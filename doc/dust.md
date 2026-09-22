# Dust in MOCASSIN-PDR

How grains are specified, what MOCASSIN does with them, and the one place the
input format can be got subtly and expensively wrong.

## The input files

Three files, named from `input.in`:

    dustFile 'input/dust_species.dat' 'input/dust_sizes.dat'
    MdMg constant 2.4827e-3

### `dust_species.dat` — which materials

    2
    'dustData/grph2-dl.nk' 0.6667 0.005 0.25 axes:graphite
    'dustData/grph1-dl.nk' 0.3333 0.005 0.25 axes:graphite

Line 1 is the number of species. Each species record is

    <optical-data file> <abundance> [<amin/um> <amax/um>] [axes:<name>]

  - **optical-data file**, relative to `PREFIX/share/mocassin/`. Either an
    `nk` file (wavelength, n, k — MOCASSIN runs Mie itself) or a `Q` file
    (tabulated Qabs, Qsca, g). **See the warning on `Q` files below.**
  - **abundance**, by number, relative to the other species of the component.
  - **amin, amax** in micron, optional; defaults to the full range of
    `dust_sizes.dat`. Sizes outside get zero cross-section for that species.
  - **axes:\<name\>**, optional. See *Anisotropic materials*.

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

## Anisotropic materials: the `axes:` tag

**This is the part that is easy to get wrong, and the error is large.**

Graphite is optically anisotropic: its dielectric function differs along the
crystal c-axis and perpendicular to it. Its data therefore comes as **two
files**, one per axis, with weights 1/3 (parallel) and 2/3 (perpendicular) —
the geometric weights of a randomly oriented grain, *not* the abundances of
two grain populations.

Listed as two plain species, MOCASSIN would solve one temperature for a
hypothetical pure-parallel grain and another for a pure-perpendicular grain —
neither of which exists — and report their mean. Measured in one cell at one
size: **44.79 K and 22.45 K, mean 37.35 K, where the real randomly-oriented
grain sits at 26.85 K.** That is a 39% error in dust temperature, and it made
the 150 kK model's dust run 26–30% hot against Cloudy (DEVLOG D-309).

Tag the members of an axis set with the same name:

    'dustData/grph2-dl.nk' 0.6667 0.005 0.25 axes:graphite
    'dustData/grph1-dl.nk' 0.3333 0.005 0.25 axes:graphite

MOCASSIN then runs Mie per axis, **averages the cross sections** with the
listed weights, and the result is one grain with one temperature. This is what
Cloudy does (`grains_mie.cpp` sums `cs_abs`/`cs_sct` over axes with the weights
from `graphite.rfi`, which carries the same two axes at the same 1:2).

Rules:

  - Untagged species are independent and keep their own temperature. This is
    the default and is right for genuine mixtures.
  - A group needs at least two members.
  - Members must share density, work function, surface-atom mass and
    sublimation temperature; MOCASSIN stops if they do not.
  - Several independent groups may coexist in one component, alongside
    untagged species.

### Abundances and mass in an axis group

The weights on an axis group's records do **double duty**: they are the
orientation weights *and* the abundances. MOCASSIN does not normalise
`grainAbun`, so they must sum to the abundance the whole grain should have.

    'dustData/grph2-dl.nk' 0.6667 0.005 0.25 axes:graphite
    'dustData/grph1-dl.nk' 0.3333 0.005 0.25 axes:graphite   -> one grain, abundance 1

For a mixture, scale the group so it sums to that material's share:

    'dustData/astroSilD2003.nk' 0.5000 0.005 0.25
    'dustData/grph2-dl.nk'      0.3333 0.005 0.25 axes:graphite
    'dustData/grph1-dl.nk'      0.1667 0.005 0.25 axes:graphite   -> half silicate, half graphite

Because the tag only overwrites **cross sections** and leaves the weights,
`rho` and `a^3` untouched, everything downstream that uses abundance is
unaffected:

  - **Mean grain mass and Ndust** — `sum (4/3) pi a^3 rho w(a) f(species)` runs
    over both records, and since their weights sum to the grain's abundance the
    mass is that of one grain. Verified: total dust mass is byte-identical with
    and without the tag (7.32406080E-02 Msol on the test fixture).
  - **Opacity** — `CTabs = sum f(species) C_abs w(a)` becomes
    `(0.6667 + 0.3333) * C_avg = C_avg`. This was always correct, tag or not,
    which is why A_V and the FUV field never carried the temperature bug.
  - **Emission** — same structure, and with one temperature now the two
    records contribute one Planck function at one T.
  - **Reported mass per species** splits 2:1 across the two labels. Cosmetic:
    the total is right, but the breakdown lists one material twice.

The one place the double duty is a genuine approximation is the photoelectric
yield. `setGrainYield` runs *before* the averaging, so `grainYield` stays
per-axis while the cross section it multiplies has become the average. The
code therefore forms `C_avg * sum w_i Y_i` where the strict orientation
average is `sum w_i C_i Y_i`. Measured on the graphite axes, as-coded over
correct:

    a [um]    0.50 Ryd   0.75 Ryd   1.00 Ryd
    0.005       1.36       1.006      0.990
    0.0354      1.08       1.021      1.000
    0.25        0.985      0.998      1.000

At 0.75-1.0 Ryd, where the photoelectrons actually come from, it is within
2%. The 1.36 sits at the bottom of the band where the yield is 0.004 and the
contribution is some 300 times smaller. Worth knowing, not worth correcting
before something depends on it.

### Why you cannot just supply one pre-averaged n,k file

Because the average is over **cross sections**, and Mie is non-linear in
(n, k). No single (n, k) reproduces `(2/3)Q(eps_perp) + (1/3)Q(eps_par)` across
size and wavelength. Measured on the graphite files in `dustData/`, the ratio
of a naively averaged n,k to the correct answer:

    a [um]   0.1 um   0.55 um   10 um   100 um
    0.005     0.96     1.21     2.14     0.09
    0.0354    1.00     1.16     2.11     0.09
    0.25      1.02     1.01     1.44     0.12

Acceptable in the ultraviolet, where the grain *absorbs*. Catastrophic at
100 um, where it *radiates* — 8 to 11 times too little emissivity, which would
drive the dust temperature far higher than the error the tag exists to fix.
Averaging the dielectric function instead is no better (0.07–1.77).

So the averaging has to happen after Mie, inside MOCASSIN, which is what the
tag asks for.

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

### `Q` format, and a warning

    Q
     label 2200. 2.2 0.323 12.004
     <comment lines>
      90 ... = NRAD
     241 ... = NWAV
       a(um)   lam(um)   Qabs   Qsca   g<cos>
     ...

**`Q` species currently get zero photoelectric yield.** `setGrainYield` is
called only from the `nk` branch of `makeDustXsec`, because the
Weingartner & Draine (2001) yield needs Im(m), which a `Q` file does not
carry. In a PDR model, where the gas temperature is set by grain photoelectric
heating, this fails silently and completely. Do not use `Q` files for a PDR
model until that is fixed.

## What MOCASSIN computes

  - **Opacity** — `Ndust` times the abundance- and size-weighted mixture cross
    section. Always the correct orientation average, independent of the `axes:`
    tag, so extinction, A_V and the FUV field were never affected by the bug
    above.
  - **A_V** — integrated from MOCASSIN's own V-band opacity including
    scattering, `A_V = 1.0857 tau`. For the 150 kK model this gives
    N_H/A_V = 2.75e21, against Cloudy's 2.74e21 (0.4%).
  - **Grain temperature** — per species and per size, from radiative
    equilibrium `integral C_abs J dnu = integral C_abs B_nu(T) dnu`, solved by
    lookup in a table built at 1 K steps. `pdrRad.out` reports the
    abundance- and number-weighted mean.
  - **Photoelectric heating** — WD01 yield by default; `MOCASSIN_YIELD=baldwin`
    selects the older two-parameter form.
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

## Known limitations

  - The model is graphite-only unless silicate is added, giving R_V = 4.57 and
    A(1000A)/A_V = 3.32 against the Milky Way's 3.1 and 2.6–2.8.
  - The gas phase is not depleted for what is locked in grains, so carbon is
    counted twice. Cloudy's reference model does the same, so comparisons are
    unaffected, but absolute abundances are not physical.
  - Gas–grain collisional coupling omits H2.
  - `getQs` caps the Mie size parameter at 100, which for a 0.25 um grain bites
    above 5.8 Ryd.
