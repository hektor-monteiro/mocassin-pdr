# MOCASSIN-PDR: validation status and known limitations

What the PDR coupling and the H2 level model have been shown to do, what they
have *not*, and the size of each known defect. Every number here is measured
and traceable to a DEVLOG or DEVLOG-H2 entry; nothing is asserted from
expectation.

Read alongside `doc/dust.md` (grain input and optics), `DEVLOG.md` and
`DEVLOG-H2.md` (the full history, including the hypotheses that turned out
wrong).

Status as of D-431, 2026-10-21: release `pdr-coupling-v2.0` (D-429, D-430)
and this page's audit. Reference models: the 150 kK PN (`pn150k`, 41^3,
n_H = 1000, MRN graphite) and the H II region and PDR of Bisbas et al. (2015)
section 5.4 (`hiipdr`, 31^3, n_H = 100, silicate), each against Cloudy c25.00
on a matched input.

**How this page is organised.** Section 3 holds only what is open. Everything
resolved, with the measurement that closed it, is in section 4. An item keeps
its number when it moves. Where an item was resolved in part, its open part is
in section 3 and its resolved part in section 4, under the same number.

---

## 1. What this is

MOCASSIN's 3D Monte Carlo photoionization and dust radiative transfer, with
3D-PDR's REDUCED 33-species steady-state chemistry solved in every active
cell. MOCASSIN owns the radiation field, the dust, A_V, the ionization balance
and the gas temperature; the chemistry owns the molecular abundances and CO's
cooling. C I, C II and O I are MOCASSIN's own atoms, with the chemistry's
collision partners and escape probabilities (D-363). Since
`pdr-coupling-v2.0` (D-429) the 3D build also solves H2's rovibrational levels
in every cell with gas (`source/h2_mod.f90`). They set the chemistry's H2
photodissociation rate and the H2 heating every PDR iteration, and give the
H2 line spectrum.

Four build flavours, all required to compile before any change lands:
`PDR=1 PDRGEOM=3D` (ray-traced columns and the H2 level model, the default),
`PDR=1` (1D slab columns, no level model), plain `mocassin` (no PDR), and
`PDR=1 mocassinWarm` (resume). `h2Test` and `h2Slab`, the level model's
standalone tests, build after the 3D flavour.

---

## 2. What is validated

### Conservation and internal consistency

| test | result | where |
|---|---|---|
| x(HI) + 2x(H2) + x(HII) = 1 at every depth | holds **by construction** since `rescaleIonToAvail` (D-220); the test that can fail is the pre-rescale `[D220]` lag - see L-29 (section 4). Since D-404 it passes un-enforced in the written model: no cell off by more than 1% on hiipdr or pn150k | D-351, D-404 |
| thermal balance residual (H-C)/H | 7e-4 to 7e-3 across the PDR | D-304 |
| budget recorded at the cell's kept T_e | 0.8% median, 4.1% p95 | D-304 |
| grain diagnostic closes: PE = Nabs/H x \<Y\> x \<E\> | **1.00** | D-304 |
| dust emission table vs independent 4∫C_abs B dν | **1.000** | D-309 |
| radiative-equilibrium solve reproduced independently | 0.9988, 0.9988 | D-309 |
| ion balance failures | **0%** (was 16-18%) | verified D-314 |
| convergence reached | **90.4%** of cells (now reported, not tested) | verified D-314 |
| model-integrated stop test, `convTotals` 2% over 3 iterations | hiipdr passes at 15, pn150k at 17 | D-391, D-392 |

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

These figures were measured before D-420/D-421 changed the gas-grain exchange
(L-9). The dust and A_V rows do not depend on it. The x(C+), photoelectric and
field rows have not been remeasured since.

### Physics verified inside MOCASSIN alone, with no reference

The deep PDR is a two-term thermostat - grain photoelectric heating against
subthermal [C II] 158 um - on both sides. Across the `MOCASSIN_LINES` on/off
pair (a switch retired at D-352; tag `d352-zone-and-switches` rebuilds it),
with one binary and one switch,

    exp(-91.2/T_on) / exp(-91.2/T_off)  =  H_on / H_off

holds to **pred/meas = 0.986-1.014** at A_V 0.30-0.65 (D-304). The gas
temperature is set by the heating, and the cooling side is not at fault.

### The H2 level model (DEVLOG-H2)

| test | result | where |
|---|---|---|
| X-level populations against Cloudy's large H2 model, 15 one-zone models (T 50-3000 K, n_H 1e2-1e6) | **0-0.5%** on every level that collisions and radiative decay set | H-003 |
| pump rate per level and Solomon rate against Cloudy, given Cloudy's populations, 16 one-zone models (1-1e4 Habing) | **1.000** and **1.000** | H-004 |
| line overlap against the exact integral on a 0.05 cm^-1 grid | **0.2-1.6%** at N(H2) 1e17-3e20 | H-006 |
| hiipdr 1-0 S(1) from 6e6 to 3.84e8 packets | **+0.8%**; no line moves by 1% from 16x to 64x | H-032 |
| warm start: the first call on resumed populations against the checkpointed run's last | **0.6%** in the Solomon dissociations | H-020 |

The comparison of the H2 lines themselves with Cloudy's is a divergence, not a
validation: L-56.

### Release check, `pdr-coupling-v2.0` (D-429)

The production build of the merge, against the H2 branch's last runs:
  - **hiipdr 31^3** reproduces DEVLOG-H2 H-042's run in every output file,
    apart from `summary.out`'s clock times.
  - **pn150k 41^3**, seeded, 18 iterations, against its last level-model run
    (D-405's code), the first run there of D-418, D-420 and D-421:
    - health clean, with 3 flagged cells;
    - ionized median T_e x0.996, with the gas-grain share of the ionized
      cooling 1.2e-3 -> 1.5e-2;
    - Hbeta +0.49%; forbidden lines -0.8 to -2.7%;
    - H2 lines within 0.22%;
    - the one cold-core cell from 21.5 K to the dust's 24.4 K.

### Regression

(D-314, before the switch was retired at D-352.) With `MOCASSIN_LINES=off`,
the binary of that cycle reproduced the pre-change binary
(b83e0e0) within the same-binary Monte Carlo scatter on every measured
quantity, and A_V matches **exactly** (D-314). The only functional change in
the cycle is the default flip; the dust cross-section and opacity chain is
provably untouched.

---

## 3. Known limitations (open)

Only what is open today. Severity is the effect on a published number, not on
aesthetics. Resolved items are in section 4.

| item | what is open | severity | entries |
|---|---|---|---|
| L-3 | The deep carbon turn is shallow at the production packet count, and CO is not converged | High | D-333, D-408 |
| L-26 | The deep chemistry is Monte Carlo noise-limited per cell; past A_V 2 carbon is drawn in one of two states | High | D-351, D-365, D-405, D-408, D-411 |
| L-19 | The two codes put reprocessed energy at different frequencies; the PDR's grains are 7-8% cooler than Cloudy's | High | D-307, D-353, D-376 |
| L-37 | Unresolved ionization-front cells dominate the [O I] lines | High | D-362, D-365, D-379, D-381, D-382 |
| L-43 | Transition-zone H2 is 14-230 times Cloudy's | High | D-387, D-389, D-395, H-002, H-021, H-023 |
| L-46 | The network has no chlorine, 25-50% of Cloudy's H2 sink in pn150k's shielded gas | High | D-399, D-400, D-401 |
| L-55 | Molecular cells whose held PDR heating swings; their H2 rotational lines are not converged | High | H-043, D-421 |
| L-4 | The diffuse field's formal solution recovers 52-130% of the Monte Carlo's, unexplained | Medium | D-348 |
| L-47 | `ionBalance` trails the chemistry by one iteration before the last | Medium | D-402, D-403, D-404 |
| L-48 | Charge transfer with H: helium below 6,000 K, steps where the data sets join, hiipdr's Mg I | Medium | D-402, D-403 |
| L-51 | A gas absorption is re-emitted from the H and He spectrum, whatever absorbed it | Medium | D-405, D-408 |
| L-52 | T(H0) in the stop test is carried by the front's hot cells; what a 2% stop leaves | Medium | D-405, D-408 |
| L-53 | Symmetry-equal cells differ in n(H2) along the twelve rays' axis | Medium | D-405, D-408, D-410 |
| L-56 | The H2 lines differ from Cloudy's by spin, mostly through the line width (a divergence) | Medium | H-005, H-008, H-024, H-026 |
| L-57 | test_Problem's face-on H2 maps are 3-5.5% fainter on the y side | Medium | H-037 |
| L-58 | Where the H2 level model does not run | Medium | D-429 |
| L-5 | The gas phase is not depleted for what is in grains (common-mode) | Medium | D-305 |
| L-6 | The fixtures' extinction curve is not a Milky Way curve (common-mode) | Medium | D-305 |
| L-7 | No PAH component in the fixtures | Medium | D-305, D-415 |
| L-8 | Stochastic heating is off | Medium | D-305, D-306 |
| L-10 | Bulk-graphite optics on the smallest size bin | Medium | D-305 |
| L-54 | H2 formation applies one dust temperature to both materials | Medium | D-414, D-417 |
| L-11 | The 1D slabs and `ifront` have not been rerun (out of scope) | Low | D-338 |
| L-12 | `thermBudget.out`'s cooling columns are bookkeeping, and its PDR heating lags an iteration | Low | D-304, D-421 |
| L-15 | `getQs` caps the Mie size parameter at 100 | Low | D-305 |
| L-16 | `dustDriver` allreduces into temporaries | Low | D-305 |
| L-17 | `absInt`/`scaInt` are cumulative and never reset | Low | - |
| L-21 | `tools/d196_axis.py` hardcodes 31^3 | Low | D-319 |
| L-30 | Two clamps that still decide a value | Low | D-352 |
| L-50 | A first ion trimmed out of the ion matrix has no place for a source | Low | D-404 |
| L-59 | A `PREFIX` over about 90 characters loses atomic data silently | Low | D-416 |
| L-60 | A bare `make` builds no executable | Low | D-424 |
| L-63 | The transport's H I emissivities use Storey & Hummer's fit, not their table | Low | D-371 |

### High - affects results now

**L-3. O-01: deep C+ drop past A_V ~2.1 - measured (D-333); most of it was the packet count (D-408)**
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

**D-408: most of it is the packet count.** On hiipdr against Cloudy,
x(C+) over Cloudy's at A_V 2.3 / 2.5 / 2.7 / 2.9 is:

| packets | 2.3 | 2.5 | 2.7 | 2.9 | C+ = C |
|---|---|---|---|---|---|
| 6e6 | 0.18 | 0.18 | 0.21 | 0.29 | 2.29 |
| 2.4e7 | 0.97 | 0.68 | 0.21 | 0.29 | 2.51 |
| 9.6e7 | 0.98 | 0.92 | 0.71 | 0.29 | 2.72 |
| **3.84e8** | **0.98** | **0.93** | **0.82** | **0.63** | **2.80** |

Cloudy's C+ = C is at 2.93. Each factor of 4 moved the turn by 0.22, 0.21
and then 0.08 mag. What remains at 64x is a turn 0.13 mag shallow whose
deep side is still sharpening: a divergence to report, a fifth of the 6e6
one.

The gas warms with it (A_V 2.5: 11.2 -> 16.9 K, Cloudy 19.3), as D-333's
open hypothesis above would have it. Whether that is through the carbon's
cooling or another path has not been separated.

The [C I] carrier is no longer 5x off. [C I] 609 um falls from 1.65 to 1.17
of Cloudy's and stops (-0.9% from 16x); 370 um goes 1.29 -> 1.10. CO still
moves at 64x (L-26). D-333's comparison against the vendored 3D-PDR
reference has not been repeated at a higher count.

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
**D-405: at the carbon turn the noise is not scatter about a mean, it is two
states.** With every iteration's cells kept and no damping, 85-97% of
hiipdr's cells in each 0.1 mag bin from A_V 1.9 to 2.6 are either ionized in
carbon (C+ above 0.9 of the carbon, about 20 K, n_e 2.3e-2) or in the state
cosmic rays alone maintain (C+ 0.166, about 12 K, n_e 5.6e-3); the deep
state holds 3, 10, 25, 47, 70, 87, 94% of the cells down those bins. A cell
is ionized when a packet of the 11.26-13.6 eV band crossed it in that
iteration: one crossing gives a rate 20-100 times the recombination rate
*(estimate)*. The state is drawn again at every iteration, with a
correlation of 0.04-0.16 with the iteration before, half of it unequal
exposure within a bin and half memory of one iteration (candidate, not
tested: neutral carbon's own opacity in that band, about 0.5 across a cell).
"C+ = C" in this model is where half the cells are missed, not where the
mean rate balances recombination. **At four times the packets the turn
moves**: the deep state's shares become 0.0, 0.6, 3.4, 10, 30, 52% from A_V
2.0-2.1 to 2.5-2.6, the fourth power of the 6e6 shares at A_V 2.1-2.2 and
0.4-0.7 of it from 2.2 on (ionized carbon in front lets more of the band
through); C+ = C goes from A_V 2.29 to 2.51 (Cloudy 2.93), n(C) over the
neutral cells falls by 28% and n(C+) rises by 22%, and [C I] 609 and 370 um
both fall by 20%, from 1.65 and 1.29 of Cloudy's to 1.32 and 1.03 (1.71 and
1.47 with the damping). **hiipdr's [C I] lines are not converged in the packet
count at 6e6.** With D-280's path biasing on the undamped production model
(pathStretch 0.5) no cell before A_V 2.6 is left in the deep state and C+ = C
is at A_V 2.61 (the comparison tool's measure, which gives 2.25 without it and
2.52 at four times the packets); but the weights reach 1e4, the scatter among
equivalent cells before the turn is 1.25-1.45 of the analog run's, and n(CO)
rises by 36% and the CO lines by 52-109% where four times the packets gives
-7% and +0.5 to +46%. It is not a remedy to switch on as it stands. The
field's noise itself is new at
every iteration in full: the spread of a cell's 7- or 9-iteration mean among
symmetry-equivalent cells is 0.33-0.41 of one iteration's, as 1/sqrt(N).
The first remedy above (accumulate the field once it has settled) is what
this calls for, and it is still a design decision. **Registered for future
development by the user (2026-10-15, D-411):** the design, its risks and its
test against D-408's series are in D-409's addendum.
**D-408, the series to 64x.** hiipdr from 6e6 to 3.84e8 packets, pn150k to
2.4e7, seed 1001, the iteration counts fixed.

  - **Per-cell spread.** Before the carbon turn every spread falls to
    0.46-0.69 of the count before at each factor of 4, as 1/sqrt(N). The
    exception is H2's at A_V 0.46-1.48, where L-53's pattern stays
    (0.60-0.96).
  - **The turn** converges at 64x (L-3).
  - **The products split.** Converged at 6e6 on both fixtures: the H2
    lines, the ionized gas's lines, [O I], Hbeta and the H/H2 crossing
    (hiipdr's 1-0 S(1) +0.8% from 6e6 to 3.84e8). [C I] needs 16-64x. CO
    still moves at 64x on hiipdr (+5 to +10.5% per factor of 4, half the
    step before) and falls by 5% at 4x on pn150k.
  - **The bias of the means is one way.** Fewer packets give a shallower
    turn and colder deep gas on hiipdr, and more C and CO on pn150k. A
    higher count is a correction, not only less scatter.
  - **pn150k at A_V 0.25-0.35.** In this band alone the steps from one
    iteration to the next grow at 4x (ln x(H+) 0.062 -> 0.145, n_e 0.004 ->
    0.040). Read as the ionizing packets past the front arriving at about
    one per cell per iteration; not tested.
  - **Cost.** hiipdr 31^3 goes from 41 min to 2 h 07 min at 64x, about 1.4
    min per 6e6 packets. pn150k's packets cost nothing at 4x.

The choice between a production count and accumulating the field is
D-409's: proposed, and the user's to make.

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
**Available to users (D-382):** the keyword `frontLines` writes
lineFluxFront.out after convergence. It holds [O I] 6300/6363/5577,
uncorrected and through the sub-cell profile, with MOCASSIN's own O I atom
at each depth. It is an estimate beside lineFlux.out, not in it.

**L-43. Transition-zone H2 is 100-1000x Cloudy's** (D-387, D-389). In the
partially ionized layer of pn150k, 2n(H2)/n_H is 2.9e-8 to 7.9e-7 in ours against
6.6e-11 to 3.7e-9 in Cloudy's, at the same x(H+) and T. REDUCED forms ground H2 from
H + H2+ directly; Cloudy forms H2* and destroys it with electrons (e- + H2* -> H +
H-) before it relaxes, so its TZ H2 is grain-made. REDUCED lacks H-, H2*,
electron-impact dissociation of H2+ and dissociative attachment. Aleman &
Gruenwald 2011 reach ~1e-5 there. Until v2.0 no production output depended on
it; since then the H2 lines do (below). Not tuned.
**Partly addressed 2026-10-05 (D-395):** the network had no electron-impact
dissociation of H2+ (e- + H2+ -> e- + H + H+), Cloudy's main H2+ sink in
ionized gas; added as reaction 332 (Janev et al. 1987). The zone's H2+ falls
2-2.8x on hiipdr and 2.6-7x on pn150k, to 3-4x Cloudy's on pn150k (was
9-22x). Its H2 falls 2x and 1.6-4.1x and is still 14-62x (hiipdr) and
30-230x (pn150k) Cloudy's at the same x(H+); nothing past the front moves.
What remains is the level-resolved part: gas-phase H2 made into excited
levels and destroyed there by electrons (H-021's plan, h2-model), and two
rate choices (H2+ dissociative recombination above 300 K; H+ + H2).
**Since v2.0 (D-429)** the H2 level model is in production, and its lines take
this zone's H2 from the chemistry. Whether the zone adds collisional H2
emission, as Aleman & Gruenwald find, turns on that abundance (DEVLOG-H2 H-002,
open).

**L-46. The network has no chlorine, a quarter to a half of Cloudy's H2 sink
in pn150k's shielded gas** (D-399; DEVLOG-H2 H-026). In Cloudy's model of the
150 kK PN, Cl+ + H2 -> HCl+ + H and HCl+ + H2 -> H2Cl+ + H carry 25-50% of
the destruction of H2 from A_V 0.26 on (photodissociation 64% falling to
20%). REDUCED's 33 species bear H, He, C, O and Mg only. Cloudy rerun
without chlorine turns molecular 0.042 mag earlier (crossing A_V 0.368 ->
0.326), with n(H2) at A_V 0.30 1.6x and its 28.2 um H2 line 1.43x; that is
the size of the effect in Cloudy, not in ours. It was hidden: on pn150k our
crossing sits 0.026 mag past Cloudy's because a line width that shields our
H2 less (+0.10 mag, h2-model) and this missing sink (about -0.04) nearly
cancel. hiipdr has no chlorine in either code. Not fixed: it needs Cl, Cl+,
HCl, HCl+ and H2Cl+ in a network that is generated code. Deferred by the
user 2026-10-10 and logged as work to do: D-400 has the reactions already in
the tree, the decisions to take first and how it would be measured. D-401
audits the coupling for it and for 3D-PDR's full network (usable, at
25-100x the solve time, but not before L-34's decision; chlorine first, in
a 38-species network, is the recommended order). L-34's decision was taken
in D-402: an added element now gets one x(X+) by construction, once it is
in the link table.

**L-55. Molecular cells whose held PDR heating swings between iterations**
(DEVLOG-H2 H-043; D-421). In 18-23 cells of each K1a run and 95-119 of each
hiipdr run with x(H2) > 0.1, the PDR heating that the last temperature search
held is more than 3 times what the finished model rebuilds from its own terms:
cosmic rays, turbulence, the chemistry's 13 tagged reactions and the level
model's three H2 terms. The bulk median is 0.97-1.00. `thermBudget.out` is
written before the last `pdrStep` (L-12), so the mismatch measures how far
those cells moved between the last two iterations, not a missing term. It
predates D-420. It matters for the H2 rotational lines of dense models: in
D-421's K1a dust10 pair, 0-0 S(2) moved x13.5 and S(1) x2.44 through one cell
at 955 K. The per-iteration record that would decide it is not built. Treat the
H2 rotational lines of such models as unconverged.

### Medium

**L-4. The diffuse field's formal solution recovers only 52-130% of the
Monte Carlo's `chi_dif`, falling with depth, unexplained** (D-348). The
scattering sites that carry the diffuse field to the chemistry
(`traceDiffuseSites`) are weighted by the formal solution
`S exp(-tau)(1 - exp(-dtau))` from MOCASSIN's own grains and field. The
weights are normalised, so the chemistry receives the Monte Carlo's own
`chi_dif`, and the formal solution only sets how it is spread over the sites.
That the solution sums to 52-130% of the Monte Carlo's value is therefore a
discrepancy in the distribution, not in the energy, and its cause is not found.
Candidates: gas two-photon emission, the phase function, the twelve-direction
quadrature (L-53). The 1D flavour keeps the direct-only chemistry (out of
scope, L-11). The four named defects of O-14 are resolved (section 4, L-4).

**L-47. `ionBalance` trails the chemistry by one iteration: measured, and
removed from the written ions; the iterations before the last still run on
it** (D-402, D-403, D-404). MOCASSIN solves its balance before the chemistry
in each iteration, so the terms it takes from the chemistry, and the
molecular content its stages are normalised to, are the previous
iteration's. D-404 tested it by solving the balance a second time after the
chemistry, at the same temperature, with the model put back afterwards so
that the run's path is unchanged, and with a control (a second solve on the
old terms, which moves nothing). Neutral cells whose solver X+/X is more
than 10% from MOCASSIN's, last iteration, first solve -> second: hiipdr H
28.4 -> 0.0, He 13.2 -> 0.0, C 1.5 -> 0.0, O 21.1 -> 9.7, Mg 12.9 -> 0.0;
pn150k H 15.5 -> 0.0, He 0.4 -> 0.0, O 28.8 -> 0.0; and so at every
iteration. The delay was all of it but hiipdr's oxygen (L-50). When a run
stops, the last iteration's second solve now takes the first's place in
the written model (damped as the first was, while the damping was on); the
hydrogen budget then closes un-enforced (L-29) and no line of either
fixture moves by more than 1.0% ([C I] 370 um, hiipdr). With the damping
the written ions were still more than 10% from the solver's in 13.4 (H),
32.1 (C), 18.7 (O) per cent of hiipdr's neutral cells and 6.4, 14.1, 18.6
of pn150k's; that was the damping (L-49), not the delay, and since D-406,
with the damping off by default, only hiipdr's oxygen is (9.9%, L-50).
Open:
  - the second solve is kept at the last iteration only. Every iteration
    before it still gives the transfer, the thermal balance and the
    chemistry ions solved one iteration behind. Keeping it throughout
    changes the path and has not been run; within an iteration it moves n_e
    by more than 10% in at most 0.1% (pn150k) and 2.1% (hiipdr) of the
    neutral cells;
  - neither the temperature nor the chemistry is solved again on the
    second solve's ions;
  - one solver for both, D-401's other route, is not started.

**L-48. Charge transfer with H: which data, where** (D-402, D-403). Both
solvers use one coefficient per reaction, from one routine (`pdrCtCoef`).
D-403 put the data sets side by side: **oxygen's** rates in the network are
fits to Stancil et al. (1999) over 10-41,000 K and agree with the fits
Cloudy uses to 0.89-1.04 (O+ + H) and 0.97-1.33 (H+ + O); Kingdon &
Ferland's, MOCASSIN's until D-402, is 0.36-0.55 of them above 8,000 K. They
stay, and what D-402 said of them is withdrawn. **Magnesium** (H+ + Mg) and
**helium** (He+ + H) use Kingdon & Ferland's fit inside its stated range
(5,000-30,000 K; 6,000-1e5 K) and the network's outside: pn150k's Mg I
lines are 0.70-1.30 of Cloudy's (9-16 with no transfer, 0.17-0.32 with the
network's 1.1e-9). Open:
  - helium below 6,000 K, where the network's is 2.4-3.4 times what Cloudy
    uses. It, and hydrogen receiving the transfer at all, are what moved
    pn150k at D-402 (Hbeta +0.25%, the gas behind the front 3-6% colder,
    0-0 S(0), S(1) -3.9, -2.5%) - not the coefficient's size above 6,000 K,
    as D-402 had it;
  - the coefficient steps where the data sets join: x2.9 at 6,000 K (He),
    x30 at 5,000 K (Mg). One of pn150k's two flagged cells is at 5,840 K;
  - hiipdr's Mg I 2852 is 0.09 of Cloudy's (0.19 before any transfer).

**L-51. A packet absorbed by the gas is re-emitted from the hydrogen and
helium spectrum, whatever absorbed it; in the PDR some come back ionizing**
(D-405). A gas absorption makes a "diffuse" packet: a line with probability
`totalLines`, otherwise a frequency drawn from `recPDF`, the hydrogen and
helium diffuse continua and nothing else (`photon_mod.f90:896-1010`,
`emission_mod.f90:855-925`). That closes the energy budget of an ionized
nebula. In neutral gas the absorber of an 11.26-13.6 eV packet is carbon,
and what returns, some of the time, is a photon that ionizes hydrogen or
helium, with the full packet energy, absorbed on the spot. Measured from
cell histories without damping (`histdamp.events`): 76-103 of hiipdr's
15,048 neutral cells per iteration have x(H+) above ten times their own
median (52 times in the median, x(He+) 112 times, n_e 4.2 times, the FUV
field unchanged): 1.9% of the cells per iteration at A_V 2.15-2.43, where
neutral carbon meets its band, 0.1% at 1.6-1.9 and at 2.7-3.0, none at
0.74-1.31, and 0.6% in the first quarter magnitude behind the ionization
front, where the ionizing field itself ends.
The chemistry is solved in steady state, so it takes one iteration's
ionization as permanent: 60-77 of those cells lose 30% or more of their H2
for that iteration and about 35 more than half (median molecular fraction
0.98 -> 0.38 -> 0.98); every one of the 202 such drops in six iterations is
on an over-ionized cell. pn150k: 10-28 cells per iteration and all eight
drops. In the sums it is 0.3% of hiipdr's deep H2; in a map it is a cell
with the wrong state, and the damping spreads it over the following
iterations. At four times the packets there are 107-146 such cells per
iteration, at 26 times their median (He+ 54, n_e 2.2), and 23 drops of more
than half the H2 in six iterations: more packets, each with a quarter of the
energy. The mechanism is read in the code, and two things it
requires hold in the histories: the events fall on cells whose carbon was
neutral at the iteration before, which is the model the transfer ran on (a
third of the events at A_V 1.8-2.0 from the 1-3% of cells that had it, two
thirds at 2.0-2.2 from the 11-25%), and from A_V 2.0 to 2.7 their rate is
0.11-0.18 of the product of a bin's shares of ionized and deep cells while
the rate itself changes twelvefold. It is **not isolated** by a run with
the channel closed. A remedy is a design decision: which spectrum an
absorption by something other than hydrogen or helium should return
through.

**D-408.** On hiipdr at 16x and 64x there are 135-167 and 90-124
over-ionized cells per iteration, at 18 times their median both times. No
drop of more than half the H2 remains: 202 / 23 / 0 / 0 from 6e6 to
3.84e8.

On pn150k the events do not fall with the packets: 11-27 and 14-33 cells
per iteration at 6e6 and 2.4e7, at 24 and 26 times their median. Its He+
events fall by a factor of 2.7, and the drops of half the H2 go from 9 to
0.

**L-52. T(H0) in the stop test is the ionization front's hot cells**
(D-405). The temperature weighted by neutral hydrogen, one of the integrated
quantities of D-391's test, is carried by the cells above 3,000 K: 72% of
its sum on pn150k (701 cells of 35,384) and 68% on hiipdr (182 of 15,204);
the cells below 100 K, which are the neutral gas, hold 14% and 29%
(`cvdamp.py` prints it for any run). Ten to thirty of pn150k's hot cells
change side at each iteration, so T(H0) scatters by 1.0% from one iteration
to the next without damping (0.9% on hiipdr), and the test's difference of
two values three iterations apart by 1.4%: the 2% limit is 1.4-1.5 standard
deviations of that. pn150k's undamped run passes at 15 and 16 and would
fail at 17 (2.73%) on T(H0) alone. With the damping the same quantity keeps
the test above 4% until iteration 16; since D-406 the default is undamped,
so this scatter is in every run's test. To decide: whether a quantity carried
by a few hundred front cells belongs in the test, or with what limit.

**D-408: the test does not see the packet count.** On hiipdr the trail is
the same from 6e6 to 3.84e8 packets: 2.3-2.5% at iteration 13, 1.6-2.0% at
14 and 1.3-1.8% at 15, carried by O+ and S2+ in the H II region. Over the
same series C+ = C moves 0.5 mag. A run stopped at 2% stops at iteration 14
whatever its packets (15 at 6e6).

On pn150k at 4x the test sits at 0.3-0.6% once He2+ has settled, the
excursion of T(H0) at 17 is gone, and T(H0)'s floor falls from 1.02% to
0.47%.

**What a 2% stop leaves of the H II region's relaxation** (from L-40, D-405).
At the iteration the test stops hiipdr (15), the hydrogen emission measure is
still falling by 0.14% per iteration without the damping, successive steps in
the ratio 0.72, so about 0.36% is still to come *(extrapolation)*. On pn150k
the ionized gas's temperature rises with ratio 0.6, and He+ still falls
0.1-0.2% per iteration at 18. What sets a ratio of 0.6-0.7 per iteration is not
known.

**L-53. Cells that the grid's symmetry makes equal differ in H2, following
z** (D-405). In an octant on a cubic grid the cells (i,j,k) and their
permutations are one cell of the model. Their spread is Monte Carlo noise
that averages away over iterations as 1/sqrt(N) for the field, the
temperature and carbon; for H2 before and across the H/H2 transition it does
not (0.61, 0.63, 0.48 of one iteration's spread after nine iterations on
pn150k, where 0.33 is expected). What stays follows the z axis: of six
equivalent cells the one nearest the plane z = 0 has 11% more H2 than the
two nearest x = 0 and y = 0 just behind pn150k's front, 6% at A_V
0.25-0.35, 1.8% at 0.35-0.44 and under 0.6% in the molecular gas, the two
agreeing with each other; on hiipdr 11% and 7% before the transition and
nothing past it, with x and y differing too (the FUV field there differs
by direction by 0.4%). The star's A_V of those cells is equal to rounding.
The chemistry's columns are integrated along twelve directions fixed in the
grid frame (HEALPix level 0; L-27), a set symmetric in x and y and not in
z. **That the rays are the cause is not tested** (a run at another ray
level would). Radial means average it; a map does not.

**D-408: not noise, and not the field.** The excess does not move with the
packets:

| fixture, A_V band | the counts | excess in H2 |
|---|---|---|
| hiipdr, 0.46-1.00 | 6e6 / 2.4e7 / 9.6e7 / 3.84e8 | +11.4 / +9.4 / +10.0 / +10.1% |
| hiipdr, 1.00-1.48 | 6e6 / 2.4e7 / 9.6e7 / 3.84e8 | +6.7 / +5.3 / +5.0 / +4.9% |
| pn150k, 0.13-0.25 | 6e6 / 2.4e7 | +10.7 / +11.2% |
| pn150k, 0.25-0.35 | 6e6 / 2.4e7 | +5.7 / +5.3% (CO +6%) |

At 16x-64x chi, T and n_e carry under 0.5%, and x against y agree within
0.5% in H2. So the part of the H2 spread that stays grows as the noise
goes. At 16x this pattern is the largest systematic in an H2 map's
transition zone.

The ray set is still the candidate, and still not tested. A run with
another ray level is D-409's next step after the field, at the user's word.

**D-410 (the user's request): the rays are the cause.** Stage 1 rotated the
same twelve directions so their ring axis is x and changed nothing else.
On hiipdr at 6e6 the excess moved from the cells nearest z = 0 (+11.4% at
A_V 0.46-1.00) to the cells nearest x = 0 (+8.8%), and y and z, which
the rotated set makes equal, came to agree. Every total stayed within
0.3%, as relabelling a symmetric model requires: the error is one of
orientation, which a map shows and the totals average away.

The twelve single out their ring axis. The mean fourth power of a
direction's component is 0.132 along it against 0.218 across it
(isotropic 0.2). The directions place the diffuse field's scattering sites
and the line-escape rays (the direct field is radial).

**Stage 2: 48 directions remove it.** HEALPix nside = 2 gives 0.188
against 0.201 in the same moment. The generalized code reproduces the
default at nside = 1 in every output file.

At A_V 0.46-1.00 the three orientations agree within 1% (+11.4% on z
with the twelve). At 1.00-1.48 what is left is the seed's noise, which all
three runs share. The totals move by under 1%: the H2 lines by -0.3 to
-0.55%, the crossing by +0.0004 mag, [C I] by +0.3% and CO by up to 1%.
The run takes 1.48 times as long on hiipdr 31^3 (59 against 40 minutes).

Which of the two users of the directions carries the pattern is not
separated. Both were changed together: the sites and the line rays.

**What a map carries** (one snapshot each, the finished models):
  - **The H2 lines carry no more than the seed's noise** (2.5%) where
    n(H2) carries +11%.
  - **CO 1-0 and 3-2 carry it per cell**: +12% and +9% on the singled-out
    axis at A_V 0.46-1.00 and 1.00-1.48, following the rotation and gone
    with the 48. CO's abundance carries +0.7% there, so for these lines it
    comes through their populations and escape, which the line rays set.
    But those cells give 8e-5 of CO 1-0's luminosity on hiipdr, and the
    bands of pn150k's pattern 0.3%, so a CO map shows none of it.
  - **[C II] 158** stays within about 1%.
  - So L-53 shows in a map of n(H2) and of CO's abundance, not of the lines.

Not done:
  - pn150k with 48 directions;
  - the production code's run.

**The user kept the twelve** (2026-10-15, D-410), since no line map carries
the pattern. The 48 are a patch (tools/patches/d410_rays_nside.patch, on both
branches since v2.0), ready if a map of n(H2) or of CO's abundance becomes a product.

**L-56. The H2 lines differ from Cloudy's by spin, and most of it is the
line width** (DEVLOG-H2 H-005, H-008, H-024, H-026). A divergence to report,
not a defect. Against Cloudy's large H2 model, hiipdr's 40 strongest lines are
ortho 0.82-0.84 and para 1.13-1.19 of Cloudy's, pn150k's ortho 0.96-1.17 and
para 1.95-2.72 (H-024). The model damps each pumping line by its upper level's
total decay rate, the line's natural width. Cloudy damps it by the line's own
A, about 20 times smaller in the median (H-005), so its lines absorb less in
their wings. Run with Cloudy's width as a diagnostic
(`tools/patches/h008_cloudy_width.patch`, not adopted), pn150k's para lines
fall 3.2-fold and its ortho lines 2.2-fold (H-008, H-024), and hiipdr's H/H2
crossing moves from A_V 1.40 to 1.19, past Cloudy's 1.28 (H-026). Cloudy's
closure, which rescales every population by one factor, raises its lines by
about 1.2 (H-004, H-009). The model keeps its width.

**L-57. The test problem's face-on H2 maps are fainter on the y side**
(DEVLOG-H2 H-037). With its own astrosilicate + PAH dust, test_Problem's
rotational H2 lines are 3.0-5.5% fainter on the y side than on the x side
(0-0 S(1) 0.945 and 0.948 in the two original-dust runs, 95% ranges
0.934-0.958 and 0.938-0.958), although the input is exactly symmetric under
x <-> y. The cause is not tested; whether it is L-53's ray pattern, which
singles out z, is not known.

**L-58. Where the H2 level model does not run** (pdr_mod `h2LevelModel`;
D-429). The level model is in the 3D build only, for one grid with point
sources. It skips itself, with a line in the log, for more than one grid, for
`planeIonization`, or when there is no diffuse field. Its arrays are then
never allocated, so such a run takes the network's single-line H2
photodissociation rate and 3D-PDR's H2 heating, and writes no H2 line
spectrum. The 1D flavour has no level model at all.

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
off too, so it is common-mode (D-305). Since D-415 the file carries Im(m), so
a PAH species can heat the gas: test_Problem's astrosilicate + PAH mixture
runs (DEVLOG-H2 H-036). The fixtures still have no PAH.

**L-8. Stochastic heating is off.** `lgQheat` defaults false. For 0.005 um
grains in a PDR the equilibrium assumption is wrong for the emitted spectrum.
D-306 showed it cannot explain the dust-temperature excess (which was L-2),
so this is a fidelity gap rather than a live error (D-305, D-306).

**L-10. Bulk-graphite optics on the smallest size bin**, where Draine's own
table is PAH/band physics: 0.38-0.89x in the FUV and 10-32x in the far-IR.
That bin is 26% of grains by number but only 3.2% of the FUV absorption, so
the FUV impact is small and the far-IR impact is not (D-305).

**L-54. H2 formation applies one dust temperature to both materials** (D-414,
D-417). CT02's silicate and carbonaceous channels both take Tdust(0,0), a
number-weighted mean over every species, which in a mixture is the smallest
grains' temperature. In test_Problem that is the PAHs' 143.5 K, against the
silicates' own ~58 K; CT02's silicate efficiency is 0.074 at the first and
0.200 at the second. By the formula, a temperature per material raises
R_form there by 1.35-1.73 (not a run). The fixtures have one material each;
an area weighting would change them too, by an amount not yet measured.
**Registered for future development by the user (2026-10-16, D-417):** the
three designs, the call sites and the test are there.

### Low - bookkeeping, tools and build

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
Its PDR heating column is also one iteration older than `pdrGrid.out`:
`thermBudget.out` is written by the last temperature search, which runs before
the last `pdrStep` (D-421, correction), so in a cell that is still moving the
two do not close (L-55).

**L-15.** `getQs` caps the Mie size parameter at 100, which for a 0.25 um
grain bites above 5.8 Ryd against a `nuMax` of 30. Affects EUV/X-ray dust
absorption only, and is undocumented in the input (D-305).

**L-16.** `dustDriver` allreduces into temporaries and copies back - 2 x
165 MB per rank at this grid that `MPI_IN_PLACE` would remove (D-305).

**L-17.** `absInt`/`scaInt` are cumulative and never reset. Long-standing.

**L-21. `tools/d196_axis.py` still hardcodes the 31^3 grid**
(`NX = NY = NZ = 31`). A tool run on only one fixture cannot tell a property
of that model from a property of the physics, and neither can its author.
Running each tool on a second fixture is the test, and this one has not had it.
The other fixture-specific constants are gone (section 4, L-21).

**L-30. Two clamps that still decide a value** (D-352, which removed every
run-time ownership switch and the zone flag). Each is recorded so that it is
not found late:
  - The chemistry's rates are evaluated at Te clamped to [pdrTmin, pdrTmax],
    its heating terms at the unclamped Te: two temperatures in one pdrStep
    wherever Te > 2e4 K (3 cells of pn150k).
  - The chemistry's T_dust is floored at T_CMB, because MOCASSIN transports no
    CMB. Where the floor binds, the chemistry and MOCASSIN's dust emission see
    different grain temperatures; the fix is the CMB in MOCASSIN's field.
A third, `teFloor`, no longer binds (section 4, L-30).

**L-50. A first ion trimmed out of the ion matrix has no place for a
source** (D-404). `ionBalance` solves each element's stages as a matrix
over the stages within `ionTrim` (1e-8) of the largest and leaves the rest
at their chain value, a product of rate ratios. For a linked element the
chain's ratio carries what the network does to X+ per X+ (the loss to
molecules) but cannot carry X+ made from something other than X (channel 6
of `pdrIonRate`). Where O+/O falls below 1e-8 - hiipdr's cold molecular
gas, A_V 2.6-2.9, about 10 K, O+/O 1.6e-9 - MOCASSIN's O+ is 10-18% under
the solver's, and in each of the 120 cells probed the difference is that
source to within 3%. Those 120 are samples of the 9.7% of hiipdr's neutral
cells that the second solve of L-47 leaves more than 10% apart in oxygen
(the first twelve rank 0 meets in each iteration, all in the outer shell);
every sample is of this kind. pn150k's second solve leaves 0.0% of its
cells apart in oxygen. No line sees it. To do: keep the first two stages
of a linked element in the matrix whenever it has molecular terms, or give
the chain value the source.

**L-59. A `PREFIX` longer than about 90 characters loses atomic data
silently and crashes** (D-416, found in DEVLOG-H2 H-036). `makeElements`
(hydro_mod.f90) holds each data path, PREFIX + `/share/mocassin/` + the file
name, in `character(len=128)`. Past that the path is truncated, `inquire` finds
nothing, and that ion's data are skipped without a message; the worker ranks
then die at start-up with SIGSEGV. Recorded, not changed: a longer variable is
a one-line fix, waiting for a plan (D-419). The README and
`doc/manual-pdr-h2.md` state the limit.

**L-60. A bare `make` builds no executable** (D-424). The Makefile's first
target is an object file (`.DEFAULT_GOAL := source/interpolation_mod.o`), so
`make` with no target builds that alone. The README names the targets
(`make PDR=1 PDRGEOM=3D all`). Changing the default goal is a Makefile change
and waits for a plan.

**L-63. The transport's H I line emissivities use Storey & Hummer's fit,
not their table** (D-371). `emission_mod`'s `RecLinesEmission` takes Hbeta from
10^(-0.870 log T + 3.57), with ratios fixed at 10^4 K (`r1b0100.dat`).
Emission-measure weighted, it is 0.994 (hiipdr) and 0.997 (pn150k) of the
table the reported lines use (L-41). It sets only the energy the Monte Carlo
carries in non-Lya H I lines, and no reported number depends on it. Moving it
onto the table changes the physics, so it waits for its own seeded pair.

---

## 4. Closed issues

Resolved items, each with the measurement that closed it, in the order of
their numbers. "Recorded at D-431" marks an item that was resolved earlier
but still listed as open until this page's audit.

| item | what was resolved | closed | entries |
|---|---|---|---|
| L-1 | Line transport discarded energy | 2026-09-22 | D-306, D-307, D-315, D-320 |
| L-2 | The dust temperature was the mean of two temperatures | 2026-09-22 | D-309, D-313, D-315 |
| L-4 | The 3D self-shielding tracer's four named defects (O-14); open part in section 3 | 2026-09-26 | D-340, D-341, D-348, D-350 |
| L-9 | The gas-grain coupling omitted H2 and was 4 pi too weak | 2026-10-19 | D-305, D-420, D-421, D-429 |
| L-13 | The published fixtures had no error bar | 2026-09-23 | D-334, D-335, D-336 |
| L-14 | Warm-versus-cold equivalence was unverified | 2026-10-04 | D-317, D-393 |
| L-18 | The Q-file dust path | 2026-10-15 | D-313, D-413 |
| L-20 | `mocassinPlot` and `mocassinOutput` had not run | 2026-09-28 | D-318, D-361, D-383 |
| L-21 | Fixture-specific constants in the comparison tools; open part in section 3 | 2026-09-22 | D-319, D-320, D-322 |
| L-22 | The gas-temperature crossover was the grain charge balance | 2026-09-22 | D-322, D-324, D-325, D-326, D-328 |
| L-23 | `ionDenPrev` was read and never written | 2026-09-23 | D-334, D-335, D-336 |
| L-24 | The chemistry was handed the wrong band | 2026-09-26 | D-349, D-350 |
| L-25 | The chemistry passes oscillated on frozen inputs | 2026-09-26 | D-351, D-354 |
| L-27 | Line escape was a slab with a third of its rays shut | 2026-09-28 | D-370, D-377 |
| L-28 | Two realities for the PDR lines | 2026-09-26 | D-360, D-362 |
| L-29 | The conserved sum was enforced, not tested | 2026-10-13 | D-351, D-404 |
| L-30 | `teFloor` bound the coldest gas; open part in section 3 | 2026-10-11 | D-402, D-403 |
| L-31 | The chemistry solved H II gas as neutral | 2026-09-26 | D-356, D-358 |
| L-32 | One ion carrier per element | 2026-10-10 | D-358, D-402 |
| L-33 | Grain H2 formation 5-25x Cloudy's: a measurement error | 2026-10-05 | D-356, D-358, D-394 |
| L-34 | The PDR's H+ had channels MOCASSIN's balance lacked | 2026-10-10 | D-358, D-401, D-402 |
| L-35 | The H I line list was corrupt in every PDR run | 2026-09-26 | D-360, D-361 |
| L-36 | The coolant table missed an exact solve by up to x3 | 2026-09-27 | D-362, D-363 |
| L-38 | In ionized gas the chemistry's atoms replaced CHIANTI's electron data | 2026-09-27 | D-362, D-363 |
| L-39 | The field beyond the front carried a grid-direction pattern | 2026-09-27 | D-365, D-366 |
| L-40 | The H II region was not converged, and the test did not see it | 2026-10-04 | D-365, D-391, D-392 |
| L-41 | The reported Hbeta was 5% low | 2026-09-27 | D-370, D-371 |
| L-42 | Lya was carried as an 8.15 um line | 2026-09-27 | D-372, D-376 |
| L-44 | The Cloudy references had no microturbulence | 2026-10-05 | D-396 |
| L-45 | The shielding columns were sampled, not integrated | 2026-10-09 | D-397, D-398 |
| L-49 | The damping across iterations, now off by default | 2026-10-14 | D-405, D-406 |
| L-61 | Levels listed out of energy order broke the collision rates | 2026-10-17 | D-418 |
| L-62 | The mean dust temperature averaged empty size bins at T = 0 | 2026-10-16 | D-414 |

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

**L-4. O-14: the 3D self-shielding tracer has four named defects, two of them
active on both production fixtures** (D-259, re-read in D-339).

O-14 verbatim: *"No reflection at mirror walls, slab rays truncated at 59% of
depth, isotropic chi/12 weighting of a one-sided field, HEALPix rings about z."*

What MOCASSIN ran was `computeRayColumns` (D-190; removed in D-348 - the
paragraphs down to "Progress" describe it as it was) - twelve HEALPix nside=1
directions per cell per MC iteration, walked through the real grid. The
vendored 3D-PDR tracer (`calc_columndens`/`raytheia`) is **dead in
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

The column rescale between chemistry passes compounded
(`col0*(a1/a0)*(a2/a0)`); deleted at D-354 (L-25).

**CLOSED 2026-09-26 (D-340, D-341, D-348, D-350), recorded at D-431.** Of
O-14's four defects, the missing mirror reflection is fixed (D-340), the slab
truncation and the isotropic `chi/12` weighting went with `computeRayColumns`
(D-348), and the overshoot of D-348's band integral was corrected by L-24
(D-350). The fourth, the HEALPix rings about z, is L-53 (open). What else
remains open is the formal solution's shortfall: section 3, L-4.

**L-9. Gas-grain collisional coupling omits H2**, which is 94% of this gas -
the loop runs over atomic elements and ionisation stages only. Measured 68x
weaker than Cloudy's dust cooling at A_V 0.65, so 4.9e-5 of the budget against
Cloudy's 1.3e-3: negligible at n_H = 1e3, decisive at high density (D-305).
Since D-352 the grain side of the exchange uses the same MOCASSIN term. D-093's
substitution of 3D-PDR's heat(11), computed on a fixed 0.1 um grain population,
is gone, so gas and grain now agree on the energy they exchange, H2 omitted
on both sides.
**CLOSED 2026-10-19 (D-420, D-421).** H2 is a collider on both sides
(D-420, ce32641): n(H2) from the chemistry, BFM's accommodation at the H2
mass. In the K1a cores the coupling rose x4.83. Then the 4 pi that both
sums were divided by is gone (D-421, 0568eb0): the gas side is left
physical per H, and the grain side is divided by pi, its balance's units.
The cold-cell coupling is now 1.08-1.20 of BFM's rate, from 0.0175 in K1a
before both fixes.
  - The K1a cold cores warm from 3.84 / 6.55 K (coldest) to 6.41 / 12.50 K,
    still well below the dust (16-25 K).
  - The ionized gas of every dusty model is 2-3.5% cooler.
  - The other benchmarks, pn150k among them, are not rerun.
**Rerun on pn150k at D-429** (the release check, with the H2 level model):
ionized T_e x0.996, the gas-grain share of the ionized gas's cooling
1.2e-3 -> 1.5e-2, and its one cold-core cell from 21.5 K to the dust's 24.4 K.

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

**Update 2026-10-04 (D-393): the licensing test is done and passes, after a
defect it found.** A warm start counts its iterations from 1, so with the
fixtures' `pdrStartIter 4` it skipped the chemistry for three iterations and
then seeded the molecules over the resumed ones (the resume above ran fewer
iterations than that). A checkpoint with PDR state now resumes from the first
iteration, unseeded. 8 cold + 8 warm against 16 cold, hiipdr 21^3: integrated
quantities within 0.33% (seed-to-seed 1.15%), Hbeta 0.04% (0.07%), worst line
0.55% (0.71%). The four arrays above are still not in the checkpoint; the one
iteration without them leaves no trace after eight. On h2-model the level
populations are resumed too (DEVLOG-H2 H-020).
**CLOSED 2026-10-04 (D-393), recorded at D-431.** The licensing test passes.
The four arrays not in the checkpoint leave no trace after eight iterations,
and that is accepted.

**L-18.** The Q-file path was unusable before D-313 (double allocation, and no
photoelectric yield). Fixed, but it means **no historical result used it**,
and it has only the coverage D-313 gave it.
**CLOSED 2026-10-15 (D-413), recorded at D-431.** The Q-file path has run in
every pn150k model since D-313 (`grph-avg.cat`, six columns). D-413 found that
every five-column Q file had failed at start-up since D-313: the test for the
optional Im(m) column read six values list-directed, which takes the sixth
from the next record, so Draine's PAHneu_30, Car_90, Sil_21 and suvSil_81 lost
a record and ran off the end. The columns of the first data record are now
counted, and the log says what each Q file holds. test_Problem's astrosilicate
+ PAH mixture runs on it (DEVLOG-H2 H-036).

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
**CLOSED 2026-09-28 (D-383), recorded at D-431.** `mocassinPlot` has run on PDR
grids: D-383's line cubes reproduce `lineFluxMol.out` (CO) and `lineFlux.out`
(Hbeta, [O I] 6300) to 1e-5 on pn150k and hiipdr, and DEVLOG-H2 H-039 takes
Hbeta per cell from it.

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
what they resolved. **CLOSED 2026-09-22 (D-319, D-320, D-322)** for these five. The general risk
is recorded with the one tool that still carries it: section 3, L-21.

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
**CLOSED 2026-09-22 (D-326, D-328), recorded at D-431.** The cause is named and
fixed, and the warm half of the crossover is closed to 7% and 1.4%. The deep
gas's remaining deficit against Cloudy moves with the packet count, and is
carried by L-3 (D-408: A_V 2.5 from 11.2 to 16.9 K at 64x, Cloudy 19.3).

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
**CLOSED 2026-09-26 (D-350)** in the 3D flavour. The 1D flavour keeps the
prescription and is out of scope (L-11).

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
the pre-rescale `[D220]` line. D-404 found what that line measures: the
first solve of `ionBalance` normalises the stages to the molecular content
the chemistry handed back an iteration earlier, so the stages it leaves sum
to 1 - 2x(H2) of the iteration before - off 1 by more than 1% in 19.9% of
hiipdr's cells and 57.6% of pn150k's at their last iterations. A second
solve after the chemistry is normalised to that iteration's own content,
and with it in the first's place (kept at the last iteration, D-404) the
sum holds before the rescale: no cell off by 1% on either. In the
iterations before the last the rescale still does the work.
**CLOSED 2026-10-13 (D-404), recorded at D-431.** In the written model the sum
now holds un-enforced. That the iterations before the last still rest on the
rescale is L-47's open item.

**L-30 (resolved part). `teFloor` bound the coldest gas from D-402 until its
default moved to the CMB** (D-402, D-403). `teFloor` holds MOCASSIN's T at 10
K or above. The coldest hiipdr cell is 10.9 K. **It binds since D-402
(2026-10-10)**: with the two solvers on one ion balance the chemistry's deep
heating is 10% lower, hiipdr's outer shell (A_V 2.7-3.0, 1,548 cells, a tenth
of the grid) wants 9.5-10.0 K, and a cell on the floor is flagged and left out
of every line - [C I] 609 16% low, CO 1-0 to 3-2 19-25% low for that alone.
With `teFloor 2.725` in the input no cell is flagged and the temperature
balance is reached everywhere. The floor had also been holding 29-39% of the
cells at iterations 2-4 of every earlier run. **Since D-403 (2026-10-10, the
user's decision) the default is 2.725 K**, the constant `TcmbK` from which the
chemistry's grain floor is also made; hiipdr run with no keyword gives what
`teFloor 2.725` gave. The clamp no longer binds on either fixture (coldest
cells 9.47 and 21.6 K).
**CLOSED 2026-10-11 (D-403).** The two clamps still open are in section 3,
L-30.

**L-31. CLOSED 2026-09-26 (D-358). The chemistry solved H II gas as neutral**
(D-356). Inside the solve the linked ions recombined with no photoionization,
so an H II cell integrated to x(H) = 1, x(H+) = 1e-3, x_e = 1e-3 of MOCASSIN's.
The molecules were formed there, and MOCASSIN re-imposed only the atoms
afterwards: two x(H+) in one cell. Ionized-zone H2 was 1e4-1e5x Cloudy's and
CO up to 1e14x. The solve now runs on MOCASSIN's own photoionization and
recombination rates for H, He, C, O, Mg and MOCASSIN's H2 photoionization,
through the network's first-order slots. Ionized-zone H2 is now 5-71x Cloudy's
and destroyed the way Cloudy's is. Nothing past the fronts moved.

**L-32. CLOSED 2026-10-10 (D-402). One ion carrier per element** (D-358). The
network has O+ for all of
O++-O6+ and C+ for C++-C4+. Each carrier takes chemistry its true stages do
not have: charge exchange into the neutral, and C+ + OH -> CO. In pn150k's
20 kK zone the solver's neutral O is 5.4 dex above MOCASSIN's, and CO, OH and
HCO+ run 3e7x, 630x and 1e12x Cloudy's at 0.03 pc, falling outward. Where the
carrier is the true stage (hiipdr) it does not show.
Each network ion is now its own stage (X+ is stage 2), `elemAvail` is counted
from the molecules' own atoms, and the solve is given the electrons the
network has no species for (it had run 3-4.5% short of MOCASSIN's through
pn150k's PDR, 7% in the He2+ zone). In ionized cells the two solvers agree
to 0.01 dex in all five linked elements on both fixtures. pn150k at 0.03 pc:
CO from 8.5e7 times Cloudy's to 16, OH from 840 to 0.09, CH from 220 to
0.15, HCO+ to zero. Ionized-zone H2 is unchanged (17-19 times Cloudy's,
L-43).

**L-33. Grain H2 formation 5-25x Cloudy's** per n_H n(H), at every depth
compared on both fixtures (D-356, D-358). MOCASSIN's coefficient is near the
classic 3e-17 cm^3 s^-1; Cloudy's is not. Not decomposed: sticking, grain
temperature, per-size efficiency.
**CLOSED 2026-10-05 (D-394): a measurement error.** Cloudy forms 94-95% of its
grain H2 as H2* (`grn,H,H=>grn,H2*`), and the comparison read only the ground
channel. With both, MOCASSIN's coefficient is 0.86-1.00 of Cloudy's on pn150k
(graphite) and 0.50-0.91 on hiipdr (silicate) through the PDR. The silicate
residual is the Cazaux & Tielens surface energies (3D-PDR's per-material set
against Cloudy's single one: 0.45-0.70 at T_d 26-37 K), with MOCASSIN's colder
gas (0.79-1.03); reported, not tuned.

**L-34. CLOSED 2026-10-10 (D-402), with the residual in L-47. The PDR's H+ has
channels MOCASSIN's ion balance lacks** (O-05; D-358).
These are H2 + CRP -> H+ + e + H and He+ + H2 -> He + H+ + H. The solver's
x(H+) is up to 4x MOCASSIN's at A_V 1.8-2.8 on hiipdr, and He+ 0.25-0.5x. The
re-imposition keeps MOCASSIN's. D-193 stopped injecting the chemistry's
source and sink terms into `ionBalance` because they double-counted the
molecular drain. Carrying these channels without that needs a decision of
its own. D-401 (2026-10-10): every run log prints the size of it for H and O
(`[D358]`: on pn150k the solver's O+/O is more than 2x from MOCASSIN's in
78.5% of the cells, H+/H in 44.8%; hiipdr 85.9% and 79.6%), and chlorine is
the same case at full strength - MOCASSIN's balance holds it 99.8% ionized
at A_V 0.30 where Cloudy has 11.9%, because Cl+ + H2 is 1e4 times
recombination and `ionBalance` does not have it. The user's rule for
chlorine is one x(Cl+), so this decision comes before L-46.
D-402 took it: every channel of the neutral/first-ion balance is in both
solvers, each computed once. Photoionization, collisional ionization and
recombination are MOCASSIN's and handed to the solve (D-358); cosmic rays
and charge transfer with H use the network's coefficients in `ionBalance`;
every other reaction is classified by what it does to X and X+ and handed to
`ionBalance`'s rates and matrix, the stages still summing to `elemAvail`
(the classified channels reproduce the right-hand side's totals to 7e-16).
Hydrogen takes only the NET of its charge exchange with the metals: carrying
both directions made the H-O pair cycle and `updateCell` stop converging in
14% of hiipdr's cells (the first version, withdrawn). Cells more than 2x
apart: hiipdr H 79.6% -> 0.5%, O 85.9% -> 0.6% (Mg 9.2%); pn150k H 44.8% ->
0.7%, O 78.5% -> 0.6%. MOCASSIN's own ions moved toward Cloudy's: on hiipdr
H+ past A_V 1.5 from 0.18-0.61 of Cloudy's to 0.60-1.37, He+ from 1.7-13x to
0.9-3.9x, O+ deep from 180-490x to 2-4.5x; on pn150k H+ past r 0.33 pc from
0.26-0.66 to 0.54-0.92 and He+ past 0.37 from 2.3-4.0x to 0.9-1.6x. The
chemistry's deep heating on hiipdr fell 10%: it had been computed with He+
re-imposed at 1.9-3.3 times the value the network held.

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
**CLOSED 2026-09-27 (D-363), recorded at D-431.** CO is the only coolant still
tabulated, at a per-cell mean |ln| of 0.02 (hiipdr) and 0.004 (pn150k); not
pursued further.

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
The escape probabilities' flaw it kept (L-27) was closed at D-377.

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
**D-405: the relaxation is geometric and the 2% stop does not wait for it.**
At the iteration the test stops hiipdr (15), the hydrogen emission measure
is still falling by 0.14% per iteration without the damping and 0.24% with
it, successive steps in the ratio 0.72 and 0.76; carried on as geometric
series the two arms have 0.36% and 0.77% still to go *(extrapolation)*. On
pn150k the ionized gas's temperature rises with ratio 0.6 (0.73 damped) and
He+ still falls 0.1-0.2% per iteration at 18. What sets a ratio of 0.6-0.7
per iteration is not known; the damping makes it 0.73-0.76.
pn150k at 81^3 (D-368) stopped itself at 94% converged cells with its He2+
front still moving outward 0.003 pc per iteration (0.0799 pc against 0.0833 at
41^3 and Cloudy's 0.0880), taking He II 4686 11% low. The per-cell test covers
x(H0), x(H2) and T_e but no helium stage (D-370; this line said "x(H0) only"
until then).

**Update 2026-10-04 (D-391, D-392): the convergence test now sees this.** Its
x(H2) half had passed every cell since D-216 (it ran before the chemistry and
compared each cell with a copy of itself), and it counts cells, of which the
ionized gas is ~1%. A model-integrated test - the emission measure of every
ion stage, the H0/H2/CO contents, the gas temperature weighted three ways -
now decides the stop, at `convTotals` (default 2%) over 3 iterations, and every
run says whether it converged. Measured over 20 snapshotted iterations:
hiipdr's spectrum is up to 8% from its iteration-20 value at 11 and the test
passes at 15; pn150k's He II 4686 is 15% low at 9 and the test passes at 17,
its He2+ front then within 0.5% of Cloudy's.
**CLOSED 2026-10-04 (D-391, D-392), recorded at D-431.** The integrated test
sees the H II region and decides the stop. What a 2% stop still leaves of the
relaxation (D-405) is carried by L-52.

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
The transport's own copy of the H I emissivities is L-63 (open).

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

**L-44. The Cloudy references had no microturbulence** (D-396). MOCASSIN and
3D-PDR run with 1 km/s (`pdrVturb`, `v_turb`); Cloudy's lines were thermal
only, so it shielded H2 and trapped its coolant lines with widths 2-4.5x
narrower, and hiipdr's reference used the small H2 model's fitted shielding.
**CLOSED 2026-10-05 (D-396):** both references carry `turbulence 1 km/s` and
hiipdr's the large H2 model. hiipdr's crossing gap falls from 0.31 to 0.12
mag; Cloudy's PDR is 2-15% colder. The hiipdr, pn150k and H2 pages were
rebuilt on the new references on 2026-10-09 (D-398); the fine-grid page was
not.

**L-45. The shielding columns were sampled, not integrated** (D-397, D-398).
Every ray march took the nearest cell once per step of a cell width, starting
half a step from the target's centre, so the part of the neighbouring cell
between the target's face and the end of the first step was never counted:
the star-ward N(H2) was a median 0.46-0.75 of the exact one through hiipdr's
H2 transition and 0.64-0.82 through pn150k's. A scattering site's first leg
also stopped at the near face of the site's cell. A_V was sampled the same
way (hiipdr's axis read 0.03 mag shallow, pn150k's 0.007).
**CLOSED 2026-10-09 (D-397, D-398):** `rayCells` gives the exact length of a
ray in each cell and carries A_V, the H2/C/CO columns, the scattering sites
and the line escape rays; a site's first leg runs to the site. Measured on
the h2-model branch (seeded pairs): hiipdr's H/H2 crossing moves 0.25 pc
towards the star and reads A_V 1.396 against Cloudy's 1.280 on the corrected
axis; pn150k's moves 0.007 pc and reads 0.393 against 0.368. The H2 lines
fall 3-8%. Not measured on the production branch's own runs.
Since v2.0 the production code is the code these pairs ran on (D-429).

**L-49. The damping across iterations no longer holds back a cycle, and it
has a cost: off by default since D-406** (D-405, D-406; asked for by the
user on 2026-10-11, measured on 2026-10-13, decided by the user on
2026-10-14). `iterDamp` 0.25 mixes a quarter of
the previous iteration's value into the temperature (D-174) and, since D-200,
into the molecular abundances and the ion stages; n_e is not damped. It was
put in against D-173's limit cycle, 44-76% of the cells crossing a branch
boundary at every iteration. Seeded pairs, `iterDamp 0` against 0.25 with
the same executable (h2-model), input and seed, on hiipdr 31^3 (15
iterations) and pn150k 41^3 (18), every iteration's cells kept
(`tools/d405_damp/`):
  - **no cycle.** Cells going from cold to above 3,000 K: none or one per
    iteration on hiipdr, 10-33 of 35,384 on pn150k, in either arm. Cell by
    cell the changes are independent draws (the change over two iterations
    as large as over one, successive changes anticorrelated at -0.5; a
    cycle gives 0 and -1), no more cells have a cycle's signature than
    chance gives, and the molecular fraction's large steps are single
    excursions in different cells (L-51);
  - **what moves is Monte Carlo noise.** Steps of the written model 1.39
    (hiipdr) and 1.48 (pn150k) of the damped arm's, against 1.49 for
    independent noise through such a blend; the spread among cells that the
    octant's symmetry makes one cell 1.2-1.4 (1.29); n_e, never damped,
    1.0. At four times the packets (hiipdr, undamped) every spread and step
    before the carbon turn is at 0.46-0.64 of its value (packet noise gives
    0.5; T at A_V 1.48-1.91 from 4.9% to 2.4%), the histories are independent
    draws again, and no cell goes from cold to hot at any iteration;
  - **the damping is a filter on the output.** With the damping taken out
    of the damped run's own history (solve = (written - 0.25 before) /
    0.75) its solves are the undamped run's: the same two carbon states in
    the same shares to a percentage point (L-26), the same statistics. The
    solves are equilibrium solves and keep no memory of their start;
  - **the damped arm trails.** By three iterations on hiipdr (EM(H+)) and
    five to six on pn150k (n(H2), T(em)). The 2% stop falls at 15 in both
    hiipdr arms and at 17 damped against 15 undamped on pn150k. Hbeta is
    0.55% and 0.25% lower without the damping, which is the ionized gas
    further along (L-40), not another solution; pn150k's ultraviolet lines
    of highest excitation are up to 2.7% higher for the same reason;
  - **on h2-model the damping derails the chemistry's second and third
    iterations**: temperature balance not reached in 89 and 79% of hiipdr's
    cells and 72 and 25% of pn150k's, in none without. The same pair on the
    production executable, which has no level model, has none with or without
    the damping (the damped arm carries the same remnant of the starting
    temperature, a median 140 K against 11 K after the chemistry's first
    iteration, and reaches its balance in every cell from the fifth
    iteration): the derailment needs the damping and H-013's heating term
    together, the term being computed at the written temperature. In
    everything else the production pair repeats h2-model's (no cell flips,
    steps 1.41, the two carbon states, [C I] 370 um 10.4% above its own solve
    damped and 1.7% below undamped; the 2% stop at 14 undamped, not by 15
    damped);
  - **without it the written model is its solution.** Neutral cells whose
    written X+/X is more than 10% from the solver's: hiipdr H 13.4, He 8.5,
    C 32.1, O 18.7, Mg 18.1 damped and 0.0, 0.0, 0.0, 9.9 (L-50), 0.0
    undamped; pn150k 6.4, 9.1, 14.1, 18.6, 0.7 and none;
  - **where a cell's answer has two values the blend writes states no solve
    gave.** Past A_V 2 hiipdr's carbon is two states (L-26); the damped
    model writes cells at 0.37 and 0.77 of C+ over carbon, the blends of
    0.166 and 0.965, at blended temperatures (12.4 and 19.9 K give 14.2 and
    18.0), and emits 4.5% more [C I] 609 um and 11.6% more [C I] 370 um
    than its own last solve (the undamped model 0.4% more and 1.5% less).
    **Every published hiipdr [C I] value carries that.** Medians of n(C)
    at the turn are 1.9 times the undamped model's with the sums equal to
    1%. pn150k has no carbon turn and no excess.
What the damping still bought: 0.77 of the cell-to-cell scatter in the
written model, and a quieter T(H0) in the stop test (L-52). **Decided
(D-406, the user): the default is 0**; `iterDamp 0.25` in an input gives
the old blend. With the new default and no `iterDamp` line, production's
hiipdr is D-405's undamped run byte for byte, and the published models are
the undamped runs. On the way, the restore's rounding of H2den, which D-363
had matched to the damping step's, gave back an undamped run's [C I] 609 um
1.1e-7 off; every writer now rounds as `pdrStep` does. **Open:** whether
the noise should be met by averaging the field over iterations where the
damping averaged the solves (L-26). Not run: the slabs and `ifront`,
denser models, pn150k on the production executable, a second seed.
**CLOSED 2026-10-14 (D-406), recorded at D-431.** The open question it leaves,
averaging the field over iterations, is L-26's. Of its "not run" list, pn150k
has since run on the production executable without damping (D-429).

**L-61. Levels listed out of energy order broke the collision rates, and
below 13.96 K made NaN** (D-418). `equilibrium` (emission_mod.f90) took the
lower index of each level pair as the lower level. 31 data files list levels
out of energy order. niII.dat has 4F9/2 (8393.9 cm^-1) as level 2 and 2D3/2
(1506.9 cm^-1) as level 3, so the 2-3 rates had detailed balance reversed at
every T (x2.7 at 1e4 K), and below 13.96 K exp(+9909/T) overflowed: NaN
populations, cooling and T_e, then NaN grain charge and chemistry and a crash
(found by the NGC 7009 K1a filtered-star run).
**CLOSED 2026-10-17 (D-418).** The Boltzmann factor and the statistical weight
of the excitation go with the lower-energy level of each pair. A starvation
test that had failed at 12 K runs to the end with no NaN. In the warm K1a
bare-star model every line moved by under 0.1% (median 0.04%). Models whose gas
spends time below ~100 K with Ni II, Fe III or Ca VII populated are not
measured.

**L-62. The mean dust temperature averaged empty size bins in at T = 0**
(D-414). `getDustT` summed each species' T over its own size range against
`grainWeight` normalised over the whole grid, so a species covering part of
the grid put the empty bins in at T = 0. test_Problem's silicates alone
(0.07-50 um on a 1e-4 - 5 um grid) came out at 2-8e-6 K and formed no H2 on
grains (DEVLOG-H2 H-035).
**CLOSED 2026-10-16 (D-414).** `Tdust(nS,0)` is renormalised over the species'
bins and `Tdust(0,0)` weights each species by the grains it has. Every consumer
reads it: the chemistry, the level model's H2 formation, the dust-only
convergence test and `pdrRad.out`. It is exact where a species fills the grid,
as in both fixtures (21 of 22 outputs byte-identical, `summary.out` different
only in clock times). What one temperature for both materials still does is
L-54.

### Checks done since they were listed in section 5

  - **hiipdr under the PDR cycle's changes**: done (D-320/D-321,
    `runs/d316-hiipdr`, artifact v10), with the per-cell budget D-304 read on
    pn150k run on hiipdr at D-322.
  - **The warm start, beyond compiling**: done (D-393). A warm continuation
    matches a cold run to within the Monte Carlo scatter (L-14).
  - **The plain flavour against Lexington**: run (D-362). D-360 and D-362 are
    identical on every benchmark quantity. The change from `dev` is not
    attributed (section 5).
  - **A model reaching A_V > 0.7**: `runs/d326-stick` reaches A_V 2.999, and
    L-3 is measured there (D-333).
  - **pn150k on the current code**: run with the production code of v2.0
    (D-429); the comparison pages are not rebuilt (section 5).

---

## 5. What has NOT been checked

Stated explicitly, because absence of a reported problem is not evidence.

  - **The 1D slab fixtures** (`v1slab`, `v2slab`) and `ifront`, at their
    configured sizes, under this cycle's changes (L-11). Note that until D-316
    they *could not have been run at all*: every PDR fixture's `pdrDataDir`
    pointed at a directory left behind by a rename.
  - **The 1D PDR flavour** (`PDR=1` without `PDRGEOM=3D`), beyond compiling.
  - **The published comparison pages on the current code.** hiipdr and pn150k
    have been run with D-420/D-421 and the H2 level model (DEVLOG-H2 H-042;
    D-429). The Cloudy and 3D-PDR comparison pages, and the Cloudy rows of
    section 2, predate D-420/D-421 and have not been rebuilt.
  - **Dense models with the H2 level model.** The only runs above
    n_H ~ 1e4 are the NGC 7009 K1a models, whose H2 rotational lines are not
    converged (L-55).
  - **The plain flavour's Lexington changes since `dev`.** Against the codes
    this branch has 14/8/24/15 lines in range (HII40/HII20/PN150/PN75) where
    `dev` had 16/9/26/16 at D-270. HII40's <T> is 8131 K, now inside the codes'
    range (dev: 8358), and many collisional lines are 10-35% lower than dev's.
    The change has not been attributed across D-280..D-330 (D-362).
  - **Past A_V 2.45 against 3D-PDR.** The vendored 3D-PDR reference stops
    there, while MOCASSIN's C+ is still falling (D-333).
  - **MOCASSIN against the vendored 3D-PDR reference on TEMPERATURE.** Every
    published comparison in this project is against Cloudy. At matched A_V and
    n_H = 100 the PDR runs 0.46-0.65x the reference in T_gas while carrying
    6-10x its FUV field; matched on field instead, 24.4 K against 85.1 K. Not
    a defect claim - the A_V zero points differ and the G0 unit convention has
    not been checked across the two codes - but the check has never been made
    (D-333).
  - **The packet count past 64x** (D-408). On hiipdr CO still moves at
    3.84e8 packets, and where it stops is not measured. Nor is pn150k past
    2.4e7, or a grid larger than 31^3 at these counts. Per cell, CO 1-0 at
    16-19.4 pc scatters by 0.45-0.60 in ln at 16x and 64x, almost all of it
    x(CO), not falling and little of it the same cell by cell in the two
    runs; a CO map carries it as +-17% per pixel pair (D-412).
  - **Cloudy's own charging exponent.** D-304's Lya correction transfers
    MOCASSIN's measured `d ln(PE)/d ln(G0) = 0.42` to Cloudy. A Cloudy run
    with its FUV field cut by the Lya fraction would measure Cloudy's own
    response and remove the assumption.

---

## 6. Reproducing the validation

    # four flavours must all build, and the H2 level model's tests after the 3D one
    for f in "PDR=1 mocassinWarm" mocassin "PDR=1 mocassin" "PDR=1 PDRGEOM=3D all"; do
        make clean && make $f || echo "FAIL $f"
    done
    make h2Test h2Slab || echo "FAIL h2Test h2Slab"

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

    # the H2 level model: X levels against Cloudy's one-zone models (H-003),
    # and a finished run's level-model summary (H-007)
    ~/miniforge3/envs/astro/bin/python tools/h003_compare.py <Cloudy one-zone runs>   # runs h2Test
    ~/miniforge3/envs/astro/bin/python tools/h007_report.py <run>
