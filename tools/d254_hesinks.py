#!/usr/bin/env python3
"""D-254: the He+ budget - what destroys He+ in the reference, and what we keep.

Answers the two measurements D-246 left open as prerequisites to the 6000 K
chex decision.

(2) MAGNITUDE. Steady state gives n(He+) = P/D. Production P is cosmic-ray
    ionization of He (reaction 297, 6.50E-18 s^-1) in BOTH codes, with the same
    x(He) to four figures, so P cancels and

        x(He+)_ours / x(He+)_ref  =  D_ref / D_ours .

    Our only sink is radiative recombination, Ne*alpha. So decomposing the
    reference's own D on the reference's own abundances says directly how much
    of the excess each missing reaction accounts for - and in particular
    whether He+ + H (reaction 156) closes it alone or only part of it.

(3) IMPOSITION. D-153/D-193 redistribute each linked element over MOCASSIN's
    ionDen ratio before EVERY chemistry call, He included. So the chemistry's
    own x(He+) - which solves all of the sinks below - is overwritten on entry
    and only has pdrChemIter passes to pull back. This compares the value
    MOCASSIN imposes against the value the solver returns in the same cell: if
    they agree, the chemistry never gets to disagree.

Usage:  d254_hesinks.py <run-dir> [<run-dir> ...]
"""
import sys, os, re, numpy as np

SPEC = ['H3+','He+','Mg','H2+','O2','CH5+','CH4+','O+','OH+','Mg+','C+','CH4',
        'H2O+','H3O+','CO+','O2+','CH2','H2O','H+','CH3+','CH','CH3','HCO+',
        'CH2+','C','He','CH+','CO','OH','O','H2','H','e-']
IHE = SPEC.index('He+')
REF = 'benchmarks/pdr/baseline3dpdr'
KNOWN = {'hiipdr': f'{REF}/sec54.pdr.fin', 'v1slab': f'{REF}/v1.pdr.fin',
         'v2slab': f'{REF}/v2.pdr.fin'}
SLABS = ('v1slab', 'v2slab')
RATES = 'dataPDR/rates_reduced.d'
# grid2.out writes ionDen(cell, elem, 1..min(elem+1,nstages)) for each element
# switched on, so H contributes 2 stages and He 3: He I is token 3, He II is 4.
IHE1, IHE2 = 2, 3


# ----------------------------------------------------------------- the network
def read_all():
    """Every reaction in file order, with DUPLICATE assigned exactly as
       source/pdr/read_rates.F90 does: consecutive lines whose three reactants
       AND four products all match are one temperature-split group, and the
       later member's RTMIN is pulled up to the earlier's RTMAX so the ranges
       are adjacent."""
    R = []
    for ln in open(RATES):
        f = [t.strip() for t in ln.split(',')]
        if len(f) < 15:
            continue
        try:
            idx = int(f[0])
        except ValueError:
            continue
        R.append(dict(idx=idx, reac=tuple(f[1:4]), prod=tuple(f[4:8]),
                      a=float(f[8]), b=float(f[9]), g=float(f[10]),
                      tmin=float(f[12]), tmax=float(f[13]), dup=0))
    for i in range(1, len(R)):
        if R[i]['reac'] == R[i-1]['reac'] and R[i]['prod'] == R[i-1]['prod']:
            if R[i-1]['dup'] == 0:
                R[i-1]['dup'] = 1
            R[i]['dup'] = R[i-1]['dup'] + 1
            R[i]['tmin'] = R[i-1]['tmax']
    return R


def k_of(r, T):
    """calc_reac_rates.F90: a rate is ZEROED below RTMIN only for the
       pathological gamma < -200 fits. Every other fit is evaluated at T, with
       T merely CLAMPED up to RTMIN when gamma < 0. Nothing is zeroed above
       RTMAX - for a duplicate group RTMAX only selects which branch applies."""
    if r['g'] < -200.0:
        k = np.where(T < r['tmin'], 0.0,
                     r['a']*(T/300.0)**r['b']*np.exp(-r['g']/np.maximum(T, 1e-3)))
        return k
    Tl = np.maximum(T, r['tmin']) if r['g'] < 0.0 else T
    Tl = np.maximum(Tl, 1e-3)
    return r['a']*(Tl/300.0)**r['b']*np.exp(-r['g']/Tl)


# MOCASSIN's own He+ radiative recombination: radRecFit(z=2,n=2) takes the
# 4-parameter Verner & Ferland branch with rnew(:,2,2) = line 380 of
# data/radrec.dat. Dielectronic is excluded for elem < 3, so this is the total.
HE_VF = (9.356e-10, 0.7892, 4.266e-02, 4.677e+06)


def alpha_moc_he(T):
    a, b, t0, t1 = HE_VF
    tt = np.sqrt(np.asarray(T, dtype=float)/t0)
    return a/(tt*(tt+1.0)**(1.0-b)*(1.0+np.sqrt(np.asarray(T, dtype=float)/t1))**(1.0+b))


def he_sinks(T, nH, ab):
    """Destruction rate of He+ [s^-1] per reaction, over arrays of cells."""
    R = read_all()
    T = np.asarray(T, dtype=float)
    res = {}
    i = 0
    while i < len(R):
        # collect the duplicate group starting here
        j = i
        while j+1 < len(R) and R[j+1]['dup'] > 1 and R[j+1]['dup'] > R[j]['dup']:
            j += 1
        grp = R[i:j+1]
        # which member applies, cell by cell: the first with T <= RTMAX,
        # otherwise the last member of the group
        sel = np.full(T.shape, len(grp)-1, dtype=int)
        chosen = np.zeros(T.shape, dtype=bool)
        for m, r in enumerate(grp):
            take = (~chosen) & (T <= r['tmax'])
            sel[take] = m
            chosen |= take
        for m, r in enumerate(grp):
            if 'He+' not in r['reac']:
                continue
            other = [t for t in r['reac'] if t and t != 'He+']
            # only two-body collisions with a species we have a density for;
            # CRP, PHOTON and the grain '#' channels are not comparable here
            if len(other) != 1 or other[0] not in SPEC:
                continue
            k = np.where(sel == m, k_of(r, T), 0.0)
            res[f"{r['idx']}:He+ +{other[0]}"] = k*ab[:, SPEC.index(other[0])]*nH
        i = j+1
    return res


# ------------------------------------------------------------------- the files
def read_ref(p):
    av, T, nH, ab = [], [], [], []
    for ln in open(p):
        f = ln.split()
        if len(f) < 41:
            continue
        av.append(float(f[2])); T.append(float(f[3])); nH.append(float(f[6]))
        ab.append([float(f[8+j]) for j in range(33)])
    return (np.array(av), np.array(T), np.array(nH), np.array(ab))


def read_run(r):
    # D-254 correction: refuse a cancelled run outright. The first version of
    # this entry quoted a "46x second defect" out of runs/d252-v1slab, whose own
    # INCOMPLETE marker says "4 of 22 iterations ... Do not use" - with
    # pdrStartIter 4 the chemistry had run on the final iteration only. The
    # output files are all present and correctly shaped, so nothing in the data
    # announces the problem; only the marker does. Fail loudly, not silently.
    mk = os.path.join(r, 'INCOMPLETE')
    if os.path.exists(mk):
        raise SystemExit(f"REFUSING {r}: marked INCOMPLETE -\n    "
                         + open(mk).read().strip().replace('\n', '\n    '))
    t = open(f'{r}/output/grid0.out').read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    n = nx*ny*nz; off = 7+nx+ny+nz
    act = np.array(t[off:off+n*3], dtype=float).reshape(n, 3)[:, 0].astype(int)
    p = np.array(open(f'{r}/output/pdrGrid.out').read().split(),
                 dtype=float)[:n*45].reshape(n, 45)
    g1 = np.array(open(f'{r}/output/grid1.out').read().split(),
                  dtype=float)[:n*3].reshape(n, 3)
    g2 = np.array(open(f'{r}/output/grid2.out').read().split(), dtype=float)
    ncol = g2.size//n
    g2 = g2[:n*ncol].reshape(n, ncol)
    return dict(act=act, zone=p[:, 0].astype(int), AV=p[:, 2],
                Tpdr=p[:, 6], ab=p[:, 12:45], Te=g1[:, 0], Ne=g1[:, 1],
                nH=g1[:, 2], ion=g2, ncol=ncol)


def terp(xs, ys, x):
    return np.exp(np.interp(x, xs, np.log(np.maximum(ys, 1e-300))))


# -------------------------------------------------------------------- the work
def main(run, refp):
    av_r, T_r, nH_r, ab_r = read_ref(refp)
    d = read_run(run)
    m = (d['act'] > 0) & (d['zone'] == 1) & (d['AV'] >= av_r[0]) & (d['AV'] <= av_r[-1])
    print(f"\n{'='*74}\n=== {run}   vs {os.path.basename(refp)}")
    print(f"    PDR cells in A_V range: {int(m.sum())}   grid2 tokens/cell: {d['ncol']}")

    # ---- (2) the reference's own He+ budget, on its own abundances -------
    sinks = he_sinks(T_r, nH_r, ab_r)
    rec = [k for k in sinks if k.endswith('+e-')]
    tot = sum(sinks.values())
    recR = sum(sinks[k] for k in rec)
    hi = av_r[-1]
    bands = [(0, .25*hi), (.25*hi, .5*hi), (.5*hi, .75*hi), (.75*hi, hi)]
    print("\n  (2) reference He+ destruction, decomposed [s^-1 per He+ ion]")
    print(f"    {'A_V band':<14}{'T_gas':>7}{'D_total':>10}{'recomb':>10}"
          f"{'157/156 H':>10}{'H2':>10}{'molecular':>11}{'D/D_rec':>9}")
    for lo, up in bands:
        s = (av_r >= lo) & (av_r < up)
        if s.sum() < 2:
            continue
        hR = sum(sinks[k] for k in sinks if k.endswith('+H'))
        h2R = sum(sinks[k] for k in sinks if k.endswith('+H2'))
        molR = tot - recR - hR - h2R
        f = lambda a: np.median(a[s])
        print(f"    {lo:.2f}-{up:<9.2f}{f(T_r):7.1f}{f(tot):10.2e}{f(recR):10.2e}"
              f"{f(hR):10.2e}{f(h2R):10.2e}{f(molR):11.2e}"
              f"{np.median(tot[s]/recR[s]):9.2f}")

    print("\n      per-reaction share of D_total, deepest quarter:")
    s = av_r >= .75*hi
    sh = sorted(((100*np.median(v[s]/tot[s]), k) for k, v in sinks.items()),
                reverse=True)
    for pc, k in sh:
        if pc >= 0.05:
            print(f"        {k:<16}{pc:7.2f}%")

    # ---- our side: Ne*alpha in the same cells ----------------------------
    # MOCASSIN's OWN recombination coefficient, not the network's: radRecFit
    # for z=2,n=2 is the Verner & Ferland He I row, rnew(:,2,2) = line 380 of
    # data/radrec.dat (line 350 of that file is the published V&F hydrogen row,
    # which fixes the offset). At 20 K this is 1.67x LARGER than the network's
    # reaction 243, so using it makes our only sink stronger, not weaker.
    print("\n  (2b) our recombination-only sink against the reference's total")
    print(f"    {'A_V band':<14}{'T_e ours':>9}{'T_pdr':>8}{'Ne ours':>10}"
          f"{'alpha_moc':>11}{'D_ours':>10}{'D_ref':>10}"
          f"{'D_ref/D_ours':>13}{'x(He+) o/r':>12}")
    for lo, up in bands:
        s = m & (d['AV'] >= lo) & (d['AV'] < up)
        if s.sum() < 5:
            continue
        Te = np.median(d['Te'][s]); Tp = np.median(d['Tpdr'][s])
        Nes = np.median(d['Ne'][s])
        al = alpha_moc_he(Te)
        d_ours = al*Nes
        sr = (av_r >= lo) & (av_r < up)
        d_ref = np.median(tot[sr]) if sr.sum() else np.nan
        xo = np.median(d['ab'][s, IHE])
        xr = np.median(terp(av_r, ab_r[:, IHE], d['AV'][s]))
        print(f"    {lo:.2f}-{up:<9.2f}{Te:9.1f}{Tp:8.1f}{Nes:10.2e}{al:11.2e}"
              f"{d_ours:10.2e}{d_ref:10.2e}{d_ref/d_ours:13.2f}{xo/xr:12.2f}")

    # ---- (3) imposed against what the chemistry's own network gives -------
    # The output files CANNOT answer this directly: D-162 re-imposes MOCASSIN's
    # ionization ratio AFTER the solve as well as before, so pdrAbun(He+) is by
    # construction the imposed value and solved/imposed is 1.0000 identically.
    # So evaluate the chemistry's own steady state instead - one production
    # channel (297, He+CRP, the only one) against the full sink list, on OUR
    # cell state (our T, our n_H, our x(H2), our x(e-)).
    print("\n  (3) x(He+): MOCASSIN's imposed value vs the chemistry's own"
          " steady state in the SAME cells")
    ne = d['ion'][:, IHE1]; ni = d['ion'][:, IHE2]
    heTot = d['ab'][:, SPEC.index('He')] + d['ab'][:, IHE]
    imposed = np.where(ne+ni > 0, heTot*ni/np.maximum(ne+ni, 1e-300), np.nan)
    ours = he_sinks(d['Tpdr'], d['nH'], d['ab'])
    Dours = sum(ours.values())
    P = 6.50e-18*(5.0e-17/1.3e-17)*heTot          # reaction 297 * zeta_local
    xchem = np.where(Dours > 0, P/np.maximum(Dours, 1e-300), np.nan)
    # MOCASSIN's balance reduces to ionUp/ionDn = CR/(Ne*alpha) once phot is
    # negligible (D-246 measured it at 4e-4 of the CR term) and chex is gated
    # off. Its CR coefficient is the network's own, so if the imposed value
    # equals this, MOCASSIN is exactly at its own CR-vs-recombination
    # equilibrium and the ENTIRE error is the missing sinks. If it exceeds it,
    # something is also over-IONIZING helium - a separate defect.
    xmoc = P/np.maximum(alpha_moc_he(d['Te'])*d['Ne'], 1e-300)
    print(f"    {'A_V band':<14}{'imposed':>11}{'st/imp':>8}"
          f"{'CR equil':>11}{'imp/CRq':>9}"
          f"{'chem SS':>11}{'imp/chem':>10}{'x(H2) ours':>12}")
    for lo, up in bands:
        s = m & (d['AV'] >= lo) & (d['AV'] < up) & np.isfinite(imposed)
        if s.sum() < 5:
            continue
        im = np.median(imposed[s]); so = np.median(d['ab'][s, IHE])
        xc = np.median(xchem[s]); xm = np.median(xmoc[s])
        print(f"    {lo:.2f}-{up:<9.2f}{im:11.3e}{so/im:8.4f}"
              f"{xm:11.3e}{im/xm:9.2f}{xc:11.3e}{im/xc:10.1f}"
              f"{np.median(d['ab'][s, SPEC.index('H2')]):12.3e}")


args = sys.argv[1:] or ['runs/d252-hiipdr', 'runs/d252-v1slab']
while args:
    run = args.pop(0)
    if args and args[0].endswith('.fin'):
        refp = args.pop(0)
    else:
        refp = next((v for k, v in KNOWN.items() if k in run),
                    None if any(t in run for t in SLABS) else KNOWN['hiipdr'])
    main(run, refp)
