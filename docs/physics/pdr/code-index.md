(app:index)=
# Index of code locations
Files are under `source/`; links resolve against the commit the site was built from; `pdr/` is the vendored 3D-PDR. A range is the whole routine unless the process column names a part of it.

:::{list-table} Index of code locations.
:name: tab:index
:header-rows: 1
:widths: 39 25 30

* - Process
  - Routine
  - File:lines
* - **Iteration and transfer**
  - 
  - 
* - MC iteration, PDR block
  - `iterateMC`
  - {src}`iteration_mod.f90::MCIterationDriver/iterateMC`
* - packet transport
  - `energyPacketDriver`, `pathSegment`
  - {src}`photon_mod.f90::energyPacketDriver`, {src}`photon_mod.f90::energyPacketDriver/pathSegment`
* - path-length estimator ($J^{\mathrm{ste}}$, $J^{\mathrm{dif}}$)
  - `pathSegment`
  - {src}`photon_mod.f90::energyPacketDriver/pathSegment@"& grid(gP)%Jste(grid(gP)%active(xP,yP,zP),enPacket%nuP) + dlLoc*deltaE(iStar) *(enPacket%weight) / dV"..@"! every PDR run (lgJdifLive), not only under pdrSplitField."`, {src}`photon_mod.f90::energyPacketDriver/pathSegment@"& grid(gP)%Jste(grid(gP)%active(xP,yP,zP),enPacket%nuP) + dS*deltaE(iStar) *(enPacket%weight) / dV"..@"! D-158: same split on the cell-crossing branch."`
* - scattering, re-flag of the packet as diffuse
  - `pathSegment`
  - {src}`photon_mod.f90::energyPacketDriver/pathSegment@"probSca = grid(gP)%scaOpac(grid(gP)%active(xP,yP,zP),enPacket%nuP)/&"..@"lgScattered = .true."`, {src}`photon_mod.f90::energyPacketDriver/pathSegment@"enPacket = initPhotonPacket(enPacket%nuP, rVec, enPacket%direction, .false., .false., enPacket%xP(1:2), &"..@"print*, '! pathSegment [warning]: hg called ten times [enPacket]', enPacket"`
* - absorption by dust or gas
  - `pathSegment`
  - {src}`photon_mod.f90::energyPacketDriver/pathSegment@"if (.not. lgScattered) then"..@"! packet is absorbed by the gas"`
* - $J^{\mathrm{dif}}$ always accumulated in PDR runs
  - `readInput`
  - {src}`set_input_mod.f90::readInput@"lgJdifLive = (pdrSplitField /= 0)"..@"if (lgPDR) lgJdifLive = .true."`
* - estimator units, octant
  - `iterateMC`
  - {src}`iteration_mod.f90::MCIterationDriver/iterateMC@"grid(iG)%Jste(i,:) = grid(iG)%Jste(i,:) * 1.e-9"`, {src}`iteration_mod.f90::MCIterationDriver/iterateMC@"grid(iG)%Jste(i,:) = grid(iG)%Jste(i,:)/8."`
* - FUV band, LW window, Draine unit, $V$ band
  - constants
  - {src}`constants_mod.f90@"#ifdef PDR"`
* - FUV and $V$ bin indices
  - `setContinuum`
  - {src}`continuum_mod.f90::setContinuum@"call locate(nuArray, nuFUVlo, FUVlowP)"..@"call locate(nuArray, nuVband, VbandP)"`
* - **Dust**
  - 
  - 
* - grain area per H by material
  - `measureH2grainArea`
  - {src}`pdr_mod.f90::measureH2grainArea`
* - material from the grain label
  - `isCarbonGrain`, `isSilicateGrain`
  - {src}`pdr_mod.f90::isCarbonGrain`, {src}`pdr_mod.f90::isSilicateGrain`
* - $R_{\mathrm{FUV}}$, $A_{V}/N_{\mathrm H}$, area per cell
  - `dustPerCell`
  - {src}`pdr_mod.f90::dustPerCell`
* - model-wide fallbacks, own extinction curve
  - `calibratePDRdust`
  - {src}`pdr_mod.f90::calibratePDRdust`
* - grain LW albedo
  - `grainAlbedoLW`
  - {src}`update_mod.f90::grainAlbedoLW`
* - grain temperatures; their mean
  - `getDustT`
  - {src}`update_mod.f90::updateCell/getDustT`, {src}`update_mod.f90::updateCell/getDustT@"! find weighted mean"..@"& grid%Tdust(nS,0,cellP)*grainAbun(nspU,nS)"`
* - size weights of the distribution
  - `makeDustXsec`
  - {src}`ph_mod.f90::makeDustXsec@"! Calculate normalization for distribution weights"..@"print*, '! makeDustXSec : Invalid grain weight ', grainWeight(ai), ai"`
* - grain attenuation factor, extinction curve
  - `SCATTER`, `XLAMBDA`
  - {src}`pdr/shield.F90::SCATTER`, {src}`pdr/shield.F90::XLAMBDA`
* - **Geometry**
  - 
  - 
* - exact ray–cell traversal
  - `rayCells`
  - {src}`pdr_mod.f90::rayCells`
* - source-ward $A_{V}$ and columns
  - `computeAVradial`
  - {src}`pdr_mod.f90::computeAVradial`
* - dispatch, plane-parallel case
  - `computeAVdust`
  - {src}`pdr_mod.f90::computeAVdust`
* - diffuse snapshot
  - `snapDiffuseSources`
  - {src}`pdr_mod.f90::snapDiffuseSources`
* - scattering sites, two-leg columns
  - `traceDiffuseSites`
  - {src}`pdr_mod.f90::traceDiffuseSites`
* - Draine LW share
  - `draineWindowShare`
  - {src}`pdr_mod.f90::draineWindowShare`
* - line-escape rays
  - `traceLineRays`
  - {src}`pdr_mod.f90::traceLineRays`
* - $\chi$, $\chi_0$
  - `mocassinToPDR`
  - {src}`pdr_mod.f90::mocassinToPDR`
* - **H$_2$ level model**
  - 
  - 
* - driver, sweeps, MPI scheduling
  - `h2LevelModel`
  - {src}`pdr_mod.f90::h2LevelModel`
* - source-ward level columns
  - `starColumns`
  - {src}`pdr_mod.f90::h2LevelModel/starColumns`
* - per-cell solution
  - `solveCell`
  - {src}`pdr_mod.f90::h2LevelModel/solveCell`
* - warm-start populations
  - `h2PopResume`
  - {src}`pdr_mod.f90::h2LevelModel/h2PopResume`
* - 1D-build stub
  - `h2LevelModel`
  - {src}`pdr_mod.f90::h2LevelModel [1d]`
* - $X$ levels, $A$ values, collision tables
  - `h2ReadX`
  - {src}`h2_mod.f90::h2ReadX`
* - excited states, lines, dissociation
  - `h2ReadElec`
  - {src}`h2_mod.f90::h2ReadElec`
* - UV pumping, Solomon rate, trapping
  - `h2PumpRates`
  - {src}`h2_mod.f90::h2PumpRates`
* - formation distribution
  - `h2FormDist`
  - {src}`h2_mod.f90::h2FormDist`
* - collision-table interpolation
  - `tabRate`
  - {src}`h2_mod.f90::tabRate`
* - Voigt function
  - `h2Voigt`
  - {src}`h2_mod.f90::h2Voigt`
* - $S$, $W$, absorption quantiles
  - `shieldQuad`, `shieldTable`
  - {src}`h2_mod.f90::shieldQuad`, {src}`h2_mod.f90::shieldTable`
* - shielding look-up, cell average
  - `h2Shield`, `tabShieldJ`, `h2ShieldJ`
  - {src}`h2_mod.f90::h2Shield`, {src}`h2_mod.f90::shieldOffsets`, {src}`h2_mod.f90::tabShield`, {src}`h2_mod.f90::h2ShieldAIndex`, {src}`h2_mod.f90::tabShieldJ`, {src}`h2_mod.f90::h2ShieldJ`
* - direct-path shielding (prepare/evaluate)
  - `h2LineShieldPrep`, `h2LineShieldEval`
  - {src}`h2_mod.f90::h2LineShieldPrep`, {src}`h2_mod.f90::h2LineShieldEval`
* - Cloudy’s FGK79 fit (comparison only)
  - `h2ShieldFederman`
  - {src}`h2_mod.f90::h2ShieldFederman`
* - line overlap
  - `lineOverlap`
  - {src}`h2_mod.f90::lineOverlap`
* - line parameters $\sigma$, $a$
  - `h2LineParams`
  - {src}`h2_mod.f90::h2LineParams`
* - escape probabilities
  - `h2LineEscape`
  - {src}`h2_mod.f90::h2LineEscape`
* - collisional and radiative rates
  - `h2CollRad`
  - {src}`h2_mod.f90::h2CollRad`
* - collisional heating
  - `h2CollHeat`
  - {src}`h2_mod.f90::h2CollHeat`
* - statistical equilibrium
  - `balance`, `h2Solve`, `gaussSolve`
  - {src}`h2_mod.f90::balance`, {src}`h2_mod.f90::h2SolveX`, {src}`h2_mod.f90::h2Solve`, {src}`h2_mod.f90::gaussSolve`
* - outputs
  - `h2Lines_mod`
  - {src}`h2Lines_mod.f90`
* - **Chemistry**
  - 
  - 
* - network set-up, linked elements, replaced channels
  - `initPDRnetwork`
  - {src}`pdr_mod.f90::initPDRnetwork`
* - atoms of each element per species
  - `initPDRnetwork`
  - {src}`pdr_mod.f90::initPDRnetwork@"if (allocated(pdrMolAtoms)) deallocate(pdrMolAtoms)"..@"pdrMolAtoms(iS, iLnk) = dble(nAt402(pdrElZ(iLnk)))"`
* - first-visit seed
  - `seedAbunFromMocassin`
  - {src}`pdr_mod.f90::seedAbunFromMocassin`
* - first-iteration molecular seed
  - `seedMolecules`
  - {src}`pdr_mod.f90::seedMolecules`
* - one cell of chemistry
  - `pdrStep`
  - {src}`pdr_mod.f90::pdrStep`
* - rays: $\chi_{\mathrm{dir}}$, $\chi_{\mathrm{dif}}$, sites, window factors
  - `pdrStep`
  - {src}`pdr_mod.f90::pdrStep@"iDifFb = 0"..@"if (nChem > 1) pdrRayLW(1:nChem-1) = fDif"`
* - imposition before the solve
  - `pdrStep`
  - {src}`pdr_mod.f90::pdrStep@"carr402(1,:) = pdrElNeut; carr402(2,:) = pdrElIon"..@"nProbe230 = nProbe230 + 1"`
* - columns handed over
  - `pdrStep`
  - {src}`pdr_mod.f90::pdrStep@"! D-078: true integrated columns, not local abundance x total column"..@"colC = 0.d0"`
* - rate coefficients
  - `CALCULATE_REACTION_RATES`
  - {src}`pdr/calc_reac_rates.F90`; call {src}`pdr_mod.f90::pdrStep@"call CALCULATE_REACTION_RATES(Tg, Td, nChem, radSurf, AVray, &"`
* - MOCASSIN’s atomic rates into the network
  - `pdrStep`
  - {src}`pdr_mod.f90::pdrStep@"if (allocated(grid%pdrPhotRate)) then"..@"& + dble(max(grid%pdrPhotRate(cellP,6), 0.))"`
* - H$_2$ photodissociation $=k_{\mathrm{Sol}}$
  - `pdrStep`
  - {src}`pdr_mod.f90::pdrStep@"if (allocated(grid%h2Sol) .and. NR2 > 0) pdrRate(NR2) = dble(max(grid%h2Sol(cellP), 0.))"`
* - charge transfer coefficients
  - `pdrCtCoef`
  - {src}`common_mod.f90::pdrCtCoef`
* - H$_2$ formation rate
  - `H2_FORMATION_RATE`
  - {src}`pdr/h2_form.F90::H2_FORMATION_RATE`
* - H$_2$, CO, C I photorates and shielding
  - `H2PDRATE`, `COPDRATE`, `CIPDRATE`, `COSHIELD`, `SCATTER`, `LBAR`
  - {src}`pdr/shield.F90::H2PDRATE`, {src}`pdr/shield.F90::COPDRATE`, {src}`pdr/shield.F90::CIPDRATE`, {src}`pdr/shield.F90::H2SHIELD1`, {src}`pdr/shield.F90::COSHIELD`, {src}`pdr/shield.F90::SCATTER`, {src}`pdr/shield.F90::LBAR`
* - steady-state integration
  - `calculate_abundances`
  - {src}`pdr/calculate_abundances.c`; call {src}`pdr_mod.f90::pdrStep@"call calculate_abundances(abun, pdrRate, nH, Tg, npart, &"`
* - ODE right-hand side
  - generated
  - {src}`pdr/odes_reduced.c`
* - post-solve imposition
  - `pdrStep`
  - {src}`pdr_mod.f90::pdrStep@"if (.true.) then ! D-193: unconditional"..@"abun(iSpI) = availTot*mocIon /(mocNeut+mocIon)"`, {src}`pdr_mod.f90::pdrStep@"! MOCASSIN computes it."+4`
* - channels for `ionBalance`
  - `pdrStep`
  - {src}`pdr_mod.f90::pdrStep@"! D-402: what the network does to each linked element's X and X+"..@"grid%pdrIonRate(cellP, pdrNchan*(iE402-1)+1:pdrNchan*iE402) = real(ch402)"`
* - coolant level populations, CO table
  - `pdrStep`
  - {src}`pdr_mod.f90::pdrStep@"! ---- the PDR's line cooling at MOCASSIN's temperature --------------"..@"grid%pdrCool(cellP) = real(coolTot)"`
* - escape probabilities of the coolant lines
  - `escape_probability`
  - {src}`pdr/escape_probability.F90::escape_probability@"S_ij=TMP2/TPOP"+18`, {src}`pdr/escape_probability.F90::escape_probability@"beta_ij_sum=sum(beta_ij_ray)"..@"beta_save(jlevel,ilevel) = beta_ij"`
* - heating, H$_2$ terms from the level model
  - `pdrStep`
  - {src}`pdr_mod.f90::pdrStep@"call CALC_HEATING(nH, dble(grid%Te(cellP)), Td, chiLoc, dble(pdrVturb)*1.d5, &"..@"& heat(8) + heat(9) + heat(10))"`
* - 3D-PDR’s heating terms
  - `CALC_HEATING`
  - {src}`pdr/heatingfunctions.F90::CALC_HEATING`
* - **Feedback**
  - 
  - 
* - handback
  - `pdrToMocassin`, `setElemAvail`
  - {src}`pdr_mod.f90::pdrToMocassin`, {src}`pdr_mod.f90::setElemAvail`
* - hydrogen budget
  - `rescaleIonToAvail`
  - {src}`pdr_mod.f90::rescaleIonToAvail`
* - molecular locking in the ion solver
  - `ionBalance`
  - {src}`update_mod.f90::updateCell/ionBalance@"availFrac(elem) = &"`, {src}`update_mod.f90::updateCell/ionBalance@"! is left entirely to the ion solver."..@"! chemical terms on the same scaled system: the sink is a"`
* - cosmic-ray ionisation in the ion solver
  - `ionBalance`
  - {src}`update_mod.f90::updateCell/ionBalance@"if (lgPDR .and. ion == 1 .and. pdrNcr > 0) then"..@"& * pdrCrGamma(iCr280)/(1.d0 - dble(omega280))"`
* - atomic photoionisation for the chemistry
  - `updateCell`
  - {src}`update_mod.f90::updateCell@"nPhotoSte(elem,ion) = nPhotoSte(elem,ion) + &"..@"& grid%JSte(cellP,j)*phXSec/(hcRyd*nuArray(j))"`, {src}`update_mod.f90::updateCell/ionBalance@"! D-358: the rates the chemistry solve runs on for a linked"..@"grid%pdrPhotRate(cellP, 6) = real(gH2358)"`
* - H$_2$ continuum opacity
  - `addOpacity`, `yanH2xSec`
  - {src}`ionization_mod.f90@"function yanH2xSec(nu) result(xsec)"`
* - thermal balance, temperature search
  - `thermBalance`, `iterateT`
  - {src}`update_mod.f90::updateCell/thermBalance`, {src}`update_mod.f90::updateCell/iterateT`
* - grain photoelectric heating
  - `setPhotoelHeatCool`
  - {src}`update_mod.f90::updateCell/setPhotoelHeatCool`
* - gas–grain collisional exchange
  - `setDustGasCollHeatCool`
  - {src}`update_mod.f90::updateCell/setDustGasCollHeatCool`
* - CO table and look-up
  - `initPDRcoolTab`, `pdrCoolAt`
  - {src}`pdr_mod.f90::initPDRcoolTab`; {src}`common_mod.f90::pdrCoolAt`
* - CO cooling added in the balance
  - `thermBalance`
  - {src}`update_mod.f90::updateCell/thermBalance@"pdrCoolMol = 0."..@"! molecules, which MOCASSIN has no atom for, are added."`
* - C I, C II, O I atoms with the chemistry’s colliders
  - atom solve; `pdrNeutralRates`
  - {src}`emission_mod.f90::equilibrium@"! D-363: ONE ATOM PER ION. For an ion the chemistry also carries (C I,"..@"#endif"`; {src}`common_mod.f90::buildPdrAtomMap`, {src}`common_mod.f90::setLineColliders`, {src}`common_mod.f90::pdrNeutralRates`
* - extra heating into the thermal balance
  - `thermBalance`
  - {src}`update_mod.f90::updateCell/thermBalance@"heatInt = heatInt + grid%pdrHeatXtra(cellP)/&"+1`
* - second ionisation solve, kept at the end
  - `ionSecondSolve`, `ionKeepSecond`
  - {src}`iteration_mod.f90::MCIterationDriver/ionSecondSolve`, {src}`iteration_mod.f90::MCIterationDriver/ionKeepSecond`
* - **Convergence**
  - 
  - 
* - integrated stop test
  - `cvTotalsUpdate`
  - {src}`iteration_mod.f90::MCIterationDriver/cvTotalsUpdate`; test at {src}`iteration_mod.f90::MCIterationDriver/iterateMC@"if ( lgCvTotals .and. (.not.lgPDR .or. nIterateMC > pdrStartIter) ) then"+0`
* - per-cell $x(\mathrm{H_2})$ test
  - `iterateMC`
  - {src}`iteration_mod.f90::MCIterationDriver/iterateMC@"! ------------------------------------------------------- D-391"..@"if (lgH2fail) then"`
:::
