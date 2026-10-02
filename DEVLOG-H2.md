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
T100_n4_G2 and T1000_n6_G4.

### Status

Done. The four MOCASSIN flavours build on the branch (h2_mod is still
outside them) and so does h2Test. H-003's comparison is unchanged by the
refactoring.
