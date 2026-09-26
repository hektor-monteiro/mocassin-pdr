#!/usr/bin/env python3
"""D-352 stage 1: is the removal of pdrZone and the run-time switches
physics-neutral?  Compares a run of the new binary against one of the old at
the same randomSeed, rank count and iteration count.

Prediction (DEVLOG D-352, committed before the run):
  1. every output file except pdrGrid.out byte-identical; pdrGrid.out
     identical in every retained column (v1 cols 1-5 -> v2 cols 0-4, and the
     abundances);
  2. every [D205] per-pass line of the run log identical.

Usage: d352_identity.py <new-run> <old-run>
"""
import filecmp
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R                                   # noqa: E402

new, old = sys.argv[1], sys.argv[2]
no, oo = os.path.join(new, 'output'), os.path.join(old, 'output')

print('1. output files')
bad = 0
for f in sorted(os.listdir(oo)):
    if f == 'pdrGrid.out':
        continue
    if not os.path.exists(os.path.join(no, f)):
        print(f'   MISSING    {f}'); bad += 1; continue
    same = filecmp.cmp(os.path.join(oo, f), os.path.join(no, f), shallow=False)
    print(f"   {'identical ' if same else 'DIFFERENT '} {f}")
    bad += not same

t = open(os.path.join(oo, 'grid0.out')).read().split()
n = int(t[1]) * int(t[2]) * int(t[3])
a, b = R.read_pdrgrid(oo, n), R.read_pdrgrid(no, n)
if a['zone'] is None or b['zone'] is not None:
    print('   expected the old run in layout v1 and the new in v2')
for k in ['chi', 'AV', 'cool', 'heat', 'heatPE', 'ab']:
    same = np.array_equal(a[k], b[k])
    print(f"   {'identical ' if same else 'DIFFERENT '} pdrGrid.out {k}"
          + ('' if same else f"  max |diff| {np.nanmax(np.abs(a[k]-b[k])):.3e}"))
    bad += not same

print('2. [D205] per-pass lines in the run log')
la = [l for l in open(os.path.join(old, 'run.log')) if '[D205]' in l]
lb = [l for l in open(os.path.join(new, 'run.log')) if '[D205]' in l]
same = la == lb
print(f"   {'identical ' if same else 'DIFFERENT '} {len(la)} old, {len(lb)} new")
bad += not same

print('HELD - byte-identical' if bad == 0 else f'FAILED - {bad} difference(s)')
