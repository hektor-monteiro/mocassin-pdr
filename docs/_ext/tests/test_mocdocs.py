"""The checks of the mocdocs pages, on a small synthetic repository: a case
label of readInput missing from keywords.yaml, and an open of an output file
missing from outputs.yaml, are each a warning of type mocdocs."""

import io
import os
import re
import sys

import pytest

EXT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if EXT not in sys.path:
    sys.path.insert(0, EXT)

import mocdocs  # noqa: E402
from fortref import resolve  # noqa: E402

MAKEFILE = """\
ifeq ($(PDR),1)
  FFLAGS += -DPDR
endif
SOURCES = source/set_input_mod.o source/writer.o
prog: $(SOURCES) source/prog.o
"""

SET_INPUT = """\
module set_input_mod
    implicit none
    contains
    subroutine readInput()
        character(len=50) :: keyword
        integer :: i, ios
        do i = 1, 10
            read(unit=10, fmt=*, iostat=ios) keyword
            select case (keyword)
            case ("alpha")           ! a comment
               read(unit=10, fmt=*, iostat=ios) keyword
            case("beta")
               select case (i)
               case (1); ios = 0
               end select
            case default
               print*, "unrecognised"
#ifdef PDR
            case ("gamma", &
                 & "oldOne")
               call retiredKeyword(keyword, .false.)
            case ("delta")
               ios = 1
#endif
            end select
        end do
        contains
          subroutine retiredKeyword(kw, lgFatal)
            character(len=*), intent(in) :: kw
            logical, intent(in)          :: lgFatal
            character(len=200)           :: why
            select case (trim(kw))
            case ("gamma")
               why = "D-1: gamma is "// &
                    & "gone"
            case default
               why = "D-2"
            end select
          end subroutine retiredKeyword
    end subroutine readInput
end module set_input_mod
"""

WRITER = """\
subroutine writer()
    open(unit=1, file='output/a.out', status='replace')
    open(unit=2, action="write", &
         & file="output/b.out")
!   open(unit=3, file='output/c.out')
    open(unit=4, file='output/c.out') ! no: this one is live
end subroutine writer
"""

KEYWORDS = """\
- name: alpha
  group: geometry
  syntax: "alpha"
  default: "off"
  build: all
  status: active
  description: |
    Alpha.
- name: delta
  group: pdr
  syntax: "delta <x>"
  default: "0"
  build: all
  status: active
  description: |
    Delta.
- name: epsilon
  group: pdr
  syntax: "epsilon"
  default: "0"
  build: pdr
  status: active
  description: |
    Epsilon.
"""

OUTPUTS = """\
- name: a.out
  group: results
  writer: 'writer.f90@"file=''output/a.out''"'
  when: "always"
  build: all
  description: |
    A.
- name: c.out
  group: results
  writer: 'writer.f90@"file=''output/c.out''"'
  when: "always"
  build: all
  description: |
    C.
- name: z.out
  group: results
  writer: 'writer.f90@"file=''output/a.out''"'
  when: "never"
  build: all
  description: |
    Z.
"""

DEVLOG = """\
# DEVLOG

## Index of decisions

| ID | Decision | Status | Entry |
|----|----------|--------|-------|
| D-263 | **v1.0.** | Done | 2026-01-01 |
"""


@pytest.fixture
def repo(tmp_path):
    root = tmp_path / 'repo'
    for rel, text in {
        'Makefile': MAKEFILE, 'source/set_input_mod.f90': SET_INPUT,
        'source/writer.f90': WRITER, 'source/prog.f90': 'program prog\nend program prog\n',
        'docs/reference/keywords.yaml': KEYWORDS, 'docs/reference/outputs.yaml': OUTPUTS,
        'DEVLOG.md': DEVLOG,
    }.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
    return root


def test_keyword_check(repo):
    r = resolve.Repo.at(str(repo))
    labels, reasons, problems = mocdocs.readinput_labels(r)
    assert problems == []
    assert sorted(labels) == ['alpha', 'beta', 'delta', 'gamma', 'oldOne']
    assert labels['alpha'].code == 'case ("alpha")' and not labels['alpha'].pdr
    assert labels['oldOne'].pdr and labels['oldOne'].retired == 'ignored'
    assert reasons == {'gamma': 'D-1: gamma is gone', 'oldOne': 'D-2'}
    text, problems = mocdocs.keywords_page(r)
    messages = [m for s, m in problems if s == 'keywords']
    assert len(problems) == len(messages) == 3
    assert any('"beta"' in m and 'no entry' in m for m in messages)        # missing from YAML
    assert any('epsilon is not a case label' in m for m in messages)       # not in readInput
    assert any('delta has build: all' in m and 'inside' in m for m in messages)
    assert '{src}`case ("alpha") <set_input_mod.f90::readInput@"case (\\"alpha\\")">`' in text
    assert '| `gamma` | ignored | D-1: gamma is gone |' in text


def test_output_check(repo):
    r = resolve.Repo.at(str(repo))
    opens = mocdocs.output_opens(r)
    assert sorted(opens) == ['a.out', 'b.out', 'c.out']
    assert opens['b.out'] == [('source/writer.f90', 3)]
    text, problems = mocdocs.outputs_page(r)
    assert [s for s, _ in problems] == ['outputs', 'outputs']
    assert any('z.out is opened by no' in m for _, m in problems)
    assert any('output/b.out is opened at source/writer.f90:3' in m for _, m in problems)
    assert '(out-a_out)=' in text


def test_compiled_set_counts_program_units(repo):
    assert 'source/prog.f90' in resolve.Repo.at(str(repo)).compiled


def test_sphinx_warnings(repo):
    from sphinx.testing.util import SphinxTestApp
    (repo / 'docs' / 'conf.py').write_text(
        "extensions = ['myst_parser', 'fortref', 'mocdocs']\n"
        "fortref_allow_unpushed = True\n"
        "fortref_limitations_page = None\n")
    (repo / 'docs' / 'index.md').write_text('# Mini\n')
    warning = io.StringIO()
    app = SphinxTestApp('html', srcdir=repo / 'docs', status=io.StringIO(),
                        warning=warning, freshenv=True)
    try:
        app.build()
    finally:
        app.cleanup()
    found = re.findall(r'WARNING: (.*?) \[mocdocs\.(\w+)\]', warning.getvalue())
    # (the mini Makefile also lacks the real one's targets and flags: 'build')
    assert {'keywords', 'outputs'} <= {s for _, s in found}
    assert any('"beta"' in m for m, s in found if s == 'keywords')
    assert any('output/b.out' in m for m, s in found if s == 'outputs')
    assert (repo / 'docs' / 'user-guide' / 'keywords.md').exists()
