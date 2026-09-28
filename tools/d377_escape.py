#!/usr/bin/env python3
"""D-377: the line escape probabilities a run's chemistry found, per zone.

pdrLineEm.out (v2, D-363) holds, per grid point in i,j,k order, every coolant
transition's emissivity and then its escape probability, packed by coolant
in the order of the pdrCoolants keyword and, within one, upper level outer
and lower inner (only A > 0). The coolant layout is read from the run log's
[D362] lines. For a few named transitions this prints the median beta in the
ionized gas (x(H+) > 0.5) and in the PDR by A_V band, and, given a second
run, the ratio.

    python tools/d377_escape.py runs/A [runs/B]
"""
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d365_noise as N

# (label, coolant file, index of the transition within that coolant)
LINES = [('CO 1-0', '12co.dat', 0), ('CO 3-2', '12co.dat', 2), ('[C II] 158', '12c+.dat', 0),
         ('[C I] 609', '12c.dat', 0), ('[O I] 63', '16o.dat', 0), ('[O I] 145', '16o.dat', 2)]


def layout(run):
    log = open(os.path.join(run, 'run.log')).read()
    cl = re.findall(r'\[D362\] coolant (\S+):\s+(\d+) radiative transitions', log)
    off, o = {}, 0
    for name, n in cl:
        if name in off:
            continue
        off[name] = o
        o += int(n)
    return off, o


def betas(run):
    off, ntr = layout(run)
    out = os.path.join(run, 'output')
    tok = open(os.path.join(out, 'pdrLineEm.out')).read().split('\n', 1)[1].split()
    v = np.array(tok, float).reshape(-1, 2 * ntr)
    d = N.read(out)
    t = open(os.path.join(out, 'grid0.out')).read().split()
    nx = int(t[1]); n = nx ** 3; offg = 7 + 3 * nx
    act = np.array(t[offg:offg + n * 3:3], float).astype(int) > 0
    b = v[act][:, ntr:]
    em = v[act][:, :ntr]
    return d, off, b, em


def summary(d, off, b, em):
    res = {}
    rb = N.band_radii(d)
    for lab, cf, k in LINES:
        if cf not in off:
            continue
        j = off[cf] + k
        row = {}
        s = d['x(H+)'] > 0.5
        row['ionized'] = np.median(b[s, j]) if s.sum() else np.nan
        for (lo, hi), (r0, r1) in zip(N.BANDS, rb):
            s = (d['r'] >= r0) & (d['r'] < r1) & (d['x(H+)'] < 0.3)
            row[f'{lo:.2f}-{hi:.2f}'] = np.median(b[s, j]) if s.sum() else np.nan
        row['_em'] = em[:, j].sum()
        res[lab] = row
    return res


def main(runs):
    S = [summary(*betas(r)) for r in runs]
    keys = [k for k in S[0][next(iter(S[0]))].keys() if k != '_em']
    print('median beta; zones: ' + ', '.join(keys) + '  (PDR bands: x(H+) < 0.3 by A_V)')
    for lab in S[0]:
        line = f'  {lab:11s}'
        for k in keys:
            line += f' {S[0][lab][k]:6.3f}'
        if len(S) > 1:
            line += '  ->'
            for k in keys:
                line += f' {S[1][lab][k]:6.3f}'
            line += f'   sum(emissivity) B/A {S[1][lab]["_em"] / S[0][lab]["_em"]:.3f}'
        print(line)


if __name__ == '__main__':
    main(sys.argv[1:])
