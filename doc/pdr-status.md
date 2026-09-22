# MOCASSIN-PDR: validation status and known limitations

What the PDR coupling has been shown to do, what it has *not*, and the size of
each known defect. Every number here is measured and traceable to a DEVLOG
entry; nothing is asserted from expectation.

Read alongside `doc/dust.md` (grain input and optics) and `DEVLOG.md` (the
full history, including the hypotheses that turned out wrong).

Status as of D-314, 2026-09-22. Reference model throughout: the 150 kK PN,
41^3, n_H = 1000, MRN graphite, against Cloudy c25.00 on a matched input.

---

## 1. What this is

MOCASSIN's 3D Monte Carlo photoionization and dust radiative transfer, with
3D-PDR's REDUCED 33-species steady-state chemistry solved in every active
cell. MOCASSIN owns the radiation field, the dust and A_V; the chemistry owns
the molecular abundances and the fine-structure coolants, which are
substituted into MOCASSIN's thermal balance in place of its own where it has
no data for the carrier.

Four build flavours, all required to compile before any change lands:
`PDR=1 PDRGEOM=3D` (ray-traced columns, the default), `PDR=1` (1D slab
columns), plain `mocassin` (no PDR), and `PDR=1 mocassinWarm` (resume).

---

## 2. What is validated

### Conservation and internal consistency

| test | result | where |
|---|---|---|
| x(HI) + 2x(H2) + x(HII) = 1 at every depth | holds | project-standing check |
| thermal balance residual (H-C)/H | 7e-4 to 7e-3 across the PDR | D-304 |
| budget recorded at the cell's kept T_e | 0.8% median, 4.1% p95 | D-304 |
| grain diagnostic closes: PE = Nabs/H x \<Y\> x \<E\> | **1.00** | D-304 |
| dust emission table vs independent 4∫C_abs B dν | **1.000** | D-309 |
| radiative-equilibrium solve reproduced independently | 0.9988, 0.9988 | D-309 |
| ion balance failures | **0%** (was 16-18%) | verified D-314 |
| convergence reached | **90.4%** | verified D-314 |

### Against Cloudy, on quantities both codes own

| quantity | agreement | where |
|---|---|---|
| N_H / A_V | **0.4%** (2.7515e21 vs 2.7401e21) | D-305 |
| dust mass per H | **0.7%** | D-305 |
| Mie cross sections vs Draine's tabulated Q | **0.1-1%** | D-305 |
| x(C+) through the PDR | **1.001-1.006** | D-304 |
| photoelectric efficiency, PE per H per G0 | **0.66-1.10**, no trend | D-304 |
| FUV field vs Lya-corrected Cloudy | **0.89-0.95** | D-303, D-304 |
| bolometric field, each over its own undimmed stellar flux | 1.16-1.36 | D-307 |

The A_V agreement matters more than it looks: every depth-matched comparison
in this project assumes that when the two codes agree on A_V they are at the
same physical column. That was unchecked until D-305. It holds.

### Physics verified inside MOCASSIN alone, with no reference

The deep PDR is a two-term thermostat - grain photoelectric heating against
subthermal [C II] 158 um - on both sides. Across the `MOCASSIN_LINES` on/off
pair, with one binary and one switch,

    exp(-91.2/T_on) / exp(-91.2/T_off)  =  H_on / H_off

holds to **pred/meas = 0.986-1.014** at A_V 0.30-0.65 (D-304). The gas
temperature is set by the heating, and the cooling side is not at fault.

### Regression

With `MOCASSIN_LINES=off`, the current binary reproduces the pre-change binary
(b83e0e0) within the same-binary Monte Carlo scatter on every measured
quantity, and A_V matches **exactly** (D-314). The only functional change in
the cycle is the default flip; the dust cross-section and opacity chain is
provably untouched.

---

## 3. Known limitations

Severity is the effect on a published number, not on aesthetics.

### High - affects results now

**L-1. Line transport was discarding energy, and every result predating
D-307 was computed that way.** Diffuse line photons were deleted rather than
allowed to escape, costing the PDR about 60% of its bolometric flux
(Fbol/Fbol_thin 0.384 against 1.215 at A_V 0.30, D-306). Transport is now on
by default. **Consequence: any artifact or conclusion built on a lines-off run
is on a non-energy-conserving model** - this includes the current
`150 kK PN Against Cloudy` page, built on `runs/d302-trim-off` (D-303).
Closes when the artifacts are rebuilt.

**L-2. The dust temperature was the mean of two temperatures, not a
temperature.** The two graphite crystal axes were listed as separate species,
each given its own equilibrium temperature, and the reported value was their
arithmetic mean: 44.79 K and 22.45 K where the real randomly-oriented grain
sits at 26.85 K (D-309). Worth 26-30% against Cloudy. Fixed in D-313 by
pre-averaging the axes into one species with `tools/mkqfile.py`.
**Measured and closed** (D-315, `runs/d313-qavg`, 11 iterations, 89.58%):
reported/Cloudy moves from 1.289/1.304/1.272/1.256 to
**0.906/0.902/0.873/0.869** at A_V 0.20/0.30/0.50/0.65. The residual now has
the *opposite* sign, 9-13% cool, and is a spectral-shape difference rather
than a magnitude one - see L-19.

**L-3. O-01: deep C+ drop past A_V ~2.1.** Not revisited in this cycle. The
reference model reaches only A_V 0.68, so it does not exercise the affected
region - which is itself a limitation of the validation, not evidence the
defect is gone.

**L-4. O-14: the 3D self-shielding tracer is not fit to be the only
geometry.** Unchanged.

**L-19. The two codes put their reprocessed energy in different places in
frequency.** MOCASSIN's bolometric field is 1.16-1.35x Cloudy's at every depth
(D-307, unchanged by the L-2 fix), yet its grains are 9-13% cooler. The band
shares explain the sign: at A_V 0.30 Cloudy carries 0.255 of its field in the
FUV against MOCASSIN's 0.107, while MOCASSIN carries more at 0.01-0.44 Ryd
(0.504 against 0.362). C_abs is orders of magnitude larger in the FUV, so
Cloudy's smaller field is concentrated where grains absorb. This is the same
diffuse-transport difference D-307 measured from the other side, and it is
what remains of O-02's dust half (D-315).

### Medium

**L-5. The gas phase is not depleted for what is locked in grains.** The model
carries C/H = 2.690e-4 in the gas *and* 2.92e-4 in graphite - about twice
solar carbon. Cloudy's reference does exactly the same ("Depletion/Grains-1:
-100.00%"), so no comparison is affected, but neither model is physical in
absolute abundance (D-305).

**L-6. The extinction curve is not a Milky Way curve.** Graphite-only MRN
gives R_V = 4.57 against 3.1 and A(1000A)/A_V = 3.32 against 2.6-2.8, with
N_H/A_V 47% above the ISM value. Deliberate, shared with the Cloudy reference,
and common-mode - but it is not interstellar dust (D-305).

**L-7. No PAH component**, though `PAHneu_30.cat` sits unused in `dustData/`.
PAHs dominate photoelectric heating in real PDRs. Cloudy's reference has PAHs
off too, so it is common-mode (D-305).

**L-8. Stochastic heating is off.** `lgQheat` defaults false. For 0.005 um
grains in a PDR the equilibrium assumption is wrong for the emitted spectrum.
D-306 showed it cannot explain the dust-temperature excess (which was L-2),
so this is a fidelity gap rather than a live error (D-305, D-306).

**L-9. Gas-grain collisional coupling omits H2**, which is 94% of this gas -
the loop runs over atomic elements and ionisation stages only. Measured 68x
weaker than Cloudy's dust cooling at A_V 0.65, so 4.9e-5 of the budget against
Cloudy's 1.3e-3: negligible at n_H = 1e3, decisive at high density (D-305).

**L-10. Bulk-graphite optics on the smallest size bin**, where Draine's own
table is PAH/band physics: 0.38-0.89x in the FUV and 10-32x in the far-IR.
That bin is 26% of grains by number but only 3.2% of the FUV absorption, so
the FUV impact is small and the far-IR impact is not (D-305).

**L-11. O-09: the V1/V2 slabs have not been re-run** since D-260/D-263/D-266,
and not at all since this cycle's changes. Deferred deliberately.

**L-12. `thermBudget.out`'s cooling columns are bookkeeping, not channels.**
`coll` still carries the [C II]/[O I] it is about to hand to the chemistry,
and `PDR` is the net of added-minus-removed. The total is correct and nothing
is double counted, but the columns cannot be read as physical channels
(D-304). `pdrCoolSub`/`pdrTfacUsed` hold the two halves in memory but are
written to no file.

**L-13. The reference comparison rests on one run of each code.** D-314
measured MOCASSIN's run-to-run scatter for the first time: on a 5^3 fixture
the same binary swings median T_gas by **37%**. Aggregate KPIs on the
production grid are far tighter, but no published comparison carries an error
bar (O-25).

### Low, or housekeeping

**L-14. The warm start is BROKEN** (D-316, upgraded from "not exercised").
Running it for the first time found three defects. Two are fixed: it never
called `setLineNuP`/`allocLineArrays`, so `linePDF` was unallocated - dormant
until D-307 made line transport the default, then an immediate stop; and
`resetGrid` was called twice, once through a scalar that aliased the array by
sequence association, re-reading every checkpoint file. The third is open: a
segfault in `updateCell` after the Monte Carlo transfer completes and the SED
is written. `seedPDR`, which `mocassin.f90` calls and the warm driver does
not, is *not* the fix and is now ruled out: its only work is a D-251
validation that every network element has a MOCASSIN abundance, plus the
seeding itself, which would overwrite `pdrAbun` and destroy the state a
resume exists to restore. It allocates nothing, so the warm path is right to
skip it and the missing piece is elsewhere.

**L-15.** `getQs` caps the Mie size parameter at 100, which for a 0.25 um
grain bites above 5.8 Ryd against a `nuMax` of 30. Affects EUV/X-ray dust
absorption only, and is undocumented in the input (D-305).

**L-16.** `dustDriver` allreduces into temporaries and copies back - 2 x
165 MB per rank at this grid that `MPI_IN_PLACE` would remove (D-305).

**L-17.** `absInt`/`scaInt` are cumulative and never reset. Long-standing.

**L-18.** The Q-file path was unusable before D-313 (double allocation, and no
photoelectric yield). Fixed, but it means **no historical result used it**,
and it has only the coverage D-313 gave it.

---

## 4. What has NOT been checked

Stated explicitly, because absence of a reported problem is not evidence.

  - **The 1D slab fixtures** (`v1slab`, `v2slab`) and `ifront`, at their
    configured sizes, under this cycle's changes. Note that until D-316 they
    *could not have been run at all*: every PDR fixture's `pdrDataDir` pointed
    at a directory left behind by a rename.
  - **`hiipdr`** (the Bisbas et al. 2015 §5.4 model) under this cycle's
    changes. The `hiipdr Against Cloudy` artifact predates the line-transport
    result entirely.
  - **The warm start**, beyond compiling (L-14).
  - **The 1D PDR flavour** (`PDR=1` without `PDRGEOM=3D`), beyond compiling.
  - **Any model reaching A_V > 0.7**, so L-3 is untested in this cycle.
  - **Cloudy's own charging exponent.** D-304's Lya correction transfers
    MOCASSIN's measured `d ln(PE)/d ln(G0) = 0.42` to Cloudy. A Cloudy run
    with its FUV field cut by the Lya fraction would measure Cloudy's own
    response and remove the assumption.

---

## 5. Reproducing the validation

    # four flavours must all build
    for f in "PDR=1 PDRGEOM=3D mocassin" "PDR=1 mocassin" mocassin "PDR=1 mocassinWarm"; do
        make clean && make $f || echo "FAIL $f"
    done

    # regression against a previous binary, with the noise floor measured
    tools/regress.sh <fixture> <new-binary> <baseline-binary> <outdir> [np]
    ~/miniforge3/envs/astro/bin/python tools/regress_cmp.py <A>/output <B>/output

    # dust optics against Draine's tables, and the extinction curve
    ~/miniforge3/envs/astro/bin/python tools/d305_dustaudit.py

    # the thermal budget, term by term, against Cloudy
    ~/miniforge3/envs/astro/bin/python tools/d304_budget.py \
        <run> <cloudy-prefix> <lines-off-run> <ioncont>

    # dust temperature size by size
    ~/miniforge3/envs/astro/bin/python tools/d305_tdust.py <run> <cloudy-prefix>
