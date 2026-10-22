# hiipdr: an H II region and its PDR

`hiipdr` is the H II region and PDR of {cite:t}`Bisbas2015`, §5.4, the model they used
to test TORUS-3DPDR:
- a 40 kK blackbody emitting $Q(\mathrm H^0)=4.26\times10^{49}$ s⁻¹ into a uniform
  sphere of $n_{\mathrm H}=100$ cm⁻³;
- inner radius $3\times10^{18}$ cm, outer radius $6\times10^{19}$ cm;
- silicate grains of 0.01–0.30 μm at a dust-to-gas mass ratio of 0.0113;
- $\zeta=5\times10^{-17}$ s⁻¹.

MOCASSIN-PDR computes one octant on $31^3$ cells, 15,204 of them active. The Cloudy
model is matched on the stellar spectrum and luminosity, the abundances, the grain
material and size range, $A_V/N_{\mathrm H}$ and $\zeta$, with 1 km s⁻¹ turbulence.

The fixture is `benchmarks/pdr/hiipdr`. The run shown is the release run `rel-hii31`
({doc}`index` gives its settings and provenance).

## Results at a glance

| Quantity | MOCASSIN-PDR | Cloudy c25.00 |
| :--- | :--- | :--- |
| Ionisation front (H⁺ = H), $A_V$ / radius | 0.429 / 3.79 pc | 0.446 / 3.76 pc |
| H/H₂ transition (H = 2H₂), $A_V$ / radius | 1.39 / 9.78 pc | 1.28 / 8.95 pc |
| C⁺ = C, $A_V$ | 2.29 | 2.93 |
| Hβ luminosity | 9.30×10³⁶ erg s⁻¹ | 10.02×10³⁶ erg s⁻¹ |

The H II region agrees. The ionisation front is 0.6% farther out in radius, at the same
$A_V$ within 0.02 mag. Hβ is 0.93 of Cloudy's; compared like for like, with the same
emissivity and the H II region's own volume, it is 0.95 ({devlog}`D-371`).

The PDR is where the two codes differ:
- **The H/H₂ transition is deeper,** at $A_V$ 1.39 against 1.28.
  - H₂ forms on the silicates at 0.5–0.9 of Cloudy's rate, set by 3D-PDR's surface
    energies of {cite:t}`CazauxTielens2004` ({lim}`L-33`).
  - The level model shields H₂ with the upper level's total decay rate as the damping
    width, where Cloudy uses each line's own A value. This dissociates more H₂ in the
    line wings ({lim}`L-56`).
- **The C⁺/C transition is shallower,** at $A_V$ 2.29 against 2.93. This is mostly the
  packet count: deep in the cloud few FUV packets reach a cell. With 4, 16 and 64 times
  the packets the transition moves to 2.51, 2.72 and 2.80 ({devlog}`D-408`; {lim}`L-3`,
  {lim}`L-26`).

## Profiles

```{include} _hiipdr_tables.md
```

## Reading the comparison

- **Neutral oxygen lines.** [O I] 63 μm, 145 μm and 6300 Å are 6–11 times Cloudy's.
  They come from the cells the ionisation front crosses. A front cell is thinner than
  needed to resolve the front, so its warm, partly ionised gas fills the whole cell
  volume and makes 92% of the model's [O I] 63 μm ({lim}`L-37`). The `frontLines`
  keyword estimates [O I] 6300 Å with the front resolved inside the cells.
- **Carbon fine-structure lines.**
  - [C II] 158 μm is 1.29 times Cloudy's.
  - [C I] 609 μm and 370 μm are 1.62 and 1.27 times Cloudy's at this packet count. They
    fall towards Cloudy's as the packets increase, with the C⁺/C transition: 1.17 and
    1.10 at 64 times the packets ({devlog}`D-408`).
- **H₂ lines.** Of Cloudy's 40 strongest H₂ lines:
  - the ortho lines (odd $J$) are 0.71–0.80 of Cloudy's;
  - the para lines are 0.95–1.09.

  The ortho/para split comes mostly from the damping width of the pumping lines
  ({lim}`L-56`, {devlog}`H-008`).
- **The PDR's temperature.** The gas is 1.05–1.11 times Cloudy's temperature in the atomic
  PDR ($A_V$ 0.5–1.0) and 0.80–0.89 times it from $A_V$ 1.3 to 2.2, around 30–40 K.
- **The deep gas.** Beyond $A_V\approx2$ few FUV packets reach a cell in one iteration,
  so the temperatures and abundances there carry Monte Carlo noise. The percentile bands
  widen accordingly ({lim}`L-26`).
- **Comparison with standalone 3D-PDR.** The standalone 3D-PDR model of this cloud is
  `benchmarks/pdr/baseline3dpdr/sec54.pdr.fin`. It takes its field from an external
  isotropic illumination attenuated along rays, so it is a reference for the chemistry
  rather than for the coupled model.
