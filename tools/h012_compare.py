#!/usr/bin/env python3
"""H-012: a model run with the H2 level model feeding the chemistry (stage B)
against the same model with the chemistry's own H2 photodissociation rate
(stage A, the level model only on the finished model).

Per run, from output/pdrGrid.out (abundances per H nucleus, every grid point
in i,j,k order), output/h2Cells.out (the level model per active cell) and
output/lineFluxH2.out:

  sum rule   x(H) + 2 x(H2) + x(H+) - 1 over the active cells
  shells     medians per radial shell of x(H2), x(H), Te, and the H2
             photodissociation rate per molecule: the levels' (which stage B
             hands the chemistry) and the chemistry's own on the same field
             (which stage A used)
  front      the radius where 2 x(H2) first reaches 0.5, along each axis
  lines      the four lines of H-007, L / Hbeta

    python tools/h012_compare.py <run A> <run B> [--names A,B] [--shells N]
"""
import os
import sys

import numpy as np

PC = 3.0857e18
SPECIES = ('H3+ He+ Mg CH5+ O2 H2+ CH4+ O+ OH+ Mg+ C+ CH4 H2O+ H3O+ CO+ O2+ CH2 H2O H+ CH3+ CH CH3 '
           'HCO+ CH2+ C He CH+ CO OH O H2 H e-').split()


def cells(run):
    rows = [l.replace('|', ' ').split() for l in open(os.path.join(run, 'output', 'h2Cells.out'))
            if not l.startswith('#')]
    return np.array(rows, float)


def species_order(run):
    f = os.path.join(run, 'output', 'pdrReacRates.out')
    if os.path.exists(f):
        for l in open(f):
            if l.startswith('# species:'):
                return l.split(':', 1)[1].split()
    return SPECIES


def abundances(run, c):
    """per active cell of h2Cells.out (in its order): the 33 abundances"""
    nx, ny, nz = (int(c[:, a].max()) for a in range(3))
    L = open(os.path.join(run, 'output', 'pdrGrid.out')).read().split('\n')[1:]
    ab = {}
    p = 0
    for i in range(1, nx + 1):
        for j in range(1, ny + 1):
            for k in range(1, nz + 1):
                ab[(i, j, k)] = L[2*p + 1]
                p += 1
    return np.array([np.array(ab[(int(r[0]), int(r[1]), int(r[2]))].split(), float) for r in c])


def lines(run):
    out, hb = {}, None
    for l in open(os.path.join(run, 'output', 'lineFluxH2.out')):
        if l.startswith('# Hbeta'):
            hb = float(l.split(':')[1])
        if l.startswith('#'):
            continue
        out[l[2:14].replace(' ', '')] = float(l[71:85])
    return out, hb


def main(ra, rb, names, nsh):
    R = {}
    for run, nm in zip((ra, rb), names):
        c = cells(run)
        sp = species_order(run)
        ab = abundances(run, c)
        xH2, xH, xHp = ab[:, sp.index('H2')], ab[:, sp.index('H')], ab[:, sp.index('H+')]
        r = np.sqrt((c[:, 4:7]**2).sum(1))/PC
        R[nm] = dict(c=c, r=r, xH2=xH2, xH=xH, xHp=xHp, T=c[:, 8], sol=c[:, 9], solc=c[:, 10],
                     L=lines(run))
        s = xH + 2*xH2 + xHp - 1
        print(f'{nm}: sum rule x(H) + 2x(H2) + x(H+) - 1 over {len(s)} cells: median {np.median(s):+.1e}, '
              f'min {s.min():+.1e}, max {s.max():+.1e}')
    a, b = R[names[0]], R[names[1]]
    edges = np.linspace(0, max(a['r'].max(), b['r'].max())*1.0001, nsh + 1)
    print(f'shells: median x(H2), x(H), Te, Sol(levels), Sol(chemistry) [s-1]   {names[0]} | {names[1]}')
    for i in range(nsh):
        out = []
        for X in (a, b):
            m = (X['r'] >= edges[i]) & (X['r'] < edges[i + 1])
            if not m.any():
                out.append(None); continue
            out.append(tuple(np.median(X[q][m]) for q in ('xH2', 'xH', 'T', 'sol', 'solc')))
        if None in out:
            continue
        print(f'  {0.5*(edges[i]+edges[i+1]):7.3f} pc  ' + ' | '.join(
            f'{o[0]:9.2e} {o[1]:9.2e} {o[2]:8.1f} {o[3]:9.2e} {o[4]:9.2e}' for o in out))
    for nm, X in ((names[0], a), (names[1], b)):
        fr = []
        for ax, (o1, o2) in ((4, (1, 2)), (5, (0, 2)), (6, (0, 1))):
            m = (X['c'][:, o1] == 1) & (X['c'][:, o2] == 1)
            o = np.argsort(X['c'][m, ax])
            rr = X['c'][m, ax][o]/PC; f = 2*X['xH2'][m][o]
            k = np.where(f >= 0.5)[0]
            fr.append(rr[k[0]] if len(k) else np.nan)
        print(f'{nm}: 2x(H2) = 0.5 first reached at r = ' + ' / '.join(f'{x:.3f}' for x in fr) + ' pc (x / y / z axis)')
    (La, ha), (Lb, hb) = a['L'], b['L']
    print('lines, L/Hbeta: ' + '   '.join(f'{k} {La[k]:.3e} -> {Lb[k]:.3e} ({Lb[k]/La[k]:.2f})'
                                          for k in ('1-0S(1)', '2-1S(1)', '0-0S(0)', '0-0S(1)', '0-0S(2)') if k in La and k in Lb))
    print(f'Hbeta [1e36 erg/s]: {ha:.5f} -> {hb:.5f}')


if __name__ == '__main__':
    argv = sys.argv[1:]
    names = argv[argv.index('--names') + 1].split(',') if '--names' in argv else ['A', 'B']
    nsh = int(argv[argv.index('--shells') + 1]) if '--shells' in argv else 14
    args = [a for i, a in enumerate(argv) if not a.startswith('--') and (i == 0 or not argv[i - 1].startswith('--'))]
    main(args[0], args[1], names, nsh)
