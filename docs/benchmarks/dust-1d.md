# Dust shells: the 1D dust benchmark

Three spherical dust shells test what MOCASSIN does with dust alone, without gas or chemistry: the
transfer of starlight through grains that absorb and scatter it, the radiative equilibrium of the
grains, and the transfer of their own infrared emission. The geometry is the benchmark problem of
{cite:t}`IvezicEtAl1997`, set up as {cite:t}`Ercolano2005` set it up to benchmark MOCASSIN against
DUSTY {cite:p}`IvezicElitzur1997`. Their figure is the reference here.

| Model | $\tau(1\,\mu\mathrm{m})$, measured | `Rout` (cm) | $r_\mathrm{in}$ (cm) | $N_\mathrm{dust}$ (cm⁻³) | Grid | `convLimit` |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| p0tau1 | 1.008 | $2.18\times10^{17}$ | $2.18\times10^{14}$ | $1.117\times10^{-8}$ | $16^3$ | 0.05 |
| p0tau10 | 10.07 | $2.20\times10^{17}$ | $2.20\times10^{14}$ | $1.107\times10^{-7}$ [^ndust] | $17^3$ | 0.03 |
| p0tau100 | 101.0 | $2.35\times10^{17}$ | $2.35\times10^{14}$ | $1.036\times10^{-6}$ | $21^3$ | 0.03 |

Each shell surrounds a point source radiating as a 2,500 K blackbody with $10^4\,L_\odot$
($3.826\times10^{37}$ erg s⁻¹). The dust density is uniform ("p0": density $\propto r^{-p}$ with
$p=0$) from $r_\mathrm{in}$ to `Rout` $=1000\,r_\mathrm{in}$. The grains have a single radius,
0.16 µm, and the optical constants of the astronomical silicate of {cite:t}`DraineLee1984`
(`dustData/sil-dlee.nk`). Ivezić et al. defined the problem with idealised opacities, and scaled it
by the dust temperature at the inner edge, $T_1=800$ K. These shells follow Ercolano et al., who
used real silicate because DUSTY's library has it too, and fixed the luminosity and $r_\mathrm{in}$
instead. The optical
depths in the table are MOCASSIN's own, from the star to the edge at 1 µm (`tauNu.out`).

The fixtures are `benchmarks/dust/1D/p0tau*`. Each is one octant (`symmetricXYZ`), on axes that the
dust-density file sets: 0, $r_\mathrm{in}$, $2r_\mathrm{in}$, $4r_\mathrm{in}$, … doubling to a few
hundred $r_\mathrm{in}$, then refined again towards `Rout` (p0tau1 also has a point at
$0.5\,r_\mathrm{in}$). The points inside $r_\mathrm{in}$ and the corners of the cube beyond `Rout`
have no dust and are inactive; the star sits in the inactive cell at the origin.

MOCASSIN's cell walls lie midway between the axis points, so the dust does not start exactly at
$r_\mathrm{in}$. The cell centred there spans $0.75$–$1.5\,r_\mathrm{in}$ in p0tau1 and
$0.5$–$1.5\,r_\mathrm{in}$ in the other two.

[^ndust]: {cite:t}`Ercolano2005`'s Table 2 gives $1.20\times10^{-7}$ cm⁻³. The fixture's value gives
    $N_\mathrm{dust}\times$`Rout` in the exact ratios 1 : 10 : 100 across the three shells, and the
    measured $\tau(1\,\mu\mathrm{m})$ is 10.07, so the table's value is probably a misprint.

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
lie below DUSTY's at most wavelengths, at $\tau=1$ at almost all of them. They are compared as
published. The summary table also gives their offsets after dividing each by its own integral, a
comparison of shape alone.

## The runs

| | p0tau1 | p0tau10 | p0tau100 |
| :--- | :--- | :--- | :--- |
| Iterations, isotropic / HG | 10 / 11, converged | 30 / 30, cap | 30 / 30, cap |
| Converged cells at the end, isotropic / HG | 95.2% / 96.2% | 93.2% / 93.8% | 91.8% / 91.6% |
| Packets in the last iteration | $1.28\times10^7$ | $1.28\times10^7$ | $1.28\times10^7$ |
| Run time, 14 ranks | 7–9 s | 88–89 s | 174–176 s |

- **Build.** The 3D build (`make PDR=1 PDRGEOM=3D mocassin`) of `main` at commit `bef7b13`
  (`pdr-coupling-v2.0.1-14-gbef7b13`), which has the {devlog}`D-441` fixes below. Without the `pdr`
  keyword it computes what the plain build does. For the three Henyey–Greenstein inputs, its
  `SED.out`, `dustGrid.out`, `grid0.out` and `tauNu.out` are byte-identical to those of the plain
  build's runs in {devlog}`D-441`.
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
  - The cells that fail are all far out: beyond $y=r/r_\mathrm{in}=128$, 486 and 654 in the
    isotropic runs at $\tau=1$, 10 and 100. They are 11–17% of the cells beyond $y=900$, where the
    shell is thin and cold and each cell receives few packets. Every cell closer in, the hot dust
    that emits the near- and mid-infrared among them, has converged.
  - That points to Monte Carlo noise in the outer cells once the packet count has stopped growing,
    but it has not been tested. The fixtures used to stop at 10 iterations; the cap is now 30
    ({devlog}`D-441`).
- **Energy.** The luminosity in each run's SED, $4\pi d^2\int F_\nu\,d\nu$, is 0.9997–0.9998 of the
  star's, and the code's own sum over its frequency bins, which `SED.out` reports, is 0.9999 of it.
  Every packet carries a fixed energy and leaves the shell sooner or later, so this checks the
  bookkeeping of the escaping light ({devlog}`D-441`), not the temperatures.
- **Reproducing them.** `docs/bench/dust.py` reduces the six runs (`docs/bench/dust.toml`) to
  `docs/bench/data/dust1d/`, with `PROVENANCE.json`.

## Results

```{figure} /benchmarks/_generated/dust1d_sed.svg
:name: fig-dust1d-sed
:alt: The spectral shapes of the three shells from DUSTY 2.01, MOCASSIN 2005 and MOCASSIN-PDR, with their logarithmic ratios to DUSTY below.

The escaping spectrum of each shell as $\lambda F_\lambda/\int F_\lambda\,d\lambda$ (top), and the
logarithm of each curve's ratio to DUSTY at DUSTY's points (bottom). The lower panels are clipped at
±0.3 dex and include points below the statistics' floor, where MOCASSIN-PDR's curve carries more
Monte Carlo noise (at $\tau=1$ beyond 300 µm, for example). At $\tau=100$ the reference curves are
drawn in the pieces the figure left above $10^{-5}$.
```

```{csv-table} Summary. The offsets are $\log_{10}$ of the ratio to DUSTY 2.01, at DUSTY's points where its curve is at least $10^{-3}$ of its peak. $T_\mathrm{in}$ is the mean dust temperature of the active cells at $r_\mathrm{in}$.
:file: /bench/data/dust1d/summary_page.csv
:header-rows: 1
:name: tab-dust1d-summary
```

With isotropic scattering, MOCASSIN-PDR follows DUSTY with a median offset of 0.003 dex at
$\tau=1$, 0.010 dex at $\tau=10$ and 0.029 dex at $\tau=100$. MOCASSIN 2005's published curves are
0.036, 0.033 and 0.026 dex from DUSTY. Divided by their own integrals they are 0.010, 0.013 and
0.018 dex from it: in shape, MOCASSIN 2005 matched DUSTY about as well, and better at $\tau=100$.

Beyond 30 µm MOCASSIN-PDR is slightly fainter than DUSTY: by a median 0.023, 0.014 and 0.014 dex,
at all of DUSTY's points there at $\tau=1$, 96% at $\tau=10$ and 76% at $\tau=100$. The largest
isotropic offsets are:
- **$\tau=1$:** 0.066 dex at 0.44 µm, on the steep blue side of the transmitted starlight.
- **$\tau=10$:** 0.078 dex at 9.6 µm, at the bottom of the silicate absorption.
- **$\tau=100$:** −0.145 dex at 7 µm, on the edge of the 10 µm absorption, where DUSTY's curve
  falls twentyfold between 7 and 7.5 µm.

  Elsewhere at $\tau=100$, MOCASSIN-PDR is brighter than DUSTY on the short-wavelength side of both
  emission regions:
  - by 0.03–0.07 dex from 2.7 to 6.5 µm, and by 0.06–0.11 dex from 25 to 35 µm;
  - below the statistics' floor, by 0.14–0.27 dex at 2–2.2 µm and 22–24 µm, and by up to 0.37 dex
    in the narrow window between the two silicate features (13.5–16 µm), where DUSTY's curve is
    $10^{-5}$–$10^{-4}$.

  MOCASSIN 2005 lies above DUSTY in the same places: by up to 0.09 dex within the floor, and by
  0.08–0.14 dex below it. The light from 2.7 to 6.5 µm needs dust hotter than about 500 K, found
  only within $y\approx2$. From there the optical depth to the outside is 3–7 at those wavelengths,
  so a few per cent more hot dust or column changes the escaping flux by several hundredths of a
  dex. The dust that starts at 0.5 rather than
  $1\,r_\mathrm{in}$ (see above) is one candidate, but it has not been tested.

**Scattering.** With the Henyey–Greenstein phase function the grains scatter forward, so more of the
starlight that is scattered keeps moving outward and escapes, and less of it is absorbed:
- **Below 3 µm,** the escaping light is brighter than with isotropic scattering by up to 0.39 dex at
  $\tau=1$ (at 0.44 µm) and 0.22 dex at $\tau=10$ (at 1 µm), within the statistics' floor. The
  difference keeps growing at shorter wavelengths: 0.42 dex at 0.36 µm and 0.59 dex at 0.85 µm.
- **The dust emission** at $\tau=1$ is correspondingly fainter: 0.03–0.06 dex from 12 to 250 µm. The
  light beyond 8 µm carries 0.129 of the luminosity, against 0.139 with isotropic scattering.
- **At $\tau=10$** the infrared differs by up to 0.06 dex in and around the silicate feature
  (9–16 µm). At $\tau=100$, where the starlight is absorbed whatever the phase function, it differs
  by at most 0.02 dex.

So the benchmark's isotropic assumption matters for the scattered starlight at every optical depth,
and for the dust emission when the shell is optically thin to it.

**Temperatures.** There is no published profile to compare with (see above).
{numref}`fig-dust1d-temperature` shows MOCASSIN-PDR's. The cells centred at $r_\mathrm{in}$ are at
759 K at $\tau=1$, 809 K at $\tau=10$ and 811 K at $\tau=100$ (isotropic). The benchmark's own
scale is $T_1=800$ K at $r_\mathrm{in}$, which optically thin grains reach there: 803 K for these
grains at p0tau1's $r_\mathrm{in}$ (a Mie estimate, {devlog}`D-442`).

The cell values differ from that for two reasons:
- **The cell's extent.** A cell spans 0.75–1.5 or 0.5–1.5 $r_\mathrm{in}$, and its mean starlight is
  not that at $r_\mathrm{in}$. The same thin estimate averaged over the cell gives 764 K and 811 K
  for the cells at $\tau=1$ and 10, close to what the runs give.
- **Back-warming.** At $\tau=100$ the cell is warmer than that estimate (811 K against 778 K), as the
  shell's own infrared radiation heats its inner edge.

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
depths. Since {devlog}`D-441` its models run and conserve energy to $10^{-4}$, though none converged
within the fixtures' 10 iterations (63–73% of the cells). It has no page yet. The five codes' SEDs and temperature profiles were published as data files on an MPIA FTP
server that no longer accepts connections. The paper's figures give the codes' mean SED only at
12.5° and 77.5°, and absolute temperatures only at $\tau=100$.

When the data are found, the fixtures need two changes:
- **Inner edge.** Their `Rin 1.96e13` (1.31 AU) switches off the cell between 1.00 and 1.35 AU that
  holds the inner rim (the density file already has no dust inside 1 AU).
- **Inclinations.** They compute 12.49° and 77.35°, and not 42.5°.

## Reproducing

```bash
# a checkout of main at bef7b13 or later; the binary reads its data from PREFIX/share/mocassin
make clean && make PDR=1 PDRGEOM=3D PREFIX=$HOME/.local install
mkdir -p myrun/input myrun/output
cp benchmarks/dust/1D/p0tau10/* myrun/input/
cp docs/bench/inputs/dust-p0tau10-iso/input.in myrun/input/
cd myrun && mpirun -np 14 $HOME/.local/bin/mocassin
```

With the same seed, rank count, compiler and machine the run reproduces the one shown here exactly;
elsewhere it differs at the level of the Monte Carlo noise.
