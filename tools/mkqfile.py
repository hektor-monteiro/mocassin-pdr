#!/usr/bin/env python3
"""Build a single-species Q file from the principal axes of one material.

An anisotropic material such as graphite comes as one `.nk` file per crystal
axis, with the geometric weights of a randomly oriented grain (1/3 parallel,
2/3 perpendicular). Those are NOT abundances of two grain populations, and
listing them as two species makes MOCASSIN solve a separate temperature for
each - a pure-parallel and a pure-perpendicular grain, neither of which
exists - and report the mean. DEVLOG D-309 measured 44.79 K and 22.45 K in one
cell where the real grain sits at 26.85 K.

The orientation average belongs on the CROSS SECTIONS, which is what Draine's
1/3-2/3 rule means and what Cloudy does (grains_mie.cpp sums cs_abs/cs_sct
over axes with the axis weights). It cannot be done by averaging n and k: Mie
is non-linear, and a naively averaged n,k reproduces only ~0.1 of the correct
Q at 100 um, where the grain radiates. So the averaging is done here, once,
and MOCASSIN reads one species with one temperature.

The output carries a sixth column, Im(m), which MOCASSIN needs for the
Weingartner & Draine photoelectric yield and which a standard Q file does not
have. Without it a Q species gets no yield at all.

    ~/miniforge3/envs/astro/bin/python tools/mkqfile.py \\
        --out dustData/grph-avg.cat --label grph-avg \\
        --sizes runs/d302-trim-on/input/dust_sizes.dat \\
        dustData/grph2-dl.nk:0.6667 dustData/grph1-dl.nk:0.3333
"""
import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from d305_mie import bhmie


def read_nk(path):
    head = open(path).read().splitlines()[1].split()
    a = np.loadtxt(path, skiprows=2)
    o = np.argsort(a[:, 0])
    return {'label': head[0], 'tsub': float(head[1]), 'rho': float(head[2]),
            'vn': float(head[3]), 'msurf': float(head[4]),
            'lam': a[o, 0], 'n': a[o, 1], 'k': a[o, 2]}


def main():
    p = argparse.ArgumentParser()
    p.add_argument('axes', nargs='+', help='file.nk:weight, one per axis')
    p.add_argument('--out', required=True)
    p.add_argument('--label', required=True)
    p.add_argument('--sizes', required=True,
                   help='dust_sizes.dat - the radii the file is tabulated on')
    p.add_argument('--nwav', type=int, default=700)
    p.add_argument('--lmin', type=float, default=1e-3)
    p.add_argument('--lmax', type=float, default=1e4,
                   help='must span the model grid: nuMin=1.001e-5 Ryd is 9104 um')
    args = p.parse_args()

    ax, w = [], []
    for spec in args.axes:
        f, _, ww = spec.rpartition(':')
        ax.append(read_nk(f))
        w.append(float(ww))
    w = np.array(w)
    if len(ax) < 2:
        raise SystemExit('need at least two axes to average')

    ref = ax[0]
    for a in ax[1:]:
        for key in ('tsub', 'rho', 'vn', 'msurf'):
            if a[key] != ref[key]:
                raise SystemExit(
                    f'axes disagree on {key}: {a[key]} vs {ref[key]} - these '
                    f'are not axes of one material')

    rad = np.loadtxt(args.sizes, skiprows=2)[:, 1]
    lam = np.geomspace(args.lmin, args.lmax, args.nwav)

    print(f'{len(ax)} axes, weights {w/w.sum()}')
    print(f'{len(rad)} radii {rad[0]:.4g}-{rad[-1]:.4g} um, '
          f'{len(lam)} wavelengths {lam[0]:.4g}-{lam[-1]:.4g} um')

    Qa = np.zeros((len(rad), len(lam)))
    Qs = np.zeros_like(Qa)
    gC = np.zeros_like(Qa)
    kk = np.zeros(len(lam))
    for a, wi in zip(ax, w):
        n_i = np.interp(lam, a['lam'], a['n'])
        k_i = np.interp(lam, a['lam'], a['k'])
        kk += wi * k_i
        for ir, r in enumerate(rad):
            for il, l in enumerate(lam):
                qe, qs, g = bhmie(min(2 * np.pi * r / l, 100.),
                                  complex(n_i[il], k_i[il]))
                # cross sections, not efficiencies: weight by pi a^2 is a
                # common factor at fixed radius, so Q may be summed directly.
                Qa[ir, il] += wi * (qe - qs)
                Qs[ir, il] += wi * qs
                gC[ir, il] += wi * qs * g
    kk /= w.sum()
    Qa /= w.sum()
    Qsn = Qs / w.sum()
    with np.errstate(invalid='ignore', divide='ignore'):
        gC = np.where(Qs > 0, gC / np.maximum(Qs, 1e-300), 0.)
    Qs = Qsn

    with open(args.out, 'w') as fh:
        fh.write('Q\n')
        fh.write(f" {args.label} {ref['tsub']} {ref['rho']} {ref['vn']} "
                 f"{ref['msurf']}\n")
        axl = ', '.join(f"{a['label']}:{wi/w.sum():.4f}"
                        for a, wi in zip(ax, w))
        fh.write(f'# orientation average of {len(ax)} axes ({axl}), cross '
                 f'sections averaged after Mie, by tools/mkqfile.py\n')
        fh.write('# columns: a(um) lam(um) Qabs Qsca g<cos> Im(m); the 6th is '
                 'for the WD01 photoelectric yield - see doc/dust.md\n')
        fh.write(f"{len(rad):6d} {rad[0]:.8E} {rad[-1]:.8E} = NRAD, a_1, "
                 f"a_NRAD (micron)\n")
        fh.write(f"{len(lam):6d} {lam[-1]:.8E} {lam[0]:.8E} = NWAV, w_1, "
                 f"w_NWAV (micron)\n")
        fh.write('    a(um)   lam(um)     Qabs      Qsca    g<cos>      Im(m)\n')
        for ir, r in enumerate(rad):
            for il in range(len(lam) - 1, -1, -1):
                # Enough digits that the radii match grainRadius exactly:
                # MOCASSIN locates the model radius in this table and
                # interpolates, so a 3-significant-figure radius puts every
                # size slightly off its own grid point.
                fh.write(f' {r:14.8e} {lam[il]:14.8e} {Qa[ir, il]:13.6e} '
                         f'{Qs[ir, il]:13.6e} {gC[ir, il]:13.6e} '
                         f'{kk[il]:13.6e}\n')
    print(f'wrote {args.out}')


if __name__ == '__main__':
    main()
