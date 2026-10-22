# Benchmarks

The benchmark pages compare MOCASSIN-PDR with independent codes on fixed models. These
pages hold the two PDR models:

| Model | What it is | Reference |
| :--- | :--- | :--- |
| {doc}`hiipdr` | The H II region and PDR of {cite:t}`Bisbas2015`, §5.4: a 40 kK star in gas of $n_{\mathrm H}=100$ cm⁻³ with silicate grains, $31^3$ cells | Cloudy c25.00, and standalone 3D-PDR |
| {doc}`pn150k` | A 150 kK planetary nebula, $n_{\mathrm H}=10^3$ cm⁻³, MRN graphite grains, $41^3$ cells | Cloudy c25.00 |

Gas-only (the Lexington models of {cite:t}`Ercolano2003`) and dust-only benchmarks will
be added once they have been rerun with this release.

## What is compared

Both models are uniform spheres around one source, computed in one octant
(`symmetricXYZ`). Cloudy solves the same sphere in one dimension, with matched
abundances, grains and cosmic-ray ionisation. Its inputs are in the repository
(`benchmarks/pdr/hiipdr/cloudy/` and `benchmarks/pdr/pn150k/cloudy/`). MOCASSIN's cells
are compared with Cloudy's zones at the same visual extinction from the star, $A_V$.
At each $A_V$ the figures show:
- **MOCASSIN-PDR:** the median of the cells in log-spaced $A_V$ bins, finer through the
  ionisation front, and the band between their 16th and 84th percentiles. The band
  shows the cell-to-cell spread of the 3D model at one $A_V$: Monte Carlo noise, and the
  geometry of the rays.
- **Cloudy:** its zones, as a dashed line.

Every quantity is defined in each model's `PROVENANCE.json` (`docs/bench/data/<model>/`).
The conventions that matter:
- $n_{\mathrm H}=n(\mathrm H)+n(\mathrm H^+)+2n(\mathrm{H_2})$ in both codes;
- Cloudy's H₂ counts H₂ and H₂*;
- in the tables, a front is where the binned medians first cross ($x(\mathrm H^+)=x(\mathrm H^0)$
  for the ionisation front); $A_\mathrm{front}$, the smallest $A_V$ of the cells with
  $x(\mathrm H^+)<0.3$ and the dotted line in the figures, places the bins.

At fixed radius MOCASSIN's $A_V$ is lower than Cloudy's: by 1–4% in `hiipdr` (mostly a
constant 0.02–0.03 mag offset from the cell discretisation of the inner cavity) and by
3–4.5% in `pn150k`. Offsets measured in $A_V$ and in radius therefore differ, and the
profiles, compared at equal $A_V$, carry this shift.

Cells MOCASSIN flags and leaves out of the line emission (`lgBlack`, for example a cell
whose temperature reached the floor) are excluded from the statistics and counted on each page.

## The runs

The MOCASSIN results are the release runs of `pdr-coupling-v2.0` ({devlog}`D-429`,
{devlog}`D-430`):

- **Build.** The binary was built at commit `c1ea374`, whose `source/`, `Makefile` and
  `dataPDR/` are identical to the release commit `53c17eb`. It is the 3D build,
  `make PDR=1 PDRGEOM=3D all`.
- **Run settings.** 14 MPI ranks, `randomSeed 1001` and 6×10⁶ packets per iteration.
  `hiipdr` ran 15 iterations and `pn150k` 18. `convTotals 1.e-6` makes the run use every
  iteration of `maxIterateMC`, so the two models were compared at fixed iteration counts.
- **Inputs.** Each run's exact input is committed in `docs/bench/inputs/`, including
  `pn150k`'s abundance file with the trace elements set to zero.
- **Convergence.** At the end the largest change of the model-integrated quantities over
  the last three iterations was:
  - 2.04% in `hiipdr` (the Ne⁺ emission measure; 2.35% and 2.60% in the two iterations
    before), just above the default stopping tolerance of 2%, so at the default the run
    would not yet have stopped;
  - 1.55% in `pn150k` (the H⁰-weighted temperature), within it.

The Cloudy models are the {devlog}`D-396` runs of Cloudy c25.00. The committed inputs
match the physics commands of those runs exactly; `reduce.py --check-cloudy` verifies
this.

## How the pages are made

The figures and tables are built in two stages, so that Read the Docs, which cannot run
MOCASSIN, rebuilds them from committed data:

1. `docs/bench/reduce.py --manifest docs/bench/manifest.toml`, run locally, reads the
   runs and the Cloudy outputs and writes small CSV and JSON files to
   `docs/bench/data/<model>/`. It records the sha256 of every file it read
   (`PROVENANCE.json`). `--verify` re-reduces and checks that the committed data are
   reproduced byte for byte.
2. `docs/bench/plots.py` draws the figures from those files when the site is built.

To reproduce a run, build the release and run the committed input:

```bash
cp -r docs/bench/inputs/rel-hii31 /tmp/rel-hii31-input   # before checking out: v2.0 has no docs/
git checkout pdr-coupling-v2.0
make clean && make PDR=1 PDRGEOM=3D PREFIX=$HOME/.local/mocassin-v2.0 install
mkdir -p myrun/output && cp -r /tmp/rel-hii31-input myrun/input
# delete the pdrDataDir line from myrun/input/input.in
cd myrun && mpirun -np 14 $HOME/.local/mocassin-v2.0/bin/mocassin
```

With the same seed, rank count, compiler and machine the run reproduces the published
one exactly; elsewhere it differs at the level of the Monte Carlo noise.
