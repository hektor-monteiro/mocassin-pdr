"""The extent rules, on a synthetic repository."""

import textwrap

import pytest

from fortref import resolve

MAKEFILE = """\
ifeq ($(PDR),1)
  FFLAGS += -DPDR
  PDRGEOM ?= 1D
  ifeq ($(PDRGEOM),3D)
    PDRGEOMFLAG = -DRAYTHEIA
  else
    PDRGEOMFLAG = -DONEDIMENSIONAL
  endif
  PDRFLAGS = -DREDUCED \\
             $(PDRGEOMFLAG)
endif
SOURCES = source/m.o
"""

SOURCE = """\
module m
contains
  subroutine s(n)
    integer :: n, i
    ! comment block, line 1
    ! comment block, line 2
    x = 1

    do i = 1, n
       y = i
    end do

    select case (n)
    case (1)
       a = 1
    ! the next case's comment
    case (2)
       a = 2
    case default
       a = 3
    end select

    if (n > 0) then
       b = 1
    else if (n < 0) then
       b = 2
    else
       b = 3
    end if
    c = 1
    d = 2

    e = 3
  end subroutine s
#ifdef PDR
  subroutine t()
    f = 1
  end subroutine t
#else
  subroutine t()
  end subroutine t
#endif
  subroutine long()
""" + ''.join(f'    z{i} = {i}\n' for i in range(70)) + """\
  end subroutine long
end module m
"""


@pytest.fixture(scope='module')
def repo(tmp_path_factory):
    root = tmp_path_factory.mktemp('repo')
    (root / 'Makefile').write_text(MAKEFILE)
    (root / 'source').mkdir()
    (root / 'source' / 'm.f90').write_text(SOURCE)
    (root / 'notes.md').write_text('# Notes\n\nfirst paragraph\nstill first\n\nsecond\n')
    return resolve.Repo(str(root))


def lines(repo, ref, **kw):
    res, w = repo.resolve(ref, **kw)
    assert res is not None, w
    return res.start, res.end


def test_profiles_from_the_synthetic_makefile(repo):
    assert sorted(repo.macros['3d']) == ['PDR', 'RAYTHEIA', 'REDUCED']
    assert sorted(repo.macros['1d']) == ['ONEDIMENSIONAL', 'PDR', 'REDUCED']
    assert repo.macros['plain'] == {}
    assert repo.compiled == {'source/m.f90'}


@pytest.mark.parametrize('anchor, want', [
    ('comment block, line 2', (5, 7)),       # the block, then the next statement
    ('do i = 1, n', (9, 11)),                # opener to closer
    ('case (1)', (14, 15)),                  # case to the next case, its comment left out
    ('case (2)', (17, 18)),
    ('case default', (19, 20)),
    ('if (n > 0) then', (23, 29)),
    ('else if (n < 0)', (25, 26)),
    ('else"#2', (27, 28)),                  # 'else' is also in 'else if' (L25)
    ('subroutine s(n)', (3, 34)),            # a header takes the unit
    ('c = 1', (30, 31)),                     # to the next blank line
    ('x = 1', (7, 7)),
    ('e = 3', (33, 34)),                     # clipped to the routine
    ('#ifdef PDR', (35, 42)),                # cpp conditionals are constructs
])
def test_extent_rules(repo, anchor, want):
    ref = 'm.f90@"' + anchor + ('' if anchor.endswith('#2') else '"')
    assert lines(repo, ref) == want


def test_explicit_extents(repo):
    assert lines(repo, 'm.f90::s@"x = 1"+3') == (7, 10)
    assert lines(repo, 'm.f90::s@"x = 1"..@"end do"') == (7, 11)
    assert lines(repo, 'm.f90::s@"a = "#2') == (18, 21)     # to the next blank line


def test_profiles_pick_the_branch(repo):
    assert lines(repo, 'm.f90::t') == (36, 38)
    assert lines(repo, 'm.f90::t [1d]') == (36, 38)          # 1d defines PDR too
    assert lines(repo, 'm.f90::t [plain]') == (40, 41)
    res, w = repo.resolve('m.f90@"f = 1" [plain]')
    assert res is None and w[0][0] == 'text' and 'inactive line(s) L37' in w[0][1]


def test_long_extent(repo):
    res, w = repo.resolve('m.f90@"subroutine long()"')
    assert (res.start, res.end) == (43, 114) and [x[0] for x in w] == ['long-extent']
    res, w = repo.resolve('m.f90@"subroutine long()"', max_lines=100)
    assert w == []
    res, w = repo.resolve('m.f90::long')          # a scope is not an auto extent
    assert w == []
    res, w = repo.resolve('m.f90@"subroutine long()"+80')
    assert (res.start, res.end) == (43, 114) and w == []   # clipped to the routine


def test_text_and_markdown(repo):
    assert lines(repo, 'notes.md@"first paragraph"') == (3, 4)
    res, w = repo.resolve('notes.md::x')
    assert res is None and w[0][0] == 'scope'
    res, w = repo.resolve('m.f90@"a = "')
    assert res is None and w[0][0] == 'text-ambiguous'
    res, w = repo.resolve('m.f90@"a = "#9')
    assert res is None and w[0][0] == 'text'


@pytest.mark.parametrize('raw, want', [
    ('a.f90', ('a.f90', None, None, None, None, None, '3d')),
    ('pdr/a.F90::m/s', ('pdr/a.F90', 'm/s', None, None, None, None, '3d')),
    ('a.f90::s@"x = \\"y\\""+3 [1d]', ('a.f90', 's', 'x = "y"', 3, None, None, '1d')),
    ('a.f90@"do"..@"end do"#2 [plain]', ('a.f90', None, 'do', None, 'end do', 2, 'plain')),
    ('a.f90@"back\\\\slash"', ('a.f90', None, 'back\\slash', None, None, None, '3d')),
])
def test_grammar(raw, want):
    r = resolve.parse_ref(raw)
    assert (r.path, r.scope, r.text, r.plus, r.endtext, r.k, r.profile) == want


@pytest.mark.parametrize('raw', [
    'a.f90::', 'a.f90@x', 'a.f90@"x', 'a.f90@""', 'a.f90 [2d]', 'a.f90@"x"#0', 'a.f90 junk',
])
def test_grammar_errors(raw):
    with pytest.raises(resolve.RefSyntaxError):
        resolve.parse_ref(raw)


def test_title_split():
    assert resolve.split_title('the case <a.f90@"x < y">') == ('the case', 'a.f90@"x < y"')
    assert resolve.split_title('a.f90@"x < y"') == (None, 'a.f90@"x < y"')


def test_scan_markdown_skips_code():
    page = textwrap.dedent('''
        Text {src}`a.f90::s` and ``{src}`not.f90` `` and `{src}`` no.

        ```md
        {src}`inside.f90`
        ```

        :::{fortran-block} b.f90::t
        :context: 2
        :allow-long:
        :::

        {lim}`L-3` {devlog}`D-1`
        ''')
    found = [(k, c, o) for k, c, _, o in resolve.scan_markdown(page)]
    assert found == [('src', 'a.f90::s', {}),
                     ('fortran-block', 'b.f90::t', {'context': '2', 'allow-long': ''}),
                     ('lim', 'L-3', {}), ('devlog', 'D-1', {})]
