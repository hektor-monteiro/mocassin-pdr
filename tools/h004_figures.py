#!/usr/bin/env python3
"""H-004: figures for the pumping comparison with Cloudy, from the arrays
tools/h004_compare.py saves with --save.

    excitation   log10 n(v,J)/g against E/k for one case: Cloudy and ours
    ratio        populations over Cloudy's against E/k for the same case: our
                 solution, and our rates put through Cloudy's scheme

    python tools/h004_figures.py <compare.npz> <out-dir> [case]
"""
import os
import sys

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

HCK = 1.4387769


def style():
    plt.rcParams.update({
        'font.family': 'serif', 'font.serif': ['STIXGeneral', 'DejaVu Serif'],
        'mathtext.fontset': 'stix', 'font.size': 10, 'axes.labelsize': 11,
        'xtick.labelsize': 10, 'ytick.labelsize': 10,
        'axes.linewidth': 0.9, 'lines.linewidth': 1.5,
        'xtick.direction': 'in', 'ytick.direction': 'in',
        'xtick.major.size': 4.5, 'ytick.major.size': 4.5,
        'xtick.minor.size': 2.3, 'ytick.minor.size': 2.3,
        'ytick.right': True, 'xtick.top': True, 'legend.frameon': False,
        'savefig.bbox': 'tight', 'savefig.pad_inches': 0.04,
    })


def main(npz, outdir, case):
    d = np.load(npz)
    J, E = d[case + '__J'], d[case + '__E']
    g = (2*J + 1)*np.where(J % 2 == 1, 3, 1)
    po, pc, pd = d[case + '__ours'], d[case + '__cloudy'], d[case + '__scheme']
    x = E*HCK/1e3
    style()
    os.makedirs(outdir, exist_ok=True)

    fig, ax = plt.subplots(figsize=(5.2, 4.0))
    ax.plot(x, np.log10(pc/g), 'o', ms=5.5, mfc='none', mec='#b3541e', mew=0.9, label='Cloudy')
    ax.plot(x, np.log10(po/g), '.', ms=3.6, color='#1f4e79', label='this work')
    ax.set_xlabel(r'$E(v,J)/k$  [$10^3$ K]')
    ax.set_ylabel(r'$\log_{10}\; n(v,J)\,/\,g\,n({\rm H_2})$')
    ax.minorticks_on()
    ax.legend(loc='upper right', handletextpad=0.2)
    for ext in ('svg', 'png'):
        fig.savefig(os.path.join(outdir, f'h004_excitation_{case}.{ext}'), dpi=200)
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(5.2, 4.0))
    ax.axhline(1., color='0.6', lw=0.8)
    ax.plot(x, po/pc, '.', ms=4.5, color='#1f4e79', label='this work')
    ax.plot(x, pd/pc, 'o', ms=4.2, mfc='none', mec='#b3541e', mew=0.8,
            label="our rates in Cloudy's scheme")
    ax.set_ylim(0.62, 1.22)
    ax.set_xlabel(r'$E(v,J)/k$  [$10^3$ K]')
    ax.set_ylabel(r"population / Cloudy's")
    ax.minorticks_on()
    ax.legend(loc='upper right', handletextpad=0.2)
    for ext in ('svg', 'png'):
        fig.savefig(os.path.join(outdir, f'h004_ratio_{case}.{ext}'), dpi=200)
    plt.close(fig)
    out = (po/pc < 0.62) | (po/pc > 1.22)
    out2 = (pd/pc < 0.62) | (pd/pc > 1.22)
    print(f'{case}: levels outside the ratio panel: this work {out.sum()}, scheme {out2.sum()} of {len(pc)}')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else 'T100_n4_G2')
