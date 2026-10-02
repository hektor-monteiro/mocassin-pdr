#!/usr/bin/env python3
"""H-007: what the H2 level model gave on a finished MOCASSIN run.

Reads output/lineFluxH2.out and output/h2Cells.out (and run.log for the
sweeps) and prints the main lines, a radial table of the per-cell results -
n(H2), Te, the columns, the Solomon rate from the levels against the
chemistry's own on the same field (all, and the direct part alone), ortho/para
and the excited fraction - and where the 2.12 um emission comes from.

With --cloudy PREFIX --rin R the same four lines Cloudy saved for the model
(save lines emissivity: 2.121, 28.2, 17.03, 12.28 um and Hbeta, as D-389's
runs/d389-cloudy-h2s/150k) are integrated over its sphere for comparison.

    python tools/h007_report.py <run dir> [--cloudy PREFIX --rin R] [--bins N]
"""
import os
import sys

import numpy as np

PC = 3.0857e18
MAIN = ['1- 0 S( 1)', '2- 1 S( 1)', '1- 0 S( 0)', '1- 0 Q( 1)', '0- 0 S( 0)', '0- 0 S( 1)', '0- 0 S( 2)',
        '0- 0 S( 3)', '0- 0 S( 5)']


def lines(run):
    out, hb = {}, None
    for l in open(os.path.join(run, 'output', 'lineFluxH2.out')):
        if l.startswith('# Hbeta'):
            hb = float(l.split(':')[1])*1e36
        if l.startswith('#'):
            continue
        out[l[2:14].strip()] = (float(l[30:44]), float(l[57:71]), float(l[71:85]))   # lambda, L, L/Hb
    return out, hb


def cells(run):
    rows = [l.replace('|', ' ').split() for l in open(os.path.join(run, 'output', 'h2Cells.out'))
            if not l.startswith('#')]
    return np.array(rows, float)


def main(run, cloudy=None, rin=0., nb=14):
    L, hb = lines(run)
    print(f'{run}: Hbeta = {hb:.4e} erg/s')
    print('  line          lambda[um]     L[erg/s]     L/Hbeta')
    for k in MAIN:
        kk = [x for x in L if x.replace(' ', '') == k.replace(' ', '')]
        if kk:
            lam, lum, r = L[kk[0]]
            print(f'  {k:12s} {lam:10.4f}   {lum:11.4e}  {r:11.4e}')
    s1 = [x for x in L if x.replace(' ', '') == '1-0S(1)']
    s2 = [x for x in L if x.replace(' ', '') == '2-1S(1)']
    if s1 and s2:
        print(f'  2-1 S(1) / 1-0 S(1) = {L[s2[0]][1]/L[s1[0]][1]:.3f}')
    log = os.path.join(run, 'run.log')
    if not os.path.exists(log):
        log = os.path.join(run, 'warm.log')
    if os.path.exists(log):
        sw = [l.rstrip() for l in open(log, errors='replace') if 'h2LevelModel' in l or 'L [erg/s] 1-0' in l]
        print('  sweeps:')
        for l in sw:
            print('   ' + l)
    a = cells(run)
    r = np.sqrt(a[:, 4]**2 + a[:, 5]**2 + a[:, 6]**2)/PC
    nH2, T, sol, solc, pump, op, fs, sd, cd, Nst, Nown, fd = (a[:, i] for i in range(7, 19))
    act = pump > 0
    hi = r[act].max() if act.any() else r.max()
    edges = np.linspace(r.min(), hi*1.02, nb + 1)
    print('  r[pc]     n   n(H2)      Te     N(H2) to   through    diffuse | Solomon [s-1]: levels   chem    ratio | direct'
          ' ratio |   o/p     f*')
    for i in range(nb):
        m = (r >= edges[i]) & (r < edges[i + 1])
        if not m.any():
            continue
        md = lambda x: np.median(x[m])

        def q(x, y):
            mm = m & (y > 0)
            return np.median((x/np.maximum(y, 1e-300))[mm]) if mm.any() else np.nan
        print(f'  {0.5*(edges[i] + edges[i+1]):6.3f} {m.sum():5d} {md(nH2):9.2e} {md(T):7.1f}  {md(Nst):9.2e} {md(Nown):9.2e}'
              f'   {md(fd):5.3f}   |              {md(sol):9.2e} {md(solc):9.2e} {q(sol, solc):6.2f} |   {q(sd, cd):6.2f}'
              f'     | {md(op):6.2f} {md(fs):8.1e}')
    if cloudy:
        e = np.loadtxt(cloudy + '.h2emis')
        hd = open(cloudy + '.h2emis').readline().lstrip('#').rstrip('\n').split('\t')
        depth = e[:, 0]
        rr = rin + depth
        edg = np.concatenate([[0.], 0.5*(depth[1:] + depth[:-1]), [depth[-1] + 0.5*(depth[-1] - depth[-2])]])
        dv = 4*np.pi*rr**2*np.diff(edg)
        tot = {h.strip(): (e[:, i]*dv).sum() for i, h in enumerate(hd) if i > 0}
        hbC = [v for k, v in tot.items() if k.startswith('H  1')][0]
        print('  Cloudy (1D sphere), L/Hbeta, and ours over it:')
        names = {'H2 2.12125m': '1- 0 S( 1)', 'H2 28.2111m': '0- 0 S( 0)', 'H2 17.0302m': '0- 0 S( 1)', 'H2 12.2785m': '0- 0 S( 2)'}
        for k, v in tot.items():
            if k in names:
                kk = [x for x in L if x.replace(' ', '') == names[k].replace(' ', '')]
                ours = L[kk[0]][2] if kk else np.nan
                print(f'    {k:14s} {v/hbC:10.3e}   ours {ours:10.3e}   ratio {ours/(v/hbC):7.2f}')


if __name__ == '__main__':
    argv = sys.argv[1:]
    cl = argv[argv.index('--cloudy') + 1] if '--cloudy' in argv else None
    rin = float(argv[argv.index('--rin') + 1]) if '--rin' in argv else 0.
    nb = int(argv[argv.index('--bins') + 1]) if '--bins' in argv else 14
    main(argv[0], cl, rin, nb)
