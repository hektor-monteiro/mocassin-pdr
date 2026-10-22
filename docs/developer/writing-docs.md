# Writing the docs

The site is Sphinx with MyST Markdown. Pages link into the code through the
`fortref` extension (`docs/_ext/fortref/`): a reference names a file, a program
unit and, if needed, a line of text, and is resolved against the working tree
every time the site is built. A reference that no longer matches the code is a
build warning, and the build runs with `-W`, so a stale link cannot be
published.

## Building

```bash
python3 -m venv ~/.venvs/mocassin-docs
~/.venvs/mocassin-docs/bin/pip install -r docs/requirements-dev.txt
~/.venvs/mocassin-docs/bin/sphinx-build -W --keep-going -b html docs docs/_build/html
```

`docs/requirements.txt` is what Read the Docs installs; `requirements-dev.txt`
adds pytest and pypandoc for local work. These pages are written by the build
and are not in git; edit their sources, not them:

| Page | Written from | By |
| :--- | :--- | :--- |
| `physics/limitations.md` | `doc/pdr-status.md` | fortref |
| `developer/devlog-index.md` | the DEVLOG index tables and dated headings | fortref |
| `user-guide/keywords.md` | `reference/keywords.yaml` and `readInput` | mocdocs |
| `user-guide/outputs.md` | `reference/outputs.yaml` | mocdocs |
| `user-guide/build-flavours.md` | the `Makefile` | mocdocs |
| `reference/changelog.md` | the release notes in `DEVLOG.md` | mocdocs |
| `developer/code-map.md` | the parsed source tree | mocdocs |
| `benchmarks/_generated/*.svg` | `bench/data/` | `bench/plots.py` |

The keyword and output pages are checked against the code on every build: a
keyword `readInput` accepts that is missing from `keywords.yaml`, or an output
file a routine opens that is missing from `outputs.yaml`, fails the build
(warning type `mocdocs`, subtypes `keywords`, `outputs` and `build`).

To check every reference without building the site, and to run the
extension's tests:

```bash
PYTHONPATH=docs/_ext ~/.venvs/mocassin-docs/bin/python -m fortref check docs
~/.venvs/mocassin-docs/bin/python -m pytest docs/_ext/fortref/tests -q
```

`check -v` prints what each reference resolves to.

## References to the code

A reference has the form

```text
path[::scope][@"text"[+N | ..@"endtext"][#k]][ [profile]]
```

`path`
: A file. It is looked up as `source/<path>` first, then from the repository
  root, so `update_mod.f90`, `pdr/shield.F90`, `Makefile` and
  `doc/pdr-status.md` all work.

`::scope`
: A program unit, named by the end of its chain of enclosing units and
  matched without regard to case. `update_mod.f90::thermBalance` and
  `update_mod.f90::updateCell/thermBalance` both name the internal procedure
  `thermBalance` of `updateCell` in module `update_mod`. The name must match
  exactly one unit of the file, otherwise the build warns `scope` (none) or
  `ambiguous` (several, listed). An interface body is a declaration, not a
  unit. C files have functions as units.

`@"text"`
: A line: the text must appear, with runs of whitespace taken as one space,
  on exactly one active line of the scope (or of the file, without a scope).
  Inside the quotes write `\"` for a quote and `\\` for a backslash. No match
  warns `text`, with the closest lines; several warn `text-ambiguous`, with
  their line numbers.

`#k`
: Take the k-th match (counting from 1) when the text matches more than once.

`+N`, `..@"endtext"`
: Set the extent by hand: the matched line and the N lines after it, or from
  the match to the first active line after it that contains `endtext`.

`[profile]`
: The build the file is read as: `3d` (the default, `make PDR=1 PDRGEOM=3D`),
  `1d` (`make PDR=1`) or `plain` (`make`). The cpp macros of each come from
  the Makefile. Lines the profile compiles out are inactive: a text anchor
  never matches them, and a unit defined in them does not exist.

Without `+N` or `..@`, the extent of a text anchor follows the line it lands
on:

- a comment: the comment block, then the next statement;
- a construct opener (`do`, `if ... then`, `select case`, `where`, ...): to its
  closer; an `#if`/`#ifdef` line likewise to its `#endif`;
- a `case`, `else` or `#else`: to the next branch, leaving out the comments
  that open that branch;
- a `subroutine`, `function` or `module` header: the whole unit;
- any other statement: to the next blank line.

The extent never leaves the routine the match is in. An automatic extent over
60 lines warns `long-extent`; narrow it with `+N` or `..@"endtext"`.

### The `{src}` role

`` {src}`ref` `` shows the unit's name and links to the site's source viewer at
the resolved lines; the small mark after it is the GitHub permalink. Write
`` {src}`title <ref>` `` to choose the text. For example, the thermal balance is
{src}`update_mod.f90::updateCell/thermBalance`; the stop test's tolerance is
read in {src}`the convTotals case <set_input_mod.f90::readInput@"case (\"convTotals\")">`;
the H2 level model is {src}`pdr_mod.f90::h2LevelModel` in the 3D build and
{src}`a stub <pdr_mod.f90::h2LevelModel [1d]>` in the 1D one; 3D-PDR's
single-line H2 photodissociation rate is {src}`pdr/shield.F90::H2PDRATE`, and
the chemistry is integrated by the C function
{src}`pdr/calculate_abundances.c::calculate_abundances_`. A file outside the
Makefile's build lists carries a badge: {src}`gaunt.f90`.

### The `fortran-block` directive

`:::{fortran-block} ref` shows the lines themselves, numbered as in the file,
with the file, routine and lines in the caption. Options:

`:context: N`
: N more lines above and below the extent.

`:emphasize: text`
: Highlight every shown line that contains the text (whitespace collapsed).

`:max-lines: N`, `:allow-long:`
: A block over `max-lines` lines (60 by default) is a build error unless
  `:allow-long:` is given.

`:hide-inactive:`
: Leave out the lines the profile compiles out; the block is then shown in
  pieces, each numbered as in the file.

A comment anchor takes the comment and the statement after it:

```md
:::{fortran-block} iteration_mod.f90::iterateMC@"H-012 (DEVLOG-H2 stage B)"
:emphasize: call h2LevelModel
:::
```

:::{fortran-block} iteration_mod.f90::iterateMC@"H-012 (DEVLOG-H2 stage B)"
:emphasize: call h2LevelModel
:::

An `#ifdef` anchor runs to its `#endif`; here the header of
`escape_probability` as the 1D build compiles it ({devlog}`D-083` is why the
three headers differ):

```md
:::{fortran-block} pdr/escape_probability.F90@"#ifdef RAYTHEIA_MO"#1 [1d]
:hide-inactive:
:::
```

:::{fortran-block} pdr/escape_probability.F90@"#ifdef RAYTHEIA_MO"#1 [1d]
:hide-inactive:
:::

## Limitations and DEVLOG entries

`` {lim}`L-58` `` links to an item of the known limitations, here
{lim}`L-58`, on the page generated from `doc/pdr-status.md`; each line there
that opens an item (`**L-n.` or `**L-n (`) carries the target; a number that
opens a second item (an open item with a closed part) gets `lim-L-n-2`. `` {devlog}`D-363` `` links
to a decision in the [DEVLOG index](devlog-index.md), with its short title on
hover: {devlog}`D-363`. An unknown number warns `lim` or `devlog`.

## Links, the viewer and the report

GitHub links name one commit for the whole build: on Read the Docs the commit
being built; locally HEAD if a remote branch has it, else the newest
merge-base with a remote branch at which every referenced file is as it is in
the working tree. If there is none the build warns `unpushed`
(`fortref_allow_unpushed = True` in `conf.py` silences it for a draft). It
warns `dirty` when `source/`, the `Makefile` or `dataPDR/` have uncommitted
changes, since line numbers come from the working tree.

The source viewer pages are written to `_src/<path>.html` for the referenced
files only. The build also writes `fortref-report.json` next to the HTML:
every routine of the compiled files, the profiles it exists under, and the
pages that cite it.

Every fortref warning has the type `fortref` and one of the subtypes `file`,
`scope`, `ambiguous`, `text`, `text-ambiguous`, `parse`, `long-extent`,
`dirty`, `unpushed`, `lim` and `devlog`.
