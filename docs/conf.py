# Sphinx configuration for the MOCASSIN-PDR documentation.
# Build: sphinx-build -W --keep-going -b html docs docs/_build/html

import os
import subprocess
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '_ext'))

project = 'MOCASSIN-PDR'


def _short_head():
    """The commit being built: Read the Docs says so; locally, git rev-parse
    (never git describe: Read the Docs clones shallowly)."""
    sha = os.environ.get('READTHEDOCS_GIT_COMMIT_HASH', '').strip()
    if sha:
        return sha[:7]
    try:
        return subprocess.run(['git', 'rev-parse', '--short', 'HEAD'], capture_output=True,
                              text=True, cwd=os.path.dirname(os.path.abspath(__file__)),
                              check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return 'unknown'


_sha = _short_head()
_rtd_version = os.environ.get('READTHEDOCS_VERSION_NAME', '').strip()
version = _rtd_version or _sha
release = f'{_rtd_version} ({_sha})' if _rtd_version else _sha

extensions = [
    'myst_parser',
    'sphinx.ext.mathjax',
    'sphinx_copybutton',
    'sphinx_design',
    'sphinxcontrib.bibtex',
    'fortref',
    'mocdocs',      # the keyword, output, build, code-map and changelog pages
]

source_suffix = {'.md': 'markdown'}
root_doc = 'index'
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store', '_ext', 'bench',
                    'benchmarks/_*.md']  # fragments, included by their pages

myst_enable_extensions = ['dollarmath', 'amsmath', 'colon_fence', 'deflist',
                          'attrs_inline', 'substitution']

# Tables, figures and equations are numbered; {numref} and {eq} use the numbers.
numfig = True
math_numfig = True

# The report's macros (doc/h2-radiation-molecules/main.tex), for MathJax.
mathjax3_config = {
    'tex': {
        'macros': {
            'AV': r'A_{V}',
            'Jste': r'J^{\mathrm{ste}}',
            'Jdif': r'J^{\mathrm{dif}}',
            'chiD': r'\chi_{\mathrm{dir}}',
            'chiF': r'\chi_{\mathrm{dif}}',
            'uD': r'u_{\mathrm{D}}',
            'RFUV': r'R_{\mathrm{FUV}}',
            'Htwo': r'\mathrm{H}_{2}',
            'Hp': r'\mathrm{H}^{+}',
            'Cp': r'\mathrm{C}^{+}',
            'dd': r'\mathrm{d}',
            'unit': [r'\,\mathrm{#1}', 1],
            'dlog': [r'\textsf{#1}', 1],
        },
    },
}

bibtex_bibfiles = ['../doc/h2-radiation-molecules/references.bib']
bibtex_default_style = 'plain'
bibtex_reference_style = 'author_year'

# Fortran with cpp lines (fortran-block also sets force on its own blocks).
highlight_options = {'force': True}

html_theme = 'sphinx_rtd_theme'
html_title = f'MOCASSIN-PDR {release}'
html_static_path = ['_static']
html_css_files = ['custom.css']
html_theme_options = {
    'navigation_depth': 4,
    'collapse_navigation': False,
    'sticky_navigation': True,
    'titles_only': False,
    'prev_next_buttons_location': 'bottom',
}

# fortref validates the GitHub blob links itself.
linkcheck_ignore = [r'https://github\.com/.*/blob/']

fortref_github = 'https://github.com/hektor-monteiro/mocassin-pdr'


# ------------------------------------------------------------- benchmarks
# The benchmark figures are drawn from the committed reduced data
# (docs/bench/data/, written locally by docs/bench/reduce.py) every time the
# site is built: Read the Docs cannot run MOCASSIN, but it can plot.
def _draw_benchmark_figures(app):
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, 'benchmarks', '_generated')
    subprocess.run([sys.executable, os.path.join(here, 'bench', 'plots.py'), out], check=True)


def setup(app):
    app.connect('builder-inited', _draw_benchmark_figures)
