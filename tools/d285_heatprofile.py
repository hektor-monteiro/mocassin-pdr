#!/usr/bin/env python3
"""D-285: MOCASSIN's thermal budget against Cloudy's, depth by depth.

Reads output/thermBudget.out (mocBud slot 2 per H nucleus, then the
photoionization heating split by element) and Cloudy's `save heating` and
`save cooling` files, and prints heating and cooling per H nucleus in radial
shells, with each code's leading agents.

    ~/miniforge3/envs/astro/bin/python tools/d285_heatprofile.py \\
        runs/d285-pn150k runs/d284-fs-cloudy/150k [Rin_cm]
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R

PC = R.PC
TERMS = ['phot', 'PE', 'PDR', 'coll', 'rec', 'ff', 'gasDust', 'PDRcool',
         'H-C', 'Te']


def read_budget(run, nact, idx):
    a = np.loadtxt(os.path.join(run, 'output', 'thermBudget.out'),
                   comments='#')
    return a[:nact][idx, :10], a[:nact][idx, 10:]


def cloudy_table(prefix, ext):
    """depth, T, Htot, Ctot and the agent/fraction pairs of a .heat/.cool."""
    dep, tot, agents = [], [], []
    for ln in open(f'{prefix}.{ext}'):
        if ln.startswith('#'):
            continue
        s = ln.rstrip('\n').split('\t')
        dep.append(float(s[0]))
        tot.append(float(s[2 if ext == 'heat' else 3]))
        pairs = [x for x in s[5:] if x.strip()]
        agents.append([(pairs[i].strip(), float(pairs[i + 1]))
                       for i in range(0, len(pairs) - 1, 2)])
    return np.array(dep), np.array(tot), agents


def main(run, prefix, rin=1e16):
    d = R.read_run(run)
    g0 = open(os.path.join(run, 'output', 'grid0.out')).read().split()
    nx, ny, nz = int(g0[1]), int(g0[2]), int(g0[3])
    n = nx * ny * nz
    off = 7 + nx + ny + nz
    idx = np.where(np.array(g0[off:off + 3 * n:3], float) > 0)[0]
    bud, hel = read_budget(run, n, idx)
    nh = np.loadtxt(os.path.join(run, 'output', 'grid1.out'))[idx, 2]
    elem, _ = R.read_composition(run)
    Z = {'H': 1, 'He': 2, 'C': 6, 'N': 7, 'O': 8, 'Ne': 10, 'Mg': 12,
         'Al': 13, 'Si': 14, 'S': 16, 'Cl': 17, 'Ar': 18, 'Ca': 20, 'Fe': 26}
    r = d['r'] * PC

    dep, htot, hag = cloudy_table(prefix, 'heat')
    _, ctot, cag = cloudy_table(prefix, 'cool')
    nhc = 1e3   # Cloudy's constant hden for this model
    rc = rin + dep

    print('shell [pc]  T_m    T_c  | heat/H  MOC    Cloudy | MOCASSIN terms'
          ' (per H)                 | Cloudy heating agents')
    for lo, hi in [(0.10, 0.13), (0.13, 0.14), (0.14, 0.15), (0.15, 0.17),
                   (0.17, 0.20), (0.20, 0.25), (0.25, 0.32), (0.32, 0.42),
                   (0.42, 0.55), (0.55, 0.62)]:
        s = (r / PC >= lo) & (r / PC < hi)
        sc = (rc / PC >= lo) & (rc / PC < hi)
        if s.sum() < 3 or sc.sum() == 0:
            continue
        hm = np.median(bud[s, 0] + bud[s, 1] + bud[s, 2])
        hc = np.median(htot[sc]) / nhc
        top = ' '.join('%s %.2f' % (t, np.median(bud[s, i]) / max(hm, 1e-99))
                       for i, t in enumerate(TERMS[:3]))
        j = np.argmin(abs(rc / PC - 0.5 * (lo + hi)))
        cl = ' '.join('%s %.2f' % (a, f) for a, f in hag[j][:3])
        print('%.2f-%.2f %6.0f %6.0f | %.2e %.2e | %s | %s'
              % (lo, hi, np.median(d['Tgas'][s]), np.median(_t(sc, dep, prefix)),
                 hm, hc, top, cl))
        # which element carries MOCASSIN's photoionization heating
        share = np.median(hel[s], axis=0)
        o = np.argsort(share)[::-1][:3]
        names = {Z[e]: e for e in elem if e in Z}
        print('%22s photoion by element: %s' % ('', ' '.join(
            '%s %.2f' % (names.get(k + 1, k + 1), share[k] / max(share.sum(), 1e-99))
            for k in o)))


def _t(sc, dep, prefix):
    """Cloudy Te in the same shells, from the .heat second column."""
    T = np.array([float(l.split('\t')[1]) for l in open(f'{prefix}.heat')
                  if not l.startswith('#')])
    return T[sc]


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2],
         float(sys.argv[3]) if len(sys.argv) > 3 else 1e16)
