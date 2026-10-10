"""D-401. The share of the model's FUV photons that can ionize Cl (12.97-13.6 eV)
against the Draine field's, per radial shell of pdrFUVspec.out.

Usage: python3 tools/d401_netbox/clband.py <run dir>
"""
import numpy as np, os, sys
f = os.path.join(sys.argv[1], 'output', 'pdrFUVspec.out')
rows = [l.split() for l in open(f) if not l.lstrip().startswith('#') and l.strip()]
a = np.array([[float(x) for x in r[:7]] for r in rows])
sh = a[:, 0].astype(int); nu = a[:, 3]; lam = a[:, 4]; J = a[:, 5]
RYD = 13.605693
E = nu*RYD
# Draine (1978) photon intensity per eV
FD = lambda e: 1.658e6*e - 2.152e5*e**2 + 6.919e3*e**3
e = np.linspace(6.0, 13.598, 200001)
uD_all = np.trapezoid(e*FD(e), e)
m = e >= 12.968
nD_cl = np.trapezoid(FD(e[m]), e[m])
nsh = sh.max(); rmin, rmax = 4.6795e16, 1.8718e18
print('band of the stored spectrum: %.2f-%.2f eV, %d bins' % (E.min(), E.max(), len(set(a[:,2]))))
print('Draine: photons 12.97-13.6 eV / energy 6-13.6 eV = %.4e per eV' % (nD_cl/uD_all))
print('# shell  r_lo-r_hi [pc]   bins in 12.97-13.6   photons(12.97-13.6)/energy(band): model/Draine')
PC = 3.0857e18
for s in range(1, nsh+1):
    k = sh == s
    lo = rmin*(rmax/rmin)**((s-1)/nsh); hi = rmin*(rmax/rmin)**(s/nsh)
    Eb, Jb = E[k], J[k]
    inb = (Eb >= 6.0) & (Eb < 13.6)
    cl = (Eb >= 12.968) & (Eb < 13.6)
    if Jb[inb].sum() <= 0: continue
    rat = (Jb[cl]/Eb[cl]).sum()/Jb[inb].sum()
    print(' %2d   %.3f-%.3f   %2d   %.3f' % (s, lo/PC, hi/PC, cl.sum(), rat/(nD_cl/uD_all)))
