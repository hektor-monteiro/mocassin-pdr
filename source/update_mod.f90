! Copyright (C) 2005 Barbara Ercolano
! Modified 2025-2026 by Hektor Monteiro for MOCASSIN-PDR; the changes are
! recorded in the git history and in DEVLOG.md.
!
! Version 2.02
module update_mod
    use constants_mod
    use common_mod
    use composition_mod
    use emission_mod
    use grid_mod
    use interpolation_mod
    use xSec_mod

    contains

      subroutine updateCell(grid, xP, yP, zP)
        implicit none

        type(grid_type), intent(inout) :: grid         ! the grid

        real, parameter :: Y0 = 0.5, Y1 = 0.2          ! see Baldwin et al. 1991

        real                           :: deltaXHI        ! delta ionDen of H0
        real                           :: convRef         ! D-155 iteration-start x(H0)
                                                       ! H0 2 is from He0 and 3 is
                                                       ! is for He+)
        real                           :: phXSec      ! ph xSec of ion M at freqency bin j
        real                           :: thResidual   ! thermal balance residual
        real                           :: thResidualHigh! ther bal residual-high lim
        real                           :: thResidualLow! ther bal residual-low lim
        real                           :: Thigh        ! T high limit [K]
        real                           :: Tlow         ! T low limit  [K]
        real                           :: XOldHI       ! old ionDen of H0 at this cell
#ifdef PDR
        logical                        :: lgBudEntry   ! D-217: next thermBalance is the first
#endif

        ! dust-gas interaction heating and cooling process
        real                           :: grainEmi, grainRec ! grain emissions and recom
        real, allocatable                  :: gasDustColl_d(:,:) ! cooling/heating of the
                                                             ! dust through collisions with grains
        real                           :: gasDustColl_g ! cooling/heating of the
                                                       ! gas through collisions with grains
        real, allocatable                   :: photoelHeat_d(:,:) ! cooling of dust by photoelectric
                                                             ! emission
        real                           :: photoelHeat_g ! heating of gas by dust photoelctric
                                                       !emission
        real, allocatable                   :: grainPot(:,:)  ! [Ryd]

        real, parameter                :: hcRyd_k = &  ! constant: h*cRyd/k (Ryd at inf used) [K]
             & 157893.94
        real, parameter                :: hcRyd = &    ! constant: h*c*Ryd (Ryd at inf used) [erg]
             & 2.1799153e-11
        real, parameter                :: thLimit = 0.01! convergence limit T-iteration

        real, dimension(nElements, nstages) &
             & :: alphaTot     ! total recombination coeffs

        real, dimension(nElements, nStages) &
             & :: nPhotoSte, & ! # of stellar photoionizations
             & nPhotoDif    ! # of diffuse photoionizations



        integer, intent(in)            :: xP, yP, zP   ! cell indexes on the Cartesian axes

        ! local variables
        logical                        :: lgHit        ! has this cell been hit by a photon?

        integer , allocatable               :: grainPotP(:,:)
        integer                        :: cellP        ! points to this cell
        integer                        :: highNuP      ! pointer to highest energy of shell
        integer                        :: IPnuP        ! pointer to this ion's IP in NuArray
        integer                        :: xSecP        ! pointer to an ion's xSec in xSecArray
        integer                        :: elem         ! element counter
        integer                        :: g0, g1       ! stat weights
        integer                        :: ion          ! ionization stage counter
        integer                        :: i,j          ! counter
        integer                        :: nElec        ! # of electrons in ion
        integer                        :: nIterateGC   ! # of GC iterations
        integer                        :: nIterateT    ! # of T iterations
        integer                        :: nIterateX    ! # of X iterations
        integer                        :: outShell     ! outer shell number (1 for k shell)
        integer                        :: nspU
        integer, parameter             ::  nTbins=300  ! number of enthalpy bins for T spike
        integer, parameter             :: maxIterateGC = 100 ! limit to number of grain charge it
        integer, parameter             :: maxIterateX = 50 ! limit to number of X-iterat ions
        integer, parameter             :: maxIterateT = 50 ! limit to number of T-iterations


        ! check whether this cell is outside the nebula
        if (grid%active(xP, yP, zP)<=0) return

        cellP = grid%active(xP, yP, zP)

        if (lgMultiDustChemistry) then
           nspU = grid%dustAbunIndex(cellP)
        else
           nspU = 1
        end if

        ! initialise lgBlack
        grid%lgBlack(cellP) = 0

        ! initialise lgHit
        lgHit = .false.

        ! find out if this cell has been hit by at least one photon
        if (.not.lgDebug) then
           do i = 1, nbins
              if ( grid%Jste(cellP,i) > 0.) then
                 lgHit = .true.
                 exit
              end if
           end do
        else
           do i = 1, nbins
              if ( (grid%Jste(cellP,i) > 0.) .or. &
                   & (grid%Jdif(cellP,i) > 0.)) then
                 lgHit = .true.
                 exit
              end if
           end do
        end if

        ! in the case of a light echo only update cells inside the echo
        if (lgEcho) then
           if (grid%echoVol(xP,yP,zP).eq.0.0) then
              grid%Tdust(:,:,cellP) = echoTemp
              TdustTemp(:,:,cellP)  = grid%Tdust(:,:,cellP)
              return
           end if

        end if

        ! do not update this cell if there were no hits
        if (.not.lgHit) then

            if (lgTalk) print*, "! updateCell [talk]: no photon hits, &
                 &returning...", xP,yP,zP

            if (lgDust) then
               TdustTemp(:,:,cellP)       = grid%Tdust(:,:,cellP)
            end if

            if (lgGas) then
               ! the grid values stay the same
               TeTemp(cellP)         = grid%Te(cellP)
               NeTemp(cellP)         = grid%Ne(cellP)
               ionDenTemp(cellP,:,:) = grid%ionDen(cellP,:,:)
            end if

            grid%noHit = grid%noHit+1.

            return
        end if

        if (lgGas) then

           ! initialize local Te and Ne

           TeUsed     = grid%Te(cellP)
           NeUsed     = grid%Ne(cellP)
           ionDenUsed = grid%ionDen(cellP, :, :)


           ! save present value of H0 abundance in XOldHI
           XOldHI = grid%ionDen(cellP,elementXref(1),1)

           nPhotoSte = 1.e-20
           if (lgDebug) nPhotoDif = 1.e-20


           ! calculate the number of stellar and diffuse photoionizations for each species
           ! NOTE: no need to time by the frequency bin width (widflx(j)) because JSte and JDif
           !       were calculated for each individual bin
           do elem = 1, nElements  ! begin element loop
            do ion = 1, min(elem, nStages-1) ! begin ion loop
               if(.not.lgElementOn(elem)) exit

               if (elem > 2) then

                  ! find the number of electrons in this ion
                  nElec = elem - ion + 1

                  ! find the outer shell number and statistical weights
                  call getOuterShell(elem, nELec, outShell, g0, g1)

                  ! get pointer to this ion's IP in NuArray
                  IPnuP = elementP(elem, ion, outShell, 1)

                  ! get pointer to this cell's highest energy
                  highNuP = elementP(elem, ion, outShell, 2) - 1

               else if (elem == 1) then ! HI

                  IPNuP   = HlevNuP(1)
                  highNuP = nbins

               else if ( (elem == 2) .and. (ion == 1) ) then ! HeI

                  IPNuP   = HeIlevNuP(1)
                  highNuP = nbins

               else if ( (elem == 2) .and. (ion == 2) ) then ! HeII

                  IPNuP   = HeIIlevNuP(1)
                  highNuP = nbins

               end if

               do j = IPnuP, highNuP ! begin frequency loop
                  if ( elem > 2 ) then

                     ! get pointer to phot xSec of this ion in xSecArray
                     xSecP = elementP(elem, ion, outShell, 3)

                     ! get phot xSec of ion at this energy
                     phXSec = xSecArray(j+xSecP-IPnuP+1-1)

                  else if ( elem == 1 ) then ! HI

                     phXSec  = xSecArray(j-IPnuP+1+HlevXSecP(1)-1)

                  else if ( (elem == 2) .and. (ion == 1) ) then ! HeI

                     phXSec  = xSecArray(j-IPnuP+1+HeISingXSecP(1)-1)

                  else if ( (elem == 2) .and. (ion == 2) ) then ! HeII

                     phXSec  = xSecArray(j-IPnuP+1+HeIIXSecP(1)-1)

                  end if

                  if ((phXSec < 1.e-35) ) then
!                     print*, "! updateCell: [warning] bad xSec value &
!                          & exiting loop (j, phXSec)",&
!                          & nuArray(j), phXSec
!                     exit
                     phXSec = 0.
                 end if

                  if ((nuArray(j) < 1.e-35) ) then
                     print*, "! updateCell: insane nu value (j, nuArray(j)", &
                          & j, nuArray(j)
                     stop
                  end if

                  ! stellar photoionizations

                  if ( grid%Jste(cellP,j) > 0. )then

                     nPhotoSte(elem,ion) = nPhotoSte(elem,ion) + &
                          & grid%JSte(cellP,j)*phXSec/(hcRyd*nuArray(j))


                  end if

                  ! diffuse photoionizations

                  if (lgDebug) then
                     if ( grid%Jdif(cellP,j) > 0. ) then
                        nPhotoDif(elem,ion) = nPhotoDif(elem,ion) + &
                             & grid%JDif(cellP,j)*phXSec/(hcRyd*nuArray(j))

                     end if
                  end if

               end do ! end frequency loop
            end do ! end ion loop
         end do ! end element loop

         ! zero out T-iteration components
         nIterateT      = 0
         thResidual     = 0.
         thResidualHigh = 0.
         thResidualLow  = 0.
         Thigh          = 0.
         Tlow           = 0.

         if (lgDust .and. lgGas .and. lgPhotoelectric) then
            allocate (grainPot(1:nSPecies, 1:nsizes))
            grainPot=0.
            allocate (grainPotP(1:nSPecies, 1:nsizes))
            grainPotP=0
            allocate (photoelHeat_d(1:nSPecies, 1:nsizes))
            photoelHeat_d=0.
            allocate ( gasDustColl_d(1:nSPecies, 1:nsizes))
            gasDustColl_d=0.
         end if

         ! call the recursive iteration procedure for the gas
#ifdef PDR
         ! D-217: the first thermBalance inside iterateT is at TeEntry, the
         ! temperature this cell carried into the iteration, evaluated with
         ! the radiation field the new MC transfer just built. Its budget is
         ! what the new iteration did to a cell before the solver moved it.
         lgBudEntry = .true.
#endif
         call iterateT()

         ! call the non recursive itaration procedure for the dust
         if (lgDust) call getDustT()

         ! this was added to help implementing MPI comunication
         if (lgDust) TdustTemp(:,:,cellP)          = grid%Tdust(:,:,cellP)

         if (lgNeInput .and. lgTalk) then
            print*, '! updateCell: [talk] cell:', xP,yP,zP, " NeInput: ", &
                 &grid%NeInput(cellP), " NeUsed: ", &
                 &grid%Ne(cellP),  " N_gas: ", &
                 &grid%Hden(cellP)
         end if

      else

         if (.not.lgDust) then
            print*, '! updateCell: no gas or dust present. the grid is empty.'
            stop
         end if

         XOldHI = grid%Tdust(0,0,cellP)

         call getDustT()

         ! determine if the model has converged at this cell
         ! NOT  variable names refer to gas phase for reasons of laziness
         deltaXHI = (grid%Tdust(0,0,cellP) - XOldHI) / XOldHI
         if ( abs(deltaXHI) <= XHILimit ) then
            grid%lgConverged(cellP) = 1
         else
            grid%lgConverged(cellP) = 0
         end if

         if (lgTalk) &
              & print*, "updateCell: [talk] cell", xP,yP,zP, "; converged?",&
              & grid%lgConverged(cellP), "; mean dust T: ", &
              & grid%Tdust(0,0,cellP), "; &
              & mean dust T old: ", XOldHI,"; dT(dust): ", deltaXHI

         ! this was added to help implementing MPI comunication
         TdustTemp(:,:,cellP)          = grid%Tdust(:,:,cellP)

      end if

    contains

!        recursive subroutine iterateT()
!            implicit none

!            ! local variables
!            integer                       :: isp, ai         ! counters
!            integer                       :: ispbig          ! counter

!            logical                       :: lgGCBConv       ! grain charge converged?
!            logical                       :: lgIBConv        ! converged?

!            real                          :: coolInt         ! tot cooling integral [erg/s/Hden]
!            real                          :: heatInt         ! tot heating integral [erg/s/Hden]

!            real, parameter               :: Xmax = 0.9999   ! max rel abundance

!            ! step up T-iteration
!            nIterateT = nIterateT + 1

!            ! calculate the recombination coefficients for this cell
!            call calcalpha()

!            ! initialize X iteration counter
!            nIterateX = 1

!            ! calculate the ion abundances for the remaning ions
!            call ionBalance(lgIBConv)

!            ! calculate dust-gas interaction heating/cooling terms
!            if (lgDust .and. lgGas .and. lgPhotoelectric) then
!               do isp = 1, nSpeciesPart(nspU)
!                  do ai = 1, nsizes
!                  
!                     if (grainRadius(ai) >= componentMinRadius(nspU, isp) .and. grainRadius(ai) <= componentMaxRadius(nspU, isp)) then
!                     
!                        nIterateGC     = 0
!                        grainEmi       = 0.
!                        grainRec       = 0.                     

!                        ispbig = isp+dustComPoint(nspU)-1
!                        call setGrainPotential(ispbig,ai,lgGCBConv)
!                        call locate(nuArray, grainPot(isp,ai), grainPotP(isp,ai))
!                        if (grainPotP(isp,ai) == 0) grainPotP = 1
!                        
!                     endif

!                  end do
!               end do
!               
!               call setPhotoelHeatCool()

!               call setDustGasCollHeatCool()

!            end if


!            ! solve thermal balance
!            call thermBalance(heatInt, coolInt)

!            ! Now calculate new Te

!            ! calculate thResidual = heatInt - coolInt
!            thResidual = heatInt - coolInt
!!print*, cellp, thresidual, heatint, coolint
!            if ( abs(thResidual) >= thLimit*heatInt ) then ! start convergence condition

!                if ( nIterateT < maxIterateT ) then ! start nIterateT condition

!                    if ( thResidual < 0) then

!                        thResidualLow = thResidual
!                        Tlow          = TeUsed

!                        if ( Thigh /= 0. ) then

!                            TeUsed = Tlow-(Thigh-Tlow)*thResidualLow/&
!                                 & (thResidualHigh-thResidualLow)

!                        else

!                            TeUsed = TeUsed/1.2

!                        end if

!                    else

!                        thResidualHigh = thResidual
!                        Thigh          = TeUsed

!                        if ( Tlow /= 0. ) then

!                            TeUsed = Tlow-(Thigh-Tlow)*thResidualLow/&
!                                 & (thResidualHigh-thResidualLow)

!                        else

!                            TeUsed = TeUsed*1.2

!                        end if

!                    end if


!                    if (nIterateT >= 6) then
!                        if (abs(Thigh-Tlow) <= (0.002*(Thigh+Tlow)) ) then

!                            if ( thResidual < 0 ) then

!                                TeUsed = Thigh - 100.
!                                 Thigh  = 0.

!                            else

!                                TeUsed = Tlow+100.
!                                Tlow   = 0.

!                            end if
!                        end if
!                    end if

!                    if (TeUsed <= 20.) TeUsed = 20.

!                    ! next T-iteration
!            
!                    call iterateT()
!                    return

!                else ! if nIterateT > maxIterateT

!                    ! after maxIterateT number of iterations the temperature
!                    ! is determined as follows

!                    if ( Thigh == 0. ) then

!                        TeUsed = Tlow

!                    else

!                        if (Tlow == 0.) then

!                            TeUsed = Thigh

!                        else

!                            TeUsed = (Thigh+Tlow)*0.5

!                        end if

!                    end if


!                    if (lgTalk) print*, "! iterateT: [warning] no convergence after ", &
!                         & nIterateT, " steps. (cell, T)", cellP,xP,yP,zP,TeUsed

!                    grid%noTeBal = grid%noTeBal+1.

!                    grid%lgBlack(cellP) = 1

!                end if

!            else ! if thResidual < thLimit

!                ! the T-iteration has converged

!                if (lgTalk) print*, "! iterateT: [talk] convergence achieved after ",&
!                     & nIterateT, " steps. (cell, T)", xP,yP,zP,TeUsed, grid%abFileIndex(xP,yP,zP)

!            end if ! end convergence condition

!            if (.not.lgIBConv) then
!               grid%noIonBal = grid%noIonBal+1
!               grid%lgBlack(cellP) = 1
!            end if

!            grid%Te(cellP)         = TeUsed

!            ! determine if the model has converged at this cell
!            deltaXHI = (grid%ionDen(cellP,elementXref(1),1) - XOldHI) / XOldHI
!            if ( abs(deltaXHI) <= XHILimit ) then
!               grid%lgConverged(cellP) = 1
!            else
!               grid%lgConverged(cellP) = 0
!            end if

!            if (lgTalk) print*, "iterateT: [talk] cell", xP,yP,zP, "; converged?",&
!                 & grid%lgConverged(cellP), "; X(H0): ", &
!                 & grid%ionDen(cellP,elementXref(1),1), &
!                 & "; X(H0) old: ", XOldHI,"; dX(H0): ", deltaXHI

!            ! this was added to help implementing MPI comunication
!            TeTemp(cellP)          = TeUsed

!        end subroutine iterateT
!        
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
subroutine iterateT()
    implicit none

    !================================================================!
    ! Find equilibrium Te using secant method. Adapted from original
    ! to use DO loop instead of recursion for better readability
    !================================================================!

    !================================================================!
    ! LOCAL VARIABLES
    !================================================================!
    integer :: isp, ai              ! Dust species and size counters
    integer :: ispbig               ! Pointer for dust component
    integer :: nIterateT            ! Temperature iteration counter

    logical :: lgGCBConv            ! Grain charge balance converged?
    logical :: lgIBConv             ! Ionization balance converged?
    logical :: lgPDRcell
    logical :: lgTConverged         ! Thermal balance converged?
    logical :: lgTOk                ! D-165: this step passes every test

    real :: coolInt                 ! Total cooling rate [erg/s/Hden]
    real :: heatInt                 ! Total heating rate [erg/s/Hden]
    real :: thResidual              ! Thermal residual (Heating - Cooling)
    real :: thResidualLow           ! Residual at Tlow
    real :: thResidualHigh          ! Residual at Thigh
    real :: deltaXHI                ! Fractional change in neutral Hydrogen

    ! D-165 probe: instrument the temperature solve itself.
    integer :: nStallHit, nUsed, iBin, iTr, jTr
    integer :: iBinTe                  ! D-248: bin index for the Te statistic
    real    :: deltaTe                 ! D-248: |Te - TeIterStart| / TeIterStart
    integer :: lastSide, nRestart      ! D-165 Illinois / restart state
    real    :: brkStep, TeNext
    real    :: TeBest, resBest       ! D-165: best point seen, for the no-bracket exit
    real    :: xHInow                ! D-170
    real    :: xH2now                ! D-179
    logical :: lgCvH0, lgCvH2       ! D-179
    logical :: lgCvTe               ! D-229
    real    :: relRes, brkW, TeEntry
    real    :: teTrail(maxIterateT), resTrail(maxIterateT)

    !================================================================!
    ! INITIALIZATION
    !================================================================!
    ! Initialize flags and bracketing values for the temperature search.
    lgTConverged = .false.
    Tlow = 0.0
    Thigh = 0.0
    thResidualLow = 0.0
    thResidualHigh = 0.0
    nStallHit = 0
    nUsed     = maxIterateT
    lastSide  = 0
    nRestart  = 0
    brkStep   = 0.2
    TeBest    = TeUsed
    resBest   = huge(1.)
    TeEntry   = TeUsed
    teTrail   = 0.
    resTrail  = 0.

    ! D-072: cells the PDR owns keep the PDR's temperature. MOCASSIN's
    ! thermal balance is built for photoionised gas: its [CII] and [OI]
    ! cooling is driven by ELECTRON collisions, and in a PDR x(e-) ~ 1e-4, so
    ! those lines contribute almost nothing and the solve runs away - measured
    ! at 2691 K in a cell where 3D-PDR gives ~150 K. In neutral gas those same
    ! lines are excited by H, H2 and He, which is what 3D-PDR uses, and it also
    ! applies an escape probability where MOCASSIN treats them optically thin.
    !
    ! So the PDR owns the thermal balance in its own cells. The loop still runs
    ! ONE full pass - calcalpha, ionBalance, the grain terms and thermBalance -
    ! at the PDR temperature, so every derived quantity the Monte Carlo needs is
    ! populated consistently; only the temperature update is skipped.
    lgPDRcell = .false.
#ifdef PDR
    ! D-165. THE SWITCH NEVER REACHED HERE. pdrTeFromMocassin was written to
    ! stop the PDR handing its temperature back (pdr_mod, handBackPDR) and to
    ! make the chemistry evaluate at MOCASSIN's Te - but this short circuit, the
    ! one that decides whether MOCASSIN solves for a temperature at all, was
    ! never taught about it. So with the switch on, a PDR cell still ran ONE
    ! pass at the temperature it already had and exited flagged converged. The
    ! temperature in PDR cells was not a solution to anything; it was the last
    ! value MOCASSIN's H II-region balance produced before pdrZone flipped to 1,
    ! carried forward untouched thereafter.
    !
    ! That is the whole of D-160's "no stable fixed point": nothing was solving
    ! for the fixed point. It also explains why the answer depended on the
    ! initial condition (median Te 379 K from an ionized start, 1246 K from a
    ! neutral one) - a frozen relic of the trajectory is exactly what depends on
    ! where the trajectory began. Every measurement in the "MOCASSIN owns T"
    ! column - 0.079%, 0.099%, 0.217% converged - was made with this defect.
    ! D-193: never. MOCASSIN solves the thermal equilibrium in every cell,
    ! so no cell is pinned to a temperature the PDR computed - the PDR does
    ! not compute one. What it supplies is the molecular heating and cooling
    ! that thermBalance solves WITH.
    if (.false.) then
       if (grid%pdrZone(cellP) == 1 .and. grid%pdrTgas(cellP) > 0.) then
          lgPDRcell = .true.
          ! D-081: use grid%Te, NOT grid%pdrTgas. pdrToMocassin has already
          ! written the D-007 BLENDED temperature into grid%Te,
          !   Te = w*pdrTgas + (1-w)*Te
          ! with w ramping from 1 at x(H+) = pdrBlendLo to 0 at pdrZoneLim.
          ! Pinning to the raw pdrTgas discards that ramp and applies the pure
          ! PDR temperature right up to the zone edge, so the blend band -
          ! which exists precisely to avoid a discontinuity at the ionization
          ! front - was bypassed. Invisible in every model run before this one,
          ! because none had a single cell inside the band.
          TeUsed    = grid%Te(cellP)
       end if
    end if
#endif

    !================================================================!
    ! MAIN ITERATION LOOP
    !----------------------------------------------------------------!
    ! This loop iteratively seeks the temperature where heating equals
    ! cooling. It will run up to 'maxIterateT' times.
    !================================================================!
    DO nIterateT = 1, maxIterateT

        ! STEP 1: CALCULATE PHYSICAL STATE FOR THE CURRENT TEMPERATURE 'TeUsed'
        !----------------------------------------------------------------
        call calcalpha()
        nIterateX = 1 ! Reset ionization balance counter for this T-step
        call ionBalance(lgIBConv)


        ! STEP 2: CALCULATE DUST-RELATED HEATING AND COOLING
        !----------------------------------------------------------------
        ! This block executes only if dust physics are enabled.
        if (lgDust .and. lgGas .and. lgPhotoelectric) then
            ! Loop over all dust components and grain sizes
            do isp = 1, nSpeciesPart(nspU)
                do ai = 1, nsizes
                    if (grainRadius(ai) >= componentMinRadius(nspU, isp) .and. grainRadius(ai) <= componentMaxRadius(nspU, isp)) then
                        
                        ! Calculate the grain's electric potential (charge)
                        nIterateGC     = 0
                        grainEmi       = 0.
                        grainRec       = 0.                     

                        ispbig = isp+dustComPoint(nspU)-1
                        call setGrainPotential(ispbig,ai,lgGCBConv)
                        call locate(nuArray, grainPot(ispbig,ai), grainPotP(ispbig,ai))
                        if (grainPotP(ispbig,ai) == 0) grainPotP(ispbig,ai) = 1

                    endif
                end do
            end do
            
            ! Sum up the photoelectric and collisional heating/cooling from dust
            call setPhotoelHeatCool()
            call setDustGasCollHeatCool()
        end if


        ! STEP 3: SOLVE THERMAL BALANCE AND CHECK FOR CONVERGENCE
        !----------------------------------------------------------------
        call thermBalance(heatInt, coolInt)
        thResidual = heatInt - coolInt

        if (teProbe /= 0) then
            teTrail(nIterateT)  = TeUsed
            resTrail(nIterateT) = thResidual
        end if

        ! Convergence condition: Is the residual smaller than a fraction of the heating?
        ! D-165: with teSolver, the bracket must also be narrow relative to Te.
        ! Cloudy requires both, because where H-C is a shallow function of T -
        ! which is the PDR - the residual test passes at a temperature the
        ! solver has not actually determined, and it then returns a different
        ! one every pass. thResidual == 0 exactly is accepted regardless: the
        ! root has been found and no bracket can improve on it.
        ! D-165: the original test is against thLimit*heatInt, not
        ! thLimit*|heatInt|, so a cell with net negative heating can never pass
        ! it. Corrected under teSolver only, to keep the comparison clean.
        if (teSolver >= 1) then
           lgTOk = abs(thResidual) < thLimit * abs(heatInt)
           ! Remember the best point. Without this the strict test below can
           ! return the SECOND probe - a full 20% step away from a temperature
           ! that already passed the residual test - and inject a 20% drift per
           ! pass into exactly the cells that were fine.
           if (abs(thResidual) < resBest) then
              resBest = abs(thResidual)
              TeBest  = TeUsed
           end if
        else
           lgTOk = abs(thResidual) < thLimit * heatInt
        end if
        if (teSolver >= 2 .and. lgTOk .and. thResidual /= 0.) then
           if (Tlow > 0. .and. Thigh > 0.) then
              lgTOk = abs(Thigh - Tlow) <= (thLimit/3.)*TeUsed
           else
              ! No bracket yet: one endpoint of the interval is unknown, so
              ! the width test cannot be applied. Take one more step to try to
              ! close it; if the sign never flips within 20% of T on either
              ! side, the residual is flat and small there and the best point
              ! seen is the answer.
              lgTOk = nIterateT > 1
              if (lgTOk) TeUsed = TeBest
           end if
        end if
        if (lgTOk) then
            lgTConverged = .true.
            nUsed = nIterateT
            if (lgTalk) print*, "! iterateT: [talk] Convergence achieved after ", &
                & nIterateT, " steps. (cell, T)", xP, yP, zP, TeUsed
            exit ! Exit the loop, we found the temperature
        end if

        ! D-072: the PDR owns this cell's temperature - one pass, no update.
        if (lgPDRcell) then
            lgTConverged = .true.
            nUsed = nIterateT
            exit
        end if


        ! STEP 4: UPDATE TEMPERATURE GUESS USING SECANT METHOD
        !----------------------------------------------------------------
        ! If not converged, calculate a better temperature for the next iteration.
        ! This method uses the last two points to extrapolate to the root (thResidual = 0).

        if (teSolver >= 1) then

            ! ============================================================ D-165
            ! Cloudy-shaped search. Three changes, each with its own reason.
            !
            ! (1) ILLINOIS. Plain regula falsi keeps whichever endpoint the
            !     function does not cross, so on a convex residual one bound
            !     never moves and the bracket stops shrinking - which is what
            !     the D-165 histogram showed: |H-C|/H passing while the bracket
            !     sat at 1-100% of Te. Halving the retained endpoint's residual
            !     after a repeat forces the interval down.
            !
            ! (2) RELATIVE STALL KICK. The old breaker added +/-100 K. That is
            !     1% of an H II region and 200% of a PDR cell, and it reset the
            !     bracket, so a cell whose interval had closed was thrown back
            !     out of it. A narrow bracket with a large residual means H-C
            !     jumps discontinuously - the ionization moved with T - so the
            !     answer is to restart the search from the midpoint with a wider
            !     step, which is what Cloudy's outer n-loop does, at most twice.
            !
            ! (3) BOUNDED FALSI. If the interpolant leaves the bracket or is not
            !     finite, bisect. The old formula was applied unguarded.
            ! ==================================================================

            if (thResidual < 0.0) then
                ! Too hot: this is the new upper bound.
                if (lastSide == 2 .and. Tlow > 0.) thResidualLow = 0.5*thResidualLow
                thResidualHigh = thResidual
                Thigh    = TeUsed
                lastSide = 2
            else
                if (lastSide == 1 .and. Thigh > 0.) thResidualHigh = 0.5*thResidualHigh
                thResidualLow = thResidual
                Tlow     = TeUsed
                lastSide = 1
            end if

            if (Tlow > 0.0 .and. Thigh > 0.0) then

                ! Narrow bracket, residual still large: H-C is discontinuous
                ! here. Restart rather than kick by a fixed number of kelvin.
                if (abs(Thigh - Tlow) <= 0.002*(Thigh + Tlow) .and. nRestart < 2) then
                    nStallHit = nStallHit + 1
                    nRestart  = nRestart + 1
                    TeUsed    = 0.5*(Tlow + Thigh)
                    Tlow      = 0.0
                    Thigh     = 0.0
                    lastSide  = 0
                    brkStep   = min(0.5, 2.*brkStep)
                else
                    if (thResidualHigh /= thResidualLow) then
                        TeNext = Tlow - (Thigh - Tlow)*thResidualLow / &
                             &          (thResidualHigh - thResidualLow)
                    else
                        TeNext = 0.5*(Tlow + Thigh)
                    end if
                    if (.not. (TeNext > min(Tlow,Thigh) .and. TeNext < max(Tlow,Thigh))) &
                         & TeNext = 0.5*(Tlow + Thigh)
                    TeUsed = TeNext
                end if

            else
                ! No bracket yet. Step by a fixed FRACTION of the current
                ! temperature, exactly as Cloudy caps its step at 0.2*T, so the
                ! search rate is the same at 20 K as at 20000 K.
                if (thResidual < 0.0) then
                    TeUsed = TeUsed*(1. - brkStep)
                else
                    TeUsed = TeUsed*(1. + brkStep)
                end if
            end if

        else

        if (thResidual < 0.0) then  ! Net cooling: Current temp is too high, it becomes the new upper bound 'Thigh'
            thResidualHigh = thResidual
            Thigh = TeUsed
        else                        ! Net heating: Current temp is too low, it becomes the new lower bound 'Tlow'
            thResidualLow = thResidual
            Tlow = TeUsed
        end if

        ! Calculate the next temperature guess
        if (Tlow /= 0.0 .and. Thigh /= 0.0) then
            ! Secant method: Use both bounds to find the new temperature
            TeUsed = Tlow - (Thigh - Tlow) * thResidualLow / (thResidualHigh - thResidualLow)
        else
            ! Bracketing search: If one bound is missing, adjust by a fixed factor
            if (thResidual < 0.0) then
                TeUsed = TeUsed / 1.2 ! Too hot, cool it down
            else
                TeUsed = TeUsed * 1.2 ! Too cold, heat it up
            end if
        end if
        
        ! --- Stall Prevention Logic ---
        ! If the temperature bounds get very close but don't converge,
        ! nudge the temperature to break out of the stall.
        if (nIterateT >= 6) then
            if (abs(Thigh - Tlow) <= (0.002*(Thigh+Tlow))) then
                nStallHit = nStallHit + 1
                if (thResidual < 0.0) then
                    TeUsed = Tlow + 100. ! Nudge up from the lower bound
                    Tlow = 0.0          ! Reset the bracket
                else
                    TeUsed = Thigh - 100. ! Nudge down from the upper bound
                    Thigh = 0.0         ! Reset the bracket
                end if
            end if
        end if

        end if

        ! Ensure temperature doesn't become non-physical. D-165: teFloor was
        ! hardcoded at 10 K. Cloudy's limit is the CMB, 2.8 K, and reaching it
        ! is a reported failure rather than a silent clamp - a cell parked on
        ! the floor is not a solved cell, and 1864 of them were being counted
        ! as one at iteration 3.
        if (TeUsed < teFloor) TeUsed = teFloor
        ! Ensure temperature doesn't go beyond atomic data limit for H
        if (TeUsed > 30000.) TeUsed = 30000.
        

    END DO ! End of main iteration loop

    !================================================================!
    ! POST-PROCESSING AND FINALIZATION
    !----------------------------------------------------------------!
    ! This section executes after the loop finishes, either by
    ! converging (exit) or by reaching the maximum iteration limit.
    !================================================================!

    ! --- Handle non-converged case ---
    if (.not. lgTConverged) then
        if (lgTalk) print*, "! iterateT: [warning] No convergence after ", &
            & maxIterateT, " steps. (cell, T)", cellP, xP, yP, zP, TeUsed
        
        ! If we failed to converge, set temperature to the best available estimate
        if (Thigh == 0.0) then
            TeUsed = Tlow
        else if (Tlow == 0.0) then
            TeUsed = Thigh
        else
            TeUsed = (Thigh + Tlow) * 0.5
        end if
        
        grid%noTeBal = grid%noTeBal + 1
        grid%lgBlack(cellP) = 1 ! Flag this cell as problematic
    end if
    
    if (TeUsed >= 30000.) grid%lgBlack(cellP) = 1 ! Flag this cell as problematic

    ! ---------------------------------------------------------------- D-165
    ! What the temperature solve actually did in this cell. The question is not
    ! only "did |H-C| get small" but "is Te pinned down" - Cloudy requires both,
    ! because where H-C is a shallow function of T the residual test passes at a
    ! temperature the solver has not determined. In a PDR the thermostat IS
    ! shallow, so a solver that tests the residual alone returns a different
    ! temperature every pass and nothing downstream can converge.
    if (teProbe /= 0) then
       teN     = teN + 1
       ! D-166: relative spread of the residual across the scan.
       if (nUsed >= 3) then
          resBest = 0.; brkW = huge(1.)
          do iTr = 1, min(nUsed, maxIterateT)
             if (teTrail(iTr) <= 0.) cycle
             resBest = max(resBest, abs(resTrail(iTr)))
             brkW    = min(brkW,    abs(resTrail(iTr)))
          end do
          if (resBest > 0.) then
             if ((resBest - brkW)/resBest < 0.01) then
                teNflat = teNflat + 1
                if (TeUsed <= teFloor*1.00001 .or. TeUsed >= 29999.) &
                     & teNflatClamp = teNflatClamp + 1
             end if
          end if
       end if
       teNsteps = teNsteps + nUsed
       if (lgTConverged) teNconv = teNconv + 1
       if (nStallHit > 0) teNstall = teNstall + 1
       if (TeUsed <= teFloor*1.00001) teNloclamp = teNloclamp + 1
       if (TeUsed >= 29999.) then
          teNhiclamp = teNhiclamp + 1
          ! D-168: updateCell runs BEFORE pdrStep in every coupling pass
          ! (iteration_mod:978 against :1075), so at the iteration where the PDR
          ! first engages MOCASSIN solves the balance with no PDR coolant at
          ! all. Split the ceiling clamps by whether this cell has ever had a
          ! coolant computed for it, which separates that ordering effect from
          ! a cell that runs hot with the cooling present.
#ifdef PDR
          if (grid%pdrCoolTref(cellP) <= 0.) teNhiNoPdr = teNhiNoPdr + 1
#endif
       end if
       if (Tlow > 0. .and. Thigh > 0. .and. TeUsed > 0.) then
          brkW = abs(Thigh - Tlow)/TeUsed
          ! Cloudy's test is bracket_width/Te <= HeatCoolRelErrorAllowed/3,
          ! i.e. ~1/3 of the residual tolerance. thLimit is 0.01 here.
          if (brkW > thLimit/3.) teNwide = teNwide + 1
          iBin = min(teNbin, max(1, 7 + int(log10(max(brkW,1.e-30)))))
          teBrkHist(iBin) = teBrkHist(iBin) + 1
       else
          teNnobrack = teNnobrack + 1
       end if
       ! Per-cell trajectories for the first few cells rank 0 touches.
       if (teProbe > 1 .and. taskid == 0 .and. teN <= teProbe) then
          write(*,'(a,i8,a,i4,a,l2,a,es11.4,a,es11.4)') &
               & ' TEPROBE cell', cellP, ' steps', nUsed, ' conv', lgTConverged, &
               & ' Tin', TeEntry, ' Tout', TeUsed
          do iTr = 1, maxIterateT
             if (teTrail(iTr) <= 0.) cycle
             write(*,'(a,i3,a,es11.4,a,es11.4)') '   step', iTr, &
                  & ' Te', teTrail(iTr), ' H-C', resTrail(iTr)
          end do
       end if
    end if
    
    ! --- Update grid values and check overall model convergence ---
    grid%Te(cellP) = TeUsed
    
    if (.not. lgIBConv) then
        grid%noIonBal = grid%noIonBal + 1
        grid%lgBlack(cellP) = 1 ! Flag cell if ionization balance failed
    end if

    ! Determine if the entire cell model has converged by checking H ionization.
    ! D-155: against the value at the start of the MC ITERATION, not at entry to
    ! this call. updateCell runs pdrCoupleIter times per iteration, so comparing
    ! with XOldHI measured the inner coupling loop settling - which it always
    ! does - and reported convergence while the model was still moving 81% per
    ! iteration.
    convRef = XOldHI
    if (allocated(grid%xHIiterStart)) convRef = grid%xHIiterStart(cellP)
    if (convRef <= 0.) convRef = XOldHI
    deltaXHI = (grid%ionDen(cellP, elementXref(1), 1) - convRef) / convRef
    ! ---------------------------------------------------------------- D-179
    ! Both x(H0) AND x(H2) must have settled when the PDR is running.
    !
    ! x(H0) = 1 - x(H+) - 2 x(H2) (D-177 finding 5), so at the iteration the
    ! PDR switches on - H2 not yet formed - it still equals the converged
    ! photoionization answer and this test passed at 98% while the molecular
    ! content was only starting to move. Measured: 98.2% at iterations 4-5,
    ! then 32% at iteration 6 when H2 formed in bulk.
    !
    ! Cloudy tests molecular column densities alongside its other convergence
    ! quantities, significance-gated at colden[i]/colden[HTOT] > 1e-5, and
    ! names the species that failed (conv_itercheck.cpp). cvH2floor is that
    ! gate: below it the cell holds no molecules worth converging, and a change
    ! from 1e-30 to 1e-28 must not be allowed to block the model.
    lgCvH0 = abs(deltaXHI) <= XHILimit
    lgCvH2 = .true.
#ifdef PDR
    if (lgPDR .and. cvUseH2 /= 0 .and. allocated(grid%xH2iterStart)) then
       xH2now = 0.
       if (grid%Hden(cellP) > 0.) xH2now = grid%H2den(cellP)/grid%Hden(cellP)
       ! Gate on either end being significant, so a cell that has just formed
       ! its molecules - the interesting case - is tested rather than skipped.
       if (max(xH2now, grid%xH2iterStart(cellP)) > cvH2floor) then
          if (grid%xH2iterStart(cellP) > 0.) then
             lgCvH2 = abs(xH2now - grid%xH2iterStart(cellP)) &
                  & / grid%xH2iterStart(cellP) <= XHILimit
          else
             lgCvH2 = .false.   ! appeared from nothing this iteration
          end if
       end if
    end if
#endif
    ! ---------------------------------------------------------------- D-229
    ! And the temperature. In an H II region Te follows the ionization, so a
    ! settled x(H0) implies a settled Te and testing it bought nothing. In a
    ! PDR the molecular coolants set Te, and the two settle at different rates:
    ! D-228 reported 95.86% converged at iteration 5 - enough to stop the run
    ! on minConvergence - with the median PDR Te still to fall from 90 K to
    ! 13 K over the following four iterations (D-227).
    !
    ! Against the iteration-start value, like the other two (D-155).
    ! TeIterStart is allocated in every flavour (grid_mod, no #ifdef); a cell
    ! with no previous value is not failed for lacking one.
    lgCvTe = .true.
    if (allocated(grid%TeIterStart)) then
       if (grid%TeIterStart(cellP) > 0.) &
            & lgCvTe = abs(TeUsed - grid%TeIterStart(cellP)) &
            &          / grid%TeIterStart(cellP) <= XHILimit
    end if
    if (lgCvH0 .and. lgCvH2 .and. lgCvTe) then
        grid%lgConverged(cellP) = 1
    else
        grid%lgConverged(cellP) = 0
    end if
    if (teProbe /= 0) then
       if (.not.lgCvH0 .and.      lgCvH2) cvFailH0   = cvFailH0   + 1
       if (     lgCvH0 .and. .not.lgCvH2) cvFailH2   = cvFailH2   + 1
       if (.not.lgCvH0 .and. .not.lgCvH2) cvFailBoth = cvFailBoth + 1
       if (.not.lgCvTe)                   cvFailTe   = cvFailTe   + 1
       ! ------------------------------------------------------------- D-248
       ! The distribution of the Te test statistic, not just its verdict.
       ! Binned as cvHist bins |dx/x| so the two are read the same way.
       if (allocated(grid%TeIterStart)) then
          if (grid%TeIterStart(cellP) > 0.) then
             deltaTe = abs(TeUsed - grid%TeIterStart(cellP)) &
                  &    / grid%TeIterStart(cellP)
             iBinTe = min(12, max(1, 9 + int(log10(max(deltaTe, 1.e-30)))))
             cvTeHist(iBinTe) = cvTeHist(iBinTe) + 1
             ! A cell held at the floor cannot move, so it passes for free.
             if (TeUsed <= teFloor*1.00001) then
                cvTeFloorN = cvTeFloorN + 1
                if (lgCvTe) cvTeFloorPass = cvTeFloorPass + 1
             end if
             if (.not.lgCvTe) then
                if (deltaTe <= 2.*XHILimit) cvTeNear = cvTeNear + 1
#ifdef PDR
                if (lgPDR) then
                   if (grid%AVeff(cellP) < 0.1) then
                      cvFailTeByAV(1) = cvFailTeByAV(1) + 1
                   else if (grid%AVeff(cellP) < 0.5) then
                      cvFailTeByAV(2) = cvFailTeByAV(2) + 1
                   else if (grid%AVeff(cellP) < 1.) then
                      cvFailTeByAV(3) = cvFailTeByAV(3) + 1
                   else if (grid%AVeff(cellP) < 2.) then
                      cvFailTeByAV(4) = cvFailTeByAV(4) + 1
                   else if (grid%AVeff(cellP) < 4.) then
                      cvFailTeByAV(5) = cvFailTeByAV(5) + 1
                   else
                      cvFailTeByAV(6) = cvFailTeByAV(6) + 1
                   end if
                end if
#endif
             end if
          end if
       end if
    end if

    ! ---------------------------------------------------------------- D-170
    ! Where the failures live. Nothing here changes the test; it records the
    ! distribution so "real instability" and "criterion unreasonable in this
    ! regime" can be told apart by measurement rather than argued.
    if (teProbe /= 0) then
       cvN = cvN + 1
       ! D-173: frozen or flipping? Compare the branch this cell is on now
       ! against the branch it was on at the start of the previous iteration.
       ! Seeding a cell from a neighbour only settles anything if branches are
       ! frozen; if cells swap every iteration the neighbour is swapping too.
       if (allocated(grid%TeIterStart)) then
          if (grid%TeIterStart(cellP) > 0.) then
             if (grid%TeIterStart(cellP) >= cvTsplit) then
                if (TeUsed >= cvTsplit) then
                   cvStayHot = cvStayHot + 1
                else
                   cvHot2Cold = cvHot2Cold + 1
                end if
             else
                if (TeUsed >= cvTsplit) then
                   cvCold2Hot = cvCold2Hot + 1
                else
                   cvStayCold = cvStayCold + 1
                end if
             end if
          end if
       end if
       ! D-172: Cloudy's thermal.lgUnstable. It tests d(C-H)/dT < 0; the
       ! residual here is H-C, so the unstable sign is d(H-C)/dT > 0 - raising
       ! the temperature increases the net heating, which is a runaway rather
       ! than a thermostat. Estimated from the last two distinct evaluations of
       ! the scan, which is how Cloudy does it too (iter_track::deriv).
       jTr = 0
       do iTr = min(nUsed, maxIterateT), 2, -1
          if (teTrail(iTr) > 0. .and. teTrail(iTr-1) > 0. .and. &
               & teTrail(iTr) /= teTrail(iTr-1)) then
             jTr = iTr; exit
          end if
       end do
       if (jTr > 1) then
          cvDeriv = cvDeriv + 1
          if ((resTrail(jTr)-resTrail(jTr-1))/(teTrail(jTr)-teTrail(jTr-1)) > 0.) &
               & cvUnstable = cvUnstable + 1
       end if
       xHInow = grid%ionDen(cellP, elementXref(1), 1)
       iBin = min(12, max(1, 9 + int(log10(max(abs(deltaXHI), 1.e-30)))))
       cvHist(iBin) = cvHist(iBin) + 1
       if (abs(deltaXHI) > XHILimit) then
          cvFail = cvFail + 1
          ! How far past tolerance: just outside, or genuinely moving?
          if (abs(deltaXHI) <= 2.*XHILimit) cvNear = cvNear + 1
          if (abs(deltaXHI) > 1.0)          cvFar  = cvFar  + 1
          iBin = min(9, max(1, 9 + int(log10(max(xHInow, 1.e-30)))))
          cvFailByX(iBin) = cvFailByX(iBin) + 1
          if (xHInow < 1.e-3) cvFailSmallX = cvFailSmallX + 1
#ifdef PDR
          if (lgPDR) then
             if (grid%AVeff(cellP) < 0.1) then
                cvFailByAV(1) = cvFailByAV(1) + 1
             else if (grid%AVeff(cellP) < 0.5) then
                cvFailByAV(2) = cvFailByAV(2) + 1
             else if (grid%AVeff(cellP) < 1.) then
                cvFailByAV(3) = cvFailByAV(3) + 1
             else if (grid%AVeff(cellP) < 2.) then
                cvFailByAV(4) = cvFailByAV(4) + 1
             else if (grid%AVeff(cellP) < 4.) then
                cvFailByAV(5) = cvFailByAV(5) + 1
             else
                cvFailByAV(6) = cvFailByAV(6) + 1
             end if
          end if
#endif
       end if
       ! Cloudy's shape: a 20% tolerance, and only where the quantity is large
       ! enough to matter. x(H0) < 1e-3 of the hydrogen is the analogue of
       ! colden[i]/colden[HTOT] > 1e-5 - too little to hold up the model.
       if (abs(deltaXHI) <= 0.20 .or. xHInow < 1.e-3) &
            & cvPassGated = cvPassGated + 1
    end if

    if (lgTalk) print*, "iterateT: [talk] cell", xP, yP, zP, "; converged?", &
        & grid%lgConverged(cellP), "; X(H0): ", &
        & grid%ionDen(cellP, elementXref(1), 1)

    ! This was added to help implementing MPI communication
    TeTemp(cellP) = TeUsed
    


end subroutine iterateT
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        recursive subroutine setGrainPotential(iSp, ai, lgGCBConv)
          implicit none

          real,save            :: delta,delta1
          real,save            :: grainPotOld ! local copy of grai pot
          real                 :: grainEmi, grainRec ! grain emissions and recom
          real,save            :: grainEmiOld, grainRecOld ! grain emissions and recom
          real,parameter       :: errorLim = 0.005, dm = 0.05 ! loop convergence
          real,parameter       :: safeLim = 100 ! loop safety limit
          real                 :: threshold,fac
          real,save            :: dVg,slope

          integer, intent(in)  :: iSp, ai

          logical, intent(inout) :: lgGCBConv   ! converged?

          nIterateGC = nIterateGC+1

          if (nIterateGC==1) then
             dVg=0.05
             grainPot(isp,ai) = 0.
             grainPotOld = grainPot(isp,ai)
             lgGCBConv = .true.
             grainEmiOld = getGrainEmission(grainPot(isp,ai), isp, ai)
             grainRecOld = getGrainRecombination(grainPot(isp,ai))
             grainPot(isp,ai) = grainPotOld+0.05
          end if

          threshold = max(grainVn(isp)+grainPot(isp,ai),grainVn(isp))
          grainEmi = getGrainEmission(grainPot(isp,ai), isp, ai)
          grainRec = getGrainRecombination(grainPot(isp,ai))
          delta = grainEmi-grainRec

          delta1 = abs(delta/(0.5*max(1.e-35, grainEmi+grainRec)))


          ! check for convergence
          if (delta1<errorLim) then
             return
          else

             if (grainPot(iSp,ai) /= grainPotOld) then
                fac = (grainEmi-grainEmiOld)-(grainRec-grainRecOld)
                if (fac/=0.) slope = fac/(grainPot(iSp,ai)-grainPotOld)
             end if

             grainPotOld=grainPot(iSp,ai)
             grainRecOld = grainRec
             grainEmiOld = grainEmi

             delta1 = -delta/slope
             delta = abs(delta1)
             delta = min(delta, dm*threshold)
             delta = sign(delta, delta1)

             grainPot(iSp,ai) = grainPot(iSp,ai)+delta

             if (nIterateGC< maxIterateGC) then
                call setGrainPotential(isp,ai,lgGCBConv)
                return
             else

!                print*, '! setGrainPotential: no convergence', &
!                     & cellP,grainPot(isp,ai),grainEmi,grainRec
                lgGCBConv=.false.
                return
             end if

          end if

        end subroutine setGrainPotential

        ! calculate the grain recombination
        ! using eqn 18 etc of Baldwin et al. (1991)
        ! cellFactor is dependant on the physical conditions of the gas,
        function getGrainEmission(Vg, isp,ai)
          implicit none


          real :: getGrainEmission
          real, intent(in) :: Vg ! grain potential
          real :: Yn, Yhat

          real :: Qa ! grain absorption efficiency
          real :: thres, photFlux

          integer, intent(in) :: isp, ai
          integer :: ifreq, ip
          integer :: global_isp

          ! D-130. isp arrives ALREADY GLOBAL. updateCell resolves it as
          !   ispbig = isp + dustComPoint(nspU) - 1
          ! and passes that to setGrainPotential, which forwards the same value
          ! here. Applying dustComPoint a second time offset it twice: with two
          ! dust components (dustComPoint(2) = 2) a component-2 grain became
          ! index 3 in an array dimensioned 2, which is a segfault without
          ! bounds checking. Every other use in this function - grainVn(isp),
          ! and grainPot(isp,ai) in the caller - already treats it as global.
          global_isp = isp

          getGrainEmission=0.


          ! get the threshold
          thres = max(grainVn(isp)+Vg,grainVn(isp))

          call locate( nuArray, thres, ip)
          ip = ip+1


          do ifreq = ip, nbins


             Yn = min(Y0*(1.-grainVn(isp)/nuArray(ifreq)), Y1)

             Yhat = Yn*min(1., max(0.,1.-Vg/(nuArray(ifreq)-grainVn(isp))))

             if (.not. lgDebug) then
!                photFlux = (grid%JPEots(cellP,ifreq) + &
!                & grid%Jste(cellP,ifreq))/(hcRyd*nuArray(ifreq))
                photFlux =  grid%Jste(cellP,ifreq)/(hcRyd*nuArray(ifreq))
             else
!                photFlux = (grid%JPEots(cellP,ifreq) +&
!                &  grid%Jste(cellP,ifreq)+grid%Jdif(cellP,ifreq))/&
!                     & (hcRyd*nuArray(ifreq))
             end if

             photFlux = photFlux*fourPi

             Qa = XSecArray(dustAbsXsecP(global_isp,ai)+ifreq-1)/(1.e-8*grainRadius(ai)**2)

             getGrainEmission = getGrainEmission+Yhat*photFlux*Qa

          end do

        end function getGrainEmission


        ! calculate the grain recombination
        ! using eqn 23 etcof Baldwin et al. (1991)
        ! cellFactor is dependant on the physical conditions of the gas,
        function getGrainRecombination(Vg)
          implicit none

          real :: getGrainRecombination
          real, intent(in) :: Vg ! grain potential [ryd]

          real :: eta   ! Coulomb correction
          real :: cpDen ! colliding particle number density [cm^-3]
          real :: eightkT_pi ! 8*k * Te/Pi [erg]
          real :: mcp   ! mass of colliding particle in [g]
          real :: kT    ! k*Te [ryd]
          real :: S     ! sticking coefficient
          real :: vmean ! colliding particle mean velocity
          real :: Z     ! colliding particle charge

          integer :: istage

          getGrainRecombination = 0.
          eta = 0.
          kT =6.336e-6*TeUsed
          eightkT_pi = (1.1045e-15)*TeUsed/Pi

          ! add e- collisions contributions

          vmean = sqrt(eightkT_pi/me)

          S  =1. ! electron sticking probability


          ! eq 24 of Baldwin et al 91
          eta = -Vg/kT

          if (eta <= 0.) then
             eta = 1.-eta
          else if (eta >0.) then
             eta = exp(-eta)
          else
             nInsaneEta = nInsaneEta + 1
             if (nInsaneEta <= maxInsaneEta) then
                print*, "! getGrainRecombination: insane eta for e-", eta
                if (nInsaneEta == maxInsaneEta) print*, &
                     & "! getGrainRecombination: further 'insane eta' warnings suppressed"
             end if
          end if

          getGrainRecombination = getGrainRecombination + &
               & NeUsed*vmean*S*eta

          ! add contribution from all other neutral and ionic species
          do elem = 1, nElements
             if (lgElementOn(elem)) then
                do istage = 2, min(elem+1,nstages)
                   ! get cpDen
                   cpDen = grid%ionDen(cellP,elementXref(elem),istage)*&
                        & grid%elemAbun(grid%abFileIndex(xP,yP,zP),elem)*&
                        & grid%Hden(cellP)
                   mcp = (aWeight(elem)*amu)
                   vmean = sqrt(eightkT_pi/mcp)

                   S = 1.
                   Z = real(istage-1)

                   eta = Z*Vg/kT

                   if (eta <= 0.) then
                      eta = 1.-eta
                   else if (eta >0.) then
                      eta = exp(-eta)
                   else
                      nInsaneEta = nInsaneEta + 1
                      if (nInsaneEta <= maxInsaneEta) then
                         print*, "! getGrainRecombination: insane eta", &
                              & eta, elem, istage
                         if (nInsaneEta == maxInsaneEta) print*, &
                              & "! getGrainRecombination: further 'insane eta' warnings suppressed"
                      end if
                   end if

                   getGrainRecombination = getGrainRecombination - &
                        & cpDen*vmean*S*eta

                end do
             end if
          end do

        end function getGrainRecombination

        ! see Baldwin et al 1991; but beware that we are resolving the size distribution.
        ! so must keep size dependance, so Qa ia really Pi a^2 Qa
        subroutine setPhotoelHeatCool()
          implicit none

          real    :: Qa, photFlux, EY, Yhat,Yn,th

          integer :: ns,na,ifreq,thP
          integer :: global_ns ! DECLARE GLOBAL INDEX

          ! calculate the cooling of dust by photoelectric emission
          !  and heating of gas
          ! Baldwin et al. 1991 eqn 25-27

          photoelHeat_d=0.
          photoelHeat_g=0.
          do ns = 1, nSpeciesPart(nspU)
             ! Calculate the correct global index for the species
             global_ns = dustComPoint(nspU) + ns - 1

             do na = 1, nSizes
             
                if (grainRadius(na) >= componentMinRadius(nspU, ns) .and. grainRadius(na) <= componentMaxRadius(nspU, ns)) then

                   if (grainPotP(global_ns,na) <= 0) then
                      print*, "! setPhotoelHeatCool irregular grain potential index", &
                           grainPotP(global_ns,na), grainPot(global_ns,na)
                      stop
                   end if

                   th = max(grainVn(global_ns)+grainPot(global_ns,na), grainVn(global_ns))
                   call locate(nuArray,th,thP)
                   if(thP<=0) thP=1

                   do ifreq = thP, nbins

                      Yn = min(Y0*(1.-grainVn(global_ns)/nuArray(ifreq)), Y1)
                      Yhat = Yn*min(1., max(0.,1.-grainPot(global_ns,na)/(nuArray(ifreq)-grainVn(global_ns))))

                      if (.not. lgDebug) then
                         photFlux = grid%Jste(cellP,ifreq)/(hcRyd*nuArray(ifreq))
                      else
                         photFlux = (grid%Jste(cellP,ifreq)+grid%Jdif(cellP,ifreq))/(hcRyd*nuArray(ifreq))
                      end if

                      photFlux = photFLux
                      Qa = XSecArray(dustAbsXsecP(global_ns,na)+ifreq-1)
                      EY = Yn*0.5* min(nuArray(ifreq)-grainVn(global_ns),&
                           & max(0., ((nuArray(ifreq)-grainVn(global_ns))**2-grainPot(global_ns,na)**2)/&
                           & (nuArray(ifreq)-grainVn(global_ns))))

                      photoelHeat_d(ns,na) = photoelHeat_d(ns,na)+Qa*photFlux*EY*hcRyd/Pi
                      photoelHeat_g = photoelHeat_g+Qa*photFlux*(EY-Yhat*grainPot(global_ns,na))*&
                           & grainAbun(nspU,ns)*grainWeight(na)

                   end do
                   
                endif
                   
             end do
          end do

          photoelHeat_g = photoelHeat_g*grid%Ndust(cellP)*hcRyd/grid%Hden(cellP)

        end subroutine setPhotoelHeatCool

        ! sets the cooling and heating rates of gas and dust due to collisions between the two phases
        ! see Baldwin et al 1991
        ! only collisions with up to the 3 times ionised case are considered here
        ! (process becomes unimportant for higher ionisation cases)
        subroutine setDustGasCollHeatCool()
          implicit none

          real :: Z , kT, eta, psi,xi,  S, IPerg
          real :: eightkT_pi ! 8*k * Te/Pi [erg]
          integer :: ss(30)
          real :: vmean, mcp ! colliding particle mean velocity and mean particle mass
          integer :: nelectrons, istage, ns, na
          integer :: global_ns ! <<-- DECLARE GLOBAL INDEX

          ! outer shell array
          ss = (/1,1,2,2,3,3,3,3,3,3,4,4,5,5,5,5,5,5,&
               &6,6,6,6,6,6,6,6,6,6,7,7/)

          gasDustColl_g = 0.
          gasDustColl_d = 0.

          kT =6.336e-6*TeUsed ! ryd
          eightkT_pi = (1.1045e-15)*TeUsed/Pi


          do elem = 1, nElements ! 0 for electrons
             if ( lgElementOn(elem)) then

                   do istage = 1, min(nstages,elem+1)
                      Z = real(istage-1)

                      mcp = aWeight(elem)*amu
                      vmean = sqrt(eightkT_pi/mcp)

                      ! number of e-'s of the ionisation stage above
                      nelectrons = elem-istage+1

                      if (istage>1) then
                         if (elem == 1) then
                            IPerg = nuArray(HlevNuP(1))*ryd2erg
                         else if (elem == 2 .and. istage == 2) then
                            IPerg = nuArray(HeIlevNuP(1))*ryd2erg
                         else if (elem == 2 .and. istage == 3) then
                            IPerg = nuArray(HeIIlevNuP(1))*ryd2erg
                         else
                            IPerg = nuArray(elementP(elem,istage-1,nShells(elem,istage-1),1))*ryd2erg
                         end if
                      else
                         ! D-127. IPerg is the ionization potential released when
                         ! an electron on the grain neutralises an impacting ion.
                         ! A NEUTRAL atom carries no such energy, so the term is
                         ! zero - but it was never assigned in that case while
                         ! still being read by the accumulation below, and
                         ! elem=1/istage=1 is the first iteration of every call.
                         ! The stack slot therefore supplied it, and its contents
                         ! reached the dust temperature: measured values of
                         ! gasDustColl_d spanning 2.3e-06 to 1.3e6 erg/s per
                         ! grain against a hand evaluation of ~1e-13, clamping
                         ! T_dust to 3000 K and hard-stopping ~8% of runs in
                         ! pathSegment as "all grains have sublimed".
                         IPerg = 0.
                      end if

                      do ns = 1, nSpeciesPart(nspU)
                      
                         ! <<-- CALCULATE THE GLOBAL INDEX
                         global_ns = dustComPoint(nspU) + ns - 1
                      
                         if (istage == 1) then
                            ! D-129. Energy accommodation for a neutral atom
                            ! striking the grain: the classical elastic-collision
                            ! transfer fraction 2mM/(m+M)^2, defined at the end
                            ! of appendix A.10 of Baldwin, Ferland & Martin.
                            ! It is dimensionless and scale-invariant, so it is
                            ! only correct when BOTH masses are in the same
                            ! units. It was written with mcp in grams
                            ! (aWeight*amu ~ 1.7e-24) against MsurfAtom in amu
                            ! (~20, as the .nk headers and the declaration in
                            ! common_mod both say), which returned ~1.7e-25
                            ! instead of ~0.09 and so deleted the neutral-atom
                            ! collisional channel outright.
                            !
                            ! mcp itself is right as it stands - vmean above
                            ! needs a mass in grams - so the units are fixed
                            ! here rather than there. Cloudy computes the same
                            ! quantity from two amu masses (grains_mie.cpp:1154).
                            S = 2.*aWeight(elem)*MsurfAtom(global_ns)/&
                                 & (aWeight(elem)+MsurfAtom(global_ns))**2
                         else
                            S = 1.
                         end if
                         
                         do na = 1, nSizes
                         
                            if (grainRadius(na) >= componentMinRadius(nspU, ns) .and. grainRadius(na) <= componentMaxRadius(nspU, ns)) then

                               psi = Z*grainPot(global_ns,na)/kT
                               if (psi <= 0. ) then
                                  eta = 1.-psi
                                  xi = 1. - psi/2.
                               else
                                  eta = exp(-psi)
                                  xi = (1.+psi/2.) * eta
                               end if

                               gasDustColl_d(ns,na) = gasDustColl_d(ns,na)+&
                                    & ionDenUsed(elementXref(elem),istage)*&
                                    & grid%elemAbun(grid%abFileIndex(xP,yP,zP),elem)*&
                                    & grid%Hden(cellP)*&
                                    & Pi*grainRadius(na)*grainRadius(na)*1.e-8*&
                                    & S*vmean*(2.*kT*Ryd2erg*xi-eta*&
                                    & (Z*grainPot(global_ns,na)*Ryd2erg-IPerg+&
                                    & 2.*kBoltzmann*grid%Tdust(ns,na,cellP)))

                               gasDustColl_g = gasDustColl_g + &
                                    & ionDenUsed(elementXref(elem),istage)*&
                                    & grainWeight(na)*grainAbun(nspU,ns)*grid%Ndust(cellP)*&
                                    & grid%elemAbun(grid%abFileIndex(xP,yP,zP),elem)*&
                                    & Pi*grainRadius(na)*grainRadius(na)*1.e-8*&
                                    & S*vmean*(2.*kT*Ryd2erg*xi-eta*2.*kBoltzmann*&
                                    & grid%Tdust(ns,na,cellP))
                                    
                            endif
                            
                         end do
                         
                      end do
                   end do
                end if
             end do

             ! add contribution of e- collisions
             vmean = sqrt(eightkT_pi/me)
             do ns = 1, nSpeciesPart(nspU)
                global_ns = dustComPoint(nspU) + ns - 1
                S = 1.
                Z=-1.
                do na = 1, nSizes
                
                   if (grainRadius(na) >= componentMinRadius(nspU, ns) .and. grainRadius(na) <= componentMaxRadius(nspU, ns)) then

                      psi = Z*grainPot(global_ns,na)/kT
                      if (psi <= 0. ) then
                         eta = 1.-psi
                         xi = 1. - psi/2.
                      else
                         eta = exp(-psi)
                         xi = (1.+psi/2.) * eta
                      end if

                      gasDustColl_d(ns,na) = gasDustColl_d(ns,na)+&
                           & NeUsed* &
                           & Pi*grainRadius(na)*grainRadius(na)*1.e-8*&
                           & S*vmean*(2.*kT*Ryd2erg*xi-eta*&
                           & (Z*grainPot(global_ns,na)*ryd2erg))

                      gasDustColl_g = gasDustColl_g + &
                           & NeUsed* &
                           & grainWeight(na)*grainAbun(nspU, ns)*grid%Ndust(cellP)*&
                           & Pi*grainRadius(na)*grainRadius(na)*1.e-8*&
                           & S*vmean*(2.*kT*Ryd2erg*xi)/&
                           & grid%Hden(cellP)
                      
                   endif
                   
                end do
             end do

             ! factor of fourpi to make up for the lack of fourpi
             ! in the balance eqns for J
             gasDustColl_d(:,:)= gasDustColl_d(:,:)/fourpi
             gasDustColl_g= gasDustColl_g/fourpi

           end subroutine setDustGasCollHeatCool


        subroutine thermBalance(heatInt, coolInt)
            implicit none

            real, intent(out)      :: heatInt, &    ! total heating and
                 & coolInt       ! cooling integrals
            ! local variables

            integer                :: i,j,k         ! counters
            integer                :: elem, ion     ! counters

            real                   :: betaFF        ! energy loss coeff due to ff rad
            real                   :: betaRec       ! energy loss coeff due to recomb
            real                   :: ch12, ch13, & ! collision excitation of
                 & ex12, ex13,&                     ! hydrogen data
                 & th12, th13                       ! (Mathis, Ly alpha, beta)
            real                   :: coolFF        ! cool due to FF radiation [erg/s/Hden]
            real                   :: heatPreP, coolPreP  ! D-207: before the PDR block
            real                   :: budL(10)             ! D-217: this call's budget
            real                   :: heatElL(nElements)   ! D-285: heatSte by element
            real                   :: heatH0win, heatH0hi  ! D-221: H0 heating by band
            integer, save          :: iH2thrP = 0          ! D-221: first bin >= 15.43 eV
            real                   :: heatH0b(5)           ! D-222: H0 heating by band
            integer                :: kB                   ! D-222
            real                   :: coolSubL             ! D-210: MOCASSIN cooling removed
            integer                :: nNullL               ! D-210: coolants the guard kept
            real                   :: coolColl      ! cool due to coll excit   [erg/s/Hden]
            real                   :: coolRec       ! cool due to recombination[erg/s/Hden]
            real                   :: fcool
            real                   :: pdrCoolMol    ! D-131: molecular coolants only
            real                   :: pdrTfac       ! D-166: C(T)/C(Tref)
            real                   :: mocCool       ! D-167: MOCASSIN's term for this ion
            real                   :: hMaxV         ! D-168: largest per-ion heating
            integer                :: hMaxE, hMaxI  ! D-168: and which ion it was
            integer                :: iH1nuP        ! D-168: H0's own threshold bin
            integer                :: iCool, iLevJ, iLevK
            real                   :: heatIonSte    ! heat due to this ion stellar phot
            real                   :: heatIonDif    ! heat due to this ion diffuse phot
            real                   :: heatSte       ! tot heat gain due to stellar phot
            real                   :: heatDif       ! tot heat gain due to diffuse phot
            real                   :: log10Te       ! log10(Te)
            real                   :: log10TeScaled ! log10(Te/Z^2)
            real                   :: Np            ! proton density
            real                   :: Te4           ! Te/10000.


            ! find log10Te and Te4 at this cell
            log10Te = log10(TeUsed)
            Te4     = TeUsed / 1.e4

            ! open ff, rec beta files for H+ and He2+ (Hummer, MNRAS 268(1994) 109, Table 1.

            ! find the N(H+)
            Np = grid%ionDen(cellP,elementXref(1),2)*grid%elemAbun(grid%abFileIndex(xP,yP,zP),1)

            ! cooling of gas due to FF radiation from H+
            ! fits to Hummer, MNRAS 268(1994) 109, Table 1. or  least square fitting to m=4

            betaFF = 1.0108464E-11 + 9.7930778E-13*log10Te - &
                 & 6.6433144E-13*log10Te*log10Te + 2.4793747E-13*log10Te*log10Te*log10Te -&
                 & 2.3938215E-14*log10Te*log10Te*log10Te*log10Te

            coolFF = Np*NeUsed*betaFF*kBoltzmann*TeUsed/sqrt(TeUsed)

            if (lgTraceHeating.and.taskid==0) then
               write(57,*) 'Cell: ', xp,yp,zp
               write(57,*) 'FF H+: ', coolFF
            end if

            ! cooling of gas due to recombination of H+
            ! fits to Hummer, MNRAS 268(1994) 109, Table 1.
            ! least square fitting to m=4
            betaRec = 9.4255985E-11 -4.04794384E-12*log10Te &
                 & -1.0055237E-11*log10Te*log10Te +  1.99266862E-12*log10Te*log10Te*log10Te&
                 & -1.06681387E-13*log10Te*log10Te*log10Te*log10Te

            coolRec = Np*NeUsed*betaRec*kBoltzmann*TeUsed/sqrt(TeUsed)

            if (lgTraceHeating.and.taskid==0) then
               if (nIterateT > 1) then
                  do i = 1, 12
                     backspace 57
                  end do
               end if

               write(57,*) 'Rec H+: ', coolrec
            end if

            ! cooling of gas due to FF radiation from He++
            ! fits to Hummer, MNRAS 268(1994) 109, Table 1. least square fitting to m=4 and
            ! scaled to Z=2

            ! find N(He++)
            Np =  grid%ionDen(cellP,elementXref(2),3)*grid%elemAbun(grid%abFileIndex(xP, yP,zP),2)

            log10TeScaled = log10(TeUsed/4.)

            betaFF = 2.*(1.0108464E-11 + 9.7930778E-13*log10TeScaled - &
                 & 6.6433144E-13*log10TeScaled*log10TeScaled + &
                 & 2.4793747E-13*log10TeScaled*log10TeScaled*log10TeScaled -&
                 & 2.3938215E-14*log10TeScaled*log10TeScaled*log10TeScaled*log10TeScaled)


            coolFF = coolFF + Np*NeUsed*betaFF*kBoltzmann*TeUsed/sqrt(TeUsed/4.)

            if (lgTraceHeating.and.taskid==0) then
               write(57,*) 'FF He++: ',Np*NeUsed*betaFF*kBoltzmann*TeUsed/sqrt(TeUsed/4.)
            end if


            ! cooling of gas due to recombination of He++
            ! fits to Hummer, MNRAS 268(1994) 109, Table 1.  least square fitting to m=4
            ! and scaled to Z=2
            betaRec = 2.*(9.4255985E-11 -4.04794384E-12*log10TeScaled &
                 & -1.0055237E-11*log10TeScaled*log10TeScaled  &
                 & +1.99266862E-12*log10TeScaled*log10TeScaled*log10TeScaled&
                 & -1.06681387E-13*log10TeScaled*log10TeScaled*log10TeScaled*log10TeScaled)

            coolRec = coolRec + Np*NeUsed*betaRec*kBoltzmann*TeUsed/sqrt(TeUsed/4.)

            if (lgTraceHeating.and.taskid==0) then
               write(57,*) 'Rec He++: ',Np*NeUsed*betaRec*kBoltzmann*TeUsed/sqrt(TeUsed/4.)
            end if

            ! cooling of gas due to FF radiation from He+
            ! fits to Hummer and Storey, MNRAS 297(1998) 1073, Table 6. least square fitting to m=4

            ! find N(He+)
            Np =  grid%ionDen(cellP,elementXref(2),2)*grid%elemAbun(grid%abFileIndex(xp, yP, zP),2)

            betaFF =  1.070073e-11    -2.5730207e-13*log10Te + &
                 & 2.109134e-13*log10Te*log10Te

            coolFF = coolFF + Np*NeUsed*betaFF*kBoltzmann*TeUsed/sqrt(TeUsed)

            if (lgTraceHeating.and.taskid==0) then
               write(57,*) 'FF He+: ',Np*NeUsed*betaFF*kBoltzmann*TeUsed/sqrt(TeUsed)
            end if


            ! cooling of gas due to recombination of He+
            ! fits to Hummer and Storey, MNRAS 297(1998) 1073, Table 6. least square fitting to m=4
            betaRec =    9.4255985E-11 -4.04794384E-12*log10Te &
                 & -1.0055237E-11*log10Te*log10Te  &
                 & +1.99266862E-12*log10Te*log10Te*log10Te &
                 & -1.06681387E-13*log10Te*log10Te*log10Te*log10Te

            coolRec = coolRec + Np*NeUsed*betaRec*kBoltzmann*TeUsed/sqrt(TeUsed)

            if (lgTraceHeating.and.taskid==0) then
               write(57,*) 'Rec He+: ',Np*NeUsed*betaRec*kBoltzmann*TeUsed/sqrt(TeUsed)
            end if

            ! collisional excitation of Hydrogen
            ! Mathis, Ly alpha, beta
            ch12 = 2.47e-8
            ch13 = 1.32e-8
            ex12 = -0.228
            ex13 = -0.460
            th12 = 118338.
            th13 = 140252.

            if (TeUsed > 5000.) then

                coolColl = (ch12*exp(-th12/TeUsed)*Te4**ex12 + &
                     & ch13*exp(-th13/TeUsed)*Te4**ex13) * &
                     & hcRyd*grid%ionDen(cellP,elementXref(1),1)*NeUsed

             else

                coolColl = 0.

             end if

            if (lgTraceHeating.and.taskid==0) then
               write(57,*) 'Coll exc H: ',coolColl
               fcool = 0.
            end if


             ! collisional excitation of Heavies

             ! get the emissivities of the forb lines
             call forLines()

             ! sum all contributions from the heavies to coolColl
             do elem = 3, nElements
                do ion = 1, min(elem+1, nstages)
                   do j = 1, 10
                      do k = 1, 10
                         coolColl = coolColl + real(forbiddenLines(elem,ion,j,k))
                         if (lgTraceHeating.and.taskid==0) then
                            fcool = fcool + real(forbiddenLines(elem,ion,j,k))
                         end if
                      end do
                   end do
                end do
             end do

            if (lgTraceHeating.and.taskid==0) then
               write(57,*) 'CELs cool: ',fcool
               fcool = 0.
            end if

             ! heating due to photoionization

             ! re-initialize heatSte and heatDif
             heatSte = 0.
             heatElL = 0.                                    ! D-285
             hMaxV = 0.; hMaxE = 0; hMaxI = 0; iH1nuP = 0    ! D-168
             ! D-221: H0 photoionization heating split where H2's continuum
             ! starts, 15.43 eV = 1.1345 Ryd (addOpacity). The energy grid is
             ! fixed for the run, so the split bin is found once.
             heatH0win = 0.; heatH0hi = 0.
             heatH0b = 0.                                   ! D-222
             call setHardBands()
             if (iH2thrP == 0) then
                iH2thrP = nbins + 1
                do j = 1, nbins
                   if (nuArray(j) >= 1.1345) then
                      iH2thrP = j
                      exit
                   end if
                end do
             end if
             if (lgDebug) heatDif = 0.

             do elem = 1, nElements  ! begin element loop
                 do ion = 1, min(elem, nStages-1) ! begin ion loop
                     if(.not.lgElementOn(elem)) exit

                     if (elem > 2) then

                         ! find the number of electrons in this ion
                         nElec = elem - ion + 1

                         ! find the outer shell number and statistical weights
                         call getOuterShell(elem, nELec, outShell, g0, g1)

                         ! get pointer to this ion's IP in NuArray
                         IPnuP = elementP(elem, ion, outShell, 1)

                         ! get pointer to this cell's highest energy
                         highNuP = elementP(elem, ion, outShell, 2)

                     else if (elem == 1) then ! HI

                         IPNuP   = HlevNuP(1)
                         highNuP = nbins

                     else if ( (elem == 2) .and. (ion == 1) ) then ! HeI

                         IPNuP   = HeIlevNuP(1)
                         highNuP = nbins

                     else if ( (elem == 2) .and. (ion == 2) ) then ! HeII

                         IPNuP   = HeIIlevNuP(1)
                         highNuP = nbins

                     end if

                     ! re-initialize heatIonSte and heatIonDif
                     heatIonSte = 0.
                     if (lgDebug) heatIonDif = 0.
                     do j = IPnuP, highNuP ! begin frequency loop
                             if ( elem > 2 ) then

                                 ! get pointer to phot xSec of this ion in xSecArray
                                 xSecP = elementP(elem, ion, outShell, 3)

                                 ! get phot xSec of ion at this energy
                                 phXSec = xSecArray(j+xSecP-IPnuP+1-1)

                             else if ( elem == 1 ) then ! HI

                                 phXSec  = xSecArray(j-IPnuP+1+HlevXSecP(1)-1)

                             else if ( (elem == 2) .and. (ion == 1) ) then ! HeI


                                 phXSec  = xSecArray(j-IPnuP+1+HeISingXSecP(1)-1)


                             else if ( (elem == 2) .and. (ion == 2) ) then ! HeII

                                 phXSec  = xSecArray(j-IPnuP+1+HeIIXSecP(1)-1)

                             end if

                             if ((phXSec < 1.e-35) ) then
                                 exit
                             end if

                             if ((nuArray(j) < 1.e-35) ) then
                                 print*, "! thermBalance: insane nu value (j, nuArray(j)", &
                                      & j, nuArray(j)
                                 stop
                             end if

                             ! stellar photoionizations
                             if ( grid%Jste(cellP,j) > 0. )then

                                heatIonSte = heatIonSte + phXSec*grid%Jste(cellP,j)*&
                                     & (nuArray(j)-nuArray(IPNuP)) / (nuArray(j))
                                ! D-221: the same term, for H0 only, by band
                                if (elem == 1 .and. ion == 1) then
                                   if (j < iH2thrP) then
                                      heatH0win = heatH0win + phXSec*grid%Jste(cellP,j)* &
                                           & (nuArray(j)-nuArray(IPNuP)) / (nuArray(j))
                                   else
                                      heatH0hi  = heatH0hi  + phXSec*grid%Jste(cellP,j)* &
                                           & (nuArray(j)-nuArray(IPNuP)) / (nuArray(j))
                                   end if
                                   do kB = 1, 5                           ! D-222
                                      if (j >= bandP(kB) .and. j < bandP(kB+1)) then
                                         heatH0b(kB) = heatH0b(kB) + phXSec*grid%Jste(cellP,j)* &
                                              & (nuArray(j)-nuArray(IPNuP)) / (nuArray(j))
                                         exit
                                      end if
                                   end do
                                end if

                             end if

                             ! diffuse photoionizations

                             if (lgDebug) then
                                if ( grid%Jdif(cellP,j) > 0. ) then

                                   heatIonDif = heatIonDif + phXSec*grid%JDif(cellP,j)* &
                                        & (nuArray(j)-nuArray(IPNuP)) / (nuArray(j))

                                end if
                             end if

                    end do ! end frequency loop

                    ! get total heat gain from stellar and diffuse photoionizations

                    heatIonSte = heatIonSte*ionDenUsed(elementXref(elem),ion)*&
                         & grid%elemAbun(grid%abFileIndex(xP,yP,zP),elem)
                    if (elem == 1 .and. ion == 1) then            ! D-221: same scaling
                       heatH0win = heatH0win*ionDenUsed(elementXref(1),1)* &
                            & grid%elemAbun(grid%abFileIndex(xP,yP,zP),1)
                       heatH0hi  = heatH0hi *ionDenUsed(elementXref(1),1)* &
                            & grid%elemAbun(grid%abFileIndex(xP,yP,zP),1)
                       heatH0b   = heatH0b  *ionDenUsed(elementXref(1),1)* &
                            & grid%elemAbun(grid%abFileIndex(xP,yP,zP),1)     ! D-222
                    end if
                    if (lgDebug) &
                         & heatIonDif = heatIonDif*ionDenUsed(elementXref(elem),ion)*&
                         &grid%elemAbun(grid%abFileIndex(xP,yP,zP),elem)

                    heatSte    = heatSte + heatIonSte
                    ! D-285: the same sum, kept per element, so a per-depth
                    ! comparison can say which absorber the heating is on.
                    if (elem >= 1 .and. elem <= nElements) &
                         & heatElL(elem) = heatElL(elem) + heatIonSte
                    ! D-168: hydrogen's OWN threshold index, saved. IPnuP is a
                    ! loop variable and by the time the budget prints it holds
                    ! whichever ion came last - reading it there was a mislabelled
                    ! probe, and the "no ionizing flux" it appeared to show was an
                    ! artifact of that.
                    if (elem == 1 .and. ion == 1) iH1nuP = IPnuP
                    ! D-168: which ion is depositing it. The hot cells' balance
                    ! is heatSte against everything else by a factor 1500, so
                    ! the single largest contributor is the whole question.
                    if (heatIonSte > hMaxV) then
                       hMaxV = heatIonSte; hMaxE = elem; hMaxI = ion
                    end if
#ifdef PDR
                    ! D-138: which ion is depositing the heat in a deep PDR
                    ! cell, and from which part of the spectrum. Three
                    ! hypotheses about this balance had been wrong from
                    ! inference; name the contributor before adding opacity.
                    if (nIonProbe < 20000 .and. heatIonSte > 0. .and. elem == 1 .and. &
                         & grid%pdrZone(cellP) == 1 .and. grid%AVeff(cellP) > 1.0 &
                         & .and. nIterateMC >= 6 .and. taskid == 0) then
                       nIonProbe = nIonProbe + 1
                       ! D-158: Jdif now carries the diffuse part alone while
                       ! Jste carries both, so the difference is the genuinely
                       ! stellar contribution. That decides whether these
                       ! photons travelled from the star through tau = 175 per
                       ! cell, or were emitted locally.
                       if (pdrSplitField /= 0 .and. ion == 1) &
                            & print*, "! [D158] cell", cellP, &
                            & " Jste(both) =", sum(grid%Jste(cellP,IPnuP:highNuP)), &
                            & " Jdif(diffuse) =", sum(grid%Jdif(cellP,IPnuP:highNuP)), &
                            & " stellar-only =", &
                            & sum(grid%Jste(cellP,IPnuP:highNuP)) &
                            & - sum(grid%Jdif(cellP,IPnuP:highNuP)), &
                            & " heat =", heatIonSte
                       ! D-145: with lgDebug the stellar and diffuse fields are
                       ! kept apart, so this says which one is actually feeding
                       ! the heating. Without it Jste holds BOTH (photon_mod
                       ! 1592-1603), which is why every earlier probe here was
                       ! reading a total field and calling it stellar.
                       ! D-146: the heating falls with radius as if tau were
                       ! ~0.9 per cell, while the opacity array holds 9e-17
                       ! cm^-1 -> tau = 175 per cell. Read the STORED opacity
                       ! the transport actually uses, at the bin that carries
                       ! the flux, to see which of the two is real.
                       print*, "! [D146] cell", cellP, " heat =", heatIonSte, &
                            & "  stored opacity at 465 =", grid%opacity(cellP,465), &
                            & "  at IPnuP =", grid%opacity(cellP,IPnuP), &
                            & "  Jste(465) =", grid%Jste(cellP,465)
                    end if
#endif
                    if (lgDebug) &
                         & heatDIf    = heatDif + heatIonDif

                end do ! end ion loop

            end do ! end element loop

            ! calculate the total heating and cooling integrals

            if (lgDebug) then
               heatInt = heatSte + heatDIf
            else
               heatInt = heatSte
            end if

            if (lgTraceHeating.and.taskid==0) then
               write(57,*) 'Dust gas coll cool: ',gasDustColl_g
               write(57,*) 'Heat photionization: ', heatInt
               write(57,*) 'Heat photoelectric: ', photoelHeat_g
            end if

            coolInt = coolFF + coolRec + coolColl

            if (lgDust .and. lgPhotoelectric) then
               coolInt = coolInt+gasDustColl_g
               heatInt = heatInt+photoelHeat_g
            end if
#ifdef PDR
            ! D-207: the budget as MOCASSIN built it, before any substitution.
            heatPreP = heatInt
            coolPreP = coolInt
            coolSubL = 0.
            nNullL   = 0
            ! D-131. MOCASSIN carries no molecular or fine-structure coolant -
            ! no CO, C, C+ or O - which is precisely why the PDR's temperature
            ! had to be handed back instead of this balance solving for it. The
            ! chemistry already computes those rates per cell; supplying them
            ! here lets MOCASSIN own the temperature in molecular gas too.
            !
            ! grid%pdrCool is volumetric [erg/s/cm^3]; coolInt is per hydrogen
            ! nucleus, so the conversion is /Hden and nothing else.
            !
            ! D-135. This originally also divided by 4pi, reasoned from
            ! gasDustColl_g a few lines above - which does carry a 4pi, but for
            ! reasons specific to how that term is built, not as a property of
            ! coolInt. Measured instead: at T_e = 9348 K with n_H = 100,
            ! coolColl = 7.4e-23, and a standard H II cooling rate of ~1e-20
            ! erg/cm^3/s is 1e-22 per H nucleus - the same order. The 4pi made
            ! every handed-over term 12.6x too small, which is why swapping the
            ! coolants and then the photoelectric heating each moved the deep
            ! PDR by about 1 K.
            ! D-198: unconditional. MOCASSIN owns the thermal equilibrium
            ! (D-193), and it cannot own it honestly while the molecular
            ! coolants and the six heating terms it has no expression for are
            ! behind a keyword that defaults to off. The two halves are one
            ! decision: taking the temperature from the PDR and then solving
            ! it here without the PDR's budget leaves neutral gas with no
            ! coolant that lacks a factor n_e, so H-C has no root and the
            ! search runs to a rail - D-166 measured 45% of the model pinned
            ! at 30000 K or 10 K.
            if (lgPDR) then
               if (grid%Hden(cellP) > 0.) then
                  ! Only the coolants MOCASSIN has no line data for. C, C+, O
                  ! and O+ are already summed into coolColl above from ci.dat,
                  ! cii.dat, oi.dat and oii.dat, so handing 3D-PDR's values for
                  ! them across would double count three of the four standard
                  ! coolants. pdrCoolIsMol is decided once in initPDRnetwork.
                  pdrCoolMol = 0.
                  do iCool = 1, pdrNcool
                     if (pdrCoolIsMol(iCool)) then
                        ! MOCASSIN has no line data for this carrier at all.
                        pdrCoolMol = pdrCoolMol + pdrCoolAt(grid,cellP,iCool,TeUsed)
                     else if (pdrCoolElem(iCool) > 0 .and. &
                          &   (pdrCoolZoneGate == 0 .or. &
                          &    grid%pdrZone(cellP) == 1)) then
                        ! D-133: an ATOMIC coolant inside the PDR. MOCASSIN has
                        ! these lines but excites them with electrons alone,
                        ! while 3D-PDR carries H, H+, He and H2 as well - and in
                        ! neutral gas the electron fraction is ~1e-4, so
                        ! MOCASSIN's version under-cools by orders of magnitude.
                        ! Measured: leaving MOCASSIN to own [C II] and [O I] put
                        ! the deep PDR at 157 K where 3D-PDR's own balance, at
                        ! that same temperature, said cooling exceeded heating
                        ! 3.2 to 1.
                        !
                        ! So REPLACE rather than exclude: take MOCASSIN's
                        ! contribution for this ion back out of coolColl and use
                        ! 3D-PDR's in its place. Outside the PDR the electron
                        ! treatment is the right one and MOCASSIN keeps the term.
                        !
                        ! D-167: ONLY if there is something to replace it with.
                        ! pdr_mod zeroes pdrCoolSp for any coolant whose carrier
                        ! has fallen below pdrNspecFloor - and in a hot cell the
                        ! carbon is ionized past C+, so [C I] and [C II] are
                        ! exactly the coolants that vanish. Subtracting
                        ! MOCASSIN's term and adding zero deletes the cooling
                        ! outright, which makes the cell hotter, which ionizes
                        ! more carbon. A self-reinforcing runaway, and the
                        ! reason 20261 cells sat on the 30000 K ceiling with a
                        ! residual that did not respond to temperature.
                        mocCool = 0.
                        do iLevJ = 1, 10
                           do iLevK = 1, 10
                              mocCool = mocCool + &
                                   & real(forbiddenLines(pdrCoolElem(iCool), &
                                   &                     pdrCoolIon(iCool), iLevJ, iLevK))
                           end do
                        end do
                        ! D-215: the guard and the value are both taken at
                        ! the temperature the solver is trying, not at the
                        ! chemistry's Tg. Under the D-166 power law the guard
                        ! tested pdrCoolSp - a fixed number - while the value
                        ! that entered the budget was that number times an
                        ! extrapolation, so the two could disagree about
                        ! whether there was anything to substitute.
                        if (pdrCoolAt(grid,cellP,iCool,TeUsed) > 0.d0) then
                           coolInt = coolInt - mocCool
                           coolSubL = coolSubL + mocCool          ! D-210
                           pdrCoolMol = pdrCoolMol &
                                & + real(pdrCoolAt(grid,cellP,iCool,TeUsed))
                        else if (mocCool > 0.) then
                           ! Nothing to replace it with: keep MOCASSIN's.
                           nCoolNull = nCoolNull + 1
                           nNullL    = nNullL + 1                 ! D-210
                        end if
                     end if
                  end do
                  ! D-135 probe: two hypotheses about this discrepancy have now
                  ! failed, and both assumed these terms actually move coolInt.
                  ! Report the sizes once, for a deep PDR cell, before guessing
                  ! a third time.
                  ! D-137: fire LATE, on a settled deep PDR cell. Every probe
                  ! so far ran at iteration 1 on cells that had barely seen a
                  ! photon, and three hypotheses have been built on inference
                  ! from them. Print the whole budget, both sides, at the
                  ! temperature the model actually converges to.
                  if (nBalProbe < 4 .and. grid%pdrZone(cellP) == 1 .and. &
                       & grid%AVeff(cellP) > 1.0 .and. nIterateMC >= 6) then
                     nBalProbe = nBalProbe + 1
                     print*, "! [D135] cell", cellP, " Te =", TeUsed, &
                          & " Hden =", grid%Hden(cellP)
                     print*, "! [D135]   MOCASSIN coolInt so far =", coolInt, &
                          & "  heatInt =", heatInt
                     print*, "! [D135]   coolFF =", coolFF, " coolRec =", coolRec, &
                          & " coolColl =", coolColl
                     print*, "! [D135]   photoelHeat_g =", photoelHeat_g, &
                          & " gasDustColl_g =", gasDustColl_g
                     print*, "! [D135]   PDR cool volumetric =", grid%pdrCool(cellP), &
                          & " -> contributes", pdrCoolMol/grid%Hden(cellP)
                     print*, "! [D135]   PDR heatXtra =", grid%pdrHeatXtra(cellP), &
                          & " -> contributes", grid%pdrHeatXtra(cellP)/grid%Hden(cellP)
                     print*, "! [D137]   PDR totals: heat(12) =", grid%pdrHeat(cellP), &
                          & "  heat(2) PE =", grid%pdrHeatPE(cellP), &
                          & "  heatGG =", grid%pdrHeatGG(cellP)
                     print*, "! [D137]   heat(4)+heat(11) =", &
                          & grid%pdrHeat(cellP)-grid%pdrHeatPE(cellP)-grid%pdrHeatXtra(cellP)
                     print*, "! [D137]   MOCASSIN PE per-H =", photoelHeat_g, &
                          & "  PDR PE per-H =", grid%pdrHeatPE(cellP)/grid%Hden(cellP), &
                          & "  ratio =", photoelHeat_g/ &
                          & max(grid%pdrHeatPE(cellP)/grid%Hden(cellP),1.e-30)
                     print*, "! [D137]   Tdust =", grid%Tdust(0,0,cellP), &
                          & "  AVeff =", grid%AVeff(cellP), "  chi =", grid%chiFUV(cellP)
                  end if
                  ! D-166. Evaluate the coolant at the temperature the solver
                  ! is currently trying, not at the one the chemistry last used.
                  ! Without this pdrCoolMol is a constant inside iterateT, and
                  ! in neutral gas it is the ONLY coolant that matters - every
                  ! term MOCASSIN computes for itself carries a factor n_e,
                  ! which is ~1e-4 there. H-C then has no temperature
                  ! dependence, there is no root, and the search can only run to
                  ! a rail: measured at iteration 4, 20261 cells pinned at
                  ! 30000 K and 13968 at 10 K, 45% of the model.
                  !
                  ! C(T) = C(Tref) * (T/Tref)^p, with p measured from a second
                  ! coolant evaluation each coupling pass. Cloudy re-solves the
                  ! whole cooling function at every trial temperature; this is
                  ! the two-point version, and the power law is clamped because
                  ! extrapolating a fine-structure exponential over three
                  ! decades of T is not defensible.
                  ! D-215: no factor. pdrCoolMol was accumulated above from
                  ! pdrCoolAt at TeUsed, which interpolates the tabulated
                  ! cooling function and clamps at its ends. The power law,
                  ! its [-2,12] slope clamp and its [1e-8,1e8] factor clamp
                  ! are all gone.
                  !
                  ! pdrTfacUsed now records what the substitution actually
                  ! scaled by relative to the coolant at Tg - the same number
                  ! the [D213] line reported, so the two runs stay
                  ! comparable. Under D-166 it reached x420; if the table is
                  ! doing its job it should now stay within the range the
                  ! cooling function itself spans between grid points.
                  if (allocated(grid%pdrTfacUsed)) then
                     pdrTfac = 0.
                     do iCool = 1, pdrNcool
                        pdrTfac = pdrTfac + grid%pdrCoolSp(cellP,iCool)
                     end do
                     if (pdrTfac > 0.) then
                        grid%pdrTfacUsed(cellP) = pdrCoolMol/pdrTfac
                     else
                        grid%pdrTfacUsed(cellP) = 1.
                     end if
                  end if
                  coolInt = coolInt + pdrCoolMol/grid%Hden(cellP)
                  ! D-168 probe: the budget of a cell sitting on the 30000 K
                  ! ceiling. D-135 printed this for a DEEP cell; the cells that
                  ! do not converge are the hot ones, and nothing has yet looked
                  ! at what is on each side of their balance at the rail.
                  if (teProbe /= 0 .and. TeUsed >= 29999. .and. nHotProbe < 8 &
                       & .and. taskid == 0 .and. grid%pdrCoolTref(cellP) > 0.) then
                     nHotProbe = nHotProbe + 1
                     print*, "! [D168] cell", cellP, " zone", grid%pdrZone(cellP), &
                          & " nH", grid%Hden(cellP), " AV", grid%AVeff(cellP)
                     print*, "! [D168]   x(H+)", grid%ionDen(cellP,elementXref(1),2), &
                          & " Ne", NeUsed, " Tref", grid%pdrCoolTref(cellP), &
                          & " p", grid%pdrCoolSlope(cellP)
                     print*, "! [D168]   HEAT ste", heatSte, " PE", photoelHeat_g, &
                          & " pdrXtra", grid%pdrHeatXtra(cellP)/grid%Hden(cellP), &
                          & " total", heatInt
                     print*, "! [D168]   COOL ff", coolFF, " rec", coolRec, &
                          & " coll", coolColl, " gasDust", gasDustColl_g, &
                          & " pdrMol", pdrCoolMol/grid%Hden(cellP), " total", coolInt
                     print*, "! [D168]   top heating ion: elem", hMaxE, " stage", hMaxI, &
                          & " = ", hMaxV, " (", 100.*hMaxV/max(heatSte,1.e-30), "% of ste)"
                     ! D-169: energy deposited per photoionization, in the SAME
                     ! cell and the same call, from the two integrals that read
                     ! the same Jste and the same cross section. It is bounded:
                     ! the excess energy cannot exceed nuMax - nu0, 14 Ryd here.
                     ! Anything larger means the two integrals disagree about
                     ! the field they are both reading.
                     print*, "! [D169]   nPhotoSte(H0)", nPhotoSte(1,1), &
                          & "  heat/H0", hMaxV/max(grid%ionDen(cellP,elementXref(1),1),1.e-30), &
                          & "  eV per event", &
                          & hMaxV/max(grid%ionDen(cellP,elementXref(1),1),1.e-30) &
                          & /max(nPhotoSte(1,1),1.e-30)/1.602e-12
                     ! The field and the opacity AT HYDROGEN'S THRESHOLD, which
                     ! is where the heating is coming from. tau per cell decides
                     ! whether this flux can physically be here: with n(H0) ~ 100
                     ! and sigma ~ 6e-18 a cell should be tau ~ 1e3 at threshold.
                     if (iH1nuP > 0) then
                        print*, "! [D168]   at H0 threshold: bin", iH1nuP, &
                             & " nu", nuArray(iH1nuP), " Jste", grid%Jste(cellP,iH1nuP), &
                             & " opacity", grid%opacity(cellP,iH1nuP)
                        print*, "! [D168]   Jste above H0 thr", &
                             & sum(grid%Jste(cellP,iH1nuP:nbins)), &
                             & "  below", sum(grid%Jste(cellP,1:max(iH1nuP-1,1))), &
                             & "  chiFUV", grid%chiFUV(cellP), &
                             & "  n(H0)", grid%Hden(cellP)*grid%ionDen(cellP,elementXref(1),1)
                        ! D-158/D-168: with pdrSplitField the diffuse packets are
                        ! mirrored into Jdif while Jste carries both, so the
                        ! difference is the genuinely stellar part. tau per cell
                        ! at threshold is ~1e3, so a stellar origin for this flux
                        ! is arithmetically impossible; this says whether the
                        ! code agrees.
                        print*, "! [D168]   Jdif above H0 thr", &
                             & sum(grid%Jdif(cellP,iH1nuP:nbins)), &
                             & "  stellar-only", &
                             & sum(grid%Jste(cellP,iH1nuP:nbins)) &
                             & - sum(grid%Jdif(cellP,iH1nuP:nbins)), &
                             & "  dx", grid%xAxis(min(xP+1,size(grid%xAxis)))-grid%xAxis(xP), &
                             & "  tau/cell", grid%opacity(cellP,iH1nuP)* &
                             & (grid%xAxis(min(xP+1,size(grid%xAxis)))-grid%xAxis(xP))
                     end if
                  end if
                  ! The heating side needs the same treatment, and for the same
                  ! reason. Adding a coolant MOCASSIN lacks without the heating
                  ! it also lacks would bias molecular gas cold - cosmic-ray
                  ! heating alone is absent entirely (D-035). pdrHeatXtra is
                  ! already the PDR total minus the three terms MOCASSIN
                  ! computes for itself.
                  heatInt = heatInt + grid%pdrHeatXtra(cellP)/&
                       & grid%Hden(cellP)
                  ! D-134: optionally let the PDR own the photoelectric term
                  ! too, inside the PDR. Take MOCASSIN's out and put 3D-PDR's
                  ! in - the same replace-don't-exclude rule as the atomic
                  ! coolants, applied to the one term that dominates the budget.
                  if (pdrPEfromPDR /= 0 .and. grid%pdrZone(cellP) == 1) then
                     heatInt = heatInt - photoelHeat_g &
                          & + grid%pdrHeatPE(cellP)/grid%Hden(cellP)
                  end if
               end if
            end if
            ! D-207: what the block above actually did to the budget, per H.
            ! Recorded at whatever Te the balance last evaluated, which after
            ! the search has converged is the cell's answer.
            if (lgPDR) then
               if (allocated(grid%pdrHeatUsed)) &
                    & grid%pdrHeatUsed(cellP) = heatInt - heatPreP
               if (allocated(grid%pdrCoolUsed)) &
                    & grid%pdrCoolUsed(cellP) = coolInt - coolPreP
               ! D-210: the two halves, so `added` is recoverable as
               ! used + removed and the guard's activity is visible.
               if (allocated(grid%pdrCoolSub)) grid%pdrCoolSub(cellP) = coolSubL
               if (allocated(grid%pdrCoolNul)) grid%pdrCoolNul(cellP) = real(nNullL)
            end if
            ! D-217: MOCASSIN's own budget, term by term, mirroring exactly how
            ! heatInt and coolInt were assembled above so the terms sum to
            ! them. Slot 2 is overwritten on every call and so ends as the
            ! last evaluation; slot 1 is written once, on the first call.
            ! Like D-207's arrays, the last evaluation is at the solver's last
            ! TRIAL temperature, which need not equal the TeUsed it finally
            ! writes - term 10 records the temperature so that is visible.
            if (allocated(grid%mocBud)) then
               budL = 0.
               if (lgDebug) then
                  budL(1) = heatSte + heatDif
               else
                  budL(1) = heatSte
               end if
               if (lgDust .and. lgPhotoelectric) then
                  budL(2) = photoelHeat_g
                  budL(7) = gasDustColl_g
               end if
               if (lgPDR) then
                  budL(3) = heatInt - heatPreP
                  budL(8) = coolInt - coolPreP
               end if
               budL(4)  = coolColl
               budL(5)  = coolRec
               budL(6)  = coolFF
               budL(9)  = heatInt - coolInt
               budL(10) = TeUsed
               grid%mocBud(cellP, 2, :) = budL
               ! D-285: the same slot-2 call, element by element. budL(1) is
               ! its sum (plus heatDif under lgDebug, which this is not).
               if (allocated(grid%mocHeatEl)) grid%mocHeatEl(cellP, :) = heatElL
               if (lgBudEntry) then
                  grid%mocBud(cellP, 1, :) = budL
                  if (allocated(grid%mocBand)) then           ! D-221: entry only
                     grid%mocBand(cellP, 1) = heatH0win
                     grid%mocBand(cellP, 2) = heatH0hi
                     grid%mocBand(cellP, 3:7) = heatH0b             ! D-222
                  end if
                  lgBudEntry = .false.
               end if
            end if
#endif


        end subroutine thermBalance


        ! this subroutine is the driver for the calculation of the emissivity
        ! from the heavy elements forbidden lines.
        subroutine forLines()
          implicit none

          integer        :: elem, ion ! counters

          ! re-initialize forbiddenLines
          forbiddenLines = 0.

          do elem = 3, nElements
             do ion = 1, min(elem+1, nstages)
                if (.not.lgElementOn(elem)) exit

                if (lgDataAvailable(elem, ion)) then

                   if (elem == 26 .and. ion == 2) then
                      if (nstages > 2) then
                         call equilibrium(file_name=dataFile(elem, ion), &
                              &ionDenUp=ionDenUsed(elementXref(elem),ion+1)/&
                              &ionDenUsed(elementXref(elem),ion), Te=TeUsed,&
                              &Ne=NeUsed, FlineEm=forbiddenLinesLarge(&
                              &1:nForLevelsLarge, 1:nForLevelsLarge))
                      else
                         call equilibrium(file_name=dataFile(elem, ion), &
                              &ionDenUp=0., Te=TeUsed,&
                              &Ne=NeUsed, FlineEm=forbiddenLinesLarge(&
                              &1:nForLevelsLarge, 1:nForLevelsLarge))
                      end if
                      forbiddenLinesLarge(:, :) = forbiddenLinesLarge(:, :)*&
                           & grid%elemAbun(grid%abFileIndex(xP,yP,zP),elem)*&
                           & ionDenUsed(elementXref(elem), ion)
                   else
                      if (ion<nstages) then
                         call equilibrium(dataFile(elem, ion), &
                              &ionDenUsed(elementXref(elem), ion+1)/&
                              &ionDenUsed(elementXref(elem),ion), &
                              & TeUsed, NeUsed, forbiddenLines(elem, ion,:,:))
                      else
                         call equilibrium(dataFile(elem, ion), 0., &
                            & TeUsed, NeUsed, forbiddenLines(elem, ion,:,:))
                      end if
                      forbiddenLines(elem, ion, :, :) = forbiddenLines(elem, ion, :, :)*&
                           & grid%elemAbun(grid%abFileIndex(xP,yP,zP),elem)*&
                           & ionDenUsed(elementXref(elem), ion)
                   end if
                end if
             end do
          end do

          ! scale the forbidden lines emissivity to give units of [erg/s/Ngas]
          ! comment: the forbidden line emissivity is so far in units of cm^-1/s/Ngas
          !          the energy [erg] of unit wave number [cm^-1] is 1.9865e-16, hence
          !          the right units are obtained by multiplying by 1.9865e-16
          forbiddenLines = forbiddenLines*1.9865e-16
          if (lgElementOn(26) .and. ion>2) forbiddenLinesLarge = forbiddenLinesLarge*1.9865e-16

        end subroutine forLines

        recursive subroutine ionBalance(lgConv)
            implicit none

            logical, intent(out)   :: lgConv        ! did ion bal converge?

            ! local variables
            real                   :: collIon       ! collisional ionization of H
            real                   :: correction    ! used in lgNeInput = .t.
            real                   :: deltaHI       ! delta(X(H0))
            real                   :: deltaHeI      ! delta(X(He0))
            real                   :: deltaHeII     ! delta(X(HeII))
            real                   :: expFact       ! exponential factor
            real                   :: t4            ! TeUsed/10000.
            real, save             :: HIOld         ! X(H0) from last iteration
            real, save             :: HeIOld        ! X(He0) from last iteration
            real, save             :: HeIIOld       ! X(He+) from last iteration
            real, parameter        :: limit = 0.01  ! convergence limit

            integer                :: elem, ion     ! element and ion counters
            integer                :: g0,g1         ! stat weights
            integer                :: i             ! counter
            integer                :: nElec         ! of  e's in the ion
            integer                :: outShell      ! byproduct of proc to get stat weights


            real                   :: revRate       ! reverse charge exchange rate
            double precision       :: chainVal, diffVal   ! D-114 self-check
            real                   :: NeIn          ! D-277: Ne the rates were built with
            double precision, dimension(4) :: eShare ! D-277: e- share of H, He, C, Mg
            integer, dimension(4), parameter :: eShEl = (/1, 2, 6, 12/)
            real                   :: avProbe       ! D-277
            real, save             :: NeLoB, NeHiB  ! D-279: bracket on the n_e root
            real                   :: deltaNe       ! D-279: (NeOut - NeIn)/NeIn
            logical                :: lgNeSum       ! D-279: NeUsed is the ion sum
            integer                :: iCr280        ! D-280: cosmic-ray table entry
            real                   :: omega280      ! D-280: cell Lyman-Werner albedo

            double precision, dimension(nELements) :: &
                 & denominator   ! denominator of final ion abundance
            real(kind=8), dimension(nElements) :: availFrac   ! D-102


            real, dimension(nElements, nstages) :: &
                 & deltaE_k      ! deltaE/k [K]

            double precision, dimension(nElements, nstages) :: &
                 & ionRatio, &   ! X(i+1)/X(+i)
                 & ionProd       ! ionRatio products

            ! D-114: the chain solve forms only the RATIO of adjacent stages.
            ! A matrix solve needs the two rates separately, so keep them.
            !   ionUp(elem,ion) = rate coefficient   stage ion -> ion+1  [s^-1]
            !   ionDn(elem,ion) = rate coefficient   stage ion+1 -> ion  [s^-1]
            double precision, dimension(nElements, nstages) :: ionUp, ionDn
            double precision, dimension(nstages, nstages)   :: ionMat
            double precision, dimension(nstages)            :: ionRHS, ionSol, ionScal
            double precision, dimension(nstages)            :: chemSrc, chemSnk  ! D-118
            integer                                         :: ik                ! D-118
            double precision, dimension(nElements, nstages) :: ionSolve
            integer                          :: nst, ir, ic, ic2Swap, ipiv, iBig
            integer                          :: iLo, iHi, nr
            double precision                       :: piv, fac, big
            real, dimension(nElements, nstages,4) :: &
                 & chex         ! ch exchange coeff in cm^3/s

            ! D-235: is the photoionization sum empty because there is no
            ! field in this ion's range, or because there is no cross-section?
            integer :: jLo234, jHi234, jj234, nnz234, iB234
            real    :: sumJ234, xTh234, opac234


            ! initialize variables
            correction  = 0.
            ionRatio    = 0.
            ionUp       = 0.d0
            ionDn       = 0.d0
            ionSolve    = -1.d0
            ionProd     = 1.
            denominator = 1.
            lgConv      = .true.
            NeIn        = NeUsed
            omega280    = -1.

            ! take into account collisional ionization of H
            ! Drake & Ulrich, ApJS42(1980)351
            expFact = 157893.94/TeUsed

            if (expFact > 75.) then
                ! prevents underflow of exponential factor in collIon
                expFact = 75.
            end if

            collIon = 2.75E-16*TeUsed*sqrt(TeUsed)*&
                 & (157893.94/TeUsed+2.)*exp(-expFact)


            ! get HIOld, HeIOld, HeIIOld from last iteration
            HIOld   = ionDenUsed(elementXref(1),1)
            HeIOld  = ionDenUSed(elementXref(2),1)
            HeIIOld = ionDenUsed(elementXref(2),2)

            ! the set of charge exchange coeffs is not complete; the following might need
            ! to be changed when a more complete set is available



            chex          = 0.
            deltaE_k      = 0.

            chex(2,1,:)  = (/7.47e-6, 2.06, 9.93,-3.89/)! He0
            chex(2,2,:)  = (/1.e-5  , 0.  , 0.  , 0./)  ! He+
            chex(3,2,:)  = (/1.26   , 0.96,3.02 ,-0.65/)! Li+
            chex(3,3,:)  = (/1.e-5  , 0.  , 0.  , 0. /) ! Li+2
            chex(4,2,:)  = (/1.e-5  , 0.  , 0.  , 0. /) ! Be+
            chex(4,3,:)  = (/1.e-5  , 0.  , 0.  , 0. /) ! Be+2
            chex(4,4,:)  = (/5.17   , 0.82, -.69, -1.12 /)! Be+3
            chex(5,2,:)  = (/2.e-2  , 0.  , 0.  , 0. /) ! B+
            chex(5,3,:)  = (/1.e-5  , 0.  , 0.  , 0. /) ! B+2
            chex(5,4,:)  = (/5.27e-1, 0.76,-0.63,-1.17/)! B+3
            chex(6,1,:)  = (/1.76e-9, 8.33, 4278.78, -6.41/)! C0
            chex(6,2,:)  = (/1.67e-4, 2.79, 304.72, -4.07/)! C+
            chex(6,3,:)  = (/3.25   , 0.21, 0.19, -3.29/)! C+2
            chex(6,4,:)  = (/332.46 ,-0.11,-0.995,-1.58e-3/)! C+3
            chex(7,1,:)  = (/1.01e-3,-0.29,-0.92, -8.38/)! N0
            chex(7,2,:)  = (/3.05e-1, 0.60, 2.65, -0.93/)! N+
            chex(7,3,:)  = (/4.54   , 0.57,-0.65, -0.89/)! N2+
            chex(7,4,:)  = (/3.28   , 0.52,-0.52, -0.19/)! N3+
            chex(8,1,:)  = (/1.04   , 3.15e-2, -0.61, -9.73/)! O0
            chex(8,2,:)  = (/1.04   , 0.27, 2.02, -5.92/)! O+
            chex(8,3,:)  = (/3.98   , 0.26, 0.56, -2.62/)! O2+
            chex(8,4,:)  = (/2.52e-1, 0.63, 2.08, -4.16/)! O3+
            chex(9,2,:)  = (/1.e-5  , 0.  , 0.  , 0./) ! F+
            chex(9,3,:)  = (/9.86   , 0.29,-0.21,-1.15/) ! F+2
            chex(9,4,:)  = (/7.15e-1, 1.21,-0.70,-0.85/) ! F3+
            chex(10,2,:) = (/1.e-5  , 0.  , 0.  , 0.  /) ! Ne+
            chex(10,3,:) = (/14.73  , 4.52e-2, -0.84, -0.31 /) ! Ne+2
            chex(10,4,:) = (/6.47   , 0.54 , 3.59 , -5.22 /) ! Ne+3
            chex(11,2,:) = (/1.e-5  , 0.   , 0.   , 0. /) ! Na+
            chex(11,3,:) = (/1.33   , 1.15 , 1.20 , -0.32 /)! Na+2
            chex(11,4,:) = (/1.01e-1, 1.34 , 10.05, -6.41 /)! Na+3
            chex(12,2,:) = (/8.58e-5, 2.49e-3, 2.93e-2, -4.33 /)! Mg+
            chex(12,3,:) = (/6.49   , 0.53 , 2.82, -7.63 /) ! Mg+2
            chex(12,4,:) = (/6.36   , 0.55 , 3.86, -5.19 /) ! Mg+3
            chex(13,2,:) = (/1.e-5  , 0.   , 0.  , 0./) ! Al+
            chex(13,3,:) = (/7.11e-5, 4.12 , 1.72e4, -22.24/)! Al+2
            chex(13,4,:) = (/7.52e-1, 0.77 , 6.24, -5.67/) ! Al+3
            chex(14,2,:) = (/1.23   , 0.24 , 3.17, 4.18e-3/) ! Si+
            chex(14,3,:) = (/4.900e-1, -8.74e-2, -0.36, -0.79/)! Si+2
            chex(14,4,:) = (/7.58   , 0.37 , 1.06, -4.09/)! Si+3
            chex(16,1,:) = (/3.82e-7, 11.10, 2.57e4, -8.22/)! S0
            chex(16,2,:) = (/1.e-5  , 0.   , 0.   ,0. /)! S+
            chex(16,3,:) = (/2.29   , 4.02e-2, 1.59, -6.06/)! S+2
            chex(16,4,:) = (/6.44   , 0.13 , 2.69 , -5.69/)! S+3
            chex(18,2,:) = (/1.e-5  , 0.   , 0.    , 0./) ! Ar+
            chex(18,3,:) = (/4.57   , 0.27 , -0.18 , -1.57/)! Ar+2
            chex(18,4,:) = (/6.37   , 2.12 , 10.21 , -6.22/)! Ar+3
            chex(20,3,:) = (/3.17e-2, 2.12 , 12.06 , -0.40/)! Ca+2
            chex(20,4,:) = (/2.68   , 0.69 , -0.68 , -4.47/)! Ca+3
            chex(26,2,:) = (/1.26   , 7.72e-2, -0.41, -7.31/)! Fe+
            chex(26,3,:) = (/3.42   , 0.51 , -2.06 , -8.99/)! Fe+2.


            ! D-263: deltaE/k is the difference of the ionization potentials,
            ! IP(X) - IP(H) with IP(H) = 13.5984 eV. N: 14.5341 eV -> 10858 K,
            ! as tabulated. O: 13.6181 eV -> 0.0197 eV = 229 K; it had been
            ! 2205 K, ten times too large (Kingdon & Ferland 1996 give 0.02 eV,
            ! UMIST 225.9 K), which held O + H+ -> O+ + H at 2e-9 of its value
            ! at 100 K and 0.5 of it at 3000 K (D-262).
            deltaE_k(7,1) = 10863.
            deltaE_k(8,1) = 229.

            chex(:,:,1) = chex(:,:,1)*1.e-9


            t4 = TeUsed/10000.


            ! calculate the X(i+1)/X(i) ratio
            do elem = 1, nElements
                do ion = 1, min(elem, nstages-1)
                    if (.not.lgElementOn(elem)) exit

                    chex(elem,ion,1) = chex(elem,ion,1)*(t4**chex(elem,ion,2))*&
                         & (1.+chex(elem,ion,3)*exp(chex(elem,ion,4)*t4))

                    if (chex(elem,ion,1) < 0. ) chex(elem,ion,1) = 0.
                    ! D-263: no lower cut-off. It had been 6000 K for every
                    ! element, which is not the fits' validity limit (O+ + H is
                    ! valid to 10 K and agrees with Stancil et al. 1999 and
                    ! UMIST to 5-15% below 1000 K) and removed the only O+
                    ! source in PDR gas (D-261, D-262). The upper cut-off stays.
                    if (TeUsed > 5.e4) chex(elem,ion,1) = 0.

                    ! find the number of electron in this ion
                    nElec = elem - ion +1

                    ! find the stat weights
                    call getOuterShell(elem, nElec, outShell, g0, g1)

                    ! calculate the reverse charge exchange rate (only if deltaE_k > 1.)
                    if ( deltaE_k(elem,ion) > 1.) then

                       ! D-263: n(H+) is x(H+)*n_H. It was (1 - x(H0))*n_H,
                       ! the same thing in ionized gas but in molecular gas it
                       ! also counts the hydrogen in H2 - harmless while the
                       ! 6000 K cut-off zeroed this in cold gas, not after.
                       revRate = chex(elem,ion,1) * &
                            & grid%ionDen(cellP, &
                            & elementXref(1),2)*grid%Hden(cellP)*&
                            & 2. * exp(-deltaE_k(elem,ion)/TeUsed)/(real(g0)/real(g1))
                    else
                       revRate = 0.
                    end if

                    if ( (elem>1) .or. (ion>1) ) collIon = 0.

                    ! calculate the X(i+1)/X(i) ratio
                    ! D-114: form the two rates separately and take the ratio
                    ! from them, so the chain and the matrix are guaranteed to
                    ! be solving identical physics rather than merely similar
                    ! expressions.
                    if (lgDebug) then
                       ionUp(elem,ion) = dble(nPhotoSte(elem,ion))+dble(nPhotoDif(elem,ion))+&
                            & dble(collIon)+dble(revRate)
                    else
                       ionUp(elem,ion) = dble(nPhotoSte(elem,ion))+&
                            & dble(collIon)+dble(revRate)
                    end if
                    ionDn(elem,ion) = dble(NeUsed)*dble(alphaTot(elem,ion)) &
                         & + dble(chex(elem,ion,1))*dble(grid%Hden(grid%active(xP,yp,zP))) &
                         & * dble(grid%ionDen(cellP,elementXref(1),1))

                    ! A negative rate coefficient is meaningless. The real
                    ! source of them is the dielectronic fit going negative in
                    ! cool gas (see calcAlpha above), which drives ionDn below
                    ! zero. ionUp is NOT a second route: revRate is a product
                    ! of non-negative factors (x(H+) since D-263). An earlier
                    ! comment here claimed otherwise; measured on two models,
                    ! the numerator is never negative. The clamps stay as cheap
                    ! insurance.
#ifdef PDR
                    ! D-193: cosmic-ray ionization, as MOCASSIN's own physics.
                    !
                    ! MOCASSIN has never had it (D-035). Until now it arrived
                    ! second-hand, inside the chemistry's injected source/sink
                    ! rates; with those gone the ionization of shielded gas
                    ! would otherwise fall to zero, which is wrong and would
                    ! have been a silent loss rather than a visible one.
                    !
                    ! Coefficients are the network's own, so both codes ionize
                    ! at identical rates from an identical zeta:
                    !   rates_reduced.d:293  H  + CRP -> H+  + e   5.98e-18
                    !   rates_reduced.d:297  He + CRP -> He+ + e   6.50e-18
                    ! evaluated as calc_reac_rates.F90 evaluates them,
                    ! RATE = ALPHA*(zeta/1.3e-17). Secondary ionization by the
                    ! knock-on electrons is folded into those coefficients
                    ! upstream, as it is in UMIST.
                    ! D-280: for EVERY linked neutral, not only H and He, and
                    ! from the network's reactions rather than two literals.
                    ! The elem == 1/2 gate left carbon, oxygen and magnesium
                    ! with no cosmic-ray source (D-234): past A_V ~2.6 their
                    ! only source was the Monte Carlo field, while the network
                    ! carries C + CRP (298), C + CRPHOT (301, gamma 510) and
                    ! Mg + CRPHOT (312, gamma 113). Rates exactly as
                    ! calc_reac_rates.F90: CRP alpha*zeta; CRPHOT
                    ! alpha*zeta*(T/300)^beta*gamma/(1-omega), with omega the
                    ! cell's own Lyman-Werner albedo.
                    if (lgPDR .and. ion == 1 .and. pdrNcr > 0) then
                       do iCr280 = 1, pdrNcr
                          if (pdrCrElem(iCr280) /= elem) cycle
                          if (pdrCrType(iCr280) == 1) then
                             ionUp(elem,ion) = ionUp(elem,ion) &
                                  & + pdrCrAlpha(iCr280)*dble(pdrZeta)/1.3d-17
                          else
                             if (omega280 < 0.) omega280 = grainAlbedoLW(grid, cellP)
                             ionUp(elem,ion) = ionUp(elem,ion) &
                                  & + pdrCrAlpha(iCr280)*dble(pdrZeta)/1.3d-17 &
                                  & * (dble(TeUsed)/300.d0)**pdrCrBeta(iCr280) &
                                  & * pdrCrGamma(iCr280)/(1.d0 - dble(omega280))
                          end if
                       end do
                    end if
#endif

                    if (ionUp(elem,ion) < 0.d0) ionUp(elem,ion) = 0.d0
                    if (ionDn(elem,ion) < 0.d0) ionDn(elem,ion) = 0.d0

#ifdef PDR
                    ! ------------------------------------------------ D-234
                    ! EVERY element, not only carbon. Deep in the PDR x(C+) is
                    ! 1e-7 of the reference while x(He+) is 1e3-1e4 ABOVE it,
                    ! in the same cells at the same temperature. Opposite
                    ! signs, so a carbon-only probe cannot separate "carbon is
                    ! wrong" from "the balance splits by element" - and two
                    ! things here are element-dependent by construction:
                    !
                    !   - chex was zeroed below 6000 K, for every element, so
                    !     no metal had a charge-exchange sink here (removed by
                    !     D-263)
                    !   - the cosmic-ray source is added only for elem 1 and 2
                    !     (the D-193 block below), so H and He keep a source in
                    !     shielded gas that every metal loses
                    !
                    ! That predicts H/He over-ionized and metals under-ionized,
                    ! split exactly at elem 2. Print both rates and each of
                    ! their ingredients, per stage per element, in one cell.
                    ! nIterateMC >= 12: the cliff is a property of the settled
                    ! state, and the first deep cells this would otherwise
                    ! catch are at iteration 4, before anything has cooled.
                    ! D-236: one cell per 0.5 mag of A_V. D-234/D-235 sampled a
                    ! single cell (27, A_V 2.88) and found zero field above the
                    ! lowest metal threshold - which cannot distinguish photons
                    ! absorbed on the way in from photons never present. The
                    ! depth profile does distinguish them.
                    iB234 = int(grid%AVeff(cellP)/0.5)
                    if (iB234 < 0)  iB234 = 0
                    if (iB234 > 15) iB234 = 15
                    ! D-237: every rank samples, not only rank 0. Rank 0 owns a
                    ! fraction of the grid, and D-236's one-cell-per-0.5-mag
                    ! scheme returned two depth points because of it.
                    if (teProbe /= 0 .and. nProbe234 < 400 &
                         & .and. nIterateMC >= 12 .and. ion <= 2 &
                         & .and. grid%pdrZone(cellP) == 1 &
                         & .and. (.not.lgAVsamp234(iB234) .or. cellSamp234 == cellP)) then
                       if (cellSamp234 /= cellP) then
                          cellSamp234 = cellP
                          lgAVsamp234(iB234) = .true.
                       end if
                       nProbe234 = nProbe234 + 1
                       ! D-235: the field and the cross-section this ion
                       ! actually sees, over its OWN range. phot sits at its
                       ! 1e-20 initialisation floor for every element while
                       ! chiFUV - built from the same Jste - reads 0.13 in
                       ! this cell, so one of the two must be empty.
                       sumJ234 = 0.; xTh234 = 0.; nnz234 = 0; opac234 = 0.
                       jLo234 = 0; jHi234 = 0
                       if (elem > 2) then
                          jLo234 = elementP(elem, ion, outShell, 1)
                          jHi234 = min(elementP(elem, ion, outShell, 2) - 1, nbins)
                          if (jLo234 >= 1 .and. jHi234 >= jLo234) then
                             do jj234 = jLo234, jHi234
                                sumJ234 = sumJ234 + grid%Jste(cellP, jj234)
                                if (grid%Jste(cellP, jj234) > 0.) nnz234 = nnz234 + 1
                             end do
                             if (elementP(elem, ion, outShell, 3) >= 1 .and. &
                                  & elementP(elem, ion, outShell, 3) <= size(xSecArray)) &
                                  & xTh234 = xSecArray(elementP(elem, ion, outShell, 3))
                             ! D-237: MOCASSIN's OWN total opacity at this
                             ! ion's threshold bin, so tau is measured rather
                             ! than estimated from A_V and a column.
                             opac234 = grid%opacity(cellP, jLo234)
                          end if
                       end if
                       if (elem == 1 .and. ion == 1) &
                            & print*, "! [D234] rank", taskid, " cell", cellP, " AV", &
                            & grid%AVeff(cellP), " Te", TeUsed, " Ne", NeUsed, &
                            & " nH", grid%Hden(cellP), " chi", grid%chiFUV(cellP)
                       print '(a,a2,i3,a,es10.3,a,es10.3,a,es10.3,a,es10.3,a,es10.3,a,f7.4,a,es10.3)', &
                            & " ! [D234]   ", elemLabel(elem), ion, &
                            & "  up", ionUp(elem,ion), &
                            & "  phot", dble(nPhotoSte(elem,ion)), &
                            & "  dn", ionDn(elem,ion), &
                            & "  Ne*alpha", dble(NeUsed)*dble(alphaTot(elem,ion)), &
                            & "  chex", dble(chex(elem,ion,1)), &
                            & "  nu_th", nuArray(elementP(elem,ion,outShell,1)), &
                            & "  up/dn", ionUp(elem,ion)/max(ionDn(elem,ion),1.d-99)
                       ! D-238: rank and cell on EVERY line. With 14 ranks
                       ! writing to one stdout, a [D235] line could attach to
                       ! another rank's [D234] header - D-237 recorded that as
                       ! a caveat and D-238's first profile was corrupted by it
                       ! (deep cells reading shallow cells' values verbatim).
                       if (elem == 6 .or. elem == 16) &
                            & print '(a,i3,a,i7,a,a2,i3,a,i5,a,es10.3,a,i5,a,es10.3,a,es10.3)', &
                            & " ! [D235] rank", taskid, " cell", cellP, "  ", elemLabel(elem), ion, &
                            & "  binLo", jLo234, &
                            & "  sum Jste", dble(sumJ234), &
                            & "  bins with J>0", nnz234, &
                            & "  xSec(thresh)", dble(xTh234), &
                            & "  opac(thresh)", dble(opac234)
                    end if
#endif

                    ! D-116: a zero denominator is what drives the whole
                    ! pathology. Report its two terms the first time it
                    ! happens, so the cause is read rather than inferred -
                    ! the alphaTot audit already came back clean, so it is
                    ! not missing atomic data.
                    if (lgAlphaAudit .and. taskid == 0 .and. .not.lgDnAudited &
                        & .and. ionDn(elem,ion) <= 0.d0) then
                       lgDnAudited = .true.
                       print*, "! [D116] ionDn = 0 : elem", elem, " stage", ion
                       print*, "! [D116]   Ne =", NeUsed, "  alphaTot =", alphaTot(elem,ion), &
                            & "  -> term1 =", NeUsed*alphaTot(elem,ion)
                       print*, "! [D116]   chex =", chex(elem,ion,1), "  Hden =", &
                            & grid%Hden(cellP), "  x(H0) =", &
                            & grid%ionDen(cellP,elementXref(1),1), &
                            & "  -> term2 =", chex(elem,ion,1) &
                            & *grid%Hden(cellP)*grid%ionDen(cellP,elementXref(1),1)
                       print*, "! [D116]   Te =", TeUsed, " (chex is zeroed above 50000 K)"
                       print*, "! [D116]   ionUp =", ionUp(elem,ion)
                    end if

                    ! The clamp above can leave ionDn at EXACTLY zero where it
                    ! was previously a small negative, turning this division
                    ! into 0/0 = NaN. That NaN propagates into ionProd, into
                    ! ionDen, and out to getGrainRecombination, whose "insane
                    ! eta" warning is unthrottled: one overnight run wrote 38.5
                    ! million lines and a 3 GB log into a tmpfs, i.e. into RAM.
                    ! Guard the division rather than the symptom.
                    !
                    ! A zero denominator means no recombination path out of the
                    ! stage above - nothing physical bounds the ratio, so cap it
                    ! rather than inventing an infinity. The cap is far above
                    ! any ratio that survives normalisation.
                    if (ionDn(elem,ion) > 0.d0) then
                       ionRatio(elem,ion) = ionUp(elem,ion)/ionDn(elem,ion)
                       if (ionRatio(elem,ion) > 1.d30) ionRatio(elem,ion) = 1.d30
                    else if (ionUp(elem,ion) > 0.d0) then
                       ionRatio(elem,ion) = 1.d30
                    else
                       ionRatio(elem,ion) = 0.d0
                    end if
                    if (.not. (ionRatio(elem,ion) >= 0.d0)) ionRatio(elem,ion) = 0.d0
                 end do
              end do

            ! calculate the products of ionRatio
            do elem = 1, nElements
                do ion = 1, min(elem, nstages-1)
                   if (.not.lgElementOn(elem)) exit

                   ! generate the product
                   do i = 1, ion
                       ionProd(elem, ion) = ionProd(elem,ion)*ionRatio(elem, i)

                   end do

                end do
            end do

            availFrac = 1.
#ifdef PDR
            if (lgPDR) then
               ! D-118: elemAvail (D-102) and the per-stage chemical rates are
               ! TWO DESCRIPTIONS OF THE SAME PHYSICS. elemAvail says "this
               ! fraction of the element is locked in molecules"; the rates say
               ! "it is being locked up this fast and released that fast".
               ! Applying both double-counts the locking, so where the rates
               ! are supplied elemAvail must stand down.
               !
               ! It is kept, not deleted, for the cells the rates do not reach:
               ! outside the PDR zone there are no rates, and elemAvail is 1.0
               ! there anyway, so the two agree by construction.
               ! ---------------------------------------------------- D-193
               ! elemAvail ALWAYS carries the molecular locking. It is not one
               ! of two interchangeable descriptions - it is the conservation
               ! constraint, and there is nothing for it to stand down in
               ! favour of.
               !
               ! D-185 stood it down wherever the chemistry supplied per-stage
               ! rates, on the argument that rates and elemAvail describe the
               ! same locking twice. They do not. elemAvail sets the SUM of the
               ! ion stages - how much of the element is not in molecules. The
               ! rates set RATIOS between stages. Dropping the sum because the
               ! ratios are known leaves the stages normalised to 1.0 in gas
               ! that is 99% molecular, which is what D-192 measured: hydrogen
               ! at x(H+) = 0.58 where the chemistry said 0.045, in cells whose
               ! non-molecular budget is 0.0094 in total.
               !
               ! The rates are gone as of D-193 (see the matrix assembly
               ! below); the constraint stays, unconditionally.
               do elem = 1, nElements
                  if (.not.lgElementOn(elem)) cycle
                  availFrac(elem) = &
                    & min(max(dble(grid%elemAvail(cellP, elem)), 1.d-10), 1.d0)
               end do
            end if
#endif

            ! calculate denominators for final ion abundances
            do elem = 1, nElements
                do ion = 1, min(elem, nstages-1)
                    if (.not.lgElementOn(elem)) exit

                    denominator(elem) = denominator(elem) + ionProd(elem, ion)

               end do
            end do

            ! ---------------------------------------------------------------
            ! D-114: matrix solve, replacing the chain above.
            !
            ! The chain forms x(i+1)/x(i) for each adjacent pair, multiplies
            ! the ratios and normalises. That is the exact solution of a pure
            ! birth-death system and nothing more: it is only valid while the
            ! ONLY couplings are ionization up and recombination down. A
            ! molecular source is inhomogeneous - it adds rather than
            ! multiplies - and chemistry can move an element between stages
            ! that are not adjacent. Neither fits a product of ratios, which
            ! is why Cloudy solves a matrix (D-111, ion_solver.cpp).
            !
            ! Balance for stage i, with U = ionUp and D = ionDn:
            !
            !   U(i-1) x(i-1) - (U(i) + D(i-1)) x(i) + D(i) x(i+1) = 0
            !
            ! The system is singular by construction - it conserves the
            ! element, so one equation is redundant - and is closed by
            ! replacing the row of the LARGEST stage with sum(x) = availFrac.
            ! Replacing the largest rather than the first is what keeps it
            ! conditioned when the population spans twenty decades.
            !
            ! Molecular source/sink terms enter on the RHS and the diagonal
            ! respectively (step 3); with none supplied this reproduces the
            ! chain to round-off, which is the acceptance test.
            if (lgIonMatrix) then
               do elem = 1, nElements
                  if (.not.lgElementOn(elem)) cycle
                  nst = min(elem+1, nstages)
                  if (nst < 2) cycle

                  ! Column-scale by the chain estimate: substitute
                  ! x(i) = c(i)*y(i) and solve for y. The stage populations
                  ! span thirteen decades or more (measured: C+ at 0.92 beside
                  ! C3+ at 7e-13), and eliminating on the raw matrix loses the
                  ! trace stages to cancellation - the first version of this
                  ! returned 5e-18 for that C3+, five orders out. Scaling makes
                  ! every unknown O(1), so the elimination is conditioned on
                  ! the ratios that matter rather than on the absolute sizes.
                  !
                  ! It also makes the acceptance test exact rather than
                  ! approximate: with no molecular terms the chain IS the
                  ! solution, so y = 1 identically and the elimination has
                  ! nothing left to lose. Cloudy solves the same problem by
                  ! trimming the stage range instead (ion_trim); scaling avoids
                  ! having to choose a trimming threshold.
                  ionScal = 0.d0
                  do ir = 1, nst
                     if (ir == 1) then
                        ionScal(ir) = availFrac(elem)/denominator(elem)
                     else
                        ionScal(ir) = availFrac(elem)*ionProd(elem,ir-1)/denominator(elem)
                     end if
                     if (.not.(ionScal(ir) > 0.d0)) ionScal(ir) = 0.d0
                  end do
                  big = maxval(ionScal(1:nst))
                  if (big <= 0.d0) cycle

                  ! TRIM the system to the populated stages, as Cloudy does
                  ! (ion_trim, trimlo = 1e-10 of the element). Column scaling
                  ! alone is not enough and the earlier attempt proved it: it
                  ! conditions the balance rows, but the conservation row ties
                  ! every stage to O(1), so a stage twenty-five decades down is
                  ! lost in the rounding of order-unity quantities no matter how
                  ! the columns are scaled. Measured then: neutral carbon 18-20
                  ! orders out in test_Problem. Bounding the SPAN is what makes
                  ! the problem tractable; the threshold is the mechanism, not
                  ! the price.
                  iLo = 1
                  do while (iLo < nst .and. ionScal(iLo) < ionTrim*big)
                     iLo = iLo + 1
                  end do
                  iHi = nst
                  do while (iHi > iLo .and. ionScal(iHi) < ionTrim*big)
                     iHi = iHi - 1
                  end do

                  ! Stages outside the range keep their chain value - the ratio
                  ! recursion is exact and perfectly stable precisely where the
                  ! matrix is not, so this is not a fallback but the better
                  ! instrument for that regime.
                  do ir = 1, nst
                     ionSolve(elem,ir) = ionScal(ir)
                  end do
                  if (iHi <= iLo) cycle

                  ! Build over [iLo,iHi] with the boundaries CLOSED - no flux in
                  ! from iLo-1, none out to iHi+1. That is not an approximation
                  ! here: with the boundary closed, row iLo reads
                  !   -U(iLo) x(iLo) + D(iLo) x(iLo+1) = 0
                  ! which the chain satisfies identically, and likewise at iHi.
                  ! So the trimmed system's exact solution IS the chain
                  ! restricted to the range, and the no-molecular-terms
                  ! equivalence stays exact by construction rather than by
                  ! numerical luck.
                  nr = iHi - iLo + 1
                  ionMat = 0.d0
                  ionRHS = 0.d0

                  ! D-118: the chemistry's terms for this element's stages.
                  ! chemSrc is an additive production rate, chemSnk a specific
                  ! destruction rate multiplying the stage's own abundance -
                  ! exactly the RHS and diagonal slots left empty in D-114, and
                  ! exactly what Cloudy puts there (ion_solver.cpp:765):
                  !     source[i] -= mole.source[nelem][ion];
                  !     MAT(xmat,i,i) -= mole.sink[nelem][ion];
                  ! A stage the network does not carry keeps zero for both and
                  ! is left entirely to the ion solver.
                  chemSrc = 0.d0; chemSnk = 0.d0
                  ! D-193: the chemistry's per-stage source/sink rates are NO
                  ! LONGER injected here. MOCASSIN owns the ionization; the one
                  ! thing 3D-PDR reports about an element is how much of it is
                  ! locked in molecules, and that arrives as elemAvail above.
                  !
                  ! pdrFormSp/pdrLossSp are the whole ODE right-hand side for
                  ! the species, molecular channels included, so injecting them
                  ! here while also constraining the sum to elemAvail counts the
                  ! molecular drain twice - and injecting them INSTEAD of the
                  ! constraint is what produced D-192. Neither is the design.
                  ! The arrays are still published, as diagnostics (D-113).
                  !
                  ! What this would have dropped on its own is cosmic-ray
                  ! ionization, which MOCASSIN lacks (D-035) and which reached
                  ! it only through these rates. It is added below as
                  ! MOCASSIN's own physics rather than imported as a rate.
                  do ir = iLo, iHi-1
                     ic = ir - iLo + 1
                     ionMat(ic,ic)     = ionMat(ic,ic)     - ionUp(elem,ir)*ionScal(ir)
                     ionMat(ic+1,ic)   = ionMat(ic+1,ic)   + ionUp(elem,ir)*ionScal(ir)
                     ionMat(ic,ic+1)   = ionMat(ic,ic+1)   + ionDn(elem,ir)*ionScal(ir+1)
                     ionMat(ic+1,ic+1) = ionMat(ic+1,ic+1) - ionDn(elem,ir)*ionScal(ir+1)
                  end do

                  ! chemical terms on the same scaled system: the sink is a
                  ! rate coefficient so it scales with the column, the source
                  ! is a rate so it goes to the RHS unscaled
                  do ir = iLo, iHi
                     ic = ir - iLo + 1
                     ionMat(ic,ic) = ionMat(ic,ic) - chemSnk(ir)*ionScal(ir)
                     ionRHS(ic)    = ionRHS(ic)    - chemSrc(ir)
                  end do
#ifdef PDR
                  ! D-169: MOCASSIN's own rates against the chemistry's, for
                  ! hydrogen, in a deep cell. thermBalance's heating integral
                  ! implies Gamma ~ 1e-9 /s while the same cell reports
                  ! x(H+) = 0.02, which needs ~1e-15. Both cannot be right, and
                  ! the injected source/sink is the only thing that enters this
                  ! matrix from outside MOCASSIN's own physics.
                  ! D-169: fire on a CEILING cell, not merely a deep one. The
                  ! previous version caught a well-behaved 101 K cell and its
                  ! rates were then compared against a hot cell's heating - two
                  ! different cells, which is how the "59 keV per event" came
                  ! about. Everything here must come from one cell, one call.
                  if (teProbe /= 0 .and. elem == 1 .and. taskid == 0 .and. &
                       & nRateProbe < 6 .and. grid%pdrZone(cellP) == 1 .and. &
                       & TeUsed >= 29999.) then
                     nRateProbe = nRateProbe + 1
                     print*, "! [D169] cell", cellP, " AV", grid%AVeff(cellP), &
                          & " Te", TeUsed, " x(H+)", grid%ionDen(cellP,elementXref(1),2)
                     print*, "! [D169]   MOCASSIN up(H0->H+)", ionUp(1,1), &
                          & "  dn(H+->H0)", ionDn(1,1)
                     print*, "! [D169]   chemistry src(H+)", chemSrc(min(2,nst)), &
                          & "  snk(H+)", chemSnk(min(2,nst)), &
                          & "  src(H0)", chemSrc(1), "  snk(H0)", chemSnk(1)
                     print*, "! [D169]   up/dn implies x(H+)/x(H0) =", &
                          & ionUp(1,1)/max(ionDn(1,1),1.d-30), &
                          & "  availFrac(H)", availFrac(1), &
                          & "  Ne", NeUsed, "  iLo", iLo, " iHi", iHi
                  end if
#endif

                  ! close on the largest stage in the range, and conserve only
                  ! what the range holds
                  iBig = 1; big = 0.d0
                  do ir = iLo, iHi
                     if (ionScal(ir) > big) then
                        big = ionScal(ir); iBig = ir - iLo + 1
                     end if
                  end do
                  fac = 0.d0
                  do ir = iLo, iHi
                     ionMat(iBig,ir-iLo+1) = ionScal(ir)
                     fac = fac + ionScal(ir)
                  end do
                  ! the conservation row replaces its balance equation, and its
                  ! chemical terms with it
                  ionRHS(iBig) = fac
                  nst = nr

                  ! dense Gaussian elimination with partial pivoting. nst <= 7,
                  ! so this is not worth a library call.
                  ionSol = ionRHS
                  do ic = 1, nst-1
                     ipiv = ic; piv = abs(ionMat(ic,ic))
                     do ir = ic+1, nst
                        if (abs(ionMat(ir,ic)) > piv) then
                           piv = abs(ionMat(ir,ic)); ipiv = ir
                        end if
                     end do
                     if (piv <= 0.d0) cycle
                     if (ipiv /= ic) then
                        do ic2Swap = 1, nst
                           fac = ionMat(ic,ic2Swap)
                           ionMat(ic,ic2Swap) = ionMat(ipiv,ic2Swap)
                           ionMat(ipiv,ic2Swap) = fac
                        end do
                        fac = ionSol(ic); ionSol(ic) = ionSol(ipiv); ionSol(ipiv) = fac
                     end if
                     do ir = ic+1, nst
                        if (ionMat(ir,ic) == 0.d0) cycle
                        fac = ionMat(ir,ic)/ionMat(ic,ic)
                        do ic2Swap = ic, nst
                           ionMat(ir,ic2Swap) = ionMat(ir,ic2Swap) - fac*ionMat(ic,ic2Swap)
                        end do
                        ionSol(ir) = ionSol(ir) - fac*ionSol(ic)
                     end do
                  end do
                  do ir = nst, 1, -1
                     fac = ionSol(ir)
                     do ic = ir+1, nst
                        fac = fac - ionMat(ir,ic)*ionSol(ic)
                     end do
                     if (ionMat(ir,ir) /= 0.d0) then
                        ionSol(ir) = fac/ionMat(ir,ir)
                     else
                        ionSol(ir) = 0.d0
                     end if
                  end do

                  ! undo the scaling over the solved range only
                  do ir = 1, nr
                     ionSolve(elem,iLo+ir-1) = max(ionScal(iLo+ir-1)*ionSol(ir), 0.d0)
                  end do
               end do
            end if


            ! calculate the new abundances for all ions
            do elem = 1, nElements
                do ion = 1, min(elem+1, nstages)

                    if (.not.lgElementOn(elem)) exit


                    ! D-102: the ion stages share only the part of the element
                    ! that is not locked in a molecule. Without this factor the
                    ! stages are normalised to sum to one, which asserts that no
                    ! molecules exist - false in any PDR cell, and it silently
                    ! overwrote both the hydrogen and the carbon handovers on
                    ! every pass. elemAvail is 1.0 wherever the chemistry has
                    ! not run, so this is a no-op outside the PDR.
#ifdef PDR
                    ! D-106: in a PDR cell the chemistry has already solved the
                    ! ionization of the elements it tracks, with cosmic rays and
                    ! the molecular network that MOCASSIN does not have. Re-solving
                    ! them here does not add information - it replaces a correct
                    ! answer with Gamma/(Ne alpha) evaluated in a regime that
                    ! expression was never meant for, and feeds a self-sustaining
                    ! ionization/recombination loop (D-104).
                    ! D-169: ...unless MOCASSIN owns the ionization, in which
                    ! case this gate is the exact opposite policy and the two
                    ! cancel. pdrIonFromMocassin (D-162) imposes MOCASSIN's ratio
                    ! ON the network, before and after the solve; pdrOwnIon then
                    ! discards MOCASSIN's own answer in the same cells, so what
                    ! propagates is whatever handBackPDR wrote - the chemistry's
                    ! cosmic-ray equilibrium (D-161). x(H+) was bit-identical
                    ! across every temperature step because nothing was writing
                    ! it, while MOCASSIN's own up/dn implied 0.9998 against the
                    ! 0.0298 on the grid.
                    !
                    ! That is the hot runaway. thermBalance builds the heating
                    ! from a photoionization rate of 2.7e-9 /s times a neutral
                    ! fraction of 0.97 - but that rate, allowed to act, removes
                    ! the neutral hydrogen doing the absorbing. The heating is
                    ! computed against an ionization state the same field
                    ! forbids, and pinned there by the other code, so no
                    ! temperature can balance it.
                    !
                    ! Same shape as D-165: a switch added later that never
                    ! reached an older gate.
                    ! D-193: removed. There is one ionization solution and it
                    ! is MOCASSIN's, in every cell and for every element. This
                    ! gate skipped the writeback for H, He, C, O and Mg in PDR
                    ! cells, leaving those stages to whatever handBackPDR had
                    ! blended in - a second writer for the same array. That
                    ! second writer is gone too (pdrToMocassin, D-193).
#endif
                    ! D-114 self-check: the chain answer for this same stage,
                    ! this same cell, this same call. With no molecular terms
                    ! the two must agree to round-off; anything larger is the
                    ! solver, not the model.
                    if (lgIonMatrix .and. ionSolve(elem,ion) >= 0.d0) then
                       if (ion == 1) then
                          chainVal = availFrac(elem)/denominator(elem)
                       else
                          chainVal = availFrac(elem)*ionProd(elem,ion-1)/denominator(elem)
                       end if
                       ! The chain can return a small NEGATIVE fraction - it
                       ! forms a product of ratios over a denominator and has
                       ! no positivity constraint, and -2.4e-18 was measured
                       ! for C stage 5. The matrix clamps at zero, which is
                       ! the physical answer, so comparing against a negative
                       ! reference reports a spurious difference of 1.0. Count
                       ! those separately rather than letting them mask the
                       ! comparison that matters.
                       if (chainVal < 0.d0) then
                          ionMatNegChain = ionMatNegChain + 1
                       else if (max(chainVal,ionSolve(elem,ion)) > 1.d-15) then
                          diffVal = abs(chainVal-ionSolve(elem,ion)) &
                               &  / max(abs(chainVal),abs(ionSolve(elem,ion)))
                          if (diffVal > ionMatMaxDiff) then
                             ionMatMaxDiff  = diffVal
                             ionMatWorstEl  = elem
                             ionMatWorstIon = ion
                             ionMatWorstA   = chainVal
                             ionMatWorstB   = ionSolve(elem,ion)
                          end if
                       end if
                    end if

                    if (lgIonMatrix .and. ionSolve(elem,ion) >= 0.d0) then
                        ! D-114: the matrix answer. Identical to the chain when
                        ! no molecular terms are supplied - that equality is the
                        ! acceptance test for this conversion.
                        grid%ionDen(cellP,elementXref(elem),ion) = &
                             & real(ionSolve(elem,ion))
                    else if (ion == 1) then
                        grid%ionDen(cellP,elementXref(elem),ion) = &
                             & real(availFrac(elem)/denominator(elem))
                    else

                        grid%ionDen(cellP,elementXref(elem),ion) = &
                             & real(availFrac(elem)*ionProd(elem, ion-1)/denominator(elem))

                   end if

                   ! take back within the limit
                   if (grid%ionDen(cellP,elementXref(elem),ion) > xMax) &
                        & grid%ionDen(cellP,elementXref(elem),ion) = xMax
                   if (grid%ionDen(cellP,elementXref(elem),ion) < 1.e-20) &
                        & grid%ionDen(cellP,elementXref(elem),ion) = 1.e-20
#ifdef PDR
                   ! D-169: what the solve actually returned, AFTER the write.
                   ! The build-time print shows the previous call's value by
                   ! construction; this one shows whether a write landed at all.
                   ! ionSolve is pre-seeded with the old column at the top of
                   ! this block and the elimination skips a zero pivot, so a
                   ! singular system leaves the previous answer in place and
                   ! looks exactly like a converged one.
                   if (teProbe /= 0 .and. elem == 1 .and. taskid == 0 .and. &
                        & nSolProbe < 12 .and. grid%pdrZone(cellP) == 1 .and. &
                        & TeUsed >= 29999.) then
                      nSolProbe = nSolProbe + 1
                      print*, "! [D169b] cell", cellP, " ion", ion, &
                           & " ionSolve", ionSolve(elem,ion), &
                           & " -> grid", grid%ionDen(cellP,elementXref(elem),ion), &
                           & " lgIonMatrix", lgIonMatrix, " xMax", xMax
                   end if
#endif


                   ! D-121: the ionization hand-off, checked before the
                   ! value is consumed downstream
                   if (.not.lgNanFound) then
                      if (.not.(grid%ionDen(cellP,elementXref(elem),ion) == &
                              & grid%ionDen(cellP,elementXref(elem),ion))) then
                         lgNanFound = .true.; nanWhere = "ionDen after ionBalance"
                         nanCell = cellP; nanIdx = elem*100 + ion
                         print*, "! [D121] first non-finite: ", trim(nanWhere), &
                              & "  cell", nanCell, " elem*100+ion", nanIdx
                      end if
                   end if

                   ionDenUsed(elementXref(elem), ion) = &
                        & grid%ionDen(cellP,elementXref(elem),ion)
                   ! this was added to help MPI communication
                   ionDenTemp(cellP,elementXref(elem),ion) = &
                        & grid%ionDen(cellP,elementXref(elem),ion)


                end do
            end do

            ! calculate new Ne
          NeUsed = 0.
            do elem = 1, nElements
                do ion = 2, min(elem+1, nstages)
                    if (lgElementOn(elem)) then
                      if( ionDenUsed(elementXref(elem),ion) >= 1.e-10) &
                           & NeUsed = NeUsed + (ion-1)*&
                           &grid%elemAbun(grid%abFileIndex(xP,yP,zP),elem)*&
                           &ionDenUsed(elementXref(elem), ion)
                    end if

                end do
            end do

            NeUsed = NeUsed * grid%Hden(cellP)

#ifdef PDR
            ! D-105: in a PDR cell the electron density is the chemistry's, not a
            ! sum over the ion stages MOCASSIN happens to track. Once carbon is
            ! honestly locked in CO that sum collapses, and with no cosmic-ray
            ! ionization to hold a floor nothing stops it reaching zero - at which
            ! point X(i+1)/X(i) = Gamma/(Ne alpha) diverges and an infinitesimal
            ! photoionization rate ionizes the cell. Measured: x(H+) = 8e-3 where
            ! the chemistry gives 6e-7, in gas with no ionizing radiation at all,
            ! and MOCASSIN then emitted a recombination continuum for it (D-104).
            ! Tried and rejected: substituting it makes the runaway WORSE, because
            ! the chemistry's Ne is SMALLER than MOCASSIN's ion sum (cosmic-ray
            ! maintained, x_e ~ 1e-8) - Gamma/(Ne alpha) then diverges harder and
            ! max x(H+) went 1.3e-2 -> 0.906. Off by default; the array and its
            ! exchange are kept because the diagnosis needed them.
            lgNeSum = .true.
            if (lgPDR .and. pdrUseNePDR /= 0) then
               if (grid%pdrZone(cellP) == 1 .and. grid%NePDR(cellP) > 0.) then
                  NeUsed  = grid%NePDR(cellP)
                  lgNeSum = .false.
               end if
            end if
#else
            lgNeSum = .true.
#endif

            if (NeUsed==0. .and.lgTalk) print*, '! ionBalance [warning]: cell ', xP,yP,zP, &
                 &'; NeUsed = ',  NeUsed

            if (NeUsed == 0.) then
               NeUsed = 1.
            end if

            if (LgNeInput) then
               correction = NeUsed/grid%NeInput(cellP)
               grid%Hden(cellP) = grid%Hden(cellP)/correction
            end if

            ! this was added to help MPI implementation
            NeTemp(cellP) = NeUsed

            grid%Ne(cellP) = NeUsed


            ! ---------------------------------------------------------------- D-279
            ! The charge balance is a ROOT in n_e, and it is solved as one.
            !
            ! Every stage above was built with NeIn and the sum of the ions is
            ! NeUsed = NeOut(NeIn). Plain substitution - the next pass at NeOut -
            ! is what this routine did, and it oscillates wherever the electrons
            ! come only from trace ions, whose abundance is ionization/(n_e alpha):
            ! then NeOut ~ K/NeIn, the map has slope -1, and n_e alternates
            ! between two values for all maxIterateX passes (D-278: 18% of the
            ! hiipdr cells, deep PDR, He+ and H+ carrying every electron).
            !
            ! NeOut is a non-increasing function of NeIn (more electrons, more
            ! recombination, fewer ions), so the root always lies between NeIn
            ! and NeOut. Each pass intersects the bracket with that interval and
            ! the next pass is taken at the bracket's geometric mean - bisection
            ! in log n_e, which lands on the root of a pure K/n_e map in one step.
            ! Cloudy converges its electron density the same way, outside the
            ! ionization solve. If the bracket inverts (the map is not strictly
            ! monotone, e.g. through charge exchange with the neutral fraction
            ! just updated), it restarts from the current interval.
            deltaNe = 0.
            if (lgNeSum .and. NeIn > 0. .and. NeUsed > 0. .and. .not.LgNeInput) then
               if (nIterateX == 1) then
                  NeLoB = 0.
                  NeHiB = huge(1.)
               end if
               NeLoB = max(NeLoB, min(NeIn, NeUsed))
               NeHiB = min(NeHiB, max(NeIn, NeUsed))
               if (NeLoB > NeHiB) then
                  NeLoB = min(NeIn, NeUsed)
                  NeHiB = max(NeIn, NeUsed)
               end if
               deltaNe = (NeUsed - NeIn)/NeIn
            end if

            ! calculate the residuals
            deltaHI   = (ionDenUsed(elementXref(1),1) - HIOld)   / HIOld
            deltaHeI  = (ionDenUsed(elementXref(2),1) - HeIOld)  / HeIOld
            deltaHeII = (ionDenUsed(elementXref(2),2) - HeIIOld) / HeIIOld

            ! D-277 (O-11): the failing cells. The rates of every stage are
            ! built with NeIn and return NeUsed; a settled balance has
            ! NeUsed = NeIn. Printed per step: both, the three residuals
            ! the test uses, and who carries the electrons.
            if (ionBalProbe /= 0 .and. nIterateMC == maxIterateMC .and. &
                 & nIterateX >= maxIterateX - 5 .and. &
                 & ( (abs(deltaHI)>limit) .or. (abs(deltaHeI)>limit) .or. &
                 &   (abs(deltaHeII)>limit) .or. (abs(deltaNe)>limit) )) then
               if (nIterateX == maxIterateX .or. nIonBalTrail < ionBalProbe) then
                  eShare = 0.d0
                  do i = 1, 4
                     elem = eShEl(i)
                     if (.not.lgElementOn(elem)) cycle
                     do ion = 2, min(elem+1, nstages)
                        eShare(i) = eShare(i) + dble(ion-1)* &
                             & dble(grid%elemAbun(grid%abFileIndex(xP,yP,zP),elem))* &
                             & dble(ionDenUsed(elementXref(elem),ion))
                     end do
                  end do
                  eShare = eShare*dble(grid%Hden(cellP))/max(dble(NeUsed),1.d-30)
                  avProbe = -1.
#ifdef PDR
                  if (lgPDR) avProbe = grid%AVeff(cellP)
#endif
                  print '(a,i3,a,i7,a,i3,a,f6.3,a,es10.3,a,es11.4,a,es11.4,a,3es10.2,a,2es10.2,a,4f7.4)', &
                       & ' ! [D277] rank', taskid, ' cell', cellP, ' step', nIterateX, &
                       & ' AV', avProbe, ' Te', TeUsed, ' NeIn', NeIn, ' NeOut', NeUsed, &
                       & ' dHI/dHeI/dHeII', deltaHI, deltaHeI, deltaHeII, &
                       & ' xH+ xHe+', ionDenUsed(elementXref(1),2), ionDenUsed(elementXref(2),2), &
                       & ' eShare H/He/C/Mg', eShare
               end if
               if (nIterateX == maxIterateX) nIonBalTrail = nIonBalTrail + 1
            end if

            ! check for convergence
            ! D-279: the balance is solved only if the n_e it was built with is
            ! the n_e it produces, so that is tested alongside the ions.
            if ( ( (abs(deltaHI)>limit) .or. (abs(deltaHeI)>limit) .or. &
                 &(abs(deltaHeII)>limit) .or. (abs(deltaNe)>limit) ) &
                 & .and. (nIterateX<maxIterateX) ) then

                ! stepa up X iteration
                nIterateX = nIterateX + 1
                ! D-279: next pass at the bracket's geometric mean
                if (deltaNe /= 0.) NeUsed = sqrt(NeLoB)*sqrt(NeHiB)
                call ionBalance(lgConv)
                return

            else if (( (abs(deltaHI)>limit) .or. (abs(deltaHeI)>limit) .or. &
                 &(abs(deltaHeII)>limit) .or. (abs(deltaNe)>limit) ) &
                 & .and. (nIterateX == maxIterateX) ) then

               if (lgTalk)  print*, "! ionBalance: [warning] convergence not reached after ", &
                    &maxIterateX, " steps. Finishing up..."

                lgConv = .false.
            end if

            ! D-280 (O-01): the rates this balance ended with, for one element's
            ! first ionization, in every cell. up = photoionization (stellar Jste)
            ! + collisional + reverse charge exchange + cosmic rays; dn = Ne*alpha
            ! + charge exchange with H0. Compared per A_V with Cloudy's
            ! RateIonizTot and RateRecomTot, it separates a missing field from a
            ! different recombination.
            if (ionRateProbe > 0 .and. nIterateMC == maxIterateMC) then
               elem = ionRateProbe
               if (elem <= nElements .and. elem >= 1) then
                  if (lgElementOn(elem)) then
                     avProbe = -1.
#ifdef PDR
                     if (lgPDR) avProbe = grid%AVeff(cellP)
#endif
                     print '(a,i3,a,i7,a,f6.3,a,es10.3,a,es10.3,a,es10.3,a,es10.3,a,es10.3,a,es10.3,a,es10.3,a,2es10.3)', &
                          & ' ! [D280] rank', taskid, ' cell', cellP, ' AV', avProbe, &
                          & ' Te', TeUsed, ' Ne', NeUsed, ' up', ionUp(elem,1), &
                          & ' phot', dble(nPhotoSte(elem,1)), ' dn', ionDn(elem,1), &
                          & ' alpha', dble(alphaTot(elem,1)), ' chexH0', &
                          & dble(chex(elem,1,1))*dble(grid%Hden(cellP))*dble(grid%ionDen(cellP,elementXref(1),1)), &
                          & ' x1 x2', ionDenUsed(elementXref(elem),1), ionDenUsed(elementXref(elem),2)
                  end if
               end if
            end if

            ! this was added to help MPI implementation
            NeTemp(cellP) = NeUsed

        end subroutine ionBalance
        
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!subroutine ionBalance(lgConv)
!        implicit none

!        logical, intent(out)  :: lgConv      ! did ion bal converge?

!        ! local variables
!        real                  :: collIon     ! collisional ionization
!        real                  :: collIonH     ! collisional ionization of H
!        real                  :: correction  ! used in lgNeInput = .t.
!        real                  :: deltaHI     ! delta(X(H0))
!        real                  :: deltaHeI    ! delta(X(He0))
!        real                  :: deltaHeII   ! delta(X(HeII))
!        real                  :: expFact     ! exponential factor
!        real                  :: t4          ! TeUsed/10000.
!        real                  :: HIOld       ! X(H0) from last iteration
!        real                  :: HeIOld      ! X(He0) from last iteration
!        real                  :: HeIIOld     ! X(He+) from last iteration
!        real, parameter       :: limit = 0.01 ! convergence limit

!        integer               :: elem, ion   ! element and ion counters
!        integer               :: g0,g1       ! stat weights
!        integer               :: i           ! counter
!        integer               :: nElec       ! of e's in the ion
!        integer               :: outShell    ! byproduct of proc to get stat weights
!        integer               :: nIterateX   ! iteration counter

!        real                  :: revRate     ! reverse charge exchange rate

!        double precision, dimension(nELements) :: &
!             & denominator    ! denominator of final ion abundance

!        real, dimension(nElements, nstages) :: &
!             & deltaE_k       ! deltaE/k [K]

!        double precision, dimension(nElements, nstages) :: &
!             & ionRatio, &    ! X(i+1)/X(+i)
!             & ionProd        ! ionRatio products
!        real, dimension(nElements, nstages,4) :: &
!             & chex           ! ch exchange coeff in cm^3/s


!        !================================================================!
!        ! START OF THE MAIN ITERATIVE LOOP                             
!        ! This loop replaces the original recursive structure. It will 
!        ! continue until the ionic fractions converge or the maximum 
!        ! number of iterations is reached.
!        !================================================================!
!        nIterateX = 0 ! Initialize iteration counter
!        lgConv    = .false.

!        DO
!            ! initialize variables for the current iteration
!            correction  = 0.
!            ionRatio    = 0.
!            ionProd     = 1.
!            denominator = 1.

!            ! Store the ion densities from the previous step to check for convergence later.
!            HIOld   = ionDenUsed(elementXref(1),1)
!            HeIOld  = ionDenUsed(elementXref(2),1)
!            HeIIOld = ionDenUsed(elementXref(2),2)
!            
!            ! take into account collisional ionization of H
!            ! Drake & Ulrich, ApJS42(1980)351
!            expFact = 157893.94/TeUsed
!            if (expFact > 75.) then
!                ! prevents underflow of exponential factor in collIonH
!                expFact = 75.
!            end if
!            collIon = 2.75E-16*TeUsed*sqrt(TeUsed)*&
!                    & (157893.94/TeUsed+2.)*exp(-expFact)


!            ! Initialize charge exchange coefficients.
!            ! The set of charge exchange coeffs is not complete; the following might need
!            ! to be changed when a more complete set is available
!            chex      = 0.
!            deltaE_k  = 0.

!            chex(2,1,:)  = (/7.47e-6, 2.06, 9.93,-3.89/)! He0
!            chex(2,2,:)  = (/1.e-5  , 0.  , 0.  , 0./)  ! He+
!            chex(3,2,:)  = (/1.26   , 0.96,3.02 ,-0.65/)! Li+
!            chex(3,3,:)  = (/1.e-5  , 0.  , 0.  , 0. /) ! Li+2
!            chex(4,2,:)  = (/1.e-5  , 0.  , 0.  , 0. /) ! Be+
!            chex(4,3,:)  = (/1.e-5  , 0.  , 0.  , 0. /) ! Be+2
!            chex(4,4,:)  = (/5.17   , 0.82, -.69, -1.12 /)! Be+3
!            chex(5,2,:)  = (/2.e-2  , 0.  , 0.  , 0. /) ! B+
!            chex(5,3,:)  = (/1.e-5  , 0.  , 0.  , 0. /) ! B+2
!            chex(5,4,:)  = (/5.27e-1, 0.76,-0.63,-1.17/)! B+3
!            chex(6,1,:)  = (/1.76e-9, 8.33, 4278.78, -6.41/)! C0
!            chex(6,2,:)  = (/1.67e-4, 2.79, 304.72, -4.07/)! C+
!            chex(6,3,:)  = (/3.25   , 0.21, 0.19, -3.29/)! C+2
!            chex(6,4,:)  = (/332.46 ,-0.11,-0.995,-1.58e-3/)! C+3
!            chex(7,1,:)  = (/1.01e-3,-0.29,-0.92, -8.38/)! N0
!            chex(7,2,:)  = (/3.05e-1, 0.60, 2.65, -0.93/)! N+
!            chex(7,3,:)  = (/4.54   , 0.57,-0.65, -0.89/)! N2+
!            chex(7,4,:)  = (/3.28   , 0.52,-0.52, -0.19/)! N3+
!            chex(8,1,:)  = (/1.04   , 3.15e-2, -0.61, -9.73/)! O0
!            chex(8,2,:)  = (/1.04   , 0.27, 2.02, -5.92/)! O+
!            chex(8,3,:)  = (/3.98   , 0.26, 0.56, -2.62/)! O2+
!            chex(8,4,:)  = (/2.52e-1, 0.63, 2.08, -4.16/)! O3+
!            chex(9,2,:)  = (/1.e-5  , 0.  , 0.  , 0./) ! F+
!            chex(9,3,:)  = (/9.86   , 0.29,-0.21,-1.15/) ! F+2
!            chex(9,4,:)  = (/7.15e-1, 1.21,-0.70,-0.85/) ! F3+
!            chex(10,2,:) = (/1.e-5  , 0.  , 0.  , 0.  /) ! Ne+
!            chex(10,3,:) = (/14.73  , 4.52e-2, -0.84, -0.31 /) ! Ne+2
!            chex(10,4,:) = (/6.47   , 0.54 , 3.59 , -5.22 /) ! Ne+3
!            chex(11,2,:) = (/1.e-5  , 0.   , 0.  , 0. /) ! Na+
!            chex(11,3,:) = (/1.33   , 1.15 , 1.20 , -0.32 /)! Na+2
!            chex(11,4,:) = (/1.01e-1, 1.34 , 10.05, -6.41 /)! Na+3
!            chex(12,2,:) = (/8.58e-5, 2.49e-3, 2.93e-2, -4.33 /)! Mg+
!            chex(12,3,:) = (/6.49   , 0.53 , 2.82, -7.63 /) ! Mg+2
!            chex(12,4,:) = (/6.36   , 0.55 , 3.86, -5.19 /) ! Mg+3
!            chex(13,2,:) = (/1.e-5  , 0.   , 0.  , 0./) ! Al+
!            chex(13,3,:) = (/7.11e-5, 4.12 , 1.72e4, -22.24/)! Al+2
!            chex(13,4,:) = (/7.52e-1, 0.77 , 6.24, -5.67/) ! Al+3
!            chex(14,2,:) = (/1.23   , 0.24 , 3.17, 4.18e-3/) ! Si+
!            chex(14,3,:) = (/4.900e-1, -8.74e-2, -0.36, -0.79/)! Si+2
!            chex(14,4,:) = (/7.58   , 0.37 , 1.06, -4.09/)! Si+3
!            chex(16,1,:) = (/3.82e-7, 11.10, 2.57e4, -8.22/)! S0
!            chex(16,2,:) = (/1.e-5  , 0.   , 0.  ,0. /)! S+
!            chex(16,3,:) = (/2.29   , 4.02e-2, 1.59, -6.06/)! S+2
!            chex(16,4,:) = (/6.44   , 0.13 , 2.69 , -5.69/)! S+3
!            chex(18,2,:) = (/1.e-5  , 0.   , 0.  , 0./) ! Ar+
!            chex(18,3,:) = (/4.57   , 0.27 , -0.18 , -1.57/)! Ar+2
!            chex(18,4,:) = (/6.37   , 2.12 , 10.21 , -6.22/)! Ar+3
!            
!            ! BUG NOTE: The following lines for Ca use index 18 (Argon), overwriting the Argon values.
!            ! The index should likely be 20 for Calcium.
!            chex(20,3,:) = (/3.17e-2, 2.12 , 12.06 , -0.40/)! Ca+2
!            chex(20,4,:) = (/2.68   , 0.69 , -0.68 , -4.47/)! Ca+3

!            chex(26,2,:) = (/1.26   , 7.72e-2, -0.41, -7.31/)! Fe+
!            chex(26,3,:) = (/3.42   , 0.51 , -2.06 , -8.99/)! Fe+2.

!            deltaE_k(7,1) = 10863.
!            deltaE_k(8,1) = 2205.

!            chex(:,:,1) = chex(:,:,1)*1.e-9
!            t4 = TeUsed/10000.

!            ! Calculate the ion ratio X(i+1)/X(i) for each species.
!            ! This is the core of the ionization balance, where the ratio of
!            ! ionization rates to recombination rates is computed.
!            do elem = 1, nElements
!                do ion = 1, min(elem, nstages-1)
!                    if (.not.lgElementOn(elem)) exit

!                    ! Calculate temperature-dependent charge exchange rate
!                    chex(elem,ion,1) = chex(elem,ion,1)*(t4**chex(elem,ion,2))*&
!                                     & (1.+chex(elem,ion,3)*exp(chex(elem,ion,4)*t4))

!                    if (chex(elem,ion,1) < 0. ) chex(elem,ion,1) = 0.
!                    if (TeUsed < 6000. .or. TeUsed>5.e4) chex(elem,ion,1) = 0.

!                    nElec = elem - ion +1
!                    call getOuterShell(elem, nElec, outShell, g0, g1)

!                    ! calculate the reverse charge exchange rate
!                    if ( deltaE_k(elem,ion) > 1.) then
!                        revRate = chex(elem,ion,1) * &
!                                & (1.-grid%ionDen(cellP, &
!                                & elementXref(1),1))*grid%Hden(cellP)*&
!                                & 2. * exp(-deltaE_k(elem,ion)/TeUsed)/(real(g0)/real(g1))
!                    else
!                        revRate = 0.
!                    end if

!                    if ( (elem>1) .or. (ion>1) ) collIon = 0.

!                    ! calculate the X(i+1)/X(i) ratio
!                    if (lgDebug) then
!                        ionRatio(elem,ion) = (nPhotoSte(elem,ion)+nPhotoDif(elem,ion)+&
!                                 & collIon+revRate)/&
!                                 & (NeUsed*alphaTot(elem,ion)&
!                                 & +chex(elem,ion,1)*grid%Hden(grid%active(xP,yp,zP)) * &
!                                 & grid%ionDen(cellP,elementXref(1),1))
!                    else
!                        ionRatio(elem,ion) = (nPhotoSte(elem,ion)+&
!                                 & collIon+revRate)/&
!                                 & (NeUsed*alphaTot(elem,ion)&
!                                 & +chex(elem,ion,1)*grid%Hden(grid%active(xP,yp,zP)) * &
!                                 & grid%ionDen(cellP,elementXref(1),1))
!                    end if
!                end do
!            end do

!            ! Calculate the products of ionRatio for each element. This product,
!            ! Prod[X(j+1)/X(j)], gives the ratio X(i+1)/X(0).
!            do elem = 1, nElements
!                do ion = 1, min(elem, nstages-1)
!                   if (.not.lgElementOn(elem)) exit
!                   do i = 1, ion
!                       ionProd(elem, ion) = ionProd(elem,ion)*ionRatio(elem, i)
!                   end do
!                end do
!            end do

!            ! Calculate denominators for final ion abundances.
!            ! The denominator is 1 + Sum[ Prod[X(j+1)/X(j)] ]
!            do elem = 1, nElements
!                do ion = 1, min(elem, nstages-1)
!                    if (.not.lgElementOn(elem)) exit
!                    denominator(elem) = denominator(elem) + ionProd(elem, ion)
!                end do
!            end do

!            ! Calculate the new fractional abundances for all ions.
!            ! X(0) = 1 / denominator
!            ! X(i) = (Prod[...]) / denominator
!            do elem = 1, nElements
!                do ion = 1, min(elem+1, nstages)
!                    if (.not.lgElementOn(elem)) exit
!                    if (ion == 1) then
!                        grid%ionDen(cellP,elementXref(elem),ion) = real(1.0/denominator(elem))
!                    else
!                        grid%ionDen(cellP,elementXref(elem),ion) = &
!                             & real(ionProd(elem, ion-1)/denominator(elem))
!                    end if

!                    if (grid%ionDen(cellP,elementXref(elem),ion) > xMax) &
!                         & grid%ionDen(cellP,elementXref(elem),ion) = xMax
!                    if (grid%ionDen(cellP,elementXref(elem),ion) < 1.e-20) &
!                         & grid%ionDen(cellP,elementXref(elem),ion) = 1.e-20

!                    ionDenUsed(elementXref(elem), ion) = &
!                         & grid%ionDen(cellP,elementXref(elem),ion)
!                    ionDenTemp(cellP,elementXref(elem),ion) = &
!                         & grid%ionDen(cellP,elementXref(elem),ion)
!                end do
!            end do

!            ! Calculate new electron density (Ne) based on the new ion fractions.
!            ! This new Ne will be used in the next iteration.
!            NeUsed = 0.
!            do elem = 1, nElements
!                do ion = 2, min(elem+1, nstages)
!                    if (lgElementOn(elem)) then
!                      if( ionDenUsed(elementXref(elem),ion) >= 1.e-10) &
!                           & NeUsed = NeUsed + (ion-1)*&
!                           &grid%elemAbun(grid%abFileIndex(xP,yP,zP),elem)*&
!                           &ionDenUsed(elementXref(elem), ion)
!                    end if
!                end do
!            end do
!            
!            NeUsed = NeUsed * grid%Hden(cellP)
!            
!            if (NeUsed==0. .and.lgTalk) print*, '! ionBalance [warning]: cell ', xP,yP,zP, &
!                 &'; NeUsed = ',  NeUsed
!            if (NeUsed == 0.) NeUsed = 1.

!            if (LgNeInput) then
!                correction = NeUsed/grid%NeInput(cellP)
!                grid%Hden(cellP) = grid%Hden(cellP)/correction
!            end if

!            NeTemp(cellP) = NeUsed
!            grid%Ne(cellP) = NeUsed

!            ! Calculate the relative change (residuals) in the key ion fractions.
!            deltaHI   = (ionDenUsed(elementXref(1),1) - HIOld)   / HIOld
!            deltaHeI  = (ionDenUsed(elementXref(2),1) - HeIOld)  / HeIOld
!            deltaHeII = (ionDenUsed(elementXref(2),2) - HeIIOld) / HeIIOld
!            
!            !================================================================!
!            ! CONVERGENCE CHECK                                              
!            !================================================================!
!            
!            ! If the changes are small enough, convergence is achieved.
!            if ( (abs(deltaHI) <= limit) .and. (abs(deltaHeI) <= limit) .and. &
!                 (abs(deltaHeII) <= limit) ) then
!                lgConv = .true.
!                EXIT ! Exit the DO loop
!            end if
!            
!            nIterateX = nIterateX + 1
!            
!            ! If the maximum number of iterations is reached, exit the loop.
!            if (nIterateX >= maxIterateX) then
!                if (lgTalk)  print*, "! ionBalance: [warning] convergence not reached after ", &
!                     &maxIterateX, " steps. Finishing up..."
!                lgConv = .false.
!                EXIT ! Exit the DO loop
!            end if
!            
!        END DO ! End of the main iterative loop

!        ! this was added to help MPI implementation
!        NeTemp(cellP) = NeUsed

!      end subroutine ionBalance
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        subroutine calcAlpha()
            implicit none

            real, dimension(nElements, nstages) &
                 &:: diRec  ! total recombination coeffs


            ! zero out alphaTot and contributors
            alphaTot = 0.
            diRec    = 0.

            ! calculate radiative recombination part first
            do elem = 1, nElements
                do ion = 1, min(nstages-1, elem)
                    alphaTot(elem, ion) = radRecFit(elem, elem-ion+1)
                end do
            end do

            call dielectronic(diRec)

            ! calculate dielectronic recombination part
            do elem = 3, nElements
                do ion = 1, min(nstages-1, elem)
                   if (diRec(elem,ion) == 0.) diRec(elem,ion) = diRec(8,ion)

                   ! D-116: the dielectronic rate is a POLYNOMIAL FIT in
                   ! t = Te/1e4,
                   !     1e-12*(a/t + b + c*t + d*t^2)*t^(-3/2)*exp(-f/t),
                   ! and nothing here bounds the temperature it is evaluated
                   ! at. Below the fitted range the a/t term dominates and the
                   ! polynomial goes NEGATIVE: measured alphaTot = -2.54e-10
                   ! for carbon stage 4 at Te = 383 K.
                   !
                   ! Zero is the physically correct floor, not just a
                   ! convenient one - dielectronic capture needs a doubly
                   ! excited state and is exponentially suppressed as Te falls,
                   ! so the true rate there is negligible, never negative.
                   !
                   ! What a negative rate does: alphaTot < 0 makes the
                   ! recombination denominator negative in ionBalance, so the
                   ! stage ratio comes out negative and the chain produces
                   ! NEGATIVE ion fractions. Measured at ~10^6 stage-cells per
                   ! iteration in a 200 kK model. They were never visible
                   ! because the 1e-20 floor at the end of ionBalance catches
                   ! them, so published results were not corrupted - but those
                   ! stages were floored, not computed, and any code that
                   ! divides by the denominator instead of flooring the result
                   ! will hit 0/0 or a sign flip. This is why the fix belongs
                   ! here rather than in whatever consumes it.
                   if (diRec(elem,ion) < 0.) diRec(elem,ion) = 0.

                    alphaTot(elem, ion) = alphaTot(elem, ion) + diRec(elem, ion)
                    if (alphaTot(elem,ion) < 0.) alphaTot(elem,ion) = 0.
                end do
            end do

            ! D-116: report every (element, stage) whose TOTAL recombination
            ! coefficient is zero. A zero alphaTot means the stage above has no
            ! way back down, so ionBalance divides by it: before D-114 that gave
            ! ionUp/0 = +Inf, and the lower stages came out as finite/Inf = 0 -
            ! an ion fraction manufactured by an overflow rather than computed.
            ! Printed once, with the electron count and the branch radRecFit
            ! would have taken, so the cause can be read off directly.
            if (lgAlphaAudit .and. taskid == 0 .and. .not.lgAlphaAudited) then
               lgAlphaAudited = .true.
               print*, "! [D116] recombination audit at Te =", TeUsed, " K"
               do elem = 1, nElements
                  if (.not.lgElementOn(elem)) cycle
                  do ion = 1, min(nstages-1, elem)
                     if (alphaTot(elem,ion) > 0.) cycle
                     print*, "! [D116]   alphaTot = 0 : elem", elem, " stage", ion, &
                          & " n_elec", elem-ion+1, &
                          & "  radRec", radRecFit(elem, elem-ion+1), &
                          & "  diRec", diRec(elem,ion)
                  end do
               end do
               print*, "! [D116] end of audit"
            end if



       end subroutine calcAlpha


       ! This subroutine calculates rates of radiative recombination for all ions
       ! of all elements from H through Zn by use of the following fits:
       ! H-like, He-like, Li-like, Na-like - Verner & Ferland, 1996, ApJS, 103, 467
       ! Other ions of C, N, O, Ne - Pequignot et al. 1991, A&A, 251, 680,
       ! refitted by Verner & Ferland formula to ensure correct asymptotes
       ! Fe XVII-XXIII - Arnaud & Raymond, 1992, ApJ, 398, 394
       ! Fe I-XV - refitted by Verner & Ferland formula to ensure correct asymptotes
       ! Other ions of Mg, Si, S, Ar, Ca, Fe, Ni -
       !                     - Shull & Van Steenberg, 1982, ApJS, 48, 95
       ! Other ions of Na, Al - Landini & Monsignori Fossi, 1990, A&AS, 82, 229
       ! Other ions of F, P, Cl, K, Ti, Cr, Mn, Co (excluding Ti I-II, Cr I-IV,
       ! Mn I-V, Co I)        - Landini & Monsignori Fossi, 1991, A&AS, 91, 183
       ! All other species    - interpolations of the power-law fits
       !  Input parameters: z - atomic number
       !                    n - number of electrons from 1 to z
       ! Output parameter:  radRecFit  - rate coefficient, cm^3 s^(-1)

       function radRecFit(z, n)
            implicit none

            integer, intent(in)             :: z     ! atomic weight of the element
            integer, intent(in)             :: n     ! number of electrons (from 1 to z)


            real                            :: radRecFit    ! rad rate coeff [cm^3/s]

            ! local variables
            integer                              :: elem    ! element counter
            integer                              :: i       ! counter
            integer                              :: ion     ! ion stage counter
            integer                              :: ios     ! I/O error status


            logical, save                        :: lgFirst = .true.
                                                            ! first time this is evaluated?

            real                                 :: tt      ! temp dep fact in interpolation

            real, dimension(2, nElements, nElements),&      ! coefficients for the
                 & save  :: rrec    ! calculation of the
            real, dimension(4, nElements, nElements),&      ! radiative rates
                 & save  :: rnew    !
            real, dimension(3, 4:13), save         :: fe    !

            ! if this is the first time this procedure is called
            ! read in radiative recombination coefficient file
            ! and the dielectronic recombination data
            if (lgFirst) then
                close(17)
                open (unit=17, file=PREFIX//'/share/mocassin/data/radrec.dat', status='old',position='rewind', iostat = ios, action="read")

                do ion = 4, 30
                    if (ion /= 11) then
                        do elem = ion, 30
                            if ( (elem /= 26) .or. (ion >= 14) ) then
                                read(unit=17, fmt=*, iostat=ios) (rrec(i,elem,ion), i=1,2)
                            end if
                        end do
                    end if
                end do

                do ion = 1, 3
                    do elem = ion, 30
                        read(unit=17, fmt=*, iostat=ios) (rnew(i,elem,ion), i=1,4)
                    end do
                end do

                do elem = 11, 30
                   read(unit=17, fmt=*, iostat=ios) (rnew(i,elem,11), i=1,4)
                end do

                do ion = 4, 10
                    do elem = max(6,ion), 8
                        read(unit=17, fmt=*, iostat=ios) (rnew(i,elem,ion), i=1,4)
                    end do
                    read(unit=17, fmt=*, iostat=ios) (rnew(i,10,ion), i=1,4)
                end do

                do ion = 12, 26
                    read(unit=17, fmt=*, iostat=ios) (rnew(i,26,ion), i=1,4)
                end do

                ! close the files
                close(17)

                ! set data for Fe
                fe(1,:) = (/4.33e-10,3.91e-10,3.49e-10,3.16e-10,&
                     &2.96e-10,2.59e-10,2.24e-10,1.91e-10,1.68e-10,1.46e-10/)
                fe(2,:) = (/0.531,0.523,0.521,0.534, &
                     &0.557,0.567,0.579,0.601,0.602,0.597/)
                fe(3,:) = (/5.77e-02,6.15e-02,6.22e-02,6.02e-02,&
                     &5.79e-02,5.65e-02,5.49e-02,5.10e-02,5.07e-02,5.22e-02/)

                ! set lgFirst to .false.
                lgFirst = .false.
            end if

            ! check right element and number of electron reference
            if ( (z<1) .or. (z>30) ) then
                print*, "! radRecFit: insane atomic number", z
                stop
            end if
            if ( (n<1) .or. (n>z) ) then
                print*, "! radRecFit: insane number of electrons", n
                stop
            end if

            ! calculate the rates
            if ( (n<=3) .or. (n==11) .or. ((z>5) .and. (z<9)) .or. (z==10) .or.&
                 &((z==26) .and. (n>11)) ) then

                tt = sqrt(TeUsed/rnew(3,z,n))
                radRecFit = rnew(1,z,n) / (tt*(tt+1.)**(1.-rnew(2,z,n))*&
                     &(1.+sqrt(TeUsed/rnew(4,z,n)))**(1.+rnew(2,z,n)))
            else
               tt = TeUsed*1.e-4
               if ( (z==26) .and. (n<=13) ) then
                   radRecFit = fe(1,n)/tt**(fe(2,n)+fe(3,n)*log10(tt))
               else
                   radRecFit = rrec(1,z,n)/tt**rrec(2,z,n)
               end if
            end if

        end function radRecFit

        subroutine dielectronic(diRec)
            implicit none

            real, intent(out), dimension(nElements, nstages) :: diRec   ! total recombination coeffs

            ! local variables

            integer                             :: ion
            real                                :: t         ! t = TeUsed/10000., t0,t1 are fitting par
            real                                :: alpha
            real, dimension(nElements, nstages) :: aldroPequi! high T dielec rec coeff by A&P73

            aldroPequi = 0.

            t = TeUsed/10000.

            alpha = 0.
            aldroPequi=0.

            do i = 1, size(direc_coeffs)
               ion = direc_coeffs(i)%elem + 1 - direc_coeffs(i)%n

               if (ion <= nstages) then

        	  if (ion == 1) then
                     diRec(direc_coeffs(i)%elem, ion) = 0.
                  else if (direc_coeffs(i)%g == 0) then
                     diRec(direc_coeffs(i)%elem, ion) = (10.**(-12))*(direc_coeffs(i)%a/t+direc_coeffs(i)%b+direc_coeffs(i)%c*t+direc_coeffs(i)%d*t**2)*t**(-3./2.)*exp(-direc_coeffs(i)%f/t)
                  else if (direc_coeffs(i)%g == 1 .and. TeUsed .lt. 20000.) then
                     diRec(direc_coeffs(i)%elem, ion) = (10.**(-12))*(direc_coeffs(i)%a/t+direc_coeffs(i)%b+direc_coeffs(i)%c*t+direc_coeffs(i)%d*t**2)*t**(-3./2.)*exp(-direc_coeffs(i)%f/t)
                  else if (direc_coeffs(i)%g == 2 .and. TeUsed .ge. 20000.) then
                     diRec(direc_coeffs(i)%elem, ion) = (10.**(-12))*(direc_coeffs(i)%a/t+direc_coeffs(i)%b+direc_coeffs(i)%c*t+direc_coeffs(i)%d*t**2)*t**(-3./2.)*exp(-direc_coeffs(i)%f/t)
                  end if
               end if
            end do

            ! calculate the high temperatures dielectronic recombination coeficients of
            ! Aldrovandi and Pequignot 1973
            t = TeUsed

            do i = 1, size(aldropequi_coeffs)
               ion = aldropequi_coeffs(i)%elem + 1 - aldropequi_coeffs(i)%n
               alpha = aldropequi_coeffs(i)%a*t**(-3./2.)*exp(-aldropequi_coeffs(i)%t0/t)*(1.+aldropequi_coeffs(i)%b*exp(-aldropequi_coeffs(i)%t1/t))
               if (ion <= nstages) aldroPequi(aldropequi_coeffs(i)%elem, ion) = alpha
            end do

            if (TeUsed>60000.) then
               diRec = aldroPequi
            else
               where (direc .eq. 0.)
                 diRec = aldroPequi
               endwhere
            end if

          end subroutine dielectronic

         subroutine getDustT()
            implicit none

            real                   :: dustAbsIntegral   ! dust absorption integral
            real                   :: dabs
            real                   :: resLineHeat       ! resonance line heating
            real, dimension(nbins) :: radField          ! radiation field

            integer :: nS, i, ai ! counters
            integer :: iT        ! pointer to dust temp in dust temp array
            integer :: global_nS ! pointer index for dust component
            ! D-126: recomputation of the collisional term at the probe point
            real    :: kTchk, psichk, etachk, xichk, vmchk, collchk
#ifdef PDR
            integer :: nS2, ai2          ! D-093: cross-section normalisation
            real    :: xsecTot           ! total grain cross-section per unit volume [1/cm]
            real    :: ggPerGrain, pePerGrain, ggpeLoss
            logical :: lgPDRcell
#endif

            ! radiation field at this location
            if (lgDebug) then
               radField = ((grid%Jste(cellP,:) + grid%Jdif(cellP,:)))/Pi
            else
               radField = grid%Jste(cellP,:)/Pi
            end if

            ! zero out dust temperature arrays
            grid%Tdust(:,:,cellP) = 0.
            if (lgforceTDust) then ! BEKS2010
               grid%Tdust(:,:,cellP) = forceTDust
               return
            endif

#ifdef PDR
            ! D-093: in PDR cells MOCASSIN's own gas-grain and photoelectric
            ! terms are built from its ION inventory - every H nucleus counted
            ! as a free atom, no H2 at all - which is the wrong description of
            ! the gas there. The PDR solves both properly, so use its rates.
            ! They are volumetric (erg cm^-3 s^-1); the dust balance wants
            ! erg s^-1 per grain, and both processes scale with grain area, so
            ! spread them over the population by cross-section. That makes
            ! SUM_grains n(ns,ai)*rate(ns,ai) equal the volumetric rate again.
            lgPDRcell = .false.
            xsecTot   = 0.
            if (lgPDR) then
               ! D-182: no zone gate here either. The PDR's grain-surface
               ! rates are computed in every cell under pdrAllCells; outside
               ! the molecular gas they are negligible on their own and need no
               ! threshold to switch them off. Gating introduced a step at
               ! pdrZoneLim for no physical gain.
               if (pdrDustFeedback /= 0 .and. grid%Ndust(cellP) > 0. &
                    & .and. (pdrCoolZoneGate == 0 .or. grid%pdrZone(cellP) == 1)) then
                  do nS2 = 1, nSpeciesPart(nspU)
                     if (grainAbun(nspU, nS2) <= 1.e-20) cycle
                     do ai2 = 1, nSizes
                        if (grainRadius(ai2) >= componentMinRadius(nspU, nS2) .and. &
                           & grainRadius(ai2) <= componentMaxRadius(nspU, nS2)) then
                           xsecTot = xsecTot + grainWeight(ai2)*grainAbun(nspU,nS2)*&
                                & Pi*grainRadius(ai2)*grainRadius(ai2)*1.e-8
                        end if
                     end do
                  end do
                  xsecTot = xsecTot*grid%Ndust(cellP)
                  if (xsecTot > 0.) lgPDRcell = .true.
               end if
            end if
#endif

            ! calculate absorption integrals for each species
            do nS = 1, nSpeciesPart(nspU)

               ! CALCULATE THE GLOBAL INDEX
               global_nS = dustComPoint(nspU) + nS - 1 

               ! Only proceed with calculations if the grain species actually exists in this cell.
               if (grainAbun(nspU, nS) > 1.e-20) then

               do ai = 1, nSizes

                  if (grainRadius(ai) >= componentMinRadius(nspU, ns) .and. grainRadius(ai) <= componentMaxRadius(nspU, ns)) then
                  
                     dustAbsIntegral=0.

                     ! D-127. dabs and resLineHeat are written only under their
                     ! own guards (trace heating, and resonance line transfer),
                     ! so anything that reads them outside those guards - the
                     ! probes in this routine did - gets a stack slot. Zero them
                     ! unconditionally: they are cheap, and it makes a read
                     ! outside the guard mean what it appears to mean.
                     dabs = 0.
                     resLineHeat = 0.

                     do i = 1, nbins
                        dustAbsIntegral = dustAbsIntegral+xSecArray(dustAbsXsecP(global_nS,ai)+i-1)*radField(i)
                        if (lgTraceHeating.and.taskid==0) then
                           dabs = dabs+xSecArray(dustAbsXsecP(global_nS,ai)+i-1)*radField(i)
                        end if
                     end do

                     if (lgGas .and. convPercent>=resLinesTransfer .and. (.not.lgResLinesFirst) .and. &
                          & (.not.nIterateMC==1) ) then
                        dustHeatingBudget(grid%abFileIndex(xp,yp,zp),0) = dustHeatingBudget(grid%abFileIndex(xp,yp,zp),0)+&
                             & dustAbsIntegral*grainWeight(ai)*grainAbun(nspU,nS)*grid%Ndust(cellP)
                        dustHeatingBudget(0,0) = dustHeatingBudget(0,0)+&
                             & dustAbsIntegral*grainWeight(ai)*grainAbun(nspU,nS)*grid%Ndust(cellP)
                        resLineHeat = resLineHeating(ai,ns,nspU)
                        dustAbsIntegral = dustAbsIntegral+resLineHeat
                     end if

#ifdef PDR
                     if (lgPDRcell) then
                        ! pdrHeatGG > 0 means the dust is heating the gas, so
                        ! the dust loses it; pdrHeatPE is FUV energy the grain
                        ! absorbed and shed as photoelectrons rather than
                        ! re-radiating, so it leaves the grain budget too.
                        ggPerGrain = grid%pdrHeatGG(cellP)*&
                             & Pi*grainRadius(ai)*grainRadius(ai)*1.e-8/xsecTot
                        pePerGrain = grid%pdrHeatPE(cellP)*&
                             & Pi*grainRadius(ai)*grainRadius(ai)*1.e-8/xsecTot
                        ! A grain cannot shed more energy than it absorbed. Without
                        ! this cap the balance has no solution and the temperature
                        ! interpolation extrapolates straight through zero - two
                        ! cells of the V1 slab came back at -4850 K and -1191 K.
                        ! Hitting the cap is diagnostic, not cosmetic: it means the
                        ! PDR's photoelectric heating exceeds what MOCASSIN's grains
                        ! absorbed, which is the PAH inconsistency of D-093 showing
                        ! up - the PDR assumes a PAH population the dust inventory
                        ! does not carry. Counted and reported rather than hidden.
                        ggpeLoss = ggPerGrain + pePerGrain
                        if (ggpeLoss > 0.9*dustAbsIntegral) then
                           ggpeLoss = 0.9*dustAbsIntegral
                           nDustCapped = nDustCapped + 1
                        end if
                        dustAbsIntegral = dustAbsIntegral - ggpeLoss
                     else if (lgGas .and. lgPhotoelectric) then
                        dustAbsIntegral = dustAbsIntegral+gasDustColl_d(nS,ai)-&
                             & photoelHeat_d(nS,ai)
#else
                     if (lgGas .and. lgPhotoelectric) then
                        dustAbsIntegral = dustAbsIntegral+gasDustColl_d(nS,ai)-&
                             & photoelHeat_d(nS,ai)
#endif
                     end if

                     if (lgTraceHeating.and.taskid==0) then
                        write(57,*) 'Dust Species: ', ns, ai
                        write(57,*) 'Abs of cont rad field  ', dabs
                        write(57,*) 'Res Lines Heating: ', reslineheat
                        if (lgGas .and. lgPhotoelectric) then

                           write(57,*) 'Grain potential ', grainPot(global_nS,ai)
                           write(57,*) 'Gas-dust collision heat', gasDustColl_d(nS,ai)
                           write(57,*) 'Photoelctric cooling: ', photoelHeat_d(nS,ai)
                        end if
                     end if

                     ! D-120: an intermittent NaN reaches T_dust and, because
                     ! NaN fails every comparison, reads as "all grains
                     ! sublimed" in pathSegment and hard-stops the run. It is
                     ! realisation-dependent, so a clean run proves nothing.
                     ! Report the first non-finite integral with the terms that
                     ! build it, once, so the source is read rather than
                     ! guessed at.
                     if (.not.(dustAbsIntegral == dustAbsIntegral) .and. &
                         & nDustNaN == 0) then
                        nDustNaN = 1
                        print*, "! [D120] non-finite dustAbsIntegral at cell", cellP, &
                             & " species", nS, " size", ai
                        print*, "! [D120]   dabs =", dabs, "  reslineheat =", reslineheat
#ifdef PDR
                        print*, "! [D120]   pdrHeatPE =", grid%pdrHeatPE(cellP), &
                             & "  pdrHeatGG =", grid%pdrHeatGG(cellP)
                        print*, "! [D120]   pdrZone =", grid%pdrZone(cellP), &
                             & "  Tgas =", grid%pdrTgas(cellP), "  Ne =", NeUsed
#endif
                     end if

                     call locate(dustEmIntegral(global_nS,ai,:), dustAbsIntegral, iT)

                     if (iT<=0 .and. lgTalk) then
                        print*, "getDustT: [warning] temperature of grain = 0. K!!!!"
                        print*, cellP
                        print*, nS, dustAbsIntegral
                        print*, dustEmIntegral(global_nS,ai,1)
                        !stop
                        iT=1
                        grid%Tdust(nS,ai,cellP) = 1.
                     else if (iT>=nTemps) then
                        grid%Tdust(nS,ai,cellP) = real(nTemps)
                     else if (dustEmIntegral(global_nS,ai,iT+1) <= &
                            & dustEmIntegral(global_nS,ai,iT)) then
                        ! DEVLOG D-109. The linear interpolation below divides by
                        ! the width of the bracketing interval in the emission
                        ! table, and nothing checked that width was non-zero.
                        ! Where a cell has absorbed almost nothing the table is
                        ! flat - neighbouring entries underflow to the same value
                        ! - and the quotient explodes: a corner cell of the
                        ! ifront benchmark produced T_dust = 2.3e9 K.
                        !
                        ! That is not merely a wrong number in a diagnostic. Any
                        ! size above TdustSublime is DROPPED from absOpac and
                        ! from the dust emission, so one degenerate interval
                        ! silently deletes grains from the cell - which is how a
                        ! cell came to carry 30% less V-band opacity than its
                        ! neighbours at identical Ndust.
                        !
                        ! A flat interval carries no information about where in
                        ! it the answer lies, so take the bracket itself.
                        grid%Tdust(nS,ai,cellP) = real(iT)
                     else
                        !if(nspU == 2) print*, nspU,nS,ai,iT, grainAbun(nspU,nS), dustAbsIntegral, xSecArray(dustAbsXsecP(global_nS,ai)+i-1)
                        grid%Tdust(nS,ai,cellP) = real(iT) + &
                             & (dustAbsIntegral-dustEmIntegral(global_nS,ai,iT))*&
                             & (real(iT+1)-real(iT))/(dustEmIntegral(global_nS,ai,iT+1)-&
                             & dustEmIntegral(global_nS,ai,iT))
                     end if

                     if (lgTraceHeating.and.taskid==0) then
                        write(57,*) 'Radiative cooling: ', dustEmIntegral(global_nS,ai,iT)
                        write(57,*) 'Grain temperature: ', grid%Tdust(nS,ai,cellP), &
                             & " species ", grainLabel(nS), " size:", grainRadius(ai)

                     end if

                     if (lgTalk) &
                          & print*, "! getDustT: [talk] cell ", xP,yP,zP,"; Grain temperature: "&
                          &, grid%Tdust(nS,ai,cellP), " species ", grainLabel(global_nS), " size:", grainRadius(ai)

                     ! D-122: a grain above its sublimation point is dropped
                     ! from the opacity, and a cell where EVERY size is gone
                     ! hard-stops pathSegment. Measured behaviour: cell 3 of the
                     ! sec5.4 fixture sits at 82 K in every completed run and
                     ! reached 1451 K in one crashed realisation - a factor 1e7
                     ! in absorbed energy, which is not Monte Carlo noise.
                     ! Report the terms so the excursion is read, not guessed.
                     if (grid%Tdust(nS,ai,cellP) >= &
                          & TdustSublime(dustComPoint(nspU)+nS-1) .and. &
                          & nDustHot < maxDustHot) then
                        nDustHot = nDustHot + 1
                        print*, "! [D122] grain over sublimation at cell", cellP, &
                             & " species", nS, " size", ai, " T =", &
                             & grid%Tdust(nS,ai,cellP)
                        print*, "! [D122]   dustAbsIntegral =", dustAbsIntegral, &
                             & "  dabs =", dabs, "  resLineHeat =", resLineHeat
                        print*, "! [D122]   iT =", iT, "  emInt(iT) =", &
                             & dustEmIntegral(global_nS,ai,min(max(iT,1),nTemps)), &
                             & "  Ndust =", grid%Ndust(cellP)
                        ! Measured: dabs is in the normal range (2.8e-12, i.e.
                        ! a ~80 K grain) while the integral is 44.7, so the
                        ! excess is entirely the gas-grain / photoelectric
                        ! pair. Print both, with the quantities they are built
                        ! from, so the 1e13 discrepancy is attributed rather
                        ! than inferred. Ndust is uniform in these models, so
                        ! it is not a dust-free-cell effect.
                        if (lgGas .and. lgPhotoelectric) then
                           print*, "! [D122]   gasDustColl_d =", gasDustColl_d(nS,ai), &
                                & "  photoelHeat_d =", photoelHeat_d(nS,ai)
                           print*, "! [D122]   grainPot =", grainPot(global_nS,ai), &
                                & "  Ne =", NeUsed, "  Te =", TeUsed, &
                                & "  Tdust(nS,ai) =", grid%Tdust(nS,ai,cellP)
                           ! D-126: rebuild the electron half of the collisional
                           ! term from the state as it stands here.
                           ! setDustGasCollHeatCool ran earlier in this same
                           ! updateCell call, so a stored value orders of
                           ! magnitude above a sane recomputation is stale or
                           ! corrupt data rather than a formula misbehaving.
                           ! This lives in getDustT deliberately: instrumenting
                           ! setDustGasCollHeatCool suppressed the fault
                           ! (D-125), while every build that fires already
                           ! carries a probe here.
                           kTchk  = 6.336e-6*TeUsed
                           psichk = -grainPot(global_nS,ai)/kTchk
                           if (psichk <= 0.) then
                              etachk = 1.-psichk
                              xichk  = 1.-psichk/2.
                           else
                              etachk = exp(-psichk)
                              xichk  = (1.+psichk/2.)*etachk
                           end if
                           vmchk = sqrt((1.1045e-15)*TeUsed/Pi/me)
                           collchk = NeUsed*Pi*grainRadius(ai)*grainRadius(ai)*&
                                & 1.e-8*vmchk*(2.*kTchk*Ryd2erg*xichk + &
                                & etachk*grainPot(global_nS,ai)*Ryd2erg)/fourPi
                           print*, "! [D126] recomputed e- term =", collchk, &
                                & "  stored gasDustColl_d =", gasDustColl_d(nS,ai), &
                                & "  ratio =", gasDustColl_d(nS,ai)/max(collchk,1.e-30)
                           print*, "! [D126] max over all (ns,ai) =", &
                                & maxval(gasDustColl_d), "  min =", minval(gasDustColl_d)
                        end if
#ifdef PDR
                        if (lgPDR) print*, "! [D122]   pdrZone =", &
                             & grid%pdrZone(cellP), "  pdrHeatPE =", &
                             & grid%pdrHeatPE(cellP), "  pdrHeatGG =", &
                             & grid%pdrHeatGG(cellP), "  xsecTot =", xsecTot
#endif
                     end if

                     ! find weighted mean
                     grid%Tdust(nS,0,cellP) = grid%Tdust(nS,0,cellP)+&
                          & grid%Tdust(nS,ai,cellP)*grainWeight(ai)
                          
                  endif

               end do

               grid%Tdust(0,0,cellP) = grid%Tdust(0,0,cellP)+&
                    & grid%Tdust(nS,0,cellP)*grainAbun(nspU,nS)
                    
               endif ! *** END OF IF for zero grain abundance ***

            end do


          end subroutine getDustT

          function resLineHeating(sizeP,speciesP, icompP)
            implicit none

            real                :: resLineHeating ! dust heating due to res lines

            real                :: Gline   ! energy is the line [erg sec^-1]
            real                :: heat    ! sub calculation var

            integer, intent(in) :: sizeP   ! size pointer
            integer, intent(in) :: speciesP! species pointer
            integer, intent(in) :: icompP! dust componenent pointer

            integer             :: iL      ! line counter
            integer             :: imul    ! multiplet counter

            integer               :: global_speciesP ! DECLARE GLOBAL INDEX

            ! Calculate the correct global index for the species
            global_speciesP = dustComPoint(icompP) + speciesP - 1

            resLineHeating = 0.
            do iL = 1, nResLines

               Gline = 0.
               do imul = 1, resLine(iL)%nmul
                  if (resLine(iL)%elem==1) then

                     if ( resLine(iL)%ion == 1 .and. resLine(iL)%moclow(imul)==1 .and. resLine(iL)%mochigh(imul)==2 ) then

                        ! fits to Storey and Hummer MNRAS 272(1995)41
                        Gline = Gline + 10**(-0.897*log10(TeUsed) + 5.05)*grid%elemAbun(grid%abFileIndex(xP,yP,zP),1)&
                             & *1.e-25*ionDenUsed(elementXref(1),2)*&
                             & NeUsed

                     else

                        print*, "! resLineHeating: [warning] only dust &
                             &heating from H Lyman alpha and resonance lines from heavy"
                        print*, "elements is implemented in this version. please contact author B. Ercolano -1-", &
                             &iL, resLine(iL)%elem, &
                             & resLine(iL)%ion

                     end if

                  else if (resLine(iL)%elem>2) then

                     Gline = Gline+real(forbiddenLines(resLine(iL)%elem,resLine(iL)%ion, &
                          &resline(iL)%moclow(imul), resline(iL)%mochigh(imul)))

                  else

                     print*, "! resLineHeating: [warning] only dust heating from H ",&
                          &"Lyman alpha and resonance lines from heavy"
                     print*, "elements is implemented in this version. please contact author B. Ercolano -2-", &
                          &iL, resLine(iL)%elem, &
                             & resLine(iL)%ion

                  end if


               end do

               Gline=Gline/Pi

               heat = Gline*grid%Hden(cellP)* &
                    & (1.-grid%fEscapeResPhotons(cellP, iL))*&
                    & xSecArray(dustAbsXSecP(global_speciesP,sizeP)+resLine(iL)%nuP-1)/&
                    & (grid%Ndust(cellP)*&
                    & absOpacSpecies(global_speciesP,resLine(iL)%nuP))

               ! Harrington Monk and Clegg 1988 (section 3.2)
               resLineHeating = resLineHeating + heat

               dustHeatingBudget(grid%abFileIndex(xP,yP,zP),iL) = &
                    & dustHeatingBudget(grid%abFileIndex(xP,yP,zP),iL) + &
                    & heat*grainWeight(sizeP)*grainAbun(icompP,speciesP)*grid%Ndust(cellP)
               dustHeatingBudget(0,iL) = dustHeatingBudget(0,iL) + &
                    & heat*grainWeight(sizeP)*grainAbun(icompP,speciesP)*grid%Ndust(cellP)


            end do

          end function resLineHeating


        end subroutine updateCell

#ifdef PDR
        ! D-280: the grain albedo that sets the cosmic-ray-induced photorates,
        ! RATE = alpha*zeta*gamma/(1-omega) (Gredel et al. 1989, as
        ! calc_reac_rates.F90 evaluates CRPHOT). The photons are H2 Lyman-Werner
        ! emission, so the albedo is this cell's own, scaOpac/(absOpac+scaOpac)
        ! over the 11.2-13.6 eV bins weighted by bin width. It replaces 3D-PDR's
        ! fixed omega = 0.42: MOCASSIN has the grains.
        real function grainAlbedoLW(grid, cellP)
            implicit none
            type(grid_type), intent(in) :: grid
            integer, intent(in)         :: cellP
            integer          :: j
            double precision :: sA, sS
            sA = 0.d0; sS = 0.d0
            grainAlbedoLW = 0.
            if (.not. lgDust .or. cellP <= 0) return
            do j = 1, nbins
               if (nuArray(j) < nuLWlo .or. nuArray(j) >= nuFUVhi) cycle
               sA = sA + dble(grid%absOpac(cellP,j))*dble(widFlx(j))
               sS = sS + dble(grid%scaOpac(cellP,j))*dble(widFlx(j))
            end do
            if (sA + sS > 0.d0) grainAlbedoLW = real(sS/(sA + sS))
        end function grainAlbedoLW
#endif

end module update_mod

