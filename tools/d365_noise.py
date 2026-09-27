#!/usr/bin/env python3
"""D-365: Monte Carlo noise per cell, from one run, without a second run.

hiipdr and pn150k are spherically symmetric, so every cell at one radius should
hold the same answer. The scatter of a quantity about its smooth radial profile
is therefore sampling noise plus whatever the Cartesian grid does to a sphere
(the ray tracer's 12 directions, cells straddling a gradient). The first falls
with the number of packet tracks per cell; the second does not, so the change
between two runs at different packet counts separates them.

The smooth profile is the median in radial bins one cell spacing wide,
interpolated to each cell's radius, so a gradient across a bin is removed
rather than counted as noise. The scatter is 1.4826 x the median absolute
deviation of ln(q / profile), i.e. a robust fractional sd. Bands are fixed in
radius from the run's own median A_V profile (radius is noise-free; A_V_eff,
being inverted from the local field, is not).

Reads grid0/grid1/pdrGrid.out only, so it works on the per-iteration snapshot
directories (runs/d365-*/snaps/itNN) as well as a finished run's output/.

    python tools/d365_noise.py runs/d363-hii/output runs/d365-hii61/snaps/it11
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R

# hiipdr's PDR runs to A_V ~3; pn150k's to ~0.8, so the bands can be set with
# e.g. D365_BANDS="0.05-0.15,0.15-0.3,0.3-0.45,0.45-0.6,0.6-0.8".
BANDS = [tuple(map(float, b.split('-'))) for b in os.environ.get(
    'D365_BANDS', '0.5-1.0,1.0-1.5,1.5-2.0,2.0-2.5,2.5-3.5').split(',')]
QTY = ['Tgas', 'chi', 'x(H2)', 'x(C+)', 'x(C)', 'x(CO)']


def read(out):
    t = open(os.path.join(out, 'grid0.out')).read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    xa = np.array(t[7:7 + nx], float)
    ya = np.array(t[7 + nx:7 + nx + ny], float)
    za = np.array(t[7 + nx + ny:7 + nx + ny + nz], float)
    n = nx * ny * nz
    off = 7 + nx + ny + nz
    act = np.array(t[off:off + n * 3:3], float).astype(int) > 0
    X, Y, Z = np.meshgrid(xa, ya, za, indexing='ij')
    r = np.sqrt(X ** 2 + Y ** 2 + Z ** 2).ravel()[act] / R.PC
    g1 = np.loadtxt(os.path.join(out, 'grid1.out'))[act]
    pg = R.read_pdrgrid(out, n)
    ab = pg['ab'][act]
    sp = R.SPEC.index
    d = {'r': r, 'dr': (xa[1] - xa[0]) / R.PC, 'rmax': xa.max() / R.PC,
         'nx': nx, 'Tgas': g1[:, 0], 'AV': pg['AV'][act], 'chi': pg['chi'][act],
         'x(H+)': ab[:, sp('H+')], 'x(H2)': 2 * ab[:, sp('H2')],
         'x(C+)': ab[:, sp('C+')], 'x(C)': ab[:, sp('C')], 'x(CO)': ab[:, sp('CO')]}
    return d


def smooth(r, q, dr):
    """Median profile in bins one cell wide, interpolated to each cell."""
    edges = np.arange(0.0, r.max() + dr, dr)
    k = np.digitize(r, edges) - 1
    rc, qc = [], []
    for b in range(len(edges) - 1):
        s = k == b
        if s.sum() >= 3:
            rc.append(np.median(r[s]))
            qc.append(np.median(q[s]))
    return np.interp(r, rc, qc)


def band_radii(d):
    """Radius range of each A_V band, from the median A_V profile."""
    ok = (d['x(H+)'] < 0.3) & (d['AV'] > 0)
    rs = np.sort(np.unique(np.round(d['r'][ok] / d['dr'] * 2) / 2 * d['dr']))
    av = smooth(d['r'][ok], d['AV'][ok], d['dr'])
    ro = d['r'][ok]
    out = []
    for lo, hi in BANDS:
        s = (av >= lo) & (av < hi)
        out.append((ro[s].min(), ro[s].max()) if s.any() else None)
    return out


def scatter(d):
    rb = band_radii(d)
    inner = d['r'] < 0.97 * d['rmax']       # the outer shell is partial
    res = {}
    for qn in QTY:
        q = d[qn]
        pos = (q > 0) & inner & (d['x(H+)'] < 0.3)
        lq = np.log(q[pos])
        prof = smooth(d['r'][pos], lq, d['dr'])
        dev = lq - prof
        rr = d['r'][pos]
        row = []
        for b in rb:
            if b is None:
                row.append((np.nan, 0))
                continue
            s = (rr >= b[0]) & (rr <= b[1])
            if s.sum() < 10:
                row.append((np.nan, int(s.sum())))
                continue
            row.append((1.4826 * np.median(np.abs(dev[s] - np.median(dev[s]))),
                        int(s.sum())))
        res[qn] = row
    return res, rb


def main(dirs):
    runs = [(p, read(p)) for p in dirs]
    for p, d in runs:
        res, rb = scatter(d)
        pk = ''
        f = os.path.join(p, 'packets.txt')
        if os.path.exists(f):
            pk = '  ' + open(f).read().split()[-4] + ' packets'
        print(f'\n{p}  ({d["nx"]}^3, cell {d["dr"]:.3f} pc){pk}')
        print('  robust fractional sd about the radial profile, by A_V band')
        print('  %-7s' % 'qty' + ''.join('  A_V %4.2f-%4.2f' % b for b in BANDS))
        for qn in QTY:
            print('  %-7s' % qn + ''.join(
                '  %7.3f (%4d)' % (v, n) if np.isfinite(v) else '  %14s' % '-'
                for v, n in res[qn]))


if __name__ == '__main__':
    main(sys.argv[1:])
