# Tutorial: a dust, gas and PDR model

This tutorial runs a complete model: a hot star ionising a dusty, structured nebula whose dense gas
turns into a photodissociation region (PDR) and then into molecular gas, with the chemistry and the
H₂ level model solved in every cell. It takes about 25 minutes on 14 cores and 9 GB of memory. It
covers setting the model up, running and monitoring it, checking it, slicing it, mapping its H₂ and
CO lines, and continuing it with a warm start.

The model is MOCASSIN's test problem (`benchmarks/test_Problem`) with a PDR. The run shown was made
with release `pdr-coupling-v2.0.1`. The tutorial's inputs and scripts (`examples/tutorial/`, and
the versions of `tools/mocread.py` and `tools/h034_maps.py` it uses) came after that release
({devlog}`D-440`), so use release `pdr-coupling-v2.0.2`, which has them and computes this model as
v2.0.1 did (it changes only `SED.out`, and only for a source in an inactive cell,
{devlog}`D-441`). The {doc}`quickstart <../getting-started/quickstart>` is a shorter first look.

:::{note}
The code after release `pdr-coupling-v2.0.2` does not compute this model as the run shown here.
It emits the collisional excitation of H I that the gas cools by ({devlog}`D-447`), and it reads
the largest grain of a Q file correctly, which this model's graphite file needed ({devlog}`D-450`,
{lim}`L-91`). This model has not been rerun with them. On the test problem without a PDR,
{devlog}`D-447` lowered H$\beta$ by 15%. On `pn150k`, whose graphite is the same file, the graphite
fix moved the H/H₂ transition deeper and cut CO 2-1 by about a third ({ref}`sec:bench-since`).
Expect the numbers below to differ.
:::

## 1. The model

- **The star:** a 200,000 K blackbody of $7\times10^{37}$ erg s⁻¹ at the centre.
- **The gas**, from a density file (`test_gas_21x21x21.dat`):
  - a **ring** of $n_{\mathrm H}=8\times10^4$ cm⁻³ at cylindrical radii 0.039–0.117 pc
    ($1.2$–$3.6\times10^{17}$ cm), within 0.065 pc of the mid-plane;
  - inside a **slab** of $10^4$ cm⁻³ of the same thickness, out to the edge of the model;
  - in a **halo** of $10^3$ cm⁻³ above and below the slab, which also fills the small cavity around
    the star.
- **The grid:** one octant (`symmetricXYZ`) of $21^3$ cells, cut to a sphere of radius
  $8\times10^{17}$ cm (0.26 pc), which leaves 4,661 active cells.
- **The abundances:** those of the Lexington PN150 model (`abunPN150.in`: He/H 0.10, C 3×10⁻⁴,
  N 1×10⁻⁴, O 6×10⁻⁴, …). The input names the file twice with `multiChemistry 2`, and the density
  file assigns the mid-plane cells to the first copy and the rest to the second. The two copies are
  the same file, so this changes nothing physically; it only makes the line tables list the
  mid-plane and the rest as separate components beside the total.
- **The dust:** graphite grains of 0.005–0.25 µm (`dustData/grph-avg.cat`) at a dust-to-gas mass
  ratio of $2.48\times10^{-3}$ (`MdMg`), the grains of the
  {doc}`150 kK nebula benchmark <../benchmarks/pn150k>`. Section 3 explains why these and not the
  test problem's own.

```{figure} _figures/tutorial-b_slices_xz.png
:name: fig-tut-xz
:alt: Slices of the model through the x-z plane: hydrogen density, electron temperature, ionised fraction, molecular fraction, CO abundance and A_V.
:width: 100%

The finished model in the x–z plane, through the star (the octant mirrored to the full plane;
blank cells are outside the model or flagged). The star's radiation escapes above and below the
slab and ionises a bipolar cone of the halo (top right), while the ring, the slab and part of the halo
turn molecular (bottom left); in the ring all the carbon is in CO (bottom middle). $A_V$ (bottom
right) is measured from the star; the slab's faces and the halo are lit mostly by diffuse radiation
from the ionised cone, so their shielding is less than this $A_V$ suggests. Made by
`examples/tutorial/plot_slices.py`.
```

## 2. Build and install

The 3D PDR build is needed, because the H₂ level model is compiled into it only:

```bash
make clean
make PDR=1 PDRGEOM=3D install        # PREFIX defaults to $HOME/.local (macOS: /usr/local)
```

The commands below write `$PREFIX` for that directory and assume `$PREFIX/bin` is on your `PATH`.
The scripts need Python 3 with numpy, and matplotlib for the figures (astropy too for the maps).
{doc}`../getting-started/install` covers SUNDIALS, `PREFIX` and the other builds. Keep `PREFIX`
under about 90 characters ({devlog}`D-416`).

## 3. Set up the run

```bash
cp -r $PREFIX/share/doc/mocassin/examples/tutorial ~/tutorial
cd ~/tutorial
mkdir -p output                      # MOCASSIN does not create it
```

`input/input.in` is the test problem's own input with these changes:

```text
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
symmetricXYZ
pdr 1
pdrNetwork "reduced"
pdrZeta 5.0e-17
pdrCoolants 4 "12co.dat" "12c+.dat" "12c.dat" "16o.dat"
pdrStartIter 4
randomSeed 1001
```

1. **`autoPackets` is removed.** It raises the packets whenever the share of converged cells is below
   95% and grows slowly. In a PDR model that share stays far below 95% (30% at the end of this run),
   so the packets would grow almost every iteration. A fixed `nPhotons` is used instead.
2. **`maxIterateMC 30 90.`** A PDR run stops when the model's integrated quantities (emission
   measures, species contents, mean temperatures) change by less than 2% over three iterations
   ({ref}`convergence <running-convergence>`); 30 is only the cap, and the 90 (a share of converged
   cells) is reported, not tested.
3. **The dust.** `dust_species.dat`, `dust_sizes.dat` and `MdMg` replace the test problem's
   astrosilicate and PAH grains and their `Ndust` file. Those grains carry little surface for
   forming H₂, $3.4\times10^{-23}$ cm² per H, a fiftieth of the interstellar value, and give a tenth
   of the interstellar $A_V$ per H: with them the PDR stays atomic (section 8). The graphite gives
   $5.7\times10^{-22}$ cm² per H and a molecular PDR.
4. **The PDR block** at the end (section 4) switches on the chemistry and the H₂ model, and
   `randomSeed` makes the run repeatable. It names no `pdrDataDir`, so the installed `dataPDR/` is
   used.
5. **`resLinesTransfer` is removed**: it is retired and ignored ({devlog}`D-376`).

**Any other dust works too.** A Q-file species (`.cat`) needs a sixth column, Im(m), for its grains
to heat the gas, and MOCASSIN stops if it is missing; an optical-constant file (`.nk`) carries its
own. The size grid should span the species' sizes. {doc}`../user-guide/dust-inputs` explains both.
Once the chemistry starts, the log lines after `[D195] H2 formation grain area at the calibration
cell` give the grain surface per H that H₂ formation uses, for silicates and for carbonaceous grains.

## 4. The PDR keywords

| Keyword | What it does |
| :--- | :--- |
| `pdr 1` | Switches on the chemistry and its thermal balance in every cell; in the 3D build, also the H₂ level model. |
| `pdrNetwork "reduced"` | Names the network. Only the reduced network (33 species) is compiled in, so this checks rather than chooses. |
| `pdrZeta 5.0e-17` | The cosmic-ray ionisation rate (s⁻¹), in the chemistry network's (UMIST) normalisation. |
| `pdrCoolants 4 ...` | The coolants whose level populations the chemistry solves (LAMDA files): CO, C⁺, C and O. CO's lines go to `lineFluxMol.out`; the C⁺, C and O fine-structure lines in `lineFlux.out` then include the neutral gas. |
| `pdrStartIter 4` | The iteration in which the chemistry starts, so that the ionised gas settles first. |
| `randomSeed 1001` | Fixes the random numbers: the same input, binary and number of ranks give the same output. |

{doc}`../user-guide/keywords` lists every keyword with its default. **The H₂ level model has no
keyword**: it runs one sweep per iteration and, on the finished model, up to 12 sweeps, until four of
its lines (1-0 S(1), 2-1 S(1), 0-0 S(0) and 0-0 S(1)) change by less than 1%.

## 5. Memory and ranks

Every rank holds the whole grid, so memory grows with the number of ranks:

$$
M \approx (0.47\ \mathrm{GB} + 38\ \mathrm{kB}\times N_\mathrm{active})\times N_\mathrm{ranks},
$$

0.65 GB per rank here. The run below peaked at 8.8 GB on 14 ranks (0.63 GB per rank; the ranks'
memory summed, sampled every 10 s). On fewer cores, use fewer ranks;
{doc}`../getting-started/running` gives the numbers for larger grids. The times below were measured
on a 14-core workstation.

## 6. Run and monitor

```bash
mpirun -np 14 mocassin > run.log 2>&1
```

For a long run, detach it from the terminal (`nohup ... &` or `systemd-run --user`). If Open MPI
warns that its one-sided component failed, `mpirun --mca osc ^ucx ...` keeps that harmless message
out of the log.

**The run took 24 minutes on 14 cores and stopped after 16 iterations.** The first three iterations,
before the chemistry starts, take about 20 s each. The fourth, the first with the chemistry and the
H₂ model, takes 3 minutes, and each later one about 85 s, two-thirds of it the H₂ model's sweep over
the 4,661 cells (about 57 s). At the end the H₂ model is solved to convergence on the finished model (2.8 minutes)
before the outputs are written.

Each iteration ends with a summary in `run.log`, including the stop test:

```text
! iterateMC: [Summary] Iteration 8 ; integrated quantities: largest change over the last 3 iterations 21.025% (O2+), limit 2.00%: NOT converged
```

and the run ends with

```text
! iterateMC: [talk] convergence reached after 16 iterations. & Finishing up ...
total run time per processor 00:24:10 (HMS)
! MoCaSSin: end simulation reached - clean exit -
```

`output/convergence.out` tabulates the integrated quantities of every iteration, so the approach to
convergence can be followed or plotted. A run that hits the cap instead says
`maximum number of iterations reached` and `NOT CONVERGED`; raise the cap or continue it (section 11).

## 7. Check the run

`examples/tutorial/check_model.py`, run from your checkout, reports the four things worth checking
after any PDR run:

```console
$ python3 /path/to/mocassin-pdr/examples/tutorial/check_model.py .
stop: ! iterateMC: [talk] convergence reached after           16  iterations. & Finishing up ...
cells: 4661 active points, 16 flagged
hydrogen budget: max |sum_s h(s) x(s) - 1| = 8.7e-09 over 4661 active points
convergence: iteration 16, cells 29.67%, worst 1.393%
```

- **The stop line:** did the integrated test pass, or did the run hit the cap?
- **Flagged cells:** cells whose thermal or ionisation balance was not reached, or whose temperature
  reached 30,000 K. `lineFlux.out` and `lineFluxMol.out` leave them out; `lineFluxH2.out` counts them
  ({doc}`../user-guide/python` explains `mask`).
  A few are normal: here 16 of 4,661, all in the cavity within 0.03 pc of the star, where the
  gas of $10^3$ cm⁻³ reaches the 30,000 K ceiling.
- **The chemistry's hydrogen budget:** in every cell the hydrogen in the chemistry's 33 species must
  add up to one per H nucleus; here it holds to $10^{-8}$. (Combining MOCASSIN's own H and H⁺ with the
  chemistry's H₂, the two codes' sum holds to $1.5\times10^{-5}$.)
- **The share of converged cells** (29.67%) is reported, not used: the stop test is the integrated
  one, and the cells of a PDR keep moving by more than `convLimit` long after the model has settled.

## 8. What the run gives

`output/` holds MOCASSIN's usual files (`lineFlux.out`, `temperature.out`, `ionratio.out`, `SED.out`,
the grid files) and the PDR's: the chemistry's state per cell (`pdrGrid.out`), the CO lines
(`lineFluxMol.out`), the H₂ lines (`lineFluxH2.out`), the H₂ level populations (`h2Pop.bin`) and
per-cell H₂ diagnostics (`h2Cells.out`), and the thermal budget (`thermBudget.out`). {doc}`../user-guide/outputs` describes
every file. With `multiChemistry`, `lineFlux.out` gives the total first and then each component.

| | This run (graphite) | The test problem's own dust |
| :--- | :--- | :--- |
| Stop | integrated test, iteration 16 (worst 1.39%) | integrated test, iteration 17 (worst 1.72%) |
| Time on 14 cores | 24 min | 17 min |
| H$\beta$ (erg s⁻¹) | $4.67\times10^{35}$ | $4.90\times10^{35}$ |
| Cells with $2n(\mathrm{H_2})/n_{\mathrm H}>0.2$ | 2,268 | none (largest $7\times10^{-7}$) |
| Largest $n(\mathrm{CO})/n_{\mathrm H}$ | $3.0\times10^{-4}$ (all the carbon) | $8\times10^{-11}$ |
| Largest $A_V$ from the star | 10.3 | 1.4 |
| H₂ 1-0 S(1) 2.12 µm / H$\beta$ | $8.1\times10^{-5}$ | $1.4\times10^{-5}$ |
| H₂ 0-0 S(1) 17.0 µm / H$\beta$ | $1.09\times10^{-4}$ | $2.8\times10^{-8}$ |
| CO 1-0 (erg s⁻¹) | $1.35\times10^{30}$ | $2.4\times10^{20}$ |
| Flagged cells; hydrogen budget | 16; $8.7\times10^{-9}$ | 3; $6.2\times10^{-9}$ |

**With the test problem's own dust the PDR stays atomic.** To try it, copy the test problem's
`dust_species.dat`, `dust_sizes.dat` and `test_dust_21x21x21.dat` into `input/` and replace the `MdMg`
line by `Ndust file "input/test_dust_21x21x21.dat"` (the files are also installed under
`$PREFIX/share/mocassin/benchmarks/test_Problem/input/`). Its grains give H₂ too little surface to form on
($2.2\times10^{-23}$ cm² per H of silicate and $1.2\times10^{-23}$ of PAH in the log's `[D195]` lines,
$3.4\times10^{-23}$ in all, against $5.7\times10^{-22}$ for the graphite; giving H₂ formation each
grain material's own temperature, {lim}`L-54`, would raise it only about 1.7 times), so H₂ is photodissociated faster than it forms, and
they give the dense gas an $A_V$ of at most 1.4. The little H₂ there still fluoresces under the
star's ultraviolet: 1-0 S(1) is a sixth of its value with graphite, while the rotational 0-0 S(1),
which needs warm molecular gas, falls by a factor of 4,000, and CO by ten orders of magnitude.

## 9. Slices

`examples/tutorial/plot_slices.py` draws six quantities in two planes through the star, using
`tools/mocread.py` ({doc}`../user-guide/python`):

```bash
python3 /path/to/mocassin-pdr/examples/tutorial/plot_slices.py .
```

It writes `slices_xy.png` (the mid-plane, the ring face-on) and `slices_xz.png`
({numref}`fig-tut-xz`).

```{figure} _figures/tutorial-b_slices_xy.png
:name: fig-tut-xy
:alt: Slices of the model through the mid-plane: hydrogen density, electron temperature, ionised fraction, molecular fraction, CO abundance and A_V.
:width: 100%

The mid-plane, the ring seen face-on. The ring's inner face is square because the cavity is only
three cells across. The ionised gas fills the cavity and reaches into the ring's first cells (the
ionisation front is thinner than a cell); behind them the ring and the slab are molecular. The spokes
along the axes in $A_V$ and CO come from the grid: a ray along an axis crosses more ring cells
(8.5 mag) than one along a diagonal (6.9 mag).
```

## 10. Maps of the H₂ and CO lines

`tools/h034_maps.py` builds intrinsic surface-brightness maps of the H₂ and CO lines from the
level populations and emissivities the run wrote (it needs numpy, astropy and matplotlib):

```bash
python3 /path/to/mocassin-pdr/tools/h034_maps.py . --png
```

It writes `output/maps_h2co.fits`, maps along z, x and y of eight H₂ lines and CO 1-0 to 6-5 in
erg s⁻¹ cm⁻² sr⁻¹, and with `--png` a quick look along z. The maps are intrinsic (no dust extinction,
no velocity axis), unfolded from the octant, and leave out the flagged cells. Each map's integral
over the sky returns its line's luminosity in the tables to within $6\times10^{-6}$ for every line,
less the flagged cells' share. The tool takes the H₂ and CO data from `--data DIR` if given, else
from the input's `pdrDataDir`, else from `~/.local/share/mocassin/dataPDR`; with another `PREFIX`,
pass `--data $PREFIX/share/mocassin/dataPDR`.

```{figure} _figures/tutorial-b_maps.png
:name: fig-tut-maps
:alt: Maps along z of eight H2 lines and six CO lines of the tutorial model.
:width: 100%

The H₂ and CO lines seen face-on. The vibrational H₂ lines and the warm rotational ones come mostly
from the ring's inner face, pumped by ultraviolet that is largely scattered starlight; the fainter,
broader emission beyond 0.1 pc comes from the slab's top layer and the neutral halo gas above it,
lit through the ionised cone. CO fills the molecular disc out to the edge of the model, but outside
the ring it carries only part of the carbon (neutral carbon dominates in the slab), so there its
brightness follows the model's edge (section 12).
```

## 11. Continue a run

`mocassinWarm`, run in the same directory with the same input, resumes from `output/`: the grid
files, the chemistry's `pdrGrid.out` and the H₂ populations in `h2Pop.bin`.

```bash
cp -r ~/tutorial ~/tutorial-more && cd ~/tutorial-more
mpirun -np 14 mocassinWarm > run.log 2>&1
```

- **It reads the input first, then the run's own parameters back from `output/`.** The PDR keywords,
  `convTotals` and `randomSeed` come from `input.in`. The grid and run parameters, among them the
  iteration cap, come from `output/grid3.out`, and the star and `nPhotons` from
  `output/photoSource.out`: changing those in `input.in` has no effect. It counts iterations from 1
  again, up to the `maxIterateMC` saved in `grid3.out` (30 here), and its stop test starts over, so it
  needs four iterations before it can stop. To allow a different number, edit the first number on the
  `maxIterateMC` line of `output/grid3.out`.
- **Its share of converged cells means nothing.** The values it compares against at the start of each
  iteration are not set up in a warm start ({devlog}`D-438`), so it reports nearly every cell as
  converged. Use the integrated stop test.
- **The chemistry resumes at once**, from the saved abundances, whatever `pdrStartIter` says
  ({devlog}`D-393`); the log says `[D-393] PDR state resumed`.
- **The H₂ populations are resumed** when `h2Pop.bin` matches the grid and levels; otherwise they
  start from a Boltzmann distribution, and the log says so. `h2Pop.bin` is written only with the
  final outputs, so a warm start after a crash restarts the populations.
- **It overwrites `output/`,** including `convergence.out`; that is why the commands above work on a
  copy.

**Continuing this run.** A copy of the finished run, continued with `mocassinWarm` on 14 cores,
resumed the chemistry and the H₂ populations (`populations resumed from output/h2Pop.bin`) and
stopped on the integrated test after 7 further iterations, in 12 minutes. Its H$\beta$ is within
0.1% of the original's and its H₂ 1-0 S(1) is 4% lower, within that line's scatter from one
iteration to the next: a continued run is equivalent to a longer one, not identical
({devlog}`D-393`). A continuation starts with a short transient: the mean H₂ temperature went from
32 to 39, 27 and 33 K over its first iterations. The same continuation capped at 4 iterations (by
editing `grid3.out`) stopped there `NOT CONVERGED`, still inside that transient, so allow a warm
start several iterations.

## 12. Known limits

- **The PDR is barely resolved.** A cell of the ring holds 1.2 magnitudes of $A_V$: the ionisation front
  lies in the ring's first cell and the H/H₂ transition in its second, which gives more than half of
  the 1-0 S(1) and 0-0 S(1) emission. The H₂ line luminosities therefore depend on the grid; a finer
  grid, at a higher cost in memory (section 5), would resolve them.
- **Monte Carlo noise** at $10^7$ packets is visible in the maps: per pixel about 15–25% in the H₂ lines
  and more in CO (DEVLOG-H2 H-037). More packets reduce it.
- **The grid's directions show.** The axis-aligned spokes in the slices and the CO maps come from the
  staircase of cells (section 9); in addition, the diffuse field and the line escape use twelve fixed
  directions, which leaves a pattern of about 10% in slices of $n(\mathrm{H_2})$ and CO ({lim}`L-53`).
- **An ionisation front narrower than a cell** makes cells at one radius differ by direction
  ({devlog}`D-412`). Here the cavity's edge is such a front.
- **Where CO is still a trace at the edge of the grid,** a CO map's brightness follows the model's
  boundary; make the grid reach past the CO transition if CO is the point.
- **H₂ formation uses one dust temperature for every grain material**, the smallest grains'. With the
  test problem's own mixture that is the PAHs' temperature, applied to the silicates too
  ({lim}`L-54`, {devlog}`D-417`).
- **The x and y sides of the face-on maps differ by a few per cent** in the rotational H₂ lines,
  although the model is symmetric in x and y: fainter on the y side in earlier runs ({lim}`L-57`),
  brighter by 4–5% in this one, so here at the level of the noise.
- {doc}`../physics/limitations` lists every open item.
