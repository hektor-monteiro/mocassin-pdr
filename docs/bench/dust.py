#!/usr/bin/env python3
"""Stage A of the 1D dust benchmark page: the three dust shells against Fig. 1 of Ercolano et al. (2005).

    python docs/bench/dust.py [--run ID=DIR ...] [--ids ID ...] [--out DIR] [--check]

Reads docs/bench/dust.toml, the reference curves of Ercolano et al. (2005), Fig. 1
(docs/bench/ref/ercolano2005_fig1.csv, written by ercref.py: DUSTY 2.01 and MOCASSIN 2005 as
lambda F_lambda / int F_lambda dlambda), and each run through tools/mocread.py. The runs are
dust-p0tau{1,10,100}-{iso,hg}, at <runs root>/<run.ID.path> ($MOCASSIN_RUNS, default
meta.runs_root_default) unless --run names one; --ids reduces a subset. Each run's input/ must hold
<run.ID.inputs>/input.in and the fixture's other files, by sha256.

For each run, from SED.out's total column, dustGrid.out, input/input.in and run.log:

    s(lambda)  nu F_nu / int F_nu dnu, nu_Hz = nu_Ryd x 3.28984e15, the integral by the trapezoid rule
    L_SED      4 pi (3.0857e18)^2 1e-23 int F_nu dnu [erg/s], against LStar x 1e36 and SED.out's L_e36
    r_in       the smallest r of an active cell, which must be Rout/1000 within 1%
    T_in       the mean T[0,0] of the active cells at r_in [K]

and the run's version line, iterations ("finished at" lines), stop line, last converged-cell share and
run time. At each DUSTY 2.01 point of a tau, MOCASSIN 2005 and s are interpolated linearly in
(log lambda, log s) and compared as log10(curve / DUSTY); the statistics use the points where DUSTY is
at least 1e-3 of its peak: median |dex|, max |dex| and its lambda. MOCASSIN 2005 is interpolated within
each segment of the figure's curve (tau = 100 is drawn as three), so a DUSTY point in a gap between
segments has no MOCASSIN 2005 value and is left out of its statistics. Writes to DIR (default
docs/bench/data/dust1d):

    sed_<id>.csv          lambda [um], s, in increasing lambda
    compare_tau<t>.csv    at DUSTY's points: each curve and its dex, and whether the point is in the statistics
    temperature_<id>.csv  y = r/r_in and T[0,0] of every active cell
    summary.csv           per tau, MOCASSIN 2005, MOCASSIN 2005 renormalised (over its own integral of
                          y dln(lambda) in ercolano2005_fig1.json, a shape-only comparison) and each run:
                          iterations, stop, converged cells, L_SED/LStar, L_SED/L_e36, r_in/(Rout/1000),
                          T_in, peak lambda, median and max |dex|
    summary_page.csv      the same as the page shows it ({csv-table})
    PROVENANCE.json       sha256 of every file read, each run's version line, the md5 of meta.binary, the date

The CSVs are written with %.4g; the page table prints numbers with %.3g, L_SED/LStar and L_SED/L_e36
with %.4f, |dex| with %.3f, and – where there is no value. --check reduces again into a temporary
directory and compares every CSV with DIR's byte for byte.
"""
import argparse
import csv
import hashlib
import json
import os
import re
import shutil
import sys
import tempfile
import time
import tomllib

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(REPO, 'tools'))
import mocread  # noqa: E402

TOML = os.path.join(HERE, 'dust.toml')
REF = os.path.join(HERE, 'ref', 'ercolano2005_fig1.csv')
REF_JSON = os.path.join(HERE, 'ref', 'ercolano2005_fig1.json')
DEFAULT_OUT = os.path.join(HERE, 'data', 'dust1d')
IDS = [f'dust-p0tau{t}-{s}' for t in (1, 10, 100) for s in ('iso', 'hg')]
TAUS = [1, 10, 100]
DUSTY, MOC2005 = 'DUSTY 2.01', 'MOCASSIN 2005'
MOC2005_RENORM = 'MOCASSIN 2005, renormalised'
SCAT = {'isotropic': 'iso', 'henyey-greenstein': 'hg'}
NU_HZ = 3.28984e15                             # Hz per Ryd
PC = 3.0857e18                                 # cm
FLOOR = 1e-3                                   # statistics where DUSTY >= FLOOR x its peak
NA = '–'                                       # the page's placeholder for no value
READ = {}                                      # label -> sha256 of every file read
SUMMARY = ['tau', 'curve', 'id', 'iterations', 'stop', 'cells_pct', 'L_SED_over_Lstar', 'L_SED_over_L_e36',
           'r_in_over_Rout_1000', 'T_in', 'peak_lam_um', 'dusty_peak_lam_um', 'median_abs_dex', 'max_abs_dex',
           'max_abs_dex_lam_um']
PAGE = ['τ(1 µm)', 'Curve', 'Iterations', 'Stop', 'Converged cells [%]', 'L_SED / L★', 'L_SED / L_e36',
        'T_in [K]', 'Peak λ [µm]', 'Median |dex|', 'Max |dex|', 'at λ [µm]']


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def label(path):
    path = os.path.abspath(path)
    for root, tag in ((RUNS, 'runs:'), (REPO, 'repo:')):
        if path.startswith(root.rstrip('/') + '/'):
            return tag + os.path.relpath(path, root)
    return path


def src(path):
    """a file about to be read: its sha256 goes into PROVENANCE.json"""
    READ[label(path)] = sha256(path)
    return path


def g(v, fmt='%.4g'):
    if v is None:
        return ''
    if isinstance(v, (bool, np.bool_)):
        return str(bool(v))
    if isinstance(v, (int, np.integer)):
        return str(int(v))
    return fmt % v if np.isfinite(v) else ''


def field(x):
    """a text field, quoted when it holds a comma (\"MOCASSIN 2005, renormalised\")"""
    return '"' + x.replace('"', '""') + '"' if ',' in x or '"' in x else x


def write_csv(path, header, rows, fmt='%.4g'):
    with open(path, 'w', newline='') as f:
        f.write(','.join(header) + '\n')
        for r in rows:
            f.write(','.join(field(x) if isinstance(x, str) else g(x, fmt) for x in r) + '\n')


def page(v, fmt='%.3g'):
    return NA if v is None or not np.isfinite(v) else fmt % v


# ------------------------------------------------------------------------------------------- inputs
def keyword(text, name):
    """the first value of keyword name in an input.in"""
    m = re.search(rf'^\s*{name}\s+(\S+)', text, re.M)
    if not m:
        raise SystemExit(f'input.in has no {name}')
    return float(m.group(1))


def check_inputs(ident, spec, path):
    """the run's input/ must hold the docs input.in and the fixture's other files, by sha256"""
    want = {'input.in': os.path.join(REPO, spec['inputs'], 'input.in')}
    fix = os.path.join(REPO, spec['fixture'])
    for f in sorted(os.listdir(fix)):
        if f != 'input.in':
            want[f] = os.path.join(fix, f)
    for f, ref in want.items():
        have = os.path.join(path, 'input', f)
        if not os.path.exists(have):
            raise SystemExit(f'REFUSING {path}: no input/{f}')
        if sha256(src(have)) != sha256(src(ref)):
            raise SystemExit(f'REFUSING {path}: input/{f} differs from {label(ref)}')


# --------------------------------------------------------------------------------------------- runs
def read_log(path):
    """run.log: the version line, iterations, the stop line and its kind, the last converged-cell share,
    the run time"""
    log = os.path.join(path, 'run.log')
    lines = open(src(log), errors='replace').read().splitlines()
    stop = [ln.strip() for ln in lines if 'iterateMC: [talk] dust only: converged cells' in ln
            or 'iterateMC: [talk] NOT CONVERGED after' in ln]
    if len(stop) != 1:
        raise SystemExit(f'{log}: {len(stop)} stop lines, not 1')
    cells = [float(m.group(1)) for ln in lines
             for m in [re.search(r'Total:\s+(\S+)\s+% converged cells over all grids', ln)] if m]
    rt = [ln.split('processor', 1)[1].split()[0] for ln in lines if ln.startswith('total run time per processor')]
    # the first MOCASSIN version line: with many ranks the start-up output interleaves, so not line 1
    version = next((ln.strip() for ln in lines if 'MOCASSIN version' in ln), None)
    return {'version': version, 'iterations': sum('finished at' in ln for ln in lines),
            'stop_line': stop[0], 'stop': 'not converged' if 'NOT CONVERGED' in stop[0] else 'converged',
            'cells_pct': cells[-1] if cells else None, 'run_time': rt[-1] if rt else None}


class Run:
    def __init__(self, ident, spec, path):
        if os.path.exists(os.path.join(path, 'INCOMPLETE')):
            raise SystemExit(f'REFUSING {path}: marked INCOMPLETE')
        out = os.path.join(path, 'output')
        if not os.path.exists(os.path.join(out, 'SED.out')):
            raise SystemExit(f'REFUSING {path}: no output/SED.out')
        check_inputs(ident, spec, path)
        self.ident, self.path, self.spec = ident, path, spec
        self.log = read_log(path)
        for f in ('SED.out', 'grid0.out', 'grid3.out', 'dustGrid.out'):
            src(os.path.join(out, f))
        inp = open(os.path.join(path, 'input', 'input.in')).read()
        sed = mocread.read_sed(path)
        d = mocread.read_dust(path)
        nu = sed['nu_ryd'] * NU_HZ
        F = sed['total']
        integral = float(np.trapezoid(F, nu))
        self.lam, self.s = sed['lam_um'], nu * F / integral
        self.L = 4 * np.pi * PC ** 2 * 1e-23 * integral
        self.Lstar = keyword(inp, 'LStar') * 1e36
        self.L_e36 = sed['L_e36']
        rout = keyword(inp, 'Rout')
        r = d.r[d.mask]
        self.r_in = float(r.min())
        self.r_in_ratio = self.r_in / (rout / 1000)
        if abs(self.r_in_ratio - 1) > 0.01:
            raise SystemExit(f'{path}: r_in = {self.r_in:.6g} cm, not Rout/1000 = {rout / 1000:.6g} within 1%')
        t00 = d.T[0, 0][d.mask]
        self.T_in = float(t00[np.isclose(r, self.r_in, rtol=1e-6)].mean())
        self.y, self.T = r / self.r_in, t00


# ----------------------------------------------------------------------------------------- compare
def loglog(lam, y, at):
    """y interpolated linearly in (log lambda, log y) at the wavelengths at, from y's positive points;
    nan outside their range"""
    ok = y > 0
    o = np.argsort(lam[ok])
    x, v = np.log10(lam[ok][o]), np.log10(y[ok][o])
    return 10 ** np.interp(np.log10(at), x, v, left=np.nan, right=np.nan)


def peak(lam, y):
    return float(lam[np.nanargmax(y)])


def stats(dex, lam, use):
    """median |dex|, max |dex| and its lambda over the used points with a value"""
    s = use & np.isfinite(dex)
    if not s.any():
        return None, None, None
    a = np.abs(dex[s])
    return float(np.median(a)), float(a.max()), float(lam[s][np.argmax(a)])


def reduce_all(conf, runs, ids, out):
    global READ
    READ = {}
    os.makedirs(out, exist_ok=True)
    with open(src(REF)) as f:
        ref = list(csv.DictReader(f))
    curve = {}
    for r in ref:
        curve.setdefault((r['code'], int(r['tau'])), []).append((float(r['lam_um']), float(r['y']),
                                                                  int(r['segment'])))
    curve = {k: np.array(sorted(v)) for k, v in curve.items()}
    with open(src(REF_JSON)) as f:
        integral = {(c['code'], c['tau']): c['integral_y_dlnlam'] for c in json.load(f)['curves']}
    done = {i: Run(i, conf['run'][i], runs[i]) for i in ids}
    summary, page_rows, card = [], [], {}
    for i, run in done.items():
        write_csv(os.path.join(out, f'sed_{i}.csv'), ['lam_um', 's'], list(zip(run.lam[::-1], run.s[::-1])))
        o = np.lexsort((run.T, run.y))
        write_csv(os.path.join(out, f'temperature_{i}.csv'), ['y', 'T_K'], list(zip(run.y[o], run.T[o])))
        card[i] = {'run': label(run.path), 'version': run.log['version'], 'stop_line': run.log['stop_line'],
                   'run_time': run.log['run_time']}
    for tau in TAUS:
        here = [i for i in ids if conf['run'][i]['tau'] == tau]
        if not here:
            continue
        lam, dusty = curve[(DUSTY, tau)][:, 0], curve[(DUSTY, tau)][:, 1]
        use = dusty >= FLOOR * dusty.max()
        dpeak = peak(lam, dusty)
        # MOCASSIN 2005 per segment of the figure: nan in the gaps between them
        moc = curve[(MOC2005, tau)]
        cols = {MOC2005: np.full(len(lam), np.nan)}
        for seg in np.unique(moc[:, 2]):
            v = loglog(moc[moc[:, 2] == seg, 0], moc[moc[:, 2] == seg, 1], lam)
            cols[MOC2005] = np.where(np.isfinite(v), v, cols[MOC2005])
        for i in here:
            cols[i] = loglog(done[i].lam, done[i].s, lam)
        dex = {k: np.log10(v / dusty) for k, v in cols.items()}
        byscat = {SCAT[conf['run'][i]['scattering']]: i for i in here}
        names = [MOC2005] + [byscat[s] for s in ('iso', 'hg') if s in byscat]
        rows = [[a, b] + [cols[k][n] for k in names] + [dex[k][n] for k in names] + [bool(use[n])]
                for n, (a, b) in enumerate(zip(lam, dusty))]
        hdr = ['lam_um', 'dusty', 'moc2005'] + [f'pdr_{s}' for s in ('iso', 'hg') if s in byscat]
        write_csv(os.path.join(out, f'compare_tau{tau}.csv'),
                  hdr + ['dex_' + h for h in hdr[2:]] + ['in_stats'], rows)
        m, mx, mxl = stats(dex[MOC2005], lam, use)
        mp = peak(moc[:, 0], moc[:, 1])
        summary.append([tau, MOC2005, '', None, '', None, None, None, None, None, mp, dpeak, m, mx, mxl])
        page_rows.append([str(tau), MOC2005, NA, NA, NA, NA, NA, NA, page(mp), page(m, '%.3f'), page(mx, '%.3f'),
                          page(mxl)])
        # the published curve over its own integral of y dln(lambda) (ercolano2005_fig1.json): its shape alone
        m, mx, mxl = stats(np.log10(cols[MOC2005] / integral[(MOC2005, tau)] / dusty), lam, use)
        summary.append([tau, MOC2005_RENORM, '', None, '', None, None, None, None, None, mp, dpeak, m, mx, mxl])
        page_rows.append([str(tau), MOC2005_RENORM, NA, NA, NA, NA, NA, NA, page(mp), page(m, '%.3f'),
                          page(mx, '%.3f'), page(mxl)])
        for i in names[1:]:
            run = done[i]
            m, mx, mxl = stats(dex[i], lam, use)
            pk = peak(run.lam, run.s)
            le = run.L / (run.L_e36 * 1e36) if run.L_e36 else None
            summary.append([tau, f'MOCASSIN-PDR {SCAT[run.spec["scattering"]]}', i, run.log['iterations'],
                            run.log['stop'], run.log['cells_pct'], run.L / run.Lstar, le, run.r_in_ratio, run.T_in,
                            pk, dpeak, m, mx, mxl])
            page_rows.append([str(tau), f'MOCASSIN-PDR ({run.spec["scattering"]})', str(run.log['iterations']),
                              run.log['stop'], page(run.log['cells_pct']), page(run.L / run.Lstar, '%.4f'),
                              page(le, '%.4f'), page(run.T_in),
                              page(pk), page(m, '%.3f'), page(mx, '%.3f'), page(mxl)])
    write_csv(os.path.join(out, 'summary.csv'), SUMMARY, summary)
    write_csv(os.path.join(out, 'summary_page.csv'), PAGE, page_rows)
    with open(os.path.join(out, 'PROVENANCE.json'), 'w') as f:
        binary = conf['meta']['binary']
        md5 = hashlib.md5(open(binary, 'rb').read()).hexdigest() if os.path.exists(binary) else None
        json.dump({'generated': time.strftime('%Y-%m-%d'), 'runs_root': RUNS, 'runs': card,
                   'binary': {'path': label(binary), 'md5': md5, 'md5_expected': conf['meta']['binary_md5']},
                   'toml': {'path': label(TOML), 'sha256': sha256(TOML)},
                   'reference': {'path': label(REF), 'sha256': sha256(REF)},
                   'script': {'dust.py': sha256(os.path.abspath(__file__)),
                              'mocread.py': sha256(os.path.abspath(mocread.__file__))},
                   'files_read': dict(sorted(READ.items()))}, f, indent=1)
        f.write('\n')


def check(conf, runs, ids, out):
    tmp = tempfile.mkdtemp(prefix='dust-check-')
    ok = True
    try:
        reduce_all(conf, runs, ids, tmp)
        fa = sorted(f for f in os.listdir(out) if f.endswith('.csv')) if os.path.isdir(out) else []
        fb = sorted(f for f in os.listdir(tmp) if f.endswith('.csv'))
        if fa != fb:
            ok = False
            print(f'files differ: {out} has {fa}, the reduction {fb}')
        for f in sorted(set(fa) & set(fb)):
            same = open(os.path.join(out, f), 'rb').read() == open(os.path.join(tmp, f), 'rb').read()
            ok &= same
            print(f'{f}: ' + ('identical' if same else 'DIFFERENT'))
    finally:
        shutil.rmtree(tmp)
    return ok


def main():
    global RUNS
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--run', action='append', default=[], metavar='ID=DIR', help='the run of id ID')
    ap.add_argument('--ids', nargs='+', default=IDS, metavar='ID', help='reduce these ids only')
    ap.add_argument('--out', default=DEFAULT_OUT)
    ap.add_argument('--check', action='store_true')
    args = ap.parse_args()
    with open(TOML, 'rb') as f:
        conf = tomllib.load(f)
    RUNS = os.path.abspath(os.environ.get(conf['meta']['runs_root_env'], conf['meta']['runs_root_default']))
    runs = {i: os.path.join(RUNS, conf['run'][i]['path']) for i in IDS}
    for a in args.run:
        i, d = a.split('=', 1)
        if i not in runs:
            raise SystemExit(f'--run {a}: no id {i} (one of {", ".join(IDS)})')
        runs[i] = os.path.abspath(d)
    for i in args.ids:
        if i not in runs:
            raise SystemExit(f'--ids {i}: not one of {", ".join(IDS)}')
    ids = [i for i in IDS if i in args.ids]
    out = os.path.abspath(args.out)
    if args.check:
        sys.exit(0 if check(conf, runs, ids, out) else 1)
    reduce_all(conf, runs, ids, out)
    print('written', out)


RUNS = ''
if __name__ == '__main__':
    main()
