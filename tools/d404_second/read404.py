#!/usr/bin/env python3
"""D-404: read a run's [D404] lines (the second solve of ionBalance) beside its [D402] lines.

usage: read404.py <run dir> [<base run dir>]

Prints, per iteration and for the cells outside the ionized zone (x(H+) < 0.5), the per cent of
cells whose solver X+/X is more than 10% (and more than 2x) from MOCASSIN's: after the first solve
([D402]), after a second solve on the same iteration's terms (pass 2, the model put back), and
what the control moved. Then the written model at the last iteration, with the second solve kept
in the first's place. With a base run, checks that every per-iteration line that depends on the
model's state is identical in the two.

Runs of the first version of the kept pass (runs/d404-hii31, d404-pn41: a third solve from the
damped state) print a "before the damping" line as well; it is read if present.
"""
import re, sys

EL = re.compile(r'(\w+) n\s*(\d+) >10%\s*([\d.]+) >2x\s*([\d.]+) max\s*([\d.]+)')

def rd(run):
    return open(run.rstrip('/') + '/run.log', errors='replace').read().splitlines()

def parse(lines):
    out = {}
    for l in lines:
        if '[D402] iteration' in l and 'solver X+/X' in l:
            it = int(l.split('iteration')[1].split()[0])
            zone = 'ion' if 'ionized cells' in l else 'oth'
            out[('d402', 'first', zone, it)] = EL.findall(l)
        elif '[D404] iteration' in l:
            it = int(l.split('iteration')[1].split()[0])
            if 'control' in l: ps = 'control'
            elif "second solve, this iteration's terms" in l: ps = 'second'
            elif 'before the damping' in l: ps = 'kept'
            elif 'as written' in l: ps = 'written'
            else: ps = None
            if "model's T" in l:
                m = re.search(r'ionized cells: n\s*(\d+) >1%\s*([\d.]+) >10%\s*([\d.]+)\s+other cells: n\s*(\d+) >1%\s*([\d.]+) >10%\s*([\d.]+)', l)
                out[('te', it)] = m.groups()
                continue
            if 'n_e moved' in l:
                m = re.search(r'ionized cells: n\s*(\d+) >10%\s*([\d.]+) >2x\s*([\d.]+)\s+other cells: n\s*(\d+) >10%\s*([\d.]+) >2x\s*([\d.]+)', l)
                f = re.search(r'balance not reached in\s*(\d+)', l)
                k = re.search(r'second solve kept in\s*(\d+) cells, not in\s*(\d+)', l)
                out[('ne', ps, it)] = m.groups() + ((f.group(1),) if f else (None,)) + (k.groups() if k else (None, None))
                continue
            if 'before it' in l: k = 'before'
            elif 'after it' in l: k = 'after'
            elif 'moved' in l: k = 'moved'
            else: continue
            zone = 'ion' if 'ionized cells' in l else 'oth'
            out[(ps, k, zone, it)] = EL.findall(l)
    return out

def fmt(v, what=2):
    return '  '.join('%-2s %5s' % (e[0], e[what]) for e in v)

def main():
    run = sys.argv[1]
    L = rd(run)
    P = parse(L)
    its = sorted({k[3] for k in P if k[0] == 'second'})
    print('=== %s' % run)
    for l in L:
        if 'total run time' in l: print('   ', l.strip())
    for zone, name in (('oth', 'cells outside the ionized zone'), ('ion', 'ionized cells')):
        print('-- %s: per cent of cells with solver X+/X more than 10%% from MOCASSIN\'s (n = %s)' % (
            name, P[('d402', 'first', zone, its[-1])][0][1] if its else '?'))
        for it in its:
            a = P.get(('d402', 'first', zone, it)); b = P.get(('second', 'after', zone, it))
            c = P.get(('control', 'moved', zone, it)); chk = P.get(('second', 'before', zone, it))
            same = '' if (a and chk and [x[2:] for x in a] == [x[2:] for x in chk]) else '   (pass 2 "before" differs from [D402]!)'
            print('  it %2d  first  %s%s' % (it, fmt(a), same))
            print('         second %s     >2x: %s -> %s' % (fmt(b), ' '.join(x[3] for x in a), ' '.join(x[3] for x in b)))
            print('         control moved >10%%: %s   max dex %s' % (' '.join(x[2] for x in c), ' '.join(x[4] for x in c)))
    print('-- second solve: n_e moved >10% (other cells), balance not reached, by iteration')
    for it in its:
        n = P.get(('ne', 'second', it)); c = P.get(('ne', 'control', it))
        print('  it %2d  n_e >10%% %s  >2x %s   not reached %s   (control: n_e >10%% %s, not reached %s)' % (
            it, n[4], n[5], n[6], c[4], c[6]))
    kit = sorted({k[3] for k in P if k[0] == 'written' and k[1] == 'after'})
    for it in kit:
        print('-- last iteration (%d): the written model, cells outside the ionized zone' % it)
        if ('kept', 'after', 'oth', it) in P:
            print('  solver vs third solve, before the damping  >10%%: %s' % fmt(P[('kept', 'after', 'oth', it)]))
            print('                                             >2x : %s' % fmt(P[('kept', 'after', 'oth', it)], 3))
        print('  solver vs written model, without the pass  >10%%: %s' % fmt(P[('written', 'before', 'oth', it)]))
        print('  solver vs written model, with the pass     >10%%: %s' % fmt(P[('written', 'after', 'oth', it)]))
        print('                           without / with    >2x : %s / %s' % (
            ' '.join(x[3] for x in P[('written', 'before', 'oth', it)]), ' '.join(x[3] for x in P[('written', 'after', 'oth', it)])))
        print('  the written X+/X moved by the pass         >10%%: %s' % fmt(P[('written', 'moved', 'oth', it)]))
        print('                                             >2x : %s' % fmt(P[('written', 'moved', 'oth', it)], 3))
        print('  ionized cells, written X+/X moved          >10%%: %s' % fmt(P[('written', 'moved', 'ion', it)]))
        if ('ne', 'written', it) in P:
            n = P[('ne', 'written', it)]
            print('  n_e moved >10%%: ionized %s, other %s; second solve kept in %s cells, not in %s' % (n[1], n[4], n[7], n[8]))
        else:
            n = P[('ne', 'kept', it)]
            print('  n_e moved >10%%: ionized %s, other %s; third solve: balance not reached in %s cells' % (n[1], n[4], n[6]))
        t = P[('te', it)]
        print('  written T vs solved T: ionized cells n %s >1%% %s >10%% %s;  other cells n %s >1%% %s >10%% %s' % t)
    if len(sys.argv) > 2:
        B = rd(sys.argv[2])
        print('-- path against %s' % sys.argv[2])
        for pat in (r'\[D402\] iteration', r'\[D354\]', r'\[D362\]', r'Summary\] Iteration.*(converged|packets)',
                    r'\[D220\]', r'balance not reached|not reached'):
            la = [l.rstrip() for l in B if re.search(pat, l) and '[D404]' not in l]
            lb = [l.rstrip() for l in L if re.search(pat, l) and '[D404]' not in l]
            n = min(len(la), len(lb))
            st = 'identical' if la == lb else ('first %d identical' % n if la[:n] == lb[:n] else 'DIFFER')
            print('  %-45s base %3d  run %3d  %s' % (pat, len(la), len(lb), st))
            if st == 'DIFFER':
                for x, y in zip(la, lb):
                    if x != y:
                        print('     base:', x[:170]); print('     run :', y[:170]); break

if __name__ == '__main__':
    main()
