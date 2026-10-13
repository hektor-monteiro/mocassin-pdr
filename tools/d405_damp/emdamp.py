#!/usr/bin/env python3
"""D-405 (L-49): what the last solve emits against what the written model emits.

    emdamp.py <damped run> <undamped run>

The chemistry stores each coolant transition's emission per cell from the
level populations of its own solve (pdrLineEm.out, D-362): that is the
emission of the last solve, at the temperature and abundances it had, in
either arm. lineFlux.out's [C I], [C II] and [O I] lines are MOCASSIN's own
atoms on the model as written (D-363). Where the written model is the solve
the two agree; where it is a blend of two iterations they need not.

Error bars need no second run: the octant has six wedges that are the same
model (i<j<k and its permutations), so the scatter of a sum over the six is
the Monte Carlo noise of a wedge, and sqrt(6) of it that of the whole.
"""
import itertools
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cmplines import forb, hbeta, mol                       # noqa: E402

# pdrLineEm.out's transitions: the coolants in the order of the input's pdrCoolants (12co, 12c+, 12c, 16o), each
# with its radiative transitions upper level outer, lower inner. Checked against lineFluxMol.out below.
SEL = (('CO 2-1', 0, None), ('CO 3-2', 1, None), ('CO 4-3', 2, None), ('CO 5-4', 3, None), ('CO 6-5', 4, None),
       ('[C II] 158', 40, (6, 2, 1, 2)), ('[C I] 609', 49, (6, 1, 1, 2)), ('[C I] 370', 51, (6, 1, 2, 3)),
       ('[O I] 63', 56, (8, 1, 1, 2)), ('[O I] 145', 58, (8, 1, 2, 3)))


def load(run):
    out = os.path.join(run, 'output')
    t = open(os.path.join(out, 'grid0.out')).read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    ax = [np.array(t[7:7 + nx], float), np.array(t[7 + nx:7 + nx + ny], float), np.array(t[7 + nx + ny:7 + nx + ny + nz], float)]

    def w(a):
        b = np.empty(len(a) + 1)
        b[1:-1] = 0.5 * (a[1:] + a[:-1])
        b[0], b[-1] = a[0], a[-1]
        return np.diff(b)
    V = (w(ax[0])[:, None, None] * w(ax[1])[None, :, None] * w(ax[2])[None, None, :]).ravel()
    n = nx * ny * nz
    L = open(os.path.join(out, 'pdrLineEm.out')).read().split('\n')
    em = np.array([l.split() for l in L[1:1 + 2 * n:2]], float)
    assert em.shape[1] == 63, 'the transition list above is for 12co, 12c+, 12c, 16o'
    idx = np.arange(n)
    c = np.stack([idx // (ny * nz), (idx // nz) % ny, idx % nz], axis=1)
    W = np.zeros((6, n))                                     # each cell's share in each of the six wedges
    for p, perm in enumerate(itertools.permutations(range(3))):
        W[p] = (c[:, perm[0]] <= c[:, perm[1]]) & (c[:, perm[1]] <= c[:, perm[2]])
    W /= W.sum(axis=0)
    return {'em': em, 'V': V, 'W': W, 'forb': forb(run), 'hb': hbeta(run) * 1e36, 'mol': mol(run)}


def sums(d, j):
    s = d['W'] @ (d['em'][:, j] * d['V'])
    return s.sum(), np.sqrt(6) * s.std(ddof=1), s


a, b = sys.argv[1], sys.argv[2]
A, B = load(a), load(b)
print('damped   %s\nundamped %s' % (a, b))
f = A['mol'][('12co.dat', 2, 1)][1] * A['hb'] / sums(A, 0)[0]
print('grid sum to luminosity (CO 2-1 of lineFluxMol.out over the octant\'s sum): %.4f' % f)
print('\n%-11s %12s %6s %12s %6s  %16s   %s' % ('', 'solve, d', '+-%', 'solve, u', '+-%', 'u / d - 1 [%]', 'written / solve: damped, undamped'))
for name, j, key in SEL:
    sa, ea, wa = sums(A, j)
    sb, eb, wb = sums(B, j)
    r = wb / wa
    line = '%-11s %12.4e %6.2f %12.4e %6.2f  %+7.2f +- %5.2f' % (name, f * sa, 100 * ea / sa, f * sb, 100 * eb / sb,
                                                            100 * (sb / sa - 1), 100 * r.std(ddof=1) / np.sqrt(6))
    if key is not None:
        la, lb = A['forb'][key][1] * A['hb'], B['forb'][key][1] * B['hb']
        line += '   %6.3f  %6.3f   (written u / d - 1: %+6.2f%%)' % (la / (f * sa), lb / (f * sb), 100 * (lb / la - 1))
    print(line)
