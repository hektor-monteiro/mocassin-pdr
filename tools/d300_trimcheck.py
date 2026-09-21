#!/usr/bin/env python3
"""D-300: does dropping the trace elements change the model?

The question is whether the 16 trace elements MOCASSIN carries at 1e-11 to
1e-6 - Li Be B F Na Al P K Sc Ti V Cr Mn Co Ni Cu Zn, on top of the Ca and Fe
already off - contribute enough cooling to matter. Answering it in MOCASSIN
costs hours; answering it in Cloudy costs seven minutes, on the same physical
model, so that is where it is answered.

Two Cloudy runs differing only in those `element ... off` lines:

  * T_e against A_V, which is what O-02 is about and what cooling sets;
  * the FUV field, since a changed temperature changes the dust and the
    ionization structure;
  * the total cooling rate, and the share the dropped species held in the
    baseline's own cooling breakdown.

    ~/miniforge3/envs/astro/bin/python tools/d300_trimcheck.py \\
        runs/d288-cloudy-grain/150k runs/d300-cloudy-trim/150k
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d287_pe as P

DROPPED = ('Li', 'Be', 'B ', 'F ', 'Na', 'Al', 'P ', 'K ', 'Sc', 'Ti',
           'V ', 'Cr', 'Mn', 'Co', 'Ni', 'Cu', 'Zn')


def cool_share(path):
    """Share of the cooling held by the dropped species, per zone.

    Each row is depth, Te, Htot, Ctot, Adve, then (label, fraction) pairs for
    the strongest coolants Cloudy chose to print. The labels carry the species
    in their first two characters.
    """
    dep, tot, share = [], [], []
    for ln in open(path):
        if ln.startswith('#'):
            continue
        f = ln.rstrip('\n').split('\t')
        if len(f) < 6:
            continue
        try:
            dep.append(float(f[0])); tot.append(float(f[3]))
        except ValueError:
            continue
        s = 0.0
        rest = [x for x in f[5:] if x.strip()]
        for i in range(0, len(rest) - 1, 2):
            lab = rest[i].strip()
            if lab[:2] in DROPPED:
                try:
                    s += float(rest[i + 1])
                except ValueError:
                    pass
        share.append(s)
    return np.array(dep), np.array(tot), np.array(share)


def main(base, trim):
    a = P.read_cloudy(base)
    b = P.read_cloudy(trim)
    dep, ctot, share = cool_share(base + '.cool')

    print('== Cloudy, all elements against the 17 dropped ==')
    print('   baseline %s' % base)
    print('   trimmed  %s' % trim)
    print()
    print('   share of the BASELINE cooling held by the dropped species:')
    print('      max %.4f %%   median %.4f %%   at the front %.4f %%'
          % (100 * share.max(), 100 * np.median(share),
             100 * share[len(share) // 2]))
    print()
    edges = np.linspace(0.0, 0.75, 16)
    print('   A_V        Te_all     Te_trim    dTe/Te     G0_all    G0_trim   dG0/G0')
    for lo, hi in zip(edges[:-1], edges[1:]):
        ma = (a['AV'] >= lo) & (a['AV'] < hi)
        mb = (b['AV'] >= lo) & (b['AV'] < hi)
        if ma.sum() < 2 or mb.sum() < 2:
            continue
        ta, tb = np.median(a['Tgas'][ma]), np.median(b['Tgas'][mb])
        ga, gb = np.median(a['G0'][ma]), np.median(b['G0'][mb])
        print('   %5.3f %10.1f %10.1f %9.3f%% %10.4g %10.4g %8.3f%%'
              % (0.5 * (lo + hi), ta, tb, 100 * (tb - ta) / ta,
                 ga, gb, 100 * (gb - ga) / ga))

    print()
    print('   worst |dTe/Te| over the PDR (A_V > front): ', end='')
    # front: where Te first drops below 1000 K
    fa = a['AV'][a['Tgas'] < 1000.]
    front = fa.min() if len(fa) else 0.0
    d = []
    for lo, hi in zip(edges[:-1], edges[1:]):
        if 0.5 * (lo + hi) < front:
            continue
        ma = (a['AV'] >= lo) & (a['AV'] < hi)
        mb = (b['AV'] >= lo) & (b['AV'] < hi)
        if ma.sum() < 2 or mb.sum() < 2:
            continue
        d.append(abs(np.median(b['Tgas'][mb]) / np.median(a['Tgas'][ma]) - 1))
    print('%.3f %%  (front at A_V %.3f)' % (100 * max(d) if d else 0.0, front))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
