# Lexington: the photoionisation benchmarks

The four models of the Lexington 2000 workshop {cite:p}`Pequignot2001` test what MOCASSIN does
without dust or chemistry: the transfer of the stellar and diffuse ionising radiation, the
ionisation balance of each element and the thermal balance. Each is a uniform sphere of gas around
a blackbody star: two H II regions and two planetary nebulae. MOCASSIN was first benchmarked on
them by {cite:t}`Ercolano2003`, whose Tables 4–7 list every code's prediction. Those tables are the
reference here.

| Model | Star | $n_{\mathrm H}$ (cm⁻³) | $R_\mathrm{in}$ (cm) | Fixture's `Rout`, `edges` (cm) | Codes' $R_\mathrm{out}$, median (cm) | What it tests |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| HII40 | 40 kK, $Q(\mathrm H^0)=4.26\times10^{49}$ s⁻¹ | 100 | $3.0\times10^{18}$ | $1.46\times10^{19}$, $1.40\times10^{19}$ | $1.46\times10^{19}$ | the standard H II region |
| HII20 | 20 kK, $1.0\times10^{49}$ s⁻¹ | 100 | $3.0\times10^{18}$ | $9.5\times10^{18}$, $9.5\times10^{18}$ | $8.89\times10^{18}$ | low excitation: almost no He⁺ |
| PN150 | 150 kK, $5.4\times10^{47}$ s⁻¹ | 3000 | $1.0\times10^{17}$ | $4.07\times10^{17}$, $3.89\times10^{17}$ | $4.04\times10^{17}$ | a radiation-bounded, high-excitation nebula |
| PN75 | 75 kK, $3.9\times10^{47}$ s⁻¹ | 500 | $1.5\times10^{17}$ | $7.5\times10^{17}$, $7.2\times10^{17}$ | $7.50\times10^{17}$ (given) | a matter-bounded nebula, cut at its outer radius |

The workshop fixes the star, the density, the abundances and the inner radius. The three
radiation-bounded models have no prescribed outer radius: each code ran to its own ionisation front
and reported it as $R_\mathrm{out}$. The fixtures stop the gas at `Rout` and the grid at `edges`
(its half-width along each axis); in HII40 and PN150 that is at the codes' front, in HII20 beyond it.

The inputs are the fixtures in `benchmarks/gas/`, each with `randomSeed 1001` added
(`docs/bench/inputs/lex-*`). Each model is one octant (`symmetricXYZ`) of $13^3$ cells. It starts
with $10^6$ packets per iteration, and `autoPackets` doubles them whenever the share of converged
cells is below 95% and has risen by less than 20% since the previous iteration.

## The reference values

The codes of the workshop are GF (Cloudy), HN (Ion), DP (Nebu), TK (XStar), PH (Harrington's code),
RS (Mappings) and RR (Nebula, H II regions only). Their values were taken from the TeX source of
{cite:t}`Ercolano2003` (arXiv astro-ph/0209378; `docs/bench/lexref.py` checks its checksum) into
`docs/bench/ref/lexington2003.csv`, as printed. That table also holds the paper's MOCASSIN results
(2003, 3-D and 1-D) and its printed median.

**The median and the range used here are those of the independent codes only.** The printed median
includes MOCASSIN 2003's 3-D result: in HII40, [O III] 4959+5007 has the codes' median 2.20, and
2.185 with MOCASSIN's 1.64, which the paper prints as 2.18. Comparing a later MOCASSIN with a median
that contains an earlier one would pull the reference toward the code being tested. So for every row
the median is recomputed from the four to seven codes that predict it, and the range is their lowest
and highest value. The printed median and MOCASSIN 2003 are shown beside them. Where the two medians
differ by more than 5% (33 rows, among them three misprints: PN150 C III] 0.174 for 1.74, PN150 O IV]
2.30 for 0.230, PN75 [S II] 6716+6731 0.0020 for 0.020), the rows are listed below.

::::{dropdown} The rows whose printed median differs from the codes' median by more than 5%
:::{csv-table}
:file: /bench/data/lexington/printed_median_page.csv
:header-rows: 1
:::
::::

## How MOCASSIN-PDR's values are obtained

- **Lines** are summed over a window of wavelengths of one ion in `lineFlux.out` (vacuum
  wavelengths), so a multiplet such as C II] 2325+ counts every component the code writes. The
  windows are in `docs/bench/lexington.toml`, and every transition each one summed is listed in
  `docs/bench/data/lexington/matches.csv`. He I 5876 and He II 4686 come from the recombination-line
  tables.
- **H$\beta$** is the luminosity in `lineFlux.out`, which already counts the whole sphere (eight
  times the computed octant), in the units of each table.
- **$\langle T[N_p N_e]\rangle$** is the electron temperature weighted by $N_e N_p\,dV$
  {cite:p}`Ferland1995`. MOCASSIN writes exactly this as the mean temperature of H⁺ in
  `temperature.out`: each ion's temperature is weighted by $n_e\,n_\mathrm{ion}\,dV$
  ({src}`output_mod.f90::outputGas@"factor1 = TeUsed*NeUsed*HdenUsed*dV"`).
- **$\langle\mathrm{He^+}\rangle/\langle\mathrm{H^+}\rangle$** is defined as
  $(n_{\mathrm H}/n_{\mathrm{He}})\int N_e N_{\mathrm{He^+}}\,dV/\int N_e N_p\,dV$
  {cite:p}`Ferland1995`. `ionratio.out` holds each element's mean fraction in each stage, weighted by
  $n_e\,n_{\mathrm H}\,dV$ ({src}`output_mod.f90::outputGas@"ionDenVol(iAb,elem,ion) / denominatorIon(iAb,elem)"`); the ratio of its
  He⁺ and H⁺ fractions is the definition above, exactly.
- **Not compared:** $T_\mathrm{inner}$, $R_\mathrm{out}$, the Balmer jump
  $\Delta(\mathrm{BC}\ 3645)$ and $\tau(1\,\mathrm{Ryd})$. Each needs a choice the outputs do not fix
  (which cell is the inner edge, where the front is, how the continuum jump is measured, along which
  ray), so a number would measure the choice as much as the code.

## The runs

| | HII40 | HII20 | PN150 | PN75 |
| :--- | :--- | :--- | :--- | :--- |
| Iterations, stopped by the integrated test | 18 | 19 | 20 | 13 |
| Converged cells at the end | 98.8% | 93.0% | 99.8% | 98.9% |
| Packets in the last iteration | $1.6\times10^7$ | $1.6\times10^7$ | $1.6\times10^7$ | $10^6$ |
| Run time, 14 ranks | 29 s | 19 s | 41 s | 14 s |

- **Build.** The plain build (`make mocassin`), as for every earlier Lexington run, at
  `pdr-coupling-v2.0-26-gb9c0fb6`. Its `source/`, `Makefile` and `dataPDR/` differ from the release
  only in comments; `data/` lost two fit files that no code reads ({devlog}`D-435`).
- **Convergence.** Each run stops when the model-integrated quantities change by less than 2% over
  three iterations ({devlog}`D-391`). The fixtures used to stop at 10 iterations (HII20 at 20); under
  that test HII40, PN150 and PN75 then ended unconverged (the last three iterations still moved S⁺
  by 12.7%, O³⁺ by 35.8% and He²⁺ by 5.4%); PN150's lines differed by up to 0.12 dex from the
  converged run, and HII40's [O I] 6300+6363 by 0.16 dex. The cap is now 60 iterations
  ({devlog}`D-437`).
- **What the test does not cover.** It tests an ion only where it carries at least 1% of its element's
  emission measure, and the neutral hydrogen only where it is at least 1% of the hydrogen. At the end
  of these runs it skipped O³⁺ and the neutral gas in HII40, O²⁺, N²⁺ and S³⁺ in HII20, and S⁺ and the
  neutral gas in PN75, so the lines of those ions ([O IV] 25.9 µm, [O I] and [N I] in HII40; [O III]
  and [N III] in HII20; [S II] in PN75) converged only as far as the rest of the model did.
- **Reproducing them.** `docs/bench/lexington.py` reduces the four runs to the tables below
  (`docs/bench/data/lexington/`, with `PROVENANCE.json`); {doc}`index` describes the pipeline.

## Results

```{csv-table} Summary. "Compared" counts the lines and quantities with a prediction from at least two codes; the statistics of MOCASSIN 2003 (the paper's 3-D column) are over the same rows.
:file: /bench/data/lexington/summary_page.csv
:header-rows: 1
:name: tab-lex-summary
```

In every model H$\beta$ is within 2% of the codes' median, $\langle T[N_pN_e]\rangle$ within 2% and
$\langle\mathrm{He^+}\rangle/\langle\mathrm{H^+}\rangle$ within 1.1%. The brightest forbidden lines,
[O III] 4959+5007 in HII40, PN150 and PN75 and [O II] 3726+3729 and [N II] 6548+6584 in HII40, HII20
and PN150, are within 0.06 dex of it. Five values miss the range by less than 1%: H$\beta$ and
[O III] 88 µm in HII40, $\langle T[N_pN_e]\rangle$ in HII20, and [O III] 52 µm and He II 4686 in PN75.

Against MOCASSIN 2003 the current code agrees as well in the H II regions (HII40: 20 values in the
range against 20, median offset 0.035 against 0.039 dex; HII20: 12 against 15, 0.063 against 0.064)
and less well in the planetary nebulae (PN150: 36 against 42, 0.059 against 0.034; PN75: 21 against
27, 0.080 against 0.049). The main departures are discussed after the figures.

### HII40

```{figure} /benchmarks/_generated/lex_HII40.svg
:name: fig-lex-hii40
:alt: Lines and quantities of HII40, MOCASSIN-PDR and MOCASSIN 2003 against the range of the Lexington codes.
:width: 100%

HII40. Each row is $\log_{10}$ of a value over the codes' median: the grey bar spans the codes, the grey
dots are the codes, the open circle is MOCASSIN 2003 (3-D) and the blue diamond MOCASSIN-PDR.
Values beyond $\pm0.6$ dex are drawn at the edge as triangles.
```

::::{dropdown} HII40: every value
:::{csv-table}
:file: /bench/data/lexington/HII40_page.csv
:header-rows: 1
:::
::::

### HII20

```{figure} /benchmarks/_generated/lex_HII20.svg
:name: fig-lex-hii20
:alt: Lines and quantities of HII20 against the range of the Lexington codes.
:width: 100%

HII20, as {numref}`fig-lex-hii40`.
```

::::{dropdown} HII20: every value
:::{csv-table}
:file: /bench/data/lexington/HII20_page.csv
:header-rows: 1
:::
::::

### PN150

```{figure} /benchmarks/_generated/lex_PN150.svg
:name: fig-lex-pn150
:alt: Lines and quantities of PN150 against the range of the Lexington codes.
:width: 100%

PN150, as {numref}`fig-lex-hii40`.
```

::::{dropdown} PN150: every value
:::{csv-table}
:file: /bench/data/lexington/PN150_page.csv
:header-rows: 1
:::
::::

### PN75

```{figure} /benchmarks/_generated/lex_PN75.svg
:name: fig-lex-pn75
:alt: Lines and quantities of PN75 against the range of the Lexington codes.
:width: 100%

PN75, as {numref}`fig-lex-hii40`.
```

::::{dropdown} PN75: every value
:::{csv-table}
:file: /bench/data/lexington/PN75_page.csv
:header-rows: 1
:::
::::

## The main departures

These are the larger and the systematic ones; the tables above list every value.

- **Sulphur sits one stage too high.** [S III] 18.7 µm, 33.6 µm and 9069+9532 are below the codes'
  range in HII40, HII20 and PN75 (0.04–0.16 dex below its lower end), while [S IV] 10.5 µm is above it
  in HII40 (by 1.4%) and PN75: the S²⁺/S³⁺ balance is shifted toward S³⁺. In PN75 MOCASSIN 2003 showed
  the same pattern, all three [S III] lines below the range and [S IV] above it; in HII40 and HII20 it
  had them inside, so there the shift is new. It was already present in the runs of {devlog}`D-376`
  and is not explained; the recombination data of S³⁺ and S²⁺ are the first place to look.
- **C III] 1907+1909 is low** in HII40, PN150 and PN75 (−0.21, −0.09 and −0.23 dex). MOCASSIN 2003 was
  low in HII40 too (0.041 against the codes' 0.060–0.091).
- **HII20's [O I] 6300+6363 is 5.5 times the median** (0.033 against 0.0047–0.008), and its lines of
  doubly ionised oxygen and nitrogen are 0.11–0.17 dex low. HII20's grid reaches past the ionisation
  front (`Rout` $9.5\times10^{18}$ cm against the codes' $8.9\times10^{18}$ cm), so 117 of its cells are
  mostly neutral, and the front, far thinner than the $7.9\times10^{17}$ cm cells, falls inside cells
  that average ionised and neutral gas. [O I] 6300 comes from such partly ionised gas, so its strength
  depends on how those cells average the front; the same effect was measured in the PDR models at {devlog}`D-362`
  (74–92% of [O I] from unresolved front cells, {lim}`L-37`). HII40 and PN150 have no such cells (their
  lowest $x(\mathrm H^+)$ is 0.78 and 0.56), and their [O I] 6300 is inside the range.
- **C II 1335 is 6 to 60 times too weak** in the three models that list it. MOCASSIN-PDR writes the
  collisionally excited multiplet by default (0.0043 of H$\beta$ in HII40). With the
  `recombinationLines` keyword, which the fixtures do not set, it also writes the recombination lines
  of C II from `data/Rcii.dat`, 1335 among them. HII40 run that way ({devlog}`D-437`, same input and
  seed) gives 0.073 more, 0.078 in all, against the codes' median of 0.082; the grid and temperature
  files are byte-identical and `lineFlux.out` only gains the recombination tables. So the shortfall is
  a choice of output, not of physics: the line's recombination part is left out. MOCASSIN 2003's
  values (0.082, 0.103, 0.086) suggest that its runs included it. HII40's value counts as inside the
  range only because TK gives 0.004.
- **N IV] 1487 is high and O IV] 1403 low in both nebulae** (PN150 +0.20 and −0.16 dex, PN75 +0.18
  and −0.24), and PN150's C IV 1549 is high (+0.26).
- **PN150 has no neutral gas.** Its lowest $x(\mathrm H^+)$ is 0.56: the fixture's outer radius,
  $4.07\times10^{17}$ cm, lies at the codes' ionisation front ($3.90$–$4.11\times10^{17}$ cm), so the
  model ends before the neutral zone where [O I] 63 µm and [N I] 5200 form. [O I] 63 µm is 0.0010
  against 0.007–0.049 (MOCASSIN 2003: 0.010) and [N I] at the bottom of the
  range. This is a property of the fixture; a run with the gas extended past the front would test the
  code.
- **Si II] 2335+** is twice the codes' value in both nebulae (PN150 0.33 against 0.13–0.20, PN75 0.013
  against 0.001–0.0078). The window sums all five components of the intercombination multiplet the
  code writes (`matches.csv`); the 2335.1 and 2335.3 Å pair alone gives 0.18 and 0.0066, inside the
  range and close to MOCASSIN 2003 (0.16 and 0.0062), which suggests that "2335+" in the tables means
  that pair. [Si II] 34.8 µm, from the same ion, agrees with MOCASSIN 2003 (0.25 and 0.057).
- **Mg II 2798 in PN150** is 2.5 against a median of 1.04, but the codes disagree by two orders of
  magnitude here (0.023–2.22); GF and HN give 2.22 and 2.10, and MOCASSIN 2003 gave 2.32.

Earlier runs of these models with this code base are in {devlog}`D-270` (the upstream `dev` branch),
{devlog}`D-362` and {devlog}`D-376`; {devlog}`D-371` brought H$\beta$ inside the codes' range by taking
it from the Storey & Hummer table. All of them stopped on the share of converged cells, before the
integrated test of {devlog}`D-391`.
