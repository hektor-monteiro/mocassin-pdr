#!/usr/bin/env python3
"""D-405 (L-49): the damping across iterations, read from run logs.

    readdamp.py <run> [<run> ...]

Prints, per iteration and per run, what the log already says about whether
the model moves: the model-integrated test, the share of cells converged,
branch crossings, how far H2, x(H0) and the molecular fraction moved, the
two solvers' agreement and the hydrogen budget. Nothing here needs code that
the damped runs did not have.

The step sizes of [D196] and [D202] are measured on the model as written,
that is after the damping: a damped run's are (1 - iterDamp) of what its
solves moved by. The column 'x1/(1-d)' undoes that, for the comparison.
"""
import re
import sys

F = r'([-+]?\d+\.\d*(?:[eE][-+]?\d+)?|[-+]?\d+)'


def read(run):
    it = {}
    cur = None
    damp = None
    lines = open(run.rstrip('/') + '/run.log', errors='replace').read().split('\n')
    for l in lines:
        m = re.search(r'\[D404\] iteration\s+\d+\s+the model\'s T \(damped, iterDamp\s+' + F, l)
        if m:
            damp = float(m.group(1))
        m = re.search(r'\[D376\] iteration\s+(\d+):', l)
        if m:
            cur = it.setdefault(int(m.group(1)), {})
            continue
        m = re.search(r'\[Summary\] Iteration\s+(\d+)\s*;\s*(.*)', l)
        if m:
            d = it.setdefault(int(m.group(1)), {})
            t = m.group(2)
            mm = re.match(F + r'\s*% converged cells in grid', t)
            if mm:
                d['conv'] = float(mm.group(1))
            mm = re.match(F + r'\s*% Te balance not reached', t)
            if mm:
                d['tenot'] = float(mm.group(1))
            mm = re.match(F + r'\s*% Ion balance not reached', t)
            if mm:
                d['ionnot'] = float(mm.group(1))
            mm = re.search(r'largest change over the last 3 iterations\s+' + F + r'% \((.*?)\)', t)
            if mm:
                d['tot'] = float(mm.group(1))
                d['totq'] = mm.group(2)
            mm = re.search(r'ionized \(x\(H\+\) >= 0.5\):\s+' + F + r'% of\s+(\d+); neutral:\s+' + F + r'% of\s+(\d+)', t)
            if mm:
                d['convI'], d['nI'], d['convN'], d['nN'] = float(mm.group(1)), int(mm.group(2)), float(mm.group(3)), int(mm.group(4))
            continue
        if cur is None:
            continue
        m = re.search(r'\[D217\] cold -> hot\s+cells\s+(\d+)', l)
        if m:
            cur['c2h'] = int(m.group(1))
        m = re.search(r'\[D217\] started hot\s+cells\s+(\d+)', l)
        if m:
            cur['hot0'] = int(m.group(1))
        m = re.search(r'\[D202\]\s+\|df_mol\| since iter start\s+median\s+' + F + r'\s+p90\s+' + F + r'\s+max\s+' + F, l)
        if m:
            cur['dfm'] = [float(x) for x in m.groups()]
        m = re.search(r'\[D202\]\s+moved >0.10:\s+(\d+) \(\s*' + F + r'%\)\s+>0.50:\s+(\d+) \(\s*' + F + r'%\)', l)
        if m:
            cur['fm10'], cur['fm50'] = float(m.group(2)), float(m.group(4))
        m = re.search(r'\[D202\]\s+Te > 3000 K:\s+(\d+)', l)
        if m:
            cur['hot'] = int(m.group(1))
        m = re.search(r'\[D202\]\s+Te\s+p10\s+' + F + r'\s+median\s+' + F + r'\s+p90\s+' + F, l)
        if m:
            cur['te'] = [float(x) for x in m.groups()]
        m = re.search(r'\[D204\]\s+mean f_mol at iteration start\s+' + F + r'\s+now\s+' + F, l)
        if m:
            cur['fmol'] = float(m.group(2))
        m = re.search(r'\[D196\]\s+\|dx\(H0\)\|/x median\s+' + F + r'\s+p90\s+' + F + r'\s+max\s+' + F, l)
        if m:
            cur['dx'] = [float(x) for x in m.groups()]
        m = re.search(r'\[D354\] iteration\s+\d+ vs the last:\s+(\S+)\s+cells\s+(\d+)\s+moved >0.1%\s+' + F + r'%\s+>1%\s+' + F + r'%\s+max\s+' + F, l)
        if m:
            cur['m_' + m.group(1)] = (float(m.group(3)), float(m.group(4)), float(m.group(5)))
        m = re.search(r'\[D402\] iteration\s+\d+\s+solver X\+/X vs MOCASSIN\'s, other cells:(.*)', l)
        if m:
            cur['first'] = {e: float(v) for e, v in re.findall(r'(\w+) n\s*\d+ >10%\s+' + F, m.group(1))}
        m = re.search(r'\[D404\] iteration\s+\d+\s+second solve, this iteration\'s terms:\s+solver X\+/X vs MOCASSIN\'s after it, other cells:(.*)', l)
        if m:
            cur['second'] = {e: float(v) for e, v in re.findall(r'(\w+) n\s*\d+ >10%\s+' + F, m.group(1))}
        m = re.search(r'\[D404\] iteration\s+\d+\s+last iteration, the model as written:\s+solver X\+/X vs MOCASSIN\'s after it, other cells:(.*)', l)
        if m:
            cur['written'] = {e: float(v) for e, v in re.findall(r'(\w+) n\s*\d+ >10%\s+' + F, m.group(1))}
        m = re.search(r'\[D220\] rescaled.*off by >1% in\s+(\d+) \(\s*' + F + r'%\)', l)
        if m:
            cur.setdefault('bud', []).append(float(m.group(2)))
    m = [l for l in lines if 'total run time per processor' in l]
    return it, damp, (m[-1].split()[-2] if m else '?')


def g(d, k, i=None, fmt='%6.1f', miss='     -'):
    v = d.get(k)
    if v is None:
        return miss
    if i is not None:
        v = v[i]
    return fmt % v


runs = sys.argv[1:]
R = [(r, ) + read(r) for r in runs]
for r, it, damp, t in R:
    print('%-28s iterDamp %s   iterations %d   run time %s' % (r.rstrip('/').split('/')[-1], 'as printed %.2f' % damp if damp else '0 (no damped-T line)', max(it), t))

print('\n-- the model-integrated test: largest change over the last 3 iterations [%] (quantity); cells converged [%], ionized / neutral')
for i in sorted(set().union(*[set(x[1]) for x in R])):
    s = '  it %2d ' % i
    for r, it, damp, t in R:
        d = it.get(i, {})
        s += ' | %s %-7s conv %s (%s /%s)' % (g(d, 'tot', fmt='%7.3f', miss='      -'), '(' + d.get('totq', '-') + ')', g(d, 'conv', fmt='%3.0f', miss='  -'),
                                             g(d, 'convI', fmt='%5.1f', miss='    -'), g(d, 'convN', fmt='%5.1f', miss='    -'))
    print(s)

print('\n-- branches (3000 K): cells that started cold and ended hot; cells above 3000 K; T balance not reached [% of cells]')
for i in sorted(set().union(*[set(x[1]) for x in R])):
    s = '  it %2d ' % i
    for r, it, damp, t in R:
        d = it.get(i, {})
        s += ' | c->h %s  hot %s  T not reached %s' % (g(d, 'c2h', fmt='%5d', miss='    0'), g(d, 'hot', fmt='%5d', miss='    -'), g(d, 'tenot', fmt='%3.0f', miss='  -'))
    print(s)

print('\n-- steps of the written model: |dx(H0)|/x median, p90;  |df_mol| p90, cells moved >0.10 and >0.50 [%];  median T [K], mean f_mol')
for i in sorted(set().union(*[set(x[1]) for x in R])):
    s = '  it %2d ' % i
    for r, it, damp, t in R:
        d = it.get(i, {})
        s += ' | %s %s  %s %s %s  %s %s' % (g(d, 'dx', 0, '%8.2e', '       -'), g(d, 'dx', 1, '%8.2e', '       -'), g(d, 'dfm', 1, '%6.4f'),
                                           g(d, 'fm10', fmt='%5.2f', miss='    -'), g(d, 'fm50', fmt='%5.2f', miss='    -'), g(d, 'te', 1, '%7.2f', '      -'), g(d, 'fmol', fmt='%6.4f'))
    print(s)

print('\n-- the chemistry\'s own answer against the iteration before: cells in which H2, CO moved by more than 1% [%]')
for i in sorted(set().union(*[set(x[1]) for x in R])):
    s = '  it %2d ' % i
    for r, it, damp, t in R:
        d = it.get(i, {})
        s += ' | H2 %s  CO %s' % (g(d, 'm_H2', 1, '%6.2f'), g(d, 'm_CO', 1, '%6.2f'))
    print(s)

print('\n-- neutral cells with the solver\'s X+/X more than 10% from MOCASSIN\'s [%]: first solve H, O; second solve H, O; hydrogen budget off by >1% before the rescale')
for i in sorted(set().union(*[set(x[1]) for x in R])):
    s = '  it %2d ' % i
    for r, it, damp, t in R:
        d = it.get(i, {})
        f, se = d.get('first', {}), d.get('second', {})
        s += ' | %s %s  %s %s  %s' % (g(f, 'H'), g(f, 'O'), g(se, 'H'), g(se, 'O'), ' '.join('%5.2f' % b for b in d.get('bud', [])) or '    -')
    print(s)

print('\n-- last iteration, the model as written: neutral cells with the solver\'s X+/X more than 10% from the written [%]')
for r, it, damp, t in R:
    w = it[max(it)].get('written', {})
    print('  %-28s ' % r.rstrip('/').split('/')[-1] + '  '.join('%s %5.1f' % (e, v) for e, v in w.items()))
