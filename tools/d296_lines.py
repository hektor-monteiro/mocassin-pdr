#!/usr/bin/env python3
"""D-296: what transporting the optically thin diffuse lines actually does.

This is the measurement D-292 set out to make and never made. D-292 changed
several things at once and blamed line transport for a destroyed PDR that
D-294 then traced to the `makeElements` reordering; and D-296 found that the
line draw itself was broken anyway - `getNu2` searched a hardcoded `nbins`, so
of `linePDF`'s 26718 entries only the first 600 were reachable and everything
above index 600 collapsed onto line 600. So no run before this one drew lines
correctly.

Two runs, one binary, `MOCASSIN_LINES` the only difference:

  * the FUV field chi in matched radial shells, on against off;
  * the PDR state - mean T_gas, hot-cell fraction, f_mol - which is what
    D-292 reported as destroyed;
  * and, if a Cloudy prefix is given, the field against Cloudy's, both raw
    and with Cloudy's Lya removed (D-291: Cloudy attenuates outward line flux
    by continuum opacity alone, so its deep-PDR Lya is an artifact).

    ~/miniforge3/envs/astro/bin/python tools/d296_lines.py \\
        runs/d296-lines-on runs/d296-lines-off [runs/d290-cloudy-field/150k]

NOTE on baselines: runs/d294-probe-off is NOT a valid control - it is the
D-292 code WITH the `makeElements` reordering, i.e. the destroyed model
(T_mean 7653 K, hot 100%, f_mol 5e-6). runs/d294-probe-bisect is the healthy
one (506 K, 6.6%, f_mol 0.417) but was built from a different binary. The only
clean comparison is two runs of the SAME binary with MOCASSIN_LINES flipped,
which is what the two arguments above are.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R

PC = R.PC
DRAINE_PER_HABING = 1.71
# D-291: H I 1216 is a flat ~46% of Cloudy's PDR field, and is an artifact of
# attenuating outward line flux by continuum opacity alone. D-298 derives this
# from the save file rather than carrying it as a constant; the value here is
# only the fallback when no .ioncont is available.
LYA_FRAC = 0.46
FUV_LO, FUV_HI = 6.0 / 13.6057, 1.0      # 6 - 13.6 eV, in Ryd


def cloudy_lya_fraction(ioncont, zone_frac=0.5):
    """H I's share of Cloudy's 6-13.6 eV field, from `save ionizing continuum
    every zone`.

    Each bin carries a flux and the fractions it is composed of - incident,
    OTS line/continuum, outward line/continuum - plus the label of the line
    that dominates it. H I's share is the outward-line flux in the bins
    labelled `H  1`, over the band total. At 1216.4 A (0.74917 Ryd) that bin
    is outlin = 1.000 and outweighs every other line by a factor 5.

    Removing ALL of it is right for the deep PDR: D-291 showed Cloudy's
    outward line flux is attenuated by continuum opacity alone, so this
    component streams like a 1216 A continuum photon; and D-293 measured, with
    MOCASSIN's own escape formula, that 72-76% of Lya is destroyed by dust
    before it even reaches the front, with the remainder destroyed within
    A_V 0.020 of it. Past the front, physical Lya is nil.
    """
    zones, cur = [], None
    for ln in open(ioncont):
        if ln.startswith('#save every zone'):
            if cur:
                zones.append(cur)
            cur = []
            continue
        if ln.startswith('#') or cur is None:
            continue
        f = ln.rstrip('\n').split('\t')
        if len(f) < 12:
            continue
        try:
            nu, flux, outlin = float(f[1]), float(f[2]), float(f[7])
        except ValueError:
            continue
        if FUV_LO <= nu <= FUV_HI:
            cur.append((flux, outlin, f[11].strip()))
    if cur:
        zones.append(cur)
    if not zones:
        return LYA_FRAC
    z = zones[int(zone_frac * (len(zones) - 1))]
    tot = sum(r[0] for r in z)
    hi = sum(r[0] * r[1] for r in z if r[2].startswith('H  1'))
    return hi / tot if tot > 0 else LYA_FRAC


def fuv(run):
    """chi (Draine units) per active cell, in pdrFUV.out's order."""
    a = np.loadtxt(os.path.join(run, 'output', 'pdrFUV.out'), comments='#')
    return {'r': a[:, 7] / PC, 'chi': a[:, 9], 'chi_thin': a[:, 10],
            'nh': a[:, 8]}


def shells(r, v, edges):
    xc, med = [], []
    for a, b in zip(edges[:-1], edges[1:]):
        s = (r >= a) & (r < b)
        if s.sum() < 3:
            xc.append(np.nan); med.append(np.nan); continue
        xc.append(np.exp(np.log(r[s]).mean()))
        med.append(np.median(v[s]))
    return np.array(xc), np.array(med)


def pdr_state(run):
    d = R.read_run(run)
    pdr = d['zone'] == 1
    if pdr.sum() == 0:
        return None
    T = d['Tgas'][pdr]
    H, H2 = d['H'][pdr], d['H2'][pdr]
    fmol = np.median(2 * H2 / np.maximum(H + 2 * H2, 1e-30))
    return {'n': int(pdr.sum()), 'Tmean': float(T.mean()),
            'hot': float(100.0 * (T > 1000.).mean()), 'fmol': float(fmol),
            'CO': float(np.median(d['CO'][pdr] / d['nh'][pdr]))
            if 'nh' in d else float(np.median(d['CO'][pdr]))}


def main(on, off, cloudy=None):
    a, b = fuv(on), fuv(off)
    edges = np.geomspace(0.12, 0.61, 18)

    print('== FUV field, transport ON against OFF ==')
    print('   %s' % on)
    print('   %s' % off)
    print()
    print('   r[pc]    chi_off    chi_on     on/off')
    xa, ya = shells(a['r'], a['chi'], edges)
    xb, yb = shells(b['r'], b['chi'], edges)
    for x, yo, yf in zip(xb, yb, ya):
        if not np.isfinite(yo) or not np.isfinite(yf):
            continue
        print('   %6.3f  %9.3g  %9.3g  %8.3f' % (x, yo, yf, yf / yo))
    ok = np.isfinite(ya) & np.isfinite(yb)
    print('   -> median ratio over the PDR: %.3f' % np.median(ya[ok] / yb[ok]))

    print('\n== PDR state (the D-292 claim) ==')
    print('   %-28s %8s %8s %8s' % ('', 'cells', 'Tmean', 'hot%'))
    for tag, run in (('transport OFF', off), ('transport ON', on)):
        s = pdr_state(run)
        if s is None:
            print('   %-28s   no PDR zone' % tag); continue
        print('   %-28s %8d %8.1f %8.2f   f_mol %.4f'
              % (tag, s['n'], s['Tmean'], s['hot'], s['fmol']))

    if cloudy:
        import d287_pe as P
        c = P.read_cloudy(cloudy)
        # MOCASSIN's A_V per active cell, in pdrFUV.out's order
        da = R.read_run(on)
        db = R.read_run(off)
        av_edges = np.linspace(0.05, 0.75, 15)

        print('\n== against Cloudy, matched in A_V ==')
        print('   Cloudy %s' % cloudy)
        print('   D-291 measured H I 1216 at a flat %.0f%% of Cloudy\'s PDR'
              % (100 * LYA_FRAC))
        print('   field, and showed it to be an artifact of attenuating')
        print('   outward line flux by continuum opacity alone. "corrected"')
        print('   below is Cloudy with that component removed.')
        print()
        print('   A_V      G0_cl   G0_corr    G0_off     G0_on   on/corr  off/corr')
        for lo, hi in zip(av_edges[:-1], av_edges[1:]):
            mc = (c['AV'] >= lo) & (c['AV'] < hi)
            ma = (da['AV'] >= lo) & (da['AV'] < hi)
            mb = (db['AV'] >= lo) & (db['AV'] < hi)
            if mc.sum() < 2 or ma.sum() < 3 or mb.sum() < 3:
                continue
            gc = np.median(c['G0'][mc])
            gcorr = gc * (1.0 - LYA_FRAC)
            ga = np.median(a['chi'][ma]) * DRAINE_PER_HABING
            gb = np.median(b['chi'][mb]) * DRAINE_PER_HABING
            print('   %5.3f %9.3g %9.3g %9.3g %9.3g %8.3f %9.3f'
                  % (0.5 * (lo + hi), gc, gcorr, gb, ga, ga / gcorr,
                     gb / gcorr))


if __name__ == '__main__':
    main(*sys.argv[1:4])
