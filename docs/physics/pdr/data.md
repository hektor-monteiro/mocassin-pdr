(app:data)=
# Data files on this path
The table lists the data files that enter the path from the field to the molecules, with the source of their content. For the H$_2$ files the source is the one the file’s own header gives, completed where the header is not the primary source ({ref}`sec:h2data`); `dataPDR/h2/` is a copy of Cloudy c25.00’s `data/h2/`, unmodified.

:::{list-table} Data files on the path from the field to the molecules.
:name: tab:datafiles
:header-rows: 1
:widths: 34 62

* - File
  - Content and provenance
* - `dataPDR/species_reduced.d`
  - the 33 species, initial abundances (unused: seeding is MOCASSIN’s) and masses; 3D-PDR {cite:p}`Bisbas2012`
* - `dataPDR/rates_reduced.d`
  - 332 reactions in UMIST format: number, reactants, products, $\alpha$, $\beta$, $\gamma$, source code, $T_{\min}$, $T_{\max}$, accuracy; 331 from 3D-PDR (a subset of UMIST, {cite:t}`Woodall2007` or {cite:t}`McElroy2013`, release not recorded; {ref}`sec:network`); reaction 332 added in this project with the coefficient of Cloudy’s `mole_co_umisthack.dat`, attributed there to {cite:t}`Janev1987`
* - `dataPDR/12c+.dat`, `12c.dat`, `16o.dat`, `12co.dat`
  - coolant level data in LAMDA format {cite:p}`Schoier2005`; for `16o.dat` and `12c.dat` the $^1D$/$^1S\to{}^3P_J$ collision rates are split by $g_J/9$ (`pdr/UPSTREAM.md`, {devlog}`D-285`)
* - `dataPDR/h2/energy_X.dat`
  - $X$ level energies (302 levels), {cite:t}`Komasa2011`, their Table 1, compiled by K. Kaplan
* - `dataPDR/h2/transprob_X.dat`
  - $X$ electric-quadrupole $A$ values, {cite:t}`Wolniewicz1998`; magnetic-dipole components of 30 $v=1\to0$, $\Delta J=0$ transitions, {cite:t}`PachuckiKomasa2011`, listed separately and summed by the reader
* - `dataPDR/h2/coll_rates_H_15.dat`
  - H + H$_2$ de-excitation rate coefficients, reactive channels included, 100–5000 K, {cite:t}`Lique2015`
* - `dataPDR/h2/coll_rates_He_ORNL.dat`
  - He + H$_2$, 1–$10^4$ K, the ORNL data set; the header cites “Lee, T. G. et al. 2007, ApJ, in preparation”, and no published source for the table was identified
* - `dataPDR/h2/coll_rates_H2ortho_ORNL.dat`, `coll_rates_H2para_ORNL.dat`
  - $o$-H$_2$ and $p$-H$_2$ + H$_2$, $v=0$, 1–$10^4$ K, {cite:t}`Wan2018`
* - `dataPDR/h2/coll_rates_Hp.dat`
  - H$^+$ + H$_2$ including proton exchange, $v=0$, $J\le9$, 3–6000 K, {cite:t}`Gerlich1990`
* - `dataPDR/h2/energy_\{state\}.dat`, `transprob_\{state\}.dat`, `dissprob_\{state\}.dat`
  - excited electronic states $B$, $C^\pm$, $B'$, $D^\pm$: levels, lines to $X$, spontaneous radiative dissociation rates and kinetic energies, {cite:t}`Abgrall2000`, whose line transition probabilities rest on {cite:t}`Abgrall1993` and {cite:t}`Abgrall1994`; the $J=0$ energies of the $\Pi$ components that the files carry as comments are extrapolations by Cloudy’s authors and are not read
* - `dataPDR/h2/energy_dissoc.dat`
  - dissociation energies of the electronic states, {cite:t}`Sharp1970` per the header (which dates it 1971), with values revised in Cloudy in 2002; only the value for $X$, 36 118.11 cm$^{-1}$, is used
* - `dataPDR/h2/README.md`
  - provenance and Cloudy’s licence notice (zlib)
* - MOCASSIN atomic data (`data/ph1.dat`, `ph2.dat`, `radrec.dat`)
  - photoionisation cross-section fits {cite:p}`Verner1996,VernerYakovlev1995` and radiative recombination fits ({cite:alp}`VernerFerland1996`, and the sources listed at {src}`update_mod.f90::updateCell@"! This subroutine calculates rates of radiative recombination for all ions"..@"! n - number of electrons from 1 to z"`), used for the linked atoms’ rates; the H$_2$ photoionisation cross section is a fit in the code {cite:p}`Yan1998,Yan2001`
:::
