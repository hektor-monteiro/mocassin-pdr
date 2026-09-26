#!/usr/bin/env python3
"""D-348: is the MC's excess direct FUV at depth spectral hardening?

The [D348] table finds the MC's unscattered stellar FUV, chi_MC - chi_dif,
exceeding chi0 * exp(-R_FUV * tau_V) increasingly with depth (x4 at A_V 2.8),
identically at 600k and 6M photons, so it is not noise. The hypothesis: one
band-mean extinction applied to a band-INTEGRATED beam over-attenuates it,
because the least opaque frequencies survive (Jensen: <e^{-k tau}> >= e^{-<k> tau}).

Test, from files the run already writes: take the direct spectrum per bin in
one shell, D_nu = Jste - Jdif (pdrFUVspec.out), carry it to every deeper shell
with each bin's OWN extinction, q_nu = tau_nu/tau_V from tauNu.out, and
inverse-square dilution, and compare the band integral with the MC's - and
with the same carried on the single band-mean q. If the per-bin prediction
closes on the MC and the band-mean one does not, the excess is hardening.

    ~/miniforge3/envs/astro/bin/python tools/d348_hardening.py runs/d348-angular
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R


def main(run):
    out = os.path.join(run, 'output')
    sp = np.loadtxt(os.path.join(out, 'pdrFUVspec.out'), comments='#')
    shells = np.unique(sp[:, 0]).astype(int)
    nu = sp[sp[:, 0] == shells[0], 3]
    lam_um = sp[sp[:, 0] == shells[0], 4] * 1e-4
    D = np.array([sp[sp[:, 0] == s, 5] - sp[sp[:, 0] == s, 6] for s in shells])
    J = np.array([sp[sp[:, 0] == s, 5] for s in shells])

    # tauNu.out holds one block per direction; the first (1,0,0) is enough
    rows = []
    for ln in open(os.path.join(out, 'tauNu.out')).readlines()[3:]:
        f = ln.split()
        if len(f) != 2:
            break
        rows.append((float(f[0]), float(f[1])))
    tn = np.array(sorted(rows))
    tau_at = lambda l: np.exp(np.interp(np.log(l), np.log(tn[:, 0]),
                                        np.log(np.maximum(tn[:, 1], 1e-300))))
    q = tau_at(lam_um) / tau_at(0.55)

    # shell geometry, with the same binning writeFUVField uses
    d = R.read_run(run)
    r = d['r'] * R.PC
    rmin, rmax = r[r > 0].min(), r.max()
    ish = np.clip(1 + (8 * np.log(r / rmin) / np.log(rmax / rmin)).astype(int), 1, 8)
    rs = np.array([np.exp(np.log(r[ish == s]).mean()) for s in shells])
    tv = np.array([np.mean(d['AV'][ish == s]) for s in shells]) / 1.086

    print('D-348: spectral hardening of the direct FUV, %s' % run)
    print('  q = tau_nu/tau_V across the band: %.2f - %.2f (mean %.2f)'
          % (q.min(), q.max(), q.mean()))
    s0 = int(np.argmax(tv > 0.2 / 1.086))       # first shell past A_V 0.2
    w0 = D[s0] / D[s0].sum()
    qbar = (w0 * q).sum()                        # band mean on the reference spectrum
    print('  reference shell %d: A_V %.2f, band-mean q on its spectrum %.2f\n'
          % (shells[s0], tv[s0] * 1.086, qbar))
    print('  shell   A_V   D_MC/J_MC   D_MC      per-bin pred   band-mean pred'
          '   MC/per-bin  MC/band-mean')
    lw = (nu >= 0.821) & (nu <= 0.9992)
    print('  (Lyman-Werner window, 0.821-0.999 Ryd, is %d of %d bins)' % (lw.sum(), lw.size))
    for i in range(s0, len(shells)):
        dil = (rs[s0] / rs[i]) ** 2
        dt = tv[i] - tv[s0]
        pb = (D[s0] * dil * np.exp(-q * dt)).sum()
        pm = D[s0].sum() * dil * np.exp(-qbar * dt)
        dm = D[i].sum()
        print('  %4d  %5.2f   %8.4f  %10.3e   %10.3e     %10.3e     %8.3f   %8.3f'
              % (shells[i], tv[i] * 1.086, dm / J[i].sum(), dm, pb, pm,
                 dm / pb, dm / pm))


    # The chemistry is handed a band-integrated chi and assumes it has the
    # spectral shape its rate coefficients were computed for; H2, CO and C I
    # respond only to the Lyman-Werner window. How that window's share of the
    # field moves with depth, relative to the first shell, is by how much the
    # band integral over- (share falling) or under-states the LW-driven rates.
    print('\n  Lyman-Werner share of the field, relative to shell %d' % shells[0])
    print('  shell   A_V   LW/band (Jste)   LW/band (Jdif)')
    Jd = np.array([sp[sp[:, 0] == s, 6] for s in shells])
    f0 = J[0][lw].sum() / J[0].sum()
    g0 = Jd[0][lw].sum() / max(Jd[0].sum(), 1e-300)
    for i in range(len(shells)):
        f = J[i][lw].sum() / J[i].sum()
        g = Jd[i][lw].sum() / max(Jd[i].sum(), 1e-300)
        print('  %4d  %5.2f       %8.3f         %8.3f' % (shells[i], tv[i] * 1.086,
                                                         f / f0, g / g0 if g0 else np.nan))


if __name__ == '__main__':
    main(sys.argv[1])
