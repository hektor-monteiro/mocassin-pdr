#!/usr/bin/env python3
"""D-405 (L-49): the model-integrated quantities of two runs, iteration by iteration.

    cvdamp.py <damped run> <undamped run> [<first iteration, default 4>]

From output/convergence.out (D-391): the emission measure of each ion, the
contents of H0, H2 and CO and three weighted temperatures, as the stop test
reads them. Prints the second run over the first at each iteration, each
run's change from the iteration before, and for the hydrogen emission measure
the iteration of the second run that the first run's last value falls at.

Then, for each run, what its T(H0) is made of: the temperature weighted by
neutral hydrogen, sum n(H0) T V / sum n(H0) V, rebuilt from the cells of the
written model (it must give convergence.out's last value), with the share of
the sum that each range of cell temperature holds; and when the test settles:
the standard deviation of a quantity's last values, and what the test's
difference of two values three iterations apart then scatters by.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

SHOW = ('H+', 'He+', 'C+', 'C2+', 'N+', 'N2+', 'O+', 'O2+', 'Ne+', 'Ne2+', 'S+', 'S2+', 'Mg+', 'n(H0)', 'n(H2)', 'n(CO)',
        'T(em)', 'T(H0)', 'T(H2)')


def rd(run):
    L = open(run.rstrip('/') + '/output/convergence.out').read().split('\n')
    return L[1].lstrip('#').split(), np.array([l.split() for l in L[2:] if l.strip()], float)


def lag(A, B, na):
    """the iteration of the second run at which the first run's last EM(H+) falls; each run's last steps, their ratio and
    the remainder of the geometric series"""
    j = na.index('H+')
    a, b = A[-1, j], B[:, j]
    k = [i for i in range(len(b) - 1) if (b[i] - a) * (b[i + 1] - a) <= 0 and b[i] != b[i + 1]]
    at = (k[-1] + 1 + (b[k[-1]] - a) / (b[k[-1]] - b[k[-1] + 1])) if k else float('nan')
    out = {'at': float(at), 'runs': []}
    for X in (A, B):
        s = X[-4:, j] / X[-5:-1, j] - 1
        q = float(np.mean(s[1:] / s[:-1]))
        out['runs'].append({'steps': [float(x) for x in s], 'q': q, 'rem': float(s[-1] * q / (1 - q)) if 0 < q < 1 else float('nan')})
    return out


def th0(run, cuts=(100., 300., 1000., 3000.)):
    """T(H0) from the cells of the written model, and the shares of its sum by the cells' temperature"""
    import d260_roellig as R
    run = run.rstrip('/')
    t = open(os.path.join(run, 'output', 'grid0.out')).read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    ax = [np.array(t[7:7 + nx], float), np.array(t[7 + nx:7 + nx + ny], float), np.array(t[7 + nx + ny:7 + nx + ny + nz], float)]

    def w(a):
        b = np.empty(len(a) + 1)
        b[1:-1] = 0.5 * (a[1:] + a[:-1])
        b[0], b[-1] = a[0], a[-1]
        return np.diff(b)
    V = (w(ax[0])[:, None, None] * w(ax[1])[None, :, None] * w(ax[2])[None, None, :]).ravel()
    n = nx * ny * nz
    off = 7 + nx + ny + nz
    act = np.array(t[off:off + n * 3:3], float).astype(int) > 0
    d = R.read_run(run)
    assert len(d['Tgas']) == act.sum()
    T, wgt = d['Tgas'], d['H'] * V[act]
    s = wgt * T
    e = (0.,) + tuple(cuts) + (np.inf,)
    names, X = rd(run)
    return {'T': float(s.sum() / wgt.sum()), 'conv': float(X[-1, names.index('T(H0)')]),
            'shares': [{'lo': e[i], 'hi': e[i + 1], 'cells': int(((T >= e[i]) & (T < e[i + 1])).sum()),
                        'share': float(s[(T >= e[i]) & (T < e[i + 1])].sum() / s.sum())} for i in range(len(e) - 1)],
            'top10': float(np.sort(s)[-10:].sum() / s.sum())}


def floor(run, name='T(H0)', last=7, lim=2.):
    """the scatter of a quantity's last values, the scatter the test's three-iteration difference then has (sqrt 2 of
    it, for independent values), and the test's values over those iterations"""
    names, X = rd(run)
    j = names.index(name)
    v = X[-last:, j]
    sd = float(np.std(v, ddof=1) / np.mean(v))
    test = [float(abs(X[i, j] / X[i - 3, j] - 1)) for i in range(len(X) - last, len(X))]
    return {'name': name, 'sd': sd, 'diff': float(np.sqrt(2.) * sd), 'lim_over': float(lim / 100. / (np.sqrt(2.) * sd)), 'test': test}


if __name__ == '__main__':
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
    g = lag(A, B, na)
    print('\nEM(H+): the first run ends (iteration %d) where the second was at iteration %.1f' % (len(A), g['at']))
    for lab, r in zip(('first', 'second'), g['runs']):
        print('EM(H+), %s run: last steps %s %%, ratio of successive steps %.2f, geometric remainder %+.2f%%' % (
            lab, ' '.join('%+.2f' % (100 * x) for x in r['steps']), r['q'], 100 * r['rem']))
    for run in sys.argv[1:3]:
        h = th0(run)
        f = floor(run)
        print('\n%s: T(H0) from the written cells %.3f K (convergence.out %.3f)' % (run, h['T'], h['conv']))
        print('   share of the sum by the cells\' temperature: ' + ';  '.join('%s K: %.1f%% (%d cells)' % (
            ('below %.0f' % x['hi']) if x['lo'] == 0 else (('above %.0f' % x['lo']) if not np.isfinite(x['hi']) else '%.0f-%.0f' % (x['lo'], x['hi'])),
            100 * x['share'], x['cells']) for x in h['shares']))
        print('   last 7 iterations: standard deviation %.2f%%; a difference three iterations apart then scatters by %.2f%%, so the 2%% limit is %.1f of it;'
              ' the test on T(H0) alone: %s %%' % (100 * f['sd'], 100 * f['diff'], f['lim_over'], ' '.join('%.2f' % (100 * x) for x in f['test'])))
