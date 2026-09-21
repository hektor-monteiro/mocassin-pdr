#!/usr/bin/env python3
"""D-297: what transporting the optically thin diffuse lines does, in profile.

Three panels in the visual language of tools/d260_roellig.py - log A_V from
the star, the ionization front marked, radius on the upper axis - built from
two runs of ONE binary with `MOCASSIN_LINES` the only difference between them:

  (a) the FUV field. Transport off, transport on, Cloudy, and Cloudy with its
      Lya removed. D-291 showed Cloudy attenuates outward line flux by
      continuum opacity alone, so its deep-PDR Lya streams like a 1216 A
      continuum photon and is an artifact; it measured that component at a
      flat 46% of the field, which is what is removed here.
  (b) the ratios. on/off is the channel's own size; on and off against
      corrected Cloudy is what is left of O-02's field half.
  (c) the gas temperature, which is what D-292 claimed line transport
      destroyed.

Nothing here is fitted. The Lya fraction is D-291's measurement of the
reference, not a free parameter, and it is the one number in the figure that
does not come from these two runs.

    ~/miniforge3/envs/astro/bin/python tools/d297_linesfig.py \\
        runs/d296-lines-on runs/d296-lines-off \\
        runs/d288-cloudy-grain/150k runs/d296-lines-on/figs
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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R
import d287_pe as P
import d296_lines as L

PC = R.PC
DRAINE_PER_HABING = L.DRAINE_PER_HABING
LYA_FRAC = L.LYA_FRAC

ON = '#B0431F'      # transport on
OFF = '#A8760C'     # transport off
REF = '#4A4540'     # Cloudy
REF2 = '#8C8378'    # Cloudy, Lya removed


def profile(run, edges):
    """A_V and G0 [Habing] per active cell, binned. pdrFUV.out skips inactive
    cells, so it is already in read_run's order."""
    d = R.read_run(run)
    f = L.fuv(run)
    g0 = f['chi'] * DRAINE_PER_HABING
    xc, med = R.median_profile(d['AV'], g0, edges)
    return d, xc, med


def main(on, off, cloudy, outdir):
    R.style()
    os.makedirs(outdir, exist_ok=True)

    edges = np.geomspace(0.02, 0.80, 34)
    da, xa, ga = profile(on, edges)
    db, xb, gb = profile(off, edges)
    c = P.read_cloudy(cloudy)

    af = float(da['A_front'])
    x0, x1 = 0.03, 0.78

    fig, axes = plt.subplots(1, 3, figsize=(12.2, 4.1))

    # ---------------- (a) the field
    ax = axes[0]
    ax.plot(c['AV'], c['G0'], color=REF, ls='--', lw=1.3)
    ax.plot(c['AV'], c['G0'] * (1 - LYA_FRAC), color=REF2, ls=(0, (1, 1.6)),
            lw=1.3)
    ax.plot(xb, gb, color=OFF, lw=1.6)
    ax.plot(xa, ga, color=ON, lw=1.8)
    ax.set_yscale('log')
    ax.set_ylim(2, 1.2e3)
    ax.set_ylabel(r'$G_0$ [Habing]')
    ax.set_title('(a)  FUV field', fontsize=10.5, loc='left')

    # ---------------- (b) the ratios
    ax = axes[1]
    ok = np.isfinite(ga) & np.isfinite(gb)
    ax.plot(xa[ok], ga[ok] / gb[ok], color=ON, lw=1.8)
    # The Cloudy ratios are drawn only outside the ionization front. Matching
    # two codes in A_V across the H II region compares cells the two do not
    # agree are at the same depth, and the ratio there swings 1.1-2.7 with no
    # physical content - D-297 discards those bins rather than averaging them.
    gcl = np.interp(xa, c['AV'], c['G0']) * (1 - LYA_FRAC)
    pdr = ok & (xa >= af)
    ax.plot(xa[pdr], (ga / gcl)[pdr], color=ON, lw=1.5, ls='-.')
    ax.plot(xb[pdr], (gb / gcl)[pdr], color=OFF, lw=1.5, ls='-.')
    ax.axhline(1.0, color='#9A9284', lw=0.7)
    ax.set_ylim(0.0, 2.0)
    ax.set_ylabel('ratio')
    ax.set_title('(b)  What it buys', fontsize=10.5, loc='left')
    # annotate on the curves, in the paper's manner - no legend box
    j = np.argmin(np.abs(xa - 0.42))
    ax.text(xa[j], (ga[j] / gb[j]) + 0.10, 'on / off', color=ON,
            fontsize=9.5, ha='center')
    ax.text(xa[j], (ga / gcl)[j] + 0.10, 'on / Cloudy$^{*}$', color=ON,
            fontsize=9.5, ha='center')
    ax.text(xa[j], (gb / gcl)[j] - 0.17, 'off / Cloudy$^{*}$', color=OFF,
            fontsize=9.5, ha='center')

    # ---------------- (c) the temperature
    ax = axes[2]
    xt, tb = R.median_profile(db['AV'], db['Tgas'], edges)
    xt2, ta = R.median_profile(da['AV'], da['Tgas'], edges)
    ax.plot(c['AV'], c['Tgas'], color=REF, ls='--', lw=1.3)
    ax.plot(xt, tb, color=OFF, lw=1.6)
    ax.plot(xt2, ta, color=ON, lw=1.8)
    ax.set_yscale('log')
    ax.set_ylim(20, 2.5e4)
    ax.set_ylabel(r'$T_{\mathrm{gas}}$ [K]')
    ax.set_title('(c)  Gas temperature', fontsize=10.5, loc='left')

    for ax in axes:
        ax.set_xscale('log')
        ax.set_xlim(x0, x1)
        ax.xaxis.set_major_locator(FixedLocator(
            [v for v in [0.05, 0.1, 0.2, 0.3, 0.5, 0.7] if x0 <= v <= x1]))
        ax.xaxis.set_major_formatter(FuncFormatter(lambda v, _: f'{v:g}'))
        ax.xaxis.set_minor_locator(
            LogLocator(base=10, subs=np.arange(2, 10) * .1, numticks=30))
        ax.xaxis.set_minor_formatter(NullFormatter())
        ax.set_xlabel(r'$A_{V,\mathrm{eff}}$ from the star [mag]')
        ax.tick_params(which='both', top=False, right=True)
        ax.axvline(af, color='0.55', lw=0.8, ls=':')
        lo, hi = ax.get_ylim()
        yt = lo * (hi / lo) ** 0.035 if ax.get_yscale() == 'log' \
            else lo + 0.035 * (hi - lo)
        ax.text(af / 1.12, yt, r'H$\,$II', ha='right', va='bottom',
                fontsize=9.5, color='0.35')
        ax.text(af * 1.12, yt, 'PDR', ha='left', va='bottom',
                fontsize=9.5, color='0.35')

        top = ax.twiny()
        top.set_xscale('log')
        top.set_xlim(ax.get_xlim())
        edges_r = np.linspace(0.0, da['r'].max() * 1.001, 41)
        rc, avr = R.median_profile(da['r'], da['AV'], edges_r)
        okr = np.isfinite(avr)
        rt = np.array([0.15, 0.2, 0.3, 0.4, 0.6])
        top.xaxis.set_major_locator(
            FixedLocator(np.interp(rt, rc[okr], avr[okr])))
        top.xaxis.set_major_formatter(FixedFormatter([f'{v:g}' for v in rt]))
        top.xaxis.set_minor_locator(FixedLocator([]))
        top.tick_params(axis='x', direction='in')
        top.set_xlabel(r'$r$ [pc]', fontsize=9.5)

    fig.legend([Line2D([], [], color=ON, lw=1.8),
                Line2D([], [], color=OFF, lw=1.6),
                Line2D([], [], color=REF, lw=1.3, ls='--'),
                Line2D([], [], color=REF2, lw=1.3, ls=(0, (1, 1.6)))],
               ['MOCASSIN-PDR, thin lines transported',
                'MOCASSIN-PDR, thin lines discarded',
                'Cloudy c25.00',
                r'Cloudy$^{*}$, Ly$\alpha$ removed (D-291)'],
               loc='lower center', ncol=4, bbox_to_anchor=(0.5, -0.09),
               handlelength=2.4, columnspacing=2.0)
    fig.tight_layout()
    for ext in ('svg', 'png', 'pdf'):
        fig.savefig(os.path.join(outdir, f'lines.{ext}'),
                    dpi=240 if ext == 'png' else None)
    plt.close(fig)
    print('wrote', os.path.join(outdir, 'lines.svg'))
    print('front at A_V %.4f; on/off median %.3f'
          % (af, np.nanmedian((ga / gb)[ok])))


if __name__ == '__main__':
    main(*sys.argv[1:5])
