(sec:moc-dust)=
# Dust

MOCASSIN treats grains as a second component of every cell, with their own opacity, temperatures and
emission, carried by the same Monte Carlo packets as the gas's radiation {cite:p}`Ercolano2005`.
This page describes what the code in this repository does with them. The input files and their
formats are in {doc}`../../user-guide/dust-inputs`; the quantities the PDR bridge derives from the
grains ($R_{\mathrm{FUV}}$, $A_V/N_{\mathrm H}$, grain area, albedo, mean temperature) in
{doc}`../pdr/dust`; the test against DUSTY in {doc}`../../benchmarks/dust-1d`; the scattering and
absorption of packets in {doc}`transfer`; and the gas side of the gas–grain terms in {doc}`thermal`.

:::{list-table} The dust of this project's models. The 35-size grids are logarithmic with $n(a)\propto a^{-3.5}$, the slope of {cite:t}`Mathis1977`. No model uses `multiDustChemistry`, `quantumHeatGrain`, `CDE`, `noScattering` or `TDust`.
:name: tab:moc-dustmodels
:header-rows: 1
:widths: 18 44 20 18

* - Model
  - Species, optical data
  - Size grid
  - Amount
* - `hiipdr`
  - astronomical silicate, `astroSilD2003_base.nk` {cite:p}`Draine2003`
  - 35 sizes, 0.01–0.30 µm
  - `MdMg constant`
* - `pn150k`, tutorial
  - graphite, `grph-avg.cat` (Q file averaged over the two axes of {cite:t}`DraineLee1984`)
  - 35 sizes, 0.005–0.25 µm
  - `MdMg constant`
* - `test_Problem`
  - silicate as in `hiipdr` (abundance 0.98, given as 0.07–50 µm, on the grid 0.08–5 µm) and neutral PAH, `PAHneu_30.cat` {cite:p}`LiDraine2001` (0.02, given as $10^{-5}$–0.002 µm, on the grid $10^{-4}$–0.0018 µm)
  - 35 sizes, $10^{-4}$–5 µm
  - `Ndust file`
* - 1D dust shells
  - silicate, `sil-dlee.nk` {cite:p}`DraineLee1984`
  - one size, 0.16 µm
  - `Ndust file`, no gas
:::

The grains are inputs, and so are some limits of the fixtures: the gas is not depleted for what the
grains hold ({lim}`L-5`), `pn150k`'s extinction curve is not a Milky Way curve ({lim}`L-6`) and its
smallest grains get bulk-graphite optics ({lim}`L-10`), and neither PDR fixture has PAHs
({lim}`L-7`).

## Cross sections

{bdg-success}`used`

`makeDustXsec` ({src}`ph_mod.f90::makeDustXsec`) builds the cross sections once, at start-up. The
species file, the first argument of `dustFile`, gives for each species an optical-data file, a
number abundance $X_s$ (used as given, not normalised) and, optionally, the radii $a_{\min,s}$ and
$a_{\max,s}$ it occupies, by default the whole size grid
({src}`the record <ph_mod.f90::makeDustXsec@"read(speciesLine, *, iostat=ios) extinctionFile, grainAbun(icomp, nSpec), &">`).
The data file's second line gives the label, the sublimation temperature $T_{\mathrm{sub},s}$, the
density $\rho_s$, the work function $W_s$ and the mass of a surface atom. The size file, the second
argument, gives radii $a_i$ and $n(a_i)$, from which the number fraction in each bin is
({src}`ph_mod.f90::makeDustXsec@"! Calculate bin size"..@"print*, '! makeDustXSec : Invalid nSizes', nSizes"`)

```{math}
:label: eq:moc-weights
w(a_i) = \frac{n(a_i)\,\Delta a_i}{\sum_j n(a_j)\,\Delta a_j},\qquad
\Delta a_i = \tfrac12\,(a_{i+1}-a_{i-1}),
```

with one-sided differences at the ends and $w=1$ for a single size. The normalisation is over the
whole grid, so a species narrower than the grid holds only part of the weight.

**Optical constants (`nk` files).** $n$ and $k$ are interpolated linearly onto the frequency grid
and keep their end values outside the table. For each size in the species' range, `getQs`
({src}`ph_mod.f90::getQs`) runs `BHmie` ({src}`ph_mod.f90::BHmie`), the Mie code of
{cite:t}`BohrenHuffman1983` with Draine's asymmetry parameter added, and takes
$Q_{\mathrm{abs}}=Q_{\mathrm{ext}}-Q_{\mathrm{sca}}$. The size parameter $2\pi a/\lambda$ is capped
at 100 ({src}`ph_mod.f90::getQs@"if (sizeParam > 100.) sizeParam=100."`), which for a 0.25 µm
grain applies above 5.8 Ryd ({lim}`L-15`). The photoelectric yield table is built from the same $k$
({src}`ph_mod.f90::setGrainYield`; {ref}`sec:moc-dust-charge`).

**Tabulated efficiencies (`Q` files).** $Q_{\mathrm{abs}}$, $Q_{\mathrm{sca}}$ and $g$ are mapped
onto the frequency grid at each tabulated radius, then interpolated linearly in radius; a radius
outside the table takes the nearest tabulated one, with a warning
({src}`ph_mod.f90::makeDustXsec@"! interpolate over the grain size distribution"`). The path could
never run before {devlog}`D-313`, which removed a second allocation of two arrays and skips header
comments until the line with the number of radii parses
({src}`ph_mod.f90::makeDustXsec@"! D-313: skip comment lines until NRAD parses, rather than"`). An
optional sixth column gives Im($m$) for the yield. It is detected by counting the columns of the
first data record ({src}`ph_mod.f90::makeDustXsec@"lgHaveK = (nCol413 >= 6)"`), since the first
test took every five-column file for six ({devlog}`D-413`). Without it, and with photoelectric
heating on, the run stops ({src}`ph_mod.f90::makeDustXsec@"else if (lgPhotoelectric) then"`);
`PAHneu_30.cat` has it since {devlog}`D-415`. Graphite and other anisotropic materials are averaged
over their axes, as cross sections, outside the code by `tools/mkqfile.py`
({devlog}`D-309`–{devlog}`D-313`; {doc}`../../user-guide/dust-inputs`).

**The mixture.** The cross sections are $C=\pi a^2Q$ (cm$^2$). Each species' mean absorption per
grain is $\bar C^{\mathrm{abs}}_s(\nu)=\sum_{a\in s}w(a)\,C^{\mathrm{abs}}_{s,a}(\nu)$. The
scattering uses one asymmetry parameter per frequency for the whole model, weighted since
{devlog}`D-280` by the scattering cross section
({src}`ph_mod.f90::makeDustXsec@"! D-280: the mean scattering cosine of a mixture is"`):

```{math}
:label: eq:moc-g
\langle g\rangle_\nu = \frac{\sum_s X_s\sum_{a\in s} w(a)\,g_{s,a}(\nu)\,C^{\mathrm{sca}}_{s,a}(\nu)}
                             {\sum_s X_s\sum_{a\in s} w(a)\,C^{\mathrm{sca}}_{s,a}(\nu)}.
```

The earlier weighting by area favoured the smallest grains, which scatter nearly isotropically, and
gave `hiipdr` an FUV $g$ of 0.44 where Cloudy has 0.59–0.64.

### Shapes and scattering switches

{bdg-warning}`not exercised`

With `CDE`, a grain whose size parameter is below 1 takes the efficiencies of a continuous
distribution of ellipsoids, with $g=0$
({src}`ph_mod.f90::getQs@"if (sizeParam < 1 .and. lgCDE) then"`; {src}`ph_mod.f90::CDE_efficiency`,
after {cite:t}`Min2003`). `noScattering` zeroes $Q_{\mathrm{sca}}$ in the Mie path only
({src}`ph_mod.f90::getQs@"if (.not.lgDustScattering) Qsca(ai,i)=0."`): species from Q files keep
their scattering ({lim}`L-82`).

## The amount of dust

{bdg-success}`used`

`MdMg`, the dust-to-gas mass ratio (a constant or a per-cell file), is converted by `setMotherGrid`
with the mean grain mass
({src}`grid_mod.f90::setMotherGrid@"grid%Ndust(grid%active(i,j,k)) = gasCell*MdMg(i,j,k)*grid%Hden(grid%active(i,j,k))"..@"& (denominator)"`):

```{math}
:label: eq:moc-ndust
N_d = \frac{(M_d/M_g)\,\mu\,n_{\mathrm H}}
           {\sum_s X_s \sum_{a\in s} \tfrac43\pi a^3\rho_s\, w(a)},\qquad
\mu=\sum_X A_X m_X ,
```

with $\mu$ the gas mass per H nucleus. `MdMh`, the ratio to the hydrogen mass, is converted to
`MdMg`; neither works without gas. `Ndust` gives $N_d$ itself, the only choice for a dust-only
model, and as a file also sets the grid axes
({src}`grid_mod.f90::setMotherGrid@"read(20, *) grid%xAxis(i), grid%yAxis(j), grid%zAxis(k), NdustTemp(i,j,k)"`). `dustMass` rescales every $N_d$ to
a total mass, and is refused with gas and `MdMg` or `MdMh`
({src}`grid_mod.f90::fillGrid@"!BEKS 2010: scale the dust mass here using dustMass keyword."`).
This project uses `MdMg constant` and `Ndust file`; the other forms are not exercised. `readInput`
means to refuse `MdMg` with `Ndust` but tests `MdMh` with `MdMg`
({src}`set_input_mod.f90::readInput@"else if ((lgMdMh .and. lgMdMg) .and. (NdustFile /= \"none\" .or. NdustValue /=0) )then"`),
so the pair passes and `Ndust` is ignored. An `MdMg` file with a constant `Ndust` gives no dust at
all, because the two share one "constant" flag ({lim}`L-75`).

### Several dust components

{bdg-warning}`not exercised`

`multiDustChemistry` names several species files with one shared size file
({src}`set_input_mod.f90::readInput@"case (\"multiDustChemistry\")"`); a fifth column of the `MdMg`
or `Ndust` file assigns each cell its component, whose species the per-cell loops then read. One
quantity stays global: `makeDustXsec` resets $\langle g\rangle_\nu$ inside its loop over components
({src}`ph_mod.f90::makeDustXsec@"gSca = 0."`), so the scattering and the PDR bridge use the last
component's $g$ everywhere ({lim}`L-72`). A segmentation fault on this path, a species index offset
twice, was fixed in {devlog}`D-130`
({src}`update_mod.f90::updateCell/getGrainEmission@"! D-130. isp arrives ALREADY GLOBAL."`).

## Opacity and sublimation

{bdg-success}`used`

`dustDriver` ({src}`dust_mod.f90::dustDriver`) runs once at start-up: it sets every grain to 50 K
except in a warm start ({src}`dust_mod.f90::dustDriver@"grid%Tdust   = 50."`), fills a first
opacity, and tabulates the emission integrals of Eq. {eq}`eq:moc-radeq`. Its sum across ranks goes
through temporary arrays that `MPI_IN_PLACE` would save ({lim}`L-16`). At the start of every
iteration, before any packet is sent, `iterateMC` rebuilds each cell's opacity from the previous
iteration's temperatures and adds it to the gas opacity
({src}`iteration_mod.f90::MCIterationDriver/iterateMC@"if (grid(iG)%Tdust(nS,ai,grid(iG)%active(i,j,k))<TdustSublime(dcp-1+nS)) then"`):

```{math}
:label: eq:moc-kappa
\kappa^{\mathrm{abs,sca}}_\nu = N_d\sum_s X_s \sum_{\substack{a\in s\\ T_d(s,a)<T_{\mathrm{sub},s}}} w(a)\,C^{\mathrm{abs,sca}}_{s,a}(\nu).
```

A grain at or above its sublimation temperature thus leaves the opacity, and the emission too. A
packet that scatters in a cell where no species has its mean temperature below
$T_{\mathrm{sub},s}$ stops the run
({src}`photon_mod.f90::pathSegment@"print*, \"! pathSegment: packet scatters with dust at position where all grains have sublimed -2-.\""`).
At an interaction the packet scatters with probability $\kappa^{\mathrm{sca}}/\kappa$; an
absorption goes to the grains with probability $\kappa^{\mathrm{abs}}/(\kappa-\kappa^{\mathrm{sca}})$,
and they re-emit it from their own spectrum ({devlog}`D-233`;
{src}`photon_mod.f90::pathSegment@"probDust233 = grid(gP)%absOpac(grid(gP)%active(xP,yP,zP),enPacket%nuP)"`).
The absorption and scattering counts printed each iteration are totals since the start of the run
({lim}`L-17`).

### Scattering phase function

{bdg-success}`used`

A scattered packet takes its direction from the Henyey–Greenstein phase function
{cite:p}`HenyeyGreenstein1941` with $g=\langle g\rangle_\nu$
({src}`photon_mod.f90::hg@"hgg = gSca(inpacket%nuP)"`), or isotropically with
`isotropicScattering`. The PDR fixtures use the first; the 1D benchmark runs both. The sampling, its
defect ({lim}`L-73`) and how scattered starlight is counted are in {doc}`transfer`.

(sec:moc-dust-td)=
## Grain temperatures

{bdg-success}`used`

`getDustT` ({src}`update_mod.f90::updateCell/getDustT`) solves the temperature $T_d(s,a)$ of every
species and size in a cell, after the cell's gas temperature search if there is gas. It balances,
per grain,

```{math}
:label: eq:moc-radeq
\sum_k C^{\mathrm{abs}}_{s,a}(\nu_k)\,\frac{J^{\mathrm{ste}}_k}{\pi}
 + \frac{H^{\mathrm{res}}_{s,a}+H^{\mathrm{coll}}_{s,a}-L^{\mathrm{pe}}_{s,a}}{\pi}
 = 4\sum_k C^{\mathrm{abs}}_{s,a}(\nu_k)\,B_{\nu_k}(T_d)\,\Delta\nu_k \equiv E_{s,a}(T_d).
```

$J^{\mathrm{ste}}_k$ is the angle-integrated intensity over bin $k$,
$4\pi\int_{\mathrm{bin}\,k}J_\nu\,d\nu$ (erg cm$^{-2}$ s$^{-1}$; $c$ times the bin's energy density, as in
{doc}`../pdr/field`), equal to $4\pi J_\nu\Delta\nu_k$ ({devlog}`D-290`); outside debug mode it holds every packet, stellar and
diffuse ({src}`photon_mod.f90::pathSegment@"! D-158: Jste holds stellar AND diffuse when lgDebug is"`).
With the radiation alone the balance is therefore
$\int C_{\mathrm{abs}}J_\nu\,d\nu=\int C_{\mathrm{abs}}B_\nu(T_d)\,d\nu$
({src}`update_mod.f90::updateCell/getDustT@"radField = grid%Jste(cellP,:)/Pi"`). The other terms are
powers per grain (erg s$^{-1}$), so the equation is the grain's energy balance divided by $\pi$:
$H^{\mathrm{res}}$ is the heating by resonance lines (below), and $H^{\mathrm{coll}}$ and
$L^{\mathrm{pe}}$, the gas–grain collisions and the photoelectric loss, enter only with gas and
photoelectric heating on
({src}`update_mod.f90::updateCell/getDustT@"dustAbsIntegral = dustAbsIntegral+gasDustColl_d(nS,ai)-&"`;
{ref}`sec:moc-dust-charge`). `dustEmissionInt` ({src}`dust_mod.f90::dustDriver/dustEmissionInt`)
tabulates $E_{s,a}(T)$ once, at $T=1,2,\ldots,3000$ K
({src}`constants_mod.f90@"integer, parameter :: nTemps=3000"`), from `getFlux`'s $B_\nu/h$
({src}`continuum_mod.f90::getFlux@"constant = 0.5250229/hPlanck ! 2*fr1Ryd^3 / c^2 [erg/cm^2]"`)
times $4h$
({src}`dust_mod.f90::dustDriver/dustEmissionInt@"dustEmIntegral = dustEmIntegral*hPlanck*4."`).

The solve locates the left side in the table and interpolates linearly between the two whole
kelvins around it
({src}`update_mod.f90::updateCell/getDustT@"call locate(dustEmIntegral(global_nS,ai,:), dustAbsIntegral, iT)"`).
Above the table the grain is set to 3000 K, above every sublimation temperature in `dustData/` (at
most 2200 K), so it leaves the next opacity. A flat interval, where neighbouring entries have
underflowed to the same value, gives its lower end ({devlog}`D-109`); before this guard one corner
cell of `ifront` reached $2.3\times10^9$ K and lost 16 of its 35 sizes as sublimated. A grain that
absorbs less than it would emit at 1 K is set to 1 K only when `talk` is on
({src}`update_mod.f90::updateCell/getDustT@"if (iT<=0 .and. lgTalk) then"`); otherwise the
flat-interval test reads the element before the start of the table ({lim}`L-81`).

The species mean $T_d(s)$ and the cell mean $T_d$ are means over the size bins that hold grains
({devlog}`D-414`, which closed {lim}`L-62`). The cell mean weights each species by $X_sf_s$, with
$f_s$ the share of the size grid's weight in the species' bins, and is then rescaled by
$\sum_sX_s/\sum_sX_sf_s$, so it comes out as $\sum_sX_s$ times the mean: a true mean only when the
abundances sum to one, as they do in every fixture
({src}`update_mod.f90::updateCell/getDustT@"if (sAbF414 > 0.) grid%Tdust(0,0,cellP) = grid%Tdust(0,0,cellP)*(sAb414/sAbF414)"`;
{lim}`L-89`). {ref}`sec:Td` defines both means and discusses one
temperature for both materials in H$_2$ formation ({lim}`L-54`). In a dust-only model a cell has
converged when its $T_d$ changes by at most `convLimit` between iterations
({src}`update_mod.f90::updateCell@"deltaXHI = (grid%Tdust(0,0,cellP) - XOldHI) / XOldHI"`), and
the run stops when the share of converged cells reaches the second number of `maxIterateMC`
({src}`iteration_mod.f90::MCIterationDriver/cvTotalsUpdate@"lgCvTotals = (totPercent >= minConvergence)"`;
{devlog}`D-441`). `pn150k`'s PDR grains are at 0.92–0.93 of Cloudy's temperature; {lim}`L-19`
explains the sign of that deficit, not its size, by the two codes putting their reprocessed energy at
different frequencies.

### Resonance-line heating

{bdg-success}`used`

Since {devlog}`D-376`, every dust+gas run heats the grains with the resonance lines the dust
destroys; before, the heating waited for the share of converged cells to reach `resLinesTransfer`,
which of this project's inputs only `test_Problem` sets ({doc}`emission`). Each grain takes
({src}`update_mod.f90::updateCell/resLineHeating@"heat = Gline*grid%Hden(cellP)* &"`)

```{math}
:label: eq:moc-resline
H^{\mathrm{res}}_{s,a} = \sum_l \varepsilon_l\,(1-P^{\mathrm{esc}}_l)\,
   \frac{C^{\mathrm{abs}}_{s,a}(\nu_l)}{N_d\,\bar C^{\mathrm{abs}}_s(\nu_l)} ,
```

with $\varepsilon_l$ the line's emissivity (for Ly$\alpha$ a fit to
{cite:t}`StoreyHummer1995` plus the collisional excitation of {src}`emission_mod.f90::hICollExc`, {devlog}`D-447`) and $P^{\mathrm{esc}}_l$ its escape probability, from optical depths along
the eight body diagonals only ({doc}`emission`; {lim}`L-88`);
the code cites {cite:t}`Harrington1988` for the formula. The destroyed power is shared within a
species by $C^{\mathrm{abs}}$, but between species by number abundance, since each species is
normalised by its own $\bar C^{\mathrm{abs}}_s$: the mixture absorbs $\sum_s X_s$ times the
destroyed power, all of it only when the abundances sum to one ({lim}`L-79`). Adding Ly$\alpha$ raised
`pn150k`'s grains in the ionised gas from 0.94 and 0.81 of Cloudy's temperature to 1.01 and 0.98
({lim}`L-19`).

### Fixed temperature

{bdg-warning}`not exercised`

`TDust` sets every grain of every cell to one temperature and skips the balance
({src}`update_mod.f90::updateCell/getDustT@"if (lgforceTDust) then ! BEKS2010"`).

## Dust emission

{bdg-success}`used`

At the start of each iteration `setDustPDF` ({src}`emission_mod.f90::emissionDriver/setDustPDF`)
builds each cell's emission distribution from the current temperatures,

```{math}
:label: eq:moc-dustpdf
F(\nu_k) \propto \sum_{j\le k}\;\sum_s X_s\sum_{a\in s} w(a)\,C^{\mathrm{abs}}_{s,a}(\nu_j)\,B_{\nu_j}\bigl(T_d(s,a)\bigr)\,\Delta\nu_j ,
```

over the grains with $0<T_d<T_{\mathrm{sub},s}$, normalised to 1; a cell with no emission gets a
zero distribution instead of 0/0
({devlog}`D-243`; {src}`emission_mod.f90::emissionDriver/setDustPDF@"! D-243: same guard as recPDF above."`).
A packet absorbed by grains becomes a `dustEmi` packet with its frequency drawn from $F$
({src}`photon_mod.f90::newPhotonPacket@"call getNu2(grid(gP)%dustPDF(grid(gP)%active(xP(igPn),yP(igPn),zP(igPn)),1:nbins), nuP)"`).
Before {devlog}`D-233` the distribution was built only without gas, and a dust+gas model re-emitted
every absorption from the gas's spectrum: about 3.8% of what the dust absorbed came back out above
13.6 eV ({devlog}`D-232`). The frequency grid that carries the infrared is in {doc}`grid`; a
dust-only model reads it from `nuDustRyd.dat`, while a dust+gas model takes one point of that file,
or two when `nuMin` lies below 4.9 GHz ({lim}`L-70`).

## Stochastic heating

{bdg-warning}`not exercised`

`quantumHeatGrain amin conv` (defaults $10^{-3}$ µm and 99;
{src}`set_input_mod.f90::readInput@"case(\"quantumHeatGrain\")"`) makes grains smaller than `amin`
emit from a temperature distribution. `qHeat` ({src}`emission_mod.f90::emissionDriver/qHeat`)
builds it on `nTbins` temperatures up to `Tmax` (by default 300 temperatures up to 700 K; set by
`quantumHeatGrainParameters`) from transition matrices between enthalpy levels, the method
{cite:t}`Ercolano2005` take from {cite:t}`GuhathakurtaDraine1989`. It changes the grain's term in
Eq. {eq}`eq:moc-dustpdf`, not the tabulated $T_d$.

Switched on, it still almost never runs ({lim}`L-8`). `qHeat` waits for iteration 2 and for the previous
iteration's share of converged cells to exceed `conv`
({src}`emission_mod.f90::emissionDriver/setDustPDF@"if (lgQHeat .and. grainRadius(ai)<minaQHeat .and. &"`).
Dust+gas runs stop at shares near 57–72% ({devlog}`D-392`) and dust-only runs at `minConvergence`,
so the gate is essentially never passed. In dust+gas runs `setDiffusePDF` calls `qHeat` a second
time per grain, for a term that feeds only the `pdfSrc` diagnostic
({src}`emission_mod.f90::emissionDriver/setDiffusePDF@"if (lgDust) grids(iG)%pdfSrc(cellPUsed,2) = normDust"`)
and, if asked, writes `qHeatPss.out`. Two more defects would show if the gate opened. The enthalpy is chosen
by the first letter of the label, `S` or `C`
({src}`emission_mod.f90::emissionDriver/qHeat@"sorc = grainLabel(ns)(1:1)"`); with any other
(`grph-avg` among them), `qHeat` returns an empty distribution and the grain emits nothing. And
`getTmin` ({src}`emission_mod.f90::emissionDriver/getTmin`) zeroes the field in the bins it then
sums, so the distribution's lowest temperature is always 1 K ({lim}`L-8`). {devlog}`D-306` asked whether
stochastic heating explained `pn150k`'s dust running 7–25% hot against Cloudy and found it did not:
the excess was the same at every size, and {devlog}`D-309` traced it to the graphite axes.

(sec:moc-dust-charge)=
## Grain charge and the exchange with the gas

{bdg-success}`used`

With gas, dust and photoelectric heating (`noPhotoelectric`, not exercised, turns all of this off),
every trial temperature of the gas search solves each grain's potential $V$ and then the
photoelectric and collisional terms
({src}`update_mod.f90::updateCell/iterateT@"if (lgDust .and. lgGas .and. lgPhotoelectric) then"`).
The gas balance takes heating $\Gamma_{\mathrm{pe}}$ and cooling $\Lambda_{\mathrm{gd}}$ per H
nucleus
({src}`update_mod.f90::updateCell/thermBalance@"coolInt = coolInt+gasDustColl_g"..@"heatInt = heatInt+photoelHeat_g"`),
and `getDustT` uses the grain-side terms of the last trial. The framework is that of
{cite:t}`Baldwin1991`, with the changes below.

**Charge.** `setGrainPotential` ({src}`update_mod.f90::updateCell/setGrainPotential`) solves, by
secant steps from $V=0$,

```{math}
:label: eq:moc-charge
\sum_{h\nu_k\ge h\nu_{\mathrm{th}}}\hat Y_{s,a}(\nu_k)\,Q^{\mathrm{abs}}_{s,a}(\nu_k)\,\frac{J^{\mathrm{ste}}_k}{h\nu_k}
 = n_e\langle v_e\rangle s_e\eta_e - \sum_{X,\,i\ge2} n_{X,i}\langle v_X\rangle\,\eta_i ,
```

with $h\nu_{\mathrm{th}}=W_s+\max(eV,0)$, $\Theta=h\nu-W_s$, $\langle v\rangle=(8kT_e/\pi m)^{1/2}$,
the Coulomb factor $\eta=1-\psi$ for $\psi\le0$ and $e^{-\psi}$ for $\psi>0$, $\psi=ZeV/kT_e$
($Z=-1$ for electrons), and the yield net of the barrier $\hat Y=Y\min[1,\max(0,1-eV/\Theta)]$.
The photoemission sum starts one bin above the bin in which the photoelectric heating below starts
({src}`update_mod.f90::updateCell/getGrainEmission@"call locate( nuArray, thres, ip)"+1`;
{lim}`L-76`). The solve stops at a relative imbalance of 0.5%, with steps of at most 5% of the
threshold
({src}`update_mod.f90::updateCell/setGrainPotential@"real,parameter       :: errorLim = 0.005, dm = 0.05 ! loop convergence"`),
and gives up after 100 steps
({src}`update_mod.f90::updateCell@"integer, parameter :: maxIterateGC = 100"`);
an unconverged potential is used as it is, since the flag is never read ({lim}`L-83`). Photoemission carried a
spurious $4\pi^2$, a second $4\pi$ on $J^{\mathrm{ste}}$ and $\pi Q_{\mathrm{abs}}$ for
$Q_{\mathrm{abs}}$, until {devlog}`D-290`
({src}`update_mod.f90::updateCell/getGrainEmission@"! D-290. This term and getGrainRecombination must be in the same"`).
The electron sticking is $s_e=\tfrac12(1-e^{-a/10\,\text{Å}})$ of {cite:t}`WeingartnerDraine2001`
({devlog}`D-325`, {devlog}`D-326`;
{src}`update_mod.f90::updateCell/getGrainRecombination@"S  = 0.5 * (1. - exp(-grainRadius(ai)/1.e-3))   ! a, l_e both in um"`),
where Baldwin et al. had 1; ion sticking is 1.

**Yield.** Since {devlog}`D-289` the charge balance and the heating share the neutral yield of
{cite:t}`WeingartnerDraine2001`, built from each species' own optical constants
({src}`ph_mod.f90::setGrainYield@"yEsc = (be/al)**2 * wdEsc(al)/wdEsc(be)"`):

```{math}
:label: eq:moc-yield
Y = \min\!\Bigl[y_0\!\left(\tfrac{\Theta}{W_s}\right)\frac{\beta^2}{\alpha^2}\frac{f(\alpha)}{f(\beta)},\,1\Bigr],\qquad
f(x)=x^2-2x+2-2e^{-x},\qquad \beta=\frac{4\pi\,\mathrm{Im}(m)\,a}{\lambda},\quad \alpha=\beta+\frac{a}{10\,\text{Å}},
```

with the bulk yield $y_0(x)=9\times10^{-3}x^5/(1+3.7\times10^{-2}x^5)$ for a carbonaceous grain,
one whose surface atom is within 1 amu of 12
({src}`ph_mod.f90::setGrainYield@"grainCarb(iSp) = abs(MsurfAtom(iSp) - 12.0) < 1.0"`), and
$0.5x/(1+5x)$ otherwise. The threshold is the grain's own $W_s$, without the paper's size-dependent
shift.

**Photoelectric terms.** A grain loses
$L^{\mathrm{pe}}_{s,a}=\sum_k C^{\mathrm{abs}}_{s,a}(\nu_k)\,(J^{\mathrm{ste}}_k/h\nu_k)\,\bar E_Y$,
with $\bar E_Y=\tfrac12Y\min[\Theta,\max(0,(\Theta^2-e^2V^2)/\Theta)]$ the energy its
photoelectrons carry
({src}`update_mod.f90::updateCell/setPhotoelHeatCool@"photoelHeat_d(ns,na) = photoelHeat_d(ns,na)+Qa*photFlux*EY*hcRyd/Pi"`).
The gas gains $\bar E_Y-\hat YeV$ per absorbed photon, summed with weights
$X_s\,w(a)\,N_d/n_{\mathrm H}$. In the PDR builds these terms replace 3D-PDR's own
({ref}`sec:thermal`).

**Collisions.** `setDustGasCollHeatCool` ({src}`update_mod.f90::updateCell/setDustGasCollHeatCool`)
gives each grain

```{math}
:label: eq:moc-coll
H^{\mathrm{coll}}_{s,a}=\pi a^2\Bigl\{\sum_{X,i} n_{X,i}S\langle v_X\rangle\bigl[2kT_e\xi_i-\eta_i\,(Z_ieV-I_{X,i-1}+2kT_d)\bigr]
 + n_e\langle v_e\rangle\bigl[2kT_e\xi_e+\eta_e eV\bigr]
 + n_{\mathrm{H_2}}S\langle v_{\mathrm{H_2}}\rangle\,(2kT_e-2kT_d)\Bigr\},
```

with $\xi=1-\psi/2$ for $\psi\le0$ and $(1+\psi/2)e^{-\psi}$ for $\psi>0$, and $I_{X,i-1}$ the
ionisation energy of stage $i-1$, released when the ion recombines by one stage on the grain, zero
for a neutral, which was read
uninitialised until {devlog}`D-127`. $S=2mM/(m+M)^2$ for neutrals, with both masses in amu since
{devlog}`D-129`, and 1 for ions and electrons. The H$_2$ term exists only in the PDR builds
({devlog}`D-420`). The gas side keeps only the colliders' thermal energy, $2kT_e\xi-2kT_d\eta$ per
collision ($2kT_e\xi$ for electrons). The grain term is divided by $\pi$ for Eq.
{eq}`eq:moc-radeq` and the gas term enters per H; both had been divided by $4\pi$ until
{devlog}`D-421`
({src}`update_mod.f90::updateCell/setDustGasCollHeatCool@"gasDustColl_d(:,:)= gasDustColl_d(:,:)/Pi"`).
