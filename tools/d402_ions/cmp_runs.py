"""D-402. Two runs of one fixture side by side, with Cloudy where it has the
quantity: the [D402] report of each, Hbeta and run time, every line of
lineFlux.out and lineFluxMol.out that moved, and median profiles by radius of
MOCASSIN's own ions, the electrons and the chemistry's molecules.

Usage: python3 tools/d402_ions/cmp_runs.py hii|pn <base run> <new run> [<Cloudy prefix>]
"""
import os
import re
import sys
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import d260_roellig as R

fx, base, new = sys.argv[1:4]
ref = sys.argv[4] if len(sys.argv) > 4 else None
if fx == 'hii':
    RIN, RADII, DR = 3e18, (2.0, 4.0, 6.0, 7.5, 8.5, 9.5, 10.5, 11.5, 12.5, 14.0, 16.0, 18.0), 0.35
else:
    RIN, RADII, DR = 1e16, (0.03, 0.06, 0.09, 0.115, 0.14, 0.17, 0.21, 0.25, 0.29, 0.33, 0.37, 0.45, 0.55), 0.008


def log(run):
    return open(os.path.join(run, 'run.log'), errors='replace').read()


def lines(run, name):
    """lineFlux.out as {(ion, wavelength, occurrence): L/Hbeta}"""
    d, ion, seen = {}, '', {}
    hb = None
    for l in open(os.path.join(run, 'output', name)):
        t = l.split()
        if 'Hbeta [E36 erg/s]' in l and hb is None:
            hb = float(t[-1])
        if len(t) == 1 and not re.match(r'^[-+0-9.Ee]+$', t[0]):
            ion = t[0]
        elif len(t) == 2:
            try:
                w, v = float(t[0]), float(t[1])
            except ValueError:
                continue
            k = (ion, w)
            seen[k] = seen.get(k, 0) + 1
            d[(ion, w, seen[k])] = v
    return hb, d


def mol(run):
    d = {}
    for l in open(os.path.join(run, 'output', 'lineFluxMol.out')):
        if l.startswith('#'):
            continue
        t = l.split()
        d[(t[0], t[1], t[2], t[3])] = float(t[-1])
    return d


print('=== %s: %s -> %s' % (fx, os.path.basename(base.rstrip('/')), os.path.basename(new.rstrip('/'))))
for r in (base, new):
    lg = log(r)
    tm = re.search(r'total run time per processor\s+(\S+)', lg)
    last = [l for l in lg.splitlines() if 'D402] iteration' in l or 'D358] iteration' in l]
    it = re.findall(r'\[D354\] iteration\s+(\d+)', lg)
    print('--', os.path.basename(r.rstrip('/')), ' run time', tm.group(1) if tm else '?', ' last chemistry iteration', it[-1] if it else '?')
    k = 4 if 'D402]' in ''.join(last[-4:]) else 1
    for l in last[-k:]:
        print('   ', l.strip()[:400])

hb0, l0 = lines(base, 'lineFlux.out'); hb1, l1 = lines(new, 'lineFlux.out')
print('Hbeta [E36 erg/s]  %.5f -> %.5f  (%+.3f%%)' % (hb0, hb1, 100*(hb1/hb0-1)))
ch = []
for k in l0:
    if k in l1 and l0[k] > 1e-7 and l1[k] > 0:
        ch.append((abs(np.log(l1[k]/l0[k])), k, l0[k], l1[k]))
ch.sort(reverse=True)
print('lineFlux.out: %d lines above 1e-7 Hbeta; moved by more than 1%%: %d, more than 5%%: %d' % (
    len(ch), sum(1 for c in ch if c[0] > np.log(1.01)), sum(1 for c in ch if c[0] > np.log(1.05))))
byion = {}
for c in ch:
    byion.setdefault(c[1][0], []).append(c)
print('  by ion: largest change, and the strongest line of each ion that moved by more than 1%:')
for ion, cs in sorted(byion.items(), key=lambda kv: -kv[1][0][0]):
    if cs[0][0] <= np.log(1.01):
        continue
    st = max(cs, key=lambda c: c[2])
    print('   %-8s lines %3d  largest x%.3f (%.2f A, %.2e)   strongest %.2f A  %.3e -> %.3e  x%.3f' % (
        ion, len(cs), cs[0][3]/cs[0][2], cs[0][1][1], cs[0][2], st[1][1], st[2], st[3], st[3]/st[2]))
m0, m1 = mol(base), mol(new)
print('lineFluxMol.out (L/Hbeta), base -> new, ratio:')
for k in m0:
    if k in m1 and m0[k] > 1e-12 and (k[1], k[2]) in (('2', '1'), ('3', '2'), ('4', '3')) or k[0] != '12co.dat':
        if k in m1 and m0[k] > 0:
            print('   %-9s %s-%s  %10.2f um  %.4e -> %.4e  x%.4f' % (k[0], k[1], k[2], float(k[3]), m0[k], m1[k], m1[k]/m0[k]))

A, B = R.read_run(base), R.read_run(new)
C = R.cloudy_as_run(ref, RIN) if ref else None
keys = ['Tgas', 'e-', 'H+', 'He+', 'C+', 'O+', 'Mg+', 'H', 'C', 'O', 'H2', 'CO', 'OH', 'H2O', 'CH', 'HCO+', 'H3+']
print('median over the cells within %.3g pc of each radius: base | new | new/base | Cloudy (n in cm^-3, T in K)' % DR)
for key in keys:
    print(' %s' % key)
    for rr in RADII:
        sa = np.abs(A['r'] - rr) < DR; sb = np.abs(B['r'] - rr) < DR
        if sa.sum() < 3 or sb.sum() < 3:
            continue
        a, b = float(np.median(A[key][sa])), float(np.median(B[key][sb]))
        c = ''
        if C is not None and key in C:
            j = np.argmin(np.abs(C['r'] - rr)); c = '%10.3e' % C[key][j]
        print('   r %6.3f  A_V %6.3f  %10.3e %10.3e  x%-9.3g %s' % (rr, float(np.median(A['AV'][sa])), a, b, b/a if a > 0 else float('nan'), c))
