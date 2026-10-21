"""The C preprocessor as fortref needs it, and the Makefile reading that gives
it its macros.

Lines are marked active or inactive for a set of macros; nothing is deleted,
so line numbers stay those of the file.  The macros of each profile and the
list of compiled files are read from the Makefile itself, so they follow it
when it changes.
"""

import os
import re
import shlex

# ---------------------------------------------------------------- #if expressions

_TOKEN = re.compile(r"""
    \s*(?:
      (?P<num>0[xX][0-9a-fA-F]+|\d+)[uUlL]*
    | (?P<id>[A-Za-z_]\w*)
    | (?P<op>\|\||&&|==|!=|<=|>=|<<|>>|[-+*/%<>!~()&|^?:,])
    )""", re.X)

# binary operators, loosest first
_BINARY = [
    ('||',), ('&&',), ('|',), ('^',), ('&',), ('==', '!='),
    ('<', '>', '<=', '>='), ('<<', '>>'), ('+', '-'), ('*', '/', '%'),
]


class CppError(ValueError):
    pass


def _tokenize(expr):
    tokens, pos = [], 0
    expr = expr.rstrip()
    while pos < len(expr):
        m = _TOKEN.match(expr, pos)
        if not m or m.end() == pos:
            raise CppError(f'cannot read #if expression at {expr[pos:]!r}')
        pos = m.end()
        if m.group('num') is not None:
            tokens.append(('num', int(m.group('num'), 0)))
        elif m.group('id') is not None:
            tokens.append(('id', m.group('id')))
        else:
            tokens.append(('op', m.group('op')))
    return tokens


def _macro_int(name, macros, depth=0):
    """Value of a macro in an #if: undefined is 0, -DX is 1, and a value that
    is not an integer (a string such as PREFIX) is 0."""
    if name not in macros or depth > 20:
        return 0
    value = str(macros[name]).strip()
    if value == '':
        return 0
    try:
        return int(value, 0)
    except ValueError:
        if re.fullmatch(r'[A-Za-z_]\w*', value):
            return _macro_int(value, macros, depth + 1)
        return 0


class _Parser:
    def __init__(self, tokens, macros):
        self.tokens, self.pos, self.macros = tokens, 0, macros

    def peek(self):
        return self.tokens[self.pos] if self.pos < len(self.tokens) else (None, None)

    def take(self, op=None):
        tok = self.peek()
        if op is not None and tok != ('op', op):
            raise CppError(f'expected {op!r} in #if expression')
        self.pos += 1
        return tok

    def parse(self):
        value = self.ternary()
        if self.pos != len(self.tokens):
            raise CppError('trailing tokens in #if expression')
        return value

    def ternary(self):
        cond = self.binary(0)
        if self.peek() == ('op', '?'):
            self.take('?')
            a = self.ternary()
            self.take(':')
            b = self.ternary()
            return a if cond else b
        return cond

    def binary(self, level):
        if level == len(_BINARY):
            return self.unary()
        left = self.binary(level + 1)
        while True:
            kind, op = self.peek()
            if kind != 'op' or op not in _BINARY[level]:
                return left
            self.take()
            right = self.binary(level + 1)
            left = _apply(op, left, right)

    def unary(self):
        kind, val = self.peek()
        if kind == 'op' and val in ('!', '-', '+', '~'):
            self.take()
            x = self.unary()
            return {'!': int(not x), '-': -x, '+': x, '~': ~x}[val]
        return self.primary()

    def primary(self):
        kind, val = self.take()
        if kind == 'num':
            return val
        if kind == 'id':
            if val == 'defined':
                if self.peek() == ('op', '('):
                    self.take('(')
                    k, name = self.take()
                    self.take(')')
                else:
                    k, name = self.take()
                if k != 'id':
                    raise CppError('defined needs a macro name')
                return int(name in self.macros)
            return _macro_int(val, self.macros)
        if (kind, val) == ('op', '('):
            x = self.ternary()
            self.take(')')
            return x
        raise CppError(f'unexpected {val!r} in #if expression')


def _apply(op, a, b):
    if op == '||':
        return int(bool(a) or bool(b))
    if op == '&&':
        return int(bool(a) and bool(b))
    if op in ('/', '%') and b == 0:
        raise CppError('division by zero in #if expression')
    return {
        '|': lambda: a | b, '^': lambda: a ^ b, '&': lambda: a & b,
        '==': lambda: int(a == b), '!=': lambda: int(a != b),
        '<': lambda: int(a < b), '>': lambda: int(a > b),
        '<=': lambda: int(a <= b), '>=': lambda: int(a >= b),
        '<<': lambda: a << b, '>>': lambda: a >> b,
        '+': lambda: a + b, '-': lambda: a - b, '*': lambda: a * b,
        '/': lambda: int(a / b), '%': lambda: a % b,
    }[op]()


def eval_expr(expr, macros):
    """Value of an #if/#elif expression (an int) under `macros`."""
    return _Parser(_tokenize(expr), macros).parse()


# ---------------------------------------------------------------- line marking

_DIRECTIVE = re.compile(r'^\s*#\s*([A-Za-z_]\w*)?(.*)$')


def _strip_c_comments(text):
    text = re.sub(r'/\*.*?\*/', ' ', text)
    text = re.sub(r'/\*.*$', ' ', text)
    return re.sub(r'//.*$', '', text)


class CppResult:
    """Per-line marks for one file under one macro set (lists indexed from 0).

    active    -- the compiler sees the line (a directive line is active when
                 the group it stands in is active);
    directive -- the line is a preprocessor directive (or its continuation);
    closer    -- for an #if/#ifdef/#ifndef line, the index of its #endif;
    sibling   -- for an #if-family/#elif/#else line, the index of the next
                 #elif/#else/#endif of the same group;
    errors    -- [(line number, message)].
    """

    def __init__(self, n):
        self.active = [True] * n
        self.directive = [False] * n
        self.closer = {}
        self.sibling = {}
        self.errors = []


def evaluate(lines, macros):
    """Mark `lines` (without line terminators) active/inactive under `macros`
    (a dict name -> value).  #define/#undef in active code update the table."""
    macros = dict(macros)
    res = CppResult(len(lines))
    # each frame: [enclosing active, a branch taken, this branch active,
    #              opening line, last branch line]
    stack = []
    active = True
    i = 0
    while i < len(lines):
        line = lines[i]
        m = _DIRECTIVE.match(line)
        if not m:
            res.active[i] = active
            i += 1
            continue
        # a directive, with its backslash continuations
        first = i
        body = line
        while body.endswith('\\') and i + 1 < len(lines):
            i += 1
            res.directive[i] = True
            res.active[i] = active
            body = body[:-1] + lines[i]
        m = _DIRECTIVE.match(body)
        name = (m.group(1) or '').lower()
        rest = _strip_c_comments(m.group(2)).strip()
        res.directive[first] = True
        lineno = first + 1
        if name in ('if', 'ifdef', 'ifndef'):
            res.active[first] = active
            if not active:
                cond = False
            elif name == 'ifdef':
                cond = rest.split()[0] in macros if rest.split() else False
            elif name == 'ifndef':
                cond = rest.split()[0] not in macros if rest.split() else True
            else:
                try:
                    cond = bool(eval_expr(rest, macros))
                except CppError as err:
                    res.errors.append((lineno, str(err)))
                    cond = False
            stack.append([active, cond, cond, first, first])
            active = active and cond
        elif name in ('elif', 'else'):
            if not stack:
                res.errors.append((lineno, f'#{name} without #if'))
                res.active[first] = active
            else:
                frame = stack[-1]
                outer = frame[0]
                res.active[first] = outer
                res.sibling[frame[4]] = first
                frame[4] = first
                if name == 'else':
                    cond = outer and not frame[1]
                elif not outer or frame[1]:
                    cond = False
                else:
                    try:
                        cond = bool(eval_expr(rest, macros))
                    except CppError as err:
                        res.errors.append((lineno, str(err)))
                        cond = False
                frame[1] = frame[1] or cond
                frame[2] = cond
                active = outer and cond
        elif name == 'endif':
            if not stack:
                res.errors.append((lineno, '#endif without #if'))
                res.active[first] = active
            else:
                frame = stack.pop()
                res.active[first] = frame[0]
                res.sibling[frame[4]] = first
                res.closer[frame[3]] = first
                active = frame[0]
        else:
            res.active[first] = active
            if active and name == 'define':
                parts = rest.split(None, 1)
                if parts:
                    key = re.match(r'[A-Za-z_]\w*', parts[0])
                    if key:
                        macros[key.group(0)] = parts[1] if len(parts) > 1 else ''
            elif active and name == 'undef':
                macros.pop(rest.split()[0] if rest.split() else '', None)
        i += 1
    for frame in stack:
        res.errors.append((frame[3] + 1, 'unterminated #if'))
    return res


# ---------------------------------------------------------------- the Makefile

# What `make` is given on its command line for each profile
# (the 3D, 1D and plain flavours of CLAUDE.md's build list).
PROFILE_VARIABLES = {
    '3d': {'PDR': '1', 'PDRGEOM': '3D'},
    '1d': {'PDR': '1'},
    'plain': {},
}
PROFILES = tuple(PROFILE_VARIABLES)

# The Makefile lists whose objects make up the build.
COMPILED_LISTS = ('SOURCES', 'PDR_MODULES', 'PDR_CODE', 'PDR_C', 'PDR_PRE')
SOURCE_SUFFIXES = ('.f90', '.F90', '.c', '.f', '.F')

_ASSIGN = re.compile(
    r'^(?:override\s+|export\s+)?([A-Za-z_][A-Za-z0-9_.-]*)\s*(\+=|::=|:=|\?=|!=|=)\s*(.*)$')
_COND = re.compile(r'^(ifeq|ifneq|ifdef|ifndef)\b\s*(.*)$')


def _logical_lines(text):
    """Makefile lines with backslash continuations joined and comments cut."""
    out, buf = [], ''
    for raw in text.split('\n'):
        raw = raw.rstrip('\r')
        if buf:
            raw = raw.lstrip()
        if raw.endswith('\\') and not raw.endswith('\\\\'):
            buf += raw[:-1] + ' '
            continue
        line = buf + raw
        buf = ''
        out.append(line)
    if buf:
        out.append(buf)
    result = []
    for line in out:
        if line.startswith('\t'):
            result.append(('recipe', line))
            continue
        result.append(('line', re.sub(r'(?<!\\)#.*$', '', line).rstrip()))
    return result


def _expand(value, table, depth=0):
    if depth > 30:
        return value

    def ref(m):
        inner = m.group(1) or m.group(2) or m.group(3)
        if ' ' in inner.strip() or ',' in inner:
            return ''          # a make function ($(shell ...) etc.): not evaluated
        return _expand(table.get(inner.strip(), ''), table, depth + 1)
    return re.sub(r'\$\(([^()]*(?:\([^()]*\)[^()]*)*)\)|\$\{([^{}]*)\}|\$([A-Za-z0-9_])',
                  ref, value)


def _condition(kind, arg, table):
    if kind in ('ifdef', 'ifndef'):
        defined = _expand(table.get(arg.strip(), ''), table) != ''
        return defined if kind == 'ifdef' else not defined
    arg = arg.strip()
    if arg.startswith('('):
        depth, cut = 0, None
        for k, ch in enumerate(arg):
            if ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
            elif ch == ',' and depth == 1 and cut is None:
                cut = k
        a, b = arg[1:cut], arg[cut + 1:arg.rfind(')')]
    else:
        parts = re.findall(r'"([^"]*)"|\'([^\']*)\'', arg)
        a, b = (p[0] or p[1] for p in parts[:2])
    same = _expand(a.strip(), table) == _expand(b.strip(), table)
    return same if kind == 'ifeq' else not same


def read_makefile(path, variables):
    """Evaluate the Makefile's variable assignments and conditionals as make
    would with `variables` on its command line.  Rules and recipes are
    skipped and make functions such as $(shell ...) expand to nothing.
    Returns the raw (unexpanded) variable table."""
    with open(path, encoding='utf-8', errors='surrogateescape') as fh:
        text = fh.read()
    table = dict(variables)
    fixed = set(variables)
    stack = []      # [enclosing active, branch taken, this branch active]
    active = True
    for kind, line in _logical_lines(text):
        if kind == 'recipe':
            continue
        s = line.strip()
        if not s:
            continue
        m = _COND.match(s)
        if m:
            cond = active and _condition(m.group(1), m.group(2), table)
            stack.append([active, cond, cond])
            active = cond
            continue
        if s == 'else' or s.startswith('else '):
            if not stack:
                continue
            frame = stack[-1]
            rest = s[4:].strip()
            m = _COND.match(rest) if rest else None
            if frame[1] or not frame[0]:
                cond = False
            elif m:
                cond = _condition(m.group(1), m.group(2), table)
            else:
                cond = True
            frame[1] = frame[1] or cond
            frame[2] = cond
            active = frame[0] and cond
            continue
        if s == 'endif':
            if stack:
                active = stack.pop()[0]
            continue
        if not active:
            continue
        m = _ASSIGN.match(s)
        if not m:
            continue
        name, op, value = m.groups()
        if name in fixed:
            continue
        if op == '+=':
            table[name] = (table.get(name, '') + ' ' + value).strip()
        elif op == '?=':
            table.setdefault(name, value)
        elif op in (':=', '::='):
            table[name] = _expand(value, table)
        elif op == '=':
            table[name] = value
    return table


def expand(table, name):
    """The expanded value of a Makefile variable."""
    return _expand(table.get(name, ''), table)


def _dflags(words):
    macros = {}
    for word in words:
        if word.startswith('-D') and len(word) > 2:
            key, _, value = word[2:].partition('=')
            macros[key] = value if '=' in word else '1'
    return macros


def _split(value):
    try:
        return shlex.split(value)
    except ValueError:
        return value.split()


def profile_macros(makefile):
    """{profile: {macro: value}}: the -D flags of FFLAGS and PDRFLAGS as the
    Makefile sets them for each profile's command line."""
    out = {}
    for profile, variables in PROFILE_VARIABLES.items():
        table = read_makefile(makefile, variables)
        words = _split(expand(table, 'FFLAGS')) + _split(expand(table, 'PDRFLAGS'))
        out[profile] = _dflags(words)
    return out


def compiled_files(makefile, repo):
    """Repo-relative paths of the sources whose objects are in the Makefile's
    build lists (COMPILED_LISTS), over every profile."""
    found = set()
    for variables in PROFILE_VARIABLES.values():
        table = read_makefile(makefile, variables)
        for name in COMPILED_LISTS:
            for word in expand(table, name).split():
                if not word.endswith('.o'):
                    continue
                stem = word[:-2]
                for suffix in SOURCE_SUFFIXES:
                    if os.path.isfile(os.path.join(repo, stem + suffix)):
                        found.add(stem + suffix)
                        break
    return found
