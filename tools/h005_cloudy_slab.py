#!/usr/bin/env python3
"""H-005: writes the Cloudy inputs of the self-shielding reference (runs/ is not
tracked): a PDR slab at constant T = 100 K, n_H = 1e4 cm-3, 100 Habing, to
A_V = 3 with the large H2 model, and then the same slab stopped at the zones
where N(H2) reaches 1e15, 1e17, 1e19 and 1e20 cm-2.

    python tools/h005_cloudy_slab.py slab <dir>     writes <dir>/slab.in; run cloudy.exe -r slab there (~5 min)
    python tools/h005_cloudy_slab.py cuts <dir>     after that: writes <dir>_N15 ... _N20/cut.in (~1 min each)

"set save resolution 1e-6 absorption" takes the line absorption out of the
saved transmitted continuum, which is then the dust- and continuum-attenuated
field the pump rates use.
"""
import os
import sys

import numpy as np

HEAD = """title H2 self-shielding slab (H-005): T=100 K, log n_H=4, FUV = 1e2 Habing
black 30000
intensity -0.7959 range 0.4412 to 1 Ryd
extinguish 24 0
cosmic rays, background
abundances ism
hden 4
database h2
iterate 2
constant temperature 100K
stop temperature off
set save resolution 1e-6 absorption
"""
SPECIES = """e-
H
H+
H2
H2*
H-
H2+
H3+
He
He+
end
"""


def slab(d):
    os.makedirs(d, exist_ok=True)
    s = HEAD + 'stop AV 3\n'
    s += 'save last overview "slab.ovr"\nsave last dr "slab.dr"\nsave last continuum units Ryd every 5 "slab.con"\n'
    s += 'save last species densities "slab.dens"\n' + SPECIES
    s += ('save last H2 populations zone "slab.pops"\nsave last H2 rates "slab.rates"\n'
          'save last H2 column density "slab.h2col"\nsave last H2 solomon "slab.sol"\n'
          'save last line optical depths units Ryd "slab.tau" -3\nsave last grain H2rates "slab.gh2"\n'
          'save last grain extinction "slab.ext"\nsave last optical depths "slab.cont_tau"\n')
    open(os.path.join(d, 'slab.in'), 'w').write(s)


def cuts(d):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import h005_compare as h5
    cs = h5.cloudy_slab(d)
    nz = min(cs['nz'], len(cs['col']['H2']))
    nH2 = cs['col']['H2'][:nz] + cs['col']['H2*'][:nz]
    Nin = np.concatenate([[0.], np.cumsum(nH2*cs['dr'][:nz])[:-1]])
    for tag, m in (('N15', 1e15), ('N17', 1e17), ('N19', 1e19), ('N20', 1e20)):
        k = int(np.searchsorted(Nin, m)) + 1
        dd = f'{d.rstrip("/")}_{tag}'
        os.makedirs(dd, exist_ok=True)
        s = HEAD + f'stop zone {k}\n'
        s += 'save last overview "cut.ovr"\nsave last continuum units Ryd "cut.con"\n'
        s += 'save last species densities "cut.dens"\n' + SPECIES
        s += ('save H2 populations last "cut.pops"\nsave last H2 populations zone "cut.popz"\n'
              'save last H2 rates "cut.rates"\nsave last H2 column density "cut.h2col"\n'
              'save last line optical depths units Ryd "cut.tau" -4\nsave last grain H2rates "cut.gh2"\n'
              'save last chemistry rates destruction "cut.h2dest" species "H2"\n'
              'save last chemistry rates destruction "cut.h2sdest" species "H2*"\n')
        open(os.path.join(dd, 'cut.in'), 'w').write(s)
        print(tag, 'zone', k)


if __name__ == '__main__':
    {'slab': slab, 'cuts': cuts}[sys.argv[1]](sys.argv[2])
