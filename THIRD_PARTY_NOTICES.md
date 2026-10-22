# Third-party code and data in MOCASSIN-PDR

MOCASSIN-PDR as a whole is distributed under the GNU General Public License, version 3
or (at your option) any later version (`LICENSE`). It combines code from several
projects, each under its own licence, all compatible with that one, and it bundles
scientific data that remain under their providers' terms. This file lists them and
reproduces the notices their licences require to be kept. Each data directory also
has its own README with the per-file sources: `data/README.md`,
`dustData/README.md`, `dataPDR/README.md` and `dataPDR/h2/README.md`.

## Known licensing issue: Numerical Recipes code

Some routines are copied or adapted from *Numerical Recipes* (Press et al.), whose
licence does not permit redistributing the routines in source or compiled form. They
are not covered by this project's GPL licence, and are to be replaced by
independently written code:

| File | Routines | Origin |
| :--- | :--- | :--- |
| `source/pdr/spline.F90` | `SPLINE`, `SPLINT`, `SPLIE2`, `SPLIN2` (and its bracket search) | vendored 3D-PDR; the file says "Copied from Numerical Recipes" |
| `source/pdr/solvlevpop.F90` | `GAUSS_JORDAN`, `GAUSS_JORDAN_writes` | vendored 3D-PDR; NR `gaussj` |
| `source/interpolation_mod.f90` | `polint`, `spline`, `splint` (never called) | MOCASSIN upstream |
| `source/iteration_mod.f90`, `source/h2_mod.f90`, `source/pdr_mod.f90` | `cvSortD`, `indexSort`, `heapSortIdx` | written for this project following NR's heapsort |

Recorded in DEVLOG D-434.

## Code

### MOCASSIN

Copyright (C) 2003-2007 Barbara Ercolano; later changes by Roger Wesson and
contributors. GNU General Public License, version 2 or any later version (the grant
is in the header of `source/mocassin.f90`). This fork starts from
[rwesson/mocassin](https://github.com/rwesson/mocassin). Files modified here keep
their original notices; a modification line is still to be added to `source/hydro_mod.f90`,
`source/fluorescence_mod.f90` and `source/readdata_mod.f90` (DEVLOG D-435).

MOCASSIN itself contains code from other authors, credited in the files:
- `BHmie` (`source/ph_mod.f90`): Bohren & Huffman (1983), *Absorption and Scattering
  of Light by Small Particles*, Appendix A, as modified by B. T. Draine; no licence
  stated by the authors.
- `hdatx`, `hlinex` (`source/output_mod.f90`): the hydrogenic emissivity code of
  Storey & Hummer (1995, MNRAS 272, 41), ported by Wang Wei and Yu Pei.
- `getGauntFF` (`source/ionization_mod.f90`, and the unused `source/gaunt.f90`): the
  free-free Gaunt factor routine of Hummer (1988, ApJ 327, 477), modified by
  J. Ferguson and B. Ercolano.
- `phFitHIon`, `HFit` (`source/ph_mod.f90`): adapted from an early version of Cloudy
  (A. Pradhan, 1990).
- `luSlv`, `lured`, `reslv` (`source/emission_mod.f90`): linear solver of the
  EQUIB code lineage (origin not confirmed).

### 3D-PDR

Copyright (C) T. G. Bisbas, Z. Zhu, B. A. L. Gaches, X.-J. Jiang, X. Tang, G. Zhang
and contributors. GNU General Public License, version 3 or later
([itamos-ism/3D-PDR](https://github.com/itamos-ism/3D-PDR), vendored at commit
`fabcdc6`; its `LICENSE` is identical to this repository's). Vendored under
`source/pdr/`; the local changes are listed in `source/pdr/UPSTREAM.md`. The 3D build
includes RAYTHEIA (Z. Zhu; `m_Ray_box.F90`, `m_Mesh.F90`). 3D-PDR itself contains:
- `healpix.F90`, `healpix_types.F90`: routines from HEALPix (below);
- `heapsort.F90`, `definitions.F90`: taken from the SEREN SPH code (C. P. Batty;
  Hubber et al. 2011, A&A 529, A27);
- the Numerical Recipes routines listed above.

### HEALPix

`source/pdr/healpix.F90` (routines from `pix_tools.F90`; its own copy of this notice was
removed upstream and is still to be restored, DEVLOG D-435) and `source/pdr/healpix_types.F90`:

```text
Copyright (C) 1997-2013 Krzysztof M. Gorski, Eric Hivon,
                        Benjamin D. Wandelt, Anthony J. Banday,
                        Matthias Bartelmann, Hans K. Eriksen,
                        Frode K. Hansen, Martin Reinecke

This file is part of HEALPix.

HEALPix is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
```

### Cloudy

Three routines are translated or adapted from the Cloudy c25.00 source, and two sets
of data files come from Cloudy (see `data/README.md` and `dataPDR/h2/README.md`):
- `yanH2xSec` (`source/ionization_mod.f90`), from `Yan_H2_CS` in `mole_h2_etc.cpp`;
- `h2ShieldFederman` (`source/h2_mod.f90`), from `shieldFederman` in
  `rt_continuum_shield_fcn.cpp`;
- `h2FormDist` (`source/h2_mod.f90`), adapted from `mole_h2_create.cpp`.

They are altered versions of Cloudy's code; the notes marking them in the routines themselves are still to be added (DEVLOG D-435). The rest of the H₂ level
model re-implements the equations and conventions of Cloudy's large H₂ model
(Shaw et al. 2005) and is this project's code. Cloudy's licence:

```text
/* Cloudy -- simulations of non-equilibrium plasmas and their spectra

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

  Gary J. Ferland gary@uky.edu

  This is an Open Source License as approved by the Open Source Initiative,
  see http://opensource.org/licenses/Zlib for details.

*/
```

### SUNDIALS

CVODE is linked, not included. The helper `check_flag` in
`source/pdr/calculate_abundances.c` comes from the SUNDIALS examples:

```text
BSD 3-Clause License

Copyright (c) 2002-2025, Lawrence Livermore National Security and Southern
Methodist University. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the copyright holder nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

Binaries built with SUNDIALS and given to others must carry this notice and SUNDIALS'
`NOTICE` file.

## Data

The GNU GPL covers the program's code. The data files in `data/`, `dustData/` and
`dataPDR/` are third-party scientific data redistributed as received or as converted
here, under their providers' terms; they are not licensed by the MOCASSIN-PDR authors.
The terms, all of which allow this use with attribution, are summarised here; the
per-file sources are in each directory's README.

| Data | Provider and terms | Where |
| :--- | :--- | :--- |
| Atomic data, CHIANTI 10.1 | Freely available; acknowledge it and state the version (chiantidatabase.org) | `data/` |
| Atomic data, Stout database | Cloudy c25.00, zlib licence above | `data/` (15 files) |
| Legacy atomic data | MOCASSIN upstream (Verner, Storey & Hummer, Péquignot and others) | `data/` |
| Dust optical constants | DUSTY (BSD-3, notice in `dustData/README.md`), B. T. Draine, Jena and Kyoto laboratory databases, Warren & Brandt; compilations by N. Wright and P. Owen, provided by M. J. Barlow with permission to publish | `dustData/` |
| Chemical network | UMIST Database for Astrochemistry (RATE12 subset), as distributed in 3D-PDR | `dataPDR/` |
| Molecular data | LAMDA (Leiden), as distributed in 3D-PDR | `dataPDR/` |
| H₂ data | Cloudy c25.00, zlib licence above | `dataPDR/h2/` |
| Stellar spectra in `examples/multistars.tar.gz` | Starburst99 (Leitherer et al. 1999) | `examples/` |
