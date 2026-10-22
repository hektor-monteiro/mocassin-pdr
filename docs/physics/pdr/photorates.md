(sec:photorates)=
# Reaction rates handed to the chemistry
The chemistry’s rate coefficients are computed per cell in `pdrStep` ({src}`pdr_mod.f90::pdrStep`) by 3D-PDR’s `CALCULATE_REACTION_RATES` ({src}`pdr/calc_reac_rates.F90`), called at {src}`pdr_mod.f90::pdrStep@"call CALCULATE_REACTION_RATES(Tg, Td, nChem, radSurf, AVray, &"` with MOCASSIN’s inputs, and then partly overwritten with rates that MOCASSIN or the level model own. {numref}`tab:rateorigin` summarises where each radiation-driven rate comes from; reaction numbers are those of `dataPDR/rates_reduced.d`.

:::{list-table} Origin of the radiation- and cosmic-ray-driven rates in the 3D build.
:name: tab:rateorigin
:header-rows: 1
:widths: 28 15 37 9

* - Reaction(s)
  - Number(s)
  - Rate used
  - Section
* - H$_2$ + $h\nu\to$ 2H
  - 329
  - the level model’s $k_{\mathrm{Sol}}$
  - {ref}`sec:h2rate`
* - CO + $h\nu\to$ C + O
  - 290
  - $\alpha_{\mathrm{CO}}\sum_r\chi_rf_r\Theta$ {cite:p}`vanDishoeckBlack1988`
  - {ref}`sec:co`
* - 24 other photoreactions
  - 266–268, 270–288, 291–292
  - $\alpha\chi$ (Draine spectral shape)
  - {ref}`sec:generic`
* - C, Mg + $h\nu\to$ ion + $e^-$
  - 269, 289
  - set to zero
  - {ref}`sec:linked`
* - ionisation of H, He, C, O, Mg
  - 293, 297, 298, 299, 312
  - cosmic-ray (or, Mg, induced-photon) rate plus MOCASSIN’s photoionisation rate
  - {ref}`sec:linked`
* - H$_2$ + CRP $\to$ H$_2^+$ + $e^-$
  - 296
  - cosmic-ray rate plus MOCASSIN’s H$_2$ photoionisation
  - {ref}`sec:linked`
* - X$^+$ + $e^-\to$ X + $h\nu$ (X = H, He, C, O, Mg)
  - 242–246, 248, 249
  - MOCASSIN’s total recombination coefficient
  - {ref}`sec:linked`
* - cosmic-ray ionisation
  - 293–300
  - $\alpha\,\zeta/\zeta_0$
  - {ref}`sec:cr`
* - cosmic-ray-induced photoreactions
  - 301–315
  - $\alpha(\zeta/\zeta_0)(T/300)^\beta\gamma/(1-\omega)$
  - {ref}`sec:cr`
* - charge transfer with H, H$^+$
  - 156–157, 161–163, 167
  - `pdrCtCoef`
  - {ref}`sec:ct`
* - H + H (grain) $\to$ H$_2$
  - 328
  - {cite:t}`CazauxTielens2002`
  - {ref}`sec:formation`
:::

(sec:rays)=
## The field as a set of rays
3D-PDR evaluates each photoreaction as a sum over rays, each ray $r$ carrying a field strength $\chi_r$ (in Draine units), a visual extinction $A_{V,r}$ and shielding columns. In the 3D build the bridge builds $n_{\mathrm{chem}} = 1 + N_{\mathrm{site}}$ (+1 fallback) rays ({src}`pdr_mod.f90::pdrStep@"iDifFb = 0"..@"if (nChem > 1) pdrRayLW(1:nChem-1) = fDif"`, {devlog}`D-348`, {devlog}`D-350`), which represent the local MC field split by the paths its photons took ({ref}`sec:split` and {ref}`sec:sites`):

:::{list-table} The rays handed to the chemistry in the 3D build.
:name: tab:rays
:header-rows: 1
:widths: 17 20 10 17 24

* - Ray
  - $\chi_r$
  - $A_{V,r}$
  - LW factor
  - Columns $N(\mathrm{H_2}),N(\mathrm{CO})$
* - 0 (direct)
  - $\chi_{\mathrm{dir}}$
  - 0
  - $f_{\mathrm{dir}}$
  - source-ward, Eq. ({eq}`eq:avradial`)
* - site $j$
  - $\chi_{\mathrm{dif}}\,w_j/\sum w$
  - 0
  - $f_{\mathrm{dif}}$
  - two-leg, Eq. ({eq}`eq:twoleg`)
* - fallback
  - $\chi_{\mathrm{dif}}$
  - 0
  - $f_{\mathrm{dif}}$
  - source-ward (only when $\chi_{\mathrm{dif}}>0$ and no site exists)
:::

$A_{V,r}=0$ on every ray ({src}`pdr_mod.f90::pdrStep@"AVray = 0.d0"`) because the MC field has already been attenuated by the dust; applying 3D-PDR’s $e^{-\gamma A_V}$ again would count the dust twice ({devlog}`D-343`, {devlog}`D-350`). The C I column handed over is zero ({src}`pdr_mod.f90::pdrStep@"colC = 0.d0"`) because MOCASSIN’s opacity already contains the C I photoionisation continuum; the HD and S columns are zero (neither species is in the network). If a source-ward column is missing (negative), it falls back to $(A_{V}/(A_{V}/N_{\mathrm H}))\,x_X$ ({src}`pdr_mod.f90::pdrStep@"NHcol = av/AVfacL"`, {src}`pdr_mod.f90::pdrStep@"if (sH2 < 0.d0) sH2 = NHcol*abun(NH2)"`); zero is a valid column and is kept ({devlog}`D-088`). The columns exclude the target cell ({ref}`sec:avradial`); only the level model averages the shielding through the cell’s own gas ({ref}`sec:ownavg`).

(sec:generic)=
## Generic photoreactions
For every reaction $X+\mathrm{PHOTON}\to\ldots$ without a dedicated treatment, 3D-PDR’s rate is $k=\sum_r\alpha\,\chi_r\,e^{-\gamma A_{V,r}}$ \[s$^{-1}$\] ({src}`pdr/calc_reac_rates.F90::CALCULATE_REACTION_RATES@"RATE(I)=RATE(I) + ALPHA(I)*RAD_SURFACE(K)*EXP(-(GAMMA(I)*AV(K)))"+23`), with $\alpha$ the rate in the unattenuated Draine field and $\gamma$ the dust-attenuation exponent of the UMIST format; with $A_{V,r}=0$, 

$$
k = \alpha\,(\chi_{\mathrm{dir}}+\chi_{\mathrm{dif}}) = \alpha\,\chi ,
$$ (eq:generic)

 the coefficient $\alpha$ of the rate file times the local MC field in the 6–13.6 eV band. This applies to the photodissociation and photoionisation of H$_2^+$, H$_3^+$, CH, CH$^+$, CH$_2$, CH$_2^+$, CH$_3$, CH$_3^+$, CH$_4$, OH, OH$^+$, H$_2$O and O$_2$ (24 of the network’s 28 photoreactions). The coefficients $\alpha$ were computed for the Draine spectral shape, while the MC field reddens with depth: its LW share falls from 0.30 to 0.008 through `hiipdr`’s PDR ({devlog}`D-349`). Reactions whose cross sections lie mainly above 11.2 eV are therefore overestimated at depth, and those driven by the 6–11 eV part underestimated; none of these reactions is shielded by H$_2$ or CO lines. Rates computed from cross sections folded over the actual field would remove the assumption; {cite:t}`Heays2017` provide cross sections for 102 species for that purpose, and find that their rates for the interstellar field agree with earlier compilations to about 30% in general.

(sec:h2rate)=
## H$_2$ photodissociation: the level model’s rate
3D-PDR first computes its own rate on the rays (`H2PDRATE`, `H2SHIELD1`; {src}`pdr/shield.F90::H2PDRATE`, {src}`pdr/shield.F90::H2SHIELD1`; {src}`pdr/calc_reac_rates.F90::CALCULATE_REACTION_RATES@"! Store the reaction number for H2 photodissociation. The rate itself"..@"IF(PRODUCT(I,1).EQ.\"H \" .AND. PRODUCT(I,2).EQ.\"H \") NRH2=I"`), 

```{math}
k^{\mathrm{net}}_{\mathrm{H_2}} = \sum_r \alpha_{\mathrm{H_2}}\,\chi_r f_r\,
     J_{\mathrm{FGK}}(N_{\mathrm{H_2},r})\,\mathrm{SCATTER}(0,1000\,\text{\AA}),
  \qquad \alpha_{\mathrm{H_2}}=5.18\times10^{-11}\,\mathrm{s^{-1}},
```

 where $J_{\mathrm{FGK}}=J_D+J_R$ is the single-line self-shielding function of {cite:t}`Federman1979`, their eqs. A7--A9 for one representative line at 1000 Å with oscillator strength 0.01, half the H$_2$ in its lower level, a Doppler width $v_{\mathrm{turb}}/\lambda$ and a radiative width of $8\times10^7$ s$^{-1}$ ({src}`pdr/shield.F90::H2PDRATE@"LAMBDA=1000.0D0"..@"H2PDRATE=K0*G0*H2SHIELD1(NH2,DOPW,RADW)*SCATTER(AV,LAMBDA)!/2.0"`, {src}`pdr/shield.F90::H2SHIELD1@"!C Calculate the optical depth at line centre = N(H2)*f_para*(πe^2/mc)*f/(√πß) ≈ N(H2)*f_para*(1.5E-2)*f/ß"..@"TAUD=NH2*FPARA*(1.497358985D-2)*FOSC/DOPW"`). The bridge then replaces it with the level model’s Solomon rate ({devlog}`H-012`): 

```{math}
k(\mathrm{H_2}+h\nu\to2\mathrm H) = k_{\mathrm{Sol}}
```

set at {src}`pdr_mod.f90::pdrStep@"if (allocated(grid%h2Sol) .and. NR2 > 0) pdrRate(NR2) = dble(max(grid%h2Sol(cellP), 0.))"`.

 The same rate is handed to 3D-PDR’s heating routine, but the H$_2$ heating terms used are the level model’s ({ref}`sec:thermal`); 3D-PDR’s are kept for comparison. The network’s own rate is kept as a diagnostic (`h2SolChem`, on the same field split and columns). On `hiipdr` the level model’s rate is 2.4–2.6 times the network’s in the ionised gas, 1.5–1.8 times in cold unshielded gas, and 0.6–0.7 and 0.4–0.6 times behind source-ward columns of $10^{15}$–$10^{17}$ cm$^{-2}$ and more ({devlog}`H-007`). Three things separate them: the level model’s rate in the unshielded Draine field is 1.23 times $\alpha_{\mathrm{H_2}}$ and the stellar field is harder; in warm gas the molecules sit in excited levels that dissociate faster; and the network shields one line of fixed radiative width at the near face of the cell, whereas the level model averages every line through the cell and includes overlap.

(sec:co)=
## CO photodissociation
`COPDRATE` ({src}`pdr/shield.F90::COPDRATE`; called at {src}`pdr/calc_reac_rates.F90::CALCULATE_REACTION_RATES@"IF(REACTANT(I,1).EQ.\"CO \" .AND. REACTANT(I,3).EQ.\" \" .AND. &"..@"NRCO=I"`): 

```{math}
k_{\mathrm{CO}} = \alpha_{\mathrm{CO}}\sum_r \chi_r\,f_r\;
     \Theta\bigl(N_{\mathrm{CO},r},N_{\mathrm{H_2},r}\bigr)\;\mathrm{SCATTER}(0,\bar\lambda),
  \qquad \alpha_{\mathrm{CO}} = 2.0\times10^{-10}\,\mathrm{s^{-1}},
```

 with $\alpha_{\mathrm{CO}}$ from the rate file (reaction 290). $\Theta$ is the combined CO self-shielding and H$_2$ screening factor for $^{12}$CO of {cite:t}`vanDishoeckBlack1988`, their Table 5, interpolated by a two-dimensional cubic spline in $\log_{10}\Theta$ over $(\log_{10}N_{\mathrm{CO}},\log_{10}N_{\mathrm{H_2}})$ and clamped at the table edges (`COSHIELD`, {src}`pdr/shield.F90::COSHIELD`). The table spans $N(\mathrm{CO})=10^{13}$–$10^{19}$ and $N(\mathrm{H_2})=10^{19}$–$10^{23}$ cm$^{-2}$ plus the unshielded entries, which 3D-PDR places at $10^{12}$ and $10^{18}$ cm$^{-2}$ ({src}`pdr/modules.F90@"real(kind=dp), dimension(8), save :: NCO_GRID=(/&"`, {src}`pdr/allocations.F90::allocations@"SCO_GRID(1:8,1) = (/0.000D+00,-1.408D-02,-1.099D-01,-4.400D-01,-1.154D+00,-1.888D+00,-2.760D+00,-4.001D+00/)"..@"SCO_GRID(1:8,6) = (/-3.883D+00,-3.888D+00,-3.936D+00,-4.197D+00,-4.739D+00,-5.165D+00,-5.441D+00,-6.446D+00/)"`); smaller columns are treated as these. $\bar\lambda$ is the mean wavelength of the 33 dissociating bands weighted by their contributions to the total rate at the given columns, at which the dust attenuation is evaluated (`LBAR`, their eq. 4, {src}`pdr/shield.F90::LBAR`): 

$$
\bar\lambda = \bigl[(5675-200.6\,w) - (571.6-24.09\,w)\,u + (18.22-0.7664\,w)\,u^2\bigr]\ \text{\AA},
$$ (eq:lbar)

 with $u=\log_{10}N_{\mathrm{CO}}$ and $w=\log_{10}N_{\mathrm{H_2}}$ \[cm$^{-2}$\], clamped to 913.6–1076.1 Å. With $A_V=0$, $\mathrm{SCATTER}=1$ and $\bar\lambda$ has no effect. The window factor $f_r$ corrects for the spectral shape of the MC field in the LW window ({ref}`sec:window`); CO is the one photoreaction in the 3D build that uses it. The columns are those of the chemistry’s own $n(\mathrm{H_2})$ and $n(\mathrm{CO})$, on the source-ward or two-leg paths, and exclude the target cell, so CO is under-shielded in the cells of its own transition ({ref}`sec:limitations`).

The shielding functions of {cite:t}`vanDishoeckBlack1988` were computed for the unmodified Draine field, cool gas ($T\lesssim100$ K, CO excitation temperature 10 K), Doppler parameters of 1 km s$^{-1}$ for CO and 3 km s$^{-1}$ for H$_2$ and a fixed H I column of $5\times10^{20}$ cm$^{-2}$ (notes to their Table 5). {cite:t}`Visser2009` recomputed them from newer spectroscopic data and find an unattenuated rate of $2.6\times10^{-10}$ s$^{-1}$, 30% above the 2.0$\times10^{-10}$ used here, and depth-dependent rates that change by up to a factor of three when the excitation temperature or the Doppler width is raised, for temperatures above 100 K. The warm CO of the illuminated PDR is therefore outside the conditions of the table, and the H$_2$ screening uses the chemistry’s total H$_2$ column rather than the level model’s line-by-line transmission ({ref}`sec:limitations`).

(sec:linked)=
## Photoionisation and recombination of the linked atoms
Five elements are *linked*: their neutral and first ion are species of the network and stages of MOCASSIN (H, He, C, O, Mg; {src}`pdr_mod.f90::initPDRnetwork@"call linkIon( 1, pdrNHsp, 1, 1) ! H -> H I"..@"call linkIon(10, NMGx, 12, 2) ! Mg+ -> Mg II"`). For them the network’s own photoionisation is replaced by MOCASSIN’s, computed on the full MC field with the real cross sections ({devlog}`D-358`; {src}`pdr_mod.f90::pdrStep@"if (allocated(grid%pdrPhotRate)) then"..@"& + dble(max(grid%pdrPhotRate(cellP,6), 0.))"`; slots found by structure at {src}`pdr_mod.f90::initPDRnetwork@"! D-358: the slots MOCASSIN's own ionization and recombination rates"..@"print '(a,i4)', \" ! H2 -> H2+ slot\", iH2cr358"`):

- the network reaction $X+\mathrm{PHOTON}\to X^++e^-$ is set to zero where it exists (C, reaction 269; Mg, 289; the network has none for H, He and O);

- MOCASSIN’s photoionisation rate from the ground state 

$$
\Gamma_X = \sum_k \frac{J^{\mathrm{ste}}_k\,\sigma_X(\nu_k)}{h\nu_k}\quad[\mathrm{s^{-1}}]
$$ (eq:gammaX)

 ({src}`update_mod.f90::updateCell@"nPhotoSte(elem,ion) = nPhotoSte(elem,ion) + &"..@"& grid%JSte(cellP,j)*phXSec/(hcRyd*nuArray(j))"`; outer-shell cross sections of {cite:t}`Verner1996` and {cite:t}`VernerYakovlev1995`, {src}`ph_mod.f90@"! outer shell of the Opacity Project (OP) elements: Verner, Ferland, Korista"`) is added to the reaction’s first-order cosmic-ray slot $X+\mathrm{CRP}\to X^++e^-$ (H, He, C, O: reactions 293, 297, 298, 299), on top of the cosmic rays; Mg has no such reaction and its cosmic-ray-induced photoionisation (312) takes the rate instead;

- for hydrogen, MOCASSIN’s collisional ionisation term $2.75\times10^{-16}\,T^{3/2}(157\,894/T+2)\,e^{-157\,894/T}$ is added as well ({src}`update_mod.f90::updateCell/ionBalance@"! take into account collisional ionization of H"..@"& (157893.94/TeUsed+2.)*exp(-expFact)"`, stored at {src}`update_mod.f90::updateCell/ionBalance@"grid%pdrPhotRate(cellP, iSl358) = nPhotoSte(elem,1) + collIon"`). It has the form of a rate coefficient \[cm$^3$ s$^{-1}$\]: at $10^4$ K it is $6.8\times10^{-16}$, the magnitude of the H I collisional ionisation coefficient, but it is added to the photoionisation rate \[s$^{-1}$\] without the factor $n_e$, here and in MOCASSIN’s own ionisation balance ({src}`update_mod.f90::updateCell/ionBalance@"ionUp(elem,ion) = dble(nPhotoSte(elem,ion))+&"+1`), so collisional ionisation is underestimated by the factor $n_e$. With that factor it would reach 10% of a photoionisation rate of $10^{-8}$ s$^{-1}$ at about $1.5\times10^4$ K for $n_e=10^4$ cm$^{-3}$; the omission matters in hot, dense ionised gas and not in the PDR. The source comment attributes the formula to {cite:t}`DrakeUlrich1980`; that paper takes its collisional ionisation rates from {cite:t}`Johnson1972` and tabulates $4.88\times10^{-16}$ cm$^3$ s$^{-1}$ for the ground level at $10^4$ K (their Table 3), so the formula’s origin is not established ({ref}`sec:limitations`);

- the radiative recombination $X^++e^-\to X+\mathrm{PHOTON}$ takes MOCASSIN’s total recombination coefficient (radiative, from the fits of {cite:t}`VernerFerland1996` and the others listed at {src}`update_mod.f90::updateCell@"! This subroutine calculates rates of radiative recombination for all ions"..@"! n - number of electrons from 1 to z"`, plus dielectronic) in the first of its temperature ranges, the other ranges set to zero;

- H$_2$ photoionisation, $\mathrm{H_2}+h\nu\to\mathrm{H_2^+}+e^-$, is added to the slot $\mathrm{H_2}+\mathrm{CRP}\to\mathrm{H_2^+}+e^-$ (296) with $\Gamma_{\mathrm{H_2}}=\sum_{h\nu_k\ge15.4\,\mathrm{eV}}J^{\mathrm{ste}}_k\sigma_{\mathrm{H_2}}(\nu_k)/h\nu_k$ and the fit of {cite:t}`Yan1998`, as revised in their erratum {cite:p}`Yan2001`, to the cross section ({src}`update_mod.f90::updateCell/ionBalance@"! H2 -> H2+ on the same field, with the cross section"..@"grid%pdrPhotRate(cellP, 6) = real(gH2358)"`; `yanH2xSec`, {src}`ionization_mod.f90::yanH2xSec`).

These rates are stored by `updateCell` at every trial temperature of its search, so the chemistry reads those of the temperature it settled on ({src}`update_mod.f90::updateCell/ionBalance@"! D-358: the rates the chemistry solve runs on for a linked"..@"grid%pdrPhotRate(cellP, 6) = real(gH2358)"`). In particular, **carbon is photoionised at MOCASSIN’s rate**: the MC field contains dust and C I continuum absorption but no H$_2$ line absorption, so the C I rate is not reduced by the H$_2$ lines that overlap the C I continuum ({ref}`sec:limitations`). The C I treatment of {cite:t}`KampBertoldi2000` in 3D-PDR (`CIPDRATE`, {src}`pdr/shield.F90::CIPDRATE`), $k=\alpha\chi\exp[-\gamma A_{V}-1.1\times10^{-17}N_{\mathrm C}-0.9\,T^{0.27}(N_{\mathrm{H_2}}/1.59\times10^{21})^{0.45}]$, is computed with $A_{V}=0$ and $N_{\mathrm C}=0$, i.e. with its H$_2$ term only, and then discarded. (Equation 8 of {cite:t}`KampBertoldi2000`, which the code cites, normalises the H$_2$ term at $10^{22}$ cm$^{-2}$, not $1.59\times10^{21}$; the vendored term is 2.3 times larger at a given column.) The ionisation balance of the linked elements is moreover imposed from MOCASSIN before and after the solve ({ref}`sec:impose`).

(sec:cr)=
## Cosmic rays and cosmic-ray-induced photons
The cosmic-ray ionisation rate is the input `pdrZeta` (default $10^{-16}$ s$^{-1}$, {src}`common_mod.f90@"real :: pdrZeta = 1.0e-16 ! CR ionization rate [1/s]"`), stored normalised to the UMIST reference rate $\zeta_0=1.3\times10^{-17}$ s$^{-1}$ ({src}`pdr_mod.f90::initPDRnetwork@"pdrZetaMod = dble(pdrZeta)/1.3d-17 ! stored normalised, as upstream"`), and is the same in every cell (3D-PDR’s attenuation option `CRATTENUATION` is not compiled). Direct cosmic-ray reactions have $k=\alpha\,\zeta/\zeta_0$, with $\alpha$ the rate at $\zeta_0$ ({src}`pdr/calc_reac_rates.F90::CALCULATE_REACTION_RATES@"2 IF(DUPLICATE(I).EQ.0) THEN"+17`). Reactions driven by the ultraviolet photons that the secondary electrons of cosmic-ray ionisation excite in H$_2$ {cite:p}`PrasadTarafdar1983` have 

$$
k = \alpha\,\frac{\zeta}{\zeta_0}\left(\frac{T}{300\,\mathrm K}\right)^{\beta}\frac{\gamma}{1-\omega}
  \quad[\mathrm{s^{-1}}]
$$ (eq:crphot)

 ({src}`pdr/calc_reac_rates.F90::CALCULATE_REACTION_RATES@"3 IF(DUPLICATE(I).EQ.0) THEN"..@"& *GAMMA(I)/(1.0D0-OMEGA)"`), the UMIST form of the rate of {cite:t}`Gredel1989`, their eq. 7, $\zeta\,p_M/(1-\omega)$ per molecule: $\alpha=\zeta_0$ for all 15 such reactions of the network, $\gamma=p_M$ is the efficiency of the photoreaction per ionisation, and $\omega$ the grain albedo, which enters because the induced photons are removed by grain absorption, $\sigma_g(1-\omega)$, rather than by extinction. That approximation holds when grains dominate the absorption of the induced photons, which {cite:t}`Gredel1989` note is the case for all molecules except CO; the temperature factor is used only by CO ($\beta=1.17$, reaction 313). Here $\omega$ is MOCASSIN’s grain albedo in the LW band ({ref}`sec:dust`). The network has 8 `CRP` and 15 `CRPHOT` reactions. {cite:t}`Heays2017` find newly calculated cosmic-ray-induced rates that differ from the standard values by up to a factor of five.

(sec:ct)=
## Charge transfer with hydrogen
The charge-transfer reactions of the linked elements with H and H$^+$ (reactions 156–157, He$^+$ + H; 161–163, O$^+$ + H and H$^+$ + O; 167, H$^+$ + Mg; the network has none for carbon) use one coefficient per reaction in both the chemistry and MOCASSIN’s ionisation balance (`pdrCtCoef`, {src}`common_mod.f90::pdrCtCoef`; {src}`pdr_mod.f90::pdrStep@"if (pdrNct > 0) then"..@"pdrRate(pdrCtReac(iqP)) = ctK403(iqP)"`; {devlog}`D-403`): the network’s $\alpha(T/300)^\beta e^{-\gamma/T}$ in its temperature ranges, replaced by the fits of {cite:t}`KingdonFerland1996`, $k=a\,t_4^{\,b}(1+c\,e^{d\,t_4})$ with $t_4=T/10^4$ K, inside their ranges for He$^+$ + H (6000–$10^5$ K) and H$^+$ + Mg (5000–30 000 K) ({src}`pdr_mod.f90::initPDRnetwork@"pdrCtKF(:,pdrNct) = 0.d0; pdrCtKFTmin(pdrNct) = 0.d0; pdrCtKFTmax(pdrNct) = 0.d0"..@"pdrCtKFTmin(pdrNct) = 5.0d3; pdrCtKFTmax(pdrNct) = 3.0d4"`). For oxygen the network’s rates are fits to {cite:t}`Stancil1999` and are kept. The coefficients are evaluated at the cell’s own $T_e$, not at the clamped temperature of the other rates.

(sec:formation)=
## H$_2$ formation on grains
The reaction $\mathrm H+\mathrm H\to\mathrm{H_2}$ on grains (reaction 328) takes the rate of {cite:t}`CazauxTielens2002`, their eqs. 15--18, whose model {cite:t}`CazauxTielens2004` develop in full (`H2_FORMATION_RATE`, {src}`pdr/h2_form.F90::H2_FORMATION_RATE`, flag `H2FORM_CT02`; called at {src}`pdr/calc_reac_rates.F90::CALCULATE_REACTION_RATES@"RATE(I)=H2_FORMATION_RATE(TEMPERATURE,DUST_TEMPERATURE)"`): 

```{math}
:label: eq:rform
\begin{gather}
  R_{\mathrm f} = \tfrac12\,v_{\mathrm{th}}\,
     \bigl(\sigma^{\mathrm{sil}}_{\mathrm H}\,\epsilon_{\mathrm{sil}}+\sigma^{\mathrm{gra}}_{\mathrm H}\,\epsilon_{\mathrm{gra}}\bigr)\,
     S_{\mathrm H}(T,T_d)\quad[\mathrm{cm^3\,s^{-1}}],\\
  v_{\mathrm{th}} = 1.45\times10^{5}\sqrt{T/100\,\mathrm K}\,\mathrm{cm\,s^{-1}},\qquad
  S_{\mathrm H} = \bigl[1+0.04\sqrt{T+T_d}+0.002\,T+8\times10^{-6}\,T^2\bigr]^{-1},\\
  \epsilon = \frac{\xi}{1+F_1+F_2},\quad
  F_1 = \frac{\mu F}{2\nu_{\mathrm{H_2}}e^{-E_{\mathrm{H_2}}/T_d}},\quad
  F_2 = \frac{\bigl(1+\sqrt{(E_{\mathrm{HC}}-E_{\mathrm S})/(E_{\mathrm{HP}}-E_{\mathrm S})}\bigr)^2}{4}\,e^{-E_{\mathrm S}/T_d},\\
  \xi = \Bigl[1+\frac{\nu_{\mathrm{HC}}}{2F}\,e^{-1.5E_{\mathrm{HC}}/T_d}
        \bigl(1+\sqrt{(E_{\mathrm{HC}}-E_{\mathrm S})/(E_{\mathrm{HP}}-E_{\mathrm S})}\bigr)^2\Bigr]^{-1},
\end{gather}
```

 with temperatures in K. $v_{\mathrm{th}}$ is the mean speed of H atoms, the factor $\frac12$ makes one molecule of two atoms, and $\sigma_{\mathrm H}$ \[cm$^2$\] is the geometric grain cross section per H nucleus. $S_{\mathrm H}$ is the sticking coefficient of {cite:t}`HollenbachMcKee1979`, eq. 3.7, which they take from calculations by Burke and Hollenbach; it is 0.58, 0.33 and 0.08 at $T=100$, 300 and 1000 K (for $T_d=20$ K). The recombination efficiency $\epsilon$ is limited by three processes {cite:p}`CazauxTielens2002`: $F_1$, newly formed molecules that stay on a very cold surface; $F_2$, the evaporation of physisorbed atoms before they meet a chemisorbed one, which controls the decline above a few tens of K; and $\xi$, the evaporation of chemisorbed atoms at several hundred K. The constants are $F=10^{-10}$ monolayers s$^{-1}$ (the accretion rate), $\mu=0.005$, $\nu_{\mathrm{H_2}}=3\times10^{12}$ s$^{-1}$, $\nu_{\mathrm{HC}}=1.3\times10^{13}$ s$^{-1}$, $E_{\mathrm{HC}}=3\times10^4$ K, and $(E_{\mathrm S},E_{\mathrm{H_2}},E_{\mathrm{HP}})=(110,320,450)$ K for silicate and $(260,520,800)$ K for graphite. The functional form and $\mu$ are those of {cite:t}`CazauxTielens2002`; the per-material energies are those tabulated by {cite:t}`Rollig2013`, Table C.1 from the work of Cazaux and Tielens, whereas {cite:t}`CazauxTielens2002`, Table 1 list $(E_{\mathrm S},E_{\mathrm{HP}},E_{\mathrm{HC}})=(200,600,10^4)$ K for their silicate surface, the values Cloudy uses; {cite:t}`Rollig2013` also set the $F_1$ term to zero. With the vendored parameters (Eq. {eq}`eq:rform` evaluated for this document) $\epsilon_{\mathrm{sil}}$ is close to 1 between 6 and 15 K, 0.90 at 20 K, 0.25 at 50 K and 0.10 at 100 K, and $\epsilon_{\mathrm{gra}}$ close to 1 between 10 and 40 K, 0.43 at 100 K and 0.12 at 300 K; both fall to zero below about 6 and 9 K ($F_1$) and above about 800 K ($\xi$). The silicate energies are the main reason why the silicate coefficient is 0.50–0.91 of Cloudy’s on `hiipdr` ({devlog}`D-394`, {devlog}`H-022`, {devlog}`H-022`).

The grain areas per H $\sigma^{\mathrm{sil}}_{\mathrm H}$, $\sigma^{\mathrm{gra}}_{\mathrm H}$ are MOCASSIN’s ({ref}`sec:grainarea`), handed over per cell at {src}`pdr_mod.f90::pdrStep@"! D-195: same idea for the H2 formation rate. H2_FORMATION_RATE is"..@"pdrH2xsecGra = -1.d0"`; $T_d$ is MOCASSIN’s mean grain temperature ({ref}`sec:Td`), floored at $T_{\mathrm{CMB}}$; the metallicity factor is 1 ({src}`pdr_mod.f90::initPDRnetwork@"pdrMetalMod = 1.0d0"`). The formation rate per unit volume is $R_{\mathrm f}\,n_{\mathrm H}\,n(\mathrm H)$ \[cm$^{-3}$ s$^{-1}$\]. The same function, evaluated with one material’s area at a time, weights the two formation distributions of the level model ({ref}`sec:formdist`).
