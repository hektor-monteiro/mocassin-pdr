(sec:moc-index)=
# MOCASSIN: transfer, gas and dust

MOCASSIN is a three-dimensional Monte Carlo code for photoionised gas and dust
{cite:p}`Ercolano2003,Ercolano2005,Ercolano2008`. On a Cartesian grid of homogeneous cells, it:
- follows the radiation of its sources as packets of equal energy, and estimates the mean intensity
  in every cell from their paths;
- solves the ionisation balance of every element and the thermal balance of the gas, and the
  temperature of every grain species and size;
- repeats both until the model converges.

From the converged model it computes the line and continuum emission and the spectrum that leaves
the nebula.

These pages describe MOCASSIN as it is in this repository, at release `pdr-coupling-v2.0.2` and the
commit shown at the foot of every page:
- what each part computes, with a link to the code that does it;
- what this project changed, cited by its DEVLOG entry (D-nnn);
- what is known to be wrong, cited by its item on the {doc}`limitations page <../limitations>`
  (L-nn).

The chemistry and the H₂ level model that this project coupled to MOCASSIN are described in
{doc}`../pdr/index`. Where those pages already explain a part of MOCASSIN (the packets and the
estimator in {doc}`../pdr/field`, the photoionisation rates in {doc}`../pdr/photorates`), these pages
link to them.

```{toctree}
:maxdepth: 1

grid
transfer
iteration
ionisation
thermal
emission
dust
```

## What each page covers

:::{list-table} The chapters.
:name: tab:moc-pages
:header-rows: 1
:widths: 18 82

* - Page
  - What it describes
* - {doc}`grid`
  - The frequency grid, the spatial grid and its cells, the density and abundance inputs, the
    octant symmetry, sub-grids, the 2D mode and plane-parallel illumination.
* - {doc}`transfer`
  - The sources and their packets, the emission of packets by the gas and the dust, their paths,
    scattering and absorption, path biasing, the estimators of the radiation field, the escaping
    packets and the spectral energy distribution, the random numbers and the parallel run.
* - {doc}`iteration`
  - What a run does from start-up to the last iteration, the per-cell and model-wide convergence
    tests, the packet count, the warm start and the output.
* - {doc}`ionisation`
  - Photoionisation cross sections, opacity and rates; radiative and dielectronic recombination,
    charge exchange and collisional ionisation; how the ionisation balance and the electron
    density are solved.
* - {doc}`thermal`
  - The heating and cooling terms of the gas, the temperature solver, the cells set aside, and the
    per-cell test of the thermal state.
* - {doc}`emission`
  - The diffuse continua and lines that the gas emits into the radiation field, the recombination
    and collisionally excited lines it reports, the resonance lines, and the line and temperature
    output files.
* - {doc}`dust`
  - The grains' optical properties, abundance and opacity; their temperatures and emission;
    stochastic heating; grain charge and the photoelectric and collisional exchange with the gas.
:::

## Status of each feature

MOCASSIN carries more than this project uses. Each section of these pages starts with a badge that
says which:

- {bdg-success}`used`: the project's benchmarks or PDR models exercise it: the Lexington gas models,
  the 1D dust shells (with Henyey–Greenstein and with isotropic scattering), `hiipdr`, `pn150k` and
  the test problem of the tutorial.
- {bdg-warning}`not exercised`: compiled, but not run or tested by this project, so its behaviour
  here is as inherited from MOCASSIN. Examples: sub-grids, the 2D mode, plane-parallel illumination,
  several stars, diffuse sources, light echoes, viewing angles in non-symmetric models, and
  `multiDustChemistry`.
- {bdg-secondary}`dead`: parsed or compiled but never takes effect, such as a keyword that is read
  and not used.
- {bdg-dark}`not compiled`: in the source tree but not in the Makefile's build lists. The X-ray
  fluorescence code of {cite:t}`Ercolano2008` ({src}`fluorescence_mod.f90`, {src}`mocassinFluorescence.f90`)
  is not compiled, so the X-ray physics of MOCASSIN 2008 is not part of this code.

## The builds

All four builds compile the whole of MOCASSIN ({doc}`../../user-guide/build-flavours`).
- **The PDR builds** (`PDR=1`) add the chemistry. When a model has the `pdr` keyword, they also add
  terms inside MOCASSIN's own routines: the H₂ photoionisation opacity; the normalisation of each
  linked element's stages to the fraction not in molecules (`elemAvail`); the network's sources and
  sinks in the ionisation matrix, its charge-exchange coefficients and the cosmic-ray ionisation; the
  neutral colliders and escape probabilities of the C I, C II and O I atoms; H₂ as a collider in the
  gas–grain exchange; the molecular cooling; and the extra heating (`pdrHeatXtra`). They also add some solver keywords that a plain build does not accept, and the pages
  say where.
- **Without the `pdr` keyword,** a PDR build computes what the plain build computes
  ({devlog}`D-438`, {devlog}`D-441`).

## Defects found while writing these pages

Writing these chapters meant reading every routine they describe, and that found twenty-six
defects in the inherited code and in this project's. Each was verified and recorded ({devlog}`D-444`).
Each is described on the page where its process is, and none has been fixed: each fix needs its
own plan, and the ones that change results need the benchmarks rerun.

:::{list-table} Defects recorded while writing these pages.
:name: tab:moc-defects
:header-rows: 1
:widths: 10 72 18

* - Item
  - What
  - Severity
* - {lim}`L-64`
  - Inner-shell photoionisation absorbs but neither ionises nor heats
  - Medium
* - {lim}`L-65`
  - H collisional-excitation cooling charges 1 Ryd per excitation
  - Medium
* - {lim}`L-66`
  - Stages without dielectronic data take oxygen's rate
  - Medium
* - {lim}`L-79`
  - Resonance-line dust heating is shared between species by number abundance
  - Medium
* - {lim}`L-80`
  - A viewpoint at $\phi=0$ collects its whole $\theta$ band
  - Medium
* - {lim}`L-88`
  - The resonance lines' escape probability samples only the eight body diagonals
  - Medium
* - {lim}`L-67`
  - Line cooling counts levels 1–10 of each ion and not Fe II; all are emitted
  - Low
* - {lim}`L-68`
  - Fe II emissivities are never converted to erg
  - Low
* - {lim}`L-69`
  - Free-free opacity is computed in frequency bin 1 only, and is too large there
  - Low
* - {lim}`L-70`
  - The dust+gas frequency grid takes one point of `nuDustRyd.dat`
  - Low
* - {lim}`L-71`
  - He I recombination lines below 5,000 K and above 20,000 K are extrapolated
  - Low
* - {lim}`L-72`
  - With `multiDustChemistry`, scattering uses the last component's asymmetry parameter
  - Low
* - {lim}`L-73`
  - A renormalised Henyey–Greenstein direction is discarded
  - Low
* - {lim}`L-74`
  - Defects in features this project does not exercise
  - Low
* - {lim}`L-75`
  - `MdMg` with `Ndust` passes the input check
  - Low
* - {lim}`L-76`
  - The photoionisation rate and heating integrals differ at the top bin
  - Low
* - {lim}`L-77`
  - Dead options and stale comments
  - Low
* - {lim}`L-78`
  - Free-free emission above the H and He edges uses another cell's Gaunt factors
  - Low
* - {lim}`L-81`
  - `getDustT`'s 1 K floor applies only with `talk`
  - Low
* - {lim}`L-82`
  - `noScattering` does not reach species read from Q files
  - Low
* - {lim}`L-83`
  - The grain-potential convergence flag is never read
  - Low
* - {lim}`L-84`
  - Without `symmetricXYZ`, an edge cell's volume is twice the region the packets cross
  - Low
* - {lim}`L-85`
  - After a warm start a diffuse source emits nothing
  - Low
* - {lim}`L-86`
  - A packet's weight across a re-emission relies on an unsaved local variable
  - Low
* - {lim}`L-87`
  - `getNu2` never emits into the first and last frequency bins
  - Low
* - {lim}`L-89`
  - Species abundances are used as given: mixture means are right only when they sum to one
  - Low
:::

## Notation and units

The symbols are those of {numref}`tab:notation`.
- **Units** are cgs, except that the code works in its own units for three quantities:
  - frequencies in rydbergs (1 Ryd $=13.6057$ eV, $\nu_{1\,\mathrm{Ryd}}=3.28984\times10^{15}$
    Hz);
  - luminosities and packet energies in $10^{36}$ erg s⁻¹;
  - cell volumes in $10^{45}$ cm³ and masses in $10^{45}$ g
    ({src}`grid_mod.f90::getVolume`).
- **Grid points and cells:** cell walls lie midway between grid points, so a grid point is the
  centre of its cell, except at the edges of the grid ({doc}`grid`).
- **The octant:** a model computed in one octant (`symmetricXYZ`) reports its integrated quantities
  for the whole sphere.
