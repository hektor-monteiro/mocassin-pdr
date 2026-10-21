#!/usr/bin/env python3
"""H-005: the shielded zones of Cloudy's slab, rate by rate.

runs/h005-cloudy-slab/<case>_N15, _N17, _N19, _N20 are the same slab stopped
where N(H2) reaches 1e15 ... 1e20 cm-2, so that Cloudy's full last-zone output
exists there: each level's population and its rates in and out, the continuum
in the zone, every H2 line's optical depth (total and line-specific) and the
chemistry network's Solomon rates.

For that zone, with Cloudy's own choices put in (Federman et al. fit, damping
from the line's own A, optical depth at the zone's inner face including the
other lines at line centre, two-sided escape with the zone's own optical depth
on the far side):
  A  pump rate out of each of the 70 matrix levels, ours/Cloudy, with
     Cloudy's total optical depths and with the line-specific ones (the
     difference is line overlap);
  S  Solomon rate of H2g and H2*, ours with Cloudy's populations over the
     network's, with and without the trapping of line photons;
  C  our closed solution (destroyed molecules replaced, sum fixed) over
     Cloudy's populations;
  D  our rates through Cloudy's scheme (h004_compare.py) over Cloudy's
     populations, and the rescaling factor f from each;
  and Cloudy's own shielding of the H2g Solomon rate against Draine &
  Bertoldi 1996.

    python tools/h005_cuts.py runs/h005-cloudy-slab/<case> [--save FILE.npz]
"""
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import h004_compare as h4          # noqa: E402
import h005_compare as h5          # noqa: E402

HERE = h5.HERE
KEYS = [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4), (0, 5), (1, 1), (1, 3), (2, 3), (6, 3)]


def lastrow(path):
    L = [l for l in open(path).read().split('\n') if l.strip()]
    hd = L[0].lstrip('#').split('\t')
    v = L[-1].split('\t')
    return {k.strip(): float(x) for k, x in zip(hd[1:], v[1:]) if x.strip()}


def federman(tau, a):
    t = np.maximum(tau, 1e-30)
    core = np.where(tau < 2, np.exp(-tau*0.66666), np.where(tau < 10, 0.638*t**-1.25,
                    np.where(tau < 100, 0.505*t**-1.15, 0.344*t**-1.0667)))
    t1 = 3.02*(a*1e3)**-0.064
    u1 = np.sqrt(np.maximum(tau*np.sqrt(np.pi), 0)*a)/t1
    return np.minimum(1., core + a/t1/np.sqrt(0.7854 + u1*u1))


def main(base, save=None):
    lev, E = h5.read_levels()
    n = len(lev)
    lidx = {l: i for i, l in enumerate(lev)}
    out = subprocess.run([os.path.join(HERE, 'h2Test'), os.path.join(HERE, 'dataPDR', 'h2'), 'lines'],
                         capture_output=True, text=True).stdout
    L = np.array([[float(x) for x in l.split()] for l in out.split('\n') if l.strip()])
    wn, A, gu, gl, Dis = L[:, 5], L[:, 6], L[:, 7], L[:, 8], L[:, 10]
    lo = np.array([lidx[(int(r[3]), int(r[4]))] for r in L])
    ups = {}
    uid = np.array([ups.setdefault((int(r[0]), int(r[1]), int(r[2])), len(ups)) for r in L])
    nu = len(ups)
    AX = h4.read_AX()
    v = np.array([l[0] for l in lev]); J = np.array([l[1] for l in lev])
    g = E <= h5.E_STAR
    nm = h4.NMATRIX if hasattr(h4, 'NMATRIX') else 70
    m = np.arange(n) < nm

    def cascade(P, beta):
        Ae = A*beta
        G = np.zeros(nu); np.add.at(G, uid, Ae)
        Du = np.zeros(nu); Du[uid] = Dis
        G = G + Du
        B = np.zeros((nu, n)); np.add.at(B, (uid, lo), Ae/G[uid])
        Pin = np.zeros((n, nu)); np.add.at(Pin, (lo, uid), P)
        return Pin @ B, Pin @ (Du/G)

    saved = []
    for tag in ('N15', 'N17', 'N19', 'N20'):
        d = f'{base}_{tag}'
        if not os.path.exists(os.path.join(d, 'cut.pops')):
            continue
        rows, op = {}, {}
        for l in open(os.path.join(d, 'cut.pops')):
            s = l.split('\t')
            if l.startswith('#') or len(s) < 4:
                continue
            if s[3].strip() in ('ortho', 'para', 'total'):
                op[s[3].strip()] = float(s[2]); continue
            rows[(int(s[0]), int(s[1]))] = (float(s[4]), float(s[10]), float(s[11]), float(s[12]), float(s[13]))
        pc, rcout, rrout, rcin, rrin = np.array([rows[k] for k in lev]).T
        nt = op['total']
        c = lastrow(os.path.join(d, 'cut.dens'))
        gh = lastrow(os.path.join(d, 'cut.gh2'))
        wcar = sum(x for k, x in gh.items() if k.startswith('gra'))
        wsil = sum(x for k, x in gh.items() if k.startswith('sil'))
        ovr = np.array([[float(x) for x in r[:2]] for r in h5.rows(os.path.join(d, 'cut.ovr'))])
        T = ovr[-1, 1]
        z0 = 0.
        for k in range(len(ovr)):
            dr = 2*(ovr[k, 0] - z0); z0 += dr
        b = np.sqrt(2*h5.KB*T/(h5.MH2*h5.AMU))
        # the continuum in the zone
        a = np.loadtxt(os.path.join(d, 'cut.con'), usecols=(0, 2, 1))
        a = a[(a[:, 0] > 0.3) & (a[:, 0] < 1.2)]
        fw = a[:, 0]*h5.RYD_WN
        etac = a[:, 1]*h5.C**2/(8*np.pi*h5.H*(a[:, 0]*h5.RYD_HZ)**4)
        lw = (fw > 91000.) & (fw < 109000.)
        att = np.median(a[lw, 1]/a[lw, 2])           # continuum left at 912-1100 A
        i = np.clip(np.searchsorted(fw, wn), 1, len(fw) - 1)
        eta = etac[np.where(wn - fw[i - 1] <= fw[i] - wn, i - 1, i)]
        # columns: total, and to the zone's inner face
        colC = {}
        for l in open(os.path.join(d, 'cut.h2col')):
            s = l.split('\t')
            if l.startswith('#') or len(s) < 4 or s[3].strip() in ('ortho', 'para', 'total'):
                continue
            colC[(int(s[0]), int(s[1]))] = float(s[3])
        N = np.array([colC.get(k, 0.) for k in lev])
        Nin = np.maximum(N - pc*nt*dr, 0.)
        sig = gu/gl*A/wn**3/(8*np.pi**1.5*b)
        aown = A/wn/(4*np.pi*b)
        # Cloudy's total over line-specific optical depth, line by line
        ct = np.array([(float(r[1])*h5.RYD_WN, float(r[2]), float(r[3])) for r in h5.rows(os.path.join(d, 'cut.tau'))
                       if r[0].strip().startswith('H2')])
        order = np.argsort(wn); wns = wn[order]
        j = np.clip(np.searchsorted(wns, ct[:, 0]), 1, len(wns) - 1)
        pick = np.where(np.abs(wns[j - 1] - ct[:, 0]) < np.abs(wns[j] - ct[:, 0]), j - 1, j)
        ok = (np.abs(wns[pick] - ct[:, 0]) < 0.05) & (ct[:, 2] > 0)
        ratio = np.ones(len(wn)); ratio[order[pick[ok]]] = ct[ok, 1]/ct[ok, 2]
        tin = Nin[lo]*sig
        tout = (N[lo] - Nin[lo])*sig
        P = {'specific': A*gu/gl*eta*federman(tin, aown), 'total': A*gu/gl*eta*federman(tin*ratio, aown)}
        print(f'{tag}: N(H2) = {N.sum():.3e} cm-2, n(H2) = {nt:.3e}, n(H) = {c["H"]:.3e}; '
              f'the last zone holds {1 - Nin[0]/N[0]:.3f} of N(0,0)')
        for name in ('total', 'specific'):
            ra = (np.bincount(lo, weights=P[name], minlength=n)/rrout)[m]
            print(f'   A pump per level, {name:8s} tau: median {np.median(ra):.3f}  16-84% {np.percentile(ra, 16):.3f} '
                  f'{np.percentile(ra, 84):.3f}')
        beta = 0.5*(federman(tin*ratio, aown) + federman(tout*ratio, aown))
        solC = {sp: lastrow(os.path.join(d, f))['PHOTON,%s=>H,H' % sp]/c[sp]
                for sp, f in (('H2', 'cut.h2dest'), ('H2*', 'cut.h2sdest'))}
        res = {}
        for trap in (False, True):
            W, kd = cascade(P['total'], beta if trap else np.ones(len(A)))
            res[trap] = (W, kd)
            sg = (pc[g]*kd[g]).sum()/pc[g].sum(); ss = (pc[~g]*kd[~g]).sum()/pc[~g].sum()
            print(f'   S Solomon ours/Cloudy, {"with" if trap else "no  "} trapping: H2g {sg/solC["H2"]:.3f}  H2* {ss/solC["H2*"]:.3f}'
                  + (f'   (Cloudy H2g {solC["H2"]:.3e} s-1)' if trap else ''))
        W, kd = res[True]
        # collisions and X-state decay from h2_mod at Cloudy's densities
        wd = os.path.join(d, 'h2test'); os.makedirs(wd, exist_ok=True)
        np.savetxt(os.path.join(wd, 'f.field'), np.c_[[1e4, 2e5], [0., 0.]])
        dens = [c['H'], c['He'], op['ortho'], op['para'], c['H+'] + c['H3+']]
        open(os.path.join(wd, 'cases.txt'), 'w').write(
            f'cut {T} ' + ' '.join(f'{x:.6e}' for x in dens) + f' f.field 0.0 {wsil:.6e} {wcar:.6e}\n')
        subprocess.run([os.path.join(HERE, 'h2Test'), os.path.join(HERE, 'dataPDR', 'h2'), 'cases.txt', 'dump'],
                       cwd=wd, check=True, stdout=subprocess.DEVNULL)
        phi = np.loadtxt(os.path.join(wd, 'cut.h2pops'))[:, 6]
        R = np.fromfile(os.path.join(wd, 'cut.h2W'))[n*n:].reshape((n, n), order='F')
        Tm = R + W
        np.fill_diagonal(Tm, 0.)
        M = Tm.T + np.outer(phi, kd)
        M[np.arange(n), np.arange(n)] = -Tm.sum(1) - kd + phi*kd
        rhs = np.zeros(n); M[0, :] = 1.; rhs[0] = 1.
        po = np.linalg.solve(M, rhs)
        F = c['H']*(wcar + wsil)/nt
        S = phi*F
        fC = np.median((pc*(rcout + rrout)/((rcin + rrin)/nt + S))[~m])
        k2 = kd.copy(); k2[g] += solC['H2']
        fD, pD = h4.solve_scheme(Tm, k2, S, nm)
        print(f'   C our solution / Cloudy:  f* {po[~g].sum()/pc[~g].sum():.3f}   '
              + ' '.join(f'{k[0]},{k[1]} {po[lidx[k]]/pc[lidx[k]]:.3f}' for k in KEYS)
              + f'   o/p {po[J % 2 == 1].sum()/po[J % 2 == 0].sum():.2f} (Cloudy {pc[J % 2 == 1].sum()/pc[J % 2 == 0].sum():.2f})')
        if pD is not None:
            print(f'   D Cloudy\'s scheme / Cloudy: f* {pD[~g].sum()/pc[~g].sum():.3f}   '
                  + ' '.join(f'{k[0]},{k[1]} {pD[lidx[k]]/pc[lidx[k]]:.3f}' for k in KEYS)
                  + f'   f {fD:.4f} (Cloudy {fC:.4f})')
        # Cloudy's own shielding of the H2g rate against Draine & Bertoldi 1996 (eq. 37)
        c0 = h4.table(os.path.join(d, 'cut.dens'))
        sol0 = h4.table(os.path.join(d, 'cut.h2dest'))['PHOTON,H2=>H,H']/c0['H2']
        x = Nin.sum()/5e14
        db = 0.965/(1 + x/(b/1e5))**2 + 0.035/np.sqrt(1 + x)*np.exp(-8.5e-4*np.sqrt(1 + x))
        print(f'   Cloudy\'s own H2g rate: {solC["H2"]:.3e} s-1 = {solC["H2"]/sol0:.3e} of its surface rate; continuum left '
              f'{att:.3f}; shielding {solC["H2"]/sol0/att:.3e} against DB96 {db:.3e}: ratio {solC["H2"]/sol0/att/db:.3f}')
        saved.append((Nin.sum(), solC['H2']/sol0/att, db))
    if save:
        np.savez(save, cuts=np.array(saved))


if __name__ == '__main__':
    argv = sys.argv[1:]
    save = argv[argv.index('--save') + 1] if '--save' in argv else None
    main([a for a in argv if not a.startswith('--') and a != save][0], save)
