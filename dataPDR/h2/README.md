# H2 data

Copied unmodified from Cloudy c25.00 (`data/h2/`), the data set of its
large H2 model (Shaw et al. 2005, ApJ 624, 794). The original references are
in each file's `#` header lines:

| file | content | source (per the file header) |
|---|---|---|
| energy_X.dat | X-state rovibrational energies | Komasa et al. 2011 (compiled by K. Kaplan 2016) |
| transprob_X.dat | X-state quadrupole A values | Wolniewicz, Simbotin & Dalgarno 1998, ApJS 115, 293 |
| coll_rates_H_15.dat | H + H2 (de-excitation, incl. reactive) | Lique 2015, MNRAS 453, 810 |
| coll_rates_He_ORNL.dat | He + H2 | Lee et al. (ORNL) |
| coll_rates_H2ortho_ORNL.dat | o-H2 + H2 | Wan et al. 2018, ApJ 862, 132 |
| coll_rates_H2para_ORNL.dat | p-H2 + H2 | Wan et al. 2018, ApJ 862, 132 |
| coll_rates_Hp.dat | H+ + H2 | Gerlich 1990, J. Chem. Phys. 92, 2377 |
| energy_{B,C_plus,C_minus,B_primed,D_plus,D_minus}.dat | rovibrational energies of the excited electronic states B, C+, C-, B', D+, D- | Abgrall, Roueff & Drira 2000, A&AS 141, 297 |
| transprob_{same six}.dat | A values of their lines to X | Abgrall, Roueff & Drira 2000 |
| dissprob_{same six}.dat | their dissociation rate [s^-1] and the kinetic energy released [eV] | Abgrall, Roueff & Drira 2000 |
| energy_dissoc.dat | dissociation energies of the electronic states | as given in the file |

Added at H-004 (UV pumping): the last four rows. The reading rule is
Cloudy's: a line starting with `#` is a comment, and a file's data end at the
first empty line. That rule is why only v = 0-2 of D- is used: energy_D_minus.dat
has an empty line before the levels "above the dissociation limit".

These are Cloudy's defaults for the five colliders (`h2.cpp`). Cloudy's
licence (zlib) applies to its distribution:

    Copyright (C) 1978-2025 Gary J. Ferland and others.
    This software is provided 'as-is', without any express or implied
    warranty.  In no event will the author be held liable for any damages
    arising from the use of this software.
    Permission is granted to anyone to use this software for any purpose,
    including commercial applications, and to alter it and redistribute it
    freely, subject to the following restrictions:
    1. The origin of this software must not be misrepresented; you must not
       claim that you wrote the original software. If you use this software
       in a product, an acknowledgment in the product documentation would be
       appreciated but is not required.
    2. Altered source versions must be plainly marked as such, and must not be
       misrepresented as being the original software.
    3. This notice may not be removed or altered from any source distribution.

MOCASSIN-PDR's H2 model (source/h2_mod.f90) is a re-implementation in
Fortran from Cloudy's equations and these data; where it follows a Cloudy
convention (linear interpolation in T held at the table ends, g-bar estimates
for same-spin pairs without data) the code says so. Two of its routines are
translated or adapted from Cloudy's source:
h2ShieldFederman (from shieldFederman, rt_continuum_shield_fcn.cpp) and
h2FormDist (from mole_h2_create.cpp); so is yanH2xSec in
source/ionization_mod.f90 (from Yan_H2_CS, mole_h2_etc.cpp). The notice above
applies to them, and a note above each marks it as altered (DEVLOG D-436).
