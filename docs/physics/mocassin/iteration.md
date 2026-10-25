(sec:moc-iteration)=
# The start-up and the Monte Carlo iteration

A MOCASSIN run is a fixed-point iteration {cite:p}`Ercolano2003`: the transfer of {doc}`transfer` computes the radiation field through the opacity of the current ionisation and dust state, every cell then solves its ionisation, thermal and grain-temperature balance in that field ({doc}`ionisation`, {doc}`thermal`, {doc}`dust`), and the next transfer runs through the opacity this produces, until the model stops changing. This page describes the start-up chain that builds the model, the steps of one iteration, the tests that end the run, the automatic increase of the packet count, the warm start and the output written on the way. The PDR coupling adds steps to the iteration; {doc}`../pdr/iteration` describes them ({numref}`tab:steps`), and {doc}`../pdr/convergence` the tests specific to a PDR run.

(sec:moc-startup)=
## The start-up chain
{bdg-success}`used`

The main program runs the routines of {numref}`tab:moc-startup` once, in that order ({src}`mocassin.f90`); `mocassinWarm` replaces the grid-building steps by the reading of a checkpoint ({ref}`sec:moc-warm`).

:::{list-table} The start-up chain of `mocassin` (lines in {src}`mocassin.f90` unless stated).
:name: tab:moc-startup
:header-rows: 1
:widths: 4 22 22 46

* - \#
  - Routine
  - Code
  - What it does
* - 1
  - `readInput`
  - {src}`code <mocassin.f90@"call readInput()">`
  - reads `input/input.in`, sets the defaults, stops on invalid or missing values ({src}`code <set_input_mod.f90::readInput@"! check for missing or invalid values in the model parameters input file">`; advisories kept outside the check chain since {devlog}`D-025`, {devlog}`D-046`, {devlog}`D-270`) and on retired keywords that selected other physics ({devlog}`D-352`)
* - 2
  - `initPDRnetwork`, `initPDRcoolTab`
  - {src}`code <mocassin.f90@"if (lgPDR) call initPDRnetwork()">`
  - PDR builds with `pdr` only: the chemical network, which sizes per-cell arrays ({devlog}`D-022`), and the temperature table on which the PDR cooling is interpolated ({devlog}`D-215`)
* - 3
  - `initCartesianGrid`, per grid
  - {src}`code <mocassin.f90@"call initCartesianGrid(grid3D(iGrid), nxIn(iGrid), nyIn(iGrid), nzIn(iGrid))">`
  - the abundance sets, the frequency grid ({ref}`sec:moc-freq`), the grid arrays, the angle bins of the SED
* - 4
  - `initXSecArray`
  - {src}`code <mocassin.f90@"call initXSecArray()">`
  - photoionisation cross-sections and each element's opacity table ({doc}`ionisation`); dust cross-sections, `makeDustXsec` ({doc}`dust`)
* - 5
  - `setContinuum`
  - {src}`code <mocassin.f90@"call setContinuum()">`
  - source spectra, their cumulative distributions, $L_\star$ or $Q$, the packet energies ({ref}`sec:moc-spectra`)
* - 6
  - `fillGrid`
  - {src}`code <mocassin.f90@"call fillGrid(grid3D(1:nGrids))">`
  - axes, active cells, densities, starting state, sub-grids, mass rescaling ({doc}`grid`)
* - 7
  - `seedPDR`
  - {src}`code <mocassin.f90@"if (lgPDR) call seedPDR(grid3D(1:nGrids))">`
  - PDR runs: the initial chemical state ({ref}`sec:seed`)
* - 8
  - `setStarPosition`
  - {src}`code <mocassin.f90@"call setStarPosition(grid3D(1)%xAxis,grid3D(1)%yAxis,grid3D(1)%zAxis, grid3D(1:nGrids))">`
  - scales the source positions and finds their cells
* - 9
  - `makeElements`, `readData`, `initResLines`, `setLineNuP`, `allocLineArrays`
  - {src}`code <mocassin.f90@"call makeElements()"+13>`
  - with gas: the atomic data and the line list, the resonance lines (with dust), the lines' frequency bins and the line arrays. `makeElements` stays after the grid, though the grid would want its line count, because moving it before changes the model for a reason not understood ({src}`code <mocassin.f90@"! D-294: makeElements is NOT moved here, though initCartesianGrid below">`; {devlog}`D-294`)
* - 10
  - `dustDriver`, per grid
  - {src}`code <mocassin.f90@"call dustDriver(grid3D(iGrid))">`
  - with dust: the dust opacity arrays, grain temperatures set to 50 K
* - 11
  - `setLdiffuse`
  - {src}`code <mocassin.f90@"call setLdiffuse(grid3D(1:nGrids))">`
  - with `diffuseSource`: each cell's share of its luminosity ({ref}`sec:moc-sources`)
* - 12
  - `MCIterationDriver`
  - {src}`code <mocassin.f90@"call MCIterationDriver(grid3D(1:nGrids))">`
  - calls `iterateMC`, which runs every iteration
:::

(sec:moc-iterate)=
## One iteration
{bdg-success}`used`

`iterateMC` is recursive: at the end of an iteration that does not stop the run it advances the counter `nIterateMC` and calls itself ({src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"call iterateMC()">`), so the call depth equals the number of iterations and a local array left allocated at the call stays allocated in every frame below ({devlog}`D-245`). One iteration runs the steps of {numref}`tab:moc-iter`; a PDR run inserts the steps of {numref}`tab:steps` after steps 7, 10 and 11. The opacity of step 2–3 and the emission distributions of step 4 are built from the state the previous iteration left, and the cell update of step 10 uses the field of this iteration's transfer.

:::{list-table} One iteration of `iterateMC`, without the PDR steps (lines in {src}`iteration_mod.f90`).
:name: tab:moc-iter
:header-rows: 1
:widths: 4 22 26 44

* - \#
  - Step
  - Code
  - What it does
* - 1
  - reset
  - {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"! re-initialize MC estimators">`
  - convergence and black-cell flags, `recPDF`, `linePDF`, `totalLines`, `dustPDF` set to zero
* - 2
  - gas opacity
  - {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"call ionizationDriver(grid(iG),i,j,k)">`
  - `ionizationDriver` in each cell (dealt round-robin to the ranks), then summed over ranks ({doc}`ionisation`)
* - 3
  - dust opacity
  - {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"grid(iG)%scaOpac(0:grid(iG)%nCells, 1:nbins) = 0."#1>`
  - absorption and scattering of every species and size below its sublimation temperature, added to the gas opacity; zero in the first iteration with `getEquivalentTau` ({bdg-warning}`not exercised`), which compares that unextinguished SED with the later ones ({src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"if((nIterateMC==1 .and. lgEquivalentTau)) then">`)
* - 4
  - emission distributions
  - {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"call emissionDriver(grid,k,j,i,iG)">`
  - `emissionDriver` in each cell: `recPDF`, `linePDF`, `totalLines`, `dustPDF` and the resonance lines' escape probabilities, summed over ranks ({doc}`emission`)
* - 5
  - zero the estimators
  - {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"grid(iG)%Jste(0:grid(iG)%nCells, 1:nbins) = 0.">`
  - $J^{\mathrm{ste}}$, $J^{\mathrm{dif}}$, `escapedPackets`
* - 6
  - transfer
  - {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"call energyPacketDriver(iStar,load, grid(1:nGrids))"+2#1>`, {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"call energyPacketDriver(iStar=0,n=load, grid=grid(1:nGrids), &"+4#1>`
  - every source's packets, then the diffuse source's cell by cell ({doc}`transfer`)
* - 7
  - estimators
  - {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"grid(iG)%Jste(i,:) = grid(iG)%Jste(i,:) * 1.e-9">`
  - `escapedPackets`, $J^{\mathrm{ste}}$, $J^{\mathrm{dif}}$ summed over ranks; $\times10^{-9}$ to erg s$^{-1}$ cm$^{-2}$, $/8$ under `symmetricXYZ`, the 2D division
* - 8
  - SED
  - {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"if (taskid==0) call writeSED(grid)">`
  - `output/SED.out` ({ref}`sec:moc-sed`)
* - 9
  - snapshot
  - {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"! D-155: the state this MC iteration starts from. The convergence"..@"& grid(iG)%Te(0:grid(iG)%nCells)">`
  - $x(\mathrm H^0)$ and $T_e$ of every cell, the reference of the per-cell test ({devlog}`D-155`), taken only in a model with gas ({devlog}`D-441`)
* - 10
  - cell update
  - {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"& call updateCell(grid(iG),i,j,k)">`
  - `updateCell` in each cell: ionisation and thermal balance, then the grain temperatures; once per iteration ({devlog}`D-216`)
* - 11
  - gather
  - {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"call mpi_allreduce(TeTemp, grid(iG)%Te, size, &">`
  - $T_e$, $n_e$, ionisation fractions, grain temperatures, convergence and black-cell flags summed over ranks
* - 12
  - tests
  - {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"! calculate the percentage of converged cells">`, {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"call cvTotalsUpdate()">`
  - converged-cell percentage, `output/summary.out`; the model-integrated quantities, `output/convergence.out`
* - 13
  - checkpoint
  - {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"if ( totPercent >= convWriteGrid) then">`
  - the grid files when the converged share reaches `writeGrid` ({ref}`sec:moc-output`)
* - 14
  - packet count
  - {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"if (nIterateMC > 1 .and. totPercent < 95. .and. lgAutoPackets &">`
  - `autoPackets` ({ref}`sec:moc-autopackets`)
* - 15
  - stop or recurse
  - {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"if ( lgCvTotals ) then"+0 [plain]>`, {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"else if (nIterateMC >= maxIterateMC) then">`
  - finish and write the outputs if the run-level test passes or `maxIterateMC` is reached; otherwise the next iteration
:::

(sec:moc-cellconv)=
## Per-cell convergence
{bdg-success}`used`

A cell with gas is converged when neither its neutral hydrogen fraction nor its temperature has moved by more than the relative tolerance $\epsilon$ = `convLimit` since the start of the iteration ({src}`code <update_mod.f90::updateCell@"lgCvH0 = abs(deltaXHI) <= XHILimit"+0>`, {src}`code <update_mod.f90::updateCell@"if (allocated(grid%TeIterStart)) then"#1>`):

$$
\left|\frac{x(\mathrm H^0)-x_{\mathrm{start}}(\mathrm H^0)}{x_{\mathrm{start}}(\mathrm H^0)}\right|\le\epsilon,\qquad
\left|\frac{T_e-T_{e,\mathrm{start}}}{T_{e,\mathrm{start}}}\right|\le\epsilon .
$$ (eq:moc-cellconv)

The reference is the snapshot of step 9, not the value at entry to `updateCell` ({devlog}`D-155`); the temperature half was added at {devlog}`D-229`. `convLimit` is this per-cell tolerance and not a share of cells ({devlog}`D-180`); its default is 0.05 ({src}`set_input_mod.f90::readInput@"XHILimit = 0.05"`), and the inputs of this project set it between 0.03 (most dust models) and 0.10 (the PDR fixtures). A PDR run adds the change of $x(\mathrm{H_2})$ across the chemistry ({src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"! The x(H2) half of the per-cell convergence test, moved here from">`; {devlog}`D-179`, {devlog}`D-391`). In a model without gas the test is on the mean grain temperature against the previous iteration's ({src}`code <update_mod.f90::updateCell@"deltaXHI = (grid%Tdust(0,0,cellP) - XOldHI) / XOldHI">`); with gas the grains do not enter it. A cell whose ionisation balance or temperature search failed, or whose temperature reached 30,000 K, is flagged black ({doc}`thermal`; {src}`code <update_mod.f90::updateCell@"grid%lgBlack(cellP) = 1 ! Flag cell if ionization balance failed">`), and the shares of cells without balance and without a temperature solution are reported with the converged share. The converged share counts the active cells (only those in the echo volume with `echo`). {devlog}`D-392` made it a report only; since {devlog}`D-441` it stops a run in a model without gas.

(sec:moc-stop)=
## The run-level test
{bdg-success}`used`

`cvTotalsUpdate` ({src}`iteration_mod.f90::cvTotalsUpdate`; {devlog}`D-391`, {devlog}`D-392`) integrates over the model the emission measure $\int n_e n_i\,\mathrm dV$ of every ion stage carrying at least 1% of its element's ion emission measure, the H$^0$ content where it is at least 1% of the hydrogen (and in a PDR run the H$_2$ and CO contents), and the gas temperature weighted by $n_e n(\mathrm H^+)$, by $n(\mathrm H^0)$ and by $n(\mathrm{H_2})$. The run stops when

$$
\max_q\left|\frac{q_n}{q_{n-3}}-1\right|\le\texttt{convTotals}
$$ (eq:moc-cvtotals)

over the quantities significant at both ends of the three-iteration window (`cvTotK`, {src}`common_mod.f90@"integer, parameter :: cvTotK = 3"+0`); `convTotals` defaults to 0.02. The window means no model with gas stops before iteration 4 ({src}`code <iteration_mod.f90::cvTotalsUpdate@"lgCvTotals = .false. ! not testable yet">`), nor a PDR run before `pdrStartIter`+1 ({devlog}`D-062`). A model without gas has nothing to integrate and stops when the converged share reaches `minConvergence`, the second number of `maxIterateMC` (default 90; {src}`code <iteration_mod.f90::cvTotalsUpdate@"lgCvTotals = (totPercent >= minConvergence)">`; {devlog}`D-441`). Otherwise the run ends at `maxIterateMC` iterations (default 30) and says that it did not converge. {ref}`running-convergence` gives the user's view of the test and {ref}`sec:convergence` what it does and does not see in a PDR run; the $n(\mathrm H^0)$-weighted temperature is carried by the few hundred hot cells of the ionisation front ({lim}`L-52`).

(sec:moc-autopackets)=
## More packets when convergence stalls
{bdg-success}`used`

`autoPackets` $f_{\mathrm{inc}}\,f\,N_{\max}$ (the Lexington models, the dust inputs, `test_Problem`) multiplies every source's packet count by $f$ and divides its packet energy by $f$, keeping the luminosity, whenever the converged share rose by a relative $f_{\mathrm{inc}}$ or less since the previous iteration, the share is below 95% and the total count is below $N_{\max}$ ({src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"if (nIterateMC > 1 .and. totPercent < 95. .and. lgAutoPackets &">`); a diffuse source's packets per cell are multiplied too. It reads the converged-cell share, not the run-level test. Until {devlog}`D-365` the total counted the first source twice, so the doubling stopped at $N_{\max}/2$ ({src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"! D-365: this used to start from nPhotons(1) and then add every star">`).

(sec:moc-output)=
## End of the run and the output
{bdg-success}`used`

When the run stops, rank 0 writes the grid files with `writeGrid` ({src}`grid_mod.f90::writeGrid`: `grid0.out`–`grid3.out`, `dustGrid.out`, `photoSource.out`, `resLineEsc.out` with dust and gas, `frontField.out` and, in a PDR run, the PDR state, `pdrCoolSp.out`, `pdrRad.out` and `thermBudget.out`), `writeFUVField` in a PDR build, and with gas the line, temperature and ionisation tables of `outputGas` ({src}`output_mod.f90::outputGas`; {doc}`emission`); a PDR run first keeps the last second ionisation solve and sweeps the H$_2$ level model to convergence ({ref}`sec:convergence`). Before the end, `SED.out`, `summary.out` and (with gas) `convergence.out` are written at every iteration; the grid files whenever the converged share reaches `writeGrid`, whose default 0 means every iteration ({src}`set_input_mod.f90::readInput@"convWriteGrid = 0."`); and with `output` the tables of `outputGas` as well ({src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"if (lgOutput .and. taskid == 0 ) then">`). {doc}`../../user-guide/outputs` describes each file.

(sec:moc-warm)=
## The warm start
{bdg-success}`used`

`mocassinWarm` resumes a run from the grid files ({src}`mocassinWarm.f90`): it reads the input ({src}`code <mocassinWarm.f90@"call readInput()">`, restored at {devlog}`D-317`), the PDR network, then `resetGrid` ({src}`grid_mod.f90::resetGrid`) in place of steps 3, 6 and 7 of {numref}`tab:moc-startup`, and then the source positions, cross-sections, spectra, line arrays and dust opacity as a cold start does. `resetGrid` reads `photoSource.out` (the sources and their packet counts), `grid3.out` (the run's parameters, among them `nbins`, the frequency range, `convLimit`, `autoPackets`, `maxIterateMC` and `minConvergence`, {src}`code <grid_mod.f90::resetGrid@"read(77, *) maxIterateMC, minConvergence"+0>`), `grid0.out`–`grid2.out`, `dustGrid.out` and, with `pdr`, `pdrGrid.out` and `pdrLineEm.out`. With dust and gas it also reads `resLineEsc.out` back (`readResLineEsc`), and when `output` is off it writes the gas tables and `SED.out` once more after the iteration. These values override the input's: the packet count and the iteration limit of a warm start are the checkpoint's, not those of `input.in` ({devlog}`D-440`). The run counts iterations from 1 again; a PDR state is resumed from the first iteration and not re-seeded ({src}`code <grid_mod.f90::resetGrid@"! D-393: the PDR was running when the checkpoint was written, so it">`; {devlog}`D-393`). `resetGrid` does not allocate the iteration-start copies, so the temperature and $x(\mathrm{H_2})$ halves of the per-cell test pass every cell and the converged share of a warm start does not measure what a cold start's does ({devlog}`D-440`). `mocassinWarm` does not call `setLdiffuse`, and `resetGrid` leaves each cell's share of a diffuse source at zero ({src}`code <grid_mod.f90::resetGrid@"grid(iG)%LdiffuseLoc=0.">`), so a diffuse source emits nothing in a warm start ({lim}`L-85`). The warm start was made to run at {devlog}`D-316` and {devlog}`D-317` and is used in the tutorial ({doc}`../../tutorials/dust-gas-pdr`).
