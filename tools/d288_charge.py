#!/usr/bin/env python3
"""D-288: MOCASSIN's grain potential against Cloudy's, and the heating split.

D-288 predicted that MOCASSIN's grains sit at a far higher potential than
Cloudy's - the Coulomb barrier then suppressing the photoelectric heating -
from the ~4.6 V implied by its heating per absorbed photon against Cloudy's
radius-averaged <Pot> of 0.5-1.4 V. Neither side had been read at depth.

MOCASSIN now writes it (mocGrain, thermBudget.out columns 41-46) and Cloudy
writes it under `save grain potential` (eV, per zone per bin). This prints
both at matched radius, together with the exact decomposition

    heating per H  =  N_abs * <Y> * <E> * hcRyd

so the gap against Cloudy is attributed to absorbed photons, yield or energy
per electron rather than to the total alone.

    ~/miniforge3/envs/astro/bin/python tools/d288_charge.py \\
        runs/d288-pn150k runs/d288-cloudy-grain/150k
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R
import d287_pe as P

PC = R.PC
HCRYD = 2.1798723e-11      # erg per Rydberg
RYD_EV = 13.605693


def read_grain(run):
    d = R.read_run(run)
    out = os.path.join(run, 'output')
    t = open(os.path.join(out, 'grid0.out')).read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    n = nx * ny * nz
    off = 7 + nx + ny + nz
    idx = np.where(np.array(t[off:off + 3 * n:3], float) > 0)[0]
    b = np.loadtxt(os.path.join(out, 'thermBudget.out'), comments='#')[:n][idx]
    if b.shape[1] < 46:
        raise SystemExit(f'{run}: thermBudget.out has {b.shape[1]} columns, '
                         'expected 46 - re-run with the D-288 build')
    d['PE'] = b[:, 1]
    d['Vg'] = b[:, 40] * RYD_EV          # eV
    d['Y'] = b[:, 41]
    d['E'] = b[:, 42] * RYD_EV           # eV
    d['Nabs'] = b[:, 43]
    d['Eabs'] = b[:, 44]
    d['area'] = b[:, 45]
    fuv = np.loadtxt(os.path.join(out, 'pdrFUV.out'), comments='#')
    d['G0'] = fuv[:, 9] * P.DRAINE_PER_HABING
    return d


def read_cloudy_grain(prefix):
    c = P.read_cloudy(prefix)
    dep = np.loadtxt(f'{prefix}.pdr', skiprows=1)[:, 0][:len(c['AV'])]
    c['r'] = (1e16 + dep) / PC
    g = np.loadtxt(f'{prefix}.gpot', skiprows=1)
    # area weights for an MRN a^-3.5 in 10 equal-log bins: the bins Cloudy
    # prints are in order of increasing radius, and what the photoelectric
    # term is felt on is absorbing area, so weight by a^2 n(a) da ~ a^-1.5.
    lab = open(f'{prefix}.gpot').readline().rstrip().split('\t')[1:]
    a = np.geomspace(0.005, 0.25, len(lab) + 1)
    am = np.sqrt(a[:-1] * a[1:])
    w = am ** (-1.5)
    w = w / w.sum()
    m = min(len(g), len(c['AV']))
    c['Vg'] = (g[:m, 1:] * w[None, :]).sum(axis=1)
    c['Vg_small'] = g[:m, 1]
    c['Vg_large'] = g[:m, -1]
    for k in list(c):
        if isinstance(c[k], np.ndarray) and len(c[k]) >= m:
            c[k] = c[k][:m]
    return c


def main(run, prefix):
    d = read_grain(run)
    c = read_cloudy_grain(prefix)

    print('grain potential and the photoelectric decomposition, '
          'matched in radius\n')
    hdr = ('  r[pc]   T_m/T_c      Vg_m   Vg_c  (sm/lg)   <Y>_m    <E>_m'
           '   Nabs/H     PE_m      PE_c   ratio')
    print(hdr)
    print('-' * len(hdr))
    for rad in (0.13, 0.16, 0.20, 0.25, 0.30, 0.40, 0.50, 0.60):
        s = np.abs(d['r'] - rad) < 0.012
        if s.sum() < 3:
            continue
        j = np.argmin(abs(c['r'] - rad))
        print('  %5.2f %6.0f/%-6.0f %6.2f %6.2f (%.2f/%.2f) %7.4f %7.3f '
              '%9.3g %9.3g %9.3g %6.2f'
              % (rad, np.median(d['Tgas'][s]), c['Tgas'][j],
                 np.median(d['Vg'][s]), c['Vg'][j],
                 c['Vg_small'][j], c['Vg_large'][j],
                 np.median(d['Y'][s]), np.median(d['E'][s]),
                 np.median(d['Nabs'][s]), np.median(d['PE'][s]),
                 c['PE'][j], np.median(d['PE'][s]) / c['PE'][j]))

    print('\nwhere the gap sits: absorbed energy vs conversion efficiency')
    print('  r[pc]   Eabs/H_m   Eabs/H_c*  eff_m    eff_c*   field x  eff x')
    print('  (* Cloudy Eabs/H inferred as MOCASSIN\'s scaled by G0_c/G0_m,')
    print('     the grain area per H being matched by construction)')
    for rad in (0.20, 0.30, 0.40, 0.50, 0.60):
        s = np.abs(d['r'] - rad) < 0.012
        if s.sum() < 3:
            continue
        j = np.argmin(abs(c['r'] - rad))
        fx = c['G0'][j] / np.median(d['G0'][s])
        eam = np.median(d['Eabs'][s])
        eac = eam * fx
        em, ec = np.median(d['PE'][s]) / eam, c['PE'][j] / eac
        print('  %5.2f %10.3g %10.3g %8.4f %8.4f %8.2f %6.2f'
              % (rad, eam, eac, em, ec, fx, ec / em))

    print('\ngrain area per H [cm^2]: MOCASSIN %.4g (constant)'
          % np.median(d['area']))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
