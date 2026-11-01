(sec:moc-thermal)=
# The thermal balance

In every cell MOCASSIN finds the electron temperature at which the heating equals the cooling, both per hydrogen nucleus, with the ionisation and the grain charges re-solved at every trial temperature ({cite:t}`Ercolano2003`). `thermBalance` computes the two sums ({src}`update_mod.f90::updateCell/thermBalance`) and `iterateT` searches for the root ({src}`update_mod.f90::updateCell/iterateT`). This chapter covers MOCASSIN's own terms; the molecular cooling and the extra heating that the PDR builds add, the H$_2$–grain exchange and the coolant atoms are in {ref}`sec:thermal` of {doc}`../pdr/feedback`. With `traceHeating` ({ref}`kw-traceHeating`, {bdg-warning}`not exercised`) rank 0 writes the terms of each cell it updates to `output/thermalBalance.out` ({src}`iteration_mod.f90::MCIterationDriver/iterateMC@"output/thermalBalance.out"#1`; {ref}`out-thermalBalance_out`).

(sec:moc-th-balance)=
## The terms
{bdg-success}`used`

The balance solved is

$$
\mathcal G_{\mathrm{ph}}+\mathcal G_{\mathrm{pe}}\;[+\,\mathcal G_{\mathrm{PDR}}]
 = \Lambda_{\mathrm{ff}}+\Lambda_{\mathrm{rec}}+\Lambda_{\mathrm H}+\Lambda_{\mathrm{CEL}}+\Lambda_{\mathrm{gd}}\;[+\,\Lambda_{\mathrm{mol}}]
 \quad[\mathrm{erg\,s^{-1}}\ \text{per H nucleus}],
$$ (eq:moc-thbal)

photoionisation and grain photoelectric heating against free–free, recombination, hydrogen collisional-excitation and collisionally excited line cooling and the gas–grain exchange, the bracketed terms in the PDR builds only ({src}`update_mod.f90::updateCell/thermBalance@"coolInt = coolFF + coolRec + coolColl"`, {src}`update_mod.f90::updateCell/thermBalance@"if (lgDust .and. lgPhotoelectric) then"#1`). There is no cooling by the collisional excitation of helium, no free–free or recombination cooling by ions heavier than helium, no Compton heating or cooling (the code for it is never enabled, {lim}`L-77`) and, outside the PDR builds, no cosmic-ray heating.

(sec:moc-th-photo)=
## Photoionisation heating
{bdg-success}`used`

Each stage contributes the kinetic energy of its photoelectrons on the Monte Carlo field,

$$
\mathcal G_{\mathrm{ph}} = \sum_{X,i}A_X\,x_{X,i}\sum_{k=k_0}^{k_1}\sigma_{X,i}(\nu_k)\,J^{\mathrm{ste}}_k\,\frac{\nu_k-\nu_{k_0}}{\nu_k},
$$ (eq:moc-heatph)

with $k_0$ the bin of the threshold and $J^{\mathrm{ste}}_k$ the band-integrated field of {numref}`tab:notation` ({src}`update_mod.f90::updateCell/thermBalance@"heatIonSte = heatIonSte + phXSec*grid%Jste(cellP,j)*&"+1`, {src}`update_mod.f90::updateCell/thermBalance@"heatIonSte = heatIonSte*ionDenUsed(elementXref(elem),ion)*&"+1`). The cross sections and the outer-shell restriction are those of the rates ({doc}`ionisation`): inner shells add no heat ({lim}`L-64`). The sum runs to the shell's upper pointer and stops at the first cross section below $10^{-35}$ cm$^2$, whereas the rate stops one bin lower and skips such values ({src}`update_mod.f90::updateCell/thermBalance@"highNuP = elementP(elem, ion, outShell, 2)"`, {src}`update_mod.f90::updateCell/thermBalance@"if ((phXSec < 1.e-35) ) then"+2`; {lim}`L-76`). The field is the one transported in the iteration; it does not change during the temperature search, but the ion fractions it is weighted with do.

(sec:moc-th-ffrec)=
## Free–free and recombination cooling
{bdg-success}`used`

For H$^+$, He$^+$ and He$^{2+}$ the code uses fits to the energy-loss coefficients of {cite:t}`Hummer1994` and {cite:t}`HummerStorey1998`,

$$
\Lambda_j = x_j\,A_j\,n_e\,k\,T\,\frac{\beta_j(T)}{\sqrt T},
$$ (eq:moc-coolff)

with $\beta_j$ a polynomial in $\log_{10}T$ (fourth order, second for He$^+$ free–free) and, for He$^{2+}$, the hydrogenic scaling of the coefficients of {cite:t}`Hummer1994`: $\beta(T)/\sqrt T$ becomes $Z\,\beta(T/Z^2)/\sqrt{T/Z^2}$ with $Z=2$, i.e. $\beta(T,Z)=Z^2\beta(T/Z^2,1)$ in Eq. ({eq}`eq:moc-coolff`) ({src}`update_mod.f90::updateCell/thermBalance@"! cooling of gas due to FF radiation from H+"..@"coolFF = Np*NeUsed*betaFF*kBoltzmann*TeUsed/sqrt(TeUsed)"`, {src}`update_mod.f90::updateCell/thermBalance@"! cooling of gas due to FF radiation from He++"..@"coolRec = coolRec + Np*NeUsed*betaRec*kBoltzmann*TeUsed/sqrt(TeUsed/4.)"`, {src}`update_mod.f90::updateCell/thermBalance@"! fits to Hummer and Storey, MNRAS 297(1998) 1073, Table 6. least square fitting to m=4"..@"coolFF = coolFF + Np*NeUsed*betaFF*kBoltzmann*TeUsed/sqrt(TeUsed)"`). The recombination coefficients are **Case A**, $\beta_A=\beta_B+\beta_1$, since {devlog}`D-286`: MOCASSIN transports the ground-state recombination continuum and counts its re-absorption in the photoionisation heating, so the energy those recombinations remove must be counted too ({src}`update_mod.f90::updateCell/thermBalance@"! cooling of gas due to recombination of H+"..@"coolRec = Np*NeUsed*betaRec*kBoltzmann*TeUsed/sqrt(TeUsed)"`). {devlog}`D-327` checked that this holds when Ly$\alpha$ is not transported. He$^+$ recombination takes the He-specific fit of {cite:t}`HummerStorey1998` up to $\log_{10}T=4.4$, the end of their table, and the hydrogenic Case A fit above it; the two do not meet, so the term steps by 24% at 25 100 K ({src}`update_mod.f90::updateCell/thermBalance@"! cooling of gas due to recombination of He+ [D-286]"..@"coolRec = coolRec + Np*NeUsed*betaRec*kBoltzmann*TeUsed/sqrt(TeUsed)"`).

(sec:moc-th-hcoll)=
## Collisional excitation of hydrogen
{bdg-success}`used`

Above 5000 K the excitation of H$^0$ to $n=2$ and 3 by electrons cools at

$$
\Lambda_{\mathrm H} = x(\mathrm H^0)\,n_e\,h\nu_{1\,\mathrm{Ryd}}
  \bigl[2.47\times10^{-8}\,t_4^{-0.228}\,e^{-118\,338/T}+1.32\times10^{-8}\,t_4^{-0.460}\,e^{-140\,252/T}\bigr],
$$ (eq:moc-hcoll)

fits the comment attributes to “Mathis” without a reference ({src}`emission_mod.f90::hICollExc`). Each excitation is charged 1 Ryd, while the Boltzmann factors use the right thresholds, so the Ly$\alpha$ term is 4/3 and the Ly$\beta$ term 9/8 too large ({lim}`L-65`); at $10^4$ K, however, the fit's coefficients are 0.75–0.83 of the $1s$–$2$ rate from standard collision strengths, which suggests that they already carry the 3/4, and the point is not settled ({devlog}`D-447`). It matters where H$^0$ and electrons coexist above 5000 K: ionisation fronts and partly ionised cells. Since {devlog}`D-447` the same terms are also emitted ({src}`emission_mod.f90::emissionDriver/RecLinesEmission@"call hICollExc(TeUsed, q12H, q13H)"`): the $n=2$ term and 27/32 of the $n=3$ term as Ly$\alpha$, 5/32 of the $n=3$ term as H$\alpha$ (Case B), in the re-emission spectrum, the grains' Ly$\alpha$ heating and the reported lines. Before, the energy they cooled was re-emitted with the shape of the remaining gas emission, part of it Lyman continuum that ionized again ({devlog}`D-446`; {lim}`L-90`): in `test_Problem` the gas recombined 1.16 times the star's hydrogen-ionising photons, and 0.99 with the fix.

(sec:moc-th-cel)=
## Collisionally excited lines
{bdg-success}`used`

`forLines` solves the level populations of every heavy-element ion with data at the trial temperature and $n_e$ (`equilibrium`, {doc}`emission`) and converts the emissivities, in cm$^{-1}$ s$^{-1}$ per H nucleus, to erg ({src}`update_mod.f90::updateCell/forLines`, {src}`update_mod.f90::updateCell/forLines@"forbiddenLines = forbiddenLines*1.9865e-16"`). `thermBalance` adds the transitions between levels 1–10 of each ion ({src}`update_mod.f90::updateCell/thermBalance@"! sum all contributions from the heavies to coolColl"+12`), although an atom may have up to 17 levels, and never adds Fe II's 142-level array: those transitions are emitted and reported but do not cool the gas ({lim}`L-67`; 2$\times10^{-8}$ to 1.4$\times10^{-4}$ of the forbidden-line luminosity in the Lexington runs, Fe being off in every fixture). The same atoms give the transported and the reported lines. In the PDR builds the C I, C II and O I atoms also take the chemistry's neutral colliders and escape probabilities ({devlog}`D-363`, {devlog}`D-418`; {doc}`../pdr/feedback`).

(sec:moc-th-grain)=
## Grain charge and photoelectric heating
{bdg-success}`used` (dust + gas runs)

With dust and gas, and unless `noPhotoelectric` is given ({ref}`kw-noPhotoelectric`, {src}`set_input_mod.f90::readInput@"case (\"noPhotoelectric\")"`), `iterateT` finds at every trial temperature the potential $V$ of each grain species and size ({src}`update_mod.f90::updateCell/iterateT@"if (lgDust .and. lgGas .and. lgPhotoelectric) then"`). `setGrainPotential` solves, by secant steps from $V=0$ limited to 5% of the photoelectric threshold, to 0.5% and in at most 100 steps ({src}`update_mod.f90::updateCell/setGrainPotential`, {src}`update_mod.f90::updateCell/setGrainPotential@"real,parameter :: errorLim = 0.005, dm = 0.05 ! loop convergence"`),

$$
\sum_{\nu_k\ge\nu_{\mathrm{th}}}\hat Y_k\,Q^{\mathrm{abs}}_k\,\frac{J^{\mathrm{ste}}_k}{h\nu_k}
 = n_e\,\bar v_e\,S_e\,\eta_e-\sum_{X,\,i\ge2}n(X^{(i-1)+})\,\bar v_X\,\eta_{X,i},
$$ (eq:moc-grainq)

photoemission against the collection of electrons and ions per unit geometric cross section, with $h\nu_{\mathrm{th}}=\max(W+V,W)$ for the work function $W$, $\hat Y=Y_n\min[1,\max(0,\,1-V/(h\nu-W))]$, $\bar v=\sqrt{8kT/\pi m}$ and the Coulomb factor $\eta=1-\psi$ for $\psi=ZeV/kT\le0$ and $e^{-\psi}$ otherwise (`getGrainEmission`, `getGrainRecombination`, after eqs. 18–24 of {cite:t}`Baldwin1991`; {src}`update_mod.f90::updateCell/getGrainEmission`, {src}`update_mod.f90::updateCell/getGrainRecombination`). The project changed three of its ingredients: the neutral yield $Y_n$ is that of {cite:t}`WeingartnerDraine2001`, from the table the heating also uses ({devlog}`D-289`); the photoemission term carried a spurious factor $4\pi^2$, so the balance converged with the grains more positively charged than their field implies ({devlog}`D-290`); and the electron sticking is $S_e=\frac12(1-e^{-a/10\,\text{\AA}})$ instead of 1, ions sticking with 1 ({src}`update_mod.f90::updateCell/getGrainRecombination@"S = 0.5 * (1. - exp(-grainRadius(ai)/1.e-3))"`; {devlog}`D-325`, {devlog}`D-326`). The photoelectric heating of the gas is then

$$
\mathcal G_{\mathrm{pe}} = \frac{N_d}{n_{\mathrm H}}\sum_{s,a}f_s\,w_a\sum_{\nu_k\ge\nu_{\mathrm{th}}}\sigma^{\mathrm{abs}}_{s,a}(\nu_k)\,\frac{J^{\mathrm{ste}}_k}{h\nu_k}\,
  \bigl[E_{Y,k}-\hat Y_k\,V_{s,a}\bigr],\qquad
  E_Y = \tfrac12\,Y_n\min\Bigl(h\nu-W,\ \max\Bigl[0,\frac{(h\nu-W)^2-V^2}{h\nu-W}\Bigr]\Bigr),
$$ (eq:moc-pe)

The code starts this sum one frequency bin below the photoemission sum of the charge balance, Eq. ({eq}`eq:moc-grainq`) ({lim}`L-76`).

the mean photoelectron energy less the work done against the grain's potential, summed over species $s$ (abundance $f_s$) and sizes $a$ (weight $w_a$) ({src}`update_mod.f90::updateCell/setPhotoelHeatCool`). The same routine returns the grains' photoelectric cooling to the dust balance ({doc}`dust`). PAHs heat the gas only if they are in the input as a species; no PDR fixture has them ({lim}`L-7`), while `test_Problem` has neutral PAHs at a number abundance of 0.02 ({doc}`dust`).

(sec:moc-th-gd)=
## Gas–grain collisional exchange
{bdg-success}`used` (dust + gas runs)

`setDustGasCollHeatCool` sums, over grain species and sizes, the energy carried by every atom, ion and electron that strikes a grain, $\pi a^2\,n_j\,S_j\,\bar v_j\,(2kT\xi_j-2kT_d\eta_j)$ for atoms and ions and $\pi a^2\,n_e\,\bar v_e\,2kT\xi_e$ for electrons, with $\xi$ the Coulomb factor of the energy flux ({src}`update_mod.f90::updateCell/setDustGasCollHeatCool`). Neutrals have the accommodation coefficient $2mM/(m+M)^2$ for a surface atom of mass $M$, with both masses in amu since {devlog}`D-129`, ions and electrons 1 ({src}`update_mod.f90::updateCell/setDustGasCollHeatCool@"S = 2.*aWeight(elem)*MsurfAtom(global_ns)/&"+1`); the ionisation energy released by a recombining ion enters the grains' balance only, and is zero for neutrals since {devlog}`D-127` found it read uninitialised ({src}`update_mod.f90::updateCell/setDustGasCollHeatCool@"IPerg = 0."`). The gas term is per H nucleus and the grains' divided by $\pi$, their field convention, since {devlog}`D-421`. The PDR builds add H$_2$ as a collider ({devlog}`D-420`; {doc}`../pdr/feedback`). The grain charge, the photoelectric heating and this exchange are computed only if dust and gas are both present and `noPhotoelectric` is not given: that keyword switches off all three ({src}`update_mod.f90::updateCell/thermBalance@"if (lgDust .and. lgPhotoelectric) then"#1`).

(sec:moc-th-search)=
## The temperature search
{bdg-success}`used`

`iterateT` makes up to 50 steps ({src}`update_mod.f90::updateCell@"maxIterateT = 50"`). At each it computes the recombination coefficients and solves the ionisation balance at the trial $T$ ({doc}`ionisation`), then the grain potentials and the gas–grain terms, then the balance; the residual $R=\mathcal G-\Lambda$ is accepted when $|R|<0.01\,\mathcal G$ ({src}`update_mod.f90::updateCell@"thLimit = 0.01"`, {src}`update_mod.f90::updateCell/iterateT@"lgTOk = abs(thResidual) < thLimit * heatInt"`). It starts from the cell's temperature of the previous iteration, and in the first iteration from `TeStart`, 10 000 K by default ({src}`grid_mod.f90::setMotherGrid@"grid%Te(grid%active(i,j,k)) = TeStart"`; {ref}`kw-TeStart`). The upstream recursive version is kept as a comment above it.

- **`teSolver 0`, the default.** Regula falsi between the two latest temperatures of opposite sign; until both exist, $T$ is multiplied or divided by 1.2. From the sixth step, a bracket narrower than 0.2% of its sum is broken by a step of 100 K up from the lower end when the residual is negative, or down from the upper end when it is positive, and that end is dropped; below about 25 000 K such a bracket is narrower than 100 K, so the step lands beyond the other end ({src}`update_mod.f90::updateCell/iterateT@"TeUsed = TeUsed / 1.2 ! Too hot, cool it down"`, {src}`update_mod.f90::updateCell/iterateT@"if (nIterateT >= 6) then"`).
- **`teSolver 1`** ({devlog}`D-165`). The Illinois variant, which halves the retained end's residual when the same end is kept twice; bisection when the interpolant leaves the bracket; unbracketed steps of 20% of $T$; a narrow bracket with a large residual, the sign of a discontinuity, restarts the search from its midpoint with a wider step, at most twice; the test uses $|\mathcal G|$, so a cell with net negative heating can pass ({src}`update_mod.f90::updateCell/iterateT@"if (lastSide == 2 .and. Tlow > 0.) thResidualLow = 0.5*thResidualLow"`, {src}`update_mod.f90::updateCell/iterateT@"if (abs(Thigh - Tlow) <= 0.002*(Thigh + Tlow) .and. nRestart < 2) then"`).
- **`teSolver 2`** ({devlog}`D-165`) adds the condition that the bracket be narrower than $0.01/3$ of $T$, as Cloudy requires, since where $R$ depends weakly on $T$ the residual test alone passes at a temperature the solver has not determined ({src}`update_mod.f90::updateCell/iterateT@"lgTOk = abs(Thigh - Tlow) <= (thLimit/3.)*TeUsed"`); {devlog}`D-166` counted the cells whose residual stays flat to 1% across the search.

Every step is clamped to $[$`teFloor`$,\,30\,000$ K$]$ ({src}`update_mod.f90::updateCell/iterateT@"if (TeUsed < teFloor) TeUsed = teFloor"+2`). The floor was 10 K, hardcoded, until {devlog}`D-165` exposed it; its default is the CMB temperature, 2.725 K, since {devlog}`D-403` ({src}`common_mod.f90@"real :: teFloor = real(TcmbK)"+0`). The ceiling came with commit 7c69d3b (2025-08-19), as “the atomic data limit for H”: the continuum tables and the H I emissivity table both end at 30 000 K ({doc}`emission`). `teSolver`, `teFloor` and the `teProbe` diagnostics are parsed only by the PDR builds ({ref}`kw-teSolver`, {ref}`kw-teFloor`, {ref}`kw-teProbe`); a plain build always runs `teSolver 0` with the 2.725 K floor.

A cell is flagged “black” when the search ends without convergence (its temperature is then the middle of the last bracket, or its one known end), when it ends at or above 30 000 K, or when the ionisation balance was not reached ({src}`update_mod.f90::updateCell/iterateT@"if (.not. lgTConverged) then"`, {src}`update_mod.f90::updateCell/iterateT@"if (TeUsed >= 30000.) grid%lgBlack(cellP) = 1 ! Flag this cell as problematic"`, {src}`update_mod.f90::updateCell/iterateT@"if (.not. lgIBConv) then"`). Black cells keep their values for the next iteration but are left out of every volume integral of `outputGas`: the line fluxes, the mean temperatures and the ionic fractions ({src}`output_mod.f90::outputGas@"if (grid(iG)%lgBlack(grid(iG)%active(i,j,k))<1 .and. lgInSlit ) then"+0`). `iterDamp`, a PDR-build keyword with default 0, would mix each new temperature with the iteration-start one ({devlog}`D-406`; {src}`iteration_mod.f90::MCIterationDriver/iterateMC@"if (lgGas .and. iterDamp > 0.) then"`).

(sec:moc-th-percell)=
## Per-cell convergence
{bdg-success}`used`

After the search a gas cell counts as converged when both $|\Delta x(\mathrm H^0)/x(\mathrm H^0)|$ and $|\Delta T/T|$, measured against their values at the start of the Monte Carlo iteration, are at most `convLimit`, 0.05 by default ({src}`update_mod.f90::updateCell/iterateT@"lgCvH0 = abs(deltaXHI) <= XHILimit"+0`, {src}`update_mod.f90::updateCell/iterateT@"lgCvTe = abs(TeUsed - grid%TeIterStart(cellP))"+1`; {ref}`kw-convLimit`). The reference was the start of the call until {devlog}`D-155`, the temperature joined the test with {devlog}`D-229`, and {devlog}`D-180` found that `convLimit` sets this per-cell tolerance, not the share of converged cells. The PDR builds test $x(\mathrm H_2)$ after the chemistry ({devlog}`D-391`). The converged share is reported; the run stops on the model-integrated test of `convTotals` ({devlog}`D-391`, {devlog}`D-392`; {ref}`running-convergence`, {doc}`iteration`).
