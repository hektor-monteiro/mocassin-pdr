#!/usr/bin/env python3
"""D-260: per-species A_V profiles of coupled runs against a 3D-PDR reference.

Unlike d196_axis.py (one on-axis column) this uses EVERY active PDR-zone cell
in the grid and bins them in A_V, so each profile carries its cell-to-cell
spread as well as its median. Pure Python - numpy is not installed.

    grid0.out    header, axes, then (active, ...) triples   - activity mask
    grid1.out    Te, Ne, Hden                               1 line per cell
    pdrGrid.out  pdrZone, chi, AVeff, ..., 33 abundances    2 lines per cell
    pdrRad.out   A_V, totalLines, J bands, Tdust            1 header line

Reference columns (3D-PDR .pdr.fin): idx, x, A_V, Tgas, Tdust, ?, n_H, chi,
then the 33 species in species_reduced.d order.

Usage:  d260_profiles.py <reference.pdr.fin> label=run-dir [label=run-dir ...]
Emits JSON on stdout.
"""
import json
import os
import sys

SPEC = ['H3+', 'He+', 'Mg', 'H2+', 'O2', 'CH5+', 'CH4+', 'O+', 'OH+', 'Mg+',
        'C+', 'CH4', 'H2O+', 'H3O+', 'CO+', 'O2+', 'CH2', 'H2O', 'H+', 'CH3+',
        'CH', 'CH3', 'HCO+', 'CH2+', 'C', 'He', 'CH+', 'CO', 'OH', 'O', 'H2',
        'H', 'e-']
# D-258: slots 3 and 5 are mislabelled upstream (odes_reduced.c treats slot 3
# as CH5+ and slot 5 as H2+); H2+ is not plotted, so the defect cannot enter.
KEEP = ['e-', 'H+', 'He+', 'C+', 'O+', 'Mg+',
        'H', 'H2', 'H3+', 'HCO+', 'CO', 'C', 'OH', 'H2O', 'CH']
A0, A1, DA = 0.45, 3.15, 0.1


def pct(v, q):
    s = sorted(v)
    k = (len(s) - 1) * q
    i = int(k)
    j = min(i + 1, len(s) - 1)
    return s[i] + (s[j] - s[i]) * (k - i)


def sig(x):
    return float(f'{x:.4g}')


def read_run(run):
    if os.path.exists(os.path.join(run, 'INCOMPLETE')):
        raise SystemExit(f'REFUSING {run}: marked INCOMPLETE')
    out = os.path.join(run, 'output')
    t = open(os.path.join(out, 'grid0.out')).read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    n = nx * ny * nz
    off = 7 + nx + ny + nz
    act = [int(float(a)) for a in t[off:off + n * 3:3]]
    g1 = [ln.split() for ln in open(os.path.join(out, 'grid1.out'))]
    p = open(os.path.join(out, 'pdrGrid.out')).read().split()
    pr = [ln.split() for ln in open(os.path.join(out, 'pdrRad.out'))][1:]
    cells = []
    for c in range(n):
        if act[c] <= 0:
            continue
        r = p[c * 45:(c + 1) * 45]
        if int(float(r[0])) != 1:
            continue
        ab = [float(v) for v in r[12:45]]
        d = {'AV': float(r[2]), 'Tgas': float(g1[c][0]),
             'Tdust': float(pr[c][6])}
        for k in KEEP:
            d[k] = ab[SPEC.index(k)]
        cells.append(d)
    return cells


def binned(cells):
    nb = int(round((A1 - A0) / DA))
    res = {'av': [], 'n': []}
    for q in ['Tgas', 'Tdust'] + KEEP:
        res[q] = {'m': [], 'lo': [], 'hi': []}
    for b in range(nb):
        a, z = A0 + b * DA, A0 + (b + 1) * DA
        s = [c for c in cells if a <= c['AV'] < z]
        if len(s) < 5:
            continue
        res['av'].append(sig(sum(c['AV'] for c in s) / len(s)))
        res['n'].append(len(s))
        for q in ['Tgas', 'Tdust'] + KEEP:
            v = [c[q] for c in s]
            res[q]['m'].append(sig(pct(v, 0.5)))
            res[q]['lo'].append(sig(pct(v, 0.16)))
            res[q]['hi'].append(sig(pct(v, 0.84)))
    return res


def read_ref(path):
    rows = [ln.split() for ln in open(path)]
    rows = [r for r in rows if len(r) >= 41]
    step = max(1, len(rows) // 120)
    rows = rows[::step] + ([rows[-1]] if (len(rows) - 1) % step else [])
    ref = {'av': [sig(float(r[2])) for r in rows],
           'Tgas': [sig(float(r[3])) for r in rows],
           'Tdust': [sig(float(r[4])) for r in rows]}
    for k in KEEP:
        j = 8 + SPEC.index(k)
        ref[k] = [sig(float(r[j])) for r in rows]
    return ref


def main():
    ref = read_ref(sys.argv[1])
    out = {'ref': ref, 'runs': {}}
    for arg in sys.argv[2:]:
        lab, run = arg.split('=', 1)
        cells = read_run(run)
        out['runs'][lab] = binned(cells)
        out['runs'][lab]['ncell'] = len(cells)
    json.dump(out, sys.stdout, separators=(',', ':'))


if __name__ == '__main__':
    main()
