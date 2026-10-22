(sec:dust)=
# Dust quantities seen by the chemistry and the level model
MOCASSIN computes the dust absorption and scattering coefficients $\kappa^{\mathrm{abs}}_\nu$, $\kappa^{\mathrm{sca}}_\nu$ \[cm$^{-1}$\] and the asymmetry parameter $g_\nu$ of every cell from the grain species and the size distribution of the input {cite:p}`Ercolano2005`: per-grain cross sections from Mie theory on optical constants {cite:p}`BohrenHuffman1983` or from tabulated efficiencies, weighted by each species’ number abundance and the size distribution and multiplied by the grain number density $N_d$ that follows from the dust-to-gas mass ratio (`doc/dust.md`). It also solves the radiative-equilibrium temperature of every species and size in every cell from the local MC field. The bridge derives from these, per cell, the quantities below. None is an input parameter: they follow the model’s own grains (`CLAUDE.md`, “no hardcoded values”). {numref}`tab:dustfix` gives their values on the two fixtures.

:::{list-table} Dust quantities measured on the two production fixtures (run logs, lines `[D073]`, `[D109]`, `[D195]`; values at the calibration cell, uniform across each model).
:name: tab:dustfix
:header-rows: 1

* - Quantity
  - `hiipdr` (silicate)
  - `pn150k` (graphite)
* - $A_{V}/N_{\mathrm H}$ \[mag cm$^2$\]
  - $5.18\times10^{-22}$
  - $3.58\times10^{-22}$
* - $N_{\mathrm H}/A_{V}$ \[cm$^{-2}$ mag$^{-1}$\]
  - $1.93\times10^{21}$
  - $2.79\times10^{21}$
* - $R_{\mathrm{FUV}}$
  - 4.31
  - 2.98
* - FUV albedo, energy-weighted over 6–13.6 eV
  - 0.45
  - 0.37
* - FUV asymmetry parameter $g$, scattering-weighted
  - 0.61
  - 0.29
* - grain area per H, silicate / carbonaceous \[cm$^2$\]
  - $1.02\times10^{-21}$ / 0
  - 0 / $5.45\times10^{-22}$
:::

## FUV-to-visual extinction ratio and $A_{V}$ per H

`dustPerCell` ({src}`pdr_mod.f90::dustPerCell`) computes 

```{math}
:label: eq:rfuv
\begin{gather}
  \kappa_V = \kappa^{\mathrm{abs}}_V + \kappa^{\mathrm{sca}}_V,\qquad
  \kappa_{\mathrm{FUV}} = \frac{\sum_{k\in\mathrm{FUV}} w_k\,(\kappa^{\mathrm{abs}}_k+\kappa^{\mathrm{sca}}_k)}{\sum_{k\in\mathrm{FUV}} w_k},
  \nonumber\\
  R_{\mathrm{FUV}}= \frac{\kappa_{\mathrm{FUV}}}{\kappa_V},\qquad
  \frac{A_{V}}{N_{\mathrm H}} = \frac{1.0857\,\kappa_V}{n_{\mathrm H}}\ [\mathrm{mag\,cm^2}],
\end{gather}
```

 stored as `grid%dustRfuv` and `grid%dustAVfac`. The weight $w_k$ is the fraction of source 1’s emitted energy in bin $k$ (the increment of its cumulative distribution), so that $\kappa_{\mathrm{FUV}}$ is the mean extinction coefficient of the band-integrated field as the source emits it; a mean weighted by bin width would over-weight the 912 Å end of the band, where the extinction is steepest. The extinction includes scattering, as in the definition of $A_{V}$, so $e^{-R_{\mathrm{FUV}}\tau_V}$ is the transmission of the source’s FUV beam with every scattered photon counted as lost.

Two approximations limit what $R_{\mathrm{FUV}}$ represents. It is weighted by the spectrum of source 1 for every source, and by the spectrum as emitted, not as it arrives: with depth the field is depleted first at the blue end of the band ({devlog}`D-349`), so the band-mean extinction of the local field is lower than $R_{\mathrm{FUV}}\kappa_V$ and $R_{\mathrm{FUV}}$ overstates it increasingly with depth. In the 3D build $R_{\mathrm{FUV}}$ does not enter any photorate. It enters the combination of the $A_{V}$ of several sources (Eq. {eq}`eq:avradial`, where it cancels for a single source), the grey extinction of the diffuse-site weights ({ref}`sec:sites`), the fallback field $\chi\,e^{-R_{\mathrm{FUV}}A_{V}/1.0857}$ of a cell the MC field did not reach ({src}`pdr_mod.f90::pdrStep@"if (chiLoc <= 0.d0) chiLoc = chi*exp(-av*RfuvL)"`), and the seed.

`calibratePDRdust` ({src}`pdr_mod.f90::calibratePDRdust`) runs once, at the first PDR iteration. From the cell whose $A_{V}/N_{\mathrm H}$ is closest to the density-weighted mean it derives the model-wide fallbacks for cells without dust, `pdrAVfac` and `pdrRfuv`, and 3D-PDR’s `UV_fac` $=R_{\mathrm{FUV}}/1.0857$, which the build does not read (it is used only under `GRAINRECOMB`, which is not compiled; {src}`pdr_mod.f90::pdrStep@"! (UV_fac, the exponent of 3D-PDR's exp(-UV_fac*A_V) prescription, is"`). It reports the energy-weighted FUV albedo and the scattering-weighted asymmetry parameter ({numref}`tab:dustfix`), and ({devlog}`D-108`) overwrites the extinction curve that 3D-PDR’s `XLAMBDA` splines (`X_GRID`, the {cite:t}`SavageMathis1979` table) with this model’s $\kappa(\lambda)/\kappa_V$ at the bin nearest each tabulated wavelength.

**3D-PDR’s grain attenuation factor.**
`SCATTER` ({src}`pdr/shield.F90::SCATTER`) is the fit of {cite:t}`WagenblastHartquist1989`, their eqs. 1a--1d to the attenuation of an FUV field incident on one side of a plane-parallel slab of absorbing and scattering grains, which they derived with the spherical-harmonics method of {cite:t}`Flannery1980` for grains of albedo 0.3 and asymmetry parameter 0.8: 

```{math}
f_g(\tau_\lambda) = \begin{cases}
     e^{-0.7514\,\tau_\lambda}, & \tau_\lambda<1,\\[2pt]
     \sum_{i=1}^{5} a_i\,e^{-k_i\tau_\lambda}, & \tau_\lambda\ge1,
  \end{cases}
  \qquad \tau_\lambda = \frac{A_{V}}{1.086}\,X(\lambda),
```

 with $(a_i)=(2.006,-1.438,0.7364,-0.5076,-0.0592)$, $(k_i)=(0.8490,1.013,1.282,2.005,5.832)$ and $X(\lambda)=\tau_\lambda/\tau_V$ the extinction curve splined by `XLAMBDA`; the two branches agree at $\tau_\lambda=1$ to $2\times10^{-4}$. The field thus falls as $e^{-0.75\tau_\lambda}$ to $e^{-0.85\tau_\lambda}$ rather than $e^{-\tau_\lambda}$, because forward scattering keeps photons in the beam. The MC transfer does this exactly, with the model’s own albedo and phase function, which differ from 0.3 and 0.8 ({numref}`tab:dustfix`). In the 3D build the photorates are evaluated at $A_{V}=0$ ({ref}`sec:rays`), where $f_g=1$, so `SCATTER` matters only for the 1D build, the seed ({ref}`sec:seed`) and diagnostics.

(sec:grainarea)=
## Grain area per H nucleus for H$_2$ formation
The formation rate of {cite:t}`CazauxTielens2002,CazauxTielens2004` ({ref}`sec:formation`) is linear in the geometric grain cross section per H nucleus of each material, for which 3D-PDR ships diffuse-ISM constants ($8.473\times10^{-22}$ and $7.908\times10^{-22}$ cm$^2$ per H for silicate and graphite, {src}`pdr/h2_form.F90::H2_FORMATION_RATE@"TOTAL_CROSS_SECTION=6.273D-22 ! Total mixed grain cross section per H nucleus (cm^-2/nucleus)"`). `measureH2grainArea` ({src}`pdr_mod.f90::measureH2grainArea`) computes instead, once, the mean geometric cross section per grain of each dust component, split by material, 

```{math}
\bar\sigma_{\mathrm{mat}} = \sum_{s\in\mathrm{mat}} X_s \sum_{a=a_{\min,s}}^{a_{\max,s}} \pi a^2\, w(a)
  \quad[\mathrm{cm^2}],
```

 with $X_s$ the number abundance of species $s$ within the component and $w(a)=n(a)\Delta a/\sum n(a)\Delta a$ the number fraction of grains in size bin $a$, normalised over the whole size grid ({src}`ph_mod.f90::makeDustXsec@"! Calculate normalization for distribution weights"..@"print*, '! makeDustXSec : Invalid grain weight ', grainWeight(ai), ai"`) and summed over the species’ own size range. This is the same weighting from which the opacity is built, so the area and the extinction describe the same grains. Species are classified by their label (`isCarbonGrain`, `isSilicateGrain`, {src}`pdr_mod.f90::isCarbonGrain`, {src}`pdr_mod.f90::isSilicateGrain`): carbonaceous if it contains `graph`, `grph`, `amc`, `carb`, `pah`, `sic`, `gr1` or `gr2`, silicate if it contains `sil`, `oliv`, `pyr`, `enst`, `forst`, `quartz` or `oss`; an unrecognised label goes to the silicate channel with a warning. `dustPerCell` then stores per cell $\sigma^{\mathrm{sil}}_{\mathrm H}=(N_d/n_{\mathrm H})\,\bar\sigma_{\mathrm{sil}}$ and $\sigma^{\mathrm{gra}}_{\mathrm H}=(N_d/n_{\mathrm H})\,\bar\sigma_{\mathrm{gra}}$ \[cm$^2$ per H\] (`grid%dustSigSil`, `grid%dustSigGra`); a dust-free cell gets zero, not the upstream constant ({devlog}`D-195`). On the fixtures the area is 1.2 times the upstream silicate constant on `hiipdr` and 0.69 times the graphite one on `pn150k`, each with no grains of the other material ({numref}`tab:dustfix`); the formation rate follows linearly. The geometric area is the right weight for the collision rate of H atoms with grains; the efficiency per unit area is applied at one mean grain temperature ({ref}`sec:Td`).

## Grain albedo in the Lyman–Werner band

Cosmic-ray-induced photoreactions are divided by $1-\omega$ ({ref}`sec:cr`), with $\omega$ the grain albedo at the wavelengths of the H$_2$ Lyman–Werner emission that cosmic rays excite: a photon is then scattered on average $1/(1-\omega)$ times before a grain absorbs it, and can photodissociate or photoionise at each step. Instead of 3D-PDR’s constant $\omega=0.42$ ({src}`pdr_mod.f90::initPDRnetwork@"pdrOmega = 0.42d0"`), each cell uses (`grainAlbedoLW`, {src}`update_mod.f90::grainAlbedoLW`; handed over at {src}`pdr_mod.f90::pdrStep@"pdrOmega = dble(grainAlbedoLW(grid, cellP)) ! D-280"`, {devlog}`D-280`) 

```{math}
\omega = \frac{\sum_{k\in\mathrm{LW}} \kappa^{\mathrm{sca}}_k\,\Delta\nu_k}
                {\sum_{k\in\mathrm{LW}} (\kappa^{\mathrm{abs}}_k+\kappa^{\mathrm{sca}}_k)\,\Delta\nu_k},
```

 an average flat in frequency over the window. MOCASSIN’s own cosmic-ray-induced ionisation of the linked neutrals uses the same $\omega$ ({src}`update_mod.f90::updateCell/ionBalance@"if (lgPDR .and. ion == 1 .and. pdrNcr > 0) then"..@"& * pdrCrGamma(iCr280)/(1.d0 - dble(omega280))"`).

(sec:Td)=
## Dust temperature
MOCASSIN solves the radiative-equilibrium temperature $T_d(s,a)$ of every species $s$ and size $a$ in every cell from the local MC field, by equating the absorbed power (plus the heating by resonance lines and gas collisions, less the photoelectric losses) to $4\pi\int C_{\mathrm{abs}}B_\nu(T_d)\,\mathrm{d}\nu$; stochastic heating is off by default (keyword `quantumHeatGrain`; {lim}`L-8`). The chemistry and the level model use one mean temperature per cell, `Tdust(0,0,cell)`. Since {devlog}`D-414` it is a mean over the grains present: each species' temperatures are averaged over the size bins that hold its grains, and the species are weighted by the grains they have,

$$
T_d(s) = \frac{\sum_{a\in s} w(a)\,T_d(s,a)}{\sum_{a\in s} w(a)},\qquad
T_d = \frac{\sum_s X_s f_s\,T_d(s)}{\sum_s X_s f_s},\qquad f_s=\sum_{a\in s} w(a),
$$

where $a\in s$ runs over the bins within species $s$'s size range and $f_s$ is the share of the size grid's weight in them ({src}`update_mod.f90::updateCell/getDustT@"! find weighted mean"..@"if (sAbF414 > 0.)"`). Where every species fills the size grid, $f_s=1$ and this is the plain number-weighted mean of the earlier code, to the last bit (the species' number abundances $X_s$ summing to one within the component, as the species file is expected to give them). The chemistry floors it at $T_{\mathrm{CMB}}=2.725$ K because MOCASSIN transports no cosmic microwave background ({src}`pdr_mod.f90::pdrStep@"Td = max(dble(grid%Tdust(0,0,cellP)), dble(pdrTcmb))"`; {lim}`L-30`); the level model's formation weights read the unfloored value. Three properties of this mean matter for the molecules:

- it is weighted by grain *number*, which favours the smallest grains, whereas the formation rate is a sum over grains weighted by *area*;

- before {devlog}`D-414` the size weights were those of the whole size grid, so a grid wider than a species' range entered with zero-temperature bins: on `test_Problem`'s silicates (0.07–50 μm grains on a $10^{-4}$–5 μm grid) the mean came out at $(2$–$8)\times10^{-6}$ K and no H$_2$ formed anywhere ({devlog}`H-035`, {lim}`L-62`). The renormalisation above removes this, and changes nothing (byte-identical outputs) where every species fills the grid, as in the benchmark fixtures;

- one efficiency $\epsilon(T_d)$ is applied to the area of all sizes, where the grains have a spread of temperatures; since $\epsilon$ is non-linear, $\epsilon(\langle T_d\rangle)\ne\langle\epsilon(T_d)\rangle$.

The temperature is the second route by which the field acts on H$_2$, and a steep one. Evaluating the efficiency of {ref}`sec:formation` with 3D-PDR’s surface energies: on silicate $\epsilon\approx1$ for $6\lesssim T_d\lesssim15$ K, 0.75 at 25 K, 0.59 at 30 K, 0.37 at 40 K and 0.25 at 50 K; on graphite $\epsilon\approx1$ for $10\lesssim T_d\lesssim40$ K, 0.91 at 50 K and 0.43 at 100 K. Below about 5.5 K (silicate) and 9 K (graphite) $\epsilon$ collapses, because newly formed H$_2$ no longer desorbs (the term $F_1$ of {ref}`sec:formation` exceeds unity); the floor at $T_{\mathrm{CMB}}$ does not prevent this. On `hiipdr` the silicate grains cool from 41 K at the ionisation front to 27 K at $A_V=1$, 21 K at the H/H$_2$ crossing ($A_V=1.39$) and 15 K at $A_V=2.2$ (v2.0 release run). $\mathrm{d}\ln\epsilon/\mathrm{d}\ln T_d$ is $-1.2$ to $-1.7$ at 26–37 K on the lit side and $-0.7$ at the crossing, so a 10% error in $T_d$ is a 12–17% error in the formation rate on the lit side and about 7% at the crossing, and the formation rate sets the depth of the H/H$_2$ transition together with the shielding. The grains of `pn150k` are 0.92–0.93 of Cloudy’s temperature through the PDR ({lim}`L-19`), where graphite’s efficiency is flat.
