#!/usr/bin/env python3
"""D-334: does a fixed randomSeed actually make a run repeatable?

Two questions, and they are not the same one:

  1. Are two runs at the SAME seed identical?  If they are not, the seed
     keyword does not do what it claims and nothing else here matters.
  2. Are two runs at DIFFERENT seeds different?  If they are not, the seed is
     being ignored and question 1 passed for free - the D-176..D-181 failure
     mode, a test that cannot move.

Both are needed. Reported as byte identity of the raw output first, because
that is the strongest statement available, then as the largest relative
difference on the physical arrays for the cases that are not identical.

    ~/miniforge3/envs/astro/bin/python tools/d334_seedcheck.py A B C D
"""
import hashlib
import os
import sys

import numpy as np

FILES = ('grid1.out', 'grid2.out', 'grid3.out', 'temperature.out',
         'thermBudget.out', 'lineFlux.out', 'SED.out', 'pdrGrid.out')


def digest(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def _numeric(path):
    """Numeric rows only - these files carry text headers in places."""
    rows = []
    for ln in open(path):
        try:
            rows.append([float(x) for x in ln.split()])
        except ValueError:
            pass
    if not rows:
        raise ValueError('no numeric rows')
    w = max(len(r) for r in rows)
    return np.array([r for r in rows if len(r) == w])


def maxreldiff(pa, pb):
    """Largest relative difference over the numeric columns of two files."""
    try:
        a, b = _numeric(pa), _numeric(pb)
    except Exception:
        return float('nan')
    if a.shape != b.shape:
        return float('inf')
    d = np.abs(a - b)
    s = np.maximum(np.abs(a), np.abs(b))
    ok = s > 0
    return float(d[ok].max() / s[ok].max()) if ok.any() else 0.0


def compare(ra, rb, label):
    same, differ, missing = [], [], []
    for f in FILES:
        pa, pb = os.path.join(ra, 'output', f), os.path.join(rb, 'output', f)
        if not (os.path.exists(pa) and os.path.exists(pb)):
            missing.append(f)
            continue
        (same if digest(pa) == digest(pb) else differ).append(f)
    print('\n=== %s ===' % label)
    print('  %s' % ra)
    print('  %s' % rb)
    print('  identical : %d/%d  %s' % (len(same), len(same) + len(differ),
                                       ' '.join(same) or '-'))
    if differ:
        print('  differing : %s' % ' '.join(differ))
        for f in differ:
            r = maxreldiff(os.path.join(ra, 'output', f),
                           os.path.join(rb, 'output', f))
            print('      %-16s max rel diff %.3e' % (f, r))
    if missing:
        print('  absent    : %s' % ' '.join(missing))
    return len(differ) == 0


def main(a, b, c, d):
    print('D-334 seed check')
    id_same = compare(a, b, 'SAME seed (12345 vs 12345) - must be IDENTICAL')
    id_diff = compare(a, c, 'DIFFERENT seed (12345 vs 999) - must DIFFER')
    compare(a, d, 'seeded vs clock-seeded default - expected to differ')

    print('\n=== verdict ===')
    print('  same seed reproduces      : %s' % ('YES' if id_same else 'NO'))
    print('  different seed changes it : %s' % ('NO - SEED IGNORED' if id_diff
                                                else 'YES'))
    ok = id_same and not id_diff
    print('  seed control works        : %s' % ('YES' if ok else 'NO'))
    return 0 if ok else 1


if __name__ == '__main__':
    r = sys.argv[1:5] or ['A', 'B', 'C', 'D']
    sys.exit(main(*r))
