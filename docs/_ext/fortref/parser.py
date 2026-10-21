"""Structure of a source file as fortref resolves references against it.

Fortran: statements (continuations joined, comments stripped outside
strings, split on `;`), program units on a scope stack (interface bodies
skipped, a named END must match the unit it closes, a bare END closes the
innermost unit) and the block constructs used by the extent rules.
C: function definitions found by a definition pattern and brace matching.
Anything else (Markdown, inputs): lines only.

Every model is built for one profile's macros; cpp marks lines inactive,
never removes them, so every line number is the file's own.
"""

import hashlib
import re
from dataclasses import dataclass, field

from . import cpp

FORTRAN_SUFFIXES = ('.f90', '.F90', '.f', '.F', '.f95', '.F95')
C_SUFFIXES = ('.c', '.h')


def read_lines(path):
    """The file's lines, read as UTF-8 with surrogateescape and split on '\\n'
    only (a trailing '\\r' stays on its line), and the sha256 of its bytes."""
    with open(path, 'rb') as fh:
        data = fh.read()
    text = data.decode('utf-8', 'surrogateescape')
    lines = text.split('\n')
    if lines and lines[-1] == '' and text.endswith('\n'):
        lines.pop()
    return lines, hashlib.sha256(data).hexdigest()


def _clean(line):
    return line[:-1] if line.endswith('\r') else line


def collapse(text):
    """Whitespace-collapsed form used for text anchors."""
    return ' '.join(text.split())


# ---------------------------------------------------------------- data model

@dataclass
class Stmt:
    text: str           # code, comments stripped, continuations joined
    masked: str         # the same with string contents removed, label and
                        # construct name stripped
    first: int          # first physical line (1-based)
    last: int           # last physical line
    label: str = None


@dataclass
class Unit:
    kind: str           # module, program, subroutine, function, blockdata, submodule
    name: str
    start: int          # header line (1-based)
    end: int = None     # last line of its END statement
    chain: tuple = ()
    header: int = None  # statement index of the header (Fortran)

    @property
    def qualname(self):
        return '/'.join(self.chain)

    @property
    def nlines(self):
        return self.end - self.start + 1


@dataclass
class Model:
    """One file under one profile.  Line lists are indexed from 0; line
    numbers in Stmt/Unit/errors are 1-based."""
    path: str
    language: str       # fortran, c, text
    profile: str
    sha256: str
    lines: list
    active: list
    directive: list
    stmts: list = field(default_factory=list)
    units: list = field(default_factory=list)
    errors: list = field(default_factory=list)      # [(line, message, category)]
    closer: dict = field(default_factory=dict)      # stmt index -> stmt index
    sibling: dict = field(default_factory=dict)     # stmt index -> stmt index
    cpp_closer: dict = field(default_factory=dict)  # line index -> line index
    cpp_sibling: dict = field(default_factory=dict)
    line_stmts: dict = field(default_factory=dict)  # line (1-based) -> [stmt indices]
    declarations: list = field(default_factory=list)  # [(name, line)] of interface bodies
    braces: dict = field(default_factory=dict)      # C: line (1-based) of '{' -> line of its '}'

    @property
    def nlines(self):
        return len(self.lines)

    def is_blank(self, n):
        return _clean(self.lines[n - 1]).strip() == ''

    def is_comment(self, n):
        s = _clean(self.lines[n - 1]).strip()
        if self.language == 'fortran':
            return s.startswith('!')
        if self.language == 'c':
            return s.startswith('//') or s.startswith('/*') or s.startswith('*')
        return False

    def innermost(self, n):
        """The innermost unit whose lines contain line n, or None."""
        best = None
        for u in self.units:
            if u.start <= n <= u.end and (best is None or u.start >= best.start):
                best = u
        return best


# ---------------------------------------------------------------- statements

def _statements(clines, active, directive):
    """Logical statements from the active, non-directive lines."""
    stmts = []
    text, masked = [], []
    first = None
    in_str = None
    cont = False

    def finish(last):
        nonlocal text, masked, first
        t = ''.join(text).strip()
        if t:
            stmts.append(Stmt(t, ''.join(masked).strip(), first, last))
        text, masked, first = [], [], None

    for i, line in enumerate(clines):
        n = i + 1
        if not active[i] or directive[i]:
            continue
        stripped = line.strip()
        if stripped == '' or stripped.startswith('!'):
            continue        # blank and comment lines, also between continuations
        pos = 0
        if cont:
            j = len(line) - len(line.lstrip())
            if j < len(line) and line[j] == '&':
                pos = j + 1
            elif in_str is None:
                pos = j
        k = pos
        line_end_amp = False
        while k < len(line):
            ch = line[k]
            if in_str:
                if ch == in_str:
                    if k + 1 < len(line) and line[k + 1] == in_str:
                        text.append(ch + ch)
                        k += 2
                        continue
                    in_str = None
                    text.append(ch)
                    masked.append(ch)
                elif ch == '&' and line[k + 1:].strip() == '':
                    line_end_amp = True
                    break
                else:
                    text.append(ch)
                k += 1
                continue
            if ch in ('"', "'"):
                in_str = ch
                if first is None:
                    first = n
                text.append(ch)
                masked.append(ch)
            elif ch == '!':
                break
            elif ch == ';':
                finish(n)
            else:
                if first is None and not ch.isspace():
                    first = n
                text.append(ch)
                masked.append(ch)
            k += 1
        if in_str:
            if line_end_amp:
                cont = True
                continue
            in_str = None       # an unterminated string: the statement ends here
            cont = False
            finish(n)
            continue
        # strip a trailing '&' outside strings
        joined = ''.join(text).rstrip()
        if joined.endswith('&'):
            while text and text[-1].isspace():
                text.pop()
            text.pop()
            while masked and masked[-1].isspace():
                masked.pop()
            if masked and masked[-1] == '&':
                masked.pop()
            cont = True
            continue
        cont = False
        finish(n)
    if text:
        finish(len(clines))
    return stmts


_LABEL = re.compile(r'^(\d{1,5})\s+')
_CONSTRUCT_NAME = re.compile(
    r'^[A-Za-z_]\w*\s*:(?!:)\s*(?=(?:do|if|select|where|forall|block|associate|critical)\b)', re.I)


def _normalise(stmt):
    m = _LABEL.match(stmt.masked)
    if m:
        stmt.label = m.group(1)
        stmt.masked = stmt.masked[m.end():]
        stmt.text = _LABEL.sub('', stmt.text, count=1)
    stmt.masked = _CONSTRUCT_NAME.sub('', stmt.masked, count=1)


# ---------------------------------------------------------------- units

_PREFIX = r'(?:recursive|pure|elemental|impure|module|non_recursive)'
_TYPESPEC = (r'(?:(?:integer|real|logical|complex|character|byte|double\s*precision|double\s*complex)'
             r'(?:\s*\*\s*(?:\d+|\(\s*\*\s*\)))?(?:\s*\((?:[^()]|\([^()]*\))*\))?'
             r'|(?:type|class)\s*\(\s*[\w*]+\s*\))')

RE_END_UNIT = re.compile(
    r'^end\s*(subroutine|function|module|program|submodule|block\s*data)\b(?:\s*([A-Za-z_]\w*))?\s*$', re.I)
RE_BARE_END = re.compile(r'^end\s*$', re.I)
RE_MODULE = re.compile(r'^module\s+(?!procedure\b)([A-Za-z_]\w*)\s*$', re.I)
RE_SUBMODULE = re.compile(r'^submodule\s*\([^)]*\)\s*([A-Za-z_]\w*)\s*$', re.I)
RE_PROGRAM = re.compile(r'^program\s+([A-Za-z_]\w*)\s*$', re.I)
RE_BLOCKDATA = re.compile(r'^block\s*data(?:\s+([A-Za-z_]\w*))?\s*$', re.I)
RE_SUBROUTINE = re.compile(rf'^(?:{_PREFIX}\s+)*subroutine\s+([A-Za-z_]\w*)', re.I)
RE_FUNCTION = re.compile(rf'^(?:(?:{_PREFIX}|{_TYPESPEC})\s*)*\bfunction\s+([A-Za-z_]\w*)\s*\(', re.I)
RE_INTERFACE = re.compile(r'^(?:abstract\s+)?interface\b', re.I)
RE_END_INTERFACE = re.compile(r'^end\s*interface\b', re.I)


def unit_header(masked):
    """(kind, name) if the statement opens a program unit, else None."""
    for kind, rx in (('module', RE_MODULE), ('submodule', RE_SUBMODULE),
                     ('program', RE_PROGRAM), ('blockdata', RE_BLOCKDATA),
                     ('subroutine', RE_SUBROUTINE), ('function', RE_FUNCTION)):
        m = rx.match(masked)
        if m:
            return kind, (m.group(1) or '')
    return None


def _units(stmts, errors, declarations):
    units, stack = [], []
    iface = 0
    for idx, st in enumerate(stmts):
        m = st.masked
        if iface:
            if RE_END_INTERFACE.match(m):
                iface -= 1
            elif RE_INTERFACE.match(m):
                iface += 1
            else:
                head = unit_header(m)
                if head and head[0] in ('subroutine', 'function'):
                    declarations.append((head[1], st.first))
            continue
        if RE_INTERFACE.match(m):
            iface += 1
            continue
        if RE_END_INTERFACE.match(m):
            errors.append((st.first, 'END INTERFACE without INTERFACE', 'unit'))
            continue
        em = RE_END_UNIT.match(m)
        if em or RE_BARE_END.match(m):
            if not stack:
                errors.append((st.first, f'{st.text!r} closes no open unit', 'unit'))
                continue
            top = stack[-1]
            if em:
                kind = re.sub(r'\s+', '', em.group(1).lower())
                name = em.group(2)
                if kind != top.kind or (name and name.lower() != top.name.lower()):
                    errors.append((st.first, f'{st.text!r} does not match the open '
                                             f'{top.kind} {top.name} (line {top.start})', 'unit'))
                    continue
            stack.pop()
            top.end = st.last
            continue
        head = unit_header(m)
        if head:
            kind, name = head
            chain = tuple(u.name for u in stack) + (name,)
            u = Unit(kind, name, st.first, None, chain, idx)
            units.append(u)
            stack.append(u)
    for u in stack:
        errors.append((u.start, f'{u.kind} {u.name} is never closed', 'unit'))
        u.end = stmts[-1].last if stmts else u.start
    if iface:
        errors.append((stmts[-1].last if stmts else 1, 'INTERFACE block never closed', 'unit'))
    return units


# ---------------------------------------------------------------- constructs

def _after_parens(s):
    """The text after the parenthesised group that starts at the first '('."""
    k = s.find('(')
    if k < 0:
        return None
    depth = 0
    for j in range(k, len(s)):
        if s[j] == '(':
            depth += 1
        elif s[j] == ')':
            depth -= 1
            if depth == 0:
                return s[j + 1:]
    return None


RE_DO_LABEL = re.compile(r'^do\s*(\d{1,5})\b', re.I)
RE_CLOSER = re.compile(
    r'^end\s*(do|if|select|where|forall|associate|block(?!\s*data)|critical|type|interface|enum)\b', re.I)
RE_SIBLING = re.compile(r'^(?:else(?:\b|where)|case\b|(?:type|class)\s+is\b|class\s+default\b|rank\b)', re.I)
RE_TYPEDEF = re.compile(r'^type\s*(?:,[^:]*)?::\s*\w+|^type\s+(?!is\b)[A-Za-z_]\w*\s*$', re.I)


def construct_kind(masked):
    """The kind of block construct the statement opens, or None."""
    s = masked
    low = s.lower()
    if re.match(r'^do\b', low) and not re.match(r'^do\s*=', low):
        return 'do'
    if re.match(r'^if\s*\(', low):
        rest = _after_parens(s)
        return 'if' if rest is not None and rest.strip().lower() == 'then' else None
    if re.match(r'^select\s*(case|type|rank)\b', low):
        return 'select'
    for kw in ('where', 'forall'):
        if re.match(rf'^{kw}\s*\(', low):
            rest = _after_parens(s)
            return kw if rest is not None and rest.strip() == '' else None
    if re.match(r'^associate\s*\(', low):
        return 'associate'
    if re.match(r'^block\s*$', low):
        return 'block'
    if re.match(r'^critical\b', low):
        return 'critical'
    if RE_TYPEDEF.match(s):
        return 'type'
    if RE_INTERFACE.match(s):
        return 'interface'
    if re.match(r'^enum\b', low):
        return 'enum'
    return None


def _constructs(stmts, units, errors):
    closer, sibling = {}, {}
    boundaries = set()
    for u in units:
        boundaries.add(u.header)
    stack = []      # (kind, stmt index, do label, [sibling stmt indices])

    def close(entry, idx):
        kind, start, label, sibs = entry
        closer[start] = idx
        chain = [start] + sibs
        for a, b in zip(chain, chain[1:] + [idx]):
            sibling[a] = b

    for idx, st in enumerate(stmts):
        m = st.masked
        if stack and stack[-1][0] == 'interface':
            # an interface block holds only declarations: its bodies' END
            # statements close nothing here; nested interfaces are counted
            if RE_END_INTERFACE.match(m):
                entry = stack[-1]
                if entry[2]:
                    stack[-1] = (entry[0], entry[1], entry[2] - 1, entry[3])
                else:
                    close(stack.pop(), idx)
            elif RE_INTERFACE.match(m):
                entry = stack[-1]
                stack[-1] = (entry[0], entry[1], (entry[2] or 0) + 1, entry[3])
            continue
        if idx in boundaries or RE_END_UNIT.match(m) or RE_BARE_END.match(m):
            for entry in stack:
                errors.append((stmts[entry[1]].first,
                               f'{entry[0]} construct not closed before the unit ends', 'construct'))
            stack = []
            continue
        if st.label:
            while stack and stack[-1][0] == 'dolabel' and stack[-1][2] == st.label:
                close(stack.pop(), idx)
        cm = RE_CLOSER.match(m)
        if cm:
            kind = cm.group(1).lower()
            if kind.startswith('block'):
                kind = 'block'
            if stack and stack[-1][0] == kind:
                close(stack.pop(), idx)
            else:
                errors.append((st.first, f'{st.text!r} closes no open {kind} construct', 'construct'))
            continue
        if RE_SIBLING.match(m):
            if stack:
                stack[-1][3].append(idx)
            continue
        dl = RE_DO_LABEL.match(m)
        if dl:
            stack.append(('dolabel', idx, dl.group(1), []))
            continue
        kind = construct_kind(m)
        if kind:
            stack.append((kind, idx, None, []))
    for entry in stack:
        errors.append((stmts[entry[1]].first, f'{entry[0]} construct never closed', 'construct'))
    return closer, sibling


# ---------------------------------------------------------------- C

_C_KEYWORDS = {'if', 'for', 'while', 'switch', 'return', 'sizeof', 'do', 'else'}


def _c_mask(clines, active, directive):
    """Code of each active non-directive line with comments, strings and
    character literals blanked (one string per line)."""
    out = []
    in_comment = False
    for i, line in enumerate(clines):
        if not active[i] or directive[i]:
            out.append('')
            continue
        res = []
        k = 0
        while k < len(line):
            if in_comment:
                end = line.find('*/', k)
                if end < 0:
                    k = len(line)
                    break
                k = end + 2
                in_comment = False
                res.append(' ')
                continue
            ch = line[k]
            if line.startswith('/*', k):
                in_comment = True
                k += 2
                continue
            if line.startswith('//', k):
                break
            if ch in ('"', "'"):
                q = ch
                k += 1
                while k < len(line) and line[k] != q:
                    k += 2 if line[k] == '\\' else 1
                res.append(q + q)
                k += 1
                continue
            res.append(ch)
            k += 1
        out.append(''.join(res))
    return out


def _c_units(clines, active, directive, errors):
    masked = _c_mask(clines, active, directive)
    units, braces = [], {}
    stack = []          # line numbers of the open braces
    current = None      # the function whose body is open, if any
    chunk = []          # [(line, text)] since the last ';' or '}' at file level
    for i, text in enumerate(masked):
        n = i + 1
        for ch in text:
            if ch == '{':
                if not stack:
                    decl = ''.join(t for _, t in chunk)
                    m = re.search(r'([A-Za-z_]\w*)\s*\([^;{}]*\)\s*$', decl, re.S)
                    current = None
                    if m and m.group(1) not in _C_KEYWORDS:
                        start = next((ln for ln, t in chunk if t.strip()), n)
                        current = Unit('function', m.group(1), start, None, (m.group(1),))
                        units.append(current)
                stack.append(n)
                chunk = []
            elif ch == '}':
                if not stack:
                    errors.append((n, "'}' without '{'", 'c'))
                    continue
                braces[stack.pop()] = n
                if not stack:
                    if current is not None:
                        current.end = n
                    current = None
                    chunk = []
            elif not stack:
                if ch == ';':
                    chunk = []
                else:
                    if not chunk or chunk[-1][0] != n:
                        chunk.append((n, ''))
                    chunk[-1] = (n, chunk[-1][1] + ch)
        if not stack and chunk and chunk[-1][0] == n:
            chunk[-1] = (n, chunk[-1][1] + '\n')
    for u in units:
        if u.end is None:
            errors.append((u.start, f'function {u.name} is never closed', 'c'))
            u.end = len(clines)
    for opened in stack:
        errors.append((opened, "'{' never closed", 'c'))
    return units, braces


# ---------------------------------------------------------------- building

def language_of(path):
    if path.endswith(FORTRAN_SUFFIXES):
        return 'fortran'
    if path.endswith(C_SUFFIXES):
        return 'c'
    return 'text'


def build(path, abspath, profile, macros):
    """The Model of one file under one profile (macros: {name: value})."""
    lines, sha = read_lines(abspath)
    return build_from_lines(path, lines, sha, profile, macros)


def build_from_lines(path, lines, sha, profile, macros):
    language = language_of(path)
    clines = [_clean(ln) for ln in lines]
    if language == 'text':
        n = len(lines)
        return Model(path, language, profile, sha, lines, [True] * n, [False] * n)
    pre = cpp.evaluate(clines, macros)
    model = Model(path, language, profile, sha, lines, pre.active, pre.directive,
                  cpp_closer=pre.closer, cpp_sibling=pre.sibling)
    model.errors.extend((n, msg, 'cpp') for n, msg in pre.errors)
    if language == 'c':
        model.units, model.braces = _c_units(clines, pre.active, pre.directive, model.errors)
        return model
    stmts = _statements(clines, pre.active, pre.directive)
    for st in stmts:
        _normalise(st)
    model.stmts = stmts
    model.units = _units(stmts, model.errors, model.declarations)
    model.closer, model.sibling = _constructs(stmts, model.units, model.errors)
    for idx, st in enumerate(stmts):
        for n in range(st.first, st.last + 1):
            model.line_stmts.setdefault(n, []).append(idx)
    return model


def unit_errors(model):
    """Errors of the unit scope stack: a mismatched or stray END, a unit or
    interface block never closed."""
    return [e for e in model.errors if e[2] == 'unit']
