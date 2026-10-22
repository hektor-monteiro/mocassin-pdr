# Citing MOCASSIN-PDR

Results should cite the **release tag** of the code they were made with
(`pdr-coupling-v2.0` for this release), so that the code behind them can be recovered
exactly. The binaries print the version they were built from at the top of every run
log.

Work that uses MOCASSIN-PDR should cite:

- **MOCASSIN:** {cite:t}`Ercolano2003`, {cite:t}`Ercolano2005` and
  {cite:t}`Ercolano2008`.
- **3D-PDR:** {cite:t}`Bisbas2012`.
- **The coupling's precursor and companion:** TORUS-3DPDR, {cite:t}`Bisbas2015`, which
  couples 3D-PDR to a different photoionisation code.
- **The H₂ level model:** it follows Cloudy's large H₂ model, {cite:t}`Shaw2005`. Its
  data:
  - the energies of X, {cite:t}`Komasa2011`;
  - the quadrupole A values, {cite:t}`Wolniewicz1998`;
  - the excited electronic states, {cite:t}`Abgrall2000`;
  - collisions with H, {cite:t}`Lique2015`; with H₂, {cite:t}`Wan2018`; with H⁺,
    {cite:t}`Gerlich1990`;
  - the formation distribution, {cite:t}`TakahashiUehara2001`.

  These data are copied unmodified from Cloudy c25.00 {cite:p}`Chatzikos2023`.
- **H₂ formation on grains:** {cite:t}`CazauxTielens2002` and
  {cite:t}`CazauxTielens2004`.
- **Grain charging and photoelectric heating:** {cite:t}`WeingartnerDraine2001`.
- **Reaction rates** (`dataPDR/rates_*.d`, UMIST format): {cite:t}`McElroy2013`.
- **Molecular data** (`dataPDR/*.dat`, LAMDA): {cite:t}`Schoier2005`, the original paper
  of each molecule used, and the date the database was accessed.
- **Atomic data** (`data/`): CHIANTI 10.1 and the Stout database. Their references are in
  the repository README.
- **HEALPix:** {cite:t}`Gorski2005`.
- **SUNDIALS/CVODE:** {cite:t}`Hindmarsh2005` and {cite:t}`Gardner2022`.
