#!/usr/bin/env python3
"""D-340: did mirror reflection in computeRayColumns change the PDR?

Written and committed BEFORE runs/d340-mirror finished, so the quantities
compared are the ones committed to rather than ones chosen after the fact.

The prediction, in one line: the shielding columns can only GROW - about half
the twelve rays were stopping early at a mirror wall and now run on - so the
gas is better shielded, H2 and CO form SHALLOWER, and the H/H2 crossing moves
to SMALLER A_V.

Falsified by: the crossing moving deeper; H2 or CO falling; the ionization
front moving (it is set by the ionizing continuum, which this does not touch);
or the dust temperature moving (shielding is an FUV-band effect on the gas
chemistry, not on grain heating).

Size is NOT predicted. D-259 measured the truncation at 59% of depth, but what
that is worth in abundance depends on where each ray sits on the self-shielding
curve, which is steeply non-linear.

Both runs use randomSeed 1001, so the difference carries no Monte Carlo noise
at all (D-334) - this is an exact comparison, not a comparison within scatter.

    ~/miniforge3/envs/astro/bin/python tools/d340_mirror.py \\
        runs/d340-mirror runs/d334-hiipdr/s1001
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d304_budget as B
import d260_roellig as R
from d326_check import cross, pdr_depths, prof


def main(new, old):
    a, b = B.read_moc(new), B.read_moc(old)
    avs = pdr_depths(a, n=5)
    print('D-340: mirror reflection in computeRayColumns')
    print('  new %s\n  old %s' % (new, old))
    print('  both at randomSeed 1001 - the difference is the change, exactly\n')
    print('  sample depths: ' + ', '.join('%.2f' % v for v in avs))

    print('\n=== what the prediction says must move ===')
    print('  A_V |      x(H2) new/old |      x(CO) new/old |       x(C) new/old')
    print('  ' + '-' * 66)
    for i, av in enumerate(avs):
        row = ['%4.2f' % av]
        for sp in ('H2', 'CO', 'C'):
            va, vb = prof(a, sp, avs)[i], prof(b, sp, avs)[i]
            row.append('%9.3e %8.3f' % (va, va / vb if vb else np.nan))
        print('  ' + ' | '.join(row))

    print('\n=== what must NOT move ===')
    print('  %-12s %10s %10s %8s' % ('quantity', 'new', 'old', 'new/old'))
    for lab, key in (('T_dust', 'Tdust'),):
        for i, av in enumerate(avs):
            va, vb = prof(a, key, avs)[i], prof(b, key, avs)[i]
            print('  %-12s %10.3f %10.3f %8.4f'
                  % ('%s A_V %.2f' % (lab, av), va, vb, va / vb if vb else np.nan))

    print('\n=== the fronts ===')
    for m, tag in ((a, 'new'), (b, 'old')):
        nh = m['H'] + 2 * m['H2'] + m['H+']
        er = np.linspace(0, m['r'].max() * 1.001, 200)
        rc, xc = R.median_profile(m['r'], m['H+'] / nh, er)
        av = m['AV'][m['zone'] == 1]
        edges = np.geomspace(max(av.min(), 1e-3), av.max(), 40)
        x1, h = R.median_profile(m['AV'], m['H'], edges)
        _, h2 = R.median_profile(m['AV'], m['H2'], edges)
        _, cp = R.median_profile(m['AV'], m['C+'], edges)
        _, cc = R.median_profile(m['AV'], m['C'], edges)
        print('  %-3s  ionization front %.4f pc   H/H2 A_V %.4f   C+=C A_V %.4f'
              % (tag, cross(rc, xc, 0.5), cross(x1, 2 * h2 / h, 1.0),
                 cross(x1, cp / cc, 1.0)))

    print('\n=== gas temperature (not predicted either way) ===')
    for i, av in enumerate(avs):
        va, vb = prof(a, 'Tgas', avs)[i], prof(b, 'Tgas', avs)[i]
        print('  T_gas A_V %.2f   %8.2f -> %8.2f   %.4f'
              % (av, vb, va, va / vb if vb else np.nan))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
