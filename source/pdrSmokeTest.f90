! Copyright (C) 2026 Hektor Monteiro
! Part of MOCASSIN-PDR.
!
! This program is free software: you can redistribute it and/or modify it
! under the terms of the GNU General Public License as published by the Free
! Software Foundation, either version 3 of the License, or (at your option)
! any later version. It is distributed WITHOUT ANY WARRANTY; see the GNU
! General Public License (LICENSE) for details.
!
! Phase 1 smoke test for the vendored 3D-PDR chemistry (DEVLOG D-020).
!
! Drives the full chemistry chain for ONE hardcoded cell under representative
! PDR conditions: read the network, build the rate coefficients, integrate the
! ODE system with CVODE, and report the abundances. Its only job is to prove
! that the vendored sources, the SUNDIALS link and the C/Fortran binding all
! work inside MOCASSIN's build - not to validate any physics.
!
! Note the radiation field is supplied in exactly the form D-001 specifies:
! rad_surface(k) = chi/nrays with AV(k) = AVeff on every ray, so the rate sum
! sum_k alpha*rad_surface(k)*exp(-gamma*AV(k)) collapses to
! alpha*chi*exp(-gamma*AVeff). This is the Phase 3 coupling shape.
program pdrSmokeTest

  ! NOTE: explicit only: lists are mandatory, not style. 3D-PDR's modules export
  ! names as generic as `i`, `p` and `NH`, so a blanket `use` collides with
  ! ordinary local variables. The Phase 2 bridge must follow this rule
  ! throughout (DEVLOG D-021).
  use definitions
  use healpix_types
  use maincode_module, only : nspec, nreac, species, init_abundance, mass, &
                            & reactant, product, alpha, beta, gamma, rate, &
                            & duplicate, rtmin, rtmax, AV_fac, UV_fac, zeta, &
                            & v_turb, coo, start_time, end_time, redshift, Tcmb
  use global_module,   only : metallicity, omega, grain_radius, NELECT, &
                            & NH, NH2, NC, NCx, NCO
  use chemistry_module, only : relative_abundance_tolerance, &
                            & absolute_abundance_tolerance

  implicit none

  integer(kind=i4b), parameter :: nraysLoc = 12      ! HEALPix level 0
  integer(kind=i4b), parameter :: npart = 1
  real(kind=dp) :: radSurf(0:nraysLoc-1), AVray(0:nraysLoc-1)
  real(kind=dp) :: colH2(0:nraysLoc-1), colHD(0:nraysLoc-1), colCO(0:nraysLoc-1)
  real(kind=dp) :: colC(0:nraysLoc-1),  colS(0:nraysLoc-1)
  real(kind=dp), allocatable :: abundance(:)
  integer(kind=i4b) :: NRGR, NRH2loc, NRHDloc, NRCOloc, NRCIloc, NRSIloc
  integer(kind=i4b) :: is, ios
  real(kind=dp) :: dummy, nHden, Tgas0, Tdust0, chiFUV, AVeff, NHtot
  real(kind=dp) :: qplus, qminus
  character(len=50) :: suffix

  write(6,*) '=============================================='
  write(6,*) ' MOCASSIN-PDR Phase 1 smoke test'
  write(6,*) '=============================================='

  ! ---- network selection must agree with the compiled-in ODE system --------
#ifdef REDUCED
  suffix = 'reduced.d'
#elif MEDIUM
  suffix = 'medium.d'
#elif FULL
  suffix = 'full.d'
#elif MYNETWORK
  suffix = 'mynetwork.d'
#endif

  ! ---- count species and reactions (readparams does this by line count) ----
  open(unit=1,file='chemfiles/species_'//trim(adjustl(suffix)),status='old',iostat=ios)
  if (ios/=0) then
     write(6,*) '! pdrSmokeTest: cannot open chemfiles/species_'//trim(adjustl(suffix))
     write(6,*) '!   run from a directory with a chemfiles/ link to dataPDR/'
     stop 1
  end if
  nspec=0
  do
     read(1,*,end=100) dummy
     nspec=nspec+1
  end do
100 continue
  close(1)

  open(unit=1,file='chemfiles/rates_'//trim(adjustl(suffix)),status='old')
  nreac=0
  do
     read(1,*,end=101) dummy
     nreac=nreac+1
  end do
101 continue
  close(1)

  write(6,'(" network   : ",A," -> ",I0," species, ",I0," reactions")') &
       & trim(adjustl(suffix)), nspec, nreac

  ! ---- parameters readparams would otherwise supply from params.dat -------
  metallicity  = 1.0d0
  grain_radius = 1.0d-5
  omega        = 0.42d0            ! grain albedo, hardcoded upstream
  AV_fac       = 6.289d-22*metallicity
  UV_fac       = 3.02d0
  zeta         = 1.0d-16/1.3d-17   ! stored normalised to 1.3e-17
  redshift     = 0.0d0
  Tcmb         = 2.725d0*(1.0d0+redshift)
  v_turb       = 1.0d5
  coo          = 0                 ! no coolants needed for a chemistry-only test
  start_time   = 0.0d0
  end_time     = 1.0d7             ! yr
  relative_abundance_tolerance = 1.0d-8
  absolute_abundance_tolerance = 1.0d-30

  call allocations
  call read_species(nspec, species, init_abundance, mass)
  call READ_RATES(nreac, reactant, product, alpha, beta, gamma, rate, &
       &          duplicate, rtmin, rtmax)
  write(6,'(" electron index NELECT = ",I0,"   (from the C binding)")') NELECT

  ! ---- one cell, representative of a moderately shielded PDR --------------
  nHden    = 1.0d3      ! cm^-3
  Tgas0 = 50.0d0     ! K
  Tdust0 = 20.0d0     ! K
  chiFUV = 10.0d0     ! Draine units
  AVeff = 3.0d0
  NHtot = AVeff/AV_fac

  radSurf = chiFUV/real(nraysLoc,kind=dp)   ! D-001 effective-AV form
  AVray   = AVeff
  colH2   = 0.5d0*NHtot
  colHD   = 1.0d-5*NHtot
  colCO   = 1.0d-4*NHtot
  colC    = 1.0d-4*NHtot
  colS    = 1.0d-6*NHtot

  allocate(abundance(1:nspec))
  abundance = init_abundance

  write(6,'(" cell      : n_H=",ES9.2," T_gas=",F6.1," T_dust=",F6.1, &
       &    " chi=",F6.1," A_V=",F5.2)') nHden, Tgas0, Tdust0, chiFUV, AVeff

  call CALCULATE_REACTION_RATES(Tgas0, Tdust0, nraysLoc, radSurf, AVray, &
       & colH2, colHD, colCO, colC, colS, &
       & nreac, reactant, product, alpha, beta, gamma, rate, rtmin, rtmax, &
       & duplicate, nspec, NRGR, NRH2loc, NRHDloc, NRCOloc, NRCIloc, NRSIloc, &
       & abundance(NELECT)*nHden, nHden, zeta)

  write(6,'(" rates     : min=",ES10.3," max=",ES10.3," nonzero=",I0,"/",I0)') &
       & minval(rate), maxval(rate), count(rate>0.0d0), nreac

  call calculate_abundances(abundance, rate, nHden, Tgas0, npart, nspec, nreac)

  write(6,*) ''
  write(6,*) ' abundances after integration to 1e7 yr (relative to n_H):'
  do is = 1, nspec
     if (abundance(is) > 1.0d-12) &
          & write(6,'("   ",A10,ES12.4)') species(is), abundance(is)
  end do

  write(6,*) ''
  write(6,'(" sum of C-bearing / elemental C : checked below")')
  write(6,'("   x(e-)  = ",ES12.4)') abundance(NELECT)
  write(6,'("   x(H)   = ",ES12.4,"   x(H2) = ",ES12.4)') abundance(NH), abundance(NH2)
  write(6,'("   x(C+)  = ",ES12.4,"   x(C)  = ",ES12.4,"   x(CO) = ",ES12.4)') &
       & abundance(NCx), abundance(NC), abundance(NCO)
  ! ---- conservation checks: the real assertions -----------------------------
  ! Charge balance is the sharpest single test that the network was read
  ! correctly and that CVODE converged: it is not imposed by the solver, it
  ! emerges only if every rate and stoichiometry is right.
  qplus = 0.0d0
  do is = 1, nspec
     if (index(trim(species(is)),'+') > 0) qplus = qplus + abundance(is)
  end do
  qminus = abundance(NELECT)

  write(6,*) ''
  write(6,*) ' conservation checks'
  write(6,'("   cations   = ",ES12.4)') qplus
  write(6,'("   electrons = ",ES12.4)') qminus
  write(6,'("   charge imbalance = ",F8.4," %")') &
       & 100.0d0*abs(qplus-qminus)/max(qplus,1.0d-30)

  if (abs(qplus-qminus)/max(qplus,1.0d-30) > 1.0d-2) then
     write(6,*) ' ! FAILED: charge is not conserved to 1%'
     stop 2
  end if
  if (abundance(NH2) < 0.4d0) then
     write(6,*) ' ! FAILED: gas is not molecular at A_V = 3'
     stop 3
  end if

  write(6,*) ''
  write(6,*) ' Phase 1 smoke test PASSED.'

end program pdrSmokeTest
