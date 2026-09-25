#!/usr/bin/env python3
"""D-345: is the diffuse FUV Lyman-alpha, or spread across the band?

Written and committed BEFORE runs/d345-fuvspec finished, so the quantities
compared are the ones committed to.

D-344 measured the diffuse FRACTION of the FUV band - 0.35 just inside the
front rising to 1.00 at the far edge - but not its colour. Colour is what
decides whether it matters. The code integrates 0.4537-0.9997 Ryd and hands one
number to every photoreaction, but H2 and CO dissociate and C ionizes only in
the Lyman-Werner window, 0.8210-0.9992 Ryd. Lyman alpha sits at 0.7496 Ryd:
inside the band the code integrates, below the window the molecules care about.

CORRECTED 2026-09-25, BEFORE ANY RESULT EXISTED. The user asked whether this
had been investigated before. It had, and the original prediction below was
already refuted when it was written:

  D-287, D-291 and D-293 established that MOCASSIN has NO Lyman alpha in its
  diffuse field, and not by accident. linePDF and totalLines are built from
  ilow >= 2 for H and He II (emission_mod.f90:560/575, hydro_mod.f90:693/711,
  and the note at common_mod.f90:142), so the Lyman series is excluded by
  construction. D-291 measured the 46% Lya share in CLOUDY's PDR field and
  diagnosed it as an artifact of Cloudy's continuum-only line attenuation;
  D-293 sized MOCASSIN's own Lya deposition and found it lands within A_V 0.020
  of the front, about 1.17 cells on this grid, and cannot reach the deep PDR
  either way. So "is MOCASSIN's diffuse FUV Lya-dominated" was answered NO
  three weeks before this file was written, and I failed to check.

  What survives is the same signature with a different carrier. The optically
  thin diffuse lines MOCASSIN DOES transport all sit RED of the window:
  C III] 1909 at 0.477 Ryd, He II 1640 at 0.556, C IV 1549 at 0.588,
  C II 1335 at 0.683 - against a Lyman-Werner window of 0.821-0.999 Ryd. So a
  line-dominated diffuse field still gives f_LW << f_band, while a
  dust-scattered continuum would be spread across the band and may even be
  BLUER than the stellar spectrum, since the scattering cross section rises
  toward short wavelengths.

  The test below is unchanged and still decides D-344's design question. Only
  the carrier named in the conclusion changes.

THE ORIGINAL PREDICTION, kept because it was wrong and the reason is the point:

  If the diffuse excess is Lyman-alpha, then f_LW << f_band - the diffuse
  fraction inside the Lyman-Werner window is much smaller than the diffuse
  fraction of the whole band - and the Lya bin carries a large share of the
  diffuse total. The single band-integrated chi is then inflated for exactly
  the reactions it drives, by a component that cannot drive them, and the fix
  is spectral: use the Lyman-Werner sub-band for the molecular rates.

  Falsified if f_LW ~ f_band, i.e. Jdif/Jste is flat across the band. Then the
  band integral is honest, the angular model stands as the next item, and it
  needs per-packet absorption history rather than twelve rays (D-344).

No prediction is made about which way a third possibility falls - a diffuse
excess concentrated at the BLUE end, inside the window - which would mean the
molecular rates are driven mostly by scattered light and the angular treatment
matters more than the band integral, not less.

    ~/miniforge3/envs/astro/bin/python tools/d345_fuvspec.py runs/d345-fuvspec
"""
import sys

import numpy as np

LW_LO, LW_HI = 0.8210, 0.9992      # Lyman-Werner window [Ryd]
LYA = 0.7496                       # Lyman alpha [Ryd]


def read(path):
    rows = []
    for ln in open(path):
        if ln.lstrip().startswith('#'):
            continue
        t = ln.split()
        if len(t) != 7:
            continue
        rows.append([float(x) for x in t])
    if not rows:
        raise SystemExit('no data rows in %s' % path)
    a = np.array(rows)
    return a


def main(run):
    a = read('%s/output/pdrFUVspec.out' % run)
    sh, cnt, nu, ste, dif = a[:, 0], a[:, 1], a[:, 3], a[:, 5], a[:, 6]
    print('D-345: colour of the diffuse FUV   %s\n' % run)

    print('  shell  cells |  f_band   f_LW   f_LW/f_band | Lya bin share of diffuse')
    print('  ' + '-' * 72)
    for s in np.unique(sh):
        m = sh == s
        lw = m & (nu >= LW_LO) & (nu <= LW_HI)
        tb, td = ste[m].sum(), dif[m].sum()
        lb, ld = ste[lw].sum(), dif[lw].sum()
        fb = td / tb if tb > 0 else np.nan
        fl = ld / lb if lb > 0 else np.nan
        # the bin nearest Lya, and its share of this shell's diffuse total
        j = np.argmin(np.abs(nu[m] - LYA))
        share = dif[m][j] / td if td > 0 else np.nan
        print('  %5d %6.0f | %7.4f %6.4f  %11.4f | %8.4f'
              % (s, cnt[m][0], fb, fl, fl / fb if fb else np.nan, share))

    print('\n=== where the diffuse light sits in the band (outermost shell) ===')
    s = np.unique(sh)[-1]
    m = sh == s
    nu_s, ste_s, dif_s = nu[m], ste[m], dif[m]
    o = np.argsort(nu_s)
    print('   nu[Ryd]  lambda[A]   Jdif/Jste   in LW window?')
    for i in o[::max(1, len(o) // 14)]:
        r = dif_s[i] / ste_s[i] if ste_s[i] > 0 else np.nan
        tag = 'LW' if LW_LO <= nu_s[i] <= LW_HI else ('<- Lya' if abs(nu_s[i] - LYA) < 0.01 else '')
        print('  %8.4f %9.1f %11.4f   %s'
              % (nu_s[i], 911.7535 / nu_s[i], r, tag))

    print('\n=== verdict against the pre-registered prediction ===')
    m = sh == s
    lw = m & (nu >= LW_LO) & (nu <= LW_HI)
    fb = dif[m].sum() / ste[m].sum()
    fl = dif[lw].sum() / ste[lw].sum()
    if fl < 0.6 * fb:
        print('  f_LW = %.4f is well below f_band = %.4f' % (fl, fb))
        print('  -> the diffuse excess is RED of the window. The band integral')
        print('     overstates what drives the molecules; the fix is spectral.')
        print('     Carrier is NOT Lya (excluded by construction, D-291) - the')
        print('     candidates are the thin diffuse lines, all red of the window:')
        print('     C III] 0.477, He II 0.556, C IV 0.588, C II 0.683 Ryd.')
    elif fl > 1.4 * fb:
        print('  f_LW = %.4f exceeds f_band = %.4f' % (fl, fb))
        print('  -> the diffuse excess is INSIDE the window. The molecular rates')
        print('     are driven by scattered light and the angular model matters')
        print('     MORE, not less. Neither branch of the prediction.')
    else:
        print('  f_LW = %.4f ~ f_band = %.4f' % (fl, fb))
        print('  -> flat across the band. Prediction refuted: the band integral')
        print('     is honest and the angular model is the next item (D-344).')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'runs/d345-fuvspec')
