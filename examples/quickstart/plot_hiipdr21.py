#!/usr/bin/env python3
"""The quickstart's PDR model, hiipdr21 (the hiipdr benchmark on a 21^3 grid): T_e, hydrogen and carbon
of every cell against A_V from the star, through the H II region, the H/H2 front and the C+/C/CO
transition.

    python3 plot_hiipdr21.py RUN [--out FILE]    # default RUN/hiipdr21.png

RUN is the model's directory (the one holding input/ and output/). Needs numpy and matplotlib, and
tools/mocread.py of the MOCASSIN-PDR repository. The densities follow docs/bench/reduce.py read_run:
atoms and ions are MOCASSIN's (grid2.out), H2 and CO the chemistry's (pdrGrid.out), and
n_H = n(H) + n(H+) + 2 n(H2).
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'tools'))
try:
    from mocread import read_grid, read_pdr, composition
except ImportError:
    print("run this script from the repository's examples/quickstart/")
    sys.exit(1)

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt                                    # noqa: E402


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('run')
    ap.add_argument('--out', default=None, help='the PNG file (default RUN/hiipdr21.png)')
    args = ap.parse_args()
    out = args.out or os.path.join(args.run, 'hiipdr21.png')

    g = read_grid(args.run)
    p = read_pdr(args.run, g)
    a_c = composition(args.run)['C']
    m = g.mask
    nh = g.nH[m]
    n_hp = g.frac('H', 1)[m] * nh
    n_h = g.frac('H', 0)[m] * nh
    n_h2 = p.abundance('H2')[m] * nh
    n_cp = g.frac('C', 1)[m] * a_c * nh
    n_c = g.frac('C', 0)[m] * a_c * nh
    n_co = p.abundance('CO')[m] * nh
    n_tot = n_h + n_hp + 2 * n_h2
    av = p.AV[m]
    k = av > 0

    fig, axs = plt.subplots(3, 1, figsize=(6.4, 8), sharex=True)
    axs[0].scatter(av[k], g.Te[m][k], s=2)
    axs[0].set_yscale('log')
    axs[0].set_ylabel(r'$T_e$ [K]')
    for y, lab in ((n_hp, r'H$^+$'), (n_h, 'H'), (2 * n_h2, r'2 H$_2$')):
        axs[1].scatter(av[k], (y / n_tot)[k], s=2, label=lab)
    axs[1].set_ylabel(r'$n(i)/n_\mathrm{H}$')
    for y, lab in ((n_cp, r'C$^+$'), (n_c, 'C'), (n_co, 'CO')):
        axs[2].scatter(av[k], (y / n_tot)[k], s=2, label=lab)
    axs[2].set_yscale('log')
    axs[2].set_ylabel(r'$n(i)/n_\mathrm{H}$')
    for ax in axs[1:]:
        ax.legend(markerscale=4)
    axs[2].set_xscale('log')
    axs[2].set_xlabel(r'$A_{V,\mathrm{eff}}$ from the star [mag]')
    fig.tight_layout()
    fig.savefig(out, dpi=110)
    print('written', out)

    a, x2 = av[k], (2 * n_h2 / n_tot)[k]
    print(f'A_V: {a.min():.4g} to {a.max():.4g} mag')
    # the median of 2 n(H2)/n_H in 20 log-spaced A_V bins; the first bin above one half
    edges = np.geomspace(a.min(), a.max(), 21)
    front = 'none'
    for i, (lo, hi) in enumerate(zip(edges[:-1], edges[1:])):
        s = (a >= lo) & ((a < hi) if i < len(edges) - 2 else (a <= hi))
        if s.any() and np.median(x2[s]) > 0.5:
            front = f'{lo:.4g} to {hi:.4g} mag'
            break
    print('first A_V bin with 2 n(H2)/n_H > 0.5:', front)


if __name__ == '__main__':
    main()
