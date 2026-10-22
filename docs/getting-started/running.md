# Running a model

## The run directory

MOCASSIN reads `input/input.in` from the directory it is started in
({src}`set_input_mod.f90::readInput@"in_file = 'input/input.in'"`) and writes into
`output/`, which it does **not** create: a run without it stops at once. Any other input
file (abundances, density grid, dust species and sizes, a source list) is named in
`input.in` by its path relative to the run directory, conventionally inside `input/`.

```text
myrun/
├── input/
│   ├── input.in          the keywords, one per line
│   ├── abun.in           nebComposition: 30 abundances by number relative to H
│   ├── density.dat       densityFile (optional)
│   ├── dust_species.dat  dustFile, first file
│   └── dust_sizes.dat    dustFile, second file
└── output/               create it before the run
```

{doc}`../user-guide/keywords` lists every keyword `readInput` accepts, with its default
and the code that reads it. A keyword it does not know is reported in the log and
ignored. A line starting with `#` is a comment.

## Starting a run

```bash
cd myrun
mkdir -p output
mpirun -np <ranks> mocassin > run.log 2>&1
```

The log records the version the binary was built from, the seed of the random numbers
(`randomSeed`; clock-seeded if none is given), and every iteration's convergence.

### Ranks and memory

**Every rank holds its own copy of the grid,** so memory grows with the number of ranks,
not with the work. For dust + gas + PDR at `nbins 600` the measured cost on the
development machine is ({devlog}`D-370`)

$$
M \approx (0.47\ \mathrm{GB} + 38\ \mathrm{kB}\times N_\mathrm{active})\times N_\mathrm{ranks}.
$$

A `symmetricXYZ` sphere has about 52% of its cube's cells active. The two PDR
benchmarks fit in 31 GB at 14 ranks: `hiipdr` (31³, 15,204 active cells) and
`pn150k` (41³, about 35,000). A larger grid needs fewer ranks. The H₂ level model stays
within this budget: the test problem's 4,661 active cells used 0.61–0.62 GB per rank,
against the formula's 0.65.

### Run time

In a 3D PDR run, the H₂ level model takes about half the time or more. In the v2.0 release
runs at 14 ranks:
- it took 22 of `hiipdr`'s 42 minutes (31³, 15 iterations);
- it took 98 of `pn150k`'s 149 minutes (41³, 18 iterations).

The ranks share its cells dynamically ({devlog}`H-011`).

## Convergence and stopping

The run stops when the **model-integrated test** passes ({devlog}`D-391`,
{devlog}`D-392`), or after `maxIterateMC` iterations. The test covers:
- the emission measures n_e n_i dV of every significant ion stage;
- the H⁰ contents, and in PDR runs the H₂ and CO contents;
- the temperatures weighted by n_e n(H⁺), n(H⁰) and n(H₂).

Each must have changed by less than `convTotals` (default 0.02) over the last three
iterations ({src}`iteration_mod.f90::cvTotalsUpdate`). Every iteration's values are in
`output/convergence.out`. The percentage of converged cells (the second number of
`maxIterateMC`) is reported, not tested.

To run a fixed number of iterations, for example to compare two builds, set
`convTotals 1.e-6` and `maxIterateMC <n> 90.` With `randomSeed`, the same build and
the same rank count reproduce a run exactly.

## Warm starts and post-processing

| Program | What it does |
| :--- | :--- |
| `mocassinWarm` | Resumes a run from the grid files in `output/` (`grid0`–`grid3.out`, `dustGrid.out` and, in a PDR build, `pdrGrid.out`, `pdrLineEm.out` and `h2Pop.bin`), with the same `input/`. It reads the input first, so the PDR state is restored only when the input still has `pdr`. |
| `mocassinOutput` | Rebuilds the output files (`lineFlux.out`, `temperature.out`, `ionratio.out`, …) from the grid files, without iterating. |
| `mocassinPlot` | Writes per-cell line luminosities (`plot.out`, `grid4.out`) for the lines listed in `input/plot.in`, for maps and cubes. In a PDR run it also maps the CO lines. |

The grid files are written when the convergence percentage passes `writeGrid`, and at
the end. {doc}`../user-guide/outputs` describes every file and the code that writes it.

## PDR runs

A PDR run needs a PDR build ({doc}`install`), dust in the model, and the `pdr` keyword.
The chemistry starts at iteration `pdrStartIter`, once the photoionisation has settled.
Typical additions to an `input.in`:

```text
pdr 1
pdrNetwork "reduced"
pdrZeta 5.e-17
pdrStartIter 4
pdrCoolants 4 "12c+.dat" "12c.dat" "16o.dat" "12co.dat"
```

Omit `pdrDataDir` so the installed `dataPDR/` is used. The benchmark inputs in
`benchmarks/pdr/` set it to an absolute path on the development machine: delete that line
or point it at your copy. {doc}`../user-guide/h2-manual` walks through a complete PDR +
H₂ run.
