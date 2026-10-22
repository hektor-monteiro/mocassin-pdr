"""The link-SHA policy and the dirty check, on temporary git repositories."""

import pytest

from fortref import resolve

REF = ['source/a.f90']


@pytest.fixture
def work(tmp_path, hermetic_git, monkeypatch):
    git = hermetic_git
    remote = tmp_path / 'remote.git'
    git(tmp_path, 'init', '-q', '--bare', '-b', 'main', str(remote))
    work = tmp_path / 'work'
    git(tmp_path, 'init', '-q', '-b', 'main', str(work))
    (work / 'source').mkdir()
    (work / 'source' / 'a.f90').write_text('module a\nend module a\n')
    (work / 'notes.md').write_text('one\n')
    commit(git, work, monkeypatch, 'one', 1)
    git(work, 'remote', 'add', 'origin', str(remote))
    git(work, 'push', '-q', 'origin', 'main')
    return work


def commit(git, work, monkeypatch, message, t):
    monkeypatch.setenv('GIT_COMMITTER_DATE', f'2026-10-0{t}T12:00:00')
    monkeypatch.setenv('GIT_AUTHOR_DATE', f'2026-10-0{t}T12:00:00')
    git(work, 'add', '-A')
    git(work, 'commit', '-q', '-m', message)
    return git(work, 'rev-parse', 'HEAD')


def test_head_on_a_remote(work, hermetic_git):
    head = hermetic_git(work, 'rev-parse', 'HEAD')
    assert resolve.link_sha(str(work), REF) == (head, 'head', [])


def test_merge_base_when_only_other_paths_changed(work, hermetic_git, monkeypatch):
    pushed = hermetic_git(work, 'rev-parse', 'HEAD')
    (work / 'notes.md').write_text('two\n')
    commit(hermetic_git, work, monkeypatch, 'two', 2)
    assert resolve.link_sha(str(work), REF) == (pushed, 'merge-base', [])


def test_newest_merge_base_wins(work, hermetic_git, monkeypatch):
    git = hermetic_git
    git(work, 'push', '-q', 'origin', 'main:old')
    (work / 'notes.md').write_text('two\n')
    second = commit(git, work, monkeypatch, 'two', 2)
    git(work, 'push', '-q', 'origin', 'main')
    (work / 'notes.md').write_text('three\n')
    commit(git, work, monkeypatch, 'three', 3)
    assert resolve.link_sha(str(work), REF) == (second, 'merge-base', [])


def test_unpushed_when_a_referenced_path_changed(work, hermetic_git, monkeypatch):
    (work / 'source' / 'a.f90').write_text('module a\n  ! changed\nend module a\n')
    head = commit(hermetic_git, work, monkeypatch, 'two', 2)
    sha, how, warnings = resolve.link_sha(str(work), REF)
    assert (sha, how) == (head, 'unpushed') and warnings[0][0] == 'unpushed'


def test_working_tree_counts(work, hermetic_git, monkeypatch):
    (work / 'notes.md').write_text('two\n')
    commit(hermetic_git, work, monkeypatch, 'two', 2)
    (work / 'source' / 'a.f90').write_text('module a\n  ! uncommitted\nend module a\n')
    assert resolve.link_sha(str(work), REF)[1] == 'unpushed'
    assert resolve.link_sha(str(work), [])[1] == 'merge-base'


def test_untracked_referenced_path(work, hermetic_git, monkeypatch):
    (work / 'notes.md').write_text('two\n')
    commit(hermetic_git, work, monkeypatch, 'two', 2)
    (work / 'source' / 'new.f90').write_text('module n\nend module n\n')
    sha, how, warnings = resolve.link_sha(str(work), REF + ['source/new.f90'])
    assert how == 'unpushed' and 'untracked: source/new.f90' in warnings[0][1]


def test_read_the_docs_commit(work):
    env = {'READTHEDOCS_GIT_COMMIT_HASH': '0123abcd'}
    assert resolve.link_sha(str(work), REF, environ=env) == ('0123abcd', 'rtd', [])


def test_not_a_checkout(tmp_path, hermetic_git):
    sha, how, warnings = resolve.link_sha(str(tmp_path), REF)
    assert (sha, how) == ('HEAD', 'none') and warnings[0][0] == 'unpushed'


def test_dirty(work):
    assert resolve.dirty(str(work)) == []
    (work / 'source' / 'untracked.f90').write_text('x\n')
    (work / 'notes.md').write_text('outside the checked paths\n')
    assert resolve.dirty(str(work)) == []
    (work / 'source' / 'a.f90').write_text('module a\n  ! edited\nend module a\n')
    (subtype, message), = resolve.dirty(str(work))
    assert subtype == 'dirty' and 'source/a.f90' in message
