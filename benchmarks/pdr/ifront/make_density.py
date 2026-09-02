#!/usr/bin/env python3
"""Graded 1D grid that RESOLVES an ionization front (DEVLOG D-081).

A uniform grid cannot do this. Placing one cell inside the front while still
spanning a PDR of depth A_V needs

    N >= [A_V / 5.34e-22] / [1.59e17]        cells per axis

and the density cancels - raising n thins the front and shortens the PDR in
step. A_V = 1 needs ~1.2e4 cells per axis; measured memory allows 83 (14 ranks,
30 GB, nbins=600). Short by ~140x for any density, luminosity or geometry.

A graded 1D grid costs nothing: 2e14 cm at the illuminated face puts ~8 cells
across the front, growing to reach A_V ~ 1.9 in 601 cells.
"""
nx = nz = 5
ny = 601
Lx = Lz = 2.0e19
den = 100.0
dy0 = 2.0e14     # ~1/8 of the front thickness 1/(n*sigma) = 1.6e15 cm
r = 1.013
ys, acc = [0.0], 0.0
for i in range(ny - 1):
    acc += dy0 * r**i
    ys.append(acc)
xs = [Lx * i / (nx - 1) for i in range(nx)]
zs = [Lz * k / (nz - 1) for k in range(nz)]
with open("input/front.den", "w") as fh:
    for x in xs:
        for y in ys:
            for z in zs:
                fh.write(f"{x:.6e} {y:.6e} {z:.6e} {den:.4e}\n")
print(f"front.den: {nx*ny*nz} cells, depth {ys[-1]:.3e} cm, A_V = {5.338e-22*den*ys[-1]:.2f}")
