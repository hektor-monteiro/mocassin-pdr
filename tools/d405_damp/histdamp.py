#!/usr/bin/env python3
"""D-405 (L-49): do cells oscillate, or scatter? Read from cell histories.

    histdamp.py <run> [<first iteration, default 9>] [<last iteration>]

Needs <run>/hist/itNN.npz, one per iteration (tools/d405_damp/snap.py).

For a quantity q of one cell over the iterations, with d1 = q(n) - q(n-1)
and d2 = q(n) - q(n-2):

    R = <d2^2> / <d1^2>     and     c = corr(d1(n), d1(n+1))

tell the kinds of motion apart without any threshold:

    noise, independent from one iteration to the next   R = 1      c = -0.50
    the same through a blend of 0.75 new and 0.25 old   R = 1.25   c = -0.375
    a cycle of period two                               R -> 0     c -> -1
    a steady drift                                      R -> 4     c -> +1
    a random walk                                       R = 2      c = 0

R and c are pooled over the cells of a band of A_V and over the iterations
(means of squares, and the same with each cell's values divided by its own
step size so that the few cells with the largest steps do not carry it).
The jumps of the molecular fraction are also counted cell by cell.
"""
import glob
import os
import sys

import numpy as np

run = sys.argv[1].rstrip('/')
files = sorted(glob.glob(os.path.join(run, 'hist', 'it*.npz')))
its = [int(os.path.basename(f)[2:4]) for f in files]
i0 = int(sys.argv[2]) if len(sys.argv) > 2 else 9
i1 = int(sys.argv[3]) if len(sys.argv) > 3 else max(its)
use = [(i, f) for i, f in zip(its, files) if i0 <= i <= i1]
assert len(use) >= 4, 'needs four iterations or more, has %s' % its
assert [u[0] for u in use] == list(range(use[0][0], use[-1][0] + 1)), 'iterations missing: %s' % its
D = [np.load(f) for _, f in use]
last = D[-1]
print('%s: iterations %d-%d (%d kept in all: %s)' % (run, use[0][0], use[-1][0], len(its), ' '.join(map(str, its))))

fm = np.array([2 * d['x_H2'] for d in D])                    # (iterations, cells)
Q = {'ln T': np.log(np.array([d['Te'] for d in D], float)),
     'ln n_e': np.log(np.maximum(np.array([d['Ne'] for d in D], float), 1e-300)),
     'f_mol': fm,
     'ln x(H2)': np.log(np.maximum(np.array([d['x_H2'] for d in D]), 1e-300)),
     'ln x(H)': np.log(np.maximum(np.array([d['x_H'] for d in D]), 1e-300)),
     'ln x(C)': np.log(np.maximum(np.array([d['x_C'] for d in D]), 1e-300)),
     'ln x(C+)': np.log(np.maximum(np.array([d['x_C+'] for d in D]), 1e-300)),
     'ln x(CO)': np.log(np.maximum(np.array([d['x_CO'] for d in D]), 1e-300))}
av = last['AV'].astype(float)
neutral = np.all(np.array([d['x_H+'] for d in D]) < 0.3, axis=0)
ionized = np.all(np.array([d['x_H+'] for d in D]) >= 0.3, axis=0)
print('cells %d: ionized throughout %d, neutral throughout %d, changing side %d' % (len(av), ionized.sum(), neutral.sum(), len(av) - ionized.sum() - neutral.sum()))
q = np.quantile(av[neutral], [0, 0.05, 0.15, 0.3, 0.5, 0.75, 1.0])
bands = [('ionized', ionized)] + [('A_V %.2f-%.2f' % (q[i], q[i + 1]), neutral & (av >= q[i]) & (av <= q[i + 1])) for i in range(6)]
bands.append(('all neutral', neutral))


def stats(x):
    """x: (iterations, cells). Pooled R and c, plain and with each cell scaled by its own rms step."""
    d1 = x[1:] - x[:-1]
    d2 = x[2:] - x[:-2]
    s = np.sqrt((d1 ** 2).mean(axis=0))
    ok = s > 0
    if ok.sum() < 20:
        return None
    d1, d2, s = d1[:, ok], d2[:, ok], s[ok]
    R = (d2 ** 2).mean() / (d1 ** 2).mean()
    c = (d1[1:] * d1[:-1]).mean() / (d1 ** 2).mean()
    u1, u2 = d1 / s, d2 / s
    Rn = (u2 ** 2).mean() / (u1 ** 2).mean()
    cn = (u1[1:] * u1[:-1]).mean() / (u1 ** 2).mean()
    rc = (d2 ** 2).mean(axis=0) / (d1 ** 2).mean(axis=0)   # each cell's own R
    return np.median(np.abs(d1)), R, c, Rn, cn, float((rc < 0.3).mean()), float((rc > 2.5).mean()), int(ok.sum())


print('\n%-13s %-9s %10s %6s %6s   %6s %6s   %9s %9s' % ('', '', 'med |d1|', 'R', 'c', 'R cell', 'c cell', 'R<0.3 [%]', 'R>2.5 [%]'))
for name, m in bands:
    if m.sum() < 20:
        continue
    for k, x in Q.items():
        r = stats(x[:, m])
        if r is None:
            continue
        print('%-13s %-9s %10.3e %6.2f %+6.2f   %6.2f %+6.2f   %9.1f %9.1f' % (name, k, r[0], r[1], r[2], r[3], r[4], 100 * r[5], 100 * r[6]))
    print()

# jumps of the molecular fraction
d1 = fm[1:] - fm[:-1]
for thr in (0.5, 0.25, 0.1):
    J = np.abs(d1) > thr
    per = J.sum(axis=1)
    ncell = int(J.any(axis=0).sum())
    back = (J[:-1] & J[1:] & (np.sign(d1[:-1]) != np.sign(d1[1:]))).sum()
    nj = J.sum(axis=0)
    h = np.bincount(nj[nj > 0], minlength=d1.shape[0] + 1)[1:]
    print('f_mol steps above %.2f: per iteration %s; %d steps in %d cells; followed by one back the next iteration: %d of %d (%.0f%%)' % (
        thr, ' '.join(map(str, per)), J.sum(), ncell, back, J[:-1].sum(), 100 * back / max(J[:-1].sum(), 1)))
    print('   cells by number of such steps (1, 2, ... of %d): %s' % (d1.shape[0], ' '.join(map(str, h))))
    if thr == 0.5 and ncell:
        c = J.any(axis=0)
        print('   those cells: A_V %.2f-%.2f (median %.2f), f_mol min-max over the iterations, median %.2f-%.2f' % (
            av[c].min(), av[c].max(), np.median(av[c]), np.median(fm[:, c].min(axis=0)), np.median(fm[:, c].max(axis=0))))
