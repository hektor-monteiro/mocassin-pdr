#!/usr/bin/env python3
"""D-307: the bolometric radiation field each code puts on its grains.

D-306 left O-02's dust half as a size-independent factor ~2.9 in absorbed
energy, with MOCASSIN's bolometric field at A_V 0.30 sitting at 1.215x the
UNATTENUATED stellar flux - trapped reprocessed infrared being the leading
explanation. That was one-sided: MOCASSIN's field was measured and Cloudy's
was only inferred from its dust temperature. This measures Cloudy's.

MOCASSIN writes band sums of Jste per cell in pdrRad.out (>1 Ryd, the FUV
0.44-1, 0.01-0.44, and <0.01 Ryd). Cloudy writes the local flux per bin per
zone in a `save ionizing continuum ... every` file - given a low enough
energy floor and no interaction cut, that is the whole mesh, not just the
ionizing range. Both are then normalised by their own unattenuated stellar
flux L/(4 pi r^2) at the same radius, which makes the comparison unit-free
and independent of either code's internal conventions.

    ~/miniforge3/envs/astro/bin/python tools/d307_fieldcmp.py \\
        runs/d302-trim-on runs/d306-cloudy-field/150k
"""
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R
from d287_pe import rows, last_iteration

RYD_ERG = 2.1798723611e-11
EDGES = [1.0, 0.44, 0.01]          # the same cuts grid_mod.f90 uses
NAMES = ['>1Ryd', 'FUV', '.01-.44', '<.01Ryd']


def band(nu):
    """Index of the MOCASSIN band a frequency falls in."""
    return np.where(nu > EDGES[0], 0,
                    np.where(nu >= EDGES[1], 1,
                             np.where(nu >= EDGES[2], 2, 3)))


def cloudy_bands(path):
    """Band-summed ENERGY flux per zone from a save-ionizing-continuum file.

    The `flux` column is photons cm^-2 s^-1 in the bin, so energy is
    flux * nu * Ryd. Streamed, because the file runs to hundreds of MB, and
    only the final iteration is kept - the same trap D-302 found in the .pdr.
    """
    zones, cur, nu, fl = [], None, [], []

    def flush():
        if cur is None or not nu:
            return
        a, f = np.array(nu), np.array(fl)
        e = f * a * RYD_ERG
        b = band(a)
        zones.append((cur, np.array([e[b == k].sum() for k in range(4)])))

    with open(path) as fh:
        for ln in fh:
            if ln.startswith('#save every zone'):
                flush()
                cur = int(ln.split()[-1])
                nu, fl = [], []
                continue
            if ln.startswith('#') or cur is None:
                continue
            s = ln.split('\t')
            if len(s) < 3:
                continue
            try:
                nu.append(float(s[1])); fl.append(float(s[2]))
            except ValueError:
                pass
    flush()
    if not zones:
        raise SystemExit(f'{path}: no zone dumps found')
    z = np.array([q[0] for q in zones])
    E = np.array([q[1] for q in zones])
    brk = np.where(np.diff(z) < 0)[0]      # an iteration restart
    if len(brk):
        z, E = z[brk[-1] + 1:], E[brk[-1] + 1:]
    return z, E


def main(run, prefix):
    L = 10 ** 36.583
    RIN = 1.0e16

    # --- Cloudy
    z, E = cloudy_bands(f'{prefix}.ioncont')
    h = open(f'{prefix}.pdr').readline().lstrip('#').rstrip().split('\t')
    pdr = last_iteration(rows(f'{prefix}.pdr', len(h)), h.index('depth'))
    dep, avc = pdr[:, h.index('depth')], pdr[:, h.index('AV(point)')]
    zi = np.clip(z - 1, 0, len(dep) - 1)           # zone number is 1-based
    rc, avz = RIN + dep[zi], avc[zi]
    thin_c = L / (4 * np.pi * rc ** 2)

    # --- MOCASSIN
    d = R.read_run(run)
    t = open(os.path.join(run, 'output', 'grid0.out')).read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    n = nx * ny * nz
    off = 7 + nx + ny + nz
    idx = np.where(np.array(t[off:off + 3 * n:3], float) > 0)[0]
    pr = np.loadtxt(os.path.join(run, 'output', 'pdrRad.out'), skiprows=1)[idx]
    fuv = np.loadtxt(os.path.join(run, 'output', 'pdrFUV.out'), comments='#')

    print('MOCASSIN %s\nCloudy   %s' % (run, prefix))
    print('Each code\'s bolometric field over its OWN unattenuated stellar '
          'flux L/(4 pi r^2)\nat the same radius, so no internal unit '
          'convention enters. %d Cloudy zones.\n' % len(z))

    hdr = ('   A_V |  MOC Fbol/thin  Cld Fbol/thin   MOC/Cld |'
           '  band shares MOC (>1/FUV/.01-.44/<.01)  |  Cloudy')
    print(hdr); print('-' * len(hdr))
    for a in (0.15, 0.20, 0.30, 0.50, 0.65):
        s = np.abs(d['AV'] - a) <= max(0.02, 0.06 * a)
        if s.sum() < 3:
            continue
        j = np.argmin(abs(avz - a))
        fm = np.median(fuv[s, 14])                 # Fbol_MC / Fbol_thin
        fc = E[j].sum() / thin_c[j]
        vm = np.median(pr[s, 2:6], axis=0); vm = vm / vm.sum()
        vc = E[j] / E[j].sum()
        print('  %4.2f | %13.3f %14.3f %9.2f | %s | %s'
              % (a, fm, fc, fm / fc,
                 ' '.join('%5.3f' % x for x in vm),
                 ' '.join('%5.3f' % x for x in vc)))

    print('\nbands: ' + ', '.join(NAMES))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
