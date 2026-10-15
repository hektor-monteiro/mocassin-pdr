#!/usr/bin/env python3
"""H-034: emission-line maps of H2 and CO from a finished run.

    python tools/h034_maps.py <run> [<run> ...] [--h2 "vu Ju vl Jl; ..."] [--co "1-0,2-1,..."] [--cubes] [--png]

Everything comes from what the run already wrote:

  - H2: the level model's populations (output/h2Pop.bin; cell order and n(H2) in output/h2Cells.out). A line's
    emission per unit volume is n(H2) pop_u A_ul h nu, with A from dataPDR/h2/transprob_X.dat and nu from
    energy_X.dat - the data the level model itself reads - as output/lineFluxH2.out defines a line's luminosity
    (optically thin, no dust extinction).
  - CO (and the other coolants): output/pdrLineEm.out, each cell's escaping emission [erg/s/cm^3] of the chemistry's
    coolant transitions, which output/lineFluxMol.out sums. Its columns are the coolants of the input's pdrCoolants
    in order, each with its radiative transitions upper level outer and lower level inner (pdr_mod.f90, D-362);
    the column of a transition is found from the coolant files themselves.

For each line: the emissivity j = L_cell / (4 pi V) [erg s^-1 cm^-3 sr^-1]; a symmetricXYZ octant unfolded to the
full cube (the cells on the symmetry planes once, at their full width; tools/d383_maps.py); the surface-brightness
maps I = sum j dl [erg s^-1 cm^-2 sr^-1] along x, y and z. Each map's 4 pi x its integral over the sky is checked
against the line's total in lineFluxH2.out or lineFluxMol.out, and both are written in its header (LTOT, LMAP).

The cells MOCASSIN flags (lgBlack in grid0.out: thermal or ionization balance not reached, or T >= 30000 K) are left
out of every map, as MOCASSIN's own line tables and lineFluxMol.out leave them out. lineFluxH2.out includes them, so an
H2 map returns its table less the flagged cells' share, which is written in the header (LFLAG; H-034).

The maps are intrinsic: no dust extinction and no velocity axis. CO's emission is each cell's own escaping
emission (its escape probability, D-377), with no absorption by the cells between it and the observer. Those are
the line tables' own conventions, so the maps and the tables agree.

Output: <run>/output/maps_h2co.fits (and maps_h2co_cubes.fits with --cubes; maps_h2co.png with --png).
"""
import os
import re
import struct
import sys

import numpy as np
from astropy.io import fits

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from d383_maps import widths, unfold_axis, unfold          # noqa: E402

PC = 3.0857e18
# the code's own constants (constants_mod.f90, single-precision parameters, as h2Lines_mod uses them), so that a
# map returns the line table to the last digit; CODATA's differ by 2e-5
H, C = float(np.float32(6.6262e-27)), float(np.float32(2.9979250e10))
FOURPI = 4 * np.pi
H2_DEFAULT = '1 3 0 1; 1 2 0 0; 2 3 1 1; 1 1 0 1; 0 2 0 0; 0 3 0 1; 0 4 0 2; 0 5 0 3'
CO_DEFAULT = '1-0,2-1,3-2,4-3,5-4,6-5'
BR = {2: 'S', 0: 'Q', -2: 'O'}


def h2_name(vu, ju, vl, jl):
    return '%d-%d %s(%d)' % (vu, vl, BR.get(ju - jl, '?'), jl)


def tag(name):
    return re.sub(r'[^A-Za-z0-9]+', '', name.replace('-', 'to'))


def read_input(run):
    inp = open(os.path.join(run, 'input', 'input.in')).read()
    sym = re.search(r'^\s*symmetricXYZ\b', inp, re.M) is not None
    m = re.search(r'^\s*pdrCoolants\s+(\d+)\s+(.*)$', inp, re.M)
    cool = re.findall(r'"([^"]+)"', m.group(2))[:int(m.group(1))] if m else []
    d = re.search(r'^\s*pdrDataDir\s+"([^"]+)"', inp, re.M)
    return sym, cool, (d.group(1) if d else None)


def grid(run):
    t = open(os.path.join(run, 'output', 'grid0.out')).read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    ax = [np.array(t[7:7 + nx], float), np.array(t[7 + nx:7 + nx + ny], float), np.array(t[7 + nx + ny:7 + nx + ny + nz], float)]
    return (nx, ny, nz), ax


def flagged(run, shape):
    """the cells MOCASSIN leaves out of its line tables: active and lgBlack >= 1 (grid0.out: active, lgConverged, lgBlack)"""
    t = open(os.path.join(run, 'output', 'grid0.out')).read().split()
    off, n = 7 + sum(shape), int(np.prod(shape))
    act = np.array(t[off:off + 3 * n:3], int) > 0
    return act & (np.array(t[off + 2:off + 3 * n:3], int) >= 1)


def lamda_transitions(path):
    """a LAMDA file's radiative transitions (up, low) with A > 0, as pdr_mod orders them: up outer, low inner"""
    L = [l for l in open(path) if l.strip()]
    i = next(n for n, l in enumerate(L) if l.upper().startswith('!NUMBER OF RADIATIVE TRANSITIONS'))
    nrad = int(L[i + 1].split()[0])
    tr = []
    for l in L[i + 3:i + 3 + nrad]:
        q = l.split()
        if float(q[3]) != 0:
            tr.append((int(q[1]), int(q[2])))
    return sorted(tr)


def mol_columns(cool, ddir):
    cols, n = {}, 0
    for c in cool:
        for up, lo in lamda_transitions(os.path.join(ddir, c)):
            cols[(c, up, lo)] = n
            n += 1
    return cols, n


def mol_totals(run):
    d = {}
    for l in open(os.path.join(run, 'output', 'lineFluxMol.out')):
        q = l.split()
        if len(q) >= 7 and not q[0].startswith('#'):
            d[(q[0], int(q[1]), int(q[2]))] = (float(q[3]), float(q[5]))
    return d


def h2_totals(run):
    d = {}
    for l in open(os.path.join(run, 'output', 'lineFluxH2.out')):
        if l.startswith('#'):
            continue
        q = l.split()
        if len(q) >= 9:
            d[tuple(int(x) for x in q[-8:-4])] = (float(q[-4]), float(q[-2]))
    return d


def h2_data(ddir):
    E = {}
    for l in open(os.path.join(ddir, 'h2', 'energy_X.dat')):
        q = l.split()
        if len(q) >= 3 and not l.startswith('#') and q[0].lstrip('-').isdigit():
            try:
                E[(int(q[0]), int(q[1]))] = float(q[2])
            except ValueError:
                pass
    # a transition can be listed twice (E2 and M1, Pachucki & Komasa 2011): the components add, as h2_mod adds them;
    # a pair listed lower level first is turned round by energy, as h2_mod turns it
    A = {}
    for l in open(os.path.join(ddir, 'h2', 'transprob_X.dat')):
        q = l.split()
        if len(q) >= 7 and not l.startswith('#') and q[0] == '0' and q[3] == '0':
            u, lo = (int(q[1]), int(q[2])), (int(q[4]), int(q[5]))
            if u in E and lo in E and E[u] < E[lo]:
                u, lo = lo, u
            A[u + lo] = A.get(u + lo, 0.) + float(q[6])
    return E, A


def h2_cells(run, shape):
    f = open(os.path.join(run, 'output', 'h2Pop.bin'), 'rb')
    nc, nl = struct.unpack('2i', f.read(8))
    v = np.frombuffer(f.read(4 * nl), np.int32)
    J = np.frombuffer(f.read(4 * nl), np.int32)
    f.read(8 * nl)
    P = np.frombuffer(f.read(4 * nl * nc), np.float32).reshape(nc, nl)
    cells = np.array([l.replace('|', ' ').split()[:8] for l in open(os.path.join(run, 'output', 'h2Cells.out'))
                      if not l.startswith('#')], float)
    ijk = cells[:, :3].astype(int) - 1
    flat = (ijk[:, 0] * shape[1] + ijk[:, 1]) * shape[2] + ijk[:, 2]
    return {(int(a), int(b)): k for k, (a, b) in enumerate(zip(v, J))}, P, cells[:, 3].astype(int) - 1, flat, cells[:, 7]


def maps_of(j, w):
    wx, wy, wz = w
    return {'Z': (j * wz[None, None, :]).sum(2), 'Y': (j * wy[None, :, None]).sum(1), 'X': (j * wx[:, None, None]).sum(0)}


def lin_wcs(h, axes, names):
    for n, (a, nm) in enumerate(zip(axes, names), start=1):
        h['CTYPE%d' % n] = nm
        h['CUNIT%d' % n] = 'pc'
        h['CRPIX%d' % n] = 1.0
        h['CRVAL%d' % n] = a[0] / PC
        h['CDELT%d' % n] = (a[1] - a[0]) / PC


def main(run, h2sel, cosel, cubes=False, png=False):
    out = os.path.join(run, 'output')
    sym, cool, ddir = read_input(run)
    if ddir is None:
        raise SystemExit('%s: no pdrDataDir in input.in' % run)
    shape, ax = grid(run)
    nx, ny, nz = shape
    n = nx * ny * nz
    w = [widths(a) for a in ax]
    V = np.einsum('i,j,k->ijk', *w).ravel()                      # cell volumes [cm^3] (octant cells at half width)
    blk = flagged(run, shape)
    uni = all(np.allclose(np.diff(a), np.diff(a)[0], rtol=1e-5) for a in ax)
    fold = 8 if sym else 1
    lines = []

    # ---------------------------------------------------------------- H2
    E, A = h2_data(ddir)
    lev, P, cid, flat, nH2 = h2_cells(run, shape)
    T2 = h2_totals(run)
    for vu, ju, vl, jl in h2sel:
        key = (vu, ju, vl, jl)
        if key not in A or (vu, ju) not in lev:
            print('  [skipped] H2 %s: no A value or level' % h2_name(*key))
            continue
        hnu = H * C * (E[(vu, ju)] - E[(vl, jl)])
        e = np.zeros(n)
        e[flat] = nH2 * P[cid, lev[(vu, ju)]].astype(float) * A[key] * hnu       # erg/s/cm^3
        lam = 1e4 / (E[(vu, ju)] - E[(vl, jl)])
        lines.append(('H2 ' + h2_name(*key), 'H2', lam, e, T2.get(key, (None, None))[1], {'VU': vu, 'JU': ju, 'VL': vl, 'JL': jl}))

    # ---------------------------------------------------------------- CO
    cols, ncol = mol_columns(cool, ddir)
    Lm = open(os.path.join(out, 'pdrLineEm.out')).read().split('\n')
    hdr = Lm[0]
    m = re.search(r'two lines of,\s*(\d+)', hdr)
    assert m and int(m.group(1)) == ncol, ('pdrLineEm.out has %s transitions, the coolant files give %d' % (m.group(1) if m else '?', ncol))
    em = np.array([l.split() for l in Lm[1:1 + 2 * n:2]], float)
    assert em.shape == (n, ncol), em.shape
    TM = mol_totals(run)
    coname = next((c for c in cool if c.lower().endswith('co.dat') and not c.lower().startswith('13')), None)
    for s in cosel:
        ju, jl = (int(x) for x in s.split('-'))
        key = (coname, ju + 1, jl + 1)                 # the coolant file numbers levels from 1: J = level - 1
        if key not in cols:
            print('  [skipped] CO %s: not a radiative transition of %s' % (s, coname))
            continue
        lam, Ltab = TM.get(key, (None, None))
        lines.append(('CO %d-%d' % (ju, jl), 'CO', lam, em[:, cols[key]].copy(), Ltab, {'UP': key[1], 'LOW': key[2], 'COOLANT': coname}))

    # ---------------------------------------------------------------- maps, checks, files
    axf, wf = ax, w
    if sym:
        pairs = [unfold_axis(a, ww) for a, ww in zip(ax, w)]
        axf, wf = [p[0] for p in pairs], [p[1] for p in pairs]
    hdus = [fits.PrimaryHDU()]
    ph = hdus[0].header
    ph['ORIGIN'] = 'MOCASSIN-PDR h2-model, tools/h034_maps.py (H-034)'
    ph['RUN'] = os.path.abspath(run)[-68:]
    ph['SYMXYZ'] = (sym, 'octant unfolded to the full cube')
    ph['NFLAG'] = (int(blk.sum()), 'cells flagged lgBlack, left out of every map')
    ph['NX'], ph['NY'], ph['NZ'] = len(axf[0]), len(axf[1]), len(axf[2])
    ph['COMMENT'] = 'MAP<axis>_<line>: I = sum j dl along that axis [erg/s/cm2/sr]; image axes in pc.'
    ph['COMMENT'] = 'Intrinsic: no dust extinction, no velocity axis; CO is each cell own escaping emission.'
    ph['COMMENT'] = 'H2 from the level model populations (h2Pop.bin); CO from pdrLineEm.out.'
    chdus = [fits.PrimaryHDU(header=ph.copy())]
    rows = []
    print('%s: %dx%dx%d cells%s, %d lines, %d flagged cells left out' % (
        run, nx, ny, nz, ' (octant, unfolded)' if sym else '', len(lines), blk.sum()))
    for name, sp, lam, e, Ltab, extra in lines:
        Lflag = (e * V)[blk].sum() * fold
        e[blk] = 0.
        Lgrid = (e * V).sum() * fold
        j = (e / FOURPI).reshape(shape)
        if sym:
            j = unfold(j)
        mp = maps_of(j, wf)
        Lmap = (mp['Z'] * np.outer(wf[0], wf[1])).sum() * FOURPI
        rows.append((name, lam, Ltab, Lgrid, Lmap, Lflag))
        r = Lmap / Ltab if Ltab else float('nan')
        print('  %-14s %9s um  L(table) %11s  map/table %.6f  map/cells %.6f  flagged %.1e  peak I_z %.3e' % (
            name, ('%.3f' % lam) if lam else '-', ('%.5e' % Ltab) if Ltab else '-', r, Lmap / Lgrid if Lgrid else float('nan'),
            Lflag / (Lgrid + Lflag) if Lgrid + Lflag > 0 else 0., mp['Z'].max()))
        for axn, m_ in mp.items():
            hh = fits.ImageHDU(m_.T.astype(np.float32), name='MAP%s_%s' % (axn, tag(name)))
            hd = hh.header
            hd['LINE'] = name
            hd['SPECIES'] = sp
            if lam:
                hd['LAMBDA'] = (lam, 'micron')
            for k_, v_ in extra.items():
                hd[k_] = v_
            hd['LOS'] = (axn, 'the axis summed along')
            hd['BUNIT'] = 'erg/s/cm2/sr'
            hd['LTOT'] = (Ltab if Ltab else -1.0, 'erg/s, the line table (lineFluxH2/Mol.out)')
            hd['LMAP'] = (Lmap, 'erg/s, 4 pi x the map integrated over the sky')
            hd['LFLAG'] = (Lflag, 'erg/s in the flagged cells, left out')
            keep = {'Z': (0, 1), 'Y': (0, 2), 'X': (1, 2)}[axn]
            if uni:
                lin_wcs(hd, [axf[keep[0]], axf[keep[1]]], ['XYZ'[keep[0]], 'XYZ'[keep[1]]])
            hdus.append(hh)
        if cubes:
            hc = fits.ImageHDU(j.T.astype(np.float32), name='CUBE_%s' % tag(name))
            hc.header['LINE'] = name
            hc.header['BUNIT'] = 'erg/s/cm3/sr'
            if uni:
                lin_wcs(hc.header, axf, ['X', 'Y', 'Z'])
            chdus.append(hc)
    tabcols = [fits.Column(name='X', format='D', unit='cm', array=axf[0]), fits.Column(name='DX', format='D', unit='cm', array=wf[0])]
    hdus.append(fits.BinTableHDU.from_columns(tabcols, name='XAXIS'))
    hdus.append(fits.BinTableHDU.from_columns([fits.Column(name='Y', format='D', unit='cm', array=axf[1]),
                                               fits.Column(name='DY', format='D', unit='cm', array=wf[1])], name='YAXIS'))
    hdus.append(fits.BinTableHDU.from_columns([fits.Column(name='Z', format='D', unit='cm', array=axf[2]),
                                               fits.Column(name='DZ', format='D', unit='cm', array=wf[2])], name='ZAXIS'))
    hdus.append(fits.BinTableHDU.from_columns([
        fits.Column(name='LINE', format='20A', array=[r[0] for r in rows]),
        fits.Column(name='LAMBDA', format='D', unit='micron', array=[r[1] or np.nan for r in rows]),
        fits.Column(name='LTABLE', format='D', unit='erg/s', array=[r[2] or np.nan for r in rows]),
        fits.Column(name='LCELLS', format='D', unit='erg/s', array=[r[3] for r in rows]),
        fits.Column(name='LMAP', format='D', unit='erg/s', array=[r[4] for r in rows]),
        fits.Column(name='LFLAG', format='D', unit='erg/s', array=[r[5] for r in rows])], name='LINES'))
    fits.HDUList(hdus).writeto(os.path.join(out, 'maps_h2co.fits'), overwrite=True)
    print('  -> %s' % os.path.join(out, 'maps_h2co.fits'))
    if cubes:
        fits.HDUList(chdus).writeto(os.path.join(out, 'maps_h2co_cubes.fits'), overwrite=True)
        print('  -> %s' % os.path.join(out, 'maps_h2co_cubes.fits'))
    if png:
        quicklook(run, os.path.join(out, 'maps_h2co.fits'))
    return rows


def quicklook(run, path):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    hl = fits.open(path)
    maps = [h for h in hl if h.name.startswith('MAPZ_')]
    nc = 4
    nr = int(np.ceil(len(maps) / nc))
    fig, axs = plt.subplots(nr, nc, figsize=(3.3 * nc, 3.1 * nr), squeeze=False)
    xa = hl['XAXIS'].data['X'] / PC
    ya = hl['YAXIS'].data['Y'] / PC
    for a, h in zip(axs.ravel(), maps):
        m = h.data.T
        pos = m[m > 0]
        vmax = np.log10(pos.max()) if pos.size else 0
        im = a.pcolormesh(ya, xa, np.log10(np.maximum(m, 10 ** (vmax - 3))), shading='nearest', cmap='magma', vmin=vmax - 3, vmax=vmax)
        a.set_aspect('equal')
        a.set_title(h.header['LINE'], fontsize=10)
        a.tick_params(labelsize=7)
        cb = fig.colorbar(im, ax=a, fraction=0.046, pad=0.03)
        cb.ax.tick_params(labelsize=7)
    for a in axs.ravel()[len(maps):]:
        a.axis('off')
    fig.suptitle('%s: log I along z [erg s$^{-1}$ cm$^{-2}$ sr$^{-1}$], three decades; axes in pc' % os.path.basename(run.rstrip('/')), fontsize=10)
    fig.tight_layout()
    fig.savefig(os.path.join(os.path.dirname(path), 'maps_h2co.png'), dpi=110)
    plt.close(fig)
    print('  -> %s' % os.path.join(os.path.dirname(path), 'maps_h2co.png'))


if __name__ == '__main__':
    argv = sys.argv[1:]

    def opt(k, default):
        if k in argv:
            i = argv.index(k)
            v = argv[i + 1]
            del argv[i:i + 2]
            return v
        return default
    h2s = [tuple(int(x) for x in s.split()) for s in opt('--h2', H2_DEFAULT).split(';') if s.strip()]
    cos = [s.strip() for s in opt('--co', CO_DEFAULT).split(',') if s.strip()]
    cubes, png = '--cubes' in argv, '--png' in argv
    runs = [a for a in argv if not a.startswith('--')]
    for r in runs:
        main(r.rstrip('/'), h2s, cos, cubes=cubes, png=png)
