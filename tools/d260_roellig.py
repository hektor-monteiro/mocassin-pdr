#!/usr/bin/env python3
"""D-260: whole-model profiles in the style of Roellig et al. (2007), Fig. 4.

Three figures, each a single log-log panel against A_V from the star, covering
the ionized gas and the PDR together:

    chemistry     n(i) of H, H2, C, O, CO, OH, H2O, CH, HCO+, H3+
    ions          n(i) of e-, H+, He+, He2+, C+, C2+, O+, O2+, Mg+
    temperatures  T_gas and T_dust

Solid lines are the coupled model, dashed lines the standalone 3D-PDR reference,
one colour per species, each labelled on its own curve (no legend box), as in
the paper. The model line is the median of all active cells in a log A_V bin.

Where each quantity comes from, one source per quantity:
  - ions, electrons and neutral atoms in the ionized gas: MOCASSIN
    (grid2.out ionDen, grid1.out Ne). In PDR cells the chemistry's written ions
    equal these to 1e-4 (median), because MOCASSIN re-imposes them.
  - molecules, and neutral H, C, O in PDR cells: the chemistry (pdrGrid.out).
  - T_gas: MOCASSIN (grid1.out). T_dust: MOCASSIN's grains (pdrRad.out).

Placing the reference. A 3D-PDR slab starts at A_V = 0 at its own lit face, and
D-257 set that face's field to what this model delivers to its first PDR cell.
So its face belongs at our ionization front, and it is drawn at
A_V = A_front + A_V,ref with A_front the smallest PDR-cell A_V. Check: the
shifted slab then ends at 2.93 against our outer edge at 3.00, and the two
extinction-per-length figures are 0.165 and 0.169 mag/pc.

The upper axis is the model's radius: each tick sits at the median A_V of the
active cells at that distance from the star.

Needs numpy + matplotlib (the `astro` conda env):
    ~/miniforge3/envs/astro/bin/python tools/d260_roellig.py \
        <run-dir> <reference.pdr.fin> <out-dir> [model-label]
"""
import os
import sys

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.ticker import (LogLocator, NullFormatter, FixedLocator,
                               FixedFormatter, FuncFormatter)

PC = 3.0857e18
SPEC = ['H3+', 'He+', 'Mg', 'H2+', 'O2', 'CH5+', 'CH4+', 'O+', 'OH+', 'Mg+',
        'C+', 'CH4', 'H2O+', 'H3O+', 'CO+', 'O2+', 'CH2', 'H2O', 'H+', 'CH3+',
        'CH', 'CH3', 'HCO+', 'CH2+', 'C', 'He', 'CH+', 'CO', 'OH', 'O', 'H2',
        'H', 'e-']
# element blocks in grid2.out, in the order MOCASSIN writes the switched-on
# elements (abunV1.in: H He C N O Ne Mg S)
ELEM = ['H', 'He', 'C', 'N', 'O', 'Ne', 'Mg', 'S']
ABUND = {'H': 1.0, 'He': 0.1, 'C': 2.2e-4, 'N': 4e-5, 'O': 3.3e-4,
         'Ne': 5e-5, 'Mg': 2.7e-6, 'S': 9e-6}
TEX = {'e-': r'e$^{-}$', 'H+': r'H$^{+}$', 'He+': r'He$^{+}$',
       'He++': r'He$^{2+}$', 'C+': r'C$^{+}$', 'C++': r'C$^{2+}$',
       'O+': r'O$^{+}$', 'O++': r'O$^{2+}$', 'Mg+': r'Mg$^{+}$',
       'H': 'H', 'H2': r'H$_2$', 'C': 'C', 'O': 'O', 'CO': 'CO', 'OH': 'OH',
       'H2O': r'H$_2$O', 'CH': 'CH', 'HCO+': r'HCO$^{+}$',
       'H3+': r'H$_3^{+}$', 'Tgas': r'$T_\mathrm{gas}$',
       'Tdust': r'$T_\mathrm{dust}$'}

# (key, colour, label). label 'R' puts it in the right margin at the curve's
# last value; a number (A_V, dex) puts it on the curve inside the panel.
CHEM = [('H', '#000000', (0.2, 0.4)), ('O', '#EE3377', (0.2, 0.45)),
        ('C', '#0077BB', (0.2, -0.55)), ('H2', '#CC3311', 'R'),
        ('CO', '#33BBEE', 'R'), ('OH', '#009988', 'R'),
        ('H2O', '#AA7700', 'R'), ('CH', '#7A5195', 'R'),
        ('HCO+', '#882255', 'R'), ('H3+', '#EE7733', 'R')]
IONS = [('e-', '#000000', (0.07, 0.35)), ('H+', '#CC3311', (0.16, 0.35)),
        ('He+', '#EE7733', (0.1, 0.35)), ('He++', '#AA7700', (0.065, 0.45)),
        ('C++', '#33BBEE', (0.1, -0.5)), ('O++', '#EE3377', (0.2, 0.4)),
        ('O+', '#009988', 'R'), ('C+', '#0077BB', 'R'), ('Mg+', '#7A5195', 'R')]
TEMP = [('Tgas', '#CC3311', (0.1, 0.13)), ('Tdust', '#0077BB', (0.1, 0.13))]


def style():
    plt.rcParams.update({
        'font.family': 'serif', 'font.serif': ['STIXGeneral', 'DejaVu Serif'],
        'mathtext.fontset': 'stix', 'font.size': 10, 'axes.labelsize': 11,
        'xtick.labelsize': 10, 'ytick.labelsize': 10,
        'axes.linewidth': 0.9, 'lines.linewidth': 1.5,
        'xtick.direction': 'in', 'ytick.direction': 'in',
        'xtick.major.size': 4.5, 'ytick.major.size': 4.5,
        'xtick.minor.size': 2.3, 'ytick.minor.size': 2.3,
        'ytick.right': True, 'legend.frameon': False,
        'savefig.bbox': 'tight', 'savefig.pad_inches': 0.04,
    })


def read_run(run):
    if os.path.exists(os.path.join(run, 'INCOMPLETE')):
        raise SystemExit(f'REFUSING {run}: marked INCOMPLETE')
    out = os.path.join(run, 'output')
    t = open(os.path.join(out, 'grid0.out')).read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    xa = np.array(t[7:7 + nx], float)
    ya = np.array(t[7 + nx:7 + nx + ny], float)
    za = np.array(t[7 + nx + ny:7 + nx + ny + nz], float)
    n = nx * ny * nz
    off = 7 + nx + ny + nz
    act = np.array(t[off:off + n * 3:3], float).astype(int) > 0
    X, Y, Z = np.meshgrid(xa, ya, za, indexing='ij')     # i/j/k record order
    r = np.sqrt(X ** 2 + Y ** 2 + Z ** 2).ravel() / PC
    g1 = np.loadtxt(os.path.join(out, 'grid1.out'))
    p = np.array(open(os.path.join(out, 'pdrGrid.out')).read().split(),
                 float)[:n * 45].reshape(n, 45)
    pr = np.loadtxt(os.path.join(out, 'pdrRad.out'), skiprows=1)
    g2 = [ln.split() for ln in open(os.path.join(out, 'grid2.out'))]
    ne = len(g2) // n
    if ne != len(ELEM):
        raise SystemExit(f'grid2.out has {ne} element blocks, expected '
                         f'{len(ELEM)} - update ELEM')

    idx = np.where(act)[0]
    zone = p[idx, 0].astype(int)
    nh = g1[idx, 2]
    ab = p[idx, 12:45]

    def ion(el, stage):
        li = ELEM.index(el)
        return np.array([float(g2[c * ne + li][stage])
                         if len(g2[c * ne + li]) > stage else 0.0
                         for c in idx]) * ABUND[el]

    d = {'AV': pr[idx, 0], 'r': r[idx], 'zone': zone,
         'Tgas': g1[idx, 0], 'Tdust': pr[idx, 6],
         'e-': g1[idx, 1]}
    for key, el, st in [('H+', 'H', 1), ('He+', 'He', 1), ('He++', 'He', 2),
                        ('C+', 'C', 1), ('C++', 'C', 2), ('O+', 'O', 1),
                        ('O++', 'O', 2), ('Mg+', 'Mg', 1)]:
        d[key] = ion(el, st) * nh
    pdr = zone == 1
    for key, el in [('H', 'H'), ('C', 'C'), ('O', 'O')]:
        d[key] = np.where(pdr, ab[:, SPEC.index(key)], ion(el, 0)) * nh
    for key in ['H2', 'CO', 'OH', 'H2O', 'CH', 'HCO+', 'H3+']:
        d[key] = np.where(pdr, ab[:, SPEC.index(key)], 0.0) * nh
    d['A_front'] = d['AV'][pdr].min()
    return d


def read_ref(path, a_front):
    a = np.array([ln.split() for ln in open(path) if len(ln.split()) >= 41],
                 float)
    nh = a[:, 6]
    d = {'AV': a_front + a[:, 2], 'Tgas': a[:, 3], 'Tdust': a[:, 4]}
    for s in SPEC:
        d[s] = a[:, 8 + SPEC.index(s)] * nh
    return d


def median_profile(x, y, edges, nmin=3):
    xc, med = [], []
    for a, b in zip(edges[:-1], edges[1:]):
        s = (x >= a) & (x < b)
        if s.sum() < nmin:
            continue
        xc.append(np.exp(np.log(x[s]).mean()))
        med.append(np.median(y[s]))
    xc, med = np.array(xc), np.array(med)
    return xc, np.where(med > 0, med, np.nan)


def place_labels(ax, inside, margin, ylo, yhi):
    """Inside labels sit on their curve; margin labels are stacked in the right
    margin at their curve's last value, pushed apart where they collide and
    tied back to the curve by a short leader."""
    for text, col, x, y in inside:
        if np.isfinite(y):
            ax.text(x, y, text, color=col, fontsize=11, fontweight='bold',
                    ha='center', va='center')
    lab = sorted([[t, c, np.log10(y)] for t, c, y in margin if np.isfinite(y)],
                 key=lambda q: q[2])
    gap = 0.075 * np.log10(yhi / ylo)
    pos = [q[2] for q in lab]
    for i in range(1, len(pos)):
        pos[i] = max(pos[i], pos[i - 1] + gap)
    over = pos[-1] - (np.log10(yhi) - 0.3) if pos else 0
    if over > 0:
        pos = [v - over for v in pos]
    for i in range(len(pos) - 2, -1, -1):
        pos[i] = min(pos[i], pos[i + 1] - gap)
    trans = ax.get_yaxis_transform()
    for (text, col, ly), py in zip(lab, pos):
        ax.annotate(text, xy=(1.0, 10 ** ly), xycoords=trans,
                    xytext=(1.09, 10 ** py), textcoords=trans, color=col,
                    fontsize=11, fontweight='bold', ha='left', va='center',
                    annotation_clip=False,
                    arrowprops=dict(arrowstyle='-', color=col, lw=0.7,
                                    shrinkA=1, shrinkB=0))


def draw(run, ref, name, spec, ylab, ylim, outdir, model_label):
    fig, ax = plt.subplots(figsize=(4.6, 4.4))
    # the ionized gas has 165 cells, the PDR 15039: coarser bins in front
    af = run['A_front']
    edges = np.concatenate([np.geomspace(0.04, af * 0.999, 9),
                            np.geomspace(af * 0.999, 3.2, 32)[1:]])
    inside, margin = [], []
    for key, col, where in spec:
        xc, med = median_profile(run['AV'], run[key], edges)
        ax.plot(xc, med, color=col, ls='-', lw=1.6)
        if key in ref:
            rv = np.where(ref[key] > 0, ref[key], np.nan)
            ax.plot(ref['AV'], rv, color=col, ls='--', lw=1.3)
        good = np.isfinite(med)
        if where == 'R':
            margin.append((TEX[key], col, med[good][-1] if good.any()
                           else np.nan))
        else:
            xa, nudge = where
            ya = np.exp(np.interp(np.log(xa), np.log(xc[good]),
                                  np.log(med[good]))) if good.any() else np.nan
            inside.append((TEX[key], col, xa, ya * 10 ** nudge))

    ax.set_xscale('log')
    ax.set_yscale('log')
    ax.set_xlim(0.04, 3.2)
    ax.set_ylim(*ylim)
    ax.xaxis.set_major_locator(FixedLocator([0.05, 0.1, 0.2, 0.5, 1, 2, 3]))
    ax.xaxis.set_major_formatter(FuncFormatter(lambda v, _: f'{v:g}'))
    ax.xaxis.set_minor_locator(LogLocator(base=10, subs=np.arange(2, 10) * .1,
                                          numticks=30))
    ax.xaxis.set_minor_formatter(NullFormatter())
    dec = np.log10(ylim[1] / ylim[0])
    ax.yaxis.set_major_locator(LogLocator(base=100 if dec > 9 else 10,
                                          numticks=40))
    ax.yaxis.set_minor_locator(LogLocator(base=10, subs=(1.0,) if dec > 9
                                          else np.arange(2, 10) * .1,
                                          numticks=80))
    ax.yaxis.set_minor_formatter(NullFormatter())
    ax.set_xlabel(r'$A_{V,\mathrm{eff}}$ from the star [mag]')
    ax.set_ylabel(ylab)

    ax.axvline(af, color='0.55', lw=0.8, ls=':')
    ax.text(af / 1.1, ylim[0] * 2.5, r'H$\,$II', ha='right', va='bottom',
            fontsize=10, color='0.35')
    ax.text(af * 1.1, ylim[0] * 2.5, 'PDR', ha='left', va='bottom',
            fontsize=10, color='0.35')
    place_labels(ax, inside, margin, *ylim)

    top = ax.twiny()
    top.set_xscale('log')
    top.set_xlim(ax.get_xlim())
    edges_r = np.arange(0.0, 19.8, 0.5)
    rc, avr = median_profile(run['r'], run['AV'], edges_r)
    ok = np.isfinite(avr)
    rt = np.array([1, 2, 3, 5, 10, 15])
    top.xaxis.set_major_locator(FixedLocator(np.interp(rt, rc[ok], avr[ok])))
    top.xaxis.set_major_formatter(FixedFormatter([f'{v:g}' for v in rt]))
    top.xaxis.set_minor_locator(FixedLocator([]))
    top.tick_params(axis='x', direction='in')
    top.set_xlabel(r'distance from the star $r$ [pc]')

    ax.legend([Line2D([], [], color='k', ls='-', lw=1.6),
               Line2D([], [], color='k', ls='--', lw=1.3)],
              [model_label, '3D-PDR reference'], loc='upper center',
              bbox_to_anchor=(0.5, -0.13), ncol=2, handlelength=2.4,
              columnspacing=1.6)
    for ext in ('png', 'pdf', 'svg'):
        fig.savefig(os.path.join(outdir, f'roellig_{name}.{ext}'),
                    dpi=240 if ext == 'png' else None)
    plt.close(fig)


def main():
    run_dir, ref_path, outdir = sys.argv[1:4]
    model_label = sys.argv[4] if len(sys.argv) > 4 else 'MOCASSIN + 3D-PDR'
    os.makedirs(outdir, exist_ok=True)
    style()
    run = read_run(run_dir)
    ref = read_ref(ref_path, run['A_front'])
    print(f"{len(run['AV'])} active cells, {int((run['zone'] == 1).sum())} "
          f"PDR; front at A_V = {run['A_front']:.4f}; reference ends at "
          f"{ref['AV'].max():.3f}")
    draw(run, ref, 'chemistry', CHEM, r'$n(i)$ [cm$^{-3}$]', (1e-16, 1e3),
         outdir, model_label)
    draw(run, ref, 'ions', IONS, r'$n(i)$ [cm$^{-3}$]', (1e-12, 1e3),
         outdir, model_label)
    draw(run, ref, 'temperatures', TEMP, r'$T$ [K]', (5, 3e4), outdir,
         model_label)


if __name__ == '__main__':
    main()
