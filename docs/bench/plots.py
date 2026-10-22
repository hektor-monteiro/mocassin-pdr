#!/usr/bin/env python3
"""Stage B of the benchmark pages: the figures, drawn from docs/bench/data/ alone.

    python docs/bench/plots.py [OUTDIR]          # default docs/benchmarks/_generated/

For every product directory of docs/bench/data/ (one with a profiles_av.csv, written by reduce.py)
writes OUTDIR/<product>_<panel>.svg:

    temperatures  T_gas and T_dust
    ions          n_e/n_H and the ionization fractions of H, He, C and O
    chemistry     H, H2, C, O, CO, OH, H2O, CH, HCO+ and H3+ per hydrogen nucleus
    h2_solomon    the H2 photodissociation rate per molecule
    h2_heating    the H2 heating terms over MOCASSIN's heating

in the style of the published comparison pages (tools/d260_roellig.py, tools/h013_figures.py; Roellig
et al. 2007): one log-log panel against A_V from the star, MOCASSIN's median of the cells in each A_V
bin (solid) with the 16th-84th percentile band, Cloudy's zones dashed, the radius on the upper axis.
The SVG is deterministic: fixed hash salt, no date. Needs numpy and matplotlib only.
"""
import csv
import json
import os
import sys

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt                                    # noqa: E402
from matplotlib.lines import Line2D                                # noqa: E402
from matplotlib.patches import Patch                               # noqa: E402
from matplotlib.ticker import (LogLocator, NullFormatter, FixedLocator,   # noqa: E402
                               FixedFormatter, FuncFormatter)

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
DATA = os.path.join(HERE, 'data')
DEFAULT_OUT = os.path.join(REPO, 'docs', 'benchmarks', '_generated')

# colours and labels of tools/d260_roellig.py
TEMP = [('Te', '#CC3311', r'$T_\mathrm{gas}$'), ('Tdust', '#0077BB', r'$T_\mathrm{dust}$')]
IONS = [('ne_nH', '#000000', r'$n_e/n_\mathrm{H}$'), ('x_H+', '#CC3311', r'H$^{+}$'),
        ('x_He+', '#EE7733', r'He$^{+}$'), ('x_He2+', '#AA7700', r'He$^{2+}$'),
        ('x_C+', '#0077BB', r'C$^{+}$'), ('x_C2+', '#33BBEE', r'C$^{2+}$'),
        ('x_O+', '#009988', r'O$^{+}$'), ('x_O2+', '#EE3377', r'O$^{2+}$')]
CHEM = [('H', '#000000', 'H'), ('H2', '#CC3311', r'H$_2$'), ('C', '#0077BB', 'C'), ('O', '#EE3377', 'O'),
        ('CO', '#33BBEE', 'CO'), ('OH', '#009988', 'OH'), ('H2O', '#AA7700', r'H$_2$O'),
        ('CH', '#7A5195', 'CH'), ('HCO+', '#882255', r'HCO$^{+}$'), ('H3+', '#EE7733', r'H$_3^{+}$')]
HEAT = [('formation', 'h2heat_form', 'pdrheat_form', '#117733'),
        ('dissociation', 'h2heat_diss', 'pdrheat_diss', '#0077BB'),
        ('collisions in X / FUV pumping', 'h2heat_coll', 'pdrheat_pump', '#CC3311')]
RLADDER = [0.002, 0.005, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 3, 5, 10, 15, 20, 30, 50, 100]
XTICKS = [0.001, 0.002, 0.005, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 3]


def style():
    """tools/d260_roellig.py style, and a fixed SVG hash salt so that the files do not change between builds"""
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
        'svg.hashsalt': 'mocassin-pdr-docs', 'svg.fonttype': 'path',
    })


# ------------------------------------------------------------------------------------------- data
def num(s):
    return float(s) if s.strip() else np.nan


def load(product):
    d = os.path.join(DATA, product)
    prof = {}
    with open(os.path.join(d, 'profiles_av.csv')) as f:
        for r in csv.DictReader(f):
            prof.setdefault(r['quantity'], []).append([num(r[k]) for k in ('av', 'n', 'p16', 'p50', 'p84')])
    prof = {k: np.array(v) for k, v in prof.items()}
    with open(os.path.join(d, 'cloudy_profiles.csv')) as f:
        rows = list(csv.reader(f))
    cl = {h: np.array([num(r[i]) for r in rows[1:]]) for i, h in enumerate(rows[0])}
    with open(os.path.join(d, 'r_av.csv')) as f:
        rav = np.array([[num(r['r_pc']), num(r['av'])] for r in csv.DictReader(f)])
    with open(os.path.join(d, 'runcard.json')) as f:
        card = json.load(f)
    return prof, cl, rav, card


def pos(y):
    return np.where(np.asarray(y) > 0, y, np.nan)


# ------------------------------------------------------------------------------------------ panels
def axes(ax, card, rav, x0, x1, ylab):
    """the A_V axis, the front, and the radius on the upper axis (d260_roellig draw)"""
    ax.set_xscale('log')
    ax.set_yscale('log')
    ax.set_xlim(x0, x1)
    ax.xaxis.set_major_locator(FixedLocator([v for v in XTICKS if x0 <= v <= x1]))
    ax.xaxis.set_major_formatter(FuncFormatter(lambda v, _: f'{v:g}'))
    ax.xaxis.set_minor_locator(LogLocator(base=10, subs=np.arange(2, 10) * .1, numticks=30))
    ax.xaxis.set_minor_formatter(NullFormatter())
    ax.set_xlabel(r'$A_{V,\mathrm{eff}}$ from the star [mag]')
    ax.set_ylabel(ylab)
    af = card['cells']['a_front']
    ax.axvline(af, color='0.55', lw=0.8, ls=':')
    lo = ax.get_ylim()[0]
    ax.text(af / 1.1, lo * 2.5, r'H$\,$II', ha='right', va='bottom', fontsize=10, color='0.35')
    ax.text(af * 1.1, lo * 2.5, 'PDR', ha='left', va='bottom', fontsize=10, color='0.35')
    top = ax.twiny()
    top.set_xscale('log')
    top.set_xlim(ax.get_xlim())
    r0, r1 = card['cells']['r_min_pc'], card['cells']['r_max_pc']
    rt = [v for v in RLADDER if r0 <= v <= r1]
    if len(rt) < 3:
        rt = list(np.geomspace(r0 * 1.02, r1 * 0.98, 5))
    ok = np.isfinite(rav[:, 1])
    top.xaxis.set_major_locator(FixedLocator(np.interp(rt, rav[ok, 0], rav[ok, 1])))
    top.xaxis.set_major_formatter(FixedFormatter([f'{v:.3g}' for v in rt]))
    top.xaxis.set_minor_locator(FixedLocator([]))
    top.tick_params(axis='x', direction='in')
    top.set_xlabel(r'distance from the star $r$ [pc]')


def yticks(ax, lo, hi):
    ax.set_ylim(lo, hi)
    dec = np.log10(hi / lo)
    ax.yaxis.set_major_locator(LogLocator(base=100 if dec > 9 else 10, numticks=40))
    ax.yaxis.set_minor_locator(LogLocator(base=10, subs=(1.0,) if dec > 9 else np.arange(2, 10) * .1, numticks=80))
    ax.yaxis.set_minor_formatter(NullFormatter())


def margin_labels(ax, labels, ylo, yhi):
    """labels stacked in the right margin at their curve's last value, pushed apart where they collide and
    tied back to the curve by a short leader (d260_roellig place_labels)"""
    lab = sorted([[t, c, np.log10(y)] for t, c, y in labels if np.isfinite(y) and ylo < y < yhi], key=lambda q: q[2])
    if not lab:
        return
    gap = 0.075 * np.log10(yhi / ylo)
    p = [q[2] for q in lab]
    for i in range(1, len(p)):
        p[i] = max(p[i], p[i - 1] + gap)
    over = p[-1] - (np.log10(yhi) - 0.3)
    if over > 0:
        p = [v - over for v in p]
    for i in range(len(p) - 2, -1, -1):
        p[i] = min(p[i], p[i + 1] - gap)
    tr = ax.get_yaxis_transform()
    for (text, col, ly), py in zip(lab, p):
        ax.annotate(text, xy=(1.0, 10 ** ly), xycoords=tr, xytext=(1.09, 10 ** py), textcoords=tr, color=col,
                    fontsize=11, fontweight='bold', ha='left', va='center', annotation_clip=False,
                    arrowprops=dict(arrowstyle='-', color=col, lw=0.7, shrinkA=1, shrinkB=0))


def legend(ax, card, extra=(), ncol=2):
    h = [(Line2D([], [], color='k', ls='-', lw=1.6), card.get('model_label', 'MOCASSIN-PDR') + ', median'),
         (Patch(color='k', alpha=0.18, lw=0), '16th-84th percentile'),
         (Line2D([], [], color='k', ls='--', lw=1.3), card.get('cloudy_label', 'Cloudy'))] + list(extra)
    ax.legend([x[0] for x in h], [x[1] for x in h], loc='upper center', bbox_to_anchor=(0.5, -0.13), ncol=ncol,
              handlelength=2.4, columnspacing=1.4, fontsize=9)


def xrange_(card, cl):
    """the A_V range both curves occupy, the lower edge the model's (d260_roellig auto_xlim)"""
    return card['cells']['av_min'] / 1.05, max(card['cells']['av_max'], float(np.nanmax(cl['av']))) * 1.05


def curve(ax, prof, cl, key, col):
    """MOCASSIN's median and band, Cloudy dashed; returns the median (A_V, value)"""
    if key not in prof:
        return np.array([]), np.array([])
    p = prof[key]
    lo, hi = pos(p[:, 2]), pos(p[:, 4])
    band = np.isfinite(lo) & np.isfinite(hi)
    ax.fill_between(p[:, 0], np.where(band, lo, np.nan), np.where(band, hi, np.nan), color=col, alpha=0.18, lw=0)
    med = pos(p[:, 3])
    ax.plot(p[:, 0], med, color=col, ls='-', lw=1.6)
    if key in cl:
        ax.plot(cl['av'], pos(cl[key]), color=col, ls='--', lw=1.3)
    return p[:, 0], med


def species_panel(prof, cl, rav, card, spec, ylab, ylim):
    fig, ax = plt.subplots(figsize=(4.6, 4.4))
    x0, x1 = xrange_(card, cl)
    yticks(ax, *ylim)
    margin = []
    for key, col, tex in spec:
        x, med = curve(ax, prof, cl, key, col)
        # a curve that reaches the right edge inside the panel is labelled in the margin; one that leaves
        # the panel earlier, at the last point it has inside it
        inside = np.where(np.isfinite(med) & (med > ylim[0]) & (med < ylim[1]))[0]
        if not len(inside):
            continue
        if inside[-1] == len(med) - 1:
            margin.append((tex, col, med[-1]))
        else:
            j = inside[-1]
            ax.text(x[j] * 1.04, med[j] * 1.5, tex, color=col, fontsize=10.5, fontweight='bold', ha='left', va='bottom')
    axes(ax, card, rav, x0, x1, ylab)
    margin_labels(ax, margin, *ylim)
    legend(ax, card)
    return fig


def span(prof, cl, keys, floor):
    """the y range of the medians and Cloudy's values inside the model's A_V range, at most `floor` decades"""
    v = []
    a0, a1 = None, None
    for k in keys:
        if k in prof:
            v += list(pos(prof[k][:, 3]))
            a0 = prof[k][0, 0] if a0 is None else min(a0, prof[k][0, 0])
            a1 = prof[k][-1, 0] if a1 is None else max(a1, prof[k][-1, 0])
    for k in keys:
        if k in cl and a0 is not None:
            s = (cl['av'] >= a0) & (cl['av'] <= a1)
            v += list(pos(cl[k][s]))
    v = np.array(v, float)
    v = v[np.isfinite(v)]
    hi = 10 ** np.ceil(np.log10(v.max() * 1.5))
    lo = max(10 ** np.floor(np.log10(v.min())), hi * 10 ** -floor)
    return lo, hi


def temperatures(prof, cl, rav, card):
    v = np.concatenate([pos(prof[k][:, 3]) for k, _, _ in TEMP] + [pos(cl[k]) for k, _, _ in TEMP if k in cl])
    v = v[np.isfinite(v)]
    return species_panel(prof, cl, rav, card, TEMP, r'$T$ [K]', (max(1., 0.5 * v.min()), 2 * v.max()))


def ions(prof, cl, rav, card):
    lo, _ = span(prof, cl, [k for k, _, _ in IONS], 10)
    return species_panel(prof, cl, rav, card, IONS, r'$n(X^{i})/n(X)$;  $n_e/n_\mathrm{H}$', (lo, 3.))


def chemistry(prof, cl, rav, card):
    lo, _ = span(prof, cl, [k for k, _, _ in CHEM], 14)
    return species_panel(prof, cl, rav, card, CHEM, r'$n(i)/n_\mathrm{H}$', (lo, 3.))


def solomon(prof, cl, rav, card):
    fig, ax = plt.subplots(figsize=(4.6, 4.4))
    x0, x1 = xrange_(card, cl)
    v = [np.nanmax(pos(prof['sol_h2'][:, 4]))]
    if 'sol_h2' in cl:
        s = (cl['av'] >= x0) & (cl['av'] <= x1)
        v.append(np.nanmax(pos(cl['sol_h2'][s])))
    hi = 3 * max(v)
    yticks(ax, hi * 1e-10, hi)
    curve(ax, prof, cl, 'sol_h2', '#7A5195')
    axes(ax, card, rav, x0, x1, r'H$_2$ photodissociation rate per molecule [s$^{-1}$]')
    legend(ax, card)
    return fig


def heating(prof, cl, rav, card):
    """the level model's heating terms (used) and 3D-PDR's (kept beside them) over MOCASSIN's heating
    (tools/h013_figures.py heating); where the collisional term's median is negative H2 cools the gas,
    drawn thin at its size"""
    fig, ax = plt.subplots(figsize=(4.6, 4.4))
    x0, x1 = xrange_(card, cl)
    yticks(ax, 1e-5, 1.)
    for name, lev, pdr, col in HEAT:
        p = prof[lev]
        band = np.isfinite(pos(p[:, 2])) & np.isfinite(pos(p[:, 4]))
        ax.fill_between(p[:, 0], np.where(band, p[:, 2], np.nan), np.where(band, p[:, 4], np.nan),
                        color=col, alpha=0.18, lw=0)
        ax.plot(p[:, 0], pos(p[:, 3]), color=col, ls='-', lw=1.7)
        if (p[:, 3] < 0).any():
            ax.plot(p[:, 0], pos(-p[:, 3]), color=col, ls='-', lw=0.8, alpha=0.8)
        q = prof[pdr]
        ax.plot(q[:, 0], pos(q[:, 3]), color=col, ls='--', lw=1.3)
    extra = [(Line2D([], [], color=col, lw=2.2), name) for name, _, _, col in HEAT]
    if 'h2dH_frac' in cl:
        ax.plot(cl['av'], pos(cl['h2dH_frac']), color='k', ls='-.', lw=1.2)
        extra.append((Line2D([], [], color='k', ls='-.', lw=1.2), 'Cloudy: H$_2$ photodissociation'))
    axes(ax, card, rav, x0, x1, "fraction of MOCASSIN's heating")
    h = [(Line2D([], [], color='k', ls='-', lw=1.7), 'level model (used), median'),
         (Patch(color='k', alpha=0.18, lw=0), '16th-84th percentile'),
         (Line2D([], [], color='k', ls='--', lw=1.3), "3D-PDR's terms (kept), median"),
         (Line2D([], [], color='k', ls='-', lw=0.8), 'collisions cooling, |median|')] + extra
    ax.legend([x[0] for x in h], [x[1] for x in h], loc='upper center', bbox_to_anchor=(0.5, -0.13), ncol=2,
              handlelength=2.4, columnspacing=1.2, fontsize=9)
    return fig


PANELS = [('temperatures', temperatures, None), ('ions', ions, None), ('chemistry', chemistry, None),
          ('h2_solomon', solomon, 'sol_h2'), ('h2_heating', heating, 'h2heat_form')]


def main():
    out = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUT
    os.makedirs(out, exist_ok=True)
    style()
    products = sorted(p for p in os.listdir(DATA) if os.path.exists(os.path.join(DATA, p, 'profiles_av.csv')))
    for product in products:
        prof, cl, rav, card = load(product)
        for name, fn, need in PANELS:
            if need is not None and need not in prof:
                continue
            fig = fn(prof, cl, rav, card)
            path = os.path.join(out, f'{product}_{name}.svg')
            fig.savefig(path, format='svg', metadata={'Date': None})
            plt.close(fig)
            print('written', path)


if __name__ == '__main__':
    main()
