#!/usr/bin/env python3
"""D-285: the numbers behind the '150 kK PN Against Cloudy' page, from a run.

Recomputes what the page states, so a re-run can be published without any
number being carried over by hand: headline figures, the selected-depths
table, the MOCASSIN line intensities, the PDR coolant integrals and the
iteration cost table.

    ~/miniforge3/envs/astro/bin/python tools/d285_kpis.py \\
        runs/d285-pn150k runs/d284-fs-cloudy/150k

Validate it by running it on runs/d283-pn150k, which the published page was
built from.
"""
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R

PC = R.PC
RIN = 1e16


def cells(run):
    d = R.read_run(run)
    g0 = open(os.path.join(run, 'output', 'grid0.out')).read().split()
    nx, ny, nz = int(g0[1]), int(g0[2]), int(g0[3])
    n = nx * ny * nz
    off = 7 + nx + ny + nz
    idx = np.where(np.array(g0[off:off + 3 * n:3], float) > 0)[0]
    xa = np.array(g0[7:7 + nx], float)
    edges = np.concatenate([[0], 0.5 * (xa[1:] + xa[:-1]), [xa[-1]]])
    w = np.diff(edges)
    V = (w[:, None, None] * w[None, :, None] * w[None, None, :]).ravel()[idx]
    return d, n, idx, V


def lineflux(run):
    """(elem, ion, wavelength [A]) -> intensity / Hbeta, plus the He blocks."""
    out, named, blk = {}, {}, None
    hbeta = None
    for ln in open(os.path.join(run, 'output', 'lineFlux.out')):
        s = ln.split()
        if 'Hbeta [E36' in ln:
            hbeta = float(s[-1]) * 1e36
            continue
        if len(s) == 3 and s[0] == 'HeII':
            try:                      # 'HeII 4686 <value>'; skip the headings
                named.setdefault('HeII', []).append((float(s[1]), float(s[2])))
            except ValueError:
                pass
            continue
        if len(s) == 1 and s[0] in ('HeI', 'HeII'):
            blk = s[0]
            continue
        if len(s) == 2:
            try:
                named.setdefault(blk, []).append((float(s[0]), float(s[1])))
            except ValueError:
                pass
            continue
        if len(s) == 7:
            try:
                e, i = int(s[0]), int(s[1])
                out[(e, i, float(s[4]))] = float(s[5])
            except ValueError:
                pass
        blk = blk if len(s) else None
    return hbeta, out, named


def pick(tab, elem, ion, lam, tol=5e-3):
    """the nearest transition of that ion within tol; blends stay separate."""
    hits = sorted((abs(k[2] - lam) / lam, v) for k, v in tab.items()
                  if k[0] == elem and k[1] == ion and abs(k[2] - lam) / lam < tol)
    return hits[0][1] if hits else float('nan')


def pick_named(named, blk, lam, tol=3.0):
    hits = [v for w, v in named.get(blk, []) if abs(w - lam) < tol]
    return max(hits) if hits else float('nan')


LINES = [('He I 5876', 'named', 'HeI', 5875.6), ('He II 4686', 'named', 'HeII', 4685.7),
         ('[O III] 5007', 8, 3, 5006.8), ('[O III] 4363', 8, 3, 4363.2),
         ('[O III] 88um', 8, 3, 883323.), ('[O IV] 25.9um', 8, 4, 258863.),
         ('[Ne V] 24.3um', 10, 5, 243108.), ('[Ne III] 3869', 10, 3, 3868.8),
         ('[Ne III] 15.6um', 10, 3, 155509.), ('[Ne II] 12.8um', 10, 2, 128101.),
         ('[S IV] 10.5um', 16, 4, 105076.), ('[S III] 18.7um', 16, 3, 187078.),
         ('[S II] 6716', 16, 2, 6716.4), ('[S II] 6731', 16, 2, 6730.8),
         ('[Ar III] 7135', 18, 3, 7135.8), ('[Cl III] 5518', 17, 3, 5517.7),
         ('[N II] 6584', 7, 2, 6583.5), ('[N II] 122um', 7, 2, 1217690.),
         ('[O II] 3726', 8, 2, 3726.0), ('[O II] 3729', 8, 2, 3728.8),
         ('[O I] 6300', 8, 1, 6300.3), ('[C II] 158um (lineFlux)', 6, 2, 1576360.),
         ('[O I] 63um (lineFlux)', 8, 1, 631679.)]


def main(run, cprefix):
    d, n, idx, V = cells(run)
    r = d['r']
    nh = np.loadtxt(os.path.join(run, 'output', 'grid1.out'))[idx, 2]
    c = R.cloudy_as_run(cprefix, RIN)
    hbeta, tab, named = lineflux(run)

    def cross(x, y, xs):
        """where y - x changes sign, linearly in the ordinate xs."""
        f = np.log(np.maximum(y, 1e-300)) - np.log(np.maximum(x, 1e-300))
        o = np.argsort(xs)
        f, xs = f[o], np.asarray(xs)[o]
        k = np.where(np.diff(np.sign(f)) != 0)[0]
        if not len(k):
            return float('nan')
        k = k[0]
        return xs[k] + (0 - f[k]) / (f[k + 1] - f[k]) * (xs[k + 1] - xs[k])

    # radial profiles: median per shell
    nb = 60
    re_ = np.linspace(r.min(), r.max(), nb + 1)
    rc_ = 0.5 * (re_[1:] + re_[:-1])
    prof = {}
    for key in ('H+', 'H', 'He++', 'He+', 'H2', 'Tgas', 'e-'):
        prof[key] = np.array([np.median(d[key][(r >= a) & (r < b)])
                              if ((r >= a) & (r < b)).sum() else np.nan
                              for a, b in zip(re_[:-1], re_[1:])])
    ok = ~np.isnan(prof['H+'])
    print('== headline ==')
    print('Hbeta                %.3e erg/s' % hbeta)
    print('H+ front  (x=1/2)    %.4f pc   Cloudy %.4f'
          % (cross(prof['H+'][ok], prof['H'][ok], rc_[ok]),
             cross(c['H+'], c['H'], (RIN + c['depth']) / PC)))
    print('He2+ front           %.4f pc   Cloudy %.4f'
          % (cross(prof['He++'][ok], prof['He+'][ok], rc_[ok]),
             cross(c['He++'], c['He+'], (RIN + c['depth']) / PC)))
    # binned like the figures: per-cell scatter would place the crossing on
    # whichever single cell straddles it
    ab = np.geomspace(max(d['AV'].min(), 1e-3), d['AV'].max(), 60)
    xh2, mh2 = R.median_profile(d['AV'], 2 * d['H2'], ab)
    _, mh = R.median_profile(d['AV'], d['H'], ab)
    aH = cross(mh2, mh, xh2)
    print('H/H2 crossing A_V    %.3f          Cloudy %.3f'
          % (aH, cross(2 * c['H2'], c['H'], c['AV'])))
    pdr = (d['AV'] > 0.3)
    print('PDR T_gas A_V>0.3    %.0f-%.0f K       Cloudy %.0f-%.0f'
          % (np.percentile(d['Tgas'][pdr], 5), np.percentile(d['Tgas'][pdr], 95),
             np.percentile(c['Tgas'][c['AV'] > 0.3], 5),
             np.percentile(c['Tgas'][c['AV'] > 0.3], 95)))

    print('\n== selected depths (MOCASSIN / Cloudy) ==')
    print('A_V     Tgas          Tdust        ne            n(H2)         n(C+)         n(CO)')
    for av in (0.05, 0.10, 0.15, 0.20, 0.30, 0.50, 0.65):
        s = np.abs(d['AV'] / av - 1) < 0.08
        j = np.argmin(abs(c['AV'] - av))
        if s.sum() == 0:
            continue
        row = []
        for k in ('Tgas', 'Tdust', 'e-', 'H2', 'C+', 'CO'):
            row.append('%.3g / %.3g' % (np.median(d[k][s]), c[k][j]))
        print('%.2f  ' % av + '  '.join('%-13s' % x for x in row))

    print('\n== line intensities / Hbeta (MOCASSIN) ==')
    for e in LINES:
        if e[1] == 'named':
            v = pick_named(named, e[2], e[3])
        else:
            v = pick(tab, e[1], e[2], e[3])
        print('%-26s %.4g' % (e[0], v))

    cool = np.loadtxt(os.path.join(run, 'output', 'pdrCoolSp.out'))[:n][idx]
    L = 8 * (cool * V[:, None]).sum(0)
    print('\n== PDR coolant luminosities (x8 octant), /Hbeta ==')
    for nm, v in zip(('CO', 'C+', 'C', 'O'), L):
        print('%-3s %.3e erg/s = %.3f Hbeta' % (nm, v, v / hbeta))

    log = os.path.join(run, 'run.log')
    if os.path.exists(log):
        txt = open(log).read()
        fin = re.findall(r'Iteration\s+(\d+) ; finished at (\d+):(\d+):(\d+)', txt)
        conv = re.findall(r'Iteration\s+\d+ ; Total:\s+([\d.E+-]+)\s+% converged', txt)
        print('\n== cost ==')
        mins = []
        for a, b in zip(fin, fin[1:]):
            t0 = int(a[1]) * 60 + int(a[2]) + int(a[3]) / 60.
            t1 = int(b[1]) * 60 + int(b[2]) + int(b[3]) / 60.
            mins.append((t1 - t0) % 1440)
        print('iterations finished: %d' % len(fin))
        print('minutes per iteration (2..N): ' +
              ' '.join('%.1f' % m for m in mins))
        print('converged %%: ' + ' '.join(conv))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
