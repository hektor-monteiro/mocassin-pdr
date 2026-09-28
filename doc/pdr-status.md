# MOCASSIN-PDR: validation status and known limitations

What the PDR coupling has been shown to do, what it has *not*, and the size of
each known defect. Every number here is measured and traceable to a DEVLOG
entry; nothing is asserted from expectation.

Read alongside `doc/dust.md` (grain input and optics) and `DEVLOG.md` (the
full history, including the hypotheses that turned out wrong).

Status as of D-377, 2026-09-28. Reference model throughout: the 150 kK PN,
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
| x(HI) + 2x(H2) + x(HII) = 1 at every depth | holds **by construction** since `rescaleIonToAvail` (D-220); the test that can fail is the pre-rescale `[D220]` lag - see L-29 | D-351 |
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
pair (a switch retired at D-352; tag `d352-zone-and-switches` rebuilds it),
with one binary and one switch,

    exp(-91.2/T_on) / exp(-91.2/T_off)  =  H_on / H_off

holds to **pred/meas = 0.986-1.014** at A_V 0.30-0.65 (D-304). The gas
temperature is set by the heating, and the cooling side is not at fault.

### Regression

(D-314, before the switch was retired at D-352.) With `MOCASSIN_LINES=off`,
the binary of that cycle reproduced the pre-change binary
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
is on a non-energy-conserving model.**
**CLOSED 2026-09-22.** Both affected artifacts are rebuilt on energy-conserving
runs: `150 kK PN Against Cloudy` on `runs/d313-qavg` (D-315, page v9) and
`hiipdr Against Cloudy` on `runs/d316-hiipdr` (D-320, page v10). The hiipdr
rebuild reversed that page's headline: its PDR gas was published as 21-26 K
against Cloudy's 29-50 and now runs 72/62/39/23/11 K at A_V 0.7/1.0/1.5/2.0/2.9
against 48/49/44/29/14 - warm behind the front, crossing near A_V 1.4, cold
beyond. Nothing else standing rests on a lines-off run; conclusions in DEVLOG
entries before D-307 still do, and are marked where they are quoted.

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

**L-3. O-01: deep C+ drop past A_V ~2.1 - now MEASURED, and it is real**
(D-333). The claim that stood here until 2026-09-23 - that the reference model
reaches only A_V 0.68 so the region is not exercised - was stale: it described
pn150k, while `runs/d326-stick` spans A_V 0.466-2.999 and the vendored 3D-PDR
reference `sec54.pdr.fin` reaches 2.453, both at n_H = 100. Against it,
x(C+) moc/ref runs **1.00/1.00/1.00/1.01/1.03/1.01** at A_V 0.6-2.1 and then
collapses to **0.38** at 2.33, where the reference still holds 82% of carbon as
C+; x(C) runs **0.16-0.23** shallow and **3.76** at 2.33; x(CO) **0.00/0.05/
0.39** at 0.6/0.9/1.25 rising to **3.2-3.4** beyond 2.1. Carbon conserves to
the total at every depth, so the transition is **placed too shallow and too
sharp** rather than losing mass. Consequence for the observables of D-331:
[C II] 158 um rests on a carrier good to 1-3%, [C I] on one 5x low, CO on one
wrong by two orders and changing sign with depth.

**Open hypothesis** (D-333, recorded before testing): this may also be the
cause of hiipdr's deep cold. [C I] 609 um has E/k = 23.6 K against [C II]'s
91.2 K, so at the 15-25 K reached beyond A_V 2 a premature C+ -> C conversion
switches on a coolant the gas can actually drive. `pdrCoolSp.out` holds the
split already; the test costs no run.

**L-4. O-14: the 3D self-shielding tracer has four named defects, two of them
active on both production fixtures** (D-259, re-read in D-339).

O-14 verbatim: *"No reflection at mirror walls, slab rays truncated at 59% of
depth, isotropic chi/12 weighting of a one-sided field, HEALPix rings about z."*

What MOCASSIN ran was `computeRayColumns` (D-190; removed in D-348 - the
paragraphs down to "Progress" describe it as it was) - twelve HEALPix nside=1
directions per cell per MC iteration, walked through the real grid. The vendored 3D-PDR tracer (`calc_columndens`/`raytheia`) is **dead in
this build**: its only caller is 3D-PDR's own `chemicaliterations.F90`.

Of the three per-ray arrays reaching `CALCULATE_REACTION_RATES`, **only the
shielding columns are directional**. `radSurf = chi/12` and `AVray = av` are
uniform by design (D-001/D-026), so 3D-PDR's ray sum collapses to MOCASSIN's
own `chi*exp(-gamma*A_V,eff)`. A per-ray A_V is computed (`colRayAV`, :1537)
and never used.

**Live defect.** The ray walk `exit`s at the grid boundary with no mirror
reflection (:1515-1521), and both production fixtures are `symmetricXYZ`
octants. Four of the twelve rays exit through the z=0 mirror and two more
through the x=0 and y=0 mirrors, so **roughly half the rays carry truncated
columns on every published run**. A truncated column under-shields, raising the
photodissociation rate and suppressing H2 and CO. Size unmeasured.

**Progress 2026-09-25.** Mirror reflection added (D-340). The per-ray columns
O-14's list implies were **never live** (D-341: grid_mod is not compiled with
`$(PDRFLAGS)`), and when D-341 made them live they ran on the **wrong rank for
93% of the cells** (D-348: `computeRayColumns` distributed by active index,
`pdrStep` by an index that counts inactive cells, and nothing reduced the
arrays), which then read zero columns on every ray. So D-342's collapse
(x(H2) x 0.002, no molecular zone) and its 0-1% for the mirror fold were
measured mostly on a defect. D-342's arithmetic - isotropic `chi/12` with
per-ray cell->boundary columns invents FUV from outside the nebula - stands.
The spectral branch is closed as measured-and-small (D-345).

**Implemented (D-348, specified in D-347).** `computeRayColumns` is removed.
Per cell, on the rank that consumes it, `traceDiffuseSites` walks twelve HEALPix
directions; every step is a scattering site weighted by the isotropic
formal-solution `S exp(-tau)(1 - exp(-dtau))` from MOCASSIN's own grains and
field, with a two-leg column `N(star->P) + N(P->C)`. Each site is its own ray to
the chemistry, carrying `chi_dif * w/sum(w)` at `A_V = 0`, so the vendored
shielding functions are evaluated per site. Slots 0-11 remain today's direct
ray byte for byte. `Jdif` is live in every PDR run. One departure from D-347:
the diffuse magnitude is distributed by formal-solution weight rather than
`f_dif/12` per direction, because the smoke test measures the field markedly
anisotropic (brightest direction 1.9-3.1x the mean).

**What the smoke test measured** (600k photons, first PDR iteration): the
tracer's scale agrees with `computeAVradial` to 0.2-2%; the chemistry's direct
plus diffuse field matches `chi_MC` to +0..+8% in the H2 band, where before the
reaction rates saw ~100x less than the heating at depth; and at fixed
abundances the H2 photodissociation rate rises x3.4 at A_V ~1 to x170 at
A_V ~2.8 - **almost all of it the diffuse field's magnitude** (D-053's "the
diffuse field is currently bypassed"), the two-leg columns taking back only
5-32%.

**Result** (`runs/d348-angular`, seed 1001): the H/H2 crossing moved **1.168 ->
1.635** (predicted deeper, into 1.8-2.6 - direction right, range wrong), the
molecular zone survives, CO fell 13-65x, C+ = C did not move (C+/C is
MOCASSIN's, D-162), front and dust unmoved, hydrogen budget intact. Against
Cloudy, H2 moves away (1.64 vs 1.09) and the deep CO excess largely closes.
**This result overshoots** - see L-24: the diffuse sites carry the band
integral, which overstates the Lyman-Werner drive at depth.

**Open under L-4.** The formal solution recovers only 52-130% of the MC's
`chi_dif`, falling with depth, unexplained (gas two-photon emission, phase
function, and twelve-direction quadrature are the candidates). The column
rescale between chemistry passes compounded (`col0*(a1/a0)*(a2/a0)`); deleted
at D-354 (L-25). The 1D flavour keeps the direct-only chemistry.

**L-24. The chemistry is handed the wrong band** (D-349). H2 and CO
dissociation and C I ionization see only 11.2-13.6 eV; every `chi` handed over
is the 6-13.6 eV integral, assumed Draine-shaped (window share 0.152). The MC's
window share falls from 0.299 at A_V 0.07 to 0.008 at 2.5, so the band integral
understates the window-driven rates 20-40% at the front and overstates them
1.7x / 3.9x / 20x at A_V 1.1 / 1.7 / 2.5. D-345's closing of the spectral branch
compared the wrong quantity and is corrected. It is also why the baseline
tracked Cloudy: MOCASSIN's window field over the old prescription is flat at
2.0-2.8 at every depth - the constant being the 40 kK star's window share,
x1.97 over Draine, so the baseline has run those rates ~2x low. **Implemented in D-350**
(3D flavour), in a stronger form than first proposed: every photorate now runs
on MOCASSIN's own local field at A_V = 0 - the direct part on the source-ward
column, the diffuse part on the D-348 sites - with H2, HD, CO and C I taking
each part's window field through a vendored per-ray hook (`ray_lw_factor`),
the C I continuum term dropped because the MC transports it, and the stale
zone test on the shielding columns removed. Result (`runs/d350-window`
against `runs/d350-base11`, 11 iterations, seed 1001): H/H2 crossing **1.184 ->
1.364**, C+ = C, front and dust unmoved, CO down 1.1-5x through the mid-PDR and
up 31% at the far edge, where MOCASSIN's window field drops below the old
prescription. The window field over the old prescription runs 2.5 / 3.6 / 4.6 /
0.8 at A_V 0.1 / 1.0 / 1.8 / 2.8 (correcting D-349's shell-averaged "flat
2.0-2.8"). Against Cloudy: crossing 1.36 vs 1.09; deep CO still 83-100x high.
The 1D flavour keeps the prescription.

**L-22. The gas-temperature crossover is the grain charge balance** (D-322,
corrected by D-324). hiipdr's PE heating crosses Cloudy's at A_V ~1.3, exactly
where the temperatures cross; cooling is exonerated at every depth by the
[C II] thermostat test, and the split is 72% conversion efficiency, 28% field.
The efficiency term is the photoelectric yield recovering as the grains
discharge with depth: it rises ~4.5x in Cloudy against a measured 1.94x in
MOCASSIN, because Cloudy's grains start more charged (2.711 V against 2.178)
and have more Coulomb suppression to give back.

D-322 originally read this as a spectral-shape difference inside the FUV band,
from `Nabs/H` falling 2.7x faster than `G0`. **That was wrong**: `grnAbs`
integrates from a threshold that moves with the grain potential, and it was
being compared against a fixed band. Threshold-matched against Cloudy's own
per-zone spectrum, the spectral residual is 1.26x, not 2.7x, and cannot carry
an efficiency swing of 4.2. The optics are also eliminated - the two codes'
grain cross sections agree in shape to 2% and in albedo to 1% across the band
(D-323).

**D-325 named it.** `update_mod.f90`'s `getGrainRecombination` hardcodes
`S = 1.` for electron sticking; Cloudy uses 0.5 (WD01). D-289 adopted WD01's
*yield* into both the charge balance and the heating but left Baldwin (1991)'s
sticking, so two halves of one prescription come from different papers in a
place where they multiply. At matched `psi = G0 sqrt(T)/x(e)` MOCASSIN's
efficiency is 2.09/1.73/1.36/1.04x Cloudy's - always above, never crossing -
and dividing psi by each code's own S flattens that to 1.15/1.16/1.13/1.31.
The crossover itself is the two codes on opposite sides of the peak of
efficiency-vs-psi, MOCASSIN's psi falling 113x across the PDR against Cloudy's
55x. **So the field drives it through psi**, and D-322's "28% field" reading
was causally wrong even though the arithmetic was right.

**Done (D-326, D-328):** electron sticking set to WD01's value. T_m/T_c at A_V
0.73 and 0.97 went from 1.488 and 1.267 to 1.069 and 1.014, closing the warm
half of the crossover. The profile did not rotate, so half of the prediction
failed (D-328).

This is *not* the same quantity as L-19 below. D-322 claimed it was; D-324
withdrew that. The dust result stands on its own measurement.

**L-19. The two codes put their reprocessed energy in different places in
frequency.** MOCASSIN's bolometric field is 1.16-1.35x Cloudy's at every depth
(D-307, unchanged by the L-2 fix), yet its grains are 9-13% cooler. The band
shares explain the sign: at A_V 0.30 Cloudy carries 0.255 of its field in the
FUV against MOCASSIN's 0.107, while MOCASSIN carries more at 0.01-0.44 Ryd
(0.504 against 0.362). C_abs is orders of magnitude larger in the FUV, so
Cloudy's smaller field is concentrated where grains absorb. This is the same
diffuse-transport difference D-307 measured from the other side, and it is
what remains of O-02's dust half (D-315). **Stale since D-352:** the grains had
also been losing 3D-PDR's PAH photoelectric term through the D-093 feedback,
5-150x the energy the gas received at A_V > 0.5. Removing it raised hiipdr's
PDR T_dust by 2-4% beyond A_V 1 and by 0.2-1.1% at A_V < 0.8. **Re-measured
on pn150k at D-353:** the PDR's grains are now 0.92-0.94 of Cloudy (6-8% cool,
was 9-13%), but in the fully ionized gas T_dust fell 7-8%, to 0.94 and 0.81 of
Cloudy at A_V 0.05 and 0.10 (was 1.01 and 0.88). The balance swapped two terms
at once there (3D-PDR's heat(2) and heat(11) for MOCASSIN's photoelHeat_d and
gasDustColl_d), and which of them supplies the fall is not decomposed.
**Re-measured at D-376**, with Lya destroyed by the local grains (L-42):
  - The ionized-zone deficit is gone. pn150k's T_dust is 1.01 and 0.98 of
    Cloudy at A_V 0.05 and 0.10 (was 0.94 and 0.81); hiipdr's 0.996 at 0.30
    (was 0.965). The grains had been missing Lya's heat, which Cloudy gives
    them.
  - The 0.01-0.44 Ryd excess was Lya carried at 8.15 um. At A_V 0.30 that
    share is now 0.346 against Cloudy's 0.362 (was 0.508).
  - The bolometric excess stays (1.09-1.30 of the thin flux against Cloudy's
    0.95-0.97), and it is now all below 0.01 Ryd: 0.560 against 0.383.
  - The FUV share is untouched (0.094 against 0.255).
  - The PDR's grains are 0.5-2% cooler than before, so 0.92-0.93 of Cloudy on
    pn150k.

**L-25. CLOSED 2026-09-26 (D-354). The chemistry passes oscillated on frozen
inputs** (D-351). Within an
MC iteration the five coupling passes re-solve the chemistry with Te, ionDen,
Ne, the field and the snapshot columns all fixed. Yet mean f_mol alternates
with period 2 and a growing swing: `d350-window` 0.8462 / 0.8546 / 0.8435 /
0.8596, extra heating +-3-5%; 0.003-0.006 in the pre-D-350 runs. The published
state is whatever pass 5 lands on. The only pass-to-pass channel found is
pdrStep rescaling every shielding column by the target cell's own abundance
ratio, compounding over `pdrChemIter` (`pdr_mod.f90:3236`). Since D-088 those
columns exclude the target cell, so the rescale is a leftover of D-078's
`NHcol*abun` form. *Hypothesis:* deleting it removes the alternation.

**Confirmed and closed (D-354).** With the rescale deleted, passes 2-5 moved no
cell's x(H2) or x(CO) by 0.1% in any iteration of hiipdr (largest move 4.6e-4),
and mean f_mol was identical to four digits across them. One pass with one
solve then reproduced five passes of three to 0.1% in T_gas, 0.4% in PE and
exactly in T_dust, at 20:48 against 50:42. The loops are collapsed and
`pdrCoupleIter`/`pdrChemIter` retired. The rescale was a positive feedback, the
self-term D-088 removed: without it hiipdr's H/H2 crossing moves from A_V 1.367
to 1.444 (Cloudy 1.09), and n(H2) at A_V 1.0 falls from 2.2 to 0.2 cm^-3.

**L-26. Since D-350 the deep chemistry is Monte Carlo noise-limited per cell**
(D-351). The photorates now read each cell's MC field, whose seed-to-seed
scatter (four-seed ensemble, 6e6 packets) is 2-4% at A_V ~1, 7% at 1.6-2.1,
14% at 2.1-2.6 and 22% (p90 38%) at 2.6-3.05. Twelve thousand of the 15,204
cells sit in the last three bins. J is rebuilt from zero every MC iteration,
so every iteration's chemistry takes a fresh draw. Measured consequence,
d350-window against d350-base11 (the D-220 lag, the iteration-to-iteration
x(H0) change, the fraction of cells whose f_mol moved >0.1):

    pre-rescale budget lag   0.020 (29% of cells >1%)   against 0.007 (9%)
    |dx(H0)|/x p90           0.34                        against 0.09
    f_mol moved >0.1          5.5%                        against 1.7%

The cell percentage (76.1% against 75.0%) did not show this. Since D-354 it is
printed directly: `[D354]` shows each iteration's chemistry moving x(H2) by more
than 1% in 39% of hiipdr's cells and x(CO) in 97-99% at iterations 9-11. Bin means over
thousands of cells survive. Per-cell values, which are what a 3D map shows, do
not. Non-linear photorates can also convert the noise into a bin-mean bias,
estimated at +5% at 22% scatter. Remedies are a design decision: accumulate
the FUV estimator over the iterations once the field has settled, reduce its
variance, or raise the packet count (roughly 20x for 5% at A_V 2.8).
**Measured at 21x the tracks per cell (D-365)**: hiipdr at 61^3 with 5e8
packets gives 0.8/1.5/2.8/4.8% iteration-to-iteration noise at A_V
1-1.5/1.5-2/2-2.5/2.5-3.5, the sqrt(N) law to within 10%. Deep C+ recovered
with it (C+ = C A_V 2.26 -> 2.72, Cloudy 2.95). The noise is now below the
fixed grid-direction pattern (L-39) at every depth, so more packets no longer
improve a per-cell map.

**L-27. Line escape in the 3D flavour is a slab with a third of its rays shut**
(D-061, D-063, D-190; registered D-351). `pdrStep` gives the four `mu = 0`
HEALPix rays `colA = 1e30` (`pdr_mod.f90:3664-3683`), so their beta is about
1e-30. The `RAYTHEIA_MO` branch of `escape_probability` divides by all twelve,
so beta is at most 2/3 even for a thin line. In the two-level limit, cooling
goes as `1/(1 + n/(beta n_crit))`. For [C II] (n_crit ~3e3 on H) that loses
~2% at n_H = 1e2, ~11% at 1e3, ~28% at 1e4 and ~33% at 1e5 *(estimate)*. The
rays toward the star also carry the cell's own populations over the whole
column. That overstates tau for CO, whose abundance rises with depth. Small
on hiipdr. Decisive for dense PDRs and for every line observable.
**Since D-363 it sets the cooling and the reported lines** (D-370): MOCASSIN's
own C I, C II and O I atoms take this beta per transition, so the loss above
is in the thermal balance and in `lineFlux.out` alike. Taking beta from 2/3 to
1 raises [C II] 158 by 2/12/38/50% at n_H 1e2/1e3/1e4/1e5; real PN PDRs sit at
1e4-1e5. The same routine pumps the lines with a vendored diffuse-ISM grain
emissivity (`NGRAIN = 2e-12 n_H`), a constant standing in for MOCASSIN's own
dust field; it reaches CO only. **Next after L-41** (D-370): per-ray columns
along the twelve D-348 directions, with each traversed cell's populations.
**CLOSED 2026-09-28 (D-377).** Each of the twelve rays is traced through the
grid (mirror folding included), and each point carries its own cell's level
populations. The background is MOCASSIN's own J_nu at the line plus the CMB.
Thin lines now escape with beta 1, and [C II] escapes the PDR 14-120% more
easily; from hiipdr's ionized gas, whose rays all cross the A_V 3 shell, it
escapes less (0.66 -> 0.50). The PDRs are 3-6% colder, because x/beta is not
small at beta 0.1-0.5. hiipdr's [C II] is x0.91 (1.17x Cloudy, was 1.29x);
pn150k's [C II] and [O I] move <1%, its [C I] 609 x1.40. Fronts, Hbeta, the
H/H2 crossing and the ionized-gas lines are unchanged.

**L-28. Two realities for the PDR lines** (D-351). In PDR cells
`lineFlux.out` reports [C II], [O I] and [C I] from MOCASSIN's electron-only
excitation. The gas is cooled by 3D-PDR's level populations with H, H2, He and
H+ as partners. The per-transition emissivities are computed in
`escape_probability` and discarded; `pdrCoolSp.out` carries each coolant's
total only. No PDR line observable exists yet (D-331).
**Measured (D-360)**, in Hbeta units, with the chemistry's cooling summed over
cells below 1000 K:

    hiipdr  [O I] 63+145  reported 0.0016   the gas's cooling 0.0059   Cloudy 0.0070
    pn150k  [O I] 63+145  reported 0.0063   the gas's cooling 0.068    Cloudy 0.20

(Corrected at D-362: that "cooling" summed only cells below 1000 K, at the
nearest table temperature, and left out the front cells that carry most of
[O I].)
**CLOSED 2026-09-26 (D-362).** `lineFlux.out`'s C I, C II and O I rows now
come from the chemistry's populations in every cell where it has the carrier,
the thermal balance's own condition. Rows from levels the chemistry's atoms
lack stay MOCASSIN's. CO lines are in `lineFluxMol.out`, and the per-cell
emissivities are checkpointed in `pdrLineEm.out`. In Hbeta units:

    [O I] 63+145   pn150k  0.0063 -> 0.280 (Cloudy 0.202)   hiipdr 0.0016 -> 0.059 (Cloudy 0.0062)
    [C II] 158     pn150k  0.163  -> 0.213 (Cloudy 0.311)   hiipdr 0.178  -> 0.194 (Cloudy 0.134)

What remains is registered as L-36, L-37 and L-38.

**L-29. The conserved sum is enforced, not tested** (D-351). The hydrogen
stages are normalised to the chemistry's `x(H) + x(H+)` before the budget is
printed and before `writeGrid`. So `x(HI) + 2x(H2) + x(HII) = 1` holds in the
log and in every output file up to H in other species, whatever the coupling
does. D-350's prediction 5 was therefore a free pass. The informative figure is
the pre-rescale `[D220]` line.

**L-30. Clamps that still decide a value** (D-352, which removed every run-time
ownership switch and the zone flag). None binds on hiipdr today, and each is
recorded so that it is not found late:
  - The chemistry's rates are evaluated at Te clamped to [pdrTmin, pdrTmax],
    its heating terms at the unclamped Te: two temperatures in one pdrStep
    wherever Te > 2e4 K (3 cells of pn150k).
  - `teFloor` holds MOCASSIN's T at 10 K or above. The coldest hiipdr cell is
    10.9 K.
  - The chemistry's T_dust is floored at T_CMB, because MOCASSIN transports no
    CMB. Where the floor binds, the chemistry and MOCASSIN's dust emission see
    different grain temperatures; the fix is the CMB in MOCASSIN's field.

**L-31. CLOSED 2026-09-26 (D-358). The chemistry solved H II gas as neutral**
(D-356). Inside the solve the linked ions recombined with no photoionization,
so an H II cell integrated to x(H) = 1, x(H+) = 1e-3, x_e = 1e-3 of MOCASSIN's.
The molecules were formed there, and MOCASSIN re-imposed only the atoms
afterwards: two x(H+) in one cell. Ionized-zone H2 was 1e4-1e5x Cloudy's and
CO up to 1e14x. The solve now runs on MOCASSIN's own photoionization and
recombination rates for H, He, C, O, Mg and MOCASSIN's H2 photoionization,
through the network's first-order slots. Ionized-zone H2 is now 5-71x Cloudy's
and destroyed the way Cloudy's is. Nothing past the fronts moved.

**L-32. One ion carrier per element** (D-358). The network has O+ for all of
O++-O6+ and C+ for C++-C4+. Each carrier takes chemistry its true stages do
not have: charge exchange into the neutral, and C+ + OH -> CO. In pn150k's
20 kK zone the solver's neutral O is 5.4 dex above MOCASSIN's, and CO, OH and
HCO+ run 3e7x, 630x and 1e12x Cloudy's at 0.03 pc, falling outward. Where the
carrier is the true stage (hiipdr) it does not show.

**L-33. Grain H2 formation 5-25x Cloudy's** per n_H n(H), at every depth
compared on both fixtures (D-356, D-358). MOCASSIN's coefficient is near the
classic 3e-17 cm^3 s^-1; Cloudy's is not. Not decomposed: sticking, grain
temperature, per-size efficiency.

**L-34. The PDR's H+ has channels MOCASSIN's ion balance lacks** (O-05; D-358).
These are H2 + CRP -> H+ + e + H and He+ + H2 -> He + H+ + H. The solver's
x(H+) is up to 4x MOCASSIN's at A_V 1.8-2.8 on hiipdr, and He+ 0.25-0.5x. The
re-imposition keeps MOCASSIN's. D-193 stopped injecting the chemistry's
source and sink terms into `ionBalance` because they double-counted the
molecular drain. Carrying these channels without that needs a decision of
its own.

**L-35. The H I line list is corrupt in every PDR run** (D-360). `hlinex`
(`output_mod.f90`) interpolates Storey & Hummer's `e1bx.dat` (T 300-30,000 K,
n_e 1e2-1e14) with 5-point polynomials in log(emissivity). It extrapolates
below both lower bounds. In PDR cells (11-27 K, n_e ~0.01) this gives H I
n = 16-25 lines at up to 1e22 x Hbeta in `lineFlux.out`, and it fills 97% of
hiipdr's log with overflow prints. It also clamps T > 30 kK by overwriting the
caller's `TeUsed`, which is latent on both fixtures. The code is legacy
(`38aca36`) and surfaced only when gas went below 300 K. Hbeta and every
non-H I line are unaffected.
**CLOSED 2026-09-26 (D-361).** `hlinex` now evaluates inside the table: the
low-density limit below 1e2 cm^-3, and the 300 K line ratio below 300 K. It no
longer writes to its arguments, and it reports once per run how many
evaluations sat at a table edge (`[D361]`). Regenerated from the D-358 grids,
every non-H I line and Hbeta are byte-identical, and the Balmer series matches
Case B to 1%. The contamination had also reached low-n lines on hiipdr:
Halpha/Hbeta went from 2.910 to 2.889 and H8 from 0.127 to 0.1045 Hbeta.
hiipdr's log shrinks from 90,561 lines to 187.

**L-36. The thermal balance's coolant table misses an exact solve by up to x3
per cell** (D-362). The balance reads each coolant from D-215's 16-point
table, log-log interpolated over brackets a factor 1.94 wide. `[D362]` compares
it with a level-population solve at the cell's T. For C+ the per-cell mean
|ln| is 0.20 (hiipdr) and 0.084 (pn150k), max 0.44. For O I it is 0.50 and
0.18, max 1.09. In sum the table is 11% high for C+ on hiipdr and 10% low on
pn150k, and within 3% for O, C and CO. The reported lines come from the exact
solve; the temperature comes from the table. For [C II]-cooled cold gas a
20% cooling error is ~4% in T *(estimate)*. The fix is a finer table or an
interpolation in 1/T. Why the C+ sign differs between the fixtures is not
known.
**Narrowed to CO (D-363).** C I, C II and O I are now MOCASSIN's own atoms,
evaluated at every trial T, with no table. For CO the per-cell mean |ln| is
0.02 (hiipdr) and 0.004 (pn150k). Removing the atoms' table made both PDRs
1-4% colder.

**L-37. Unresolved ionization-front cells dominate the [O I] lines**
(D-362). 92% (hiipdr) and 74% (pn150k) of [O I] 63 um comes from cells with
x(H+) 0.01-0.95 at 5,600-11,000 K. A 31^3 hiipdr cell is 0.65 pc, where
Cloudy's H+ transition is 0.031 pc and its [O I] 6300 layer 0.18 pc (D-379;
first written here as "~0.01 pc"), so each front cell carries 0.65 pc of warm
half-neutral gas. [O I] 63 is 9.3x Cloudy on hiipdr and 1.39x on pn150k.
MOCASSIN's own [O I] 6300 has always been 6.5x and 1.42x, so the same layer
drives both. The lines are the model's own state, and the balance cooled those
cells by them. The test is a finer grid; any front-sensitive line needs a
resolution check before it is published.
**Tested (D-365):** at 61^3 the front cells' [O I] 63 is 0.53x the 31^3
value for half the cell size, and [O I] 63 falls from 9.5x to 5.5x Cloudy
(6300: 6.8x to 4.7x). [C II] 158 has a front share too: a third at 31^3,
falling 0.60x, which takes [C II] from 1.35x to 1.19x Cloudy while its cold-PDR
part does not move. Neither grid resolves the front, so neither number is
converged. **pn150k is different (D-368):** at 81^3 its front cells' [O I] 63
is 0.95x the 41^3 value, so its 1.26x Cloudy (1.35x at 41^3) is a model
difference, not a grid effect. D-368 put this down to the hard 150 kK field
making a thicker zone. **D-379 measured otherwise:** Cloudy's 6300 layer holds
about the same H column on both fixtures, 5.5e19 cm^-2 (hiipdr) and 4.3e19
(pn150k). What separates them is the column per cell, 2.0e20 against 4.7e19,
i.e. 0.27 and 0.91 layers per cell. One layer per cell on hiipdr needs ~110^3.
A correction factor estimated from the transfer was evaluated and not adopted
(D-379): it needs a sub-cell solve of T and O0, and a factor on the reported
line alone would contradict the cooling that set the cell's T.
**Sub-cell profile, stage 1 (D-381), offline only:** H and He are integrated
through each cell from the transport's own field and opacity
(`frontField.out`, `tools/d381_subcell.py`) at the cell's T.
  - hiipdr [O I] 6300: 1.09-1.19x Cloudy at 21^3/31^3/41^3, max/min 1.18,
    against 5.6-9.9x (1.72) uncorrected.
  - pn150k [O I] 6300: 1.00x against 1.38x. D-368's "model difference" for
    6300 is withdrawn: one layer per cell is not resolved.
  - [O I] 63 is not fixed, because the cell's neutral part keeps the warm T;
    that needs a temperature per depth (stage 2).
Nothing enters the run yet. The reported lines and the cooling are unchanged.

**L-38. In ionized gas the chemistry's atoms replace CHIANTI's electron data**
(D-362). The substitution runs in every cell with the carrier, as the balance
does. In H II gas that swaps CHIANTI 10.1's electron-impact data for the
coolant files'. The C II] 2325 multiplet rises x1.22 (hiipdr) and x1.16
(pn150k), away from Cloudy on pn150k (0.94 against 0.62). The 2324 A
component rises x2.1: 4P3/2 A = 1.71/5.24 s^-1 in `12c+.dat` against 1.38/8.35
in CHIANTI. [C I] 9824/9850 falls to x0.66 (toward Cloudy), and [O I]
6300/6363/5577 moves <1%. The principled fix is one atom per ion: MOCASSIN's
CHIANTI levels and electron rates, plus the chemistry's H, H2, He and H+ rates
for the levels they cover, solved once for the balance and the lines. That is
a design decision.
**CLOSED 2026-09-27 (D-363)**, as that design: one atom per ion, with the
chemistry's escape probabilities carried over. C II] 2325 is back within
0.1-2.1% of the electron-only CHIANTI values. In neutral gas the chemistry's
atom and MOCASSIN's agree to 0.4-7% in the transitions they share. The escape
probabilities keep L-27's flaw (beta <= 2/3 for thin lines), which matters
only above the critical density.

**L-39. MOCASSIN's field beyond the front carries a fixed grid-direction
pattern** (D-365). At fixed radius in hiipdr the FUV field runs +29% along
the grid axes, -16% on the diagonals and +44% on the symmetry planes at A_V
2.5-3.5 (+7/-10/+12% at 0.5-1), the same at 31^3 and 61^3 and identical from
one iteration to the next (r = 0.95-1.00), so it is neither noise nor a
per-crossing error. T_dust carries it (+3.0/-1.7/+3.7%), the ionized gas does
not (<1%), CO inverts it (-19/+15/-41%). `randomUnitVector` and `hg` are
unbiased and path stretching is off. Untested candidates: the mirror treatment
at the symmetry planes, or the scattered field that dominates at depth. The
test is the fixture without `symmetricXYZ`. Radial means over shells average
it out; per-cell maps and single sight lines do not.
**CLOSED 2026-09-27 (D-366)**, on the user's hypothesis that the anisotropic
scattering was involved. The mirror reflections turned the step direction but
not the packet's stored one, and the next Henyey-Greenstein scattering starts
from the stored one, so after every bounce the packet was scattered back
toward the plane. Upstream since the initial import, at all four reflection
sites. Fixed: the pattern falls to +-0.02 (isotropic scattering, which cannot
see it, gives the same). The radial means were biased too: the deep field
rises 8/13/18% at A_V 1.5-2/2-2.5/2.5-3.5 with the fix. Every published
hiipdr number carries the defect; pn150k (g = 0.29, A_V < 0.8) about 2%.

**L-40. The H II region is not converged in 11 iterations** (D-365). hiipdr's
front is still moving inward 0.008 pc per iteration at iteration 11 on 61^3
(3.790 -> 3.699 pc over iterations 6-11) and ionized hydrogen falls ~0.7% per
iteration, with Hbeta. The 22-iteration 31^3 runs sit at 3.787 pc and Hbeta
8.63 E36 against 3.830 and 8.82 at 11. The converged-cell percentage does not
see it, because each front cell moves by less than `convLimit`. Every
published hiipdr number that depends on the front or on Hbeta carries this;
Hbeta is 13-18% below Cloudy's 9.95 E36 and not yet a converged number
*(most of that gap is L-41, not convergence - D-370)*.
pn150k at 81^3 (D-368) stopped itself at 94% converged cells with its He2+
front still moving outward 0.003 pc per iteration (0.0799 pc against 0.0833 at
41^3 and Cloudy's 0.0880), taking He II 4686 11% low. The per-cell test covers
x(H0), x(H2) and T_e but no helium stage (D-370; this line said "x(H0) only"
until then).

**L-41. The reported Hbeta is 5% low, so every line ratio is 5% high**
(D-370). `outputGas` reports Hbeta from 2530/T^0.833 (`output_mod.f90:2485`,
copied at `mocassinPlot.f90:784`) and takes every other H I line as a ratio
to it from Storey & Hummer's `e1bx.dat`, whose own Hbeta the same routine
computes and uses only as a denominator. The power law is 0.954/0.948/0.954/
0.965/0.977 of the table at 5/7.5/10/12.5/15 kK. The transport uses a third
form, S&H's fit 10^(-0.870 log T + 3.57) (`emission_mod.f90:556`), which is
0.996-1.005 of the table at 7.5-15 kK. Upstream since the import, on `dev`,
in every flavour. Taking Hbeta from the table (`tools/d370_hbeta.py`) raises
it x1.0546 on hiipdr and x1.0404 on pn150k; every non-H I ratio falls by the
same factor.
  - hiipdr: the gap to Cloudy goes from -11.6% to -6.7%. What is left is the
    ionized gas 4.4% hotter (EM-weighted 9005 K against 8628 K) and an
    emission measure 1.1% lower.
  - pn150k: emission measure and temperature match Cloudy's to 0.4% and
    0.1%, so the formula was the whole difference.
**CLOSED 2026-09-27 (D-371).** Hbeta is `hlinex(4,2)`, the table's own value, in
`output_mod` and `mocassinPlot`. Regenerated from the grids with
`mocassinOutput`, every non-H I ratio falls by exactly 1/F and H I ratios move
<0.08%. Hbeta is now inside the Lexington codes' range on all four models
(three were below it). The He II 4686 fit is S&H case B to <=1% below 15 kK
(hydrogenic scaling of the same table); Cloudy's own 4686 emissivity is 0.80-0.88
of case B in pn150k's He++ zones, a divergence to report. The transport's copy
(`emission_mod`, 0.994-0.997 of the table) waits for its own seeded pair. Ported
to this repository's `dev` with D-361's table bounds (605e838, D-373).

**L-42. Lya is carried as an 8.15 um line** (D-372). `emission_mod` adds Lya
into `HIRecLines(15,8)`, and since D-292/D-307 every line packet drawn from
that slot is emitted at the 15->8 frequency. `SED.out` has a spurious 8.3 um
line carrying 5.6% of hiipdr's emergent luminosity and 18.8% of pn150k's (27%
of its 1-1000 um). The energy that belongs in the grains near the front
crosses the PDR at 8 um instead. 0.0112 Ryd is inside L-19's 0.01-0.44 Ryd
excess band (a candidate, not measured). `lineFlux.out` reports Lya in the H I
30->8 row at 6.28 um. Not on `dev`, which has no line transport. Where Lya's
energy should go is a design decision; D-372 recommends absorbing it in the
local dust.
**CLOSED 2026-09-27 (D-376).**
  - Lya has its own slot at 1216 A.
  - The six resonance lines of `resLines.dat` are destroyed by the local dust
    with their escape probability in every dust+gas run. The destroyed part
    leaves as dust emission and heats the grains through `resLineHeating`; the
    rest is traced at the line.
  - The 8 um line is gone, and its energy is in the 15-1000 um continuum to
    1.00 (hiipdr) and 1.03 (pn150k).
  - Fronts, Hbeta, the H/H2 crossing, C+ = C and the lines are unchanged
    within 1%.
  - pn150k's PDR FUV falls 7-9%, because C IV is now mostly destroyed.
  - `resLinesTransfer` is retired, and `lineFlux.out` has a "HI 1216 (Lya)"
    row.

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
Since D-352 the grain side of the exchange uses the same MOCASSIN term. D-093's
substitution of 3D-PDR's heat(11), computed on a fixed 0.1 um grain population,
is gone, so gas and grain now agree on the energy they exchange, H2 omitted
on both sides.

**L-10. Bulk-graphite optics on the smallest size bin**, where Draine's own
table is PAH/band physics: 0.38-0.89x in the FUV and 10-32x in the far-IR.
That bin is 26% of grains by number but only 3.2% of the FUV absorption, so
the FUV impact is small and the far-IR impact is not (D-305).

**L-11. O-09: the V1/V2 slabs and `ifront` have not been re-run** since
D-260/D-263/D-266, and not at all since this cycle's changes.
**Demoted to low priority 2026-09-24 at the user's direction** (D-338): they
are 1D slab fixtures and sit outside the 3D scope this version of MOCASSIN is
being taken to production for. They stay in the tree as regression fixtures
rather than as validation targets.

**L-12. `thermBudget.out`'s cooling columns are bookkeeping, not channels.**
`coll` still carries the [C II]/[O I] it is about to hand to the chemistry,
and `PDR` is the net of added-minus-removed. The total is correct and nothing
is double counted, but the columns cannot be read as physical channels
(D-304). `pdrCoolSub`/`pdrTfacUsed` hold the two halves in memory but are
written to no file.

**L-13. CLOSED 2026-09-23 (D-334, D-335, D-336). Both published fixtures now
carry an error bar, and D-314's 37% was never the noise floor.**

A `randomSeed` keyword makes a run repeatable at fixed input and fixed rank
count (D-334); omitted or negative it keeps the historical clock seeding, so
nothing changed for runs that do not ask. Verified in both directions - same
seed byte-identical across all eight output files, different seed different -
because a silently ignored seed passes the first test for free.

Four-run ensembles on each published fixture, differing only in the seed:

    quantity            hiipdr            pn150k
    T_gas            0.06 - 0.39%      0.07 - 0.21%, 2.17% at the outer edge
    T_dust           0.04 - 0.09%      0.01 - 0.05%
    PE heating       0.45 - 1.81%      0.19 - 0.32%
    ionization front      0.08%             0.03%
    H/H2 A_V              0.20%             0.07%

**D-314's 37% swing in median T_gas is retired.** It was measured on the 5^3
fixture - six MC iterations, three of them PDR iterations, 75% converged, and
carrying the L-23 defect - and it is a property of that fixture, not of the
Monte Carlo on a production grid. It should not be quoted again.

Consequence: hiipdr's T/Cloudy of 1.058/0.949/0.838/0.815/0.788 carries sigma
of 0.2-0.4%, and pn150k's 0.698/0.750/0.737/0.625/0.668 carries 0.000-0.015.
**Every disagreement published by this project is 15-300 sigma** - the
comparisons are measurements, not draws.

Two caveats kept deliberately. Four draws means the sd itself carries about 40%
relative uncertainty, so the full range is reported beside it and three
significant figures are not claimed. And several small shifts are formally
2-4 sigma while being three parts in a thousand: an error bar makes small real
effects visible, it does not make them important.

**L-23. CLOSED 2026-09-23 (D-334). `ionDenPrev` was read and never written.**
Found by the seed test, not by inspection: two runs at the same seed were
byte-identical through iterations 1-3 and diverged at iteration 4, the
fixture's `pdrStartIter`. `iteration_mod.f90` declared, allocated and read
`ionDenPrev` with no assignment anywhere in the tree, and one of its two reads
was `grid%ionDen = (1-pdrCoupleDamp)*ionDen + pdrCoupleDamp*ionDenPrev` - so
with the defaults (0.25, five passes) a quarter of uninitialised memory went
into the ionization fractions on four of every five coupling passes, on every
MC iteration from `pdrStartIter`, in every PDR run this project has done.

The D-216 comment above it asserted the block was inert and "measures zero";
the residual printed beside it read 1.95e30 in one run and 2.26e6 in the other,
for a quantity bounded by 1, and had done so for as long as the diagnostic
existed. Fixed by taking the snapshot the damping always assumed it had. The
residual now reads exactly 0.00000000, which *confirms* D-216's claim rather
than asserting it.

**Effect on published results: none.** On the 5^3 fixture it was worth a factor
92 in PDR temperature, and D-334 wrongly generalised from that. On both
production fixtures T new/old is 0.974-1.001, every point inside the ensemble
spread (D-335, D-336): `updateCell` recomputes `ionDen` at the top of every MC
iteration, so the corruption only perturbs the chemistry within one iteration,
which 22 iterations converge out of and 6 do not. Neither artifact needed
rebuilding. The one residue is PE heating +0.6 to +1.0%, the same sign at every
depth - real and negligible.

**L-14. The warm start runs, but warm-versus-cold equivalence is unverified**
(D-317, was "broken", was "not exercised"). Five defects were found by running
it once and all are fixed: `setLineNuP`/`allocLineArrays` never called;
`resetGrid` called twice through a scalar aliasing the array; `readInput()`
commented out, which left `lgPDR` at `.false.` so every PDR allocation was
skipped while `#ifdef PDR` code still read the arrays; and the
double-allocation clash that the commenting-out had been working around,
across nine star arrays and six further module arrays, now guarded.

It resumes correctly on the test fixture - A_V identical over the same 53
cells, the same 50 PDR cells, the chemistry continuing rather than re-seeding,
100% convergence and the energy budget closing. **What is not done** is the
test that would license production use: resume-and-converge compared against
running cold to convergence. **Also (D-351):** `pdrLevPop`, `pdrCoolTab`,
`pdrHeatXtra` and `pdrCoolSp` are not in the checkpoint. updateCell runs
before pdrStep, so the first resumed thermal balance has neither the PDR
coolants nor the PDR heating.

**L-20. `mocassinPlot` is fixed but unrun; `mocassinOutput` has now run
(D-361).** Run on both D-358 grids, `mocassinOutput` reproduced the run's own
`lineFlux.out` byte for byte except every He II line, which it gave as zero:
it never called `readData()`. It now does, and it reproduces the file.
Both had
the D-317 defect - `lgPDR` consumed before anything set it, so `resetGrid`
skipped every PDR allocation and the tools would have emitted output with the
PDR state silently absent. `readInput()` is now called in both and both
compile, but neither has been run against a grid, so the fix is verified only
to the extent that D-317's was before it was exercised (D-318).

**L-21. The comparison tools carried four fixture-specific constants, and one
of them was in every published figure.** `tools/d260_roellig.py` held hiipdr's
A_V plot range and radius ticks as defaults (D-283 kept them so hiipdr's
figures would stay pixel-identical) and pn150k's Cloudy grain size span; it
drew the pn150k axis out to A_V 3.2 for a model ending at 0.67, clipped four
curve labels off the left edge, and collapsed the radius axis onto one point.
`tools/d305_tdust.py` could not read hiipdr's `dust_sizes.dat` at all, and its
sample depths covered the first fifth of hiipdr's PDR. A fifth turned up the
moment the next tool was pointed at hiipdr: `tools/d304_budget.py` sampled
pn150k's A_V 0.05-0.65, which on hiipdr would have **stopped short of the
crossover the run was made to reach** (D-322). All five are now derived from
the run or from Cloudy's own output (D-319, D-320, D-322), and the tools print
what they resolved. **The general risk stands:** a tool run on only one fixture
cannot tell a property of that model from a property of the physics, and
neither can its author. Running each tool on a second fixture is the test;
`tools/d196_axis.py` still hardcodes 31^3 and has not had it.

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
  - ~~**`hiipdr`** under this cycle's changes~~ - **done** (D-320/D-321,
    `runs/d316-hiipdr`, artifact v10). What is *not* done on this fixture is
    the per-cell heating/cooling budget that D-304 read on the 150 kK model,
    which is now the open question: the disagreement is a profile *shape*,
    too much energy deposited inside A_V 1 and too little beyond 1.5.
  - **The warm start**, beyond compiling (L-14).
  - **pn150k on the current code.** Its last run is D-336, before D-348 and
    D-350. The two Cloudy artifacts (2026-09-24) and `hiipdr Against 3D-PDR`
    (2026-09-14) all show pre-D-348 physics (D-351).
  - ~~**The plain flavour against Lexington**~~ - **run** (D-362). D-360 and
    D-362 are identical on every benchmark quantity. Against the codes this
    branch has 14/8/24/15 lines in range (HII40/HII20/PN150/PN75) where `dev`
    had 16/9/26/16 at D-270. HII40's <T> is 8131 K, now inside the codes' range
    (dev: 8358), and many collisional lines are 10-35% lower than dev's. The
    change has not been attributed across D-280..D-330.
  - **The 1D PDR flavour** (`PDR=1` without `PDRGEOM=3D`), beyond compiling.
  - ~~**Any model reaching A_V > 0.7**, so L-3 is untested~~ - **superseded**
    (D-333): `runs/d326-stick` reaches A_V 2.999 and L-3 is measured there.
    What is *not* checked is anything past A_V 2.45, where the vendored 3D-PDR
    reference stops and MOCASSIN's C+ is still falling.
  - **MOCASSIN against the vendored 3D-PDR reference on TEMPERATURE.** Every
    published comparison in this project is against Cloudy. At matched A_V and
    n_H = 100 the PDR runs 0.46-0.65x the reference in T_gas while carrying
    6-10x its FUV field; matched on field instead, 24.4 K against 85.1 K. Not
    a defect claim - the A_V zero points differ and the G0 unit convention has
    not been checked across the two codes - but the check has never been made
    (D-333).
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

    # regression against a previous binary, exact at a fixed randomSeed (D-352)
    tools/regress.sh <fixture> <new-binary> <baseline-binary> <outdir> [np] [seed]
    ~/miniforge3/envs/astro/bin/python tools/regress_cmp.py <A>/output <B>/output

    # dust optics against Draine's tables, and the extinction curve
    ~/miniforge3/envs/astro/bin/python tools/d305_dustaudit.py

    # the thermal budget, term by term, against Cloudy
    ~/miniforge3/envs/astro/bin/python tools/d304_budget.py \
        <run> <cloudy-prefix> <lines-off-run> <ioncont>

    # dust temperature size by size
    ~/miniforge3/envs/astro/bin/python tools/d305_tdust.py <run> <cloudy-prefix>
