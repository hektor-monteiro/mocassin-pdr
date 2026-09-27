#!/usr/bin/env python3
"""D-376: what the resonance-line treatment changes, run B against run A.

  - the emergent SED: total, the 8.15 um bin where Lya used to leave (D-372),
    the dust continuum (15-1000 um) and the far-UV (6-13.6 eV);
  - T_dust (pdrRad.out) in ionized cells (x(H+) > 0.5), in the front
    (0.1-0.5) and in the PDR by A_V band, as medians and B/A;
  - the PDR's FUV field chi by A_V band, B/A;
  - Hbeta, Lya's own row, and the resonance-line table of lineFlux.out;
  - B's per-iteration [D376] destroyed fractions and its last dust budget.

    python tools/d376_resonance.py runs/d366-hii runs/d376-hii
"""
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d365_noise as N

PC = 3.0857e18


def sed(run):
    L = [l.split() for l in open(os.path.join(run, 'output', 'SED.out')).read().splitlines()[3:]]
    a = np.array([[float(x) for x in l[:3]] for l in L if len(l) >= 3 and l[0][0].isdigit()])
    o = np.argsort(a[:, 0])
    nu, lam, F = a[o, 0], a[o, 1], a[o, 2]
    e = np.concatenate([[nu[0]], 0.5 * (nu[1:] + nu[:-1]), [nu[-1]]])
    Lb = 4 * np.pi * F * 1e-23 * PC ** 2 * np.diff(e) * 3.2898e15
    k0 = np.argmin(abs(nu - (1 / 64 - 1 / 225)))
    k = k0 - 2 + int(np.argmax(Lb[k0 - 2:k0 + 3]))
    return {'total': Lb.sum(), '8um': Lb[k], '8um_lam': lam[k],
            'nbr': 0.5 * (Lb[k - 2] + Lb[k + 2]),
            'dust15': Lb[(lam > 15) & (lam < 1000)].sum(),
            'fuv': Lb[(nu > 6 / 13.6057) & (nu < 1.0)].sum()}


def cells(run):
    out = os.path.join(run, 'output')
    d = N.read(out)
    pr = np.loadtxt(os.path.join(out, 'pdrRad.out'), skiprows=1)
    t = open(os.path.join(out, 'grid0.out')).read().split()
    nx = int(t[1]); n = nx ** 3; off = 7 + 3 * nx
    act = np.array(t[off:off + n * 3:3], float).astype(int) > 0
    d['Tdust'] = pr[act, 6]
    return d


def lines(run):
    txt = open(os.path.join(run, 'output', 'lineFlux.out')).read()
    hb = float(re.search(r'Hbeta \[E36 erg/s\]:\s+(\S+)', txt).group(1))
    m = re.search(r'HI 1216 \(Lya\)\s+(\S+)', txt)
    lya = float(m.group(1)) if m else None
    res = re.search(r'Resonance Lines Attenuated by dust absorption\n.*\n((?:.*\n){1,8}?)\s*Line Ratios', txt)
    return hb, lya, (res.group(1).rstrip() if res else None)


def main(A, B):
    sa, sb = sed(A), sed(B)
    print(f"== emergent SED [erg/s]            {os.path.basename(A):>14s} {os.path.basename(B):>14s}   B/A")
    for k, lab in [('total', 'total'), ('8um', f"{sa['8um_lam']:.2f} um bin"), ('nbr', '  its neighbours'),
                   ('dust15', '15-1000 um'), ('fuv', '6-13.6 eV')]:
        print(f"   {lab:30s} {sa[k]:14.4e} {sb[k]:14.4e}   {sb[k] / sa[k]:.4f}")
    print(f"   B - A at 15-1000 um: {sb['dust15'] - sa['dust15']:.3e};  A's 8 um excess over neighbours: "
          f"{sa['8um'] - sa['nbr']:.3e}")

    for r in (A, B):
        hb, lya, res = lines(r)
        print(f"== {r}: Hbeta {hb:.5g} E36" + (f", Lya {lya:.4g} Hbeta" if lya is not None else ", no Lya row"))
        if res:
            print("   resonance lines (uncorrected, escaping) in Hbeta:")
            for l in res.splitlines():
                print("     " + l.strip())

    da, db = cells(A), cells(B)
    print("== T_dust medians             A          B        B/A")
    for lab, fa, fb in [('ionized x(H+)>0.5', da['x(H+)'] > 0.5, db['x(H+)'] > 0.5),
                        ('front 0.1-0.5', (da['x(H+)'] > 0.1) & (da['x(H+)'] <= 0.5),
                         (db['x(H+)'] > 0.1) & (db['x(H+)'] <= 0.5))]:
        ta, tb = np.median(da['Tdust'][fa]), np.median(db['Tdust'][fb])
        print(f"   {lab:22s} {ta:9.3f} {tb:9.3f}   {tb / ta:.4f}   ({fa.sum()} / {fb.sum()} cells)")
    # PDR by A_V band of run A, matched in radius (radius is noise-free)
    rb = N.band_radii(da)
    dr = da['dr']
    print("== PDR by A_V band (A's radii), shell medians of x(H+) < 0.3 cells: T_dust and chi, B/A")
    for (lo, hi), (r0, r1) in zip(N.BANDS, rb):
        c = 0.5 * (r0 + r1)
        sa_ = (np.abs(da['r'] - c) <= dr) & (da['x(H+)'] < 0.3)
        sb_ = (np.abs(db['r'] - c) <= dr) & (db['x(H+)'] < 0.3)
        if sa_.sum() < 3 or sb_.sum() < 3:
            continue
        print(f"   A_V {lo:4.2f}-{hi:4.2f} r {c:6.3f} pc  T_dust {np.median(da['Tdust'][sa_]):7.3f} -> "
              f"{np.median(db['Tdust'][sb_]):7.3f} ({np.median(db['Tdust'][sb_]) / np.median(da['Tdust'][sa_]):.4f})"
              f"   chi {np.median(da['chi'][sa_]):9.3g} -> {np.median(db['chi'][sb_]):9.3g} "
              f"({np.median(db['chi'][sb_]) / np.median(da['chi'][sa_]):.4f})")

    log = os.path.join(B, 'run.log')
    if os.path.exists(log):
        fr = re.findall(r'\[D376\] iteration\s+(\d+): resonance-line packets drawn\s+(\d+), destroyed by dust\s+(\d+), fraction\s+(\S+)', open(log).read())
        if fr:
            print("== B: resonance-line packets destroyed by dust, per iteration")
            print("   " + "  ".join(f"it{int(i)} {float(f):.5f}" for i, _, _, f in fr))
    summ = os.path.join(B, 'output', 'summary.out')
    if os.path.exists(summ):
        blocks = open(summ).read().split('Dust Budgets:')
        if len(blocks) > 1:
            last = blocks[-1].split('Component')[1]
            vals = re.findall(r'Contribution\s+(\d+)\s+(\S+)', last)
            print("== B: last dust budget (share of grain heating; 0 = radiation field, then resLines.dat order)")
            print("   " + "  ".join(f"{i}: {float(v):.4f}" for i, v in vals))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
