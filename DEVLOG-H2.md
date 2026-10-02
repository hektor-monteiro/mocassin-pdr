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
| H-007 | **Stage A, step 5: the level model inside MOCASSIN, on the finished model (`pdr_mod` `h2LevelModel`, called on every rank before the final output; 3D build).** Per cell: MOCASSIN's Te and the chemistry's densities; the MC field in the bin of each pumping line, split as pdrStep splits it (direct part behind the star-ward level columns, diffuse part on traceDiffuseSites' scattering sites behind their two-leg level columns); line shielding and overlap averaged through the cell's own column; photon escape over the twelve line rays; formation on silicate and carbonaceous surfaces in the proportion of the chemistry's own rate on each. Other cells' populations are the previous sweep's; sweeps repeat until four lines move by under 1%. Output: lineFluxH2.out, h2Cells.out (with the chemistry's own H2 photodissociation rate beside the levels'), h2Pop.bin. **First full run (hiipdr 21^3, 4,661 cells): 4 sweeps, 286 s on 14 ranks; 1-0 S(1) = 6.2e33 erg/s = 7.2e-4 Hbeta, 2-1 S(1)/1-0 S(1) = 0.53; the levels' Solomon rate is 2.6x the chemistry's in the ionized gas, 1.5-1.8x in unshielded cold gas, 0.4-0.7x in shielded gas.** The in-code field conversion agrees with an offline one from pdrFUVspec.out to 3-8%. The result is sensitive to how the cell's own column is treated (4.6x in 1-0 S(1) between leaving it out of the diffuse part and averaging through it): the pumping layer is inside one or two cells. pn150k 41^3 and hiipdr 31^3, 41^3 are running | In progress | 2026-10-02 |

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
    (D-384), with their depth profiles from the rerun.
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
Not measured on pn150k.

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

### Resolution

A hiipdr cell at 21^3 is 1 pc; its own H2 column where the molecule turns
on is 1e14-1e18 cm^-2, the whole range over which the pumping lines go
from thin to damped. The level model's answer there depends on how the
cell's own column is treated, by the 4.6x above. The shielding average
through a cell is exact for a uniform cell; these cells are not uniform.
The 21^3 / 31^3 / 41^3 series below measures how much this matters.

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

  - pn150k against Cloudy's four H2 lines; the resolution series. Running.
  - Formation by routes other than grains (H2+ + H, H-) is not
    distributed over levels; cells with no grain formation would take a
    Boltzmann distribution (none in this model).
  - H2 inside the ionized gas (T ~ 9,000 K): the collision tables are
    held at their ends, and electrons are not colliders yet.
  - Dust extinction of the H2 lines on their way out is not applied.
  - Plane-parallel models, multiple grids, the 1D build.
  - Cost on a 35k-cell model (estimated ~10 min a sweep at 14 ranks).

### Status

In progress: the code is in and builds; pn150k 41^3 and hiipdr 31^3 and
41^3 are running.
