"""D-401. MOCASSIN's own stage fractions of any element by A_V (grid2.out),
median over the cells within 0.012 mag, beside 2n(H2)/nH.

Usage: python3 tools/d401_netbox/ions_by_av.py <run dir> Cl O C ...
"""
import sys, os, numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import d260_roellig as R
run = sys.argv[1]
ELEM, ABUND = R.read_composition(run)
out = os.path.join(run, 'output')
t = open(os.path.join(out, 'grid0.out')).read().split()
nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
n = nx*ny*nz
off = 7+nx+ny+nz
act = np.array(t[off:off+n*3:3], float).astype(int) > 0
idx = np.where(act)[0]
pr = np.loadtxt(os.path.join(out, 'pdrRad.out'), skiprows=1)
g2 = [ln.split() for ln in open(os.path.join(out, 'grid2.out'))]
ne = len(g2)//n
assert ne == len(ELEM), (ne, len(ELEM))
def frac(el, st):
    li = ELEM.index(el)
    return np.array([float(g2[c*ne+li][st]) if len(g2[c*ne+li]) > st else 0. for c in idx])
av = pr[idx, 0]
pg = R.read_pdrgrid(out, n)
ab = pg['ab'][idx]
h2 = 2*ab[:, R.SPEC.index('H2')]
print('elements on:', ' '.join(ELEM))
for el in sys.argv[2:]:
    f0, f1, f2 = frac(el, 0), frac(el, 1), frac(el, 2)
    print(f'--- {el}: MOCASSIN stage fractions (median over cells) by A_V; 2n(H2)/nH median')
    for a in (0.10, 0.20, 0.26, 0.30, 0.34, 0.38, 0.46, 0.58, 0.66, 1.0, 2.0):
        m = np.abs(av-a) < 0.012
        if m.sum() < 3: continue
        tot = f0[m]+f1[m]+f2[m]
        print(f'  A_V {a:5.2f} cells {m.sum():5d}  X0 {np.median(f0[m]):9.3e}  X+ {np.median(f1[m]):9.3e}  X++ {np.median(f2[m]):9.3e}  X+/(X0+X+) {np.median(f1[m]/np.maximum(f0[m]+f1[m],1e-300)):7.4f}  2H2/nH {np.median(h2[m]):9.3e}')
