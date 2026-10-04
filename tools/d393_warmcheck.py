#!/usr/bin/env python3
"""D-393: is a warm start a continuation? (L-14)

Compares a cold run of N iterations (A) with a cold run of N/2 continued by a
warm start for N/2 more (W), against the seed-to-seed scatter of two cold runs
of N (A and A2). The warm start counts as equivalent where |W/A - 1| is within
what |A2/A - 1| shows the Monte Carlo can do. Read off each run's last row of
output/convergence.out (D-391's integrated quantities), its lineFlux.out, and
the H/H2 crossing from median profiles (tools/d285_kpis_hiipdr.py's method).

    ~/miniforge3/envs/astro/bin/python tools/d393_warmcheck.py \\
        runs/d393-cold16 runs/d393-cold16s2 runs/d393-warm8
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R                                    # noqa: E402
from d285_kpis_hiipdr import cross                          # noqa: E402
from d391_convtrail import read_lines                       # noqa: E402


def trail(run):
    rows = [ln for ln in open(os.path.join(run, 'output', 'convergence.out'))]
    names = rows[1].split()[4:]
    last = [float(x) for x in rows[-1].split()]
    return dict(zip(names, last[3:])), int(last[0])


def crossing(run):
    d = R.read_run(run)
    ab = np.geomspace(max(d['AV'].min(), 1e-3), d['AV'].max(), 60)
    xa, m2 = R.median_profile(d['AV'], 2 * d['H2'], ab)
    _, mh = R.median_profile(d['AV'], d['H'], ab)
    return cross(mh, m2, xa)


def main(a, a2, w):
    ta, na = trail(a)
    t2, n2 = trail(a2)
    tw, nw = trail(w)
    print(f'A  {a}: last row = iteration {na}')
    print(f'A2 {a2}: iteration {n2}')
    print(f'W  {w}: iteration {nw} of the warm start')
    print('\nintegrated quantity        A2/A-1      W/A-1')
    worst = []
    for k, v in ta.items():
        if v <= 0 or t2.get(k, -1) <= 0 or tw.get(k, -1) <= 0:
            continue
        s, d = t2[k] / v - 1, tw[k] / v - 1
        worst.append((abs(d) - abs(s), k, s, d))
        print(f'{k:24s} {100 * s:9.3f}% {100 * d:9.3f}%')
    hb = {r: read_lines(os.path.join(r, 'output', 'lineFlux.out')) for r in (a, a2, w)}
    hbA, rowsA, _ = hb[a]
    keys = [k for k, v in rowsA.items() if v >= 0.01]
    print(f'\nlines >= 0.01 Hbeta ({len(keys)}), luminosity ratios: max |A2/A-1|, max |W/A-1|')
    for name, (h, rows, _) in (('A2', hb[a2]), ('W', hb[w])):
        dev = {k: abs(rows.get(k, 0) * h / (rowsA[k] * hbA) - 1) for k in keys}
        kk = max(dev, key=dev.get)
        print(f'  {name}: Hbeta {100 * (h / hbA - 1):7.3f}%   worst line {100 * dev[kk]:7.3f}% {kk}')
    print('\nH/H2 crossing A_V: A %.3f  A2 %.3f  W %.3f' % (crossing(a), crossing(a2), crossing(w)))
    worst.sort(reverse=True)
    print('\nlargest excess of |W/A-1| over |A2/A-1|:')
    for e, k, s, d in worst[:5]:
        print(f'  {k:24s} excess {100 * e:7.3f}%  (scatter {100 * s:7.3f}%, warm {100 * d:7.3f}%)')


if __name__ == '__main__':
    main(*sys.argv[1:4])
