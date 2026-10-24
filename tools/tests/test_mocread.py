"""tools/mocread.py against the runs it was written for: the release run rel-hii31 (3D PDR build), read
identically to docs/bench/reduce.py's read_run, and the Lexington HII40 run of D-376 (plain build).
The runs root is $MOCASSIN_RUNS (default the production checkout's runs/); a test whose run directory
is missing is skipped. multiChemistry is tested on the test_Problem run h036b-tp-orig of the h2
worktree and on small synthetic run directories. read_dust and read_sed are tested on the dev branch's
dust benchmark runs (1D p0tau10, 2D tau 1, with viewpoints) and on a synthetic multiDustChemistry run."""

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
TP = '/home/hmonteiro/software/mocassin_h2/runs/h036b-tp-orig'
DEVBENCH = '/home/hmonteiro/software/dev_bench/bench'
DUST1D = os.path.join(DEVBENCH, 'dust_1D_p0tau10_final')
DUST2D = os.path.join(DEVBENCH, 'dust_2D_tau1.000_final')


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


def test_multichemistry_test_problem():
    need(TP)
    g = mocread.read_grid(TP)
    assert g.elements == ['H', 'He', 'C', 'N', 'O', 'Ne', 'Mg', 'Si', 'S']
    k, c = np.unique(g.abindex, return_counts=True)
    assert dict(zip(k.tolist(), c.tolist())) == {1: 441, 2: 8820}
    act = g.active > 0
    o = sum(g.frac('O', q) for q in range(7))              # grid2.out holds O's charges 0 to 6
    assert np.abs(o[act] - 1).max() < 1e-5
    ab = mocread.composition(TP)
    assert isinstance(ab, dict) and ab['C'] == 3e-4


def abundance_file(path, c):
    vals = [1., 0.1, 0., 0., 0., c] + [0.] * 24             # H, He and C of the 30 elements
    path.write_text(''.join(f'{v!r}  ! {el}\n' for v, el in zip(vals, mocread.ELEMENTS)))


def test_multichemistry_components_differ(tmp_path):
    (tmp_path / 'input').mkdir()
    (tmp_path / 'output').mkdir()
    (tmp_path / 'input' / 'input.in').write_text(
        'multiChemistry 2 "input/abunA.in" \'input/abunB.in\'\n')
    abundance_file(tmp_path / 'input' / 'abunA.in', 3e-4)
    abundance_file(tmp_path / 'input' / 'abunB.in', 1e-4)
    # a 2 x 2 x 1 grid, all four points active; abFileIndex 1, 2, 2, 1
    (tmp_path / 'output' / 'grid0.out').write_text(
        '1\n2 2 1 4 0 1.0E+17\n0. 1.0E+17\n0. 1.0E+17\n0.\n'
        + ''.join(f'{p} 1 0\n' for p in range(1, 5)))
    idx = [1, 2, 2, 1]
    (tmp_path / 'output' / 'grid1.out').write_text(''.join(f'1.0E+4 1.0E+3 1.0E+3 {i}\n' for i in idx))
    (tmp_path / 'output' / 'grid2.out').write_text(
        '0. 1.\n0. 1. 0.\n0. 1. 0. 0. 0. 0. 0.\n' * 4)
    with pytest.raises(ValueError):
        mocread.composition(str(tmp_path))
    comps = mocread.compositions(str(tmp_path))
    assert len(comps) == 2 and [d['C'] for d in comps] == [3e-4, 1e-4]
    g = mocread.read_grid(str(tmp_path))
    assert np.array_equal(g.abindex.ravel(), idx)
    assert np.array_equal(g.abundance('C').ravel(), [3e-4, 1e-4, 1e-4, 3e-4])


def test_both_compositions_refused(tmp_path):
    (tmp_path / 'input').mkdir()
    (tmp_path / 'input' / 'input.in').write_text(
        'nebComposition "input/abun.in"\nmultiChemistry 1 "input/abun.in"\n')
    abundance_file(tmp_path / 'input' / 'abun.in', 3e-4)
    with pytest.raises(ValueError):
        mocread.compositions(str(tmp_path))
    with pytest.raises(ValueError):
        mocread.composition(str(tmp_path))


def test_read_dust_1d():
    need(DUST1D)
    d = mocread.read_dust(DUST1D)
    assert d.T.shape[2:] == (17, 17, 17) and d.ndust.shape == (17, 17, 17)
    assert int(d.mask.sum()) == 2665
    first = np.flatnonzero(d.ndust.ravel() > 0)[0]
    assert d.T[0, 0].ravel()[first] == pytest.approx(807.44, abs=0.005)
    assert d.mass_msol == pytest.approx(0.150011882)
    assert np.all(d.abindex == 1)


def test_read_sed_1d_old_trailer():
    need(DUST1D)
    s = mocread.read_sed(DUST1D)
    row = open(os.path.join(DUST1D, 'output', 'SED.out')).read().splitlines()[3]
    assert len(row.split()) == 4
    n = len(s['total'])
    assert s['views'].shape == (n, 0) and s['star_views'].shape == (n, 0)
    assert np.all(s['star'] == 0)
    assert s['viewpoints'] == []
    assert s['L_e36'] is None


def test_read_sed_2d_views():
    need(DUST2D)
    s = mocread.read_sed(DUST2D)
    n = len(s['total'])
    assert s['views'].shape == (n, 2) and s['star_views'].shape == (n, 2)
    assert len(s['viewpoints']) == 2


def dust_run(tmp_path):
    """a 2 x 1 x 1 grid, both points active, 2 species and 2 sizes, multiDustChemistry"""
    (tmp_path / 'output').mkdir()
    (tmp_path / 'output' / 'grid0.out').write_text(
        '1\n2 1 1 2 0 1.0E+17\n0. 1.0E+17\n0.\n0.\n1 1 0\n2 0 0\n')
    (tmp_path / 'output' / 'grid3.out').write_text(
        ' T           2  lgMultiDustChemistry, nDustComponents\n'
        '           2           3           2  nSpeciesMax, nSpecies, nSizes\n')
    body = ''
    for p, (nd, ia) in enumerate(((1.0e-7, 2), (2.0e-7, 1))):
        body += f'{nd!r} {ia}\n'
        for a in range(3):
            body += ' '.join(f'{100. * (p + 1) + 10. * a + s}' for s in range(3)) + '\n'
    body += '  \n Total dust mass [1.e45 g]:  1.0E-13\n Total dust mass [Msol]:   5.0E-02\n'
    (tmp_path / 'output' / 'dustGrid.out').write_text(body)
    return body


def test_read_dust_synthetic(tmp_path):
    body = dust_run(tmp_path)
    d = mocread.read_dust(str(tmp_path))
    assert d.T.shape == (3, 3, 2, 1, 1)
    assert d.T[0, 0, 0, 0, 0] == 100. and d.T[2, 1, 0, 0, 0] == 112. and d.T[1, 2, 1, 0, 0] == 221.
    assert np.array_equal(d.ndust.ravel(), [1.0e-7, 2.0e-7])
    assert np.array_equal(d.abindex.ravel(), [2, 1])
    assert np.array_equal(d.mask.ravel(), [True, True]) and np.array_equal(d.converged.ravel(), [True, False])
    assert d.mass_msol == 5.0e-2
    lines = body.split('\n')
    (tmp_path / 'output' / 'dustGrid.out').write_text('\n'.join(lines[:3] + lines[4:]))
    with pytest.raises(ValueError, match='lines, not'):
        mocread.read_dust(str(tmp_path))
