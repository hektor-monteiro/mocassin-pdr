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
  - molecules everywhere, and neutral H, C, O in PDR cells: the chemistry
    (pdrGrid.out), which is solved in the ionized cells too.
  - T_gas: MOCASSIN (grid1.out). T_dust: MOCASSIN's grains (pdrRad.out).

Placing the reference. A 3D-PDR slab starts at A_V = 0 at its own lit face, and
D-257 set that face's field to what this model delivers to its first PDR cell.
So its face belongs at our ionization front, and it is drawn at
A_V = A_front + A_V,ref with A_front the smallest PDR-cell A_V. Check: the
shifted slab then ends at 2.93 against our outer edge at 3.00, and the two
extinction-per-length figures are 0.165 and 0.169 mag/pc.

The upper axis is the model's radius: each tick sits at the median A_V of the
active cells at that distance from the star.

With --cloudy the reference is a Cloudy model instead (D-264): the argument is
the save-file prefix, and its A_V is Cloudy's own AV(point) from the inner face,
i.e. measured from the star like ours, so no alignment shift is applied.

Needs numpy + matplotlib (the `astro` conda env):
    ~/miniforge3/envs/astro/bin/python tools/d260_roellig.py \
        <run-dir> <reference.pdr.fin> <out-dir> [model-label]
    ~/miniforge3/envs/astro/bin/python tools/d260_roellig.py --cloudy \
        <run-dir> <cloudy-prefix> <out-dir> [model-label]
"""
import os
import re
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
# D-283: plot ranges and Cloudy's grain size law, overridable on the command
# line (--xlim=lo,hi --rticks=a,b,.. --grains=amin,amax,slope).
# D-319: the defaults USED to be hiipdr's two constants, (0.04, 3.2), and the
# pn150k figures inherited them - drawing an axis to A_V 3 for a model that
# ends at 0.67, so the model occupied the left two thirds of the panel and the
# inside labels at A_V < 0.04 fell off the left edge entirely. The run knows
# its own extent; a constant cannot track it. Both are now derived from the
# data unless given, and the explicit options still override.
XLIM = None
RTICKS = None


def auto_xlim(run, ref):
    """The A_V range both curves actually occupy, padded by 5%. The reference
    is allowed to start deeper inside than the model's first cell (Cloudy's
    first zone is far thinner than a MOCASSIN cell), so the lower edge follows
    the MODEL - otherwise one code's zoning sets the framing for both."""
    lo = float(np.nanmin(run['AV'])) / 1.05
    hi = max(float(np.nanmax(run['AV'])),
             float(np.nanmax(ref['AV']))) * 1.05
    return lo, hi


# a ladder of round distances; the ticks are those that fall inside the
# model's own radial extent, so the top axis is never extrapolated
RLADDER = [0.002, 0.005, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5,
           1, 2, 3, 5, 10, 15, 20, 30, 50, 100]


def auto_rticks(run):
    r0, r1 = float(np.nanmin(run['r'])), float(np.nanmax(run['r']))
    rt = [v for v in RLADDER if r0 <= v <= r1]
    # a decade-and-a-bit span can leave only two or three rungs; fall back to
    # the geometric middle rather than drawing a bare axis
    if len(rt) < 3:
        rt = list(np.geomspace(r0 * 1.02, r1 * 0.98, 5))
    return rt
# D-305: Cloudy's grain size range, which its own output pins down without
# guessing. `save grain temperature` writes one column per bin, and the
# "Average Grain Properties" block in the .out gives the dust-to-gas MASS
# fraction per bin. For MRN a^-3.5 in log bins that mass goes as a^0.5, so the
# constant bin-to-bin ratio fixes amax/amin outright: the 150k model gives
# 1.21604 per bin, i.e. (amax/amin)^0.05, i.e. amax/amin = 50.00 = 0.25/0.005.
# This used to read (0.010, 0.300), a ratio of 30. It matters little for the
# number-weighted mean temperature (0.1%, because both weightings put most of
# the grains in the first bin and the small bins are nearly isothermal) but it
# was wrong, and the range is measurable rather than assumed.
GRAINS = (0.005, 0.25, -3.5)


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


LABELS = ['H', 'He', 'Li', 'Be', 'B', 'C', 'N', 'O', 'F', 'Ne', 'Na', 'Mg',
          'Al', 'Si', 'P', 'S', 'Cl', 'Ar', 'K', 'Ca', 'Sc', 'Ti', 'V', 'Cr',
          'Mn', 'Fe', 'Co', 'Ni', 'Cu', 'Zn']


def read_composition(run):
    """D-283: the switched-on elements, in the order grid2.out writes them, and
    their abundances, from the run's own nebComposition file. ELEM/ABUND above
    were abunV1.in's and are kept only as the fallback."""
    import re
    try:
        inp = open(os.path.join(run, 'input', 'input.in')).read()
        m = re.search(r'^\s*nebComposition\s+"?([^"\s]+)"?', inp, re.M)
        vals = [float(ln.split()[0]) for ln in
                open(os.path.join(run, m.group(1))) if ln.split()][:30]
    except (OSError, AttributeError, ValueError):
        return ELEM, ABUND
    elem = [LABELS[i] for i, v in enumerate(vals) if v > 0]
    return elem, {LABELS[i]: v for i, v in enumerate(vals) if v > 0}


def read_pdrgrid(out, n):
    """pdrGrid.out in either layout, one record per grid point (i,j,k order).

    v2 (D-352): a '# pdrGrid v2' first line, then chiFUV AVeff pdrCool pdrHeat
    pdrHeatPE and the abundances. v1 (before D-352): no header, and a zone flag
    plus the vestigial pdrTgas/pdrTlow/pdrThigh (twice) ahead of the same
    fields - 12 of them. The zone flag is returned for v1 only, for checks;
    the analysis does not use it (read_run)."""
    txt = open(os.path.join(out, 'pdrGrid.out')).read()
    ns = len(SPEC)
    if txt.startswith('# pdrGrid v2'):
        k = 5
        a = np.array(txt.split('\n', 1)[1].split(), float)[:n * (k + ns)]
        a = a.reshape(n, k + ns)
        return dict(chi=a[:, 0], AV=a[:, 1], cool=a[:, 2], heat=a[:, 3],
                    heatPE=a[:, 4], ab=a[:, k:], zone=None)
    k = 12
    a = np.array(txt.split(), float)[:n * (k + ns)].reshape(n, k + ns)
    return dict(chi=a[:, 1], AV=a[:, 2], cool=a[:, 3], heat=a[:, 4],
                heatPE=a[:, 5], ab=a[:, k:], zone=a[:, 0].astype(int))


def read_run(run):
    ELEM, ABUND = read_composition(run)
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
    pg = read_pdrgrid(out, n)
    pr = np.loadtxt(os.path.join(out, 'pdrRad.out'), skiprows=1)
    g2 = [ln.split() for ln in open(os.path.join(out, 'grid2.out'))]
    ne = len(g2) // n
    if ne != len(ELEM):
        raise SystemExit(f'grid2.out has {ne} element blocks, expected '
                         f'{len(ELEM)} - update ELEM')

    idx = np.where(act)[0]
    nh = g1[idx, 2]
    ab = pg['ab'][idx]

    def ion(el, stage):
        li = ELEM.index(el)
        return np.array([float(g2[c * ne + li][stage])
                         if len(g2[c * ne + li]) > stage else 0.0
                         for c in idx]) * ABUND[el]

    d = {'AV': pr[idx, 0], 'r': r[idx],
         'Tgas': g1[idx, 0], 'Tdust': pr[idx, 6],
         'e-': g1[idx, 1]}
    for key, el, st in [('H+', 'H', 1), ('He+', 'He', 1), ('He++', 'He', 2),
                        ('C+', 'C', 1), ('C++', 'C', 2), ('O+', 'O', 1),
                        ('O++', 'O', 2), ('Mg+', 'Mg', 1)]:
        d[key] = ion(el, st) * nh
    # D-352: atoms and ions are MOCASSIN's in every cell - it owns the
    # ionization, and the chemistry's H, C, O are imposed from it (D-162),
    # agreeing to a median 1e-7 (1.2% worst cell, runs/d350-window). This
    # used to switch source on the model's zone flag.
    for key, el in [('H', 'H'), ('C', 'C'), ('O', 'O')]:
        d[key] = ion(el, 0) * nh
    # 'zone' is now an ANALYSIS label, not a model quantity: MOCASSIN's own
    # x(H+) below 0.3, the definition the removed flag latched on
    # (pdrZoneLim). It places the 3D-PDR reference's A_V zero point
    # (A_front) and selects cells in the budget tools; on d350-window it
    # differs from the stored flag in 1 cell of 15204 and gives the same
    # A_front.
    d['zone'] = (ion('H', 1) < 0.3).astype(int)
    pdr = d['zone'] == 1
    # The chemistry is solved in every active cell, ionized gas included
    # (lgChemOnly cells), so the molecules are its answer everywhere. An
    # earlier version zeroed them outside the PDR zone, which drew a gate the
    # model does not have.
    for key in ['H2', 'CO', 'OH', 'H2O', 'CH', 'HCO+', 'H3+']:
        d[key] = ab[:, SPEC.index(key)] * nh
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


def cloudy_grain_ratio(prefix, slope=-3.5):
    """D-319: amax/amin for Cloudy's grains, from Cloudy's own output.

    D-306 established the method for the 150k model and then wrote the answer
    down as a constant, GRAINS - which promptly went stale for hiipdr, whose
    grains are 0.01-0.30 um against the 150k model's 0.005-0.25. The method
    itself needs no constant. The "Average Grain Properties" block prints the
    dust-to-gas MASS fraction per bin; for a power law a^slope in log bins the
    mass per bin goes as a^(slope+4), so the (constant) bin-to-bin ratio R is
    (amax/amin)^((slope+4)/nb) and the span follows.

    Only the RATIO reaches the weights - they are normalised, and scaling both
    edges by the same factor cancels - so the absolute sizes are not needed.
    Returns None if the block is absent, leaving the caller on GRAINS.
    """
    try:
        txt = open(f'{prefix}.out', errors='replace').read()
    except OSError:
        return None
    m = re.findall(r'^ <D/G>:(.*)$', txt, re.M)
    if not m:
        return None
    dg = np.array(m[0].split(), float)
    if len(dg) < 2 or (dg <= 0).any():
        return None
    r = dg[1:] / dg[:-1]
    # a real power law gives a constant ratio; anything else is not this law
    if r.std() / r.mean() > 1e-3:
        return None
    return float(r.mean() ** (len(dg) / (slope + 4)))


def read_cloudy(prefix, amin=None, amax=None, slope=None):
    """A Cloudy model saved with `save species densities`, `save overview` and
    `save grain temperature` (runs/d264-cloudy/hiipdr.in). Densities are
    already n(i) in cm^-3. A_V is Cloudy's AV(point) from the illuminated face,
    which for this sphere is measured from the star, as ours is.

    T_dust: MOCASSIN's Tdust(0,0) is the NUMBER-weighted mean over size bins
    (grainWeight, update_mod.f90), so Cloudy's bins are weighted the same way,
    by the number of grains in each of its equal-log-width bins of the same
    power law."""
    def table(ext):
        with open(f'{prefix}.{ext}') as fh:
            head = fh.readline().lstrip('#').split('\t')
        a = np.loadtxt(f'{prefix}.{ext}', comments='#', delimiter='\t')
        return [h.strip() for h in head], a

    hd, dens = table('dens')
    ho, ovr = table('ovr')
    hg, gt = table('gtemp')
    d = {'depth': dens[:, 0], 'AV': ovr[:, ho.index('AV(point)')],
         'Tgas': ovr[:, ho.index('Te')]}
    for j, name in enumerate(hd[1:], start=1):
        if name:
            d[name] = dens[:, j]
    d['He++'] = d.pop('He+2')
    d['C++'] = d.pop('C+2')
    d['O++'] = d.pop('O+2')
    if amin is None:
        amin, amax, slope = GRAINS
        k = cloudy_grain_ratio(prefix, slope)
        if k is not None:
            amin, amax = 1.0, k
    nb = gt.shape[1] - 1
    edges = np.geomspace(amin, amax, nb + 1)
    w = edges[:-1] ** (slope + 1) - edges[1:] ** (slope + 1)
    d['Tdust'] = gt[:, 1:] @ (w / w.sum())
    return d


def cloudy_as_run(prefix, rin):
    """D-283: a Cloudy model on the model side of a comparison (e.g. Cloudy
    against Cloudy). r from the inner radius plus depth; the front is where
    n(H+) = n(H)."""
    d = read_cloudy(prefix)
    d['r'] = (rin + d['depth']) / PC
    x = np.log(np.maximum(d['H+'], 1e-300)) - np.log(np.maximum(d['H'], 1e-300))
    i = np.where(np.diff(np.sign(x)) != 0)[0][0]
    d['A_front'] = d['AV'][i] + (0 - x[i]) / (x[i + 1] - x[i]) * (d['AV'][i + 1] - d['AV'][i])
    d['zone'] = (d['AV'] >= d['A_front']).astype(int)
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


def draw(run, ref, name, spec, ylab, ylim, outdir, model_label,
         ref_label='3D-PDR reference', prefix='roellig'):
    fig, ax = plt.subplots(figsize=(4.6, 4.4))
    # the ionized gas has 165 cells, the PDR 15039: coarser bins in front
    af = run['A_front']
    x0, x1 = XLIM if XLIM is not None else auto_xlim(run, ref)
    edges = np.concatenate([np.geomspace(x0, af * 0.999, 9),
                            np.geomspace(af * 0.999, x1, 32)[1:]])
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
            # positions were placed for hiipdr (front at A_V 0.4659); keep
            # them at the same place relative to this model's front
            xa = xa * af / 0.4659
            ya = np.exp(np.interp(np.log(xa), np.log(xc[good]),
                                  np.log(med[good]))) if good.any() else np.nan
            inside.append((TEX[key], col, xa, ya * 10 ** nudge))

    ax.set_xscale('log')
    ax.set_yscale('log')
    ax.set_xlim(x0, x1)
    ax.set_ylim(*ylim)
    ax.xaxis.set_major_locator(FixedLocator([v for v in
        [0.001, 0.002, 0.005, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 3]
        if x0 <= v <= x1]))
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
    edges_r = np.linspace(0.0, run['r'].max() * 1.001, 41)
    rt = np.array(RTICKS if RTICKS is not None else auto_rticks(run))
    rc, avr = median_profile(run['r'], run['AV'], edges_r)
    ok = np.isfinite(avr)
    top.xaxis.set_major_locator(FixedLocator(np.interp(rt, rc[ok], avr[ok])))
    top.xaxis.set_major_formatter(FixedFormatter([f'{v:g}' for v in rt]))
    top.xaxis.set_minor_locator(FixedLocator([]))
    top.tick_params(axis='x', direction='in')
    top.set_xlabel(r'distance from the star $r$ [pc]')

    ax.legend([Line2D([], [], color='k', ls='-', lw=1.6),
               Line2D([], [], color='k', ls='--', lw=1.3)],
              [model_label, ref_label], loc='upper center',
              bbox_to_anchor=(0.5, -0.13), ncol=2, handlelength=2.4,
              columnspacing=1.6)
    for ext in ('png', 'pdf', 'svg'):
        fig.savefig(os.path.join(outdir, f'{prefix}_{name}.{ext}'),
                    dpi=240 if ext == 'png' else None)
    plt.close(fig)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    run_dir, ref_path, outdir = args[:3]
    model_label = args[3] if len(args) > 3 else 'MOCASSIN + 3D-PDR'
    cloudy = '--cloudy' in sys.argv
    global XLIM, RTICKS, GRAINS
    opt = {a.split('=')[0]: a.split('=', 1)[1] for a in sys.argv[1:]
           if a.startswith('--') and '=' in a}
    if '--xlim' in opt:
        XLIM = tuple(float(v) for v in opt['--xlim'].split(','))
    if '--rticks' in opt:
        RTICKS = [float(v) for v in opt['--rticks'].split(',')]
    if '--grains' in opt:
        GRAINS = tuple(float(v) for v in opt['--grains'].split(','))
    os.makedirs(outdir, exist_ok=True)
    style()
    if '--model-cloudy-rin' in opt:
        run = cloudy_as_run(run_dir, float(opt['--model-cloudy-rin']))
    else:
        run = read_run(run_dir)
    if cloudy:
        ref = read_cloudy(ref_path)
        kw = dict(ref_label=opt.get('--ref-label', 'Cloudy c25.00'),
                  prefix=opt.get('--prefix', 'cloudy'))
    else:
        ref = read_ref(ref_path, run['A_front'])
        kw = {}
    nh = np.nanmax(run['H'] + 2 * run['H2'] + run['H+'])
    top = max(1e3, 10 ** np.ceil(np.log10(3 * nh)))
    tmax = 1.2 * np.nanmax(run['Tgas'])
    ttop = 3e4 if tmax <= 3e4 else 10 ** np.ceil(np.log10(tmax))
    xr = XLIM if XLIM is not None else auto_xlim(run, ref)
    rr = RTICKS if RTICKS is not None else auto_rticks(run)
    print(f"{len(run['AV'])} active cells, {int((run['zone'] == 1).sum())} "
          f"PDR; front at A_V = {run['A_front']:.4f}; reference A_V "
          f"{ref['AV'].min():.3g}-{ref['AV'].max():.3f}")
    print(f"  A_V axis {xr[0]:.4g}-{xr[1]:.4g} "
          f"({'given' if XLIM is not None else 'from the run'}); "
          f"r ticks {[float(f'{v:g}') for v in rr]} pc "
          f"({'given' if RTICKS is not None else 'from the run'})")
    draw(run, ref, 'chemistry', CHEM, r'$n(i)$ [cm$^{-3}$]', (1e-16, top),
         outdir, model_label, **kw)
    draw(run, ref, 'ions', IONS, r'$n(i)$ [cm$^{-3}$]', (1e-12, top),
         outdir, model_label, **kw)
    draw(run, ref, 'temperatures', TEMP, r'$T$ [K]', (5, ttop), outdir,
         model_label, **kw)


if __name__ == '__main__':
    main()
