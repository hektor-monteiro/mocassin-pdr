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
`3DPDR.F90`, `read_input.F90`, `readdensity.F90`, `UVfield.F90`, `writeoutputs.F90`,
`restart_io.F90`, `logo.F90`, `read_command_line.F90`.

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

- [ ] Install SUNDIALS 7.x and record the exact version here and in the README (D-014).
- [ ] Grep `source/` for any other `output/*.out` name before adding files (lesson from D-011).

---

<!-- Append new entries below this line. -->
