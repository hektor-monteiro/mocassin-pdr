(sec:scope)=
# From the radiation field to the molecules

These pages describe how MOCASSIN-PDR's Monte Carlo radiation field sets the molecular content of the gas, from the field and the dust, through the geometry of the rays, the H$_2$ level model and the rates, to the chemistry and its feedback. Each process is linked to the code block that implements it. The physics assumptions are collected in {doc}`assumptions`, and the limitations of this path in {doc}`path-limitations`.

```{toctree}
:maxdepth: 1

iteration
field
dust
geometry
h2-model
photorates
chemistry
feedback
convergence
assumptions
path-limitations
code-index
data
```

## What is described

MOCASSIN-PDR couples three pieces of physics:

1.  **MOCASSIN** {cite:p}`Ercolano2003,Ercolano2005,Ercolano2008`: a three-dimensional Monte Carlo (MC) code for photoionisation and dust radiative transfer on a Cartesian grid of homogeneous cells. It owns the radiation field at every frequency, the dust (optical properties, temperatures, charge), the ionisation state of every element, the electron density and the gas temperature.

2.  **3D-PDR** {cite:p}`Bisbas2012`, vendored under `source/pdr/` (upstream commit `fabcdc6`, imported 2026-08-28; `source/pdr/UPSTREAM.md`): the REDUCED 33-species chemical network solved to steady state, its photoreaction prescriptions, its H$_2$ formation rate and its escape-probability level-population solver for the coolants. 3D-PDR’s own treatment of the radiation field (an external field attenuated along rays to the cloud boundary) and its own thermal balance are not used. MOCASSIN drives the vendored routines through the bridge module {src}`pdr_mod.f90`.

3.  **The H$_2$ level model**, part of the code since release `pdr-coupling-v2.0` ({src}`h2_mod.f90`, driven by `h2LevelModel` in {src}`pdr_mod.f90`): the 302 rovibrational levels of $\mathrm{H_2}\,X$ in statistical equilibrium under collisions, quadrupole decay, ultraviolet pumping through the excited electronic states, Solomon dissociation and formation on grains. It is a re-implementation from the data and the conventions of Cloudy’s large H$_2$ model {cite:p}`Shaw2005,Ferland2017,Chatzikos2023`. Its Solomon rate is the H$_2$ photodissociation rate the chemistry uses.

By *molecular content* we mean the abundances of the 33 species in every cell and, for H$_2$, the populations of its 302 levels. These pages follow the path by which the MC radiation field determines them, and the feedback of the molecules on the field, the ionisation and the temperatures.

The description is of release `pdr-coupling-v2.0`. Code links resolve against the commit the site was built from, shown at the foot of every page; files are under `source/` unless a path says otherwise. DEVLOG entries are cited as D-nnn (`DEVLOG.md`), the H$_2$ model's entries as H-nnn (`DEVLOG-H2.md`) and the known limitations of {doc}`../limitations` as L-nn; {doc}`../../developer/devlog-index` lists their titles. Measured numbers quoted without a log entry are read from the run logs of the two benchmark fixtures: `hiipdr`, an H II region and PDR around a 40 kK star in gas of $n_{\mathrm H}=100$ cm$^{-3}$ with silicate grains on $31^3$ cells, and `pn150k`, a 150 kK planetary nebula with $n_{\mathrm H}=10^3$ cm$^{-3}$ and graphite grains on $41^3$ cells. Both are uniform spheres around one source, computed in one octant (`symmetricXYZ`). These numbers come from the runs `d405-hii31-d0` and `d405-pn41-d0` (2026-10-14), made with the H$_2$ model before the gas–grain exchange was corrected ({devlog}`D-420`, {devlog}`D-421`); they describe the field, the geometry and the rates, which that correction leaves almost unchanged. The current results against Cloudy are on the benchmark pages, {doc}`../../benchmarks/hiipdr` and {doc}`../../benchmarks/pn150k`.

**Build flavour.**
The description is of the ray-traced build, `make PDR=1 PDRGEOM=3D mocassin`, which compiles with the flags

```text
-DPDR -DRAYTHEIA -DRAYTHEIA_MO
-DTHERMALBALANCE -DREDUCED -DH2FORM_CT02 -DCHEMSTEADY -DCHEMRETRY
-DFORCECONVERGENCE -DNGACCEL -DNGCYCLE -DNGRELAX -DILLINOIS -DREBRACKET -DSOBOLEV
```

(see {doc}`../../user-guide/build-flavours`): the first line selects the ray-traced geometry, the others are fixed for every PDR build. Of the fixed flags, `-DREDUCED`, `-DH2FORM_CT02`, `-DCHEMSTEADY`, `-DCHEMRETRY` and `-DSOBOLEV` change what the coupled code computes (the network, the H$_2$ formation rate, the steady-state integration and the escape-probability form); `-DTHERMALBALANCE`, `-DFORCECONVERGENCE`, `-DNGACCEL`, `-DNGCYCLE`, `-DNGRELAX`, `-DILLINOIS` and `-DREBRACKET` act only in 3D-PDR’s own iteration and temperature routines, which the bridge does not call. Two other PDR flavours exist and are not described except where noted: the 1D-slab build (`-DONEDIMENSIONAL`), whose chemistry still receives 3D-PDR’s prescription $\chi_0\,e^{-\gamma A_{V}}$ on twelve rays and in which the level model is a stub that leaves the network’s H$_2$ rate in place ({src}`pdr_mod.f90::h2LevelModel [1d]`); and the warm start (`make PDR=1 mocassinWarm`). The level model also skips plane-parallel illumination and nested grids ({src}`pdr_mod.f90::h2LevelModel@"if (nGrids /= 1 .or. lgPlaneIonization) then"..@"if (taskid == 0) print*, \"! h2LevelModel: one grid and point sources only so far - skipped\""`), so the description applies to one grid illuminated by point sources.

## Notation and units

{numref}`tab:notation` lists the symbols used in more than one section. cgs units are used throughout; frequencies are in rydbergs in the code (1 Ryd $=13.6057$ eV, $\nu_{1\,\mathrm{Ryd}}=3.28984\times10^{15}$ Hz). $J_\nu$ is the angle-averaged specific intensity (the mean intensity), so that $u_\nu=4\pi J_\nu/c$ is the spectral energy density.

:::{list-table} Notation and units.
:name: tab:notation
:header-rows: 1
:widths: 22 73

* - Symbol
  - Meaning
* - $n_{\mathrm H}$
  - density of hydrogen nuclei, `grid%Hden` \[cm$^{-3}$\]
* - $x_i = n_i/n_{\mathrm H}$
  - fractional abundance of species $i$, `grid%pdrAbun` \[dimensionless\]
* - $J_\nu$
  - mean intensity \[erg s$^{-1}$ cm$^{-2}$ Hz$^{-1}$ sr$^{-1}$\]
* - $k$, $\nu_k$, $\Delta\nu_k$
  - index, tabulated frequency and width of a bin of the MC frequency grid (`nuArray`, `widFlx`)
* - $J^{\mathrm{ste}}_k$
  - MC estimator of the *total* field in bin $k$, $4\pi\int_{\mathrm{bin}\,k} J_\nu\,\mathrm{d}\nu$ \[erg s$^{-1}$ cm$^{-2}$\], `grid%Jste`
* - $J^{\mathrm{dif}}_k$
  - the part of $J^{\mathrm{ste}}_k$ carried by scattered or re-emitted packets, `grid%Jdif` \[same units\]
* - $u_{\mathrm{D}}$
  - $8.94\times10^{-14}$ erg cm$^{-3}$, the 6–13.6 eV energy density of the {cite:t}`Draine1978` interstellar field ({src}`constants_mod.f90@"real, parameter :: uDraine = 8.94e-14 ! [erg/cm^3]"`); $c\,u_{\mathrm{D}}=2.68\times10^{-3}$ erg s$^{-1}$ cm$^{-2}$
* - $\chi$
  - band-integrated (6–13.6 eV) field in Draine units, a dimensionless energy density, $\chi = \sum_{k\in\mathrm{FUV}} J^{\mathrm{ste}}_k/(c\,u_{\mathrm{D}})$; $\chi=1$ is $G_0=1.69$ in Habing units of the same band ({ref}`sec:bands`)
* - $\chi_0$
  - geometrically diluted, unattenuated field of the sources, same units (Eq. {eq}`eq:chi`)
* - $\chi_{\mathrm{dir}},\ \chi_{\mathrm{dif}}$
  - direct (never scattered or re-emitted) and diffuse parts of $\chi$
* - $s_{\mathrm D}$
  - share of the Draine field’s 6–13.6 eV energy in the Lyman–Werner (LW) window 11.2–13.6 eV
* - $f_{\mathrm{dir}},\ f_{\mathrm{dif}}$
  - LW window factors of the direct and diffuse parts ({ref}`sec:window`)
* - $\eta_{lu}$
  - photon occupation number at the line $l\to u$, $J_\nu c^2/(2h\nu^3)$ \[dimensionless\]
* - $\kappa^{\mathrm{abs}}_\nu,\ \kappa^{\mathrm{sca}}_\nu$
  - dust absorption and scattering coefficients \[cm$^{-1}$\], `absOpac`, `scaOpac`; $\kappa_V$ their sum at 5500 Å
* - $A_{V}$
  - visual extinction \[mag\]; $1.0857 = 2.5\log_{10}e$ mag per unit optical depth (`magPerTau`)
* - $R_{\mathrm{FUV}}$
  - ratio of the band-mean FUV dust extinction coefficient to $\kappa_V$, per cell ({ref}`sec:dust`)
* - $N_X$
  - column density of species $X$ \[cm$^{-2}$\]; $N_l$ the column of H$_2$ in level $l$
* - $b$
  - Doppler parameter, $b^2 = 2kT/m_{\mathrm{H_2}} + v_{\mathrm{turb}}^2$ \[cm s$^{-1}$\]
* - $\tau_0,\ a$
  - line-centre optical depth and Voigt damping parameter of an H$_2$ line
* - $S(\tau_0,a)$, $W(\tau_0,a)$
  - single-line self-shielding function (profile-weighted transmission of a continuum in a Voigt line) and its integral over $\tau_0$ (curve of growth)
* - $k_{\mathrm{Sol}}$
  - Solomon photodissociation rate per H$_2$ molecule \[s$^{-1}$\], `grid%h2Sol`
* - $R_{\mathrm{f}}$
  - H$_2$ grain formation coefficient \[cm$^3$ s$^{-1}$\]; formation rate per volume $R_{\mathrm f}\,n_{\mathrm H}\,n(\mathrm H)$ \[cm$^{-3}$ s$^{-1}$\]
* - $\zeta$
  - cosmic-ray ionisation rate, `pdrZeta` \[s$^{-1}$\]
* - $T_e$, $T_d$
  - gas (electron) temperature and mean grain temperature \[K\]; $T_{\mathrm{CMB}}=2.725$ K
:::

(sec:ownership)=
## Who owns what
The coupling is designed so that every quantity has a single writer (the project's rule of “one reality per quantity”). {numref}`tab:owner` lists the quantities that lie on the path from the field to the molecules.

:::{list-table} Ownership of the quantities on the path from the radiation field to the molecular content.
:name: tab:owner
:header-rows: 1
:widths: 26 16 25 24

* - Quantity
  - Owner
  - Written in
  - Read by
* - $J_\nu$ in every bin (total and diffuse)
  - MOCASSIN MC
  - `pathSegment`, {src}`photon_mod.f90::energyPacketDriver/pathSegment@"& grid(gP)%Jste(grid(gP)%active(xP,yP,zP),enPacket%nuP) + dlLoc*deltaE(iStar) *(enPacket%weight) / dV"..@"! every PDR run (lgJdifLive), not only under pdrSplitField."`, {src}`photon_mod.f90::energyPacketDriver/pathSegment@"& grid(gP)%Jste(grid(gP)%active(xP,yP,zP),enPacket%nuP) + dS*deltaE(iStar) *(enPacket%weight) / dV"..@"! D-158: same split on the cell-crossing branch."`
  - everything below
* - dust opacity, albedo, $T_d$
  - MOCASSIN
  - {src}`dust_mod.f90`, `getDustT` ({src}`update_mod.f90`)
  - $R_{\mathrm{FUV}}$, H$_2$ formation, level model
* - $T_e$
  - MOCASSIN `thermBalance`
  - {src}`update_mod.f90::updateCell/thermBalance`
  - chemistry, level model
* - ionisation stages of H, He, C, O, Mg (and all other elements), $n_e$
  - MOCASSIN `ionBalance`
  - {src}`update_mod.f90::updateCell/ionBalance`
  - imposed on the chemistry
* - atom photoionisation and recombination rates of H, He, C, O, Mg; H$_2\to$H$_2^+$
  - MOCASSIN
  - {src}`update_mod.f90::updateCell/ionBalance@"! for H, collisional ionization) and the total recombination"..@"grid%pdrPhotRate(cellP, 6) = real(gH2358)"`
  - chemistry (replace network channels)
* - $A_{V}$ and the source-ward columns $N(\mathrm{H_2}), N(\mathrm C), N(\mathrm{CO})$
  - bridge geometry
  - `computeAVradial`, {src}`pdr_mod.f90::computeAVradial`
  - chemistry
* - scattering sites and their two-leg columns
  - bridge geometry
  - `traceDiffuseSites`, {src}`pdr_mod.f90::traceDiffuseSites`
  - chemistry, level model
* - H$_2$ level populations, $k_{\mathrm{Sol}}$, H$_2$ heating
  - level model
  - `h2LevelModel`, {src}`pdr_mod.f90::h2LevelModel`
  - chemistry, thermal balance
* - abundances of the 33 species
  - chemistry
  - `pdrStep`, {src}`pdr_mod.f90::pdrStep`
  - MOCASSIN, level model, columns
* - fraction of each element not in molecules (`elemAvail`)
  - chemistry
  - `setElemAvail`, {src}`pdr_mod.f90::setElemAvail`
  - `ionBalance`
* - $n(\mathrm{H_2})$ for the gas opacity (`H2den`)
  - chemistry
  - {src}`pdr_mod.f90::pdrStep@"grid%H2den(cellP) = real(abun(NH2)*nH) ! D-107"`
  - `addOpacity`
* - cooling by CO
  - chemistry (3D-PDR level populations, tabulated in $T$)
  - `pdrStep`
  - `thermBalance`
* - cooling by C$^+$, C, O
  - MOCASSIN’s own atoms, with the chemistry’s neutral colliders and escape probabilities ({devlog}`D-363`)
  - {src}`emission_mod.f90::equilibrium@"! D-363: ONE ATOM PER ION. For an ion the chemistry also carries (C I,"..@"#endif"`
  - `thermBalance`, line fluxes
* - heating terms MOCASSIN lacks (`pdrHeatXtra`)
  - chemistry and level model
  - {src}`pdr_mod.f90::pdrStep@"call CALC_HEATING(nH, dble(grid%Te(cellP)), Td, chiLoc, dble(pdrVturb)*1.d5, &"..@"& heat(8) + heat(9) + heat(10))"`
  - `thermBalance`
:::

## Overview of the chain

{numref}`fig:chain` shows the chain inside one MC iteration. The field reaches the molecules through five channels: (i) directly, through the photodissociation and photoionisation rates, which read the local MC field ({ref}`sec:field` and {ref}`sec:photorates`); (ii) through the gas temperature, which sets the rate coefficients, the collisional excitation of H$_2$ and, through the thermal speed and the sticking of H atoms, the H$_2$ formation rate; (iii) through the dust temperature, which sets the efficiency of H$_2$ formation on grains ({ref}`sec:Td`); (iv) through MOCASSIN’s ionisation balance, which fixes the C$^+$/C ratio and the electron density the chemistry works with; and (v) through the molecules themselves, whose columns, integrated along the paths the photons took, shield the H$_2$ and CO lines at the next iteration ({ref}`sec:geometry`). The molecules act back on the transfer only through the H$_2$ photoionisation continuum and, indirectly, through the ionisation and energy balances ({ref}`sec:feedback`); no molecular line opacity enters the MC transfer.

:::{figure} chain.svg
:name: fig:chain
:alt: Six boxes connected by downward arrows: MC transfer, dust and geometry, H2 level model, MOCASSIN cell update, chemistry, feedback.

The chain from the radiation field to the molecular content inside one MC iteration $n$ (3D build), in the order of execution. Inputs marked "iteration $n-1$" or with the superscript $(n-1)$ are one iteration old ({ref}`sec:lags`); the lags vanish at a fixed point of the iteration. The steps and their code are listed in {numref}`tab:steps`.
:::
