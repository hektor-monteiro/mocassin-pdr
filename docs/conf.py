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
]

source_suffix = {'.md': 'markdown'}
root_doc = 'index'
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store', '_ext']

myst_enable_extensions = ['dollarmath', 'amsmath', 'colon_fence', 'deflist',
                          'attrs_inline', 'substitution']

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

html_theme = 'furo'
html_title = f'MOCASSIN-PDR {release}'
html_static_path = []

# fortref validates the GitHub blob links itself.
linkcheck_ignore = [r'https://github\.com/.*/blob/']

fortref_github = 'https://github.com/hektor-monteiro/mocassin-pdr'
