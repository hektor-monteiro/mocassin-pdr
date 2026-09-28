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
