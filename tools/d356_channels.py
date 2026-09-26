#!/usr/bin/env python3
"""D-356: which reactions make and destroy a species, cell by cell.

Reads output/pdrReacRates.out (written with `pdrDiagRates 2`): one row per
sampled cell with every reaction's volume rate [cm^-3 s^-1] on the solver's
own state, and both that state and the one MOCASSIN re-imposes after the
solve. Reactions are attributed to species with the network's stoichiometry
from dataPDR/rates_<network>.d, in the same order as the rates.

    ~/miniforge3/envs/astro/bin/python tools/d356_channels.py \\
        runs/d356-hiirates [species ...] [--state] [--top N]

--state prints the solver's and the imposed x(H), x(H+), x_e, x(O), x(O+),
x(He+) and the molecules side by side, per cell.
"""
import os
import re
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PSEUDO = {'PHOTON', 'CRP', 'CRPHOT', '#', ''}


def read_network(name='reduced'):
    reac = []
    for ln in open(os.path.join(ROOT, 'dataPDR', f'rates_{name}.d')):
        f = ln.rstrip('\n').split(',')
        if len(f) < 9 or not f[0].strip().isdigit():
            continue
        reac.append(([x.strip() for x in f[1:4]], [x.strip() for x in f[4:8]]))
    return reac


def read_rates(run):
    path = os.path.join(run, 'output', 'pdrReacRates.out')
    head = [l for l in open(path) if l.startswith('#')]
    it = int(head[0].split('iteration')[1].split()[0])
    species = head[2].split(':', 1)[1].split()
    # Fortran's Ew.d drops the E of a three-digit exponent (2.4456-104)
    fix = re.compile(r'(?<=\d)([+-]\d{3})(?=\s|$)')
    rows = np.array([[float(v) for v in fix.sub(r'E\1', l).split()]
                     for l in open(path) if not l.startswith('#') and l.strip()])
    ns = len(species)
    cells = []
    for r in rows:
        cells.append(dict(cell=int(r[0]), r=r[1], AV=r[2], nH=r[3], T=r[4], xe=r[5],
                          xs=dict(zip(species, r[6:6 + ns])),
                          xi=dict(zip(species, r[6 + ns:6 + 2 * ns])),
                          R=r[6 + 2 * ns:]))
    cells.sort(key=lambda c: c['AV'])
    return it, species, cells


def fix_labels(reac, species, cells):
    """D-258: species_reduced.d labels slot 3 H2+ and slot 5 CH5+, but the
    generated odes_reduced.c integrates slot 3 as CH5+ and slot 5 as H2+. The
    chemistry is right in the ODE's indices; only the labels are crossed. The
    Fortran diagnostic took each reactant's abundance by label, so a reaction
    with H2+ (CH5+) as a reactant was weighted with slot 3 (5). Swap the two
    labels back and rescale those reactions to the ODE's weighting."""
    a, b = 'H2+', 'CH5+'
    for c in cells:
        for key in ('xs', 'xi'):
            c[key][a], c[key][b] = c[key][b], c[key][a]
        for i, (rs, _) in enumerate(reac):
            f = 1.0
            # after the swap c['xs'][a] is the true H2+; the rate was weighted
            # with what is now c['xs'][b]
            for sp, other in ((a, b), (b, a)):
                for _ in range(rs.count(sp)):
                    # a zero in the slot it was weighted with leaves the
                    # coefficient unrecoverable; the rate is then unknown
                    f *= c['xs'][sp] / c['xs'][other] if c['xs'][other] > 0 else np.nan
            if f != 1.0:
                c['R'][i] *= f
        c['unknown'] = int(np.isnan(c['R']).sum())


def label(reac, i):
    rs, ps = reac[i]
    return ' + '.join(x for x in rs if x) + ' -> ' + ' + '.join(x for x in ps if x)


def channels(reac, R, sp):
    """(formation [(rate, i)], loss [(rate, i)]) for species sp."""
    form, loss = [], []
    for i, (rs, ps) in enumerate(reac):
        nu = ps.count(sp) - rs.count(sp)
        if np.isnan(R[i]):
            continue
        if nu > 0:
            form.append((nu * R[i], i))
        elif nu < 0:
            loss.append((-nu * R[i], i))
    return sorted(form, reverse=True), sorted(loss, reverse=True)


def main(argv):
    run = argv[0]
    top = 5
    if '--top' in argv:
        top = int(argv[argv.index('--top') + 1])
    want = [a for a in argv[1:] if not a.startswith('--') and not a.isdigit()] \
        or ['H2', 'H2+', 'H3+', 'CO', 'OH']
    reac = read_network()
    it, species, cells = read_rates(run)
    fix_labels(reac, species, cells)
    print(f'{run}: {len(cells)} sampled cells, MC iteration {it}, {len(reac)} reactions '
          '(H2+/CH5+ labels corrected, D-258)')
    if '--state' in argv:
        keys = ['H', 'H+', 'O', 'O+', 'He+', 'C+', 'H2', 'CO', 'OH', 'H3+', 'HCO+']
        print('\n   A_V    r[pc]     T     x_e solver/imposed  ' +
              '  '.join('%-17s' % (k + ' s/i') for k in keys))
        for c in cells:
            xi_e = c['xi'].get('e-', np.nan)
            print('%7.4f %7.3f %7.0f  %9.2e %9.2e  ' % (c['AV'], c['r'] / 3.0857e18, c['T'], c['xe'], xi_e)
                  + '  '.join('%8.1e %8.1e' % (c['xs'][k], c['xi'][k]) for k in keys))
    for sp in want:
        print(f'\n======== {sp}')
        for c in cells:
            f, l = channels(reac, c['R'], sp)
            F, L = sum(v for v, _ in f), sum(v for v, _ in l)
            n = c['xs'][sp] * c['nH']
            print('A_V %.4f  r %.3f pc  T %.0f  x_solver %.2e  x_imposed %.2e   form %.2e  loss %.2e  (form-loss)/form %+.1e'
                  % (c['AV'], c['r'] / 3.0857e18, c['T'], c['xs'][sp], c['xi'][sp], F, L,
                     (F - L) / F if F > 0 else np.nan))
            for tag, lst, tot in (('  +', f, F), ('  -', l, L)):
                for v, i in lst[:top]:
                    if tot > 0 and v / tot >= 0.01:
                        print('%s %5.1f%%  %.2e  %s' % (tag, 100 * v / tot, v, label(reac, i)))
            if n > 0 and L > 0:
                print('     lifetime %.2e s' % (n / L))


if __name__ == '__main__':
    main(sys.argv[1:])
