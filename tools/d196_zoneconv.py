#!/usr/bin/env python3
"""D-196: what is the model's convergence percentage actually made of?

Joins the per-cell records writeGrid dumps - all written from the same
i/j/k loop, so record N is the same cell in every file:

    grid0.out    active, lgConverged, lgBlack          (1 line per cell)
    grid2.out    ionDen(elem, stages)                  (nElem lines per cell,
                                                        hydrogen first)
    pdrGrid.out  pdrZone, chiFUV, AVeff, ...           (2 lines per cell,
                 then the 33 network abundances         abundances on the 2nd)

and cross-tabulates, over PDR-zone cells only, whether the cell is counted
converged against whether MOCASSIN's x(H0) has been clamped to zero by the
D-192 handback. If the converged cells are the clamped ones, the convergence
percentage is measuring a quantity that has been pinned rather than settled.

Usage:  d196_zoneconv.py <run-dir> [nElem] [nSpec]
"""
import sys
import os

IH2, IH, IHP = 31, 32, 19          # species_reduced.d: H2, H, H+ (1-based)


def read_grid0(path, ncell):
    """active, lgConverged, lgBlack - three integers. Header lines carry a
    different field count, so filter on that rather than on a line offset."""
    rows = []
    with open(path) as fh:
        for line in fh:
            f = line.split()
            if len(f) == 3 and all(x.lstrip('-').isdigit() for x in f):
                rows.append((int(f[0]), int(f[1]), int(f[2])))
    if len(rows) < ncell:
        sys.exit(f'grid0.out: got {len(rows)} cell records, expected {ncell}')
    return rows[-ncell:]


def read_hydrogen(path, ncell, nelem):
    """ionDen for hydrogen: the first of each cell's nelem lines, 2 stages."""
    out = []
    with open(path) as fh:
        for i, line in enumerate(fh):
            if i % nelem == 0:
                f = line.split()
                out.append((float(f[0]), float(f[1])))
            if len(out) == ncell:
                break
    return out


def read_pdr(path, ncell):
    """pdrZone from the header line, x(H2)/x(H)/x(H+) from the abundance line."""
    zone, ab = [], []
    with open(path) as fh:
        for i, line in enumerate(fh):
            f = line.split()
            if i % 2 == 0:
                zone.append(int(float(f[0])))
            else:
                ab.append((float(f[IH2 - 1]), float(f[IH - 1]), float(f[IHP - 1])))
            if len(ab) == ncell:
                break
    return zone, ab


def main():
    run = sys.argv[1]
    nelem = int(sys.argv[2]) if len(sys.argv) > 2 else 7
    out = os.path.join(run, 'output')

    with open(os.path.join(out, 'pdrGrid.out')) as fh:
        ncell = sum(1 for _ in fh) // 2

    g0 = read_grid0(os.path.join(out, 'grid0.out'), ncell)
    hyd = read_hydrogen(os.path.join(out, 'grid2.out'), ncell, nelem)
    zone, ab = read_pdr(os.path.join(out, 'pdrGrid.out'), ncell)

    tab = {(0, 0): 0, (0, 1): 0, (1, 0): 0, (1, 1): 0}
    nzone = 0
    conv_all = sum(1 for a, c, _ in g0 if a > 0 and c == 1)
    nact = sum(1 for a, _, _ in g0 if a > 0)

    for i in range(ncell):
        if g0[i][0] <= 0 or zone[i] != 1:
            continue
        nzone += 1
        clamped = 1 if hyd[i][0] <= 0.0 else 0
        tab[(clamped, g0[i][1])] += 1

    print(f'\n  {run}')
    print(f'  active cells {nact}   PDR-zone cells {nzone}'
          f'   converged over all active cells {100.0*conv_all/max(nact,1):.2f} %\n')
    print('  PDR-zone cells            converged   not converged      total')
    print('  ' + '-' * 58)
    for clamped, label in ((1, 'x(H0) clamped to 0'), (0, 'x(H0) > 0')):
        c, n = tab[(clamped, 1)], tab[(clamped, 0)]
        print(f'  {label:<24}{c:>10}{n:>16}{c+n:>11}')
    print('  ' + '-' * 58)
    tc = tab[(1, 1)] + tab[(0, 1)]
    print(f'  {"total":<24}{tc:>10}{tab[(1,0)]+tab[(0,0)]:>16}{nzone:>11}\n')
    if tc:
        print(f'  of the converged PDR-zone cells, {100.0*tab[(1,1)]/tc:.1f} % '
              f'have x(H0) pinned at exactly zero')


if __name__ == '__main__':
    main()
