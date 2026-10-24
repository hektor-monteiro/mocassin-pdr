#!/usr/bin/env python3
"""The 1D dust benchmark's reference SEDs, read from the PostScript of Fig. 1 of Ercolano et al. (2005).

    python docs/bench/ercref.py [--tarball PATH] [--check]

Fig. 1 of Ercolano, Barlow & Storey 2005, MNRAS 362, 1038 (arXiv astro-ph/0507050) overplots, for the
spherical dust shells of Ivezic et al. (1997) with tau(1 um) = 1, 10 and 100, MOCASSIN 2005 (black,
solid) and DUSTY 2.01 (red, dashed) as lambda F_lambda / int F_lambda dlambda against lambda. It is
dustybench.ps in the arXiv source, one vector panel written by IDL 6.0: every curve is a stroked path of
the points as plotted, so the values are read exactly, not digitised. The tarball is
[ref.ercolano2005] tarball of docs/bench/dust.toml under the runs root ($MOCASSIN_RUNS, default
meta.runs_root_default) unless --tarball names one; it and dustybench.ps must have the sha256 values of
the toml.

The PostScript is read as follows. The prolog's aliases must be those of IDL's prolog: M moveto, R
rlineto, D {currentpoint stroke moveto}, L0 and L2 the solid and [200 200] dashes; setrgbcolor and
setlinewidth are used as themselves. The page body may hold nothing else. A path is M followed by R ...
and ended by D. The frame (x 2220-17114, y 1408-11996) and the major ticks (x 5718, 9517, 13315, 17114,
lambda = 1, 10, 100, 1000 um; y every 2117.6 from 1408, one decade each) are detected and checked, and
the axes calibrated as

    lambda = 10^((x - 5718)/3798.67) um,    y = 10^((y - 11996)/2117.6)

The curves are the paths of colour (0,0,0) or (1,0,0) with 7 or more points lying inside the frame
(+-1 unit); the figure's text, drawn as black strokes too, lies outside it. Colour (0,0,0) with L0 is
MOCASSIN 2005, (1,0,0) with L2 DUSTY 2.01; line width 10, 40, 80 is tau = 1, 10, 100. The three subpaths
of each code at tau = 100 are one curve. Points on the bottom or right edge of the frame are where a
curve was clipped, and are dropped.

Writes docs/bench/ref/ercolano2005_fig1.csv (code, tau, segment, lam_um, y; %.6g, sorted by code, tau,
lambda; segment is 1 for a curve drawn as one path, and 1, 2, 3 for the tau = 100 subpaths in lambda order)
and ercolano2005_fig1.json (where the values come from, the frame, ticks and calibration, the point
counts and each curve's integral of y over ln lambda by the trapezoid rule, across the gaps between
segments). That integral is 1 for a
curve normalised as the caption says; DUSTY 2.01's must lie in 0.97-1.02, which checks the calibration.
MOCASSIN 2005's is reported and not checked: the published curve lies 0.02-0.04 dex below DUSTY's and is
kept as published. --check extracts again and compares with the committed CSV byte for byte. Needs the
standard library and numpy.
"""
import argparse
import hashlib
import io
import json
import os
import re
import sys
import tarfile
import tomllib

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TOML = os.path.join(HERE, 'dust.toml')
OUT = os.path.join(HERE, 'ref', 'ercolano2005_fig1.csv')

# the prolog's aliases this reader relies on, whitespace collapsed
ALIASES = {'M': 'moveto', 'R': 'rlineto', 'D': 'currentpoint stroke moveto',
           'L0': '[] 0 setdash', 'L2': '[200 200] 0 setdash'}
OPERATORS = {'M', 'R', 'D', 'L0', 'L2', 'setrgbcolor', 'setlinewidth'}
FRAME = {'x0': 2220, 'x1': 17114, 'y0': 1408, 'y1': 11996}
XTICKS = [5718, 9517, 13315, 17114]                    # lambda = 1, 10, 100, 1000 um
YTICK0, YTICKSTEP, NYTICKS = 1408, 2117.6, 6           # 1e-5 ... 1e0
X1UM, XDEC = 5718, 3798.67
Y1, YDEC = 11996, 2117.6
CODES = {((0., 0., 0.), 'L0'): 'MOCASSIN 2005', ((1., 0., 0.), 'L2'): 'DUSTY 2.01'}
TAUS = {10.: 1, 40.: 10, 80.: 100}
# points per subpath as plotted, in wavelength order
COUNTS = {('MOCASSIN 2005', 1): [81], ('DUSTY 2.01', 1): [81], ('MOCASSIN 2005', 10): [78],
          ('DUSTY 2.01', 10): [78], ('MOCASSIN 2005', 100): [15, 7, 38], ('DUSTY 2.01', 100): [15, 7, 36]}
DUSTY_WINDOW = (0.97, 1.02)
FORMULAS = {'lam_um': '10**((x - 5718)/3798.67)', 'y': '10**((y - 11996)/2117.6)',
            'y_meaning': 'lambda F_lambda / int F_lambda dlambda'}


def fail(msg):
    raise SystemExit('ercref: ' + msg)


def sha256(b):
    return hashlib.sha256(b).hexdigest()


def read_ps(conf, tarball):
    """dustybench.ps from the tarball, both checksums checked; (ps bytes, tarball path)"""
    ref = conf['ref']['ercolano2005']
    if tarball is None:
        runs = os.environ.get(conf['meta']['runs_root_env'], conf['meta']['runs_root_default'])
        tarball = os.path.join(runs, ref['tarball'])
    with open(tarball, 'rb') as f:
        data = f.read()
    if sha256(data) != ref['tarball_sha256']:
        fail(f'{tarball} has sha256 {sha256(data)}, not {ref["tarball_sha256"]}')
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as tar:
        ps = tar.extractfile(tar.getmember(ref['member'])).read()
    if sha256(ps) != ref['member_sha256']:
        fail(f'{ref["member"]} has sha256 {sha256(ps)}, not {ref["member_sha256"]}')
    return ps, tarball


def check_prolog(text):
    """the /name {...} bdef aliases of the prolog: those of ALIASES as listed, and no redefinition of
    setrgbcolor or setlinewidth"""
    prolog = text.split('%%BeginProlog', 1)[1].split('%%EndProlog', 1)[0]
    defs = {m.group(1): ' '.join(m.group(2).split())
            for m in re.finditer(r'/(\S+)\s*\{([^{}]*)\}\s*b?def', prolog)}
    for name, body in ALIASES.items():
        if defs.get(name) != body:
            fail(f'the prolog defines {name} as {{{defs.get(name)}}}, not {{{body}}}')
    for op in ('setrgbcolor', 'setlinewidth'):
        if op in defs:
            fail(f'the prolog redefines {op}')
    return defs


def paths(text):
    """the page body's stroked paths: (rgb, width, dash, [(x, y), ...]) in drawing order"""
    body = text.split('%%EndPageSetup', 1)[1].split('%%PageTrailer', 1)[0]
    stack, out, cur = [], [], None
    rgb = width = dash = None
    for t in body.split():
        if t not in OPERATORS:
            try:
                stack.append(float(t))
            except ValueError:
                fail(f'the page body holds {t!r}, which this reader does not interpret')
            continue
        if t == 'M':
            y, x = stack.pop(), stack.pop()
            cur = [(x, y)]
        elif t == 'R':
            dy, dx = stack.pop(), stack.pop()
            x, y = cur[-1]
            cur.append((x + dx, y + dy))
        elif t == 'D':
            out.append((rgb, width, dash, cur))
            cur = [cur[-1]]
        elif t == 'setrgbcolor':
            b, g, r = stack.pop(), stack.pop(), stack.pop()
            rgb = (r, g, b)
        elif t == 'setlinewidth':
            width = stack.pop()
        else:
            dash = t
    if stack:
        fail(f'{len(stack)} numbers are left on the stack after the page body')
    return out


def frame_and_ticks(ps_paths):
    """the frame from the four long axis lines, and the major ticks (the longest ticks) on its bottom and
    left sides; each checked against FRAME, XTICKS and the y ladder"""
    segs = [p[3] for p in ps_paths if len(p[3]) == 2]
    hor = [(min(a[0], b[0]), max(a[0], b[0]), a[1]) for a, b in segs if a[1] == b[1]]
    ver = [(min(a[1], b[1]), max(a[1], b[1]), a[0]) for a, b in segs if a[0] == b[0]]
    long_h = [s for s in hor if s[1] - s[0] > 10000]
    long_v = [s for s in ver if s[1] - s[0] > 5000]
    if not long_h or not long_v:
        fail('no frame lines found')
    fr = {'x0': min(s[2] for s in long_v), 'x1': max(s[2] for s in long_v),
          'y0': min(s[2] for s in long_h), 'y1': max(s[2] for s in long_h)}
    for k, v in FRAME.items():
        if abs(fr[k] - v) > 1:
            fail(f'the frame has {k} = {fr[k]}, not {v} +- 1')
    bottom = [(s[2], s[1] - s[0]) for s in ver
              if abs(s[0] - fr['y0']) <= 1 and 0 < s[1] - s[0] < (fr['y1'] - fr['y0']) / 2]
    left = [(s[2], s[1] - s[0]) for s in hor
            if abs(s[0] - fr['x0']) <= 1 and 0 < s[1] - s[0] < (fr['x1'] - fr['x0']) / 2]
    xmaj = sorted(x for x, n in bottom if n == max(n for _, n in bottom))
    ymaj = sorted(y for y, n in left if n == max(n for _, n in left))
    yexp = [YTICK0 + k * YTICKSTEP for k in range(NYTICKS)]
    if len(xmaj) != len(XTICKS) or max(abs(a - b) for a, b in zip(xmaj, XTICKS)) > 2:
        fail(f'the major x ticks are {xmaj}, not {XTICKS} +- 2')
    if len(ymaj) != len(yexp) or max(abs(a - b) for a, b in zip(ymaj, yexp)) > 2:
        fail(f'the major y ticks are {ymaj}, not every {YTICKSTEP} from {YTICK0} +- 2')
    return fr, xmaj, ymaj


def curves(ps_paths, fr):
    """{(code, tau): [subpath, ...]} in wavelength order"""
    def inside(pts):
        return all(fr['x0'] - 1 <= x <= fr['x1'] + 1 and fr['y0'] - 1 <= y <= fr['y1'] + 1 for x, y in pts)
    sel = [p for p in ps_paths if p[0] in ((0., 0., 0.), (1., 0., 0.)) and len(p[3]) >= 7 and inside(p[3])]
    if len(sel) != 10:
        fail(f'{len(sel)} paths of colour (0,0,0) or (1,0,0) with 7 or more points lie inside the frame, not 10')
    out = {}
    for rgb, width, dash, pts in sel:
        if (rgb, dash) not in CODES:
            fail(f'a curve has colour {rgb} with dash {dash}, neither MOCASSIN 2005 nor DUSTY 2.01')
        if width not in TAUS:
            fail(f'a curve has line width {width}, not one of {sorted(TAUS)}')
        out.setdefault((CODES[(rgb, dash)], TAUS[width]), []).append(sorted(pts))
    for k in out:
        out[k].sort(key=lambda s: s[0][0])
    counts = {k: [len(s) for s in v] for k, v in out.items()}
    if counts != COUNTS:
        fail(f'the point counts per subpath are {counts}, not {COUNTS}')
    return out


def extract(ps):
    """the CSV text and the JSON record"""
    text = ps.decode('latin-1')
    check_prolog(text)
    pp = paths(text)
    fr, xmaj, ymaj = frame_and_ticks(pp)
    cv = curves(pp, fr)
    rows, record = [], []
    for (code, tau) in sorted(cv):
        pts = [q for s in cv[(code, tau)] for q in s]
        kept = sorted((x, y, seg) for seg, sub in enumerate(cv[(code, tau)], start=1) for x, y in sub
                      if y != fr['y0'] and x != fr['x1'])
        kept = np.array(kept)
        lam = 10 ** ((kept[:, 0] - X1UM) / XDEC)
        y = 10 ** ((kept[:, 1] - Y1) / YDEC)
        integral = float(np.trapezoid(y, np.log(lam)))      # across the tau = 100 gaps too
        rows += [(code, tau, int(seg), a, b) for a, b, seg in zip(lam, y, kept[:, 2])]
        record.append({'code': code, 'tau': tau, 'points': len(pts), 'subpaths': [len(s) for s in cv[(code, tau)]],
                       'points_kept': len(kept), 'integral_y_dlnlam': round(integral, 6),
                       'checked': code == 'DUSTY 2.01'})
    csv = 'code,tau,segment,lam_um,y\n' + ''.join(f'{c},{t},{n},{a:.6g},{b:.6g}\n' for c, t, n, a, b in rows)
    return csv, fr, xmaj, ymaj, record


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--tarball', help='the arXiv source (default: [ref.ercolano2005] tarball under the runs root)')
    ap.add_argument('--check', action='store_true', help='compare a new extraction with the committed CSV')
    args = ap.parse_args()
    with open(TOML, 'rb') as f:
        conf = tomllib.load(f)
    ref = conf['ref']['ercolano2005']
    ps, tarball = read_ps(conf, args.tarball)
    csv, fr, xmaj, ymaj, record = extract(ps)
    bad = []
    for r in record:
        print(f"{r['code']:<14} tau {r['tau']:>3}: {r['points']:>3} points ({'+'.join(map(str, r['subpaths']))}), "
              f"{r['points_kept']:>3} kept, integral {r['integral_y_dlnlam']:.4f}"
              + ('' if r['checked'] else ' (not checked)'))
        if r['checked'] and not DUSTY_WINDOW[0] <= r['integral_y_dlnlam'] <= DUSTY_WINDOW[1]:
            bad.append(f"{r['code']} tau {r['tau']}: {r['integral_y_dlnlam']}")
    if bad:
        fail(f'integrals outside {DUSTY_WINDOW}: ' + '; '.join(bad))
    if args.check:
        same = os.path.exists(OUT) and open(OUT, 'rb').read() == csv.encode()
        print(f'{os.path.relpath(OUT, REPO)}: ' + ('identical' if same else 'DIFFERENT'))
        sys.exit(0 if same else 1)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', newline='') as f:
        f.write(csv)
    with open(os.path.splitext(OUT)[0] + '.json', 'w') as f:
        json.dump({'url': ref['url'], 'citation': ref['citation'], 'member': ref['member'],
                   'tarball_sha256': ref['tarball_sha256'], 'member_sha256': ref['member_sha256'],
                   'frame': fr, 'major_ticks': {'x': xmaj, 'y': ymaj}, 'formulas': FORMULAS,
                   'attribution': {'MOCASSIN 2005': 'rgb (0,0,0), L0 (solid)', 'DUSTY 2.01': 'rgb (1,0,0), L2 (dashed)',
                                   'tau': 'line width 10, 40, 80 = tau(1 um) 1, 10, 100'},
                   'clipped': 'points with y = frame y0 or x = frame x1 dropped',
                   'integral_check': f'DUSTY 2.01 only, in {DUSTY_WINDOW[0]}-{DUSTY_WINDOW[1]}',
                   'curves': record,
                   'script': {'ercref.py': sha256(open(os.path.abspath(__file__), 'rb').read())}},
                  f, indent=1, ensure_ascii=False)
        f.write('\n')
    print('written', OUT, f'(from {tarball})')


if __name__ == '__main__':
    main()
