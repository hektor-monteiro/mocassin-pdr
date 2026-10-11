# DEVLOG-H2 - the H2 level model (branch h2-model)

The development log of the `h2-model` branch (DEVLOG D-388): the same rules
as DEVLOG.md - every discussion and decision gets an entry, a summary row
here and a dated body below, with what was measured, what it means and what
is not yet known. Entries are H-numbered; at the final merge they are folded
into DEVLOG.md. Production's own history (D-001..D-388 and on) is in
DEVLOG.md and arrives here by merge.

| ID | Summary | Status | Date |
|---|---|---|---|
| H-001 | **Branch created at the user's go-ahead (D-388): `h2-model` from c27e658, tagged `pdr-coupling-v1.1` on production, in worktree ~/software/mocassin_h2, with this log and a CLAUDE.md note (own install prefix, own runs/, merge production in regularly).** Plan: D-387's transition-zone H2 excess is diagnosed on production first; then stage A (D-385), the post-processing H2 level model | Done | 2026-09-28 |
| H-002 | **Production's D-389 merged in, and turned into requirements for the H2 model.** Cloudy's pn150k H2 lines all come from the PDR (2.121 um at emission-weighted 118 K, pumped; rotational lines at ~60 K). Whether the transition zone adds collisional emission (Aleman & Gruenwald) turns on the TZ H2 abundance, 1e-10 (Cloudy) / 1e-7 (ours) / 1e-5 (A&G), which is set by how gas-phase H2 survives electrons. So the model needs: level-resolved formation (H2+ route at 1.83 eV, H- associative detachment, grains); destruction of excited levels by electrons (dissociative attachment) and by collisions; collisions with e-, H+, H at thousands of K; UV pumping; and, in stage B, the chemistry's TZ H2 following from it. First validation target: Cloudy's pn150k PDR H2 lines (d389-cloudy-h2s has the per-zone emissivities) | Open | 2026-09-28 |
| H-003 | **Stage A, step 1: the X-state level solver (`source/h2_mod.f90`), re-implemented from Cloudy c25.00's data and conventions, matches Cloudy's large H2 model to 0-0.5% on every level that collisions and radiative decay set, across 15 one-zone models (T 50-3000 K, n_H 1e2-1e6).** Data vendored into dataPDR/h2 with provenance and the zlib notice (X energies, Wolniewicz et al. A values, the five default collision sets). Levels: 302 X, energy-ordered; colliders H, He, o-H2, p-H2, H+; linear-in-T interpolation held at the table ends; g-bar for same-spin pairs without data; detailed balance on (2J+1)(2I+1). One defect found by the comparison and fixed: transprob_X lists some transitions twice (E2 + M1, Pachucki & Komasa 2011), which Cloudy adds; overwriting them had doubled v=1 populations at low density. Test: `make h2Test`, `tools/h003_compare.py runs/h003-cloudy-lev`. Not yet included: formation into levels, destruction, cosmic rays, UV pumping (the non-thermal populations, which is where the remaining differences are), electrons. All four flavours build | Done | 2026-09-28 |
| H-004 | **Stage A, step 2: ultraviolet pumping. The excited electronic states (B, C+, C-, B', D+, D-: 1,592 levels, 32,453 lines to X, Abgrall et al. 2000) are in `h2_mod`, with the cascade back into X, the Solomon dissociation rate per level, and formation on grains in Takahashi & Uehara's (v, J) distribution. Against 16 one-zone Cloudy models (T 100 and 1000 K, n_H 1e2-1e6, FUV 1-1e4 Habing), with Cloudy's own populations put in: pump rate per level 1.000, Solomon rate of H2g 1.000, radiative rate into each level 0.996-1.001.** Solomon rate of H2* 0.94-0.96, and 0.997-0.998 once Cloudy's direct photodissociation of H2* (all H2* taken at 2.5 eV) is added - a process not yet in ours. **Our own populations differ from Cloudy's by 0.07 dex in the median (v >= 1 levels 8-21% lower in each model's median at 1-100 Habing, ground levels up to 24% higher at 1e4), and the cause is Cloudy's bookkeeping, not its rates:** it applies its network's H2g Solomon rate a second time as a uniform sink on the H2g levels, solves the levels without a sum rule, and rescales every population by one factor f (1.06-1.11 at n <= 1e4, read off its own saved rates). Our rates put through that scheme reproduce Cloudy's populations to 0.002-0.018 dex in 15 of 16 models (0.040 in the other) and its f to 0.021 or better. Not adopted: ours replaces each destroyed molecule by a formed one and keeps the sum. Line ratios are unaffected (2-1 S(1)/1-0 S(1) = 0.53-0.55 at low density in both, equal to 0.005 in 15 models). Three hypotheses discarded (formation distribution, H- route, LTE-distributed sources). Two of 18 Cloudy models had too little H2 for its large model to run. Next: line self-shielding | Done | 2026-10-02 |
| H-005 | **Stage A, step 3: self-shielding of the pumping lines and trapping of the fluorescent photons, marched through a Cloudy PDR slab (100 K, n_H 1e4, 100 Habing, to A_V = 3). The model's shielding - a Voigt line integrated numerically, damping from the upper level's total decay rate, averaged through each zone - follows Draine & Bertoldi's (1996) shielding function without its overlap factor to 0.79-1.00 from N(H2) = 1e18 to 1e21. Cloudy's own H2g Solomon rate is 0.28-0.36 of DB96 at N(H2) = 1e17-1e20, because it takes each line's damping from that line's own A: the upper level's total decay rate is 20x larger in the median (8-157).** Machinery checked first, with Cloudy's choices put in (Federman fit, own-A damping, its optical depths): line-centre tau and damping agree to 0.04% and 0.00% over 1,216 thick lines; pump rate per level in the shielded zones 0.97-1.00 of Cloudy's at N(H2) = 1e15-1e20; with photon trapping the H2g Solomon rate 0.93-0.97; and through Cloudy's closure (H-004) its excited fraction 0.92-0.98. **For the same slab the model's excited-level columns are 2.4x Cloudy's (v >= 1 levels 1.7-3.9x, median 2.45), and all its pumping absorptions 3.2x the Cloudy-like march's.** Not in yet: line overlap (DB96's factor is 0.9 at 1e19, 0.7 at 1e20, 0.3 at 1e21; 30% of the pumping lies above 1e20). Our ortho/para ratio reaches 60 in a thin layer at N(H2) ~ 1e16 (Cloudy 5.4), unchecked. Next: line overlap, then the field and columns from a MOCASSIN run | Done | 2026-10-02 |
| H-006 | **Stage A, step 4: line overlap. Each pumping line's shielding is now its own times the mean transmission of all the other H2 lines over the frequencies where it absorbs, a six-point quadrature placed by the line's own absorption (`lineOverlap`). Against the exact integral on a 0.05 cm^-1 grid across the whole band, the factor overlap puts on the H2g Solomon rate is reproduced to 0.2-1.6% from N(H2) = 1e17 to 3e20 and 4.5% at 1e21 (exact 0.96, 0.93, 0.86, 0.65, 0.49, 0.32), and the exact factor is within 5% of Draine & Bertoldi's overlap term.** In the slab the model's shielding is now 0.70-0.95 of the full DB96 fit at 1e18-1e21. **H-005's numbers are revised: overlap lowers the model's total pumping by 33% (H-005 estimated 20%), and its excited-level columns are 1.63x Cloudy's (v >= 1 levels 1.25-2.77, median 1.66), not 2.44x.** Cost ~55 ms per call, so a cell computes it once and reuses it while iterating. Not in: shading by H I Lyman lines; a photon absorbed in another line's wing is counted as lost, not as a pump of that line. Next: the field and level columns from a MOCASSIN run | Done | 2026-10-02 |
| H-007 | **Stage A, step 5: the level model inside MOCASSIN, on the finished model (`pdr_mod` `h2LevelModel`, called on every rank before the final output; 3D build).** Per cell: MOCASSIN's Te and the chemistry's densities; the MC field in the bin of each pumping line, split as pdrStep splits it (direct part behind the star-ward level columns, diffuse part on traceDiffuseSites' scattering sites behind their two-leg level columns); line shielding and overlap averaged through the cell's own column; photon escape over the twelve line rays; formation on silicate and carbonaceous surfaces in the proportion of the chemistry's own rate on each. Other cells' populations are the previous sweep's; sweeps repeat until four lines move by under 1%. Output: lineFluxH2.out, h2Cells.out (with the chemistry's own H2 photodissociation rate beside the levels'), h2Pop.bin. **First full run (hiipdr 21^3, 4,661 cells): 4 sweeps, 286 s on 14 ranks; 1-0 S(1) = 6.2e33 erg/s = 7.2e-4 Hbeta, 2-1 S(1)/1-0 S(1) = 0.53; the levels' Solomon rate is 2.6x the chemistry's in the ionized gas, 1.5-1.8x in unshielded cold gas, 0.4-0.7x in shielded gas.** The in-code field conversion agrees with an offline one from pdrFUVspec.out to 3-8%. The result is sensitive to how the cell's own column is treated (4.6x in 1-0 S(1) between leaving it out of the diffuse part and averaging through it): the pumping layer is inside one or two cells. **pn150k 41^3 against Cloudy: 2.12 um 1.12x, 17.0 um 1.03x, 28.2 um 0.85x, 12.28 um 2.36x; the totals agree by cancellation (2.12 and 17.0 um 1.5-4.7x Cloudy's where H2 turns on, 0.3-0.8x deep), the column ortho/para is 0.04-0.06 against 0.31 because the shielded gas is 15-20 K colder (both near thermal), and N(0,4) is 2.2-2.5x at every depth (hypothesis: the damping width, as H-005; collisions ruled out). Level model 62 of 98 min, overlap 53% of the timed work. hiipdr 21/31/41^3: 1-0 S(1) 6.22/8.38/8.64e33 erg/s (+35%, +3.0%), totals converge, the transition's H2 profile does not** | Done | 2026-10-02 |
| H-008 | **The damping width alone, as a diagnostic (one line of h2LineParams, not committed): pn150k rerun with each line damped by its own A, as Cloudy does, against H-007's run with the upper level's total decay rate. The two runs are byte-identical outside the level model (MOCASSIN is reproducible at fixed np), so the comparison is exact. With Cloudy's width the 12.28 um excess goes (2.37x -> 0.62x Cloudy; N(0,4) 0.56-0.91x along the axes), but every pumped line falls 2.1-3.8x: 2.12 um 0.52x Cloudy, 17.0 um 0.31x, 28.2 um 0.23x. Lines behind < 1e14 cm^-2 of H2 are unchanged; behind > 1e16 they fall to 0.18-0.41 (sqrt(1/20) = 0.22, the damping wings). In the H-005 slab the same change takes the excited columns from 1.63x to 0.60x Cloudy's.** So H-007's agreement of three lines was two factors of 2-4 cancelling. The model keeps its width (the natural width; Cloudy itself uses the upper level's lifetime for every other species, its H2 alone the line's A). What remains with equal widths (0.23-0.62) is not isolated: the closure, the colder gas, the H2 at the front | Done | 2026-10-03 |
| H-009 | **Cloudy's closure on pn150k (diagnostic patch kept in tools/patches/, validated on H-004's 16 one-zone models: populations within 0.003-0.032 dex of Cloudy's, f 1.002-1.082). With Cloudy's width and closure together the four H-007 lines are 0.63 (2.12 um), 0.27 (28.2), 0.37 (17.0) and 0.77 (12.28) of Cloudy's; the closure raises all by ~1.2. Over Cloudy's 40 strongest H2 lines (tools/h009_lines.py) the 11 vibrational para lines are then 0.85-1.03 of Cloudy's and the 20 ortho lines 0.49-0.68: what is left in the pumped lines is the ortho/para ratio of the gas, which follows our colder shielded gas.** H-007's 1-0 S(1) agreement = width x2.1 x closure /1.2 x ortho fraction ~0.55-0.6. Our chemistry destroys H2 almost only by photodissociation (93-100% to 0.43 pc); Cloudy's, deep, 25-69%, the rest by Cl+, HCl+, O+ and cosmic rays (no chlorine in our network). The closure alone (model's width) raises the lines by the same 1.17-1.21: the two choices are independent to 1-2%. The width's factor is larger for para lines (x3.2) than ortho (x2.2), as para pumping sits deeper in the damping wings. Nothing changes in the code | Done | 2026-10-03 |
| H-010 | **Cloudy's small H2 model computes no line intensities** (H2_LinesAdd returns when the large model is off): H2g, one H2* pseudo-level, Solomon and pumping rates from fits in G0 and total N(H2) (Elwert et al. 2005), fixed H2* decay 2e-7 s^-1, fitted heating, Glover & Abel rotational cooling. Not usable: no lines, and fitted stand-ins for what MOCASSIN computes. From Cloudy's large model: the lowest 70 levels by matrix and the rest by back-substitution applies to our solve (a median pn150k H2 cell has 10 levels above 1e-8, 80 above 1e-10); its H2/H > 1e-8 limit covers only 0.8% of pn150k's cells; its overlap at line centre is too crude (1-6% vs 14-35%). The overlap (53% of the cost) is best cut by reuse across sweeps | Discussion | 2026-10-03 |
| H-011 | **The level model 2.5x faster on pn150k (3,736 -> 1,474 s; the run 98 -> 60 min) and 4x on hiipdr 21^3 (283 -> 71 s), lines within 2.5e-4 of H-007 and the rest of the outputs byte-identical.** A third of the wall time was ranks waiting: the i7-14700's 8 performance and 12 efficiency cores run 14 ranks at speeds 2x apart, which no static deal sees; the ranks now take cells from a shared MPI-3 counter (a window MPI allocates: one on the program's memory stalls on its target and was slower than the static deal). lineOverlap reorganised exactly (separate long and short lists, windows as index ranges, branch-free wing sums, thin lines in wavenumber order with pointers): 2.3-2.5x. The solution: collision rates cached by T, Gauss column by column, byte-identical, 3.2x. Shielding prepared once per cell and per line. A cell's passes no longer floored at three (1.0-1.6 instead of 3.0; lines move by at most 6.6e-5). Dropped: a grid for the far wings (4e-4 error, no gain), -O3 -march=native (not established) | Done | 2026-10-03 |
| H-012 | **Stage B, step 1: the chemistry's H2 photodissociation rate is the level model's. `iterateMC` calls `h2LevelModel(grid, 1)` every PDR iteration before the PDR step (one sweep from the last call's populations, on this iteration's field and the last chemistry), and pdrStep hands the reaction the cell's Solomon rate in place of the network's single-line rate; CALC_HEATING reads the same rate. Every cell with gas is solved; no switch; the 1D build keeps the network's rate and says so.** hiipdr 21^3, B against A: sum rule unchanged (-1.9e-7 .. +3e-8); x(H2) 1.3-2.5x higher at 7-10.5 pc (shielded gas, where the levels' rate is the lower), half at the 5.7 pc edge; the front one cell (0.97 pc) toward the star; Te unchanged to 0.5 K; Hbeta unchanged to 1e-4; vibrational lines 1.07x, rotational 1.24-1.26x (*corrected 2026-10-04, H-014: the 21^3 grid's; at 31^3, with step 2 too, 0.82-0.83x and 0.92-1.03x, the edge thinning as on pn150k*). **Convergence, 11 against 16 iterations: B's lines move 0.1-1.6%, A's 0.2-2.7%, Hbeta 2.5% in both (the ionized gas's own convergence, D-365's L-40); B/A 1.09x and 1.27-1.29x at 16.** Per call the Solomon rate moves 50-60% (median per cell) between iterations but 3.4% on a fixed field: the Monte Carlo field's noise in each line's bin, ~1.5x the band-integrated rate's; in the transition x(H2) per cell scatters ~2x more than in A, the cloud's total destruction by 1.4%. Cost +2.4 min (11 iterations). Groundwork for step 2 in h2_mod, not called: dissociation heating per level, net collisional heating within X. **pn150k (2026-10-04): the opposite sign, for the same reason - at the transition's lit edge the levels' rate is 1.3-2.5x the chemistry's, so 0.195-0.325 pc loses 59-95% of its H2 and the front moves one cell (0.015 pc) out; 1-0 S(1) 0.73x, rotational 0.80-0.95x; against Cloudy's 40 strongest lines ortho 0.86-1.05 -> 0.69-0.77, para 1.63-2.63 -> 1.47-2.40. Not converged in 9 iterations: the per-call rate change falls 0.86 -> 0.33 and is 9% on a fixed field; 1-0 S(1) still rising 15-17% a step. +8 min (1 h 08 min)** The converged comparison is H-013's | Done | 2026-10-03 |
| H-013 | **Stage B, step 2a: the H2 heating from the levels, beside 3D-PDR's, nothing handed over. h2LevelModel gives per cell the atoms' kinetic energy from dissociation and the net heating by collisions within X (Cloudy's HeatDiss, HeatDexc; the latter is also H2's line cooling, which nothing in either code has), and the kinetic energy of a molecule formed on a grain by energy conservation on Takahashi & Uehara's distribution (silicate 0.834 eV, carbonaceous 1.142; 3D-PDR 1.5; Cloudy gives the gas nothing for it). pdrStep keeps 3D-PDR's three H2 terms; h2Cells.out has both, per H, with MOCASSIN's budget (tools/h012_heat.py).** Outputs byte-identical otherwise. hiipdr 21^3: levels/3D-PDR = formation 0.55, dissociation 1.08 (0.438 eV), collisions 32x pumping but never above 0.6% of the heating; the three 0.67, i.e. 3-7% off the PDR's heating if handed over. pn150k at 14 iterations: H-012's transition settles (1-0 S(1) steps halving, ~2% left; rate change on a fixed field 1.9%), front one cell inside stage A's at 9, lines 0.90-1.06 of A's; heating ratios 0.76 / 1.07 / 5.5, the three 0.87, collisions never above 1.2%. **Step 2b: the three handed over in pdrStep, held through MOCASSIN's temperature search like the rest of pdrHeatXtra; on hiipdr every PDR shell 0.3-1.0 K (1-3%) colder, lines within 2%; on pn150k 0.1-4 K, lines within 1%.** **Stage B against stage A on pn150k, both at 14 iterations (A was not converged at 9 either: lines +6-10%): the warm lit edge thins (x(H2) 0.06-0.74 of A's at 0.195-0.325 pc), the shielded gas gains 5-8%, the front stays within a cell; 1-0 S(1) and 2-1 S(1) 0.82-0.83x, rotational 0.91-1.00x; against Cloudy's 40 strongest lines ortho 0.92-1.15 -> 0.81-0.95, para 1.75-2.81 -> 1.71-2.73 (the width, H-008)** | Done | 2026-10-04 |
| H-014 | **Artifacts: stage B on the three comparison pages.** `tools/h013_figures.py`: stage A against stage B against Cloudy in the Cloudy pages' style, six panels per fixture (transition, the photodissociation rate each chemistry used, T_gas, the H2 heating terms, the H2 line emissivities, carbon); pn150k both at 14 iterations, hiipdr 21^3 at 11. H2 Lines in MOCASSIN v4 gains a Stage B section with both fixtures; hiipdr Against Cloudy v19 and 150 kK PN Against Cloudy v17 gain a section marked as the h2-model branch, everything else on them unchanged. Read off: pn150k's edge n(H2) at A_V 0.20 is 1.6x Cloudy's in stage B against 26x in stage A, crossing unchanged (0.395/0.396 vs 0.368); hiipdr's crossing 1.505 -> 1.409 vs 1.090. **Then, at the user's question, the pages' whole-model figures too: pn150k from the stage-B run, hiipdr from a new 31^3 stage-B run (the page's resolution; stage A at 31^3 is H-007's run, which reproduces the page's numbers). At 31^3 hiipdr behaves like pn150k: the edge thins (x(H2) 0.12-0.46 of A's), the crossing moves 0.04 mag (1.447 -> 1.407), vibrational lines 0.82-0.83x, rotational 0.92-1.03x - the 21^3 ratios (1.05x, 1.23-1.27x) were the grid's.** Pages: H2 Lines v5, hiipdr v20, pn150k v18 | Done | 2026-10-04 |
| H-015 | **The pages rebuilt on stage B, every number from the pages' own tools: hiipdr Against Cloudy v21 (31^3), 150 kK PN Against Cloudy v19/v20 (14 iterations), hiipdr Against 3D-PDR v2 with the reference re-run on stage B's face field (G0 119.73, from x(H+) < 0.3; `d275_3dpdr_reference.py` now reads pdrGrid v2; new `h014_3dpdr_kpis.py` reproduces the D-275 page), H2 Lines v6 (cost past H-011, stage B's calls).** **pn150k is not converged at 9 iterations: from 9 to 14, He II 4686 +16%, [O III] 4363 +13%, the He2+ front 0.083 -> 0.087 pc (Cloudy 0.088), Hbeta -1.5%, in stage A and B alike, while the convergence percentage stays at 92%; production's 9-iteration runs are affected.** Against 3D-PDR now: crossing 1.407 vs 1.548 (1.192 vs 1.558 at D-275), PDR gas 0.25-0.34 of the slab's (0.11-0.34), deep C+ 0.2 of it (1e-7). Corrected: D-275's field slope 3.34/mag and H2O claim, v16's CO 0.09x, v18's stage B cost. Stage B's level-model time on pn150k 62.5 min per 14-iteration run against stage A's 24.4 | Done | 2026-10-04 |
| H-016 | **Stage A first, the level model only at the end? From the logs: on pn150k 41^3 stage B's calls take 62.5 min per 14-iteration run, 29 of them during the PDR's build-up (iterations 4-9), against stage A's single 24.4-min call; a cold start on a converged model needs 2-3 sweeps (the first overshoots dissociations by 38%); the coupling's tail halves per iteration (pumping +7%, +4%, +2%, +1%, +0.5% over iterations 10-14).** Estimate: switching at iteration 10 saves ~20 min (15-20%) at 41^3; fine grids need threads in the level model more than a schedule. An iteration keyword would be the run-time ownership switch CLAUDE.md warns about; if adopted, the network rate becomes only the starting guess, with stage B's own convergence test before the run may finish. Proposed test: stage A to 9, mocassinWarm with stage B 10-14, against the all-stage-B run. **Decided: not adopted - the user keeps the full level solution every iteration, as the more self-consistent; the test is not run** | Done | 2026-10-04 |
| H-017 | **What is pending, at the user's question: the merge of stage B (D-388: after every benchmark; not yet the 1D flavour, the warm start, the fine grids), iteration counts and a convergence test that sees helium and slow drifts (L-40, H-015; *corrected: x(H2) is tested, at 10% per iteration*), and the physics divergences O-02, L-43, L-33, L-37, pn150k's neon and low ions, deep O+/He+ against 3D-PDR.** New: `h2Pop.bin` is written and never read, so a warm start restarts the level model cold | Discussion | 2026-10-04 |
| H-018 | **Production's D-391 merged in (e60a836, no conflicts): the per-cell x(H2) test had passed every cell since D-216 and now runs after the chemistry; a model-integrated test (emission measures, H0/H2/CO contents, weighted temperatures; convTotals, default 2% over 3 iterations) gates the stop and every run reports whether it converged.** By it, the pages' runs were not converged: pn150k at 14 (He2+ 5.8% over the window, lines up to 5% from iteration 20), hiipdr 31^3 at 11 (O+ 5.9%, lines up to 8%); 2% is reached at 17 and 15. Merged branch: four flavours and h2Test/h2Slab rc 0; a stage B run reports the new test and exits cleanly | Done | 2026-10-04 |
| H-019 | **The integrated test decides the stop (production D-392 merged, 2abfebe; default 2%, the strict end of the user's 2-5%), and the pages' runs are re-made at convergence: stage B for hiipdr 31^3 and pn150k 41^3 stopped by the test, stage A at the same counts, then the 3D-PDR reference and the four pages.** hiipdr stops at 15, pn150k at 18; all four pages republished | Done | 2026-10-05 |
| H-020 | **The warm start resumes the level populations: h2Pop.bin was written and read by nothing, so a resumed run's first call started from Boltzmann; it is now read back when it describes this grid and level set (checked), else Boltzmann as before, said.** Resumed, the first call is within 0.6% of the checkpointed run's last (Solomon dissociations); withheld, +93%. With production's D-393 (the PDR continues instead of being re-seeded) merged in | Done | 2026-10-04 |
| H-021 | **The user: "lets work on the gaps in H2 formation and destruction" (H-017 items 4-5). L-33 is withdrawn (production D-394, merged): Cloudy forms 94-95% of its grain H2 as H2*, a channel the comparison never read; with it, our grain coefficient is 0.86-1.00 of Cloudy's (pn150k) and 0.50-0.91 (hiipdr, silicate surface energies). L-43 stands: transition-zone H2 24-665x Cloudy's at A_V 0.05-0.13 on pn150k, where Cloudy's H2* is 0.5-1.3% of its H2 and its H- outnumbers its H2 10^2-10^4 times. The plan: the level model takes the level-resolved channels (H2+ + H and H- + H into levels, dissociative attachment and the H2+ charge transfer back out by detailed balance, H- in local balance), measured first** | In progress | 2026-10-05 |
| H-022 | **Diagnostic: hiipdr stage B with Cloudy's Cazaux & Tielens surface energies (tools/patches/h022_ct02_cloudy_set.patch, not adopted), seeded against runs/h019-B-hii31 at 15 iterations. The crossing moves 1.400 -> 1.363 (Cloudy 1.090): the parameter set is 0.04 of the 0.31 mag, the rest is not formation. Lit-edge H2 x2.9-4.5 (still 63x short of Cloudy's at A_V 1.0), T +0.5-1.3 K, H2 lines +14-33%, everything else <1%** | Done | 2026-10-05 |
| H-023 | **D-395's seeded pairs on this branch (reaction 332, e- + H2+ -> e- + H + H+, merged from production), at the converged counts.** hiipdr (`runs/h023-eh2p-hii31`, 15 iterations, 40:55): the zone's H2+ falls 2-2.8x and its H2 halves where x(H+) = 0.5-0.99, still 14-62x Cloudy's. pn150k (`runs/h023-eh2p-pn41`, 18, 2:29:55): H2+ falls 2.6-7x, to 3-4x Cloudy's (was 9-22x); H2 falls 1.6-4.1x, still 30-230x. Fronts, crossings, Hbeta and every PDR shell unchanged; the H2 lines within 0.2%. What is left of the zone's H2 is the level-resolved part of H-021's plan | Done | 2026-10-05 |
| H-024 | **H-022's 'next': hiipdr's lit edge cell by cell. The 4000x column lag was a definition - h2Cells' N(H2) is the column to a cell's near face, and at A_V 0.50 the cells are the front cells themselves; at the cell centre it is 2-3x Cloudy's - and what was left was mostly the reference.** Like for like the lit-edge H2 at A_V 0.55-0.60 is 1.95-2.4x low, which formation (0.49-0.55, the silicate surface energies) and destruction (0.97-1.28) reproduce. The rest of hiipdr's gap was in Cloudy: no microturbulence, and the small H2 model's Elwert et al. (2005) shielding, 1.4-3.3x stronger than its own large model at N = 1e15-1e17 (production D-396, merged). Cloudy's crossing moves 1.090 -> 1.280 against our 1.400; n(H2) like for like is 1.0x Cloudy's at A_V 0.70 and 0.54x at 1.0 (H-022: 7x and 280x short). Our FUV field falls faster with A_V than Cloudy's, so it is not the field. hiipdr's H2 lines against Cloudy's large model, measured for the first time: ortho 0.82-0.84, para 1.13-1.19 (corrected the same day: 0.37 and 0.50 were against an emergent line list, D-396) | Done | 2026-10-05 |
| H-025 | **H-024's 'found, not fixed' was not an on-axis curiosity: every shielding column was sampled once per step of a cell width, and the path between the target cell's face and the end of the first step was never counted. Against the exact path on the same ray, the star-ward N(H2) was a median 0.46-0.75 of the true one through hiipdr's transition and 0.64-0.82 through pn150k's (production D-397, merged: `rayCells`).** The level model's `starColumns` and site columns take the same routine. Checked: the new columns equal an independent exact integral in all 15,191 cells (1.000); A_V equals 0.159737 mag/pc times the exact path in every cell to 3e-8, where the sampled A_V was off by -0.058 to +0.057 mag (median -0.028) at the inner cavity's edge; 36 mirrored rays agree with a brute-force walk to 3e14 cm. Also (production D-398): a scattering site's first leg runs to the site, not to the near face of its cell. **Measured (seeded pairs): hiipdr's crossing 10.028 -> 9.847 (D-397) -> 9.781 pc (D-398), A_V 1.396 against Cloudy's 1.280; pn150k's 0.3706 -> 0.3637 pc, A_V 0.393 against 0.368. Every H2 line falls, 6-8% on hiipdr and 3-4% on pn150k; the ortho/para split against Cloudy does not move (hiipdr ortho 0.75-0.78, para 1.05-1.10; pn150k 0.91-1.11, 1.88-2.62).** The site walk costs 1.4-1.6x, 4-5% of the level model | Done | 2026-10-09 |
| H-026 | **The damping width in stage B, where the levels' rate is the chemistry's (H-008's one line, now `tools/patches/h008_cloudy_width.patch`; a diagnostic, not adopted). hiipdr, seeded pair at 15 iterations: with each line damped by its own A, as Cloudy's H2, the H/H2 crossing moves from A_V 1.396 to 1.188 (9.78 to 8.52 pc, two cells), past Cloudy's 1.280 (8.95 pc). The remaining 0.12 mag was therefore not 'the width and the surface energies': it is +0.21 from the width and -0.09 from everything else.** The split by spin goes with it: ortho 0.46-0.57 and para 0.50-0.54 of Cloudy's, where they were 0.75-0.78 and 1.05-1.10; with equal widths every H2 line is about half Cloudy's, as on pn150k in stage A (H-008). Fronts, Hbeta and the C+/C crossing do not move; the transition gas is 1-4 K warmer (to within 2.3 K of Cloudy's at 7.8-9.7 pc) on 13% less heating, [C II] 158 um -2.2%. **pn150k, seeded pair at 18 iterations (2026-10-10): the crossing moves from A_V 0.393 to 0.294 (0.364 to 0.275 pc, six cells), past Cloudy's 0.368: +0.099 from the width against a published gap of 0.026.** Its ortho lines come to 0.45-0.69 and its para lines to 0.70-0.93 of Cloudy's (0.91-1.11 and 1.88-2.62); a factor 1.3-1.6 between the spins stays, the colder shielded gas (H-009). The PDR is 1.5-3.2 K warmer and still 8-12 K below Cloudy's; CO 2-1 +42%. **Cloudy's saved rates show its chlorine (Cl+ + H2, HCl+ + H2) is 25-50% of its H2 sink from A_V 0.26 on; Cloudy rerun without chlorine (`runs/h026-cloudy-pn-noCl`) crosses at 0.326. If the pieces add, pn150k's +0.026 = +0.099 (width) - 0.042 (chlorine, which the REDUCED network lacks) - 0.031 (the rest); hiipdr, with no chlorine in either model, +0.116 = +0.208 - 0.092.** The model keeps its width; whether to add chlorine to the network is open | Done | 2026-10-10 |
| H-027 | **Production's D-402 (one x(X+): the same neutral/first-ion balance in both solvers) merged; what it does to this branch's H2 results.** Seeded pairs with H-026's published runs, level model in the loop (stage B). The H/H2 crossing does not move: hiipdr A_V 1.3961 -> 1.3962, pn150k 0.3931 -> 0.3927. hiipdr lines / Hbeta: 1-0 S(1) 7.032e-4 -> 6.988e-4 (-0.6%), 2-1 S(1) -0.6%, 0-0 S(0), S(1), S(2) -1.8, -0.8, +0.2%. pn150k: 1-0 S(1) 9.449e-4 -> 9.383e-4 (-0.7%), 2-1 S(1) -0.7%, 0-0 S(2) -0.5%, 0-0 S(1) -2.4%, S(0) -4.0% - the transition zone 3-6% colder, which traces to one charge-transfer coefficient (He+ + H; D-402, L-48). Ionized-zone H2 unchanged on hiipdr, +7-8% on pn150k (17-19 times Cloudy's; not attributed). No change to the level model; its cost per call is the day's (x1.20-1.28 on untouched code). hiipdr's outer shell now reaches the 10 K floor and is left out of the atomic and CO lines (not of `lineFluxH2.out`'s H2 lines, which move 0.1% between the two floors) | Done | 2026-10-10 |
| H-028 | **Production's D-403 merged (charge transfer with H by the gas at hand in both solvers; hydrogen's side of He+ + H in `ionBalance`; the temperature floor's default at 2.725 K); what it does to this branch's H2 results: nothing beyond 0.3%.** Seeded against H-027's runs. Crossings: pn150k A_V 0.3927 -> 0.3927, hiipdr 1.3962 -> 1.3959. pn150k lines against H-027's: 1-0 S(1) +0.3%, 0-0 S(0), S(1), S(2) +0.1, -0.1, +0.1%; hiipdr's within 0.1%. So pn150k's 0-0 S(0) and S(1) stay 3.9 and 2.5% below their values from before the shared ionization balance, with the Kingdon & Ferland fit back above 6,000 K: H-027's reading, that this loss was the size of helium's coefficient at the front, is refuted - it is the transfer below 6,000 K, where MOCASSIN had effectively none before, cooling the gas behind the front (4,805 -> 4,642 -> 4,614 K, 519 -> 485 -> 488 K). hiipdr run with no floor keyword gives what `teFloor 2.725` gave. One merge conflict (`pdr_mod.f90`, before the solve; both sides kept: the level model's H2 rate and D-403's charge-transfer rows). Page: H2 Lines in MOCASSIN, version 11 | Done | 2026-10-11 |

---

## H-001 - The branch (2026-09-28)

The user agreed to D-388's refinements ("proceed"). Created:
  - **tag `pdr-coupling-v1.1`** (annotated) on production at c27e658, the
    commit recording D-388;
  - **branch `h2-model`** from the same commit, checked out in the worktree
    `~/software/mocassin_h2`;
  - **this log**, and a note at the top of this branch's CLAUDE.md: log
    here, install with `PREFIX=$(HOME)/.local/mocassin_h2`, runs in this
    worktree, merge production in regularly, and the feedback stage is
    physics when merged, not a keyword.

**One hazard found while setting up.** Both checkouts' binaries have the
data directory compiled in (`-DPREFIX`, Makefile line 26:
`$(HOME)/.local`). A plain `make install` from this branch would therefore
change the data that production runs read. The Makefile assigns PREFIX
without `override`, so `make PREFIX=...` on the command line is enough.

### Plan (from D-385, D-387, D-388)

  1. **On production:** find what sets the transition-zone H2 in MOCASSIN
     (100-1000x Cloudy's, D-387). Grain formation near 1e4 K, and missing
     ionized-gas destruction (EUV photoionization of H2, electron
     collisional dissociation) are the candidates. A fix belongs to
     production and merges in here.
  2. **Here, stage A.** An H2 level model on the converged model, as post-
     processing:
       - ~300 X levels, with the B and C states radiatively;
       - collisions with H, He, H2, H+ and e- (Aleman & Gruenwald 2011's
         set; Cloudy's data where it has them);
       - UV pumping with per-line self-shielding along D-377's 12 rays;
       - outputs lineFluxH2.out, `mol`-style maps, and the model's Solomon
         rate against the chemistry's.
     Validated on pn150k against Cloudy's big H2 model, and against
     Aleman & Gruenwald's H2/Brgamma at 150 kK.
  3. **Here, stage B:** the feedback, after stage A is validated.

---

## H-002 - Requirements from D-389 (2026-09-28)

Production (pdr-photoionization) diagnosed D-387's transition-zone H2 excess
as D-389, merged in here.

### What it shows

  - **Cloudy's pn150k H2 lines all come from the PDR.** Per-zone
    emissivities in `runs/d389-cloudy-h2s` (production worktree), r^2
    weighted:
      - 1-0 S(1) 2.121 um arises at an emission-weighted 118 K, pumped;
      - 0-0 S(0), S(1), S(2) arise at 59-61 K;
      - none arises at x(H+) > 0.05.
  - **Cloudy's TZ destroys gas-phase H2 before it relaxes.** It forms H2*
    by H + H- (~90%) and H + H2+ (5-7%), and destroys it by e- + H2* -> H
    + H- (~100%). The ground H2 left is grain-made.
  - **Ours** (REDUCED) turns H2+ + H into ground H2 directly, 500x more.
  - **Aleman & Gruenwald's code** keeps ~1e-5, which makes the TZ a
    collisional H2 emitter.

### Requirements for the H2 model

  1. **Formation into specific levels.** Grains (a Black & Dalgarno-type
     distribution), the H2+ route (1.83 eV), and H- associative detachment
     (Launay et al. 1991 level-resolved), even though REDUCED has no H-. The
     H- route can be taken from the model's own H- balance or added to the
     network. That is a design decision for later.
  2. **Destruction by level:** dissociative attachment by electrons
     (strongly v-dependent), and collisional dissociation from excited
     levels (Lepp & Shull 1983's distribution, or level-resolved rates).
  3. **Colliders** e-, H+, H, He and H2 over 10-2e4 K.
  4. **UV pumping** with per-line self-shielding (D-385).
  5. **Stage B:** the chemistry's H2 in the TZ follows from 1-2 rather
     than from REDUCED's ground-state-only channels. That is where L-43 is
     cured.

### Validation targets

  - Cloudy pn150k's PDR H2 lines: 1-0 S(1) 8.0e-5 Hbeta, 0-0 S(0) 1.7e-4
    (D-384), with their depth profiles from the rerun. *(Corrected
    2026-10-02, D-390: 8.0e-5 was the 2.12101 um line; Cloudy's 1-0 S(1)
    is `H2 2.12125m`, 9.4e-4 Hbeta.)*
  - Aleman & Gruenwald's H2/Brgamma at 150 kK.
  - Where the codes disagree (the TZ), the result is reported, not tuned.

---

## H-003 - The X-level solver, checked against Cloudy (2026-09-28)

The user: "proceed" (stage A, D-385/H-002). Built in the h2-model worktree.

### What was built

  - **`dataPDR/h2/`:** seven files copied unmodified from Cloudy c25.00's
    data/h2, with a README giving provenance, the per-file references and
    Cloudy's zlib notice:
      - X energies (Komasa et al. 2011);
      - X A values (Wolniewicz et al. 1998, plus Pachucki & Komasa 2011 M1);
      - collision rates for the five colliders Cloudy uses by default: H
        (Lique 2015), He (ORNL), o-H2 and p-H2 (Wan et al. 2018), H+
        (Gerlich 1990).
    2.8 MB.
  - **`source/h2_mod.f90`**, standalone (not yet in the MOCASSIN build):
      - `h2ReadX` parses the data: `#` and `//` comments cut, the magic
        number, the temperature grid, then (v', J', v, J, k(T)) rows;
      - levels are sorted by energy;
      - `h2SolveX(T, dens(5), pops)` solves statistical equilibrium under
        collisions (table, else g-bar for same-spin pairs, linear in T and
        held at the ends, detailed balance on (2J+1)(2I+1)) and radiative
        decay;
      - a dense Gaussian elimination with partial pivoting, level 1's
        equation replaced by normalization.
    Each convention follows Cloudy's source (h2.cpp, atmdat.cpp
    InterpCollRate, mole_h2_coll.cpp) so the check is like for like. The
    header says it is a re-implementation, not a translation.
  - **`source/h2Test.f90`** and the `make h2Test` target: a case file in,
    populations out.
  - **`tools/h003_compare.py`:** builds each case from Cloudy's own zone
    (H, H+, He from `save species densities`; o-H2 and p-H2 from `save H2
    populations`), runs h2Test, and compares level by level.

### The reference: 15 one-zone Cloudy models

`runs/h003-cloudy-lev` (this worktree), from Cloudy's tsuite template
`h2_cr_grains.in`:
  - a 30 kK blackbody with the ionizing part extinguished and the FUV at
    1e-8 erg s^-1 cm^-2 (pumping negligible);
  - cosmic-ray background, ISM abundances;
  - constant T = 50, 100, 300, 1000, 3000 K; n_H = 1e2, 1e4, 1e6;
  - one zone, three iterations, `database H2`.
~10 s each.

### Result

On every level that collisions and radiative decay set, ours/Cloudy is
0.995-1.005:
  - v = 0, J = 0-7 at T >= 1000 K;
  - v = 0, J <= 3-4 at 100 K;
  - v = 1, J = 1, 3 (the 2.12 um upper level) at 1000 and 3000 K;
  - all 75 levels above 1e-10 at 3000 K, 1e2 cm^-3 (median 0.000 dex).
Ortho/para agrees to 0.1% at T >= 300 K and to 2.4% at 50 K, where
Cloudy's grain conversion and o/p = 3 formation act.

Populations are never negative, and sum to 1 within the printed precision
(as low as 1e-318 at 50 K).

**Where it differs, it is missing physics.** The v >= 2 and high-J levels
at 50-300 K, and the high levels at 3000 K and high density, are orders of
magnitude above collisional equilibrium in Cloudy. There they are set by
formation into excited levels, cosmic rays and residual pumping, none of
which is in yet.

**One defect found by the comparison, fixed.** transprob_X.dat lists some
v = 1 -> 0 transitions twice: the E2 value, then an M1 component (Pachucki
& Komasa 2011), e.g. (1,1)->(0,1) 4.289e-7 then 7.131e-10. Cloudy adds the
components (`Aul() += Aul`). The first reader overwrote them, which cut
v = 1's decay in half and doubled its population at low density (2.0x at
1000 K, 1e2 cm^-3). It now adds them.

### Not yet in

Formation into specific levels (grains, H2+, H-), destruction by level
(dissociative attachment, collisional dissociation), cosmic-ray excitation,
UV pumping through B/C/B'/D with self-shielding, and electrons as
colliders (Aleman & Gruenwald; Cloudy has none). Next: UV pumping, the
process that makes pn150k's H2 lines (D-389).

### Status

Done. The four MOCASSIN flavours build on the branch (h2_mod is not yet in
them) and so does h2Test.

## H-004 - Ultraviolet pumping, checked against Cloudy (2026-10-02)

The user: "proceed with next steps". H-003's log named the step: UV
pumping, the process that makes pn150k's H2 lines (D-389).

### What was built

  - **Data:** 19 more files copied unmodified from Cloudy c25.00's data/h2
    (README updated): energies, A values to X and dissociation rates of the
    six excited electronic states B, C+, C-, B', D+, D- (Abgrall, Roueff &
    Drira 2000), and the dissociation energies. dataPDR/h2 is now 3.7 MB.
  - **`h2ReadElec`:** 1,592 excited levels and 32,453 lines to X.
      - Cloudy's reading rule is followed: a file's data end at its first
        empty line. That is why D- stops at v = 2 (75 levels of 352): the
        file has an empty line before the levels "above the dissociation
        limit". 3,138 D- lines are dropped with them, and 392 lines whose
        lower level is beyond the 302 X levels.
      - Ortho/para of the excited levels follows Cloudy: B, C+, B', D+ are
        ortho for even J; C- and D- for odd J. No line changes the spin.
      - A line listed twice would add, as in X; none is.
  - **`h2PumpRates(eta, W, kdiss, pump)`:** for a photon occupation number
    eta at each line (shielding is the caller's):
      - absorption l -> u at A_ul (g_u/g_l) eta;
      - the excited level returns to X level l' with probability
        A_ul'/Gamma_u or dissociates with probability D_u/Gamma_u,
        Gamma_u = sum A (1 + eta) + D_u;
      - so W(l, l') is a rate matrix within X, kdiss(l) the Solomon rate
        out of each level, pump(l) the total absorption rate.
    The excited levels are never populations to solve for; they live
    ~1e-8 s.
  - **`h2FormDist(surf, phi)`:** the (v, J) distribution of H2 formed on a
    grain, Takahashi & Uehara 2001, for ice, silicate and carbonaceous
    surfaces, as Cloudy applies it by default.
  - **`h2Solve(T, dens, eta, phi, pops, ...)`:** collisions and radiative
    decay (H-003, now `h2CollRad`) plus W, with a sink kdiss per level and
    the closure that every molecule destroyed is replaced by one formed in
    phi. The sum of the populations is fixed at 1. `h2SolveX` is the same
    balance without a field.
  - **`h2Test`:** a second case format with a field file and the three
    surface weights; `dump` writes W and the collision matrix.
  - **`tools/h004_compare.py`** (five checks, below),
    **`tools/h004_figures.py`** and **`tools/h004_cloudy_grid.sh`**.

### The reference: 18 one-zone Cloudy models

`runs/h004-cloudy-pump` (not tracked; `tools/h004_cloudy_grid.sh` writes
the inputs): H-003's setup with a real field and without
`no induced processes`: a 30 kK blackbody cut at 1 Ryd, 1.6e-3 erg cm^-2
s^-1 x (1, 1e2, 1e4) over 0.4412-1 Ryd; T = 100, 1000 K; n_H = 1e2, 1e4,
1e6; one zone. Saved: populations with their rates, the continuum, species
densities, the network's H2 and H2* creation and destruction rates, the
grain formation rate per size bin.

Two of them (n_H = 1e2 at 1e4 Habing, both T) have H2/H ~ 1e-10 and Cloudy
never evaluates its large model there. 16 are compared.

Each comparison uses Cloudy's own zone: its colliders, its continuum as an
occupation number per mesh cell (what its pump rate uses), and its
carbon/silicate split of grain formation (46-55% on carbonaceous
grains).

### Result 1: the rates agree

With Cloudy's populations put into our rates, so that only the rates are
compared:

| check | ours / Cloudy, 16 models |
|---|---|
| A: pump rate out of each of the 70 levels Cloudy solves by matrix | 1.000 (min 1.000, max 1.000) |
| S: Solomon rate of H2g (levels below 4100 cm^-1) | 1.000 |
| S: Solomon rate of H2* | 0.938-0.962 |
| S: the same plus Cloudy's direct photodissociation of H2* | 0.997-0.998 |
| B: radiative rate into each level (return from the excited states plus decays from higher X levels) | median 0.999-1.000, min 0.996, max 1.001 |

The H2* difference is a process, not an error: Cloudy's network adds
direct photodissociation into the continuum with every H2* molecule taken
at 2.5 eV (6e-19 cm^2 times the photon flux from 1.07896 Ryd - 2.5 eV to
1.14 Ryd; its source marks it "a pretty bad approximation"). Rebuilt from
the same field it closes the gap. Ours has no direct photodissociation yet.

The formation distribution also agrees: the fraction formed above
4100 cm^-1 is 0.9771 in ours and 0.97713 in Cloudy's network.

### Result 2: the populations differ by ~0.07 dex, and why

Our solution against Cloudy's populations (check C):

| | 1-100 Habing | 1e4 Habing |
|---|---|---|
| v >= 1 levels, ours/Cloudy, median per model | 0.79-0.92 | 0.96-1.00 |
| the same, all levels | 0.61-1.03 | 0.77-1.09 |
| v = 0, J = 0-3 | 0.88-1.09 | 0.66-1.24 |
| median abs(log10 ratio), all 302 levels | 0.035-0.104 | 0.003-0.018 |
| 1-0 S(1) emissivity per H2 | 0.84-0.95 (1.00 at 1000 K, 1e6, 1 Habing) | 0.97-1.04 |

Line ratios are not affected: 2-1 S(1)/1-0 S(1) is 0.527-0.546 at
n_H = 1e2 in ours and 0.529-0.547 in Cloudy (the pure-fluorescence value),
and the two agree to 0.005 in 15 models and to 0.012 in the other.

**The cause is how Cloudy closes its level system** (mole_h2.cpp,
atom_leveln.cpp), read off its source and then measured:
  - the formation source into the levels is fixed by its chemistry
    network, in cm^-3 s^-1;
  - `H2_X_sink_and_source` adds to every H2g level a uniform sink
    "sink_left" = the network's total H2 destruction rate minus the sinks
    resolved by level. The network's rate is the Solomon rate, which the
    level solver already has through the excited states; so the H2g
    Solomon rate is applied twice;
  - the levels are solved without a sum rule (the 70 lowest by matrix with
    sources and sinks, the rest one by one as in/out), and every
    population is then multiplied by `H2_renorm_conserve` = n(H2)/sum.
At the fixed point a level above the matrix therefore has
n out = f (in + source) with f that factor. Cloudy's own saved rates
show it: f = 1.0885 (16-84%: 1.0880-1.0907) over the 232 levels above the
matrix at 100 K, 1e2, 1 Habing; 1.06-1.11 at n_H <= 1e4 and <= 100 Habing,
1.00 at 1e6 and at 1e4 Habing.

**Check D: our rates through that scheme.** With the same double sink, no
sum rule and a factor f fixed by the sum, our rates give:

| | 16 models |
|---|---|
| f, ours against Cloudy's | within 0.007 in 15, 0.021 in the other (e.g. 1.0822 / 1.0885, 1.0601 / 1.0636) |
| median abs(log10 ratio) of populations | 0.002-0.018 in 15 models, 0.040 in T1000_n6_G0 (0.035-0.104 for our solution at 1-100 Habing) |
| twelve key levels (v = 0-6) | 0.96-1.05 in 13 models |

So the difference of check C is Cloudy's closure, to within a few percent.

**Not adopted.** Our closure - each destroyed molecule replaced by a formed
one, the sum fixed - is the statistical equilibrium of the processes that
are in. Cloudy's rescaling raises its excited populations above what its
own rates support. Reported as a divergence, not tuned away.

### Hypotheses discarded on the way

  - **The formation distribution differs.** No: the fraction above
    4100 cm^-1 agrees to four digits, and in the 1e4-Habing models the
    source implied by Cloudy's rates is 0.92-1.00 of phi F level by level.
  - **Formation through H-** (4% of formation at 1000 K, 1e2). No: the
    excess is the same at 100 K, where that route is 0.1%.
  - **Cloudy's LTE-distributed "source_left".** No: at 100 K it cannot
    reach v >= 5, where the excess was first seen.
The excess was proportional to each level's radiative input (8.85% of it,
to three digits, in five levels), which is what pointed to a factor on
the whole balance.

### What is not yet known

  - **Check D's residuals.** Three models keep many levels more than 5%
    from Cloudy's in check D (levels above 1e-8): T1000_n2_G0 (99 levels,
    worst (2,27) at 0.64), T1000_n6_G0 (246, around 0.9) and T100_n6_G2
    (133). v = 0, J = 0-1 at 100 K, n_H = 1e6 and 1e2-1e4 Habing are
    0.54-0.95 of Cloudy's (0.66-1.04 in our solution). Candidates, none
    tested: the H- route (4% of formation at 1000 K, 1e2), Cloudy's other
    network formation routes put into the levels in an LTE distribution,
    its grain-surface ortho-para conversion.
  - **One residual is identified:** (4,0) is 0.75 of Cloudy's in
    T1000_n4_G4. Cloudy puts all of H2+ + H -> H2 + H+ into that level.
  - **Direct photodissociation from excited levels** is 4-6% of the H2*
    destruction in Cloudy's crude form. Ours needs it level by level
    (Allison & Dalgarno 1969), with the other destruction processes.
  - **Self-shielding.** All of this is an unshielded field. In a PDR the
    pumping lines are optically thick and the rates fall by orders of
    magnitude; that is the next step.
  - Whether Cloudy's absolute H2 line intensities in a full model carry
    the same factor f: these are one-zone models. To be measured when a
    slab is compared.

### Figures

`tools/h004_figures.py` on the arrays of `h004_compare.py --save`:
excitation diagram and population ratio against level energy, for
T100_n4_G2 and T1000_n6_G4. Published with the two tables as the artifact
"H2 Pumping Check": https://claude.ai/artifact/NcToc4rA4vGTRygK9EYc1r

### Status

Done. The four MOCASSIN flavours build on the branch (h2_mod is still
outside them) and so does h2Test. H-003's comparison is unchanged by the
refactoring.

## H-005 - Self-shielding and photon trapping, checked on a Cloudy slab (2026-10-02)

The user: "proceed" (to H-004's next step, line self-shielding checked
against a Cloudy slab).

### What was built

  - **`h2Voigt`:** the Voigt function (Humlicek 1982).
  - **`h2Shield(tau0, a[, dtau])`:** the fraction of a beam left in a
    Voigt line of central optical depth tau0 and damping parameter a,
    S = (1/sqrt(pi)) int H(a,x) exp(-tau0 H(a,x)/H(a,0)) dx, integrated
    numerically and tabulated once with its integral W (the curve of
    growth) on 161 x 29 points (tau0 1e-4..1e16, a 1e-7..1). With `dtau` it
    returns the mean through a layer that adds dtau, (W(tau0 + dtau) -
    W(tau0))/dtau: a cell thick in a line is averaged, not sampled.
  - **`h2LineShield(Ncol, b, shield[, dNcol])`:** per line,
    tau0 = N_l (g_u/g_l) A_ul lambda^3/(8 pi^1.5 b) and
    a = Gamma_u lambda/(4 pi b), Gamma_u = sum A + D_u the upper level's
    total decay rate.
  - **`h2LineEscape(Ncol(:,dirs), b, beta)`** and `beta` in `h2PumpRates`
    and `h2Solve`: a photon emitted in a thick line is absorbed again on
    the spot, so each decay counts by its escape probability, the mean over
    directions of the same function S. The excited level's other decays
    and its dissociation take the share.
  - **`h2ShieldFederman`:** Cloudy's default fit (Federman, Glassgold & Kwan
    1979), for the like-for-like check only.
  - **`source/h2Slab.f90`** (`make h2Slab`): the level model marched through
    a slab zone by zone, as it will be run on a finished MOCASSIN model -
    each zone's gas and continuum given, levels solved, their columns
    shading the next zone; two passes so that the far-side column is known
    for the escape. Modes `voigt` (the model) and `federman` (Cloudy's
    choices). The ortho and para H2 that collide are the model's own,
    iterated in each zone.
  - **Tools:** `tools/h005_cloudy_slab.py` (writes the Cloudy inputs),
    `h005_compare.py` (the march and checks T, O, R, D, P, N),
    `h005_cuts.py` (rate-by-rate checks in the shielded zones),
    `h005_figures.py`.
  - **Makefile:** h2Test.o and h2Slab.o now depend on h2_mod.o. Without
    it a changed interface left a stale driver that crashed.

**S and W were checked** against an independent quadrature (scipy's wofz):
0.04% and 0.03% at worst over tau0 1e-2..1e11, a 1e-6..1e-1. The Federman
fit is 0.98-1.18 of S over the same grid.

### The reference

`runs/h005-cloudy-slab/n4_G2_T100`: H-004's field at 100 Habing,
n_H = 1e4 cm^-3, constant 100 K, `database H2`, two iterations, stopped at
A_V = 3 (634 zones, N(H2) = 2.7e21). Saved per zone: densities, all 302
level populations, H2 rates, the continuum every 5 zones; at the end the
level columns and every line's optical depth.
`set save resolution 1e-6 absorption` takes the line absorption out of
the saved continuum, which is then the field the pump rates use
(checked in six of the 128 saved blocks: smooth to 3% across neighbouring
cells at 912-1100 A, 8% in the last).

Then the same slab stopped at the zones where N(H2) reaches 1e15, 1e17,
1e19, 1e20 (`_N15` .. `_N20`), which gives Cloudy's full last-zone output
in shielded gas: each level's rates in and out, and the network's Solomon
rates.

### Result 1: the machinery, like for like

With Cloudy's choices put in:

| check | result |
|---|---|
| line-centre tau0, ours from Cloudy's level columns / Cloudy's line-specific tau, 1,216 lines with tau0 > 1 | median 1.0004, 1.000-1.004 |
| damping from the line's own A / Cloudy's | 1.0000, 0.9995-1.0005 |
| pump rate per level in the last zone at N(H2) = 1e15, 1e17, 1e19, 1e20 (Cloudy's total tau) | median 0.999, 1.000, 0.991, 0.972 |
| the same with the line-specific tau (no overlap) | 1.005, 1.015, 1.020, 1.028 |
| H2g Solomon rate there, no trapping | 0.912, 0.892, 0.848, 0.806 |
| with trapping | 0.949, 0.972, 0.963, 0.925 |
| excited fraction f*, our rates through Cloudy's closure (H-004) | 0.958, 0.980, 0.964, 0.922 |
| Cloudy's rescaling factor f, from its rates / from ours | 1.0825 / 1.0703, 1.0722 / 1.0615, 1.0621 / 1.0488, 1.0643 / 1.0430 |

The 1-3% in the pump rate at 1e19 and 1e20 is the continuum: the saved
field is the zone's far face, and that zone holds 16% and 9% of the column.

**Trapping is needed.** Without it the rate into v = 0, J = 0-5 from the
excited states was up to 2,200x Cloudy's in the shielded zones, and the
Solomon rate 10-20% low: Cloudy multiplies each decay by its escape
probability (two-sided), which closes the thick lines to the ground levels
and sends those decays to excited levels and to dissociation. With the
same in ours the Solomon rate comes within 3-8%. The residual is the
escape function: ours is S along the two normals, Cloudy's is Hummer's K2
with a wing correction plus destruction by the continuum.

**Line overlap in Cloudy** (its optical depth holds the other lines at each
line's centre): total over specific tau0 is 1.000 in the median, 1.13 at
the 84th percentile, 5.5 at the 95th; it changes the pump rate per level by
1-6% in the median at these four depths (13% for one level).

**The like-for-like march** (`federman`) ends with v = 0, J = 0-2 columns
at 0.999-1.002 of Cloudy's and N(H2*) at 0.73 (v >= 1 levels 0.60-0.90). The
missing quarter is Cloudy's closure, not a rate: in the four truncated
slabs our closed solution has f* = 0.60-0.77 of Cloudy's where our rates
through Cloudy's scheme give 0.92-0.98.

### Result 2: the model's own shielding against Draine & Bertoldi

The H2g Solomon rate over its surface value, with the continuum's own
attenuation at 912-1100 A divided out, against DB96's eq. 37 at
b = 0.908 km/s:

| N(H2) [cm^-2] | 1e14 | 1e15 | 1e16 | 1e17 | 1e18 | 1e19 | 1e20 | 3e20 | 1e21 |
|---|---|---|---|---|---|---|---|---|---|
| model / DB96 | 1.19 | 1.57 | 1.42 | 1.27 | 1.03 | 1.03 | 1.30 | 1.67 | 2.63 |
| model / DB96 without its overlap factor | 1.19 | 1.57 | 1.42 | 1.25 | 0.99 | 0.91 | 0.88 | 0.86 | 0.79 |
| Cloudy-like march / DB96 | 1.25 | 1.56 | 0.99 | 0.68 | 0.28 | 0.28 | 0.33 | 0.42 | 0.66 |
| Cloudy itself / DB96 (truncated slabs) | | 2.23 | | 0.35 | | 0.28 | 0.36 | | |

In the damping-wing regime the model follows DB96 without overlap to
0.79-1.00, and what separates it from the full DB96 is the overlap factor,
which the model does not have. Cloudy sits 2.8-3.6x below.

**The cause in Cloudy** is in its source and in its output:
`mole_h2_create.cpp` sets `dampXvel = Aul/EnergyWN/PI4`, the line's own
A, and the saved damping constants equal A_ul lambda/(4 pi b) to 0.05%.
The natural width of a line is the upper level's total decay rate. Over
the 1,216 thick lines that rate is 20x the line's A in the median
(16-84%: 7.8-157), and the wing shielding goes as sqrt(a). (Cloudy's
hydrogenic lines use the level lifetime, `iso_create.cpp`.)

**Consequence for the same slab:**

| | model / Cloudy | Cloudy-like march / Cloudy |
|---|---|---|
| N(v=0, J=0-2) | 0.994-1.004 | 0.999-1.002 |
| N(0,4), N(0,5), N(0,7) | 3.01, 2.45, 2.25 | 0.76, 0.67, 0.63 |
| N(1,3), upper level of 2.12 um | 2.64 | 0.80 |
| N(H2*), all levels above 4100 cm^-1 | 2.44 | 0.73 |
| v >= 1 levels | 1.72-3.94, median 2.45 | 0.60-0.90, median 0.74 |
| pumping absorptions through the slab [cm^-2 s^-1] | 9.73e8 | 3.08e8 |

So for a PDR like this one the model's fluorescent H2 emission is about
2.4x Cloudy's, and D-389's Cloudy line fluxes for pn150k (2.121 um at
8.0e-5 Hbeta) are low by a factor of this order if the same holds there.
Not measured on pn150k. *(Corrected 2026-10-02, D-390 and H-007: the
8.0e-5 was a different line; Cloudy's 1-0 S(1) is 9.4e-4 Hbeta, and the
level model inside MOCASSIN gives 1.12x it on pn150k. The level the
slab's damping difference raised most, N(0,4), is 2.2-2.5x Cloudy's
there.)*

### Where the pumping happens

Share of all absorptions below N(H2): 4% below 1e16, 14% below 1e18, 33%
below 1e19, 71% below 1e20, 90% below 3e20. So 30% of the pumping lies
where DB96's overlap factor is below 0.7. Weighting each bin by that
factor gives about 0.8 for the whole: **overlap would lower the model's
total pumping here by roughly 20%.** An estimate, not a calculation.

### Divergences reported, not tuned

  - **The closure** (H-004), now also in shielded gas: Cloudy's excited
    populations are 1.3-1.7x our closed solution's for the same rates.
  - **The damping width**: above.
  - **Ortho/para.** In our march the local ortho/para ratio rises to 12 at
    N(H2) = 1e15 and peaks at 60 at 1.4e16 (76 in the Cloudy-like march),
    above 6 from 5e14 to 9e16, and is back to 2.3 by 1e18; Cloudy's peaks
    at 5.4. The cause in ours, inferred from the closure and not measured
    separately: the ortho lines are thick first, so para H2 is dissociated
    faster (20x for a ratio of 60, since what is destroyed is replaced
    3:1), and conversion by H+ and H is slower than destruction there.
    Cloudy's second, uniform Solomon sink dilutes the selectivity. The
    layer holds less than 1e17 cm^-2, so the columns do not see it
    (v = 0, J = 0-2 agree to 0.6%).

### Hypotheses discarded on the way

  - **The saved continuum still carries line absorption.** No: it is
    smooth, and the extra attenuation beyond dust at A_V > 1.5 is the C I
    ionization continuum.
  - **Cloudy's network Solomon rate does not fall with depth.** My error:
    the table reader took the first zone's row of a per-zone file.
  - **Cloudy's small return into v = 0 at depth cannot be trapping, since
    its escape probability is at least 0.5 at the far face.** Wrong: the
    last zone is taken at its inner face and its own optical depth lies on
    the far side.
  - A crash of h2Test after the interface change was a stale object file
    (Makefile dependency, fixed), not the code.

### What is not yet known

  - **Line overlap** in the model: the ~20% above is an estimate from
    DB96's factor. H I Lyman lines are not in it either.
  - **The ortho/para ratio of 60:** no independent calculation to compare
    with.
  - **The escape function.** Two normal directions here; twelve rays in a
    MOCASSIN run. Its effect on the result is the 10-20% of the trapping
    itself; the difference between escape functions was not isolated.
  - **Other conditions.** One slab: 100 K, 1e4, 100 Habing, no turbulence.
    Thermal balance, warmer gas and higher field/density are untested.
  - **Coarse cells.** The zone average of S is exact for a uniform cell,
    but a MOCASSIN cell across the H/H2 transition is not uniform. Not
    tested.
  - **The continuum.** At A_V > 1.5 the C I ionization continuum takes a
    large part of the 912-1100 A field in Cloudy. Whether MOCASSIN's FUV
    field in PDR cells has that opacity is to be checked at the
    integration step.
  - Whether Cloudy's damping width is a known choice or a defect: not
    looked up.

### Figures

`tools/h005_figures.py`: the shielding of the Solomon rate against N(H2)
(model, Cloudy-like march, Cloudy at four depths, DB96 with and without
overlap), and the level columns over Cloudy's against level energy.
Published with the tables as the artifact "H2 Shielding Check":
https://claude.ai/artifact/UGwgcHXfQ72aNyBnEG194Q

### Status

Done. The four MOCASSIN flavours build on the branch (h2_mod is still
outside them), and h2Test and h2Slab. H-003's and H-004's comparisons are
unchanged.

## H-006 - Line overlap (2026-10-02)

The user: "proceed" (to H-005's next step: line overlap, then the field
and columns from a MOCASSIN run). This entry is the overlap.

### The exact reference

`tools/h006_exact.py`. For the level columns the slab march has at a
depth, the optical depth of all H2 lines together is built on a 0.05 cm^-1
grid from 84,000 to 119,500 cm^-1 (710,000 points; every line with
tau0 > 1e-3 a Voigt profile, 8,400-13,800 of them), and each line's
shielding is integrated through it,
S_i = int phi_i exp(-tau_total) dnu, against the same with the line alone.
1,158 lines out of the H2g levels, six depths, ~1.5 min each.

| N(H2) [cm^-2] | 1e17 | 1e18 | 1e19 | 1e20 | 3e20 | 1e21 |
|---|---|---|---|---|---|---|
| exact factor on the H2g Solomon rate | 0.962 | 0.933 | 0.861 | 0.654 | 0.490 | 0.315 |
| DB96's overlap term, exp(-8.5e-4 sqrt(1 + N/5e14)) | 0.988 | 0.962 | 0.880 | 0.681 | 0.514 | 0.299 |

The two agree to 5%, which also checks the reference itself.

### What was built

  - **`lineOverlap`** (in `h2LineShield`, and alone as `h2LineOverlap`):
    S_i = S(tau_i, a_i) x mean of exp(-tau_others) over line i's own
    absorption. The mean is a quadrature on six points, three on each side
    at the offsets where 1/6, 1/2 and 5/6 of that side's absorption has
    happened. Those offsets are tabulated with S (a third table), so a thin
    line samples its core and a damped line its wings, which lie hundreds
    of Doppler widths out.
  - tau_others at a point is the sum of the other lines' profiles: the
    Voigt function within 12 Doppler widths of the other line, its
    Lorentzian wing beyond, dropped below 1e-4. Lines with tau0 >= 0.01
    shade. Those whose wing reaches more than 100 cm^-1 are summed for
    every line; the rest are found by bisection in wavenumber order. A thin
    line takes the far part once, at its centre.
  - `h2LineShield(..., overlap=)` takes factors already in hand, so a cell
    that iterates on its own populations computes the overlap once.
    h2Slab does that, at mid-zone.
  - `h2Test <dir> overlap <columns> <b>` prints every line's shielding
    with and without overlap; `tools/h006_compare.py` sets it against the
    exact reference; `tools/h006_figures.py`.

**Three points per side were chosen by test** (a Python prototype against
the exact reference): the Solomon factor over the exact one is 0.86-1.03
with one point per side, 0.99-1.02 with two, 0.98-1.04 with three, and
the line-by-line rms falls from 0.03-0.45 to 0.03-0.21.

### Result: the model's overlap against the exact one

| N(H2) [cm^-2] | 1e17 | 1e18 | 1e19 | 1e20 | 3e20 | 1e21 |
|---|---|---|---|---|---|---|
| Solomon factor, model | 0.962 | 0.930 | 0.858 | 0.643 | 0.491 | 0.329 |
| model / exact | 1.001 | 0.998 | 0.997 | 0.984 | 1.004 | 1.045 |
| pump rate per level, v = 0, J = 0-7, model / exact | 0.997-1.002 | 0.982-1.005 | 0.990-1.006 | 0.996-1.024 | 0.997-1.032 | 0.997-1.086 |
| line by line, weighted rms | 0.02 | 0.05 | 0.07 | 0.13 | 0.17 | 0.21 |

The scatter line by line reaches 21% (rms) at 1e21; the sums over a
level are within 9% and the Solomon rate within 4.5%. The table's own S is within 1.2% of
the exact single-line integral.

### The slab again, with overlap in the model

`h005_compare.py` on the same Cloudy slab (the Cloudy-like march has no
overlap of ours and is unchanged):

| | H-005 (no overlap) | now |
|---|---|---|
| shielding / DB96 at N(H2) = 1e18, 1e19, 1e20, 3e20, 1e21 | 1.03, 1.03, 1.30, 1.67, 2.63 | 0.95, 0.84, 0.76, 0.70, 0.74 |
| pumping absorptions through the slab [cm^-2 s^-1] | 9.73e8 | 6.53e8 |
| N(v=0, J=0-2) / Cloudy | 0.994-1.004 | 0.998-1.001 |
| N(1,3) / Cloudy | 2.64 | 1.70 |
| N(H2*) / Cloudy | 2.44 | 1.63 |
| v >= 1 levels / Cloudy | 1.72-3.94, median 2.45 | 1.25-2.77, median 1.66 |

**H-005's headline is revised.** Overlap lowers the model's total pumping
in this slab by 33%, not the ~20% H-005 estimated from DB96's factor, and
the excited-level columns are 1.63x Cloudy's, not 2.44x. One reason the
estimate was low, not measured separately: the pumped rotational levels
(v = 0, J >= 4) carry part of the pumping themselves, so less pumping
means fewer of them and less pumping again.

The model now sits 5-30% below the full DB96 fit in the damped regime and
20-50% above it at 1e14-1e17. Not chased: the fit is for their conditions
and populations, and our H2g rate carries the pumped J levels and the
band's uneven dust attenuation.

Cloudy's own overlap (the other lines at each line's centre, H-005) moves
its pump rates by 1-6%; the exact effect here is 14-35% at 1e19-1e20.
With wings 20x too narrow there is little to overlap.

### Cost

One overlap call is ~55 ms at these columns (32,453 lines, up to 13,800
shading). The march takes 59 s a pass with one call per zone, against
about 20 s without. For a MOCASSIN run: one call per cell and path.

### What is not yet known

  - **H I Lyman lines** shade the band too (Ly-beta and up, each ~2 A wide
    at N(H I) = 1e21). Not in.
  - **Cross-pumping.** A photon absorbed in another line's wing is counted
    as lost; it is in fact a pump of that line. That is in neither the
    exact reference nor the model: the reference is exact for the
    shielding, not for where the absorbed photon goes. Each line's own
    pumping is unaffected.
  - **Escape.** The trapping (beta) takes each line alone, no overlap.
  - **Why the model is 16-30% below DB96 at 1e19-1e21:** not isolated.
  - The ortho/para peak (58 at 1.1e16) and the other open items of H-005
    stand, but one: **the C I continuum.** Production's pdrStep records
    (D-350) that MOCASSIN's opacity carries C I photoionization absorption,
    so the field handed to the level model will already have it.

### Figures

`tools/h006_figures.py`: the overlap factor against N(H2), exact, model
and DB96. `tools/h005_figures.py` re-run for the slab. The artifact "H2
Shielding Check" is updated in place:
https://claude.ai/artifact/UGwgcHXfQ72aNyBnEG194Q

### Status

Done. The four MOCASSIN flavours, h2Test and h2Slab build. H-003's and
H-004's comparisons are unchanged, and so are H-005's like-for-like
numbers (the Cloudy-like march and the truncated slabs).

## H-007 - The level model inside MOCASSIN (2026-10-02)

The user: "proceed" (to H-006's next step: feeding the model the field and
columns from a MOCASSIN run).

### Where it runs, and on what

`h2LevelModel(grid)` in `pdr_mod.f90`, called from `iteration_mod` on
every rank at the final iteration (both exits: converged, and maximum
iterations), before rank 0 writes the output. Stage A: nothing feeds back.
3D build only (the 1D build has neither the site walk nor the line rays;
a stub says so). One grid, point sources.

Per cell, from the finished model:

| what | from |
|---|---|
| T | MOCASSIN's Te |
| n(H), n(He), n(H+), n(H2) | the chemistry's abundances times Hden |
| ortho and para H2 that collide | the level model's own, iterated |
| Doppler width | thermal at Te plus `pdrVturb` |
| field at each pumping line | Jste and Jdif in the line's bin (MOCASSIN's own rule for line bins), as a photon occupation number |
| direct part, Jste - Jdif | shielded by the level columns from the star to the cell (computeAVradial's march), averaged through the cell along the star's direction |
| diffuse part, Jdif | on traceDiffuseSites' scattering sites, each behind its two-leg level column, averaged through the cell's mean chord 4V/A |
| escape of each line | mean over the twelve line rays of traceLineRays |
| formation | Takahashi & Uehara on silicate and carbonaceous surfaces, weighted by the chemistry's H2_FORMATION_RATE on each surface alone |

Dust and continuous opacity (C I included, D-350) are already in the MC
field; the level model adds only the H2 lines' shading.

**Level columns are level by level.** The chemistry's columns are N(H2);
here each path's column of every one of the 302 levels is built from the
level populations of the cells on it and the chemistry's n(H2) there.
traceDiffuseSites now records each site's cell, ray and step and the
cells it stepped through, so the second leg can be rebuilt per level; its
results for the chemistry are unchanged.

**The sites are binned, not looped.** A cell has hundreds of sites, and
32,453 lines each. Per level, the site weights go into a histogram of
log N_l (0.1 dex), and each line is shielded bin by bin. Overlap is taken
per group of sites by total N(H2) (below 1e17: none; 1e17-1e19;
1e19-3e20; above), at the group's weighted mean level columns.

**Sweeps.** Other cells' populations are the previous sweep's (as the
coolants' are the previous iteration's in pdrStep), from Boltzmann
populations at Te on the first. Sweeps repeat until 1-0 S(1), 2-1 S(1),
0-0 S(0) and 0-0 S(1) all move by less than 1%.

**Output** (`h2Lines_mod.f90`, called from outputGas): `lineFluxH2.out`,
`h2Cells.out`, `h2Pop.bin`; described in the man page.
`tools/h007_report.py` summarises a run.

### Two defects on the way

  - **A local `nH2` hid the species index `NH2`** (Fortran is
    case-insensitive; D-075's trap): `pdrAbun(cellP, NH2)` was indexed
    with a real. One cell "solved", zero luminosity. Renamed; `nC` too.
  - **The diffuse part first left the cell's own column out** (as the
    chemistry does, D-088) while the direct part was averaged through it.
    The diffuse part then carried almost all the pumping in the cells
    where H2 turns on, and the level model's Solomon rate was 4-12x the
    chemistry's there. Averaging the sites' shielding through the cell's
    mean chord as well brought it to ~1 and 1-0 S(1) down 4.6x
    (3.2e34 -> 6.9e33 erg/s on the test model). The size of that change
    is the point: see "resolution" below.

### Checks

  - **Field conversion.** The unshielded Solomon rate recomputed offline
    from the shell-averaged spectrum of pdrFUVspec.out (h2Test, same T) is
    2.30e-7 and 1.00e-7 s^-1 in shells 2 and 3; the cells' mean from the
    run is 2.22e-7 and 9.23e-8 (0.97, 0.92). Shell membership was
    reconstructed, not read.
  - **In the Draine field** the level model's unshielded Solomon rate is
    6.36e-11 s^-1 (pumping 5.05e-10, one dissociation per 8.1
    absorptions); the network's coefficient is 5.18e-11.
  - Populations sum to 1 by construction; all four MOCASSIN flavours,
    mocassinOutput and mocassinPlot build.

### First full run: hiipdr 21^3

`runs/h007-full-hii21` (production's d381-hii21 input; 4,661 active
cells, 11 iterations, 14 ranks). The whole run took 10 min 11 s, of which
the level model 286 s: 4 sweeps of 59-79 s. Rank-seconds per sweep:
overlap ~285, solution ~255, shielding ~76, escape ~22, sites ~7.

| line | L [erg/s] | L / Hbeta |
|---|---|---|
| 1-0 S(1) 2.12 um | 6.22e33 | 7.2e-4 |
| 2-1 S(1) 2.25 um | 3.30e33 | 3.8e-4 |
| 0-0 S(0) 28.2 um | 2.08e33 | 2.4e-4 |
| 0-0 S(1) 17.0 um | 2.90e33 | 3.4e-4 |
| 0-0 S(3) 9.66 um | 3.63e33 | 4.2e-4 |

2-1 S(1)/1-0 S(1) = 0.53, the fluorescent value, as it should be at
n_H = 100.

**The levels' Solomon rate against the chemistry's**, on the same field
split and the same total columns (median per radial bin):

| where | levels / chemistry |
|---|---|
| ionized gas, T ~ 9,000 K | 2.4-2.6 |
| cold, unshielded (N(H2) < 1e14) | 1.5-1.8 |
| N(H2) to the cell 1e15-1e17 | 0.6-0.7 |
| deeper | 0.4-0.6 |

Three things separate them, none of them a bug in either:
  - the network's coefficient is for the Draine field, and the level
    model's rate in that field is 1.23x it; the 40 kK star's field rises
    toward 912 A where Draine's falls;
  - at 9,000 K the molecules are in excited levels (82% above
    4100 cm^-1), which dissociate faster;
  - the chemistry shields with one Federman line of radiative width
    8e7 s^-1 at the near face of the cell (D-088); the level model
    averages through the cell and has line overlap.
Resolving this is stage B.

Ortho/para peaks at 22 (median of a radial bin) where N(H2) to the cell
is ~1e15, as in the slab (H-005).

### pn150k 41^3 against Cloudy

`runs/h007-full-pn41` (production's d381-pn41 input; 35,384 active cells,
14 ranks). The whole run took 1 h 37 min 34 s, of which the level model
3,736 s: 4 sweeps of 763, 1,170, 1,005 and 798 s. Cloudy's model is
D-389's `runs/d389-cloudy-h2s/150k` (1D sphere, inner radius 1e16 cm),
its per-zone emissivities integrated over its sphere by
`tools/h007_report.py --cloudy`.

| line | this work, L / Hbeta | Cloudy, L / Hbeta | ratio |
|---|---|---|---|
| 1-0 S(1) 2.12 um | 1.062e-3 | 9.45e-4 | 1.12 |
| 0-0 S(0) 28.2 um | 1.44e-4 | 1.69e-4 | 0.85 |
| 0-0 S(1) 17.0 um | 5.67e-4 | 5.48e-4 | 1.03 |
| 0-0 S(2) 12.28 um | 1.084e-3 | 4.59e-4 | 2.36 |

2-1 S(1)/1-0 S(1) = 0.51 (fluorescent). Cloudy's are with D-390's
correction: D-384 had read the 2.12101 um line as 1-0 S(1).

**Where the lines come from, by gas temperature** (share of each line's
luminosity):

| | < 200 K | 200-1,000 K | 1,000-3,000 K | > 3,000 K |
|---|---|---|---|---|
| 2.12 um, this work | 83.2% | 13.9% | 1.3% | 1.6% |
| 2.12 um, Cloudy | 92.0% | 7.0% | 0.6% | 0.4% |
| 28.2, 17.0, 12.28 um, both | 98.9-100% | 0-1.1% | 0 | 0 |

So the transition zone does not carry these lines in either code; the
2.12 um line has a warmer tail here. By N(H2) to the cell, 30% of 2.12 um
is from cells behind less than 1e16 cm^-2 and 51% behind less than 1e18.

**The totals agree, the profiles do not.** Per radial shell, this work over
Cloudy (each normalised to its own Hbeta):

| shell [pc] | Te, this work / Cloudy [K] | n(H2) this work / Cloudy | 17.0 | 12.28 | 28.2 | 2.12 | share of Cloudy's 12.28 |
|---|---|---|---|---|---|---|---|
| 0.17-0.19 | 243 / 202 | 0.052 / 0.013 | 4.66 | 2.44 | 3.13 | 2.59 | 1% |
| 0.19-0.21 | 120 / 119 | 0.86 / 1.18 | 3.68 | 2.11 | 1.46 | 1.84 | 2% |
| 0.21-0.23 | 72 / 98 | 7.8 / 18.8 | 2.91 | 2.82 | 0.84 | 1.63 | 3% |
| 0.23-0.26 | 55 / 79 | 24 / 55 | 2.06 | 2.61 | 0.97 | 1.47 | 7% |
| 0.26-0.30 | 47 / 67 | 63 / 125 | 1.39 | 2.34 | 0.99 | 1.24 | 13% |
| 0.30-0.35 | 40 / 61 | 144 / 242 | 1.06 | 2.52 | 0.84 | 0.98 | 16% |
| 0.35-0.40 | 36 / 59 | 244 / 327 | 0.82 | 2.61 | 0.66 | 0.73 | 14% |
| 0.40-0.50 | 31 / 53 | 361 / 396 | 0.59 | 2.43 | 0.70 | 0.50 | 23% |
| 0.50-0.60 | 26 / 41 | 430 / 442 | 0.37 | 1.92 | 1.45 | 0.34 | 18% |

(medians of the cells / zones in a shell). The 17.0 and 2.12 um lines are
1.5-4.7x Cloudy's where H2 turns on and 0.3-0.8x in the shielded gas, and
the two nearly cancel in the totals. The 0.85-1.12 agreement of three
lines is therefore not a sign that the codes agree in each place, and is
not claimed as one. The 12.28 um line is 1.9-2.8x Cloudy's at every depth.

**Level columns along a radius.** Along the three grid axes (cells with
the other two indices 1), against Cloudy's printed columns (J = 4 and
v = 1 J = 3 from its emissivities, which reproduce its printed J = 2 and 3
columns to 0.001 dex):

| log N [cm^-2] | this work, x / y / z axis | Cloudy |
|---|---|---|
| H2 | 20.54 / 20.50 / 20.53 | 20.58 |
| ortho / para | 0.037 / 0.057 / 0.044 | 0.306 |
| v=0 J=0 | 20.52 / 20.47 / 20.51 | 20.46 |
| v=0 J=1 | 19.09 / 19.22 / 19.15 | 19.95 |
| v=0 J=2 | 17.10 / 17.46 / 17.16 | 17.20 |
| v=0 J=3 | 16.37 / 16.87 / 16.47 | 16.31 |
| v=0 J=4 | 15.66 / 15.67 / 15.73 | 15.32 |
| v=1 J=3 | 13.05 (x) | 12.97 |

  - **Ortho/para is 5-8x lower here, and the gas is what sets it.** Both
    codes' ratios are near thermal at their own gas temperature (9
    exp(-170.5/T) is 0.31 at 50 K and 0.04 at 33 K), and the shielded gas
    here is 15-20 K colder than Cloudy's (26-40 K against 41-61 K). The
    temperature is MOCASSIN's thermal balance with 3D-PDR's cooling, not
    the level model's. The colder gas also explains the deep 17.0 um
    (ortho J = 3) at 0.4-0.8x.
  - **N(0,4) is 2.2-2.5x Cloudy's,** which is the 12.28 um excess. J = 4
    lies 1,682 K up, so in gas below 100 K it is populated by the UV
    cascade and formation, not by collisions. H-005's slab, same physics
    and same Cloudy conventions except the damping width, gave N(0,4)
    3.0x Cloudy's from the damping width alone (Cloudy's lines damped by
    A_ul, the model's by the upper level's whole decay rate). That is the
    leading hypothesis; it is not tested on pn150k. *(Corrected
    2026-10-03, H-008: the 3.0 was H-005's model / Cloudy before overlap,
    with several choices differing at once, not the damping width alone.
    Measured alone in H-008, the width moves N(0,4) by 3.3x in the slab
    and 2.5-3.9x on pn150k, and the hypothesis holds for 12.28 um, but
    the width moves every pumped line about as much.)* A second candidate,
    discarded: the colliders (95% para-H2 here, 77% in Cloudy). Wan et
    al.'s J = 4 -> 2 rate at 30-50 K is 5.5-5.9e-14 cm^3 s^-1 for both
    (coll_rates_H2{ortho,para}_ORNL.dat), so at n(H2) ~ 400 cm^-3 the
    collisions take 2e-11 s^-1 against J = 4's A of 2.8e-9 s^-1: J = 4 is
    emptied by its own decay, whoever collides.

**The levels' Solomon rate against the chemistry's** (median per radial
bin): 3.0-3.3 in the ionized gas (12-16 kK), 2.3-2.6 at N(H2) < 1e15,
1.4 at ~1e17, 0.9-1.2 at 1e18-2e19, 0.5-0.8 deeper. The same pattern as
hiipdr; the unshielded ratio is larger here, where both the star and the
ionized gas are hotter (the two not separated).

**Cost.** Over the four sweeps, 39,476 rank-seconds are timed: overlap
53%, solution 25%, shielding 17%, escape 3%, sites 1%. The level model's
wall time is 52,300 rank-seconds, so a quarter of it is outside the timed
parts: ranks waiting at the reduction for the slowest one, and the field
set-up. Overlap is the place to make it cheaper.

### Resolution

A hiipdr cell at 21^3 is 1 pc; its own H2 column where the molecule turns
on is 1e14-1e18 cm^-2, the whole range over which the pumping lines go
from thin to damped. The level model's answer there depends on how the
cell's own column is treated, by the 4.6x above. The shielding average
through a cell is exact for a uniform cell; these cells are not uniform.
The 21^3 / 31^3 / 41^3 series measures how much this matters
(`runs/h007-full-hii{21,31,41}`, production's d381 hiipdr input at each
size, 11 iterations, 14 ranks):

| grid | active cells | Hbeta [1e36 erg/s] | 1-0 S(1) [1e33 erg/s] | 1-0 S(1) / Hbeta | 0-0 S(0) [1e33] | 0-0 S(1) [1e33] | sweeps | level model [s] | run |
|---|---|---|---|---|---|---|---|---|---|
| 21^3 | 4,661 | 8.582 | 6.22 | 7.25e-4 | 2.08 | 2.90 | 4 | 286 | 10 min |
| 31^3 | 15,204 | 9.296 | 8.38 | 9.02e-4 | 2.67 | 4.09 | 5 | 1,073 | 34 min |
| 41^3 | 35,377 | 8.802 | 8.64 | 9.81e-4 | 2.75 | 4.34 | 5 | 3,544 | 1 h 47 min |

**The line luminosities converge:** 21 -> 31 raises 1-0 S(1) by 35%,
31 -> 41 by 3.0% (0-0 S(0) +28% then +3.1%; 0-0 S(1) +41% then +6.3%).
1-0 S(1)/Hbeta moves more, +24% then +8.8%, because Hbeta itself moves
by +8.3% then -5.3% with the grid; that is MOCASSIN's ionized gas, not
the level model.

**The profile does not converge.** Shell by shell (1 pc shells), the
H2 in the transition keeps rising with resolution, and its emission per
molecule falls to compensate:

| shell [pc] | 31/21: 1-0 S(1) | H2 | per molecule | 41/31: 1-0 S(1) | H2 | per molecule |
|---|---|---|---|---|---|---|
| 4-5 | 0.90 | 0.71 | 1.27 | 1.19 | 1.32 | 0.90 |
| 5-6 | 1.22 | 1.00 | 1.22 | 1.09 | 2.05 | 0.53 |
| 6-7 | 1.75 | 2.65 | 0.66 | 1.08 | 3.60 | 0.30 |
| 7-8 | 1.74 | 2.18 | 0.80 | 1.06 | 2.36 | 0.45 |
| 8-9 | 1.34 | 1.34 | 1.00 | 1.00 | 2.15 | 0.47 |
| 9-10 | 1.33 | 1.29 | 1.03 | 0.81 | 1.31 | 0.62 |
| 10-11 | 1.04 | 1.05 | 0.99 | 0.82 | 1.21 | 0.68 |
| 11-12 | 0.98 | 1.05 | 0.93 | 0.71 | 0.99 | 0.71 |

The H2 that moves is the chemistry's: the self-shielding front sharpens
as its cells shrink, and the H2 at 5-9 pc grows 2-3.6x from 31 to 41.
The 1-0 S(1) of a shell follows the pumping in it (the pumping-weighted
ratio tracks the luminosity ratio to a few per cent at 21 -> 31), and
the total follows the number of Lyman-Werner photons the H2 absorbs.
Once the front absorbs most of them, the total depends only weakly on
where it sits. That reading predicts that the totals stay converged and
the profile goes on moving until the front is resolved. It has not been
tested beyond 41^3, which is the largest grid that fits at 14 ranks.

At 41^3, 50% of 1-0 S(1) is from cells behind less than 1e16 cm^-2 of
H2 (64% at 21^3, 55% at 31^3); 98.9% is from gas below 200 K.

### Observations, not chased

  - **Warm restarts with `pdrStartIter 1` are not a faithful test bed.**
    The first tests restarted d381-hii21 for one iteration with
    pdrStartIter set to 1. The outer cloud's n(H2) came out at 0.03-0.5
    where the full run has 49 cm^-3: the chemistry appears to be re-seeded
    without molecules at the PDR's first iteration. Likely my change of
    pdrStartIter rather than a defect of mocassinWarm; not diagnosed.
    Full runs are used instead.
  - Production's d381-hii21 was run at np = 2; this one at 14. Hbeta
    agrees to 0.02% and CO 1-0 to 0.5%; CO 6-5 differs by 46%.

### Not yet known

  - **The 12.28 um excess on pn150k** (N(0,4) 2.2-2.5x Cloudy's at every
    depth): whether the damping width accounts for it, as in H-005's slab.
    The test is the level model run with Cloudy's width (A_ul) on the same
    model.
  - **The pumping layer**: 2.12 and 17.0 um are 1.5-4.7x Cloudy's where H2
    turns on. Geometry (3D cells against a 1D march), the diffuse field and
    the chemistry's H2 profile all differ there; none of them is isolated.
  - **The shielded gas's temperature** (15-20 K below Cloudy's on pn150k,
    and with it ortho/para 5-8x lower) is the coupled model's thermal
    balance; the level model only inherits it.
  - **Cost**: overlap is 53% of the timed work on pn150k and a quarter of
    the wall time is outside the timed parts (waiting at the reduction).
  - **The profile at resolution**: hiipdr's line totals move 3-6% from
    31^3 to 41^3, but the H2 in the transition still grows 2-3.6x per
    shell. Where the line comes from is not converged at 41^3.
  - Formation by routes other than grains (H2+ + H, H-) is not
    distributed over levels; cells with no grain formation would take a
    Boltzmann distribution (none in this model).
  - H2 inside the ionized gas (T ~ 9,000 K): the collision tables are
    held at their ends, and electrons are not colliders yet.
  - Dust extinction of the H2 lines on their way out is not applied.
  - Plane-parallel models, multiple grids, the 1D build.
  - ~~Cost on a 35k-cell model (estimated ~10 min a sweep at 14 ranks).~~
    Measured: 13-20 min a sweep on pn150k (above).

### Status

Done (2026-10-02). Stage A's level model runs inside MOCASSIN on the
finished model and writes its lines; pn150k is compared with Cloudy and
hiipdr's line totals converge with resolution. All four flavours,
mocassinOutput, mocassinPlot, h2Test and h2Slab build. Not pushed. The findings
that need work (the 12.28 um excess, the pumping layer, the cost) are
above; nothing here feeds back into the chemistry (stage B).

## H-008 - The damping width, alone, on pn150k and the slab (2026-10-03)

The user: "proceed" (to H-007's next step: the level model on pn150k with
Cloudy's damping width, to test the hypothesis for the 12.28 um excess).

### The test

One line of `h2LineParams` changed, as a diagnostic, not committed:

    -      a = (h2uAtot(h2tU(i)) + h2uDiss(h2tU(i)))*lam/(4._dp*pi*b)
    +      a = h2tA(i)*lam/(4._dp*pi*b)

`h2LineParams` is the only place the width is formed. It feeds each line's
own shielding (`h2LineShield`), the overlap (`h2LineOverlap`), the escape
(`h2LineEscape`) and the shielding of the diffuse sites' histograms in
`pdr_mod`, so the test changes the width everywhere and nothing else.
Built into `runs/h008-aul-pn41/mocassin.h008` and the slab's
`h2Slab.aul`; the source was then restored and all four flavours,
mocassinOutput, mocassinPlot, h2Test and h2Slab rebuilt from it.

With A_ul the cold-gas lines with A below ~6e3 s^-1 have a below the
shielding table's edge (1e-7) and take the edge. They are thick only up to
tau0 ~ 300, where a tau0 < 3e-5 and the wings carry less than 1% of the
equivalent width, so the clamp does not matter.

**The two pn150k runs are identical outside the level model.** At the same
input and the same number of ranks, every output file of `runs/h008-aul-pn41`
other than lineFluxH2.out, h2Cells.out and h2Pop.bin is byte-identical to
H-007's `runs/h007-full-pn41` (summary.out apart from its timestamps).
MOCASSIN's Monte Carlo is reproducible at fixed np, so this comparison
carries no Monte Carlo scatter. (CLAUDE.md's "two runs of the same fixture
differ" holds across np, as d381-hii21 at np = 2 against 14 did, H-007.)

The run took 1 h 07 min; the level model 2,265 s in 4 sweeps (H-007's
3,736 s): overlap 10,449 rank-seconds (21,108), shielding 4,831 (6,672),
solution 7,995 (9,793). Narrower wings reach fewer other lines.

### pn150k

`tools/h008_compare.py runs/h007-full-pn41 runs/h008-aul-pn41 --cloudy
.../d389-cloudy-h2s/150k --rin 1.0e16`:

| line / Hbeta | the model's width (H-007) | Cloudy's width | Cloudy | model's / Cloudy | Cloudy's width / Cloudy | Cloudy's width / model's |
|---|---|---|---|---|---|---|
| 1-0 S(1) 2.12 um | 1.062e-3 | 4.95e-4 | 9.45e-4 | 1.12 | 0.52 | 0.47 |
| 0-0 S(0) 28.2 um | 1.44e-4 | 3.94e-5 | 1.69e-4 | 0.85 | 0.23 | 0.27 |
| 0-0 S(1) 17.0 um | 5.67e-4 | 1.71e-4 | 5.48e-4 | 1.03 | 0.31 | 0.30 |
| 0-0 S(2) 12.28 um | 1.087e-3 | 2.86e-4 | 4.59e-4 | 2.37 | 0.62 | 0.26 |

The pumping summed over the H2 falls to 0.38 and the levels' Solomon rate
to 0.40. 2-1 S(1)/1-0 S(1) stays fluorescent (0.51).

**Where the width matters**, by N(H2) to the cell (the share is of the
2.12 um line in H-007's run; the rest is Cloudy's width over the model's):

| N(H2) to the cell [cm^-2] | share of 2.12 um | 2.12 | 28.2 | 17.0 | 12.28 |
|---|---|---|---|---|---|
| < 1e14 | 10.5% | 1.00 | 1.00 | 1.00 | 1.00 |
| 1e14-1e16 | 19.5% | 0.85 | 0.78 | 0.76 | 0.84 |
| 1e16-1e17 | 8.6% | 0.26 | 0.40 | 0.29 | 0.30 |
| 1e17-1e18 | 12.8% | 0.20 | 0.27 | 0.20 | 0.18 |
| 1e18-1e19 | 22.6% | 0.25 | 0.25 | 0.23 | 0.21 |
| 1e19-1e20 | 20.7% | 0.34 | 0.27 | 0.30 | 0.25 |
| > 1e20 | 5.3% | 0.41 | 0.28 | 0.34 | 0.27 |

Thin lines do not care; behind 1e16 cm^-2 the pumping is in the damping
wings, where the equivalent width goes as sqrt(a), and the upper levels'
total decay rate is 20x the line's A in the median (H-005): sqrt(1/20) =
0.22. Measured, 0.18-0.41.

Per radial shell, luminosity over Cloudy's (the model's width | Cloudy's):

| shell [pc] | 2.12 um | 28.2 um | 17.0 um | 12.28 um |
|---|---|---|---|---|
| 0.17-0.19 | 2.54 / 2.49 | 3.08 / 3.04 | 4.58 / 4.45 | 2.39 / 2.36 |
| 0.19-0.21 | 1.80 / 1.30 | 1.43 / 1.12 | 3.61 / 2.56 | 2.07 / 1.65 |
| 0.21-0.23 | 1.60 / 0.43 | 0.83 / 0.32 | 2.86 / 0.82 | 2.76 / 0.82 |
| 0.23-0.26 | 1.45 / 0.30 | 0.95 / 0.25 | 2.02 / 0.40 | 2.57 / 0.47 |
| 0.26-0.30 | 1.22 / 0.30 | 0.97 / 0.24 | 1.37 / 0.31 | 2.29 / 0.47 |
| 0.30-0.35 | 0.96 / 0.29 | 0.83 / 0.21 | 1.04 / 0.28 | 2.48 / 0.58 |
| 0.35-0.40 | 0.72 / 0.25 | 0.65 / 0.17 | 0.81 / 0.25 | 2.56 / 0.65 |
| 0.40-0.50 | 0.49 / 0.19 | 0.69 / 0.19 | 0.58 / 0.19 | 2.38 / 0.63 |
| 0.50-0.60 | 0.34 / 0.14 | 1.42 / 0.39 | 0.36 / 0.13 | 1.88 / 0.51 |

Level columns along the three axes (log N, x / y / z), and Cloudy's:

| | the model's width | Cloudy's width | Cloudy |
|---|---|---|---|
| ortho / para | 0.037 / 0.057 / 0.044 | 0.034 / 0.054 / 0.041 | 0.306 |
| v=0 J=2 | 17.10 / 17.46 / 17.16 | 16.47 / 17.35 / 16.59 | 17.20 |
| v=0 J=3 | 16.37 / 16.87 / 16.47 | 15.83 / 16.77 / 15.98 | 16.30 |
| v=0 J=4 | 15.66 / 15.67 / 15.73 | 15.07 / 15.28 / 15.18 | 15.32 |
| v=1 J=3 | 13.05 / 13.17 / 13.13 | 12.80 / 12.95 / 12.90 | 12.97 |

With Cloudy's width, 64% of 2.12 um is from gas below 200 K and 32% from
200-3,000 K (H-007: 83% and 15%; Cloudy: 92% and 7%): the cold, shielded
part falls and the thin warm front does not.

### The slab, with the same single change

H-005's slab (100 K, n_H 1e4, 100 Habing), the model as of H-006 (with
overlap), marched with `h2Slab.aul` in voigt mode: only the width differs
from the model's own march (`voigt.cols`); the Cloudy-like march
(`federman.cols`, Federman fit, own-A width, no averaging through the
zone, no overlap of ours) is unchanged.

| / Cloudy | the model | the model, Cloudy's width | Cloudy-like march |
|---|---|---|---|
| N(H2*), E > 4100 cm^-1 | 1.63 | 0.60 | 0.73 |
| v >= 1 levels, median (range) | 1.66 (1.25-2.77) | 0.62 (0.51-0.75) | 0.74 (0.60-0.90) |
| N(0,4) | 1.95 | 0.58 | 0.76 |
| N(0,5), N(0,7) | 1.62, 1.53 | 0.54, 0.53 | 0.67, 0.63 |
| N(1,3) | 1.70 | 0.64 | 0.80 |
| N(0,0-2) | 1.00 | 1.00 | 1.00 |

The width alone moves the excited levels by 2.5-3.3x here (N(0,4) 3.3x).

### What it means

  1. **The hypothesis holds for 12.28 um.** With Cloudy's width, N(0,4) is
     0.56-0.91x Cloudy's along the axes and the line 0.62x; the uniform
     2.4x excess of H-007 is gone.
  2. **But the width moves every pumped line about as much** (2.1-3.8x on
     the totals), so with the same width as Cloudy all four lines are
     below Cloudy's, by 0.23-0.62. H-007's agreement of three lines was two
     factors of 2-4 in opposite directions: the wider line raises ours, and
     something else lowers it. The 12.28 um line stood out only because it
     has less of the something else.
  3. **The model keeps its width.** The natural width of a line is the
     upper level's total decay rate, here sum A + dissociation. Cloudy
     itself uses the upper level's lifetime for its database species
     (`cont_createpointers.cpp:481`), its iso-sequences (`iso_create.cpp`
     485, 1445) and its UTA lines (radiative plus autoionization,
     `atmdat_readin.cpp:1234`); its H2 alone takes the line's own A
     (`mole_h2_create.cpp:630`), with no comment on why. The 2-4x is a
     difference to report between the codes, not one to close.
  4. **What remains**, with the widths equal: 0.52 (2.12 um), 0.62
     (12.28), 0.31 (17.0), 0.23 (28.2). Candidates, none isolated:
       - the closure: for the same rates Cloudy's excited populations are
         1.3-1.7x our closed solution's (H-004, H-005); in the slab, the
         model with Cloudy's width sits at 0.60 of Cloudy, close to
         pn150k's 0.52-0.62 for the two lines fed by pumping alone;
       - the gas: the rotational lines fall further (0.23-0.31), and they
         are the ones with a thermal part and an ortho/para dependence;
         our shielded gas is 15-20 K colder (H-007);
       - the H2 at the front: our n(H2) is 0.4-0.5x Cloudy's at
         0.21-0.30 pc (H-007), where the cold-gas pumping starts.

### Not yet known

  - Which of the three remaining candidates sets the 0.23-0.62. The closure
    can be tested on pn150k the way H-004 tested it in isolation (the
    model's rates through Cloudy's scheme).
  - Why the y axis's J = 2 and J = 3 columns sit 0.8-0.9 dex above the x
    and z axes' with Cloudy's width (0.3-0.5 dex with the model's): one
    axis is a single line of cells; not looked at.
  - Whether Cloudy's H2 width is a deliberate choice: the source does not
    say; not asked.

### Status

Done. The test is in the log, not in the code; the model keeps the upper
level's total decay rate as each line's width. `tools/h008_compare.py`
compares two runs of a model with each other and with Cloudy.

## H-009 - Cloudy's closure on pn150k, and the ortho/para split (2026-10-03)

The user: "proceed" (H-008's next step: the closure test on pn150k, the
model's rates through Cloudy's scheme as H-004 did for one-zone models).

### The test

A diagnostic patch to `h2Solve`, not committed to the code but kept as
`tools/patches/h009_cloudy_closure.patch` (applies to dd9f753 and later):
`balanceCloudy` replaces the closure. As H-004's check D:
  - a formation source fixed in advance, phi times F, F the destruction
    rate per H2 of the populations handed in (the previous iteration's);
  - the H2g Solomon rate of those populations added again as a uniform
    sink on the 9 levels below 4100 cm^-1 (Cloudy's "sink_left");
  - no sum rule: the 70 lowest levels solved together, the levels above
    with all their input scaled by the same factor f as the source, and f
    fixed so that the populations add up to 1.

**Validated first on H-004's 16 one-zone models** (h2Test, iterated four
times from zero for the validation only):

| | median abs(log10) of populations / Cloudy's | f |
|---|---|---|
| our closure (H-004 check C) | 0.035-0.104 at 1-100 Habing | - |
| check D (Python, H-004) | 0.002-0.040 | 1.001-1.086 |
| this patch | 0.003-0.032 | 1.002-1.082 |

Two defects on the way, both in the test, not the model: a plain secant on
f jumped across the pole of sum(n)(f) (beyond the root the system turns
singular and the sum changes sign) and fell back to our closure in 6 of
the 16 models; it now steps up from f = 1 as check D scans, halving the
step where populations turn negative, and refines in the bracket
(Illinois). And h2Test hands each case the previous case's populations,
so the patch first took F and the H2g rate from the wrong model; in a
MOCASSIN run they are the same cell's previous iteration.

**What F leaves out.** In the emulation the formation is the levels'
Solomon rate. Our chemistry's budget (`tools/d356_channels.py` on the
run's sampled cells) supports that: photodissociation is 93-100% of H2
destruction out to 0.43 pc, 83% at 0.47 and 67% at 0.60 pc. Cloudy's own
pn150k (`150k.H2de`) is different: beyond 0.21 pc photodissociation is
25-69%, and H2 + Cl+ -> HCl+ (17-28%), H2 + HCl+ -> H2Cl+ (up to 20%),
H2 + O+ -> OH+ (2-8%) and cosmic rays (up to 9%) take the rest. Our
33-species network has no chlorine. Cloudy's levels therefore see a larger
uniform sink and a larger formation source deep than this emulation
gives; that part of its closure is not emulated.

### The runs

`runs/h009-aulcl-pn41`: Cloudy's width (H-008's patch) and Cloudy's
closure together. `runs/h009-cl-pn41`: Cloudy's closure alone, with the
model's width (queued behind it). Both byte-identical to H-007's run
outside the level model, as in H-008.

Cost: the search for f takes ~25 linear solves per call. The level model
took 14,561 s in 4 sweeps (H-008's 2,265 s); the solution step is
25,000-28,600 rank-seconds a sweep against ~2,000. The whole run took
4 h 30 min.

### Cloudy's closure, with Cloudy's width

| line / Hbeta | Cloudy's width (H-008) | + Cloudy's closure | Cloudy | / Cloudy, H-008 | / Cloudy, now | closure's factor |
|---|---|---|---|---|---|---|
| 1-0 S(1) 2.12 um | 4.95e-4 | 5.96e-4 | 9.45e-4 | 0.52 | 0.63 | 1.20 |
| 0-0 S(0) 28.2 um | 3.94e-5 | 4.59e-5 | 1.69e-4 | 0.23 | 0.27 | 1.17 |
| 0-0 S(1) 17.0 um | 1.71e-4 | 2.03e-4 | 5.48e-4 | 0.31 | 0.37 | 1.19 |
| 0-0 S(2) 12.28 um | 2.86e-4 | 3.52e-4 | 4.59e-4 | 0.62 | 0.77 | 1.23 |

The closure raises everything by about the same 1.2 (H-004's unshielded f
was 1.06-1.11, H-005's shielded slab ~1.37). Per radial shell the rise is
largest at the front (1.14-1.6 at 0.17-0.21 pc, where the lines are now
1.7-5x Cloudy's) and 1.08-1.29 behind it; the shielded shells stay at
0.14-0.77 of Cloudy's.

### The ortho/para split

The four lines of H-007 are three ortho and one para. Cloudy's
"save lines" file has hundreds of H2 lines; `tools/h009_lines.py` matches
its 40 strongest to ours (air to vacuum, 2e-4) and divides each code's by
its own Hbeta. (Cloudy's file holds the intrinsic block first and the
emergent one, with dust extinction, second; the intrinsic is used. Its
2.12 um there is 1.005e-3 Hbeta, 6% above the 9.45e-4 from integrating its
emissivities: two integrations of Cloudy's own sphere.)

Median of ours / Cloudy's, by the upper level's v and spin:

| upper level | lines | the model (H-007) | Cloudy's width (H-008) | Cloudy's width and closure |
|---|---|---|---|---|
| v = 0, ortho | 6 | 0.86 | 0.34 | 0.42 |
| v = 0, para | 3 | 1.63 | 0.50 | 0.63 |
| v = 1, ortho | 8 | 1.05 | 0.48 | 0.58 |
| v = 1, para | 5 | 2.63 | 0.84 | 0.99 |
| v >= 2, ortho | 12 | 1.00 | 0.44 | 0.53 |
| v >= 2, para | 6 | 2.54 | 0.79 | 0.92 |

Line by line with both of Cloudy's conventions, the 11 vibrational para
lines are 0.85-1.03 of Cloudy's and the 20 vibrational ortho lines
0.49-0.68; within each group the spread is small.

**What it means.** With the same line width and the same closure as
Cloudy, the fluorescence of para-H2 agrees with Cloudy's to 0-15%, from
v = 1 to v = 5. What is left in the pumped lines is the spin: ortho lines
are 0.55-0.6 of para lines relative to Cloudy, at every v. Radiative
pumping and cascades keep the spin, so that is the ortho/para ratio of the
pumped gas, and H-007 found it lower here because the shielded gas is
15-20 K colder (both codes near thermal at their own temperature). The
rotational v = 0 lines are lower still (0.42 and 0.63), as they carry a
thermal part from that colder gas as well.

So H-007's 1-0 S(1) at 1.06x Cloudy's (on this file) is the product of
the width, x2.1 (ours physical); the closure, x1/1.2 (Cloudy's
convention); the ortho fraction of the gas, x~0.55-0.6 (the coupled
model's temperature); and what remains, ~1.0. The para lines, which do
not have the third factor, were 2.5-2.6x Cloudy's.

**The width's factor depends on the spin.** The model's width over
Cloudy's (medians of the same 40 lines): v = 1 ortho 2.19, para 3.15;
v >= 2 ortho 2.27, para 3.22; v = 0 ortho 2.51, para 3.26. Para pumping
starts mostly from J = 0, behind ~3e20 cm^-2, deep in the damping wings
where the width counts most; our ortho J = 1 column is 20x smaller
(19.1 against 20.5 dex). So the clean split above, ortho 0.55-0.6 of
para relative to Cloudy, is with Cloudy's width; with the model's width
it is 0.40, the gas's ortho/para and the width together.

### Not yet known

  - Whether the ortho deficit is the gas temperature alone, or also the
    ortho-para conversion (H+ and H exchange, grain surfaces): both codes
    are near thermal, which points to the temperature, but this is not a
    separate test.
  - Cloudy's extra destruction and formation from chlorine and O+
    chemistry in the shielded gas: not emulated, and our network has no
    chlorine.

### The closure alone, and the four runs together

`runs/h009-cl-pn41` (Cloudy's closure, the model's width): 3 h 57 min,
level model 12,303 s in 4 sweeps, no fall-backs. Each line / Hbeta over
Cloudy's (its emissivities integrated, as H-007):

| | 2.12 um | 28.2 um | 17.0 um | 12.28 um |
|---|---|---|---|---|
| the model (H-007) | 1.12 | 0.85 | 1.03 | 2.37 |
| Cloudy's closure | 1.34 | 0.99 | 1.22 | 2.86 |
| Cloudy's width (H-008) | 0.52 | 0.23 | 0.31 | 0.62 |
| Cloudy's width and closure | 0.63 | 0.27 | 0.37 | 0.77 |

The closure's factor is 1.17-1.21 with the model's width and 1.17-1.23
with Cloudy's; the width's is 0.47, 0.27, 0.30, 0.26 with our closure and
0.47, 0.27, 0.30, 0.27 with Cloudy's. The two choices act independently
to 1-2%. By spin (40 lines, medians, v = 1): ortho 1.05 -> 1.24, para
2.63 -> 3.04 with the closure alone.

`tools/h009_lines.py --fig`: ours/Cloudy per line against the upper
level's v, ortho and para, one panel per run.

### Status

Done (2026-10-03). Nothing in the code changes: the model keeps its width
and its closure. Between the codes, on pn150k: the width (x2-3.3, ours
physical), the closure (x1.2, Cloudy's convention) and the gas's
ortho/para (ortho lines 0.55-0.6 of para lines, the coupled model's
colder shielded gas). Once the first two are equal, para-H2 fluorescence
agrees with Cloudy's to 0-15%. The tree is rebuilt from the committed
source.

## H-010 - Cloudy's small H2 model: no lines; what Cloudy does for speed (2026-10-03)

The user: "lets look at Cloudy simple H2 model for some clues. Does it
calculate line intensities? Can we use it instead of the full model to
make it faster?"

### What the small model is (Cloudy c25.00 source and Hazy)

The default without `database H2`, the "three-level model" of TH85,
Burton et al. 1990 and Draine & Bertoldi 1996 as extended by Elwert et
al. (2005, IAU Symp. 235): H2g, one excited pseudo-level H2*, and
dissociation.
  - Solomon rates of H2g and H2* from fitting formulas in log G0 and the
    total N(H2) (`mole_reactions.cpp` 3910-4010); H2g -> H2* at a
    G0-dependent multiple of the Solomon rate.
  - H2* decays at a fixed A = 2e-7 s^-1 (`h2s_sp_decay`; the large
    model's average A when that is on).
  - De-excitation heating from a fit with factors in n_H and G0
    (`mole_drive.cpp` 285); rotational cooling from the Glover & Abel
    2008 function times n(H2) (`cool_eval.cpp` 255).
  - **No lines.** `H2_LinesAdd` returns at once when the large model is
    off (`mole_h2_io.cpp` 47); Hazy: H2 lines appear in the output only
    with the large model.

**Not usable here.** It has no line spectrum, and its rates are fits in
G0 and n_H with shielding by total N(H2), standing in for what MOCASSIN
computes (the field in each line's bin, 3D level columns): what
CLAUDE.md excludes. Our chemistry's Federman-based rate is already such
an approximation, and replacing it is stage B's point.

### What Cloudy's large model does for speed, and whether it applies

  - **The lowest levels by matrix, the rest by back-substitution** from
    the top down (`database H2 matrix`; 70 levels in H-004's models). On
    pn150k a median H2 cell (2n(H2)/n_H > 1e-4) has 10 levels above
    1e-8, 80 above 1e-10, 239 above 1e-12: most of our 302 x 302 dense
    solve (25% of the timed work) is on negligible levels. Applicable;
    to be checked against the full solve.
  - **The large model only where H2/H > 1e-8** (`database H2 limit`,
    TH85 expressions below): 0.8% of pn150k's cells (1.7% below 1e-6).
    No gain, and a gate.
  - **Overlap from the summed opacity at each line's centre** on its
    continuum mesh: cheap, but it moves pump rates by 1-6% where the
    exact effect is 14-35% (H-006). Not adoptable as it is; building the
    summed line opacity once per path on a grid and reading our six
    quadrature points from it could replace the per-line sums over
    neighbours.

The cost on pn150k is overlap 53%, solution 25%, shielding 17% (H-007).
None of the small model's simplifications touches the overlap; reusing it
across sweeps (it is recomputed each sweep while the columns barely move
after the second) is the larger saving.

### Status

Discussion; no code. The speed work, when taken up: warm start, overlap
reuse, matrix plus back-substitution, load balance by measured cost, each
checked against H-007 byte for byte where the physics is unchanged and to
the stated tolerance where it is not.

## H-011 - The level model made faster (2026-10-03)

The user: "proceed" (to H-010's next step: the speed work, warm start
excepted, which belongs to stage B).

### Where the time went

Timers added to every part of `solveCell`, to the star columns and to the
reduction, with each rank's time in the cell loop (they stay: the log now
prints three timing lines a sweep). hiipdr 21^3, H-007's code
(`runs/h011-prof-hii21`), per sweep in rank-seconds:

| | sweep 1 | sweep 2 | sweep 3 | sweep 4 |
|---|---|---|---|---|
| overlap | 196 | 309 | 284 | 278 |
| solution | 299 | 263 | 254 | 253 |
| shielding | 56 | 85 | 77 | 75 |
| escape, sites | 15 | 32 | 29 | 29 |
| field, formation, after the solution, star columns | 3.5 | 4.0 | 3.1 | 3.0 |
| waiting at the reduction | 249 | 404 | 388 | 379 |
| cell loop per rank, min / max [s] | 25 / 58 | 28 / 78 | 26 / 74 | 25 / 73 |

A third of the wall time was ranks waiting. **The cause is the machine:**
the i7-14700 has 8 performance cores (5.3-5.4 GHz) and 12 efficiency
cores (4.2 GHz); 14 ranks run on both, and a rank on an efficiency core
takes about twice as long over the same cells. The round-robin cell
assignment cannot see that, nor can any static one: a cell's cost
depends on the core.

### What changed

  1. **Dynamic scheduling.** The ranks take cells one at a time from a
     shared counter (MPI-3 `MPI_Fetch_and_op` on a window on rank 0),
     the dearest of the last sweep first and the first sweep in a fixed
     shuffled order; a faster core simply takes more. A cell's result
     does not depend on its rank (no random numbers, no rank state that
     changes a result), so the outputs do not change. Two traps, measured
     on a synthetic test (2,000 items of ~4 ms, 14 ranks): a window on
     the program's memory (`MPI_Win_create`) waits for rank 0 to enter
     MPI, 2.03 s, worse than the static deal's 1.73 s; a window MPI
     allocates (`MPI_Win_allocate`) is an atomic in shared memory, 1.10 s.
     The first version used the former and was slower than the static
     deal it replaced (238 s against 184 s). Open MPI 5.0.10 here warns
     that its UCX one-sided component failed and falls back; `--mca osc
     ^ucx` keeps the warning out of the log (`runs/h011-*.sh`).
  2. **lineOverlap, the same sums reorganised** (overlap factors within
     1.2e-15 of the old ones at every column tested): the shading lines
     also in two lists of their own, long and short, so that each
     exclusion window is a contiguous range instead of a test per term;
     the long lines' wings, now one coefficient over the distance
     squared, summed without branches in four partial sums; the thin
     lines taken in wavenumber order, so that their windows (all centred
     on the line, all widening with it) are followed by pointers instead
     of six binary searches each, and neighbouring lines touch
     neighbouring memory. Bench (`h011` scratch, columns cumulated along
     pn150k's x axis):

     | N(H2) [cm^-2] | 4.7e14 | 7e16 | 1e18 | 1e19 | 1e20 | 3e20 | 9e20 | 3e21 |
     |---|---|---|---|---|---|---|---|---|
     | ms per call, H-007 | 5.2 | 9.5 | 14.8 | 20.3 | 23.6 | 25.6 | 38.1 | 55.1 |
     | ms per call, now | 2.7 | 5.1 | 6.7 | 8.5 | 9.6 | 10.3 | 15.8 | 23.9 |

  3. **The solution** (populations byte-identical): `h2CollRad` keeps the
     rate coefficients and Boltzmann factors of its last temperature, as
     a cell iterates at one T (3.6 -> 0.37 ms); `gaussSolve` eliminates a
     column at a time, in memory order, each element getting the same
     operations as row by row (6.2 -> 2.0 ms). One solution 10.8 -> 3.4
     ms.
  4. **Shielding lookups** (bit-identical): the direct path's shielding
     prepared once per cell (`h2LineShieldPrep`: tau0, W(tau0) and the
     damping's place in the table) and evaluated per pass for the cell's
     own column (`h2LineShieldEval`); the damping's place computed once
     per line for the sites' histogram and the twelve escape directions.
  5. **No floor on a cell's passes.** The ortho/para loop stopped only
     after three solutions; now when the colliding ortho fraction moves
     less than 1e-4, so a cell settled in the last sweep takes one
     (1.2-1.7 solutions a cell instead of 3.0). This one changes numbers:
     over hiipdr 21^3's 4,104 lines, median 1.2e-5, at most 6.6e-5.

### Tried and dropped

  - **The long lines' far wings from a grid** (10 cm^-1, tapered in from
    100 to 200 cm^-1, cubic convolution, the near ones summed one by
    one): an approximation, with errors up to 4e-4 in the overlap factor
    (more than the 1e-5 estimated), and no faster once item 2 had made
    the direct sum cheap. Removed.
  - **h2_mod at -O3 -march=native**: up to 15-20% on the solution and 4%
    on the overlap, measured under contention, so not established; the
    portable -O2 build is kept.
  - perf was not available (kernel setting); the profile is timers.

### Results

**hiipdr 21^3**, each step a full run (`runs/h011-v*-hii21`):

| | level model [s] | outputs against H-007 |
|---|---|---|
| H-007's code, with timers | 283 | byte-identical |
| + overlap reorganised, solution cached, static deal by cost | 184 | lines equal to all printed digits |
| + shared counter on a program-memory window | 238 | the same |
| + shared counter on an MPI-allocated window | 113 | the same |
| + prepared shielding | 118 (a benchmark ran alongside) | the same |
| + thin lines in wavenumber order | 99 | lineFluxH2.out and h2Pop.bin byte-identical |
| + no floor on a cell's passes | 71 | 4,104 lines: median 1.2e-5, max 6.6e-5 |

**pn150k 41^3** (`runs/h011-pn41`, against H-007's `runs/h007-full-pn41`):

| | H-007 | now |
|---|---|---|
| sweeps [s] | 763, 1170, 1005, 798 | 274, 412, 416, 372 |
| level model [s] | 3,736 | 1,474 |
| whole run | 1 h 37 min 34 s | 1 h 00 min 22 s |
| sweep 2, rank-seconds: overlap / shielding / solution / escape / sites | 6960 / 1986 / 2697 / 473 / 158 | 3026 / 1396 / 655 / 365 / 146 |
| solutions per cell, sweeps 1-4 | 3+ | 2.15, 1.57, 1.09, 1.04 |
| cell loop per rank, sweep 4, min / max [s] | - | 368 / 370 |

All 4,027 lines of lineFluxH2.out are within 2.5e-4 of H-007's (median
1e-5); grid0.out, lineFlux.out and temperature.out are byte-identical (the
Monte Carlo is untouched). The standalone drivers still reproduce their
references: h2Test's one-zone populations against Cloudy (H-004 check C,
median |dex| 0.003-0.104) and h2Slab's voigt march (level columns within
1e-6 of H-006's).

On pn150k the overlap is now 55% of the work, the sites' shielding
histogram 26%, the solution 12%, the escape 7%.

### Not yet known

  - **Enough for stage B?** Stage B calls the level model every Monte
    Carlo iteration from the last one's populations, so one or two
    sweeps, not four: ~7-14 min an iteration on pn150k, 1.3-2.5 h over
    eleven. The next costs: the overlap (one direct and up to three site
    groups a cell, each 10-25 ms at these columns) and the sites'
    shielding histogram (37 ms a cell on pn150k against 13 on hiipdr).
  - Whether lines with no field in their bin can skip the overlap (exact,
    as their shielding multiplies zero): not measured how many there are.
  - 14 ranks on 8 performance and 12 efficiency cores: whether more ranks
    would pay, now that a slow core no longer holds the others back, is
    a memory question (CLAUDE.md's 46k-cell limit at 14).

### Status

Done (2026-10-03). All four flavours, mocassinOutput, mocassinPlot,
h2Test and h2Slab build. Not pushed.

## H-012 - Stage B, step 1: the chemistry takes its H2 photodissociation rate from the level model (2026-10-03)

The user: "proceed" (to H-011's recommendation: stage B next).

### Design

Stage B is the level model becoming the physics, not a keyword (D-388's
rule for the branch): there is no switch between the two rates.

  - **Where it runs.** `iterateMC` calls `h2LevelModel(grid, 1)` every PDR
    iteration, after computeAVdust, mocassinToPDR and (on the first PDR
    iteration) seedMolecules, and before the PDR step: on this
    iteration's Monte Carlo field, the chemistry's n(H2) of the last
    iteration (or the seed) and the last Te. One sweep a call, from the
    last call's populations (Boltzmann only on the first call); the
    finished model gets sweeps to convergence (`h2LevelModel(grid, 12)`,
    as before). The coupled iteration is the Monte Carlo's own.
  - **What it hands over.** In pdrStep, after CALCULATE_REACTION_RATES and
    D-358's photoionization rates, the H2 photodissociation reaction
    (NRH2) takes the level model's Solomon rate per molecule for the cell
    (`grid%h2Sol`): the 302 levels, every pumping line shielded and
    overlapped on the cell's own direct and diffuse paths, instead of the
    network's single-line rate. CALC_HEATING reads the same RATE(NRH2),
    so the photodissociation and pumping heating use it too - with their
    fixed energies (0.4 eV, 9 x 2.2 eV) still 3D-PDR's: step 2.
  - **Every cell with gas is solved**, also one without H2: its rate per
    molecule is what the chemistry needs there (stage A skipped n(H2) = 0).
  - **The 1D build** has no site walk or line rays: its chemistry keeps the
    network's rate, and says so once. A model the level model does not
    handle (more than one grid, plane-parallel illumination) keeps it too,
    as h2LevelModel returns before allocating h2Sol.
  - What stays the chemistry's: n(H2) itself, and the H2 columns that
    shield CO and C (pdrColH2).

### hiipdr 21^3, stage B against stage A (11 iterations, PDR from 4)

`runs/h012-b1-hii21` against `runs/h011-v7-hii21` (`tools/h012_compare.py`):

| | stage A | stage B |
|---|---|---|
| x(H) + 2x(H2) + x(H+) - 1, all cells | -1.5e-7 .. +3.0e-8 | -1.5e-7 .. +3.0e-8 |
| 2x(H2) = 0.5 first at (each axis) | 10.69 pc | 9.72 pc |
| Hbeta [1e36 erg/s] | 8.58200 | 8.58324 |
| 1-0 S(1), 2-1 S(1) / Hbeta | 7.25e-4, 3.85e-4 | 7.77e-4, 4.11e-4 (1.07x) |
| 0-0 S(0), S(1), S(2) / Hbeta | 2.42, 3.38, 4.41e-4 | 3.04, 4.25, 5.47e-4 (1.24-1.26x) |
| run time | 6 min 34 s | 8 min 59 s |

Per shell (medians): where the levels' rate is below the chemistry's
(shielded gas, 0.5-0.6x, H-007) x(H2) is 1.3-2.5x higher at 7-10.5 pc;
at the unshielded edge (5.7 pc), where it is above, x(H2) is half. Te is
unchanged to 0.5 K in every shell. The front moves one cell (0.97 pc)
toward the star.

*Corrected 2026-10-04 (H-014).* These line ratios are the 21^3 grid's. With
both steps at 31^3 (`runs/h007-full-hii31` against `runs/h013-b2b-hii31`)
the lit edge, inside one 0.97 pc cell here, is resolved: it thins as on
pn150k, the vibrational lines fall to 0.82-0.83 of stage A's and the
rotational lines move by -8 to +3%, and the crossing moves 0.04 mag
toward Cloudy's (1.447 -> 1.407) where 21^3 gave 0.10.

The first call starts from Boltzmann populations on the seeded molecules
and gives 0-0 S(0) and S(1) of 7e36 and 8e37 erg/s (the seed's H2 at the
ionized gas's temperature); the second 1e36 and 3e35, the third 6e33 and
4e33, and from the fourth on 2-4e33.

### Does the coupled iteration converge? 11 against 16 iterations

The 11-iteration run's lines were still rising 3% an iteration at its end
(below), so both stages were rerun to 16 iterations, same input otherwise
(`runs/h012-it16-A`, `-B`; A with H-011's binary, B with this one). Each
run is byte-identical to its 11-iteration twin through iteration 11's
level-model call (MOCASSIN at fixed np), so the difference is the five
iterations alone.

| L [1e33 erg/s] | A, 11 it. | A, 16 it. | B, 11 it. | B, 16 it. |
|---|---|---|---|---|
| 1-0 S(1) | 6.219 | 6.167 (-0.8%) | 6.667 | 6.746 (+1.2%) |
| 2-1 S(1) | 3.302 | 3.277 (-0.8%) | 3.529 | 3.573 (+1.2%) |
| 0-0 S(0) | 2.078 | 2.074 (-0.2%) | 2.613 | 2.654 (+1.6%) |
| 0-0 S(1) | 2.903 | 2.824 (-2.7%) | 3.646 | 3.650 (+0.1%) |
| Hbeta [1e36 erg/s] | 8.58200 | 8.36656 (-2.5%) | 8.58324 | 8.36568 (-2.5%) |
| 2x(H2) = 0.5 first at, x/y/z [pc] | 10.69 (all) | 10.69, 10.69, 9.72 | 9.72 (all) | 10.69, 9.72, 8.75 |
| run time | 6 min 34 s | 8 min 08 s | 8 min 59 s | 12 min 05 s |

B over A at 16 iterations: 1-0 S(1) and 2-1 S(1) 1.09x, 0-0 S(0), S(1),
S(2) 1.27-1.29x (1.07x and 1.24-1.26x at 11). The sum rule is the same in
all four (-1.9e-7 .. +3.0e-8).

Stage B's 1-0 S(1), the call at the start of each iteration, iterations
4-16 [1e33 erg/s]: 10.72, 8.57, 7.34, 5.85, 5.67, 6.19, 6.37, 6.59 | 6.57,
6.67, 6.80, 6.88, 6.75; the finished model 6.75. 0-0 S(1) from iteration 9:
3.31, 3.41, 3.62 | 3.57, 3.62, 3.72, 3.82, 3.66; finished 3.65. After the
seed transient (iterations 4-8) the line climbs 2-4% an iteration to
iteration 11 and then moves by -0.3 to +1.9% and back by 2.0%: no
oscillation and no runaway; whether a slow climb remains under the
iteration-to-iteration scatter one run cannot say.

What this establishes:

  - **The coupling does not slow the convergence.** Five more iterations
    move B's lines by 0.1-1.6%, A's by 0.2-2.7%, and Hbeta by 2.5% in both.
    The 11-iteration hiipdr model (D-349's setting; the fixture keeps 22)
    is not converged to better than ~3% in its own ionized gas, as D-365
    found (L-40): the 3.47 pc shell (the H+/H front) goes from x(H) 0.39
    to 0.44 and Te 8690 to 8570 K in both stages alike. The H2 lines
    follow it.
  - **Stage B's effect is stable** to 0.02 in the ratio across the five
    iterations.
  - The front moves by one cell (0.97 pc) between the 11- and 16-iteration
    runs along one axis in A and along two in B (one out, one in): the
    transition is resolved by one or two cells (H-007's 21/31/41 series)
    and its position on this grid is a cell-quantised quantity.
  - Costs: B adds 2 min 25 s at 11 iterations and 3 min 57 s at 16: 18-20 s
    per call at 1.5 solutions per cell after the transient (30 s at the
    first), and the finished model needs 2 sweeps instead of A's 4.

### The rate handed over: the field's noise against the coupling's residual

h2LevelModel now says how far each call moves the Solomon rate the
chemistry has been using (median and 90th percentile of |new/old - 1| over
the cells with x(H2) >= 1e-6 and a rate before). The binary with it and
with step 2's groundwork (below) was rerun on h012-b1's input
(`runs/h012-b1c-hii21`): **every output byte-identical to h012-b1's**
except summary.out's clock times.

| call (iteration) | 5 | 6 | 7 | 8 | 9 | 10 | 11 | finished model |
|---|---|---|---|---|---|---|---|---|
| cells | 2859 | 2234 | 2021 | 1958 | 1957 | 1972 | 1971 | 2008 |
| median \|new/old - 1\| | 0.97 | 0.71 | 0.60 | 0.57 | 0.53 | 0.60 | 0.62 | **0.034** |
| 90th percentile | 25 | 8.5 | 2.7 | 2.2 | 6.0 | 2.9 | 4.4 | **0.11** |

The finished model's call reads the same Monte Carlo field as iteration
11's (both after iteration 11's transport), with the chemistry of iteration
11's PDR step in between: on a fixed field, the coupled rate moves by 3.4%
(median). Between iterations it moves by 50-60%: **the field's own noise,
not the coupling.** Each pumping line reads the field in its own frequency
bin, and from one iteration's photons to the next that differs per cell by
much more than the band integral the chemistry's own rate uses.

Measured per cell, between the 11- and 16-iteration runs (median / 90th
percentile of |new/old - 1|, cells with x(H2) >= 1e-6; scratch script
`h012_noise.py`):

| r [pc] | cells | Sol(levels), A | Sol(chem), A | x(H2), A | Sol(levels), B | x(H2), B |
|---|---|---|---|---|---|---|
| 4.5-6.0 | 40-63 | 0.07 / 0.18 | 0.04 / 0.13 | 0.04 / 0.13 | 0.09 / 0.18 | 0.06 / 0.14 |
| 6.0-7.5 | 139 | 0.13 / 0.36 | 0.09 / 0.21 | 0.07 / 0.18 | 0.15 / 0.39 | 0.12 / 0.34 |
| 7.5-9.0 | 205 | 0.23 / 0.51 | 0.12 / 0.30 | 0.09 / 0.25 | 0.23 / 0.55 | 0.21 / 0.54 |
| 9.0-10.5 | 280 | 0.37 / 0.88 | 0.22 / 0.55 | 0.13 / 0.31 | 0.40 / 0.90 | 0.14 / 0.40 |
| 10.5-12.0 | 371 | 0.54 / 2.1 | 0.33 / 0.95 | 0.06 / 0.16 | 0.54 / 2.6 | 0.04 / 0.11 |
| 12.0-13.5 | 390 | 0.81 / 15 | 0.58 / 3.0 | 0.03 / 0.08 | 0.81 / 14 | 0.02 / 0.06 |
| 13.5-15.0 | 222 | 1.0 / 500 | 0.73 / 6.1 | 0.02 / 0.38 | 1.0 / 380 | 0.01 / 0.38 |

  - Both rates scatter more with depth, in both stages: the field's noise
    per cell grows as the photons reaching a cell thin out (L-26). The
    levels' rate scatters ~1.5x more than the chemistry's on the same
    field (12.0-13.5 pc: 0.81 against 0.58).
  - Weighted by the destruction, sum n(H2) |dSol| / sum n(H2) Sol: the
    levels' rate 0.30 (A) and 0.33 (B), the chemistry's 0.22 and 0.19. The
    destruction each chemistry used, n(H2) times its own rate: 0.14 in A,
    0.23 in B, cell by cell; **its cloud total moves 1.6% (A) and 1.4% (B).**
  - What it does to the chemistry: in the transition, 6-9 pc, x(H2) per
    cell moves 1.7-2.3x more in B than in A (7.5-9 pc: 0.21 against 0.09);
    deeper, where x(H2) is saturated, it does not (0.01-0.04). The lines,
    sums over many cells, move by under 2% (above).

So stage B hands the chemistry a rate as noisy as the field in each line's
bin. That is the physics read on this Monte Carlo field, not a defect; it
falls with more packets, which only a run can price. Averaging the field
over iterations would also cut it, and would be a change of MOCASSIN's
iteration, not of the level model: not made.

### Built for step 2, not yet called

In h2_mod, tested on a scratch driver and called by nothing yet (the rerun
above is byte-identical with them in):

  - `h2PumpRates(..., heatDis)`: per level, the kinetic energy the
    dissociations out of it leave in the gas [eV s^-1], each excited
    level's dissociation rate times the energy of its atoms (h2uKE).
  - `h2CollHeat(T, dens, pops)`: the net heating by collisions within X
    per molecule [erg s^-1], every downward collision giving its level
    difference to the gas and every upward one taking it (Cloudy's
    HeatDexc). On Boltzmann populations it is -6e-42 erg s^-1 (zero to
    rounding: detailed balance); on pumped ones, positive.
  - On the scratch driver's pumped cell the mean kinetic energy per
    dissociation is 0.505 eV (3D-PDR fixes 0.4).

### pn150k 41^3 under stage B (2026-10-04)

`runs/h012-b1-pn41` (this commit's binary) against H-011's stage-A run
`runs/h011-pn41`, same input (9 iterations, PDR from 4, 35,384 cells):

| | stage A | stage B | B/A |
|---|---|---|---|
| x(H) + 2x(H2) + x(H+) - 1 | -1.1e-7 .. +3.0e-8 | -1.1e-7 .. +3.0e-8 | |
| Hbeta [1e36 erg/s] | 0.02725 | 0.02725 | 1.000 |
| 2x(H2) = 0.5 first at, x/y/z [pc] | 0.379, 0.409, 0.379 | 0.394, 0.425, 0.394 | one cell (0.015 pc) out |
| x(H2) at 0.195 / 0.238 / 0.282 pc | 5.7e-4 / 1.9e-2 / 6.5e-2 | 2.7e-5 / 9.2e-4 / 1.3e-2 | 0.05 / 0.05 / 0.19 |
| x(H2) at 0.455 / 0.585 pc | 0.362 / 0.442 | 0.368 / 0.459 | 1.02 / 1.04 |
| 1-0 S(1) / Hbeta | 1.062e-3 | 7.79e-4 | 0.73 |
| 2-1 S(1), 0-0 S(0), S(1), S(2) | | | 0.72, 0.95, 0.80, 0.93 |
| run time | 1 h 00 min 22 s | 1 h 08 min 29 s | |

**The opposite of hiipdr's sign, for the same reason.** In stage A the
levels' rate over the chemistry's is, by shell, 2.5 at 0.152 pc, 1.7 at
0.195, 1.3 at 0.238, 1.06 at 0.282, then 0.88 down to 0.47 at 0.585 pc. Where
it is above one the molecules the chemistry had there go, their shielding
with them, and the rate in B is 11x A's at 0.195 pc: the lit edge of the
transition (0.195, 0.238, 0.282, 0.325 pc; 130 to 40 K) loses 95, 95, 81
and 59% of its H2 and the front moves one cell out;
deeper, where the levels' rate is the lower, there is 2-4% more. In hiipdr
the levels' rate is below the chemistry's through most of the transition,
so the transition gained H2.

Against Cloudy's 40 strongest H2 lines (`tools/h009_lines.py`, median
ours/Cloudy by upper level):

| upper level | lines | A | B |
|---|---|---|---|
| v = 0, ortho | 6 | 0.86 | 0.69 |
| v = 0, para | 3 | 1.63 | 1.47 |
| v = 1, ortho | 8 | 1.05 | 0.77 |
| v = 1, para | 5 | 2.63 | 2.40 |
| v >= 2, ortho | 12 | 1.00 | 0.71 |
| v >= 2, para | 6 | 2.54 | 2.31 |

The ortho lines fall by 0.71-0.73 and the para lines by 0.90: the H2 that
goes is the warm edge's, ortho-rich. (With Cloudy's width and closure,
H-009, the para lines agreed and the ortho lines were 0.49-0.68: the width
still multiplies everything here.)

**Not converged in 9 iterations.** The per-call change of the Solomon
rate falls steadily, 0.86, 0.71, 0.59, 0.44, 0.33 (median, iterations 5-9),
which is the transition still moving rather than noise; on the finished
model's fixed field it is 0.092 (median), 0.27 (90%), against hiipdr's
0.034 and 0.11. 1-0 S(1) per call, iterations 4-9: 14.9, 22.4, 21.7, 15.4,
15.9, 18.6, finished 21.2 [1e30 erg/s] - 15-17% a step over the last two.
The cost per PDR iteration is 4-5.5 min (the call's 300-340 s); the
finished model takes 3 sweeps (781 s) instead of A's 4 (1,474 s).

### Not yet known

  - Whether the noisier rate moves the converged transition, or only
    scatters it: one 21^3 run per stage cannot separate the two.
  - Where pn150k's coupled transition settles: a longer run (next).
  - The heating (step 2): 3D-PDR's H2 terms are fixed energies on the
    level model's rate - 1.5 eV per formation, 0.4 eV per dissociation,
    9 x 2.2 eV per dissociation for the pumping, damped by a critical
    density - and nothing anywhere cools by H2 lines: neither 3D-PDR's
    coolants (C+, C, O, CO) nor MOCASSIN's include H2.

---

## H-013 - Stage B, step 2: the H2 heating, measured before it is handed over (2026-10-03)

The user: "proceed" (stage B, H-012's next step).

### What the gas gets from H2 now

MOCASSIN adds the PDR heating it has no term for (pdrHeatXtra, D-131) to
its balance, held fixed through its temperature search. Three of those
terms are H2's, at 3D-PDR's fixed energies (heatingfunctions.F90):

  - formation on grains, 1.5 eV per molecule (Hollenbach & Tielens 1999);
  - photodissociation, 0.4 eV per dissociation on RATE(NRH2) - the level
    model's rate since H-012;
  - FUV pumping, 9 x 2.2 eV per dissociation, times 1/(1 + n_cr/n) with
    Hollenbach & McKee's critical density.

Nothing cools by H2: the coolants are CO, C+, C and O (pdrCoolants in
both fixtures), and MOCASSIN cools only by its atoms and ions.

### What the level model has for the same physics (Cloudy's HeatDiss and HeatDexc)

  - **Dissociation**: each excited level's dissociation rate times the
    kinetic energy of its atoms (h2uKE, Abgrall et al.), summed over the
    X levels that pump into it: per molecule, sum_l pop_l heatDis_l.
  - **Collisions within X**: every downward collision gives the gas its
    level difference, every upward one takes it, at Te (`h2CollHeat`).
    This is both the heating by the pumped and formed molecules' energy
    and the cooling by H2's own lines: positive where pumping keeps the
    levels above their Boltzmann ratio, negative where the gas is hotter
    than they are. It replaces both the pumping term and the H2 cooling
    nobody has.
  - **Formation**: the binding energy D = 4.478 eV of a molecule formed on
    a grain goes to the grain, into the molecule's levels (formation
    pumping, already in the populations, from where it is radiated or
    collisionally given to the gas, above) and into its motion. Cloudy
    puts the grain's part into the grain's heating (ChemEnH2) and gives
    the gas nothing for the motion: Xtrans enters its mole_h2_create.cpp
    only through E_rot, and its reaction-enthalpy heating, which skips
    grain reactions as the grains' business, is compiled out
    (cool_eval.cpp, `#if 0`). Here the kinetic part is the gas's.

Takahashi & Uehara's partition, by energy conservation on the formation
distribution the model uses (h2FormDist: kinetic = D - E_dust(v) -
E(v,J), averaged over phi), against their nominal fractions X D (scratch
driver `form_test.f90`):

| surface | kinetic | grain | internal (vib + rot) | sum | TU X_trans D | TU X_dust D |
|---|---|---|---|---|---|---|
| ice | 0.711 | 0.198 | 3.569 (2.841 + 0.728) | 4.478 | 0.537 | 0.179 |
| silicate | 0.834 | 0.486 | 3.158 (2.348 + 0.810) | 4.478 | 0.672 | 0.448 |
| carbonaceous | 1.142 | 1.815 | 1.522 (0.740 + 0.781) | 4.478 | 1.120 | 1.791 |

[eV per molecule formed]. The sums are D to the last digit; the kinetic
energy is 24% above the nominal X_trans D on silicate because the
distribution's mean vibrational energy (2.35 eV) sits below its peak X_vib
D: the conserved value is the one consistent with the populations.

Cloudy's own pn150k (`d389-cloudy-h2s/150k.heat`): H2 photodissociation
heating is 0.4-1.0% of the heating in the 240 zones where it is listed
(5.6e17-1.9e18 cm), grain photoelectric 97% at most; collisional heating
or cooling within X is never listed.

### Step 2a: the three terms beside 3D-PDR's, every cell, nothing handed over

h2LevelModel now also gives, per cell (grid%h2Heat): the dissociation
heating and the collisional heating per molecule, and the kinetic energy
per molecule formed. pdrStep keeps CALC_HEATING's three H2 terms
(grid%pdrHeatH2, reduced over the ranks like pdrHeat). h2Cells.out gets
both, per H nucleus as MOCASSIN's budget, with MOCASSIN's own heating and
cooling at the balance point (mocBud) and the energies per event;
`tools/h012_heat.py` compares them by shell and in total.

Nothing is handed over: `runs/h013-b2a-hii21` (h012-b1's input) is
byte-identical to h012-b1 in every output except h2Cells.out, whose 19
old columns are identical in every row (13 new), and summary.out's clock
times. All four flavours build.

### hiipdr 21^3 (2026-10-04)

The formation partition follows the model's own grains: hiipdr's dust is
astronomical silicate only, so 0.834 eV kinetic and 0.486 eV on the grain
in every cell; pn150k's is graphite only (1.142 and 1.815 eV).

Grid totals [erg s^-1, the octant]: MOCASSIN's heating 2.34e37 (the H II
region's photoionization, mostly).

| term | levels | 3D-PDR | ratio |
|---|---|---|---|
| formation | 5.83e33 | 1.05e34 | 0.55 (0.834 against 1.5 eV) |
| dissociation | 2.54e33 | 2.35e33 | 1.08 (0.438 eV per dissociation, dissociation-weighted, range 0.07-0.91; 0.4) |
| collisions within X / FUV pumping | +2.0e32 | 6.4e30 | 32 |
| the three | 8.58e33 | 1.29e34 | 0.67 |

The collisional term heats in 2,076 cells (+2.4e32) and cools in 2,585
(-3.8e31, the deep cold gas). By shell, as fractions of MOCASSIN's heating
at its balance point (medians):

| r [pc] | Te [K] | 2x(H2) | levels: formation, dissociation, collisions | 3D-PDR: formation, photodissociation, pumping | the three, levels / 3D-PDR |
|---|---|---|---|---|---|
| 3.47 | 8690 | 3e-8 | 2e-7, 2e-6, -7e-6 | 3e-7, 2e-6, 5e-7 | (-0.8) |
| 4.86 | 51 | 8e-7 | 0.035, 0.018, 4e-5 | 0.063, 0.017, 2e-16 | 0.66 |
| 7.64 | 44 | 0.007 | 0.072, 0.036, 0.0026 | 0.130, 0.035, 3e-12 | 0.68 |
| 9.03 | 38 | 0.19 | 0.093, 0.046, 0.0063 | 0.168, 0.045, 8e-11 | 0.69 |
| 10.42 | 33 | 0.71 | 0.072, 0.035, 0.0055 | 0.131, 0.033, 2e-10 | 0.70 |
| 13.20 | 22 | 0.97 | 0.038, 0.0039, 0.0014 | 0.064, 0.0038, 2e-11 | 0.60 |
| 17.36 | 11 | 0.98 | 0.070, 0, -7e-17 | 0.125, 0, 0 | 0.57 |

  - Formation is the largest of the three everywhere (3D-PDR's 1.5 eV gives
    it 6-17% of the heating; the level model's 0.834 eV, 4-9%).
  - Dissociation agrees to 8%.
  - **The collisional term is never above 0.6% of the heating** here;
    3D-PDR's pumping term is 1e-10 of it, its critical density being 1e11
    cm^-3 and more at these temperatures (4e11 at 50 K in molecular gas).
    So on hiipdr it would not matter whether the term follows T inside
    MOCASSIN's temperature search or is held, as pdrHeatXtra's other
    terms are.
  - Handing the three over would take 3-7% off the heating in the PDR
    shells (the H2 share x 0.3-0.45), nearly all of it through the
    formation energy.

### pn150k 41^3 at 14 iterations (2026-10-04)

`runs/h013-b2a-pn41-it14`: H-012's pn150k input with maxIterateMC 14
(the run's own copy), this step's binary. Its six level-model calls
through iteration 9 repeat `runs/h012-b1-pn41`'s to every printed digit.

**Where H-012's coupled transition settles.** 1-0 S(1) per call,
iterations 9-14: 18.6, 20.9, 23.1, 24.4, 25.2, 25.6, finished 26.0
[1e30 erg/s] - steps of 12, 10, 5.4, 3.5, 1.7, 1.6%, halving: some 2%
remain. The per-call change of the Solomon rate falls 0.33 (iteration
9), 0.28, 0.25, 0.24, 0.24, 0.23: a floor, the field's noise (hiipdr's
is 0.5-0.6 at its packet count). On the finished model's fixed field
it is 0.019 (median), 0.062 (90%), against 0.092 and 0.27 at 9.

| | A, 9 it. | B, 9 it. | B, 14 it. |
|---|---|---|---|
| 2x(H2) = 0.5 first at, x/y/z [pc] | 0.379, 0.409, 0.379 | 0.394, 0.425, 0.394 | 0.364, 0.394, 0.349 |
| x(H2) at 0.238 / 0.325 / 0.412 pc | 1.9e-2 / 0.142 / 0.307 | 9.2e-4 / 0.058 / 0.285 | 3.1e-3 / 0.116 / 0.337 |
| Te at 0.152 pc (the H+/H front) [K] | 3167 | 3070 | 4239 |
| Hbeta [1e36 erg/s] | 0.02725 | 0.02725 | 0.02685 |
| 1-0 S(1) / Hbeta | 1.062e-3 | 7.79e-4 | 9.68e-4 |
| 2-1 S(1), 0-0 S(0), S(1), S(2), over A at 9 | 1 | 0.72, 0.95, 0.80, 0.93 | 0.90, 1.06, 0.99, 1.06 |

So H-012's pn150k result at 9 iterations was mostly the transition still
on its way: at 14 the front is one cell inside stage A's (at 9), the
lit edge still has less H2 (0.238 pc: 1/6 of A's) and the deeper gas
more, and the lines are 0.90-1.06 of A's. The ionized gas moves too
(Hbeta -1.5%, the front's Te +38%), so stage A itself needs 14
iterations for the comparison: `runs/h013-A-pn41-it14`, queued.

**The heating**, grid totals [erg s^-1, the octant]: MOCASSIN's 2.53e35.

| term | levels | 3D-PDR | ratio |
|---|---|---|---|
| formation | 3.31e31 | 4.33e31 | 0.76 (1.142 against 1.5 eV, graphite) |
| dissociation | 1.17e31 | 1.09e31 | 1.07 (0.438 eV per dissociation, range 0.13-0.68) |
| collisions within X / FUV pumping | +2.8e30 | 5.1e29 | 5.5 |
| the three | 4.75e31 | 5.47e31 | 0.87 |

The collisional term heats in most cells (+3.9e30) and cools in 737
(-1.1e30). By shell, as fractions of MOCASSIN's heating (medians):
formation 2.2-9.3% (3D-PDR's 2.8-12.1%), dissociation 0.8-3.3% (both),
collisions 0.09-1.15% (3D-PDR's pumping 2e-6 at 0.195 pc, 1e-9 deeper,
3e-4 at the front's 4200 K). Handing the three over takes 0.5-1.7% off
the PDR's heating. Cloudy's H2 photodissociation heating in its own
pn150k is 0.4-1.0% of its heating; our dissociation term is 0.8-3.3% of
ours, in gas 15-20 K colder (H-007).

### Step 2b: the handover (built; runs queued)

In pdrStep, after CALC_HEATING (3D build), the three H2 terms become the
level model's for the cell, on the chemistry's own rate and abundances:

  - formation: RATE(NRGR) n_H n(H) times the kinetic energy per molecule
    formed on this cell's grains (h2Heat 3);
  - dissociation: n(H2) times the atoms' kinetic energy per molecule
    (h2Heat 1), which is the levels' Solomon rate the chemistry already
    uses (H-012) times the energy of each dissociation;
  - collisions within X: n(H2) times the net heating per molecule at the
    level model's Te (h2Heat 2), negative where H2 cools the gas.

heat(12) is TOTAL_HEATING's sum again (heat(1) and heat(3) are not in it),
and pdrHeatXtra carries the three as it carried 3D-PDR's: held through
MOCASSIN's temperature search, following Te from one iteration to the
next. pdrHeatH2 keeps 3D-PDR's values for comparison. The collisional term
is net, as Cloudy's HeatDexc (which Cloudy splits by sign into heating and
cooling): MOCASSIN's balance only needs H - C, and at its root
H = C > 0, so the convergence test against thLimit x heatInt (teSolver
0, both fixtures; update_mod.f90:688) is still met there. The 1D build, and models h2LevelModel does not
handle, keep 3D-PDR's terms (h2Heat is never allocated there).

Whether holding the collisional term through the search is enough: on
hiipdr it is never above 0.6% of the heating (above), and on pn150k
(`runs/h013-b2a-pn41-it14`, below) never above 1.2%. It is.

### Step 2b on hiipdr 21^3 (2026-10-04)

`runs/h013-b2b-hii21` against `runs/h013-b2a-hii21` (the same input; 2a
hands nothing over, so its physics is H-012's):

| | 2a (3D-PDR's H2 heating) | 2b (the levels') |
|---|---|---|
| Te at 4.86 / 7.64 / 9.03 / 10.42 pc [K] | 51.4 / 43.9 / 37.7 / 33.3 | 50.7 / 42.9 / 36.7 / 32.6 |
| Te at 15.97 / 17.36 / 18.75 pc [K] | 12.6 / 11.4 / 10.7 | 12.3 / 11.1 / 10.5 |
| x(H2) by shell | | within 1-2% |
| 2x(H2) = 0.5 first at | 9.72 pc (all axes) | 9.72 pc (all axes) |
| sum rule | -1.5e-7 .. +3.0e-8 | -1.5e-7 .. +3.0e-8 |
| 1-0 S(1), 2-1 S(1) / Hbeta | 7.77e-4, 4.11e-4 | 7.63e-4, 4.04e-4 (0.98) |
| 0-0 S(0), S(1), S(2) / Hbeta | 3.04, 4.25, 5.47e-4 | 3.07, 4.17, 5.49e-4 (0.98-1.01) |
| Hbeta [1e36 erg/s] | 8.58324 | 8.58172 |
| run time | 9 min 02 s | 10 min 16 s |

Taking 3-7% off the PDR's heating (the formation energy, 0.834 against
1.5 eV, nearly all of it) cools every PDR shell by 0.3-1.0 K (1-3%), the
same sign in all of them; the chemistry and the lines move by no more
than the iteration-to-iteration scatter (H-012). The binary that ran
and a clean build of this commit have the same code and data; only
the embedded `git describe` string differs (5ce1ee0 against 2975daa).

### Step 2b on pn150k 41^3, 14 iterations (2026-10-04)

`runs/h013-b2b-pn41-it14` against `runs/h013-b2a-pn41-it14` (the same input):

| | 2a | 2b |
|---|---|---|
| Te at 0.152 (the front) / 0.195 / 0.238 / 0.325 pc [K] | 4239 / 142.9 / 60.5 / 40.8 | 4143 / 138.5 / 60.2 / 40.5 |
| Te at 0.368-0.585 pc | | within 0.1-0.3 K |
| x(H2) by shell | | within 1-2% (+10% at the front) |
| 2x(H2) = 0.5 first at, x/y/z [pc] | 0.364, 0.394, 0.349 | 0.364, 0.394, 0.349 |
| sum rule | -1.0e-7 .. +3.0e-8 | -1.0e-7 .. +3.0e-8 |
| 1-0 S(1), 2-1 S(1), 0-0 S(0), S(1), S(2), 2b over 2a | | 0.99, 0.99, 1.00, 1.00, 1.00 |
| Hbeta [1e36 erg/s] | 0.02685 | 0.02684 |
| heating: the three H2 terms, levels / 3D-PDR | 0.87 | 0.87 |

On pn150k the handover takes 0.5-1.7% off the PDR's heating (above), and
the gas answers by 0.1-4 K, most of it in the warm layer where H2 turns
on (0.195 pc, 143 -> 139 K); the lines move by under 1%. The run took 2 h
10 min against 2a's 1 h 40 min: its iterations 2-11 ran 1.3-1.9x slower,
level-model calls included (the same work in both), and 12-14 at 2a's
speed (calls of 280, 277, 278 s against 278, 278 s), so that was the
machine, not the change.

### Stage B against stage A on pn150k, both at 14 iterations (2026-10-04)

`runs/h013-A-pn41-it14` (H-011's binary, the 14-iteration input) against
`runs/h013-b2b-pn41-it14` (stage B with both steps):

**Stage A was not converged at 9 either**: from 9 to 14 iterations its
lines rise 6-10% (1-0 S(1) 1.09x, 2-1 S(1) 1.10x, 0-0 S(0)-S(2) 1.06-1.08x),
its front moves one cell in (0.379, 0.409, 0.379 -> 0.364, 0.379, 0.364 pc)
and Hbeta falls the same 1.5% as stage B's. Run time 1 h 14 min, the level
model 1,463 s (4 sweeps).

| | A, 14 it. | B, 14 it. | B/A |
|---|---|---|---|
| 2x(H2) = 0.5 first at, x/y/z [pc] | 0.364, 0.379, 0.364 | 0.364, 0.394, 0.349 | within a cell |
| x(H2) at 0.195 / 0.238 / 0.282 / 0.325 pc | 4.3e-4 / 2.0e-2 / 7.3e-2 / 0.156 | 2.6e-5 / 3.2e-3 / 3.3e-2 / 0.116 | 0.06 / 0.16 / 0.46 / 0.74 |
| x(H2) at 0.368 / 0.455 / 0.585 pc | 0.245 / 0.368 / 0.443 | 0.239 / 0.399 / 0.463 | 0.98 / 1.08 / 1.05 |
| Te by shell | | | within 0.1-3 K (the heating, above) |
| 1-0 S(1) / Hbeta | 1.162e-3 | 9.63e-4 | 0.83 |
| 2-1 S(1), 0-0 S(0), S(1), S(2) | | | 0.82, 1.00, 0.91, 0.99 |
| Hbeta [1e36 erg/s] | 0.02685 | 0.02684 | 1.000 |

Against Cloudy's 40 strongest H2 lines (median ours/Cloudy):

| upper level | lines | A, 9 it. | A, 14 it. | B, 14 it. | B/A at 14 |
|---|---|---|---|---|---|
| v = 0, ortho | 6 | 0.86 | 0.92 | 0.81 | 0.88 |
| v = 0, para | 3 | 1.63 | 1.75 | 1.71 | 0.98 |
| v = 1, ortho | 8 | 1.05 | 1.15 | 0.95 | 0.83 |
| v = 1, para | 5 | 2.63 | 2.81 | 2.73 | 0.97 |
| v >= 2, ortho | 12 | 1.00 | 1.10 | 0.90 | 0.82 |
| v >= 2, para | 6 | 2.54 | 2.71 | 2.63 | 0.97 |

What stage B does on pn150k, converged: where the levels' rate is above
the chemistry's (the lit edge, 0.15-0.3 pc) the warm molecular layer
thins - x(H2) down to 0.06-0.74 of A's - and the shielded gas behind it
gains 5-8%. The ortho lines lose 12-18% (the vibrational ones, 1-0 S(1)
and 2-1 S(1), 17-18%), because the edge is the warm, ortho-rich part of
the cloud; the para lines, vibrational or rotational, 0-3%. The front stays within a cell of stage A's.
Against Cloudy the ortho lines go from 0.92-1.15 to 0.81-0.95 and the para
lines stay 1.7-2.7x, which is the damping width (H-008: x3.2 on para,
x2.2 on ortho) and not changed here.

### Not yet known

  - Whether 14 iterations are enough for either stage on pn150k: B's
    1-0 S(1) steps were halving with ~2% to go; A's 9-to-14 change says
    the ionized gas itself (Hbeta, the front's Te) was still settling.
    The fixture's input says 9.
  - The field's per-line noise (H-012) under more packets.
  - The remaining H-002 requirements: formation into levels by the H-
    and H2+ routes, and destruction of excited H2 by electrons, which
    matter in the transition zone (D-387, D-389).

---

## H-014 - Artifacts: stage B on the three comparison pages (2026-10-04)

The user: "update the comparison artifacts including the hiipdr and 150kpn
so I can look at the plots".

### Figures

`tools/h013_figures.py` (new): stage A against stage B on one fixture, with
Cloudy where it has the quantity, in the Cloudy pages' style (d260_roellig's
readers, bins, A_V axis from the star and radius on the upper axis). Six
panels: the transition (x(H+), x(H), 2x(H2)); the H2 photodissociation
rate each chemistry used (stage A the network's, stage B the levels';
Cloudy's PHOTON + H2 -> 2H for H2 and H2*, over n(H2), from its saved
destruction rates); the gas temperature; stage B's three H2 heating terms
against 3D-PDR's and Cloudy's photodissociation heating; the emissivity of
2.12, 17.0 and 28.2 um (Cloudy's zones from .h2emis); C+, C and CO.

  - pn150k: `runs/h013-A-pn41-it14` against `runs/h013-b2b-pn41-it14`;
    Cloudy `d389-cloudy-h2s/150k`, which is the page's own d302 model
    (both `Database H2 limit -10`) with more saves.
  - hiipdr: `runs/h011-v7-hii21` against `runs/h013-b2b-hii21` (21^3, 11
    iterations); Cloudy `d277-cloudy/hiipdr`, the page's, which has only
    Cloudy's small H2 model: no Cloudy lines, rate or heating there.
  - The numbers in the pages' tables are the pages' own tools on these
    runs: `d285_kpis.py` / `d285_kpis_hiipdr.py` (crossing, selected
    depths, front, C+ = C), `h012_heat.py`, `h009_lines.py`.

Read off the figures and tools, in addition to H-012/H-013:

  - pn150k: H/H2 crossing A_V 0.395 (A) and 0.396 (B) against Cloudy's
    0.368; n(H2) at A_V 0.20 / 0.30 / 0.50 = 0.42 / 81 / 381 (A), 0.025 / 39
    / 412 (B), 0.016 / 110 / 394 (Cloudy): at the edge stage B is 1.6x
    Cloudy's where stage A was 26x, at 0.30 it is further (0.36 against
    0.73). Cloudy's rate per molecule tracks stage A's network rate in the
    ionized gas and stage B's levels at the edge, and is below both deep.
    Both stages make some 2.12 um in the ionized transition zone, where
    Cloudy has none (D-387, D-389).
  - hiipdr 21^3: crossing 1.505 (A) and 1.409 (B) against 1.090; n(H2) at
    A_V 1.00 / 1.50 = 0.021 / 24.3 (A), 0.035 / 34.9 (B), 14.1 / 46.2
    (Cloudy); the front 3.770 pc in both against 3.765 (in A_V 0.521 against
    0.446: the 21^3 cell); C+ = C 2.164 / 2.165 against 2.950.

### Pages

  - **H2 Lines in MOCASSIN v4** (https://claude.ai/artifact/B98zztmSp6yCK9NAy83PE8):
    a "Stage B" section after the summary, with both fixtures' six figures
    in a two-column grid (a click widens one to the row), pn150k's line and
    40-line tables at A 9, A 14 and B 14 iterations, hiipdr's table, and
    the noise and cost; kicker, lead, a "Stage B" finding and the footer
    updated. The stage-A sections are unchanged.
  - **hiipdr Against Cloudy v19** (https://claude.ai/artifact/PBCP2hf3SzMMn5t6PYLDtx)
    and **150 kK PN Against Cloudy v17** (https://claude.ai/artifact/DofNhQwr6apCKo2BR8y1JV):
    a section "The H2 level model as the physics", marked as the h2-model
    branch, after the headline numbers: what stage B hands over, the runs,
    the six figures (in the pages' zoom viewer), a table and a reading;
    the eyebrow and the lede note the update. Nothing else on either page
    changed (asserted replacements on the published versions, which were
    read in full before republishing). The production figures and numbers
    stay production's (d377 runs); the new sections say where the branch's
    runs differ (hiipdr 21^3 against the page's 31^3; pn150k 14
    iterations against 9).
  - Builders in the scratchpad (`h007page/gen.py` with `stageb.html`,
    `h013pages/build.py`). Rendered headless at 1100 and 400 px before
    publishing; one wording slip found that way and fixed (the hiipdr
    section said "the figures above" of figures that come below it).

### The whole-model figures, and hiipdr at 31^3

The user: "You did not update the figures of The whole model, star to cloud
edge, with the new runs?" They had not been: the first version of this entry
added a section and left the pages' main Roellig figures on production's
d377 runs.

  - The three figures (`tools/d260_roellig.py --cloudy`, no options, the
    pages' Cloudy models) are now stage B's: pn150k from
    `runs/h013-b2b-pn41-it14` (449 ionized and 34,935 PDR cells), hiipdr from
    a new `runs/h013-b2b-hii31`. The figure text names the run, and says
    that the headline numbers and the tables further down are still the
    production run's (not rebuilt). Builder: `h013pages/build_whole.py`
    after `build.py`, asserted replacements inside that section only, and
    the embedded images checked byte for byte against the new SVGs.
  - **hiipdr at 31^3.** The page's figures are 31^3, so stage B was run at
    the fixture's own settings: 31^3, 11 iterations, seed 1001, 14 ranks,
    30 min 54 s (`runs/h013-b2b-hii31`, step 2b's binary). Its stage A is
    H-007's `runs/h007-full-hii31` (the same input; stage A's MOCASSIN
    physics does not depend on the level model), which reproduces the
    production page's own numbers: front 3.841 pc, crossing A_V 1.447 (the
    page: 1.446), T_gas 51.3 and 46.8 K at A_V 0.70 and 1.00 (the page: the
    same).

| hiipdr 31^3 | stage A | stage B | Cloudy |
|---|---|---|---|
| H/H2 crossing A_V | 1.447 | 1.407 | 1.090 |
| n(H2) at A_V 0.70 / 1.00 / 1.50 [cm^-3] | 3.5e-4 / 0.19 / 30.0 | 8.5e-5 / 0.050 / 34.8 | 5.8e-4 / 14.1 / 46.2 |
| T_gas at A_V 0.70 / 1.00 / 2.00 [K] | 51.3 / 46.8 / 22.1 | 50.6 / 46.0 / 21.8 | 48.0 / 49.3 / 28.4 |
| C+ = C, A_V | 2.266 | 2.266 | 2.950 |
| front, radial shells [pc] | 3.841 | 3.842 | 3.765 |
| 2x(H2) = 0.5 first at (all axes) [pc] | 11.02 | 10.37 | |
| 1-0 S(1), 2-1 S(1) / Hbeta | 9.02, 4.80e-4 | 7.45, 3.95e-4 (0.83, 0.82) | |
| 0-0 S(0), S(1), S(2) / Hbeta | 2.87, 4.40, 5.27e-4 | 2.97, 4.05, 5.31e-4 (1.03, 0.92, 1.01) | |
| Hbeta [1e36 erg/s] | 9.29574 | 9.29664 | |
| sum rule | -1.8e-7 .. +3.0e-8 | -1.8e-7 .. +3.0e-8 | |

**At 31^3 hiipdr behaves like pn150k.** At the lit edge (4.9-7.6 pc) the
levels' rate is 1.2-2x the network's and x(H2) falls to 0.12-0.46 of stage
A's; behind it (9-12 pc), where the levels' rate is 0.5-0.8x, x(H2) is
1.06-1.20x. The pumped lines fall to 0.82-0.83 and the rotational lines move
by -8 to +3%. Heating: levels / 3D-PDR = 0.56 (formation), 1.06
(dissociation, 0.431 eV), the three 0.67, the collisional term at most 0.65%
of the heating; every PDR shell 0.2-1.0 K colder. On a fixed field the
finished model's call moves the rate by 2.4% (median), 7.8% (90%).

**The 21^3 hiipdr numbers of H-012, H-013 and this entry's first version
were the grid's.** There the vibrational lines rose 5-7% and the rotational
23-27%, and the crossing moved 0.10 mag; the lit edge sat inside one 0.97 pc
cell and its loss of H2 was not resolved. The pages now carry the 31^3 pair
(hiipdr Against Cloudy v20, H2 Lines in MOCASSIN v5, both with the 21^3
reading named as superseded); 150 kK PN Against Cloudy is v18.

### Status

Done. The pages are private until shared from each page's Share menu.

## H-015 - The pages rebuilt on stage B; the 3D-PDR reference re-run; pn150k's iteration count (2026-10-04)

The user: "update all relevant artifacts to reflect new model results".

H-014 put stage B into the pages as a section and as the whole-model
figures; every other number on the two Cloudy pages was still production's
(the d377 runs), and the 3D-PDR page was still D-275's. Each page is now
rebuilt on the stage B runs, every number from the page's own tools.

### hiipdr Against Cloudy v21

`runs/h013-b2b-hii31` (31^3, 11 iterations, 74.6%) throughout: header,
headline numbers, selected depths, the ionized gas matched in radius, the line
table and the reading, from `d285_kpis_hiipdr.py`, `d326_check.py` and the
pages' line script. The stage B section becomes "Since version 18" with a
table against version 18 (`runs/d377-hii`); the matched-models table names the
level model; the history sections' "now" columns are relabelled. Crossing
1.407 (Cloudy 1.090), C+ = C 2.266 (2.950), PDR T 22-49 K (29-50), front
3.842 pc (3.765). Builder `h013pages/build_hii21.py` after `build.py` and
`build_whole.py`.

### 150 kK PN Against Cloudy v19, v20

`runs/h013-b2b-pn41-it14` (41^3, 14 iterations, 91.7%, 2 h 20 min) throughout,
with a table of version 16 (`runs/d377-pn`, 9 iterations) | stage A at 14 |
stage B at 14 | Cloudy. Builder `h013pages/build_pn19.py`.

**pn150k is not converged at 9 iterations, in the ionized gas.** Stage A at
14 iterations (`runs/h013-A-pn41-it14`) against stage A at 9
(`runs/h011-pn41`), same input, seed and 14 ranks:

| | stage A, 9 it. | stage A, 14 it. | stage B, 14 it. | Cloudy |
|---|---|---|---|---|
| Hbeta [1e34 erg/s] | 2.725 | 2.685 | 2.684 | 2.78 |
| He II 4686 / Hbeta | 0.2898 | 0.3368 | 0.3368 | 0.279 |
| [O III] 4363 | 0.1567 | 0.1774 | 0.1775 | 0.155 |
| [O III] 5007 | 13.01 | 13.79 | 13.79 | 13.19 |
| [O IV] 25.9 um | 4.12 | 4.49 | 4.49 | 4.75 |
| He I 5876 | 0.0915 | 0.0861 | 0.0861 | 0.077 |
| He2+ front [pc] | 0.0831 | 0.0870 | 0.0870 | 0.0880 |
| converged | 92.1% | 92.0% | 91.7% | |

Stage B agrees with stage A at 14 to 0.1% in the ionized gas, and stage A at
9 reproduces production's version 16 run (5 ranks) to 0.1% there (Hbeta 2.725
against 2.726, He II 0.2898 against 0.2896). So the change is the iteration
count, and production's 9-iteration pn150k runs are not converged in the He2+
zone: five more iterations move the He2+ front onto Cloudy's (6% short ->
1%) and [O IV] to 5% low, while He II 4686 goes from 4% to 21% above Cloudy
and [O III] 4363 from 1% to 15%. **The convergence percentage did not see
it** (92.1% at 9, 92.0% at 14 in stage A): the quantity it tests does not
include the He2+ zone's lines. Whether 14 iterations are enough has not been
tested; production's fixture is unchanged (nothing in the production
worktree is touched from this branch).

Corrections on the page:

  - Version 16's "CO ... 0.09x at A_V 0.30" was version 15's number
    (`runs/d363-pn`: 2.32e-7 / 2.69e-6 = 0.086) carried over; version 16's
    own run had 0.072. Now 0.033 (stage A at 14: 0.085, with twice the H2).
  - Version 18's "Stage B costs 4-5.5 min per PDR iteration": measured, the
    call takes 4.6-5.5 min on a quiet machine (B2a's run: 278-332 s after a
    first call of 170 s as the PDR switches on) and adds 3.7-4.7 min to each
    PDR iteration after the first (B2a - A14 at iterations 5-14, B14 - A14 at
    12-14; the first adds 1.1 min). v19 said 4.6-5.4 and "to each"; v20
    corrects both.
  - Stage B's run took 2 h 20 min (01:52-04:12). Its iterations 2-11 ran
    1.2-1.9x slower than B2a's, which does the same work, and the
    fixed-work parts of its level-model calls (the site search) 1.4x
    slower, so the machine was slower then; why is not known (the hiipdr
    21^3 test overlapped only its first nine minutes). Iterations 12-14 took
    6.8-7.1 min, as B2a's.
  - The stage B section said "the 9 iterations of the run above" when the
    run above became the 14-iteration one; the rail rounded stage A's
    n(H2) at A_V 0.20 to 26x Cloudy's (0.419 / 0.01577 = 26.6, now 27x);
    two history sentences claimed the present tense ("Hbeta now agrees to
    1.9%", "since this version (D-371)").

### hiipdr Against 3D-PDR v2

The page was D-275's (2026-09-14): `runs/d266-cfull` against
`runs/d275-3dpdr-hiipdr` at G0 123.79.

  - **`tools/d275_3dpdr_reference.py` could not read today's runs.** It read
    `pdrGrid.out` v1 (45 columns, the zone flag first), which D-352 replaced.
    It now reads either layout through `d260_roellig.read_pdrgrid` and takes
    the PDR as the figures' own label, x(H+) < 0.3 (`read_run`), asserting
    that the face A_V is the figures' A_front; the parameter template can be
    passed (this worktree has no `runs/d257-3dpdr-standalone`). On
    `runs/d266-cfull` it reproduces D-275's depth grid byte for byte and its
    parameter file except G0: 127.04 against the flag's 123.79, because the
    two definitions differ in 2 cells at A_V 0.472 (14 face cells instead of
    12). Reading the flag reproduces 123.79 from 12 cells exactly.
  - **Stage B's face field is 119.73 Draine** (12 cells at A_V 0.4659,
    16-84% 118.6-129.7), 6% below d266's on the same definition. A_V / N_H
    is unchanged (PDR fit 5.1714e-22 on B31, 5.1709e-22 on d266; the
    reference keeps D-264's 5.177e-22), the composition file is identical,
    and the slab's grid is byte-identical. The reference was re-run in
    `runs/h014-3dpdr-hii31` with D-257's binary and D-275's chemistry files:
    rc 0, under a minute, x(H) + 2x(H2) + x(H+) closes to 3.0e-8, carbon at
    2.2e-4. The lower G0 cools the reference by 0.9% (median; at most 1.9%)
    and moves its crossing 1.558 -> 1.548.
  - **`tools/h014_3dpdr_kpis.py`** (new) computes the page's numbers with
    `d285_kpis_hiipdr.py`'s conventions, so the MOCASSIN side of both hiipdr
    pages is one computation. On the D-275 pair it reproduces the page:
    crossing 1.192 / 1.558 (the page: 1.20 / 1.56), C+ = C 2.128 / never,
    PDR T 21-26 / 83-181 K (22-26), every selected-depth entry, 108-1035
    cells per bin, and the ratio ranges (e- 0.74-1.01, C+ 0.94-1.00, H+
    0.25-0.56, field 0.81 then 0.37-0.49, dust 0.97-1.19).
  - **Two D-275 statements do not reproduce.** (1) "MOCASSIN's field falls
    at 3.34 per magnitude": no method gives it (all PDR cells 2.98, the
    median profile 3.27, the selected-depth medians 3.16, A_V 0.55-2.5
    3.31), because the field is not one exponential (on d266 3.84 e-folds
    per magnitude at 0.55-1.5, 2.82 at 1.5-2.9); the page now gives the two
    segments. (2) "CH and H2O sit above it past A_V 1": on d266 H2O was 3-21x
    *below* the reference at A_V 1.0-2.0 (CH 14-49x above); the page says
    so. Neither was a conclusion anything rested on.

| MOCASSIN / reference | D-275 (d266) | now (B31) |
|---|---|---|
| crossing A_V | 1.192 / 1.558 | 1.407 / 1.548 |
| C+ = C, A_V | 2.128 / never | 2.266 / never |
| PDR T_gas, A_V 0.7-2.0 [K] | 21-26 / 83-181 | 22-49 / 82-180 |
| T_gas ratio, selected depths | 0.11-0.34 | 0.25-0.34 |
| T_dust ratio | 0.97-1.19 | 1.03-1.29 |
| field ratio at 0.55 / 0.7-2.0 / 2.5-2.9 | 0.81 / 0.37-0.55 / 0.47-0.49 | 0.79 / 0.46-0.58 / 0.77-1.01 |
| field e-folds per mag, 0.55-1.5 / 1.5-2.9 (reference 3.02) | 3.84 / 2.82 | 3.60 / 2.45 |
| n(H2) ratio at 0.70 / 1.00 | 1/30 / 3.4 | 1/1350 / 1/24 |
| H2 MOCASSIN = reference at A_V | 0.84 | 1.24 |
| C+ ratio at 2.5-2.9 | 1e-7 | 0.19-0.21 |
| e- ratio at 2.5-2.9 | 0.14-0.16 | 0.27-0.28 |
| O+ ratio at 0.7-1.5 / 2.5-2.9 | 5e-5-3e-3 / 0.004-0.04 | 0.012-0.040 / 6-51 |
| He+ ratio at 2.5-2.9 | 12-14 | 6-7 |
| CO ratio to 1.5 / at 2.5-2.9 | 4-9 / 11-23 | 0.6-2.9 / 14-24 |

Read: the PDR gas is a quarter to a third of the reference's temperature
where it was a ninth to a third; deep carbon no longer collapses (O-01); at
depth MOCASSIN's field now equals the slab's, where it was half; the lit edge
has far less H2 than the slab's (1/1350 at A_V 0.70; stage A had 4x more
than stage B there). Not known: which of D-276 .. D-390 and H-012/H-013
made each change (the Cloudy pages' history takes them one at a time against
Cloudy; not here), and why deep O+ runs 6-51x above the slab's, with He+
6-7x (not investigated).

### H2 Lines in MOCASSIN v6

Its cost had never been brought past H-007: the summary still said the level
model took 62 of a 98-minute run. Now: once on the finished model 25 of 60
minutes since H-011 (1,474 s); in stage B a call per PDR iteration, 4.6-5.5
min on a quiet machine, 62.5 min over a 14-iteration run (B2a's 12 calls)
against stage A's single 24.4-min call (`runs/h013-A-pn41-it14`, 4 sweeps,
1,462 s). Stage B's final call starts from the last iteration's populations
and converges in 2 sweeps (541 s on pn150k, 128 s on hiipdr 31^3); hiipdr
31^3's calls take 66-105 s, 12.9 min in all, and its 11 iterations 31 min.
"Not yet known": the colder shielded gas no longer says the thermal balance
is untouched (stage B's H2 heating moves it 0.1-4 K); two items added, how
many iterations pn150k needs and whether the field's per-line noise biases
the rate.

### Status

Done: hiipdr Against Cloudy v21, 150 kK PN Against Cloudy v20, hiipdr Against
3D-PDR v2, H2 Lines in MOCASSIN v6. Not rebuilt: Fine Grids Against Cloudy,
which would need stage B runs on the fine grids (hours each at fewer ranks);
it stays production's.

## H-016 - Stage A first, the level model only at the end? (2026-10-04)

The user: "Could we use the H2 chemistry from before the level calculations
to get close to convergence and include full level calculation just at the
end to get more time efficiency?"

### What the existing runs say (logs only, no new runs)

  - **Cost**, pn150k 41^3, 14 ranks, quiet machine (`runs/h013-b2a-pn41-it14`,
    which does stage B's work): the level model's 12 calls take 62.5 min:
    170 s at iteration 4, 278-332 s at 5-14, 541 s for the finished model (2
    sweeps). The calls at iterations 4-9, while the PDR builds up
    (convergence 0.3% -> 92%), take 29 min. Stage A's single call on its
    converged model takes 24.4 min (`runs/h013-A-pn41-it14`, 4 sweeps).
  - **A cold start needs 2-3 sweeps.** On stage A's converged model, sweeps
    1-4 give Solomon dissociations 2.05, 1.51, 1.49, 1.49e44 s^-1 and 1-0
    S(1) 4.97, 3.16, 3.12, 3.12e31 erg/s: the first sweep overshoots by 38%
    and 59%, because the pumping lines' self-shielding starts from the
    initial populations.
  - **The coupling has a slow tail of its own.** In the all-stage-B run,
    after the PDR has built up, the pumping absorptions per call are 7.06,
    7.53, 7.82, 7.97, 8.04, 8.09e44 s^-1 at iterations 9-14 (increments
    halving) and 1-0 S(1) rises 2.07 -> 2.59e31 (+25%); the median per-cell
    rate change per call falls 0.86, 0.66, 0.64, 0.43, 0.33, 0.28, 0.25,
    0.24, 0.23 (iterations 5-13) to the Monte Carlo floor. Stage A's lines
    rose 6-10% over 9 -> 14 iterations, so part of the tail is common to
    both stages (the ionized gas still converging, H-015) and part is the
    coupling's.
  - **The two fixed points are close where the shielding is set:** crossing
    0.395 / 0.396, shielded gas within 5-8%, T within 1 K past A_V 0.3. They
    differ at the warm edge (n(H2) at A_V 0.20 17x lower in stage B) and in
    the lines (1-0 S(1) 0.83x).

### Estimate, not measured

Stage A for iterations 4-9 and stage B for 10-14 (the first call with 3
sweeps) would save the build-up calls (29 min) less the cold start's extra
sweeps (~10 min): ~20 min of B2a's 108, 15-20%; hiipdr 31^3 about 5 of 31 min.
The tail above suggests stage B needs 4-5 iterations after the switch;
that is the number to measure.

Fine grids: a cold call costs more per cell on larger grids (0.86, 0.99, 1.40
rank-seconds per cell at hiipdr 21^3 / 31^3 / 41^3, H-007's runs: the paths
are longer). Extrapolated, one sweep on pn150k 81^3 at the 3 ranks memory
allows would take hours, so the schedule alone would not make stage B
affordable there; letting each rank's level model use several cores
(threads over cells) would be the larger lever. Not measured either.

### The rule

CLAUDE.md lists "switches that select ownership at run time" among the
largest sources of defects. A keyword "levels from iteration N" is one: set
too late, a run finishes on stage A physics and looks converged, and
MOCASSIN's convergence percentage would not notice (H-015: 92% in both
stages, blind to a 16% change in He II). If adopted, the design would make
the network rate only the starting guess: no keyword; the run cannot finish
until stage B has had its iterations and passed its own test (median
per-cell rate change at the noise floor; pumping total and H2 lines steady
to ~1% between calls), followed by the finished model's call. That is the
user's decision.

### Proposed test, no code change

Stage A stopped at iteration 9, then `mocassinWarm` with stage B for
iterations 10-14, against `runs/h013-b2b-pn41-it14` at the same total
iteration count; the same on hiipdr 31^3 (stage A to 7, stage B 8-11, against
`runs/h013-b2b-hii31`). First check that the warm start resumes the PDR state
on this branch.

### Decision

The user: "lets keep the full level solution since it is more self
consistent." Stage B stays as built: the level model is solved every PDR
iteration from the first, and the chemistry's H2 photodissociation and the
thermal balance's H2 heating come from it throughout. No schedule and no
keyword; the warm-restart test is not run. The cost stands as measured
(+3.7-4.7 min per PDR iteration on pn150k 41^3).

### Status

Closed (2026-10-04).

## H-017 - What is pending (2026-10-04)

The user: "what other important to-do items we have pending?" Compiled from
this log, production's DEVLOG (D-267's register and its closures) and the
limitations register in `doc/pdr-status.md`; one item is new (marked).

**Decisions for the user**

  1. **Merging stage B into production.** D-388: stage B "stays on the branch
     until every benchmark is re-validated". Done: hiipdr 31^3 and pn150k
     41^3 against Cloudy, hiipdr against 3D-PDR (H-014, H-015). Not done:
     the 1D flavour (it keeps the network's rate, H-012), the warm start, the
     fine grids. *New:* `output/h2Pop.bin` is written (h2Lines_mod) and read
     by nothing, so a resumed run restarts the level model cold, whose first
     sweep overshoots the dissociations by 38% (H-016); with L-14
     (warm-versus-cold equivalence never verified) and D-351's PDR arrays
     missing from the checkpoint.
  2. **Iteration counts and the convergence test.** pn150k needs at least 14
     iterations (H-015); hiipdr's H II front still moves at 11 (L-40). The
     per-cell test has no helium stage (L-40) and nothing for H2 (H-016), so
     its percentage cannot say when either is done. *(Corrected 2026-10-04,
     D-391: it does test x(H2), since D-179, gated at x(H2) > 1e-5, at the
     fixtures' `convLimit 0.10` - a 10% change per iteration. What it cannot
     see is a tail under that: stage B's pumping total moved 7, 4, 2, 1, 0.5%
     per iteration (H-016), and He II about 3% (H-015).)*

**Physics divergences still open**

  3. pn150k's PDR is a third colder than Cloudy's (O-02): photoelectric
     heating per H 0.27-0.44 of Cloudy's, the field no longer the cause.
  4. Transition-zone H2 100-1000x Cloudy's (L-43); the level model lacks
     H-002's requirements 1-3 (formation into levels by the H2+ and H-
     routes, electron colliders, dissociative attachment).
  5. Grain H2 formation 5-25x Cloudy's (L-33), not decomposed.
  6. Unresolved front cells dominate [O I] (L-37); the sub-cell correction is
     an offline estimate (`frontLines`, D-382).
  7. pn150k's ionized gas at 14 iterations: [Ne III] +41-43%, [Ne II] +32%,
     [O II] +20%, He II 4686 +21% against Cloudy; not investigated.
  8. hiipdr's deep carbon (O-01/L-3, mostly Monte Carlo noise at 31^3, L-26)
     and, against 3D-PDR, deep O+ 6-51x and He+ 6-7x the slab's (H-015;
     L-34's missing H+ channels are related).

**Smaller**

  9. The error bars are a four-seed ensemble of pre-D-348 code.
  10. H2 lines are not extincted on their way out (needed for observations,
      not for Cloudy's intrinsic lines).
  11. Stage B's cost: the level model is single-core per rank; threads over
      cells would make the fine grids feasible (H-016).
  12. Low priority at the user's direction: V1/V2 slabs and `ifront` (L-11);
      `mocassinPlot` unrun (L-20).

## H-018 - Production's D-391 merged in: the convergence test (2026-10-04)

The user: "proceed as suggested" (H-017's first item: fix the convergence
test). A production fix (DEVLOG D-391, dc302f2), merged as D-388 asks (merge
e60a836, no conflicts).

What D-391 found and changed, in short: the per-cell x(H2) test had passed
every cell since D-216 (it ran before the chemistry and compared H2den with
the copy just taken of it); it now runs after the chemistry. A
model-integrated test - the emission measure of every ion stage holding 1% of
its element's, the H0/H2/CO contents, the gas temperature weighted by
n_e n(H+), n(H0) and n(H2) - must change by at most `convTotals` (default 2%)
over 3 iterations before a run may stop, and every run now ends saying
whether it converged.

For this branch:
  - **H-017's correction holds and goes further**: x(H2) was tested (D-179)
    but the test could not fail, so stage B's slow H2 tail (H-016) was
    invisible to it as well as to the 10% tolerance.
  - **The pages' runs were not converged** by D-391's measure: pn150k at 14
    iterations (H-015) has the He2+ emission measure moving 5.8% over the
    last 3 iterations and lines up to 5% from iteration 20 (production
    physics, `runs/d391-cv-pn41b`); hiipdr 31^3 at 11, 5.9% (O+) and lines
    up to 8%. The rule passes 2% at 17 (pn150k) and 15 (hiipdr). Stage B's
    own tail (pumping +1, +0.5% at iterations 13-14, H-016) is within that.
    Re-running the pages at converged counts waits on the user's choice of
    counts (production's fixtures are unchanged).
  - Checks on the merged branch: all four flavours and h2Test/h2Slab rc 0
    (own PREFIX); `runs/h018-merge-hii21` (stage B, 21^3, 6 iterations, 14
    ranks): the level model each PDR iteration as before, the integrated
    test reported each iteration, "NOT CONVERGED after 6 iterations: n(H0)
    changed 79.6%", clean exit.

### Status

Done.

## H-019 - The stop decided by the integrated test; the pages' runs at convergence (2026-10-04)

The user, on D-391: "I want the new test to decide when to stop. I think a
tolerance of 2% to 5% is quite good given observational uncertainties. Then
proceed as recommended."

  - Production's D-392 merged in (2abfebe, no conflicts): a run stops when its
    model-integrated quantities moved by at most convTotals (default 2%, the
    strict end of the user's range) over 3 iterations; the cell percentage is
    reported only. All four flavours and h2Test/h2Slab rc 0 on the merge.
  - **The recommended next step, under way: the comparison pages' runs at
    convergence** (`runs/h019-chain.sh`), each at 14 ranks, seed 1001, the
    pages' inputs with only the iteration line changed:
      - stage B, hiipdr 31^3 and pn150k 41^3 (`h019-B-*`, this branch's
        binary): `maxIterateMC 30 90.`, stopped by the integrated test;
      - stage A at the same counts (`h019-A-*`, H-011's binary, mocassin.h011,
        which has a fixed count only) so each A/B pair compares equal
        iterations; production's D-391 snapshots show stage A physics (=
        production's, the convergence % equal to every digit at 9 and 14)
        passes 2% at 15 (hiipdr) and 17 (pn150k);
      - then the 3D-PDR reference on the new stage B hiipdr, and the four
        pages rebuilt on them.

### hiipdr 31^3: stage B stops at 15

`runs/h019-B-hii31` (binary at 2abfebe, `maxIterateMC 30 90.`) passed the
integrated test at iteration 15: largest change over the window 1.958% (Ne+).
The trail, from the run's own report: 19.6% (n(H0)) at 9, 8.70% (n(H0)) at 10,
5.94% (O+) 11, 4.12% (N+) 12, 3.22% (O+) 13, 2.33% (O+) 14, 1.96% (Ne+) 15 -
the slowest quantities are the front's low ions, as D-391 found on production.
The cell count read 69.5% at 15 (68.6-69.7% from iteration 10 on); H-013's
11-iteration run read 74.6%, its x(H2) half passing every cell (D-391). Run time
41:46 (the code's own "total run time per processor"); stage A at the same 15,
`runs/h019-A-hii31` (mocassin.h011), 33:38.

**B15 repeats H-013's B11 through iteration 11.** The resonance-line packet
counts ([D376] lines) are identical at every iteration and the level model's
per-call Solomon statistics identical for every in-run call, so H-013's
`runs/h013-b2b-hii31` against this run is the four extra iterations alone:

| quantity                         | B11 (H-013) | B15     | Cloudy |
|----------------------------------|-------------|---------|--------|
| Hbeta [1e36 erg/s]               | 9.297       | 9.166   | 9.96   |
| front, radial shells [pc]        | 3.842       | 3.831   | 3.765  |
| H/H2 crossing, C+ = C [A_V]      | 1.407, 2.266| 1.400, 2.275 | 1.090, 2.950 |
| [C II] 158 / Hbeta               | 0.1528      | 0.1544  | 0.134  |
| C II] 2326 / Hbeta               | 0.2458      | 0.2385  | 0.174  |
| [O I] 6300 / Hbeta               | 0.06728     | 0.06888 | 0.0104 |
| H2 lines (1-0 S(1) ... 0-0 S(2)) | -           | +2.6 to +3.5% | - |

T_gas at A_V 0.70 / 1.00 did not move (50.6 / 46.0 K).

**Stage A against stage B at 15** (the pair differs in stage B alone):
crossing 1.443 -> 1.400 (0.04 mag toward Cloudy's 1.090, still 0.31 past it);
front 3.831 both; C+ = C 2.274 / 2.275; Hbeta 9.1655 / 9.1657. On stage A's
own field and H2 the levels' rate is 2.3-2.6x the network's in the ionized gas
(the 0.7-3.5 pc shells), 1.2-2.0x at the lit edge (4.9-7.6 pc) and 0.1-0.8x in
the shielded gas; H2 at the lit edge falls to 0.12-0.46 of stage A's and is
1.07-1.20x behind it. The vibrational lines are 0.83 of stage A's, the
rotational -7 to +4%; [C II] 158 -2.6%, [C I] 609/370 -4/-9%, the CO ladder -4
to -9% (less H2 at the edge, less CO). Taking 3-7% off the PDR's heating
cools every PDR shell by 0.1-1.0 K. H2 heating, levels / 3D-PDR over the grid:
formation 0.56, dissociation 1.09, all three 0.67. Per H2 formed on this
silicate the gas gets 0.834 eV; per dissociation 0.433 eV (dissociation-
weighted) - **the hiipdr page said 0.44, a value carried over from pn150k's
0.438; v22 says 0.43.**

Per cell the levels' Solomon rate moves by a median 50-58% from call to call
over the last eight calls (0.96 at the second call), the field noise of each
pumping line's own frequency bin (H-012), while the integrated test settles to
2%.

**Checks on the page numbers.** nums.py (the page tools' logic returning
values) rebuilds version 21's selected-depth and ionized-gas rows from version
21's run exactly (12 of 12), and the "version 18" column of the page's history
table from runs/d377-hii digit for digit. H2 in the ionized gas over Cloudy's
at 1.55 / 3.07 pc is the median of the cells within 0.35 pc over Cloudy
interpolated at the radius (validated: d377-hii 3.91 / 27.7, h013-b2b-hii31
2.81 / 18.1, the published 3.9 / 28 and 2.8 / 18); now 3.9 / 28 (A15) and
2.8 / 18 (B15). Cloudy's front, 3.7645 pc, is 3.76 to two figures: the page
had rounded the printed 3.765 up to 3.77.

### The hiipdr pages (2026-10-05)

  - **hiipdr Against Cloudy v22** (https://claude.ai/artifact/PBCP2hf3SzMMn5t6PYLDtx,
    version 1791169091-5c00): every number and both sets of figures on the
    A15/B15 pair; a new first section, "The run stops when the model has
    converged", with the B11 -> B15 table above; the "Since version 18" table
    now has stage A at 15 as its own column, so version 18 -> stage A is the
    iteration count and stage A -> now is stage B. Built by asserted
    replacements on version 21 as published (byte-identical to the local
    build), every number from nums.py, table rows rebuilt in the old cells'
    formats (the same code rebuilds version 21's rows from version 21's run).
    Two wording corrections besides the numbers: "the first section below"
    now points at the right section, and links take the theme's blue (they
    were the browser's dark blue on the dark theme).
  - **hiipdr Against 3D-PDR v3** (https://claude.ai/artifact/Wyx5Xzwb2QYCL8mCpcVzQk,
    version 1791169150-812e): built on B15 and the reference re-run on its
    face field (G0 119.10, runs/h019-3dpdr-hii31) earlier in this entry's
    work; its one statement about stage A ("4x more H2 at A_V 0.70") checked
    on the A15/B15 pair: 4.14.

### pn150k 41^3: stage B stops at 18 (2026-10-05)

`runs/h019-B-pn41` passed at 18: 1.503% (He2+), after 7.40, 5.37 and 4.15% at
14-16 (the n(H0)-weighted temperature) and 2.01% (He2+) at 17; cell count
85.4% (91.7% at 14 in H-013's run, its x(H2) half vacuous). Run 2:51:46;
stage A at 18 (`runs/h019-A-pn41`) 1:28:38. B18 repeats H-013's B14 through
iteration 14 ([D376] counts and every in-run Solomon line identical). 14 -> 18:
He II 4686 +2.6%, H2 lines +1.3 to +2.9%, He2+ front 0.0870 -> 0.0877 pc
(Cloudy 0.0880). A18 against B18: crossing 0.395 / 0.393 (does not move);
ionized gas within 0.03%; n(H2) at A_V 0.20 24x -> 1.5x Cloudy's, at 0.30 0.72
-> 0.40; ortho lines -10 to -16%, para -1 to -2%; 1-0 S(1) 0.85x, 1.05x
Cloudy's; T within 1 K; CO 2-1 +16%; levels/3D-PDR heating 0.76, 1.10, 0.88.
Per cell the Solomon rate moves a median 23% per call.

**Cost, and the machine.** Stage B's calls took 350-448 s (first 188 s, final
two sweeps 751 s), its settled iterations 9.6-10.2 min against stage A's 3.1:
the level model adds 6.5-7.1 min. H-013's run did the same work at 277-281 s
over its last three calls and 397-458 s before them; the first two
iterations, identical work, took 3.5-3.8 min in B18 and 4.9-5.1 in A18 three
hours later. The machine's speed varies by up to 1.4x; the ranks are not
pinned to the i7-14700's P/E cores; untested. **Correction:** the pn150k page
v20 gave H-013's run as 2 h 20 min; the code's own count is 2:10:23 (ten
minutes were queued time).

### Pages (2026-10-05)

  - 150 kK PN Against Cloudy v21 (DofNhQwr6apCKo2BR8y1JV, 1791174359-8475): the
    A18/B18 pair throughout, a "run stops when converged" section with the
    B14 -> B18 table, the cost and the correction above.
  - H2 Lines in MOCASSIN v7 (B98zztmSp6yCK9NAy83PE8, 1791174425-e5e0): stage B
    on both converged pairs; the iteration item of "Not yet known" replaced
    by the machine's speed; energies per dissociation 0.43-0.44 eV.
  - With hiipdr v22 and 3D-PDR v3 above, all four pages are on converged runs.

### Status

Done.

## H-020 - The warm start resumes the level populations (2026-10-04)

The warm-start fix recommended before the merge decision (H-017), with
production's D-393 (the warm start continues the PDR, merged as b145dfb).

**Defect.** `output/h2Pop.bin` was written (h2Lines_mod) and read by nothing,
so a resumed run's first level-model call started from Boltzmann
populations. **Fix.** At the first call of a warm start, h2LevelModel reads
the file back (`h2PopResume`) when it describes this grid and level set: the
cell count, h2NX, every level's v and J and energy are checked, and on any
mismatch, a truncated file or none the call starts from Boltzmann as before
and says which.

**Test.** `runs/h018-merge-hii21` (stage B, 21^3, 6 iterations) resumed twice
with mocassinWarm on 4 ranks, the first call compared with the checkpointed
run's last:

| first resumed call | 1-0 S(1) | pumping | Solomon dissociations |
|---|---|---|---|
| h018's last call | 5.389e33 erg/s | 1.225e47 s^-1 | 2.212e46 s^-1 |
| populations resumed (`h020-warm-pop`) | +0.2% | -0.4% | -0.6% |
| file withheld (`h020-warm-nopop`) | +127% | +105% | +93% |

Resumed, the first call lands within 0.6% of where the run left off, on a new
Monte Carlo field (1.45 solutions per cell against 1.67 from Boltzmann);
without it, the first resumed chemistry would have been handed twice the H2
photodissociation rate. Both test runs were stopped after their first call
(only that was being tested; D-393 tested the continuation over 8 iterations).
All four flavours and h2Test/h2Slab rc 0.

Still not in the checkpoint: the last call's Solomon rates and H2 heating
(h2Sol, h2Heat), which the first call recomputes before the chemistry reads
them, so nothing stale is used; and production's per-coolant split and extra
heating (L-14, D-393).

### Status

Done.

## H-021 - The gaps in H2 formation and destruction: one was a measurement (2026-10-05)

The user: "lets work on the the gaps in H2 formation and destruction", the
two physics items H-017 listed: 4 (L-43, transition-zone H2 100-1000x
Cloudy's) and 5 (L-33, grain formation 5-25x Cloudy's).

### L-33: withdrawn (production D-394, merged in)

`tools/h021_h2form.py` takes the grain formation coefficient apart one
ingredient at a time, on the converged stage B runs (H-019) against Cloudy.
MOCASSIN's coefficient is h2Cells.out's (the chemistry's own;
rebuilding it from T, T_d and the [D195] areas agrees to 3e-5).

Cloudy forms most of its grain H2 as H2* (`grn,H,H=>grn,H2*`): 95.1% on
pn150k (`runs/d389-cloudy-h2s`) and 94.2% on hiipdr. The hiipdr number comes from
`runs/h021-cloudy-hii`, a rerun of production's `runs/d356-cloudy-hii` that
saves the H2* and H- channels, its input otherwise identical; it took 306 s. D-356 and
D-358 compared only the ground channel. With both channels the coefficient is:

  - **pn150k**: 0.86-1.00 of Cloudy's at A_V 0.20-0.65 (graphite);
  - **hiipdr**: 0.50, 0.60, 0.74, 0.86, 0.91, 0.90 at A_V 0.55, 0.70, 1.0,
    1.5, 2.0, 2.9 (silicate).

Against the ground channel alone it is 18-20x (pn150k) and 8.5-15.6x
(hiipdr), which are L-33's numbers. Ingredient by ingredient:

  - area: x1.04-1.05;
  - grain temperatures bin by bin: 0.95-1.04;
  - gas temperature: 0.79-1.03;
  - **the Cazaux & Tielens surface energies on silicate: 0.45-0.70 at
    T_d 26-37 K.** 3D-PDR's per-material set gives silicate 0.59 at 30 K,
    where Cloudy's single set gives 0.99.

Cloudy's own formula on its own inputs reproduces its saved total to
0.92-1.08. On silicate, then, MOCASSIN forms H2 at about half Cloudy's rate
through hiipdr's transition. That is a candidate share of hiipdr's deeper
crossing (1.40 against 1.09), and is not measured. pn150k's graphite
efficiencies agree, and so does its crossing.

### L-43: real, and what it needs

**Does Cloudy's H2* change the transition zone?** It might have, as it did for
L-33, but it does not. In pn150k's zone (`runs/d389-cloudy-h2s`, .dens389)
Cloudy's H2* is 0.5-1.3% of its H2 at A_V 0.03-0.13, and 40% only at 0.15,
just past the front. The excess is therefore real: our n(H2) (stage B, 18
iterations) over Cloudy's H2 + H2* is:

| A_V  | ours/Cloudy |
|------|-------------|
| 0.05 | 24          |
| 0.10 | 665         |
| 0.15 | 77          |

**Cloudy holds 2e-8 to 4e-6 cm^-3 of H- there, 10^2-10^4 times its H2.**

**Our channels** (`tools/d356_channels.py` on `runs/h019-B-pn41`), at
A_V 0.02-0.15:

  - formation: grains 28-78%, and H + H2+ -> H2 + H+ 22-85%. The H2+ route
    leads from A_V 0.075 outward.
  - destruction: photoionization (the network's H2 + CRP slot carries
    MOCASSIN's own, D-358) 33-83%, photodissociation 13-66%, H+ + H2 ->
    H2+ + H up to 23%. Electron-impact dissociation is 2-3%.

The H2+ route puts H2 straight into the network's ground state, where it
lives 10^7-10^8 s.

**Cloudy** (D-389, `mole_h2.cpp`, `mole_h2_form.cpp`, `mole_reactions.cpp`):

  - gas-phase formation goes into excited levels. H- + H -> H2(v,J) + e follows
    Launay, Le Dourneuf & Zeippen 1991 (state-specific rates,
    data/h2/hminus_deposit.dat). H2+ + H -> H2* + H+ goes into the levels above
    H2*'s energy, LTE-weighted in the large model and v = 4 in the small one;
  - the per-level sinks in the large model are:
      - dissociative attachment e + H2(v,J) -> H- + H (`H2_X_Hmin_back`: the
        total reverse rate times Launay's distribution);
      - collisional dissociation from each level ("rates are just guesses");
      - continuum photodissociation;
      - the network's other sinks, spread evenly.
  - in the zone, H2* is formed by H- + H (~90%) and destroyed by e + H2* ->
    H + H- (~100%) before it relaxes. What is left in ground H2 is grain-made.

### The plan

The level-resolved channels belong to the level model. It owns the levels;
the 33-species network has no H-, and only `rates_full.d` (215 species) does.

  1. **Formation into levels**:
      - H2+ + H at the network's own rate. Cloudy puts it at v = 4; a
        state-resolved set (Krstic 2002) is to be looked for first;
      - H- + H at Launay's state-specific rates, read from Cloudy's file
        into dataPDR/h2 as the other H2 data were (H-003).
  2. **H- in local steady state, per cell**:
      - formation: radiative attachment (Milne-related to photodetachment,
        so no extra constant) and dissociative attachment;
      - destruction: photodetachment on MOCASSIN's own field in the cell,
        associative detachment, mutual neutralization with H+, and electron
        detachment.
  3. **Destruction out of levels**:
      - dissociative attachment by detailed balance from Launay's rates, level
        by level, not Cloudy's distribution-weighted shortcut;
      - H+ + H2(v,J) -> H2+ + H by detailed balance from the H2+ route's
        distribution;
      - collisional dissociation from high levels, if data better than
        Cloudy's guesses exist.
  4. **Stage A first**, as at H-013: on the finished pn150k model, measure:
      - n(H-) against Cloudy's;
      - the destruction per H2 molecule by channel;
      - the net formation the network would get.

     Predict the zone's H2 before handing anything over.
  5. **Then stage B**: hand the chemistry, as rate coefficients like the
     Solomon rate:
      - the level-averaged H+ + H2 charge transfer;
      - the net H- route (2H -> H2, electron-catalysed, the stoichiometry of
        the grain slot);
      - the dissociative attachment destruction (H2 -> 2H once H- is
        neutralized or detached).

     How H- itself enters the network is the design decision H-002 left open:
     carried in the level model (recommended, above) or added as a species.

Electron collisions within X (H-002 requirement 3) are separate, and come
after.

### Status

In progress (L-33 done; L-43 step 1 next).

## H-022 - How much of hiipdr's crossing is the silicate surface energies (2026-10-05)

H-021 found that MOCASSIN forms H2 on hiipdr's silicate at 0.45-0.70 of
Cloudy's rate at T_d 26-37 K. The cause is 3D-PDR's per-material Cazaux &
Tielens surface energies against Cloudy's single set. Is that hiipdr's deeper
crossing? This is a diagnostic, so nothing is adopted. Both parameter sets are
from the literature, and one is not to be chosen because it closes a gap.

**The run:** `runs/h022-ct02-hii31`, built with
`tools/patches/h022_ct02_cloudy_set.patch` (h2_form.F90 given Cloudy's
E_S 200, E_HP 600, E_HC 1e4, E_H2 320 K for both materials). The source was
restored after the build. Input, seed (1001), 14 ranks and 15 iterations are
those of `runs/h019-B-hii31`: `convTotals 1e-6` keeps the test from stopping
it early. Run time 40:29.

| quantity | 3D-PDR set (B15) | Cloudy's set | Cloudy |
|---|---|---|---|
| H/H2 crossing, A_V | 1.400 | 1.363 | 1.090 |
| front, radial shells [pc] | 3.831 | 3.831 | 3.765 |
| C+ = C, A_V | 2.275 | 2.275 | 2.950 |
| n(H2) at A_V 0.70 / 1.00 / 1.50 | 8.5e-5 / 0.050 / 35.5 | 2.5e-4 / 0.223 / 38.0 | 5.8e-4 / 14.1 / 46.2 |
| T_gas at A_V 0.70 / 1.00 / 1.50 [K] | 50.6 / 46.0 / 33.3 | 51.9 / 46.8 / 33.8 | 48.0 / 49.3 / 43.5 |
| 1-0 S(1), 2-1 S(1) / Hbeta | 7.67, 4.06e-4 | 10.18, 5.42e-4 (x1.33) | - |
| 0-0 S(0), S(1), S(2) | | x1.14, 1.26, 1.16 | |
| [C II], [O I] 63, [C I], CO 1-0..3-2 | | within 1% | |
| Hbeta | 9.1657 | 9.1655 | |

**What it means.** The silicate surface energies are worth 0.04 mag of
hiipdr's 0.31 mag crossing gap, about an eighth. With Cloudy's set, the
lit-edge H2 still falls short of Cloudy's by 2.3x at A_V 0.70 and 63x at 1.0.
The deeper transition is therefore mostly not grain formation. The
destruction is what remains: the levels' photodissociation rate on MOCASSIN's
own field. That field is 2.5-4.6x the old prescription's through this
transition (D-350), and the levels' rate is 1.2-2.0x the network's on it
(H-019). Comparing the destruction rate per H2 molecule with Cloudy's,
depth by depth, is the measurement this points to. Cloudy's
`PHOTON,H2=>H,H` over its n(H2) is in
`runs/d356-cloudy-hii` and `runs/h021-cloudy-hii` (.H2de).

The H2 lines are sensitive to the parameter set (+14-33%): more H2 at the
lit edge means more pumping. That sensitivity is worth stating wherever our
H2 lines are compared with Cloudy's on silicate.

### The destruction side, measured

Photodissociation per H2 molecule, hiipdr, medians in +-5% A_V bins. Ours is
h2Cells.out of `runs/h019-B-hii31` (stage B, the levels') and of
`runs/h019-A-hii31` (stage A, the network's). Cloudy's is `PHOTON,H2=>H,H`
plus both `PHOTON,H2*=>` dissociation channels over n(H2), from
`runs/h021-cloudy-hii`. N(H2) is ours to the cell along the star-ward ray,
and Cloudy's from its face.

| A_V | ours (B) | Cloudy | B/Cloudy | A/Cloudy | diffuse share of our LW field | N(H2) ours | N(H2) Cloudy |
|---|---|---|---|---|---|---|---|
| 0.50 | 1.3e-8 | 1.5e-8 | 0.91 | 0.47 | 0.59 | 3.4e9 | 1.4e13 |
| 0.60 | 5.3e-9 | 4.6e-9 | 1.14 | 0.52 | 0.66 | 1.6e13 | 8.4e13 |
| 0.70 | 2.2e-9 | 5.4e-10 | 4.1 | 1.0 | 0.71 | 5.8e13 | 4.7e14 |
| 0.80 | 7.0e-10 | 8.8e-13 | 794 | 98 | 0.75 | 1.7e14 | 1.4e17 |
| 0.90 | 1.3e-10 | 7.9e-14 | 1656 | 207 | 0.77 | 3.9e14 | 3.3e18 |
| 1.00 | 4.8e-12 | 1.6e-14 | 296 | 73 | 0.80 | 2.0e15 | 2.0e19 |
| 1.20 | 7.3e-14 | 2.4e-15 | 30 | 29 | 0.85 | 8.2e17 | 1.2e20 |
| 1.50 | 2.0e-15 | 3.4e-16 | 5.8 | 9.9 | 0.90 | 6.2e19 | 3.6e20 |

Across A_V 0.70-0.80 Cloudy's rate falls 600x, as its H2 column passes
1e15-1e17 and shields itself, while ours falls 3x. At A_V 0.5-0.6 the two
agree to 10-15%, where neither is self-shielded. The divergence is a feedback
that starts at A_V 0.6-0.7: there our formation is 0.5-0.6 of Cloudy's (H-021)
and our destruction 1.1-4x, so n(H2) is 7x lower at 0.70 and the column that
shields grows that much more slowly. Formation alone moves the crossing
0.04 mag (above), so most of the shift is the destruction. In the
transition, 59-90% of our Lyman-Werner field is scattered light, and its part
of the rate is 2-5x the direct part. The scattered field is shielded by the
two-leg columns of its scattering sites (D-348), not by the star-ward column.

**The scattered field is not under-shielded; the column is low from the
start.** The scattered part of our rate is 3.1x the direct part at A_V 1.0
while it carries 4x the direct field (diffuse share 0.80). Its mean shielding
factor is therefore about 0.8 of the direct beam's, as two-leg columns in a
closed shell should give: an inward site's two legs sum to the star-ward
column, and a sideways or outward one's exceed it. What differs is the H2
column itself, ours to Cloudy's at the same A_V:

  - A_V 0.50: 3.4e9 against 1.4e13, 4000x lower, where the rates still agree;
  - A_V 0.60: 5x;
  - A_V 0.70: 8x;
  - A_V 0.80: 830x;
  - A_V 1.0: 1e4x.

Every later difference is that lag fed back through self-shielding.

**Next, and not done:** where the lag at A_V 0.5 comes from. Our star-ward
column (pdrColH2) up to the lit edge is 4000x below Cloudy's, although our
ionized-gas H2 is 3-18x Cloudy's per cm^3. Whether pdrColH2 counts the H2 of
the ionized cells at all is the first thing to check. Then the edge's H2 at
A_V 0.50-0.65 cell by cell, with its formation and destruction, against
Cloudy's zones.

### Status

Done (diagnostic). The destruction measurement points at the H2 column at the
lit edge, which our model builds far more slowly than Cloudy's (next).

## H-023 - D-395's seeded pairs: reaction 332 on the converged stage B runs (2026-10-05)

Production D-395 added reaction 332, e- + H2+ -> e- + H + H+ (Janev et al.
1987, 2e-7 exp(-30720/T)). It is the network's missing H2+ sink in ionized
gas, behind L-43's transition-zone H2 excess. The change was merged here per
D-388; the four flavours, h2Test and h2Slab build with rc 0, and it is
installed into this branch's PREFIX.

The pairs are this branch's converged stage B runs, rerun with the new
binary at the same input, seed (1001), 14 ranks and iteration count, with
`convTotals 1e-6` so the test does not stop them early:

  - hiipdr: `runs/h023-eh2p-hii31` against `runs/h019-B-hii31` (15);
  - pn150k: `runs/h023-eh2p-pn41` against `runs/h019-B-pn41` (18).

The tool is `scratchpad/h023_compare.py`. It bins cells by their own x(H+),
and Cloudy's H2 is H2 + H2*.

### hiipdr (40:55)

| x(H+) | cells | n(H2+) new/old | 2n(H2)/n_H new/old | ours/Cloudy, new |
|---|---|---|---|---|
| 0.99-1.00 | 107 | 0.51 | 0.97 | 25 |
| 0.95-0.99 | 19 | 0.36 | 0.51 | 56 |
| 0.80-0.95 | 4 | 0.37 | 0.46 | 14 |
| 0.50-0.80 | 12 | 0.47 | 0.49 | 62 |
| 0.20-0.50 | 20 | 0.64 | 0.65 | 43 |
| 0.05-0.20 | 19 | 0.93 | 0.95 | 4.8 |
| 0.01-0.05 | 12 | 0.89 | 1.06 | 0.9 |

  - front 3.8312 -> 3.8310 pc;
  - H/H2 crossing 1.4004 -> 1.3996;
  - Hbeta 9.16568 -> 9.16518;
  - H2 lines x0.998-0.999;
  - every PDR shell's x(H2) and T_e to 1.000.

The H2+ drop is the rate table's x2.1 at hiipdr's 8-9 kK. D-395's 4-10x
was predicted for pn150k's 1-2e4 K.

### pn150k (2:29:55)

Cloudy's H2+ is saved for this model (`runs/d389-cloudy-h2s`, .dens389).

| x(H+) | cells | n(H2+) new/old | n(H2+) ours/Cloudy, old -> new | 2n(H2)/n_H new/old | H2 ours/Cloudy, new |
|---|---|---|---|---|---|
| 0.99-1.00 | 167 | 0.14 | 530 -> 75 | 0.59 | 2500 |
| 0.95-0.99 | 122 | 0.19 | 22 -> 4.2 | 0.37 | 32 |
| 0.80-0.95 | 72 | 0.20 | 20 -> 3.9 | 0.24 | 75 |
| 0.50-0.80 | 50 | 0.26 | 15 -> 4.0 | 0.28 | 230 |
| 0.20-0.50 | 60 | 0.38 | 9.4 -> 3.6 | 0.41 | 190 |
| 0.05-0.20 | 68 | 0.64 | 5.1 -> 3.2 | 0.64 | 100 |
| 0.01-0.05 | 154 | 1.08 | 2.4 -> 2.6 | 0.92 | 0.1 |

  - front 0.12814 -> 0.12814 pc; He++ front 0.08773 -> 0.08769 pc;
  - H/H2 crossing 0.3930 -> 0.3933;
  - Hbeta unchanged to four figures;
  - H2 lines: 1-0 S(1) x0.998, 2-1 S(1) x0.999, 0-0 S(0), S(1), S(2) x1.002,
    1.001, 1.002;
  - PDR shells' x(H2) 0.97-1.006, T_e within 0.4%.

At fixed A_V, ours over Cloudy's H2 + H2* goes 24 -> 16 at A_V 0.05,
670 -> 205 at 0.10 and 74 -> 71 at 0.15 (H-021's table: 24, 665, 77).

### What it means for the plan (H-021)

  - The H2+ supply is now within 3-4x of Cloudy's, so step 1's first half
    (H2+ + H at the network's rate) has the right input.
  - The H2 that is left, 30-230x Cloudy's on pn150k, is the level-resolved
    part: formation into excited levels and their destruction by electrons.
    It is unchanged as the next step.
  - Its weight in the lines is unchanged too: the zone carries 1.1% of
    1-0 S(1) on pn150k, and the lines moved by 0.2% here.

### Status

Done.

## H-024 - hiipdr's lit edge, cell by cell: a column definition and the references (2026-10-05)

H-022 ended on "where the lag at A_V 0.5 comes from": our star-ward H2 column
4000x below Cloudy's at the lit edge, though our ionized-gas H2 is 3-18x
Cloudy's per cm^3. Its first question was whether the chemistry's column
counts the ionized cells at all. Tool: `scratchpad/h024_edge.py <run> <Cloudy
prefix>`, our cells binned in A_V (+-0.02 mag, medians) against Cloudy's zone
at that A_V.

### The column counts the ionized cells

`computeAVradial`'s star-ward march adds n(H2) ds over every active cell but
the target (D-350 removed the zone test); so does the level model's
`starColumns`. Not the cause.

### The lag was a definition

h2Cells.out's "N(H2) to cell" (column 17, 1-based) is the level column to the
cell's near face. The cell's own H2 is left out of it and enters the
shielding averaged through the cell. Our cells are 0.65 pc, about 0.08 mag of
A_V each. The cells H-022 binned at A_V 0.50 are the front cells themselves
(median x(H+) 0.015), so their column to the face is the ionized gas's,
3.4e9.

Cloudy's own ionized column is 4e8. Both codes build their H2 column only past
the front. Measured to the cell centre (to the face plus half the cell's
own):

  - A_V 0.50: 6.2e12 against Cloudy's 1.85e13 (3x);
  - A_V 0.55: 2.2e13 against Cloudy's 4.25e13 (1.9x).

**Two more corrections to H-022:**

  - Its Cloudy photodissociation per molecule divided every channel (H2 and
    H2*) by ground H2 alone. Per H2 + H2*, Cloudy's rates are lower by 1.33,
    1.23, 1.16, 1.08 and 1.01 at A_V 0.45, 0.50, 0.55, 0.60 and 0.70.
  - A trap found on the way: `save pdr` writes 2n(H2)/n_H and 2n(H2*)/n_H
    (`save_do.cpp`), not n/n_H. The first pass of this tool doubled Cloudy's
    H2 by taking it at face value.

### Against the old reference, ingredient by ingredient

At A_V 0.55-0.60, `runs/h021-cloudy-hii`:

  - 2n(H2)/n_H is 1.95-2.4x below Cloudy's;
  - grain formation per cm^3 is 0.49-0.55 (H-021: the silicate surface
    energies);
  - photodissociation per molecule is 0.97-1.28.

The product reproduces the abundance ratio. From A_V 0.65 the gap grows (7x
at 0.70, 98x at 0.75) as Cloudy's column passes 1e14-1e15 and shields
itself, and ours does not.

### The shielding each code uses

Shielding factor against N(H2), from the formulas. Cloudy's small model is
Elwert et al. (2005), checked against its saved ground-state rate below.

| N(H2) | Elwert, b 0.64 (Cloudy as run) | Elwert, b 1.19 | DB96, b 1.19 | 3D-PDR `H2SHIELD1`, 1 km/s |
|---|---|---|---|---|
| 1e14 | 0.50 | 0.67 | 0.74 | 0.61 |
| 1e15 | 0.043 | 0.10 | 0.15 | 0.053 |
| 4e15 | 0.0060 | 0.014 | 0.028 | 0.012 |
| 1e16 | 2.2e-3 | 4.2e-3 | 1.1e-2 | 5.3e-3 |
| 1e17 | 4.4e-4 | 6.5e-4 | 2.5e-3 | 1.8e-3 |
| 1e18 | 1.1e-4 | 1.6e-4 | 7.5e-4 | 7.4e-4 |

  - b = 0.64 km/s is H2's thermal width at 50 K. 1.19 is that with
    MOCASSIN's 1 km/s added, the level model's b.
  - H-005's slab puts the level model at 1.19, 1.57, 1.42 and 1.27 of DB96 at
    1e14-1e17, and Cloudy's large model at 2.23 and 0.35 of DB96 at 1e15 and
    1e17.
  - **Cloudy's saved rate follows Elwert's form:**
      - k_g / (a 4.6e-11 f_E G0) is 0.67 -> 0.22 over A_V 0.45-1.5, with G0 the
        TH85 field Cloudy saves times the face's DB96/TH85;
      - through the transition, A_V 0.50 -> 0.80, f_E falls 2460x and the rate
        11660x;
      - the slow drift is the DB96 band fading faster than the TH85 G0.

Two things in Cloudy's hiipdr reference, then:

  - no microturbulence, which is a factor 1.7-2.5 at 3e14-1e16;
  - the small model's fit, which shields 1.4-3.3x more than Cloudy's own
    line-by-line model at 1e15-1e17.

Both are corrected in production D-396 (merged): `turbulence 1 km/s no
pressure`, and `Database H2`.

### Against the corrected reference

`runs/d396-cloudy-hii` in production: its H/H2 crossing moves 1.090 -> 1.172
(turbulence) -> 1.280 (and the large model), against our 1.400. Ours over
Cloudy's at the lit edge, stage B:

| A_V | 0.55 | 0.60 | 0.65 | 0.70 | 0.75 | 0.80 | 0.85 | 0.90 | 1.00 |
|---|---|---|---|---|---|---|---|---|---|
| 2n(H2)/n_H | 0.65 | 0.72 | 0.97 | 0.98 | 1.18 | 1.34 | 1.92 | 2.64 | 0.54 |
| photodissociation per H2 | 0.77 | 0.74 | 0.60 | 0.63 | 0.55 | 0.51 | 0.37 | 0.26 | |

  - **Up to A_V 0.9, ours holds about as much H2 as Cloudy's or more.** Our
    formation is half (the surface energies), and our destruction is
    0.5-0.77x. Our FUV field is 0.8-0.86 of Cloudy's there (the next check),
    and our shielding is no stronger.
  - **Then Cloudy runs away.** Its H2 rises 70x from A_V 0.9 to 1.0, ours 14x.
    Cloudy's column is passing 1e15-1e17 there, where its damping is each
    line's own A (H-005, H-008: about 3x more shielding at N > 1e17 than the
    natural width). That is the candidate for the 0.12 mag left; it is not
    measured.

### The field is not the cause

Our chi (Draine) times 1.71 against Cloudy's saved G0 (Habing, TH85), cells
binned in A_V:

| A_V | 0.30 | 0.50 | 0.70 | 1.00 | 1.60 | 2.50 |
|---|---|---|---|---|---|---|
| ratio | 1.09 | 1.04 | 0.81 | 0.80 | 0.61 | 0.43 |

The two bands are not defined the same way, so the absolute ratio is not
exact. The trend is: our FUV falls faster with depth than Cloudy's. Less
field would put our transition shallower, not deeper.

### hiipdr's H2 lines, against Cloudy for the first time

**Corrected the same day.** This section first gave ours as 0.373 (ortho,
v = 1), 0.505 (para), 0.33 (rotational ortho) of Cloudy's. Those were against
`hiipdr.lines`, saved with `save lines ... emergent`. That file holds emergent
intensities under a header that says intrinsic: its Hbeta is 0.357 of the
intrinsic one, so an infrared H2 line over it is 2.2x its intrinsic ratio
(D-396, corrected). The same holds for pn150k's `150k.lines`, whose first
block `tools/h009_lines.py` has always read: it is the first iteration's,
with Hbeta 0.89 of the converged intrinsic and 1-0 S(1)/Hbeta 6% high.

Against the intrinsic list of the last iteration (`.linesint`, now saved by
both Cloudy inputs; 1-0 S(1)/Hbeta in it equals Cloudy's emissivity summed
over its sphere, 9.24e-4):

`tools/h009_lines.py runs/d396-cloudy-hii/hiipdr.linesint runs/h019-B-hii31
runs/h023-eh2p-hii31`, ours over Cloudy's large model, its 40 strongest
lines:

| upper level | lines | ours / Cloudy |
|---|---|---|
| v = 0, ortho | 4 | 0.84 |
| v = 0, para | 1 | 1.19 |
| v = 1, ortho | 6 | 0.83 |
| v = 1, para | 6 | 1.17 |
| v >= 2, ortho | 9 | 0.82 |
| v >= 2, para | 14 | 1.13 |

1-0 S(1) is 0.83 of Cloudy's, 2-1 S(1) 0.82, 0-0 S(0), S(1), S(2) 1.31,
0.86, 1.19. D-395 changes none by more than 0.2%.

The split by spin is the one pn150k shows, much smaller: there the para lines
are 1.95-2.72 and the ortho lines 0.96-1.17 of Cloudy's (stage B, against the
intrinsic list of D-396's reference; the published 0.83-0.98 and 1.74-2.77
were against the first block of the old one). H-008 and H-009 traced
pn150k's to three things: the damping width (ours, the natural width, gives
3.2x the para lines and 2.2x the ortho lines that Cloudy's own-A width
gives), Cloudy's closure (which raises every line by 1.2), and our colder
gas's ortho/para. It is not decomposed on hiipdr.

### Found, not fixed

The level model's `starColumns` steps a ray in cell widths and samples each
step at its middle. On a ray along a grid axis the samples fall on the cell
boundaries, so the nearest-point lookup can give a step to the wrong
neighbour. The ray to cell (1,1,9) counts cell 8 for 2e18 cm and cell 7 not at
all: 3.33e13 against 3.95e13 summed exactly, 16% on that ray. The
chemistry's own column is the separate march above.

### What it means

  - H-022's "every later difference is that lag fed back through
    self-shielding" is withdrawn.
  - Like for like, hiipdr's lit edge agrees with Cloudy's to 0.65-2.6x
    through A_V 0.9, with half the formation rate. What remains is Cloudy's
    later, sharper run-away, 0.12 mag on the crossing:
      - the silicate surface energies are 0.04 of it (H-022);
      - the damping width is the leading candidate for the rest.

### Not yet known

  - The damping width's share, measured. H-008's one-line patch on hiipdr
    would give it.
  - Whether `starColumns`' sampling moves anything that matters (an exact
    segment march is the fix).
  - hiipdr's H2 lines at 0.37-0.50, by cause.

### Status

Done.

## H-025 - The shielding columns, integrated: exact ray paths and the site's first leg (2026-10-05)

H-024 ended on a found-not-fixed: `starColumns` samples a ray once per step
of a cell width, and on a grid axis the samples fall on cell faces. Measured
over every cell (`tools/h025_columns.py`), the defect is general and
one-sided. It is in production's `computeAVradial` too, so the fix is
production's (D-397, D-398, merged here per D-388). This entry is the
measurement, the level model's side, and the checks.

### The measurement

The tool rebuilds the sampled march and the exact path length through each
cell on the same ray, both with the run's own n(H2). The rebuilt march
reproduces h2Cells.out's "N(H2) to cell" to 1% in every cell (15,191 on
`runs/h019-B-hii31`, 35,377 on `runs/h019-B-pn41`). The code's column over
the exact one:

| exact N(H2) [cm^-2] | hiipdr median | 5% of cells below | pn150k median | 5% below |
|---|---|---|---|---|
| 1e14-1e15 | 0.73 | 0.57 | 0.73 | 0.41 |
| 1e15-1e16 | 0.53 | 0.20 | 0.67 | 0.23 |
| 1e16-1e17 | 0.46 | 0.03 | 0.64 | 0.40 |
| 1e17-1e18 | 0.52 | 0.04 | 0.73 | 0.53 |
| 1e18-1e19 | 0.64 | 0.35 | 0.82 | 0.65 |
| 1e19-1e20 | 0.75 | 0.27 | 0.92 | 0.84 |
| 1e20-1e21 | 0.95 | 0.84 | 0.97 | 0.93 |

**Why.** The steps are placed from the target cell's centre, at 0.5, 1.5,
2.5 ... steps. The cell reaches 0.5-0.87 of a cell width from its centre
along a ray, so the first sample is inside the target, whose column is left
out. The path from the target's face to the end of that step is in the
neighbour and is counted for nothing. n(H2) rises 5-10x per cell through the
transition, so that neighbour is most of the column.

The production log had been showing it. Its scale check (`Nwalk/N`,
`AVwalk/AV`, D-348) compares two sampled marches of the same path with
different step phases. In `runs/h023-eh2p-hii31` `Nwalk/N` read 1.61, 0.88,
0.59 and 1.05 in the first four A_V bins, and `AVwalk/AV` 0.72 in the first.

### The change, on this branch

  - `starColumns` takes `rayCells` (the exact length of the ray in each
    cell), traced from the cell's centre to the star as `computeAVradial`
    traces it. Its own stepping and `nearestAxB` are gone.
  - The walk the level model reads from `traceDiffuseSites` is now the cells
    each ray crosses with the length in each (`wkLen`); it was steps of one
    length (`wkDs`).
  - D-398: a site's first leg adds the site's cell's own column from its
    near face to its centre (`difSrc(:,6)`), as production's does.

All flavours, h2Test and h2Slab rc 0.

### Checked

A 5-iteration run (`runs/h025-smoke-hii31`, D-397 only) and a debug build
that dumped three cells' rays (`runs/h025-raydump`; the dump code is not
committed):

  - **Star-ward columns**: h2Cells.out's column over the tool's exact
    integral is 1.000 in all 15,191 cells (min 1, max 1). The tool finds the
    crossings by sorting, the code face by face.
  - **A_V**: 0.159737 mag/pc times the exact path through active cells, in
    every cell, to 3e-8.
  - **The old A_V was not exact either.** It was off by -0.058 to +0.057 mag
    (median -0.028, rms 1.8%). The dust is uniform, but the inner cavity
    (Rin 0.97 pc, 1.5 cells) is not, and the sampled march misjudged its
    edge. A_V = 0.1594 (r - 1.148 pc) before, 0.1598 (r - 1.052 pc) now,
    and the scatter about that line falls from 0.044 to 0.028 mag (what is
    left is the cavity's staircase). Production predicted "A_V does not
    move"; that failed for this reason.
  - **Mirrored rays**: for cells (2,3,4), (1,1,5) and (10,7,3), all 36
    HEALPix rays against a brute-force walk in 2e14 cm steps with the
    coordinates folded at the lower faces. Every cell's length and the total
    path agree to 3e14 cm, the order of cells on all 36, and each segment's
    start to 1e14 cm. The on-axis cell (1,1,5) reflects on two axes.
  - The scale check now reads 1.0000 in every bin, as it must: both sides
    are the same routine.

### Cost

One site per cell crossed, not one per step: 531 sites per cell at the lit
edge where there were 356. The site walk's share of a sweep doubles (29 to
55 rank-seconds of about 1,500). The sweeps of these runs take 1.3x longer
than `runs/h023-eh2p-hii31`'s, but so does the solve step, whose code did not
change; the machine's speed varies by that much (H-019).

Over whole runs (the level model's calls summed; rank-seconds of the site
walk summed):

| run | calls | level model [s] | site walk [rank-s] | run time |
|---|---|---|---|---|
| hiipdr, D-395 (`h023-eh2p-hii31`) | 13 | 1,102 | 507 | 40:55 |
| hiipdr, + D-397 (`h025-rays-hii31`) | 13 | 1,258 | 802 | 49:12 |
| hiipdr, + D-398 (`h026-site-hii31`) | 13 | 1,207 | 832 | 44:38 |
| pn150k, D-395 (`h023-eh2p-pn41`) | 16 | 5,640 | 2,147 | 2:29:55 |
| pn150k, + D-397 + D-398 (`h026-site-pn41`) | 16 | 5,152 | 2,926 | 2:24:17 |

(Sums corrected at H-026: this table first had each call's time with its
fraction of a second dropped, 6-9 s low.)

The site walk costs 1.4-1.6x what it did: 4-5% of the level model's
rank-seconds where it was 3% (the overlap step is 45-48%). The pn150k runs
were made on different days and the later one is the faster.

### The models: measured (2026-10-09)

Seeded pairs at the converged counts, 14 ranks: hiipdr 15 iterations,
pn150k 18. The pn150k run finished on 2026-10-05 and was read on 2026-10-09.
Production's D-397 and D-398 hold the tables; what belongs to this branch:

**hiipdr** (D-397 alone, then D-398 added), against Cloudy's large model
with turbulence (H-024):

| | D-395 | + D-397 | + D-398 | Cloudy |
|---|---|---|---|---|
| H/H2 crossing, radius [pc] | 10.028 | 9.847 | 9.781 | 8.946 |
| H/H2 crossing, each run's A_V | 1.400 | 1.406 | 1.396 | 1.280 |
| 1-0 S(1) / Hbeta | 7.65e-4 | 7.20e-4 | 7.03e-4 | 9.24e-4 |
| 0-0 S(0), S(1), S(2) / Hbeta [1e-4] | 3.04, 4.18, 5.46 | 2.93, 4.02, 5.19 | 2.86, 3.94, 5.08 | 2.32, 4.84, 4.61 |
| 40 strongest lines, median ours / Cloudy: ortho v = 0, 1, >= 2 | 0.84, 0.83, 0.81 | 0.79, 0.78, 0.77 | 0.78, 0.76, 0.75 | |
| the same, para | 1.19, 1.17, 1.13 | 1.13, 1.11, 1.07 | 1.10, 1.09, 1.05 | |

**pn150k** (both together):

| | D-395 | + D-397 + D-398 | Cloudy |
|---|---|---|---|
| H/H2 crossing, radius [pc] | 0.3706 | 0.3637 | 0.3278 |
| H/H2 crossing, each run's A_V | 0.3933 | 0.3931 | 0.3675 |
| 1-0 S(1) / Hbeta | 9.87e-4 | 9.45e-4 | 8.47e-4 |
| 0-0 S(0), S(1), S(2) / Hbeta [1e-4] | 1.55, 5.74, 11.7 | 1.49, 5.56, 11.3 | 0.78, 4.81, 4.49 |
| 40 strongest lines, median ours / Cloudy: ortho v = 0, 1, >= 2 | 0.95, 1.16, 1.11 | 0.91, 1.11, 1.07 | |
| the same, para | 1.95, 2.73, 2.69 | 1.88, 2.62, 2.58 | |

  - **The transitions moved towards the star, by 0.25 pc (0.039 mag) on
    hiipdr and 0.007 pc (0.008 mag) on pn150k.** The A_V axes moved the other
    way (+0.03 and +0.007 mag: they were sampled too), so in A_V the
    crossings read as they did.
  - **Every H2 line falls: 6-8% on hiipdr, 3-4% on pn150k**, ortho and para
    alike. The atomic layer that feeds them is thinner.
  - **The ortho/para split against Cloudy does not move** (para over ortho
    1.38-1.41 on hiipdr before and 1.40-1.43 after; 2.0-2.4 on pn150k in
    both). The columns were not its cause. H-008's damping width stays the measured part of it
    on pn150k.
  - On hiipdr the ortho lines are now 0.75-0.78 of Cloudy's, further than
    they were (0.81-0.84); the para lines 1.05-1.10, nearer (1.13-1.19).
  - The level model's star-ward column equals the independent exact
    integral in all 35,377 cells of the pn150k run too.

### Not yet known

  - D-397's and D-398's separate shares on pn150k: one run carries both.
  - What holds the rest of the crossing gap, 0.12 mag on hiipdr and 0.026 on
    pn150k. The silicate surface energies are 0.04 of hiipdr's (H-022); the
    damping width's share there is not measured (H-008's patch on hiipdr
    would).
  - Whether hiipdr's ortho lines at 0.75-0.78 are the crossing (ours is
    still 0.84 pc further out) or the excitation.

### Pages (2026-10-09)

Published from this branch's runs (production D-398 has the links): hiipdr
Against Cloudy version 23, 150 kK PN Against Cloudy version 22, H2 Lines in
MOCASSIN version 8. The H2 page has a new first section, "Like for like",
with both fixtures' lines against Cloudy's intrinsic lists; its stage B and
stage A sections stay as measured at H-019 and say which reference and line
list they used.

### Status

Done.

## H-026 - The damping width in stage B: the crossing with Cloudy's width (2026-10-09)

The user: "Proceed" (to the step recommended after H-025: measure the damping
width's share of hiipdr's remaining 0.12 mag with H-008's patch).

### The test

H-008's one line, each line damped by its own A as Cloudy's H2 is, instead of
by the upper level's total decay rate. It is now kept as
`tools/patches/h008_cloudy_width.patch`; it is a diagnostic and is not in the
code. H-008 ran it in stage A, where the level model only read the finished
model, so it could move the lines and nothing else. Since stage B (H-012,
H-013) the levels' photodissociation rate and heating are the chemistry's, so
the same line now moves the transition.

`runs/h026-aul-hii31` (binary `mocassin.h026aul`: a79ceac plus the patch; the
source was restored and the branch's 3D binaries rebuilt, rc 0) against
`runs/h026-site-hii31`: same input, seed, 15 iterations, 14 ranks. It ran
37:25 (44:38); the level model's 13 calls took 886 s (1,207 s), the overlap
step 243 rank-seconds a sweep against 524, as narrower wings reach fewer
lines. Last integrated-test report 1.96% on Ne+ (2.02%).

### Where the gap is (the model's own width)

A_V at which 2n(H2)/n_H passes a value (ours: medians of cells in 0.02 mag
bins, interpolated; Cloudy: its zones, `runs/d396-cloudy-hii`):

| 2n(H2)/n_H | ours | ours, Cloudy's width | Cloudy | ours - Cloudy | Cloudy's width - Cloudy |
|---|---|---|---|---|---|
| 1e-4 | 0.909 | 0.900 | 0.942 | -0.033 | -0.042 |
| 1e-3 | 0.981 | 0.943 | 0.991 | -0.009 | -0.047 |
| 1e-2 | 1.072 | 0.997 | 1.020 | +0.052 | -0.023 |
| 0.1 | 1.221 | 1.044 | 1.090 | +0.131 | -0.046 |
| 0.5 | 1.397 | 1.187 | 1.280 | +0.117 | -0.093 |
| 0.9 | 1.652 | 1.450 | 1.653 | -0.001 | -0.204 |

With its own width the model turns H2 on where Cloudy does (0.01 mag at
1e-3) and is molecular where Cloudy is (0.9 at 1.65). The whole gap opens
between A_V 1.0 and 1.2, where Cloudy runs away and ours does not: there our
photodissociation rate per molecule is 5-7x Cloudy's at the same A_V.

### With Cloudy's width

| | the model's width | Cloudy's width | Cloudy |
|---|---|---|---|
| H/H2 crossing, radius [pc] | 9.781 | 8.515 | 8.946 |
| H/H2 crossing, A_V | 1.396 | 1.188 | 1.280 |
| ionization front [pc] | 3.8312 | 3.8310 | 3.7644 |
| C+ = C, radius [pc] | 15.251 | 15.251 | |
| Hbeta [1e36 erg/s] | 9.166 | 9.166 | 10.02 |
| 1-0 S(1) / Hbeta | 7.03e-4 | 5.23e-4 | 9.24e-4 |
| 2-1 S(1) / 1-0 S(1) | 0.530 | 0.532 | |
| 0-0 S(0), S(1), S(2) / Hbeta [1e-4] | 2.86, 3.94, 5.08 | 1.26, 2.31, 2.30 | 2.32, 4.84, 4.61 |
| [C II] 158 um / Hbeta | 0.1538 | 0.1504 | 0.1151 |
| CO 1-0, 2-1, 3-2 / Hbeta [1e-6] | 1.405, 2.115, 0.469 | 1.417, 2.136, 0.477 | |

The crossing moves 0.208 mag, 1.27 pc, two cells (a cell is 0.648 pc, 0.104
mag). It was 0.116 mag deeper than Cloudy's and is 0.092 mag shallower.

In each run's own A_V (medians of the cells within 0.025 mag; Cloudy's zone at
that A_V). The column is to the cell's near face:

| A_V | 2n(H2)/n_H over Cloudy's: model's width | Cloudy's width | rate per H2 over Cloudy's: model's width | Cloudy's width | N(H2) to the cell: model's width | Cloudy's width | Cloudy |
|---|---|---|---|---|---|---|---|
| 0.70 | 0.79 | 0.80 | 0.74 | 0.74 | 5.7e13 | 5.7e13 | 1.8e14 |
| 0.80 | 0.92 | 0.92 | 0.73 | 0.72 | 1.7e14 | 1.7e14 | 4.7e14 |
| 0.90 | 2.83 | 3.68 | 0.24 | 0.17 | 5.5e14 | 5.6e14 | 1.6e15 |
| 1.00 | 0.76 | 4.17 | 1.01 | 0.15 | 5.5e15 | 6.9e15 | 3.5e16 |
| 1.05 | 0.14 | 2.52 | 5.78 | 0.29 | 3.7e16 | 6.9e16 | 7.3e17 |
| 1.10 | 0.13 | 1.93 | 6.71 | 0.37 | 1.4e17 | 6.3e17 | 4.3e18 |
| 1.15 | 0.17 | 1.79 | 5.77 | 0.36 | 4.9e17 | 7.4e18 | 1.2e19 |
| 1.20 | 0.24 | 1.63 | 4.87 | 0.37 | 1.5e18 | 2.1e19 | 2.6e19 |
| 1.30 | 0.47 | 1.41 | 3.12 | 0.33 | 8.2e18 | 7.0e19 | 6.3e19 |
| 1.40 | 0.75 | 1.25 | 1.89 | 0.29 | 3.2e19 | 1.4e20 | 1.2e20 |
| 1.50 | 0.95 | 1.18 | 1.13 | 0.21 | 8.0e19 | 2.3e20 | 1.7e20 |
| 1.70 | 1.00 | 1.05 | 1.00 | 0.23 | 2.3e20 | 4.1e20 | 3.6e20 |
| 2.00 | 1.01 | 1.01 | 0.69 | 0.19 | 5.1e20 | 6.9e20 | 6.5e20 |

At fixed radius (shell medians), Cloudy's width over the model's:

| r [pc] | A_V | n(H2) | rate per H2 | T [K]: model's width | Cloudy's width | Cloudy |
|---|---|---|---|---|---|---|
| 5.8 | 0.77 | 1.007 | 0.997 | 50.5 | 50.5 | 45.6 |
| 6.5 | 0.89 | 1.09 | 0.92 | 49.0 | 49.0 | 45.0 |
| 7.1 | 0.98 | 2.00 | 0.45 | 46.9 | 46.9 | 43.8 |
| 7.8 | 1.08 | 16.1 | 0.051 | 43.8 | 44.9 | 42.5 |
| 8.4 | 1.18 | 8.29 | 0.067 | 40.9 | 43.7 | 42.2 |
| 9.1 | 1.29 | 3.34 | 0.103 | 38.2 | 42.4 | 41.9 |
| 9.7 | 1.39 | 1.82 | 0.144 | 36.4 | 39.9 | 41.1 |
| 10.4 | 1.50 | 1.27 | 0.186 | 34.2 | 36.1 | 39.5 |
| 11.0 | 1.59 | 1.11 | 0.219 | 31.9 | 32.7 | 37.2 |
| 12.3 | 1.80 | 1.03 | 0.230 | 26.5 | 26.6 | 31.5 |
| 14.0 | 2.07 | 1.005 | 0.265 | 21.1 | 21.1 | 25.2 |

Inside 6 pc nothing moves (the columns there are below 2e14 cm^-2, the
Doppler core).

The rate at equal column, to take the feedback out (ours: column to the
cell's centre, medians per half dex; Cloudy: its zone at that column; each at
its own A_V):

| log N(H2) | A_V: model's width | Cloudy's width | Cloudy | rate over Cloudy's: model's width | Cloudy's width |
|---|---|---|---|---|---|
| 14.0-14.5 | 0.75 | 0.75 | 0.70 | 0.44 | 0.44 |
| 15.0-15.5 | 0.89 | 0.89 | 0.91 | 0.49 | 0.60 |
| 16.0-16.5 | 0.95 | 0.93 | 0.99 | 1.09 | 1.14 |
| 16.5-17.0 | 0.99 | 0.95 | 1.01 | 2.11 | 2.06 |
| 17.0-17.5 | 1.04 | 0.99 | 1.02 | 2.48 | 2.09 |
| 17.5-18.0 | 1.10 | 1.00 | 1.04 | 2.08 | 1.65 |
| 18.0-18.5 | 1.15 | 1.03 | 1.07 | 1.45 | 0.86 |
| 18.5-19.0 | 1.22 | 1.08 | 1.11 | 1.11 | 0.59 |
| 19.0-19.5 | 1.31 | 1.15 | 1.17 | 0.83 | 0.52 |
| 19.5-20.0 | 1.43 | 1.25 | 1.28 | 0.60 | 0.49 |
| 20.0-20.5 | 1.64 | 1.45 | 1.48 | 0.36 | 0.33 |
| 20.5-21.0 | 2.07 | 1.96 | 1.91 | 0.26 | 0.16 |

Over Cloudy's 40 strongest H2 lines (`tools/h009_lines.py`, its intrinsic
list), median of ours over Cloudy's:

| upper level | lines | the model's width | Cloudy's width | Cloudy's width / the model's |
|---|---|---|---|---|
| v = 0, ortho | 4 | 0.78 | 0.46 | 0.60 |
| v = 0, para | 1 | 1.10 | 0.50 | 0.45 |
| v = 1, ortho | 6 | 0.76 | 0.57 | 0.75 |
| v = 1, para | 6 | 1.09 | 0.54 | 0.50 |
| v >= 2, ortho | 9 | 0.75 | 0.56 | 0.75 |
| v >= 2, para | 14 | 1.05 | 0.52 | 0.50 |

The levels' H2 heating summed over the grid falls to 0.65 (formation 0.68,
dissociation 0.60): fewer atoms are cycled.

### What it means

  1. **The 0.12 mag was not 'the surface energies and, for the rest, the
     width'** (H-024, H-025, and the hiipdr page's version 23). The width
     alone is 0.21 mag, 1.8x the gap, and with Cloudy's width ours forms its
     H2 0.09 mag *before* Cloudy's. The gap is the difference of two larger
     things: +0.21 from the width and -0.09 from everything else. With
     Cloudy's surface energies as well (0.04 mag the same way, H-022, not run
     together) it would be about -0.13.
  2. **The 'everything else' has the sign H-008 found on pn150k**: with equal
     widths ours absorbs less in the lines than Cloudy does. Here the rate
     per molecule at equal column is 0.49-0.59 of Cloudy's from 3e18 to 1e20
     cm^-2 and 0.16-0.33 beyond, and every H2 line is 0.46-0.57 of Cloudy's
     (pn150k, stage A: 0.23-0.62).
  3. **The two codes' shielding differs in shape, not only in the wings.**
     At 3e16-1e18 cm^-2 ours is 1.6-2.5x Cloudy's rate with either width;
     below 3e15 it is 0.44-0.60 with either. The width acts from about 1e18
     on: at equal column our rate with the model's width is 1.2-1.9x that
     with Cloudy's, behind 0.1-0.2 mag more dust, so the width's own factor
     is larger than that. The 16x in n(H2) at 7.8 pc is that factor fed back
     through the column.
  4. **On hiipdr the split by spin is the width, all of it.** Para over ortho
     against Cloudy goes from 1.40-1.43 to 0.93-1.08. The width multiplies
     our para lines by 2.0-2.2 and our vibrational ortho lines by 1.34 (the
     rotational ones by 1.67); on pn150k, in stage A, 3.2 and 2.2 (H-009).
     H-025's "whether hiipdr's ortho lines at 0.75-0.78 are the crossing or
     the excitation" is answered: neither, it is the width acting less on
     them than on the para lines.
  5. **Part of 'our PDR is colder than Cloudy's' at 8-10 pc is the hydrogen
     being atomic.** With Cloudy's width the gas at 7.8-10.4 pc is 1.0-4.2 K
     warmer, and at 7.8-9.7 pc within 2.3 K of Cloudy's (it was up to 4.6 K
     colder), on 13% less heating (at 9.1 pc: photoelectric 2.56e-26 ->
     2.41e-26 erg/s per H, the chemistry's terms 4.66e-27 -> 2.09e-27).
     MOCASSIN's collisional line cooling balances that at the higher
     temperature, which is what the coolants' colliders going from H to half
     as many H2 would do; the coolants were not separated. Beyond 11 pc,
     where both runs are molecular, the 4-5 K stays.
  6. **Nothing changes in the code.** The natural width of a line is its
     upper level's total decay rate; Cloudy uses that for every species but
     its H2 (H-008). The difference is reported with its size: 0.21 mag on
     hiipdr's crossing, 1.3-2.2x on its lines.

### Not yet known

  - pn150k: `runs/h026-aul-pn41` against `runs/h026-site-pn41` (18
    iterations), launched 2026-10-09 23:48. (Measured 2026-10-10: the
    pn150k section below.)
  - What makes up the -0.09 mag and the half-strength lines at equal width.
    Candidates, none isolated here: line overlap, which ours has (Draine &
    Bertoldi's factor is 0.9 at 1e19, 0.7 at 1e20, 0.3 at 1e21, the trend of
    the equal-column table); our FUV falling faster with depth (0.80 of
    Cloudy's at A_V 1.0, 0.61 at 1.6, H-024); Cloudy's closure (1.2 on the
    lines, H-009); the cell: 0.1 mag wide where n(H2) rises 16x in one.
  - Why ours is 2x Cloudy's rate at 3e16-1e18 cm^-2 with either width. That
    is where a cell's own column is most of the column (H-007).
  - The transition is two cells from Cloudy's with one width and one cell
    with the other: the resolution series (H-007: the profile was not
    converged at 41^3) has not been repeated in stage B.

### Pages (2026-10-10)

hiipdr Against Cloudy, version 24 (https://claude.ai/artifact/PBCP2hf3SzMMn5t6PYLDtx):
a new first section, "With Cloudy's H2 line width, the transition moves past
Cloudy's", with the pair's transition, rate, line emissivities and the 40
lines by spin as figures, and the tables above. Version 23's "the second is
not yet measured on this model" and its "0.12 mag deeper" bullet now say
what was measured. The page's own numbers are unchanged: its run is the
model's. The pn150k and H2 pages wait for the pn150k run.

### pn150k (2026-10-10)

`runs/h026-aul-pn41` (the same binary, `mocassin.h026aul`) against
`runs/h026-site-pn41`: same input, seed 1001, 18 iterations, 14 ranks, rc 0.
It ran 2:42:12; the baseline's 2:24:17 was five days earlier, so the two
times do not compare (the machine's speed is not steady). The level model's
16 calls took 5,311 s (5,152 s); in the last sweep the overlap step took
1,507 rank-seconds against 1,834, every other part 6-34% more. Last
integrated-test report 1.51% on He2+ (1.49%).

| | the model's width | Cloudy's width | Cloudy |
|---|---|---|---|
| H/H2 crossing, radius [pc] | 0.3636 | 0.2745 | 0.3278 |
| H/H2 crossing, A_V | 0.393 | 0.294 | 0.368 |
| H+ front, He2+ front [pc] | 0.1282, 0.0877 | 0.1281, 0.0877 | 0.1279, 0.0880 |
| Hbeta [1e34 erg/s] | 2.678 | 2.678 | 2.779 |
| 1-0 S(1) / Hbeta | 9.45e-4 | 5.86e-4 | 8.47e-4 |
| 2-1 S(1) / 1-0 S(1) | 0.503 | 0.507 | 0.506 |
| 0-0 S(0), S(1), S(2) / Hbeta [1e-4] | 1.49, 5.56, 11.31 | 0.57, 2.62, 3.70 | 0.78, 4.80, 4.48 |
| n(H2) at A_V 0.20 / 0.30 / 0.50 [cm^-3] | 0.019 / 45 / 413 | 0.019 / 275 / 468 | 0.014 / 110 / 395 |
| T_gas at A_V 0.20 / 0.30 / 0.50 / 0.65 [K] | 168 / 46.7 / 30.5 / 24.7 | 165 / 49.4 / 31.0 / 24.8 | 172 / 60.8 / 45.4 / 36.1 |
| n(CO) at A_V 0.30 / 0.65 [cm^-3] | 1.1e-7 / 6.4e-6 | 7.3e-7 / 8.2e-6 | 1.9e-6 / 1.8e-6 |
| [C II] 158, [O I] 63 um / Hbeta | 0.1974, 0.2603 | 0.1913, 0.2595 | 0.3373, 0.1754 |
| [C I] 609, 370 um / Hbeta [1e-4] | 1.60, 1.86 | 1.55, 1.79 | 2.55, 4.23 |
| CO 2-1 / Hbeta [1e-7] | 1.87 | 2.66 | 2.79 |
| He II 4686, [O III] 5007 / Hbeta | 0.3454, 13.91 | 0.3455, 13.92 | 0.2793, 13.18 |

The crossing moves 0.099 mag, 0.089 pc, 5.9 cells (a cell is 0.0152 pc,
0.0168 mag). It was 0.026 mag deeper than Cloudy's and is 0.073 mag
shallower. A_V at which 2n(H2)/n_H passes a value (cells in 0.01 mag bins):

| 2n(H2)/n_H | ours | ours, Cloudy's width | Cloudy | ours - Cloudy | Cloudy's width - Cloudy |
|---|---|---|---|---|---|
| 1e-4 | 0.211 | 0.211 | 0.217 | -0.006 | -0.006 |
| 1e-3 | 0.230 | 0.227 | 0.230 | 0.000 | -0.003 |
| 1e-2 | 0.251 | 0.238 | 0.239 | +0.012 | -0.001 |
| 0.1 | 0.305 | 0.251 | 0.268 | +0.036 | -0.017 |
| 0.5 | 0.393 | 0.294 | 0.368 | +0.025 | -0.074 |
| 0.9 | 0.574 | 0.434 | 0.661 | -0.087 | -0.227 |

With Cloudy's width ours follows Cloudy's rise to within 0.006 mag up to
2n(H2)/n_H = 0.01 and then turns molecular faster than Cloudy does.

In each run's own A_V (cells within 0.01 mag; Cloudy's zone at that A_V; the
column is to the cell's near face):

| A_V | 2n(H2)/n_H over Cloudy's: model's width | Cloudy's width | rate per H2 over Cloudy's: model's width | Cloudy's width | N(H2) to the cell: model's width | Cloudy's width | Cloudy |
|---|---|---|---|---|---|---|---|
| 0.18 | 0.92 | 0.89 | 0.99 | 1.00 | 3.5e13 | 3.7e13 | 1.7e14 |
| 0.22 | 1.97 | 2.23 | 0.48 | 0.43 | 1.4e15 | 1.4e15 | 2.4e15 |
| 0.26 | 0.25 | 2.91 | 6.06 | 0.41 | 1.3e17 | 8.0e17 | 1.2e18 |
| 0.30 | 0.40 | 2.47 | 5.07 | 0.40 | 1.9e18 | 1.7e19 | 8.9e18 |
| 0.34 | 0.60 | 1.85 | 3.90 | 0.41 | 8.6e18 | 5.1e19 | 2.6e19 |
| 0.38 | 0.81 | 1.54 | 2.88 | 0.40 | 2.5e19 | 9.4e19 | 5.1e19 |
| 0.42 | 0.93 | 1.35 | 2.43 | 0.40 | 5.2e19 | 1.4e20 | 8.5e19 |
| 0.46 | 1.01 | 1.25 | 2.01 | 0.39 | 8.8e19 | 1.9e20 | 1.2e20 |
| 0.50 | 1.04 | 1.18 | 1.77 | 0.37 | 1.3e20 | 2.4e20 | 1.6e20 |
| 0.58 | 1.05 | 1.10 | 1.58 | 0.38 | 2.3e20 | 3.5e20 | 2.6e20 |
| 0.66 | 1.04 | 1.07 | 1.48 | 0.35 | 3.2e20 | 4.5e20 | 3.5e20 |

At fixed radius (shell medians), Cloudy's width over the model's:

| r [pc] | A_V | n(H2) | rate per H2 | T [K]: model's width | Cloudy's width | Cloudy |
|---|---|---|---|---|---|---|
| 0.19 | 0.200 | 1.00 | 0.98 | 174.0 | 167.7 | 133.8 |
| 0.21 | 0.222 | 1.17 | 0.83 | 94.0 | 92.2 | 97.6 |
| 0.23 | 0.245 | 8.27 | 0.105 | 64.7 | 65.7 | 78.0 |
| 0.25 | 0.265 | 10.98 | 0.066 | 53.7 | 55.2 | 67.3 |
| 0.27 | 0.288 | 7.69 | 0.072 | 48.6 | 50.9 | 60.4 |
| 0.29 | 0.311 | 5.05 | 0.085 | 45.2 | 48.0 | 56.4 |
| 0.31 | 0.332 | 3.50 | 0.100 | 42.5 | 45.7 | 54.5 |
| 0.33 | 0.354 | 2.52 | 0.118 | 40.3 | 43.3 | 52.8 |
| 0.35 | 0.377 | 1.95 | 0.136 | 38.4 | 41.0 | 51.4 |
| 0.37 | 0.399 | 1.62 | 0.153 | 36.8 | 38.9 | 50.3 |
| 0.40 | 0.432 | 1.36 | 0.175 | 34.6 | 36.1 | 48.3 |
| 0.45 | 0.487 | 1.16 | 0.202 | 31.3 | 32.0 | 44.9 |
| 0.55 | 0.598 | 1.05 | 0.240 | 26.0 | 26.2 | 37.6 |

The rate at equal column (as for hiipdr above; Cloudy's is its
photodissociation of H2 and H2* over their sum):

| log N(H2) | A_V: model's width | Cloudy's width | Cloudy | rate over Cloudy's: model's width | Cloudy's width |
|---|---|---|---|---|---|
| 14.0-14.5 | 0.185 | 0.185 | 0.180 | 0.85 | 0.84 |
| 15.0-15.5 | 0.214 | 0.213 | 0.216 | 0.77 | 0.80 |
| 16.0-16.5 | 0.233 | 0.230 | 0.234 | 1.77 | 1.63 |
| 16.5-17.0 | 0.244 | 0.235 | 0.239 | 1.84 | 1.39 |
| 17.0-17.5 | 0.255 | 0.240 | 0.244 | 1.98 | 1.16 |
| 17.5-18.0 | 0.272 | 0.247 | 0.252 | 2.08 | 0.83 |
| 18.0-18.5 | 0.294 | 0.257 | 0.265 | 1.95 | 0.68 |
| 18.5-19.0 | 0.323 | 0.273 | 0.287 | 1.71 | 0.69 |
| 19.0-19.5 | 0.364 | 0.298 | 0.326 | 1.55 | 0.80 |
| 19.5-20.0 | 0.430 | 0.350 | 0.390 | 1.34 | 0.80 |
| 20.0-20.5 | 0.569 | 0.480 | 0.513 | 0.94 | 0.56 |

(The last half dex, 20.5-21.0, holds 2,365 of the model's cells against
14,402 of the other run's and is left out.)

Over Cloudy's 40 strongest H2 lines, median of ours over Cloudy's:

| upper level | lines | the model's width | Cloudy's width | Cloudy's width / the model's |
|---|---|---|---|---|
| v = 0, ortho | 5 | 0.91 | 0.45 | 0.50 |
| v = 0, para | 3 | 1.88 | 0.70 | 0.37 |
| v = 1, ortho | 7 | 1.11 | 0.69 | 0.62 |
| v = 1, para | 6 | 2.62 | 0.93 | 0.36 |
| v >= 2, ortho | 10 | 1.07 | 0.69 | 0.64 |
| v >= 2, para | 9 | 2.58 | 0.90 | 0.35 |

Line by line, with Cloudy's width the 22 ortho lines are 0.43-0.73 of
Cloudy's and the 18 para lines 0.67-0.95. The levels' H2 heating summed over
the grid falls to 0.49 (formation 0.53, dissociation 0.47, the collisional
term 0.24).

### pn150k's 'everything else': Cloudy's chlorine

At equal width the rate per molecule at equal A_V is 0.35-0.41 of Cloudy's
photodissociation rate from A_V 0.26 to 0.66. But photodissociation is not
all that destroys Cloudy's H2 there. From its saved destruction rates
(`.H2de`, `.H2sde` of `runs/d396-cloudy-pn`; net sinks of H2 + H2* only,
`tools/h026_cloudy_sinks.py`):

| A_V | Cloudy's sink per H2 [s^-1] | photodissociation | Cl+ + H2 -> HCl+ + H | HCl+ + H2 -> H2Cl+ + H |
|---|---|---|---|---|
| 0.20 | 1.65e-9 | 1.00 | 0.00 | 0.00 |
| 0.23 | 4.71e-11 | 0.99 | 0.01 | 0.00 |
| 0.26 | 5.23e-13 | 0.64 | 0.23 | 0.02 |
| 0.30 | 1.39e-13 | 0.54 | 0.27 | 0.08 |
| 0.34 | 5.70e-14 | 0.51 | 0.27 | 0.14 |
| 0.38 | 3.13e-14 | 0.48 | 0.28 | 0.17 |
| 0.46 | 1.32e-14 | 0.40 | 0.29 | 0.20 |
| 0.58 | 5.48e-15 | 0.27 | 0.29 | 0.21 |
| 0.66 | 3.69e-15 | 0.20 | 0.27 | 0.19 |

The two chlorine reactions are 25-50% of Cloudy's H2 sink from A_V 0.26 on
(H-009 had noted them beyond 0.21 pc and left them out of its closure
patch). The REDUCED network has no chlorine (its 33 species are H, He, C, O
and Mg bearing). hiipdr's Cloudy model has chlorine off, as MOCASSIN's
hiipdr has no chlorine, and photodissociation is 97-100% of its sink at A_V
0.9-1.3: this is pn150k's only.

To size it, Cloudy was run without chlorine: `runs/h026-cloudy-pn-noCl`,
the reference's input with `element chlorine off` and its three chlorine
output lines removed (593 zones, 2 iterations, 212 s). The two
models side by side: `tools/h026_cloudy_pair.py`. A diagnostic on the
reference; the page's Cloudy model is unchanged.

| Cloudy | the reference | without chlorine |
|---|---|---|
| H/H2 crossing, A_V | 0.3675 | 0.3259 |
| H/H2 crossing, radius [pc] | 0.3278 | 0.2908 |
| A_V where 2n(H2)/n_H = 1e-3 / 1e-2 / 0.1 / 0.9 | 0.230 / 0.239 / 0.268 / 0.661 | 0.230 / 0.238 / 0.258 / 0.518 |
| n(H2) at A_V 0.26 / 0.30 / 0.38 / 0.50 [cm^-3] | 36.6 / 110 / 271 / 395 | 55.5 / 176 / 347 / 446 |
| sink per H2 at A_V 0.30 / 0.38 / 0.50 [s^-1] | 1.39e-13 / 3.13e-14 / 9.5e-15 | 7.3e-14 / 1.67e-14 / 4.4e-15 |
| photodissociation's share at A_V 0.30 / 0.38 / 0.50 | 0.54 / 0.48 / 0.35 | 0.82 / 0.84 / 0.69 |
| T_gas at A_V 0.30 / 0.38 / 0.50 [K] | 60.8 / 52.2 / 45.4 | 61.7 / 55.2 / 47.6 |
| 1-0 S(1) / Hbeta | 8.47e-4 | 9.35e-4 |
| 0-0 S(0), S(1), S(2) / Hbeta [1e-4] | 0.78, 4.80, 4.48 | 1.11, 4.31, 4.35 |
| Hbeta [1e34 erg/s] (its zones summed) | 2.776 | 2.776 |

Cloudy's crossing moves 0.042 mag toward the star without chlorine, more
than the 0.026 mag the pages carry.

### What it means, with both models

  7. **On pn150k too the gap is a difference of larger things.** The width
     alone is 0.099 mag, 3.9x the published 0.026, and with Cloudy's width
     ours forms its H2 0.073 mag before Cloudy's. Against Cloudy without
     chlorine it is 0.031 mag before. So, if the pieces add, +0.026 =
     +0.099 (the width) - 0.042 (Cloudy's chlorine, which our network does
     not have) - 0.031 (the rest). The pieces were measured in different
     codes and one at a time; that they add is an assumption. hiipdr, with
     no chlorine in either model: +0.116 = +0.208 - 0.092.
  8. **The agreement of the two crossings to 0.026 mag on pn150k was a
     cancellation**, as H-008 found for its lines: a line width that
     shields ours less, against a sink Cloudy has and ours lacks plus the
     same residual as on hiipdr.
  9. **The chlorine is a gap in our chemistry, not a convention.** Cl+ +
     H2 -> HCl+ + H is fast and exothermic, and chlorine (I.P. 12.97 eV)
     stays ionized through the atomic gas: in Cloudy's model it is 99% Cl+
     at A_V 0.20, 38% at 0.26, 12% at 0.30 and 1-3% at 0.38-0.46 (its
     `.ele_Cl`), so behind the transition the Cl+ that reacts is what
     photoionization of Cl resupplies. On this model it carries a
     quarter to a half of Cloudy's H2 destruction where photodissociation
     is shielded. Our network cannot represent it without new species (Cl,
     Cl+, HCl, HCl+, H2Cl+), and the network is generated code selected at
     compile time. Not done here; it is a decision for the user. Adding it
     would move our crossing *away* from Cloudy's (deeper), by something
     like the 0.04 mag it moves Cloudy's; that number is Cloudy's, not
     ours.
  10. **The split by spin is mostly the width on pn150k, not all of it.**
     Para over ortho against Cloudy goes from 2.1-2.4 to 1.3-1.6 (hiipdr:
     1.40-1.43 to 0.93-1.08). The width multiplies our para lines by
     2.7-2.9 and our ortho lines by 1.6-2.0 (stage A, H-009: 3.2 and 2.2).
     What is left on pn150k is what H-009 found: the ortho/para ratio of
     shielded gas that is 11-14 K colder than Cloudy's. With equal widths
     the vibrational para lines are 0.90-0.93 of Cloudy's and the ortho
     lines 0.69.
  11. **The shape of the shielding repeats.** At equal column ours is
     1.2-2.0x Cloudy's rate at 1e16-3e17 cm^-2 with either width (hiipdr
     1.1-2.5x at 1e16-1e18), and with Cloudy's width 0.68-0.83 of it from
     3e17 to 1e20 (hiipdr 0.49-0.86 from 1e18). The residual has one sign
     on both models and is smaller on pn150k.
  12. **On pn150k little of the colder PDR is the atomic hydrogen.** With
     Cloudy's width the gas at 0.25-0.40 pc is 1.5-3.2 K warmer and still
     8-12 K below Cloudy's (it was 11-14 K below). On hiipdr the same test
     closed the gap at 7.8-9.7 pc to 2.3 K. Cloudy without chlorine is
     itself 1-3 K warmer at A_V 0.30-0.50.
  13. **CO follows.** With Cloudy's width n(CO) at A_V 0.30 rises 6.7x and
     CO 2-1 by 42%, to 0.95 of Cloudy's (0.67); [C II] 158 falls 3.1%, [C I]
     3.0-3.6%, [O I] 63 0.3%. The ionized nebula does not move (0.03%).
  14. **The model keeps its width**, as point 6. The difference is 0.10 mag
     on pn150k's crossing and 1.6-2.9x on its lines.

### Not yet known (after pn150k)

  - The residual at equal width, with one sign on both models: -0.09 mag
    and half-strength lines on hiipdr, -0.03 mag (against Cloudy without
    chlorine) and lines at 0.45-0.93 on pn150k. The candidates of the list
    above stand, none isolated.
  - What chlorine would do in our own network. Its size here is Cloudy's:
    0.042 mag on its crossing, +10% on its 1-0 S(1), +43% on 0-0 S(0), -10%
    on 0-0 S(1). Cloudy without chlorine was not rerun as the reference for
    the line comparison, so the per-line medians above are against the
    model with chlorine.
  - Whether the pieces add: the width in Cloudy (its own H2 with the
    natural width) is not something its input can set, so the cross term
    cannot be measured from that side.
  - Cloudy's other sinks. Without chlorine photodissociation is still only
    0.82-0.84 of its H2 sink at A_V 0.26-0.38 and 0.37-0.75 beyond (O+,
    cosmic rays, H2+); ours is 93-100% photodissociation out to 0.43 pc
    (H-009).

### Pages (2026-10-10, pn150k and the H2 lines)

  - 150 kK PN Against Cloudy, version 23
    (https://claude.ai/artifact/DofNhQwr6apCKo2BR8y1JV): a new first
    section, "The 0.026 mag agreement is a cancellation: a line width, and
    chlorine": the pair's transition, rate, line emissivities and 40 lines
    by spin, what destroys Cloudy's H2 (shares against A_V), the four
    transitions (two runs, two Cloudy models), and the tables above with
    Cloudy without chlorine as a fourth column. Version 22's "the para
    lines stay 1.9-2.6x Cloudy's through its line damping width" now
    carries the stage B measurement, and "H2 forms just past Cloudy's" the
    three pieces.
  - H2 Lines in MOCASSIN, version 9
    (https://claude.ai/artifact/B98zztmSp6yCK9NAy83PE8): a new first
    section, "The damping width where the level model is the physics", both
    models side by side. Version 8's "on hiipdr it is not decomposed" and
    its open item "hiipdr's lines by cause" are replaced by what was
    measured.
  - hiipdr Against Cloudy, version 24, republished: 1-0 S(1) with Cloudy's
    width is 5.23e-4 (the page had 5.24e-4, from a ratio that
    `tools/h009_lines.py` prints to three decimals; the lines now come from
    each run's `lineFluxH2.out`, as in the table above), and a paragraph on
    the companion model. The platform counts the republish as its version
    25; the page still says 24.

The page builders and numbers scripts are in the session's scratchpad
(`h026wpages/`: `numsw.py`, `figcl.py`, `build_hii24.py`, `build_pn23.py`,
`build_h2v9.py`), not in the repository, as for the earlier versions.

Point 7's residual was first written as 0.032 mag; it is 0.0315 and rounds
to 0.031, as the pages have it (corrected the same day; commit 568a98d's
message still says 0.032).

### Status

Done (2026-10-10). The patch is `tools/patches/h008_cloudy_width.patch`; the
code is unchanged. Open, for the user: whether the network gets chlorine.

## H-027 - Production's D-402 merged: what one x(X+) does to the H2 results (2026-10-10)

D-402 (`DEVLOG.md`) made the neutral/first-ion balance of H, He, C, O and Mg
the same one in MOCASSIN's `ionBalance` and in the chemistry solve. It is a
production fix, made there and merged here (0c0d5c7, 9542ac6, 3bc4983,
03d80d3, 82e7769, ff87858; one conflict, the allocations in
`iteration_mod.f90`, both sides kept). All four flavours, `h2Test` and
`h2Slab` built at 82e7769. The full runs were made on this branch, with the
level model in the loop, as seeded pairs with H-026's published runs
(`runs/h026-site-hii31`, 15 iterations; `runs/h026-site-pn41`, 18).

### Measured

| | baseline | D-402 | Cloudy |
|---|---|---|---|
| hiipdr H/H2 crossing, A_V | 1.3961 | 1.3962 | 1.2799 |
| hiipdr 1-0 S(1) / Hbeta | 7.032e-4 | 6.988e-4 (-0.6%) | 9.235e-4 |
| hiipdr 2-1 S(1) | 3.727e-4 | -0.6% | 4.934e-4 |
| hiipdr 0-0 S(0), S(1), S(2) | | -1.8, -0.8, +0.2% | |
| pn150k H/H2 crossing, A_V | 0.3931 | 0.3927 | 0.3675 |
| pn150k 1-0 S(1) / Hbeta | 9.449e-4 | 9.383e-4 (-0.7%) | 8.479e-4 |
| pn150k 2-1 S(1) | 4.751e-4 | -0.7% | 4.293e-4 |
| pn150k 0-0 S(0), S(1), S(2) | | -4.0, -2.4, -0.5% | |

hiipdr's figures are the run with `teFloor 2.725` (`runs/d402-c-hii31-cmb`);
with the default 10 K floor (`runs/d402-c-hii31`) the H2 lines differ by
0.05-0.17%. H2 itself is unchanged to 0.5% through hiipdr's PDR and to 1%
past pn150k's transition; the thresholds x(H2) = 1e-4 ... 0.9 on pn150k move
by at most 0.0009 pc (6% of a cell). The pumping medians against Cloudy's
are unchanged (pn150k v=0 ortho 0.912 -> 0.910, para 1.883 -> 1.882).

pn150k's two lowest rotational lines lose 2.4 and 4.0% because the
transition zone is 3-6% colder (4,805 -> 4,642 K at r 0.145-0.16 pc, 519 ->
485, 173 -> 167): more neutral helium at the front absorbs more of the hard
photons, and that is `ionBalance` now having He+ + H -> He + H+ at the
network's coefficient, 1.7-3.1 times Kingdon & Ferland's at 5,000-12,000 K
(D-402's own section; `doc/pdr-status.md` L-48 - which set should be the one
in hot gas is open).

Ionized-zone H2: unchanged on hiipdr; +7-8% at 0.03-0.06 pc on pn150k (15-17
-> 17-19 times Cloudy's, L-43), not attributed.

### The level model's cost

Untouched code. Per call 111.7 s against 92.8 on hiipdr (13 calls) and 412 s
against 322 on pn150k (16): the 2026-10-05 runs against this afternoon's,
x1.20 and x1.28. That ratio is the machine's (memory: timings vary 1.4x
between sessions) and was used in D-402 to show the rest of the run costs
nothing measurable more.

### What it changes for this branch's open items

  - Chlorine (H-026, D-400): the user's rule is one x(Cl+). An element added
    to the link table now gets that by construction.
  - hiipdr's outer shell (A_V 2.7-3.0) reaches the default 10 K floor and is
    flagged; flagged cells are left out of `lineFlux.out` and
    `lineFluxMol.out`. Whether the floor stays at 10 K is the user's
    decision (D-402, L-30).

### Pages (2026-10-10)

"H2 Lines in MOCASSIN" is version 10
(https://claude.ai/artifact/B98zztmSp6yCK9NAy83PE8): a new first section
with the tables above for both nebulae, the 40 lines by spin before and
after, and four figures; the summary's "Now" numbers are the new runs'
(pn150k ortho 0.91-1.11 and para 1.88-2.62 of Cloudy's, hiipdr 0.74-0.77
and 1.05-1.10; 1-0 S(1) 1.11 and 0.76). The sections after it are as they
were measured on H-026's runs and say so. The two comparison pages were
rebuilt on the same runs (D-402, "Pages"). Builders in the session's
scratchpad, `d402pages/build_h2v10.py`.

D-402 was corrected the same day: its line comparison had read only the
recombination lines. Nothing in this entry depended on it (the H2 lines
are read from `lineFluxH2.out`).

### Not yet known

  - Why pn150k's ionized-zone H2 is 7-8% higher.
  - What pn150k's 0-0 S(0) and S(1) would be with the charge-transfer
    fits made for ionized gas in both solvers (D-402, L-48): not run.

### Status

Done (2026-10-10). No code of this branch changed.


## H-028 - Production's D-403 merged: the charge-transfer data checked, and what H-027 got wrong (2026-10-11)

The user, on D-402's three open items: "Proceed with your recommendations".
D-403 (`DEVLOG.md`) is production's: for charge transfer with H both
solvers use, per reaction, the fit made for the gas at hand (helium's and
magnesium's Kingdon & Ferland inside its stated range and the network's
outside; oxygen's stay on the network's, which are Stancil et al. 1999, the
data Cloudy uses too); hydrogen's side of He+ + H is computed in
`ionBalance` with its own He+; `teFloor` defaults to 2.725 K. Merged here
as 6778adb, with one conflict in `pdr_mod.f90` before the solve - both
sides kept (the level model's H2 photodissociation rate, H-012, and
D-403's charge-transfer rows). All four flavours, `h2Test` and `h2Slab`
rc 0. Runs on this branch, seeded, the level model in the loop:
`runs/d403-hii31` (15 iterations, 52:44) and `runs/d403-pn41` (18, 3:00:41).

### Measured

| | before one balance (H-026) | one balance (H-027) | now | Cloudy |
|---|---|---|---|---|
| pn150k H/H2 crossing, A_V | 0.3931 | 0.3927 | 0.3927 | 0.3675 |
| pn150k 1-0 S(1) / Hbeta | 9.449e-4 | 9.383e-4 | 9.410e-4 | 8.473e-4 |
| pn150k 0-0 S(0) | 1.493e-4 | 1.434e-4 | 1.435e-4 | 7.76e-5 |
| pn150k 0-0 S(1) | 5.557e-4 | 5.424e-4 | 5.420e-4 | 4.804e-4 |
| pn150k 0-0 S(2) | 1.131e-3 | 1.126e-3 | 1.127e-3 | 4.481e-4 |
| hiipdr H/H2 crossing, A_V | 1.3961 | 1.3962 | 1.3959 | 1.2799 |
| hiipdr 1-0 S(1) / Hbeta | 7.032e-4 | 6.988e-4 | 6.993e-4 | 9.237e-4 |
| hiipdr 0-0 S(0), S(1), S(2) against H-027 | | | 0.0, +0.1, 0.0% | |

The medians by spin of Cloudy's 40 strongest lines are unchanged (pn150k
ortho 0.91-1.11, para 1.88-2.62; hiipdr 0.74-0.78, 1.05-1.10). H2 in
pn150k's partly ionized gas is 34-210 times Cloudy's at the same x(H+), as
at H-027. The level model's cost per call is unchanged (6,572 s for 16
calls against 6,598 the same day).

### What H-027 got wrong

H-027 said pn150k's 0-0 S(0) and S(1) lost 4.0 and 2.4% because the gas
behind the ionization front was 3-6% colder, and that this was "one
charge-transfer coefficient (He+ + H; D-402, L-48)" - the network's being
1.7-3.1 times Kingdon & Ferland's at 5,000-12,000 K. The first half
stands. The second does not: with the Kingdon & Ferland fit back above
6,000 K the two lines are where H-027 left them (-3.9, -2.5% from H-026)
and so is the temperature (4,805 -> 4,642 -> 4,614 K at 0.15 pc, 519 -> 485
-> 488 K at 0.17). That gas is below 6,000 K, where MOCASSIN's balance had
effectively no transfer before D-402 and both solvers now have the
network's: He+ there fell by a third at D-402 and stays, and the neutral
helium takes more of the hard photons that heat it. D-403 has the shell
table.

### Pages

"H2 Lines in MOCASSIN" is version 11
(https://claude.ai/artifact/B98zztmSp6yCK9NAy83PE8): a new first section
with the tables above for both nebulae at the three stages; the summary's
"Now" numbers are these runs'; H-027's section is marked as measured then,
with its "one coefficient" marked refuted in part. The two comparison
pages were rebuilt on the same runs (D-403, "Pages").

### Not yet known

  - What helium's coefficient should be between 1,000 and 6,000 K, where
    the network's is 2.4-3.4 times what Cloudy uses (D-403, L-48): it sets
    pn150k's 0-0 S(0) and S(1) by 3.9 and 2.5%.
  - Why pn150k's ionized-zone H2 is 7-8% higher than before the shared
    balance (H-027's item, unchanged).

### Status

Done (2026-10-11). No code of this branch changed.

