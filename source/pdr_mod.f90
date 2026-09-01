! MOCASSIN <-> 3D-PDR bridge (DEVLOG D-005, D-021, D-022).
!
! Everything that crosses between the two codes goes through here. Four entry
! points, matching the plan:
!
!   initPDR(grid)        - resolve data paths, validate the network, read it,
!                          allocate the PDR grid fields and seed abundances
!   mocassinToPDR(grid)  - MC radiation field -> chi, A_V,eff, zone flag
!   pdrStep(grid,i,j,k)  - one cell of chemistry + thermal balance   [Phase 4]
!   pdrToMocassin(grid)  - abundances and T_gas back into the grid   [Phase 4]
!
! Two rules apply to every import in this file:
!
!   1. Explicit `only:` lists, never a blanket `use`. 3D-PDR's modules export
!      names as generic as i, j, k, p, NH, NC (DEVLOG D-021).
!   2. Rename on import where the name also exists in common_mod. Four do:
!      input, mass, rate, species.
!
module pdr_mod
#ifdef PDR

    use common_mod
    use constants_mod
    use continuum_mod, only : inSpectrumProbDen

    ! KB and PC are 3D-PDR's own constants; use theirs rather than MOCASSIN's
    ! equivalents so the level-population arithmetic matches upstream exactly.
    use healpix_types, only : KB, PC

    use maincode_module, only : pdrNspecMod  => nspec,      &
                              & pdrNreacMod  => nreac,      &
                              & pdrSpecies   => species,    &
                              & pdrMass      => mass,       &
                              & pdrRate      => rate,       &
                              & pdrInitAbun  => init_abundance, &
                              & pdrReactant  => reactant,   &
                              & pdrProduct   => product,    &
                              & pdrAlpha     => alpha,      &
                              & pdrBeta      => beta,       &
                              & pdrGamma     => gamma,      &
                              & pdrDuplicate => duplicate,  &
                              & pdrRtmin     => rtmin,      &
                              & pdrRtmax     => rtmax,      &
                              & pdrAVfacMod  => AV_fac,     &
                              & pdrUVfacMod  => UV_fac,     &
                              & pdrZetaMod   => zeta,       &
                              & pdrVturbMod  => v_turb,     &
                              & pdrCooMod    => coo,        &
                              & pdrCoolfile  => coolfile,   &
                              & pdrStartTime => start_time, &
                              & pdrEndTimeMod=> end_time,   &
                              & pdrRedshift  => redshift,   &
                              & pdrTcmb      => Tcmb,       &
                              & pdrTminMod   => Tmin,       &
                              & pdrTmaxMod   => Tmax,       &
                              & pdrLevel     => level,      &
                              & pdrChemPath  => chemPath,  &
                              & pdrTdustMod  => dust_temperature, &
                              & pdrCoolant2  => coolant

    ! Species indices come from global_module. NH2/NC/NCO do not collide with
    ! anything in common_mod, so they are imported under their own names.
    use global_module,    only : pdrMetalMod  => metallicity, &
                               & pdrOmega     => omega,       &
                               & pdrGrainRadM => grain_radius, &
                               & pdrNelect    => NELECT,      &
                               & NH2, NC, NCO, NH, NPROTON, NHe, NHEx, &
                               & NCx, NO, NOx, NMG, NMGx

    use chemistry_module, only : pdrRelTol => relative_abundance_tolerance, &
                               & pdrAbsTol => absolute_abundance_tolerance

    ! CALC_HEATING's chemical-heating term needs this module's reaction indices
    ! built first; without it the term reads unset state (DEVLOG D-029).
    use chemical_heating_module, only : init_chemical_heating

    implicit none

    private
    public :: initPDRnetwork, seedPDR, calibratePDRdust, computeAVdust, &
            & mocassinToPDR, pdrStep, pdrToMocassin

    contains

      !-----------------------------------------------------------------
      ! Set up the chemistry: resolve where the data lives, check that the
      ! requested network is the one that was compiled in, read it, then
      ! allocate and seed the per-cell PDR state.
      !-----------------------------------------------------------------
      subroutine initPDRnetwork()
        implicit none

        character(len=20)  :: builtNetwork
        character(len=200) :: dataDir
        character(len=250) :: fname
        integer            :: ios, iS
        double precision   :: dummy

        ! ---- which network is actually compiled in? ---------------------
        ! The ODE right-hand side is generated C, selected at compile time, so
        ! pdrNetwork can only validate - it cannot switch anything (D-003).
#ifdef REDUCED
        builtNetwork = 'reduced'
#elif MEDIUM
        builtNetwork = 'medium'
#elif FULL
        builtNetwork = 'full'
#elif MYNETWORK
        builtNetwork = 'mynetwork'
#else
        builtNetwork = 'none'
#endif
        if (trim(adjustl(pdrNetwork)) /= trim(adjustl(builtNetwork))) then
           print*, "! initPDR: requested network '", trim(adjustl(pdrNetwork)), &
                & "' but this binary was built with '", trim(adjustl(builtNetwork)), "'."
           print*, "!   The ODE system is generated C chosen at compile time, so the"
           print*, "!   network cannot be switched at run time. Rebuild with"
           print*, "!   NETWORK=", trim(adjustl(pdrNetwork)), " or set pdrNetwork accordingly."
           stop
        end if

        ! ---- where the chemistry data lives (D-022) ---------------------
        if (len_trim(pdrDataDir) > 0) then
           dataDir = trim(adjustl(pdrDataDir))
        else
           dataDir = PREFIX//"/share/mocassin/dataPDR"
        end if
        ! the vendored readers concatenate directly, so keep the separator here
        pdrChemPath = trim(adjustl(dataDir))//"/"

        ! ---- count species and reactions --------------------------------
        fname = trim(adjustl(pdrChemPath))//"species_"//trim(adjustl(pdrNetwork))//".d"
        close(81)
        open(unit=81, file=fname, status='old', action='read', iostat=ios)
        if (ios /= 0) then
           print*, "! initPDR: cannot open ", trim(fname)
           print*, "!   set pdrDataDir, or run 'make install' to place dataPDR/ under PREFIX."
           stop
        end if
        pdrNspec = 0
        do
           read(81,*,iostat=ios) dummy
           if (ios /= 0) exit
           pdrNspec = pdrNspec + 1
        end do
        close(81)

        fname = trim(adjustl(pdrChemPath))//"rates_"//trim(adjustl(pdrNetwork))//".d"
        open(unit=81, file=fname, status='old', action='read', iostat=ios)
        if (ios /= 0) then
           print*, "! initPDR: cannot open ", trim(fname)
           stop
        end if
        pdrNreac = 0
        do
           read(81,*,iostat=ios) dummy
           if (ios /= 0) exit
           pdrNreac = pdrNreac + 1
        end do
        close(81)

        pdrNspecMod = pdrNspec
        pdrNreacMod = pdrNreac

        ! ---- parameters readparams would have supplied (D-022) ----------
        pdrMetalMod   = dble(pdrMetal)
        pdrGrainRadM  = dble(pdrGrainRad)
        pdrOmega      = 0.42d0                      ! grain albedo, hardcoded upstream
        pdrAVfacMod   = dble(pdrAVfac)*dble(pdrMetal)
        pdrUVfacMod   = dble(pdrUVfac)
        pdrZetaMod    = dble(pdrZeta)/1.3d-17       ! stored normalised, as upstream
        pdrRedshift   = 0.0d0
        pdrTcmb       = 2.725d0*(1.0d0+pdrRedshift)
        pdrVturbMod   = dble(pdrVturb)*1.0d5        ! km/s -> cm/s
        pdrTminMod    = max(dble(pdrTmin), pdrTcmb)
        pdrTmaxMod    = dble(pdrTmax)
        pdrLevel      = pdrHealpix
        pdrStartTime  = 0.0d0
        pdrEndTimeMod = dble(pdrEndTime)
        pdrRelTol     = 1.0d-8
        pdrAbsTol     = 1.0d-30

        ! Coolant datafiles. readcoolants allocates coolant(1:coo), which
        ! read_species then indexes (read_species.F90:175) - so it must run
        ! FIRST, matching upstream 3DPDR.F90's ordering.
        do iS = 1, pdrNcool
           if (len_trim(adjustl(pdrChemPath))+len_trim(adjustl(pdrCoolant(iS))) &
                & > len(pdrCoolfile(iS))) then
              print*, "! initPDR: coolant path too long for the buffer -"
              print*, "!   ", trim(adjustl(pdrChemPath))//trim(adjustl(pdrCoolant(iS)))
              print*, "!   shorten pdrDataDir, or widen coolfile in source/pdr/modules.F90"
              stop
           end if
           pdrCoolfile(iS) = trim(adjustl(pdrChemPath))//trim(adjustl(pdrCoolant(iS)))
        end do
        pdrCooMod = pdrNcool
        if (pdrNcool > 0) call readcoolants

        ! Pack every coolant's levels into one per-cell array. Offsets are
        ! computed once so pdrStep can slice it without a ragged structure.
        pdrNlevTot = 0
        do iS = 1, pdrNcool
           pdrLevOff(iS) = pdrNlevTot
           pdrNlevTot = pdrNlevTot + pdrCoolant2(iS)%cnlev
           pdrMaxLev  = max(pdrMaxLev, pdrCoolant2(iS)%cnlev)
        end do

        ! ---- read the network -------------------------------------------
        call allocations
        call read_species(pdrNspecMod, pdrSpecies, pdrInitAbun, pdrMass)
        call READ_RATES(pdrNreacMod, pdrReactant, pdrProduct, pdrAlpha, pdrBeta, &
             &          pdrGamma, pdrRate, pdrDuplicate, pdrRtmin, pdrRtmax)

        ! Identify the exothermic chemical-heating reactions in this network.
        ! 3DPDR.F90 does this immediately after READ_RATES; omitting it leaves
        ! CHEMICAL_HEATING_RATE working on uninitialised indices (D-029).
        call init_chemical_heating(pdrNreacMod, pdrReactant, pdrProduct, &
             &                     pdrNspecMod, pdrSpecies)

        if (taskid == 0) then
           print*, "! initPDR: network '", trim(adjustl(pdrNetwork)), "' - ", &
                & pdrNspec, " species, ", pdrNreac, " reactions"
           print*, "! initPDR: chemistry data from ", trim(adjustl(pdrChemPath))
           print*, "! initPDR: ", pdrNcool, " coolants loaded, ", &
                & pdrNlevTot, " levels in total"
        end if

      end subroutine initPDRnetwork


      !-----------------------------------------------------------------
      ! Seed a fresh grid with the network's initial abundances. The arrays
      ! themselves are allocated in grid_mod alongside every other per-cell
      ! field, so that resetGrid gets them on the warm-start path too.
      ! Not called after a restart - those abundances come from pdrGrid.out.
      !-----------------------------------------------------------------
      subroutine seedPDR(grid)
        implicit none

        type(grid_type), dimension(:), intent(inout) :: grid

        integer :: iG, iCell, i, j, k, iAb, yTop
        double precision :: seed(pdrNspec)

        ! Report how the two codes' elemental abundances compare, once. They are
        ! set independently - the network's from species_*.d, MOCASSIN's from its
        ! abundance file - and in the shipped files they disagree: C/H is 1.4e-4
        ! in the reduced network against 2.2e-4 in abunHII20.in, so the chemistry
        ! and the opacity/emission were modelling different amounts of carbon.
        if (taskid == 0) then
           print*, "! seedPDR: elemental abundances, network vs MOCASSIN -"
           call reportAbun( 2, NHe,  grid(1)%elemAbun(1, 2), 'He')
           call reportAbun( 6, NCx,  grid(1)%elemAbun(1, 6), 'C ')
           call reportAbun( 8, NO,   grid(1)%elemAbun(1, 8), 'O ')
           call reportAbun(12, NMGx, grid(1)%elemAbun(1,12), 'Mg')
           if (pdrSyncAbun /= 0) then
              print*, "!   rescaling the network to MOCASSIN's values (pdrSyncAbun)"
           else
              print*, "!   [warning] pdrSyncAbun=0: the two are left inconsistent"
           end if
        end if

        do iG = 1, nGrids
           if (iG > 1 .or. (.not.lg2D)) then
              yTop = grid(iG)%ny
           else
              yTop = 1
           end if

           ! default seed for cells the loop below does not reach (inactive)
           do iCell = 0, grid(iG)%nCells
              grid(iG)%pdrAbun(iCell,:) = pdrInitAbun(1:pdrNspec)
           end do

           do i = 1, grid(iG)%nx
              do j = 1, yTop
                 do k = 1, grid(iG)%nz
                    iCell = grid(iG)%active(i,j,k)
                    if (iCell <= 0) cycle
                    iAb = grid(iG)%abFileIndex(i,j,k)

                    seed = pdrInitAbun(1:pdrNspec)

                    ! At initialisation each element sits in exactly one carrier
                    ! species, so matching MOCASSIN's elemental abundance is a
                    ! single assignment per element. Done per cell so that
                    ! multiChemistry models with different abundance files get
                    ! the right budget in each region.
                    if (pdrSyncAbun /= 0) then
                       call syncSeed(seed, NHe,  grid(iG)%elemAbun(iAb, 2))
                       call syncSeed(seed, NCx,  grid(iG)%elemAbun(iAb, 6))
                       call syncSeed(seed, NO,   grid(iG)%elemAbun(iAb, 8))
                       call syncSeed(seed, NMGx, grid(iG)%elemAbun(iAb,12))
                    end if

                    grid(iG)%pdrAbun(iCell,:) = seed
                 end do
              end do
           end do
        end do

      end subroutine seedPDR


      !-----------------------------------------------------------------
      ! Set one element's carrier species to MOCASSIN's elemental abundance.
      ! A zero MOCASSIN abundance means the element is switched off there, and
      ! the network's value is left alone rather than deleting the element -
      ! removing e.g. Mg+ would silently change the electron budget.
      !-----------------------------------------------------------------
      subroutine syncSeed(seed, iSp, abunMoc)
        implicit none
        double precision, intent(inout) :: seed(:)
        integer, intent(in)             :: iSp
        real, intent(in)                :: abunMoc

        if (iSp <= 0) return
        if (abunMoc <= 0.) return
        seed(iSp) = dble(abunMoc)

      end subroutine syncSeed


      subroutine reportAbun(elem, iSp, abunMoc, label)
        implicit none
        integer, intent(in)          :: elem, iSp
        real, intent(in)             :: abunMoc
        character(len=2), intent(in) :: label

        if (iSp <= 0) then
           print*, "!   ", label, " not in this network"
        else if (abunMoc <= 0.) then
           print*, "!   ", label, " network ", pdrInitAbun(iSp), &
                & " MOCASSIN: element off - network value kept"
        else
           print*, "!   ", label, " network ", pdrInitAbun(iSp), &
                & " MOCASSIN ", abunMoc
        end if

      end subroutine reportAbun



      !-----------------------------------------------------------------
      ! Measure the dust FUV-to-visual extinction ratio from MOCASSIN's own
      ! grain optics (DEVLOG D-026).
      !
      ! 3D-PDR photorates are alpha*chi*exp(-gamma*A_V) with A_V a genuine
      ! visual extinction in magnitudes: each reaction's gamma is fitted against
      ! a standard extinction curve. So A_V,eff handed to the chemistry has to
      ! BE a visual extinction, not a fitting constant - otherwise every gamma
      ! in the network is being applied to the wrong abscissa.
      !
      ! MOCASSIN attenuates with real grain optical constants, so the conversion
      ! from the MC-measured FUV optical depth to A_V is a property of the dust
      ! actually in the model, not a free parameter:
      !
      !     R_FUV = <kappa_ext(FUV)> / kappa_ext(V)         [measured here]
      !     A_V   = 1.0857 * tau_FUV / R_FUV                [magnitudes]
      !
      ! Extinction is absorption + scattering: a scattered FUV photon is removed
      ! from the beam just as an absorbed one is.
      !
      ! Note that in the frozen build matrix (D-009) 3D-PDR never reads UV_fac
      ! itself - its five uses are all inside #ifdef GRAINRECOMB, and AV_fac is
      ! inside #ifdef CRATTENUATION. They enter only through this conversion,
      ! which is why measuring it correctly is the whole job.
      !-----------------------------------------------------------------
      subroutine calibratePDRdust(grid)
        implicit none

        type(grid_type), dimension(:), intent(in) :: grid

        integer          :: iG, iCell, ifreq, nUsed
        double precision :: kFUV, kV, wsum, w

        ! find any cell that actually carries dust; the ratio is independent of
        ! the dust column, so one representative cell is enough
        iCell = -1
        do iG = 1, nGrids
           do ifreq = 0, grid(iG)%nCells
              if (grid(iG)%absOpac(ifreq,VbandP) + &
                & grid(iG)%scaOpac(ifreq,VbandP) > 0.) then
                 iCell = ifreq
                 exit
              end if
           end do
           if (iCell >= 0) exit
        end do

        if (iCell < 0) then
           print*, "! calibratePDRdust: no cell carries dust opacity - cannot"
           print*, "!   calibrate A_V. PDR runs require dust (DEVLOG D-019)."
           stop
        end if

        kV = dble(grid(1)%absOpac(iCell,VbandP)) + dble(grid(1)%scaOpac(iCell,VbandP))

        ! Band-average the FUV extinction over the same bins chi is summed over,
        ! weighted by the ENERGY ACTUALLY EMITTED in each bin rather than by bin
        ! width. chi is a band-integrated energy density, so the extinction it
        ! experiences is the spectrum-weighted one; a flat or width-weighted
        ! average on a log-nu mesh silently over-weights the 912 A end, where
        ! the opacity is steepest, and biases R_FUV high.
        !
        ! inSpectrumProbDen is the cumulative emitted-energy PDF the packets are
        ! drawn from, so its bin-to-bin increment is exactly that weight.
        kFUV = 0.d0
        wsum = 0.d0
        nUsed = 0
        do ifreq = FUVlowP, FUVhighP
           if (ifreq > 1) then
              w = dble(inSpectrumProbDen(1,ifreq)) - dble(inSpectrumProbDen(1,ifreq-1))
           else
              w = dble(inSpectrumProbDen(1,ifreq))
           end if
           if (w <= 0.d0) cycle
           kFUV = kFUV + w*(dble(grid(1)%absOpac(iCell,ifreq)) + &
                &           dble(grid(1)%scaOpac(iCell,ifreq)))
           wsum = wsum + w
           nUsed = nUsed + 1
        end do
        if (wsum > 0.d0) then
           kFUV = kFUV/wsum
        else
           print*, "! calibratePDRdust: no emitted energy in the FUV band"
           stop
        end if

        ! D-055: pdrAVfac converts A_V back to N_H for the H2/CO self-shielding
        ! columns (NHcol = av/pdrAVfac). It MUST invert what computeAVdust
        ! produced, or the shielding columns are wrong by their ratio. Derive it
        ! from the same grains rather than leaving it at a literature default:
        ! A_V per unit length is magPerTau*kV, N_H per unit length is Hden.
        if (grid(1)%Hden(iCell) > 0.) then
           pdrAVfac = real(dble(magPerTau)*kV/dble(grid(1)%Hden(iCell)))
           if (taskid == 0) print*, &
                & "! calibratePDRdust: A_V per N_H =", pdrAVfac, &
                & "  (N_H per mag =", 1./pdrAVfac, ")"
           if (taskid == 0) print*, "! [D060] pdrDiagCool =", pdrDiagCool, " pdrNcool =", pdrNcool
        end if

        if (kV <= 0.d0 .or. kFUV <= 0.d0) then
           print*, "! calibratePDRdust: non-positive dust opacity at V or FUV"
           stop
        end if

        pdrRfuv = real(kFUV/kV)

        if (taskid == 0) then
           print*, "! calibratePDRdust: measured from this model's grains -"
           print*, "!   tau_FUV/tau_V      = ", pdrRfuv, " over ", nUsed, " FUV bins"
           print*, "!   implied UV_fac     = ", pdrRfuv/magPerTau
           print*, "!   3D-PDR default     = ", pdrUVfac
           if (abs(pdrRfuv/magPerTau - pdrUVfac) > 0.25*pdrUVfac) then
              print*, "! calibratePDRdust: [warning] this model's dust differs from the"
              print*, "!   canonical value by more than 25%. A_V is derived from the"
              print*, "!   measured ratio, so the chemistry stays self-consistent, but"
              print*, "!   the network's gamma values assume a standard extinction curve."
           end if
        end if

      end subroutine calibratePDRdust


      !-----------------------------------------------------------------
      ! A_V by direct integration of the dust column (DEVLOG D-042).
      !
      ! The MC-inverted A_V of D-026 is exact while chi is measurable and
      ! carries NO depth information once chi underflows - deep in a resolved
      ! slab no packet ever arrives, chi is exactly zero, and every such cell
      ! collapses to A_V = 0. The chemistry there is still right; the
      ! coordinate is not, and the coordinate is what a benchmark needs.
      !
      ! Under plane-parallel illumination the beam is normal (0,1,0) from the
      ! y=0 face, so the column is a straight accumulation along +y of
      ! kappa_ext(V) = absOpac + scaOpac, both of which are Ndust*sigma and so
      ! already per unit length. A_V is evaluated at the cell centre, hence the
      ! half-step either side.
      !
      ! General 3D geometry still needs the ray trace of D-002; there the MC
      ! inversion remains in use.
      !-----------------------------------------------------------------
      subroutine computeAVdust(grid)
        implicit none

        type(grid_type), dimension(:), intent(inout) :: grid

        integer          :: iG, i, j, k, cellP, yTop, jStart
        double precision :: tau, dy, kap

        if (.not.lgPlaneIonization) return

        do iG = 1, nGrids
           if (iG > 1 .or. (.not.lg2D)) then
              yTop = grid(iG)%ny
           else
              yTop = 1
           end if

           ! Start at the illuminated plane, not at the grid edge.
           ! planeIonization force-disables lgSymmetricXYZ, so the axes run
           ! -Rn..+Rn and packets are launched at position%y = 0 - the grid
           ! CENTRE. Only y > 0 is illuminated. Integrating from j = 1 would
           ! accumulate the whole shadowed half before reaching the light, which
           ! is what made A_V and chi inconsistent (DEVLOG D-045).
           jStart = 1
           do j = 1, grid(iG)%ny
              if (grid(iG)%yAxis(j) >= 0.) then
                 jStart = j
                 exit
              end if
           end do

           do i = 1, grid(iG)%nx
              do k = 1, grid(iG)%nz
                 ! shadowed half: no incident field, so no meaningful A_V
                 do j = 1, jStart-1
                    if (grid(iG)%active(i,j,k) > 0) &
                         & grid(iG)%AVeff(grid(iG)%active(i,j,k)) = 0.
                 end do
                 tau = 0.d0
                 do j = jStart, yTop

                    if (j > 1 .and. j < grid(iG)%ny) then
                       dy = 0.5d0*abs(dble(grid(iG)%yAxis(j+1)) - dble(grid(iG)%yAxis(j-1)))
                    else if (j == 1) then
                       dy = abs(dble(grid(iG)%yAxis(min(2,grid(iG)%ny))) - dble(grid(iG)%yAxis(1)))
                    else
                       dy = abs(dble(grid(iG)%yAxis(j)) - dble(grid(iG)%yAxis(j-1)))
                    end if

                    cellP = grid(iG)%active(i,j,k)
                    kap = 0.d0
                    if (cellP > 0) kap = dble(grid(iG)%absOpac(cellP,VbandP)) &
                         &              + dble(grid(iG)%scaOpac(cellP,VbandP))

                    tau = tau + kap*dy*0.5d0
                    if (cellP > 0) grid(iG)%AVeff(cellP) = real(dble(magPerTau)*tau)
                    tau = tau + kap*dy*0.5d0
                 end do

                 ! D-061: the remaining column to the far boundary, which the
                 ! inward-looking escape rays see.
                 do j = jStart, yTop
                    cellP = grid(iG)%active(i,j,k)
                    if (cellP > 0) grid(iG)%AVback(cellP) = &
                         & max(real(dble(magPerTau)*tau) - grid(iG)%AVeff(cellP), 0.)

                 end do
              end do
           end do
        end do

      end subroutine computeAVdust


      !-----------------------------------------------------------------
      ! Reduce the Monte Carlo radiation field to what the chemistry needs.
      !
      ! chi is the D-001 formula, validated to 0.3% in Phase 0: Jste/Jdif are
      ! bin-integrated [erg/s/cm^2], so the FUV energy density is a bare sum
      ! over bins divided by c - there is deliberately no widFlx factor.
      !
      ! A_V,eff inverts the attenuation against the unattenuated, geometrically
      ! diluted field from the sources, so that feeding 3D-PDR
      ! rad_surface(k) = chi0/nrays with AV(k) = AVeff reproduces the MC field
      ! through its existing alpha*rad_surface*exp(-gamma*AV) rate expressions.
      !-----------------------------------------------------------------
      subroutine mocassinToPDR(grid)
        implicit none

        type(grid_type), dimension(:), intent(inout) :: grid

        integer          :: iG, i, j, k, ifreq, iS, cellP, yTop
        double precision :: uFUV, chi, chi0, rr, dx, dy, dz, xHII, tauFUV
        double precision :: chi0Plane
        double precision :: Lfuv(nStars)
        real             :: fFUV

        if (pdrRfuv <= 0.) then
           print*, "! mocassinToPDR: dust not calibrated - call calibratePDRdust first"
           stop
        end if

        ! Per-source FUV luminosity, from the same cumulative energy PDF the
        ! packets are drawn from (validated in Phase 0). Kept per source rather
        ! than summed: the unattenuated field at a cell is the sum of each
        ! source's own inverse-square dilution from its own position.
        do iS = 1, nStars
           fFUV = inSpectrumProbDen(iS, FUVhighP)
           if (FUVlowP > 1) fFUV = fFUV - inSpectrumProbDen(iS, FUVlowP-1)
           Lfuv(iS) = dble(Lstar(iS))*1.d36*dble(fFUV)
        end do

        do iG = 1, nGrids
           if (iG > 1 .or. (.not.lg2D)) then
              yTop = grid(iG)%ny
           else
              yTop = 1
           end if

           ! Plane-parallel: there is no point source to dilute from. The
           ! unattenuated field is the incident flux at the illuminated face,
           ! which is the total FUV luminosity spread over the area the
           ! transverse mirrors enclose - the same xAxis(nx)*zAxis(nz) that
           ! setMotherGrid used to build Lstar from meanField (D-048).
           chi0Plane = 0.d0
           if (lgPlaneIonization) then
              do iS = 1, nStars
                 chi0Plane = chi0Plane + Lfuv(iS) / &
                      & (dble(grid(iG)%xAxis(grid(iG)%nx)) * &
                      &  dble(grid(iG)%zAxis(grid(iG)%nz)) * &
                      &  dble(c)*dble(uDraine))
              end do
           end if
           if (lgPlaneIonization .and. taskid == 0) &
                & print*, "! mocassinToPDR: plane-parallel surface field chi0 =", chi0Plane

           do i = 1, grid(iG)%nx
              do j = 1, yTop
                 do k = 1, grid(iG)%nz
                    cellP = grid(iG)%active(i,j,k)
                    if (cellP <= 0) cycle

                    uFUV = 0.d0
                    do ifreq = FUVlowP, FUVhighP
                       uFUV = uFUV + dble(grid(iG)%Jste(cellP,ifreq))
                       if (lgDebug) uFUV = uFUV + dble(grid(iG)%Jdif(cellP,ifreq))
                    end do
                    chi = uFUV / (dble(c)*dble(uDraine))
                    grid(iG)%chiFUV(cellP) = real(chi)

                    ! Unattenuated field at this cell: every source diluted
                    ! from its own position, not a single lumped luminosity.
                    chi0 = 0.d0
                    if (lgPlaneIonization) chi0 = chi0Plane
                    do iS = 1, nStars
                       if (lgPlaneIonization) exit
                       dx = dble(grid(iG)%xAxis(i)) - dble(starPosition(iS)%x)
                       dy = dble(grid(iG)%yAxis(j)) - dble(starPosition(iS)%y)
                       dz = dble(grid(iG)%zAxis(k)) - dble(starPosition(iS)%z)
                       rr = sqrt(dx*dx + dy*dy + dz*dz)
                       if (rr > 0.d0) chi0 = chi0 + &
                            & Lfuv(iS)/(dble(fourPi)*rr*rr*dble(c)*dble(uDraine))
                    end do

                    grid(iG)%chiFUV0(cellP) = real(chi0)

                    ! Invert the measured attenuation into a genuine visual
                    ! extinction in magnitudes, using this model's own grains
                    ! (D-026). tau_FUV -> A_V = 1.0857*tau_FUV/R_FUV.
                    !
                    ! Skipped under plane-parallel illumination, where
                    ! computeAVdust has already integrated the dust column
                    ! directly: inverting the MC field loses all depth
                    ! information once chi underflows to zero, which is exactly
                    ! what happens deep in a well-resolved slab (D-042).
                    ! D-053: carry the MC field - diffuse component included -
                    ! into the chemistry. 3D-PDR re-derives the attenuation from
                    ! A_V using its own gamma, so the A_V handed over must be the
                    ! one that REPRODUCES the measured field, not the geometric
                    ! dust column. MOCASSIN transports the field at gamma_eff
                    ! ~ 0.73 against 3D-PDR's ~3.0, so the two differ by a lot.
                    !
                    ! D-043 disabled this under plane-parallel illumination
                    ! because chi underflowed to zero deep in the slab and the
                    ! inversion degenerated. That underflow was the A_V-origin
                    ! bug of D-045 and is fixed, so the inversion is viable here
                    ! again. computeAVdust has already run this iteration
                    ! (iteration_mod.f90:779), so wherever chi HAS underflowed
                    ! its dust-column value simply stands.
                    if (.not.lgPlaneIonization) then
                       if (chi0 > chi .and. chi > 0.d0) then
                          tauFUV = -log(chi/chi0)
                          grid(iG)%AVeff(cellP) = &
                               & real(dble(magPerTau)*tauFUV/dble(pdrRfuv))
                       else
                          grid(iG)%AVeff(cellP) = 0.
                       end if
                    end if

                    ! zone flag (D-007): PDR chemistry runs in the neutral gas
                    xHII = dble(grid(iG)%ionDen(cellP, elementXref(1), 2))
                    ! Latching, not a bare threshold. The handover writes the
                    ! PDR temperature into grid%Te, which changes the ionization
                    ! balance, which moves x(H+) - the very quantity the zone
                    ! test uses. Measured consequence: a cell entered the zone,
                    ! got a temperature, left the zone next iteration and was
                    ! never revisited, so the grid ended up a patchwork of cells
                    ! converged at different iterations. Once a cell is in the
                    ! zone it stays there, so the criterion cannot be perturbed
                    ! by its own effect (DEVLOG D-031).
                    if (xHII < dble(pdrZoneLim)) then
                       grid(iG)%pdrZone(cellP) = 1
                    else if (grid(iG)%pdrZone(cellP) == 0) then
                       grid(iG)%pdrZone(cellP) = 0
                    end if

                    ! Seed the thermal state the first time a cell enters the
                    ! zone. 3D-PDR's GUESS_TEMP estimate, T = 10(1+(2chi)^1/3),
                    ! is a far better starting point than MOCASSIN's T_e here -
                    ! which D-030 measured at 30-3550 K in gas that belongs at
                    ! 10-100 K. The bracket starts wide and is halved each
                    ! iteration (D-031).
                    if (grid(iG)%pdrZone(cellP) == 1 .and. &
                        & grid(iG)%pdrTgas(cellP) <= 0.) then
                       grid(iG)%pdrTgas(cellP)  = &
                            & real(10.d0*(1.d0 + (2.d0*max(chi,0.d0))**(1.d0/3.d0)))
                       grid(iG)%pdrTgas(cellP)  = &
                            & min(max(grid(iG)%pdrTgas(cellP), pdrTmin), pdrTmax)
                       grid(iG)%pdrTlow(cellP)  = pdrTmin
                       grid(iG)%pdrThigh(cellP) = pdrTmax
                    end if

                 end do
              end do
           end do

           ! D-054: the plane-parallel A_V inversion is NOT enabled. TORUS-3DPDR
           ! (Bisbas et al. 2015) - the published MC + 3D-PDR coupling - derives
           ! A_V geometrically from the density field along HEALPix rays and uses
           ! the MC field only to set the direction-dependent surface field, plus
           ! a geometric dilution term. Inverting A_V out of the MC field is a
           ! departure from that, and measurably worse here: it puts A_V = 0.68 in
           ! the first cell and drives the H/H2 transition to smaller A_V, where
           ! TORUS finds the diffuse field moves it deeper. computeAVdust's
           ! geometric column stands (D-043).
        end do

      end subroutine mocassinToPDR


      !-----------------------------------------------------------------
      ! One cell of PDR chemistry (DEVLOG D-027).
      !
      ! Takes pdrChemIter passes and returns; the outer MC loop carries the
      ! convergence (D-008). Converging the chemistry here would multiply the
      ! two solvers' iteration counts.
      !
      ! The radiation field is handed over in the D-001 effective-A_V form:
      ! rad_surface(k) = chi/nrays and AV(k) = A_V,eff on every ray, so
      ! 3D-PDR's own sum_k alpha*rad_surface(k)*exp(-gamma*AV(k)) collapses to
      ! alpha*chi*exp(-gamma*A_V,eff) with A_V,eff measured from this model's
      ! grains (D-026).
      !
      ! SHIELDING COLUMNS ARE SLAB-EQUIVALENT, not ray-traced. N_H is recovered
      ! from the local extinction, N_H = A_V/AV_fac, and each shielding column
      ! is that times the local fractional abundance. For a 1D slab - the
      ! geometry of every published PDR benchmark - this is exact. For genuinely
      ! 3D geometry it is an approximation, and the HEALPix trace of D-002 is
      ! the upgrade. Flagged rather than hidden.
      !-----------------------------------------------------------------
      subroutine pdrStep(grid, xP, yP, zP)
        implicit none

        type(grid_type), intent(inout) :: grid
        integer, intent(in)            :: xP, yP, zP

        integer, parameter :: nraysLoc = 12          ! HEALPix level 0
        integer, parameter :: npart = 1
        double precision   :: radSurf(0:nraysLoc-1), AVray(0:nraysLoc-1)
        double precision   :: colH2(0:nraysLoc-1), colHD(0:nraysLoc-1)
        double precision   :: colCO(0:nraysLoc-1), colC(0:nraysLoc-1)
        double precision   :: colS(0:nraysLoc-1)
        double precision   :: abun(pdrNspec)
        double precision   :: abun0(pdrNspec), heat(12)
        integer            :: ik, il, jl, nlev, itherm, ilev
        double precision   :: coolTot, coolK, nSpec, Zpart, lsum, Fbal, Tlo, Thi, TgIn
        double precision   :: Flo, Fhi, Fratio, Fden, xlo, xhi, xnewT, denom
        logical            :: doChop
        character(len=1)   :: prevChange, illLast
        double precision   :: TdMoc, TdHTT, T0HTT
        double precision   :: lpop(pdrMaxLev), lsol(pdrMaxLev)
        double precision   :: Ccoef(pdrMaxLev,pdrMaxLev), trans(pdrMaxLev,pdrMaxLev)
        double precision   :: lline(pdrMaxLev,pdrMaxLev)
        double precision   :: evpop(0:nraysLoc-1,0:1,pdrMaxLev), plen(0:nraysLoc-1,0:1)
        double precision   :: evpt(1:3,0:nraysLoc-1,0:1)
        integer            :: jjr(0:nraysLoc-1)
        integer            :: kray
        double precision   :: mu, colA, avBack
        double precision   :: nH, Tg, Td, chi, av, NHcol
        integer            :: cellP, NRGR, NR2, NR3, NR4, NR5, NR6, it

        cellP = grid%active(xP,yP,zP)
        if (cellP <= 0) return
        if (grid%pdrZone(cellP) == 0) return

        nH  = dble(grid%Hden(cellP))
        if (nH <= 0.d0) return

        ! The PDR temperature, NOT grid%Te. MOCASSIN's thermal balance solves
        ! for photoionised gas and barely constrains T at low ionisation; D-030
        ! measured it at 30-3550 K where a PDR belongs at 10-100 K.
        Tg  = dble(grid%pdrTgas(cellP))
        if (Tg <= 0.d0) Tg = dble(grid%Te(cellP))
        ! ---- dust temperature (DEVLOG D-033, D-036) ----------------------
        ! MOCASSIN solves dust equilibrium against the local radiation field
        ! with no floor, so a deeply shielded cell has almost nothing heating
        ! its grains and T_dust tends to zero - measured at 0.59 K. Fine for an
        ! H II region; unphysical for a PDR, and damaging twice over: H2 forms
        ! on grains and the Cazaux & Tielens rate collapses as T_dust -> 0, and
        ! cosmic-ray heating is proportional to x(H2), so it collapses with it.
        !
        ! Hollenbach, Takahashi & Tielens (1991) parametrise T_dust from the FUV
        ! field and A_V, including the re-radiated IR and the CMB - designed for
        ! exactly this regime. Their own routine ends by flooring T_dust at 10 K
        ! "since values below 10 K can dramatically limit the rate of H2
        ! formation on grains", which is the same failure found here.
        !
        ! The two estimates are combined by taking the larger. MOCASSIN's failure
        ! mode is specifically to UNDER-estimate - it omits heat sources rather
        ! than inventing them - so max() keeps its full radiative transfer where
        ! the grains see light and falls back to HTT91 where they do not.
        TdMoc = dble(grid%Tdust(0,0,cellP))

        ! HTT91, evaluated with the single effective ray of D-001 carrying the
        ! full local field (3D-PDR's own 1D mode does the same, putting all the
        ! flux on one ray).
        TdHTT = 8.9d-11*2.65d15*(1.71d0*chi) + pdrTcmb**5
        T0HTT = 12.2d0*(1.71d0*max(chi,0.d0))**0.2d0
        if (av > 1.0d0) T0HTT = T0HTT*av**(-0.4d0)
        if (T0HTT > 0.d0) TdHTT = TdHTT + &
             & (0.42d0 - log(3.45d-5*T0HTT))*(3.45d-5*T0HTT)*T0HTT**5
        TdHTT = max(TdHTT, 0.d0)**0.2d0
        TdHTT = max(TdHTT, 10.0d0)          ! HTT91's own floor, and the reason for it

        select case (pdrDustModel)
        case (0)
           Td = max(TdMoc, dble(pdrTcmb))
        case (2)
           Td = TdHTT
        case default
           Td = max(TdMoc, TdHTT)
        end select
        if (Td <= 0.d0) Td = dble(pdrTdustMod)
        ! D-050: 3D-PDR re-applies the attenuation itself, through
        ! alpha*rad_surface*exp(-gamma*A_V) inside CALCULATE_REACTION_RATES.
        ! The field handed over must therefore be the UNATTENUATED one; passing
        ! the local MC field (grid%chiFUV) attenuates it twice and drives every
        ! photodissociation front to too small an A_V.
        chi = dble(grid%chiFUV0(cellP))
        if (chi <= 0.d0) chi = dble(grid%chiFUV(cellP))
        av  = dble(grid%AVeff(cellP))

        ! keep the chemistry inside the temperature range it was fitted over
        Tg = min(max(Tg, dble(pdrTmin)), dble(pdrTmax))

        radSurf = chi/dble(nraysLoc)
        AVray   = av

        ! slab-equivalent shielding columns (see header)
        NHcol = av/dble(pdrAVfac)
        abun  = grid%pdrAbun(cellP, 1:pdrNspec)

        colH2 = NHcol*abun(NH2)
        colCO = NHcol*abun(NCO)
        colC  = NHcol*abun(NC)
        colHD = 0.d0
        colS  = 0.d0

        abun0 = abun


        do it = 1, pdrChemIter
           call CALCULATE_REACTION_RATES(Tg, Td, nraysLoc, radSurf, AVray, &
                & colH2, colHD, colCO, colC, colS, &
                & pdrNreacMod, pdrReactant, pdrProduct, pdrAlpha, pdrBeta, &
                & pdrGamma, pdrRate, pdrRtmin, pdrRtmax, pdrDuplicate, &
                & pdrNspecMod, NRGR, NR2, NR3, NR4, NR5, NR6, &
                & abun(pdrNelect)*nH, nH, pdrZetaMod)

           call calculate_abundances(abun, pdrRate, nH, Tg, npart, &
                & pdrNspecMod, pdrNreacMod)

           ! shielding columns follow the abundances between passes
           colH2 = NHcol*abun(NH2)
           colCO = NHcol*abun(NCO)
           colC  = NHcol*abun(NC)
        end do

        ! Make a silent solver failure visible. calculate_abundances copies the
        ! CVODE state vector back unconditionally, so when the integration does
        ! not advance - which happens for the stiffest cells right at the
        ! illuminated face, even with CHEMRETRY - the initial abundances are
        ! written back and are indistinguishable from a converged result.
        ! Flagging them as zone 2 keeps them out of downstream use instead of
        ! letting seed values masquerade as chemistry (DEVLOG D-027).
        ! An unchanged abundance vector was originally treated as a solver
        ! failure and returned early. That was wrong twice over: it is also the
        ! signature of chemistry that has simply CONVERGED, and returning here
        ! skipped the thermal balance below - so once a cell's chemistry settled,
        ! its temperature froze permanently. The symptom was T_gas identical to
        ! the last digit across three different thermal-balance algorithms.
        !
        ! Count it for diagnostics, but never skip the thermal balance for it.
        if (all(abun == abun0)) pdrNstuck = pdrNstuck + 1

        grid%pdrAbun(cellP, 1:pdrNspec) = abun


        ! ---- inner thermal-balance loop (DEVLOG D-031) -------------------
        ! D-008's rule - one pass, let the outer MC loop converge - holds for
        ! the chemistry but NOT for thermal balance. The level populations lag
        ! the temperature, so a single bracketing step per MC iteration chases
        ! a moving target: measured heat/cool stayed at 0.15 and 9.4 at the
        ! extremes after 8 MC iterations, while mid-range cells reached 1.0.
        ! Standalone 3D-PDR needs ~65 iterations for this; MOCASSIN runs 10-20.
        ! So the temperature and the populations are relaxed together here.
        ! Start each MC iteration with NO bracket and search for one. An
        ! assumed bracket is worthless here: if F does not change sign across
        ! it, bisection simply walks to whichever bound it started nearest,
        ! which is what pinned cells at 5 K and 3700 K in the first attempt.
        ! D-051: seed the march deterministically. The incoming Tg is the
        ! cell's previous temperature, which carries Monte Carlo noise. Where
        ! F(T) = heating - cooling has more than one root, the noise decides
        ! which direction the march sets off in and therefore which root is
        ! found - so transverse cells that are physically IDENTICAL (same A_V,
        ! density and field, by the slab's symmetry) settled a factor of four
        ! apart, at 33 K and 135 K. Starting above the expected root and
        ! marching DOWN selects the highest (surface-heated) root consistently.
        ! D-051 (reverted): seeding the march from a fixed temperature to make
        ! the root selection deterministic does NOT work - see the DEVLOG. The
        ! incoming temperature is kept as the seed; TgIn only guards the
        ! non-finite exit below so a failed cell never reports a bogus value.
        TgIn = Tg
        Tlo = 0.d0
        Thi = 0.d0

        do itherm = 1, max(pdrThermIter,1)

           ! PDR heating budget for this cell: 12 terms, total in slot 12. The
           ! photoelectric part is kept separately because it is the term
           ! MOCASSIN also computes, and D-007's blend band ramps between the
           ! two rather than adding them.
           call CALC_HEATING(nH, Tg, Td, chi, dble(pdrVturb)*1.d5, pdrNspecMod, &
                & abun, pdrNreacMod, pdrRate, heat, &
                & NRGR, NR2, NR3, NR4, NR5, NR6, pdrZetaMod)

           grid%pdrHeat(cellP)   = real(heat(12))
           grid%pdrHeatPE(cellP) = real(heat(1) + heat(2) + heat(3))

           ! ---- line cooling (DEVLOG D-030) --------------------------------
           ! Non-LTE level populations per coolant, solved with an escape
           ! probability. The ray structure is collapsed to ONE ray carrying ONE
           ! evaluation point whose path length is the slab depth implied by the
           ! local extinction - the same slab-equivalent approximation the
           ! shielding columns use (D-027), and exact for 1D geometry.
           !
           ! One pass per MC iteration, not an inner convergence loop: the outer
           ! loop carries level-population convergence exactly as it carries the
           ! chemistry (D-008).
           coolTot = 0.d0
           do ik = 1, pdrNcool
              nlev = pdrCoolant2(ik)%cnlev
              nSpec = abun(pdrCoolant2(ik)%cspec)*nH

              ! Skip a coolant whose carrier has been chemically destroyed.
              ! Below this the level populations are numerically meaningless
              ! and the transition matrix goes singular - solvlevpop's
              ! Gauss-Jordan then hits a zero pivot, returns NaN, and the NaN
              ! rides the cooling into T_gas and out into MOCASSIN (D-041).
              if (nSpec <= pdrNspecFloor*nH) cycle

              lpop(1:nlev) = grid%pdrLevPop(cellP, pdrLevOff(ik)+1 : pdrLevOff(ik)+nlev)

              ! First visit to this cell: start from LTE, as 3D-PDR does.
              if (all(lpop(1:nlev) <= 0.d0)) then
                 call calculate_partition_function(Zpart, nlev, &
                      & pdrCoolant2(ik)%energies, pdrCoolant2(ik)%weights, Tg)
                 call calculate_lte_populations(nlev, lpop(1:nlev), &
                      & pdrCoolant2(ik)%energies, pdrCoolant2(ik)%weights, &
                      & Zpart, nSpec, Tg)
              else
                 ! rescale to the abundance the chemistry just produced
                 lsum = sum(lpop(1:nlev))
                 if (lsum > 0.d0) lpop(1:nlev) = lpop(1:nlev)*nSpec/lsum
              end if

              call FIND_CCOEFF(pdrCoolant2(ik)%cntemp, nlev, Tg, &
                   & pdrCoolant2(ik)%temperatures, pdrCoolant2(ik)%H_COL, &
                   & pdrCoolant2(ik)%HP_COL, pdrCoolant2(ik)%EL_COL, &
                   & pdrCoolant2(ik)%HE_COL, pdrCoolant2(ik)%H2_COL, &
                   & pdrCoolant2(ik)%PH2_COL, pdrCoolant2(ik)%OH2_COL, &
                   & Ccoef(1:nlev,1:nlev), abun(NH)*nH, abun(NPROTON)*nH, &
                   & abun(pdrNelect)*nH, abun(NHe)*nH, abun(NH2)*nH)

              ! Rebuild the upward rates by detailed balance at the local gas
              ! temperature, as coolingfunctions does (avoids "supercooling").
              do il = 2, nlev
                 do jl = 1, il-1
                    Ccoef(jl,il) = Ccoef(il,jl) &
                         & *pdrCoolant2(ik)%weights(il)/pdrCoolant2(ik)%weights(jl) &
                         & *exp(-(pdrCoolant2(ik)%energies(il) &
                         &       -pdrCoolant2(ik)%energies(jl))/(KB*Tg))
                 end do
              end do

              ! ---- D-060: converge the level populations AT FIXED T -------
              ! One pass per thermal step is not enough. The populations then
              ! lag the temperature by a step, and the cooling they produce is
              ! not a monotonic function of T - measured at one face cell it
              ! ran 5.1e-22 at 34.6 K, 4.0e-23 at 17.3 K and 3.3e-24 at 24.5 K.
              ! A bracket search on a non-monotonic F(T) finds an arbitrary
              ! root, which is why the surface settled 12x hotter than
              ! standalone 3D-PDR and why physically identical cells landed
              ! decades apart (D-051 blamed bistability; it was this).
              !
              ! 3D-PDR guards the same thing: changetemperature.F90 opens with
              ! `if (.not.level_conv) return` - it refuses to move T until the
              ! populations have converged. D-056 ported its arithmetic but not
              ! that guard. Here the equivalent is an inner fixed-T iteration.
              ! ---- D-063: compile and call the SAME branch 3D-PDR uses ----
              ! Approximating 3D-PDR's escape geometry from outside kept
              ! failing: 12 rays divided by 12 gave beta = 0.33 (D-061), one
              ! ray on the nearest face gave worse fronts still. The branch
              ! itself was the difference - we compiled RAYTHEIA_MO, which
              ! divides beta by nrays, while 3D-PDR's 1D build takes
              ! ONEDIMENSIONAL, which blanks 11 of 12 rays to tau = 1e50 and
              ! does NOT divide. PDRFLAGS now selects ONEDIMENSIONAL, so both
              ! codes run identical escape_probability code and the only thing
              ! we supply is the geometry it asks for: evaluation-point
              ! coordinates, in pc, along ray 6.
              avBack = dble(grid%AVback(cellP))
              colA   = av                       ! column back to the illuminated face
              jjr    = 1
              evpt   = 0.d0
              evpt(1,6,0) = 0.d0
              evpt(1,6,1) = (colA/dble(pdrAVfac))/nH/PC

              do ilev = 1, max(pdrLevIter,1)
              evpop = 0.d0
              do kray = 0, nraysLoc-1
                 evpop(kray,0,1:nlev) = lpop(1:nlev)
                 evpop(kray,1,1:nlev) = lpop(1:nlev)
              end do

              trans(1:nlev,1:nlev) = 0.d0
              call escape_probability(trans(1:nlev,1:nlev), Td, nraysLoc, nlev, &
                   & pdrCoolant2(ik)%A_COEFFS, pdrCoolant2(ik)%B_COEFFS, &
                   & Ccoef(1:nlev,1:nlev), pdrCoolant2(ik)%frequencies, &
                   & evpop(0:nraysLoc-1,0:1,1:nlev), 1, Tg, dble(pdrVturb)*1.d5, jjr, &
                   & lpop(1:nlev), evpt, pdrCoolant2(ik)%weights, coolK, &
                   & lline(1:nlev,1:nlev), nH, pdrMetalMod, &
                   & pdrCoolant2(ik)%molweight)

              call solvlevpop(nlev, trans(1:nlev,1:nlev), nSpec, lsol(1:nlev))

              ! Validate before trusting it. A singular matrix returns NaN
              ! rather than failing, and that NaN surfaces far away as
              ! "getGrainRecombination: insane eta" - a symptom naming neither
              ! this routine nor the real cause. Keep the previous populations
              ! and leave this coolant out of the budget for this pass.
              if (any(lsol(1:nlev) /= lsol(1:nlev)) .or. &
                & any(lsol(1:nlev) < 0.d0) .or. &
                & sum(lsol(1:nlev)) <= 0.d0 .or. coolK /= coolK) then
                 pdrNbadPop = pdrNbadPop + 1
                 cycle
              end if

              ! converged when the populations stop moving at this T
              lsum = 0.d0
              do il = 1, nlev
                 if (lsol(il) > 0.d0) lsum = max(lsum, &
                      & abs(lsol(il)-lpop(il))/lsol(il))
              end do
              lpop(1:nlev) = lsol(1:nlev)
              if (lsum < dble(pdrLevTol)) exit
              end do

              grid%pdrLevPop(cellP, pdrLevOff(ik)+1 : pdrLevOff(ik)+nlev) = lsol(1:nlev)
              coolTot = coolTot + coolK

              ! D-060 diagnostic: per-coolant budget at the illuminated face
              if (pdrDiagCool > 0 .and. taskid == 0) then
                 if (pdrNdiag < 60) then
                    pdrNdiag = pdrNdiag + 1
                    print '(a,i3,a,es9.2,a,i3,a,es10.3,a,es10.3,a,es10.3,a,f8.1)', &
                       & " [D060] coolant", ik, " A_V=", grid%AVeff(cellP), &
                       & " cspec=", pdrCoolant2(ik)%cspec, " n=", nSpec, &
                       & " cool=", coolK, " plen_pc=", evpt(1,6,1), " T=", Tg
                 end if
              end if
           end do

           grid%pdrCool(cellP) = real(coolTot)

           ! F(T) = heating - cooling. F > 0 means the gas is too cold.
           ! Cooling is exponentially sensitive to T - a single bisection step
           ! can move it by two orders of magnitude - so the bracket has to be
           ! found by marching before bisecting, not assumed.
           ! Never let a non-finite budget move the temperature.
           if (heat(12) /= heat(12) .or. coolTot /= coolTot) then
              if (Tlo <= 0.d0 .or. Thi <= 0.d0) Tg = TgIn   ! never report the seed
              exit
           end if

           ! D-056 (reverted): porting 3D-PDR's +-30% expansion + Illinois
           ! regula falsi into this loop made things worse - transverse spread
           ! at A_V~0.1 went from 150-152 K to 167-814 K, heat/cool from 0.997
           ! to 1.055. Its +-30% steps assume 3D-PDR's ~65 OUTER iterations with
           ! the bracket persisting across them; this inner loop gets 12 steps
           ! and resets each MC iteration, so the search never reaches the root.
           ! Porting it properly means persisting Tlow/Thigh/Flow/Fhigh and the
           ! direction flags on the grid, not just the arithmetic.
           Fbal = heat(12) - coolTot
           if (Fbal > 0.d0) then
              Tlo = Tg
           else
              Thi = Tg
           end if

           if (Tlo > 0.d0 .and. Thi > 0.d0) then
              Tg = sqrt(Tlo*Thi)
           else if (Fbal > 0.d0) then
              Tg = Tg*2.d0
           else
              Tg = Tg*0.5d0
           end if
           Tg = min(max(Tg, dble(pdrTmin)), dble(pdrTmax))

        end do

        ! Re-evaluate once at the converged temperature so the stored heating
        ! and cooling correspond to the stored T. Without this they are one
        ! bisection step stale, and because cooling is exponential in T that
        ! makes a converged cell look like a factor-of-20 imbalance.
        call CALC_HEATING(nH, Tg, Td, chi, dble(pdrVturb)*1.d5, pdrNspecMod, &
             & abun, pdrNreacMod, pdrRate, heat, &
             & NRGR, NR2, NR3, NR4, NR5, NR6, pdrZetaMod)
        grid%pdrHeat(cellP)   = real(heat(12))
        grid%pdrHeatPE(cellP) = real(heat(1) + heat(2) + heat(3))

        grid%pdrTgas(cellP)  = real(Tg)
        grid%pdrTlow(cellP)  = real(Tlo)
        grid%pdrThigh(cellP) = real(Thi)

        ! Fold PDR thermal balance into MOCASSIN's convergence test (D-032).
        !
        ! Without this the run stops on MOCASSIN's own criterion - which counts
        ! its ionization and electron-temperature convergence and knows nothing
        ! about the PDR - while PDR cells are still moving. Measured: the test
        ! model reported 97.8% converged after 3 MC iterations, by which point
        ! cells that had only just entered the zone had received a single
        ! thermal step.
        !
        ! lgConverged uses the same owner-contributes reduction as Te and Ne and
        ! is exchanged after this loop, so clearing it here for an unbalanced
        ! cell is enough; no change to the counting logic is needed.
        if (max(abs(heat(12)), coolTot) > 0.d0) then
           if (abs(heat(12)-coolTot)/max(abs(heat(12)), coolTot) > dble(pdrFcrit)) then
              grid%lgConverged(cellP) = 0
           end if
        end if

      end subroutine pdrStep


      !-----------------------------------------------------------------
      ! Push converged PDR state back into the MOCASSIN grid.
      ! PHASE 4 - deliberately a stub.
      !-----------------------------------------------------------------
      !-----------------------------------------------------------------
      ! Push the PDR gas temperature back into the grid (DEVLOG D-031).
      !
      ! In the PDR zone MOCASSIN's T_e is replaced outright: its thermal
      ! balance is simply the wrong solver there, so blending it in would
      ! only dilute the right answer with the wrong one. Across the blend
      ! band (D-007) the two are interpolated linearly in log x(H+), so the
      ! temperature structure has no step at the handover.
      !
      ! Note this replaces rather than adds, so there is no double counting:
      ! MOCASSIN's heating/cooling for these cells is simply discarded.
      !-----------------------------------------------------------------
      subroutine pdrToMocassin(grid)
        implicit none

        type(grid_type), dimension(:), intent(inout) :: grid

        integer          :: iG, i, j, k, cellP, yTop, iAb
        double precision :: xHII, w, lo, hi, xnew, heTot

        lo = log10(max(dble(pdrBlendLo), 1.d-30))
        hi = log10(max(dble(pdrZoneLim), 1.d-30))

        do iG = 1, nGrids
           if (iG > 1 .or. (.not.lg2D)) then
              yTop = grid(iG)%ny
           else
              yTop = 1
           end if
           do i = 1, grid(iG)%nx
              do j = 1, yTop
                 do k = 1, grid(iG)%nz
                    cellP = grid(iG)%active(i,j,k)
                    if (cellP <= 0) cycle
                    if (grid(iG)%pdrTgas(cellP) <= 0.) cycle

                    xHII = dble(grid(iG)%ionDen(cellP, elementXref(1), 2))

                    if (xHII <= dble(pdrBlendLo)) then
                       w = 1.d0
                    else if (xHII < dble(pdrZoneLim)) then
                       ! blend band: w = 1 at the neutral edge, 0 at the ionised one
                       w = (hi - log10(max(xHII,1.d-30))) / max(hi-lo, 1.d-30)
                       w = min(max(w, 0.d0), 1.d0)
                    else
                       cycle
                    end if

                    grid(iG)%Te(cellP) = real( &
                         & w*dble(grid(iG)%pdrTgas(cellP)) + &
                         & (1.d0-w)*dble(grid(iG)%Te(cellP)))

                    ! ---- ionization state (DEVLOG D-037) -----------------
                    ! MOCASSIN has no cosmic-ray ionization (D-035), so in
                    ! shielded gas its ionBalance drives x(H+) to zero while the
                    ! true value is CR-maintained. The chemical network does have
                    ! it, so hand H and He back the same way the temperature is
                    ! handed back. This closes the loop: the ionization that sets
                    ! the zone flag, the electron density and the proton density
                    ! is now the one computed with the relevant physics.
                    !
                    if (NPROTON > 0) then
                       xnew = min(max(grid(iG)%pdrAbun(cellP,NPROTON), 0.d0), 1.d0)
                       grid(iG)%ionDen(cellP,elementXref(1),2) = real( &
                            & w*xnew + (1.d0-w)*dble(grid(iG)%ionDen(cellP,elementXref(1),2)))
                       grid(iG)%ionDen(cellP,elementXref(1),1) = &
                            & 1.0 - grid(iG)%ionDen(cellP,elementXref(1),2)
                    end if

                    if (lgElementOn(2) .and. NHe > 0 .and. NHEx > 0 .and. nStages >= 3) then
                       heTot = grid(iG)%pdrAbun(cellP,NHe) + grid(iG)%pdrAbun(cellP,NHEx)
                       if (heTot > 0.d0) then
                          xnew = min(max(grid(iG)%pdrAbun(cellP,NHEx)/heTot, 0.d0), 1.d0)
                          grid(iG)%ionDen(cellP,elementXref(2),2) = real( &
                               & w*xnew + (1.d0-w)*dble(grid(iG)%ionDen(cellP,elementXref(2),2)))
                          grid(iG)%ionDen(cellP,elementXref(2),1) = &
                               & 1.0 - grid(iG)%ionDen(cellP,elementXref(2),2)
                          grid(iG)%ionDen(cellP,elementXref(2),3) = 1.e-20
                       end if
                    end if

                    ! ---- metals (DEVLOG D-038) ---------------------------
                    ! MOCASSIN tracks min(elem+1, nstages) stages per element -
                    ! seven for carbon at the default nstages=7, not two. And
                    ! every consumer uses ionDen MULTIPLICATIVELY:
                    !   Np           = ionDen(...,1,2)*elemAbun(1)
                    !   forbidden    = ...*elemAbun(elem)*ionDen(...,elem,ion)
                    ! Nothing infers a stage by closure, so the stages summing to
                    ! one is an OUTPUT property of ionBalance, not an input
                    ! requirement.
                    !
                    ! That is what makes the molecular fraction easy rather than
                    ! awkward: carbon locked in CO simply does not appear in any
                    ! atomic stage. The fractions then sum to less than one, which
                    ! is exactly right - that carbon emits no atomic line and
                    ! contributes no free electron. Higher stages are set to
                    ! MOCASSIN's own floor since C2+ and the like are negligible
                    ! at PDR temperatures.
                    iAb = grid(iG)%abFileIndex(i,j,k)
                    call setIonPair(grid(iG), cellP, iAb,  6, NC,  NCx,  w)
                    call setIonPair(grid(iG), cellP, iAb,  8, NO,  NOx,  w)
                    call setIonPair(grid(iG), cellP, iAb, 12, NMG, NMGx, w)
                 end do
              end do
           end do
        end do

      end subroutine pdrToMocassin


      !-----------------------------------------------------------------
      ! Write one element's neutral and singly-ionised fractions into
      ! grid%ionDen, blended by w, and floor the higher stages.
      !
      ! The fractions are taken relative to MOCASSIN's own elemAbun so that
      ! ionDen*elemAbun reproduces the network's density directly. That is
      ! exact only if both codes use the same elemental abundances - the
      ! network's come from species_*.d and MOCASSIN's from its abundance
      ! file. They are clamped here, and reconciling them is an open item.
      !-----------------------------------------------------------------
      subroutine setIonPair(grid, cellP, iAb, elem, iNeut, iIon, w)
        implicit none

        type(grid_type), intent(inout) :: grid
        integer, intent(in)            :: cellP, iAb, elem, iNeut, iIon
        double precision, intent(in)   :: w

        integer          :: ion, nTop
        double precision :: tot, f0, f1

        if (elem > nElements) return
        if (.not.lgElementOn(elem)) return
        if (iNeut <= 0 .or. iIon <= 0) return

        tot = dble(grid%elemAbun(iAb, elem))
        if (tot <= 0.d0) return

        f0 = min(max(grid%pdrAbun(cellP,iNeut)/tot, 0.d0), 1.d0)
        f1 = min(max(grid%pdrAbun(cellP,iIon )/tot, 0.d0), 1.d0)

        grid%ionDen(cellP,elementXref(elem),1) = real( &
             & w*f0 + (1.d0-w)*dble(grid%ionDen(cellP,elementXref(elem),1)))
        grid%ionDen(cellP,elementXref(elem),2) = real( &
             & w*f1 + (1.d0-w)*dble(grid%ionDen(cellP,elementXref(elem),2)))

        nTop = min(elem+1, nStages)
        do ion = 3, nTop
           grid%ionDen(cellP,elementXref(elem),ion) = real( &
                & w*1.d-20 + (1.d0-w)*dble(grid%ionDen(cellP,elementXref(elem),ion)))
        end do

      end subroutine setIonPair

#endif
end module pdr_mod
