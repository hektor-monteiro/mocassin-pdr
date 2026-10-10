"""H-026: two Cloudy models of pn150k side by side (the reference, and the reference without chlorine).
    python tools/h026_cloudy_pair.py <prefix a> <prefix b> [<numbers.json>]"""
import json
import os
import sys
import numpy as np
PC = 3.0856776e18
RIN = 1e16


def table(p):
    h = open(p).readline().lstrip('#').rstrip('\n').split('\t')
    return [x.strip() for x in h], np.loadtxt(p, comments='#', delimiter='\t', ndmin=2)


def model(prefix):
    ho, o = table(prefix + '.ovr')
    hd, dn = table(prefix + '.dens')
    h3, d3 = table(prefix + '.dens389')
    assert len(d3) == len(o) == len(dn)
    d = dict(depth=o[:, 0], AV=o[:, ho.index('AV(point)')], T=o[:, ho.index('Te')], nH=o[:, ho.index('hden')],
             H=dn[:, hd.index('H')], Hp=dn[:, hd.index('H+')], CO=dn[:, hd.index('CO')],
             H2=d3[:, h3.index('H2')] + d3[:, h3.index('H2*')])
    d['r'] = (d['depth'] + RIN) / PC
    d['x2'] = 2 * d['H2'] / d['nH']
    rate = {}
    for ext in ('.H2de', '.H2sde'):
        h, t = table(prefix + ext)
        for i, name in enumerate(h[1:], 1):
            if name and not ({'H2', 'H2*'} & set(name.split('=>')[1].split(','))):
                rate[name] = rate.get(name, 0) + t[:, i]
    d['sink'] = sum(rate.values()) / np.maximum(d['H2'], 1e-300)
    d['phot'] = sum(v for k, v in rate.items() if k.startswith('PHOTON,H2') and ('=>H,H' in k or '=>PHOTON,H,H' in k)) / np.maximum(d['H2'], 1e-300)
    he, e = table(prefix + '.h2emis')
    r = RIN + e[:, 0]
    L = lambda c: float(np.trapezoid(e[:, he.index(c)] * 4 * np.pi * r ** 2, r))
    d['Hbeta'] = L('H  1 4861.32A')
    d['lines'] = {c.split()[1]: L(c) / d['Hbeta'] for c in he[1:] if c.startswith('H2')}
    return d


def at(d, y, val, x='AV'):
    yl = np.log10(np.maximum(d[y], 1e-300))
    k = np.where((yl[:-1] < np.log10(val)) & (yl[1:] >= np.log10(val)))[0]
    return float(d[x][k[0]] + (np.log10(val) - yl[k[0]]) / (yl[k[0] + 1] - yl[k[0]]) * (d[x][k[0] + 1] - d[x][k[0]])) if len(k) else None


M = [model(p) for p in sys.argv[1:3]]
O = {'prefix': sys.argv[1:3]}
print('                                  a          b        b - a  (or b/a)')
row = []
for d in M:
    k = np.where(np.diff(np.sign(2 * d['H2'] - d['H'])) > 0)[0][0]
    f = (d['H'][k] - 2 * d['H2'][k]) / ((2 * d['H2'][k + 1] - d['H'][k + 1]) + (d['H'][k] - 2 * d['H2'][k]))
    row.append((float(d['AV'][k] + f * (d['AV'][k + 1] - d['AV'][k])), float(d['r'][k] + f * (d['r'][k + 1] - d['r'][k]))))
print('H/H2 crossing A_V            %9.4f  %9.4f  %+9.4f' % (row[0][0], row[1][0], row[1][0] - row[0][0]))
print('H/H2 crossing radius [pc]    %9.4f  %9.4f  %+9.4f' % (row[0][1], row[1][1], row[1][1] - row[0][1]))
O['cross_av'] = [row[0][0], row[1][0]]; O['cross_r'] = [row[0][1], row[1][1]]
O['thr'] = []
for v in (1e-4, 1e-3, 1e-2, 0.1, 0.5, 0.9):
    a, b = at(M[0], 'x2', v), at(M[1], 'x2', v)
    O['thr'].append([v, a, b])
    print('A_V where 2n(H2)/n_H = %-6g %9.4f  %9.4f  %+9.4f' % (v, a, b, b - a))
O['av'] = []
for av in (0.20, 0.23, 0.26, 0.30, 0.34, 0.38, 0.46, 0.50, 0.58, 0.65):
    j = [np.argmin(np.abs(d['AV'] - av)) for d in M]
    q = dict(av=av, **{k: [float(M[i][k][j[i]]) for i in (0, 1)] for k in ('H2', 'T', 'sink', 'phot', 'CO')})
    O['av'].append(q)
    print('A_V %.2f  n(H2) %9.3g %9.3g (x%.2f)  T %6.1f %6.1f  sink/H2 %9.2e %9.2e (x%.2f)  photodiss./H2 %9.2e %9.2e (x%.2f)  share %.2f %.2f  CO %8.2e %8.2e'
          % (av, q['H2'][0], q['H2'][1], q['H2'][1] / q['H2'][0], q['T'][0], q['T'][1], q['sink'][0], q['sink'][1], q['sink'][1] / q['sink'][0],
             q['phot'][0], q['phot'][1], q['phot'][1] / q['phot'][0], q['phot'][0] / q['sink'][0], q['phot'][1] / q['sink'][1], q['CO'][0], q['CO'][1]))
print('Hbeta [erg/s]                %9.4e  %9.4e  x%.4f' % (M[0]['Hbeta'], M[1]['Hbeta'], M[1]['Hbeta'] / M[0]['Hbeta']))
O['hbeta'] = [M[0]['Hbeta'], M[1]['Hbeta']]
O['lines'] = {}
for k in M[0]['lines']:
    O['lines'][k] = [M[0]['lines'][k], M[1]['lines'][k]]
    print('H2 %-10s / Hbeta       %9.3e  %9.3e  x%.3f' % (k, M[0]['lines'][k], M[1]['lines'][k], M[1]['lines'][k] / M[0]['lines'][k]))
O['zones'] = [len(d['AV']) for d in M]; O['avmax'] = [float(d['AV'][-1]) for d in M]
print('zones', O['zones'], 'A_V at the edge', O['avmax'])
if len(sys.argv) > 3:
    json.dump(O, open(sys.argv[3], 'w'), indent=1)
