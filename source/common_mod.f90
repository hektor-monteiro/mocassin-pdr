! Copyright (C) 2005 Barbara Ercolano
! Modified 2025-2026 by Hektor Monteiro for MOCASSIN-PDR; the changes are
! recorded in the git history and in DEVLOG.md.
!
! Version 2.02
module common_mod
    use constants_mod
    use vector_mod
    use iso_fortran_env
    implicit none


    ! fluorescence variables
    integer          :: nFluo ! # of fluorescent lines to be transfered
    integer          :: nVP   ! # of fluorescent viewing angles

    character(len=4), allocatable :: fluorescenceLabel(:) ! ID labels of fluorescent transitions
    real, allocatable    :: fluorescenceVP(:,:) ! viewing angles for fluorescence cube &
                                            ! (for the first dimension 1=theta;2=phi)

    ! MPI variables
    integer, allocatable :: lgConvergedTemp(:)  ! temporary converged? flag
    integer, allocatable :: lgBlackTemp(:)      ! temporary converged? flag

    logical         :: lg2D=.false.             ! 2D?
    logical         :: lgIsotropic

    logical         :: lgMultiStars=.false.
    logical         :: lgEquivalentTau          ! calculate equivalent tau?
    logical         :: lgWarm=.false.           ! warm started?
    logical         :: lgFluorescence=.false.   ! fluorescence run?
    logical         :: lgNeInput=.false.        ! Ne distribution entered
    logical         :: lgPhotoelectric = .true. ! photoelectric effect on
    logical         :: lgQheat = .false.        ! temperature spiking on?
    logical         :: lgWritePss=.false.       ! write Pss for qHeat file?
    logical         :: lgTraceHeating = .false. ! trace thermal balance?
    ! D-352: Case A recombination cooling (D-286), the Weingartner & Draine
    ! (2001) photoelectric yield (D-289), the matched-unit grain charge balance
    ! (D-290) and transport of the thin diffuse lines (D-307) are the physics,
    ! not options. The MOCASSIN_RECCOOL / _YIELD / _GRAINQ / _LINES switches
    ! that selected the legacy forms are gone; tag d352-zone-and-switches
    ! builds them.
    logical         :: lgGrainSpiking = .true.  ! temperature spiking for small grains
    logical         :: lgEcho = .false.         ! light time travel included?
    logical         :: lgforceTDust = .false.   !
    logical         :: lgNosource = .false.     ! exclude sources from SED?
    logical         :: lginputDustMass = .false.! user sets input dust mass?
    logical         :: lginputGasMass = .false. ! user sets input gas mass?
    logical         :: lgCDE = .false.          ! user sets CDE for grain properties?

    real, allocatable :: gSca(:)                 ! gSca(freq)

    real, allocatable   :: TdustTemp(:,:,:)     ! temporary dust temperature array (species,size,cell)
    real, allocatable   :: ionDenTemp(:,:,:)    ! temporary ion density array
    real, allocatable   :: NeTemp(:)            ! temporary electron density array
    real, allocatable   :: TeTemp(:)            ! temporary electron Temperature array
    real            :: HeIrecLineCoeff(34,3,4)
    real, allocatable   :: KNsigmaArray(:,:)    ! Klein Nishina calc PDFs (nbins,180)
    real, allocatable   :: KNsigmaT(:)          ! Klein Nishina cross-sections integrated over the solid angle
    real, allocatable   :: PcompArray (:,:)
    real, allocatable   :: twoDscaleJ(:)

    integer         :: radio4p9GHzP   !

    integer         :: ierr           ! MPI error status
    integer         :: numtasks       ! total # of processes
    integer         :: taskid         ! process identification #
    real            :: starttime      ! start time [sec]

    real            :: endtime        ! end time [sec]
    real            :: absInt         ! total number of absorption events
    real            :: scaInt         ! total number of scattering events
    real            :: echot1=0., echot2=0.   ! light time travel parameters
    real            :: echoTemp=0.       ! temperature outside the illuminated parabula
    real            :: dTheta                  !
    real            :: dPhi                    !
    real            :: nu0                     !
    real            :: nu0Add                  !
    real            :: totalDustMass           ! total dust mass 
    real            :: totalGasMass
    real            :: inputDustMass           ! for when user sets desired dust mass in input
    real            :: inputGasMass           ! for when user sets desired gas mass in input
    real            :: forceTDust = 0.         ! for TDust feature
    real            :: convPercent=0.          ! total convergence percentage
    real            :: pwlIndex = 0.           ! power law input spectrum index
    real            :: pwlMin=0.               ! power law lower cutoff [Ryd]
    real            :: pwlMax=0.               ! power law higher cutoff [Ryd]
    real            :: totPercent=0.           !
    real            :: minaQHeat = 0.          ! min radius for Q Heat in [um]
    real            :: NeUsed, TeUsed, HdenUsed ! local properties of the gas
    real            :: Tmax                    ! max temp for qheat
    real            :: auger(30,30,10,10)      ! auger yields



    integer, allocatable  :: HINuEdgeP(:)     ! pointers to the HI, HeI and HeII
    integer, allocatable  :: HeINuEdgeP(:)    ! series edges in nuArray
    integer, allocatable  :: HeIINuEdgeP(:)   !


    integer :: nTbins                     ! # of temp bins in qheat
    integer :: nlimGammaHI,nlimGammaHeI, nlimGammaHeII, ntkGamma

    integer :: nIterateMC = 1                  ! current MC interation #

    integer :: nflux = 1                       ! number of energy bins to the high energy end
                                               ! of the incident spectrum
    integer :: nLines = 0                      ! total number of lines
    ! D-292. The frequency bin of every line in linePDF's order, so a diffuse
    ! line packet can be emitted at its own frequency and traced instead of
    ! being dropped. 0 where the line has no usable wavelength.
    integer, allocatable :: lineNuP(:)         ! (nLines)
    ! D-296. linePDF is a per-cell cumulative PDF over lines, and nLines is
    ! 26718 - the forbidden block contributes nForLevelsLarge**2 = 20164 for
    ! Fe II alone. At (0:nCells, 1:nLines) that is 3.8 GB per rank, and with
    ! linePackets beside it 7.6 GB, which is why -np 14 could not start.
    ! Only the lines that map to a frequency bin (1663 of 26718) can ever be
    ! transported; the rest are drawn and dropped. Storing just the former
    ! reproduces the draw exactly - each kept line kappa still carries mass
    ! emiss_k/totalLines, and the shortfall 1 - linePDF(cell,nLinesPDF) is the
    ! probability of landing on a dropped line - at 6% of the memory.
    ! With transport off the map is the identity, so there is one code path.
    integer :: nLinesPDF = 0                   ! second extent of linePDF
    integer, allocatable :: lineTrSlot(:)      ! (nLines) -> slot, 0 = not stored
    integer, allocatable :: lineTrNuP(:)       ! (nLinesPDF) -> freq bin, 0 = drop
    ! D-376. The resonance lines of data/resLines.dat, found among the stored
    ! slots: lineTrRes(slot) is the resLine index of that slot's line (0 for
    ! every other line). A packet drawn on a resonance line is destroyed by
    ! the local dust with probability 1 - fEscapeResPhotons, and re-emitted
    ! from the cell's dust PDF; otherwise it is traced at the line's own
    ! frequency. Lya has a slot of its own, the last (lineTrLya): it used to
    ! ride in the H I 15->8 slot and was traced at 8.15 um (D-372).
    integer, allocatable :: lineTrRes(:)       ! (nLinesPDF) -> resLine index, 0 = none
    integer :: lineTrLya = 0                   ! Lya's slot, 0 = outside the frequency grid
    ! D-376: this rank's resonance-line packets in the current MC iteration -
    ! drawn, and of those destroyed by the dust. Reset and reported per
    ! iteration by iterateMC.
    integer(kind=8) :: nResDrawn = 0, nResDust = 0
    ! D-292. Transport the optically thin diffuse lines. MOCASSIN created them
    ! as packets and discarded them, which removed ~17% of the local FUV field
    ! in a PDR (D-291). The Lyman series is NOT in this channel - linePDF is
    ! built from ilow >= 2 - so this adds no resonance-line transfer.
    ! D-292: DEFAULT OFF. Transporting them destroyed the PDR outright -
    ! mean Te 302 -> 7576 K, f_mol 0.91 -> 0.00 - which optically thin
    ! forbidden lines cannot do, and no line maps at or above 1 Ryd, so it is
    ! not stray ionizing photons. The leading suspect is totalLines itself:
    ! it is the probability that a diffuse packet is a line, and because every
    ! such packet was discarded before, a mis-normalisation against the
    ! continuum normHI/normHeI/normHeII could never show. Not yet measured.

    integer :: iOrigin, jOrigin, kOrigin       ! pointers to the origin of the axes

    ! stack pointers

    integer :: KshellLimitP                    ! KshellLimitP
    integer :: FeKaColdP                       ! pointer to 6.4keV in nuArray
    integer :: secIonP
    integer :: cRecoilP                        ! pointer to compton recoil (194.Ryd) in nuArray
    integer :: xrayP                           ! pointer to carbon k-shell ionization in nuArray
    integer :: cRecoilHP, cRecoilHeP           ! recoil pointers

    integer :: BjumpP                          ! pointer to balmer jump

    integer :: nAuger(30,30,10)                ! max number of auger electrons freed

    integer :: noGpLoc = -1
    integer, dimension(3) :: noCellLoc=-1

    integer, dimension(nElements, nElements, 7, 3) &
         &:: elementP                          ! first dim is atomic number of element,
                                               ! second dimension is ion stage, 1 for atom
                                               ! third is shell, 1 for k shell, up to 7
                                               ! last is 1 for pointer to energy of threshold
                                               ! 2 is highest energy for shell
                                               ! 3 is opacity offset


    integer, allocatable :: dustScaXsecP(:,:)       ! pointer to dust scatterring x-sec in xSecArray (species,size)
    integer, allocatable :: dustAbsXsecP(:,:)       ! pointer to dust absorption x-sec in xSecArray  (species,size)



    integer, dimension(nHlevel+1) &
         & :: HlevNuP = 0      ! pointer to the nth H level in nuArray

    integer, dimension(nHeIlevel+1) &
         & :: HeIlevNuP = 0    ! pointer to the nth HeI level in nuArray


    integer, dimension(nHeIIlevel+1) &
         & :: HeIIlevNuP = 0   ! pointer to the nth HeII level in nuArray


    logical, allocatable :: &
         & lgDataAvailable(:,:)! is the atomic data available for this species?

    character(len=50), dimension(3:nElements, 1:10) :: &
         & dataFile       ! name of the file containing the atomic data for this species

    integer, dimension(nElements, nElements)&
         & :: nShells          ! number of shells for each element and ionization stage
                                               ! first dimension is atomic weight, second is ionization stage

    character(len=2)        :: elemLabel(30)


    ! energies temperatures etc..
    real :: Bjump = 0.                        ! Balmer jump


    ! slit stuff
    character(len=1) :: slitAxis = 'N'
    real :: d1Slit = 0.
    real :: d2Slit = 0.
    
    ! photoionization data
    real, dimension(5,30,30) :: CF=0.
    real, dimension(30,30)   :: cionTherm = 0.
    real, dimension(6, 30, 30, 7) :: ph1
    real, dimension(7, 30, 30) :: ph2
    real, dimension(nElements) :: aWeight
    real, dimension(450) :: ionEdge

    real, allocatable :: logGammaHI(:,:),logGammaHeI(:,:),logGammaHeII(:,:), tkGamma(:), nuGammaHI(:),&
         & nuGammaHeI(:),nuGammaHeII(:)

    ! dust arrays
    real, allocatable :: TdustSublime(:)        ! sublimation T (nspecies)
    real, allocatable :: grainVn(:)             ! potential of neutral grain
    real, allocatable :: MsurfAtom(:)           ! mass of surf atom of a grain [amu]
    real, allocatable :: rho(:)                 ! intrinsic density (nspecies)
    ! D-289. The neutral-grain photoelectric yield, tabulated once per
    ! (species, size, frequency). It does not depend on the grain potential -
    ! the Coulomb part is Yhat at the point of use - so it is built at setup
    ! and read by BOTH getGrainEmission (the charge balance) and
    ! setPhotoelHeatCool (the heating). One yield, one reality: the charge and
    ! the heating cannot run on different photoemission.
    real, allocatable :: grainYield(:,:,:)      ! (nSpecies, nSizes, nbins)
    ! Carbonaceous, from MsurfAtom in the grain's own data file (12.004 for
    ! graphite and amorphous carbon; 20-36 for the silicates and oxides),
    ! which selects WD01's carbonaceous or silicate bulk-yield fit.
    logical, allocatable :: grainCarb(:)        ! (nSpecies)
    real, allocatable :: dustHeatingBudget(:,:) ! heating budget of grains (nAbComponents, nResLines+1)
    real, allocatable :: SEDnoExt(:)            ! SED no extinction
    real, allocatable :: equivalentTau(:)       ! SED no extinction
    real, allocatable :: totalSpecMass(:)      ! Total dust species mass (nspecies)
    
    double precision, save, allocatable::&
          & forbiddenLines(:,:,:,:)                                 ! emissivity from heavies  rec lines
    double precision, save, allocatable::&
          & forbiddenLinesLarge(:,:)

    ! linear increments
    real, allocatable :: dl(:)

    ! calculate recombination lines?
    logical :: lgRecombination=.false.

    ! composition switches
    ! D-299: initialised. setComposition (called from initCartesianGrid) is
    ! what sets this, and makeElements reads it. With no initialiser its value
    ! before that was formally undefined, and D-292 read it - see D-299.
    logical, dimension(nElements) :: lgElementOn = .false. ! is this element present?

    ! dust arrays
    real, allocatable :: dustEmIntegral(:,:,:)   ! dust emission integral (species,size,temperature)

    ! allocatable arrays
    real, allocatable :: absOpacSpecies(:,:)     ! absOpacSpecies (nspecies, freq)

    real, allocatable :: continuum(:)            ! continuum array (freq)

    real, allocatable :: gauntFF(:)              ! gaunt factor

    real, allocatable :: gauntFFHeII(:)          ! gaunt ff for HeII

    real, allocatable :: H2phot(:)               ! H 2-photon emission

    real, allocatable :: HeI2phot(:)             ! HeI 2-photon emission

    real, allocatable :: HeII2phot(:)            ! HeII 2-photon emission

    real, allocatable :: ionDenUsed(:,:)         ! local ionDen array

    real, allocatable :: nuArray(:)              ! energy array [Ryd]

    real, allocatable :: xSecArray(:)            ! x Section array calculated in xSec_mod

    real, allocatable :: xSecRecoil(:)           ! compton recoil xSec

    real, allocatable :: comXSecH(:)             ! compton Xsec Heat array

    real, allocatable :: comXSecC(:)             ! compton Xsec Cool array

    real, allocatable :: widFlx(:)               ! widFlx array

    real, allocatable :: photoRateFluo(:,:)      ! photoionisation rate (nfluo, nstages) [sec^-1]


    integer, allocatable :: planeIonDistribution(:,:) ! initial distribution of ionising photons



    ! derived types

    type grid_type             ! derived grid type

        character(len=50) :: composition            ! chemical composition

        integer :: nx                               ! size of cartesian grid in x
        integer :: ny                               ! size of cartesian grid in y
        integer :: nz                               ! size of cartesian grid in z
        integer :: nCells                           ! number of active cells
        integer :: motherP                          ! pointer to the motherGrid

        integer, allocatable :: dustAbunIndex(:)        ! dust chemistry file index (cell)
        integer, allocatable :: abFileIndex(:,:,:)      ! abundance file index axxay
        integer, allocatable :: lgConverged(:)          ! has the model converged at this grid cell?
        ! D-155: x(H0) at the START of the MC iteration. The convergence test
        ! used the value at entry to updateCell, which with the D-119 coupling
        ! loop is the previous COUPLING PASS, not the previous iteration - so it
        ! measured the inner loop settling and reported 100% while x(H0) was
        ! still moving 81% between iterations.
        real, allocatable    :: xHIiterStart(:)
        ! D-173: the temperature this MC iteration started from, so the
        ! branch a cell sits on can be compared with the branch it sat on
        ! last iteration. Frozen (each cell picked a branch once and kept it)
        ! and flipping (cells swap every iteration) need different fixes:
        ! seeding selects an initial guess and only helps the frozen case.
        real, allocatable    :: TeIterStart(:)
        ! D-179: x(H2) at the start of the MC iteration. The convergence test
        ! needs it for the same reason Cloudy tests molecular columns: at the
        ! iteration the PDR switches on, H2 has not formed, so x(H0) still
        ! equals the converged photoionization answer and the test passes at
        ! 98% while the molecules are only starting to move.
        real, allocatable    :: xH2iterStart(:)
        ! D-188: has the chemistry ever run in this cell? Until it has, the
        ! cell is seeded from MOCASSIN's ionization state rather than from the
        ! network file's defaults.
        integer, allocatable :: pdrSeeded(:)
        ! D-348: what the diffuse-site walk reads per cell, snapshot once per
        ! MC iteration beside the source-ward columns (pdr_mod,
        ! snapDiffuseSources): (cell,1:3) shielding n(H2), n(C), n(CO), (cell,4)
        ! FUV extinction, (cell,5) FUV scattering emissivity. Replaces D-190's
        ! colRayH2/C/CO/AV, which the removed computeRayColumns filled.
        ! Declared unconditionally, NOT under #ifdef RAYTHEIA: PDRGEOMFLAG is
        ! not applied to common_mod's compilation, so a RAYTHEIA-guarded field
        ! here is invisible to the rest of the build (D-341). Allocated only
        ! in the 3D flavour, in pdr_mod, where the flag arrives.
        double precision, allocatable :: difSrc(:,:)
        integer, allocatable :: lgBlack(:)              ! is this to remain a black cell?

        integer, allocatable :: active(:,:,:)           ! point to active cell in 1d array;
                                                    ! returns 0 for inactive cells

        real    :: geoCorrX,geoCorrY,geoCorrZ       ! geometric correction
        real    :: noHit                            ! cells not sampled by rad field
        real    :: noIonBal                         ! Ion Balance not raeched
        real    :: noTeBal                          ! Te Balance not reached


        real, allocatable :: absOpac(:,:)               ! dust absorption opacity
        real, allocatable :: scaOpac(:,:)               ! dust scattering opacity
        real, allocatable :: dustPDF(:,:)               ! dust emission PDF
        real, allocatable :: fEscapeResPhotons(:,:)     ! frac of res line photons escaping (cell,resline)
                                                        ! D-376: every MC iteration, for every
                                                        ! dust+gas run
        real, allocatable :: fluorescenceCube(:,:,:)    ! escaped fluorescence packets (ncell,nFluo,nVP)
        real, allocatable :: Hden(:)                    ! density of H [1/cm^3]
        real, allocatable :: Ne(:)                      ! electron density [1/cm^3]
        real, allocatable :: Te(:)                      ! electron temperature [K]
        real, allocatable :: Tdust(:,:,:)               ! dust temperature (species,size,cell) [K]
        real, allocatable :: ionDen(:,:,:)              ! fractional ion density (x,y,z,elem,stage)
        real, allocatable :: Jste(:,:)                  ! MC estimator of stellar J (cell,nu)
        real, allocatable :: Jdif(:,:)                  ! MC estimator of diffuse J (cell,nu)
        real, allocatable :: JPEots(:,:)                ! OTS line contribution to photoelectric emission
        real, allocatable :: escapedPackets(:,:,:)      ! escaped packets (cell,nu, angle)
        real, allocatable :: linePackets(:,:)           ! line packets (x,y,z,n)
        real, allocatable :: LFluorescence(:,:)         ! local fluorescence luminosity of cell [e36 erg/sec]
        real, allocatable :: LdiffuseLoc(:)             ! loc luminosity of diffuse source [e36 erg/sec]
        real, allocatable :: Ndust(:)                   ! number density for dust

        real, allocatable :: xAxis(:)                   ! x-axis
        real, allocatable :: yAxis(:)                   ! y-axiss
        real, allocatable :: zAxis(:)                   ! z-axis

        real, allocatable :: NeInput(:)                 ! only used if lgNeInput=.t.


        real, allocatable :: opacity(:,:)               ! total  opacity (cell,nu) [1/cm]
        real, allocatable :: recPDF(:,:)                ! rec prob distribution function
        real, allocatable :: linePDF(:,:)               ! line prob distribution function
        real, allocatable :: totalLines(:)              ! fraction of non-ionizing line phots

        real, allocatable :: elemAbun(:,:)              ! elemental abundance (specified
                                                    ! by number relative to total
                                                    ! hydrogen density)
        real, allocatable :: echoVol(:,:,:)  ! BEKS 2010. Contains volume of one
        ! grid cell enclosed by echo.  Only used if lgEcho=.true.

        ! D-224. The 15.4-24.6 eV stellar path-length estimator, per cell, split
        ! by the step that deposited it: (cell,1) all, (cell,2) steps not inside
        ! the cell they were charged to, (cell,3) steps entering from a cell with
        ! tau per cell < 1 at that energy. D-225 adds (cell,4) the same
        ! estimator for EVERY packet in the band, stellar or diffuse - the
        ! closure against Jste - (cell,5) stellar interactions in the cell and
        ! (cell,6) stellar steps in the cell. Declared outside #ifdef PDR because
        ! photon_mod writes it in every flavour (the D-158 slip again); it is
        ! only allocated in the PDR build, and every write tests allocated().
        real, allocatable :: trcJ(:,:)
        ! D-232. Where a re-emitted packet's spectrum comes from, per cell,
        ! captured in setDiffusePDF before the terms are folded into recPDF:
        ! (cell,1) gas norm (HI+HeI+HeII), (cell,2) dust norm, (cell,3) the gas
        ! part above 13.6 eV, (cell,4) the dust part above 13.6 eV, (cell,5) the
        ! gas part above 24.6 eV, (cell,6) the dust part above 24.6 eV. Dust
        ! absorptions currently sample the pooled spectrum (photon_mod:1914), so
        ! this says how much of the ionizing diffuse field each side supplies.
        real, allocatable :: pdfSrc(:,:)

#ifdef PDR
        ! --- photodissociation-region state (DEVLOG D-006, D-018) -------------
        ! pdrAbun is double precision deliberately: PDR abundances run below
        ! 1e-38 and would underflow MOCASSIN's default 4-byte real.
        real, allocatable         :: chiFUV(:)       ! FUV field [Draine units]
        real, allocatable         :: chiFUV0(:)      ! UNATTENUATED FUV field [Draine units]
        real, allocatable         :: AVback(:)       ! A_V from this cell to the far boundary (D-061)
        real, allocatable         :: pdrColH2(:)     ! integrated N(H2) from the illuminated face (D-078)
        real, allocatable         :: pdrColC(:)      ! integrated N(C)  from the illuminated face (D-078)
        real, allocatable         :: pdrColCO(:)     ! integrated N(CO) from the illuminated face (D-078)
        real, allocatable         :: AVeff(:)        ! effective A_V from the MC field
        real, allocatable         :: dustAVfac(:)    ! A_V per N_H from THIS cell's grains (D-109)
        real, allocatable         :: dustRfuv(:)     ! tau_FUV/tau_V from THIS cell's grains (D-109)
        real, allocatable         :: dustSigSil(:)   ! GEOMETRIC grain area per H nucleus [cm^2/H]
        real, allocatable         :: dustSigGra(:)   ! of THIS cell's silicate / carbonaceous
                                                     ! grains, for H2 formation (D-195)
        real, allocatable         :: H2den(:)        ! n(H2) from the CHEMISTRY [cm^-3] (D-107),
                                                     ! for the H2 photoionization continuum above
                                                     ! 15.43 eV in addOpacity.
        real, allocatable         :: elemAvail(:,:)  ! (cell, element): the fraction of that
                                                     ! element NOT locked in molecules, and so
                                                     ! available to the atomic ion stages (D-102).
                                                     ! 1.0 everywhere the chemistry has not run.
        real, allocatable         :: pdrCool(:)      ! total PDR cooling [erg/s/cm^3]
        ! D-402 (was D-118's whole right-hand side, unused since D-193): the
        ! channels of each linked element's neutral/first-ion balance that
        ! only the network has, from the last solve, for ionBalance to carry
        ! too. Indexed (cell, pdrNchan*(e-1) + k) for linked element e:
        !   k = 1  X -> X+   specific rate [s^-1 per X]
        !   k = 2  X+ -> X   specific rate [s^-1 per X+]
        !   k = 3  X lost to anything else  [s^-1 per X]
        !   k = 4  X made from anything else [per atom of the element, s^-1]
        !   k = 5  X+ lost to anything else [s^-1 per X+]
        !   k = 6  X+ made from anything else [per atom of the element, s^-1]
        ! Photoionization, recombination, cosmic rays and charge transfer
        ! with H are not in these: ionBalance computes them itself.
        real, allocatable         :: pdrIonRate(:,:)
        ! D-404: the solver's own X+/X of each linked element at the end of
        ! the last solve of this cell (pdrStep), kept so that a later solve
        ! of ionBalance can be read against it. Each rank holds the cells it
        ! solves. -1 = not set.
        double precision, allocatable :: pdrSolIon(:,:)
        ! D-358: MOCASSIN's own rates for the linked neutrals, stored by
        ! ionBalance so the chemistry solve runs on them - the same rates in
        ! both solvers. Columns 1-5 are H, He, C, O, Mg: photoionization (and,
        ! for H, collisional ionization) [s^-1] and total recombination of
        ! the singly charged ion [cm^3 s^-1]. pdrPhotRate column 6 is
        ! H2 -> H2+ from the MC field and MOCASSIN's H2 cross section
        ! (yanH2xSec). -1 = not yet computed.
        real, allocatable         :: pdrPhotRate(:,:)
        real, allocatable         :: pdrAlphaRec(:,:)
        ! D-166. pdrCoolSp is a NUMBER, evaluated once per coupling pass. In
        ! iterateT it does not move when TeUsed moves - and in neutral gas it is
        ! the only coolant that matters, because every term MOCASSIN computes
        ! for itself is proportional to n_e. So H-C has no temperature
        ! dependence there and the solver can only run to a rail. Store the
        ! local power-law index d ln C / d ln T and the temperature it was
        ! measured at, so thermBalance can evaluate C(T) instead of reading C.
        real, allocatable         :: pdrCoolSlope(:) ! d ln(cool) / d ln(T)
        real, allocatable         :: pdrCoolTref(:)  ! T the coolants were solved at
        real, allocatable         :: pdrCoolSp(:,:)  ! per-coolant cooling [erg/s/cm^3] (D-096),
                                                     ! in the order pdrCoolants lists them
        ! D-362: the net escaping emission of each coolant transition
        ! [erg/s/cm^3], from a level-population solve at the cell's own
        ! temperature (the table of D-215 is at fixed temperatures), packed
        ! by pdrLnOff. Their sum over one coolant is that coolant's cooling
        ! at T. outputGas reports the atomic ones in lineFlux.out in place of
        ! MOCASSIN's electron-only C, C+ and O lines, and the molecular ones
        ! in lineFluxMol.out.
        real, allocatable         :: pdrLineEm(:,:)
        ! D-363: each coolant transition's escape probability from the same
        ! solve (1 where it is not solved). MOCASSIN's atoms take it for the
        ! transitions they share with the chemistry's.
        real, allocatable         :: pdrLineBeta(:,:)
        real, allocatable         :: pdrHeat(:)      ! total PDR heating [erg/s/cm^3]
        real, allocatable         :: pdrHeatPE(:)    ! grain photoelectric term alone
        ! D-131: the PDR heating MOCASSIN does not compute for itself, summed
        ! per cell. heat(12) is the PDR total, but MOCASSIN already has three of
        ! its terms - PAH photoelectric (heat 2) via photoelHeat_g, carbon
        ! photoionization (heat 4) in its own heatSte sum over ions, and
        ! gas-grain (heat 11) via gasDustColl_g. Handing the total across would
        ! double count all three. What is left, and genuinely absent from
        ! MOCASSIN, is H2 formation (5), H2 photodissociation (6), FUV pumping
        ! (7), cosmic-ray (8), turbulent (9) and chemical (10) heating.
        real, allocatable         :: pdrHeatXtra(:)
        ! D-207. What the PDR block ACTUALLY changed in the thermal balance,
        ! per H nucleus: heatInt and coolInt after it, minus before it. The
        ! arrays above are 3D-PDR's own totals, and most of what they hold
        ! never reaches MOCASSIN's balance - pdrHeatPE only as the grain
        ! photoelectric loss in the dust balance (D-093), and pdrHeat is the
        ! PDR total of which MOCASSIN computes three terms itself. Reporting
        ! those as "the heating" overstated it by an order of magnitude
        ! (D-207). These two are the substitution's net effect and nothing
        ! else, so a diagnostic built on them cannot drift from the budget.
        real, allocatable         :: pdrHeatUsed(:)
        real, allocatable         :: pdrCoolUsed(:)
        ! D-210. pdrCoolUsed is the NET effect and it goes negative, which
        ! means the substitution removes more of MOCASSIN's cooling than it
        ! puts back. Two mechanisms give that and they need different fixes:
        ! 3D-PDR's coolant is ZERO (D-167's case, guarded), or it is merely
        ! SMALLER than MOCASSIN's (unguarded, and silent). Splitting the net
        ! into the part removed and the number of coolants the guard saved
        ! decides which, since added = used + removed.
        real, allocatable         :: pdrCoolSub(:)   ! MOCASSIN cooling removed
        real, allocatable         :: pdrCoolNul(:)   ! coolants the guard kept
        ! D-213. `added` is pdrCoolSp TIMES the D-166 extrapolation factor
        ! (TeUsed/Tref)^slope, so a collapse in `added` is either the coolant
        ! or the extrapolation and the aggregate cannot tell them apart.
        ! pdrTfacUsed records the factor actually applied at the converged Te.
        real, allocatable         :: pdrTfacUsed(:)
        ! D-215. The cooling function itself, tabulated per cell per coolant
        ! on the fixed log-T grid pdrTabT, replacing D-166's two-point power
        ! law. Inside iterateT the abundances and partner densities are frozen
        ! and only T moves, so the coolant is a function of ONE variable and
        ! can be tabulated once per coupling pass and interpolated - never
        ! extrapolated. [erg/s/cm^3], same units as pdrCoolSp.
        real, allocatable         :: pdrCoolTab(:,:,:)
        ! D-217. MOCASSIN's OWN thermal budget, term by term, per H nucleus.
        ! Every PDR-side term has been instrumented (D-205..D-215) and the
        ! residual oscillation is now shown to start in the thermal solve on
        ! gas that is still molecular, with the PDR cooling adding cooling and
        ! the PDR heating ~1e-27 (D-216) - so what jumps is in MOCASSIN's half
        ! of the budget, which nothing reports.
        !
        ! (cell, slot, term). Slot 1 = the FIRST thermBalance call of the
        ! updateCell, i.e. at the iteration-start temperature with the NEW
        ! radiation field; slot 2 = the LAST call, the balance point. Terms:
        !   1 photoionization heating  2 photoelectric heating  3 PDR heating
        !   4 collisional cooling  5 recombination  6 free-free
        !   7 gas-dust collisional  8 PDR cooling (net substitution)
        !   9 heat - cool  10 the Te the balance was evaluated at
        ! Heating = 1+2+3 and cooling = 4+..+8 exactly, so 9 is their
        ! difference and the terms can be compared on one footing.
        real, allocatable         :: mocBud(:,:,:)
        ! D-218. The D-217 outcome group each cell fell in at the previous MC
        ! iteration (0 = none yet; 1 cold->hot, 2 stayed cold, 3 started hot).
        ! Iteration 7 showed the photoionization heating MOVING between cells:
        ! the 8336 that went hot at 6 enter 7 with 180x less of it, while 2835
        ! other cells take 25x more. Whether each iteration's flipping cells
        ! are drawn from the previous iteration's cold ones - a front advancing
        ! in pulses - is a question about the SAME cell across iterations, and
        ! group means cannot answer it without this.
        integer, allocatable      :: budGrpLast(:)
        ! D-221. H0 photoionization heating per H nucleus at the FIRST
        ! thermBalance call, split at 15.43 eV: (cell, 1) the 13.6-15.4 eV
        ! window where H2 has no continuum (D-139), (cell, 2) above it where
        ! H2 absorbs (addOpacity, yanH2xSec). D-218 found threshold opacity
        ! does not decide where the field lands, so the photons carrying the
        ! heating must sit where the gas is thinner - this says which band.
        real, allocatable         :: mocBand(:,:)          ! (cell, 7): 1-2 D-221, 3-7 D-222 by band
        ! D-285. Photoionization heating per H nucleus split by element, summed
        ! over that element's stages, at the same call that fills mocBud slot 2.
        ! D-284 left the deep PDR's budget resting on a group mean in which
        ! MOCASSIN's photoionization heating was two thirds of the total while
        ! Cloudy's was a few percent; a per-depth comparison needs the split,
        ! and the mean cannot say which absorber carries it.
        real, allocatable         :: mocHeatEl(:,:)        ! (cell, nElements)
        ! D-288. The photoelectric term decomposed, so O-02's remaining factor
        ! stops being inferred from the heating alone. D-287 could measure the
        ! FUV field and the charging PARAMETER psi on both sides, but not the
        ! grain potential itself, which is the quantity Cloudy prints (<Pot>
        ! 0.5-1.4 V) and the one the Coulomb suppression actually runs on.
        ! Accumulated in setPhotoelHeatCool over exactly its own integral, so
        !   heating per H = slot 4 * slot 2 * slot 3 * hcRyd
        ! holds identically. Slots (cell, 1:6):
        !   1 <V_g> [Ryd], weighted by absorbed photons above threshold
        !   2 <Y>, electrons per absorbed photon (yield AFTER Coulomb escape)
        !   3 <E> [Ryd], net energy carried per escaping electron
        !   4 absorbed photons per H per s, above threshold
        !   5 absorbed energy per H per s [erg], above threshold
        !   6 geometric grain area per H [cm^2]
        real, allocatable         :: mocGrain(:,:)         ! (cell, 6)
        ! D-222. Each gas absorber's share of the opacity the photons saw, at the
        ! representative bin of each hard band (cell, band 2-5 -> 1-4, absorber):
        ! 1 H2, 2 free-free, 3 H0, 4 He0, 5 He+, 6 heavier elements. Captured in
        ! addOpacity as successive differences of the running total, so the
        ! split is of the opacity actually built, not a recomputation of it.
        real, allocatable         :: opaRep(:,:,:)
                                                     ! > 0 when the dust is heating the gas
        ! Level populations for every coolant, packed end to end using
        ! pdrLevOff. Double precision: these span many orders of magnitude.
        double precision, allocatable :: pdrLevPop(:,:)
        double precision, allocatable :: pdrAbun(:,:)! (cell, species) fractional abundance
#endif
    end type grid_type

    ! photon packet type
    type photon_packet

        integer       :: nuP       ! pointer
        integer, dimension(2) &
             & :: xP,yP,zP         ! grids position indeces 1= mother 2=sub
        integer, dimension(2) :: origin ! 1=ig, 2=icell
        integer       :: iG        ! grid index

        real          :: nu
        real          :: weight    ! weight to be used in path streching
        
        logical       :: lgStellar
        logical       :: lgLine

        type(vector)  :: position
        type(vector)  :: direction


    end type photon_packet

    ! plot type
    type plot_type
       real, allocatable         :: intensity(:,:,:)
       real, allocatable         :: xAxis(:), yAxis(:)

       logical               :: lgFilter
       logical               :: lgMap
       logical, allocatable      :: lgLine(:)

       integer, allocatable      :: lineNumber(:)
       integer               :: nPlots
       integer, allocatable      :: nuP(:,:)

    end type plot_type

    type resLine_type
       character(len=2)      :: species
       character(len=30)     :: transition, multiplet! label

       integer               :: nuP  ! pointer to freq of line in nuArray
       integer               :: elem ! elemnt
       integer               :: ion  ! ionization stage
       integer               :: glow, ghigh ! lower and upper statistical weights
       integer               :: nmul ! # of components in the multiplet
       integer, allocatable       :: moclow(:), mochigh(:) ! mocassin's lower and higher levels code

       real                  :: m_ion ! mass of the ion
       real                  :: wav  ! wavelength [A]
       real                  :: freq ! frequency [Ryd]
       real                  :: Elow,Ehigh ! lower and higher level energies
       real                  :: Aik,fik ! trans prob and oscillator strength
    end type resLine_type

    !  model parameters

    type(vector), allocatable :: starPosition(:) ! ionising source(s) position
    type(vector)       :: nullUnitVector

    logical            :: lgCompton        ! evaluate Compton energy exchange?
    logical            :: lgAutoPackets    ! automatic increase of packets on the fly?
    logical            :: lgTalk           ! talk on?
    logical            :: lgDfile          ! use an external density file?
    logical            :: lgDebug          ! debigging mode? (memory consuming)
    logical            :: lgDlaw           ! use the density law routine?
    logical            :: lgDust           ! is dust included in this model?
    logical            :: lgDustScattering ! is dust scattering included in this model?
    logical            :: lgDustConstant   ! is the md/Mg constant throughtout the grid?
    logical            :: lgGas            ! is there any gas in teh grid?
    logical            :: lgHdenConstant   ! use the constant density parameters?
    logical            :: lgMdMg           ! dust to gas mass ratio used>?
    logical            :: lgMdMh           ! dust to hydrogen mass ratio used>?
    logical            :: lgOutput         ! output line fluxes,temp & ion struct files?
    logical            :: lgFrontLines = .false. ! D-382: sub-cell front [O I] estimate (lineFluxFront.out)
    logical            :: lg1D             ! 1-D switch
    logical            :: lgMultiDustChemistry ! do we have a inhomogeneous dust species distribution?
    logical            :: lgMultiChemistry ! do we have a chemically inhomogeneous gas?
    logical            :: lgNeutral        ! starting from neutral gas?
    logical            :: lgPlaneIonization! plane parallel ionization?
    logical            :: lgSymmetricXYZ   ! symmetric in x, y, and z?

    character(len=50)  :: gridList ! grid list file name
    character(len=50), allocatable  :: abundanceFIle(:) ! abundance file names
    character(len=50), allocatable  :: dustSpeciesFIle(:) ! abundance file names
    character(len=50)           :: contDiffuse      ! shape of the diffuse ionising spectrum
    character(len=50), allocatable  :: contShape(:)     ! continuumShape
    character(len=50), allocatable  :: contShapeIn(:)   ! continuumShape
    character(len=50), allocatable  :: spID(:)          ! input spectrum generator ID
    character(len=50)  :: densityFile      ! density file
    character(len=50)  :: dustFile(2)      ! dust files
    character(len=50)  :: MdMgFile         ! name of MdMg file
    character(len=50)  :: NdustFile        ! name of Ndust file
    character(len=50)  :: Qfile            ! name of Qfile
    character(len=30), allocatable       :: grainLabel(:)    ! name of this species

    integer, allocatable    :: viewPointPtheta(:), viewPointPphi(:)       ! viewing angles

    integer            :: nAngleBins=0     ! number of viewing angles for SED
    integer            :: TotAngleBinsTheta=20 ! total # of theta angle bins for SED
    integer            :: TotAngleBinsPhi=40 ! total # of phi angle bins for SED
    integer            :: nGrids           ! total number of grids to be used in the simulation
    integer            :: maxIterateMC     ! limit on number of MC iterations
    ! D-334: Monte Carlo seed control. Negative (the default) keeps the
    ! historical behaviour - energyPacketDriver perturbs the running generator
    ! state with the millisecond field of the wall clock, so no run can be
    ! repeated. Any value >= 0 replaces that with a deterministic stream built
    ! from the seed, the rank and the call number, which makes a run repeatable
    ! at fixed input AND fixed rank count. Set with the 'randomSeed' keyword.
    integer            :: randomSeed = -1  ! <0 = clock-seeded, >=0 = repeatable
    integer            :: nSeedCalls = 0   ! energyPacketDriver calls this rank has made
    integer(kind=int64):: maxPhotons       ! limit to packets to be use
    integer            :: nAbComponents=1  ! number of abundance components
    integer            :: nDustComponents=1 ! number of dust components
    integer, allocatable   :: dustComPoint(:)  !
    integer            :: nBins            ! number of energy bins
    integer            :: nElementsUsed    ! actual number of elements used
    integer(kind=int64), allocatable   :: nPhotons(:)      ! # of packets to be used in the sim
    integer(kind=int64):: nPhotonsTot      ! # of packets to be used in the sim
    integer            :: nPhotonsDiffuse  ! # of packets to be used by the diffuse ionisation source
    integer            :: nPhotonsDiffuseLoc! # of packets to be used by the diffuse ionisation source
    integer            :: nPacketsFluo     ! # of packets to be used for each fluorescent transition
    integer            :: nPacketsFluoLoc  ! # of packets to be used for each fluorescent trans in one cell
    integer, dimension(maxGrids) &
                      &:: nxIn,nyIn, nzIn  ! x, y and z dimensions of the grids
    integer            :: nStars           ! number of ionising sources
    integer            :: elementXref(nElements) ! x reference index array for elements actually used
    integer            :: emittingGrid     ! grid emiting illuminating radiation [0 for all]
    integer, allocatable   :: starIndeces(:,:) ! (nstars, 3) 1=x; 2=y; 3=z, 4=gp
    integer            :: nstages          ! # of ionisation stages to be included

    real               :: fluoCubeMineV, fluoCubeMaxeV ! limits of the fluorescence cube band
    real               :: fillingFactor    ! filling factor epsilon
    real               :: contCube(2)      ! continuum cube
    real               :: convIncPercent   ! percentage by  which conv must increase
    real               :: convWriteGrid    ! min conv level before starting to write the grid
    real               :: nPhotIncrease    ! nPhoton increase factor
    real               :: densityLaw(3)    ! density law parameters (R1,n,f,N0)
    real, allocatable       :: grainAbun(:,:)     ! abundance of this species
    real, allocatable       :: grainRadius(:)   ! grain radius [um]
    real, allocatable       :: componentMinRadius(:,:)   ! grain minimum radius [um] for species
    real, allocatable       :: componentMaxRadius(:,:)   ! grain maximum radius [um] for species
    real, allocatable       :: grainWeight(:)   ! grain weight normalised to 1
    real, allocatable       :: viewPointTheta(:),viewPointPhi(:)     ! viewing angles
    real               :: Hdensity         ! constant H density values (cm-^3)
    real               :: H0Start          ! initial guess at X(H0) for regions I and II
    real               :: Lphot            ! L of ionizing source [e36 phot/sec]
    real               :: Ldiffuse         ! total luminosity of diffuse source [e36 erg/sec]
    real, allocatable       :: LStar(:)         ! L of ionizing source [e36 erg/sec]
    real               :: meanField        ! mean ionizing field to be used with plane parallel
                                           ! geometry [erg/sec/cm^2]
    real               :: meanFieldin
    real               :: minConvergence   ! % of cells passing; reported, no longer stops a run (D-392)
    real               :: minConvQHeat     ! min convergence level for Qheat routines to run
    real               :: NeStart          ! initial guess at Ne
    real               :: MdMgValue        ! dust-to-gas ratio by mass
    real               :: NdustValue       ! dust number density [cm^-3]
    real               :: nuMax            ! max nu limit [Ryd]
    real               :: nuMin            ! min nu limit [Ryd]
    real               :: nuStepSize       !
    real               :: resLinesTransfer ! D-376: selects nothing - kept only so the
                                           ! grid checkpoint keeps its format
    real               :: Rnx,Rny,Rnz      ! edges [cm]
    real               :: R_in             ! inner radius [cm]
    real               :: R_out            ! outer radius [cm]
    real               :: SEDfreq(2)       !
    real               :: TeStart          ! initial guess at Te for regions I and II
    real, allocatable      :: deltaE(:)        ! energy carried by a single photon
    real               :: Tdiffuse         ! energy of diffuse ionising source [K]
    real, allocatable      :: Tstellar(:)      ! T of ionizing source [K]
    real, allocatable      :: tStep(:)         ! time step for sb99 inputs [yrs]
    real               :: XHILimit         ! convergence limit on X(HI)

    ! ---------------------------------------------------------------- D-391
    ! Iteration-level convergence on quantities integrated over the model.
    ! The per-cell test (XHILimit, iterateT) counts CELLS, so a zone that is
    ! 1% of the grid cannot hold a run open - pn150k's ionized gas is 449 of
    ! 35,384 cells, its He2+ zone ~90 - and it compares each iteration with
    ! the one before, so a drift under XHILimit per iteration passes for ever:
    ! He II 4686 rose 16% over pn150k's iterations 9-14 at ~3% each, with 92%
    ! of the cells passing throughout (DEVLOG-H2 H-015). These quantities sum
    ! over the whole model and are tested over cvTotK iterations:
    !   - the emission measure, n_e n_i dV, of every ION stage carrying at
    !     least cvTotSig of its element's. n_e puts the weight where the lines
    !     are made; it leaves out the deep PDR's trace ions, whose totals swing
    !     2-6% with the deep carbon state (measured, runs/d391-cv-hii31);
    !   - the H0 content, and in PDR flavours the H2 and CO contents, n dV;
    !   - the gas temperature weighted by n_e n(H+), by n(H0) and by n(H2).
    ! Converged when the largest |q_n / q_(n-cvTotK) - 1| is at most
    ! convTotals. D-392: that alone stops the run (the user: "I want the new
    ! test to decide when to stop"); minConvergence is reported against.
    real               :: convTotals = 0.02
    real, parameter    :: cvTotSig   = 0.01
    integer, parameter :: cvTotK     = 3
    integer            :: cvTotNq    = 0          ! quantities defined
    integer            :: cvTotNit   = 0          ! iterations stored, up to cvTotK+1
    real(kind=8), allocatable :: cvTotHist(:,:)   ! (quantity, 0:cvTotK), 0 = this iteration
    character(len=8), allocatable :: cvTotName(:)
    logical            :: lgCvTotals = .false.
    real               :: cvTotWorst = -1.        ! largest change over the window
    character(len=8)   :: cvTotWorstName = ''

    integer             :: lymanP                  ! frequency pointer to Lyman limit
#ifdef PDR
    integer             :: FUVlowP                 ! first nuArray bin inside the FUV band
    integer             :: FUVhighP                ! last  nuArray bin inside the FUV band
    integer             :: VbandP                   ! nuArray bin nearest Johnson V
    real                :: pdrRfuv    = 0.          ! measured tau_FUV/tau_V of the dust
    integer             :: pdrNstuck  = 0           ! cells whose chemistry did not advance
    integer             :: pdrNbadPop = 0           ! level-population solves rejected (D-041)
    double precision    :: pdrNspecFloor = 1.d-25   ! coolant abundance below which it is skipped
    integer             :: pdrNlevTot = 0           ! total coolant levels, summed over coolants
    integer             :: pdrMaxLev  = 1           ! largest cnlev over the coolants
    integer             :: pdrLevOff(30) = 0        ! offset of each coolant in pdrLevPop
    ! D-362: every coolant's radiative transitions (A_ij > 0), packed end to
    ! end per coolant in escape_probability's order (upper level outer, lower
    ! inner), so pdrLineEm can be sliced like pdrLevPop. Built in
    ! initPDRnetwork from the coolant data themselves.
    integer             :: pdrNln = 0               ! transitions, all coolants
    integer             :: pdrLnOff(30) = 0         ! offset of each coolant's first
    integer             :: pdrLnN(30)   = 0         ! and its count
    integer, allocatable          :: pdrLnUp(:), pdrLnLo(:)  ! levels, the coolant's own numbering
    double precision, allocatable :: pdrLnWav(:)    ! vacuum wavelength [Angstrom]
    double precision, allocatable :: pdrLvE(:)      ! level energy [cm^-1], packed as pdrLevPop
    ! D-362: pdrLineEm holds a solve - set by the first pdrStep sweep, or by
    ! resetGrid reading output/pdrLineEm.out. Until then outputGas keeps
    ! MOCASSIN's own C, C+ and O lines, and says so.
    logical             :: lgPdrLineEm = .false.
    ! ---------------------------------------------------------------- D-363
    ! ONE ATOM PER ION. C I, C II and O I are solved by MOCASSIN's own atoms
    ! (CHIANTI levels and electron rates), which also take the chemistry's
    ! rates for the colliders MOCASSIN has no data for - H, H+, He, H2 - and
    ! the chemistry's escape probability for each transition the chemistry's
    ! atom has. One solve serves the thermal balance at every trial T, the
    ! diffuse line emission and lineFlux.out.
    !
    ! pdr_atom_coll: one atomic coolant's collision tables as the chemistry
    ! read them, in ITS level numbering. Partners are numbered as 3D-PDR does:
    ! 1 H2, 2 p-H2, 3 o-H2, 4 e- (not used: MOCASSIN's own), 5 H, 6 He, 7 H+.
    ! kDown(p,u,l,it) is the u -> l rate coefficient [cm^3/s] at tempK(p,it);
    ! tempK(p,1) = 0 means the file has no such partner.
    type pdr_atom_coll
       integer :: nlev = 0, ntemp = 0
       double precision, allocatable :: tempK(:,:)
       double precision, allocatable :: kDown(:,:,:,:)
    end type pdr_atom_coll
    type(pdr_atom_coll) :: pdrAtomColl(30)
    ! the map onto MOCASSIN's atoms, built once its atomic data are loaded:
    ! pdrAtomOf(elem,ion) is the coolant solving that ion (0: none);
    ! pdrLvMap(ik,lc) is MOCASSIN's level for the chemistry's level lc
    logical             :: lgPdrAtomMap = .false.
    integer             :: pdrAtomOf(30,10) = 0
    integer             :: pdrLvMap(30,17) = 0
    ! the cell the line solver is working on: set by each caller of forLines,
    ! cleared after. collCellP = 0 means no neutral colliders and no escape
    ! probabilities - plain MOCASSIN, or a call with no cell behind it.
    integer             :: collCellP = 0
    double precision    :: collDen(7) = 0.d0          ! per partner [cm^-3]; H2 in 1
    double precision, allocatable :: collBeta(:)      ! per coolant transition

    ! --- PDR module controls (DEVLOG D-022) ------------------------------------
    ! Defaults reproduce 3D-PDR's shipped params.dat so an unspecified run is
    ! the documented reference case rather than an arbitrary one.
    logical             :: lgPDR      = .false.    ! master switch ('pdr' keyword)
    character(len=20)   :: pdrNetwork = 'reduced'  ! validated against compiled-in network
    character(len=200)  :: pdrDataDir = ''         ! '' -> PREFIX/share/mocassin/dataPDR
    integer             :: pdrNspec   = 0          ! species in the network
    integer             :: pdrNreac   = 0          ! reactions in the network
    integer             :: pdrStartIter=1          ! let MOCASSIN converge this many MC iterations first (D-062)
    ! D-393: a warm start whose checkpoint carries PDR state continues it: the
    ! chemistry runs from the first resumed iteration and the molecules are not
    ! seeded again (resetGrid sets both from the checkpoint's lgPDRrestart).
    logical             :: lgPDRresumed = .false.
    integer             :: pdrLevIter=25           ! D-060: fixed-T level-population passes
    real                :: pdrLevTol=1.e-3         ! D-060: relative convergence on level populations
    integer             :: pdrDiagCool=0           ! D-060: dump per-coolant budget at the face
    integer             :: pdrNdiag=0              ! D-060 diagnostic line counter
    real                :: pdrZeta    = 1.0e-16    ! CR ionization rate [1/s]
    real                :: pdrEndTime = 1.0e7      ! chemistry integration span [yr]
    ! D-352: A_V per N_H, MEASURED from this model's grains by calibratePDRdust
    ! (D-055/D-109) - not an input. It is the fallback for a cell with no dust.
    real                :: pdrAVfac   = 0.
    real                :: pdrVturb   = 1.0        ! turbulent velocity [km/s]
    real                :: pdrTmin    = 1.0        ! floor gas temperature [K]
    real                :: pdrTmax    = 2.0e4      ! ceiling gas temperature [K]
    integer             :: pdrDiagRates = 0      ! 1: print the D-113 exported form/loss; 2: also output/pdrReacRates.out (D-356)
    real                :: pdrDiagAV  = 1.0        ! A_V at which to print them
    integer             :: pdrTrackCell = 0   ! D-150: follow this cell across iterations
    integer             :: nTrackHit = 0      ! D-152: cap on failing-cell reports
    integer             :: nBalProbe = 0   ! D-135 one-shot balance probe
    integer             :: nIonProbe = 0   ! D-138 per-ion heating probe
    integer             :: nOpacProbe = 0  ! D-143 opacity-vs-bin probe
    integer             :: iOpP           ! D-143 loop counter
    integer             :: pdrNcool   = 0          ! number of coolants
    ! D-131: which coolants MOCASSIN does NOT already compute for itself.
    ! thermBalance sums forbidden lines over every heavy element and ion for
    ! which there is CEL data, and data/ carries ci.dat, cii.dat, oi.dat and
    ! oii.dat - so C, C+, O and O+ are ALREADY in coolColl. Adding 3D-PDR's
    ! values for them would double count three of the four standard coolants.
    ! Only species MOCASSIN has no line data for - CO and the other molecules -
    ! may be added. Set in initPDR, printed there so the choice is visible.
    logical             :: pdrCoolIsMol(30) = .false.
    ! D-133: for an ATOMIC coolant, which MOCASSIN ion it corresponds to, so
    ! its forbidden-line contribution can be removed and 3D-PDR's used instead.
    ! MOCASSIN drives forLines with NeUsed alone; 3D-PDR carries seven collision
    ! partners (H, H+, e-, He, H2, para-H2, ortho-H2). In neutral gas the
    ! electron fraction is ~1e-4, so MOCASSIN's [C II] 158um and [O I] 63um are
    ! computed with a collider that barely contributes and it under-cools by
    ! orders of magnitude. Excluding 3D-PDR's version to avoid double counting
    ! is therefore formally right and physically wrong: whichever code has the
    ! correct excitation physics must own the term.
    integer             :: pdrCoolElem(30) = 0
    integer             :: pdrCoolIon(30)  = 0
    character(len=50)   :: pdrCoolant(30) = ''     ! coolant datafile names
#endif

    ! D-114 / crash fix state. These live OUTSIDE the PDR block on purpose:
    ! ionBalance and getGrainRecombination compile into EVERY flavour, so
    ! guarding them with #ifdef PDR breaks the plain build - which is exactly
    ! how it broke here first time round.
    ! D-117: ON. The matrix reproduces the chain to 2e-15 on V1 and 3e-8 on a
    ! nine-element 200 kK model, with the tail handled by the exact ratio
    ! recursion. It exists so the chemistry can inject per-ion-stage source and
    ! sink terms (D-111), which a product of ratios cannot represent.
    logical             :: lgIonMatrix = .true.  ! matrix ionBalance
    ! D-354: pdrCoupleIter (D-119's coupling passes) and pdrChemIter (D-008's
    ! chemistry rounds) are gone. D-123's ladder measured a loop that re-ran
    ! updateCell each pass; since D-216 the passes re-solved fixed inputs,
    ! and without D-078's column rescale they recompute the first to 4.6e-4.
    ! The linked (element, stage) pairs: which MOCASSIN ion each network species
    ! is. Set in initPDRnetwork once the species indices are known.
    integer, parameter  :: pdrNlink = 10
    integer             :: pdrLinkElem(pdrNlink) = 0
    integer             :: pdrLinkIon (pdrNlink) = 0
    integer             :: pdrLinkSpec(pdrNlink) = 0
    ! D-402: the linked elements, one per neutral/first-ion pair of the table
    ! above (slots 2e-1 and 2e): atomic number, and the two species. And how
    ! many atoms of each linked element every network species holds - zero
    ! for the element's own two carriers, so the sum over species is what
    ! its molecules hold. Built in initPDRnetwork from the species' names.
    integer, parameter  :: pdrNlinkEl = pdrNlink/2
    integer             :: pdrElZ(pdrNlinkEl) = 0, pdrElNeut(pdrNlinkEl) = 0, &
         &                 pdrElIon(pdrNlinkEl) = 0
    double precision, allocatable :: pdrMolAtoms(:,:)   ! (species, linked element)
    integer             :: pdrElOfZ(30) = 0             ! linked-element index of atomic number Z
    integer, parameter  :: pdrNchan = 6                 ! channels per element in pdrIonRate
    ! D-402: charge transfer of a linked element with hydrogen, X + H+ -> X+ + H
    ! (pdrCtDir +1) and X+ + H -> X + H+ (-1), from the network's own
    ! reactions, so ionBalance and the solve use one set of coefficients - as
    ! D-280 does for the cosmic rays. One entry per reaction, in file order;
    ! pdrCtDup is the network's temperature-range counter (0: one range).
    integer, parameter  :: pdrMaxCt = 32
    integer             :: pdrNct = 0
    integer             :: pdrCtEl(pdrMaxCt) = 0, pdrCtDir(pdrMaxCt) = 0, pdrCtDup(pdrMaxCt) = 0
    double precision    :: pdrCtAlpha(pdrMaxCt) = 0.d0, pdrCtBeta(pdrMaxCt) = 0.d0, &
         &                 pdrCtGamma(pdrMaxCt) = 0.d0, pdrCtTmin(pdrMaxCt) = 0.d0, &
         &                 pdrCtTmax(pdrMaxCt) = 0.d0
    ! D-403: one coefficient per reaction in both solvers, and for each
    ! reaction the fit made for the gas at hand. Where Kingdon & Ferland
    ! (1996) fitted the reaction for ionized gas, k = a t4^b (1 + c exp(d t4))
    ! with t4 = T/1e4 K, that fit is used inside its stated temperature range
    ! and the network's coefficient outside it; pdrCtKF(1:4,i) = a [cm^3 s^-1],
    ! b, c, d, and a = 0 means no such fit. Helium (He+ + H, 6,000-1e5 K) and
    ! magnesium (H+ + Mg, 5,000-30,000 K) have one. Oxygen has none here on
    ! purpose: the network's O+ + H and H+ + O are fits to Stancil et al.
    ! (1999) over 10-41,000 K and agree with the fits to the same tables that
    ! Cloudy uses to 0.89-1.04 and 0.97-1.33 from 30 to 25,000 K, where
    ! Kingdon & Ferland's is 0.36-0.55 of them above 8,000 K (D-403).
    ! pdrCtReac is the reaction's row in the rate file, so the solve can be
    ! handed the same number (pdrStep); pdrHeEl is helium's linked-element
    ! index, for hydrogen's side of He+ + H in ionBalance.
    double precision    :: pdrCtKF(4,pdrMaxCt) = 0.d0, pdrCtKFTmin(pdrMaxCt) = 0.d0, &
         &                 pdrCtKFTmax(pdrMaxCt) = 0.d0
    integer             :: pdrCtReac(pdrMaxCt) = 0
    integer             :: pdrHeEl = 0
    ! D-280: cosmic-ray ionization of every linked neutral, read from the
    ! network's own reactions (CRP direct, CRPHOT through cosmic-ray-induced
    ! photons) so MOCASSIN and the chemistry ionize with identical coefficients.
    ! One entry per reaction: element, type (1 CRP, 2 CRPHOT), alpha, beta, gamma.
    integer, parameter  :: pdrMaxCr = 16
    integer             :: pdrNcr = 0
    integer             :: pdrCrElem(pdrMaxCr) = 0, pdrCrType(pdrMaxCr) = 0
    double precision    :: pdrCrAlpha(pdrMaxCr) = 0.d0, pdrCrBeta(pdrMaxCr) = 0.d0, &
         &                 pdrCrGamma(pdrMaxCr) = 0.d0
    ! Stage-trimming threshold, as a fraction of the most populated stage.
    ! Cloudy's equivalent (ionbal.trimlo) is 1e-10 of the element; 1e-12 here
    ! keeps a little more of the tail while still bounding the system to twelve
    ! decades, which double precision resolves with four digits to spare.
    real(kind=8)        :: ionTrim = 1.d-8
    integer             :: nIonDump = 0
    ! D-116: one-shot audit of zero total recombination coefficients
    logical             :: lgAlphaAudit   = .true.
    logical             :: lgAlphaAudited = .false.
    logical             :: lgDnAudited    = .false.
    ! D-114 self-check: worst relative difference between the matrix answer and
    ! the chain answer, accumulated IN THE SAME CELL of the SAME run so no MC
    ! feedback can contaminate the comparison. Two separate runs cannot settle
    ! this - a solver difference changes the opacity and amplifies.
    real(kind=8)        :: ionMatMaxDiff = 0.
    integer             :: ionMatWorstEl = 0, ionMatWorstIon = 0
    real(kind=8)        :: ionMatWorstA = 0., ionMatWorstB = 0.
    integer             :: ionMatNegChain = 0   ! chain returned a negative fraction
    ! An unthrottled NaN warning wrote 38.5 million lines and a 3 GB log into a
    ! tmpfs overnight - i.e. into RAM - and took the machine down. The warning
    ! is worth keeping (it detects a NaN nothing else catches) but it has to be
    ! bounded. Cap the prints and report the total once.
    ! D-158: mirror diffuse packets into Jdif as a diagnostic. Declared OUTSIDE
    ! the #ifdef PDR block because photon_mod, which reads it, compiles in both
    ! flavours - the sixth time in this project that a PDR-scoped declaration
    ! has broken the plain build (D-096, D-109, D-119, D-138, D-143).
    integer             :: pdrSplitField = 0
    ! D-348: Jdif is physics now, not only a diagnostic - the 3D build's
    ! diffuse FUV rays take their magnitude from it (pdr_mod, pdrStep) - so it
    ! is mirrored, reset and reduced in every PDR run as well as under
    ! pdrSplitField. Derived once in readInput; not an input. Declared here,
    ! outside #ifdef PDR, for the reason given above.
    logical             :: lgJdifLive = .false.
    integer             :: nXProbe = 0     ! D-159: surviving-packet probe
    ! D-224: transport consistency trace, summed over ranks after the transfer.
    ! 1 steps, 2 starting outside the cell they are charged to, 3 longer than
    ! the chord to that cell's far wall, 4 total path, 5 excess path, 6 wall
    ! distances replaced by the "cater for cells on cell wall" branch; 7-9 the
    ! same three for 15.4-24.6 eV stellar packets; 10 their interactions in
    ! cells with tau per cell > 20, 11-16 binned by the tau per cell of the cell
    ! crossed before (none, <0.1, 0.1-1, 1-10, 10-100, >=100), 17 previous step
    ! not inside its cell, 18 this step not inside its cell, 19 interaction
    ! point outside the cell, 20 previous cell in the PDR zone.
    real(kind=8)        :: trc224(20) = 0.d0
    ! D-165: instrument iterateT itself. Cloudy's temperature solver
    ! (conv_temp_eden_ioniz.cpp) brackets first, then runs Brent, and declares
    ! convergence only when BOTH |H-C|/H is small AND the bracket is narrow
    ! relative to Te - "this assures that the temperature is also well
    ! determined if H-C is a shallow function of T". MOCASSIN tests |H-C| alone,
    ! so where the thermostat is weak it accepts a temperature that is not
    ! pinned down. That is exactly the PDR regime. Record, per call: whether it
    ! converged, at what step, the residual, the bracket width, whether the
    ! +/-100 K stall breaker fired, and whether it exited on a clamp.
    ! Declared outside the #ifdef PDR block - iterateT compiles in both flavours.
    ! D-166/167/168/169. Declared OUTSIDE the #ifdef PDR block: set_input_mod
    ! and iteration_mod read them and both compile in either flavour. The
    ! SEVENTH time a PDR-scoped declaration has broken the plain build
    ! (D-096, D-109, D-119, D-138, D-143, D-158) - and the third caught only
    ! because the plain build is checked before anything reaches dev.
    ! D-198: ON by default. With MOCASSIN owning the thermal equilibrium and
    ! consuming the PDR's coolants, a cooling rate held CONSTANT inside
    ! iterateT leaves H-C with no temperature dependence in neutral gas and
    ! therefore no root. 1 = the two-point power law; 2 adds a third solve on
    ! the far side of Tref purely to check the extrapolation.
    ! D-215: the tabulation grid. 16 points log-spaced over [pdrTmin,pdrTmax]
    ! = [1, 2e4] K gives a spacing of x1.94, so the root finder interpolates
    ! over a factor of two at worst. D-166's power law was measured
    ! extrapolating over x9.3 with a multiplier reaching x420 (D-213).
    !
    ! Cost: 16 level-population solves per coolant per coupling pass against
    ! D-166's 2. That is 8x the level-population work per pass - but the same
    ! measurement that condemned the extrapolation also showed the coupling
    ! loop should run ONE pass, not five (D-214), so against the five-pass
    ! two-point configuration the total is comparable.
    integer             :: pdrNtab = 16
    real                :: pdrTabT(64) = 0.        ! filled by initPDRcoolTab
    ! D-222: bands above hydrogen's threshold, edged by physical thresholds -
    ! 13.6 eV (H0), 15.43 eV (H2 continuum), 24.59 eV (He0), 54.42 eV (He+) -
    ! with the band from He+ to the top of the grid split into two equal halves
    ! in log energy. bandP(k) is the first bin of band k, bandP(6) = nbins+1;
    ! bandRepP(k) the bin at the geometric centre of band k. Set once, by
    ! setHardBands, so the heating loop, addOpacity and the census agree.
    integer             :: bandP(6)    = 0
    integer             :: bandRepP(5) = 0
    integer             :: pdrNslopeChk = 0    ! D-166: cap on power-law checks
    integer(kind=8)     :: nCoolNull = 0       ! D-167: replacement with nothing to replace
    integer             :: nHotProbe = 0       ! D-168: budget at the 30000 K rail
    integer(kind=8)     :: teNhiNoPdr = 0      ! D-168: ceiling clamps with no PDR data yet
    integer             :: nRateProbe = 0      ! D-169: MOCASSIN vs chemistry H rates
    integer             :: nProbe234 = 0       ! D-234: ionization balance, every element
    ! D-238: composite biasing of the interaction depth (Baes et al. 2016,
    ! A&A 590, A55). Default off: it changes the sampling of EVERY model, not
    ! only PDRs, so it is validated on the fixtures before it becomes default.
    logical             :: lgPathStretch = .false.
    real                :: pathStretchXi = 0.5  ! the composite parameter xi
    ! D-239: what the packet weights actually do. D-238 left deep deposits at
    ! 1e-17 to 1e-35 where the physical field is ~2.7e-10, and the hypothesis is
    ! that enPacket%weight compounds across segments - bounded per draw by
    ! 1/xi, unbounded as a product. These measure it instead of assuming it.
    real(kind=8)        :: wgtMin239 = 1.d99, wgtMax239 = 0.d0
    real(kind=8)        :: wgtSum239 = 0.d0, wgtLogS239 = 0.d0
    real(kind=8)        :: wgtN239 = 0.d0, wgtKill239 = 0.d0, wgtSurv239 = 0.d0
    ! Russian roulette below this weight: the packet survives with probability
    ! w/wRoulette239 and is promoted to wRoulette239, so the estimator is
    ! unchanged in expectation and negligible packets stop costing time.
    real                :: wRoulette239 = 1.e-3
    ! D-236: one sampled cell per 0.5 mag of A_V, so the field can be read as a
    ! function of depth rather than at a single cell.
    logical             :: lgAVsamp234(0:15) = .false.
    ! D-243: one cell per 0.5 mag of A_V for the 19.82 eV He I 2^3S probe in
    ! setDiffusePDF. Separate from lgAVsamp234, which update_mod owns.
    logical             :: lgAVsamp243(0:15) = .false.
    integer             :: cellSamp234 = -1
    integer             :: nSolProbe = 0       ! D-169: what ionBalance wrote back
    ! D-170. Where do the convergence failures actually live? Cloudy judges
    ! ITERATION-level convergence (ConvIterCheck) on model-integrated
    ! quantities - outward Hbeta, Lya/Halpha optical depths, molecular column
    ! densities - each SIGNIFICANCE-GATED (`TauIn > 0.5`,
    ! `colden[i]/colden[HTOT] > 1e-5`) so a quantity too small to matter cannot
    ! block convergence, at a tolerance of autocv = 0.20. It also records WHY,
    ! in conv.chNotConverged.
    !
    ! MOCASSIN tests the relative change in x(H0) in every cell with no gate at
    ! XHILimit = 0.05, and reports a bare percentage. In a PDR x(H0) runs from
    ! ~1e-5 in the ionized zone, where the MC noise on a small number dominates
    ! the RELATIVE change, through 0.95 atomic to ~8e-3 molecular. Measure the
    ! distribution before changing the test.
    integer(kind=8)     :: cvN = 0, cvFail = 0
    integer(kind=8)     :: cvHist(12) = 0       ! log10 |dx/x|, -8..+3
    integer(kind=8)     :: cvFailByX(9) = 0     ! failures by log10 x(H0), -8..0
    integer(kind=8)     :: cvFailByAV(7) = 0    ! failures by A_V band
    integer(kind=8)     :: cvFailSmallX = 0     ! failures with x(H0) < 1e-3
    integer(kind=8)     :: cvPassGated = 0      ! would pass a Cloudy-style gate
    ! ------------------------------------------------------------------ D-248
    ! The same instrument for the TEMPERATURE. D-229 added Te to lgConverged
    ! and D-247 measured that it is the only test still failing at the plateau
    ! (x(H0) 2, x(H2) 0, Te 1895 at iteration 13) - but nothing recorded the
    ! DISTRIBUTION of the Te test statistic, so whether 1895 cells are moving
    ! or merely noisy could not be told apart. cvTeHist is |dTe/Te| binned
    ! exactly as cvHist bins |dx/x|, so the tolerance can be read against the
    ! distribution it is applied to rather than argued about.
    !
    ! cvTeFloorPass is the D-176..D-181 / D-191 question asked of Te: a cell
    ! clamped at teFloor cannot move, so it passes the test for free. D-165
    ! recorded 1864 such cells being counted as converged; this counts them.
    integer(kind=8)     :: cvTeHist(12) = 0     ! log10 |dTe/Te|, -8..+3
    integer(kind=8)     :: cvFailTeByAV(7) = 0  ! Te failures by A_V band
    integer(kind=8)     :: cvTeNear = 0         ! Te failures within 2x tolerance
    integer(kind=8)     :: cvTeFloorPass = 0    ! at teFloor AND passing the Te test
    integer(kind=8)     :: cvTeFloorN = 0       ! at teFloor, however they test
    ! D-172. Cloudy never reports a bare "not converged": conv.chNotConverged
    ! carries the reason, drChoice records which criterion set the zone
    ! thickness, and thermal.lgUnstable names a cell whose solution is on the
    ! unstable branch. MOCASSIN printed a percentage and nothing else, so every
    ! convergence discussion in this log has been an argument about a scalar.
    !
    ! cvNear/cvFar split the failures by how far past tolerance they are: a
    ! model sitting just outside XHILimit is a criterion question, one moving
    ! 100% per iteration is not. cvUnstable is Cloudy's lgUnstable test,
    ! d(H-C)/dT > 0 at the solution (its dCmHdT < 0, opposite sign convention).
    integer(kind=8)     :: cvNear = 0, cvFar = 0
    integer(kind=8)     :: cvHot2Cold = 0, cvCold2Hot = 0
    integer(kind=8)     :: cvStayHot = 0, cvStayCold = 0
    real                :: cvTsplit = 1000.   ! hot/cold boundary [K]
    ! D-174. Damping ACROSS MC iterations - the interval the convergence test
    ! actually measures (D-155). (The pass-to-pass pdrCoupleDamp it was paired
    ! with was an identity after D-216 and went at D-352.) D-173 measured
    ! 44-76% of cells crossing the 1000 K branch boundary EVERY iteration, in
    ! both directions at once: a limit cycle, not divergence. Damping a flip is
    ! the only thing in the code that can break one.
    !
    ! CONVENTION: the weight on the PREVIOUS iteration's value.
    !   Te = (1 - iterDamp)*Te_new + iterDamp*Te_previous
    ! so 0.25 mixes in a quarter of the old value. 0 disables.
    !
    ! D-406: the default is 0 (0.25 from D-174 to D-405; the user's
    ! decision). D-405 measured no cycle without it - hiipdr 31^3 and
    ! pn150k 41^3, cells cold -> hot 0-1 and 10-33 per iteration in either
    ! arm, histories independent draws - so what it damped was Monte Carlo
    ! noise. The written model was then a blend of solves rather than a
    ! solution (X+/X >10% from the solver's in 6-32% of neutral cells), it
    ! trailed by 3-6 iterations, and where a cell has two states it wrote
    ! states no solve gave (hiipdr's [C I] 370 um +11.6% over its own last
    ! solve). Kept as a keyword.
    real                :: iterDamp = 0.
    ! D-404: second solves of ionBalance (updateCell's ionPass) that did not
    ! reach the balance, on this rank, since last reported.
    integer             :: nIonPassFail = 0
    ! D-404: the last ionPass call solved its cell (it had a field to solve
    ! with), as opposed to leaving it as it was; and that solve reached the
    ! balance.
    logical             :: lgIonPassDone = .false., lgIonPassConv = .false.
    ! D-178. Cloudy decides ITERATION-level convergence on several
    ! independent, model-integrated quantities - the outward Hbeta fraction,
    ! the Lya/Halpha optical depths, and MOLECULAR COLUMN DENSITIES - each
    ! significance-gated and each recording which one failed
    ! (conv_itercheck.cpp, autocv = 0.20). MOCASSIN tests one composite
    ! per-cell number, x(H0) = 1 - x(H+) - 2x(H2), which is only incidentally
    ! molecular: at the iteration the PDR switches on, H2 has not formed yet,
    ! so x(H0) still equals the converged photoionization answer and the test
    ! passes at 98% while the molecules are only just starting to move.
    !
    ! Total content per species, summed over the model - the geometry-free
    ! analogue of Cloudy's column test. Reported per iteration as a relative
    ! change, so "which quantity has converged and which has not" is a
    ! measurement rather than an inference.
    ! Species indices, published by initPDRnetwork so iteration_mod can sum
    ! them: the chemistry_module names are private to pdr_mod.
    integer             :: pdrIdxH2 = 0, pdrIdxCO = 0, pdrIdxCp = 0, pdrIdxC = 0
    ! D-196: atomic and ionized hydrogen, so the chemistry's x(H+) can be
    ! compared against the ion solver's on the same per-nucleus basis.
    integer             :: pdrIdxH = 0, pdrIdxHp = 0
    ! D-179: include x(H2) in the convergence test when the PDR is on.
    !   cvUseH2  1 = require BOTH x(H0) and x(H2) to have settled (default)
    !            0 = x(H0) alone, the pre-D-179 behaviour
    !   cvH2floor  significance gate: below this molecular fraction the cell
    !            carries no molecules worth converging and the H2 test is not
    !            applied - Cloudy's colden[i]/colden[HTOT] > 1e-5 in spirit.
    !            Without it a cell going 1e-30 -> 1e-28 is a 100x "change".
    integer             :: cvUseH2   = 1
    real                :: cvH2floor = 1.e-5
    integer(kind=8)     :: cvFailH0 = 0, cvFailH2 = 0, cvFailBoth = 0
    integer(kind=8)     :: cvFailTe = 0   ! D-229: cells failing on Te
    ! D-230: the chemistry's electron abundance is imposed from MOCASSIN's Ne
    ! before the solve (pdr_mod, D-212) and frozen through it
    ! (calculate_abundances.c copies x_e in and back out untouched), yet the
    ! dumped value is 960-2500x MOCASSIN's Ne/Hden while the chemistry's own
    ! cations agree with it. Report both sides at the two points.
    integer             :: nProbe230 = 0, nProbe230b = 0
    integer, parameter  :: nCvSp = 8
    real(kind=8)        :: cvSpNow(nCvSp) = 0.d0, cvSpOld(nCvSp) = 0.d0
    character(len=6)    :: cvSpName(nCvSp) = &
         & (/ 'H0    ', 'H+    ', 'H2    ', 'CO    ', &
         &    'C+    ', 'C     ', 'e-    ', '<Te>  ' /)
    integer(kind=8)     :: cvUnstable = 0, cvDeriv = 0
    integer             :: teProbe = 0
    ! D-277 (O-11): which cells fail the ionization balance, and how. At the
    ! last MC iteration every cell whose X-iteration ends unconverged prints
    ! one line; the first ionBalProbe such cells per rank also print their
    ! last six steps. Diagnostic only.
    integer             :: ionBalProbe = 0, nIonBalTrail = 0
    ! D-280 (O-01): at the last MC iteration, the ionization and recombination
    ! rates of stage 1 -> 2 of element ionRateProbe (atomic number) in every
    ! cell, printed where each ionization balance ends. Diagnostic only.
    integer             :: ionRateProbe = 0
    ! D-165. Cloudy's temperature solver, for comparison with MOCASSIN's:
    !   * bracket with a step capped at 20% of T, then van Wijngaarden-Dekker-
    !     Brent INSIDE the bracket, which therefore always shrinks;
    !   * convergence needs |H-C|/H small AND the bracket narrow relative to Te,
    !     "this assures that the temperature is also well determined if H-C is a
    !     shallow function of T" (conv_temp_eden_ioniz.cpp, lgConvTemp);
    !   * on failure, restart the whole search up to five times with a growing
    !     iteration budget, explicitly to survive hysteresis in the ionization;
    !   * the low limit is 2.8 K - the CMB - and reaching it is a hard error
    !     with a diagnostic, not a silent clamp.
    ! MOCASSIN's search matches Cloudy on the 20% bracketing step and nothing
    ! else: plain regula falsi (one endpoint sticks, so the bracket stops
    ! shrinking), a convergence test on the residual alone, a stall breaker that
    ! adds +/-100 K - 1% of an H II region and 200% of a PDR - and resets the
    ! bracket, and a silent floor at 10 K.
    ! teSolver 1 selects the Cloudy-shaped search so the two can be compared in
    ! one build. teFloor exposes the floor, which has never been a parameter.
    ! D-403: the default is the CMB temperature, the one constant TcmbK that
    ! the chemistry's grain-temperature floor is also made from (pdr_mod). At
    ! 10 K the floor had come to decide the temperature of a tenth of hiipdr's
    ! cells (D-402), and a cell on the floor is flagged and left out of every
    ! line.
    double precision, parameter :: TcmbK = 2.725d0
    integer             :: teSolver = 0
    real                :: teFloor  = real(TcmbK)
    integer(kind=8)     :: teN = 0, teNconv = 0, teNstall = 0
    integer(kind=8)     :: teNloclamp = 0, teNhiclamp = 0, teNsteps = 0
    integer(kind=8)     :: teNwide = 0, teNnobrack = 0
    ! D-166: is H-C a function of T at all in this cell? grid%pdrCoolSp and
    ! grid%pdrHeatXtra are stored once per coupling pass, so they do not move
    ! when iterateT changes TeUsed - and in neutral gas every term that DOES
    ! move is proportional to n_e, which is ~1e-4. If the residual is flat the
    ! cell has no root and the solver can only run to a rail.
    integer(kind=8)     :: teNflat = 0, teNflatClamp = 0
    integer, parameter  :: teNbin = 12
    integer(kind=8)     :: teBrkHist(teNbin) = 0   ! log10 bracket width / Te
    ! D-160: the initial neutral-hydrogen fraction every cell starts from.
    ! It was hardcoded to 1.e-5 in two places in grid_mod, i.e. every model
    ! starts essentially fully ionized. If the coupled system is bistable
    ! (D-159) that hardcoded value silently selects the ionized branch.
    real                :: initH0 = 1.e-5
    integer             :: nInsaneEta = 0
    integer             :: nDustNaN = 0   ! D-120 one-shot probe
    ! D-122: the "all grains sublimed" hard stop is NOT driven by a NaN. The
    ! excursion is a finite but enormous dustAbsIntegral in one cell in one
    ! realisation, so a probe that only tests for non-finite values never
    ! trips. Report the first few cells whose grain temperature crosses the
    ! sublimation point, with the terms that built the integral.
    integer             :: nDustHot = 0
    integer, parameter  :: maxDustHot = 8
    ! D-121: first non-finite value seen anywhere in the coupled chain, with
    ! the stage that produced it. The NaN surfaces in pathSegment as "all
    ! grains sublimed", which is several steps downstream of wherever it is
    ! born; catching it at each hand-off localises the origin instead.
    character(len=48)   :: nanWhere = ""
    integer             :: nanCell = -1, nanIdx = -1
    logical             :: lgNanFound = .false.
    integer, parameter  :: maxInsaneEta = 20
    ! dust parameters
    integer            :: nSizes           ! number of grain sizes
    integer, allocatable    :: nSpeciesPart(:)  ! number of grain specie
    integer            :: nSpecies         ! number of grain specie
    integer            :: nSpeciesMax      ! max number of grain species
    integer            :: nResLines=0      ! number of resonant lines to be transfered

! CEL atomic data

    type atomic_data
        integer :: NTEMPS
        integer :: NLEVS
        integer :: irats
        character(len=50) :: ion
        real,allocatable :: logtemp(:)
        real,allocatable :: roott(:)
        character(len=20),allocatable :: label(:)
        integer,allocatable :: g(:) !statistical weight
        double precision,allocatable :: e(:) ! energy in wavenumbers
        double precision,allocatable :: a(:,:) !einstein A coefficient
        double precision,allocatable :: cs(:,:) !collision strength
        double precision,allocatable :: qeff(:,:)
        double precision,allocatable :: qom(:,:,:)
        real,allocatable :: qq(:),qq2(:)
        real :: a_r(4),a_d(5),z,br
        real,allocatable :: alphaTotal(:)
    end type atomic_data

    type(atomic_data), dimension(3:nElements, 1:10) :: atomic_data_array

! HeI2phot

    real, dimension(41) :: Ay_dat        ! data point in Ay (rates) [1/s]
    real, dimension(41) :: y_dat         ! data point in y (=nu/nu0)

! H I emissivity
! units are [e-25erg/s/N_gas]
    double precision, dimension(3:30, 2:8) :: HIRecLineData ! data
    double precision, dimension(3:30, 2:8) :: HIRecLines           ! emissivity from HI rec lines

! He II

    integer, parameter:: NHeIILyman = 4     ! Number of HeII Lym lines included
    real, dimension(NHeIILyman) :: HeIILymanData     ! HeII Lyman lines em.  [e-25ergs*cm^3/s]
    real, dimension(NHeIILyman) :: HeIILymanNu       ! HeII Lyman lines freq. [Ryd]
    double precision, dimension(3:30, 2:16) :: HeIIRecLineData ! HeII rec line data (Storey & Hummer 1995)
    double precision, dimension(3:30, 2:16) :: HeIIRecLines    ! emissivity from HeII rec lines

! dielectronic recombination

    type direcdata
        integer :: elem   ! atomic number
        integer :: n      ! number of electrons
        real :: a,b,c,d,f ! fitting coefficients
        integer :: g      ! temperature flag
    end type direcdata

    type(direcdata), dimension(25) :: direc_coeffs

    type aldropequidata
        integer :: elem   ! atomic number
        integer :: n      ! number of electrons
        real :: a,b,t0,t1 ! fitting coefficients
    end type aldropequidata

    type(aldropequidata), dimension(167) :: aldropequi_coeffs



contains

  !-----------------------------------------------------------------
  ! D-402, D-403: the coefficient [cm^3 s^-1] of each of the network's
  ! charge-transfer reactions of a linked element with hydrogen, at
  ! temperature T, as BOTH solvers use it: ionBalance sums the rows by
  ! element and direction (pdrCtRates), and pdrStep writes them into the
  ! solve's rate array, row by row.
  !
  ! The network's own value is alpha (T/300)^beta exp(-gamma/T), evaluated
  ! as calc_reac_rates.F90 evaluates a thermal reaction: where the network
  ! gives a reaction several temperature ranges, the first whose upper limit
  ! holds T, else the last, carries it and the other rows are zero; a
  ! negative gamma is held at the range's lower limit below it. Where the
  ! reaction has a fit made for ionized gas (pdrCtKF) and T is inside that
  ! fit's stated range, the fit replaces the network's value in the row that
  ! carries the reaction.
  !-----------------------------------------------------------------
  subroutine pdrCtCoef(T, k)
    implicit none
    double precision, intent(in)  :: T
    double precision, intent(out) :: k(pdrMaxCt)
    integer          :: i, j
    double precision :: tl, t4

    k = 0.d0
    i = 1
    do while (i <= pdrNct)
       j = i
       if (pdrCtDup(i) >= 1) then
          do
             if (T <= pdrCtTmax(j)) exit
             if (j == pdrNct) exit
             if (pdrCtDup(j+1) <= pdrCtDup(j)) exit
             j = j + 1
          end do
       end if
       if (.not.(pdrCtGamma(j) < -200.d0 .and. T < pdrCtTmin(j))) then
          tl = T
          if (pdrCtGamma(j) < 0.d0 .and. T < pdrCtTmin(j)) tl = pdrCtTmin(j)
          if (tl > 0.d0) k(j) = pdrCtAlpha(j)*(tl/300.d0)**pdrCtBeta(j)*exp(-pdrCtGamma(j)/tl)
       end if
       if (pdrCtKF(1,j) > 0.d0 .and. T >= pdrCtKFTmin(j) .and. T <= pdrCtKFTmax(j)) then
          t4 = T*1.d-4
          k(j) = pdrCtKF(1,j)*t4**pdrCtKF(2,j)*(1.d0 + pdrCtKF(3,j)*exp(pdrCtKF(4,j)*t4))
       end if
       ! on to the next reaction: past the rest of this one's ranges
       if (pdrCtDup(i) >= 1) then
          do while (i < pdrNct)
             if (pdrCtDup(i+1) <= pdrCtDup(i)) exit
             i = i + 1
          end do
       end if
       i = i + 1
    end do
  end subroutine pdrCtCoef

#ifdef PDR

  !-----------------------------------------------------------------
  ! One coolant, one cell, at an arbitrary temperature: log-log
  ! interpolation on the D-215 table. Volumetric, [erg/s/cm^3], the same
  ! units and meaning as pdrCoolSp.
  !-----------------------------------------------------------------
  double precision function pdrCoolAt(grid, cellP, iCool, T)
    implicit none
    type(grid_type), intent(in) :: grid
    integer,         intent(in) :: cellP, iCool
    real,            intent(in) :: T

    integer          :: i
    double precision :: f, c1, c2, t1, t2

    pdrCoolAt = 0.d0
    if (.not.allocated(grid%pdrCoolTab)) return
    if (iCool < 1 .or. iCool > pdrNcool) return

    ! clamped, not extrapolated - see the note on initPDRcoolTab
    if (T <= pdrTabT(1)) then
       pdrCoolAt = dble(grid%pdrCoolTab(cellP, iCool, 1));        return
    end if
    if (T >= pdrTabT(pdrNtab)) then
       pdrCoolAt = dble(grid%pdrCoolTab(cellP, iCool, pdrNtab));  return
    end if

    ! the grid is uniform in log T, so the bracket is arithmetic
    i = 1 + int(log(dble(T)/dble(pdrTabT(1))) &
         &      /log(dble(pdrTabT(pdrNtab))/dble(pdrTabT(1))) &
         &      *dble(pdrNtab-1))
    i = min(max(i, 1), pdrNtab-1)
    t1 = dble(pdrTabT(i)); t2 = dble(pdrTabT(i+1))
    c1 = dble(grid%pdrCoolTab(cellP, iCool, i))
    c2 = dble(grid%pdrCoolTab(cellP, iCool, i+1))
    f  = log(dble(T)/t1)/log(t2/t1)

    if (c1 > 0.d0 .and. c2 > 0.d0) then
       ! log-log: a fine-structure coolant is a power law in pieces, so
       ! this is exact where the two-point law was only ever a guess
       pdrCoolAt = exp((1.d0-f)*log(c1) + f*log(c2))
    else
       ! one end is zero (carrier destroyed at that T) - linear, which
       ! reaches zero honestly instead of taking log of it
       pdrCoolAt = (1.d0-f)*c1 + f*c2
    end if

  end function pdrCoolAt

  !-----------------------------------------------------------------
  ! D-363: map each atomic coolant's levels onto MOCASSIN's own atom for the
  ! same ion, by energy (the rule D-362 used): the nearest MOCASSIN level
  ! within 1e-3 of the energy (1 cm^-1 below 1000 cm^-1) and closer than a
  ! fifth of the distance to the second nearest, one-to-one. An ion that
  ! fails to map keeps MOCASSIN's electron-only atom, and says so.
  ! Called once MOCASSIN's atomic data are loaded.
  !-----------------------------------------------------------------
  subroutine buildPdrAtomMap()
    implicit none
    integer          :: ik, el, io, lc, lm, m1
    double precision :: e0, d, d1, d2
    logical          :: ok

    lgPdrAtomMap = .true.
    pdrAtomOf = 0
    pdrLvMap  = 0
    do ik = 1, pdrNcool
       if (pdrCoolIsMol(ik) .or. pdrCoolElem(ik) < 3) cycle
       el = pdrCoolElem(ik); io = pdrCoolIon(ik)
       if (el > nElements .or. io > 10) cycle
       if (.not.lgElementOn(el)) cycle
       if (.not.lgDataAvailable(el, io)) cycle
       if (pdrAtomColl(ik)%nlev <= 0 .or. pdrAtomColl(ik)%nlev > 17) cycle
       ok = .true.
       do lc = 1, pdrAtomColl(ik)%nlev
          e0 = pdrLvE(pdrLevOff(ik)+lc)
          d1 = huge(1.d0); d2 = huge(1.d0); m1 = 0
          do lm = 1, atomic_data_array(el,io)%nlevs
             d = abs(atomic_data_array(el,io)%e(lm) - e0)
             if (d < d1) then
                d2 = d1; d1 = d; m1 = lm
             else if (d < d2) then
                d2 = d
             end if
          end do
          if (m1 == 0 .or. d1 > 1.d-3*max(e0, 1000.d0) .or. d1 > 0.2d0*d2) ok = .false.
          if (ok .and. lc > 1) then
             if (any(pdrLvMap(ik,1:lc-1) == m1)) ok = .false.
          end if
          pdrLvMap(ik,lc) = m1
          if (taskid == 0) print '(a,i3,a,i3,a,i3,a,f12.3,a,i3,a,f12.3,a)', &
               & " ! [D363] elem", el, " stage", io, "  chemistry level", lc, &
               & "  E", e0, " cm-1  -> MOCASSIN's level", m1, " (", &
               & merge(atomic_data_array(el,io)%e(max(m1,1)), -1.d0, m1 > 0), ")"
       end do
       if (ok) then
          pdrAtomOf(el, io) = ik
          if (taskid == 0) print '(a,i3,a,i3,a)', " ! [D363] elem", el, " stage", io, &
               & ": MOCASSIN's atom takes the chemistry's H, H+, He, H2 rates and escape probabilities"
       else
          pdrLvMap(ik,:) = 0
          if (taskid == 0) print '(a,i3,a,i3,a)', " ! [D363] elem", el, " stage", io, &
               & ": levels do NOT map - MOCASSIN's electron-only atom is kept"
       end if
    end do
  end subroutine buildPdrAtomMap

  !-----------------------------------------------------------------
  ! D-363: the colliders and escape probabilities of cell cellP, for the
  ! next forLines. Densities are the ones the chemistry's own atoms use:
  ! H0 and H+ from MOCASSIN's ionization (which the chemistry imposes), He0
  ! likewise, H2 from the chemistry. ionDenCell is the caller's ionDenUsed.
  !-----------------------------------------------------------------
  subroutine setLineColliders(grid, cellP, ionDenCell, abunHe)
    implicit none
    type(grid_type), intent(in) :: grid
    integer,         intent(in) :: cellP
    real,            intent(in) :: ionDenCell(:,:)
    real,            intent(in) :: abunHe
    double precision :: nH

    collCellP = 0
    if (.not.lgPDR .or. cellP <= 0) return
    if (.not.lgPdrAtomMap) call buildPdrAtomMap()
    nH = dble(grid%Hden(cellP))
    collDen = 0.d0
    collDen(5) = nH*dble(ionDenCell(elementXref(1),1))                 ! H0
    collDen(7) = nH*dble(ionDenCell(elementXref(1),2))                 ! H+
    if (lgElementOn(2)) collDen(6) = nH*dble(abunHe)*dble(ionDenCell(elementXref(2),1))  ! He0
    if (allocated(grid%H2den)) collDen(1) = max(dble(grid%H2den(cellP)), 0.d0)       ! H2
    if (.not.allocated(collBeta)) allocate(collBeta(max(pdrNln,1)))
    collBeta = 1.d0
    if (allocated(grid%pdrLineBeta)) collBeta(1:max(pdrNln,1)) = &
         & dble(grid%pdrLineBeta(cellP, 1:max(pdrNln,1)))
    collCellP = cellP
  end subroutine setLineColliders

  !-----------------------------------------------------------------
  ! D-363: the neutral-collider rates for coolant ik at temperature T, onto
  ! MOCASSIN's levels: cN(from,to) [s^-1], both directions. The tables are
  ! interpolated as 3D-PDR's FIND_CCOEFF does - linear in T, held at the end
  ! values outside - and o/p-H2 split thermally as it does; the upward rate
  ! is detailed balance on MOCASSIN's own energies and weights.
  !-----------------------------------------------------------------
  subroutine pdrNeutralRates(ik, el, io, T, cN)
    implicit none
    integer,          intent(in)    :: ik, el, io
    double precision, intent(in)    :: T
    double precision, intent(inout) :: cN(:,:)
    integer          :: p, k, klo, khi, uc, lc, um, lm
    double precision :: step, fpara, den(7), kd

    fpara = 1.d0/(1.d0 + 9.d0*exp(-170.5d0/T))
    den = 0.d0
    den(1) = collDen(1)
    den(2) = collDen(1)*fpara
    den(3) = collDen(1)*(1.d0 - fpara)
    den(5) = collDen(5); den(6) = collDen(6); den(7) = collDen(7)
    do p = 1, 7
       if (p == 4) cycle                          ! electrons: MOCASSIN's own
       if (den(p) <= 0.d0) cycle
       if (pdrAtomColl(ik)%tempK(p,1) == 0.d0) cycle
       klo = 0; khi = 0
       do k = 1, pdrAtomColl(ik)%ntemp
          if (pdrAtomColl(ik)%tempK(p,k) > T) then
             klo = k-1; khi = k; exit
          else if (pdrAtomColl(ik)%tempK(p,k) == 0.d0) then
             klo = k-1; khi = k-1; exit
          end if
       end do
       if (khi == 0) then
          klo = pdrAtomColl(ik)%ntemp; khi = klo
       else if (khi == 1) then
          klo = 1; khi = 1
       end if
       if (klo == khi) then
          step = 0.d0
       else
          step = (T - pdrAtomColl(ik)%tempK(p,klo)) &
               & /(pdrAtomColl(ik)%tempK(p,khi) - pdrAtomColl(ik)%tempK(p,klo))
       end if
       do uc = 2, pdrAtomColl(ik)%nlev
          um = pdrLvMap(ik,uc)
          do lc = 1, uc-1
             lm = pdrLvMap(ik,lc)
             kd = pdrAtomColl(ik)%kDown(p,uc,lc,klo) + (pdrAtomColl(ik)%kDown(p,uc,lc,khi) &
                  & - pdrAtomColl(ik)%kDown(p,uc,lc,klo))*step
             if (kd <= 0.d0) cycle
             cN(um,lm) = cN(um,lm) + kd*den(p)
             cN(lm,um) = cN(lm,um) + kd*den(p) &
                  & *dble(atomic_data_array(el,io)%g(um))/dble(atomic_data_array(el,io)%g(lm)) &
                  & *exp(-(atomic_data_array(el,io)%e(um) - atomic_data_array(el,io)%e(lm)) &
                  &      *1.4388463d0/T)
          end do
       end do
    end do
  end subroutine pdrNeutralRates
#endif

  !-----------------------------------------------------------------
  ! D-222. The hard bands. Unguarded: thermBalance's heating loop, which
  ! reads them, compiles in every flavour.
  !-----------------------------------------------------------------
  subroutine setHardBands()
    implicit none
    integer :: i, k, nb, iHi
    real    :: eMid

    if (bandP(1) /= 0) return
    if (.not. allocated(nuArray)) return
    nb = size(nuArray)
    if (HlevNuP(1) <= 0 .or. HeIlevNuP(1) <= 0 .or. HeIIlevNuP(1) <= 0) return
    bandP(1) = HlevNuP(1)
    bandP(2) = nb + 1
    do i = 1, nb
       if (nuArray(i) >= 1.1345) then
          bandP(2) = i
          exit
       end if
    end do
    bandP(3) = HeIlevNuP(1)
    bandP(4) = HeIIlevNuP(1)
    eMid = sqrt(nuArray(bandP(4))*nuArray(nb))
    bandP(5) = nb
    do i = bandP(4), nb
       if (nuArray(i) >= eMid) then
          bandP(5) = i
          exit
       end if
    end do
    bandP(6) = nb + 1
    bandRepP(1) = bandP(1)
    do k = 2, 5
       iHi = max(bandP(k+1) - 1, bandP(k))
       eMid = sqrt(nuArray(bandP(k))*nuArray(iHi))
       bandRepP(k) = bandP(k)
       do i = bandP(k), iHi
          if (nuArray(i) >= eMid) then
             bandRepP(k) = i
             exit
          end if
       end do
    end do
  end subroutine setHardBands


end module common_mod
