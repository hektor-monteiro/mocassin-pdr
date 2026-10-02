#!/usr/bin/env python3
"""H-006: line overlap in h2_mod (lineOverlap) against the exact integral on a
fine frequency grid (tools/h006_exact.py), for the level columns of H-005's
slab march at several depths.

For each depth: the factor overlap puts on the H2g Solomon rate (exact, the
model's, and the overlap factor in Draine & Bertoldi's 1996 fit), the model's
pump rate per lower level over the exact one, and the spread line by line.

    python tools/h006_compare.py <compare.npz of h005_compare.py> <exact.npz of h006_exact.py>
"""
import os
import subprocess
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import h006_exact as ex          # noqa: E402


def main(cmp_npz, exact_npz):
    c = np.load(cmp_npz); d = np.load(exact_npz)
    lev = [tuple(x) for x in c['lev']]
    lidx = {l: i for i, l in enumerate(lev)}
    L = ex.line_list()
    lo = np.array([lidx[(int(r[3]), int(r[4]))] for r in L])
    b = np.sqrt(2*ex.KB*100./(ex.MH2*ex.AMU))
    N = c['NH2in']; pops = c['popV']
    wd = os.path.dirname(os.path.abspath(exact_npz))
    print('overlap factor on the H2g Solomon rate; pump rate per lower level, model/exact; line by line: rms of '
          'model/exact - 1 weighted by each line\'s share of the dissociation')
    print('  N(H2)     exact   model   DB96   model/exact | ' + ' '.join(f'0,{j}'.rjust(6) for j in range(8))
          + ' |  rms    time [s]')
    for m in d['marks']:
        key = '%.0e' % m
        sel = d[key + '__sel']; S_ov = d[key + '__S_ov']; S_own = d[key + '__S_own']; Ncol = d[key + '__N']
        with open(os.path.join(wd, 'cols.txt'), 'w') as f:
            for (v, j), n in zip(lev, Ncol):
                f.write(f'{v} {j} {n:.8e}\n')
        t0 = time.time()
        out = subprocess.run([os.path.join(ex.HERE, 'h2Test'), os.path.join(ex.HERE, 'dataPDR', 'h2'), 'overlap',
                              os.path.join(wd, 'cols.txt'), f'{b:.6e}'], capture_output=True, text=True).stdout
        dt = time.time() - t0
        a = np.array([[float(x) for x in l.split()] for l in out.split('\n') if l.strip()])
        own = a[sel, 3]; sh = a[sel, 4]
        k = int(np.searchsorted(N, m)); pz = pops[min(k, len(pops) - 1)]
        P = L[sel, 6]*L[sel, 7]/L[sel, 8]; fd = L[sel, 10]/L[sel, 9]; lvl = lo[sel]; w = pz[lvl]*P*fd
        fe = (w*S_ov).sum()/(w*S_own).sum(); fm = (w*sh).sum()/(w*own).sum()
        x = Ncol.sum()/5e14
        pe = np.bincount(lvl, weights=P*S_ov, minlength=len(lev)); pm = np.bincount(lvl, weights=P*sh, minlength=len(lev))
        ww = w*S_ov
        rms = np.sqrt((ww*(sh/S_ov - 1)**2).sum()/ww.sum())
        print(f'  {Ncol.sum():8.2e}  {fe:6.3f}  {fm:6.3f}  {np.exp(-8.5e-4*np.sqrt(1 + x)):6.3f}   {(w*sh).sum()/(w*S_ov).sum():6.3f}     | '
              + ' '.join(f'{pm[lidx[(0, j)]]/pe[lidx[(0, j)]]:6.3f}' for j in range(8)) + f' | {rms:5.3f}   {dt:5.1f}')
    # the model's own S against the exact own S (the table and its interpolation)
    r = own/S_own
    print(f'  own shielding at the last depth, table/exact: median {np.median(r):.4f}  min {r.min():.4f} max {r.max():.4f}')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
