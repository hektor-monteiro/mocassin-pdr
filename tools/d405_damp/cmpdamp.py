#!/usr/bin/env python3
"""D-405 (L-49): two arms of a seeded pair, cell by cell.

    cmpdamp.py <damped run> <undamped run>

The fixtures are octants of a sphere on a cubic grid with equal axes, so the
cells (i,j,k), (j,i,k), (k,j,i), ... are the same cell of the model: what
separates them inside one run is the Monte Carlo field and nothing else. The
spread of a quantity over such a set is therefore that run's own noise in
the written model, measured without a second run.

Per band of A_V this prints, for each quantity,
  - the noise of each arm (median over the sets of the standard deviation of
    ln q) and their ratio; independent noise through a blend of 0.75 new and
    0.25 old predicts undamped / damped = 1.29;
  - the two arms against each other: the mean of ln(undamped / damped) over
    the band with its standard error (a shift of the model), and the median
    of |ln| (cell-to-cell, which noise alone puts at about 0.67 of the two
    arms' noise added in quadrature).
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import d260_roellig as R                                   # noqa: E402

KEYS = ('Tgas', 'e-', 'H+', 'H', 'H2', 'C+', 'C', 'CO', 'O', 'OH')


def ijk(run):
    t = open(os.path.join(run, 'output', 'grid0.out')).read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    n = nx * ny * nz
    off = 7 + nx + ny + nz
    act = np.array(t[off:off + n * 3:3], float).astype(int) > 0
    idx = np.where(act)[0]
    return np.stack([idx // (ny * nz), (idx // nz) % ny, idx % nz], axis=1), (nx, ny, nz)


def orbits(c, shape):
    assert shape[0] == shape[1] == shape[2], 'the symmetry needs a cubic grid'
    s = np.sort(c, axis=1)
    key = (s[:, 0] * shape[1] + s[:, 1]) * shape[2] + s[:, 2]
    order = np.argsort(key, kind='stable')
    k = key[order]
    cut = np.flatnonzero(np.diff(k)) + 1
    return [g for g in np.split(order, cut) if len(g) >= 3]


a, b = sys.argv[1], sys.argv[2]
A, B = R.read_run(a), R.read_run(b)
c, shape = ijk(a)
assert len(c) == len(A['r']) == len(B['r'])
orb = orbits(c, shape)
print('damped   %s\nundamped %s' % (a, b))
print('%d active cells, %d sets of 3 or 6 equivalent cells holding %d of them' % (len(c), len(orb), sum(len(g) for g in orb)))

neutral = (A['zone'] == 1) & (B['zone'] == 1)
ion = (A['zone'] == 0) & (B['zone'] == 0)
print('ionized in both arms %d, neutral in both %d, in one only %d' % (ion.sum(), neutral.sum(), len(c) - ion.sum() - neutral.sum()))
av = A['AV']
q = np.quantile(av[neutral], [0, 0.05, 0.15, 0.3, 0.5, 0.75, 1.0])
bands = [('ionized', ion)] + [('A_V %.2f-%.2f' % (q[i], q[i + 1]), neutral & (av >= q[i]) & (av <= q[i + 1])) for i in range(len(q) - 1)]

om = np.array([np.median(av[g]) for g in orb])            # a set's A_V
oz = np.array([bool(np.all(neutral[g])) for g in orb]), np.array([bool(np.all(ion[g])) for g in orb])


def noise(d, key, sel):
    v = []
    for g, ok in zip(orb, sel):
        if not ok:
            continue
        x = d[key][g]
        if np.all(x > 0):
            v.append(np.std(np.log(x), ddof=1))
    return (float(np.median(v)), len(v)) if len(v) >= 5 else (np.nan, len(v))


for name, m in bands:
    if m.sum() < 20:
        continue
    if name == 'ionized':
        sel = oz[1]
    else:
        lo, hi = [float(x) for x in name.split()[1].split('-')]
        sel = oz[0] & (om >= lo) & (om <= hi)
    print('\n%s   cells %d, sets %d' % (name, m.sum(), sel.sum()))
    print('  %-5s %11s %11s   %9s %9s %6s   %9s %8s %9s %7s' % ('', 'median d', 'median u', 'noise d', 'noise u', 'u/d', 'mean ln', '+-', 'med |ln|', '/noise'))
    for k in KEYS:
        x, y = A[k][m], B[k][m]
        ok = (x > 0) & (y > 0)
        if ok.sum() < 20:
            continue
        na, nn = noise(A, k, sel)
        nb, _ = noise(B, k, sel)
        d = np.log(y[ok] / x[ok])
        exp = 0.6745 * np.hypot(na, nb)
        print('  %-5s %11.4e %11.4e   %9.2e %9.2e %6.2f   %+9.2e %8.1e %9.2e %7.2f' % (
            k, np.median(x[ok]), np.median(y[ok]), na, nb, nb / na if na > 0 else np.nan,
            d.mean(), d.std(ddof=1) / np.sqrt(len(d)), np.median(np.abs(d)), np.median(np.abs(d)) / exp if exp > 0 else np.nan))

pdrA, pdrB = A['zone'] == 1, B['zone'] == 1


def cross(d):
    """A_V of the H/H2 crossing: where 2 n(H2) = n(H), from the medians in bins of A_V"""
    z = d['zone'] == 1
    e = np.linspace(d['AV'][z].min(), d['AV'][z].max(), 80)
    xc, r = [], []
    for i in range(len(e) - 1):
        s = z & (d['AV'] >= e[i]) & (d['AV'] < e[i + 1])
        if s.sum() >= 3 and np.median(d['H'][s]) > 0:
            xc.append(0.5 * (e[i] + e[i + 1]))
            r.append(np.log(2 * np.median(d['H2'][s]) / np.median(d['H'][s])))
    xc, r = np.array(xc), np.array(r)
    j = np.flatnonzero((r[:-1] < 0) & (r[1:] >= 0))
    if len(j) == 0:
        return np.nan
    j = j[0]
    return float(xc[j] - r[j] * (xc[j + 1] - xc[j]) / (r[j + 1] - r[j]))


print('\nH/H2 crossing (2 n(H2) = n(H), medians in 79 bins of A_V): damped %.4f, undamped %.4f' % (cross(A), cross(B)))
print('front (smallest A_V with x(H+) < 0.3): damped %.4f, undamped %.4f' % (A['A_front'], B['A_front']))
