#!/usr/bin/env python3
"""D-462: check of qheat_mod (stochastic grain heating) through qhTest.

Each case is a grain from one of Draine's Q tables in dustData. The field is MMP83's interstellar field times chi
plus the CMB, on a 600-bin geometric grid from 1.001e-5 to 15 Ryd. Optionally a Lya line carries a share of the
grain's absorbed power, and a continuous term is added as a fraction of it.

For each case the tool writes qhTest's case file, runs qhTest, and compares it with three references:
  (1) the same algorithm in numpy, on qheat_mod's grid and histogram: the mean T, P(T) and the spectrum must
      agree to rounding;
  (2) an independent Monte Carlo of the grain's history (Poisson photon arrivals, continuous cooling between
      them) for grains up to 0.02 um with no continuous term: the mean T within 2.5%;
  (3) the equilibrium temperature for grains of 0.05 um and above: the mean T within 1.5%.
It also checks that emitted/absorbed is 1 within 2e-3.

    python tools/d462_qheat_check.py ./qhTest OUTDIR       (exit status 1 if any check fails)
"""
import os
import subprocess
import sys

import numpy as np

f32 = lambda v: float(np.float32(v))                                   # noqa: E731  constants_mod's reals
H, C, FR1RYD, K, AMU, PI = (f32(6.6262e-27), f32(2.9979250e10), f32(3.28984e15), f32(1.380658e-16),
                            f32(1.66053e-24), f32(3.141592654))
DUST = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'dustData')
NT, TLO, TMAX = 300, 1., 700.
#        label            table          a[um]   chi  Lya share  continuous / absorbed
CASES = [('C005_isrf', 'grph-avg.cat', 0.005, 1., 0., 0.),
         ('C010_isrf', 'grph-avg.cat', 0.010, 1., 0., 0.),
         ('C005_x1e2_lya', 'grph-avg.cat', 0.005, 1e2, 0.4, 0.),
         ('C010_x1e4_lya', 'grph-avg.cat', 0.010, 1e4, 0.4, 0.),
         ('C020_x1e2_lya', 'grph-avg.cat', 0.020, 1e2, 0.4, 0.),
         ('C050_x1e2', 'grph-avg.cat', 0.050, 1e2, 0., 0.),
         ('C100_x1e2_lya', 'grph-avg.cat', 0.100, 1e2, 0.4, 0.),
         ('S010_x1e2_lya', 'Sil_21.cat', 0.010, 1e2, 0.4, 0.),
         ('S025_isrf', 'Sil_21.cat', 0.025, 1., 0., 0.),
         ('C010_x1e2_cont+', 'grph-avg.cat', 0.010, 1e2, 0., 0.2),
         ('C010_x1e2_cont-', 'grph-avg.cat', 0.010, 1e2, 0., -0.1)]


def mocgrid(numin=1.001e-5, numax=15., nb=600):
    nu = np.geomspace(numin, numax, nb).astype(np.float32)
    wid = np.empty(nb, np.float32)
    wid[0] = nu[1] - nu[0]
    wid[1:-1] = (nu[2:] - nu[:-2]) / np.float32(2.)
    wid[-1] = nu[-1] - nu[-2]
    return nu, wid


def read_q(path):
    """Draine-format Q table: {a: (lam ascending, Qabs)}, and rho and MsurfAtom from the label line."""
    hdr, rows = None, []
    for n, line in enumerate(open(path)):
        t = line.split('!')[0].split()
        if n == 1:
            hdr = t
        if len(t) >= 5:
            try:
                rows.append([float(x) for x in t[:5]])
            except ValueError:
                pass
    r = np.array(rows)[:, :3]
    q = {}
    for a in np.unique(r[:, 0]):
        s = r[r[:, 0] == a]
        o = np.argsort(s[:, 1])
        q[a] = (s[o, 1], s[o, 2])
    return q, float(hdr[2]), float(hdr[4])


def cabs(nu, q, a):
    lam = C / (nu.astype(float) * FR1RYD) * 1e4
    aa = min(q, key=lambda x: abs(np.log(x / a)))
    l, Q = q[aa]
    return aa, np.pi * aa ** 2 * np.exp(np.interp(np.log(lam), np.log(l), np.log(np.maximum(Q, 1e-300))))


def bnu_h(nuhz, T):
    x = H * nuhz / (K * T)
    return np.where(x > 700., 0., 2 * nuhz ** 3 / C ** 2 / np.expm1(np.minimum(x, 700.)))


def field(nu, wid, chi, lya, cab):
    """Jste per bin [erg s^-1 cm^-2]: MMP83 x chi (Draine 2011 eq 12.7) + CMB, + a Lya line of share lya."""
    nu = nu.astype(float)
    wid = wid.astype(float)
    nuhz = nu * FR1RYD
    lam = C / nuhz * 1e4
    uv = np.where(lam < 0.0912, 0., np.where(lam < 0.110, 38.57 * lam ** 3.4172,
                  np.where(lam < 0.134, 2.045e-2, 7.115e-4 * lam ** -1.6678)))
    jnu = np.where(lam < 0.246, chi * uv * lam / nuhz, 0.)
    star = sum(W * 4 * PI * H * bnu_h(nuhz, T) for W, T in ((1e-14, 7500.), (1e-13, 4000.), (4e-13, 3000.)))
    jnu = jnu + np.where(lam >= 0.246, chi * star, 0.) + 4 * PI * H * bnu_h(nuhz, 2.725)
    js = jnu * wid * FR1RYD
    if lya > 0:
        ia = np.searchsorted(nu, 0.7496, side='right') - 1              # locate, as resLine%nuP
        js[ia] += lya / (1 - lya) * np.sum(cab * js) / cab[ia]
    return js


def enthalpy(T, carb, Nat, vg):
    T = np.asarray(T, float)
    fN = max(Nat - 2., 1.)
    if carb:
        return fN * 4.15e-22 * T ** 3.3 / (1 + 6.51e-3 * T + 1.5e-6 * T * T + 8.3e-7 * T ** 2.3)
    u50 = (1.4e3 / 3.) * 50. ** 3
    u150 = u50 + (2.1647e4 / 2.3) * (150. ** 2.3 - 50. ** 2.3)
    u500 = u150 + (4.8375e5 / 1.68) * (500. ** 1.68 - 150. ** 1.68)
    u = np.where(T <= 50, (1.4e3 / 3.) * T ** 3, np.where(T <= 150, u50 + (2.1647e4 / 2.3) * (T ** 2.3 - 50. ** 2.3),
                 np.where(T <= 500, u150 + (4.8375e5 / 1.68) * (T ** 1.68 - 150. ** 1.68), u500 + 3.3107e7 * (T - 500.))))
    return fN / Nat * vg * u


def edges(nu):
    eR = H * FR1RYD
    nu = nu.astype(float)
    e = np.empty(len(nu) + 1)
    e[0] = max(eR * (1.5 * nu[0] - 0.5 * nu[1]), 0.)
    e[1:-1] = eR * 0.5 * (nu[:-1] + nu[1:])
    e[-1] = eR * (1.5 * nu[-1] - 0.5 * nu[-2])
    return e


def qh_py(nu, wid, fld, cab, cont, carb, Nat, vg):
    """qheat_mod's qhSolve in numpy."""
    nb = len(nu)
    eR = H * FR1RYD
    pconv = 4 * PI * eR
    T = TLO * (TMAX / TLO) ** (np.arange(NT) / (NT - 1))
    Eph = eR * nu.astype(float)
    edge = edges(nu)
    nuhz = nu.astype(float) * FR1RYD
    B = np.array([bnu_h(nuhz, t) for t in T]).T * wid.astype(float)[:, None]
    gam = np.sum(cab * fld)
    f, contH = 1., 0.
    if cont >= 0:
        contH = cont
    else:
        f = (gam + cont) / gam
    E = enthalpy(T, carb, Nat, vg)
    Emin = np.concatenate([[0.], 0.5 * (E[:-1] + E[1:])])
    Emax = np.concatenate([Emin[1:], [E[-1] + (E[-1] - Emin[-1])]])
    dE = Emax - Emin
    w = edge[1:] - edge[:-1]
    dens = np.where(w > 0, f * cab * fld / np.where(w > 0, w, 1.), 0.)
    F0e = np.concatenate([[0.], np.cumsum(dens * w)])
    F1e = np.concatenate([[0.], np.cumsum(dens * 0.5 * (edge[1:] ** 2 - edge[:-1] ** 2))])

    def cum(e):
        e = np.atleast_1d(np.asarray(e, float))
        k = np.clip(np.searchsorted(edge, e, side='right'), 1, nb)
        f0 = F0e[k - 1] + dens[k - 1] * (e - edge[k - 1])
        f1 = F1e[k - 1] + dens[k - 1] * 0.5 * (e * e - edge[k - 1] ** 2)
        lo, hi = e <= edge[0], e >= edge[-1]
        return np.where(lo, 0., np.where(hi, F0e[-1], f0)), np.where(lo, 0., np.where(hi, F1e[-1], f1))
    Tm = np.zeros((NT, NT))
    for l in range(NT - 1):
        u = np.arange(l + 1, NT - 1)
        if len(u):
            W1 = np.maximum(Emin[u] - Emax[l], 0.)
            W2 = np.minimum(Emin[u] - Emin[l], Emax[u] - Emax[l])
            W3 = np.maximum(Emin[u] - Emin[l], Emax[u] - Emax[l])
            W4 = Emax[u] - Emin[l]
            a0, a1 = cum(W1)
            b0, b1 = cum(W2)
            c0, c1 = cum(W3)
            d0, d1 = cum(W4)
            s = ((b1 - a1) - W1 * (b0 - a0)) + np.minimum(dE[l], dE[u]) * (c0 - b0) + (W4 * (d0 - c0) - (d1 - c1))
            Tm[u, l] = s / (dE[l] * (E[u] - E[l]))
        a0, a1 = cum(dE[l])
        Tm[l + 1, l] += (a0[0] - a1[0] / dE[l]) / (E[l + 1] - E[l])
        W1 = max(Emin[-1] - Emax[l], 0.)
        Wc = Emin[-1] - Emin[l]
        a0, a1 = cum(W1)
        b0, b1 = cum(Wc)
        s = F0e[-1] - b0[0]
        if Wc > W1:
            s += ((b1[0] - a1[0]) - W1 * (b0[0] - a0[0])) / (Wc - W1)
        Tm[-1, l] += s / (E[-1] - E[l])
        if contH > 0:
            Tm[l + 1, l] += contH / (E[l + 1] - E[l])
    nI = np.searchsorted(Eph, E, side='left')
    pw = np.zeros(NT)
    cool = np.zeros(NT)
    for u in range(1, NT):
        pw[u] = pconv * np.sum(cab[:nI[u]] * B[:nI[u], u])
        cool[u] = pw[u] / (E[u] - E[u - 1])
    Bs = Tm.copy()
    for l in range(NT - 1):
        Bs[l + 1:, l] = np.cumsum(Tm[l + 1:, l][::-1])[::-1]
    X = np.zeros(NT)
    X[0] = 1.
    for j in range(1, NT):
        X[j] = np.dot(Bs[j, :j], X[:j]) / cool[j] if cool[j] > 0 else 0.
        if X[j] > 1e250:
            X[:j + 1] *= 1e-250
    P = X / X.sum()
    spec = np.zeros(nb)
    for u in range(1, NT):
        if P[u] > 0:
            spec[:nI[u]] += P[u] * B[:nI[u], u]
    return T, P, spec * cab, np.sum(P * T), np.sum(P * pw) / (f * gam + contH), P[-1]


def teq(nu, wid, fld, cab):
    nuhz = nu.astype(float) * FR1RYD
    wd = wid.astype(float)
    g = np.sum(cab * fld)
    lo, hi = 0.5, 5000.
    for _ in range(80):
        m = np.sqrt(lo * hi)
        e = 4 * PI * H * FR1RYD * np.sum(cab * bnu_h(nuhz, m) * wd)
        lo, hi = (m, hi) if e < g else (lo, m)
    return np.sqrt(lo * hi)


def mc(nu, wid, fld, cab, carb, Nat, vg, T0, nphot=300000, seed=1):
    """Mean T of a grain whose history is simulated: photons (energy uniform in their bin) arrive at the bins'
    rates; between them the grain cools continuously at the power it radiates below its own energy."""
    rng = np.random.default_rng(seed)
    nb = len(nu)
    pconv = 4 * PI * H * FR1RYD
    edge = edges(nu)
    Eph = H * FR1RYD * nu.astype(float)
    nuhz = nu.astype(float) * FR1RYD
    wd = wid.astype(float)
    Tf = np.geomspace(0.5, 5000., 6000)
    Ef = enthalpy(Tf, carb, Nat, vg)
    L = np.array([pconv * np.sum((cab * bnu_h(nuhz, t) * wd)[Eph < e]) for t, e in zip(Tf, Ef)])
    ok = L > 0.
    Tf, Ef, L = Tf[ok], Ef[ok], L[ok]
    inv = 1. / L
    tau = np.concatenate([[0.], np.cumsum(0.5 * (inv[1:] + inv[:-1]) * np.diff(Ef))])
    rate = cab * fld / (0.5 * (edge[1:] + edge[:-1]))
    R = rate.sum()
    cdf = np.cumsum(rate) / R
    Tg = TLO * (TMAX / TLO) ** (np.arange(NT + 1) / NT)
    tedge = np.interp(enthalpy(Tg, carb, Nat, vg), Ef, tau)
    hist = np.zeros(NT)
    E = enthalpy(np.array([T0]), carb, Nat, vg)[0]
    dts = rng.exponential(1. / R, nphot)
    k = np.minimum(np.searchsorted(cdf, rng.random(nphot)), nb - 1)
    eph = edge[k] + rng.random(nphot) * (edge[k + 1] - edge[k])
    burn = nphot // 20
    floorbin = max(np.searchsorted(Tg, Tf[0]) - 1, 0)
    for n in range(nphot):
        t0 = np.interp(E, Ef, tau)
        t1 = t0 - dts[n]
        if n >= burn:
            hist += np.clip(np.minimum(tedge[1:], t0) - np.maximum(tedge[:-1], max(t1, 0.)), 0., None)
            if t1 < 0.:
                hist[floorbin] += -t1
        E = np.interp(max(t1, 0.), tau, Ef) + eph[n]
    Tc = np.sqrt(Tg[1:] * Tg[:-1])
    return np.sum(hist * Tc) / hist.sum()


def write_case(path, nu, wid, fld, cab, carb, Nat, vg, cont):
    with open(path, 'w') as fh:
        fh.write(f"{len(nu)} {NT} {TLO!r} {TMAX!r} {1 if carb else 0} {float(Nat)!r} {float(vg)!r} {float(cont)!r}\n")
        for a, b, c_, d in zip(nu, wid, fld, cab):
            fh.write(f"{float(a):.9e} {float(b):.9e} {c_:.17e} {d:.17e}\n")


def read_out(path, nb):
    L = open(path).read().split('\n')
    t = L[0].split()
    TP = np.array([[float(x) for x in L[1 + j].split()] for j in range(NT)])
    spec = np.array([float(L[1 + NT + i]) for i in range(nb)])
    return t[0] == 'T', float(t[1]), float(t[2]), float(t[3]), TP[:, 0], TP[:, 1], spec


def main():
    exe, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    nu, wid = mocgrid()
    lines, nfail = [], 0
    lines.append(f"{'case':16s} {'a':>7s} {'Teq':>7s} {'<T>F':>8s} {'<T>py':>8s} {'dT/T':>9s} {'maxdP':>9s} "
                 f"{'dspec':>9s} {'E/A-1':>9s} {'ref':>5s} {'<T>ref':>8s} {'dref':>8s}  verdict")
    for lab, tab, a, chi, lya, cf in CASES:
        q, rho, msurf = read_q(os.path.join(DUST, tab))
        carb = abs(msurf - 12.) < 1.                                    # grainCarb's test (ph_mod)
        aa, cab = cabs(nu, q, a)
        fld = field(nu, wid, chi, lya, cab)
        vg = 4.18879e-12 * aa ** 3
        Nat = vg * rho / (msurf * AMU)
        cont = cf * np.sum(cab * fld)
        cpath, opath = os.path.join(out, lab + '.case'), os.path.join(out, lab + '.out')
        write_case(cpath, nu, wid, fld, cab, carb, Nat, vg, cont)
        rc = subprocess.run([exe, cpath, opath]).returncode
        if rc != 0:
            lines.append(f"{lab:16s} qhTest rc={rc}  FAIL")
            nfail += 1
            continue
        okF, tmF, raF, ptF, TF, PF, sF = read_out(opath, len(nu))
        T, P, s, tm, ra, pt = qh_py(nu, wid, fld, cab, cont, carb, Nat, vg)
        te = teq(nu, wid, fld, cab)
        dT = abs(tmF / tm - 1)
        dP = np.max(np.abs(PF - P))
        dS = np.sum(np.abs(sF - s)) / np.sum(s)
        good = okF and dT <= 1e-5 and dP <= 1e-6 and dS <= 1e-5 and abs(raF - 1) <= 2e-3
        ref, tref, dref = '-', float('nan'), float('nan')
        if aa <= 0.0201 and cf == 0.:
            ref, tref = 'MC', mc(nu, wid, fld, cab, carb, Nat, vg, te)
            dref = tmF / tref - 1
            good = good and abs(dref) <= 0.025
        elif aa >= 0.049 and cf == 0.:
            ref, tref = 'Teq', te
            dref = tmF / tref - 1
            good = good and abs(dref) <= 0.015
        nfail += 0 if good else 1
        lines.append(f"{lab:16s} {aa:7.4f} {te:7.2f} {tmF:8.3f} {tm:8.3f} {dT:9.2e} {dP:9.2e} {dS:9.2e} "
                     f"{raF - 1:+9.2e} {ref:>5s} {tref:8.3f} {dref:+8.4f}  {'PASS' if good else 'FAIL'}")
    lines.append(f"{len(CASES) - nfail} of {len(CASES)} cases pass")
    txt = '\n'.join(lines)
    print(txt)
    open(os.path.join(out, 'summary.txt'), 'w').write(txt + '\n')
    sys.exit(1 if nfail else 0)


if __name__ == '__main__':
    main()
