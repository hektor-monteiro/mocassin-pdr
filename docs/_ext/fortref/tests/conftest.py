import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
EXT = os.path.abspath(os.path.join(HERE, '..', '..'))
REPO = os.path.abspath(os.path.join(EXT, '..', '..'))
if EXT not in sys.path:
    sys.path.insert(0, EXT)

import pytest  # noqa: E402

GIT_ENV = {
    'GIT_AUTHOR_NAME': 'fortref test', 'GIT_AUTHOR_EMAIL': 'test@example.invalid',
    'GIT_COMMITTER_NAME': 'fortref test', 'GIT_COMMITTER_EMAIL': 'test@example.invalid',
    'GIT_CONFIG_NOSYSTEM': '1',
}


@pytest.fixture
def hermetic_git(tmp_path, monkeypatch):
    """git with no user or system configuration, and a helper to run it."""
    home = tmp_path / 'home'
    home.mkdir()
    monkeypatch.setenv('HOME', str(home))
    monkeypatch.setenv('GIT_CONFIG_GLOBAL', str(home / '.gitconfig'))
    monkeypatch.delenv('READTHEDOCS_GIT_COMMIT_HASH', raising=False)
    for key, value in GIT_ENV.items():
        monkeypatch.setenv(key, value)

    def git(cwd, *args):
        out = subprocess.run(['git', *args], cwd=cwd, capture_output=True, text=True)
        assert out.returncode == 0, out.stderr
        return out.stdout.strip()
    return git
