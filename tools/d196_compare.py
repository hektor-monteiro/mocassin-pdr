#!/usr/bin/env python3
"""D-196: extract the per-iteration D-196 blocks from two run logs and put them
side by side.

The pair differs only in `ionChemRates` - whether elemAvail stands down where
the chemistry supplied per-stage rates (D-118). The question it answers is
D-191's: at D-190, could x(H0) - the quantity the convergence test measures -
move at all?

Usage:  d196_compare.py <runA.log> <runB.log> [labelA labelB]
"""
import re
import sys

FLOAT = r'[-+0-9.Ee]+'

PATTERNS = {
    'cells':   re.compile(r'PDR-zone cells\s+(\d+),\s+x\(H0\) > 0\.99 in\s+(\d+)\s+\(\s*(' + FLOAT + r')\s*%\)'),
    'xh0':     re.compile(r'x\(H0\)\s+min\s+(' + FLOAT + r')\s+median\s+(' + FLOAT + r')\s+max\s+(' + FLOAT + r')'),
    'dx':      re.compile(r'\|dx\(H0\)\|/x median\s+(' + FLOAT + r')\s+p90\s+(' + FLOAT + r')\s+max\s+(' + FLOAT + r')'),
    'clamp':   re.compile(r'clamp\)\s*(\d+)\s+clamped,\s*(\d+)\s+with x\(H0\) exactly 0'),
    'h2':      re.compile(r'mean 2x\(H2\)\s+(' + FLOAT + r')\s+mean elemAvail\(H\)\s+(' + FLOAT + r')'),
    'ratio':   re.compile(r'x\(H\+\)_ion / x\(H\+\)_chem\s+median\s+(' + FLOAT + r')\s+p90\s+(' + FLOAT + r')\s+max\s+(' + FLOAT + r')'),
}
CONV = re.compile(r'Iteration\s+(\d+)\s*;\s*Total:\s*(' + FLOAT + r')\s*% converged')


def parse(path):
    """Return {iteration: {...}}. D-196 blocks precede the convergence summary
    for the same iteration, so a block is attributed to the next one seen."""
    out, cur = {}, {}
    with open(path, errors='replace') as fh:
        for line in fh:
            if '[D196]' in line:
                for key, pat in PATTERNS.items():
                    m = pat.search(line)
                    if m:
                        cur[key] = m.groups()
                        break
            else:
                m = CONV.search(line)
                if m:
                    it = int(m.group(1))
                    if cur:
                        cur['conv'] = (m.group(2),)
                        out[it] = cur
                        cur = {}
    return out


def cell(rec, key, idx, width=11):
    if rec is None or key not in rec:
        return '-'.rjust(width)
    try:
        return f'{float(rec[key][idx]):.4g}'.rjust(width)
    except (ValueError, IndexError):
        return str(rec[key][idx]).rjust(width)


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    a, b = parse(sys.argv[1]), parse(sys.argv[2])
    la = sys.argv[3] if len(sys.argv) > 3 else 'A ionChemRates 1'
    lb = sys.argv[4] if len(sys.argv) > 4 else 'B ionChemRates 0'

    rows = [
        ('x(H0) median',            'xh0',   1),
        ('x(H0) min',               'xh0',   0),
        ('cells x(H0)>0.99  [%]',   'cells', 2),
        ('|dx(H0)|/x median',       'dx',    0),
        ('|dx(H0)|/x p90',          'dx',    1),
        ('mean 2x(H2)',             'h2',    0),
        ('mean elemAvail(H)',       'h2',    1),
        ('x(H+)_ion/chem median',   'ratio', 0),
        ('x(H+)_ion/chem p90',      'ratio', 1),
        ('cells clamped',           'clamp', 0),
        ('cells x(H0) == 0',        'clamp', 1),
        ('converged [%]',           'conv',  0),
    ]

    iters = sorted(set(a) | set(b))
    if not iters:
        sys.exit('no D-196 blocks found in either log')

    print(f'\n  A = {la}\n  B = {lb}\n')
    head = 'quantity'.ljust(24) + ''.join(f'  it{i:<2d} A   it{i:<2d} B ' for i in iters)
    print(head)
    print('-' * len(head))
    for label, key, idx in rows:
        line = label.ljust(24)
        for i in iters:
            line += '  ' + cell(a.get(i), key, idx, 9) + ' ' + cell(b.get(i), key, idx, 9)
        print(line)
    print()
    print('  x(H+)_ion/chem is the decisive number: 1.0 means the ionBalance')
    print('  conservation row normalised to the available (non-molecular)')
    print('  fraction; 1/(1-2x(H2)) means it normalised to unity.')
    print()
    print('  Measured chain when it normalises to unity (D-196, run A):')
    print('    x(H+) over-stated ~99x  ->  1 - x(H+) - 2x(H2) < 0  ->  the')
    print('    D-192 handback clamps x(H0) to exactly 0  ->  x(H0) cannot')
    print('    move  ->  the convergence test passes for free. NOT the D-191')
    print('    guess of x(H0) pinned just under 1; it is pinned at zero.')


if __name__ == '__main__':
    main()
