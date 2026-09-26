#!/usr/bin/env python3
"""D-350: the photorates on MOCASSIN's own field, against the pre-D-348 model.

Written and committed BEFORE runs/d350-window finished, so the quantities
compared are the ones committed to rather than ones chosen after the fact.

What changed, against the baseline (runs/d350-base11: commit c7a7075, the
physics of s1001, at 11 iterations):
  - every photorate is driven by MOCASSIN's local field - the direct part
    (Jste - Jdif) on the source-ward column, the diffuse part (Jdif) on the
    D-348 scattering sites' two-leg columns - at A_V = 0, where the baseline
    used 3D-PDR's prescription chi0*exp(-gamma*A_V);
  - H2, HD, CO and C I take each part's Lyman-Werner-window field
    (ray_lw_factor); the C I continuum term is dropped, the MC carrying it;
  - the zone test on the shielding columns is gone.

D-349 measured the window field at 2.0-2.8x the prescription's at every depth,
and the band field at 1.3x (front) to 39x (A_V 2.5). So:

  1. the H/H2 crossing moves DEEPER than the baseline's, but by much less than
     D-348's (1.168 -> 1.635): into A_V 1.25-1.45;
  2. x(H2) and x(CO) fall against the baseline at every sampled PDR depth, and
     at A_V >= 1.3 by less than D-348 made them fall (D-348's band field is the
     larger there; nearer the front the window factor exceeds D-348's, so no
     bracket is claimed at A_V < 1.3);
  3. C+ = C moves by less than 0.05 (it is MOCASSIN's, D-162);
  4. the ionization front moves by less than 1% and T_dust by less than 1%;
  5. x(HI) + 2 x(H2) + x(HII) = 1 holds to better than 3e-4;
  6. the zone test's removal is small: non-zone cells supply more than 1% of
     the H2 column in fewer than 1% of PDR cells;
  7. the plumbing: in the first A_V bin the direct window field over the old
     prescription's H2 field is 1.9-2.6, the star's window share over
     Draine's (D-349: 1.97, and 2.46 measured at A_V 0.07);
  8. the baseline reproduces s1001's first 11 iterations to nine digits.

Falsified by any of them failing. T_gas and the minor species are not
predicted.

    ~/miniforge3/envs/astro/bin/python tools/d350_window.py \\
        runs/d350-window runs/d350-base11
"""
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d304_budget as B
from d326_check import pdr_depths, prof
from d348_angular import fronts

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D348 = os.path.join(HERE, 'runs', 'd348-angular')
S1001 = os.path.join(HERE, 'runs', 'd334-hiipdr', 's1001')


def last_block(run, tag):
    try:
        lines = open(os.path.join(run, 'run.log'), errors='replace').readlines()
    except OSError:
        return []
    starts = [i for i, l in enumerate(lines) if tag in l]
    if not starts:
        return []
    out = []
    for l in lines[starts[-1]:]:
        if '[D350]' not in l:
            break
        out.append(l.rstrip())
    return out


def trace(run):
    t = []
    for l in open(os.path.join(run, 'run.log'), errors='replace'):
        m = re.search(r'Iteration\s+(\d+)\s*;\s*Total:\s*([0-9.Ee+-]+)', l)
        if m:
            t.append((int(m.group(1)), m.group(2)))
    return t


def xs(m):
    for sp in ('H2', 'CO', 'C', 'C+'):
        m['x' + sp] = m[sp] / m['nh']


def main(new, base):
    a, b = B.read_moc(new), B.read_moc(base)
    c, d = B.read_moc(D348), B.read_moc(S1001)
    for m in (a, b, c, d):
        xs(m)
    avs = pdr_depths(a, n=6)
    print('D-350: the photorates on MOCASSIN\'s own field')
    print('  new %s\n  base %s\n  bracket: D-348 %s against s1001\n' % (new, base, D348))

    print('=== the fronts (predictions 1, 3, 4) ===')
    print('  %-6s %10s %10s %10s %12s' % ('', 'IF [pc]', 'H/H2 A_V', 'C+=C A_V', 'max 2H2/H'))
    fa, fb, fc = fronts(a), fronts(b), fronts(c)
    for tag, f in (('new', fa), ('base', fb), ('D-348', fc)):
        print('  %-6s %10.4f %10.4f %10.4f %12.4f' % (tag, f[0], f[1], f[2], f[4]))
    print('  IF new/base %.4f   C+=C new-base %+.4f' % (fa[0] / fb[0], fa[2] - fb[2]))

    print('\n=== abundances (prediction 2): new/base, and D-348/s1001 beside it ===')
    print('  A_V  |  x(H2) new/base  D348/s1001 |  x(CO) new/base  D348/s1001 |  x(C) new/base')
    for i, av in enumerate(avs):
        r = lambda m1, m2, k: prof(m1, k, avs)[i] / prof(m2, k, avs)[i]
        print('  %4.2f |     %8.3f      %8.3f  |     %8.3f      %8.3f  |    %8.3f'
              % (av, r(a, b, 'xH2'), r(c, d, 'xH2'), r(a, b, 'xCO'), r(c, d, 'xCO'),
                 r(a, b, 'xC')))

    print('\n=== must not move (prediction 4) ===')
    for i, av in enumerate(avs):
        va, vb = prof(a, 'Tdust', avs)[i], prof(b, 'Tdust', avs)[i]
        print('  T_dust A_V %.2f  %8.3f -> %8.3f   %.4f' % (av, vb, va, va / vb))

    print('\n=== hydrogen budget (prediction 5) ===')
    for tag, m in (('new', a), ('base', b)):
        s = ((m['H'] + 2 * m['H2'] + m['H+']) / m['nh'])[m['zone'] == 1]
        print('  %-4s  PDR cells %6d   max|dev| %.2e' % (tag, s.size, np.abs(s - 1).max()))

    print('\n=== gas temperature (not predicted) ===')
    for i, av in enumerate(avs):
        va, vb = prof(a, 'Tgas', avs)[i], prof(b, 'Tgas', avs)[i]
        print('  T_gas A_V %.2f   %8.2f -> %8.2f   %.4f' % (av, vb, va, va / vb))

    print('\n=== the baseline against s1001, iteration by iteration (prediction 8) ===')
    tb, ts = dict(trace(base)), dict(trace(S1001))
    same = [k for k in sorted(tb) if k in ts and tb[k] == ts[k]]
    print('  iterations with identical convergence to all printed digits: %d of %d'
          % (len(same), len(tb)))
    for k in sorted(tb):
        if k not in same:
            print('  differs at iteration %d: %s vs %s' % (k, tb[k], ts.get(k)))

    print('\n=== the new run\'s last [D350] blocks (predictions 6, 7) ===')
    zl = [l.rstrip() for l in open(os.path.join(new, 'run.log'), errors='replace')
          if 'zone test gone' in l]
    if zl:
        print(zl[-1])
    for l in last_block(new, '[D350] photorate field'):
        print(l)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
