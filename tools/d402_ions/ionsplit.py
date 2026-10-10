"""Solver's own X+/X against the re-imposed (MOCASSIN's) in the sampled cells of
pdrReacRates.out, for every linked element, with x_e.
Usage: python3 ionsplit.py <run dir>"""
import sys, os, numpy as np
run = sys.argv[1]
L = open(os.path.join(run, 'output', 'pdrReacRates.out')).read().split('\n')
h = L[0].split(); nspec = int(h[h.index('nspec')+1]); nreac = int(h[h.index('nreac')+1])
sp = L[2].split()[2:]
assert len(sp) == nspec
rows = []
for l in L[3:]:
    t = l.split()
    if len(t) < 6 + 2*nspec + nreac: continue
    rows.append([float(x) for x in t])
a = np.array(rows); a = a[np.argsort(a[:, 2])]
xs = a[:, 6:6+nspec]; xi = a[:, 6+nspec:6+2*nspec]
i = {s: k for k, s in enumerate(sp)}
print('# %s  iteration %s  %d sampled cells' % (run.rstrip('/').split('/')[-1], h[h.index('iteration')+1], len(a)))
print('# A_V    T      2x(H2)   | solver X+/X over MOCASSIN X+/X:  H        He       C        O        Mg     | x(H+) sol  moc     x(C+)/C_at sol  moc    x_e sol    moc')
for r in range(len(a)):
    o = []
    for el, ion in (('H', 'H+'), ('He', 'He+'), ('C', 'C+'), ('O', 'O+'), ('Mg', 'Mg+')):
        s0, s1, m0, m1 = xs[r, i[el]], xs[r, i[ion]], xi[r, i[el]], xi[r, i[ion]]
        o.append((s1/s0)/(m1/m0) if min(s0, s1, m0, m1) > 0 else np.nan)
    cs = xs[r, i['C+']]/(xs[r, i['C+']]+xs[r, i['C']]); cm = xi[r, i['C+']]/(xi[r, i['C+']]+xi[r, i['C']])
    print('%6.3f %7.1f %9.2e | %8.3g %8.3g %8.3g %8.3g %8.3g | %9.2e %9.2e  %7.4f %7.4f  %9.2e %9.2e' % (
        a[r, 2], a[r, 4], 2*xs[r, i['H2']], *o, xs[r, i['H+']], xi[r, i['H+']], cs, cm, xs[r, i['e-']], xi[r, i['e-']]))
