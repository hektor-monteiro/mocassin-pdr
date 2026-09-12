#!/usr/bin/env python3
"""D-233: put a run's on-axis PDR profile beside the standalone 3D-PDR §5.4 run.

The reference is written by source/pdr/writeoutputs.F90:83, the ONEDIMENSIONAL
branch, so its 41 columns are

    1 p   2 x   3 AV   4 Tgas   5 Tdust   6 etype   7 rho   8 UVfield
    9..41  the 33 REDUCED-network abundances, species_reduced.d order

A_V is the one depth coordinate both codes compute for themselves, so the
comparison is made there: the reference is interpolated onto the run's A_V and
the ratio reported per species. Where MOCASSIN's own dust puts a different A_V
on the same physical depth, that is a divergence to read, not to correct - the
depth columns are printed alongside so it stays visible.

The V1/V2 slab references (baseline3dpdr/v1.pdr.fin, v2.pdr.fin) are written by
the same branch and share the layout, so --ref points the comparison at them.

Usage:  d233_refcmp.py [--ref <file.pdr.fin>] <run-dir> [<run-dir> ...]
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(HERE, os.pardir, 'benchmarks', 'pdr', 'baseline3dpdr',
                   'sec54.pdr.fin')
SPEC = {'Hep': 2, 'Cp': 11, 'C': 25, 'CO': 28, 'OH': 29, 'H2': 31, 'H': 32}
COLS = ('T', 'Td', 'Hep', 'Cp', 'C', 'CO', 'OH')


def read_ref(path):
    out = {k: [] for k in ('x', 'AV', 'T', 'Td') + tuple(SPEC)}
    with open(path) as fh:
        for line in fh:
            f = line.split()
            if len(f) < 41:
                continue
            out['x'].append(float(f[1]))
            out['AV'].append(float(f[2]))
            out['T'].append(float(f[3]))
            out['Td'].append(float(f[4]))
            for name, j in SPEC.items():
                out[name].append(float(f[8 + j - 1]))
    return out


def interp(xs, ys, x):
    """Linear in x, logarithmic in y where y is positive - abundances span
    twenty decades and a linear interpolation of them is meaningless."""
    if x <= xs[0]:
        return ys[0]
    if x >= xs[-1]:
        return ys[-1]
    lo = 0
    hi = len(xs) - 1
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if xs[mid] <= x:
            lo = mid
        else:
            hi = mid
    t = (x - xs[lo]) / (xs[hi] - xs[lo]) if xs[hi] > xs[lo] else 0.
    a, b = ys[lo], ys[hi]
    if a > 0. and b > 0.:
        from math import exp, log
        return exp(log(a) + t * (log(b) - log(a)))
    return a + t * (b - a)


def axis(run):
    js = subprocess.run([sys.executable, os.path.join(HERE, 'd196_axis.py'),
                         run], capture_output=True, text=True, check=True)
    return json.loads(js.stdout)


def main():
    args = sys.argv[1:]
    path = REF
    if args and args[0] == '--ref':
        path = args[1]
        args = args[2:]
    ref = read_ref(path)
    print(f'reference: {os.path.normpath(path)}')
    for run in args:
        d = axis(run)
        print(f'\n=== {run}   (reference A_V reaches {ref["AV"][-1]:.3f} '
              f'over {ref["x"][-1]:.2f} pc; run reaches {max(d["AV"]):.3f})')
        print(f'{"r/pc":>6} {"A_V":>6} {"zone":>4} ' +
              ' '.join(f'{c:>10} {"ref":>10} {"x/ref":>8}' for c in COLS))
        for i in range(len(d['r'])):
            if d['zone'][i] != 1:
                continue
            av = d['AV'][i]
            row = f'{d["r"][i]/3.0857e18:6.2f} {av:6.3f} {d["zone"][i]:4d} '
            for c in COLS:
                run_v = d[c][i]
                ref_v = interp(ref['AV'], ref[c], av)
                rat = run_v / ref_v if ref_v else float('nan')
                row += f' {run_v:10.3e} {ref_v:10.3e} {rat:8.2e}'
            print(row)


if __name__ == '__main__':
    main()
