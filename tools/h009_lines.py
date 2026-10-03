#!/usr/bin/env python3
"""H-009: every H2 line both codes report, ours over Cloudy's, for several runs
of the same model.

Ours from output/lineFluxH2.out (vacuum wavelengths, upper and lower v J);
Cloudy's from its "save lines, intensity" file (air wavelengths, intensity
per unit inner area; the first block, intrinsic - the second is emergent,
with the dust's extinction). Each is divided by its own Hbeta. Lines are matched by
wavelength after the air-vacuum conversion (Edlen's formula), to 2e-4 relative.

    python tools/h009_lines.py <Cloudy .lines> <run> [<run> ...] [--names A,B,..] [--top N]

Prints each of Cloudy's N strongest H2 lines that is matched: wavelength,
upper level, ortho or para, and ours/Cloudy per run; then the median ratio of
the ortho and the para lines, split by the upper level's v.
"""
import os
import sys

import numpy as np


def vac_to_air(lam_um):
    s2 = (1./lam_um)**2
    return lam_um/(1. + 8.34213e-5 + 2.406030e-2/(130. - s2) + 1.5997e-4/(38.9 - s2))


def cloudy_lines(path):
    hb, h2 = None, []
    for l in open(path, errors='replace'):
        if l.startswith('####'):
            break                        # the intrinsic block ends; the emergent one follows
        t = l.split()
        if len(t) == 3 and t[0] == 'H2' and t[1][-1] in 'mA':
            lam = float(t[1][:-1])*(1e-4 if t[1][-1] == 'A' else 1.)
            h2.append((lam, float(t[2])))
        if len(t) == 4 and t[0] == 'H' and t[1] == '1' and t[2] == '4861.32A':
            hb = float(t[3])
    return np.array(h2), hb


def ours(run):
    rows, hb = [], None
    for l in open(os.path.join(run, 'output', 'lineFluxH2.out')):
        if l.startswith('# Hbeta'):
            hb = float(l.split(':')[1])
        if l.startswith('#'):
            continue
        vu, ju, vl, jl = (int(x) for x in l[14:30].split())
        rows.append((float(l[30:44]), vu, ju, vl, jl, float(l[71:85])))
    return rows


def main(clfile, runs, names, top):
    cl, hbC = cloudy_lines(clfile)
    cl = cl[np.argsort(-cl[:, 1])][:top]
    R = [ours(r) for r in runs]
    lamA = np.array([vac_to_air(x[0]) for x in R[0]])
    print(f'Cloudy Hbeta {hbC:.4e} (per unit inner area); {len(cl)} strongest H2 lines')
    print(f'  lambda(air)  upper(v,J) lower  o/p   Cloudy/Hb  ' + '  '.join(f'{n:>8s}' for n in names))
    tab = []
    for lam, I in cl:
        j = np.argmin(abs(lamA - lam))
        if abs(lamA[j] - lam) > 2e-4*lam:
            continue
        lam0, vu, ju, vl, jl, _ = R[0][j]
        q = []
        for rr in R:
            m = [x for x in rr if x[1:5] == (vu, ju, vl, jl)]
            q.append(m[0][5]/(I/hbC) if m else np.nan)
        op = 'o' if ju % 2 else 'p'
        tab.append((vu, op, q))
        print(f'  {lam:10.5f}  ({vu:2d},{ju:2d})  ({vl:2d},{jl:2d})   {op}   {I/hbC:9.3e}  ' + '  '.join(f'{x:8.3f}' for x in q))
    print('  median ours/Cloudy by upper v and spin (n):')
    for grp, sel in (('v = 0', lambda v: v == 0), ('v = 1', lambda v: v == 1), ('v >= 2', lambda v: v >= 2)):
        for op in 'op':
            qs = np.array([q for v, o, q in tab if sel(v) and o == op])
            if len(qs):
                print(f'    {grp:6s} {"ortho" if op == "o" else "para "} ({len(qs):2d}): ' +
                      '  '.join(f'{n} {np.nanmedian(qs[:, i]):6.3f}' for i, n in enumerate(names)))


if __name__ == '__main__':
    argv = sys.argv[1:]
    names = argv[argv.index('--names') + 1].split(',') if '--names' in argv else None
    top = int(argv[argv.index('--top') + 1]) if '--top' in argv else 40
    args = [a for i, a in enumerate(argv) if not a.startswith('--') and (i == 0 or not argv[i - 1].startswith('--'))]
    main(args[0], args[1:], names or [os.path.basename(r.rstrip('/')) for r in args[1:]], top)
