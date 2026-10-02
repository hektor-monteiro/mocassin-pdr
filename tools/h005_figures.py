#!/usr/bin/env python3
"""H-005: figures for the self-shielding comparison, from the arrays saved by
tools/h005_compare.py --save and tools/h005_cuts.py --save.

    shielding  the shielding of the H2g Solomon rate against N(H2): the model
               (solid), the model run with Cloudy's choices (dashed), Cloudy
               itself at four depths (circles), Draine & Bertoldi 1996 with
               and without its line-overlap factor (dotted)
    columns    level columns at the far face over Cloudy's against level energy

    python tools/h005_figures.py <compare.npz> <cuts.npz> <out-dir>
"""
import os
import sys

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h004_figures import style, HCK      # noqa: E402

BLUE, WARM, GREY = '#1f4e79', '#b3541e', '0.45'


def main(npz, cuts, outdir):
    d = np.load(npz); c = np.load(cuts)['cuts']
    N = d['NH2in']; att = d['att']; zf = d['zf']; zv = d['zv']
    style()
    os.makedirs(outdir, exist_ok=True)
    k = N > 1e12
    fig, ax = plt.subplots(figsize=(5.4, 4.2))
    ax.loglog(N[k], (zv[:, 3]/zv[0, 3]/att)[k], ls='-', color=BLUE, lw=1.7, label='this work')
    ax.loglog(N[k], (zf[:, 3]/zf[0, 3]/att)[k], ls='--', color=WARM, lw=1.4, label="with Cloudy's choices")
    ax.loglog(c[:, 0], c[:, 1], 'o', ms=6, mfc='none', mec=WARM, mew=1.2, label='Cloudy')
    ax.loglog(N[k], d['db96'][k], ls=':', color='k', lw=1.4, label='Draine & Bertoldi 1996')
    ax.loglog(N[k], d['db96no'][k], ls=':', color=GREY, lw=1.2, label='the same, no line overlap')
    ax.set_xlim(1e12, 3e21); ax.set_ylim(2e-6, 2.)
    ax.set_xlabel(r'$N({\rm H_2})$ to the zone  [cm$^{-2}$]')
    ax.set_ylabel(r'Solomon rate of H$_2$ / unshielded')
    ax.legend(loc='lower left', handlelength=2.4, fontsize=9.5)
    for ext in ('svg', 'png'):
        fig.savefig(os.path.join(outdir, f'h005_shielding.{ext}'), dpi=200)
    plt.close(fig)

    E = d['E']; x = E*HCK/1e3
    fig, ax = plt.subplots(figsize=(5.4, 4.2))
    ax.axhline(1., color='0.6', lw=0.8)
    ax.semilogy(x, d['colV']/d['colC'], '.', ms=4.5, color=BLUE, label='this work')
    ax.semilogy(x, d['colF']/d['colC'], 'o', ms=4.0, mfc='none', mec=WARM, mew=0.8, label="with Cloudy's choices")
    ax.set_ylim(0.4, 6.)
    ax.set_yticks([0.5, 1, 2, 3, 5]); ax.set_yticklabels(['0.5', '1', '2', '3', '5'])
    ax.yaxis.set_minor_formatter(matplotlib.ticker.NullFormatter())
    ax.set_xlabel(r'$E(v,J)/k$  [$10^3$ K]')
    ax.set_ylabel(r"level column / Cloudy's")
    ax.legend(loc='lower right', handletextpad=0.2)
    for ext in ('svg', 'png'):
        fig.savefig(os.path.join(outdir, f'h005_columns.{ext}'), dpi=200)
    plt.close(fig)
    rv = d['colV']/d['colC']; rf = d['colF']/d['colC']
    print('columns over Cloudy: voigt min %.3f max %.3f ; federman min %.3f max %.3f' % (rv.min(), rv.max(), rf.min(), rf.max()))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3])
