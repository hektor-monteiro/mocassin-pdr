#!/usr/bin/env python3
"""The tutorial's model, test_Problem (a dense ring in a slab around a hot star): slices of the gas and
PDR state through the star, in the x-y mid-plane (the ring face-on) and the x-z plane (edge-on).

    python3 plot_slices.py RUN [--out-prefix P]    # default RUN/slices: P_xy.png and P_xz.png

RUN is the model's directory (the one holding input/ and output/). Needs numpy and matplotlib, and
tools/mocread.py of the MOCASSIN-PDR repository. The densities follow docs/bench/reduce.py read_run:
atoms and ions are MOCASSIN's (grid2.out), H2 and CO the chemistry's (pdrGrid.out), and
n_H = n(H) + n(H+) + 2 n(H2). The symmetricXYZ octant is mirrored to the full plane; cells outside
the nebula and the cells MOCASSIN flags are left blank.
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'tools'))
try:
    from mocread import read_grid, read_pdr
except ImportError:
    print("run this script from the repository's examples/tutorial/")
    sys.exit(1)

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt                                    # noqa: E402
from matplotlib.colors import LogNorm                              # noqa: E402

PC = 3.0857e18


def mirror(a):
    """a plane of the octant mirrored to the full plane, the cells on the symmetry axes once"""
    a = np.concatenate([np.flip(a[1:], 0), a], 0)
    return np.concatenate([np.flip(a[:, 1:], 1), a], 1)


def axis(x):
    """an octant axis mirrored to the full axis [pc]"""
    return np.concatenate([-np.flip(x[1:]), x]) / PC


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('run')
    ap.add_argument('--out-prefix', default=None, help='the PNG files P_xy.png and P_xz.png (default RUN/slices)')
    args = ap.parse_args()
    prefix = args.out_prefix or os.path.join(args.run, 'slices')

    g = read_grid(args.run)
    p = read_pdr(args.run, g)
    nh = g.nH
    n_h = g.frac('H', 0) * nh
    n_hp = g.frac('H', 1) * nh
    n_h2 = p.abundance('H2') * nh
    n_co = p.abundance('CO') * nh
    n_tot = n_h + n_hp + 2 * n_h2
    with np.errstate(invalid='ignore', divide='ignore'):             # 0/0 outside the nebula
        x_h2 = 2 * n_h2 / n_tot
        x_co = np.maximum(n_co / n_tot, 1e-12)
    # (quantity, label, colour scale, cmap, vmin, vmax); NaN outside g.mask
    panels = [(n_tot, r'$n_\mathrm{H}$ [cm$^{-3}$]', 'log', 'viridis', None, None),
              (g.Te, r'$T_e$ [K]', 'log', 'inferno', None, None),
              (g.frac('H', 1), r'$x(\mathrm{H}^+)$', 'linear', 'viridis', 0., 1.),
              (x_h2, r'$2n(\mathrm{H_2})/n_\mathrm{H}$', 'linear', 'viridis', 0., 1.),
              (x_co, r'$n(\mathrm{CO})/n_\mathrm{H}$', 'log', 'viridis', None, None),
              (p.AV, r'$A_V$ [mag]', 'linear', 'viridis', None, None)]

    planes = [('xy', 'x', 'y', 'z index 0, the x-y mid-plane', lambda a: a[:, :, 0], g.x, g.y),
              ('xz', 'x', 'z', 'y index 0, the x-z plane', lambda a: a[:, 0, :], g.x, g.z)]
    for tag, hn, vn, title, cut, h, v in planes:
        ha, va = axis(h), axis(v)
        ext = [ha.min(), ha.max(), va.min(), va.max()]
        fig, axs = plt.subplots(2, 3, figsize=(10, 6.4))
        for ax, (q, label, scale, cmap, vmin, vmax) in zip(axs.ravel(), panels):
            full = mirror(cut(np.where(g.mask, q, np.nan)))
            norm = LogNorm() if scale == 'log' else None
            im = ax.imshow(full.T, origin='lower', extent=ext, cmap=cmap, norm=norm,
                           vmin=vmin, vmax=vmax)
            fig.colorbar(im, ax=ax)
            ax.set_title(label)
            ax.set_xlabel(f'{hn} [pc]')
            ax.set_ylabel(f'{vn} [pc]')
        fig.suptitle(f'{os.path.basename(os.path.abspath(args.run))}: {title}')
        fig.tight_layout()
        out = f'{prefix}_{tag}.png'
        fig.savefig(out, dpi=110)
        plt.close(fig)
        print(f'{out}: {title}, {hn} {ext[0]:.4g} to {ext[1]:.4g} pc, {vn} {ext[2]:.4g} to {ext[3]:.4g} pc')


if __name__ == '__main__':
    main()
