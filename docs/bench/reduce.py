#!/usr/bin/env python3
"""Stage A of the benchmark pages: the release runs and their Cloudy references, reduced to small tables.

    python docs/bench/reduce.py [--manifest docs/bench/manifest.toml] [--out DIR]
    python docs/bench/reduce.py --check-cloudy [--manifest ...]
    python docs/bench/reduce.py --verify [--manifest ...]

Reads the runs named in the manifest under the runs root ($MOCASSIN_RUNS, default the production
checkout's runs/) and writes, per product, docs/bench/data/<product>/ (or DIR/<product>/):

    profiles_av.csv     MOCASSIN's cells binned in A_V: quantity, av, n, p16, p50, p84 (long format)
    r_av.csv            the median A_V of the cells at each radius (the figures' upper axis)
    cloudy_profiles.csv Cloudy's zones, the same quantities
    fronts.json         H+/H, H/2H2, C+/C and C/CO, in A_V and in radius, both codes
    lines.csv           the published page's matched line list
    h2lines.csv         Cloudy's strongest H2 lines matched to MOCASSIN's (H-009)
    runcard.json        the manifest's run entry with what the run's own files say
    PROVENANCE.json     sha256 of every file read, the docs checkout's commit, the definitions

Every number is written with %.6g. --check-cloudy compares each committed Cloudy input with the input
of the run the pages use, physics commands only. --verify reduces again into a temporary directory and
compares the result with the committed data, PROVENANCE.json's time stamp and commit aside.

The logic is ported, not reinvented, from the tools the published pages were built with:
tools/d260_roellig.py (read_run, read_cloudy, cloudy_grain_ratio, median_profile, auto_rticks),
tools/d285_kpis_hiipdr.py (cross), tools/h013_figures.py (h2Cells.out, Cloudy's Solomon rate and H2
heating), tools/h009_lines.py (the H2 lines), and the page number scripts nums.py, pnlines.py,
h024_refs_lines.py, nums23.py and nums_d404.py (runs/_scratchpad_backup_2026-10-13). Needs numpy.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
PC = 3.0857e18
SCRIPT_VERSION = 1

# ------------------------------------------------------------------------------------- provenance
READ = {}                                      # label -> sha256 of every file read


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def label(path):
    path = os.path.abspath(path)
    for root, tag in ((RUNS, 'runs:'), (REPO, 'repo:')):
        if path.startswith(root.rstrip('/') + '/'):
            return tag + os.path.relpath(path, root)
    return path


def src(path):
    """a file about to be read: its sha256 goes into PROVENANCE.json"""
    READ[label(path)] = sha256(path)
    return path


def text(path):
    return open(src(path), errors='replace').read()


# --------------------------------------------------------------------------------------- numbers
def g6(v):
    return '' if v is None or not np.isfinite(v) else '%.6g' % v


def j6(o):
    """JSON-ready, every float at %.6g, NaN as null"""
    if isinstance(o, dict):
        return {str(k): j6(v) for k, v in o.items()}
    if isinstance(o, (list, tuple)):
        return [j6(v) for v in o]
    if isinstance(o, (bool, np.bool_)):
        return bool(o)
    if isinstance(o, (int, np.integer)):
        return int(o)
    if isinstance(o, (float, np.floating)):
        return float('%.6g' % o) if np.isfinite(o) else None
    return o


def write_csv(path, header, rows):
    with open(path, 'w', newline='') as f:
        f.write(','.join(header) + '\n')
        for r in rows:
            f.write(','.join(g6(x) if isinstance(x, (float, np.floating)) else str(x) for x in r) + '\n')


def write_json(path, o):
    with open(path, 'w') as f:
        json.dump(j6(o), f, indent=1)
        f.write('\n')


def cross(a, b, xs):
    """where b - a changes sign, linearly in the ordinate xs (tools/d285_kpis_hiipdr.py cross)"""
    f = np.log(np.maximum(b, 1e-300)) - np.log(np.maximum(a, 1e-300))
    o = np.argsort(xs)
    f, xs = np.asarray(f)[o], np.asarray(xs)[o]
    k = np.where(np.diff(np.sign(f)) != 0)[0]
    if not len(k):
        return float('nan')
    k = k[0]
    return xs[k] + (0 - f[k]) / (f[k + 1] - f[k]) * (xs[k + 1] - xs[k])


def median_profile(x, y, edges, nmin=3):
    """tools/d260_roellig.py median_profile: geometric-mean x and median y per bin, NaN where <= 0"""
    xc, med = [], []
    for a, b in zip(edges[:-1], edges[1:]):
        s = (x >= a) & (x < b)
        if s.sum() < nmin:
            continue
        xc.append(np.exp(np.log(x[s]).mean()))
        med.append(np.median(y[s]))
    xc, med = np.array(xc), np.array(med)
    return xc, np.where(med > 0, med, np.nan)


def av_edges(av, a_front):
    """the plan's A_V bins (tools/d260_roellig.py draw): 8 in front of the ionization front, 31 behind"""
    return np.concatenate([np.geomspace(av.min(), a_front * 0.999, 9),
                           np.geomspace(a_front * 0.999, av.max(), 32)[1:]])


def binned(av, y, edges, nmin=3):
    """per bin: geometric-mean A_V, n, p16, p50, p84 of the finite values; bins closed on the left, the
    last one on both sides so that the deepest cell is counted; bins with fewer than nmin cells left out"""
    m = np.isfinite(y)
    av, y = av[m], y[m]
    rows, last = [], len(edges) - 2
    for i, (a, b) in enumerate(zip(edges[:-1], edges[1:])):
        s = (av >= a) & ((av < b) if i < last else (av <= b))
        if s.sum() < nmin:
            continue
        p16, p50, p84 = np.percentile(y[s], [16, 50, 84])
        rows.append((float(np.exp(np.log(av[s]).mean())), int(s.sum()), p16, p50, p84))
    return rows


# ------------------------------------------------------------------------------------- MOCASSIN
# the abundance slots in odes_reduced.c's order (dataPDR/species_reduced.d since D-357; d260_roellig SPEC)
SPEC = ['H3+', 'He+', 'Mg', 'CH5+', 'O2', 'H2+', 'CH4+', 'O+', 'OH+', 'Mg+',
        'C+', 'CH4', 'H2O+', 'H3O+', 'CO+', 'O2+', 'CH2', 'H2O', 'H+', 'CH3+',
        'CH', 'CH3', 'HCO+', 'CH2+', 'C', 'He', 'CH+', 'CO', 'OH', 'O', 'H2',
        'H', 'e-']
LABELS = ['H', 'He', 'Li', 'Be', 'B', 'C', 'N', 'O', 'F', 'Ne', 'Na', 'Mg',
          'Al', 'Si', 'P', 'S', 'Cl', 'Ar', 'K', 'Ca', 'Sc', 'Ti', 'V', 'Cr',
          'Mn', 'Fe', 'Co', 'Ni', 'Cu', 'Zn']
ION = [('x_H+', 'H', 1), ('x_He+', 'He', 1), ('x_He2+', 'He', 2), ('x_C+', 'C', 1), ('x_C2+', 'C', 2),
       ('x_O+', 'O', 1), ('x_O2+', 'O', 2)]
CHEM = ['H', 'H2', 'C', 'O', 'CO', 'OH', 'H2O', 'CH', 'HCO+', 'H3+']
HEAT = [('h2heat_form', 21), ('h2heat_diss', 22), ('h2heat_coll', 23),
        ('pdrheat_form', 24), ('pdrheat_diss', 25), ('pdrheat_pump', 26)]


def read_composition(run):
    """the switched-on elements in grid2.out's order and their abundances, from the run's own
    nebComposition file (d260_roellig read_composition)"""
    inp = text(os.path.join(run, 'input', 'input.in'))
    m = re.search(r'^\s*nebComposition\s+"?([^"\s]+)"?', inp, re.M)
    vals = [float(ln.split()[0]) for ln in text(os.path.join(run, m.group(1))).splitlines() if ln.split()][:30]
    elem = [LABELS[i] for i, v in enumerate(vals) if v > 0]
    return elem, {LABELS[i]: v for i, v in enumerate(vals) if v > 0}


def read_pdrgrid(out, n):
    """pdrGrid.out, v2 (D-352) or v1 (d260_roellig read_pdrgrid)"""
    txt = text(os.path.join(out, 'pdrGrid.out'))
    ns = len(SPEC)
    if txt.startswith('# pdrGrid v2'):
        k = 5
        a = np.array(txt.split('\n', 1)[1].split(), float)[:n * (k + ns)].reshape(n, k + ns)
    else:
        k = 12
        a = np.array(txt.split(), float)[:n * (k + ns)].reshape(n, k + ns)
    return a[:, k:]


def read_h2cells(out):
    """h2Cells.out's rows, the active cells in i,j,k order (h013_figures cells)"""
    rows = [l.replace('|', ' ').split() for l in text(os.path.join(out, 'h2Cells.out')).splitlines()
            if l.strip() and not l.startswith('#')]
    w = min(len(r) for r in rows)
    return np.array([r[:w] for r in rows], float)


def read_run(run):
    """d260_roellig read_run, keeping the ion fractions, n_H, the lgBlack flag and h2Cells.out"""
    if os.path.exists(os.path.join(run, 'INCOMPLETE')):
        raise SystemExit(f'REFUSING {run}: marked INCOMPLETE')
    elem, abund = read_composition(run)
    out = os.path.join(run, 'output')
    t = text(os.path.join(out, 'grid0.out')).split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    xa = np.array(t[7:7 + nx], float)
    ya = np.array(t[7 + nx:7 + nx + ny], float)
    za = np.array(t[7 + nx + ny:7 + nx + ny + nz], float)
    n = nx * ny * nz
    off = 7 + nx + ny + nz
    g0 = np.array(t[off:off + n * 3], float).reshape(n, 3)
    act = g0[:, 0].astype(int) > 0
    X, Y, Z = np.meshgrid(xa, ya, za, indexing='ij')
    r = np.sqrt(X ** 2 + Y ** 2 + Z ** 2).ravel() / PC
    g1 = np.loadtxt(src(os.path.join(out, 'grid1.out')))
    ab = read_pdrgrid(out, n)
    pr = np.loadtxt(src(os.path.join(out, 'pdrRad.out')), skiprows=1)
    g2 = text(os.path.join(out, 'grid2.out')).rstrip('\n').split('\n')
    ne = len(g2) // n
    if ne != len(elem):
        raise SystemExit(f'{run}: grid2.out has {ne} element blocks, the composition {len(elem)}')
    idx = np.where(act)[0]
    nh = g1[idx, 2]

    def frac(el, stage):
        li = elem.index(el)
        out_ = np.empty(len(idx))
        for j, c in enumerate(idx):
            q = g2[c * ne + li].split()
            out_[j] = float(q[stage]) if len(q) > stage else 0.0
        return out_

    d = {'AV': pr[idx, 0], 'r': r[idx], 'Te': g1[idx, 0], 'Tdust': pr[idx, 6], 'e-': g1[idx, 1], 'nh': nh,
         'flag': g0[idx, 2] > 0, 'n_grid': n, 'shape': (nx, ny, nz)}
    for key, el, st in ION:
        d[key] = frac(el, st)
    # atoms and ions are MOCASSIN's in every cell, the molecules the chemistry's (d260_roellig, D-352)
    d['H+'] = d['x_H+'] * abund['H'] * nh
    for key in ('H', 'C', 'O'):
        d[key] = frac(key, 0) * abund[key] * nh
    for key in ('H2', 'CO', 'OH', 'H2O', 'CH', 'HCO+', 'H3+'):
        d[key] = ab[idx, SPEC.index(key)] * nh
    d['C+'] = d['x_C+'] * abund['C'] * nh
    # the hydrogen nuclei as the page figures count them (h013_figures model, d402figs)
    d['nH'] = d['H'] + d['H+'] + 2 * d['H2']
    f = os.path.join(out, 'h2Cells.out')
    if os.path.exists(f):
        c = read_h2cells(out)
        rc = np.sqrt((c[:, 4:7] ** 2).sum(1)) / PC
        if len(rc) != len(d['r']) or np.max(np.abs(rc - d['r'])) > 1e-4 * max(rc.max(), 1e-30):
            raise SystemExit(f'{run}: h2Cells.out and the grid files do not line up')
        d['h2cells'] = c
    return d


def mocassin_quantities(d):
    """per cell, every quantity of profiles_av.csv"""
    q = {'Te': d['Te'], 'Tdust': d['Tdust'], 'ne_nH': d['e-'] / d['nH']}
    for key, _, _ in ION:
        q[key] = d[key]
    for key in CHEM:
        q[key] = d[key] / d['nH']
    if 'h2cells' in d:
        c = d['h2cells']
        # the photodissociation rate per H2 molecule the chemistry used: the levels' (h013 stage B)
        q['sol_h2'] = np.where(c[:, 9] > 0, c[:, 9], np.nan)
        # the H2 heating terms over MOCASSIN's heating at its balance point (h013 heating, H-012 columns)
        heat = c[:, 27]
        ok = heat > 0
        for key, col in HEAT:
            q[key] = np.where(ok, c[:, col] / np.where(ok, heat, 1.), np.nan)
    return q


# ---------------------------------------------------------------------------------------- Cloudy
def table(prefix, ext):
    f = f'{prefix}.{ext}'
    if not os.path.exists(f):
        return None, None
    with open(src(f)) as fh:
        h = [x.strip() for x in fh.readline().lstrip('#').rstrip('\n').split('\t')]
    return h, np.loadtxt(f, comments='#', delimiter='\t', ndmin=2)


def cloudy_grain_ratio(prefix, slope=-3.5):
    """amax/amin of Cloudy's grains from the <D/G> per bin of its listing (d260_roellig, D-319)"""
    m = re.findall(r'^ <D/G>:(.*)$', text(f'{prefix}.out'), re.M)
    if not m:
        return None
    dg = np.array(m[0].split(), float)
    if len(dg) < 2 or (dg <= 0).any():
        return None
    r = dg[1:] / dg[:-1]
    if r.std() / r.mean() > 1e-3:
        return None
    return float(r.mean() ** (len(dg) / (slope + 4)))


def read_cloudy(prefix, rin):
    """d260_roellig read_cloudy with n(H2) = H2 + H2* from .dens389 (nums23 read_cloudy_total), and
    h013_figures cloudy's Solomon rate and H2 photodissociation heating"""
    hd, dens = table(prefix, 'dens')
    ho, ovr = table(prefix, 'ovr')
    hg, gt = table(prefix, 'gtemp')
    d = {'depth': dens[:, 0], 'AV': ovr[:, ho.index('AV(point)')], 'Te': ovr[:, ho.index('Te')]}
    for j, name in enumerate(hd[1:], start=1):
        if name:
            d[name] = dens[:, j]
    # Cloudy's own ionization fractions, n(X^i)/n(X), as MOCASSIN's grid2.out gives them
    for key, col in (('x_H+', 'HII'), ('x_He+', 'HeII'), ('x_He2+', 'HeIII'), ('x_C+', 'C2'), ('x_C2+', 'C3'),
                     ('x_O+', 'O2'), ('x_O2+', 'O3')):
        d[key] = ovr[:, ho.index(col)]
    # MOCASSIN's Tdust is the number-weighted mean over its size bins; Cloudy's bins the same way
    slope = -3.5
    k = cloudy_grain_ratio(prefix, slope)
    amin, amax = (1.0, k) if k is not None else (0.005, 0.25)
    nb = gt.shape[1] - 1
    edges = np.geomspace(amin, amax, nb + 1)
    w = edges[:-1] ** (slope + 1) - edges[1:] ** (slope + 1)
    d['Tdust'] = gt[:, 1:] @ (w / w.sum())
    h9, t9 = table(prefix, 'dens389')
    if h9 is not None:
        t9 = t9[-len(d['H2']):]
        d['H2'] = t9[:, h9.index('H2')] + t9[:, h9.index('H2*')]
    d['r'] = (rin + d['depth']) / PC
    d['nH'] = d['H'] + d['H+'] + 2 * d['H2']
    hs, g = table(prefix, 'H2de')
    hss, s = table(prefix, 'H2sde')
    if hs is not None and 'PHOTON,H2=>H,H' in hs and len(g) == len(d['AV']):
        rate = g[:, hs.index('PHOTON,H2=>H,H')].copy()
        if hss is not None and 'PHOTON,H2*=>H,H' in hss and len(s) == len(d['AV']):
            rate += s[:, hss.index('PHOTON,H2*=>H,H')]
        d['sol_h2'] = rate / np.maximum(d['H2'], 1e-300)
    f = f'{prefix}.heat'
    if os.path.exists(f):
        fr = []
        for l in text(f).splitlines():
            if l.startswith('#') or not l.strip():
                continue
            t = l.rstrip('\n').split('\t')
            v = 0.
            for i in range(5, len(t) - 1, 2):
                if t[i].strip() == 'H2dH':
                    v = float(t[i + 1])
            fr.append(v)
        if len(fr) == len(d['AV']):
            d['h2dH_frac'] = np.array(fr)
    return d


def cloudy_quantities(c):
    q = {'Te': c['Te'], 'Tdust': c['Tdust'], 'ne_nH': c['e-'] / c['nH']}
    for key, _, _ in ION:
        q[key] = c[key]
    for key in CHEM:
        q[key] = c[key] / c['nH']
    for key in ('sol_h2', 'h2dH_frac'):
        if key in c:
            q[key] = c[key]
    return q


# ---------------------------------------------------------------------------------------- fronts
PAIRS = [('H+/H', 'H+', 'H'), ('H/2H2', 'H', '2H2'), ('C+/C', 'C+', 'C'), ('C/CO', 'C', 'CO')]


def fronts(d, c):
    """MOCASSIN: medians in 59 log A_V bins (nums.py kpi_hii/kpi_pn) and in 60 radial shells (nums23
    radii); Cloudy: its zones. A crossing is the first one outward; null where there is none."""
    d = dict(d, **{'2H2': 2 * d['H2']})
    c = dict(c, **{'2H2': 2 * c['H2']})
    ab = np.geomspace(max(d['AV'].min(), 1e-3), d['AV'].max(), 60)
    re_ = np.linspace(0, d['r'].max() * 1.0001, 61)

    def rprof(key):
        x, y = [], []
        for a, b in zip(re_[:-1], re_[1:]):
            s = (d['r'] >= a) & (d['r'] < b)
            if s.sum() >= 3:
                x.append(np.exp(np.log(np.maximum(d['r'][s], 1e-9)).mean()))
                y.append(np.median(d[key][s]))
        return np.array(x), np.array(y)

    o = {'mocassin': {'av': {}, 'r_pc': {}}, 'cloudy': {'av': {}, 'r_pc': {}}}
    for name, a, b in PAIRS:
        xa, ma = median_profile(d['AV'], d[a], ab)
        _, mb = median_profile(d['AV'], d[b], ab)
        o['mocassin']['av'][name] = cross(ma, mb, xa)
        xr, ra = rprof(a)
        o['mocassin']['r_pc'][name] = cross(ra, rprof(b)[1], xr)
        o['cloudy']['av'][name] = cross(c[a], c[b], c['AV'])
        o['cloudy']['r_pc'][name] = cross(c[a], c[b], c['r'])
    return o


# ----------------------------------------------------------------------------------------- lines
# Cloudy's listing: the last iteration's intrinsic block (h024_refs_lines PAT)
PAT = re.compile(r'([A-Za-z][A-Za-z0-9+]*(?: {1,2}[A-Za-z0-9+]+)?)\s+(\d[\d.]*[mAc]|0)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)')


def cloudy_listing(prefix):
    txt = text(prefix + '.out')
    i = txt.rfind('Intrinsic line intensities')
    j = txt.find('Emergent line intensities', i)
    k = txt.find('Intrinsic line intensities', j)
    k = len(txt) if k < 0 else k
    L, E = {}, {}
    for d, a, b in ((L, i, j), (E, j, k)):
        for line in txt[a:b].splitlines()[1:]:
            for m in PAT.finditer(line):
                d[(' '.join(m.group(1).split()), m.group(2))] = float(m.group(3))
    return L, E


# hiipdr: (label, nums.py lines_hii key, Cloudy line of h024_refs_lines WANT)
HII = [('[C II] 158', 'CII158', ('C 2', '157.636m')), ('[O I] 63', 'OI63', ('O 1', '63.1679m')),
       ('[O I] 145', 'OI145', ('O 1', '145.495m')), ('[C I] 609', 'CI609', ('C 1', '609.590m')),
       ('[C I] 370', 'CI370', ('C 1', '370.269m')), ('C II] 2326', 'CII2326', ('C 2', '2326.00A')),
       ('[O I] 6300', 'OI6300', ('O 1', '6300.30A')), ('CO 1-0', 'CO10', ('CO', '2600.05m')),
       ('CO 2-1', 'CO21', ('CO', '1300.05m')), ('CO 3-2', 'CO32', ('CO', '866.727m'))]


def lines_hii(run, prefix):
    """MOCASSIN: nums.py lines_hii (d378_lines); Cloudy: h024_refs_lines lines; Hbeta in 1e36 erg/s"""
    t = text(os.path.join(run, 'output', 'lineFlux.out'))
    hb = float(re.search(r'Hbeta \[E36 erg/s\]:\s+(\S+)', t).group(1))
    rows = {}
    for l in t.split('Heavy ions forbidden lines')[1].split('Component')[0].splitlines():
        q = l.split()
        if len(q) == 7:
            try:
                rows[(int(q[0]), int(q[1]), int(q[2]), int(q[3]))] = float(q[5])
            except ValueError:
                pass
    mol = {}
    for l in text(os.path.join(run, 'output', 'lineFluxMol.out')).splitlines():
        if l.startswith('#') or not l.strip():
            continue
        q = l.split()
        if q[0] == '12co.dat':
            mol[(int(q[1]), int(q[2]))] = float(q[6])
    g = lambda k: rows.get(k, 0.)                                              # noqa: E731
    mo = {'OI63': g((8, 1, 1, 2)), 'OI145': g((8, 1, 2, 3)), 'CII158': g((6, 2, 1, 2)),
          'CI609': g((6, 1, 1, 2)), 'CI370': g((6, 1, 2, 3)),
          'CII2326': sum(g((6, 2, a, b)) for a in (1, 2) for b in (3, 4, 5)), 'OI6300': g((8, 1, 1, 4)),
          'CO10': mol.get((2, 1), 0), 'CO21': mol.get((3, 2), 0), 'CO32': mol.get((4, 3), 0)}
    L, E = cloudy_listing(prefix)
    chb = L[('H 1', '4861.32A')]
    out = [('Hbeta', '4861.32A', hb, 10 ** (chb - 36), '1e36 erg/s')]
    for lab, key, w in HII:
        if key == 'CII2326':
            cl = sum(10 ** (v - chb) for (lb, ww), v in L.items()
                     if lb == 'C 2' and ww.endswith('A') and 2320 < float(ww[:-1]) < 2330)
        elif w in L:
            cl = 10 ** (L[w] - chb)
        elif w in E and w[1].endswith('m') and float(w[1][:-1]) > 30:
            cl = 10 ** (E[w] - chb)                       # far-IR: emergent = intrinsic (D-362)
        else:
            cl = float('nan')
        out.append((lab, w[1], mo[key], cl, 'L/Hbeta'))
    return out


# pn150k: pnlines.py FORB (element, ion, vacuum window [A]) and nums23 PNMAP (Cloudy's line), in the order
# of the published page's line table (build_pn28 PLAB)
PN = [('He I 5876', None, ('Blnd', '5875.66A')), ('He II 4686', None, ('He 2', '4685.68A')),
      ('[O III] 5007', (8, 3, 5007, 5010), ('O 3', '5006.84A')), ('[O III] 4363', (8, 3, 4363, 4366), ('O 3', '4363.21A')),
      ('[O III] 88', (8, 3, 8.7e5, 8.9e5), ('O 3', '88.3323m')), ('[O IV] 25.9', (8, 4, 2.55e5, 2.62e5), ('O 4', '25.8863m')),
      ('[Ne V] 24.3', (10, 5, 2.40e5, 2.46e5), ('Ne 5', '24.3108m')),
      ('[Ne III] 3869', (10, 3, 3868, 3872), ('Ne 3', '3868.76A')),
      ('[Ne III] 15.6', (10, 3, 1.54e5, 1.57e5), ('Ne 3', '15.5509m')),
      ('[Ne II] 12.8', (10, 2, 1.27e5, 1.29e5), ('Ne 2', '12.8101m')),
      ('[S IV] 10.5', (16, 4, 1.04e5, 1.06e5), ('S 4', '10.5076m')),
      ('[S III] 18.7', (16, 3, 1.85e5, 1.89e5), ('S 3', '18.7078m')),
      ('[S II] 6716', (16, 2, 6716, 6720), ('S 2', '6716.44A')), ('[S II] 6731', (16, 2, 6731, 6735), ('S 2', '6730.82A')),
      ('[Ar III] 7135', (18, 3, 7136, 7139), ('Ar 3', '7135.79A')),
      ('[Cl III] 5518', (17, 3, 5518, 5521), ('Cl 3', '5517.71A')),
      ('[N II] 6584', (7, 2, 6584, 6587), ('N 2', '6583.45A')), ('[N II] 122', (7, 2, 1.20e6, 1.24e6), ('N 2', '121.769m')),
      ('[O II] 3726', (8, 2, 3726, 3728), ('O 2', '3726.03A')), ('[O II] 3729', (8, 2, 3729, 3731), ('O 2', '3728.81A')),
      ('[O I] 6300', (8, 1, 6299, 6305), ('O 1', '6300.30A')), ('C II] 2326', (6, 2, 2320, 2331), ('Blnd', '2326.00A')),
      ('[C I] 9824+9850', (6, 1, 9820, 9855), ('Blnd', '9850.00A')),
      ('[C II] 158', (6, 2, 1.55e6, 1.6e6), ('C 2', '157.636m')), ('[O I] 63', (8, 1, 6.2e5, 6.4e5), ('O 1', '63.1679m')),
      ('[O I] 145', (8, 1, 1.44e6, 1.47e6), ('O 1', '145.495m')), ('[C I] 609', (6, 1, 6.0e6, 6.2e6), ('C 1', '609.590m')),
      ('[C I] 370', (6, 1, 3.6e6, 3.8e6), ('C 1', '370.269m')), ('CO 2-1', 'co', ('CO', '1300.05m'))]


def lines_pn(run, prefix):
    """MOCASSIN: pnlines.py read (H-019); Cloudy: nums23 cloudy_pn_lines; Hbeta in 1e34 erg/s"""
    t = text(os.path.join(run, 'output', 'lineFlux.out')).split('Component:')[0]
    mo = {'Hbeta': 100 * float(re.search(r'Hbeta \[E36 erg/s\]:\s+(\S+)', t).group(1))}
    ana = t.split('Line Ratios :')[0]
    mo['He I 5876'] = float(re.search(r'\n\s+5875\.\d+\s+(\S+)', ana).group(1))
    mo['He II 4686'] = float(re.search(r'HeII 4686\s+(\S+)', ana).group(1))
    rows = []
    for l in t.split('Heavy ions forbidden lines')[1].splitlines():
        q = l.split()
        if len(q) == 7:
            rows.append((int(q[0]), int(q[1]), float(q[4]), float(q[5])))
    for lab, win, _ in PN:
        if isinstance(win, tuple):
            e, i, a, b = win
            mo[lab] = sum(v for (ee, ii, w, v) in rows if ee == e and ii == i and a <= w <= b)
    for l in text(os.path.join(run, 'output', 'lineFluxMol.out')).splitlines():
        q = l.split()
        if q and q[0] == '12co.dat' and (int(q[1]), int(q[2])) in ((3, 2), (5, 4), (7, 6)):
            mo['CO %d-%d' % (int(q[1]) - 1, int(q[2]) - 1)] = float(q[6])
    L, _ = cloudy_listing(prefix)
    chb = L[('H 1', '4861.32A')]
    # this model's listing gives fluxes at its 1 kpc: back to a luminosity, in 1e34 erg/s
    cl_hb = 10 ** chb * 4 * np.pi * (1000 * 3.0857e18) ** 2 / 1e34 if chb < 0 else 10 ** (chb - 34)
    out = [('Hbeta', '4861.32A', mo['Hbeta'], cl_hb, '1e34 erg/s')]
    for lab, _, w in PN:
        out.append((lab, w[1], mo[lab], 10 ** (L[w] - chb) if w in L else float('nan'), 'L/Hbeta'))
    return out


def vac_to_air(lam_um):
    s2 = (1. / lam_um) ** 2
    return lam_um / (1. + 8.34213e-5 + 2.406030e-2 / (130. - s2) + 1.5997e-4 / (38.9 - s2))


def h2lines(run, prefix, top):
    """tools/h009_lines.py main for one run: Cloudy's `top` strongest H2 lines of its intrinsic list of the
    last iteration (.linesint, D-396), matched in wavelength after the air-vacuum conversion to 2e-4;
    each code's line over its own Hbeta"""
    hb, cl = None, []
    for l in text(prefix + '.linesint').splitlines():
        if l.startswith('####'):
            break
        t = l.split()
        if len(t) == 3 and t[0] == 'H2' and t[1][-1] in 'mA':
            cl.append((float(t[1][:-1]) * (1e-4 if t[1][-1] == 'A' else 1.), float(t[2])))
        if len(t) == 4 and t[0] == 'H' and t[1] == '1' and t[2] == '4861.32A':
            hb = float(t[3])
    cl = np.array(cl)
    cl = cl[np.argsort(-cl[:, 1], kind='stable')][:top]
    ours = []
    for l in text(os.path.join(run, 'output', 'lineFluxH2.out')).splitlines():
        if l.startswith('#') or not l.strip():
            continue
        vu, ju, vl, jl = (int(x) for x in l[14:30].split())
        name = ''.join(l[2:14].split())
        name = re.sub(r'([OPQRS]\()', r' \1', name)
        ours.append((float(l[30:44]), vu, ju, vl, jl, float(l[71:85]), name))
    lam_air = np.array([vac_to_air(x[0]) for x in ours])
    rows = []
    for lam, inten in cl:
        j = int(np.argmin(abs(lam_air - lam)))
        if abs(lam_air[j] - lam) > 2e-4 * lam:
            continue
        _, vu, ju, vl, jl, v, name = ours[j]
        rows.append((name, '%.6g' % lam, vu, ju, vl, jl, 'ortho' if ju % 2 else 'para', v, inten / hb, v / (inten / hb)))
    return rows


# --------------------------------------------------------------------------------------- run card
def runcard(run, rman, d, extent):
    log = text(os.path.join(run, 'run.log'))
    summ = text(os.path.join(run, 'output', 'summary.out'))
    cv = text(os.path.join(run, 'output', 'convergence.out')).split('\n')
    m = re.match(r'\s*MOCASSIN version\s+(\S+)', log)
    version = m.group(1) if m else None
    m = re.search(r'random seed =\s+(\d+)\s+\(reproducible at np =\s+(\d+)', log)
    seed, ranks = (int(m.group(1)), int(m.group(2))) if m else (None, None)
    fin = {int(a): b for a, b in re.findall(r'\[Summary\] Iteration\s+(\d+) ; finished at (\S+)', summ)}
    worst = {int(a): (float(b), c) for a, b, c in re.findall(
        r'\[Summary\] Iteration\s+(\d+) ; integrated quantities: largest change over the last \d+ iterations\s+(\S+)% \((.*)\), limit', log)}
    total = {int(a): float(b) for a, b in re.findall(
        r'\[Summary\] Iteration\s+(\d+) ; Total:\s+(\S+)\s+% converged cells over all grids', log)}
    cvh = cv[1].lstrip('#').split()
    trail = []
    for l in cv[2:]:
        if not l.strip():
            continue
        q = l.split()
        it = int(q[cvh.index('it')])
        w = float(q[cvh.index('worst%')])
        trail.append({'it': it, 'finished_at': fin.get(it), 'cells_converged_pct': total.get(it),
                      'worst_change_pct': None if w < 0 else w,
                      'worst_quantity': worst[it][1] if it in worst else None})
    m = re.findall(r'total run time per processor\s+(\S+)', log)
    run_time = m[-1] if m else None
    talk = [l.split('[talk]', 1)[1].strip() for l in log.splitlines() if 'iterateMC: [talk]' in l]
    measured = {'version': version, 'seed': seed, 'ranks': ranks, 'iterations': max(fin) if fin else None,
                'run_time': run_time}
    mism = {k: (rman.get(k), v) for k, v in measured.items() if k in rman and rman.get(k) != v}
    blog = rman.get('build_log')
    built = None
    if blog:
        bl = text(os.path.join(RUNS, blog))
        m = re.search(r'^version\s+(\S+)', bl, re.M)
        built = m.group(1) if m else None
        if 'version' in rman and built != rman['version']:
            mism['build_log version'] = (rman['version'], built)
    # the committed inputs against the run's own
    cdir = os.path.join(REPO, rman['inputs']) if 'inputs' in rman else None
    same = None
    if cdir and os.path.isdir(cdir):
        rdir = os.path.join(run, 'input')
        names = sorted(os.listdir(rdir))
        same = names == sorted(os.listdir(cdir)) and all(
            sha256(src(os.path.join(rdir, f))) == sha256(src(os.path.join(cdir, f))) for f in names)
    return {'manifest': rman, 'measured': measured, 'build_log_version': built, 'mismatch': mism,
            'inputs_identical_to_run': same, 'trail': trail, 'verdict': talk, 'cells': extent,
            'h2_model': 'h2cells' in d}


# ------------------------------------------------------------------------------------------ driver
DEFS = {
    'A_V': 'pdrRad.out column 1, A_V,eff from the star; Cloudy AV(point) of save overview',
    'cells': 'active cells of grid0.out; flagged (lgBlack, grid0.out column 3) cells are set aside from every '
             'statistic and counted in runcard.json cells',
    'A_front': 'the smallest A_V among the cells with x(H+) < 0.3',
    'bins': 'edges geomspace(AVmin, 0.999 A_front, 9) U geomspace(0.999 A_front, AVmax, 32); a bin is '
            '[a, b), the last [a, b]; per bin the geometric-mean A_V of its cells, n, and the 16th, 50th and '
            '84th percentiles; bins with n < 3 are left out',
    'n_H': 'n(H) + n(H+) + 2 n(H2), both codes; Cloudy n(H2) = H2 + H2* (.dens389)',
    'Te': 'K; MOCASSIN grid1.out; Cloudy save overview Te',
    'Tdust': 'K; MOCASSIN pdrRad.out (number-weighted over sizes); Cloudy save grain temperature weighted by '
             'the number of grains per bin of the same power law (d260_roellig)',
    'ne_nH': 'n_e / n_H',
    'x_*': 'n(X^i)/n(X): MOCASSIN grid2.out; Cloudy save overview (HII, HeII, HeIII, C2, C3, O2, O3)',
    'H, H2, C, O, CO, OH, H2O, CH, HCO+, H3+': 'n(i)/n_H; atoms MOCASSIN grid2.out, molecules the chemistry '
                                                '(pdrGrid.out); Cloudy save species densities',
    'sol_h2': 's^-1 per H2; MOCASSIN h2Cells.out Sol(levels); Cloudy (PHOTON,H2=>H,H + PHOTON,H2*=>H,H) / '
              'n(H2 + H2*)',
    'h2heat_*': "h2Cells.out H2 heating per H of the level model (formation, dissociation, collisions within X) "
                "over MOCASSIN's heating, cells with heating > 0",
    'pdrheat_*': "h2Cells.out 3D-PDR's terms (formation, photodissociation, FUV pumping), the same way",
    'h2dH_frac': "Cloudy save heating, the H2 photodissociation heating's fraction (H2dH)",
    'fronts': 'first crossing outward of medians: in A_V 59 log bins geomspace(max(AVmin, 1e-3), AVmax, 60), '
              'in r 60 shells linspace(0, 1.0001 rmax, 61); Cloudy on its zones',
    'r_av': 'median A_V in 40 shells linspace(0, 1.001 rmax, 41), bins with n >= 3',
    'lines': 'each code over its own Hbeta; Hbeta as a luminosity; ratio MOCASSIN / Cloudy; Cloudy from the '
             'last iteration\'s intrinsic block of its listing',
    'h2lines': 'tools/h009_lines.py: Cloudy\'s strongest H2 lines of .linesint, matched to lineFluxH2.out by '
               'wavelength (air), each over its own Hbeta; ratio MOCASSIN / Cloudy',
}


def git_sha():
    try:
        sha = subprocess.run(['git', '-C', REPO, 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip()
        dirty = subprocess.run(['git', '-C', REPO, 'status', '--porcelain', '--', 'docs/bench'],
                               capture_output=True, text=True).stdout.strip() != ''
        return sha or None, dirty
    except OSError:
        return None, None


def reduce_product(name, man, outroot):
    global READ
    READ = {}
    p = man['product'][name]
    rman = dict(man['run'][p['run']])
    cref = man['ref'][p['cloudy']]
    run = os.path.join(RUNS, rman['path'])
    prefix = os.path.join(RUNS, cref['prefix'])
    out = os.path.join(outroot, name)
    os.makedirs(out, exist_ok=True)

    d = read_run(run)
    keep = ~d['flag']
    cells = {k: (v[keep] if isinstance(v, np.ndarray) and v.shape[:1] == keep.shape else v) for k, v in d.items()}
    av = cells['AV']
    a_front = float(av[cells['x_H+'] < 0.3].min())
    extent = {'active': int(len(d['AV'])), 'flagged': int(d['flag'].sum()), 'flagged_av': sorted(d['AV'][d['flag']].tolist()),
              'used': int(keep.sum()), 'av_min': float(av.min()), 'av_max': float(av.max()), 'a_front': a_front,
              'r_min_pc': float(cells['r'].min()), 'r_max_pc': float(cells['r'].max())}

    # profiles_av.csv
    edges = av_edges(av, a_front)
    q = mocassin_quantities(cells)
    rows = []
    for key, y in q.items():
        for b in binned(av, y, edges):
            rows.append((key,) + b)
    write_csv(os.path.join(out, 'profiles_av.csv'), ['quantity', 'av', 'n', 'p16', 'p50', 'p84'], rows)

    # r_av.csv: the upper axis (d260_roellig draw)
    er = np.linspace(0.0, cells['r'].max() * 1.001, 41)
    rr = []
    for a, b in zip(er[:-1], er[1:]):
        s = (cells['r'] >= a) & (cells['r'] < b)
        if s.sum() >= 3:
            rr.append((float(np.exp(np.log(cells['r'][s]).mean())), int(s.sum()), float(np.median(av[s]))))
    write_csv(os.path.join(out, 'r_av.csv'), ['r_pc', 'n', 'av'], rr)

    # cloudy_profiles.csv
    c = read_cloudy(prefix, cref['rin_cm'])
    cq = cloudy_quantities(c)
    cols = ['depth_cm', 'r_pc', 'av'] + list(cq)
    data = [c['depth'], c['r'], c['AV']] + [cq[k] for k in cq]
    write_csv(os.path.join(out, 'cloudy_profiles.csv'), cols,
              [tuple(float(x[i]) for x in data) for i in range(len(c['AV']))])

    # fronts.json
    fr = fronts(cells, c)
    fr['a_front'] = a_front
    write_json(os.path.join(out, 'fronts.json'), fr)

    # lines.csv, h2lines.csv
    ln = lines_hii(run, prefix) if p['lineset'] == 'hii' else lines_pn(run, prefix)
    write_csv(os.path.join(out, 'lines.csv'), ['label', 'wavelength', 'mocassin', 'cloudy', 'ratio', 'normalisation'],
              [(lab, w, float(a), float(b), float(a / b) if np.isfinite(b) and b > 0 else float('nan'), nrm)
               for lab, w, a, b, nrm in ln])
    if os.path.exists(os.path.join(run, 'output', 'lineFluxH2.out')) and os.path.exists(prefix + '.linesint'):
        write_csv(os.path.join(out, 'h2lines.csv'),
                  ['label', 'lambda_air_um', 'vu', 'Ju', 'vl', 'Jl', 'spin', 'mocassin', 'cloudy', 'ratio'],
                  [r[:7] + tuple(float(x) for x in r[7:]) for r in h2lines(run, prefix, p.get('h2_top', 40))])

    # runcard.json
    rc = runcard(run, rman, d, extent)
    rc.update({'product': name, 'title': p['title'], 'run': p['run'],
               'release': man['meta'].get('release'), 'release_commit': man['meta'].get('release_commit'),
               'built_from': man['meta'].get('built_from'), 'built_from_check': man['meta'].get('built_from_check'),
               'cloudy': dict(cref, zones=int(len(c['AV'])), name=p['cloudy']),
               'model_label': 'MOCASSIN-PDR ' + str(man['meta'].get('release', '')),
               'cloudy_label': cref.get('code', 'Cloudy')})
    write_json(os.path.join(out, 'runcard.json'), rc)

    sha, dirty = git_sha()
    write_json(os.path.join(out, 'PROVENANCE.json'), {
        'product': name, 'generated_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'docs_git_sha': sha, 'docs_bench_dirty': dirty,
        'script': {'reduce.py': sha256(os.path.abspath(__file__)), 'version': SCRIPT_VERSION},
        'manifest': {'path': label(ARGS.manifest), 'sha256': sha256(ARGS.manifest)},
        'python': sys.version.split()[0], 'numpy': np.__version__, 'runs_root': RUNS,
        'files_read': dict(sorted(READ.items())), 'definitions': DEFS})
    return rc['mismatch']


# --------------------------------------------------------------------------------- --check-cloudy
def cloudy_commands(path):
    """a Cloudy input's commands, normalised: `init` files expanded, comments, blank lines, `title`,
    `print`, the save prefix and every save (punch) command with its continuation block dropped;
    lower case, single spaces"""
    out, skip = [], None
    for raw in text(path).splitlines():
        s = raw.strip()
        if not s or s.startswith(('#', '//', '%')):
            continue
        low = ' '.join(s.lower().split())
        if skip:
            if low.startswith(skip):
                skip = None
            continue
        m = re.match(r'init\s+"([^"]+)"', low)
        if m:
            out += cloudy_commands(os.path.join(os.path.dirname(path), re.match(r'init\s+"([^"]+)"', s, re.I).group(1)))
            continue
        w = low.split()[0]
        if w in ('title', 'print') or low.startswith(('set save prefix', 'set punch prefix')):
            continue
        if w in ('save', 'punch'):
            # the two saves here that take a list: species (to `end`) and line emissivities (to `end of lines`)
            if 'species densities' in low:
                skip = 'end'
            elif 'emissivity' in low:
                skip = 'end of lines'
            continue
        out.append(low)
    return out


def check_cloudy(man):
    ok = True
    for name, ref in man['ref'].items():
        if 'run_input' not in ref:
            continue
        a = cloudy_commands(os.path.join(REPO, ref['input']))
        b = cloudy_commands(os.path.join(RUNS, ref['run_input']))
        same = a == b
        ok &= same
        print(f'{name}: {ref["input"]} against {ref["run_input"]}: {len(a)} and {len(b)} physics commands, '
              + ('identical' if same else 'DIFFERENT'))
        if not same:
            import difflib
            for l in difflib.unified_diff(a, b, 'committed', 'run', lineterm='', n=0):
                print('    ' + l)
    return ok


# ---------------------------------------------------------------------------------------- --verify
def verify(man):
    root = os.path.join(REPO, man['meta']['data'])
    tmp = tempfile.mkdtemp(prefix='bench-verify-')
    ok = True
    try:
        for name in man['product']:
            reduce_product(name, man, tmp)
            a, b = os.path.join(root, name), os.path.join(tmp, name)
            fa = sorted(os.listdir(a)) if os.path.isdir(a) else []
            fb = sorted(os.listdir(b))
            if fa != fb:
                ok = False
                print(f'{name}: files differ: committed {fa}, reduced {fb}')
            for f in sorted(set(fa) & set(fb)):
                if f == 'PROVENANCE.json':
                    ja, jb = (json.load(open(os.path.join(x, f))) for x in (a, b))
                    for k in ('generated_utc', 'docs_git_sha', 'docs_bench_dirty'):
                        ja.pop(k, None), jb.pop(k, None)
                    same = ja == jb
                else:
                    same = open(os.path.join(a, f), 'rb').read() == open(os.path.join(b, f), 'rb').read()
                ok &= same
                print(f'{name}/{f}: ' + ('identical' if same else 'DIFFERENT'))
    finally:
        shutil.rmtree(tmp)
    return ok


def main():
    global RUNS, ARGS
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--manifest', default=os.path.join(HERE, 'manifest.toml'))
    ap.add_argument('--out', default=None, help='output root (default: the manifest\'s meta.data)')
    ap.add_argument('--check-cloudy', action='store_true')
    ap.add_argument('--verify', action='store_true')
    ARGS = ap.parse_args()
    ARGS.manifest = os.path.abspath(ARGS.manifest)
    with open(ARGS.manifest, 'rb') as f:
        man = tomllib.load(f)
    RUNS = os.path.abspath(os.environ.get(man['meta'].get('runs_root_env', 'MOCASSIN_RUNS'),
                                          man['meta']['runs_root_default']))
    if ARGS.check_cloudy:
        sys.exit(0 if check_cloudy(man) else 1)
    if ARGS.verify:
        sys.exit(0 if verify(man) else 1)
    outroot = os.path.abspath(ARGS.out) if ARGS.out else os.path.join(REPO, man['meta']['data'])
    bad = {}
    for name in man['product']:
        t0 = time.time()
        mism = reduce_product(name, man, outroot)
        print(f'{name}: written {os.path.join(outroot, name)} in {time.time() - t0:.1f} s')
        if mism:
            bad[name] = mism
    if bad:
        print('the manifest disagrees with the runs\' own files:', bad)
        sys.exit(2)


RUNS = ''
ARGS = None
if __name__ == '__main__':
    main()
