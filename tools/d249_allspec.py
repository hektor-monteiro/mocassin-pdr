#!/usr/bin/env python3
"""D-249: compare ALL 33 reduced-network species against the 3D-PDR reference,
at matched A_V, over every PDR-zone cell.

Reference layout (writeoutputs.F90 ONEDIMENSIONAL branch, 41 cols):
  1 p  2 x  3 AV  4 Tgas  5 Tdust  6 etype  7 rho  8 UVfield  9..41 the 33
  abundances in species_reduced.d order.
Run layout: pdrGrid.out is 2 records per cell, 12 scalars then 33 abundances.
A_V is the one depth coordinate both codes compute for themselves.
"""
import sys, numpy as np

SPEC = ['H3+','He+','Mg','H2+','O2','CH5+','CH4+','O+','OH+','Mg+','C+','CH4',
        'H2O+','H3O+','CO+','O2+','CH2','H2O','H+','CH3+','CH','CH3','HCO+',
        'CH2+','C','He','CH+','CO','OH','O','H2','H','e-']

def read_ref(path):
    av, ab, T = [], [], []
    for ln in open(path):
        f = ln.split()
        if len(f) < 41: continue
        av.append(float(f[2])); T.append(float(f[3]))
        ab.append([float(f[8+j]) for j in range(33)])
    return np.array(av), np.array(T), np.array(ab)

def read_run(run):
    t = open(f'{run}/output/grid0.out').read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3]); n = nx*ny*nz
    off = 7 + nx + ny + nz
    act = np.array(t[off:off+n*3], dtype=float).reshape(n,3)[:,0].astype(int)
    p = np.array(open(f'{run}/output/pdrGrid.out').read().split(),
                 dtype=float)[:n*45].reshape(n,45)
    Te = np.loadtxt(f'{run}/output/grid1.out')[:,0]
    return act, p[:,0].astype(int), p[:,2], p[:,12:45], Te

def logterp(xs, ys, x):
    y = np.interp(x, xs, np.log(np.maximum(ys, 1e-300)))
    return np.exp(y)

def run_cmp(run, refpath, label):
    av_r, T_r, ab_r = read_ref(refpath)
    act, zone, AV, ab, Te = read_run(run)
    m = (act > 0) & (zone == 1) & (AV >= av_r[0]) & (AV <= av_r[-1])
    print(f"\n{'='*78}\n{label}\n  run={run}\n  ref={refpath.split('/')[-1]}"
          f"   ref A_V 0..{av_r[-1]:.4f}")
    print(f"  PDR cells inside the reference's A_V range: {int(m.sum())} "
          f"of {int(((act>0)&(zone==1)).sum())} PDR cells")
    if m.sum() == 0: return
    AVm, abm = AV[m], ab[m]
    Tref = logterp(av_r, T_r, AVm)
    print(f"  T_gas ratio  median {np.median(Te[m]/Tref):.3f}")
    print(f"\n  {'species':>6}  {'median x':>11} {'median ref':>11} "
          f"{'med ratio':>10} {'p10':>9} {'p90':>9}")
    rows = []
    for j, name in enumerate(SPEC):
        ref_j = logterp(av_r, ab_r[:, j], AVm)
        ok = (ref_j > 1e-30) & (abm[:, j] >= 0)
        if ok.sum() < 10: continue
        r = abm[ok, j] / ref_j[ok]
        rows.append((np.median(r), name, np.median(abm[ok,j]),
                     np.median(ref_j[ok]), np.percentile(r,10), np.percentile(r,90)))
    for med, name, x, xr, p10, p90 in sorted(rows):
        flag = '  <<<' if (med < 0.2 or med > 5) else ''
        print(f"  {name:>6}  {x:11.3e} {xr:11.3e} {med:10.3f} "
              f"{p10:9.3f} {p90:9.3f}{flag}")

REF = 'benchmarks/pdr/baseline3dpdr'
KNOWN = {'hiipdr': (f'{REF}/sec54.pdr.fin', '3D  H II + PDR (sec 5.4)'),
         'v1slab': (f'{REF}/v1.pdr.fin',    'V1 SLAB  n=1e3, chi=10'),
         'v2slab': (f'{REF}/v2.pdr.fin',    'V2 SLAB  n=1e5, chi=1e3')}

def guess(run):
    """Pick the reference a run dir belongs to from its name, so
    `d249_allspec.py runs/d252-v1slab` needs no second argument."""
    for key, (path, label) in KNOWN.items():
        if key in run:
            return path, f'{label}   [{run}]'
    # D-252: the 3D fixture appears under many run names (d248-tehist,
    # d244-species, ...); anything that is not a slab is the sec 5.4 model.
    if not any(t in run for t in ('v1slab', 'v2slab')):
        return KNOWN['hiipdr'][0], f"{KNOWN['hiipdr'][1]}   [{run}]"
    return None, None

if len(sys.argv) > 1:
    args = sys.argv[1:]
    while args:
        run = args.pop(0)
        if args and args[0].endswith('.fin'):
            refp = args.pop(0); label = run
        else:
            refp, label = guess(run)
            if refp is None:
                print(f'!! cannot infer the reference for {run} - '
                      f'pass it explicitly: {run} <file.pdr.fin>')
                continue
        run_cmp(run, refp, label)
else:
    run_cmp('runs/d248-tehist', f'{REF}/sec54.pdr.fin', '3D  H II + PDR (sec 5.4)')
    run_cmp('runs/d233-v1slab', f'{REF}/v1.pdr.fin', 'V1 SLAB  n=1e3, chi=10')
    run_cmp('runs/d233-v2slab', f'{REF}/v2.pdr.fin', 'V2 SLAB  n=1e5, chi=1e3')
