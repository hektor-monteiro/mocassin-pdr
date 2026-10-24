# Dust shells: the 1D dust benchmark

Three spherical dust shells test what MOCASSIN does with dust alone, without gas or chemistry: the
transfer of starlight through grains that absorb and scatter it, the radiative equilibrium of the
grains, and the transfer of their own infrared emission. The geometry is the benchmark problem of
{cite:t}`IvezicEtAl1997`, set up as {cite:t}`Ercolano2005` set it up to benchmark MOCASSIN against
DUSTY {cite:p}`IvezicElitzur1997`. Their figure is the reference here.

| Model | $\tau(1\,\mu\mathrm{m})$, measured | `Rout` (cm) | $r_\mathrm{in}$ (cm) | $N_\mathrm{dust}$ (cm⁻³) | Grid | `convLimit` |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| p0tau1 | 1.008 | $2.18\times10^{17}$ | $2.18\times10^{14}$ | $1.117\times10^{-8}$ | $16^3$ | 0.05 |
| p0tau10 | 10.07 | $2.20\times10^{17}$ | $2.20\times10^{14}$ | $1.107\times10^{-7}$ | $17^3$ | 0.03 |
| p0tau100 | 101.0 | $2.35\times10^{17}$ | $2.35\times10^{14}$ | $1.036\times10^{-6}$ | $21^3$ | 0.03 |

Each shell surrounds a point source radiating as a 2,500 K blackbody with $10^4\,L_\odot$
($3.826\times10^{37}$ erg s⁻¹). The dust density is uniform ("p0": density $\propto r^{-p}$ with
$p=0$) from $r_\mathrm{in}$ to `Rout` $=1000\,r_\mathrm{in}$. The grains have a single radius,
0.16 µm, and the optical constants of the astronomical silicate of {cite:t}`DraineLee1984`
(`dustData/sil-dlee.nk`). Ivezić et al. defined the problem with idealised opacities instead; these
shells follow Ercolano et al., who used real silicate because DUSTY's library has it too. The optical
depths in the table are MOCASSIN's own, from the star to the edge at 1 µm (`tauNu.out`).

The fixtures are `benchmarks/dust/1D/p0tau*`. Each is one octant (`symmetricXYZ`), on axes that the
dust-density file sets: 0, $r_\mathrm{in}$, $2r_\mathrm{in}$, …, spaced logarithmically out to
`Rout`, so the inner edge is resolved although it is a thousand times smaller than the shell. The
points inside $r_\mathrm{in}$ and the corners of the cube beyond `Rout` have no dust and are
inactive; the star sits in the inactive cell at the origin.

## The reference

Figure 1 of {cite:t}`Ercolano2005` overplots DUSTY 2.01 and MOCASSIN (2005) for the three shells, as
the spectral shape $\lambda F_\lambda/\int F_\lambda\,d\lambda$ of the escaping radiation. "The
scattering was assumed to be isotropic for all benchmark models", by both codes. The paper gives no
numbers for the agreement ("very good"); the dust temperatures, it says, also agreed, but they are
not shown.

**How the curves were read.** The figure is vector PostScript in the arXiv source of the paper
(astro-ph/0507050). `docs/bench/ercref.py` reads the plotted paths from it rather than digitising
an image:
- **Checksums.** It checks the sha256 of the tarball and of `dustybench.ps`.
- **Calibration.** It finds the frame and the major ticks of both logarithmic axes: 0.12–1000 µm and
  $10^{-5}$–1.
- **Curves.** It keeps the ten curves inside the frame. By the caption and the text, solid black is
  MOCASSIN and dashed red is DUSTY, and line widths 10, 40 and 80 are $\tau=1$, 10 and 100.
- **Output.** It writes them to `docs/bench/ref/ercolano2005_fig1.csv`, about 80 points per curve.

The figure clips its curves at $10^{-5}$. So at $\tau=100$ both curves are missing where the silicate
features at 10 and 18 µm push the flux below that, and they are drawn in three pieces.

**Check.** A curve of $\lambda F_\lambda/\int F_\lambda\,d\lambda$ integrates to 1 over $\ln\lambda$.
DUSTY's three curves give 0.997, 1.001 and 1.010, which checks the calibration, since both codes are
drawn on the same axes. MOCASSIN 2005's give 0.908, 0.931 and 0.960: the published MOCASSIN curves
lie 0.02–0.04 dex below DUSTY's at almost every wavelength. They are used as published, not
renormalised.

## The runs

| | p0tau1 | p0tau10 | p0tau100 |
| :--- | :--- | :--- | :--- |
| Iterations, isotropic / HG | 10 / 11, converged | 30 / 30, cap | 30 / 30, cap |
| Converged cells at the end, isotropic / HG | 95.2% / 96.2% | 93.2% / 93.8% | 91.8% / 91.6% |
| Packets in the last iteration | $1.28\times10^7$ | $1.28\times10^7$ | $1.28\times10^7$ |
| Run time, 14 ranks | 7–9 s | 88–89 s | 174–176 s |

- **Build.** The 3D build (`make PDR=1 PDRGEOM=3D mocassin`) of `main` at commit `bef7b13`
  (`pdr-coupling-v2.0.1-14-gbef7b13`), which has the {devlog}`D-441` fixes below. Without the `pdr`
  keyword it computes what the plain build does: its runs of these inputs are byte-identical to the
  plain build's.
- **Inputs.** Each fixture with `randomSeed 1001` added (`docs/bench/inputs/dust-*`).
  - Every model was run twice: with `isotropicScattering`, as DUSTY and MOCASSIN 2005 assumed, and
    with the default Henyey–Greenstein phase function, whose asymmetry parameter comes from the Mie
    calculation (HG in the tables).
  - The comparison is the isotropic run; the HG run shows what the assumption costs.
  - `autoPackets` started each run with $10^5$ packets and doubled them while the share of converged
    cells grew slowly.
- **Convergence.** A dust-only model stops when the dust temperature of at least 95% of the cells
  (the second number of `maxIterateMC`) changes by less than `convLimit` between iterations.
  - p0tau1 stopped on it. In p0tau10 and p0tau100 the share rose to 91–94% within about 12
    iterations and stayed there, so they ran to the cap of 30.
  - Whether the remaining 6–8% of cells are held back by Monte Carlo noise or by a slow drift has not
    been established. The fixtures used to stop at 10 iterations; the cap is now 30
    ({devlog}`D-441`).
- **Energy.** The luminosity in each run's SED, $4\pi d^2\int F_\nu\,d\nu$, is 0.9997–0.9998 of the
  star's. What is left is the difference between that integral and the code's own sum over its
  frequency bins, which `SED.out` reports (also 0.9998).
- **Reproducing them.** `docs/bench/dust.py` reduces the six runs (`docs/bench/dust.toml`) to
  `docs/bench/data/dust1d/`, with `PROVENANCE.json`.

## Results

```{figure} /benchmarks/_generated/dust1d_sed.svg
:name: fig-dust1d-sed
:alt: The spectral shapes of the three shells from DUSTY 2.01, MOCASSIN 2005 and MOCASSIN-PDR, with their logarithmic ratios to DUSTY below.

The escaping spectrum of each shell as $\lambda F_\lambda/\int F_\lambda\,d\lambda$ (top), and the
logarithm of each curve's ratio to DUSTY at DUSTY's points (bottom). At $\tau=100$ the reference
curves are drawn in the pieces the figure left above $10^{-5}$.
```

```{csv-table} Summary. The offsets are $\log_{10}$ of the ratio to DUSTY 2.01, at DUSTY's points where its curve is at least $10^{-3}$ of its peak. $T_\mathrm{in}$ is the mean dust temperature of the active cells at $r_\mathrm{in}$.
:file: /bench/data/dust1d/summary_page.csv
:header-rows: 1
:name: tab-dust1d-summary
```

With isotropic scattering, MOCASSIN-PDR follows DUSTY with a median offset of 0.003 dex at
$\tau=1$, 0.010 dex at $\tau=10$ and 0.029 dex at $\tau=100$. MOCASSIN 2005's published curves are
0.036, 0.033 and 0.026 dex from DUSTY, most of it the uniform offset above. The largest isotropic
offsets are:
- **$\tau=1$:** 0.066 dex at 0.44 µm, on the steep blue side of the transmitted starlight.
- **$\tau=10$:** 0.078 dex at 9.6 µm, at the bottom of the silicate absorption.
- **$\tau=100$:** −0.145 dex at 7 µm, on the edge of the 10 µm absorption, where DUSTY's curve
  falls twentyfold between 7 and 7.5 µm.

  Elsewhere at $\tau=100$, MOCASSIN-PDR is brighter than DUSTY on the short-wavelength side of both
  emission regions:
  - by 0.03–0.07 dex from 2.7 to 6.5 µm, and by 0.06–0.11 dex from 25 to 35 µm;
  - by 0.17–0.27 dex just below the statistics' floor, at 2–2.2 µm and 22–24 µm.

  MOCASSIN 2005 lies above DUSTY there too: by up to 0.09 dex within the floor, and by 0.08–0.14 dex
  below it. That light comes from the hottest dust, in the innermost cells. On these grids the first
  cells span a factor of 2 in radius, but whether that resolution is the cause has not been tested.

**Scattering.** With the Henyey–Greenstein phase function the grains scatter forward, so more of the
starlight that is scattered keeps moving outward and escapes:
- **Below 3 µm,** the escaping light is up to 0.39 dex brighter than with isotropic scattering at
  $\tau=1$ (at 0.44 µm) and up to 0.22 dex at $\tau=10$.
- **Beyond 3 µm** the two differ by at most 0.06 dex, and at the infrared peaks by less than 0.001
  dex.

So the benchmark's isotropic assumption matters for the scattered starlight and hardly at all for
the dust emission.

**Temperatures.** There is no reference profile (see above). {numref}`fig-dust1d-temperature` shows
MOCASSIN-PDR's: the mean temperature at $r_\mathrm{in}$ is 759 K at $\tau=1$, 809 K at $\tau=10$ and
811 K at $\tau=100$ (isotropic).

```{figure} /benchmarks/_generated/dust1d_temperature.svg
:name: fig-dust1d-temperature
:alt: Dust temperature against radius in units of the inner radius for the three shells.
:width: 60%

The dust temperature of every active cell against $y=r/r_\mathrm{in}$, isotropic runs. The circles
mark the mean at $r_\mathrm{in}$.
```

## What made these runs possible

Until {devlog}`D-441` none of these models ran:
- **Crash.** Every build crashed in the first iteration of a model without gas. A convergence
  snapshot copied gas arrays that a dust-only model never allocates.
- **Stopping.** Once past that, the model-integrated convergence test, which has nothing to test
  without gas, would have stopped every run after one iteration. Dust-only runs now stop on the share
  of converged cells, as original MOCASSIN did.
- **Missing starlight.** `SED.out` had been leaving out the starlight that escapes without being
  scattered or absorbed whenever the star sits in an inactive cell, as it does here. A rewrite of the
  SED output in 2025 had dropped it. Only part of the luminosity reached `SED.out`:
  - 30% in p0tau1, in the first iteration, before the crash;
  - 77% in p0tau10, measured with the older `dev` branch, whose SED output is the same.

  It affected every model with a central cavity, the gas models included: 40% in the quickstart HII40.

## The 2D discs

The disc benchmark of {cite:t}`Pascucci2004` is set up in `benchmarks/dust/2D/` for the four optical
depths, and its models run since {devlog}`D-441`, conserving energy to $10^{-4}$. It has no page
yet. The five codes' SEDs and temperature profiles were published as data files on an MPIA FTP
server that no longer accepts connections. The paper's figures give the codes' mean SED only at
12.5° and 77.5°, and absolute temperatures only at $\tau=100$.

When the data are found, the fixtures need two changes:
- **Inner edge.** Their `Rin 1.96e13` (1.31 AU) switches off the cell between 1.00 and 1.35 AU that
  holds the inner rim (the density file already has no dust inside 1 AU).
- **Inclinations.** They compute 12.49° and 77.35°, and not 42.5°.

## Reproducing

```bash
# a checkout of main at bef7b13 or later
make clean && make PDR=1 PDRGEOM=3D mocassin
mkdir -p myrun/input myrun/output
cp benchmarks/dust/1D/p0tau10/* myrun/input/
cp docs/bench/inputs/dust-p0tau10-iso/input.in myrun/input/
cd myrun && mpirun -np 14 ../mocassin
```

With the same seed, rank count, compiler and machine the run reproduces the one shown here exactly;
elsewhere it differs at the level of the Monte Carlo noise.
