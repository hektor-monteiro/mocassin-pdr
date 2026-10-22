"""Golden references against the real tree, frozen at the lines they resolve
to now.  A source change that moves them fails here first, on purpose: check
the new lines against the code and update the table."""

import pytest
from conftest import REPO

from fortref import resolve

repo = resolve.Repo.at(REPO)

# ref -> (path, start, end, unit qualname) or ('FAIL', subtype)
GOLDEN = {
    # the three escape_probability headers: one per profile, one shared END
    'pdr/escape_probability.F90::escape_probability':
        ('source/pdr/escape_probability.F90', 3, 268, 'escape_probability'),
    'pdr/escape_probability.F90::escape_probability [1d]':
        ('source/pdr/escape_probability.F90', 14, 268, 'escape_probability'),
    'pdr/escape_probability.F90::escape_probability [plain]':
        ('source/pdr/escape_probability.F90', 14, 268, 'escape_probability'),
    # the H2 level model under RAYTHEIA, its stub in the 1D build, none without PDR
    'pdr_mod.f90::h2LevelModel': ('source/pdr_mod.f90', 5201, 6014, 'pdr_mod/h2LevelModel'),
    'pdr_mod.f90::h2LevelModel [1d]': ('source/pdr_mod.f90', 6018, 6027, 'pdr_mod/h2LevelModel'),
    'pdr_mod.f90::h2LevelModel [plain]': ('FAIL', 'scope'),
    'pdr_mod.f90::h2LevelModel/h2PopResume':
        ('source/pdr_mod.f90', 5961, 6012, 'pdr_mod/h2LevelModel/h2PopResume'),
    # an interface body declares, it does not define
    'pdr/modules.F90::H2PDRATE': ('FAIL', 'scope'),
    'pdr/shield.F90::H2PDRATE': ('source/pdr/shield.F90', 27, 55, 'H2PDRATE'),
    'pdr/shield.F90::H2SHIELD1': ('source/pdr/shield.F90', 231, 281, 'H2SHIELD1'),   # bare END
    'update_mod.f90::updateCell': ('source/update_mod.f90', 52, 4741, 'update_mod/updateCell'),
    'update_mod.f90::updateCell/thermBalance':
        ('source/update_mod.f90', 1792, 2514, 'update_mod/updateCell/thermBalance'),
    'update_mod.f90::thermbalance':
        ('source/update_mod.f90', 1792, 2514, 'update_mod/updateCell/thermBalance'),
    'iteration_mod.f90::iterateMC':
        ('source/iteration_mod.f90', 56, 3345, 'iteration_mod/MCIterationDriver/iterateMC'),
    # forLines in three modules: the path decides, the scope suffix must fit
    'emission_mod.f90::forLines':
        ('source/emission_mod.f90', 586, 637, 'emission_mod/emissionDriver/forLines'),
    'output_mod.f90::forLines': ('source/output_mod.f90', 2382, 2454, 'output_mod/outputGas/forLines'),
    'update_mod.f90::forLines': ('source/update_mod.f90', 2519, 2583, 'update_mod/updateCell/forLines'),
    'update_mod.f90::updateCell/forLines':
        ('source/update_mod.f90', 2519, 2583, 'update_mod/updateCell/forLines'),
    'emission_mod.f90::updateCell/forLines': ('FAIL', 'scope'),
    'h2_mod.f90::h2Solve': ('source/h2_mod.f90', 1516, 1533, 'h2_mod/h2Solve'),
    'vector_mod.f90::mult': ('source/vector_mod.f90', 139, 147, 'vector_mod/mult'),   # typed function
    # text anchors and their extents
    'set_input_mod.f90::readInput@"case (\\"convTotals\\")"':
        ('source/set_input_mod.f90', 468, 470, 'set_input_mod/readInput'),
    'set_input_mod.f90::readInput@"case (\\"convLimit\\")"':
        ('source/set_input_mod.f90', 462, 464, 'set_input_mod/readInput'),
    'set_input_mod.f90::readInput@"case (\\"convLimit\\")"..@"XHILimit"':
        ('source/set_input_mod.f90', 462, 464, 'set_input_mod/readInput'),
    'set_input_mod.f90::readInput@"case (\\"convTotals\\")"+1':
        ('source/set_input_mod.f90', 468, 469, 'set_input_mod/readInput'),
    'iteration_mod.f90::iterateMC@"call h2LevelModel(grid(1:nGrids), 1)"':
        ('source/iteration_mod.f90', 1043, 1045, 'iteration_mod/MCIterationDriver/iterateMC'),
    'update_mod.f90::thermBalance@"do i = 1, 12"#1':
        ('source/update_mod.f90', 1878, 1880, 'update_mod/updateCell/thermBalance'),
    'pdr_mod.f90::h2LevelModel@"subroutine h2PopResume"#1':
        ('source/pdr_mod.f90', 5961, 6012, 'pdr_mod/h2LevelModel/h2PopResume'),
    'pdr_mod.f90::h2LevelModel@"subroutine h2PopResume"': ('FAIL', 'text-ambiguous'),
    'grid_mod.f90::writeGrid@"pdrGrid.out"': ('FAIL', 'text-ambiguous'),
    'iteration_mod.f90::iterateMC@"call h2LevelModel(grid, 1)"': ('FAIL', 'text'),
    'iteration_mod.f90::iterateMC@"call h2LevelModel(grid(1:nGrids), 1)" [plain]': ('FAIL', 'text'),
    # C
    'pdr/calculate_abundances.c::calculate_abundances_':
        ('source/pdr/calculate_abundances.c', 68, 508, 'calculate_abundances_'),
    'pdr/calculate_abundances.c::check_flag': ('source/pdr/calculate_abundances.c', 600, 633, 'check_flag'),
    # other files
    'Makefile@"PDRFLAGS ="': ('Makefile', 87, 89, None),
    'doc/pdr-status.md@"**L-37."': ('doc/pdr-status.md', 337, 375, None),
    'nonexistent.f90': ('FAIL', 'file'),
    'update_mod.f90::nosuch': ('FAIL', 'scope'),
}


@pytest.mark.parametrize('raw', list(GOLDEN))
def test_golden(raw):
    want = GOLDEN[raw]
    res, warnings = repo.resolve(raw)
    subtypes = [w[0] for w in warnings]
    if want[0] == 'FAIL':
        assert res is None
        assert want[1] in subtypes, warnings
        return
    assert res is not None, warnings
    assert subtypes == [], warnings
    unit = res.unit.qualname if res.unit else None
    assert (res.path, res.start, res.end, unit) == want


def test_escape_probability_profiles_share_the_end():
    a, _ = repo.resolve('pdr/escape_probability.F90::escape_probability [3d]')
    b, _ = repo.resolve('pdr/escape_probability.F90::escape_probability [1d]')
    assert a.start != b.start and a.end == b.end
    assert 'length)' in a.model.lines[a.start + 2] and 'molmass)' in b.model.lines[b.start + 2]


def test_h2levelmodel_is_the_raytheia_version_under_3d():
    a, _ = repo.resolve('pdr_mod.f90::h2LevelModel')
    b, _ = repo.resolve('pdr_mod.f90::h2LevelModel [1d]')
    assert a.model.lines[a.start - 2].strip() == '#ifdef RAYTHEIA'
    assert 'end subroutine h2LevelModel' in a.model.lines[a.end - 1]
    assert a.model.lines[a.end].strip() == '#else'
    assert b.end - b.start + 1 == 10 and b.model.lines[b.end].strip() == '#endif'


def test_interface_declaration_is_named_in_the_warning():
    _, warnings = repo.resolve('pdr/modules.F90::H2PDRATE')
    assert 'interface block at L433' in warnings[0][1]


def test_scope_suggestion_and_other_profile():
    _, w = repo.resolve('update_mod.f90::updatecel')
    assert 'did you mean update_mod/updateCell' in w[0][1]
    _, w = repo.resolve('pdr_mod.f90::h2LevelModel [plain]')
    assert 'defined under profile 3d, 1d' in w[0][1]


def test_text_suggestion():
    _, w = repo.resolve('iteration_mod.f90::iterateMC@"call h2LevelModel(grid, 1)"')
    assert 'closest: L1043' in w[0][1]


def test_not_compiled_flag():
    res, _ = repo.resolve('gaunt.f90')
    assert res is not None and res.start is None and not res.compiled
    res, _ = repo.resolve('update_mod.f90')
    assert res.compiled


def test_long_extent_warns_but_resolves():
    res, w = repo.resolve('set_input_mod.f90::readInput@"select case (keyword)"')
    assert (res.start, res.end) == (152, 765)
    assert [x[0] for x in w] == ['long-extent']
    res, w = repo.resolve('set_input_mod.f90::readInput@"select case (keyword)"', allow_long=True)
    assert w == []
