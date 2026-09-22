#!/usr/bin/env python3
"""D-309: MOCASSIN averages graphite TEMPERATURES where Draine averages CROSS
SECTIONS, and that is most of D-283's dust-temperature excess.

dust_species.dat carries grph2-dl (E perp c, 0.6667) and grph1-dl (E par c,
0.3333) as two SPECIES. MOCASSIN solves a separate equilibrium temperature for
each and reports their abundance-weighted arithmetic mean. Draine's graphite -
what Cloudy uses - applies the same 1/3-2/3 weights to the CROSS SECTIONS of a
single randomly-oriented grain and solves ONE temperature. The two orientations
differ enormously in far-IR emissivity, so a mean of temperatures is not the
temperature of the mean, and T is a steeply non-linear function of the
absorbed energy.

This recovers each cell's absorbed energy from the species-1 balance it
already satisfies, re-solves it for a grain with the AVERAGED cross section,
and re-does the comparison against Cloudy.

    ~/miniforge3/envs/astro/bin/python tools/d309_tavg.py \\
        runs/d302-trim-on runs/d302-cloudy-trim-rad/150k
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from d305_mie import bhmie
from d305_tdust import read_dustgrid
from d287_pe import rows, last_iteration
import d260_roellig as R

H, C, KB = 6.62607015e-27, 2.99792458e10, 1.380649e-16
LAM = np.geomspace(0.003, 3000., 700)
NU = C / (LAM * 1e-4)
TGRID = np.geomspace(3., 400., 260)


def nk(p):
    a = np.loadtxt(p, skiprows=2)
    return a[:, 0], a[:, 1], a[:, 2]


def cvec(lm, n, k, a_um):
    nn, kk = np.interp(LAM, lm, n), np.interp(LAM, lm, k)
    q = np.empty(len(LAM))
    for i, (l, x, y) in enumerate(zip(LAM, nn, kk)):
        qe, qs, _ = bhmie(min(2 * np.pi * a_um / l, 100.), complex(x, y))
        q[i] = qe - qs
    return q * np.pi * (a_um * 1e-4) ** 2


def emtab(Cv):
    """4 * integral C_abs B_nu(T) dnu on TGRID - MOCASSIN's own convention."""
    out = np.empty(len(TGRID))
    for j, T in enumerate(TGRID):
        x = np.clip(H * NU / (KB * T), 0, 700.)
        B = 2 * H * NU ** 3 / C ** 2 / np.expm1(x)
        out[j] = -np.trapezoid(4 * Cv * B, NU)
    return out


def main(run, prefix):
    sz = np.loadtxt(os.path.join(run, 'input', 'dust_sizes.dat'), skiprows=2)
    a_um, nofa = sz[:, 1], sz[:, 2]
    spec = open(os.path.join(run, 'input', 'dust_species.dat')).read().split()
    f2, f1 = float(spec[2]), float(spec[6])          # grph2 then grph1
    w2, w1 = f2 / (f1 + f2), f1 / (f1 + f2)

    D = 'dustData/'
    l2, n2, k2 = nk(D + 'grph2-dl.nk')
    l1, n1, k1 = nk(D + 'grph1-dl.nk')

    print('building cross sections and emission tables for %d sizes ...'
          % len(a_um))
    E2, EAV = [], []
    for a in a_um:
        C2, C1 = cvec(l2, n2, k2, a), cvec(l1, n1, k1, a)
        E2.append(emtab(C2))
        EAV.append(emtab(w2 * C2 + w1 * C1))
    E2, EAV = np.array(E2), np.array(EAV)

    ndust, T = read_dustgrid(run)
    t = open(os.path.join(run, 'output', 'grid0.out')).read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    n = nx * ny * nz
    off = 7 + nx + ny + nz
    idx = np.where(np.array(t[off:off + 3 * n:3], float) > 0)[0]
    T = T[idx]                                        # (cell, size, species)
    d = R.read_run(run)

    # Cloudy
    hg = open(f'{prefix}.gtemp').readline().lstrip('#').rstrip().split('\t')
    gt = rows(f'{prefix}.gtemp', len(hg))
    hp = open(f'{prefix}.pdr').readline().lstrip('#').rstrip().split('\t')
    pdr = last_iteration(rows(f'{prefix}.pdr', len(hp)), hp.index('depth'))
    avc = pdr[:, hp.index('AV(point)')]
    nb = gt.shape[1] - 1
    edges = np.geomspace(a_um[0], a_um[-1], nb + 1)
    wc = edges[:-1] ** -2.5 - edges[1:] ** -2.5
    wc /= wc.sum()

    da = np.empty(len(a_um))
    da[0] = a_um[1] - a_um[0]
    da[1:-1] = (a_um[2:] - a_um[:-2]) / 2
    da[-1] = a_um[-1] - a_um[-2]
    wn = nofa * da
    wn /= wn.sum()

    print('\nMOCASSIN %s\nCloudy   %s\n' % (run, prefix))
    hdr = ('   A_V | reported  corrected | Cloudy | reported/Cld  corrected/Cld')
    print(hdr); print('-' * len(hdr))
    for av in (0.20, 0.30, 0.50, 0.65):
        s = np.abs(d['AV'] - av) <= max(0.02, 0.06 * av)
        if s.sum() < 3:
            continue
        t1 = np.median(T[s, :, 0], axis=0)            # species 1 = grph2
        t2 = np.median(T[s, :, 1], axis=0)
        rep = (w2 * t1 + w1 * t2) @ wn                # what MOCASSIN reports
        cor = np.empty(len(a_um))
        for i in range(len(a_um)):
            absorbed = np.interp(t1[i], TGRID, E2[i])  # its own balance
            cor[i] = np.interp(absorbed, EAV[i], TGRID)
        corm = cor @ wn
        j = min(np.argmin(abs(avc - av)), len(gt) - 1)
        tc = gt[j, 1:] @ wc
        print('  %4.2f | %8.2f %10.2f | %6.2f | %12.3f %14.3f'
              % (av, rep, corm, tc, rep / tc, corm / tc))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
