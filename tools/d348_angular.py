#!/usr/bin/env python3
"""D-348: the angular model (D-347) against the validated baseline.

Written and committed BEFORE runs/d348-angular finished, so the quantities
compared are the ones committed to rather than ones chosen after the fact.

What changed. The reaction rates used to see only the direct stellar field,
chi0 * exp(-gamma*A_V) on the source-ward column. They now also see the MC's
own diffuse FUV (Jdif), spread over scattering sites along twelve HEALPix
directions, each site shielded by its two-leg column N(star->P) + N(P->C).
The heating already took the whole MC field; after this the chemistry does
too, to within +2..+8% in the H2 band (smoke test, see D-348).

The prediction, from the smoke test's first PDR iteration at FIXED abundances:
the H2 photodissociation rate rises x3.4 at A_V 0.8-1.2, x8.6 at 1.2-1.6,
x19 at 1.6-2.1 and x60 at 2.1-2.6, and nearly all of that is the diffuse
field's MAGNITUDE - the two-leg columns take back only 5-30% of it against
carrying the same field on the source-ward column. So:

  1. the H/H2 crossing moves DEEPER than s1001's A_V 1.168, into 1.8-2.6;
  2. a molecular zone still exists (2 x(H2) > x(H) somewhere), because at
     A_V > 2.6 the rate stays ~40x below its value at the old crossing;
  3. x(H2) and x(CO) fall at every PDR depth sampled, and the C+ = C
     crossing moves deeper;
  4. the ionization front moves by less than 2% and T_dust by less than 1%
     (neither is set by the molecular chemistry);
  5. x(HI) + 2 x(H2) + x(HII) = 1 holds to the baseline's precision.

T_gas is not predicted either way: the heating already took the MC field,
and what moves is the coolant mix.

Falsified by: the crossing moving shallower or by less than 0.05 in A_V;
x(H2) rising at any sampled PDR depth; no molecular zone at all; the front
or the dust moving by more than stated; the hydrogen budget breaking.

Both runs use randomSeed 1001 and 14 ranks, so the difference is the change
and nothing else (D-334).

    ~/miniforge3/envs/astro/bin/python tools/d348_angular.py \\
        runs/d348-angular runs/d334-hiipdr/s1001
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d304_budget as B
import d260_roellig as R
from d326_check import cross, pdr_depths, prof


def fronts(m):
    nh = m['H'] + 2 * m['H2'] + m['H+']
    er = np.linspace(0, m['r'].max() * 1.001, 200)
    rc, xc = R.median_profile(m['r'], m['H+'] / nh, er)
    av = m['AV'][m['zone'] == 1]
    edges = np.geomspace(max(av.min(), 1e-3), av.max(), 40)
    x1, h = R.median_profile(m['AV'], m['H'], edges)
    _, h2 = R.median_profile(m['AV'], m['H2'], edges)
    _, cp = R.median_profile(m['AV'], m['C+'], edges)
    _, cc = R.median_profile(m['AV'], m['C'], edges)
    _, co = R.median_profile(m['AV'], m['CO'], edges)
    return (cross(rc, xc, 0.5), cross(x1, 2 * h2 / h, 1.0),
            cross(x1, cp / cc, 1.0), cross(x1, co / cc, 1.0),
            np.nanmax(2 * h2 / h))


def last_table(run):
    """The final [D348] block of the run log."""
    try:
        lines = open(os.path.join(run, 'run.log'), errors='replace').readlines()
    except OSError:
        return []
    starts = [i for i, l in enumerate(lines) if '[D348] diffuse rays' in l]
    if not starts:
        return []
    out = []
    for l in lines[starts[-1]:]:
        if '[D348]' not in l:
            break
        out.append(l.rstrip())
    return out


def main(new, old):
    a, b = B.read_moc(new), B.read_moc(old)
    avs = pdr_depths(a, n=6)
    print('D-348: the angular model - direct ray plus diffuse scattering sites')
    print('  new %s\n  old %s' % (new, old))
    print('  both at randomSeed 1001 - the difference is the change, exactly\n')

    print('=== the fronts (prediction 1-4) ===')
    print('  %-3s %12s %10s %10s %10s %12s' % ('', 'IF [pc]', 'H/H2 A_V',
                                              'C+=C A_V', 'CO=C A_V', 'max 2H2/H'))
    fa, fb = fronts(a), fronts(b)
    for tag, f in (('new', fa), ('old', fb)):
        print('  %-3s %12.4f %10.4f %10.4f %10.4f %12.4f' % ((tag,) + tuple(f)))
    print('  IF new/old %.4f' % (fa[0] / fb[0]))

    print('\n=== abundances at the new model\'s PDR depths (prediction 3) ===')
    print('  A_V  |       x(H2) new/old |       x(CO) new/old |'
          '        x(C) new/old |       x(C+) new/old')
    print('  ' + '-' * 92)
    # read_run gives number densities; per H nucleus is what is compared
    for m in (a, b):
        for sp in ('H2', 'CO', 'C', 'C+'):
            m['x' + sp] = m[sp] / m['nh']
    for i, av in enumerate(avs):
        row = ['%4.2f' % av]
        for sp in ('H2', 'CO', 'C', 'C+'):
            va, vb = prof(a, 'x' + sp, avs)[i], prof(b, 'x' + sp, avs)[i]
            row.append('%10.3e %8.3f' % (va, va / vb if vb else np.nan))
        print('  ' + ' | '.join(row))

    print('\n=== must not move (prediction 4) ===')
    for i, av in enumerate(avs):
        va, vb = prof(a, 'Tdust', avs)[i], prof(b, 'Tdust', avs)[i]
        print('  T_dust A_V %.2f  %8.3f -> %8.3f   %.4f'
              % (av, vb, va, va / vb if vb else np.nan))

    print('\n=== hydrogen budget x(HI)+2x(H2)+x(HII) (prediction 5) ===')
    for tag, m in (('new', a), ('old', b)):
        s = ((m['H'] + 2 * m['H2'] + m['H+']) / m['nh'])[m['zone'] == 1]
        print('  %-3s  PDR cells %6d   min %.6f   max %.6f   max|dev| %.2e'
              % (tag, s.size, s.min(), s.max(), np.abs(s - 1).max()))

    print('\n=== gas temperature (not predicted either way) ===')
    for i, av in enumerate(avs):
        va, vb = prof(a, 'Tgas', avs)[i], prof(b, 'Tgas', avs)[i]
        print('  T_gas A_V %.2f   %8.2f -> %8.2f   %.4f'
              % (av, vb, va, va / vb if vb else np.nan))

    print('\n=== the new run\'s last [D348] table ===')
    for l in last_table(new):
        print(l)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
