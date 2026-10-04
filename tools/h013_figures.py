#!/usr/bin/env python3
"""H-013: stage A against stage B on one fixture, with Cloudy where it has the
quantity, in the style of the Cloudy pages' figures (tools/d260_roellig.py:
one log-log panel against A_V from the star, the median of the active cells
in each log A_V bin, the radius on the upper axis).

    transition   x(H+), x(H) and 2x(H2), fractions of the hydrogen nuclei
    temperature  T_gas
    solomon      the H2 photodissociation rate per molecule each chemistry
                 used: stage A the network's own (h2Cells Sol(chem)), stage B
                 the levels' (Sol(levels)); Cloudy's PHOTON + H2 -> H + H for
                 H2 and H2*, over n(H2) (its saved densities have no H2*)
    lines        4 pi j of 1-0 S(1) 2.12 um, 0-0 S(1) 17.0 um and 0-0 S(0)
                 28.2 um from the level populations; Cloudy's zones
    heating      stage B's H2 heating terms as fractions of MOCASSIN's heating
                 at its balance point (h2Cells, H-012 columns): the levels'
                 (handed over in step 2b) and 3D-PDR's (kept beside them);
                 Cloudy's H2 photodissociation heating fraction

Stage A dotted, stage B solid, Cloudy dashed.

    python tools/h013_figures.py <run A> <run B> <cloudy prefix> <out dir> <tag>
        [--label-a=..] [--label-b=..] [--cloudy-label=..]

Writes h013_<panel>_<tag>.svg/.png. The Cloudy prefix needs .dens, .ovr and
.gtemp (read_cloudy); .h2emis, .H2de, .H2sde and .heat are used where they
exist.
"""
import os
import struct
import sys

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.ticker import (LogLocator, NullFormatter, FixedLocator,
                               FixedFormatter, FuncFormatter)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R                                  # noqa: E402

PC = R.PC
HC = 6.62607015e-27*2.99792458e10                         # h c [erg cm]
LINES = [('1-0 S(1) 2.12 um', (1, 3), (0, 1), 3.47e-7, 'H2 2.12125m', '#CC3311'),
         ('0-0 S(1) 17.0 um', (0, 3), (0, 1), 4.76e-10, 'H2 17.0302m', '#0077BB'),
         ('0-0 S(0) 28.2 um', (0, 2), (0, 0), 2.94e-11, 'H2 28.2111m', '#009988')]
STY = {'A': dict(ls=':', lw=1.7), 'B': dict(ls='-', lw=1.7), 'C': dict(ls='--', lw=1.3)}


def cells(run):
    rows = [l.replace('|', ' ').split() for l in open(os.path.join(run, 'output', 'h2Cells.out'))
            if not l.startswith('#')]
    w = min(len(r) for r in rows)
    return np.array([r[:w] for r in rows], float)


def pops(run):
    f = open(os.path.join(run, 'output', 'h2Pop.bin'), 'rb')
    nc, nl = struct.unpack('2i', f.read(8))
    v = np.frombuffer(f.read(4*nl), np.int32)
    J = np.frombuffer(f.read(4*nl), np.int32)
    E = np.frombuffer(f.read(8*nl), np.float64)
    P = np.frombuffer(f.read(4*nl*nc), np.float32).reshape(nc, nl)
    return {(a, b): i for i, (a, b) in enumerate(zip(v, J))}, E, P


def model(run):
    """read_run's per-cell arrays, with h2Cells.out's rows attached (both are
    the active cells in i,j,k order; checked on the radius)"""
    d = R.read_run(run)
    c = cells(run)
    r = np.sqrt((c[:, 4:7]**2).sum(1))/PC
    if len(r) != len(d['r']) or np.max(np.abs(r - d['r'])) > 1e-4*max(r.max(), 1e-30):
        raise SystemExit(f'{run}: h2Cells.out and the grid files do not line up')
    d['cells'] = c
    nh = d['H'] + d['H+'] + 2*d['H2']
    d['xH'], d['xHp'], d['x2H2'] = d['H']/nh, d['H+']/nh, 2*d['H2']/nh
    lev, E, P = pops(run)
    cid = c[:, 3].astype(int) - 1
    for name, u, l, A, _, _ in LINES:
        d[name] = c[:, 7]*P[cid, lev[u]]*A*HC*(E[lev[u]] - E[lev[l]])
    return d


def table(prefix, ext):
    f = f'{prefix}.{ext}'
    if not os.path.exists(f):
        return None, None
    h = [x.strip() for x in open(f).readline().lstrip('#').rstrip('\n').split('\t')]
    return h, np.loadtxt(f, comments='#', delimiter='\t', ndmin=2)


def cloudy(prefix):
    d = R.read_cloudy(prefix)
    nh = d['H'] + d['H+'] + 2*d['H2']
    d['xH'], d['xHp'], d['x2H2'] = d['H']/nh, d['H+']/nh, 2*d['H2']/nh
    h, e = table(prefix, 'h2emis')
    if h is not None and len(e) == len(d['AV']):
        for name, _, _, _, lab, _ in LINES:
            if lab in h:
                d[name] = e[:, h.index(lab)]
    hg, g = table(prefix, 'H2de')
    hs, s = table(prefix, 'H2sde')
    if hg is not None and 'PHOTON,H2=>H,H' in hg and len(g) == len(d['AV']):
        rate = g[:, hg.index('PHOTON,H2=>H,H')].copy()
        if hs is not None and 'PHOTON,H2*=>H,H' in hs and len(s) == len(d['AV']):
            rate += s[:, hs.index('PHOTON,H2*=>H,H')]
        d['sol'] = rate/np.maximum(d['H2'], 1e-300)
    # save heating: total, then (agent, fraction) pairs above Cloudy's own
    # printing threshold; H2dH is H2 photodissociation heating
    f = f'{prefix}.heat'
    if os.path.exists(f):
        fr = []
        for l in open(f):
            if l.startswith('#'):
                continue
            t = l.rstrip('\n').split('\t')
            v = 0.
            for i in range(5, len(t) - 1, 2):
                if t[i].strip() == 'H2dH':
                    v = float(t[i + 1])
            fr.append(v)
        if len(fr) == len(d['AV']):
            d['h2dH'] = np.array(fr)
    return d


def axes(ax, run, x0, x1, ylab):
    ax.set_xscale('log')
    ax.set_yscale('log')
    ax.set_xlim(x0, x1)
    ax.xaxis.set_major_locator(FixedLocator([v for v in
        [0.001, 0.002, 0.005, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 3] if x0 <= v <= x1]))
    ax.xaxis.set_major_formatter(FuncFormatter(lambda v, _: f'{v:g}'))
    ax.xaxis.set_minor_locator(LogLocator(base=10, subs=np.arange(2, 10)*.1, numticks=30))
    ax.xaxis.set_minor_formatter(NullFormatter())
    ax.set_xlabel(r'$A_{V,\mathrm{eff}}$ from the star [mag]')
    ax.set_ylabel(ylab)
    af = run['A_front']
    ax.axvline(af, color='0.55', lw=0.8, ls=':')
    top = ax.twiny()
    top.set_xscale('log')
    top.set_xlim(ax.get_xlim())
    rt = np.array(R.auto_rticks(run))
    rc, avr = R.median_profile(run['r'], run['AV'], np.linspace(0., run['r'].max()*1.001, 41))
    ok = np.isfinite(avr)
    top.xaxis.set_major_locator(FixedLocator(np.interp(rt, rc[ok], avr[ok])))
    top.xaxis.set_major_formatter(FixedFormatter([f'{v:g}' for v in rt]))
    top.xaxis.set_minor_locator(FixedLocator([]))
    top.tick_params(axis='x', direction='in')
    top.set_xlabel(r'distance from the star $r$ [pc]')


def yticks(ax, lo, hi):
    ax.set_ylim(lo, hi)
    dec = np.log10(hi/lo)
    ax.yaxis.set_major_locator(LogLocator(base=100 if dec > 9 else 10, numticks=40))
    ax.yaxis.set_minor_locator(LogLocator(base=10, subs=(1.0,) if dec > 9 else np.arange(2, 10)*.1,
                                          numticks=80))
    ax.yaxis.set_minor_formatter(NullFormatter())


def label(ax, x, y, text, col):
    if np.isfinite(y):
        ax.text(x, y, text, color=col, fontsize=10.5, fontweight='bold', ha='center', va='center')


def legend_styles(ax, labs, extra=(), ncol=3):
    h = [Line2D([], [], color='k', **STY[k]) for k in labs] + [e[0] for e in extra]
    t = [labs[k] for k in labs] + [e[1] for e in extra]
    ax.legend(h, t, loc='upper center', bbox_to_anchor=(0.5, -0.13), ncol=min(ncol, len(h)),
              handlelength=2.4, columnspacing=1.4, fontsize=9.5)


def save(fig, outdir, name, tag):
    for ext in ('svg', 'png'):
        fig.savefig(os.path.join(outdir, f'h013_{name}_{tag}.{ext}'), dpi=220 if ext == 'png' else None)
    plt.close(fig)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    ra, rb, cpre, outdir, tag = args[:5]
    opt = {a.split('=')[0]: a.split('=', 1)[1] for a in sys.argv[1:] if a.startswith('--') and '=' in a}
    labs = {'A': opt.get('--label-a', 'stage A'), 'B': opt.get('--label-b', 'stage B'),
            'C': opt.get('--cloudy-label', 'Cloudy c25.00')}
    os.makedirs(outdir, exist_ok=True)
    R.style()
    A, B, C = model(ra), model(rb), cloudy(cpre)
    x0, x1 = R.auto_xlim(B, C)
    af = B['A_front']
    edges = np.concatenate([np.geomspace(x0, af*0.999, 9), np.geomspace(af*0.999, x1, 32)[1:]])

    def prof(d, key, pdr=False, sel=None):
        m = np.isfinite(d[key])
        if sel is not None:
            m &= sel
        return R.median_profile(d['AV'][m], d[key][m], edges)

    # ---- the transition
    fig, ax = plt.subplots(figsize=(4.6, 4.4))
    for key, col, txt, xa in (('xHp', '#0077BB', r'H$^{+}$', 0.6), ('xH', '#000000', 'H', 1.6),
                              ('x2H2', '#CC3311', r'2H$_2$', 3.0)):
        xc, ya = prof(A, key)
        ax.plot(xc, ya, color=col, **STY['A'])
        xc, yb = prof(B, key)
        ax.plot(xc, yb, color=col, **STY['B'])
        ax.plot(C['AV'], np.where(C[key] > 0, C[key], np.nan), color=col, **STY['C'])
        g = np.isfinite(yb)
        xl = min(max(af*xa, x0*1.3), x1/1.3)
        label(ax, xl, np.exp(np.interp(np.log(xl), np.log(xc[g]), np.log(yb[g])))*2.2, txt, col)
    axes(ax, B, x0, x1, 'fraction of the hydrogen nuclei')
    yticks(ax, 1e-8, 3.)
    legend_styles(ax, labs)
    save(fig, outdir, 'transition', tag)

    # ---- carbon: C+, C and CO
    fig, ax = plt.subplots(figsize=(4.6, 4.4))
    for d in (A, B, C):
        nh = d['H'] + d['H+'] + 2*d['H2']
        for key in ('C+', 'C', 'CO'):
            d['x' + key] = d[key]/nh
    for key, col, txt, xa in (('xC+', '#0077BB', r'C$^{+}$', 1.3), ('xC', '#000000', 'C', 3.2),
                              ('xCO', '#33BBEE', 'CO', 4.2)):
        xc, ya = prof(A, key)
        ax.plot(xc, ya, color=col, **STY['A'])
        xc, yb = prof(B, key)
        ax.plot(xc, yb, color=col, **STY['B'])
        ax.plot(C['AV'], np.where(C[key] > 0, C[key], np.nan), color=col, **STY['C'])
        g = np.isfinite(yb)
        xl = min(max(af*xa, x0*1.3), x1/1.25)
        label(ax, xl, np.exp(np.interp(np.log(xl), np.log(xc[g]), np.log(yb[g])))*2.5, txt, col)
    axes(ax, B, x0, x1, 'abundance per hydrogen nucleus')
    yticks(ax, 1e-12, 1e-3)
    legend_styles(ax, labs)
    save(fig, outdir, 'carbon', tag)

    # ---- the gas temperature
    fig, ax = plt.subplots(figsize=(4.6, 4.4))
    col = '#CC3311'
    xc, ya = prof(A, 'Tgas')
    ax.plot(xc, ya, color=col, **STY['A'])
    xc, yb = prof(B, 'Tgas')
    ax.plot(xc, yb, color=col, **STY['B'])
    ax.plot(C['AV'], C['Tgas'], color=col, **STY['C'])
    axes(ax, B, x0, x1, r'$T_\mathrm{gas}$ [K]')
    tmax = max(np.nanmax(yb), np.nanmax(C['Tgas']))
    yticks(ax, max(5., 0.5*min(np.nanmin(yb), np.nanmin(C['Tgas']))), 2*tmax)
    legend_styles(ax, labs)
    save(fig, outdir, 'temperature', tag)

    # ---- the H2 photodissociation rate each chemistry used
    fig, ax = plt.subplots(figsize=(4.6, 4.4))
    col = '#7A5195'
    A['solc'] = np.where(A['cells'][:, 10] > 0, A['cells'][:, 10], np.nan)
    B['soll'] = np.where(B['cells'][:, 9] > 0, B['cells'][:, 9], np.nan)
    xc, ya = prof(A, 'solc')
    ax.plot(xc, ya, color=col, **STY['A'])
    xc, yb = prof(B, 'soll')
    ax.plot(xc, yb, color=col, **STY['B'])
    keys = {'A': labs['A'] + ': the network\'s', 'B': labs['B'] + ': the levels\''}
    vals = [np.nanmax(ya), np.nanmax(yb)]
    if 'sol' in C:
        ax.plot(C['AV'], np.where(C['sol'] > 0, C['sol'], np.nan), color=col, **STY['C'])
        keys['C'] = labs['C']
    axes(ax, B, x0, x1, r'H$_2$ photodissociation rate per molecule [s$^{-1}$]')
    hi = 3*max(vals)
    yticks(ax, hi*1e-10, hi)
    legend_styles(ax, keys, ncol=2)
    save(fig, outdir, 'solomon', tag)

    # ---- the H2 lines
    fig, ax = plt.subplots(figsize=(4.6, 4.4))
    top = 0.
    for name, u, l, Aul, clab, col in LINES:
        xc, ya = prof(A, name)
        ax.plot(xc, ya, color=col, **STY['A'])
        xc, yb = prof(B, name)
        ax.plot(xc, yb, color=col, **STY['B'])
        top = max(top, np.nanmax(ya), np.nanmax(yb))
        if name in C:
            ax.plot(C['AV'], np.where(C[name] > 0, C[name], np.nan), color=col, **STY['C'])
            top = max(top, np.nanmax(C[name]))
    axes(ax, B, x0, x1, r'$4\pi j$ [erg s$^{-1}$ cm$^{-3}$]')
    yticks(ax, top*1e-5, top*4)
    legend_styles(ax, {k: labs[k] for k in (('A', 'B', 'C') if LINES[0][0] in C else ('A', 'B'))},
                  extra=[(Line2D([], [], color=col, lw=2.2), name.replace(' um', r' $\mu$m'))
                         for name, _, _, _, _, col in LINES])
    save(fig, outdir, 'lines', tag)

    # ---- the H2 heating, stage B
    c = B['cells']
    if c.shape[1] >= 32:
        fig, ax = plt.subplots(figsize=(4.6, 4.4))
        heat = c[:, 27]
        ok = heat > 0
        terms = [('formation', 21, 24, '#117733'), ('dissociation', 22, 25, '#0077BB'),
                 ('collisions in X / FUV pumping', 23, 26, '#CC3311')]
        for name, il, ip, col in terms:
            B['fl'] = np.where(ok, c[:, il]/np.where(ok, heat, 1.), np.nan)
            B['fp'] = np.where(ok, c[:, ip]/np.where(ok, heat, 1.), np.nan)
            xc, yl = R.median_profile(B['AV'][ok], B['fl'][ok], edges)       # NaN where <= 0
            ax.plot(xc, yl, color=col, ls='-', lw=1.7)
            if il == 23:
                # where the median is negative, H2 cools the gas: its size, thin
                m = []
                for a, b in zip(edges[:-1], edges[1:]):
                    s = ok & (B['AV'] >= a) & (B['AV'] < b)
                    m.append((np.exp(np.log(B['AV'][s]).mean()), np.median(B['fl'][s])) if s.sum() >= 3
                             else (np.nan, np.nan))
                m = np.array(m)
                neg = np.where(m[:, 1] < 0, -m[:, 1], np.nan)
                ax.plot(m[:, 0], neg, color=col, ls='-', lw=0.8, alpha=0.8)
            xc, yp = R.median_profile(B['AV'][ok], B['fp'][ok], edges)
            ax.plot(xc, yp, color=col, ls='--', lw=1.3)
        extra = [(Line2D([], [], color=col, lw=2.2), name) for name, _, _, col in terms]
        if 'h2dH' in C:
            ax.plot(C['AV'], np.where(C['h2dH'] > 0, C['h2dH'], np.nan), color='k', ls='-.', lw=1.2)
            extra.append((Line2D([], [], color='k', ls='-.', lw=1.2), 'Cloudy: photodissociation'))
        axes(ax, B, x0, x1, "fraction of MOCASSIN's heating")
        yticks(ax, 1e-5, 1.)
        ax.legend([Line2D([], [], color='k', ls='-', lw=1.7), Line2D([], [], color='k', ls='--', lw=1.3),
                   Line2D([], [], color='k', ls='-', lw=0.8)] + [e[0] for e in extra],
                  ['the levels (used)', "3D-PDR's (kept)", 'collisions cooling'] + [e[1] for e in extra],
                  loc='upper center', bbox_to_anchor=(0.5, -0.13), ncol=2, handlelength=2.4,
                  columnspacing=1.2, fontsize=9)
        save(fig, outdir, 'heating', tag)
    print(f'{tag}: front A_V {af:.4f}; A_V axis {x0:.4g}-{x1:.4g}; Cloudy has: '
          + ', '.join(k for k in ('sol', 'h2dH') + tuple(n for n, *_ in LINES) if k in C))


if __name__ == '__main__':
    main()
