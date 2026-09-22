#!/usr/bin/env python3
"""D-304: decompose O-02's temperature half - heating and cooling, term by term.

D-301/D-303 closed the field half of O-02: with thin-line transport the FUV
field reaches 0.91 of Cloudy's. The gas is still ~1.8x colder, so what remains
is the conversion from field to temperature. This reads only what is already on
disk - MOCASSIN's thermBudget.out/pdrCoolSp.out/pdrFUV.out and Cloudy's
.heat/.cool/.ovr/.pdr - and prints, in matched A_V bins:

  * the total heating and cooling per H nucleus on each side, with the
    residual H-C as MOCASSIN's own convergence check,
  * the heating split (MOCASSIN phot/PE/PDR against Cloudy's agents),
  * the cooling split (MOCASSIN coll/rec/ff/gasDust/PDR against Cloudy's),
  * MOCASSIN's PDR cooling by coolant (CO, C+, C, O),
  * a [C II] thermostat test: the deep PDR is GrnP heating balanced by 158 um
    [C II] cooling on both sides, and that line's cooling per H goes as
    exp(-91.2/T) while subthermal. If the heating deficit alone accounts for
    the temperature, then T_m predicted from H_m/H_c and Cloudy's T_c matches
    the measured T_m. If it does not, the cooling side carries the rest.

    ~/miniforge3/envs/astro/bin/python tools/d304_budget.py \\
        runs/d302-trim-on runs/d302-cloudy-trim-rad/150k
"""
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R
from d287_pe import rows, last_iteration, DRAINE_PER_HABING

# thermBudget.out slots 1..10, as update_mod.f90 assembles them.
HEAT = ['phot', 'PE', 'PDR']
COOL = ['coll', 'rec', 'ff', 'gasDust', 'PDR']
COOLANT = ['CO', 'C+', 'C', 'O']
# thermBudget columns 41..46, the D-288 grain diagnostic.
GRAIN = ['Vg[Ryd]', '<Y>', '<E>[Ryd]', 'Nabs/H', 'Eabs/H', 'area/H']
RYD_ERG = 2.1798723611e-11
RYD_VOLT = 13.605693

# [C II] 2P3/2-2P1/2, 157.74 um.
T_CII = 91.21


def read_moc(run):
    """Per-H budget terms, A_V, T and field for every active cell."""
    d = R.read_run(run)
    out = os.path.join(run, 'output')
    t = open(os.path.join(out, 'grid0.out')).read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    n = nx * ny * nz
    off = 7 + nx + ny + nz
    idx = np.where(np.array(t[off:off + 3 * n:3], float) > 0)[0]

    bud = np.loadtxt(os.path.join(out, 'thermBudget.out'),
                     comments='#')[:n][idx]
    d['heat'] = bud[:, 0:3]              # phot PE PDR
    d['cool'] = bud[:, 3:8]              # coll rec ff gasDust PDR
    d['HmC'] = bud[:, 8]
    d['Tbud'] = bud[:, 9]                # the T the budget was evaluated at
    d['grain'] = bud[:, 40:46]           # D-288: Vg <Y> <E> Nabs/H Eabs/H area/H

    nh = np.loadtxt(os.path.join(out, 'grid1.out'))[idx, 2]
    d['nh'] = nh
    # pdrCoolSp.out is written in the same loop as pdrGrid.out - every cell,
    # not just the active ones.
    csp = np.loadtxt(os.path.join(out, 'pdrCoolSp.out'))[:n][idx]
    d['coolSp'] = csp / nh[:, None]

    fuv = np.loadtxt(os.path.join(out, 'pdrFUV.out'), comments='#')
    d['G0'] = fuv[:, 9] * DRAINE_PER_HABING

    # The chemistry's C+ per H nucleus (pdrGrid.out abundances are already
    # relative to H nuclei), not the ionized-gas solver's C+.
    p = np.array(open(os.path.join(out, 'pdrGrid.out')).read().split(),
                 float)[:n * 45].reshape(n, 45)
    d['C+pdr'] = p[idx, 12:45][:, R.SPEC.index('C+')]
    elem, abun = R.read_composition(run)
    d['C/H'] = abun['C']
    return d


def cloudy_agents(path, totcol):
    """depth, T, total rate and the agent->fraction map of a .heat/.cool."""
    dep, T, tot, ag = [], [], [], []
    for ln in open(path):
        if ln.startswith('#'):
            continue
        s = ln.rstrip('\n').split('\t')
        if len(s) < 5:
            continue
        try:
            d0, t0, r0 = float(s[0]), float(s[1]), float(s[totcol])
        except ValueError:
            continue
        pairs = [x for x in s[5:] if x.strip()]
        f = {}
        for i in range(0, len(pairs) - 1, 2):
            try:
                f[pairs[i].strip()] = float(pairs[i + 1])
            except ValueError:
                pass
        dep.append(d0); T.append(t0); tot.append(r0); ag.append(f)
    return np.array(dep), np.array(T), np.array(tot), ag


def read_cloudy(prefix):
    hdr = open(f'{prefix}.pdr').readline().lstrip('#').rstrip().split('\t')
    pdr = last_iteration(rows(f'{prefix}.pdr', len(hdr)),
                         hdr.index('depth') if 'depth' in hdr else 0)
    oh = open(f'{prefix}.ovr').readline().lstrip('#').rstrip().split('\t')
    ovr = rows(f'{prefix}.ovr', len(oh))
    _, T, htot, hag = cloudy_agents(f'{prefix}.heat', 2)
    _, _, ctot, cag = cloudy_agents(f'{prefix}.cool', 3)

    eh = open(f'{prefix}.ele_C').readline().lstrip('#').rstrip().split('\t')
    ele = rows(f'{prefix}.ele_C', len(eh))
    ch = 10 ** float(re.search(r'C :\s*(-?\d+\.\d+)',
                               open(f'{prefix}.out').read()).group(1))

    gh = rows(f'{prefix}.gheat',
              len(open(f'{prefix}.gheat').readline().rstrip().split('\t')))
    gp = rows(f'{prefix}.gpot',
              len(open(f'{prefix}.gpot').readline().rstrip().split('\t')))

    m = min(len(pdr), len(ovr), len(htot), len(ctot), len(ele), len(gh))
    nh = ovr[:m, oh.index('hden')]
    return {'xC+': ele[:m, eh.index('C+')] * ch, 'C/H': ch,
            'gheat': gh[:m, 1:] / nh[:, None], 'gpot': gp[:m, 1:],
            'AV': pdr[:m, hdr.index('AV(point)')],
            'G0': pdr[:m, hdr.index('G0')],
            'Tgas': T[:m], 'nh': nh,
            'H': htot[:m] / nh, 'C': ctot[:m] / nh,
            'hag': hag[:m], 'cag': cag[:m]}


def _isnum(a):
    try:
        float(a)
        return True
    except ValueError:
        return False


def cii_gated(c, j):
    """Is the [C II] thermostat the right relation in this zone?

    The relation below assumes the balance is GrnP against subthermal 158 um
    [C II]. Rather than pick a temperature threshold, ask the reference where
    its own cooling is that line: Cloudy writes the share per zone.
    """
    return c['cag'][j].get('C  2 0.0', 0.0) > 0.5


def bins(av):
    return [(a, max(0.02, 0.08 * a)) for a in av]


def pdr_depths(m, n=8):
    """D-322: the depths this sampling used to carry - 0.05 to 0.65 - were the
    150 kK model's, whose PDR ends at A_V 0.67. On hiipdr, which reaches 3,
    they covered the first fifth and stopped, and stopped short of exactly the
    depth where the two codes' temperatures cross. Same disease as L-21.
    Sample the model's own range instead: two points in front of the
    ionization front, the rest spread over the PDR."""
    av = m['AV']
    pdr = av[m['zone'] == 1]
    front = np.geomspace(max(av.min(), 1e-3), m['A_front'] * 0.85, 3)[:2]
    deep = np.geomspace(np.percentile(pdr, 2), np.percentile(pdr, 98), n - 2)
    return [float(v) for v in np.concatenate([front, deep])]


def main(run, prefix, avs=None, off=None, ioncont=None):
    m = read_moc(run)
    c = read_cloudy(prefix)
    pdr = m['zone'] == 1
    if avs is None:
        avs = pdr_depths(m)
        print('sample depths from the run: '
              + ', '.join('%.2f' % a for a in avs))

    print(f'MOCASSIN {run}\nCloudy   {prefix}')
    print('Rates per H nucleus [erg/s]. MOCASSIN: median over active cells in '
          'the bin.\nCloudy: nearest zone. A_V is each code\'s own from the '
          'illuminated face.\n')

    # The budget is recorded at the solver's last trial T, which need not be
    # the TeUsed the cell keeps. Say how far apart they are before using it.
    s = pdr & (m['Tbud'] > 0)
    dev = np.abs(m['Tbud'][s] - m['Tgas'][s]) / np.maximum(m['Tgas'][s], 1e-30)
    print('budget-T check (PDR cells): |T_bud - T_gas|/T_gas  median %.2e  '
          'p95 %.2e  max %.2e'
          % (np.median(dev), np.percentile(dev, 95), dev.max()))
    print('A_front = %.4f, %d PDR cells of %d active'
          % (m['A_front'], pdr.sum(), len(m['AV'])))
    print('C/H: MOCASSIN %.3e, Cloudy %.3e\n' % (m['C/H'], c['C/H']))

    print('=== balance ===')
    h = ('  A_V     T_m     T_c   T_m/T_c |    H_m       H_c    m/c |'
         '    C_m       C_c    m/c |  (H-C)/H_m')
    print(h); print('-' * len(h))
    keep = []
    for a, w in bins(avs):
        s = np.abs(m['AV'] - a) <= w
        if s.sum() < 3:
            continue
        j = np.argmin(abs(c['AV'] - a))
        Hm = np.median(m['heat'][s].sum(1)); Cm = np.median(m['cool'][s].sum(1))
        Tm = np.median(m['Tgas'][s])
        keep.append((a, s, j, Hm, Cm, Tm))
        print('%6.2f %7.1f %7.1f %8.3f | %9.3e %9.3e %5.2f | %9.3e %9.3e %5.2f'
              ' | %9.2e'
              % (a, Tm, c['Tgas'][j], Tm / c['Tgas'][j],
                 Hm, c['H'][j], Hm / max(c['H'][j], 1e-99),
                 Cm, c['C'][j], Cm / max(c['C'][j], 1e-99),
                 np.median(m['HmC'][s]) / max(Hm, 1e-99)))

    for what, arr, names, agkey, tot in [
            ('heating', 'heat', HEAT, 'hag', 'H'),
            ('cooling', 'cool', COOL, 'cag', 'C')]:
        print(f'\n=== {what}, per H, and each side\'s leading agents ===')
        if what == 'cooling':
            print("Read the MOCASSIN columns as bookkeeping, not as channels. "
                  "`coll` is its RAW\ncollisional cooling, including the "
                  "[C II]/[O I] it is about to hand over, and `PDR`\nis the "
                  "NET of (3D-PDR's coolants added) minus (MOCASSIN's own "
                  "taken back out) -\nupdate_mod.f90 does coolInt = coolInt - "
                  "mocCool without touching coolColl. The two\nsum to the "
                  "right total and nothing is double counted, but the physical "
                  "split is the\nper-coolant table below: in the deep PDR "
                  "MOCASSIN cools by [C II], as Cloudy does.")
        lab = ' '.join('%9s' % n for n in names)
        print('  A_V  MOCASSIN %s |  Cloudy (agent, per H)' % lab)
        print('-' * (13 + 10 * len(names) + 40))
        for a, s, j, Hm, Cm, Tm in keep:
            v = np.median(m[arr][s], axis=0)
            top = sorted(c[agkey][j].items(), key=lambda kv: -kv[1])[:4]
            print('%6.2f          %s | %s'
                  % (a, ' '.join('%9.2e' % x for x in v),
                     '  '.join('%s %.2e' % (k, f * c[tot][j]) for k, f in top)))

    print('\n=== MOCASSIN PDR cooling by coolant, per H ===')
    print('  A_V  %s |    sum      used   used/sum'
          % ' '.join('%9s' % n for n in COOLANT))
    print('-' * 72)
    for a, s, j, Hm, Cm, Tm in keep:
        v = np.median(m['coolSp'][s], axis=0)
        used = np.median(m['cool'][s, 4])
        print('%6.2f  %s | %9.2e %9.2e %8.3f'
              % (a, ' '.join('%9.2e' % x for x in v), v.sum(), used,
                 used / max(v.sum(), 1e-99)))

    grain_section(m, c, keep)

    if off is not None and ioncont is not None:
        from d296_lines import cloudy_lya_fraction
        pexp = np.median(charging_exponent(run, off, (0.30, 0.40, 0.50, 0.65)))
        lya_section(m, c, keep, pexp, cloudy_lya_fraction(ioncont), ioncont)

    print('\n=== [C II] thermostat test ===')
    print('Deep-PDR balance is GrnP heating against 158 um [C II] cooling on '
          'both sides.\nWhile the line is subthermal its cooling per H goes as '
          'x(C+) exp(-%.1f/T), so the\nheating ratio alone predicts a '
          'temperature. T_pred solves\n  exp(-%.1f/T) = (H_m/H_c) '
          '(x_c/x_m) exp(-%.1f/T_c).' % (T_CII, T_CII, T_CII))
    print('Rows are restricted to zones where Cloudy\'s own cooling is >50% '
          '[C II]; nearer the\nfront the balance is a different one and the '
          'relation does not apply.')
    hh = ('  A_V   H_m/H_c  x(C+)_m/x_c  T_c     T_pred   T_m    T_m/T_pred'
          '   GrnP_m/GrnP_c')
    print(hh); print('-' * len(hh))
    cp_m = m['C+pdr']
    for a, s, j, Hm, Cm, Tm in keep:
        if not cii_gated(c, j):
            continue
        rh = Hm / max(c['H'][j], 1e-99)
        rx = np.median(cp_m[s]) / max(c['xC+'][j], 1e-99)
        rhs = rh / max(rx, 1e-30) * np.exp(-T_CII / c['Tgas'][j])
        Tp = -T_CII / np.log(rhs) if 0 < rhs < 1 else np.nan
        pe_m = np.median(m['heat'][s, 1])
        pe_c = c['hag'][j].get('GrnP', 0.0) * c['H'][j]
        print('%6.2f %8.3f %12.3f %7.1f %8.1f %7.1f %11.3f %14.3f'
              % (a, rh, rx, c['Tgas'][j], Tp, Tm, Tm / Tp if Tp == Tp else
                 float('nan'), pe_m / max(pe_c, 1e-99)))


def lya_section(m, c, keep, p, lya, ioncont):
    print('\n=== the reference corrected for its own Ly-alpha artifact ===')
    print('D-291/D-298: Cloudy attenuates outward line flux by continuum '
          'opacity alone, so its\ndeep-PDR Ly-alpha is an artifact, measured '
          'at a flat %.3f of the 6-13.6 eV field.\nIt inflates Cloudy\'s GrnP '
          'heating and so its temperature, not only its field.\nGrnP goes as '
          'G0^%.2f (measured, not assumed - see the charging exponent above),\n'
          'so the corrected heating is (1-%.3f)^%.2f = %.3f of Cloudy\'s, and '
          'the corrected T\nfollows from the same [C II] thermostat.'
          % (lya, p, lya, p, (1 - lya) ** p))
    print('fraction read from %s' % ioncont)
    print('Same [C II]-dominated zones as the thermostat test below.')
    h = ('  A_V    T_c    T_c corr   T_m   | T_m/T_c  T_m/T_c corr | '
         'G0_m/G0_c  corr')
    print(h); print('-' * len(h))
    f = (1 - lya) ** p
    for a, s, j, Hm, Cm, Tm in keep:
        if not cii_gated(c, j):
            continue
        rhs = f * np.exp(-T_CII / c['Tgas'][j])
        Tc2 = -T_CII / np.log(rhs) if 0 < rhs < 1 else np.nan
        g0m = np.median(m['G0'][s])
        print('%6.2f %7.1f %9.1f %7.1f | %7.3f %13.3f | %8.3f %6.3f'
              % (a, c['Tgas'][j], Tc2, Tm, Tm / c['Tgas'][j], Tm / Tc2,
                 g0m / c['G0'][j], g0m / (c['G0'][j] * (1 - lya))))


def grain_section(m, c, keep):
    print('\n=== the photoelectric term, grain by grain ===')
    print('MOCASSIN: D-288 diagnostic. Its own identity is PE = Nabs/H x <Y> '
          'x <E>, checked here.\nCloudy: .gheat summed over its ten bins '
          '(reproduces GrnP), and .gpot per bin.')
    h = ('  A_V   PE_m      NxYxE     id.  | Nabs/H    <Y>     <E>[Ryd] '
         ' area/H   | Vg_m[V]  Vg_c[V] (min-max over bins)  | PE_c      m/c')
    print(h); print('-' * len(h))
    for a, s, j, Hm, Cm, Tm in keep:
        g = np.median(m['grain'][s], axis=0)
        pe = np.median(m['heat'][s, 1])
        recon = g[3] * g[1] * g[2] * RYD_ERG
        pec = c['gheat'][j].sum()
        # heating-weighted mean potential: the bins that carry the heating
        w = c['gheat'][j]
        vgc = (c['gpot'][j] * w).sum() / max(w.sum(), 1e-99)
        print('%6.2f %9.2e %9.2e %5.2f | %8.2e %7.4f %8.4f %8.2e | '
              '%7.3f  %7.3f (%.2f-%.2f) | %9.2e %5.2f'
              % (a, pe, recon, recon / max(pe, 1e-99),
                 g[3], g[1], g[2], g[5],
                 g[0] * RYD_VOLT, vgc, c['gpot'][j].min(), c['gpot'][j].max(),
                 pec, pe / max(pec, 1e-99)))

    print('\nwhich grain sizes carry Cloudy\'s GrnP (share per bin, '
          'small -> large)')
    for a, s, j, Hm, Cm, Tm in keep:
        w = c['gheat'][j] / max(c['gheat'][j].sum(), 1e-99)
        print('%6.2f  %s' % (a, ' '.join('%5.3f' % x for x in w)))

    print('\n=== efficiency: the field divided out ===')
    h = ('  A_V    G0_m     G0_c   m/c  |  PE_m/G0   PE_c/G0    m/c  '
         '|  T_m/T_c')
    print(h); print('-' * len(h))
    for a, s, j, Hm, Cm, Tm in keep:
        g0m = np.median(m['G0'][s])
        pe = np.median(m['heat'][s, 1])
        pec = c['gheat'][j].sum()
        em = pe / max(g0m, 1e-30)
        ec = pec / max(c['G0'][j], 1e-30)
        print('%6.2f %8.3g %8.3g %5.2f  | %9.3e %9.3e %6.2f  | %7.3f'
              % (a, g0m, c['G0'][j], g0m / max(c['G0'][j], 1e-30),
                 em, ec, em / max(ec, 1e-30), Tm / c['Tgas'][j]))


def charging_exponent(runA, runB, avs):
    """d ln(PE heating) / d ln(G0), measured from the lines on/off pair.

    PE heating is sublinear in the field because a stronger field charges the
    grains more positively and cuts the yield. The exponent is needed to carry
    Cloudy's Ly-alpha correction from its field into its heating: removing 46%
    of the field does NOT remove 46% of GrnP.
    """
    a, b = read_moc(runA), read_moc(runB)
    num, den = [], []
    for av, w in bins(avs):
        sa = np.abs(a['AV'] - av) <= w
        sb = np.abs(b['AV'] - av) <= w
        if sa.sum() < 3 or sb.sum() < 3:
            continue
        num.append(np.log(np.median(a['heat'][sa].sum(1)) /
                          np.median(b['heat'][sb].sum(1))))
        den.append(np.log(np.median(a['G0'][sa]) / np.median(b['G0'][sb])))
    return np.array(num) / np.array(den)


def moc_pair(runA, runB, avs):
    """The thermostat relation tested inside MOCASSIN alone.

    Two runs of one binary differing only in MOCASSIN_LINES: the field, and so
    the heating, changes while every other piece of physics is held fixed. If
    T really is set by heating against subthermal [C II], then

        exp(-91.2/T_A) / exp(-91.2/T_B) = H_A / H_B

    with no Cloudy, no Ly-alpha correction and no abundance question in it.
    """
    a, b = read_moc(runA), read_moc(runB)
    print('\n=== thermostat, MOCASSIN against MOCASSIN ===')
    print('A: %s\nB: %s' % (runA, runB))
    h = ('  A_V    T_A     T_B   | H_A/H_B  G0_A/G0_B | x(C+)A/B | T_A pred'
         '   measured   pred/meas')
    print(h); print('-' * len(h))
    for av, w in bins(avs):
        sa = np.abs(a['AV'] - av) <= w
        sb = np.abs(b['AV'] - av) <= w
        if sa.sum() < 3 or sb.sum() < 3:
            continue
        Ha = np.median(a['heat'][sa].sum(1)); Hb = np.median(b['heat'][sb].sum(1))
        Ta = np.median(a['Tgas'][sa]); Tb = np.median(b['Tgas'][sb])
        rx = np.median(a['C+pdr'][sa]) / max(np.median(b['C+pdr'][sb]), 1e-99)
        rhs = (Ha / max(Hb, 1e-99)) / max(rx, 1e-30) * np.exp(-T_CII / Tb)
        Tp = -T_CII / np.log(rhs) if 0 < rhs < 1 else np.nan
        print('%6.2f %7.1f %7.1f | %7.3f %9.3f | %8.3f | %8.1f %10.1f %11.3f'
              % (av, Ta, Tb, Ha / max(Hb, 1e-99),
                 np.median(a['G0'][sa]) / max(np.median(b['G0'][sb]), 1e-99),
                 rx, Tp, Ta, Tp / Ta if Tp == Tp else float('nan')))


if __name__ == '__main__':
    if os.path.isdir(os.path.join(sys.argv[2], 'output')):
        avs = (0.20, 0.30, 0.40, 0.50, 0.65)
        p = charging_exponent(sys.argv[1], sys.argv[2], avs)
        print('charging exponent d ln(PE) / d ln(G0), from the on/off pair:')
        print('  ' + '  '.join('%.2f: %.3f' % (a, x) for a, x in zip(avs, p)))
        print('  median over the deep PDR (A_V >= 0.3): %.3f' % np.median(p[1:]))
        moc_pair(sys.argv[1], sys.argv[2], avs)
    else:
        # trailing numeric arguments override the sample depths
        rest = sys.argv[3:]
        avs = [float(a) for a in rest if _isnum(a)] or None
        rest = [a for a in rest if not _isnum(a)]
        main(sys.argv[1], sys.argv[2], avs=avs,
             off=rest[0] if len(rest) > 0 else None,
             ioncont=rest[1] if len(rest) > 1 else None)
