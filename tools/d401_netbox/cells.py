"""D-401. The run's own median conditions at eight depths through the H/H2
transition, for the one-cell box (boxTest.f90): writes cells.txt.
Needs an h2-model run (h2Cells.out holds the levels' dissociation rate and the
grain formation coefficient).

Usage: python3 tools/d401_netbox/cells.py <run dir>
"""
import sys, os, numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import d260_roellig as R
run = sys.argv[1]
out = os.path.join(run, 'output')
t = open(os.path.join(out, 'grid0.out')).read().split()
nx, ny, nz = int(t[1]), int(t[2]), int(t[3]); n = nx*ny*nz
off = 7+nx+ny+nz
act = np.array(t[off:off+n*3:3], float).astype(int) > 0
idx = np.where(act)[0]
pr = np.loadtxt(os.path.join(out, 'pdrRad.out'), skiprows=1)
g1 = np.loadtxt(os.path.join(out, 'grid1.out'))
pg = R.read_pdrgrid(out, n)
hc = np.loadtxt(os.path.join(out, 'h2Cells.out'), comments='#')
assert len(hc) == len(idx), (len(hc), len(idx))
av = pr[idx, 0]; Te = g1[idx, 0]; ne = g1[idx, 1]; nh = g1[idx, 2]; Td = pr[idx, 6]
chi = pg['chi'][idx]; ab = pg['ab'][idx]
x2 = 2*ab[:, R.SPEC.index('H2')]; xe = ab[:, R.SPEC.index('e-')]
sol = hc[:, 9]; solc = hc[:, 10]; NH2 = hc[:, 16]; Rf = hc[:, 20]
print('# A_V  T  Td  chi  kdiss(levels)  kdiss(3D-PDR fn)  Rform  N(H2)  2n(H2)/nH(run)  x_e(run)  nH  ncells')
rows = []
for a in (0.22, 0.26, 0.30, 0.34, 0.38, 0.46, 0.58, 0.66):
    m = np.abs(av-a) < 0.012
    md = lambda v: float(np.median(v[m]))
    rows.append((a, md(Te), md(Td), md(chi), md(sol), md(solc), md(Rf), md(NH2), md(x2), md(xe), md(nh), int(m.sum())))
    print(' '.join(f'{v:.4e}' if isinstance(v, float) else str(v) for v in rows[-1]))
with open('cells.txt', 'w') as f:
    f.write(f'{len(rows)}\n')
    for r in rows:
        f.write(' '.join(f'{v:.6e}' for v in r[:11]) + '\n')
