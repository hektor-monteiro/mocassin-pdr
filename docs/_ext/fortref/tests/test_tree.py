"""Every compiled file of the real tree parses under every profile, and its
unit counts match the snapshot.  Regenerate the snapshot after a source change
that adds or removes units with FORTREF_UPDATE_SNAPSHOT=1."""

import json
import os

import pytest
from conftest import HERE, REPO

from fortref import cpp, parser, resolve

SNAPSHOT = os.path.join(HERE, 'units_snapshot.json')

# The Makefile's macros per profile, frozen (PREFIX and VERSION are defined
# too; their values follow the environment and do not steer any branch).
MACROS = {
    '3d': ['CHEMRETRY', 'CHEMSTEADY', 'FORCECONVERGENCE', 'H2FORM_CT02', 'ILLINOIS',
           'NGACCEL', 'NGCYCLE', 'NGRELAX', 'PDR', 'PREFIX', 'RAYTHEIA', 'RAYTHEIA_MO',
           'REBRACKET', 'REDUCED', 'SOBOLEV', 'THERMALBALANCE', 'VERSION'],
    '1d': ['CHEMRETRY', 'CHEMSTEADY', 'FORCECONVERGENCE', 'H2FORM_CT02', 'ILLINOIS',
           'NGACCEL', 'NGCYCLE', 'NGRELAX', 'ONEDIMENSIONAL', 'PDR', 'PREFIX',
           'REBRACKET', 'REDUCED', 'SOBOLEV', 'THERMALBALANCE', 'VERSION'],
    'plain': ['PREFIX', 'VERSION'],
}

repo = resolve.Repo.at(REPO)


def test_makefile_macros_frozen():
    assert {p: sorted(m) for p, m in repo.macros.items()} == MACROS
    for profile in ('3d', '1d'):
        assert repo.macros[profile]['PDR'] == '1'


def test_compiled_set_is_read_from_the_makefile():
    compiled = repo.compiled
    assert 'source/pdr_mod.f90' in compiled            # SOURCES via PDR_BRIDGE
    assert 'source/h2_mod.f90' in compiled             # PDR_PRE
    assert 'source/pdr/calculate_abundances.c' in compiled
    assert 'source/pdr/odes_reduced.c' in compiled
    for absent in ('source/gaunt.f90', 'source/fluorescence_mod.f90',
                   'source/pdr/odes_full.c', 'source/pdr/m_IOAndVisu.F90'):
        assert absent not in compiled


def _counts():
    out = {}
    for profile in cpp.PROFILES:
        out[profile] = {path: len(repo.model(path, profile).units)
                        for path in sorted(repo.compiled)}
    return {'compiled': sorted(repo.compiled), 'units': out}


@pytest.mark.parametrize('profile', cpp.PROFILES)
def test_every_compiled_file_parses(profile):
    problems = []
    for path in sorted(repo.compiled):
        model = repo.model(path, profile)
        problems += [(path, e) for e in model.errors]
        for u in model.units:
            if u.end is None or u.end < u.start:
                problems.append((path, f'unit {u.qualname} has no end'))
    assert problems == []


def test_unit_counts_match_snapshot():
    counts = _counts()
    if os.environ.get('FORTREF_UPDATE_SNAPSHOT') == '1':
        with open(SNAPSHOT, 'w') as fh:
            json.dump(counts, fh, indent=1, sort_keys=True)
            fh.write('\n')
    with open(SNAPSHOT) as fh:
        assert counts == json.load(fh)


def test_unit_errors_helper_reports_only_units():
    model = parser.build_from_lines(
        'x.f90', ['subroutine a()', 'end subroutine b', 'do i = 1, 2'], 'sha', 'plain', {})
    errors = parser.unit_errors(model)
    assert [e[1].split()[-3:] for e in errors] == [['a', '(line', '1)'], ['is', 'never', 'closed']]
    assert any(e[2] == 'construct' for e in model.errors)
