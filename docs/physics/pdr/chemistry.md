(sec:chemistry)=
# The chemical solve
(sec:network)=
## Network and rate law
The network is 3D-PDR’s REDUCED network (files `dataPDR/species_reduced.d` and `dataPDR/rates_reduced.d`), in the format of the UMIST Database for Astrochemistry. {cite:t}`Bisbas2012` introduced its 33 species with 320 reactions drawn from UMIST 2006 {cite:p}`Woodall2007`; {cite:t}`Bisbas2015` describe the 33-species network then in use as a 330-reaction subset of UMIST 2012 {cite:p}`McElroy2013`. The vendored file, from upstream commit `fabcdc6`, has 331 reactions and records neither its UMIST release nor the references of its coefficients, so the release cannot be determined from the files. It has 33 species,

H, H$_2$, H$^+$, H$_2^+$, H$_3^+$, He, He$^+$, C, C$^+$, CH, CH$^+$, CH$_2$, CH$_2^+$, CH$_3$, CH$_3^+$, CH$_4$, CH$_4^+$, CH$_5^+$, O, O$^+$, OH, OH$^+$, H$_2$O, H$_2$O$^+$, H$_3$O$^+$, O$_2$, O$_2^+$, CO, CO$^+$, HCO$^+$, Mg, Mg$^+$, e$^-$,

and 332 reactions: 3D-PDR’s 331 plus reaction 332, $e^-+\mathrm{H_2^+}\to e^-+\mathrm H+\mathrm H^+$ ($2\times10^{-7}e^{-30720/T}$ cm$^3$ s$^{-1}$), appended in this project because the network had no electron-impact dissociation of H$_2^+$, Cloudy’s main H$_2^+$ sink in ionised gas (`pdr/UPSTREAM.md`, {devlog}`D-395`); the Arrhenius form is the one of Cloudy’s `mole_co_umisthack.dat`, which attributes it to {cite:t}`Janev1987`. Of the 332, 28 are photoreactions, 8 cosmic-ray and 15 cosmic-ray-induced photoreactions ({ref}`sec:photorates`), and three carry the grain marker `#`: grain formation of H$_2$ (328) and the grain-assisted recombinations of He$^+$ and C$^+$ (330, 331). These two have no term in the generated right-hand side, so their coefficients are computed but unused and 330 reactions act in the solve. The other 278 are two-body reactions: ion–molecule, neutral–neutral and charge-transfer reactions, dissociative and radiative recombination, radiative association and collisional dissociation. The ODE right-hand side is generated C code selected at compile time ({src}`pdr/odes_reduced.c`, flag `-DREDUCED`); the keyword `pdrNetwork` only validates that the requested network is the compiled one.

Two-body coefficients follow the modified Arrhenius form 

$$
k(T) = \alpha\left(\frac{T}{300\,\mathrm K}\right)^{\beta} e^{-\gamma/T}\quad[\mathrm{cm^3\,s^{-1}}],
$$ (eq:arrhenius)

 with $\gamma$ in K ({src}`pdr/calc_reac_rates.F90::CALCULATE_REACTION_RATES@"IF(GAMMA(I).LT.-200.0D0 .AND. TEMPERATURE.LT.RTMIN(I)) THEN"..@"RATE(I)=ALPHA(I)*(LOCTEMPERATURE/300.0D0)**BETA(I)*EXP(-(GAMMA(I)/LOCTEMPERATURE))"`). Where a reaction has several entries for different temperature ranges, the first whose upper limit is above $T$ (else the last) is used and the others are set to zero; a fit with $\gamma<0$ is evaluated at the lower limit of its range below it, and one with $\gamma<-200$ K is set to zero there. The chemistry is evaluated at MOCASSIN’s $T_e$ clamped to \[`pdrTmin`, `pdrTmax`\] $=[1,\,2\times10^4]$ K by default ({src}`pdr_mod.f90::pdrStep@"Tg = min(max(Tg, dble(pdrTmin)), dble(pdrTmax))"`), the range over which the fits are meant to be used; MOCASSIN’s own floor `teFloor`, 2.725 K by default, keeps $T_e$ above $T_{\mathrm{CMB}}$. The vendored bound $\max(`pdrTmin`,T_{\mathrm{CMB}})$ ({src}`pdr_mod.f90::initPDRnetwork@"pdrTminMod = max(dble(pdrTmin), pdrTcmb)"`) is read only by 3D-PDR’s own temperature iteration ({src}`pdr/changetemperature.F90`), which the bridge does not call. In terms of fractional abundances $x_i=n_i/n_{\mathrm H}$ the system is 

$$
\frac{\mathrm{d}x_i}{\mathrm{d}t} = \sum_{j,k} k_{jk}\,x_jx_k\,n_{\mathrm H}
      + \sum_j k_j\,x_j - x_i\Bigl(\sum_j k_{ij}\,x_j\,n_{\mathrm H} + \sum k_i\Bigr),
$$ (eq:odes)

 with two-body coefficients $k_{jk}$, $k_{ij}$ \[cm$^3$ s$^{-1}$\] and first-order rates $k_j$, $k_i$ \[s$^{-1}$\] (photoreactions and cosmic rays, {ref}`sec:photorates`). Grain formation enters as $R_{\mathrm f}\,x(\mathrm H)\,n_{\mathrm H}$ in $\mathrm{d}x(\mathrm{H_2})/\mathrm{d}t$ and twice that as a loss of H. Inside the right-hand side the electron abundance is not a free variable: it is the sum of the network’s cations plus `xe_extra`, the electrons of the ions the network has no species for (higher stages, other elements), supplied by the bridge ({devlog}`D-402`; {src}`pdr/odes_reduced.c::f@"x_e = chemistry_module_mp_xe_extra_+x[0]+x[1]+x[3]+x[5]+x[6]+x[7]+x[8]+x[9]+x[10]+x[12]+x[13]+x[14]+x[15]+x[18]+x[19]+x[22]+x[23]+x[26]; /* D-402 xe_extra */"`).

(sec:seed)=
## Initial conditions and seeding
**First visit of a cell.**
`seedAbunFromMocassin` ({src}`pdr_mod.f90::seedAbunFromMocassin`, {devlog}`D-208`): every molecule starts at zero; each linked element’s neutral and first ion take MOCASSIN’s stage-1 and stage-2 fractions times the element abundance; $x_e=n_e/n_{\mathrm H}$. Nothing is read from the network file’s dark-cloud defaults.

**First PDR iteration.**
`seedMolecules` ({src}`pdr_mod.f90::seedMolecules`, {devlog}`D-209`) places a first H$_2$ and CO content so that the first shielding columns are not zero. H$_2$ comes from the balance of grain formation and unshielded photodissociation, with the neutral hydrogen of MOCASSIN, $x_{\mathrm n}n_{\mathrm H}$, shared between H and H$_2$: 

```{math}
\begin{gather}
  R_{\mathrm f}\,n_{\mathrm H}\,n(\mathrm H) = D\,n(\mathrm{H_2}),\qquad
  n(\mathrm H)+2n(\mathrm{H_2}) = x_{\mathrm n}n_{\mathrm H}
  \quad\Longrightarrow\quad
  x(\mathrm{H_2}) = \frac{R_{\mathrm f}\,x_{\mathrm n}\,n_{\mathrm H}}{D+2R_{\mathrm f}n_{\mathrm H}},\\
  D = \alpha_{\mathrm{H_2}}\,\chi\;\mathrm{SCATTER}(A_{V},1000\,\text{\AA}),
\end{gather}
```

 with $\alpha_{\mathrm{H_2}}$ the network’s coefficient ($5.18\times10^{-11}$ s$^{-1}$, read from the rate file) and $\chi$ the local MC field of Equation ({eq}`eq:chi`); $x(\mathrm{H_2})$ is capped at $x_{\mathrm n}/2$. CO follows the ansatz $x(\mathrm{CO}) = x(\mathrm C)\,[2x(\mathrm{H_2})/x_{\mathrm n}]$, capped by the oxygen, with carbon and oxygen conserved. Steps 4–5 of {numref}`tab:steps` are then repeated on the seeded abundances. The seed attenuates the already attenuated local field $\chi$ once more with `SCATTER` and ignores self-shielding; it only provides the starting point, which the iteration then forgets.

(sec:impose)=
## Imposition of MOCASSIN’s ionisation before the solve
MOCASSIN owns the ionisation state; the chemistry owns what is locked in molecules ({devlog}`D-153`, {devlog}`D-193`, {devlog}`D-402`; {src}`pdr_mod.f90::pdrStep@"carr402(1,:) = pdrElNeut; carr402(2,:) = pdrElIon"..@"nProbe230 = nProbe230 + 1"`). For each linked element $X$ with abundance $A_X$ and molecular content $M_X=\sum_i \nu_{X,i}x_i$ (atoms of $X$ in each species, from the species’ formulae, `speciesAtoms`): 

```{math}
x(X) = (A_X-M_X)\,\frac{f_1}{\sum_s f_s},\qquad
  x(X^+) = (A_X-M_X)\,\frac{f_2}{\sum_s f_s},
```

 where $f_s$ are MOCASSIN’s stage fractions; what MOCASSIN holds in stages above the second stays MOCASSIN’s. The electron abundance is set to $n_e/n_{\mathrm H}$ from MOCASSIN, and `xe_extra` to $x_e$ minus the linked first ions ({src}`pdr_mod.f90::pdrStep@"! D-402: inside the solve the electrons are not this entry. The"..@"if (pdrNelect > 0) pdrXeExtra = max(abun(pdrNelect) - xeIon402, 0.d0)"`). The imposition fixes the starting point of the integration; inside it, the linked atoms are ionised and recombined at MOCASSIN’s own rates ({ref}`sec:linked`), so the solver’s neutral/ion ratio should stay close to MOCASSIN’s, and the remaining difference is carried by the network’s other channels (charge transfer, ion–molecule reactions).

## Integration to steady state

`calculate_abundances` ({src}`pdr/calculate_abundances.c`), called at {src}`pdr_mod.f90::pdrStep@"call calculate_abundances(abun, pdrRate, nH, Tg, npart, &"`, integrates Equation ({eq}`eq:odes`) with CVODE from SUNDIALS 7.8.0 ({devlog}`D-015`; {cite:t}`Hindmarsh2005,Gardner2022`). The line numbers in this list are those of {src}`pdr/calculate_abundances.c` unless a file is named:

- variable-order backward differentiation formulae (`CV_BDF`, {src}`code <pdr/calculate_abundances.c::calculate_abundances_@"cvode_mem = CVodeCreate(CV_BDF, sunctx);">`), the stiff integrator, with Newton iteration on a dense direct linear solver (`SUNDenseMatrix`, `SUNLinSol_Dense`, {src}`code <pdr/calculate_abundances.c::calculate_abundances_@"SUNMatrix A = SUNDenseMatrix(neq, neq, sunctx);"..@"SUNLinSol_Dense(y, A, sunctx);">`) and CVODE’s difference-quotient Jacobian (the analytic Jacobian is not used);

- relative and absolute tolerances $10^{-8}$ and $10^{-30}$ on the fractional abundances (set at {src}`pdr_mod.f90::initPDRnetwork@"pdrRelTol = 1.0d-8"`, applied at {src}`code <pdr/calculate_abundances.c::calculate_abundances_@"flag = CVodeSStolerances(cvode_mem, reltol, abstol);">`); at most $10^7$ internal steps per output interval ({src}`code <pdr/calculate_abundances.c::calculate_abundances_@"mxstep = 10000000;">`);

- output times from $10^{-4}$ yr, multiplied by 10 until `pdrEndTime` (default $10^7$ yr) ({src}`code <pdr/calculate_abundances.c::calculate_abundances_@"tout = 1.0e-4 * seconds_in_year;"#1>`, {src}`code <pdr/calculate_abundances.c::calculate_abundances_@"tout = tout * 10;">`);

- `CHEMRETRY` ({src}`code <pdr/calculate_abundances.c::calculate_abundances_@"/* CHEMRETRY: save the initial abundances so a cell whose integration fails"..@"} /* end CHEMRETRY block */">`): a failed integration is restarted from the initial state up to four more times with a forced first step of $10^{-2}$ s, divided by 100 at each retry;

- `CHEMSTEADY` ({src}`code <pdr/calculate_abundances.c::calculate_abundances_@"#ifdef CHEMSTEADY"..@"free(yold);">`): the integration then continues in blocks that each double the elapsed time, at most seven ($128\times$`pdrEndTime`, $1.3\times10^9$ yr by default), until no species above the absolute tolerance changes by more than 1% over a block;

- abundances below the absolute tolerance are set to zero and the electron entry is restored ({src}`code <pdr/calculate_abundances.c::calculate_abundances_@"/* Store the output values in the abundance array */"..@"abundance[n * (*nspec) + nelect] = user_data->x_e;">`).

The result is meant to be the steady state of the network at fixed temperature, field, columns and imposed ionisation; there is no time dependence carried between MC iterations. A species that relaxes exponentially on a time scale $\tau$ from an offset of order unity passes the 1% test over a doubling once the elapsed time exceeds about $4.6\,\tau$, so species that relax more slowly than about $10^8$ yr cannot pass it by the last block; if the seventh block does not pass, the abundances of that time are returned without a flag. An unchanged abundance vector is counted (`pdrNstuck`, {src}`pdr_mod.f90::pdrStep@"if (all(abun == abun0)) pdrNstuck = pdrNstuck + 1"`) but not treated as a failure, since it is also the signature of a converged cell. The slowest chemical process in molecular gas is usually H$_2$ formation, whose time scale $1/(R_{\mathrm f}n_{\mathrm H})$ is $\sim10^7$ yr at $n_{\mathrm H}=100$ cm$^{-3}$; where the age of the object is shorter the steady state overstates the molecular content ({ref}`sec:assumptions`).

## After the solve

1.  The solver’s own neutral/ion split of each linked element is overwritten with MOCASSIN’s stage-1:stage-2 ratio, keeping the solver’s total $x(X)+x(X^+)$ ({src}`pdr_mod.f90::pdrStep@"if (.true.) then ! D-193: unconditional"..@"abun(iSpI) = availTot*mocIon /(mocNeut+mocIon)"`, {devlog}`D-162`); the electron abundance is reset to MOCASSIN’s ({src}`pdr_mod.f90::pdrStep@"! MOCASSIN computes it."+4`, {devlog}`D-231`). The solver’s own ratio is kept for diagnostics ({devlog}`D-402`, {devlog}`D-404`).

2.  The abundances are stored ({src}`pdr_mod.f90::pdrStep@"grid%pdrAbun(cellP, 1:pdrNspec) = abun"`) and $n(\mathrm{H_2})=x(\mathrm{H_2})n_{\mathrm H}$ is written for MOCASSIN’s opacity ({src}`pdr_mod.f90::pdrStep@"grid%H2den(cellP) = real(abun(NH2)*nH) ! D-107"`).

3.  What the network does to each linked element’s $X$ and $X^+$ beyond the channels `ionBalance` computes itself (photoionisation, cosmic rays, radiative recombination, charge transfer with H) is classified reaction by reaction at the solver’s state, as net conversions $X\leftrightarrow X^+$ and as sources and sinks to and from molecules, and stored for MOCASSIN’s next ionisation solve (`pdrIonRate`, {src}`pdr_mod.f90::pdrStep@"! D-402: what the network does to each linked element's X and X+"..@"grid%pdrIonRate(cellP, pdrNchan*(iE402-1)+1:pdrNchan*iE402) = real(ch402)"`, {devlog}`D-402`). The classified totals reproduce the right-hand side’s own formation and destruction totals to $4\times10^{-16}$ ({devlog}`D-402`).
