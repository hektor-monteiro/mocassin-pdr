#!/usr/bin/env python3
"""D-334: the error bar. Spread across an ensemble of runs differing only in
the Monte Carlo seed.

Every comparison this project has published - D-304, D-315, D-320, D-322,
D-328, D-332 - is one draw of MOCASSIN against one run of Cloudy. D-314
measured the scatter once, on a 5^3 fixture, and found 37% in median T_gas.
This measures it on the grid the artifacts are actually drawn on, for the
quantities they actually quote.

Reported as mean, sample standard deviation and full range. The sd over a
handful of draws is itself uncertain - with n draws its own relative error is
about 1/sqrt(2(n-1)) - so the range is printed beside it rather than the sd
being quoted alone.

    ~/miniforge3/envs/astro/bin/python tools/d334_spread.py runs/d334-pn150k/s*
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d304_budget as B
import d260_roellig as R
from d326_check import cross, pdr_depths, pe, prof


def scalars(m):
    """The scalars the artifacts quote, from one run."""
    nh = m['H'] + 2 * m['H2'] + m['H+']
    er = np.linspace(0, m['r'].max() * 1.001, 200)
    rc, xc = R.median_profile(m['r'], m['H+'] / nh, er)
    av = m['AV'][m['zone'] == 1]
    edges = np.geomspace(max(av.min(), 1e-3), av.max(), 40)
    x1, h = R.median_profile(m['AV'], m['H'], edges)
    _, h2 = R.median_profile(m['AV'], m['H2'], edges)
    return {'front (pc)': cross(rc, xc, 0.5),
            'H/H2 A_V': cross(x1, 2 * h2 / h, 1.0),
            'A_V max': float(av.max())}


def report(name, vals):
    v = np.asarray([x for x in vals if np.isfinite(x)], float)
    if v.size < 2:
        print('  %-22s  n=%d  insufficient' % (name, v.size))
        return
    mu, sd = v.mean(), v.std(ddof=1)
    print('  %-22s  %10.4g  +- %-9.3g  (%.2f%%)   range %.4g - %.4g'
          % (name, mu, sd, 100 * sd / abs(mu) if mu else np.nan,
             v.min(), v.max()))


def main(runs):
    ms = [B.read_moc(r) for r in runs]
    print('D-334: run-to-run spread over %d draws' % len(ms))
    for r in runs:
        print('  %s' % r)

    avs = pdr_depths(ms[0], n=5)
    print('\nsample depths: ' + ', '.join('%.2f' % v for v in avs))
    print('  (derived from the first run - L-21)')

    print('\n=== the profile quantities the artifacts quote ===')
    print('  %-22s  %10s  %-12s %8s   %s'
          % ('quantity', 'mean', 'sd', 'rel', 'range'))
    print('  ' + '-' * 74)
    for key, lab, fn in (('Tgas', 'T_gas', prof), ('Tdust', 'T_dust', prof),
                         (None, 'PE heating', None)):
        for i, av in enumerate(avs):
            if fn is None:
                vals = [pe(m, avs)[i] for m in ms]
            else:
                vals = [fn(m, key, avs)[i] for m in ms]
            report('%s A_V %.2f' % (lab, av), vals)
        print()

    print('=== the scalars ===')
    keys = scalars(ms[0]).keys()
    allv = [scalars(m) for m in ms]
    for k in keys:
        report(k, [a[k] for a in allv])

    print('\n=== what this means for the published comparisons ===')
    print('  A ratio against a reference inherits this spread. A disagreement')
    print('  smaller than ~2x the sd above is not a measurement.')


if __name__ == '__main__':
    main(sys.argv[1:])
