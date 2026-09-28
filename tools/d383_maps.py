#!/usr/bin/env python3
"""D-383: emissivity cubes and projected maps from mocassinPlot's output.

mocassinPlot writes, for each entry of input/plot.in, every cell's line
luminosity [E36 erg/s] (output/plot.out, one row per grid point in i,j,k
order) and every cell's position and volume [cm, E45 cm^3] (output/grid4.out).
This turns them into
  - an emissivity cube, j = L / (4 pi V)       [erg s^-1 cm^-3 sr^-1]
  - surface-brightness maps along x, y and z,
    I = sum_los j dl                             [erg s^-1 cm^-2 sr^-1]
and writes them to one FITS file, output/lineMaps.fits. A symmetricXYZ octant
is unfolded to the full cube, the cells on the symmetry planes appearing once
at their full width. With --png, the maps along z also go to
output/lineMaps_<n>.png.

plot.in entries are 'line <lineFlux.out index> <wav> <wav>' for MOCASSIN's
lines and 'mol <coolant file> <upper> <lower>' for the chemistry's molecular
coolant lines (D-383), numbered as in output/lineFluxMol.out.

The maps are optically thin sums of each cell's emission. For the molecular
lines that emission is already the escaping one (the escape probability of the
chemistry's line transfer, D-377), but no absorption between the cell and the
observer beyond it is applied, and there is no velocity axis.

    python tools/d383_maps.py runs/A [--png]
"""
import os
import sys

import numpy as np
from astropy.io import fits

FOURPI = 4 * np.pi


def labels(run):
    """Names for the plots: molecular lines by the coolant's own level numbers
    (for 12co.dat, level = J+1) and their wavelength from lineFluxMol.out."""
    ent = [l.split() for l in open(os.path.join(run, 'input', 'plot.in')) if l.strip()][1:]
    wav = {}
    fm = os.path.join(run, 'output', 'lineFluxMol.out')
    if os.path.exists(fm):
        for l in open(fm):
            s = l.split()
            if len(s) >= 4 and not s[0].startswith('#'):
                wav[(s[0], s[1], s[2])] = float(s[3])
    out = []
    for e in ent:
        if e[0] == 'mol':
            w = wav.get(tuple(e[1:4]))
            out.append((f'{e[1]} {e[2]}->{e[3]}' + (f' {w:.1f}um' if w else ''), 'mol', e[1:4]))
        else:
            out.append((f'line {e[1]} ({e[2]} A)', e[0], e[1:4]))
    return out


def widths(a):
    """Cell widths from the midpoints; the end cells run to the axis ends."""
    m = 0.5 * (a[1:] + a[:-1])
    return np.diff(np.concatenate(([a[0]], m, [a[-1]])))


def unfold_axis(a, w):
    """Mirror an octant axis about 0: the plane cell once, at twice its octant width."""
    ww = w.copy()
    ww[0] = 2 * w[0]
    return np.concatenate((-a[:0:-1], a)), np.concatenate((ww[:0:-1], ww))


def unfold(c):
    """Mirror an octant cube (i, j, k from the origin) to the full cube."""
    for ax in range(3):
        c = np.concatenate((np.flip(np.take(c, np.arange(1, c.shape[ax]), axis=ax), axis=ax), c),
                           axis=ax)
    return c


def main(run, png=False):
    out = os.path.join(run, 'output')
    sym = any(l.split()[:1] == ['symmetricXYZ'] for l in open(os.path.join(run, 'input', 'input.in')))
    g4 = np.loadtxt(os.path.join(out, 'grid4.out'))
    P = np.atleast_2d(np.loadtxt(os.path.join(out, 'plot.out')))[:, 1:]
    lab = labels(run)
    if P.shape[1] != len(lab):
        raise SystemExit(f'plot.out has {P.shape[1]} columns, plot.in {len(lab)} entries')
    xa, ya, za = (np.unique(g4[:, c]) for c in range(3))
    nx, ny, nz = len(xa), len(ya), len(za)
    if nx * ny * nz != len(g4):
        raise SystemExit('grid4.out is not one Cartesian grid (sub-grids are not handled)')
    dV = g4[:, 3].reshape(nx, ny, nz) * 1e45
    wx, wy, wz = widths(xa), widths(ya), widths(za)
    if sym:
        vol = np.einsum('i,j,k->ijk', wx, wy, wz)
    else:
        vol = dV
    mis = np.nanmax(np.abs(vol[dV > 0] / dV[dV > 0] - 1))
    if mis > 1e-3:
        print(f'  [warning] cell widths reproduce grid4.out volumes only to {mis:.2e}')
    if sym:
        (xa, wx), (ya, wy), (za, wz) = unfold_axis(xa, wx), unfold_axis(ya, wy), unfold_axis(za, wz)

    hdus = [fits.PrimaryHDU()]
    hdus[0].header['ORIGIN'] = 'MOCASSIN-PDR mocassinPlot (D-383)'
    hdus[0].header['SYMXYZ'] = (sym, 'octant unfolded to the full cube')
    hdus[0].header['COMMENT'] = 'CUBE: j [erg/s/cm3/sr], axes (z,y,x); MAPX/Y/Z: I [erg/s/cm2/sr]'
    hdus[0].header['COMMENT'] = 'Optically thin sums of each cell emission; no velocity axis.'
    print(f'{run}: {nx}x{ny}x{nz} cells{" (octant, unfolded)" if sym else ""}, {len(lab)} plots')
    for n, (name, kind, spec) in enumerate(lab):
        L = P[:, n].reshape(nx, ny, nz) * 1e36                     # erg/s per cell
        j = np.where(dV > 0, L / np.where(dV > 0, dV, 1) / FOURPI, 0.)
        Ltot = L.sum() * (8 if sym else 1)
        if sym:
            j = unfold(j)
        maps = {'Z': (j * wz[None, None, :]).sum(2), 'Y': (j * wy[None, :, None]).sum(1),
                'X': (j * wx[:, None, None]).sum(0)}
        # checks: the cube and each map return the grid's own total
        Lcube = (j * np.einsum('i,j,k->ijk', wx, wy, wz)).sum() * FOURPI
        Lz = (maps['Z'] * np.outer(wx, wy)).sum() * FOURPI
        print(f'  {n + 1}: {name:22s} L {Ltot:.5e} erg/s   cube/L {Lcube / Ltot if Ltot else 0:.6f}'
              f'   map_z/L {Lz / Ltot if Ltot else 0:.6f}   peak I_z {maps["Z"].max():.3e} erg/s/cm2/sr')
        h = fits.ImageHDU(j.T.astype(np.float32), name=f'CUBE{n + 1}')
        h.header['LINE'] = name
        h.header['BUNIT'] = 'erg/s/cm3/sr'
        h.header['LTOT'] = (Ltot, 'erg/s, whole grid')
        hdus.append(h)
        for ax, m in maps.items():
            hm = fits.ImageHDU(m.T.astype(np.float32), name=f'MAP{ax}{n + 1}')
            hm.header['LINE'] = name
            hm.header['BUNIT'] = 'erg/s/cm2/sr'
            hm.header['LOS'] = ax
            hdus.append(hm)
        if png:
            import matplotlib
            matplotlib.use('Agg')
            import matplotlib.pyplot as plt
            fig, a = plt.subplots(figsize=(5.2, 4.4))
            m = maps['Z']
            pos = m[m > 0]
            lo = np.percentile(pos, 1) if pos.size else 1e-30
            im = a.pcolormesh(ya / 3.0857e18, xa / 3.0857e18, np.log10(np.maximum(m, lo)),
                              shading='nearest', cmap='magma')
            a.set_aspect('equal')
            a.set_xlabel('y [pc]'); a.set_ylabel('x [pc]')
            a.set_title(f'{name}, along z')
            fig.colorbar(im, label='log I [erg s$^{-1}$ cm$^{-2}$ sr$^{-1}$]')
            fig.tight_layout()
            fig.savefig(os.path.join(out, f'lineMaps_{n + 1}.png'), dpi=110)
            plt.close(fig)
    ax = fits.BinTableHDU.from_columns([
        fits.Column(name='X', format='D', unit='cm', array=xa), fits.Column(name='DX', format='D', unit='cm', array=wx)],
        name='XAXIS')
    hdus += [ax,
             fits.BinTableHDU.from_columns([fits.Column(name='Y', format='D', unit='cm', array=ya),
                                            fits.Column(name='DY', format='D', unit='cm', array=wy)], name='YAXIS'),
             fits.BinTableHDU.from_columns([fits.Column(name='Z', format='D', unit='cm', array=za),
                                            fits.Column(name='DZ', format='D', unit='cm', array=wz)], name='ZAXIS')]
    fits.HDUList(hdus).writeto(os.path.join(out, 'lineMaps.fits'), overwrite=True)
    print(f'  -> {os.path.join(out, "lineMaps.fits")}')


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    for r in args:
        main(r, png='--png' in sys.argv)
