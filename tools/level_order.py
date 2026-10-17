"""Read MOCASSIN atomic data files as hydro_mod.f90 reads them and report
levels whose energies are not in ascending order. For a pair i<j with
E(i) > E(j), emission_mod's equilibrium computes exp(+(E(i)-E(j))*1.4388/T),
which overflows double precision below T = dE*1.4388/709.78 (DEVLOG D-418).

    level_order.py <data directory>
"""
import glob, os, sys
D = sys.argv[1]
def toks(lines):
    for l in lines:
        for t in l.replace(",", " ").split():
            yield t
res = []
for f in sorted(glob.glob(os.path.join(D, "*.dat"))):
    try:
        L = open(f, errors="replace").read().splitlines()
        nc = int(L[0].split()[0]); p = 1 + nc
        nlev, ntemp = map(int, L[p].split()[:2]); p += 1
        p += nlev + ntemp
        irats = int(float(L[p].split()[0])); p += 1
        if irats != 0:
            res.append((f, "iRats=%d (not parsed)" % irats)); continue
        # collision strengths until qx == 0 (third token of a record)
        while True:
            t = L[p].split(); p += 1
            if float(t[2].replace("D", "E")) == 0.0: break
        p += nlev * (nlev - 1) // 2
        e = []; g = []
        for k in range(nlev):
            t = L[p].split(); p += 1
            g.append(float(t[1])); e.append(float(t[2].replace("D", "E")))
        worst = 0.0; pair = None
        for i in range(nlev):
            for j in range(i + 1, nlev):
                if e[i] - e[j] > worst: worst, pair = e[i] - e[j], (i + 1, j + 1)
        if worst > 0:
            res.append((f, "levels %d>%d: dE=%.1f cm-1, overflow below %.2f K; E=%s" %
                        (pair[0], pair[1], worst, worst * 1.4388463 / 709.78, [round(x, 1) for x in e])))
    except Exception as ex:
        res.append((f, "parse failed: %s" % ex))
for f, m in res:
    print(os.path.basename(f), m)
