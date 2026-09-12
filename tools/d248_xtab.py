#!/usr/bin/env python3
"""D-248: cross-tabulate the cells that actually FAIL the convergence test
against the Monte Carlo noise measured from an identical-configuration repeat.

lgConverged is written per cell to grid0.out, so the failing cells are on disk
and no new run is needed.
"""
import sys, numpy as np

def load(run):
    with open(f"{run}/output/grid0.out") as f:
        toks = f.read().split()
    nx, ny, nz = int(toks[1]), int(toks[2]), int(toks[3])
    off = 7 + nx + ny + nz
    ncell = nx*ny*nz
    rest = np.array(toks[off:off+ncell*3], dtype=float).reshape(ncell, 3)
    g1 = np.loadtxt(f"{run}/output/grid1.out")
    with open(f"{run}/output/pdrGrid.out") as f:
        p = np.array(f.read().split(), dtype=float)[:ncell*45].reshape(ncell, 45)
    return dict(active=rest[:, 0].astype(int), conv=rest[:, 1].astype(int),
                Te=g1[:, 0], pdrZone=p[:, 0].astype(int), AV=p[:, 2])

a, b = load(sys.argv[1]), load(sys.argv[2])
limit = float(sys.argv[3]) if len(sys.argv) > 3 else 0.10
m = (a['active'] > 0) & (b['active'] > 0) & (a['Te'] > 0) & (b['Te'] > 0)

rel   = np.abs(a['Te'][m] - b['Te'][m]) / b['Te'][m]
convA = a['conv'][m].astype(bool)
convB = b['conv'][m].astype(bool)
AV    = a['AV'][m]
noisy = rel > limit

print(f"=== failing cells vs noise map: {sys.argv[1]} / {sys.argv[2]} (limit {limit}) ===")
print(f"cells {m.sum()}   unconverged A {np.sum(~convA)} ({100.*np.sum(~convA)/m.sum():.2f}%)"
      f"   unconverged B {np.sum(~convB)} ({100.*np.sum(~convB)/m.sum():.2f}%)"
      f"   noisy {noisy.sum()} ({100.*noisy.sum()/m.sum():.2f}%)")

for nm, conv in (("run A", convA), ("run B", convB)):
    fail = ~conv
    print(f"\n-- {nm}: does failing coincide with noisy? --")
    print(f"   fail & noisy   {np.sum(fail & noisy):6d}")
    print(f"   fail & quiet   {np.sum(fail & ~noisy):6d}")
    print(f"   pass & noisy   {np.sum(~fail & noisy):6d}")
    print(f"   pass & quiet   {np.sum(~fail & ~noisy):6d}")
    if fail.sum():
        print(f"   P(noisy | fail) = {100.*np.sum(fail&noisy)/fail.sum():5.1f}%"
              f"    P(noisy | pass) = {100.*np.sum(~fail&noisy)/max((~fail).sum(),1):5.1f}%")
        print(f"   median scatter of FAILING cells {np.median(rel[fail]):.4f}"
              f"   of PASSING cells {np.median(rel[~fail]):.4f}")

print("\n-- distribution over A_V --")
print(f"{'A_V band':<14s}{'n':>7s}{'fail A':>9s}{'fail%':>8s}{'noisy':>8s}{'noisy%':>8s}{'med scat':>10s}")
for lo, hi in [(0,0.5),(0.5,1),(1,1.5),(1.5,2),(2,2.5),(2.5,3),(3,99)]:
    s = (AV >= lo) & (AV < hi)
    if not s.any(): continue
    print(f"{lo:.1f}-{hi:<9.1f}{s.sum():7d}{np.sum(s&~convA):9d}"
          f"{100.*np.sum(s&~convA)/s.sum():7.1f}%{np.sum(s&noisy):8d}"
          f"{100.*np.sum(s&noisy)/s.sum():7.1f}%{np.median(rel[s]):10.4f}")
