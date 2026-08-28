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
                              & pdrChemPath  => chemPath

    use global_module,    only : pdrMetalMod  => metallicity, &
                               & pdrOmega     => omega,       &
                               & pdrGrainRadM => grain_radius, &
                               & pdrNelect    => NELECT

    use chemistry_module, only : pdrRelTol => relative_abundance_tolerance, &
                               & pdrAbsTol => absolute_abundance_tolerance

    implicit none

    private
    public :: initPDRnetwork, seedPDR, calibratePDRdust, mocassinToPDR, pdrStep, pdrToMocassin

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

        ! Coolant filenames are resolved now, but coo stays 0 until Phase 4.
        ! read_species indexes coolant(1:coo) (read_species.F90:175), and that
        ! array is only allocated by read_coolants - which belongs with the
        ! level-population machinery. Setting coo here without calling
        ! read_coolants segfaults.
        do iS = 1, pdrNcool
           pdrCoolfile(iS) = trim(adjustl(pdrChemPath))//trim(adjustl(pdrCoolant(iS)))
        end do
        pdrCooMod = 0

        ! ---- read the network -------------------------------------------
        call allocations
        call read_species(pdrNspecMod, pdrSpecies, pdrInitAbun, pdrMass)
        call READ_RATES(pdrNreacMod, pdrReactant, pdrProduct, pdrAlpha, pdrBeta, &
             &          pdrGamma, pdrRate, pdrDuplicate, pdrRtmin, pdrRtmax)

        if (taskid == 0) then
           print*, "! initPDR: network '", trim(adjustl(pdrNetwork)), "' - ", &
                & pdrNspec, " species, ", pdrNreac, " reactions"
           print*, "! initPDR: chemistry data from ", trim(adjustl(pdrChemPath))
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
        integer :: iG, iCell

        do iG = 1, nGrids
           do iCell = 0, grid(iG)%nCells
              grid(iG)%pdrAbun(iCell,:) = pdrInitAbun(1:pdrNspec)
           end do
        end do

      end subroutine seedPDR



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
                    do iS = 1, nStars
                       dx = dble(grid(iG)%xAxis(i)) - dble(starPosition(iS)%x)
                       dy = dble(grid(iG)%yAxis(j)) - dble(starPosition(iS)%y)
                       dz = dble(grid(iG)%zAxis(k)) - dble(starPosition(iS)%z)
                       rr = sqrt(dx*dx + dy*dy + dz*dz)
                       if (rr > 0.d0) chi0 = chi0 + &
                            & Lfuv(iS)/(dble(fourPi)*rr*rr*dble(c)*dble(uDraine))
                    end do

                    ! Invert the measured attenuation into a genuine visual
                    ! extinction in magnitudes, using this model's own grains
                    ! (D-026). tau_FUV -> A_V = 1.0857*tau_FUV/R_FUV.
                    if (chi0 > chi .and. chi > 0.d0) then
                       tauFUV = -log(chi/chi0)
                       grid(iG)%AVeff(cellP) = &
                            & real(dble(magPerTau)*tauFUV/dble(pdrRfuv))
                    else
                       grid(iG)%AVeff(cellP) = 0.
                    end if

                    ! zone flag (D-007): PDR chemistry runs in the neutral gas
                    xHII = dble(grid(iG)%ionDen(cellP, elementXref(1), 2))
                    if (xHII < dble(pdrZoneLim)) then
                       grid(iG)%pdrZone(cellP) = 1
                    else
                       grid(iG)%pdrZone(cellP) = 0
                    end if

                 end do
              end do
           end do
        end do

      end subroutine mocassinToPDR


      !-----------------------------------------------------------------
      ! One cell of chemistry, level populations and thermal balance.
      ! PHASE 4 - deliberately a stub. See DEVLOG D-008: this must take only
      ! a few chemistry passes and let MOCASSIN's outer MC loop carry the
      ! convergence, rather than converging the PDR inside each iteration.
      !-----------------------------------------------------------------
      subroutine pdrStep(grid, xP, yP, zP)
        implicit none
        type(grid_type), intent(inout) :: grid
        integer, intent(in)            :: xP, yP, zP
        integer                        :: cellP

        cellP = grid%active(xP,yP,zP)
        if (cellP <= 0) return
        if (grid%pdrZone(cellP) == 0) return

        ! Phase 4: calculate_reaction_rates -> calculate_abundances ->
        !          coolingfunctions -> changetemperature

      end subroutine pdrStep


      !-----------------------------------------------------------------
      ! Push converged PDR state back into the MOCASSIN grid.
      ! PHASE 4 - deliberately a stub.
      !-----------------------------------------------------------------
      subroutine pdrToMocassin(grid)
        implicit none
        type(grid_type), dimension(:), intent(inout) :: grid
        integer :: iG

        do iG = 1, nGrids
           if (grid(iG)%nCells < 0) cycle   ! placeholder; Phase 4 fills this in
        end do

      end subroutine pdrToMocassin

#endif
end module pdr_mod
