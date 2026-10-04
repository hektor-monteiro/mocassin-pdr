#!/usr/bin/env python3
"""D-391: what the convergence test sees, iteration by iteration, from a run's
per-iteration grid snapshots (runs/<run>/snaps/itNN, the D-365 method).

For each iteration against the one before:

  - the code's own per-cell test, reproduced: x(H0), x(H2) (where either end
    is above cvH2floor = 1e-5) and T_e, each |change|/old <= XHILimit (the
    run's convLimit); its percentage over all active cells is checked against
    the one the run printed, then split into ionized (MOCASSIN's own
    x(H+) >= 0.5) and neutral cells, which is only a label for this
    accounting;
  - the same test with the helium stages added (x(He+), x(He2+), each tested
    where either end is above 1e-3 of helium);
  - model-integrated totals and line proxies, summed with each cell's
    volume: ionized H, He+, He2+, H2, CO; Hbeta ~ n_e n(H+) T^-0.87,
    He II 4686 ~ n_e n(He2+) T^-0.9, [O III] 5007 and 4363 ~ n_e n(O2+)
    T^-1/2 exp(-T_x/T) with T_x 29,170 and 62,130 K (no de-excitation);
  - the H+ and He2+ fronts: medians in radial shells crossing 1/2.

The proxies are for RELATIVE change between iterations, not luminosities.

    ~/miniforge3/envs/astro/bin/python tools/d391_convtrail.py runs/d391-cv-pn41b

Modes:
  (default)     the tables above, then the exploratory candidate rules;
  --code-rule   exactly what iteration_mod's cvTotalsUpdate (D-391) computes:
                the largest change over the last 3 iterations and the three
                quantities behind it, per iteration, and the first iteration
                within 2% - to check the code against, and to replay the rule
                on runs made before it existed;
  --lines       the line spectrum per iteration against the last, from
                work/itNN/output/lineFlux.out (runs/d391-snaplines.sh: the
                warm reader and outputGas on each snapshot, which reproduce
                the run's own lineFlux.out except the resonance lines'
                escaping fractions).
"""
import glob
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R  # noqa: E402

PC = 3.0857e18
H2FLOOR, HEFLOOR = 1e-5, 1e-3


def keyword(run, name, default):
    t = open(os.path.join(run, 'input', 'input.in')).read()
    m = re.search(rf'^\s*{name}\s+([0-9.eE+-]+)', t, re.M)
    return float(m.group(1)) if m else default


def read(snap, elem):
    t = open(os.path.join(snap, 'grid0.out')).read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    n = nx * ny * nz
    xa = np.array(t[7:7 + nx], float)
    ya = np.array(t[7 + nx:7 + nx + ny], float)
    za = np.array(t[7 + nx + ny:7 + nx + ny + nz], float)
    off = 7 + nx + ny + nz
    act = np.array(t[off:off + n * 3:3], float).astype(int) > 0
    X, Y, Z = np.meshgrid(xa, ya, za, indexing='ij')
    r = np.sqrt(X ** 2 + Y ** 2 + Z ** 2).ravel()[act] / PC

    def widths(a):
        e = np.concatenate(([a[0]], 0.5 * (a[1:] + a[:-1]), [a[-1]]))
        return np.diff(e)
    dV = np.einsum('i,j,k->ijk', widths(xa), widths(ya), widths(za)).ravel()[act]
    g1 = np.loadtxt(os.path.join(snap, 'grid1.out'))[act]
    Te, ne, nh = g1[:, 0], g1[:, 1], g1[:, 2]
    lines = open(os.path.join(snap, 'grid2.out')).read().split('\n')
    ne_ = len(elem)
    idx = np.where(act)[0]

    def stage(el, st):
        li = elem.index(el)
        out = np.zeros(len(idx))
        for k, c in enumerate(idx):
            q = lines[c * ne_ + li].split()
            out[k] = float(q[st]) if len(q) > st else 0.0
        return out
    d = dict(r=r, dV=dV, Te=Te, ne=ne, nh=nh,
             xH0=stage('H', 0), xHp=stage('H', 1),
             xHe1=stage('He', 1), xHe2=stage('He', 2))
    d['xO2'] = stage('O', 2) if 'O' in elem else np.zeros(len(idx))
    d['stages'] = {}
    for el in elem:
        li = elem.index(el)
        nst = max(len(lines[c * ne_ + li].split()) for c in idx[:50])
        for st in range(nst):
            d['stages'][f'{el}{st}'] = stage(el, st)
    pg = R.read_pdrgrid(snap, n)
    d['xH2'] = pg['ab'][act, R.SPEC.index('H2')]
    d['xCO'] = pg['ab'][act, R.SPEC.index('CO')]
    return d


def front(r, x, dr):
    edges = np.arange(0, r.max() + dr / 2, dr / 2)
    k = np.digitize(r, edges) - 1
    rc, xc = [], []
    for b in range(len(edges) - 1):
        s = k == b
        if s.sum() >= 3:
            rc.append(np.median(r[s])); xc.append(np.median(x[s]))
    rc, xc = np.array(rc), np.array(xc)
    j = np.where((xc[:-1] >= 0.5) & (xc[1:] < 0.5))[0]
    if not len(j):
        return np.nan
    j = j[0]
    return rc[j] + (0.5 - xc[j]) * (rc[j + 1] - rc[j]) / (xc[j + 1] - xc[j])


def rel(a, b):
    with np.errstate(divide='ignore', invalid='ignore'):
        return np.abs(a - b) / np.abs(b)


def main(run):
    elem, abund = R.read_composition(run)
    tol = keyword(run, 'convLimit', 0.05)
    aHe, aO = abund['He'], abund.get('O', 0.)
    printed = [float(x) for x in re.findall(
        r'Iteration +\d+ ; Total: +([0-9.Ee+-]+) +% converged', open(os.path.join(run, 'run.log')).read())]
    snaps = sorted(glob.glob(os.path.join(run, 'snaps', 'it[0-9][0-9]')))
    prev = None
    rows = []
    for sp in snaps:
        it = int(sp[-2:])
        d = read(sp, elem)
        nO2 = d['xO2'] * aO * d['nh']
        tot = dict(
            Hp=(d['xHp'] * d['nh'] * d['dV']).sum(),
            He1=(d['xHe1'] * aHe * d['nh'] * d['dV']).sum(),
            He2=(d['xHe2'] * aHe * d['nh'] * d['dV']).sum(),
            H2=(d['xH2'] * d['nh'] * d['dV']).sum(),
            CO=(d['xCO'] * d['nh'] * d['dV']).sum(),
            Hb=(d['ne'] * d['xHp'] * d['nh'] * (d['Te'] / 1e4) ** -0.87 * d['dV']).sum(),
            He4686=(d['ne'] * d['xHe2'] * aHe * d['nh'] * (d['Te'] / 1e4) ** -0.9 * d['dV']).sum(),
            O5007=(d['ne'] * nO2 * d['Te'] ** -0.5 * np.exp(-29170. / d['Te']) * d['dV']).sum(),
            O4363=(d['ne'] * nO2 * d['Te'] ** -0.5 * np.exp(-62130. / d['Te']) * d['dV']).sum())
        dr = np.diff(np.unique(np.round(d['r'], 6)))[:5].min() * 2 if len(d['r']) > 10 else 0.1
        fr = dict(Hp=front(d['r'], d['xHp'], dr), He2=front(d['r'], d['xHe2'], dr))
        row = dict(it=it, tot=tot, fr=fr)
        if prev is not None:
            p = prev[0]
            okH0 = rel(d['xH0'], p['xH0']) <= tol
            okH0 |= p['xH0'] <= 0          # the code skips a zero start
            sig2 = np.maximum(d['xH2'], p['xH2']) > H2FLOOR
            okH2 = ~sig2 | ((p['xH2'] > 0) & (rel(d['xH2'], p['xH2']) <= tol))
            okT = rel(d['Te'], p['Te']) <= tol
            code = okH0 & okH2 & okT
            okHe = np.ones_like(code)
            for k in ('xHe1', 'xHe2'):
                sig = np.maximum(d[k], p[k]) > HEFLOOR
                okHe &= ~sig | ((p[k] > 0) & (rel(d[k], p[k]) <= tol))
            ion = p['xHp'] >= 0.5
            row.update(code=100 * code.mean(), codeIon=100 * code[ion].mean(),
                       codeNeu=100 * code[~ion].mean(), nIon=int(ion.sum()),
                       withHe=100 * (code & okHe).mean(),
                       withHeIon=100 * (code & okHe)[ion].mean(),
                       heFailIon=int((~okHe & ion).sum()),
                       printed=printed[it - 1] if it - 1 < len(printed) else np.nan,
                       dtot={k: 100 * (tot[k] - prev[1][k]) / prev[1][k] if prev[1][k] else np.nan for k in tot},
                       dfr={k: fr[k] - prev[2][k] for k in fr})
        rows.append(row)
        prev = (d, tot, fr)

    print(f'{run}: tolerance (convLimit) {tol}, {len(snaps)} snapshots')
    print('it  printed  code  ionized  neutral | +He: all  ionized  He-fail(ion) | front H+ [pc] He2+ [pc]')
    for w in rows:
        if 'code' not in w:
            print(f"{w['it']:2d}                                                            "
                  f"{w['fr']['Hp']:.4f}  {w['fr']['He2']:.4f}")
            continue
        print(f"{w['it']:2d}  {w['printed']:6.2f}  {w['code']:6.2f}  {w['codeIon']:6.2f}  {w['codeNeu']:6.2f} |"
              f"  {w['withHe']:6.2f}  {w['withHeIon']:6.2f}  {w['heFailIon']:5d} of {w['nIon']:5d} |"
              f"  {w['fr']['Hp']:.4f}  {w['fr']['He2']:.4f}")
    keys = list(rows[0]['tot'])
    print('\nchange per iteration in the integrated totals [%]')
    print('it  ' + ''.join(f'{k:>9s}' for k in keys))
    for w in rows:
        if 'dtot' in w:
            print(f"{w['it']:2d}  " + ''.join(f"{w['dtot'][k]:9.3f}" for k in keys))
    print('\nthe totals against the last iteration [last/this - 1, %]')
    last = rows[-1]['tot']
    print('it  ' + ''.join(f'{k:>9s}' for k in keys))
    for w in rows:
        print(f"{w['it']:2d}  " + ''.join(f"{100 * (last[k] / w['tot'][k] - 1) if w['tot'][k] else np.nan:9.3f}" for k in keys))


def candidates(run, sig=1e-3, K=3, weight='content'):
    """Integrated quantities with no labels: every ion stage's content that is
    at least `sig` of its element, H2 and CO content, and the gas temperature
    weighted three ways - by n_e n(H+) (ionized gas), by n(H0) (atomic) and by
    n(H2) (molecular). Rule S_K: the largest change over the last K
    iterations, max_q |q_n / q_(n-K) - 1|. Rule A: Aitken's estimate of the
    change still to come, |d_n| r/(1-r) with r = d_n/d_(n-1) when the last
    three changes share a sign (|d_n| otherwise, infinite if r >= 1)."""
    elem, abund = R.read_composition(run)
    snaps = sorted(glob.glob(os.path.join(run, 'snaps', 'it[0-9][0-9]')))
    series = {}
    for sp in snaps:
        d = read(sp, elem)
        w = d['nh'] * d['dV']
        q = {}
        for name, x in d['stages'].items():
            el = re.match(r'[A-Z][a-z]?', name).group(0)
            if weight == 'em' and name.endswith('0') and not name.endswith('10'):
                continue            # neutrals: covered by the H0/H2 contents and temperatures
            if weight == 'em':      # emission measure of the stage, n_e n_i dV
                q[name] = (d['ne'] * x * abund[el] * w).sum() / (d['ne'] * abund[el] * w).sum()
            else:                   # content of the stage, n_i dV
                q[name] = (x * abund[el] * w).sum() / (abund[el] * w).sum()
        q['H2'] = (d['xH2'] * w).sum() / w.sum()
        if weight != 'em':
            q['CO'] = (d['xCO'] * w).sum() / w.sum()
        em = d['ne'] * d['xHp'] * w
        q['T_em'] = (em * d['Te']).sum() / em.sum()
        q['T_H0'] = (d['xH0'] * w * d['Te']).sum() / (d['xH0'] * w).sum()
        if (d['xH2'] * w).sum() > 0:
            q['T_H2'] = (d['xH2'] * w * d['Te']).sum() / (d['xH2'] * w).sum()
        q['H0'] = (d['xH0'] * w).sum() / w.sum()
        nit = len(series.get('H0', [])) + 1
        for k, v in q.items():
            series.setdefault(k, [])
            while len(series[k]) < nit - 1:
                series[k].append(np.nan)
            series[k].append(v)
        for k in series:
            while len(series[k]) < nit:
                series[k].append(np.nan)
    n = len(snaps)
    names = [k for k, v in series.items()
             if not (k[-1].isdigit() and np.nanmax(v[-3:]) < sig)]
    print(f'\ncandidate rules, weight={weight}, on {len(names)} integrated quantities (stages >= {sig:g} of their element)')
    print('it   S_K worst            A worst')
    for i in range(K, n):
        ok = [k for k in names if np.all(np.isfinite(series[k][i - K:i + 1])) and series[k][i - K] > 0]
        sk = {k: abs(series[k][i] / series[k][i - K] - 1) for k in ok}
        aa = {}
        for k in ok:
            dl = [series[k][j] / series[k][j - 1] - 1 for j in (i - 2, i - 1, i)]
            if np.sign(dl[0]) == np.sign(dl[1]) == np.sign(dl[2]) and dl[1] != 0:
                r = dl[2] / dl[1]
                aa[k] = abs(dl[2]) * r / (1 - r) if 0 < r < 1 else np.inf
            else:
                aa[k] = abs(dl[2])
        if not sk:
            continue
        ks, ka = max(sk, key=sk.get), max(aa, key=aa.get)
        last = {k: abs(series[k][-1] / series[k][i] - 1) for k in ok}
        kl = max(last, key=last.get)
        print(f'{i + 1:2d}  {100 * sk[ks]:6.2f}% {ks:6s}   {100 * aa[ka]:7.2f}% {ka:6s}   to last: {100 * last[kl]:5.2f}% {kl}')


def code_rule(run, sig=0.01, K=3, tol=None):
    """What iteration_mod.f90's cvTotalsUpdate computes (D-391), from the
    snapshots: the emission measure n_e n_i dV of every ION stage holding at
    least `sig` of its element's, n(H0) and n(H2) holding at least `sig` of the
    hydrogen, n(CO) at least `sig` of the carbon, and T weighted by
    n_e n(H+), n(H0) (if n(H0) counts) and n(H2) (if n(H2) counts). Prints the
    largest |q_n/q_(n-K) - 1| and which quantity, per iteration; with `tol`,
    the first iteration that passes."""
    elem, abund = R.read_composition(run)
    snaps = sorted(glob.glob(os.path.join(run, 'snaps', 'it[0-9][0-9]')))
    hist = []
    for sp in snaps:
        d = read(sp, elem)
        w = d['nh'] * d['dV']
        q = {}
        for name, x in d['stages'].items():
            el = re.match(r'[A-Z][a-z]?', name).group(0)
            st = int(name[len(el):])
            if st == 0:
                continue
            em = (d['ne'] * x * abund[el] * w).sum()
            tot = sum((d['ne'] * d['stages'][f'{el}{s2}'] * abund[el] * w).sum()
                      for s2 in range(1, 40) if f'{el}{s2}' in d['stages'])
            if tot > 0 and em >= sig * tot:
                q[f'{el}{st}+'] = em
        cH = w.sum()
        if (d['xH0'] * w).sum() >= sig * cH:
            q['n(H0)'] = (d['xH0'] * w).sum()
            q['T(H0)'] = (d['xH0'] * w * d['Te']).sum() / (d['xH0'] * w).sum()
        if (d['xH2'] * w).sum() >= sig * cH:
            q['n(H2)'] = (d['xH2'] * w).sum()
            q['T(H2)'] = (d['xH2'] * w * d['Te']).sum() / (d['xH2'] * w).sum()
        if 'C' in abund and (d['xCO'] * w).sum() >= sig * abund['C'] * cH:
            q['n(CO)'] = (d['xCO'] * w).sum()
        em = d['ne'] * d['xHp'] * w
        q['T(em)'] = (em * d['Te']).sum() / em.sum()
        hist.append(q)
    print(f'\n{run}: the D-391 rule (window {K}, significance {sig:g})')
    first = None
    for i in range(K, len(hist)):
        ch = {k: abs(hist[i][k] / hist[i - K][k] - 1) for k in hist[i] if k in hist[i - K] and hist[i - K][k] > 0}
        top = sorted(ch, key=ch.get, reverse=True)[:3]
        print(f'{i + 1:2d}  ' + '   '.join(f'{100 * ch[k]:6.2f}% {k}' for k in top))
        if tol is not None and first is None and max(ch.values()) <= tol:
            first = i + 1
    if tol is not None:
        print(f'first iteration with every change <= {100 * tol:g}%: {first}')


def read_lines(path):
    """Hbeta [1e36 erg/s] and every forbidden line of lineFlux.out, keyed by
    (Z, ion, upper, lower), as luminosity in Hbeta units of THIS file."""
    t = open(path).read()
    hb = float(re.search(r'Hbeta \[E36 erg/s\]:\s+(\S+)', t).group(1))
    rows = {}
    sec = t.split('Heavy ions forbidden lines')[1].split('Component')[0]
    for ln in sec.splitlines():
        q = ln.split()
        if len(q) == 7:
            try:
                rows[(int(q[0]), int(q[1]), int(q[2]), int(q[3]))] = float(q[5])
            except ValueError:
                pass
    top = t.split('Line Ratios :')[0]
    m = re.search(r'HeII 4686\s+(\S+)', top)
    named = {'HeII4686': float(m.group(1)) if m else 0.0}
    return hb, rows, named


def lines_trail(run, floor=0.01):
    """Per iteration: how far Hbeta and every forbidden line above `floor`
    of Hbeta (at the last iteration) still are from their last-iteration
    luminosity, from work/itNN/output/lineFlux.out (d391-snaplines.sh)."""
    files = sorted(glob.glob(os.path.join(run, 'work', 'it[0-9][0-9]', 'output', 'lineFlux.out')))
    data = [read_lines(f) for f in files]
    its = [int(f.split(os.sep)[-3][2:]) for f in files]
    hbL, rowsL, namedL = data[-1]
    keys = [k for k, v in rowsL.items() if v >= floor]
    print(f'\n{run}: line spectrum per iteration against iteration {its[-1]} '
          f'({len(keys)} forbidden lines >= {floor:g} Hbeta, luminosities)')
    print('it   Hbeta    HeII4686   worst line                 next')
    for it, (hb, rows, named) in zip(its, data):
        dev = {k: abs(rows.get(k, 0) * hb / (rowsL[k] * hbL) - 1) for k in keys}
        top = sorted(dev, key=dev.get, reverse=True)[:2]
        he = named['HeII4686'] * hb / (namedL['HeII4686'] * hbL) - 1 if namedL['HeII4686'] > 0 else float('nan')
        print(f'{it:2d}  {100 * (hb / hbL - 1):6.2f}%  {100 * he:7.2f}%   ' +
              '   '.join(f'{100 * dev[k]:6.2f}% {k}' for k in top))


if __name__ == '__main__':
    if '--lines' in sys.argv:
        lines_trail(sys.argv[1])
        sys.exit()
    if '--code-rule' in sys.argv:
        for tol in (0.01, 0.02, 0.03):
            code_rule(sys.argv[1], tol=tol) if tol == 0.02 else None
        sys.exit()
    if '--rules-only' not in sys.argv:
        main(sys.argv[1])
    candidates(sys.argv[1], sig=1e-2, weight='em')
