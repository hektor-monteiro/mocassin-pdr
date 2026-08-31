#!/usr/bin/env python3
"""Slab density file for the matched 3D-PDR comparison (DEVLOG D-058/D-059).

Graded in y with a FLOORED first cell: cells thinner than this collapse their
own shielding columns and the thermal solve reports convergence far from
balance (D-057). A_V/N_H = 5.33997e-22 matches the canonical 1.87e21 N_H per
magnitude, which MOCASSIN reaches at MdMg = 0.0281 (D-058).
"""
nx = nz = 5
ny = 401
Lx = Lz = 2.0e19
den = 1000.0
AVfac = 5.33997e-22          # must match what calibratePDRdust reports
AVmax = 8.491                # extent of 3D-PDR's ics/1Dn30.dat under this dust
Ly = AVmax / (AVfac * den)
dy0 = 0.005 / (AVfac * den)  # first cell = 0.005 mag
n = ny - 1
lo, hi = 1.0000001, 1.05
f = lambda r: dy0 * (r**n - 1) / (r - 1) - Ly
for _ in range(200):
    mid = (lo + hi) / 2
    if f(mid) < 0: lo = mid
    else: hi = mid
r = (lo + hi) / 2
ys, acc = [0.0], 0.0
for i in range(n):
    acc += dy0 * r**i
    ys.append(acc)
xs = [Lx * i / (nx - 1) for i in range(nx)]
zs = [Lz * k / (nz - 1) for k in range(nz)]
with open("v1.den", "w") as fh:
    for x in xs:
        for y in ys:
            for z in zs:
                fh.write(f"{x:.6e} {y:.6e} {z:.6e} {den:.4e}\n")
print(f"v1.den: {nx*ny*nz} cells, depth {ys[-1]:.4e} cm, A_V max {AVfac*den*ys[-1]:.3f}, r={r:.5f}")
