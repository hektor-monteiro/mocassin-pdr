"""fortref: links from the documentation to the code, kept honest.

References name a file, a program unit and optionally a line of text
(see resolve.py for the grammar); they are resolved against the working
tree when the docs are built, under the cpp macros of a build profile read
from the Makefile, so a reference that no longer matches the code is a
build warning rather than a wrong link.

Roles {src}, {lim}, {devlog}; directive fortran-block; the source viewer
under _src/; fortref-report.json in the HTML output.
"""

import json
import os

from docutils import nodes
from sphinx.util import logging
from sphinx.util.osutil import relative_uri

from . import cpp, resolve, roles, viewer

__version__ = '1.0'

logger = logging.getLogger(__name__)
STATIC = os.path.join(os.path.dirname(__file__), 'static')


class State:
    """What a build resolves against; set up once per build, before reading."""

    def __init__(self, repo, sha, how, lim, devlog):
        self.repo, self.sha, self.how, self.lim, self.devlog = repo, sha, how, lim, devlog


def repo_root(app):
    return app.config.fortref_repo_root or os.path.join(app.confdir, '..')


def referenced_paths(repo, srcdir, exclude=()):
    """Repo-relative files that the pages' {src} roles and fortran-block
    directives name (a fast scan, before Sphinx reads anything)."""
    paths = set()
    for page in markdown_pages(srcdir, exclude):
        with open(page, encoding='utf-8', errors='replace') as fh:
            found = resolve.scan_markdown(fh.read())
        for kind, content, _, _ in found:
            if kind not in ('src', 'fortran-block'):
                continue
            _, raw = resolve.split_title(content)
            try:
                rel = repo.locate(resolve.parse_ref(raw).path)
            except resolve.RefSyntaxError:
                continue
            if rel:
                paths.add(rel)
    return paths


def markdown_pages(srcdir, exclude=()):
    srcdir = os.path.realpath(srcdir)
    skip = {os.path.realpath(p) for p in exclude}
    for dirpath, dirnames, filenames in os.walk(srcdir):
        dirnames[:] = sorted(d for d in dirnames
                             if not d.startswith(('.', '_build'))
                             and os.path.realpath(os.path.join(dirpath, d)) not in skip)
        for name in sorted(filenames):
            if name.endswith('.md'):
                yield os.path.join(dirpath, name)


def on_config_inited(app, config):
    if STATIC not in config.html_static_path:
        config.html_static_path.append(STATIC)


def on_builder_inited(app):
    config = app.config
    repo = resolve.Repo.at(repo_root(app))
    srcdir = str(app.srcdir)
    paths = referenced_paths(repo, srcdir, (app.outdir, app.doctreedir))
    paths |= roles.limitation_links(repo.root)
    sha, how, warnings = resolve.link_sha(repo.root, paths)
    warnings += resolve.dirty(repo.root)
    for subtype, message in warnings:
        if subtype == 'unpushed' and config.fortref_allow_unpushed:
            logger.info(f'fortref: {message} (allowed by fortref_allow_unpushed)')
            continue
        logger.warning(message, type='fortref', subtype=subtype)
    lim, repeated = ({}, [])
    if config.fortref_limitations_page:
        lim, repeated = roles.write_limitations(repo.root, srcdir, config.fortref_limitations_page,
                                                config.fortref_github, sha)
        if repeated:
            logger.info('fortref: L-numbers that open more than one item in '
                        f'{roles.LIMITATIONS_SOURCE} ({{lim}} links to the first; the '
                        'others are lim-L-n-2, ...): '
                        + ', '.join(f'L-{n}' for n in sorted(set(repeated))))
    devlog = {}
    if config.fortref_devlog_page:
        devlog, added = roles.write_devlog_index(repo.root, srcdir, config.fortref_devlog_page)
        if added:
            logger.info(f'fortref: {len(added)} DEVLOG IDs from dated body headings only: '
                        + ', '.join(added))
    app.fortref = State(repo, sha, how, lim, devlog)
    logger.info(f'fortref: links name {sha[:12]} ({how}); {len(paths)} referenced files')


def on_env_before_read_docs(app, env, docnames):
    if not hasattr(env, 'fortref_refs'):
        env.fortref_refs = {}


def on_env_purge_doc(app, env, docname):
    getattr(env, 'fortref_refs', {}).pop(docname, None)


def on_env_merge_info(app, env, docnames, other):
    if not hasattr(env, 'fortref_refs'):
        env.fortref_refs = {}
    theirs = getattr(other, 'fortref_refs', {})
    for docname in docnames:
        if docname in theirs:
            env.fortref_refs[docname] = theirs[docname]


def on_doctree_resolved(app, doctree, docname):
    state = app.fortref
    base = app.config.fortref_github
    html = app.builder.format == 'html'
    std = app.env.domains['std']
    for node in list(doctree.findall(nodes.reference)):
        kind = node.get('fortref_kind')
        if not kind:
            continue
        if kind == 'label':
            target = std.anonlabels.get(node['fortref_label'])
            if target is None:
                logger.warning(f'no target {node["fortref_label"]} for {node.astext()}',
                               type='fortref', subtype=node['classes'][0].split('-')[-1],
                               location=node)
                node.replace_self(node.children)
                continue
            todoc, labelid = target
            node['refuri'] = app.builder.get_relative_uri(docname, todoc) + '#' + labelid
            continue
        path = node['fortref_path']
        start, end = node['fortref_start'] or None, node['fortref_end'] or None
        github = resolve.github_url(base, state.sha, path, start, end)
        if kind == 'github' or not html:
            node['refuri'] = github
            continue
        uri = relative_uri(app.builder.get_target_uri(docname), f'_src/{path}.html')
        node['refuri'] = uri + (f'#L{start}-L{end}' if start else '')


def on_build_finished(app, exception):
    if exception is not None or app.builder.format != 'html' or not hasattr(app, 'fortref'):
        return
    state = app.fortref
    refs = getattr(app.env, 'fortref_refs', {})
    paths = sorted({r['path'] for recs in refs.values() for r in recs})
    written = 0
    for path in paths:
        github = resolve.github_url(app.config.fortref_github, state.sha, path)
        written += viewer.write(str(app.outdir), state.repo.root, path, github,
                                path in state.repo.compiled)
    report = build_report(state, refs, app.config.fortref_github)
    with open(os.path.join(str(app.outdir), 'fortref-report.json'), 'w', encoding='utf-8') as fh:
        json.dump(report, fh, indent=1, sort_keys=True)
    logger.info(f'fortref: {len(paths)} viewer pages ({written} rewritten), '
                f'{sum(len(r) for r in refs.values())} references, '
                f'{len(report["routines"])} routines in fortref-report.json')


def build_report(state, refs, github):
    """Every routine of the compiled files (and of any other cited file), with
    the profiles it exists under and the pages citing it; every reference."""
    repo = state.repo
    files = sorted(repo.compiled | {r['path'] for recs in refs.values() for r in recs})
    routines = {}
    for path in files:
        if resolve.parser.language_of(path) == 'text':
            continue
        for profile in cpp.PROFILES:
            for u in repo.model(path, profile).units:
                key = (path, u.qualname, u.start, u.end)
                entry = routines.setdefault(key, {
                    'path': path, 'name': u.name, 'qualname': u.qualname, 'kind': u.kind,
                    'start': u.start, 'end': u.end, 'compiled': path in repo.compiled,
                    'profiles': [], 'cited_by': []})
                entry['profiles'].append(profile)
    references = []
    for docname in sorted(refs):
        for r in refs[docname]:
            references.append(dict(r, docname=docname))
            if r['unit'] is None:
                continue
            key = (r['path'], r['unit'], r['unit_start'], r['unit_end'])
            if key in routines and docname not in routines[key]['cited_by']:
                routines[key]['cited_by'].append(docname)
    return {
        'link_sha': state.sha, 'link_sha_from': state.how, 'github': github,
        'routines': [routines[k] for k in sorted(routines)],
        'references': references,
    }


def setup(app):
    app.add_config_value('fortref_repo_root', None, 'env')
    app.add_config_value('fortref_github', 'https://github.com/hektor-monteiro/mocassin-pdr', 'env')
    app.add_config_value('fortref_default_profile', '3d', 'env')
    app.add_config_value('fortref_max_lines', resolve.DEFAULT_MAX_LINES, 'env')
    # what a {src} role shows without a title: 'location' (file:lines) or 'name'
    app.add_config_value('fortref_display', 'location', 'env')
    app.add_config_value('fortref_allow_unpushed', False, 'env')
    app.add_config_value('fortref_limitations_page', 'physics/limitations', 'env')
    app.add_config_value('fortref_devlog_page', 'developer/devlog-index', 'env')
    app.add_role('src', roles.SrcRole())
    app.add_role('lim', roles.LimRole())
    app.add_role('devlog', roles.DevlogRole())
    app.add_directive('fortran-block', roles.FortranBlock)
    app.add_css_file('fortref.css')
    app.connect('config-inited', on_config_inited)
    app.connect('builder-inited', on_builder_inited)
    app.connect('env-before-read-docs', on_env_before_read_docs)
    app.connect('env-purge-doc', on_env_purge_doc)
    app.connect('env-merge-info', on_env_merge_info)
    app.connect('doctree-resolved', on_doctree_resolved)
    app.connect('build-finished', on_build_finished)
    return {'version': __version__, 'env_version': 1,
            'parallel_read_safe': True, 'parallel_write_safe': True}
