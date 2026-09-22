! Copyright (C) 2005 Barbara Ercolano
! Modified 2025-2026 by Hektor Monteiro for MOCASSIN-PDR; the changes are
! recorded in the git history and in DEVLOG.md.
!
! Version 2.02
module dust_mod
  use common_mod
  use continuum_mod
  use interpolation_mod
  use xSec_mod

  implicit none

  contains

    subroutine dustDriver(grid)
      !use mpi
      implicit none
      include 'mpif.h'

      type(grid_type), intent(inout) :: grid

      ! local variables

      real, allocatable :: absOpacTmp(:,:)
      real, allocatable :: scaOpacTmp(:,:)

      integer :: err ! allocation error status
      integer :: iP,jP,kP ! counter
      integer(kind=int64) :: size ! size of MPI reducing string
      integer :: yTop

      logical,save :: lgFirstDustEm=.true.

      ! allocate dust opacity arrays

      allocate(absOpacTmp(0:grid%nCells, 1:nbins), stat = err)
      if (err /= 0) then
         print*, "! dustOpacity: can't allocate absOpacTmp memory"
         stop
      end if

      allocate(scaOpacTmp(0:grid%nCells, 1:nbins), stat = err)
      if (err /= 0) then
         print*, "! dustOpacity: can't allocate scaOpacTmp memory"
         stop
      end if

      allocate(grid%absOpac(0:grid%nCells, 1:nbins), stat = err)
      if (err /= 0) then
         print*, "! dustOpacity: can't allocate absOpac memory"
         stop
      end if

      allocate(grid%scaOpac(0:grid%nCells, 1:nbins), stat = err)
      if (err /= 0) then
         print*, "! dustOpacity: can't allocate scaOpac memory"
         stop
      end if

      if (.not. lgWarm) then
         allocate(grid%Tdust(0:nSpeciesMax, 0:nSizes, 0:grid%nCells), stat = err)
         if (err /= 0) then
            print*, "! dustOpacity: can't allocate Tdust memory"
            stop
         end if
         grid%Tdust   = 50.
      end if

      ! initialize arrays
      grid%absOpac = 0.
      grid%scaOpac = 0.

      ! initialize tmp arrays
      absOpacTmp = 0.
      scaOpacTmp = 0.

      if (lg2D) then
         yTop = 1
      else
         yTop = grid%ny
      end if


      do iP = taskid+1, grid%nx, numtasks
         do jP = 1, yTop
            do kP = 1, grid%nz

               call dustOpacity()

            end do
         end do
      end do

      size = (grid%nCells+1)*nbins

      call mpi_allreduce(grid%absOpac, absOpacTmp, size, &
&                             mpi_real, mpi_sum, mpi_comm_world, ierr)
      call mpi_allreduce(grid%scaOpac, scaOpacTmp, size, &
&                             mpi_real, mpi_sum, mpi_comm_world, ierr)


      do iP = 0, grid%nCells
         do jP = 1, nbins
            grid%absOpac(iP,jP) = absOpacTmp(iP,jP)
            grid%scaOpac(iP,jP) = scaOpacTmp(iP,jP)
         end do
      end do

      ! calculate the dust emission integrals
      if (lgFirstDustEm) then
         call dustEmissionInt()
         lgFirstDustEm=.false.
      end if
      lgDust = .true.


    contains


      subroutine dustOpacity()
        implicit none

        integer :: i ! counter

        ! check whether this cell is outside the nebula
        if (grid%active(iP,jP,kP) <= 0) return

        ! calculate scaOpac array
        ! calculate absOpac array
        do i = 1, nbins
           grid%scaOpac(grid%active(iP,jP,kP),i) = grid%Ndust(grid%active(iP,jP,kP))*&
                & xSecArray(dustScaXsecP(0,1)+i-1)
           grid%absOpac(grid%active(iP,jP,kP),i) = grid%Ndust(grid%active(iP,jP,kP))*&
                & xSecArray(dustAbsXsecP(0,1)+i-1)
        end do
        
      end subroutine dustOpacity


      ! this subroutine calculates the dust emission integrals for each species with non-zero
      ! abundance for temperatures between 0 and nTempsK in steps of 1K.
      ! assumes grains emit as blackbodies
      ! to be used later to determine dust Temps according to
      ! Kirchoff's law
      subroutine dustEmissionInt()
        implicit none

        real :: bb ! blackbody flux

        integer :: i, nT, nS, ai  ! counters
        integer :: probeStat, nuP044, nuP200          ! D-308 probe
        character(len=32) :: probeEnv                 ! D-308 probe

        character(len=50) :: cShapeLoc


        allocate(dustEmIntegral(1:nSpecies,1:nSizes,nTemps), stat = err)
        if (err /= 0) then
           print*, "! dustEmissionInt: can't allocate dustEmissionInt memory"
           stop
        end if
        dustEmIntegral = 0.

        cShapeLoc = 'blackbody'
        call locate(nuArray, 0.44, nuP044)             ! D-308 probe
        call locate(nuArray, 2.00, nuP200)             ! D-308 probe

        do nS = 1, nSpecies
           do ai = 1, nSizes
              do nT = 1, nTemps
                 do i = 1, nbins
                    bb = getFlux(nuArray(i), real(nT), cShapeLoc)
                    dustEmIntegral(nS,ai,nT) = dustEmIntegral(nS,ai,nT)+&
                         & xSecArray(dustAbsXsecP(nS,ai)+i-1)*bb*fr1Ryd*widFlx(i)
                 end do
              end do
           end do
        end do

        ! the hPlanck is re-introduced here (was excluded in the bb calcs)
        dustEmIntegral = dustEmIntegral*hPlanck*4.

        ! D-308 probe: the emission side of the dust temperature balance, for
        ! comparison against an independent integral C_abs B_nu(T) dnu. Opt-in
        ! and taskid 0 only, so it is inert in a normal run.
        call get_environment_variable("MOCASSIN_DUSTPROBE", probeEnv, status=probeStat)
        if (probeStat == 0 .and. trim(probeEnv) == "on" .and. taskid == 0) then
           print*, "! [D308] nSpecies=", nSpecies, " nSizes=", nSizes, &
                & " nbins=", nbins, " nTemps=", nTemps
           do nS = 1, min(nSpecies, 2)
              do ai = 2, nSizes, max(1, nSizes/4)
                 do nT = 20, 60, 20
                    print*, "! [D308] emInt  nS", nS, " ai", ai, &
                         & " a[um]", grainRadius(ai), " T", nT, &
                         & " dustEmIntegral", dustEmIntegral(nS,ai,nT)
                 end do
                 print*, "! [D308] Cabs   nS", nS, " ai", ai, &
                      & " a[um]", grainRadius(ai), &
                      & " at 0.44Ryd", xSecArray(dustAbsXsecP(nS,ai)+nuP044-1), &
                      & " at 2.0Ryd", xSecArray(dustAbsXsecP(nS,ai)+nuP200-1)
              end do
           end do
        end if

      end subroutine dustEmissionInt

    end subroutine dustDriver

  end module dust_mod


