(sec:assumptions)=
# Physical assumptions
The assumptions below are made, explicitly or implicitly, on the path from the field to the molecular content. Each names the section where it enters, says why it is made and where it fails, and gives the direction of the resulting bias and its measured size where the project has measured it. {ref}`sec:limitations` lists the defects and open issues.

## Time dependence and equilibrium

1.  **Chemical steady state.** The network is integrated until no species changes by more than 1% over a doubling of the integration time, at fixed temperature, field, columns and imposed ionisation ({ref}`sec:chemistry`). No chemical age, advection or time-dependent field is represented. The slowest process is H$_2$ formation, with a time scale $1/(R_{\mathrm f}n_{\mathrm H})\approx10^7\,(n_{\mathrm H}/100\,\mathrm{cm^{-3}})^{-1}$ yr for $R_{\mathrm f}\approx3\times10^{-17}$ cm$^3$ s$^{-1}$, close to the model’s coefficient ({devlog}`D-394`): $10^7$ yr at `hiipdr`’s density and $10^6$ yr at `pn150k`’s. This is comparable to or longer than the age of an H II region and much longer than that of a planetary nebula, so where molecules have to form from atomic gas the steady state overstates the molecular content, and it describes neither gas just uncovered by an advancing front nor molecules inherited from an earlier phase.

2.  **Statistical equilibrium of the H$_2$ levels**, with the excited electronic states treated as instantaneous (radiative lifetimes 0.5–9 ns in the data; collisions compete only above $\sim10^{14}$ cm$^{-3}$) ({ref}`sec:balance`, {ref}`sec:pump`). The slowest radiative relaxation within $X$, the quadrupole decay of the lowest rotational levels ($A=2.9\times10^{-11}$ s$^{-1}$ for $J=2\to0$, about 1100 yr, in `dataPDR/h2/transprob_X.dat`), is short compared with the dynamical times of the modelled objects, and collisions shorten it further.

3.  **Formation closure in the level model**: every molecule removed by the Solomon process is replaced by one formed on a grain, and the level populations are normalised to one. The formation flux into the levels therefore equals the Solomon flux; destruction by other channels and the corresponding formation are not in the level balance ({ref}`sec:balance`). Where the Solomon rate has been shielded away and cosmic rays and ion–molecule reactions dominate the destruction, formation pumping, and the internal energy it brings, are underestimated ({ref}`sec:limitations`). With the network’s H$_2$ + CRP channels alone the other destruction is $0.99\,\zeta$, $10^{-16}$ s$^{-1}$ at the default `pdrZeta`, so this happens where the Solomon rate is shielded below a few $10^{-16}$ s$^{-1}$ ({ref}`sec:balance`).

4.  **The coupling is a fixed-point iteration**: shielding columns, level populations of other cells, the chemistry’s channels in `ionBalance` and the heating terms held in the temperature search are one or two iterations behind ({ref}`sec:lags`). The lags vanish at a fixed point; because the MC field is redrawn at every iteration, the fixed point is statistical, and the noise biases cell means through the non-linear rates ({ref}`sec:mcnoise`).

5.  **Homogeneous cells.** Every quantity is uniform within a cell, and the MC field is the cell average. A front thinner than a cell is not resolved: on `hiipdr`’s $31^3$ grid a cell is 0.65 pc and 0.104 mag of $A_{V}$ ({devlog}`H-026`), so the H/H$_2$ transition is located only to a cell, and an ionisation-front cell spreads over its whole volume the warm, partly ionised gas of a layer about 0.18 pc thick, which then dominates \[O I\] 63 μm ({lim}`L-37`). The shielding columns of the chemistry run to the near face of the cell ({ref}`sec:avradial`), which under-shields CO in the cells of its transition by up to half a cell’s column.

## Radiation field

6.  **Point sources only.** The field is that of the sources of the input and their reprocessing; no interstellar radiation field illuminates the outer boundary and the cosmic microwave background is not transported ({ref}`sec:field`, {ref}`sec:Td`). Where the attenuated field of the sources falls below the interstellar one, the model’s outer gas is more molecular and colder, and its grains colder, than the same cloud immersed in the interstellar field would be. On `hiipdr` the source’s field falls below $\chi=1$ beyond about 0.6 of the outer radius and to a median $\chi=0.08$ in the outermost shell; on `pn150k` it stays above 1.6 everywhere (`output/pdrFUV.out` of the fixtures’ runs). The grain temperature is floored at $T_{\mathrm{CMB}}$ for the chemistry only ({lim}`L-30`); the line background of the coolants does include the CMB ({devlog}`D-377`).

7.  **The MC field is a continuum field.** It contains dust absorption and scattering and the gas continuum opacities (including C I and H$_2$ photoionisation), but no H$_2$, CO or H I Lyman-series *line* opacity ({ref}`sec:eta`). The photons that the H$_2$ lines absorb remain in the transported field, where they heat dust, eject photoelectrons and photoionise C I. Behind the H/H$_2$ transition this overstates dust heating and photoelectric emission slightly, since the saturated line cores hold a small part of the band’s energy (the whole window holds 15% of a Draine-shaped field’s), and C I photoionisation, which happens only in the window, by more: a few tens of per cent at $A_{V}\sim3$ by the project’s estimate ({ref}`sec:limitations`). Unmeasured.

8.  **Separability of continuum and line attenuation.** The rate seen by a molecule is the MC continuum at the line times a line transmission computed from column densities along a characteristic path: the straight line to each source for the direct beam, and the two-leg path through a scattering site for diffuse light. Dust is never applied twice: $A_{V}=0$ on every ray ({ref}`sec:rays`). Exact for the direct beam; for the diffuse light it assumes that a photon’s history is represented by the one site it is assigned to.

9.  **Direct beam geometry.** The direct field arrives along the straight line from each point source. With several sources the columns and the in-cell chord are averages weighted by $r_s^{-2}$ alone, without the sources’ luminosities or attenuation, applied to the summed direct field ({ref}`sec:avradial`). Exact for one source, as in all the fixtures; for several, the error is unmeasured and has no definite sign.

10. **Diffuse field geometry.** Its total is the MC’s $\chi_{\mathrm{dif}}$; its distribution over twelve fixed directions and over sites along them is the formal solution with an isotropic emissivity $\sum\kappa^{\mathrm{sca}}J$ and a grey FUV extinction $R_{\mathrm{FUV}}\kappa_V$ ({ref}`sec:sites`). The same window factor is applied at every site. Measured: the formal solution recovers 52–130% of $\chi_{\mathrm{dif}}$, falling with depth ({lim}`L-4`); the forward-peaked phase function ($g=0.29$–0.61 on the fixtures) puts more of the real diffuse field on the source side than the weights do.

11. **Angular quadrature**: twelve HEALPix $N_{\mathrm{side}}=1$ directions fixed in the grid frame, for the sites and for line escape ({ref}`sec:healpix`, {ref}`sec:lineRays`). Biased along the ring axis: cells nearest the plane $z=0$ hold 5–11% more H$_2$ before and across the transition than their symmetry-equivalent cells; 48 directions remove this, moving the totals by under 1% ({lim}`L-53`, {devlog}`D-410`).

12. **Spectral shape.** The generic photoreactions assume the Draine spectral shape across 6–13.6 eV ({ref}`sec:generic`), while the MC field’s LW share falls from 0.30 to 0.008 through `hiipdr`’s PDR ({devlog}`D-349`); CO takes the ratio of the MC field’s LW share to Draine’s, with the shape inside the window assumed Draine’s ({ref}`sec:window`); H$_2$ uses the MC specific intensity at each line, constant across the 2%-wide frequency bin that contains it ({ref}`sec:eta`).

13. **Symmetry.** For a `symmetricXYZ` octant the lower faces are mirrors for every walk to the edge of the model; the walks towards the sources do not reflect ({ref}`sec:raycells`). Valid for a model symmetric in the three planes with its sources on them.

## H$_2$ microphysics

14. **Line profile**: Voigt, with Doppler parameter $b^2=2kT_e/m_{\mathrm{H_2}}+v_{\mathrm{turb}}^2$ and damping from the upper level’s total radiative decay rate (to the bound levels and the continuum of $X$; the data contain no predissociated levels) ({ref}`sec:shield`). Damping each line by its own $A$, as Cloudy does, would put `hiipdr`’s H/H$_2$ crossing 0.21 mag and `pn150k`’s 0.10 mag shallower ({devlog}`H-026`).

15. **Self-shielding** of each line by the column of its lower level, averaged through the cell’s own column with the curve of growth; the cell’s own column is taken over its mean chord along the source direction (direct) or over all directions (diffuse) ({ref}`sec:ownavg`).

16. **Line overlap** by the other H$_2$ lines, as a six-point mean of their transmission over the line’s absorption; photons absorbed in another line’s wing are lost, not counted as pumping it; H I Lyman lines do not shade ({ref}`sec:overlap`).

17. **Trapping**: complete redistribution; a trapped photon re-excites the same upper level (on-the-spot); escape probability per line, without overlap, averaged over twelve directions ({ref}`sec:escape`).

18. **Colliders**: H (including reactive collisions), He, ortho- and para-H$_2$ and H$^+$; no electrons, so the excitation of H$_2$ in ionised gas is underestimated. Missing same-spin pairs (86–99.9% of them, depending on the collider) take g-bar estimates; missing spin-changing pairs get no collisional rate; outside the tabulated temperatures (for H, 100–5000 K) the rates are held at the table’s end values ({ref}`sec:coll`).

19. **Formation distribution** of {cite:t}`TakahashiUehara2001`, silicate and carbonaceous surfaces mixed in the proportion of the formation rates ({ref}`sec:formdist`). Formation through H$^-$ and H$_2^+$, cosmic-ray excitation and destruction other than Solomon are not in the level model.

## Grains

20. **H$_2$ formation** follows {cite:t}`CazauxTielens2002,CazauxTielens2004` with the {cite:t}`HollenbachMcKee1979` sticking coefficient and 3D-PDR’s surface energies per material, on the geometric grain area per H nucleus of the model’s own grains, split into silicate and carbonaceous by the species’ labels ({ref}`sec:grainarea`, {ref}`sec:formation`). On `hiipdr`’s silicates this gives 0.50–0.91 of Cloudy’s coefficient, mainly through the surface energies and partly through the colder gas; on `pn150k`’s graphite 0.86–1.00 ({devlog}`D-394`, {devlog}`H-022`).

21. **One grain temperature per cell**: the number-weighted mean over the grains present (each species over its own size bins, {devlog}`D-414`) enters an efficiency that is steep in $T_d$ ({ref}`sec:Td`).

22. **Grain temperature** from MOCASSIN’s radiative equilibrium with no stochastic heating by default ({lim}`L-8`), floored for the chemistry at $T_{\mathrm{CMB}}$ because the CMB is not transported ({ref}`sec:Td`).

23. **Extinction ratio** $R_{\mathrm{FUV}}$ weighted by source 1’s emitted spectrum; it overstates the band extinction of the reddened local field at depth, which matters only for the diffuse-site weights ({ref}`sec:dust`).

24. **Photoelectric heating** from the grains the input specifies, and from nothing else: 3D-PDR's PAH prescription is not used. PAHs and very small grains contribute only if the input includes them as species. The benchmark fixtures have none ({lim}`L-7`), so their heating is lower than PDR models with the {cite:t}`BakesTielens1994` prescription would have at the same field, and their gas colder ({ref}`sec:thermal`).

## Ownership and coupling

25. **MOCASSIN owns the ionisation** of H, He, C, O and Mg and the electron density: imposed on the chemistry before and after the solve, with the photoionisation and recombination rates of these atoms taken from MOCASSIN inside the solve ({ref}`sec:linked`, {ref}`sec:impose`). In particular the C$^+$/C ratio, which controls the carbon available to CO, is MOCASSIN’s, and its C I photoionisation has no H$_2$-line shielding.

26. **MOCASSIN owns the temperatures**: the chemistry and the level model run at $T_e$ (clamped to the fitted range of the rate data, while 3D-PDR’s heating terms are evaluated at the unclamped $T_e$, {lim}`L-30`) and $T_d$ ({ref}`sec:chemistry`). The thermal balance is solved at fixed chemistry, with the extra heating terms held fixed during the temperature search ({ref}`sec:thermal`).

27. **The chemistry owns the molecular content**, which reaches MOCASSIN only as the fraction of each element locked in molecules, as $n(\mathrm{H_2})$ in the opacity, and through the coolants and heating terms ({ref}`sec:feedback`).

28. **Cosmic rays**: a uniform ionisation rate (`pdrZeta`), with no attenuation with column ({ref}`sec:cr`); their heating, 9.4 eV per H$_2$ ionisation, is counted in molecular gas only {cite:p}`TielensHollenbach1985`.

## Relation to the standard PDR benchmark

The PDR code comparison {cite:p}`Rollig2007` fixed, for its benchmark models, the field in Draine units with $\chi=1.71\,G_0$, $A_{V}=6.289\times10^{-22}N_{\mathrm H}$, an FUV attenuation $e^{-3.02A_{V}}$ wherever a code did not treat it as a function of wavelength, an H$_2$ formation coefficient $3\times10^{-18}T^{1/2}$ cm$^3$ s$^{-1}$, a cosmic-ray ionisation rate of $5\times10^{-17}$ s$^{-1}$, and photoelectric heating after {cite:t}`BakesTielens1994`, the only heating process it standardised; the H$_2$ shielding was left to each code (their Sect. 4.2.3 and Table 5). The present model departs from all of these choices by construction: its field is the transported MC field, scattering included ({ref}`sec:split`); its $A_{V}/N_{\mathrm H}$, $R_{\mathrm{FUV}}$ and grain area are its own grains’ ({numref}`tab:dustfix`); its formation coefficient follows the grains’ temperature ({ref}`sec:Td`); $\zeta$ defaults to $10^{-16}$ s$^{-1}$; its photoelectric heating comes from its own grains without PAHs; and its H$_2$ shielding is the level model’s. A benchmark comparison therefore tests the coupling only after these inputs have been matched, as was done against the vendored 3D-PDR in {devlog}`D-257` (in $\zeta$, composition, $A_{V}$ conversion and dust); unmatched, it measures differences of physics rather than of numerics.
