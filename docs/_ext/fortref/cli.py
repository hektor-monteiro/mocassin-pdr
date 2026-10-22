"""python -m fortref check <docsdir>: resolve every reference in the pages
without building them.  Prints one line per problem, as the Sphinx build
would warn, and exits 1 if there is any."""

import argparse
import os
import sys

from . import markdown_pages, resolve, roles

DEFAULT_GITHUB = 'https://github.com/hektor-monteiro/mocassin-pdr'


def check(docsdir, repo_root=None, verbose=False, out=sys.stdout):
    docsdir = os.path.realpath(docsdir)
    repo = resolve.Repo.at(repo_root or os.path.join(docsdir, '..'))
    lim = set(_lim_numbers(repo.root))
    devlog = {e[0] for entries in roles.devlog_sources(repo.root)[0].values() for e in entries}
    problems, count, paths = [], 0, set()
    exclude = [os.path.join(docsdir, '_build')]
    for page in markdown_pages(docsdir, exclude):
        rel_page = os.path.relpath(page, docsdir)
        with open(page, encoding='utf-8', errors='replace') as fh:
            found = resolve.scan_markdown(fh.read())
        for kind, content, line, opts in found:
            where = f'{rel_page}:{line}'
            count += 1
            if kind == 'lim':
                n = content.strip()
                if not (n.startswith('L-') and n[2:].isdigit() and int(n[2:]) in lim):
                    problems.append((where, 'lim', f'{{lim}}`{n}`: unknown limitation'))
                continue
            if kind == 'devlog':
                if content.strip() not in devlog:
                    problems.append((where, 'devlog', f'{{devlog}}`{content.strip()}`: unknown DEVLOG ID'))
                continue
            raw = resolve.split_title(content)[1] if kind == 'src' else content
            max_lines = int(opts.get('max-lines') or resolve.DEFAULT_MAX_LINES)
            allow_long = 'allow-long' in opts
            res, warnings = repo.resolve(raw, max_lines=max_lines,
                                         allow_long=allow_long or kind == 'fortran-block')
            for subtype, message in warnings:
                problems.append((where, subtype, f'{raw}: {message}'))
            if res is None:
                continue
            paths.add(res.path)
            if kind == 'fortran-block':
                a, b = (res.start, res.end) if res.start else (1, res.model.nlines)
                ctx = int(opts.get('context') or 0)
                n = min(res.model.nlines, b + ctx) - max(1, a - ctx) + 1
                if n > max_lines and not allow_long:
                    problems.append((where, 'long-extent',
                                     f'{raw}: the block is {n} lines, over :max-lines: {max_lines}'))
            if verbose:
                span = f'L{res.start}-L{res.end}' if res.start else 'whole file'
                unit = res.unit.qualname if res.unit else '-'
                print(f'{where}: {res.path} {span} {unit} [{res.ref.profile}]', file=out)
    sha, how, warnings = resolve.link_sha(repo.root, paths)
    warnings += resolve.dirty(repo.root)
    for subtype, message in warnings:
        problems.append(('(repository)', subtype, message))
    for where, subtype, message in problems:
        print(f'{where}: WARNING: {message} [fortref.{subtype}]', file=out)
    print(f'fortref: {count} references in {docsdir}, {len(paths)} files, '
          f'links name {sha[:12]} ({how}); {len(problems)} problem(s)', file=out)
    return problems


def _lim_numbers(root):
    path = os.path.join(root, roles.LIMITATIONS_SOURCE)
    if not os.path.exists(path):
        return []
    with open(path, encoding='utf-8') as fh:
        return [int(m.group(1)) for m in map(roles._LIM_LINE.match, fh) if m]


def main(argv=None):
    ap = argparse.ArgumentParser(prog='python -m fortref')
    sub = ap.add_subparsers(dest='command', required=True)
    c = sub.add_parser('check', help='resolve every reference in the docs')
    c.add_argument('docsdir')
    c.add_argument('--repo', help='repository root (default: the docs directory\'s parent)')
    c.add_argument('-v', '--verbose', action='store_true', help='print every resolution')
    args = ap.parse_args(argv)
    problems = check(args.docsdir, args.repo, args.verbose)
    return 1 if problems else 0
