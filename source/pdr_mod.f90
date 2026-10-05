! Copyright (C) 2026 Hektor Monteiro
! Part of MOCASSIN-PDR.
!
! This program is free software: you can redistribute it and/or modify it
! under the terms of the GNU General Public License as published by the Free
! Software Foundation, either version 3 of the License, or (at your option)
! any later version. It is distributed WITHOUT ANY WARRANTY; see the GNU
! General Public License (LICENSE) for details.
!
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
    use update_mod,    only : grainAlbedoLW     ! D-280

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
                              & pdrCoolant2  => coolant

    ! Species indices come from global_module. NH2/NC/NCO do not collide with
    ! anything in common_mod, so they are imported under their own names.
    ! D-108: the Savage & Mathis extinction table SCATTER() splines, so it can
    ! be repopulated with this model's own grains.
    use uclpdr_module,    only : start, N_GRID, L_GRID, X_GRID

    use global_module,    only : pdrMetalMod  => metallicity, &
                               & pdrOmega     => omega,       &
                               & pdrGrainRadM => grain_radius, &
                               & pdrH2xsecSil => h2form_xsec_sil, &
                               & pdrH2xsecGra => h2form_xsec_gra, &
                               & pdrNelect    => NELECT,      &
                               ! D-075: NH must be renamed. It is the species
                               ! index for atomic H, but pdrStep declares a local
                               ! `nH` for the hydrogen density and Fortran is
                               ! CASE-INSENSITIVE, so inside that routine `NH`
                               ! resolved to the local double and abun(NH) indexed
                               ! a 33-element array at 1000. gfortran accepts the
                               ! real subscript as a legacy extension, silently.
                               & pdrRayLW => ray_lw_factor, &       ! D-350
                               & pdrEscBeta => escape_beta, &       ! D-363
                               & pdrEscBg => escape_bg, &           ! D-377
                               & NH2, NC, NCO, pdrNHsp => NH, NPROTON, NHe, NHEx, &
                               & NCx, NO, NOx, NMG, NMGx, &
                               ! D-258: H2+ and H3+, for the chain diagnostic
                               & NH2x, NH3x

    ! D-113: per-species formation and destruction rates from the ODE RHS
    use chemistry_module, only : pdrFormSp => species_form, &
                               & pdrLossSp => species_loss
    use chemistry_module, only : pdrRelTol => relative_abundance_tolerance, &
                               & pdrAbsTol => absolute_abundance_tolerance

    ! CALC_HEATING's chemical-heating term needs this module's reaction indices
    ! built first; without it the term reads unset state (DEVLOG D-029).
    use chemical_heating_module, only : init_chemical_heating

    ! D-348: the vendored band-integrated shielding, evaluated for the
    ! diagnostics exactly as CALCULATE_REACTION_RATES evaluates it per ray
    use functions_module, only : pdrH2PDRATE => H2PDRATE, pdrSCATTER => SCATTER

    implicit none

    private
    public :: initPDRnetwork, seedPDR, seedMolecules, calibratePDRdust, dustPerCell, computeAVdust, &
             & initPDRcoolTab, rescaleIonToAvail, &
            & mocassinToPDR, pdrStep, pdrToMocassin
    public :: resetDiffuseDiag, reportDiffuseDiag        ! D-348
    public :: reportPassChange                           ! D-354

    ! D-195: mean GEOMETRIC cross section of one grain [cm^2], per dust chemistry
    ! component, split by material. Fixed by the size distribution and the
    ! species mix, so measured once; the per-H area is Ndust/Hden times this.
    double precision, allocatable :: sigSilGrain(:), sigGraGrain(:)
    logical                       :: lgH2areaDone = .false.

    ! D-348: the scattering sites of the cell pdrStep is solving, filled by
    ! traceDiffuseSites - weight, and (H2, C, CO) two-leg columns [cm^-2]
    double precision, allocatable :: siteW(:), siteN(:,:)

    ! D-397: the cells the ray last traced by rayCells crosses, in order, and
    ! its exact length in each [cm] (rayCell 0 where the cell is not active)
    integer, allocatable          :: rayCell(:)
    double precision, allocatable :: rayLen(:)

    ! D-377: the line-escape rays of the cell pdrStep is solving, filled by
    ! traceLineRays - along each of the twelve HEALPix directions, the cells
    ! crossed from this one to the edge of the model (lrCell) and the path
    ! length in each (lrLen, cm), lrN(k) of them on ray k
    integer                       :: lrN(0:11) = 0
    integer, allocatable          :: lrCell(:,:)
    double precision, allocatable :: lrLen(:,:)
    ! D-377: the MOCASSIN frequency bin of each coolant transition (upper,
    ! lower, coolant); 0 outside the grid. Built on first use.
    integer, allocatable          :: pdrTrBin(:,:,:)

    ! D-348: per-A_V-bin sums over the cells this rank solved in the current
    ! coupling pass, reduced and printed by reportDiffuseDiag. The bins are
    ! D-344's, so the diffuse fractions read straight against its table.
    integer, parameter :: nDifBin = 9, nDifCol = 20
    double precision, parameter :: difBinEdge(0:nDifBin) = &
         & (/ 0.d0, 0.2d0, 0.47d0, 0.8d0, 1.2d0, 1.6d0, 2.1d0, 2.6d0, 3.05d0, 1.d30 /)
    double precision :: difDiag(nDifCol, nDifBin) = 0.d0

    ! D-354: how far this MC iteration's chemistry moved x(H2) and x(CO) in
    ! the cells this rank solved, against each cell's state from the last
    ! iteration: cells counted, moved by >0.1%, moved by >1%, and the largest
    ! relative move. Reduced and printed by reportPassChange.
    double precision :: passCnt(2,3) = 0.d0, passMax(2) = 0.d0

    ! D-358: where MOCASSIN's own rates for the linked neutrals H, He, C, O,
    ! Mg enter the network. iCr358: the first-order slot X + CRP (or CRPHOT)
    ! -> X+ + e-, which takes MOCASSIN's photoionization rate on top of the
    ! cosmic rays; iPh358: the network's own X + PHOTON -> X+ + e-, which it
    ! replaces; iRec358: X+ + e- -> X + PHOTON (all temperature ranges), whose
    ! first entry takes MOCASSIN's recombination coefficient. iH2cr358 is
    ! H2 + CRP -> H2+ + e-, which takes MOCASSIN's H2 photoionization rate.
    ! Found by structure at initPDRnetwork, as D-163 finds the linked channels.
    integer :: iCr358(5) = 0, iPh358(5) = 0, iRec358(5,4) = 0, nRec358(5) = 0
    integer :: iH2cr358 = 0
    character(len=2), parameter :: lnk358(5) = (/ 'H ', 'He', 'C ', 'O ', 'Mg' /)
    ! D-358: the solver's X+/X against MOCASSIN's, per iteration, for H and O:
    ! cells compared, off by more than 2x, largest |log10| of the ratio;
    ! and cells whose MOCASSIN rates were not yet set
    double precision :: ion358(2,3) = 0.d0
    integer          :: nUnset358 = 0
    ! D-362: each coolant's cooling from a level-population solve at the
    ! cell's own temperature against the log-log interpolation of the D-215
    ! table the thermal balance reads: cells compared, the two sums, and
    ! the sum and largest of |ln(exact/table)|. Reduced and printed by
    ! reportPassChange.
    double precision :: lnCmp362(30,4) = 0.d0, lnMax362(30) = 0.d0

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
        integer            :: iTyp280          ! D-280: 1 CRP, 2 CRPHOT
        integer            :: ios, iS, iC
        integer            :: iLv, iUp, nT362  ! D-362: transition list
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
        ! D-352: metallicity and grain radius are not inputs. The model's
        ! metallicity is its abundances and dust, and the chemistry reads the
        ! grain area MOCASSIN measures (D-195), so the vendored metallicity is
        ! pinned at 1 - it multiplies that measured area in h2_form and must
        ! not scale it a second time. The vendored grain radius reaches only
        ! the freeze-out branches (absent from this network) and 3D-PDR's own
        ! gas-grain term (heat(11)); it keeps upstream's 0.1 um.
        pdrMetalMod   = 1.0d0
        pdrGrainRadM  = 1.0d-5
        ! D-280: upstream's fixed grain albedo. It enters every CRPHOT rate
        ! (calc_reac_rates.F90, gamma/(1-omega)) - D-247 was wrong to call it
        ! dead. pdrStep overwrites it with each cell's own Lyman-Werner albedo
        ! before the rates are evaluated; this value survives only in the smoke
        ! test, which has no grid.
        pdrOmega      = 0.42d0
        ! D-352: AV_fac is reset per cell in pdrStep from THIS cell's grains
        ! (D-109); UV_fac is read only under GRAINRECOMB, which is not built.
        ! Both are set from the measured dust in calibratePDRdust.
        pdrAVfacMod   = 0.0d0
        pdrUVfacMod   = 0.0d0
        pdrZetaMod    = dble(pdrZeta)/1.3d-17       ! stored normalised, as upstream
        pdrRedshift   = 0.0d0
        pdrTcmb       = 2.725d0*(1.0d0+pdrRedshift)
        pdrVturbMod   = dble(pdrVturb)*1.0d5        ! km/s -> cm/s
        pdrTminMod    = max(dble(pdrTmin), pdrTcmb)
        pdrTmaxMod    = dble(pdrTmax)
        pdrLevel      = 0                           ! HEALPix level 0: pdrStep's 12 rays
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

        ! D-362: every coolant's radiative transitions, in the order
        ! escape_probability evaluates them (upper level outer, lower inner,
        ! A_ij > 0), with their wavelengths and the level energies - all from
        ! the coolant files themselves. pdrStep stores each transition's
        ! emission per cell; outputGas matches the atomic ones to MOCASSIN's
        ! own levels by energy.
        pdrNln = 0
        do iS = 1, pdrNcool
           pdrLnOff(iS) = pdrNln
           pdrLnN(iS)   = 0
           do iUp = 2, pdrCoolant2(iS)%cnlev
              do iLv = 1, iUp-1
                 if (pdrCoolant2(iS)%A_COEFFS(iUp,iLv) /= 0.d0) pdrLnN(iS) = pdrLnN(iS) + 1
              end do
           end do
           pdrNln = pdrNln + pdrLnN(iS)
        end do
        if (allocated(pdrLnUp)) deallocate(pdrLnUp, pdrLnLo, pdrLnWav, pdrLvE)
        allocate(pdrLnUp(max(pdrNln,1)), pdrLnLo(max(pdrNln,1)), &
             & pdrLnWav(max(pdrNln,1)), pdrLvE(max(pdrNlevTot,1)))
        pdrLnUp = 0; pdrLnLo = 0; pdrLnWav = 0.d0; pdrLvE = 0.d0
        do iS = 1, pdrNcool
           nT362 = pdrLnOff(iS)
           do iUp = 1, pdrCoolant2(iS)%cnlev
              pdrLvE(pdrLevOff(iS)+iUp) = pdrCoolant2(iS)%energies(iUp) &
                   & /(dble(hPlanck)*dble(c))
           end do
           do iUp = 2, pdrCoolant2(iS)%cnlev
              do iLv = 1, iUp-1
                 if (pdrCoolant2(iS)%A_COEFFS(iUp,iLv) == 0.d0) cycle
                 nT362 = nT362 + 1
                 pdrLnUp(nT362) = iUp
                 pdrLnLo(nT362) = iLv
                 if (pdrCoolant2(iS)%frequencies(iUp,iLv) > 0.d0) &
                      & pdrLnWav(nT362) = dble(c)/pdrCoolant2(iS)%frequencies(iUp,iLv)*1.d8
              end do
           end do
           if (taskid == 0) print '(a,a,a,i4,a)', " ! [D362] coolant ", &
                & trim(adjustl(pdrCoolant(iS))), ": ", pdrLnN(iS), &
                & " radiative transitions, emission stored per cell"
        end do

        ! D-363: the atomic coolants' collision tables, for MOCASSIN's own
        ! atoms to take the colliders it has no data for (H, H+, He, H2).
        ! Copied as read, in the chemistry's level numbering; the electron
        ! rates stay behind - MOCASSIN's CHIANTI rates are used for those.
        do iS = 1, pdrNcool
           if (pdrCoolIsMol(iS) .or. pdrCoolElem(iS) < 3) cycle
           nT362 = pdrCoolant2(iS)%cntemp
           iUp   = pdrCoolant2(iS)%cnlev
           if (allocated(pdrAtomColl(iS)%tempK)) &
                & deallocate(pdrAtomColl(iS)%tempK, pdrAtomColl(iS)%kDown)
           allocate(pdrAtomColl(iS)%tempK(7, nT362), pdrAtomColl(iS)%kDown(7, iUp, iUp, nT362))
           pdrAtomColl(iS)%nlev  = iUp
           pdrAtomColl(iS)%ntemp = nT362
           pdrAtomColl(iS)%tempK = pdrCoolant2(iS)%TEMPERATURES(1:7, 1:nT362)
           pdrAtomColl(iS)%kDown = 0.d0
           pdrAtomColl(iS)%kDown(1,:,:,:) = pdrCoolant2(iS)%H2_COL(1:iUp, 1:iUp, 1:nT362)
           pdrAtomColl(iS)%kDown(2,:,:,:) = pdrCoolant2(iS)%PH2_COL(1:iUp, 1:iUp, 1:nT362)
           pdrAtomColl(iS)%kDown(3,:,:,:) = pdrCoolant2(iS)%OH2_COL(1:iUp, 1:iUp, 1:nT362)
           pdrAtomColl(iS)%kDown(5,:,:,:) = pdrCoolant2(iS)%H_COL(1:iUp, 1:iUp, 1:nT362)
           pdrAtomColl(iS)%kDown(6,:,:,:) = pdrCoolant2(iS)%HE_COL(1:iUp, 1:iUp, 1:nT362)
           pdrAtomColl(iS)%kDown(7,:,:,:) = pdrCoolant2(iS)%HP_COL(1:iUp, 1:iUp, 1:nT362)
        end do
        if (allocated(pdrEscBeta)) deallocate(pdrEscBeta)
        allocate(pdrEscBeta(pdrMaxLev, pdrMaxLev))
        pdrEscBeta = 1.d0
        ! D-377: the background each transition sees is MOCASSIN's own field
        ! at the line (plus the CMB, which MOCASSIN does not transport), not
        ! the vendored diffuse-ISM grain emissivity
        if (allocated(pdrEscBg)) deallocate(pdrEscBg)
        allocate(pdrEscBg(pdrMaxLev, pdrMaxLev))
        pdrEscBg = 0.d0

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

        ! D-280: the cosmic-ray ionization of every linked neutral, from the
        ! network itself: reactant = the neutral + CRP or CRPHOT, products = its
        ! linked ion + e-. ionBalance adds these to MOCASSIN's up rates, so both
        ! codes ionize from the same coefficients (D-193 did this for H and He
        ! with literals, and for nothing else).
        pdrNcr = 0
        do iR = 1, pdrNreacMod
           do iLnk = 1, pdrNlink
              if (pdrLinkSpec(iLnk) <= 0 .or. pdrLinkIon(iLnk) /= 1) cycle
              sNeut = adjustl(pdrSpecies(pdrLinkSpec(iLnk)))
              sIon  = ''
              do jLnk = 1, pdrNlink
                 if (pdrLinkElem(jLnk) == pdrLinkElem(iLnk) .and. &
                      & pdrLinkIon(jLnk) == 2 .and. pdrLinkSpec(jLnk) > 0) &
                      & sIon = adjustl(pdrSpecies(pdrLinkSpec(jLnk)))
              end do
              if (len_trim(sIon) == 0) cycle
              if (.not. any(adjustl(pdrReactant(iR,:)) == sNeut)) cycle
              if (.not. any(adjustl(pdrProduct(iR,:)) == sIon)) cycle
              if (.not. any(adjustl(pdrProduct(iR,:)) == 'e-')) cycle
              if (any(adjustl(pdrReactant(iR,:)) == 'CRP')) then
                 iTyp280 = 1
              else if (any(adjustl(pdrReactant(iR,:)) == 'CRPHOT')) then
                 iTyp280 = 2
              else
                 cycle
              end if
              if (pdrNcr >= pdrMaxCr) then
                 print*, "! initPDRnetwork: more cosmic-ray ionizations than pdrMaxCr", pdrMaxCr
                 stop
              end if
              pdrNcr = pdrNcr + 1
              pdrCrElem (pdrNcr) = pdrLinkElem(iLnk)
              pdrCrType (pdrNcr) = iTyp280
              pdrCrAlpha(pdrNcr) = pdrAlpha(iR)
              pdrCrBeta (pdrNcr) = pdrBeta(iR)
              pdrCrGamma(pdrNcr) = pdrGamma(iR)
              if (taskid == 0) print '(a,i4,a,a,a,a,a,es10.3,a,f6.2,a,f8.2)', &
                   & " ! [D280] cosmic-ray ionization: reaction", iR, "  ", trim(sNeut), &
                   & merge(" + CRP    -> ", " + CRPHOT -> ", iTyp280 == 1), trim(sIon), &
                   & "  alpha", pdrAlpha(iR), " beta", pdrBeta(iR), " gamma", pdrGamma(iR)
           end do
        end do

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
        ! D-193: unconditional. MOCASSIN always owns the ion stages, so the
        ! network's own photoionization and recombination channels for those
        ! stages are always duplicates and are always suppressed.
        if (taskid == 0) &
             & print*, "! initPDR: linked ionization/recombination channels KEPT &
             &inside the solve (D-260), at MOCASSIN's rates (D-358); MOCASSIN re-imposes afterwards:"
        if (.true.) then
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
                 ! D-260: KEPT, no longer zeroed. Deleting these inside the
                 ! network left the linked ions with production but no loss
                 ! during the solve: H + CRP -> H+ ran with H+ + e- removed, and
                 ! because odes_reduced.c computes x_e as the sum of the evolving
                 ! cations, x_e inflated 13-926x and dissociative recombination
                 ! emptied H3+ (D-258, closure exact at five depths). The
                 ! post-solve re-imposition (D-162 ratios, D-231 electrons) then
                 ! hid it. MOCASSIN still owns the stored ionization state and
                 ! re-imposes it after every solve; the network now only uses
                 ! its own coefficients WHILE it integrates, so its internal
                 ! electrons stay physical. Evidence that this suffices in
                 ! shielded gas: the standalone 3D-PDR, this network with these
                 ! channels intact, gives x_e 1.01-1.12x MOCASSIN's at matched
                 ! illumination (D-257). Photoionization (269 C, 289 Mg) is kept
                 ! with recombination so C+/Mg+ keep both directions.
              end if
           end do
        end if

        ! D-358: the slots MOCASSIN's own ionization and recombination rates
        ! go into (see the module declarations). A linked element with no
        ! first-order ionization slot cannot be given MOCASSIN's rate, and the
        ! solve would ionize it on the network's terms alone: that is refused.
        do iLnk = 1, 5
           sNeut = lnk358(iLnk)
           sIon  = trim(lnk358(iLnk))//'+'
           do iR = 1, pdrNreacMod
              if (.not.(any(adjustl(pdrProduct(iR,:)) == sIon) .and. &
                   & any(adjustl(pdrProduct(iR,:)) == 'e-'))) then
                 ! X+ + e- -> X + PHOTON, radiative only (no grain marker)
                 if (any(adjustl(pdrReactant(iR,:)) == sIon) .and. &
                      & any(adjustl(pdrReactant(iR,:)) == 'e-') .and. &
                      & any(adjustl(pdrProduct(iR,:)) == sNeut) .and. &
                      & any(adjustl(pdrProduct(iR,:)) == 'PHOTON') .and. &
                      & .not. any(adjustl(pdrReactant(iR,:)) == '#')) then
                    if (nRec358(iLnk) < 4) then
                       nRec358(iLnk) = nRec358(iLnk) + 1
                       iRec358(iLnk, nRec358(iLnk)) = iR
                    end if
                 end if
                 cycle
              end if
              if (.not. any(adjustl(pdrReactant(iR,:)) == sNeut)) cycle
              if (any(adjustl(pdrReactant(iR,:)) == 'CRP')) then
                 iCr358(iLnk) = iR
              else if (any(adjustl(pdrReactant(iR,:)) == 'CRPHOT') .and. &
                   & iCr358(iLnk) == 0) then
                 iCr358(iLnk) = -iR           ! CRPHOT only if no CRP slot
              else if (any(adjustl(pdrReactant(iR,:)) == 'PHOTON')) then
                 iPh358(iLnk) = iR
              end if
           end do
           iCr358(iLnk) = abs(iCr358(iLnk))
           if (iCr358(iLnk) == 0) then
              do iR = 1, pdrNspecMod
                 if (trim(adjustl(pdrSpecies(iR))) == trim(sNeut)) then
                    print*, "! initPDRnetwork: no first-order ionization slot for ", &
                         & trim(sNeut), " - MOCASSIN's rate cannot reach the solve (D-358)"
                    stop
                 end if
              end do
           end if
        end do
        do iR = 1, pdrNreacMod
           if (any(adjustl(pdrReactant(iR,:)) == 'H2') .and. &
                & any(adjustl(pdrReactant(iR,:)) == 'CRP') .and. &
                & any(adjustl(pdrProduct(iR,:)) == 'H2+') .and. &
                & any(adjustl(pdrProduct(iR,:)) == 'e-')) iH2cr358 = iR
        end do
        if (taskid == 0) then
           print*, "! initPDR: MOCASSIN's ionization and recombination rates enter the solve (D-358):"
           do iLnk = 1, 5
              print '(a,a2,a,i4,a,i4,a,4i4)', " !   ", lnk358(iLnk), &
                   & "  ionization slot", iCr358(iLnk), "  own photoionization zeroed", &
                   & iPh358(iLnk), "  recombination", iRec358(iLnk,1:4)
           end do
           print '(a,i4)', " !   H2 -> H2+ slot", iH2cr358
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
        integer :: iLnk, iEl                  ! D-251
        logical :: lgAbunMissing              ! D-251
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
           ! D-208: the comparison above is still worth printing - the two
           ! files genuinely disagree, C/H is 1.4e-4 against 2.2e-4 - but it
           ! is now a report, not a choice. Every cell is seeded from
           ! MOCASSIN's elemAbun and ionDen, so the network's column is
           ! documentation of what was NOT used.
           print*, "!   MOCASSIN's values are used; the network column is what &
                &was not used (D-208)"
        end if

        ! ------------------------------------------------------------- D-251
        ! An element the network carries with a non-zero initial abundance,
        ! switched off in MOCASSIN, is DELETED from the chemistry - not kept at
        ! the network's value. seedAbunFromMocassin builds the seed from zero
        ! and cycles past elements that are off, so the slot keeps that zero
        ! and pdrAbun is overwritten with it.
        !
        ! Magnesium is the case that matters in the REDUCED network, and it is
        ! silent: Mg is a CLOSED sub-system - of its eleven reactions, ten make
        ! Mg+ from Mg and one makes Mg from Mg+, and nothing produces either
        ! from a non-Mg species. So x(Mg) + x(Mg+) is conserved at whatever it
        ! is seeded with, a zero seed stays zero for the whole run, and the
        ! solver neither fails nor complains. What is lost is eight
        ! charge-transfer sinks for molecular ions (H3+, CH5+, CH3+, H2O+, CH+,
        ! C+, H+, O2+ each strip Mg WITHOUT consuming an electron) and the
        ! dominant electron donor of shielded gas - up to 99.3% of x(e-) in the
        ! deep V2 slab against the reference (D-250).
        !
        ! The chemistry does not fail without it, it answers a different
        ! question - which is exactly why this is a stop and not a warning. A
        ! model whose network expects an element MOCASSIN is not carrying is
        ! misconfigured, and D-250 is what that costs when it goes unnoticed.
        lgAbunMissing = .false.
        do iLnk = 1, pdrNlink
           if (pdrLinkSpec(iLnk) <= 0) cycle
           iEl = pdrLinkElem(iLnk)
           if (iEl < 2 .or. iEl > nElements) cycle      ! hydrogen is always on
           if (pdrInitAbun(pdrLinkSpec(iLnk)) <= 0.d0) cycle
           if (lgElementOn(iEl)) then
              if (grid(1)%elemAbun(1, iEl) > 0.) cycle
           end if
           if (taskid == 0) then
              print*, "! seedPDR: MOCASSIN element", iEl, " is switched off, but the &
                   &network carries species", pdrLinkSpec(iLnk)
              print*, "!   with initial abundance", pdrInitAbun(pdrLinkSpec(iLnk)), &
                   & " - the seed would DELETE it, not keep it."
              print*, "!   Give element", iEl, " an abundance in the nebComposition &
                   &file (element 12 is Mg)."
           end if
           lgAbunMissing = .true.
        end do
        if (lgAbunMissing) then
           if (taskid == 0) print*, "! seedPDR: refusing to run - a network element is &
                &absent from MOCASSIN's composition (D-251)"
           stop
        end if

        do iG = 1, nGrids
           if (iG > 1 .or. (.not.lg2D)) then
              yTop = grid(iG)%ny
           else
              yTop = 1
           end if

           ! D-208: zero, not the network file's defaults. A cell with no
           ! gas has no species; a cell with gas is filled from MOCASSIN
           ! below. The old line wrote x(H) = 0.400 and x(H2) = 0.300 into
           ! every cell including cell 0 and the inactive ones, which nothing
           ! ever re-seeded, and D-188's claim that the defaults never reach a
           ! solved cell held only for the abundances - the shielding columns
           ! at the first PDR iteration were integrated over exactly these
           ! values. See seedAbunFromMocassin.
           do iCell = 0, grid(iG)%nCells
              grid(iG)%pdrAbun(iCell,:) = 0.d0
           end do

           do i = 1, grid(iG)%nx
              do j = 1, yTop
                 do k = 1, grid(iG)%nz
                    iCell = grid(iG)%active(i,j,k)
                    if (iCell <= 0) cycle
                    iAb = grid(iG)%abFileIndex(i,j,k)

                    ! D-208. Molecules zero, every carrier from MOCASSIN -
                    ! the same rule pdrStep applies on a cell's first visit.
                    !
                    ! This replaces `seed = pdrInitAbun` followed by syncSeed
                    ! on He, C, O and Mg. That construction rescaled four
                    ! elements to MOCASSIN's abundances and left hydrogen at
                    ! the network file's x(H) = 0.400 and x(H2) = 0.300, and
                    ! left every molecule at its dark-cloud value. syncSeed
                    ! and the pdrSyncAbun keyword go with it: there is nothing
                    ! left to synchronise when the seed is built from
                    ! MOCASSIN's own numbers in the first place.
                    call seedAbunFromMocassin(grid(iG), iCell, iAb, seed)
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
      ! Record that a network species carries one ionization stage of one
      ! MOCASSIN element.
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


      ! D-208: syncSeed is gone. It rescaled four elements of the network
      ! file's seed to MOCASSIN's abundances and left hydrogen and every
      ! molecule at the file's dark-cloud values. seedAbunFromMocassin builds
      ! the whole seed from MOCASSIN instead, so there is nothing to rescale.


      subroutine reportAbun(elem, iSp, abunMoc, label)
        implicit none
        integer, intent(in)          :: elem, iSp
        real, intent(in)             :: abunMoc
        character(len=2), intent(in) :: label

        if (iSp <= 0) then
           print*, "!   ", label, " not in this network"
        else if (abunMoc <= 0.) then
           ! D-251: this used to claim "network value kept". It is not kept -
           ! seedAbunFromMocassin zeroes the slot and pdrAbun is overwritten
           ! with the zero, so the element is deleted from the chemistry. The
           ! message asserted the opposite for every run that had Mg off.
           print*, "!   ", label, " network ", pdrInitAbun(iSp), &
                & " MOCASSIN: element OFF - the seed DELETES it (D-251)"
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


      !-----------------------------------------------------------------
      ! D-195: is this grain material carbonaceous?
      !
      ! H2 forms on grain surfaces, and Cazaux & Tielens give silicate and
      ! carbonaceous surfaces different binding energies - so the rate needs to
      ! know which surface it is looking at, not just how much of it there is.
      ! MOCASSIN's grain labels come from the .nk files and follow no single
      ! convention, so the match is on substrings and the full classification is
      ! PRINTED at startup for inspection rather than trusted silently.
      !-----------------------------------------------------------------
      logical function isCarbonGrain(label)
        implicit none

        character(len=*), intent(in) :: label
        character(len=30) :: lc
        integer           :: i, ic

        lc = ' '
        do i = 1, min(len(label), 30)
           ic = iachar(label(i:i))
           if (ic >= iachar('A') .and. ic <= iachar('Z')) ic = ic + 32
           lc(i:i) = achar(ic)
        end do

        isCarbonGrain = (index(lc,'graph') > 0) .or. (index(lc,'grph')  > 0) &
             &     .or. (index(lc,'amc')   > 0) .or. (index(lc,'carb')  > 0) &
             &     .or. (index(lc,'pah')   > 0) .or. (index(lc,'sic')   > 0) &
             &     .or. (index(lc,'gr1')   > 0) .or. (index(lc,'gr2')   > 0)

      end function isCarbonGrain


      !-----------------------------------------------------------------
      ! D-195: measure the geometric grain area this model actually carries.
      !
      ! H2_FORMATION_RATE is LINEAR in the grain cross section per H nucleus,
      ! and upstream hardcodes that as a diffuse-ISM constant - so the H/H2
      ! front sat where standard ISM dust would put it no matter what dust the
      ! model was given. MOCASSIN knows the size distribution, the composition
      ! and the dust-to-gas ratio, so it can simply measure it.
      !
      ! The per-grain part is fixed by the size distribution: sum over sizes of
      ! pi a^2 weighted by grainWeight (which is normalised to 1) and by the
      ! species abundance, exactly the weighting dustOpacity uses to build
      ! absOpac from Ndust - so the area and the opacity describe the same
      ! grains. The per-H part, Ndust/Hden, is per cell and is applied in
      ! dustPerCell.
      !-----------------------------------------------------------------
      subroutine measureH2grainArea()
        implicit none

        integer          :: nsp, nspec, ai, iSpec, err
        double precision :: aCm2, sigTot
        logical          :: lgUnknown

        if (lgH2areaDone) return
        lgH2areaDone = .true.

        if (.not.lgDust) return

        allocate(sigSilGrain(1:nDustComponents), stat = err)
        if (err /= 0) then
           print*, "! measureH2grainArea: can't allocate sigSilGrain"; stop
        end if
        allocate(sigGraGrain(1:nDustComponents), stat = err)
        if (err /= 0) then
           print*, "! measureH2grainArea: can't allocate sigGraGrain"; stop
        end if
        sigSilGrain = 0.d0
        sigGraGrain = 0.d0
        lgUnknown   = .false.

        if (taskid == 0) then
           print*, "! [D195] H2 formation grain area, measured from this model's dust:"
           print*, "!   (component, species, label, material, mean pi a^2 per grain [cm^2])"
        end if

        do nsp = 1, nDustComponents
           do nspec = 1, nSpeciesPart(nsp)
              iSpec  = dustComPoint(nsp) - 1 + nspec
              sigTot = 0.d0
              do ai = 1, nSizes
                 if (grainRadius(ai) < componentMinRadius(nsp, nspec)) cycle
                 if (grainRadius(ai) > componentMaxRadius(nsp, nspec)) cycle
                 aCm2   = dble(grainRadius(ai))*1.d-4          ! um -> cm
                 sigTot = sigTot + dble(Pi)*aCm2*aCm2 &
                        &        * dble(grainWeight(ai))*dble(grainAbun(nsp, nspec))
              end do

              if (isCarbonGrain(grainLabel(iSpec))) then
                 sigGraGrain(nsp) = sigGraGrain(nsp) + sigTot
              else
                 sigSilGrain(nsp) = sigSilGrain(nsp) + sigTot
                 ! everything that is not recognisably carbonaceous goes to the
                 ! silicate channel; say so when the label was not recognised
                 ! either, so an unlisted material is never silently binned
                 if (.not.isSilicateGrain(grainLabel(iSpec))) lgUnknown = .true.
              end if

              if (taskid == 0) then
                 if (isCarbonGrain(grainLabel(iSpec))) then
                    print*, "!  ", nsp, nspec, trim(grainLabel(iSpec)), &
                         & "  carbonaceous ", real(sigTot)
                 else if (isSilicateGrain(grainLabel(iSpec))) then
                    print*, "!  ", nsp, nspec, trim(grainLabel(iSpec)), &
                         & "  silicate     ", real(sigTot)
                 else
                    print*, "!  ", nsp, nspec, trim(grainLabel(iSpec)), &
                         & "  UNRECOGNISED -> silicate ", real(sigTot)
                 end if
              end if
           end do
        end do

        if (lgUnknown .and. taskid == 0) then
           print*, "! [D195] [warning] at least one grain label was not recognised as"
           print*, "!   silicate or carbonaceous and was assigned to the silicate"
           print*, "!   channel of Cazaux & Tielens. Check the table above."
        end if

      end subroutine measureH2grainArea


      logical function isSilicateGrain(label)
        implicit none

        character(len=*), intent(in) :: label
        character(len=30) :: lc
        integer           :: i, ic

        lc = ' '
        do i = 1, min(len(label), 30)
           ic = iachar(label(i:i))
           if (ic >= iachar('A') .and. ic <= iachar('Z')) ic = ic + 32
           lc(i:i) = achar(ic)
        end do

        isSilicateGrain = (index(lc,'sil')  > 0) .or. (index(lc,'oliv') > 0) &
             &       .or. (index(lc,'pyr')  > 0) .or. (index(lc,'enst') > 0) &
             &       .or. (index(lc,'forst')> 0) .or. (index(lc,'quartz') > 0) &
             &       .or. (index(lc,'oss')  > 0)

      end function isSilicateGrain


      subroutine dustPerCell(grid)
        implicit none

        type(grid_type), dimension(:), intent(inout) :: grid

        integer          :: iG, cP, ifreq, nsp
        double precision :: kV, kFUV, wsum, perH
        double precision :: wt(nbins)

        ! D-195: the H2 formation area is a property of the same grains, and is
        ! wanted in every cell the chemistry runs in - so it is filled here,
        ! in the loop that already visits them, not on a separate pass.
        call measureH2grainArea()

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

              ! D-195. Deliberately BEFORE the kV cycle below: a cell with no
              ! dust has no A_V scale to speak of (hence the fallback there) but
              ! it does have a well-defined grain area for H2 formation, namely
              ! zero. Falling back to a diffuse-ISM constant there would form H2
              ! on grains the model does not contain.
              if (allocated(sigSilGrain) .and. grid(iG)%Hden(cP) > 0.) then
                 if (lgMultiDustChemistry) then
                    nsp = grid(iG)%dustAbunIndex(cP)
                 else
                    nsp = 1
                 end if
                 if (nsp >= 1 .and. nsp <= nDustComponents) then
                    perH = dble(grid(iG)%Ndust(cP))/dble(grid(iG)%Hden(cP))
                    grid(iG)%dustSigSil(cP) = real(perH*sigSilGrain(nsp))
                    grid(iG)%dustSigGra(cP) = real(perH*sigGraGrain(nsp))
                 end if
              end if

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
        pdrUVfacMod = dble(pdrRfuv)/dble(magPerTau)     ! D-352: this model's own
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
        ! D-352: unconditional - the pdrOwnDust switch back to the Savage &
        ! Mathis table is gone.
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
        if (taskid == 0) print*, "! [D077] FUV band bins:", FUVhighP-FUVlowP+1, &
             & " of", nbins, " (FUVlowP,FUVhighP =", FUVlowP, FUVhighP, &
             & ") nu =", real(nuArray(FUVlowP)), real(nuArray(FUVhighP))

        if (taskid == 0) then
           print*, "! calibratePDRdust: measured from this model's grains -"
           print*, "!   tau_FUV/tau_V      = ", pdrRfuv, " over ", nUsed, " FUV bins"
           print*, "!   implied UV_fac     = ", pdrRfuv/magPerTau
        end if

        ! D-195: report the H2 formation area against what upstream assumes, at
        ! the densest dusty cell found above, so the size of the change is on
        ! the record rather than buried in the chemistry.
        if (taskid == 0 .and. lgDust) then
           print*, "! [D195] H2 formation grain area at the calibration cell:"
           print*, "!   silicate     = ", grid(1)%dustSigSil(iCell), &
                & " cm^2/H   (Cazaux & Tielens assume 8.473e-22)"
           print*, "!   carbonaceous = ", grid(1)%dustSigGra(iCell), &
                & " cm^2/H   (Cazaux & Tielens assume 7.908e-22)"
           print*, "!   the H2 formation rate is LINEAR in these"
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
      ! D-397: the cells a straight ray crosses, each with the exact length
      ! of the ray inside it.
      !
      ! A cell owns the points nearer to its axis value than to its
      ! neighbours' (MOCASSIN's cells), so its faces are the midpoints of the
      ! axes, and the grid ends at the first and last axis values. The ray
      ! starts at (x0,y0,z0) inside the grid, runs along the unit vector
      ! (ux,uy,uz), and ends after the length sMax or where it leaves the
      ! grid. With lgMirror the lower faces are planes of symmetry (a
      ! symmetricXYZ octant, D-340): the ray is reflected there and runs on.
      ! On return rayCell(1:nSeg) holds the active-cell index of each cell in
      ! the order crossed (0 where the cell is not active) and rayLen(1:nSeg)
      ! the length in it [cm]. The first is the cell the ray starts in.
      !
      ! It replaces the marches that took the nearest cell once per step of
      ! the finest axis spacing, the first sample half a step from the
      ! target cell's centre. Those gave each cell a whole number of steps.
      ! The first sample fell inside the target cell, which the shielding
      ! columns leave out (D-088), so the path between the target's face and
      ! the end of the first step - in the neighbour that shields it most -
      ! was never counted. Through hiipdr's H2 transition, where n(H2) rises
      ! 5-10x from one cell to the next, the star-ward N(H2) came out at a
      ! median 0.46-0.75 of the exact one, and below 0.35 of it in one cell
      ! in twenty; on a ray along a grid axis the samples fell on the faces
      ! themselves and a whole cell could go missing.
      !-----------------------------------------------------------------
      subroutine rayCells(grid, x0, y0, z0, ux, uy, uz, sMax, lgMirror, nSeg)
        implicit none
        type(grid_type), intent(in)  :: grid
        double precision, intent(in) :: x0, y0, z0, ux, uy, uz, sMax
        logical, intent(in)          :: lgMirror
        integer, intent(out)         :: nSeg

        integer          :: n(3), idx(3), q, cP, need, it
        double precision :: u(3), pos(3), sNext(3), s, sN, face

        n = (/ grid%nx, grid%ny, grid%nz /)
        ! each axis is crossed at most once downwards and once upwards
        need = 2*(n(1) + n(2) + n(3)) + 8
        if (allocated(rayCell)) then
           if (size(rayCell) < need) deallocate(rayCell, rayLen)
        end if
        if (.not.allocated(rayCell)) allocate(rayCell(need), rayLen(need))

        nSeg = 0
        u    = (/ ux, uy, uz /)
        pos  = (/ x0, y0, z0 /)
        idx(1) = nearIdx(grid%xAxis, n(1), x0)
        idx(2) = nearIdx(grid%yAxis, n(2), y0)
        idx(3) = nearIdx(grid%zAxis, n(3), z0)
        do q = 1, 3
           sNext(q) = huge(1.d0)
           if (u(q) /= 0.d0) sNext(q) = abs(nextFace(q) - pos(q))/abs(u(q))
        end do

        s = 0.d0
        do it = 1, 2*need
           q  = minloc(sNext, 1)
           sN = min(sNext(q), sMax)
           if (sN > s) then
              cP = max(grid%active(idx(1), idx(2), idx(3)), 0)
              if (nSeg > 0 .and. cP > 0 .and. rayCell(max(nSeg,1)) == cP) then
                 ! back in the cell it was just in (a reflection)
                 rayLen(nSeg) = rayLen(nSeg) + (sN - s)
              else
                 if (nSeg >= size(rayCell)) exit
                 nSeg = nSeg + 1
                 rayCell(nSeg) = cP
                 rayLen(nSeg)  = sN - s
              end if
              s = sN
           end if
           if (sNext(q) >= sMax) exit

           ! through the face on axis q
           face = nextFace(q)
           if (u(q) > 0.d0) then
              if (idx(q) >= n(q)) exit                 ! the edge of the grid
              idx(q) = idx(q) + 1
           else if (idx(q) <= 1) then
              if (.not.lgMirror) exit                  ! the edge of the grid
              u(q) = -u(q)                             ! a plane of symmetry
           else
              idx(q) = idx(q) - 1
           end if
           pos(q)   = face
           sNext(q) = sNext(q) + abs(nextFace(q) - pos(q))/abs(u(q))
        end do

      contains

        ! the next face on axis q in the ray's direction: the midpoint to the
        ! neighbouring axis value, or the end of the axis
        double precision function nextFace(q)
          implicit none
          integer, intent(in) :: q
          select case (q)
          case (1)
             nextFace = faceOf(grid%xAxis, n(1), idx(1), u(1))
          case (2)
             nextFace = faceOf(grid%yAxis, n(2), idx(2), u(2))
          case default
             nextFace = faceOf(grid%zAxis, n(3), idx(3), u(3))
          end select
        end function nextFace

        double precision function faceOf(ax, na, ia, ua)
          implicit none
          real, intent(in)             :: ax(:)
          integer, intent(in)          :: na, ia
          double precision, intent(in) :: ua
          if (ua > 0.d0) then
             if (ia < na) then
                faceOf = 0.5d0*(dble(ax(ia)) + dble(ax(ia+1)))
             else
                faceOf = dble(ax(na))
             end if
          else
             if (ia > 1) then
                faceOf = 0.5d0*(dble(ax(ia-1)) + dble(ax(ia)))
             else
                faceOf = dble(ax(1))
             end if
          end if
        end function faceOf

        ! the axis value nearest to a coordinate
        integer function nearIdx(ax, na, v)
          implicit none
          real, intent(in)             :: ax(:)
          integer, intent(in)          :: na
          double precision, intent(in) :: v
          integer :: lo, hi, mid
          lo = 1; hi = na
          do while (hi - lo > 1)
             mid = (lo + hi)/2
             if (v >= dble(ax(mid))) then
                lo = mid
             else
                hi = mid
             end if
          end do
          if (abs(v-dble(ax(hi))) < abs(v-dble(ax(lo)))) then
             nearIdx = hi
          else
             nearIdx = lo
          end if
        end function nearIdx

      end subroutine rayCells

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

        integer          :: iG, i, j, k, cellP, iS, m, nSeg
        integer          :: cP
        double precision :: sx, sy, sz, dxs, dys, dzs, seg, ds, tauS, fS
        double precision :: fSum, fTot, kap, avS
        double precision :: cH2S, cCS, cCOS, wH2, wC, wCO, tauB, wB, nd
        double precision :: cx, cy, cz, ownS, wOwn
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
                    wOwn = 0.d0
                    do iS = 1, nStars
                       sx = dble(starPosition(iS)%x)
                       sy = dble(starPosition(iS)%y)
                       sz = dble(starPosition(iS)%z)
                       dxs = dble(grid(iG)%xAxis(i)) - sx
                       dys = dble(grid(iG)%yAxis(j)) - sy
                       dzs = dble(grid(iG)%zAxis(k)) - sz
                       seg = sqrt(dxs*dxs + dys*dys + dzs*dzs)
                       if (seg <= 0.d0) cycle

                       ! D-397: the ray between the source and the cell's
                       ! centre, cell by cell with its exact length in each
                       ! (rayCells). It is traced from the centre, which is
                       ! always inside the grid, towards the source.
                       cx = dble(grid(iG)%xAxis(i))
                       cy = dble(grid(iG)%yAxis(j))
                       cz = dble(grid(iG)%zAxis(k))
                       call rayCells(grid(iG), cx, cy, cz, -dxs/seg, -dys/seg, &
                            & -dzs/seg, seg, .false., nSeg)
                       tauS = 0.d0
                       cH2S = 0.d0
                       cCS  = 0.d0
                       cCOS = 0.d0
                       ownS = 0.d0
                       do m = 1, nSeg
                          cP = rayCell(m)
                          if (cP <= 0) cycle
                          ds = rayLen(m)
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
                          ! D-088 let only PDR-zone cells shield, because
                          ! outside the zone pdrAbun still held seedPDR's
                          ! x(H2) = 0.3 - the chemistry never ran there. D-350
                          ! removed that test (the chemistry runs in every cell,
                          ! D-198, seeded with no molecules, D-208) and measured
                          ! what it added: at most 2.7e12 cm^-2, at the front.
                          ! D-352 removed the zone flag itself.
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
                          ! amplifying. (D-397: with the exact path lengths the
                          ! column is the one to the cell's near face on this
                          ! ray. The sampled march it replaces also dropped
                          ! the part of the neighbouring cell between that
                          ! face and the end of its first step.)
                          if (cP /= cellP) then
                             nd   = dble(grid(iG)%Hden(cP))
                             cH2S = cH2S + nd*dble(grid(iG)%pdrAbun(cP,NH2))*ds
                             cCS  = cCS  + nd*dble(grid(iG)%pdrAbun(cP,NC ))*ds
                             cCOS = cCOS + nd*dble(grid(iG)%pdrAbun(cP,NCO))*ds
                          else
                             ! D-398: the ray's length in the cell itself,
                             ! from its near face to its centre
                             ownS = ownS + ds
                          end if
                       end do

                       ! remaining column outwards, along the same direction,
                       ! to the grid boundary: what the outward escape rays see
                       ! (D-397: exact lengths, ending at the edge of the grid;
                       ! the sampled march ran a fixed length on, taking the
                       ! edge cell for every step beyond the grid)
                       call rayCells(grid(iG), cx, cy, cz, dxs/seg, dys/seg, &
                            & dzs/seg, huge(1.d0), lgSymmetricXYZ, nSeg)
                       tauB = 0.d0
                       do m = 1, nSeg
                          cP = rayCell(m)
                          if (cP <= 0) cycle
                          tauB = tauB + (dble(grid(iG)%absOpac(cP,VbandP)) &
                               &       + dble(grid(iG)%scaOpac(cP,VbandP)))*rayLen(m)
                       end do

                       avS  = dble(magPerTau)*tauS
                       fS   = 1.d0/(seg*seg)          ! geometric dilution only
                       fTot = fTot + fS
                       fSum = fSum + fS*exp(-RfuvL*avS/dble(magPerTau))
                       wH2  = wH2 + fS*cH2S
                       wC   = wC  + fS*cCS
                       wCO  = wCO + fS*cCOS
                       wB   = wB  + fS*dble(magPerTau)*tauB
                       wOwn = wOwn + fS*ownS
                    end do

                    if (fTot > 0.d0 .and. fSum > 0.d0) then
                       grid(iG)%AVeff(cellP) = real( &
                            & -dble(magPerTau)/RfuvL*log(fSum/fTot))
                       ! flux-weighted columns (exact for a single source)
                       grid(iG)%pdrColH2(cellP) = real(wH2/fTot)
                       grid(iG)%pdrColC (cellP) = real(wC /fTot)
                       grid(iG)%pdrColCO(cellP) = real(wCO/fTot)
                       grid(iG)%AVback  (cellP) = real(wB /fTot)
                       ! D-398: for the scattering sites in this cell
                       ! (traceDiffuseSites); the snapshot exists in the
                       ! ray-traced flavour only
                       if (allocated(grid(iG)%difSrc)) &
                            & grid(iG)%difSrc(cellP,6) = wOwn/fTot
                    end if
                 end do
              end do
           end do
        end do

      end subroutine computeAVradial

#ifdef RAYTHEIA
      !-----------------------------------------------------------------
      ! D-348 (specified in D-347): the diffuse FUV field as scattering sites
      ! along twelve HEALPix directions, each site carrying the two-leg column
      ! its photons actually crossed.
      !
      ! What this replaces. computeRayColumns (D-190) traced each ray from the
      ! cell to the outer boundary and stored the column per (cell, ray). That
      ! column answers "how is radiation arriving from OUTSIDE attenuated on
      ! its way in" - right for 3D-PDR, whose FUV is a boundary condition, and
      ! wrong here, where the star is inside and the diffuse field is made by
      ! scattering within the cloud. It also ran on the wrong rank: it kept the
      ! cells with mod(cellP-(taskid+1),numtasks) == 0, where pdrStep owns
      ! mod(iCell-(taskid+1),numtasks) == 0 with iCell counting INACTIVE cells
      ! too, and its output was never reduced. On hiipdr only 1011 of 15204
      ! active cells (6.6%) had their columns computed on the rank that read
      ! them; the rest read the zero-initialised arrays (D-348).
      !
      ! What it does instead. A photon scattered at P and arriving at the cell
      ! C has crossed
      !
      !     N_eff = N(star -> P) + N(P -> C)
      !
      ! The first leg is pdrColH2/C/CO(P) (D-078/D-088), stored per cell, to
      ! that cell's near face, plus the cell's own gas from there to its
      ! centre (D-398); the second is accumulated along the walk. The walk is done HERE,
      ! per cell, on the rank that consumes it, so there is no ownership to get
      ! wrong and no per-(cell,ray) storage.
      !
      ! Each step of the walk is one scattering site. Its weight is the formal
      ! solution of the transfer equation for isotropic scattering,
      !
      !     w = S(P) exp(-tau(C->P)) (1 - exp(-dtau)),  S = sum_nu kSca*J / kExt
      !
      ! built from MOCASSIN's own scattering opacity, FUV extinction and field.
      ! The sites are handed to the chemistry as rays of their own (pdrStep),
      ! so the vendored shielding functions - H2SHIELD1, COSHIELD, the C I
      ! band - are each evaluated per site on the site's own columns: the
      ! non-linear factor is never applied to a mean column (D-100's point).
      !
      ! Everything the walk reads is the snapshot snapDiffuseSources takes in
      ! computeAVdust, i.e. the same abundances pdrColH2 was integrated from.
      ! The live pdrAbun would mix this coupling pass's values (cells this rank
      ! has already solved) with the last pass's (every other cell), and the
      ! answer would depend on the rank count and the order of the sweep.
      !
      ! Directions are the twelve HEALPix nside=1 pixel centres in RING order,
      ! constructed directly (the vendored pix2vec_nest is never initialised):
      ! rays 0-3 at mu = +2/3, 4-7 at 0, 8-11 at -2/3.
      !-----------------------------------------------------------------

      !-----------------------------------------------------------------
      ! D-348: what traceDiffuseSites reads, per cell, taken once per MC
      ! iteration beside the source-ward columns:
      !   difSrc(:,1:3)  n(H2), n(C), n(CO) [cm^-3] that shield, in every cell
      !   difSrc(:,4)    FUV extinction coefficient [1/cm], R_FUV*kappa_V from
      !                  this cell's own grains (D-109)
      !   difSrc(:,5)    FUV scattering emissivity sum_nu kSca(nu)*J(nu)
      !                  [Jste units / cm], the MC's full local field
      !   difSrc(:,6)    the length of the source-ward ray inside this cell,
      !                  from its centre to its near face [cm] (D-398; filled
      !                  by computeAVradial right after this snapshot)
      ! Allocated here, not in grid_mod, for the reason D-341 gives: this is
      ! the file the RAYTHEIA flag actually reaches.
      !-----------------------------------------------------------------
      subroutine snapDiffuseSources(grid)
        implicit none
        type(grid_type), dimension(:), intent(inout) :: grid

        integer          :: iG, cP, ifreq, errAlloc
        double precision :: nd, kV, rfuvL, emis, jnu

        do iG = 1, nGrids
           if (.not.allocated(grid(iG)%difSrc)) then
              allocate(grid(iG)%difSrc(0:grid(iG)%nCells, 1:6), stat=errAlloc)
              if (errAlloc /= 0) then
                 print*, "! snapDiffuseSources: can't allocate difSrc"
                 stop
              end if
           end if
           grid(iG)%difSrc = 0.d0
           do cP = 1, grid(iG)%nCells
              if (grid(iG)%Hden(cP) <= 0.) cycle
              ! every cell shields, with whatever the chemistry holds there
              nd = dble(grid(iG)%Hden(cP))
              grid(iG)%difSrc(cP,1) = nd*dble(grid(iG)%pdrAbun(cP,NH2))
              grid(iG)%difSrc(cP,2) = nd*dble(grid(iG)%pdrAbun(cP,NC ))
              grid(iG)%difSrc(cP,3) = nd*dble(grid(iG)%pdrAbun(cP,NCO))
              kV = dble(grid(iG)%absOpac(cP,VbandP)) &
                 & + dble(grid(iG)%scaOpac(cP,VbandP))
              rfuvL = dble(grid(iG)%dustRfuv(cP))
              if (rfuvL <= 0.d0) rfuvL = dble(pdrRfuv)
              grid(iG)%difSrc(cP,4) = rfuvL*kV
              emis = 0.d0
              do ifreq = FUVlowP, FUVhighP
                 jnu = dble(grid(iG)%Jste(cP,ifreq))
                 ! under lgDebug the diffuse packets are in Jdif ALONE
                 if (lgDebug) jnu = jnu + dble(grid(iG)%Jdif(cP,ifreq))
                 emis = emis + dble(grid(iG)%scaOpac(cP,ifreq))*jnu
              end do
              grid(iG)%difSrc(cP,5) = emis
           end do
        end do

      end subroutine snapDiffuseSources


      !-----------------------------------------------------------------
      ! D-348: walk the twelve directions from cell (xP,yP,zP) and return the
      ! scattering sites in siteW (weight) and siteN (H2, C, CO two-leg
      ! columns), 1..nSite. Also returns, for the diagnostics:
      !   wTot     sum of all weights; wTot/12 is the formal solution's J_dif
      !   aniso    brightest direction over the mean, sum_k basis
      !   colWalk  N(H2) walked from the cell to the star with this routine's
      !   avWalk   own stepping, and the A_V along the same path - the scale
      !            check D-342 listed (against pdrColH2 and AVeff, which
      !            computeAVradial built independently). -1 unless nStars == 1.
      !   nUnset   sites whose first leg was never computed (pdrColH2 < 0)
      !-----------------------------------------------------------------
      subroutine traceDiffuseSites(grid, xP, yP, zP, cellP, nSite, wTot, &
           & aniso, colWalk, avWalk, nUnset)
        implicit none
        type(grid_type), intent(in) :: grid
        integer, intent(in)           :: xP, yP, zP, cellP
        integer, intent(out)          :: nSite, nUnset
        double precision, intent(out) :: wTot, aniso, colWalk, avWalk

        integer          :: kray, istep, cP, need, nSeg
        double precision, save :: vx(0:11), vy(0:11), vz(0:11)
        logical, save    :: lgDirs = .false.
        double precision :: zz, ph, sr, ds, px, py, pz, seg
        double precision :: x0, y0, z0
        double precision :: tau, dtau, kext, emis, esc, w, tauV, cH2w
        double precision :: cN(3), dN(3), col1(3), wRay(0:11)

        if (.not.lgDirs) then
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
           lgDirs = .true.
        end if

        nSite = 0; nUnset = 0
        wTot = 0.d0; aniso = 0.d0; colWalk = -1.d0; avWalk = -1.d0
        wRay = 0.d0

        ! D-397: one site per cell a ray crosses (rayCells), at most this many
        need = 12*(2*(grid%nx + grid%ny + grid%nz) + 8)
        if (allocated(siteW)) then
           if (size(siteW) < need) deallocate(siteW, siteN)
        end if
        if (.not.allocated(siteW)) allocate(siteW(need), siteN(3,need))

        x0 = dble(grid%xAxis(xP)); y0 = dble(grid%yAxis(yP)); z0 = dble(grid%zAxis(zP))

        do kray = 0, 11
           tau = 0.d0
           cN  = 0.d0
           ! D-397: the cells the ray crosses, each with its exact length.
           ! The lower faces of a symmetricXYZ octant are planes of symmetry,
           ! not edges (D-340): the ray is reflected there. The upper faces are
           ! the edge of the model, and a ray reaching one has left the cloud.
           call rayCells(grid, x0, y0, z0, vx(kray), vy(kray), vz(kray), &
                & huge(1.d0), lgSymmetricXYZ, nSeg)
           do istep = 1, nSeg
              cP = rayCell(istep)
              if (cP <= 0) cycle
              ds = rayLen(istep)

              kext = grid%difSrc(cP,4)
              dtau = kext*ds
              ! only cells IN FRONT of this one shield it (D-088): the target
              ! cell's own column is kept out of the second leg exactly as
              ! computeAVradial keeps it out of the first
              dN = 0.d0
              if (cP /= cellP) dN = grid%difSrc(cP,1:3)*ds

              emis = grid%difSrc(cP,5)
              if (emis > 0.d0 .and. kext > 0.d0) then
                 ! emission from within the cell's part of the ray, escaping
                 ! through the rest of it: (1 - e^-dtau)/kext, which is its
                 ! length for a thin one
                 if (dtau > 1.d-4) then
                    esc = (1.d0 - exp(-dtau))/kext
                 else
                    esc = ds*(1.d0 - 0.5d0*dtau)
                 end if
                 w = emis*esc*exp(-tau)
                 if (w > 0.d0) then
                    col1(1) = dble(grid%pdrColH2(cP))
                    col1(2) = dble(grid%pdrColC (cP))
                    col1(3) = dble(grid%pdrColCO(cP))
                    if (any(col1 < 0.d0)) nUnset = nUnset + 1
                    col1 = max(col1, 0.d0)
                    ! D-398: the first leg runs to the site, not to the near
                    ! face of the site's cell. The light scattered in a cell
                    ! has crossed, on its way from the source, that cell's
                    ! own gas as far as the scattering point - to the cell's
                    ! centre, for the cell's mean field. D-347 took the
                    ! stored near-face column because it was at hand. The
                    ! target cell's own column stays out, as in the direct
                    ! beam (D-088).
                    if (cP /= cellP) col1 = col1 + grid%difSrc(cP,1:3)*grid%difSrc(cP,6)
                    nSite = nSite + 1
                    siteW(nSite)   = w
                    ! the site sits in the middle of its cell's part of the
                    ! ray: half of that is between it and the cell (when that
                    ! cell shields at all)
                    siteN(:,nSite) = col1 + cN + 0.5d0*dN
                    wRay(kray)     = wRay(kray) + w
                 end if
              end if
              tau = tau + dtau
              cN  = cN  + dN
           end do
        end do

        wTot = sum(wRay)
        if (wTot > 0.d0) aniso = maxval(wRay)/(wTot/12.d0)

        ! The scale check: the same snapshot, walked from this cell to the
        ! star, against the columns computeAVradial traced. Since D-397 both
        ! are the same exact path (rayCells), so this only says that the
        ! snapshot and the stored columns are of the same abundances.
        if (nStars == 1) then
           px = dble(starPosition(1)%x) - x0
           py = dble(starPosition(1)%y) - y0
           pz = dble(starPosition(1)%z) - z0
           seg = sqrt(px*px + py*py + pz*pz)
           if (seg > 0.d0) then
              call rayCells(grid, x0, y0, z0, px/seg, py/seg, pz/seg, seg, &
                   & .false., nSeg)
              tauV = 0.d0; cH2w = 0.d0
              do istep = 1, nSeg
                 cP = rayCell(istep)
                 if (cP <= 0) cycle
                 tauV = tauV + (dble(grid%absOpac(cP,VbandP)) &
                      &       + dble(grid%scaOpac(cP,VbandP)))*rayLen(istep)
                 if (cP /= cellP) cH2w = cH2w + grid%difSrc(cP,1)*rayLen(istep)
              end do
              colWalk = cH2w
              avWalk  = dble(magPerTau)*tauV
           end if
        end if

      end subroutine traceDiffuseSites


      !-----------------------------------------------------------------
      ! D-350: the share of the Draine (1978) field's 6-13.6 eV energy that
      ! lies in the Lyman-Werner window, on MOCASSIN's own FUV bins - the
      ! spectral shape the rate coefficients were measured in. The same
      ! formula integrated over the band gives uDraine (8.938e-14 against the
      ! constant's 8.94e-14), so this is the unit's own definition carried to
      ! the window, not a new number. Computed once; D-349 found 0.1516 for
      ! the continuous band.
      !-----------------------------------------------------------------
      double precision function draineWindowShare()
        implicit none
        double precision, parameter :: eVperRyd = 13.605693d0
        double precision, save      :: share = -1.d0
        double precision            :: e, de, u, uT, uW
        integer                     :: j

        if (share < 0.d0) then
           uT = 0.d0; uW = 0.d0
           do j = FUVlowP, FUVhighP
              e  = dble(nuArray(j))*eVperRyd
              de = dble(widFlx(j))*eVperRyd
              ! Draine (1978): photons cm^-2 s^-1 sr^-1 eV^-1, times E for energy
              u  = e*(1.658d6*e - 2.152d5*e**2 + 6.919d3*e**3)*de
              uT = uT + u
              if (nuArray(j) >= nuLWlo .and. nuArray(j) < nuFUVhi) uW = uW + u
           end do
           if (uT <= 0.d0 .or. uW <= 0.d0) then
              print*, "! draineWindowShare: no FUV bins in the band or the window"
              stop
           end if
           share = uW/uT
           if (taskid == 0) print '(a,f8.5)', &
                & " ! [D350] Draine field's Lyman-Werner share on the FUV bins:", share
        end if
        draineWindowShare = share
      end function draineWindowShare


      !-----------------------------------------------------------------
      ! D-377: the line-escape rays of cell (xP,yP,zP). The same twelve HEALPix
      ! nside=1 directions, fixed in the grid frame, and the same rays as
      ! traceDiffuseSites: the lower faces of a symmetricXYZ octant are
      ! mirrors, a ray ends at the upper faces (inactive cells beyond Rout,
      ! or in an inner cavity, add nothing and the ray runs on through
      ! them). Each ray is a list of (cell, path length), the exact length of
      ! the ray in that cell (D-397, rayCells). The first entry is the cell
      ! itself, with the half of it the ray crosses.
      !-----------------------------------------------------------------
      subroutine traceLineRays(grid, xP, yP, zP)
        implicit none
        type(grid_type), intent(in) :: grid
        integer, intent(in)         :: xP, yP, zP

        integer          :: kray, istep, nstep, n, nSeg
        double precision, save :: vx(0:11), vy(0:11), vz(0:11)
        logical, save    :: lgDirs = .false.
        double precision :: zz, ph, sr
        double precision :: x0, y0, z0

        if (.not.lgDirs) then
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
           lgDirs = .true.
        end if

        lrN = 0
        nstep = 2*(grid%nx + grid%ny + grid%nz) + 8

        if (allocated(lrCell)) then
           if (size(lrCell,2) < nstep) deallocate(lrCell, lrLen)
        end if
        if (.not.allocated(lrCell)) allocate(lrCell(0:11,nstep), lrLen(0:11,nstep))

        x0 = dble(grid%xAxis(xP)); y0 = dble(grid%yAxis(yP)); z0 = dble(grid%zAxis(zP))

        do kray = 0, 11
           call rayCells(grid, x0, y0, z0, vx(kray), vy(kray), vz(kray), &
                & huge(1.d0), lgSymmetricXYZ, nSeg)
           n = 0
           do istep = 1, nSeg
              if (rayCell(istep) <= 0) cycle
              n = n + 1
              lrCell(kray,n) = rayCell(istep)
              lrLen(kray,n)  = rayLen(istep)
           end do
           lrN(kray) = n
        end do

      end subroutine traceLineRays
#endif

      !-----------------------------------------------------------------
      ! D-377: the MOCASSIN frequency bin of every radiative transition of
      ! every coolant, by the rule MOCASSIN places its own line packets with
      ! (nuArray(ib) <= nu < nuArray(ib+1)); 0 for a line outside the grid.
      !-----------------------------------------------------------------
      subroutine buildTrBins()
        implicit none
        integer          :: ik, il, jl, ib, nl
        double precision :: nuR

        allocate(pdrTrBin(pdrMaxLev, pdrMaxLev, max(pdrNcool,1)))
        pdrTrBin = 0
        do ik = 1, pdrNcool
           nl = pdrCoolant2(ik)%cnlev
           do il = 2, nl
              do jl = 1, il-1
                 if (pdrCoolant2(ik)%A_COEFFS(il,jl) <= 0.d0) cycle
                 nuR = pdrCoolant2(ik)%frequencies(il,jl)/dble(fr1Ryd)
                 if (nuR <= dble(nuArray(1)) .or. nuR >= dble(nuArray(nbins))) cycle
                 do ib = 1, nbins-1
                    if (dble(nuArray(ib)) <= nuR .and. nuR < dble(nuArray(ib+1))) then
                       pdrTrBin(il, jl, ik) = ib
                       exit
                    end if
                 end do
              end do
           end do
        end do
      end subroutine buildTrBins


      subroutine computeAVdust(grid)
        implicit none

        type(grid_type), dimension(:), intent(inout) :: grid

        integer          :: iG, i, j, k, cellP, yTop, jStart
        double precision :: tau, dy, kap, cH2, cC, cCO
        integer          :: iS, istep, nstep, ix, iy, iz
        double precision :: sx, sy, sz, dxs, dys, dzs, seg, ds, tauS, fS, fSum, fTot

#ifdef RAYTHEIA
        ! D-348: the diffuse-site walk reads this snapshot, taken from the
        ! same abundances the source-ward columns below are integrated from,
        ! so the two legs of every two-leg column agree.
        call snapDiffuseSources(grid)
#endif

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
        double precision :: uFUV, chi, chi0, rr, dx, dy, dz, tauFUV
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

                    ! D-352: no zone flag. D-007's x(H+) < pdrZoneLim latch
                    ! decided where the PDR's own thermal balance ran; since
                    ! D-193 there is none (MOCASSIN owns T in every cell) and
                    ! since D-198 the chemistry runs everywhere, so the flag
                    ! decided nothing a model quantity does not already say.

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


        ! D-342 removed the computeRayColumns call that stood here; D-348
        ! removed the routine. Its successor, traceDiffuseSites, is called
        ! per cell from pdrStep, on the rank that consumes it.

      end subroutine mocassinToPDR




      !-----------------------------------------------------------------
      ! D-215. The tabulation grid, and lookup on it.
      !
      ! D-166 gave thermBalance a two-point power law C(T) = C(Tref)*
      ! (T/Tref)^p because the alternative - Cloudy's re-evaluation of the
      ! whole cooling function at every trial temperature - looked like 30
      ! level-population solves per cell per coupling pass. D-213 measured
      ! what the power law does when the solver leaves the neighbourhood of
      ! Tref: an effective multiplier of x229 at iteration 6 pass 1, x420 in
      ! the one-pass configuration, against a validation that covered x2.56
      ! and a median error of 6.3%. The inflated cooling manufactured a cold
      ! state that was not physical, and each re-anchoring of Tref removed
      ! part of the prop and let the temperature march.
      !
      ! There is a third option between two points and thirty. Inside
      ! iterateT the abundances, the partner densities and the dust
      ! temperature are all frozen; only T moves. The coolant is therefore a
      ! function of a single variable, and a function of one variable can be
      ! tabulated once and interpolated. 16 points log-spaced over
      ! [pdrTmin, pdrTmax] put successive entries a factor 1.94 apart, so the
      ! root finder interpolates over a factor of two at worst and
      ! extrapolates never.
      !
      ! Outside the table the value is CLAMPED to the end entry rather than
      ! extrapolated. That is a deliberate choice and not a silent one: the
      ! chemistry itself refuses to evaluate outside [pdrTmin, pdrTmax]
      ! (pdr_mod clamps Tg there to keep the fitted rate data in range), so
      ! above 2e4 K there is no solve to tabulate and any value would be
      ! invention. MOCASSIN's own iterateT ceiling is 30000 K, so the clamp
      ! does get used; it is counted and reported rather than hidden.
      !-----------------------------------------------------------------
      subroutine initPDRcoolTab()
        implicit none
        integer :: i

        if (pdrNtab < 2) pdrNtab = 2
        if (pdrNtab > size(pdrTabT)) pdrNtab = size(pdrTabT)
        do i = 1, pdrNtab
           pdrTabT(i) = pdrTmin &
                & *(pdrTmax/pdrTmin)**(real(i-1)/real(pdrNtab-1))
        end do
        if (taskid == 0) then
           print '(a,i3,a,f8.2,a,f10.1,a,f6.3)', &
                & " ! initPDRcoolTab: cooling tabulated at", pdrNtab, &
                & " points from", pdrTabT(1), " K to", pdrTabT(pdrNtab), &
                & " K, ratio", pdrTabT(2)/pdrTabT(1)
           print*, "! initPDRcoolTab: D-166's power law is retired (D-215) - &
                &the balance interpolates this table and never extrapolates"
        end if

      end subroutine initPDRcoolTab





      !-----------------------------------------------------------------
      ! D-220. Make the ionization the opacity is built from describe the
      ! same hydrogen as the molecules beside it.
      !
      ! D-219 measured x(H0)+2x(H2)+x(H+) at a median of 0.43-1.85 in the
      ! state ionizationDriver reads at the top of each MC iteration: the ion
      ! stages carry a molecular fraction from BEFORE the chemistry moved it,
      ! the molecules carry the fraction after. D-218 confirmed the opacity
      ! follows that stale state (tau 1260 = x(H0) 1.0 at iteration 5; 460
      ! predicted, 466 measured at iteration 6).
      !
      ! The fix is D-153's rule applied on MOCASSIN's side. D-153 hands the
      ! chemistry MOCASSIN's RATIO between stages and lets the chemistry keep
      ! the non-molecular TOTAL. Here the same split runs the other way: keep
      ! MOCASSIN's ratio between stages, and rescale their sum to the
      ! chemistry's current available fraction. That is exactly what
      ! ionBalance's conservation row asserts - every enabled element, stages
      ! 1..min(elem+1, nstages), summing to min(max(elemAvail,1e-10),1) - so
      ! this reproduces the normalisation the next updateCell would apply,
      ! one step earlier, where the opacity needs it. Elements pdrToMocassin
      ! never sets carry elemAvail = 1 and are left unchanged.
      !
      ! Called after the D-200 damping and elemAvail republish, when ionDen is
      ! already reduced and every rank holds the same elemAvail, so every rank
      ! rescales identically and no collective is needed.
      !-----------------------------------------------------------------
      subroutine rescaleIonToAvail(grid)
        implicit none
        type(grid_type), dimension(:), intent(inout) :: grid

        integer          :: iG, cP, elem, nSt, nH, nOff
        double precision :: tot, tgt, offSum

        nH = 0; nOff = 0; offSum = 0.d0
        do iG = 1, nGrids
           if (.not.allocated(grid(iG)%elemAvail)) cycle
           do cP = 1, grid(iG)%nCells
              if (grid(iG)%Hden(cP) <= 0.) cycle
              do elem = 1, nElements
                 if (.not.lgElementOn(elem)) cycle
                 if (elementXref(elem) <= 0) cycle
                 nSt = min(elem+1, nstages)
                 tot = sum(dble(grid(iG)%ionDen(cP, elementXref(elem), 1:nSt)))
                 if (tot <= 0.d0) cycle
                 tgt = min(max(dble(grid(iG)%elemAvail(cP, elem)), 1.d-10), 1.d0)
                 if (elem == 1) then
                    ! hydrogen's full budget BEFORE the rescale, with the
                    ! molecules, so the defect is measured as it is removed
                    nH = nH + 1
                    if (pdrIdxH2 > 0 .and. allocated(grid(iG)%pdrAbun)) then
                       offSum = offSum + abs(tot + 2.d0*grid(iG)%pdrAbun(cP,pdrIdxH2) - 1.d0)
                       if (abs(tot + 2.d0*grid(iG)%pdrAbun(cP,pdrIdxH2) - 1.d0) > 0.01d0) &
                            & nOff = nOff + 1
                    end if
                 end if
                 grid(iG)%ionDen(cP, elementXref(elem), 1:nSt) = &
                      & real(dble(grid(iG)%ionDen(cP, elementXref(elem), 1:nSt))*tgt/tot)
              end do
           end do
        end do
        if (taskid == 0 .and. nH > 0) print '(a,i8,a,f8.4,a,i8,a,f6.2,a)', &
             & " ! [D220] rescaled ion stages to elemAvail in", nH, &
             & " cells; before: mean |x(H0)+x(H+)+2x(H2)-1| ", offSum/dble(nH), &
             & ", off by >1% in", nOff, " (", 100.d0*dble(nOff)/dble(nH), "%)"

      end subroutine rescaleIonToAvail

      !-----------------------------------------------------------------
      ! D-209. The starting H2 and CO fractions, from MOCASSIN's own
      ! photoionization solution.
      !
      ! D-208 set every molecule to zero at startup, which is right there -
      ! at startup MOCASSIN knows nothing yet. By pdrStartIter it knows a
      ! great deal: a converged ionization structure, an electron temperature,
      ! a dust temperature, a dust opacity, and from those an FUV field and an
      ! A_V. That is enough to place the H/H2 balance before the chemistry
      ! ever runs, and it has to be done HERE because the shielding columns
      ! are integrated over pdrAbun before the coupling loop opens (D-208).
      !
      ! H2: formation on grains against photodissociation, at equilibrium.
      !
      !     R n(H) n_H = D n(H2),     n(H) + 2 n(H2) = N
      !
      ! with N the neutral hydrogen MOCASSIN reports, giving in closed form
      !
      !     n(H2) = R N n_H / (D + 2 R n_H)
      !
      ! which conserves hydrogen exactly, is bounded by N/2, tends to N/2
      ! where the field is extinguished (D -> 0) and to zero in the ionized
      ! gas, where N is itself near zero. No iteration and no free parameter.
      !
      ! Every input is the model's own. R is H2_FORMATION_RATE, the Cazaux &
      ! Tielens rate as a function of THIS cell's gas and dust temperature,
      ! with the grain cross sections reseeded from MOCASSIN's measured
      ! geometric area per H nucleus (D-195) rather than the diffuse-ISM
      ! constants h2_form.F90 ships with. D is the network's own
      ! photodissociation coefficient for H2 - looked up in the rate table,
      ! not written here - times MOCASSIN's chi_FUV, attenuated by the
      ! network's own SCATTER at MOCASSIN's A_V.
      !
      ! D is taken UNSHIELDED: H2 self-shielding needs an H2 column, and the
      ! H2 column is what this seed exists to supply. Using zero there is the
      ! one choice that cannot inject shielding the model has not earned, and
      ! it errs low - the chemistry then self-shields upward from a floor
      ! rather than relaxing down from a fiction, which is exactly the failure
      ! D-208 removed.
      !
      ! CO is weaker and is labelled as such. It has no two-body formation
      ! rate to balance - every path to CO in the reduced network is a chain
      ! through H2 - so there is no equilibrium to solve without inventing a
      ! coefficient, which the project forbids. The seed instead gives CO the
      ! same share of the neutral carbon that H2 took of the neutral hydrogen,
      ! capped by the available oxygen and conserving both. It is an ansatz,
      ! not a solution: zero where there is no H2, all the neutral carbon
      ! where the gas is fully molecular, and monotonic between. The chemistry
      ! replaces it on the first call.
      !-----------------------------------------------------------------
      subroutine seedMolecules(grid)
        use functions_module, only : H2_FORMATION_RATE, SCATTER
        implicit none

        type(grid_type), dimension(:), intent(inout) :: grid

        integer          :: iG, cP, iR, i, j, k, iAb, yTop
        integer, save    :: iRxH2 = -1
        double precision, save :: alphaH2 = 0.d0
        double precision :: Rform, Dh2, nH, xHn, xH2, fH2, xCO
        integer          :: nSeed, nMol
        double precision :: molSum, hSum, chiSum, avSum, rSum, dSum
        double precision :: abunL(pdrNspec)

        ! The photodissociation coefficient comes from the network's rate
        ! table, once. Writing 5.18e-11 here would be the same defect D-208
        ! removed, one file further along.
        if (iRxH2 < 0) then
           iRxH2 = 0
           do iR = 1, pdrNreacMod
              if (trim(adjustl(pdrReactant(iR,1))) == "H2" .and. &
                & trim(adjustl(pdrReactant(iR,2))) == "PHOTON" .and. &
                & trim(adjustl(pdrProduct(iR,1)))  == "H" .and. &
                & trim(adjustl(pdrProduct(iR,2)))  == "H") then
                 iRxH2   = iR
                 alphaH2 = pdrAlpha(iR)
                 exit
              end if
           end do
           if (taskid == 0) then
              if (iRxH2 > 0) then
                 print*, "! seedMolecules: H2 photodissociation is reaction", &
                      & iRxH2, " alpha =", alphaH2, " s^-1 (unattenuated)"
              else
                 print*, "! seedMolecules: [warning] no H2 photodissociation &
                      &reaction found in the network - molecules seeded at zero"
              end if
           end if
        end if
        if (iRxH2 <= 0 .or. alphaH2 <= 0.d0) return

        nSeed = 0; nMol = 0; molSum = 0.d0
        hSum = 0.d0; chiSum = 0.d0; avSum = 0.d0; rSum = 0.d0; dSum = 0.d0
        ! Looped over i,j,k rather than the cell pointer because the
        ! abundance-file index is held per (i,j,k), exactly as seedPDR does it.
        do iG = 1, nGrids
           if (.not.allocated(grid(iG)%pdrAbun)) cycle
           if (iG > 1 .or. (.not.lg2D)) then
              yTop = grid(iG)%ny
           else
              yTop = 1
           end if
           do i = 1, grid(iG)%nx
            do j = 1, yTop
             do k = 1, grid(iG)%nz
              cP = grid(iG)%active(i,j,k)
              if (cP <= 0) cycle
              iAb = grid(iG)%abFileIndex(i,j,k)
              nH = dble(grid(iG)%Hden(cP))
              if (nH <= 0.d0) cycle
              nSeed = nSeed + 1

              ! THIS cell's grains, the same handover pdrStep makes (D-195).
              ! A negative value means MOCASSIN measured no dust and h2_form
              ! falls back to its own constants, so a dust-free model is
              ! unchanged.
              if (allocated(grid(iG)%dustSigSil) .and. &
                & allocated(grid(iG)%dustSigGra)) then
                 if (grid(iG)%dustSigSil(cP) >= 0. .and. &
                   & grid(iG)%dustSigGra(cP) >= 0.) then
                    pdrH2xsecSil = dble(grid(iG)%dustSigSil(cP))
                    pdrH2xsecGra = dble(grid(iG)%dustSigGra(cP))
                 else
                    pdrH2xsecSil = -1.d0
                    pdrH2xsecGra = -1.d0
                 end if
              end if

              Rform = H2_FORMATION_RATE(dble(grid(iG)%Te(cP)), &
                   &                    dble(grid(iG)%Tdust(0,0,cP)))
              if (Rform <= 0.d0) cycle

              Dh2 = alphaH2*dble(grid(iG)%chiFUV(cP)) &
                  & *SCATTER(dble(grid(iG)%AVeff(cP)), 1.0d3)
              if (Dh2 < 0.d0) Dh2 = 0.d0

              ! Rebuild the carriers from the ionization MOCASSIN has NOW.
              !
              ! Reading pdrAbun here instead was wrong and measured so: seedPDR
              ! runs at startup, where fillGrid has set x(H0) = initH0 = 1e-5
              ! - the grid starts essentially fully ionized - so pdrAbun held
              ! 1e-5 of neutral hydrogen in every cell and the equilibrium
              ! below could not put more than 5e-6 into H2 anywhere. Reported
              ! mean f_mol 0.0000. The whole point of seeding at pdrStartIter
              ! rather than at startup is that x(H0), Te and Tdust are
              ! converged by then; reading a startup value at that point threw
              ! the reason away.
              call seedAbunFromMocassin(grid(iG), cP, iAb, abunL)
              grid(iG)%pdrAbun(cP, 1:pdrNspec) = abunL

              ! neutral hydrogen, as a fraction per H nucleus
              xHn = grid(iG)%pdrAbun(cP, pdrNHsp)
              hSum   = hSum   + xHn
              chiSum = chiSum + dble(grid(iG)%chiFUV(cP))
              avSum  = avSum  + dble(grid(iG)%AVeff(cP))
              rSum   = rSum   + Rform
              dSum   = dSum   + Dh2
              if (xHn <= 0.d0) cycle

              ! n(H2)/n_H = R N n_H /(D + 2 R n_H), with N/n_H = xHn
              xH2 = Rform*xHn*nH/(Dh2 + 2.d0*Rform*nH)
              xH2 = min(max(xH2, 0.d0), 0.5d0*xHn)

              grid(iG)%pdrAbun(cP, pdrIdxH2) = xH2
              grid(iG)%pdrAbun(cP, pdrNHsp)  = xHn - 2.d0*xH2
              if (allocated(grid(iG)%H2den)) &
                   & grid(iG)%H2den(cP) = real(xH2*nH)

              ! fH2 here is the fraction of the NEUTRAL hydrogen that is
              ! molecular - that is what the CO ansatz below needs. It is NOT
              ! what the D-202 census calls f_mol, which is 2x(H2) per H
              ! NUCLEUS, and in the ionized gas the two differ by everything:
              ! xHn is ~0 there, so the neutral-normalised ratio is 0/0 and
              ! reads 1 while the per-nucleus value is ~0. Reporting the
              ! neutral-normalised one is how the zero-field defect above
              ! looked like a plausible answer. The census definition is the
              ! one printed.
              fH2 = 2.d0*xH2/xHn
              molSum = molSum + 2.d0*xH2
              if (2.d0*xH2 > 0.5d0) nMol = nMol + 1

              ! CO: the ansatz above. Carbon and oxygen both conserved.
              if (pdrIdxC > 0 .and. pdrIdxCO > 0) then
                 xCO = grid(iG)%pdrAbun(cP, pdrIdxC)*fH2
                 xCO = min(xCO, grid(iG)%pdrAbun(cP, NO))
                 if (xCO > 0.d0) then
                    grid(iG)%pdrAbun(cP, pdrIdxCO) = xCO
                    grid(iG)%pdrAbun(cP, pdrIdxC)  = &
                         & grid(iG)%pdrAbun(cP, pdrIdxC) - xCO
                    grid(iG)%pdrAbun(cP, NO)       = &
                         & grid(iG)%pdrAbun(cP, NO) - xCO
                 end if
              end if

              ! the cell is now seeded; pdrStep must not overwrite this with
              ! its own molecules-at-zero version on the first visit
              if (allocated(grid(iG)%pdrSeeded)) grid(iG)%pdrSeeded(cP) = 1
             end do
            end do
           end do
        end do

        if (taskid == 0 .and. nSeed > 0) then
           print '(a,i8,a,f8.4,a,i8,a,f6.2,a)', &
                & " ! [D209] seeded", nSeed, " cells:  mean f_mol = 2x(H2) ", &
                & molSum/dble(nSeed), "    f_mol > 0.5 in", nMol, " (", &
                & 100.d0*dble(nMol)/dble(nSeed), "%)"
           ! D-209: the seed's INPUTS, so a wrong answer says which input was
           ! wrong instead of leaving it to be guessed. Two attempts at this
           ! routine failed on a stale or unset input - chiFUV read before
           ! mocassinToPDR wrote it, then x(H0) read from the startup grid -
           ! and neither was visible in the answer alone.
           print '(a,5(es11.4,a))', " ! [D209]   inputs: mean x(H0) ", &
                & hSum/dble(nSeed), "  chi ", chiSum/dble(nSeed), &
                & "  A_V ", avSum/dble(nSeed), "  R_form ", rSum/dble(nSeed), &
                & "  D_pd ", dSum/dble(nSeed)
        end if

      end subroutine seedMolecules


      !-----------------------------------------------------------------
      ! D-208. The ONE seeding rule, used by seedPDR at startup and by
      ! pdrStep on a cell's first visit.
      !
      ! Molecules start at zero and every elemental carrier comes from
      ! MOCASSIN: elemAbun for how much of the element there is, ionDen for
      ! how it is split between stages, Ne/Hden for the electrons. Nothing
      ! here is read from the network file.
      !
      ! This existed as an inline block in pdrStep (D-188) while seedPDR went
      ! on writing species_reduced.d's dark-cloud defaults - x(H) = 0.400,
      ! x(H2) = 0.300, sixty per cent of the hydrogen nuclei molecular,
      ! uniformly, H II region included. D-188 argued those defaults never
      ! reached a cell the chemistry solved, and that was true of the
      ! ABUNDANCES and false of what they feed: computeAVdust and
      ! computeRayColumns run at iteration_mod:864-865, inside the
      ! nIterateMC >= pdrStartIter block, and the coupling loop that calls
      ! pdrStep does not start until line 1029. So at the first PDR iteration
      ! the H2, C and CO shielding columns were integrated over a grid still
      ! holding x(H2) = 0.300 everywhere - about 6e19 cm^-2 of fictitious H2
      ! per cell at n_H = 100 with 2e18 cm cells, order 1e21 cm^-2 across the
      ! grid, which saturates H2 self-shielding outright. The first chemistry
      ! call therefore solved a fully self-shielded cloud, and D-112 measured
      ! that this choice does not wash out: 1.109 against 1.679 for the H2
      ! front ratio, still apart after a hundredfold longer integration.
      !
      ! syncSeed rescaled He, C, O and Mg to MOCASSIN's abundances and left
      ! hydrogen alone, so 0.400 and 0.300 were the vendored numbers exactly.
      !
      ! Two rules for one quantity is the failure this project keeps finding.
      ! There is now one.
      !-----------------------------------------------------------------
      !-----------------------------------------------------------------
      ! D-266: MOCASSIN's fraction of element iEl in all ionized stages.
      ! The reduced network carries one ion per element, so that species
      ! stands for every stage above neutral; this is the MOCASSIN quantity it
      ! corresponds to. Stages sum to elemAvail, not 1, so this is on the same
      ! footing as ionDen(.,1).
      !-----------------------------------------------------------------
      double precision function mocIonizedFrac(grid, cellP, iEl)
        implicit none
        type(grid_type), intent(in) :: grid
        integer, intent(in)         :: cellP, iEl
        integer :: ist

        mocIonizedFrac = 0.d0
        do ist = 2, min(iEl+1, nstages)
           mocIonizedFrac = mocIonizedFrac + &
                & dble(grid%ionDen(cellP, elementXref(iEl), ist))
        end do
      end function mocIonizedFrac


      subroutine seedAbunFromMocassin(grid, cellP, iAb, abun)
        implicit none

        type(grid_type), intent(in)   :: grid
        integer,         intent(in)   :: cellP, iAb
        double precision, intent(out) :: abun(:)

        integer :: iLnk, iEl
        double precision :: fracL                      ! D-266

        abun = 0.d0
        do iLnk = 1, pdrNlink
           if (pdrLinkSpec(iLnk) <= 0) cycle
           iEl = pdrLinkElem(iLnk)
           if (iEl < 1 .or. iEl > nElements) cycle
           if (.not.lgElementOn(iEl)) cycle
           ! elemAbun is relative to hydrogen; ionDen is the fraction of the
           ! element in that stage. Hydrogen's elemAbun is 1 by definition.
           ! D-266: the network's ion carrier (C+, O+, Mg+, He+) stands for
           ! EVERY ionized stage MOCASSIN has, not stage 2 alone. The reduced
           ! network has no doubly ionized species, so seeding C+ from stage 2
           ! left the C++ (and O++) share out of the chemistry's element total
           ! for good - setElemAvail then reported it as locked in molecules
           ! and ionBalance removed it: 80% of the carbon and 52% of the
           ! oxygen were missing from the H II gas (D-265).
           if (pdrLinkIon(iLnk) == 2) then
              fracL = mocIonizedFrac(grid, cellP, iEl)
           else
              fracL = dble(grid%ionDen(cellP, elementXref(iEl), pdrLinkIon(iLnk)))
           end if
           if (iEl == 1) then
              abun(pdrLinkSpec(iLnk)) = fracL
           else
              abun(pdrLinkSpec(iLnk)) = dble(grid%elemAbun(iAb, iEl))*fracL
           end if
        end do
        ! electrons: MOCASSIN's own, per hydrogen nucleus
        if (pdrNelect > 0 .and. grid%Hden(cellP) > 0.) &
             & abun(pdrNelect) = max(dble(grid%Ne(cellP))/dble(grid%Hden(cellP)), 0.d0)

      end subroutine seedAbunFromMocassin


      !-----------------------------------------------------------------
      ! One cell of PDR chemistry (DEVLOG D-027).
      !
      ! Solves the chemistry once and returns; the outer MC loop carries the
      ! convergence (D-008). Every input the solve reads is fixed within an MC
      ! iteration, so repeating it here would recompute the same answer (D-354).
      !
      ! The radiation field (D-350, 3D build): every photorate takes the MC's
      ! own local field at A_V = 0 - the direct part (Jste - Jdif) on one ray
      ! with the source-ward shielding columns, the diffuse part (Jdif) on
      ! D-348's scattering sites with their two-leg columns - and the H2, HD,
      ! CO and C I rates take each part's Lyman-Werner window share
      ! (ray_lw_factor). The 1D build still hands over D-001's prescription,
      ! chi0/12 on twelve rays at A_V,eff (D-350 audit item 5, open).
      !
      ! Temperatures: the chemistry, the level populations and the heating
      ! and cooling are all evaluated at MOCASSIN's Te (D-193); nothing here
      ! solves for a temperature, and no zone flag decides where it runs
      ! (D-198, D-352).
      !-----------------------------------------------------------------
      subroutine pdrStep(grid, xP, yP, zP)
        implicit none

        type(grid_type), intent(inout) :: grid
        integer, intent(in)            :: xP, yP, zP

        integer, parameter :: nraysLoc = 12          ! HEALPix level 0
        integer, parameter :: npart = 1
        ! D-348: the chemistry's rays are the twelve direct twelfths plus one
        ! per diffuse scattering site, so the count is only known per cell.
        ! nraysLoc stays 12 for the escape probabilities, which are unchanged.
        integer            :: nChem
        double precision, allocatable :: radSurf(:), AVray(:)
        double precision, allocatable :: colH2(:), colHD(:)
        double precision, allocatable :: colCO(:), colC(:)
        double precision, allocatable :: colS(:)
        integer            :: nSite, iSite, nUnsetL, iBinD, ifreqD, iDifFb   ! D-348
        double precision   :: chiDif, wTotD, anisoD, colWalkD, avWalkD      ! D-348
        double precision   :: rDirD, rDifSrcD, rDif2D, rOldD                ! D-348/D-350
        integer            :: nDir                                          ! D-350
        double precision   :: chiDir, fDir, fDif, sumT, sumD, lwT, lwD, jT, jD, fLWd  ! D-350
        double precision   :: abun(pdrNspec)
        double precision   :: abun0(pdrNspec), heat(12)
        integer            :: iqP, ispP                  ! D-354
        double precision   :: dqP                        ! D-354
        integer            :: ik, il, jl, nlev, ilev
        integer            :: iTnear                     ! D-215
        double precision   :: coolTot, coolK, nSpec, Zpart, lsum
        double precision   :: fIonL                      ! D-266
        double precision   :: lpop(pdrMaxLev), lsol(pdrMaxLev)
        double precision   :: Ccoef(pdrMaxLev,pdrMaxLev), trans(pdrMaxLev,pdrMaxLev)
        double precision   :: lline(pdrMaxLev,pdrMaxLev)
        double precision   :: evpop(0:nraysLoc-1,0:1,pdrMaxLev), plen(0:nraysLoc-1,0:1)
        ! D-377: the 3D flavour's ray points, sized per cell and coolant
        double precision, allocatable :: evpopR(:,:,:), plenR(:,:)
        integer            :: maxPt, ipt, ib
        double precision   :: jBg
        double precision   :: evpt(1:3,0:nraysLoc-1,0:1)
        integer            :: jjr(0:nraysLoc-1)
        integer            :: kray
        double precision   :: mu, colA, avBack
        double precision   :: nH, Tg, Td, chi, chiLoc, av, NHcol, sH2, sC, sCO
        double precision   :: AVfacL, RfuvL          ! this cell's own dust (D-109)
        integer            :: cellP, NRGR, NR2, NR3, NR4, NR5, NR6, it
        integer            :: iLnk, jLnk, iSpN, iSpI      ! D-153
        double precision   :: availTot, mocNeut, mocIon   ! D-153
        integer            :: iTpass                     ! D-166
        integer            :: iEl                        ! D-188
        integer            :: iRay                       ! D-190
        double precision   :: Tc, coolTot2, coolTot3     ! D-166
        integer            :: iBinD113                   ! D-258
        logical, save      :: lgAVd113(8) = .false.      ! D-258
        integer, save      :: iterD113 = -1            ! D-258b
        double precision   :: abunPre(pdrNspec)          ! D-258c
        integer            :: iLn362                     ! D-362
        double precision   :: cTab362, d362              ! D-362

        cellP = grid%active(xP,yP,zP)
        if (cellP <= 0) return
        ! D-131. The zone test used to return here, so the network was never
        ! called in ionized gas and H2/CO were zero there because nothing had
        ! computed them - not because the chemistry said so.
        !
        ! D-198: the chemistry now runs in EVERY cell, with no keyword. Two
        ! reasons, and the second is a defect the gate was causing.
        !
        ! The gate bought almost nothing: 14854 of 15204 active cells in the
        ! sec 5.4 fixture are already inside the zone, so it skipped 2.3% of
        ! the model. What it cost was those 2.3%. pdrToMocassin writes
        ! elemAvail for every cell from pdrAbun, and in a cell the chemistry
        ! never touched pdrAbun still holds seedPDR's network defaults -
        ! x(H) = 0.400, x(H2) = 0.300, the reduced network's dark-cloud
        ! starting point. So elemAvail(H) was 0.400 across the whole H II
        ! region, ionBalance normalised the hydrogen stages to 0.400, and the
        ! ionized gas ran at 4600-7200 K against the 7927-9420 K this fixture
        ! is benchmarked at. Measured at D-196; 60% of the hydrogen was simply
        ! missing.
        !
        ! Outside the molecular gas the chemistry answers "no molecules here"
        ! by itself and needs no threshold to be switched off. D-352 removed
        ! the last use of the zone flag here (lgChemOnly, which decided only
        ! whether the vestigial pdrTgas was written).

        nH  = dble(grid%Hden(cellP))
        if (nH <= 0.d0) return

        ! D-132/D-193: MOCASSIN owns the thermal balance in every cell, with
        ! no switch. The PDR evaluates its chemistry, level populations and
        ! heating/cooling AT this temperature and reports them back.
        Tg = dble(grid%Te(cellP))
        ! ---- the field and A_V this cell's chemistry is handed -----------
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
        ! THIS cell's grains. (No metallicity factor: D-352.)
        pdrAVfacMod = AVfacL

        ! D-195: same idea for the H2 formation rate. H2_FORMATION_RATE is
        ! linear in the grain cross section per H nucleus and upstream hardcodes
        ! it as a diffuse-ISM constant, so the H/H2 front ignored the model's
        ! own dust entirely. Hand it THIS cell's measured geometric grain area,
        ! split by material. A negative value means MOCASSIN measured nothing
        ! (a dust-free model) and h2_form keeps the upstream constants.
        if (grid%dustSigSil(cellP) >= 0. .and. grid%dustSigGra(cellP) >= 0.) then
           pdrH2xsecSil = dble(grid%dustSigSil(cellP))
           pdrH2xsecGra = dble(grid%dustSigGra(cellP))
        else
           pdrH2xsecSil = -1.d0
           pdrH2xsecGra = -1.d0
        end if
        ! (UV_fac, the exponent of 3D-PDR's exp(-UV_fac*A_V) prescription, is
        ! read only under GRAINRECOMB, which is not built. D-352 retired the
        ! keyword; calibratePDRdust sets it from this model's own R_FUV.)

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

        ! ---- dust temperature (D-033, D-036, D-094, D-352) ---------------
        ! MOCASSIN's own radiative-equilibrium T_dust - the temperature its dust
        ! emission uses - is the only one. D-352 removed the alternatives the
        ! pdrDustModel keyword offered (HTT91's parametric estimate, alone or
        ! as a max() floor; D-094 had already shown max() imposed HTT91's
        ! artificial 10 K floor) and pdrFUVmode's prescribed heating field.
        ! The CMB bound stays: MOCASSIN transports no CMB, and T_CMB is what a
        ! grain is held at with no other heating. Where it binds, MOCASSIN's
        ! own dust emission sees a colder grain than the chemistry does - an
        ! open item (the fix is the CMB in MOCASSIN's field), not a choice.
        Td = max(dble(grid%Tdust(0,0,cellP)), dble(pdrTcmb))
        ! D-050: 3D-PDR re-applies the attenuation itself, through
        ! alpha*rad_surface*exp(-gamma*A_V) inside CALCULATE_REACTION_RATES.
        ! The field handed over must therefore be the UNATTENUATED one; passing
        ! the local MC field (grid%chiFUV) attenuates it twice and drives every
        ! photodissociation front to too small an A_V.

        ! keep the chemistry inside the temperature range it was fitted over
        Tg = min(max(Tg, dble(pdrTmin)), dble(pdrTmax))

        ! ---------------------------------------------------------- D-350
        ! THE PHOTORATES SEE MOCASSIN'S OWN FIELD (D-350: D-348's angular
        ! model, with its direct ray taken off the prescription).
        !
        ! D-348 kept the direct ray on 3D-PDR's prescription - chi0 attenuated
        ! by exp(-gamma*A_V) and SCATTER, i.e. the Savage & Mathis curve, FRR80
        ! slab scattering with albedo 0.3 and g 0.8, and an assumed Draine
        ! spectral shape - where MOCASSIN transports that field itself on its
        ! own grains. That is the constant-standing-in-for-the-model the
        ! project rules call a bug, and D-349 measured it: MOCASSIN's
        ! Lyman-Werner field runs 2.0-2.8x the prescription's at every depth.
        !
        ! Now every photorate is driven by the MC's local field, split only so
        ! that each part is shielded by the column its photons crossed:
        !
        !   direct   Jste - Jdif   one ray      the source-ward columns
        !   diffuse  Jdif          the sites    their two-leg columns (D-348)
        !
        ! A_V = 0 on every ray: MOCASSIN's transfer has already applied the
        ! dust, and exp(-gamma*A_V) again would count it twice (D-343). The C I
        ! continuum term goes for the same reason (colC = 0 below): MOCASSIN's
        ! opacity carries C I photoionization absorption (tauNu.out, tau
        ! 12.8 -> 18.5 across 1100 A). What the chemistry adds is what the MC
        ! does not transport - H2 and CO line shielding and the H2-line term of
        ! the C I rate.
        !
        ! And the band. H2, HD and CO dissociation and C I ionization see only
        ! 11.2-13.6 eV, while radSurf is the 6-13.6 eV integral the other
        ! photoreactions take, and the rate coefficients assume a Draine-shaped
        ! field. Each part's measured window share over the Draine field's
        ! goes to the vendored routine as ray_lw_factor (D-349: this cloud's
        ! share runs 0.299 -> 0.008 against Draine's 0.152).
        !
        ! The 1D flavour keeps the prescription and 12 direct twelfths: it has
        ! no site walk, and changing it was not part of D-350 (L-24).
        nSite  = 0
        iDifFb = 0
        chiDif = 0.d0
        chiDir = 0.d0
        fDir   = 1.d0
        fDif   = 1.d0
        wTotD  = 0.d0
#ifdef RAYTHEIA
        nDir = 1
        if (.not.allocated(grid%difSrc)) then
           ! computeAVdust takes the snapshot before any pdrStep can run; an
           ! absent one is a sequencing bug, and D-341 is what a silently
           ! absent array costs
           print*, "! pdrStep: difSrc not allocated - snapDiffuseSources has not run"
           stop
        end if
        call traceDiffuseSites(grid, xP, yP, zP, cellP, nSite, wTotD, &
             & anisoD, colWalkD, avWalkD, nUnsetL)
        sumT = 0.d0; sumD = 0.d0; lwT = 0.d0; lwD = 0.d0
        do ifreqD = FUVlowP, FUVhighP
           jT = dble(grid%Jste(cellP,ifreqD))
           ! under lgDebug the diffuse packets are in Jdif ALONE
           if (lgDebug) jT = jT + dble(grid%Jdif(cellP,ifreqD))
           jD = dble(grid%Jdif(cellP,ifreqD))
           sumT = sumT + jT
           sumD = sumD + jD
           if (nuArray(ifreqD) >= nuLWlo .and. nuArray(ifreqD) < nuFUVhi) then
              lwT = lwT + jT
              lwD = lwD + jD
           end if
        end do
        ! Jdif is a subset of Jste deposit by deposit; max() only absorbs the
        ! rounding of two single-precision sums taken in different orders
        chiDir = max(sumT - sumD, 0.d0)/(dble(c)*dble(uDraine))
        chiDif = sumD/(dble(c)*dble(uDraine))
        fLWd   = draineWindowShare()
        if (sumT - sumD > 0.d0) fDir = max(lwT - lwD, 0.d0)/(sumT - sumD)/fLWd
        if (sumD > 0.d0)        fDif = lwD/sumD/fLWd
        ! A diffuse field with no scattering site to place it on (no dust on
        ! any of the twelve directions) cannot be a scattered field; carry it
        ! on the source-ward column (D-344's slab-equivalent) so none of the
        ! measured field is dropped, and count the cell so it is seen.
        if (chiDif > 0.d0 .and. wTotD <= 0.d0) then
           nSite  = 0
           iDifFb = 1
        end if
#else
        nDir = nraysLoc
#endif
        nChem = nDir + nSite + iDifFb
        allocate(radSurf(0:nChem-1), AVray(0:nChem-1), colH2(0:nChem-1), &
             & colHD(0:nChem-1), colCO(0:nChem-1), colC(0:nChem-1), &
             & colS(0:nChem-1))

#ifdef RAYTHEIA
        radSurf(0) = chiDir
        AVray      = 0.d0
        do iSite = 1, nSite
           radSurf(nDir+iSite-1) = chiDif*siteW(iSite)/wTotD
        end do
        if (iDifFb == 1) radSurf(nChem-1) = chiDif
        ! the window factor per ray: the direct part's on ray 0, the diffuse
        ! part's on every site and the fallback
        if (allocated(pdrRayLW)) then
           if (ubound(pdrRayLW,1) < nChem-1) deallocate(pdrRayLW)
        end if
        if (.not.allocated(pdrRayLW)) allocate(pdrRayLW(0:max(nChem-1, 1023)))
        pdrRayLW(0) = fDir
        if (nChem > 1) pdrRayLW(1:nChem-1) = fDif
#else
        radSurf = chi/dble(nraysLoc)
        AVray   = av
#endif

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
        ! D-208: one rule, shared with seedPDR. Was an inline block here.
        if (grid%pdrSeeded(cellP) == 0) then
           call seedAbunFromMocassin(grid, cellP, &
                & grid%abFileIndex(xP,yP,zP), abun)
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
        ! D-193: unconditional. MOCASSIN's ionization is an input to the
        ! chemistry, never an output of it.
        if (.true.) then
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
              ! D-266: all ionized stages, which the ion carrier stands for
              mocIon  = mocIonizedFrac(grid, cellP, pdrLinkElem(iLnk))
              if (mocNeut + mocIon <= 0.d0) cycle
              abun(iSpN) = availTot*mocNeut/(mocNeut+mocIon)
              abun(iSpI) = availTot*mocIon /(mocNeut+mocIon)
           end do

           ! ----------------------------------------------------- D-212
           ! The electron density, on the same footing and for the same
           ! reason. It is in the contract - MOCASSIN hands the chemistry ion
           ! densities, Ne, Te, T_dust and the dust opacity - and it was the
           ! one item of that list handed over exactly once.
           !
           ! Electrons are not an element, so they have no entry in the link
           ! table and the loop above never reached them. abun(NELECT) was
           ! written from grid%Ne only on a cell's first visit, in
           ! seedAbunFromMocassin, and thereafter evolved under CVODE from the
           ! 33-species reduced network's own electron balance.
           !
           ! That matters because of where abun(NELECT) is consumed. The
           ! level-population solve that produces the substituted cooling is
           ! called with five collision-partner densities:
           !
           !     H, H+, e-, He, H2
           !
           ! Four of those are re-imposed from MOCASSIN by the loop above,
           ! every call. The fifth - the one that dominates the excitation of
           ! [C II] and [O I] once the gas is warm and ionized - was the
           ! chemistry's own, drifting. So MOCASSIN's coolant was removed and
           ! replaced by one computed with a different electron density from
           ! the one MOCASSIN's ionization solver had just produced.
           !
           ! Measured at D-210/D-211, iteration 6, per coupling pass, per H:
           !
           !     pass  Te      f_mol   removed     added
           !       1     536   0.808   3.63e-25   2.524e-23
           !       2    4120   0.700   2.08e-24   7.141e-25
           !       3    8073   0.220   1.399e-23  8.537e-25
           !       4    8263   0.129   1.810e-23  2.270e-24
           !
           ! The added term falls by a factor 35 between passes 1 and 2 for a
           ! 13% change in f_mol, while the removed term grows with Te. Two
           ! electron densities is the only quantity in that budget that can
           ! move like this at nearly fixed molecular content.
           !
           ! One reality per quantity: there is one electron density and
           ! MOCASSIN owns it.
           if (pdrNelect > 0 .and. grid%Hden(cellP) > 0.) &
                & abun(pdrNelect) = &
                & max(dble(grid%Ne(cellP))/dble(grid%Hden(cellP)), 0.d0)
           ! D-230: what the imposition actually wrote, at the moment it wrote it
           if (teProbe /= 0 .and. taskid == 0 .and. nProbe230 < 24) then
              nProbe230 = nProbe230 + 1
              print '(a,i7,a,i3,a,es11.4,a,es11.4,a,es11.4,a,f8.2)', &
                   & " ! [D230] cell", cellP, "  NELECT idx", pdrNelect, &
                   & "   Ne/Hden", dble(grid%Ne(cellP))/max(dble(grid%Hden(cellP)),1.d-99), &
                   & "   e- imposed", abun(max(pdrNelect,1)), &
                   & "   Ne", dble(grid%Ne(cellP)), "   Te", grid%Te(cellP)
           end if
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
        ! The direct ray's column: sH2/sCO/sC, traced by computeAVradial from
        ! the source to the cell - the right shielding column for the stellar
        ! beam, and the only direction the direct field arrives from.
        colH2 = sH2
        colCO = sCO
        colC  = sC
        colHD = 0.d0
        ! D-348: each diffuse site on its own two-leg column,
        ! N(star -> site) + N(site -> cell). The fallback slot, if any, keeps
        ! the source-ward column assigned just above.
        do iSite = 1, nSite
           colH2(nDir+iSite-1) = siteN(1,iSite)
           colC (nDir+iSite-1) = siteN(2,iSite)
           colCO(nDir+iSite-1) = siteN(3,iSite)
        end do
#ifdef RAYTHEIA
        ! D-350: MOCASSIN transports the C I continuum absorption, so the
        ! chemistry's 1.1e-17*N(C) term would count it a second time
        colC = 0.d0
#endif
        ! D-342 removed the per-ray override that stood here: it gave each of
        ! twelve chi/12 rays its own cell -> boundary column, and the rays
        ! pointing OUT of the cloud then delivered their share unshielded,
        ! inventing FUV from outside a nebula with no outside source. The
        ! arithmetic of that argument stands. Its measurement (runs/d341-percol:
        ! x(H2) x 0.002, no molecular zone) does NOT: D-348 found the columns
        ! were computed on the wrong rank for 93% of the cells, which read
        ! zeros on all twelve rays - no shielding at all - so the run measured
        ! mostly that, not the outward columns.
        colS  = 0.d0

#ifdef RAYTHEIA
        ! D-350 diagnostics, per A_V bin (D-348's, re-cut for the new handoff):
        ! the field the MC measured and its window fields, the old
        ! prescription's H2 field for comparison, and four H2 photorates per
        ! unit alpha from the same vendored H2PDRATE the chemistry calls - the
        ! old handoff on these columns, the new direct ray, and the diffuse
        ! part on the source-ward column and on the sites' two-leg columns.
        iBinD = nDifBin
        do ik = 1, nDifBin
           if (av < difBinEdge(ik)) then
              iBinD = ik
              exit
           end if
        end do
        rOldD    = pdrH2PDRATE(1.d0, chi, av, sH2)
        rDirD    = pdrH2PDRATE(1.d0, chiDir*fDir, 0.d0, sH2)
        rDifSrcD = pdrH2PDRATE(1.d0, chiDif*fDif, 0.d0, sH2)
        rDif2D   = 0.d0
        do iSite = 1, nSite
           rDif2D = rDif2D + pdrH2PDRATE(1.d0, radSurf(nDir+iSite-1)*fDif, &
                & 0.d0, siteN(1,iSite))
        end do
        if (iDifFb == 1) rDif2D = rDifSrcD
        difDiag( 1,iBinD) = difDiag( 1,iBinD) + 1.d0
        difDiag( 2,iBinD) = difDiag( 2,iBinD) + dble(grid%chiFUV(cellP))
        difDiag( 3,iBinD) = difDiag( 3,iBinD) + chiDif
        difDiag( 4,iBinD) = difDiag( 4,iBinD) + wTotD/12.d0/(dble(c)*dble(uDraine))
        difDiag( 5,iBinD) = difDiag( 5,iBinD) + chiDir
        difDiag( 6,iBinD) = difDiag( 6,iBinD) + chiDir*fDir
        difDiag( 7,iBinD) = difDiag( 7,iBinD) + chiDif*fDif
        difDiag( 8,iBinD) = difDiag( 8,iBinD) + chi*pdrSCATTER(av, 1000.d0)
        difDiag( 9,iBinD) = difDiag( 9,iBinD) + rOldD
        difDiag(10,iBinD) = difDiag(10,iBinD) + rDirD
        difDiag(11,iBinD) = difDiag(11,iBinD) + rDifSrcD
        difDiag(12,iBinD) = difDiag(12,iBinD) + rDif2D
        if (colWalkD >= 0.d0) then
           difDiag(13,iBinD) = difDiag(13,iBinD) + colWalkD
           difDiag(14,iBinD) = difDiag(14,iBinD) + sH2
           difDiag(15,iBinD) = difDiag(15,iBinD) + avWalkD
           difDiag(16,iBinD) = difDiag(16,iBinD) + av
        end if
        difDiag(17,iBinD) = difDiag(17,iBinD) + anisoD
        difDiag(18,iBinD) = difDiag(18,iBinD) + dble(nSite)
        difDiag(19,iBinD) = difDiag(19,iBinD) + dble(iDifFb)
        difDiag(20,iBinD) = difDiag(20,iBinD) + dble(nUnsetL)
#endif

        abun0 = abun


        abunPre = abun                                 ! D-258c
        pdrOmega = dble(grainAlbedoLW(grid, cellP))    ! D-280
        call CALCULATE_REACTION_RATES(Tg, Td, nChem, radSurf, AVray, &
             & colH2, colHD, colCO, colC, colS, &
             & pdrNreacMod, pdrReactant, pdrProduct, pdrAlpha, pdrBeta, &
             & pdrGamma, pdrRate, pdrRtmin, pdrRtmax, pdrDuplicate, &
             & pdrNspecMod, NRGR, NR2, NR3, NR4, NR5, NR6, &
             & abun(pdrNelect)*nH, nH, pdrZetaMod)

        ! D-358: the solve ionizes and recombines the linked atoms at
        ! MOCASSIN's own rates for this cell, not the network's. Until now it
        ! had recombination but no photoionization for H, He and O, so inside
        ! an H II region it integrated to NEUTRAL gas (D-356: x(H) = 1,
        ! x(H+) = 1e-3, x_e = 1e-3 of MOCASSIN's), formed the molecules there,
        ! and MOCASSIN re-imposed only the atoms afterwards - two x(H+) in one
        ! cell. The re-imposition below stays; it should now change little.
        if (allocated(grid%pdrPhotRate)) then
           if (grid%pdrPhotRate(cellP,1) < 0.) then
              nUnset358 = nUnset358 + 1
           else
              do iqP = 1, 5
                 if (iCr358(iqP) <= 0) cycle
                 pdrRate(iCr358(iqP)) = pdrRate(iCr358(iqP)) &
                      & + dble(max(grid%pdrPhotRate(cellP,iqP), 0.))
                 if (iPh358(iqP) > 0) pdrRate(iPh358(iqP)) = 0.d0
                 if (nRec358(iqP) > 0) then
                    pdrRate(iRec358(iqP,1:nRec358(iqP))) = 0.d0
                    pdrRate(iRec358(iqP,1)) = dble(max(grid%pdrAlphaRec(cellP,iqP), 0.))
                 end if
              end do
              if (iH2cr358 > 0) pdrRate(iH2cr358) = pdrRate(iH2cr358) &
                   & + dble(max(grid%pdrPhotRate(cellP,6), 0.))
           end if
        end if

        call calculate_abundances(abun, pdrRate, nH, Tg, npart, &
             & pdrNspecMod, pdrNreacMod)
        abunPre = abun   ! D-258c: the chemistry's own state, before D-162/D-231 re-impose
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
        if (.true.) then                        ! D-193: unconditional
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
              ! D-266: all ionized stages, which the ion carrier stands for
              mocIon  = mocIonizedFrac(grid, cellP, pdrLinkElem(iLnk))
              if (mocNeut + mocIon <= 0.d0) cycle
              abun(iSpN) = availTot*mocNeut/(mocNeut+mocIon)
              abun(iSpI) = availTot*mocIon /(mocNeut+mocIon)
           end do

           ! ---------------------------------------------------- D-231
           ! And the electrons, for the same reason and on the same
           ! footing. D-212 imposed them BEFORE the solve only. D-230
           ! measured what the solve then does to that entry: x306, x26,
           ! x16, /14 against the value imposed, matching neither
           ! MOCASSIN's Ne nor the chemistry's own cations - it is
           ! whatever CVODE left in the slot, the restore in
           ! calculate_abundances.c (line 451) not taking effect on this
           ! path. The rates inside the solve use the imposed value (it is
           ! passed separately), so what was corrupted is the exported
           ! state vector - and that is what the level populations, the
           ! substituted cooling and the next pass's rates all read.
           !
           ! One reality per quantity: there is one electron density and
           ! MOCASSIN computes it.
           if (pdrNelect > 0 .and. grid%Hden(cellP) > 0.) &
                & abun(pdrNelect) = &
                & max(dble(grid%Ne(cellP))/dble(grid%Hden(cellP)), 0.d0)
        end if

        ! D-356: every reaction's rate in this cell, one cell per 0.1 dex of
        ! A_V on rank 0, the solver's state beside the re-imposed one.
        ! Diagnostic only.
        if (pdrDiagRates >= 2 .and. taskid == 0) &
             & call writeReactionRates(cellP, sqrt(dble(grid%xAxis(xP))**2 &
             & + dble(grid%yAxis(yP))**2 + dble(grid%zAxis(zP))**2), &
             & av, nH, Tg, abunPre, abun)

        ! D-354: the shielding columns are NOT rescaled here any more.
        ! D-078 wrote them as NHcol*abun(X), the local abundance times the
        ! whole column, and scaled them by abun(X)/abun0(X) after each
        ! solve so they followed the chemistry. Since D-088 they are the
        ! integrated columns of the cells IN FRONT of this one (both legs,
        ! computeAVradial and traceDiffuseSites), and the target cell is
        ! kept out of them precisely because its own H2 shielding itself
        ! is a positive feedback. Scaling them by this cell's abundance
        ! change put that self-term back, compounded over pdrChemIter, and
        ! it was the only input that differed between rounds and passes:
        ! T, n_e (imposed from MOCASSIN, above), the field and the columns
        ! are all fixed within an MC iteration. D-351 found the passes
        ! alternating on it (L-25). With it gone every round and pass
        ! recomputed the first, so the chemistry is solved once (D-354).

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
        ! D-230: and what survives the solve, in the same cell. Electrons are
        ! frozen inside calculate_abundances, so these two must agree - and the
        ! dumped state says they do not.
        ! nProbe230b, not nProbe230: gating the pair on the first counter left
        ! this print firing for every cell once that counter had stopped
        ! rising, and it wrote the per-cell state of the whole grid to the log.
        if (teProbe /= 0 .and. taskid == 0 .and. nProbe230b < 24) then
           nProbe230b = nProbe230b + 1
           print '(a,i7,a,es11.4,a,es11.4,a,es11.4,a,es11.4,a,es11.4)', &
                & " ! [D230]      after solve, cell", cellP, &
                & "   e-", abun(max(pdrNelect,1)), &
                & "   H+", abun(NPROTON), "   He+", abun(NHEx), &
                & "   C+", abun(NCx), &
                & "   H+ + He+ + C+", abun(NPROTON) + abun(NHEx) + abun(NCx)
        end if

        if (all(abun == abun0)) pdrNstuck = pdrNstuck + 1

        ! D-121: the chemistry's outputs are the first hand-off in the chain.
        ! A NaN in them used to reach T_dust through the D-093 grain feedback
        ! (removed at D-352) and stop the run under a message about
        ! sublimation that named nothing useful; it is still caught here first.
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
              end if
           end if
           if (lgNanFound .and. taskid == 0) print*, &
                & "! [D121] first non-finite: ", trim(nanWhere), &
                & "  cell", nanCell, " index", nanIdx
        end if

        ! D-354: abun0 is what this cell held at the last MC iteration. H2
        ! and CO are neither imposed from MOCASSIN nor rescaled, so the move
        ! is the chemistry's own answer to this iteration's field - since
        ! D-350, largely its per-cell Monte Carlo noise (L-26).
        do iqP = 1, 2
           ispP = NH2
           if (iqP == 2) ispP = NCO
           if (max(abun0(ispP), abun(ispP)) < 1.d-12) cycle
           dqP = abs(abun(ispP) - abun0(ispP))/max(abun0(ispP), abun(ispP))
           passCnt(iqP,1) = passCnt(iqP,1) + 1.d0
           if (dqP > 1.d-3) passCnt(iqP,2) = passCnt(iqP,2) + 1.d0
           if (dqP > 1.d-2) passCnt(iqP,3) = passCnt(iqP,3) + 1.d0
           passMax(iqP) = max(passMax(iqP), dqP)
        end do

        ! D-358: how far the solver's own X+/X ends from MOCASSIN's, H and O
        if (pdrNHsp > 0 .and. NPROTON > 0 .and. NO > 0 .and. NOx > 0) then
           do iqP = 1, 2
              if (iqP == 1) then
                 dqP = dble(grid%ionDen(cellP,elementXref(1),1))
                 if (dqP > 0.d0 .and. abunPre(pdrNHsp) > 0.d0 .and. abunPre(NPROTON) > 0.d0) then
                    dqP = log10((abunPre(NPROTON)/abunPre(pdrNHsp)) &
                         & / (dble(grid%ionDen(cellP,elementXref(1),2))/dqP))
                 else
                    cycle
                 end if
              else
                 dqP = dble(grid%ionDen(cellP,elementXref(8),1))
                 if (dqP > 0.d0 .and. abunPre(NO) > 0.d0 .and. abunPre(NOx) > 0.d0) then
                    dqP = log10((abunPre(NOx)/abunPre(NO)) &
                         & / (mocIonizedFrac(grid, cellP, 8)/dqP))
                 else
                    cycle
                 end if
              end if
              if (dqP /= dqP) cycle
              ion358(iqP,1) = ion358(iqP,1) + 1.d0
              if (abs(dqP) > log10(2.d0)) ion358(iqP,2) = ion358(iqP,2) + 1.d0
              ion358(iqP,3) = max(ion358(iqP,3), abs(dqP))
           end do
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
        ! D-258: extended to H2+ and H3+, and sampled one cell per 0.5 mag of
        ! A_V rather than a single pdrDiagAV window, because the question -
        ! is our H2+ consistent with our OWN network? - is a function of depth.
        ! The column that matters is x_eq: the ODE is dx/dt = form + x*loss
        ! with loss negative, so at steady state x_eq = form/(-loss), and
        ! x_eq/x is 1 exactly when a species sits where its own rates put it.
        ! Measured from the output files, ours is ~1e9 for H2+ (D-257 s11).
        ! Diagnostic only; fixed-size saved flags, so no allocation and none
        ! of the D-245/D-253 leak class.
        if (pdrDiagRates /= 0 .and. taskid == 0) then
           ! D-258b: re-arm every MC iteration. The first version latched each
           ! A_V bin on first visit and never cleared, so all six bins were
           ! captured during iteration 4 - the FIRST chemistry pass, with the
           ! model 0.00% converged - and never refreshed over 55 later pdrStep
           ! calls. The probe then described a transient, not the settled
           ! state, which is exactly the failure D-176..D-181 warn about: a
           ! diagnostic whose quantity cannot move reports for free.
           if (nIterateMC /= iterD113) then
              lgAVd113 = .false.
              iterD113 = nIterateMC
           end if
           iBinD113 = int(av/0.5d0) + 1
           if (iBinD113 < 1) iBinD113 = 1
           if (iBinD113 > 8) iBinD113 = 8
           if (.not.lgAVd113(iBinD113)) then
              lgAVd113(iBinD113) = .true.
              print*, "! [D258] rates at A_V =", real(av), " n_H =", real(nH), &
                   & " T =", real(Tg)
              print*, "! [D258]   species     x            form         ", &
                   & "x*loss       resid        x_eq         x_eq/x"
              do it = 1, 5
                 nSpec = 0.d0
                 select case (it)
                 case (1); ik = NH2
                 case (2); ik = NCO
                 case (3); ik = pdrNHsp
                 case (4); ik = NH2x
                 case (5); ik = NH3x
                 end select
                 if (pdrLossSp(ik) < 0.d0) nSpec = pdrFormSp(ik)/(-pdrLossSp(ik))
                 print*, "! [D258]  ", pdrSpecies(ik), real(abun(ik)), &
                      & real(pdrFormSp(ik)), real(abun(ik)*pdrLossSp(ik)), &
                      & real((pdrFormSp(ik)+abun(ik)*pdrLossSp(ik)) &
                      &      / max(abs(pdrFormSp(ik)),1.d-99)), &
                      & real(nSpec), real(nSpec/max(abun(ik),1.d-99))
              end do
              print*, "! [D258]   implied H2 formation coefficient R =", &
                   & real(pdrFormSp(NH2)/max(nH*abun(pdrNHsp),1.d-99)), &
                   & " cm^3/s   (textbook ~3e-17)"
              ! D-258c: the chemistry's OWN electrons and linked ions at the end
              ! of the last solve, before D-162 re-imposes the ion ratios and
              ! D-231 the electrons. Tests D-258's hypothesis: odes_reduced.c:52
              ! computes x_e as the cation sum of the evolving state (written back
              ! at calculate_abundances.c:451), while D-163 has deleted the linked
              ! ions' radiative recombination, so they may accumulate in the solve.
              print*, "! [D258c]  species    internal(solve)   imposed(MOCASSIN)   int/imp"
              do it = 1, 6
                 select case (it)
                 case (1); ik = pdrNelect
                 case (2); ik = NPROTON
                 case (3); ik = NHEx
                 case (4); ik = NCx
                 case (5); ik = NOx
                 case (6); ik = NMGx
                 end select
                 if (ik <= 0) cycle
                 print*, "! [D258c]  ", pdrSpecies(ik), real(abunPre(ik)), real(abun(ik)), &
                      & real(abunPre(ik)/max(abun(ik),1.d-99))
              end do
           end if
        end if


        ! ---- the PDR's line cooling at MOCASSIN's temperature --------------
        ! D-031 relaxed a PDR gas temperature here, and D-193 made MOCASSIN
        ! own T in every cell, which left a one-pass bracket whose answer was
        ! overwritten by Te. D-352 removed it: what this block produces is
        ! the level populations and the cooling tabulated in T (D-215).


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
        ! D-215: walk the tabulation grid from the bottom up, so each
        ! level-population solve warm-starts from the one below it - the
        ! same chaining D-166 used for its second point, extended along
        ! the whole grid. iTnear is the entry closest to the cell's actual
        ! temperature; it is the one whose populations are stored and whose
        ! value goes into pdrCoolSp, so everything that reads those still
        ! reads the coolant AT Tg.
        iTnear = 1
        do iTpass = 2, pdrNtab
           if (abs(log(dble(pdrTabT(iTpass))/Tg)) < &
             & abs(log(dble(pdrTabT(iTnear))/Tg))) iTnear = iTpass
        end do
        ! D-362: one pass more, at the cell's own temperature. The table
        ! entries are a factor 1.94 apart and the balance interpolates them;
        ! the lines the run REPORTS come from this solve, at the T the cell
        ! has, and they write nothing the physics reads. It starts from the
        ! populations just stored at iTnear.
#ifdef RAYTHEIA
        ! D-377: this cell's line-escape rays, once for every coolant and pass
        call traceLineRays(grid, xP, yP, zP)
#endif
        do iTpass = 1, pdrNtab + 1
           if (iTpass <= pdrNtab) then
              Tc = dble(pdrTabT(iTpass))
           else
              Tc = Tg
           end if

        do ik = 1, pdrNcool
           ! D-363: the atomic coolants are MOCASSIN's to cool with now, at
           ! its own trial T, so their table is not built; the chemistry's
           ! atom is solved once, at the cell's T, for its escape
           ! probabilities (and its lines, kept for comparison, D-363).
           if (.not.pdrCoolIsMol(ik) .and. iTpass <= pdrNtab) then
              grid%pdrCoolTab(cellP, ik, iTpass) = 0.
              cycle
           end if
           nlev = pdrCoolant2(ik)%cnlev
           nSpec = abun(pdrCoolant2(ik)%cspec)*nH
           ! D-266: an atomic ION coolant (C+) must be excited at the
           ! density of its own stage. Its carrier holds every ionized
           ! stage, so take the stage-2 share of MOCASSIN's ionized total.
           ! In the PDR that share is 1 and nothing changes; in the H II
           ! gas it keeps C++ out of the [C II] cooling that replaces
           ! MOCASSIN's own C II lines.
           if (.not.pdrCoolIsMol(ik) .and. pdrCoolIon(ik) == 2) then
              fIonL = mocIonizedFrac(grid, cellP, pdrCoolElem(ik))
              if (fIonL > 0.d0) nSpec = nSpec &
                   & *dble(grid%ionDen(cellP, elementXref(pdrCoolElem(ik)), 2))/fIonL
           end if

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
              if (iTpass <= pdrNtab) then
                 grid%pdrCoolTab(cellP, ik, iTpass) = 0.        ! D-215
                 if (iTpass == iTnear) grid%pdrCoolSp(cellP, ik) = 0.
              else if (pdrLnN(ik) > 0) then
                 grid%pdrLineEm(cellP, pdrLnOff(ik)+1:pdrLnOff(ik)+pdrLnN(ik)) = 0.  ! D-362
                 grid%pdrLineBeta(cellP, pdrLnOff(ik)+1:pdrLnOff(ik)+pdrLnN(ik)) = 1. ! D-363
                 if (.not.pdrCoolIsMol(ik)) grid%pdrCoolSp(cellP, ik) = 0.
              end if
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
           ! D-377 (L-27): each of the twelve rays is the list of cells
           ! traceLineRays found from this one to the edge of the model, and
           ! each point carries THAT cell's level populations over the path
           ! it has in that cell - 3D-PDR's own tau along a ray. It replaces
           ! the slab closed form, which read HEALPix nside=1 as three rings
           ! about the radial direction, gave the four mu = 0 rays an
           ! infinite column (so beta <= 2/3 even for a thin line) and
           ! carried this cell's own populations over the whole column. Other
           ! cells' populations are last iteration's (pdrLevPop, on every
           ! rank); this cell's are iterated below. Since D-363 the beta found
           ! here is what MOCASSIN's own C, C+ and O atoms cool with.
           maxPt = max(1, maxval(lrN))
           if (allocated(evpopR)) deallocate(evpopR, plenR)
           allocate(evpopR(0:nraysLoc-1, 0:maxPt, nlev), plenR(0:nraysLoc-1, 0:maxPt))
           evpopR = 0.d0
           plenR  = 0.d0
           do kray = 0, nraysLoc-1
              jjr(kray) = lrN(kray)
              do ipt = 1, lrN(kray)
                 plenR(kray,ipt) = lrLen(kray,ipt)/PC
                 if (lrCell(kray,ipt) /= cellP) evpopR(kray,ipt,1:nlev) = &
                      & grid%pdrLevPop(lrCell(kray,ipt), pdrLevOff(ik)+1 : pdrLevOff(ik)+nlev)
              end do
           end do
#else
           colA   = av
           jjr    = 1
           evpt   = 0.d0
           evpt(1,6,0) = 0.d0
           evpt(1,6,1) = (colA/AVfacL)/nH/PC
#endif

           ! ---- D-377: the background at each line ----------------------
           ! MOCASSIN's own mean intensity in the bin the line falls in (its
           ! dust emission, and the bin-averaged share of whatever lines it
           ! transports there), J_nu = Jste/(4 pi dnu); escape_probability
           ! adds the CMB, which MOCASSIN does not transport. It replaces the
           ! vendored grain emissivity 2e-12 n_H x metallicity at T_dust.
           if (allocated(pdrEscBg)) then
              if (.not.allocated(pdrTrBin)) call buildTrBins()
              pdrEscBg = 0.d0
              do il = 2, nlev
                 do jl = 1, il-1
                    ib = pdrTrBin(il, jl, ik)
                    if (ib <= 0) cycle
                    jBg = dble(grid%Jste(cellP, ib))
                    if (lgDebug) jBg = jBg + dble(grid%Jdif(cellP, ib))
                    pdrEscBg(il, jl) = jBg/(4.d0*dble(pi)*dble(widFlx(ib))*dble(fr1Ryd))
                 end do
              end do
           end if

           do ilev = 1, max(pdrLevIter,1)
#ifdef RAYTHEIA
           ! D-377: this cell's own points take its current iterate
           do kray = 0, nraysLoc-1
              evpopR(kray,0,1:nlev) = lpop(1:nlev)
              do ipt = 1, lrN(kray)
                 if (lrCell(kray,ipt) == cellP) evpopR(kray,ipt,1:nlev) = lpop(1:nlev)
              end do
           end do
#else
           evpop = 0.d0
           do kray = 0, nraysLoc-1
              evpop(kray,0,1:nlev) = lpop(1:nlev)
              evpop(kray,1,1:nlev) = lpop(1:nlev)
           end do
#endif

           trans(1:nlev,1:nlev) = 0.d0
#ifdef RAYTHEIA
           call escape_probability(trans(1:nlev,1:nlev), Td, nraysLoc, nlev, &
                & pdrCoolant2(ik)%A_COEFFS, pdrCoolant2(ik)%B_COEFFS, &
                & Ccoef(1:nlev,1:nlev), pdrCoolant2(ik)%frequencies, &
                & evpopR, maxPt, Tc, dble(pdrVturb)*1.d5, jjr, &
                & lpop(1:nlev), pdrCoolant2(ik)%weights, coolK, &
                & lline(1:nlev,1:nlev), nH, pdrMetalMod, &
                & pdrCoolant2(ik)%molweight, plenR)
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

           ! D-362: the pass at the cell's own T stores its lines, and
           ! measures the table interpolation the balance uses against it
           if (iTpass > pdrNtab) then
              do iLn362 = pdrLnOff(ik)+1, pdrLnOff(ik)+pdrLnN(ik)
                 grid%pdrLineEm(cellP, iLn362) = &
                      & real(lline(pdrLnUp(iLn362), pdrLnLo(iLn362)))
                 ! D-363: and each transition's escape probability, from the
                 ! same (last) evaluation, for MOCASSIN's atom to take
                 if (allocated(pdrEscBeta)) grid%pdrLineBeta(cellP, iLn362) = &
                      & real(pdrEscBeta(pdrLnUp(iLn362), pdrLnLo(iLn362)))
              end do
              ! D-363: for an atom this is its only solve - keep its
              ! populations for the next iteration's start, and its cooling
              ! at T for pdrCoolSp.out (a diagnostic; the balance uses
              ! MOCASSIN's atom)
              if (.not.pdrCoolIsMol(ik)) then
                 grid%pdrLevPop(cellP, pdrLevOff(ik)+1 : pdrLevOff(ik)+nlev) = lsol(1:nlev)
                 grid%pdrCoolSp(cellP, ik) = real(coolK)
                 coolTot = coolTot + coolK
              end if
              cTab362 = pdrCoolAt(grid, cellP, ik, real(Tg))
              if (coolK > 0.d0 .and. cTab362 > 0.d0) then
                 d362 = abs(log(coolK/cTab362))
                 lnCmp362(ik,1) = lnCmp362(ik,1) + 1.d0
                 lnCmp362(ik,2) = lnCmp362(ik,2) + coolK
                 lnCmp362(ik,3) = lnCmp362(ik,3) + cTab362
                 lnCmp362(ik,4) = lnCmp362(ik,4) + d362
                 lnMax362(ik)   = max(lnMax362(ik), d362)
              end if
              cycle
           end if

           grid%pdrCoolTab(cellP, ik, iTpass) = real(coolK)          ! D-215
           if (iTpass == iTnear) then
              grid%pdrLevPop(cellP, pdrLevOff(ik)+1 : pdrLevOff(ik)+nlev) &
                   & = lsol(1:nlev)
              coolTot = coolTot + coolK
              coolTot3 = coolTot3 + coolK       ! D-363: the tabulated coolants alone
              grid%pdrCoolSp(cellP, ik) = real(coolK)                 ! D-096
           end if

           ! D-060 diagnostic: per-coolant budget at the illuminated face
           if (pdrDiagCool > 0 .and. taskid == 0 .and. iTpass == 1) then
              if (pdrNdiag < 400000) then
                 pdrNdiag = pdrNdiag + 1
                 print '(a,i3,a,es9.2,a,i3,a,es10.3,a,es11.3,a,f7.2,a,f9.1,a,2es11.3,a,es10.3,a,es10.3,a,es10.3)', &
                    & " [D060] coolant", ik, " A_V=", grid%AVeff(cellP), &
                    & " cspec=", pdrCoolant2(ik)%cspec, " n=", nSpec, &
                    & " cool=", coolK, " Td=", Td, " T=", real(Tc), " pop=", lsol(1), lsol(2), &
                    & " nSpec=", nSpec, " ne=", abun(pdrNelect)*nH, " nH0=", abun(pdrNHsp)*nH
              end if
           end if
        end do
        end do
        ! Local power law, clamped: below the excitation temperature a
        ! fine-structure coolant rises nearly exponentially, above it the
        ! line saturates and the index goes to zero. Extrapolating an
        ! unclamped index over three decades is not defensible.
        ! D-215: kept, but DIAGNOSTIC only - the balance no longer reads
        ! either of these. The slope is now measured off the table across
        ! the entry nearest Tg and the one above it, so the [D213] line
        ! still reports the local logarithmic index of the real cooling
        ! function rather than the exponent of a prescription.
        coolTot2 = 0.d0
        do ik = 1, pdrNcool
           coolTot2 = coolTot2 &
                & + dble(grid%pdrCoolTab(cellP, ik, min(iTnear+1, pdrNtab)))
        end do
        ! D-363: over the tabulated coolants only (CO); the atoms are solved at
        ! T alone and are in coolTot but not in the table
        if (coolTot3 > 0.d0 .and. coolTot2 > 0.d0 .and. iTnear < pdrNtab) then
           grid%pdrCoolSlope(cellP) = real( &
                & log(coolTot2/coolTot3) &
                & /log(dble(pdrTabT(iTnear+1))/dble(pdrTabT(iTnear))))
        else
           grid%pdrCoolSlope(cellP) = 0.
        end if
        grid%pdrCoolTref(cellP) = pdrTabT(iTnear)
        ! D-215: the D-166 power-law check is gone with the power law it
        ! checked. There is nothing left to validate here - the balance
        ! reads solves, not an extrapolation from them.


        grid%pdrCool(cellP) = real(coolTot)


        ! ---- the PDR's heating terms, at MOCASSIN's temperature ------------
        ! 12 terms, total in slot 12 (heatingfunctions.F90). Evaluated once, at
        ! grid%Te as it stands - NOT the Tg the rates were taken at, which is
        ! Te clamped to [pdrTmin, pdrTmax] (above). The two differ only where
        ! Te leaves that range (3 cells of pn150k, none of hiipdr); D-352 keeps
        ! the behaviour and records the mismatch as open.
        call CALC_HEATING(nH, dble(grid%Te(cellP)), Td, chiLoc, dble(pdrVturb)*1.d5, &
             & pdrNspecMod, abun, pdrNreacMod, pdrRate, heat, &
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
        grid%H2den(cellP)     = real(abun(NH2)*nH)         ! D-107

        ! D-032's PDR heat/cool test on lgConverged is gone (D-352): the PDR's
        ! heat and cool are evaluated at MOCASSIN's temperature and nothing
        ! solves for them to balance, so the test (off by default since D-228)
        ! asked whether an unsolved balance happened to hold.

      end subroutine pdrStep


      !-----------------------------------------------------------------
      ! D-348: the diffuse-ray diagnostics. reset before each coupling pass's
      ! pdrStep sweep, report after the last one; every rank calls both, so
      ! the reduction is a matched collective. The 1D flavour has no diffuse
      ! rays and does nothing.
      !-----------------------------------------------------------------
      subroutine resetDiffuseDiag()
        implicit none
        difDiag = 0.d0
      end subroutine resetDiffuseDiag

      subroutine reportDiffuseDiag(iterMC)
        implicit none
        include 'mpif.h'
        integer, intent(in) :: iterMC
#ifdef RAYTHEIA
        double precision :: tot(nDifCol, nDifBin), n
        integer          :: ib, ierr, k

        call mpi_allreduce(difDiag, tot, nDifCol*nDifBin, &
             & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
        if (taskid == 0) then
           print '(a,i4,a)', " ! [D350] photorate field, iteration", iterMC, &
                & " - means per cell, ratios of sums"
           print '(a)', " ! [D350]  A_V bin     cells   chi_MC   chi_dif  chi_pred  chi_dir" // &
                & "   win_dir  win_dif  presc_H2    R_old     R_dir   R_difSrc R_dif2leg" // &
                & "  Nwalk/N  AVwalk/AV  aniso  sites  fb  unset"
           do ib = 1, nDifBin
              n = tot(1,ib)
              if (n <= 0.d0) cycle
              print '(a,f5.2,a,f5.2,i8,7es9.2,4es10.2,2f9.4,f7.2,f7.0,2i5)', &
                   & " ! [D350] ", difBinEdge(ib-1), "-", min(difBinEdge(ib), 99.d0), &
                   & nint(n), (tot(k,ib)/n, k = 2, 8), (tot(k,ib)/n, k = 9, 12), &
                   & tot(13,ib)/max(tot(14,ib), 1.d-99), &
                   & tot(15,ib)/max(tot(16,ib), 1.d-99), &
                   & tot(17,ib)/n, tot(18,ib)/n, nint(tot(19,ib)), nint(tot(20,ib))
           end do
        end if
#endif
        difDiag = 0.d0
      end subroutine reportDiffuseDiag

      !-----------------------------------------------------------------
      ! D-354: print passCnt/passMax for this iteration's chemistry, then
      ! clear them. Collective: every rank calls it once per iteration.
      !-----------------------------------------------------------------
      subroutine reportPassChange(iterMC)
        implicit none
        include 'mpif.h'
        integer, intent(in) :: iterMC
        double precision    :: cnt(2,3), mx(2)
        double precision    :: cmp362(30,4), mx362(30)     ! D-362
        integer             :: iq, ierr
        character(len=2), parameter :: lab(2) = (/ 'H2', 'CO' /)

        call mpi_allreduce(passCnt, cnt, 6, mpi_double_precision, &
             & mpi_sum, mpi_comm_world, ierr)
        call mpi_allreduce(passMax, mx, 2, mpi_double_precision, &
             & mpi_max, mpi_comm_world, ierr)
        if (taskid == 0) then
           do iq = 1, 2
              print '(a,i3,3a,i7,a,f8.3,a,f8.3,a,es9.2)', &
                   & " ! [D354] iteration", iterMC, &
                   & " vs the last:  ", lab(iq), "  cells", nint(cnt(iq,1)), &
                   & "   moved >0.1%", 100.d0*cnt(iq,2)/max(cnt(iq,1), 1.d0), &
                   & "%   >1%", 100.d0*cnt(iq,3)/max(cnt(iq,1), 1.d0), &
                   & "%   max", mx(iq)
           end do
        end if
        passCnt = 0.d0
        passMax = 0.d0

        ! D-358: the solver's ionization against MOCASSIN's
        call mpi_allreduce(ion358(:,1:2), cnt(:,1:2), 4, mpi_double_precision, &
             & mpi_sum, mpi_comm_world, ierr)
        call mpi_allreduce(ion358(:,3), mx, 2, mpi_double_precision, &
             & mpi_max, mpi_comm_world, ierr)
        call mpi_allreduce(nUnset358, iq, 1, mpi_integer, mpi_sum, mpi_comm_world, ierr)
        if (taskid == 0) then
           print '(a,i3,2(a,a2,a,i7,a,f8.3,a,f7.2),a,i6)', " ! [D358] iteration", iterMC, &
                & "  solver X+/X vs MOCASSIN:  ", 'H ', " cells", nint(cnt(1,1)), &
                & "  off >2x", 100.d0*cnt(1,2)/max(cnt(1,1),1.d0), "%  max dex", mx(1), &
                & "   ", 'O ', " cells", nint(cnt(2,1)), &
                & "  off >2x", 100.d0*cnt(2,2)/max(cnt(2,1),1.d0), "%  max dex", mx(2), &
                & "   rates unset in", iq
        end if
        ion358 = 0.d0
        nUnset358 = 0

        ! D-362: the balance's interpolated cooling against a solve at T
        call mpi_allreduce(lnCmp362, cmp362, 120, mpi_double_precision, &
             & mpi_sum, mpi_comm_world, ierr)
        call mpi_allreduce(lnMax362, mx362, 30, mpi_double_precision, &
             & mpi_max, mpi_comm_world, ierr)
        if (taskid == 0) then
           do iq = 1, pdrNcool
              if (cmp362(iq,1) < 1.d0) cycle
              print '(a,i3,a,a10,a,i7,a,f8.4,a,f8.4,a,f8.4)', " ! [D362] iteration", &
                   & iterMC, "  ", trim(adjustl(pdrCoolant(iq))), " cells", &
                   & nint(cmp362(iq,1)), "  cooling at T / table", &
                   & cmp362(iq,2)/max(cmp362(iq,3), 1.d-300), "  mean |ln|", &
                   & cmp362(iq,4)/cmp362(iq,1), "  max |ln|", mx362(iq)
           end do
        end if
        lnCmp362 = 0.d0
        lnMax362 = 0.d0
      end subroutine reportPassChange

      !-----------------------------------------------------------------
      ! D-356: one row per sampled cell holding every reaction's volume rate
      ! [cm^-3 s^-1], taken from the solver's own state so that formation
      ! and loss of each species close at its steady state. The weights are
      ! the ODE's (odes_reduced.c): k n1 n2 for two bodies, k n(X) for
      ! PHOTON, CRP and CRPHOT, k n_H n(H) for formation on grains, and the
      ! electrons as the sum of the cations, which is how the ODE builds
      ! them. The state MOCASSIN re-imposes after the solve is written
      ! beside the solver's, so the two can be compared cell by cell.
      ! One cell per 0.1 dex of A_V on rank 0. The file is rewritten each MC
      ! iteration, so it ends holding the last. Channels are attributed
      ! offline from dataPDR's rate file (tools/d356_channels.py).
      !-----------------------------------------------------------------
      subroutine writeReactionRates(cellP, rCell, av, nH, Tg, xs, xi)
        implicit none
        integer, intent(in)          :: cellP
        double precision, intent(in) :: rCell, av, nH, Tg
        double precision, intent(in) :: xs(:), xi(:)

        integer, save              :: iterLast = -1, lun = -1
        logical, save              :: lgBin(0:40) = .false.
        integer, allocatable, save :: rIdx(:,:)
        integer          :: i, j, k, ib
        double precision :: xe, rr
        double precision, allocatable :: R(:)

        if (av <= 0.d0) return
        ib = int((log10(av) + 2.5d0)*10.d0)
        if (ib < 0 .or. ib > 40) return
        if (nIterateMC /= iterLast) then
           if (lun > 0) close(lun)
           open(newunit=lun, file='output/pdrReacRates.out', status='replace', &
                & action='write')
           write(lun, '(a,i4,a,i4,a,i5)') '# D-356 reaction rates, MC iteration', &
                & nIterateMC, '  nspec', pdrNspecMod, '  nreac', pdrNreacMod
           write(lun, '(a)') '# row: cell r[cm] A_V n_H[cm-3] T[K] x_e(solver), ' // &
                & 'x(1:nspec) solver, x(1:nspec) imposed, R(1:nreac) [cm-3 s-1]'
           write(lun, '(a)', advance='no') '# species:'
           do j = 1, pdrNspecMod
              write(lun, '(1x,a)', advance='no') trim(adjustl(pdrSpecies(j)))
           end do
           write(lun, *)
           lgBin = .false.
           iterLast = nIterateMC
        end if
        if (lgBin(ib)) return
        lgBin(ib) = .true.

        if (.not.allocated(rIdx)) then
           allocate(rIdx(pdrNreacMod, 3))
           rIdx = 0
           do i = 1, pdrNreacMod
              do k = 1, 3
                 do j = 1, pdrNspecMod
                    if (trim(adjustl(pdrReactant(i,k))) == trim(adjustl(pdrSpecies(j)))) &
                         & rIdx(i,k) = j
                 end do
              end do
           end do
        end if

        xe = 0.d0
        do j = 1, pdrNspecMod
           if (index(pdrSpecies(j), '+') > 0) xe = xe + xs(j)
        end do

        allocate(R(pdrNreacMod))
        do i = 1, pdrNreacMod
           rr = pdrRate(i)
           if (any(adjustl(pdrReactant(i,:)) == '#')) then
              rr = rr*nH*xs(rIdx(i,1))*nH                ! k n_H n(H)
           else
              do k = 1, 3
                 if (rIdx(i,k) <= 0) cycle
                 if (rIdx(i,k) == pdrNelect) then
                    rr = rr*xe*nH
                 else
                    rr = rr*xs(rIdx(i,k))*nH
                 end if
              end do
           end if
           R(i) = rr
        end do
        write(lun, '(i7,4es13.5,es12.4)', advance='no') cellP, rCell, av, nH, Tg, xe
        ! es13.4e3: a plain es12.4 drops the E of a three-digit exponent
        write(lun, '(999es13.4e3)') xs(1:pdrNspecMod), xi(1:pdrNspecMod), R
        flush(lun)
        deallocate(R)
      end subroutine writeReactionRates


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
                    ! D-193: no guard. The PDR does not publish a temperature
                    ! at all now, so the old pdrTgas test would skip every cell
                    ! and elemAvail - the molecular content, which is the whole
                    ! point of the handback - would never be updated.

                    ! ------------------------------------------- D-193
                    ! The handback is the MOLECULAR CONTENT and nothing else.
                    !
                    ! 3D-PDR receives MOCASSIN's ion densities, Ne, Te, dust
                    ! temperature and dust opacity, and reports back how much
                    ! of each element it converted to molecules, plus the
                    ! heating and cooling that follows from those molecules
                    ! (published by pdrStep). It does not write an ionization
                    ! state and it does not write a temperature. Those are
                    ! MOCASSIN's, solved in ionBalance and thermBalance, and
                    ! they have exactly one writer each.
                    !
                    ! Removed here as of D-193: the blended writeback of
                    ! ionDen for H, He, C, O and Mg, and the Te writeback.
                    ! Every one of them was a second author for a variable
                    ! MOCASSIN already owned, reachable only through a switch
                    ! (pdrIonFromMocassin, pdrTeFromMocassin, pdrAtomicH) - so
                    ! which code owned the ionization depended on an input
                    ! file. D-192 is what that cost: two writers with two
                    ! different normalisations, one clamping the other's answer
                    ! to zero in half the PDR.
                    !
                    ! elemAvail is the handback. Per element it is
                    ! (neutral + ionized)/total from the chemistry - the
                    ! fraction NOT locked in molecules - and ionBalance
                    ! constrains its ion stages to sum to it (D-193 in
                    ! update_mod). No enumeration of which molecules exist is
                    ! needed, and carbon in CO simply does not appear in any
                    ! atomic stage: it emits no atomic line and contributes no
                    ! free electron, which is exactly right.
                    if (pdrNHsp > 0 .and. NPROTON > 0) &
                         & grid(iG)%elemAvail(cellP,1) = real(min(max( &
                         &   grid(iG)%pdrAbun(cellP,pdrNHsp) &
                         & + grid(iG)%pdrAbun(cellP,NPROTON), 0.d0), 1.d0))

                    ! Helium: no helium-bearing molecule exists in the network,
                    ! so its available fraction is 1 by construction. Written
                    ! explicitly rather than left at whatever it held, so the
                    ! array has one meaning everywhere.
                    if (lgElementOn(2) .and. NHe > 0 .and. NHEx > 0) &
                         & grid(iG)%elemAvail(cellP,2) = 1.0

                    iAb = grid(iG)%abFileIndex(i,j,k)
                    call setElemAvail(grid(iG), cellP, iAb,  6, NC,  NCx)
                    call setElemAvail(grid(iG), cellP, iAb,  8, NO,  NOx)
                    call setElemAvail(grid(iG), cellP, iAb, 12, NMG, NMGx)
                 end do
              end do
           end do
        end do

      end subroutine pdrToMocassin


      !-----------------------------------------------------------------
      ! Record how much of one element the chemistry did NOT lock into
      ! molecules: (neutral + ion carrier)/total, from the network's own
      ! abundances. Since D-266 the ion carrier holds every ionized stage, so
      ! this is 1 - molecular fraction; before it, it also dropped the doubly
      ! ionized share and removed it from MOCASSIN's gas (D-265). D-193: this is the whole handback for an element. The
      ! ion stages themselves are MOCASSIN's and are not written here.
      !
      ! The fractions are taken relative to MOCASSIN's own elemAbun, which is
      ! exact only if both codes use the same elemental abundances - the
      ! network's come from species_*.d and MOCASSIN's from its abundance
      ! file. They are clamped here, and reconciling them is an open item.
      !-----------------------------------------------------------------
      subroutine setElemAvail(grid, cellP, iAb, elem, iNeut, iIon)
        implicit none

        type(grid_type), intent(inout) :: grid
        integer, intent(in)            :: cellP, iAb, elem, iNeut, iIon

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

      end subroutine setElemAvail

#endif
end module pdr_mod
