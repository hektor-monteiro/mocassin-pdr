! D-401: one-cell box runs of the compiled-in network at a run's own median
! conditions (cells.txt, from cells.py), timed cold and warm. The run's grain
! formation coefficient and H2 dissociation rate are imposed, so the box
! isolates what the network changes. Not part of any flavour: build.sh puts
! it in place of pdrSmokeTest.f90 in a scratch copy of the source.
!
! Usage: ./pdrSmokeTest [<factor on Cl + PHOTON>] [<1 keep | 0 zero H2 -> H2*>]
program pdrSmokeTest

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

  integer(kind=i4b), parameter :: nraysLoc = 12
  integer(kind=i4b), parameter :: npart = 1
  real(kind=dp) :: radSurf(0:nraysLoc-1), AVray(0:nraysLoc-1)
  real(kind=dp) :: colH2(0:nraysLoc-1), colHD(0:nraysLoc-1), colCO(0:nraysLoc-1)
  real(kind=dp) :: colC(0:nraysLoc-1),  colS(0:nraysLoc-1)
  real(kind=dp), allocatable :: abundance(:), seed(:), seedW(:)
  real(kind=dp) :: twarm
  integer(kind=i4b) :: NRGR, NRH2loc, NRHDloc, NRCOloc, NRCIloc, NRSIloc
  integer :: is, ios, ic, ncell, ir, irep, j, nb, net, iH2s, iClp, iCl, iHClp, iStat
  integer(kind=8) :: c0, c1, crate
  real(kind=dp) :: dummy, nHden, Tg, Td, chi, kdis, kdisc, Rf, colN, x2run, xerun, av
  real(kind=dp) :: tbest, tsec, lTot, lPD, lClp, lHClp, lStar, lOth, evr, clScale, xH2t
  integer :: keepStar
  character(len=50) :: suffix
  character(len=10) :: rr(3), pp(4)
  character(len=32) :: arg
  integer, external :: calculate_abundances

  clScale = 1.0d0; keepStar = 1
  if (command_argument_count() >= 1) then
     call get_command_argument(1, arg); read(arg,*) clScale
  end if
  if (command_argument_count() >= 2) then
     call get_command_argument(2, arg); read(arg,*) keepStar
  end if

#ifdef REDUCED
  suffix = 'reduced.d'
#elif MEDIUM
  suffix = 'medium.d'
#elif FULL
  suffix = 'full.d'
#elif MYNETWORK
  suffix = 'mynetwork.d'
#endif

  open(unit=1,file='chemfiles/species_'//trim(adjustl(suffix)),status='old',iostat=ios)
  if (ios/=0) stop 1
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
  write(6,'("# network ",A,": ",I0," species, ",I0," reactions; Cl photoionization x",F6.1, &
       & "; H2 -> H2* pumping ",A)') trim(adjustl(suffix)), nspec, nreac, clScale, &
       & merge('kept  ','zeroed', keepStar == 1)

  metallicity  = 1.0d0
  grain_radius = 1.0d-5
  omega        = 0.42d0
  AV_fac       = 6.289d-22
  UV_fac       = 3.02d0
  zeta         = 4.293d-16/1.3d-17      ! the fixture's pdrZeta
  redshift     = 0.0d0
  Tcmb         = 2.725d0
  v_turb       = 1.0d5
  coo          = 0
  start_time   = 0.0d0
  end_time     = 1.0d7
  relative_abundance_tolerance = 1.0d-8
  absolute_abundance_tolerance = 1.0d-30

  call allocations
  call read_species(nspec, species, init_abundance, mass)
  call READ_RATES(nreac, reactant, product, alpha, beta, gamma, rate, &
       &          duplicate, rtmin, rtmax)

  ! the seed MOCASSIN would hand a PDR cell: no molecules, each element in the
  ! stage it has past the front (pn150k's trimmed abundances)
  allocate(abundance(1:nspec), seed(1:nspec), seedW(1:nspec))
  seed = 0.d0
  call put('H         ', 1.0d0)
  call put('He        ', 8.51d-2)
  call put('C+        ', 2.69d-4)
  call put('N         ', 6.76d-5)
  call put('O         ', 4.90d-4)
  call put('Mg+       ', 3.98d-7)
  call put('Si+       ', 3.24d-7)
  call put('S+        ', 1.32d-5)
  call put('Cl+       ', 3.16d-7)
  seed(NELECT) = 0.d0
  do is = 1, nspec
     if (is == NELECT) cycle
     if (index(trim(species(is)),'+') > 0) seed(NELECT) = seed(NELECT) + seed(is)
  end do
  iH2s = idx('H2*       '); iClp = idx('Cl+       '); iCl = idx('Cl        ')
  iHClp = idx('HCl+      ')

  open(unit=7, file='cells.txt', status='old')
  read(7,*) ncell
  write(6,'(A)') '# A_V   2n(H2)/nH run   box     x_e run    box      x(C+)     x(CO)     Cl+/Cl_tot  ' // &
       & 'H2 loss [s-1]  shares: photodiss  Cl+   HCl+   via H2*  other   solve cold, warm [ms]  status'
  nHden = 1.0d3
  do ic = 1, ncell
     read(7,*) av, Tg, Td, chi, kdis, kdisc, Rf, colN, x2run, xerun, nHden
     radSurf = chi/real(nraysLoc,kind=dp)
     AVray   = 0.0d0                    ! the field is the cell's own (D-350)
     colH2   = colN
     colHD   = 0.0d0; colCO = 0.0d0; colC = 0.0d0; colS = 0.0d0
     tbest = 1.d30
     do irep = 1, 3
        abundance = seed
        call CALCULATE_REACTION_RATES(Tg, Td, nraysLoc, radSurf, AVray, &
             & colH2, colHD, colCO, colC, colS, &
             & nreac, reactant, product, alpha, beta, gamma, rate, rtmin, rtmax, &
             & duplicate, nspec, NRGR, NRH2loc, NRHDloc, NRCOloc, NRCIloc, NRSIloc, &
             & abundance(NELECT)*nHden, nHden, zeta)
        ! the run's own grain formation coefficient and H2 dissociation rate
        rate(NRGR)    = Rf
        rate(NRH2loc) = kdis
        do ir = 1, nreac
           rr = adjustl(reactant(ir,:)); pp = adjustl(product(ir,:))
           if (rr(1) == 'Cl' .and. rr(2) == 'PHOTON' .and. any(pp == 'Cl+')) &
                & rate(ir) = rate(ir)*clScale
           if (keepStar == 0 .and. rr(1) == 'H2' .and. rr(2) == 'PHOTON' &
                & .and. any(pp == 'H2*')) rate(ir) = 0.d0
        end do
        call system_clock(c0, crate)
        iStat = calculate_abundances(abundance, rate, nHden, Tg, npart, nspec, nreac)
        call system_clock(c1)
        tsec = dble(c1-c0)/dble(crate)
        tbest = min(tbest, tsec)
     end do
     ! a warm start, as the model makes: from the last answer
     seedW = abundance
     call system_clock(c0, crate)
     iStat = calculate_abundances(seedW, rate, nHden, Tg, npart, nspec, nreac)
     call system_clock(c1)
     twarm = dble(c1-c0)/dble(crate)

     xH2t = abundance(NH2)
     if (iH2s > 0) xH2t = xH2t + abundance(iH2s)
     ! what destroys H2 (+H2*), per H2, by reaction
     lTot = 0.d0; lPD = 0.d0; lClp = 0.d0; lHClp = 0.d0; lStar = 0.d0; lOth = 0.d0
     do ir = 1, nreac
        rr = adjustl(reactant(ir,:)); pp = adjustl(product(ir,:))
        net = count(rr == 'H2') + count(rr == 'H2*') - count(pp == 'H2') - count(pp == 'H2*')
        if (net <= 0) cycle
        evr = rate(ir); nb = 0
        do j = 1, 3
           is = idx(rr(j))
           if (is > 0) then
              evr = evr*abundance(is); nb = nb + 1
           end if
        end do
        if (nb == 0) cycle
        evr = evr*nHden**(nb-1)*dble(net)
        ! the grain formation reaction is H + H, never a loss; nothing to skip
        lTot = lTot + evr
        if (ir == NRH2loc) then
           lPD = lPD + evr
        else if (any(rr == 'Cl+')) then
           lClp = lClp + evr
        else if (any(rr == 'HCl+')) then
           lHClp = lHClp + evr
        else if (any(rr == 'H2*')) then
           lStar = lStar + evr
        else
           lOth = lOth + evr
        end if
     end do
     dummy = 0.d0
     if (iClp > 0) dummy = abundance(iClp)/3.16d-7
     write(6,'(F5.2,2ES11.3,2ES11.3,2ES10.2,ES11.3,ES12.3,2X,5F7.3,2F10.2,I6)') av, x2run, 2.d0*xH2t, &
          & xerun, abundance(NELECT), abundance(NCx), abundance(NCO), dummy, &
          & lTot/max(xH2t,1.d-300), lPD/max(lTot,1.d-300), lClp/max(lTot,1.d-300), &
          & lHClp/max(lTot,1.d-300), lStar/max(lTot,1.d-300), lOth/max(lTot,1.d-300), &
          & tbest*1.d3, twarm*1.d3, iStat
  end do
  close(7)

contains

  integer function idx(name)
    character(len=*), intent(in) :: name
    integer :: k
    idx = 0
    if (len_trim(name) == 0) return
    do k = 1, nspec
       if (trim(adjustl(species(k))) == trim(adjustl(name))) then
          idx = k; return
       end if
    end do
  end function idx

  subroutine put(name, val)
    character(len=*), intent(in) :: name
    real(kind=dp), intent(in) :: val
    integer :: k
    k = idx(name)
    if (k > 0) seed(k) = val
  end subroutine put

end program pdrSmokeTest
