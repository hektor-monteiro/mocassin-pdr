# Running a PDR + H2 model: a short manual

This manual takes MOCASSIN's standard test problem
(`benchmarks/test_Problem`) and runs it as a complete model with the
photodissociation-region chemistry and the H2 level model:
  - **MOCASSIN:** 3D Monte Carlo photoionization and dust radiative transfer.
  - **3D-PDR's chemistry and thermal balance:** the reduced network of 33
    species, solved in every cell.
  - **The H2 level model:** the 302 rovibrational levels of H2, solved in
    MOCASSIN's own radiation field.

The test problem is a 200 kK star of 7×10³⁷ erg/s at the centre of a 21³
octant (`symmetricXYZ`), 0.26 pc in radius. Its gas density comes from a
file: 10³ and 10⁴ cm⁻³, and a box-shaped region of 8×10⁴ cm⁻³ whose inner
face is 1.2×10¹⁷ cm from the star along the axes. That dense gas is thicker
than the star can ionize, and its neutral part is the PDR. Whether that
part becomes molecular depends on the dust (section 3.1).

The input of section 3 was run as written on 2026-10-15 (DEVLOG-H2 H-035),
with a binary built as in section 2; that prefix's data were already
installed, so `make install` itself was not repeated for the test. The
results are under "What the test run gave".

## 1. What you need

  - **A Fortran compiler with MPI.** The Makefile uses `mpif90.openmpi`;
    override it with `make FC=... LD=...`. Open MPI is assumed below.
  - **SUNDIALS 7.x** with CVODE, which the chemistry uses. The Makefile
    looks in `$(HOME)/software/sundials-7.8.0`; override it with
    `SUNDIALS_DIR=...`. The path is written into the binary with `-rpath`,
    so `LD_LIBRARY_PATH` is not needed at run time.
  - **The `h2-model` branch.** The H2 level model lives only there.
    `pdr-photoionization` has the PDR chemistry without it.
  - **Python 3 with numpy, astropy and matplotlib**, for the map tool
    (section 8). The checks of section 7 need only Python 3.

## 2. Build and install

    cd mocassin_h2                       # a checkout of branch h2-model
    make clean
    make PDR=1 PDRGEOM=3D PREFIX=$HOME/.local/mocassin_h2 install

  - **`PDRGEOM=3D` is required for H2.** The 3D build traces the chemistry's
    columns along twelve rays from every cell. The 1D build (`PDRGEOM=1D`,
    the default) is for slabs, and it skips the H2 level model with a
    message in the log.
  - **`PREFIX` is compiled into the binary.** It reads its atomic data from
    `PREFIX/share/mocassin/data` and its dust data from
    `PREFIX/share/mocassin/dustData`. It also reads `dataPDR` from there
    when the input does not name one. The second line of every run log
    names the directories the binary uses.
  - **`make install` builds all four programs** with the flags given:
    `mocassin`, `mocassinWarm`, `mocassinOutput` and `mocassinPlot`. It
    copies them to `PREFIX/bin`, and copies `data`, `dustData`, `dataPDR`
    and `benchmarks` to `PREFIX/share/mocassin`. Repeat it after changing
    the data or the code.
  - **Run `make clean` between builds with different flags.** The object
    files are shared, and a stale object from another flavour does not
    always fail to link.

## 3. Set up the model

    mkdir -p ~/models/tp-pdr && cd ~/models/tp-pdr
    cp -r <checkout>/benchmarks/test_Problem/input .     # <checkout>: your mocassin_h2
    mkdir output                         # MOCASSIN does not create it

MOCASSIN reads `input/input.in` relative to the directory it runs in, and
writes into `output/`. The file paths inside the input (`input/...`) are
relative to the same directory. The dust files (`dustData/...`) are read
under `PREFIX/share/mocassin`.

### 3.1 The dust files

Replace the test problem's two dust files with the pn150k fixture's:

    cp <checkout>/benchmarks/pdr/pn150k/input/dust_species.dat input/
    cp <checkout>/benchmarks/pdr/pn150k/input/dust_sizes.dat input/

These are graphite grains from 0.005 to 0.25 µm in one six-column Q file
(`dustData/grph-avg.cat`), over a size grid that spans exactly those
sizes. The test problem's own dust cannot make H2. It fails in two ways,
both measured (DEVLOG-H2 H-035):

  1. **Its PAHs are refused.** `PAHneu_30.cat` is a Q file with five
     columns: efficiencies, but no Im(m). A grain's photoelectric yield
     needs Im(m), and a PDR's gas temperature is set mostly by photoelectric
     heating. So with photoelectric heating on, the default, the run stops:

         ! makeDustXsec: dustData/PAHneu_30.cat is a Q file with no Im(m) column, so no photoelectric yield can be built for it.

  2. **Its silicates alone form no H2.** The test problem's size grid runs
     from 10⁻⁴ to 5 µm, and its silicates cover only 0.07–50 µm. The dust
     temperature the chemistry reads for H2 formation is a number-weighted
     mean over the whole grid, so the empty small bins pull it down to
     about 10⁻⁶ K. No H2 then forms on grains anywhere. The log shows it as
     `4661 cells solved (4661 without grain formation)`: the shell stays
     atomic, with x(H2) ≤ 2×10⁻⁷. Large grains also give little area for
     H2 formation and little FUV extinction.

The rules to take from this, for any dust:
  - **`dust_sizes.dat` must span exactly its species' sizes**
    (`benchmarks/pdr/README.md`).
  - **A Q file needs a sixth column, Im(m)**, if the grains are to heat the
    gas. `tools/mkqfile.py` writes one from optical constants; see
    `doc/dust.md`. An n,k file (`.nk`) carries its own.
  - **Check the log** once the chemistry starts:
      - `[D195] H2 formation grain area at the calibration cell` gives the
        grain area per H, beside the 8.5×10⁻²² (silicate) and 7.9×10⁻²²
        (carbon) cm² that Cazaux & Tielens assume.
      - `h2LevelModel: sweep ... (0 without grain formation)` says that
        every cell forms H2 on grains.

### 3.2 `input/input.in`

The test problem as distributed, with four changes and a PDR block added
at the end:

    TStellar 200000.
    TeStart 20000.
    contShape  blackbody
    multiChemistry 2 "input/abunPN150.in" "input/abunPN150.in"
    densityFile "input/test_gas_21x21x21.dat"
    maxIterateMC  30 90.
    nPhotons 1e7
    nx 21
    ny 21
    nz 21
    nbins 700
    LStar 70.
    nuMax 15.
    nuMin 1.001e-6
    Rin 0.
    Rout 8.0e17
    convLimit 0.05
    dustFile  'input/dust_species.dat' 'input/dust_sizes.dat'
    MdMg constant 2.4827e-3
    inclination 1 1.57 0.
    resLinesTransfer 50.
    symmetricXYZ
    pdr 1
    pdrDataDir "/home/<you>/.local/mocassin_h2/share/mocassin/dataPDR"
    pdrNetwork "reduced"
    pdrZeta 5.0e-17
    pdrCoolants 4 "12co.dat" "12c+.dat" "12c.dat" "16o.dat"
    pdrStartIter 4
    randomSeed 1001

The four changes:

  1. **`autoPackets 0.20 1.5 2e18` is removed.** It multiplies the packets by
     1.5 in every iteration in which the share of converged cells is under
     95% and has improved by 20% or less. In a PDR model that share levels
     off between about 70% and 90%: the cells in and beyond the transition
     zones keep moving by more than `convLimit`. So the packets would grow
     every iteration. Set a fixed `nPhotons` instead.
  2. **`maxIterateMC 15 90.` becomes `30 90.`** A PDR run stops on the
     model-integrated test: the largest change in the integrated quantities
     over the last iterations, under `convTotals` (2% by default). The
     integrated quantities are the emission measures, the species contents
     and the mean temperatures, tabulated in `output/convergence.out`.
     `maxIterateMC N x` only sets a cap of N iterations. The share of
     converged cells, x, is reported but does not stop the run.
  3. **`Ndust file "input/test_dust_21x21x21.dat"` becomes
     `MdMg constant 2.4827e-3`.** The Ndust file gives grain number densities
     for the test problem's own grains. `MdMg` gives the dust-to-gas ratio
     by mass, here the pn150k fixture's, and the code turns it into a grain
     density in each cell from that cell's gas density.
  4. **The PDR block is added.** The keywords are listed below.
     `pdrDataDir` must be an absolute path; the input file does not expand
     `$HOME`. It can be left out after `make install`, but the map tool
     (section 8) needs it.

### 3.3 The PDR keywords

| keyword | what it does | default |
|---|---|---|
| `pdr 1` | Switches on the chemistry and its thermal balance in every cell. In a 3D `h2-model` build it also switches on the H2 level model. | off |
| `pdrNetwork "reduced"` | Names the network. Only the reduced network (33 species) is compiled in, so this can only check, not choose. | `reduced` |
| `pdrDataDir "<dir>"` | The rates, species and coolant files. The H2 data are in its `h2/`. | `PREFIX/share/mocassin/dataPDR` |
| `pdrZeta` | The cosmic-ray ionization rate [s⁻¹]. | 1×10⁻¹⁶ |
| `pdrCoolants N f1 ... fN` | LAMDA files of the coolants whose level populations the chemistry solves. CO's lines go to `lineFluxMol.out`. For C⁺, C and O, MOCASSIN's own atoms take the chemistry's collision rates (H, H⁺, He, H2) and escape probabilities, so their fine-structure lines in `lineFlux.out` include the neutral gas. Without it `lineFluxMol.out` is empty and those lines escape freely. | none |
| `pdrStartIter` | The MC iteration in which the chemistry starts. The iterations before it are MOCASSIN's alone, which lets the ionized gas settle first. | 1 |
| `randomSeed` | Fixes the random numbers. Two runs with the same input, binary and number of ranks then give identical output. | from the clock |
| `convTotals` | The limit of the integrated stop test. | 0.02 |
| `pdrVturb` | Microturbulent velocity [km/s]. | 1.0 |
| `pdrTmin`, `pdrTmax` | Floor and ceiling of the gas temperature in the chemistry [K]. | 1, 2×10⁴ |
| `pdrDiagRates 2` | Also writes every reaction's rate per cell to `output/pdrReacRates.out`. | 0 |

**The H2 level model has no keyword.** It runs once per iteration (one
sweep), giving the chemistry its H2 photodissociation rate and the thermal
balance its H2 heating. On the finished model it runs again, to
convergence in up to 12 sweeps, before the outputs are written. Its data
(`dataPDR/h2`) come from Cloudy c25.00's large H2 model; the sources are
in `dataPDR/h2/README.md`.

**Older inputs.** Some keywords from older inputs are now ignored, with a
message. The test problem's own `resLinesTransfer` is one: with dust and
gas, resonance lines are always destroyed by the local dust. Others stop the run, because they chose physics or constants the
model now takes from itself: `pdrZoneLimit`, `pdrMetallicity`,
`pdrGrainRadius` and the like.

## 4. Memory and ranks

Measured for dust + gas + PDR runs at `nbins 600`: **about 0.47 GB plus
38 kB per active cell, per MPI rank.** Every rank holds the whole grid, so
more ranks multiply the memory. They do not share it.

The test problem has 4,661 active cells: `Rout` cuts the 21³ cube to an
octant of a sphere. The formula gives 0.65 GB per rank; the test run used
0.61–0.62 GB per rank, 8.6 GB at 14 ranks. Use the number of physical
cores, and fewer ranks for a larger grid. At 14 ranks, about 46,000 active
cells fit in 31 GB.

## 5. Run

    cd ~/models/tp-pdr
    mpirun -np 14 $HOME/.local/mocassin_h2/bin/mocassin > run.log 2>&1

  - **For a long run,** detach it from the terminal, with `nohup ... &` or
    `systemd-run --user`. With `systemd-run`, give the full path of every
    program and set the directory, since its environment is minimal.
  - **Open MPI 5 with UCX** warns that its one-sided component failed and
    falls back to another; the warning is harmless.
    `mpirun --mca osc ^ucx ...` keeps it out of the log.
  - **Each iteration** ends with a summary in the log. Its lines include
    `Iteration N ; finished at hh:mm:ss`, the share of converged cells, the
    share of cells whose balance was not reached, and the stop test:

        ! iterateMC: [Summary] Iteration  10 ; integrated quantities: largest change over the last 3 iterations  56.697% (O3+), limit  2.00%: NOT converged

  - **The run stops** when that change falls under the limit, with

        ! iterateMC: [talk] convergence reached after N iterations. & Finishing up ...

    or at the cap, with `maximum number of iterations reached`. At the cap,
    raise it or continue the run (below). Either way the H2 level model then
    solves the finished model, the outputs are written, and the log ends
    with `total run time per processor` and
    `! MoCaSSin: end simulation reached - clean exit -`.
  - **To continue a run,** run `$HOME/.local/mocassin_h2/bin/mocassinWarm`
    in the same directory. It resumes from `output/`: the grid files, the
    chemistry's `pdrGrid.out`, and the H2 populations in `h2Pop.bin`. The
    populations are read when they describe the same grid and levels;
    otherwise they start from Boltzmann, and the log says so.
      - **It counts iterations from 1 again,** so `maxIterateMC` is the
        number of further iterations it may take. Its stop test starts
        over too, so allow it several.
      - **The chemistry resumes in its first iteration,** from the saved
        abundances, whatever `pdrStartIter` says (D-393).

## 6. What the run writes (`output/`)

| file | content |
|---|---|
| `lineFlux.out` | MOCASSIN's emission lines (H I, He, the forbidden lines), absolute and over Hβ. With the coolants on, it includes [C II] 158 µm, [C I] 609 and 370 µm and [O I] 63 and 146 µm from the neutral gas. |
| `lineFluxMol.out` | CO's rotational lines integrated over the grid, each with its levels, wavelength, E_up/k, L [erg/s] and L/Hβ |
| `lineFluxH2.out` | Every line of H2's ground electronic state above 10⁻⁶ of the strongest: v, J of both levels, λ, E_up/k, L and L/Hβ. Optically thin, with no dust extinction. |
| `h2Cells.out` | Per cell: n(H2), T, the photodissociation rate from the levels and from the chemistry, the pumping rate, the ortho/para ratio and the heating terms |
| `h2Pop.bin` | Every cell's level populations, as a raw stream: int32 nCells, nLev; int32 v(nLev), J(nLev); real64 E(nLev) [cm⁻¹]; then real32 populations, nLev per cell, in the order of `h2Cells.out` |
| `pdrGrid.out` | Per grid point (i, j, k order), two lines. The first holds χ_FUV, A_V, the chemistry's cooling and heating, and the photoelectric heating. The second holds 33 abundances per H nucleus, in the order of `dataPDR/species_reduced.d`. |
| `pdrLineEm.out` | Per grid point, each coolant transition's escaping emission [erg s⁻¹ cm⁻³], then its escape probability |
| `pdrRad.out` | Per cell: A_V from the star, the line and field bands, T_dust |
| `pdrFUV.out` | The FUV field per cell, in Draine units, with its diffuse part |
| `thermBudget.out` | Per cell: every heating and cooling term |
| `convergence.out` | The integrated quantities of each iteration, which the stop test compares |
| `grid0.out` | The grid's axes, then per cell: active, converged, and flagged (the cell's balance was not reached) |
| `SED.out`, `temperature.out`, `ionratio.out`, `summary.out` | MOCASSIN's usual outputs |

## 7. Checks after a run

**Did it stop on the test?** Read the stop line (section 5). A run that hit
the cap is not converged in the integrated quantities.

**Flagged cells.** A cell whose thermal or ionization balance was not
reached, or whose T reached 3×10⁴ K, is flagged. MOCASSIN leaves flagged
cells out of `lineFlux.out` and `lineFluxMol.out`. `lineFluxH2.out` still
counts them. The log gives their share each iteration; to count them:

    python3 - <<'EOF'
    t = open('output/grid0.out').read().split()
    nx, ny, nz = int(t[1]), int(t[2]), int(t[3])
    off, n = 7 + nx + ny + nz, nx * ny * nz
    act, flag = t[off:off + 3*n:3], t[off + 2:off + 3*n:3]
    print('active', sum(int(a) > 0 for a in act),
          'flagged', sum(int(a) > 0 and int(f) >= 1 for a, f in zip(act, flag)))
    EOF

A few flagged cells are normal. The fixtures have 0 to 3; the test run of
section 3 has 19, which carry under 10⁻¹³ of any H2 or CO line.

**The hydrogen budget.** In every cell, the hydrogen in all species must
sum to 1 per H nucleus. This is the sharpest single test of the coupling.
The fixtures and both test runs meet it to 4×10⁻⁹. The short form
x(H) + 2x(H2) + x(H⁺) leaves out the hydrogen in molecules such as water,
which reaches 1.5×10⁻⁵ in the test's dense molecular gas. So count every
species:

    python3 - <<'EOF'
    import re
    DATA = '/home/<you>/.local/mocassin_h2/share/mocassin/dataPDR'
    sp = [l.split(',')[1].strip() for l in open(DATA + '/species_reduced.d') if l.strip()]
    def nh(s):      # hydrogen atoms in a species name such as H3O+ or CH4
        return sum(int(k or 1) for el, k in re.findall(r'(He|Mg|[A-Z])(\d*)', s.rstrip('+-')) if el == 'H')
    L = open('output/pdrGrid.out').read().split('\n')[1:]
    dev = 0.
    for k in range(1, len(L), 2):
        x = [float(v) for v in L[k].split()]
        if len(x) == len(sp) and sum(x) > 0:
            dev = max(dev, abs(sum(nh(s) * v for s, v in zip(sp, x)) - 1))
    print('largest |H budget - 1| over the cells:', dev)
    EOF

**Noise.** MOCASSIN is Monte Carlo, so two runs with different seeds
differ. With `randomSeed` and the same number of ranks, a run repeats
exactly, so an A/B test of an input change is clean. To see how much a
number depends on the packets, run it at 4× `nPhotons`.

## 8. Maps of the H2 and CO lines

    cd mocassin_h2
    python3 tools/h034_maps.py ~/models/tp-pdr --png --cubes

This writes, in the run's `output/`:
  - **`maps_h2co.fits`:** maps along z, x and y of eight H2 lines and
    CO 1-0 to 6-5, in erg s⁻¹ cm⁻² sr⁻¹, with a linear WCS in pc. Each map's
    header carries the line's total from the tables (`LTOT`), from the map
    (`LMAP`) and from the flagged cells (`LFLAG`).
  - **`maps_h2co_cubes.fits`** (with `--cubes`): the emissivity per cell.
  - **`maps_h2co.png`** (with `--png`): a quick look along z.

Other lines can be chosen with `--h2 "vu Ju vl Jl; ..."` and
`--co "1-0,2-1,..."`.

What the maps are:
  - **Intrinsic,** with no dust extinction and no velocity axis. CO is each
    cell's own escaping emission.
  - **Mirrored.** The octant is unfolded, so each map is symmetric about
    its axes and its noise appears four times.
  - **Without the flagged cells,** as MOCASSIN's own line tables are made.
  - **Checked against the tables:** each map's integral over the sky
    returns its line's total.

## 9. Known limits

  - **The diffuse field and the line escape use twelve fixed directions.**
    In maps of n(H2) or of CO's abundance, this leaves a pattern of about
    10% along the z axis, which the line maps do not show
    (`doc/pdr-status.md`, L-53).
  - **An ionization front narrower than a cell** makes cells at one radius
    differ by direction (production DEVLOG D-412).
  - **Where CO is still a trace at the grid's edge,** a CO map's brightness
    follows the boundary of the model. Make the grid reach past the CO
    transition if CO is the point.
  - **The open questions are listed in `doc/pdr-status.md`.** The
    development history is in `DEVLOG.md` (the PDR coupling) and
    `DEVLOG-H2.md` (the H2 level model).

## What the test run gave

Two runs on 2026-10-15, each with 14 ranks and branch h2-model at
`pdr-coupling-v1.1-229-geb8e28a` (DEVLOG-H2 H-035):
  - **"As written":** section 3 exactly, with the pn150k fixture's grains
    (`runs/h035-testproblem-c`).
  - **"Silicates alone":** the test problem's own dust with its PAHs
    dropped and its Ndust file kept (`runs/h035-testproblem-b`).

| | as written | silicates alone |
|---|---|---|
| stop | integrated test at iteration 17 (1.76%, n(CO)) | integrated test at 17 (1.73%, O²⁺) |
| time per processor | 33 min 38 s | 10 min 24 s |
| memory at 14 ranks | not measured | 8.6 GB |
| active / flagged cells | 4,661 / 19 | 4,661 / 3 |
| hydrogen budget, all species | 3.9×10⁻⁹ | 4.1×10⁻⁹ |
| cells with x(H2) > 0.1 | 2,259 (x(H2) up to 0.5) | none (x(H2) ≤ 2×10⁻⁷) |
| largest x(CO) | 3.0×10⁻⁴, all the carbon | 8×10⁻¹¹ |
| largest A_V from the star | 10.3 | 1.45 |
| T_dust | 27–281 K | about 10⁻⁶ K (section 3.1) |
| Hβ [erg/s] | 4.65×10³⁵ | 4.90×10³⁵ |
| H2 1-0 S(1) 2.12 µm / Hβ | 8.1×10⁻⁵ | 1.7×10⁻⁶ |
| H2 0-0 S(1) 17.0 µm / Hβ | 1.1×10⁻⁴ | 6.3×10⁻¹⁰ |
| CO 1-0 [erg/s] | 1.35×10³⁰ | 1.4×10¹⁹ |

Most of the run's time is the H2 level model: 80 s per sweep in each
iteration once there is H2 to solve, against 24 s with none.

The maps of the "as written" run return their tables within 1.2×10⁻⁵:
`python3 tools/h034_maps.py runs/h035-testproblem-c --png --cubes`. Their
H2 lines trace the inner face of the dense gas, about 0.06 pc out. That gas
is box-shaped, so the ring is square. CO fills the disc out to the edge of
the grid.
