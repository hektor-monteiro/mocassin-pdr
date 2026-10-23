#!/usr/bin/env python3
"""mocread: a small reader for MOCASSIN-PDR's main output files. Needs numpy only.

    python tools/mocread.py [run]       # a summary of the model in run/ (default .)

    import mocread
    g = mocread.read_grid(run)          # the grid and the gas: Te, ne, nH, ion fractions
    l = mocread.read_lines(run)         # lineFlux.out: Hbeta and the line ratios
    p = mocread.read_pdr(run, g)        # pdrGrid.out of a PDR build: chiFUV, A_V, the chemistry

Scope. One grid, a 3D model, written by a gfortran build (list-directed output), without lgDebug, with
one nebular composition (nebComposition, no multiChemistry). Anything else is refused with a message
saying which of these it is, rather than read wrongly.

Files, all relative to the run directory:

    input/input.in and its nebComposition file   composition()     the switched-on elements
    output/grid0.out, grid1.out, grid2.out       read_grid()       axes, active and lgBlack flags,
                                                                   Te, ne, nH, ion fractions
    output/lineFlux.out                          read_lines()      Hbeta, H I, He I, He II, heavy ions
    output/temperature.out                       mean_te()         mean ionic temperatures
    output/ionratio.out                          ion_fractions()   mean ionic fractions
    output/SED.out                               read_sed()        the emergent SED
    output/pdrGrid.out                           read_pdr()        the PDR state (v2 layout, D-352)
    output/convergence.out                       read_convergence()  the per-iteration totals (D-391)

Ion stages are named by their charge: 0 is the neutral atom, 1 the singly ionised ion, and so on, so
frac('O', 2) is the fraction of oxygen in O2+. MOCASSIN's own files count stages from 1 (the neutral
atom); this module converts every one of them.
"""
import os
import re
import sys

import numpy as np

ELEMENTS = ['H', 'He', 'Li', 'Be', 'B', 'C', 'N', 'O', 'F', 'Ne', 'Na', 'Mg',
            'Al', 'Si', 'P', 'S', 'Cl', 'Ar', 'K', 'Ca', 'Sc', 'Ti', 'V', 'Cr',
            'Mn', 'Fe', 'Co', 'Ni', 'Cu', 'Zn']
# the abundance slots in odes_reduced.c's order (dataPDR/species_reduced.d since D-357; d260_roellig SPEC)
REDUCED_SPECIES = ['H3+', 'He+', 'Mg', 'CH5+', 'O2', 'H2+', 'CH4+', 'O+', 'OH+', 'Mg+',
                   'C+', 'CH4', 'H2O+', 'H3O+', 'CO+', 'O2+', 'CH2', 'H2O', 'H+', 'CH3+',
                   'CH', 'CH3', 'HCO+', 'CH2+', 'C', 'He', 'CH+', 'CO', 'OH', 'O', 'H2',
                   'H', 'e-']


def _text(path):
    with open(path) as f:
        return f.read()


def _z(el):
    """an element's atomic number, from its symbol or the number itself"""
    return ELEMENTS.index(el) + 1 if isinstance(el, str) else int(el)


def ion_label(el, charge):
    """'O', 'O+', 'O2+' ..."""
    el = el if isinstance(el, str) else ELEMENTS[int(el) - 1]
    return el if charge == 0 else el + '+' if charge == 1 else f'{el}{charge}+'


# -------------------------------------------------------------------------------------- composition
def composition(run='.'):
    """the switched-on elements and their abundances (per H), in Z order, from input/input.in's
    nebComposition file; an element is on when its abundance exceeds 1e-12, as in composition_mod.f90"""
    inp = _text(os.path.join(run, 'input', 'input.in'))
    if re.search(r'^\s*multiChemistry', inp, re.M):
        raise ValueError('mocread reads single-composition models: input/input.in has multiChemistry')
    m = re.search(r'^\s*nebComposition\s+"?([^"\s]+)"?', inp, re.M)
    if not m:
        raise ValueError('mocread needs nebComposition: input/input.in has none')
    vals = [float(ln.split()[0]) for ln in _text(os.path.join(run, m.group(1))).splitlines() if ln.split()][:30]
    return {ELEMENTS[i]: v for i, v in enumerate(vals) if v > 1e-12}


# --------------------------------------------------------------------------------------------- grid
class Grid:
    """the grid and the gas of a run. Arrays are (nx, ny, nz), in grid0.out's i, j, k order.

    x, y, z     the axes [cm]
    active      grid0.out's active-cell index (0 or less outside the nebula)
    converged   grid0.out's lgConverged
    black       grid0.out's lgBlack >= 1 (a cell set aside by the code)
    Te, ne, nH  grid1.out: T_e [K], n_e and the hydrogen density [cm^-3]
    r           distance from the grid origin [cm], where the star sits in a symmetric model
    mask        active cells that are not flagged black
    elements    the switched-on elements, in grid2.out's order
    abundances  their abundances per H
    """

    def __init__(self, run, nx, ny, nz, x, y, z, flags, g1, g2, abundances):
        self.run = run
        self.nx, self.ny, self.nz = nx, ny, nz
        self.x, self.y, self.z = x, y, z
        shape = (nx, ny, nz)
        self.active = flags[:, 0].reshape(shape)
        self.converged = flags[:, 1].reshape(shape) > 0
        self.black = flags[:, 2].reshape(shape) >= 1
        self.Te = g1[:, 0].reshape(shape)
        self.ne = g1[:, 1].reshape(shape)
        self.nH = g1[:, 2].reshape(shape)
        X, Y, Z = np.meshgrid(x, y, z, indexing='ij')
        self.r = np.sqrt(X ** 2 + Y ** 2 + Z ** 2)
        self.mask = (self.active > 0) & ~self.black
        self.elements = list(abundances)
        self.abundances = abundances
        self._g2 = g2
        self._frac = {}

    def frac(self, el, charge):
        """the fraction of element el (a symbol) in the stage of this charge, per grid point"""
        if el not in self._frac:
            li, ne = self.elements.index(el), len(self.elements)
            self._frac[el] = np.array([ln.split() for ln in self._g2[li::ne]], float)
        a = self._frac[el]
        if not 0 <= charge < a.shape[1]:
            raise ValueError(f'grid2.out holds charges 0 to {a.shape[1] - 1} of {el}, not {charge}')
        return a[:, charge].reshape(self.nx, self.ny, self.nz)


def read_grid(run='.'):
    """grid0.out, grid1.out and grid2.out of a run, and its composition"""
    out = os.path.join(run, 'output')
    t = _text(os.path.join(out, 'grid0.out')).split()
    if int(t[0]) != 1:
        raise ValueError(f'multi-grid models are not supported: grid0.out has {t[0]} grids')
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    n = nx * ny * nz
    off = 7 + nx + ny + nz
    if len(t) != off + 3 * n:
        raise ValueError(f'grid0.out has {len(t)} numbers, a 3D {nx}x{ny}x{nz} grid writes {off + 3 * n}: '
                         'a 2D model, or a compiler that wraps list-directed lines (ifort), is not supported')
    x = np.array(t[7:7 + nx], float)
    y = np.array(t[7 + nx:7 + nx + ny], float)
    z = np.array(t[7 + nx + ny:off], float)
    flags = np.array(t[off:], int).reshape(n, 3)
    g1 = np.loadtxt(os.path.join(out, 'grid1.out'), ndmin=2)
    if g1.shape[1] != 3:
        raise ValueError(f'grid1.out has {g1.shape[1]} columns, not 3 (multiChemistry is not supported)')
    abundances = composition(run)
    g2 = _text(os.path.join(out, 'grid2.out')).rstrip('\n').split('\n')
    if len(g2) != n * len(abundances):
        raise ValueError(f'grid2.out has {len(g2)} lines, not {n} points x {len(abundances)} elements')
    return Grid(run, nx, ny, nz, x, y, z, flags, g1, g2, abundances)


# -------------------------------------------------------------------------------------------- lines
# lineFlux.out's rows without lgDebug, as output_mod.f90 writes them (HI :1493, HeI :1514, HeII :1536,
# heavy ions :1584); the heavy ions' stage is converted to a charge
_SECTIONS = [('HeII recombination lines', 'heii'), ('HeI recombination lines', 'hei'),
             ('HI recombination lines', 'hi'), ('Heavy ions forbidden lines', 'heavy')]
_DTYPES = {
    'hi': [('nup', int), ('nlow', int), ('rel', float), ('iline', int), ('wav_air', float)],
    'hei': [('l', int), ('wav', float), ('rel', float), ('iline', int)],
    'heii': [('nup', int), ('nlow', int), ('rel', float), ('iline', int), ('wav_air', float)],
    'heavy': [('Z', int), ('charge', int), ('lo', int), ('up', int), ('wav', float), ('rel', float), ('iline', int)],
}


def _row(sec, q):
    if sec in ('hi', 'heii') and len(q) == 7:              # 1 2 nup nlow rel iline wav_air; 2 3 ...
        return int(q[2]), int(q[3]), float(q[4]), int(q[5]), float(q[6])
    if sec == 'hei' and len(q) == 6:                       # 2 2 l wav rel iline
        return int(q[2]), float(q[3]), float(q[4]), int(q[5])
    if sec == 'heavy' and len(q) == 7:                     # Z stage lo up wav_vac rel iline
        return int(q[0]), int(q[1]) - 1, int(q[2]), int(q[3]), float(q[4]), float(q[5]), int(q[6])
    return None


class Lines:
    """lineFlux.out, the totals over the nebula. Every rel is the line's intensity over Hbeta's.

    hbeta  Hbeta [erg/s]
    hi     H I recombination lines: nup, nlow, rel, iline, wav_air [A]
    hei    He I recombination lines: l, wav [A], rel, iline
    heii   He II recombination lines: nup, nlow, rel, iline, wav_air [A]
    heavy  the heavy ions' collisionally excited lines: Z, charge, lo, up (levels), wav [A, vacuum], rel, iline
    """

    def __init__(self, hbeta, rows):
        self.hbeta = hbeta
        for sec, dt in _DTYPES.items():
            setattr(self, sec, np.array(rows[sec], dtype=dt))

    def matches(self, el, charge, wmin, wmax):
        """the heavy-ion rows of element el (symbol or Z) in this charge with wmin <= wav <= wmax"""
        h = self.heavy
        return h[(h['Z'] == _z(el)) & (h['charge'] == charge) & (h['wav'] >= wmin) & (h['wav'] <= wmax)]

    def sum(self, el, charge, wmin, wmax):
        """the sum of rel over matches(el, charge, wmin, wmax), or None if nothing matches"""
        m = self.matches(el, charge, wmin, wmax)
        return float(m['rel'].sum()) if len(m) else None


def read_lines(run='.'):
    """lineFlux.out of a run: the totals block, before the first component"""
    txt = _text(os.path.join(run, 'output', 'lineFlux.out')).split('\n')
    end = next((k for k, ln in enumerate(txt) if 'Component:' in ln), len(txt))
    txt = txt[:end]
    hbeta = None
    rows = {sec: [] for sec in _DTYPES}
    sec = None
    for ln in txt:
        if hbeta is None and 'Hbeta [E36 erg/s]:' in ln:
            hbeta = float(ln.split('Hbeta [E36 erg/s]:', 1)[1].split()[0]) * 1e36
        head = next((s for h, s in _SECTIONS if h in ln), None)
        if head:
            sec = head
            continue
        if sec is None:
            continue
        try:
            r = _row(sec, ln.split())
        except ValueError:
            continue
        if r is not None:
            rows[sec].append(r)
    if not rows['heavy']:
        raise ValueError('lineFlux.out has no heavy-ion rows of 7 numbers: lgDebug output is not supported')
    return Lines(hbeta, rows)


# ---------------------------------------------------------------------------- integrated quantities
def _totals(path):
    """the (symbol, charge) -> value rows `elem ion value` of a file's totals block (ion counted from 1)"""
    d = {}
    for ln in _text(path).split('Component :')[0].splitlines():
        q = ln.split()
        if len(q) != 3:
            continue
        try:
            d[(ELEMENTS[int(q[0]) - 1], int(q[1]) - 1)] = float(q[2])
        except ValueError:
            continue
    return d


def mean_te(run='.'):
    """temperature.out, totals: (symbol, charge) -> T_e weighted by n_e n(ion) dV [K]; ('H', 1) is
    T(H+) of summary.out"""
    return _totals(os.path.join(run, 'output', 'temperature.out'))


def ion_fractions(run='.'):
    """ionratio.out, totals: (symbol, charge) -> the fraction of the element in that stage, weighted by
    n_e n_H dV (Harrington), so that each element's fractions sum to 1. The file's header reads
    <ion>/<H+>, which misleads: no value is divided by H+'s. The ratio of two of them,
    ion_fractions()[('He', 1)] / ion_fractions()[('H', 1)], is the integral of n_e x(He+) n_H dV over
    that of n_e x(H+) n_H dV"""
    return _totals(os.path.join(run, 'output', 'ionratio.out'))


def read_sed(run='.'):
    """SED.out: nu [Ryd], lambda [um] and the total F(nu) D^2 [Jy pc^2] (column 3)"""
    rows = []
    for ln in _text(os.path.join(run, 'output', 'SED.out')).splitlines()[3:]:
        if not ln.strip():
            break
        rows.append([float(v) for v in ln.split()[:3]])
    a = np.array(rows, float).reshape(-1, 3)
    return {'nu_ryd': a[:, 0], 'lam_um': a[:, 1], 'total': a[:, 2]}


# ---------------------------------------------------------------------------------------------- PDR
class PDR:
    """pdrGrid.out (v2, D-352). Arrays are (nx, ny, nz), like Grid's.

    chiFUV  the FUV field the chemistry used
    AV      A_V,eff from the star [mag] (pdrRad.out column 1 holds the same)
    cool, heat, heatPE   the chemistry's cooling, heating and photoelectric heating
    """

    def __init__(self, a, shape):
        self.shape = shape
        self.chiFUV, self.AV, self.cool, self.heat, self.heatPE = (a[:, k].reshape(shape) for k in range(5))
        self._ab = a[:, 5:]

    def abundance(self, species):
        """the abundance per H of one of REDUCED_SPECIES"""
        return self._ab[:, REDUCED_SPECIES.index(species)].reshape(self.shape)


def read_pdr(run, grid):
    """pdrGrid.out of a PDR build, on the grid of read_grid"""
    txt = _text(os.path.join(run, 'output', 'pdrGrid.out'))
    head, body = txt.split('\n', 1)
    if not head.startswith('# pdrGrid v2'):
        raise ValueError('pdrGrid.out is not the v2 layout (D-352): its first line is not "# pdrGrid v2"')
    m = re.search(r'(\d+)\s+abundances', head)
    if not m or int(m.group(1)) != len(REDUCED_SPECIES):
        raise ValueError(f'pdrGrid.out has {m.group(1) if m else "no"} abundances per point, '
                         f'not the reduced network\'s {len(REDUCED_SPECIES)}')
    n = grid.nx * grid.ny * grid.nz
    k = 5 + len(REDUCED_SPECIES)
    t = body.split()
    if len(t) != n * k:
        raise ValueError(f'pdrGrid.out has {len(t)} numbers, not {n} points x {k}')
    return PDR(np.array(t, float).reshape(n, k), (grid.nx, grid.ny, grid.nz))


def read_convergence(run='.'):
    """convergence.out (D-391): (names, array), one row per iteration; a value written as *** is nan"""
    lines = _text(os.path.join(run, 'output', 'convergence.out')).splitlines()
    names = lines[1].lstrip('#').split()
    rows = [[np.nan if '*' in v else float(v) for v in ln.split()] for ln in lines[2:] if ln.strip()]
    return names, np.array(rows, float).reshape(-1, len(names))


# --------------------------------------------------------------------------------------------- main
def main():
    run = sys.argv[1] if len(sys.argv) > 1 else '.'
    g = read_grid(run)
    act = g.active > 0
    print(f'grid: {g.nx} x {g.ny} x {g.nz}, {int(act.sum())} active cells, {int((act & g.black).sum())} flagged')
    print('elements:', ' '.join(g.elements))
    ln = read_lines(run)
    print(f'Hbeta: {ln.hbeta:.9g} erg/s')
    print(f'T(H+): {mean_te(run)[("H", 1)]:.2f} K')
    print('strongest heavy-ion lines:')
    print(f'    {"ion":<6} {"lambda vac [A]":>14} {"I/Hbeta":>10}')
    for r in np.sort(ln.heavy, order='rel')[::-1][:8]:
        print(f'    {ion_label(int(r["Z"]), int(r["charge"])):<6} {r["wav"]:>14.4g} {r["rel"]:>10.4g}')
    if os.path.exists(os.path.join(run, 'output', 'pdrGrid.out')):
        p = read_pdr(run, g)
        av = p.AV[g.mask]
        print(f'A_V: {av.min():.4g} to {av.max():.4g} mag')
        print(f'max x(H2) = 2 n(H2)/n_H: {(2 * p.abundance("H2")[g.mask]).max():.4g}')


if __name__ == '__main__':
    main()
