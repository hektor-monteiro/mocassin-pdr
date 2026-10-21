#!/usr/bin/env python3
"""H-007: figures for the H2 level model on a finished MOCASSIN run, against
Cloudy's 1D model of the same nebula where there is one.

    emissivity  4 pi j of 1-0 S(1) 2.12 um, 0-0 S(0) 28.2 um, 0-0 S(1)
                17.0 um and 0-0 S(2) 12.28 um against radius, one panel each:
                the model's cells (median per radial bin, solid) and Cloudy's
                zones (dashed)
    shellratio  with Cloudy: each line's luminosity per radial shell, this work
                over Cloudy
    solomon     the H2 dissociation rate per molecule against radius: from the
                level model (solid) and the chemistry's own on the same field
                (dashed); and n(H2) on the right-hand axis

    series      the same model at several resolutions: 4 pi j of 1-0 S(1)
                against radius, and the cumulative L(<r), from the cells' own
                volumes (as writeH2Lines sums them); L/Hbeta in the legend

    python tools/h007_figures.py <run dir> <out dir> [--cloudy PREFIX --rin R] [--tag NAME]
    python tools/h007_figures.py --series <out dir> <tag> <run dir> [<run dir> ...]
"""
import os
import struct
import sys

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h004_figures import style          # noqa: E402

PC = 3.0857e18
H = 6.6262e-27
C = 2.997925e10
BLUE, WARM, GREEN = '#1f4e79', '#b3541e', '#2e7d4f'
LINES = {'1-0 S(1) 2.12 um': ((1, 3), (0, 1), 3.47e-7, 'H2 2.12125m'),
         '0-0 S(0) 28.2 um': ((0, 2), (0, 0), 2.94e-11, 'H2 28.2111m'),
         '0-0 S(1) 17.0 um': ((0, 3), (0, 1), 4.76e-10, 'H2 17.0302m'),
         '0-0 S(2) 12.28 um': ((0, 4), (0, 2), 2.76e-9, 'H2 12.2785m')}


def load(run):
    f = open(os.path.join(run, 'output', 'h2Pop.bin'), 'rb')
    nc, nl = struct.unpack('2i', f.read(8))
    v = np.frombuffer(f.read(4*nl), np.int32); J = np.frombuffer(f.read(4*nl), np.int32)
    E = np.frombuffer(f.read(8*nl), np.float64)
    P = np.frombuffer(f.read(4*nl*nc), np.float32).reshape(nc, nl)
    cells = np.array([l.replace('|', ' ').split() for l in open(os.path.join(run, 'output', 'h2Cells.out'))
                      if not l.startswith('#')], float)
    return v, J, E, P, cells


def binned(r, y, edges):
    out = np.full(len(edges) - 1, np.nan)
    for i in range(len(edges) - 1):
        m = (r >= edges[i]) & (r < edges[i + 1])
        if m.any():
            out[i] = np.median(y[m])
    return out


def main(run, outdir, cloudy=None, rin=0., tag='run'):
    v, J, E, P, cells = load(run)
    lev = {(a, b): i for i, (a, b) in enumerate(zip(v, J))}
    cid = cells[:, 3].astype(int) - 1
    r = np.sqrt(cells[:, 4]**2 + cells[:, 5]**2 + cells[:, 6]**2)/PC
    nH2 = cells[:, 7]
    edges = np.linspace(r.min(), r.max()*1.001, 36)
    rc = 0.5*(edges[1:] + edges[:-1])
    style()
    os.makedirs(outdir, exist_ok=True)

    # one panel per line: this work's cells (median per radial bin) and Cloudy's zones
    if cloudy:
        e = np.loadtxt(cloudy + '.h2emis')
        hd = [h.strip() for h in open(cloudy + '.h2emis').readline().lstrip('#').rstrip('\n').split('\t')]
        d = e[:, 0]
        rr = (rin + d)/PC
        dvC = 4*np.pi*(rin + d)**2*np.diff(np.concatenate([[0.], 0.5*(d[1:] + d[:-1]), [1.5*d[-1] - 0.5*d[-2]]]))
    dV = volumes(cells)
    act = np.zeros(len(r), bool)
    for (u, l, A, _) in LINES.values():
        act |= P[cid, lev[u]]*nH2 > 0
    lo = r[act & (nH2 > 1e-3*nH2.max())].min()*0.85
    fig, axs = plt.subplots(2, 2, figsize=(9.6, 7.0), sharex=True)
    shell = np.linspace(lo, r.max()*1.001, 19)
    ratios = {}
    for ax, (name, (u, l, A, clab)) in zip(axs.flat, LINES.items()):
        iu, il = lev[u], lev[l]
        em = nH2*P[cid, iu]*A*H*C*(E[iu] - E[il])          # 4 pi j [erg cm^-3 s^-1]
        y = binned(r, em, edges)
        ax.semilogy(rc, y, color=BLUE, lw=1.7, label='this work')
        top = np.nanmax(y)
        if cloudy and clab in hd:
            yc = e[:, hd.index(clab)]
            ax.semilogy(rr, yc, color=WARM, ls='--', lw=1.4, label='Cloudy')
            top = max(top, yc.max())
            Ls = np.histogram(r, shell, weights=em*dV)[0]
            Lc = np.histogram(rr, shell, weights=yc*dvC)[0]
            ratios[name] = np.where(Lc > 0, Ls/np.maximum(Lc, 1e-300), np.nan)
        ax.set_ylim(top*1e-4, top*3)
        ax.set_xlim(lo, r.max()*1.02)
        ax.set_title(name, fontsize=11)
        if ax in axs[1]:
            ax.set_xlabel('radius  [pc]')
        if ax in axs[:, 0]:
            ax.set_ylabel(r'$4\pi j$  [erg cm$^{-3}$ s$^{-1}$]')
    axs[0, 0].legend(loc='upper right', fontsize=9.5)
    fig.tight_layout()
    for ext in ('svg', 'png'):
        fig.savefig(os.path.join(outdir, f'h007_emissivity_{tag}.{ext}'), dpi=200)
    plt.close(fig)

    if ratios:
        # each code's luminosity per radial shell, this work over Cloudy (not
        # renormalised by Hbeta)
        fig, ax = plt.subplots(figsize=(5.8, 4.2))
        sc = 0.5*(shell[1:] + shell[:-1])
        for (name, q), col in zip(ratios.items(), [BLUE, GREEN, WARM, '0.35']):
            ax.semilogy(sc, q, color=col, lw=1.6, marker='o', ms=3, label=name)
        ax.axhline(1., color='0.5', lw=0.8)
        ax.set_ylim(0.05, 10.)
        ax.set_xlim(lo, r.max()*1.02)
        ax.set_xlabel('radius  [pc]')
        ax.set_ylabel('luminosity per shell, this work / Cloudy')
        ax.legend(loc='upper right', fontsize=9)
        for ext in ('svg', 'png'):
            fig.savefig(os.path.join(outdir, f'h007_shellratio_{tag}.{ext}'), dpi=200)
        plt.close(fig)

    fig, ax = plt.subplots(figsize=(5.4, 4.2))
    sol, solc = cells[:, 9], cells[:, 10]
    ok = sol > 0
    ax.semilogy(rc, binned(r[ok], sol[ok], edges), color=BLUE, lw=1.7, label='level model')
    ok = solc > 0
    ax.semilogy(rc, binned(r[ok], solc[ok], edges), color=WARM, lw=1.4, ls='--', label='chemistry, same field')
    ax.set_xlabel('radius  [pc]')
    ax.set_ylabel(r'H$_2$ dissociation rate per molecule  [s$^{-1}$]')
    ax2 = ax.twinx()
    ax2.semilogy(rc, binned(r, np.maximum(nH2, 1e-30), edges), color='0.5', lw=1.0, ls=':')
    ax2.set_ylabel(r'$n({\rm H_2})$  [cm$^{-3}$]  (dotted)', color='0.4')
    ax.legend(loc='lower left', fontsize=9.5)
    for ext in ('svg', 'png'):
        fig.savefig(os.path.join(outdir, f'h007_solomon_{tag}.{ext}'), dpi=200)
    plt.close(fig)


def volumes(cells):
    """MOCASSIN's getVolume for the listed cells: half a spacing either side,
    the end cells half-size, on axes rebuilt from the cells' coordinates;
    times 8 for a symmetricXYZ octant (the coordinates are all >= 0)."""
    dV = np.ones(len(cells))
    for ax in range(3):
        idx = cells[:, ax].astype(int)
        x = np.zeros(idx.max() + 2)
        x[idx] = cells[:, 4 + ax]
        n = idx.max()
        d = np.empty(n + 1)
        d[1] = 0.5*(x[2] - x[1])
        d[n] = 0.5*(x[n] - x[n - 1])
        d[2:n] = 0.5*(x[3:n + 1] - x[1:n - 1])
        dV *= d[idx]
    return dV*(8. if cells[:, 4:7].min() >= 0. else 1.)


def hbeta(run):
    for l in open(os.path.join(run, 'output', 'lineFluxH2.out')):
        if l.startswith('# Hbeta'):
            return float(l.split(':')[1])*1e36


def series(outdir, tag, runs):
    (u, l, A, _) = LINES['1-0 S(1) 2.12 um']
    style()
    os.makedirs(outdir, exist_ok=True)
    fig, (ax, bx) = plt.subplots(1, 2, figsize=(10.4, 4.2))
    shades = [BLUE, GREEN, WARM, '0.3']
    for run, col in zip(runs, shades):
        v, J, E, P, cells = load(run)
        lev = {(a, b): i for i, (a, b) in enumerate(zip(v, J))}
        cid = cells[:, 3].astype(int) - 1
        r = np.sqrt(cells[:, 4]**2 + cells[:, 5]**2 + cells[:, 6]**2)/PC
        iu, il = lev[u], lev[l]
        em = cells[:, 7]*P[cid, iu]*A*H*C*(E[iu] - E[il])
        lab = f'{int(cells[:, 0].max())}$^3$'
        edges = np.linspace(r.min(), r.max()*1.001, 36)
        rc = 0.5*(edges[1:] + edges[:-1])
        ax.semilogy(rc, binned(r, em, edges), color=col, lw=1.6, label=lab)
        o = np.argsort(r)
        cum = np.cumsum((em*volumes(cells))[o])
        bx.plot(r[o], cum/1e33, color=col, lw=1.6, label=lab + f'   L/H$\\beta$ = {cum[-1]/hbeta(run):.2e}')
    ax.set_xlabel('radius  [pc]')
    ax.set_ylabel(r'$4\pi j$(1-0 S(1))  [erg cm$^{-3}$ s$^{-1}$]')
    ax.set_ylim(bottom=1e-30)
    ax.legend(loc='upper right', fontsize=9.5, title='median per radial bin', title_fontsize=9)
    bx.set_xlabel('radius  [pc]')
    bx.set_ylabel(r'$L(<r)$ of 1-0 S(1)  [10$^{33}$ erg s$^{-1}$]')
    bx.set_ylim(bottom=0.)
    bx.legend(loc='upper left', fontsize=9.5)
    fig.tight_layout()
    for ext in ('svg', 'png'):
        fig.savefig(os.path.join(outdir, f'h007_series_{tag}.{ext}'), dpi=200)
    plt.close(fig)


if __name__ == '__main__':
    argv = sys.argv[1:]
    if argv[0] == '--series':
        series(argv[1], argv[2], argv[3:])
        sys.exit(0)
    cl = argv[argv.index('--cloudy') + 1] if '--cloudy' in argv else None
    rin = float(argv[argv.index('--rin') + 1]) if '--rin' in argv else 0.
    tag = argv[argv.index('--tag') + 1] if '--tag' in argv else 'run'
    main(argv[0], argv[1], cl, rin, tag)
