#!/usr/bin/env python3
"""Stage A of the Lexington benchmark page: the four Lexington 2000 runs against the codes of the workshop.

    python docs/bench/lexington.py [--run M=DIR ...] [--out DIR] [--check]

Reads docs/bench/lexington.toml, the reference values of Ercolano et al. (2003), Tables 4-7
(docs/bench/ref/lexington2003.csv, written by lexref.py), and each run through tools/mocread.py. The
runs are <runs root>/<run.M.path> ($MOCASSIN_RUNS, default meta.runs_root_default) unless --run names
one. Writes to DIR (default docs/bench/data/lexington):

    <M>.csv             every compared row: MOCASSIN-PDR's value, the median, range and number of the
                        Lexington codes (MOCASSIN 2003 left out), whether the value is in the range, its
                        offset in dex, the printed median, MOCASSIN 2003 (3-D) and each code's value
    matches.csv         every lineFlux.out row summed into a line
    summary.csv         per model: rows compared, in range, median |dex|, the same for MOCASSIN 2003 on
                        the same rows, and Hbeta over the codes' median
    printed_median.csv  rows whose printed median differs from the codes' median by more than 5%
    PROVENANCE.json     sha256 of every file read, each run's version line, the md5 of meta.binary, the date

<M>.csv, summary.csv and printed_median.csv are written with %.4g, matches.csv with %.6g. --check
reduces again into a temporary directory and compares every CSV with DIR's byte for byte.
"""
import argparse
import csv
import hashlib
import json
import os
import shutil
import sys
import tempfile
import time
import tomllib

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(REPO, 'tools'))
import mocread  # noqa: E402

TOML = os.path.join(HERE, 'lexington.toml')
DEFAULT_OUT = os.path.join(HERE, 'data', 'lexington')
CODES = ['GF', 'HN', 'DP', 'TK', 'PH', 'RS', 'RR']
MODELS = ['HII40', 'HII20', 'PN150', 'PN75']
COLUMNS = ['row', 'id', 'display', 'value', 'median', 'lo', 'hi', 'n', 'in_range', 'dex', 'median_printed',
           'moc2003'] + CODES
READ = {}                                      # label -> sha256 of every file read


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def label(path):
    path = os.path.abspath(path)
    for root, tag in ((RUNS, 'runs:'), (REPO, 'repo:')):
        if path.startswith(root.rstrip('/') + '/'):
            return tag + os.path.relpath(path, root)
    return path


def src(path):
    """a file about to be read: its sha256 goes into PROVENANCE.json"""
    READ[label(path)] = sha256(path)
    return path


def num(s):
    return float(s) if s.strip() else None


def g(v, fmt='%.4g'):
    if v is None:
        return ''
    if isinstance(v, (bool, np.bool_)):
        return str(bool(v))
    if isinstance(v, (int, np.integer)):
        return str(int(v))
    return fmt % v if np.isfinite(v) else ''


def write_csv(path, header, rows, fmt='%.4g'):
    with open(path, 'w', newline='') as f:
        f.write(','.join(header) + '\n')
        for r in rows:
            f.write(','.join(x if isinstance(x, str) else g(x, fmt) for x in r) + '\n')


# ------------------------------------------------------------------------------------------- values
def windows(spec):
    """a line's windows (Z, charge, wmin, wmax) in vacuum A; ir = [Z, charge, um] is um*1e4*(1 -+ 0.015)"""
    if 'ir' in spec:
        z, q, um = spec['ir']
        return [(z, q, um * 1e4 * (1 - 0.015), um * 1e4 * (1 + 0.015))]
    return [tuple(w) for w in spec['windows']]


class Run:
    def __init__(self, model, path):
        if os.path.exists(os.path.join(path, 'INCOMPLETE')):
            raise SystemExit(f'REFUSING {path}: marked INCOMPLETE')
        out = os.path.join(path, 'output')
        if not os.path.exists(os.path.join(out, 'lineFlux.out')):
            raise SystemExit(f'REFUSING {path}: no output/lineFlux.out')
        self.model, self.path = model, path
        self.lines = mocread.read_lines(path)
        for f in ('lineFlux.out', 'temperature.out', 'ionratio.out'):
            src(os.path.join(out, f))
        self.te = mocread.mean_te(path)
        self.ion = mocread.ion_fractions(path)
        self.matches = []

    def value(self, ident, spec):
        kind = spec['kind']
        ln = self.lines
        if kind == 'hbeta':
            return ln.hbeta / spec['scale']
        if kind == 'te_hplus':
            return self.te[('H', 1)]
        if kind == 'heplus_ratio':
            return self.ion[('He', 1)] / self.ion[('H', 1)]
        if kind == 'hei':
            a, b = spec['window']
            m = ln.hei[(ln.hei['wav'] >= a) & (ln.hei['wav'] <= b)]
        elif kind == 'heii':
            a, b = spec['window']
            m = ln.heii[(ln.heii['wav_air'] >= a) & (ln.heii['wav_air'] <= b)]
        elif kind == 'line':
            m = []
            for z, q, a, b in windows(spec):
                for r in ln.matches(z, q, a, b):
                    m.append(r)
                    self.matches.append((self.model, ident, int(r['Z']), int(r['charge']), int(r['lo']),
                                         int(r['up']), float(r['wav']), float(r['rel'])))
        else:
            raise SystemExit(f'{ident}: unknown kind {kind}')
        if not len(m):
            raise SystemExit(f'{self.model}: {ident} matches no line of lineFlux.out')
        return float(sum(r['rel'] for r in m))


def stats(v, codes):
    """median, lo, hi, n, in_range, dex of a value against the codes' values (None where fewer than 2)"""
    n = len(codes)
    if n < 2:
        return None, None, None, n, None, None
    med, lo, hi = float(np.median(codes)), min(codes), max(codes)
    dex = float(np.log10(v / med)) if v > 0 and med > 0 else None
    return med, lo, hi, n, lo <= v <= hi, dex


def reduce_model(model, run, ids, ref, out):
    rows, comp = [], []
    for r in ref:
        spec = ids[r['id']]
        if spec['kind'] == 'skip':
            continue
        v = run.value(r['id'], spec)
        codes = [num(r[c]) for c in CODES if num(r[c]) is not None]
        med, lo, hi, n, inr, dex = stats(v, codes)
        be = num(r['BE3D'])
        rows.append([int(r['row']), r['id'], spec['display'], v, med, lo, hi, n, inr, dex, num(r['Med']), be]
                    + [num(r[c]) for c in CODES])
        if med is not None:
            comp.append((r, spec, v, med, lo, hi, inr, dex, be))
    write_csv(os.path.join(out, f'{model}.csv'), COLUMNS, rows)

    # MOCASSIN 2003 (BE 3-D) on the same rows, the same way
    be = [(lo <= b <= hi, abs(np.log10(b / med))) for r, s, v, med, lo, hi, inr, dex, b in comp
          if b is not None and b > 0]
    hb = [v / med for r, s, v, med, lo, hi, inr, dex, b in comp if s['kind'] == 'hbeta']
    summary = [model, len(comp), sum(bool(c[6]) for c in comp),
               float(np.median([abs(c[7]) for c in comp if c[7] is not None])),
               sum(bool(x[0]) for x in be), float(np.median([x[1] for x in be])) if be else None,
               hb[0] if hb else None]
    printed = [[model, int(r['row']), r['id'], s['display'], num(r['Med']), med]
               for r, s, v, med, lo, hi, inr, dex, b in comp
               if num(r['Med']) is not None and abs(num(r['Med']) / med - 1) > 0.05]
    return summary, printed


def reduce_all(conf, runs, out):
    global READ
    READ = {}
    os.makedirs(out, exist_ok=True)
    ids = conf['id']
    refpath = os.path.join(REPO, conf['meta']['reference'])
    with open(src(refpath)) as f:
        ref = list(csv.DictReader(f))
    summary, printed, matches, card = [], [], [], {}
    for model in MODELS:
        run = Run(model, runs[model])
        s, p = reduce_model(model, run, ids, [r for r in ref if r['model'] == model], out)
        summary.append(s)
        printed += p
        matches += run.matches
        log = os.path.join(runs[model], 'run.log')
        card[model] = {'run': label(runs[model]),
                       'version': open(src(log)).readline().strip() if os.path.exists(log) else None}
    write_csv(os.path.join(out, 'matches.csv'), ['model', 'id', 'Z', 'charge', 'lo', 'up', 'wav', 'rel'], matches,
              '%.6g')
    write_csv(os.path.join(out, 'summary.csv'), ['model', 'compared', 'in_range', 'median_abs_dex', 'moc2003_in_range',
                                                 'moc2003_median_abs_dex', 'hbeta_over_median'], summary)
    write_csv(os.path.join(out, 'printed_median.csv'), ['model', 'row', 'id', 'display', 'median_printed', 'median'],
              printed)
    with open(os.path.join(out, 'PROVENANCE.json'), 'w') as f:
        binary = os.path.join(RUNS, conf['meta']['binary'])
        json.dump({'generated': time.strftime('%Y-%m-%d'), 'runs_root': RUNS, 'runs': card,
                   'binary': {'path': label(binary), 'md5': hashlib.md5(open(binary, 'rb').read()).hexdigest()
                              if os.path.exists(binary) else None},
                   'toml': {'path': label(TOML), 'sha256': sha256(TOML)},
                   'reference': {'path': label(refpath), 'sha256': sha256(refpath)},
                   'script': {'lexington.py': sha256(os.path.abspath(__file__)),
                              'mocread.py': sha256(os.path.abspath(mocread.__file__))},
                   'files_read': dict(sorted(READ.items()))}, f, indent=1)
        f.write('\n')


def check(conf, runs, out):
    tmp = tempfile.mkdtemp(prefix='lexington-check-')
    ok = True
    try:
        reduce_all(conf, runs, tmp)
        fa = sorted(f for f in os.listdir(out) if f.endswith('.csv')) if os.path.isdir(out) else []
        fb = sorted(f for f in os.listdir(tmp) if f.endswith('.csv'))
        if fa != fb:
            ok = False
            print(f'files differ: {out} has {fa}, the reduction {fb}')
        for f in sorted(set(fa) & set(fb)):
            same = open(os.path.join(out, f), 'rb').read() == open(os.path.join(tmp, f), 'rb').read()
            ok &= same
            print(f'{f}: ' + ('identical' if same else 'DIFFERENT'))
    finally:
        shutil.rmtree(tmp)
    return ok


def main():
    global RUNS
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--run', action='append', default=[], metavar='M=DIR', help='the run of model M')
    ap.add_argument('--out', default=DEFAULT_OUT)
    ap.add_argument('--check', action='store_true')
    args = ap.parse_args()
    with open(TOML, 'rb') as f:
        conf = tomllib.load(f)
    RUNS = os.path.abspath(os.environ.get(conf['meta']['runs_root_env'], conf['meta']['runs_root_default']))
    runs = {m: os.path.join(RUNS, conf['run'][m]['path']) for m in MODELS}
    for a in args.run:
        m, d = a.split('=', 1)
        if m not in runs:
            raise SystemExit(f'--run {a}: no model {m} (one of {", ".join(MODELS)})')
        runs[m] = os.path.abspath(d)
    out = os.path.abspath(args.out)
    if args.check:
        sys.exit(0 if check(conf, runs, out) else 1)
    reduce_all(conf, runs, out)
    print('written', out)


RUNS = ''
if __name__ == '__main__':
    main()
