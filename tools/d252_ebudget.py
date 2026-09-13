#!/usr/bin/env python3
"""D-252: who supplies the electrons, ours against the reference, by depth.

D-250 found Mg+ deleted from the chemistry while it carries up to 99.3% of the
reference's electrons in shielded gas. This puts the two budgets side by side
at matched A_V so "our x(e-) is 1.79x the reference" can be attributed to a
donor rather than left as a scalar.

Usage:  d252_ebudget.py <run-dir> [<run-dir> ...]        reference inferred
        d252_ebudget.py <run-dir> <file.pdr.fin>
"""
import sys, os, numpy as np

SPEC = ['H3+','He+','Mg','H2+','O2','CH5+','CH4+','O+','OH+','Mg+','C+','CH4',
        'H2O+','H3O+','CO+','O2+','CH2','H2O','H+','CH3+','CH','CH3','HCO+',
        'CH2+','C','He','CH+','CO','OH','O','H2','H','e-']
REF = 'benchmarks/pdr/baseline3dpdr'
KNOWN = {'hiipdr': f'{REF}/sec54.pdr.fin', 'v1slab': f'{REF}/v1.pdr.fin',
         'v2slab': f'{REF}/v2.pdr.fin'}
# the 3D fixture appears under several run names (d248-tehist,
# d244-species ...); anything not a slab is the sec 5.4 model.
SLABS = ('v1slab', 'v2slab')
DONORS = ['C+', 'Mg+', 'H+', 'He+', 'H3+', 'HCO+', 'H3O+']

def read_ref(p):
    av, ab = [], []
    for ln in open(p):
        f = ln.split()
        if len(f) < 41: continue
        av.append(float(f[2])); ab.append([float(f[8+j]) for j in range(33)])
    return np.array(av), np.array(ab)

def read_run(r):
    t = open(f'{r}/output/grid0.out').read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3]); n = nx*ny*nz; off = 7+nx+ny+nz
    act = np.array(t[off:off+n*3], dtype=float).reshape(n, 3)[:, 0].astype(int)
    p = np.array(open(f'{r}/output/pdrGrid.out').read().split(),
                 dtype=float)[:n*45].reshape(n, 45)
    return act, p[:, 0].astype(int), p[:, 2], p[:, 12:45]

def terp(xs, ys, x):
    return np.exp(np.interp(x, xs, np.log(np.maximum(ys, 1e-300))))

def main(run, refp):
    av_r, ab_r = read_ref(refp)
    act, zone, AV, ab = read_run(run)
    m = (act > 0) & (zone == 1) & (AV >= av_r[0]) & (AV <= av_r[-1])
    ie = SPEC.index('e-')
    print(f"\n=== {run}   vs {os.path.basename(refp)} ===")
    print(f"  PDR cells in range: {int(m.sum())}")
    hi = av_r[-1]
    bands = [(0, .25*hi), (.25*hi, .5*hi), (.5*hi, .75*hi), (.75*hi, hi)]
    hdr = f"  {'A_V band':<13}{'n':>6}{'x(e-) our':>11}{'ref':>11}{'ratio':>7}  "
    hdr += ' '.join(f'{d+" our/ref %":>16}' for d in ['C+', 'Mg+'])
    print(hdr)
    for lo, up in bands:
        s = m & (AV >= lo) & (AV < up)
        if s.sum() < 5: continue
        e_o = np.median(ab[s, ie])
        e_r = np.median(terp(av_r, ab_r[:, ie], AV[s]))
        row = f"  {lo:.2f}-{up:<8.2f}{int(s.sum()):6d}{e_o:11.3e}{e_r:11.3e}{e_o/e_r:7.2f}  "
        for d in ['C+', 'Mg+']:
            j = SPEC.index(d)
            f_o = 100*np.median(ab[s, j])/e_o
            f_r = 100*np.median(terp(av_r, ab_r[:, j], AV[s]))/e_r
            row += f"{f_o:7.1f}/{f_r:<8.1f}"
        print(row)
    s = m & (AV >= .75*hi)
    if s.sum() >= 5:
        print("  deepest quarter, donor shares (ours vs reference):")
        for d in DONORS:
            j = SPEC.index(d)
            f_o = 100*np.median(ab[s, j])/np.median(ab[s, ie])
            f_r = (100*np.median(terp(av_r, ab_r[:, j], AV[s]))
                   / np.median(terp(av_r, ab_r[:, ie], AV[s])))
            print(f"     {d:>5}  ours {f_o:7.2f}%   reference {f_r:7.2f}%")

args = sys.argv[1:] or ['runs/d233-v1slab', 'runs/d233-v2slab', 'runs/d248-tehist']
while args:
    run = args.pop(0)
    if args and args[0].endswith('.fin'):
        refp = args.pop(0)
    else:
        refp = next((v for k, v in KNOWN.items() if k in run),
                    None if any(t in run for t in SLABS)
                    else KNOWN['hiipdr'])
    main(run, refp)
