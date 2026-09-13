#!/usr/bin/env python3
"""D-260: publication-style profiles of a coupled run against a 3D-PDR reference.

Three figures - temperatures, ionic fractions, molecular fractions - each with
two panels sharing the y axis: against A_V (left) and against distance from the
star (right). Every active PDR-zone cell in the grid is used, binned; the solid
line is the bin median and the shading holds 16-84% of the cells. The reference
is dashed.

Radius of the reference. A 3D-PDR slab has depth x from its own illuminated
face. It is placed on MOCASSIN's radial axis as r = Rout - (x_max - x), i.e.
its far face on the grid's outer edge. D-257 built the slab to our PDR depth
(14.89 pc against 14.90), so this puts its face at the ionization front.

Needs numpy + matplotlib (the `astro` conda env):
    ~/miniforge3/envs/astro/bin/python tools/d260_figures.py \
        <run-dir> <reference.pdr.fin> <out-dir> [label]
"""
import os
import sys

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.ticker import LogLocator, NullFormatter, AutoMinorLocator

PC = 3.0857e18
SPEC = ['H3+', 'He+', 'Mg', 'H2+', 'O2', 'CH5+', 'CH4+', 'O+', 'OH+', 'Mg+',
        'C+', 'CH4', 'H2O+', 'H3O+', 'CO+', 'O2+', 'CH2', 'H2O', 'H+', 'CH3+',
        'CH', 'CH3', 'HCO+', 'CH2+', 'C', 'He', 'CH+', 'CO', 'OH', 'O', 'H2',
        'H', 'e-']
# Paul Tol's colour-blind-safe "muted" set
TOL = ['#332288', '#88CCEE', '#44AA99', '#117733', '#999933', '#DDCC77',
       '#CC6677', '#882255', '#AA4499']
LATEX = {'e-': r'e$^-$', 'H+': r'H$^+$', 'He+': r'He$^+$', 'C+': r'C$^+$',
         'O+': r'O$^+$', 'Mg+': r'Mg$^+$', 'H2': r'H$_2$', 'H3+': r'H$_3^+$',
         'HCO+': r'HCO$^+$', 'CO': 'CO', 'OH': 'OH', 'H2O': r'H$_2$O',
         'CH': 'CH', 'Tgas': r'$T_\mathrm{gas}$',
         'Tdust': r'$T_\mathrm{dust}$'}
FIGS = [
    ('temperatures', ['Tgas', 'Tdust'], ['#CC6677', '#332288'],
     r'$T$ [K]', None),
    ('ions', ['e-', 'H+', 'He+', 'C+', 'O+', 'Mg+'],
     ['#332288', '#CC6677', '#DDCC77', '#117733', '#88CCEE', '#AA4499'],
     r'$x(i) = n(i)/n_\mathrm{H}$', (1e-14, 3.0)),
    ('molecules', ['H2', 'H3+', 'HCO+', 'CO', 'OH', 'H2O', 'CH'],
     ['#332288', '#CC6677', '#AA4499', '#117733', '#88CCEE', '#999933',
      '#882255'],
     r'$x(i) = n(i)/n_\mathrm{H}$', (1e-20, 3.0)),
]


def style():
    plt.rcParams.update({
        'font.family': 'serif', 'font.serif': ['STIXGeneral', 'DejaVu Serif'],
        'mathtext.fontset': 'stix', 'font.size': 9, 'axes.labelsize': 10,
        'legend.fontsize': 8, 'xtick.labelsize': 9, 'ytick.labelsize': 9,
        'axes.linewidth': 0.8, 'lines.linewidth': 1.4,
        'xtick.direction': 'in', 'ytick.direction': 'in',
        'xtick.top': True, 'ytick.right': True,
        'xtick.major.size': 4, 'ytick.major.size': 4,
        'xtick.minor.size': 2, 'ytick.minor.size': 2,
        'xtick.minor.visible': True, 'ytick.minor.visible': True,
        'legend.frameon': False, 'savefig.bbox': 'tight',
        'savefig.pad_inches': 0.03,
    })


def read_run(run):
    if os.path.exists(os.path.join(run, 'INCOMPLETE')):
        raise SystemExit(f'REFUSING {run}: marked INCOMPLETE')
    out = os.path.join(run, 'output')
    t = open(os.path.join(out, 'grid0.out')).read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    rout = float(t[6])
    xa = np.array(t[7:7 + nx], float)
    ya = np.array(t[7 + nx:7 + nx + ny], float)
    za = np.array(t[7 + nx + ny:7 + nx + ny + nz], float)
    n = nx * ny * nz
    off = 7 + nx + ny + nz
    act = np.array(t[off:off + n * 3:3], float).astype(int)
    X, Y, Z = np.meshgrid(xa, ya, za, indexing='ij')     # i/j/k record order
    r = np.sqrt(X ** 2 + Y ** 2 + Z ** 2).ravel() / PC
    g1 = np.loadtxt(os.path.join(out, 'grid1.out'))
    p = np.array(open(os.path.join(out, 'pdrGrid.out')).read().split(),
                 float)[:n * 45].reshape(n, 45)
    pr = np.loadtxt(os.path.join(out, 'pdrRad.out'), skiprows=1)
    m = (act > 0) & (p[:, 0].astype(int) == 1)
    d = {'AV': p[m, 2], 'r': r[m], 'Tgas': g1[m, 0], 'Tdust': pr[m, 6]}
    for j, s in enumerate(SPEC):
        d[s] = p[m, 12 + j]
    return d, rout / PC


def read_ref(path, rout_pc):
    a = np.array([ln.split() for ln in open(path) if len(ln.split()) >= 41],
                 float)
    d = {'x': a[:, 1], 'AV': a[:, 2], 'Tgas': a[:, 3], 'Tdust': a[:, 4]}
    d['r'] = rout_pc - (a[:, 1].max() - a[:, 1])
    for j, s in enumerate(SPEC):
        d[s] = a[:, 8 + j]
    return d


def binned(x, y, edges, nmin=5):
    xc, med, lo, hi = [], [], [], []
    for a, b in zip(edges[:-1], edges[1:]):
        s = (x >= a) & (x < b)
        if s.sum() < nmin:
            continue
        v = y[s]
        xc.append(x[s].mean())
        med.append(np.median(v))
        lo.append(np.percentile(v, 16))
        hi.append(np.percentile(v, 84))
    return [np.array(q) for q in (xc, med, lo, hi)]


def logticks(ax, lo, hi):
    dec = np.log10(hi) - np.log10(lo)
    if dec > 8:
        # label every second decade, a minor tick at every decade
        ax.yaxis.set_major_locator(LogLocator(base=100, numticks=30))
        ax.yaxis.set_minor_locator(LogLocator(base=10, subs=(1.0,),
                                              numticks=60))
    else:
        ax.yaxis.set_major_locator(LogLocator(base=10, numticks=30))
        ax.yaxis.set_minor_locator(LogLocator(base=10,
                                              subs=np.arange(2, 10) * .1,
                                              numticks=60))
    ax.yaxis.set_minor_formatter(NullFormatter())


def figure(run, ref, name, keys, cols, ylab, ylim, outdir, label):
    fig, axes = plt.subplots(1, 2, figsize=(7.1, 3.3), sharey=True,
                             gridspec_kw={'wspace': 0.05})
    specs = [('AV', np.arange(0.45, 3.2, 0.1), r'$A_V$ [mag]'),
             ('r', np.arange(4.0, 19.8, 0.5),
              r'distance from the star $r$ [pc]')]
    for ax, (xk, edges, xlab) in zip(axes, specs):
        for k, c in zip(keys, cols):
            xc, med, lo, hi = binned(run[xk], run[k], edges)
            pos = lo > 0
            ax.fill_between(xc[pos], lo[pos], hi[pos], color=c, alpha=0.18,
                            lw=0)
            ax.plot(xc, np.where(med > 0, med, np.nan), color=c, ls='-')
            rv = np.where(ref[k] > 0, ref[k], np.nan)
            ax.plot(ref[xk], rv, color=c, ls='--', lw=1.2)
        ax.set_yscale('log')
        ax.xaxis.set_minor_locator(AutoMinorLocator())
        ax.set_xlabel(xlab)
    axes[0].set_xlim(0, 3.15)
    axes[1].set_xlim(4.0, 19.6)
    axes[0].set_ylabel(ylab)
    lo, hi = ylim if ylim else (5, 2e4)
    axes[0].set_ylim(lo, hi)
    logticks(axes[0], lo, hi)
    h = [Line2D([], [], color=c, ls='-', lw=1.6) for c in cols]
    h += [Line2D([], [], color='none'),
          Line2D([], [], color='k', ls='-', lw=1.4),
          Line2D([], [], color='k', ls='--', lw=1.2)]
    labs = [LATEX[k] for k in keys] + ['', label, '3D-PDR reference']
    fig.legend(h, labs, loc='lower center', bbox_to_anchor=(0.5, 0.9),
               ncol=len(h), handlelength=1.8, columnspacing=1.1,
               handletextpad=0.5)
    for ext in ('png', 'pdf'):
        fig.savefig(os.path.join(outdir, f'd260_{name}.{ext}'),
                    dpi=220 if ext == 'png' else None)
    plt.close(fig)


def main():
    run_dir, ref_path, outdir = sys.argv[1:4]
    label = sys.argv[4] if len(sys.argv) > 4 else 'MOCASSIN + 3D-PDR'
    os.makedirs(outdir, exist_ok=True)
    style()
    run, rout_pc = read_run(run_dir)
    ref = read_ref(ref_path, rout_pc)
    print(f'{len(run["AV"])} PDR cells; r {run["r"].min():.2f}-'
          f'{run["r"].max():.2f} pc; reference face at r = {ref["r"].min():.2f}'
          f' pc')
    for name, keys, cols, ylab, ylim in FIGS:
        figure(run, ref, name, keys, cols, ylab, ylim, outdir, label)


if __name__ == '__main__':
    main()
