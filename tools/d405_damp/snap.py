#!/usr/bin/env python3
"""D-405 (L-49): keep each iteration's cells of a run in progress.

    snap.py <run> [<poll seconds, default 10>]

MOCASSIN rewrites output/grid1.out (T, n_e) and output/pdrGrid.out (the
chemistry's abundances) at the end of every iteration. This watches a run,
and when an iteration has been written copies T, n_e and a few abundances of
the active cells to <run>/hist/itNN.npz. It only reads: the run takes the
path it would take without it. It ends when <run>/DONE appears.

An iteration counts as written when convergence.out has a new line and both
files are newer than it and have not changed for 8 seconds.
"""
import os
import sys
import time

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import d260_roellig as R                                   # noqa: E402

KEEP = ('H', 'H2', 'H+', 'e-', 'C+', 'C', 'CO', 'O', 'OH', 'He+')


def nlines(f):
    try:
        return sum(1 for l in open(f) if l.strip() and not l.startswith('#'))
    except OSError:
        return 0


def snapshot(run, it):
    out = os.path.join(run, 'output')
    t = open(os.path.join(out, 'grid0.out')).read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    n = nx * ny * nz
    off = 7 + nx + ny + nz
    act = np.array(t[off:off + n * 3:3], float).astype(int) > 0
    idx = np.where(act)[0]
    g1 = np.loadtxt(os.path.join(out, 'grid1.out'))
    pg = R.read_pdrgrid(out, n)
    d = {'idx': idx, 'shape': np.array([nx, ny, nz]), 'Te': g1[idx, 0].astype('f4'), 'Ne': g1[idx, 1].astype('f4'),
         'nH': g1[idx, 2].astype('f4'), 'AV': pg['AV'][idx].astype('f4'), 'chi': pg['chi'][idx].astype('f4')}
    for k in KEEP:
        if k in R.SPEC:
            d['x_' + k] = pg['ab'][idx, R.SPEC.index(k)]
    os.makedirs(os.path.join(run, 'hist'), exist_ok=True)
    np.savez_compressed(os.path.join(run, 'hist', 'it%02d.npz' % it), **d)


run = sys.argv[1].rstrip('/')
poll = float(sys.argv[2]) if len(sys.argv) > 2 else 10.
conv = os.path.join(run, 'output', 'convergence.out')
files = [os.path.join(run, 'output', f) for f in ('grid1.out', 'pdrGrid.out')]
done = 0
while True:
    fin = os.path.exists(os.path.join(run, 'DONE'))
    it = nlines(conv)
    if it > done:
        try:
            mt = [os.path.getmtime(f) for f in files]
            ready = min(mt) >= os.path.getmtime(conv) and time.time() - max(mt) > 8.
        except OSError:
            ready = False
        if ready:
            try:
                snapshot(run, it)
                print(time.strftime('%H:%M:%S'), 'iteration', it, 'kept', flush=True)
                done = it
            except Exception as e:                           # a file caught half written: try again
                print(time.strftime('%H:%M:%S'), 'iteration', it, 'not read:', repr(e)[:120], flush=True)
    if fin and done >= it:
        break
    time.sleep(poll)
print('run finished;', done, 'iterations seen last', flush=True)
