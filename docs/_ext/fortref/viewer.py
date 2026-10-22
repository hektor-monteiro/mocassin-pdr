"""The site's source viewer: one static page per referenced file, under
_src/<path>.html, each line a <span id="L<n>">, and a few lines of script
that highlight the range a link names (#La-Lb)."""

import hashlib
import html
import os
import re

from pygments import highlight
from pygments.formatters import HtmlFormatter
from pygments.lexers import get_lexer_for_filename
from pygments.lexers.special import TextLexer
from pygments.util import ClassNotFound

VIEWER_VERSION = '1'
LIGHT_STYLE = 'default'
DARK_STYLE = 'github-dark'

_SCRIPT = """
(function () {
  var marked = [];
  function mark() {
    marked.forEach(function (e) { e.classList.remove('hl'); });
    marked = [];
    var m = /^#L(\\d+)(?:-L?(\\d+))?$/.exec(window.location.hash);
    if (!m) return;
    var a = +m[1], b = m[2] ? +m[2] : a;
    if (b < a) { var t = a; a = b; b = t; }
    for (var i = a; i <= b; i++) {
      var e = document.getElementById('L' + i);
      if (e) { e.classList.add('hl'); marked.push(e); }
    }
    var first = document.getElementById('L' + a);
    if (first) first.scrollIntoView({block: 'center'});
  }
  window.addEventListener('hashchange', mark);
  mark();
})();
"""


def _lexer(path):
    name = os.path.basename(path)
    try:
        if name.endswith(('.F90', '.f90', '.F', '.f')):
            return get_lexer_for_filename('x.f90', stripnl=False)
        return get_lexer_for_filename(name, stripnl=False)
    except ClassNotFound:
        return TextLexer(stripnl=False)


def _css():
    light = HtmlFormatter(style=LIGHT_STYLE).get_style_defs('.highlight')
    dark = HtmlFormatter(style=DARK_STYLE).get_style_defs('.highlight')
    return f"""
:root {{ color-scheme: light dark; --bg: #ffffff; --fg: #1f2328; --muted: #6e7781;
        --hl: #fff8c5; --rule: #d0d7de; --badge: #9a6700; }}
@media (prefers-color-scheme: dark) {{
  :root {{ --bg: #0d1117; --fg: #e6edf3; --muted: #8d96a0; --hl: #3b2e00;
          --rule: #30363d; --badge: #d29922; }}
}}
body {{ margin: 0; background: var(--bg); color: var(--fg);
       font: 14px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif; }}
header {{ position: sticky; top: 0; z-index: 1; padding: 8px 16px; background: var(--bg);
         border-bottom: 1px solid var(--rule); display: flex; flex-wrap: wrap; gap: 4px 12px;
         align-items: baseline; }}
header a {{ color: inherit; }}
header code {{ font-weight: 600; overflow-wrap: anywhere; }}
.badge {{ font-size: 12px; color: var(--badge); border: 1px solid var(--badge);
         border-radius: 4px; padding: 0 4px; }}
{light}
@media (prefers-color-scheme: dark) {{
{dark}
}}
.highlight {{ background: var(--bg) !important; }}
.highlight pre {{ margin: 0; padding: 8px 0; overflow-x: auto;
                 font: 13px/1.4 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }}
.highlight pre > span[id] {{ display: block; padding-right: 16px; }}
.highlight pre > span.hl {{ background: var(--hl); }}
a.linenos {{ display: inline-block; min-width: 5ch; padding: 0 12px 0 8px; margin-right: 8px;
            text-align: right; color: var(--muted); text-decoration: none;
            user-select: none; border-right: 1px solid var(--rule); }}
a.linenos:hover {{ color: var(--fg); }}
"""


def render(abspath, relpath, github, home, compiled):
    """The viewer page of one file.  `github`: the file's permalink; `home`:
    the site's index relative to the page."""
    with open(abspath, 'rb') as fh:
        text = fh.read().decode('utf-8', 'surrogateescape')
    text = text.encode('utf-8', 'replace').decode('utf-8')
    lines = text.split('\n')
    if lines and lines[-1] == '' and text.endswith('\n'):
        lines.pop()
    # one physical line per output line, a trailing '\r' kept out of the markup
    code = '\n'.join(ln[:-1] if ln.endswith('\r') else ln for ln in lines) + '\n'
    body = highlight(code, _lexer(relpath),
                     HtmlFormatter(linenos='inline', linespans='L', style=LIGHT_STYLE))
    body = re.sub(r'<span id="L-(\d+)">', r'<span id="L\1">', body)
    body = re.sub(r'<span class="linenos">\s*(\d+)</span>',
                  r'<a class="linenos" href="#L\1">\1</a>', body)
    body = body.replace('\n</span>', '</span>')
    badge = '' if compiled else '<span class="badge" title="outside the Makefile build lists">not compiled</span>'
    title = html.escape(relpath)
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>{title} - MOCASSIN-PDR source</title>
<style>{_css()}</style>
</head>
<body>
<header><a href="{html.escape(home)}">MOCASSIN-PDR</a><code>{title}</code>{badge}
<a href="{html.escape(github)}">GitHub permalink</a></header>
{body}
<script>{_SCRIPT}</script>
</body>
</html>
"""


def write(outdir, root, relpath, github, compiled):
    """Write _src/<relpath>.html under outdir unless an identical one is there."""
    target = os.path.join(outdir, '_src', relpath + '.html')
    depth = relpath.count('/') + 1
    home = '../' * depth + 'index.html'
    abspath = os.path.join(root, relpath)
    with open(abspath, 'rb') as fh:
        digest = hashlib.sha256(fh.read()).hexdigest()
    key = f'<!-- fortref {VIEWER_VERSION} {digest} {github} {int(compiled)} -->\n'
    if os.path.exists(target):
        with open(target, encoding='utf-8', errors='replace') as fh:
            if fh.readline() == key:
                return False
    page = render(abspath, relpath, github, home, compiled)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, 'w', encoding='utf-8') as fh:
        fh.write(key + page)
    return True
