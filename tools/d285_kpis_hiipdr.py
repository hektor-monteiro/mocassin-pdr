#!/usr/bin/env python3
"""D-285: the numbers behind the 'hiipdr Against Cloudy' page, from a run.

Same purpose as d285_kpis.py, for the other fixture: headline figures, the
selected-depths table (medians in +-0.05 mag bins, as the page states), the
ionized-gas table matched in radius, and the deep-carbon ratios.

    ~/miniforge3/envs/astro/bin/python tools/d285_kpis_hiipdr.py \\
        runs/d285-hiipdr runs/d277-cloudy/hiipdr

Validate it on runs/d284-analog-fixes, the run the published page was built
from.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R

PC = R.PC
RIN = 3e18


def cross(a, b, xs):
    f = np.log(np.maximum(b, 1e-300)) - np.log(np.maximum(a, 1e-300))
    o = np.argsort(xs)
    f, xs = np.asarray(f)[o], np.asarray(xs)[o]
    k = np.where(np.diff(np.sign(f)) != 0)[0]
    if not len(k):
        return float('nan')
    k = k[0]
    return xs[k] + (0 - f[k]) / (f[k + 1] - f[k]) * (xs[k + 1] - xs[k])


def main(run, cprefix):
    d = R.read_run(run)
    c = R.cloudy_as_run(cprefix, RIN)
    r = d['r']
    rc = (RIN + c['depth']) / PC

    print('== headline ==')
    # front in radial shells, as the page states
    edges = np.arange(3.0, 4.6, 0.05)
    hp, hh, rr = [], [], []
    for a, b in zip(edges[:-1], edges[1:]):
        s = (r >= a) & (r < b)
        if s.sum() < 3:
            continue
        hp.append(np.median(d['H+'][s])); hh.append(np.median(d['H'][s]))
        rr.append(np.exp(np.log(r[s]).mean()))
    print('front (radial shells)  %.3f pc      Cloudy %.3f'
          % (cross(np.array(hh), np.array(hp), np.array(rr)), cross(c['H'], c['H+'], rc)))
    ab = np.geomspace(max(d['AV'].min(), 1e-3), d['AV'].max(), 60)
    xa, m2 = R.median_profile(d['AV'], 2 * d['H2'], ab)
    _, mh = R.median_profile(d['AV'], d['H'], ab)
    print('H/H2 crossing A_V      %.3f          Cloudy %.3f'
          % (cross(mh, m2, xa), cross(c['H'], 2 * c['H2'], c['AV'])))
    _, mcp = R.median_profile(d['AV'], d['C+'], ab)
    _, mc = R.median_profile(d['AV'], d['C'], ab)
    print('C+ = C at A_V          %.3f          Cloudy %.3f'
          % (cross(mcp, mc, xa), cross(c['C+'], c['C'], c['AV'])))
    s = (d['AV'] >= 0.7) & (d['AV'] <= 2.0)
    sc = (c['AV'] >= 0.7) & (c['AV'] <= 2.0)
    print('PDR T_gas A_V 0.7-2.0  %.0f-%.0f K       Cloudy %.0f-%.0f'
          % (np.percentile(d['Tgas'][s], 5), np.percentile(d['Tgas'][s], 95),
             c['Tgas'][sc].min(), c['Tgas'][sc].max()))
    print('front in A_V           %.3f          Cloudy %.3f'
          % (cross(mh, R.median_profile(d['AV'], d['H+'], ab)[1], xa),
             cross(c['H'], c['H+'], c['AV'])))

    print('\n== selected depths (MOCASSIN / Cloudy) ==')
    print('A_V    Tgas         Tdust        ne           n(H2)        n(C+)        n(CO)')
    for av in (0.30, 0.45, 0.70, 1.00, 1.50, 2.00, 2.50, 2.90):
        s = np.abs(d['AV'] - av) <= 0.05
        j = np.argmin(abs(c['AV'] - av))
        if s.sum() == 0:
            continue
        row = ['%.3g / %.3g' % (np.median(d[k][s]), c[k][j])
               for k in ('Tgas', 'Tdust', 'e-', 'H2', 'C+', 'CO')]
        print('%.2f  ' % av + ' '.join('%-12s' % x for x in row))

    print('\n== ionized gas, matched in radius ==')
    print('r[pc]  Tgas        C2+          O2+          O+           Mg+          H0')
    for rad in (1.0, 2.0, 3.0, 3.3):
        s = np.abs(r - rad) < 0.35
        j = np.argmin(abs(rc - rad))
        row = ['%.3g / %.3g' % (np.median(d[k][s]), c[k][j])
               for k in ('Tgas', 'C++', 'O++', 'O+', 'Mg+', 'H')]
        print('%.1f   ' % rad + ' '.join('%-12s' % x for x in row))

    print('\n== deep carbon and electrons (MOCASSIN / Cloudy) ==')
    for av in (2.3, 2.5, 2.7, 2.9):
        s = np.abs(d['AV'] - av) <= 0.05
        j = np.argmin(abs(c['AV'] - av))
        if s.sum() == 0:
            continue
        print('A_V %.1f  C+ %.2f   e- %.2f   CO %.3g   Tdust %.3f'
              % (av, np.median(d['C+'][s]) / c['C+'][j],
                 np.median(d['e-'][s]) / c['e-'][j],
                 np.median(d['CO'][s]) / c['CO'][j],
                 np.median(d['Tdust'][s]) / c['Tdust'][j]))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
