! Copyright (C) 2003 Barbara Ercolano
! Modified 2025-2026 by Hektor Monteiro for MOCASSIN-PDR; the changes are
! recorded in the git history and in DEVLOG.md.
!
! MoCaSSiNwarm = MOnte CArlo SImulationS of Nebulae
! this is the warm-start driver of the simulation
! (requires grid1.out,grid2.out,grid3.out files)
!
! Version 2.02
program MoCaSSiNwarm
    use common_mod
    use constants_mod
    use dust_mod
    use emission_mod        ! D-316: setLineNuP, before the line arrays are sized
    use grid_mod
    use iteration_mod
    use output_mod
#ifdef PDR
    use pdr_mod
#endif
    use set_input_mod
    use xSec_mod
    use readdata_mod
    
    implicit none
    include 'mpif.h'

    type(grid_type) :: grid3D(maxGrids) ! the 3D Cartesian  grid

    integer         :: iGrid            !

    real            :: etime
    real, dimension(2) :: tarray,timing        ! cputimer
    integer         :: nhours, nminutes, nseconds

    timing(1)=etime(tarray)/60.0


    call mpi_init(ierr)
    call mpi_comm_rank(MPI_COMM_WORLD, taskid, ierr)
    call mpi_comm_size(MPI_COMM_WORLD, numtasks, ierr)

!    starttime = mpi_wtime()

    lgWarm = .true.

    ! D-316: read the input parameters. This was commented out, which left
    ! lgPDR at its module default of .false. for the whole warm start - so
    ! resetGrid's `if (lgPDR)` guard skipped every PDR allocation, and then
    ! the compile-time `#ifdef PDR` code in updateCell read the unallocated
    ! AVeff. resetGrid itself assumes this has run: at grid_mod.f90:3590 it
    ! validates "this run has pdr enabled" (lgPDR, from the input) against
    ! lgPDRrestart (from the checkpoint), so the checkpoint flag only
    ! corroborates the input, it does not supply it.
    call readInput()

    ! D-334: record the Monte Carlo seed in the run log. A run that prints
    ! "clock-seeded" cannot be reproduced; one that prints a seed can, at the
    ! same rank count.
    if (taskid == 0) then
       if (randomSeed < 0) then
          print*, "! mocassin: random seed = clock-seeded (this run is NOT reproducible)"
       else
          print*, "! mocassin: random seed =", randomSeed, " (reproducible at np =", numtasks, ")"
       end if
    end if

    if (taskid == 0) then
        print*, "MOCASSIN version ",VERSION
        print*, "Data directories: ",PREFIX,"/share/mocassin/data,"
        print*, "                  ",PREFIX,"/share/mocassin/dustData"
        print*, " "
    end if

    if (taskid == 0) then
        print*, " "
    end if

#ifdef PDR
    ! network before resetGrid: it sizes pdrAbun (D-022). Once, not per grid.
    if (lgPDR) call initPDRnetwork()
    if (lgPDR) call initPDRcoolTab()          ! D-215
#endif

    ! reset the 3D cartesian grid.
    ! D-316: this used to loop `call resetGrid(grid3D(iGrid))` AND then call
    ! `call resetGrid(grid3D)`. resetGrid's dummy is `grid(maxGrids)`, an
    ! array, so the loop form passed a scalar and, by sequence association,
    ! aliased the same storage - the grid was reset twice, reading every
    ! checkpoint file twice. One call, on the array, is what it always meant.
    call resetGrid(grid3D)

    call setStarPosition(grid3D(1)%xAxis,grid3D(1)%yAxis,grid3D(1)%zAxis,grid3D)

    ! initialize opacities x sections array
    call initXSecArray()

    ! set the ionzing continuum according to the contShape variable
    call setContinuum()

    ! prepare atomica data stuff
    if (lgGas) then
      call makeElements()
      call readData()
      ! D-316: the warm start needs the line arrays sized exactly as the cold
      ! start does. It never called these, which did not show while line
      ! transport was off by default - linePDF was then only needed under
      ! lgDebug. D-307 made transport the default, and setDiffusePDF stopped
      ! with "linePDF unallocated with line transport on". Same order as
      ! mocassin.f90: setLineNuP settles nLinesPDF, then the arrays are sized.
      ! D-376: the resonance lines first, as mocassin.f90 does, and the escape
      ! fractions the checkpointed run used
      if (lgDust) call initResLines(grid3D(1:nGrids))
      call setLineNuP()
      do iGrid = 1, nGrids
         call allocLineArrays(grid3D(iGrid))
      end do
      if (lgDust) call readResLineEsc(grid3D(1:nGrids))
    endif

    if (taskid == 0) then
        print*, "Total number of grids (mother+sub-grids): ", nGrids
        print*, "Mother grid used:"
        print*, grid3D(1)%xAxis
        print*, grid3D(1)%yAxis
        print*, grid3D(1)%zAxis
    end if

    ! if grains are included, calculate the dust opacity
    if (lgDust) then
       do iGrid = 1, nGrids
          call dustDriver(grid3D(iGrid))
       end do
    end if

    call mpi_barrier(mpi_comm_world, ierr)

    ! start the Monte Carlo simulation
    call MCIterationDriver(grid3D(1:nGrids))

    if (taskid ==  0 .and. .not.lgOutput) then
        ! determine final statistics
        if (lgGas) call outputGas(grid3D)
        call writeSED(grid3D)
        if (contCube(1)>0. .and. contCube(2)>0. ) &
             & call writeContCube(grid3D, contCube(1),contCube(2))
    end if

    call mpi_barrier(mpi_comm_world, ierr)

    ! free all space allocated to the 3D grid
    do iGrid=1, nGrids
       call freeGrid(grid3D(iGrid))
    end do

!    endtime  = mpi_wtime()
!
!    if (taskid == 0) then
!        print*, "time: ", endtime-starttime
!    end if

     timing(2) = etime(tarray)/60.0
     nhours = int((timing(2)-timing(1))/60.)
     nminutes = int(mod(timing(2)-timing(1),60.))
     nseconds = nint(60.*((timing(2)-timing(1))-real(nhours*60)-real(nminutes)))

     write(6,100)nhours,nminutes,nseconds
 100 format('total run time per processor ',1i3.2,':',1i2.2,':',1i2.2' (HMS)')


    call mpi_finalize(ierr)
    stop 'mpi done'


end program MoCaSSiNwarm


