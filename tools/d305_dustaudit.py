#!/usr/bin/env python3
"""D-305: audit MOCASSIN's dust optics against Draine's tabulated Q.

Checks the Mie path, the size-distribution quadrature, and the extinction
curve the model actually produces (R_V, A(1000A)/A_V, N_H/A_V).

    ~/miniforge3/envs/astro/bin/python tools/d305_dustaudit.py
from the repository root.
"""
import os
import sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from d305_mie import bhmie

DD = 'dustData/'
RUN = 'runs/d302-trim-on/input/'
def read_nk(p):
    a = np.loadtxt(p, skiprows=2); return a[:, 0], a[:, 1], a[:, 2]

lam1, n1, k1 = read_nk(DD + 'grph1-dl.nk')
lam2, n2, k2 = read_nk(DD + 'grph2-dl.nk')

sz = np.loadtxt(RUN + 'dust_sizes.dat', skiprows=2)
a_um, nofa = sz[:, 1], sz[:, 2]
N = len(a_um)

def da_mocassin(a):
    d = np.zeros_like(a)
    d[0] = a[1] - a[0]
    d[1:-1] = (a[2:] - a[:-2]) / 2.
    d[-1] = a[-1] - a[-2]
    return d

def da_correct(a):
    """Midpoint bin edges - the standard quadrature for a tabulated n(a)."""
    e = np.empty(len(a) + 1)
    e[1:-1] = 0.5 * (a[1:] + a[:-1])
    e[0] = a[0] - (e[1] - a[0])
    e[-1] = a[-1] + (a[-1] - e[-2])
    return np.diff(e)

def weights(da):
    w = nofa * da
    return w / w.sum()

def Qmix(a, lam):
    tot_a = tot_s = 0.0
    for (lm, n, k), wt in [((lam2, n2, k2), 2/3.), ((lam1, n1, k1), 1/3.)]:
        nn, kk = np.interp(lam, lm, n), np.interp(lam, lm, k)
        x = min(2 * np.pi * a / lam, 100.0)
        qe, qs, g = bhmie(x, complex(nn, kk))
        tot_a += wt * (qe - qs); tot_s += wt * qs
    return tot_a, tot_s

RHO = 2.2                       # g/cm^3, from the .nk header
MDMG = 2.4827e-3                # input.in
MU = 1.4 * 1.6726e-24           # gas mass per H nucleus, He-bearing

print('MOCASSIN grain size distribution: %d bins, %.4g - %.4g um, n(a) ~ a^%.2f'
      % (N, a_um[0], a_um[-1],
         np.polyfit(np.log(a_um), np.log(nofa), 1)[0]))

dm, dc = da_mocassin(a_um), da_correct(a_um)
print('\nbin widths: MOCASSIN vs midpoint quadrature')
for i in [0, 1, N // 2, N - 2, N - 1]:
    print('  bin %2d  a=%.5f  da_moc=%.5e  da_mid=%.5e  ratio %.3f'
          % (i + 1, a_um[i], dm[i], dc[i], dm[i] / dc[i]))

wm, wc = weights(dm), weights(dc)
print('\nnumber fraction in the smallest bin: MOCASSIN %.4f, correct %.4f'
      % (wm[0], wc[0]))
print('number fraction in the largest  bin: MOCASSIN %.4e, correct %.4e'
      % (wm[-1], wc[-1]))

LAMV, LAMB, LFUV = 0.55, 0.44, 0.1
rows = []
for lam in (LFUV, LAMB, LAMV):
    qa = np.array([Qmix(a, lam) for a in a_um])
    Cext = (qa[:, 0] + qa[:, 1]) * np.pi * (a_um * 1e-4) ** 2
    Cabs = qa[:, 0] * np.pi * (a_um * 1e-4) ** 2
    rows.append((lam, Cext, Cabs))

mass = (4 / 3.) * np.pi * (a_um * 1e-4) ** 3 * RHO

print('\n=== what the two quadratures give ===')
hdr = ' lam[um] |  <Cext>/<m> [cm2/g]      | tau/N_H [cm2/H]          | moc/mid'
print(hdr); print('-' * len(hdr))
for lam, Cext, Cabs in rows:
    km, kc = (wm * Cext).sum() / (wm * mass).sum(), (wc * Cext).sum() / (wc * mass).sum()
    tm, tc = km * MDMG * MU, kc * MDMG * MU
    print('%8.4f | %11.4e %11.4e | %11.4e %11.4e | %6.3f'
          % (lam, km, kc, tm, tc, km / kc))

def AV_per_H(w):
    lam, Cext, _ = rows[2]
    k = (w * Cext).sum() / (w * mass).sum()
    return 1.0857 * k * MDMG * MU          # mag per H column

for nm, w in [('MOCASSIN da', wm), ('midpoint da', wc)]:
    av = AV_per_H(w)
    print('\n%s: A_V/N_H = %.4e mag cm^2   ->   N_H/A_V = %.4e cm^-2 mag^-1'
          % (nm, av, 1. / av))
print('  standard ISM (Bohlin+78 / Draine 03): N_H/A_V = 1.87e21')

print('\n=== R_V and the FUV-to-V ratio ===')
for nm, w in [('MOCASSIN da', wm), ('midpoint da', wc)]:
    kf = (w * rows[0][1]).sum() / (w * mass).sum()
    kb = (w * rows[1][1]).sum() / (w * mass).sum()
    kv = (w * rows[2][1]).sum() / (w * mass).sum()
    print('  %-12s  A(1000A)/A_V = %.3f   R_V = A_V/(A_B-A_V) = %.2f'
          % (nm, kf / kv, 1. / (kb / kv - 1.)))
print('  Milky Way (Draine 2003, R_V=3.1): A(1000A)/A_V ~ 2.6-2.8, R_V = 3.1')

print('\n=== which sizes carry the FUV absorption (MOCASSIN da) ===')
lam, Cext, Cabs = rows[0]
sh = wm * Cabs / (wm * Cabs).sum()
cum = np.cumsum(sh)
for i in range(0, N, 4):
    print('  a=%.4f um  share %.4f  cumulative %.4f' % (a_um[i], sh[i], cum[i]))
print('  a=%.4f um  share %.4f  cumulative %.4f' % (a_um[-1], sh[-1], cum[-1]))

# --- the Mie path against Draine's own tabulated Q -------------------------
def read_Q(p):
    a = np.loadtxt(p, skiprows=7)
    return a[:, 0], a[:, 1], a[:, 2], a[:, 3]


def mie_vs_draine():
    aG, lG, QaG, _ = read_Q(DD + 'Car_90.cat')
    print('\n=== Mie-from-nk against Draine tabulated Q (Car_90.cat) ===')
    hdr = '   a[um]   lam[um]  |  MOCASSIN     Draine   ratio'
    print(hdr); print('-' * len(hdr))
    ua = np.unique(aG)
    for a0 in (0.005, 0.05, 0.25):
        an = ua[np.argmin(abs(ua - a0))]
        sel = aG == an
        ll, qq = lG[sel][::-1], QaG[sel][::-1]
        for lam in (0.0912, 0.15, 0.55, 1.0, 10.0, 100.0):
            qm = Qmix(a0, lam)[0]
            qd = np.interp(lam, ll, qq)
            print('%8.3f %9.4f  | %10.3e %10.3e %7.3f' % (an, lam, qm, qd, qm / qd))
        print()

    print('=== BHmie fixed-array bound: nmx ~ max(x,|m|x)+15 against d(3000) ===')
    for f in ('grph1-dl.nk', 'grph2-dl.nk'):
        lm, n, k = read_nk(DD + f)
        x = np.minimum(2 * np.pi * a_um[:, None] / lm[None, :], 100.0)
        print('  %-14s max|m| %6.1f   max|m|x %6.1f' %
              (f, np.abs(n + 1j * k).max(), (np.abs(n + 1j * k)[None, :] * x).max()))


mie_vs_draine()
