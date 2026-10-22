# Dust in MOCASSIN-PDR

How grains are specified, what MOCASSIN does with them, and the one place the
input format can be got subtly and expensively wrong.

## The input files

Three files, named from `input.in`:

    dustFile 'input/dust_species.dat' 'input/dust_sizes.dat'
    MdMg constant 2.4827e-3

### `dust_species.dat` — which materials

    1
    'dustData/grph-avg.cat' 1.0000 0.005 0.25

Line 1 is the number of species. Each species record is

    <optical-data file> <abundance> [<amin/um> <amax/um>] 

  - **optical-data file**, relative to `PREFIX/share/mocassin/`. Either an
    `nk` file (wavelength, n, k — MOCASSIN runs Mie itself) or a `Q` file
    (tabulated Qabs, Qsca, g, and Im(m) - see *Q format* below).
  - **abundance**, by number, relative to the other species of the component.
  - **amin, amax** in micron, optional; defaults to the full range of
    `dust_sizes.dat`. Sizes outside get zero cross-section for that species.
There is no axis keyword. An anisotropic material is pre-averaged into a
single file before MOCASSIN sees it - see *Anisotropic materials* below.

Each species gets **its own equilibrium temperature**. That is correct and
required: silicate and graphite in the same nebula genuinely sit at different
temperatures, because they have different opacities and so different energy
balances.

### `dust_sizes.dat` — the size distribution

    35 sizes

    0	0.005000	1.000000e+07
    1	0.005610	6.685071e+06
    ...

Index, radius in micron, and **n(a)**, the number per unit radius. MOCASSIN
forms bin widths from the neighbouring radii (symmetric midpoint), multiplies,
and normalises so the weights sum to 1 — so the third column's absolute scale
is irrelevant, only its shape matters. The example is MRN, n(a) ∝ a^-3.5.

### `MdMg` — how much dust

Dust-to-gas ratio **by mass**, converted to a grain number density using the
mean grain mass over the distribution:

    Ndust = MdMg * (gas mass per H) * n_H / sum( (4/3) pi a^3 rho w(a) f(species) )

`MdMh` is the same thing per unit hydrogen mass instead. `Ndust` may be given
directly, which is the only option for a gas-free model.

## Anisotropic materials: pre-average them into one species

**This is the part that is easy to get wrong, and the error is large.**

Graphite is optically anisotropic: its dielectric function differs along the
crystal c-axis and perpendicular to it. Its data therefore ships as **two
files**, one per axis, with weights 1/3 (parallel) and 2/3 (perpendicular) -
the geometric weights of a randomly oriented grain, *not* the abundances of
two grain populations.

Listed as two species, MOCASSIN solves one temperature for a hypothetical
pure-parallel grain and another for a pure-perpendicular grain - neither of
which exists - and reports their mean. Measured in one cell at one size:
**44.79 K and 22.45 K, mean 37.35 K, where the real randomly-oriented grain
sits at 26.85 K.** That is a 39% error, and it made the 150 kK model's dust
run 26-30% hot against Cloudy (DEVLOG D-309).

**Do the orientation average yourself, once, and give MOCASSIN one species.**

    ~/miniforge3/envs/astro/bin/python tools/mkqfile.py \
        --out dustData/grph-avg.cat --label grph-avg \
        --sizes input/dust_sizes.dat \
        dustData/grph2-dl.nk:0.6667 dustData/grph1-dl.nk:0.3333

then

    1
    'dustData/grph-avg.cat' 1.0000 0.005 0.25

`mkqfile.py` runs Mie per axis and sums the **cross sections** with the axis
weights, which is what Draine's 1/3-2/3 rule means and what Cloudy does
(`grains_mie.cpp` sums `cs_abs`/`cs_sct` over the axes in `graphite.rfi`). It
refuses if the axes disagree on density, work function, surface-atom mass or
sublimation temperature, since those would not be one material.

Verified: the generated file reproduces direct Mie of the mixture to a ratio
of 1.000 from 0.001 to 25 Ryd, and MOCASSIN's own arrays built from it match
the two-file mixture to 0.12% at 0.44 Ryd and exactly at 2.0 Ryd.

Two things to get right when generating:

  - **Wavelength range must span the model grid.** `nuMin = 1.001e-5 Ryd` is
    9104 um, so the default `--lmax 1e4` exists for a reason; values outside
    the table are clamped, not extrapolated.
  - **Radii should be the model's own.** Pass the same `dust_sizes.dat` the
    model uses, so MOCASSIN interpolates at its own grid points.

### Why you cannot supply one pre-averaged n,k file instead

Because the average is over **cross sections**, and Mie is non-linear in
(n, k). No single (n, k) reproduces `(2/3)Q(eps_perp) + (1/3)Q(eps_par)`
across size and wavelength. Measured on the graphite files in `dustData/`, the
ratio of a naively averaged n,k to the correct answer:

    a [um]   0.1 um   0.55 um   10 um   100 um
    0.005     0.96     1.21     2.14     0.09
    0.0354    1.00     1.16     2.11     0.09
    0.25      1.02     1.01     1.44     0.12

Acceptable in the ultraviolet, where the grain *absorbs*. Catastrophic at
100 um, where it *radiates* - 8 to 11 times too little emissivity. Averaging
the dielectric function instead is no better (0.07-1.77). So the average has
to happen after Mie, which is what `mkqfile.py` does.

### Abundances and mass

Abundances are by number and are **not normalised** by MOCASSIN - they are
used as given. With the axes pre-averaged into one species this is
straightforward again: one file, one abundance.

    'dustData/astroSilD2003.nk' 0.5000 0.005 0.25
    'dustData/grph-avg.cat'     0.5000 0.005 0.25   -> half silicate, half graphite

`Ndust` follows from `MdMg` and the mean grain mass
`sum (4/3) pi a^3 rho w(a) f(species)`, so the abundances set both the mass
split and the opacity mixture, as they always did.

## Optical data files

### `nk` format

    nk
     grph1-dl  2200. 2.2 0.323 12.004
        1.00000E-03    9.99690E-01    2.38100E-05
        ...

Line 2 is `label Tsublime[K] rho[g/cm3] Vn[Ryd] MsurfAtom[amu]`, where `Vn` is
the work function and `MsurfAtom` the surface atom's mass — the latter also
classifies the material as carbonaceous (~12) or not, which selects the
photoelectric yield fit. Then wavelength in micron, n, k, in any monotonic
order. Values outside the table are **clamped**, not extrapolated, so the table
must span `nuMin`–`nuMax` of the model.

### `Q` format

    Q
     label 2200. 2.2 0.323 12.004
     <comment lines>
      90 ... = NRAD
     241 ... = NWAV
       a(um)   lam(um)   Qabs   Qsca   g<cos>
     ...

A sixth column, **Im(m)**, is a MOCASSIN extension. The
Weingartner & Draine (2001) photoelectric yield needs it, and a standard
Draine Q file does not carry it. Without the column MOCASSIN **stops** rather
than running with no yield - in a PDR model the gas temperature is set by
grain photoelectric heating, so a silently zero yield would be fatal and
invisible. `tools/mkqfile.py` writes the column.

Header comment lines are skipped until the NRAD line parses, so the count of
comment lines is free.

Historical note: before D-313 the `Q` path could not run at all. It allocated
`CTsca`/`CTabs` a second time, which returns a non-zero status and stopped the
model, and it never called `setGrainYield`. Both are fixed.

## What MOCASSIN computes

  - **Opacity** — `Ndust` times the abundance- and size-weighted mixture cross
    section, so extinction, A_V and the FUV field were never affected by the
    temperature bug above - only the per-species temperature was.
  - **A_V** — integrated from MOCASSIN's own V-band opacity including
    scattering, `A_V = 1.0857 tau`. For the 150 kK model this gives
    N_H/A_V = 2.75e21, against Cloudy's 2.74e21 (0.4%).
  - **Grain temperature** — per species and per size, from radiative
    equilibrium `integral C_abs J dnu = integral C_abs B_nu(T) dnu`, solved by
    lookup in a table built at 1 K steps. `pdrRad.out` reports the
    abundance- and number-weighted mean.
  - **Photoelectric heating** — the Weingartner & Draine (2001) yield. The
    `MOCASSIN_YIELD=baldwin` switch to the older two-parameter form is retired
    (D-352); tag `d352-zone-and-switches` builds it.
  - **Stochastic heating** — available via `quantumHeatGrain`, off by default.
    It changes the emitted spectrum, not the tabulated temperature.

## Diagnostics

  - `MOCASSIN_DUSTPROBE=on` prints the emission table for a few (species, size,
    temperature) and, for the first cells, the absorption integral, the field
    it was evaluated on, and the resulting temperature. Run it on a small grid;
    it is opt-in and inert otherwise.
  - `output/dustGrid.out` holds `Ndust` and `Tdust(species, size)` for every
    cell — the per-size, per-species temperatures, which the reported mean
    hides. `tools/d305_tdust.py` reads it.
  - `tools/d305_dustaudit.py` checks the Mie path against Draine's tabulated Q
    and prints the extinction curve the model produces (R_V, A(1000A)/A_V,
    N_H/A_V).

## What the inputs decide

The grain materials, their size distribution and the dust-to-gas ratio are inputs:
MOCASSIN uses whatever `dust_species.dat`, `dust_sizes.dat` and `MdMg` / `MdMh` /
`Ndust` give it, and `tools/d305_dustaudit.py` prints the extinction curve they
produce. Properties of a model's dust are therefore choices of its input, not of the
code. The source of every bundled optical-data file, and the terms it is distributed
under, are in `dustData/README.md`. In the PDR benchmark fixtures:

  - `pn150k` uses MRN graphite alone, as its Cloudy reference does. That mixture gives
    R_V = 4.57 and A(1000A)/A_V = 3.32, against the Milky Way's 3.1 and 2.6–2.8; a
    Milky-Way-like curve needs silicate and carbonaceous species together in
    `dust_species.dat`.
  - MOCASSIN takes the gas-phase abundances of the abundance file as given and does
    not subtract what the grains lock up, so the abundance file should hold depleted
    gas-phase values. `pn150k`, like its Cloudy reference, uses undepleted ones, so its
    carbon is counted twice (in the gas and in the graphite); comparisons between the
    two codes are unaffected.
  - Neither fixture contains PAHs. `dustData/PAHneu_30.cat` can be added as a species;
    it carries Im(m) since D-415, so PAHs heat the gas photoelectrically.

## Known limitations

  - `getQs` caps the Mie size parameter at 100, which for a 0.25 um grain bites
    above 5.8 Ryd.
