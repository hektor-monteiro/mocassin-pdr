#!/usr/bin/env python3
"""D-293: size the Lyman-alpha deposition at the front before implementing it.

D-291 established that Cloudy's deep-PDR Lya is an artifact of attenuating
outward line flux by continuum opacity alone, and that physically Lya should
be destroyed by dust in a thin layer at the ionization front. Option 2 - using
MOCASSIN's escape-probability machinery to put Lya where it actually goes - is
the only route left to O-02's remaining factor, so the question worth
answering before spending a run is: how much energy, over what depth, and can
this grid resolve it?

Everything here comes from the model's own structure (runs/<run>), not from
Cloudy:

  * L(Lya) from MOCASSIN's own recombination structure, Case B;
  * the flux that implies at the front;
  * the destruction depth, from the standard criterion for Lya in a dusty
    medium - essentially all of it is absorbed once
        (a tau_0)^(1/3) tau_a  >~  1
    (Draine, ISM ch. 19), with a the Voigt parameter, tau_0 the line-centre
    optical depth and tau_a the dust ABSORPTION optical depth, both measured
    from the front;
  * the heating that implies, against the photoelectric heating the model
    currently has there;
  * and the cell size, which decides whether any of it is resolvable.

    ~/miniforge3/envs/astro/bin/python tools/d293_lya.py runs/d290-pn150k-grainq
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R
import d288_charge as C

PC = R.PC
E_LYA = 1.634e-11          # erg, 10.199 eV
AV_PER_NH = 3.648e-22      # mag cm^2, matched to Cloudy (D-283)
ALBEDO = 0.4               # graphite near 1216 A, for extinction -> absorption
EXT_1216_OVER_V = 2.5      # MRN graphite


def alpha_B(T):
    """Case B recombination coefficient, Hummer & Storey-like fit [cm^3/s]."""
    t = T / 1e4
    return 2.59e-13 * t ** (-0.833 - 0.035 * np.log(t))


def main(run):
    d = C.read_grain(run)
    r = d['r'] * PC
    # cell volume: uniform cartesian grid, one octant
    g0 = open(os.path.join(run, 'output', 'grid0.out')).read().split()
    nx = int(g0[1])
    xa = np.array(g0[7:7 + nx], float)
    dcell = xa[1] - xa[0]
    dV = dcell ** 3

    np_ = d['H+']                                  # proton density [cm^-3]
    T = d['Tgas']

    # Case B: 0.68 Lya photons per recombination (2/3, the standard value)
    frac = 0.68
    emis = np_ * d['e-'] * alpha_B(T) * frac * E_LYA        # erg cm^-3 s^-1
    ion = d['zone'] == 0
    L_lya = (emis[ion] * dV).sum() * 8.0                    # x8, octant -> sphere
    print('MOCASSIN %s' % run)
    print('  L(Lya), Case B, from this model\'s own recombinations:')
    print('     %.3e erg/s   (Cloudy intrinsic, same model: 4.03e35)' % L_lya)

    # the front and the flux there
    front = d['A_front']
    rf = np.median(r[np.abs(d['AV'] - front) < 0.02])
    area = 4 * np.pi * rf ** 2
    F = L_lya / area
    print('  front at A_V %.3f, r = %.4f pc' % (front, rf / PC))
    print('  Lya flux there   %.4g erg cm^-2 s^-1 = %.0f Habing' % (F, F / 1.6e-3))
    Lfuv = 1.3326e35
    print('  stellar FUV there %.4g erg cm^-2 s^-1 = %.0f Habing  -> Lya/FUV %.2f'
          % (Lfuv / area, Lfuv / area / 1.6e-3, L_lya / Lfuv))

    # destruction depth
    print('\n  where it is destroyed (a tau_0)^1/3 tau_a = 1:')
    sig_a = AV_PER_NH / 1.086 * EXT_1216_OVER_V * (1 - ALBEDO)   # cm^2 per H
    print('     dust absorption cross-section  %.3g cm^2 per H' % sig_a)
    Tpdr = np.median(T[(d['AV'] > front) & (d['AV'] < front + 0.1)])
    nHI = np.median(d['H'][(d['AV'] > front) & (d['AV'] < front + 0.1)])
    print('     just past the front: T = %.0f K, n(H0) = %.0f cm^-3' % (Tpdr, nHI))
    sig0 = 5.9e-14 * (Tpdr / 1e4) ** -0.5
    avoigt = 4.7e-4 * (Tpdr / 1e4) ** -0.5
    print('     sigma_0 = %.3g cm^2, Voigt a = %.3g' % (sig0, avoigt))
    print('     A_V      N_H        tau_0      tau_a    (a tau_0)^1/3 tau_a')
    hit = None
    for dav in (0.002, 0.005, 0.01, 0.015, 0.02, 0.05, 0.1, 0.3):
        NH = dav / AV_PER_NH
        t0 = NH * sig0
        ta = NH * sig_a
        crit = (avoigt * t0) ** (1. / 3.) * ta
        print('     %6.3f  %9.3g  %9.3g  %9.4g  %14.2f' % (dav, NH, t0, ta, crit))
        if hit is None and crit >= 1.0:
            hit = dav
    print('     -> destroyed within about A_V %.3f of the front' % hit)

    # heating that implies, and whether the grid can see it
    NHdep = hit / AV_PER_NH
    perH = F / NHdep
    print('\n  heating if deposited over that column:')
    print('     %.3g erg s^-1 per H, total (nearly all of it into grains)' % perH)
    eff = 0.0145                        # measured conversion efficiency, D-290
    print('     %.3g erg s^-1 per H into the GAS at the measured %.1f%% efficiency'
          % (perH * eff, eff * 100))
    s = np.abs(r / PC - 0.20) < 0.012
    print('     against the model\'s photoelectric heating at r = 0.20 pc: %.3g'
          % np.median(d['PE'][s]))
    print('     i.e. a factor %.0f, in that layer only'
          % (perH * eff / np.median(d['PE'][s])))

    dav_cell = dcell * 1000 * AV_PER_NH
    print('\n  can this grid resolve it?')
    print('     cell %.4g cm = %.4f pc  ->  A_V %.4f per cell'
          % (dcell, dcell / PC, dav_cell))
    print('     deposition layer A_V %.3f  =  %.2f cells' % (hit, hit / dav_cell))


if __name__ == '__main__':
    main(sys.argv[1])
