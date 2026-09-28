#!/usr/bin/env python3
"""D-381: stage-1 sub-cell front profile, offline (D-380's first stage).

For every cell in output/frontField.out (cells with x(H+) > 1e-4; the Monte
Carlo's Jste and the opacity its packets saw, from the Lyman edge up) this
integrates the ionization of H and He through the cell along the radial
direction, at the cell's own temperature, and evaluates [O I] 6300 and 63 um
at every depth. The ratio of the profile's mean emissivity to the one the
homogeneous cell has, C, times the cell's own emissivity (pdrLineEm.out) is
the stage-1 prediction. Nothing here feeds back into a run.

What it takes from MOCASSIN, so that no rate is duplicated:
  - the field entering the cell, J_in = J tau/(1 - e^-tau) per bin, with tau
    the Monte Carlo opacity over the cell's chord along r (plane front);
  - the recombination coefficients, as the cell's own balance implies them:
    alpha = Gamma n(X^i) / (n(X^i+1) n_e) at its T, for H0, He0 and He+;
  - O0/O+ as the cell's ratio to H0/H+ (charge exchange locks them, D-263);
    O++/O+ scaled with the photoionization rate above 35.1 eV;
  - the H0, He0, He+ cross sections from the file header (xSecArray).
The O I atom is D-284's 5-level solve on dataPDR/16o.dat, with Barklem's
electron rates for 1D and 1S. It enters only as the ratio C, so its absolute
accuracy mostly cancels.

Approximations (stage 1): one T for the whole cell; a plane front normal to
r; the whole field enters through one face (the diffuse field included); the
metals' electrons held at the cell's value; dust absorption constant.

    python tools/d381_subcell.py runs/A [runs/B ...] [--cells N]
"""
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R

HC = 6.62607e-27 * 2.99792e10          # h c [erg cm]
KB = 1.380649e-16
PC = 3.0857e18
RYD_O2 = 35.1211 / 13.6057             # O+ -> O++ threshold [Ryd]

# ---------------------------------------------------------------- O I atom
_REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_L = [l.rstrip('\n') for l in open(os.path.join(_REPO, 'dataPDR', '16o.dat'))]


def _after(tag, start=0):
    for i in range(start, len(_L)):
        if _L[i].startswith(tag):
            return i + 1


NL = int(_L[_after('!NUMBER OF ENERGY LEVELS')].split()[0])
_i0 = _after('!LEVEL')
E_LEV = np.array([float(_L[_i0 + k].split()[1]) for k in range(NL)])
G_LEV = np.array([float(_L[_i0 + k].split()[2]) for k in range(NL)])
A_EIN = np.zeros((NL, NL))
_nr = int(_L[_after('!NUMBER OF RADIATIVE')])
_i0 = _after('!TRANS + UP')
for _k in range(_nr):
    _s = _L[_i0 + _k].split()
    A_EIN[int(_s[1]) - 1, int(_s[2]) - 1] = float(_s[3])
COLL = {}
_pos = 0
while True:
    _j = _after('!COLLISIONS BETWEEN', _pos)
    if _j is None:
        break
    _pid = int(_L[_j].split()[0])
    _nt = int(_L[_after('!NUMBER OF COLL TRANS', _j)])
    _ntemp = int(_L[_after('!NUMBER OF COLL TEMPS', _j)])
    _Tg = np.array(_L[_after('!COLL TEMPS', _j)].split(), float)
    _kr = _after('!TRANS + UP', _j)
    _rows = [_L[_kr + k].split() for k in range(_nt)]
    COLL[_pid] = (_Tg, [(int(r[1]) - 1, int(r[2]) - 1, np.array(r[3:3 + _ntemp], float)) for r in _rows])
    _pos = _kr + _nt
# Barklem 2007 electron Upsilons for the 1D and 1S terms (as D-284 uses them)
_TB = np.array([1000, 3000, 5000, 8000, 12000, 20000, 50000.])
_UPS = {(1, 4): [8.61E-04, 1.91E-02, 5.44E-02, 1.12E-01, 1.83E-01, 3.03E-01, 5.54E-01],
        (2, 4): [5.16E-04, 1.14E-02, 3.26E-02, 6.69E-02, 1.10E-01, 1.82E-01, 3.33E-01],
        (3, 4): [1.72E-04, 3.82E-03, 1.09E-02, 2.23E-02, 3.67E-02, 6.06E-02, 1.11E-01],
        (1, 5): [1.22E-02, 1.48E-02, 2.10E-02, 3.03E-02, 4.01E-02, 5.44E-02, 8.05E-02],
        (2, 5): [7.35E-03, 8.90E-03, 1.26E-02, 1.82E-02, 2.41E-02, 3.26E-02, 4.83E-02],
        (3, 5): [2.45E-03, 2.97E-03, 4.20E-03, 6.05E-03, 8.03E-03, 1.09E-02, 1.61E-02],
        (4, 5): [5.55E-02, 7.16E-02, 8.83E-02, 1.07E-01, 1.26E-01, 1.53E-01, 2.28E-01]}
DE = (E_LEV[:, None] - E_LEV[None, :]) * HC        # erg, [u, l]
PID_E, PID_H, PID_HE, PID_HP = 4, 5, 6, 7


# ------------------------------------- MOCASSIN's radiative recombination
# Verner & Ferland 1996 fits, read from data/radrec.dat in radRecFit's order
# (update_mod.f90): the two-parameter block first, then (a, b, T0, T1) for
# ions with 1, 2, 3 electrons, elements ascending.
def _vf96():
    lines = [l.strip() for l in open(os.path.join(_REPO, 'data', 'radrec.dat')) if l.strip()]
    n = sum(1 for ion in range(4, 31) if ion != 11 for el in range(ion, 31) if el != 26 or ion >= 14)
    get = lambda k: np.array(lines[k].split(','), float)
    return {'HI': get(n), 'HeII': get(n + 1), 'HeI': get(n + 30)}


VF = _vf96()


def radrec(key, T):
    a, b, T0, T1 = VF[key]
    tt = np.sqrt(T / T0)
    return a / (tt * (1 + tt) ** (1 - b) * (1 + np.sqrt(T / T1)) ** (1 + b))


def rate_coeffs(T):
    """De-excitation rate coefficients k[pid][u, l] at T (cm^3/s)."""
    k = {}
    for pid, (Tg, rows) in COLL.items():
        m = np.zeros((NL, NL))
        for u, l, v in rows:
            if pid == PID_E and u >= 3:
                continue
            m[u, l] += np.interp(T, Tg, v)
        k[pid] = m
    for (lo, up), ups in _UPS.items():
        k[PID_E][up - 1, lo - 1] += 8.629e-6 * np.interp(T, _TB, ups) / (G_LEV[up - 1] * np.sqrt(T))
    return k


def emissivity(T, k, dens):
    """Per O atom, erg/s, for 63 um (2->1) and 6300 (4->1); dens: pid -> array over depth."""
    nz = len(next(iter(dens.values())))
    q = np.zeros((nz, NL, NL))
    for pid, n in dens.items():
        if pid in k:
            q += n[:, None, None] * k[pid][None, :, :]
    for u in range(NL):
        for l in range(u):
            q[:, l, u] = q[:, u, l] * G_LEV[u] / G_LEV[l] * np.exp(-DE[u, l] / (KB * T))
    rate = q + A_EIN[None, :, :]                     # rate[i, j] = i -> j
    M = np.transpose(rate, (0, 2, 1)).copy()         # M[j, i] = rate i -> j
    for i in range(NL):
        M[:, i, i] = -rate[:, i, :].sum(axis=1) + rate[:, i, i]
    M[:, 0, :] = 1.
    b = np.zeros((nz, NL)); b[:, 0] = 1.
    p = np.linalg.solve(M, b[:, :, None])[:, :, 0]
    e63 = p[:, 1] * A_EIN[1, 0] * DE[1, 0]
    e6300 = p[:, 3] * A_EIN[3, 0] * DE[3, 0]
    return e63, e6300


# ---------------------------------------------------------------- readers
def read_front(out):
    t = open(os.path.join(out, 'frontField.out')).read().split('\n', 1)[1].split()
    p = 0
    nlo, nb = int(t[0]), int(t[1]); p = 2
    nn = nb - nlo + 1
    arr = lambda: np.array(t[p:p + nn], float)
    nu = arr(); p += nn
    sH = arr(); p += nn
    sHe0 = arr(); p += nn
    sHe1 = arr(); p += nn
    cells = []
    while p < len(t):
        iG, nout = int(t[p]), int(t[p + 1]); p += 2
        for _ in range(nout):
            i, j, k = int(t[p + 1]), int(t[p + 2]), int(t[p + 3]); p += 5
            J = arr(); p += nn
            kap = arr(); p += nn
            kd = arr(); p += nn
            cells.append((i, j, k, J, kap, kd))
    return nu, sH, sHe0, sHe1, cells


def grid_geom(out):
    t = open(os.path.join(out, 'grid0.out')).read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3]); n = nx * ny * nz; off = 7 + nx + ny + nz
    ax = [np.array(t[7:7 + nx], float), np.array(t[7 + nx:7 + nx + ny], float),
          np.array(t[7 + nx + ny:7 + nx + ny + nz], float)]
    act = np.array(t[off:off + n * 3:3], float).astype(int) > 0
    W = [np.diff(np.concatenate(([a[0]], 0.5 * (a[1:] + a[:-1]), [a[-1]]))) for a in ax]
    dV = 8 * np.einsum('i,j,k->ijk', *W).ravel()[act]
    return nx, ny, nz, ax, act, dV


# ---------------------------------------------------------------- the profile
def profile(J, kap, kd, nu, sH, sHe0, sHe1, L, nH, AHe, cell):
    """Integrate x(z) through the cell. cell: dict of the homogeneous state."""
    ph = J / nu                                       # photon rate per bin (arbitrary units)
    tb = kap * L
    with np.errstate(over='ignore', invalid='ignore'):
        fac = np.where(tb > 1e-6, tb / -np.expm1(-tb), 1.)
    phin = ph * fac                                   # entering, per bin
    GH, GHe0, GHe1 = (ph * sH).sum(), (ph * sHe0).sum(), (ph * sHe1).sum()
    ne0 = cell['ne']
    T = cell['T']
    aH = GH * cell['xH0'] / (cell['xHp'] * ne0)
    # He from the cell's own balance where both stages are present; where one
    # is empty the balance cannot give it, and MOCASSIN's He/H ratio of
    # radRecFit at the cell's T is applied to the cell's own H value (the
    # field's normalization cancels only within one unit system)
    if cell['y0'] > 1e-6 and cell['y1'] > 1e-6 and GHe0 > 0:
        aHe0 = GHe0 * cell['y0'] / (cell['y1'] * ne0)
    else:
        aHe0 = aH * radrec('HeI', T) / radrec('HI', T)
    if cell['y1'] > 1e-6 and cell['y2'] > 1e-6 and GHe1 > 0:
        aHe1 = GHe1 * cell['y1'] / (cell['y2'] * ne0)
    else:
        aHe1 = aH * radrec('HeII', T) / radrec('HI', T)
    neo = max(ne0 - nH * (cell['xHp'] + AHe * (cell['y1'] + 2 * cell['y2'])), 1e-6 * nH)
    hi = nu >= RYD_O2
    G35c = (ph[hi] * sHe0[hi]).sum()
    zs, dzs, st = [], [], []
    tau = np.zeros_like(nu)
    z = 0.
    ne = ne0
    rin = phin.sum()

    def local(tau_, ne_):
        Jz = phin * np.exp(-tau_)
        gH, g0, g1 = (Jz * sH).sum(), (Jz * sHe0).sum(), (Jz * sHe1).sum()
        g35 = (Jz[hi] * sHe0[hi]).sum()
        for _ in range(6):                            # n_e fixed point (He electrons lag)
            r1 = g0 / (aHe0 * ne_)
            r2 = g1 / (aHe1 * ne_)
            y0 = 1. / (1. + r1 + r1 * r2); y1 = r1 * y0; y2 = r1 * r2 * y0
            neo_ = neo + nH * AHe * (y1 + 2 * y2)
            # H: aH ne^2 + (gH - aH neo_) ne - (nH + neo_) gH = 0
            bq = gH - aH * neo_
            ne_new = (-bq + np.sqrt(bq * bq + 4 * aH * (nH + neo_) * gH)) / (2 * aH) if aH > 0 else nH + neo_
            ne_new = max(ne_new, neo_)
            if abs(ne_new - ne_) < 1e-6 * ne_:
                ne_ = ne_new
                break
            ne_ = ne_new
        xHp = gH / (gH + aH * ne_) if gH > 0 else 0.
        return dict(ne=ne_, xHp=xHp, xH0=1 - xHp, y0=y0, y1=y1, y2=y2, g35=g35, gH=gH,
                    rate=Jz.sum())

    while z < L:
        s = local(tau, ne)
        ne = s['ne']
        k_abs = nH * (s['xH0'] * sH + AHe * (s['y0'] * sHe0 + s['y1'] * sHe1)) + kd
        w = phin * np.exp(-tau)
        keff = (w * k_abs).sum() / max(w.sum(), 1e-300)
        dz = min(L / 400., 0.05 / max(keff, 1e-300), L - z)
        if s['rate'] < 1e-8 * rin:                    # dark: the rest of the cell is this state
            dz = L - z
        # midpoint
        s2 = local(tau + 0.5 * dz * k_abs, ne)
        k2 = nH * (s2['xH0'] * sH + AHe * (s2['y0'] * sHe0 + s2['y1'] * sHe1)) + kd
        zs.append(z + 0.5 * dz); dzs.append(dz); st.append(s2)
        tau = tau + dz * k2
        z += dz
    P = {key: np.array([s[key] for s in st]) for key in st[0]}
    P['dz'] = np.array(dzs); P['z'] = np.array(zs)
    P['G35c'] = G35c; P['aH'] = aH
    P['absH_prof'] = (nH * P['xH0'] * P['gH'] * P['dz']).sum()
    P['absH_hom'] = nH * cell['xH0'] * GH * L
    return P


def run_cells(run, ncells_show=0):
    out = os.path.join(run, 'output')
    ELEM, AB = R.read_composition(run)
    d = R.read_run(run)
    nx, ny, nz, ax, act, dV = grid_geom(out)
    idx = np.where(act)[0]
    where = {c: m for m, c in enumerate(idx)}
    nH = np.loadtxt(os.path.join(out, 'grid1.out'))[act][:, 2]
    n = nx * ny * nz
    _L = np.loadtxt(os.path.join(out, 'pdrLineEm.out'), skiprows=1)
    Lem = (_L[0::2] if len(_L) == 2 * n else _L)[act]
    e63c, e6300c = Lem[:, 56] * dV, Lem[:, 59] * dV
    lf = os.path.join(out, 'lineFlux.out')
    Hb = (float(re.search(r'Hbeta \[E36 erg/s\]:\s+(\S+)', open(lf).read()).group(1)) * 1e36
          if os.path.exists(lf) else np.nan)
    nu, sH, sHe0, sHe1, cells = read_front(out)
    dx = np.median(np.diff(ax[0]))
    AHe = AB['He']
    xHp_all = d['H+'] / nH
    C63 = np.ones(len(idx)); C6300 = np.ones(len(idx))
    rows = []
    for (i, j, k, J, kap, kd) in cells:
        c = ((i - 1) * ny + (j - 1)) * nz + (k - 1)
        m = where[c]
        rv = np.array([ax[0][i - 1], ax[1][j - 1], ax[2][k - 1]])
        rr = np.linalg.norm(rv)
        if rr <= 0 or J.sum() <= 0:
            continue
        nh = nH[m]; T = d['Tgas'][m]
        He = AHe * nh
        cell = dict(ne=d['e-'][m], T=T, xHp=d['H+'][m] / nh, xH0=d['H'][m] / nh,
                    y1=d['He+'][m] / He, y2=d['He++'][m] / He)
        cell['y0'] = max(1 - cell['y1'] - cell['y2'], 0.)
        if cell['xH0'] <= 0 or cell['xHp'] <= 0:
            continue
        L = dx / np.abs(rv / rr).sum()
        P = profile(J, kap, kd, nu, sH, sHe0, sHe1, L, nh, AHe, cell)
        # oxygen: O0/O+ locked to H0/H+ at the cell's ratio; O++/O+ with the >35 eV rate
        O0, O1, O2 = d['O'][m], d['O+'][m], d['O++'][m]
        RO = (O0 / O1) / (cell['xH0'] / cell['xHp']) if O1 > 0 else np.inf
        q2 = O2 / O1 if O1 > 0 else 0.
        with np.errstate(divide='ignore', invalid='ignore'):
            q2z = q2 * (P['g35'] / P['G35c']) * (cell['ne'] / P['ne']) if P['G35c'] > 0 else 0. * P['ne']
            OpO0 = P['xHp'] / (np.maximum(P['xH0'], 1e-300) * RO)
            fO0 = 1. / (1. + OpO0 * (1. + q2z))
        Otot = O0 + O1 + O2
        kc = rate_coeffs(T)
        dens = {PID_E: P['ne'], PID_H: nh * P['xH0'], PID_HP: nh * P['xHp'], PID_HE: He * P['y0']}
        e63, e6300 = emissivity(T, kc, dens)
        dens0 = {PID_E: np.array([cell['ne']]), PID_H: np.array([nh * cell['xH0']]),
                 PID_HP: np.array([nh * cell['xHp']]), PID_HE: np.array([He * cell['y0']])}
        h63, h6300 = emissivity(T, kc, dens0)
        wz = P['dz'] / L
        prof63 = (Otot * fO0 * e63 * wz).sum(); hom63 = O0 * h63[0]
        prof6300 = (Otot * fO0 * e6300 * wz).sum(); hom6300 = O0 * h6300[0]
        C63[m] = prof63 / hom63 if hom63 > 0 else 1.
        C6300[m] = prof6300 / hom6300 if hom6300 > 0 else 1.
        rows.append(dict(m=m, r=rr / PC, L=L, x=cell['xHp'], xm=(P['xHp'] * wz).sum(),
                         T=T, tau=(kap[0] * L), C63=C63[m], C6300=C6300[m],
                         bud=P['absH_prof'] / P['absH_hom'] if P['absH_hom'] > 0 else np.nan,
                         nz=len(P['z'])))
    return dict(run=run, Hb=Hb, e63=e63c, e6300=e6300c, C63=C63, C6300=C6300, xHp=xHp_all,
                rows=rows, dx=dx, ncells=len(cells))


def report(res, ncells_show=0):
    front = (res['xHp'] > 0.01) & (res['xHp'] <= 0.95)
    print(f"== {res['run']}: cell {res['dx']:.3e} cm, {res['ncells']} cells in frontField.out, "
          f"Hbeta {res['Hb']:.4e} erg/s")
    for lab, e, C in [('[O I] 6300', res['e6300'], res['C6300']), ('[O I] 63', res['e63'], res['C63'])]:
        tot, cor = e.sum(), (C * e).sum()
        ft, fc = e[front].sum(), (C * e)[front].sum()
        print(f"   {lab:10s} total {tot:.4e} erg/s ({tot / res['Hb']:.4g} Hb) -> corrected {cor:.4e} "
              f"({cor / res['Hb']:.4g} Hb);  front cells {ft:.4e} -> {fc:.4e} (x{fc / ft:.3f})")
    rw = res['rows']
    if rw:
        thick = [r for r in rw if r['tau'] > 100]
        if thick:
            q = np.array([r['xm'] / r['x'] ** 2 for r in thick])
            b = np.array([r['bud'] for r in thick])
            print(f"   thick cells (tau912 > 100): {len(thick)}; <x(z)>/x^2 median {np.median(q):.3f} "
                  f"(10-90% {np.percentile(q, 10):.3f}-{np.percentile(q, 90):.3f}); H absorbed profile/cell "
                  f"median {np.median(b):.3f} ({np.percentile(b, 10):.3f}-{np.percentile(b, 90):.3f})")
        thin = [r for r in rw if r['x'] > 0.95]
        if thin:
            print(f"   ionized cells (x > 0.95): {len(thin)}; C6300 median {np.median([r['C6300'] for r in thin]):.3f}, "
                  f"C63 median {np.median([r['C63'] for r in thin]):.3f}")
    if ncells_show:
        print('      r[pc]   L[cm]     x(H+)  <x(z)>   x^2     T      tau912   C6300   C63    Habs p/h  steps')
        for r in sorted(rw, key=lambda r: -res['e6300'][r['m']])[:ncells_show]:
            print(f"     {r['r']:6.3f} {r['L']:.2e} {r['x']:7.4f} {r['xm']:7.4f} {r['x'] ** 2:7.4f} {r['T']:7.0f} "
                  f"{r['tau']:8.3g} {r['C6300']:7.4f} {r['C63']:7.3f} {r['bud']:7.3f} {r['nz']:6d}")


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    show = 0
    for a in sys.argv[1:]:
        if a.startswith('--cells'):
            show = int(a.split('=')[1]) if '=' in a else 12
    for run in args:
        report(run_cells(run), show)
