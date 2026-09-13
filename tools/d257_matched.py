#!/usr/bin/env python3
"""D-257: compare a coupled run against a chosen 3D-PDR reference.

The point of this tool is that the reference is now a VARIABLE. D-255 measured
that `sec54.pdr.fin` was produced with a prescribed surface field of 61.236
Draine while the hiipdr fixture's own star delivers 165.56 at its ionization
front, so every comparison against it carried a 2.70x boundary-condition
mismatch. The standalone reference can now be rebuilt at any G0 (D-257), so the
same coupled run can be compared against a matched reference.

Two things this tool insists on, both because getting them wrong produced
confident wrong numbers in D-254/D-255/D-256:

  - it states the match variable in the output, and supports both A_V (the
    shielding column, right where dust attenuation dominates) and chi (the
    local field, right near the surface). Neither is correct everywhere.
  - it restricts BOTH sides to the range the model actually samples, rather
    than averaging the reference over depths our grid never reaches.

Usage:  d257_matched.py <run-dir> <reference.pdr.fin> [--on chi|av] [--bands N]
"""
import sys, os, numpy as np

SPEC = ['H3+','He+','Mg','H2+','O2','CH5+','CH4+','O+','OH+','Mg+','C+','CH4',
        'H2O+','H3O+','CO+','O2+','CH2','H2O','H+','CH3+','CH','CH3','HCO+',
        'CH2+','C','He','CH+','CO','OH','O','H2','H','e-']
KEYS = ['H2','H','H+','C+','C','CO','OH','H2O','H3+','H2+','HCO+','e-','Mg+']


def read_ref(p):
    av, uv, tg, nh, ab = [], [], [], [], []
    for ln in open(p):
        f = ln.split()
        if len(f) < 41:
            continue
        av.append(float(f[2])); tg.append(float(f[3]))
        nh.append(float(f[6])); uv.append(float(f[7]))
        ab.append([float(f[8+j]) for j in range(33)])
    return (np.array(av), np.array(uv), np.array(tg), np.array(nh),
            np.array(ab))


def read_run(r):
    mk = os.path.join(r, 'INCOMPLETE')
    if os.path.exists(mk):                      # D-254 lesson
        raise SystemExit(f"REFUSING {r}: marked INCOMPLETE -\n    "
                         + open(mk).read().strip().replace('\n', '\n    '))
    t = open(f'{r}/output/grid0.out').read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    n = nx*ny*nz; off = 7+nx+ny+nz
    act = np.array(t[off:off+n*3:3], dtype=int)
    p = np.array(open(f'{r}/output/pdrGrid.out').read().split(),
                 dtype=float)[:n*45].reshape(n, 45)
    return dict(act=act, zone=p[:, 0].astype(int), chi=p[:, 1], AV=p[:, 2],
                Tpdr=p[:, 6], ab=p[:, 12:45])


def main(run, refp, on='av', nband=4):
    av_r, uv_r, tg_r, nh_r, ab_r = read_ref(refp)
    d = read_run(run)
    m = (d['act'] > 0) & (d['zone'] == 1)
    if on == 'av':
        xo, xr = d['AV'], av_r
        order = np.argsort(xr)
        label = 'A_V,eff'
    else:
        xo, xr = d['chi'], uv_r
        order = np.argsort(xr)
        label = 'chi (local field)'
        m &= d['chi'] > 0

    lo = max(xo[m].min(), xr.min())
    hi = min(xo[m].max(), xr.max())
    m &= (xo >= lo) & (xo <= hi)
    print(f"\n{'='*78}\n=== {run}\n===   vs {os.path.basename(refp)}"
          f"   matched on {label}")
    print(f"    reference surface field G0 = {uv_r[np.argmin(av_r)]:.4f}"
          f"   A_V max {av_r.max():.4f}")
    print(f"    overlap {lo:.5g} .. {hi:.5g}   cells {int(m.sum())}"
          f"   (BOTH sides restricted to this range)")
    if m.sum() < 20:
        print("    too few cells"); return

    def terp(col, x):
        return np.exp(np.interp(np.log(np.maximum(x, 1e-300)),
                                np.log(np.maximum(xr[order], 1e-300)),
                                np.log(np.maximum(ab_r[order, col], 1e-300))))

    edges = np.exp(np.linspace(np.log(max(lo, 1e-30)), np.log(hi), nband+1)) \
        if on == 'chi' else np.linspace(lo, hi, nband+1)
    hdr = f"    {'band':<18}{'n':>6}" + ''.join(f"{k:>8}" for k in KEYS)
    print(hdr)
    for a, b in zip(edges[:-1], edges[1:]):
        s = m & (xo >= a) & (xo < b)
        if s.sum() < 20:
            continue
        row = f"    {a:7.4g}-{b:<10.4g}{int(s.sum()):6d}"
        for k in KEYS:
            j = SPEC.index(k)
            rr = np.median(terp(j, xo[s]))
            row += f"{np.median(d['ab'][s, j])/max(rr, 1e-300):8.3f}"
        print(row)
    # temperature, which is MOCASSIN's own and not the chemistry's
    s = m
    print(f"    T: ours median {np.median(d['Tpdr'][s]):.2f} K   reference "
          f"{np.median(np.interp(xo[s], xr[order], tg_r[order])):.2f} K")


if __name__ == '__main__':
    a = [x for x in sys.argv[1:] if not x.startswith('--')]
    on = 'chi' if '--on' in sys.argv and 'chi' in sys.argv else 'av'
    nb = 4
    if '--bands' in sys.argv:
        nb = int(sys.argv[sys.argv.index('--bands')+1])
    if len(a) < 2:
        raise SystemExit(__doc__)
    main(a[0], a[1], on, nb)
