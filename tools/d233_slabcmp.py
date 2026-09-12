#!/usr/bin/env python3
"""D-233: compare a V1/V2 slab run against its standalone 3D-PDR reference.

The slabs are graded in y (5 x ny x 5), not radial, so d196_axis.py's 31^3
indexing does not read them. writeGrid loops i outer, j, k inner, so the
mid-plane column is i = (nx+1)/2, k = (nz+1)/2 walking j, and the record for
cell (i,j,k) is ((i-1)*ny + (j-1))*nz + (k-1).

Geometry comes from output/grid0.out line 2 (nx ny nz nCells ...), so the same
script reads V1 (801 cells deep) and V2 (401).

    d233_slabcmp.py <run-dir> <reference.pdr.fin>
"""
import os
import sys
import importlib.util

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('rc', os.path.join(HERE, 'd233_refcmp.py'))
rc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rc)

COLS = ('T', 'Td', 'Hep', 'Cp', 'C', 'CO', 'OH')
TD_COL = 6                          # Tdust, 0-based, in pdrRad.out
IDX = {'Hep': 2, 'Cp': 11, 'C': 25, 'CO': 28, 'OH': 29, 'H2': 31, 'H': 32}


def load(path):
    with open(path) as fh:
        return [ln.split() for ln in fh]


def main():
    run, refpath = sys.argv[1], sys.argv[2]
    out = os.path.join(run, 'output')
    g0 = load(os.path.join(out, 'grid0.out'))
    nx, ny, nz = (int(v) for v in g0[1][:3])
    g1 = load(os.path.join(out, 'grid1.out'))
    pg = load(os.path.join(out, 'pdrGrid.out'))
    pr = load(os.path.join(out, 'pdrRad.out'))[1:]
    ref = rc.read_ref(refpath)

    i0, k0 = (nx + 1) // 2, (nz + 1) // 2
    print(f'{run}   grid {nx}x{ny}x{nz}   mid-plane column i={i0} k={k0}')
    print(f'reference {os.path.basename(refpath)}: A_V to {ref["AV"][-1]:.3f} '
          f'over {ref["x"][-1]:.3g} pc')
    hdr = f'{"A_V":>6} {"zone":>4} ' + ' '.join(
        f'{c:>10} {"ref":>10} {"x/ref":>8}' for c in COLS)
    print(hdr)

    rows = 0
    for j in range(1, ny + 1):
        rec = ((i0 - 1) * ny + (j - 1)) * nz + (k0 - 1)
        if rec * 2 + 1 >= len(pg) or rec >= len(g1):
            break
        head = pg[rec * 2]
        if int(float(head[0])) != 1:
            continue
        abun = pg[rec * 2 + 1]
        av = float(head[2])
        vals = {'T': float(g1[rec][0]),
                'Td': float(pr[rec][TD_COL]) if rec < len(pr) else 0.}
        for name, ix in IDX.items():
            vals[name] = float(abun[ix - 1])
        rows += 1
        if rows % max(1, (ny // 24)) and j != ny:
            continue
        line = f'{av:6.3f} {int(float(head[0])):4d} '
        for c in COLS:
            v = vals[c]
            r = rc.interp(ref['AV'], ref[c], av)
            line += f' {v:10.3e} {r:10.3e} {(v / r if r else float("nan")):8.2e}'
        print(line)


if __name__ == '__main__':
    main()
