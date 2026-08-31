# MOCASSIN–PDR Development Log

Running history of the design discussions, decisions and rationale behind coupling the
[3D-PDR](https://github.com/itamos-ism/3D-PDR) photodissociation-region chemistry code into
this fork of MOCASSIN.

Entries are appended in chronological order (oldest first). Decisions carry stable IDs
(`D-001`, …) so later entries can reference, supersede or revert them. When a decision is
superseded, mark the original **[SUPERSEDED by D-nnn]** rather than deleting it — the
reasoning that led to the wrong turn is part of the history.

**Conventions**

- Every decision records *why*, not just *what*. A decision without a rationale is a note.
- Code references are `path:line` against the commit named in the entry header, since line
  numbers drift.
- Measured numbers are marked *measured*; estimates are marked *estimate*.

---

## Index of decisions

| ID | Decision | Status | Entry |
|----|----------|--------|-------|
| D-001 | MOCASSIN's MC field replaces 3D-PDR's `calc_UVfield` | Accepted | 2026-08-28 |
| D-002 | 3D-PDR keeps ownership of line self-shielding column densities | Accepted | 2026-08-28 |
| D-003 | Chemistry network: REDUCED (33 species), user-selectable later | Accepted | 2026-08-28 |
| D-004 | Steady-state chemistry (`CHEMSTEADY=1`), not time-dependent | Accepted | 2026-08-28 |
| D-005 | Vendor 3D-PDR sources into `source/pdr/` | Accepted | 2026-08-28 |
| D-006 | `mocassinWarm` must resume PDR state; persistence lands in Phase 2 | Accepted | 2026-08-28 |
| D-007 | Zone ownership split at x(H+) with a blend band | Accepted | 2026-08-28 |
| D-008 | Do not converge PDR chemistry inside each MC iteration | Accepted | 2026-08-28 |
| D-009 | Build matrix frozen for the coupled build | Accepted | 2026-08-28 |
| D-010 | Maintain this DEV log | Accepted | 2026-08-28 |
| D-011 | PDR checkpoint is `output/pdrGrid.out`, not `grid4.out` | Accepted | 2026-08-28b |
| D-012 | `mocassinPlot` and `mocassinOutput` become PDR-aware via `resetGrid` | Accepted | 2026-08-28b |
| D-013 | `nbins >= 1000` for PDR runs | Accepted | 2026-08-28b |
| D-014 | SUNDIALS >= 7.0.0, pinned at install | Accepted | 2026-08-28b |
| D-015 | SUNDIALS pinned at 7.8.0, installed to `~/software/sundials-7.8.0` | Accepted | 2026-08-28c |
| D-016 | Phase 6 baseline is a fresh standalone run, not the shipped reference files | Accepted | 2026-08-28d |
| D-017 | `PDR=1` build switch; chi diagnostic in `writeFUVField` | Accepted | 2026-08-28e |
| D-018 | All bridge arithmetic in double precision | Accepted | 2026-08-28e |
| D-019 | PDR models REQUIRE dust; gas-only does not transport the FUV field | Accepted | 2026-08-28e |
| D-020 | Vendored build integration and frozen preprocessor matrix | Accepted | 2026-08-28f |
| D-021 | Import 3D-PDR modules only with explicit `only:` lists | Accepted | 2026-08-28f |
| D-022 | Chemistry data lives in `dataPDR/`; paths must become configurable | Accepted | 2026-08-28f |
| D-023 | Build-system staleness: objects depend on `.pdrflag` and the Makefile | Accepted | 2026-08-28g |
| D-024 | PDR input validation must sit outside MOCASSIN's else-if chain | Accepted | 2026-08-28g |
| D-025 | Fix the validation-chain short-circuit in `readInput` | Accepted | 2026-08-28h |
| D-026 | A_V is derived from the model's own grain optics, not from `UV_fac` | Accepted | 2026-08-28i |
| D-027 | Per-cell chemistry in the MC loop; slab-equivalent shielding for now | Accepted | 2026-08-28j |
| D-028 | Declare Fortran module dependencies in the Makefile | Accepted | 2026-08-28k |
| D-029 | Coolants loaded and per-cell PDR heating computed | Accepted | 2026-08-28k |
| D-030 | Line cooling via slab-equivalent escape probability | Accepted | 2026-08-28l |
| D-031 | Thermal balance handed to 3D-PDR; inner loop; latched zone flag | Accepted | 2026-08-28m |
| D-032 | PDR thermal balance folded into MOCASSIN's convergence test | Accepted | 2026-08-28n |
| D-033 | Dust temperature floored at T_cmb; D-009's dust ownership needs revisiting | Accepted | 2026-08-28o |
| D-034 | Benchmark uses MOCASSIN's plane-parallel mode; geometry blocker withdrawn | Accepted | 2026-08-29 |
| D-035 | MOCASSIN has no cosmic-ray physics; ionization state is unreconciled | Accepted | 2026-08-29 |
| D-036 | Dust temperature from HTT91 where MOCASSIN's is unphysically low | Accepted | 2026-08-29b |
| D-037 | Ionization state fed back to MOCASSIN for H and He | Accepted | 2026-08-29b |
| D-038 | Metals fed back too; the "two stages" rationale was wrong | Accepted | 2026-08-29c |
| D-039 | Network elemental abundances synced to MOCASSIN's | Accepted | 2026-08-29c |
| D-040 | No memory leak; OOM was rank-count x replication under systemd-oomd | Accepted | 2026-08-29c |
| D-041 | Reject non-finite level-population solves instead of propagating them | Accepted | 2026-08-29d |
| D-042 | A_V inverted from the MC field degenerates where the field underflows | Resolved by D-043 | 2026-08-29d |
| D-043 | A_V from direct dust-column integration under plane-parallel illumination | Accepted | 2026-08-29e |
| D-044 | Slab illumination normalisation is not yet understood; benchmark still open | Resolved by D-045..D-047 | 2026-08-29e |
| D-045 | `planeIonization` illuminates the y>0 half only; A_V must start at the mid-plane | Accepted | 2026-08-31 |
| D-046 | Six non-fatal advisories inside the readInput else-if chain shadow 27 checks | Accepted | 2026-08-31 |
| D-047 | Launch overhang is reflected back in, so `meanField` IS the incident flux | Revised | 2026-08-31 |
| D-048 | `planeIonization` side walls are specular mirrors: a true infinite slab | Accepted | 2026-08-31 |
| D-049 | Bug: z-min mirror assigns `yAxis(1)` to `rVec%z` in `pathSegment` | Reported | 2026-08-31 |
| D-050 | Hand 3D-PDR the UNATTENUATED field; the local field double-counts extinction | Accepted | 2026-08-31 |
| D-051 | Deterministic thermal seed - attempted, reverted; NaN guard kept | Reverted | 2026-08-31 |
| D-052 | Mother-grid mirror walls omit the half-cell `geoCorr` the other walls use | Accepted | 2026-08-31 |
| D-053 | 3D-PDR's fronts are not the target: MOCASSIN transports diffuse FUV | Accepted | 2026-08-31 |

---

## 2026-08-28 — Initial codebase analysis and architecture

**Participants:** Hektor Monteiro, Claude (Opus 5)
**MOCASSIN commit:** `f37a67e` (branch `dev`)
**3D-PDR:** `itamos-ism/3D-PDR`, default branch, shallow clone
**Goal:** decide whether and how to model PDR chemistry inside this MOCASSIN fork.

### Findings from the analysis

These are the observations the architecture rests on. Each was read directly from source,
not assumed.

**F-1 — MOCASSIN already transports FUV photons.** *measured*

This is the finding that determines the whole shape of the project.

- The frequency grid spans `nuMin = 1.001e-5` Ryd to `nuMax = 15` Ryd over `nbins = 600`
  (`source/set_input_mod.f90:69,107-108`). The FUV band 912–2400 Å is 0.4407–1.0 Ryd,
  comfortably inside it.
- The source PDF `inSpectrumProbDen` is normalised by **energy across all `nbins`**
  (`source/continuum_mod.f90:456-460`), not from `lymanP` upward. Only the photon-count
  normalisation `normConstantPhot` starts at the Lyman limit
  (`source/continuum_mod.f90:449`).
- Therefore non-ionizing packets are emitted and transported *today*, with dust absorption
  and scattering in full 3D plus the diffuse field.

**F-2 — The MC estimators are bin-integrated, not spectral densities.** *measured*

`Jste`/`Jdif` accumulate as `dl*deltaE*weight/dV` (`source/photon_mod.f90:1594-1602`),
are scaled by `1e-9` at `source/iteration_mod.f90:733`, and are divided by 8 when
`lgSymmetricXYZ` at `source/iteration_mod.f90:745`. The comment at
`source/photon_mod.f90:285-292` states the units: **erg s⁻¹ cm⁻², summed over separate
bins** (Lucy 1999 path-length estimator). Each element is therefore `4*pi*J_nu*dnu`.

Consequence: the FUV energy density is a plain sum over bins divided by `c`, with **no
`widFlx` factor**. Applying `widFlx` a second time is the most likely normalisation bug in
this project and is the specific thing the Phase 0 slab test exists to catch.

**F-3 — 3D-PDR photorates are a per-ray sum with a per-reaction attenuation exponent.**

`RATE(I) = sum_k alpha * RAD_SURFACE(k) * exp(-gamma * AV(k))`
(`3D-PDR/src/calc_reac_rates.F90:310`). `gamma` is not geometry — it encodes how that
reaction's cross-section samples the dust extinction curve. Collapsing the field to a
single scalar chi discards that. See D-001 for how this is handled.

**F-4 — Self-shielding needs per-ray column densities.**

H2, HD, CO, CI and SI photodissociation/ionization use dedicated shielding functions taking
`COLUMN_NH2(k)`, `COLUMN_NCO(k)`, `COLUMN_NC(k)`, `COLUMN_NS(k)`
(`3D-PDR/src/calc_reac_rates.F90:250-301`, `3D-PDR/src/shield.F90`). No continuum radiative
transfer produces these — they are line quantities along specific rays.

**F-5 — Four physical processes are modelled by both codes.**

Grain photoelectric heating (`source/update_mod.f90:946` vs `3D-PDR/src/heatingfunctions.F90`),
gas–grain collisional coupling (`source/update_mod.f90:1014`), dust temperature
(`source/update_mod.f90:2353` vs 3D-PDR's HTT91), and [C II]/[O I] emission
(`source/emission_mod.f90:597-616` vs 3D-PDR's non-LTE solver). Left alone the coupled code
double-counts all four. Note that MOCASSIN's `equilibrium` solver assumes **electron
collisions only**, which is wrong in neutral gas.

**F-6 — The two iteration loops have compatible shapes.**

`iterateMC` (`source/iteration_mod.f90:35`) runs: opacity per cell → allreduce →
emissivity per cell → MC transport → allreduce `Jste`/`Jdif` (`:676,:680`) →
`updateCell` per cell (`:857`) → allreduce `Te`/`Ne`/`ionDen`/`Tdust` (`:895-911`) →
convergence test → recurse. Cells are distributed round-robin by
`mod(iCell-(taskid+1),numtasks)==0`. 3D-PDR's per-cell chemistry drops into the
`updateCell` slot without touching the MPI design.

**F-7 — Licences are compatible.** *measured* — both repositories are GPL-3.0.

### Decisions

---

**D-001 — MOCASSIN's Monte Carlo field replaces 3D-PDR's `calc_UVfield`.** *Accepted*

3D-PDR's `UVfield.F90` is **removed from the coupled build, not ported**. The FUV field in
each cell is derived from `Jste + Jdif`.

*Why:* per F-1 and F-2, MOCASSIN's estimator is strictly better than the isotropic
`sum_j rad_surface(j)*exp(-AV(j)*UV_fac)` it replaces — it resolves true 3D geometry,
includes scattering into shadowed regions, and carries the diffuse field. Porting
`calc_UVfield` would mean computing a worse answer alongside a better one.

*Conversion (F-2):*

```
chi(cell) = ( sum_{i in FUV} [ Jste(cell,i) + Jdif(cell,i) ] ) / ( c * u_D )
```

with FUV = bins where `0.4407 <= nuArray(i) <= 1.0` Ryd, and
`u_D = 8.94e-14 erg/cm^3`, the Draine (1978) integrated FUV energy density. The Draine
normalisation is confirmed by `HABING_FIELD = 1.68D0*UV_FIELD` in
`3D-PDR/src/heatingfunctions.F90`, matching the standard Draine→Habing ratio of 1.69.

*Handling the gamma dependence (F-3)* — staged, in increasing fidelity:

1. **Effective A_V** (Phase 3). Define `AVeff = -ln(chi/chi0)/UV_fac`, where `chi0` is the
   unattenuated, geometrically-diluted field from `Lstar` and `starPosition`. Feed 3D-PDR
   `rad_surface(:) = chi0/nrays` and `AV(:) = AVeff`. Every existing rate expression works
   unmodified and the gamma-dependence is preserved approximately.
2. **Band-resolved chi** (Phase 5). Carry 4–5 FUV sub-bands and map each reaction's gamma to
   a representative wavelength.
3. **Direct cross-section integral** — out of scope. The ratefiles carry only alpha and
   gamma; the needed sigma(nu) data exists in neither repository.

*Open risk:* the log mesh gives roughly 0.011 dex per bin, so ≈30 bins span the FUV band
(*estimate* — to be measured in Phase 0). Adequate for an integrated chi, thin for
band-resolved rates. `nbins` is a plain input keyword and costs memory linearly.

---

**D-002 — 3D-PDR retains ownership of line self-shielding column densities.** *Accepted*

The HEALPix ray tracer and `calc_columndens` survive into the coupled build, but their
scope narrows to producing `column_NH2`, `column_NHD`, `column_NCO`, `column_NC`,
`column_NS`.

*Why:* F-4 — these are line quantities along rays that continuum RT cannot supply. This is
the one place 3D-PDR's ray machinery does something MOCASSIN cannot.

*Ordering constraint:* each ray reads neighbouring cells' abundances, so `calc_columndens`
must run **after** the abundance `mpi_allreduce`, not inside the per-cell loop.

---

**D-003 — Chemistry network: REDUCED (33 species), with larger networks user-selectable
after validation.** *Accepted*

Build with `NETWORK=REDUCED` (33 species, 331 reactions —
`3D-PDR/chemfiles/species_reduced.d`, `rates_reduced.d`). Expose the choice through a
`pdrNetwork` input keyword from the start so MEDIUM (77) and FULL (215) can be enabled
without a rebuild-and-edit cycle, but treat anything above REDUCED as unvalidated until the
Phase 6 benchmarks pass.

*Why:* this is a first implementation and the priority is a working coupling, not chemical
completeness. REDUCED keeps the per-cell CVODE solve fast and the memory cost negligible
(33 doubles/cell against MOCASSIN's 600-bin `Jste`, which dominates by two orders of
magnitude). Reading the network from a keyword rather than a compile flag costs almost
nothing now and avoids a disruptive refactor later.

*Implementation note:* 3D-PDR selects the network with a **preprocessor** flag because each
network has its own generated `odes_*.c` (`3D-PDR/src/makefile`). Making `pdrNetwork` a
runtime keyword therefore means either compiling in several `odes_*.o` and dispatching, or
keeping the compile flag and having the keyword *validate* against the compiled-in network
and fail loudly on mismatch. **Start with the second** — it is honest, cheap, and defers the
dispatch work until there is a reason for it.

---

**D-004 — Steady-state chemistry, not time-dependent.** *Accepted*

Build with `CHEMSTEADY=1`.

*Why:* this implementation is a test of the coupling, so a well-defined steady state is more
useful than a chemical age. It also removes a real correctness hazard: inside an MC iteration
loop each cell receives a different number of chemistry calls depending on when its thermal
balance converged, so under time-dependent integration the chemical age would vary from cell
to cell and leave unphysical abundance jumps between neighbours. 3D-PDR's own `config.mk`
documents `CHEMSTEADY` as addressing exactly this, and recommends it.

*Consequence:* `end_time` stops being a physical age and becomes only the initial integration
span that the doubling-block search starts from. The `pdrEndTime` keyword should be
documented that way.

---

**D-005 — Vendor 3D-PDR sources into `source/pdr/`.** *Accepted*

Copy the 3D-PDR sources into `source/pdr/` as part of this repository, rather than a git
submodule or subtree.

*Why:* the sources need local edits (removing `calc_UVfield` per D-001, replacing the driver,
adapting the global `pdr(:)` array to MOCASSIN's cell indexing). Vendoring keeps the build
simple, makes the edits reviewable in normal diffs, and avoids a submodule that every
contributor has to remember to initialise. The cost is that upstream changes must be merged
by hand.

*Provenance requirement:* record the upstream commit SHA and clone date in
`source/pdr/UPSTREAM.md` at import time, so the divergence is always measurable.

*Excluded from the import* (driver and I/O that MOCASSIN supplies instead):
`3DPDR.F90`, ~~`read_input.F90`~~, `readdensity.F90`, `UVfield.F90`, `writeoutputs.F90`,
`restart_io.F90`, `logo.F90`, `read_command_line.F90`.

> **Correction (2026-08-28f):** `read_input.F90` is the LAMDA coolant datafile reader,
> not the parameter reader, and is required by `read_coolants.F90`. The parameter reader
> is `input_parameters.F90`. This list was inferred from filenames; see D-020.

Retain `3DPDR.F90` as a **read-only reference** for call ordering before deleting it — it is
the only place the intended sequence of `calc_columndens` → `chemicaliterations` →
`coolingfunctions` → `changetemperature` → `updatelte` is written down.

---

**D-006 — `mocassinWarm` must resume PDR state; persistence moves into Phase 2.**
*Accepted — filename amended by D-011*

PDR state joins the `output/grid*.out` checkpoint set, and this is built in **Phase 2**
(alongside the grid fields) rather than deferred to Phase 5.

*Why:* PDR runs are expensive and being unable to restart one is a practical blocker, not a
polish item. Building persistence at the same time as the grid fields is also much cheaper
than retrofitting it — the field list is being touched anyway.

*Existing format* (`source/grid_mod.f90:2626-2852` writes, `:2931-3541` reads):

| File | Unit | Contents |
|------|------|----------|
| `grid0.out` | 21 | geometry, axes, `active`/`lgConverged`/`lgBlack` per cell |
| `grid1.out` | 20 | `Te`, `Ne`, `Hden` [, `abFileIndex`] per cell |
| `grid2.out` | 30 | `ionDen` per element/ion per cell |
| `dustGrid.out` | 50 | `Ndust` [, `dustAbunIndex`], `Tdust` |
| `grid3.out` | 40 | scalar simulation parameters |
| `photoSource.out` | 42 | source definitions |

*Plan:* add a new per-cell checkpoint file (named by D-011 — **not** `grid4.out`, see there)
written from **inside the same `i/j/k` cell loop** as the
other per-cell files, so record order stays aligned with `resetGrid`'s read order. Contents
per cell: `pdrZone`, `chiFUV`, `AVeff`, `pdrAbun(cellP, 1:nSpecPDR)`.

Add to `grid3.out`: the PDR-enabled flag, the network name, and `nSpecPDR`, so `resetGrid`
can **validate the checkpoint against the current input and refuse to resume on mismatch**
rather than reading a misaligned file. `lgMultiChemistry` at `source/grid_mod.f90:2710` is
the existing precedent for a conditional record shape — follow it.

Two traps in the existing loop to preserve: the `if (cellP<0) cellP=0` guard, and the
`yTop` 2D handling.

---

**D-007 — Zone ownership split on x(H+) with a blend band.** *Accepted*

Add `grid%pdrZone(cell)` derived from `grid%ionDen(cell, elementXref(1), 2)`. PDR chemistry
runs where x(H+) < 0.5. Photoelectric and gas–grain heating ramp linearly in log x(H+)
between x(H+) = 0.5 and 0.01; every other process switches hard.

*Why:* F-5 — the double-counted processes are exactly the ones that would otherwise produce a
plausible-looking but too-hot PDR, which is the hardest class of bug to notice. Ramping only
the two heating terms keeps the discontinuity out of the temperature structure without
inventing a blend for quantities (ionization state, molecular abundances) where blending has
no physical meaning.

Cells above x(H+) = 0.5 keep `updateCell` untouched, which is what guarantees existing
H II-region benchmarks are unchanged when PDR is off.

---

**D-008 — Do not converge the PDR chemistry inside each MC iteration.** *Accepted*

Take 2–3 chemistry passes per MC iteration and let MOCASSIN's outer loop carry convergence.

*Why:* nesting two independently-converging solvers multiplies their iteration counts and is
the dominant schedule risk. MOCASSIN already treats ionization balance exactly this way —
`updateCell` does not converge the whole nebula, it takes one step and returns. Following the
existing pattern is both cheaper and more consistent.

---

**D-009 — Frozen build matrix for the coupled build.** *Accepted*

| Flag | Value | Rationale |
|------|-------|-----------|
| `DIMENSIONS` | 3 | MOCASSIN grids are 3D Cartesian |
| `RAYTHEIA` | 1 | Recomputes rays on the fly. **Mandatory** — the per-cell `projected`/`length` arrays are what actually exhausts memory at MOCASSIN grid sizes |
| `NETWORK` | REDUCED | D-003 |
| `DUST` | 0 | MOCASSIN owns dust temperature (F-5); inject `grid%Tdust` |
| `THERMALBALANCE` | 1 | Needed for gas temperature in neutral zone |
| `CHEMSTEADY` | 1 | D-004 |
| `CHEMRETRY` | 1 | Recovers stiff cells CVODE's automatic initial step over-reaches |
| `OPENMP` | 0 | MOCASSIN's MPI round-robin already parallelises the cell loop; revisit hybrid only if profiling justifies it |

MOCASSIN side: new `PDR=1` make switch adding `-DPDR`, the SUNDIALS include/lib paths and the
six `-lsundials_*` libraries. **With `PDR` unset the build and binaries must be unchanged** —
this is a hard requirement, and worth an automated check from Phase 1.

*Watch at link time:* `3D-PDR/src/calculate_abundances.c` references ifort-mangled symbols
(`chemistry_module_mp_..._`). Upstream handles this with explicit `bind(c,name=...)`
declarations, but verify rather than assume, since this repo builds with gfortran.

---

**D-010 — Maintain this DEV log.** *Accepted*

Record design discussions and decisions here as the implementation proceeds, with rationale.

*Why:* the reasoning behind a coupling like this is not recoverable from the diff. Several
decisions above (D-001 especially) look arbitrary without the finding that motivated them.

### Scope limits agreed

- Single-grid 3D Cartesian only. `nGrids > 1` and `lg2D` must **fail loudly at startup**
  rather than produce quiet nonsense — 3D-PDR's ray tracer assumes one uniform box.
- Precision: MOCASSIN grid arrays are default `real` (4-byte), 3D-PDR is `real(kind=dp)`
  throughout. Convert explicitly at the bridge entry points. Store `pdrAbun` as double or as
  log — abundances below ~1e-38 underflow in single precision.

### Open items

- [x] Measure the actual FUV bin count and decide whether PDR runs need a larger `nbins`
      — resolved by D-013.
- [x] Confirm the SUNDIALS version to build against and pin it — resolved by D-014.
- [x] Decide whether `mocassinPlot` and `mocassinOutput` also need PDR awareness — resolved
      by D-012 (yes).

---

## 2026-08-28b — Follow-up: output tooling, frequency resolution, SUNDIALS

**Participants:** Hektor Monteiro, Claude (Opus 5)
**Context:** closing the three open items left by the previous entry. Two of them turned up
findings that change the design, so they are recorded as decisions rather than notes.

---

**D-011 — The PDR checkpoint is `output/pdrGrid.out`, not `grid4.out`.** *Accepted*
*Amends D-006.*

**`output/grid4.out` is already taken.** `mocassinPlot` opens it for writing on unit 29
(`source/mocassinPlot.f90:150`), and a 639 KB `grid4.out` from a previous run is sitting in
`benchmarks/test_Problem/output/` right now. D-006 proposed that exact filename.

Had this landed, running `mocassinPlot` after a PDR model would have silently truncated the
PDR checkpoint, and the failure would only have surfaced later as a corrupt or empty resume.

*Decision:* name the PDR checkpoint `output/pdrGrid.out`, following the existing
`dustGrid.out` precedent for an optional per-cell block. Everything else in D-006 stands.

*Process note:* `grid4.out` is referenced nowhere in the README or man page — it is only
visible by grepping the source. Before adding any new file to `output/`, grep for the name
across `source/` first.

---

**D-012 — `mocassinPlot` and `mocassinOutput` become PDR-aware, via `resetGrid`.**
*Accepted*

Both auxiliary drivers gain PDR support. The work is smaller than it looks because it is
mostly shared with D-006.

*Structure:* all three auxiliary drivers — `mocassinWarm` (`source/mocassinWarm.f90:60`),
`mocassinOutput` (`source/mocassinOutput.f90:45`) and `mocassinPlot` — begin with
`resetGrid`. Making **`resetGrid` PDR-aware covers all three at once**; the remaining
per-driver work is only in what each does with the state afterwards:

| Driver | Additional work |
|--------|-----------------|
| `mocassinWarm` | none beyond `resetGrid` — it re-enters `MCIterationDriver` and continues |
| `mocassinOutput` | `outputGas` emits PDR line fluxes and an abundance summary |
| `mocassinPlot` | PDR line emissivities available to the emission-map machinery |

*Why this matters for the design:* neither `mocassinPlot` nor `mocassinOutput` runs the Monte
Carlo, so **neither can recompute `chiFUV`**. They can only read PDR state from the
checkpoint. This confirms D-006's decision to persist derived quantities (`chiFUV`, `AVeff`,
`pdrZone`) alongside the abundances rather than treating them as recomputable — without them
the auxiliary drivers cannot reconstruct the PDR at all.

---

**D-013 — PDR runs should use `nbins >= 1000`.** *Accepted*

*Measurement.* Taken from a real run's `grid3.out`
(`benchmarks/test_Problem/output/grid3.out`), which records `nuStepSize` directly:

```
nbins        = 700
nuMin        = 1.001e-6 Ryd
nuMax        = 15 Ryd
nuStepSize   = 1.374647e-2 dex      <- measured
```

Inverting the construction at `source/grid_mod.f90:246-254` reproduces this exactly and
recovers the split between special and log-mesh points:

```
log-mesh span   = log10(15) - log10(1.001e-6) = 7.17566 dex
iCount          = 7.17566 / 0.0137465 + 1     = 523.0   (exact integer - model confirmed)
special points  = 700 - 523 + 1               = 178.0
```

The 178 special points are the 4.9 GHz radio point, 17 H series edges x 3, the ion edges x 3,
and the dust grid points from `nuDustRyd.dat` (this run has both gas and dust). The FUV band
912-2400 A spans `log10(1/0.4407) = 0.3559` dex, giving:

| `nbins` | step (dex) | FUV bins |
|--------:|-----------:|---------:|
| 600  | 0.01704 | **21** |
| 700  | 0.01377 | **26** |
| 1000 | 0.00874 | **41** |
| 1500 | 0.00543 | **66** |
| 2000 | 0.00394 | **90** |

*Decision:* 21 bins at the default `nbins = 600` is thin — adequate for the scalar chi of
D-001 option 1, but only ~4 bins per sub-band for the band-resolved rates of option 2, which
is not enough to resolve the extinction curve across the band. **Recommend `nbins >= 1000`
for PDR runs** (~41 FUV bins, ~8 per sub-band), and document it against the `nbins` keyword.

*Two secondary findings:*

1. The log mesh spends resolution uniformly in log(nu), so **extending `nuMin` downward costs
   FUV resolution**. At `nbins = 700`, moving `nuMin` from 1.001e-6 to the default 1.001e-5
   recovers roughly 4 FUV bins for free. Do not extend `nuMin` below what the model actually
   needs — the 4.9 GHz radio point is only worth its cost if 5 GHz fluxes are wanted.
2. MOCASSIN already inserts refined triplets at every ion edge, which includes the neutral
   metals — C I (0.83 Ryd), S I (0.76 Ryd), Si I, Mg I, Na I. These sit **inside** the FUV
   band and are exactly the edges that matter for C I and S I photoionization in PDRs. The
   existing mesh is better suited to this than expected; do not disturb it.

*Cost:* `Jste`, `Jdif` and `opacity` are each `(nCells+1) x nbins`. Going 700 -> 1000 is +43%
on the three dominant arrays. Real, but it buys the FUV resolution the whole coupling depends
on.

---

**D-014 — SUNDIALS >= 7.0.0, pinned at install time.** *Accepted*

*Finding:* SUNDIALS is **not currently installed on this machine** — `SUNDIALS_DIR` is unset
and no distribution package is present. This is a Phase 0 blocker, not a Phase 1 one.

*Version floor:* 3D-PDR's link line (`3D-PDR/src/makefile`) is

```
-lsundials_cvode -lsundials_nvecserial -lsundials_sunmatrixdense
-lsundials_sunlinsoldense -lsundials_sunnonlinsolnewton -lsundials_core -lm
```

`sundials_core` was introduced in the **7.0.0** library restructuring; it does not exist in
6.x or earlier. So 7.0.0 is a hard floor, imposed by upstream's link line rather than by
anything we choose.

*Decision:* build against a 7.x release, record the **exact version and build flags** in the
README next to the existing MPI/gfortran prerequisites, and note it here when installed. Do
not float the version — a CVODE change between minor releases would surface as a chemistry
difference and be extremely hard to attribute.

*Install shape* (from 3D-PDR's README, adapted): build SUNDIALS with
`-DCMAKE_INSTALL_PREFIX`, then export `SUNDIALS_DIR` and add its `lib` to
`LD_LIBRARY_PATH`. The MOCASSIN `PDR=1` make switch (D-009) picks up `SUNDIALS_DIR`.

### Open items

- [x] Install SUNDIALS 7.x and record the exact version here and in the README — resolved by
      D-015.
- [ ] Grep `source/` for any other `output/*.out` name before adding files (lesson from D-011).

---

## 2026-08-28c — SUNDIALS installed and verified

**Participants:** Hektor Monteiro, Claude (Opus 5)
**Context:** clearing the Phase 0 blocker identified in D-014.

---

**D-015 — SUNDIALS pinned at 7.8.0, installed to `~/software/sundials-7.8.0`.** *Accepted*
*Implements D-014.*

*Installed and verified.* Not a plan — this is done and tested.

```
version        7.8.0
upstream tag   v7.8.0
commit         aedc088437064dd55b35c000145f7f5db6ee49e3
prefix         ~/software/sundials-7.8.0        (2.4 MB installed)
```

*Version choice.* 7.8.0 was the latest release tag at install time. Before committing to it
one specific compatibility risk was checked: `3D-PDR/src/calculate_abundances.c` includes
`sundials/sundials_types_deprecated.h`, a backwards-compatibility header introduced in the
7.0.0 restructuring that supplies `realtype` and friends. A deprecated header is exactly the
kind of thing that gets dropped in a later minor release, which would break the build. It is
**present in every 7.x tag** (checked v7.0.0, 7.1.1, 7.2.1, 7.3.0, 7.5.0, 7.6.0, 7.7.0,
7.8.0), so there is no reason to pin older than latest. The C file otherwise uses the modern
`SUNContext` API (`SUNContext_Create`, `CVodeCreate(CV_BDF, sunctx)`, `SUNLinSol_Dense`),
which is v6+ and stable across 7.x.

*Configuration.* Only the modules 3D-PDR's link line needs were built, which keeps the
install to 2.4 MB and the build under a minute:

```
-DCMAKE_BUILD_TYPE=Release
-DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=ON
-DBUILD_CVODE=ON
-DBUILD_ARKODE=OFF -DBUILD_CVODES=OFF -DBUILD_IDA=OFF -DBUILD_IDAS=OFF -DBUILD_KINSOL=OFF
-DEXAMPLES_ENABLE_C=OFF
-DSUNDIALS_PRECISION=DOUBLE -DSUNDIALS_INDEX_SIZE=64
-DENABLE_OPENMP=OFF
```

`SUNDIALS_PRECISION=DOUBLE` matches 3D-PDR's `real(kind=dp)` throughout and the `realtype`
in the C layer — do not change it. `ENABLE_OPENMP=OFF` matches D-009's `OPENMP=0`; only
`nvecserial` is on the link line, so the OpenMP vector is not needed.

*Verification.* Beyond checking the six libraries exist, a C program mirroring
`calculate_abundances.c`'s include set and CVODE call sequence was compiled, linked against
the **exact** 3D-PDR library list, and run:

```
gcc -I$SUNDIALS_DIR/include linktest.c -L$SUNDIALS_DIR/lib \
    -lsundials_cvode -lsundials_nvecserial -lsundials_sunmatrixdense \
    -lsundials_sunlinsoldense -lsundials_sunnonlinsolnewton -lsundials_core -lm

-> SUNDIALS 7.8.0 | CVODE integrate t=2.0 y=0.367879 (exact 0.367879)
```

Integrating `y' = -y/2` from `y(0)=1` to `t=2` returns `exp(-1)` to six digits. The toolchain
is confirmed working, not merely present.

*Environment.* `~/software/sundials-7.8.0/env.sh` sets `SUNDIALS_DIR` and prepends the lib
directory to `LD_LIBRARY_PATH`. Source it, or copy its two lines into `~/.bashrc`. The
shell rc was deliberately **not** modified — that is the user's file.

```
source ~/software/sundials-7.8.0/env.sh
```

*Note on `cmake`.* `cmake` is **not installed on this machine**. It was obtained for this
build from a throwaway Python venv (`pip install cmake` -> 4.4.2), which needs no root.
SUNDIALS declares `cmake_minimum_required(VERSION 3.18)`, so cmake 4.x is fine despite its
removal of `<3.5` compatibility. To rebuild SUNDIALS later, either install cmake properly
(`sudo apt install cmake`) or repeat the venv trick — it is worth installing properly, since
the venv used here is temporary.

*Consequence:* the Phase 0 blocker is cleared. D-009's `PDR=1` make switch can now pick up
`SUNDIALS_DIR` as designed.

### Open items

- [x] Add the SUNDIALS prerequisite and `env.sh` usage to the README — done 2026-08-28d.
- [ ] Install `cmake` system-wide so SUNDIALS can be rebuilt without the venv workaround.

---

## 2026-08-28d — 3D-PDR builds and runs; the shipped reference files are stale

**Participants:** Hektor Monteiro, Claude (Opus 5)
**Context:** second half of Phase 0 — build 3D-PDR standalone against the SUNDIALS from D-015
and reproduce a 1D benchmark.

### Build and run

Built clean, no errors, using the stock `src/config.mk` (which already defaults to
`DIMENSIONS=1`, `NETWORK=REDUCED`, `CHEMSTEADY=1`, `CHEMRETRY=1` — matching D-003 and D-004).
The stock `params.dat` reproduces the shipped benchmark: G0=10, zeta=1e-16, dust-to-gas=1,
uniform n_H=1e3 over 122 points from `ics/1Dn30.dat`.

```
build   : clean against SUNDIALS 7.8.0, zero errors
run     : converged after 65 iterations, 0.7 s wall (8 OpenMP threads)
```

**D-015 is confirmed in practice** — the SUNDIALS install links and runs real chemistry, not
just a synthetic test.

### Comparison against `benchmarks/model.pdr.fin`

| Quantity | Agreement |
|----------|-----------|
| x, A_V (geometry) | 5e-7 — bit-comparable |
| T_dust | 1.5e-7 — bit-comparable |
| UV field | 8e-6 |
| **H/H2 front** | **0.05%** |
| **C+/C front** | **0.83%** |
| T_gas, whole profile | max 1.6 K absolute (0.6% at surface, 6.9% at 12 K deep) |
| x(CO), outer PDR | **factor ~3.5 low vs reference** |
| x(CO), A_V=10 | ~20% |
| x(Mg) (trace) | up to 10x, deep only |

The split is diagnostic: **everything that does not depend on the chemistry solver is
bit-comparable**, and the two physically-important fronts agree to under 1%. The build, the
radiation path and the dust treatment are all correct.

---

**D-016 — The Phase 6 comparison baseline is a freshly generated standalone 3D-PDR run,
not the shipped `benchmarks/model.*.fin` files.** *Accepted*

*The shipped reference outputs are stale.* Two independent lines of evidence:

1. **Format.** `benchmarks/model.params` contains three values; the current code writes four
   on the first line plus two further lines. The reference was written by an older version.
2. **History.** `git log` dates the reference files to **2025-11-25** (initial upload), while
   `src/calc_reac_rates.F90` was last modified **2026-07-10** — eight months later.

*Attribution.* Commit `728797f`, "Added condition to treat reactions when Tgas<10K", adds:

```fortran
!     Clamp evaluation temperature to RTMIN for negative-gamma fits
      IF(GAMMA(I).LT.0.0D0 .AND. TEMPERATURE.LT.RTMIN(I)) THEN
         LOCTEMPERATURE=RTMIN(I)
      ENDIF
```

Negative-gamma Arrhenius fits diverge as T falls below their validity range. This model's
deep-cloud gas sits at 10-12 K, exactly where the clamp fires. That accounts for the
deep-cloud T_gas shift (11.49 -> 12.28 K) and is the most likely origin of the CO difference,
since low-temperature CO chemistry runs through such reactions.

**Our run is the more correct one.** The difference is an upstream bug fix landing after the
reference was generated, not a defect in our build.

*Decision:* generate a fresh standalone baseline from the **same vendored source** that gets
coupled (D-005), commit it under `benchmarks/`, and compare the coupled code against that.
Treat the shipped `model.*.fin` files as historical only.

*Why this matters:* had Phase 6 used the shipped files as its target, the ~3.5x CO
discrepancy would have appeared as a regression introduced by the coupling. That is a
phantom failure in the one quantity — CO, a coolant and a key observable — where a real
coupling bug is most likely to hide, and it could have cost weeks.

*Corollary for D-005:* pin the vendored upstream SHA in `source/pdr/UPSTREAM.md` and generate
the baseline from that exact commit. A baseline is only meaningful against a known source
revision.

### Caveat to carry forward

The CO difference is *attributed* to `728797f` by timing and mechanism, not *proven* — no
A/B run was done with the commit reverted. If CO behaviour looks wrong during Phase 3-4
validation, revisiting this is the first place to look. Cheap to settle later: build the
vendored source with and without that clamp and diff the CO profile.

### Open items

- [ ] Install `cmake` system-wide so SUNDIALS can be rebuilt without the venv workaround.
- [ ] Generate and commit the fresh 3D-PDR baseline once the source is vendored in Phase 1
      (D-016).
- [x] Remaining Phase 0 work: the MOCASSIN chi test — done 2026-08-28e, gate passed. See
      D-017 to D-019.

---

## 2026-08-28e — Phase 0 chi test: PASSED, after finding that gas-only models do not transport the FUV field

**Participants:** Hektor Monteiro, Claude (Opus 5)
**Context:** the remaining Phase 0 exit criterion — validate the chi formula of D-001 against
an analytic case before anything is built on it.

### Test design (refined from the original plan)

The plan said "compare chi against the analytic `exp(-UV_fac*A_V)`". That is **not** the right
test: `UV_fac=3.02` and `AV_fac=6.289e-22` are 3D-PDR's own dust parametrisation, whereas
MOCASSIN attenuates with real grain optical constants. Comparing the two conflates the
estimator normalisation with a dust-model calibration.

The estimator normalisation is what Phase 0 must gate, so the test used instead is the
**optically thin limit**, where the answer is exact and parameter-free:

```
chi_MC(cell)   = sum_{FUV bins} [Jste + Jdif] / (c * uDraine)
chi_thin(cell) = L_FUV / (4 pi r^2 c uDraine)
```

`L_FUV` is taken from `inSpectrumProbDen` — the same cumulative energy PDF the packets are
drawn from — so the comparison is internally consistent. This directly gates the three named
suspects: the `1e-9` scaling, the `lgSymmetricXYZ` division by 8, and a spurious `widFlx`.

Cross-check: the code's FUV energy fraction (0.53528) matches the analytic blackbody fraction
for T=25 kK (0.53001) to 1%, and `deltaE * nPhotons = Lstar` exactly. The reference side is sound.

---

**D-017 — `PDR=1` build switch and the `writeFUVField` diagnostic.** *Accepted*

Six files touched, every change behind `#ifdef PDR`:

| File | Change |
|------|--------|
| `Makefile` | `PDR=1` adds `-DPDR`. Phase 1 will hang the SUNDIALS flags off the same switch |
| `constants_mod.f90` | `nuFUVlo=0.44066`, `nuFUVhi=1.0` Ryd, `uDraine=8.94e-14` |
| `common_mod.f90` | `FUVlowP`, `FUVhighP` |
| `continuum_mod.f90` | locate the FUV pointers beside `lymanP`; report the band at startup |
| `output_mod.f90` | `writeFUVField` -> `output/pdrFUV.out` |
| `iteration_mod.f90` | call it from **both** convergence exit paths |

*Verification that the default build is unaffected.* `make` with `PDR` unset was compared
against the pristine tree, `VERSION` pinned to remove the git-describe confound.

**Byte-identity is not achievable and must not be the acceptance criterion.** Three objects
differ — exactly the three files with in-body `#ifdef` blocks. The differences are only
instructions of the form `movl $0x49d -> $0x4a0` into `0x2c0(%rsp)`, which is the `line` field
of gfortran's I/O parameter struct: the source line numbers baked into I/O statements for
runtime error messages. The deltas (3 and 6) are exactly the number of lines inserted above
each site. Normalising those immediates, **all 19 objects are identical**.

So the D-009 criterion is **"semantically unchanged"**, verified by masking line-number
immediates in the disassembly — not `md5sum`. Anyone wiring this into CI needs to know that;
a naive byte-comparison will fail forever.

---

**D-018 — All bridge arithmetic in double precision.** *Accepted*

The first version of the diagnostic returned `chi_thin = 0` in every cell. Cause: in cgs,
`4*pi*r^2*c` is ~4e47 for r ~ 1e18 cm, which **overflows a 4-byte real** (max ~3.4e38),
giving Inf and then a zero quotient — silently, with no warning.

MOCASSIN's grid arrays are default `real`, so this will recur everywhere the bridge touches
cgs luminosities, energy densities or radii. Every bridge computation promotes to
`double precision` and converts explicitly at the boundary. This is the precision hazard the
plan predicted; it appeared on the very first calculation.

---

**D-019 — PDR models REQUIRE dust. Gas-only models do not transport the FUV field at all.**
*Accepted*

**The most consequential finding so far.** With dust off, chi came out a factor **~3.6 low**,
flat in radius, stable across MPI rank count (1 vs 4), grid resolution (11^3, 21^3, 41^3) and
`R_out`. Ruled out in turn: attenuation (`tauNu.out` gives tau_FUV ~ 9e-9), packet loss
(0 trapped, 99.985% of L escapes), path-stretching weights (disabled, `weightFactor=1`),
cell volumes (total matches the analytic sphere), and `safeLimit` truncation.

Direct instrumentation of the accumulation settled it: packets deposited over only
**3.3e17 cm** of path where geometry demands 9.3e17, at **5.3 cell crossings per packet**
instead of ~15. Dropping T_eff to 10 kK made it far worse — **0.04 deposits per packet**.

Root cause, `source/photon_mod.f90:396`:

```fortran
if (.not.lgDust .and. enPacket%nu < ionEdge(1) .and. .not.enPacket%lgLine) then
   ! the packet escapes without further interaction
```

In a **gas-only** model, every continuum packet below the lowest ionization edge is binned
straight into `escapedPackets` and **never traced through the grid**, so it contributes
nothing to `Jste`. This is a correct and sensible optimisation for a pure photoionisation
code — below the lowest edge such photons cannot interact with the gas, and their only role
is the emergent SED. It is fatal for PDR work, where those photons *are* the physics.

It also explains the T_eff dependence exactly: the deficit scales with how much of the
spectrum lies below `ionEdge(1)`.

*Decision:* **PDR models require `lgDust = .true.`** This is not a workaround — it is
physically mandatory anyway: A_V is a dust quantity, photoelectric heating is a dust process,
and H2 forms on grains. With dust on, the shortcut cannot fire and packets are traced normally.

*Implemented now:* `writeFUVField` warns loudly when `lgDust` is false. *Phase 2 must* turn
this into hard input validation that refuses to start.

*Second-order trap:* the threshold is `ionEdge(1)`, the lowest edge among the **elements
actually enabled**. So in a gas-only model the FUV cutoff silently moves when the abundance
file changes. Another reason to require dust rather than reason about the shortcut.

### Result — Phase 0 gate PASSED

With dust enabled (`Ndust constant 1.e-12`, optically thin):

| | median ratio MC / analytic |
|---|---|
| **FUV chi** | **1.0024** |
| **Bolometric control** | **1.0023** |

Flat across radius (0.983-1.049; the scatter is MC noise). The chi formula of D-001 is
validated **to 0.3%**, and with it: the `1e-9` scaling is right, there is **no** `widFlx`
factor, `lgSymmetricXYZ` is handled correctly (sym and nosym agree to 0.3%), `uDraine =
8.94e-14` is right, and `L_FUV` from `inSpectrumProbDen` is right.

### Notes

- FUV band width is **58 bins** at `nbins=1000` in this gas-only run, against the ~41
  predicted in D-013. D-013's table was computed for a gas+dust mesh, which spends points on
  `nuDustRyd.dat`. Since D-019 makes dust mandatory, **D-013's numbers are the ones that
  apply** and its `nbins >= 1000` recommendation stands.
- `output/pdrFUV.out` carries a bolometric control column (all bins vs `L_bol/4 pi r^2`)
  alongside the FUV one. It is what separated "estimator normalisation" from "FUV band
  selection", and is worth keeping.

### Open items

- [ ] Install `cmake` system-wide so SUNDIALS can be rebuilt without the venv workaround.
- [ ] Generate and commit the fresh 3D-PDR baseline once the source is vendored (D-016).
- [ ] Phase 2: hard input validation refusing to start a PDR run with `lgDust = .false.` (D-019).
- [ ] Phase 2: `writeFUVField` currently writes from both `iterateMC` exit paths only; decide
      whether `mocassinOutput` should regenerate it from the checkpoint (D-012).

---

## 2026-08-28f — Phase 1: vendored, building, chemistry running

**Participants:** Hektor Monteiro, Claude (Opus 5)
**Context:** Phase 1 — vendor 3D-PDR into `source/pdr/`, link it against the SUNDIALS of
D-015, and get a single cell of chemistry running inside MOCASSIN's build.

**Phase 1 exit criterion met:** `make PDR=1` links all four binaries, and a hardcoded
single-cell call to `calculate_abundances` returns sane abundances.

---

**D-020 — Vendored build integration and frozen preprocessor matrix.** *Accepted*

Vendored at upstream `fabcdc64` (2026-08-26), recorded in `source/pdr/UPSTREAM.md`:
44 `.F90` + 5 `.c`, 916 KB. Chemistry data goes to `dataPDR/` (see D-022).

*Build wiring.* `PDR=1` now adds `-DPDR`, the frozen 3D-PDR matrix, the SUNDIALS
include/lib flags, and the vendored objects to all four link targets:

```
-DTHERMALBALANCE -DREDUCED -DRAYTHEIA -DRAYTHEIA_MO -DH2FORM_CT02
-DCHEMSTEADY -DCHEMRETRY -DFORCECONVERGENCE
-DNGACCEL -DNGCYCLE -DNGRELAX -DILLINOIS -DREBRACKET -DSOBOLEV
```

Deliberately **not** set, each for a reason already decided: `ONEDIMENSIONAL` (3D grids),
`DUST` (D-005/F-5 — MOCASSIN owns dust temperature), `OPENMP` (D-009 — MPI already
parallelises the cell loop), `CHEMANALYSIS` (`temp_rate(nreac,ncells)` is prohibitive in
3D), `GUESS_TEMP` (it lives inside `calc_UVfield`, which D-001 removes).

*`-rpath`.* The link line embeds `-Wl,-rpath,$(SUNDIALS_DIR)/lib`, so the binaries resolve
SUNDIALS without `LD_LIBRARY_PATH` being set at run time. Only `SUNDIALS_DIR` at build time
is needed. Worth keeping — the alternative is a class of "works on my machine" failures.

*The filename trap.* D-005's exclusion list was inferred from filenames and was wrong:
**`read_input.F90` is the LAMDA/RADEX coolant datafile reader**, called by
`read_coolants.F90`, not the parameter reader. Excluding it would have broken the build.
The parameter reader is `input_parameters.F90`.

Revised approach, and the safer rule generally: **vendor the whole tree, compile a subset.**
Unused sources cost nothing, keep the mirror faithful for future merges, and remove the
temptation to guess a file's role from its name. The compiled subset and the reason each
file is excluded are tabulated in `UPSTREAM.md`.

*Default build unaffected.* With `PDR` unset, all 19 MOCASSIN objects remain semantically
identical to the pristine tree (per the D-017 line-number-masking method), and no
`source/pdr/*.o` is built at all.

---

**D-021 — Import 3D-PDR modules only with explicit `only:` lists.** *Accepted*

The first version of the smoke test used blanket `use maincode_module` /
`use global_module` and failed immediately:

```
Error: Symbol 'i'  conflicts with symbol from module 'maincode_module'
Error: Symbol 'nh' conflicts with symbol from module 'global_module'
```

`maincode_module` exports loop counters `i`, `j`, `k`, `p` as module variables;
`global_module` exports species indices `NH`, `NC`, `NO`. Any blanket `use` collides with
ordinary local names.

*Decision:* every import of a 3D-PDR module carries an explicit `only:` list. This is a
correctness rule for the Phase 2 bridge, not a style preference — the bridge will `use`
both codebases' modules in one scope, which is exactly where these collide.

*Related, and checked:* three procedure names exist in both trees — `readinput`, `spline`,
`splint`. `nm` confirms there is **no link clash**: MOCASSIN's are module procedures
(`__interpolation_mod_MOD_spline`), 3D-PDR's are bare externals (`spline_`). But a source
file that `use`s `interpolation_mod` and also calls 3D-PDR's `spline` will silently bind to
MOCASSIN's. Documented in `UPSTREAM.md`.

---

**D-022 — Chemistry data in `dataPDR/`; the hardcoded paths must become configurable.**
*Accepted*

`chemfiles/` is vendored to `dataPDR/` at the repository root, matching the existing
`data/` and `dustData/` convention, and should join them in the `install` target.

*Problem found:* `read_species.F90`, `read_rates.F90` and `input_parameters.F90` all open
their data through a **hardcoded relative path**, `"chemfiles/species_"//suffix`. MOCASSIN
resolves its data as `PREFIX//"/share/mocassin/data"`, so a PDR run would only work from a
directory that happens to contain a `chemfiles/` link.

*Phase 2 must* make these paths configurable — either a `pdrDataDir` keyword defaulting to
`PREFIX//"/share/mocassin/dataPDR"`, or a small patch to the three vendored readers
(recorded in `UPSTREAM.md` as a local modification if so). Until then, anything driving the
chemistry runs from a directory with a `chemfiles` link.

*The complete parameter set MOCASSIN must supply* is `readparams`
(`source/pdr/input_parameters.F90`) — this is the definitive list for the Phase 2 keywords:

| Group | Variables |
|---|---|
| Radiation / CR | `Gext`, `zeta` (stored as zeta/1.3e-17), `AV_fac` (x metallicity), `UV_fac` |
| Grains | `grain_radius`, `omega` (=0.42, hardcoded), `metallicity` |
| Thermal | `Tguess`, `Tmin` (floored at `Tcmb`), `Tmax`, `dust_temperature`, `Fcrit`, `Tdiff`, `Tlow0`=10, `Thigh0`=8000 |
| Chemistry | `end_time`, `chemiterations`, `ITERTOT`, both CVODE tolerances |
| Geometry | `level` (HEALPix), `theta_crit`, and under RAYTHEIA `nxc,nyc,nzc,xlx,yly,zlz` + `call Mesh` |
| Other | `v_turb_inp`, `redshift` -> `Tcmb`, `Av_crit`, `v_alfv` (stored as v^2*40.382518), `coolfile(:)`, `coo` |
| Derived | `nspec`, `nreac` — obtained by counting lines in the species/rates files |

---

### Smoke test result

`make PDR=1 pdrSmokeTest` builds `source/pdrSmokeTest.f90`, which drives the whole chain
for one cell at n_H=1e3, T_gas=50 K, T_dust=20 K, chi=10, A_V=3. The radiation field is
supplied in exactly the D-001 form — `rad_surface(k)=chi/nrays`, `AV(k)=AVeff` on all 12
rays — so the rate sum collapses to `alpha*chi*exp(-gamma*AVeff)`. That makes the test a
first exercise of the Phase 3 coupling shape, not just a link check.

```
network   : reduced.d -> 33 species, 331 reactions
rates     : nonzero 303/331
x(H)  = 1.85e-03   x(H2) = 4.99e-01
x(C+) = 1.69e-05   x(C)  = 1.03e-04   x(CO) = 2.03e-05
charge imbalance = 0.0000 %
```

The physics is right, not merely non-crashing: the gas is fully molecular at A_V=3;
C+ + C + CO = 1.4e-4, matching the input C/H exactly (elemental conservation); and charge
balances to the printed precision. **Charge balance is the sharpest available check** — the
solver does not impose it, so it only emerges if every rate and stoichiometry was read
correctly and CVODE converged.

The test asserts both conditions and exits non-zero on failure, so it is a regression test
rather than a print-and-eyeball.

### Open items

- [ ] Install `cmake` system-wide (carried from D-015).
- [ ] Generate and commit the fresh 3D-PDR baseline (D-016) — now possible, the vendored
      source is pinned.
- [x] Phase 2: hard validation refusing a PDR run with `lgDust=.false.` (D-019) — done, see D-024.
- [x] Phase 2: make the `chemfiles/` paths configurable (D-022) — done via `chemPath`.
- [x] Phase 2: add `dataPDR/` to the Makefile `install` target — done.

---

## 2026-08-28g — Phase 2: grid fields, keywords, bridge skeleton, warm-restart persistence

**Participants:** Hektor Monteiro, Claude (Opus 5)

**Phase 2 exit criterion met:** a PDR-enabled run allocates, reads the network, and writes
`output/pdrGrid.out`; `mocassinWarm` re-reads it. The round-trip is **lossless — 9261/9261
abundance records identical** after write -> read -> write, with chemistry still stubbed.

### What landed

| Area | Change |
|---|---|
| `common_mod.f90` | `grid_type` gains `pdrZone`, `chiFUV`, `AVeff`, `pdrCool`, `pdrAbun` (double, per D-018), plus the PDR control block |
| `set_input_mod.f90` | 16 `pdr*` keywords; validation (D-024) |
| `pdr_mod.f90` | new bridge: `initPDRnetwork`, `seedPDR`, `mocassinToPDR`, and `pdrStep`/`pdrToMocassin` as marked Phase 4 stubs |
| `grid_mod.f90` | PDR array allocation with the other grid arrays; `pdrGrid.out` write and read; PDR header in `grid3.out` |
| `iteration_mod.f90` | `mocassinToPDR` before the checkpoint write, so it carries real state |
| all four drivers | `initPDRnetwork` before any grid allocation |
| `man/mocassin.1` | the keywords documented |
| `Makefile` | `dataPDR/` installed; bridge slotted into `SOURCES` |

*Path handling (D-022).* `chemPath` was added to `maincode_module` and the two compiled
readers now open through it. Recorded in `UPSTREAM.md` as the only local modification to the
vendored tree; the default preserves upstream behaviour exactly.

*Allocation lives in `grid_mod`, not the bridge.* The first cut allocated in `initPDR`, but
`resetGrid` reads into those arrays on the warm-start path and `grid_mod` is compiled before
`pdr_mod`. Splitting it — `grid_mod` allocates alongside every other per-cell field,
`pdr_mod` only reads the network and seeds — removes the ordering problem entirely.

*Coolants deferred.* `read_species.F90:175` indexes `coolant(1:coo)`, an array only
`read_coolants` allocates. Setting `coo` without calling it segfaults. The coolant filenames
are resolved now but `coo` stays 0 until Phase 4, where the level populations need them.
Better a correct stub than a latent trap.

---

**D-023 — Objects depend on `.pdrflag` and on the Makefile.** *Accepted*

Two stale-object failures cost real time, both the same class: **make cannot see that the
compile flags changed.**

1. Toggling `PDR` left `constants_mod.o` from the previous mode. The `.mod` file then lacked
   the `#ifdef PDR` symbols and the build failed with a baffling `Symbol 'udraine' has no
   IMPLICIT type` in a file that clearly declares it.
2. Adding a compile *rule* for `pdr_mod.o` did not rebuild `pdr_mod.o`, so the binary kept a
   version compiled without `-DREDUCED`. That one surfaced as a **runtime** error — the
   network validator reporting "built with 'none'" — which is much worse than a build error.

*Decision:* a `.pdrflag` stamp file records the current `PDR` value and every object depends
on it, plus on `Makefile` itself. Verified: `PDR=1` -> unset -> `PDR=1` with no manual
`make clean` now works.

*Worth noting the second failure was caught only because the network validator of D-003
exists.* Without it the run would have proceeded with a silently mismatched ODE system. That
is the argument for validators that check what was compiled against what was asked for.

---

**D-024 — PDR input validation must sit outside MOCASSIN's `else if` chain.** *Accepted*

The `lgDust` refusal (D-019) was added into `readInput`'s validation chain and **did not
fire**. The reason is a **pre-existing MOCASSIN bug**, not anything introduced here:

```fortran
else if (nuMin > 1.4e-6) then
    print*, "! readInput [waring]:  nuMin ... too large to include 5GHz ..."
else if (R_out < 0.) then          ! <- unreachable for almost every model
```

That branch is a **non-fatal warning inside an `else if` chain**. The default `nuMin` is
`1.001e-5`, comfortably greater than `1.4e-6`, so the warning branch is taken for
essentially every model and the chain terminates there. **Nine subsequent checks are dead
code**, including `R_out < 0`, `R_in < 0`, `R_in >= R_out` and
`lgMultiChemistry .and. .not.lgDfile`.

*Decision here:* the PDR validations are standalone `if` blocks after the chain, so they run
unconditionally. Verified: a PDR run without dust is now refused, and a valid one still runs.

*Not fixed, deliberately.* Restructuring the chain would make nine previously-dormant checks
start firing, which could reject existing user models that have been running with latent
invalid input. That is a behaviour change with real blast radius and it is the maintainer's
call, not a side effect of PDR work. **Flagged for Hektor to decide.** The minimal fix is to
turn the warning into a plain `if` that does not consume the chain.

### Verification

- Fresh PDR run: network read (33 species, 331 reactions), `pdrGrid.out` 8.5 MB / 9261
  records x 33 abundances, `chiFUV` non-zero in all 4169 active cells (max 1.2e4 Draine),
  `AVeff` non-zero in 1686.
- `mocassinWarm`: re-reads and re-writes losslessly, 9261/9261 records identical.
- `pdr` without dust: refused with the D-019 message.
- Network mismatch: refused with the D-003 message.
- With `PDR` unset: all 19 MOCASSIN objects semantically identical to pristine, and zero PDR
  objects compiled.

### Open items

- [ ] Install `cmake` system-wide (carried from D-015).
- [ ] Generate and commit the fresh 3D-PDR baseline (D-016).
- [x] **Decide whether to fix the `else if` chain bug** (D-024) — fixed, see D-025.
- [ ] Phase 3: replace `AVeff`'s single-star assumption — `mocassinToPDR` currently
      geometrically dilutes from `starPosition(1)` only.
- [ ] Phase 4: `read_coolants`, then `coo` can be set for real.

---

## 2026-08-28h — Fixing the validation-chain short-circuit

**Participants:** Hektor Monteiro, Claude (Opus 5)
**Context:** D-024 flagged a pre-existing bug and left the fix to the maintainer. Hektor
asked for it to be fixed.

---

**D-025 — `readInput`'s non-fatal `nuMin` advisory no longer consumes the validation chain.**
*Accepted*

### The bug

`readInput` validates its inputs with one long `if / else if` chain in which every branch
reports an error and calls `stop`. One branch did not:

```fortran
else if (nuMin > 1.4e-6) then
    print*, "! readInput [waring]:  nuMin ... too large to include 5GHz flux calculations"
else if (R_out < 0.) then          ! <-- and everything below here
```

Because it is an `else if` that returns without stopping, matching it ends the chain. The
default `nuMin` is `1.001e-5`, comfortably greater than `1.4e-6`, so **for essentially every
model MOCASSIN has ever run, the branch matched and every check below it was skipped.**

The checks that were unreachable:

| Check | What it catches |
|---|---|
| `R_out < 0.` | negative outer radius |
| `R_in < 0.` | negative inner radius |
| `R_in >= R_out` | inverted geometry |
| `lgMultiChemistry .and. .not.lgDfile` | multi-chemistry without a density file |
| `fillingFactor > 1.` | unphysical filling factor |
| `lgDfile` vs `Rn{x,y,z}` consistency (x2) | conflicting density specifications |
| `lgPlaneIonization` consistency (x2) | plane-ionization misconfiguration |

None of these are exotic: they are the guards against exactly the input mistakes a new user
makes. They have been silently inert.

*How it surfaced.* The D-019 `lgDust` refusal was added into that chain and simply never
fired. The PDR work did not create the bug; it tripped over it.

### The fix

The advisory is hoisted out of the chain into a standalone `if` immediately after the input
file is closed, where it still prints for the models that warrant it but no longer terminates
the chain. The chain itself is otherwise untouched, so every branch keeps its original
condition and message.

The PDR checks added in D-024 stay standalone as well — that remains the right pattern for
anything that must not depend on its position in a chain.

### Blast-radius check

The concern in D-024 was that reviving nine dormant checks could reject models that currently
run. Every shipped benchmark was run against the fixed binary and checked for a fatal
`! readInput:` rejection:

| Model | Result |
|---|---|
| `benchmarks/gas/HII20`, `HII40`, `PN75`, `PN150` | pass (nuMin advisory still shown) |
| `benchmarks/test_Problem` | pass |
| `benchmarks/dust/1D/tau1.000`, `2D/tau1.000` | pass |
| the PDR test model | pass, runs end to end |

**No shipped model is rejected.** The advisory still prints for all of them, as before — it
is the same message, just no longer swallowing its successors.

### Note for the maintainer

Any model that *is* now rejected has a genuine input error that MOCASSIN was previously
ignoring; the message will say which. Worth mentioning in release notes, since a user with a
long-standing bad input file will see a new hard stop.

### Open items

- [ ] Install `cmake` system-wide (carried from D-015).
- [ ] Generate and commit the fresh 3D-PDR baseline (D-016).
- [x] Phase 3: `mocassinToPDR` dilutes from `starPosition(1)` only — fixed, see D-026.
- [ ] Phase 4: `read_coolants`, then `coo` can be set for real.

---

## 2026-08-28i — Phase 3: radiation coupling, with A_V measured rather than assumed

**Participants:** Hektor Monteiro, Claude (Opus 5)

---

**D-026 — A_V,eff is derived from the model's own grain optics.** *Accepted*

### The question Phase 3 actually had to answer

The plan framed Phase 3 as reconciling MOCASSIN's real grain optics with 3D-PDR's
`AV_fac`/`UV_fac` parametrisation. Checking where those constants are actually *read* in the
frozen build matrix (D-009) changed the framing:

| Constant | Uses in the compiled subset | Status |
|---|---|---|
| `AV_fac` | 3, all in `CRattenuation.F90` | inside `#ifdef CRATTENUATION` — **not set** |
| `UV_fac` | 6 in `calc_reac_rates.F90` | 1 is the `use` statement; the other 5 are inside `#ifdef GRAINRECOMB` — **not set** |

**Neither constant is read by any active code path.** They enter the coupled model only
through how *we* define `A_V,eff`. So the job is not to match 3D-PDR's constants — it is to
make `A_V,eff` a genuine visual extinction, because every `gamma` in the reaction network is
fitted against a standard extinction curve with A_V in magnitudes on the abscissa. Get the
abscissa wrong and all 331 reactions are wrong together, consistently and invisibly.

### What was implemented

`calibratePDRdust` measures the FUV-to-visual extinction ratio from MOCASSIN's own dust
arrays, once per run:

```
R_FUV = <kappa_abs + kappa_sca>(FUV) / (kappa_abs + kappa_sca)(V, 5500 A)
A_V   = 1.0857 * tau_FUV / R_FUV            [magnitudes]
```

Three details that matter:

- **Extinction, not absorption.** A scattered FUV photon leaves the beam exactly as an
  absorbed one does.
- **Weighted by emitted energy per bin, not by bin width.** `chi` is a band-integrated energy
  density, so the extinction it experiences is the spectrum-weighted one. On a log-nu mesh
  `widFlx` grows with nu, so a width-weighted average over-weights the 912 A end where the
  opacity is steepest. The weight used is the bin-to-bin increment of
  `inSpectrumProbDen` — by construction the emitted energy fraction in that bin. (Effect is
  modest here, ~7%, but it is free and removes a known bias.)
- **`A_V` in magnitudes**, hence the 1.0857 factor. 3D-PDR's `exp(-gamma*A_V)` takes
  magnitudes; `tau_V` would be wrong by that factor throughout.

`mocassinToPDR` was also generalised from a single source to **all** sources: the
unattenuated field is now the sum of each source's own inverse-square dilution from its own
position, rather than one lumped luminosity diluted from `starPosition(1)`.

### Validation

The routine was run against three dust models in an otherwise identical nebula:

| Dust model | R_FUV | implied `UV_fac` | vs canonical 3.02 |
|---|---|---|---|
| 0.07-50 um, 98% silicate (the shipped `test_Problem` grains) | 1.12 | 1.03 | grey, 3x low |
| MRN 0.005-0.25 um, 98% silicate | 5.26 | 4.85 | 61% high |
| **MRN 0.005-0.25 um, silicate + carbonaceous + PAH** | **3.24** | **2.99** | **1% agreement** |

**Standard ISM dust reproduces 3D-PDR's canonical constant to 1%.** That is the validation:
an independent measurement through MOCASSIN's grain optics, MOCASSIN's frequency mesh and
MOCASSIN's opacity arrays lands on the literature value, which would be a remarkable
coincidence if any step of the chain were wrong.

The other two rows are the argument for measuring instead of assuming. Both are *plausible*
inputs — the large-grain model is what `benchmarks/test_Problem` actually ships — and both
would have silently mis-scaled every photorate in the network by factors of 1.6 to 3. A
warning fires when the measured value departs from canonical by more than 25%.

*Caveat, stated plainly:* a single scalar `A_V,eff` cannot exactly represent band-integrated
attenuation of a wavelength-dependent opacity — the band hardens with depth, so the effective
ratio drifts. This is the D-001 option-1 approximation, and D-026 makes its zero point
correct rather than assumed. Option 2 (band-resolved chi) remains the upgrade path if the
residual matters.

### Phase 3 status

Delivered: `chi` (validated to 0.3% in Phase 0), `A_V,eff` on a measured footing, multi-source
dilution, the zone flag, and the dust calibration with its warning.

**Not yet delivered:** the plan's Phase 3 gate — reproducing a 3D-PDR 1D benchmark end to end
— needs the per-cell chemistry loop, which is Phase 4 work. Phase 3 has built and validated
every input that loop consumes; it has not yet run it. Being explicit so the gate is not
recorded as passed when it has not been attempted.

### Open items

- [ ] Install `cmake` system-wide (carried from D-015).
- [ ] Generate and commit the fresh 3D-PDR baseline (D-016).
- [ ] Phase 4: `read_coolants`, then `coo` can be set for real.
- [ ] Phase 4: the 1D benchmark gate.
- [ ] Consider deriving `pdrAVfac` from the dust too, for consistency if `CRATTENUATION` is
      ever enabled — it is currently an unused input.

---

## 2026-08-28j — Phase 4a: chemistry running inside the Monte Carlo loop

**Participants:** Hektor Monteiro, Claude (Opus 5)

---

**D-027 — Per-cell PDR chemistry inside `iterateMC`, with slab-equivalent shielding.**
*Accepted*

`pdrStep` is implemented and wired into `iterateMC` using **the same round-robin
decomposition as `updateCell`** (`mod(iCell-(taskid+1),numtasks)==0`) — per-cell chemistry is
embarrassingly parallel and needed no new MPI design, exactly as F-6 predicted.

It takes `pdrChemIter` passes and returns; the outer MC loop carries convergence (D-008).
The radiation field is handed over in the D-001 effective-A_V form, so 3D-PDR's own rate sum
collapses to `alpha*chi*exp(-gamma*A_V,eff)` with A_V measured from the model's grains (D-026).

*Scope, stated honestly.* This is **4a: chemistry only.** It runs *in addition to*
`updateCell`, not instead of it. Handing thermal balance to 3D-PDR in the neutral zone
(D-007) needs the cooling functions and `read_coolants`, and is 4b.

*Shielding columns are slab-equivalent, not ray-traced.* N_H is recovered from the local
extinction as `A_V/AV_fac` and each shielding column is that times the local abundance. For a
1D slab — the geometry of every published PDR benchmark — this is exact; for genuinely 3D
geometry it is an approximation and the HEALPix trace of D-002 is the upgrade. Flagged, not
hidden. It also finally gives `pdrAVfac` a real role; it was an unused input until now.

### Three bugs found, in ascending order of subtlety

**1. The MPI reduction pattern does not transfer.** `Te`/`Ne`/`ionDen` are reduced by
building a *zeroed* temporary that only owned cells write, then SUM. `pdrAbun` cannot use
that pattern: every rank holds a full **seeded** copy, so a plain SUM multiplies it by
`numtasks`. The fix is that each rank contributes only the cells it owns, and contributes
them **whether or not `pdrStep` changed anything** — otherwise cells it skipped (inactive, or
outside the PDR zone) come back zero and lose their seeded abundances. Cell 0 is deliberately
excluded: several `(i,j,k)` map to it, so it would be counted many times.

**2. `calculate_abundances` fails silently.** When CVODE cannot advance — which happens for
the stiffest cells right at the illuminated face, even with `CHEMRETRY` — the C routine
copies the state vector back **unconditionally** (`calculate_abundances.c:440-450`). The
initial abundances are written out and are indistinguishable from a converged result.
`pdrStep` now compares the vector before and after and flags a non-advancing cell as
`pdrZone = 2`, with a per-iteration count reported. Better a visible failure than data that
looks real.

**3. The zone flag and the abundances could disagree.** This one was genuinely subtle and is
the reason the first two fixes were not enough. `mocassinToPDR` was being called **twice per
iteration** — once before the cell loops, and again just before `writeGrid`. The second call
recomputed `pdrZone` *after* the last `pdrStep`. Any cell that had just crossed the x(H+)
threshold was therefore written to the checkpoint labelled "PDR zone" while still holding its
**seed abundances** — a cell that had never had chemistry run on it, presented in the output
as if it had.

74 of 4150 zone cells were affected, all at the ionization front. They were not solver
failures: the stalled-cell detector correctly reported zero. The second call was redundant
anyway — the radiation field has not changed since the first — so it is removed.

*What this cost to find, and what it says:* the seed abundances (x(H)=0.4, x(H2)=0.3) are
plausible PDR-surface values. Had the seed been zeros the problem would have been obvious
immediately. **A seed that looks like a physical answer hides its own failure to be
replaced.** Worth remembering when choosing initial conditions for the thermal-balance work.

### Verification

Model: n_H = 2000, `MdMg constant 0.01` (standard ISM dust-to-gas), T_eff = 25 kK,
R = 1e18 cm, MRN silicate + carbonaceous grains, 4 MPI ranks.

```
radial tau_FUV = 5.11   tau_V = 1.51   A_V = 1.64 mag
tau_FUV/tau_V  = 3.38   vs the 3.24 measured independently by calibratePDRdust
```

That agreement is a useful cross-check: `tauNu.out` and `calibratePDRdust` compute the ratio
by different routes and land within 4%.

| Check | Result |
|---|---|
| Cells running chemistry | 4076 |
| Stalled (`pdrZone=2`) | **0** |
| Zone cells holding seed values | **0** (was 74) |
| Carbon conservation, deepest cell | sum C-bearing = 1.4000e-4 vs input C/H 1.4e-4 |
| Charge balance | cations 1.5964e-4, electrons 1.5964e-4 — **exact** |
| chi vs A_V | monotonically attenuated, 424 -> 0.51 over A_V 0.08 -> 1.16 |
| x(H2), x(C) vs A_V | both rise monotonically with shielding |

The gas remains atomic, which is **correct** at these columns: at A_V ~ 1 and chi ~ 0.5,
photodissociation (~8e-13/s) still exceeds grain formation (~6e-14/s). Molecular gas needs
A_V >~ 3. The Phase 1 smoke test already demonstrated a fully molecular solution at A_V = 3
through the same code path, so both branches of the chemistry are exercised.

*Aside worth recording:* `Ndust constant` does **not** scale the dust column linearly — 2500x
in `Ndust` produced 23x in tau. `MdMg constant` behaves as expected and is the right control
for PDR work. Whatever `Ndust`'s normalisation is, it is not grain number density in the
naive sense; not chased further, but noted.

### Open items

- [ ] Install `cmake` system-wide (carried from D-015).
- [ ] Generate and commit the fresh 3D-PDR baseline (D-016).
- [~] Phase 4b: `read_coolants` and `coo` done, heating done (D-029). Cooling and the
      thermal-balance handover remain.
- [ ] Phase 4c / D-002: HEALPix-traced shielding columns for genuinely 3D geometry.
- [ ] The 1D benchmark gate carried from Phase 3 — now reachable once 4b lands.
- [ ] Investigate `Ndust constant` normalisation, or document `MdMg` as the supported control.

---

## 2026-08-28k — Phase 4b: coolants loaded, heating computed, and three ordering bugs

**Participants:** Hektor Monteiro, Claude (Opus 5)

---

**D-028 — Fortran module dependencies are declared in the Makefile.** *Accepted*

The Makefile expressed **no** inter-module dependencies. Editing a foundational module left
its dependents compiling against a stale `.mod`, which surfaces as
`Mismatch in components of derived type 'grid_type'` — an error that reads like a source
problem and is actually a build-order one. Worse, for a **character length** change it
produces no error at all: `read_coolants.o` kept a `len=50` view of `coolfile` and silently
truncated every path.

Two dependency layers are now declared:

```
MODBASE = constants_mod.o vector_mod.o common_mod.o    (everything depends on these)
PDRBASE = pdr/definitions.o pdr/healpix_types.o pdr/modules.o   (all vendored units)
```

Verified: touching `common_mod.f90` now rebuilds 20 objects instead of 1.

This is the third instance of the same class after D-023 (flag staleness, Makefile
staleness). The pattern is worth stating plainly: **make cannot see anything the compiler
knows**, so every implicit dependency has to be written down or it becomes a silent
wrong-answer bug rather than a build failure.

---

**D-029 — Coolants loaded; per-cell PDR heating computed.** *Accepted*

`readcoolants` is now called from `initPDRnetwork` — **before** `read_species`, matching
upstream 3DPDR.F90, because `read_species.F90:175` indexes `coolant(1:coo)`. Four coolants
(CO, C+, C, O) load. `CALC_HEATING` then runs per cell in `pdrStep`, returning all 12 terms;
the total and the grain photoelectric part are stored separately, because photoelectric is
the term MOCASSIN also computes and D-007's blend band has to ramp between them rather than
add them. Both persist in `pdrGrid.out`.

### Three bugs, all ordering or completeness of an exchange

**1. `coolfile` was `character(len=50)`.** Upstream prefixes a short relative `chemfiles/`;
MOCASSIN passes an absolute path under `PREFIX`, which truncated mid-directory. The runtime
error named a path (`.../da`) that appears in no input file. Widened to 200 and recorded in
`UPSTREAM.md`; `initPDRnetwork` now also refuses a path that would truncate, rather than
letting the truncation happen.

**2. `mocassinToPDR` ran before `Jste` was scaled to physical units.** It was placed
immediately after the `Jste` MPI reduction — but the `1.e-9` unit conversion (and the
`lgSymmetricXYZ` division by 8) happens in the loop *after* that, at
`iteration_mod.f90:742`. chi was therefore overstated by exactly 1e9.

*How it was caught:* `writeFUVField`, the Phase 0 diagnostic, recomputes chi from `Jste` at
write time by the same formula, and disagreed by that factor. **The Phase 0 diagnostic paid
for itself here** — a stored value and an independently recomputed one disagreeing is a much
sharper signal than either alone.

**3. `CALC_HEATING` was corrupting unrelated memory.** With heating enabled, `chiFUV` came
back as ~1e9 even after fix 2; with the call removed, chi was correct. Bounds checking found
nothing, because the vendored routines are external with no explicit interface — the compiler
cannot check those calls at all.

The cause was a **missing initialisation**: `CALC_HEATING`'s chemical-heating term calls
`CHEMICAL_HEATING_RATE`, whose reaction indices are built by `init_chemical_heating`.
3DPDR.F90 calls it immediately after `READ_RATES`; `initPDRnetwork` did not. The term ran on
unset state and wrote outside its arrays.

*The lesson, which is not "call the missing routine":* the symptom appeared in `chiFUV`, a
variable with no connection to heating, computed by a routine that was already verified
correct. Diagnosis only converged because the bisect was mechanical — disable the one new
call, re-run, observe. **When a verified-correct value goes wrong after an unrelated change,
suspect memory, not physics.**

**4 (not a bug so much as an omission).** With heating working, only ~26% of cells had a
non-zero value on 4 ranks. `pdrAbun` was being reduced across ranks but `pdrHeat`,
`pdrHeatPE` and `pdrZone` were not, so only rank 0's cells reached the output. `1/numtasks`
coverage looks like a physics problem and is not. The heating arrays now use the same
owner-contributes SUM as `pdrAbun`; `pdrZone` uses MAX, since it is identical on every rank
except where `pdrStep` raised it to 2.

### Verification

Same model as D-027 (n_H = 2000, `MdMg 0.01`, MRN silicate+carbonaceous, 4 ranks):

```
  A_V      chi      heat_tot     heat_PE   PE/tot
0.184   1.02e+02   3.2564e-21   4.817e-21   1.479
0.446   1.27e+01   1.6798e-21   3.189e-21   1.898
0.688   3.14e+00   4.8948e-22   9.582e-22   1.957
1.142   5.25e-01   9.9420e-23   1.946e-22   1.957
```

All 4076 PDR cells carry a heating rate. `chi` is back in range (0.53-102.5) and matches
`writeFUVField`. The budget is coherent: total heating falls monotonically as chi drops with
depth, grain photoelectric dominates, and the net sits at about half the photoelectric term -
the balance being gas-grain and PAH cooling, which are negative when T_gas > T_dust. The
ratio is stable at ~1.95 through the bulk and falls to 1.48 at the surface, where
photoelectric heating is strongest relative to the coolers.

### Open items

- [ ] Install `cmake` system-wide (carried from D-015).
- [ ] Generate and commit the fresh 3D-PDR baseline (D-016).
- [ ] Phase 4b remainder: line cooling (needs level populations) and the thermal-balance
      handover with the D-007 blend band. The heating half is now in place.
- [ ] Phase 4c / D-002: HEALPix-traced shielding columns for 3D geometry.
- [ ] The 1D benchmark gate carried from Phase 3.
- [ ] `Ndust constant` normalisation is not linear in the dust column; `MdMg` is the
      supported control for PDR work. Worth documenting or fixing.

---

## 2026-08-28l — Line cooling, and the measurement that proves the handover is needed

**Participants:** Hektor Monteiro, Claude (Opus 5)

---

**D-030 — Non-LTE line cooling via a slab-equivalent escape probability.** *Accepted*

`pdrStep` now solves the level populations for each coolant and returns a cooling rate,
following the same call sequence as upstream `coolingfunctions`:

```
FIND_CCOEFF -> detailed-balance rebuild -> escape_probability -> solvlevpop
```

*The ray structure is collapsed to one ray with one evaluation point*, whose path length is
the slab depth implied by the local extinction. `escape_probability`'s `RAYTHEIA_MO` branch
accumulates optical depth as `sum_i frac1*frac2*frac3*length(j,i)*PC`, so a single entry with
`length = (A_V/AV_fac)/n_H/PC` reproduces the slab result exactly. Same approximation as the
shielding columns (D-027), exact in 1D, an approximation in 3D.

Level populations are stored per cell in `pdrLevPop(0:nCells, 1:pdrNlevTot)`, packed end to
end with per-coolant offsets in `pdrLevOff`. 4 coolants, **56 levels total**. First visit to a
cell starts from LTE, as 3D-PDR does; thereafter the populations are rescaled to the abundance
the chemistry just produced and advanced by **one pass per MC iteration** — the outer loop
carries level-population convergence exactly as it carries the chemistry (D-008).

Cooling, and the level populations, join the owner-contributes reduction with the other
per-cell fields.

*Not checkpointed.* `pdrLevPop` is left out of `pdrGrid.out` for now; a warm restart
re-initialises from LTE and re-converges over a few iterations. Deliberate, to avoid churning
the checkpoint format again; worth revisiting if restarts prove expensive.

### The result: cooling works, and it proves the loop is still open

All 4076 PDR cells return a cooling rate. But heating and cooling are nowhere near balance,
and cooling scatters by orders of magnitude between neighbouring cells:

| A_V | T_e (K) | chi | heating | cooling |
|---|---|---|---|---|
| 0.185 | 295.8 | 1.02e+02 | 3.54e-21 | 3.32e-19 |
| 0.446 | 35.5 | 1.27e+01 | 1.68e-21 | 1.83e-21 |
| 0.582 | **2641.7** | 5.60e+00 | 6.04e-22 | **2.01e-18** |
| 1.136 | **1238.0** | 5.35e-01 | 6.14e-23 | 1.69e-23 |

**The scatter is the temperature's, not the cooling's.** Correlating against `grid1.out` shows
the cooling tracking T_e exactly: 2642 K gives 2.0e-18, 35 K gives 1.8e-21. The line cooling
is behaving correctly for the temperature it is handed.

The temperature is the problem. Across cells flagged as PDR zone, MOCASSIN's T_e spans
**30.5 to 3552 K, median 130.5** — in gas that a PDR calculation would put at 10-100 K. That
is not a defect in MOCASSIN: its thermal balance solves for photoionised gas, and in
low-ionisation cells the processes it knows about barely constrain the temperature. It is
simply the wrong solver for this regime.

*So this is the measurement that turns D-007 from an architectural assertion into a
demonstrated requirement.* The plan asserted from the start that thermal balance must be
handed to 3D-PDR in the neutral zone. It is now possible to say by how much it matters: until
the handover happens, the cooling rates are computed on a temperature that is wrong by one to
two orders of magnitude, and no amount of level-population convergence will fix that.

Both halves of the thermal balance now exist per cell. What remains is to stop using
MOCASSIN's T_e in the PDR zone and solve `heating = cooling` instead.

### Open items

- [ ] Install `cmake` system-wide (carried from D-015).
- [ ] Generate and commit the fresh 3D-PDR baseline (D-016).
- [x] **Close the thermal balance (D-007)** — done, see D-031.
- [ ] Phase 4c / D-002: HEALPix-traced shielding columns for 3D geometry.
- [ ] The 1D benchmark gate carried from Phase 3 - reachable once the handover lands.
- [ ] Consider checkpointing `pdrLevPop` if restart cost matters.
- [ ] `Ndust constant` normalisation; `MdMg` is the supported control.

---

## 2026-08-28m — Phase 4: thermal balance closed

**Participants:** Hektor Monteiro, Claude (Opus 5)

---

**D-031 — Thermal balance handed to 3D-PDR in the neutral zone.** *Accepted*
*Completes D-007.*

`pdrStep` now solves `heating(T) = cooling(T)` per cell and `pdrToMocassin` writes the result
into `grid%Te`. In the PDR zone MOCASSIN's T_e is **replaced outright** rather than blended:
its thermal balance is the wrong solver there (D-030 measured 30-3550 K in gas belonging at
10-100 K), so mixing it in would only dilute the right answer. Across the D-007 blend band the
two are interpolated linearly in log x(H+) so the temperature structure has no step. Because
this replaces rather than adds, there is no double counting - MOCASSIN's heating and cooling
for those cells is simply discarded.

### Result

| | before D-031 | after |
|---|---|---|
| T_gas median | 671 K | **52.9 K** |
| T_gas range | 5.4 - 3708 K | **8.9 - 465 K** |
| heating/cooling median | 11.8 | **1.030** |

The temperature structure is now physically sensible for a PDR, and the median cell sits at
thermal balance to 3%. Deeper cells in the sample come out at 1.00, 0.93, 0.78, 1.00.

### Three things this cost, each worth keeping

**1. D-008 does not extend to thermal balance.** The established rule - one pass per cell, let
the outer MC loop converge it - works for the chemistry and fails here. Cooling is
*exponential* in temperature: a single bisection step can move it two orders of magnitude, so
the level populations never catch up with a temperature that moves once per iteration.
Measured: after 8 MC iterations, mid-range cells reached heat/cool = 1.0 while the extremes
sat at 0.15 and 9.4. The temperature and the populations are now relaxed **together** in an
inner loop, `pdrThermIter` (default 12).

**2. An assumed bracket is worthless when the function is this stiff.** The first version
assumed a bracket of `[T/5, 5T]` and bisected. If F does not change sign across it, bisection
just walks to whichever bound it started nearest - which pinned cells at 5 K and 3700 K.
Replaced with march-then-bisect: double or halve until the sign flips, only then bisect
geometrically.

Related: the stored heating and cooling were one bisection step stale relative to the stored
temperature. Harmless for a linear quantity; here it made converged cells *look* like
factor-of-20 imbalances. There is now a final evaluation at the converged T.

**3. The diagnostic from D-027 was silently disabling the physics it protected.** `pdrStep`
returned early when the abundance vector came back unchanged, treating that as a CVODE
failure. But an unchanged vector is also the signature of chemistry that has **converged** -
so the moment a cell's chemistry settled, its thermal balance stopped being computed and its
temperature froze. The symptom was T_gas identical *to the last digit* across three different
thermal-balance algorithms, which is what finally gave it away. It now counts the occurrence
and continues.

*The general lesson:* a guard that returns early is a guard that can disable more than it
means to. This one was added in good faith to make a silent failure visible, and ended up
creating a much quieter one.

### The subtler problem: the handover perturbs its own trigger

With all three fixed, the temperatures were still a patchwork. Instrumenting a single cell
showed the inner loop converging cleanly - 25.4 K in, 50.8 K out, bracket [50.76, 50.83] -
but `pdrStep` being called for that cell **once in the whole run**.

The cause is circular: the handover writes the PDR temperature into `grid%Te`; T_e feeds
MOCASSIN's ionization balance; the ionization balance sets x(H+); and x(H+) is the criterion
deciding whether the cell gets PDR treatment at all. A cell could enter the zone, receive a
temperature, leave the zone next iteration, and never be revisited.

*Fix:* the zone flag **latches**. Once a cell has entered the PDR zone it stays there, so the
criterion cannot be perturbed by its own effect. That single change moved the median
heating/cooling from 11.8 to 1.03.

*Worth stating as a principle:* when a coupled quantity feeds back into the test that decides
whether the coupling applies, the test needs hysteresis or the system oscillates.

### Known limitation: MOCASSIN's convergence criterion does not know about the PDR

The test model converges - by MOCASSIN's own criterion, 97.8% of cells - after **3 MC
iterations**. That is far too few for the PDR to settle across the grid: cells that enter the
zone late get one visit. It is why 27% of cells sit within 20% of thermal balance rather than
most of them, and why the surface cells still show heat/cool ~ 12-19.

This is not a defect in the thermal balance, which converges cleanly per cell when visited. It
is that `minConvergence` counts MOCASSIN's own ionization/temperature convergence and is blind
to whether the PDR cells have settled. **Next step: fold PDR thermal convergence into the
iteration criterion**, so the run does not stop while PDR cells are still moving.

### Open items

- [ ] Install `cmake` system-wide (carried from D-015).
- [ ] Generate and commit the fresh 3D-PDR baseline (D-016).
- [x] **Fold PDR thermal convergence into `minConvergence`** — done, see D-032.
- [ ] Phase 4c / D-002: HEALPix-traced shielding columns for 3D geometry.
- [ ] The 1D benchmark gate carried from Phase 3 - reachable once the convergence criterion
      is fixed.
- [ ] Consider checkpointing `pdrLevPop`.
- [ ] `Ndust constant` normalisation; `MdMg` is the supported control.

---

## 2026-08-28n — PDR convergence folded into MOCASSIN's iteration test

**Participants:** Hektor Monteiro, Claude (Opus 5)

---

**D-032 — A PDR cell is not converged until its thermal balance is.** *Accepted*

`pdrStep` now clears `grid%lgConverged(cellP)` when a PDR cell's heating and cooling differ by
more than `pdrFcrit` (new keyword, default 0.10).

The implementation is a one-line hook rather than new machinery, because `lgConverged` already
uses the owner-contributes reduction and is exchanged *after* the `pdrStep` loop. Clearing it
there is enough; the counting logic that turns it into `totPercent` is untouched.

### Why it was needed

MOCASSIN's convergence test counts its own ionization and electron-temperature convergence and
knows nothing about the PDR. The test model reported **97.8% converged after 3 MC iterations**
and stopped — at which point cells that had only just entered the PDR zone had received a
single thermal step. The thermal balance of D-031 was converging correctly per cell and then
being cut off at the grid level.

### Result

| | D-031 | with D-032 |
|---|---|---|
| MC iterations used | 3 (early stop) | **8** (hit `maxIterateMC`) |
| heating/cooling median | 1.030 | **1.004** |
| cells within 10% of balance | - | **55.1%** |
| runtime | 88 s | 235 s |

The sampled profile is now in genuine thermal equilibrium through the bulk:

```
  A_V     chi      T_gas     heating      cooling   heat/cool
0.463   1.34e+01  1648.4   1.1542e-21   1.1530e-21    1.00
0.622   5.08e+00   567.4   6.2558e-22   6.1250e-22    1.02
0.722   3.03e+00   232.1   4.8349e-22   4.9591e-22    0.97
0.807   1.86e+00   106.1   3.3276e-22   3.2537e-22    1.02
```

Temperature falls monotonically with depth from 1648 K to 106 K as chi drops - the shape a PDR
should have - with heating and cooling matching to 1-3% at each point.

The run now stops on `maxIterateMC` rather than on convergence, which is the honest state: the
PDR is still improving when the iteration cap is hit. Raising `maxIterateMC` is the knob;
whether 55% within 10% is good enough is a science question for the benchmark, not an
engineering one.

### Note on a build-system false alarm

The first run after this change reported `unrecognised keyword pdr`, suggesting the toggle
mechanism of D-023 had failed again. It had not: an explicit
`PDR=1 -> PDR unset -> PDR=1` cycle rebuilds correctly each time, verified by probing the
binary for PDR symbols. The transient came from interleaving a `VERSION=pinned` verification
build with a normal one in the same sequence. **Probe the artefact, not the build log** - `make`
printing no errors is not evidence that it rebuilt what you think.

### Open items

- [ ] Install `cmake` system-wide (carried from D-015).
- [ ] Generate and commit the fresh 3D-PDR baseline (D-016).
- [ ] Phase 4c / D-002: HEALPix-traced shielding columns for 3D geometry. The slab-equivalent
      columns are exact for the benchmark's geometry, so this is not blocking the gate.
- [ ] **The 1D benchmark gate carried from Phase 3 is now reachable** - the chemistry, the
      radiation field, the heating, the cooling and the thermal balance are all in place and
      converging.
- [ ] Consider checkpointing `pdrLevPop`.
- [ ] `Ndust constant` normalisation; `MdMg` is the supported control.

---

## 2026-08-28o — Benchmark attempt: a geometry blocker, and the H2 hunt

**Participants:** Hektor Monteiro, Claude (Opus 5)
**Goal:** the Phase 3 benchmark gate - reproduce a 3D-PDR 1D model end to end.

### The gate is blocked by geometry, not by the coupling

3D-PDR's 1D benchmark is **plane-parallel**: FUV enters a slab from outside at constant flux.
MOCASSIN's source sits *inside* the grid, so chi falls by geometric dilution as well as
extinction. Approximating a slab needs a shell thin compared to its inner radius, resolved on
a uniform Cartesian grid:

```
 n_H     shell thickness for A_V=4   R_in for <15% dilution   cells across 2*R_out
1e+03    6.36e+18 cm (2.06 pc)       4.54e+19 cm                    326
1e+04    6.36e+17 cm (0.21 pc)       4.54e+18 cm                    326
1e+05    6.36e+16 cm (0.02 pc)       4.54e+17 cm                    326
```

The requirement is **scale-invariant at ~326 cells per axis** - it is a pure ratio, so raising
the density does not help. That is 3.5e7 cells, and `Jste` alone is `nbins*ncells*4` bytes:
**108 GB per rank** at `nbins=1000`, on a grid MOCASSIN replicates on every rank.

*So the standard 1D benchmark cannot be run at feasible cost with a uniform Cartesian grid
centred on the source.* Two ways forward, both outside current scope: a **spherical** PDR
benchmark instead (physically valid, just not the published comparison), or MOCASSIN's
**nested sub-grids** (`nGrids > 1`), which D-009 currently excludes because 3D-PDR's ray
tracer assumes one box - a constraint that does not bind while the shielding columns are
slab-equivalent (D-027).

### What the coupled code does produce

In the spherical geometry it *can* do (n_H = 1e4, A_V to 5.5), the carbon chemistry is
correct and fully stratified:

| A_V | chi | T_gas | x(C+) | x(C) | x(CO) |
|---|---|---|---|---|---|
| 0.07 | 6.6e+02 | 5485 | 1.40e-04 | 4.8e-10 | 1.1e-14 |
| 1.01 | 1.6e+01 | 698 | 1.35e-04 | 4.6e-06 | 1.6e-08 |
| 5.53 | 2.6e-06 | 4.4 | 1.2e-06 | 9.6e-05 | 4.2e-05 |

C+ -> C -> CO runs to completion: carbon is essentially all neutral C and CO at depth. But
**H stays atomic**, x(H2) ~ 8e-3 where a real PDR is fully molecular by A_V ~ 2.

### Running the H2 problem to ground

Three hypotheses, tested in order:

1. **Not integration depth.** Raising `pdrChemIter` from 3 to 15 - five times the chemistry
   calls - moved x(H2) from 8.6e-3 to 7.6e-3. It is a steady state, not an unconverged one.

2. **Not the chemistry code.** Feeding the *identical stated conditions* (n_H=1e4, T_gas=5 K,
   T_dust=12 K, chi=0, A_V=5) through `pdrSmokeTest` - the same vendored routines - gives
   **x(H2) = 0.4998, x(CO) = 1.40e-4**. Fully molecular. So the chemistry is fine and the
   coupled path was feeding it something different.

3. **It was the dust temperature.** Printing what `pdrStep` actually passes:

```
DBGIN cell 400  nH= 10000.0  Tg= 15.6  Td= 0.594
DBGIN chi= 0.0876  av= 2.123  NHcol= 3.38e21
```

`T_dust = 0.59 K`. H2 forms on grains, and the Cazaux & Tielens rate collapses as T_dust -> 0.

*A correction to my own earlier reading:* I had sampled `dustGrid.out` and reported "dust is
cold, median 12.4 K", concluding dust was not the problem. That probe filtered values to
`1 < v < 3000` and so **excluded exactly the sub-Kelvin cells that were the problem**. The
filter was chosen to skip non-temperature columns and silently removed the evidence. A probe
that discards outliers cannot be used to rule out an outlier.

---

**D-033 — Dust temperature is floored at T_cmb; D-009's dust ownership needs revisiting.**
*Accepted*

`pdrStep` now applies `T_dust = max(T_dust, T_cmb)`.

*Why MOCASSIN produces sub-Kelvin dust:* `getDustT` solves absorption = emission against the
**local radiation field only**. In a deeply shielded cell there is almost nothing heating the
grains, so the equilibrium tends to zero. That is entirely reasonable for an H II region,
where such cells carry no weight, and it is unphysical for a PDR: real grains cannot fall
below the CMB. 3D-PDR never meets this because its dust is isothermal or HTT91.

*Effect:* x(H2) rose from 8e-3 to **4.5e-2** in shielded cells - a five-fold improvement, and
still an order of magnitude short of 0.5.

*So the floor is necessary but not sufficient, and the real conclusion is larger.* **F-5 and
D-009 assigned dust temperature to MOCASSIN on the grounds that it computes it
self-consistently.** That reasoning is sound where the grains see radiation and fails where
they do not. The options, in increasing order of effort:

- floor at a physically motivated value rather than the CMB (crude, but honest and cheap);
- fall back to 3D-PDR's HTT91 dust model below some threshold, which parametrises T_dust from
  the FUV field and A_V and is designed for exactly this regime;
- add CMB and interstellar-radiation-field heating to MOCASSIN's dust equilibrium, which is a
  change to MOCASSIN proper and would benefit it independently of the PDR work.

The second looks right: it is what 3D-PDR does, it needs no change to MOCASSIN, and `dust_t.F90`
is already vendored (though not currently compiled, per D-009).

### Open items

- [ ] **Resolve the dust temperature in shielded cells (D-033).** This is now the top blocker
      on the molecular chemistry.
- [ ] Decide the benchmark strategy: spherical comparison, or enable nested sub-grids.
- [ ] Install `cmake` system-wide (carried from D-015).
- [ ] Generate and commit the fresh 3D-PDR baseline (D-016).
- [ ] Consider checkpointing `pdrLevPop`.
- [ ] `Ndust constant` normalisation; `MdMg` is the supported control.

---

## 2026-08-29 — Two corrections from Hektor: plane-parallel mode, and cosmic rays

**Participants:** Hektor Monteiro, Claude (Opus 5)
**Context:** Hektor pointed out that MOCASSIN has a plane-parallel mode, and asked whether the
heating and cooling sources - cosmic rays in particular - are properly incorporated. Both
questions landed on real gaps.

---

**D-034 — The benchmark uses MOCASSIN's plane-parallel mode. The geometry blocker of
2026-08-28o is withdrawn.** *Accepted*

**The previous entry was wrong.** It concluded the 1D benchmark was infeasible because a
uniform Cartesian grid centred on a point source cannot resolve a thin shell - ~326 cells per
axis, 108 GB per rank. That analysis is correct *for a point source at the centre*, and I
never checked whether MOCASSIN offers anything else. It does.

`planeIonization` (`set_input_mod.f90`, `lgPlaneIonization`) launches stellar packets from a
**face**: position randomised across x and z, `position%y = 0`, beaming along +y
(`photon_mod.f90:583-640`). That is exactly slab illumination.

*Consequence:* the structure is one-dimensional in y, so the grid can be thin in x and z.
`nx = nz = 5`, `ny = 200` is **5000 cells** - `Jste` becomes ~20 MB rather than 108 GB. The
benchmark goes from infeasible to cheap.

*The lesson is about how the wrong conclusion was reached.* The arithmetic was right and the
premise was never checked. "Can MOCASSIN do plane-parallel?" is one grep, and it was skipped
because the spherical geometry was the one already in front of me. **Quantifying a constraint
is not the same as establishing it exists.**

---

**D-035 — MOCASSIN has no cosmic-ray physics, and the two codes' ionization states are
unreconciled.** *Accepted*

*Finding, verified by grep:* MOCASSIN contains **no cosmic-ray physics whatsoever** - no CR
heating, no CR ionization, nothing in `update_mod` (0 matches for `cosmic|zeta`). This is
entirely correct for a photoionization code: in an H II region CR heating is negligible
beside photoionization heating. It simply means **MOCASSIN cannot set either the temperature
or the ionization state of shielded gas**, which is precisely the regime the coupling adds.

**What the coupling does supply.** In PDR cells 3D-PDR provides both:

- *Heating*, `heatingfunctions.F90:207` (active; the 20 eV variant above it is commented out):
  ```
  COSMICRAY_HEATING = (9.4*EV)*(1.3D-17*ZETALOCAL)*DENSITY*ABUNDANCE(NH2)
  ```
- *Ionization*, through `ZETALOCAL` in `CALCULATE_REACTION_RATES`, which drives the CRP and
  CRPHOT reactions that sustain the ion-molecule chemistry deep in the cloud.

So the answer to the question as asked is **yes in PDR cells, no everywhere else, and no in
MOCASSIN itself.**

**But there is a sting, and it feeds straight back into D-033.** CR heating is proportional to
`ABUNDANCE(NH2)`. With x(H2) stuck at 8e-3 instead of 0.5:

```
n_H = 1e4, x(H2) = 0.5    ->  7.53e-24 erg/s/cm3
n_H = 1e4, x(H2) = 8e-3   ->  1.21e-25 erg/s/cm3     62x suppressed
```

So the cold-dust bug is not merely holding the gas atomic - it is **suppressing the dominant
heating term of shielded gas by a factor of 62**, which cools those cells further. D-033 and
D-035 are the same failure seen twice:

```
T_dust -> 0  ->  H2 formation on grains collapses  ->  x(H2) ~ 1e-2
             ->  CR heating (proportional to x(H2)) collapses  ->  cells colder still
```

That raises D-033 from "molecular chemistry is wrong" to "the thermal balance of shielded gas
is wrong for the same reason", and makes fixing the dust temperature clearly the top priority.

**A second, independent gap.** MOCASSIN's `ionBalance` has no CR ionization, so in a shielded
cell it drives x(H+) toward zero, whereas the true value is CR-maintained at ~1e-4. Meanwhile
3D-PDR's network computes its own H+, He+, C+ and electron abundances. **Nothing reconciles
the two**: `pdrToMocassin` writes back only the temperature (`pdr_mod.f90` touches `ionDen`
solely to *read* x(H+) for the zone test). So in PDR cells `grid%ionDen` and `grid%pdrAbun`
hold two different, independently-computed ionization states, and the zone criterion is based
on the one that lacks the relevant physics.

This has not caused visible harm yet because the zone flag latches (D-031), but it should be
resolved: either write the network's ionization back into `ionDen` for PDR cells, or change
the zone criterion to something MOCASSIN can determine correctly.

### Open items

- [x] **Fix the dust temperature in shielded cells (D-033)** - done, see D-036.
- [ ] **Run the 1D benchmark using `planeIonization`** (D-034), with `nx = nz = 5`, `ny ~ 200`.
- [x] Reconcile the ionization state between `ionDen` and `pdrAbun` in PDR cells - done, see D-037.
- [ ] Install `cmake` system-wide (carried from D-015).
- [ ] Generate and commit the fresh 3D-PDR baseline (D-016).
- [ ] Consider checkpointing `pdrLevPop`.

---

## 2026-08-29b — Dust temperature fixed; ionization fed back

**Participants:** Hektor Monteiro, Claude (Opus 5)

---

**D-036 — Dust temperature falls back to HTT91 where MOCASSIN's is unphysically low.**
*Accepted. Resolves D-033.*

`pdrStep` now computes the Hollenbach, Takahashi & Tielens (1991) dust temperature inline
from the local chi and A_V - the same formula as the vendored `dust_t.F90`, evaluated with the
single effective ray of D-001 - and takes `max(T_MOCASSIN, T_HTT91)`.

*Why max().* Both are estimates of the same quantity, and MOCASSIN's failure mode is
specifically to **under**-estimate: `getDustT` omits heat sources (CMB, ISRF, the IR bath from
warmer dust that is under-sampled deep in), it does not invent them. So taking the larger keeps
MOCASSIN's full radiative transfer wherever the grains see light and falls back to the PDR
parametrisation where they do not. Selectable via `pdrDustModel` (0 = MOCASSIN only,
1 = max, default, 2 = HTT91 only) so the sensitivity can be tested.

*Upstream had already found this.* `dust_t.F90` ends with a floor at 10 K, commented
"since values below 10 K can dramatically limit the rate of H2 formation on grains (the
molecule cannot desorb from the surface)" - independently the same failure diagnosed here.

### Result

| dust treatment | x(H2) in shielded gas |
|---|---|
| MOCASSIN raw (T_dust -> 0.59 K) | 8e-3 |
| floored at T_cmb = 2.725 K | 4.5e-2 |
| **HTT91, floor 10 K** | **4.999e-1** |

Standalone 3D-PDR at matched conditions gives **5.0e-1**, and x(CO) comes out at 1.399e-4
against standalone's 1.4e-4. The coupled code now reproduces the standalone chemistry in
shielded gas **to the printed precision**.

That also lifts the cosmic-ray heating suppression of D-035: with x(H2) back at 0.5 rather
than 8e-3, `COSMICRAY_HEATING` - which is proportional to `ABUNDANCE(NH2)` - recovers its
factor of 62.

*Note on the earlier CMB-floor attempt.* Flooring at 2.725 K moved x(H2) only from 8e-3 to
4.5e-2, and it would have been easy to read that five-fold improvement as progress in the right
direction and keep tuning the floor. It was the wrong knob: the right value is not a floor at
all but a physical model of what heats the grains, and HTT91 supplies it. **A partial
improvement from a plausible fix is not evidence the fix is correct.**

---

**D-037 — The ionization state is fed back to MOCASSIN for H and He.** *Accepted.
Completes D-035.*

`pdrToMocassin` now writes the network's H and He ionization into `grid%ionDen`, blended
across the D-007 band exactly as the temperature is. The loop is closed: the ionization that
sets the zone flag, the electron density and the proton density is now the one computed with
cosmic-ray ionization in it, which MOCASSIN does not have (D-035).

*Metals are deliberately not written back.* MOCASSIN's `ionDen` has two stages per element and
no notion of molecules, so carbon locked in CO would have to be booked as either C0 or C+ and
either choice misrepresents it - it would show up as spurious C I or C II emission. D-007
already assigns [C II] and [O I] in PDR cells to 3D-PDR, which accounts for that carbon
correctly. Recorded so the omission is visibly a decision rather than an oversight.

*Safe against oscillation* because the zone flag latches (D-031): feeding x(H+) back cannot
flip the criterion that decides whether the feedback happens.

### Verification

n_H = 1e4, MdMg = 0.01, MRN silicate+carbonaceous, 13^3, A_V to 4.51, 925 PDR cells:

```
  A_V     chi     T_gas    x(H)     x(H2)    x(C+)    x(C)     x(CO)    x(H+)
2.400  4.41e-02   32.2   3.03e-04 5.00e-01 4.72e-08 4.48e-07 1.39e-04 4.21e-09
4.510  5.75e-05   13.1   4.44e-04 5.00e-01 9.56e-09 6.87e-08 1.40e-04 2.70e-09
```

Fully molecular, carbon fully in CO, and a small CR-maintained x(H+) that MOCASSIN alone would
have driven to zero. PDR-off build verified unchanged.

### Open items

- [ ] Run the 1D benchmark using `planeIonization` (D-034), `nx = nz = 5`, `ny ~ 200`.
- [ ] Install `cmake` system-wide (carried from D-015).
- [ ] Generate and commit the fresh 3D-PDR baseline (D-016).
- [ ] Deep cells settle at T_gas ~ 3-6 K where a real cloud interior sits nearer 10 K. Worth
      checking whether `pdrTmin` should default above the CMB, and whether gas-grain coupling
      to the now-warmer dust is being applied.
- [ ] Consider checkpointing `pdrLevPop`.

---

## 2026-08-29c — Metals fed back after a wrong premise; abundances synced; the OOM explained

**Participants:** Hektor Monteiro, Claude (Opus 5)

---

**D-038 — Metals ARE fed back. D-037's rationale for excluding them was wrong.** *Accepted*

D-037 excluded metals on the grounds that "MOCASSIN's `ionDen` has two stages per element and
no notion of molecules, so carbon locked in CO would have to be booked as either C0 or C+".
Hektor pushed back, and **both halves of that were wrong**:

1. **MOCASSIN tracks `min(elem+1, nStages)` stages per element** - seven for carbon at the
   default `nstages=7`, not two. Confirmed directly from `grid2.out`, whose line-length
   histogram is `{2: H, 3: He, 7: five metals}`.

2. **Nothing requires the stages to sum to one.** Every consumer uses `ionDen`
   *multiplicatively*:
   ```
   Np                           = ionDen(...,1,2)*elemAbun(1)
   emissionHeI                  = ...*elemAbun(2)*ionDen(...,2)*Ne
   forbiddenLines(elem,ion,:,:) = ...*elemAbun(elem)*ionDen(...,elem,ion)
   ```
   and nothing infers a stage by closure. Summing to unity is an **output** property of
   `ionBalance`'s construction (`ionDen(1)=1/denominator`, `ionDen(ion)=ionProd/denominator`),
   not an input requirement.

That inverts the conclusion. The molecular fraction is not awkward - it is simply **absent**
from the atomic stages, which is exactly right: carbon in CO emits no atomic line and donates
no free electron. `setIonPair` now writes C, O and Mg, with stages above the first ion set to
MOCASSIN's own 1e-20 floor.

Verified in a deep cell: network has C+ 8.9e-9, C 7.0e-8, CO 1.4e-4; MOCASSIN now holds
`ionDen(C) = [3.18e-4, 4.06e-5, 1e-20 x5]`, summing to **3.6e-4**. Only 0.036% of carbon
appears as atomic - the rest is correctly missing. Previously `ionBalance` had those summing to
1, i.e. treating essentially all carbon as atomic, over-predicting C I and C II by ~2800x.

*Worth noting how the error survived.* It was stated confidently in a commit message and a
design doc, and re-read several times, because it sounded like a structural fact about
MOCASSIN. It was never checked - one look at `nstages` would have settled it. **An assumption
about someone else's data structure is a thing to verify, not to reason from.**

---

**D-039 — The network's elemental abundances are synced to MOCASSIN's.** *Accepted*

Investigating D-038 surfaced a second inconsistency: the two codes were modelling **different
amounts of carbon**. The network's initial abundances come from `species_*.d`, MOCASSIN's from
its abundance file, and nothing connected them:

| element | network | MOCASSIN | |
|---|---|---|---|
| H | 0.4 + 2x0.3 = 1.0 | 1.0 | agree |
| He | 1.0e-1 | 0.1 | agree |
| C | 1.40e-4 | 2.2e-4 | **57% apart** |
| O | 3.00e-4 | 3.3e-4 | **10% apart** |
| Mg | 2.7e-6 | 0 (element off) | network only |

So the chemistry, cooling and line emission were running on 1.4e-4 carbon while MOCASSIN's
opacity and emission used 2.2e-4.

At initialisation each element sits in exactly one carrier species, so reconciling them is a
single assignment per element. `seedPDR` now does this **per cell**, using that cell's
abundance-file index so `multiChemistry` models get the right budget in each region, and
reports the comparison at startup. Controlled by `pdrSyncAbun` (default on).

Where MOCASSIN has an element switched off - Mg here - the network's value is **kept rather
than zeroed**. Deleting Mg+ would silently change the electron budget of the shielded gas,
which is not a change to make as a side effect of an abundance sync.

---

**D-040 — There is no memory leak. The OOM was rank count times grid replication, under
systemd-oomd.** *Accepted*

Runs had been dying with exit 137, and the reported symptom was RAM climbing linearly without
bound - which is the signature of a leak. It is not one.

*Audited, all balanced:* `escape_probability` (3 allocate / 3 deallocate, `#ifdef SOBOLEV`
guards matched on both sides), `calculate_abundances.c` (every CVODE object freed - context,
vector, solver memory, matrix, linear solver, and all three `malloc`s), `chemical_heating`
(its single allocate is in `init_chemical_heating`, called once), and the PDR block of
`iteration_mod` (12 allocates, 12 deallocates).

*Measured:* the same model at 13^3 with `nbins=1000` on 2 ranks, run with `pdr 0` and then
`pdr 1`, holds **RSS flat at ~250 MB per rank** and exits cleanly in both cases. No growth,
with or without the PDR module.

*So the cause is the footprint, not a leak.* MOCASSIN replicates the full grid on **every**
rank, so memory scales linearly with `-np`. The arrays that dominate are all
`nCells x nbins`, and `escapedPackets` carries a further `nAngleBins` factor - which is why
`iterateMC` reduces it in chunks. Asking for 14 ranks multiplies the whole footprint by 14.

*And the kill was made by `systemd-oomd`, not the kernel's classic OOM path*, in a cgroup
recorded as `app-gitkraken-9385.scope` - i.e. the shell inherited GitKraken's systemd scope.
systemd-oomd kills on memory **pressure** within a cgroup, so it can fire well before physical
RAM is exhausted and while `free` still shows tens of gigabytes available. That is why the
crash looked like a runaway leak on a 61 GB machine.

*Practical guidance:* run models from a plain terminal rather than one launched by a desktop
app, and treat `-np` as a memory multiplier - for large grids or large `nbins`, fewer ranks may
be the only way to fit, and D-013's `nbins >= 1000` recommendation has a memory price.

*A process note.* Three diagnostic attempts were wasted before this landed: one sampled a model
whose dust setup dominated and never reached `pdrStep`; two ran the binary without `mpirun` and
with block-buffered output, so the log greps returned zero and the sampled RSS was not a
running solver. **Each produced confident-looking numbers that meant nothing.** The fix was to
check the harness itself - is the process actually running, is the output actually flushed -
before reading anything into its output.

### Open items

- [ ] Run the 1D benchmark using `planeIonization` (D-034), `nx = nz = 5`, `ny ~ 200`.
- [ ] Install `cmake` system-wide (carried from D-015).
- [ ] Generate and commit the fresh 3D-PDR baseline (D-016).
- [ ] Deep cells settle at T_gas ~ 3-6 K where a real cloud interior sits nearer 10 K.
- [ ] Consider checkpointing `pdrLevPop`.

---

## 2026-08-29d — Plane-parallel slab runs; a NaN fixed; A_V found wanting

**Participants:** Hektor Monteiro, Claude (Opus 5)

### Setting up the slab

`planeIonization <flux> <nu0>` works as needed. With `nu0 = 0` the rescaling is skipped and
the value is taken directly as the incident **bolometric** flux, and
`Lstar = flux x xAxis(nx) x zAxis(nz)`. For chi = 10 Draine at the face with a 25 kK
blackbody (f_FUV = 0.535):

```
F_FUV = chi*u_D*c = 2.680e-2 erg/s/cm2   ->   F_bol = 5.010e-2
```

Two setup facts that cost a run each and are worth recording:

- **`ny` must be odd** - "the automatic grid option requires odd integer ny if not symmetric".
- **`Rout 0` disables the radial clipping**, which otherwise trims a slab's corners since the
  termination test is `sqrt(x^2+y^2+z^2) >= R_out .and. R_out > 0`.

`edges Lx Ly Lz` sets each axis extent independently, so `nx = nz = 5, ny = 201` gives a
5 x 201 x 5 slab - 5025 cells, trivial memory. The beam is normal: `direction = (0,1,0)`
from the `y = 0` face, matching 3D-PDR's 1D geometry where all the flux sits on one ray.

---

**D-041 — A non-finite level-population solve is rejected, not propagated.** *Accepted*

The full-resolution slab died with **19.9 million NaN lines**. The messages all read
`getGrainRecombination: insane eta` - MOCASSIN's own grain code, nowhere near the PDR module.

*Bisected in two runs, each halving the space:*

| run | result |
|---|---|
| `pdr 0`, full resolution | **clean**, 2m25 - so it is not baseline MOCASSIN |
| `pdr 1`, cooling off (`pdrCoolants 0`) | **clean** - so it is not the chemistry or heating |
| `pdr 1`, cooling on | 19.9M NaN - **the level-population solve** |

The chain: in a cell whose coolant has been chemically destroyed, the transition matrix goes
singular; `solvlevpop`'s Gauss-Jordan hits a zero pivot, sets `call_writes` and dumps the
matrix (those 19.9M lines), and returns **NaN rather than failing**; the NaN rides the cooling
into `coolTot`, through the thermal balance into `T_gas`, and out through `pdrToMocassin` into
`grid%Te` - where it finally surfaces in a routine that names neither the cause nor the
culprit.

*Three guards, in order of preference:*

1. **Skip the coolant** when its carrier is below `pdrNspecFloor` (1e-25 relative). This is the
   real fix - the populations are meaningless there and solving is what creates the singularity.
2. **Validate the solution** before use: NaN, negative, or zero-sum populations mean the solve
   failed, so keep the previous populations and leave the coolant out of this pass. Counted and
   reported.
3. **Never let a non-finite budget move the temperature** - the thermal loop exits instead.

In the fixed run guard 1 caught everything: the slab completes in 2m55 with **no NaN** and no
rejections reported.

*Worth noting where the diagnosis nearly went wrong.* The visible symptom named MOCASSIN's
grain recombination, which is not remotely near this code. Reading the symptom rather than
bisecting would have sent the search into the wrong module entirely. **A NaN's point of
discovery says nothing about its point of origin** - only its path.

---

**D-042 — A_V inverted from the MC field degenerates where the field underflows.** *OPEN*

The slab now produces real PDR structure: A_V to 11.7, x(H2) = 0.499, CO forming. But the
transition depths could not be measured, because **many deep cells report `A_V = 0.000` with
`chi = 0`**.

The cause is in the definition (D-001/D-026): A_V,eff is obtained by *inverting the measured
attenuation*, `A_V = 1.0857*ln(chi0/chi)/R_FUV`. That is exact while chi is measurable, and it
carries no depth information at all once chi underflows to zero - which is exactly what
happens deep in a well-resolved slab, where no packet ever arrives. Those cells fall to the
`else` branch and get A_V = 0, so sorting by A_V scrambles the profile and the H/H2 and C+/C
fronts cannot be located.

The chemistry in those cells is still right - they are fully shielded and fully molecular,
which is the correct answer for large A_V - but the *coordinate* is wrong, and the benchmark
needs the coordinate.

*The fix is the ray-traced column of D-002*, or for plane-parallel geometry the much simpler
accumulation of dust optical depth along the beam. Either gives an A_V that grows monotonically
with depth regardless of how few photons arrive. This is now the blocker on the benchmark.

### Open items

- [ ] **Compute A_V from the dust column rather than by inverting the MC field (D-042).**
      Blocks the benchmark.
- [ ] Install `cmake` system-wide (carried from D-015).
- [ ] Generate and commit the fresh 3D-PDR baseline (D-016).
- [ ] Deep cells settle at T_gas ~ 5 K where a real cloud interior sits nearer 10 K.
- [ ] Consider checkpointing `pdrLevPop`.

---

## 2026-08-29e — A_V from the dust column; the slab's illumination is still wrong

**Participants:** Hektor Monteiro, Claude (Opus 5)

---

**D-043 — Under plane-parallel illumination, A_V comes from the dust column.** *Accepted.
Resolves D-042.*

`computeAVdust` integrates `kappa_ext(V) = absOpac + scaOpac` along +y from the illuminated
face, evaluating A_V at each cell centre. Both arrays are `Ndust*sigma` and therefore already
per unit length, so the accumulation is direct; `A_V = 1.0857*tau_V`.

The MC inversion of D-026 is skipped when `lgPlaneIonization` and retained otherwise. General
3D geometry still needs the ray trace of D-002.

*Result:* A_V is now monotonic with depth and **no cell reports A_V = 0** (previously most
deep cells did), spanning 0.008 to 3.35 across the slab. The transition fronts became
locatable for the first time.

*Why the old definition had to go, restated because it is a general trap:* A_V,eff was derived
by inverting a **measurement**. That is exact while the measurement has signal and carries no
information at all once it saturates - here, once chi underflows to zero because no packet
reaches that depth. The failure is silent: the cells were physically correct (fully shielded,
fully molecular) and merely mislabelled, so nothing looked wrong until the coordinate was used
as an abscissa. **A quantity derived by inverting a measurement inherits that measurement's
dynamic range.**

---

**D-044 — The slab's illumination normalisation is not understood. Benchmark still open.**
*OPEN*

With A_V fixed, the fronts could be compared for the first time, and they do not agree:

| front | MOCASSIN+PDR slab | standalone 3D-PDR |
|---|---|---|
| H/H2 | 0.025 | 0.069 |
| C+/C | 0.042 | 1.677 |

The cause is not the chemistry - it is that **the FUV field decays far faster than dust
extinction allows**. At the face chi = 51.9 (target: 10), and by A_V = 0.33 chi is exactly
zero, where extinction alone predicts `51.9*exp(-3.02*0.33) = 19`.

*First diagnosis, correct but insufficient:* the slab was 4.4:1 **deeper than wide**
(`edges 2.0e18 8.8e18 2.0e18`), the opposite of what a plane-parallel approximation needs.
MOCASSIN has no periodic boundaries, so a scattered photon exits the side after ~L_x rather
than continuing to depth.

*The correction made it worse.* Widening to `edges 4.0e19 8.8e18 4.0e19` dropped chi at the
face to 1.77e-3 and brought the NaNs back. So the transverse aspect ratio is not the whole
story, and something in how the incident flux is normalised against the face is wrong.

The suspect is `setMotherGrid`:

```fortran
Lstar(1) = (meanField/1.e36)*grid%xAxis(grid%nx)*grid%zAxis(grid%nz)
```

which uses the axis **maxima**. If the axes run -L..+L the illuminated face is 2L x 2L while
this computes L x L - a factor of four - and packets are launched across the full face
(`position%x` spans the whole axis range). That would explain a normalisation error but not a
factor of 5600, so it is at most part of it.

**Stopping here rather than guessing further.** The next step is to establish, from the code
rather than by inference, what `planeIonization` actually normalises against - whether the axes
are symmetric in this mode, what area the packets are spread over, and how `meanField` relates
to the flux entering the face. That is a bounded reading task, and it should precede any
further parameter tuning.

*What is not in doubt:* the coupling physics is verified independently of this. Chemistry,
radiation field, heating, cooling, thermal balance, dust temperature and the ionization
feedback all reproduce standalone 3D-PDR at matched conditions. What remains is a geometry and
normalisation problem in one illumination mode.

### Open items

- [ ] **Establish what `planeIonization` normalises the flux against (D-044).** Blocks the
      benchmark. Read `setMotherGrid` and the packet launcher together; do not tune parameters
      until the normalisation is understood.
- [ ] Install `cmake` system-wide (carried from D-015).
- [ ] Generate and commit the fresh 3D-PDR baseline (D-016).
- [ ] Deep cells settle at T_gas ~ 5 K where a real cloud interior sits nearer 10 K.
- [ ] Consider checkpointing `pdrLevPop`.

---

<!-- Append new entries below this line. -->

## 2026-08-31 - what `planeIonization` actually does (closes D-044)

D-044 asked, as a bounded reading task, what `planeIonization` normalises against. Answer, from
the code rather than by inference. Three separate things were wrong, and only one of them was
the factor I had been chasing.

### D-045: the illuminated face is the mid-plane, not the grid edge

`readInput` force-disables `lgSymmetricXYZ` for this mode (`set_input_mod.f90`, the
`lgPlaneIonization .and. lgSymmetricXYZ` advisory), and `lgSymmetricXYZ` defaults to `.false.`
anyway. So `setMotherGrid` takes the non-symmetric branch (`grid_mod.f90:580-596`):

```fortran
grid(1)%xAxis(i) = 2.*real(i-1)/real(grid(1)%nx-1) - 1.
grid(1)%xAxis(i) = grid(1)%xAxis(i) * Rnx
```

The axes run **-Rn .. +Rn**, so `edges` sets the *half*-width. Packets launch at
`position%y = 0.` travelling `+y` (`photon_mod.f90`), and **y = 0 is the centre of the grid**.
Only the `y > 0` half is ever illuminated; the `y < 0` half sits in permanent shadow.

`computeAVdust` integrated the dust column from `j = 1`, i.e. from `y = -Rny`. It therefore
accumulated the entire shadowed half before reaching the plane where the light actually enters.
**That is the A_V/chi inconsistency** - chi was measured from the true face while A_V was
measured from a point half a slab away, so no extinction law could reconcile them. This is what
made the field look as though it "decayed far faster than extinction allows".

Fixed: `computeAVdust` now locates the first `j` with `yAxis(j) >= 0` and starts the column
there, zeroing `AVeff` in the shadowed half.

### D-046: six advisories shadow the rest of the validation chain

D-025 fixed *one* non-fatal clause sitting inside `readInput`'s `else if` chain. It was not an
isolated slip - there are six, and the earliest of them shadows **27** subsequent fatal checks:

| line | condition | effect |
|---|---|---|
| 821 | `resLinesTransfer >= 100.5 .and. lgDust .and. lgGas` | shadows 27 checks |
| 824 | `resLinesTransfer <= 100 .and. (.not.lgDust .or. .not.lgGas)` | shadows 26 |
| 838 | `lgDebug .and. .not.lgGas` | shadows 22 |
| 850 | `lgDfile .and. (Rnx>=0 .or. ...)` | shadows 19 |
| 858 | `lgPlaneIonization .and. lgSymmetricXYZ` | shadows 18 |
| 874 | `LPhot /= 0. .and. allocated(LStar)` | shadows 13 |

Any dust+gas model without the `resonanceLinesTransfer` keyword trips line 821 - which is a
*warning* - and thereby skips every validation below it. The slab model is exactly such a model,
which is why two checks that should have caught its configuration never fired:

- `lgPlaneIonization .and. .not.lgDfile` - plane ionization **requires** a density file
- `lgPlaneIonization .and. lgSymmetricXYZ` - the symmetry force-disable

All six are now standalone `if` blocks placed after the chain, so the chain is entirely fatal
and every check is reachable. The three that mutate state (`resLinesTransfer`, `lgDebug`,
`lgSymmetricXYZ`) still run before anything downstream consumes those values.

*Verified against the shipped models:* no shipped input uses `planeIonization`, and the
dust benchmarks that set neither `edges` nor `densityFile` (`benchmarks/dust/1D/*`,
`benchmarks/dust/2D/*`) survive the newly-reachable `Rnx < 0` check because they ship a
`.ndust` dust-density file, so `NdustFile /= "none"`.

### D-047: the launch area exceeds the area the luminosity assumes

`grid_mod.f90:1826` sets

```fortran
Lstar(1) = (meanField/1.e36)*grid%xAxis(grid%nx)*grid%zAxis(grid%nz)
```

so the assumed illuminated area is `L x L` with `L = Rnx`. But the launcher spreads packets over

```fortran
position%x = -(xAxis(2)-xAxis(1))/2. + random*( (xAxis(2)-xAxis(1))/2. &
             + (xAxis(nx)-xAxis(nx-1))/2. + xAxis(nx))
```

i.e. over `-dx/2 .. L+dx/2`, a span of `L + dx` per axis. The delivered flux is therefore

    F_actual = meanField * L^2 / (L + dx)^2

Note this is *not* the factor-of-four I guessed in D-044. Packets are **not** launched across
the full `-L..+L` face - only across the positive quadrant, which is consistent with `L x L`.
The error is the one-cell overhang, and it vanishes only as `nx -> infinity`:

| nx | dx/L | flux deficit |
|---|---|---|
| 5 | 0.500 | 2.25x |
| 21 | 0.100 | 1.21x |
| 41 | 0.050 | 1.10x |

This is a genuine defect in MOCASSIN, not in the coupling, but it is small and bounded and I am
correcting for it in the input rather than changing MOCASSIN's launcher: `meanField` is scaled
by `((L+dx)/L)^2`. Changing the launcher would alter results for any existing plane-parallel
model, and nothing shipped uses the mode, so there is no reference to re-validate against.

### Why D-044's "factor of 5600" was a false trail

It was never a single factor. chi was right at the face to within the D-047 correction; A_V was
measured from the wrong origin (D-045); and the configuration errors that would have flagged the
setup were unreachable (D-046). Chasing one multiplicative constant could not have found any of
them.



## 2026-08-31b - the side walls are mirrors (D-048), which revises D-047

I wrote D-047 before reading the boundary handling, and it is wrong in its conclusion. Recording
the correction rather than editing it away, since the reasoning matters.

### D-048: x and z walls reflect specularly

In `pathSegment` (`photon_mod.f90:2288-2345`) the `lgPlaneIonization` branch handles the four
transverse walls. Each one pins the packet to the wall cell **and flips the normal velocity
component**:

```fortran
if ( (rVec%x >= grid(1)%xAxis(grid(gP)%nx) .or. xP>grid(gP)%nx) ) then
   xP = grid(gP)%nx
   rVec%x = grid(gP)%xAxis(grid(gP)%nx)
   vHat%x = -vHat%x            ! <- specular reflection
end if
```

x-min, x-max, z-min and z-max all do this. Contrast the non-plane-parallel path, where the same
faces terminate the packet (`if (.not.lgPlaneIonization .and. gP==1) return`).

**So the transverse boundaries are mirrors, and the model is a genuine infinite slab.** Two
consequences:

1. *Lateral escape is not a loss channel.* I had assumed the slab needed to be wide relative to
   its depth so sideways-scattered packets would not bias the interior column. It does not.
   The transverse extent is physically irrelevant, so it can be made small and cheap.
2. *The y walls remain open* - packets leave at `yAxis(1)` and at `yAxis(ny)` via `lgReturn`.
   That is correct: the beam enters at one face and escapes out the back.

`safeLimit` is reduced from 50000 to 5000 for this mode (`photon_mod.f90:1286`), which is the
price of the mirrors: a packet can bounce for a long time before being abandoned.

`lgSymmetricXYZ` together with `lgPlaneIonization` is an explicit fatal error inside
`pathSegment` (`photon_mod.f90:2718`), independently of the `readInput` advisory in D-046.

### D-047, revised: there is no normalisation deficit

D-047 argued the delivered flux was low by `((L+dx)/L)^2` because packets launch over `L+dx`
while `Lstar` assumes `L`. With mirrors that is wrong: the overhang is **reflected straight back
into the domain**, so no energy is lost. The mirrors sit at `xAxis(1)` and `xAxis(nx)`, enclosing
an area `L x L`, and

    Lstar = meanField * xAxis(nx) * zAxis(nz) = meanField * L^2

is exactly the energy that ends up inside that area. **`meanField` is the incident flux, with no
correction** - provided the axes run `0..L`, so that the mirrors bound the illuminated region.

This is why the earlier symmetric-axis runs were confused rather than simply mis-scaled: with
axes on `-L..+L` the mirrors sit at `-L` and `+L`, enclosing `4L^2`, while `Lstar` still assumes
`L^2` and the launch footprint covers only the positive quadrant. The geometry, not a constant,
was wrong. Using a density file to put the axes on `0..L` removes the ambiguity entirely.

### D-049: a real bug in the z-min mirror

```fortran
if ( (rVec%z <= grid(1)%zAxis(1) .or.zP<1) ) then
   zP=1
   rVec%z = grid(gP)%yAxis(1)      ! <- should be zAxis(1)
   vHat%z = -vHat%z
end if
```

`photon_mod.f90:2316` places the reflected packet using the **y** axis origin. It is only
harmless when `yAxis(1) == zAxis(1)`, which is true for the symmetric-axis default and false for
any grid whose y and z origins differ - including every density-file slab. Reported here; not
patched yet, because the slab grid below is built with `yAxis(1) = zAxis(1) = 0` so the bug is
inert for the benchmark, and fixing it changes packet paths for any existing plane-parallel model.


## 2026-08-31c - the double-attenuation bug (D-050), and the benchmark moves

### D-050: the field handed to 3D-PDR was attenuated twice

`mocassinToPDR`'s own header states the D-001 contract:

> A_V,eff inverts the attenuation against the unattenuated, geometrically diluted field from the
> sources, so that feeding 3D-PDR `rad_surface(k) = chi0/nrays` with `AV(k) = AVeff` reproduces
> the MC field through its existing `alpha*rad_surface*exp(-gamma*AV)` rate expressions.

The handover did not honour it. `pdrStep` did

```fortran
chi = dble(grid%chiFUV(cellP))      ! the LOCAL, already-attenuated MC field
av  = dble(grid%AVeff(cellP))
radSurf = chi/dble(nraysLoc)
```

`chiFUV` is the Monte Carlo field *at the cell* - MOCASSIN has already transported it through the
dust. `CALCULATE_REACTION_RATES` then applies `exp(-gamma*A_V)` a second time. Every
photodissociation and photoionization rate in the network was therefore too small, and every
front sat at too small an A_V. `chi0` was computed in `mocassinToPDR` and thrown away.

Fixed by storing it: a new `grid%chiFUV0` carries the unattenuated field, and the handover reads
that. `chiFUV` is retained as the MC diagnostic. For plane-parallel illumination there is no
point source to dilute from, so `chi0` is the incident face flux, the FUV luminosity spread over
the area the transverse mirrors enclose:

```fortran
chi0Plane = Lfuv(iS) / (xAxis(nx)*zAxis(nz)*c*uDraine)
```

**This is an independent confirmation of D-048.** The slab was set up for a target of chi = 10
Draine, and the code now prints

    ! mocassinToPDR: plane-parallel surface field chi0 =  10.052786555796875

`meanField` really is the incident flux, with no area correction, exactly as D-048 argued from
the mirror geometry. Two independent routes to the same number.

### Benchmark: the fronts move most of the way

| quantity | before D-045/D-050 | after | standalone 3D-PDR |
|---|---|---|---|
| H/2H2 transition, A_V | 0.025 | 0.037 - 0.043 | 0.069 |
| C+/C transition, A_V | 0.042 | 1.130 | 1.677 |
| heat/cool median | 1.03 | 0.997 | 1 |

C+/C went from **40x wrong to 1.5x**. Both fronts are now short by a similar factor (~1.6-1.9),
which points at one remaining common cause rather than several. The obvious candidate is the A_V
scale: the dust column integration gives N_H/A_V = 5.25e21 per magnitude where the canonical
diffuse-ISM value is 1.87e21, a factor of 2.8. That does not shift the *reported* front A_V on
its own - the chemistry sees A_V directly, so a rescaling moves the physical depth, not the front's
A_V - but it does enter the shielding columns through `NHcol = av/pdrAVfac`, and H2 and CO
self-shielding is precisely what sets these two transitions. That is the next thing to check.

### D-051: a deterministic thermal seed - attempted, and reverted

The 25 transverse cells at a given depth are physically identical by the slab's symmetry, yet
spanned 33 K to 137 K. The radiation field across them varies by only 6% (Monte Carlo noise), so
a 4x spread in temperature is numerical, not physical: where `F(T) = heating - cooling` has more
than one root, the incoming temperature decides which way the march sets off and therefore which
root is found.

Seeding the march from a fixed temperature to remove the path dependence **did not work**:

- seeded at 1000 K, every cell came back at exactly 1000.0 K. The seed is outside the range the
  coolant collision data covers, the first cooling evaluation was non-finite, the loop took its
  `exit` on that branch, and the cell was stored *at the seed*.
- seeded at 300 K, cells pinned at exactly 300.0 K the same way, and the H/2H2 front moved the
  wrong way (0.020 against 0.037 for the unseeded run).

Reverted. Two things are kept from the attempt:

1. **The silent failure it exposed is now guarded.** A non-finite budget used to leave `Tg` at
   whatever the loop last set and store it as the answer. It now falls back to the incoming
   temperature whenever the bracket was never established. This removed the high-temperature
   outliers on its own: the interior column ran 30 K - 9300 K before the guard and 1 K - 275 K
   after it, with heat/cool median unchanged at 0.997.
2. `pdrTseed` remains as an input keyword, unused by default, for a later attempt.

The root-selection scatter is still open. A deterministic scan over a fixed log-spaced
temperature grid, taking the outermost sign change, would fix it properly at the cost of extra
cooling evaluations per cell.

### D-052: the mirror walls omit the half-cell correction

Prompted by a direct question about whether the lateral reflecting-wall tests use the half-cell
geometric correction. They do not, and the branch is inconsistent with itself.
`geoCorrX = (xAxis(nx)-xAxis(nx-1))/2` is the half-cell width, and within the single
`lgPlaneIonization` block:

| wall | test | uses geoCorr |
|---|---|---|
| y min / y max (open, escape) | `yAxis(1)-geoCorrY`, `yAxis(ny)+geoCorrY` | yes |
| x/z walls, sub-grid (`gP>1`) | `xAxis(1)-geoCorrX`, `xAxis(nx)+geoCorrX` | yes |
| **x/z walls, mother grid** | bare `xAxis(1)`, `xAxis(nx)`, `zAxis(1)`, `zAxis(nz)` | **no** |

So the mother-grid mirrors sit at the *centres* of the boundary cells rather than at their faces,
and the outer half of each boundary cell is unreachable. Measured effect on the field is about 7%
(edge columns 6.35, interior 7.12), not the factor of two a bare half-cell would give, because
reflection at the centre plane raises the path-length density on the inner half and partly
compensates.

**This is not a flux-normalisation error, and it should not be "fixed" casually.** Placing the
mirrors at the cell centres is what makes the enclosed area exactly `xAxis(nx)*zAxis(nz)`, which
is the same `L x L` that `setMotherGrid` uses to turn `meanField` into `Lstar` - and the measured
`chi0 = 10.05` against a target of 10 confirms the pair is consistent. Adding `geoCorr` to the
mirrors without also changing the `Lstar` area would introduce a `((L+dx)/L)^2` error - the very
factor D-047 wrongly predicted.

*Practical consequence:* the boundary columns `i=1, i=nx, k=1, k=nz` are half-cells and read
about 7% dim. All benchmark analysis uses an interior column.


## 2026-08-31d - D-053: standalone 3D-PDR is not the benchmark target

Raised by Hektor, and it corrects the standard I had been holding the benchmark to:

> one thing to keep in mind in these comparisons is that the transfer in Mocassin takes into
> account the difuse radiation. I would not expect the front to be identical as well as Te and
> other factors.

This is right, and the effect is much larger than the residual I had been chasing.

### `Jste` is the total field, not the direct beam

`photon_mod.f90:1593-1604`:

```fortran
if (enPacket%lgStellar) then
   Jste += dlLoc*deltaE*weight/dV
else                        ! diffuse packet
   if (lgDebug) then
      Jdif += ...           ! debug only: kept separate for inspection
   else
      Jste += ...           ! normal run: folded straight into Jste
   end if
end if
```

So in a production run `Jste` already carries the scattered and re-emitted component, and `Jdif`
exists only to *separate* it for debugging. Two consequences:

1. The bridge's `if (lgDebug) uFUV = uFUV + Jdif` is **correct as written** - it adds `Jdif` only
   in the one case where `Jdif` is separately accumulated, and avoids double counting otherwise.
   The matching `lgDebug` gates on the `1.e-9` scaling (`iteration_mod.f90:751`) and on the
   accumulation itself are consistent with each other.
2. My 2026-08-31 note flagging "chi decays 4-5x too slowly relative to A_V" as a possible defect
   was **wrong**. That shallow decay is the diffuse field, and it is physical.

### How big the effect is

Fitting the transported field along the slab's interior column:

| A_V range | fit |
|---|---|
| 0.05 - 0.5 | chi = 7.52 exp(-0.407 A_V) |
| 0.5 - 1.5 | chi = 9.48 exp(-0.834 A_V) |
| 0.05 - 1.6 | chi = 8.43 exp(-0.731 A_V) |

3D-PDR's photoreactions use gamma ~ 2.5-3.5 (3.02 for H2 photodissociation, 3.0 for C
photoionization). MOCASSIN transports the field at **gamma_eff = 0.73**, so at A_V = 1.5 the
field is **31x larger** than a pure-extinction law gives.

A correctly coupled model must therefore put its fronts **deeper** than standalone 3D-PDR, and
run a different temperature structure. Recording the earlier table's framing as wrong: the
0.069 and 1.677 figures are a *sanity range*, not targets to converge on.

### The sharper consequence: the diffuse field is currently bypassed

The chemistry does not presently see any of this under plane-parallel illumination. It receives
`chi0` (unattenuated) and `AVeff` from the dust-column integration, and `CALCULATE_REACTION_RATES`
re-derives the attenuation with its own gamma. So the coupling is reproducing **3D-PDR's**
attenuation law, not MOCASSIN's transfer - which is exactly why the fronts land near 3D-PDR's
values, and why that near-agreement is not the reassurance it looks like.

D-001's mechanism was designed for precisely this: invert `AVeff` from `chi/chi0`, so that
3D-PDR's `alpha*rad_surface*exp(-gamma*AVeff)` reproduces the MC field *including its diffuse
component*. D-043 replaced that with direct dust-column integration under plane-parallel
illumination because chi underflowed to zero deep in the slab and the inversion degenerated.

**That underflow was the A_V-origin bug of D-045, and it is fixed.** chi now stays finite all the
way to the back wall (1.16 at A_V = 1.675, against 8.4 at the face). So the inversion is viable
again in this mode, and restoring it is what would carry the diffuse field into the chemistry.

### Open item

- [ ] **Restore the D-001 A_V inversion under plane-parallel illumination.** Drop the
      `.not.lgPlaneIonization` guard in `mocassinToPDR`, keeping `computeAVdust` as the fallback
      wherever chi still underflows. Expect the fronts to move deeper than 3D-PDR's, and treat
      that as the correct outcome rather than a regression. Verify against gamma_eff = 0.73
      rather than against 3D-PDR's front positions.
