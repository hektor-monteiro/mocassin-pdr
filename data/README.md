# Atomic data (`data/`)

The data MOCASSIN reads at run time from `PREFIX/share/mocassin/data/`. They are
third-party scientific data, redistributed under their providers' terms; the GNU GPL of
MOCASSIN-PDR covers the code, not these files (see `../THIRD_PARTY_NOTICES.md`).

## CHIANTI 10.1 (123 files)

Energy levels, radiative rates and effective collision strengths converted from
version 10.1 of the CHIANTI database. Each file keeps the version and the original
references of the CHIANTI files it was made from (`.elvlc`, `.wgfa`, `.scups`).
CHIANTI is freely available; its authors ask users to acknowledge it and to state the
version incorporated (https://www.chiantidatabase.org/referencing.html). Cite
Dere et al. 1997, A&AS 125, 149, and Dere et al. 2023, ApJS 268, 52.

The converter is `tools/chianti_converter` in
[hektor-monteiro/mocassin_HM_2026](https://github.com/hektor-monteiro/mocassin_HM_2026).

## Stout database, from Cloudy c25.00 (15 files)

`arii.dat`, `arvi.dat`, `caiv.dat`, `clix.dat`, `fii.dat`, `fiv.dat`, `kiii.dat`,
`kvii.dat`, `mgi.dat`, `piii.dat`, `scv.dat`, `siii.dat`, `tivi.dat`, `v7.dat`,
`vvii.dat` (`vvii.dat` duplicates `v7.dat`).

Converted from the Stout database distributed with Cloudy c25.00 (Lykins et al. 2015,
ApJ 807, 118). Each file says so in its header; they are altered versions of Cloudy's
data (reformatted for MOCASSIN). Cloudy's licence (zlib), which applies to them:

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

The converter is `tools/stout_converter` in
[hektor-monteiro/mocassin_HM_2026](https://github.com/hektor-monteiro/mocassin_HM_2026).

## He I recombination lines (`HeIrecLines.dat`)

Fits made for this project to the He I emissivities of Porter et al. 2012 (MNRAS 425,
L28) and 2013 (MNRAS 433, L89), as tabulated by PyNeb (Luridiana et al. 2015, A&A 573,
A42). Made with `tools/hei_converter` in
[hektor-monteiro/mocassin_HM_2026](https://github.com/hektor-monteiro/mocassin_HM_2026)
(commit `f18b30c`).

## Inherited from MOCASSIN (31 files)

The remaining files come unchanged from MOCASSIN (`e1bx.dat` was `e1bx.d`). Their
sources are given in the MOCASSIN papers (Ercolano et al. 2003, MNRAS 340, 1136;
2005, MNRAS 362, 1038; 2008, ApJS 175, 534), and where a file names its source it is
listed here:

| Files | Content | Source |
| :--- | :--- | :--- |
| `ph1.dat`, `ph2.dat` | photoionisation cross-section fits | Verner et al. 1996; Verner & Yakovlev 1995 |
| `radrec.dat` | radiative recombination fits | the compilation listed in `radRecFit` (`source/update_mod.f90`): Verner & Ferland 1996; Péquignot et al. 1991; Arnaud & Raymond 1992; Shull & Van Steenberg 1982; Landini & Monsignori Fossi 1990, 1991 |
| `e1bx.dat` | hydrogenic case B recombination data | Storey & Hummer 1995, MNRAS 272, 41 |
| `covi.dat`, `criii.dat`, `mniv.dat`, `v2.dat` (and its duplicate `vii.dat`) | effective collision strengths | Berrington 1995, A&AS 109, 193 (named in the files) |
| `clv.dat`, `feii.dat` | fine-structure and Fe II level data | as stated in the file headers |
| `gammaHI.dat`, `gammaHeI.dat`, `gammaHeII.dat`, `r1b0100.dat`, `r2a0100.dat`, `r2b0100.dat`, `dielectronic.dat`, `aldrovandi.dat`, `auger.dat`, `cion.dat`, `HeI2phot.dat`, `Rcii.dat`, `Rneii.dat`, `Rnii.dat`, `Rnii_aeff.dat`, `Rniiold.dat`, `Roii.dat`, `resLines.dat`, `flambda.dat`, `fileNames.dat` | H and He continuous emission coefficients, recombination-line tables, dielectronic and other recombination rates, Auger yields, collisional ionisation, He I two-photon, recombination-line coefficients, resonance lines, extinction curve, file index | MOCASSIN papers above |

## Older data sets, not used

`data.chianty-7/` (CHIANTI 7, with three files from CHIANTI 5.2; MOCASSIN's own
`data/` as distributed upstream) and `data.chianty-10/` (an earlier CHIANTI 10
conversion) are kept for reference. They are not installed and no code reads them.
