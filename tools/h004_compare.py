#!/usr/bin/env python3
"""H-004: UV pumping in h2_mod (h2Test) against Cloudy's large H2 model,
one-zone models at fixed T in an unshielded FUV field (runs/h004-cloudy-pump).

Each case takes Cloudy's own zone: the colliders (H, He, H+ + H3+ from
pump.dens; ortho- and para-H2 from pump.pops), the field (the incident
continuum of pump.con turned into a photon occupation number per mesh cell,
which is what Cloudy's pump rate uses), and the split of grain formation
between carbonaceous and silicate surfaces (pump.gh2).

Five checks, each isolating one piece:
  A  pump rate out of each X level against Cloudy's "RRout", for the levels
     Cloudy solves by matrix, where RRout is the pump rate alone;
  S  Solomon dissociation rate of H2g and H2* (E above 4100 cm-1), ours with
     Cloudy's populations, against the rate its chemistry network uses. For
     H2* Cloudy adds direct photodissociation with every H2* molecule taken
     at 2.5 eV (6e-19 cm2 times the photon flux from 1.07896 Ryd - 2.5 eV to
     1.14 Ryd, mole_h2.cpp); that term is rebuilt here from the same field
     and shown added;
  B  radiative rate into each level ("RRin"): return from the excited states
     plus decays from the X levels above Cloudy's matrix, ours with Cloudy's
     populations;
  C  the populations themselves, from our solution (each destroyed molecule
     replaced by a newly formed one, sum of populations fixed);
  D  the populations from our rates put through Cloudy's scheme, to show
     where C's difference comes from. Cloudy (mole_h2.cpp, atom_leveln.cpp)
     gives the levels a formation source fixed by its chemistry, adds its
     network's H2g Solomon rate a second time as a uniform sink on the H2g
     levels ("sink_left"), solves without a sum rule, and then multiplies
     every population by one factor f so that they add up. At the fixed
     point a level above the matrix has  n out = f (in + source), and a
     matrix level the same with f on the source and on what comes from above
     the matrix. f(C) is that factor read off Cloudy's own saved rates,
     f(D) the one our rates give.

    python tools/h004_compare.py runs/h004-cloudy-pump [--levels] [--case NAME] [--save FILE.npz]
"""
import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RYD_WN = 109737.31568          # 1 Ryd [cm^-1]
RYD_HZ = 3.2898419603e15       # 1 Ryd [Hz]
EV_RYD = 13.605693
H = 6.62607015e-27
C = 2.99792458e10
E_STAR = 4100.                 # Cloudy's H2g / H2* boundary [cm^-1]
KEY = [(0, 0), (0, 1), (0, 2), (0, 3), (0, 5), (0, 7), (1, 1), (1, 2), (1, 3), (2, 3), (3, 3), (6, 3)]


def table(path):
    L = open(path).read().split('\n')
    hd = L[0].lstrip('#').split('\t')
    v = L[1].split('\t')
    return {k.strip(): float(x) for k, x in zip(hd[1:], v[1:]) if x.strip()}


def cloudy_case(d):
    c = table(os.path.join(d, 'pump.dens'))
    rows, op = {}, {}
    for l in open(os.path.join(d, 'pump.pops')):
        s = l.split('\t')
        if l.startswith('#') or len(s) < 4:
            continue
        if s[3].strip() in ('ortho', 'para', 'total'):
            op[s[3].strip()] = float(s[2]); continue
        # pops/H2, RCout [s-1], RRout [s-1], RCin, RRin [cm-3 s-1]
        rows[(int(s[0]), int(s[1]))] = (float(s[4]), float(s[10]), float(s[11]), float(s[12]), float(s[13]))
    name = os.path.basename(d)
    T = float(name.split('_')[0][1:])
    dens = [c['H'], c['He'], op['ortho'], op['para'], c['H+'] + c['H3+']]
    # field: nu [Ryd], incident nu F_nu [erg cm-2 s-1], F_nu = 4 pi J_nu
    a = np.loadtxt(os.path.join(d, 'pump.con'), usecols=(0, 1))
    a = a[(a[:, 0] > 0.2) & (a[:, 0] < 1.5)]
    nu = a[:, 0]*RYD_HZ
    eta = a[:, 1]*C**2/(8*np.pi*H*nu**4)
    # Cloudy's direct photodissociation of H2*: photons from 1.07896 Ryd - 2.5 eV to 1.14 Ryd
    lo, hi = 1.07896 - 2.5/EV_RYD, 1.14
    sel = (a[:, 0] >= lo) & (a[:, 0] < hi)
    y, x = a[sel, 1]/(H*nu[sel]), np.log(nu[sel])
    phot = (0.5*(y[1:] + y[:-1])*np.diff(x)).sum()
    g = table(os.path.join(d, 'pump.gh2'))
    wcar = sum(v for k, v in g.items() if k.startswith('gra'))
    wsil = sum(v for k, v in g.items() if k.startswith('sil'))
    sol = {}
    for sp, f in (('H2', 'pump.h2dest'), ('H2*', 'pump.h2sdest')):
        r = table(os.path.join(d, f))
        sol[sp] = r['PHOTON,%s=>H,H' % sp]/c[sp]
    return dict(T=T, dens=dens, rows=rows, c=c, op=op, fw=a[:, 0]*RYD_WN, eta=eta,
                w=(0., wsil, wcar), sol=sol, ntot=op['total'], form=c['H']*(wcar + wsil)/op['total'],
                direct=6e-19*phot)


def read_AX():
    """X-state A values in h2Test's level order (energy order), components added."""
    d = os.path.join(HERE, 'dataPDR', 'h2')
    lv = []
    for l in open(os.path.join(d, 'energy_X.dat')).read().split('\n')[1:]:
        if not l or l[0] in ' \r':
            break
        if l[0] == '#':
            continue
        s = l.split('#')[0].split('//')[0].split()
        lv.append((float(s[2]), int(s[0]), int(s[1])))
    lv.sort()
    idx = {(v, j): i for i, (e, v, j) in enumerate(lv)}
    A = np.zeros((len(lv), len(lv)))
    for l in open(os.path.join(d, 'transprob_X.dat')).read().split('\n')[1:]:
        if not l or l[0] in ' \r':
            break
        if l[0] == '#':
            continue
        s = l.split('#')[0].split('//')[0].split()
        u, lo = idx.get((int(s[1]), int(s[2]))), idx.get((int(s[4]), int(s[5])))
        if u is None or lo is None:
            continue
        if u < lo:
            u, lo = lo, u
        A[u, lo] += float(s[6])
    return A


def cloudy_scheme(Tm, k, S, nm, f):
    """Our rates through Cloudy's scheme at rescaling factor f: populations (not normalized)."""
    n = len(k)
    out = Tm.sum(1) + k
    M = -f*Tm.T
    M[:nm, :nm] = -Tm[:nm, :nm].T
    M[np.arange(n), np.arange(n)] = out
    return np.linalg.solve(M, f*S)


def solve_scheme(Tm, k, S, nm):
    """The factor f at which Cloudy's scheme gives populations that sum to 1, all positive."""
    fs = np.linspace(0.95, 1.3, 701)
    val = []
    for f in fs:
        P = cloudy_scheme(Tm, k, S, nm, f)
        val.append(P.sum() - 1. if P.min() > 0 else np.nan)
    val = np.array(val)
    j = np.where(np.isfinite(val[:-1]) & np.isfinite(val[1:]) & (val[:-1]*val[1:] <= 0))[0]
    if len(j) == 0:
        return np.nan, None
    lo, hi = fs[j[0]], fs[j[0] + 1]
    slo = cloudy_scheme(Tm, k, S, nm, lo).sum() - 1.
    for _ in range(60):
        mid = 0.5*(lo + hi)
        smid = cloudy_scheme(Tm, k, S, nm, mid).sum() - 1.
        if smid*slo <= 0:
            hi = mid
        else:
            lo, slo = mid, smid
    f = 0.5*(lo + hi)
    return f, cloudy_scheme(Tm, k, S, nm, f)


def main(base, show_levels=False, only=None, save=None):
    AX = read_AX()
    cases = sorted(d for d in os.listdir(base) if d.startswith('T') and os.path.isdir(os.path.join(base, d)))
    if only:
        cases = [c for c in cases if c == only]
    # where H2 is too scarce Cloudy does not evaluate its large model and saves no populations
    skipped = [c for c in cases if len(open(os.path.join(base, c, 'pump.pops')).readlines()) < 10]
    cases = [c for c in cases if c not in skipped]
    if skipped:
        print('no large-H2 evaluation in Cloudy (skipped): ' + ', '.join(skipped))
    wd = os.path.join(base, 'h2test')
    os.makedirs(wd, exist_ok=True)
    info = {}
    with open(os.path.join(wd, 'cases.txt'), 'w') as f:
        for cdir in cases:
            ci = cloudy_case(os.path.join(base, cdir))
            info[cdir] = ci
            np.savetxt(os.path.join(wd, cdir + '.field'), np.c_[ci['fw'], ci['eta']], fmt='%.8e')
            f.write(f'{cdir} {ci["T"]} ' + ' '.join(f'{x:.6e}' for x in ci['dens'])
                    + f' {cdir}.field ' + ' '.join(f'{x:.6e}' for x in ci['w']) + '\n')
    subprocess.run([os.path.join(HERE, 'h2Test'), os.path.join(HERE, 'dataPDR', 'h2'), 'cases.txt', 'dump'],
                   cwd=wd, check=True, stdout=subprocess.DEVNULL)

    print('A: pump rate per level, ours/Cloudy over Cloudy\'s matrix levels (median, min, max); nm = their number')
    print('S: Solomon rate [s-1] of H2g and H2*: Cloudy\'s network rate, ours/Cloudy (ours with Cloudy populations), '
          'and for H2* ours + Cloudy\'s direct term')
    print('B: radiative rate into each level, ours/Cloudy (median, min, max; ours with Cloudy populations)')
    print('  case           nm  A med   min   max |  Sol g(C)  ours/C  Sol *(C)  ours/C  +direct |  B med   min   max')
    out = {}
    rows = []
    for cdir in cases:
        ci = info[cdir]
        a = np.loadtxt(os.path.join(wd, cdir + '.h2pops'))
        n = len(a)
        lev = [(int(r[0]), int(r[1])) for r in a]
        v = np.array([k[0] for k in lev]); J = np.array([k[1] for k in lev])
        E = a[:, 2]; po = a[:, 3]; pump = a[:, 4]; kdiss = a[:, 5]; phi = a[:, 6]
        raw = np.fromfile(os.path.join(wd, cdir + '.h2W'))
        W = raw[:n*n].reshape((n, n), order='F')
        R = raw[n*n:].reshape((n, n), order='F')            # collisions + A
        cl = np.array([ci['rows'][k] for k in lev])
        pc, rcout, rrout, rcin, rrin = cl.T
        nt = ci['ntot']
        # Cloudy's radiative loop within X keeps only lower levels of v <= the upper level's
        Aok = AX*(v[None, :] <= v[:, None])
        # the levels above Cloudy's matrix: RRout holds the A's as well as the pump
        dec = Aok.sum(1) > 3e-3*pump
        above = dec & ((rrout - pump) > 0.5*Aok.sum(1))
        nm = int(np.where(above)[0].min()) if above.any() else n
        m = np.arange(n) < nm
        ra = (pump/rrout)[m]
        g = E <= E_STAR
        sg = (pc[g]*kdiss[g]).sum()/pc[g].sum()
        ss = (pc[~g]*kdiss[~g]).sum()/pc[~g].sum()
        into = pc @ W + np.array([(pc[max(i + 1, nm):]*Aok[max(i + 1, nm):, i]).sum() for i in range(n)])
        ok = rrin > 0
        rb = (into*nt)[ok]/rrin[ok]
        print(f'  {cdir:13s} {nm:3d} {np.median(ra):6.3f} {ra.min():5.3f} {ra.max():5.3f} | '
              f'{ci["sol"]["H2"]:9.3e} {sg/ci["sol"]["H2"]:6.3f} {ci["sol"]["H2*"]:9.3e} {ss/ci["sol"]["H2*"]:6.3f} '
              f'{(ss + ci["direct"])/ci["sol"]["H2*"]:7.3f} | '
              f'{np.median(rb):6.3f} {rb.min():5.3f} {rb.max():5.3f}')
        # D: our rates through Cloudy's scheme
        Tm = R + W
        np.fill_diagonal(Tm, 0.)
        k = kdiss.copy()
        k[g] += ci['sol']['H2']
        S = phi*ci['form']
        fD, pD = solve_scheme(Tm, k, S, nm)
        up = ~m
        fC = np.median((pc*(rcout + rrout)/((rcin + rrin)/nt + S))[up]) if up.any() else np.nan
        rows.append((cdir, ci, lev, po, pc, pD, fC, fD, E, J, kdiss))
        out[cdir] = dict(v=v, J=J, E=E, ours=po, cloudy=pc, scheme=pD if pD is not None else po*np.nan,
                         fC=fC, fD=fD, nm=nm)

    hdr = ' '.join(f'{v},{j}'.rjust(6) for v, j in KEY)
    print()
    print('C: populations, ours/Cloudy; o/p; f* = fraction above 4100 cm-1; Solomon rate per H2 [s-1] from each '
          'code\'s own populations; median |log10 ratio| over levels with Cloudy pop > 1e-12')
    print('  case          o/p(C) o/p(us)  f*(C)    f*(us)   Sol(C)    Sol(us)  ' + hdr + '  med|dex| (n)')
    for cdir, ci, lev, po, pc, pD, fC, fD, E, J, kdiss in rows:
        opU = po[J % 2 == 1].sum()/po[J % 2 == 0].sum()
        opC = ci['op']['ortho']/ci['op']['para']
        g = E <= E_STAR
        solC = (ci['sol']['H2']*ci['c']['H2'] + ci['sol']['H2*']*ci['c']['H2*'])/(ci['c']['H2'] + ci['c']['H2*'])
        rat = [po[lev.index(k)]/pc[lev.index(k)] for k in KEY]
        sel = (pc > 1e-12) & (po > 0)
        dex = np.abs(np.log10(po[sel]/pc[sel]))
        print(f'  {cdir:13s} {opC:6.3f} {opU:6.3f} {pc[~g].sum():9.2e} {po[~g].sum():9.2e} {solC:9.2e} {(po*kdiss).sum():9.2e} '
              + ' '.join(f'{r:6.3f}' for r in rat) + f'  {np.median(dex):6.3f} ({sel.sum()})')
        if show_levels:
            idx = np.where(sel)[0]
            worst = idx[np.argsort(-dex)][:6]
            print('      worst: ' + '; '.join(f'{lev[i]} C {pc[i]:.2e} us {po[i]:.2e}' for i in worst))
    print()
    print('D: our rates through Cloudy\'s scheme, populations/Cloudy; f(C) from Cloudy\'s saved rates, f(D) from ours; '
          'max = largest |ratio - 1| over levels with Cloudy pop > 1e-8')
    print('  case           f(C)    f(D)   ' + hdr + '  med|dex|    max')
    for cdir, ci, lev, po, pc, pD, fC, fD, E, J, kdiss in rows:
        if pD is None:
            print(f'  {cdir:13s} {fC:6.4f}  no solution with positive populations')
            continue
        rat = [pD[lev.index(k)]/pc[lev.index(k)] for k in KEY]
        sel = pc > 1e-12
        dex = np.abs(np.log10(pD[sel]/pc[sel]))
        big = pc > 1e-8
        print(f'  {cdir:13s} {fC:6.4f}  {fD:6.4f}  ' + ' '.join(f'{r:6.3f}' for r in rat)
              + f'  {np.median(dex):6.3f}  {np.abs(pD[big]/pc[big] - 1).max():6.3f}')
    if save:
        np.savez(save, **{f'{c}__{k}': np.asarray(v) for c, d in out.items() for k, v in d.items()})


if __name__ == '__main__':
    argv = sys.argv[1:]
    only = save = None
    if '--case' in argv:
        only = argv[argv.index('--case') + 1]
    if '--save' in argv:
        save = argv[argv.index('--save') + 1]
    args = [a for a in argv if not a.startswith('--') and a not in (only, save)]
    main(args[0], '--levels' in argv, only, save)
