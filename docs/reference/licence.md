# Licence and credits

MOCASSIN-PDR is distributed under the **GNU General Public License, version 3 or (at your
option) any later version**; see
[LICENSE](https://github.com/hektor-monteiro/mocassin-pdr/blob/main/LICENSE). This
documentation, including the code excerpts it shows, is distributed under the same
licence.

The GPL covers the program's code. The data files in `data/`, `dustData/` and
`dataPDR/` are third-party scientific data redistributed under their providers' terms;
they are not licensed by the MOCASSIN-PDR authors.
{doc}`third-party` (`THIRD_PARTY_NOTICES.md` in the repository) lists every third-party
component and reproduces the notices their licences require, and {doc}`data-sources`
gives the per-file sources and terms of the bundled data.

- **MOCASSIN** is Copyright (C) 2003–2007 Barbara Ercolano, with later changes by Roger
  Wesson and contributors, licensed under the GPL, version 2 or any later version. This
  fork starts from R. Wesson's version
  ([rwesson/mocassin](https://github.com/rwesson/mocassin)). Files changed here keep their
  original copyright notice and carry a modification note, except three still to get one
  (`hydro_mod.f90`, `fluorescence_mod.f90`, `readdata_mod.f90`).
- **3D-PDR** ([itamos-ism/3D-PDR](https://github.com/itamos-ism/3D-PDR); T. G. Bisbas,
  Z. Zhu, B. A. L. Gaches, X.-J. Jiang, X. Tang, G. Zhang and contributors) is GPL version 3
  or later. It is vendored under `source/pdr/`, with the local changes listed in
  {doc}`../developer/vendored-3dpdr`. Because 3D-PDR is GPL v3, the combined program can
  only be distributed under GPL v3 or later.
- **HEALPix** (Górski et al.): `source/pdr/healpix.F90` and `source/pdr/healpix_types.F90`
  contain HEALPix code, GPL version 2 or later.
- **SUNDIALS/CVODE** is BSD-3-Clause. It is linked, not included, apart from one helper
  function from its examples in `source/pdr/calculate_abundances.c`.
- **Cloudy** c25.00 (Copyright (C) 1978–2025 Gary J. Ferland and others; zlib licence): the
  H₂ data in `dataPDR/h2/` are copied unmodified, 15 atomic-data files in `data/` are
  converted from its Stout database, and three routines are translated or adapted from
  its source (`yanH2xSec`, `h2ShieldFederman`, `h2FormDist`); the notes marking them as altered
  in the code are still to be added. The
  rest of the H₂ level model re-implements the equations and conventions of Cloudy's large
  H₂ model and is this project's code.
- **DUSTY** (BSD-3-Clause, © 2016 Ž. Ivezić): about 18 optical-constant files in
  `dustData/` come from its library.

:::{warning}
**Known licensing issue.** Some routines in `source/pdr/spline.F90` and
`source/pdr/solvlevpop.F90` (inherited from 3D-PDR), in `source/interpolation_mod.f90`
(from MOCASSIN, unused) and three sort routines written here follow *Numerical Recipes*,
whose licence does not permit redistributing them. They are listed in
`THIRD_PARTY_NOTICES.md` and are to be replaced by independently written code.
:::

MOCASSIN-PDR is not the official MOCASSIN. The official code is described at
<https://mocassin.nebulousresearch.org/>.
