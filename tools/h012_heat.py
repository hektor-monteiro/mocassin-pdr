#!/usr/bin/env python3
"""H-012 step 2: the H2 heating from the level model against 3D-PDR's
fixed-energy terms, cell by cell, from output/h2Cells.out (H-012 columns)
and output/grid1.out (n_H).

Per H nucleus [erg s^-1], as MOCASSIN's thermal budget (thermBudget.out):
  levels   formation  grain formation rate x n(H) x kinetic energy per H2
                      formed (energy conservation on the formation
                      distribution, h2FormDist)
           dissociation  sum over levels of pop x dissociation rate x the
                      atoms' kinetic energy
           collisions  net heating by collisions within X at Te (negative:
                      H2 cools the gas)
  3D-PDR   formation 1.5 eV per H2 formed; photodissociation 0.4 eV per
           dissociation; FUV pumping 9 x 2.2 eV per dissociation / (1 + n_cr/n)
  MOCASSIN its heating and its cooling at the balance point

    python tools/h012_heat.py <run> [--shells N]
"""
import os
import sys

import numpy as np

PC = 3.0857e18
NAMES = ('form', 'dis', 'col')


def table(run):
    rows = [l.replace('|', ' ').split() for l in open(os.path.join(run, 'output', 'h2Cells.out'))
            if not l.startswith('#')]
    c = np.array(rows, float)
    if c.shape[1] < 32:
        sys.exit(f'{run}: h2Cells.out has no H-012 heating columns')
    return c


def hden(run, c):
    """n_H per cell of h2Cells.out, from grid1.out (every grid point, i,j,k order)"""
    nx, ny, nz = (int(c[:, a].max()) for a in range(3))
    L = [l.split() for l in open(os.path.join(run, 'output', 'grid1.out'))]
    n = {}
    p = 0
    for i in range(1, nx + 1):
        for j in range(1, ny + 1):
            for k in range(1, nz + 1):
                n[(i, j, k)] = float(L[p][2])
                p += 1
    return np.array([n[(int(r[0]), int(r[1]), int(r[2]))] for r in c])


def widths(ax):
    """cell widths along one axis: half a spacing at the origin (symmetric grid)"""
    ax = np.unique(ax)
    w = np.empty_like(ax)
    w[1:-1] = 0.5*(ax[2:] - ax[:-2])
    w[0] = 0.5*(ax[1] - ax[0])
    w[-1] = ax[-1] - ax[-2]
    return dict(zip(ax, w))


def main(run, nsh):
    c = table(run)
    nH = hden(run, c)
    wx, wy, wz = widths(c[:, 4]), widths(c[:, 5]), widths(c[:, 6])
    dV = np.array([wx[x]*wy[y]*wz[z] for x, y, z in c[:, 4:7]])
    T = c[:, 8]
    lev, pdr = c[:, 21:24], c[:, 24:27]
    heat, cool = c[:, 27], c[:, 28]
    eK, eG, eD = c[:, 29], c[:, 30], c[:, 31]
    r = np.sqrt((c[:, 4:7]**2).sum(1))/PC
    W = nH*dV

    print(f'{run}: {len(c)} cells')
    print('grid totals [erg/s, x8 for the octant not applied]:')
    print(f'  MOCASSIN heating {np.sum(W*heat):.3e}, cooling {np.sum(W*cool):.3e}')
    for k, nm in enumerate(('formation', 'dissociation', 'collisions within X / FUV pumping')):
        print(f'  {nm:34s} levels {np.sum(W*lev[:, k]):+.3e}   3D-PDR {np.sum(W*pdr[:, k]):+.3e}')
    print(f'  H2 total                           levels {np.sum(W*lev.sum(1)):+.3e}   '
          f'3D-PDR {np.sum(W*pdr.sum(1)):+.3e}')
    neg = lev[:, 2] < 0
    print(f'  collisions within X cool the gas in {neg.sum()} cells; there they remove '
          f'{-np.sum(W[neg]*lev[neg, 2]):.3e} (heating elsewhere {np.sum(W[~neg]*lev[~neg, 2]):.3e})')
    m = c[:, 20] > 0
    print(f'  eV per H2 formed: kinetic {np.median(eK[m]):.3f} (range {eK[m].min():.3f}-{eK[m].max():.3f}), '
          f'left on the grain {np.median(eG[m]):.3f}; 3D-PDR 1.5 to the gas')
    m = eD > 0
    if m.any():
        w = c[m, 7]*c[m, 9]*dV[m]
        print(f'  eV per dissociation (kinetic): median {np.median(eD[m]):.3f}, dissociation-weighted '
              f'{np.sum(w*eD[m])/np.sum(w):.3f} (range {eD[m].min():.3f}-{eD[m].max():.3f}); 3D-PDR 0.4')

    edges = np.linspace(0, r.max()*1.0001, nsh + 1)
    print('shells, medians: Te, 2x(H2) | levels/MOCASSIN heating: form dis col | 3D-PDR/MOCASSIN heating: '
          'form dis pump | H2 total, levels/3D-PDR')
    x2 = 2*c[:, 7]/np.maximum(nH, 1e-300)
    for i in range(nsh):
        s = (r >= edges[i]) & (r < edges[i + 1]) & (heat > 0)
        if s.sum() < 3:
            continue
        a = [np.median(lev[s, k]/heat[s]) for k in range(3)]
        b = [np.median(pdr[s, k]/heat[s]) for k in range(3)]
        tot = np.sum(W[s]*lev[s].sum(1))/max(np.sum(W[s]*pdr[s].sum(1)), 1e-300)
        print(f'  {0.5*(edges[i] + edges[i + 1]):7.3f} pc {s.sum():5d}  {np.median(T[s]):8.1f} {np.median(x2[s]):9.2e} | '
              + ' '.join(f'{v:+9.2e}' for v in a) + ' | ' + ' '.join(f'{v:+9.2e}' for v in b) + f' | {tot:7.3f}')


if __name__ == '__main__':
    argv = sys.argv[1:]
    nsh = int(argv[argv.index('--shells') + 1]) if '--shells' in argv else 14
    args = [a for i, a in enumerate(argv) if not a.startswith('--') and (i == 0 or not argv[i - 1].startswith('--'))]
    main(args[0], nsh)
