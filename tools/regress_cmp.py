#!/usr/bin/env python3
"""Compare two MOCASSIN output trees, field by field, against a tolerance.

MOCASSIN is not bitwise reproducible - two runs of the same binary on the same
input differ - so a regression check has to be read against the run-to-run
scatter, not against zero. Run the reference twice to establish that floor,
then compare the candidate against it.

    ~/miniforge3/envs/astro/bin/python tools/regress_cmp.py A/output B/output
"""
import os
import sys

import numpy as np

# file -> (columns to compare, label)
FIELDS = {
    'grid1.out':   (None, 'Tgas, ne, nH per cell'),
    'pdrRad.out':  (None, 'A_V, totalLines, J bands, Tdust'),
    'ionratio.out': (None, 'ionic ratios'),
}


def load(p, skip=0):
    try:
        return np.loadtxt(p, skiprows=skip)
    except Exception:
        return None


def main(A, B):
    print(f'A = {A}\nB = {B}\n')
    worst = 0.0
    hdr = '  %-16s %6s %10s %10s %10s' % ('file', 'col', 'median', 'p95', 'max')
    print(hdr); print('-' * len(hdr))
    for fn, (_, lab) in FIELDS.items():
        skip = 1 if fn == 'pdrRad.out' else 0
        a, b = load(os.path.join(A, fn), skip), load(os.path.join(B, fn), skip)
        if a is None or b is None:
            print('  %-16s  (missing)' % fn)
            continue
        if a.shape != b.shape:
            print('  %-16s  SHAPE %s vs %s' % (fn, a.shape, b.shape))
            worst = float('inf')
            continue
        if a.ndim == 1:
            a, b = a[:, None], b[:, None]
        for c in range(a.shape[1]):
            x, y = a[:, c], b[:, c]
            m = np.isfinite(x) & np.isfinite(y) & (np.abs(x) > 0)
            if m.sum() < 5:
                continue
            r = np.abs(y[m] - x[m]) / np.abs(x[m])
            worst = max(worst, float(np.percentile(r, 95)))
            print('  %-16s %6d %10.3e %10.3e %10.3e'
                  % (fn, c, np.median(r), np.percentile(r, 95), r.max()))
    print('\nworst p95 over all fields: %.3e' % worst)

    # Aggregates. Per-cell scatter is dominated by cells where the quantity is
    # near zero; the medians over active cells are what a physical comparison
    # actually rests on, and they average the Monte Carlo noise down.
    print('\naggregate KPIs (median over active cells)')
    g1a, g1b = load(os.path.join(A, 'grid1.out')), load(os.path.join(B, 'grid1.out'))
    pra = load(os.path.join(A, 'pdrRad.out'), 1)
    prb = load(os.path.join(B, 'pdrRad.out'), 1)
    hdr = '  %-22s %12s %12s %9s' % ('quantity', 'A', 'B', 'B/A')
    print(hdr); print('-' * len(hdr))
    rows = []
    if g1a is not None and g1b is not None and g1a.shape == g1b.shape:
        act = (g1a[:, 2] > 0) & (g1b[:, 2] > 0)
        rows += [('median Tgas [K]', np.median(g1a[act, 0]), np.median(g1b[act, 0])),
                 ('median ne [cm-3]', np.median(g1a[act, 1]), np.median(g1b[act, 1]))]
    if pra is not None and prb is not None and pra.shape == prb.shape:
        act = (pra[:, 6] > 0) & (prb[:, 6] > 0)
        rows += [('median Tdust [K]', np.median(pra[act, 6]), np.median(prb[act, 6])),
                 ('median A_V', np.median(pra[act, 0]), np.median(prb[act, 0])),
                 ('median J(FUV)', np.median(pra[act, 3]), np.median(prb[act, 3])),
                 ('median J(.01-.44)', np.median(pra[act, 4]), np.median(prb[act, 4])),
                 ('median J(<.01Ryd)', np.median(pra[act, 5]), np.median(prb[act, 5])),
                 ('median totalLines', np.median(pra[act, 1]), np.median(prb[act, 1]))]
    for n, x, y in rows:
        print('  %-22s %12.5g %12.5g %9.4f'
              % (n, x, y, y / x if x else float('nan')))
    return worst


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
