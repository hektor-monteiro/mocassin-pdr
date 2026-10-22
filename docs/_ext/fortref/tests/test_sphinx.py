"""A sphinx.testing mini-project on a small git repository: good references
build with no warning and link where they should; each bad one gives its
warning subtype."""

import io
import json
import re

import pytest
from sphinx.testing.util import SphinxTestApp
from test_extents import SOURCE

MAKEFILE = """\
ifeq ($(PDR),1)
  FFLAGS += -DPDR
endif
SOURCES = source/m.o source/dup.o
"""

DUP = """\
module one
contains
  subroutine work()
  end subroutine work
end module one
module two
contains
  subroutine work()
  end subroutine work
end module two
"""

DEVLOG = """\
# DEVLOG

| ID | Not this table | Status | Entry |
|----|----|----|----|
| D-900 | decoy | Accepted | 2026-01-01 |

## Index of decisions

| ID | Decision | Status | Entry |
|----|----------|--------|-------|
| D-001 | **First decision, in bold.** And more | Accepted | 2026-08-28 |
| D-002 | A plain decision with a `code` span and |pipes| in it | Accepted | 2026-08-29 |
| D-003 | Three cells | Done 2026-08-30 |
"""

DEVLOG_H2 = """\
# DEVLOG-H2

| ID | Summary | Status | Date |
|---|---|---|---|
| H-001 | **The branch.** x | Done | 2026-09-28 |
"""

STATUS = """\
# Status

See [the dust notes](dust.md) and [the code](../source/m.f90#L3).

**L-1. The first limitation.** Text.

**L-2. The second** (D-001). Text.

**L-2. The second, resolved part.** Text.
"""

CONF = """\
extensions = ['myst_parser', 'fortref']
myst_enable_extensions = ['colon_fence']
fortref_github = 'https://github.com/example/repo'
"""

INDEX = """\
# Mini

```{toctree}
good
bad
physics/limitations
developer/devlog-index
```
"""

GOOD = """\
# Good

Unit {src}`m.f90::s`, titled {src}`the second case <m.f90::s@"case (2)">`,
1D {src}`m.f90::t [plain]`, uncompiled {src}`extra.f90`, {lim}`L-2`, {devlog}`D-001`,
{devlog}`H-001`.

:::{fortran-block} m.f90::s@"do i = 1, n"
:context: 1
:emphasize: "y = i"
:::

:::{fortran-block} m.f90::long
:allow-long:
:hide-inactive:
:::
"""

BAD = """\
# Bad

{src}`nosuch.f90`

{src}`m.f90::nosuch`

{src}`dup.f90::work`

{src}`m.f90@"no such text"`

{src}`m.f90@"a = "`

{src}`m.f90 [2d]`

{src}`m.f90@"subroutine long()"`

{lim}`L-99`

{devlog}`D-999`

:::{fortran-block} m.f90::long
:::
"""


@pytest.fixture
def project(tmp_path, hermetic_git):
    git = hermetic_git
    root = tmp_path / 'repo'
    for rel, text in {
        'Makefile': MAKEFILE, 'source/m.f90': SOURCE, 'source/dup.f90': DUP,
        'source/extra.f90': 'subroutine extra()\nend subroutine extra\n',
        'DEVLOG.md': DEVLOG, 'DEVLOG-H2.md': DEVLOG_H2,
        'doc/pdr-status.md': STATUS, 'doc/dust.md': '# Dust\n',
        'docs/conf.py': CONF, 'docs/index.md': INDEX, 'docs/good.md': GOOD,
        'docs/bad.md': BAD,
    }.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
    git(tmp_path, 'init', '-q', '--bare', '-b', 'main', str(tmp_path / 'remote.git'))
    git(root, 'init', '-q', '-b', 'main')
    git(root, 'add', '-A')
    git(root, 'commit', '-q', '-m', 'mini')
    git(root, 'remote', 'add', 'origin', str(tmp_path / 'remote.git'))
    git(root, 'push', '-q', 'origin', 'main')
    return root, git(root, 'rev-parse', 'HEAD')


def build(root):
    warning = io.StringIO()
    app = SphinxTestApp('html', srcdir=root / 'docs', status=io.StringIO(),
                        warning=warning, freshenv=True)
    try:
        app.build()
    finally:
        app.cleanup()
    return warning.getvalue(), root / 'docs' / '_build' / 'html'


def by_page(warnings, page):
    return re.findall(rf'{page}\.md:(\d+): (?:WARNING|ERROR): .*?\[fortref\.([\w-]+)\]', warnings)


def test_good_and_bad_references(project):
    root, sha = project
    warnings, out = build(root)
    assert by_page(warnings, 'good') == []
    others = [ln for ln in warnings.splitlines() if 'bad.md:' not in ln]
    assert [ln for ln in others if re.search(r'WARNING|ERROR', ln)] == [], warnings
    assert by_page(warnings, 'bad') == [
        ('3', 'file'), ('5', 'scope'), ('7', 'ambiguous'), ('9', 'text'),
        ('11', 'text-ambiguous'), ('13', 'parse'), ('15', 'long-extent'),
        ('17', 'lim'), ('19', 'devlog'), ('21', 'long-extent')]

    good = (out / 'good.html').read_text()
    assert 'href="_src/source/m.f90.html#L3-L34"' in good
    assert f'href="https://github.com/example/repo/blob/{sha}/source/m.f90#L3-L34"' in good
    assert '<code class="docutils literal notranslate"><span class="pre">the</span>' in good
    assert 'href="_src/source/m.f90.html#L17-L18"' in good
    assert 'href="_src/source/m.f90.html#L40-L41"' in good
    assert 'href="_src/source/extra.f90.html"' in good and 'fortref-badge' in good
    assert 'href="physics/limitations.html#lim-l-2"' in good
    assert 'title="The second"' in good
    assert 'href="developer/devlog-index.html#devlog-d-001"' in good
    assert 'title="D-001 (2026-08-28): First decision, in bold."' in good
    assert 'href="developer/devlog-index.html#devlog-h-001"' in good
    # the block: lines 9-11 and one of context (8 and 12 are empty, so left
    # out), line 10 emphasized
    assert re.search(r'<span class="linenos"> ?9</span><span class="w">    </span>'
                     r'<span class="k">do </span>', good)
    assert re.search(r'<span class="hll"><span class="linenos">10</span>'
                     r'<span class="w">       </span><span class="n">y</span>', good)
    assert 'lines 9–11' in good
    assert '<span class="linenos"> 8</span>' not in good

    viewer = (out / '_src' / 'source' / 'm.f90.html').read_text()
    assert '<span id="L3">' in viewer and 'href="#L3"' in viewer
    assert f'https://github.com/example/repo/blob/{sha}/source/m.f90' in viewer
    assert not (out / '_src' / 'source' / 'dup.f90.html').exists()

    report = json.loads((out / 'fortref-report.json').read_text())
    assert report['link_sha'] == sha and report['link_sha_from'] == 'head'
    s = next(r for r in report['routines'] if r['qualname'] == 'm/s')
    assert s['cited_by'] == ['good'] and s['profiles'] == ['3d', '1d', 'plain']
    work = [r for r in report['routines'] if r['name'] == 'work']
    assert len(work) == 2 and all(r['cited_by'] == [] for r in work)

    lim = (root / 'docs' / 'physics' / 'limitations.md').read_text()
    assert f'[the dust notes](https://github.com/example/repo/blob/{sha}/doc/dust.md)' in lim
    assert f'(https://github.com/example/repo/blob/{sha}/source/m.f90#L3)' in lim
    assert lim.count('(lim-L-2)=') == 1 and '(lim-L-1)=\n**L-1.' in lim

    index = (root / 'docs' / 'developer' / 'devlog-index.md').read_text()
    assert 'D-900' not in index
    assert '**D-002** · 2026-08-29 · A plain decision with a code span and \\|pipes\\| in it' in index
    assert '**D-003** · 2026-08-30 · Three cells' in index


def test_dirty_and_unpushed(project, hermetic_git):
    root, sha = project
    (root / 'source' / 'm.f90').write_text(SOURCE.replace('x = 1', 'x = 2'))
    warnings, _ = build(root)
    # HEAD is on the remote: its links stand, the edit is reported
    assert '[fortref.dirty]' in warnings and '[fortref.unpushed]' not in warnings
    hermetic_git(root, 'commit', '-q', '-am', 'local')
    warnings, _ = build(root)
    assert '[fortref.dirty]' not in warnings and '[fortref.unpushed]' in warnings
    (root / 'docs' / 'conf.py').write_text(CONF + 'fortref_allow_unpushed = True\n')
    warnings, _ = build(root)
    assert '[fortref.unpushed]' not in warnings
