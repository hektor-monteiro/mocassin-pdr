#!/usr/bin/env python3
"""The Lexington benchmark's reference values, from the TeX source of Ercolano et al. (2003).

    python docs/bench/lexref.py [--tarball PATH]

Tables 4-7 of Ercolano et al. 2003, MNRAS 340, 1136 (arXiv astro-ph/0209378) list, for the four
Lexington 2000 models (HII40, HII20, PN150, PN75), the value of every code of the workshop (Pequignot
et al. 2001: GF Cloudy, HN Ion, DP Nebu, TK XStar, PH Harrington, RS Mappings, RR Nebula), the printed
median, and MOCASSIN 2003 in 3-D and 1-D (BE). Without --tarball the arXiv source is downloaded; the
tables are read from MC935.tex inside it, which must have the sha256 below.

Writes docs/bench/ref/lexington2003.csv (model, row, id, tex_label, Med, GF, HN, DP, TK, PH, RS, RR,
BE3D, BE1D; the values as printed, a '-' left empty, a column a model lacks empty) and
docs/bench/ref/lexington2003.json (where the values come from). Every TeX label must be mapped to an id
in docs/bench/lexington.toml [label]. Needs the standard library only.
"""
import argparse
import csv
import hashlib
import io
import json
import os
import re
import tarfile
import time
import tomllib
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TOML = os.path.join(HERE, 'lexington.toml')
ARXIV = 'astro-ph/0209378'
URL = 'https://arxiv.org/e-print/' + ARXIV
USER_AGENT = 'mocassin-pdr-docs (https://github.com/hektor-monteiro/mocassin-pdr)'
TEX = 'MC935.tex'
TEX_SHA256 = 'c977fc89984a9d237fcd38d87342ccde340267c1d7949eba93b1b2f9aa0248ef'
MODELS = ['HII40', 'HII20', 'PN150', 'PN75']
CODES = ['GF', 'HN', 'DP', 'TK', 'PH', 'RS', 'RR']
COLUMNS = ['model', 'row', 'id', 'tex_label', 'Med'] + CODES + ['BE3D', 'BE1D']


def collapse(s):
    return ' '.join(s.split())


def read_tex(tarball):
    """MC935.tex from the arXiv source (a tar.gz, in memory) and the tarball's sha256"""
    if tarball:
        with open(tarball, 'rb') as f:
            data = f.read()
    else:
        req = urllib.request.Request(URL, headers={'User-Agent': USER_AGENT})
        with urllib.request.urlopen(req, timeout=120) as r:
            data = r.read()
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as tar:
        tex = tar.extractfile(tar.getmember(TEX)).read()
    sha = hashlib.sha256(tex).hexdigest()
    if sha != TEX_SHA256:
        raise SystemExit(f'{TEX} has sha256 {sha}, not {TEX_SHA256}: not the source these tables were checked on')
    return tex.decode('latin-1'), hashlib.sha256(data).hexdigest()


def argument(tex, i):
    """the {...} argument of the command ending at i, an optional [...] argument skipped"""
    if tex[i] == '[':
        i = tex.index(']', i) + 1
    j = tex.index('{', i)
    depth = 0
    for k in range(j, len(tex)):
        depth += {'{': 1, '}': -1}.get(tex[k], 0)
        if depth == 0:
            return tex[j + 1:k]
    return tex[j + 1:]


def table(tex, model):
    """the first tabular after the caption containing (model), as (columns, rows); each row is its
    cells, whitespace collapsed, the label first"""
    cap = next(m.end() for m in re.finditer(r'\\caption', tex) if f'({model})' in argument(tex, m.end()))
    i = tex.index('\\begin{tabular}', cap)
    body = tex[i:tex.index('\\end{tabular}', i)]
    columns, rows = None, []
    for line in body.split('\n'):
        if '&' not in line:
            continue
        cells = [collapse(c) for c in line.split('\\\\')[0].split('&')]
        if cells[0] == 'Line':
            columns = []
            for c in cells[1:]:
                if c in ('Med', 'Median'):
                    columns.append('Med')
                elif c == '\\multicolumn{2}{c}{BE}':
                    columns += ['BE3D', 'BE1D']
                else:
                    columns.append(c)
            continue
        if not cells[0]:
            continue
        rows.append([cells[0]] + ['' if c == '-' else c for c in cells[1:]])
    return columns, rows


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--tarball', help='a local copy of the arXiv source (default: download it)')
    args = ap.parse_args()
    with open(TOML, 'rb') as f:
        conf = tomllib.load(f)
    labels = {collapse(k): v for k, v in conf['label'].items()}
    tex, tar_sha = read_tex(args.tarball)
    out, unknown = [], []
    for model in MODELS:
        columns, rows = table(tex, model)
        for n, cells in enumerate(rows, start=1):
            if cells[0] not in labels:
                unknown.append(f'{model}: {cells[0]}')
                continue
            vals = dict(zip(columns, cells[1:]))
            out.append([model, n, labels[cells[0]], cells[0]] + [vals.get(c, '') for c in COLUMNS[4:]])
    if unknown:
        raise SystemExit('TeX labels missing from lexington.toml [label]:\n  ' + '\n  '.join(unknown))
    ref = os.path.join(REPO, conf['meta']['reference'])
    os.makedirs(os.path.dirname(ref), exist_ok=True)
    with open(ref, 'w', newline='') as f:
        w = csv.writer(f, lineterminator='\n')
        w.writerow(COLUMNS)
        w.writerows(out)
    with open(os.path.splitext(ref)[0] + '.json', 'w') as f:
        json.dump({'url': URL, 'arxiv': ARXIV, 'tex': TEX, 'tex_sha256': TEX_SHA256, 'tarball_sha256': tar_sha,
                   'date': time.strftime('%Y-%m-%d'),
                   'citation': 'Ercolano et al. 2003, MNRAS 340, 1136, Tables 4–7',
                   'note': 'the non-BE columns are the Lexington 2000 codes (Péquignot et al. 2001); Med is the '
                           "paper's printed median, which includes BE 3-D"}, f, indent=1, ensure_ascii=False)
        f.write('\n')
    for model in MODELS:
        print(model, sum(r[0] == model for r in out), 'rows')
    print('written', ref)


if __name__ == '__main__':
    main()
