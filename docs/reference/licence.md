# Licence and credits

MOCASSIN-PDR is distributed under the **GNU General Public License, version 3**; see
`LICENSE` in the repository.

- **MOCASSIN** is Copyright (C) 2003–2005 Barbara Ercolano and is licensed under the GPL,
  version 2 or any later version. This fork starts from R. Wesson's version
  ([rwesson/mocassin](https://github.com/rwesson/mocassin)). Files changed here keep their
  original copyright notice and carry a modification note.
- **3D-PDR** ([itamos-ism/3D-PDR](https://github.com/itamos-ism/3D-PDR)) is GPL version 3.
  It is vendored under `source/pdr/`, with the local changes listed in
  {doc}`../developer/vendored-3dpdr`. Because 3D-PDR is GPL v3, the combined program can
  only be distributed under GPL v3.
- `source/pdr/healpix_types.F90` comes from HEALPix (Górski et al.) and is GPL version 2
  or later.
- **SUNDIALS/CVODE** is BSD-3-Clause. It is linked, not included.
- The H₂ data in `dataPDR/h2/` are copied unmodified from **Cloudy** c25.00 (Copyright (C)
  1978–2025 Gary J. Ferland and others), under its zlib licence, which is reproduced in
  `dataPDR/h2/README.md`. The H₂ model's code is not Cloudy's.

MOCASSIN-PDR is not the official MOCASSIN. The official code is described at
<https://mocassin.nebulousresearch.org/>.
