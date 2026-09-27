#!/usr/bin/env python3
"""D-370: where a run's Hbeta comes from, term by term.

outputGas reports Hbeta from the power law 2530/T^0.833 (output_mod.f90
RecLinesEmission), while every other H I line in lineFlux.out is a ratio from
Storey & Hummer's case B table, data/e1bx.dat, via hlinex. This tool reads the
run's grid and prints, per run:

  - the emission measure sum(n_e n_p dV) over the whole nebula (x8 for the
    symmetricXYZ octant) and its n_e n_p-weighted temperature;
  - the factor sum(n_e n_p dV j_table(T, n_e)) / sum(n_e n_p dV j_power(T)),
    i.e. what Hbeta becomes if it is taken from the same table as the other
    H I lines, at each cell's own T and n_e (interpolated as hlinex does: in
    log n_e and sqrt T, log emissivity; clamped to the table's domain);
  - the reported Hbeta and the table-based one.

With --cloudy PREFIX it also integrates Cloudy's overview (PREFIX.ovr, inner
radius from PREFIX's 'radius' command in common.inc or the .in file) the same
way, so the emission measure and temperature can be compared. Reads files on
disk only.

    python tools/d370_hbeta.py runs/d366-hii --cloudy runs/d356-cloudy-hii/hiipdr
    python tools/d370_hbeta.py runs/d363-pn
"""
import argparse
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def sh_table():
    """Hbeta (4->2) emissivity 4 pi j/(n_e n_p) [erg cm^3/s] on e1bx.dat's grid."""
    L = open(os.path.join(HERE, 'data', 'e1bx.dat')).read().splitlines()
    i, tab = 1, {}
    while i < len(L):
        h = L[i]
        dens, T = float(h[1:11]), float(h[16:26])
        ntop, _, nlu, nll = [int(h[31 + 5 * k:36 + 5 * k]) for k in range(4)]
        ne = (2 * ntop - nlu - nll) * (nlu - nll + 1) // 2
        v = []
        i += 1
        while len(v) < ne:
            v += [float(x) for x in L[i].split()]
            i += 1
        # lower level 2 first, upper levels from ntop down: 4->2 is ntop-4
        tab[(dens, T)] = v[ntop - 4]
    Ts = np.array(sorted({k[1] for k in tab}))
    Ds = np.array(sorted({k[0] for k in tab}))
    G = np.array([[tab[(d, t)] for t in Ts] for d in Ds])
    return Ts, Ds, np.log10(G)


TS, DS, LG = sh_table()


def j_table(T, ne):
    T = np.clip(T, TS[0], TS[-1])
    ne = np.clip(ne, DS[0], DS[-1])
    sT = np.sqrt(TS)
    out = np.empty(len(T))
    for m in range(len(T)):
        a = np.array([np.interp(np.sqrt(T[m]), sT, LG[k]) for k in range(len(DS))])
        out[m] = 10 ** np.interp(np.log10(ne[m]), np.log10(DS), a)
    return out


def j_power(T):
    return 2530. / T ** 0.833 * 1e-25


def moc(run):
    d = R.read_run(run)
    out = os.path.join(run, 'output')
    t = open(os.path.join(out, 'grid0.out')).read().split()
    nx = int(t[1])
    xa = np.array(t[7:7 + nx], float)
    # symmetric grids put the first cell centre on the plane: half width
    e = np.concatenate([[xa[0]], 0.5 * (xa[1:] + xa[:-1]), [xa[-1]]])
    w = np.diff(e)
    W = (w[:, None, None] * w[None, :, None] * w[None, None, :]).ravel()
    act = np.array(t[7 + 3 * nx:7 + 3 * nx + nx ** 3 * 3:3], float).astype(int) > 0
    em = d['e-'] * d['H+'] * W[act] * 8.
    s = em > 0.
    T, ne, em = d['Tgas'][s], d['e-'][s], em[s]
    rep = float([ln for ln in open(os.path.join(out, 'lineFlux.out'))
                 if 'Hbeta [E36' in ln][0].split()[-1])
    return em.sum(), (em * T).sum() / em.sum(), \
        (em * j_table(T, ne)).sum() / (em * j_power(T)).sum(), rep


def cloudy(pref):
    L = open(pref + '.ovr').read().splitlines()
    h = L[0].lstrip('#').split('\t')
    a = np.array([[float(x) for x in ln.split('\t')] for ln in L[1:]
                  if ln and not ln.startswith('#')])
    rin = None
    for f in [os.path.join(os.path.dirname(pref), 'common.inc'), pref + '.in']:
        if os.path.exists(f):
            m = re.search(r'^radius\s*=?\s*([0-9.eE+-]+)', open(f).read(), re.M)
            if m:
                rin = 10 ** float(m.group(1))
                break
    if rin is None:
        raise SystemExit('no radius command found for ' + pref)
    r = rin + a[:, 0]
    dV = 4 * np.pi * r ** 2 * np.gradient(r)
    em = a[:, h.index('eden')] * a[:, h.index('hden')] * a[:, h.index('HII')] * dV
    T = a[:, 1]
    return em.sum(), (em * T).sum() / em.sum(), (em * j_table(T, a[:, h.index('eden')])).sum()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('runs', nargs='+')
    ap.add_argument('--cloudy')
    o = ap.parse_args()
    ref = None
    if o.cloudy:
        ref = cloudy(o.cloudy)
        print(f"Cloudy {o.cloudy}: EM {ref[0]:.4e} cm^-3  <T>_EM {ref[1]:.0f} K  "
              f"Hbeta from the table {ref[2] / 1e36:.4g} E36")
    for run in o.runs:
        EM, T, f, rep = moc(run)
        line = (f"{run}: EM {EM:.4e} cm^-3  <T>_EM {T:.0f} K  table/power law {f:.4f}  "
                f"Hbeta reported {rep:.4g} -> table {rep * f:.4g} E36")
        if ref:
            line += f"  [EM/Cloudy {EM / ref[0]:.3f}, T/Cloudy {T / ref[1]:.3f}]"
        print(line)


if __name__ == '__main__':
    main()
