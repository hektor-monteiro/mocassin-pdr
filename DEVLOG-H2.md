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
