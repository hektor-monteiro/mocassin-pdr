#!/usr/bin/env python3
"""D-405 (L-49): the lines of two runs, the second over the first.

    cmplines.py <run a> <run b> [<threshold, in Hbeta; default 1e-4>]

Hbeta; every line of lineFlux.out's totals block above the threshold (the
recombination lines and the collisionally excited ones apart); the lines of
the chemistry's coolants (lineFluxMol.out); the H2 lines of the level model
(lineFluxH2.out) where the run has them.
"""
import os
import re
import sys

import numpy as np

ELN = {2: 'He', 6: 'C', 7: 'N', 8: 'O', 10: 'Ne', 12: 'Mg', 14: 'Si', 16: 'S', 17: 'Cl', 18: 'Ar'}
ROM = {1: 'I', 2: 'II', 3: 'III', 4: 'IV', 5: 'V', 6: 'VI'}


def totals(run):
    return open(os.path.join(run, 'output', 'lineFlux.out')).read().split('Component:')[0]


def hbeta(run):
    for l in totals(run).splitlines():
        if 'Hbeta [E36 erg/s]' in l:
            return float(l.split()[-1])


def forb(run):
    d = {}
    for l in totals(run).split('Heavy ions forbidden lines')[1].splitlines():
        q = l.split()
        if len(q) == 7:
            d[(int(q[0]), int(q[1]), int(q[2]), int(q[3]))] = (float(q[4]), float(q[5]))
    return d


def recomb(run):
    """the lines listed before the collisionally excited block: {(label, wavelength, occurrence): L/Hbeta}"""
    d, ion, seen = {}, '', {}
    for l in totals(run).split('Heavy ions forbidden lines')[0].splitlines():
        t = l.split()
        if len(t) == 1 and not re.match(r'^[-+0-9.Ee]+$', t[0]):
            ion = t[0]
        elif len(t) == 2:
            try:
                w, v = float(t[0]), float(t[1])
            except ValueError:
                continue
            k = (ion, w)
            seen[k] = seen.get(k, 0) + 1
            d[(ion, w, seen[k])] = v
    return d


def mol(run):
    d = {}
    f = os.path.join(run, 'output', 'lineFluxMol.out')
    if not os.path.exists(f):
        return d
    for l in open(f):
        if l.startswith('#'):
            continue
        t = l.split()
        if len(t) >= 7:
            d[(t[0], int(t[1]), int(t[2]))] = (float(t[3]), float(t[-1]))
    return d


def h2(run):
    d = {}
    f = os.path.join(run, 'output', 'lineFluxH2.out')
    if not os.path.exists(f):
        return d
    for l in open(f):
        if l.startswith('#'):
            continue
        t = l.split()
        if len(t) >= 9:
            d[' '.join(t[:-8]) if len(t) > 9 else t[0]] = (float(t[-4]), float(t[-1]))
    return d


NAMED = ('1- 0 S( 1)', '2- 1 S( 1)', '0- 0 S( 0)', '0- 0 S( 1)', '0- 0 S( 2)', '0- 0 S( 3)')


def sets(a, b):
    """the two runs' lines as lists of (label, a, b) by kind"""
    ra, rb = recomb(a), recomb(b)
    fa, fb = forb(a), forb(b)
    ma, mb = mol(a), mol(b)
    xa, xb = h2(a), h2(b)
    out = {'recomb': [('%s %.2f' % (k[0], k[1]), ra[k], rb[k]) for k in ra if k in rb],
           'forb': [('[%s %s] %.2f' % (ELN.get(k[0], k[0]), ROM.get(k[1], k[1]), fa[k][0]), fa[k][1], fb[k][1]) for k in fa if k in fb],
           'h2': [(k, xa[k][1], xb[k][1]) for k in xa if k in xb]}
    for c in sorted({k[0] for k in ma}):
        out['mol ' + c] = [('%d-%d %.2f um' % (k[1], k[2], ma[k][0]), ma[k][1], mb[k][1]) for k in ma if k in mb and k[0] == c]
    return out


def summary(rows, lim):
    """counts above lim in run a and the changes, largest first"""
    r = [(lab, a, b, b / a) for lab, a, b in rows if a > lim and b > 0]
    if not r:
        return None
    ch = sorted(r, key=lambda x: -abs(np.log(x[3])))
    ab = [abs(np.log(x[3])) for x in r]
    return {'n': len(r), 'gt1': sum(1 for x in ab if x > np.log(1.01)), 'gt5': sum(1 for x in ab if x > np.log(1.05)),
            'gt20': sum(1 for x in ab if x > np.log(1.20)), 'med': float(np.exp(np.median(ab)) - 1), 'top': ch, 'all': {x[0]: x[3] for x in r}}


def stat(name, rows, lim, show=12, always=()):
    s = summary(rows, lim)
    if s is None:
        return
    print('\n%s: %d lines above %.0e Hbeta; moved by more than 1%%: %d, 5%%: %d, 20%%: %d; median |change| %.2f%%' % (
        name, s['n'], lim, s['gt1'], s['gt5'], s['gt20'], 100 * s['med']))
    for lab, a, b, x in s['top'][:show]:
        print('    %-26s %11.4e -> %11.4e  %+7.2f%%' % (lab, a, b, 100 * (x - 1)))
    for lab, a, b, x in s['top'][show:]:
        if lab in always:
            print('    %-26s %11.4e -> %11.4e  %+7.2f%%   (named)' % (lab, a, b, 100 * (x - 1)))


if __name__ == '__main__':
    a, b = sys.argv[1], sys.argv[2]
    lim = float(sys.argv[3]) if len(sys.argv) > 3 else 1e-4
    ha, hb = hbeta(a), hbeta(b)
    print('a %s\nb %s' % (a, b))
    print('Hbeta [E36 erg/s]: %.6f -> %.6f  %+.3f%%' % (ha, hb, 100 * (hb / ha - 1)))
    S = sets(a, b)
    stat('recombination lines', S['recomb'], lim, show=6)
    stat('collisionally excited lines', S['forb'], lim, show=14)
    for k in S:
        if k.startswith('mol '):
            stat('coolant %s' % k[4:], S[k], 1e-9, show=8)
    if S['h2']:
        stat('H2 lines (level model)', S['h2'], 1e-7, show=6, always=NAMED)
