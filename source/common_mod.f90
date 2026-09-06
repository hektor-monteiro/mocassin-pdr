! Copyright (C) 2005 Barbara Ercolano
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
    logical         :: lgResLinesFirst = .true. ! first time the res lines transfer proc is called?
    logical         :: lgPhotoelectric = .true. ! photoelectric effect on
    logical         :: lgQheat = .false.        ! temperature spiking on?
    logical         :: lgWritePss=.false.       ! write Pss for qHeat file?
    logical         :: lgTraceHeating = .false. ! trace thermal balance?
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
    logical, dimension(nElements) :: lgElementOn ! is this element present?

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
        integer, allocatable :: resLinePackets(:)       ! extraPackets to be generated cell (cell)
        integer, allocatable :: abFileIndex(:,:,:)      ! abundance file index axxay
        integer, allocatable :: lgConverged(:)          ! has the model converged at this grid cell?
        ! D-155: x(H0) at the START of the MC iteration. The convergence test
        ! used the value at entry to updateCell, which with the D-119 coupling
        ! loop is the previous COUPLING PASS, not the previous iteration - so it
        ! measured the inner loop settling and reported 100% while x(H0) was
        ! still moving 81% between iterations.
        real, allocatable    :: xHIiterStart(:)
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

#ifdef PDR
        ! --- photodissociation-region state (DEVLOG D-006, D-018) -------------
        ! pdrAbun is double precision deliberately: PDR abundances run below
        ! 1e-38 and would underflow MOCASSIN's default 4-byte real.
        integer, allocatable      :: pdrZone(:)      ! 1 where PDR chemistry runs
        real, allocatable         :: chiFUV(:)       ! FUV field [Draine units]
        real, allocatable         :: chiFUV0(:)      ! UNATTENUATED FUV field [Draine units]
        real, allocatable         :: AVback(:)       ! A_V from this cell to the far boundary (D-061)
        real, allocatable         :: pdrColH2(:)     ! integrated N(H2) from the illuminated face (D-078)
        real, allocatable         :: pdrColC(:)      ! integrated N(C)  from the illuminated face (D-078)
        real, allocatable         :: pdrColCO(:)     ! integrated N(CO) from the illuminated face (D-078)
        real, allocatable         :: AVeff(:)        ! effective A_V from the MC field
        real, allocatable         :: dustAVfac(:)    ! A_V per N_H from THIS cell's grains (D-109)
        real, allocatable         :: dustRfuv(:)     ! tau_FUV/tau_V from THIS cell's grains (D-109)
        real, allocatable         :: H2den(:)        ! n(H2) from the CHEMISTRY [cm^-3] (D-107),
                                                     ! for the H2 photoionization continuum above
                                                     ! 15.43 eV in addOpacity.
        real, allocatable         :: NePDR(:)        ! electron density from the CHEMISTRY [cm^-3]
                                                     ! (D-105). MOCASSIN's own sum over ion stages
                                                     ! collapses once carbon is locked in CO, and
                                                     ! it has no cosmic-ray ionization to hold a
                                                     ! floor, so Gamma/(Ne alpha) diverges.
        real, allocatable         :: elemAvail(:,:)  ! (cell, element): the fraction of that
                                                     ! element NOT locked in molecules, and so
                                                     ! available to the atomic ion stages (D-102).
                                                     ! 1.0 everywhere the chemistry has not run.
        real, allocatable         :: pdrCool(:)      ! total PDR cooling [erg/s/cm^3]
        ! D-118: the chemistry's formation and destruction rates for the ion
        ! stages MOCASSIN also tracks, published per cell so ionBalance can put
        ! them into its matrix. Indexed (cell, 1:2*pdrNlink) as
        ! form(1..n) then loss(1..n), one entry per linked (element, stage).
        real, allocatable         :: pdrIonRate(:,:)
        real, allocatable         :: pdrCoolSp(:,:)  ! per-coolant cooling [erg/s/cm^3] (D-096),
                                                     ! in the order pdrCoolants lists them
        real, allocatable         :: pdrHeat(:)      ! total PDR heating [erg/s/cm^3]
        real, allocatable         :: pdrHeatPE(:)    ! grain photoelectric term alone
        real, allocatable         :: pdrHeatGG(:)    ! gas-grain collisional term alone (D-093);
        ! D-131: the PDR heating MOCASSIN does not compute for itself, summed
        ! per cell. heat(12) is the PDR total, but MOCASSIN already has three of
        ! its terms - PAH photoelectric (heat 2) via photoelHeat_g, carbon
        ! photoionization (heat 4) in its own heatSte sum over ions, and
        ! gas-grain (heat 11) via gasDustColl_g. Handing the total across would
        ! double count all three. What is left, and genuinely absent from
        ! MOCASSIN, is H2 formation (5), H2 photodissociation (6), FUV pumping
        ! (7), cosmic-ray (8), turbulent (9) and chemical (10) heating.
        real, allocatable         :: pdrHeatXtra(:)
                                                     ! > 0 when the dust is heating the gas
        ! Level populations for every coolant, packed end to end using
        ! pdrLevOff. Double precision: these span many orders of magnitude.
        double precision, allocatable :: pdrLevPop(:,:)
        ! Thermal balance state, carried across MC iterations (DEVLOG D-031).
        ! One bracketing step per iteration; the outer loop converges it.
        real, allocatable         :: pdrTgas(:)      ! PDR gas temperature [K]
        real, allocatable         :: pdrTlow(:)      ! bracket, heating > cooling
        real, allocatable         :: pdrThigh(:)     ! bracket, cooling > heating
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
    real               :: minConvergence   ! stop when this level of convergence has been reached
    real               :: minConvQHeat     ! min convergence level for Qheat routines to run
    real               :: NeStart          ! initial guess at Ne
    real               :: MdMgValue        ! dust-to-gas ratio by mass
    real               :: NdustValue       ! dust number density [cm^-3]
    real               :: nuMax            ! max nu limit [Ryd]
    real               :: nuMin            ! min nu limit [Ryd]
    real               :: nuStepSize       !
    real               :: resLinesTransfer ! after what conv percent should the resonant line transfer start?
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

    ! --- PDR module controls (DEVLOG D-022) ------------------------------------
    ! Defaults reproduce 3D-PDR's shipped params.dat so an unspecified run is
    ! the documented reference case rather than an arbitrary one.
    logical             :: lgPDR      = .false.    ! master switch ('pdr' keyword)
    character(len=20)   :: pdrNetwork = 'reduced'  ! validated against compiled-in network
    character(len=200)  :: pdrDataDir = ''         ! '' -> PREFIX/share/mocassin/dataPDR
    integer             :: pdrNspec   = 0          ! species in the network
    integer             :: pdrNreac   = 0          ! reactions in the network
    integer             :: pdrHealpix = 0          ! HEALPix level of refinement
    integer             :: pdrChemIter= 3          ! chemistry passes per MC iteration (D-008)
    integer             :: pdrThermIter=12         ! thermal-balance steps per MC iteration (D-031, D-051)
    real                :: pdrTseed=300.           ! deterministic seed for the thermal march (D-051)
    integer             :: pdrStartIter=1          ! let MOCASSIN converge this many MC iterations first (D-062)
    integer             :: pdrLevIter=25           ! D-060: fixed-T level-population passes
    real                :: pdrLevTol=1.e-3         ! D-060: relative convergence on level populations
    integer             :: pdrDiagCool=0           ! D-060: dump per-coolant budget at the face
    integer             :: pdrNdiag=0              ! D-060 diagnostic line counter
    real                :: pdrFcrit   = 0.005       ! |heat-cool|/mean tolerated (3D-PDR params.dat, D-074)
    integer             :: pdrAtomicH = 1            ! D-107: hand back the true atomic H
                                                     ! fraction. Default 1 as of D-107: the H2
                                                     ! photoionization continuum removes the reason
                                                     ! this was held off (D-099/D-103/D-104).
    integer             :: pdrDustFeedback = 1       ! D-093: 1 = PDR rates drive the dust balance
    integer             :: pdrOwnDust  = 1           ! D-108: 1 = the H2/CO photorate shielding
                                                     ! uses THIS model's grains rather than the
                                                     ! Savage & Mathis 1979 table shipped with 3D-PDR
    integer             :: pdrUseNePDR = 0           ! D-105: 1 = ionBalance uses the chemistry's Ne
    integer             :: pdrOwnIon   = 1           ! D-106: ionBalance leaves the chemistry's
                                                     ! own elements alone in PDR cells. Default 1 as
                                                     ! of D-107, for the same reason as pdrAtomicH.
                                                     ! elements alone in PDR cells
    integer             :: nDustCapped = 0           ! D-093: grain-budget caps hit this iteration
    integer             :: pdrDustModel = 0          ! 0 = MOCASSIN only, 1 = max(MOCASSIN,HTT91), 2 = HTT91 only
                                                     ! D-094: default was 1 while Tdust(0,0) was
                                                     ! misread as ~1 K (D-092). With the readout
                                                     ! sound, max() only imposes HTT91's artificial
                                                     ! 10 K floor on a colder transported value.
    integer             :: pdrFUVmode = 0            ! 0 = transported MC field heats the gas,
                                                     ! 1 = 3D-PDR's prescribed chi0*exp(-UVfac*A_V) (D-089 diagnostic)
    integer             :: pdrSyncAbun = 1           ! rescale network elemental abundances to MOCASSIN's (D-039)
    real                :: pdrZeta    = 1.0e-16    ! CR ionization rate [1/s]
    real                :: pdrEndTime = 1.0e7      ! chemistry integration span [yr]
    real                :: pdrAVfac   = 6.289e-22  ! N_H -> A_V conversion
    real                :: pdrUVfac   = 3.02       ! FUV dust attenuation exponent
    real                :: pdrGrainRad= 1.0e-5     ! grain radius [cm]
    real                :: pdrMetal   = 1.0        ! metallicity
    real                :: pdrVturb   = 1.0        ! turbulent velocity [km/s]
    real                :: pdrTmin    = 1.0        ! floor gas temperature [K]
    real                :: pdrTmax    = 2.0e4      ! ceiling gas temperature [K]
    integer             :: pdrDiagRates = 0      ! print the D-113 exported form/loss
    real                :: pdrDiagAV  = 1.0        ! A_V at which to print them
    real                :: pdrZoneLim = 0.3        ! x(H+) below which PDR chemistry runs (TORUS-3DPDR, D-055)
    ! D-131: the two switches that remove the PDR barrier.
    !
    ! pdrAllCells - run the chemistry in EVERY cell instead of only where
    ! x(H+) < pdrZoneLim. Outside the traditional zone the network is solved at
    ! MOCASSIN's own electron temperature with the thermal bisection skipped,
    ! so H2 and CO are computed from the local field, density and temperature
    ! everywhere and fall to zero in ionized gas because the chemistry says so,
    ! not because the solver was never called there.
    !
    ! pdrCoolFeedback - add 3D-PDR's molecular line cooling to MOCASSIN's own
    ! thermal balance. MOCASSIN has no CO, C, C+ or O fine-structure coolant,
    ! which is the reason the PDR's temperature had to be handed back rather
    ! than MOCASSIN solving for it. With the coolant supplied, MOCASSIN's
    ! balance can own the temperature in molecular gas too.
    integer             :: pdrAllCells = 0
    integer             :: pdrTrackCell = 0   ! D-150: follow this cell across iterations
    integer             :: nTrackHit = 0      ! D-152: cap on failing-cell reports
    ! D-153. The self-consistent division of labour: MOCASSIN owns the
    ! ionization state and hands it TO the chemistry; the chemistry returns the
    ! molecular fractions MOCASSIN cannot compute. Nothing is blended, and there
    ! is no zone gate deciding whose answer to take.
    !
    ! The deadlock this removes (D-152): in cells at the ionization front the
    ! chemistry said x(H) = 0.999 while MOCASSIN's ionBalance said x(H+) = 0.97,
    ! and handBackPDR keys its blend weight on MOCASSIN's x(H+) - which was
    ! above pdrZoneLim, so the handback hit `cycle` and the chemistry's answer
    ! was never applied. Neither side moved and x(H0) never settled.
    integer             :: pdrIonFromMocassin = 0
    integer             :: pdrCoolFeedback = 0
    ! D-132: one thermal balance, and it is MOCASSIN's. The PDR stops solving
    ! for temperature entirely - it evaluates the chemistry, the level
    ! populations and its heating/cooling AT MOCASSIN's electron temperature and
    ! reports them back, and handBackPDR no longer overwrites Te. Requires
    ! pdrCoolFeedback, since without the molecular coolant and the six heating
    ! terms MOCASSIN has no way to reach a PDR temperature at all.
    integer             :: pdrTeFromMocassin = 0
    ! D-134/D-136: who owns the photoelectric heating inside the PDR. MOCASSIN
    ! computes it from its own grain population and grain charge (Baldwin et al.
    ! 1991); 3D-PDR uses a PAH formula. They differ by ~6x, and photoelectric
    ! heating is ~96% of the PDR's heating budget, so the choice sets the
    ! temperature outright.
    !
    ! THE ANSWER IS MOCASSIN'S, AND THIS STAYS OFF. The project's rule is that
    ! MOCASSIN owns the dust and everything that follows from it: its value is
    ! computed from the grains actually in the model, while 3D-PDR's assumes a
    ! PAH population this dust inventory does not contain. Wanting PAH physics
    ! means adding PAH particles to the dust composition, not importing a
    ! formula the grains cannot support.
    !
    ! Turning this on does not make the model more correct - it makes it agree
    ! with 3D-PDR. Since 3D-PDR is a reference and not a benchmark to
    ! reproduce, that is a diagnostic, not a goal. Kept solely to quantify the
    ! difference against the reference.
    integer             :: pdrPEfromPDR = 0
    integer             :: nBalProbe = 0   ! D-135 one-shot balance probe
    integer             :: nIonProbe = 0   ! D-138 per-ion heating probe
    integer             :: nOpacProbe = 0  ! D-143 opacity-vs-bin probe
    integer             :: iOpP           ! D-143 loop counter
    real                :: pdrBlendLo = 0.01       ! blend band lower edge in x(H+) (D-007)
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
    ! D-118: feed the chemistry's per-stage rates into the ion matrix, replacing
    ! elemAvail's scalar "this fraction is locked up" with "it is being locked
    ! up this fast and released that fast". Cloudy's ion_solver.cpp:765.
    logical             :: lgIonChemRates = .true.
    ! D-119: how many times to close the ionization <-> chemistry loop inside a
    ! single MC iteration. 1 reproduces the sequential behaviour exactly.
    ! Cloudy's equivalent lives in conv_base and needs damping plus oscillation
    ! detection, which is evidence that two solvers passing rates can chase
    ! each other rather than settle.
    !
    ! D-123 measured the ladder 1/3/5/7 on three fixtures. The loop converges:
    ! the change from 5 to 7 passes is 0.0009-0.0030 in front ratio against
    ! 0.108-0.451 from 1 to 3. It also collapses the between-fixture spread
    ! from 0.564 to 0.130 while leaving the mean error near 5% - i.e. it buys
    ! internal consistency, not accuracy, and at 1 pass the fixtures merely
    ! straddled the reference. 5 is converged at ~2.5-3x the cost of 1; 3 is
    ! within 2.2% of converged at ~40% of that cost.
    integer             :: pdrCoupleIter = 5
    real(kind=8)        :: pdrCoupleDamp = 0.5   ! Cloudy's 50% averaging
    real(kind=8)        :: pdrCoupleResid = 0.
    ! The linked (element, stage) pairs: which MOCASSIN ion each network species
    ! is. Set in initPDRnetwork once the species indices are known.
    integer, parameter  :: pdrNlink = 10
    integer             :: pdrLinkElem(pdrNlink) = 0
    integer             :: pdrLinkIon (pdrNlink) = 0
    integer             :: pdrLinkSpec(pdrNlink) = 0
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

end module common_mod
