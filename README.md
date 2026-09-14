# MOCASSIN-PDR: Monte Carlo photoionisation and photodissociation-region modelling

**MOCASSIN-PDR** is MOCASSIN with the photodissociation-region chemistry and thermal balance of
[3D-PDR](https://github.com/itamos-ism/3D-PDR) coupled into it. The Monte Carlo radiation field,
dust and ionisation structure computed by MOCASSIN drive the chemistry, so that one model follows the
gas from the H II region through the PDR into the molecular gas. It is not the official MOCASSIN; see
[Licence and credits](#licence-and-credits).

**MOCASSIN** is a fully 3D or 2D photoionisation and dust radiative transfer code which employs a Monte Carlo approach to the transfer of radiation through media of arbitrary geometry and density distribution. It was originally developed by Barbara Ercolano (https://mocassin.nebulousresearch.org/publications) for the modelling of photoionised regions like HII regions and planetary nebulae and has since expanded and been applied to a variety of astrophysical problems, including modelling clumpy dusty supernova envelopes, star forming galaxies, protoplanetary disks and inner shell fluorescence emission in the photospheres of stars and disk atmospheres.

The code can deal with arbitrary Cartesian grids of variable resolution, it has successfully been used to model complex density fields from SPH calculations and can deal with ionising radiation extending from Lyman edge to the X-ray. The dust and gas microphysics is fully coupled both in the radiation transfer and in the thermal balance.

The code is detailed in https://mocassin.nebulousresearch.org/

This repository is a fork of the official Mocassin repo located at: https://github.com/rwesson/mocassin

## Overview

The project provides four main executables:

- `mocassin`: The main MOCASSIN driver that is used to start a new simulation.
- `mocassinWarm`: Resumes an interrupted simulation using existing grid files.
- `mocassinOutput`: Runs the output routines using the current grid files in the output subdirectory.
- `mocassinPlot`: Uses the current grid files in the output/ subdirectory to create 3d-emission maps.

## Building and Installation

Building the project requires MPI and Fortran compilers. On Debian/Ubuntu, install them via:
```bash
sudo apt-get install -y openmpi-bin libopenmpi-dev gfortran
```

The project is built using `make`:
```bash
make clean
make
```
Compiler flags can be overridden, for example: `make FCFLAGS="-Wall -Wextra"`.

To install locally:
```bash
make install
```

### PDR support

The 3D-PDR chemistry is compiled in with `make PDR=1` (1D slab columns) or `make PDR=1 PDRGEOM=3D`
(ray-traced columns). A plain `make` builds MOCASSIN without it and needs no extra dependencies.

`PDR=1` additionally requires **SUNDIALS >= 7.0.0** (3D-PDR's link
line uses `-lsundials_core`, which does not exist in 6.x). A verified local install lives at
`~/software/sundials-7.8.0`; source its environment file before building with PDR support:

```bash
source ~/software/sundials-7.8.0/env.sh   # sets SUNDIALS_DIR and LD_LIBRARY_PATH
```

To build SUNDIALS elsewhere, `cmake` is required, and only the CVODE modules are needed:

```bash
git clone https://github.com/LLNL/sundials.git && cd sundials && git checkout v7.8.0
cmake -B build -DCMAKE_INSTALL_PREFIX=<prefix> -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_CVODE=ON -DBUILD_ARKODE=OFF -DBUILD_CVODES=OFF \
      -DBUILD_IDA=OFF -DBUILD_IDAS=OFF -DBUILD_KINSOL=OFF \
      -DEXAMPLES_ENABLE_C=OFF -DSUNDIALS_PRECISION=DOUBLE
cmake --build build -j && cmake --install build
```

`SUNDIALS_PRECISION=DOUBLE` is required — it must match 3D-PDR's `real(kind=dp)`.

Design decisions and implementation history for this work are recorded in [DEVLOG.md](DEVLOG.md).


## Running the Benchmarks

### Directory Setup
To run the models, the code must be properly installed wit the `data` and `dustData` directories copied or linked to `/usr/share/mocassin/` or available locally depending on your environment. 

### Pure Photoionisation Benchmarks
You can try to run one or more of the available benchmark problems located in the `benchmarks/` directory.

To run the standard test problem (Meudon standard HII region), navigate to `benchmarks/test_Problem`:
```bash
cd benchmarks/test_Problem
mkdir -p output/
mpirun -np 1 ../../mocassin
```

Alternatively, to setup a benchmark manually:
1. Copy or link the benchmark `input.in` to your working `input` directory.
2. Ensure you have the corresponding abundance file.
3. Run using MPI: `mpirun -np <num_procs> ./mocassin`

### Pure Dust Benchmarks
There are also 1D and 2D benchmark models included under `benchmarks/dust/1D` and `benchmarks/dust/2D`. Copy the required input file to `input/input.in` and execute MOCASSIN.

## Input and Output Files

- **Input files**: Placed in the `input/` directory (e.g. `input.in`, abundance files, density distribution files).
- **Data files**: Located in the `data/` directory (atomic data files) and `dustData/` (dust optical data library).
- **Output files**: Saved in the `output/` directory (e.g. `ionratio.out`, `lineFlux.out`, `temperature.out`, `SED.out`, `grid0.out`, `grid1.out`, `grid2.out`, `grid3.out`, `dustGrid.out`).

See `man/mocassin.1` for a complete list of keywords that can be configured in the `input.in` file.

## Licence and credits

MOCASSIN-PDR is distributed under the **GNU General Public License, version 3** ([LICENSE](LICENSE)).

- **MOCASSIN** is Copyright (C) 2003-2005 Barbara Ercolano and is licensed under GPL version 2 or any
  later version. This fork starts from R. Wesson's version ([rwesson/mocassin](https://github.com/rwesson/mocassin)).
  Files changed here keep their original copyright notice and carry a modification note.
- **3D-PDR** ([itamos-ism/3D-PDR](https://github.com/itamos-ism/3D-PDR)) is GPL version 3. It is
  vendored under `source/pdr/`, and the local changes are listed in
  [source/pdr/UPSTREAM.md](source/pdr/UPSTREAM.md). Because 3D-PDR is GPL v3, the combined program
  can only be distributed under GPL v3.
- `source/pdr/healpix_types.F90` comes from HEALPix (Górski et al.) and is GPL version 2 or later.
- **SUNDIALS/CVODE** is BSD-3-Clause. It is linked, not included.

Work that uses MOCASSIN-PDR should cite:

- MOCASSIN: Ercolano et al. 2003, MNRAS 340, 1136; Ercolano, Barlow & Storey 2005, MNRAS 362, 1038;
  Ercolano et al. 2008, ApJS 175, 534
- 3D-PDR: Bisbas et al. 2012, MNRAS 427, 2100
- Molecular data, `dataPDR/*.dat` (LAMDA): Schöier et al. 2005, A&A 432, 369, plus the original paper for
  each molecule used, and the date the database was accessed
- Reaction rates, `dataPDR/rates_*.d` (UMIST format): McElroy et al. 2013, A&A 550, A36
- HEALPix: Górski et al. 2005, ApJ 622, 759
- SUNDIALS: Hindmarsh et al. 2005, ACM TOMS 31, 363; Gardner et al. 2022, ACM TOMS 48, 31

Related work: TORUS-3DPDR (Bisbas et al. 2015, MNRAS 454, 2828) couples 3D-PDR to a different
photoionisation code. M. Vasta's PhD thesis (UCL, 2010, *Modelling ionised and photodissociated
regions*) combined MOCASSIN with the UCL PDR code.

---

## Some Notes on Dust Species

| Grain Species | Type | Size Range (μm) | ρ (g/cm³) | Sublim. Temp (K) | Molecular Formula | Mol. Weight (amu) | ⟨amu/atom⟩ | Work Function (Ry) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Silicates (amorphous) | Mg/Fe silicates | 0.005–0.25 | 2.5–3.5 | 1200–1500 | Approx. MgFeSiO₄ | ~172 | ~21.5 | ~0.37 (5 eV) |
| Graphite | Carbonaceous | 0.005–0.25 | 2.2 | ~2000 | C | 12 | 12.0 | 0.33–0.37 (4.5–5 eV) |
| Olivine | (Mg,Fe)₂SiO₄ | 0.01–1.0 | 3.3–4.4 | 1400–1500 | Mg₂SiO₄ | 140.7 | 23.5 | ~0.37 (5 eV) |
| Forsterite | Mg₂SiO₄ (pure olivine) | 0.1–1.0 | 3.27 | 1400 | Mg₂SiO₄ | 140.7 | 23.5 | ~0.37 (5 eV) |
| Quartz | SiO₂ | 0.01–0.5 | 2.65 | 1200–1300 | SiO₂ | 60.08 | 20.0 | ~0.33 (4.5 eV) |
| Enstatite | MgSiO₃ | 0.1–1.0 | 3.2 | 1350–1400 | MgSiO₃ | 100.4 | 25.1 | ~0.37 (5 eV) |

### References & Sources

Here are sources used to compile the physical parameters (need to double check these):

#### Density and Molecular Weights
- **Draine, B. T. (2003)**, *Annual Review of Astronomy and Astrophysics*, 41, 241  
- **Henning, T. (2010)**, *ARA&A*, 48, 21  
- **Lodders, K. (2003)**, *ApJ*, 591, 1220 (solar abundances)  
- **CRC Handbook of Chemistry and Physics** for molecular weights and densities

#### Sublimation Temperatures
- **Gail & Sedlmayr (1999)**, *A&A*, 347, 594  
- **Tielens, A. G. G. M. (2005)**, *The Physics and Chemistry of the Interstellar Medium*  
- **Duschl et al. (1996)**, *A&A*, 312, 624  
- Note: Temperatures vary with ambient pressure and gas density.

#### Work Function
- **Draine & Salpeter (1979)**, *ApJ*, 231, 77 (photoelectric emission from grains)  
- **Jenkins (2009)**, *ApJ*, 700, 1299 (dust charging)  
- **CRC Handbook** for graphite and silica values  
- For silicates, work functions are inferred from electron yield and ionization potentials (~5 eV = 0.37 Ry)
