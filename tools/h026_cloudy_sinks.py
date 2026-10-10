"""H-026: what destroys Cloudy's H2 (H2 + H2*) through the transition, from its saved destruction rates.
    python tools/h026_cloudy_sinks.py hii|pn [<Cloudy prefix>]
Net sinks of the pair only: reactions whose products still hold an H2 or H2* are left out."""
import sys
import numpy as np
PROD = '/home/hmonteiro/software/mocassin_HM_2026_3DPDR'
fx = sys.argv[1]
REF = sys.argv[2] if len(sys.argv) > 2 else PROD + ('/runs/d396-cloudy-hii/hiipdr' if fx == 'hii' else '/runs/d396-cloudy-pn/150k')
AVS = (0.9, 1.0, 1.05, 1.1, 1.2, 1.3, 1.5, 2.0) if fx == 'hii' else (0.20, 0.23, 0.26, 0.30, 0.34, 0.38, 0.46, 0.58, 0.66)


def table(p):
    h = open(p).readline().lstrip('#').rstrip('\n').split('\t')
    return [x.strip() for x in h], np.loadtxt(p, comments='#', delimiter='\t', ndmin=2)


ho, o = table(REF + '.ovr')
h3, d3 = table(REF + '.dens389')
H2C = d3[:, h3.index('H2')] + d3[:, h3.index('H2*')]
av = o[:, ho.index('AV(point)')]
rate = {}
for ext in ('.H2de', '.H2sde'):
    h, t = table(REF + ext)
    assert len(t) == len(av)
    for i, name in enumerate(h[1:], 1):
        if not name:
            continue
        lhs, rhs = name.split('=>')
        prod = rhs.split(',')
        if 'H2' in prod or 'H2*' in prod:
            continue          # an exchange between H2 and H2*, or a collider that survives
        rate[name] = rate.get(name, 0) + t[:, i]
tot = sum(rate.values())
phot = sum(v for k, v in rate.items() if k.startswith('PHOTON,H2') and ('=>H,H' in k or '=>PHOTON,H,H' in k))
print(fx, REF)
print('   A_V   n(H2+H2*)  total sink/H2  photodissociation/H2  share   then the largest other sinks (share)')
for a in AVS:
    j = np.argmin(np.abs(av - a))
    oth = sorted(((v[j] / tot[j], k) for k, v in rate.items() if not (k.startswith('PHOTON,H2') and ('=>H,H' in k or '=>PHOTON,H,H' in k))), reverse=True)[:4]
    print('  %5.2f  %9.2e  %10.2e  %10.2e  %6.3f   %s' % (av[j], H2C[j], tot[j] / H2C[j], phot[j] / H2C[j], phot[j] / tot[j],
                                                         '; '.join('%s %.3f' % (k, f) for f, k in oth)))
