#!/usr/bin/env python3
"""H-014: the numbers behind the 'hiipdr Against 3D-PDR' page, from a run and
its standalone 3D-PDR reference (tools/d275_3dpdr_reference.py).

Same conventions as tools/d285_kpis_hiipdr.py, so the MOCASSIN side of both
hiipdr pages is one computation: crossings from median profiles on 60
geometric A_V bins, the PDR temperature range as the 5th-95th percentile of
the cells at A_V 0.7-2.0, selected depths as medians in +-0.05 mag bins. The
reference is placed at the run's A_front (d260_roellig.read_ref) and
interpolated at the same A_V.

    ~/miniforge3/envs/astro/bin/python tools/h014_3dpdr_kpis.py \\
        runs/h013-b2b-hii31 runs/h014-3dpdr-hii31/sims/hiipdr.pdr.fin

Validate it on runs/d266-cfull with runs/d275-3dpdr-hiipdr, the pair the
D-275 page was built from.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R
from d285_kpis_hiipdr import cross

DEPTHS = (0.55, 0.70, 1.00, 1.50, 2.00, 2.50, 2.90)
KEYS = ('Tgas', 'Tdust', 'chi', 'e-', 'H+', 'H2', 'C+', 'C', 'CO', 'O+',
        'He+', 'CH', 'H2O', 'OH')


def load(run, ref_path):
    d = R.read_run(run)
    out = os.path.join(run, 'output')
    t = open(os.path.join(out, 'grid0.out')).read().split()
    n = int(t[1]) * int(t[2]) * int(t[3])
    off = 7 + int(t[1]) + int(t[2]) + int(t[3])
    act = np.array(t[off:off + n * 3:3], float).astype(int) > 0
    d['chi'] = R.read_pdrgrid(out, n)['chi'][act]
    # the chemistry's species everywhere, MOCASSIN's own ions where it owns them
    nh = np.loadtxt(os.path.join(out, 'grid1.out'))[act, 2]
    ab = R.read_pdrgrid(out, n)['ab'][act]
    for k in ('CH', 'H2O', 'OH'):
        d[k] = ab[:, R.SPEC.index(k)] * nh
    ref = R.read_ref(ref_path, d['A_front'])
    a = np.array([ln.split() for ln in open(ref_path)
                  if len(ln.split()) >= 41], float)
    ref['chi'] = a[:, 7]
    ref['nh'] = a[:, 6]
    ref['ab'] = a[:, 8:8 + len(R.SPEC)]
    return d, ref


def at(ref, k, av):
    return np.interp(av, ref['AV'], ref[k])


def main(run, ref_path):
    d, ref = load(run, ref_path)
    ab = np.geomspace(max(d['AV'].min(), 1e-3), d['AV'].max(), 60)
    xa, m2 = R.median_profile(d['AV'], 2 * d['H2'], ab)
    _, mh = R.median_profile(d['AV'], d['H'], ab)
    _, mcp = R.median_profile(d['AV'], d['C+'], ab)
    _, mc = R.median_profile(d['AV'], d['C'], ab)

    print('== headline ==')
    print('A_front %.4f, face chi (reference) %.2f' % (d['A_front'], ref['chi'][0]))
    print('H/H2 crossing A_V    %.3f   ref %.3f'
          % (cross(mh, m2, xa), cross(ref['H'], 2 * ref['H2'], ref['AV'])))
    cr = cross(ref['C+'], ref['C'], ref['AV'])
    print('C+ = C at A_V        %.3f   ref %s'
          % (cross(mcp, mc, xa), 'never' if np.isnan(cr) else '%.3f' % cr))
    s = (d['AV'] >= 0.7) & (d['AV'] <= 2.0)
    sr = (ref['AV'] >= 0.7) & (ref['AV'] <= 2.0)
    print('PDR T_gas A_V 0.7-2.0  %.0f-%.0f K   ref %.0f-%.0f'
          % (np.percentile(d['Tgas'][s], 5), np.percentile(d['Tgas'][s], 95),
             ref['Tgas'][sr].min(), ref['Tgas'][sr].max()))

    print('\n== selected depths (MOCASSIN / reference) ==')
    print('A_V  cells  ' + '  '.join('%-17s' % k for k in KEYS[:7]))
    rat = {k: [] for k in KEYS}
    cells = []
    for av in DEPTHS:
        sel = np.abs(d['AV'] - av) <= 0.05
        cells.append(sel.sum())
        row = []
        for k in KEYS:
            m, r = np.median(d[k][sel]), at(ref, k, av)
            rat[k].append(m / r if r > 0 else np.nan)
            row.append('%.3g / %.3g' % (m, r))
        print('%.2f %5d  ' % (av, sel.sum()) + '  '.join('%-17s' % x for x in row[:7]))
    print('cells per bin %d-%d' % (min(cells), max(cells)))

    print('\n== MOCASSIN / reference at the selected depths ==')
    print('A_V    ' + ' '.join('%7.2f' % a for a in DEPTHS))
    for k in KEYS:
        print('%-6s ' % k + ' '.join('%7.3g' % v for v in rat[k]))

    print('\n== the rest of what the page states ==')
    pdr = (d['zone'] == 1) & (d['chi'] > 0)    # an edge cell can get no FUV packet
    k_m = -np.polyfit(d['AV'][pdr], np.log(d['chi'][pdr]), 1)[0]
    k_r = -np.polyfit(ref['AV'], np.log(ref['chi']), 1)[0]
    print('field e-folding per magnitude: MOCASSIN %.2f (all PDR cells), reference %.2f'
          % (k_m, k_r))
    xm, mh2 = R.median_profile(d['AV'], d['H2'], ab)
    rh2 = np.interp(xm, ref['AV'], ref['H2'], left=np.nan, right=np.nan)
    ok = np.isfinite(rh2) & np.isfinite(mh2)
    print('H2 MOCASSIN = reference at A_V %.3f' % cross(rh2[ok], mh2[ok], xm[ok]))
    for nm, sp in (('O+', 'O+'), ('He+', 'He+'), ('CO', 'CO')):
        x2, mm = R.median_profile(d['AV'], d[sp], ab)
        rr = np.interp(x2, ref['AV'], ref[sp], left=np.nan, right=np.nan)
        q = np.isfinite(rr) & np.isfinite(mm) & (rr > 0)
        print('%-4s MOCASSIN/ref over the PDR bins: %.3g - %.3g' % (nm, np.nanmin(mm[q] / rr[q]), np.nanmax(mm[q] / rr[q])))
    hb = ref['ab'][:, R.SPEC.index('H')] + 2 * ref['ab'][:, R.SPEC.index('H2')] \
        + ref['ab'][:, R.SPEC.index('H+')]
    carbon = [i for i, s in enumerate(R.SPEC) if 'C' in s]  # one C each, HCO+ too
    cb = ref['ab'][:, carbon].sum(1)
    print('reference budget: max |x(H)+2x(H2)+x(H+) - 1| %.1e; carbon %.4g - %.4g'
          % (np.abs(hb - 1).max(), cb.min(), cb.max()))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
