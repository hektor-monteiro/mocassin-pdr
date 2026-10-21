#!/usr/bin/env python3
"""H-006: line overlap, the exact reference.

For the H2 columns the slab march of H-005 has at a chosen depth, the optical
depth of all H2 lines together is built on a fine wavenumber grid (every line
a Voigt profile, damping from the upper level's total decay rate), and each
pumping line's shielding is integrated through it:

    S_i = int phi_i(nu) exp(-tau_total(nu)) dnu

against the same integral with the line alone (no overlap). The continuum is
taken flat across each line.

    python tools/h006_exact.py <compare.npz of h005_compare.py> <out.npz> [N(H2) ...]
"""
import os
import subprocess
import sys

import numpy as np
from scipy.special import wofz

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
C = 2.99792458e10
KB = 1.380649e-16
AMU = 1.66053907e-24
MH2 = 2.01588
SQPI = np.sqrt(np.pi)


def line_list():
    out = subprocess.run([os.path.join(HERE, 'h2Test'), os.path.join(HERE, 'dataPDR', 'h2'), 'lines'],
                         capture_output=True, text=True).stdout
    return np.array([[float(x) for x in l.split()] for l in out.split('\n') if l.strip()])


def voigt(a, x):
    return wofz(x + 1j*a).real


def exact(L, lo, Ncol, b, sel, dnu=0.05, wn0=84000., wn1=119500., core=12., taumin=1e-3):
    """S with and without overlap for the lines in sel, columns Ncol(level)."""
    wn, A, gu, gl, Gam = L[:, 5], L[:, 6], L[:, 7], L[:, 8], L[:, 9]
    dD = wn*b/C                                   # Doppler width [cm-1]
    a = Gam/(4*np.pi*C*dD)                        # Gamma lambda/(4 pi b)
    sig = gu/gl*A/wn**3/(8*np.pi**1.5*b)
    tau0 = Ncol[lo]*sig
    grid = np.arange(wn0, wn1, dnu)
    tau = np.zeros(len(grid))
    blockers = np.where((tau0 > taumin) & (wn > wn0) & (wn < wn1))[0]
    for j in blockers:
        h0 = voigt(a[j], 0.)
        x = (grid - wn[j])/dD[j]
        far = np.abs(x) > core
        # wings as a Lorentzian, the core as the full Voigt function
        t = np.empty(len(grid))
        t[far] = a[j]/(SQPI*x[far]**2)
        near = ~far
        t[near] = voigt(a[j], x[near])
        tau += tau0[j]*t/h0
    S_ov = np.zeros(len(sel)); S_own = np.zeros(len(sel))
    etau = np.exp(-tau)
    for n, i in enumerate(sel):
        h0 = voigt(a[i], 0.)
        x = (grid - wn[i])/dD[i]
        far = np.abs(x) > core
        ph = np.empty(len(grid))
        ph[far] = a[i]/(SQPI*x[far]**2)
        ph[~far] = voigt(a[i], x[~far])
        own = tau0[i]*ph/h0
        norm = dnu/(SQPI*dD[i])
        S_ov[n] = (ph*etau).sum()*norm
        S_own[n] = (ph*np.exp(-own)).sum()*norm
    return S_ov, S_own, tau0, a, len(blockers)


def main(npz, out, marks):
    d = np.load(npz)
    lev = [tuple(x) for x in d['lev']]
    E = d['E']
    lidx = {l: i for i, l in enumerate(lev)}
    L = line_list()
    lo = np.array([lidx[(int(r[3]), int(r[4]))] for r in L])
    wn = L[:, 5]
    N = d['NH2in']
    dNz = np.diff(N)                               # n(H2) dr of zones 1..nz-1
    pops = d['popV']
    b = np.sqrt(2*KB*100./(MH2*AMU))
    # lines whose lower level is one of the H2g levels and that lie on the grid
    sel = np.where((E[lo] <= 4100.) & (wn > 86000.) & (wn < 118400.))[0]
    res = {}
    print('exact overlap on a %.2f cm-1 grid; %d lines out of the H2g levels' % (0.05, len(sel)))
    print('   N(H2)      blockers   pump rate with overlap / without, by lower level: '
          + ' '.join(f'0,{j}'.rjust(6) for j in range(8)) + '   Solomon g   DB96 factor')
    for m in marks:
        k = int(np.searchsorted(N, m))
        Ncol = (pops[:k]*dNz[:k, None]).sum(0)
        S_ov, S_own, tau0, a, nb = exact(L, lo, Ncol, b, sel)
        P = L[sel, 6]*L[sel, 7]/L[sel, 8]           # A gu/gl, flat continuum
        lvl = lo[sel]
        pl_ov = np.bincount(lvl, weights=P*S_ov, minlength=len(lev))
        pl_own = np.bincount(lvl, weights=P*S_own, minlength=len(lev))
        fd = L[sel, 10]/L[sel, 9]                   # dissociation probability of the upper level
        pz = pops[min(k, len(pops) - 1)]
        sol_ov = (pz[lvl]*P*S_ov*fd).sum(); sol_own = (pz[lvl]*P*S_own*fd).sum()
        x = Ncol.sum()/5e14
        db = np.exp(-8.5e-4*np.sqrt(1 + x))
        print(f'   {Ncol.sum():9.2e}  {nb:6d}      ' + ' '*46
              + ' '.join(f'{pl_ov[lidx[(0, j)]]/pl_own[lidx[(0, j)]]:6.3f}' for j in range(8))
              + f'   {sol_ov/sol_own:7.3f}     {db:7.3f}')
        res[f'{m:.0e}'] = dict(N=Ncol, S_ov=S_ov, S_own=S_own, sel=sel, tau0=tau0, a=a)
    np.savez(out, **{f'{k}__{kk}': v for k, r in res.items() for kk, v in r.items()}, marks=np.array(marks))


if __name__ == '__main__':
    marks = [float(x) for x in sys.argv[3:]] or [1e17, 1e18, 1e19, 1e20, 3e20, 1e21]
    main(sys.argv[1], sys.argv[2], marks)
