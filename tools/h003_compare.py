#!/usr/bin/env python3
"""H-003: X-level populations from h2_mod (h2Test) against Cloudy's large H2
model, one-zone models at fixed T with negligible UV (runs/h003-cloudy-lev).

For each case the collider densities are Cloudy's own zone's: H and H+ and He
from lev.dens, ortho- and para-H2 from the header of lev.pops (save H2
populations). h2Test solves collisions + radiative decay only, so the
comparison measures that part; Cloudy also has formation into specific levels,
destruction, cosmic rays and residual pumping.

    python tools/h003_compare.py runs/h003-cloudy-lev [--levels]
"""
import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def cloudy_case(d):
    dens = open(os.path.join(d, 'lev.dens')).read().split('\n')
    hd = dens[0].lstrip('#').split('\t')
    vals = np.array(dens[1].split('\t'), float)
    c = {k.strip(): vals[i] for i, k in enumerate(hd)}
    pops = {}
    op = {}
    for l in open(os.path.join(d, 'lev.pops')):
        s = l.split('\t')
        if l.startswith('#') or len(s) < 4:
            continue
        if s[3].strip() in ('ortho', 'para', 'total'):
            op[s[3].strip()] = float(s[2]); continue
        pops[(int(s[0]), int(s[1]))] = float(s[4])
    T = float(os.path.basename(d).split('_')[0][1:])
    return T, [c['H'], c['He'], op['ortho'], op['para'], c['H+']], pops, c


def main(base, show_levels=False):
    cases = sorted(d for d in os.listdir(base) if d.startswith('T') and os.path.isdir(os.path.join(base, d)))
    wd = os.path.join(base, 'h2test')
    os.makedirs(wd, exist_ok=True)
    info = {}
    with open(os.path.join(wd, 'cases.txt'), 'w') as f:
        for cdir in cases:
            T, dens, pops, c = cloudy_case(os.path.join(base, cdir))
            info[cdir] = (T, dens, pops, c)
            f.write(f'{cdir} {T} ' + ' '.join(f'{x:.6e}' for x in dens) + '\n')
    subprocess.run([os.path.join(HERE, 'h2Test'), os.path.join(HERE, 'dataPDR', 'h2'), 'cases.txt'],
                   cwd=wd, check=True, stdout=subprocess.DEVNULL)
    key = [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4), (0, 5), (0, 6), (0, 7), (1, 1), (1, 3), (2, 3)]
    print('ours/Cloudy for X levels; o/p ratio; median |log10 ratio| over levels with Cloudy pop > 1e-10')
    print('  case        n(H)      n(He)     n(H2)     o/p(C)  o/p(us) ' + ' '.join(f'{v},{j}'.rjust(6) for v, j in key) + '  med|dex| (n)')
    for cdir in cases:
        T, dens, pops, c = info[cdir]
        a = np.loadtxt(os.path.join(wd, cdir + '.h2pops'))
        ours = {(int(r[0]), int(r[1])): r[3] for r in a}
        opU = sum(p for (v, j), p in ours.items() if j % 2) / sum(p for (v, j), p in ours.items() if not j % 2)
        opC = dens[2] / dens[3]
        rat = [ours[k] / pops[k] if pops.get(k, 0) > 0 else np.nan for k in key]
        sel = [k for k in pops if pops[k] > 1e-10 and k in ours and ours[k] > 0]
        dex = np.array([abs(np.log10(ours[k] / pops[k])) for k in sel])
        print(f'  {cdir:10s} {dens[0]:9.2e} {dens[1]:9.2e} {dens[2] + dens[3]:9.2e} {opC:6.3f} {opU:7.3f} '
              + ' '.join(f'{r:6.3f}' if np.isfinite(r) else '   nan' for r in rat)
              + f'  {np.median(dex):6.3f} ({len(sel)})')
        if show_levels:
            worst = sorted(sel, key=lambda k: -abs(np.log10(ours[k] / pops[k])))[:5]
            print('      worst: ' + '; '.join(f'{k} C {pops[k]:.2e} us {ours[k]:.2e}' for k in worst))


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    main(args[0], '--levels' in sys.argv)
