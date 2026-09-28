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
