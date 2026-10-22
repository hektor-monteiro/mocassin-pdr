(sec:iteration)=
# The iteration in which the chain runs
All of the coupling lives inside MOCASSIN’s MC iteration, the recursive subroutine `iterateMC` ({src}`iteration_mod.f90::MCIterationDriver/iterateMC`), which advances the iteration counter and calls itself until the stop test of {ref}`sec:convergence` passes or the maximum number of iterations is reached. The PDR part switches on at iteration `pdrStartIter` (default 1, {src}`common_mod.f90@"integer :: pdrStartIter=1 ! let MOCASSIN converge this many MC iterations first (D-062)"`); a larger value lets MOCASSIN first converge an ionisation structure, a gas and a dust temperature without molecules. From then on every iteration executes the steps of {numref}`tab:steps`, in that order.

:::{list-table} One MC iteration with the PDR coupling active (3D build). Lines are in {src}`iteration_mod.f90` unless stated.
:name: tab:steps
:header-rows: 1
:widths: 4 25 25 38

* - \#
  - Step
  - Location
  - What it does
* - 1
  - MC transfer
  - `energyPacketDriver` for the sources ({src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"call energyPacketDriver(iStar,load, grid(1:nGrids))"+2#1>`) and for the optional diffuse source ({src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"call energyPacketDriver(iStar=0,n=load, grid=grid(1:nGrids), &"+4#1>`)
  - propagates the energy packets of every source; an absorbed packet is re-emitted on the spot by the local gas or dust and followed until it escapes; accumulates $J^{\mathrm{ste}}$ and $J^{\mathrm{dif}}$ ({ref}`sec:field`)
* - 2
  - estimator units
  - {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"grid(iG)%Jste(i,:) = grid(iG)%Jste(i,:) * 1.e-9">`, {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"grid(iG)%Jste(i,:) = grid(iG)%Jste(i,:)/8.">`
  - multiplies by $10^{-9}$ (packet luminosity in $10^{36}$ erg s$^{-1}$, cell volume in $10^{45}$ cm$^3$, path lengths in cm) and divides by 8 for a `symmetricXYZ` octant
* - 3
  - dust per cell
  - `calibratePDRdust` {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"call calibratePDRdust(grid(1:nGrids))">` (first time), `dustPerCell` {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"call dustPerCell(grid(1:nGrids))">`
  - $R_{\mathrm{FUV}}$, $A_{V}/N_{\mathrm H}$, grain area per H, model-wide fallbacks ({ref}`sec:dust`)
* - 4
  - columns and $A_{V}$
  - `computeAVdust` {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"call dustPerCell(grid(1:nGrids))">`
  - `snapDiffuseSources` (snapshot for the diffuse walk), `computeAVradial` ($A_{V}$ and source-ward columns) ({ref}`sec:geometry`)
* - 5
  - field summary
  - `mocassinToPDR` {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"! the first attempt: mean f_mol 1.0000 in 100.00% of cells.">`
  - $\chi$ (local) and $\chi_0$ (geometric, unattenuated) per cell
* - 6
  - seed (first PDR iteration only)
  - {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"call seedMolecules(grid(1:nGrids))">`, {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"! start needs the same, from the resumed abundances.">`
  - `seedMolecules`, then steps 4–5 again on the seeded abundances, then `pdrToMocassin` ({ref}`sec:seed`)
* - 7
  - H$_2$ level model
  - `h2LevelModel(grid,1)` {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"call h2LevelModel(grid(1:nGrids), 1)">`
  - one sweep over all cells on this iteration’s field ({ref}`sec:h2model`)
* - 8
  - MOCASSIN cell update
  - `updateCell` {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"& call updateCell(grid(iG),i,j,k)">`
  - ionisation and thermal balance of every cell; stores the atomic photoionisation and recombination rates the chemistry will use
* - 9
  - chemistry
  - `pdrStep` ({src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"call pdrStep(grid(iG),i,j,k)">`), cells dealt round-robin to the ranks ({src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"if (mod(iCell-(taskid+1),numtasks)==0) then"+6>`), then `MPI_Allreduce` of abundances, heating, cooling and rates
  - photorates, steady-state solve, heating and cooling for the thermal balance ({ref}`sec:photorates`–{ref}`sec:chemistry`)
* - 10
  - handback
  - `pdrToMocassin` {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"& call pdrToMocassin(grid(1:nGrids))">`
  - fraction of each element not in molecules (`elemAvail`)
* - 11
  - second ionisation solve
  - `ionSecondSolve` called at {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"call ionSecondSolve(iG, 2)">` (routine {src}`code <iteration_mod.f90::MCIterationDriver/ionSecondSolve>`); its control pass, before the chemistry, at {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"call ionSecondSolve(iG, 1)">`
  - `ionBalance` solved again on the channels and molecular content this iteration’s chemistry left, then put back ({devlog}`D-404`); the result is set aside for step 15
* - 12
  - damping, hydrogen budget
  - {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"if (lgPDR .and. iterDamp > 0. .and. nIterateMC >= pdrStartIter) then">` (only if `iterDamp`$>0$; default 0), `rescaleIonToAvail` {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"& call rescaleIonToAvail(grid(1:nGrids))">`
  - ion stages rescaled to `elemAvail` so that $x(\mathrm{H^0})+x(\mathrm{H^+})+2x(\mathrm{H_2})=1$
* - 13
  - stop test
  - {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"if ( lgCvTotals .and. (.not.lgPDR .or. nIterateMC > pdrStartIter) ) then"+0>`
  - integrated-quantity test (`convTotals`, {ref}`sec:convergence`)
* - 14
  - next iteration
  - recursive call of `iterateMC`
  - the opacity of the next transfer is built from this iteration’s ionisation, dust and $n(\mathrm{H_2})$
* - 15
  - finish
  - `ionKeepSecond` {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"call ionKeepSecond()"#1>`/{src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"call ionKeepSecond()"#2>` (routine {src}`code <iteration_mod.f90::MCIterationDriver/ionKeepSecond>`), `h2LevelModel(grid,12)` {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"! runs on the stages that are written.">`/{src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"if (lgPDR) call h2LevelModel(grid(1:nGrids), 12) ! H-007, H-012">`, outputs
  - the last second solve replaces the first in the written model; level model swept to convergence on the final model; `h2Cells.out`, `lineFluxH2.out`, `h2Pop.bin`
:::

(sec:lags)=
## What each step reads, and from when
The coupling is a fixed-point iteration in which some inputs are one iteration old. Within iteration $n$:

- the **radiation field** used by steps 3–9 is iteration $n$’s, transported through the opacity built from iteration $n-1$’s ionisation, dust and $n(\mathrm{H_2})$;

- the **shielding columns** (steps 4 and 7) are integrated over the abundances left by iteration $n-1$’s chemistry. The snapshot is taken before any cell of iteration $n$ is solved, so the columns do not depend on the rank count or on the order in which the cells are solved;

- the **level model** (step 7) runs before `updateCell`: it sees iteration $n-1$’s $T_e$, collider abundances and $n(\mathrm{H_2})$, and iteration $n$’s field; the other cells’ level populations in its columns are those of its previous sweep (a Jacobi iteration);

- **MOCASSIN’s ionisation balance** (step 8) takes the chemistry’s channels to and from molecules, and normalises the ion stages to the molecular content, of iteration $n-1$ ({lim}`L-47`); step 11 measures what the delay costs and, at the end of the run, removes it from the written ions;

- the **chemistry** (step 9) sees iteration $n$’s $T_e$, $n_e$, ionisation and atomic rates (step 8), iteration $n$’s field, the step-7 Solomon rates and the columns of step 4;

- the **coolant line escape** in step 9 integrates the optical depth over the level populations of the other cells as stored on the rank; these are iteration $n-1$’s except for cells solved earlier in the same sweep on the same rank, so this one input does depend weakly on the order of the sweep and the rank count;

- the **heating terms** that MOCASSIN takes from the chemistry and the level model (`pdrHeatXtra`) and its **CO cooling table** enter step 8 as step 9 of iteration $n-1$ left them, and the heating terms are held fixed during the temperature search ({ref}`sec:thermal`). The cosmic-ray, turbulent and chemical terms were evaluated at $T_e^{(n-1)}$; the H$_2$ terms come from the level model of iteration $n-1$, which ran at $T_e^{(n-2)}$.

Inside one iteration the chemistry is solved once per cell: every input of the solve is frozen during the iteration, so repeating it would reproduce the same answer ({devlog}`D-354`, which retired the inner coupling loop after finding that a column rescale between passes was the only thing that changed and that it oscillated). The damping across iterations (`iterDamp`) is off by default ({devlog}`D-406`): with it, the written model was a blend of solves that trailed the undamped one by three to six iterations and, where a cell has two solutions, wrote states no solve gave ({lim}`L-49`).

At a fixed point of the iteration every lagged input equals its current value, so the lags determine the path to the solution, not the solution. Two things qualify this. First, the MC field is redrawn at every iteration, so the fixed point is reached only in a statistical sense: per-cell quantities fluctuate about it with the MC noise of {ref}`sec:mcnoise`, and because the photorates are non-linear in the field and the shielding is non-linear in the columns, the noise can bias cell means ({lim}`L-26`, {devlog}`D-408`). Second, the coupled system has cells with two stable states (the carbon ionisation turn, {devlog}`D-405`), in which the lagged inputs decide which state a cell is in at a given iteration.
