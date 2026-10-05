#!/usr/bin/env python3
"""H-021 (L-33): MOCASSIN's grain H2 formation coefficient against Cloudy's,
taken apart one ingredient at a time.

R [cm^3 s^-1] is the coefficient per n_H n(H0): H2 forms on grains at
R n_H n(H0) cm^-3 s^-1. Both codes write it as

    R = 1/2 v_H(T) sum_k sigma_k S(T, Td_k) eps_k(Td_k)

  sigma_k  projected grain area per H nucleus of material or size bin k;
  S        sticking, Hollenbach & McKee (1979) eq. 3.7 - the same formula in
           both codes (3D-PDR's h2_form.F90, Cloudy's sticking_probability_H);
  eps      the recombination efficiency of Cazaux & Tielens (2002). Cloudy
           (mole_reactions.cpp, its default 'C') has one parameter set for
           every material: E_S 200, E_HP 600, E_HC 1e4, E_H2 320 K. 3D-PDR's
           h2_form.F90 has one per material: silicate E_S 110, E_HP 450,
           E_H2 320; carbon E_S 260, E_HP 800, E_H2 520; both E_HC 3e4 K;
  Td       Cloudy: each size bin's own (`save grain temperature`). MOCASSIN:
           the cell's mean over sizes (Tdust(0,0), number-weighted), for all
           of them.

MOCASSIN's R is the one its chemistry used (h2Cells.out, column 21), its
areas the run log's [D195] lines. Cloudy's R is its saved channel rates
grn,H,H=>grn,H2 (+ grn,H,H=>grn,H2* where saved) over n_H n(H0), its areas
the grain opacity file's per-bin Int(4 pi a^2) per H over 4, times the
abundance scale of the `grains` command.

The chain at each depth changes one ingredient from MOCASSIN's to Cloudy's,
in this order, so each ratio is that ingredient's share (the order is a
choice: the ingredients multiply, so each ratio is exact for its step):
  M0  MOCASSIN, as run (median of its cells in the A_V bin)
  M1  ... with Cloudy's gas temperature (v_H and S)
  M2  ... with Cloudy's grain temperatures, bin by bin, over Cloudy's area
      distribution (MOCASSIN's efficiency formula, its total area)
  M3  ... with Cloudy's efficiency parameters
  M4  ... with Cloudy's total area: this is Cloudy's formula on Cloudy's
      inputs, to be compared with what Cloudy saved (C)

    python tools/h021_h2form.py <run> <cloudy prefix> <cloudy .opc> <scale> [--av a,b,c]
"""
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R              # noqa: E402
import h013_figures as F              # noqa: E402

PC = 3.0857e18


def v_h(T):
    """mean thermal speed of H atoms, as both codes write it [cm s-1]"""
    return 1.45e5 * np.sqrt(T / 100.)


def sticking(T, Td):
    """Hollenbach & McKee 1979 eq. 3.7, as both codes write it"""
    return 1. / (1. + 0.04 * np.sqrt(T + Td) + 0.2 * (T / 100.) + 0.08 * (T / 100.) ** 2)


def eps_3dpdr(Td, mat):
    """h2_form.F90's Cazaux & Tielens efficiency for 'sil' or 'car'"""
    mu, flux, nu_h2, nu_hc = 0.005, 1e-10, 3e12, 1.3e13
    if mat == 'sil':
        es, eh2, ehp, ehc = 110., 320., 450., 3e4
    else:
        es, eh2, ehp, ehc = 260., 520., 800., 3e4
    sq = (1. + np.sqrt((ehc - es) / (ehp - es))) ** 2
    f1 = mu * flux / (2 * nu_h2 * np.exp(-eh2 / Td))
    f2 = sq / 4. * np.exp(-es / Td)
    xi = 1. / (1. + nu_hc / (2 * flux) * np.exp(-1.5 * ehc / Td) * sq)
    return xi / (1. + f1 + f2)


def eps_cloudy(Td):
    """Cloudy's default Cazaux & Tielens 2002 efficiency (no quantum heating branch)"""
    f = 1e-10
    sq = 35.399494936611667          # (1 + sqrt((1e4 - 200)/(600 - 200)))^2
    ba = 0.25 * sq * np.exp(-200. / Td)
    xi = 1. / (1. + 1.3e13 * np.exp(-1.5e4 / Td) * sq / (2. * f))
    beta = 3e12 * np.exp(-320. / Td)
    return beta * xi / (beta + 0.0025 * f + beta * ba)


def table(path):
    with open(path) as fh:
        head = [h.strip() for h in fh.readline().lstrip('#').rstrip('\n').split('\t')]
    return head, np.loadtxt(path, comments='#', delimiter='\t', ndmin=2)


def opc_areas(path):
    """per size bin: total grain area Int(4 pi a^2) per H [cm2/H] at the file's abundance"""
    txt = open(path).read()
    return np.array([float(m) for m in re.findall(
        r'^\s*([0-9.eE+-]+)\s+# total grain area Int\(4pi\*a\^2\) per H, this bin', txt, re.M)])


def moc_areas(run):
    t = open(os.path.join(run, 'run.log')).read()
    sil = float(re.search(r'silicate\s+=\s+(\S+)\s+cm\^2/H', t).group(1))
    car = float(re.search(r'carbonaceous\s+=\s+(\S+)\s+cm\^2/H', t).group(1))
    return sil, car


def main(run, cpre, opc, scale, avs=None):
    # ---------------------------------------------------------------- MOCASSIN
    d = F.model(run)
    c = d['cells']
    RM = c[:, 20]
    T = d['Tgas']
    Td = d['Tdust']
    sil, car = moc_areas(run)
    mat = 'sil' if sil > 0 else 'car'
    sigM = sil + car
    # the coefficient rebuilt from its ingredients, against what the code used
    Rre = 0.5 * v_h(T) * (sil * eps_3dpdr(np.maximum(Td, 2.7), 'sil')
                          + car * eps_3dpdr(np.maximum(Td, 2.7), 'car')) * sticking(T, Td)
    ok = RM > 0
    q = Rre[ok] / RM[ok]
    print(f'MOCASSIN {run}: {ok.sum()} cells with R > 0; area per H {sigM:.4e} cm2 ({mat});'
          f' R rebuilt / R used: median {np.median(q):.5f}, 1-99% {np.percentile(q, 1):.5f}-{np.percentile(q, 99):.5f}')

    # ---------------------------------------------------------------- Cloudy
    ho, ovr = table(cpre + '.ovr')
    hd, dens = table(cpre + '.dens')
    hg, gt = table(cpre + '.gtemp')
    hc, cr = table(cpre + '.H2cr')
    rate = cr[:, hc.index('grn,H,H=>grn,H2')].copy()
    star = 0. * rate
    if os.path.exists(cpre + '.H2scr'):
        hs, scr = table(cpre + '.H2scr')
        if 'grn,H,H=>grn,H2*' in hs and len(scr) == len(rate):
            star = scr[:, hs.index('grn,H,H=>grn,H2*')]
    for a in (ovr, dens, gt):
        assert len(a) == len(rate) and np.allclose(a[:, 0], cr[:, 0], rtol=1e-6), cpre
    nH = ovr[:, ho.index('hden')]
    nH0 = dens[:, hd.index('H')]
    TC = ovr[:, ho.index('Te')]
    AVC = ovr[:, ho.index('AV(point)')]
    TdC = gt[:, 1:]
    RC = (rate + star) / (nH * nH0)
    Ab = opc_areas(opc) / 4. * scale                       # projected, per H, per bin
    assert len(Ab) == TdC.shape[1], (len(Ab), TdC.shape)
    sigC = Ab.sum()
    RCre = 0.5 * v_h(TC) * (sticking(TC[:, None], TdC) * eps_cloudy(TdC) * Ab[None, :]).sum(1)
    q = RCre / RC
    good = np.isfinite(q) & (RC > 0)
    print(f'Cloudy {cpre}: {len(RC)} zones; area per H {sigC:.4e} cm2 ({len(Ab)} bins, scale {scale:g});'
          f' H2* share of grain formation {np.median(star[good] / (rate + star)[good]):.3f};'
          f' formula / saved: median {np.median(q[good]):.4f}, 5-95% {np.percentile(q[good], 5):.4f}-{np.percentile(q[good], 95):.4f}')

    # ---------------------------------------------------------------- the chain
    if avs is None:
        avs = (0.05, 0.10, 0.15, 0.20, 0.30, 0.50, 0.65) if AVC.max() < 1.5 else \
              (0.30, 0.45, 0.55, 0.70, 1.00, 1.50, 2.00, 2.50, 2.90)
    print('\nA_V    cells   T_M     T_C     Td_M   Td_C(area-wt)   R_M        R_C        R_M/R_C |'
          '  T_gas   Td(bins)  eps form  area  | C formula/saved')
    rows = []
    for av in avs:
        s = (np.abs(d['AV'] / av - 1) < 0.08) & ok
        j = np.argmin(np.abs(AVC - av))
        if s.sum() == 0:
            continue
        m0 = np.median(RM[s])
        TM, TdM = np.median(T[s]), np.median(Td[s])
        tc, tdc = TC[j], TdC[j]
        w = Ab / sigC                                        # Cloudy's area distribution
        eM = eps_3dpdr(np.maximum(TdM, 2.7), mat)
        # M0 rebuilt from the medians, so the chain is a chain of the same object
        m0r = 0.5 * v_h(TM) * sigM * sticking(TM, TdM) * eM
        m1 = 0.5 * v_h(tc) * sigM * sticking(tc, TdM) * eM
        m2 = 0.5 * v_h(tc) * sigM * (w * sticking(tc, tdc) * eps_3dpdr(tdc, mat)).sum()
        m3 = 0.5 * v_h(tc) * sigM * (w * sticking(tc, tdc) * eps_cloudy(tdc)).sum()
        m4 = 0.5 * v_h(tc) * sigC * (w * sticking(tc, tdc) * eps_cloudy(tdc)).sum()
        rc = RC[j]
        rows.append((av, m0 / rc, m0r / m1, m1 / m2, m2 / m3, m3 / m4, m4 / rc))
        print(f'{av:4.2f}  {s.sum():6d}  {TM:7.1f}  {tc:7.1f}  {TdM:6.1f}  {(w * tdc).sum():6.1f}       '
              f'{m0:9.3e}  {rc:9.3e}  {m0 / rc:7.2f} | {m0r / m1:6.2f}  {m1 / m2:7.2f}  {m2 / m3:7.2f}  {m3 / m4:6.2f} | {m4 / rc:6.3f}'
              f'   (M0 from medians / median M0 {m0r / m0:.3f})')
    print('\nratios read left to right multiply to R_M/R_C (with the last column, Cloudy\'s formula against its saved rate,'
          ' and the medians column, which is 1 when the cells in the bin agree)')
    print('\nefficiency at a few dust temperatures:  Td   3D-PDR sil   3D-PDR car   Cloudy CT02')
    for x in (10., 15., 20., 30., 40., 60., 80., 100., 150.):
        print(f'                                     {x:5.0f}  {eps_3dpdr(x, "sil"):10.3f}  {eps_3dpdr(x, "car"):10.3f}  {eps_cloudy(x):10.3f}')
    return rows


if __name__ == '__main__':
    a = [x for x in sys.argv[1:] if not x.startswith('--')]
    avs = None
    if '--av' in sys.argv:
        avs = tuple(float(v) for v in sys.argv[sys.argv.index('--av') + 1].split(','))
        a = [x for x in a if x != sys.argv[sys.argv.index('--av') + 1]]
    main(a[0], a[1], a[2], float(a[3]), avs)
