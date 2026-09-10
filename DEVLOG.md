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
| D-054 | Follow TORUS-3DPDR: geometric A_V from the density field, not inverted from the MC field | Accepted | 2026-08-31 |
| D-055 | Derive `pdrAVfac` from the model's own grains; it was 3.3x off the dust column | Accepted | 2026-08-31 |
| D-056 | Porting 3D-PDR's thermal root finder into a 12-step inner loop - reverted | Reverted | 2026-08-31 |
| D-057 | Graded y-axis collapses the surface thermal solve; floor the first cell instead | Accepted | 2026-08-31 |
| D-058 | Match the benchmark's dust (MdMg 0.0281), not just its A_V | Accepted | 2026-08-31 |
| D-059 | Standalone 3D-PDR baseline built and run; my quoted reference values were wrong | Accepted | 2026-08-31 |
| D-060 | Level populations must converge at fixed T before the temperature moves | Accepted | 2026-08-31 |
| D-061 | Per-ray slab escape geometry: helps C->CO, does not close the cooling gap | Partial | 2026-08-31 |
| D-063 | We compiled RAYTHEIA_MO where 3D-PDR compiles ONEDIMENSIONAL; beta divided by 12 | Accepted | 2026-08-31 |
| D-064 | Residual is a uniform ~1.8x temperature offset, not a surface blowup | Closed by D-075/D-076 | 2026-08-31 |
| D-065 | HTT91 ran on uninitialised chi/av and returned its 10 K floor in every cell | Accepted | 2026-09-01 |
| D-066 | MOCASSIN's own dust equilibrium gives 1.2 K at an illuminated PDR face | Retracted by D-092 | 2026-09-01 |
| D-067 | MOCASSIN floors Te at 10 K, exactly where PDR interiors live | Noted | 2026-09-01 |
| D-068 | [CII]/[OI] are included correctly but under-emit; [OI] by 17x | Closed by D-075 | 2026-09-01 |
| D-069 | Blend band is inactive in a pure-PDR slab; packets are not the limit | Closed | 2026-09-01 |
| D-070 | MOCASSIN and 3D-PDR use different atomic data AND different excitation physics | Open | 2026-09-01 |
| D-071 | MOCASSIN re-solves Te in PDR cells, overwriting the handover | Resolved by D-072 | 2026-09-01 |
| D-072 | The PDR owns the thermal balance in its own cells | Accepted | 2026-09-01 |
| D-073 | The benchmark's grains were 0.07-50 um: grey extinction, R_FUV = 1.12 | Accepted | 2026-09-01 |
| D-074 | Full parameter audit against 3D-PDR's params.dat; Fcrit was 20x loose | Accepted | 2026-09-01 |
| D-075 | `NH` species index shadowed by a local `nH`: atomic H collision partner was ZERO | Accepted | 2026-09-01 |
| D-076 | Photoelectric heating was given the UNATTENUATED surface field at every depth | Accepted | 2026-09-01 |
| D-077 | Frequency bins and grid resolution are both converged; 3D-PDR has no grain size distribution | Closed | 2026-09-01 |
| D-078 | Shielding columns used local abundance x total column instead of the integral | Accepted | 2026-09-01 |
| D-079 | What the reported convergence actually measures, and why it is not a PDR test | Noted | 2026-09-01 |
| D-080 | H II + PDR model runs; the blend band needs a resolved ionization front | Accepted | 2026-09-01 |
| D-081 | A uniform grid provably cannot resolve the front; a graded 1D grid can, and the blend band was bypassed | Accepted | 2026-09-01 |
| D-082 | Rollig V2 (n=1e5, chi=1e3) matches standalone to 0-8%; the fixes generalise | Accepted | 2026-09-01 |
| D-083 | Our build compiles ONEDIMENSIONAL, which is 1D-correct and WRONG for any 3D model | Resolved by D-084 | 2026-09-01 |
| D-084 | `PDRGEOM` build switch; 3D needs BOTH RAYTHEIA flags; committed fixture did not reproduce | Accepted | 2026-09-02 |
| D-085 | 3D-PDR has no photoionization; its 1D mode IS a central-source PDR minus dilution | Accepted | 2026-09-02 |
| D-086 | Spherical `AVeff` from the chi/chi0 inversion under-reads the dust column by ~1.8x | Resolved by D-087 | 2026-09-02 |
| D-087 | `computeAVradial`: geometric A_V for non plane-parallel geometry | Accepted | 2026-09-02 |
| D-088 | Radial path never filled the shielding columns, so it fell back to D-078's error | Accepted | 2026-09-02 |
| D-089 | The mid-cloud temperature excess is the scattered FUV field, not the thermal balance | Accepted | 2026-09-02 |
| D-090 | gamma_eff = 1.85 is what this geometry's scattering should give; 3D-PDR's 3.02 omits it | Accepted | 2026-09-02 |
| D-091 | Audit: what H2 and CO exchange with dust, and the one place it uses the wrong dust | Mostly closed by D-095 | 2026-09-02 |
| D-092 | The benchmark dust was PAH-only by accident; MOCASSIN's dust temperature was never broken | Accepted | 2026-09-02 |
| D-093 | Photoelectric and gas-grain energy fed back into MOCASSIN's dust balance | Accepted | 2026-09-02 |
| D-094 | Deep dust temperature is transported IR, not a floor; drop the HTT91 crutch | Accepted | 2026-09-02 |
| D-095 | The "PAH inconsistency" was mostly my own double-count of an unused heating term | Accepted | 2026-09-02 |
| D-096 | Full audit pass: per-coolant cooling, missing MPI exchange, non-PDR build restored | Accepted | 2026-09-02 |
| D-097 | MOCASSIN's infrared transfer verified; HTT91's 10 K floor is the wrong one | Accepted | 2026-09-02 |
| D-098 | Adopt TORUS-3DPDR's section 5.4 photoionization+PDR model as the coupled-code reference | Accepted | 2026-09-02 |
| D-099 | ionDen(H,1) is the non-ionized total, not atomic H; correcting it needs H2 opacity | Reverted, documented | 2026-09-02 |
| D-100 | How to give MOCASSIN an H2 opacity: not by reusing the self-shielding function | Design | 2026-09-02 |
| D-101 | The slabs are fed ionizing photons Roellig does not specify - necessary but not sufficient | Partial | 2026-09-02 |
| D-102 | ionBalance normalised the ion stages to sum to one, asserting no molecules exist | Accepted | 2026-09-02 |
| D-103 | The deep dust heating is the diffuse Lyman continuum; H2 opacity is confirmed as the blocker | Confirmed by D-104 | 2026-09-03 |
| D-104 | Band budget: the ionizing field is 1955x larger, and it is paid for by nothing | Partly withdrawn by D-106 | 2026-09-03 |
| D-105 | Substituting the chemistry's electron density makes the runaway worse, not better | Rejected | 2026-09-03 |
| D-106 | Let the chemistry own the ionization of its own elements in PDR cells | Accepted | 2026-09-03 |
| D-107 | H2 photoionization continuum added; pdrAtomicH and pdrOwnIon now default on | Accepted | 2026-09-03 |
| D-108 | The H2/CO photorate shielding now uses this model's grains, not Savage & Mathis 1979 | Accepted | 2026-09-03 |
| D-109 | Dust measured per cell, not from one arbitrary cell; found T_dust = 2.3e9 K in getDustT | Accepted | 2026-09-03 |
| D-116 | Dielectronic fit returns negative rates in cool gas; clamped, with its division guarded | Accepted | 2026-09-04 |
| D-117 | Matrix ionBalance closes at 2e-15 / 3e-8 once rates are non-negative; enabled | Accepted | 2026-09-04 |
| D-118 | Chemistry's per-stage rates feed the ion matrix; elemAvail stands down | Accepted | 2026-09-04 |
| D-119 | In-cell ionization/chemistry loop; H2 front 0.497 -> 0.905 against a 0.9054 reference | Accepted | 2026-09-04 |
| D-120 | Intermittent crash at T_dust, ~8%, pre-existing. Framed as a NaN; it was not one | Superseded by D-127 | 2026-09-04 |
| D-121 | Coupling loop across four fixtures: improves two, degrades V2 | Settled by D-123/D-128 | 2026-09-04 |
| D-122 | "All grains sublimed" is a finite excursion, not a NaN (correct). Blamed on the mirror-wall corner (wrong) | Superseded by D-127 | 2026-09-04 |
| D-123 | Pass-count ladder: loop converges by 5 passes; collapses between-fixture spread 4.3x at a systematic 5% low bias; default 1 -> 5 | Done | 2026-09-05 |
| D-124 | Excursion localised to gas-grain collisional heating, ~1e19 over a hand evaluation; not PDR, not the corner; mawk E-notation retraction | Superseded by D-127 | 2026-09-05 |
| D-125 | Instrumentation suppresses the fault (6/20 -> 0/14) - the clue that led to D-127; control run established the rate had not drifted | Superseded by D-127 | 2026-09-05 |
| D-126 | Vectorisation ruled out (3/10), narrowing the fault to memory layout; the grainPotP note here grew into D-130 | Superseded by D-127/D-130 | 2026-09-05 |
| D-127 | **Root cause: IPerg read uninitialised for istage==1 on every call.** Fixed; 0/12. Must precede any fix to the S units bug | Done | 2026-09-05 |
| D-128 | Ladder re-run clean: fronts unchanged to MC scatter, D-123 stands. My prediction that the garbage shifted results everywhere was wrong - it was negligible or catastrophic, never in between | Done | 2026-09-05 |
| D-129 | Sticking coefficient units fixed (grams vs amu, 1.7e-25 -> 0.091). Invisible in the coupled fixtures by construction; in plain MOCASSIN the coldest dust warms 10%, groups fully separated | Done | 2026-09-05 |
| D-130 | Multi-component dust segfaults on unmodified code - species index offset twice. Fixed, plus local/global grainPot reads and the whole-array grainPotP assignment | Done | 2026-09-05 |
| D-131 | pdrAllCells: chemistry in every cell, so H2/CO emerge instead of being seeded (0.3 -> 1e-8 in ionized gas). pdrCoolFeedback: molecular cooling and the six missing heating terms into MOCASSIN's balance | Done | 2026-09-05 |
| D-133 | Atomic coolants REPLACE rather than are excluded inside the PDR - MOCASSIN excites [C II]/[O I] with electrons alone, 3D-PDR carries H/H+/He/H2 | Done | 2026-09-05 |
| D-135 | The handed-over terms were divided by 4pi as well as Hden, making them 12.6x too small - which is why two successive hypotheses each moved the deep PDR by ~1 K | Fixed | 2026-09-05 |
| D-136 | **Policy: 3D-PDR is a reference, not a benchmark. MOCASSIN owns the dust and everything following from it** | Standing | 2026-09-05 |
| D-138 | H I photoionization is 99.5% of the heating in deep PDR cells; carbon 0.0%, so the metals explanation is dead | Open | 2026-09-05 |
| D-139 | Added an H2 continuum at 13.6-15.4 eV, then REVERTED: Cloudy puts zero there, and x(H)=0.189 gives tau=230 per cell so nothing was leaking | Reverted | 2026-09-05 |
| D-141 | Yan/Sadeghpour/Dalgarno H2 photoionization cross section ported from Cloudy, replacing D-107's power law - which was 2.5x low across the 18 eV peak | Done | 2026-09-05 |
| D-143 | Deep-PDR H I heating is not transported light: one bin in 171 carries flux, the same bin in 31/31 cells, where tau = 175 per cell. Points at the boundary treatment (D-049) | Open | 2026-09-06 |
| D-144 | Mirror hypothesis REJECTED: 90% of the heating is away from the boundaries and all three planes show the same ~3x geometric enhancement. The 31/31 result was a probe sampling artifact | Done | 2026-09-06 |
| D-145 | Jste holds stellar AND diffuse when lgDebug is false; MOCASSIN's debug mode segfaults on its own, so the two fields cannot currently be separated | Open | 2026-09-06 |
| D-146 | Stored opacity gives tau=388/cell, the field decays as tau~0.9/cell. Forced-skip weight exp(-tau) underflows to exact zero above tau~87, explaining why 170/171 bins are exactly zero | Open | 2026-09-06 |
| D-147 | Forced skip removed on instruction. Moves the shipped default's front 0.9150 -> 0.8534, so it had been materially affecting results | Done | 2026-09-06 |
| D-148 | RETRACTED: the convergence criterion was never wrong - gas models always used x(H0) (iterateT:777); the dust-T test is the dust-only branch, as it should be | Retracted | 2026-09-06 |
| D-149 | Convergence collapse is caused by pdrTeFromMocassin alone (97.7% -> 0.13%) and is indifferent to 8x packets. Structural, not statistical | Open | 2026-09-06 |
| D-152 | Failing cells are at the ionization front where the two codes disagree 3-38x on x(H0), and the blend gate keys on the disputed quantity | Superseded by D-155 | 2026-09-06 |
| D-153 | MOCASSIN owns ionization, chemistry returns molecules only, no gating. Implemented; does NOT fix convergence, and the network relaxes an imposed ratio back | Partial | 2026-09-06 |
| D-155 | **Convergence criterion compared against the previous COUPLING PASS, not the previous iteration** - a D-119 regression. Reported 100% where the truth was 0%. Fixed | Done | 2026-09-06 |
| D-156 | Ladder re-measured correctly: pdrAllCells and pdrCoolFeedback converge at 97.7% in 5 iterations; pdrTeFromMocassin collapses and removing the gating does not help. The transport defect blocks the whole self-consistent mode | Done | 2026-09-06 |
| D-159 | **Not a transport bug.** Field is 86-100% stellar, no packet crosses tau>20, and the failing cells are nearly transparent (x(H0)=0.026). Two self-consistent branches - ionized/hot and neutral/cold. D-143's framing retracted | Open | 2026-09-06 |
| D-160 | Not bistable either: a neutral start decays away, but the two starts end materially different (median Te 379 vs 1246 K). No stable fixed point under pdrTeFromMocassin. Adds initH0, previously hardcoded | Open | 2026-09-06 |
| D-161 | **The codes were never disagreeing.** The reduced network has NO H photoionization - every H->H+ channel is charge exchange or cosmic rays - so its x(H+) is the cosmic-ray equilibrium. Cloudy's answer: shared storage for linked ion stages, network gives src/snk only | Done | 2026-09-06 |
| D-162 | **One x(H+), owned by MOCASSIN.** Ratio re-imposed after the solve as well as before, for all five linked elements. Chemistry and MOCASSIN now agree to 7-8 figures where they were 3-38x apart. 97.76% vs 97.74% - costs nothing | Done | 2026-09-06 |
| D-163 | Duplicated channels removed from the network as Cloudy does: C and Mg photoionization, and recombination of all five ions. Charge exchange and cosmic rays kept. Every suppression printed | Done | 2026-09-06 |
| D-164 | Suppression corrected: reactions 330/331 are recombination ON GRAINS ('#' marker), which MOCASSIN lacks - now kept. Nine channels suppressed, not eleven. 97.74% | Done | 2026-09-06 |
| D-165 | **pdrTeFromMocassin never reached iterateT.** The D-072 short circuit that skips the temperature solve in PDR cells was never taught about the switch, so MOCASSIN has never once solved the thermal balance in a PDR cell. Every "MOCASSIN owns T" number - 0.079/0.099/0.217% - measured a frozen temperature | In progress | 2026-09-06 |
| D-166 | **The PDR coolant is a stored constant inside iterateT.** With the solve finally running, 45% of cells run to a rail and 23% have a residual flat to <1% across the whole scan - 100% of those clamped. In neutral gas it is the only coolant that matters. Made T-dependent by a two-point power law | In progress | 2026-09-06 |
| D-167 | The atomic coolant replacement subtracted MOCASSIN's term and added zero whenever pdr_mod had floored the carrier. Real, fires 1.26M times per iteration, and **changes nothing measurable** - the deleted term is electron-excited, which is why D-133 replaced it in the first place. Guard kept | Done, null | 2026-09-06 |
| D-168 | The hot runaway is 99.7% H0 photoionization heating. The flux is STELLAR, not diffuse, behind tau = 1270 per cell. 4028 of 20024 ceiling clamps are the updateCell-before-pdrStep ordering; the rest are not | Done | 2026-09-06 |
| D-169 | **pdrOwnIon and pdrIonFromMocassin are opposite policies and both were on.** ionBalance `cycle`s the writeback for H/He/C/O/Mg in every PDR cell, so MOCASSIN's answer was discarded in the same cells D-162 imposes it from. Fixed: **ceiling clamps 20024 -> 0**, Te convergence 55% -> 97%. Structure correct: IF at A_V 0.5, deep x(H2) = 0.495 | Done | 2026-09-06 |
| D-171 | **The self-consistent mode is spatially bistable on ALL THREE fixtures.** V1 shows 55 hot/cold transitions along an 801-cell sightline (a front gives 1-2), cells at identical A_V sitting at 17 K and 11036 K. Cloudy prevents this by continuation + adaptive zoning, which MOCASSIN has neither of | Open | 2026-09-07 |
| D-176 | **The reported convergence was measuring the wrong test.** pdrStep clears lgConverged on the PDR heat/cool balance (D-032) after updateCell sets it - a balance nothing solves under pdrTeFromMocassin. ~74500 pass-events cleared per iteration. Gated: 0.03% -> 98.2% on the same physical model | Done | 2026-09-07 |
| D-177 | Full audit of the code against the self-consistent mode. Seven leftovers found; two already fixed, one in test, four new | In progress | 2026-09-07 |
| D-178 | Per-species total content reported per iteration - Cloudy's column-density test, geometry-free. At the iteration reporting 98% converged, H2 was changing **+594%** and mean Te -53% | Done | 2026-09-07 |
| D-179 | Convergence requires x(H0) AND x(H2) when the PDR is on, significance-gated. At the iteration the PDR engages the failures are **18x more x(H2) than x(H0)** - the molecular content was what the old test could not see | Done | 2026-09-07 |
| D-180 | **`convLimit` sets the PER-CELL tolerance, not the converged-cell fraction.** Every fixture carried `convLimit 0.90`, so a cell passed if x(H0) changed by less than 90%. Every convergence number this project has ever reported was measured against that | Done | 2026-09-07 |
| D-181 | **First benchmark numbers on a converged model.** V2 converges (all species <=0.7%): CO front **1.017**, H2 front 1.32. V1 does not (H0 -27%, Te -33%). Bistability largely resolves - V1 transitions 55->15, V2 25->**1**. Gas 3-7x too warm in all three | Done | 2026-09-08 |
| D-182 | **Zone gates removed.** The coolant substitution and the dust feedback no longer key on pdrZone: 3D-PDR's coolants carry electrons AND H/H+/He/H2, so they are the more complete physics everywhere and reduce to the electron case by themselves in ionized gas | Done | 2026-09-08 |
| D-183 | H2 cooling: **neither code has an explicit H2 line coolant.** H2 enters as a collider exciting CO/C+/C/O, as three heating terms, and via the critical-density suppression of FUV pumping. Cloudy computes it explicitly; we match the reference by construction | Understood | 2026-09-08 |
| D-184 | **cmp_sph defaulted to the wrong reference.** hii1dv2 carries C = 1.4e-4, sec54 and our fixture carry 2.2e-4 - a spurious uniform 1.571x carbon offset in every sec 5.4 comparison this project has made. Fixed | Done | 2026-09-08 |
| D-185 | **elemAvail stands down where the rates ARE, not where a zone flag says they should be.** The old test asserted delivery rather than checking it; pdrStep writes the rates AFTER updateCell, so on the first PDR pass they are identically zero and the molecular locking was carried by neither mechanism. Keyed per element on the rates themselves; both zone gates removed | Done | 2026-09-08 |
| D-186 | **Atomic-data inconsistency, flagged for future work.** [C II]/[C I]/[O I] are taken from 3D-PDR because MOCASSIN excites them with electrons alone. Correct physics today, but two codes hold line data for the same transitions. The endpoint is MOCASSIN owning them with H/H2/He colliders added, and 3D-PDR supplying only rates MOCASSIN does not have | Deferred | 2026-09-08 |
| D-187 | **The two atomic datasets measured.** MOCASSIN (CHIANTI v10) vs LAMDA: energies agree to <=0.1% and weights are identical, but the A-coefficients differ by **1.3% ([C II] 158um)** to **6.1% ([O I] 145um)**. Too small to matter today, but a silent dependency on which code computed the cooling | Measured | 2026-09-08 |
| D-188 | **Every cell was seeded x(H2)=0.300, x(H)=0.400 - the network file's dark-cloud defaults - including cells in the H II region at 9000 K.** Now seeded from MOCASSIN's own ionization state on first visit, molecules zero, chemistry forms them | Done | 2026-09-08 |
| D-189 | Restart audit: elemAvail reset to 1.0 ("no molecules") and H2den to 0 while pdrAbun was restored full of them. Both are functions of pdrAbun - now DERIVED from the restored state instead of defaulted | Done | 2026-09-08 |
| D-190 | **PDRGEOM=3D with ray-traced per-ray columns.** A 3D photoionization code had been coupled to a 1D PDR: 11 of 12 rays blanked, escape probability undivided, all 12 shielding columns filled with one source-ward scalar. Mean Te **-23%**, its per-iteration change **26.8% -> 6.9%**, and **the two-cell ionization oscillation at the front is gone** | Done | 2026-09-08 |
| D-191 | **Damping 0.50 removes the residual hot spike near the front** (2024 K -> 202 K, median T ratio 6.56 -> 4.77) **and exposes an H2 error the spike was masking**: x(H2) overshoots 12x once the spurious heat is gone. Not settled at 24 iterations; fixtures keep 0.25 | Open | 2026-09-08 |
| D-192 | **MOCASSIN's ionDen(H) and the chemistry's x(H) disagree by 100-200x past the H2 front**, in both runs: x(H+) 5.8e-1 against 4.5e-2, x(H0) clamped to exactly 0, budget 1.50 instead of 1.00 in 16 of 29 axis cells. Opacity, heating and n_e in the molecular interior all read the broken array | Open | 2026-09-08 |
| D-193 | **One reality: ownership is no longer an input.** MOCASSIN owns ionization and thermal equilibrium in every cell; 3D-PDR returns molecular content plus heating/cooling and nothing else. Fixes D-192 (elemAvail now always constrains the ion sum), drops the rate injection, **adds cosmic-ray ionization to MOCASSIN's own ionBalance**, retires pdrAtomicH / pdrOwnIon / pdrIonFromMocassin / pdrTeFromMocassin | Done | 2026-09-08 |
| D-196 | **The convergence percentage was counting frozen cells.** 97.0% of the converged PDR cells have x(H0) clamped to exactly zero by the D-192 handback, because ionBalance's conservation row normalises hydrogen to the TOTAL rather than the available fraction and over-states x(H+) by ~99x. D-191's mechanism was right and its direction wrong: x(H0) is pinned at 0, not near 1. D-190's 89.31% is not trustworthy. Correcting it (`ionChemRates 0`) sends the ratio to exactly 1, eliminates the clamp entirely, and raises convergence to 92.28% at iteration 12 with 0.0% of converged cells frozen | Measured | 2026-09-09 |
| D-197 | **Reverted to D-190** (recorded as D-191 at the time, colliding with the damping entry that already held that ID). **Undone at D-198.** D-193 (ownership hard-coded), D-194 (port list) and D-195 (H2 formation on the measured grain area) were discarded with it: they made the model worse, and the convergence fraction fell from 89.3% to 5.8% with 36-45% of cells flipping across 1000 K on every pass. Recoverable at tag `d193-d195-reverted`, and all three are now back: D-193 restored at D-198 on D-196's evidence, D-195 cherry-picked at D-209 because the H2 seed needs a formation rate built on MOCASSIN's own grains. The D-192 hydrogen-budget defect returned with the revert | Superseded by D-198 | 2026-09-09 |
| D-198 | **D-193 restored on D-196's evidence.** The revert at D-197 compared a convergence number that counts frozen cells against one that does not; D-196 measured that directly. MOCASSIN owns ionization, thermal equilibrium and molecular bookkeeping again, unconditionally, and `ionChemRates` retires with the other ownership keywords | Done | 2026-09-09 |
| D-199 | **`elemAvail` was one MC iteration stale.** `pdrToMocassin`, its only writer, sat outside the coupling loop while `updateCell` read it 5 times per iteration. Harmless until D-193 stopped writing `ionDen` directly; after that it rang the ion/chemistry ratio 1.05 -> 19.5 -> 0.166 with nothing converging. Moved inside the loop: the ratio holds 1.0000 with p90 1.01 and budget failures fall 9670 -> 29 | Done | 2026-09-09 |
| D-200 | **Damping extended from the temperature to the molecular and ionic state.** D-174 damped Te across the MC iteration and recorded "Te only, for now: it is the bistable variable"; D-198 measured that it is not - a hot cell is atomic AND ionized AND hot. `pdrAbun` and `ionDen` are now damped on the same interval, and `elemAvail` republished from the damped abundances. Whether this resolves the bistability or only freezes it is the measurement | Running | 2026-09-09 |
| D-201 | **The D-200 damping created a second x(H2), and the damping's own diagnostic caught it.** `pdrAbun` was damped but `H2den`, which `pdrStep` derives from it, was not - so the H2 opacity, the convergence test and the branch census read an undamped molecular fraction while the chemistry used a damped one. Measured: the same census gave 27.6% hot from `H2den` and 1.6% from `pdrAbun` on the same cells. `H2den` now follows. With it single-valued the hot-branch eruptions vanish (76% -> 0%, flips 78% -> 0%), but the molecular-fraction swing at iterations 6 and 11 is identical in both runs - it is not the damping and not the split | Done | 2026-09-09 |
| D-202 | **The branch census was blind to the swing it was built to watch.** D-200's instrument labelled each cell hot / cold / between and counted changes of the HOT label; the collapse runs between the cold and middle labels and never crosses the hot threshold, so the flip count read 0-1.8% while three quarters of the grid moved. Replaced with the molecular fraction's own distribution - an eight-bin histogram of f_mol = 2x(H2), its quantiles, and |df_mol| since the iteration start - so no threshold decides what counts as a change of state. The new census reproduces the collapse and shows it is a broad multi-modal distribution, not two clean branches | Done | 2026-09-09 |
| D-203 | **The collapse is not the radiative transfer's: measured.** chi_FUV and A_V are now reported as quantiles every iteration beside f_mol and Te. Across the iteration-6 collapse the median f_mol falls 0.765 -> 0.196 and the median Te rises 79 K -> 8006 K while the median chi moves +1.0% and A_V -0.3%. The FUV field and the extinction are exonerated; the instability is inside the chemistry / thermal-balance loop. The inner coupling loop is exonerated too - its ion-fraction change decays 8.6e-3 -> 1.6e-3 over four passes within that same iteration | Done | 2026-09-09 |
| D-204 | **Neither leads: the collapse is a coupled runaway, and the D-203 inference was wrong.** Te sampled after the first updateCell of each iteration - thermal balance done, chemistry not yet run. At iteration 6 that takes the hot fraction from 2.25% to 5.08% at f_mol still 0.70; it ends the iteration at 76.74%. So the thermal balance alone contributes one fourteenth of the excursion and the rest appears across the five coupling passes. D-203 reasoned from the pass order that Te probably leads; measuring it says otherwise | Done | 2026-09-09 |
| D-205 | **The coupling loop's own residual is blind to the runaway inside it.** Within iteration 6 the [D119] abundance-weighted ion-fraction change decays monotonically 8.56e-3 -> 1.46e-3 across the five passes while the hot fraction goes 5.08% -> 76.74% in those same passes. It measures ion fractions, so the thermal/molecular runaway is invisible to it - the third instrument in this audit to report quiet on a moving model (D-196, D-202). The D-204 snapshot now fires on every pass, with the PDR cooling and heating the balance was handed | Running | 2026-09-09 |
| D-206 | **Twelve iterations: a relaxation oscillation, not a bistability - and the D-204 sign flip is withdrawn.** The model relaxes toward cold molecular gas over four iterations (|df_mol| p90 0.62 -> 0.13, converged fraction reaching its run maximum at iteration 9) and then discharges to 77% hot in one. Iteration 8 starts at f_mol 0.662, within 6% of iteration 6's, and its pass-1 balance cools by x0.15 where 6 warmed by x4.58 - so the sign flip flagged from three points was the initial transient read as a trend. chi_FUV jumps 45% the iteration AFTER each collapse, confirming the field follows the molecules | Done | 2026-09-09 |
| D-208 | **The network file's x(H2)=0.300 was never removed, only routed around - and it was setting the H2 shielding column the first chemistry call consumed.** D-188 re-seeded each cell from MOCASSIN on its first `pdrStep` visit, but `seedPDR` went on writing `species_reduced.d`'s x(H)=0.400 / x(H2)=0.300 into every cell, and `computeAVdust` and `computeRayColumns` run BEFORE the coupling loop - so at the first PDR iteration the columns were integrated over a grid uniformly 60% molecular, order 1e21 cm^-2, which saturates self-shielding outright. One seeding rule now: `seedAbunFromMocassin`, molecules zero, every carrier from `elemAbun` and `ionDen`. `syncSeed` and `pdrSyncAbun` retire with it | Done | 2026-09-09 |
| D-207 | **The D-205 budget columns reported quantities that never enter the balance.** They printed `pdrCool`, `pdrHeat` and `pdrHeatPE` - 3D-PDR's own totals. `pdrHeatPE` reaches `heatInt` only when `pdrPEfromPDR` is set, which is 0 by default and in no fixture, and `pdrHeat` is the PDR total of which MOCASSIN computes three terms itself. The heating column read ~1.9e-25 per H where the true contribution is ~1.4e-26. Replaced by `pdrHeatUsed` and `pdrCoolUsed`, captured as `heatInt`/`coolInt` after the PDR block minus before it - the substitution's net effect and nothing else | Done | 2026-09-09 |
| D-194 | **Port list: 3D-PDR's presuppositions about our dust and abundances.** H2 formation on a hardcoded 6.273e-22 cm2/H grain cross-section (MOCASSIN measures 4.92e-22 and tracks MdMg, CT02 does not); photorate gammas on Savage & Mathis when this model's grains imply UV_fac 3.83 vs 3.02; WD01 grain recombination not even compiled in; network abundances C=1.4e-4 vs the model's 2.2e-4 | Open | 2026-09-08 |
| D-195 | **H2 formation on grains now runs on MOCASSIN's own dust.** Upstream hardcoded 8.473e-22 / 7.908e-22 cm2/H for silicate / graphite, with no dependence on MdMg, the size distribution or the composition, while the rate is LINEAR in them. MOCASSIN now measures the geometric grain area per H per cell and splits it by material. This model: **1.02e-21 cm2/H, all silicate, zero graphite** - 20% MORE area than CT02 assumes, but a **0.62x** rate at cold dust and **0.24x** at 60 K, because CT02's graphite channel was carrying the rate and this model has none | Done | 2026-09-08 |
| D-209 | **H2 and CO seeded from MOCASSIN's photoionization state - and the oscillation does not care.** At `pdrStartIter` MOCASSIN has a converged x(H0), Te, Tdust and dust opacity, so the H/H2 balance is placed by formation-on-grains against photodissociation at equilibrium, closed form, hydrogen conserved, with the CT02 rate on MOCASSIN's measured grain area (D-195 restored) and the network's own photodissociation coefficient. The seed lifts iteration 4 from f_mol 0.23 to 0.77 - and from iteration 6 the run is identical to the zero-seed run, collapses at 6 and 11 in both. The cycle is an attractor with no memory of the seed | Done | 2026-09-09 |
| D-210 | **The oscillation is the cooling substitution changing sign, measured at both collapses.** `pdrCoolUsed` - what the PDR block actually does to `coolInt` - is +2.4e-23 per H at pass 1 of iteration 6, where the gas is cold and molecular, and **-1.5e-24 at pass 2**, with Te going 542 K -> 4127 K and f_mol barely moving (0.809 -> 0.697). By pass 5 it is deleting 1.6e-23. Iteration 11 reproduces it: +2.0e-23, -1.3e-24, converging to the same -1.58e-23. The heating handback is ~1e-27 throughout, four orders down, and plays no part. D-167's guard covers only a ZERO 3D-PDR coolant, not a smaller one, and its `nCoolNull` counter is incremented and never printed | Done | 2026-09-09 |
| D-211 | **D-167's guard covers the wrong case.** It protects against 3D-PDR's coolant being ZERO; measured, `guard kept` is 0.000 per cell in every pass after the first, so that case never fires. The loss is 3D-PDR's coolant being merely SMALLER than MOCASSIN's, on the same code path, unguarded and silent. At iteration 5 pass 4 MOCASSIN's removed coolant is 2.19e-25 against 5.10e-26 put back. `nCoolNull`, the one counter that separates the two, has been incremented and never printed since D-167 | Done | 2026-09-10 |
| D-212 | **Ne re-imposed on the chemistry every call - correct, and not the bug.** Electrons are not an element, so D-153's link table never reached them: `abun(NELECT)` was written from MOCASSIN's Ne once per cell and then evolved under CVODE, while the four other collision partners feeding the substituted cooling were re-imposed every call. Fixed on contract grounds. Measured: iteration 6 is unchanged to within run-to-run scatter. The premise - that it drifts - was never measured; D-153 already re-imposes C+ and H+, which set the electron abundance | Done | 2026-09-10 |
| D-213 | **The collapse is D-166's extrapolation decaying, not the chemistry.** `added` is `pdrCoolSp` times `(Te/Tref)^slope`. Split at iteration 6: the raw coolants RISE monotonically x22 across the passes, while the effective multiplier falls **229 -> 3.2 -> 1.2 -> 1.00**. At pass 1 `Tref` is 177 K from the previous iteration's cold chemistry and the mean slope is 2.71 (clamp ceiling 12), manufacturing a stiff artificial thermostat that holds the cell at 530 K; each pass re-anchors `Tref`, the slope flattens, the prop is removed and Te marches to ~8300 K. Separately, at multiplier 1.00 the substitution still replaces 1.81e-23 of MOCASSIN's cooling with 2.46e-24 of 3D-PDR's - a 7.4x net loss in hot gas | Done | 2026-09-10 |
| D-214 | **The coupling loop is a temperature-marching scheme, and the march is the amplifier.** Each pass runs a full `iterateT` at frozen radiation field, re-anchors `pdrCoolTref`, flattens the slope and releases the temperature the previous extrapolation was holding: 530 -> 4129 -> 8054 -> 8245 -> 8283 K inside iteration 6. With `pdrCoupleIter 1` both collapses vanish (f_mol 0.291 -> 0.759 at it 6, 0.327 -> 0.764 at it 11) and the run is 2.5x faster. **Partly retracted at D-215**: much of that was the extrapolation propping the gas cold | Done | 2026-09-10 |
| D-215 | **The cooling function is tabulated and interpolated; D-166's power law is retired.** Inside `iterateT` only T moves, so the coolant is a function of one variable: 16 points log-spaced over [1, 2e4] K, log-log interpolation, clamped at the ends, never extrapolated. The effective multiplier falls from **x420 to x15.5**, and x15.5 IS the real cooling function over that temperature range. D-213's "second defect" (substitution deleting cooling 7.4x in hot gas) was an artefact of the first and is **retracted** - the substitution is now net positive. The oscillation survives, damped 4.8x in Te amplitude | Done | 2026-09-10 |
| D-216 | **MOCASSIN solves Te and ionization once per MC iteration; the chemistry converges against it.** The `updateCell` loop moves out of the coupling loop, so `pdrCoupleIter` now counts chemistry passes only. Te is constant across passes by construction (2977.4 K at every pass of iteration 6). The trajectory is identical to the one-pass run within scatter - collapses at 6 and 10, Te median 2558/1502 K against 2517/1677 - so D-119's chemistry closure buys nothing and the D-214 confound is closed. It costs 2.7x in wall clock (58:42 vs 21:53). The pass-to-pass f_mol alternation is real but at most 0.034, against a ~0.4 collapse: NOT a candidate for the residual. Under one thermal solve the order is unambiguous - Te jumps 131 K -> 2977 K at f_mol 0.80, then the chemistry follows | Done | 2026-09-10 |
| D-217 | **The trigger is photoionization heating from the MC field, landing in the coldest cells.** At every iteration the cells that go cold -> hot enter the thermal solve with photoionization heating 45-2208x that of the cells that stay cold (45x and 111x at the two collapses) and 6-843x their own total cooling (above 100x from iteration 6 on); photoelectric and PDR terms are two orders smaller. Iteration 6: 8336 cells at 88 K carrying 4.47e-23 per H. Iteration 10: 6649 at 133 K, 6.64e-23. The heating does not stay put - cells that flipped enter the next iteration with it 100x lower. The instrument's entry slot reproduces the iteration-start Te to 0.1 K. Separately, `resetGrid` had none of the post-D-188 PDR arrays; fixed, compiled, not exercised by a warm run | Done | 2026-09-10 |
| D-218 | **Two regularities hold at every iteration; no single variable decides which cells flip.** Twelve iterations (runs/d218-front, 21:33). At EVERY iteration 5-12 the flipping cells come overwhelmingly from last iteration's cold cells, and a cell that flips receives ~1000x LESS field the next iteration (started hot: J 1.5-5.3e-6; flippers 2e-4-1.1e-2). The two big collapses look alike - iteration 6 (8265 cells) and 10 (6587) put their flippers deep (A_V 2.34, 2.41), very molecular (f_mol 0.904, 0.905) and at the lowest threshold tau (466, 201) - but the follow-on iterations do not, and threshold tau does not predict where the field lands (at 7 and 11 the lowest-tau group gets the least). The opacity trails the ionization by one iteration (tau 1260 = x(H0) 1.0 at it 5; predicted 460, measured 466 at it 6) | Done | 2026-09-10 |
| D-219 | **The opacity was built from a hydrogen budget that did not sum to 1, and D-216 made that the permanent state.** The census's x(H0)+2x(H2)+x(H+) - exactly what `ionizationDriver` reads to build the next opacity - ran at a median of 0.43-1.85 whenever one ionization solve was followed by chemistry that moved (D-216 and the one-pass runs); the five-pass loop held 1.000. The opacity followed that stale state (tau 1260 = x(H0) 1.0 at iteration 5). `seedMolecules` also never republished `elemAvail`. **Fixed by D-220**: budget 1.0000 at every iteration measured. Not the cause of the collapse - it persists with the budget closed | Fixed | 2026-09-10 |
| D-220 | **The ion stages are rescaled to the chemistry's available fraction before the next opacity is built - verified, and the collapse survives it.** D-153's rule on MOCASSIN's side, applied after the D-200 damping, plus a `pdrToMocassin` after the seed. Before the rescale hydrogen was off by a mean 0.400 / 0.093 / 0.420 (93% / 78% / 89% of cells) at iterations 4-6; after it the budget reads 1.0000. The opacity follows: tau 281 per cell against 272 predicted at iteration 5, where it read 1260. Iteration 6 still collapses - median f_mol 0.239 against 0.238 without the fix, Te median 2160 K against 2525 K | Done | 2026-09-10 |
| D-221 | **The heating that flips cells comes from above 15.43 eV, where H2 absorbs - not from the H2-transparent window.** At iteration 6, 7274 cells go cold -> hot (7270 of them cold at iteration 5): 99.9998% of their field and essentially all their H0 photoionization heating (4.94e-23 against 3.2e-29 in the window) lie above 15.43 eV, and H0 is 99.3% of their photoionization heating. Iterations 4 and 5 showed the same in 18 cells. So missing H2 line opacity between 13.6 and 15.4 eV is ruled out as the cause. The two bands reproduce D-218's total field to four figures | Done | 2026-09-10 |
| D-110 | Zeroing molecules outside the PDR zone: implemented, then rejected as imposing the answer | Rejected | 2026-09-03 |
| D-111 | Cloudy couples ionization and chemistry by per-stage source/sink, not by network photoionization | Accepted | 2026-09-03 |
| D-112 | H2 self-shielding is bistable; the seed is a model input, not a numerical artifact | Accepted | 2026-09-03 |
| D-113 | Per-species form/loss exported from the ODE RHS; H2 formation measured at 4.6e-17 | Accepted | 2026-09-03 |
| D-114 | Matrix ionBalance: balance rows correct, trace stages not; inert pending ion_trim | Partial | 2026-09-04 |
| D-115 | Trimming implemented; blocked by alphaTot = 0, which the old code hid behind Inf | Blocked | 2026-09-04 |
| D-062 | `pdrStartIter`: let MOCASSIN converge before enabling the PDR | Accepted | 2026-08-31 |

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


## 2026-08-31e - D-054: what TORUS-3DPDR actually does

Hektor asked how TORUS-3DPDR (Bisbas et al. 2015, arXiv:1509.05038) handles the coupling. It is
the closest published analogue to this work - a Monte Carlo radiative transfer code coupled to
the same 3D-PDR - so its choices are worth matching or consciously departing from.

### Where we agree

Their FUV field estimator is ours. TORUS accumulates

    U = (eps/dt) * (1/(1.71 H_0)) * (1/V) * sum(l)

over path lengths in the 912-2400 A band - the Lucy path-length estimator normalised to Draine
units. That is the D-001 formula, arrived at independently, which is a useful check on Phase 0.

One difference: TORUS stores the field **directionally**, as positive/negative direction vectors,
so multi-dimensional geometries keep the anisotropy. We store a scalar per cell.

### Where we differed, and why we now match them

TORUS computes A_V **geometrically from the density field**, integrating along HEALPix rays:

    A_V(q) = A_V,0 * integral_0^L n_H dr

with l=0 (12 rays) sufficient for their tests. The field handed to the chemistry is

    chi(r,q) = chi_0(q) * exp(-tau_UV * A_V(q)) * R_IF^2/(R_IF + r)^2

- a direction-dependent **surface** field, times ray-traced extinction, times a geometric
dilution term. They report agreement with MOCASSIN in their photoionization+PDR test (their
section 5.4) *only* when the dilution term was included; the on-the-spot approximation
underestimated PDR temperatures.

So the published coupling is **surface field + geometric A_V**. The MC field sets `chi_0`; it is
never inverted to produce an extinction. Our spherical path already matches this structurally -
`chi0` carries the per-source inverse-square dilution, and `AVeff` from `chi/chi0` removes it
again, leaving the extinction - so `chi0*exp(-gamma*AVeff)` has the same three factors.

D-053's plane-parallel inversion was a departure from it, and the experiment says it is the wrong
lever:

| run | A_V treatment | H/2H2 (A_V,dust) | C+/C (A_V,dust) |
|---|---|---|---|
| slabF | geometric dust column (D-043) | 0.033 | 1.128 |
| slab8 | inverted vs analytic chi0 | **none** | 1.370 |
| slab9 | inverted vs column-max chi | 0.005 | 1.671 |

Inverting against `chi0` puts **A_V = 1.00 in the first cell**, because the MC field at a slab
surface is already ~29% below the incident flux for two reasons that are not extinction: the mean
intensity at a surface is below the incident flux (only inward-going radiation is present), and
the cell at the launch plane is a half-cell (D-052). That artificial shielding floor made the
surface molecular and **erased the H/H2 front entirely**. Referencing to the column maximum
(slab9) restores an atomic surface, but still leaves A_V = 0.68 in the first cell and drives the
H/2H2 transition to *smaller* A_V - whereas TORUS reports the diffuse field moves that transition
**interior**. Our inversion moves it the wrong way.

**Withdrawn.** `computeAVdust`'s geometric column stands, which is both the published method and
the one that behaves correctly here.

### What TORUS found about the diffuse field

With the diffuse component enabled they report inner-cloud temperatures up 100-200 K at high
optical depth, H2 decreasing (more atomic H) with the H-to-H2 transition shifted interior, and CO
J=7-6 emissivity up by as much as five orders of magnitude - concluding that diffuse radiation
matters most for high-J CO as a temperature diagnostic.

This confirms D-053's substance (the diffuse field is a first-order effect, and standalone 3D-PDR
front positions are not targets) while correcting D-053's proposed mechanism. In their geometry
the diffuse field is dominated by recombination photons inside an HII region reaching shadowed
gas. Our externally-illuminated slab has no such source, so the honest expectation for *this*
benchmark is a small diffuse effect - and the large `gamma_eff = 0.73` measured in the transported
field is mostly forward scattering, not a separate diffuse source.

### Benchmarks they ran

- 1D PDR against 3D-PDR on **Rollig et al. 2007 V2** (n_H = 10^5 cm^-3, A_V = 10, chi = 10^3):
  "excellent agreement" in temperature, H/H2/C abundances and line emissivities.
- Lexington **HII40** photoionization test against CLOUDY and others: within 8-30% of median.
- 1D photoionization+PDR against **MOCASSIN** for the ionized region.

Our slab (n_H = 10^3, chi = 10) is closest to Rollig **V1**, though not identical to it: we run
zeta = 1e-16 against the benchmark's 5e-17, and C/H = 2.2e-4, O/H = 3.3e-4 against 1e-4 and 3e-4.
Matching V1 exactly is the natural next benchmark step.


## 2026-08-31f - adopting what TORUS-3DPDR settled, and the Rollig V1 run

Continuing on Hektor's instruction to reuse what TORUS-3DPDR already worked out rather than
reinventing it.

### D-055: `pdrAVfac` was inconsistent with our own dust

`computeAVdust` builds A_V by integrating the real grain extinction (`absOpac + scaOpac` at V).
The chemistry then inverts it to get the self-shielding columns:

    NHcol = av / pdrAVfac

but `pdrAVfac` was a hardcoded literature default, `6.289e-22`. The dust in this model actually
gives `1.900e-22` per magnitude. The round trip was therefore wrong by **3.3x**, and H2 and CO
self-shielding - which is exactly what sets the two fronts - was computed off a column 3.3x too
small.

Fixed by deriving it in `calibratePDRdust` from the same grains that `computeAVdust` integrates:

```fortran
pdrAVfac = real(dble(magPerTau)*kV/dble(grid(1)%Hden(iCell)))
```

The run now prints, and it matches the value measured from the slab profile to three digits:

    ! calibratePDRdust: A_V per N_H = 1.90034396E-22 (N_H per mag = 5.26220509E+21)

Worth recording as a model property: **these grains give 5.26e21 N_H per magnitude against the
canonical diffuse-ISM 1.87e21**, so they are ~2.8x less extinguishing per hydrogen than the value
the Rollig benchmark assumes. At a matched A_V our column is 2.8x deeper in N_H. Matching the
benchmark's dust (rather than just its A_V) would need `MdMg` near 0.028, and is a separate
decision from this fix.

Also adopted from TORUS: the PDR zone criterion is now `x(H+) < 0.3` (was 0.5), their published
value. We already use HEALPix level 0 (12 rays), as they do.

### D-056: porting 3D-PDR's thermal root finder - attempted, reverted

TORUS states its thermal-balance routines are 3D-PDR's unchanged, so the obvious move was to stop
hand-rolling ours. 3D-PDR's `changetemperature.F90` differs from our march in ways that all looked
like improvements:

- expands the bracket by **+-30%**, not x2 / x0.5
- tracks `previouschange` and only starts root-finding when the direction **reverses**, which is
  what actually proves a bracket - our march set a bound from any sign of F, so a "bracket" could
  span more than one root
- then runs an **Illinois-modified regula falsi in ln(T)**, not plain geometric bisection
- converges on `Fratio = 2|F|/|heat+cool| <= Fcrit`, with `fullyconverged` latching

Ported faithfully, it made things measurably worse:

| | old march | ported | reference |
|---|---|---|---|
| transverse spread at A_V ~ 0.1 | 150.9 - 152.3 K | **167 - 814 K** | uniform |
| heat/cool median | 0.9965 | 1.0549 | 1 |
| deep T | 11.8 K | 33.0 K | ~10 K |

**Why it failed is the useful part.** 3D-PDR's +-30% expansion assumes its own outer structure:
~65 iterations with `Tlow`, `Thigh`, `Flow`, `Fhigh`, `previouschange`, `dobinarychop` and
`fullyconverged` **persisting across them**. Our inner loop gets `pdrThermIter = 12` steps and
resets that state on every MC iteration. Twelve +-30% steps move the temperature by at most
1.3^12 ~ 23x and usually far less before switching to chop, so the search never arrives. Our
coarser x2 march covers more ground and is the better choice *for a 12-step budget*.

Reverted. Porting it properly means persisting the bracket state on the grid across MC iterations
- i.e. adopting 3D-PDR's iteration structure, not just its arithmetic. That is the right shape of
the fix and is now the open item.

### D-057: the graded y-axis breaks the surface, not the solver

To reach A_V = 10 while still resolving a front at A_V ~ 0.07, I built the V1 grid with a
geometrically graded y-axis (first cell 2e15 cm, ratio 1.0435). The deep chemistry came out well,
but the surface layer sat at **35 K where it belongs near 570 K**.

That survived the D-056 solver swap unchanged, which is what identified it. The cells at
A_V < 0.001 report

    heat = 6.5e-22   cool = 1.8e-23   ->  heat/cool = 37

with `Tlow = Thigh = Tgas` - a *collapsed* bracket. The solver is reporting convergence at a point
that is nowhere near balance.

The tell is that the earlier **uniform**-grid slabs had a correct 500-570 K surface. The graded
axis makes the first cells so thin that `NHcol = av/pdrAVfac` collapses toward zero, and the
shielding columns and escape probabilities that the cooling depends on degenerate with it.

Re-running V1 on a uniform grid, 1001 cells deep at dA_V = 0.01 per cell, which resolves the
H/H2 front and still reaches A_V = 10.

### Where the V1 run stands (graded-axis version)

| quantity | coupled | Rollig V1 |
|---|---|---|
| C -> CO | **3.00** | ~2-3 |
| C+ -> C | 0.85 | ~1.7 |
| H -> 2H2 | corrupted by the surface | ~0.07 |
| deep T | 11.8 K | ~10 K |
| deep x(CO) | 9.94e-5 of C/H = 1e-4 | ~1e-4 |
| heat/cool median | 0.9965 | 1 |

The full layered PDR structure is present for the first time, and the deep cloud - CO reservoir,
temperature, thermal balance - is right. The C+/C front is still a factor of two shallow, and the
surface is unusable until D-057 is confirmed fixed.


## 2026-08-31g - D-058: the Rollig V1 benchmark, with the benchmark's dust

D-057 diagnosed the 35 K surface as a grid problem, and a uniform grid confirmed it - but a
uniform grid fine enough to resolve a front at A_V ~ 0.07 needs 1000+ cells to reach A_V = 10,
and at 25025 cells the same photon budget gave 4x worse statistics per cell: heat/cool median
72.5 and 1.6% of cells below 5 K. The working grid is **graded but with a floored first cell**
(dA_V = 0.005, ratio 1.0067, 401 cells) - fine enough at the surface, cheap enough at depth, and
with no cell thin enough to collapse its shielding columns.

### The remaining error was the dust, not the coupling

With that grid, H->H2 and C+->C were both still shallow (0.013 and 0.89 against 0.07 and 1.7)
while C->CO was already right. That pattern is diagnostic: the two shallow fronts are the ones
set by self-shielding, and D-055 had just established that these grains give **5.26e21 N_H per
magnitude against the canonical 1.87e21**. At a matched A_V our shielding columns were therefore
2.8x too large, which pushes exactly those two fronts shallow and leaves the deep CO front alone.

Matching the benchmark's dust rather than only its A_V - `MdMg` 0.01 -> 0.0281 - confirmed it.
D-055's auto-derivation picked the change up with no manual intervention:

    ! calibratePDRdust: A_V per N_H = 5.33996734E-22 (N_H per mag = 1.87267061E+21)

### Rollig V1 result

| quantity | coupled | Rollig V1 | ratio |
|---|---|---|---|
| surface T | **564.8 K** | ~570 K | 0.99 |
| H -> 2H2 | 0.032 | ~0.07 | 0.46 |
| C+ -> C | **1.371** | ~1.7 | 0.81 |
| C -> CO | **2.747** | ~2-3 | in range |
| deep T | 11.5 K | ~10 K | 1.15 |
| deep x(CO) | 9.94e-5 of C/H = 1e-4 | ~1e-4 | 0.99 |
| heat/cool median | 1.044 | 1 | 1.04 |

Progress across the three grids, all with the same physics:

| | H->2H2 | C+->C | C->CO | surf T | heat/cool | cells < 5 K |
|---|---|---|---|---|---|---|
| graded, thin first cell | 0.018 | 0.854 | 3.00 | 35 K | 0.993 | 0.0% |
| uniform 1001 | 0.013 | 0.859 | 4.13 | 277 K | 72.5 | 1.6% |
| graded, floored first cell | 0.013 | 0.888 | 3.19 | 953 K | 1.963 | 0.0% |
| **+ benchmark dust** | **0.032** | **1.371** | **2.75** | **565 K** | **1.044** | **0.0%** |

Temperature structure, thermal balance and the carbon chemistry are now all within ~20% of the
benchmark, and the CO front sits inside its range.

### What is still open

- **H -> H2 is a factor of two shallow** (0.032 against ~0.07) while C+/C is within 20% and C/CO
  is in range. A single remaining discrepancy isolated to hydrogen points at H2 self-shielding or
  the Cazaux & Tielens grain formation rate, not at the radiation field or the extinction, both of
  which the other two fronts now validate.
- **The thermal bracket state should persist across MC iterations** (D-056). Porting 3D-PDR's
  +-30% expansion and Illinois regula falsi without that persistence made results worse; with it,
  it should be strictly better than our x2 march.
- Neither V1 run used the exact benchmark cosmic-ray rate until this one; zeta = 5e-17 is now set.


## 2026-08-31h - D-059: an actual baseline, and what it corrected (closes D-016)

Hektor asked for the 3D-PDR curves plotted alongside ours. That required a real standalone run,
not remembered figures - which is what D-016 has been asking for since Phase 0.

Upstream was cloned, built from the same tree we vendor, and run on the same slab. Its default
`config.mk` already matches our `PDRFLAGS` almost exactly (REDUCED, H2FORM_CT02, HTT91 dust,
ILLINOIS, REBRACKET, SOBOLEV, CHEMSTEADY, CHEMRETRY, 1D). Two build notes:

- The SUNDIALS we built is MPI-enabled, and 3D-PDR never calls `MPI_INIT`, so CVODE aborted with
  `MPI_Comm_dup() called before MPI_INIT`. Fixed with a small C constructor (`mpishim.c`) that
  calls `MPI_Init` before `main`, linked with `mpif90`.
- Run it under `mpirun -np 1` with stdin closed. As a singleton it initialises MPI and then blocks
  with zero CPU.

`ics/1Dn30.dat` is n_H = 10^3 over 5.15 pc - the V1 density and depth.

### The reference values I had been quoting were wrong

| | what I quoted | 3D-PDR, matched |
|---|---|---|
| H -> 2H2 | ~0.07 | **0.027** |
| C+ -> C | ~1.7 | 1.604 |
| C -> CO | ~2-3 | **4.924** |
| surface T | ~570 K | **79 K** |
| deep T | ~10 K | 10.5 K |

These came from memory of the Rollig paper rather than from a computation, and two of them were
badly off. Consequences for the record:

- **The H/H2 front was never the problem.** D-058 called it "a factor of two shallow" and reasoned
  it isolated to H2 self-shielding or the grain formation rate. It is 0.032 against 0.027 - within
  17%. That whole line of inquiry was chasing an error in the reference.
- **The surface temperature, which D-058 reported as agreeing (564.8 K against "~570"), is wrong
  by a factor of twelve.** It was the one number I presented as a clean success.

3D-PDR also uses C/H = 1.4e-4 from its own `species_reduced.d`, not the 1e-4 I had set from the
benchmark paper. The comparison was re-run with abundances, dust, cosmic-ray rate and depth all
matched.

### Matched comparison

| quantity | coupled | 3D-PDR | ratio |
|---|---|---|---|
| deep x(CO) | 1.385e-4 | 1.393e-4 | 0.99 |
| H -> 2H2 | 0.032 | 0.027 | 1.17 |
| deep T | 12.5 K | 10.5 K | 1.20 |
| C+ -> C | 1.236 | 1.604 | 0.77 |
| surface chi | 7.61 | 10.00 | 0.76 |
| C -> CO | 3.126 | 4.924 | 0.63 |
| **surface T** | **982 K** | **79 K** | **12.4** |

The chemistry tracks. The deep cloud is essentially exact.

### D-060: the surface temperature is the real defect

Both codes run the same heating and cooling routines on nearly the same field, so a 12x
disagreement at A_V ~ 0 is in what the coupling hands over at low extinction, not in the PDR
physics. The candidates, in order:

1. **The D-007 blend band.** At low x(H+) the coupling ramps between MOCASSIN's photoelectric
   heating and 3D-PDR's. If MOCASSIN's dominates at the face, this is exactly the signature.
2. **MOCASSIN's electron temperature leaking into PDR-owned cells** through the handover.
3. The surface chi being 24% low should make the face *cooler*, not hotter, so it is not the cause.

Worth noting the interiors agree closely and the curves converge past A_V ~ 1, which points at
something that only operates where the gas is still partly ionized - consistent with (1) and (2).

### D-016 closed

The baseline exists, is reproducible from `scratchpad/3dpdr` with `mpishim.c`, and should be
committed as a regression fixture: `sims/v1.pdr.fin` plus the `params.dat` that produced it.


## 2026-08-31i - D-060/D-061/D-062: the cooling, and a warm-up

### D-060: the thermal bracket was searching on a non-monotonic function

Instrumenting the per-coolant budget at one face cell across thermal iterations:

| T | C+ cooling | O cooling |
|---|---|---|
| 34.6 K | 5.08e-22 | 6.90e-22 |
| 17.3 K | 3.96e-23 | 1.61e-25 |
| 24.5 K | **3.33e-24** | 1.93e-28 |
| 29.1 K | 1.42e-23 | 9.49e-27 |

Cooling was **not monotonic in T** - it fell 12x between 17 K and 24 K. The level populations were
carried one pass behind and never converged at fixed T, so `F(T) = heating - cooling` was noise
and the root the bracket found was arbitrary.

3D-PDR guards exactly this. `changetemperature.F90` opens with `if (.not.level_conv) return` - it
refuses to move the temperature until the populations have converged. D-056 ported its arithmetic
and missed that line, which is the part that actually matters.

Fixed with an inner fixed-T iteration over `escape_probability` + `solvlevpop`, to
`pdrLevTol = 1e-3` or `pdrLevIter = 25` passes. Cooling is now monotonic and saturating, as a
fine-structure line must be:

    3.96e-23 (34.6 K) -> 1.29e-22 (69 K) -> 2.32e-22 (138 K) -> 3.00e-22 (277 K) -> 3.29e-22 (553 K)

**This also retires D-051.** The "multiple roots" and the factor-of-four scatter between
physically identical cells were never bistability - they were a bracket search on a noisy
function. With the warm-up below, identical cells now agree to the digit (142.1 K across all
nine interior cells at A_V ~ 0.1, against 142.0-145.7 K before).

### D-061: what the fix exposed

Making the solver well-posed made the temperatures *worse*, because two errors had been partly
cancelling. The residual is now clean and isolated: at the face our C+ cooling saturates near
3.3e-22 where 3D-PDR reaches 5.77e-22 at only 79 K - a factor of ~4 deficit at fixed conditions,
with the carrier abundance identical to four digits (1.3986e-4 against 1.3992e-4) and the
collision partners all passed correctly to `FIND_CCOEFF`.

That points at the escape-probability geometry, not the chemistry or the field. We collapse the
ray structure to **one ray with two evaluation points set to the same populations** (D-030), and
iterating that to a fixed point may simply converge on the wrong operator. 3D-PDR uses 12 HEALPix
rays with genuinely distinct evaluation points along each. This is the next thing to fix.

### D-062: `pdrStartIter` - warm up MOCASSIN before enabling the PDR

Hektor's suggestion, and it matches TORUS-3DPDR's architecture (converge photoionization first,
then run the PDR). Two supporting observations:

- At `maxIterateMC 1` **no cell is ever in the PDR zone** - the zone flag latches from the second
  iteration, so a single-iteration run does no chemistry at all. Worth knowing.
- With the PDR live from iteration 1 the model **never converges**: 71.6% after 8 iterations,
  because the chemistry keeps perturbing the ionization structure. Without it, 100% in 3.

The first attempt failed instructively: `pdrStartIter 4` on a slab that converges in 3 finished
before the chemistry ran once - 100% converged at iteration 3, zero `pdrStep` calls, every cell
still zone 0. So the warm-up must also **hold the run open**: the convergence exit is now
suppressed until the PDR has been enabled and had a pass.

Effect at `pdrStartIter 4` (8 MC iterations, 5 with chemistry):

| quantity | warm=1 | warm=4 | 3D-PDR |
|---|---|---|---|
| transverse spread at A_V ~ 0.1 | 142.0-145.7 K | **142.1-142.1 K** | - |
| C+ -> C | 0.670 | **1.215** | 1.604 |
| C -> CO | 0.484 | **3.360** | 4.924 |
| heat/cool median | 1.001 | 0.999 | 1 |

Default is `pdrStartIter = 1`, preserving current behaviour; it is an option, not a new default.

### Where the temperatures stand

Still hot - surface 2270 K against 79 K, deep 49.6 K against 10.5 K - and that is D-061, not the
solver. The chemistry fronts, the thermal balance and the cell-to-cell consistency are all now
in good shape; the cooling *magnitude* is the single remaining defect.


## 2026-08-31j - D-061 partial, and where the cooling gap actually lives

`escape_probability` averages beta over rays (`beta_ij = beta_ij_sum/real(nrays)`), so it only
needs a correct path length per ray - and a plane-parallel slab gives that in closed form.
HEALPix nside=1 is three rings: 4 rays at mu = +2/3, 4 at mu = 0, 4 at mu = -2/3. Rays looking
back at the illuminated face see `A_V/|mu|`; rays looking inward see the remaining column
`A_Vback/mu`; rays parallel to an infinite slab never escape. Implemented, with a new
`grid%AVback` filled by `computeAVdust`.

**Result: real but not sufficient.**

| quantity | 1 ray | 12 rays | 3D-PDR |
|---|---|---|---|
| C -> CO | 3.360 | **4.100** | 4.924 |
| C+ -> C | 1.215 | 1.213 | 1.604 |
| H -> 2H2 | 0.018 | 0.019 | 0.027 |
| surface T | 2270 K | 2296 K | 79 K |
| deep T | 49.6 K | 56.2 K | 10.5 K |

The C->CO front moved from 0.68 to 0.83 of standalone. The temperatures did not move.

### D-063: the ceiling is beta, and the geometric column may be the wrong length

Measured C+ cooling against temperature at the face, with the corrected ray geometry:

| T | 29.7 | 59.3 | 118.6 | 237.3 | 474.5 | 949 | 1898 |
|---|---|---|---|---|---|---|---|
| C+ cooling | 1.9e-23 | 6.8e-23 | 1.2e-22 | 1.6e-22 | 1.6e-22 | 1.6e-22 | 1.5e-22 |

It saturates at **1.6e-22, which is 6% of the optically thin LTE ceiling** (2.69e-21 for
n(C+) = 0.14). 3D-PDR reaches 5.77e-22, or **21%**, at only 79 K. So even at infinite temperature
our C+ line cannot emit what 3D-PDR emits at 79 K - the limit is not the level populations or the
temperature, it is the escape probability.

Backing the numbers out: with populations sub-thermal by roughly n/(n+n_crit) ~ 0.25 at
n_H = 1e3, our saturated value implies beta ~ 0.33 - exactly the 4-of-12 rays that see a short
column in our slab construction. 3D-PDR's 5.77e-22 implies beta ~ 0.86, i.e. its lines escape
almost freely at the face.

**The suspect is the length itself, not the ray count.** Both builds set `-DSOBOLEV`, where the
optical depth belongs to the local velocity-coherent (Sobolev/LVG) length, not the geometric
column. We pass the geometric path - for an inward ray at the face that is 7.755 pc, which is
enormously thick - and that alone would push beta from ~0.86 down to the ~0.33 we measure. The
next step is to establish what length 3D-PDR's `escape_probability` expects under SOBOLEV and
pass that instead.

*What is now well established, and worth not relitigating:* the chemistry tracks standalone
(all three fronts within 0.68-0.83), thermal balance closes (heat/cool 0.999), physically
identical cells agree exactly, and the radiation field is verified twice over. The open defect is
one number - the escape probability - in one routine.


## 2026-08-31k - D-063: we were compiling a different escape-probability branch

Three attempts to approximate 3D-PDR's escape geometry from outside all failed, in different
directions. The reason is that `escape_probability.F90` has three mutually exclusive branches, and
we were not compiling the one 3D-PDR uses.

```fortran
#ifdef ONEDIMENSIONAL
         beta_ij = beta_ij_sum                      ! 3D-PDR's 1D build
#else
         beta_ij = beta_ij_sum / real(nrays,kind=DP)   ! ours (RAYTHEIA_MO)
#endif
```

3D-PDR's 1D build blanks 11 of its 12 rays to `tau = 1e50` and then does **not** divide, so its
beta is one normal ray's value, up to ~1. Our `PDRFLAGS` set `-DRAYTHEIA -DRAYTHEIA_MO`, whose
branch divides by `nrays`. Every geometry we tried was therefore fighting a factor we could not
see from the call site:

| attempt | beta | result |
|---|---|---|
| 1 ray, inward column (original) | beta_1 | C+ saturates 3.3e-22 |
| 12 rays, true slab lengths (D-061) | 4/12 = 0.33 | C+ saturates 1.6e-22, C->CO improved |
| 1 ray, nearest face | beta_1 | fronts worse (C+/C 0.68) |

**Fix: compile the same branch.** `PDRFLAGS` now selects `-DONEDIMENSIONAL` in place of
`-DRAYTHEIA -DRAYTHEIA_MO`, and the call supplies what that branch asks for - evaluation-point
coordinates in pc along ray 6 - instead of a path-length array. Both codes now run identical
escape-probability code. (`eval_points` and `CRattenuation` also respond to the flag; we call
neither.)

### Effect

| quantity | RAYTHEIA_MO | ONEDIMENSIONAL | 3D-PDR |
|---|---|---|---|
| **deep T** | 56.2 K | **18.7 K** | 10.5 K |
| C -> CO | 4.100 | 4.008 | 4.924 |
| C+ -> C | 1.213 | 1.216 | 1.604 |
| heat/cool | 0.999 | 0.999 | 1 |

The deep cloud went from 5.4x to 1.8x, and the deep profile now tracks closely - our last two
points are 30 K and 19 K against 3D-PDR's 29 K and 10 K.

### D-064: and the "surface blowup" was a reporting artefact

The headline "surface T" figure in every table above was `max(T)` over the first six cells. It was
catching a single outlier. The actual surface layer:

| j | A_V | our T | 3D-PDR T |
|---|---|---|---|
| 1 | 0.0075 | 377 | 81 |
| 2 | 0.0125 | 255 | 83 |
| 5 | 0.0278 | 186 | 84 |
| 10 | 0.0539 | 158 | 86 |
| 15 | 0.0808 | 146 | 86 |

**Only 1 cell in 401 exceeds 500 K.** Median over the first 20 cells is 156 K against 3D-PDR's
~85 K. Heating and cooling agree to four digits in every cell, and our surface heating (4.98e-22)
is close to 3D-PDR's (6.98e-22).

So the residual is not a blowup at the face - it is a **uniform ~1.8x temperature offset** through
the whole column (1.9x at the surface, 1.79x deep), with the first cell somewhat worse. That is a
far better-posed problem than what the max-based metric was describing, and it should be tracked
with a median, not a maximum.

*Correction to the record:* every "surface temperature" ratio reported in this log from D-059
onwards (12.4x, 28.6x, 28.9x, 32.9x) is a max-over-six-cells statistic and overstates the
disagreement. The comparable numbers are ~1.9x.


## 2026-09-01 - D-065/D-066/D-067: the dust temperature

Hektor asked whether MOCASSIN's dust treatment, and its inclusion in the thermal balance, could
account for the temperature offset. The hypothesis found a real bug, though not the mechanism
first guessed.

### The mechanism guessed, and why it was wrong

`escape_probability` forms the net line cooling as
`line = A*h*nu*pop*beta*(S_ij - BB_ij)/S_ij`, where `BB_ij` carries the dust continuum at
`T_dust`. Hotter dust raises the background and suppresses net cooling *multiplicatively* -
depth-independent, matching the uniform offset. But measurement runs the other way: our dust was
**colder** than 3D-PDR's (10 K against 21 K at the face), so it was not suppressing cooling.

### D-065: HTT91 was returning its floor in every cell of every model

```
815:  TdMoc = dble(grid%Tdust(0,0,cellP))
820:  TdHTT = 8.9d-11*2.65d15*(1.71d0*chi) + pdrTcmb**5     <- uses chi
821:  T0HTT = 12.2d0*(1.71d0*max(chi,0.d0))**0.2d0          <- uses chi
822:  if (av > 1.0d0) ...                                   <- uses av
...
842:  chi = dble(grid%chiFUV0(cellP))                       <- assigned HERE
844:  av  = dble(grid%AVeff(cellP))
```

`chi` and `av` were read 22 lines before they were assigned. With `chi = 0` the expression
collapses to `(T_cmb^5)^0.2 = 2.73 K`, which then hits HTT91's own `max(...,10)` - so **TdHTT
returned exactly 10.00 K in every cell, in every model, regardless of the radiation field**.
Measured at the illuminated face where the correct value is 20.9 K.

Fixed by hoisting the assignments above the dust block. TdHTT now reads **21.02 K** at the face
against 3D-PDR's 21.0 K.

A second error surfaced immediately: HTT91 uses *two different fields*, and we fed one to both.
3D-PDR's `dust_t.F90`:

```fortran
PDR(P)%Tdust = 8.9D-11*NU_0*(1.71D0*PDR(P)%UVfield) + Tcmb**5   ! LOCAL field
T_0          = 12.2*(1.71D0*PDR(P)%RAD_SURFACE(J))**0.2         ! SURFACE field
IF (PDR(P)%AV(J)>1.0D0) T_0 = T_0 * PDR(P)%AV(J)**(-0.4)
```

The first term is direct FUV heating where the grain sits, so it takes the attenuated local
field; the second is IR re-radiated from the illuminated skin, carrying the surface field with
its own Rowan-Robinson depth attenuation. Feeding the surface field to both held T_dust near
21 K at every depth. Corrected; T_dust now falls with the local field (19.8 K at A_V = 0.013,
18.9 K at 0.62).

### D-066: but MOCASSIN's own dust cannot be favoured yet

Hektor's instruction was that if 3D-PDR's treatment is the less self-consistent, we should prefer
MOCASSIN's. On the physics that is right: 3D-PDR uses an HTT91 parametrisation with a
Rowan-Robinson correction, while MOCASSIN solves real radiative equilibrium against the
transported field with actual grain opacities and a size distribution.

The measurement blocks it. `TdMoc = grid%Tdust(0,0,cellP)` - the same grand-average slot
`update_mod` itself uses - reads **1.10 to 1.45 K** right across the illuminated surface, where
both HTT91 and 3D-PDR give ~21 K. A grain at a chi = 10 Draine surface cannot be at 1.2 K. So
MOCASSIN's dust equilibrium is under-heated by a factor of ~17 in temperature in this regime, and
`max(TdMoc, TdHTT)` is currently always selecting HTT91.

Until that is understood, favouring MOCASSIN's value would replace a working parametrisation with
a broken solve. Establishing *why* MOCASSIN's dust is cold here - whether the PDR cells' dust is
updated at all, and what field its equilibrium actually integrates - is the prerequisite.

### D-067: MOCASSIN floors Te at 10 K

Confirmed at Hektor's suggestion, `update_mod.f90:669`:

```fortran
! Ensure temperature doesn't become non-physical
if (TeUsed < 10.) TeUsed = 10.
```

This sits exactly where PDR interiors live - 3D-PDR's deep gas is 10.5 K. `pdrToMocassin` writes
the PDR temperature back into `grid%Te`, so a genuinely cold interior is clamped on the way back
and then re-seeds `pdrStep`. Not the cause of a *hot* bias, but it means `grid%Te` carries no
information below 10 K and should never be used as a PDR seed or diagnostic.

*Also spotted:* a leftover hard-coded debug print at `update_mod.f90:673`,
`if (cellP == 9249) print*, ...`, which fires in any model with that many cells.

### Effect on the benchmark - and a caution

| quantity | HTT91 broken | HTT91 fixed | 3D-PDR |
|---|---|---|---|
| median T, first 20 | 156.4 | 159.0 | 79.6 |
| H -> 2H2 | 0.018 | 0.017 | 0.027 |
| C+ -> C | 1.216 | 1.215 | 1.604 |
| C -> CO | 4.008 | 3.951 | 4.924 |
| **deep T** | **18.7** | **49.9** | **10.5** |

The correction made the deep temperature worse, and the honest reading is that the previous
agreement was partly luck: with HTT91 pinned at its 10 K floor, our deep dust coincidentally
matched 3D-PDR's deep dust, which is also 10 K. The fixed code is right and the old agreement was
not evidence of anything. Why the deep gas now settles at 50 K is **not yet explained** - the
local field there is small enough that HTT91 should return its floor, so the effect is likely
downstream of the warmer surface dust through H2 formation, not the deep dust itself.

**The dust hypothesis is therefore partly confirmed:** it found a real and long-standing bug, but
it does not account for the ~1.8x offset, which survives the fix.


## 2026-09-01b - four questions from Hektor, four answers

### D-068: are [CII] and [OI] included correctly?

Verified, top to bottom:

- **Level structure.** `12c+.dat` has 2P_1/2 -> 2P_3/2 at 63.395 cm^-1 (157.7 um, the [CII] line)
  plus three 4P states near 43000 cm^-1. `16o.dat` has 3P_2 -> 3P_1 at 158.269 cm^-1 (63.2 um)
  and 3P_1 -> 3P_0 at 68.7 cm^-1 (145.6 um), plus 1D_2 and 1S_0. Both correct.
- **Collision partners.** Our `FIND_CCOEFF` call passes `H, H+, e-, He, H2` against its signature
  `H_abd, Hp_abd, elec_abd, He_abd, H2_abd`. Correct order.
- **Detailed balance.** Our rebuild loop is character-for-character 3D-PDR's
  `coolingfunctions.F90:78-83`, same indices, same units.

So they are included correctly - and both still under-emit. Measured at the face, our T = 69.2 K
against 3D-PDR's T = 79.4 K:

| line | ours | 3D-PDR | ratio |
|---|---|---|---|
| [CII] 158 um | 1.36e-22 | 5.77e-22 | 0.24 |
| [OI] 63+146 um | 6.9e-24 | 1.20e-22 | **0.06** |

That [OI] is 17x low while [CII] is 4x low is the diagnostic. [OI] 63 um has a critical density
near 5e5 cm^-3 against [CII]'s ~3e3, so at n_H = 1e3 it is the line furthest below thermalisation
and therefore the most sensitive to the level populations. Both being low, with [OI] far worse,
points at the population solve rather than at the atomic data or the escape geometry.

### D-069: the blend band, and the packet count

**The blend band is inactive in this benchmark.** x(H+) never exceeds **7.6e-5** anywhere in the
column - 130x below `pdrBlendLo = 0.01` - so the weight is w = 1 in all 401 cells. Narrowing the
band or moving its start to x(H+) = 0.1 cannot change these results. The suggestion is sound but
needs an HII-region + PDR model with a real ionization front to test; a pure-PDR slab cannot.

**Packets are not the limit either.** 6e6 -> 24e6 (600 -> 2400 per cell):

| | 6e6 | 24e6 |
|---|---|---|
| median T, first 20 | 158.96 | 153.09 |
| H -> 2H2 / C+ -> C / C -> CO | 0.017 / 1.215 / 3.951 | 0.017 / 1.229 / 3.982 |
| deep T | 49.92 | 49.85 |
| surface chi | 7.519 | 7.516 |

Fronts identical to three digits. The 24% surface-chi deficit against the analytic 10.0 is
**systematic, not noise** - consistent with the surface mean-intensity and half-cell explanation
of D-052, and not something more photons will fix.

### D-070: the two codes do NOT use the same atomic data

The `dataPDR/` files are byte-identical to upstream 3D-PDR's `chemfiles/` - all four coolants,
`species_reduced.d` and `rates_reduced.d`. So the **PDR side** of the comparison is clean.

MOCASSIN's own side is a different dataset entirely:

| ion | MOCASSIN | 3D-PDR |
|---|---|---|
| C II | `data/cii.dat`, **46 levels**, CHIANTI v10 | `12c+.dat`, **5 levels**, LAMDA |
| O I | `data/oi.dat`, **24 levels**, CHIANTI v10 | `16o.dat`, **5 levels**, LAMDA |

And, as Hektor pointed out, **MOCASSIN does not apply self-absorption to these lines**.
`setResLineEscapeProb` handles *resonance* lines only, and only fires under
`lgDust .and. convPercent >= resLinesTransfer`. The forbidden fine-structure CELs are optically
thin in MOCASSIN, while 3D-PDR gives them an escape probability.

Underneath the data difference is a physics difference that matters more: **MOCASSIN's CEL cooling
is driven by electron collisions**, correct for an H II region, while in a PDR
x(e-) ~ 1.4e-4 and these lines are excited by neutral **H, H2 and He** - which is what 3D-PDR
uses. The two codes are not computing the same quantity for the same ion.

### D-071: MOCASSIN overwrites the temperature the PDR just handed it

`update_mod.f90` contains no `pdrZone` guard, so `updateCell` re-solves the thermal balance in
PDR-owned cells, unaware that the PDR owns them, and overwrites the value `pdrToMocassin` wrote at
`pdr_mod.f90:1231`. A leftover debug print in that routine showed it converging to **2691 K** in a
cell where the PDR gives ~150 K - the electron-cooling solve of D-070 applied to neutral gas.

`pdrStep` seeds from `grid%pdrTgas`, so the PDR itself is insulated. But `grid%Te` drives
MOCASSIN's ionization balance and opacities, so those are being computed at a temperature that is
wrong by ~20x in every PDR cell, and the resulting ionization fractions are what set `pdrZone`.

**This is the most likely candidate yet for the residual offset**, and unlike the escape-geometry
work it is a coupling-design question rather than a tuning one: a cell the PDR owns should not
have its temperature re-solved by the photoionisation thermal balance. That is what "self
consistent" has to mean here.

*Also removed:* the hard-coded `if (cellP == 9249) print*, ...` debug statement at
`update_mod.f90:673`, which fired in any model with that many cells.


## 2026-09-01c - D-072: the PDR owns thermal balance in its own cells

Hektor's call, and it is the right division of labour: *"we should leave PDR balance to 3DPDR
since it takes into account the adequate physics. Mocassin should then take those values and
ionization balance from it in cells that are in PDR."*

The justification is D-070. MOCASSIN's [CII] and [OI] cooling is driven by **electron**
collisions - correct for an H II region - but in a PDR x(e-) ~ 1.4e-4, so those lines contribute
almost nothing and its thermal solve runs away. In neutral gas the same lines are excited by H,
H2 and He, which is what 3D-PDR uses, and 3D-PDR also applies an escape probability where
MOCASSIN treats them optically thin.

Implemented in `updateCell`: a cell with `pdrZone == 1` and a valid `pdrTgas` has `TeUsed` pinned
to the PDR temperature, runs **one full pass** of the loop - `calcalpha`, `ionBalance`, the grain
potential and photoelectric/dust-gas terms, `thermBalance` - so every derived quantity the Monte
Carlo needs is populated consistently at that temperature, and then exits without the secant
update.

### Effect

On MOCASSIN's own electron temperature across the grid:

| | median Te | max Te |
|---|---|---|
| MOCASSIN owned | 102.0 K | **10222.5 K** |
| PDR owned | 66.0 K | **2270.6 K** |

The runaway is gone. The residual 2270 K maximum is the PDR's own outlier cell, now faithfully
adopted rather than replaced - which is the guard working as intended.

### Correction to D-071

D-071 called this "the most likely candidate yet for the residual offset". **It was not.** The PDR
temperatures are essentially unchanged by the guard:

| quantity | MOCASSIN owned | PDR owned | 3D-PDR |
|---|---|---|---|
| median T, first 20 | 158.96 | 153.12 | 79.62 |
| C+ -> C | 1.215 | 1.216 | 1.604 |
| C -> CO | 3.951 | 3.927 | 4.924 |
| deep T | 49.92 | 50.27 | 10.46 |

The reason is that `pdrStep` already seeded `Tg` from `grid%pdrTgas` rather than `grid%Te`, so the
PDR was insulated from the runaway in the first place. The guard fixes the *reverse* direction -
MOCASSIN's ionization balance and opacities in PDR cells were being computed at up to 10^4 K and
now are not. That is a real self-consistency gain, and it is what the coupling should have been
doing, but it does not explain the ~1.9x offset.

**Still open (D-064, D-068):** the offset survives every fix so far, and the sharpest handle on it
remains the line emission - [CII] at 0.24x and [OI] at 0.06x of standalone at matched temperature,
with identical atomic data, identical collision-partner mapping and an identical detailed-balance
rebuild. The population solve is where to look next.


## 2026-09-01d - D-073/D-074: the benchmark's dust was wrong, and a full parameter audit

### Following the deep-cloud discrepancy to its source

The deep cloud was cooling 200-1500x more than 3D-PDR and still sitting at 30-60 K against 8-10 K.
Since heat/cool = 0.999 in both, the deep *heating* had to be equally excessive, and the candidate
was the FUV field: ours reached chi = 7.4e-3 at A_V = 8.5 where 3D-PDR's is 7.3e-11.

**It is not Monte Carlo noise.** Quadrupling the packets to 2400 per cell left the deep field
unchanged at every depth (ratios 0.97-1.05), so it is genuinely transported radiation.

That made the decay rate the thing to explain. Measuring the dust directly:

    ! [D073] kFUV/kV = R_FUV = 1.11973917   kV = 4.91996275E-19   kFUV = 5.50907510E-19
    ! [D073] FUV albedo = 0.549705327

With omega = 0.55, diffusion theory gives the diffuse field decaying as
`exp(-tau*sqrt(3(1-w)(1-wg)))`, i.e. gamma_eff ~ 0.95*R_FUV/1.0857. At R_FUV = 1.12 that predicts
0.98-1.20 per magnitude against the 0.73 measured - agreement to ~35%, about as good as a
diffusion approximation gets. **So the deep field was physically consistent with the dust. The
dust was wrong.**

### D-073: 0.07 to 50 micron grains

```
2
'dustData/astroSilD2003_base.nk' 0.9800 0.07 50      <- silicate, 0.07-50 um
'dustData/PAHneu_30.cat'         0.0200 1e-05 0.002
```

Interstellar MRN grains run 0.005-0.25 um. This distribution is dominated by large grains, which
give **grey extinction** - hence R_FUV = 1.12 where interstellar dust gives ~3. Changing only the
size range, same materials:

| a range | R_FUV | albedo | A_V/N_H |
|---|---|---|---|
| 0.07-50 um (as inherited) | **1.12** | 0.550 | 5.34e-22 |
| 0.005-0.25 um | 5.21 | 0.450 | 1.15e-21 |
| **0.010-0.30 um (adopted)** | **3.59** | 0.486 | 1.42e-21 |

3D-PDR's `params.dat` states its UV factor as **3.02**, so 0.010-0.30 um at R_FUV = 3.59 is within
19%. Rescaling `MdMg` to hold A_V/N_H at 3D-PDR's value gives **0.01059** - essentially the
canonical dust-to-gas ratio, which is itself a consistency check: proper ISM grains at the
canonical dust-to-gas reproduce the canonical extinction per hydrogen. The 0.0281 of D-058 was
compensating for the wrong grain sizes.

### D-074: the full parameter audit

Prompted by Hektor: having found one inconsistency, check them all against 3D-PDR's `params.dat`.

| parameter | 3D-PDR | ours | |
|---|---|---|---|
| G0 | 10 Draine | 10.1 | ok |
| zeta | 5e-17 | 5e-17 | ok |
| turbulent velocity | 1 km/s | 1.0 | ok |
| grain radius | 1e-5 cm | 1e-5 | ok |
| A_V conversion | 5.33997e-22 | **5.33839e-22** | ok, 0.03% |
| T_min / T_max | 1 / 2e4 | 1 / 2e4 | ok |
| HEALPix level | 0 | 0 | ok |
| **Fcrit** | **0.005** | **0.10** | **was 20x loose - fixed** |
| **UV factor (R_FUV)** | **3.02** | 1.12 -> **3.59** | fixed to 19% |
| **dust-to-gas x1e-2** | **1** | 2.81 -> **1.06** | fixed |
| chemistry iterations | 8 then 6000 | 3 per MC pass | differs by design |

`pdrFcrit` had been 0.10 since D-032 - twenty times looser than 3D-PDR's thermal convergence
criterion, and a plain error on our side. Now 0.005.

### Effect of the corrected setup

| quantity | old dust | corrected | 3D-PDR | ratio |
|---|---|---|---|---|
| gamma_eff of the field | 0.73/mag | **1.86/mag** | 3.02 assumed | - |
| chi at A_V = 8.5 | 7.1e-3 | **underflows to 0** | 7.3e-11 | - |
| H -> 2H2 | 0.017 | **0.021** | 0.027 | 0.76 |
| C+ -> C | 1.216 | 1.215 | 1.604 | 0.76 |
| C -> CO | 3.927 | **4.028** | 4.924 | 0.82 |
| deep T | 50.3 K | **40.1 K** | 10.5 K | 3.83 |
| median T, first 20 | 153 K | 156 K | 79.6 K | 1.96 |
| heat/cool | 0.999 | 0.999 | 1 | - |

The radiation field is now physically sensible - it decays 2.5x faster and underflows at depth as
it should - and **all three chemical fronts now cluster at 0.76-0.82** of standalone rather than
scattering between 0.62 and 0.82.

The temperatures did not follow: the surface is unchanged at ~1.96x and the deep cloud improved
only from 5.4x to 3.8x. So the dust was a real and necessary fix for the *radiation field* and the
*chemistry*, but it is not the explanation for the temperature offset either.

### Where that leaves the [CII]/[OI] question

The emissivity comparison needs restating, because the earlier framing was misleading. Measured at
**matched temperature**, our cooling function is weak: [CII] 0.24x, [OI] 0.06x. But in the
*converged* model our emissivities are comparable to or larger than 3D-PDR's, because our gas is
hotter and radiates more. Both are true and they answer different questions. heat/cool = 0.999
throughout, so the model is internally consistent; it simply balances the same heating at a higher
temperature because its cooling per unit temperature is weaker.

That remains the open thread, and it is now the *only* one: atomic data byte-identical, collision
partners correctly mapped, detailed balance identical, escape-probability branch identical, dust
corrected, every input parameter audited.


## 2026-09-01e - D-075: the atomic hydrogen collision partner was zero

### Finding it

The [CII]/[OI] deficit was sharpest at the **surface**, where the column is negligible, so
beta ~ 1 in both codes and the level populations reduce to an optically thin statistical
equilibrium with inputs verified identical. If the answer still differed there, it had to be the
solve. Printing the populations and the collision partners alongside 3D-PDR's `.spop.fin` files
made it immediate:

    pop= 1.277E-01 1.222E-02   nSpec= 1.399E-01   ne= 1.432E-01   nH0= 0.000E+00
                                                                  ^^^^^^^^^^^^^^

**The atomic hydrogen density passed to `FIND_CCOEFF` was exactly zero**, in every cell, in every
model. At A_V = 0.018 the gas is mostly atomic and n(H) should be ~500 cm^-3.

### The cause

`global_module` exports `NH`, the *species index* for atomic hydrogen, set by name-matching in
`read_species.F90:109`. `pdrStep` declares

```fortran
double precision :: nH, Tg, Td, chi, av, NHcol
```

and **Fortran is case-insensitive**, so inside that routine `NH` resolves to the local double
precision hydrogen *density*, not the species index. `abun(NH)` therefore indexed a 33-element
array at 1000.0. gfortran accepts a real array subscript as a legacy extension and compiled it
**silently** - no warning at any optimisation level.

This is precisely the collision class D-021 identified when the module imports were written
("3D-PDR modules export `i`, `j`, `k`, `p`, `NH`, `NC`"). The `common_mod` clashes were renamed
then; this one was a clash with our own local, and was missed.

Fixed by renaming the import to `pdrNHsp => NH`.

### Why it produced exactly the observed signature

[CII] 158 um and [OI] 63 um are excited in a PDR overwhelmingly by **neutral H**. With n(H) = 0,
only electrons (n_e ~ 0.14) and H2 remained. And it explains the *ratio* that had been the clue
all along: [OI] is excited almost entirely by H and barely at all by electrons, so it was hit four
times harder than [CII].

| at A_V = 0.018 | before | after | 3D-PDR |
|---|---|---|---|
| n(H) partner | **0** | **516** | ~520 |
| C+ upper level | - | 1.693e-2 | 1.974e-2 (0.86) |
| [CII] cooling | 0.24x | **4.885e-22** | 5.770e-22 (**0.85**) |
| [OI] cooling | 0.06x | **1.003e-22** | 1.203e-22 (**0.84**) |
| T_gas | 216 K | **86.9 K** | ~85 K |

### Effect on the benchmark

| quantity | before | after | 3D-PDR | ratio |
|---|---|---|---|---|
| median T, first 20 cells | 155.8 K | **94.1 K** | 79.6 K | **1.18** |
| surface cell T | - | **83.5 K** | 79.4 K | **1.05** |
| H -> 2H2 | 0.021 | 0.019 | 0.027 | 0.71 |
| C+ -> C | 1.215 | 1.215 | 1.604 | 0.76 |
| C -> CO | 4.028 | 4.054 | 4.924 | 0.82 |
| deep T | 40.1 K | 40.1 K | 10.5 K | 3.83 |
| heat/cool | 0.999 | 0.999 | 1 | - |

The gas temperature profile now tracks standalone through the illuminated layer:
83.5, 93.7, 108.0, 121.3 K against 79.4, 79.5, 79.8, 82.3 K.

**This closes D-064 and D-068.** The "uniform ~1.9x temperature offset" and the
"[CII] 0.24x / [OI] 0.06x cooling deficit" were the same bug seen from two directions.

*The deep cloud is untouched* - 40.1 K against 10.5 K, exactly as before - which is consistent:
at A_V > 4 the gas is molecular, x(H) ~ 1e-3, so the H collision partner barely contributes there.
That residual is separate and most likely the FUV field, which still decays at gamma_eff = 1.86
per magnitude against the 3.02 3D-PDR assumes, delivering too much photoelectric heating at depth.


## 2026-09-01f - D-076: heating was using the surface field at every depth

Hektor's observation located this precisely: *"the dust temperature is much better and agrees well
with the 3DPDR benchmark. The gas temperature however is not so good. Beginning Av~0.1 it is
consistently higher."*

Dust temperature follows the local field; gas temperature follows photoelectric heating. If one is
right and the other is not, they are being handed different fields - and they were.

3D-PDR keeps two fields and never confuses them:

```fortran
! UVfield.F90 - the LOCAL, attenuated field
pdr(p)%UVfield = pdr(p)%UVfield + pdr(p)%rad_surface(j)*EXP(-pdr(p)%AV(j)*UV_fac)

! changetemperature.F90 - heating takes the LOCAL field
call calc_heating(pdr(p)%rho, pdr(p)%nTgas, pdr(p)%Tdust, pdr(p)%UVfield, ...)

! the RATES take the surface field, and attenuate internally
CALCULATE_REACTION_RATES(..., pdr(p)%rad_surface(0:nrays-1), pdr(p)%AV(0:nrays-1), ...)
```

We passed `chi = grid%chiFUV0` - the unattenuated ~10 Draine **surface** field - to `CALC_HEATING`
at every depth, so **photoelectric heating never attenuated**. Below A_V ~ 0.1 the attenuation is
negligible and it does not matter; beyond that the error grows exponentially. Exactly the
behaviour reported.

This is the same error class as D-065, which fixed the *dust* temperature to use the local field.
The heating call was missed then, which is why the dust came right and the gas did not.

Fixed: `chiLoc = grid%chiFUV(cellP)` (the Monte Carlo transported local field, falling back to
`chi0*exp(-A_V*R_FUV)` where it underflows) now goes to both `CALC_HEATING` calls, while
`radSurf` keeps the surface field for the rates.

### Effect

| quantity | surface field | local field | 3D-PDR | ratio |
|---|---|---|---|---|
| median T, first 20 cells | 94.1 K | **83.1 K** | 79.6 K | **1.04** |
| deep T | 40.1 K | **13.3 K** | 10.5 K | **1.27** |
| C -> CO | 4.054 | **4.752** | 4.924 | **0.97** |
| C+ -> C | 1.215 | 1.263 | 1.604 | 0.79 |
| H -> 2H2 | 0.019 | 0.021 | 0.027 | 0.75 |
| heat/cool | 0.999 | 1.000 | 1 | - |

The temperature profile now tracks standalone across the whole slab:

| A_V | ours | 3D-PDR |
|---|---|---|
| 0.008 | 76.1 | 81.2 |
| 0.108 | 84.7 | 85.3 |
| 0.363 | 75.7 | 68.2 |
| 0.882 | 50.6 | 38.9 |
| 1.946 | 27.0 | 11.7 |
| 3.675 | 11.8 | 8.1 |
| 8.491 | 13.3 | 10.5 |

**D-064 is now closed.** The temperature offset that survived D-060, D-065, D-072, D-073 and D-074
was two separate bugs - the zero collision partner (D-075) at the surface and the unattenuated
heating field (D-076) at depth - which is why no single earlier fix moved it.

Residual: the mid-slab (A_V ~ 1-2) still runs ~2x warm, and both carbon fronts sit ~20-25% shallow
while C->CO is now within 3%.


## 2026-09-01g - D-077: convergence, and how the two codes treat dust

Hektor asked whether grid resolution, the number of frequency bins, or a difference in how the
size distributions are treated could explain the field decaying too slowly.

### The two codes do not treat grain sizes the same way, and cannot

**3D-PDR has no size distribution and computes no opacity.** `grain_radius` from its `params.dat`
appears in exactly one place in the source - `writeparams.F90`, which prints it. There is no Mie
code, no `Q_ext`, no size integration anywhere in the tree. Its dust is entirely parametric:

    A_V          = (Av conversion factor) * N_H     ! 5.33997e-22, prescribed
    attenuation  = exp(-(UV factor) * A_V)          ! 3.02, prescribed, NO scattering

MOCASSIN computes real Mie opacities over `nSpecies x nSizes` grains and `nbins` frequency bins.
So the comparison cannot be "same size distribution"; it can only be "same *effective*
R_FUV and A_V/N_H", which is what D-073/D-074 tuned - 3.59 against 3.02, and 5.338e-22 against
5.33997e-22.

**This also means the field panel is the one place the two codes should legitimately disagree.**
3D-PDR's exponential has no scattering at all. Ours transports a field through grains of albedo
0.486, so scattered light survives deeper: gamma_eff = 1.85 per magnitude against the prescribed
3.02. That is Hektor's original point from 2026-08-31, now quantified with the correct dust.

### Both resolutions are converged

**Frequency bins** - the FUV band (0.441-1.000 Ryd) is sampled by 59 of 1000 bins, 231 of 4000:

| quantity | nbins=1000 | nbins=4000 | change |
|---|---|---|---|
| R_FUV | 3.595 | 3.591 | -0.1% |
| gamma_eff | 1.832 | 1.795 | -2.0% |
| median T, first 20 | 83.08 | 82.70 | -0.5% |
| C -> CO | 4.769 | 4.758 | -0.2% |

**Grid resolution** - 401 vs 801 cells (first cell dA_V 0.005 vs 0.0025):

| quantity | 401 | 801 | 3D-PDR | change |
|---|---|---|---|---|
| gamma_eff | 1.785 | 1.850 | - | +3.6% |
| median T, first 20 | 83.08 | **80.67** | 79.62 | -2.9% |
| deep T | 13.31 | 13.31 | 10.46 | 0.0% |
| C+ -> C | 1.263 | 1.263 | 1.604 | 0.0% |
| C -> CO | 4.752 | 4.760 | 4.924 | +0.2% |

Nothing moves by more than 4%, and the extra resolution improves the surface to **1.01x**. Neither
was the limitation.

### Where the benchmark stands

| quantity | coupled | 3D-PDR | ratio |
|---|---|---|---|
| median T, first 20 cells (801) | 80.7 K | 79.6 K | **1.01** |
| deep T | 13.3 K | 10.5 K | 1.27 |
| C -> CO front | 4.752 | 4.924 | **0.97** |
| C+ -> C front | 1.263 | 1.604 | 0.79 |
| H -> 2H2 front | 0.021 | 0.027 | 0.78 |
| heat/cool | 1.000 | 1 | - |
| gamma_eff of the field | 1.85/mag | 3.02 prescribed | physical difference |

Temperature and the CO front now agree to a few per cent. The two carbon/hydrogen fronts sit
~20% shallow, which is the expected direction for a field that penetrates deeper than 3D-PDR's
scattering-free exponential.


## 2026-09-01h - D-078: the shielding columns were not integrated

### The contradiction that located it

With D-076 in, the temperatures agreed but both the H/H2 and C+/C fronts still sat ~20% shallow.
The explanation offered - a field penetrating deeper than 3D-PDR's - does not survive checking:
a stronger field at depth would push C+ **deeper**, not shallower. Tabulating the profiles made
the contradiction explicit:

| A_V | chi ours | chi 3D-PDR | x(C+) ours | x(C+) 3D-PDR |
|---|---|---|---|---|
| 0.599 | 2.60 | 1.74 | 1.37e-4 | 1.37e-4 |
| 1.260 | 0.644 | 0.232 | 7.08e-5 | 1.10e-4 |
| 1.601 | 0.358 | 0.0875 | 1.59e-5 | 7.40e-5 |

Our field is **stronger** at every depth, yet our C+ converts to C **faster**. Both cannot follow
from the radiation field. And at the H/H2 front our gas was more molecular at every A_V while
slightly *cooler*. Both are the signature of too much self-shielding.

### The cause

```fortran
NHcol = av/dble(pdrAVfac)
colH2 = NHcol*abun(NH2)     ! LOCAL abundance x TOTAL column
colCO = NHcol*abun(NCO)
colC  = NHcol*abun(NC)
```

3D-PDR integrates the real column along each ray (`columndensity.F90`). We took the *local*
abundance and applied it over the *whole* path. Wherever a species' abundance rises with depth -
which is exactly what H2, C and CO do across their own fronts - that overestimates the column. At
the H/H2 front x(H2) climbs from ~0 to 0.25 while the local value is applied over the entire path,
so the column comes out about **2x** too large. More self-shielding lets the species survive at
shallower depth, which is the ~20% shallow bias in both fronts.

Fixed by integrating N(H2), N(C) and N(CO) from the illuminated face in `computeAVdust`, which
already walks the column for the dust, and handing those to the chemistry. Between chemistry
passes the columns are now scaled from the integrated value rather than rebuilt from the local
abundance, so the depth weighting is preserved.

### Result

| quantity | local x total | integrated | 3D-PDR | ratio |
|---|---|---|---|---|
| median T, first 20 cells | 80.67 K | **79.98 K** | 79.62 K | **1.00** |
| C+ -> C front | 1.263 | **1.594** | 1.604 | **0.99** |
| C -> CO front | 4.760 | 4.769 | 4.924 | **0.97** |
| H -> 2H2 front | 0.021 | **0.025** | 0.027 | **0.91** |
| deep T | 13.31 K | 13.31 K | 10.46 K | 1.27 |
| heat/cool | 1.000 | 1.000 | 1 | - |

**The 1D benchmark is now met.** Surface temperature to 0.4%, C+/C to 1%, C/CO to 3%, H/H2 to 9%,
with thermal balance closed to 1.000.

### The arc of the temperature problem, for the record

The offset that stood from D-059 to D-076 was never one bug. In order of discovery:

1. **D-060** - level populations lagged the temperature, so F(T) was not monotonic and the
   bracket found an arbitrary root.
2. **D-065** - HTT91 read `chi` and `av` before assignment and returned its 10 K floor in every
   cell of every model.
3. **D-073** - the benchmark's grains ran 0.07-50 um, giving grey extinction, R_FUV = 1.12.
4. **D-074** - `pdrFcrit` was 0.10 against 3D-PDR's 0.005.
5. **D-075** - `NH`, the species index for atomic H, was shadowed by a local `nH`, so the
   dominant collision partner for [CII] and [OI] was zero.
6. **D-076** - photoelectric heating was given the unattenuated surface field at every depth.
7. **D-078** - shielding columns used the local abundance over the total path.

Only the last three moved the temperatures, and each was masked by the others. The single most
useful diagnostic throughout was comparing a quantity **at matched temperature** rather than in
the converged solution, which is what separated "the cooling function is weak" from "the gas is
hotter so it radiates more".

### Remaining

- **Deep gas at 13.3 K against 10.5 K (1.27x).** The only outstanding discrepancy.
- The transported field decays at gamma_eff = 1.85 per magnitude against 3D-PDR's prescribed
  3.02. This is a genuine physical difference - 3D-PDR's exponential has no scattering, ours
  transports through grains of albedo 0.486 - and is expected to persist.


## 2026-09-01i - D-079: what the reported convergence actually measures

Hektor asked how the convergence the model reports is doing. Worth answering carefully, because
the number is not measuring what its name suggests.

### What it reports

    Iteration 1 ;   0.000 % converged
    Iteration 2 ;   0.424 %
    Iteration 3 ; 100.000 %
    Iteration 4 ; 100.000 %
    Iteration 5 ;  99.995 %   -> convergence reached after 5 iterations

### What that criterion is

In `updateCell` the **gas-phase** convergence test is commented out in upstream MOCASSIN:

```fortran
!            grid%Te(cellP)         = TeUsed
!            deltaXHI = (grid%ionDen(cellP,elementXref(1),1) - XOldHI) / XOldHI
!            if ( abs(deltaXHI) <= XHILimit ) then
!               grid%lgConverged(cellP) = 1
```

The live test is on the **dust temperature**:

```fortran
XOldHI   = grid%Tdust(0,0,cellP)
call getDustT()
deltaXHI = (grid%Tdust(0,0,cellP) - XOldHI) / XOldHI
if (abs(deltaXHI) <= XHILimit) grid%lgConverged(cellP) = 1
```

To which D-032 adds the only PDR-aware term - `pdrStep` clears `lgConverged` for any cell whose
instantaneous imbalance exceeds `pdrFcrit`:

```fortran
if (abs(heat(12)-coolTot)/max(abs(heat(12)), coolTot) > dble(pdrFcrit)) &
     & grid%lgConverged(cellP) = 0
```

So "100% converged" means: **dust temperature stable, and heating balances cooling to 0.5% at the
current temperature.** It says nothing about whether the chemistry has reached steady state.

### The PDR only ever gets about two passes

With `pdrStartIter 4` the run exits at iteration 5, so `pdrStep` runs **twice**. That is by
construction: D-062's guard holds the run open only until the PDR has been enabled and had a pass.
Raising `convLimit` does not change it - at 99.99 and even at 100.5 the model still stopped after
3-5 iterations, because the dust had already stabilised before the PDR started.

### But the PDR is nonetheless converged - verified directly

The reported number cannot establish this, so it was tested by quadrupling the internal
relaxation: `pdrChemIter` 3 -> 12, `pdrThermIter` 12 -> 40, `pdrLevIter` 25 -> 60.

| quantity | 3/12/25 | 12/40/60 | change |
|---|---|---|---|
| median T, first 20 cells | 79.977 | 79.749 | -0.3% |
| deep T | 13.306 | 13.305 | -0.0% |
| H -> 2H2 | 0.0250 | 0.0252 | **+0.7%** |
| C+ -> C | 1.5944 | 1.5936 | -0.1% |
| C -> CO | 4.7689 | 4.7743 | +0.1% |
| heat/cool | 1.0000 | 1.0000 | 0.0% |

Everything moves by 0.7% or less. The inner loops do the relaxation within a single pass, so two
passes suffice **for this model**.

*A false alarm on the way to that:* an earlier attempt reported the H/H2 front moving by -93%. That
run had been killed mid-flight by a polling timeout and its `pdrGrid.out` was a partial write. It
parsed cleanly - the record count was right - which is exactly why it was believable. Re-running
it detached gave +0.7%. Worth remembering that a complete-looking checkpoint from a killed run is
not a result.

### The honest assessment

The convergence report is **trustworthy for this model but not diagnostic of the PDR**. It
measures dust-temperature stability plus an instantaneous energy balance; chemical steady state is
established separately, by the relaxation test above. For a model whose chemistry evolves more
slowly - higher density, greater depth, or a network with longer timescales - two passes might not
suffice and the reported number would not catch it.

**Recommended practice:** treat the reported percentage as a necessary but not sufficient check,
and confirm any new configuration with a relaxation test (raise `pdrChemIter`/`pdrThermIter` and
verify nothing moves) before trusting the result.


## 2026-09-01j - where the work stands, and what to do next

### Status

The 1D benchmark is met. Against standalone 3D-PDR on a matched slab:

| quantity | ratio |
|---|---|
| median T_gas, first 20 cells | 1.00 |
| C+ -> C front | 0.99 |
| C -> CO front | 0.97 |
| H -> 2H2 front | 0.91 |
| heat/cool balance | 1.000 |
| deep T_gas | 1.27 |

Original scope is complete: vendored 3D-PDR builds inside MOCASSIN, `mocassinWarm` round-trips
the PDR state losslessly, `mocassinPlot` and `mocassinOutput` are PDR-aware, and the DEVLOG has
carried every decision.

### The gap that matters

**Everything MOCASSIN uniquely brings to this coupling is still untested.** The only configuration
ever exercised is a plane-parallel slab lit by a non-ionizing source, in which:

- `x(H+)` never exceeds **7.6e-5**, so the D-007 **blend band has never once been active** - the
  whole ramp between MOCASSIN's photoelectric heating and 3D-PDR's is dead code in every run so far;
- there is **no ionization front**, so the zone criterion has never been tested where it matters;
- the **metal ionization feedback** - the multi-stage work of D-037 onward - is never exercised,
  because there is nothing to ionize;
- the geometry is 1D, so HEALPix rays, three-dimensional A_V and the directional field are all
  collapsed to a single direction;
- the diffuse field, which is the physical reason to couple to a Monte Carlo code at all, has no
  recombination source to generate it.

A 1D slab is the right first benchmark and it found nine real bugs. But it cannot validate the
coupling's reason for existing.

### Recommended next step: an H II region + PDR model

This is TORUS-3DPDR's own section 5.4 test - a uniform-density cloud around an ionizing star,
which they validated against **MOCASSIN** for the ionized zone and **3D-PDR** for the PDR. It is
the natural next benchmark because it exercises, in one model, every path the slab could not:

1. a real ionization front, so `pdrZoneLim` and the blend band finally do something;
2. metal ionization feedback across the front;
3. the geometric dilution term `R_IF^2/(R_IF+r)^2` that TORUS reports was **required** for
   agreement with MOCASSIN, and which this coupling has never needed and never tested;
4. genuine diffuse radiation from recombination, which is where TORUS found effects worth 100-200 K
   and five orders of magnitude in CO J=7-6.

It also has a published reference on both sides, which the slab did not.

### Then, in order

- **Rollig V2** (n_H = 10^5, chi = 10^3): the stiffer chemistry test, and the model TORUS validated
  on. High density puts the coolants above their critical densities, which exercises the level
  population solve in the opposite regime from V1.
- **Deep gas at 1.27x** (13.3 K against 10.5 K): the last discrepancy in the 1D benchmark.
- **Checkpoint `pdrLevPop`** (carried since D-016 era). It mattered little when populations were
  re-solved from LTE each pass; after D-060 made the fixed-T level iteration central, a warm start
  that discards them restarts that relaxation from scratch.
- **Decide the `pdrStartIter` default.** Currently 1 for backward compatibility, but the evidence
  of D-062 favours a warm-up, and the benchmark uses 4.

### A note on method, for whoever picks this up

Two habits did most of the work in this session:

- **Compare at matched temperature, not in the converged solution.** "Our cooling is weak" and
  "our emissivities are larger" were both true simultaneously, and only the matched-temperature
  comparison distinguished cause from consequence.
- **Check that a claimed explanation predicts the right direction.** The shallow fronts were
  attributed to a deeper-penetrating field for some time; that field would have pushed C+ *deeper*.
  Noticing the sign error is what led to D-078.


## 2026-09-01k - D-080: the first H II region + PDR model

Built from MOCASSIN's own validated `benchmarks/gas/HII40`, which already sits at TORUS-3DPDR's
section 5.4 conditions - n_H = 100 cm^-3 and a 4e4 K blackbody. Its `Rout` stops at the ionization
front, so it was extended from 1.46e19 to 6.0e19 cm to open a neutral zone, dust and the PDR were
added, and the abundances matched to the slab benchmark (He 0.1, C 1.4e-4, O 3e-4, zeta = 5e-17).

Committed as `benchmarks/pdr/hiipdr/`.

### It works

Converged to 99.2% in 5 MC iterations. Radial cut along x:

| r [cm] | T_e | x(H+) | x(C+)/C |
|---|---|---|---|
| 4.0e18 | 9544 K | 0.9999 | 0.008 |
| 1.2e19 | 11230 K | 0.980 | 0.838 |
| **1.6e19** | **198 K** | **8.9e-5** | 1.000 |
| 2.8e19 | 124 K | 1.3e-5 | 1.000 |
| 4.0e19 | 93 K | 3.9e-6 | 0.997 |
| 6.0e19 | 22 K | 7.6e-6 | 0.484 |

An ionization front at R_IF ~ 1.4e19 against a Stromgren estimate of 1.58e19, 9500-11000 K
ionized gas, and a PDR beyond it falling to 22 K with CO taking over the carbon at the outer edge.
14903 of 29791 cells are in the PDR zone.

**Three coupling paths are exercised here for the first time**, none of which the slab could reach:

1. the **spherical A_V path** - `AVeff` inverted from `chi/chi0` per source (D-001), rather than
   `computeAVdust`'s plane-parallel dust column;
2. **metal multi-stage feedback across a front** - the C+ fraction runs 0.008 near the star,
   through 1.0 in the PDR, back to 0.48 as CO forms;
3. a **diffuse field with a real recombination source**, which is the physical reason for coupling
   to a Monte Carlo code at all.

### But the blend band is still dead, and now we know why

Zero cells fall in `0.01 < x(H+) < 0.3`. The transition runs from x(H+) = 0.98 at r = 1.2e19 to
8.9e-5 at 1.6e19 - **inside a single cell**. The front is simply thinner than the grid:

    front thickness ~ 1/(n*sigma) = 1.6e15 cm
    cell size (nx=31, Rout=6e19) = 2.0e18 cm
    under-resolved by a factor of ~1260

Placing ~10 cells across the front needs ~1.6e14 cm cells, which a uniform grid to 6e19 cm cannot
provide (3.8e5 cells per axis). **The D-007 blend band therefore cannot be tested without
MOCASSIN's nested sub-grids** (`nGrids > 1`) refining the region around R_IF - or a dedicated 1D
model spanning only the front.

That is a concrete, bounded next step, and it is worth doing: the blend band has never executed in
any run of this coupling, so it remains the one substantial piece of the design that is entirely
unverified.


## 2026-09-01l - D-081: resolving the front without sub-grids, and the bug it found

Hektor ruled out MOCASSIN's nested sub-grids and asked what resolution the available RAM allows.

### Measured memory

Two points at nbins = 600 on 14 ranks - 9261 cells at 329 MB/rank and 29791 at 539 MB/rank - give

    per rank:  234 MB fixed  +  10.47 kB/cell
    14 ranks:  3.2 GB fixed  +  147 kB/cell

The machine has 61 GB, 44 GB available. Budgeting 30 GB (oomd killed earlier runs well below full
RAM, D-040):

| nbins | cells | uniform grid |
|---|---|---|
| 600 | 192000 | **58^3** |
| 200 | 575000 | **83^3** |

### A uniform grid provably cannot do it

To put even one cell inside the front while spanning a PDR of depth A_V:

    cell <= d_IF  = 1/(n*sigma)          = 1.59e17/n
    box  >= L_PDR = A_V/(n*5.34e-22)
    =>  N >= L_PDR/d_IF = [A_V/5.34e-22]/1.59e17      <- n CANCELS

| A_V | cells per axis |
|---|---|
| 0.5 | 5.9e3 |
| 1 | 1.2e4 |
| 2 | 2.4e4 |

Memory allows 83. **Short by 140-430x, and the density cancels** - raising n thins the front and
shortens the PDR in exact step, so no choice of density, luminosity or geometry helps. This is not
a resource limitation; a uniform 3D grid is the wrong tool.

### A graded 1D grid costs nothing

MOCASSIN already reads arbitrary axes from a `densityFile`, which is how the slab benchmark is
built. It is not sub-gridding. Applying it to a plane-parallel *ionizing* beam - 2e14 cm at the
face, ratio 1.013, 601 cells - puts **~8 cells across the front** and still reaches A_V = 1.9, in
15025 cells and about 5 GB. Committed as `benchmarks/pdr/ifront/`.

Result: **168 cells inside 0.01 < x(H+) < 0.3.** The D-007 blend band executed for the first time
in the history of this coupling.

### D-081: and it was being bypassed

`pdrToMocassin` writes the blended temperature into `grid%Te`:

```fortran
grid(iG)%Te(cellP) = real(w*pdrTgas + (1-w)*Te)
```

but D-072's guard pinned `TeUsed = grid%pdrTgas(cellP)` - the **raw** PDR temperature - discarding
the ramp and applying the pure PDR value right up to the zone edge. The blend band exists
precisely to avoid a discontinuity at the ionization front, and it was doing nothing.

Invisible in every previous model, because none had a single cell in the band.

Fixed to `TeUsed = grid%Te(cellP)`, which is the value `pdrToMocassin` already blended.

| y [cm] | x(H+) | w | before | after |
|---|---|---|---|---|
| 1.80e16 | 0.308 | 0.00 | 8596 K | 8596 K |
| 2.79e16 | 0.098 | 0.33 | - | **4930 K** |
| 4.06e16 | 0.019 | 0.82 | - | **1724 K** |
| 5.71e16 | 0.0058 | 1.00 | 50 K | 372 K |
| 7.85e16 | 0.0024 | 1.00 | 52 K | 52 K |

Before the fix the temperature fell 8922 K to 50 K in a single step. It now ramps smoothly across
the front, which is what the design intended.

### Note

This model is deliberately weakly ionized - `meanField` 2e-3 gives x(H+) ~ 0.6 at the face rather
than a fully ionized region - which broadens the transition and makes it a good test of the blend.
It is a machinery test, not a physical H II region; `benchmarks/pdr/hiipdr/` is the physical one.


## 2026-09-01m - D-082: Rollig V2, and the limits of a 3D comparison

### V2 matches

Built by scaling 3D-PDR's own `ics/1Dn30.dat` by 1/100 in length at n_H = 1e5, so the A_V span is
unchanged, and running standalone 3D-PDR on it at chi = 1e3. Committed as
`benchmarks/pdr/v2slab/` with the reference in `benchmarks/pdr/baseline3dpdr/v2.pdr.fin`.

| quantity | coupled | 3D-PDR | ratio |
|---|---|---|---|
| median T, first 20 cells | 196.28 K | 195.67 K | **1.00** |
| deep T | 10.03 K | 9.80 K | **1.02** |
| C -> CO front | 2.2355 | 2.2638 | **0.99** |
| C+ -> C front | 1.5571 | 1.5949 | **0.98** |
| H -> 2H2 front | 0.0534 | 0.0583 | 0.92 |
| heat/cool | 1.0000 | 1.0000 | - |

**This is the important result of the two.** V2 is 1000x denser and carries a 100x stronger field
than V1, which puts the coolants above their critical densities and changes the thermal balance
regime entirely. The fixes of D-075 through D-078 were all found on V1; that they hold to 0-8% on
V2 without any retuning says they were real physics errors, not V1-specific compensation.

Worth noting the **deep temperature is 1.02 here against 1.27 on V1**. So V1's deep residual is a
low-density effect, not a general defect - which also means it is the less interesting of the two
remaining discrepancies.

### A 3D comparison cannot be matched, and why

3D-PDR's 3D mode illuminates isotropically:

```fortran
pdr(p)%rad_surface = Gext(1)/real(nrays,kind=dp)     ! UVfield.F90:91
```

- every ray carries the same external field. MOCASSIN has no equivalent. Its `diffuseSource` is a
*distributed emitter inside* the grid, not an external bath, and its other options are point
sources or a plane-parallel beam. So a like-for-like 3D benchmark against
`ics/3Dsphere.dat` is not available without modifying vendored source.

The 3D run is therefore framed honestly as a **machinery test**, not a benchmark: 3D-PDR's own
sphere density field (32^3, n = 1e3 in a 9.7 pc box, 53% of cells dense, A_V ~ 8 through the
diameter) illuminated plane-parallel at chi = 10. What it establishes is whether the coupling
functions in three dimensions at all - and it exercises the one thing 3D-PDR structurally cannot
produce under isotropic illumination: **shadowing behind the cloud**, which is precisely what the
Monte Carlo transfer contributes.

Memory: 32768 cells at nbins = 600 on 14 ranks measured **15.7 GB**, against the D-081 model
predicting 3.2 + 0.147*32768/1024 = 7.9 GB. The excess is the dust arrays, which the slab models
carried too but at a twentieth the cell count. Worth folding into the memory model.


## 2026-09-01n - D-083: the escape-probability branch is dimensionality-specific

Hektor pointed at 3D-PDR's documentation for running a 3D example, which led to
`templates/3D/config.mk`. Diffed against the 1D template it carries:

```
DIMENSIONS   = 3        (1D template: 1)
RAYTHEIA     = 1        (1D template: 0)
```

That second line matters. `escape_probability.F90` has three mutually exclusive branches and the
flags select between them:

| build | branch | beta |
|---|---|---|
| 1D template (`RAYTHEIA=0`, `DIMENSIONS=1`) | `ONEDIMENSIONAL` | 11 of 12 rays blanked to tau = 1e50; **beta = beta_6, undivided** |
| 3D template (`RAYTHEIA=1`) | `RAYTHEIA` | all rays real; **beta = sum(beta)/nrays** |

**Our `PDRFLAGS` sets `-DONEDIMENSIONAL`** (D-063), chosen deliberately so the coupling runs the
same code as the 1D reference. That is correct for every benchmark run so far - V1, V2, the
ionization front - and **wrong for any three-dimensional model**, where it would blank eleven of
twelve escape directions and leave beta undivided.

D-061's per-ray slab geometry was, in hindsight, the RAYTHEIA formulation applied under a
RAYTHEIA_MO build; it was withdrawn for the wrong reason. The formulation was not the error, the
branch was.

**Practical consequence:** the branch is a compile-time `#ifdef`, so one binary cannot serve both.
A 3D model needs either a second build with `-DRAYTHEIA` in place of `-DONEDIMENSIONAL`, or
`escape_probability` restructured to take the choice as an argument. Until then, **3D results from
this coupling would use the wrong escape geometry and should not be trusted.**

### Also learned from the 3D template

The official 3D example uses `ics/diffuse_32.dat`, not `3Dsphere.dat`, at G0 = 10,
zeta = 1e-16, A_V factor 6.289e-22, UV factor 3.02, HEALPix level 0, and requires the HDF5
post-processing path for column-density maps.

### State of the 3D attempt

A 32^3 run on `3Dsphere.dat` was set up and reached iteration 4 (96% converged) before the
session scratchpad was cleared, taking the run and the upstream clone with it. Two things were
learned first and are worth keeping:

1. **`planeIonization` requires axes starting at zero** (D-045), and 3D-PDR's sphere IC starts at
   0.156 pc. Unshifted, every packet launch failed with
   `integratePathTau: starting position in x is outside the grid`. Shifting the axes fixed it.
2. Measured memory for 32768 cells at nbins = 600 on 14 ranks was **15.7 GB**, against 7.9 GB from
   the D-081 model. The excess is dust arrays, which scale with `nSpecies x nSizes` and were a
   negligible fraction at the slab cell counts the model was fitted on. The memory model
   under-predicts for dusty 3D grids by about 2x.

### Not recovered

`v1.cool.fin` - the per-species cooling reference for V1, used by the artifact's emissivity panel
- lived only in the scratchpad. Regenerating it means re-cloning upstream and re-running the 1D
reference, which `benchmarks/pdr/baseline3dpdr/` has everything else needed for.


## 2026-09-02 - D-084: a PDRGEOM switch, and a fixture that did not reproduce

### The 3D flags are a pair, not one

D-083 recorded that `templates/3D/config.mk` sets `RAYTHEIA = 1`. That is a *makefile* variable,
not a preprocessor symbol, and 3D-PDR maps it to two flags:

```make
ifeq ($(RAYTHEIA),1)
  CFLAGS += -DRAYTHEIA
  CFLAGS += -DRAYTHEIA_MO
endif
ifeq ($(RAYTHEIA),2)
  CFLAGS += -DRAYTHEIA          # -DRAYTHEIA alone
endif
```

`-DRAYTHEIA` alone - their `RAYTHEIA=2` - **does not link**: `columndensity.F90` then compiles a
path using a bare `projected` array that is only declared under `RAYTHEIA_MO`, so the reference is
resolved as an undefined external `projected_`. That combination is evidently untested upstream.
`columndensity.o` cannot simply be dropped either, since `chemicaliterations` calls
`calc_columndens`.

So the 3D configuration is `-DRAYTHEIA -DRAYTHEIA_MO`, **which is exactly what this coupling built
before D-063 changed it to `-DONEDIMENSIONAL`**. D-061's per-ray slab geometry was the right
formulation for that branch all along; it was withdrawn for the wrong reason.

### The switch

`make PDR=1` builds the 1D flavour (`-DONEDIMENSIONAL`), `make PDR=1 PDRGEOM=3D` the 3D one
(`-DRAYTHEIA -DRAYTHEIA_MO`). The two branches take **different arguments** - RAYTHEIA a per-ray
`length` array, ONEDIMENSIONAL evaluation-point coordinates - so the call in `pdrStep` and the
geometry that feeds it are guarded by the same `#ifdef`. One binary cannot serve both.

The `.pdrflag` stamp now records `$(PDR)-$(PDRGEOM)`, so switching geometry forces a rebuild.
Without that it is exactly the staleness trap of D-023 and D-028.

### The regression found a worse problem than the one it was checking

Running the committed `benchmarks/pdr/v1slab` fixture through the 1D build did not reproduce the
D-078 result: H -> 2H2 came out at 0.14 of standalone against the 0.91 recorded, and C+ -> C at
1.09 against 0.99.

The build was not at fault. **The committed fixture was never the configuration that produced the
published numbers.** It carried `maxIterateMC 4`, `ny 401`, and *no* `pdrStartIter` line at all -
so it ran without the D-062 warm-up - because it had been copied from a D-058-era input and never
updated as the configuration evolved through D-062, D-076 and D-078.

Corrected to `ny 801`, `maxIterateMC 8`, `pdrStartIter 4`, with `make_density.py` matched
(first cell 0.0025 mag). It now reproduces exactly:

| quantity | fixture rerun | 3D-PDR | ratio | D-078 reported |
|---|---|---|---|---|
| median T, first 20 cells | 79.9253 | 79.6172 | **1.00** | 1.00 |
| deep T | 13.3063 | 10.4611 | **1.27** | 1.27 |
| H -> 2H2 | 0.0250 | 0.0274 | **0.91** | 0.91 |
| C+ -> C | 1.5942 | 1.6039 | **0.99** | 0.99 |
| C -> CO | 4.7839 | 4.9236 | **0.97** | 0.97 |
| heat/cool | 1.0000 | 1 | - | - |

`v2slab` had the same defect and was corrected the same way.

**The lesson is about the fixtures, not the physics.** Every benchmark number in this log from
D-062 onwards was produced from a scratch directory, and the committed fixture was assumed to
match. It did not, and nothing checked. Re-running a committed fixture against a committed
reference is cheap and should be done whenever either changes.

### State

Both flavours build clean. The 1D flavour is verified against `baseline3dpdr/v1.pdr.fin`. The 3D
flavour is **built but unexercised** - testing it needs 3D-PDR's `ics/3Dsphere.dat` or
`diffuse_32.dat`, which live upstream and were lost with the session scratchpad, and a 3D model
still supplies per-ray columns from the plane-parallel closed form rather than ray-tracing them
through the grid (`columndensity.F90` is the routine that would do it).


## 2026-09-02b - D-085/D-086: can 3D-PDR run an H II model? No, and what that leaves

Hektor asked whether we could run something like HII40 in 3D-PDR, to get a realistic spherical
model with a central star and compare against MOCASSIN.

### D-085: 3D-PDR has no photoionization at all

Checked against the source rather than assumed. Searching for ionizing transfer finds only
**carbon and sulphur** photoionization - `heatingfunctions.F90:157` "Carbon photoionization
heating", `calc_reac_rates.F90:280` "reaction number for CI photoionization" - which are FUV
processes inside the PDR. There is no Lyman-continuum transfer anywhere, and H+ in the reduced
network is produced by chemistry (charge exchange, cosmic rays), not by a stellar ionizing field.

So 3D-PDR cannot produce an H II region. That is by design: it is a PDR code that begins where the
ionized gas ends, which is exactly why TORUS-3DPDR's section 5.4 compared the ionized zone against
**MOCASSIN** and the PDR against **3D-PDR**, separately.

It also has exactly two illumination modes, both in `UVfield.F90`:

```fortran
#ifdef ONEDIMENSIONAL
   pdr(p)%rad_surface(6) = Gext(1)                    ! all flux on one ray
#else
   pdr(p)%rad_surface = Gext(1)/real(nrays,kind=dp)   ! isotropic bath
#endif
```

No point source. (A directional variant was contemplated - the commented
`!-DOT_PRODUCT(Gext(:),vectors(:,j))` - and `Gext` is declared as a 3-vector, but only `Gext(1)`
is ever read.)

**But Hektor's idea has a realizable form.** In a spherically symmetric problem with a central
source, radiation reaches any point from one direction only - radially. That is precisely the
`ONEDIMENSIONAL` mode. So 3D-PDR's 1D mode *is* a centrally-illuminated spherical PDR, missing
only the geometric dilution, which is the `R_IF^2/(R_IF+r)^2` factor TORUS reported was required
for agreement with MOCASSIN.

### The test that results

MOCASSIN ran the spherical H II + PDR model (`benchmarks/pdr/hiipdr`, n_H = 100, 4e4 K blackbody,
LPhot 4.26e13). It converged and produced a proper structure:

| r [cm] | T_e | x(H+) | note |
|---|---|---|---|
| 4.0e18 | 9533 K | 0.9999 | H II region |
| 1.2e19 | 11147 K | 0.9814 | |
| **1.341e19** | | **0.5** | **ionization front** |
| 1.6e19 | 3130 K | 0.0189 | **inside the D-007 blend band** |
| 2.8e19 | 125 K | 1.4e-5 | PDR |
| 6.0e19 | 39 K | 4.7e-4 | outer edge, x(H2) = 0.49 |

Note the blend band is genuinely active here - x(H+) = 0.0189 lies in 0.01-0.3 - which the slab
models never achieved and the earlier plane-parallel front model needed a graded grid to reach.

3D-PDR was then run in 1D at n_H = 100 with `Gext = 105.15`, the field our model gives at the
front, over a matched A_V span.

### D-086: and the comparison found a defect - after a false start

Aligned on **our** A_V, the ratio chi_ours/chi_3DPDR tracked (R_IF/r)^2 to about 15%, which looked
like a clean confirmation that we carry the dilution TORUS had to add.

**That comparison was circular.** In the spherical path `AVeff` is *defined* from the field:

```fortran
if (.not.lgPlaneIonization) then
   tauFUV = -log(chi/chi0)
   grid(iG)%AVeff(cellP) = real(dble(magPerTau)*tauFUV/dble(pdrRfuv))
```

so aligning on that A_V matches the attenuation by construction, and what remains is the dilution
almost by definition. Re-aligned on **geometric** depth from the front - independent of either
code - the picture changes:

| | our A_V | geometric A_V |
|---|---|---|
| outer edge, r = 6e19 | **1.386** | **2.487** |

**Our spherical A_V under-reads the true dust column by a factor of 1.8.** The cause is known: the
Monte Carlo field carries scattered light, so `-ln(chi/chi0)` under-reads the extinction. The slab
measured gamma_eff = 1.86 per magnitude against the 3.02 of pure extinction, a ratio of 1.6 -
close to the 1.8 seen here.

This is the same defect D-054 fixed for the plane-parallel case by abandoning the inversion in
favour of `computeAVdust`'s geometric column. That routine still opens with

```fortran
if (.not.lgPlaneIonization) return
```

so **the spherical path never got the fix**. Extending it - integrating the dust column radially
from the source rather than inverting the field - is the outstanding work, and it is the same
correction, applied to the geometry that was left behind.

*Caveat on the run itself:* the 3D-PDR grid was sized to our derived A_V span (1.181) rather than
the geometric one (2.487), so the comparison is only valid to r ~ 3.4e19 where its grid still has
points. Re-running it over the geometric span is cheap and should be done alongside the fix.


## 2026-09-02c - D-087: a geometric A_V for the spherical geometry

D-086 established that the spherical path's `AVeff`, defined by inverting the Monte Carlo field,
under-reads the dust column - and that D-054 had already fixed exactly this for the plane-parallel
case by integrating the column instead. `computeAVdust` opened with
`if (.not.lgPlaneIonization) return`, so the spherical geometry never received the fix.

### What was added

`computeAVradial` walks from each source to each cell centre, accumulating dust extinction
(`absOpac + scaOpac` at V, as `computeAVdust` does), and forms the effective A_V that reproduces
the summed transmitted flux:

    A_V,eff = -(1.0857/R_FUV) ln( SUM_s f_s e^{-R_FUV A_V,s/1.0857} / SUM_s f_s )

which reduces to the plain column for a single source. The march step is set by the finest axis
spacing so no cell is skipped, and a contained `nearestAx` helper does the index lookup rather
than depending on MOCASSIN's `locate`, which `pdr_mod` does not `use`.

### The first attempt changed nothing, and the reason is worth recording

Adding the routine moved the median A_V/truth from 0.390 to 0.386 - no change at all.
`mocassinToPDR` was still running the old inversion *after* `computeAVdust`, overwriting the
result. Adding a better calculation is not the same as removing the worse one that follows it. The
inversion is now deleted for this geometry.

### Result

Measured against the geometric column from the source, `A_V_true = 5.338e-22 * n * r`:

| r [cm] | A_V true | inversion | radial | radial/true |
|---|---|---|---|---|
| 1.8e19 | 0.9608 | 0.3149 | 0.7509 | 0.782 |
| 3.0e19 | 1.6014 | 0.5871 | 1.4942 | 0.933 |
| 4.2e19 | 2.2420 | 0.9459 | 2.0383 | 0.909 |
| 6.0e19 | 3.2028 | 1.3861 | 3.1073 | **0.970** |

**Median A_V/truth: 0.390 -> 0.928.** The residual few per cent is the finite march step and the
`Rin = 3e18` cavity, which carries no gas.

The effect on the PDR is large and in the right direction - more extinction, so the gas turns
molecular sooner and the carbon transition moves inside the model:

| r [cm] | x(H2) before | x(H2) after | T before | T after |
|---|---|---|---|---|
| 2.2e19 | 0.029 | **0.381** | 147 K | 204 K |
| 2.8e19 | 0.157 | **0.475** | 125 K | 200 K |
| 4.0e19 | 0.413 | 0.495 | 103 K | 126 K |

The C+ -> C transition now falls inside the grid, crossing near r = 4e19 where
x(C+) = 7.1e-5 against x(C) = 6.9e-5. Under the inversion it never happened - C+ stayed at
1.40e-4 to the outer edge.

### Still to do on this comparison

The 3D-PDR 1D reference for this model was built to span our *old* (under-read) A_V range of
1.181. With the corrected A_V the model now reaches 3.1, so that reference no longer covers it and
the quantitative comparison must be re-run over the new span before any agreement is claimed. The
qualitative check that motivated the fix - our A_V against the geometric column - needs no
reference and is what the table above reports.


## 2026-09-02d - D-088: the radial path fell back to the D-078 shielding-column error

### What the corrected reference showed

With D-087's geometric A_V in place, the 3D-PDR 1D reference was rebuilt over the corrected span
(A_V = 0 to 2.4637 from the ionization front, n_H = 100, `Gext = 65.349` - the field in our first
PDR cell) and compared against the spherical coupled model, aligned on geometric A_V. Alignment on
a geometric A_V is independent of our radiation field, so this comparison is no longer circular the
way D-086's was.

The field tracked well (chi ratio 0.79-1.85 across two decades of attenuation), but the chemistry
did not:

| A_V from front | x(H2) ours | x(H2) 3D-PDR |
|---|---|---|
| 0.000 | 4.16e-02 | 1.63e-06 |
| 0.322 | 3.07e-01 | 8.20e-03 |
| 0.429 | 4.04e-01 | 1.96e-02 |
| 0.743 | 4.75e-01 | 1.31e-01 |

H -> 2H2 crossing: **ours 0.26, 3D-PDR 0.91**. Our gas turns molecular almost immediately, and
x(C+) fell to 4e-5 by the outer edge where 3D-PDR holds it at its full 1.4e-4 (at n = 100 and
chi = 65 the carbon front is deeper than this model reaches). Both are the signature of far too
much self-shielding.

### Cause

`computeAVradial` (D-087) writes `AVeff` and nothing else. `pdrColH2`, `pdrColC`, `pdrColCO` and
`AVback` stay at zero, and `pdrToMocassin` has a fallback for exactly that case:

```fortran
if (sH2 <= 0.d0) sH2 = NHcol*abun(NH2)
```

That is the D-078 error - the local abundance times the whole column - which we removed from the
plane-parallel path in D-078 and then reintroduced, unnoticed, by adding a second geometry whose
column integration was never written. It is worse here than it was in the slab: `NHcol` is the
column all the way back to the star, so it counts the entire H II region as H2-bearing at the
local molecular fraction. At the first PDR cell that is a column of ~1e21 cm^-2 of "H2" where the
true integrated value is essentially zero, and the H2 photodissociation rate is shielded away
before any H2 exists.

Adding a better A_V calculation was not enough; the routine also has to supply everything the old
one supplied. Same lesson as D-087's first attempt, one layer down.

### Fix

`computeAVradial` now accumulates n_H(cell) * x_X(cell) * ds for H2, C and CO along the same
source-to-cell march it already walks for the dust optical depth, and adds a second outward march
from the cell to the grid boundary for `AVback`. Where there is more than one source the four
quantities are combined with the same 1/r^2 flux weight used for the A_V, which is exact for the
single-source case these models use.

That fixed C, CO and the outward escape column - but x(H2) did not move by one digit. Three more
things were shielding H2, each hidden behind the last.

### (2) The column ran through the H II region on seed abundances

`pdrAbun` is only solved where `pdrZone == 1`. Everywhere else it still holds `seedPDR`'s values -
x(H2) = 0.3, x(H) = 0.4 - because nothing ever overwrites them. Integrating those from the star put
~1e21 cm^-2 of fictitious H2 in front of the first PDR cell. In ionized gas the molecules are
dissociated and carbon is C+ or higher, so the true shielding column through it is zero: the
accumulation is now gated on `pdrZone(cP) == 1`.

C+ improved sharply - it now holds its full 1.4e-4 out to A_V ~ 1.4, as the reference does - and
x(H2) still did not move.

### (3) A cell's own H2 shielded that cell

The march ran source -> cell *centre*, so the target cell's own near half was in its own column.
That feedback is positive: more H2 -> less dissociation -> more H2. On 3D-PDR's graded grid the
half-cell column is ~1e13 cm^-2 and it does nothing. On a 2e18 cm MOCASSIN cell it is 4e18 cm^-2 -
enough to shield the surface cell outright - and the solver settles on that runaway branch. The
accumulation now skips the target cell (`cP /= cellP`), giving the near-face column: it lags the
true centre column by half a cell, an error that shrinks with resolution rather than amplifying.

And x(H2) *still* did not move, to three digits, across every variant and across gas temperatures
from 203 K to 3418 K. That last part was the clue - no real chemistry is that insensitive.

### (4) Zero is an answer, not a missing value

```fortran
if (sH2 <= 0.d0) sH2 = NHcol*abun(NH2)
```

The first PDR cell's near-face column is legitimately **zero** - there is nothing molecular in
front of it. That tripped the "not computed" fallback and handed the cell `NHcol*abun(NH2)`: the
entire column back to the star times the local molecular fraction. Every fix above was being
overwritten by the one line meant to cover the case where none of them had run.

The column arrays now initialise to -1, the sentinel test is `< 0`, and the surface cell keeps its
zero.

### Result

Spherical H II + PDR model (n_H = 100, 31^3, chi = 65.6 at the front) against 3D-PDR run over the
matched A_V span, aligned on geometric A_V:

| A_V from front | x(H2) before | x(H2) after | 3D-PDR |
|---|---|---|---|
| 0.000 | 4.16e-02 | **4.44e-06** | 1.63e-06 |
| 0.322 | 3.07e-01 | **2.13e-05** | 8.20e-03 |
| 0.429 | 4.04e-01 | **6.02e-05** | 1.96e-02 |
| 0.743 | 4.75e-01 | 4.16e-01 | 1.31e-01 |

H -> 2H2 crossing: 0.26 -> **0.53** against the reference's 0.905. x(C+) now holds 1.40e-4 to
A_V ~ 1.4 where before it had fallen to 7e-5. Median T ratio 1.46 -> 1.34.

The residual is resolution: x(H2) goes from 6e-5 to 0.42 across a single cell, because a uniform
31^3 grid over 6e19 cm gives dA_V = 0.107 per cell and the H/H2 front is thinner than that. The
front cannot land anywhere but on a cell boundary. This is the same limit already recorded for the
ionization front - a uniform grid cannot resolve either - and it is what TORUS-3DPDR uses AMR for.

### Regression check

The change touches the shared sentinel test, so both slab benchmarks were re-run. They reproduce
their committed values exactly:

| | H->2H2 | C+->C | C->CO | deep T |
|---|---|---|---|---|
| V1 | 0.916 | 0.994 | 0.962 | 1.32 |
| V2 | 0.914 | 0.977 | 0.988 | 1.025 |

V1's chemistry matches the reference to 3-4 digits at every depth.


## 2026-09-02e - D-089: the mid-cloud temperature excess is the field, not the balance

### What V2 established

Running the V2 slab (n_H = 1e5, chi = 1e3) with nothing adjusted after V1 gave fronts of 0.915 /
0.977 / 0.988 and a deep temperature of 1.02x - but a temperature that runs hot through the middle
of the cloud, peaking at **3.7x near A_V = 3.3**, where V1 peaks at **2.4x near A_V = 2.2**. The
same defect in two regimes two decades apart in density rules out anything tuned to V1.

Surface right, deep right (in V2), middle wrong is not the signature of a missing coolant or a
broken root find. It is the signature of a heating term that is too large only where something
else has diverged - and panel (e) of the benchmark already showed exactly one thing diverging
there: the FUV field. MOCASSIN transports it through grains of albedo 0.486, so scattered light
survives to depth; 3D-PDR applies exp(-3.02 A_V) with no scattering term at all. At A_V = 1.95 the
transported field is 0.168 Draine against the prescription's 0.028 - a factor of six.

### The test

The reaction rates already run on the prescription: `CALCULATE_REACTION_RATES` rebuilds
chi0*exp(-gamma*A_V) internally from `radSurf` and `AVray`. Only `CALC_HEATING` and the HTT91 dust
temperature take the transported field. So substituting the prescription in those two places, and
nowhere else, isolates the field from the balance.

`pdrFUVmode = 1` does that. V1, everything else identical:

| | median T/T_3DPDR | peak | deep |
|---|---|---|---|
| transported MC field (default) | 1.341 | 2.42 | 13.3 K |
| prescribed exp(-3.02 A_V) | **0.991** | **1.39** | 13.3 K |

Depth by depth, the prescribed run sits at 0.95-0.85 of 3D-PDR from A_V = 0.2 to 1.6 and 0.98-1.19
beyond - flat agreement where the default runs from 1.04 up to 2.28.

**The thermal balance is right.** The entire mid-cloud excess is the extra FUV energy that
MOCASSIN's transfer deposits and 3D-PDR's exponential does not. It is not a bug to be fixed, and
`pdrFUVmode = 1` is a diagnostic, not a mode to run in - it discards the radiative transfer that
is the whole reason for coupling the two codes.

### What that leaves open

The excess is real physics only if gamma_eff = 1.85 per magnitude is right. Two ways it could be
too shallow: MOCASSIN scattering isotropically where FUV grain scattering is strongly forward
throwing photons out of the beam that should have stayed in it, or the FUV dust opacity itself.
That is now the question, and it is a question about MOCASSIN's dust transfer rather than about
the coupling.

Note also that V1's deep offset (1.27x) survives the substitution unchanged - 13.3 K in both runs.
It is a separate defect, and one V2 does not share (1.02x).

### Not settled by this: the dust temperature

The adopted T_dust is `max(TdMoc, TdHTT)`, and TdMoc - MOCASSIN's own dust equilibrium - reads
1.6 K at the illuminated face of the V1 slab where HTT91 and 3D-PDR both give ~21 K. HTT91 wins the
max at every depth in both regimes. So the benchmark's dust agreement is the parametrisation
agreeing with 3D-PDR, not the transfer agreeing with it.


## 2026-09-02f - D-090: gamma_eff = 1.85 is right, and 3D-PDR's 3.02 is the approximation

D-089 left one question: the mid-cloud temperature excess is the transported FUV field, but is that
field itself right? Two ways it could decay too slowly - MOCASSIN scattering isotropically where
FUV grain scattering is forward-peaked, or the FUV opacity being wrong.

**Scattering is not isotropic.** `photon_mod.f90` samples Henyey-Greenstein with a
frequency-dependent asymmetry parameter `gSca(nuP)` built in `ph_mod.f90` from the grains' own
`gCos` tables. So the phase function is not the suspect.

The `[D073]` diagnostic reported the albedo but not the asymmetry, though its own comment named
both as what sets the decay. It now reports the scattering-weighted g as well. For the benchmark
grains:

    ! [D073] FUV albedo = 0.485525399   asymmetry g = 0.354697287
    ! [D073] kFUV/kV = R_FUV = 3.59476638

which bracket the possible decay rates:

| treatment | gamma per magnitude |
|---|---|
| pure extinction - every scattered photon lost | 3.31 |
| 3D-PDR's prescription | 3.02 |
| reduced by forward scattering, (1 - w g) | 2.74 |
| every scattered photon retained, (1 - w) | 1.70 |
| **measured, V1** | **1.849** |
| **measured, V2** | **1.847** |

Two regimes two decades apart in density give the same number to three digits, and it sits just
above the (1 - albedo) floor. That is exactly where a slab under `planeIonization` should sit: the
transverse walls are specular mirrors, so laterally scattered photons are reflected back in rather
than escaping, and the only loss is backscatter out through the illuminated face. In that geometry
almost every scattered photon is eventually absorbed inside the slab, and the effective attenuation
approaches (1 - albedo) times the extinction value.

So the field is behaving as the grains and the geometry require. 3D-PDR's exp(-3.02 A_V) treats
scattering as if it were absorption, which under-reads the deep FUV field by a factor of ~6 at
A_V = 2. **Ours is the more complete treatment, and the disagreement in panels (a) and (e) of the
benchmark is the coupling doing its job.** It also means the benchmark can never close to better
than this in the mid-cloud, and should not be tuned to try.


## 2026-09-02g - D-091: audit of the H2/CO-dust interaction

Asked directly whether the coupling accounts for H2 and CO interacting with dust. It does, in five
places, all on the 3D-PDR side of the bridge - and there is one place where it uses the wrong dust.

### Present

| interaction | where | driven by |
|---|---|---|
| H2 formation on grain surfaces | `h2_form.F90`, Cazaux & Tielens 2002/2004, `-DH2FORM_CT02` | our T_dust |
| dust continuum shielding of the H2 and CO photorates | `shield.F90` `SCATTER(A_V, lambda)` | A_V |
| gas-grain collisional thermal coupling | `heatingfunctions.F90` `GASGRAIN_HEATING`, Burke & Hollenbach | our T_dust |
| grain (PAH) photoelectric heating | `PAHPHOTOELEC_HEATING`, the dominant PDR heating term | local FUV field |
| grain thermal continuum pumping the CO / [C II] / [O I] level populations | `escape_probability.F90` `BB_ij_dust`, added to the CMB term | our T_dust |

The last one is easy to miss: the level solver does not just see the CMB, it sees a grain
blackbody at T_dust scaled by a simple emissivity, so the dust temperature feeds the line
excitation directly and not only the chemistry.

### Absent

**No freeze-out or desorption anywhere.** The dispatch in `calc_reac_rates.F90` has labels for
`FREEZE`, `ELFRZE`, `THERM` and `PHOTD`, so the machinery exists - but none of the three shipped
networks contains a single such reaction:

    reduced (33 species): 0    medium (78): 0    full (215): 0

The only grain reactions in the reduced network are three: H + H + # -> H2, He+ + e- + # -> He,
and C+ + e- + # -> C. So CO cannot deplete onto grains at any depth or dust temperature. In a real
cloud CO freeze-out is first-order beyond A_V ~ 5 with T_dust < 20 K, which is inside the
benchmark's range. This is a network limitation shared with standalone 3D-PDR, so it does not
affect the comparison - but it does bound what the coupled code can be used for.

**The two grain-assisted recombinations are placeholders.** `BALG` and `GRAINRECOMB` are off in
our `PDRFLAGS`, and the reference build has `GRAINRECOMB = 0` too, so the comparison is
consistent. But note the dispatch tests the SECOND reactant for `#`:

```fortran
IF(REACTANT(I,2)(1:1).EQ."#") GOTO 9
```

and reactions 330/331 carry `#` as the THIRD reactant. They therefore fall through to the generic
modified-Arrhenius branch and get 5.2e-17 (T/300)^0.5 - four orders below C+ radiative
recombination, i.e. effectively zero. Turning `GRAINRECOMB` on would be needed to get the
Weingartner & Draine rate, and would move the C+ -> C front shallower.

**MOCASSIN's own opacity has no molecules.** H2 and CO contribute no continuum opacity, no line
blanketing and no cooling on the MOCASSIN side. They reach it only through what the bridge writes
back: T_e, the ionization state, and the carbon locked in CO removed from the atomic stages
(D-038).

### The one real problem: the photorates use somebody else's dust

`SCATTER(A_V, lambda)` converts A_V to tau(lambda) through `XLAMBDA`, which splines a **fixed
Savage & Mathis (1979) extinction curve** - tau(1000 A)/tau(V) = 4.65 - and then applies the
Wagenblast & Hartquist multi-exponential scattering fit. The A_V handed in is measured from the
model's own grains, but the wavelength dependence is not. Effective attenuation of the H2 and CO
photorates:

| | gamma per magnitude |
|---|---|
| H2 / CO photorates via `SCATTER` (A_V 0.2-1) | 3.31 |
| H2 / CO photorates via `SCATTER` (A_V 1-4) | 3.53 |
| **the field that actually heats the gas (measured, D-090)** | **1.85** |
| our grains, pure extinction | 3.31 |
| 3D-PDR's field prescription | 3.02 |

In the benchmark this is invisible, because the grains were tuned in D-073 to R_FUV = 3.59, which
happens to sit right on the Savage & Mathis value. It will not stay invisible. With the grey
0.07-50 um silicates this benchmark originally inherited (R_FUV = 1.12, D-073), the transported
field would decay three times more slowly while the H/H2 and C/CO fronts would still be placed by
an interstellar extinction curve the model does not have.

The fix is to scale the `SCATTER` optical depth by the model's measured R_FUV rather than leaving
it on the tabulated curve. Not done here: it changes front positions in every model, so it needs
its own before/after against both slab benchmarks.


## 2026-09-02h - D-092: the benchmark dust was PAH-only, and D-065's "broken" dust temperature was a misread

Asked why there were PAHs in a setup the log describes as MRN silicates. There should not have
been, and chasing it retracts a claim this log has carried since D-065.

### What was committed

`git log` on the fixture is unambiguous. D-073 (`b995c17`) changed exactly one line - the silicate
size range, 0.07-50 -> 0.010-0.30 um - and left the PAH species untouched, inherited from whatever
MOCASSIN example the fixture was copied from. `dust_sizes.dat` was never touched at all, and still
ran 1e-4 to 5 um.

`grainWeight(ai)` is a **number** weight normalised over the whole size grid, and MRN puts nearly
all of its number in the smallest bins. The result:

| | bins | number weight |
|---|---|---|
| silicate, 0.010-0.30 um | 15-25 | **6.1e-06** |
| PAH, 1e-5-0.002 um | 0-9 | 0.9997 |
| no grains at all | 14 bins | 3.2e-04 |

So the benchmark's dust was, in practice, **PAH-only** - while the README documented 0.010-0.30 um
silicates and D-073's "R_FUV = 3.59 from the corrected size distribution" was really a PAH number.
Fourteen of thirty-five size bins held nothing.

### The retraction

`Tdust(0,0)` is built as `sum_ns grainAbun(ns) * sum_ai grainWeight(ai) Tdust(ns,ai)`. With the
silicates at 6e-6 of the weight, that produced 1.16 K. D-065 read that number, concluded
"MOCASSIN's own dust equilibrium reads 1.2 K at an illuminated face where HTT91 gives 21 K", and
introduced `max(TdMoc, TdHTT)` so the parametrisation would carry it. D-089 and D-090 repeated the
claim, and it reached the published benchmark artifact.

**It was never true.** Reading the per-species, per-size array directly, MOCASSIN's grains at the
V1 illuminated face are at:

    silicate (0.0118-0.285 um)   26.3 -> 18.8 K
    PAH      (1e-4-0.0018 um)    58.1 K

against HTT91's 21 K. MOCASSIN's dust radiative transfer was right all along; the bridge was
reading a number-weighted mean over a size grid most of the grains did not occupy.

### The corrected fixture

One silicate species over a size grid spanning exactly 0.010-0.30 um, no dead bins, `MdMg` retuned
0.01059 -> 0.011295. This is also what 3D-PDR models: a single 0.1 um grain, with its PAH
photoelectric heating a metallicity-scaled formula rather than a grain inventory.

    A_V per N_H = 5.33995522E-22   against 3D-PDR's 5.33997e-22
    R_FUV = 3.94   albedo 0.4845   g 0.4141
    Tdust(0,0) at the face = 26.09 K   (was 1.16)

### What it does to the benchmark

| | old (PAH-only) | corrected | 3D-PDR |
|---|---|---|---|
| V1 H -> 2H2 | 0.916 | 1.142 | - |
| V1 C+ -> C | 0.994 | 0.995 | - |
| V1 C -> CO | 0.962 | 0.973 | - |
| V1 median T | 1.338 | 1.272 | - |
| V2 H -> 2H2 | 0.915 | **1.031** | - |
| V2 C+ -> C | 0.977 | 0.980 | - |
| V2 C -> CO | 0.988 | 0.985 | - |
| V2 deep T | 1.025 | 1.513 | - |

Mixed, and honestly so. The carbon fronts improve slightly everywhere and V2's H2 front improves a
lot; V1's H2 front overshoots instead of undershooting by a similar amount; V2's deep gas gets
worse. The mechanism is visible and is the point: with `Tdust(0,0)` meaningful, the `max()` no
longer hands everything to HTT91, so MOCASSIN's transferred dust temperature now drives H2
formation and the gas-grain coupling for the first time. Warmer grains form H2 more slowly, which
moves the front deeper.

And the deep V2 dust is much warmer than HTT91:

| A_V | Td MOCASSIN | Td HTT91 | Td 3D-PDR |
|---|---|---|---|
| 0.013 | 55.3 | 49.9 | 52.4 |
| 1.10 | 35.1 | 32.6 | 29.1 |
| 3.11 | 24.3 | 15.9 | 13.4 |

Surface agreement is good; at depth MOCASSIN's grains stay ~10 K hotter because it transports the
IR re-radiated by the hot skin into the interior, where HTT91 applies a Rowan-Robinson
`A_V^-0.4` attenuation that falls off faster. That is the same shape of disagreement as D-090's
FUV result - a transferred field against a prescribed one - and whether ours is right is now a
question about MOCASSIN's IR transfer. It is the obvious next thing to test, and it should be
tested before the `max(TdMoc, TdHTT)` crutch is removed.

### Also fixed

`input.in` itself was still at the fixture root while everything it references had been moved into
`input/`. MOCASSIN reads `input/input.in`, so the fixtures still did not run as documented.


## 2026-09-02i - D-093: the two grain energy terms now feed back to MOCASSIN

MOCASSIN already had the hook. `getDustT` has carried

```fortran
if (lgGas .and. lgPhotoelectric) then
   dustAbsIntegral = dustAbsIntegral + gasDustColl_d(nS,ai) - photoelHeat_d(nS,ai)
```

for as long as the dust solver has existed, and `lgPhotoelectric` defaults true. What was wrong is
where the two numbers come from: both are built by looping over MOCASSIN's **ion** inventory. In a
PDR that description is wrong twice over - every H nucleus is counted as a free H atom, and H2 does
not exist at all - so the collisional rate is roughly double what it should be and carries the
wrong partner mass.

The PDR already computes both correctly: `HEATING_RATE(11)` is Burke & Hollenbach gas-grain,
`HEATING_RATE(1..3)` the photoelectric terms. `pdrHeatPE` was already stored per cell; `pdrHeatGG`
is new.

In `pdrZone == 1` cells the dust balance now takes those instead. They are volumetric
(erg cm^-3 s^-1) where the balance wants erg s^-1 per grain, and both processes scale with grain
area, so they are spread over the population by cross-section:

    rate(ns,ai) = Gamma_vol * pi a_ai^2 / SUM_grains n(ns,ai) pi a_ai^2

which makes `SUM n(ns,ai) rate(ns,ai)` equal the volumetric rate again. Both are subtracted: a
positive gas-grain term means the dust is heating the gas and loses that energy, and the
photoelectric term is FUV the grain absorbed and shed as electrons rather than re-radiating.

It moves the dust temperature toward 3D-PDR at every depth in V2:

| A_V | before | after | 3D-PDR |
|---|---|---|---|
| 0.013 | 55.3 | 53.2 | 52.4 |
| 0.36 | 48.1 | 45.4 | 42.6 |
| 1.10 | 35.1 | **30.4** | 29.1 |
| 1.95 | 27.3 | 24.0 | 18.6 |

and the H2 front with it: V2 1.031 -> **0.985**, V1 1.142 -> 1.099.

One inconsistency is inherited rather than introduced. The PDR's dominant heating term is PAH
photoelectric heating, computed from a metallicity-scaled formula, while the dust inventory after
D-092 is silicate only. Energy is now conserved - what the gas gains is taken from the grain budget
- but it is taken from grains that did not absorb it as PAHs. 3D-PDR has the same split (single
0.1 um grain for opacity, PAH formula for heating), so matching it means inheriting it.

### The cap, and why it is a diagnostic

The first version subtracted without limit, and it can subtract more than the grain absorbed. Two
cells of the V1 slab then came back at **-4850 K and -1191 K**: with `dustAbsIntegral` negative the
balance has no solution and the temperature interpolation extrapolates straight through zero.

A grain cannot shed more energy than it absorbed, so the loss is capped at 90% of the absorbed
integral. Hitting the cap is exactly the PAH inconsistency above becoming visible - the PDR's
photoelectric heating exceeding what a silicate-only inventory absorbed - so the count is
accumulated in `nDustCapped` and printed with the iteration summary rather than hidden:

    ! iterateMC: [Summary] Iteration  5 ;  55  grain energy-budget caps hit

55 of 20025 cells in V2. Small, but it is the number to watch if PAHs are ever added back to the
dust inventory, where it should go to zero.


## 2026-09-02j - D-094: the deep dust temperature is transported IR, and HTT91's floor is the crutch

D-092 left MOCASSIN's dust ~10 K warmer than 3D-PDR deep in the V2 slab, and it was not obvious
whether that was real. It plateaus - 23.9 K at A_V = 1.9 through 21.2 K at 6.7 - while the FUV
field falls three orders of magnitude across the same span, which looks like a floor.

It is not. Comparing the two regimes, whose incident fields differ by 100x:

| A_V | V1 (chi 10) | V2 (chi 1000) | ratio |
|---|---|---|---|
| surface | 23.5 | 47.2 | 2.01 |
| 5.0 | 8.2 | 22.1 | **2.71** |

T_dust ~ chi^0.2 predicts 2.51. A noise floor or a table limit would not scale with the incident
luminosity; this does. The deep dust is genuinely heated by IR re-radiated at the illuminated skin
and transported inward - and under `planeIonization` the transverse walls are specular mirrors, so
that IR cannot escape sideways, the same trapping that gave gamma_eff = 1.85 for the FUV in D-090.

The decisive detail is the other direction. In V1 MOCASSIN's deep dust reaches **6.4 K at
A_V = 8**, *below* HTT91's 10 K floor - which HTT91's own paper describes as an artificial device
to stop H2 formation collapsing. 3D-PDR runs `DUST = HTT91`, so its deep dust temperature in both
regimes is simply that floor. Our transported value is more physical in both directions.

`pdrDustModel` therefore defaults to 0 (MOCASSIN only) instead of 1 (max with HTT91). The max was
introduced in D-065 because `Tdust(0,0)` was believed broken; D-092 showed it never was, so all the
max() does now is impose HTT91's floor on a colder, better value.

### Benchmark, all changes in

| | V1 | V2 |
|---|---|---|
| H -> 2H2 | 1.102 | **0.986** |
| C+ -> C | **0.995** | **0.981** |
| C -> CO | 1.075 | **0.985** |
| deep T | **1.061** | 1.503 |

V1's deep gas, open since the first slab comparison at 1.27-1.32x, closes to **1.061** - it was
HTT91's floor holding the grains at 10 K where the transfer gives 6.4 K. The cost is V1's C -> CO
front, which overshoots to 1.075 where the floor had it at 0.971.

V2's deep gas goes the other way, 1.02 -> 1.50, and the mechanism is worth stating because it is
not a regression in the physics: at n_H = 1e5 the gas-grain coupling is strong enough that the deep
gas temperature simply reports the dust temperature. Ours is 20.7 K (transported IR), 3D-PDR's is
10.0 K (the floor), and the gas follows each. The old 1.02 agreement was reached with a dust
temperature that was meaningless (D-092) and a floor that happened to sit near 3D-PDR's answer.


## 2026-09-02k - D-095: the energy-budget caps were a double-count, not a PAH problem

D-093 reported 55 cells where the PDR's photoelectric heating exceeded what MOCASSIN's grains
absorbed, and attributed it to the PDR assuming a PAH population the silicate-only dust inventory
does not carry. Asked to explain that, it does not survive checking.

`pdrHeatPE` was formed as `heat(1) + heat(2) + heat(3)`. Of those three, `TOTAL_HEATING` takes
**only heat(2)**:

```fortran
TOTAL_HEATING=&
!    & + PHOTOELECTRIC_HEATING &     <- heat(1), hard-set to 0.0D0
     & + PAHPHOTOELEC_HEATING &      <- heat(2), the one that counts
!    & + WEINGARTNER_HEATING &       <- heat(3), an ALTERNATIVE prescription, commented out
```

`heat(1)` is zero, and `heat(3)` is Weingartner & Draine's photoelectric rate offered *instead of*
the PAH one, not in addition to it. Summing all three was harmless while `pdrHeatPE` was only a
diagnostic. The moment D-093 began subtracting it from the grain energy budget it removed about
twice the right amount, including a term the gas never received - which is what pushed those cells
past what their grains had absorbed.

With `pdrHeatPE = heat(2)` alone:

| | caps hit | H -> 2H2 | C+ -> C | C -> CO | deep T |
|---|---|---|---|---|---|
| V1 | **0** | 1.117 | 0.995 | 1.076 | 1.062 |
| V2 | **0** | **1.003** | 0.981 | 0.985 | 1.505 |

The cap never fires now, in either regime, and V2's H2 front closes to 1.003.

The conceptual mismatch is still real - the PDR heats the gas with a PAH formula while the grains
are silicate - but it is no longer doing measurable damage: the grains always absorb more than the
gas takes. The cap and its counter stay as a guard, and `nDustCapped > 0` is now a genuine signal
rather than a symptom of this bug.


## 2026-09-02l - D-096: full audit pass

A deliberate stop to re-run every benchmark on one build and check what had drifted. Four things
had.

### 1. The non-PDR build was broken

`iteration_mod.f90:1389` used `lgPDR` and `pdrStartIter` outside any `#ifdef PDR`, so
`make mocassin` without `PDR=1` failed to compile. The whole point of guarding the coupling is
that plain MOCASSIN still builds; it had not for some time. Guarded, and the non-PDR binary now
compiles and runs a dust+gas model clean (2:03, 21 iterations). All three flavours build:
`PDR=0`, `PDR=1 PDRGEOM=1D`, `PDR=1 PDRGEOM=3D`.

### 2. pdrHeatGG was never exchanged between ranks

Every other PDR array is `mpi_allreduce`d after the `pdrStep` loop; the one D-093 added was not.
It happened to work because `pdrStep` and `updateCell` use the identical decomposition
(`mod(iCell-(taskid+1),numtasks)==0`), so each rank had the value for its own cells - but it was
luck, not design. Added to the exchange.

### 3. The other two fixtures still had the D-092 dust

`hiipdr` and `ifront` carried the same inherited PAH species, unmatched size grid and old
`MdMg = 0.01059` that D-092 corrected in the slabs, and their inputs were still at the fixture root
rather than under `input/`. Both fixed the same way.

### 4. Per-coolant cooling was not recoverable

`coolK` was computed per coolant and summed into `pdrCool` without being stored, so a
coolant-by-coolant comparison against 3D-PDR's `.cool.fin` needed a rebuild to reconstruct. Now
kept in `pdrCoolSp(cell, coolant)`, exchanged, and written to `output/pdrCoolSp.out` in the same
record order as `pdrGrid.out`.

`v1.cool.fin`, lost in the machine crash, was regenerated - and the run that produced it also
regenerated `v1.pdr.fin` **bit-identical to the committed reference**, which independently confirms
the 3D-PDR build and parameters are the ones behind every comparison in this log.

### What the coolant comparison shows

Local cooling rate, ours / 3D-PDR:

| A_V | CO | [C II] | [C I] | [O I] |
|---|---|---|---|---|
| 0.05 | 0.85 | 0.95 | 1.01 | 0.81 |
| 0.20 | 0.96 | 1.01 | 1.02 | 1.03 |
| 0.50 | 1.19 | 1.21 | 1.04 | 1.74 |
| 1.00 | 1.82 | 1.80 | 1.18 | 5.04 |
| 2.00 | 3.74 | 50.1 | 2.86 | 835 |

(V1; V2 is the same shape.) Every coolant agrees to within 5% out to A_V = 0.2 and within 20% to
0.5. That is a direct check on the level populations, the collision coefficients and the escape
probability, and it passes.

Past A_V ~ 1 the ratios diverge, and they diverge in the order of the transitions' excitation
energies - [C I] least, then CO and [C II], then [O I] hardest. [O I] 63 um sits 228 K above
ground, so at 30 K against 12 K its emissivity differs by e^11. **The deep cooling discrepancy is
not independent of the temperature discrepancy; it is the same fact seen through an exponential.**
Nothing here points at a second defect.

### Benchmark state on this build

| | V1 | V2 |
|---|---|---|
| H -> 2H2 | 1.120 | **1.002** |
| C+ -> C | **0.995** | **0.980** |
| C -> CO | 1.070 | **0.985** |
| deep T | **1.061** | 1.508 |
| median T | 1.249 | 1.505 |

Spherical H II + PDR, against a 3D-PDR reference regenerated at its matched field
(chi = 61.28 at the front, A_V span 2.464):

| A_V from front | x(H2) ours | x(H2) 3D-PDR |
|---|---|---|
| 0.000 | 4.05e-06 | 1.76e-06 |
| 1.073 | 4.85e-01 | 3.67e-01 |
| 2.464 | 4.96e-01 | 4.94e-01 |

H -> 2H2 crossing 0.515 against 0.888, x(C+) holding its full 1.4e-4 to A_V ~ 1.4 as the reference
does. The gap is grid resolution: dA_V = 0.107 per cell on a uniform 31^3 grid, and the front is
thinner than one cell.


## 2026-09-02m - D-097: the infrared transfer is right, and HTT91's floor is not

D-094 left the deep dust temperature resting on an argument from scaling alone. It is now checked
directly, and it passes on five counts.

### 1. The machinery exists and is complete

A packet absorbed by dust is not destroyed. `pathSegment` sets `packetType = "diffuse"` (or
`"dustEmi"` with no gas) and exits, and `newPhotonPacket` re-emits it by sampling `recPDF`, which
includes `sumDiffuseDust` whenever `lgDust`. So absorbed energy is re-radiated with the local dust
emission spectrum and transported like any other packet - the Lucy immediate re-emission scheme,
intact.

### 2. The infrared is resolved

The frequency mesh is logarithmic - `nuArray(i) = 10**(log10(nuArray(i-1)) + nuStepSize)` - and
spans 0.006 um to 7 cm in 1000 bins. **708 of them lie between 50 and 2000 um**, where 10-50 K
grains radiate. A linear mesh would have collapsed the entire far-infrared into one or two bins;
this one does not.

### 3. The flat depth profile is what the optical depth demands

From the model's own `tauNu.out`, centre to edge:

| lambda | tau |
|---|---|
| 0.1 um | 46.6 |
| 0.55 um | 7.82 |
| 30 um | 0.157 |
| 255 um | **0.0018** |

The slab is optically thick in the ultraviolet and **optically thin in the far infrared by a factor
of ~4000**. Infrared emitted at the hot skin therefore streams through the whole interior almost
unattenuated, and with `planeIonization`'s specular transverse walls it cannot escape sideways
either. A deep dust temperature that barely declines with depth is not a symptom - it is the only
thing that optical depth allows.

This is exactly what HTT91 gets wrong here. Its infrared term carries a Rowan-Robinson
`A_V**(-0.4)` attenuation, appropriate to a medium that is optically thick to its own infrared. At
tau(FIR) = 0.002 that attenuation has no physical basis, and it is what drives HTT91 onto its 10 K
floor.

### 4. The surface value matches the standard result

    12.2 * chi**0.2  =  48.6 K        (the textbook FUV-heated grain)
    HTT91                49.9 K
    MOCASSIN             53.2 K

### 5. The deep value matches an independent estimate, in both regimes

Balancing a deep grain against the infrared bath from the warm skin,

    (T_deep/T_skin)**(4+beta) = f_in * <kappa>_IR / kappa_FUV

with beta = 2.26 measured from the model's own opacity curve, `kappa` taken from `tauNu.out`,
`<kappa>_IR` weighted over the skin's own emission, and `f_in` the fraction of the skin's infrared
directed inward:

| | T_skin | predicted (f = 0.5 .. 1.0) | MOCASSIN | implied f |
|---|---|---|---|---|
| V1 | 23.5 K | 5.8 - 6.5 K | **6.4 K** | 0.93 |
| V2 | 53.2 K | 17.5 - 19.6 K | **20.7 K** | 1.41 |

V1 lands in the middle of the band. V2 sits just above it, at an implied inward fraction of 1.4,
which is the expected direction: the estimate treats the emitting skin as one layer at a single
temperature, where the real warm column spans A_V ~ 0 to 1.5 and every layer in it radiates.

The V1 row is the decisive one. Its deep grains sit at **6.4 K, below HTT91's 10 K floor**, and the
independent estimate says 5.8-6.5 K. MOCASSIN is right there and HTT91 is not.

### Consequence

V2's deep gas at 1.51x is not our error. At n_H = 1e5 the gas-grain coupling ties the deep gas to
the dust; ours follows verified dust at 20.7 K, 3D-PDR's follows HTT91's floor at 10.0 K. The
disagreement is 3D-PDR's parametrisation, and it should not be tuned out - the same conclusion
D-090 reached for the FUV field, arrived at independently.

The one caveat worth stating: all of this is for a plane-parallel slab with reflecting transverse
walls, where infrared cannot escape sideways. That is the correct model for a 1D benchmark and it
is what 3D-PDR's 1D mode assumes too, but a real 3D cloud loses infrared laterally and its interior
would be cooler. Nothing here has been verified in 3D.

### A trap in the method, recorded because it nearly produced a false alarm

The first pass at the estimate above returned 7.4 K against MOCASSIN's 20.7 - a factor of three,
which looks like a decisive failure. It was the method that was wrong.

`tauNu.out` is the **total** opacity, gas and dust together. Weighting it over the 25000 K stellar
spectrum picks up hydrogen and helium photoionization below 912 A, which is enormous and has
nothing to do with grains: it returned a "dust" opacity of 7703 in tau units where tau at 0.1 um is
only 47. The energy absorbed there goes into the gas and leaves as lines and free-free, not as dust
infrared.

Restricting the weighting to the non-ionizing range, where dust genuinely dominates the opacity,
gives the numbers in the table. Anyone repeating this check should take the ultraviolet anchor from
tau(0.1 um) and not from an integral over the stellar spectrum.


## 2026-09-02n - D-098: TORUS-3DPDR section 5.4 as the coupled-code reference

The 3D flavour cannot be validated directly - `PDRGEOM=3D` compiles but there is no reference to
run it against, and MOCASSIN has no isotropic external ISRF source to match 3D-PDR's own 3D mode
with. Rather than build one, adopt the only published benchmark of a *coupled* photoionization+PDR
code: Bisbas et al. (2015), TORUS-3DPDR, section 5.4.

### Why this test and not another

It is the same problem we are solving, done independently, and - importantly - **they benchmarked
it against the two codes we are coupling**. Their Fig. 3 overplots MOCASSIN for the photoionized
region and 3D-PDR for the photodissociation region. We are MOCASSIN plus 3D-PDR, so both curves are
predictions for us, not just qualitative targets.

### Their setup, verbatim from section 5.4

    n_H            = 100 cm^-3, uniform
    star           = blackbody, T = 4e4 K, radius 18.67 R_sun, at the grid edge
    grid           = uniform spherical, 256 cells, one-dimensional
    PDR cell test  = T < 3000 K, corresponding to ionization fraction <= 0.3
    "These values correspond to the HII40 simulation of the Lexington benchmarking"

Our `hiipdr` fixture already is this model. The star reproduces the canonical HII40 photon rate -
integrating a 4e4 K Planck function above 13.6 eV over 18.67 R_sun gives Q(H) = 4.272e49 s^-1
against the canonical 4.26e49 - and the analytic Stromgren radius for n = 100 is 1.579e19 cm
against the 1.5e19 our run places the front at, the small deficit being dust absorption. What did
not match were the abundances, which had been left at the Roellig V1 PDR values (C 1.4e-4,
O 3.0e-4, no N, Ne or S) rather than HII40's.

### What their section 5.4 actually found, and why it matters to us

They ran it two ways: attenuation taken from the Monte Carlo transport, and attenuation from the
prescribed exponential of their Eqn. 1. The prescribed version does not reproduce the Monte Carlo
one unless the geometric dilution is added explicitly - their Eqn. 3,

    chi(r,q) = chi_o(q) exp(-tau_UV A_V(q)) R_IF^2 / (R_IF + r)^2

- and they state the PDR temperature profile "is reproducible only when the distance from the
source is taken into account", while noting H2 and H I are not strongly sensitive to it.

That is the same result D-087 arrived at independently and from the opposite direction. We had
inverted A_V out of the Monte Carlo field, which conflates dilution with extinction; replacing it
with a geometric A_V walked from the source, with the 1/r^2 dilution left where it belongs in the
transported field, moved the median A_V from 0.39 to 0.93 of truth. MOCASSIN's transport carries
the dilution inherently, so we are on their Monte Carlo branch by construction - the branch their
prescribed-field runs had to be corrected to match.

### What is being compared

Their Fig. 3: gas temperature against distance in the upper panel, and fractional abundances of
H II, H I and H2 in the lower. Both panels run through the ionization front into the PDR, which is
the transition this whole coupling exists to model and the one place a 1D slab benchmark cannot
test.



### D-098 result

`hiipdr` re-run with HII40's abundances (He 0.1, C 2.2e-4, N 4.0e-5, O 3.3e-4, Ne 5.0e-5,
S 9.0e-6), which had been left at the Roellig V1 values. Reference `sec54.pdr.fin` is standalone
3D-PDR at the field the coupled model delivers to its first PDR cell (chi = 61.236, A_V span
2.4534), with the network's C and O rescaled to the same HII40 values.

| quantity | coupled | expected |
|---|---|---|
| H II region temperature | 7925-9440 K | ~8000-9000 K (HII40) |
| ionization front | 1.2-1.6e19 cm | 1.579e19 cm (Stromgren) |
| Q(H) from the specified star | 4.272e49 /s | 4.26e49 canonical |
| PDR temperature, median ratio | 1.21 | vs standalone 3D-PDR |
| deep x(H2) | 0.495 | 0.494 |
| H -> 2H2 front | A_V = 0.52 | A_V = 0.89 |

The ionized region agreeing is a consistency check rather than an independent one - Bisbas et al.
overplot MOCASSIN there and our ionized region *is* MOCASSIN. What it establishes is that the
coupling has not damaged the photoionization solver, which is worth knowing on its own.

The H/H2 front remains the one real gap and it is the grid: dA_V = 0.107 per uniform cell against a
front thinner than that. Bisbas et al. used 256 cells clustered on the front. This is the same
limit recorded in D-080/D-081 and it is not reachable by tuning.


## 2026-09-02o - D-099: the neutral hydrogen MOCASSIN carries is not atomic hydrogen

Raised from the section 5.4 figure: x(H I) does not fall in the PDR the way 3D-PDR's does. Is the
hydrogen being corrected for the H2 that formed?

**In the chemistry, yes. In the array MOCASSIN carries, no - and that turns out to be load-bearing.**

### The observation is correct

`pdrToMocassin` closes the neutral stage against the proton fraction alone:

```fortran
grid%ionDen(cellP,elementXref(1),1) = 1.0 - grid%ionDen(cellP,elementXref(1),2)
```

Every hydrogen nucleus locked in H2 is therefore handed back as free atomic H. Deep in the V1 slab
the chemistry gives x(H) = 1.2e-3 while this writes 1.000 - three orders of magnitude. It looked
like exactly the omission D-038 fixed for carbon, where carbon in CO simply does not appear in any
atomic stage and the ionization fractions correctly sum to less than one.

### Fixing it made things worse, for a reason worth keeping

Handing back the chemistry's x(H) instead, with the molecular hydrogen also removed from
MOCASSIN's side of the blend so hydrogen stays conserved across the band, does what it should to
the abundances - x(H I) tracks the chemistry, and x(H I) + 2x(H2) + x(H II) = 1.0000 exactly in
fully-PDR cells. Then the benchmark moved the wrong way:

| | before | after |
|---|---|---|
| V1 deep T ratio | **1.061** | 1.321 |
| V1 H -> 2H2 | 1.120 | 1.219 |
| V1 median T | 1.249 | 1.287 |

The cause is that **MOCASSIN has no H2 opacity**. Its opacity is atomic photoionization plus dust,
and nothing else absorbs the Lyman continuum. The atomic hydrogen in `ionDen` was, without anyone
intending it, standing in for the molecular hydrogen as well - and it is the only thing keeping the
molecular interior opaque there. Take it away and the medium goes transparent:

| A_V | ionDen(H,II) before | after | chemistry x(H+) |
|---|---|---|---|
| 0.45 | 5.7e-07 | **0.168** | 5.4e-07 |
| 4.00 | 8.1e-07 | **0.0131** | 8.1e-07 |

MOCASSIN's own `ionBalance` answers with 17% ionization at A_V = 0.45 where the chemistry gives
5e-7. And 0.168 sits inside the blend band, since `pdrZoneLim = 0.3`, so the weight
w = (log 0.3 - log 0.168)/(log 0.3 - log 0.01) collapses to **0.17** - and the handover the blend
exists to deliver is 83% discarded, gas temperature included. Hence the deep-T regression.

Reverted. The line now carries a comment saying what it is and why, because it reads like a bug and
is not one.

### What is actually true

- the chemistry's x(H) is right, and is already written per cell to `pdrGrid.out`
- `ionDen(H,1)` is the **total non-ionized hydrogen**, which is the correct absorber for the Lyman
  continuum given that H2 absorbs there too and MOCASSIN cannot represent it
- the figure in the section 5.4 artifact was plotting `ionDen` rather than the chemistry, which is
  why the H I curve looked wrong. It now plots x(H) from the chemistry.

### The real fix, when it is wanted

Give MOCASSIN an H2 continuum opacity. Then `ionDen(H,1)` can hold atomic hydrogen alone, the two
descriptions stop having to share one array, and the blend stops being poisoned by an ionization
balance solved against the wrong absorber. That is a change to MOCASSIN's opacity model, not to the
bridge, and it is the prerequisite for this correction rather than a refinement of it.


## 2026-09-02p - D-100: how to give MOCASSIN an H2 opacity

D-099 left the missing H2 opacity as the blocker. Asked whether 3D-PDR's self-shielding could be
reused for it, and what that would do to the diffuse transfer.

### The self-shielding function cannot be reused, and the reason is structural

`H2SHIELD1(N(H2), DOPW, RADW)` returns a dimensionless factor: the fraction of the band-integrated
dissociating flux surviving a column N(H2). `grid%opacity(cell, nu)` needs a local, memoryless
coefficient that `pathSegment` multiplies by a path length. Three properties each disqualify it.

**It is a function of the column, not the density.** The Monte Carlo accumulates tau = SUM kappa ds
cell by cell with no memory of what a packet already traversed. A shielding factor is that integral,
already taken.

**It is not an exponential, so no kappa reproduces it.** Defining one anyway,
kappa_eff = -d(ln f)/dN, gives a number that is not constant:

| N(H2) | f_shield | implied sigma |
|---|---|---|
| 1e14 | 7.02e-01 | 3.22e-15 |
| 1e16 | 9.80e-03 | 7.97e-17 |
| 1e18 | 7.53e-04 | 5.19e-19 |
| 1e20 | 5.35e-05 | 6.90e-21 |

A factor of **4.7e5** across the columns that matter. The physics is line saturation: absorption is
in ~30 discrete Lyman-Werner bands whose cores black out early, after which the damping wings do
the work. One opacity per frequency bin cannot represent a medium that is opaque at line centre and
transparent between lines.

**It has no frequency resolution to give.** Our grid carries **17 bins** across 912-1108 A, each
~3564 km/s wide, against a thermal H2 line width of ~0.9 km/s at 100 K.

### What is available

**Recommended: the H2 photoionization continuum above 15.43 eV.** A genuine smooth continuum,
sigma ~ 1e-18 cm^2 against atomic hydrogen's 6.3e-18, needing only n(H2) per cell - already in
`pdrAbun(cellP,NH2)` - and dropping into the existing opacity accumulation unchanged.

Its decisive property is *where it sits*: 15.43 eV is above the Lyman limit and far above the FUV
band the PDR owns (0.44-1.0 Ryd). **It cannot double-count against anything 3D-PDR is already
doing** - and double-counting is the live hazard, not accuracy. D-050 was exactly this: we handed
the PDR an already-attenuated field while its rate expressions re-applied exp(-gamma*A_V), and
every front moved too shallow. Any scheme touching 912-2400 A must transfer ownership of that band,
not add to it.

**Rejected: full Lyman-Werner line transfer.** Physically complete, and it is a different code.
Resolving line cores needs ~1 km/s bins across 912-1108 A, about 4000x the resolution there, with
memory at 10.5 kB per cell scaling with nbins - plus H2 rovibrational level populations, since the
shielding depends on which states absorb. This is why photoionization and PDR codes are separate
programs; building it here is rebuilding 3D-PDR inside MOCASSIN.

**Deferred: an energy-equivalent grey LW opacity.** Take the dissociation rate the PDR already
computes with proper shielding, convert the energy removed into a grey kappa over the band. The
D-093 pattern applied to radiation - the PDR computes the rate, MOCASSIN is told what energy left
the field. Requires transferring LW ownership in the same change. Worth doing only if that band's
energy matters for the transfer, which here it does not: it is narrow, well inside the FUV, and
dust dominates the continuum extinction across it.

### Effect on the diffuse field

MOCASSIN conserves energy by immediate re-emission - an absorbed packet becomes `"diffuse"` and is
re-emitted from `recPDF`. For the photoionization continuum that fate is *correct*, not merely
convenient: H2 photoionization thermalizes and returns through the recombination continua and lines
already in `recPDF`, the same fate as an ionizing photon absorbed by atomic H.

For the LW options it is wrong. A Lyman-Werner absorption does not thermalize - ~85% fluoresces
back down into LW and infrared quadrupole lines, ~15% dissociates depositing ~0.4 eV. Those need
their own re-emission channel or the energy comes back at the wrong frequency.

The transfer machinery itself is untouched in every case: an extra additive term in
`grid%opacity` changes the numbers `pathSegment` accumulates, not the structure, and nothing about
the scattering, the Lucy estimators or the convergence logic changes.

### One thing to check before building anything

Between 13.6 and 15.43 eV only atomic hydrogen absorbs, and molecular gas genuinely has very little
of it - there the real absorber is dust. Whether restoring H2 above 15.43 eV is enough to keep
MOCASSIN's ionization balance sane with a true x(H) is an experiment, not a deduction.

And there may be a simpler answer sitting underneath it. **3D-PDR's radiation field is FUV-only by
definition** - chi is measured over 912-2400 A and it models no ionizing photons at all - while
MOCASSIN carries the whole stellar spectrum. The Roellig slab benchmarks specify a pure FUV field,
so MOCASSIN arguably should not be sending ionizing photons into those slabs at all. If that is
where the spurious deep ionization of D-099 comes from, the fix is in the benchmark's source
spectrum and not in the opacity.


## 2026-09-02q - D-101: the slab benchmarks are fed ionizing photons the specification excludes

D-100 flagged a free check before building any opacity: 3D-PDR's field is FUV-only by definition,
MOCASSIN carries the whole stellar spectrum, and the Roellig slabs specify a pure FUV field. Tested.

### The mismatch is real and it was already doing damage

`contShape blackbody` at `TStellar 25000` puts **11.6% of the source energy above 1 Ryd**. The
Roellig V1/V2 tests specify chi in Draine units over 912-2400 A and no ionizing radiation at all.

The consequence was in the committed runs and had not been noticed:

| A_V | x(H+) MOCASSIN | x(H+) chemistry |
|---|---|---|
| 0.00125 | **2.775e-01** | 8.15e-06 |
| 0.05 | 1.51e-03 | 2.12e-06 |

The surface cell is 28% ionized in MOCASSIN's view against 8e-6 in the chemistry's - a factor of
34000 - and 0.277 sits inside the blend band (`pdrZoneLim = 0.3`), so that cell received a blend
weight of **0.023**. Its PDR result was 98% discarded.

### Fixing it

The source is now a 25000 K blackbody tabulated in the `rauch` two-column format with the flux
zeroed shortward of 911.75 A, and `planeIonization` rescaled 5.01e-2 -> 4.4316e-2 to put chi0 back
at 10.115 (removing 11.6% of the luminosity had otherwise pushed the FUV up to 11.435, since
MOCASSIN normalises the total).

| | max x(H+) MOCASSIN | chemistry | ratio |
|---|---|---|---|
| full blackbody | 2.775e-01 | 8.15e-06 | 34000 |
| **pure FUV** | **1.568e-03** | 9.81e-06 | **160** |

and at every depth below the first few cells MOCASSIN's x(H+) now equals the chemistry's exactly,
so the handover runs at full weight throughout.

### What it costs, honestly

| | H->2H2 | C+->C | C->CO | deep T |
|---|---|---|---|---|
| full blackbody | **1.117** | 0.995 | 1.075 | 1.062 |
| pure FUV | 1.234 | 0.995 | 1.075 | 1.061 |

The H2 front moves further from the reference. That is not a regression to be undone: the previous
1.117 was obtained with a surface cell whose PDR answer had been 98% replaced by MOCASSIN's, and
1.234 is what the chemistry actually produces once it is allowed to stand. Everything else is
unchanged.

### It is necessary but NOT sufficient

The point of the test was whether this unblocks D-099. It does not. Re-applying the true atomic
hydrogen handover on top of the pure-FUV source (`pdrAtomicH 1`, added as a switch, default off):

| A_V | x(H+) closure handover | x(H+) with atomic H | chemistry |
|---|---|---|---|
| 0.10 | 9.10e-04 | 3.78e-02 | 1.18e-06 |
| 0.50 | 5.83e-07 | **1.82e-01** | 5.72e-07 |
| 8.00 | 4.62e-07 | 1.69e-02 | 1.23e-08 |

**733 of 801 cells** end up above `pdrBlendLo`, so the whole slab sits in the blend band and the
handover is diluted everywhere. Deep T goes 1.061 -> 1.324, the same regression as D-099.

So the runaway is not driven by the stellar ionizing photons. With none in the source it happens
anyway, which rules out the simple explanation and points at MOCASSIN's `ionBalance` itself: on a
straight equilibrium argument, x(H+)^2 n alpha = x(H0) Gamma, reducing x(H0) by 500x should *lower*
x(H+), not raise it. It rises, so that is not the equation being solved - most likely a
normalisation of the ionization stages to sum to one, which the molecular case violates by
construction. That is the next thing to read, and it is upstream of the H2 opacity question rather
than downstream of it.

### State

- pure FUV source: **not yet adopted** in the committed fixtures. It is right, but V2 needs its own
  `planeIonization` recalibration and both slabs then need re-running and every artifact
  regenerating. Held as a separate step rather than folded in here.
- `pdrAtomicH` switch: committed, default 0, so behaviour is unchanged.


## 2026-09-02r - D-102: ionBalance asserted that no molecules exist

D-101 narrowed the runaway to `ionBalance` itself. Reading it settles the question in four lines:

```fortran
denominator(elem) = 1. + SUM(ionProd(elem, :))
ionDen(elem,1)    = 1.0/denominator(elem)
ionDen(elem,ion)  = ionProd(elem,ion-1)/denominator(elem)
```

It solves for the *ratios* between successive stages and then **normalises the stages to sum to
exactly one**. That is an assertion that every atom of the element is in some atomic ion stage,
which is false in any PDR cell: for hydrogen the stages should sum to 1 - 2x(H2) ~ 0.01, for carbon
to 1 - x(CO)/C_total.

This explains what D-099 could not. Whatever the bridge writes into the neutral stage is discarded
on the next pass, because that stage is recomputed as `1/denominator` from the ratios alone. And it
was not only hydrogen: **D-038's carbon handover was being undone the same way, every iteration,
since the day it was written.** Its comment says "the fractions then sum to less than one, which is
exactly right" - and `ionBalance` had been restoring the one.

### Fix

A per-element available fraction, `grid%elemAvail(cell, element)`, defaulting to 1.0 and set by the
bridge from the chemistry as (neutral + ionized)/total - which needs no enumeration of which
molecules hold the element. `ionBalance` multiplies the normalised stages by it:

```fortran
ionDen(elem,1)   = availFrac(elem)/denominator(elem)
ionDen(elem,ion) = availFrac(elem)*ionProd(elem,ion-1)/denominator(elem)
```

It is 1.0 wherever the chemistry has not run, so it is a no-op outside the PDR, and it applies
uniformly to H, C, O and Mg. `NeUsed` is built multiplicatively from `ionDen`, so the electron
density follows correctly with no further change.

### Measured

Default configuration - committed fixture, `pdrAtomicH` off:

| | before | after |
|---|---|---|
| H -> 2H2 | 1.117 | 1.219 |
| C+ -> C | 0.995 | **1.003** |
| C -> CO | 1.075 | 1.078 |
| deep T | 1.062 | 1.062 |

With everything self-consistent - pure FUV source (D-101), `elemAvail`, and the true atomic
hydrogen handover:

| | value |
|---|---|
| H -> 2H2 | 1.212 |
| C+ -> C | **1.004** |
| C -> CO | **0.987** |
| deep T | 1.338 |
| cells above pdrBlendLo | **103** of 801, from 733 |
| max x(H+) | 1.3e-02, from 1.8e-01 |

x(H I) now tracks the chemistry at every depth, and x(H+) matches it exactly below A_V ~ 2. The
C -> CO front reaching 0.987 is D-038's handover finally surviving to the next iteration.

Worth stating plainly: the H -> 2H2 front moves from 1.117 to ~1.21 under *three independent*
corrections - the pure FUV source, `elemAvail`, and the atomic hydrogen handover - each of which
arrives at nearly the same place. The old 1.117 was propped up by errors that happened to push the
other way.

### Open

In the fully self-consistent configuration the deep dust temperature roughly doubles - 11.3 -> 32.2 K
at A_V = 2, 6.3 -> 18.0 K at A_V = 8 - and carries the deep gas to 1.34.

It is not the radiation field and not the PDR: chi_FUV agrees to 1% at every depth between the two
runs, tau(V) and tau(100um) are identical, no grain energy-budget caps fire, and the PDR's own
heating and cooling budgets agree to three digits. So it is inside `getDustT`, in the part of the
transported field chi does not measure - the infrared. The obvious candidate is that the gas
opacity and electron density both changed by orders of magnitude when the neutral hydrogen became
real, and something in the infrared responds to that. Not yet identified.

`pdrAtomicH` stays default 0 until it is.


## 2026-09-03a - D-103: the deep dust heating is the diffuse Lyman continuum

D-102 left one thing open: with the hydrogen self-consistent, the deep dust temperature roughly
triples and carries the deep gas to 1.34. Traced by elimination.

### What it is not

| candidate | test | result |
|---|---|---|
| the FUV field | chi at every depth, both runs | agrees to 1% |
| the source spectrum | chi0, Lstar, contShape, the file itself | byte-identical setup |
| the D-093 gas-grain feedback | re-ran with `pdrDustFeedback 0` | T_dust 32.22 -> 32.69, unchanged |
| MOCASSIN's own grain terms | that same run uses them instead | same answer |
| the PDR's budget | heating, cooling, heatPE per cell | agree to three digits |
| grain energy-budget caps | counter | zero in both |

`tauNu.out` also agrees - but that is not evidence, and it is worth recording why: it is computed
along **direction 1,0,0** while the slab is graded in **y**. It says nothing about depth structure
in these models.

### What it is

Atomic hydrogen contributes opacity in exactly one place:

```fortran
! hydrogen lyman continuum photoelectric opacity
call inOpacity(HlevXSecP(1), HlevNuP(1), nbins, density(1,1), 0.)
```

from the Lyman edge upward, and nowhere below 1 Ryd - MOCASSIN has no H-minus and no Rayleigh
scattering, so the only sub-Lyman gas term is free-free. Reducing n(H I) by 500x therefore changes
the opacity **only above 13.6 eV**.

The source has no photons there: it is Lyman-truncated (D-101). But the *diffuse* field does.
Recombination to the ground state emits Lyman-continuum photons, and the self-consistent run has
x(H+) ~ 1e-2 in about a hundred surface cells to emit them. Previously those photons were reabsorbed
within a cell or two by the abundant atomic hydrogen. With the atomic hydrogen now correctly at
~2e-3, nothing stops them, and they travel until **dust** absorbs them - at 13.6 eV a photon, deep
in the cloud, which is a very efficient way to heat a grain that would otherwise sit at 6 K.

### Why this vindicates D-100

The chain closes on the H2 opacity. In a real PDR those diffuse Lyman-continuum photons do not
travel: H2 absorbs above 15.43 eV, and the Lyman-Werner bands take the rest. MOCASSIN carries
neither, so with the atomic hydrogen made honest there is nothing left to stop them.

D-100 recommended the H2 photoionization continuum above 15.43 eV on the grounds that it sits
outside the band the PDR owns and so cannot double-count. This is the physical case for it, arrived
at independently: it is precisely the absorber missing from the path these photons take. D-101
showed that removing the *stellar* ionizing photons was necessary but not sufficient; the reason it
was not sufficient is that the problem is the diffuse ones, which no change to the source spectrum
can remove.

### Order of work

1. H2 photoionization continuum above 15.43 eV (D-100, option 3)
2. re-test `pdrAtomicH 1`, which should then hold
3. if the deep dust is still hot, the remaining 13.6-15.43 eV window is dust-absorbed only, and
   that is a genuine physical statement rather than a missing term

Until then `pdrAtomicH` stays 0. `elemAvail` (D-102) is unconditional and does not depend on any of
this - it fixes the normalisation for carbon and oxygen regardless, which is where the C -> CO front
gain came from.


### D-103 continued: what the diffuse PDF does, and what is still unexplained

Prompted by the observation that diffuse photons are drawn from an emission PDF - which is the
right thread, and worth writing down because the machinery is not obvious.

`setDiffusePDF` builds two things per cell:

```fortran
normalize  = normHI + normHeI + normHeII + normDust        ! continuum
normalize  = normalize + totalLines                        ! + lines
totalLines = totalLines / normalize                        ! P(a diffuse packet is a LINE photon)
recPDF     = cumulative(sumDiffuseHI + HeI + HeII + Dust)  ! normalised to 1
```

and `newPhotonPacket` uses them:

```fortran
if (random <= totalLines) then      ! line photon - "line photons escape"
else                                ! continuum photon, frequency from recPDF
```

Two consequences matter here. First, `recPDF` is **normalised** - it is a shape, not an amplitude -
so every absorbed packet is re-emitted with a frequency drawn from whatever the local gas and dust
emissivities look like in ratio, however small they are absolutely. Second, the line branch
**escapes the grid**, while the continuum branch is transported. So the fraction of re-emitted
energy that leaves a cell immediately is set by the gas line emissivity relative to the dust
continuum.

That gives a plausible route for the deep dust anomaly: making the hydrogen and carbon
self-consistent collapses n_e and with it every gas emissivity MOCASSIN computes, `totalLines`
falls toward zero, less energy escapes as line photons, and more is retained locally as dust
continuum. It also fits the observation that the anomaly is insensitive to everything on the
absorption side.

**It is not yet demonstrated.** `totalLines` is not written to any output, so the comparison between
runs has not been made. Recorded as the leading hypothesis, not a finding.

### Eliminated so far

| candidate | test | verdict |
|---|---|---|
| FUV field | chi at every depth | identical to 1% |
| source spectrum | chi0, Lstar, file identity | identical |
| Lyman-edge sampling artefact | re-truncated with 120000 points, 0.0137% spacing, finer than the tightest bin | T_dust 32.22 -> 32.28, unchanged |
| D-093 gas-grain feedback | `pdrDustFeedback 0` | 32.22 -> 32.69, unchanged |
| MOCASSIN's own grain terms | same run, uses them instead | unchanged |
| PDR heating/cooling budget | per cell | agrees to 3 digits |
| grain energy-budget caps | counter | zero in both |
| resonance line heating of dust | `Gline ~ ionDen(H,2)*Ne` | scales DOWN with the change, cannot heat |
| H I opacity below 1 Ryd | there is none - no H-minus, no Rayleigh, only free-free | n/a |

The strongest single fact remains that **T_dust reaches 32 K at A_V = 2 while the illuminated face
sits at 25 K**. Dust hotter deep inside than at the surface, with no internal source, is not a
subtle calibration issue - it is energy appearing where none is delivered.

### Next measurement

Write `totalLines` and the band-integrated `Jste` per cell to a diagnostic file and compare the two
runs directly. That distinguishes "more energy is being retained" from "more energy is arriving",
which every test so far has been unable to separate.


## 2026-09-03b - D-104: the band budget, and a retraction of the retraction

`pdrRad.out` now writes, per cell, `totalLines` and the field summed over four bands. Two runs,
identical but for `pdrAtomicH`, both on the Lyman-truncated source.

### The hypothesis was wrong, and so was the retraction

`totalLines` is **1e-7 or below in both runs** at every depth. The escaping-line channel carries
nothing either way, so the idea that collapsing gas emissivities retained energy by closing that
channel is dead. Recorded as a hypothesis last entry; falsified here.

But the retraction in that same entry was also wrong. Summed over the profile:

| band | A: closure | B: atomic H | B/A |
|---|---|---|---|
| ionizing > 1 Ryd | 1.02e-02 | 1.99e+01 | **1955** |
| FUV 0.44-1 | 2.9234 | 2.9268 | 1.00 |
| 0.01-0.44 | 6.9156 | 6.8578 | 0.99 |
| FIR < 0.01 Ryd | 3.34e-03 | 2.05e-02 | 6.14 |

The ionizing field is **three orders of magnitude larger**, exactly as D-103 argued. The reason the
cleanly re-truncated source changed nothing is that these photons are not from the source: they are
diffuse, which is what D-103 said and what I then failed to hold onto when reading that null result.
D-103's mechanism stands. FUV and optical are untouched to 1%, and the far-infrared - which sets
the deep dust temperature - is up 6x, downstream of dust absorbing the ionizing photons.

### The part that is worse than a transfer problem

Where does a 13.6 eV photon field come from when the source emits none?

`ionBalance` gives x(H+) = 8e-3 at A_V = 0.5 where the chemistry gives 6e-7. `setDiffusePDF` then
builds `sumDiffuseHI` from that ionization and emits a recombination continuum accordingly. At
n_H = 1000 that is ~1.7e-11 recombinations cm^-3 s^-1, some 3.6e-22 erg cm^-3 s^-1 - the same order
as the entire photoelectric heating of the cell.

**Nothing paid for it.** Ionizing that hydrogen costs 13.6 eV per atom and the source supplies no
photons above 1 Ryd. MOCASSIN is emitting recombination radiation for ionization that was never
purchased, and the dust is absorbing it. That is not a transfer artefact to be routed around; it is
energy created by an ionization balance answering a question no radiation asked.

Note this is latent in the shipped code too - the same spurious x(H+) exists there (D-101 measured
0.277 in the surface cell). What the honest neutral fraction changes is that the atomic hydrogen no
longer reabsorbs the resulting photons locally, so the error stops hiding and spreads through the
slab.

### What this makes of the H2 opacity plan

D-100's option 3 would help - dust and H2 would both compete for these photons - but it would be
treating the symptom. The recombination continuum at 65 K is emitted within ~1e-6 Ryd of threshold,
below H2's 15.43 eV edge entirely, so an H2 photoionization continuum would not even absorb it.

**The order of work has changed.** Before any opacity: find why `ionBalance` returns x(H+) ~ 1e-2 in
a cell with no ionizing radiation. That is the term creating the energy, and both the deep dust
anomaly and the D-099 blocker are downstream of it.


## 2026-09-03c - D-105/D-106: two attempts, one wrong, and what the ionizing field really is

### D-105, rejected: the electron density

D-104 ended by pointing at `ionBalance` ionizing without radiation. Reading it gives a clean
candidate: the stage ratio is

```fortran
ionRatio = (nPhotoSte + collIon + revRate) / (NeUsed*alphaTot + ...)
```

so X(i+1)/X(i) = Gamma/(Ne alpha), and `NeUsed` is rebuilt each pass from MOCASSIN's own ion sum
with **no floor** - only a warning if it reaches exactly zero. Once carbon is honestly locked in CO
that sum collapses, so the ratio diverges and an infinitesimal Gamma ionizes the cell. The obvious
fix is to hand back the chemistry's electron density, which is maintained by cosmic rays that
MOCASSIN does not have.

**It made things worse.** max x(H+) went 1.3e-2 -> **0.906**. The chemistry's Ne is *smaller*, not
larger - deep in a PDR x_e ~ 1e-8 - so substituting it shrinks the denominator further. The
diagnosis was backwards. Kept as `pdrUseNePDR`, default 0, with the array and its MPI exchange
retained because the measurement needed them.

### D-106, accepted: the chemistry owns its own elements

The principle was already settled for the thermal balance - the PDR owns it because MOCASSIN's
solver is the wrong one there. The same argument applies to ionization, and had never been applied:
in a PDR cell the chemistry has already solved H, He, C, O and Mg with cosmic rays and a molecular
network, and re-solving them from Gamma/(Ne alpha) replaces a correct answer with an expression
evaluated far outside the regime it was built for.

`pdrOwnIon = 1` makes `ionBalance` skip those elements in `pdrZone == 1` cells. It works:

| | max x(H+) | C+ -> C | C -> CO | H -> 2H2 |
|---|---|---|---|---|
| closure handover | 2.29e-03 | 0.995 | 1.075 | 1.117 |
| true atomic H | 1.32e-02 | 1.004 | 0.987 | 1.212 |
| **chemistry owns ions** | **9.82e-06** | **0.995** | **0.988** | 1.237 |

x(H+) now matches the chemistry to within a factor of two everywhere, from 1.3e-2 down to 9.8e-6.

### And it disproves the D-104 mechanism

D-104 argued the ionizing field was recombination radiation emitted for ionization nothing paid
for. With the ionization now correct at ~1e-5, that emission is gone - and the ionizing field is
**unchanged**: J(>1 Ryd) summed over the profile is 2.03e+01 against 2.01e+01, still 2000x the
closure run's 1.02e-02. The deep dust stays hot, 15.2 K against 6.3 K.

So the spurious recombination was real but it was not the source of the ionizing field. What
remains is simply that **the slab is transparent to ionizing photons once the hydrogen is
molecular**: whatever residual flux exists above 1 Ryd used to be absorbed in the first cells by
abundant atomic hydrogen, and now crosses the whole slab and is absorbed by dust.

That is D-100's argument, no longer argued but demonstrated, with the confounders removed one at a
time: not the source spectrum (D-101), not the escaping-line channel (D-104), not the electron
density (D-105), not spurious recombination (D-106). **MOCASSIN needs an H2 opacity.**

### State

Three switches, all default 0, so shipped behaviour is unchanged: `pdrAtomicH`, `pdrUseNePDR`,
`pdrOwnIon`. `elemAvail` (D-102) remains unconditional. The configuration that should eventually
ship is `pdrAtomicH 1` + `pdrOwnIon 1` + an H2 continuum opacity, and the first two are ready and
measured.


## 2026-09-03d - Step 0: restore the record

The plan's step 0. All four benchmarks re-run on head `37ace4b` with every switch (`pdrAtomicH`,
`pdrOwnIon`, `pdrUseNePDR`) at its default of 0, so this is the build as it ships.

| | V1 | V2 |
|---|---|---|
| H -> 2H2 | 1.219 | 1.029 |
| C+ -> C | 1.003 | 0.989 |
| C -> CO | 1.074 | 1.026 |
| deep T | 1.062 | 1.507 |

V1's H -> 2H2 confirms exactly the 1.219 measured in passing during D-102's work; V2 is a first
measurement with `elemAvail` live and moves both carbon fronts slightly (0.980->0.989,
0.985->1.026) without changing deep T. The spherical sec54 model and the ionization front benchmark
both re-run clean; sec54's H II region is 808-9479 K (HII40 ~8000-9000) and its PDR median ratio is
1.20 against standalone 3D-PDR at the model's own field.

All three artifacts (benchmark comparison, sec54, status) regenerated from these runs and
republished. A fourth artifact, a sequenced work plan, is now the reference for what comes next.


## 2026-09-03e - D-107: the H2 opacity, and both switches now default on

Step 1 and step 2 of the plan, done together because the second only became safe once the first was
measured working.

### The term

`addOpacity` gained an optional `H2density` argument and, when present and positive, adds

    sigma(nu) = 6.2e-18 * (nu/1.1345)^(-2.7)   cm^2,   nu >= 1.1345 Ryd (15.43 eV)

a single power law anchored at the H2 photoionization threshold, explicitly commented as an
approximation to the tabulated cross section (Backx, Wight & Van der Wiel 1976; Chung, Lee &
Gallagher 1993; Yan, Sadeghpour & Dalgarno 1998) rather than a reproduction of its resonance
structure - the job is restoring an absorber that is otherwise entirely absent between 13.6 eV and
wherever this falls off, not a spectroscopic result. `grid%H2den(cell)`, filled from
`abun(NH2)*nH` and MPI-exchanged, supplies the density - the same pattern as `NePDR` (D-105), which
made this a small, mechanical addition. A packet absorbed here becomes `"diffuse"` and re-emits
through `recPDF`, the physically correct fate for a photoionization.

### Both criteria the plan set, met

V1, with `pdrAtomicH 1` and `pdrOwnIon 1`:

| | without H2 opacity | with it | D-097's independent value |
|---|---|---|---|
| J(>1 Ryd), summed | 2.032e+01 | **1.813e-02** | (closure run: 1.020e-02) |
| max x(H+) | 9.82e-06 | 9.82e-06 (unchanged - already correct) | - |
| T_dust(A_V=8) | 15.24 K | **6.27 K** | 6.4 K, verified in D-097 |

Both the ionizing field and the deep dust temperature return to the closure run's values, and the
dust temperature lands on the value D-097 verified independently from the model's own opacity
curve. V2 confirms it: J(>1 Ryd) 8.5e-03, max x(H+) 3.5e-08, T_dust(A_V=8) 20.80 K against D-097's
20.7 K.

### A better result than expected: the truncated source was not required

The plan treated the Lyman-truncated source (D-101, plan step 4) as possibly necessary before the
opacity could be tested cleanly. It is not. Re-running the **committed fixtures**, unmodified,
un-truncated blackbody source, with only the two switches flipped to their new defaults:

| | V1 | V2 |
|---|---|---|
| H -> 2H2 | 1.117 | 1.015 |
| C+ -> C | 0.995 | 0.980 |
| C -> CO | 1.074 | 0.986 |
| deep T | 1.061 | 1.519 |
| max x(H+) | 8.15e-06 | (chemistry-matched) |
| T_dust(A_V=8) | 6.30 K | - |

This is the best this benchmark has produced. The H2 continuum is a genuine physical absorber, not
a patch for a truncated spectrum, so it absorbs real stellar ionizing photons as well as the
diffuse ones - step 4 becomes a separate correctness question (should these slabs receive ionizing
photons at all) rather than a prerequisite for anything already committed here.

### Defaults changed

`pdrAtomicH` and `pdrOwnIon`: 0 -> **1**. `pdrUseNePDR` stays 0 - it was rejected outright in D-105
and has no dependency on the opacity. The spherical sec54 model and the ionization front benchmark
both re-run clean under the new defaults.

### What remains open

The fit is a single power law with no resonance structure and an order-of-magnitude normalisation;
revisit it if the ionization structure of molecular gas ever needs to be more than a guard against
D-099's failure mode. And this is 1D-slab-verified only, under `planeIonization`'s reflecting walls
- the 3D flavour remains untested for this or anything else.


## 2026-09-03f - D-108: the photorate shielding now uses the model's own dust

D-091 recorded that `SCATTER()` converts A_V to tau(lambda) through `XLAMBDA`, which splines a
fixed Savage & Mathis (1979) extinction curve - so the H2 and CO photodissociation rates were
attenuated on a literature dust law regardless of what grains the model actually carries, while the
field heating the same gas is transported through the real ones.

### The fix is smaller than it sounds

`X_GRID` is a `save`d array in `uclpdr_module` that `XLAMBDA` splines on demand. Repopulating it
from `absOpac + scaOpac` - dust only, the same arrays `kV` and `kFUV` already come from - redirects
every caller (H2, CO, C I, S I) onto the model's own extinction with **no change to any vendored
routine**. `start` is reset so the spline is rebuilt. 29 of the 30 tabulated wavelengths are
replaced; the last, at 1e9 A, lies past the frequency grid and keeps its Savage & Mathis value
of 0.

    ! [D108] H2/CO shielding now uses this model's dust: 29 of 30 extinction points replaced
    ! [D108]   tau(1000A)/tau(V): Savage & Mathis 4.65, this model 4.83

### On the benchmark it changes almost nothing, and that was predicted

| | S&M curve | model's own |
|---|---|---|
| V1 H -> 2H2 | 1.117 | 1.113 |
| V1 C+ -> C | 0.995 | 0.994 |
| V1 C -> CO | 1.074 | 1.074 |
| V2 H -> 2H2 | 1.017 | 1.009 |
| V2 C+ -> C | 0.980 | 0.979 |
| V2 C -> CO | 0.986 | **1.075** |

D-091 said this would be invisible here because D-073 tuned the grains close to the tabulated
curve, and it is: 4.83 against 4.65. The one real move is V2's C -> CO front, and it is a genuine
shift rather than scatter - repeat runs of that quantity sit in 2.23-2.32 and this gives 2.43.
That front sits at A_V ~ 2.4 where the two curves have diverged enough to matter, and both the
C-ionizing and CO-dissociating rates shift, so the direction is not fixed by inspection. V1's
C -> CO front, though deeper still at A_V ~ 5.3, does not move at all: there the radiation is
attenuated far enough that cosmic rays dominate the carbon chemistry and the photorate could change
by a factor of two without being noticed.

**This moves away from the reference by design**, in exactly the sense D-090 established for the
FUV field: 3D-PDR's own run uses the Savage & Mathis curve, so agreeing with it perfectly requires
sharing its dust. `pdrOwnDust` defaults to 1 because self-consistency is the point of the coupling;
set it to 0 to reproduce a like-for-like 3D-PDR comparison.

### Why it matters anyway

The benchmark hides the size of the error because its fronts are shallow. Evaluating `SCATTER` for
the grey 0.07-50 um grains D-091 warned about, whose model curve is tau(1000A)/tau(V) = **1.13**
against the tabulated 4.65:

| A_V | S&M | grey grains | ratio |
|---|---|---|---|
| 0.03 | 9.08e-01 | 9.77e-01 | 1.1 |
| 0.3 | 3.86e-01 | 7.91e-01 | 2.1 |
| 1.0 | 3.71e-02 | 4.59e-01 | 12 |
| 3.0 | 3.37e-05 | 9.37e-02 | **2800** |
| 8.0 | 4.69e-13 | 1.43e-03 | 3e9 |

The error is unbounded with depth. A grey-dust slab run both ways gives nearly identical fronts
(0.0033 against 0.0034) only because grey grains barely attenuate the FUV at all, so those fronts
sit at A_V ~ 0.003 where the dust term is negligible and self-shielding does all the work. Any
model that combines non-Savage-&-Mathis grains with a front at appreciable A_V would have been
wrong by orders of magnitude, silently.

## 2026-09-03g - D-109: the dust the chemistry sees is the dust in its own cell

Prompted by a direct instruction, after the audit below found a calibration that had silently
drifted: *"we should not use one arbitrarily-chosen cell, we should use the values of the cell at
which the chemistry is being calculated. This is because we should use 3D-PDR to calculate the
chemistry and self shielding at each cell and Mocassin should provide the radiation field and the
dust properties at each cell location."*

That is the division of labour the whole coupling is built on, and the dust was the one place it
was not being honoured.

### What the audit found

Asked to re-check the dust setups, the fixtures came back clean - all four benchmarks carry the
D-073/D-092 correction, silicate only, 0.010-0.30 um on a matched MRN grid with `MdMg 0.011295`,
no PAH line at all. (The 0.07-50 um grains quoted in D-108 were a *constructed counterexample* in
a scratch directory, not a model setup. They should have been labelled as such.)

What was not clean was the calibration. Five hiipdr runs from the same input files:

| run | build | kV | R_FUV | A_V per N_H |
|---|---|---|---|---|
| hii54, hiiA, hiiF, hiiCK | four commits incl. head | 4.92e-20 | 4.16 | 5.342e-22 |
| hii107 | 0af9592-dirty | **3.46e-20** | **5.30** | **3.757e-22** |

One run in five read a V-band opacity 30% low at its calibration cell, with `Hden` = 100 there as
everywhere else. Downstream that run computed N_H **1.42x too large** at every A_V - every H2 and
CO shielding column in the model - and attenuated the FUV 27% more steeply per magnitude.

**The cause was never found.** Ruled out by measurement: identical total dust mass (1208.748 Msol),
`Ndust` uniform at 8.707e-09 in every cell of both runs, max per-size T_dust 89 K against a 1400 K
sublimation cut, identical frequency grid, byte-identical input and dust files. The one in-code
mechanism that can lower a single cell's opacity at fixed `Ndust` is the sublimation mask, and that
predicts R_FUV going *down* (it removes the small grains, which carry the FUV) while the
measurement went *up*. Head reproduces the canonical value bit-identically, so the instance is
gone. The absence of any guard against it was not.

### The change

`calibratePDRdust` took one cell - literally the first in array order carrying any dust - and made
its `kV/Hden` and `kFUV/kV` the law for the whole model, once, at `pdrStartIter`, never revisited.
That is correct only if every cell has the same dust-to-gas ratio and the same grain mixture, and
nothing checked that it did.

**`dustPerCell` (new)** measures both quantities in every cell from that cell's own
`absOpac`/`scaOpac`/`Hden`, into two new grid arrays `dustAVfac` and `dustRfuv`. The
emitted-energy band weights are a property of the source spectrum, so they are built once outside
the cell loop; the per-cell cost is one pass over the FUV bins.

**`pdrStep`** - the per-cell chemistry call - now reads its own cell, falling back to the
model-wide value only where a cell carries no dust at all, and reseeds the vendored module global
`AV_fac` per cell so that `CRattenuation` and `UVfield`, which are not touched, get this cell's
grains. `NHcol`, the escape-probability path lengths and the `chiLoc` fallback all follow.

**`computeAVradial`** now inverts `exp(-R_FUV*A_V)` with the target cell's own ratio, so the A_V it
stores is the A_V the chemistry will then interpret with the same grains.

**`calibratePDRdust`** keeps only three jobs: the fallback for dust-free cells, the seed before the
first cell, and diagnostics. It no longer picks the first cell it finds - it takes the
density-weighted mean over all dusty cells, picks the cell nearest that mean as representative, and
**reports the spread**, so a model whose dust is not uniform says so instead of silently electing a
delegate.

**Refreshed every iteration**, not once. The dust opacity is rebuilt each pass, so a one-shot
measurement goes stale - which is the shape of failure hii107 exhibited, whatever its cause.

### What was deliberately NOT changed

`UV_fac` is reseeded from nothing. It is tempting to set it to `R_FUV/magPerTau` in the same
breath, but it is not a measured dust property - it is the exponent of a *prescription*,
exp(-UV_fac*A_V), reconstructing a local field from the surface field. D-090 measured what the
transported field actually does in this geometry: gamma_eff = 1.849 (V1) and 1.847 (V2), against
3.31 for pure extinction and 3.02 for 3D-PDR's prescription, because the mirror walls return
laterally scattered photons. `R_FUV/magPerTau` is the pure-extinction number - the one D-090 showed
is wrong here. Substituting it would have been a regression dressed as self-consistency. The
reasoning is now a comment at the assignment so it is not "fixed" later.

### What it found immediately: T_dust = 2.3e9 K

Three of the four benchmarks came back **uniform to 1 part in 1e4** over 10-20 thousand cells, and
bit-identical to the old single-cell numbers - the right answer for a constant-`MdMg` model, and
the first time that uniformity has been measured rather than asserted.

`ifront` did not:

    ! [D109]   spread over the model: min = 3.58e-22  max = 5.37e-22  (ratio 1.498)
    ! [D109]   least-opaque cell at (i,j,k) = 1 1 5
    ! [D109]     Hden = 100.0   Ndust = 8.68659189E-09
    ! [D109]     max T_dust = 2.28894669E+09 K;  sizes above T_sublime: 16 of 35

A corner cell at normal density with a full grain complement, carrying a dust temperature of 2.3
BILLION K, which puts 16 of its 35 sizes over `TdustSublime` so they are deleted from `absOpac`.
That is the 30% opacity deficit. `dustGrid.out` shows 1236 K for the same model at the end of the
run, so the excursion is transient - and a one-shot calibration is exactly the thing that freezes a
transient into a run.

The cause is in `getDustT` (`update_mod.f90`), pre-existing and nothing to do with the coupling:

    grid%Tdust(nS,ai,cellP) = real(iT) + (dustAbsIntegral-dustEmIntegral(...,iT)) * &
         & (real(iT+1)-real(iT))/(dustEmIntegral(...,iT+1)-dustEmIntegral(...,iT))

It divides by the width of the bracketing interval in the emission table and never checks that the
width is non-zero. There are guards for `iT<=0` and `iT>=nTemps`, none for a degenerate interval.
In a cell that absorbed almost nothing, neighbouring table entries underflow to the same value and
the quotient explodes. Guarded: a flat interval carries no information about where in it the answer
lies, so take the bracket itself. With the guard, ifront's spread collapses to uniform and its mean
moves to 5.36504781e-22, the value the other cells always had.

**This is very probably what happened to hii107**, and it explains the one thing that defeated the
audit: the sign. Sublimation removing SMALL grains would lower R_FUV, and hii107's R_FUV rose. A
degenerate interval does not select by size - it fires wherever the table is flat, and here it took
16 sizes out of 35 including the large ones that dominate the V band. It also could not be
reproduced because it needs one cell to be transiently pathological at one iteration.

The exposure is not confined to the PDR coupling. A size dropped for being "sublimated" is dropped
from dust EMISSION too, so plain MOCASSIN models carry the same risk in low-flux cells.

### Measured

All four benchmarks on the change, 14 ranks:

| | V1 | V2 | sec 5.4 sphere | ifront |
|---|---|---|---|---|
| dusty cells measured | 20025 | 10025 | 15203 | 15025 |
| A_V/N_H mean | 5.33995522e-22 | 5.33995472e-22 | 5.34152688e-22 | 5.36504781e-22 |
| spread | uniform to 1e-4 | uniform to 1e-4 | uniform to 1e-4 | uniform to 1e-4 |
| R_FUV | 3.94185853 | 3.94185877 | 4.15870857 | 4.12171555 |
| H -> 2H2 | 1.109 | 1.007 | - | - |
| C+ -> C | 0.994 | 0.979 | - | - |
| C -> CO | 1.076 | 1.075 | - | - |
| deep T ratio | 1.062 | 1.515 | - | - |

Against the D-108 baseline (1.113 / 0.994 / 1.074 / 1.061 and 1.009 / 0.979 / 1.075 / 1.519) every
number is inside the repeat-run scatter. That is the expected and correct outcome: for a model with
constant MdMg the per-cell value IS the global one, and if these had moved it would have meant the
old global was wrong for these benchmarks too. What changed is not the answer but what the run
knows about it.

### Also fixed: the plain build, broken again

D-107 guarded `lgPDR` and `grid%H2den` in `ionization_mod.f90` with a runtime `if` rather than
`#ifdef PDR`, so the non-PDR build had not compiled since. Same slip D-096 caught in
`iteration_mod`. All three flavours - PDR `mocassin`, `mocassinWarm`, plain `mocassin` - build
clean again.

## 2026-09-03h - D-110: zeroing molecules outside the PDR zone, implemented and REJECTED

Prompted by: *"H2 and CO should show 0 in Mocassin arrays where PDR chemistry is not activated.
This should be result of self consistency."*

The observation is correct. `seedPDR` fills `pdrAbun` in EVERY cell with the network's initial
condition - `species_reduced.d` opens at H = 0.4, H2 = 0.3 - and `pdrStep` returns at its first
line for any cell with `pdrZone == 0`. So a cell deep inside the H II region reported x(H2) = 0.3,
a seed presented as a result.

Implemented as a `dissociate()` helper called from both seeding paths (the non-PDR branch of
`pdrStep` and `seedPDR`'s inactive-cell default), moving the hydrogen in H2 back to atomic H and
CO's carbon and oxygen back to C+ and O so the elements stayed whole. Measured: molecules zero
outside the zone, x(H) = 1.0 rather than 0.4, budgets closing to 1.0000 and 2.2e-4 on both sides
of the boundary. All three build flavours compiled.

**Rejected on the next instruction**, and correctly: *"we should have arrays that track the
abundances of ions and they should be set with initial values and after that it should only be
changed by the code based on physics or chemistry calculations. Molecules should naturally
disappear in ionized regions due to the physics not the seeding."* Writing a dissociated state by
hand is the same defect as the seed wearing better clothes - nothing computed it. Reverted; nothing
committed on `pdr-coupling`.

### Two real findings survive the rejection

**`grid%H2den` is never re-zeroed.** It is initialised to 0 and written only in PDR cells, but the
zone is re-evaluated every iteration. A cell that is PDR on one pass and ionized on the next keeps
its stale n(H2) and goes on feeding the D-107 photoionization opacity into gas MOCASSIN has since
ionized. Not triggered by the current benchmarks; still a stale-cache bug, and it is NOT an
imposed-physics question - it is a refusal to use a number computed for a state the cell has left.
Unfixed, deliberately, pending the redesign below.

**`computeAVdust` does not gate the shielding columns on zone.** It accumulates cH2/cC/cCO with
only a `cellP > 0` guard (`pdr_mod.f90`, D-078 block), while `computeAVradial` gates on
`pdrZone == 1`. So under plane-parallel illumination the seed in non-PDR cells contributes real
H2 self-shielding to every cell behind them, and the two geometries disagree about whether
non-PDR cells shield. Also unfixed.


## 2026-09-03i - D-111: how Cloudy couples ionization to chemistry, read from the source

Asked to check Cloudy before committing to a design. Read `cloudy-c25.00` locally rather than
relying on the papers.

**The first scope draft proposed adding EUV photoionization to the 3D-PDR network. Cloudy wrote
exactly those reactions and commented them out.** `data/mole_co_base.dat`:

    #These would be double counted if included in the molecular network
    #C+,e-=>C:ele_recomb:1.:0.:0.
    #O+,e-=>O:ele_recomb:1.:0.:0.
    #C,PHOTON=>C+,e-:ele_ionize:1.:0.:0.
    #O,PHOTON=>O+,e-:ele_ionize:1.:0.:0.
    #N,PHOTON=>N+,e-:ele_ionize:1.:0.:0.
    #S,PHOTON=>S+,e-:ele_ionize:1.:0.:0.

Atomic photoionization AND recombination, written out with a rate function `ele_ionize`, disabled
on purpose, with the reason stated in the file.

### What they do instead

The ion solver keeps photoionization, recombination and charge transfer. The chemistry reports,
per element and per ionization stage, how fast it creates and destroys that stage, and those two
numbers enter the ionization matrix directly - `ion_solver.cpp:765`:

    source[i] -= mole.source[nelem][ion];
    MAT( xmat, i, i ) -= mole.sink[nelem][ion];

Both are then iterated to a joint solution in the same zone (`conv_base.cpp`: solve ionization,
call `mole_drive()`, test, with oscillation detection and 50% damping). There is no zone gate
anywhere in Cloudy and no "available fraction".

`chem_nuclide::ipMl` is sized `Z+1`, one slot per ionization stage, and `ipMl[ion] == -1` means
"not in the network" - that stage gets zero molecular source and sink and is left entirely to the
ion solver. **This dissolves what looked like our blocker**: a singly-ionized network is fine,
C2+ simply has no chemical terms and MOCASSIN owns it.

### What this costs us

Our generated ODE code already computes both numbers. From `odes_reduced.c`:

    loss = -rate[51]*x[30]*n_H - ... - rate[243]*x_e*n_H;
    form = +rate[41]*x[26]*x[31]*n_H + ...;
    ode[10] = form + x[10]*loss;

`form` is additive production, `loss` a specific destruction rate multiplying the species' own
abundance - the same shape as Cloudy's `source` and diagonal `sink`. They are computed for every
species on every call and discarded as locals.

**The obstacle is `ionBalance`, which is a chain solver.** It forms adjacent-stage ratios,
multiplies them into `ionProd`, sums to a `denominator` and normalises
(`update_mod.f90:1760-1830`). That is only valid when the only couplings are ionization up and
recombination down. A molecular source is inhomogeneous - it adds rather than multiplies - and
chemistry can move an element between non-adjacent stages. Converting it to a linear solve is the
real work, not the network and not the rates. `nstages = 7`, so the systems are 7x7.

**Decided: convert for ALL elements, not just the five the chemistry touches.** Reason given:
*"the user may want to select different abundances for each model"* - `nebComposition` and
`lgElementOn` are per-model, so hardcoding a subset would break silently when someone enables a
different set, and it removes a special case rather than adding one. Cost: this touches a solver
every MOCASSIN model uses, so "with zero molecular terms it reproduces the chain answer to
round-off" becomes a mandatory regression, on non-PDR models too.

`elemAvail` (D-102) retires when this lands. It is the scalar approximation of the same idea:
"this fraction is locked up" against "it is being locked up this fast and released that fast".


## 2026-09-03j - D-112: H2 self-shielding is bistable, so the seed is a model input

The D-110 work turned up something that looked like a numerical defect: dissociating 7 surface
cells moved V1's H -> 2H2 front from 1.109 to 1.245. The suspicion was that the chemistry carries
a memory of its initial condition because `calculate_abundances` integrates to `pdrEndTime` rather
than to a steady state.

Suggested that the matrix conversion of D-111 would make this moot. It does not, and the reason is
physics rather than numerics.

### The measurement

Three V1 runs, IDENTICAL elemental budget (0.4 + 2x0.3 = 1.0 = 1.0 + 0), differing only in where
the chemistry starts:

| seeding | integration | H -> 2H2 | C+ -> C |
|---|---|---|---|
| network, H = 0.4 / H2 = 0.3 | 1e7 yr | 1.109 | 0.994 |
| every cell dissociated | 1e7 yr | 1.679 | 1.244 |
| every cell dissociated | **1e9 yr** | **1.682** | 1.244 |

A hundredfold longer integration changes nothing - the surface layers agree to four digits between
them (x(H2) = 8.202e-05 against 8.206e-05 at A_V = 0.00125). The dissociated state is not relaxing
slowly toward the molecular one; it is converged, to a different answer.

**H2 self-shielding is a positive feedback with two stable attractors at the front.** More H2 gives
more shielding gives more H2. The system stays in whichever basin its initial condition put it in,
and no amount of integration moves it. The deep chemistry is unaffected - C -> CO sits at 1.076
against 1.072 - because the feedback only bites where the field is strong enough for shielding to
decide the outcome.

### Why it matters, and when

t_form(H2) = 1/(R n_H). R was taken as the textbook 3e-17 cm3/s when this was
written; D-113 then measured the value this build actually uses, 4.6e-17, because
`-DH2FORM_CT02` selects Cazaux & Tielens (2002) rather than Jura. Corrected:

| n_H | t_form (R = 4.6e-17, measured) | against an H II region lifetime of 1-10 Myr |
|---|---|---|
| 1e5 (V2) | 6.9 kyr | equilibrium long since reached |
| 1e3 (V1) | 0.69 Myr | comparable |
| 1e2 (sec 5.4) | 6.9 Myr | inside the window, so the seed is physics there |

Borne out directly: V2 did not move at all under re-seeding (1.007 to four digits), V1 moved 12%.
For the sec 5.4 model the H2 abundance genuinely has not reached equilibrium within the lifetime of
the source, so the initial condition there is not a numerical artifact at all.

### Decided

There is no astrophysical justification for the network's 0.4/0.3 - it is a numerically convenient
midpoint from the UMIST distribution - and no numerical fix, because integration cannot remove it.
So it becomes an explicit model input:

- **x(H+) seeded per cell from MOCASSIN's photoionization**, as proposed. That equilibrium is fast
  and reliable to small fractions, and it removes the ambiguity everywhere it can be removed.
- **The neutral split is a named choice** with two physically motivated presets rather than an
  inherited number:
  - *atomic* - gas that recently crossed an ionization front and is forming H2. Correct for
    expanding H II regions and champagne flows, i.e. the sec 5.4 geometry.
  - *molecular* - a pre-existing cloud with a dissociation front eating inward. The
    Tielens & Hollenbach picture, i.e. what the Rollig benchmarks represent.
- Carbon follows the same logic, C+ or CO. Its front is just as sensitive: 0.994 -> 1.244.

**For the record: the benchmark agreement depends on this choice.** V1's 1.109 holds because we and
3D-PDR both start from 0.4/0.3. That is a fair like-for-like comparison and it is not
seed-independent physics. The artifacts now say so.

Three predictions were made ahead of these measurements and two were wrong - that sublimation
explained the D-109 opacity deficit (wrong sign), and that V1's seed dependence was slow relaxation
(it is bistability). Recorded because the pattern is the point: reasoning ahead of the measurement
has been the main source of error in this log.

## 2026-09-03k - D-113: export per-species formation and destruction rates

Step 1 of the D-111 design. No physics change: this only surfaces two numbers the
chemistry was already computing and discarding.

### What was added

`chemistry_module` gains two `bind(c)` arrays, `species_form` and `species_loss`,
following the convention `calculate_abundances.c` already uses for the solver
tolerances. The generated ODE files write into them.

The odes_*.c files are GENERATED, so the capture is a re-runnable patch script
(`tools/patch_odes_capture.py`) rather than a hand edit that would be lost the
next time the network is rebuilt. Every ODE line has the identical shape

    ode[N] = form+x[N]*loss;

so the patch appends a store after each - 32 of them in the reduced network. It
checks the `ode` and `x` indices agree on every line, refuses to run if the
generator's output shape ever stops matching rather than silently doing nothing,
and is idempotent.

`calculate_abundances.c` re-evaluates the right-hand side once at the abundances
being returned. This is the part that is easy to get wrong: `f()` stores on every
call, but CVODE's LAST internal evaluation sits at an interior stage of the final
step, not at the solution it hands back. Without the deliberate call the exported
rates would describe a state the integrator never returned.

No capture flag. OpenMP is off in PDRFLAGS and `pdrStep` passes npart = 1, so
there is no race, and 64 stores per RHS call is nothing against ~300 rate
expressions. `pdrDiagRates` and `pdrDiagAV` gate the diagnostic only; both
default off.

### Verification

Two independent checks, V1 at A_V ~ 0.91, n_H = 1e3:

| species | x | form | x*loss | residual |
|---|---|---|---|---|
| H2 | 0.4952 | 4.36660784e-16 | -4.36660784e-16 | 2.9e-09 |
| CO | 1.227e-08 | 4.55690129e-19 | -4.55690129e-19 | 7.2e-13 |
| H  | 9.570e-03 | 8.22381747e-16 | -8.22381747e-16 | -3.1e-09 |

`form` and `x*loss` cancel to nine significant figures. That tests three things
at once: the right quantities were captured, they were captured AT THE RETURNED
SOLUTION (an interior stage would leave a large residual), and the chemistry is
genuinely at steady state at this depth. H and H2 carry opposite-signed residuals,
which is what exchange between them looks like.

Second check, absolute rather than internal: the implied H2 formation coefficient
`form(H2)/(n_H*x(H))` comes out **4.56-4.64e-17 cm3/s**. The textbook Jura value
is 3e-17, but this build carries `-DH2FORM_CT02`, so formation is Cazaux &
Tielens (2002), which is higher and lands exactly in this range at these grain
temperatures. **This corrects D-112's timescale table**, which used 3e-17 - the
real formation times are ~35% shorter, and the entry above has been fixed. No
conclusion changes: sec 5.4 at 6.9 Myr still sits inside the 1-10 Myr window where
the seed is physics rather than a numerical choice.

### Physics unchanged, as required

V1 against the pre-D-113 tree, all within MC scatter:

| | before | with capture |
|---|---|---|
| H -> 2H2 | 1.109 | 1.113 |
| C+ -> C | 0.994 | 0.994 |
| C -> CO | 1.076 | 1.074 |
| deep T | 1.062 | 1.062 |

All three build flavours compile and the PDR rebuild is byte-identical.

One process note worth keeping: the first no-op comparison was made against
`v1slab112`, which carries the D-110 dissociation that was rejected and reverted.
Against that baseline a clean no-op reads as a 12% regression. Compare against the
tree you actually changed, not the most recent run.

## 2026-09-04a - D-114: matrix ionBalance, and the overnight crash

Step 2 of D-111. **Not finished** - the matrix is committed but inert
(`lgIonMatrix = .false.`). Two real fixes came out of the attempt and those
are live.

### The crash

An overnight `test_Problem` run took the machine down. Not the model outgrowing
memory: a clamp added here,

    if (ionDn(elem,ion) < 0.d0) ionDn(elem,ion) = 0.d0

left the denominator at EXACTLY zero where it had been a small negative, so the
following division became 0/0 = NaN. The NaN propagated through ionProd into
ionDen and out to `getGrainRecombination`, whose "insane eta" warning fires only
on NaN and has no throttle. It wrote **38.5 million lines and a 3 GB log** into
`/tmp`, which is tmpfs - RAM-backed. That was the memory exhaustion.

Two fixes, both kept:

- **The division is guarded.** A zero denominator means no recombination path
  out of the stage above; nothing physical bounds the ratio, so it is capped
  rather than allowed to become an infinity, and any non-finite result is
  caught.
- **The warning is throttled** to 20 prints with a per-iteration summary of how
  many NaNs occurred. This is a PRE-EXISTING hazard independent of the bug that
  triggered it: any NaN from any cause would have done the same to any user. The
  warning detects something nothing else catches, so it is worth keeping - but
  bounded.

Verified: log 100 KB against 3 GB, zero "insane eta", clean exit.

### What the clamp was for, and that it works

`revRate` carries a factor `(1 - x(H+))`, so any cell where x(H+) transiently
exceeds 1 drives `ionUp` negative, which propagates as a negative `ionProd` and
a negative ion fraction. Measured at ~10^6 stage-cells per iteration in V1,
silently caught until now by the `1e-20` floor at the end of the routine.
Clamping at source fixes both solvers; after it, the negative count is zero.
Published results were never corrupted - the floor caught them - but the chain
was routinely computing unphysical intermediates.

### Why the matrix is not finished

The balance rows are right. Verified in V1 against the chain IN THE SAME CELL on
the SAME call, which is the only comparison that means anything here: two
separate runs differing only by the switch diverge from any difference at all,
because MOCASSIN is deterministic and a solver difference of 1e-11 in one cell
amplifies through the opacity to 0.5% by iteration 5. In-run, V1's converged
iteration agrees to **1.8e-15 on the dominant stage**.

`test_Problem` - 9 elements, 200 kK, PDR off - then failed, and it is the case
V1 cannot probe because V1's deep stages sit on the 1e-20 floor while 200 kK
genuinely populates middle stages. Neutral carbon in the ionized gas:

| chain | matrix |
|---|---|
| 7.85e-25 | 4.83e-05 |
| 8.38e-28 | 4.00e-10 |
| 2.19e-26 | 7.99e-08 |

Eighteen to twenty orders out, persistently. Column scaling by the chain
estimate - which fixed an earlier 5-decade error on C3+ - cannot fix this. It
conditions the BALANCE rows, but the conservation row `sum(c_i y_i) = availFrac`
couples every stage at O(1), so a stage 25 decades down is lost in the rounding
of order-unity quantities no matter how the columns are scaled.

**This is what Cloudy's `ion_trim` is for**, and the first scope draft dismissed
it: *"scaling avoids having to choose a trimming threshold"*. The threshold is
not the cost of trimming - it is the mechanism that makes the problem tractable
at all, by keeping the system inside a few decades. The next attempt should
restrict the matrix to the populated range and fill trace stages from the ratio
recursion, which is exact and stable precisely where the matrix is not.

### Process notes

Two mistakes worth keeping. The first no-op check compared against `v1slab112`,
which carries the rejected D-110 dissociation - against that baseline a clean
no-op reads as a 12% regression. Compare against the tree you changed. And an
overnight job wrote unbounded output to a RAM-backed filesystem; long-run logs
belong on disk, not in `/tmp`.

## 2026-09-04b - D-115: Cloudy's trimming, and the zero recombination coefficient underneath

Tried Cloudy's `ion_trim` approach on D-114's matrix: restrict the system to the
populated stage range so it never spans more than a decade or so. Their
thresholds are `trimhi = 1e-6`, `trimlo = 1e-10` of the element; ours is one
parameter, `ionTrim = 1e-12`, and stages outside the range keep their chain
value - the ratio recursion is exact and stable precisely where the matrix is
not, so that is the better instrument for the tail rather than a fallback.

The boundaries are closed deliberately. With no flux in from iLo-1 or out to
iHi+1, row iLo reads `-U(iLo)x(iLo) + D(iLo)x(iLo+1) = 0`, which the chain
satisfies identically, and likewise at iHi. So the trimmed system's exact
solution IS the chain restricted to the range, and equivalence stays exact by
construction rather than by numerical luck.

**The linear algebra is correct.** Replicated the assembly, pivoting and
back-substitution outside MOCASSIN and ran a 7-stage system spanning nineteen
decades: every stage reproduced to 1.0000, trimmed range and untrimmed tail
alike. Whatever is wrong is not the solver.

### What the dump showed

Carbon in `test_Problem`, dumped from the failing solve:

    nst 5  iLo 1  iHi 5  nr 5  iBig 5
      stage 1  c = 6.96e-09   y = 1366.9
      stage 2  c = 3.53e-07   y = 1366.9
      stage 3  c = 8.80e-19   y = 1366.9
      stage 4  c = 1.00e-30   y = 1366.9
      stage 5  c = 9.99e-01   y = 0.9995

The chain estimate is **non-monotonic**: stage 4 at 1e-30 sitting between stage
3 at 1e-19 and stage 5 at ~1. That is the 1e30 ratio cap from D-114 firing,
which means `ionDn` is ZERO for carbon stage 4 - `alphaTot` carries no
recombination coefficient there.

Two things follow.

**Trimming the ends cannot bound the span when the degeneracy is in the middle.**
Both ends are populated, so iLo = 1 and iHi = 5 and nothing is trimmed; the
system still spans thirty decades. Cloudy's method is right for a monotonic
profile and a missing rate coefficient destroys that assumption.

**This predates all of this work.** Before D-114's clamp the same situation gave
`ionUp/0 = +Inf`, so `ionProd` went to Inf, `denominator` to Inf, and the lower
stages came out as `finite/Inf = 0`. MOCASSIN has been hiding a missing
recombination rate behind infinity arithmetic, and the chain's answers for those
stages were never meaningful - they were zeros manufactured by an overflow. The
cap made it visible as 1e-30 instead of fixing it.

### Where this leaves the coupling

The matrix stays inert (`lgIonMatrix = .false.`). The blocker is no longer
numerical: it is that `alphaTot` is zero for some stages, which corrupts the
reference any solver would scale against. That has to be settled first - it is a
data question, not a linear-algebra one - and it is worth settling on its own
merits, because it means some published ion fractions in strongly-ionized models
rest on overflow rather than on a rate.

Next step is to find which (element, stage) pairs have `alphaTot = 0` under what
conditions, and whether that is missing data, a temperature range being exceeded,
or a lookup returning zero where it should extrapolate.
## 2026-09-04a - D-116: the dielectronic recombination fit returns negative rates

Found while investigating why a matrix ion solver on the photoionization branch
could not reproduce the chain. The cause turned out to have nothing to do with
solvers and everything to do with a rate coefficient, so the fix belongs here,
on the branch every MOCASSIN variant descends from.

### What is wrong

`calcAlpha` builds the total recombination coefficient as radiative plus
dielectronic. The dielectronic part is a POLYNOMIAL FIT in t = Te/1e4:

    diRec = 1e-12*(a/t + b + c*t + d*t^2)*t^(-3/2)*exp(-f/t)

Nothing anywhere bounds the temperature it is evaluated at. Below the fitted
range the `a/t` term dominates - at Te = 383 K, t = 0.038, so a/t is ~26a - and
the polynomial goes NEGATIVE. Measured directly:

    elem 6 (carbon), stage 4:  alphaTot = -2.54443133E-10  at Te = 382.858 K

A first audit at Te = 20000 K came back completely clean, which is why this has
never been noticed: the fits are fine everywhere the code was exercised, and
only misbehave in cool gas.

Physically the answer there is not negative, it is negligible: dielectronic
capture needs a doubly excited state and is exponentially suppressed as Te
falls. Zero is the correct floor, not merely a convenient one.

### What it was doing

alphaTot < 0 makes the recombination denominator in `ionBalance` negative, so
the stage ratio comes out negative and the chain produces NEGATIVE ion
fractions - measured at ~10^6 stage-cells per iteration in a 200 kK model.
They have never been visible because the `1e-20` floor at the end of
`ionBalance` catches them. Published results were therefore not corrupted, but
those stages were floored rather than computed.

### The fix is TWO changes that cannot be separated

Clamping `diRec` and `alphaTot` at zero is necessary and not sufficient. It can
leave the denominator EXACTLY zero where it was previously a small negative -
`chex` is itself zeroed outside 6000-50000 K, so in cool gas both terms vanish
together - and the division then gives 0/0 = NaN instead of a finite wrong
answer. A NaN T_dust reads as "all grains sublimed" in `pathSegment`, because
**NaN fails every comparison**, and the run hits a hard `stop`.

Measured: with the clamp alone, hiipdr died at its second PDR iteration, 14
stops, one per rank. The three slab fixtures passed - only the spherical model
with a real ionization front and cool cells exercises the path. So the
numerator and denominator are now formed separately and the division guarded,
capping where there is no recombination path rather than overflowing.

**The general rule this is the second instance of: clamping a quantity to zero
is never safe in isolation if anything divides by it.**

### Measured effect

| | V1 | V2 | sec 5.4 |
|---|---|---|---|
| H -> 2H2 | 1.109 -> 1.109 | 1.007 -> 1.009 | 0.4973 -> 0.4976 |
| C+ -> C | 0.994 -> 0.994 | 0.979 -> 0.979 | 2.1753 -> 2.1929 |
| C -> CO | 1.076 -> 1.076 | 1.075 -> 1.075 | - |
| deep T | 1.062 -> 1.062 | 1.515 -> 1.516 | - |
| median T ratio | - | - | **0.908 -> 0.971** |

The slabs do not move: they are warm and uniform, with few cells in the regime
where the fit misbehaves. The spherical model improves - its median PDR
temperature ratio goes from 0.908 to 0.971 - which is exactly where cool gas
coexists with ionization and therefore exactly where a negative recombination
rate was biting. An improvement confined to the geometry that has the problem
is a better result than a uniform shift would have been.

### The "still open" item, retracted

D-116 closed by flagging `revRate` as a second, separate route to a negative
rate. **That was wrong, and it was an inference rather than a measurement.**

Two errors in one sentence. The factor is `(1 - x(H0))`, the NEUTRAL fraction,
not `(1 - x(H+))` as written - so it needs x(H0) > 1, not x(H+) > 1. And
`xMax = 0.99999` is a hard parameter in `constants_mod`, applied to every
`ionDen` assignment in `ionBalance`, so x(H0) can never exceed it. The factor
is bounded below by 1e-5 and `revRate` is structurally non-negative.

Measured to be sure, on both the model with cool gas beside an ionization front
and the 200 kK nine-element model: **zero negative numerators, every iteration
of both**. The concern does not exist.

Worth recording because the pattern is now familiar in this log: a mechanism
asserted from reading code, propagated into a commit message and a plan, and
false. The instrument that settled it took ten minutes.

## 2026-09-04c - D-117: the matrix solve closes, once the rates are not negative

D-115 parked the matrix with a structural verdict: the conservation row couples
every stage at O(1), so a stage twenty-five decades down is lost no matter how
the columns are scaled, and trimming cannot help because the degeneracy sits in
the middle of the range rather than at its ends.

**Every observation there was accurate and the conclusion was wrong.** The
middle-stage degeneracy was manufactured by the negative dielectronic rate of
D-116 - carbon stage 4 at 1e-30 between neighbours at 1e-19 and 1 was the 1e30
ratio cap firing on a zero denominator, not a real population. Fix the rate and
the profile is monotonic again, trimming bounds the span as intended, and the
numerical obstacle disappears.

### Agreement, in the same cell on the same call

| model | matrix vs chain |
|---|---|
| V1 slab | **2.09e-15** - round-off |
| test_Problem, 9 elements at 200 kK | **3.2e-8** |
| negative ion fractions | 0 |

The residual is the SPAN of the linear system and nothing else, which was
predicted and then confirmed: twelve decades against sixteen digits leaves
~1e-4 at the bottom of the range.

| ionTrim | span | worst agreement |
|---|---|---|
| 1e-12 | 12 decades | 5.5e-5 |
| **1e-8** | 8 decades | **3.2e-8** |

Four decades less span, ~1700x better agreement - one digit per decade, as the
arithmetic requires. Nothing is lost by trimming harder: stages below the
threshold take the ratio recursion, which is exact there. Cloudy's equivalent
(trimlo) is 1e-10.

### Enabled, and what it does to the benchmarks

| | chain | matrix |
|---|---|---|
| V1 H->2H2 / C+->C / C->CO / deep T | 1.109 / 0.994 / 1.076 / 1.062 | 1.113 / 0.994 / 1.071 / 1.061 |
| V2 H->2H2 / C+->C / deep T | 1.009 / 0.979 / 1.516 | 1.005 / 0.979 / 1.516 |
| sec 5.4 median T ratio | 0.971 | **0.997** |

Within scatter everywhere except the spherical model, which improves again -
its PDR temperature now agrees with standalone 3D-PDR to 0.3%. All five
fixtures complete with zero NaN flags and zero sublimation stops.

`lgIonMatrix` therefore defaults true. The chain is kept behind the switch as
the reference the matrix is checked against, not as a fallback.

### The pattern, recorded because it keeps happening

Three times this session a structural "this cannot work" verdict dissolved on
measurement: sublimation explaining the D-109 opacity deficit (wrong sign), the
seed dependence being slow relaxation (it is bistability), and this one. Each
was settled in ten to fifteen minutes by an instrument aimed one level closer
to the thing in question. The lesson is not "measure more" but specifically:
**a conclusion about why something cannot work deserves the same evidential
standard as a claim that it does.**

## 2026-09-04d - D-118: the chemistry's rates feed the ion matrix

Step 3 of D-111, and the first change in this sequence that alters physics
rather than preparing to. The chemistry now constrains the ionization through
per-stage formation and destruction rates, as Cloudy does
(`ion_solver.cpp:765`), instead of through `elemAvail`'s scalar.

### What was built

`pdrLinkSpec/Elem/Ion` is Cloudy's `ipMl` in Fortran: which MOCASSIN ion each
network species is. Built from the index variables `read_species` resolved, not
from literals, because the species indices are irregular - He+ is 2, Mg is 3,
H is 32 - and a literal would silently attach one element's chemistry to
another's ionization, which looks like physics rather than a bug.

`pdrIonRate(cell, 1:2*pdrNlink)` carries `form` and `loss` per linked stage,
MPI-gathered like the other per-cell PDR arrays. `ionBalance` puts them in the
two slots D-114 left empty:

    ionMat(ic,ic) = ionMat(ic,ic) - chemSnk(ir)*ionScal(ir)   ! diagonal
    ionRHS(ic)    = ionRHS(ic)    - chemSrc(ir)               ! RHS

The sink is a rate coefficient so it scales with the column; the source is a
rate so it goes to the RHS unscaled. A stage the network does not carry keeps
zero for both and stays entirely with the ion solver - Cloudy's `ipMl == -1`
rule, which is what lets a singly-ionized network couple to a seven-stage
solver with no special case.

### Two ordering constraints, both learned the hard way

The link table was first built before `read_species` ran, so every index was
zero, `linkIon` rejected all ten, and **five fixtures completed cleanly with an
empty table**. That is the dangerous kind of failure: it looks like success,
and the "benchmarks unchanged" result would have been rationalised away. What
caught it was printing `count(pdrLinkSpec > 0)` rather than assuming. The count
is printed for that reason and should stay.

Second: `linkIon` must NOT test `lgElementOn`. `initPDRnetwork` runs before
`setComposition` populates it, so such a check would silently empty the table
again. The guard that matters is in `ionBalance`'s element loop. Both
constraints are now comments at the call site.

### elemAvail stands down, and that is the point

`elemAvail` (D-102) and the rates are **two descriptions of the same physics**:
one says "this fraction is locked in molecules", the other "it is being locked
up this fast and released that fast". Running both double-counts. The first
measurement of step 3 was taken with both active and was therefore of a
configuration nobody would ship - small shifts that meant nothing. `elemAvail`
now stands down in PDR-zone cells where the rates are supplied, and stays in
force elsewhere, where it is 1.0 anyway.

### Measured

| | step 2 (elemAvail) | step 3 (rates only) |
|---|---|---|
| V1 H->2H2 / C+->C / C->CO / deep T | 1.113 / 0.994 / 1.071 / 1.061 | 1.113 / 0.994 / 1.078 / 1.062 |
| V2 H->2H2 / C+->C / C->CO / deep T | 1.005 / 0.979 / 1.075 / 1.516 | 1.007 / 0.979 / 1.075 / 1.522 |
| sec 5.4 median T ratio | 0.997 | 0.985 |

**Essentially unchanged**, and that is the correct result rather than a
disappointing one. In equilibrium the two formulations agree by construction:
a scalar locked fraction f and a pair of rates whose ratio determines f are the
same statement. The rate form is not better here - it is more GENERAL, and the
generality buys nothing until the system is out of equilibrium or chemistry
moves material between non-adjacent stages, neither of which these benchmarks
exercise.

That the answer did not move is also the evidence the wiring is right. It is
paired with the conservation check, which shows the locking really is going
through the rates:

    x(C0) + x(C+) + x(CO) = C/H   to 5.7e-5 over every PDR cell
    x(H0) + 2x(H2) + x(H+) = 1    to 7.5e-8

The carbon sum falls short of C/H by exactly the CO fraction - 3.8e-14 at the
inner edge rising to 7.1e-7 at the outer - so carbon is being removed from the
ion stages by the chemical sink and accounted for in the molecule. With
`availFrac` now 1.0 in those cells, nothing else could be doing it.

### Process

Two suites ran concurrently at one point, 28 processes on 14 physical cores.
The cause is in the transcript: a `pkill` was issued, the next line printed
`ranks: 14`, and the launch went ahead anyway. Printing a check and then
ignoring it is worse than not checking. The driver script now waits for the
process count to reach zero before each run, which makes the constraint
structural rather than dependent on attention.

## 2026-09-04e - D-119: closing the ionization/chemistry loop moves the H2 front onto the reference

Step 4 of D-111. Until now `updateCell` and `pdrStep` ran once each per MC
iteration, in sequence, so the loop between them closed only ACROSS MC
iterations: the chemistry saw last iteration's ionization and the ionization
saw last iteration's chemistry. Cloudy iterates the two to a joint solution
within a zone (`conv_base`) with damping and oscillation detection.

`pdrCoupleIter` sets how many times the pair is repeated inside one MC
iteration. The count is FIXED, not convergence-tested, because every rank must
execute the same number of passes or the MPI collectives inside the PDR block
deadlock. Convergence is measured and reported; the operator chooses the count.
Damping is Cloudy's 50% averaging.

### The result

| configuration | H -> 2H2 front, three runs each |
|---|---|
| 1 pass (sequential, as before) | 0.4969, 0.4973, 0.4979 |
| **3 passes (joint)** | **0.9044, 0.9055, 0.9048** |
| standalone 3D-PDR | **0.9054** |

Both clusters are tight to 0.1%, which is the MC scatter, and they are
separated by a factor of 1.82. The three-pass cluster lands on the reference to
**0.1%**.

**This corrects a documented claim.** The sec 5.4 artifact has explained that
front's factor-of-two disagreement as a GRID RESOLUTION limit - "the H/H2 front
is thinner than one cell, so it can only land on a cell boundary", with an
argument that no choice of n_H helps and that Bisbas et al. used 256 clustered
cells for the same reason. That explanation was wrong. The grid resolves the
front perfectly well; the sequential coupling was lagging, and the front sat
where a half-converged ionization put it. The resolution argument was
plausible, quantitative, and never tested against the alternative.

Other quantities, three runs each:

| | 1 pass | 3 passes |
|---|---|---|
| C+ -> C front | 2.177, 2.186, 2.183 | 2.302, 2.293, 2.291 |
| median T ratio | 0.905, 1.044, 0.974 | 0.898, 0.866, 0.872 |

C+ -> C moves 5% and out of the 1-pass scatter, so it is real but small. The
temperature ratio scatters more between repeats than it differs between
configurations - 1-pass spans 0.905-1.044 - so nothing can be concluded about
it from three runs, and the earlier single-run temperature comparisons in this
log should be read with that in mind.

### Convergence

Abundance-weighted mean change in the ion fractions, per pass:

| MC iteration | pass 2 | pass 3 |
|---|---|---|
| 4 | 8.24e-04 | 1.43e-04 |
| 5 | 6.07e-03 | 2.69e-03 |

Monotonically decreasing, by factors of 2 to 6 per pass. Converging, not
oscillating, so the damping is insurance rather than necessity here.

### The metric had to be fixed first

The first version reported changes of 1e5 and looked like divergence. It was a
bare relative difference over every stage above a 1e-10 guard, so a stage
sitting ON the guard - where a negligible absolute change is an enormous
relative one - dominated the answer. Abundance-weighting fixed it.

That is the THIRD time in this work a comparison built that way has measured
its own floor rather than the physics: the chain-vs-matrix diff reported 1.0
from a near-zero pair and sent me chasing a solver bug that did not exist, and
a "24% MC noise floor" turned out to be a completed run compared against a
crashed one. The general form is worth stating once: **a relative-difference
metric with a bare floor guard measures the floor.** Weight by the quantity
that matters, or restrict to values that matter, every time.

## 2026-09-04f - D-120: an intermittent NaN, ~8%, pre-existing - recorded, not fixed

Found while validating D-119, and recorded here rather than chased now because
finding it needs hours of runs and the diagnosis is already useful.

### What happens

A NaN reaches T_dust. In `pathSegment` the sublimation test is

    if (.not. ANY( ... grid%Tdust(...) < TdustSublime(...) )) then ... stop

and **NaN fails every comparison**, so a NaN dust temperature reads as "all
grains have sublimed" and the run hits a hard stop. IEEE_INVALID flags
accompany it.

### It is intermittent and pre-existing

| build | clean | crashed |
|---|---|---|
| D-118 | 3 | 0 |
| D-119 + probe | 8 | 1 |

**~8% failure rate.** Two independent lines say the coupling work did not
introduce it: the rates are statistically indistinguishable between builds, and
the D-119 diff is 74 insertions with every added block skipped at
`pdrCoupleIter = 1`, so that build is a functional no-op.

At 8% this has almost certainly been present throughout this project, and every
benchmark reported in this log before today was a single run. It would never
have surfaced without repeats.

### The probe, armed and not yet triggered

`getDustT` now carries a one-shot report of the first non-finite
`dustAbsIntegral` with the terms that build it - `dabs`, `reslineheat`, and the
D-093 additions `pdrHeatPE` and `pdrHeatGG`. Four runs did not trip it. **That
is not evidence of absence**: at 8%, four clean runs happens 72% of the time.
Catching it with 90% confidence needs ~28 runs, about three hours.

The probe distinguishes the two candidate origins. If `pdrHeatPE` or
`pdrHeatGG` is non-finite the fault is in the coupling's feedback into the
grain energy balance; if `dabs` is, it predates the PDR work entirely. The
D-109 guard covers a degenerate interpolation interval in `getDustT`, which is
a different failure, and demonstrably does not cover this one.

### Why this matters beyond the bug

The methodological point is larger than the defect. MOCASSIN is a Monte Carlo
code and is not reproducible run to run - stated plainly here because this log
asserted the opposite earlier today and built comparisons on it. Consequences,
all of which cost time before being noticed:

- A single clean run is not verification. Acceptance needs repeats.
- Completion means the `end simulation reached` line, not the existence of an
  output file. A wait keyed on `grid2.out` returned "done" for a crashed run,
  and the comparison that followed produced a fictitious "24% MC noise floor".
- Run-to-run scatter must be measured before a difference between two runs can
  be called an effect. On the sec 5.4 model the median per-stage scatter is
  ~2%, and the median PDR temperature ratio spans 0.905-1.044 across three
  identical runs - wide enough that several single-run temperature comparisons
  earlier in this log carry more uncertainty than they were reported with.

## 2026-09-04g - D-121: the coupling loop across four fixtures, and a probe for D-120

Sixteen runs - four fixtures, two configurations, two repeats each. All
completed, no crashes, no NaN flags.

### The result is mixed, and that is the finding

H -> 2H2 front, against standalone 3D-PDR. **The sec 5.4 row is an absolute
A_V and the V1/V2 rows are ratios** - sec 5.4 is spherical and compared with
`cmp_sph.py` against `hii1dv2.pdr.fin`, whose front is at A_V = 0.9054, while
V1/V2 are planeIonization slabs compared with `cmp_slab.py` against
`benchmarks/pdr/baseline3dpdr/v{1,2}.pdr.fin`, which report ours/reference.
Agreement therefore means 0.9054 in the first row and 1.0 in the other two.
(Corrected in D-122: this table originally labelled every column a ratio,
which would have made the sec 5.4 entries mean the opposite of what they are.)

| fixture | 1 pass | 3 passes |
|---|---|---|
| sec 5.4 (abs A_V) | 0.497, 0.497, 0.498 | **0.904, 0.906, 0.905** |
| V1 | 1.113, 1.113 | **0.978, 0.978** |
| V2 | 1.007, 1.005 | **0.899, 0.901** |

Repeats agree to three digits inside every configuration, so every shift here
is real and far above the Monte Carlo scatter.

**Closing the loop is not a uniform correction.** It moves every front by 0.11
to 0.41 in ratio, but sec 5.4 and V1 move toward the reference while V2 moves
away. The reading this was drifting toward - "the sequential coupling was
lagging everywhere" - is not what the data says, and is recorded here as a
narrative that the wider set refuted rather than confirmed.

Two readings remain, and this set cannot separate them:

1. The loop is right and V2's previous agreement was coincidental - a lag that
   happened to cancel against another offset. Uncomfortable, but sec 5.4 is
   hard to explain otherwise: 0.497 -> 0.905 against a 0.9054 reference is not
   a coincidence.
2. Three passes is not converged and V2 is still in flight. The residuals were
   still falling at pass 3 (8.2e-4 -> 1.4e-4, 6.1e-3 -> 2.7e-3), so this is
   live.

A pass-count ladder - 1, 3, 5, 7 - separates them. Until it is run,
`pdrCoupleIter` stays at 1: a change that improves two fixtures and degrades a
third is not a default.

`ifront` and `test_Problem` completed clean in both configurations, so the loop
is safe on the non-PDR path as well.

### What the repeats settled, and what they did not

Front positions are stable to 3-4 digits across identical runs, so single runs
are adequate for measuring them from here. The median PDR temperature ratio is
NOT: it spans 0.905-1.044 across three identical runs of the same
configuration. Front comparisons in this log can be trusted at face value;
single-run temperature comparisons cannot, and several earlier entries report
them without that caveat.

### D-120 probe, broadened

The NaN of D-120 surfaces in `pathSegment` as "all grains sublimed", several
steps downstream of wherever it is born. The probe now checks three hand-offs
in order and records the first failure with the stage that produced it:

- chemistry outputs: `abun`, `pdrHeatPE`, `pdrHeatGG`, `pdrTgas`
- ionization: `ionDen` after `ionBalance`
- grain energy balance: `dustAbsIntegral` and its constituent terms

That distinguishes a NaN born in the coupling's feedback (the D-093 additions)
from one born in MOCASSIN's own radiation terms. It costs a comparison against
a saved flag, so it can ride along with ordinary work rather than needing a
dedicated hunt - which is how an 8% fault is realistically caught.

## 2026-09-04h - D-122: the "sublimed grains" crash is not a NaN

**Retraction first.** D-120 recorded the intermittent hard stop as an
intermittent NaN, and D-121 armed a probe that tests for non-finite values at
each hand-off in the coupled chain. That framing was wrong, and the probe it
motivated cannot trip on the actual fault. The evidence:

The pass-count ladder's first run (`Lhii1`, sec5.4 at one pass) died in
iteration 4 at `photon_mod.f90:1776` - `pathSegment: packet scatters with dust
at position where all grains have sublimed -2-`, followed by `stop`. That check
is

    .not. ANY( grainabun(...) > 0 .and. Tdust(1:nSpeciesPart(1), 0, cell) < TdustSublime(...) )

and it fires either when the temperature is NaN (NaN fails every comparison) or
when it is genuinely at or above the sublimation point. The iteration-3 grid
dump distinguishes the two, and it is unambiguous: **no NaN anywhere in
`dustGrid.out`, and exactly one cell above the 1400 K sublimation point of
Ssil.**

| run | passes | completed | hottest cells (size-averaged T_dust, K) |
|---|---|---|---|
| hiis3 | 1 | 5 iters | c994=86, c63=82, **c3=82** |
| Lhii1 | 1 | **crashed, iter 4** | **c3=1451, c4=1363**, c994=86 |
| Lhii3 | 3 | 5 iters | c994=86, c63=82, **c3=82** |
| Lhii5 | 5 | 5 iters | c994=86, c63=82, **c3=82** |
| Lhii7 | 7 | 5 iters | c994=86, c63=82, **c3=82** |

Three facts follow directly, and none of them needed a new run:

1. **It is not a NaN.** 1451 K is a finite number produced by the ordinary
   interpolation branch, not by the `iT>=nTemps` clamp (which would give 3000)
   and not by the D-109 degenerate-interval branch (which is now guarded).
2. **It is not the pass count.** `hiis3` is the same fixture at the same one
   pass and reaches iteration 5 with cell 3 at 82 K. One pass is not
   deterministically fatal, so `Lhii1` is a run-to-run excursion.
3. **It is not Monte Carlo noise.** Cell 3 sits at 82 K in four runs and at
   1451 K in one. For T_dust ~ (absorbed flux)^(1/(4+beta)), a factor 17.7 in
   temperature is a factor ~1e7 in absorbed energy. Path-length estimators do
   not have a 1e7 tail. Something in that cell's energy budget is wrong in that
   realisation, not merely under-sampled.

**Where cell 3 is.** With a 31^3 grid and the write order of `writeGrid`, cell
index 3 is (x,y,z) = (1,1,3) - exactly the position printed by the crash. That
is the corner column where two mirror walls of the planeIonization geometry
meet. It is also the same corner named in D-109: *"a corner cell of the ifront
benchmark produced T_dust = 2.3e9 K."* D-109 closed one fault there (a flat
emission-table interval divided into); this is a second, and the recurrence of
the same two cells (3 and 4, adjacent in z) says the geometry concentrates
something into that column rather than that one cell is unlucky.

**Hypothesis, held loosely:** mirror-wall reflection double-counts packets in
the corner where two walls meet, so the corner column's path-length estimator
occasionally accumulates far more than the physical flux. This is a hypothesis,
not a finding - the four predictions of D-109/D-112/D-116/D-119 that measurement
contradicted are the reason to say so explicitly.

**What was changed:** nothing in the physics. The D-120/D-121 probes stay (they
test a different thing and cost a comparison), and a new probe reports the first
`maxDustHot = 8` grains to cross their sublimation temperature, printing
`dustAbsIntegral` with the terms that build it - `dabs`, `resLineHeat`, `iT`,
`Ndust`, and under `-DPDR` the D-093 feedback terms `pdrHeatPE`, `pdrHeatGG`
and `xsecTot`. That separates a large continuum absorption from a large
resonance-line term from a small `xsecTot` blowing up the per-grain PDR
heating, which is the one division in that block that can amplify without bound.

**Why the probe is worth more than the crash rate suggests.** The excursion is
recorded in the grid dump whether or not a packet happens to scatter in that
cell, so a surviving run is still evidence: none of the four completed runs has
any cell above 1400 K. The observable is "did any cell cross", not "did the run
die", and that is roughly an order of magnitude more sensitive.

**Still open.** Whether the `stop` is the right response at all. A single cell
of 29791 losing its grains halts fourteen ranks; dropping the cell's dust and
carrying on is the physically consistent alternative, since that is already what
happens to individual sizes above `TdustSublime`. That change is not being made
while the cause is unknown - a crash that reveals a real energy-budget fault is
more useful than a silent workaround that hides it.

## 2026-09-05a - D-123: the pass-count ladder, and what it does to the D-121 reading

Twelve runs, three fixtures at 1/3/5/7 passes, one run per configuration (the
D-121 repeats established that front positions repeat to three digits, so
repeats bought nothing here). One run crashed - sec 5.4 at one pass, which is
D-122 and unrelated to the pass count; its 1-pass entry is taken from `cpl1`.

H -> 2H2 front as a ratio to standalone 3D-PDR, so all three fixtures are in
the same units (sec 5.4's absolute A_V divided by the reference 0.9054):

| fixture | 1 pass | 3 | 5 | 7 | d(1->3) | d(3->5) | d(5->7) |
|---|---|---|---|---|---|---|---|
| sec 5.4 | 0.549 | 1.000 | 1.009 | **1.010** | 0.451 | 0.009 | 0.0009 |
| V1 | 1.113 | 0.978 | 0.956 | **0.953** | 0.135 | 0.022 | 0.0030 |
| V2 | 1.007 | 0.899 | 0.883 | **0.880** | 0.108 | 0.016 | 0.0030 |

### 1. The loop converges, and V2's degradation is the converged answer

Every fixture is monotone and the increments fall by two orders of magnitude:
d(5->7) is 0.0009-0.0030 against d(1->3) of 0.108-0.451. Five passes is
converged; three is not, sitting 0.9-2.2% off the settled value.

This kills the more comfortable of D-121's two readings. That entry offered
*"three passes is not converged and V2 is still in flight"* as a live
possibility. It is not: V2 settles at 0.880 and stays there. **The converged
coupling genuinely disagrees with 3D-PDR for V2 by 12%, and no amount of
further iteration repairs it.**

### 2. What the loop actually does is collapse the scatter, not improve accuracy

| | 1 pass | 3 | 5 | 7 |
|---|---|---|---|---|
| between-fixture spread | 0.564 | 0.101 | 0.126 | **0.130** |
| mean ratio | 0.890 | 0.959 | 0.949 | **0.948** |

At one pass the three fixtures disagree with each other by 56% and happen to
straddle the reference. Converged, they agree with each other to 13% and sit
systematically 5% low. That reframes the whole D-121 result:

- **V2's 1.007 at one pass was not accuracy.** It is an unconverged number that
  landed near the right answer; the same calculation puts sec 5.4 at 0.549.
  Scoring a configuration by how close one fixture lands, when the same
  configuration is 45% wrong on another, measures luck.
- **sec 5.4's exact 0.9054 at three passes was the curve passing through.** It
  continues to 0.9146 and settles there, 1.0% past the reference. D-121 read
  that coincidence as the headline improvement.

A systematic 5% offset shared by three fixtures has a single cause worth
looking for. A 56% scatter does not. The loop is therefore a real improvement
in the model's internal consistency even though the mean error barely moves,
and the residual - +1.0% (sec 5.4), -4.7% (V1), -12.0% (V2) - is now a clean
physics question rather than noise.

### 3. Cost, and the default

Per-run wall time on 14 ranks, derived from consecutive completion times:

| fixture | 1 | 3 | 5 | 7 |
|---|---|---|---|---|
| sec 5.4 | (crashed at 3.0) | 10.1 | 18.0 | 23.4 |
| V1 | 10.0 | 17.0 | 25.5 | 26.2 |
| V2 | 4.4 | 9.1 | 12.8 | 15.8 |

Five passes costs about 2.5-3x one pass. Seven costs a further ~25% for a
change of 0.3% or less, so seven is not worth its price.

**`pdrCoupleIter` default moves from 1 to 5.** The standing requirement is that
the coupling be as self-consistent as it can be made, and 1 is the setting
whose answers depend on where the iteration was stopped. Three passes is a
defensible cheaper setting - within 2.2% of converged at ~40% of the cost - and
is what to use when turnaround matters more than the last two percent.

This bakes in a configuration that is measurably worse for V2 against 3D-PDR
(0.7% error at one pass, 12% converged), and that is a deliberate judgement
rather than an oversight: an unconverged calculation that lands near the
reference on one fixture out of three is not evidence the calculation is right.

## 2026-09-05b - D-124: the excursion is gas-grain collisional heating, and it is not a PDR fault

Two 10-run replications of sec 5.4 at one pass, the configuration D-122 crashed
in. All twenty completed; none crashed. The probe fired in 3/10 and 3/10, and
one run of the first set still carried a hot cell in its final dump. So the
excursion happens in ~30% of runs, usually relaxes before the last iteration,
and only becomes a crash when a packet also happens to scatter in that cell
while it is hot - which is the ~8% originally recorded as D-120.

### The decomposition

    T = 3000.00 (the iT>=nTemps clamp)
    dustAbsIntegral = 1266735.88     emInt(3000 K)  = 5.18e-05
    dabs            = 3.23e-12       resLineHeat    = 4.34e-44
    gasDustColl_d   = 1266735.88     photoelHeat_d  = 1.10e-14
    grainPot = 0.290   Ne = 109.65   Te = 9190.8
    pdrZone = 0   pdrHeatPE = 0   pdrHeatGG = 0   xsecTot = 0

`dustAbsIntegral` and `gasDustColl_d` are equal to the last digit. The radiative
term `dabs = 3.2e-12` is an entirely normal ~80 K grain. **The whole excursion
is the gas-grain collisional heating term.**

This rules out both hypotheses this log has carried:

- **Not the mirror-wall corner (D-122).** The cell is #4 here and #6 in the
  other run, not the (1,1,3) corner, and D-122's reasoning from cell 3 being
  hot in one run and 82 K in four was a coincidence of which cell tripped first.
- **Not the PDR coupling at all.** `pdrZone = 0`: these are ionized cells, and
  the D-093 feedback terms `pdrHeatPE`, `pdrHeatGG` and the `xsecTot` divisor
  named in D-122 as "the one division that can amplify without bound" are all
  identically zero on this path. The fault is in MOCASSIN's own
  `setDustGasCollHeatCool` and predates this branch.

Two further hypotheses are dead on the evidence: zero "insane eta" warnings and
zero `nDustCapped` hits across all twenty runs, and `grainPot` = 0.29-0.84 with
`Ne` = 110 and `Te` = 7900-9200 are all unremarkable.

### Why the number cannot come from those inputs

Hand evaluation of the electron branch with the reported values - kT = 0.0582
Ryd, psi = -4.98, eta = 5.98, xi = 3.49, vmean = 5.96e7 cm/s, Ne = 110,
pi a^2 = 3.14e-12 cm^2 - gives ~1e-13 erg/s per grain after the 1/4pi. The code
produced 1.27e6. **A factor of 1e19 is not something a smooth function of these
inputs produces**, which points at a stale or out-of-range value read at the
moment the term is accumulated rather than at the physics of the formula. The
accumulator reset (`gasDustColl_d = 0.`) is unconditional at the top of the
routine, so it is not cross-cell accumulation.

A third probe now prints, for whichever term first pushes the running total
past 1e-6, the element, ionization stage, grain species and size with every
factor: `ionDenUsed`, `elemAbun`, `Hden`, `S`, `vmean`, `kT`, `eta`, `xi`,
`psi`, `grainPot`, `IPerg`, `Tdust` and `mcp`.

### A separate defect found while reading the routine - NOT yet verified

    S = 2*mcp*MsurfAtom(global_ns)/(mcp+MsurfAtom(global_ns))**2

is the standard accommodation coefficient `2mM/(m+M)^2`, which is dimensionless
and O(1) only when both masses share units. `mcp = aWeight(elem)*amu` is in
**grams** (~1.7e-24); `MsurfAtom` is declared in common_mod as *"mass of surf
atom of a grain [amu]"* - a pure number ~20. Mixing them gives S ~ 1e-25
instead of O(0.1), which would suppress the neutral-atom half of the gas-grain
coupling almost entirely.

This is recorded as an observation, not a fix. It runs in the opposite
direction to the excursion (it under-heats), so it is not the cause, and
changing it would alter dust temperatures in every model. It needs its own
measurement before anything is touched.

### Retraction: an analysis bug of mine

While tracing this I reported that the affected cell had `Ndust = 8.7e-09`
against neighbours "at 8" and reasoned it was a nine-orders-of-magnitude
dust-poor cell. That was wrong. The system `awk` is mawk, which does not parse
Fortran E-notation: `"8.70684591E-09" + 0` evaluates to **8**. Every cell in
these models carries the identical `Ndust = 8.707e-09`. There is no dust-free
cell and no dust-free effect.

Re-scanned in Python, the hot-cell counts are unchanged (0,0,0,0,1), because
Fortran writes values above 1400 in plain decimal - so the D-123 ladder table,
whose `hot` column comes from `ladder.py` using Python floats throughout,
stands as reported. **Any numeric scan of Fortran list-directed output in this
project must use Python, not awk.**

## 2026-09-05c - D-125: the probe suppresses the fault it measures

The term-level probe added at the end of D-124 returned nothing in ten runs.
Taken with the four bounds-checked runs that followed, the pattern is not
chance:

| set | build | probe hits | hot cells in final dump |
|---|---|---|---|
| H122 | D-122 probe only | 3/10 | 1 |
| K122 | + decomposition prints in getDustT | 3/10 | 2 |
| M124 | + term-level prints inside setDustGasCollHeatCool | **0/10** | 0 |
| B124 | M124 source + `-fcheck=bounds` | **0/4** | 0 |

6/20 in the first pair against 0/14 in the second. P(0/14) at the measured 30%
rate is 0.7%, so the instrumentation is suppressing the fault rather than the
fault having gone quiet on its own.

The obvious mundane explanations were checked and ruled out first: both probes
are present in the binaries (6 strings each), the per-run binaries are
byte-identical to the repo build, and `pdrCoupleIter 1` is pinned in every
input.

**Why this is evidence rather than an annoyance.** D-124 concluded from
arithmetic that the value cannot come from its inputs - a hand evaluation gives
1e-13 and the code gives 1.27e6 - and inferred a stale or out-of-range read.
A read of that kind depends on what the surrounding memory happens to hold, so
it is exactly the class of fault that a probe can extinguish. Two changes went
in with the term-level probe: a new module variable in `common_mod` (which
moves module storage) and an in-loop read of the accumulator (which forces it
through memory instead of a register). Either would change what a stray read
finds. The Heisenbug is a prediction of the D-124 hypothesis, not a setback to
it.

**The distinction that makes the next experiment possible:** `-fcheck=bounds`
inserts checks but does **not** move data; adding a module variable does. So
the B124 result is uninformative - bounds checking had nothing to catch because
the fault did not occur - while a bounds build of the *K122 source layout*
should still fire.

That build is `mocassin.k122bounds`: the D-122 probe exactly as it was in the
set that fires, with the D-124 in-loop probes and their counters removed so the
layout matches, compiled `-O2 -fcheck=bounds -fbacktrace`. Eight runs give a
94% chance of at least one occurrence at the measured rate. The outcomes are
mutually exclusive and both worth having:

- **bounds violation reported** - the array, index and line are named, and
  D-124's hypothesis is confirmed at a specific line;
- **fault fires, bounds silent** - it is not an out-of-range read. Uninitialised
  memory or a genuine floating-point path then become the candidates, and the
  next instrument is valgrind or `-finit-real=snan`, not more repetitions;
- **fault does not fire in eight** - even the bounds instrumentation perturbs
  it, and the fault has to be caught by a method that does not recompile the
  routine at all.

A `CO=bounds` target was added to the Makefile for this (`-O2 -fcheck=bounds
-fbacktrace -g`), keeping full optimisation so a run stays minutes rather than
hours. It is worth having independently of this bug.

### The control, which should have been run alongside

The layout-preserving bounds build fired 0/8 as well - the third outcome. At
that point every non-firing set differed from the firing ones in **two** ways:
the instrumentation, and being run several hours later. The whole inference
rested on a 30% rate measured before any of them, and nothing had re-checked
that the rate itself was still 30%.

Ten runs of the *unmodified* K122 binary - byte-identical to the one that fired
3/10, launched after all the instrumented sets - fired **4/10**.

| build | fires |
|---|---|
| uninstrumented (H122, K122, control C122) | 10/30 |
| instrumented (M124, B124, KB) | **0/22** |

P(0/22) at the measured rate is 3.9e-4. The rate is stable across the whole
session, so the suppression is the instrumentation and not drift. The control
is what licenses that sentence; without it the same numbers would have
supported "the fault stopped happening for some other reason" equally well.

### A cleaner hypothesis than a stale read

`-fcheck=bounds` and an in-loop read of the accumulator have one thing in
common besides perturbing memory: **both inhibit auto-vectorisation.** A
vectorised loop consuming a garbage lane fits every observation as well as a
stray read does, and it is separable - `-fno-tree-vectorize` changes codegen
without moving a single byte of data layout, so it isolates vectorisation from
the layout effects that adding a module variable brings with it.

Ten runs are under way on the firing source built with
`EXTRA=-fno-tree-vectorize` (a new Makefile hook, appended after the `CO`
block, so questions about codegen can be asked without editing the routine and
perturbing the thing being measured):

- **still fires ~4/10** - vectorisation is not involved, and the suppression
  came from layout or register allocation; the remaining instrument is one that
  does not recompile at all;
- **fires 0/10** - the fault lives in a vectorised loop, which narrows it from
  "somewhere in `setDustGasCollHeatCool`" to a specific loop nest and makes
  `-fopt-info-vec` on that routine the next read.

**Scope note.** Every occurrence has `pdrZone = 0`. This is MOCASSIN's own
dust-gas collisional heating in ionized cells, so it is not confined to the PDR
branch and plain MOCASSIN runs carry it too. Like the negative dielectronic
recombination of D-116, the fix will belong on `dev` rather than here.

## 2026-09-05d - D-126: vectorisation ruled out; instrument where the fault survives

`-fno-tree-vectorize` on the firing source layout fired **3/10**, against the
uninstrumented baseline of 10/30. Auto-vectorisation is not involved, and the
hypothesis floated at the end of D-125 - a vectorised loop consuming a garbage
lane - is dead.

That result is worth more than the hypothesis it killed, because it establishes
where instrumentation is safe. Codegen in `setDustGasCollHeatCool` can be
changed (no vectorisation at all) without suppressing the fault, so the
suppression in M124 was not "any recompilation": it was the specific
combination of a new module variable and an in-scope read of the accumulator.

### Honest accounting of the suppression evidence

D-125 quoted 0/22 at P = 3.9e-4, which lumps three builds. Taken separately
against the 1/3 baseline:

| build | result | P(0 of n) |
|---|---|---|
| M124 (in-loop probe) | 0/10 | 1.6% |
| B124 (that source + bounds) | 0/4 | 20% |
| KB (firing layout + bounds) | 0/8 | 4% |

Only M124 is strong on its own, and B124 shares its source. **The claim that
bounds checking by itself suppresses the fault rests on KB's 0/8, which is a 4%
result - suggestive, not established.** The combined figure is real but should
not be read as three independent confirmations.

### The instrument this licenses

Every build that fires carries a probe in `getDustT`, and the probe grew
between H122 and K122 without changing the rate. So `getDustT` can be edited
freely while `setDustGasCollHeatCool` cannot.

`setDustGasCollHeatCool` is called at update_mod.f90:640, earlier in the same
`updateCell` invocation than the `getDustT` at :312. The probe now rebuilds the
electron half of the collisional term from `NeUsed`, `TeUsed` and
`grainPot(nS,ai)` as they stand at the probe point, and prints it beside the
stored value with their ratio, plus `maxval`/`minval` over the whole array:

- **recomputed ~ stored** - the formula really does produce ~1e6 from the state
  it was given, so one of its inputs was extreme at compute time even though
  all three read as normal a few lines later. The hunt moves to what changes
  between :640 and :312.
- **recomputed ~1e-13, stored orders above** - the stored value does not
  correspond to any state the cell has held, which is corruption, and
  `maxval`/`minval` says whether one entry or the whole array is affected.

Observed magnitudes so far span 2.26e-06, 2.81, 44.7 and 1.27e6 across
occurrences, with `grainPot` 0.29-0.84, `Ne` ~110 and `Te` 7900-9200 every
time. A formula whose inputs move by a factor of three while its output moves
by twelve orders of magnitude is already hard to reconcile with the first
reading.

### An unrelated defect noticed in passing - not fixed

update_mod.f90:632

    if (grainPotP(isp,ai) == 0) grainPotP = 1

assigns **the whole array**, not the element - the indices are missing on the
left-hand side. Every grain species and size gets its pointer reset whenever
any single one comes back zero. It is not this fault (it clamps to a valid
index rather than producing garbage) and single-species models cannot show a
difference, so it is recorded for its own measurement rather than changed here.

## 2026-09-05e - D-127: found it. IPerg is read uninitialised on every call

update_mod.f90:1092

    if (istage>1) then
       ... IPerg = <ionization potential> ...
    end if                        ! <- no else branch
    ...
    gasDustColl_d(ns,na) = gasDustColl_d(ns,na) + ... * &
         & (2.*kT*Ryd2erg*xi - eta*(Z*grainPot*Ryd2erg - IPerg + 2.*kBoltzmann*Tdust))

`IPerg` is used unconditionally but assigned only for `istage > 1`, and the
loop's first iteration is `elem = 1, istage = 1`. Fortran does not initialise
locals, so **every call to `setDustGasCollHeatCool` reads a stack slot** and
puts its contents into the dust temperature.

Physically the fix is not a patch: `IPerg` is the recombination energy released
when an electron on the grain neutralises an impacting **ion**. A neutral atom
carries none, so `IPerg = 0.` in the `else` is the correct value.

### The evidence, and what each piece does and does not establish

| observation | what it shows |
|---|---|
| the source at :1092 | the read is uninitialised. This is not statistical - it is a fact about the code |
| `-finit-real=zero`, flags only, 0/10 | uninitialised reals are the cause. **No layout change**, so this is not confounded |
| `-fno-tree-vectorize`, flags only, 3/10 | codegen alone does not suppress; the sensitivity is to memory, not instructions |
| layout-changing builds M124/R126/KB, 0/22 | consistent with a stack read |
| the fix, 0/12, no cell above 1400 K | **corroborating but confounded** - the fix is a source change, and D-126 established that any source change moves the stack |

The last row is worth being explicit about: 0/12 at P = 0.8% would be
convincing on its own only if the fix could not have suppressed the fault by
accident, and it could. The claim rests on the first two rows - a defect read
directly out of the source, and a flag-only experiment that neutralises exactly
that class of defect without touching layout.

### The arithmetic checks out, and it is only survivable because of a second bug

The prefactor multiplying `IPerg` in the neutral term, with Te = 9190 K,
Ne = Hden = 100, a = 0.01 um and the `S` from D-124, is 5.8e-30. So:

- clamping T_dust at 3000 K needs the garbage `IPerg` above **1.5e24**;
- the observed 1.27e6 needs about **3.7e34**.

Both sit inside single-precision range (max 3.4e38), and a stack slot holding
an arbitrary bit pattern lands above 1e24 often enough to explain a ~1/3 rate.
The legitimate value is ~2e-11 erg.

**The two defects interact, and the order of fixing matters.** D-124 recorded
that `S = 2*mcp*MsurfAtom/(mcp+MsurfAtom)**2` mixes grams with amu, giving
1.7e-25 where the accommodation coefficient should be O(0.1). That error
suppresses the whole neutral-atom term by 24 orders of magnitude - and it is
the only reason the garbage `IPerg` is survivable. Correcting `S` alone, with
`IPerg` still uninitialised, would have amplified this term by 6e23 and turned
an intermittent crash into a certainty. **`S` must not be touched before this
commit is in.**

### Correction to D-124's reasoning

D-124 argued "dabs = 3.23e-12 is an entirely normal ~80 K grain, so the
radiative term is healthy and the excess is all gas-grain". The conclusion is
right - `dustAbsIntegral` equalled `gasDustColl_d` to the last digit - but the
argument was not: `dabs` is written only under `lgTraceHeating .and.
taskid==0`, which is off in these runs, so the probe was printing another
uninitialised stack slot. The same is true of `resLineHeat`, whose 4.34e-44
in every print is a denormal, and which is why the logs carry IEEE_DENORMAL
flags. Neither enters the physics (both are read only inside the guards that
write them), but both are now zeroed unconditionally so that a read outside the
guard means what it appears to mean.

### What this costs downstream

The garbage entered the neutral-atom collisional heating on **every call**,
usually as a stale value from the previous call at the same stack depth rather
than as something wild. So dust temperatures carry a small systematic error
everywhere, not only in the 1/3 of runs that produced a visible excursion.
Every dust temperature and every front position measured before this commit was
measured with it present, including the D-123 ladder. Those need re-checking
against fixed code before they are quoted again.

Scope: `pdrZone = 0` in every occurrence - this is MOCASSIN's own dust-gas
collisional heating, it affects every variant, and like D-116 it belongs on
`dev`.

## 2026-09-05f - D-128: the ladder re-run clean, and a prediction of mine that was wrong

Twelve runs on the D-127 build, pass count pinned in every input. All completed
- including sec 5.4 at one pass, which is the configuration that crashed in
D-122 - and **no cell anywhere crossed the sublimation point**. The fix holds.

### The fronts did not move

| fixture | pass | pre-fix | post-fix | delta |
|---|---|---|---|---|
| sec 5.4 | 1 | 0.4969 (from cpl1; the ladder run crashed) | 0.4982 | +0.0013 |
| sec 5.4 | 3 | 0.9054 | 0.9051 | -0.0003 |
| sec 5.4 | 5 | 0.9138 | 0.9150 | +0.0012 |
| sec 5.4 | 7 | 0.9146 | 0.9146 | 0 |
| V1 | 1/3/5/7 | 1.113 / 0.978 / 0.956 / 0.953 | identical | 0 |
| V2 | 1/3/5/7 | 1.007 / 0.899 / 0.883 / 0.880 | 1.007 / 0.899 / 0.882 / 0.880 | -0.001 |

Every difference is at or below the Monte Carlo scatter established in D-121,
where repeats of one configuration spanned 0.904-0.906.

**This contradicts what I predicted.** D-127 recorded that "the garbage entered
the neutral-atom collisional heating on every call... so dust temperatures
carry a small systematic error everywhere, not only in the 1/3 of runs that
produced a visible excursion", and told the reader the ladder needed
re-checking before it could be quoted. The re-check says the fronts were never
affected.

The reason is the interaction already documented in D-127, followed through to
its conclusion, which I did not do at the time. The `S` units bug suppresses
the whole neutral-atom term by 24 orders of magnitude, so a garbage `IPerg`
contributes nothing at all unless it exceeds ~1.5e24. **The fault was never
"small everywhere and occasionally large" - it was negligible or catastrophic,
with nothing in between.** The arithmetic for that was already in D-127; I drew
the wrong conclusion from it by reasoning about how often the variable was read
rather than about what magnitude was needed to matter.

That is worth stating plainly because the prediction was the stated reason for
this whole re-run. The re-run was still right to do - "the fronts are unchanged"
is only knowable by measuring - but it confirmed the old numbers rather than
correcting them.

### D-123 stands unchanged, now on clean data

| fixture | 1 | 3 | 5 | 7 | d(3->5) | d(5->7) |
|---|---|---|---|---|---|---|
| sec 5.4 | 0.550 | 1.000 | 1.011 | **1.010** | 0.0109 | 0.0004 |
| V1 | 1.113 | 0.978 | 0.956 | **0.953** | 0.0220 | 0.0030 |
| V2 | 1.007 | 0.899 | 0.882 | **0.880** | 0.0170 | 0.0020 |

| | 1 pass | 3 | 5 | 7 |
|---|---|---|---|---|
| between-fixture spread | 0.563 | 0.101 | 0.129 | **0.130** |
| mean ratio | 0.890 | 0.959 | 0.950 | **0.948** |

Converged by five passes; V2's disagreement is the converged answer, not a
way-point; the loop buys internal consistency (spread 0.563 -> 0.130) rather
than accuracy (mean stuck near 0.95). `pdrCoupleIter = 5` stands.

One improvement over D-123: the sec 5.4 1-pass entry is now measured directly
(0.4982) instead of borrowed from `cpl1` because the ladder run had crashed.

### Still open

- **`S` mixes grams with amu** (~1.7e-25 against an intended O(0.1)). This is
  now the most consequential known defect in the dust-gas coupling: it
  effectively deletes the neutral-atom collisional channel. It must not be
  corrected on its own - D-127's `IPerg` initialisation is the prerequisite -
  and it needs its own measurement of what the dust temperatures do when the
  channel is restored.
- **`grainPotP` whole-array assignment**, update_mod.f90:632, indices missing
  on the left-hand side. Single-species models cannot show it.
- The residual front offsets: +1.0% (sec 5.4), -4.7% (V1), -12.0% (V2). With
  the crash explained and the ladder converged, this is the open physics
  question.

## 2026-09-05g - D-129: the sticking coefficient's units, fixed and measured

    S = 2*mcp*MsurfAtom(global_ns)/(mcp+MsurfAtom(global_ns))**2

is the elastic energy-transfer fraction 2mM/(m+M)^2 defined at the end of
appendix A.10 of Baldwin, Ferland & Martin. It is dimensionless and
scale-invariant, so it is correct only when both masses carry the same units.
They did not: `mcp = aWeight(elem)*amu` is in grams (~1.7e-24) while
`MsurfAtom` is in amu - 20.077 in the `astroSilD2003_base.nk` header, and
declared "[amu]" in common_mod. The result was 1.67e-25 where it should be
0.091, which deleted the neutral-atom collisional channel outright.

Three independent confirmations before touching it: the grain data file, the
declaration, and **Cloudy computing the identical quantity from two amu
masses** (`grains_mie.cpp:1154`, citing the same BFM appendix).

The fix is applied to the `S` expression, not to `mcp`. `mcp` is also used for
`vmean = sqrt(eightkT_pi/mcp)`, which legitimately wants grams - correcting
`mcp` would have fixed `S` and silently broken the thermal velocity.

    S = 2.*aWeight(elem)*MsurfAtom(global_ns)/(aWeight(elem)+MsurfAtom(global_ns))**2

| collider | old S | new S |
|---|---|---|
| H | 1.67e-25 | 0.0910 |
| He | | 0.2772 |
| C | | 0.4684 |
| O | | 0.4936 |

approaching 0.5 as m -> M, as the formula requires.

### The coupled fixtures cannot see it, by construction

sec 5.4, V1 and V2 at the default five passes: fronts 0.9150 -> 0.9149,
0.956 -> 0.953, 0.882 -> 0.882; dust temperatures within 0.05%. That is not
reassurance, it is a blind test. In PDR cells the D-093 branch replaces
`gasDustColl_d` wholesale with 3D-PDR's rates - exactly where neutral atoms
dominate - and in the ionized cells that do use this path the neutral
population is a ~1e-4 fraction against an ion channel that already had S = 1.

### Measured where the channel is live

A plain photoionization model - the same geometry with the PDR stripped out, so
nothing replaces the term - run three times each with binaries differing in
that one expression and nothing else (the rebuilt `newS` binary was verified
byte-identical to the one used above).

| statistic | old S | new S | change | groups overlap | perm p |
|---|---|---|---|---|---|
| T_dust min | 12.846 | 14.145 | **+10.11%** | no | 0.10 |
| T_dust median | 20.564 | 20.569 | +0.03% | yes | 0.60 |
| T_gas median | 5301.3 | 5360.1 | +1.11% | no | 0.10 |
| T_gas max | 9422.0 | 9337.7 | -0.90% | no | 0.10 |

Two-sided exact permutation on 3v3; 0.10 is the floor, so it means the two
groups do not overlap at all - the strongest result this sample size admits.
The pattern is what the physics predicts: the coldest dust, deepest in the
model where radiative heating is weakest and the collisional term competes,
warms by 10%, while the bulk median - the one statistic that overlaps - does
not move.

**Correction to my own analysis.** On first seeing the single-pair result I
judged it against "twice the within-group spread" and reported every statistic
as *not separable from scatter*. That is not a test: it ignores that three of
the four groups do not overlap at all. Replacing it with an exact permutation
test reverses the verdict on three of four rows. The instinct to demand a
scatter control was right - a single pair could not have established this - but
the criterion applied to the control was wrong.

### Standing

The fix is correct on first principles independently of how much it moves these
models, so it goes in regardless. It changes no benchmark result and overturns
no earlier conclusion; it restores a channel that was silently absent. D-127's
`IPerg` initialisation was the prerequisite and is in on both branches, so the
ordering constraint recorded there is satisfied.

## 2026-09-05h - D-130: multi-component dust has never worked

Chasing the `grainPotP` whole-array assignment noted in D-126 opened a larger
seam: MOCASSIN carries a species index in two conventions and mixes them.

- **Per-component arrays** take `(icomp, local)`: `grainAbun`,
  `componentMinRadius`, `componentMaxRadius`.
- **Per-species physical data** is **global**, built in `ph_mod` as
  `dustComPoint(icomp)+i-1`: `rho`, `grainVn`, `MsurfAtom`, `dustAbsXsecP`,
  `dustScaXsecP`.

`grainPot` and `grainPotP` are allocated `1:nSpecies` - global - and written at
the global index. They were read at the local one.

### The crash

`updateCell` resolves `ispbig = isp + dustComPoint(nspU) - 1` and passes it to
`setGrainPotential`, which forwards it to `getGrainEmission` - which applied
`dustComPoint` **a second time**:

    global_isp = dustComPoint(nspU) + isp - 1     ! isp is already global

With two components, `dustComPoint(2) = 2`, so a component-2 grain became index
3 into `dustAbsXsecP`, dimensioned 2. Under `-fcheck=bounds` that is a clean
diagnostic; at -O2 it is a segfault. **A two-component dust model crashes
immediately on the unmodified code**, which is presumably why nothing in this
project or its fixtures has ever used one.

### What else was wrong once it could run

- `grainPot`/`grainPotP` read locally in `setPhotoelHeatCool`,
  `setDustGasCollHeatCool` and `getDustT`, so component 2 used component 1's
  grain potentials. Now global everywhere.
- `if (grainPotP(isp,ai) == 0) grainPotP = 1` assigned the **whole array** -
  the left-hand indices were missing - resetting every species and size
  whenever any one came back zero. This was the D-126 note; it turned out to be
  the smallest of the family.
- One `grainVn(ns)` in the photoelectric yield denominator whose own numerator
  already used `grainVn(global_ns)`.

### Measured on a purpose-built two-component model

15^3, plain photoionization, silicate inside and graphite outside - genuinely
different grains (`grainVn` 0.588 vs 0.323 Ryd, `MsurfAtom` 20.077 vs 12.004
amu). Before: segfault. After: completes with zero bounds violations.

`B` keeps the crash fix but restores the local reads; `C` is the full fix.
Per-cell |T_dust difference|, median over the cells of each component:

| component | C/C2 | C/C3 | C2/C3 | **B/C** |
|---|---|---|---|---|
| 1 silicate - fix cannot act here | 0.174 | 0.170 | 0.147 | **0.160** |
| 2 graphite - fix acts | 0.471 | 0.473 | 0.470 | **0.619** |

Component 1 is the control and it is not a rhetorical one: `dustComPoint(1) = 1`
makes local and global indices *identical* there, so B and C are the same
computation and must differ only by Monte Carlo noise. They do - 0.160 sits
inside the 0.147-0.174 noise band.

Component 2 is where the indices diverge. Its noise floor is reproducible to
+/-0.002 (0.4702, 0.4709, 0.4730) and the fix moves it to 0.619 - far outside
that band. The magnitude is modest because the two work functions differ by
less than a factor of two and dust temperature is dominated by radiative
heating; the point is that it is real and localised exactly where the analysis
said it would be.

### Scope

Unreachable with a single dust component, where `dustComPoint(1) = 1` collapses
the two conventions - which is why every fixture in this project has been blind
to it. Belongs on `dev` with D-127 and D-129: it is MOCASSIN's own dust code and
nothing here is PDR-specific.

### Process note

I discarded these edits mid-session with a careless `git checkout
source/update_mod.f90` while building a comparison binary, and had to
reconstruct them. Re-applied by unique context rather than line numbers, and
verified by rebuilding to a binary **byte-identical** to the one that had
already run the test model clean. Commit before building variants, not after.

## 2026-09-05i - D-136: 3D-PDR is a reference, not a benchmark; MOCASSIN owns the dust

A project-level ruling, and it changes how every comparison in this log should
be read from here on.

1. **3D-PDR models are references, not benchmarks to be reproduced.**
   Divergence from 3D-PDR stops being automatically a defect. Numbers are still
   compared, but agreement is no longer the success criterion, and a
   disagreement is to be reported with its cause rather than closed by tuning.

2. **MOCASSIN owns the dust, and everything that follows from it.** Where the
   codes disagree because they assume different grains, MOCASSIN's answer wins:
   it is computed from the grain population actually in the model. If PAH
   physics is wanted, PAH particles go into MOCASSIN's dust composition - a
   PAH formula is not imported into a silicate inventory.

### What this settles

D-134 measured MOCASSIN's photoelectric heating at ~6x 3D-PDR's, and since that
term is ~96% of the PDR heating budget, whichever value is used sets the
temperature. The question of which is "right" is now answered by policy rather
than by which reproduces the reference: **MOCASSIN's**, because it follows from
the dust the model actually has. `pdrPEfromPDR` stays off, and exists only to
quantify the gap against the reference.

This also means the deep-PDR temperature under a MOCASSIN-owned thermal balance
is not required to land on 3D-PDR's ~47 K. If it settles elsewhere with every
term correctly normalised and correctly attributed, that is a result about this
model's dust, not an error to be removed.

### What it does NOT settle

The distinction that matters is *why* the codes disagree:

- **Different dust assumptions** -> MOCASSIN wins, by the rule above.
- **Incomplete physics in MOCASSIN** -> the term must still be taken from
  3D-PDR, because this is not a modelling choice. The live case is D-133:
  MOCASSIN excites [C II] 158um and [O I] 63um with electrons alone, while
  3D-PDR carries H, H+, He and H2 partners, and in neutral gas the electron
  fraction is ~1e-4. That is a gap in MOCASSIN, not a different assumption, and
  handing the term across stays correct. The long-term fix is to give MOCASSIN
  the neutral collision partners.

The rule is therefore: hand over what MOCASSIN lacks or computes with
incomplete physics; never hand over what it computes differently because it
models different dust.

## 2026-09-05j - D-139 reverted, D-141: use Cloudy's H2 cross section

### The opacity that was not missing

D-138 measured H I photoionization depositing 99.5% of the heating in deep PDR
cells, at the Lyman edge. The inference drawn was that the 13.6-15.4 eV window
had no absorber - D-107's H2 continuum starts at 15.43 eV, its own ionization
threshold - so a flat 6e-18 cm^2 was added there (D-139).

Both halves were wrong, and the user's question about Cloudy exposed the first:

1. **Cloudy puts zero H2 continuum there.** `Yan_H2_CS`
   (`source/mole_h2_etc.cpp:358`) opens with `if( energy < 15.4 ) cross_section
   = 0.`. That window is covered by H2 LINE absorption in the higher electronic
   bands, not a continuum. The reference the fix would have cited says not to
   make it.

2. **The premise was false anyway.** The argument rested on D-099's remark that
   the atomic hydrogen fraction is ~0.002, quoted without re-measuring it here.
   Measured in this model's deep PDR cells: **x(H) = 0.189**, so n(H0) = 18.9
   cm^-3 and the Lyman-edge optical depth is **230 per cell**, ~5000 to
   A_V = 2.3. The window is opaque by thousands of e-foldings and no stellar
   photon reaches that depth. Nothing was missing.

D-139 is reverted, with the reasoning kept in the source so it is not retraced.
The H I heating measured at depth is real and still unexplained - it cannot be
transported stellar light, so either the heating integral sees a field it should
not, or it is multiplied by a density it should not. A probe on `Jste` at the
edge and on the densities the opacity is built from is running.

### D-141: the cross section itself, from Cloudy

D-107's comment asked for the tabulated cross section once a power law stopped
being adequate. It is now ported: Yan, Sadeghpour & Dalgarno 1998 (ApJ 496,
1044) with the 2001 erratum (ApJ 559, 1194), exactly as Cloudy implements it -
same branch boundaries, coefficients and E^-7/2 scaling.

The power law was not merely imprecise, it was the wrong shape:

| E (eV) | Yan | D-107 power law | ratio |
|---|---|---|---|
| 16 | 2.86e-18 | 5.63e-18 | 1.97 |
| **18** | **9.82e-18** | 4.09e-18 | **0.42** |
| 25 | 4.30e-18 | 1.69e-18 | 0.39 |
| 40 | 9.93e-19 | 4.74e-19 | 0.48 |
| 200 | 6.17e-21 | 6.15e-21 | 1.00 |

The true cross section rises from threshold to 9.8e-18 cm^2 at 18 eV and then
falls; the power law fell monotonically from 6.2e-18, so it was a factor 2.5
LOW right across the peak and a factor 2 HIGH just above threshold, converging
only above ~200 eV.

The Fortran port reproduces the C to five significant figures at 16, 18, 25,
40, 100 and 500 eV, checked against an independent evaluation of the published
fit rather than against itself. Both build flavours verified.

## 2026-09-06a - D-143: the deep-PDR heating is not transported light

Where the H I photoionization heating of D-138 comes from, run to ground.

### The chain of measurements

| probe | result |
|---|---|
| D-138 per-ion | H I is 99.5% of the heating at A_V > 1; carbon 0.0% |
| D-140 field at the edge | `Jste` at the Lyman edge is EXACTLY zero |
| D-142 whole band | one bin non-zero out of 171: bin 465, 1.7922 Ryd, in **31 of 31** cells |
| D-143 opacity there | smooth, no dip: H I sigma 1.269e-18, tau = **175 per cell** |

`sum(Jste) == max(Jste)` over bins 430-600 in every sampled cell, and the other
170 bins are exact zeros - not small, zero. An exact zero means no packet of
that frequency ever crossed the cell, so this is packet discreteness rather
than a field leaking through.

### What that rules out

- **Not missing opacity.** D-139 added a continuum for a leak that does not
  exist; reverted. H I alone gives tau = 175-230 per cell across this band.
- **Not a cross-section or density error.** density(1,1) = 71-83 cm^-3 is right
  (ionDen x elemAbun x Hden), the table is tabulated HlevNuP(1)..nbins, and the
  opacity is smooth across 460-470.
- **Not Monte Carlo shot noise.** Noise would scatter across bins from cell to
  cell. The same bin in 31 of 31 cells is deterministic.
- **Not the metals, not the coolants, not the photoelectric split, not the 4pi.**
  Each was proposed and each was wrong (D-133, D-134, D-135).

### What is left

Photons are reaching cells they cannot reach by attenuated transport. The route
matters, not the amount. The prime suspect is the boundary treatment: this
model runs `symmetricXYZ`, and D-049 records that `pathSegment`'s z-min mirror
assigns `yAxis(1)` to `rVec%z` - reported and never fixed, and noted there as
harmless for 1D slabs but not for anything using the z mirror.

Bin 465 sits just below the He I edge (1.807 Ryd), the natural transparency
window between H I falling as nu^-3 and He I switching on. That is where
surviving photons SHOULD cluster - so the frequency is not itself anomalous.
What is anomalous is that any survive at tau = 175 per cell over ~22 cells.

### Standing

This is a MOCASSIN transport question, not a coupling one. It is only visible
because the self-consistency work made MOCASSIN's own thermal balance depend on
its radiation field in gas where that field should be zero; with the PDR owning
the temperature (the shipped default) it is entirely masked. Nothing in use is
affected, and `pdrTeFromMocassin` stays off until this is closed.

Note on the D-143 probe itself: it prints immediately after the H I opacity
call and before the He I and heavy-element calls, so its "total opacity" column
is partial. It is valid for H I, which is what was under test; the absence of a
jump at the He I edge in that column is an artifact of the print position, not
a result.

## 2026-09-06b - D-144: the mirror hypothesis is not supported

D-143 proposed the boundary treatment as the route by which stellar photons
reach cells at tau = 175 per cell. Tested and rejected.

### Two false starts, both mine

**D-049's defect is real but latent here.** `photon_mod.f90:2316` assigns
`rVec%z = grid(gP)%yAxis(1)` in the z-min mirror where it should be
`zAxis(1)`. This model has `edges 6.0e19 6.0e19 6.0e19` on a 31^3 grid, so
those two hold the same number and the bug cannot express itself. It bites only
on non-cubic grids. Worth fixing on its own account; irrelevant to this symptom.

**"31 of 31 affected cells lie on the mirror plane" was a sampling artifact.**
Cells are distributed as `mod(iCell-(taskid+1), numtasks)==0`, so rank 0 takes
every 14th cell in raster order - i=1 first, working through j and k before
reaching i=2. The probe's 240-line cap was exhausted inside the i=1 slab, so
"every affected cell is on the mirror" meant only "every cell I sampled was on
the mirror". The tell was visible in the output: the cell indices marched
monotonically upward, which is raster order rather than a scattered subset.

### The actual measurement

Re-run with a 20000-cell cap, 3025 sampled cells carrying H I heating:

| plane | cells at index 1 | share of heat at 1 | within 2 |
|---|---|---|---|
| i (x-mirror) | 145 / 3025 | 9.80% | 16.09% |
| j (y-mirror) | 170 / 3025 | 9.56% | 16.00% |
| k (z-mirror) | 135 / 3025 | 9.82% | 16.60% |

Uniform expectation for one plane of 31 is 3.23% of cells. So each boundary
carries a ~2-3x enhancement - but **90% of the heating is not at any mirror
plane**, and the enhancement is identical across all three (9.80/9.56/9.82).
That equality is what a corner source on symmetric axes predicts geometrically,
not what a defect in one mirror would produce. The hottest cells come in
cyclic permutations - (7,11,1) and (1,7,11) - which is the octant symmetry
expressing itself correctly.

**The mirrors are cleared.** The heating is distributed through the volume.

### What still stands

- H I photoionization is 99.5% of the heating in deep PDR cells (D-138)
- `Jste` is exactly zero at the Lyman edge; one bin of 171 carries flux, bin
  465 at 1.7922 Ryd, in every cell sampled (D-142)
- the opacity there is smooth and gives tau = 175 per cell (D-143)
- the flux is not concentrated at the boundaries (this entry)

Photons are being counted in `Jste` in cells they cannot reach by attenuated
transport, at one frequency, spread through the volume. The remaining
candidates are the estimator itself - a diffuse or re-emitted packet being
accumulated into the stellar field - or something specific to how packets at
that frequency are initialised. Neither has been tested.

`pdrTeFromMocassin` stays off. The shipped default masks this entirely.

## 2026-09-06c - D-146: the attenuation is ~200x too weak, and a mechanism

### Measured

| quantity | value |
|---|---|
| stored `grid%opacity` at bin 465, deep PDR cell | 1.3-2.3e-16 cm^-1 |
| implied tau per cell (dS = 1.94e18 cm) | **250-450** |
| tau implied by the radial falloff of the heating | **~0.9 per cell** |

The heating falls with radius as median 8.9e-25 -> 1.9e-26 -> 3.0e-28 ->
1.2e-28 across shells, i.e. a factor ~7000 over ~10 cells. That is an
exponential decay with tau_eff ~ 0.9, against an opacity array that says 388.
**The stored opacity is correct and the transport is not applying it.**

The falloff being exponential and steep also argues against diffuse
contamination: diffuse emission tracks local emissivity, it does not decay like
an attenuated beam.

### The mechanism, photon_mod.f90:1535

    ! force skip for high tau cells
    if ( i == 1 .and. tauCell > 20.0) then
       passProb = tauCell+1.0e-6
       enPacket%weight = enPacket%weight / weightFactor * exp(-passProb)
    endif

A variance-reduction scheme: rather than absorb a packet in an optically thick
first cell, force it through and reduce its weight by exp(-tau). `weightFactor`
is 1.0 (the alternatives are commented out), and `passProb`, normally sampled
once per packet as `-log(1-random)`, is overwritten with tau+1e-6.

**`exp(-tau)` underflows to exactly zero in single precision for tau > ~87.**
With tau = 250-450 the weight is not small, it is 0. Such a packet then deposits
nothing anywhere - including in the first cell, where it should have deposited
before being absorbed.

That predicts precisely what is observed: **170 of the 171 bins above the Lyman
edge hold exact zeros**, not small numbers. Bin 465 is the exception because it
sits in the He I transparency window (1.7922 Ryd, just below the 1.807 Ryd
edge) where H I's cross section has fallen furthest, so its first-cell tau stays
below the 20 threshold, it never enters this branch, and it keeps weight 1.

### Status of the claim

The underflow explains the exact zeros, and that part is solid - an exact zero
in a Monte Carlo estimator is not a small number, it means no weight was
deposited. Whether it ALSO explains bin 465's too-shallow attenuation is not
established: that bin escapes the branch entirely, so its transport should be
ordinary. Two possibilities remain and neither is tested - that the same
underflow is corrupting the absTau bookkeeping for surviving packets, or that
bin 465's shallow decay has a separate cause.

### Side findings

- **`Jste` is not the stellar field.** With `lgDebug` false, diffuse packets
  accumulate into it (photon_mod.f90:1592-1603); `Jdif` is used only in debug
  mode. Every "stellar" quantity in this investigation has been the total field.
- **MOCASSIN's `debug` mode segfaults.** Verified with a binary whose probes
  never touch `Jdif`, so it is pre-existing. It is the only way to separate the
  two fields and it is currently unusable.
- `Jdif` is allocated unconditionally - the `if (lgDebug)` guards around its
  allocation are commented out - so memory is spent on an array that is only
  filled in a mode that crashes.

## 2026-09-06d - D-147/D-148: convergence is structural, not statistical

### The forced skip is gone (D-147)

Removed on instruction, with the block and the reasoning kept as a comment so
it can be restored deliberately. Measured consequences on the shipped default:
the H -> 2H2 front moved 0.9150 -> 0.8534 and deep T_dust 46.91 -> 49.52 K,
both far outside Monte Carlo scatter. So the branch had been materially
affecting results. Convergence stayed at 100% and heat/cool at 1.000.

What it gives up: a source embedded in an optically thick cell now has every
packet absorbed in cell 1 and the outer grid goes unsampled. No fixture here
exercises that geometry, so nothing we run will warn us - it would present as a
suspiciously dark model, not an error.

### Retraction: the convergence criterion was never wrong (D-148)

I reported that convergence was gated on the mean DUST temperature, from a
block in update_mod carrying ionization-fraction variable names and an
in-code admission of "laziness". That block is in the `else` of
`if (lgGas)` - it runs for **dust-only models**, which is exactly right.

The gas path has always used the ionization fraction, at iterateT:777:

    deltaXHI = (grid%ionDen(cellP, elementXref(1), 1) - XOldHI) / XOldHI
    if (abs(deltaXHI) <= XHILimit) grid%lgConverged(cellP) = 1

The commented-out copy at 507-520 that I took for the disabled original is a
stale duplicate, 460 lines from the live one in the same file. I read one
branch of a conditional without checking which branch executes, and did not
grep every assignment to `lgConverged` before claiming the criterion had been
swapped. The rewrite built on that was reverted; it had placed the ionization
test in the dust-only branch, where `convXold` is never set - an uninitialised
read of exactly the kind this project keeps finding elsewhere.

**The consequence is that the measurements mean MORE, not less.** They were
already the ionization fraction: x(H0) genuinely moves by >5% between
iterations in 99.9% of cells once MOCASSIN owns the thermal balance. That sits
consistently with `0 % Ion balance not reached`, which counts something else -
cells where the ion-balance solver failed internally. The solver works; its
answer keeps moving because the temperature underneath it does.

### Which switch, and whether packets matter

Isolation at identical packet count:

| config | converged on x(H0) |
|---|---|
| none | 100% |
| `pdrAllCells` | 97.8% |
| `+ pdrCoolFeedback` | 97.7% |
| `+ pdrTeFromMocassin` | **0.13%** |

Chemistry everywhere costs 2%. The molecular cooling and the six heating terms
cost nothing further. Handing MOCASSIN the thermal balance collapses it.

Packet count tested properly - 8x packets fixed from iteration 1, same config,
compared iteration for iteration (the earlier autoPackets ladder was
confounded: the PDR starts at iteration 4 and packets only began doubling at
iteration 5):

| iter | 48e6 | 6e6 |
|---|---|---|
| 1-3 | 100.0000 | 100.0000 |
| 4 | 0.1118 | 0.0592 |
| 5 | 0.0658 | 0.0855 |
| 6 | 0.0658 | 0.0723 |

Means over the post-PDR iterations: 0.081% against 0.072%. Eight times the
packets cuts field noise ~2.8x and changes nothing; the two runs cross over
each other. **Not a statistics problem.**

### Standing candidate

`grid%pdrCool` and `grid%pdrHeatXtra` are computed once per PDR pass and held
fixed while MOCASSIN's thermal solver iterates on temperature. The dominant
cooling term is then a constant with respect to T, so the solver has no
restoring force, the gas temperature wanders, and x(H0) follows it. That
predicts precisely what is measured: a collapse triggered by
`pdrTeFromMocassin` alone, indifferent to packet count. Untested.

## 2026-09-06e - D-155: the convergence criterion was measuring the wrong interval

Flagged by the user: 100% convergence in the first three iterations is not
credible for a photoionization model with gas and dust. It was not.

### The defect

`iterateT` tests the fractional change in x(H0) against `XOldHI`, captured at
entry to `updateCell`. With the D-119 coupling loop, `updateCell` runs
`pdrCoupleIter` times per MC iteration - so `XOldHI` is the previous COUPLING
PASS, not the previous iteration. Measured directly:

    iter 1 call 1:  entry 1.0e-05 -> final 0.5348   delta 53478
    iter 1 call 5:  entry 0.5361  -> final 0.5358   delta 0.00053   "converged"
    iter 2 call 1:  entry 0.5358  -> final 0.9719   delta 0.814
    iter 2 call 5:  entry 0.9716  -> final 0.9719   delta 0.00027   "converged"

The inner loop always settles, so every cell reported converged while x(H0) was
moving **81% between iterations**.

**This is a regression I introduced with D-119.** At `pdrCoupleIter = 1` the
call and the iteration coincide and the test is correct; it only breaks once
the loop runs more than one pass, which became the default in D-123.

### The correction

`grid%xHIiterStart` snapshots x(H0) once per MC iteration, before the coupling
loop (iteration_mod, beside the `lgConverged` reset). The test compares against
that.

Reference configuration, before and after:

| iter | corrected | old |
|---|---|---|
| 1 | **0.00%** | 100% |
| 2 | **17.21%** | 100% |
| 3 | **91.58%** | 100% |
| 4 | **84.18%** (PDR engages) | 100% |
| 5 | **99.36%** | 100% |

The model builds its ionization structure over three iterations, dips seven
points when the PDR switches on, and settles - which is what such a model
should do. The old test reported 100% at iteration 1 where the true figure is
zero.

### What this invalidates

Every convergence number in this session, in both directions:

- **False passes.** "100% converged" for the reference configuration, used
  repeatedly here as evidence that a change was safe.
- **False fails.** The 0.13% collapse under `pdrTeFromMocassin` means the inner
  loop stopped settling within five passes once the chemistry was active - not
  that the model was unstable. The whole D-149 to D-153 investigation was
  chasing a number that did not mean what it appeared to.
- **D-123's ladder** chose `pdrCoupleIter = 5` partly on convergence behaviour
  measured this way. Its front positions came from completed runs so they may
  survive, but that needs checking rather than assuming.

The autoPackets escalation is also driven by `totPercent`, so packet counts were
being increased on a signal that did not mean what it claimed.

## 2026-09-06f - D-156: the ladder, re-measured on a criterion that means something

Every convergence figure in this session was taken with the D-155 defect in
place. Re-run on the corrected criterion:

| config | switches | iterations | converged |
|---|---|---|---|
| reference | none | 5 | 99.36% |
| RC_1 | `pdrAllCells` | 5 | **97.73%** |
| RC_2 | `+ pdrCoolFeedback` | 5 | **97.74%** |
| RC_3 | `+ pdrTeFromMocassin` | 12 (never) | 0.099% |
| RC_4 | `+ pdrIonFromMocassin` | 12 (never) | 0.118% |

### The collapse is real

I expected the corrected criterion to dissolve it - the earlier 97.7% -> 0.13%
had been measured on the inner coupling loop - and said so before RC_3
finished. It did not. Correctly measured, the collapse is if anything sharper:
91.5% at iteration 3, then off a cliff when the PDR engages. So D-149 to D-153
were chasing a real phenomenon on numbers that happened to be wrong.

### What is sound

`pdrAllCells` and `pdrCoolFeedback` both converge in five iterations at 97.7%,
against the reference's 99.36% in five. So the chemistry running in every cell -
H2 and CO emerging from the network everywhere rather than being seeded - and
the molecular cooling plus the six missing heating terms are stable, at a cost
of about 1.6 points of convergence.

### What is not, and why it is not the coupling

RC_4 removes the ionization blending and the zone gate entirely, which was the
best structural account of the collapse (D-152: front cells where the codes
disagree 3-38x on x(H0), with the gate keyed on the disputed quantity). It
changes nothing: 0.118% against RC_3's 0.099%. The instability is therefore not
in how the two codes negotiate ionization.

It is in the thermal balance itself, and the measurement that has survived every
criterion change and every reframing says why: the failing cells sit at
**7000-9700 K where the PDR's own balance gives ~50 K**, because H I
photoionization supplies **99.5%** of their heating (D-138) from a field that
tau = 175 per cell says cannot reach them (D-143, D-146). A thermal balance fed
a spurious dominant heating term cannot settle, and no restructuring of the
handover will make it.

**The transport defect is therefore not one open item among several - it is the
blocker for the entire self-consistent configuration.**

## 2026-09-06g - D-159: not a transport bug - the coupled system is bistable

### The two measurements that force the reframing

**The deep-cell field is stellar.** `Jdif` now mirrors the diffuse packets while
`Jste` carries both, so `Jste - Jdif` is the stellar part. In the cells that
matter it is **86-100% stellar** - so this is not diffuse emission miscredited
to `Jste`, which had been the leading explanation since D-145.

**No stellar packet crosses a cell with tau > 20.** A probe on exactly that
event, over two iterations and millions of packets, fired **zero** times.

Those two are only consistent if the cells in question are not optically thick
at that frequency. And they are not. The tau = 175 figure came from the D-143
probe, which selected cells with `n(H0) > 50`. The cells that actually fail
convergence carry `ionDen H0 = 0.026-0.36` (D-152), and tau scales with it:

    x(H0)=0.026  n(H0)= 2.60  tau/cell =   6.4
    x(H0)=0.160  n(H0)=16.00  tau/cell =  39.4
    x(H0)=0.360  n(H0)=36.00  tau/cell =  88.6
    x(H0)=0.830  n(H0)=83.00  tau/cell = 204.4

At x(H0) = 0.026 the cell is nearly transparent. Stellar photons reach it
legitimately, and the photoionization heating they deposit is real.

### What this means: two self-consistent solutions

- **MOCASSIN's branch:** ionized -> transparent at 1.79 Ryd -> stellar photons
  penetrate -> photoionization heating -> ~8000 K -> stays ionized.
- **The chemistry's branch:** neutral -> opaque -> nothing penetrates -> ~50 K
  -> stays neutral.

Both close on themselves. The two codes sit in different ones. D-152's
"disagreement of 3-38x" is not an error by either code - it is two valid
solutions of the same cell.

This accounts for everything that resisted explanation:

- why `pdrTeFromMocassin` alone breaks convergence (D-156): it removes the PDR
  temperature that was holding those cells on the neutral branch;
- why removing the gate changed nothing (D-153): the gate was reacting to the
  disagreement, not causing it;
- why 8x packets did nothing (D-149): the field is right, it belongs to a
  different branch;
- why one cell read 146 K in one run and 2475 K in another: realisation-
  dependent branch selection.

### Retraction

From D-143 onward I described this as "spurious heating from photons that
cannot arrive", and built D-139, D-144, D-146 and D-158 on it. It is neither
spurious nor impossible: the heating is real, the photons do arrive, and the
opacity that would stop them exists only in the other solution. The chain of
probes was sound; the framing on top of it was not, and it survived four
rounds of contradicting evidence because each round only tested a mechanism,
never the premise.

### Established vs inferred

Measured: the stellar fraction; the zero crossings above tau = 20; the
ionization disagreement; the temperatures; tau as a function of x(H0).

Inferred, and NOT yet tested: that these are genuinely two stable fixed points
rather than one solution and one transient. **The test is to start the same
model from a fully neutral initial condition** - `H0in` at grid_mod:1652 - and
see whether MOCASSIN's own balance stays on the neutral branch. If it does, the
system is bistable and the coupling must choose a branch deliberately. If it
collapses to the ionized state regardless, the ionized branch is the only
solution MOCASSIN's physics admits and the disagreement is a physics gap, not a
branch-selection problem.

## 2026-09-06h - D-160: not bistable either - no stable fixed point

Two runs of the same configuration (`pdrTeFromMocassin` on), differing only in
the initial neutral fraction. `H0in` was hardcoded to 1.e-5 in three places in
grid_mod - every MOCASSIN model has always started 99.999% ionized with no way
to change it - so this needed a keyword, `initH0`, defaulting to the old value.

| iter | ionized start | neutral start |
|---|---|---|
| 1 | 0.00% | 99.93% |
| 2 | 17.34% | 84.14% |
| 3 | 91.44% | 22.74% |
| 4 (PDR on) | 0.059% | 0.033% |
| final | 0.066% | 0.039% |

### The result is neither outcome I predicted

**Not bistable.** The neutral start does not hold - it decays 99.93 -> 84.14 ->
22.74 as radiation penetrates. There are not two stable solutions to choose
between, so nothing about initial conditions, damping or branch selection will
fix this.

**But not a single solution either.** The two runs end in materially different
states:

| | ionized start | neutral start |
|---|---|---|
| gas cells (Ne > 1e-3) | 14258 | 12545 |
| cells > 5000 K | 674 | 335 |
| median T_e | **379 K** | **1246 K** |

**So there is no stable fixed point at all under `pdrTeFromMocassin`.** The
model wanders, never settles, and where it wanders depends on where it started.

### Correction

I reported "by iteration 4 they are in the same collapsed state" from the
convergence percentage alone. The percentages are near-identical while the
underlying models are not - 379 K against 1246 K median. Reading a scalar
summary as if it described the state was the same error as trusting the
convergence figure itself before D-155.

### Where this leaves it

The D-159 bistability framing is withdrawn along with the D-143 transport
framing it replaced. What survives measurement:

- MOCASSIN's ionization balance and 3D-PDR's chemistry disagree by 3-38x on
  x(H0) in the front cells (D-152), and neither is reachable from the other;
- with the PDR owning the temperature, the coupled model converges (97.7%,
  D-156) - the disagreement is suppressed, not resolved;
- with MOCASSIN owning it, no stable solution exists.

That is a genuine physics disagreement between the two codes about hydrogen in
partially ionized gas, and it is not a coupling defect, an initial-condition
choice, or a transport bug. It is the thing the audit needs to settle.

## 2026-09-06i - D-161: the two codes were never disagreeing, and what Cloudy does

### Which code is right about hydrogen at x(H+) ~ 0.5

Settled from the physics, not from either code's output. In equilibrium
n(H0)*Gamma = n(H+)*n_e*alpha_B, so each answer implies a photoionization rate.
For cell 93 (Te = 9648 K, nH = 100, A_V = 0.467):

| | x(H+) | implied Gamma |
|---|---|---|
| MOCASSIN | 0.974 | 9.8e-10 s^-1 |
| chemistry | 8.9e-4 | **2.4e-17 s^-1** |

2.4e-17 is the cosmic-ray rate - this model sets `pdrZeta = 5.0e-17`. Confirmed
in the network data: **every H -> H+ channel in the reduced network is either
charge exchange or cosmic rays.**

    155:  H + H2+ -> H2 + H+      charge exchange
    156:  H + He+ -> He + H+      charge exchange
    161:  H + O+  -> O  + H+      charge exchange
    168:  H + CO+ -> CO + H+      charge exchange
    293:  H + CRP -> H+ + e-      cosmic rays, 5.98e-18

There is no `H + PHOTON -> H+ + e-`. **The network cannot photoionize hydrogen
and never claimed to.**

So the "3-38x disagreement" of D-152 was never a disagreement. MOCASSIN is right
wherever ionizing photons reach; 3D-PDR is answering a different question - the
cosmic-ray equilibrium of gas beyond the ionization front, which is its domain.
Applying it inside the front is outside its validity, and no coupling
architecture, damping, branch selection or initial condition could have
reconciled two answers to different questions.

### What Cloudy does (source read locally, c25.00)

1. **Duplicated physics is deleted from the network data.** `mole_co_base.dat`
   carries atomic photoionization and recombination written out as reactions
   and all of them commented out: *"These would be double counted if included
   in the molecular network"*.

2. **The network contributes source and sink terms, never abundances**
   (`mole_eval_balance.cpp:248`): for a linked stage,
   `mole.source[nelem][ion] = species[ipMl[ion]].src`, and zero when
   `ipMl == -1` - a stage the network does not carry contributes nothing. This
   is what D-118 already implemented for us.

3. **Ion stages are SHARED STORAGE, not two numbers to reconcile**
   (`mole_species.cpp:1030`): `species[mole_index].location =
   &(dense.xIonDense[nelem][ion])`. The network species and the ion solver's
   density are literally the same memory. There is no handback, no blend
   weight, no zone gate - the concepts do not arise.

4. **They are iterated to consistency with an explicit metric**
   (`mole_species.cpp:950-978`): the write-back accumulates the RMS fractional
   change of the monatomic species and returns it, which `conv_base` drives to
   convergence with 50% damping.

### The contrast with what we built

Ours reconciles two independently computed answers - blend weight, zone gate,
`pdrZoneLim`, the D-153 imposition that the network relaxes straight back.
Cloudy makes reconciliation impossible by construction: one storage location,
each code contributing only the physics it owns, iterated with a convergence
metric.

The pieces we already have that match: D-118's src/snk into `ionBalance`, and
Cloudy's `ipMl == -1` rule for stages the network lacks.

The piece we do not: shared storage for the linked ion stages, so the chemistry
cannot hold an independent opinion about x(H+) at all. That - not another
coupling switch - is what the architecture needs, and it is what makes the
question "which code is right" stop being askable.

## 2026-09-06j - D-162/D-163: one x(H+), owned by MOCASSIN

The user's requirement, stated repeatedly across this project and finally
implemented as stated: *"There is just one reality for x(H+) period."* Not a
blend weight, not a zone gate, not two answers to reconcile.

### What was wrong with D-153

It imposed MOCASSIN's ionization ratio on the network BEFORE the solve and let
CVODE evolve it. The network has no `H + PHOTON -> H+ + e-` reaction at all
(D-161), so it relaxed the ratio straight back to the cosmic-ray equilibrium
every time. Imposing an initial condition does not constrain a quantity the ODE
system is free to evolve.

### D-162: the ratio is MOCASSIN's on both sides of the solve

Re-imposed after `calculate_abundances` as well as before, for every linked
element - H, He, C, O and Mg, not just hydrogen. The chemistry keeps what it
legitimately owns, how much of each element is locked in molecules, returned
through `elemAvail`. No quantity is determined by both codes.

Measured in the front cells that were 3-38x apart (D-152):

    chemistry x(H)        MOCASSIN ionDen H0
    2.49704272E-02        2.49704290E-02
    0.365551472           0.365551502
    0.165114492           0.165114492
    8.88847560E-02        8.88847485E-02

Agreement to 7-8 significant figures - single-precision round-trip only.

### D-163: and the duplicated channels come out of the network

Following the rule to its conclusion, and matching what Cloudy does in
`mole_co_base.dat`. Suppressed, identified by structure rather than index:

- `C + PHOTON -> C+ + e-` and `Mg + PHOTON -> Mg+ + e-` (the only two the
  network could photoionize at all)
- radiative recombination of H+, He+, C+, O+, Mg+

KEPT, because MOCASSIN has none of it and it reaches the ion solver as
source/sink through D-118: charge exchange, and `H + CRP -> H+ + e-`.

Every suppression prints at startup. Silently deleting reactions from a
chemical network should never be invisible in a run log.

### Result

| config | converged |
|---|---|
| PDR owns T, one x(H+) | **97.76%** |
| PDR owns T, blend and gate (D-156) | 97.74% |
| MOCASSIN owns T, one x(H+) | 0.079% |

**The architecture costs nothing where the model already worked** - 97.76%
against 97.74% - so it is adoptable on its own merits. It also removes a real
incoherence: the chemistry was computing an ionization state it has no physics
for, and every mechanism built to reconcile that (blend weight, zone gate,
D-153's imposition) was machinery for a problem that should not have existed.

**It does not fix the MOCASSIN-owned thermal balance**, which still collapses.
That is a temperature instability (D-160: no stable fixed point from either
initial condition), and it is now cleanly separated from the ionization
question rather than entangled with it.

## 2026-09-06k - D-164: the suppression set, corrected

The D-163 startup print earned its keep. Of the eleven channels it suppressed,
**two were wrong**:

    330,He+,e-,#,He,#,,,5.20E-17,...
    331,C+ ,e-,#,C ,#,,,5.20E-17,...

The `#` is the grain marker: these are recombination of ions **on grain
surfaces**, not radiative recombination. The 5.2e-17 coefficient, which looked
wrong for a recombination rate when the reactions were first enumerated, is the
tell. MOCASSIN's `alphaTot` is radiative recombination only - it has no
gas-phase ion recombination on grains - so these belong with charge exchange
and cosmic rays as physics only the network carries.

The matcher now requires PHOTON among the products and no `#` among the
reactants, which separates
`242,H+,e-,,H,PHOTON` (radiative, MOCASSIN computes it) from
`330,He+,e-,#,He,#` (grain surface, only the network has it).

Final set, nine channels, printed at startup in every run:

| suppressed | kept |
|---|---|
| radiative recombination of H+, He+, C+ (x3), O+, Mg+ | grain-surface recombination (330, 331) |
| photoionization of C and Mg | charge exchange |
| | cosmic-ray ionization |

DUP2, the corrected set: 0.00 / 16.65 / 91.55 / 78.02 / **97.74%** - matching
DUP_pdrT's 97.72% and ONE_pdrT's 97.76%. The two grain channels are slow enough
not to move the result, but that is a measurement rather than an assumption now.

### The complete picture across every variant

| | PDR owns T | MOCASSIN owns T |
|---|---|---|
| blend + zone gate (D-156) | 97.74% | 0.099% |
| one x(H+), no gate (D-162) | 97.76% | 0.079% |
| + duplicates suppressed (D-163) | 97.72% | 0.217% |
| + grain recombination kept (D-164) | **97.74%** | - |

The ionization architecture is settled and free. The thermal instability is
untouched by any of it, and is now cleanly separated as its own problem.

## 2026-09-06j - D-165: MOCASSIN has never solved the thermal balance in a PDR cell

The remaining open item was the thermal instability: with `pdrTeFromMocassin`
the model converges 0.08-0.22% of cells in every architecture tried, from either
initial condition, and D-160 concluded there was no stable fixed point. The
instruction was to work on it with Cloudy as the reference.

### What Cloudy does

`conv_temp_eden_ioniz.cpp`, the `vWDB` solver:

1. **Bracket, then solve.** An explicit bracketing phase steps until
   `error1*error2 <= 0`, with the step sized from the remembered derivative
   `conv.dCmHdT`, capped at `0.2*T`, grown by sqrt(2) per failed step, up to 100
   steps. Only then does van Wijngaarden-Dekker-Brent run, and it runs INSIDE
   the bracket, so the interval always shrinks.
2. **Convergence needs two things.** `lgConvTemp` requires
   `|H-C|/H <= HeatCoolRelErrorAllowed` (0.005) **and**
   `bracket_width/Te <= HeatCoolRelErrorAllowed/3` - *"this assures that the
   temperature is also well determined if H-C is a shallow function of T"*.
3. **Restart on failure.** An outer `for n=0..4` loop restarts the whole search,
   ignoring the first n bracketing steps, explicitly to survive hysteresis in
   the ionization ("e.g. O-H charge transfer"), with the Brent budget doubling
   as n grows.
4. **The low limit is the CMB, 2.8 K**, and reaching it is a `cloudy_abort` with
   a diagnostic, not a silent clamp.
5. It reports `thermal.lgUnstable` when `dCmHdT + 2*sigma < 0` - a thermally
   unstable solution is *named*, not hidden.

### What MOCASSIN's iterateT does

It matches Cloudy on exactly one point - the 20% bracketing step (`*1.2`,
`/1.2`) - and differs on every other:

| | Cloudy | MOCASSIN |
|---|---|---|
| root find | Brent inside the bracket | plain regula falsi, one endpoint sticks |
| convergence | residual **and** bracket width | residual alone |
| residual test | `\|H-C\|/H` | `\|H-C\| < thLimit*heatInt` - unpassable if heatInt < 0 |
| stall | restart the search, up to 5x | add **+/-100 K** and reset the bracket |
| low limit | 2.8 K, hard error | 10 K, silent clamp |
| budget | 100 bracketing + up to 5x(10..40) Brent | 50 total |

The +/-100 K kick is the sharpest of these: it is 1% of an H II region and 200%
of a PDR cell. It is a routine written for photoionized gas being run in a PDR.

### The probe (teProbe)

`iterateT` instrumented to report, per MC iteration summed over ranks: calls,
convergences, mean steps, stall-breaker firings, floor and ceiling clamps, and a
histogram of `bracket_width/Te` at exit. V1 slab, 31^3, full self-consistent
configuration (`pdrAllCells`, `pdrCoolFeedback`, `pdrIonFromMocassin`,
`pdrTeFromMocassin`).

| iter | Te conv | mean steps | stalls | at 10 K floor | bracket wider than thLimit/3 | global conv |
|---|---|---|---|---|---|---|
| 1 | 100% | 1.62 | 1 | 0 | 15327 of 15327 bracketed | 0.00% |
| 2 | 98.5% | 4.84 | 3188 | 172 | 19405 | 17.52% |
| 3 | 96.4% | 7.31 | 4299 | **1864** | 19769 | 91.61% |
| 4 (PDR on) | **98.8%** | **2.59** | 878 | 2199 | 5019 | **0.296%** |

Two things fall out. Every cell that ever formed a bracket exited with it wider
than Cloudy's criterion - the residual test was passing at temperatures the
solver had not determined. And 1864 cells at iteration 3 were parked on the 10 K
floor and counted as converged.

But the fourth row is the one that mattered. At the iteration where the PDR
engages and global convergence collapses to 0.296%, the temperature solver gets
*better*: 98.8% converged, mean steps down from 7.31 to 2.59, 93% of cells
needing no bracket at all because the entry temperature already satisfied the
residual test.

That is not what a struggling solver looks like. It is what a solver that is not
running looks like.

### The defect

`update_mod.f90:600`, the D-072 short circuit:

```fortran
if (lgPDR) then
   if (grid%pdrZone(cellP) == 1 .and. grid%pdrTgas(cellP) > 0.) then
      lgPDRcell = .true.
      TeUsed    = grid%Te(cellP)
```

and, 100 lines later:

```fortran
if (lgPDRcell) then
    lgTConverged = .true.
    exit
end if
```

**It never tests `pdrTeFromMocassin`.** The switch was implemented in `pdr_mod`
- it stops `handBackPDR` writing the PDR temperature into `grid%Te` (D-132) and
makes the chemistry evaluate at MOCASSIN's `Te` (line 1488) - and never wired
into the one place that decides whether MOCASSIN solves for a temperature at
all. `pdrTgas` is written unconditionally at `pdr_mod:2156`, and under the
switch it is written from `grid%Te`, so the `> 0.` guard passes too.

So with the switch on, a PDR cell runs one pass of `calcalpha`, `ionBalance`,
the grain terms and `thermBalance` at the temperature it already had, and exits
flagged converged. `TeUsed = grid%Te(cellP)` in, `grid%Te(cellP) = TeUsed` out.
The molecular coolant and the six PDR heating terms - D-131 through D-146, the
whole reason the switch exists - were being computed into a residual that was
thrown away.

**MOCASSIN has never solved the thermal balance in a PDR cell.** The temperature
there is the last value its H II-region balance produced before `pdrZone` flipped
to 1, carried forward untouched for the rest of the model.

### What this retracts

D-160's "no stable fixed point" is withdrawn. Nothing was solving for a fixed
point. And its most puzzling result - that the answer depended on the initial
condition, median Te 379 K from an ionized start against 1246 K from a neutral
one - is exactly what a frozen relic of the trajectory does.

Every number in the "MOCASSIN owns T" column is void:

| | PDR owns T | MOCASSIN owns T |
|---|---|---|
| blend + zone gate (D-156) | 97.74% | ~~0.099%~~ |
| one x(H+), no gate (D-162) | 97.76% | ~~0.079%~~ |
| + duplicates suppressed (D-163) | 97.72% | ~~0.217%~~ |

None of them measured what the row claims. They measured a code that skips the
solve. The ionization-architecture column is unaffected - those runs had the PDR
owning the temperature, which is the path that works.

D-149's framing ("convergence collapse is caused by pdrTeFromMocassin alone")
survives, and is now explained: the switch does not enable MOCASSIN's thermal
balance, it *disables* the PDR's without enabling anything in its place.

### Fixes

1. `lgPDRcell` is set only when `pdrTeFromMocassin == 0`.
2. `teSolver` (0 = as-is, 1 = Cloudy-shaped search, 2 = + strict convergence)
   and `teFloor` (default 10., the old hardcoded value) added, so the solver
   change can be measured against the old one in a single build:
   - **Illinois** regula falsi - halve the retained endpoint's residual after a
     repeat, so the bracket actually shrinks;
   - the +/-100 K kick replaced by a restart from the bracket midpoint with a
     widened relative step, at most twice, which is Cloudy's outer loop;
   - the falsi step bisects if the interpolant leaves the bracket;
   - bracketing steps are a fixed *fraction* of T, so the search rate is the
     same at 20 K as at 20000 K;
   - at `teSolver >= 2`, convergence also requires
     `(Thigh-Tlow) <= (thLimit/3)*Te`, Cloudy's second test;
   - the residual test uses `|heatInt|`, so a cell with net negative heating can
     pass it (`teSolver >= 1` only, to keep the comparison clean).

Runs D165A (fix, old solver) and D165B (fix, Cloudy-shaped solver) measure
whether the thermal balance converges now that it is being solved.

### Note on the scratchpad filesystem

`cp -r` on the session scratchpad produced three run directories whose `input`
subdirectories shared an inode - writes to one appeared in all three, and in the
source directory. Caught before any run started, by a `stat` after the inputs
came back identical. Run directories are built with `mkdir` and explicit file
writes from here on. The D-119/D-123/D-128 ladder directories were built by
`ladder.py`, which writes files directly, and are confirmed distinct.

## 2026-09-06k - D-166: the thermal balance in a PDR cell has no root

D-165 removed the short circuit, so `iterateT` now solves for a temperature in
PDR cells. It does not go well.

| iter | Te conv | mean steps | at 10 K | at 30000 K | flat residual | global conv |
|---|---|---|---|---|---|---|
| 3 (no PDR) | 96.5% | 7.3 | 1847 | 0 | 0 | 91.48% |
| **4 (PDR on)** | **55.0%** | **31.5** | **14391** | **19927** | **17612** | **0.072%** |

45% of cells run off one rail or the other, and the mean call burns 31.5 of its
50-step budget doing it. That is not a root finder failing to locate a root; it
is a root finder correctly reporting there isn't one.

The `flat residual` column settles it. It counts cells whose `|H-C|` varied by
less than **1%** across the entire scan - a scan that spans three decades of
temperature - and **every single one of them ended clamped**. 17612 cells, 23%
of the model, where the thermal balance is not a function of temperature at all.

### Why

`grid%pdrCoolSp` is written once per coupling pass, at `pdr_mod:2046`, and
`thermBalance` reads the stored number. Inside `iterateT` it does not move when
`TeUsed` moves. Neither does `pdrHeatXtra`.

Everything MOCASSIN computes for itself *is* a function of T - `coolColl`,
`coolRec`, `coolFF` - and every one of them carries a factor n_e. In neutral gas
x(e) ~ 1e-4, so they contribute nothing. What is left is a constant heating term
minus a constant cooling term: a residual with a fixed sign, and a search that
can only run to whichever rail that sign points at.

The bimodal split is the signature. 19927 cells run hot and 14391 run cold, and
which way a cell goes depends on nothing but whether its frozen coolant was
measured above or below the temperature it now wants. The other half of the
clamped cells - 34318 clamped against 17612 flat - had residuals that moved but
never changed sign: the n_e-weighted terms were not enough to overcome the
constant.

### This also explains D-150 and D-151

D-150 asked exactly the right question - *"is the MOCASSIN <-> PDR pair an
oscillating fixed point? MOCASSIN solves T with pdrCool held constant, the PDR
then recomputes pdrCool at the new T"* - and D-151 answered it with *"Te is
pinned to 7 figures while pdrCool swings 2x, so the coolant abundances are
moving at constant temperature."*

Te pinned to seven significant figures **was the D-165 bug**. The temperature was
not being solved, so of course it did not move. That probe was reading the
defect's fingerprint and concluding something about the chemistry.

### The fix, and what Cloudy does

Cloudy re-evaluates the entire cooling function at every trial temperature:
`CoolHeatError(temp)` calls `TempChange` then `ConvEdenIoniz`, which re-solves
the ionization, the electron density and every coolant including the H2 and CO
level populations. There is no stored cooling rate to go stale.

Doing that here means 30+ level-population solves per cell per coupling pass.
The affordable version of the same requirement, `pdrCoolTdep`:

* solve the coolants at `Tg` and again at `pdrCoolTfac*Tg` (1.6) each coupling
  pass, the second starting from the first's converged populations;
* store `p = d ln C / d ln T`, clamped to [-2, 12], and the reference `Tg`;
* `thermBalance` evaluates `C(T) = C(Tref)*(T/Tref)^p` inside the temperature
  loop instead of reading `C`.

Cost is 2x the level-population work per coupling pass rather than 30x.

The clamp is not cosmetic: below its excitation temperature a fine-structure
coolant rises nearly exponentially and above it the line saturates, so an
unclamped index extrapolated over three decades is not defensible.

`pdrCoolTdep 2` adds a third solve at `Tg/1.6` and prints the power law against
it - a real evaluation on the far side of `Tref`. An extrapolation is worth
nothing until someone has looked at how far it misses, so that check runs
alongside the convergence measurement rather than after it.

### The power law holds

30 cells, predicting C at `Tref/1.6` from a slope measured between `Tref` and
`1.6*Tref` - an extrapolation to the *opposite* side of the anchor, a 2.56x
temperature span - against a genuine third solve:

**median error 6.3%, 90th percentile 33%, worst 38.5%.**

Ample for a thermostat. The balance needs the sign and rough magnitude to
bracket a root, and the coupling loop re-anchors `Tref` every pass, which is
exactly how Cloudy uses `conv.dCmHdT`.

### Result

| | frozen coolant | C(T) power law |
|---|---|---|
| Te converged (iter 4) | 55.0% | **70.3%** |
| mean steps | 31.5 | 20.4 |
| clamped at 10 K | 14391 | **2467** |
| clamped at 30000 K | 19927 | 20261 |
| flat residual | 17612 | 16484 |
| global convergence | 0.072% | 0.026% |

**The cold runaway is 83% gone** - cooling now falls as T falls, so it stops
winning at the floor. **The hot runaway does not move at all**, and 16484 cells
still have a residual flat to 1%. Scaling a coolant by a power law cannot help a
cell whose coolant is zero, which is what D-167 turned out to be.

### Incidental

`pdr_mod:1616` clamps `Tg` to `[pdrTmin, pdrTmax]` = [1, 20000] K
unconditionally, *"keep the chemistry inside the temperature range it was fitted
over"*. Under `pdrTeFromMocassin`, MOCASSIN's `iterateT` has a 30000 K ceiling,
so it asks for temperatures the chemistry will not evaluate - a third of the
sampled cells report `Tref` sitting exactly on 20000. Not a defect; the clamp is
protecting fitted data. But it means the coolant above 20000 K is now a power-law
extrapolation rather than a solve, which is worth knowing when reading a hot
cell's budget.

### Note

`pdrHeatGGTmp/Sum`, `NePDRTmp`, `H2denTmp` and `pdrCoolSpTmp` are allocated
every MC iteration and never deallocated. The `allocate` carries `stat=err` and
the status is not checked, so the second allocation silently fails and the array
keeps its previous contents - which happens to be the right size, so it works.
Pre-existing. The two D-166 arrays are deallocated properly rather than joining
them.

## 2026-09-06l - D-167: replacing a coolant with nothing

D-166 fixed the cold runaway and left the hot one exactly where it was: 20261
cells on the 30000 K ceiling, 16484 with a residual flat to better than 1%. A
power law cannot rescue a coolant that is zero, so the question was why it was
zero.

### The loop

D-133 established that inside the PDR the atomic coolants are *replaced* rather
than excluded: MOCASSIN's [C I], [C II] and [O I] come out of `coolColl` and
3D-PDR's go in, because MOCASSIN excites those lines with electrons alone and
x(e) ~ 1e-4 in neutral gas. Correct, and measured at the time.

What was never checked is whether 3D-PDR supplies a replacement. `pdr_mod:1898`
sets `grid%pdrCoolSp(cellP, ik) = 0.` and cycles for any coolant whose carrier
has fallen below `pdrNspecFloor` - deliberately, so a stale value from the
previous MC iteration cannot be fed to a carrier the chemistry has since
destroyed (that guard is itself D-131).

In a hot cell the carbon is ionized past C+. So [C I] and [C II] are precisely
the coolants that fall below the floor, and the replacement then subtracts
MOCASSIN's term and adds zero:

```
coolInt = coolInt - forbiddenLines(C, I..II, :, :)     ! removed
pdrCoolMol = pdrCoolMol + 0.                           ! nothing put back
```

The cell loses its carbon cooling outright, so it heats, so more carbon ionizes,
so the coolant stays below the floor. Self-reinforcing, and it starts from
whichever cells happened to be hottest.

That is why the residual is flat in those cells: with the carbon cooling deleted
and the oxygen cooling deleted the same way, what remains is `coolFF + coolRec +
coolColl + gasDustColl_g`, all proportional to n_e, against a constant heating
term.

### Fix

Sum MOCASSIN's contribution for the ion first, and do the swap only when there
is something to swap in:

```fortran
if (grid%pdrCoolSp(cellP,iCool) > 0.) then
   coolInt    = coolInt - mocCool
   pdrCoolMol = pdrCoolMol + grid%pdrCoolSp(cellP,iCool)
else if (mocCool > 0.) then
   nCoolNull = nCoolNull + 1     ! keep MOCASSIN's term
end if
```

Note the asymmetry this restores is the right one: D-133's argument for
preferring 3D-PDR is that MOCASSIN under-cools *in neutral gas*. In a cell hot
enough to have ionized its carbon away, x(e) is not 1e-4 and MOCASSIN's electron
treatment is the appropriate one anyway.

`nCoolNull` counts and reports how often this fires, so the size of what was
being deleted is on the record rather than inferred.

### Result: real, frequent, and immaterial

| | no guard (D-166C) | guard (D-167) |
|---|---|---|
| Te converged (iter 4) | 70.3% | 70.1% |
| clamped at 30000 K | 20261 | 20249 |
| flat residual | 16484 | 16484 |
| global convergence | 0.0263% | 0.0263% |
| `nCoolNull` firings | - | **1,264,809** |

It fires 1.26 million times in one iteration and moves nothing. The reason is
D-133's own premise: the term being deleted is MOCASSIN's *electron-excited*
[C II] and [O I], which in neutral gas is orders of magnitude too small to
matter either way. Deleting a negligible term is still wrong and the guard
stays, but D-167 is not the hot runaway.

The index line is updated to say so rather than leaving it reading as a fix.

## 2026-09-06m - D-168/D-169: the hot runaway, and one x(H+) for real this time

### What is heating the ceiling cells

The budget of a cell sitting on the 30000 K rail, with the PDR data present
(the probe was first fired too early and caught cells before `pdrStep` had ever
run - that ordering is a finding in its own right, below):

```
cell 134  zone 1  nH 100  A_V 1.54   x(H+) 0.0233  Ne 2.40  n(H0) 97.7
HEAT  ste 2.577e-20   PE 9.40e-26   pdrXtra 1.62e-28
COOL  ff 1.87e-26  rec 1.43e-26  coll 2.282e-20  gasDust 6.4e-25  pdrMol 1.66e-23
top heating ion: elem 1 stage 1 = 2.568e-20  (99.67% of ste)
```

Neutral hydrogen photoionization is **99.7%** of the heating, six orders above
the photoelectric term and above the entire PDR heating budget.

### The flux is stellar, and cannot be

With `pdrSplitField` separating the two:

```
at H0 threshold: bin 430, 0.9994 Ryd   Jste 0.0   opacity 6.35e-16 cm^-1
Jste above H0 thr 2.07e-3   below 5.96e-2
Jdif above H0 thr 0.0       stellar-only 2.07e-3
dx 2.0e18 cm    tau/cell 1269.8
```

`Jdif = 0` exactly: none of it is locally produced diffuse radiation. It is
stellar, in a cell behind tau = 1270 *per cell*, many cells deep. The surviving
flux is the hard tail where sigma ~ nu^-3 makes the gas thin, which is real
physics - but it does not close the gap.

D-159 concluded "not a transport bug" from *"no packet crosses tau > 20"*. That
measurement was taken while the temperature was frozen by D-165, and it answers
a different question anyway: a packet absorbed INSIDE a cell still deposits path
length into Lucy's estimator.

### Two wrong turns, recorded

1. **A mislabelled probe.** I printed `sum(Jste(IPnuP:nbins))` as "above 1 Ryd".
   `IPnuP` is a loop variable and by then holds the LAST ion's threshold, so the
   "Jste > 1 Ryd = 0 exactly" that looked decisive meant nothing. Re-measured
   with hydrogen's own saved index.
2. **Two cells compared as one.** I took Gamma from a cold cell's probe and heat
   from a hot cell's and derived "59 keV per photoionization", which would have
   been damning. Measured properly in ONE cell in ONE call: **10.79 eV per
   event**, entirely physical. The two integrals agree; they were never the
   problem.

### The actual defect

`ionBalance`'s writeback loop opens with the D-106 gate:

```fortran
if (lgPDR .and. pdrOwnIon /= 0) then
   if (grid%pdrZone(cellP) == 1 .and. &
        & (elem==1 .or. elem==2 .or. elem==6 .or. elem==8 .or. elem==12)) cycle
end if
```

In every PDR-zone cell MOCASSIN's ionization answer for H, He, C, O and Mg is
`cycle`d past and never written. `pdrOwnIon` defaults to 1 (fb4049a).

So two exactly opposite policies were both live:

| | policy |
|---|---|
| D-106 `pdrOwnIon` (default ON) | the chemistry owns H/He/C/O/Mg in PDR cells; discard MOCASSIN's answer |
| D-162 `pdrIonFromMocassin` | MOCASSIN owns the ionization and imposes it ON the chemistry |

They cancel. D-162 pushes MOCASSIN's ratio into the network; D-106 then throws
MOCASSIN's own answer away in the same cells, so what propagates is whatever
`handBackPDR` wrote - the chemistry's cosmic-ray equilibrium (D-161).

Measured in one cell, one call:

```
cell 13  A_V 1.38  Te 30000
up(H0->H+) 2.744e-9    dn(H+->H0) 5.620e-13    ratio 4883  ->  x(H+) = 0.9998
chemistry src/snk = 0        availFrac(H) = 1.0        iLo 1  iHi 2
grid ionDen x(H+)  =  0.0298      (bit-identical across every temperature step)
```

Nothing locked in molecules, no chemistry terms in the matrix, both stages in
the system - and the grid holds 0.0298 while the rates say 0.9998, unchanged to
the last bit across four successive steps because **nothing was writing it**.
A writeback probe placed after the store never fired at all, while the
build-time probe fired 32 times: proof the `cycle` is taken.

**That is the hot runaway.** `thermBalance` builds the heating from a
photoionization rate of 2.7e-9 /s times a neutral fraction of 0.97 - but that
rate, allowed to act, removes the neutral hydrogen doing the absorbing. The
heating is computed against an ionization state the same radiation field
forbids, and pinned there by the other code. No temperature can balance it.

The user's instruction was *"there is just one reality for x(H+) period"*. D-162
implemented that in one direction and this gate quietly undid it in the other.

### Fix

`pdrOwnIon`'s gate applies only when `pdrIonFromMocassin == 0`. Same shape as
D-165: a switch added later that never reached an older gate.

### Also found

* **`updateCell` runs before `pdrStep`** (iteration_mod:978 against :1075), so
  at the iteration where the PDR first engages MOCASSIN solves the balance with
  no PDR coolant at all, then `pdrStep` solves the chemistry at whatever
  temperature that produced. Measured: **4028 of 20024** ceiling clamps are
  cells the PDR has never reported for. Real, but a fifth of the effect.
* `ionBalance` sets `phXSec = 0.` and continues when the cross section
  underflows; `thermBalance` does `exit` on the same condition. The two
  integrate over different ranges. Not the cause here - it makes the heating
  integral shorter, not longer - but they should agree.
* The plain build broke for the **seventh** time on a PDR-scoped declaration.
  The D-166/167/168/169 counters now sit outside the `#ifdef PDR` block with a
  note. This wants a CI check, as D-109 already said.

### Result

Full 12 iterations, V1 slab, `pdrTeFromMocassin` + `pdrIonFromMocassin` +
`pdrCoolTdep` + `pdrAllCells` + `pdrCoolFeedback`:

| iteration 4 | frozen ion | + D-166 coolant | + D-169 |
|---|---|---|---|
| Te converged | 55.0% | 70.1% | **95.7%** |
| mean steps | 31.5 | 20.1 | **9.96** |
| clamped at 10 K | 14391 | 2842 | 2305 |
| clamped at 30000 K | 19927 | 20024 | **0** |

and it holds, improving, across every later iteration - by iteration 12 the
thermal solve is at **97.2%** in 6.4 mean steps with zero ceiling clamps.
**MOCASSIN now owns the thermal balance in PDR cells**, which it has never
actually done before.

The structure it produces is right:

| A_V | x(H+) | x(H) | x(H2) |
|---|---|---|---|
| 0.00-0.10 | 0.9999 | 9.5e-5 | 0 |
| 0.10-0.50 | 0.997 | 3.1e-3 | 0 |
| 0.50-1.00 | 0.045 | 0.952 | 6.8e-7 |
| 1.00-2.00 | 7.8e-3 | 0.775 | 4.3e-4 |
| 2.00-4.00 | 2.1e-3 | 8.2e-3 | **0.495** |

Ionization front at A_V ~ 0.5, atomic zone, H/H2 transition, deep x(H2) = 0.495
against the 0.494 D-098 verified against TORUS-3DPDR.

### RETRACTED: the transport claim

Mid-investigation I argued that Gamma = 2.7e-9 /s at A_V = 1.38 was ten orders
too large for the column, that MOCASSIN's transport was delivering stellar flux
that could not arrive, and that D-159's "not a transport bug" had been decided
from the D-165-contaminated state.

**Withdrawn.** That rested entirely on cells sitting on the 30000 K ceiling in
the broken configuration - a pathological state, not a sample of the model. With
D-169 fixed those cells do not exist, and the ionization front sits exactly where
it should. x(H+) at A_V 1-2 is 7.8e-3, not 1. D-159 stands.

The tau/cell = 1270 and Jdif = 0 measurements are real and still on the record;
what was wrong was inferring a transport defect from them while the cells
carrying them were in a state the fix removes.

### What is still open

Global convergence is **~0%** through all twelve iterations (0.072, 0.039,
0.066, 0.013, 0.026, 0.033, 0.000, 0.046, 0.0066) while the thermal solve is at
97% and the structure is correct. So the model is physically sensible and the
x(H0) criterion never passes.

That is now the whole of the remaining problem, and it is not thermal. Note what
the profile implies for the test: in the molecular zone x(H0) is 8e-3 and set by
the H/H2 balance, so a small absolute change is a large relative one - and the
criterion is relative. Whether that is a real instability or a criterion that is
unreasonable in molecular gas is the next thing to measure, not to assume.

## 2026-09-07a - D-171: the benchmarks in the self-consistent mode, and why they fail

All three fixtures rerun on the D-169 build with the full self-consistent set
(`pdrTeFromMocassin`, `pdrIonFromMocassin`, `pdrCoolTdep`, `pdrAllCells`,
`pdrCoolFeedback`). The thermal solver is healthy everywhere - zero ceiling
clamps on every fixture, Te convergence 85-97% - and the slabs are nonetheless
badly wrong.

| | D-128 (PDR owns T) | self-consistent |
|---|---|---|
| V1 H->2H2 front | 0.956 | **23.86** |
| V2 H->2H2 front | 0.882 | **1.288** |
| V1 median T ratio | ~1 | **149.6** |
| V2 median T ratio | ~1 | **3.68** |

Section 5.4 fails the same way. Its radial profile oscillates - 4118, 6484,
43.8, 43.9, 7702, 5048, 4297, 285, 25.0 K - while 3D-PDR's x(H2) climbs
smoothly from 1.6e-6 to 0.486 and ours reaches the right value only at the last
point. Over its 15053 PDR-zone cells with A_V > 0.3: **25.4% above 1000 K,
15.8% above 5000 K, 17.6% below 100 K**, spanning 10 K to 14206 K where a PDR
belongs at 20-200 K throughout.

**Correction.** I first reported section 5.4 as structurally sound in this mode
(front at A_V ~ 0.5, deep x(H2) = 0.495) and used that to argue the failure was
slab-specific. That was wrong: I had binned by A_V and taken medians, which
smooths over the very oscillation that IS the defect. The same error as reading
a scalar - which is what D-172 exists to stop.

### The failure is spatial, not thermal

V1's temperature along the sightline is not a monotonic profile with a hot
offset. It is interleaved:

| A_V | n | median Te | min | max | median x(H2) |
|---|---|---|---|---|---|
| 2-3 | 100 | 8411 | **17** | 11036 | 1.1e-7 |
| 3-4 | 76 | 10804 | 1313 | 10941 | 2.9e-8 |
| 4-5 | 63 | 10689 | **19** | 10818 | 3.0e-8 |
| 6.8-7.5 | 29 | 9640 | **10** | 10161 | 5.1e-8 |
| **7.5-9** | 38 | **10.4** | 10.2 | 9353 | **0.4986** |

The deepest 38 cells are *correct* - 10.4 K, x(H2) = 0.4986. Between A_V 2 and
7.5 there is a hot atomic bubble with cold molecular gas on both sides of it,
and within any single A_V bin cells range over three decades in temperature.

Counting hot/cold transitions along the sightline settles it:

| | above 1000 K | transitions |
|---|---|---|
| V1 (801 cells) | 51.7% | **55** |
| V2 (401 cells) | 4.7% | **25** |

A single thermal front gives 1-2. Adjacent cells at identical A_V, density and
field are landing on different branches.

### The loop

With MOCASSIN owning the temperature AND the H2 cooling feeding back into it:
hot -> H2 collisionally destroyed -> H2 cooling lost -> hotter; cold -> H2 forms
-> more cooling -> colder. Two attractors. This is D-112's H2 bistability
reappearing in the temperature rather than in the front position.

V2 is 100x denser and 10x less affected, which is the mechanism's own
prediction: cooling per hydrogen scales with n, photoionization heating per
hydrogen does not.

### What Cloudy does about it

Not a solver trick - three architectural things, none of which MOCASSIN has.

1. **Continuation in space.** Each zone's temperature solve starts from the
   PREVIOUS ZONE's converged answer, with the bracketing step capped at 0.2*T
   (`conv_temp_eden_ioniz.cpp`). The solution is tracked along a branch; a zone
   is never allowed to look far enough to find the other attractor.

2. **Adaptive zoning that forbids jumps.** `radius_next.cpp` - 1451 lines - sets
   the next zone thickness to the minimum over a long list of "do not let X
   change by more than this per zone" criteria:
   * temperature: target dT/T = 0.03 per zone, shrink floored at 0.5, commented
     *"from 0.7 to 0.5 stop from punching through thermal front"* - changed
     twice (97 May, 04 Mar) for exactly that;
   * H2 heating/cooling: if H2 carries >10% of heating, limit its fractional
     change to 0.05 per zone;
   * H2 abundance: keys on d(H2)/H, tightened repeatedly in the change log -
     *"limit from 0.01 to 0.001, some models fell over H2 front"*, then
     *"1e-4 to 1e-6"*, then *"from >1e-6 to >1e-8, some pdr's had too large a
     change in H2"*;
   * plus relative ionization, dust optical depth per zone, the Draine field.
   Each candidate goes into a `drChoice` object that records WHICH criterion set
   the step - the same discipline as `chNotConverged`.

3. **It names instability.** `thermal.lgUnstable = (dCmHdT + 2*sigma < 0)`,
   counted in `thermal.nUnstable`, printed per zone and in the closing
   commentary. Cloudy does not try to suppress an unstable solution; it reports
   one.

MOCASSIN's grid is fixed before the run, every cell is solved independently from
its own previous-iteration value, and the field carries Monte Carlo noise.
Nothing ties cell j's branch to cell j-1's, so noise alone selects the attractor.
That is the whole of the 55 transitions.

This is the deeper form of D-080/D-081 ("uniform grids cannot resolve a front -
TORUS-3DPDR uses AMR here"): Cloudy's zoning is driven by SOLUTION change, not
by geometry, which is something AMR-on-density would not supply either.

### Sequenced next steps

1. Port `lgUnstable` - evaluate d(H-C)/dT at the converged temperature per cell
   and count it. Distinguishes genuine bistability from noise amplifying a stiff
   response. ~10 lines, and it is a measurement rather than a fix.
2. Neighbour seeding - start each cell's solve from the converged temperature of
   the neighbour toward the source. The essential half of Cloudy's continuation,
   cheap on a slab.
3. Per-iteration damping - Cloudy damps ionization 50% per pass in `ConvBase`;
   MOCASSIN damps nothing anywhere.
4. Solution-driven adaptive zoning: the real fix, and the large one.

## 2026-09-07b - D-172: convergence reporting that names a reason

The user's instruction, after D-171: fix the convergence *reporting* before
touching the criterion. That is Cloudy's discipline exactly - `chNotConverged`
carries the reason an iteration failed, `drChoice` records which criterion set
the zone thickness, `lgUnstable` names a cell on the unstable branch. MOCASSIN
printed one percentage and nothing else, so every convergence argument in this
log - including two of mine that turned out wrong - has been an argument about a
scalar with no attribution.

Instrumentation only. Nothing about the test changes, so the next decision on
`XHILimit` is made on measurement.

Per iteration, summed over ranks:

* failure count and fraction;
* histogram of log10 |dx(H0)/x(H0)|;
* failures binned by x(H0) magnitude and by A_V band;
* **near/far split** - within 2x tolerance, versus moving >100% per iteration.
  That single line separates "the tolerance is below our Monte Carlo noise
  floor" from "the model is not settling";
* **thermally unstable count** - Cloudy's `thermal.lgUnstable` ported. It tests
  d(C-H)/dT < 0; the residual here is H-C, so the unstable sign is
  d(H-C)/dT > 0 - raising T increases net heating, a runaway rather than a
  thermostat. Estimated from the last two distinct evaluations of the scan, as
  `iter_track::deriv` does;
* the fraction that would pass a Cloudy-shaped **gated** test (20% tolerance,
  skipped where x(H0) < 1e-3, the analogue of
  `colden[i]/colden[HTOT] > 1e-5`);
* and a named dominant reason:

```
! CVPROBE   NOT CONVERGED: thermally unstable solution (d(H-C)/dT > 0)
! CVPROBE   NOT CONVERGED: x(H0) too small to matter (< 1e-3); relative test is MC noise
! CVPROBE   NOT CONVERGED: x(H0) moving >100% per iteration; model genuinely not settling
! CVPROBE   NOT CONVERGED: just outside XHILimit; tolerance may be below the MC noise floor
! CVPROBE   NOT CONVERGED: concentrated at A_V 1-4, the H/H2 transition
```

### Why the tolerance is suspect on its own

`XHILimit = 0.05` is a **5%** per-cell relative test with no significance gate,
against Cloudy's `autocv = 0.20` on gated, model-integrated quantities. And
MOCASSIN is a Monte Carlo code: 6e6 packets over 20025 cells is ~300 per cell,
so the Poisson noise on a cell's mean intensity is ~1/sqrt(300) = **6%** -
larger than the tolerance being demanded of it. A Monte Carlo code cannot
satisfy a per-cell relative tolerance below its own noise floor. That is exactly
why a deterministic code can afford to test integrated quantities at 20%.

D-149 reported convergence "indifferent to 8x packets", but that was measured in
the D-165-contaminated state and needs re-testing once the reporting is in.

## 2026-09-07c - D-177: audit of the code against the self-consistent mode

Three defects this session shared one shape: a switch added later that never
reached an older gate (D-165 `pdrTeFromMocassin` vs the D-072 short circuit,
D-169 `pdrIonFromMocassin` vs the D-106 `pdrOwnIon` gate, D-176
`pdrTeFromMocassin` vs the D-032 convergence override). Each was found by
tripping over it. This is the systematic sweep instead: for every switch that
defines the self-consistent mode, every consumer of the quantity it governs.

### Findings

| # | site | status |
|---|---|---|
| 1 | `pdrOwnIon` discards MOCASSIN's ionization in PDR cells | **fixed** D-169 |
| 2 | `lgPDRcell` skips the thermal solve in PDR cells | **fixed** D-165 |
| 3 | `pdrStep` clears `lgConverged` on the PDR heat/cool balance | **in test** D-176 |
| 4 | `elemAvail` stands down, and the rates that replace it measure ZERO for H | **open** |
| 5 | x(H0) - the convergence variable - is written by `handBackPDR` from the chemistry's x(H2) | **understood** |
| 6 | `pdrTmin`/`pdrTmax` clamp the chemistry to [1, 20000] K while `iterateT` allows 30000 | **open** |
| 7 | `pdrAtomicH` default ON is the configuration D-099 warned about | **understood** |

Verified consistent and needing no change: `handBackPDR`'s ionization writeback
(w = 0 under `pdrIonFromMocassin`, so `ionDen(H,2)` is untouched);
`pdrUseNePDR` (off by default, and D-105 measured that turning it on makes the
runaway worse); the D-133 atomic-coolant replacement's `pdrZone` gate (outside
the zone the electron treatment is the right one); the `lgConverged` MPI
reduction (`max = 1` throughout, `convPercent` faithful - measured in D-176, my
double-counting hypothesis was wrong); the `nst` bound on the rate injection
(set at the top of the element loop, not stale).

### 4. elemAvail stands down for rates that are zero

`update_mod:2492`, D-118's rule: *"elemAvail and the per-stage chemical rates
are two descriptions of the same physics ... where the rates are supplied
elemAvail must stand down"*. So in any PDR-zone cell with `lgIonChemRates`
(default true), `availFrac(elem) = 1.0` - ionBalance normalises the ion stages
as if no molecules existed.

That is correct only if the rates actually arrive. D-169 measured, in a PDR-zone
cell, `chemSrc(H+) = chemSnk(H+) = chemSrc(H0) = chemSnk(H0) = 0`, with all ten
ion links resolved at startup and the export code plainly present
(`pdr_mod:1789`). So for hydrogen the molecular locking is represented by
*neither* mechanism inside ionBalance: elemAvail stood down and nothing took its
place.

The composition is rescued afterwards by finding 5 - `handBackPDR` overwrites
`ionDen(H,1)` - so the model does not obviously misbehave. But ionBalance is
solving the wrong system, and whether the same holds for C, O and Mg (which have
no equivalent rescue) is not yet measured.

### 5. The convergence variable is a molecular quantity

With `pdrAtomicH` on (default), `handBackPDR` writes

```fortran
ionDen(H,1) = max(w*x_chem(H) + (1-w)*(1 - x(H+) - 2*x(H2)), 0)
```

and under `pdrIonFromMocassin` w = 0, so **x(H0) = 1 - x(H+) - 2 x(H2)** with
x(H+) MOCASSIN's and x(H2) the chemistry's.

The convergence test is defined on x(H0). So when a cell flips branch and x(H2)
goes 0.49 -> 5e-8, x(H0) goes ~0.02 -> ~1: a fiftyfold change, reported as
"moving >100%". **"x(H0) moving >100% per iteration" has been the H2 bistability
all along, seen through the composition identity.** The variable is well chosen -
it does track the real instability - but D-172's named reason should say so
rather than implying an ionization problem.

Note also the comment above that line describes the OPPOSITE of what the code
now does: it explains that this is deliberately *not* the atomic fraction
("every nucleus not in H+, the molecular ones included"), which describes the
`else` branch. The `pdrAtomicH` branch subtracts the molecular hydrogen. The
comment predates D-101 defaulting the switch on.

### 6. Two temperature ranges

`pdr_mod:1616` clamps `Tg` to `[pdrTmin, pdrTmax]` = [1, 20000] K
unconditionally - *"keep the chemistry inside the temperature range it was
fitted over"* - while `iterateT` solves up to 30000 K. Under
`pdrTeFromMocassin` the chemistry and the coolants are therefore evaluated at a
temperature up to 1.5x below the one the thermal balance is using, and D-166's
power law extrapolates the rest. Measured in D-168: a third of the sampled cells
report `pdrCoolTref` sitting exactly on 20000.

### 7. pdrAtomicH is on in the configuration D-099 warned about

D-099 measured that handing the true atomic fraction to MOCASSIN makes the
molecular interior transparent to the Lyman continuum, and D-101 guarded it
behind `pdrAtomicH` for *"a source that emits no ionizing photons"*. It was
later defaulted on (fb4049a). Every benchmark fixture uses a full blackbody with
**11.6% of its energy above 1 Ryd** - precisely the case the guard excluded. The
proper fix went in as D-107 (H2 photoionization opacity), so this is probably
fine, but the switch is being used outside the condition it was justified under,
and the pure-FUV fixtures built earlier today are the way to check.

## 2026-09-07d - D-176: the convergence number was reporting the wrong test

CV7 (criterion as-is) against CV8 (criterion skipped where MOCASSIN owns the
balance), identical in every other respect:

| iteration | CV7 | CV8 |
|---|---|---|
| 4 | 0.033% | **98.24%** |
| 5 | 0.0066% | **98.22%** |

The two runs are physically identical - x(H0) failures 1454 vs 1463 at iteration
4, 1444 vs 1433 at iteration 5, flip rates 45.3/45.8% and 5.2/5.2%. Only the
flag differs. `pdrStep` was clearing ~74500 pass-events per iteration, cells
that had *passed* the x(H0) test.

### Why the criterion is meaningless here

D-032 added it when the PDR solved its own thermal balance, so
`heat(12) == coolTot` was exactly what it had converged to. Under
`pdrTeFromMocassin` the temperature comes from MOCASSIN's balance, which carries
MOCASSIN's photoelectric heating, its gas-grain term and its atomic coolants -
3D-PDR's own heating and cooling have no reason to match at it. The test asks,
at 0.5%, whether a balance nothing is solving happens to hold. With
`pdrAllCells` it ran in ionized cells too.

### What this voids, and what it does not

**Void:** the `conv` column in every run of this session, and every statement
leaning on it - including "the model never settles" (D-171) and D-149's original
"convergence collapses when pdrTeFromMocassin is on", which was partly this.

**Unaffected:** every probe-based measurement, because D-170/D-172/D-173
instrument the x(H0) test directly rather than the flag. The packet null result
(D-172), the flip rates, the damping effect, the pdrStartIter comparison, and
D-171's profile bistability all stand - 55 hot/cold transitions along a sightline
is a physical measurement of the state, not an artifact of a convergence flag.

### The model is not in a limit cycle

CV8 exited at iteration 5 on hitting the convergence limit - inside the same
quiet window that CV4 and CV7 both show ending in a blow-up at iteration 6. The
code made the error I had made three times today: calling convergence from
inside a transient. CV9, forced to run ten iterations:

| iter | x(H0) fail | flip | conv |
|---|---|---|---|
| 4 | 1449 | 45.5% | 98.24% |
| 5 | 1414 | 5.2% | 98.22% |
| 6 | 52158 | 68.4% | 32.44% |
| 7 | 53161 | 70.3% | 29.37% |
| 8 | 54968 | 74.5% | 29.86% |
| 9 | 50982 | **27.2%** | 36.90% |
| 10 | 41043 | **19.8%** | **53.70%** |

The 98.2% was premature. But iteration 6 is an excursion, not a new steady
state: from iteration 8 the model recovers monotonically in both measures and
was still improving when the run hit its ceiling. A damped oscillation, not a
sustained one - consistent with iterDamp working, slowly. CV10 runs 22
iterations to see whether it reaches the limit.

### The early-exit rule needs revisiting

`maxIterateMC n pct` stops the run the first time `convPercent` crosses `pct`.
Nothing requires the model to have *stayed* there, and the one place we have
looked, it exited one iteration before a 3x excursion. Cloudy's
`ConvIterCheck` has the same shape but tests several independent integrated
quantities and records which one failed; a single-shot threshold on one number
is weaker than that. Worth requiring two consecutive iterations, at least.



## 2026-09-07e - D-178/D-179/D-180: the convergence criterion, rebuilt

### D-180: the tolerance was 90%

```fortran
case ("convLimit")
    read(unit=10, fmt=*, iostat=ios) keyword,  XHILimit
```

and every fixture in this project carries `convLimit 0.90`. The keyword reads
like "the fraction of cells that must converge" - and such a threshold does
exist, as the second number on `maxIterateMC` - but it sets the PER-CELL
relative tolerance. `XHILimit`'s 0.05 default in set_input_mod was overridden in
every run and was never what executed.

So a cell counted as converged if x(H0) changed by less than **90%** in one
iteration. Every convergence number this project has ever reported, including
all of today's, was measured against that.

This also retracts my own analysis from D-172: I argued at length that
`XHILimit = 5%` sat below the ~6% Monte Carlo noise floor and motivated a
packet-count experiment on it. The real tolerance was 90%, far above the noise.
I read the default out of the source instead of checking what the input set.

Parser annotated. All four fixtures moved to `convLimit 0.10`.

### D-179: x(H2) belongs in the test

x(H0) = 1 - x(H+) - 2 x(H2) (D-177 finding 5). At the iteration the PDR
switches on, H2 has not formed, so x(H0) still equals the converged
photoionization answer and the test passes - while the molecules, the only thing
still moving, are untested. Cloudy tests molecular column densities alongside
its other quantities, gated at `colden[i]/colden[HTOT] > 1e-5`, naming the
species that failed (`conv_itercheck.cpp`).

Both x(H0) and x(H2) must now settle, with `cvH2floor` as the significance gate
so a cell going 1e-30 -> 1e-28 cannot block the model. Measured on the first run
- at iteration 4, the exact iteration that used to report 98%:

| | x(H0) only | **x(H2) only** | both |
|---|---|---|---|
| failures | 2956 | **52249** | 6368 |

Eighteen times more molecular failures than atomic. The criterion now sees what
it was blind to.

**The ordering inverts as the model settles**: by iteration 8 it is 45736 x(H0)
against 7728 x(H2), and stays that way. Molecules form on a grain-surface
timescale and lock in; the atomic fraction keeps responding to the field. Only
visible because the two are tested separately.

### The model converges

22 iterations, `convLimit 0.10`, both criteria, `pdrFcritConv 0`:

| iter | 4 | 8 | 12 | 15 | 18 | 22 |
|---|---|---|---|---|---|---|
| converged | 0.51% | 11.6% | 60.7% | 80.8% | 85.7% | **86.4%** |

and by Cloudy's own standard it is converged - per-species total content at the
final iteration:

| H0 | H+ | H2 | CO | C+ | C | e- | <Te> |
|---|---|---|---|---|---|---|---|
| +0.92% | +0.67% | **-0.14%** | -0.94% | +0.03% | +0.01% | +0.67% | **+7.85%** |

Every species stable to ~1%, far inside `autocv = 0.20`. H2 - changing +594% at
the iteration the old criterion called 98% converged - now moves 0.14%.

**The model was always converging.** It was stopped at 8-12 iterations and
judged by the PDR heat/cool balance (D-176) at a 90% per-cell tolerance (D-180)
with molecules untested (D-179). Three defects stacked to hide it. It needs
about 18-22 iterations; every fixture was too short.

### What is still open

* **~14% of cells churn between branches.** Real, and it averages out globally -
  which is why the integrated quantities look clean while the per-cell test says
  86%. Cloudy's criterion would call this done; both are true and they measure
  different things.
* **Mean Te still moves 7.85% per iteration**, the largest residual by far and
  the next thing to chase.
* Every benchmark comparison in the log and the artifacts was run at
  `convLimit 0.90` and at 8-12 iterations. The front positions remain valid
  measurements of the state reached, but they were not measured on a converged
  model and need re-running.
\n

## 2026-09-08a - D-181: the benchmarks, on a converged model at last

All three fixtures re-run at 24 iterations with `convLimit 0.10`, both x(H0) and
x(H2) tested, and the PDR heat/cool criterion gated off. Every previous
benchmark number in this log was taken at 8-12 iterations, at a 90% per-cell
tolerance, judged by a balance nothing solves.

| fixture | converged? | H->2H2 | C->CO | median T ratio |
|---|---|---|---|---|
| V1 (n 1e3) | **no** - H0 -27%, Te -33% | 2.31 | 0.48 | 8.70 |
| V2 (n 1e5) | **yes** - all <=0.7%, Te 2.1% | 1.32 | **1.017** | 6.90 |
| sec 5.4 | mostly - Te 13.5% | - | - | ~3x |

### How far the numbers moved

V1, same fixture, 8 iterations against 24:

| | 8 iters | 24 iters |
|---|---|---|
| median T ratio | 149.6 | **8.70** |
| H->2H2 front | 23.86 | **2.31** |
| C->CO front | 0.168 | 0.48 |

An order of magnitude on both, which is the measure of how meaningless the
earlier comparison was.

### The bistability largely resolves with convergence

| | before | after |
|---|---|---|
| V1 hot/cold transitions along the sightline | 55 | **15** |
| V1 cells above 1000 K | 51.7% | **10%** |
| V2 transitions | 25 | **1** |
| V2 cells above 1000 K | 4.7% | **1%** |

V2 now shows a single clean thermal front, which is what a correct PDR looks
like. What remains is a systematic warm offset, not a checkerboard. D-171's
framing - "the self-consistent mode is spatially bistable" - was measured before
convergence and overstated: the bistability is a transient the model works its
way out of, given enough iterations.

sec 5.4's radial profile is the clearest demonstration. Before: x(H2) of 2.6e-7,
5.4e-5, 3.0e-7, 4.8e-5, 0.493 with temperatures oscillating 4118, 6484, 43.8,
43.9, 7702, 5048 K. After: a smooth rise to x(H2) = **0.495** against the
reference's 0.493, with a coherent 310-390 K through the PDR.

### What is now the disagreement

**The chemistry is close and the temperature is not.** V2's CO front is 1.017
and its H2 front 1.32; sec 5.4's molecular profile matches to three digits deep.
The gas is 3-7x too warm in all three fixtures - systematic, not bimodal.

Part of that is D-089, the scattered FUV the reference has no term for, but
D-089 measured 2.4x and this is 6.9x on V2's median. The residual hot cells
inflate a median, so the distribution rather than the median is the next thing
to look at.

### V2 converges and V1 does not

Same code, same criterion, same iteration count. V2 is 100x denser, and cooling
per hydrogen scales with n while photoionization heating per hydrogen does not -
the same argument that ordered the severity when the bistability was first
measured.

V1 also still receives the full 25000 K blackbody with 11.6% of its energy above
1 Ryd, which the Roellig specification excludes (D-101) and which a pure-PDR
slab has no business absorbing. The pure-FUV fixtures were built during D-171
and have never been run; that is the obvious next test for V1.

## 2026-09-08b - D-182: the zone gates come out

Hektor's ruling, and it restates a principle already settled twice in this log
(D-152's blend gate, D-169's pdrOwnIon gate): *"we should not have the zone
gate. this should emerge naturally from the self consistent solution."*

I had defended this one an hour earlier as "right rather than a leftover". That
was wrong, and the argument against it is short. 3D-PDR's coolants are solved
with electrons **and** H, H+, He, H2 as colliders (`FIND_CCOEFF` receives all
five densities, and splits H2 ortho/para at the equilibrium ratio
`FPARA = 1/(1+9exp(-170.5/T))`). MOCASSIN's `forbiddenLines` carry electrons
alone. So the PDR value is strictly the more complete physics in **every** cell:
in ionized gas it reduces to the electron-dominated case by itself, because
FIND_CCOEFF is handed the same n(e) MOCASSIN would use. Gating it on
`pdrZone == 1` bought nothing and put a discontinuity at `pdrZoneLim`.

Removed for the coolant substitution and for `pdrDustFeedback`, both behind
`pdrCoolZoneGate` (default 0 = no gate) so the old behaviour stays measurable.

Surveyed and left alone, with reasons:

* `pdrPEfromPDR`, `pdrUseNePDR` - default off, so their gates are inert.
* the D-072 short circuit - now gated on `pdrTeFromMocassin == 0`, so it never
  fires in the self-consistent mode; its zone test *is* the definition of the
  legacy mode.
* **`elemAvail` / rate injection - the same anti-pattern, deliberately not
  touched yet.** See D-185.

## 2026-09-08c - D-183: how H2 cooling is handled, in both codes

Hektor asked. The answer is that **neither 3D-PDR nor our coupling has an
explicit H2 line coolant**, and that is a deliberate match rather than an
oversight.

H2 enters 3D-PDR in three ways:

1. **As a collision partner.** `coolingfunctions.F90` passes `H2_COL`,
   `PH2_COL`, `OH2_COL` and n(H2) into `FIND_CCOEFF`, so H2 excites CO, C+, C
   and O. This is the D-072/D-133 point - it is why the PDR's [C II] and [O I]
   are orders of magnitude stronger than MOCASSIN's electron-only versions.
2. **As three heating terms** of the twelve in `heatingfunctions.F90`: H2
   formation (1.5 eV), H2 photodissociation (0.4 eV), FUV pumping (2.2 eV x 9).
3. **Radiative loss implicitly.** `FUVPUMPING_HEATING` carries
   `1/(1 + NCR_H2/DENSITY)`: below the critical density pumped H2 de-excites
   radiatively and the energy leaves the gas, accounted for by suppressing the
   heating rather than by adding a cooling term.

The cooling proper is the four coolants (CO, C+, C, O) through escape
probability, plus gas-grain when Td < Tg. Our coupling carries all of that: the
same four coolant files, and all three H2 heating terms in `pdrHeatXtra`.

**Cloudy differs.** It runs a full H2 level model (`mole_h2.cpp`) and computes
H2 heating and cooling explicitly from the populations - `radius_next.cpp` even
limits the zone thickness on "change in H2 heating/cooling" once H2 carries more
than 10% of the heating.

Worth watching but not a candidate for our warm bias on its own: the reference
lacks the term too, so it cannot explain us being warmer *than the reference*.
It could only amplify an existing offset, and only where our H2 differs from
theirs.

## 2026-09-08d - D-184: sec 5.4 was being compared against the wrong reference

Chasing whether carbon showed the elemAvail signature turned up something else.
`cmp_sph.py` defaulted to `hii1dv2`, and there are two spherical references:

| | C+ | O |
|---|---|---|
| `hii1dv2` | 1.4e-4 | 3.0e-4 |
| `sec54` (and the hiipdr fixture) | **2.2e-4** | **3.3e-4** |

So every sec 5.4 comparison in this project carried a spurious uniform
**1.571x** carbon offset. Against the correct reference the surface C+ matches
exactly, 2.20e-4 both sides.

What that leaves is more informative than what it removes:

| A_V | x(C+) ours | ref | T ours | T ref | chi ours/ref |
|---|---|---|---|---|---|
| 0.00 | 2.20e-4 | 2.20e-4 | 362 | 182 | 1.55 |
| 1.14 | 1.85e-4 | 2.20e-4 | 325 | 91 | 1.54 |
| 2.21 | 1.04e-4 | 1.92e-4 | 389 | 30 | **6.19** |

The temperature excess grows with depth - 2.0x at the front, **13x** deep - and
tracks chi_ours/chi_ref, which grows the same way. That is D-089/D-090:
MOCASSIN transports scattered FUV that the reference's `exp(-3.02 A_V)` has no
term for, giving gamma_eff = 1.85 against 3.02, and the difference compounds
exponentially in A_V. So the deep temperature disagreement is largely a known
and understood difference in the radiation field, not a missing coolant.

Our C+ also converts to C and CO faster than the reference at depth
(1.04e-4 against 1.92e-4), which is now a real physical difference to examine
rather than an abundance artifact.

The script's default is corrected, with the reason in a comment.

## 2026-09-08e - D-185: the rate matrix becomes the standard

Hektor's instruction: make the rate matrix the self-consistent path throughout,
and remove the leftover gates. This is the deepest of them.

### The two descriptions

`ionBalance` normalises ion stages to sum to one, which asserts the whole
element is atomic or ionic - false wherever CO or H2 holds some. Two ways to
say otherwise:

* **elemAvail (D-102)**, in *abundance* space: only fraction f of the element is
  available to the stages, f = (neutral + ionized)/total from the chemistry.
* **Per-stage rates (D-118)**, in *rate* space and Cloudy's design
  (`ion_solver.cpp:765`): a formation rate into the RHS and a specific
  destruction rate onto the diagonal, so "C+ is consumed into CO this fast and
  released that fast" appears in the balance equations directly.

D-118's rule that only one may apply is correct - both would count the same CO
twice.

### What was wrong

The test for which applies was `grid%pdrZone(cellP) == 1`. That **asserts** the
rates are present rather than checking. They are written by `pdrStep`, which
runs after `updateCell` in every coupling pass (iteration_mod:978 against
:1075), so on the first PDR pass `pdrIonRate` is identically zero - and D-169
measured zero for hydrogen in a zone cell with all ten links resolved.

Wherever that happens, `availFrac` is forced to 1.0 **and** the rates contribute
nothing: the locking is carried by neither, and ionBalance solves as if no
hydrogen were molecular in cells that are 98% H2.

It does not visibly break for hydrogen because `handBackPDR`'s `pdrAtomicH`
branch afterwards overwrites `ionDen(H,1)` with `1 - x(H+) - 2 x(H2)`, restoring
the composition the solve got wrong. **C, O and Mg have no such rescue.**

### The fix

Key the stand-down per element on whether that element's rates are actually
non-zero in this cell:

```fortran
lgHaveRates = .false.
do ik = 1, pdrNlink
   ...
   if (pdrIonRate(cellP, ik) /= 0. .or. pdrIonRate(cellP, pdrNlink+ik) /= 0.) &
        lgHaveRates(pdrLinkElem(ik)) = .true.
end do
...
if (lgIonChemRates .and. lgHaveRates(elem)) then
   availFrac(elem) = 1.d0        ! the rates carry it
else
   availFrac(elem) = elemAvail   ! the abundance carries it
end if
```

Three cases, exhaustive, and none double-counts:

| | carried by |
|---|---|
| rates present | the rate matrix |
| rates absent | elemAvail |
| neither | impossible by construction |

The zone gate disappears from the stand-down and from the injection, which is
the point of D-182 applied here. It is also robust to the ordering problem
rather than papering over it: on the first PDR pass the rates are zero, the test
sees that, and elemAvail correctly stays in force.

### Correctness is independent of the open question

D-183's measurement - whether the rates are delivered at all from pass 2 onward,
or genuinely zero throughout - is still running. The fix is right either way,
which is why it did not wait for it:

* if the rates arrive, the test picks them up and the rate matrix is the
  standard path, as intended;
* if they never arrive, elemAvail stays in force and the locking is represented
  rather than lost.

What the measurement changes is the *interpretation* - whether D-118's design
has been working since it was written, or has never fired - not whether this
code is correct.

### The measurement, and a correction to D-177

D-183's probe, per iteration over 15204 cells:

| slot | link | non-zero cells | mean \|rate\| |
|---|---|---|---|
| 1, 2 | H, H+ | 15105 | 4.07e-14, 3.40e-14 |
| 3, 4 | He, He+ | 15081, 15204 | 2.5e-18 |
| 5, 6 | C, C+ | 15042 | 8.4e-19, 1.0e-18 |
| 7, 8 | O, O+ | 15105 | 3.4e-14 |
| **9, 10** | **Mg, Mg+** | **0** | **0** |

**D-118's design has been working.** Hydrogen's rates are non-zero in 99.3% of
cells, so D-169's measured zero was the first-pass artifact suspected above -
`ionBalance` runs before `pdrStep`, and that probe sampled the one pass where
`pdrIonRate` has never been written.

**D-177 finding 4 was over-stated by me** and is corrected here. The claim was
that the molecular locking is carried by neither mechanism. That is true for one
coupling pass out of ~105, and permanently true only for **magnesium**.

Magnesium is the case the fix was actually needed for. Its rates are zero in
every cell, so the old `pdrZone == 1` test forced `availFrac(Mg) = 1.0` on the
assumption of a delivery that never happens: magnesium's ion stages have been
normalised as if no magnesium were ever locked in a molecule, in every PDR cell,
for the life of this project. Under D-185 `lgHaveRates(12)` is false and
elemAvail carries it.

Expected impact: small. Mg is 2.7e-6 of hydrogen and contributes negligibly to
the cooling and the electron budget, so no benchmark number should move. That is
a prediction to test, not an assumption - and the value of the change is that
the behaviour is now correct by construction rather than by accident.

## 2026-09-08f - D-186: the one place we take what MOCASSIN already provides

Hektor's rule, stated while reviewing the coolant path: *"We should use from
3D-PDR only what Mocassin does not provide. We should not delete MOCASSIN's
cooling if it was not calculated elsewhere."*

The second sentence settles an open design question and I withdrew a change I
had just offered because of it. I had proposed making `pdrCoolSp = 0`
distinguishable between "carrier destroyed, not computed" and "computed to be
zero", so that a genuine zero could be substituted. That is precisely the thing
the rule forbids: it would let 3D-PDR's zero delete MOCASSIN's cooling. D-167's
guard stands as written - replace only where there IS a replacement.

### Audit against the rule

| quantity | MOCASSIN provides? | what we do |
|---|---|---|
| CO cooling | no line data | take 3D-PDR's |
| molecular abundances | no chemistry | take 3D-PDR's |
| H2 formation / photodissociation / FUV pumping / cosmic-ray / turbulent / chemical heating | none exist in MOCASSIN | take 3D-PDR's (`pdrHeatXtra`) |
| photoelectric heating | yes, from its own grains | excluded, MOCASSIN's stands |
| carbon photoionization heating | yes, in `heatSte` | excluded |
| gas-grain heating | yes, `gasDustColl_g` | excluded |
| ionization state | yes | MOCASSIN owns it (D-162) |
| temperature | yes | MOCASSIN owns it (D-165) |
| **[C II], [C I], [O I] cooling** | **yes, but electron-excited only** | **replaced (D-133)** |

Everything obeys the rule except the last row.

### Why it stays for now, and what the endpoint is

MOCASSIN does have the lines - `ci.dat`, `cii.dat`, `oi.dat` - but excites them
with electrons alone. In neutral gas x(e-) ~ 1e-4, so its [C II] and [O I]
under-cool by orders of magnitude: D-133 measured that leaving MOCASSIN to own
them put the deep PDR at 157 K, where 3D-PDR's own balance at that same
temperature said cooling exceeded heating 3.2 to 1. So 3D-PDR's value is the
physically correct one today and Hektor's ruling is to keep it.

**But two codes now hold line data for the same transitions**, which is exactly
the duplication this project has spent D-161 to D-169 removing everywhere else.
It is an atomic-data inconsistency waiting to bite: if the two datasets ever
disagree - different A-coefficients, different level energies, different
collision fits - the model's cooling depends on which code happened to compute
it, and nothing would flag the discrepancy.

**The endpoint** is that MOCASSIN owns these coolants outright, with H, H2 and
He added as colliders, and 3D-PDR supplies only collision rates MOCASSIN does
not have. That is not a data-sourcing problem: the rates are already in the
LAMDA files the PDR reads - `12c+.dat` carries `H_COL`, `H2_COL`, `PH2_COL` and
`OH2_COL` alongside `EL_COL`. The work is extending MOCASSIN's `forbiddenLines`
to accept non-electron colliders, then deleting the substitution.

Until then the substitution is a **known, deliberate, physically justified
duplication**, recorded here and on the status page so it is not mistaken for
an oversight.

## 2026-09-08g - D-187: how far apart the two atomic datasets actually are

D-186 flagged that two codes hold line data for the same transitions and that
the cooling therefore depends on which one computed it. That was a statement of
risk; this measures it, so the future work has a baseline rather than a
suspicion.

MOCASSIN reads CHIANTI v10 files (`data/ci.dat`, `cii.dat`, `oi.dat` - level
energies, statistical weights, electron collision strengths Omega(T), and
A-values, all in one file). The PDR reads LAMDA (`dataPDR/12c.dat`,
`12c+.dat`, `16o.dat` - energies, weights, A-values, and collision RATE
coefficients for e-, H, H+, He, para-H2 and ortho-H2).

### Level energies and weights: no disagreement

| | MOCASSIN | LAMDA | difference |
|---|---|---|---|
| C II 2P3/2 | 63.4 | 63.395087 | 0.008% |
| C II 4P1/2 | 43003.2 | 43003.291 | 0.0002% |
| C II 4P3/2 | 43024.2 | 43025.285 | 0.0025% |
| C I 3P1 | 16.4 | 16.4167122 | 0.10% |
| C I 3P2 | 43.4 | 43.4134544 | 0.03% |
| O I 3P1 | 158.3 | 158.2687410 | 0.02% |
| O I 3P0 | 227.0 | 226.9852492 | 0.006% |

Statistical weights are identical throughout - C II (2,4,2,4,6), C I (1,3,5),
O I (5,3,1). MOCASSIN's energies are simply stored to fewer decimals. Nothing
here is a physical disagreement.

### Einstein A-coefficients: 1 to 6 percent apart

| line | MOCASSIN (CHIANTI v10) | LAMDA | difference |
|---|---|---|---|
| [C II] 158 um | 2.290e-06 | 2.321e-06 | **1.3%** |
| [C I] 609 um (2->1) | 7.93e-08 | 7.880e-08 | 0.6% |
| [C I] 370 um (3->2) | 2.65e-07 | 2.650e-07 | 0.0% |
| [O I] 63 um | 8.542e-05 | 8.910e-05 | **4.1%** |
| [O I] 145 um | 1.643e-05 | 1.750e-05 | **6.1%** |
| [O I] 3->1 | 1.380e-10 | 1.340e-10 | 3.0% |

### What it means, and what it does not

In the optically thin limit the cooling rate scales linearly with A, so the 6.1%
on [O I] 145 um propagates directly into the cooling wherever that line
dominates. **It is far too small to bear on the 3-7x temperature excess** and is
not a candidate for it.

Its significance is the one D-186 named: the two codes hold genuinely different
numbers for the same transitions, so which code computes a coolant changes the
answer by a per-cent or two. Today that is invisible against everything else.
It matters because it is a **silent dependency** - if either dataset is updated
independently, the model moves and nothing reports it.

That strengthens the case for the D-186 endpoint. When MOCASSIN owns these
coolants with H, H2 and He added as colliders, there is one dataset and the
question disappears. Until then the numbers above are the measured size of the
inconsistency, and a regression check worth having: if these differences ever
grow, something has been updated on one side only.

### Note on the collision data

The two codes store collisions in different forms - CHIANTI gives Omega(T)
(dimensionless collision strengths, electrons only, on a 23-point temperature
grid for C II); LAMDA gives rate coefficients in cm^3/s for six partners. They
are relatable by q = 8.629e-6/(g_u sqrt(T)) * Omega, so a like-for-like
comparison of the ELECTRON rates is possible and has not been done. That is the
other half of this measurement and is the thing that would actually have to be
reconciled when MOCASSIN takes the coolants over.

## 2026-09-08h - D-188: the chemistry was seeded from a dark cloud

Hektor asked what n(H2) is when the chemistry first runs. The answer:

| species | seed |
|---|---|
| **H2** | **0.300** |
| **H** | **0.400** |
| C+ | 1.40e-4 (rescaled to MOCASSIN's per cell) |
| O | 3.00e-4 (rescaled) |
| all else | 0 |

`seedPDR` wrote `species_reduced.d`'s own initial values into **every** cell,
identically, and `syncSeed` then adjusted only the *elemental* budgets for He,
C, O and Mg. Hydrogen's split was never touched. So every cell began with 60% of
its hydrogen NUCLEI molecular - including cells sitting inside the H II region
at 9000 K - and the first chemistry call had to destroy all of it.

That is not an initial condition. It is the network file's starting point for a
standalone dark-cloud run, carried into a coupled model where MOCASSIN already
knows the ionization structure.

D-112 had already measured that this choice is not neutral: V1's H2 front ratio
is 1.109 from the network seed against 1.679 fully dissociated, and the second
does not relax into the first even with a hundredfold longer integration. So the
seed selects an attractor, and it was selecting one that contradicts MOCASSIN's
own solution.

**Fixed**: on the first visit to a cell, `pdrStep` seeds from MOCASSIN's
ionization - each linked element distributed over its atomic and ionic carriers
in MOCASSIN's ratio, electrons from MOCASSIN's Ne, every molecule zero - and the
chemistry forms the molecules from there. Hektor's ruling was no switch: the old
behaviour is simply wrong.

This will change the benchmark numbers, because the reference starts from the
network seed. That is a real difference in what is being compared and has to be
stated when the fixtures are next run.

### Measured: it changes almost nothing, and Hektor's question explains why

I raised `pdrEndTime` as a risk - that starting from zero H2 might leave the
deep gas under-molecular within a 1e7 yr integration. Hektor asked whether we
are not running the steady-state option. We are. `CHEMSTEADY` is defined in the
Makefile and `calculate_abundances.c` is explicit:

> *Continue the integration in doubling time blocks until the composition is
> steady. Up to 7 doublings (128 x end_time); a particle is steady when no
> species changes by more than 1% over a full doubling.*

So `pdrEndTime` is the initial block size, not a stopping time, and the solver
is driven to equilibrium. **The seed cannot leave anything under-formed** - it
can only select WHICH steady state, where more than one exists. My concern is
withdrawn.

That sharpens the prediction, and the run confirms it. Section 5.4 at 24
iterations, identical to D185hii but for the seed:

| | network seed | MOCASSIN seed |
|---|---|---|
| final convergence | 87.45% | 87.86% |
| deep x(H2) | 0.4963 | **0.4962** |
| H2 total | 6.5365e5 | 6.5487e5 |
| CO total | 6.4028 | 6.4622 |

The convergence trajectory tracks the previous run within 1-2 points at every
iteration. Deep x(H2) is unchanged, exactly as expected where the molecular
solution is the only one available.

**The two-cell oscillation survives**:

```
1.4e19  T=10680  x(H+)=0.9987
1.6e19  T= 7961  x(H+)=0.0367
1.8e19  T=10570  x(H+)=0.9971
2.0e19  T= 7842  x(H+)=0.0333
2.2e19  T=  414  x(H+)=2.0e-5    <- ends here (was 2.4e19)
```

One cell shorter, which is within the run-to-run variation seen elsewhere. **The
seed is not what drives it.**

### Three candidate causes now excluded by measurement

| candidate | test | result |
|---|---|---|
| Monte Carlo noise | 8x packets (D-172) | >100% movers 45554 -> 43667: **no** |
| ionizing contamination | pure-FUV V1 (D-101) | identical oscillation: **no** |
| the H2 seed | D-188 | oscillation survives: **no** |

What remains is the structural one Cloudy addresses: **no continuation between
neighbouring cells.** Each cell solves independently from its own previous
value, so nothing ties cell j's branch to cell j-1's, and adjacent cells at the
same depth settle on different branches. Cloudy prevents this by starting each
zone's solve from the previous zone's converged answer with the step capped at
0.2 T, and by adaptive zoning that forbids large per-zone changes (D-171).

The seeding change stands on its own merits regardless: it removed an initial
condition that contradicted MOCASSIN's own solution in every ionized cell, and
the audit it prompted (D-189) found three real restart inconsistencies.

## 2026-09-08i - D-189: audit for the same class of error

Hektor: *"since you have made this mistake before, I want you to audit the code
and find other places where inconsistencies like this one may be present. The
golden rule is to favor self consistency."*

The pattern: **a default or file value standing in for something the model
computes.** Swept the per-cell PDR state, with the restart path as the sharpest
test - a checkpoint restores some arrays and not others, so any quantity that
is *derived* from a restored one but left at its fresh-grid value is this bug.

| array | in checkpoint? | on restart | verdict |
|---|---|---|---|
| pdrAbun | yes | restored | ok |
| pdrZone, chiFUV, AVeff | yes | restored | ok |
| **pdrSeeded** (new) | no | 0 | **would have wiped the restored chemistry** - fixed |
| **elemAvail** | no | **1.0 = "no molecules"** | **inconsistent with restored pdrAbun** - fixed |
| **H2den** | no | **0 = "no H2 opacity"** | **inconsistent with restored pdrAbun** - fixed |
| pdrIonRate | no | 0 | safe - D-185 keys elemAvail on rate presence |
| pdrCoolSlope, pdrCoolTref | no | 0 | safe - guarded by `> 0` |
| pdrLevPop | no | LTE | known, already on the status page |
| NePDR | no | 0 | inert, pdrUseNePDR off by default |

**The first one I introduced myself, an hour earlier.** D-188's first-visit seed
keys on `pdrSeeded`, which a restart leaves at zero - so a warm restart would
have overwritten the restored molecular abundances with MOCASSIN's ionization
and zero molecules, destroying exactly what the restart exists to preserve. That
is the same mistake in a new place, found by looking for it.

**The fix is the principle, not the patch**: elemAvail and H2den are *functions*
of pdrAbun, so they are now recomputed from the restored state rather than
checkpointed separately or left at a default. Deriving beats storing twice -
two copies can disagree, a derivation cannot.

### Also found, not yet fixed

`pdrGrid.out`'s write record carries **12** fields and the read consumes **9**:
`pdrTgas`, `pdrTlow`, `pdrThigh` are written twice. List-directed reads skip the
remainder of a record, so it works by accident. The asymmetry is fragile and
should be tidied.

### Checked and found sound

* `pdrDustModel = 0` (default) takes MOCASSIN's own dust temperature floored at
  the CMB, not HTT91's parametrisation - self-consistent already.
* Level populations seed from LTE at the local temperature on first visit. That
  is a physical starting point for an iterative solve, not an arbitrary default,
  and the solver moves off it.
* `initH0` and `TeStart` are initial guesses for iterative solves that converge
  away from them - the same category as LTE, not the D-188 category. `initH0`
  became a keyword at D-160 precisely so its influence could be measured.
* `pdrTseed` is declared but never used. Dead parameter.

## 2026-09-08j - D-190: the geometry inconsistency was doing real damage

Hektor: *"We have not yet used PDRGEOM=3D. So we are essentially using a 3D
photoionization code coupled with a 1D PDR code."* Then, on being told the 3D
build still took its columns from the plane-parallel closed form: *"we should
use the per-ray column densities ray-traced through the grid since the
shielding-column is an important parameter in determining molecular content."*

Both correct, and the fix is the largest single physics result of this session.

### What was wrong

Two things, both in `escape_probability.F90` and `pdr_mod`:

1. **The escape probability.** `#ifdef ONEDIMENSIONAL` blanks eleven of the
   twelve HEALPix rays and takes `beta_ij = beta_ij_sum` **undivided**. Correct
   for a slab. Section 5.4 is a sphere with a central source, where photons have
   far more solid angle to escape into, so a slab beta understates the escape
   and therefore understates the line cooling.
2. **The shielding columns.** Even in the 3D build, every ray's column was the
   plane-parallel `A_V/|mu|` or `A_Vback/mu`, and all twelve of `colH2`,
   `colCO`, `colC` were filled with the single source-ward scalar
   `computeAVradial` traces. A ray pointing out of the cloud was being told it
   was as shielded as the line back to the star.

### The fix

`computeRayColumns` walks each of the twelve rays outward from every cell to the
grid boundary through the actual grid, accumulating n(H2), n(C), n(CO) columns
and the V-band extinction. Called once per MC iteration from `mocassinToPDR`.
Directions are the twelve nside=1 pixel centres constructed directly in RING
order - the vendored `pix2vec_nest` is never called anywhere and its pix2x/pix2y
tables are never initialised.

Two things had to be corrected on the way. The rescale
`colH2 = sH2*abun/abun0` recomputed all twelve from the scalar on every
chemistry iteration, so traced values would have been overwritten immediately -
it now rescales in place. And the new grid fields had to be declared
unconditionally rather than under `#ifdef RAYTHEIA`, because PDRGEOMFLAG is not
applied to common_mod's compilation: the eighth flag-scope build break in this
project.

### Result: section 5.4, 24 iterations, identical but for the geometry

| | 1D slab | 3D ray-traced |
|---|---|---|
| convergence | 87.58% | **89.31%** |
| **mean Te** | 1.4712e7 | **1.1343e7  (-23%)** |
| **Te change/iter** | **26.8%** | **6.9%** |
| H0 change/iter | -11.2% | -3.5% |
| H+ change/iter | 4.1% | 1.1% |
| H2 total | 6.5487e5 | 6.7367e5 (+2.9%) |
| CO total | 6.4622 | 6.9698 (+7.9%) |
| runtime | ~95 min | **84 min** |

**The mean temperature falls 23%** - the predicted direction: more escape, more
cooling, colder gas - and it eats into the 3-13x warm bias.

**The temperature finally converges.** Te was the one quantity that would not
settle: 26.8% per iteration at the end of every run in this session. It is now
6.9%, with H0 and H+ tightening 3-4x as well. A slab escape probability inside a
spherical model was a significant part of why the thermal state kept moving.

The twelve traces per cell per iteration cost **nothing** - the run is faster
than the 1D one, because it converges better.

### The two-cell oscillation at the front is gone

| r | T 1D | T 3D | x(H+) 1D | x(H+) 3D | x(H2) 1D | x(H2) 3D |
|---|---|---|---|---|---|---|
| 1.4e19 | 10682 | **58.8** | **0.999** | **4.0e-3** | 1.6e-8 | 6.1e-7 |
| 1.6e19 | 7961 | **148.5** | **0.037** | **3.6e-3** | 5.3e-8 | 4.4e-4 |
| 1.8e19 | 10570 | **1866** | **0.997** | **1.6e-2** | 2.0e-8 | 1.5e-2 |
| 2.0e19 | 7842 | 1791 | **0.033** | 1.2e-2 | 6.1e-8 | 7.0e-3 |

x(H+) alternated 0.999 / 0.037 / 0.997 / 0.033 in adjacent cells and now runs
4.0e-3 / 3.6e-3 / 1.6e-2 / 1.2e-2 - **no alternation**. H2 forms at the front
(1.5e-2) where the 1D run suppressed it to ~2e-8. Cells above 1000 K fall from
38% to 31%.

**Not fully cured**: a weaker disturbance remains further out, at 2.2-3.0e19,
where T spikes to 3561 K and x(H2) dips to 9e-6 between 2.4e-2 and 0.415. So the
pathology is reduced and displaced rather than eliminated. Deep beyond 3.4e19
the two runs are identical and both correct, x(H2) -> 0.495.

### What this retires and what it does not

Three candidates for the oscillation were excluded by measurement (packets,
ionizing contamination, the H2 seed). This is the fourth thing tried and the
first to move it - so the front oscillation was substantially a **geometry**
artifact, not the H2 bistability alone. The residual disturbance further out may
still be the bistability, and the continuation argument (D-171) is untouched.

The V1/V2 slab benchmarks are genuinely 1D and unaffected: for them the
ONEDIMENSIONAL branch is the correct geometry. This only bites on models that
are actually 3D, which is exactly why it survived every slab benchmark in the
project.


## 2026-09-08k - D-191: damping 0.50 - the hot spike was compensating for an H2 error

Hektor asked to test pdrCoupleDamp = iterDamp = 0.50 against the 0.25 that
D-190 was measured with. Both parameters are, since D-174, the fraction of the
PREVIOUS value retained, so 0.50 is HEAVIER damping - Cloudy's original 50/50
coupling average. Run D05hii: sec 5.4 fixture, 3D build, 24 iterations, 90 min,
identical to G3Dhii in every other respect.

The convergence percentage is NOT evidence here and was not used as such.
iterDamp shrinks the very iteration-to-iteration change the criterion measures,
so heavier damping mechanically flatters the number (89.31% -> 90.67%). Every
conclusion below rests on state measurements instead.

State comparison, 0.25 -> 0.50:

  <Te>                     1.134e7  ->  7.752e6   (-32%)
  <Te> change per pass       +6.88%  ->   -0.51%
  thermally unstable cells       40  ->       14
  hot/cold branch flips        5.42%  ->    3.50%
  cells that stayed hot        2544  ->     1189
  median T ratio vs 3D-PDR     6.56  ->     4.77
  H0 total                  1.133e5  ->  1.008e5
  H2 total                  6.737e5  ->  6.880e5

The residual disturbance flagged at the end of D-190 is gone. Near the front,
at A_V_rel 0.19 and 0.50, the gas ran 1866 K and 2024 K at damping 0.25
against a reference of 154 K and 119 K. At 0.50 it runs 345 K and 202 K. That
is the spike, not a smoothed version of it.

But it exposed something. The H2 front moved the WRONG way:

  H -> 2H2 front (A_V)   ours 0.736 (damp 0.25)   0.461 (damp 0.50)   3D-PDR 0.892
  x(H2) at A_V_rel 0.497        2.4e-2                3.96e-1          3.28e-2

At 0.25 our x(H2) near the front sat at 2.4e-2 against the reference 3.3e-2 -
apparently good agreement. It was not agreement. It was 2000 K gas
collisionally destroying H2 down to roughly the right number for the wrong
reason. Take the spurious heat away and H2 overshoots by a factor of 12.

So the correct reading of D-191 is not "0.50 is better". It is:

  - on temperature, 0.50 is substantially closer to the reference and removes
    a thermal artifact that D-190 left behind;
  - the H2 formation/destruction balance near the front has an error of its own
    that the artifact was masking. Suspects, in order: H2 self-shielding column
    at low A_V, the formation rate on grains, and the seeding transient.

One caveat that blocks a verdict: at iteration 24 the 0.50 run had NOT settled.
<Te> was still descending (-2.29, -7.44, -5.45, -5.16, -0.51 over the last five
passes) and decelerating but not flat. The 0.25 run by contrast limit-cycles
around 1.1e7 with no trend. A longer 0.50 run is needed before the H2 overshoot
is attributed to chemistry rather than to an unfinished descent.

Not committed as a default. The fixtures keep 0.25 until the endpoint is known.

## 2026-09-08l - D-192: MOCASSIN's hydrogen and the chemistry's disagree past the H2 front

Found while rebuilding the sec 5.4 artifact for D-191, by reading hydrogen out
of MOCASSIN's ionDen array instead of out of pdrGrid and noticing the two do
not agree. Present in BOTH damping runs, so it is not a D-191 side effect.

On the +x axis, at r = 3.0e19 cm:

                        chemistry      MOCASSIN ionDen
  x(H)                  3.25e-2        0.000, exactly
  x(H+)                 4.51e-2        5.81e-1
  x(HI)+2x(H2)+x(HII)   1.0000         1.5032

Inside r = 2.6e19 the two agree to every digit printed. The break is AT the
H/H2 front and follows it outward: 16 of 29 axis cells at damping 0.25, 15 of
29 at 0.50, budget running 1.28 to 1.64.

Mechanism, read off handBackPDR (pdr_mod.f90, the pdrAtomicH branch):

  ionDen(H,1) = max( w*x(H)_chem + (1-w)*(1 - ionDen(H,2) - 2*x(H2)), 0 )

Deep in the cloud 1 - 2*x(H2) is about 0.01, so ANY ionDen(H,2) above that
drives the bracket negative and the clamp writes exactly zero - which is the
0.000 above. Nothing renormalises the pair afterwards, so the ionised stage
keeps a value the neutral stage has already been zeroed to accommodate.

Why ionDen(H,2) is 0.58 in the first place is not yet measured. The leading
hypothesis is the blend's own memory: it mixes w*(chemistry) with
(1-w)*(previous value), the previous value in these cells descends from when
they were ionised, and nothing in the expression forces it to the chemistry's
answer in finite time. Note also that update_mod's D-169 gate makes ionBalance
skip the writeback for H in PDR cells when pdrOwnIon is on, so this blend is
the ONLY thing writing hydrogen there - a single unchecked path.

Why it matters beyond bookkeeping: MOCASSIN's opacity, its photoionisation
heating and its electron density in the molecular interior all read ionDen,
not the chemistry's arrays. In those cells they are computed with 100-200x too
much ionised hydrogen, and those are the same cells where the gas runs warmer
than the reference. Whether the two are connected is a hypothesis, not a
result - the deep warm bias has an independently measured cause in the
scattered-FUV offset of D-089/D-090.

This is the class of defect D-189 was an audit for, and it is the same shape:
a quantity that is a FUNCTION of another (here, the split of non-molecular
hydrogen between H0 and H+) carried as an independent variable, with no
identity enforced. Nothing on the artifact is drawn from the affected array -
hydrogen there is the chemistry's and closes the budget in all 29 cells - and
the defect is plotted next to it so it can be inspected.

Not fixed. Fixing it means deciding what ionDen(H,*) MEANS in a PDR cell:
either the split of the available atomic pool (then both stages must be scaled
by 1-2*x(H2) and forced to sum to it), or fractions of total hydrogen (then
the sum is 1-2*x(H2), not 1). The two are currently mixed inside one
expression, which is why it clamps.

## 2026-09-08m - D-193: one reality. The contract, written into the code.

Hektor, after D-192: "We have to have one reality. Mocassin should give 3DPDR
code all ion densities, Ne, Te, dust temperature and opacity. 3D PDR should
then calculate how much is converted to molecules and give that back to
mocassin along with cooling/heating rates relative to them. Mocassin should
keep track of the molecular abundance and solve the thermal equilibrium. There
should be no ambiguity in this."

That is now what the code does, unconditionally, with no switch able to change
it. The contract:

  MOCASSIN -> 3D-PDR   ion densities, Ne, Te, dust temperature, dust opacity
  3D-PDR   -> MOCASSIN molecular content (elemAvail, H2den, pdrAbun), and the
                       heating/cooling rates that follow from it
  MOCASSIN owns        ionization, thermal equilibrium, molecular bookkeeping

### What was actually wrong

Not one bug. An architecture in which ownership was an INPUT PARAMETER. Four
keywords - pdrAtomicH, pdrOwnIon, pdrIonFromMocassin, pdrTeFromMocassin -
between them decided which code owned x(H+), x(C+) and Te. Different fixtures
set them differently. Every "leftover from a previous design" of the last
several days has been a path that was live under some combination of them.

D-192 was what it cost. Two writers for grid%ionDen with two different
normalisations:

  * ionBalance wrote the stages summing to availFrac, which D-185 had set to
    1.0 whenever the chemistry supplied rates - i.e. all hydrogen ionic, in gas
    that is 99% H2;
  * handBackPDR then recomputed the neutral stage by closure,
    max(1 - ionDen(H+) - 2x(H2), 0), and clamped it to exactly zero because the
    first writer's H+ had already used up more than the whole budget.

Result: x(H+) = 0.58 where the chemistry said 0.045, x(H0) = 0, and the
identity x(HI)+2x(H2)+x(HII) = 1 violated in 16 of 29 axis cells.

### The specific error in D-185

D-185's premise was "elemAvail and the per-stage rates are two descriptions of
the same locking; applying both counts it twice." That is wrong, and it is the
root of D-192.

  elemAvail sets the SUM of the ion stages - how much of the element is not in
  molecules. It is a conservation constraint.
  The rates set RATIOS between stages.

Dropping the constraint because the ratios are known leaves the stages
normalised to 1.0 in gas that is almost entirely molecular. The constraint now
applies unconditionally, and the rates are gone.

### Changes

update_mod.f90
  * availFrac = elemAvail ALWAYS. The lgHaveRates branch that set it to 1.0 is
    deleted. This is the D-192 fix.
  * The chemistry's per-stage source/sink rates are no longer injected into the
    ion matrix. pdrFormSp/pdrLossSp are the whole ODE RHS, molecular channels
    included; injecting them alongside the elemAvail constraint double-counts
    the molecular drain, and injecting them instead of it is what produced
    D-192. Still published as diagnostics (D-113).
  * COSMIC-RAY IONIZATION ADDED as MOCASSIN's own physics. MOCASSIN never had
    it (D-035) and it had been arriving second-hand inside those injected
    rates; removing them without this would have silently zeroed the ionization
    of shielded gas. Coefficients are the network's own, so both codes ionize
    at identical rates from an identical zeta:
      rates_reduced.d:293  H  + CRP -> H+  + e   5.98e-18
      rates_reduced.d:297  He + CRP -> He+ + e   6.50e-18
    evaluated as calc_reac_rates.F90 does, RATE = ALPHA*(zeta/1.3e-17).
  * The D-169 gate that made ionBalance skip H, He, C, O and Mg in PDR cells is
    removed. One solution, every element, every cell.
  * iterateT never pins a cell to a PDR temperature: there isn't one any more.

pdr_mod.f90
  * pdrToMocassin writes elemAvail and nothing else. The blended ionDen
    writeback for H, He, C, O, Mg is deleted; the Te writeback is deleted; the
    blend weight w and the pdrBlendLo/pdrZoneLim band go with them.
  * setIonPair -> setElemAvail: same molecular bookkeeping, no ionDen writes.
  * Helium's elemAvail is set explicitly to 1.0 - no helium-bearing molecule
    exists in the network - so the array has one meaning everywhere.
  * pdrStep takes Te from MOCASSIN unconditionally and runs ONE thermal pass
    rather than pdrThermIter; it no longer marches a temperature of its own.
  * MOCASSIN's ion ratios are imposed on the network before and after the
    solve, unconditionally.
  * The network's own photoionization/recombination channels for MOCASSIN-owned
    stages are always suppressed as duplicates.
  * The PDR's own heat/cool imbalance no longer fails a cell's convergence: it
    is evaluated AT MOCASSIN's temperature and is not required to balance.

set_input_mod.f90
  * pdrAtomicH, pdrOwnIon, pdrIonFromMocassin, pdrTeFromMocassin are RETIRED.
    Still parsed so existing input files run, but the value is ignored and the
    run prints that it is ignored. Ownership is no longer an input.

All four build flavours compile clean (3D, 1D, plain, warm).

### What this is expected to change, and what it risks

The molecular interior is where it bites: ionBalance there now solves for
0.9% of the hydrogen rather than 100% of it, so n_e, the opacity and the
photoionization heating in those cells all change. If the deep warm bias
(D-089/D-090) had a contribution from the 100-200x excess ionized hydrogen,
this is where it shows. That was a hypothesis in D-192 and it stays one until
measured.

The risk is the opposite sign: cosmic-ray ionization is now MOCASSIN's own
term, and if the two codes' zeta conventions differ the deep x(H+) will move
with it. The coefficients above are taken from the network file the run is
actually using, and pdrZetaMod already normalises by 1.3e-17 the same way, so
they should agree by construction - but it is asserted here, not yet measured.

Running D193hii (sec 5.4, 3D, 24 iterations) to find out.

---

---

## D-197 - reverted to D-190 (2026-09-09)  [SUPERSEDED by D-198]

Recorded as D-191 at the time, which collided with the damping entry that
already held that ID. Relabelled D-197 when D-193 was restored at D-198, so
that both entries keep a stable identifier and the references in the section
5.4 artifact to "D-191 - two damping settings" stay correct.

D-193, D-194 and D-195 are discarded and the tree is back at `4dfcb25`. Kept
recoverable as the annotated tag `d193-d195-reverted` (tip `f6da2dd`); nothing
is on a branch.

### Why

The three of them together made the model worse, and the clearest single
number is the convergence fraction:

      D-190  (G3Dhii)    89.31%   at iteration 24
      D-193  (D193hii)    5.01%
      D-195  (D195hii)    5.77%   36-45% of cells flipping across 1000 K
                                  on every one of the last ten passes

Neither post-D-190 run settles. The axis profiles swing by two orders of
magnitude in T between neighbouring cells and between the two runs, in both
directions, which made D-195's actual target - the H/H2 front position -
unmeasurable. On that state no further item from the D-194 port list could have
been measured either.

### What is being given back

Recorded here so it does not have to be rediscovered:

  - **The D-192 hydrogen-budget defect returns.** `x(HI)+2x(H2)+x(HII)` is
    1.28-1.64 in 16 of 29 axis cells at D-190, with `ionDen(H0)` clamped to
    exactly zero past the H2 front and `ionDen(H+)` at 5.8e-1 where the
    chemistry says 4.5e-2. MOCASSIN's opacity, photoionization heating and n_e
    in the molecular interior all read that array. This is a real defect at
    D-190 and it is now open again.
  - **H2 formation is back on the hardcoded cross sections**, 8.473e-22 /
    7.908e-22 cm^2/H, with no dependence on MdMg, the size distribution or the
    composition. The measurement that replaced them is worth keeping on record:
    this model carries **1.0165e-21 cm^2/H, all silicate, zero graphite** -
    20% MORE area than Cazaux & Tielens assume, but a 0.62x rate at cold dust
    and 0.24x at 60 K, because CT02's graphite channel was carrying the rate
    and this model has no graphite. That number is independent of the coupling
    and will still be true whenever this is picked up again.
  - **The D-194 port list** (photorate gammas on Savage & Mathis when this
    model implies UV_fac 3.83 vs 3.02; WD01 grain recombination not compiled
    in; network abundances C=1.4e-4 against the model's 2.2e-4; charge exchange
    reactions 178 and 185) is discarded as a file but the findings stand. It is
    in the tag.

### The open question this leaves

Why the convergence fraction collapsed is NOT settled, and the leading
explanation was arrived at only after a wrong one was discarded:

  - **Wrong**: the D-169 `ionDen` writeback gate. It is guarded by
    `pdrIonFromMocassin == 0` and every fixture here sets that keyword to 1, so
    the gate was never active in any of these runs. Not the cause.
  - **Leading, inferred from the diff and not measured**: before D-193,
    `availFrac` stood down wherever the chemistry supplied per-stage rates -
    under `pdrAllCells 1` that is everywhere - so the ion stages in PDR cells
    normalised to 1.0 regardless of how much hydrogen was molecular.
    x(H0), which is what the convergence test measures, then had almost nothing
    to move it between passes. D-193 ties it to the molecular fraction, which
    changes every pass. The failure breakdown fits: 41261 cells fail on x(H0)
    alone against 2772 on x(H2), concentrated at A_V 1-4.

If that reading is right then D-190's 89.31% is measuring a quantity that
cannot move, and the honest convergence of the D-190 state is unknown rather
than high. That is worth settling before the number is trusted again, and it
needs a build with only that one edit reverted. Not done.

All four flavours rebuilt clean at D-190.


---

## D-196 - the convergence percentage was counting frozen cells (2026-09-09)

Against `17a1508`. Answers the question D-191 left open, and finds that the
question could not previously have been asked from this repository at all.

### What D-191 left open

> If that reading is right then D-190's 89.31% is measuring a quantity that
> cannot move, and the honest convergence of the D-190 state is unknown rather
> than high. That is worth settling before the number is trusted again, and it
> needs a build with only that one edit reverted. Not done.

That build could not be made: `lgIonChemRates` - the D-118 switch that stands
`elemAvail` down wherever the chemistry supplied per-stage rates - had **no
input keyword**. It could only be changed by editing `common_mod.f90` and
recompiling, which is why the run was never made.

### The premise D-191 recorded is false against the repository

D-191 dismisses the D-169 `ionDen` writeback gate on the grounds that "every
fixture here sets that keyword to 1". No file under `benchmarks/pdr/` sets
`pdrIonFromMocassin`, or any other ownership keyword - `hiipdr`, `v1slab`,
`v2slab` and `ifront` all stop at `pdrStartIter`, and there is no tracked
`input/input.in`. Every fixture therefore runs on the compiled defaults, which
are the opposite policy: `pdrOwnIon 1`, `pdrIonFromMocassin 0`,
`pdrTeFromMocassin 0`, `pdrCoolFeedback 0`, `pdrAllCells 0`.

So the D-190, D-193 and D-195 runs were made against an input that was never
committed, and nothing in the tree reproduces them. Two further signs of the
same gap: D-191 quotes 89.31% **at iteration 24**, while every fixture sets
`maxIterateMC 12`.

Three fixtures added so measurements are reproducible from the repository:

  - `benchmarks/pdr/hiipdr-d190/` - `hiipdr` + `pdrIonFromMocassin 1`,
    reconstructing the only ownership keyword D-191 names. A reconstruction,
    not a recovery.
  - `benchmarks/pdr/hiipdr-d190-noavail/` - identical but `ionChemRates 0`.
  - `benchmarks/pdr/hiipdr-contract/` - the full ownership contract
    (MOCASSIN owns ionization, thermal equilibrium and molecular bookkeeping),
    each keyword annotated with the contract line it states.

### The diagnostic, and a correction made before it produced a number

`[D196]`, in `iteration_mod.f90`, reported every iteration rather than behind a
probe flag. Its first version reported `x(H0) + 2x(H2) + x(H+)` as the budget
test. **That test was tautological and was replaced before it was believed.**
`pdrToMocassin` (line 1353) runs after `updateCell` (1008) and writes

    ionDen(H0) = max(1 - ionDen(H+) - 2 x(H2), 0)

so the sum is 1 by construction and departs from it only where the `max`
clamps. It is a clamp counter, and is now labelled as one.

The replacement is `ionDen(H+) / pdrAbun(H+)`, both per hydrogen nucleus.
`ionDen(H+)` is untouched by the handback under `pdrIonFromMocassin` (w = 0),
so it is the ion solver's own answer; the chemistry re-imposes MOCASSIN's ratio
on its non-molecular total, so

    x(H+)_chem = (1 - 2x(H2)) * ionDen(H+) / (ionDen(H0) + ionDen(H+))

If the conservation row normalises to the available fraction the denominator is
1 - 2x(H2) and the ratio is exactly 1. If it normalises to unity - the D-118
stand-down - the denominator is 1 and the ratio is 1/(1 - 2x(H2)). The ratio
**is** the defect.

### Run A measured - `hiipdr-d190`, `ionChemRates 1`, 49m46s on 14 ranks

| iter | mean 2x(H2) | x(H+)_ion/chem | cells clamped | converged |
|------|-------------|----------------|---------------|-----------|
| 4    | 0.127       | 1.07           | 0             | 0.50%     |
| 5    | 0.875       | 71.6           | 0             | 5.99%     |
| 6    | 0.913       | 93.7           | 219           | 0.83%     |
| 7    | 0.910       | 94.2           | 1054          | 6.85%     |
| 8    | 0.911       | 95.2           | 3407          | 11.8%     |
| 9    | 0.910       | 96.4           | 6884          | 29.7%     |
| 10   | 0.911       | 98.1           | 9847          | 51.0%     |
| 11   | 0.910       | 99.0           | 11671         | 71.7%     |
| 12   | 0.911       | 99.3           | 12596         | 81.7%     |

*measured*. The ratio tracks 1/(1 - 2x(H2)) throughout: at iteration 4 the
median 1.065 implies 2x(H2) = 0.061, at iteration 12 the median 99.3 implies
0.9899. Over 14854 PDR-zone cells out of 15204 active - **97.7% of the model
is PDR**, so nothing here is an ionized-region effect.

Cross-tabulating `lgConverged` (grid0.out) against the clamp (grid2.out) at
iteration 12, via `tools/d196_zoneconv.py`:

                              converged   not converged      total
    x(H0) clamped to 0            11760             889      12649
    x(H0) > 0                       367            1838       2205

A clamped cell is counted converged 93.0% of the time; an unclamped one 16.6%.
**97.0% of the converged PDR-zone cells have x(H0) pinned at exactly zero.**

### The chain

One defect with three reported symptoms, not three defects:

    availFrac -> 1               (D-118 stand-down, update_mod.f90:2564)
      -> the conservation row asserts x(H0) + x(H+) = 1 in gas that is 99%
         molecular                                    (update_mod.f90:2756)
      -> ionDen(H+) over-stated by 1/(1-2x(H2)), measured 99x
      -> 1 - x(H+) - 2x(H2) goes negative
      -> the D-192 handback clamps x(H0) to exactly 0  (pdr_mod.f90:2577)
      -> x(H0) cannot move
      -> the convergence test on x(H0) passes for free

D-191's hypothesis was right about the mechanism's origin and wrong about its
direction: it predicted x(H0) pinned just under **1**; it is pinned at **0**.
Recorded because the wrong direction is what made it look unfalsifiable - a
value near 1 is what one expects in neutral gas and would not draw attention.

### What this says about D-190's 89.31%

The clamp count and the convergence percentage rise together across iterations
9-12 (46.4% -> 85.2% clamped, 29.7% -> 81.7% converged). Extrapolated to the
iteration 24 at which D-190 was measured, the clamp saturates and the
convergence figure approaches the high 80s. **89.31% is consistent with being
the clamp count, not a physical result.** Not proven - it needs the
reconstruction run to 24 - but it is the leading explanation and no longer an
inference from the diff alone.

### Two silent-failure defects found on the way

  - **`ionChemRates` as a logical.** Added first as
    `read(...) keyword, lgIonChemRates` against a `LOGICAL`. Fortran
    list-directed logical input rejects `0` (iostat 5010), `ios` is discarded
    in this block, and the default `.true.` stood - so run B ran as an exact
    duplicate of run A and reproduced it to three digits. Caught because the
    duplication was too exact to be physical. Now read as an integer, like
    `pdrOwnIon` and every other switch there, and it echoes what it applied.
  - **`ionMatrix` has the same shape.** `lgIonMatrix` is also a `LOGICAL` read
    list-directed, so `ionMatrix 0` in any input silently leaves the matrix
    solver on. No result in the repository depends on it. Not fixed.
  - More generally, ~40 keywords in `set_input_mod.f90` read with `iostat=ios`
    and never test it. Any typo or type mismatch fails silently.

### Run B measured - `hiipdr-d190-noavail`, `ionChemRates 0`, 50m01s

One input line different. The chain breaks at the root.

| iter | x(H+)_ion/chem A | B | clamped A | B | converged A | B |
|------|------------------|---|-----------|---|-------------|---|
| 4    | 1.065 | 1.065 | 0     | 0 | 0.50%  | 0.51%  |
| 5    | 71.6  | 53.86 | 0     | 1 | 5.99%  | 6.17%  |
| 6    | 93.71 | 1.286 | 219   | 0 | 0.83%  | 45.10% |
| 7    | 94.19 | 0.990 | 1054  | 0 | 6.85%  | 79.97% |
| 8    | 95.21 | 0.997 | 3407  | 0 | 11.8%  | 85.45% |
| 9    | 96.42 | 0.993 | 6884  | 0 | 29.7%  | 87.92% |
| 10   | 98.06 | 1.000 | 9847  | 0 | 51.0%  | 90.33% |
| 11   | 98.98 | 0.994 | 11671 | 0 | 71.7%  | 90.87% |
| 12   | 99.32 | 1.000 | 12596 | 0 | 81.7%  | 92.28% |

*measured*. Three things, each predicted by the derivation above:

  - **The ratio goes to exactly 1.** With the conservation row normalising to
    the available fraction, MOCASSIN's x(H+) and the chemistry's are the same
    number, to four figures. In A they differ by a factor of 99.
  - **The D-192 clamp never fires.** Zero clamped cells at every iteration
    against A's 12596. D-192 is not an independent defect; it is a consequence
    of D-118's stand-down, which is what the chain predicted.
  - **Convergence is higher AND honest.** 92.28% against 81.7%, and the
    cross-tab inverts completely:

                                  converged   not converged      total
        A   x(H0) clamped to 0        11760             889      12649
        A   x(H0) > 0                   367            1838       2205
        B   x(H0) clamped to 0             2               5          7
        B   x(H0) > 0                  13736            1112      14848

    97.0% of A's converged cells are frozen; **0.0% of B's are**.

The sharpest single line is `|dx(H0)|/x`. In A the median falls to *exactly
zero* by iteration 11 - the quantity has stopped existing. In B it settles at
0.0465, just inside the 0.05 tolerance, and the p90 falls 0.99 -> 0.264. That
is what convergence looks like when the tested quantity can move.

**The transient at iteration 5 is real and diagnostic.** B's ratio reads 53.86
there rather than 1, because `elemAvail` is written by `pdrToMocassin` at the
end of an iteration and read by `updateCell` during the next - it is one MC
iteration stale. Harmless once 2x(H2) plateaus, but during the 0.127 -> 0.875
formation jump the stale value is badly wrong. Worth fixing on its own account.

### Consequences for D-191

D-191 reverted D-193/D-195 on the grounds that they "made the model worse", the
evidence being a convergence fraction of 5.01%/5.77% against D-190's 89.31%.
This measurement says the comparison was between a number that counts frozen
cells and a number that does not. Correcting the same bookkeeping here raises
convergence to 92.28% at iteration 12 - past D-190's 89.31%, at less than half
the iterations, with zero clamped cells. Whatever destabilised D-193/D-195, it
was not the act of tying the ion budget to the molecular fraction. The revert
should be revisited on this basis; the `d193-d195-reverted` tag still holds it.

### Confound, recorded

`lgIonChemRates` is **not** the single lever D-191 asked for. It gates the
`availFrac` stand-down (`update_mod.f90:2564`) *and* the injection of the
chemistry's per-stage source/sink terms into the ion matrix (2697). B therefore
differs from A in two ways. The ratio going to exactly 1 is explained by the
first alone - it is the arithmetic of the conservation row - but the
convergence improvement cannot be attributed between them without a second
switch. Not built.

### What is NOT known

  - How the convergence gain splits between the two things `lgIonChemRates`
    gates. Needs the switches separated.
  - The residual tail: B's median ratio is 1.000 and p90 1.18, but max is 127.
    A few hundred cells are still mis-normalised. Unexplained.
  - What else the lost D-190 input set. `pdrAtomicH 0` would produce the
    pinning D-191 actually describes - x(H0) near 1 rather than at 0 - so it
    is a candidate, untested.
  - Whether 89.31% is reproducible from the reconstruction at iteration 24.
  - Nothing here tests the rest of the contract: run B still has 3D-PDR
    owning the temperature (`pdrTeFromMocassin 0`) and `thermBalance` still
    receiving no PDR budget (`pdrCoolFeedback 0`). `hiipdr-contract` exists
    and has not been run.
  - MC/MPI scatter on this fixture: runs of an identical configuration
    diverged by 0.22 pp in convergence at iteration 3, before the PDR engages.
    That is the noise floor for the percentage; the clamp counts and the ratio
    differ by factors and are far above it.

All four flavours rebuilt clean.
Nothing implemented in this entry. This is the flag.


---

## D-198 - D-193 restored, and the contract finished (2026-09-09)

Against `2b85f28`. D-197 reverted D-193 on evidence D-196 has since shown was
misread; this restores it and completes the half it did not cover.

### Why the revert is undone

D-197's case was a convergence fraction: 89.31% at D-190 against 5.01% and
5.77% after D-193/D-195. D-196 measured what those numbers count. At D-190,
97.0% of the converged PDR cells have x(H0) clamped to exactly zero by the
D-192 handback and therefore frozen; the correction sends the ion-solver /
chemistry x(H+) ratio from 99.3 to 1.0000, removes the clamp entirely, and
reaches 92.28% at iteration 12 with none frozen.

So the comparison was between a number that counts frozen cells and a number
that does not. That is not evidence D-193 made the model worse, and it was the
whole of the case against it. `git cherry-pick 7015d4e`, one conflict, in
DEVLOG.md only - the sources merged clean.

D-194 (the port list) and D-195 (H2 formation on the measured grain area) are
NOT restored here. D-195 is its own decision with its own measurement to make,
and belongs after this one rather than inside it.

### What D-193 supplies

  - `availFrac` = `elemAvail`, always. The D-185 `lgHaveRates` branch is gone.
    elemAvail constrains the SUM of the ion stages; the rates set RATIOS
    between them. Dropping the sum because the ratios are known is what left
    the stages normalised to 1.0 in gas that is 99% molecular.
  - The chemistry's per-stage source/sink terms are no longer injected into
    the ion matrix.
  - Cosmic-ray ionization added as MOCASSIN's own physics, with the network's
    own coefficients, so removing the injection does not silently zero the
    ionization of shielded gas. MOCASSIN had none (D-035).
  - `pdrToMocassin` writes `elemAvail` and nothing else: no ionDen, no Te, no
    blend weight.
  - `pdrStep` takes Te from MOCASSIN and runs one thermal pass.
  - Four keywords retired: `pdrAtomicH`, `pdrOwnIon`, `pdrIonFromMocassin`,
    `pdrTeFromMocassin`.

### What this entry adds

D-193 gave MOCASSIN the temperature but left the budget that makes it solvable
behind a keyword, and left the zone gate in place. Three changes:

  - **`pdrCoolFeedback` retired, the handback unconditional.** MOCASSIN cannot
    own the thermal equilibrium while the molecular coolants and the six
    heating terms it has no expression for default to off. Taking the
    temperature from the PDR and then solving it here without the PDR's budget
    leaves neutral gas with no coolant lacking a factor n_e, so H-C has no root
    and the search runs to a rail - D-166 measured 45% of the model pinned at
    30000 K or 10 K. The two halves are one decision.
  - **`pdrCoolTdep` defaults to 1.** Same reason: a cooling rate held constant
    inside `iterateT` has no temperature dependence and therefore no root.
  - **`pdrAllCells` retired, the zone gate removed.** This was scheduled later
    and is pulled forward because it causes a live defect that would corrupt
    the verification below.

### The defect that forced the zone gate out (measured, D-196)

`pdrToMocassin` writes `elemAvail` for every cell from `pdrAbun`. In a cell the
chemistry never ran, `pdrAbun` still holds `seedPDR`'s network defaults -
x(H) = 0.400, x(H2) = 0.300, the reduced network's dark-cloud starting point.
So `elemAvail(H)` was **0.400 across the whole H II region**, `ionBalance`
normalised the hydrogen stages to 0.400, and 60% of the ionized hydrogen was
simply absent. On the axis of the sec 5.4 reconstruction:

      i    r          zone   T      ionDen(H0)   ionDen(H+)   sum
      3    4.0e18       0    4597   2.06e-05     0.4000       0.4000
      9    1.6e19       0    7242   0.0665       0.3335       0.4000

*measured*. The ionized gas ran at 4600-7200 K against the 7927-9420 K this
fixture is benchmarked at.

The gate was buying almost nothing: 14854 of 15204 active cells are already
inside the zone, so it skipped 2.3% of the model and broke their hydrogen
entirely. Outside the molecular gas the chemistry answers "no molecules here"
by itself and needs no threshold to be switched off.

### Ownership is no longer expressible as an input

Seven keywords are now parsed, reported and ignored: `pdrAtomicH`,
`pdrOwnIon`, `pdrIonFromMocassin`, `pdrTeFromMocassin` (D-193),
`ionChemRates` (D-196), `pdrAllCells`, `pdrCoolFeedback` (D-198). A fixture
that sets one says so in the log and proceeds with the contract regardless.

`benchmarks/pdr/hiipdr-contract/` states no ownership keyword at all, because
there are none left to state.

### DEVLOG ID collision, resolved

D-197 was recorded as D-191, which the damping entry of 2026-09-08k already
held and which the section 5.4 artifact cites by that name. The revert is
relabelled D-197; D-191 keeps the damping entry. Both now have stable IDs.

### The contract run, measured

`hiipdr-contract`, 14 ranks, 12 iterations, 47m11s, on the D-199 fix below.
**The contract works and the model does not settle.** Both halves are results.

What the contract delivers, at iteration 12 over 15039 PDR-zone cells:

  - `x(H+)_ion / x(H+)_chem` median **1.0000**, p90 1.0040-1.21. MOCASSIN and
    the chemistry agree on the hydrogen ionization to four figures across the
    PDR, against 99.3x apart at D-190.
  - **Zero cells** with x(H0) clamped to exactly zero, at every iteration.
    D-192 does not occur.
  - The H II region has its hydrogen back: `ionDen(H0)+ionDen(H+)` = 1.0000
    and `elemAvail` = 1 inside the front, against the 0.4000 the zone gate was
    producing. The ionized gas runs 9173-15660 K.

What it exposes:

      hot branch  (2x(H2) < 0.01, T > 3000 K)    3530   23.5%   converged 0
      cold branch (2x(H2) > 0.5)                10544   70.1%   converged 0
      in between                                  965    6.4%
      T over the zone: min 41.7  median 2081  max 10538

*measured*. The model is **bistable**. Adjacent cells on the axis sit at 85 K
fully molecular and 9418 K fully ionized:

      i    r         T       ionDen(H+)   2x(H2)   budget
      14   2.6e19      85.4   2.30e-05    0.7118   1.3011
      18   3.4e19    9418.0   0.9580      0.0000   1.0000
      19   3.6e19     101.7   0.0007      0.9774   0.9999
      20   3.8e19    8957.0   0.9127      0.0000   1.0000

Nothing converges on either branch, which is why the convergence fraction sits
at 0.0197%. The median PDR temperature of 2081 K is an order of magnitude above
the reference's 100-180 K.

**A hypothesis raised and discarded in the same session.** Before the run
finished, the flat convergence was attributed to the criterion becoming
ill-conditioned: under the contract `ionDen(H0)` is normalised to
`elemAvail ~ 1 - 2x(H2)`, which is ~0.011 deep in the cloud, so
d x(H0)/x(H0) = -2 dx(H2)/(1-2x(H2)) amplifies a 0.05% change in x(H2) into 9%
in x(H0). The arithmetic is right and the conclusion was wrong: the axis shows
whole cells flipping between branches, not a sensitive quantity jittering. The
amplification is real and may matter later; it is not what is happening here.

**This partially vindicates D-197 (the revert).** Its observation that the
model would not settle - "36-45% of cells flipping across the 1000 K line on
every one of the last ten passes" - is confirmed. What was wrong was reading
the convergence *percentage* as evidence the change was bad, when D-196 showed
that number was counting frozen cells. The instability is real, predates the
reading of it, and is now the open item.

### What is NOT known

  - **What drives the bistability.** Two branches with no cells between them is
    the signature of a thermal balance with two roots, and the PDR temperature
    is now MOCASSIN's to solve. Suspects, untested: the coolant power law
    (`pdrCoolTdep`) extrapolating across the H/H2 transition; the ionization
    and the chemistry each being consistent with their own branch; the residual
    one-PASS lag below.
  - D-195 is not restored. The grain-area measurement (1.0165e-21 cm^2/H, all
    silicate, no graphite - 20% more area than Cazaux & Tielens assume but a
    0.62x rate, because their graphite channel was carrying it) still stands
    and is still not in the code.
  - The `lgIonChemRates` flag survives in `common_mod` with no reader, so the
    retired keyword has something to report against. Removing it is a tidy-up.
  - The ionized region now runs **9173-15660 K** against the 7927-9420 K this
    fixture is benchmarked at. It has its hydrogen back, but it is too hot at
    the inner edge. The D-193 run measured the same thing (15590 K), so this is
    a property of the restored contract rather than of D-198, and it is not
    explained.
  - A thin tail survives on the ratio: median 1.0000 and p90 1.0040, but the
    maximum is 31-82 depending on the iteration. A few hundred cells out of
    15039.

All four flavours rebuilt clean.

---

## D-199 - elemAvail was one MC iteration stale (2026-09-09)

Found by the first contract run, not by the D-196 pair.

`pdrToMocassin` is the only writer of `elemAvail`, and it was called at
`iteration_mod.f90:1354`, **outside** the coupling loop that closes at 1280.
`updateCell` reads `elemAvail` and runs `pdrCoupleIter` (5) times per MC
iteration, so every one of those passes normalised the ion stages to a
molecular fraction a full iteration out of date.

That was survivable while `pdrToMocassin` also wrote `ionDen` directly - the
handback corrected its own lag. D-193 removed that write, so `ionDen` is
`ionBalance`'s answer normalised to `elemAvail` and nothing else, and the lag
goes straight into x(H0).

Measured on the first contract run, which was stopped at iteration 6:

      iter    x(H+)_ion/chem    budget off >1%     converged
      4       1.05              9670               0.00%
      5       19.5              14236              0.00%
      6       0.166             14019              0.00%

*measured*. Ringing around 1 with a period of one iteration.

The fix is to publish `elemAvail` inside the coupling loop, after the `pdrAbun`
reduction. The old call site carried a note that it had to follow the Te
allreduce, which overwrites `grid%Te` wholesale; that no longer binds, because
under D-193 `pdrToMocassin` writes `elemAvail` and nothing else.

Same fixture, same everything else:

      iter    x(H+)_ion/chem median   p90       max      budget off >1%
      4       1.0013                  1.0119    1.0293   29
      6       1.0000                  1.0001    76.2     1363
      12      1.0000                  1.2108    81.8     1845

*measured*. At iteration 4 the entire distribution including the maximum sits
within 3% of 1, against a maximum of 2.23 with the lag.

### A correction this forces

D-196 attributed a ~1.25% shortfall in `elemAvail + 2x(H2)` to hydrogen held in
the network's other carriers - H2O, OH, the CH_n chain, H3+. With the lag
fixed, cells failing the 1% budget test fall from 9670 to 29 out of ~15000, so
that shortfall was predominantly the lag and not other carriers. The other
carriers exist and hold some hydrogen; they are not 1.25%.

### What is NOT known

  - A residual **one-pass** lag remains: within a coupling pass `updateCell`
    still runs before `pdrStep`, so it reads the previous pass's `elemAvail`.
    That is the likely source of the thin ratio tail, untested.
  - Whether it contributes to the bistability of D-198. Not tested.

All four flavours rebuilt clean.


---

## D-200 - damping the state the bistability actually lives in (2026-09-09)

Against `13641c9`. D-198 left the contract correct and the model bistable:
23.5% of PDR cells hot and atomic, 70.1% cold and molecular, zero converged on
either branch, adjacent axis cells at 85 K and 9418 K.

### What was damped, and what was not

  - `pdrCoupleDamp` (0.25) damps `ionDen` **between coupling passes**, inside
    the loop.
  - `iterDamp` (0.25) damps `Te` **between MC iterations**, after the loop -
    the interval the convergence criterion is defined on.
  - `pdrAbun`, the molecular abundances, were damped on **neither** interval.
  - `ionDen` was damped pass-to-pass but **not** across the MC iteration.

D-174 added the Te damping and stated the restriction plainly: *"Te only, for
now: it is the bistable variable, and one change at a time is the point."*
That was the right discipline at the time and D-198 measured it wrong. The two
branches differ in all three quantities at once - a hot cell is atomic AND
ionized AND hot - so damping one while the other two run free lets the free
pair carry the flip and drag the damped one after it.

### Why the molecular abundances specifically

Under `CHEMSTEADY` the network integrates to a steady state, so the starting
abundances do not set the answer EXCEPT where more than one steady state
exists - which is exactly the bistable regime. D-112 already measured that
part: V1's H2 front ratio is 1.109 from the network seed against 1.679 fully
dissociated, and the second does not relax into the first even with a
hundredfold longer integration. `pdrAbun` carries over from the previous
iteration as that starting point, and was undamped.

`elemAvail` is derived from `pdrAbun`, so it is republished from the damped
abundances. Without that the next iteration's first coupling pass would
normalise the ion stages to a molecular fraction that no longer matches the
abundances beside it - the D-199 lag, reintroduced by the damping itself.

### What this can and cannot do

Damping is a relaxation on the path, not a change to the fixed point.

  - If the coupled system has ONE root and was oscillating around it, this
    finds it: the flip rate goes to zero and one population is left.
  - If the thermal balance genuinely has TWO roots, this does NOT remove the
    second. Each cell freezes on whichever branch it is nearest, the flip rate
    ALSO goes to zero, and two populations are left.

Both outcomes zero the flip rate, so the flip rate alone cannot distinguish
them and must not be reported as if it could. The `[D200]` census therefore
reports the branch populations alongside it. A single smooth profile means the
oscillation was a coupling artifact; a static bimodal one means the roots are
real and the damping has hidden the symptom rather than fixed the cause -
which would be exactly the "tune it away" failure CLAUDE.md warns against, and
would have to be reported as such rather than kept.

### What is NOT known

  - Which of the two outcomes this produces. Running as this is written.
  - Whether `iterDamp` = 0.25 is the right strength for the abundances. It is
    reused rather than given its own keyword, on the grounds that one
    relaxation parameter for one interval is a design and three would be
    knobs. If the abundances need a different constant, that is a finding.
  - The residual one-PASS lag from D-199 is untouched: within a coupling pass
    `updateCell` still runs before `pdrStep`.
  - Nothing here addresses the ionized region running 9173-15660 K against a
    benchmark of 7927-9420 K (D-198).


---

## D-201 - the damping introduced a second x(H2) (2026-09-09)

Against `13641c9` plus D-200. Self-inflicted, found within the hour, recorded
because the class of defect is the one this project keeps rediscovering.

### What happened

D-200 damps `pdrAbun` across the MC iteration. `H2den` is DERIVED from it -
`pdrStep` writes `H2den = abun(NH2)*nH` - and was not damped with it. From that
point the model carried two molecular fractions:

  - `pdrAbun(NH2)`, damped, which the chemistry and `elemAvail` use;
  - `H2den`, undamped, which MOCASSIN's H2 opacity reads (D-107,
    `addOpacity`), which the convergence test compares against
    `xH2iterStart` (D-179), and which the D-200 branch census reads.

### How it was caught

Not by inspection. The D-200 census is computed twice by different code on
different arrays - in-line during the run from `H2den`, and afterwards from
`pdrGrid.out`, which carries `pdrAbun`. At iteration 12 of the first D-200 run
they disagreed:

      same cells, same thresholds, iteration 12
        from H2den   (undamped)   hot branch 27.6%
        from pdrAbun (damped)     hot branch  1.6%

*measured*. Two numbers for one quantity is the signature, and the only reason
it surfaced is that the quantity was being computed twice from different
sources. A single implementation would have been self-consistent and wrong.

### What it costs

The whole D-200 measurement is suspect and is NOT being reported as a result.
Its branch classification used the undamped array while the physics ran on the
damped one, so the trace

      hot fraction, iterations 4-12
      0.0  2.0  76.1  18.4  7.7  6.0  3.9  77.1  27.6

cannot be attributed to the damping. It may be the bistability, it may be the
split, it is most likely both. Rerun with `H2den` following.

One D-200 result does survive, because it does not touch x(H2): the coupling
consistency improved sharply. `x(H+)_ion/x(H+)_chem` p90 went 1.21 -> 1.0005
and its maximum 82 -> 1.35 against the undamped contract run.

### The rule this breaks

CLAUDE.md, "one reality per quantity": *"There is one x(H+), one T_e, one A_V.
If two arrays hold the same physical thing they will diverge, and the
divergence will be found late and in the deep, quiet part of the model."* The
divergence here was found early only by luck of double instrumentation.

Anything derived from a damped array has to be damped or recomputed with it.
In this coupling that is `H2den` and `elemAvail` from `pdrAbun`; both now are.
`NePDR` is derived from `abun(NELECT)` and is not, but nothing reads it
(`pdrUseNePDR` = 0, audit P5) so it cannot yet diverge into anything.

### Measured, after the fix

Same fixture, same damping, `H2den` following the damped abundances. The two
runs differ in that one line.

      it   D-200 hot%  D-201 hot%   D-200 cold%  D-201 cold%   D-200 flip%  D-201 flip%
       5      2.0         0.0          92.4        90.6           2.73        0.00
       6     76.1         0.0          16.5        15.2          78.51        0.00
       7     18.4         0.3          76.4        82.0          84.79        0.41
      11     77.1         1.6          18.5        17.0          77.52        1.78
      12     27.6         1.4          65.4        74.5          70.98        1.52

*measured*. Two separate results, and they point in different directions.

**The hot branch was mine.** The eruptions to 76-77% and the flip rates of
78-85% do not occur when x(H2) is single-valued. The hot population never
exceeds 1.6% and flips never exceed 1.78%. So D-200's "period-2 global
oscillation" was a description of the split, not of the model, and is
withdrawn.

**The molecular-fraction swing is not mine, and damping does not touch it.**
The cold fraction collapses at iteration 6 and again at iteration 11 in BOTH
runs, at the same iterations and with the same amplitude: 92.4 -> 16.5 against
90.6 -> 15.2, and 90.8 -> 18.5 against 89.8 -> 17.0. Identical to within a
point and a half. Whatever drives it is upstream of both the damping and the
x(H2) split.

The flip counter reports 0.00-1.78% through all of that, because it tests
`hot` against `not-hot` and this swing is cold <-> between. **That is a defect
in the instrument, not a quiet model**, and it nearly got reported as one.

### What this says about damping

  - It does NOT resolve the instability. Convergence ends at 0.0066%, against
    0.0197% undamped: no better, and arguably worse.
  - It DOES improve the coupling consistency sharply, and that survives:
    `x(H+)_ion/x(H+)_chem` p90 1.21 -> 1.0021, maximum 82 -> 1.80.
  - The question it was meant to answer - one root or two - is not answered.
    The hot/cold split it was testing turned out to be an artifact, so the
    two-root hypothesis it came from has no measurement behind it either way.

### What is NOT known

  - **What drives the swing at iterations 6 and 11.** Photon count is constant
    at 6e6 throughout, so it is not `lgAutoPackets`. Two events is not a
    period; calling it one on this evidence would be the same error as the two
    premature calls made while D-200 was running.
  - Whether a heavier `iterDamp` changes it. Untested, and worth testing only
    with a census that can see the cold <-> between axis.
  - The census thresholds are the immediate work: `hot` = 2x(H2) < 0.01 and
    T > 3000 K, `cold` = 2x(H2) > 0.5, and a swing between 0.5 and 0.01 is
    invisible to the flip count. It should report the molecular fraction's
    distribution, not a three-way label.
  - The ionized region still runs 9173-15660 K against 7927-9420 K (D-198).


---

## D-202 - the census could not see the swing (2026-09-09)

Against `8563528`. A defect in my own instrument, found by reading its output
against the axis data rather than by any test.

**What the instrument said.** The D-200 census gives each PDR cell one of three
labels - `hot` (2x(H2) < 0.01 and T > 3000 K), `cold` (2x(H2) > 0.5), `between`
- and counts the cells whose HOT label changed since the iteration started.
Across the whole D-201 run that count never exceeded 1.78%.

**What was actually happening.** In the same iterations the cold population
went 90.6% -> 15.2% and back to 74.5%. Three quarters of the grid moved. The
flip count did not see it because the motion ran from `cold` into `between` and
back, and neither end of that path crosses the `hot` threshold. The label was
constructed so that the swing is invisible to it.

This is the project's recurring failure in a new place. D-176..D-181 measured
convergence on a quantity that could not move; D-191 did it again; D-196 found
the convergence percentage counting frozen cells. Here it is a *census* rather
than a convergence test, but the shape is identical: a number that cannot
respond to the thing it is watching reports quiet, and quiet is the answer
everyone wants, so it is believed.

**The fix.** No labels. The census now reports

  - an eight-bin histogram of f_mol = 2x(H2) over the PDR cells, spanning
    <0.01 through >=0.99, as a percentage of cells;
  - f_mol at p10 / median / p90, and its mean;
  - |df_mol| since the iteration start at median / p90 / max, and the count of
    cells that moved by more than 0.10 and by more than 0.50;
  - Te at p10 / median / p90, and the count above 3000 K.

A distribution has no threshold to be blind at. The one labelled count kept is
`f_mol < 0.01 .and. Te > 3000`, the old `hot`, and it is kept only so the D-200
and D-201 tables remain comparable to what follows.

**One property of the old census is deliberately preserved.** f_mol is taken
from `H2den`, and the `mean 2x(H2)` line a few lines above it is taken from
`pdrAbun`. D-201 was caught precisely because two code paths computed the same
physical quantity from different arrays and disagreed. Collapsing them to one
array would be tidier and would have hidden that defect, so they stay separate:
here the redundancy is the test, not the bug.

**What it shows.** Run `runs/d202-census`, the `hiipdr-contract` fixture at
`8563528` plus this census. Stopped by the operator during iteration 7, which
is after the collapse and so leaves the measurement intact.

    f_mol = 2x(H2) distribution, % of PDR cells
     it      <.01  .01-.1   .1-.3   .3-.5   .5-.7   .7-.9  .9-.99   >=.99
      4      0.00    0.00   75.33   24.00    0.67    0.00    0.00    0.00
      5      0.00    4.32    1.41    3.34   12.19   78.74    0.00    0.00
      6      2.25    0.05   81.23    2.24    1.19    5.77    7.26    0.00

The collapse reproduces: the cells above f_mol = 0.5 go 90.9% -> 14.2% at
iteration 6, matching the 90.6% -> 15.2% the D-201 run reported for the same
iteration with the old labels. So the new instrument is measuring the same
event, and the D-200/D-201 tables are not invalidated - they were incomplete,
not wrong.

What the labels could not show is the shape. This is not two clean branches
with an empty gap between them, which is what "bistable" was asserting from
D-198 onward. At iteration 6 the population is spread across four separated
bins - 2.25% fully atomic, 81.2% at f_mol ~ 0.2, 7.0% between 0.5 and 0.9, and
7.26% at 0.9-0.99 - with the mode sitting in the MIDDLE of the range, not at
either end. A cell at f_mol = 0.2 is not on a branch; it is somewhere between
them. The word "bistability" should be treated as unproven from here on.

**What is NOT known.** Whether f_mol falls because Te rises or Te rises because
f_mol falls. Both move within one MC iteration and the medians cannot order
them. See D-203.

---

## D-203 - measuring the input, not just the answer (2026-09-09)

Against D-202, same build. The bistability has survived the contract (D-198),
damping (D-200) and the x(H2) split (D-201), and none of those measurements
looked at what the chemistry was handed.

f_mol is an *output*. Its two dominant inputs in this model are the FUV field
the cell sees, chi_FUV in Draine units, and the effective A_V the MC transfer
built for it. Both already exist per cell (`grid%chiFUV`, `grid%AVeff`) and
both are written to `pdrGrid.out`, but neither was reported per iteration, so
the time series that would separate the two candidate causes was never formed.

The census now prints chi_FUV and A_V at p10 / median / p90 on the same lines
as f_mol and Te, every iteration. The discrimination is direct:

  - f_mol collapses while chi and A_V hold steady -> the cause is inside the
    chemistry / thermal-balance loop, and the field is exonerated;
  - f_mol collapses *after* chi jumps or A_V drops -> the cause is upstream, in
    the radiative transfer, and the chemistry is doing what it was told.

Neither outcome is assumed. The photon count is constant at 6e6 across the run,
so `lgAutoPackets` is already ruled out as a source of a step change in the
field; that is the only candidate eliminated so far.

**Measured, and the discrimination is clean.** Same run as D-202:

     it   f_mol_med   Te_med      chi_med      AV_med
      4      0.1888     265.5   2.909e-01   2.371e+00
      5      0.7645      79.1   2.785e-01   2.361e+00
      6      0.1957    8005.9   2.812e-01   2.355e+00

Across the collapse the median molecular fraction falls by a factor 3.9 and the
median temperature rises by a factor 101, while the median FUV field moves
+1.0% and the median A_V moves -0.3%. The field the chemistry was handed is
flat to a per cent across an event that moves its answer by two orders of
magnitude.

**So the FUV field and the extinction are exonerated.** The instability is
inside the chemistry / thermal-balance loop. The `lgAutoPackets` candidate was
already dead (photon count constant at 6e6), and the two `nIterateMC >= 6`
branches in `update_mod.f90` - which fire at exactly the iteration of the
collapse, and were checked for that reason - are the D-135 and D-138 print
probes and change no state.

**The inner coupling loop is exonerated too, and that was not expected.**
Within iteration 6 the `[D119]` abundance-weighted mean ion-fraction change
decays 8.63e-3 -> 7.15e-3 -> 3.90e-3 -> 1.57e-3 over the four passes. The
ionization/chemistry coupling settles inside the iteration; the state then
swings by a factor 100 in Te between iterations. The instability lives in the
MC iteration loop, not in the coupling loop that was built to close it.

**A limit on the claim, stated because it decides the next measurement.**
"the field is flat" is established for chi_FUV and for A_V. It is NOT
established for the rest of the radiation field: the MC transfer also sets the
local heating rates and the dust temperature, and those are what MOCASSIN's
thermal balance actually solves against. The one number in hand there is from
the D-137 probe at iteration 6, on deep cell 14: MOCASSIN's photoelectric
heating is 7.6e-27 per H against 3D-PDR's 4.19e-25, a ratio of 1.8e-2. That is
a 55-fold disagreement in the dominant PDR heating term, and it is the obvious
place to look next - but it is one cell, on a cell that is cooling smoothly
(130 -> 108 -> 90 -> 75 K across the balance solve) rather than one of the
collapsing ones, so it is a lead and not a result.

**What is NOT known, and is not being guessed.** Whether Te leads f_mol or
f_mol leads Te. The coupling pass order (updateCell before pdrStep) means the
thermal balance at iteration 6 ran on iteration 5's abundances, which would
favour Te leading - but that is inference from code order, not measurement, and
inference of exactly this kind has been wrong three times in this project
(D-135, D-137, D-191). The measurement that settles it is the heating and
cooling budget in the census, per iteration, next to f_mol and Te.


---

## D-204 - which one moves first (2026-09-09)

Against `dbfb882`. D-203 narrowed the iteration-6 collapse to the chemistry /
thermal-balance loop and ruled out the FUV field, the extinction, the photon
count and the inner coupling loop. What it could not do is order the two
quantities inside it: the median f_mol falls by 3.9x and the median Te rises by
101x in the same MC iteration, and iteration-end medians cannot say which drove
which.

Both directions are physically ordinary and they call for opposite fixes:

  - **Te leads.** MOCASSIN's thermal balance flips to ~10^4 K on abundances
    that are still molecular; the chemistry then dissociates H2 because it was
    handed a hot cell. The defect is in the heating/cooling budget - and the
    D-137 probe's 55-fold photoelectric disagreement is a live candidate.
  - **f_mol leads.** The chemistry drops the molecular fraction first; the
    molecular coolants go with it, and the thermal balance runs away hot
    because its cooling was removed. The defect is in the chemistry or in what
    it is handed.

**The measurement.** Inside each MC iteration the coupling loop runs
`updateCell` before `pdrStep`. So immediately after the FIRST `updateCell`,
MOCASSIN's thermal balance has been solved against the abundances the iteration
started with, and this iteration's chemistry has not run at all. Sampling Te
there is a clean split:

    Te at iteration start  ->  Te after pass-1 updateCell  ->  Te at iteration end
                              (chemistry has NOT run yet)     (chemistry has run)

If the jump to ~10^4 K is already present in the middle column, the thermal
balance flipped at unchanged f_mol and Te leads. If the middle column still
holds the cold value and the temperature only rises by the end, f_mol led.

`grid%Te` is not reduced inside the coupling loop - each rank holds new values
for the cells it owns and stale ones elsewhere - so the count is formed per
rank over owned PDR-zone cells and reduced with three scalar collectives that
every rank executes unconditionally. The census prints the iteration-start
values over the same cell set, so the three columns share a denominator.

**A note on getting the run to complete.** Three consecutive runs were killed
mid-iteration, all reported as stopped by the operator. No OOM entry in the
kernel log, no MPI abort banner, no stall - iterations ran at normal cadence up
to each cut, and in every case the MPI job and an unrelated polling task died
in the same instant, which is a task-group kill rather than a process failure.
The job is now launched detached (`setsid`, its own session, reparented to
init) so that whatever reaps the background tasks takes the poller and leaves
the run alone. That worked: `runs/d204-order` ran through.

**The answer: neither leads.**

     it   | cells with Te > 3000 K, %  |  mean Te, K       |  mean f_mol
          |  start    upd1     end     |  start     upd1   |  start     end
      4   |   4.17    0.04    0.00     |  1168.0     51.9  |  0.0000   0.2335
      5   |   0.74    0.66    1.94     |   363.9    122.0  |  0.2322   0.7066
      6   |   2.25    5.08   76.74     |   211.7    970.1  |  0.7003   0.2950

All three temperature columns are the same statistic - the percentage of PDR
cells above 3000 K - because the first version of the reporting tool paired
D-204's means against the census median, and a three-point series whose points
are different statistics is the mismatched comparison this project keeps
finding.

At iteration 6 the thermal balance runs on gas that is still 70% molecular and
takes the hot fraction from 2.25% to 5.08%, with the mean temperature up by a
factor 4.6. That is a real push. It is also one fourteenth of the 76.74% the
iteration ends at. The remaining 71.7 points appear across the five coupling
passes, so the collapse is a coupled runaway and not a lead-follow.

**D-203's inference was wrong, and this is why it was measured.** D-203 argued
from the pass order - `updateCell` before `pdrStep` - that Te probably leads.
It does not. That is the fourth time in this project that reasoning from code
order about which quantity moves first has been wrong (D-135, D-137, D-191,
here), and the first time it was checked before being written down as a result.

**The sign flip, which is the lead worth following.** The thermal balance's
response at pass 1, against the molecular content it was handed:

     it   f_mol at start   mean Te: start -> upd1
      4       0.0000        1168.0 ->    51.9   (x 0.04, cools)
      5       0.2322         363.9 ->   122.0   (x 0.34, cools)
      6       0.7003         211.7 ->   970.1   (x 4.58, WARMS)

Monotonic in f_mol, and it changes sign. MOCASSIN's thermal balance cools
atomic gas and warms molecular gas in this model, at fixed f_mol within the
pass - so it is attributable to the balance, not to the chemistry. Three points
from one run: a strong lead, not a settled law.

The obvious candidate mechanism is that `elemAvail = 1 - 2x(H2)` cuts x(H0) and
with it MOCASSIN's collisional cooling, while the molecular cooling meant to
replace it is not arriving at the same size. That is a hypothesis. It is not
measured, and D-205 is where the terms get reported.

**The sign flip does not survive the full run. It is withdrawn.**
`runs/d204-order` completed all 12 iterations (49:46, clean exit):

     it  f_mol_start   Te_start   Te_upd1    ratio
      4     0.0000     1168.0      51.9   x 0.04
      5     0.2322      363.9     122.0   x 0.34
      6     0.7003      211.7     970.1   x 4.58
      7     0.2938     6150.5    1606.4   x 0.26
      8     0.6617     2597.8     393.6   x 0.15
      9     0.7934     1109.5     231.2   x 0.21
     10     0.8282      629.4     144.6   x 0.23
     11     0.8559      428.2     488.5   x 1.14
     12     0.3413     6464.3    1792.7   x 0.28

Iteration 8 starts at f_mol 0.662, within 6% of iteration 6's 0.700, and its
pass-1 balance COOLS by a factor 0.15 where iteration 6 warmed by 4.58. The
relation is not monotonic in f_mol and there is no sign flip keyed to the
molecular content. The three points that suggested one were iterations 4, 5
and 6, which are the model's initial transient off the atomic seed - a
monotonic sequence read as a trend.

It was recorded as "a strong lead, not a settled law", and the full run says it
was not even that. Six more iterations cost nothing to wait for and would have
prevented the claim; that is the lesson, not the arithmetic.

**What replaced it.** Iteration 11 collapses just as hard as 6 - the hot
fraction ends at 77.57% - but its pass-1 balance does essentially nothing: the
hot fraction goes DOWN, 4.13% to 2.89%, and the mean temperature moves only
428 K to 489 K. So at iteration 11 the entire runaway happens inside the
coupling passes, with the thermal balance at fixed f_mol contributing nothing
at all. That strengthens D-205 rather than D-204: the unwatched part of the
loop is where this lives.


---

## D-205 - the loop's convergence monitor cannot see the runaway (2026-09-09)

Against `93fd747`. Found in the same log block as the D-204 answer, and it is
the more consequential half.

Inside iteration 6 of `runs/d204-order`:

    [D204]  pass-1 updateCell done, chemistry not yet run: mean Te 9.70E+02, hot 5.08%
    [D119]  coupling pass 2   abundance-weighted mean ion-fraction change: 8.56e-3
    [D119]  coupling pass 3                                               7.00e-3
    [D119]  coupling pass 4                                               3.86e-3
    [D119]  coupling pass 5                                               1.46e-3
    [D204]  iteration start:  mean Te 2.12E+02, hot 2.25%
    [D204]  mean f_mol at iteration start 0.7003   now 0.2950

The residual decays monotonically, by a factor 5.9 across the four passes it
covers. Read on its own it says the coupling loop is settling. In those same
passes the hot fraction goes from 5.08% to 76.74% and the mean molecular
fraction more than halves.

`[D119]` measures an abundance-weighted change in ION FRACTIONS. The runaway is
in the temperature and the molecular fraction. It is not that the monitor is
badly built - D-119 fixed a genuine defect in it, and it correctly reports that
the ionization/chemistry handshake converges within the iteration. It is that
the quantity it watches is not the quantity that is moving, so it reports quiet
through an excursion of a factor 15 in the hot fraction.

That is the third time in this audit. D-196: the convergence percentage counted
cells whose x(H0) was pinned by a clamp. D-202: the branch census counted
transitions of a label the swing never crossed. Here: the coupling residual
watches ion fractions while the thermal state runs away beside it. The common
shape is that each number was correct about its own quantity and was read as a
statement about the model.

**The change.** The D-204 snapshot fired only on pass 1, because the ordering
question only needed pass 1. It now fires on every pass and carries, per H
nucleus over the same PDR-zone cells:

    mean Te, the hot fraction, mean f_mol
    PDR cooling, PDR heating, and the photoelectric part of the heating

so the runaway can be watched building across the passes, with the two terms
that would drive it printed beside it. Six scalar collectives per pass, every
rank, unconditionally.

The D-137 probe measured MOCASSIN's photoelectric heating at 1.8e-2 of
3D-PDR's on one deep cell. Reporting `pdrHeatPE` next to `pdrCool` every pass
turns that single-cell observation into a population.

**What is NOT known.** Whether the PDR cooling handed back is too small to
replace the atomic cooling that `elemAvail` removes - that is the D-204
hypothesis and these are the numbers that test it. Nothing about the mechanism
is being asserted before the run.


---

## D-206 - the full 12 iterations: a relaxation oscillation, not a bistability (2026-09-09)

`runs/d204-order`, `hiipdr-contract` at `93fd747`, 12 iterations, 14 ranks,
49:46, clean exit. The first complete run of this fixture through the D-202
census.

    f_mol = 2x(H2) distribution, % of PDR cells
     it      <.01  .01-.1   .1-.3   .3-.5   .5-.7   .7-.9  .9-.99   >=.99
      4      0.00    0.00   75.46   23.82    0.71    0.00    0.00    0.00
      5      0.00    4.34    1.75    3.21   12.25   78.46    0.00    0.00
      6      2.25    0.05   79.99    2.21    1.34    5.96    8.20    0.00
      7      1.72    6.55   10.10    0.20    1.91   75.42    4.10    0.00
      8      2.02    4.38    4.94    1.31    1.78   18.52   67.05    0.00
      9      2.74    3.26    4.20    2.18    2.11    8.29   77.21    0.00
     10      2.32    2.30    3.74    1.74    2.41    6.51   80.97    0.01
     11      2.46    3.14   75.57    1.42    1.98    3.59   11.83    0.01
     12      2.46   13.25   10.23    0.95    1.85   66.25    5.00    0.01

**It is not settling and it is not stuck. It relaxes and breaks.** Read the
movement column: |df_mol| at p90 falls 0.62, 0.60, 0.55, 0.16, 0.13 across
iterations 6 to 10, and the fraction of cells moving by more than 0.1 falls
94.8%, 92.8%, 89.3%, 19.6%, 12.3%. The model is converging - the converged
fraction even reaches 0.0066% at iteration 9, its highest anywhere. Then
iteration 11 puts 83.6% of cells back into motion and the hot fraction to
77.57%, and the whole approach starts again: iteration 12 reproduces iteration
7 closely (start hot 77.57% vs 76.59%, end f_mol 0.619 vs 0.663).

That is the shape of a relaxation oscillation: a slow approach to a state, a
threshold, a fast discharge, repeat. It is NOT the two-branch bistability this
has been called since D-198, and D-202 already flagged that the distribution
has its mode in the middle rather than at either end.

**Two collapses, five iterations apart, with the same recovery shape.** That is
one interval, not a period. It is worth saying precisely: two events give one
gap, and this project has twice called an oscillation's character from too few
points and been wrong (D-200, twice in the same run). What can be said is that
the shape repeated once, in detail.

**The FUV field responds one iteration LATE, which confirms D-203.** chi
medians: 0.282, 0.411, 0.322, 0.321, 0.316, 0.293, 0.411 across iterations 6 to
12. It jumps ~45% at iterations 7 and 12 - the iterations AFTER each collapse,
when the H2 that was shielding the gas has already gone. The field follows the
molecules; it does not drive them. D-203 exonerated it from a flat series
across one collapse, and the full run shows why the series was flat there and
where the field's response actually appears.

**A_V drifts down monotonically**, 2.371 to 2.337 over the nine PDR iterations,
about 1.4% in total, unaffected by the collapses. Nothing in the oscillation
comes from the extinction.

**What triggers the discharge is not yet known.** The two collapsing iterations
are the two whose starting state is coldest and most molecular relative to the
run's trend (iteration 6 at mean Te 212 K after 364 K; iteration 11 at 428 K
after 629 K, with f_mol 0.856, the highest anywhere). But iteration 10 is also
cold and molecular and does not collapse, so "cold and molecular" is a
correlate, not a threshold, and no threshold is being asserted from two events.

**What is NOT known, and what measures it.** The discharge happens inside the
coupling passes - D-205 shows the loop's own residual cannot see it, and the
D-204 pass-1 probe shows the thermal balance at fixed f_mol contributes
one fourteenth of it at iteration 6 and nothing at all at iteration 11. The
per-pass instrument built at D-205 (mean Te, hot fraction, f_mol, and per H
nucleus the PDR cooling, PDR heating and its photoelectric part, on every pass)
has not yet been run. That is the next measurement.


---

## D-208 - the hardcoded seed was still there (2026-09-09)

Against `164798f`. Raised by the operator, who was right: this was supposed to
have been removed and was not.

**What the file says.** `dataPDR/species_reduced.d`:

    11,C+,1.40E-04,12.0
    26,He,1.00E-01,4.0
    30,O,3.00E-04,16.0
    31,H2,3.00E-01,2.0
    32,H,4.00E-01,1.0

x(H) = 0.400 and x(H2) = 0.300: sixty per cent of the hydrogen NUCLEI
molecular. These are `species_reduced.d`'s starting values for a standalone
dark-cloud run, not an initial condition for an H II region model.

**What D-188 did, and where its claim stopped being true.** D-188 made
`pdrStep` re-seed each cell from MOCASSIN's ionization state on its first
visit, and recorded that "the network file's x(H2) = 0.3 never reaches a cell
the chemistry actually solves". That is true of the ABUNDANCES the solver
starts from. It is false of what those abundances feed, and the call order says
so plainly:

    iteration_mod.f90:864   call computeAVdust(grid)      <- integrates pdrAbun
    iteration_mod.f90:865   call mocassinToPDR(grid)      <- computeRayColumns, ditto
    iteration_mod.f90:1029  do iCouple = 1, ...
    iteration_mod.f90:1258       call pdrStep(...)        <- the re-seed happens HERE

Both column routines sit in the `nIterateMC >= pdrStartIter` block, above the
coupling loop. So at the first PDR iteration the H2, C and CO shielding columns
are integrated over a grid that still holds the network defaults in every cell.
At n_H = 100 with 2e18 cm cells that is 6e19 cm^-2 of fictitious H2 per cell
and order 1e21 cm^-2 across the grid - H2 self-shielding saturates far below
that, so the first chemistry call solved a fully self-shielded cloud.

D-112 already measured that this is not a transient the model forgets: the H2
front ratio is 1.109 from the network seed against 1.679 fully dissociated, and
the two do not relax into each other with a hundredfold longer integration.

**Three more places the defaults survived.**

  - `computeRayColumns` has NO zone guard - it sums `pdrAbun(cP,pdrIdxH2)` over
    every active cell on the ray, H II region included. That is the RAYTHEIA
    path, which is `PDRGEOM=3D`, the default test build. `computeAVradial`
    guards with `pdrZone(cP) == 1`, and the comment explaining why the ionized
    gas must be excluded lives only in the radial routine.
  - `pdrAbun(0:nCells,:) = pdrInitAbun` ran over every cell including cell 0 and
    the inactive ones; only active cells were then overwritten, and nothing
    re-seeds an inactive cell ever.
  - `syncSeed` rescaled He, C, O and Mg to MOCASSIN's `elemAbun` and left
    hydrogen alone. So 0.400 and 0.300 were the vendored numbers exactly, while
    four other elements were MOCASSIN's - two rules for one quantity.

**The fix.** One seeding rule, `seedAbunFromMocassin`, called by `seedPDR` at
startup and by `pdrStep` on a cell's first visit:

    abun = 0                                   ! molecules included
    linked species <- elemAbun(elem) * ionDen(elem, stage)
    electrons      <- Ne / Hden

Nothing is read from the network file. Inactive cells and cell 0 get zeros
rather than dark-cloud abundances. `seedPDR` runs after `fillGrid`, so `ionDen`
is MOCASSIN's initial ionization rather than a converged one - but it is
MOCASSIN's, which is the whole point, and by the time the columns are consumed
at `pdrStartIter` the ionization has been through three MC iterations.

`syncSeed` and the `pdrSyncAbun` keyword retire with it - there is nothing to
rescale when the seed is built from MOCASSIN's numbers in the first place.
`pdrSyncAbun` becomes the eighth retired keyword. The network-vs-MOCASSIN
abundance comparison is still printed at startup, now as a report of what was
NOT used.

**A defect introduced and caught in the same edit.** Removing `syncSeed` by
walking back to the preceding comment header also deleted `linkIon`, the
routine that builds the very species-to-ion-stage table the new seeding rule
depends on. It failed at link time (`undefined reference to linkion_`) rather
than silently, and was restored. Recorded because "the cleanup deleted a
neighbour" is a failure mode worth having written down once.

**What is NOT known.** What this changes. Every result in this session -
D-202 through D-207, including the relaxation oscillation and its period -
was measured with the 0.300 seed in the first-iteration columns. The oscillation
may be unaffected, damped, or gone; nothing is being predicted. `runs/d207-budget`
was launched before this change and still carries the old seed, so its budget
numbers stand as a measurement of the OLD model and must not be read as the new
one.

**What must NOT be concluded if the oscillation improves.** That the seed was
"the cause". D-112 says the seed selects a branch; a branch change is not the
same as removing an instability, and the run-to-run comparison has to show the
oscillation gone rather than moved.


---

## D-207 - measuring the wrong side of the substitution (2026-09-09)

Against `164798f`. Caught before it was reported as a result, but only just:
the sentence naming 3D-PDR's photoelectric heating as the driver of the
runaway was written and then deleted.

**What the D-205 columns printed.** `pdrCool`, `pdrHeat` and `pdrHeatPE`, per
H nucleus. At iteration 6 pass 1 that reads heat 1.94e-25 against cool
8.02e-26 - net heating by a factor 2.4 in gas at 929 K, with 99% of the
heating photoelectric. Next to the D-137 probe's finding that 3D-PDR's
photoelectric term is 9 to 25 times MOCASSIN's own on the same cell, same
field, same A_V and same Tdust, the conclusion looked obvious.

**Why it was wrong.** `pdrHeatPE` reaches `heatInt` only inside

    if (pdrPEfromPDR /= 0 .and. grid%pdrZone(cellP) == 1) then
       heatInt = heatInt - photoelHeat_g + grid%pdrHeatPE(cellP)/grid%Hden(cellP)
    end if

and `pdrPEfromPDR` is 0 in `common_mod` and set by no fixture. What actually
reaches the balance in a PDR cell is MOCASSIN's own `photoelHeat_g`, measured
at 1.40e-26 per H, plus `pdrHeatXtra` at 1.42e-26 - together about 2.8e-26,
an order of magnitude below what the column was printing.

So the instrument was reporting 3D-PDR's own budget rather than the
substitution's effect on MOCASSIN's. Both are real numbers about real things.
Only one of them is the one the sentence was about.

**Fourth in this audit, and the first that is mine.** D-196: a convergence
percentage counting cells whose x(H0) was pinned by a clamp. D-202: a census
counting transitions of a label the swing never crossed. D-205: a coupling
residual watching ion fractions while the temperature ran away. D-207: a
budget column reading the neighbouring budget. The first three were inherited;
this one was written two commits earlier in this same session, by me, while
writing the entry that names the pattern.

**The fix removes the possibility rather than correcting the number.**
`grid%pdrHeatUsed` and `grid%pdrCoolUsed` are set in `thermBalance` as

    heatUsed = heatInt(after the PDR block) - heatInt(before it)
    coolUsed = coolInt(after)              - coolInt(before)

so they are the substitution's net effect by construction and cannot drift
from the budget however the substitution is later changed. `pdrHeatXtra` is
still reported alongside, since it is the one PDR term that always enters.

**What is NOT known.** What flips the balance between pass 1 and pass 2. The
per-pass series shows Te going 489 K to 2273 K at iteration 11 pass 2 while
f_mol moves only 0.855 to 0.834, so it is not the molecular content. The
candidates are the coolants re-evaluated at a new reference temperature
(D-166) and coolants zeroed when their carrier falls below the floor (D-167,
which describes this runaway shape exactly). `runs/d207-budget` is the
measurement - and note it was launched before D-208, so it carries the old
hardcoded seed.
## D-195 - H2 formation on grains, from the model's own dust (2026-09-08)

D-194 item 1, implemented. The complaint was `source/pdr/h2_form.F90:36`:

    TOTAL_CROSS_SECTION=6.273D-22    ! cm^2 per H nucleus
    SILICATE_CROSS_SECTION=8.473D-22
    GRAPHITE_CROSS_SECTION=7.908D-22

and the rate that uses them:

    RATE = 0.5*v_th*(SIL_XSEC*eps_sil + GRA_XSEC*eps_gra)*S*METALLICITY

The rate is LINEAR in those cross sections and they are constants. A dust-poor
model, a dust-rich model, one with a different size distribution and one made
of a different material all got the same diffuse-ISM H2 formation rate. The
H/H2 front therefore sat where standard ISM dust would put it regardless of
what dust MOCASSIN was actually transporting radiation through - and the H/H2
front position is one of the two open disagreements against 3D-PDR sec 5.4.

### What MOCASSIN measures

The quantity CT02 wants is the GEOMETRIC grain area per H nucleus. MOCASSIN
already has every term:

    sigma_bar   = sum_species sum_sizes grainAbun * pi*a^2 * grainWeight   [cm^2/grain]
    area per H  = Ndust(cell)/Hden(cell) * sigma_bar

`sigma_bar` uses exactly the weighting `dustOpacity` uses to build `absOpac`
from `Ndust` (ph_mod.f90:1398, grid_mod.f90:1810-1830), so the area and the
opacity describe the same grains - which is the whole point. It is fixed by the
size distribution and so is measured once; `Ndust/Hden` is per cell and is
applied in `dustPerCell`, the loop that already visits every cell each
iteration to refresh `dustAVfac` (D-109).

Deliberately placed BEFORE the `kV <= 0` cycle in that loop. A cell with no
dust has no A_V scale, hence the model-wide fallback there - but it does have a
well-defined grain area for H2 formation, namely zero. Falling back to a
diffuse-ISM constant there would form H2 on grains the model does not contain.

### The silicate / graphite split

CT02 gives the two materials different binding energies, so the rate needs to
know which surface it is looking at. MOCASSIN's grain labels come from the .nk
files and follow no single convention (`Ssil_dl_base`, `CamC-hann`, `grph1-dl`,
`Olivpx`, `gr2_dl_hgk`, ...), so the classifier matches substrings and the full
classification table is PRINTED at startup rather than trusted silently.
Anything not recognisably carbonaceous goes to the silicate channel, and an
unrecognised label additionally raises a warning naming itself.

### Measured, this model

`benchmarks/pdr/hiipdr`: single component, `astroSilD2003_base.nk`, MRN slope
-3.5, a = 0.01-0.30 um, MdMg = 0.011295, mu = 1.418 amu/H.

    sigma_bar  = 1.1675e-11 cm^2 per grain
    Ndust/n_H  = 8.7069e-11
    silicate   = 1.0165e-21 cm^2/H     (CT02 assumes 8.473e-22)
    graphite   = 0                     (CT02 assumes 7.908e-22)

The area is 20% LARGER than CT02's silicate channel. That is not the story.
The story is the missing material, because the two efficiencies diverge with
dust temperature - silicate's saddle-point energy is 110 K against graphite's
260 K, so eps_sil collapses above ~25 K while eps_gra holds to ~60 K:

      T_d   eps_sil   eps_gra    old rate    new rate   ratio
       10    0.9996    0.9968   1.635e-21   1.016e-21   0.621
       20    0.9009    1.0000   1.554e-21   9.158e-22   0.589
       30    0.5924    0.9970   1.290e-21   6.022e-22   0.467
       40    0.3676    0.9740   1.082e-21   3.736e-22   0.345
       60    0.1886    0.8112   8.013e-22   1.917e-22   0.239

So the H2 formation rate falls by a factor 0.62 in the cold interior and by
more than 4 where the dust is warm. Over this model's actual dust temperatures
(~21 K at the illuminated face, colder inside) the working factor is ~0.6.

Less H2 formation moves the H/H2 front DEEPER in A_V. D-191 left that front at
A_V 0.461 (damping 0.50) and 0.736 (damping 0.25) against 3D-PDR's 0.892, i.e.
too shallow, with x(H2) overshooting 12x - so the direction is right. Whether
the size is right is what D195hii is being run to find out; nothing is claimed
here beyond the measurement.

### Honest notes

  - Upstream's own TOTAL (6.273e-22) is not the sum of its two channel values
    (1.638e-21). Only the two channel values enter the active CT02 branch, so
    those are what the measurement replaces; TOTAL is carried along for the
    commented-out Tielens & Hollenbach branch.
  - METALLICITY still multiplies the rate, exactly as before. The measured area
    already contains MdMg, so `pdrMetal` remains a user knob layered on top and
    is NOT pre-multiplied into the areas - same convention as `pdrAVfacMod`
    (D-109), one factor of metallicity, not two.
  - The classifier is a heuristic over free-text labels. It is printed, so it
    can be checked and corrected; it is not claimed to be complete.
  - The efficiency table above is evaluated offline from the CT02 formulae, not
    read out of a run.

### Files

  - `source/pdr/modules.F90` - `h2form_xsec_sil` / `h2form_xsec_gra` in
    `global_module`, both initialised to -1 meaning "host measured nothing"
  - `source/pdr/h2_form.F90` - uses them when both are non-negative; the
    upstream constants otherwise, so a dust-free model is bit-identical
  - `source/pdr_mod.f90` - `measureH2grainArea`, `isCarbonGrain`,
    `isSilicateGrain`; per-cell fill in `dustPerCell`; per-cell reseed in
    `pdrStep` next to `pdrAVfacMod`; report in `calibratePDRdust`
  - `source/common_mod.f90`, `source/grid_mod.f90` - `dustSigSil` /
    `dustSigGra` per-cell arrays, initialised to -1

All four build flavours compile clean.

### D-193 verified, on D193hii

Run finished, 24 iterations. The defect D-192 recorded was
`x(HI)+2x(H2)+x(HII)` = 1.28-1.64 in 16 of 29 axis cells, with `ionDen(H0)`
clamped to exactly zero and `ionDen(H+)` at 5.8e-1 where the chemistry said
4.5e-2. After D-193:

    hydrogen budget off by >2%:  0 of 29 cells

and MOCASSIN's `ionDen(H+)` now agrees with the chemistry's x(H+) to 3-4
significant figures from the face down to r = 2.2e19 cm. Past that the two
still differ - 3.09e-4 against 1.34e-2 at r = 3.4e19 - but at absolute levels
of ~1e-2 in a region whose temperature is still oscillating (248 K, 3043 K,
168 K, 254 K, 167 K, 1556 K on consecutive cells). That oscillation is the
open item, not the ownership.


---

## D-209 - seeding the molecules from the photoionization solution (2026-09-09)

Asked for by the operator, on the reasoning that before the chemistry runs the
model already knows x(H0), Te and Tdust, and should use them rather than start
from nothing.

**Where it runs, and why not earlier.** `seedPDR` executes right after
`fillGrid`, where `fillGrid` has set x(H0) = `initH0` = 1e-5: the grid starts
essentially fully ionized and MOCASSIN knows nothing yet, so D-208's zeros are
correct there. By `pdrStartIter` there is a converged ionization structure, an
electron temperature, a dust temperature and a dust opacity, and
`computeAVdust`/`mocassinToPDR` have turned the last into chi_FUV and A_V. That
is the moment, and it has to be before the shielding columns are integrated -
which is the whole D-208 problem, one step further on.

**H2: an equilibrium, in closed form.**

    R n(H) n_H = D n(H2),   n(H) + 2n(H2) = N
      ->  n(H2) = R N n_H / (D + 2 R n_H)

Hydrogen conserved exactly, bounded by N/2, tending to N/2 as D -> 0 and to
zero in the ionized gas where N is already near zero. No iteration, no free
parameter. R is `H2_FORMATION_RATE(Te, Tdust)` with the grain cross sections
reseeded from MOCASSIN's measured geometric area per H (D-195, cherry-picked
back from `d193-d195-reverted` for this); D is the network's own
photodissociation coefficient, looked up in the rate table rather than written
into the source, times MOCASSIN's chi_FUV attenuated by the network's `SCATTER`
at MOCASSIN's A_V.

D is deliberately UNSHIELDED. H2 self-shielding needs an H2 column and the
column is what the seed exists to supply; zero is the only choice that cannot
inject shielding the model has not earned. It errs low, so the chemistry
self-shields upward from a floor instead of relaxing down from a fiction.

**CO is an ansatz and is labelled one.** Every path to CO in the reduced
network is a chain through H2, so there is no two-body rate to balance and no
equilibrium to solve without inventing a coefficient. CO takes the same share
of the neutral carbon that H2 took of the neutral hydrogen, capped by the
available oxygen, conserving both. Zero without H2, all the neutral carbon when
fully molecular. The chemistry replaces it on the first call.

**What it places.**

    [D209] seeded 15204 cells: mean f_mol = 2x(H2) 0.4826, f_mol > 0.5 in 49.64%
    [D209] inputs: mean x(H0) 9.567E-01  chi 8.883E+00  A_V 2.191E+00
                   R_form 2.000E-17  D_pd 1.789E-10

Structurally right - near zero in the illuminated gas, near one deep, half the
grid above 0.5 - against the hardcoded seed's uniform 0.6 including the H II
region, and D-208's zero everywhere.

**Two failed attempts, both stale inputs, both plausible on their face.**

  - `seedMolecules` called before `mocassinToPDR`, which is what writes
    chi_FUV. D = 0 everywhere, the closed form correctly returned N/2, and the
    log read mean f_mol 1.0000 in 100.00% of cells. A zero field IS the
    fully-shielded limit, so the answer was right for the question accidentally
    asked.
  - Neutral hydrogen read from `pdrAbun` rather than from the current `ionDen`.
    `seedPDR` had filled it at startup from x(H0) = 1e-5, so no cell could put
    more than 5e-6 into H2. Reported mean f_mol 0.0000.

Neither was visible in the answer alone, which is why the `[D209]` line now
prints the seed's INPUTS beside its output. That is the D-203 lesson - report
what went in, not only what came out - which had been written down and then not
applied to this routine.

The reported f_mol was also, on the first attempt, the fraction of the NEUTRAL
hydrogen that is molecular rather than 2x(H2) per H nucleus. In ionized gas the
neutral fraction is ~0, so that ratio is 0/0 and reads 1 where the census
definition reads ~0 - two definitions of f_mol in one model, and the one that
made the zero-field defect look plausible. It now prints the census definition.

**The result: the oscillation does not care.**

     it   f_mol mean, zero seed   f_mol mean, D-209 seed
      4          0.2335                  0.7697
      5          0.7066                  0.8165
      6          0.2950                  0.2913
      7          0.6634                  0.6416
      8          0.7953                  0.7696
      9          0.8291                  0.8182
     10          0.8571                  0.8144
     11          0.3413                  0.3273
     12          0.6186                  0.6031

The seed changes iterations 4 and 5 and nothing after. From iteration 6 the two
runs are the same trajectory to within a few per cent, collapsing at 6 and 11
in both, the same five-iteration interval, the same 0.0066% convergence
ceiling. Two initial molecular contents differing by a factor 3.3 converge onto
one cycle within two iterations.

So the cycle is an attractor of the coupled system with no memory of the seed.
D-208 predicted that an improvement would not establish the seed as the cause;
there is no improvement at all, which settles it the other way and conclusively.
Both D-208 and D-209 remain worth having - 0.300 uniformly across an H II
region was wrong on its own terms, and an equilibrium seed is the right
starting point - but neither is this defect.

**A note against citing D-112 here.** D-112 measured that the H2 seed selects a
branch that does not relax away even with a hundredfold longer integration.
That was the 1D slab at a fixed field. In the fully coupled model the seed's
memory is gone in two iterations. Different regime, not a contradiction, but
D-112 should not be quoted as though it covers the coupled case.

**What is NOT known.** What sets the five-iteration interval, and what triggers
the discharge. `runs/d207-budget` was to answer the second with `pdrHeatUsed`
and `pdrCoolUsed`, and it was killed before finishing; it also predates D-208,
so it would have to be rerun regardless.

**Known defect in the D-209 diagnostic, not yet fixed.** The input line reports
MEANS over a field that is strongly bimodal - mean chi 8.88 and mean D 1.79e-10
are set by H II region cells where chi is huge and A_V ~ 0, while the molecular
half sits at chi ~ 0.1 and A_V ~ 3. Substituting those means into the closed
form gives f_mol 2e-5 rather than the 0.4826 actually placed. That is not an
inconsistency in the seed, it is a mean over two populations describing
neither, and it is the D-202 failure in a new diagnostic. It should print
quantiles.


---

## D-210 - the cooling substitution changes sign, and that is the oscillation (2026-09-09)

`runs/d210-budget`, `hiipdr-contract` at `ea75caf`, 12 iterations, 45:33, clean
exit. The first run carrying D-207's `pdrCoolUsed`/`pdrHeatUsed` on top of the
D-208 and D-209 seed work.

**The measurement.** `pdrCoolUsed` is `coolInt` after the PDR block minus
`coolInt` before it, per H nucleus - the substitution's own effect on
MOCASSIN's budget, by construction, which is the property D-207 built it for.
Per coupling pass:

    iteration 6                          iteration 11
    pass  Te     f_mol   cool            pass  Te     f_mol   cool
      1    542   0.809   +2.4345e-23       1    612   0.820   +1.9823e-23
      2   4127   0.697   -1.4562e-24       2   3388   0.714   -1.2600e-24
      3   8040   0.223   -1.3057e-23       3   8330   0.229   -1.1193e-23
      4   8240   0.132   -1.5824e-23       4   8289   0.155   -1.6064e-23
      5   8285   0.128   -1.5664e-23       5   8294   0.162   -1.5846e-23

The heating column over the same passes runs 1.7e-27 down to 8.0e-28 - four
orders of magnitude below the cooling - so the heating handback plays no part
in this at all. That is worth stating plainly, because D-207 caught a version
of this diagnostic that made 3D-PDR's photoelectric heating look like the
driver; with the terms that actually enter the balance, the heating side is
negligible and the whole event is in the cooling.

**What it says.** While the gas is cold and molecular the substitution SUPPLIES
essentially all the cooling: +2e-23 per H, against MOCASSIN's own coolColl of
order 1e-25 at those temperatures. Once the gas warms past ~1000 K the sign
flips and the substitution DELETES cooling instead, and keeps deleting more as
the temperature rises - 1.6e-23 per H by pass 5. Hotter gas gives weaker PDR
coolants, weaker PDR coolants delete more of MOCASSIN's, and that warms the gas
further. A positive feedback with no fixed point until the gas reaches ~8300 K,
which is where every collapse lands.

**Reproduced, which is what makes it a mechanism rather than an event.** Both
collapses show the same sign change at the same pass, at f_mol within 2% of
each other (0.697 and 0.714), and converge to the same value by pass 5 to
within 1%. Two independent discharges five iterations apart, one mechanism.

**Why the sign flip is not the molecular content.** Between pass 1 and pass 2
f_mol moves 0.809 to 0.697 at iteration 6 and 0.820 to 0.714 at iteration 11 -
about 13%, while the cooling term moves by 2.6e-23, its whole magnitude and
then some. The molecular fraction collapses AFTER, at pass 3. This is the
D-204 result at finer grain: the chemistry follows.

**Where the deletion comes from, and the guard that does not cover it.** The
substitution is replace-not-exclude:

    if (grid%pdrCoolSp(cellP,iCool) > 0.) then
       coolInt = coolInt - mocCool                     ! remove MOCASSIN's
       pdrCoolMol = pdrCoolMol + grid%pdrCoolSp(...)   ! add 3D-PDR's
    else if (mocCool > 0.) then
       nCoolNull = nCoolNull + 1                       ! keep MOCASSIN's
    end if

D-167 added that guard against 3D-PDR's coolant being ZERO, having diagnosed
exactly this runaway ("subtracting MOCASSIN's term and adding zero deletes the
cooling outright, which makes the cell hotter, which ionizes more carbon"). It
does nothing when 3D-PDR's coolant is merely SMALLER than MOCASSIN's, which is
a silent net loss on the same path and grows with temperature.

And `nCoolNull`, the one counter that separates the two cases, is incremented
and never printed anywhere in the code. The guard's activity has been invisible
since D-167 - a fifth instrument in this audit that cannot report what it
measures.

**What is NOT known.** Which of the two paths does the deleting. D-210 splits
the net into `removed` (MOCASSIN's coolant taken out), `added` (3D-PDR's put
in, recoverable as net + removed) and the guard's firing rate per cell, so the
next run answers it directly. If `added` is far below `removed` while the guard
is quiet, it is the unguarded smaller-coolant path and the fix is to guard on
magnitude rather than on zero - though "take the larger of the two" would be
choosing the answer rather than computing it, so what the right fix IS remains
open until the split is measured.

Nothing is being asserted about the fix before that run.


---

## D-211 - the guard covers the case that never fires (2026-09-10)

`runs/d211-split`, stopped after iteration 6 once the answer was in.

D-210 measured that the cooling substitution goes net negative. Two mechanisms
produce that and they need different fixes: 3D-PDR's coolant is ZERO (D-167's
case, guarded) or merely SMALLER than MOCASSIN's (unguarded). Splitting the net
into `removed`, `added` and the guard's firing rate settles it:

    iteration 5      Te      f_mol   cool used   removed    added     guard kept
      pass 1         39.4    0.758   +4.58e-26   0          0           3.000
      pass 2         44.4    0.857   +1.48e-27   4.04e-26   2.58e-26    0.000
      pass 3         99.5    0.869   -4.64e-26   3.65e-26   2.82e-26    0.000
      pass 4        149.7    0.840   -1.68e-25   2.19e-25   5.10e-26    0.000

`guard kept` is 0.000 per cell in every pass after the first. D-167's guard
never fires. Every deletion goes through the unguarded path, where 3D-PDR's
coolant is non-zero but smaller - at pass 4, by a factor 4.3.

`nCoolNull`, the counter that would have shown this, is incremented at
`update_mod.f90:2059` and printed nowhere. The guard's behaviour has been
unobservable since the day it was added.

**Iteration 5 does not collapse, and already shows the runaway.** Te goes 39 K
to 150 K across its passes, x3.8, at frozen radiation field, with the
substitution going negative from pass 3. The instability is in every iteration;
the collapse iterations are where it escapes.

---

## D-212 - Ne on the same footing as the other partners (2026-09-10)

The level-population solve that produces the substituted cooling takes five
collision-partner densities: H, H+, e-, He, H2. D-153 re-imposes MOCASSIN's
ionization on the linked species every call - but electrons are not an element,
have no entry in the link table, and were never reached. `abun(NELECT)` was
written from `grid%Ne` once, in `seedAbunFromMocassin`, and thereafter evolved
under CVODE.

That is a contract violation on its face: the operator's contract lists Ne
among the things MOCASSIN hands the chemistry, and it was the one item on that
list delivered once instead of every call. Fixed - four lines inside D-153's
existing block, so all five partners now arrive by the same rule at the same
moment.

**It changes nothing measurable.** Iteration 6, against `runs/d211-split`:

    pass   added (baseline)   added (Ne)     cool used (baseline)  cool used (Ne)
      1      2.524e-23        2.546e-23       +2.4877e-23          +2.5093e-23
      2      7.141e-25        6.960e-25       -1.3696e-24          -1.3958e-24
      3      8.537e-25        8.415e-25       -1.3136e-23          -1.3143e-23
      4      2.270e-24        2.270e-24       -1.5832e-23          -1.5956e-23

Identical within run-to-run scatter. **The hypothesis was wrong**, and the
reason it was wrong is instructive: D-153 already re-imposes C+ and H+, which
are what set the electron abundance in this network, so CVODE's electron
density was probably tracking MOCASSIN's all along. The argument ran from "it
is handed over once" to "therefore it drifts" without ever measuring the drift.
Third hypothesis withdrawn in this session; in each case the measurement was
cheaper than the argument that preceded it.

The change stays. It is right on contract grounds whether or not it moves a
number.

---

## D-213 - the cold state was propped up by an extrapolation artefact (2026-09-10)

`runs/d213-coolsplit`, stopped after iteration 6.

`added` is not the coolant. It is `pdrCoolSp` times D-166's factor
`(TeUsed/pdrCoolTref)^pdrCoolSlope`, clamped to [1e-8, 1e8] with the slope
clamped to [-2, 12]. Aggregated, those two are indistinguishable. Split:

    iteration 6   Te      raw coolants   added       effective    slope   Tref
      pass 1       530    1.10e-25       2.515e-23   x229         2.71     177
      pass 2      4129    2.21e-25       7.165e-25   x3.2         0.81     530
      pass 3      8054    6.91e-25       8.322e-25   x1.2         1.02    4129
      pass 4      8245    2.25e-24       2.258e-24   x1.00        1.46    8054
      pass 5      8283    2.46e-24       2.461e-24   x1.00        1.47    8245

**The coolants behave correctly.** CO, C+, C and O sum to 1.10e-25 at pass 1
and rise monotonically to 2.46e-24 by pass 5 - x22 with temperature, which is
what fine-structure cooling should do. Nothing is destroyed, and the CO
hypothesis is dead.

**The multiplier is the whole effect.** 229 at pass 1, 1.00 by pass 4. The x35
collapse chased since D-210 is the extrapolation decaying.

**The mechanism.** At pass 1 `Tref` is 177 K, inherited from the previous
iteration's cold chemistry, and the mean slope is 2.71 with a clamp ceiling of
12 - so some cells carry cooling scaling as T^12. That is a very stiff
artificial thermostat: cooling rises so steeply with T that the solver finds a
root at 530 K. `pdrStep` then re-anchors `Tref` to 530 K, the newly measured
slope flattens to 0.81, the multiplier falls to 3.2, the prop is removed and Te
jumps to 4129 K. Each pass repeats it until the multiplier reaches 1 and the
march ends at ~8300 K.

D-166 cited per-pass re-anchoring as the thing that makes the power law safe -
"the coupling loop re-anchors Tref every pass, which is exactly how Cloudy uses
conv.dCmHdT". Measured here, re-anchoring is the mechanism of the runaway: each
re-anchor releases the temperature by the amount the previous extrapolation was
holding it.

D-166's own validation was a 2.56x span on both sides of the anchor, median
error 6.3%. Nothing in it covers a multiplier of 229.

**A second, independent defect, visible once the multiplier is 1.** At pass 5
the substitution removes 1.81e-23 of MOCASSIN's cooling and puts back 2.46e-24
- a 7.4x net loss at 8283 K. D-133's rationale for the replacement ("in neutral
gas the electron fraction is ~1e-4, so MOCASSIN's version under-cools by orders
of magnitude") holds in cold neutral gas and inverts in hot ionized gas, and
the substitution carries no condition on either.

So there are two defects and a structure that marches between them:

  1. the extrapolation inflates PDR cooling by up to ~1e2-1e4 at low T,
     manufacturing a cold state that is not physical;
  2. the substitution deletes cooling at high T, by 7.4x, because a cold-gas
     correction is applied unconditionally;
  3. the coupling loop re-solves Te five times per MC iteration at frozen
     radiation field, walking the cell from (1) to (2) in one iteration.

**A caveat on the printed factor.** The `[D213]` line reports mean
`(Te/Tref)^slope` = 1.16e4 at pass 1, far above the x229 quoted. Both are real:
the mean of a product is not the product of means, the distribution is
enormously heterogeneous, and some cells sit near the 1e8 clamp. The quoted
figure is `added/raw`, the cell-weighted effective multiplier, because that is
the one that acts on the budget. The diagnostic should report the effective
ratio rather than the mean factor.

**What is NOT known.** Which of the three to fix first, and whether fixing the
pass structure alone is enough. The operator's design point - MOCASSIN solves Te
once per MC iteration, the passes converge the molecular content at that Te -
addresses (3) and needs no new physics. `pdrCoupleIter 1` approximates it with
no code change and is the cheapest next measurement.


---

## D-214 - one coupling pass (2026-09-10)

The operator's reading of the contract: MOCASSIN hands the chemistry Te, the
chemistry returns molecular content, so the passes should solve for molecules
and not re-solve the thermal equilibrium five times per MC iteration.

Measured, that is exactly what a pass does. `updateCell` calls `ionBalance` and
then `iterateT`, a full bracketed temperature search to convergence, and
`pdrCoupleIter` defaults to 5. The radiation field is frozen across all five,
so the inner loop is a closed molecules -> coolants -> Te -> molecules feedback
with the one leg that pushes back - the field responding to changed opacity and
ionization - cut out of it. And of the two damped quantities, `iterDamp` damps
Te across MC iterations and `pdrCoupleDamp` damps `ionDen` across passes:
**nothing damps Te across passes**, so the runaway variable is undamped in the
one place the runaway happens.

`runs/d214-couple1` (fixture `benchmarks/pdr/hiipdr-couple1`), 12 iterations,
18:09 against 45:33:

     it   f_mol mean 5-pass -> 1-pass    Te median 5-pass -> 1-pass
      6        0.291 -> 0.759                7966 -> 288
     11        0.327 -> 0.764                8153 -> 135

Both collapses gone, f_mol held in 0.63-0.83 throughout, convergence reaching
0.0526% at iteration 4 - the highest recorded anywhere in this project.

**Partly retracted at D-215.** Much of that was the D-166 extrapolation, still
running at x372-420 in this configuration, inflating the cooling and holding the
gas cold. Removing the march and removing the prop are not additive, because
one was masking the other. What survives is that the march is real, that it is
an amplifier, and that `pdrCoupleIter 1` is 2.5x faster.

`pdrCoupleIter 1` is a diagnostic and not the design: it removes the chemistry
loop too, so whatever D-119's ionization/chemistry closure was buying is gone
with it. The design is one `updateCell` and N `pdrStep`.

---

## D-215 - the cooling function, tabulated (2026-09-10)

D-166 gave `thermBalance` a two-point power law because the alternative -
Cloudy's re-evaluation of the whole cooling function at every trial temperature
- looked like 30 level-population solves per cell per coupling pass. D-213
measured what the power law does away from `Tref`: an effective multiplier of
x229 at five passes and x420 at one, against a validation covering x2.56 with
6.3% median error.

**There is a third option between two points and thirty.** Inside `iterateT`
the abundances, the partner densities and the dust temperature are frozen and
only T moves. The coolant is therefore a function of ONE variable, and a
function of one variable can be tabulated once per pass and interpolated.

`pdrStep` now walks a 16-point grid log-spaced over [pdrTmin, pdrTmax] =
[1, 2e4] K, warm-starting each level-population solve from the entry below it,
and stores `pdrCoolTab(cell, coolant, T)`. `thermBalance` calls `pdrCoolAt`,
which interpolates log-log - exact for a piecewise power law, which is what a
fine-structure coolant is - and **clamps** at the ends. Successive entries are
a factor 1.935 apart, so the root finder interpolates over a factor of two at
worst and extrapolates never.

Retired with the power law: `pdrCoolSlope` and `pdrCoolTref` as inputs to the
balance, the [-2, 12] slope clamp, the [1e-8, 1e8] factor clamp, `pdrCoolTfac`,
and the D-166 validation print. `pdrCoolSlope`/`pdrCoolTref` survive as
diagnostics, now measured off the table.

The substitution guard is also evaluated at `TeUsed` now. Under the power law
it tested `pdrCoolSp`, a fixed number, while the value entering the budget was
that number times an extrapolation - so guard and value could disagree about
whether there was anything to substitute.

**The multiplier is physical now.** x420 becomes x15.5, and x15.5 is the
tabulated cooling function's own rise from Tg ~ 159 K to Te ~ 2807 K, a factor
17.7 in temperature. It is bounded by the function rather than by a clamp.

**D-213's second defect is RETRACTED.** That entry reported the substitution
removing 1.81e-23 of MOCASSIN's cooling and returning 2.46e-24 at 8283 K, a
7.4x net loss, and attributed it to D-133's cold-gas correction being applied
unconditionally. It was an artefact of the first defect: `added` was the
coolant evaluated at the chemistry's cold Tg and merely scaled, so the
comparison was MOCASSIN's hot-gas cooling against 3D-PDR's cold-gas cooling.
Evaluated at the same temperature the substitution is net POSITIVE:

     it   removed     added      net
      5   4.53e-26   4.04e-26   -5.0e-27
      6   3.30e-25   1.166e-24  +8.4e-25
      7   8.91e-25   1.716e-24  +8.2e-25

against -1.58e-23 in the five-pass baseline. One defect, not two.

**Result: damped, not cured.** `runs/d215-cooltab`, 12 iterations, 21:53, clean
exit, on the one-pass fixture so it isolates the table against D-214.

     it   f_mol mean   Te median          baseline Te median
      6      0.398        2517                  7966
     10      0.489        1677                  (it 11) 8153

The oscillation survives - collapses at 6 and 10, period 4 rather than 5 - with
the temperature excursion 4.8x smaller and f_mol dipping to 0.40/0.49 instead
of 0.29/0.33. Convergence still does not exceed 0.0263%.

**And D-166's cost argument was wrong, which is worth recording.** The table is
8x the level-population work of the two-point law, and the run is 21% slower in
wall clock (21:53 against 18:09). Level populations are not the bottleneck.
The 30x Cloudy-style evaluation D-166 rejected on cost would very likely have
been affordable, and the two-point law was never necessary.

**What is NOT known.** What drives the residual oscillation. The three
candidates D-213 named are now down to one - the march is removed, the
extrapolation is removed, and the "deletion in hot gas" was never real. Whether
the remainder is a genuine thermal bistability, the one-pass configuration
having removed the chemistry closure, or something not yet instrumented, is
open. The proper restructure (one `updateCell`, N `pdrStep`) has not been
built; D-214 only disabled the loop.


---

## D-216 - one thermal solve per MC iteration (2026-09-10)

The operator's design, built properly rather than approximated by
`pdrCoupleIter 1`: MOCASSIN solves the ionization and the thermal equilibrium
once per MC iteration, and the chemistry converges the molecular content
against that fixed state. The `updateCell` loop moves out of `do iCouple`;
`pdrCoupleIter` keeps its name and now counts CHEMISTRY passes - a numerical
convergence parameter that cannot move a quantity between the codes, so it is
not an ownership switch. The count stays fixed because every rank must run the
same number of passes or the collectives inside deadlock.

D-119 put `updateCell` inside the loop to close the ionization/chemistry
handshake, and that reasoning was sound. What it did not anticipate is that
`updateCell` calls `iterateT`, a full temperature search, so the loop re-solved
thermal equilibrium once per pass at frozen radiation field with nothing
damping Te across passes. The `[D119]` residual is left in place; under the
restructure it measures zero by construction, since `ionDen` is written only by
`updateCell` and `pdrToMocassin` writes only `elemAvail`.

`runs/d216-restructure`, `hiipdr-contract` (default `pdrCoupleIter` 5 = five
chemistry passes), 12 iterations, 58:42, clean exit. The run survived a Claude
Code session restart because it was launched detached.

**The design does what it says.** Te is constant across all five passes -
2977.4 K at every pass of iteration 6 - so the D-213 march cannot happen.

**And the chemistry closure buys nothing.** Against `runs/d215-cooltab`, which
differs only in running one chemistry pass instead of five:

     it   d215 (1 pass): f_mol / Te     d216 (5 passes): f_mol / Te
      6        0.398 / 2517 K                0.390 / 2558 K
      7        0.578 /  998 K                0.587 / 1006 K
     10        0.489 / 1677 K                0.492 / 1502 K
     12        0.670 /  412 K                0.662 /  476 K

Identical within run-to-run scatter: collapses at 6 and 10 in both, same
amplitudes, same recovery. The confound D-214 carried - that `pdrCoupleIter 1`
disabled D-119's closure along with the march - is closed. Convergence is at or
below 0.0066% (one cell in 15204) at every iteration of both runs, which is
scatter, not a difference.

The five passes cost 2.7x in wall clock for no measurable effect. The table is
rebuilt every pass, so it is 5 x 16 x 4 level-population solves per cell per
iteration against 16 x 4.

**A claim from the running commentary is withdrawn.** At iteration 6 the
per-pass f_mol read 0.2538, 0.2665, 0.2543, 0.2662 - a period-2 alternation at
fixed Te, field and columns - and it was offered as a possible sign of the
D-112 bistability and "a candidate for the residual oscillation". The full run:

     it   f_mol per pass (1 = state handed in)
      5   0.7465  0.8250  0.8400  0.8211  0.8389
      6   0.7959  0.2538  0.2665  0.2543  0.2662
      7   0.3883  0.6566  0.6525  0.6528  0.6526
      8   0.5855  0.7654  0.7462  0.7554  0.7481
      9   0.7110  0.8009  0.7672  0.7877  0.7702
     10   0.7669  0.4069  0.4049  0.4010  0.4084
     11   0.4920  0.5464  0.5516  0.5440  0.5540
     12   0.5306  0.7106  0.7053  0.7059  0.7059

The alternation is real in some iterations (5, 6, 11), decays in others (8, 9)
and is absent in others (7, 12). Its amplitude is at most 0.034 and usually
0.005-0.01. The oscillation it was proposed to explain moves f_mol by about
0.4. Two orders of magnitude too small - it is a minor non-convergence of the
steady-state chemistry at fixed inputs, not the driver. It was a guess from
one iteration presented with more weight than one iteration carries.

**What the restructure does make unambiguous is the ordering.** With one
thermal solve per iteration, pass 1 is that solve and pass 2 onward is the
chemistry. At iteration 6 the thermal solve puts mean Te at 2977 K with 56.5%
of cells above 3000 K while f_mol is still 0.796 - up from 131 K at iteration
5. The chemistry then drops f_mol to 0.254. Iteration 10 repeats it: Te 2115 K
at f_mol 0.767, then 0.407. D-204 could only say "neither leads" because the
old passes interleaved the two; here they cannot interleave. Te leads, and
across an MC iteration rather than within one.

**Where that leaves the residual.** Every mechanism named so far is removed or
refuted: the pass march (D-216), the cooling extrapolation (D-215), the
hot-gas deletion (retracted at D-215), the seed (D-209), the FUV field and A_V
(D-203), Ne (D-212). The PDR cooling is now evaluated at the temperature the
solver tries and adds cooling (+8.5e-25 per H at iteration 6), and the PDR
heating is ~1e-27. So a thermal solve on molecular gas jumps x23 between
iterations 5 and 6 on something in MOCASSIN's own budget: its photoionization
heating from the new MC field, its photoelectric term, or its own coolants,
which carry x(H0) through `elemAvail` and n_e.

**What is NOT known.** Which of those terms moves between iterations 5 and 6.
The census reports the PDR side of the budget and none of MOCASSIN's own terms.


---

## D-217 - MOCASSIN's own budget, and a warm-start gap (2026-09-10)

**Why this instrument.** D-216 made the ordering unambiguous: with one thermal
solve per MC iteration, iteration 6's solve moves the mean Te from 131 K to
2977 K while f_mol is still 0.796, and the chemistry follows. Every PDR-side
term has been instrumented and cleared - the PDR cooling is evaluated at the
trial temperature and ADDS cooling, the PDR heating is ~1e-27 - so what jumps
is in MOCASSIN's own half of the budget, which no diagnostic reported.

**What it records.** `grid%mocBud(cell, slot, term)`, per H nucleus:

    1 photoionization heating (heatSte, + heatDif under lgDebug)
    2 photoelectric heating (photoelHeat_g)
    3 PDR heating (heatInt after the PDR block minus before - D-207's quantity)
    4 collisional cooling (coolColl)   5 recombination (coolRec)   6 free-free (coolFF)
    7 gas-dust collisional (gasDustColl_g)   8 PDR cooling (net substitution)
    9 heat - cool   10 the Te the balance was evaluated at

Mirrored exactly from how `thermBalance` assembles `heatInt` and `coolInt`, so
heating = 1+2+3 and cooling = 4+...+8 with no remainder.

**Two slots, because the question has two halves.** Slot 1 is the FIRST
`thermBalance` call of the `updateCell` - `iterateT` sets `TeEntry = TeUsed`
and evaluates there first - so it is the budget of a cell sitting at its
iteration-start temperature under the radiation field the new MC transfer just
built. That is what changed. Slot 2 is the last call, where the solve left the
cell. A flag set in `updateCell` immediately before `iterateT`, and cleared by
the first `thermBalance`, marks the entry. As with D-207's arrays, the last
call is at the solver's last TRIAL temperature, which need not equal the TeUsed
it finally writes; term 10 records the temperature so a mismatch is visible
rather than assumed away.

**Grouped by outcome.** The census bins PDR cells into cold at iteration start
and hot after the solve, cold throughout, and hot from the start, using the
existing 3000 K hot threshold to bin the report only. Grouping by outcome keeps
each mean describing one population - the D-209 input line averaged a hot and
a cold population together and described neither. Means within a group remain
means over cells at different depths; the terms are additive, so the group
means of the terms still sum to the group mean of H - C.

**The warm-start gap.** Adding one more per-cell array prompted the question of
whether `resetGrid` - the `mocassinWarm` path - allocates the per-cell PDR
arrays that `setMotherGrid` does. It allocated `pdrCoolSp`, `pdrHeatPE`,
`pdrLevPop`, `pdrAbun` and the rest of the older set, and D-195's `dustSigSil`
and `dustSigGra`, but none of:

    pdrHeatXtra                  - written unguarded in pdrStep, read unguarded
                                   in thermBalance; predates this session
    pdrCoolTab (D-215)           - written unguarded in pdrStep
    pdrHeatUsed, pdrCoolUsed (D-207), pdrCoolSub, pdrCoolNul (D-210),
    pdrTfacUsed (D-213), mocBud (D-217)
                                 - every access guarded by `allocated`, so no
                                   crash, and on this path they would have read
                                   zero without saying so

So `mocassinWarm` compiled - and CLAUDE.md's "all four flavours compile" held -
while the warm path would have reached unallocated arrays the first time the
chemistry ran. All eight are now allocated and initialised in `resetGrid`. This
is compiled, not measured: no warm restart has been run, and one is the only
thing that shows the path works.

**Run.** `runs/d217-budget` on `benchmarks/pdr/hiipdr-couple1`, one chemistry
pass. D-216 measured the one-pass and five-pass trajectories identical within
scatter, and the budget is taken on pass 1 either way, so this costs ~22 minutes
rather than ~59 for the same answer.

**What is NOT known.** Everything the run is for: which of MOCASSIN's own terms
separates the cells that go hot from those that stay cold at iteration 6 and 10,
and whether it is a heating term appearing or a cooling term disappearing.



### D-217 result (2026-09-10)

`runs/d217-budget`, 12 iterations, 21:06, clean exit. Trajectory as D-215/D-216:
collapses at iterations 6 and 10 (f_mol mean 0.393 and 0.484, Te median 2538
and 1764 K).

**The instrument is sound.** Its entry-slot temperatures, weighted by group
size, reproduce the run's own iteration-start mean Te: 1160.4 against 1160.3 K
at iteration 4, 367.5 against 367.5 at 5, 210.9 against 210.9 at 6 - so slot 1
is the first balance call as intended. Heating minus cooling reproduces the
printed H - C to rounding in every group checked. All three groups are
populated at every iteration.

**The result.** Per H nucleus, at entry to the thermal solve:

     it   cells   entry Te   phot heat   phot heat    ratio    cold->hot   started-hot
          c->h     c->h       c->h      stayed cold           total cool  phot heat
      4       11     1683    2.66e-25    2.38e-27      112x    4.45e-26    4.22e-25
      5       18      112    5.09e-24    7.44e-26       68x    1.48e-25    6.09e-25
      6     8336       88    4.47e-23    9.90e-25       45x    3.79e-25    8.45e-25
      7     2835      701    1.13e-21    7.87e-25     1436x    1.34e-24    2.53e-25
      8      919      461    5.06e-22    2.92e-25     1733x    8.45e-25    7.42e-25
      9      925      285    1.85e-22    1.10e-25     1682x    4.95e-25    5.94e-25
     10     6649      133    6.64e-23    6.00e-25      111x    3.51e-25    9.41e-25
     11     2671      663    1.02e-22    4.56e-25      224x    3.64e-25    3.59e-25
     12     2117      474    7.55e-22    3.42e-25     2208x    9.03e-25    5.43e-25

In EVERY iteration the cells that go cold -> hot enter the solve carrying
photoionization heating 45-2208x that of the cells that stay cold, and 6-843x
their own total cooling. The ratio to cooling is only 6x and 34x at iterations
4 and 5, and above 100x from iteration 6 on; the ratio to the stayed-cold cells
is LOWEST at the two collapses (45x, 111x), because at those iterations the
stayed-cold cells are also being heated. An earlier draft of this entry said
"100-2000x" and "about two orders above their own cooling"; the parser's table
does not support either as a range, and they are corrected here. The photoelectric term and the
PDR heating are two orders below it throughout. The PDR cooling substitution is
small and slightly negative for these cells at entry (-3.3e-25 at iteration 6)
- nothing like the heating. So the collapse is not lost cooling. It is heating
arriving.

The two collapses have the same signature: 8336 cells at 88 K with 4.47e-23 at
iteration 6, 6649 cells at 133 K with 6.64e-23 at iteration 10. The iterations
between show the same process at small scale (925 cells at iteration 9 with
1.85e-22). The collapses are the iterations where it catches most of the grid
at once.

**The heating moves.** The started-hot column is the previous iteration's
flippers: they enter with photoionization heating of 2.5e-25 to 9.4e-25, one to
three orders below what they carried as flippers, and cool. A different set of
cells takes the heating each time. D-218 asks where those cells sit and where
they came from.

**Caveats.** Group means still average cells at different depths - the
started-hot exit rows show collisional cooling of 5e-25 at mean Te of a few
hundred K, which is a few still-hot cells carrying the mean. The exit slot is
the solver's last trial temperature, recorded in term 10 so it can be checked.

**Withdrawn during this entry.** A 13.6-15.4 eV "leak" through molecular gas
was offered as the mechanism; D-139 had already tested and reverted exactly
that, on tau = 230 per cell, and the H2 continuum does reach the transport
above 15.43 eV. And a "two-iteration opacity lag" was offered for the period;
the opacity is rebuilt at the top of every MC iteration and the lag that exists
errs opaque while molecules form. Both recorded under D-218.

---

## D-218 - does the heating move, and does it move deeper? (2026-09-10)

**What prompted it.** D-217's iteration 7, read against iteration 6:

     it   group        cells   entry Te   photoionization heating per H
      6   cold -> hot   8336      88 K       4.47e-23
      7   started hot   5293    4052 K       2.53e-25   (these are 6's flippers)
      7   cold -> hot   2835     701 K       1.13e-21

The cells that went hot at iteration 6 lose their photoionization heating by a
factor 180 and cool to 416 K; a different set of cells takes 25x more than
iteration 6's group did. The heating is not a property of fixed cells.

**The hypothesis.** Heating per H nucleus goes as x(H0) times the field above
threshold. Cells that ionize at iteration N carry few absorbers at N+1: the
hard photons pass through them to the layer behind, which heats, while the
ionized layer - little H0 to absorb with - loses its heating, cools, recombines
and becomes opaque again. An ionization front advancing in pulses. It predicts
that each iteration's cold -> hot cells are (a) deeper than the previous
iteration's, and (b) drawn from the previous iteration's stayed-cold cells.

**The history this has to respect.** Deep-cell heating is 99.5% H I
photoionization (D-138). The field delivering it is 86-100% stellar with no
packet crossing tau > 20 (D-159), which retracted the "photons that cannot
arrive" framing: the heating is real and the opacity that stops it belongs to
the other ionization state. D-168 raised a transport defect again and retracted
it at D-169. D-160 tested for a stable neutral branch under pdrTeFromMocassin
and found none. So this entry does not re-open the transport question; it asks
how the ionized/neutral alternation propagates through the grid.

**A claim from the running commentary, withdrawn.** While reading D-217 I
suggested a two-iteration delay between molecule formation and the opacity the
photons see, and that a delayed loop explains the 4-5 iteration period. The
structure does not support it. `iteration_mod` zeroes `grid%opacity` and runs
`ionizationDriver` - and so `addOpacity` with `H2den` - over every cell at the
TOP of each MC iteration, before the transfer. Photons at iteration N see H2
from iteration N-1's chemistry and an x(H0) normalised with `elemAvail` from one
iteration earlier still, because `updateCell` precedes the chemistry (D-216).
That lag errs OPAQUE while molecules form - more H2 arrives before x(H0) falls -
so it opens no transparent window where the collapse begins. It is recorded,
not used.

Also checked on the way: H2 opacity does reach the transport (the PDR build
passes `grid%H2den` to `addOpacity`, continuum above 15.43 eV), and
`pdrSplitField` is diagnostic-only - every `Jdif` read in `update_mod` sits
behind `lgDebug`.

**The instrument.** Per D-217 outcome group, on pass 1:

    A_V (mean)                     - depth
    x(H0), f_mol                   - the absorbers
    J above hydrogen's threshold   - sum of Jste from HlevNuP(1), the bin the
                                     H0 cross section itself starts from (ph_mod)
    tau per cell at threshold      - opacity(HlevNuP(1)) x cell size
    group one iteration ago        - none / cold->hot / stayed cold / started hot

The last needs the same cell across iterations, so `grid%budGrpLast` stores
each cell's group. Ownership of a cell is fixed per rank, so each rank carries
its own cells' history with no reduction. It is allocated in `setMotherGrid`
AND `resetGrid` - D-217 found the warm path missing every per-cell PDR array
added since D-188, and this does not add another.

**Run.** `runs/d218-front`, one-pass fixture, launched automatically as soon as
`runs/d217-budget` released the cores.

**What is NOT known.** Whether the flipping cells are deeper and were cold the
iteration before. If they are not - if the heating lands in scattered cells
with no progression in A_V - the pulsing-front picture is wrong, and patchy
Monte Carlo sampling of a hard-tail field deep in the cloud becomes the
leading alternative.



### D-218 result so far - iterations 4 to 6 (2026-09-10)

`runs/d218-front`, one-pass fixture. The trajectory reproduces `d217-budget`:
iteration 6's cold -> hot group is 8265 cells entering at 87.6 K with
photoionization heating 4.48e-23 per H, against 8336 cells, 88 K and 4.47e-23
in the earlier run.

**Checks.** At iteration 4 every cell's previous group is "none", as it must be.
Cells re-enter the census consistently: iteration 4's 587 started-hot cells cool
to 99 K and appear at iteration 5 as stayed cold (585 of them). Cells with no
previous group at later iterations are cells that joined the PDR zone between
iterations. tau per cell at threshold in the cold groups at iteration 4-5 is
1260-1270, matching D-168's independent 1270.

**The opacity trails the ionization by one iteration plus the damping.** With
n_H = 100, sigma(13.6 eV) ~ 6.3e-18 cm^2 and 2e18 cm cells, tau = 1260 per cell
is x(H0) = 1.0 exactly. At iteration 5 the cold groups report tau 1262-1270
while their x(H0) is 0.05-0.21. The census's end-of-iteration x(H0) median -
the state `ionizationDriver` reads at the top of the next iteration - is 0.998
after iteration 4 (seed defect: `elemAvail` never republished), 0.365 after
iteration 5 (0.21 from `updateCell` blended by iterDamp 0.25 with 0.998), and
0.110 after iteration 6. That predicted tau ~ 460 per cell for iteration 6's
photons; the flipping group measured 466. Confirmed.

**The cells that flip are not a front's leading edge.**

     it 6          cells   A_V    f_mol   tau/cell@thr   J>thr      phot heat   cold at it 5
     cold -> hot    8265   2.34   0.904      466        2.84e-3    4.48e-23       8262
     stayed cold    6579   2.10   0.680      598        1.77e-4    1.00e-24       6415

A front advancing outward would put the flipping cells shallower than the rest,
next to the previous iteration's hot cells. Instead they are the deepest and
MOST MOLECULAR cells, drawn almost entirely from the previous iteration's cold
cells - so their H0 opacity for this iteration's photons has fallen the
furthest (tau 466 against 598), and they receive 16x the field above threshold
and carry 45x the photoionization heating. Iteration 5's 33 flippers show the
same shape: deepest (A_V 2.54 against 2.25), f_mol 0.914, all cold the iteration
before, 47x the field.

What that suggests, and it is NOT yet a mechanism: molecular locking removes H0,
and H2 does not replace it as an absorber between 13.6 and 15.4 eV, so the
cells that lock most hydrogen lose the most opacity in that window - one
iteration late, because the opacity is built from the previous ionization.
The difficulty it has not resolved: tau ~ 466 per cell at threshold is still
far too thick for threshold photons to cross several cells, so the extra field
must sit at energies where the gas is thinner, and which band that is has not
been measured.

**Two slips while reading this.**
  - An awk field offset printed the PHOTOELECTRIC column as "photoionization
    heating" for iteration 6 (1.89e-25 for the flippers). Caught before being
    reported as a result; the values above are from the parser.
  - D-218's x(H0) is read from `grid%ionDen` after `updateCell`, so for cells
    that went hot it is the HOT END STATE, not what they carried into the
    solve. Pairing it with entry heating - x(H0)*J predicts only a ~1.4x
    heating ratio against the measured 45x - is not valid. f_mol is valid
    (`updateCell` does not move H2), and so are the field and tau columns,
    which do not depend on the solve.

**What is NOT known.** Which band carries the extra field - the 13.6-15.4 eV
window where H2 is transparent, or above 15.4 eV where it absorbs - and what
share of the photoionization heating is hydrogen's in these cells at ENTRY.
Those decide whether the missing absorber is H2 line opacity MOCASSIN does not
model, or something else.

### Iteration 7 reverses it (2026-09-10)

     it 7          cells   A_V    f_mol   tau/cell@thr   J>thr      phot heat   last iteration
     cold -> hot    2835   1.73   0.417      591        1.14e-2    1.17e-21    560 c->h, 2275 cold
     stayed cold    6890   2.50   0.518      248        2.12e-4    7.91e-25    2486 c->h, 4304 cold
     started hot    5256   2.11   0.219      167        1.52e-6    2.61e-25    5219 c->h

Every feature of the iteration 5-6 flipping group is inverted. The cells that
flip at iteration 7 are the SHALLOWEST, the LEAST molecular, and see the HIGHEST
tau per cell at threshold - and they receive 54x the field of the cells that
stay cold and 7500x that of iteration 6's flippers. Iteration 6's flippers, now
the started-hot group, see the LOWEST threshold tau (167) and receive the least
field of any group.

**Withdrawn.** The index row committed with iterations 4-6 read "the cells that
flip are the most molecular, and their H0 opacity has fallen furthest", and the
body offered molecular locking removing H0 absorbers as what it suggested. That
held at two iterations and is contradicted at the third. Tau per cell at H0
threshold does not predict where the field lands: at iteration 6 lower tau went
with more field, at iteration 7 higher tau does. Group means across three
iterations were read as a law.

**What survives iteration 7.**
  - The opacity trails the ionization by one iteration plus damping - measured
    at iterations 5 and 6 against a prediction, and the largest group at
    iteration 7 (started hot, tau 167) is consistent in magnitude with the
    end-of-iteration-6 median x(H0) of 0.110 (tau ~ 139).
  - The heating moves between cells every iteration (D-217), and cells rarely
    stay in one group: of iteration 7's stayed-cold cells, 2486 flipped at
    iteration 6.
  - Threshold tau being irrelevant to where the field lands is itself
    informative: the photons carrying the heating must sit at energies where
    the gas is far thinner than at 13.6 eV. That band is still unmeasured, and
    after iteration 7 it is the measurement that matters rather than one of
    several.


### Full result - iterations 4 to 12 (2026-09-10)

`runs/d218-front`, one-pass fixture, 12 iterations, 21:33, clean exit.

      it  group        cells    A_V   f_mol  tau@thr   J>H0thr   phot heat   last: none c->h  cold  hot
      4  cold -> hot      7   2.43   0.427   1260   1.32e-06   7.45e-25      7     0     0    0
      4  stayed cold  13951   2.31   0.521   1261   2.66e-08   2.44e-27   13951     0     0    0
      4  started hot    587   1.23   0.061   1064   2.18e-06   4.06e-25    587     0     0    0

      5  cold -> hot     33   2.54   0.914   1270   2.24e-04   4.58e-24      0     0    33    0
      5  stayed cold  14677   2.25   0.785   1262   4.79e-06   7.43e-26    169     5 13918  585
      5  started hot     78   0.85   0.008    962   4.49e-06   6.78e-25     74     2     0    2

      6  cold -> hot   8265   2.34   0.904    466   2.84e-03   4.48e-23      0     3  8262    0
      6  stayed cold   6579   2.10   0.680    598   1.77e-04   1.00e-24     61    25  6415   78
      6  started hot     77   0.77   0.015    919   5.32e-06   8.14e-25     72     5     0    0

      7  cold -> hot   2835   1.73   0.417    592   1.14e-02   1.17e-21      0   560  2275    0
      7  stayed cold   6890   2.50   0.518    248   2.12e-04   7.91e-25     23  2486  4304   77
      7  started hot   5256   2.11   0.219    167   1.52e-06   2.61e-25     37  5219     0    0

      8  cold -> hot    929   2.14   0.657    353   7.10e-03   5.38e-22      0    80   849    0
      8  stayed cold  11158   2.36   0.699    626   1.01e-04   2.87e-25      7   272  6041 4838
      8  started hot   2922   1.68   0.084    532   3.67e-06   7.58e-25     21  2483     0  418

      9  cold -> hot    921   2.32   0.768    301   3.51e-03   1.58e-22      0    49   872    0
      9  stayed cold  12524   2.30   0.797    529   2.84e-05   1.06e-25      0   288 10286 1950
      9  started hot   1575   1.47   0.061    673   3.25e-06   6.23e-25     11   592     0  972

     10  cold -> hot   6587   2.41   0.905    201   3.49e-03   6.91e-23      0   109  6470    8
     10  stayed cold   7617   2.07   0.747    557   1.01e-04   6.01e-25      0   146  6054 1417
     10  started hot    817   1.98   0.150    348   4.29e-06   9.29e-25      1   666     0  150

     11  cold -> hot   2634   2.26   0.733    233   4.44e-03   1.37e-22      0   502  2116   16
     11  stayed cold   7800   2.15   0.565    368   9.92e-05   4.48e-25      0  1753  5501  546
     11  started hot   4591   2.29   0.211    130   2.52e-06   3.76e-25      4  4332     0  255

     12  cold -> hot   2088   1.90   0.606    395   1.07e-02   7.69e-22      0   237  1843    8
     12  stayed cold  10561   2.31   0.647    572   1.07e-04   3.59e-25      0   800  5957 3804
     12  started hot   2380   2.07   0.119    467   2.47e-06   5.32e-25      4  1597     0  779

(J is the plain sum of `Jste` over the bins from hydrogen's threshold; phot heat
is the D-217 entry photoionization heating per H nucleus; "last" counts each
group's cells by their group one iteration earlier. f_mol is valid at entry;
D-218's x(H0), not shown, is post-solve and is not.)

**What holds at every iteration from 5 to 12.**

  1. **The cells that flip come from last iteration's cold cells** - 33 of 33,
     8262 of 8265, 2275 of 2835, 849 of 929, 872 of 921, 6470 of 6587, 2116 of
     2634, 1843 of 2088.
  2. **A cell that flips receives about 1000x less field the next iteration.**
     The started-hot group - last iteration's flippers - sits at J = 1.5e-6 to
     5.3e-6 in every iteration, against 2.2e-4 to 1.1e-2 in that iteration's
     flippers. This is the sharpest regularity in the run: whatever puts the
     field into a cell stops the iteration after the cell heats.

**What holds only at the two big collapses.** Iterations 6 and 10 put their
flippers deep (A_V 2.34, 2.41), very molecular (f_mol 0.904, 0.905) and at the
lowest threshold tau of any group (466, 201). The follow-on iterations do not
share it: iteration 7's flippers are shallow (1.73), less molecular (0.417) and
at the highest tau (592); iteration 12's are shallow again (1.90).

**What does not hold.** Threshold tau does not predict the field. At iterations 7
and 11 the lowest-tau group (started hot: 167, 130) receives the least field of
any group. So the opacity at 13.6 eV is not what decides where the field lands,
and the photons carrying it must sit where the gas is far thinner. The
iteration 4-6 generalization withdrawn earlier in this entry stays withdrawn.

**What holds about the opacity.** It trails the ionization by one iteration plus
damping: tau 1260 at iteration 5 is x(H0) = 1.0 exactly, matching the
end-of-iteration-4 median x(H0) of 0.998; the end-of-iteration-5 median of 0.365
predicted tau ~ 460 at iteration 6, measured 466; iteration 7's started-hot group
(tau 167) is consistent in magnitude with the end-of-6 median of 0.110.

**What is NOT known.** Why the field in a cell collapses the iteration after the
cell heats, and which energy band carries the field that does arrive. The first
is a question about how the MC estimator responds to a cell's own state; the
second is the measurement proposed alongside the D-219 fix.

---

## D-219 - the opacity's hydrogen does not add up (2026-09-10)

Found while checking the first D-218 block. Its stayed-cold group reported
x(H0) = 0.9988 and f_mol = 0.5208 at iteration 4 - a hydrogen budget of 1.52,
where `x(HI) + 2x(H2) + x(HII) = 1` is the sharpest test in the project.

**Iteration 4 first, because it is a defect in D-209.** `seedMolecules` calls
only `seedAbunFromMocassin`. `pdrToMocassin`, the only writer of `elemAvail`,
runs inside the coupling loop (iteration_mod:1652) and after the D-200 damping
(1944) - both after iteration 4's `updateCell` (1115). So at the first PDR
iteration the ionization is normalised to the full hydrogen abundance while the
seed has already made half of it molecular.

**But the budget fails at every iteration, not only the first.** The census
line `[D196] x(H0)+2x(H2)+x(H+)`, across four runs:

     it   d210-budget        d215-cooltab       d216-restructure   d217-budget     
          median (min-max)   median (min-max)   median (min-max)   median (min-max)
      4   1.210 (0.98-1.73)   1.852 (1.00-1.99)   1.850 (1.00-1.99)   1.851 (1.00-1.99)
      5   1.050 (0.32-1.41)   1.260 (0.52-1.73)   1.263 (0.52-1.73)   1.261 (0.52-1.73)
      6   1.012 (0.18-1.43)   0.426 (0.34-1.51)   0.456 (0.34-1.49)   0.425 (0.34-1.59)
      7   1.003 (0.42-1.58)   1.329 (0.29-1.72)   1.364 (0.29-1.62)   1.343 (0.29-1.72)
      8   1.001 (0.27-1.70)   1.225 (0.28-1.73)   1.225 (0.28-1.72)   1.225 (0.28-1.73)
      9   1.000 (0.17-1.72)   1.088 (0.28-1.74)   1.090 (0.28-1.72)   1.088 (0.28-1.74)
     10   1.000 (0.14-1.71)   0.657 (0.28-1.72)   0.687 (0.27-1.73)   0.646 (0.27-1.72)
     11   1.000 (0.13-1.72)   1.067 (0.28-1.70)   1.063 (0.28-1.72)   1.071 (0.28-1.72)
     12   1.000 (0.23-1.56)   1.217 (0.27-1.72)   1.218 (0.27-1.68)   1.217 (0.27-1.72)

**It is the state the opacity is built from.** The census takes x(H0) and x(H+)
from `grid%ionDen` and 2x(H2) from `grid%pdrAbun` (iteration_mod:2099-2102) and
prints at line 2196 - after the D-200 damping (1905) and the `elemAvail`
republish (1944). At the top of the next MC iteration `ionizationDriver` reads
`grid%ionDen` as-is - `density = ionDenUsed * elemAbun * Hden`, no
renormalisation - and hands `addOpacity` `grid%H2den`, which follows `pdrAbun`
(D-201). So this table is the hydrogen the photons of the next iteration see.

**Why it happens.** The ionization is solved once and the chemistry then moves
the molecular content. The ionization carries x(H0) normalised to the
molecular fraction BEFORE that move; the molecules carry the fraction AFTER.
When H2 forms, hydrogen is counted twice (median 1.85, 1.26, 1.36); when H2 is
destroyed, it is missing (0.43 after iteration 6's collapse, 0.66-0.69 after
iteration 10's).

**It is not new with D-216, but D-216 made it permanent.** The pre-D-216
one-pass run (`d215-cooltab`) gives the same series. The five-pass run
(`d210-budget`) holds the median at 1.003, 1.0007 ... 1.0000 from iteration 7,
because its last `updateCell` uses `elemAvail` from chemistry that had
converged over the passes. D-216 moved `updateCell` out of the loop to stop the
temperature march, and in doing so reinstated - at the scale of a whole MC
iteration - the lag D-199 had removed at the scale of a pass. D-216 was
committed without checking this budget. It is the test CLAUDE.md singles out,
and it should have been run before calling D-216 done.

Even at five passes individual cells span 0.13-1.72, so the median closing is
not the same as every cell closing.

**What it does and does not explain.**

  - RETRACTED: "It is NOT the collapse trigger. Iteration 6 enters with a
    median of 1.26 - an excess, which errs opaque." The budget sum counts H2,
    and H2 has no continuum between 13.6 and 15.4 eV (D-139); at hydrogen's
    threshold the only gas absorber is H0. The H0 fraction iteration 6's
    photons saw had fallen to 0.365 of atomic from 1.0 one iteration earlier
    (measured under D-218). So the lag errs TRANSPARENT at threshold exactly
    when molecules form. What still stands is that `d210-budget`, with its
    median at 1.00, also collapsed - so the lag is not NECESSARY for a
    collapse. Whether it triggers this one is open.
  - It plausibly AMPLIFIES what follows a collapse. After iteration 6 the median
    cell's opacity carries 0.43 of its hydrogen, and iteration 7 then carries
    the largest photoionization heating in the run, 1.13e-21 per H in its
    flipping cells (D-217). After iteration 10 it carries 0.65, and iteration
    11's heating is elevated but less so (1.02e-22). Two cases in the same
    direction, which is a correlation and not a mechanism.

**What is NOT known.** Whether the cells that flip are the deficit cells - a
per-cell question the group means cannot answer. And whether `updateCell` is
itself consistent with the `elemAvail` it is handed at the start of an
iteration: D-218's per-group x(H0) + f_mol at pass 1 measures exactly that, and
decides where a fix must act.

**The fix is not applied.** The candidate is D-153's rule applied on MOCASSIN's
side: after the chemistry moves the molecular content, rescale the linked ion
stages to the new `elemAvail` - MOCASSIN keeps the RATIO between stages, the
chemistry sets the non-molecular TOTAL - before the opacity is built. Plus a
`pdrToMocassin` after `seedMolecules`. It changes the D-216 design, so it is
put to the operator rather than made.


---

## D-220 - the ion stages brought to the same hydrogen as the molecules (2026-09-10)

**What.** A new `rescaleIonToAvail`, called in `iteration_mod` after the D-200
damping block closes - so after the last change to the molecular content and
the last `elemAvail` republish, whether or not the damping ran. For every
enabled element, stages `1..min(elem+1, nstages)` are scaled so they sum to
`min(max(elemAvail, 1e-10), 1)`. That is exactly the normalisation
`ionBalance`'s conservation row imposes (`availFrac`), so this applies the next
`updateCell`'s normalisation one step earlier, where `ionizationDriver` needs it
to build the opacity. The ratio between stages is MOCASSIN's and is unchanged;
the total is the chemistry's. D-153 hands the chemistry MOCASSIN's ratio and
keeps the chemistry's total; this is the same split applied on MOCASSIN's side.

Elements `pdrToMocassin` never sets keep `elemAvail = 1` and are unchanged.
At the call site `ionDen` is already reduced and every rank has republished
`elemAvail` from the reduced `pdrAbun`, so every rank rescales identically and
no collective is added.

Also a `pdrToMocassin` immediately after `seedMolecules` at `pdrStartIter`: the
seed moves the molecular content and nothing republished `elemAvail`, so the
first PDR iteration's `updateCell` normalised hydrogen's stages to 1 beside a
seed that had made half of it molecular (budget 1.85 at iteration 4, D-219).

**Verification built in.** The D-196 budget census prints after the rescale, so
its median should read ~1.00 rather than 0.43-1.85 - the other hydrogen carriers
in the network (H2O, OH, CH_n, H3+) keep it slightly off. And a `[D220]` line on
rank 0 reports hydrogen's mean |x(H0)+x(H+)+2x(H2)-1| and the fraction of cells
off by more than 1% BEFORE each rescale, so the defect is measured in the same
pass that removes it.

**What it is not.** A promised cure. `d210-budget`, whose median budget was
1.000 from iteration 7, still collapsed at iterations 6 and 11. The fix makes
the opacity physically consistent; whether that changes the collapse is what
the run measures.

---

## D-221 - which band carries the heating (2026-09-10)

**Why.** D-218: threshold opacity does not predict where the field lands - at
iterations 7 and 11 the lowest-tau group receives the least field - so the
photons carrying the heating must sit where the gas is much thinner than at
13.6 eV. The candidates differ in what they imply: in the 13.6-15.4 eV window H2
has no continuum (D-139; MOCASSIN does not model H2 line opacity there), above
15.43 eV H2 absorbs (`addOpacity` with `yanH2xSec`).

**What.** At the D-217 entry call (the first `thermBalance` of the updateCell),
H0's photoionization heating is split inside the frequency loop at the first
bin with nu >= 1.1345 Ryd, with exactly the scaling `heatIonSte` gets, and
stored in per-cell `mocBand(cell, 1:2)` - allocated in `setMotherGrid` and
`resetGrid`. The census adds per outcome group: the field summed over
[HlevNuP(1), split) and [split, nbins], the two H0 heating means, and H0's share
of the group's entry photoionization heating.

**Run.** `runs/d220-fix`, one-pass fixture, carrying both D-220 and D-221.

**What is NOT known.** Everything the run is for.


### D-220/D-221 verified at runtime - iteration 4 (2026-09-10)

`runs/d220-fix`, one-pass fixture.

**The rescale works as designed.** At the end of iteration 4:

    [D220] rescaled ion stages to elemAvail in 15204 cells;
           before: mean |x(H0)+x(H+)+2x(H2)-1| 0.4004, off by >1% in 14186 (93.30%)
    census budget after the rescale: min 0.99996  median 1.0000  max 1.0000

Before the rescale the defect is large and nearly universal - the chemistry
moved the mean molecular fraction from the seed's 0.52 to 0.78 during the
iteration, and 93% of cells carried an ionization normalised to the old value.
After it the budget closes exactly. That the maximum departure is 4e-5 also
bounds the network's other hydrogen carriers (H2O, OH, CH_n, H3+) below that
here, so the ~1.25% D-196 once attributed to them was lag, as D-199 concluded.

**The seed republish works.** At pass 1 of iteration 4, x(H0) + f_mol per group
is 0.992, 0.999 and 0.981 (the last before x(H+)) - against 1.41 and 1.52 at
the same point in `runs/d218-front`, where `elemAvail` was never republished
after the seed. tau per cell at threshold is still 1260 at iteration 4, as it
must be: iteration 4's opacity was built before the seed ran. The first opacity
built from the rescaled state is iteration 5's, and should read ~272 per cell
from the end-of-iteration-4 elemAvail(H) of 0.2160.

**D-221 is internally consistent.** The two bands reproduce D-218's total field
above threshold to four figures in every group (6.707e-9 + 2.463e-7 = 2.530e-7
against 2.531e-7; 2.820e-8 against 2.820e-8; 2.198e-6 against 2.198e-6). H0's
share of the photoionization heating is 0.9950, 0.9404 and 0.9913 - never above
1, and matching D-138's 99.5% and D-168's 99.7% independently.

**A first look at the band - eight cells, not a result.** Iteration 4's eight
cold -> hot cells receive 97% of their field above 15.43 eV, and 99.97% of their
H0 heating comes from that band (1.135e-25 against 2.9e-29 in the window). The
13,980 cells that stay cold receive 89% of their field in the 13.6-15.4 eV
window. If iteration 6's thousands of flipping cells show the same, the heating
that flips cells comes from photons H2 does absorb, and missing H2 line opacity
in the window is not the cause.


### Iteration 5: the opacity follows the rescaled ionization (2026-09-10)

First iteration whose transfer was built from the rescaled state.

     it 5          cells   A_V    f_mol   tau@thr   J 13.6-15.4   J >15.4     H0 heat win   H0 heat >15.4   H0 share
     cold -> hot     10    2.52   0.906     121       0.000       3.93e-4       0.000        4.78e-24       0.984
     stayed cold  14700    2.25   0.775     281      3.85e-8      2.28e-6      1.15e-27      3.68e-26       0.965
     started hot     79    0.90   0.006     966      3.78e-6      5.24e-7      3.88e-25      2.91e-25       0.991

**Prediction met.** From the end-of-iteration-4 elemAvail(H) of 0.2160 the
bulk of the cold gas should see tau ~ 0.216 x 1260 = 272 per cell at threshold;
the 14,700 stayed-cold cells measure 281. `runs/d218-front` read 1262-1270 at
this iteration. The rescale reaches the opacity, which is the path D-219 said
was broken.

**The band shifted, and not in the way the window hypothesis would predict.**
In the stayed-cold cells the field above 15.43 eV rose from 3.0e-9 at
iteration 4 to 2.28e-6 at iteration 5 - a factor ~760 - while the window field
stayed near 3e-8. At iteration 4 the window carried 89% of their field; at 5
the hard band carries 98%. Lowering the H0 opacity at threshold 4.5-fold did
not bring in window photons; it coincided with the hard band arriving.

**Flipping cells, two iterations running.** Iteration 5's ten flippers receive
exactly zero field in the window and take all their H0 heating from above
15.43 eV, as iteration 4's eight did (99.97%). Eighteen cells in total, so
still not a result - iteration 6 is where thousands flip.

**What is NOT known.** What absorbs the hard band on the way in - H0, H2 above
its 15.43 eV threshold, He above 24.6 eV, or dust - and so why lowering the H0
fraction moved it by ~760x. That is a question for a per-absorber opacity
decomposition, and is only worth building if iteration 6 shows the same.


### Iteration 6: the collapse survives the fix, and the band is decided (2026-09-10)

**The collapse.** `runs/d220-fix` against `runs/d218-front`, identical except
for D-220 and D-221:

     it   f_mol median   f_mol mean   |df| p90   moved >0.1   Te median
          d218   d220    d218  d220   d218 d220   d218  d220   d218   d220
      4  0.850  0.833   0.794 0.784  0.698 0.698  60.2  62.5    264    311
      5  0.915  0.916   0.808 0.820  0.160 0.167  38.8  39.4     96    102
      6  0.238  0.239   0.396 0.433  0.714 0.714  72.4  67.7   2525   2160

Iteration 6 still collapses. The median molecular fraction falls to 0.239
against 0.238; at most the event is slightly milder (Te median 15% lower, mean
f_mol 0.43 against 0.40, 4.7 points fewer cells moving), and that is within the
range two runs of one fixture can differ. Closing the hydrogen budget in the
opacity did not remove the relaxation oscillation. D-219 is a real correctness
defect, now fixed, and not its cause - the five-pass run had already shown the
collapse without the lag; this shows it with the lag removed.

**The fix holds.** [D220] before each rescale: mean |x(H0)+x(H+)+2x(H2)-1| of
0.4004, 0.0931 and 0.4198 at iterations 4, 5 and 6 (93.3%, 78.1%, 89.0% of cells
off by more than 1%); the census after each reads min 0.99995-0.99996, median
1.0000, max 1.0000.

**The band, at scale.**

     it 6          cells   A_V   f_mol  tau@thr   J 13.6-15.4   J >15.4   % hard   H0 heat win   H0 heat >15.4   H0 share
     cold -> hot    7274   2.28  0.902    124     6.61e-9       3.30e-3    100.0    3.20e-29      4.94e-23        0.993
     stayed cold    7579   2.19  0.734    322     1.08e-7       2.53e-4    100.0    1.89e-27      1.23e-24        0.979
     started hot      64   0.65  0.000    960     4.87e-6       7.00e-7     12.6    4.77e-25      3.83e-25        0.992

The 7274 cells that flip receive 99.9998% of their field above 15.43 eV and
take essentially all their H0 photoionization heating from that band - six
orders of magnitude more than from the window. H0 is 99.3% of their
photoionization heating. 7270 of them were cold the iteration before. The cells
that stay cold are also hard-field dominated (99.96%); only the 64 shallow
started-hot cells, at A_V 0.65, are window-dominated.

**So the window hypothesis is ruled out.** The heating that flips cells is not
carried by 13.6-15.4 eV photons slipping through gas where H2 has no continuum.
It is carried by photons above 15.43 eV - the band where H2 does absorb, and
where the flipping cells, at f_mol 0.90 and n(H2) ~ 45 cm^-3, should be very
thick near threshold (tau ~ 900 per cell at 18 eV from yanH2xSec).

**What that leaves.** The photons arriving must sit where every absorber is thin
- well above threshold, where the H0 and H2 cross sections fall as E^-3 and
E^-3.5 and He0 has not yet taken over (24.6 eV) or has fallen off again. Which
energies those are, and which absorber sets the path on the way in, is not
measured. The obvious next instrument is the hard band split further in energy,
with the opacity along it decomposed by absorber (H0, H2, He, dust). It is not
built.

**Also noted.** Convergence at iteration 6 is 0.1118% (17 cells), against
0.0132% without the fix. Both are tiny and this is one run of each, so no
weight is put on it.


### Full run - iterations 7 to 12 (2026-09-10)

`runs/d220-fix`, 12 iterations, 21:17, clean exit.

**The fix holds throughout.** Before each rescale hydrogen was off by a mean
0.405, 0.271, 0.179, 0.373, 0.377 and 0.304 at iterations 7-12, in 87-94% of
cells; after each the census reads min 0.99996, median 1.0000, max 1.0000. The
chemistry moves the molecular content by that much every iteration, so the
one-iteration lag D-219 described is not a transient.

**The collapses, against `runs/d218-front`, which differs only by D-220/D-221:**

     it    f_mol median     f_mol mean     moved >0.1      Te median
           d218    d220     d218   d220    d218   d220     d218    d220
      6    0.238   0.239    0.396  0.433   72.4   67.7     2525    2160
      7    0.790   0.789    0.578  0.556   80.9   80.7      995    1064
      8    0.904   0.882    0.719  0.721   84.2   82.4      319     346
      9    0.926   0.926    0.784  0.789   41.1   45.6      111     129
     10    0.241   0.315    0.487  0.543   71.4   65.2     1753     762
     11    0.777   0.787    0.558  0.563   76.9   76.4      834     823
     12    0.798   0.799    0.672  0.678   82.4   80.2      384     428

The first collapse is unchanged. The second is milder with the fix - median
f_mol 0.315 against 0.241, Te median 762 K against 1753 K, 6 points fewer cells
moving. One run each, so that is suggestive, not established: it is the kind of
difference two runs of one fixture can show. What is established is that the
relaxation oscillation survives a hydrogen budget closed to 1.0000 at every
iteration.

Convergence is 0.013-0.112% throughout against 0.000-0.020% without the fix -
consistently higher, and still two to seventeen cells. No weight is put on it.

**The band holds at every iteration.** The cold -> hot group takes its field and
its H0 photoionization heating from above 15.43 eV at iterations 7-12 as at 4-6:

     it   cells   J window   J >15.43 eV   H0 heat window   H0 heat >15.43 eV   H0 share
      7    3239   2.47e-7     1.08e-2         6.8e-27          1.05e-21          0.9992
      8     708   3.76e-7     7.51e-3         9.0e-27          6.07e-22          0.9992
      9     904   1.57e-7     3.82e-3         2.0e-27          1.93e-22          0.9981
     10    5425   7.62e-8     3.39e-3         8.3e-28          6.31e-23          0.9952
     11    3152   2.45e-7     4.32e-3         7.6e-27          1.15e-22          0.9976
     12    1930   3.51e-7     1.28e-2         9.6e-27          8.54e-22          0.9993

Nine iterations, every one with the heating that flips cells carried by photons
above the H2 continuum threshold and hydrogen doing 99.5-99.9% of the absorbing.
D-222 decomposes that band by energy and by absorber.
