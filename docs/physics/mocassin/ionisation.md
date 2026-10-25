(sec:moc-ionisation)=
# Photoionisation and the ionisation balance

This chapter describes how MOCASSIN turns a cell's Monte Carlo field into the fractions $x_{X,i}=n(X^{i-1+})/n(X)$ of every ion stage and the electron density, following {cite:t}`Ercolano2003` as the code now implements it. The cross sections are tabulated once at start-up; in every iteration `ionizationDriver` rebuilds each cell's opacity from the current ion fractions ({src}`ionization_mod.f90::ionizationDriver`), the transfer accumulates the field ({doc}`transfer`), and `updateCell` computes the photoionisation rates once and then solves the balance at every trial temperature of the thermal search ({doc}`thermal`). For the five elements that the chemistry shares (H, He, C, O, Mg) the PDR builds hand these rates to the network and replace some channels with the network's; that part is described in {doc}`../pdr/photorates` and {doc}`../pdr/feedback` and only flagged here. Status flags are explained in {doc}`index`; notation follows {numref}`tab:notation`.

(sec:moc-ion-xsec)=
## Photoionisation cross sections
{bdg-success}`used`

`phInit` reads the fit parameters of `data/ph1.dat` and `data/ph2.dat` ({src}`ph_mod.f90::phInit`), and `phFitEl` evaluates the partial cross section of shell $s$ (1s, 2s, 2p, 3s, 3p, 3d, 4s) of any stage of H to Zn: the outer shells of the Opacity Project elements from {cite:t}`Verner1996`, the inner shells and the outer shells of the other elements from {cite:t}`VernerYakovlev1995` ({src}`ph_mod.f90@"! outer shell of the Opacity Project (OP) elements: Verner, Ferland, Korista"`, {src}`ph_mod.f90::phFitEl`). The inner-shell form is

$$
\sigma(E) = \sigma_0\,\bigl[(y-1)^2+y_w^2\bigr]\,y^{-(5.5+l-P/2)}\,\bigl(1+\sqrt{y/y_a}\bigr)^{-P},\qquad y=E/E_0 ,
$$ (eq:moc-verner)

with $l$ the orbital quantum number of the shell. The outer-shell fits of {cite:t}`Verner1996` have no $l$ term and take $x$ in the first factor and $z$ in the others, $\sigma=\sigma_0\bigl[(x-1)^2+y_w^2\bigr]\,z^{P/2-5.5}\bigl(1+\sqrt{z/y_a}\bigr)^{-P}$ with $z=\sqrt{x^2+y_1^2}$, $x=E/E_0-y_0$ ({src}`ph_mod.f90::phFitEl@"q = -0.5*p1 - 5.5"+6`). Above the edge of the highest inner shell (1s for ions with 3–10 electrons, 2p for 11–18, 3p beyond) the outer shell of an Opacity Project element switches to the partial fit of {cite:t}`VernerYakovlev1995`, Eq. ({eq}`eq:moc-verner`); H- and He-like ions keep the {cite:t}`Verner1996` fit at every energy ({src}`ph_mod.f90::phFitEl@"if( (shell <= nInt) .or. (photEn >= eInn) ) then"`). `initXSecArray` stores the ground-state cross sections of H I, He I and He II on the frequency grid ({src}`ph_mod.f90::initXSecArray@"call phFitEl(1, 1, 1, thres, xSec)"`, {src}`ph_mod.f90::initXSecArray@"call phFitEl(2, 2, 1, nuArray(i)*RydToeV, xSec)"`, {src}`ph_mod.f90::initXSecArray@"call phFitEl(2, 1, 1, thres, xSec)"`), and `makeOpacity` every shell of every stage up to `nstages` of the heavier elements switched on ({src}`ph_mod.f90::makeOpacity`); for H I, He II and the heavy elements the first bin of a range takes the value at the threshold, which may lie inside that bin. H and He have dedicated arrays and one shell each ({src}`hydro_mod.f90::setPointers@"nShells(1,1) = 1"+2`).

A shell's range runs from the bin of its threshold to an upper pointer set by `setShells` and `limitShell` ({src}`hydro_mod.f90::setShells`, {src}`hydro_mod.f90::limitShell`): the 1s, 2s and 2p shells extend to `kShellLimit`, $7.35\times10^4$ Ryd ({src}`constants_mod.f90@"real, parameter :: kShellLimit = 7.35e4"`), which with the default `nuMax` of 15 Ryd ({src}`set_input_mod.f90::readInput@"nuMax = 15."`; {ref}`kw-nuMax`) is the top bin of the grid; the n = 3 shells stop below the K edge and 4s below the 3d (or 3p) edge. A shell whose threshold lies above `nuMax` occupies the top bin only. The grid itself (600 bins by default, {ref}`kw-nbins`) is described in {doc}`grid`.

(sec:moc-ion-opacity)=
## Gas opacity
{bdg-success}`used`

`addOpacity` sums $n_i\sigma_i(\nu)$ over the ground states of H$^0$, He$^0$ and He$^+$ and over every shell of every heavy-element stage with a non-zero density (`putOpacity`), with no stimulated-emission correction (the departure coefficient passed is zero) and no absorption from excited levels, whose populations are not computed ({src}`ionization_mod.f90::addOpacity@"call inOpacity(HlevXSecP(1), HlevNuP(1), nbins, density(1,1), 0.)"`, {src}`ionization_mod.f90::addOpacity@"! NOTE: the opacity due to the excited levels of HI, HeI and HeII is"`, {src}`ionization_mod.f90::addOpacity/putOpacity`). The PDR builds add the H$_2$ photoionisation continuum above 15.4 eV ({devlog}`D-107`, {devlog}`D-141`; {doc}`../pdr/feedback`). Dust opacity is added separately ({doc}`dust`).

Free–free absorption is coded as

$$
\kappa^{\mathrm{ff}}_\nu = 1.0368\times10^{-38}\;
  \frac{n_e\bigl[n(\mathrm H^+)+n(\mathrm{He}^+)+4n(\mathrm{He}^{2+})+\sum_{X\ge3}\sum_i i^2\,n(X^{i+})\bigr]}{T^{1/2}\,\nu_{\mathrm{Ryd}}^{3}}\;
  g_{\mathrm{ff}}(\nu,T)\,\bigl(1-e^{-h\nu/kT}\bigr)\ \mathrm{cm^{-1}},
$$ (eq:moc-ffopac)

with the thermally averaged non-relativistic Gaunt factor of {cite:t}`Hummer1988` for $Z=1$ (`getGauntFF`, a Chebyshev fit; {src}`ionization_mod.f90::getGauntFF`, {src}`ionization_mod.f90::eDenSum`). It is recomputed only when $T$ differs by more than 10% from the temperature of its last evaluation ({src}`ionization_mod.f90::BoltGaunt@"if ( abs(1. - TeOld2/TeUsed) > 0.10 ) then"`; {lim}`L-76`). Two defects make the term almost absent ({lim}`L-69`): the branch that computes it belongs to the first frequency bin only, so for all bins above the first `FFOpacity` stays zero ({src}`ionization_mod.f90::addOpacity@"if (i>1) then"`); and the Boltzmann factor is formed from $T_{1\,\mathrm{Ryd}}/T+\nu$ instead of $\nu\,T_{1\,\mathrm{Ryd}}/T$ ({src}`ionization_mod.f90::BoltGaunt@"exponent = (Te1Ryd / TeUsed) + nuArray(i)"`), so the stimulated-emission factor is always 1 and the bin-1 value is too large by $kT/h\nu$. The gas therefore emits a free–free continuum ({doc}`emission`) that it does not absorb, which matters at radio and millimetre wavelengths.

(sec:moc-ion-rates)=
## Photoionisation rates
{bdg-success}`used`

The rate of each stage from its ground state is Eq. ({eq}`eq:gammaX`), $\Gamma=\sum_k J^{\mathrm{ste}}_k\sigma(\nu_k)/h\nu_k$, computed by `updateCell` once per cell and iteration, before the temperature search, so the rates are the same at every trial temperature ({src}`update_mod.f90::updateCell@"nPhotoSte(elem,ion) = nPhotoSte(elem,ion) + &"..@"& grid%JSte(cellP,j)*phXSec/(hcRyd*nuArray(j))"`). H and He are integrated from threshold to the top bin. For the heavier elements only the **outer shell** is integrated, from its threshold to one bin below its upper pointer ({src}`update_mod.f90::updateCell@"highNuP = elementP(elem, ion, outShell, 2) - 1"`), and cross sections below $10^{-35}$ cm$^2$ count as zero ({lim}`L-76`). The loop over stages stops at `nstages`−1, so the top stage has no rate out of it, though `makeOpacity` gives it an opacity: its absorptions neither ionise nor heat ({lim}`L-64`). Without `debug`, $J^{\mathrm{ste}}$ holds the whole field, stellar and diffuse ({src}`photon_mod.f90@"! D-158: Jste holds stellar AND diffuse when lgDebug is"#1`); with `debug` the diffuse part is accumulated apart in $J^{\mathrm{dif}}$, its rates are computed separately and added in the balance ({src}`update_mod.f90::updateCell/ionBalance@"if (lgDebug) then"#1`; {ref}`kw-debug`, {bdg-warning}`not exercised`). The diffuse ionising field is the Monte Carlo's own, not an on-the-spot approximation ({doc}`emission`), which is why the recombination coefficients below are totals.

(sec:moc-ion-inner)=
## Inner shells, Auger electrons and collisional-ionisation data
{bdg-success}`used` (inner-shell absorption) {bdg-secondary}`dead` (Auger and collisional-ionisation data)

Inner shells absorb but neither ionise nor heat ({lim}`L-64`): `putOpacity` adds every shell to the opacity, while the rates above and the heating in `thermBalance` use only the outer shell (`getOuterShell`, {src}`hydro_mod.f90::getOuterShell`). In the convention of the Verner fits, a shell of an Opacity Project element that lies between the outer shell and the highest inner shell (the 2s of an ion whose outer shell is 2p, the 3s of one whose outer shell is 3p) has no cross section below that inner shell's edge, the outer-shell fit carrying its part ({src}`ph_mod.f90::phFitEl@"if( (shell < nOut) .and. (shell > nInt) .and. &"+1`). C, N, O and Ne therefore lose nothing to inner shells within 15 Ryd. What absorbs there is the 2s and 2p shells of Mg I–II and Si I–IV, the 2p shells of S I–III (from 12.5 Ryd), and the 3s shells of Si I–II and S I–III above their 2p edges. The 24 and 30 Ryd grids of PN150, PN75 and `pn150k` also reach the K shells of C I–II (C I–IV and N I at 30 Ryd) and further L shells of S. The top stage of an element with more than `nstages` stages absorbs in the same way: its cross sections are stored and enter the opacity, but no rate leaves it. With `nstages` 7 the top stages of N and O lie far above 30 Ryd, but those of Ne, Mg, Si and S (15.2–20.7 Ryd) fall inside the 24 Ryd grids of PN150 and PN75. `pn150k` switches on trace elements whose stage-VII thresholds lie inside even a 15 Ryd grid (Cl, Ar, K and Sc to Zn without Fe at 8.4–11.8 Ryd, F at 13.6), and its 30 Ryd grid also takes in Na, Al and P VII (15.3–19.3 Ryd) besides Ne, Mg, Si and S. Two data sets are read at start-up and never used ({src}`ph_mod.f90::initXSecArray@"call makeCollIonData()"+2`): the Auger yields of `auger.dat` ({src}`hydro_mod.f90::makeAugerData`) and the five-parameter collisional-ionisation fits of `cion.dat` ({src}`hydro_mod.f90::makeCollIonData`). The absorbed energy is not lost, since the packet is re-emitted from the gas emission spectrum ({lim}`L-51`), but it produces no ion and no heat.

(sec:moc-ion-radrec)=
## Radiative recombination
{bdg-success}`used`

`radRecFit` returns the total (Case A) radiative recombination coefficient into each stage, read from `data/radrec.dat` at the first call ({src}`update_mod.f90::updateCell/radRecFit`). Its header lists the sources ({src}`update_mod.f90::updateCell@"! This subroutine calculates rates of radiative recombination for all ions"..@"! n - number of electrons from 1 to z"`): {cite:t}`VernerFerland1996` for H-, He-, Li- and Na-like ions, {cite:t}`Pequignot1991` refitted to the same form for the other ions of C, N, O and Ne, {cite:t}`ArnaudRaymond1992` and refits for Fe, {cite:t}`ShullVanSteenberg1982` for Mg, Si, S, Ar, Ca, Fe and Ni, and {cite:t}`LandiniMonsignoriFossi1990,LandiniMonsignoriFossi1991` for Na, Al and some other elements. The Verner–Ferland form is $\alpha=a/\bigl[\sqrt{T/T_0}\,(1+\sqrt{T/T_0})^{1-b}(1+\sqrt{T/T_1})^{1+b}\bigr]$; the others are power laws in $T/10^4$ K, with a $\log T$ term in the exponent for Fe XVII–XXIII (Fe XIV–XVI take the Verner–Ferland form), stages that `nstages` $\le10$ never reaches (constants inline, {src}`update_mod.f90::updateCell/radRecFit@"if ( (n<=3) .or. (n==11) .or. ((z>5) .and. (z<9)) .or. (z==10) .or.&"..@"end if"`). {doc}`../../reference/data-sources` lists the file's sources.

(sec:moc-ion-dielec)=
## Dielectronic recombination
{bdg-success}`used`

`calcAlpha` adds a dielectronic coefficient to the radiative one for every stage of the elements from Li up ({src}`update_mod.f90::updateCell/calcAlpha`). Below 60 000 K it uses the low-temperature fits of `data/dielectronic.dat`, 25 rows for C, N, O, Ne, Mg, Al and Si of which the six for recombination into a neutral are zeroed (below), so 19 fits act (read at {src}`readdata_mod.f90::readData@"! dielectronic recombination coefficients"`), in the form of {cite:t}`NussbaumerStorey1983`, the source {cite:t}`Ercolano2003` give for them (with two later papers by the same authors):

$$
\alpha_{\mathrm{di}} = 10^{-12}\,\Bigl(\frac{a}{t}+b+c\,t+d\,t^2\Bigr)\,t^{-3/2}\,e^{-f/t}\ \mathrm{cm^3\,s^{-1}},\qquad t=T/10^4\,\mathrm K ,
$$ (eq:moc-dielec)

where a flag selects, for the stages with two fits, the one below or the one at and above 20 000 K ({src}`update_mod.f90::updateCell/dielectronic@"else if (direc_coeffs(i)%g == 1 .and. TeUsed .lt. 20000.) then"+3`). Above 60 000 K, and for every stage without a fit, it takes the high-temperature rates of {cite:t}`AldrovandiPequignot1973` (`data/aldrovandi.dat`, 167 rows; {src}`readdata_mod.f90::readData@"! Aldrovandi and Pequignot 1973"`), $\alpha=A\,T^{-3/2}e^{-T_0/T}\,(1+B\,e^{-T_1/T})$ ({src}`update_mod.f90::updateCell/dielectronic@"if (TeUsed>60000.) then"`). A stage still without a rate then takes oxygen's rate for the same stage index ({src}`update_mod.f90::updateCell/calcAlpha@"if (diRec(elem,ion) == 0.) diRec(elem,ion) = diRec(8,ion)"`; {lim}`L-66`): with `nstages` 7 that is 91 stages, of Li, Be, B, C VI, F, Na, P, Cl, K, Sc–Mn, Co, Cu and Zn. Of these `hiipdr`, the Lexington models and `test_Problem` have only C VI; `pn150k` switches on trace amounts of the others, so all 91 take oxygen's rate there. The rate into the neutral stage was zeroed in 2026 (commit 490f484, {src}`update_mod.f90::updateCell/dielectronic@"diRec(direc_coeffs(i)%elem, ion) = 0."`), but the two fallbacks refill it with an {cite:t}`AldrovandiPequignot1973` rate, the element's own or oxygen's ({lim}`L-66`). That rate is exponentially small at low temperature and zero in cold gas, where $e^{-T_0/T}$, with $T_0$ of $3\times10^4$–$3\times10^5$ K for the neutrals, underflows in single precision. Below their fitted range the polynomial fits go negative; such rates are set to zero ({src}`update_mod.f90::updateCell/calcAlpha@"if (diRec(elem,ion) < 0.) diRec(elem,ion) = 0."`; {devlog}`D-116`). H and He have no dielectronic term.

(sec:moc-ion-ct)=
## Charge exchange with hydrogen
{bdg-success}`used`

The coefficients of $X^{i+}+\mathrm H\to X^{(i-1)+}+\mathrm H^+$ are fits of the form of {cite:t}`KingdonFerland1996`,

$$
k_{\mathrm{ct}} = 10^{-9}\,a\,t_4^{\,b}\,\bigl(1+c\,e^{d\,t_4}\bigr)\ \mathrm{cm^3\,s^{-1}},\qquad t_4=T/10^4\,\mathrm K ,
$$ (eq:moc-ct)

for 51 element–stage pairs from He to Fe, some of them a constant $10^{-14}$ cm$^3$ s$^{-1}$, set inline ({src}`update_mod.f90::updateCell/ionBalance@"chex(2,1,:)"..@"chex(26,3,:)"`, evaluated at {src}`update_mod.f90::updateCell/ionBalance@"chex(elem,ion,1) = chex(elem,ion,1)*(t4**chex(elem,ion,2))*&"+1`). Each adds $k_{\mathrm{ct}}\,n(\mathrm H^0)$ to the recombination rate of the stage ({src}`update_mod.f90::updateCell/ionBalance@"ionDn(elem,ion) = dble(NeUsed)*dble(alphaTot(elem,ion)) &"+2`). The reverse reaction, $X+\mathrm H^+\to X^++\mathrm H$, is included only for N and O, by detailed balance, $k_{\mathrm{ct}}\,n(\mathrm H^+)\,2(g_1/g_0)\,e^{-\Delta E/kT}$ with $\Delta E/k=10\,863$ K and 229 K ({src}`update_mod.f90::updateCell/ionBalance@"revRate = chex(elem,ion,1) * &"+3`). {devlog}`D-263` corrected oxygen's threshold from 2205 K to 229 K, took $n(\mathrm H^+)$ as $x(\mathrm H^+)\,n_{\mathrm H}$, and removed a 6000 K lower cut-off that was not the fits' validity limit ({devlog}`D-262`; {src}`update_mod.f90::updateCell/ionBalance@"! D-263: deltaE/k is the difference of the ionization potentials,"..@"deltaE_k(8,1) = 229."`). The coefficients are zero above 50 000 K ({src}`update_mod.f90::updateCell/ionBalance@"if (TeUsed > 5.e4) chex(elem,ion,1) = 0."`), and in a plain build the He$^+$ + H fit, valid from 6000 K, is used down to any temperature ({lim}`L-48`). Hydrogen does not receive the other side of these reactions. In the PDR builds the neutral/first-ion pair of each linked element uses the network's coefficients instead, through `pdrCtRates`, and hydrogen takes its side of He$^+$ + H ({src}`update_mod.f90::updateCell/ionBalance@"ionUp(elem,1) = ionUp(elem,1) - dble(revRate) + ctUp402(ie402)*nHp402"+2`; {devlog}`D-402`, {devlog}`D-403`; {ref}`sec:ct`; {lim}`L-48`).

(sec:moc-ion-collion)=
## Collisional ionisation
{bdg-success}`used`

Only hydrogen is ionised collisionally, with $2.75\times10^{-16}\,T^{3/2}(157\,894/T+2)\,e^{-157\,894/T}$ ({src}`update_mod.f90::updateCell/ionBalance@"! take into account collisional ionization of H"..@"& (157893.94/TeUsed+2.)*exp(-expFact)"`), which is added to the photoionisation rate without the factor $n_e$; {ref}`sec:linked` discusses the formula, its attribution to {cite:t}`DrakeUlrich1980` and the missing factor (item 31 of {doc}`../pdr/path-limitations`).

(sec:moc-ion-cr)=
## Cosmic rays
{bdg-success}`used` (PDR builds only)

A plain build has no cosmic-ray ionisation ({devlog}`D-035`). The PDR builds add, for every linked neutral, the network's direct and cosmic-ray-induced-photon rates at the input $\zeta$ ({src}`update_mod.f90::updateCell/ionBalance@"if (lgPDR .and. ion == 1 .and. pdrNcr > 0) then"`; {devlog}`D-193`, {devlog}`D-280`; {doc}`../pdr/feedback`).

(sec:moc-ion-solve)=
## Solving the balance
{bdg-success}`used`

For each element the upward rate of stage $i$ is $U_i=\Gamma_i+C_i+k^{\mathrm{rev}}_i$ (photoionisation, collisional ionisation, reverse charge exchange) and the downward rate of stage $i+1$ is $D_i=n_e\alpha_i+k^{\mathrm{ct}}_i\,n(\mathrm H^0)$, both clamped at zero ({src}`update_mod.f90::updateCell/ionBalance@"if (ionUp(elem,ion) < 0.d0) ionUp(elem,ion) = 0.d0"+1`). The original solution is the chain $x_{i+1}/x_i=U_i/D_i$ (capped at $10^{30}$; {src}`update_mod.f90::updateCell/ionBalance@"ionRatio(elem,ion) = ionUp(elem,ion)/dnChain402"`), normalised so that the stages sum to $f_X$, which is 1 in a plain build and, in the PDR builds, the fraction of the element not locked in molecules ({src}`update_mod.f90::updateCell/ionBalance@"availFrac(elem) = &"`; {devlog}`D-102`, {devlog}`D-193`). Since {devlog}`D-117` the default (`lgIonMatrix`, {src}`common_mod.f90@"logical :: lgIonMatrix = .true. ! matrix ionBalance"+0`) solves instead

$$
U_{i-1}x_{i-1}-(U_i+D_{i-1})\,x_i+D_i\,x_{i+1}=0 ,
$$ (eq:moc-ionmatrix)

with the row of the most populated stage replaced by the sum over the stages kept, column-scaled by the chain estimate and solved by Gaussian elimination with partial pivoting ({src}`update_mod.f90::updateCell/ionBalance@"! D-114: matrix solve, replacing the chain above."..@"if (lgIonMatrix) then"`, {devlog}`D-114`, {devlog}`D-115`). Stages below `ionTrim` times the largest are trimmed and keep their chain values ({src}`update_mod.f90::updateCell/ionBalance@"do while (iLo < nst .and. ionScal(iLo) < ionTrim*big)"`); `ionTrim` is $10^{-8}$, while its comment still says $10^{-12}$ ({src}`common_mod.f90@"! Stage-trimming threshold, as a fraction of the most populated stage."..@"ionTrim = 1.d-8"`; {lim}`L-77`). Without molecular terms the matrix reproduces the chain to round-off; it exists so that the PDR builds can add the network's sources and sinks of the neutral and first ion on the right-hand side and the diagonal ({src}`update_mod.f90::updateCell/ionBalance@"chemSnk(1) = dble(grid%pdrIonRate(cellP, ik+3))"+3`; {devlog}`D-402`), which a product of ratios cannot carry; a first ion trimmed out of the matrix loses that source ({lim}`L-50`). Fractions are clamped to $[10^{-20},\,0.99999]$ ({src}`update_mod.f90::updateCell/ionBalance@"if (grid%ionDen(cellP,elementXref(elem),ion) > xMax) &"+3`).

The electron density is then summed over the stages with $x\ge10^{-10}$,

$$
n_e = n_{\mathrm H}\sum_X A_X\sum_{i\ge2}(i-1)\,x_{X,i}
$$ (eq:moc-ne)

({src}`update_mod.f90::updateCell/ionBalance@"if( ionDenUsed(elementXref(elem),ion) >= 1.e-10) &"+2`; 1 cm$^{-3}$ if the sum is zero), and the balance is solved again, recursively, up to 50 passes ({src}`update_mod.f90::updateCell@"maxIterateX = 50"`), until $x(\mathrm H^0)$, $x(\mathrm{He}^0)$, $x(\mathrm{He}^+)$ and $n_e$ change by less than 1% between passes ({src}`update_mod.f90::updateCell/ionBalance@"limit = 0.01"`). Each new pass starts from the geometric mean of a bracket on the root in $n_e$ ({src}`update_mod.f90::updateCell/ionBalance@"if (deltaNe /= 0.) NeUsed = sqrt(NeLoB)*sqrt(NeHiB)"`): {devlog}`D-278` found that deep in a PDR, where the electrons come from trace ions whose abundances scale as $1/n_e$, plain substitution was a two-cycle, and {devlog}`D-279` made it a bracketed root, which removed the failures. A balance not reached in 50 passes flags the cell ({doc}`thermal`). With `inputNe` ({ref}`kw-inputNe`, {bdg-warning}`not exercised`) the density read is $n_e$: $n_{\mathrm H}$ starts at $n_e/1.11$ and is rescaled after every pass so that the computed $n_e$ matches the input, and the $n_e$ test is skipped ({src}`update_mod.f90::updateCell/ionBalance@"correction = NeUsed/grid%NeInput(cellP)"+1`).

(sec:moc-ion-stages)=
## Ion stages
{bdg-success}`used`

`nstages` sets how many stages of each element are followed, 7 by default and at most 10 ({src}`set_input_mod.f90::readInput@"case(\"nstages\")"`; {ref}`kw-nstages`); an element has $\min(Z+1,\,$`nstages`$)$ stages, and the top one stands for every higher stage. The Lexington fixtures use 7, except HII20 with 6 ({doc}`../../benchmarks/lexington`).

(sec:moc-ion-pdr)=
## What the PDR builds add, and the keywords only they parse
{bdg-success}`used`

Besides the terms flagged above, the PDR builds store the linked elements' photoionisation and recombination rates for the chemistry at every trial temperature ({devlog}`D-358`; {ref}`sec:linked`) and, after the chemistry, solve `ionBalance` a second time in every cell, kept at the last iteration ({src}`iteration_mod.f90::MCIterationDriver/ionSecondSolve`; {devlog}`D-404`; {lim}`L-47`). The keywords `ionMatrix`, `initH0`, `iterDamp`, `ionBalProbe` and `ionRateProbe` are parsed only inside the PDR block of `readInput` ({src}`set_input_mod.f90::readInput@"case (\"ionMatrix\")"`; {ref}`kw-ionMatrix`, {ref}`kw-initH0`, {ref}`kw-iterDamp`, {ref}`kw-ionBalProbe`, {ref}`kw-ionRateProbe`). A plain build prints “unrecognised keyword” for them ({src}`set_input_mod.f90::readInput@"unrecognised keyword in model parameter input file"`) and runs on the defaults: the matrix solve on, a starting $x(\mathrm H^0)$ of $10^{-5}$ in every cell ({src}`grid_mod.f90::setMotherGrid@"H0in = initH0 ! D-160"`), no damping, no probes. `H0Start` and `NeStart` are parsed by every build and read by nothing ({ref}`kw-H0Start`, {ref}`kw-NeStart`; {lim}`L-77`).

(sec:moc-ion-dead)=
## Code that is compiled but never acts, or not compiled
{bdg-secondary}`dead` {bdg-dark}`not compiled`

`initXSecArray` also tabulates cross sections of the excited levels of H I ($n\le10$, fits that the comment traces to Cloudy), He II ($n\le9$) and He I (power laws), which nothing reads ({src}`ph_mod.f90::initXSecArray@"! Balmer, Paschen etc. continua (up to n= 10)"`); `H2plusXSec` and `HFit` are never called ({src}`ph_mod.f90::H2plusXSec`, {src}`ph_mod.f90::HFit`); the pointers for secondary ionisation and Compton recoil are set and never used ({src}`hydro_mod.f90::setPointers@"call locate(nuArray,7.353,secIonP)"`). The Compton heating and cooling arrays are allocated only if `lgCompton` is true, and no keyword sets it ({src}`ph_mod.f90::initXSecArray@"if (lgCompton) then"`; {lim}`L-77`). The X-ray fluorescence code of {cite:t}`Ercolano2008` ({src}`fluorescence_mod.f90`, {src}`mocassinFluorescence.f90`) and a second copy of the Gaunt-factor routine ({src}`gaunt.f90`) are not in the Makefile's `SOURCES` ({src}`Makefile@"SOURCES = source/constants_mod.o"`).
