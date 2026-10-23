#!/usr/bin/env python3
"""The quickstart's first model, HII40 (the Lexington standard H II region): T_e and the oxygen and
carbon ionization fractions of every cell against its distance from the star, and the strongest
optical line ratios.

    python3 plot_hii40.py RUN [--out FILE]      # default RUN/hii40.png

RUN is the model's directory (the one holding input/ and output/). Needs numpy and matplotlib, and
tools/mocread.py of the MOCASSIN-PDR repository.
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'tools'))
try:
    from mocread import read_grid, read_lines, ion_label
except ImportError:
    print("run this script from the repository's examples/quickstart/")
    sys.exit(1)

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt                                    # noqa: E402

PC = 3.0857e18
# (label, element Z, charge, vacuum windows [A]) as in the Lexington tables
LINES = [('[O III] 4959+5007', 8, 2, [(4957, 4962), (5005, 5010)]),
         ('[O II] 3726+3729', 8, 1, [(3724, 3731)]),
         ('[N II] 6548+6584', 7, 1, [(6546, 6550), (6582, 6587)]),
         ('[S II] 6716+6731', 16, 1, [(6714, 6734)])]


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('run')
    ap.add_argument('--out', default=None, help='the PNG file (default RUN/hii40.png)')
    args = ap.parse_args()
    out = args.out or os.path.join(args.run, 'hii40.png')

    g = read_grid(args.run)
    ln = read_lines(args.run)
    m = g.mask
    r = g.r[m] / PC

    fig, axs = plt.subplots(3, 1, figsize=(6.4, 8), sharex=True)
    axs[0].scatter(r, g.Te[m], s=2)
    axs[0].set_ylabel(r'$T_e$ [K]')
    for el, charges, ax in (('O', (0, 1, 2), axs[1]), ('C', (1, 2, 3), axs[2])):
        for q in charges:
            ax.scatter(r, g.frac(el, q)[m], s=2, label=ion_label(el, q))
        ax.set_ylabel(f'fraction of {el}')
        ax.legend(markerscale=4)
    axs[2].set_xlabel('distance from the star r [pc]')
    fig.tight_layout()
    fig.savefig(out, dpi=110)
    print('written', out)

    print(f'Hbeta: {ln.hbeta:.4g} erg/s')
    for label, z, q, windows in LINES:
        v = sum(ln.sum(z, q, a, b) or 0. for a, b in windows)
        print(f'{label:<18} I/Hbeta = {v:.4g}')


if __name__ == '__main__':
    main()
