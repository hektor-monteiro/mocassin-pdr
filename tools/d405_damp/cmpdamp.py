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
    the band with its standard error, and the median of |ln| (cell-to-cell,
    which noise alone puts at about 0.67 of the two arms' noise added in
    quadrature). The mean of ln is not a shift of the model where a quantity
    scatters widely: a blend is an arithmetic mean and lies above the median
    of what it blends. The medians and the sums are printed beside it.

Then the cells near the carbon turn by C+ / (C+ + C + CO), in bins of 0.1
mag, for each arm: two states, or values between.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import d260_roellig as R                                   # noqa: E402

KEYS = ('Tgas', 'e-', 'H+', 'H', 'H2', 'C+', 'C', 'CO', 'O', 'OH')
QB = (0, 0.05, 0.15, 0.3, 0.5, 0.75, 1.0)


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
        return float('nan')
    j = j[0]
    return float(xc[j] - r[j] * (xc[j + 1] - xc[j]) / (r[j + 1] - r[j]))


def states(d, lo=1.9, hi=2.6, step=0.1):
    """cells of each A_V bin by C+ / (C+ + C + CO): below 0.18, between, above 0.9"""
    f = d['C+'] / (d['C+'] + d['C'] + d['CO'])
    out = []
    for a in np.arange(lo, hi - 1e-9, step):
        m = (d['AV'] >= a) & (d['AV'] < a + step) & (d['zone'] == 1)
        if m.sum() == 0:
            continue
        x = f[m]
        out.append({'lo': float(a), 'hi': float(a + step), 'n': int(m.sum()), 'low': int((x < 0.18).sum()),
                    'mid': int(((x >= 0.18) & (x <= 0.9)).sum()), 'high': int((x > 0.9).sum()),
                    'T': float(np.median(d['Tgas'][m]))})
    return out


def compare(a, b):
    A, B = R.read_run(a), R.read_run(b)
    c, shape = ijk(a)
    assert len(c) == len(A['r']) == len(B['r'])
    orb = orbits(c, shape)
    neutral = (A['zone'] == 1) & (B['zone'] == 1)
    ion = (A['zone'] == 0) & (B['zone'] == 0)
    av = A['AV']
    q = np.quantile(av[neutral], QB)
    bands = [('ionized', ion, None)] + [('A_V %.2f-%.2f' % (q[i], q[i + 1]), neutral & (av >= q[i]) & (av <= q[i + 1]), (q[i], q[i + 1]))
                                        for i in range(len(q) - 1)]
    om = np.array([np.median(av[g]) for g in orb])
    on = np.array([bool(np.all(neutral[g])) for g in orb])
    oi = np.array([bool(np.all(ion[g])) for g in orb])

    def noise(d, key, sel):
        v = []
        for g, ok in zip(orb, sel):
            if not ok:
                continue
            x = d[key][g]
            if np.all(x > 0):
                v.append(np.std(np.log(x), ddof=1))
        return float(np.median(v)) if len(v) >= 5 else float('nan')

    out = {'ncell': int(len(c)), 'nsets': len(orb), 'inset': int(sum(len(g) for g in orb)), 'nion': int(ion.sum()),
           'nneutral': int(neutral.sum()), 'bands': [], 'cross': [cross(A), cross(B)], 'front': [float(A['A_front']), float(B['A_front'])],
           'states': [states(A), states(B)], 'sums': {}}
    for k in ('C', 'C+', 'CO', 'H', 'H2', 'OH'):
        out['sums'][k] = float(B[k][neutral].sum() / A[k][neutral].sum())
    for name, m, lim in bands:
        if m.sum() < 20:
            continue
        sel = oi if lim is None else on & (om >= lim[0]) & (om <= lim[1])
        row = {'name': name, 'lim': lim, 'n': int(m.sum()), 'sets': int(sel.sum()), 'q': {}}
        for k in KEYS:
            x, y = A[k][m], B[k][m]
            ok = (x > 0) & (y > 0)
            if ok.sum() < 20:
                continue
            na, nb = noise(A, k, sel), noise(B, k, sel)
            d = np.log(y[ok] / x[ok])
            exp = 0.6745 * np.hypot(na, nb)
            row['q'][k] = {'med': [float(np.median(x[ok])), float(np.median(y[ok]))], 'mean': [float(x.mean()), float(y.mean())],
                           'noise': [na, nb], 'ratio': nb / na if na > 0 else float('nan'),
                           'mln': float(d.mean()), 'eln': float(d.std(ddof=1) / np.sqrt(len(d))), 'mabs': float(np.median(np.abs(d))),
                           'rel': float(np.median(np.abs(d)) / exp) if exp > 0 else float('nan')}
        out['bands'].append(row)
    return out


if __name__ == '__main__':
    a, b = sys.argv[1], sys.argv[2]
    C = compare(a, b)
    print('damped   %s\nundamped %s' % (a, b))
    print('%d active cells, %d sets of 3 or 6 equivalent cells holding %d of them' % (C['ncell'], C['nsets'], C['inset']))
    print('ionized in both arms %d, neutral in both %d, in one only %d' % (C['nion'], C['nneutral'], C['ncell'] - C['nion'] - C['nneutral']))
    for row in C['bands']:
        print('\n%s   cells %d, sets %d' % (row['name'], row['n'], row['sets']))
        print('  %-5s %11s %11s %7s   %9s %9s %6s   %9s %8s %9s %7s   %s' % (
            '', 'median d', 'median u', 'u/d-1%', 'noise d', 'noise u', 'u/d', 'mean ln', '+-', 'med |ln|', '/noise', 'mean u/d-1%'))
        for k, v in row['q'].items():
            print('  %-5s %11.4e %11.4e %+7.2f   %9.2e %9.2e %6.2f   %+9.2e %8.1e %9.2e %7.2f   %+7.2f' % (
                k, v['med'][0], v['med'][1], 100 * (v['med'][1] / v['med'][0] - 1), v['noise'][0], v['noise'][1], v['ratio'],
                v['mln'], v['eln'], v['mabs'], v['rel'], 100 * (v['mean'][1] / v['mean'][0] - 1)))
    print('\nall neutral cells, sum of n, undamped / damped - 1: ' + '  '.join('%s %+.2f%%' % (k, 100 * (v - 1)) for k, v in C['sums'].items()))
    print('\nH/H2 crossing (2 n(H2) = n(H), medians in 79 bins of A_V): damped %.4f, undamped %.4f' % tuple(C['cross']))
    print('front (smallest A_V with x(H+) < 0.3): damped %.4f, undamped %.4f' % tuple(C['front']))
    for lab, st in zip(('damped', 'undamped'), C['states']):
        if not st:
            continue
        print('\n%s: neutral cells by C+ / (C+ + C + CO)' % lab)
        print('  A_V        cells  below 0.18   between  above 0.9   in one of the two [%]   mean crossings if none = e^-mu   median T')
        for s in st:
            p0 = s['low'] / s['n']
            print('  %.1f-%.1f   %5d   %8d  %8d   %8d   %8.1f                %8s                  %6.1f' % (
                s['lo'], s['hi'], s['n'], s['low'], s['mid'], s['high'], 100 * (s['low'] + s['high']) / s['n'],
                '%.2f' % -np.log(p0) if 0 < p0 < 1 else '-', s['T']))
