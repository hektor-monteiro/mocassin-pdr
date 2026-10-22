# Chemistry data (`dataPDR/`)

The species lists, reaction rates and coolant data the coupled 3D-PDR chemistry reads
from `PREFIX/share/mocassin/dataPDR/` (or `pdrDataDir`). They come from 3D-PDR
(https://github.com/itamos-ism/3D-PDR, vendored at commit `fabcdc6`, whose repository is
under the GNU GPL v3), which took them from the databases below. They are third-party
scientific data, redistributed under their providers' terms; see
`../THIRD_PARTY_NOTICES.md`. The H₂ data in `h2/` are described in `h2/README.md`.

## Networks (`species_*.d`, `rates_*.d`)

A subset of the UMIST Database for Astrochemistry, RATE12 release, as distributed in
3D-PDR (McElroy et al. 2013, A&A 550, A36; https://umistdatabase.uk). Cite McElroy et al.
2013 and 3D-PDR. Only the REDUCED network (`species_reduced.d`, `rates_reduced.d`) is
compiled into MOCASSIN-PDR; the `full`, `medium` and `mynetwork` files are kept as 3D-PDR
distributes them and are not read.

Changed here, as recorded in `source/pdr/UPSTREAM.md`:
- `rates_reduced.d`: reaction 332, e⁻ + H₂⁺ → e⁻ + H + H⁺, appended (DEVLOG D-395),
  with the coefficient Cloudy's `mole_co_umisthack.dat` attributes to Janev et al. 1987;
- `species_reduced.d`: the H₂⁺ and CH₅⁺ entries (lines 4 and 6) exchanged so that the
  species order matches the generated `odes_reduced.c` (DEVLOG D-357).

## Coolant and line data (`*.dat`)

`12c.dat`, `12c+.dat`, `16o.dat`, `12co.dat` and the other molecule files are from the
Leiden Atomic and Molecular Database, LAMDA (Schöier et al. 2005, A&A 432, 369; van der
Tak et al. 2020, Atoms 8, 15; https://home.strw.leidenuniv.nl/~moldata/), as distributed
in 3D-PDR `fabcdc6`; the date they were taken from LAMDA is not recorded. Each file names
the sources of its collision rates; LAMDA asks users to cite those papers as well.

Changed here: in `12c.dat` and `16o.dat` the collision rates from the ¹D and ¹S levels to
the ³P term are split among the ³P_J levels by g_J/9 (DEVLOG D-285; `tools/d285_split_3p.py`),
marked in the files.

