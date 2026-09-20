#!/usr/bin/env python3
"""D-289: the photoelectric term, depth by depth, against Cloudy.

Three panels in the same visual language as tools/d260_roellig.py, on the
radial axis both codes share:

  (a) the FUV field, G0 in Habing units. MOCASSIN's is a near-constant 0.3 of
      Cloudy's through the PDR because it discards every line photon at
      creation, so Lya - here 3.0x the whole stellar FUV band luminosity -
      never enters the field the grains see (D-287).
  (b) the grain potential, which nothing in this project could read before
      D-288 added it to the per-cell output. Baldwin and WD01 runs and Cloudy.
  (c) the photoelectric heating per hydrogen nucleus.

    ~/miniforge3/envs/astro/bin/python tools/d289_pefig.py \\
        runs/d289-pn150k-wd01 runs/d288-pn150k \\
        runs/d288-cloudy-grain/150k <outdir>
"""
import os
import sys

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import NullFormatter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R
import d288_charge as C

PC = R.PC
MOC = '#B0431F'      # --ion on the page
MOC2 = '#A8760C'     # --dust
REF = '#4A4540'


def shells(r, v, edges):
    xc, med = [], []
    for a, b in zip(edges[:-1], edges[1:]):
        s = (r >= a) & (r < b)
        if s.sum() < 3:
            continue
        xc.append(np.exp(np.log(r[s]).mean()))
        med.append(np.median(v[s]))
    return np.array(xc), np.array(med)


def main(wd01, baldwin, prefix, outdir):
    R.style()
    a = C.read_grain(wd01)
    b = C.read_grain(baldwin)
    c = C.read_cloudy_grain(prefix)

    os.makedirs(outdir, exist_ok=True)
    # from just inside the H+ front outwards: the ionized gas is the other
    # three figures' subject, and MOCASSIN's grain potential runs to 12.5 V
    # there, which would flatten the PDR comparison this figure is for.
    edges = np.geomspace(0.12, 0.61, 24)

    fig, axes = plt.subplots(1, 3, figsize=(11.4, 3.9))

    # ---- (a) the FUV field
    ax = axes[0]
    x, y = shells(a['r'], a['G0'], edges)
    ax.plot(x, y, color=MOC, lw=1.7, label='MOCASSIN-PDR')
    ax.plot(c['r'], c['G0'], color=REF, ls='--', lw=1.3, label='Cloudy c25.00')
    ax.set_yscale('log')
    ax.set_ylabel(r'$G_0$ [Habing]')
    ax.set_ylim(2, 600)
    ax.set_title('(a)  FUV field', fontsize=10.5, loc='left')
    ax.text(0.06, 0.12, r'$\times\,0.3$ at every depth',
            transform=ax.transAxes, fontsize=9.5, color=MOC)

    # ---- (b) the grain potential
    ax = axes[1]
    x, y = shells(a['r'], a['Vg'], edges)
    ax.plot(x, y, color=MOC, lw=1.7, label='MOCASSIN, WD01 yield')
    x2, y2 = shells(b['r'], b['Vg'], edges)
    ax.plot(x2, y2, color=MOC2, lw=1.5, ls=':', label='MOCASSIN, before the fix')
    ax.plot(c['r'], c['Vg'], color=REF, ls='--', lw=1.3, label='Cloudy')
    ax.axhline(0, color='#9A9284', lw=0.7)
    ax.set_ylabel(r'grain potential $V_g$ [V]')
    ax.set_ylim(-2.4, 5.3)
    ax.set_title('(b)  Grain charge', fontsize=10.5, loc='left')

    # ---- (c) the photoelectric heating
    ax = axes[2]
    x, y = shells(a['r'], a['PE'], edges)
    ax.plot(x, y, color=MOC, lw=1.7)
    x2, y2 = shells(b['r'], b['PE'], edges)
    ax.plot(x2, y2, color=MOC2, lw=1.5, ls=':')
    ax.plot(c['r'], c['PE'], color=REF, ls='--', lw=1.3)
    ax.set_yscale('log')
    ax.set_ylabel(r'photoelectric heating [erg s$^{-1}$ per H]')
    ax.set_title('(c)  Heating', fontsize=10.5, loc='left')

    for ax in axes:
        ax.set_xscale('log')
        ax.set_xlim(0.125, 0.61)
        ax.set_xticks([0.15, 0.2, 0.3, 0.4, 0.5, 0.6])
        ax.set_xticklabels(['0.15', '0.2', '0.3', '0.4', '0.5', '0.6'])
        ax.xaxis.set_minor_formatter(NullFormatter())
        ax.set_xlabel(r'distance from the star $r$ [pc]')
        ax.tick_params(which='both', top=True, right=True)

    h = [plt.Line2D([], [], color=MOC, lw=1.7),
         plt.Line2D([], [], color=MOC2, lw=1.5, ls=':'),
         plt.Line2D([], [], color=REF, lw=1.3, ls='--')]
    fig.legend(h, ['MOCASSIN-PDR, charge balance fixed (D-290)',
                   'MOCASSIN-PDR, before the fix (D-289)',
                   'Cloudy c25.00 (Ca, Fe off)'],
               loc='lower center', ncol=3, bbox_to_anchor=(0.5, -0.10),
               handlelength=2.4, columnspacing=2.0)
    fig.tight_layout()
    for ext in ('svg', 'png', 'pdf'):
        fig.savefig(os.path.join(outdir, f'photoelectric.{ext}'),
                    dpi=240 if ext == 'png' else None)
    plt.close(fig)
    print('wrote', os.path.join(outdir, 'photoelectric.svg'))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
