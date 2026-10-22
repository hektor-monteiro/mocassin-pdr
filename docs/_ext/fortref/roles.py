"""The roles {src}, {lim} and {devlog}, the fortran-block directive, and the
two generated pages the last two roles link into."""

import os
import re

from docutils import nodes
from docutils.parsers.rst import directives
from sphinx.util import logging
from sphinx.util.docutils import SphinxDirective, SphinxRole

from . import resolve

logger = logging.getLogger(__name__)

LANGUAGES = {'fortran': 'fortran', 'c': 'c'}


def warn(subtype, message, location=None):
    logger.warning(message, type='fortref', subtype=subtype, location=location)


def _record(env, docname, kind, line, res):
    if not hasattr(env, 'fortref_refs'):
        env.fortref_refs = {}
    unit = res.unit
    env.fortref_refs.setdefault(docname, []).append({
        'kind': kind, 'line': line, 'ref': res.ref.raw, 'path': res.path,
        'start': res.start, 'end': res.end, 'profile': res.ref.profile,
        'unit': unit.qualname if unit else None,
        'unit_start': unit.start if unit else None,
        'unit_end': unit.end if unit else None,
    })


def _links(res, start, end, label):
    """[viewer link around `label`, GitHub icon link]; their URIs are filled
    in when the page is written (doctree-resolved)."""
    hover = res.path + (f' L{start}-L{end}' if start else '')
    if res.unit is not None:
        hover += f' · {res.unit.qualname}'
    hover += f' · {res.ref.profile}'
    view = nodes.reference('', '', internal=True, refuri='#', reftitle=hover,
                           classes=['fortref-src'])
    view['fortref_kind'] = 'viewer'
    gh = nodes.reference('', '', internal=False, refuri='#', reftitle='GitHub permalink',
                         classes=['fortref-gh'])
    gh['fortref_kind'] = 'github'
    for node in (view, gh):
        node['fortref_path'] = res.path
        node['fortref_start'] = start or 0
        node['fortref_end'] = end or 0
    view += label
    gh += nodes.inline('GitHub', 'GitHub', classes=['fortref-gh-label'])
    return view, gh


def _badge():
    return nodes.inline('not compiled', 'not compiled', classes=['fortref-badge'])


def _resolve(env, raw, location, max_lines=None, allow_long=False):
    state = env.app.fortref
    try:
        ref = resolve.parse_ref(raw, env.config.fortref_default_profile)
    except resolve.RefSyntaxError as err:
        warn('parse', f'{raw}: {err}', location)
        return None
    env.note_dependency(state.repo.makefile)
    rel = state.repo.locate(ref.path)
    if rel is not None:
        env.note_dependency(os.path.join(state.repo.root, rel))
    res, warnings = state.repo.resolve(
        ref, max_lines=max_lines or env.config.fortref_max_lines, allow_long=allow_long)
    for subtype, message in warnings:
        warn(subtype, f'{raw}: {message}', location)
    return res


class SrcRole(SphinxRole):
    """{src}`ref` or {src}`title <ref>`: the file and lines (or the routine's
    name, with fortref_display = 'name'), linked to the
    site's source viewer at the resolved lines, with a GitHub permalink."""

    def run(self):
        title, raw = resolve.split_title(self.text)
        res = _resolve(self.env, raw, self.get_location())
        if res is None:
            text = title or raw
            return [nodes.literal(self.rawtext, text, classes=['fortref-broken'])], []
        _record(self.env, self.env.docname, 'src', self.lineno, res)
        shown = res.location if self.env.config.fortref_display == 'location' else res.display
        text = title or shown
        view, gh = _links(res, res.start, res.end, nodes.literal(text, text))
        wrap = nodes.inline(classes=['fortref'])
        wrap += view
        wrap += gh
        if not res.compiled:
            wrap += _badge()
        return [wrap], []


class FortranBlock(SphinxDirective):
    """:::{fortran-block} ref -- the resolved lines, highlighted, with the
    file, routine and lines in the caption."""

    required_arguments = 1
    final_argument_whitespace = True
    has_content = False
    option_spec = {
        'context': directives.nonnegative_int,
        'max-lines': directives.positive_int,
        'allow-long': directives.flag,
        'emphasize': directives.unchanged_required,
        'hide-inactive': directives.flag,
    }

    def run(self):
        raw = self.arguments[0]
        location = self.get_location()
        max_lines = self.options.get('max-lines', self.config.fortref_max_lines)
        allow_long = 'allow-long' in self.options
        # the block's own length test below (context included) stands in for
        # the resolver's long-extent warning
        res = _resolve(self.env, raw, location, max_lines, allow_long=True)
        if res is None:
            return []
        model = res.model
        a, b = (res.start, res.end) if res.start is not None else (1, model.nlines)
        ctx = self.options.get('context', 0)
        lo, hi = max(1, a - ctx), min(model.nlines, b + ctx)
        if hi - lo + 1 > max_lines and not allow_long:
            logger.error(f'{raw}: the block is {hi - lo + 1} lines (L{lo}-L{hi}), over '
                         f':max-lines: {max_lines}; narrow the reference or add :allow-long:',
                         type='fortref', subtype='long-extent', location=location)
            return []
        emphasized = set()
        needle = self.options.get('emphasize')
        if needle:
            emphasized.update(resolve.text_hits(model, needle, lo, hi))
            if not emphasized:
                warn('text', f'{raw}: :emphasize: "{needle}" is on no active line of '
                             f'L{lo}-L{hi}', location)
        shown = [n for n in range(lo, hi + 1)
                 if 'hide-inactive' not in self.options or model.active[n - 1]]
        runs = []
        for n in shown:
            if runs and runs[-1][-1] == n - 1:
                runs[-1].append(n)
            else:
                runs.append([n])
        # Pygments drops empty lines at the ends of a block, which would shift
        # every line number after them: leave them out here instead
        empty = lambda n: model.lines[n - 1].rstrip('\r') == ''  # noqa: E731
        runs = [run for run in (_strip_run(r, empty) for r in runs) if run]
        _record(self.env, self.env.docname, 'block', self.lineno, res)
        container = nodes.container('', literal_block=True,
                                    classes=['literal-block-wrapper', 'fortref-block'])
        container += self._caption(res, a, b)
        for run in runs:
            code = '\n'.join(model.lines[n - 1].rstrip('\r') for n in run)
            block = nodes.literal_block(code, code)
            block['language'] = LANGUAGES.get(res.language, 'text')
            block['linenos'] = True
            block['force'] = True
            block['highlight_args'] = {'linenostart': run[0]}
            hl = [n - run[0] + 1 for n in run if n in emphasized]
            if hl:
                block['highlight_args']['hl_lines'] = hl
            self.set_source_info(block)
            container += block
        self.set_source_info(container)
        return [container]

    def _caption(self, res, a, b):
        caption = nodes.caption('', '')
        view, gh = _links(res, a, b, nodes.literal(res.path, res.path))
        caption += view
        if res.unit is not None:
            caption += nodes.Text(' · ')
            caption += nodes.literal(res.unit.qualname, res.unit.qualname)
        caption += nodes.Text(f' · lines {a}–{b}')
        if res.ref.profile != self.config.fortref_default_profile:
            caption += nodes.Text(f' · {res.ref.profile} build')
        caption += nodes.Text(' ')
        caption += gh
        if not res.compiled:
            caption += nodes.Text(' ')
            caption += _badge()
        return caption


def _strip_run(run, empty):
    while run and empty(run[0]):
        run = run[1:]
    while run and empty(run[-1]):
        run = run[:-1]
    return run


class _LabelRole(SphinxRole):
    """A role that links an ID to its target on a generated page."""

    pattern = None
    kind = None

    def run(self):
        ident = self.text.strip()
        titles, label, source = self.lookup(ident)
        for path in source:
            self.env.note_dependency(path)
        if label is None:
            warn(self.kind, f'{{{self.kind}}}`{ident}`: unknown {self.what}', self.get_location())
            return [nodes.literal(self.rawtext, ident, classes=['fortref-broken'])], []
        node = nodes.reference('', '', internal=True, refuri='#', reftitle=titles,
                               classes=[f'fortref-{self.kind}'])
        node['fortref_kind'] = 'label'
        node['fortref_label'] = label
        node += nodes.inline(ident, ident)
        return [node], []


class LimRole(_LabelRole):
    """{lim}`L-37`: the limitation on the limitations page."""

    kind = 'lim'
    what = 'limitation (no **L-n. line in doc/pdr-status.md)'

    def lookup(self, ident):
        state = self.env.app.fortref
        source = [os.path.join(state.repo.root, LIMITATIONS_SOURCE)]
        m = re.fullmatch(r'L-(\d+)', ident)
        if not m or int(m.group(1)) not in state.lim:
            return None, None, source
        n = int(m.group(1))
        return state.lim[n] or f'L-{n}', f'lim-l-{n}', source


class DevlogRole(_LabelRole):
    """{devlog}`D-363`: the decision on the DEVLOG index page."""

    kind = 'devlog'
    what = ('DEVLOG ID (not in the index tables of DEVLOG.md or DEVLOG-H2.md, '
            'nor in a dated body heading)')

    def lookup(self, ident):
        state = self.env.app.fortref
        source = [os.path.join(state.repo.root, f) for f in DEVLOG_SOURCES]
        if ident not in state.devlog:
            return None, None, source
        title, date = state.devlog[ident]
        return f'{ident} ({date}): {title}', f'devlog-{ident.lower()}', source


# ---------------------------------------------------------------- generated pages

LIMITATIONS_SOURCE = 'doc/pdr-status.md'
DEVLOG_SOURCES = ('DEVLOG.md', 'DEVLOG-H2.md')
# a line that opens an item: **L-n. Title**, or **L-n (resolved part). for
# the second part of an item split into an open and a closed one
_LIM_LINE = re.compile(r'^\*\*L-(\d+)(\.| \()')
# a dated body heading: ## 2026-09-07b - D-172: title, or D-060/D-061/D-062
_DATED_HEADING = re.compile(
    r'^## (\d{4}-\d\d-\d\d)[a-z]? - ((?:[DH]-\d+)(?:\s*/\s*[DH]-\d+)*)\s*[:\-–—]\s*(.+?)\s*$')
_MD_LINK = re.compile(r'(?<!!)\[([^\]]*)\]\(([^)\s]+)\)')


def write_if_changed(path, text):
    """Write text unless the file already holds it (an unchanged mtime keeps
    Sphinx from re-reading the page)."""
    if os.path.exists(path):
        with open(path, encoding='utf-8') as fh:
            if fh.read() == text:
                return False
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(text)
    return True


def _plain(md):
    """Inline Markdown to plain text: emphasis markers and backticks dropped."""
    return re.sub(r'\s+', ' ', md.replace('**', '').replace('`', '')).strip()


def md_escape(text):
    return re.sub(r'([\\`*_{}\[\]<>()#+!|$~&])', r'\\\1', text)


def limitation_links(root):
    """Repo-relative paths that doc/pdr-status.md links to."""
    path = os.path.join(root, LIMITATIONS_SOURCE)
    if not os.path.exists(path):
        return set()
    with open(path, encoding='utf-8') as fh:
        text = fh.read()
    out = set()
    for _, target in _MD_LINK.findall(text):
        rel = _repo_relative(target)
        if rel:
            out.add(rel.split('#')[0])
    return out


def _repo_relative(target):
    if re.match(r'^[a-z][a-z0-9+.-]*:', target, re.I) or target.startswith(('#', '/')):
        return None
    path, _, frag = target.partition('#')
    norm = os.path.normpath(os.path.join(os.path.dirname(LIMITATIONS_SOURCE), path))
    if norm.startswith('..'):
        return None
    return norm + (f'#{frag}' if frag else '')


def write_limitations(root, srcdir, docname, github, sha):
    """physics/limitations.md from doc/pdr-status.md: repo-relative links to
    GitHub at the link commit, and a (lim-L-n)= target before each line that
    opens an item (**L-n. or **L-n (...)).  An L-number that opens several
    items (an item split into an open and a closed part) has lim-L-n at its
    first, which {lim} links to, and lim-L-n-2, lim-L-n-3, ... at the others.
    Returns ({n: title}, [repeated L-numbers])."""
    path = os.path.join(root, LIMITATIONS_SOURCE)
    if not os.path.exists(path):
        return {}, []
    with open(path, encoding='utf-8') as fh:
        lines = fh.read().split('\n')

    def link(m):
        rel = _repo_relative(m.group(2))
        if rel is None:
            return m.group(0)
        file, _, frag = rel.partition('#')
        return f'[{m.group(1)}]({github.rstrip("/")}/blob/{sha}/{file}' + \
               (f'#{frag}' if frag else '') + ')'

    out = [f'% Generated by fortref from {LIMITATIONS_SOURCE} when the docs are built; '
           f'edit that file, not this one.', '']
    titles, repeated = {}, []
    for i, line in enumerate(lines):
        m = _LIM_LINE.match(line)
        if m:
            n = int(m.group(1))
            if n in titles:
                repeated.append(n)
                out.append(f'(lim-L-{n}-{repeated.count(n) + 1})=')
            else:
                para = []
                for nxt in lines[i:]:
                    if not nxt.strip():
                        break
                    para.append(nxt)
                head = re.match(r'^\*\*L-\d+\.\s*(.*?)\*\*', ' '.join(para))
                titles[n] = _plain(head.group(1)) if head else ''
                out.append(f'(lim-L-{n})=')
        out.append(_MD_LINK.sub(link, line))
    write_if_changed(os.path.join(srcdir, docname + '.md'), '\n'.join(out))
    return titles, repeated


def devlog_entries(path):
    """[(ID, short title, date)] from the summary table of a DEVLOG file: the
    table under '## Index of decisions', or else the first table whose first
    column is ID.  The short title is the Decision cell's leading bold span
    when it has one, else its first 160 characters."""
    with open(path, encoding='utf-8') as fh:
        lines = fh.read().split('\n')
    start = 0
    for i, line in enumerate(lines):
        if line.strip().lower() == '## index of decisions':
            start = i
            break
    i = start
    while i < len(lines) and not re.match(r'^\|\s*ID\s*\|', lines[i]):
        i += 1
    entries = []
    for line in lines[i + 2:]:
        if not line.startswith('|'):
            break
        cells = line.strip().strip('|').split('|')
        ident = cells[0].strip()
        if not re.fullmatch(r'[A-Z]-\d+', ident) or len(cells) < 3:
            continue
        decision = ('|'.join(cells[1:-2]) if len(cells) >= 4 else cells[1]).strip()
        bold = re.match(r'^\*\*(.+?)\*\*', decision)
        if bold:
            title = _plain(bold.group(1))
        else:
            plain = _plain(decision)
            title = plain[:160] + ('…' if len(plain) > 160 else '')
        date = re.search(r'\d{4}-\d{2}-\d{2}', cells[-1])
        entries.append((ident, title, date.group(0) if date else ''))
    return entries


def devlog_heading_entries(path):
    """[(ID, short title, date)] from the dated body headings of a DEVLOG file
    (## 2026-09-07b - D-172: title); every ID a heading lists
    (D-060/D-061/D-062) gets that heading."""
    with open(path, encoding='utf-8') as fh:
        lines = fh.read().split('\n')
    entries = []
    for line in lines:
        m = _DATED_HEADING.match(line)
        if m:
            for ident in re.split(r'\s*/\s*', m.group(2)):
                entries.append((ident, _plain(m.group(3)), m.group(1)))
    return entries


def devlog_sources(root):
    """({file name: [(ID, short title, date)]}, [IDs from body headings]):
    each DEVLOG file's summary table, then the IDs of its dated body headings
    that are in no summary table (the first heading naming an ID wins)."""
    tables = {}
    for name in DEVLOG_SOURCES:
        path = os.path.join(root, name)
        if os.path.exists(path):
            tables[name] = devlog_entries(path)
    known = {e[0] for entries in tables.values() for e in entries}
    added = []
    for name in tables:
        for ident, title, date in devlog_heading_entries(os.path.join(root, name)):
            if ident not in known:
                tables[name].append((ident, title, date))
                known.add(ident)
                added.append(ident)
    return tables, added


def write_devlog_index(root, srcdir, docname):
    """developer/devlog-index.md; returns ({ID: (title, date)}, [IDs from body
    headings])."""
    sections = []
    table = {}
    tables, added = devlog_sources(root)
    for name, label in zip(DEVLOG_SOURCES, ('production, D-numbers', 'H2 model, H-numbers')):
        if name not in tables:
            continue
        entries = sorted(tables[name], key=lambda e: int(e[0].split('-')[1]))
        body = [f'## {name} ({label})', '']
        for ident, title, date in entries:
            table[ident] = (title, date)
            body.append(f'- (devlog-{ident})=')
            body.append(f'  **{ident}** · {date} · {md_escape(title)}')
            body.append('')
        sections.append('\n'.join(body))
    text = '\n'.join([
        '% Generated by fortref from DEVLOG.md and DEVLOG-H2.md when the docs are built; '
        'edit those files, not this one.',
        '',
        '# DEVLOG index',
        '',
        'Every decision in the summary tables of `DEVLOG.md` and `DEVLOG-H2.md`, '
        'and every one that has a dated body section (`## 2026-09-07b - D-172: ...`) '
        'but no row there, with its short title and date. The full entries are in '
        'those files.',
        '',
    ] + sections)
    write_if_changed(os.path.join(srcdir, docname + '.md'), text)
    return table, added
