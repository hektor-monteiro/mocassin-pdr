#!/usr/bin/env python3
"""D-325: the photoelectric efficiency against the charging parameter.

D-324 left the gas-temperature crossover as "the grain charge balance" without
saying what in it. The parametrisation every treatment uses - including the
Weingartner & Draine form vendored in `source/pdr/heatingfunctions.F90` - is

    psi = G0 sqrt(T) / x(e)

because that is the ratio of the photoemission rate to the electron collection
rate, and it is what sets the equilibrium charge. Comparing the two codes'
photoelectric efficiency PE/G0 *at matched psi* separates the photoelectric
physics from the field, temperature and ionisation that feed it.

Electron sticking enters the collection rate linearly, so a code that sticks
every electron charges its grains less at the same nominal psi. MOCASSIN's
`getGrainRecombination` hardcodes `S = 1.` for electrons and for ions; Cloudy
uses STICK_ELEC = 0.5*(1-exp(-a/l_esc)) and STICK_ION = 1.0 (grains.cpp). The
`--stick` option divides psi by each code's own value so the comparison is
like for like; the collapse of the two curves is the test.

    ~/miniforge3/envs/astro/bin/python tools/d325_psi.py \\
        runs/d316-hiipdr runs/d322-cloudy-hb/hiipdr

This is a SCALING argument, not a derivation: psi is a similarity variable and
dividing it by S is the leading-order way sticking enters, no more. Read the
flatness of the ratio, not its absolute value.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d304_budget as B
from d287_pe import rows

S_MOC = 1.0      # update_mod.f90 getGrainRecombination, hardcoded
S_CLD = 0.5      # cloudy grains.cpp STICK_ELEC (its size factor is ~1 here)


def gather(run, prefix, avs):
    m = B.read_moc(run)
    c = B.read_cloudy(prefix)
    pdr = m['zone'] == 1
    oh = open(f'{prefix}.ovr').readline().lstrip('#').rstrip().split('\t')
    ovr = rows(f'{prefix}.ovr', len(oh))
    ne_c = ovr[:len(c['AV']), oh.index('eden')]
    M, C = [], []
    for av in avs:
        w = max(0.02, 0.08 * av)
        s = pdr & (np.abs(m['AV'] - av) <= w)
        M.append((np.median(m['G0'][s]), np.median(m['Tgas'][s]),
                  np.median(m['e-'][s] / m['nh'][s]),
                  np.median(m['heat'][s][:, 1])))
        j = np.argmin(abs(c['AV'] - av))
        C.append((c['G0'][j], c['Tgas'][j], ne_c[j] / c['nh'][j],
                  c['gheat'][j].sum()))
    return np.array(M), np.array(C)


def ratio_at_matched_psi(M, C, sm, sc):
    pm = M[:, 0] * np.sqrt(M[:, 1]) / (sm * M[:, 2])
    pc = C[:, 0] * np.sqrt(C[:, 1]) / (sc * C[:, 2])
    em, ec = M[:, 3] / M[:, 0], C[:, 3] / C[:, 0]
    lp, le = np.log(pc[::-1]), np.log(ec[::-1])
    return np.array([em[i] / np.exp(np.interp(np.log(pm[i]), lp, le))
                     for i in range(len(pm))]), pm, pc, em, ec


def main(run, prefix, avs):
    M, C = gather(run, prefix, avs)
    print(f'MOCASSIN {run}\nCloudy   {prefix}\n')
    print('  A_V |      psi_m    PE/G0 _m |      psi_c    PE/G0 _c')
    print('  ' + '-' * 58)
    _, pm, pc, em, ec = ratio_at_matched_psi(M, C, 1.0, 1.0)
    for i, av in enumerate(avs):
        print('  %4.2f | %10.3e %11.4e | %10.3e %11.4e'
              % (av, pm[i], em[i], pc[i], ec[i]))
    print('\n  both efficiencies are PEAKED in psi; the peak is where the grain'
          '\n  has discharged enough to lift the Coulomb barrier but the field'
          '\n  has not yet gone. Which side of it a code sits on is the sign of'
          '\n  its disagreement.')
    print('\n  psi falls across this range by:  MOCASSIN %.0fx   Cloudy %.0fx'
          % (pm[0] / pm[-1], pc[0] / pc[-1]))

    print('\n=== efficiency ratio at MATCHED psi ===')
    print('  A_V                           ' +
          ' '.join('%6.2f' % a for a in avs))
    for sm, sc, lab in ((1.0, 1.0, 'S equal (nominal psi)'),
                        (S_MOC, S_CLD, "each code's own S (%.1f vs %.1f)"
                         % (S_MOC, S_CLD))):
        r, *_ = ratio_at_matched_psi(M, C, sm, sc)
        print('  %-28s ' % lab + ' '.join('%6.3f' % v for v in r)
              + '   spread %.2f' % (np.nanmax(r) / np.nanmin(r)))
    print("""
If the two codes differed only by their electron sticking convention, the
second row would be flat at 1.000. How flat it is, is the measurement.""")


if __name__ == '__main__':
    a = [float(v) for v in sys.argv[3:]]
    main(sys.argv[1], sys.argv[2], a or (0.73, 0.97, 1.27, 1.68, 2.21))
