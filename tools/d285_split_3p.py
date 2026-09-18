#!/usr/bin/env python3
"""D-285: split the 1D/1S -> 3P_J collision rates of the 3D-PDR coolant files
by the statistical weight of the lower level.

dataPDR/16o.dat and 12c.dat (as vendored from upstream 3D-PDR) give each of the
three rates u -> 3P_J (u = 1D2, 1S0) the same value, and that value is the
collision strength of the WHOLE 3P term:

  - O + e: the per-J Upsilon implied by 16o.dat is 0.293 at 1e4 K for 1D and
    0.0323 for 1S; the sources the file cites (Zatsarinny & Tayal 2003, in
    CHIANTI's o_1.splups) give term totals 0.295 and 0.0322, split 5:3:1.
  - C + e: 12c.dat's per-J 1D Upsilon is 1.141 at 1e4 K; the term total in
    Cloudy's c_1.coll (Mendoza 1983) is 1.149, split 1:3:5.

For an LS-coupled term the J-resolved collision strength is
Upsilon(3P_J, u) = Upsilon(3P, u) * g_J / g(3P), and the downward rate is
proportional to it, so each rate is multiplied by g_J/9. Excitation out of a
thermally populated 3P term is unchanged by the split; out of 3P2 alone - the
case in ionized gas, where 3P1 and 3P0 are sub-thermal - it falls by ~2 (D-284).

Only blocks whose u -> 3P_J rows are still identical are touched, so running
this twice changes nothing. The collider's comment line gets a D-285 note (the
reader takes only its first integer).

    ~/miniforge3/envs/astro/bin/python tools/d285_split_3p.py [dataPDR]
"""
import os
import sys

import numpy as np

# file -> (3P level indices, term upper levels)
FILES = {'16o.dat': ([1, 2, 3], [4, 5]), '12c.dat': ([1, 2, 3], [4, 5])}
NOTE = ' [D-285: u->3P_J rates split by g_J/9]'


def nxt(lines, tag, start):
    for k in range(start, len(lines)):
        if lines[k].startswith(tag):
            return k + 1
    raise ValueError(tag)


def main(root):
    for name, (p3, uppers) in FILES.items():
        path = os.path.join(root, name)
        L = open(path).read().split('\n')
        i0 = nxt(L, '!LEVEL', 0)
        nlev = int(L[nxt(L, '!NUMBER OF ENERGY LEVELS', 0)].split()[0])
        g = {int(L[i0 + k].split()[0]): float(L[i0 + k].split()[2])
             for k in range(nlev)}
        gsum = sum(g[j] for j in p3)
        changed = False
        for i, line in enumerate(L):
            if not line.startswith('!COLLISIONS BETWEEN'):
                continue
            ntr = int(L[nxt(L, '!NUMBER OF COLL TRANS', i)])
            k0 = nxt(L, '!TRANS + UP', i)
            rows = {}
            for k in range(k0, k0 + ntr):
                s = L[k].split()
                rows[(int(s[1]), int(s[2]))] = k
            hit = False
            for u in uppers:
                ks = [rows[(u, j)] for j in p3 if (u, j) in rows]
                if len(ks) != len(p3):
                    continue
                vals = [np.array(L[k].split()[3:], float) for k in ks]
                if not np.any(vals[0] > 0) or \
                   not all(np.array_equal(v, vals[0]) for v in vals):
                    continue
                for j, k in zip(p3, ks):
                    s = L[k].split()
                    new = np.array(s[3:], float) * g[j] / gsum
                    L[k] = '%5s %5s %5s  ' % tuple(s[:3]) + \
                        ''.join('%10.3E' % v for v in new)
                hit = True
                print(f'{name}: {L[i + 1].split("!")[0].strip()} '
                      f'upper {u} split by g_J/{gsum:g}')
            if hit and NOTE not in L[i + 1]:
                L[i + 1] = L[i + 1] + NOTE
            changed |= hit
        if changed:
            open(path, 'w').write('\n'.join(L))
        else:
            print(f'{name}: nothing to split')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'dataPDR')
