# MOCASSIN-PDR

MOCASSIN (3D Monte Carlo photoionization + dust radiative transfer, Fortran/MPI)
with 3D-PDR's photodissociation-region chemistry coupled into it. 3D-PDR is
vendored under `source/pdr/` (44 files) and driven through `source/pdr_mod.f90`.

## The rule that outranks the others

**Favour self-consistency, and favour the physics.** Every quantity the two
codes share should be computed once, by whichever code owns it, and read by the
other - not assumed, not duplicated, not prescribed.

  - **No hardcoded values** standing in for something the model already knows.
    If MOCASSIN has the grain size distribution, the extinction curve, the
    abundances or the dust-to-gas ratio, the chemistry must use *those*, not a
    diffuse-ISM constant vendored in from upstream. A constant that cannot
    track the model is a bug even when its value is reasonable.
  - **No artificial gates.** Zone tests, `if (element == 1 .or. ...)` skips,
    thresholds that decide which code owns a cell, switches that select
    ownership at run time - these have been the single largest source of defects
    in this project (D-161, D-165, D-169, D-182, D-185, D-192). Ownership is a
    design decision and belongs in the design, not in an input keyword.
  - **One reality per quantity.** There is one x(H+), one T_e, one A_V. If two
    arrays hold the same physical thing they will diverge, and the divergence
    will be found late and in the deep, quiet part of the model.
  - **Report divergence, do not tune it away.** 3D-PDR is a *reference*, not a
    benchmark to be reproduced. Where MOCASSIN's own dust or field gives a
    different answer, that difference is a result to be measured and explained.
    Never fit a coefficient to close a gap.
  - When a fix and a prettier number disagree, take the fix.

## Build

Four flavours. **All four must compile before any change is called done.**

    make PDR=1 PDRGEOM=3D mocassin     # ray-traced per-ray columns (the default test)
    make PDR=1 mocassin                # 1D slab columns
    make mocassin                      # no PDR at all
    make PDR=1 mocassinWarm            # must resume PDR state

`make clean` between flavours - the object tree is shared. SUNDIALS is expected
at `$(HOME)/software/sundials-7.8.0`, overridable with `SUNDIALS_DIR`.

`PDRGEOM=3D` sets `-DRAYTHEIA -DRAYTHEIA_MO`; anything else sets
`-DONEDIMENSIONAL`. The rest of the PDR flags are fixed in the Makefile:
`-DTHERMALBALANCE -DREDUCED -DH2FORM_CT02 -DCHEMSTEADY -DCHEMRETRY
-DFORCECONVERGENCE -DNGACCEL -DNGCYCLE -DNGRELAX -DILLINOIS -DREBRACKET
-DSOBOLEV`. Note `GRAINRECOMB` and `BALG` are **not** defined anywhere, so the
code inside those guards is dead.

The chemistry is the **REDUCED network, 33 species**, steady-state
(`CHEMSTEADY`). The ODE right-hand side is generated C selected at compile
time, so the `pdrNetwork` keyword can only validate - it cannot switch anything.

## Code changes are planned, then executed

Every code change is planned at extra-high effort and then implemented by the
`code-executor` subagent (`.claude/agents/code-executor.md`) at high effort.
That covers anything that changes what is built or computed: `source/`,
`source/pdr/`, the `Makefile` and `tools/`.

  - **The plan is made at `xhigh` effort**, by the main session in plan mode.
    The main session holds the discussion and the DEVLOG history. It runs at
    `xhigh` by the user's settings.
  - **A plan leaves nothing to design.** For every step it names:
    - the file and the routine;
    - the change itself;
    - how the step is verified (the builds, the test, and the prediction on
      record before any run).
    Every choice between alternatives is made in the plan.
  - **The `code-executor` implements it at `high` effort.** Its definition
    sets that effort. Hand it the plan file's path, the checkout and branch,
    and the commit attribution lines. It follows the plan exactly, does not
    redesign, and stops at anything that blocks the plan.
  - **A blocker goes back to planning.** The plan is revised at `xhigh` and
    the revised plan is executed. The executor does not patch around a
    blocker, and nor does the main session. Each blocker and how it was
    resolved go in the DEVLOG.
  - **The main session reviews the report.** It reads the diff and the
    verification output, checks the runs when they finish, and writes and
    commits the DEVLOG entry.

## Running

    mpirun -np 14 ./mocassin

**Always 14** unless there is a specific reason otherwise: that is the physical
core count, and more ranks multiply memory rather than sharing it. Measured for
dust+gas+PDR runs at nbins=600 (D-370): **~0.47 GB + 38 kB per active cell per
rank**. Within the ~31 GB the machine can safely give a run (systemd-oomd), that
is ~46k active cells at 14 ranks (about 44^3 for a `symmetricXYZ` octant
sphere, whose active cells are ~52% of the cube), ~104k at 7 and ~260k at 3.
hiipdr 31^3 (15k active) and pn150k 41^3 (35k) fit at 14; a larger grid means
fewer ranks.

MOCASSIN reads `input/input.in` relative to the working directory and does
**not** create `output/` - make it first. Fixtures live under `benchmarks/pdr/`
(`hiipdr` is the Bisbas et al. 2015 §5.4 model; `v1slab`/`v2slab` are the 1D
slabs; `baseline3dpdr` holds the standalone reference output).

## Verification

  - A single run is the default evidence. MOCASSIN is Monte Carlo and two runs
    of the same fixture differ, so where a result is close to the run-to-run
    scatter, say so rather than repeating the run - extra runs are requested
    when they are worth the time, not taken as a matter of course.
  - Check when a run finishes rather than waiting to be asked.
  - Prefer conserved sums and budgets over single cells:
    `x(HI) + 2x(H2) + x(HII) = 1` at every depth is the sharpest test in the
    project and has caught real defects twice.
  - A convergence percentage is only as good as the quantity it measures. If
    the tested quantity cannot move, the test passes for free (D-176..D-181,
    and again at D-191).

## DEVLOG.md

**Every discussion and decision gets an entry**, so the implementation history
is detailed enough to not be re-derived. 185 entries, D-001 onward: a summary
row in the index table at the top, then a dated body section. Record what was
measured, what it means, and what is *not* yet known - including hypotheses
that turned out wrong, and which of them was discarded and why. Convert
relative dates to absolute.

Reverted work is tagged rather than deleted (e.g. `d193-d195-reverted`).

## Artifacts

Comparisons against 3D-PDR are published as Röllig et al. (2007)-style plots so
the profiles can be inspected rather than summarised.
