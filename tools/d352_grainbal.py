#!/usr/bin/env python3
"""D-352 stage 2: the grain energy balance on MOCASSIN's own photoelectric
and gas-grain terms, against stage 1 at the same seed.

Prediction (DEVLOG D-352, committed before the run):
  3. T_dust rises: by < 0.2% at A_V < 0.8 and 0.1-1.5% at A_V > 1.6;
  4. ionization front < 0.1%; H/H2 crossing and C+ = C < 0.03 in A_V;
  5. T_gas and bin-mean x(H2), x(CO) within twice the per-bin scatter between
     the two runs' last iterations (the pair decorrelates from iteration 4).

Usage: d352_grainbal.py <stage-2 run> <stage-1 run>
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R                                   # noqa: E402
from d348_angular import fronts                              # noqa: E402

new, old = sys.argv[1], sys.argv[2]
a, b = R.read_run(new), R.read_run(old)
edges = [0, .2, .47, .8, 1.2, 1.6, 2.1, 2.6, 3.05]

print('3-5. by A_V bin (new/old, means over the bin)')
print('  A_V bin    cells  T_dust    T_gas     x(H2)     x(CO)    '
      'sd(T_dust ratio) per cell')
for lo, hi in zip(edges[:-1], edges[1:]):
    m = (b['AV'] >= lo) & (b['AV'] < hi)
    if m.sum() == 0:
        continue
    nh_a = a['H'] + 2 * a['H2'] + a['H+']
    nh_b = b['H'] + 2 * b['H2'] + b['H+']
    rT = a['Tdust'][m].mean() / b['Tdust'][m].mean()
    rG = a['Tgas'][m].mean() / b['Tgas'][m].mean()
    rH2 = (a['H2'] / nh_a)[m].mean() / (b['H2'] / nh_b)[m].mean()
    rCO = (a['CO'] / nh_a)[m].mean() / max((b['CO'] / nh_b)[m].mean(), 1e-99)
    sd = np.std(a['Tdust'][m] / b['Tdust'][m])
    print(f'  {lo:4.2f}-{hi:4.2f} {m.sum():6d}  {rT:8.5f}  {rG:8.5f}  '
          f'{rH2:8.5f}  {rCO:8.5f}   {sd:.2e}')

fa, fb = fronts(a), fronts(b)
print('fronts                     new        old')
for k, name in enumerate(['ionization front [pc]', 'H/H2 crossing A_V',
                          'C+ = C A_V', 'CO = C A_V', 'max 2x(H2)/x(H)']):
    print(f'  {name:24s} {fa[k]:9.4f}  {fb[k]:9.4f}')
