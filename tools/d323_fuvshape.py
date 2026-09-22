#!/usr/bin/env python3
"""D-323: the shape of the FUV band, and how each code attenuates across it.

D-322 found that MOCASSIN's count of grain-absorbed photons above the
photoelectric threshold falls 2.7x faster with depth than its own Habing-band
field (Nabs/H 242x against G0 89x over A_V 0.73-2.21 in hiipdr). That is a
statement about the spectrum's shape *inside* 0.44-1 Ryd, and the first thing
to rule in or out is the optics: if MOCASSIN's grain cross section rises more
steeply across the band than Cloudy's, the band reddens faster with depth for
that reason alone and no transport difference is needed.

Both sides are read as cross section PER HYDROGEN, which is the only form in
which they are comparable - the two codes carry different material densities
and different size distributions to reach the same A_V/N_H.

  MOCASSIN: the run's own `dust_species.dat` and `dust_sizes.dat`, with Mie
            computed here from the named .nk file (tools/d305_mie.py), summed
            over the size distribution with the same weights the code uses.
  Cloudy:   the compiled `.opc`, whose `abs_cs_nn`/`sct_cs_nn` blocks are
            already per H per bin. Summed over its bins.

    ~/miniforge3/envs/astro/bin/python tools/d323_fuvshape.py \\
        runs/d316-hiipdr runs/d277-cloudy/sdraine03_hiipdr_10.opc
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from d305_mie import bhmie

RYD_UM = 0.0911267051          # 1 Ryd in um
FUV = (0.44, 1.0)              # the Habing band, as grid_mod.f90 cuts it


def read_sizes(run):
    """The declared number of records, not however many lines the file has -
    hiipdr's carries a trailing ' slope (p)' line and pn150k's does not
    (L-21)."""
    sl = open(os.path.join(run, 'input', 'dust_sizes.dat')).read().splitlines()
    n = int(sl[0].split()[0])
    rec = [l.split()[:3] for l in sl[1:]
           if len(l.split()) >= 3 and l.split()[0].isdigit()][:n]
    a = np.array(rec, float)
    if len(a) != n:
        raise SystemExit(f'dust_sizes.dat declares {n}, found {len(a)}')
    return a[:, 1], a[:, 2]        # a [um], n(a) weight


def read_species(run):
    sl = [l for l in open(os.path.join(run, 'input', 'dust_species.dat'))
          .read().splitlines() if l.strip()]
    n = int(sl[0].split()[0])
    out = []
    for l in sl[1:1 + n]:
        t = l.split()
        out.append((t[0].strip("'\""), float(t[1])))
    return out


def moc_xsec(run, nu):
    """C_abs, C_sca per H nucleus on the frequency grid nu [Ryd].

    Number-weighted over the size distribution exactly as dust_mod.f90 does;
    the absolute scale carries whatever Ndust the model set, which cancels in
    every ratio below, so only the SHAPE is claimed here.
    """
    a_um, nofa = read_sizes(run)
    # ph_mod.f90 makeDustXsec: grainWeight = n(a) da / sum(n(a) da), with da
    # the central difference of the radius grid. Using n(a) alone on a
    # logarithmic grid over-weights the small grains by a factor ~a, which
    # steepens the FUV slope - i.e. it manufactures exactly the signal this
    # tool is looking for. Weight the same way the code does.
    da = np.empty_like(a_um)
    if len(a_um) > 1:
        da[0] = a_um[1] - a_um[0]
        da[1:-1] = (a_um[2:] - a_um[:-2]) / 2.0
        da[-1] = a_um[-1] - a_um[-2]
    else:
        da[:] = 1.0
    w = nofa * da
    w = w / w.sum()
    lam = RYD_UM / nu
    tot_a = np.zeros_like(nu)
    tot_s = np.zeros_like(nu)
    for path, abun in read_species(run):
        p = path if os.path.exists(path) else os.path.join('dustData',
                                                           os.path.basename(path))
        t = np.loadtxt(p, skiprows=2)
        wl, n_, k_ = t[:, 0], t[:, 1], t[:, 2]
        o = np.argsort(wl)
        wl, n_, k_ = wl[o], n_[o], k_[o]
        m = (np.interp(lam, wl, n_) + 1j * np.interp(lam, wl, k_))
        for ai, wi in zip(a_um, w):
            x = 2 * np.pi * ai / lam
            qe = np.empty_like(nu)
            qs = np.empty_like(nu)
            for i in range(len(nu)):
                qext, qsca, _ = bhmie(x[i], m[i])
                qe[i], qs[i] = qext, qsca
            geo = np.pi * (ai * 1e-4) ** 2
            tot_a += abun * wi * geo * (qe - qs)
            tot_s += abun * wi * geo * qs
    return tot_a, tot_s


def cloudy_xsec(opc):
    """anu, C_abs, C_sca per H, summed over Cloudy's bins."""
    lines = open(opc).read().splitlines()
    out = {}
    for key, tag in (('abs', 'abs_cs_01'), ('sca', 'sct_cs_01')):
        i = next(j for j, l in enumerate(lines) if tag in l)
        block = []
        for l in lines[i + 1:]:
            t = l.split()
            if not t or t[0].startswith('#'):
                # a bare '#' separates the header from the data; stop only
                # once data has started
                if block:
                    break
                continue
            block.append([float(v) for v in t])
        b = np.array(block)
        out[key] = (b[:, 0], b[:, 1:].sum(axis=1))
    anu = out['abs'][0]
    return anu, out['abs'][1], np.interp(anu, out['sca'][0], out['sca'][1])


def logslope(nu, y, lo, hi):
    s = (nu >= lo) & (nu <= hi) & (y > 0)
    return np.polyfit(np.log(nu[s]), np.log(y[s]), 1)[0]


def main(run, opc):
    anu_c, ca_c, cs_c = cloudy_xsec(opc)
    s = (anu_c >= 0.30) & (anu_c <= 1.30)
    nu = np.unique(np.concatenate([anu_c[s], np.linspace(0.40, 1.05, 27)]))
    ca_m, cs_m = moc_xsec(run, nu)
    ca_ci = np.interp(nu, anu_c, ca_c)
    cs_ci = np.interp(nu, anu_c, cs_c)

    print(f'MOCASSIN {run}\nCloudy   {opc}')
    print('Grain cross section per H across the Habing band, and its shape.\n')
    print('  E[Ryd] lam[um] |  C_abs m      C_abs c   |  albedo m  albedo c')
    print('  (MOCASSIN C_abs carries no Ndust, so only its SHAPE and the')
    print('   albedo, which is a ratio, are comparable in absolute terms.)')
    print('  ' + '-' * 66)
    for e in (0.44, 0.50, 0.60, 0.70, 0.80, 0.90, 1.00):
        i = np.argmin(abs(nu - e))
        am = cs_m[i] / (ca_m[i] + cs_m[i])
        ac = cs_ci[i] / (ca_ci[i] + cs_ci[i])
        print('  %6.2f %7.4f | %10.3e %10.3e | %9.3f %9.3f'
              % (e, RYD_UM / e, ca_m[i], ca_ci[i], am, ac))

    print('\n=== the shape, normalised at the band\'s red edge (0.44 Ryd) ===')
    i0 = np.argmin(abs(nu - 0.44))
    print('  E[Ryd] | C_abs/C_abs(0.44):  MOCASSIN   Cloudy   m/c')
    for e in (0.50, 0.60, 0.70, 0.80, 0.90, 1.00):
        i = np.argmin(abs(nu - e))
        rm, rc = ca_m[i] / ca_m[i0], ca_ci[i] / ca_ci[i0]
        print('  %6.2f |                  %9.3f %8.3f %6.3f'
              % (e, rm, rc, rm / rc))

    sm = logslope(nu, ca_m, *FUV)
    sc = logslope(nu, ca_ci, *FUV)
    print('\n  d ln C_abs / d ln E over %.2f-%.2f Ryd:  MOCASSIN %+.3f   '
          'Cloudy %+.3f   difference %+.3f' % (FUV[0], FUV[1], sm, sc, sm - sc))
    em = logslope(nu, ca_m + cs_m, *FUV)
    ec = logslope(nu, ca_ci + cs_ci, *FUV)
    print('  the same for C_ext (what attenuates):  MOCASSIN %+.3f   '
          'Cloudy %+.3f   difference %+.3f' % (em, ec, em - ec))

    print("""
Reading it. A steeper C_ext means the blue side of the band is removed faster,
so the band reddens more per magnitude and the photoelectric integral - which
weights the blue side, being the part above the work function - falls faster
than the energy integral. That is the D-322 signature. A difference near zero
here means the optics are NOT the cause and the next suspect is transport.""")


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
