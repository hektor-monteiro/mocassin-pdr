#!/usr/bin/env python3
"""H-025 (production D-397): the star-ward H2 column of every cell as the code
has it (h2Cells.out, "N(H2) to cell") against the exact path length through
each cell on the same ray, with the same n(H2).

Before D-397 the code sampled the nearest cell once per step of about a cell
width; that march is rebuilt here too ("sampled") and set against the code's
column, so the comparison says which of the two the run used.

    python tools/h025_columns.py <run>
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import h013_figures as F              # noqa: E402

run = sys.argv[1]
c = F.cells(run)
t = open(run + '/output/grid0.out').read().split()
nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
xa = np.array(t[7:7 + nx], np.float32)
ya = np.array(t[7 + nx:7 + nx + ny], np.float32)
za = np.array(t[7 + nx + ny:7 + nx + ny + nz], np.float32)
ii, jj, kk = (c[:, q].astype(int) - 1 for q in (0, 1, 2))
nH2 = np.zeros((nx, ny, nz))
nH2[ii, jj, kk] = c[:, 7]
cid = -np.ones((nx, ny, nz), int)
cid[ii, jj, kk] = np.arange(len(c))
X = [xa.astype(float), ya.astype(float), za.astype(float)]
MID = [0.5 * (a[1:] + a[:-1]) for a in X]


def nearest(ax, v):
    """nearestAxB: bisection, then the nearer of the two; a tie goes to the lower"""
    j = np.clip(np.searchsorted(ax, v, side='right') - 1, 0, len(ax) - 2)
    return np.where(np.abs(v - ax[j + 1]) < np.abs(v - ax[j]), j + 1, j)


def sampled(i, j, k):
    p = np.array([X[0][i], X[1][j], X[2][k]])
    seg = np.sqrt((p * p).sum())
    if seg <= 0:
        return 0.
    n = max(8, min(400, int(seg / max(abs(X[0][1] - X[0][0]), 1.))))
    ds = seg / n
    rr = (np.arange(1, n + 1) - 0.5) * ds
    ix, iy, iz = (nearest(X[q], p[q] * rr / seg) for q in range(3))
    keep = ~((ix == i) & (iy == j) & (iz == k))
    return (nH2[ix[keep], iy[keep], iz[keep]] * ds).sum()


def exact(i, j, k):
    p = np.array([X[0][i], X[1][j], X[2][k]])
    seg = np.sqrt((p * p).sum())
    if seg <= 0:
        return 0., 0.
    ts = [np.array([0., 1.])]
    for q in range(3):
        if p[q] > 0:
            tq = MID[q] / p[q]
            ts.append(tq[(tq > 0) & (tq < 1)])
    tt = np.unique(np.concatenate(ts))
    tm = 0.5 * (tt[1:] + tt[:-1])
    L = np.diff(tt) * seg
    ix, iy, iz = (nearest(X[q], p[q] * tm) for q in range(3))
    own = (ix == i) & (iy == j) & (iz == k)
    return (nH2[ix[~own], iy[~own], iz[~own]] * L[~own]).sum(), L[own].sum()


S = np.array([sampled(a, b, d) for a, b, d in zip(ii, jj, kk)])
E = np.array([exact(a, b, d) for a, b, d in zip(ii, jj, kk)])
Ex, own = E[:, 0], E[:, 1]
code = c[:, 16]
ok = code > 0
q = S[ok] / code[ok]
print(f'{run}: {len(c)} cells')
print(f'the rebuilt sampled march over h2Cells.out\'s column: median {np.median(q):.4f}, 1-99% {np.percentile(q, 1):.4f}-{np.percentile(q, 99):.4f},'
      f' within 1%: {(np.abs(q - 1) < 0.01).mean() * 100:.1f}% of {ok.sum()}')
r = np.sqrt((c[:, 4:7] ** 2).sum(1)) / 3.0857e18
ok = (Ex > 0) & (code > 0)
q = code[ok] / Ex[ok]
print(f'\nthe code\'s column over the exact one, all {ok.sum()} cells: median {np.median(q):.4f}; 5-95% {np.percentile(q, 5):.3f}-{np.percentile(q, 95):.3f};'
      f' 1-99% {np.percentile(q, 1):.3f}-{np.percentile(q, 99):.3f}; min {q.min():.3g}, max {q.max():.3g}')
for lo, hi in ((0, 0.5), (0.5, 0.8), (0.8, 1.25), (1.25, 2), (2, 1e9)):
    print(f'   ratio {lo}-{hi}: {((q >= lo) & (q < hi)).sum():6d} cells')
print('\nby N(H2) exact (the transition is 1e14-1e19):')
print('   log N      cells   median   5%     95%    min    max   | ratio < 0.5 | > 2')
for lo in range(9, 22):
    s = ok & (Ex >= 10. ** lo) & (Ex < 10. ** (lo + 1))
    if s.sum() == 0:
        continue
    q = code[s] / Ex[s]
    print(f'   {lo:2d}-{lo + 1:2d}  {s.sum():7d}   {np.median(q):6.3f}  {np.percentile(q, 5):6.3f} {np.percentile(q, 95):6.3f} {q.min():6.3f} {q.max():6.3f}'
          f'   {(q < 0.5).sum():6d}      {(q > 2).sum():6d}')
on = ((ii == 0).astype(int) + (jj == 0).astype(int) + (kk == 0).astype(int))
for nm, sel in (('on a grid axis', on == 2), ('in a coordinate plane', on == 1), ('elsewhere', on == 0)):
    s = ok & sel & (Ex > 1e13)
    q = code[s] / Ex[s]
    print(f'{nm:22s} (N > 1e13): {s.sum():6d} cells, median {np.median(q):.3f}, 5-95% {np.percentile(q, 5):.3f}-{np.percentile(q, 95):.3f}, min {q.min():.3f}, max {q.max():.3f}')
