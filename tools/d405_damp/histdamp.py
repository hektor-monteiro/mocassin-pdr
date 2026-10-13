#!/usr/bin/env python3
"""D-405 (L-49): do cells oscillate, or scatter? Read from cell histories.

    histdamp.py <run> [<first iteration, default 9>] [<last iteration>]

Needs <run>/hist/itNN.npz, one per iteration (tools/d405_damp/snap.py).

For a quantity q of one cell over the iterations, with d1 = q(n) - q(n-1)
and d2 = q(n) - q(n-2):

    R = <d2^2> / <d1^2>     and     c = corr(d1(n), d1(n+1))

tell the kinds of motion apart without any threshold:

    noise, independent from one iteration to the next   R = 1      c = -0.50
    the same through a blend of 0.75 new and 0.25 old   R = 1.25   c = -0.375
    a cycle of period two                               R -> 0     c -> -1
    a steady drift                                      R -> 4     c -> +1
    a random walk                                       R = 2      c = 0

R and c are pooled over the cells of a band of A_V and over the iterations
(means of squares, and the same with each cell's values divided by its own
step size so that the few cells with the largest steps do not carry it).

Two-state quantities are also counted cell by cell: the molecular fraction's
large steps, and the carbon state (C+ over C+ + C above 0.9, or below 0.18).
For a state drawn afresh at every iteration with probability p, the chance
that a cell is 'on' given that it was 'on' the iteration before is p, the
same as given that it was 'off'.
"""
import glob
import os
import sys

import numpy as np

QB = (0, 0.05, 0.15, 0.3, 0.5, 0.75, 1.0)


def load(run, i0=9, i1=None):
    files = sorted(glob.glob(os.path.join(run, 'hist', 'it*.npz')))
    its = [int(os.path.basename(f)[2:4]) for f in files]
    i1 = max(its) if i1 is None else i1
    use = [(i, f) for i, f in zip(its, files) if i0 <= i <= i1]
    assert len(use) >= 4, 'needs four iterations or more, has %s' % its
    assert [u[0] for u in use] == list(range(use[0][0], use[-1][0] + 1)), 'iterations missing: %s' % its
    return [u[0] for u in use], [np.load(f) for _, f in use], its


def stats(x):
    """x: (iterations, cells). Pooled R and c, plain and with each cell scaled by its own rms step."""
    d1 = x[1:] - x[:-1]
    d2 = x[2:] - x[:-2]
    s = np.sqrt((d1 ** 2).mean(axis=0))
    ok = s > 0
    if ok.sum() < 20:
        return None
    d1, d2, s = d1[:, ok], d2[:, ok], s[ok]
    u1, u2 = d1 / s, d2 / s
    rc = (d2 ** 2).mean(axis=0) / (d1 ** 2).mean(axis=0)   # each cell's own R
    return {'step': float(np.median(np.abs(d1))), 'R': float((d2 ** 2).mean() / (d1 ** 2).mean()),
            'c': float((d1[1:] * d1[:-1]).mean() / (d1 ** 2).mean()),
            'Rn': float((u2 ** 2).mean() / (u1 ** 2).mean()), 'cn': float((u1[1:] * u1[:-1]).mean() / (u1 ** 2).mean()),
            'lowR': float((rc < 0.3).mean()), 'highR': float((rc > 2.5).mean()), 'n': int(ok.sum())}


def analyse(run, i0=9, i1=None):
    use, D, its = load(run, i0, i1)
    last = D[-1]
    lg = lambda k: np.log(np.maximum(np.array([d[k] for d in D], float), 1e-300))     # noqa: E731
    fm = np.array([2 * d['x_H2'] for d in D])
    Q = {'ln T': lg('Te'), 'ln n_e': lg('Ne'), 'f_mol': fm, 'ln x(H2)': lg('x_H2'), 'ln x(H)': lg('x_H'), 'ln x(C)': lg('x_C'),
         'ln x(C+)': lg('x_C+'), 'ln x(CO)': lg('x_CO')}
    av = last['AV'].astype(float)
    xhp = np.array([d['x_H+'] for d in D])
    neutral, ionized = np.all(xhp < 0.3, axis=0), np.all(xhp >= 0.3, axis=0)
    q = np.quantile(av[neutral], QB)
    bands = [('ionized', ionized)] + [('A_V %.2f-%.2f' % (q[i], q[i + 1]), neutral & (av >= q[i]) & (av <= q[i + 1])) for i in range(6)]
    bands.append(('all neutral', neutral))
    out = {'run': run, 'its': use, 'kept': its, 'ncell': int(len(av)), 'nion': int(ionized.sum()), 'nneutral': int(neutral.sum()), 'bands': [], 'jumps': [],
           'carbon': []}
    for name, m in bands:
        if m.sum() < 20:
            continue
        row = {'name': name, 'n': int(m.sum()), 'q': {}}
        for k, x in Q.items():
            r = stats(x[:, m])
            if r is not None:
                row['q'][k] = r
        out['bands'].append(row)
    d1 = fm[1:] - fm[:-1]
    for thr in (0.5, 0.25, 0.1):
        J = np.abs(d1) > thr
        nj = J.sum(axis=0)
        c = J.any(axis=0)
        back = int((J[:-1] & J[1:] & (np.sign(d1[:-1]) != np.sign(d1[1:]))).sum())
        row = {'thr': thr, 'per': [int(x) for x in J.sum(axis=1)], 'steps': int(J.sum()), 'cells': int(c.sum()), 'back': back, 'of': int(J[:-1].sum()),
               'hist': [int(x) for x in np.bincount(nj[nj > 0], minlength=d1.shape[0] + 1)[1:]]}
        if c.any():
            row.update(av=[float(av[c].min()), float(np.median(av[c])), float(av[c].max())],
                       fm=[float(np.median(fm[:, c].min(axis=0))), float(np.median(fm[:, c].max(axis=0)))])
        out['jumps'].append(row)
    # the carbon state, by bins of 0.1 mag where both states occur
    f = np.array([d['x_C+'] / (d['x_C+'] + d['x_C'] + d['x_CO']) for d in D])
    on, off = f > 0.9, f < 0.18
    for a in np.arange(np.floor(10 * av[neutral].min()) / 10, av[neutral].max(), 0.1):
        m = neutral & (av >= a) & (av < a + 0.1)
        if m.sum() < 50:
            continue
        p_on, p_off = float(on[:, m].mean()), float(off[:, m].mean())
        if min(p_on, p_off) < 0.02:
            continue
        o0, o1 = on[:-1, m], on[1:, m]
        f0 = off[:-1, m]
        out['carbon'].append({'lo': float(a), 'n': int(m.sum()), 'on': p_on, 'off': p_off,
                              'on_on': float((o0 & o1).sum() / max(o0.sum(), 1)), 'on_off': float((f0 & o1).sum() / max(f0.sum(), 1)),
                              'always_on': float(on[:, m].all(axis=0).mean()), 'always_off': float(off[:, m].all(axis=0).mean()),
                              'iid_on': p_on ** on.shape[0], 'iid_off': p_off ** on.shape[0]})
    return out


if __name__ == '__main__':
    run = sys.argv[1].rstrip('/')
    A = analyse(run, int(sys.argv[2]) if len(sys.argv) > 2 else 9, int(sys.argv[3]) if len(sys.argv) > 3 else None)
    print('%s: iterations %d-%d (%d kept in all: %s)' % (run, A['its'][0], A['its'][-1], len(A['kept']), ' '.join(map(str, A['kept']))))
    print('cells %d: ionized throughout %d, neutral throughout %d, changing side %d' % (A['ncell'], A['nion'], A['nneutral'], A['ncell'] - A['nion'] - A['nneutral']))
    print('\n%-13s %-9s %10s %6s %6s   %6s %6s   %9s %9s' % ('', '', 'med |d1|', 'R', 'c', 'R cell', 'c cell', 'R<0.3 [%]', 'R>2.5 [%]'))
    for row in A['bands']:
        for k, r in row['q'].items():
            print('%-13s %-9s %10.3e %6.2f %+6.2f   %6.2f %+6.2f   %9.1f %9.1f' % (row['name'], k, r['step'], r['R'], r['c'], r['Rn'], r['cn'], 100 * r['lowR'], 100 * r['highR']))
        print()
    n1 = len(A['its']) - 1
    for j in A['jumps']:
        print('f_mol steps above %.2f: per iteration %s; %d steps in %d cells; followed by one back the next iteration: %d of %d (%.0f%%)' % (
            j['thr'], ' '.join(map(str, j['per'])), j['steps'], j['cells'], j['back'], j['of'], 100 * j['back'] / max(j['of'], 1)))
        print('   cells by number of such steps (1, 2, ... of %d): %s' % (n1, ' '.join(map(str, j['hist']))))
        if 'av' in j and j['thr'] == 0.5:
            print('   those cells: A_V %.2f-%.2f (median %.2f), f_mol min-max over the iterations, median %.2f-%.2f' % (j['av'][0], j['av'][2], j['av'][1], *j['fm']))
    if A['carbon']:
        k = len(A['its'])
        print('\ncarbon, on = C+/(C+ + C + CO) above 0.9, off = below 0.18; over %d iterations' % k)
        print('  A_V        cells   on [%]  off [%]   on, if on before [%]   on, if off before [%]   on throughout [%] (if drawn afresh)   off throughout [%] (if drawn afresh)')
        for c in A['carbon']:
            print('  %.1f-%.1f   %5d   %6.1f   %6.1f   %12.1f   %20.1f   %14.2f (%.2f)   %24.2f (%.2f)' % (
                c['lo'], c['lo'] + 0.1, c['n'], 100 * c['on'], 100 * c['off'], 100 * c['on_on'], 100 * c['on_off'], 100 * c['always_on'], 100 * c['iid_on'],
                100 * c['always_off'], 100 * c['iid_off']))
