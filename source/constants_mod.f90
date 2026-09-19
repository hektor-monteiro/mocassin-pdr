! Copyright (C) 2005 Barbara Ercolano
! Modified 2025-2026 by Hektor Monteiro for MOCASSIN-PDR; the changes are
! recorded in the git history and in DEVLOG.md.
! changed nStages from 6 to 9 for the modelling of higher energy ions (nw2006)
!
! Version 2.02
module constants_mod

    public

    ! physical constant
    real, parameter :: A0 = 6.30e-18               ! H0 phot x sec at the edge [cm^2]
    real, parameter :: amu = 1.66053e-24           ! [g]
    real, parameter :: c = 2.9979250e10            ! speed of light [cm/s]

#ifdef PDR
    ! --- FUV band and Draine field normalisation (DEVLOG D-001) ---------------
    ! The far-UV band conventionally used for PDR photorates, 912-2400 Angstrom,
    ! expressed in Rydbergs: 2400 A = 0.44066 Ryd, 912 A = 1.0 Ryd (Lyman limit).
    real, parameter :: nuFUVlo = 0.44066            ! 2400 A [Ryd]
    real, parameter :: nuFUVhi = 1.0                ! 912 A  [Ryd]
    ! D-280: the H2 Lyman-Werner band, 11.2-13.6 eV, where cosmic-ray-excited
    ! H2 emits the photons behind the CRPHOT reactions (Gredel et al. 1989).
    ! 11.2 eV / 13.6057 eV = 0.8232 Ryd.
    real, parameter :: nuLWlo = 0.8232              ! 11.2 eV [Ryd]
    ! Integrated FUV energy density of the Draine (1978) field, chi = 1.
    ! The Habing equivalent is 5.29e-14; their ratio, 1.69, is the 1.68 factor
    ! that 3D-PDR's heatingfunctions.F90 uses to convert Draine -> Habing.
    real, parameter :: uDraine = 8.94e-14           ! [erg/cm^3]
    ! Johnson V, 5500 A, for converting a measured FUV optical depth into a
    ! genuine visual extinction using MOCASSIN's own grain optics (D-026).
    real, parameter :: nuVband = 0.165738            ! 5500 A [Ryd]
    ! A_V[mag] = 2.5/ln(10) * tau_V
    real, parameter :: magPerTau = 1.0857362
#endif
    real, parameter :: fr1Ryd = 3.28984e15         ! frequency a 1 Ryd [Hz]
    real, parameter :: hPlanck = 6.6262e-27        ! Planck constant [erg s]
    real, parameter :: HIonPot = 0.99946           ! ionization potential of H [Ryd]
    real, parameter :: hnu3c2 = 0.524166
    real, parameter :: me = 9.109382e-28           ! mass of e- [g]
    real, parameter :: kBoltzmann = 1.380658e-16     ! Boltzmann constant
    real, parameter :: radio4p9GHz = 1.489434e-6     ! 4.9 GHz in Ryd
    real, parameter :: Ryd2erg = 2.1799e-11        ! converts ryd to erg
    real, parameter :: RydInf = 109737.315         ! Ryd for infinitme mass nuclei [1/cm]
    real, parameter :: sigma = 5.66956e-5          ! Stefan-Boltzmann constant [erg*cm^-2deg^-4s-1]
    real, parameter :: Te1Ryd = 1.578866e5         ! Te at 1 Ryd [K]
    ! Baldwin et al. (1991), ApJ 374, 580: the photoelectric yield
    ! Y = min(Y0*(1 - nu_0/nu), Y1). D-289 moved Y0 here from a duplicate
    ! declaration inside updateCell, so that ph_mod's yield table and the
    ! legacy branch it replaces read the same two numbers.
    real, parameter :: Y0 = 0.5
    real, parameter :: Y1 = 0.2
    real, parameter :: FeKaCold = 470.388          ![ryd] =6.4keV -> energy of Fe K alpha for cold iron

    ! numerical constants
    real, parameter :: rootThree = 1.732050808
    real, parameter :: kShellLimit = 7.35e4        ! high energy limit to code

    ! pi
    real, parameter :: pi = 3.141592654
    real, parameter :: twoPi = 2.*pi
    real, parameter :: fourPi = 4.*pi
    real, parameter :: piByFour = pi/4.
    real, parameter :: oneOnFourPi = 1./(4.*pi)
    real, parameter :: oneOnTwoPi = 1./(2.*pi)

    ! conversion factors
    real, parameter :: degToRad = pi/180.
    real, parameter :: RydToeV = 13.6056981
    real, parameter :: radToDeg = 180./pi

    ! hard limits
    integer, parameter :: maxGrids = 50000           ! limit to the number of grids to be used
    integer, parameter :: maxTau = 10000000         ! limit to the optical depth arrays
    integer, parameter :: nElements = 30            ! number of elements
    integer, parameter :: nForLevels = 17           ! number of levels
    integer, parameter :: nForLevelsLarge = 142     ! number of levels for FeII
    integer, parameter :: nHlevel =  10             ! number of levels in the H atom
    integer, parameter :: nHeIlevel = 9             ! number of levels in the HeI singlets
    integer, parameter :: nHeIIlevel = 9            ! number of levels in the HeII singlets
    integer, parameter :: NnuMax = 3000             ! limit to the possible number of energy bins (nbins)
    integer, parameter :: xSecMax = 1000000         ! max limit to xSecArray
    integer, parameter :: nTemps=3000
    integer, parameter :: recursionLimit=5000

    real, parameter :: xMax = 0.99999               ! max limit for a relative ionic abundance

end module constants_mod



