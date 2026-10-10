"""Prototype of the channel classification: for each linked element and sampled
cell, split the solver's formation and loss of the ion X+ into
  slot  : the first-order ionization slot (MOCASSIN's rate + cosmic rays) and
          the radiative recombinations (MOCASSIN's coefficient)      [D-358]
  hct   : X+ + H <-> X + H+, which MOCASSIN also has (its own chex)
  conv  : any other reaction turning X into X+ or back (network only)
  mol   : X+ made from, or lost to, anything that is not X (network only)
and check the closure  form = loss  in the solver's state.
Usage: python3 chanclass.py <run dir>"""
import sys, os, csv, numpy as np
run = sys.argv[1]
R0 = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'dataPDR', 'rates_reduced.d')
rx = [[c.strip() for c in r] for r in csv.reader(open(R0))]
L = open(os.path.join(run, 'output', 'pdrReacRates.out')).read().split('\n')
h = L[0].split(); nspec = int(h[h.index('nspec')+1]); nreac = int(h[h.index('nreac')+1])
assert nreac == len(rx)
sp = L[2].split()[2:]
a = np.array([[float(x) for x in l.split()] for l in L[3:] if len(l.split()) >= 6+2*nspec+nreac])
a = a[np.argsort(a[:, 2])]
xs = a[:, 6:6+nspec]; xi = a[:, 6+nspec:6+2*nspec]; R = a[:, 6+2*nspec:6+2*nspec+nreac]
ix = {s: k for k, s in enumerate(sp)}
nH = a[:, 3]
print('# %s' % run.rstrip('/').split('/')[-1])
for el, ion in (('H', 'H+'), ('He', 'He+'), ('C', 'C+'), ('O', 'O+'), ('Mg', 'Mg+')):
    cls = {}
    for k, r in enumerate(rx):
        re = [x for x in r[1:4] if x]; pr = [x for x in r[4:8] if x]
        dn = pr.count(el) - re.count(el); di = pr.count(ion) - re.count(ion)
        if di == 0: continue
        if 'CRP' in re or 'CRPHOT' in re:
            c = 'slot'
        elif 'PHOTON' in re and el in re:
            c = 'slot'                       # zeroed in the solve
        elif ion in re and 'e-' in re and el in pr and 'PHOTON' in pr and '#' not in re:
            c = 'slot'
        elif el != 'H' and ((set(re) == {ion, 'H'} and set(pr) == {el, 'H+'}) or (set(re) == {el, 'H+'} and set(pr) == {ion, 'H'})):
            c = 'hct'
        elif dn == -di:
            c = 'conv'
        else:
            c = 'mol'
        cls[k] = (c, di)
    print('--- %s: A_V | solver/MOC ratio | share of X+ formation: slot hct conv mol | share of X+ loss: slot hct conv mol | closure' % ion)
    for j in range(len(a)):
        f = dict(slot=0., hct=0., conv=0., mol=0.); l = dict(slot=0., hct=0., conv=0., mol=0.)
        for k, (c, di) in cls.items():
            if di > 0: f[c] += di*R[j, k]
            else: l[c] += -di*R[j, k]
        ft = sum(f.values()); lt = sum(l.values())
        s0, s1, m0, m1 = xs[j, ix[el]], xs[j, ix[ion]], xi[j, ix[el]], xi[j, ix[ion]]
        rat = (s1/s0)/(m1/m0) if min(s0, s1, m0, m1) > 0 else float('nan')
        if ft <= 0 or lt <= 0: continue
        print('  %6.3f | %9.3g | %5.3f %5.3f %5.3f %5.3f | %5.3f %5.3f %5.3f %5.3f | %7.4f' % (
            a[j, 2], rat, *(f[c]/ft for c in ('slot', 'hct', 'conv', 'mol')), *(l[c]/lt for c in ('slot', 'hct', 'conv', 'mol')), ft/lt))
