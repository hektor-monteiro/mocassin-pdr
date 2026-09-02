#!/usr/bin/env python3
"""Slab density file for the Rollig V2 comparison (DEVLOG D-082).

V2 is n_H = 1e5 with chi = 1e3. The A_V span is held at 8.491 - the same as V1
- so the standalone reference is 3D-PDR's own ics/1Dn30.dat scaled by 1/100 in
length (density rises 100x, so length falls 100x). That scaled IC is committed
as baseline3dpdr/1Dn50.dat.
"""
nx = nz = 5
ny = 401
Lx = Lz = 2.0e17
den = 1.0e5
AVfac = 5.33839e-22          # must match what calibratePDRdust reports
AVmax = 8.491
Ly = AVmax / (AVfac * den)
dy0 = 0.005 / (AVfac * den)  # first cell = 0.005 mag (D-057: never thinner)
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
print(f"v1.den: {nx*ny*nz} cells, depth {ys[-1]:.3e} cm, A_V {AVfac*den*ys[-1]:.2f}, r={r:.5f}")
