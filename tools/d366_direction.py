#!/usr/bin/env python3
"""D-366: the grid-direction test for a spherically symmetric run.

Median deviation of ln q from its radial profile (tools/d365_noise.py), split
by direction - mu = max|x_i|/r, 1 on a grid axis and 0.577 on the diagonal -
and for cells lying on a symmetry plane, by A_V band. In a correct model every
row is zero to within the noise. The mirror-reflection defect D-366 fixed
showed as +0.29 (axis), -0.16 (diagonal) and +0.44 (planes) in ln chi at
A_V 2.5-3.5 on hiipdr.

    python tools/d366_direction.py runs/d366-fix/output
"""
import sys, os, numpy as np
sys.path.insert(0, 'tools')
import d365_noise as N, d260_roellig as R
p = sys.argv[1]
d = N.read(p)
t = open(os.path.join(p, 'grid0.out')).read().split()
nx = int(t[1]); xa = np.array(t[7:7+nx], float)
n = nx**3; off = 7 + 3*nx
act = np.array(t[off:off+n*3:3], float).astype(int) > 0
I, J, K = np.meshgrid(np.arange(nx), np.arange(nx), np.arange(nx), indexing='ij')
I, J, K = I.ravel()[act], J.ravel()[act], K.ravel()[act]
X, Y, Z = xa[I], xa[J], xa[K]
rr = np.sqrt(X**2+Y**2+Z**2)
mu = np.maximum(np.maximum(X, Y), Z) / np.where(rr > 0, rr, 1)
plane = (I == 0) | (J == 0) | (K == 0)
rb = N.band_radii(d)
inner = (d['r'] < 0.97*d['rmax']) & (d['x(H+)'] < 0.3)
for q in ['chi', 'Tgas', 'x(CO)']:
    ok = inner & (d[q] > 0)
    lq = np.log(d[q][ok]); dev = lq - N.smooth(d['r'][ok], lq, d['dr'])
    m, pl, r0 = mu[ok], plane[ok], d['r'][ok]
    print(f'\n{q}: median deviation by direction (rows) and A_V band (cols)')
    for lo, hi, lab in [(0.95, 1.01, 'axis   mu>0.95'), (0.8, 0.95, 'mu 0.80-0.95'),
                        (0.65, 0.8, 'mu 0.65-0.80'), (0.5, 0.65, 'diag   mu<0.65')]:
        row = ''
        for b in rb:
            s = (r0 >= b[0]) & (r0 <= b[1]) & (m >= lo) & (m < hi) & ~pl
            row += '  %+7.3f (%5d)' % (np.median(dev[s]) if s.sum() else np.nan, s.sum())
        print('  %-15s' % lab + row)
    row = ''
    for b in rb:
        s = (r0 >= b[0]) & (r0 <= b[1]) & pl
        row += '  %+7.3f (%5d)' % (np.median(dev[s]) if s.sum() else np.nan, s.sum())
    print('  %-15s' % 'on a sym plane' + row)
