#!/usr/bin/env python3
"""D-405 (L-49): the model-integrated quantities of two runs, iteration by iteration.

    cvdamp.py <damped run> <undamped run> [<first iteration, default 4>]

From output/convergence.out (D-391): the emission measure of each ion, the
contents of H0, H2 and CO and three weighted temperatures, as the stop test
reads them. Prints the second run over the first at each iteration, each
run's change from the iteration before, and for the hydrogen emission measure
the iteration of the second run that the first run's last value falls at.
"""
import sys

import numpy as np

SHOW = ('H+', 'He+', 'C+', 'C2+', 'N+', 'N2+', 'O+', 'O2+', 'Ne+', 'Ne2+', 'S+', 'S2+', 'Mg+', 'n(H0)', 'n(H2)', 'n(CO)',
        'T(em)', 'T(H0)', 'T(H2)')


def rd(run):
    L = open(run.rstrip('/') + '/output/convergence.out').read().split('\n')
    return L[1].lstrip('#').split(), np.array([l.split() for l in L[2:] if l.strip()], float)


na, A = rd(sys.argv[1])
nb, B = rd(sys.argv[2])
i0 = int(sys.argv[3]) if len(sys.argv) > 3 else 4
assert na == nb
show = [s for s in SHOW if s in na and A[-1, na.index(s)] > 0 and B[-1, na.index(s)] > 0]
n = min(len(A), len(B))
pc = lambda x, y: '%+7.2f' % (100 * (y / x - 1)) if x > 0 and y > 0 else '      -'     # noqa: E731
print('second / first - 1 [%], by iteration')
print('  it ' + ' '.join('%7s' % s for s in show))
for i in range(i0 - 1, n):
    print('  %2d ' % (i + 1) + ' '.join(pc(A[i, na.index(s)], B[i, na.index(s)]) for s in show))
for lab, X in (('first', A), ('second', B)):
    print('\n%s run: change from the iteration before [%%]' % lab)
    print('  it ' + ' '.join('%7s' % s for s in show))
    for i in range(max(i0, 1), len(X)):
        print('  %2d ' % (i + 1) + ' '.join(pc(X[i - 1, na.index(s)], X[i, na.index(s)]) for s in show))
j = na.index('H+')
a, b = A[-1, j], B[:, j]
k = [i for i in range(len(b) - 1) if (b[i] - a) * (b[i + 1] - a) <= 0 and b[i] != b[i + 1]]
if k:
    i = k[-1]
    print('\nEM(H+): the first run ends (iteration %d) where the second was at iteration %.1f' % (len(A), i + 1 + (b[i] - a) / (b[i] - b[i + 1])))
for lab, X in (('first', A), ('second', B)):
    s = X[-4:, j] / X[-5:-1, j] - 1
    q = float(np.mean(s[1:] / s[:-1]))
    print('EM(H+), %s run: last steps %s %%, ratio of successive steps %.2f, geometric remainder %+.2f%%' % (
        lab, ' '.join('%+.2f' % (100 * x) for x in s), q, 100 * s[-1] * q / (1 - q) if 0 < q < 1 else float('nan')))
