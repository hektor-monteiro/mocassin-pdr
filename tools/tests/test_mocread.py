"""tools/mocread.py against the runs it was written for: the release run rel-hii31 (3D PDR build), read
identically to docs/bench/reduce.py's read_run, and the Lexington HII40 run of D-376 (plain build).
The runs root is $MOCASSIN_RUNS (default the production checkout's runs/); a test whose run directory
is missing is skipped."""

import importlib.util
import os
import re
import sys

import numpy as np
import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
REPO = os.path.dirname(TOOLS)
if TOOLS not in sys.path:
    sys.path.insert(0, TOOLS)

import mocread  # noqa: E402

RUNS = os.environ.get('MOCASSIN_RUNS', '/home/hmonteiro/software/mocassin_HM_2026_3DPDR/runs')
REL = os.path.join(RUNS, '_release_v2', 'rel-hii31')
LEX = os.path.join(RUNS, 'd376-lex', 'HII40', 'new')


def need(run):
    if not os.path.isdir(run):
        pytest.skip(f'run directory {run} is missing')


def reduce_module():
    spec = importlib.util.spec_from_file_location('bench_reduce', os.path.join(REPO, 'docs', 'bench', 'reduce.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_rel_hii31_as_reduce():
    need(REL)
    d = reduce_module().read_run(REL)
    g = mocread.read_grid(REL)
    p = mocread.read_pdr(REL, g)
    act = g.active.ravel() > 0
    for ours, theirs in ((g.Te, 'Te'), (g.ne, 'e-'), (g.nH, 'nh'), (g.frac('H', 1), 'x_H+'),
                         (g.frac('O', 2), 'x_O2+'), (p.AV, 'AV')):
        assert np.array_equal(ours.ravel()[act], d[theirs]), theirs
    assert np.array_equal(g.black.ravel()[act], d['flag'])


def test_rel_hii31_mean_te():
    need(REL)
    t = re.findall(r'T\(H\+\)\s+(\S+)', open(os.path.join(REL, 'output', 'summary.out')).read())
    assert mocread.mean_te(REL)[('H', 1)] == float(t[-1])


def test_rel_hii31_ion_fractions():
    need(REL)
    f = mocread.ion_fractions(REL)
    for el in ('H', 'He'):
        assert abs(sum(v for (e, _), v in f.items() if e == el) - 1) < 1e-5, el


def test_hii40_plain_build():
    need(LEX)
    mocread.read_grid(LEX)
    with pytest.raises(FileNotFoundError):
        mocread.read_pdr(LEX, mocread.read_grid(LEX))
    txt = open(os.path.join(LEX, 'output', 'lineFlux.out')).read()
    ln = mocread.read_lines(LEX)
    assert ln.hbeta == 1e36 * float(re.search(r'Hbeta \[E36 erg/s\]:\s+(\S+)', txt).group(1))
    n = 0
    for line in txt.split('Heavy ions forbidden lines', 1)[1].split('Component:', 1)[0].splitlines():
        q = line.split()
        if len(q) != 7:
            continue
        try:
            [float(v) for v in q]
        except ValueError:
            continue
        n += 1
    assert len(ln.heavy) == n


def test_multigrid_refused(tmp_path):
    (tmp_path / 'output').mkdir()
    (tmp_path / 'output' / 'grid0.out').write_text('           2\n          13          13          13\n')
    with pytest.raises(ValueError):
        mocread.read_grid(str(tmp_path))


def test_multichemistry_refused(tmp_path):
    (tmp_path / 'input').mkdir()
    (tmp_path / 'input' / 'input.in').write_text('nebComposition "input/abun.in"\nmultiChemistry 1 "x" 1\n')
    with pytest.raises(ValueError):
        mocread.composition(str(tmp_path))
