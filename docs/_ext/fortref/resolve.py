"""References to the code: their grammar, their resolution to line ranges,
and the commit the GitHub links point at.

Grammar::

    path[::scope][@"text"[+N | ..@"endtext"][#k]][ [profile]]

  path     tried as source/<path> first, then repo-relative;
  scope    a case-insensitive suffix of the unit chain (updateCell/thermBalance);
  "text"   a whitespace-collapsed substring of one active line ('\\"' is a
           quote, '\\\\' a backslash);
  +N       the extent is the matched line and the N lines after it;
  ..@"end" the extent runs to the first active line after the match that
           contains "end";
  #k       take the k-th match of "text" (1-based) when it matches more than once;
  profile  3d (default), 1d or plain: the cpp macros the file is read under.
"""

import difflib
import os
import re
import subprocess
from dataclasses import dataclass

from . import cpp, parser

DEFAULT_MAX_LINES = 60
DIRTY_PATHS = ('source', 'Makefile', 'dataPDR')


# ---------------------------------------------------------------- grammar

class RefSyntaxError(ValueError):
    pass


@dataclass
class Ref:
    raw: str
    path: str
    scope: str = None
    text: str = None
    plus: int = None
    endtext: str = None
    k: int = None
    profile: str = '3d'


def _quoted(s, pos):
    if pos >= len(s) or s[pos] != '"':
        raise RefSyntaxError(f'expected a quoted string at {s[pos:]!r}')
    out, k = [], pos + 1
    while k < len(s):
        ch = s[k]
        if ch == '\\' and k + 1 < len(s) and s[k + 1] in '"\\':
            out.append(s[k + 1])
            k += 2
            continue
        if ch == '"':
            return ''.join(out), k + 1
        out.append(ch)
        k += 1
    raise RefSyntaxError('unterminated quoted string')


def parse_ref(raw, default_profile='3d'):
    s = raw.strip()
    profile = default_profile
    m = re.search(r'\s\[([A-Za-z0-9]+)\]$', s)
    if m:
        profile = m.group(1).lower()
        s = s[:m.start()].rstrip()
    if profile not in cpp.PROFILES:
        raise RefSyntaxError(f'unknown profile {profile!r} (one of {", ".join(cpp.PROFILES)})')
    m = re.match(r'[^\s:@\[\]"]+', s)
    if not m:
        raise RefSyntaxError(f'no path in {raw!r}')
    ref = Ref(raw=raw.strip(), path=m.group(0), profile=profile)
    pos = m.end()
    if s.startswith('::', pos):
        m = re.compile(r'[A-Za-z_]\w*(?:/[A-Za-z_]\w*)*').match(s, pos + 2)
        if not m:
            raise RefSyntaxError(f'bad scope at {s[pos:]!r}')
        ref.scope = m.group(0)
        pos = m.end()
    if s.startswith('@', pos):
        ref.text, pos = _quoted(s, pos + 1)
        if not parser.collapse(ref.text):
            raise RefSyntaxError('empty text anchor')
        if s.startswith('+', pos):
            m = re.compile(r'\+(\d+)').match(s, pos)
            if not m:
                raise RefSyntaxError(f'bad +N at {s[pos:]!r}')
            ref.plus = int(m.group(1))
            pos = m.end()
        elif s.startswith('..@', pos):
            ref.endtext, pos = _quoted(s, pos + 3)
            if not parser.collapse(ref.endtext):
                raise RefSyntaxError('empty end text')
        if s.startswith('#', pos):
            m = re.compile(r'#(\d+)').match(s, pos)
            if not m or int(m.group(1)) < 1:
                raise RefSyntaxError(f'bad #k at {s[pos:]!r}')
            ref.k = int(m.group(1))
            pos = m.end()
    if pos != len(s):
        raise RefSyntaxError(f'cannot read {s[pos:]!r} in {raw!r}')
    return ref


# ---------------------------------------------------------------- resolution

@dataclass
class Resolution:
    ref: Ref
    path: str               # repo-relative
    abspath: str
    language: str
    start: int = None       # None: the whole file
    end: int = None
    unit: parser.Unit = None
    compiled: bool = False
    auto: bool = False      # the extent was chosen by the extent rules
    model: parser.Model = None

    @property
    def nlines(self):
        return 0 if self.start is None else self.end - self.start + 1

    @property
    def location(self):
        """The file and lines a role shows by default, e.g. pdr_mod.f90:5064–5089:
        the path under source/ (repo-relative otherwise), then the lines."""
        rel = self.path[len('source/'):] if self.path.startswith('source/') else self.path
        if self.start is None:
            return rel
        if self.end is None or self.end == self.start:
            return f'{rel}:{self.start}'
        return f'{rel}:{self.start}\u2013{self.end}'

    @property
    def display(self):
        """The name a role shows: the scope's last part, else the unit the
        anchor falls in, else the file name."""
        if self.ref.scope:
            return self.ref.scope.split('/')[-1] if self.unit is None else self.unit.name
        if self.unit is not None and self.ref.text:
            return self.unit.name
        return os.path.basename(self.path)


class Repo:
    """The repository the references resolve against, with its caches."""

    _instances = {}

    @classmethod
    def at(cls, root):
        root = os.path.realpath(root)
        if root not in cls._instances:
            cls._instances[root] = cls(root)
        return cls._instances[root]

    def __init__(self, root):
        self.root = os.path.realpath(root)
        self.makefile = os.path.join(self.root, 'Makefile')
        self._macros = None
        self._compiled = None
        self._models = {}       # (path, sha256, profile) -> Model
        self._shas = {}         # (abspath, mtime_ns, size) -> (lines, sha256)

    @property
    def macros(self):
        if self._macros is None:
            self._macros = cpp.profile_macros(self.makefile)
        return self._macros

    @property
    def compiled(self):
        if self._compiled is None:
            self._compiled = cpp.compiled_files(self.makefile, self.root)
        return self._compiled

    def locate(self, path):
        """The repo-relative path that `path` names, or None."""
        if os.path.isabs(path) or '..' in path.split('/'):
            return None
        for cand in ('source/' + path, path):
            if os.path.isfile(os.path.join(self.root, cand)):
                return cand
        return None

    def read(self, relpath):
        abspath = os.path.join(self.root, relpath)
        st = os.stat(abspath)
        key = (abspath, st.st_mtime_ns, st.st_size)
        if key not in self._shas:
            self._shas[key] = parser.read_lines(abspath)
        return self._shas[key]

    def model(self, relpath, profile):
        lines, sha = self.read(relpath)
        key = (relpath, sha, profile)
        if key not in self._models:
            self._models[key] = parser.build_from_lines(relpath, lines, sha, profile,
                                                        self.macros[profile])
        return self._models[key]

    # ------------------------------------------------------------ resolve

    def resolve(self, ref, max_lines=DEFAULT_MAX_LINES, allow_long=False):
        """(Resolution or None, [(subtype, message)])."""
        if isinstance(ref, str):
            try:
                ref = parse_ref(ref)
            except RefSyntaxError as err:
                return None, [('parse', str(err))]
        warnings = []
        rel = self.locate(ref.path)
        if rel is None:
            return None, [('file', f'no file source/{ref.path} or {ref.path} in the repository')]
        model = self.model(rel, ref.profile)
        res = Resolution(ref, rel, os.path.join(self.root, rel), model.language,
                         compiled=rel in self.compiled, model=model)
        bad = [e for e in model.errors if e[2] in ('unit', 'cpp', 'c')]
        if bad:
            warnings.append(('parse', f'{rel} [{ref.profile}] does not parse cleanly: ' +
                             '; '.join(f'line {n}: {msg}' for n, msg, _ in bad[:3])))
        lo, hi = 1, model.nlines
        if ref.scope:
            if model.language == 'text':
                return None, warnings + [('scope', f'{rel} has no program units; '
                                                   f'a scope needs a Fortran or C file')]
            unit, w = self._find_unit(model, ref)
            if unit is None:
                return None, warnings + [w]
            res.unit = unit
            lo, hi = unit.start, unit.end
            res.start, res.end = lo, hi
        if ref.text is None:
            return res, warnings
        hits = text_hits(model, ref.text, lo, hi)
        if not hits:
            return None, warnings + [('text', f'"{ref.text}" is on no active line of '
                                              f'{_where(rel, ref)}' + suggest(model, ref.text, lo, hi))]
        if ref.k is not None:
            if ref.k > len(hits):
                return None, warnings + [('text', f'"{ref.text}"#{ref.k}: only {len(hits)} '
                                                  f'match(es) in {_where(rel, ref)}')]
            a = hits[ref.k - 1]
        elif len(hits) > 1:
            return None, warnings + [('text-ambiguous', f'"{ref.text}" matches {len(hits)} lines of '
                                                        f'{_where(rel, ref)}: ' +
                                      ', '.join(f'L{n}' for n in hits[:12]) +
                                      (' ...' if len(hits) > 12 else '') + ' (add #k)')]
        else:
            a = hits[0]
        if ref.plus is not None:
            b = a + ref.plus
        elif ref.endtext is not None:
            ends = [n for n in text_hits(model, ref.endtext, a + 1, hi)]
            if not ends:
                return None, warnings + [('text', f'end text "{ref.endtext}" is on no active line '
                                                  f'after L{a} in {_where(rel, ref)}')]
            b = ends[0]
        else:
            a, b = auto_extent(model, a)
            res.auto = True
        inner = model.innermost(a) if model.units else None
        top, bottom = (inner.start, inner.end) if inner else (1, model.nlines)
        a, b = max(a, top), min(b, bottom)
        res.start, res.end = a, b
        if inner is not None:
            res.unit = inner
        if res.auto and not allow_long and res.nlines > max_lines:
            warnings.append(('long-extent', f'the extent L{a}-L{b} is {res.nlines} lines '
                                            f'(over {max_lines}); narrow it with +N or ..@"end"'))
        return res, warnings

    def _find_unit(self, model, ref):
        want = [c.lower() for c in ref.scope.split('/')]
        found = [u for u in model.units
                 if len(u.chain) >= len(want) and
                 [c.lower() for c in u.chain[-len(want):]] == want]
        if len(found) == 1:
            return found[0], None
        if len(found) > 1:
            return None, ('ambiguous', f'{ref.scope} matches {len(found)} units in {model.path} '
                                       f'[{ref.profile}]: ' +
                          ', '.join(f'{u.qualname} (L{u.start}-L{u.end})' for u in found))
        msg = f'no unit {ref.scope} in {model.path} [{ref.profile}]'
        other = [p for p in cpp.PROFILES if p != ref.profile
                 and any([c.lower() for c in u.chain[-len(want):]] == want
                         for u in self.model(model.path, p).units)]
        if other:
            msg += f' (it is defined under profile {", ".join(other)})'
        declared = [ln for name, ln in model.declarations if name.lower() == want[-1]]
        if declared:
            msg += (f'; {model.path} declares it in an interface block at L{declared[0]}, '
                    f'which is not a definition')
        names = {u.name.lower(): u.qualname for u in model.units}
        close = difflib.get_close_matches(want[-1], list(names), n=3, cutoff=0.7)
        if close:
            msg += '; did you mean ' + ', '.join(names[c] for c in close) + '?'
        return None, ('scope', msg)


def _where(rel, ref):
    return f'{rel}' + (f'::{ref.scope}' if ref.scope else '') + f' [{ref.profile}]'


def text_hits(model, text, lo, hi):
    """Active lines in lo..hi holding `text`, whitespace collapsed."""
    needle = parser.collapse(text)
    return [n for n in range(lo, hi + 1)
            if model.active[n - 1] and needle in parser.collapse(model.lines[n - 1])]


def suggest(model, text, lo, hi):
    """'; ...' hint for a text anchor that matched nothing: the inactive lines
    that hold it under this profile, else the closest active lines."""
    needle = parser.collapse(text)
    inactive = [n for n in range(lo, hi + 1)
                if not model.active[n - 1] and needle in parser.collapse(model.lines[n - 1])]
    if inactive:
        return (f'; it is on inactive line(s) ' + ', '.join(f'L{n}' for n in inactive[:5]) +
                f' under profile {model.profile}')
    scored = []
    for n in range(lo, hi + 1):
        if not model.active[n - 1]:
            continue
        line = parser.collapse(model.lines[n - 1])
        if not line:
            continue
        sm = difflib.SequenceMatcher(None, needle, line, autojunk=False)
        score = sum(b.size for b in sm.get_matching_blocks()) / len(needle)
        if score >= 0.6:
            scored.append((score, n, line))
    if not scored:
        return ''
    scored.sort(key=lambda t: (-t[0], t[1]))
    return '; closest: ' + '; '.join(f'L{n}: {line[:80]!r}' for _, n, line in scored[:3])


# ---------------------------------------------------------------- extents

def _trim(model, a, b):
    while b > a and (model.is_blank(b) or model.is_comment(b)):
        b -= 1
    return b


def _paragraph(model, a, last):
    """From a to the line before the first blank line after `last`."""
    n = last + 1
    while n <= model.nlines and not model.is_blank(n):
        n += 1
    return a, n - 1


def auto_extent(model, a):
    """The extent rules for an anchor matched on line a.

      a comment block      -> the block, then the next statement;
      a construct opener   -> to its closer;
      a case/else          -> to its next sibling;
      a unit header        -> the whole unit;
      anything else        -> to the next blank line.
    cpp conditionals are constructs too (#if.. to #endif, #elif/#else to the
    next branch).
    """
    if model.directive[a - 1]:
        i = a - 1
        if i in model.cpp_closer:
            return a, model.cpp_closer[i] + 1
        if i in model.cpp_sibling:
            return a, _trim(model, a, model.cpp_sibling[i])
        return _paragraph(model, a, a)
    if model.language == 'text':
        return _paragraph(model, a, a)
    if model.is_comment(a):
        s, e = a, a
        while s > 1 and model.active[s - 2] and model.is_comment(s - 1):
            s -= 1
        while e < model.nlines and model.active[e] and model.is_comment(e + 1):
            e += 1
        nxt = _next_code_line(model, e)
        return s, (nxt if nxt else e)
    if model.language == 'c':
        for u in model.units:
            body = min((ln for ln in model.braces if u.start <= ln <= u.end), default=u.start)
            if u.start <= a <= body:
                return u.start, u.end
        if a in model.braces:
            return a, model.braces[a]
        return _paragraph(model, a, a)
    idxs = model.line_stmts.get(a)
    if not idxs:
        return _paragraph(model, a, a)
    idx = idxs[0]
    st = model.stmts[idx]
    for u in model.units:
        if u.header == idx:
            return u.start, u.end
    if idx in model.closer:
        return st.first, model.stmts[model.closer[idx]].last
    if idx in model.sibling:
        nxt = model.stmts[model.sibling[idx]]
        return st.first, _trim(model, st.first, max(nxt.first - 1, st.last))
    return _paragraph(model, st.first, st.last)


def _next_code_line(model, e):
    """The last line of the next statement after line e (C: the next code line)."""
    if model.language == 'fortran':
        for st in model.stmts:
            if st.first > e:
                return st.last
        return None
    for n in range(e + 1, model.nlines + 1):
        if model.active[n - 1] and not model.is_blank(n) and not model.is_comment(n):
            return n
    return None


# ---------------------------------------------------------------- links

def github_url(base, sha, path, start=None, end=None):
    url = f'{base.rstrip("/")}/blob/{sha}/{path}'
    if path.endswith('.md'):
        url += '?plain=1'
    if start is not None:
        url += f'#L{start}' + (f'-L{end}' if end is not None and end != start else '')
    return url


def _git(repo, *args):
    try:
        out = subprocess.run(['git', '-C', repo, *args], capture_output=True, text=True,
                             timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return 1, ''
    return out.returncode, out.stdout.rstrip()


def link_sha(repo, paths, environ=None):
    """The commit the GitHub links name: (sha, how, [(subtype, message)]).

    On Read the Docs, READTHEDOCS_GIT_COMMIT_HASH.  Locally, HEAD when a
    remote branch contains it; otherwise the newest merge-base of HEAD with a
    remote branch at which every referenced path is as in the working tree;
    otherwise HEAD, with an `unpushed` warning.
    """
    environ = os.environ if environ is None else environ
    rtd = environ.get('READTHEDOCS_GIT_COMMIT_HASH', '').strip()
    if rtd:
        return rtd, 'rtd', []
    rc, head = _git(repo, 'rev-parse', 'HEAD')
    if rc != 0 or not head:
        return 'HEAD', 'none', [('unpushed', f'{repo} is not a git checkout; links name HEAD')]
    paths = sorted(set(paths))
    rc, out = _git(repo, 'branch', '-r', '--contains', head)
    if rc == 0 and out.strip():
        return head, 'head', []
    rc, refs = _git(repo, 'for-each-ref', '--format=%(refname)', 'refs/remotes')
    bases = set()
    for ref in refs.split():
        if ref.endswith('/HEAD'):
            continue
        rc, mb = _git(repo, 'merge-base', 'HEAD', ref)
        if rc == 0 and mb:
            bases.add(mb)
    dated = []
    for mb in bases:
        rc, ct = _git(repo, 'log', '-1', '--format=%ct', mb)
        dated.append((int(ct) if rc == 0 and ct.isdigit() else 0, mb))
    untracked = []
    if paths:
        rc, tracked = _git(repo, 'ls-files', '--', *paths)
        tracked = set(tracked.split('\n')) if rc == 0 else set()
        untracked = [p for p in paths if p not in tracked]
    if not untracked:
        for _, mb in sorted(dated, reverse=True):
            rc, _ = _git(repo, 'diff', '--quiet', mb, '--', *paths) if paths else (0, '')
            if rc == 0:
                return mb, 'merge-base', []
    why = (f'untracked: {", ".join(untracked[:5])}' if untracked else
           'no remote merge-base has the referenced paths as they are here')
    return head, 'unpushed', [('unpushed', f'HEAD {head[:10]} is on no remote branch and {why}; '
                                           f'GitHub links name a commit GitHub does not have')]


def dirty(repo, paths=DIRTY_PATHS):
    """[(subtype, message)]: uncommitted changes to tracked files under paths."""
    rc, out = _git(repo, 'status', '--porcelain', '--untracked-files=no', '--', *paths)
    if rc == 0 and out.strip():
        files = [ln[3:] for ln in out.split('\n') if ln.strip()]
        return [('dirty', f'uncommitted changes under {", ".join(paths)}: ' +
                 ', '.join(files[:8]) + (' ...' if len(files) > 8 else '') +
                 '; line numbers come from the working tree, links from a commit')]
    return []


# ---------------------------------------------------------------- scanning pages

ROLE_NAMES = ('src', 'lim', 'devlog')
_FENCE = re.compile(r'^(\s*)(`{3,}|~{3,}|:{3,})(.*)$')


def _roles_in_line(line):
    """[(role, content, column)] for MyST roles on one line, skipping code spans."""
    out, k = [], 0
    while k < len(line):
        if line[k] != '`':
            k += 1
            continue
        j = k
        while j < len(line) and line[j] == '`':
            j += 1
        ticks = line[k:j]
        close = re.compile(r'(?<!`)' + ticks + r'(?!`)').search(line, j)
        if not close:
            k = j
            continue
        m = re.search(r'\{([A-Za-z][\w:-]*)\}$', line[:k])
        if m:
            out.append((m.group(1), line[j:close.start()], m.start()))
        k = close.end()
    return out


def scan_markdown(text):
    """References in a MyST page: [(kind, content, line, options)], kind
    'src', 'lim', 'devlog' or 'fortran-block'.  Code fences that are not
    directives are skipped."""
    found = []
    lines = text.split('\n')
    fence = None
    i = 0
    while i < len(lines):
        line = lines[i]
        m = _FENCE.match(line)
        if fence is not None:
            if m and m.group(2)[0] == fence[0] and len(m.group(2)) >= len(fence) \
                    and not m.group(3).strip():
                fence = None
            i += 1
            continue
        if m:
            info = m.group(3).strip()
            if info.startswith('{'):
                d = re.match(r'\{([\w-]+)\}\s*(.*)$', info)
                if d and d.group(1) == 'fortran-block':
                    opts = {}
                    j = i + 1
                    while j < len(lines):
                        o = re.match(r'^\s*:([\w-]+):\s*(.*)$', lines[j])
                        if not o:
                            break
                        opts[o.group(1)] = o.group(2).strip()
                        j += 1
                    found.append(('fortran-block', d.group(2).strip(), i + 1, opts))
                i += 1
                continue
            if m.group(2)[0] != ':':
                fence = m.group(2)
            i += 1
            continue
        for role, content, _ in _roles_in_line(line):
            if role in ROLE_NAMES:
                found.append((role, content, i + 1, {}))
        i += 1
    return found


def split_title(content):
    """'title <ref>' -> (title, ref); 'ref' -> (None, ref)."""
    m = re.match(r'^(.*?\S)\s+<(.+)>\s*$', content, re.S)
    if m:
        return m.group(1).strip(), m.group(2).strip()
    return None, content.strip()
