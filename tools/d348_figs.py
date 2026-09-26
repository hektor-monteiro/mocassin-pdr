#!/usr/bin/env python3
"""D-348: Roellig et al. (2007) Fig. 4-style profiles of one run against another.

tools/d260_roellig.py draws a model against a reference slab or a Cloudy model.
For a code change the reference is the same model before the change, so this
bins the baseline run exactly as d260_roellig bins the model (median of all
active cells per log A_V bin, same edges) and hands those medians to its
draw() as the dashed curves. Solid = the new run, dashed = the baseline.

    ~/miniforge3/envs/astro/bin/python tools/d348_figs.py \\
        runs/d348-angular runs/d334-hiipdr/s1001 <out-dir> \\
        ["new label"] ["baseline label"]
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import d260_roellig as R


def binned(run, other, keys):
    """The baseline as median profiles on the new run's A_V bins."""
    af = run['A_front']
    x0, x1 = R.auto_xlim(run, other)
    edges = np.concatenate([np.geomspace(x0, af * 0.999, 9),
                            np.geomspace(af * 0.999, x1, 32)[1:]])
    ref = {}
    for k in keys:
        xc, med = R.median_profile(other['AV'], other[k], edges)
        ref.setdefault('AV', xc)
        # a species can drop bins the first key kept; re-grid onto 'AV'
        ref[k] = np.interp(ref['AV'], xc, med, left=np.nan, right=np.nan) \
            if len(xc) != len(ref['AV']) else med
    return ref


def main():
    new_dir, old_dir, outdir = sys.argv[1:4]
    new_lab = sys.argv[4] if len(sys.argv) > 4 else 'with diffuse FUV (D-348)'
    old_lab = sys.argv[5] if len(sys.argv) > 5 else 'before (s1001)'
    os.makedirs(outdir, exist_ok=True)
    R.style()
    a, b = R.read_run(new_dir), R.read_run(old_dir)
    keys = sorted({k for spec in (R.CHEM, R.IONS, R.TEMP) for k, _, _ in spec})
    ref = binned(a, b, keys)
    nh = np.nanmax(a['H'] + 2 * a['H2'] + a['H+'])
    top = max(1e3, 10 ** np.ceil(np.log10(3 * nh)))
    tmax = 1.2 * max(np.nanmax(a['Tgas']), np.nanmax(b['Tgas']))
    ttop = 3e4 if tmax <= 3e4 else 10 ** np.ceil(np.log10(tmax))
    kw = dict(ref_label=old_lab, prefix='d348')
    R.draw(a, ref, 'chemistry', R.CHEM, r'$n(i)$ [cm$^{-3}$]', (1e-16, top),
           outdir, new_lab, **kw)
    R.draw(a, ref, 'ions', R.IONS, r'$n(i)$ [cm$^{-3}$]', (1e-12, top),
           outdir, new_lab, **kw)
    R.draw(a, ref, 'temperatures', R.TEMP, r'$T$ [K]', (5, ttop), outdir,
           new_lab, **kw)
    print('wrote', ', '.join(f'd348_{n}.svg' for n in
                             ('chemistry', 'ions', 'temperatures')), 'to', outdir)


if __name__ == '__main__':
    main()
