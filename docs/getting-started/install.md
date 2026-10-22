# Installation

MOCASSIN-PDR is Fortran 90 with MPI, plus a small amount of C in the vendored 3D-PDR
chemistry. The plain photoionisation build needs only an MPI Fortran compiler. The PDR
builds also need the CVODE solver of SUNDIALS.

## Requirements

| Needed for | Requirement |
| :--- | :--- |
| every build | an MPI Fortran compiler (Open MPI with gfortran is what the code is developed with) and GNU make |
| PDR builds (`PDR=1`) | a C compiler (`cc` by default, `CC=` to change it) and **SUNDIALS ≥ 7.0** in double precision |

On Debian or Ubuntu:

```bash
sudo apt-get install -y openmpi-bin libopenmpi-dev gfortran make
```

The Makefile calls the compiler `mpif90.openmpi`, Debian's name for it. Elsewhere add
`FC=mpif90 LD=mpif90` to every `make` command below.

## SUNDIALS (PDR builds only)

3D-PDR links `-lsundials_core`, which SUNDIALS 6 does not have, so version 7 or later
is required. Only CVODE is needed. It must be built in double precision, to match
3D-PDR's `real(kind=dp)`:

```bash
git clone https://github.com/LLNL/sundials.git && cd sundials && git checkout v7.8.0
cmake -B build -DCMAKE_INSTALL_PREFIX=$HOME/software/sundials-7.8.0 -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_CVODE=ON -DBUILD_ARKODE=OFF -DBUILD_CVODES=OFF \
      -DBUILD_IDA=OFF -DBUILD_IDAS=OFF -DBUILD_KINSOL=OFF \
      -DEXAMPLES_ENABLE_C=OFF -DSUNDIALS_PRECISION=DOUBLE
cmake --build build -j && cmake --install build
```

The Makefile looks for SUNDIALS in `$HOME/software/sundials-7.8.0`. Give another
location with `SUNDIALS_DIR=/path/to/sundials`. The library path is linked into the
binaries (rpath), so nothing has to be set at run time.

## Building

Always name the targets: a bare `make` builds only the first object file. There are three
builds. Run `make clean` between builds of different kinds, because they share one
object tree.

| Command | What it builds |
| :--- | :--- |
| `make PDR=1 PDRGEOM=3D all` | The coupled code with ray-traced columns **and the H₂ level model**. Use it for 3D PDR models. |
| `make PDR=1 all` | The coupled code with 1D slab columns, without the H₂ level model. |
| `make all` | MOCASSIN without the PDR. It needs no extra libraries. |

`all` builds the four programs `mocassin`, `mocassinWarm`, `mocassinOutput` and
`mocassinPlot`. After a 3D build, `make PDR=1 PDRGEOM=3D h2Test h2Slab` builds the
H₂ model's standalone tests (repeat the flags, or the next build recompiles every
object).

The programs read their data from `PREFIX/share/mocassin/` (below), so a build is
runnable only after `make install` with the same `PREFIX`. A stale installed copy
from another version is read silently. {doc}`../user-guide/build-flavours` lists every compile-time flag
and what it selects.

:::{important}
The H₂ level model is compiled into the 3D build only (`PDRGEOM=3D`). In the 1D build
it is a stub, and H₂ is photodissociated at the chemistry network's single-line rate
({src}`pdr_mod.f90::h2LevelModel [1d]`).
:::

## Installing, and where the data are read from

The programs read their atomic, dust and chemistry data from `PREFIX/share/mocassin/`.
That path is **compiled into the binaries**. `PREFIX` defaults to `$HOME/.local` on
Linux and `/usr/local` on macOS.

```bash
make clean
make PDR=1 PDRGEOM=3D PREFIX=$HOME/.local install
```

`make install` copies:

| From | To |
| :--- | :--- |
| the four programs | `PREFIX/bin` |
| `data/`, `dustData/`, `dataPDR/` (with `dataPDR/h2/`) and `benchmarks/` | `PREFIX/share/mocassin/` |
| `examples/` | `PREFIX/share/doc/mocassin/` |
| `man/mocassin.1` | `PREFIX/share/man/man1` |

Two rules matter:

- **Run `make clean` before changing `PREFIX`.** Make does not rebuild the objects for a
  new prefix, so the binaries would keep reading the old one.
- **Keep `PREFIX` under about 90 characters.** A longer data path is truncated, that
  ion's data are skipped without a message, and the run crashes at start-up
  ({devlog}`D-416`).

Use a separate `PREFIX` for a second build you want to keep apart, for example a
development branch. Installing into the same prefix replaces the data that runs made
with the first build read.

The atomic data in `data/` are CHIANTI 10.1, with some ions from Cloudy's Stout
database ({devlog}`D-330`). The chemistry's species, reaction rates and coolant data are
in `dataPDR/`, and the H₂ data, copied unmodified from Cloudy c25.00, in `dataPDR/h2/`.
A PDR run finds them through `pdrDataDir`, which defaults to the installed copy
({src}`pdr_mod.f90::h2LevelModel@"h2Dir = trim(pdrDataDir)"`).

## Checking a build

The binaries print the version they were built from at start-up: `pdr-coupling-v2.0` at
the tag, `pdr-coupling-v2.0-<n>-g<hash>` for a later commit, with `-dirty` if the tree had
uncommitted changes. The string is compiled into the main program's object, so
build from `make clean` when it must identify the binary; outside a git checkout it
is empty.

A PDR build also has `pdrSmokeTest`, a one-cell chemistry test. It reads the network
from `chemfiles/`, a link to `dataPDR/` in the directory it is run from:

```bash
make PDR=1 PDRGEOM=3D pdrSmokeTest
ln -sfn dataPDR chemfiles && ./pdrSmokeTest
```
