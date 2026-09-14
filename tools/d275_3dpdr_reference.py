#!/usr/bin/env python3
"""D-275: set up a standalone 3D-PDR reference matched to a coupled hiipdr run.

The slab's inputs are read from the run, not assumed:

  G0        median chiFUV [Draine] of the face cells: the PDR cells within
            0.02 mag of the shallowest PDR-cell A_V. That is the field
            MOCASSIN delivers where the PDR begins.
  AV_fac    A_V per N_H of MOCASSIN's own dust (D-264: 5.177e-22), passed on
            the command line. 3D-PDR multiplies it by its dust-to-gas scale,
            which therefore stays 1.
  length    the slab covers the same A_V span as the model, from the face
            (the A_V the figure script aligns on, d260_roellig.py A_front) to
            the largest active-cell A_V, at the run's n_H.
  zeta, n_H from the run's input.in (pdrZeta, Hdensity).

The depth grid keeps the shape of the validated sec54 grid (D-257): 250 points,
geometric spacing with ratio 1.02533, first step scaled with the length.

Composition is not written here: 3D-PDR takes it from chemfiles/species_reduced.d,
so the target directory's chemfiles must carry the run's C, O, Mg and He.

    python tools/d275_3dpdr_reference.py <run-dir> <target-dir> [AV_fac]
"""
import os
import re
import sys

import numpy as np

PC = 3.0857e18
NPTS, RATIO = 250, 1.0253353


def keyword(text, name):
    m = re.search(rf'^\s*{name}\s+([0-9.eE+-]+)', text, re.M)
    if not m:
        raise SystemExit(f'{name} not found in input.in')
    return float(m.group(1))


def main():
    run, target = sys.argv[1:3]
    av_fac = float(sys.argv[3]) if len(sys.argv) > 3 else 5.177e-22
    out = os.path.join(run, 'output')
    inp = open(os.path.join(run, 'input', 'input.in')).read()
    zeta, nh = keyword(inp, 'pdrZeta'), keyword(inp, 'Hdensity')

    t = open(os.path.join(out, 'grid0.out')).read().split()
    n = int(t[1]) * int(t[2]) * int(t[3])
    off = 7 + int(t[1]) + int(t[2]) + int(t[3])
    act = np.array(t[off:off + n * 3:3], float).astype(int) > 0
    p = np.array(open(os.path.join(out, 'pdrGrid.out')).read().split(),
                 float)[:n * 45].reshape(n, 45)
    zone, chi, av = p[:, 0].astype(int), p[:, 1], p[:, 2]
    pdr = act & (zone == 1)
    a_face = av[pdr].min()
    face = pdr & (av < a_face + 0.02)
    g0 = np.median(chi[face])
    a_edge = av[act].max()
    length = (a_edge - a_face) / (av_fac * nh * PC)

    steps = RATIO ** np.arange(NPTS - 1)
    x = np.concatenate([[0.0], np.cumsum(steps)])
    x *= length / x[-1]

    os.makedirs(os.path.join(target, 'ics'), exist_ok=True)
    os.makedirs(os.path.join(target, 'sims'), exist_ok=True)
    with open(os.path.join(target, 'ics', 'hiipdr.dat'), 'w') as fh:
        for xi in x:
            fh.write(f'{xi:.7E} {0.0:.7E} {0.0:.7E} {nh:.7E}\n')

    tmpl = open(os.path.join(os.path.dirname(__file__), '..', 'runs',
                             'd257-3dpdr-standalone',
                             'params_sec54_G166c.dat')).read()
    subs = [('sec54.dat', 'hiipdr.dat'), ('sec54g166c', 'hiipdr'),
            ('165.56 ', f'{g0:.2f}'.ljust(7)),
            ('5.000E-17', f'{zeta:.3E}'), ('5.34153E-22', f'{av_fac:.5E}')]
    for old, new in subs:
        if old not in tmpl:
            raise SystemExit(f'template changed: {old!r} not found')
        tmpl = tmpl.replace(old, new)
    open(os.path.join(target, 'params.dat'), 'w').write(tmpl)

    print(f'face: {face.sum()} cells, A_V {a_face:.4f}, G0 {g0:.2f} '
          f'(16-84% {np.percentile(chi[face], 16):.1f}-'
          f'{np.percentile(chi[face], 84):.1f})')
    print(f'edge A_V {a_edge:.4f}; slab {length:.3f} pc, N_H '
          f'{length * PC * nh:.4e}; zeta {zeta:.3e}; n_H {nh:g}; '
          f'AV_fac {av_fac:.4e}')


if __name__ == '__main__':
    main()
