# Benchmarks

The benchmark pages compare MOCASSIN-PDR with independent codes on fixed models:

| Model | What it is | Reference |
| :--- | :--- | :--- |
| {doc}`lexington` | The four photoionised nebulae of the Lexington 2000 workshop, two H II regions and two planetary nebulae, gas only, $13^3$ cells each | the seven codes of {cite:t}`Ercolano2003`, Tables 4–7 |
| {doc}`dust-1d` | Three spherical dust shells around a 2,500 K star, dust only (Draine & Lee silicate), $\tau(1\,\mu\mathrm{m})=1$, 10, 100 | DUSTY 2.01 and MOCASSIN 2005, Fig. 1 of {cite:t}`Ercolano2005` |
| {doc}`hiipdr` | The H II region and PDR of {cite:t}`Bisbas2015`, §5.4: a 40 kK star in gas of $n_{\mathrm H}=100$ cm⁻³ with silicate grains, $31^3$ cells | Cloudy c25.00, and standalone 3D-PDR |
| {doc}`pn150k` | A 150 kK planetary nebula, $n_{\mathrm H}=10^3$ cm⁻³, MRN graphite grains, $41^3$ cells | Cloudy c25.00 |

The 2D dust discs of {cite:t}`Pascucci2004` wait for that benchmark's data files ({doc}`dust-1d`
explains why). The rest of this page describes the two PDR models; {doc}`lexington` and
{doc}`dust-1d` describe their own method and runs.

## What is compared

Both models are uniform spheres around one source, computed in one octant
(`symmetricXYZ`). Cloudy solves the same sphere in one dimension, with matched
abundances, grains and cosmic-ray ionisation. Its inputs are in the repository
(`benchmarks/pdr/hiipdr/cloudy/` and `benchmarks/pdr/pn150k/cloudy/`).
The sphere is static (`sphere static`, {devlog}`D-458`), as MOCASSIN's nebula is: it has no
velocity field. Cloudy's default sphere assumes expansion, which lets lines leave through the
central hole ({devlog}`D-457`). In `pn150k` that sent the nebula's Ly$\alpha$ into the PDR and
doubled Cloudy's far-ultraviolet field there. These pages compared with the expanding runs
of {devlog}`D-396` until {devlog}`D-459`; {devlog}`D-458` sets the two geometries side by side. MOCASSIN's cells
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

Cells MOCASSIN flags and leaves out of the line emission (`lgBlack`: a cell whose thermal
balance was not reached or reached 30,000 K, or whose ionisation balance failed) are excluded from the statistics and counted on each page.

## The runs

The MOCASSIN results are the release runs of `pdr-coupling-v2.0` ({devlog}`D-429`,
{devlog}`D-430`); releases `pdr-coupling-v2.0.1` and `pdr-coupling-v2.0.2` compute exactly the same
for a `pdr` run ({devlog}`D-438`), apart from `SED.out` in v2.0.2 ({devlog}`D-441`), which these
pages do not use:

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

The Cloudy models are the {devlog}`D-458` runs of Cloudy c25.00: the inputs of {devlog}`D-396`
with `sphere static`. The committed inputs match the physics commands of those runs exactly;
`reduce.py --check-cloudy` verifies this.

(sec:bench-since)=
### Since the release

Two fixes made after `pdr-coupling-v2.0.2` change what these models compute: the collisional
excitation of H I is emitted as well as cooled ({devlog}`D-447`), and a Q file's largest grain and
the charge transfer of the heavy elements' higher stages are handled correctly ({devlog}`D-450`).
The pages still show the release runs. {devlog}`D-451` reran both models on the code with these
fixes, with the same seed, packets, iterations and ranks:

- **`hiipdr`** is unchanged within the Monte Carlo noise: H$\beta$ ×0.999, the line ratios
  within 0.5%, and the H/H₂ and C⁺/C transitions where they were.
- **`pn150k`** changes. H$\beta$ goes from 0.959 to 0.942 of Cloudy's, and the Case B
  recombinations from 0.974 to 0.957 of the star's hydrogen-ionising photons (Cloudy: 0.991).
  The graphite now absorbs as its Q file says, so the far-ultraviolet reaches deeper:
  - the H/H₂ transition moves from $A_V$ 0.393 to 0.419 (Cloudy: 0.362);
  - the gas at $A_V$ 0.20, 0.30 and 0.65 is 13%, 4% and 3% warmer;
  - H₂ 1-0 S(1)/H$\beta$ rises by 10%;
  - [C I] 609 μm and CO 2-1 fall to 0.81 and 0.71 of the values shown.

A third change moves the escaping lines out of `SED.out` into `SEDlines.out` ({devlog}`D-454`).
It changes no other output: `hiipdr` rerun with it matches the {devlog}`D-451` run byte for byte
in every file but `SED.out`. No page here reads a gas model's `SED.out`, and the dust shells of
{doc}`dust-1d` emit no lines.

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
