#!/usr/bin/env python3
"""D-305: MOCASSIN's dust temperature size by size, against Cloudy's.

D-283 has MOCASSIN's mean grain temperature 7-25% above Cloudy's and the cause
is open. The mean is a NUMBER-weighted average over the size distribution
(update_mod.f90), so it is dominated by the smallest grains - which is exactly
where the two codes' grain physics differs most (MOCASSIN runs bulk-graphite
Mie at 0.005 um where Draine's own table is PAH physics, and stochastic
heating is off). This prints the temperature size by size on both sides, which
says whether the excess is uniform - an energy-balance or field difference -
or confined to the small grains, which would be optics.

    ~/miniforge3/envs/astro/bin/python tools/d305_tdust.py \\
        runs/d302-trim-on runs/d302-cloudy-trim-rad/150k
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R
from d287_pe import rows


def read_dustgrid(run, nsizes=35, nspec=2):
    """Tdust(size, species) per active cell, from output/dustGrid.out.

    Per cell the file holds Ndust then (nSizes+1) rows of (nSpeciesMax+1)
    values: row 0 and column 0 are the averages MOCASSIN accumulates, so the
    per-size per-species block is rows 1.. and columns 1...
    """
    p = os.path.join(run, 'output', 'dustGrid.out')
    lines = [l for l in open(p).read().splitlines() if 'mass' not in l]
    tok = np.array(' '.join(lines).split(), float)
    per = 1 + (nsizes + 1) * (nspec + 1)
    if len(tok) % per:
        raise SystemExit(f'dustGrid.out: {len(tok)} tokens is not a multiple '
                         f'of {per}')
    a = tok.reshape(-1, per)
    T = a[:, 1:].reshape(-1, nsizes + 1, nspec + 1)
    return a[:, 0], T[:, 1:, 1:]          # Ndust, Tdust(cell, size, species)


def main(run, prefix):
    d = R.read_run(run)
    sz = np.loadtxt(os.path.join(run, 'input', 'dust_sizes.dat'), skiprows=2)
    a_um, nofa = sz[:, 1], sz[:, 2]
    # dust_species.dat order and weights
    spec = open(os.path.join(run, 'input', 'dust_species.dat')).read().split()
    abun = np.array([float(spec[2]), float(spec[6])])

    ndust, T = read_dustgrid(run)
    t = open(os.path.join(run, 'output', 'grid0.out')).read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    n = nx * ny * nz
    off = 7 + nx + ny + nz
    idx = np.where(np.array(t[off:off + 3 * n:3], float) > 0)[0]
    T = T[idx]                                        # active cells only
    Tsize = T @ (abun / abun.sum())                   # mean over species

    # Cloudy: geometric bin centres of a log grid over the SAME range, which
    # its own output confirms (per-bin <D/G> is geometric with ratio 1.216,
    # giving amax/amin = 50.00 = 0.25/0.005).
    hg = open(f'{prefix}.gtemp').readline().lstrip('#').rstrip().split('\t')
    gt = rows(f'{prefix}.gtemp', len(hg))
    nb = gt.shape[1] - 1
    edges = np.geomspace(a_um[0], a_um[-1], nb + 1)
    ac = np.sqrt(edges[:-1] * edges[1:])
    hp = open(f'{prefix}.pdr').readline().lstrip('#').rstrip().split('\t')
    from d287_pe import last_iteration
    pdr = last_iteration(rows(f'{prefix}.pdr', len(hp)), hp.index('depth'))
    avc = pdr[:, hp.index('AV(point)')]

    print('MOCASSIN %s\nCloudy   %s' % (run, prefix))
    print('Grain temperature size by size. MOCASSIN: 35 bins, median over '
          'cells in the\nA_V bin. Cloudy: 10 bins at their geometric centres, '
          'nearest zone.\n')
    for av in (0.20, 0.30, 0.50, 0.65):
        s = np.abs(d['AV'] - av) <= max(0.02, 0.06 * av)
        if s.sum() < 3:
            continue
        j = min(np.argmin(abs(avc - av)), len(gt) - 1)
        tm = np.median(Tsize[s], axis=0)
        tc = gt[j, 1:]
        print('A_V = %.2f' % av)
        print('   a[um]   T_MOC  |    a[um]   T_Cld  |  interp T_Cld  ratio')
        ti = np.interp(a_um, ac, tc)
        for i in range(0, 35, 3):
            cl = ('%8.4f %7.2f' % (ac[i // 3], tc[i // 3])) if i // 3 < nb \
                 else ' ' * 16
            print('%8.4f %7.2f  | %s  | %9.2f %9.3f'
                  % (a_um[i], tm[i], cl, ti[i], tm[i] / ti[i]))
        # the number-weighted means, which is what D-283 compares
        da = np.empty(35)
        da[0] = a_um[1] - a_um[0]
        da[1:-1] = (a_um[2:] - a_um[:-2]) / 2
        da[-1] = a_um[-1] - a_um[-2]
        w = nofa * da; w /= w.sum()
        wc = edges[:-1] ** -2.5 - edges[1:] ** -2.5; wc /= wc.sum()
        print('  number-weighted mean:  MOCASSIN %.2f K   Cloudy %.2f K   '
              'ratio %.3f' % (tm @ w, tc @ wc, (tm @ w) / (tc @ wc)))
        print('  reported in pdrRad.out: %.2f K\n' % np.median(d['Tdust'][s]))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
