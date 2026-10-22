% Data part of the hiipdr benchmark page, included by benchmarks/hiipdr.md.
% Tables: docs/bench/data/hiipdr/*.csv, written by docs/bench/reduce.py (stage A, from the runs).
% Figures: benchmarks/_generated/hiipdr_*.svg, drawn by docs/bench/plots.py (stage B, at build time).
% Definitions of every quantity: docs/bench/data/hiipdr/PROVENANCE.json, "definitions".

```{figure} /benchmarks/_generated/hiipdr_temperatures.svg
:name: fig-hiipdr-temperatures
:alt: Gas and dust temperature of hiipdr against A_V from the star, MOCASSIN-PDR and Cloudy c25.00.
:width: 100%

Gas and dust temperatures against $A_V$ from the star. Solid: MOCASSIN-PDR, the median of the cells in
each $A_V$ bin, with the band between the 16th and 84th percentiles; dashed: Cloudy c25.00, its zones.
The dotted line is the ionization front, the smallest $A_V$ of the cells with $x(\mathrm{H^+}) < 0.3$;
the upper axis is the radius at which the cells have that median $A_V$.
```

```{figure} /benchmarks/_generated/hiipdr_ions.svg
:name: fig-hiipdr-ions
:alt: Ionization fractions of H, He, C and O and the electron density over n_H for hiipdr against A_V.
:width: 100%

The electron density over $n_\mathrm{H}$ and the ionization fractions $n(X^i)/n(X)$ of H, He, C and O,
drawn as in the temperature figure. MOCASSIN's from its own ionization balance
(`grid2.out`), Cloudy's from its overview.
```

```{figure} /benchmarks/_generated/hiipdr_chemistry.svg
:name: fig-hiipdr-chemistry
:alt: Abundances per hydrogen nucleus of H, H2, C, O, CO, OH, H2O, CH, HCO+ and H3+ for hiipdr against A_V.
:width: 100%

Abundances per hydrogen nucleus, $n(i)/n_\mathrm{H}$ with $n_\mathrm{H} = n(\mathrm{H}) + n(\mathrm{H^+})
+ 2n(\mathrm{H_2})$. The atoms are MOCASSIN's, the molecules the chemistry's; Cloudy's $n(\mathrm{H_2})$
counts $\mathrm{H_2}$ and $\mathrm{H_2^*}$.
```

```{figure} /benchmarks/_generated/hiipdr_h2_solomon.svg
:name: fig-hiipdr-h2-solomon
:alt: H2 photodissociation rate per molecule for hiipdr against A_V, MOCASSIN-PDR's level model and Cloudy.
:width: 100%

The $\mathrm{H_2}$ photodissociation rate per molecule: MOCASSIN's from the level model, the rate the
chemistry used (`h2Cells.out`); Cloudy's from its $\mathrm{H_2}$ and $\mathrm{H_2^*}$ photodissociation
rates over $n(\mathrm{H_2}) + n(\mathrm{H_2^*})$.
```

```{figure} /benchmarks/_generated/hiipdr_h2_heating.svg
:name: fig-hiipdr-h2-heating
:alt: H2 heating terms as fractions of MOCASSIN's heating for hiipdr against A_V.
:width: 100%

The $\mathrm{H_2}$ heating terms over MOCASSIN's heating, in the cells where that heating is positive:
the level model's (used; solid, with the percentile band) and 3D-PDR's (kept beside them; dashed). Where
the median of the collisional term is negative, $\mathrm{H_2}$ cools the gas; that part is drawn thin at
its size. This Cloudy model saved no heating.
```

```{csv-table} Line intensities, MOCASSIN-PDR against Cloudy c25.00. H$\beta$ is a luminosity in $10^{36}$ erg/s; every other line is over its own code's H$\beta$; ratio is MOCASSIN over Cloudy. Cloudy's lines are the last iteration's intrinsic block of its listing; its listing has no CO line for this model.
:file: /bench/data/hiipdr/lines.csv
:header-rows: 1
:name: tab-hiipdr-lines
```

```{csv-table} The $\mathrm{H_2}$ lines: Cloudy's 40 strongest of its intrinsic line list (last iteration), matched to MOCASSIN-PDR's lineFluxH2.out by wavelength (air); each over its own code's H$\beta$; ratio is MOCASSIN over Cloudy. Levels are $(v, J)$ of the upper and the lower state.
:file: /bench/data/hiipdr/h2lines.csv
:header-rows: 1
:name: tab-hiipdr-h2lines
```
