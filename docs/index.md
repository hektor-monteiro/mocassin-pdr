# MOCASSIN-PDR

MOCASSIN-PDR follows the gas around a hot star from the H II region, through the
photodissociation region (PDR), into the molecular gas, in three dimensions and in one
model. It is [MOCASSIN](https://mocassin.nebulousresearch.org/), the 3D Monte Carlo
photoionisation and dust radiative-transfer code of {cite:t}`Ercolano2003`, with three
additions:
- the chemistry and thermal balance of [3D-PDR](https://github.com/itamos-ism/3D-PDR)
  {cite:p}`Bisbas2012`;
- a 302-level model of H₂ solved in every cell;
- the feedback of both into the transfer and the thermal balance.

The Monte Carlo radiation field, the dust and the ionisation structure that MOCASSIN
computes drive the chemistry. The chemistry's molecules, heating and cooling feed back
into the next iteration.

:::{note}
These pages describe release `pdr-coupling-v2.0` and the commit they were built from,
shown at the bottom of every page. MOCASSIN-PDR is research code under active
development, and it is not the official MOCASSIN. Results for publication should cite a
release tag ({doc}`reference/citing`).
:::

## What the site holds

- **Getting started.** {doc}`getting-started/install` covers the three builds, SUNDIALS
  and where the data are read from. {doc}`getting-started/running` covers the run
  directory, MPI and memory, warm starts and convergence.
- **User guide.** The complete references, each generated from the code and checked
  against it on every build:
  - {doc}`every input keyword <user-guide/keywords>`;
  - {doc}`every output file <user-guide/outputs>`;
  - {doc}`the build flavours <user-guide/build-flavours>`;
  - the {doc}`dust inputs <user-guide/dust-inputs>`;
  - a worked {doc}`PDR + H₂ run <user-guide/h2-manual>`.
- **Physics and numerics.** {doc}`physics/pdr/index` follows the radiation field into
  the molecular content: the field and its estimator, the dust, the rays, the H₂ level
  model, the rates, the chemistry, the feedback and the convergence. Every process is
  linked to the code block that implements it. {doc}`physics/limitations` lists what is
  known to be wrong, and by how much.
- **Benchmarks.** The current results against Cloudy c25.00 for the two PDR models,
  {doc}`benchmarks/hiipdr` and {doc}`benchmarks/pn150k`, with their provenance.
- **Developer notes.** The {doc}`code map <developer/code-map>`, the
  {doc}`vendored 3D-PDR <developer/vendored-3dpdr>`, the
  {doc}`decision log <developer/devlog-index>` and {doc}`how these pages are built
  <developer/writing-docs>`.

## How the coupling is organised

Every quantity the two codes share is computed once, by the code that owns it, and read
by the other. The chemistry runs in every active cell, and no zone threshold or input
keyword moves a quantity from one code to the other.

| Quantity | Computed by |
| :--- | :--- |
| Radiation field: stellar and diffuse, ionising and FUV, through gas and dust | MOCASSIN (Monte Carlo) |
| Dust: optical properties, temperature per species and size, charge, photoelectric heating | MOCASSIN |
| A_V, and the ratio of FUV to visual extinction | MOCASSIN, from the model's own grains |
| Ionisation balance of every element, and the electron density | MOCASSIN |
| Gas temperature: one thermal balance per cell | MOCASSIN, with the chemistry's heating and cooling terms in it |
| Gas–grain heat exchange: atoms, ions, electrons and H₂ | MOCASSIN |
| Molecular abundances: the REDUCED network, 33 species, steady state | 3D-PDR, solved with CVODE |
| Columns for self-shielding | rays: 12 HEALPix directions per cell (3D build), or a 1D slab |
| H₂ formation on grains | {cite:t}`CazauxTielens2002`, at MOCASSIN's dust temperatures |
| H₂ level populations, photodissociation rate and heating | the H₂ level model (3D build) |
| CO cooling and line emission | the chemistry's level populations, with escape probabilities along the rays |
| C I, C II and O I lines and cooling | MOCASSIN's own atoms, with the chemistry's colliders and escape probabilities |

Each Monte Carlo iteration:
1. transfers the stellar and diffuse packets through gas and dust;
2. solves each cell's ionisation, dust temperatures and charge, and thermal balance;
3. solves the H₂ levels in every cell with gas (3D build), from iteration `pdrStartIter`
   on;
4. runs the chemistry in every active cell;
5. solves the ionisation balance again.

The run stops when the model-integrated convergence test passes (`convTotals`).
{doc}`physics/pdr/iteration` gives the full order and the lags.

```{toctree}
:hidden:
:caption: Getting started

getting-started/install
getting-started/running
```

```{toctree}
:hidden:
:caption: User guide

user-guide/keywords
user-guide/outputs
user-guide/build-flavours
user-guide/environment
user-guide/dust-inputs
user-guide/h2-manual
```

```{toctree}
:hidden:
:caption: Physics and numerics

physics/pdr/index
physics/limitations
```

```{toctree}
:hidden:
:caption: Benchmarks

benchmarks/index
benchmarks/hiipdr
benchmarks/pn150k
```

```{toctree}
:hidden:
:caption: Developer notes

developer/code-map
developer/vendored-3dpdr
developer/devlog-index
developer/writing-docs
```

```{toctree}
:hidden:
:caption: Reference

reference/citing
reference/changelog
reference/licence
reference/bibliography
```
