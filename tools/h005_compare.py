#!/usr/bin/env python3
"""H-005: line self-shielding in h2_mod against a Cloudy PDR slab with its large
H2 model (runs/h005-cloudy-slab/<case>).

The level model is marched through Cloudy's own slab (h2Slab): each zone's T,
densities and n(H2), its dust-attenuated continuum (save continuum every 5
zones with line absorption switched off in the output, interpolated in depth)
and its split of grain formation come from Cloudy; the level populations, the
columns that shade the next zone and the dissociation rates are ours.

Two marches:
  federman  Cloudy's shielding choices (Federman et al. fit, damping from the
            line's own A, no averaging through the zone) - like for like,
            except that Cloudy's optical depth also holds the other lines at
            each line's centre (overlap), which ours does not;
  voigt     the model's own (Voigt line, damping from the upper level's total
            decay rate, averaged through the zone).

Both marches let a line's decay count by its escape probability (a photon
emitted in a thick line is absorbed again on the spot), two passes.

Checks:
  T  definitions: line-centre optical depth and damping parameter of each
     line at the far face against Cloudy's "save line optical depths", ours
     computed from Cloudy's own level columns;
  O  how much overlap adds in Cloudy: its total over its line-specific
     optical depth;
  R  Solomon rate against depth: Cloudy's "BigH2" (rate of H2g plus rate of
     H2*, each per molecule of its own kind) and ours formed the same way;
  D  the shielding of the H2g Solomon rate, rate(N)/rate(0) with the
     continuum's own attenuation divided out, against the fit of Draine &
     Bertoldi 1996 (ApJ 468, 269, eq. 37) with and without its line-overlap
     factor - an independent reference for the damping wings;
  P  where the pumping happens: the share of all absorptions that occur
     below a given N(H2);
  N  level column densities at the far face.

    python tools/h005_compare.py runs/h005-cloudy-slab/<case> [--save FILE.npz]
"""
import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RYD_WN = 109737.31568
RYD_HZ = 3.2898419603e15
H = 6.62607015e-27
C = 2.99792458e10
KB = 1.380649e-16
AMU = 1.66053907e-24
MH2 = 2.01588
E_STAR = 4100.


def rows(path):
    out = []
    for l in open(path):
        if l.startswith('#') or not l.strip():
            continue
        out.append(l.rstrip('\n').split('\t'))
    return out


def header(path):
    return [x.strip() for x in open(path).readline().lstrip('#').rstrip('\n').split('\t')]


def read_levels():
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
    return [(v, j) for e, v, j in lv], np.array([e for e, v, j in lv])


def cloudy_slab(d):
    ovr = np.array([[float(x) for x in r[:5]] for r in rows(os.path.join(d, 'slab.ovr'))])
    zmid = ovr[:, 0]; T = ovr[:, 1]
    nz = len(zmid)
    dr = np.zeros(nz); z0 = 0.
    for k in range(nz):
        dr[k] = 2*(zmid[k] - z0); z0 += dr[k]
    hd = header(os.path.join(d, 'slab.dens'))
    dens = np.array([[float(x) for x in r] for r in rows(os.path.join(d, 'slab.dens'))])
    col = {k: dens[:, i] for i, k in enumerate(hd)}
    for k in list(col):
        if k.startswith('depth'):
            col['depth'] = col.pop(k)
    # level populations per zone, relative to total H2
    pops = []
    opz = []
    for r in rows(os.path.join(d, 'slab.pops')):
        opz.append((float(r[0]), float(r[1]), float(r[2])))
        p = {}; v = None; j = 0
        for tok in r[5:]:
            if tok.startswith('v='):
                v = int(tok[2:]); j = 0
            elif tok.strip():
                p[(v, j)] = float(tok); j += 1
        pops.append(p)
    rates = np.array([[float(x) for x in r] for r in rows(os.path.join(d, 'slab.rates'))])
    rh = header(os.path.join(d, 'slab.rates'))
    gh = header(os.path.join(d, 'slab.gh2'))
    g = np.array([[float(x) for x in r] for r in rows(os.path.join(d, 'slab.gh2'))])
    wcar = g[:, [i for i, k in enumerate(gh) if k.startswith('gra')]].sum(1)
    wsil = g[:, [i for i, k in enumerate(gh) if k.startswith('sil')]].sum(1)
    # continuum blocks: zone 1, every 5th zone, and the last
    blocks = [[]]
    for l in open(os.path.join(d, 'slab.con')):
        if l.startswith('#Cont'):
            continue
        if l.startswith('###'):
            blocks.append([]); continue
        s = l.split('\t')
        blocks[-1].append((float(s[0]), float(s[1]), float(s[2])))
    blocks = [np.array(b) for b in blocks if len(b)]
    bz = [1] + [5*k for k in range(1, nz//5 + 1)]
    if nz % 5 != 0:
        bz.append(nz)
    assert len(bz) == len(blocks), (len(bz), len(blocks), nz)
    nu = blocks[0][:, 0]
    sel = (nu > 0.3) & (nu < 1.2)
    eta = np.array([b[sel, 2]*C**2/(8*np.pi*H*(b[sel, 0]*RYD_HZ)**4) for b in blocks])
    zb = np.array([zmid[k - 1] for k in bz])
    return dict(nz=nz, zmid=zmid, dr=dr, T=T, col=col, pops=pops, opz=np.array(opz), rates=rates, rh=rh,
                wcar=wcar, wsil=wsil, fw=nu[sel]*RYD_WN, eta=eta, zb=zb, inc=blocks[0][sel, 1], tr0=blocks[0][sel, 2])


def main(d, save=None):
    lev, E = read_levels()
    nx = len(lev)
    cs = cloudy_slab(d)
    nz = cs['nz']
    n = min(nz, len(cs['pops']), len(cs['rates']), len(cs['col']['H']), len(cs['wcar']))
    if n != nz:
        print(f'zones: overview {nz}, populations {len(cs["pops"])}, rates {len(cs["rates"])}; using {n}')
    nz = n
    wd = os.path.join(d, 'h2slab')
    os.makedirs(wd, exist_ok=True)
    # log eta interpolated in depth between the saved zones
    le = np.log(np.maximum(cs['eta'], 1e-300))
    with open(os.path.join(wd, 'slab.txt'), 'w') as f:
        f.write(f'{nz} {len(cs["fw"])} 0.0\n')
        f.write(' '.join(f'{x:.6f}' for x in cs['fw']) + '\n')
        c = cs['col']
        for k in range(nz):
            z = cs['zmid'][k]
            j = min(max(np.searchsorted(cs['zb'], z) - 1, 0), len(cs['zb']) - 2)
            t = (z - cs['zb'][j])/(cs['zb'][j + 1] - cs['zb'][j])
            e = np.exp(le[j] + t*(le[j + 1] - le[j]))
            f.write(f'{cs["dr"][k]:.6e} {cs["T"][k]:.4f} {c["H"][k]:.6e} {c["He"][k]:.6e} '
                    f'{c["H2"][k] + c["H2*"][k]:.6e} {c["H+"][k] + c["H3+"][k]:.6e} 0.0 {cs["wsil"][k]:.6e} {cs["wcar"][k]:.6e}\n')
            f.write(' '.join(f'{x:.5e}' for x in e) + '\n')
    res = {}
    for mode in ('federman', 'voigt'):
        r = subprocess.run([os.path.join(HERE, 'h2Slab'), os.path.join(HERE, 'dataPDR', 'h2'), 'slab.txt', mode, mode],
                           cwd=wd, check=True, capture_output=True, text=True)
        zones = np.loadtxt(os.path.join(wd, mode + '.zones'))
        pops = np.fromfile(os.path.join(wd, mode + '.pops')).reshape((nz, nx))
        cols = np.loadtxt(os.path.join(wd, mode + '.cols'))[:, 3]
        res[mode] = dict(zones=zones, pops=pops, cols=cols)
    nH2 = cs['col']['H2'][:nz] + cs['col']['H2*'][:nz]
    pc = np.array([[cs['pops'][k].get(l, 0.) for l in lev] for k in range(nz)])
    colC = (pc*(nH2*cs['dr'][:nz])[:, None]).sum(0)
    NH2in = np.concatenate([[0.], np.cumsum(nH2*cs['dr'][:nz])[:-1]])
    NHin = np.concatenate([[0.], np.cumsum((cs['col']['H'][:nz] + 2*nH2)*cs['dr'][:nz])[:-1]])

    # ---- T, O: Cloudy's line optical depths at the far face
    tau_path = os.path.join(d, 'slab.tau')
    if os.path.exists(tau_path) and os.path.getsize(tau_path) > 0:
        b = np.sqrt(2*KB*cs['T'][nz - 1]/(MH2*AMU))
        ours = np.loadtxt(os.path.join(wd, 'federman.tau'))          # written with OUR columns
        # rebuild tau0 with Cloudy's columns: tau0 = N_l (gu/gl) A lam^3 / (8 pi^1.5 b)
        lidx = {l: i for i, l in enumerate(lev)}
        wn = ours[:, 5]; A = ours[:, 6]
        lo = np.array([lidx[(int(r[3]), int(r[4]))] for r in ours])
        colO = res['federman']['cols']
        sig = np.where(colO[lo] > 0, ours[:, 7]/np.maximum(colO[lo], 1e-300), 0.)
        tauC_from_ours = sig*colC[lo]
        ct = []
        for r in rows(tau_path):
            if not r[0].strip().startswith('H2'):
                continue
            ct.append((float(r[1])*RYD_WN, float(r[2]), float(r[3]), float(r[4])))
        ct = np.array(ct)
        order = np.argsort(wn)
        wns = wn[order]
        i = np.clip(np.searchsorted(wns, ct[:, 0]), 1, len(wns) - 1)
        pick = np.where(np.abs(wns[i - 1] - ct[:, 0]) < np.abs(wns[i] - ct[:, 0]), i - 1, i)
        dw = np.abs(wns[pick] - ct[:, 0])
        # keep unambiguous matches: nearest within 0.05 cm-1 and next nearest 5x farther
        nxt = np.minimum(np.abs(wns[np.clip(pick - 1, 0, len(wns) - 1)] - ct[:, 0]) + (pick == 0)*1e9,
                         np.abs(wns[np.clip(pick + 1, 0, len(wns) - 1)] - ct[:, 0]) + (pick == len(wns) - 1)*1e9)
        okm = (dw < 0.05) & (nxt > 5*np.maximum(dw, 0.01))
        k = order[pick[okm]]
        spec = ct[okm, 2]/np.sqrt(np.pi)
        mean = ct[okm, 1]/np.sqrt(np.pi)
        big = spec > 1.
        rt = tauC_from_ours[k][big]/spec[big]
        ra = ours[k, 9][big]/ct[okm, 3][big]
        print(f'T: {okm.sum()} of {len(ct)} Cloudy H2 lines matched unambiguously; {big.sum()} with specific tau0 > 1')
        print(f'   tau0, ours (Cloudy columns) / Cloudy: median {np.median(rt):.4f}  16-84% {np.percentile(rt, 16):.4f} {np.percentile(rt, 84):.4f}'
              f'  min {rt.min():.3f} max {rt.max():.3f}')
        print(f'   damping a from the line\'s own A, ours / Cloudy: median {np.median(ra):.4f}  min {ra.min():.4f} max {ra.max():.4f}')
        rg = ours[k, 8][big]/ours[k, 9][big]
        print(f'   a from the upper level\'s total decay rate over a from the line\'s A: median {np.median(rg):.1f}'
              f'  16-84% {np.percentile(rg, 16):.1f} {np.percentile(rg, 84):.1f}')
        ov = mean[big]/spec[big]
        print(f'O: Cloudy\'s total / line-specific tau0 (overlap), lines with specific tau0 > 1: median {np.median(ov):.3f}'
              f'  84% {np.percentile(ov, 84):.3f}  95% {np.percentile(ov, 95):.2f}  max {ov.max():.1f}')
    else:
        print('T, O: no slab.tau yet')

    # ---- R: Solomon rate against depth
    iB = cs['rh'].index('BigH2')
    solC = cs['rates'][:nz, iB]
    print()
    print('R: Solomon rate, H2g rate + H2* rate [s-1], against depth; ours over Cloudy\'s')
    print('   N(H2) to the zone     N(H)        Cloudy      federman  voigt   | Sol_g: federman  voigt  [s-1]')
    marks = [0, 1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 3e20, 1e21, 3e21]
    for m in marks:
        k = int(np.searchsorted(NH2in, m))
        if k >= nz:
            break
        f = res['federman']['zones'][k]; v = res['voigt']['zones'][k]
        print(f'   {NH2in[k]:10.3e}        {NHin[k]:10.3e}  {solC[k]:10.3e}  {(f[3] + f[4])/solC[k]:7.3f}  {(v[3] + v[4])/solC[k]:7.3f}'
              f'   |  {f[3]:10.3e} {v[3]:10.3e}')
    # ---- D: shielding against Draine & Bertoldi 1996
    lw = (cs['fw'] > 91000.) & (cs['fw'] < 109000.)
    att = np.zeros(nz)
    for k in range(nz):
        z = cs['zmid'][k]
        j = min(max(np.searchsorted(cs['zb'], z) - 1, 0), len(cs['zb']) - 2)
        t = (z - cs['zb'][j])/(cs['zb'][j + 1] - cs['zb'][j])
        att[k] = np.median(np.exp(le[j][lw] + t*(le[j + 1][lw] - le[j][lw]) - le[0][lw]))
    b5 = np.sqrt(2*KB*cs['T'][0]/(MH2*AMU))/1e5

    def db96(N, overlap=True):
        x = N/5e14
        w = 0.035/np.sqrt(1 + x)
        if overlap:
            w = w*np.exp(-8.5e-4*np.sqrt(1 + x))
        return 0.965/(1 + x/b5)**2 + w
    zf = res['federman']['zones']; zv = res['voigt']['zones']
    print()
    print(f'D: shielding of the H2g Solomon rate against Draine & Bertoldi 1996 (b = {b5:.3f} km/s); '
          'atten = continuum left at 912-1100 A')
    print('   N(H2)       atten      DB96        voigt/DB96  voigt/DB96 without overlap  federman/DB96   o/p: voigt federman Cloudy')
    Jl = np.array([l[1] for l in lev])
    opC = pc[:, Jl % 2 == 1].sum(1)/pc[:, Jl % 2 == 0].sum(1)
    for m in [1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 3e20, 1e21]:
        k = int(np.searchsorted(NH2in, m))
        if k >= nz:
            break
        sv = zv[k, 3]/zv[0, 3]/att[k]; sf = zf[k, 3]/zf[0, 3]/att[k]
        print(f'   {NH2in[k]:9.2e}  {att[k]:9.3e}  {db96(NH2in[k]):9.3e}   {sv/db96(NH2in[k]):7.3f}      {sv/db96(NH2in[k], False):7.3f}'
              f'                 {sf/db96(NH2in[k]):7.3f}       {zv[k, 7]:7.2f} {zf[k, 7]:7.2f} {opC[k]:7.2f}')
    # ---- P: where the pumping happens
    print()
    print('P: share of all pumping absorptions that occur below N(H2), and their total [cm-2 s-1]')
    for mode, z in (('federman', zf), ('voigt', zv)):
        ev = z[:, 6]*nH2*cs['dr'][:nz]
        c = np.cumsum(ev)/ev.sum()
        print(f'   {mode:9s} ' + '  '.join(f'{m:.0e}: {c[min(int(np.searchsorted(NH2in, m)), nz - 1)]:.3f}'
                                           for m in [1e16, 1e18, 1e19, 1e20, 3e20, 1e21]) + f'   total {ev.sum():.3e}')
    # ---- N: columns
    print()
    print('N: level columns at the far face [cm-2], ours over Cloudy\'s')
    print('   level    Cloudy      federman  voigt')
    for l in [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4), (0, 5), (0, 7), (1, 0), (1, 1), (1, 2), (1, 3), (2, 1), (2, 3), (3, 3), (4, 3), (6, 3)]:
        i = lev.index(l)
        print(f'   {str(l):8s} {colC[i]:10.3e}  {res["federman"]["cols"][i]/colC[i]:7.3f}  {res["voigt"]["cols"][i]/colC[i]:7.3f}')
    for mode in ('federman', 'voigt'):
        r = res[mode]['cols']/colC
        s = E > E_STAR
        print(f'   {mode}: N(H2*) ours/Cloudy {res[mode]["cols"][s].sum()/colC[s].sum():.3f}; '
              f'median over v >= 1 levels {np.median(r[np.array([l[0] >= 1 for l in lev])]):.3f}')
    if save:
        np.savez(save, lev=np.array(lev), E=E, NH2in=NH2in, NHin=NHin, solC=solC, colC=colC, att=att,
                 db96=db96(NH2in), db96no=db96(NH2in, False),
                 zf=res['federman']['zones'], zv=res['voigt']['zones'],
                 colF=res['federman']['cols'], colV=res['voigt']['cols'],
                 popC=pc, popF=res['federman']['pops'], popV=res['voigt']['pops'])


if __name__ == '__main__':
    argv = sys.argv[1:]
    save = argv[argv.index('--save') + 1] if '--save' in argv else None
    args = [a for a in argv if not a.startswith('--') and a != save]
    main(args[0], save)
