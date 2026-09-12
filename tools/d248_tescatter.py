#!/usr/bin/env python3
"""D-248: per-cell Te scatter between two identical-configuration runs.

Measures the Monte Carlo noise floor on the quantity the D-229 convergence
test compares:  lgCvTe = |Te - TeIterStart| / TeIterStart <= XHILimit.
"""
import sys, numpy as np

def load(run):
    # grid0.out: 2 header lines + nx+ny+nz axis lines, then (active, lgConv, lgBlack)
    with open(f"{run}/output/grid0.out") as f:
        toks = f.read().split()
    nx, ny, nz, nCells = int(toks[1]), int(toks[2]), int(toks[3]), int(toks[4])
    off = 7 + nx + ny + nz          # nGrids + 6 header fields + axes
    rest = np.array(toks[off:], dtype=float)
    ncell = nx*ny*nz
    rest = rest[:ncell*3].reshape(ncell, 3)
    active = rest[:, 0].astype(int)
    # grid1.out: Te, Ne, Hden
    g1 = np.loadtxt(f"{run}/output/grid1.out")
    # pdrGrid.out: 45 tokens/cell, first 12 are the scalar record
    with open(f"{run}/output/pdrGrid.out") as f:
        p = np.array(f.read().split(), dtype=float)
    p = p[:ncell*45].reshape(ncell, 45)
    return dict(active=active, Te=g1[:, 0], Ne=g1[:, 1], Hden=g1[:, 2],
                pdrZone=p[:, 0].astype(int), chi=p[:, 1], AV=p[:, 2],
                pdrTgas=p[:, 6], ncell=ncell)

def pct(x, q):
    return np.percentile(x, q) if x.size else float('nan')

def report(label, rel, limit):
    if rel.size == 0:
        print(f"  {label:<22s}  (no cells)"); return
    over = 100.0*np.sum(rel > limit)/rel.size
    print(f"  {label:<22s} n={rel.size:6d}  median {pct(rel,50):8.4f}  "
          f"p90 {pct(rel,90):8.4f}  p99 {pct(rel,99):8.4f}  max {rel.max():9.4f}   "
          f">{limit:.2f}: {over:6.2f}%  ({int(np.sum(rel>limit))} cells)")

a, b = load(sys.argv[1]), load(sys.argv[2])
limit = float(sys.argv[3]) if len(sys.argv) > 3 else 0.10
print(f"=== Te scatter: {sys.argv[1]} vs {sys.argv[2]}   (XHILimit = {limit}) ===")

m = (a['active'] > 0) & (b['active'] > 0) & (a['Te'] > 0) & (b['Te'] > 0)
print(f"active cells compared: {m.sum()}")
# symmetric relative difference, and the one-sided form the test actually uses
rel  = np.abs(a['Te'][m] - b['Te'][m]) / b['Te'][m]
zone = a['pdrZone'][m]; AV = a['AV'][m]; Te = b['Te'][m]

print("\n-- by zone --")
report("all cells",        rel,             limit)
report("PDR zone (==1)",   rel[zone == 1],  limit)
report("ionized (zone 0)", rel[zone == 0],  limit)

print("\n-- PDR cells by A_V --")
for lo, hi in [(0,0.5),(0.5,1),(1,1.5),(1.5,2),(2,2.5),(2.5,3),(3,99)]:
    s = (zone == 1) & (AV >= lo) & (AV < hi)
    report(f"A_V {lo:.1f}-{hi:.1f}", rel[s], limit)

print("\n-- PDR cells by Te --")
for lo, hi in [(0,15),(15,20),(20,30),(30,100),(100,1000),(1000,1e9)]:
    s = (zone == 1) & (Te >= lo) & (Te < hi)
    report(f"Te {lo:g}-{hi:g} K", rel[s], limit)

print(f"\ntotal cells exceeding {limit}: {int(np.sum(rel>limit))} of {rel.size}"
      f"  ({100.0*np.sum(rel>limit)/rel.size:.2f}%)")
