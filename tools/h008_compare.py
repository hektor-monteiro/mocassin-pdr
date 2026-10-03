#!/usr/bin/env python3
"""H-008: two runs of the same model that differ in one choice of the level
model, against each other and against Cloudy's 1D model of the nebula.

    A  the run-to-run scatter: Hbeta, and Te and n(H2) cell by cell (the
       level model does not feed back, so these differ by the Monte Carlo
       realization only)
    L  the line totals over Hbeta, each run and Cloudy
    S  each line's luminosity per radial shell, over Cloudy's
    N  level columns along the three grid axes, and Cloudy's (its printed
       columns; J = 4 and v = 1 J = 3 recovered from its line emissivities)

    python tools/h008_compare.py <run A> <run B> --cloudy PREFIX --rin R [--names A,B]
"""
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h007_figures import load, volumes, hbeta, LINES, H, C, PC      # noqa: E402

SHELLS = np.array([0.17, 0.19, 0.21, 0.23, 0.26, 0.30, 0.35, 0.40, 0.50, 0.60])
LEVELS = [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4), (1, 3)]


def model(run):
    v, J, E, P, c = load(run)
    lev = {(a, b): i for i, (a, b) in enumerate(zip(v, J))}
    cid = c[:, 3].astype(int) - 1
    r = np.sqrt((c[:, 4:7]**2).sum(1))/PC
    dV = volumes(c)
    em = {}
    for name, (u, l, A, _) in LINES.items():
        iu, il = lev[u], lev[l]
        em[name] = c[:, 7]*P[cid, iu]*A*H*C*(E[iu] - E[il])*dV
    cols = []
    for ax, (o1, o2) in ((4, (1, 2)), (5, (0, 2)), (6, (0, 1))):
        m = (c[:, o1] == 1) & (c[:, o2] == 1)
        cc = c[m]
        o = np.argsort(cc[:, ax])
        cc = cc[o]
        x = cc[:, ax]
        dx = np.diff(np.concatenate([[0.], 0.5*(x[1:] + x[:-1]), [1.5*x[-1] - 0.5*x[-2]]]))
        N = (cc[:, 7, None]*P[cc[:, 3].astype(int) - 1]*dx[:, None]).sum(0)
        cols.append({k: N[lev[k]] for k in LEVELS} | {'H2': N.sum(), 'o/p': N[J % 2 == 1].sum()/N[J % 2 == 0].sum()})
    return dict(c=c, r=r, em=em, cols=cols, hb=hbeta(run))


def cloudy(prefix, rin):
    e = np.loadtxt(prefix + '.h2emis')
    hd = [h.strip() for h in open(prefix + '.h2emis').readline().lstrip('#').rstrip('\n').split('\t')]
    d = e[:, 0]
    dd = np.diff(np.concatenate([[0.], 0.5*(d[1:] + d[:-1]), [1.5*d[-1] - 0.5*d[-2]]]))
    dv = 4*np.pi*(rin + d)**2*dd
    hb = (e[:, [i for i, h in enumerate(hd) if h.startswith('H  1')][0]]*dv).sum()
    em = {name: e[:, hd.index(clab)]*dv for name, (u, l, A, clab) in LINES.items()}
    # columns: printed ones from the main output, J = 4 and v = 1 J = 3 from 4 pi j
    txt = open(prefix + '.out', errors='replace').read()
    m = re.search(r'H2 total +([\d.]+) H2 ortho +([\d.]+) para +([\d.]+) v0 J=0,3 +([\d.]+) +([\d.]+) +([\d.]+) +([\d.]+)', txt)
    cols = {'H2': 10**float(m.group(1)), 'o/p': 10**(float(m.group(2)) - float(m.group(3)))}
    for k, g in zip(LEVELS[:4], range(4, 8)):
        cols[k] = 10**float(m.group(g))
    for name, k in (('0-0 S(2) 12.28 um', (0, 4)), ('1-0 S(1) 2.12 um', (1, 3))):
        u, l, A, clab = LINES[name]
        lam = float(clab.split()[1].rstrip('m'))*1e-4
        cols[k] = (e[:, hd.index(clab)]*dd).sum()/(A*H*C/lam)
    return dict(r=(rin + d)/PC, em=em, hb=hb, cols=cols)


def main(ra, rb, prefix, rin, names):
    A, B, Cl = model(ra), model(rb), cloudy(prefix, rin)
    na, nb = names
    print(f'A  run-to-run: Hbeta {nb}/{na} = {B["hb"]/A["hb"]:.4f}')
    ca, cb = A['c'], B['c']
    if len(ca) == len(cb) and (ca[:, 3] == cb[:, 3]).all():
        for lab, i in (('Te', 8), ('n(H2)', 7)):
            ok = (ca[:, i] > 1e-3*ca[:, i].max()) & (cb[:, i] > 0)
            q = cb[ok, i]/ca[ok, i]
            print(f'   {lab:6s} {nb}/{na} over {ok.sum()} cells: median {np.median(q):.4f}, 16-84% {np.percentile(q, 16):.4f}-'
                  f'{np.percentile(q, 84):.4f}, 1-99% {np.percentile(q, 1):.3f}-{np.percentile(q, 99):.3f}')
    print('L  line / Hbeta:      ' + f'{na:>12s} {nb:>12s} {"Cloudy":>12s}   {na}/Cl  {nb}/Cl  {nb}/{na}')
    for name in LINES:
        a, b, c = A['em'][name].sum()/A['hb'], B['em'][name].sum()/B['hb'], Cl['em'][name].sum()/Cl['hb']
        print(f'   {name:18s} {a:12.4e} {b:12.4e} {c:12.4e}   {a/c:6.2f} {b/c:6.2f} {b/a:6.2f}')
    print(f'S  luminosity per shell over Cloudy, {na} | {nb}')
    print('   shell[pc]   ' + '  '.join(f'{n.split()[2] + " um":>11s}' for n in LINES))
    for i in range(len(SHELLS) - 1):
        out = []
        for name in LINES:
            mc = (Cl['r'] >= SHELLS[i]) & (Cl['r'] < SHELLS[i + 1])
            lc = Cl['em'][name][mc].sum()
            q = [(X['em'][name][(X['r'] >= SHELLS[i]) & (X['r'] < SHELLS[i + 1])].sum())/lc for X in (A, B)]
            out.append(f'{q[0]:5.2f}|{q[1]:5.2f}')
        print(f'   {SHELLS[i]:4.2f}-{SHELLS[i+1]:4.2f}   ' + '  '.join(f'{o:>11s}' for o in out))
    print('N  log N along the axes (x / y / z), and Cloudy')
    for k in ['H2', 'o/p'] + LEVELS:
        f = (lambda x: f'{x:.3f}') if k == 'o/p' else (lambda x: f'{np.log10(x):.2f}')
        print(f'   {str(k):8s} {na}: ' + ' / '.join(f(X[k]) for X in A['cols']) + f'   {nb}: '
              + ' / '.join(f(X[k]) for X in B['cols']) + f'   Cloudy: {f(Cl["cols"][k])}')


if __name__ == '__main__':
    argv = sys.argv[1:]
    pre = argv[argv.index('--cloudy') + 1]
    rin = float(argv[argv.index('--rin') + 1])
    names = argv[argv.index('--names') + 1].split(',') if '--names' in argv else ['A', 'B']
    main(argv[0], argv[1], pre, rin, names)
