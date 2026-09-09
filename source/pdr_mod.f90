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
    ! D-108: the Savage & Mathis extinction table SCATTER() splines, so it can
    ! be repopulated with this model's own grains.
    use uclpdr_module,    only : start, N_GRID, L_GRID, X_GRID

    use global_module,    only : pdrMetalMod  => metallicity, &
                               & pdrOmega     => omega,       &
                               & pdrGrainRadM => grain_radius, &
                               & pdrNelect    => NELECT,      &
                               ! D-075: NH must be renamed. It is the species
                               ! index for atomic H, but pdrStep declares a local
                               ! `nH` for the hydrogen density and Fortran is
                               ! CASE-INSENSITIVE, so inside that routine `NH`
                               ! resolved to the local double and abun(NH) indexed
                               ! a 33-element array at 1000. gfortran accepts the
                               ! real subscript as a legacy extension, silently.
                               & NH2, NC, NCO, pdrNHsp => NH, NPROTON, NHe, NHEx, &
                               & NCx, NO, NOx, NMG, NMGx

    ! D-113: per-species formation and destruction rates from the ODE RHS
    use chemistry_module, only : pdrFormSp => species_form, &
                               & pdrLossSp => species_loss
    use chemistry_module, only : pdrRelTol => relative_abundance_tolerance, &
                               & pdrAbsTol => absolute_abundance_tolerance

    ! CALC_HEATING's chemical-heating term needs this module's reaction indices
    ! built first; without it the term reads unset state (DEVLOG D-029).
    use chemical_heating_module, only : init_chemical_heating

    implicit none

    private
    public :: initPDRnetwork, seedPDR, calibratePDRdust, dustPerCell, computeAVdust, &
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
        character(len=50)  :: cname        ! D-131: coolant species, isotope stripped
        character(len=10)  :: sNeut, sIon  ! D-163: linked neutral / ion labels
        integer            :: iR, iLnk, jLnk   ! D-163
        logical            :: lgDupPhot, lgDupRec
        integer            :: ios, iS, iC
        logical            :: lgAtomic
        ! D-131. Element symbols, lower case. Cobalt is deliberately ABSENT -
        ! see the note where this is used.
        integer            :: nCharge
        ! atomic numbers matching elemSym, cobalt omitted (see the note there)
        integer, parameter :: elemZ(29) = (/ 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12, &
             & 13,14,15,16,17,18,19,20,21,22,23,24,25,26,28,29,30 /)
        character(len=2), parameter :: elemSym(29) = (/ &
             & 'h ','he','li','be','b ','c ','n ','o ','f ','ne','na','mg', &
             & 'al','si','p ','s ','cl','ar','k ','ca','sc','ti','v ','cr', &
             & 'mn','fe','ni','cu','zn' /)
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
        ! D-131. Decide, once, which coolants may be handed to MOCASSIN's
        ! thermal balance. MOCASSIN cools every heavy it has CEL data for, and
        ! that includes C I, C II, O I and O II - three of 3D-PDR's four
        ! standard coolants. Only molecules it has no line data for may be
        ! added. Anything unrecognised is EXCLUDED and reported: under-counting
        ! a coolant is recoverable, silently double counting one is not.
        do iS = 1, pdrNcool
           cname = trim(adjustl(pdrCoolant(iS)))
           iC = index(cname, '.')
           if (iC > 1) cname = cname(1:iC-1)
           ! strip an isotope prefix: 12co -> co, 13co -> co, 16o -> o
           iC = 1
           do while (iC <= len_trim(cname))
              if (cname(iC:iC) < '0' .or. cname(iC:iC) > '9') exit
              iC = iC + 1
           end do
           cname = cname(iC:)
           ! drop an ionization sign and any '-suffix' (cn-hfs -> cn)
           iC = index(cname, '-')
           if (iC > 1) cname = cname(1:iC-1)
           nCharge = 0
           iC = len_trim(cname)
           if (iC > 1) then
              if (cname(iC:iC) == '+') then
                 nCharge = 1; cname = cname(1:iC-1)
              else if (cname(iC:iC) == '-') then
                 cname = cname(1:iC-1)
              end if
           end if
           ! Decide by structure, not by a hand-kept list of molecules.
           ! MOCASSIN cools every heavy it has CEL data for, and that data is
           ! per ION of a single element - so a coolant duplicates MOCASSIN if
           ! and only if its carrier is one atom. Anything with two or more
           ! atoms (CO, OH, HCN, HCO+, CN, CH+, N2H+, C2H, HNC, SiO...) has no
           ! counterpart anywhere in MOCASSIN and must be added.
           !
           ! The one ambiguity is 'co': carbon monoxide, or cobalt. No PDR uses
           ! cobalt as a coolant and every 3D-PDR distribution ships 12co.dat,
           ! so 'co' is read as the molecule and cobalt is left out of the
           ! element list below with this note attached.
           lgAtomic = .false.
           do iC = 1, 29
              if (trim(cname) == trim(elemSym(iC))) then
                 lgAtomic = .true.
                 pdrCoolElem(iS) = elemZ(iC)
                 pdrCoolIon(iS)  = nCharge + 1     ! neutral -> stage 1
              end if
           end do
           pdrCoolIsMol(iS) = .not. lgAtomic
           if (taskid == 0) then
              if (pdrCoolIsMol(iS)) then
                 print*, "! initPDR: coolant ", trim(cname), &
                      & " molecular -> added to MOCASSIN's balance"
              else
                 print*, "! initPDR: coolant ", trim(cname), &
                      & " atomic -> REPLACES MOCASSIN's forbidden lines for ", &
                      & "elem", pdrCoolElem(iS), " stage", pdrCoolIon(iS), &
                      & " (MOCASSIN excites them with electrons alone)"
              end if
           end if
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

        ! D-118: which MOCASSIN ion each network species IS. MUST come after
        ! read_species: NCx, NC, NPROTON and the rest are resolved there, and
        ! are all zero before it. Built earlier at first, which produced a
        ! silently empty table - the count printed below is what caught it,
        ! and is why it is printed rather than assumed.
        !
        ! It must also NOT test lgElementOn: initPDRnetwork runs before
        ! setComposition, so that array is not populated yet. The guard that
        ! matters is in ionBalance's element loop, which skips elements that
        ! are off. Cloudy keeps the
        ! same table as chem_nuclide::ipMl and uses it to hand per-stage source
        ! and sink terms to the ion solver (D-111). The species indices are not
        ! arithmetic - He+ is 2, Mg is 3, H is 32 - so the map is explicit, and
        ! built from the index variables the network itself resolved rather
        ! than from literals, so a different species file cannot silently
        ! mis-assign a rate to the wrong element.
        pdrLinkSpec = 0; pdrLinkElem = 0; pdrLinkIon = 0
        call linkIon( 1, pdrNHsp,  1, 1)   ! H     -> H I
        call linkIon( 2, NPROTON,  1, 2)   ! H+    -> H II
        call linkIon( 3, NHe,      2, 1)   ! He    -> He I
        call linkIon( 4, NHEx,     2, 2)   ! He+   -> He II
        call linkIon( 5, NC,       6, 1)   ! C     -> C I
        call linkIon( 6, NCx,      6, 2)   ! C+    -> C II
        pdrIdxH2 = NH2; pdrIdxCO = NCO; pdrIdxCp = NCx; pdrIdxC = NC   ! D-178
        pdrIdxH  = pdrNHsp; pdrIdxHp = NPROTON                        ! D-196
        call linkIon( 7, NO,       8, 1)   ! O     -> O I
        call linkIon( 8, NOx,      8, 2)   ! O+    -> O II
        call linkIon( 9, NMG,     12, 1)   ! Mg    -> Mg I
        call linkIon(10, NMGx,    12, 2)   ! Mg+   -> Mg II
        if (taskid == 0) print*, "! [D118] chemistry/ion links established:", &
             & count(pdrLinkSpec > 0), "of", pdrNlink
        call READ_RATES(pdrNreacMod, pdrReactant, pdrProduct, pdrAlpha, pdrBeta, &
             &          pdrGamma, pdrRate, pdrDuplicate, pdrRtmin, pdrRtmax)

        ! D-163: MOCASSIN owns every ion stage, so the network must not compute
        ! them too. These are exactly the reactions Cloudy deletes from its own
        ! network data (`mole_co_base.dat`, "These would be double counted if
        ! included in the molecular network"): photoionization of a linked
        ! neutral, and radiative recombination of a linked ion.
        !
        ! Identified by structure, not by index, so a network change does not
        ! silently leave a duplicate behind: {X, PHOTON} -> {X+, e-} and
        ! {X+, e-} -> {X} for any X in the link table. Charge exchange and
        ! cosmic-ray channels are KEPT - MOCASSIN has no cosmic-ray ionization
        ! (D-035) and no charge exchange, so those are real physics only the
        ! network carries, and they reach the ion solver as source/sink terms
        ! through D-118.
        !
        ! Every suppression is printed, because silently deleting reactions from
        ! a chemical network is exactly the kind of change that should never be
        ! invisible in a run log.
        if (pdrIonFromMocassin /= 0 .and. taskid == 0) &
             & print*, "! initPDR: MOCASSIN owns the ion stages - suppressing &
             &duplicated network channels:"
        if (pdrIonFromMocassin /= 0) then
           do iR = 1, pdrNreacMod
              lgDupPhot = .false.; lgDupRec = .false.
              do iLnk = 1, pdrNlink
                 if (pdrLinkSpec(iLnk) <= 0) cycle
                 sNeut = ''; sIon = ''
                 if (pdrLinkIon(iLnk) == 1) then
                    sNeut = adjustl(pdrSpecies(pdrLinkSpec(iLnk)))
                    do jLnk = 1, pdrNlink
                       if (pdrLinkElem(jLnk) == pdrLinkElem(iLnk) .and. &
                            & pdrLinkIon(jLnk) == 2 .and. pdrLinkSpec(jLnk) > 0) &
                            & sIon = adjustl(pdrSpecies(pdrLinkSpec(jLnk)))
                    end do
                 end if
                 if (len_trim(sNeut) == 0 .or. len_trim(sIon) == 0) cycle
                 ! photoionization of the neutral
                 if (any(adjustl(pdrReactant(iR,:)) == sNeut) .and. &
                      & any(adjustl(pdrReactant(iR,:)) == 'PHOTON') .and. &
                      & any(adjustl(pdrProduct(iR,:)) == sIon)) lgDupPhot = .true.
                 ! RADIATIVE recombination of the ion - and only that.
                 ! MOCASSIN's alphaTot is radiative recombination; it has no
                 ! recombination of ions on grain surfaces. Those are written
                 ! with the grain marker '#' as a reactant and product:
                 !   330,He+,e-,#,He,#     alpha 5.20E-17
                 !   331,C+ ,e-,#,C ,#     alpha 5.20E-17
                 ! and they belong with charge exchange and cosmic rays as
                 ! physics only the network carries. Requiring PHOTON among the
                 ! products separates the two - the radiative channels are
                 ! written 242,H+,e-,,H,PHOTON and 244,C+,e-,,C,PHOTON.
                 if (any(adjustl(pdrReactant(iR,:)) == sIon) .and. &
                      & any(adjustl(pdrReactant(iR,:)) == 'e-') .and. &
                      & any(adjustl(pdrProduct(iR,:)) == sNeut) .and. &
                      & any(adjustl(pdrProduct(iR,:)) == 'PHOTON') .and. &
                      & .not. any(adjustl(pdrReactant(iR,:)) == '#')) lgDupRec = .true.
              end do
              if (lgDupPhot .or. lgDupRec) then
                 if (taskid == 0) print*, "!   reaction", iR, " ", &
                      & trim(adjustl(pdrReactant(iR,1))), " + ", &
                      & trim(adjustl(pdrReactant(iR,2))), " -> ", &
                      & trim(adjustl(pdrProduct(iR,1))), &
                      & merge("  (photoionization)", "  (recombination)  ", lgDupPhot)
                 pdrAlpha(iR) = 0.d0
              end if
           end do
        end if

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

           ! D-188: this is now only a fallback for inactive cells and for the
           ! shielding columns computed before the chemistry first runs. Every
           ! active cell is re-seeded from MOCASSIN's ionization state on its
           ! first visit in pdrStep, so the network file's x(H2) = 0.3 never
           ! reaches a cell the chemistry actually solves.
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
      !-----------------------------------------------------------------
      ! D-118: record that network species iSp is MOCASSIN's (elem, ion).
      ! A species the network does not carry leaves the slot at zero, which
      ! consumers read as "no chemical terms for this stage" - Cloudy's
      ! ipMl == -1 rule, and what lets a singly-ionized network couple to a
      ! seven-stage ion solver with no special case anywhere.
      !-----------------------------------------------------------------
      subroutine linkIon(slot, iSp, elem, ion)
        implicit none
        integer, intent(in) :: slot, iSp, elem, ion

        if (iSp <= 0 .or. iSp > pdrNspec) return
        if (elem > nElements) return
        pdrLinkSpec(slot) = iSp
        pdrLinkElem(slot) = elem
        pdrLinkIon (slot) = ion
      end subroutine linkIon


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
      ! D-109: measure the dust properties SEPARATELY IN EVERY CELL.
      !
      ! calibratePDRdust used to read absOpac at one cell - literally the first
      ! in array order that carried any dust - and hand the resulting A_V per
      ! N_H and tau_FUV/tau_V to the chemistry for the whole model. That is only
      ! correct if every cell has the same dust-to-gas ratio and the same grain
      ! mixture, and nothing checked that it did: an unrepresentative cell
      ! silently rescaled every H2/CO shielding column in the run.
      !
      ! It is also the wrong division of labour. MOCASSIN owns the radiation
      ! field and the grains; 3D-PDR owns the chemistry. MOCASSIN should
      ! therefore report what the dust is doing AT THE CELL the chemistry is
      ! being solved in, exactly as it already does for chi, A_V and T_dust.
      ! D-109 diagnostic: locate the least-opaque dusty cell and report what
      ! its grains are doing, so a non-uniform model can be diagnosed.
      subroutine reportExtreme(grid, aTarget)
        implicit none
        type(grid_type), dimension(:), intent(in) :: grid
        double precision, intent(in) :: aTarget
        integer :: iG, i, j, k, cP, nS, ai, nHot, nMask
        double precision :: aLoc, tMax

        do iG = 1, nGrids
           do i = 1, grid(iG)%nx
              do j = 1, grid(iG)%ny
                 do k = 1, grid(iG)%nz
                    cP = grid(iG)%active(i,j,k)
                    if (cP <= 0) cycle
                    aLoc = dble(grid(iG)%dustAVfac(cP))
                    if (aLoc <= 0.d0) cycle
                    if (abs(aLoc - aTarget) > 1.d-6*aTarget) cycle

                    tMax = 0.d0; nHot = 0; nMask = 0
                    do nS = 1, nSpeciesPart(1)
                       do ai = 1, nSizes
                          tMax = max(tMax, dble(grid(iG)%Tdust(nS,ai,cP)))
                          if (grid(iG)%Tdust(nS,ai,cP) >= &
                            & TdustSublime(dustComPoint(1)-1+nS)) nMask = nMask + 1
                          nHot = nHot + 1
                       end do
                    end do
                    print*, "! [D109]   least-opaque cell at (i,j,k) =", i, j, k
                    print*, "! [D109]     Hden =", grid(iG)%Hden(cP), &
                         & "  Ndust =", grid(iG)%Ndust(cP)
                    print*, "! [D109]     max T_dust =", real(tMax), &
                         & " K;  grain sizes above T_sublime:", nMask, "of", nHot
                    return
                 end do
              end do
           end do
        end do
      end subroutine reportExtreme


      subroutine dustPerCell(grid)
        implicit none

        type(grid_type), dimension(:), intent(inout) :: grid

        integer          :: iG, cP, ifreq
        double precision :: kV, kFUV, wsum
        double precision :: wt(nbins)

        ! the emitted-energy weights are a property of the source spectrum, not
        ! of the cell - build them once (see the band-average note below)
        wt = 0.d0
        wsum = 0.d0
        do ifreq = FUVlowP, FUVhighP
           if (ifreq > 1) then
              wt(ifreq) = dble(inSpectrumProbDen(1,ifreq)) &
                        & - dble(inSpectrumProbDen(1,ifreq-1))
           else
              wt(ifreq) = dble(inSpectrumProbDen(1,ifreq))
           end if
           if (wt(ifreq) < 0.d0) wt(ifreq) = 0.d0
           wsum = wsum + wt(ifreq)
        end do
        if (wsum <= 0.d0) return

        do iG = 1, nGrids
           do cP = 0, grid(iG)%nCells
              grid(iG)%dustAVfac(cP) = 0.
              grid(iG)%dustRfuv(cP)  = 0.

              kV = dble(grid(iG)%absOpac(cP,VbandP)) &
                 & + dble(grid(iG)%scaOpac(cP,VbandP))
              if (kV <= 0.d0) cycle          ! no dust here; consumers fall back

              kFUV = 0.d0
              do ifreq = FUVlowP, FUVhighP
                 if (wt(ifreq) <= 0.d0) cycle
                 kFUV = kFUV + wt(ifreq)*(dble(grid(iG)%absOpac(cP,ifreq)) &
                      &                 + dble(grid(iG)%scaOpac(cP,ifreq)))
              end do
              kFUV = kFUV/wsum
              if (kFUV <= 0.d0) cycle

              grid(iG)%dustRfuv(cP) = real(kFUV/kV)
              if (grid(iG)%Hden(cP) > 0.) &
                 & grid(iG)%dustAVfac(cP) = &
                 & real(dble(magPerTau)*kV/dble(grid(iG)%Hden(cP)))
           end do
        end do

      end subroutine dustPerCell


      subroutine calibratePDRdust(grid)
        implicit none

        ! inout, not in: dustPerCell fills the per-cell arrays below (D-109)
        type(grid_type), dimension(:), intent(inout) :: grid

        integer          :: iG, iCell, ifreq, nUsed
        double precision :: kFUV, kV, wsum, w, kabs, ksca, gbar
        integer          :: iL, nOwn, i       ! D-108
        double precision :: nuL, kLam       ! D-108
        integer          :: cP, nDusty                                ! D-109
        double precision :: aLoc, aSum, aWt, aMin, aMax, dBest, dHere ! D-109

        ! D-109: the per-cell arrays are the values the chemistry actually
        ! uses. Everything below only derives the model-wide REPRESENTATIVE
        ! numbers - reported here, used as the fallback where a cell carries no
        ! dust, and used to seed the vendored module before the first cell.
        call dustPerCell(grid)

        ! Representative cell = the dusty cell whose A_V per N_H sits closest to
        ! the density-weighted mean, NOT whichever cell happened to come first
        ! in array order. If the model's dust-to-gas is uniform these are the
        ! same cell and nothing changes; if it is not, this is the cell that
        ! best describes the model, and the spread printed below says how much
        ! trust the single number deserves.
        aSum = 0.d0; aWt = 0.d0; nDusty = 0
        aMin = huge(1.d0); aMax = 0.d0
        do iG = 1, nGrids
           do cP = 0, grid(iG)%nCells
              aLoc = dble(grid(iG)%dustAVfac(cP))
              if (aLoc <= 0.d0) cycle
              w    = dble(grid(iG)%Hden(cP))
              aSum = aSum + w*aLoc
              aWt  = aWt  + w
              aMin = min(aMin, aLoc)
              aMax = max(aMax, aLoc)
              nDusty = nDusty + 1
           end do
        end do

        if (nDusty == 0 .or. aWt <= 0.d0) then
           print*, "! calibratePDRdust: no cell carries dust opacity - cannot"
           print*, "!   calibrate A_V. PDR runs require dust (DEVLOG D-019)."
           stop
        end if

        aSum  = aSum/aWt
        iCell = -1
        dBest = huge(1.d0)
        do iG = 1, nGrids
           do cP = 0, grid(iG)%nCells
              aLoc = dble(grid(iG)%dustAVfac(cP))
              if (aLoc <= 0.d0) cycle
              dHere = abs(aLoc - aSum)
              if (dHere < dBest) then
                 dBest = dHere
                 iCell = cP
              end if
           end do
           if (iCell >= 0) exit
        end do

        if (taskid == 0) then
           print*, "! [D109] dust measured per cell:", nDusty, "dusty cells,", &
                & " A_V/N_H mean =", real(aSum)
           if (aMax > 1.0001d0*aMin) then
              print*, "! [D109]   spread over the model: min =", real(aMin), &
                   & " max =", real(aMax), " (ratio", real(aMax/aMin), ")"
              print*, "! [D109]   the chemistry uses each cell's own value;", &
                   & " the mean is only a fallback"
              ! say WHERE the extreme is and what the grains are doing there,
              ! so a spread can be diagnosed instead of merely noted
              call reportExtreme(grid, aMin)
           else
              print*, "! [D109]   uniform to 1 part in 1e4 across the model"
           end if
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
        ! D-073: the FUV albedo and asymmetry set how fast the DIFFUSE field
        ! decays: exp(-tau*sqrt(3(1-w)(1-wg))). Report them alongside R_FUV so
        ! the measured gamma_eff can be checked against diffusion theory.
        if (taskid == 0) then
           kabs = 0.d0; ksca = 0.d0; wsum = 0.d0; gbar = 0.d0
           do ifreq = FUVlowP, FUVhighP
              if (ifreq > 1) then
                 w = dble(inSpectrumProbDen(1,ifreq)) - dble(inSpectrumProbDen(1,ifreq-1))
              else
                 w = dble(inSpectrumProbDen(1,ifreq))
              end if
              if (w <= 0.d0) cycle
              kabs = kabs + w*dble(grid(1)%absOpac(iCell,ifreq))
              ksca = ksca + w*dble(grid(1)%scaOpac(iCell,ifreq))
              ! scattering-weighted: g only matters where light actually scatters
              gbar = gbar + w*dble(grid(1)%scaOpac(iCell,ifreq))*dble(gSca(ifreq))
              wsum = wsum + w
           end do
           if (wsum > 0.d0) then
              if (ksca > 0.d0) gbar = gbar/ksca
              kabs = kabs/wsum; ksca = ksca/wsum
              ! D-089: these two set how much shallower the transported field
              ! decays than 3D-PDR's scattering-free exp(-3.02 A_V). Forward
              ! scattering keeps photons in the beam, so the effective
              ! extinction is reduced by (1 - albedo*g); the measured gamma_eff
              ! should sit between that reduction and the full extinction value.
              print*, "! [D073] FUV albedo =", real(ksca/max(kabs+ksca,1.d-99)), &
                   & " asymmetry g =", real(gbar)
           end if
        end if
        end if

        if (kV <= 0.d0 .or. kFUV <= 0.d0) then
           print*, "! calibratePDRdust: non-positive dust opacity at V or FUV"
           stop
        end if

        pdrRfuv = real(kFUV/kV)
        if (taskid == 0) print*, "! [D073] kFUV/kV = R_FUV =", pdrRfuv, &
             & "  kV =", real(kV), "  kFUV =", real(kFUV)

        ! D-108: give the H2 and CO photorate shielding THIS model's grains.
        !
        ! 3D-PDR's SCATTER() converts A_V to tau(lambda) through XLAMBDA, which
        ! splines a fixed Savage & Mathis (1979) extinction curve - so those
        ! rates were attenuated on a literature dust law no matter what grains
        ! the model actually has, while the field heating the gas is transported
        ! through the real ones. Invisible in the benchmark only because D-073
        ! happened to tune R_FUV close to that curve; wrong for any other dust.
        !
        ! X_GRID is a saved module array that XLAMBDA splines, so repopulating
        ! it with k(lambda)/k(V) measured from absOpac+scaOpac - dust only, the
        ! same arrays kV and kFUV come from - redirects every caller (H2, CO,
        ! C I, S I) onto the model's own extinction with no change to the
        ! vendored routines. START is reset so the spline is rebuilt from it.
        if (pdrOwnDust /= 0) then
           nOwn = 0
           do iL = 1, N_GRID
              ! L_GRID is in Angstrom; nuArray in Ryd, lambda = 911.76/nu
              nuL = 911.76d0/L_GRID(iL)
              if (nuL < dble(nuArray(1)) .or. nuL > dble(nuArray(nbins))) cycle
              ifreq = 1
              do i = 2, nbins
                 if (abs(dble(nuArray(i))-nuL) < abs(dble(nuArray(ifreq))-nuL)) ifreq = i
              end do
              kLam = dble(grid(1)%absOpac(iCell,ifreq)) + dble(grid(1)%scaOpac(iCell,ifreq))
              if (kLam <= 0.d0) cycle
              X_GRID(iL) = kLam/kV
              nOwn = nOwn + 1
           end do
           start = .true.
           if (taskid == 0) then
              print*, "! [D108] H2/CO shielding now uses this model's dust:", &
                   & nOwn, " of", N_GRID, " extinction points replaced"
              print*, "! [D108]   tau(1000A)/tau(V): Savage & Mathis 4.65, this model", &
                   & real(X_GRID(3))
           end if
        end if
        if (taskid == 0) print*, "! [D077] FUV band bins:", FUVhighP-FUVlowP+1, &
             & " of", nbins, " (FUVlowP,FUVhighP =", FUVlowP, FUVhighP, &
             & ") nu =", real(nuArray(FUVlowP)), real(nuArray(FUVhighP))

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
      !-----------------------------------------------------------------
      ! D-087: geometric A_V for a NON plane-parallel geometry.
      !
      ! The spherical path used to define A_V by inverting the Monte Carlo
      ! field, AVeff = 1.0857*(-ln(chi/chi0))/R_FUV. That under-reads the dust
      ! column, because the transported field carries scattered light: measured
      ! against the geometric column in the spherical H II + PDR model it came
      ! out 1.386 where the column gives 2.487, low by a factor of 1.8 (D-086).
      ! The slab saw the same thing as gamma_eff = 1.86 per magnitude against
      ! the 3.02 of pure extinction.
      !
      ! D-054 fixed this for plane-parallel illumination by integrating the dust
      ! column directly, which is also what TORUS-3DPDR does - A_V ray-traced
      ! from the density field, never inverted from the field. This is the same
      ! correction for the geometry that was left behind: walk from each source
      ! to the cell, accumulating extinction.
      !
      ! With several sources the effective A_V is the one that reproduces the
      ! summed transmitted flux, so it reduces to the plain column for a single
      ! source:
      !
      !   A_V,eff = -(1.0857/R_FUV) ln( SUM_s f_s e^{-R_FUV A_V,s/1.0857}
      !                                 / SUM_s f_s )
      !-----------------------------------------------------------------
      subroutine computeAVradial(grid)
        implicit none

        type(grid_type), dimension(:), intent(inout) :: grid

        integer          :: iG, i, j, k, cellP, iS, istep, nstep, ix, iy, iz
        integer          :: cP, nback
        double precision :: sx, sy, sz, dxs, dys, dzs, seg, ds, tauS, fS
        double precision :: fSum, fTot, kap, rr, avS
        double precision :: cH2S, cCS, cCOS, wH2, wC, wCO, tauB, wB, span, nd
        double precision :: RfuvL                          ! D-109

        if (pdrRfuv <= 0.) return

        do iG = 1, nGrids
           do i = 1, grid(iG)%nx
              do j = 1, grid(iG)%ny
                 do k = 1, grid(iG)%nz
                    cellP = grid(iG)%active(i,j,k)
                    if (cellP <= 0) cycle

                    ! D-109: A_V is defined by the grains AT THIS CELL. The
                    ! per-ray sum below inverts exp(-R_FUV*A_V) to an effective
                    ! A_V, so it must invert it with the same R_FUV the
                    ! chemistry will then use here.
                    RfuvL = dble(grid(iG)%dustRfuv(cellP))
                    if (RfuvL <= 0.d0) RfuvL = dble(pdrRfuv)

                    fSum = 0.d0
                    fTot = 0.d0
                    wH2  = 0.d0
                    wC   = 0.d0
                    wCO  = 0.d0
                    wB   = 0.d0
                    do iS = 1, nStars
                       sx = dble(starPosition(iS)%x)
                       sy = dble(starPosition(iS)%y)
                       sz = dble(starPosition(iS)%z)
                       dxs = dble(grid(iG)%xAxis(i)) - sx
                       dys = dble(grid(iG)%yAxis(j)) - sy
                       dzs = dble(grid(iG)%zAxis(k)) - sz
                       seg = sqrt(dxs*dxs + dys*dys + dzs*dzs)
                       if (seg <= 0.d0) cycle

                       ! march from the source to the cell centre; the step is
                       ! set by the finest axis spacing so no cell is skipped
                       nstep = max(8, min(400, int(seg/max( &
                            & abs(dble(grid(iG)%xAxis(min(2,grid(iG)%nx))) &
                            &    -dble(grid(iG)%xAxis(1))), 1.d0))))
                       ds   = seg/dble(nstep)
                       tauS = 0.d0
                       cH2S = 0.d0
                       cCS  = 0.d0
                       cCOS = 0.d0
                       do istep = 1, nstep
                          rr = (dble(istep)-0.5d0)*ds
                          ix = nearestAx(grid(iG)%xAxis, grid(iG)%nx, &
                               & real(sx + dxs*rr/seg))
                          iy = nearestAx(grid(iG)%yAxis, grid(iG)%ny, &
                               & real(sy + dys*rr/seg))
                          iz = nearestAx(grid(iG)%zAxis, grid(iG)%nz, &
                               & real(sz + dzs*rr/seg))
                          if (grid(iG)%active(ix,iy,iz) <= 0) cycle
                          cP  = grid(iG)%active(ix,iy,iz)
                          kap = dble(grid(iG)%absOpac(cP,VbandP)) &
                              & + dble(grid(iG)%scaOpac(cP,VbandP))
                          tauS = tauS + kap*ds

                          ! D-088: integrate the SHIELDING COLUMNS along the
                          ! same ray. computeAVradial used to fill AVeff only,
                          ! so every radial model fell through to the
                          ! NHcol*abun(X) fallback - the local abundance times
                          ! the whole column back to the star, H II region
                          ! included. That is the D-078 error again, and it is
                          ! far larger here: it self-shields H2 from the first
                          ! PDR cell on.
                          ! only PDR cells shield. Elsewhere pdrAbun still
                          ! holds seedPDR's values - x(H2) = 0.3, x(C) and
                          ! x(CO) likewise - because the chemistry is never
                          ! solved there, and integrating those across the H II
                          ! region puts ~1e21 cm^-2 of fictitious H2 in front
                          ! of the first PDR cell. In the ionized gas the
                          ! molecules are dissociated and carbon is C+ or
                          ! higher, so the true shielding column is zero.
                          ! ...and only cells IN FRONT of this one. Including
                          ! the target cell's own near half makes its H2 shield
                          ! itself, and that feedback is positive: more H2 ->
                          ! less dissociation -> more H2. On 3D-PDR's grid the
                          ! half-cell column is ~1e13 cm^-2 and the effect is
                          ! nil; on a 2e18 cm MOCASSIN cell it is 4e18 cm^-2,
                          ! enough to shield the surface cell completely, and
                          ! the solver settles on that runaway branch. The
                          ! near-face column removes the self-term; it lags the
                          ! true centre column by half a cell, which is an
                          ! error that shrinks with resolution instead of
                          ! amplifying.
                          if (cP /= cellP .and. grid(iG)%pdrZone(cP) == 1) then
                             nd   = dble(grid(iG)%Hden(cP))
                             cH2S = cH2S + nd*dble(grid(iG)%pdrAbun(cP,NH2))*ds
                             cCS  = cCS  + nd*dble(grid(iG)%pdrAbun(cP,NC ))*ds
                             cCOS = cCOS + nd*dble(grid(iG)%pdrAbun(cP,NCO))*ds
                          end if
                       end do

                       ! remaining column outwards, along the same direction,
                       ! to the grid boundary: what the outward escape rays see
                       span  = dble(grid(iG)%xAxis(grid(iG)%nx)) &
                             & - dble(grid(iG)%xAxis(1))
                       nback = max(4, min(200, int(span/ds)))
                       tauB  = 0.d0
                       do istep = 1, nback
                          rr = seg + (dble(istep)-0.5d0)*ds
                          ix = nearestAx(grid(iG)%xAxis, grid(iG)%nx, &
                               & real(sx + dxs*rr/seg))
                          iy = nearestAx(grid(iG)%yAxis, grid(iG)%ny, &
                               & real(sy + dys*rr/seg))
                          iz = nearestAx(grid(iG)%zAxis, grid(iG)%nz, &
                               & real(sz + dzs*rr/seg))
                          if (grid(iG)%active(ix,iy,iz) <= 0) cycle
                          tauB = tauB &
                               & + (dble(grid(iG)%absOpac(grid(iG)%active(ix,iy,iz),VbandP)) &
                               &  + dble(grid(iG)%scaOpac(grid(iG)%active(ix,iy,iz),VbandP)))*ds
                       end do

                       avS  = dble(magPerTau)*tauS
                       fS   = 1.d0/(seg*seg)          ! geometric dilution only
                       fTot = fTot + fS
                       fSum = fSum + fS*exp(-RfuvL*avS/dble(magPerTau))
                       wH2  = wH2 + fS*cH2S
                       wC   = wC  + fS*cCS
                       wCO  = wCO + fS*cCOS
                       wB   = wB  + fS*dble(magPerTau)*tauB
                    end do

                    if (fTot > 0.d0 .and. fSum > 0.d0) then
                       grid(iG)%AVeff(cellP) = real( &
                            & -dble(magPerTau)/RfuvL*log(fSum/fTot))
                       ! flux-weighted columns (exact for a single source)
                       grid(iG)%pdrColH2(cellP) = real(wH2/fTot)
                       grid(iG)%pdrColC (cellP) = real(wC /fTot)
                       grid(iG)%pdrColCO(cellP) = real(wCO/fTot)
                       grid(iG)%AVback  (cellP) = real(wB /fTot)
                    end if
                 end do
              end do
           end do
        end do

      contains

        ! nearest axis index to a coordinate; a contained helper so this
        ! routine does not depend on MOCASSIN's `locate` (D-087)
        integer function nearestAx(ax, n, v)
          implicit none
          real, intent(in) :: ax(:)
          integer, intent(in) :: n
          real, intent(in) :: v
          integer :: lo, hi, mid
          lo = 1; hi = n
          do while (hi - lo > 1)
             mid = (lo + hi)/2
             if (v >= ax(mid)) then
                lo = mid
             else
                hi = mid
             end if
          end do
          if (abs(v-ax(hi)) < abs(v-ax(lo))) then
             nearestAx = hi
          else
             nearestAx = lo
          end if
        end function nearestAx

      end subroutine computeAVradial

#ifdef RAYTHEIA
      !-----------------------------------------------------------------
      ! D-190: per-ray shielding columns, ray-traced through the grid.
      !
      ! The 3D build gives every HEALPix ray a real path length, but every
      ! ray's COLUMN still came from the plane-parallel closed form, and all
      ! twelve shielding columns were filled with the single source-ward scalar
      ! computeAVradial had traced. That is a slab answer inside a 3D model,
      ! and the shielding column is what sets the molecular content.
      !
      ! Here each ray is walked outward from the cell centre to the grid
      ! boundary through the actual grid. Twelve traces per cell, once per MC
      ! iteration - the work computeAVradial already does, times twelve.
      !
      ! Directions are the twelve HEALPix nside=1 pixel centres in RING order,
      ! constructed directly: the vendored pix2vec_nest is never called and its
      ! pix2x/pix2y tables are never initialised. RING keeps the convention the
      ! rest of pdr_mod assumes - rays 0-3 at mu = +2/3, 4-7 at 0, 8-11 at -2/3.
      !-----------------------------------------------------------------
      subroutine computeRayColumns(grid)
        implicit none
        type(grid_type), intent(inout) :: grid(*)

        integer :: iG, i, j, k, kray, istep, nstep, ix, iy, iz, cP, cellP
        double precision :: vx(0:11), vy(0:11), vz(0:11)
        double precision :: zz, ph, sr, ds, rr, px, py, pz, dmax
        double precision :: cH2, cC, cCO, cAV, nd, kap

        do kray = 0, 11
           if (kray < 4) then
              zz =  2.d0/3.d0; ph = (dble(kray)  +0.5d0)*pi*0.5d0
           else if (kray < 8) then
              zz =  0.d0     ; ph =  dble(kray-4)       *pi*0.5d0
           else
              zz = -2.d0/3.d0; ph = (dble(kray-8)+0.5d0)*pi*0.5d0
           end if
           sr = sqrt(max(1.d0 - zz*zz, 0.d0))
           vx(kray) = sr*cos(ph); vy(kray) = sr*sin(ph); vz(kray) = zz
        end do

        do iG = 1, nGrids
           if (.not.allocated(grid(iG)%colRayH2)) cycle
           ds = abs(dble(grid(iG)%xAxis(min(2,grid(iG)%nx))) &
                & - dble(grid(iG)%xAxis(1)))
           if (grid(iG)%ny > 1) ds = min(ds, abs(dble(grid(iG)%yAxis(2)) &
                & - dble(grid(iG)%yAxis(1))))
           if (grid(iG)%nz > 1) ds = min(ds, abs(dble(grid(iG)%zAxis(2)) &
                & - dble(grid(iG)%zAxis(1))))
           if (ds <= 0.d0) cycle
           dmax = sqrt( dble(grid(iG)%xAxis(grid(iG)%nx))**2 &
                &     + dble(grid(iG)%yAxis(grid(iG)%ny))**2 &
                &     + dble(grid(iG)%zAxis(grid(iG)%nz))**2 )
           nstep = max(4, min(2000, int(dmax/ds) + 1))

           do i = 1, grid(iG)%nx
            do j = 1, grid(iG)%ny
             do k = 1, grid(iG)%nz
              cellP = grid(iG)%active(i,j,k)
              if (cellP <= 0) cycle
              if (mod(cellP-(taskid+1), numtasks) /= 0) cycle
              do kray = 0, 11
                 cH2 = 0.d0; cC = 0.d0; cCO = 0.d0; cAV = 0.d0
                 do istep = 1, nstep
                    rr = (dble(istep)-0.5d0)*ds
                    px = dble(grid(iG)%xAxis(i)) + vx(kray)*rr
                    py = dble(grid(iG)%yAxis(j)) + vy(kray)*rr
                    pz = dble(grid(iG)%zAxis(k)) + vz(kray)*rr
                    if (px < dble(grid(iG)%xAxis(1)) .or. &
                      & px > dble(grid(iG)%xAxis(grid(iG)%nx)) .or. &
                      & py < dble(grid(iG)%yAxis(1)) .or. &
                      & py > dble(grid(iG)%yAxis(grid(iG)%ny)) .or. &
                      & pz < dble(grid(iG)%zAxis(1)) .or. &
                      & pz > dble(grid(iG)%zAxis(grid(iG)%nz))) exit
                    ix = nearestAxG(grid(iG)%xAxis, grid(iG)%nx, real(px))
                    iy = nearestAxG(grid(iG)%yAxis, grid(iG)%ny, real(py))
                    iz = nearestAxG(grid(iG)%zAxis, grid(iG)%nz, real(pz))
                    cP = grid(iG)%active(ix,iy,iz)
                    if (cP <= 0) cycle
                    nd  = dble(grid(iG)%Hden(cP))
                    cH2 = cH2 + nd*dble(grid(iG)%pdrAbun(cP,pdrIdxH2))*ds
                    cC  = cC  + nd*dble(grid(iG)%pdrAbun(cP,pdrIdxC ))*ds
                    cCO = cCO + nd*dble(grid(iG)%pdrAbun(cP,pdrIdxCO))*ds
                    kap = dble(grid(iG)%absOpac(cP,VbandP)) &
                        & + dble(grid(iG)%scaOpac(cP,VbandP))
                    cAV = cAV + kap*ds
                 end do
                 grid(iG)%colRayH2(cellP,kray) = real(cH2)
                 grid(iG)%colRayC (cellP,kray) = real(cC)
                 grid(iG)%colRayCO(cellP,kray) = real(cCO)
                 grid(iG)%colRayAV(cellP,kray) = real(1.0857d0*cAV)
              end do
             end do
            end do
           end do
        end do

      end subroutine computeRayColumns

      integer function nearestAxG(ax, n, v)
        implicit none
        real, intent(in) :: ax(*)
        integer, intent(in) :: n
        real, intent(in) :: v
        integer :: m
        nearestAxG = 1
        do m = 1, n
           if (abs(ax(m)-v) < abs(ax(nearestAxG)-v)) nearestAxG = m
        end do
      end function nearestAxG
#endif


      subroutine computeAVdust(grid)
        implicit none

        type(grid_type), dimension(:), intent(inout) :: grid

        integer          :: iG, i, j, k, cellP, yTop, jStart
        double precision :: tau, dy, kap, cH2, cC, cCO
        integer          :: iS, istep, nstep, ix, iy, iz
        double precision :: sx, sy, sz, dxs, dys, dzs, seg, ds, tauS, fS, fSum, fTot

        if (.not.lgPlaneIonization) then
           call computeAVradial(grid)
           return
        end if

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
                 cH2 = 0.d0; cC = 0.d0; cCO = 0.d0
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

                    ! D-078: integrate the SHIELDING COLUMNS the same way.
                    ! They used to be formed as NHcol*abun(X) - the LOCAL
                    ! abundance times the TOTAL column - where 3D-PDR
                    ! integrates the real column along its rays. Wherever the
                    ! abundance rises with depth, which is precisely what H2, C
                    ! and CO do across their own fronts, that overestimates the
                    ! column (about 2x at the H/H2 front, where x(H2) climbs
                    ! from ~0 to 0.25 while the local value is applied over the
                    ! whole path). Too much self-shielding lets the species
                    ! survive shallower, which is the ~20% shallow bias seen in
                    ! both the H/H2 and C+/C fronts.
                    if (cellP > 0) then
                       cH2 = cH2 + dble(grid(iG)%Hden(cellP)) &
                            & *dble(grid(iG)%pdrAbun(cellP,NH2))*dy*0.5d0
                       cC  = cC  + dble(grid(iG)%Hden(cellP)) &
                            & *dble(grid(iG)%pdrAbun(cellP,NC ))*dy*0.5d0
                       cCO = cCO + dble(grid(iG)%Hden(cellP)) &
                            & *dble(grid(iG)%pdrAbun(cellP,NCO))*dy*0.5d0
                       grid(iG)%pdrColH2(cellP) = real(cH2)
                       grid(iG)%pdrColC (cellP) = real(cC)
                       grid(iG)%pdrColCO(cellP) = real(cCO)
                       cH2 = cH2 + dble(grid(iG)%Hden(cellP)) &
                            & *dble(grid(iG)%pdrAbun(cellP,NH2))*dy*0.5d0
                       cC  = cC  + dble(grid(iG)%Hden(cellP)) &
                            & *dble(grid(iG)%pdrAbun(cellP,NC ))*dy*0.5d0
                       cCO = cCO + dble(grid(iG)%Hden(cellP)) &
                            & *dble(grid(iG)%pdrAbun(cellP,NCO))*dy*0.5d0
                    end if
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
                    ! D-087: the chi/chi0 inversion is NO LONGER used. It
                    ! under-reads the dust column because the transported field
                    ! carries scattered light - measured 1.386 against a
                    ! geometric 2.487 in the spherical model (D-086).
                    ! computeAVradial now integrates the column from each source
                    ! for this geometry, exactly as computeAVdust does for the
                    ! plane-parallel case (D-054), and has already run this
                    ! iteration (iteration_mod.f90:779). Overwriting it here was
                    ! why adding computeAVradial changed nothing at first.

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


#ifdef RAYTHEIA
        ! D-190: with the grid's abundances current, retrace the per-ray
        ! shielding columns before the chemistry consumes them.
        call computeRayColumns(grid)
#endif

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
        logical            :: lgChemOnly   ! D-131: outside the zone, chemistry only
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
        double precision   :: nH, Tg, Td, chi, chiLoc, av, NHcol, sH2, sC, sCO
        double precision   :: chiHeat
        double precision   :: AVfacL, RfuvL          ! this cell's own dust (D-109)
        integer            :: cellP, NRGR, NR2, NR3, NR4, NR5, NR6, it
        integer            :: iLnk, jLnk, iSpN, iSpI      ! D-153
        double precision   :: availTot, mocNeut, mocIon   ! D-153
        integer            :: iTpass                     ! D-166
        integer            :: iEl                        ! D-188
        integer            :: iRay                       ! D-190
        double precision   :: Tc, coolTot2, coolTot3     ! D-166

        cellP = grid%active(xP,yP,zP)
        if (cellP <= 0) return
        ! D-131. The zone test used to return here, so the network was never
        ! called in ionized gas and H2/CO were zero there because nothing had
        ! computed them - not because the chemistry said so. With pdrAllCells
        ! the solver runs in every cell; outside the zone it solves the
        ! chemistry only, at MOCASSIN's temperature, and hands nothing back.
        lgChemOnly = .false.
        if (grid%pdrZone(cellP) == 0) then
           if (pdrAllCells == 0) return
           lgChemOnly = .true.
        end if

        nH  = dble(grid%Hden(cellP))
        if (nH <= 0.d0) return

        ! The PDR temperature, NOT grid%Te. MOCASSIN's thermal balance solves
        ! for photoionised gas and barely constrains T at low ionisation; D-030
        ! measured it at 30-3550 K where a PDR belongs at 10-100 K.
        Tg  = dble(grid%pdrTgas(cellP))
        if (Tg <= 0.d0) Tg = dble(grid%Te(cellP))
        ! D-131: in chemistry-only cells MOCASSIN's thermal balance is the
        ! authority - it is photoionized gas, which is what that balance is for
        ! - so take its temperature and do not iterate on it below.
        if (lgChemOnly) Tg = dble(grid%Te(cellP))
        ! D-132: MOCASSIN owns the thermal balance in every cell.
        if (pdrTeFromMocassin /= 0) Tg = dble(grid%Te(cellP))
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
        ! D-065: chi and A_V must be in hand BEFORE the dust block - HTT91
        ! reads both. They used to be assigned ~25 lines later, so HTT91 ran on
        ! uninitialised locals: with chi = 0 it reduces to (T_cmb^5)^0.2 = 2.73 K
        ! and then hits its own max(...,10), returning exactly 10.00 K in every
        ! cell of every model regardless of the radiation field. Measured: 10.00
        ! at the illuminated face where the correct value is 20.9 K.
        chi = dble(grid%chiFUV0(cellP))
        if (chi <= 0.d0) chi = dble(grid%chiFUV(cellP))
        av  = dble(grid%AVeff(cellP))

        ! D-109: the dust properties THIS cell's grains have, not a model-wide
        ! constant read off one arbitrary cell. MOCASSIN measures them where the
        ! chemistry is about to be solved; the calibrated model-wide values are
        ! only the fallback for a cell that carries no dust at all.
        AVfacL = dble(grid%dustAVfac(cellP))
        RfuvL  = dble(grid%dustRfuv(cellP))
        if (AVfacL <= 0.d0) AVfacL = dble(pdrAVfac)
        if (RfuvL  <= 0.d0) RfuvL  = dble(pdrRfuv)

        ! AV_fac is read from a module global inside the vendored chemistry
        ! (CRattenuation, UVfield) - reseed it per cell so those routines get
        ! THIS cell's grains.
        pdrAVfacMod = AVfacL*dble(pdrMetal)
        !
        ! UV_fac is deliberately NOT reseeded from RfuvL. It is not a measured
        ! dust property but the exponent of a PRESCRIPTION, exp(-UV_fac*A_V),
        ! that reconstructs a local field from the surface field. D-090 measured
        ! what the transported field actually does in this geometry -
        ! gamma_eff = 1.85, because the mirror walls return laterally scattered
        ! photons - against 3.31 for pure extinction and 3.02 for 3D-PDR's
        ! prescription. RfuvL/magPerTau is the pure-extinction number, i.e. the
        ! one D-090 showed is wrong here, so substituting it would be a
        ! regression dressed as self-consistency. It stays at the input value.

        ! D-076: heating takes the LOCAL, attenuated field; the reaction rates
        ! take the SURFACE field. 3D-PDR keeps them separate and we did not:
        !
        !   UVfield = sum_j rad_surface(j)*EXP(-AV(j)*UV_fac)   <- local
        !   call calc_heating(rho, nTgas, Tdust, UVfield, ...)  <- local
        !   CALCULATE_REACTION_RATES(..., rad_surface, AV, ...) <- surface
        !
        ! We passed chiFUV0 - the unattenuated 10 Draine surface field - to
        ! CALC_HEATING at every depth, so photoelectric heating never
        ! attenuated. Below A_V ~ 0.1 that is harmless; beyond it the error
        ! grows exponentially, which is exactly where the gas temperature was
        ! seen to peel away from standalone while the DUST temperature (fixed
        ! to use the local field in D-065) stayed correct.
        chiLoc = dble(grid%chiFUV(cellP))
        if (chiLoc <= 0.d0) chiLoc = chi*exp(-av*RfuvL)

        ! D-089, diagnostic only. The reaction rates already run on 3D-PDR's
        ! prescription - CALCULATE_REACTION_RATES rebuilds
        ! chi0*exp(-gamma*A_V) internally from radSurf and AVray - but the
        ! heating and the HTT91 dust temperature take the TRANSPORTED field,
        ! which carries scattered light the prescription has no term for. At
        ! A_V ~ 2 the two differ by an order of magnitude. pdrFUVmode = 1
        ! substitutes the prescription here as well, which isolates whether
        ! the mid-cloud temperature excess is the field or the thermal
        ! balance. Not a physical mode: it throws away the transfer that is
        ! the reason for coupling the codes at all.
        chiHeat = dble(grid%chiFUV(cellP))
        if (pdrFUVmode == 1) then
           chiLoc  = chi*exp(-av*RfuvL)
           chiHeat = chiLoc
        end if

        TdMoc = dble(grid%Tdust(0,0,cellP))

        ! HTT91, evaluated with the single effective ray of D-001 carrying the
        ! full local field (3D-PDR's own 1D mode does the same, putting all the
        ! flux on one ray).
        ! D-065: HTT91 uses TWO different fields, and conflating them is what
        ! made the deep cloud run hot. 3D-PDR's dust_t.F90:
        !
        !   Tdust = 8.9e-11*NU_0*(1.71*PDR(P)%UVfield) + Tcmb**5   <- LOCAL field
        !   T_0   = 12.2*(1.71*PDR(P)%RAD_SURFACE(J))**0.2         <- SURFACE field
        !   if (AV(J) > 1) T_0 = T_0 * AV(J)**(-0.4)
        !
        ! The first term is the direct FUV heating where the grain sits, so it
        ! must be the ATTENUATED local field; the second is the re-radiated IR
        ! from the illuminated skin, so it carries the surface field and its own
        ! Rowan-Robinson depth attenuation. Feeding the surface field to both
        ! left T_dust near 21 K at every depth and heated the deep gas to 50 K.
        TdHTT = 8.9d-11*2.65d15*(1.71d0*chiHeat) + pdrTcmb**5
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

        ! keep the chemistry inside the temperature range it was fitted over
        Tg = min(max(Tg, dble(pdrTmin)), dble(pdrTmax))

        radSurf = chi/dble(nraysLoc)
        AVray   = av

        ! slab-equivalent shielding columns (see header)
        NHcol = av/AVfacL
        abun  = grid%pdrAbun(cellP, 1:pdrNspec)

        ! ---------------------------------------------------------- D-188
        ! FIRST VISIT: seed from MOCASSIN's ionization state, not from the
        ! network file.
        !
        ! seedPDR wrote species_reduced.d's defaults into every cell -
        ! x(H2) = 0.300 and x(H) = 0.400, i.e. 60% of the hydrogen NUCLEI
        ! molecular - identically everywhere, including cells sitting in the
        ! H II region at 9000 K. That is not an initial condition, it is the
        ! network file's own starting point for a standalone dark-cloud run,
        ! and the first chemistry call had to destroy all of it. D-112 measured
        ! that this choice is not neutral: V1's H2 front ratio is 1.109 from
        ! the network seed against 1.679 fully dissociated, and the second does
        ! not relax into the first even with a hundredfold longer integration.
        !
        ! MOCASSIN has a converged ionization structure by the time the
        ! chemistry first runs (pdrStartIter), so the self-consistent seed is
        ! that structure with no molecules yet formed: each element sits in its
        ! atomic and ionic carriers in MOCASSIN's ratio, everything else zero,
        ! and the chemistry forms the molecules from there.
        if (grid%pdrSeeded(cellP) == 0) then
           abun = 0.d0
           do iLnk = 1, pdrNlink
              if (pdrLinkSpec(iLnk) <= 0) cycle
              iEl = pdrLinkElem(iLnk)
              if (iEl < 1 .or. iEl > nElements) cycle
              if (.not.lgElementOn(iEl)) cycle
              ! elemAbun is relative to hydrogen; ionDen is the fraction of the
              ! element in that stage. Hydrogen's elemAbun is 1 by definition.
              if (iEl == 1) then
                 abun(pdrLinkSpec(iLnk)) = &
                      & dble(grid%ionDen(cellP, elementXref(iEl), pdrLinkIon(iLnk)))
              else
                 abun(pdrLinkSpec(iLnk)) = &
                      & dble(grid%elemAbun(grid%abFileIndex(xP,yP,zP), iEl)) &
                      & * dble(grid%ionDen(cellP, elementXref(iEl), pdrLinkIon(iLnk)))
              end if
           end do
           ! electrons: MOCASSIN's own, per hydrogen nucleus
           if (pdrNelect > 0 .and. grid%Hden(cellP) > 0.) &
                & abun(pdrNelect) = max(dble(grid%Ne(cellP))/dble(grid%Hden(cellP)), 0.d0)
           grid%pdrSeeded(cellP) = 1
        end if
        ! D-153: impose MOCASSIN's ionization on the network before solving.
        !
        ! MOCASSIN owns the ionization state; the chemistry owns what is locked
        ! in molecules. So for each linked element take the atomic+ionic total
        ! the chemistry currently holds - which already excludes its molecular
        ! content - and redistribute THAT total according to MOCASSIN's
        ! ionization ratio. The element is conserved, MOCASSIN sets the ratio,
        ! and the molecular fractions are left untouched for the chemistry to
        ! evolve.
        if (pdrIonFromMocassin /= 0) then
           do iLnk = 1, pdrNlink
              if (pdrLinkSpec(iLnk) <= 0) cycle
              if (pdrLinkIon(iLnk) /= 1) cycle       ! handle each element once
              iSpN = pdrLinkSpec(iLnk)               ! neutral stage species
              iSpI = 0
              do jLnk = 1, pdrNlink
                 if (pdrLinkElem(jLnk) == pdrLinkElem(iLnk) .and. &
                      & pdrLinkIon(jLnk) == 2) iSpI = pdrLinkSpec(jLnk)
              end do
              if (iSpI <= 0) cycle
              availTot = abun(iSpN) + abun(iSpI)     ! non-molecular part
              if (availTot <= 0.d0) cycle
              mocNeut = dble(grid%ionDen(cellP, elementXref(pdrLinkElem(iLnk)), 1))
              mocIon  = dble(grid%ionDen(cellP, elementXref(pdrLinkElem(iLnk)), 2))
              if (mocNeut + mocIon <= 0.d0) cycle
              abun(iSpN) = availTot*mocNeut/(mocNeut+mocIon)
              abun(iSpI) = availTot*mocIon /(mocNeut+mocIon)
           end do
        end if

        ! D-078: true integrated columns, not local abundance x total column
        sH2 = dble(grid%pdrColH2(cellP))
        sCO = dble(grid%pdrColCO(cellP))
        sC  = dble(grid%pdrColC(cellP))
        ! D-088: "< 0", not "<= 0". Zero is a real, common answer - the first
        ! PDR cell has nothing molecular in front of it - and treating it as
        ! missing data sent that cell to NHcol*abun(X), the whole column back to
        ! the star times the local molecular fraction. That self-shielded the
        ! illuminated face completely and pinned x(H2) near 0.04 where 3D-PDR
        ! gives 1.6e-6, no matter what the column integration did.
        if (sH2 < 0.d0) sH2 = NHcol*abun(NH2)
        if (sCO < 0.d0) sCO = NHcol*abun(NCO)
        if (sC  < 0.d0) sC  = NHcol*abun(NC)
        sH2 = max(sH2, 0.d0)
        sCO = max(sCO, 0.d0)
        sC  = max(sC , 0.d0)
        ! D-190: per-ray traced columns where they exist, the single
        ! source-ward scalar otherwise.
        !
        ! sH2/sCO/sC come from computeAVradial, which traces ONE direction -
        ! source to cell - and is the right shielding column for the stellar
        ! FUV. Assigning it to all twelve rays says every direction is as
        ! shielded as the line back to the star, which in a 3D model it is not:
        ! a ray pointing out of the cloud sees almost no column at all. The
        ! traced values give each ray its own.
        colH2 = sH2
        colCO = sCO
        colC  = sC
        colHD = 0.d0
#ifdef RAYTHEIA
        if (allocated(grid%colRayH2)) then
           do iRay = 0, nraysLoc-1
              colH2(iRay) = dble(grid%colRayH2(cellP,iRay))
              colCO(iRay) = dble(grid%colRayCO(cellP,iRay))
              colC (iRay) = dble(grid%colRayC (cellP,iRay))
           end do
        end if
#endif
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
           ! D-162: THERE IS ONE x(H+), AND MOCASSIN COMPUTES IT.
           !
           ! D-153 imposed MOCASSIN's ionization ratio before the solve and let
           ! CVODE evolve it. The network has no H + PHOTON -> H+ + e- reaction
           ! at all (D-161) - every H -> H+ channel in it is charge exchange or
           ! cosmic rays - so it relaxes the ratio straight back to the
           ! cosmic-ray equilibrium, x(H+) ~ 9e-4, whatever it was handed. That
           ! is not a second opinion about the same quantity; it is the answer
           ! to a different question, and letting it stand was the reason no
           ! blend weight, zone gate or initial condition could reconcile the
           ! two codes.
           !
           ! So re-impose the ratio afterwards as well. The chemistry keeps what
           ! it legitimately owns - how much of each element is locked in
           ! molecules, which is returned through elemAvail - and MOCASSIN keeps
           ! the ionization state, which is the only physics that can compute
           ! it here. Neither overrides the other's domain, and there is no
           ! quantity that both determine.
           if (pdrIonFromMocassin /= 0) then
              do iLnk = 1, pdrNlink
                 if (pdrLinkSpec(iLnk) <= 0) cycle
                 if (pdrLinkIon(iLnk) /= 1) cycle
                 iSpN = pdrLinkSpec(iLnk)
                 iSpI = 0
                 do jLnk = 1, pdrNlink
                    if (pdrLinkElem(jLnk) == pdrLinkElem(iLnk) .and. &
                         & pdrLinkIon(jLnk) == 2) iSpI = pdrLinkSpec(jLnk)
                 end do
                 if (iSpI <= 0) cycle
                 availTot = abun(iSpN) + abun(iSpI)
                 if (availTot <= 0.d0) cycle
                 mocNeut = dble(grid%ionDen(cellP, elementXref(pdrLinkElem(iLnk)), 1))
                 mocIon  = dble(grid%ionDen(cellP, elementXref(pdrLinkElem(iLnk)), 2))
                 if (mocNeut + mocIon <= 0.d0) cycle
                 abun(iSpN) = availTot*mocNeut/(mocNeut+mocIon)
                 abun(iSpI) = availTot*mocIon /(mocNeut+mocIon)
              end do
           end if

           ! shielding columns follow the abundances between passes
           ! columns follow the abundances between passes, scaled from the
           ! integrated value so the depth weighting is preserved (D-078)
           ! D-190: rescale in PLACE so a traced per-ray column keeps its own
           ! value; the old form overwrote all twelve with the scalar again.
           if (abun0(NH2) > 0.d0) colH2 = colH2*abun(NH2)/abun0(NH2)
           if (abun0(NCO) > 0.d0) colCO = colCO*abun(NCO)/abun0(NCO)
           if (abun0(NC ) > 0.d0) colC  = colC *abun(NC )/abun0(NC )
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

        ! D-121: the chemistry's outputs are the first hand-off in the chain.
        ! A NaN here reaches the grain energy balance through pdrHeatPE and
        ! pdrHeatGG (D-093) and thence T_dust, where it stops the run under a
        ! message about sublimation that names nothing useful.
        if (.not.lgNanFound) then
           do ik = 1, pdrNspec
              if (.not.(abun(ik) == abun(ik))) then
                 lgNanFound = .true.; nanWhere = "chemistry abundance"
                 nanCell = cellP; nanIdx = ik; exit
              end if
           end do
           if (.not.lgNanFound) then
              if (.not.(grid%pdrHeatPE(cellP) == grid%pdrHeatPE(cellP))) then
                 lgNanFound = .true.; nanWhere = "pdrHeatPE"; nanCell = cellP
              else if (.not.(grid%pdrHeatGG(cellP) == grid%pdrHeatGG(cellP))) then
                 lgNanFound = .true.; nanWhere = "pdrHeatGG"; nanCell = cellP
              else if (.not.(grid%pdrTgas(cellP) == grid%pdrTgas(cellP))) then
                 lgNanFound = .true.; nanWhere = "pdrTgas"; nanCell = cellP
              end if
           end if
           if (lgNanFound .and. taskid == 0) print*, &
                & "! [D121] first non-finite: ", trim(nanWhere), &
                & "  cell", nanCell, " index", nanIdx
        end if

        grid%pdrAbun(cellP, 1:pdrNspec) = abun

        ! D-118: publish the chemistry's per-stage formation and destruction
        ! rates for the ions MOCASSIN also tracks. form is an additive
        ! production rate; loss is a specific destruction rate multiplying the
        ! species' own abundance - the same decomposition ionBalance's matrix
        ! wants for its RHS and diagonal, and the one Cloudy consumes as
        ! mole.source / mole.sink. loss is stored positive; the sign convention
        ! lives with the consumer.
        do ik = 1, pdrNlink
           if (pdrLinkSpec(ik) <= 0) cycle
           grid%pdrIonRate(cellP, ik)          = real(pdrFormSp(pdrLinkSpec(ik)))
           grid%pdrIonRate(cellP, pdrNlink+ik) = real(-pdrLossSp(pdrLinkSpec(ik)))
        end do

        ! D-113 verification, one representative cell, last iteration only.
        ! Two checks on the exported rates:
        !   (a) form + x*loss must reproduce dx/dt. At a converged steady state
        !       that is ~0, so |form + x*loss| / form is the residual.
        !   (b) H2 formation on grains is the textbook R*n_H*x(H) with
        !       R ~ 3e-17 cm^3/s, so form(H2)/(nH*x(H)) recovers R.
        if (pdrDiagRates /= 0 .and. taskid == 0 .and. grid%pdrZone(cellP) == 1) then
           if (av > 0.9d0*pdrDiagAV .and. av < 1.1d0*pdrDiagAV) then
              print*, "! [D113] rates at A_V =", real(av), " n_H =", real(nH)
              print*, "! [D113]   species     x            form         ", &
                   & "x*loss       residual"
              do it = 1, 3
                 nSpec = 0.d0
                 select case (it)
                 case (1); ik = NH2
                 case (2); ik = NCO
                 case (3); ik = pdrNHsp
                 end select
                 print*, "! [D113]  ", pdrSpecies(ik), real(abun(ik)), &
                      & real(pdrFormSp(ik)), real(abun(ik)*pdrLossSp(ik)), &
                      & real((pdrFormSp(ik)+abun(ik)*pdrLossSp(ik)) &
                      &      / max(abs(pdrFormSp(ik)),1.d-99))
              end do
              print*, "! [D113]   implied H2 formation coefficient R =", &
                   & real(pdrFormSp(NH2)/max(nH*abun(pdrNHsp),1.d-99)), &
                   & " cm^3/s   (textbook ~3e-17)"
           end if
        end if


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

        do itherm = 1, merge(1, max(pdrThermIter,1), &
             & lgChemOnly .or. pdrTeFromMocassin /= 0)

           ! PDR heating budget for this cell: 12 terms, total in slot 12. The
           ! photoelectric part is kept separately because it is the term
           ! MOCASSIN also computes, and D-007's blend band ramps between the
           ! two rather than adding them.
           call CALC_HEATING(nH, Tg, Td, chiLoc, dble(pdrVturb)*1.d5, pdrNspecMod, &
                & abun, pdrNreacMod, pdrRate, heat, &
                & NRGR, NR2, NR3, NR4, NR5, NR6, pdrZetaMod)

           grid%pdrHeat(cellP)   = real(heat(12))
           ! D-095: heat(2) ALONE. TOTAL_HEATING takes only PAHPHOTOELEC_HEATING from
           ! the photoelectric family - heat(1) is hard-set to zero and heat(3),
           ! Weingartner & Draine, is an ALTERNATIVE prescription commented out of
           ! the sum. Summing all three was harmless while this was a diagnostic;
           ! once D-093 started subtracting it from the grain energy budget it
           ! removed about twice the right amount, including a term the gas never
           ! received.
           grid%pdrHeatPE(cellP) = real(heat(2))
           grid%pdrHeatGG(cellP) = real(heat(11))
           grid%NePDR(cellP)     = real(abun(pdrNelect)*nH)   ! D-105
           grid%H2den(cellP)     = real(abun(NH2)*nH)         ! D-107

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
           ! ---- D-166: two evaluations, one power law ----------------------
           ! The coolants are solved at Tg and again at pdrCoolTfac*Tg. Only the
           ! first stores anything; the second exists so thermBalance can be
           ! handed d ln C / d ln T and evaluate C(T) inside its temperature
           ! loop instead of reading a constant. Cloudy re-evaluates the entire
           ! cooling function at every trial temperature; this is the two-point
           ! version of the same requirement, at twice the level-population cost
           ! per coupling pass rather than thirty times.
           coolTot  = 0.d0
           coolTot2 = 0.d0
           coolTot3 = 0.d0
           ! pdrCoolTdep 2 adds a THIRD evaluation, at 1/pdrCoolTfac * Tg, used
           ! only to check the power law against a real solve on the other side
           ! of Tref. An extrapolation is worth nothing until someone has looked
           ! at how far it misses.
           do iTpass = 1, 3
              if (iTpass == 1) then
                 Tc = Tg
              else if (iTpass == 2) then
                 if (pdrCoolTdep == 0) exit
                 Tc = dble(pdrCoolTfac)*Tg
              else
                 if (pdrCoolTdep < 2) exit
                 Tc = Tg/dble(pdrCoolTfac)
              end if

           do ik = 1, pdrNcool
              nlev = pdrCoolant2(ik)%cnlev
              nSpec = abun(pdrCoolant2(ik)%cspec)*nH

              ! Skip a coolant whose carrier has been chemically destroyed.
              ! Below this the level populations are numerically meaningless
              ! and the transition matrix goes singular - solvlevpop's
              ! Gauss-Jordan then hits a zero pivot, returns NaN, and the NaN
              ! rides the cooling into T_gas and out into MOCASSIN (D-041).
              if (nSpec <= pdrNspecFloor*nH) then
                 ! D-131: zero it, do not just skip. pdrCoolSp is now read by
                 ! MOCASSIN's thermal balance, and leaving the previous MC
                 ! iteration's value in place would feed a cell the cooling of
                 ! a carrier the chemistry has since destroyed.
                 if (iTpass == 1) grid%pdrCoolSp(cellP, ik) = 0.
                 cycle
              end if

              lpop(1:nlev) = grid%pdrLevPop(cellP, pdrLevOff(ik)+1 : pdrLevOff(ik)+nlev)

              ! First visit to this cell: start from LTE, as 3D-PDR does.
              if (all(lpop(1:nlev) <= 0.d0)) then
                 call calculate_partition_function(Zpart, nlev, &
                      & pdrCoolant2(ik)%energies, pdrCoolant2(ik)%weights, Tc)
                 call calculate_lte_populations(nlev, lpop(1:nlev), &
                      & pdrCoolant2(ik)%energies, pdrCoolant2(ik)%weights, &
                      & Zpart, nSpec, Tc)
              else
                 ! rescale to the abundance the chemistry just produced
                 lsum = sum(lpop(1:nlev))
                 if (lsum > 0.d0) lpop(1:nlev) = lpop(1:nlev)*nSpec/lsum
              end if

              call FIND_CCOEFF(pdrCoolant2(ik)%cntemp, nlev, Tc, &
                   & pdrCoolant2(ik)%temperatures, pdrCoolant2(ik)%H_COL, &
                   & pdrCoolant2(ik)%HP_COL, pdrCoolant2(ik)%EL_COL, &
                   & pdrCoolant2(ik)%HE_COL, pdrCoolant2(ik)%H2_COL, &
                   & pdrCoolant2(ik)%PH2_COL, pdrCoolant2(ik)%OH2_COL, &
                   & Ccoef(1:nlev,1:nlev), abun(pdrNHsp)*nH, abun(NPROTON)*nH, &
                   & abun(pdrNelect)*nH, abun(NHe)*nH, abun(NH2)*nH)

              ! Rebuild the upward rates by detailed balance at the local gas
              ! temperature, as coolingfunctions does (avoids "supercooling").
              do il = 2, nlev
                 do jl = 1, il-1
                    Ccoef(jl,il) = Ccoef(il,jl) &
                         & *pdrCoolant2(ik)%weights(il)/pdrCoolant2(ik)%weights(jl) &
                         & *exp(-(pdrCoolant2(ik)%energies(il) &
                         &       -pdrCoolant2(ik)%energies(jl))/(KB*Tc))
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
              ! ---- D-083: geometry for whichever branch was compiled --------
              ! The branch and the arguments must agree. ONEDIMENSIONAL takes
              ! evaluation-point coordinates and uses only ray 6; RAYTHEIA takes
              ! a per-ray path length and uses all of them. See the PDRGEOM
              ! switch in the Makefile.
              avBack = dble(grid%AVback(cellP))
#ifdef RAYTHEIA
              ! Per-ray slab geometry. HEALPix nside=1 is three rings: 4 rays at
              ! mu = +2/3, 4 at mu = 0, 4 at mu = -2/3 along the slab normal.
              ! Rays looking back at the illuminated face see A_V/|mu|; rays
              ! looking inward see the remaining column A_Vback/mu; rays parallel
              ! to an infinite slab never escape.
              !
              ! NOTE: this is the SLAB closed form. A genuinely 3D model needs
              ! per-ray columns ray-traced through the grid, as 3D-PDR does in
              ! columndensity.F90. Until that exists, a 3D run using this is
              ! approximating every ray's column by the plane-parallel result.
              ! D-190: the ray-traced A_V, not the slab closed form. Every ray
              ! now carries the extinction actually accumulated along it through
              ! the grid; the old version assigned A_V/|mu| or A_Vback/mu from a
              ! plane-parallel argument, which is a slab answer inside a 3D
              ! model. Falls back to the closed form only if the trace has not
              ! run yet (first iteration, before mocassinToPDR).
              do kray = 0, nraysLoc-1
                 if (allocated(grid%colRayAV)) then
                    colA = dble(grid%colRayAV(cellP,kray))
                 else
                    colA = -1.d0
                 end if
                 if (colA < 0.d0) then
                    if (kray < 4) then
                       mu =  2.d0/3.d0
                    else if (kray < 8) then
                       mu =  0.d0
                    else
                       mu = -2.d0/3.d0
                    end if
                    if (mu > 1.d-6) then
                       colA = avBack/mu
                    else if (mu < -1.d-6) then
                       colA = av/abs(mu)
                    else
                       colA = 1.d30
                    end if
                 end if
                 jjr(kray)    = 1
                 plen(kray,0) = 0.d0
                 plen(kray,1) = min((colA/AVfacL)/nH/PC, 1.d30)
              end do
#else
              colA   = av
              jjr    = 1
              evpt   = 0.d0
              evpt(1,6,0) = 0.d0
              evpt(1,6,1) = (colA/AVfacL)/nH/PC
#endif

              do ilev = 1, max(pdrLevIter,1)
              evpop = 0.d0
              do kray = 0, nraysLoc-1
                 evpop(kray,0,1:nlev) = lpop(1:nlev)
                 evpop(kray,1,1:nlev) = lpop(1:nlev)
              end do

              trans(1:nlev,1:nlev) = 0.d0
#ifdef RAYTHEIA
              call escape_probability(trans(1:nlev,1:nlev), Td, nraysLoc, nlev, &
                   & pdrCoolant2(ik)%A_COEFFS, pdrCoolant2(ik)%B_COEFFS, &
                   & Ccoef(1:nlev,1:nlev), pdrCoolant2(ik)%frequencies, &
                   & evpop(0:nraysLoc-1,0:1,1:nlev), 1, Tc, dble(pdrVturb)*1.d5, jjr, &
                   & lpop(1:nlev), pdrCoolant2(ik)%weights, coolK, &
                   & lline(1:nlev,1:nlev), nH, pdrMetalMod, &
                   & pdrCoolant2(ik)%molweight, plen)
#else
              call escape_probability(trans(1:nlev,1:nlev), Td, nraysLoc, nlev, &
                   & pdrCoolant2(ik)%A_COEFFS, pdrCoolant2(ik)%B_COEFFS, &
                   & Ccoef(1:nlev,1:nlev), pdrCoolant2(ik)%frequencies, &
                   & evpop(0:nraysLoc-1,0:1,1:nlev), 1, Tc, dble(pdrVturb)*1.d5, jjr, &
                   & lpop(1:nlev), evpt, pdrCoolant2(ik)%weights, coolK, &
                   & lline(1:nlev,1:nlev), nH, pdrMetalMod, &
                   & pdrCoolant2(ik)%molweight)
#endif

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

              if (iTpass == 1) grid%pdrLevPop(cellP, pdrLevOff(ik)+1 : pdrLevOff(ik)+nlev) = lsol(1:nlev)
              if (iTpass == 1) then
                 coolTot  = coolTot  + coolK
              else if (iTpass == 2) then
                 coolTot2 = coolTot2 + coolK
              else
                 coolTot3 = coolTot3 + coolK
              end if
              if (iTpass == 1) grid%pdrCoolSp(cellP, ik) = real(coolK)   ! D-096

              ! D-060 diagnostic: per-coolant budget at the illuminated face
              if (pdrDiagCool > 0 .and. taskid == 0 .and. iTpass == 1) then
                 if (pdrNdiag < 400000) then
                    pdrNdiag = pdrNdiag + 1
                    print '(a,i3,a,es9.2,a,i3,a,es10.3,a,es11.3,a,f7.2,a,f9.1,a,2es11.3,a,es10.3,a,es10.3,a,es10.3)', &
                       & " [D060] coolant", ik, " A_V=", grid%AVeff(cellP), &
                       & " cspec=", pdrCoolant2(ik)%cspec, " n=", nSpec, &
                       & " cool=", coolK, " Td=", Td, " T=", Tc, " pop=", lsol(1), lsol(2), &
                       & " nSpec=", nSpec, " ne=", abun(pdrNelect)*nH, " nH0=", abun(pdrNHsp)*nH
                 end if
              end if
           end do
           end do
           ! Local power law, clamped: below the excitation temperature a
           ! fine-structure coolant rises nearly exponentially, above it the
           ! line saturates and the index goes to zero. Extrapolating an
           ! unclamped index over three decades is not defensible.
           if (pdrCoolTdep /= 0 .and. coolTot > 0.d0 .and. coolTot2 > 0.d0) then
              grid%pdrCoolSlope(cellP) = real(min(max( &
                   & log(coolTot2/coolTot)/log(dble(pdrCoolTfac)), -2.d0), 12.d0))
           else
              grid%pdrCoolSlope(cellP) = 0.
           end if
           grid%pdrCoolTref(cellP) = real(Tg)
           ! Power law against a real solve, on the far side of Tref.
           if (pdrCoolTdep >= 2 .and. taskid == 0 .and. coolTot > 0.d0 .and. &
                & coolTot3 > 0.d0 .and. pdrNslopeChk < 30 .and. .not. lgChemOnly) then
              pdrNslopeChk = pdrNslopeChk + 1
              print '(a,i8,a,f9.2,a,f7.3,a,es11.3,a,es11.3,a,f8.3)', &
                   & " [D166] cell", cellP, " Tref=", Tg, " p=", grid%pdrCoolSlope(cellP), &
                   & "  C(Tref/f) true=", coolTot3, " pred=", &
                   & coolTot*(1.d0/dble(pdrCoolTfac))**dble(grid%pdrCoolSlope(cellP)), &
                   & "  ratio=", real(coolTot3/max(coolTot*(1.d0/dble(pdrCoolTfac)) &
                   & **dble(grid%pdrCoolSlope(cellP)),1.d-99))
           end if


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
           ! D-131: a chemistry-only cell keeps MOCASSIN's temperature.
           ! D-132: under pdrTeFromMocassin, so does every other cell.
           if (lgChemOnly .or. pdrTeFromMocassin /= 0) then
              Tg = dble(grid%Te(cellP))
           else
              Tg = min(max(Tg, dble(pdrTmin)), dble(pdrTmax))
           end if

        end do

        ! Re-evaluate once at the converged temperature so the stored heating
        ! and cooling correspond to the stored T. Without this they are one
        ! bisection step stale, and because cooling is exponential in T that
        ! makes a converged cell look like a factor-of-20 imbalance.
        call CALC_HEATING(nH, Tg, Td, chiLoc, dble(pdrVturb)*1.d5, pdrNspecMod, &
             & abun, pdrNreacMod, pdrRate, heat, &
             & NRGR, NR2, NR3, NR4, NR5, NR6, pdrZetaMod)
        grid%pdrHeat(cellP)   = real(heat(12))
        grid%pdrHeatPE(cellP) = real(heat(2))   ! D-095: heat(2) alone, see above
        ! D-131: the part of the PDR heating MOCASSIN has no term for. Excluded
        ! because MOCASSIN already computes them: heat(2) PAH photoelectric
        ! (photoelHeat_g), heat(4) carbon photoionization (its own heatSte sum
        ! over ions), heat(11) gas-grain (gasDustColl_g). What remains is H2
        ! formation, H2 photodissociation, FUV pumping, cosmic-ray, turbulent
        ! and chemical heating - none of which exist anywhere in MOCASSIN.
        grid%pdrHeatXtra(cellP) = real(heat(5) + heat(6) + heat(7) + &
             & heat(8) + heat(9) + heat(10))
        ! D-150: is the MOCASSIN <-> PDR pair an oscillating fixed point?
        ! MOCASSIN solves T with pdrCool held constant, the PDR then recomputes
        ! pdrCool at the new T, and so on. If that is the instability, Te in a
        ! given cell should swing between MC iterations rather than settle.
        ! Track a few fixed deep cells across iterations before building any
        ! machinery to fix a mechanism that has not been shown to exist.
        ! D-152: track cells that FAIL the convergence test, not cells picked
        ! by index. The previous probe followed cells 13/133/253 and found them
        ! comfortably converged - x(H0) moving ~0.04% against a 5% tolerance -
        ! which says nothing about the 99.9% that do not.
        if (pdrTrackCell > 0 .and. taskid == 0 .and. nIterateMC > pdrStartIter &
             & .and. grid%lgConverged(cellP) == 0 .and. nTrackHit < 40) then
           nTrackHit = nTrackHit + 1
           ! D-151: Te is pinned to 7 figures while pdrCool swings 2x, so the
           ! coolant abundances are moving at constant temperature. Report the
           ! chemistry and the field that drives it, to see which is the source.
           print*, "! [D151] iter", nIterateMC, " cell", cellP, &
                & " Te =", grid%Te(cellP), " chi =", grid%chiFUV(cellP), &
                & " cool =", grid%pdrCool(cellP), &
                & " x(C+) =", real(abun(NCx)), " x(C) =", real(abun(NC)), &
                & " x(CO) =", real(abun(NCO)), " x(H2) =", real(abun(NH2))
           print*, "! [D152]      x(H) =", real(abun(pdrNHsp)), &
                & " x(H+) =", real(abun(NPROTON)), &
                & " ionDen H0 =", grid%ionDen(cellP,elementXref(1),1), &
                & " AV =", grid%AVeff(cellP), " nH =", grid%Hden(cellP)
        end if
        grid%pdrHeatGG(cellP) = real(heat(11))
        grid%NePDR(cellP)     = real(abun(pdrNelect)*nH)   ! D-105
        grid%H2den(cellP)     = real(abun(NH2)*nH)         ! D-107

        ! D-131: leave pdrTgas at zero outside the zone. handBackPDR skips any
        ! cell with pdrTgas <= 0, so a chemistry-only cell publishes abundances
        ! without also publishing a temperature MOCASSIN did not ask for.
        if (.not. lgChemOnly) then
           grid%pdrTgas(cellP)  = real(Tg)
           grid%pdrTlow(cellP)  = real(Tlo)
           grid%pdrThigh(cellP) = real(Thi)
        end if

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
        ! D-176: count it, and let it be switched off where it is meaningless.
        ! Under pdrTeFromMocassin the PDR does not solve for the temperature,
        ! so its own heat and cool are evaluated at MOCASSIN's answer and need
        ! not balance; and with pdrAllCells this ran in ionized cells too,
        ! where the PDR chemistry is not what the model is converging.
        if (max(abs(heat(12)), coolTot) > 0.d0) then
           if (abs(heat(12)-coolTot)/max(abs(heat(12)), coolTot) > dble(pdrFcrit)) then
              if (grid%lgConverged(cellP) == 1) cvPdrCleared = cvPdrCleared + 1
              if (pdrFcritConv /= 0 .or. &
                   & (pdrTeFromMocassin == 0 .and. .not. lgChemOnly)) &
                   & grid%lgConverged(cellP) = 0
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
                    ! D-153: with MOCASSIN owning the temperature the PDR does
                    ! not publish one, so this guard would skip every cell and
                    ! elemAvail - the molecular content, which is the whole
                    ! point of the handback - would never be updated.
                    if (pdrIonFromMocassin == 0 .and. &
                         & grid(iG)%pdrTgas(cellP) <= 0.) cycle

                    xHII = dble(grid(iG)%ionDen(cellP, elementXref(1), 2))

                    ! D-153: under pdrIonFromMocassin there is nothing to blend
                    ! and nothing to gate. MOCASSIN already owns the ionization
                    ! state - it was imposed on the network before the solve -
                    ! so the only thing coming back is the molecular content,
                    ! via elemAvail below. The weight is irrelevant and the
                    ! zone test, which used to reject the chemistry precisely
                    ! where the two codes disagreed (D-152), is not applied.
                    if (pdrIonFromMocassin /= 0) then
                       w = 0.d0            ! no ionization or temperature handback
                    else if (xHII <= dble(pdrBlendLo)) then
                       w = 1.d0
                    else if (xHII < dble(pdrZoneLim)) then
                       ! blend band: w = 1 at the neutral edge, 0 at the ionised one
                       w = (hi - log10(max(xHII,1.d-30))) / max(hi-lo, 1.d-30)
                       w = min(max(w, 0.d0), 1.d0)
                    else
                       cycle
                    end if

                    ! D-132: with MOCASSIN owning the balance there is nothing
                    ! to hand back - its own thermBalance now carries the
                    ! molecular coolant and the six heating terms it lacked.
                    if (pdrTeFromMocassin == 0) &
                         & grid(iG)%Te(cellP) = real( &
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
                    ! D-102: publish, per element, the fraction NOT locked in
                    ! molecules. ionBalance normalises the ion stages to sum to
                    ! one, which is false wherever a molecule holds some of the
                    ! element - and that normalisation silently undid both this
                    ! routine's hydrogen handover and D-038's carbon one on the
                    ! next pass. The available fraction is taken straight from
                    ! the chemistry as (neutral + ionized)/total, which needs no
                    ! enumeration of which molecules exist.
                    if (pdrNHsp > 0 .and. NPROTON > 0) &
                         & grid(iG)%elemAvail(cellP,1) = real(min(max( &
                         &   grid(iG)%pdrAbun(cellP,pdrNHsp) &
                         & + grid(iG)%pdrAbun(cellP,NPROTON), 0.d0), 1.d0))

                    if (NPROTON > 0) then
                       xnew = min(max(grid(iG)%pdrAbun(cellP,NPROTON), 0.d0), 1.d0)
                       grid(iG)%ionDen(cellP,elementXref(1),2) = real( &
                            & w*xnew + (1.d0-w)*dble(grid(iG)%ionDen(cellP,elementXref(1),2)))
                       ! D-099: this is NOT the atomic hydrogen fraction, and
                       ! deliberately so. It is the total non-ionized hydrogen -
                       ! every nucleus not in H+, the molecular ones included.
                       !
                       ! The chemistry's own x(H) is the physical atomic
                       ! fraction and is what pdrGrid.out carries; handing it
                       ! here instead was tried and reverted. MOCASSIN has no H2
                       ! opacity at all, so the atomic hydrogen in this array is
                       ! the only thing keeping the molecular interior opaque to
                       ! the Lyman continuum. Replacing 1.0 with the true
                       ! x(H) ~ 0.002 makes the medium transparent and
                       ! MOCASSIN's own ionBalance then answers x(H+) ~ 0.17 at
                       ! A_V = 0.45, where the chemistry gives 5e-7. That lands
                       ! inside the blend band (pdrZoneLim = 0.3), drives w to
                       ! 0.17 and discards 83% of the handover, temperature
                       ! included: V1 deep T ratio went 1.06 -> 1.32.
                       !
                       ! Fixing it properly means giving MOCASSIN an H2 opacity,
                       ! not changing this line.
                       ! D-101: with a source that emits no ionizing photons
                       ! this can be the true atomic fraction. Guarded so the
                       ! two can be compared.
                       if (pdrAtomicH /= 0 .and. pdrNHsp > 0) then
                          grid(iG)%ionDen(cellP,elementXref(1),1) = real(max( &
                               & w*min(max(dble(grid(iG)%pdrAbun(cellP,pdrNHsp)),0.d0),1.d0) &
                               & + (1.d0-w)*(1.d0 &
                               &   - dble(grid(iG)%ionDen(cellP,elementXref(1),2)) &
                               &   - 2.d0*dble(grid(iG)%pdrAbun(cellP,NH2))), 0.d0))
                       else
                          grid(iG)%ionDen(cellP,elementXref(1),1) = &
                               & 1.0 - grid(iG)%ionDen(cellP,elementXref(1),2)
                       end if
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

        ! D-102: what is left over is locked in molecules - CO above all for
        ! carbon and oxygen. Record the available fraction so ionBalance does
        ! not renormalise the atomic stages back to one on the next pass, which
        ! is what had been quietly undoing this handover ever since D-038.
        grid%elemAvail(cellP, elem) = real(min(max(f0+f1, 0.d0), 1.d0))

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
