# MOCASSIN-PDR: Monte Carlo photoionisation and photodissociation-region modelling

**MOCASSIN-PDR** is MOCASSIN with the photodissociation-region chemistry and thermal balance of
[3D-PDR](https://github.com/itamos-ism/3D-PDR) coupled into it. The Monte Carlo radiation field,
dust and ionisation structure computed by MOCASSIN drive the chemistry, so that one model follows the
gas from the H II region through the PDR into the molecular gas. It is not the official MOCASSIN; see
[Licence and credits](#licence-and-credits).

**MOCASSIN** is a fully 3D or 2D photoionisation and dust radiative transfer code which employs a Monte Carlo approach to the transfer of radiation through media of arbitrary geometry and density distribution. It was originally developed by Barbara Ercolano (https://mocassin.nebulousresearch.org/publications) for the modelling of photoionised regions like HII regions and planetary nebulae and has since expanded and been applied to a variety of astrophysical problems, including modelling clumpy dusty supernova envelopes, star forming galaxies, protoplanetary disks and inner shell fluorescence emission in the photospheres of stars and disk atmospheres.

The code can deal with arbitrary Cartesian grids of variable resolution, it has successfully been used to model complex density fields from SPH calculations and can deal with ionising radiation extending from Lyman edge to the X-ray. The dust and gas microphysics is fully coupled both in the radiation transfer and in the thermal balance.

The code is detailed in https://mocassin.nebulousresearch.org/

This repository is a fork of the official MOCASSIN repository, https://github.com/rwesson/mocassin.

## Current state

MOCASSIN-PDR is research code under active development. The coupled code runs on 3D grids with
ray-traced column densities. Its latest release is `pdr-coupling-v1.2` (2026-10-21, DEVLOG D-425), and
science results should cite a release tag. The coupling has been compared with Cloudy (c25.00) and with
standalone 3D-PDR on the models in `benchmarks/pdr/`.

  - Every design decision, measurement and correction, including the hypotheses that turned out wrong, is
    recorded in [DEVLOG.md](DEVLOG.md). Its entries run from D-001 to D-425, and the README cites them
    by number.
  - What is validated, and what is known to be wrong and by how much, is summarised in
    [doc/pdr-status.md](doc/pdr-status.md). That page was last updated at D-410 (2026-10-15).

Recent changes that move results:

  - **Gas–grain energy exchange (D-420, D-421, 2026-10-19).** H2 is now a collider in the exchange.
    Before, only atoms, ions and electrons were, so in molecular gas almost nothing coupled the gas to
    the dust. The term also enters each energy balance in that balance's own units: the gas side had
    been 4π too weak, and the grain side 4 times too weak. In dusty models the ionised gas is now
    2–3.5% cooler, and shielded molecular gas exchanges heat with the dust at the physical rate. The
    reference models in `benchmarks/pdr/` have not yet been rerun with this change.
  - **[Ni II] level order (D-418).** The collision rates took the Boltzmann factor at the wrong level of
    one level pair. Below about 14 K this overflowed and crashed cold models.
  - **Dust Q files (D-413, D-415).** Five-column Q files had failed at start-up since D-313. The PAH
    file `dustData/PAHneu_30.cat` now carries Im(m), so PAHs can heat the gas photoelectrically.

## How the coupling works

The rule the coupling is built on: every quantity the two codes share is computed once, by the code that
owns it, and read by the other. The chemistry runs in every active cell. No zone threshold or input
keyword moves a quantity from one code to the other.

| Quantity | Computed by |
| :--- | :--- |
| Radiation field: stellar and diffuse, ionising and FUV, through gas and dust | MOCASSIN (Monte Carlo) |
| Dust: optical properties, temperature per species and size, charge, photoelectric heating (Weingartner & Draine 2001) | MOCASSIN |
| A_V, and the ratio of FUV to visual extinction | MOCASSIN, measured from the model's own grains |
| Ionisation balance of every element, and the electron density | MOCASSIN |
| Gas temperature: one thermal balance per cell | MOCASSIN, with the chemistry's heating and cooling terms in it |
| Gas–grain heat exchange: atoms, ions, electrons and H2 | MOCASSIN |
| Molecular abundances: the REDUCED network, 33 species, steady state | 3D-PDR, solved with CVODE |
| Columns for self-shielding | 3D-PDR's rays, 12 HEALPix directions per cell (`PDRGEOM=3D`), or a 1D slab |
| H2 formation on grains | Cazaux & Tielens (2002, 2004), at MOCASSIN's dust temperature |
| CO cooling and line emission | the chemistry's level populations, with escape probabilities along the rays |
| C I, C II and O I lines and cooling | MOCASSIN's own atoms, with the chemistry's collision rates (H, H+, He, ortho/para-H2) and escape probabilities (D-363) |

Hydrogen is conserved by construction, x(HI) + 2x(H2) + x(HII) = 1 in every cell (D-220). The resonance
lines, Lyman α among them, are destroyed by the local dust with their escape probability in every
dust + gas run (D-376).

Each Monte Carlo iteration runs these steps:

1. Transfer the stellar and diffuse photon packets through the gas and dust.
2. In each cell, solve the ionisation balance, the dust temperatures and charge, and the thermal
   balance. The thermal balance uses the chemistry's heating and cooling from the last iteration.
3. From iteration `pdrStartIter` on, run the chemistry in every active cell on MOCASSIN's field, T_e,
   electron density and dust temperature. It returns the abundances and its heating and cooling.
4. Solve the ionisation balance again, after the chemistry (D-404).

The run stops when the model-integrated test passes; see [Convergence](#convergence).

## Executables

- `mocassin`: The main MOCASSIN driver that is used to start a new simulation.
- `mocassinWarm`: Resumes an interrupted simulation using existing grid files. In a PDR build it also
  resumes the chemistry's state.
- `mocassinOutput`: Runs the output routines using the current grid files in the output subdirectory.
- `mocassinPlot`: Uses the current grid files in the output/ subdirectory to create 3d-emission maps.
  In a PDR run it also maps the CO lines (the `mol` entry, D-383).

## Building and installation

Building requires MPI and a Fortran compiler. On Debian/Ubuntu:
```bash
sudo apt-get install -y openmpi-bin libopenmpi-dev gfortran
```
The Makefile calls the compiler `mpif90.openmpi`, Debian's name for it. Elsewhere, add
`FC=mpif90 LD=mpif90` to the `make` commands below.

**Name the targets.** A bare `make` builds only the first object file, not the programs.

There are three builds:

| Command | What it builds |
| :--- | :--- |
| `make PDR=1 PDRGEOM=3D all` | The coupled code, with ray-traced columns. Use it for 3D models. |
| `make PDR=1 all` | The coupled code, with 1D slab columns. |
| `make all` | MOCASSIN without the PDR. It needs no extra libraries. |

`all` builds the four executables. Run `make clean` between builds of different kinds, because they
share one object tree. The rest of the PDR configuration is fixed in the Makefile, whose comments
explain each flag.

### SUNDIALS (PDR builds only)

`PDR=1` requires **SUNDIALS >= 7.0.0**, because 3D-PDR links `-lsundials_core`, which 6.x does not have.
The Makefile looks for it in `$(HOME)/software/sundials-7.8.0`; give another location with
`SUNDIALS_DIR`:
```bash
make PDR=1 PDRGEOM=3D SUNDIALS_DIR=/path/to/sundials all
```
The library path is linked into the binaries, so nothing has to be set at run time.

Only the CVODE modules are needed. To build SUNDIALS (this requires `cmake`):
```bash
git clone https://github.com/LLNL/sundials.git && cd sundials && git checkout v7.8.0
cmake -B build -DCMAKE_INSTALL_PREFIX=<prefix> -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_CVODE=ON -DBUILD_ARKODE=OFF -DBUILD_CVODES=OFF \
      -DBUILD_IDA=OFF -DBUILD_IDAS=OFF -DBUILD_KINSOL=OFF \
      -DEXAMPLES_ENABLE_C=OFF -DSUNDIALS_PRECISION=DOUBLE
cmake --build build -j && cmake --install build
```
`SUNDIALS_PRECISION=DOUBLE` is required, to match 3D-PDR's `real(kind=dp)`.

### Installing, and where the data are read from

The binaries read their atomic and dust data from `PREFIX/share/mocassin/`. That path is compiled in.
`PREFIX` defaults to `$(HOME)/.local` on Linux and `/usr/local` on macOS.

`make install` copies the four executables to `PREFIX/bin`. It copies `data/`, `dustData/`, `dataPDR/`
and `benchmarks/` to `PREFIX/share/mocassin/`, and the man page to `PREFIX/share/man/man1`. In a PDR
build:
```bash
make clean
make PDR=1 PDRGEOM=3D PREFIX=$HOME/.local install
```
  - **Run `make clean` before changing `PREFIX`.** Make does not rebuild the objects for a new prefix,
    so the binaries would keep reading the old one.
  - **Keep `PREFIX` under about 90 characters.** A longer data path is truncated, that ion's data are
    skipped without a message, and the run crashes at start-up (D-416).

The atomic data in `data/` are CHIANTI 10.1, with some ions from Cloudy's Stout database (D-330).

## Running

MOCASSIN reads `input/input.in` from the working directory. It does not create `output/`, so make that
first:
```bash
mkdir -p output
mpirun -np <ranks> mocassin
```
**Memory grows with the number of ranks.** Every rank holds its own copy of the grid. For dust + gas +
PDR at `nbins 600`, measured on the development machine (D-370):

    memory ≈ (0.47 GB + 38 kB × active cells) × ranks

With 31 GB for the run, that allows about 46,000 active cells at 14 ranks, or 104,000 at 7.

### PDR keywords

These keywords take effect only in a PDR build. `man/mocassin.1` documents them in full, under
PHOTODISSOCIATION REGIONS.

| Keyword | Meaning |
| :--- | :--- |
| `pdr 1` | Turn the chemistry on. Requires dust: without dust the FUV field is not transported. |
| `pdrDataDir "path"` | The species, rates and coolant data. Default: `PREFIX/share/mocassin/dataPDR`. |
| `pdrNetwork "reduced"` | Checked against the network compiled in, which is the only one; a mismatch stops the run. |
| `pdrCoolants n "file" ...` | The coolant data files in LAMDA format, e.g. `4 "12co.dat" "12c+.dat" "12c.dat" "16o.dat"`. |
| `pdrZeta` | Cosmic-ray ionisation rate [s⁻¹]. Default 1e-16. |
| `pdrVturb` | Turbulent velocity [km/s]. Default 1. |
| `pdrStartIter` | First Monte Carlo iteration at which the chemistry runs. Default 1. |
| `pdrDiagCool`, `pdrDiagRates`, `pdrDiagAV`, `pdrTrackCell`, `pdrSplitField` | Diagnostics only. |

**Some keywords are refused.** A keyword that selected alternative physics, or stood in for a quantity
the model computes, stops the run with a message. Examples are `pdrZoneLimit`, `pdrOwnDust` and
`pdrMetallicity`; the man page has the full list.

The keyword `frontLines` adds a post-processing estimate of the [O I] 6300, 6363 and 5577 lines with the
cells an ionisation front crosses resolved (D-382). It is an estimate, not the model's state.

### Convergence

The run stops when the model-integrated test passes. That test covers the emission measures, the H0, H2
and CO contents and the weighted temperatures. Each must change by less than `convTotals` (default 0.02)
over three iterations (D-391, D-392). `maxIterateMC` caps the number of iterations, and
`output/convergence.out` records the test at every iteration. The percentage of converged cells is
reported, not tested.

## Benchmarks

### Photoionisation and dust

To run the standard test problem (Meudon standard HII region), navigate to `benchmarks/test_Problem`:
```bash
cd benchmarks/test_Problem
mkdir -p output/
mpirun -np 1 ../../mocassin
```
- The Lexington benchmarks (Ercolano et al. 2003) are in `benchmarks/gas/`: HII20, HII40, PN75 and
  PN150.
- 1D and 2D dust benchmarks are in `benchmarks/dust/1D` and `benchmarks/dust/2D`. Copy the input file
  you need to `input/input.in`, then run MOCASSIN.

### PDR models (`benchmarks/pdr/`)

| Model | What it is |
| :--- | :--- |
| `hiipdr` | The H II region and PDR of Bisbas et al. (2015), §5.4, on a 31³ grid. A matched Cloudy input is in `cloudy/`. |
| `pn150k` | A 150 kK planetary nebula, n_H = 1000 cm⁻³, 41³, with MRN graphite. A matched Cloudy input is in `cloudy/`. |
| `v1slab`, `v2slab` | 1D slabs. `make_density.py` writes their grids. `v1slab` is matched to a standalone 3D-PDR run. |
| `baseline3dpdr/` | Standalone 3D-PDR output: `v1.pdr.fin` for v1slab and `sec54.pdr.fin` for hiipdr. |
| `ifront` | A 1D grid graded to resolve an ionisation front (D-081). |
| `hiipdr-*` | Variants of `hiipdr` made for specific DEVLOG entries. |
| `results/` | Text output of earlier diagnostics. |

- **Fix `pdrDataDir` first.** Every PDR fixture sets it to an absolute path on the development machine.
  Point it at your `dataPDR/`, or delete the line to use the installed copy.
- **The 1D models are out of scope.** `v1slab`, `v2slab` and `ifront` were set aside when this version
  was taken to 3D production (D-338), and they have not been checked under the recent changes.
- `benchmarks/pdr/README.md` describes how the slabs are set up and how the standalone 3D-PDR baseline is
  regenerated.

## Input and output files

- **Input files**: Placed in the `input/` directory (e.g. `input.in`, abundance files, density distribution files, `dust_species.dat` and `dust_sizes.dat`).
- **Data files**: Located in `data/` (atomic data), `dustData/` (dust optical data) and `dataPDR/`
  (chemistry: species, reaction rates and coolant data).
- **Output files**: Saved in the `output/` directory (e.g. `ionratio.out`, `lineFlux.out`, `temperature.out`, `SED.out`, `grid0.out`, `grid1.out`, `grid2.out`, `grid3.out`, `dustGrid.out`).

PDR runs also write:

| File | Contents |
| :--- | :--- |
| `pdrGrid.out` | Per cell: the FUV field, effective A_V, PDR heating and cooling, and the 33 abundances. It is also the checkpoint `mocassinWarm` resumes from. |
| `pdrRad.out` | Per cell: A_V, the line field, the continuum in four bands, and the dust temperature. |
| `thermBudget.out` | Per cell: every heating and cooling term, the gas–grain term, and the grain charge and photoelectric diagnostics. |
| `pdrLineEm.out` | Per cell: each coolant transition's emissivity and escape probability. It is a checkpoint. |
| `lineFluxMol.out` | The CO lines, integrated over the grid. |
| `pdrFUV.out`, `pdrFUVspec.out` | Diagnostics of the FUV field. |
| `resLineEsc.out` | Per cell: the escape fraction of each resonance line. |
| `convergence.out` | The model-integrated quantities at every iteration. |
| `frontField.out`, `lineFluxFront.out` | Only with `frontLines`: the [O I] lines with the fronts resolved. |

`thermBudget.out` is written by the last temperature solve, which comes before the last chemistry step.
So its PDR heating column is one iteration older than `pdrGrid.out`. In a cell that is still changing,
the two do not close.

## Validation and known limitations

The full list, with each figure's source, is in [doc/pdr-status.md](doc/pdr-status.md). Some highlights
against Cloudy, on quantities both codes compute:

| Quantity | Agreement | Entry |
| :--- | :--- | :--- |
| N_H / A_V | 0.4% | D-305 |
| dust mass per H | 0.7% | D-305 |
| Mie cross sections against Draine's tabulated Q | 0.1–1% | D-305 |
| x(C+) through the PDR | 1.001–1.006 | D-304 |
| photoelectric heating per H per G0 | 0.66–1.10, no trend | D-304 |

These were measured before D-420 and D-421. The dust and A_V figures do not depend on those changes; the
heating figures have not been remeasured since.

Limitations to know before using the results:

  - **Shielded gas sees few FUV packets.** Deep in a molecular core a cell can receive no FUV packet in
    an iteration, so its photoelectric heating and temperature carry Monte Carlo noise (D-421). On hiipdr,
    CO in the outer PDR was still changing at 64 times the fixture's packet count (D-408).
  - **Thin ionisation fronts.** Where a front is thinner than a cell, lines that need both ionised and
    neutral gas, such as [O I] 6300, come out too bright. `frontLines` estimates the correction for
    [O I] (D-379 to D-382).
  - **Ray directions.** With 12 rays per cell, hiipdr's x(H2) at A_V 0.5–1 comes out about 11% higher
    in the cells of one symmetry plane than elsewhere, while the model's totals agree within 0.3%
    (D-410). 48 directions remove the pattern at 1.5 times the run time; the default stays at 12.
  - **H2 physics on this branch** is 3D-PDR's. A full rovibrational level model is under development; see
    [Branches and versions](#branches-and-versions).

## Branches and versions

  - **`main`**: the code described here.
  - **`h2-model`**: development of a full H2 level model. It covers the rovibrational X-state levels,
    ultraviolet pumping through the excited electronic states, self-shielding with line overlap, and the
    H2 line spectrum (`lineFluxH2.out`). It is built from Cloudy c25.00's H2 data. The model sets the
    chemistry's H2 photodissociation rate and the H2 heating. Its log is `DEVLOG-H2.md` on that branch.
    It is work in progress.
  - **Tags**: `pdr-coupling-v1.0`, `pdr-coupling-v1.1` and `pdr-coupling-v1.2` are releases. D-425 has
    v1.2's release notes. Reverted work is kept under tags such as `d193-d195-reverted`.
  - The binaries carry the `git describe` version they were built from: `pdr-coupling-v1.2` at the
    tag, `pdr-coupling-v1.2-<n>-g<hash>` for a later commit.

## Documentation

- [DEVLOG.md](DEVLOG.md): the implementation history, one entry per decision.
- [doc/pdr-status.md](doc/pdr-status.md): validation status and known limitations.
- [doc/dust.md](doc/dust.md): the dust input files, the optical data formats and what MOCASSIN computes
  from them.
- `man/mocassin.1`: every input keyword and output file.
- [source/pdr/UPSTREAM.md](source/pdr/UPSTREAM.md): the local changes to the vendored 3D-PDR.
- [benchmarks/pdr/README.md](benchmarks/pdr/README.md): the 1D slab benchmark and its standalone
  baseline.

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
- Atomic data, `data/`: CHIANTI (Dere et al. 1997, A&AS 125, 149; version 10.1, Dere et al. 2023,
  ApJS 268, 52) and Stout (Lykins et al. 2015, ApJ 807, 118)
- Grain photoelectric heating and charging: Weingartner & Draine 2001, ApJS 134, 263
- H2 formation on grains: Cazaux & Tielens 2002, ApJ 575, L29; 2004, ApJ 604, 222
- HEALPix: Górski et al. 2005, ApJ 622, 759
- SUNDIALS: Hindmarsh et al. 2005, ACM TOMS 31, 363; Gardner et al. 2022, ACM TOMS 48, 31

Related work: TORUS-3DPDR (Bisbas et al. 2015, MNRAS 454, 2828) couples 3D-PDR to a different
photoionisation code. M. Vasta's PhD thesis (UCL, 2010, *Modelling ionised and photodissociated
regions*) combined MOCASSIN with the UCL PDR code.
