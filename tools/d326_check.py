#!/usr/bin/env python3
"""D-326: check the sticking fix against the prediction made before the run.

Written before `runs/d326-stick` finished, so the quantities compared are the
ones D-326 committed to, not ones chosen after seeing the answer.

The prediction, in one line: the temperature profile ROTATES about A_V ~ 1.3 -
cooler behind the front where MOCASSIN ran warm, warmer deep where it ran
cold - because doubling the effective charging parameter moves every depth to
the right along an efficiency-vs-psi curve that peaks near psi = 2e5.

Falsified by the whole profile moving one way, or by the ionization front,
H/H2 crossing, deep carbon or dust temperature moving.

    ~/miniforge3/envs/astro/bin/python tools/d326_check.py \\
        runs/d326-stick runs/d316-hiipdr runs/d322-cloudy-hb/hiipdr
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d304_budget as B
import d260_roellig as R

# D-332: these were hiipdr's depths, hardcoded - the L-21 disease in a tool
# written one day earlier. Derived from the model's own PDR unless given on
# the command line.
AVS = None
PC = 3.0857e18


def pdr_depths(m, n=5):
    av = m['AV'][m['zone'] == 1]
    return tuple(float(v) for v in
                 np.geomspace(np.percentile(av, 3), np.percentile(av, 97), n))


def prof(m, key, avs):
    pdr = m['zone'] == 1
    out = []
    for av in avs:
        w = max(0.02, 0.08 * av)
        s = pdr & (np.abs(m['AV'] - av) <= w)
        out.append(np.median(m[key][s]) if s.sum() else np.nan)
    return np.array(out)


def pe(m, avs):
    pdr = m['zone'] == 1
    out = []
    for av in avs:
        w = max(0.02, 0.08 * av)
        s = pdr & (np.abs(m['AV'] - av) <= w)
        out.append(np.median(m['heat'][s][:, 1]) if s.sum() else np.nan)
    return np.array(out)


def cross(x, y, t):
    x, y = np.asarray(x, float), np.asarray(y, float)
    ok = np.isfinite(x) & np.isfinite(y)
    x, y = x[ok], y[ok]
    sg = np.sign(y - t)
    for i in range(len(x) - 1):
        if sg[i] != sg[i + 1] and sg[i] != 0:
            return x[i] + (t - y[i]) / (y[i + 1] - y[i]) * (x[i + 1] - x[i])
    return np.nan


def main(new, old, prefix, avs=None):
    a, b = B.read_moc(new), B.read_moc(old)
    c = B.read_cloudy(prefix)
    global AVS
    AVS = avs or pdr_depths(a)
    print('sample depths: ' + ', '.join('%.2f' % v for v in AVS))
    Ta, Tb = prof(a, 'Tgas', AVS), prof(b, 'Tgas', AVS)
    Da, Db = prof(a, 'Tdust', AVS), prof(b, 'Tdust', AVS)
    Pa, Pb = pe(a, AVS), pe(b, AVS)
    Tc = np.array([c['Tgas'][np.argmin(abs(c['AV'] - v))] for v in AVS])
    Pc = np.array([c['gheat'][np.argmin(abs(c['AV'] - v))].sum() for v in AVS])

    print(f'new {new}\nold {old}\nref {prefix}\n')
    print('=== gas temperature, new against old and against the reference ===')
    print('  A_V |   T_old  T_new  Cloudy |  new/old |  old/Cl  new/Cl')
    print('  ' + '-' * 62)
    for i, av in enumerate(AVS):
        print('  %4.2f | %7.1f %6.1f %7.1f | %8.3f | %7.3f %7.3f'
              % (av, Tb[i], Ta[i], Tc[i], Ta[i] / Tb[i],
                 Tb[i] / Tc[i], Ta[i] / Tc[i]))
    n1 = max(1, len(AVS) // 2)
    warm, deep = Ta[:n1] / Tb[:n1], Ta[n1:] / Tb[n1:]
    print('\n  shallower half (A_V %.2f-%.2f)  new/old = %s'
          % (AVS[0], AVS[n1 - 1], ' '.join('%.3f' % v for v in warm)))
    print('  deeper half    (A_V %.2f-%.2f)  new/old = %s'
          % (AVS[n1], AVS[-1], ' '.join('%.3f' % v for v in deep)))
    # D-326 predicted a ROTATION for hiipdr. Report the shape, not a verdict
    # tied to one fixture's prediction.
    print('  shape: %s' % ('rotates - cooler shallow, warmer deep'
                           if np.nanmean(warm) < 1.0 < np.nanmean(deep) else
                           'shifts one way (%s)' %
                           ('cooler' if np.nanmean(np.concatenate([warm, deep]))
                            < 1 else 'warmer')))

    print('\n=== the term it acts on ===')
    print('  A_V |  PE_old    PE_new   new/old |  PE_new/PE_Cloudy')
    for i, av in enumerate(AVS):
        print('  %4.2f | %9.3e %9.3e %7.3f | %14.3f'
              % (av, Pb[i], Pa[i], Pa[i] / Pb[i], Pa[i] / Pc[i]))

    print('\n=== what must NOT move ===')
    for lab, va, vb in (
            ('dust T', Da, Db),):
        print('  %-8s new/old  %s' % (lab, ' '.join('%.3f' % v
                                                    for v in va / vb)))
    for m, tag in ((a, 'new'), (b, 'old')):
        nh = m['H'] + 2 * m['H2'] + m['H+']
        er = np.linspace(0, m['r'].max() * 1.001, 200)
        rc, xc = R.median_profile(m['r'], m['H+'] / nh, er)
        edges = np.concatenate([np.geomspace(0.0493, m['A_front'] * .999, 9),
                                np.geomspace(m['A_front'] * .999, 3.149, 32)[1:]])
        x1, h = R.median_profile(m['AV'], m['H'], edges)
        _, h2 = R.median_profile(m['AV'], m['H2'], edges)
        _, cp = R.median_profile(m['AV'], m['C+'], edges)
        _, cc = R.median_profile(m['AV'], m['C'], edges)
        print('  %-3s  front %.3f pc   H/H2 A_V %.3f   C+=C A_V %.3f'
              % (tag, cross(rc, xc, 0.5), cross(x1, 2 * h2 / h, 1.0),
                 cross(x1, cp / cc, 1.0)))
    print('\n  (D-314: this code is not bitwise reproducible. Read anything '
          'under\n   a few per cent as scatter, not as an effect.)')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3],
         tuple(float(v) for v in sys.argv[4:]) or None)
