# Citing MOCASSIN-PDR

Results should cite the **release tag** of the code they were made with
(`pdr-coupling-v2.0` for this release), so that the code behind them can be recovered
exactly. The binaries print the version they were built from at the top of every run
log.

Work that uses MOCASSIN-PDR should cite:

- **MOCASSIN:** {cite:t}`Ercolano2003`, {cite:t}`Ercolano2005` and
  {cite:t}`Ercolano2008`.
- **3D-PDR:** {cite:t}`Bisbas2012`, and the code itself, {cite:t}`Bisbas2026` (its JOSS paper once
  published). The 3D build uses the ray tracer RAYTHEIA, {cite:t}`Zhu2026`.
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

  These data are copied unmodified from Cloudy c25.00 {cite:p}`Gunasekera2025`.
- **H₂ formation on grains:** {cite:t}`CazauxTielens2002` and
  {cite:t}`CazauxTielens2004`.
- **Grain charging and photoelectric heating:** {cite:t}`WeingartnerDraine2001`.
- **Reaction rates** (`dataPDR/rates_*.d`, UMIST format): {cite:t}`McElroy2013`.
- **Molecular data** (`dataPDR/*.dat`, LAMDA): {cite:t}`Schoier2005`, {cite:t}`vanderTak2020`
  and the original paper of each molecule used (the files come from 3D-PDR; the date they were
  taken from LAMDA is not recorded).
- **Atomic data** (`data/`): CHIANTI 10.1, {cite:t}`Dere1997` and {cite:t}`Dere2023`; the Stout
  database, {cite:t}`Lykins2015`; He I recombination lines, {cite:t}`Porter2012` and
  {cite:t}`Porter2013`. The other files' sources are in `data/README.md`.
- **Dust optical data** (`dustData/`): the papers each file names (`dustData/README.md`), and
  DUSTY, {cite:t}`IvezicElitzur1997`, for the files from its library.
- **HEALPix:** {cite:t}`Gorski2005`.
- **SUNDIALS/CVODE:** {cite:t}`Hindmarsh2005` and {cite:t}`Gardner2022`.
