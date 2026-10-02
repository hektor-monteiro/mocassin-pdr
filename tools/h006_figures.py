#!/usr/bin/env python3
"""H-006: the factor line overlap puts on the H2g Solomon rate against N(H2):
the exact integral on a fine frequency grid, the model's quadrature, and the
overlap factor of Draine & Bertoldi's (1996) fit.

    python tools/h006_figures.py <compare.npz of h005_compare.py> <exact.npz> <out-dir>
"""
import os
import subprocess
import sys

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import h006_exact as ex                  # noqa: E402
from h004_figures import style           # noqa: E402

BLUE, WARM = '#1f4e79', '#b3541e'


def main(cmp_npz, exact_npz, outdir):
    c = np.load(cmp_npz); d = np.load(exact_npz)
    lev = [tuple(x) for x in c['lev']]
    lidx = {l: i for i, l in enumerate(lev)}
    L = ex.line_list()
    lo = np.array([lidx[(int(r[3]), int(r[4]))] for r in L])
    b = np.sqrt(2*ex.KB*100./(ex.MH2*ex.AMU))
    N = c['NH2in']; pops = c['popV']
    wd = os.path.dirname(os.path.abspath(exact_npz))
    xs, fe, fm = [], [], []
    for m in d['marks']:
        key = '%.0e' % m
        sel = d[key + '__sel']; S_ov = d[key + '__S_ov']; S_own = d[key + '__S_own']; Ncol = d[key + '__N']
        with open(os.path.join(wd, 'cols.txt'), 'w') as f:
            for (v, j), n in zip(lev, Ncol):
                f.write(f'{v} {j} {n:.8e}\n')
        out = subprocess.run([os.path.join(ex.HERE, 'h2Test'), os.path.join(ex.HERE, 'dataPDR', 'h2'), 'overlap',
                              os.path.join(wd, 'cols.txt'), f'{b:.6e}'], capture_output=True, text=True).stdout
        a = np.array([[float(x) for x in l.split()] for l in out.split('\n') if l.strip()])
        k = int(np.searchsorted(N, m)); pz = pops[min(k, len(pops) - 1)]
        w = pz[lo[sel]]*L[sel, 6]*L[sel, 7]/L[sel, 8]*L[sel, 10]/L[sel, 9]
        xs.append(Ncol.sum()); fe.append((w*S_ov).sum()/(w*S_own).sum()); fm.append((w*a[sel, 4]).sum()/(w*a[sel, 3]).sum())
    style()
    os.makedirs(outdir, exist_ok=True)
    fig, ax = plt.subplots(figsize=(5.2, 4.0))
    xx = np.logspace(16, 21.5, 200)
    ax.semilogx(xx, np.exp(-8.5e-4*np.sqrt(1 + xx/5e14)), ls=':', color='k', lw=1.4, label='Draine & Bertoldi 1996')
    ax.semilogx(xs, fe, 'o', ms=7, mfc='none', mec=WARM, mew=1.3, label='exact, fine frequency grid')
    ax.semilogx(xs, fm, '.', ms=7, color=BLUE, label='this work')
    ax.set_xlim(1e16, 3e21); ax.set_ylim(0., 1.05)
    ax.set_xlabel(r'$N({\rm H_2})$  [cm$^{-2}$]')
    ax.set_ylabel('Solomon rate with line overlap / without')
    ax.minorticks_on()
    ax.legend(loc='lower left', handletextpad=0.4)
    for ext in ('svg', 'png'):
        fig.savefig(os.path.join(outdir, f'h006_overlap.{ext}'), dpi=200)
    plt.close(fig)
    print('N', ' '.join(f'{x:.2e}' for x in xs)); print('exact', ' '.join(f'{x:.3f}' for x in fe)); print('model', ' '.join(f'{x:.3f}' for x in fm))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3])
