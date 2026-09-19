#!/usr/bin/env python3
"""D-288: MOCASSIN's photoelectric yield against Weingartner & Draine (2001).

D-287 attributed the residual 3-7x in the photoelectric rate to the yield,
by eliminating the field, the charge, the threshold and the size distribution.
That attribution was never checked against WD01's yield itself, and it needs
to be, because WD01's is not uniformly larger than Baldwin's: it rises far
above it near 13.6 eV and falls far below it near the 4.4 eV threshold.

MOCASSIN (Baldwin et al. 1991, update_mod.f90:1305 and :1456), no dependence
on grain radius at all:

    Y = min( 0.5 (1 - nu_0/nu), 0.2 )

WD01 for a NEUTRAL carbonaceous grain, their eqs 12-16:

    Y = min( y0(Theta) * y1(hnu, a), 1 )
    y0 = 9e-3 (Theta/W)^5 / (1 + 3.7e-2 (Theta/W)^5)
    y1 = (b/A)^2 (A^2 - 2A + 2 - 2exp(-A)) / (b^2 - 2b + 2 - 2exp(-b))
    b  = a/la,  A = a/la + a/le,  le = 10 A

la is the photon attenuation length, la = lambda / (4 pi k), taken from the
same optical constants MOCASSIN builds its cross sections from, so nothing
here is a constant standing in for something the model knows. Z = 0
throughout: MOCASSIN applies the Coulomb suppression separately as Yhat, so
the like-for-like comparison is with WD01's neutral yield.

    ~/miniforge3/envs/astro/bin/python tools/d288_yield.py
"""
import os
import sys

import numpy as np

RYD_EV = 13.605693
W_CARB = 4.4          # WD01 work function for carbonaceous grains, eV
LE = 10.0             # electron escape length, Angstrom (WD01)
NU0 = 0.323           # grainVn in the .nk files, Ryd
DUST = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'dustData')
# grph1 (E parallel) 1/3, grph2 (E perpendicular) 2/3, as dust_species.dat
FILES = [('grph2-dl.nk', 2. / 3.), ('grph1-dl.nk', 1. / 3.)]


def optical(ev):
    """n, k at photon energy ev [eV], weighted over the two graphite axes."""
    lam = 1.239842 / ev                      # micron
    n = np.zeros_like(ev)
    k = np.zeros_like(ev)
    for fn, w in FILES:
        a = np.loadtxt(os.path.join(DUST, fn), skiprows=2)
        o = np.argsort(a[:, 0])
        n += w * np.interp(lam, a[o, 0], a[o, 1])
        k += w * np.interp(lam, a[o, 0], a[o, 2])
    return n, k


def y_baldwin(ev):
    return np.minimum(0.5 * (1. - NU0 * RYD_EV / ev), 0.2)


def y_wd01(ev, a_um, k):
    """Neutral-grain yield, WD01 eqs 12-16. a_um in micron."""
    a_A = a_um * 1e4                                    # Angstrom
    lam_A = 1.239842 / ev * 1e4
    la = lam_A / (4. * np.pi * np.maximum(k, 1e-8))     # Angstrom
    b = a_A / la
    A = a_A / la + a_A / LE

    def f(x):
        # x^2 - 2x + 2 - 2exp(-x); series for small x to keep it accurate
        out = np.where(x > 1e-2,
                       x ** 2 - 2 * x + 2 - 2 * np.exp(-np.minimum(x, 700.)),
                       x ** 3 / 3. - x ** 4 / 12.)
        return np.maximum(out, 1e-300)

    y1 = (b / A) ** 2 * f(A) / f(b)
    # threshold for Z = 0: W + 0.5 e^2/a + 2 (e^2/a)(0.3A/a)
    e2a = 14.4 / a_A
    hnu_pet = W_CARB + 0.5 * e2a + 2. * e2a * (0.3 / a_A)
    theta = np.maximum(ev - hnu_pet, 0.)
    r = (theta / W_CARB) ** 5
    y0 = 9e-3 * r / (1. + 3.7e-2 * r)
    return np.minimum(y0 * y1, 1.0)


def main():
    print('Graphite, neutral grains. MOCASSIN uses no grain radius at all.\n')
    ev = np.array([6., 7., 8., 9., 10., 11., 12., 13., 13.6])
    _, k = optical(ev)
    print('photon [eV] ' + ' '.join('%7.1f' % e for e in ev))
    print('k(graphite) ' + ' '.join('%7.3f' % x for x in k))
    print('MOCASSIN    ' + ' '.join('%7.4f' % x for x in y_baldwin(ev)))
    for a in (0.005, 0.01, 0.025, 0.05, 0.1, 0.25):
        print('WD01 %5.3f um' % a + ' '.join(
            '%7.4f' % x for x in y_wd01(ev, a, k)))

    # Band average over the MRN distribution, weighted by ABSORBED photons.
    # Qabs from the Rayleigh limit, capped where the grain becomes large:
    # the weighting only has to be reasonable, and the sensitivity to the cap
    # is printed below.
    print('\nAbsorbed-photon-weighted band average, MRN a^-3.5 '
          '0.005-0.25 um, 4.4-13.6 eV')
    print('spectrum: 150 kK blackbody attenuated by exp(-tau), tau ~ A_V')
    aa = np.geomspace(0.005, 0.25, 120)
    ee = np.linspace(4.5, 13.59, 200)
    nn, kk = optical(ee)
    m = nn + 1j * kk
    ray = 4. * (2 * np.pi * aa[:, None] * 1e4 / (1.239842 / ee[None, :] * 1e4)) \
        * np.imag((m[None, :] ** 2 - 1) / (m[None, :] ** 2 + 2))
    for qcap in (1.0, 2.0):
        qabs = np.minimum(ray, qcap)
        print('  Qabs capped at %.1f:' % qcap)
        for av in (0.0, 0.5, 1.0):
            # blackbody photon flux, times FUV attenuation growing to the blue
            T = 1.5e5
            x = ee / (8.617333e-5 * T)
            nphot = ee ** 2 / np.expm1(x)
            atten = np.exp(-av * (1.0 + 0.9 * (ee - 4.4) / 9.2) / 1.086 * 2.5)
            wsp = nphot * atten
            wgt = (aa[:, None] ** (-3.5) * aa[:, None] ** 2) * qabs * wsp[None, :]
            yb = np.sum(wgt * y_baldwin(ee)[None, :]) / np.sum(wgt)
            yw = np.sum(wgt * np.array([y_wd01(ee, a, kk) for a in aa])) \
                / np.sum(wgt)
            print('    A_V %.1f:  <Y> MOCASSIN %.4f   WD01 %.4f   '
                  'WD01/MOCASSIN %.2f' % (av, yb, yw, yw / yb))


if __name__ == '__main__':
    main()
