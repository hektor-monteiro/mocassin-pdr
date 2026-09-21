#!/usr/bin/env python3
"""D-287: separate the FUV field from the photoelectric rate, against Cloudy.

O-02 is a grain photoelectric heating deficit (D-285): MOCASSIN heats the deep
PDR 5-11x less than Cloudy on that term, with the same graphite, the same MRN
0.005-0.25 um distribution and A_V/N_H matched.  Three things could be low:
the FUV field the term is evaluated on, the yield, or the grain charge.  The
field is measurable on both sides - Cloudy's `save PDR` writes G0 per zone and
MOCASSIN's pdrFUV.out writes chi in Draine units - so this prints, in matched
A_V bins:

  * the field on each side (G0, Habing),
  * the photoelectric heating per H nucleus on each side,
  * the *efficiency*, heating per H per unit G0, which is the rate physics
    with the field divided out.

If the fields agree and the efficiencies do not, O-02 is the yield/charging,
not the transfer.

    ~/miniforge3/envs/astro/bin/python tools/d287_pe.py \\
        runs/d285-pn150k runs/d283-150k-cloudy-noCaFe/150k
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R

# Draine (8.94e-14 erg/cm3, constants_mod) over Habing (5.29e-14): MOCASSIN
# reports chi in Draine units, Cloudy's save PDR reports G0 in Habing.
DRAINE_PER_HABING = 8.94e-14 / 5.29e-14


def read_moc(run):
    """A_V, G0, PE heating per H, n_e, T_gas for every active cell."""
    d = R.read_run(run)
    out = os.path.join(run, 'output')
    t = open(os.path.join(out, 'grid0.out')).read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    n = nx * ny * nz
    off = 7 + nx + ny + nz
    idx = np.where(np.array(t[off:off + 3 * n:3], float) > 0)[0]

    bud = np.loadtxt(os.path.join(out, 'thermBudget.out'),
                     comments='#')[:n][idx]
    # pdrFUV.out skips inactive cells, so it is already on `idx` order
    fuv = np.loadtxt(os.path.join(out, 'pdrFUV.out'), comments='#')
    if len(fuv) != len(idx):
        raise SystemExit(f'pdrFUV.out has {len(fuv)} rows, expected {len(idx)}')

    d['G0'] = fuv[:, 9] * DRAINE_PER_HABING
    d['G0thin'] = fuv[:, 10] * DRAINE_PER_HABING
    d['phot'] = bud[:, 0]
    d['PE'] = bud[:, 1]
    d['PDRheat'] = bud[:, 2]
    d['nh'] = fuv[:, 8]
    return d


def rows(path, ncol):
    """Rows of a Cloudy save file that have the header's column count.

    A save file read while Cloudy is still writing ends in a partial line,
    and a multi-iteration save can carry a short trailing record; numpy's
    loadtxt refuses the whole file for either. Take the well-formed rows.
    """
    out = [ln.split() for ln in open(path).read().splitlines()[1:]]
    return np.array([r for r in out if len(r) == ncol], float)


def last_iteration(a, depth_col=0):
    """D-302: keep only the final iteration of a Cloudy save file.

    The model input writes `save PDR` without `last`, where every other save
    is `save last`, so the .pdr file holds ALL iterations concatenated - 1348
    rows against the .ovr's 671 - and a reader that takes the whole file mixes
    the unconverged first pass into the reference. An iteration restart shows
    as the depth column decreasing.
    """
    if len(a) < 2:
        return a
    brk = np.where(np.diff(a[:, depth_col]) < 0)[0]
    return a if not len(brk) else a[brk[-1] + 1:]


def read_cloudy(prefix):
    """A_V, G0, GrnP heating per H, n_e, T from the .pdr/.ovr/.heat set."""
    hdr = open(f'{prefix}.pdr').readline().lstrip('#').rstrip().split('\t')
    pdr = last_iteration(rows(f'{prefix}.pdr', len(hdr)),
                         hdr.index('depth') if 'depth' in hdr else 0)
    g0 = pdr[:, hdr.index('G0')]
    av = pdr[:, hdr.index('AV(point)')]

    oh = open(f'{prefix}.ovr').readline().lstrip('#').rstrip().split('\t')
    ovr = rows(f'{prefix}.ovr', len(oh))
    nh = ovr[:, oh.index('hden')]
    ne = ovr[:, oh.index('eden')]
    te = ovr[:, oh.index('Te')]

    dep, tot, grnp = [], [], []
    for ln in open(f'{prefix}.heat'):
        if ln.startswith('#'):
            continue
        s = ln.rstrip('\n').split('\t')
        # D-300: a .heat saved with extra diagnostics carries interleaved
        # non-data lines (per-level heating traces). Skip anything whose
        # first field is not a depth.
        if len(s) < 3:
            continue
        try:
            d0, t0 = float(s[0]), float(s[2])
        except ValueError:
            continue
        dep.append(d0)
        tot.append(t0)
        pairs = [x for x in s[5:] if x.strip()]
        f = {}
        for i in range(0, len(pairs) - 1, 2):
            try:
                f[pairs[i].strip()] = float(pairs[i + 1])
            except ValueError:
                pass
        grnp.append(f.get('GrnP', 0.0))
    tot, grnp = np.array(tot), np.array(grnp)
    m = min(len(av), len(tot), len(nh))
    return {'AV': av[:m], 'G0': g0[:m], 'PE': (tot * grnp)[:m] / nh[:m],
            'Htot': tot[:m] / nh[:m], 'e-': ne[:m], 'Tgas': te[:m],
            'nh': nh[:m]}


def main(run, prefix):
    m = read_moc(run)
    c = read_cloudy(prefix)

    print('MOCASSIN %s   Cloudy %s' % (run, prefix))
    print('A_V from the front; MOCASSIN medians in +-0.05 dex-free bins,\n'
          'Cloudy at the nearest zone.\n')
    hdr = ('  A_V     T_m/T_c        G0_m      G0_c   G0m/G0c    '
           'PE_m       PE_c    PEm/PEc   eff_m     eff_c   ratio')
    print(hdr)
    print('-' * len(hdr))
    for av in (0.05, 0.1, 0.2, 0.3, 0.5, 0.7, 1.0, 1.5, 2.0, 3.0, 4.0):
        s = np.abs(m['AV'] - av) <= max(0.02, 0.08 * av)
        if s.sum() < 3:
            continue
        j = np.argmin(abs(c['AV'] - av))
        g0m = np.median(m['G0'][s])
        pem = np.median(m['PE'][s])
        # efficiency: heating per H nucleus per unit G0
        em, ec = pem / max(g0m, 1e-30), c['PE'][j] / max(c['G0'][j], 1e-30)
        print('%6.2f  %5.0f/%-5.0f  %9.3g %9.3g %7.2f  %9.3g %9.3g %7.2f  '
              '%9.3g %9.3g %7.2f'
              % (av, np.median(m['Tgas'][s]), c['Tgas'][j],
                 g0m, c['G0'][j], g0m / max(c['G0'][j], 1e-30),
                 pem, c['PE'][j], pem / max(c['PE'][j], 1e-30),
                 em, ec, em / max(ec, 1e-30)))

    print('\nattenuation check: MOCASSIN chi/chi_thin against exp(-tau_FUV)')
    print('  A_V    chi/chi_thin   G0_c/G0_c(front)   n_e(m)/n_e(c)')
    jf = np.argmin(abs(c['AV'] - 0.0))
    for av in (0.05, 0.1, 0.2, 0.3, 0.5, 0.7, 1.0, 1.5, 2.0, 3.0):
        s = np.abs(m['AV'] - av) <= max(0.02, 0.08 * av)
        if s.sum() < 3:
            continue
        j = np.argmin(abs(c['AV'] - av))
        print('%6.2f   %12.4g   %16.4g   %13.3g'
              % (av, np.median(m['G0'][s] / m['G0thin'][s]),
                 c['G0'][j] / c['G0'][jf],
                 np.median(m['e-'][s]) / c['e-'][j]))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
