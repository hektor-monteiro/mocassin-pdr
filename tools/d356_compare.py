#!/usr/bin/env python3
"""D-356: the leading formation and destruction channels of a species in
MOCASSIN's chemistry and in Cloudy's, side by side at matched depths.

MOCASSIN from output/pdrReacRates.out (pdrDiagRates 2, tools/d356_channels.py);
Cloudy from `save chemistry rates creation/destruction` files (volume rates,
k times the reactant densities, as mole_save writes them). Cells inside the
ionization front are matched in radius, cells beyond it in A_V, as the pages
match them.

    ~/miniforge3/envs/astro/bin/python tools/d356_compare.py \\
        runs/d356-hiirates runs/d356-cloudy-hii/hiipdr 3e18 H2 H3+ CO OH
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R                                   # noqa: E402
import d356_channels as C                                  # noqa: E402

PC = 3.0857e18
SUFFIX = {'H2': 'H2', 'H2+': 'H2p', 'H3+': 'H3p', 'CO': 'CO', 'OH': 'OH'}


def read_cloudy_rates(prefix, sp, kind):
    path = f'{prefix}.{SUFFIX[sp]}{kind}'
    if not os.path.exists(path):
        return None, None
    lines = open(path).read().splitlines()
    lab = lines[0].split('\t')[1:]
    rows = np.array([[float(v) for v in l.split('\t')] for l in lines[1:] if l.strip()])
    return lab, rows


def top(pairs, n):
    tot = sum(v for v, _ in pairs)
    out = []
    for v, name in sorted(pairs, reverse=True)[:n]:
        if tot > 0 and v / tot >= 0.02:
            out.append('%5.1f%% %s' % (100 * v / tot, name))
    return tot, out


def main(argv):
    run, cpre, rin = argv[0], argv[1], float(argv[2])
    want = argv[3:] or ['H2', 'H3+', 'CO', 'OH']
    n = 4
    reac = C.read_network()
    it, species, cells = C.read_rates(run)
    C.fix_labels(reac, species, cells)
    c = R.cloudy_as_run(cpre, rin)
    cr = rin + c['depth']
    d = R.read_run(run)
    af = float(np.atleast_1d(d['A_front'])[0])
    print(f'MOCASSIN {run} (iteration {it}) against Cloudy {cpre}; front A_V {af:.3f}')
    for sp in want:
        print(f'\n################ {sp}')
        crea = read_cloudy_rates(cpre, sp, 'cr')
        dest = read_cloudy_rates(cpre, sp, 'de')
        for cell in cells:
            ion = cell['AV'] < af
            if ion:
                j = np.argmin(abs(cr - cell['r']))
                how = 'radius'
            else:
                j = np.argmin(abs(c['AV'] - cell['AV']))
                how = 'A_V'
            f, l = C.channels(reac, cell['R'], sp)
            mf = [(v, C.label(reac, i)) for v, i in f]
            ml = [(v, C.label(reac, i)) for v, i in l]
            Fm, fm = top(mf, n)
            Lm, lm = top(ml, n)
            depth_c = c['depth'][j]
            out_c = []
            for (lab, rows), tag in ((crea, '+'), (dest, '-')):
                if lab is None:
                    out_c.append((np.nan, []))
                    continue
                k = np.argmin(abs(rows[:, 0] - depth_c))
                out_c.append(top(list(zip(rows[k, 1:], lab)), n))
            print('\n A_V %.3f  r %.2f pc  (%s-matched)   MOCASSIN T %.0f, x %.2e (solver) %.2e (imposed)'
                  '   |   Cloudy A_V %.3f, T %.0f, x %.2e'
                  % (cell['AV'], cell['r'] / PC, how, cell['T'], cell['xs'][sp], cell['xi'][sp],
                     c['AV'][j], c['Tgas'][j], c[sp][j] / (c['H'][j] + c['H+'][j] + 2 * c['H2'][j])
                     if sp in c else np.nan))
            print('   formation  MOCASSIN %.2e   Cloudy %.2e cm^-3 s^-1' % (Fm, out_c[0][0]))
            for a, b in zip(fm + [''] * n, out_c[0][1] + [''] * n):
                if a or b:
                    print('     %-44s | %s' % (a, b))
            print('   loss       MOCASSIN %.2e   Cloudy %.2e' % (Lm, out_c[1][0]))
            for a, b in zip(lm + [''] * n, out_c[1][1] + [''] * n):
                if a or b:
                    print('     %-44s | %s' % (a, b))


if __name__ == '__main__':
    main(sys.argv[1:])
