! H-005: test driver - the H2 level model marched through a plane slab lit
! from one side, zone by zone, as it will be run on a finished MOCASSIN model:
! the gas (T, densities, n(H2)) and the dust-attenuated continuum of every zone
! are given, the levels are solved, and their columns shade the zones behind.
!
!    h2Slab <data dir> <slab file> <voigt|federman> <output prefix> [passes]
!
! Slab file:
!    nz nf vturb[cm/s]
!    nf wavenumbers [cm-1], ascending
!    then for each zone
!       dr[cm] T[K] n(H) n(He) n(H2) n(H+) w_ice w_sil w_car
!       nf photon occupation numbers of the continuum in the zone
!
! voigt     the model's shielding (h2LineShield): Voigt line, damping from
!           the upper level's total decay rate, averaged through the zone,
!           and the other lines' shading (overlap)
! federman  Cloudy's, for the like-for-like check: the Federman et al. fit,
!           damping from the line's own A, optical depth at the zone's inner
!           face with no averaging through the zone
!
! A photon emitted in a thick line is absorbed again on the spot, so each
! line's decay counts by its escape probability, here the mean over the two
! directions along the slab's normal. The column on the far side is only
! known once the slab has been marched, so the march is repeated (passes,
! default 2); the first pass takes the far side as closed.
!
! Output: <prefix>.zones (one line per zone), <prefix>.pops (nz x h2NX raw
! float64), <prefix>.cols (v J E N[cm-2]), <prefix>.tau (line list with the
! optical depths at the far face).
program h2Slab
    use h2_mod
    implicit none
    integer, parameter :: dp = kind(1.d0)
    real(dp), parameter :: pi = 3.14159265358979324_dp
    real(dp), parameter :: kB = 1.380649e-16_dp, amu = 1.66053907e-24_dp
    real(dp), parameter :: mH2 = 2.01588_dp
    real(dp), parameter :: eStar = 4100._dp           ! Cloudy's H2g / H2* boundary [cm-1]
    character(len=512) :: dir, slabFile, mode, prefix, arg5
    integer :: nz, nf, iz, i, k, lo, hi, mid, it, u, l, ipass, npass
    real(dp) :: vturb, dr, T, nH, nHe, nH2, nHp, wSurf(h2NSurf), b, dens(h2NColl)
    real(dp) :: fo, foNew, depth, lam, sig, a, solG, solS, popG
    real(dp), allocatable :: fw(:), fe(:), etaC(:), eta(:), shield(:), tau0(:)
    real(dp), allocatable :: Ncol(:), dN(:), pops(:), kdiss(:), pump(:), phi(:), phi1(:)
    real(dp), allocatable :: Ntot(:), N2(:,:), beta(:), ovl(:)
    integer, allocatable :: cell(:)
    logical :: lgFed

    call get_command_argument(1, dir)
    call get_command_argument(2, slabFile)
    call get_command_argument(3, mode)
    call get_command_argument(4, prefix)
    call get_command_argument(5, arg5)
    npass = 2
    if (len_trim(arg5) > 0) read(arg5, *) npass
    lgFed = (trim(mode) == 'federman')
    if (.not.lgFed .and. trim(mode) /= 'voigt') stop '! h2Slab: mode is voigt or federman'
    call h2ReadX(trim(dir))
    call h2ReadElec(trim(dir))

    open(unit=10, file=trim(slabFile), status='old', action='read')
    read(10, *) nz, nf, vturb
    allocate(fw(nf), fe(nf), etaC(h2NT), eta(h2NT), shield(h2NT), tau0(h2NT), cell(h2NT))
    allocate(Ncol(h2NX), dN(h2NX), pops(h2NX), kdiss(h2NX), pump(h2NX), phi(h2NX), phi1(h2NX))
    allocate(Ntot(h2NX), N2(h2NX, 2), beta(h2NT), ovl(h2NT))
    read(10, *) fw
    ! the field cell of each line: the nearest
    do i = 1, h2NT
       lo = 1; hi = nf
       do while (hi - lo > 1)
          mid = (lo + hi)/2
          if (fw(mid) <= h2tWN(i)) then
             lo = mid
          else
             hi = mid
          end if
       end do
       cell(i) = merge(lo, hi, h2tWN(i) - fw(lo) <= fw(hi) - h2tWN(i))
    end do

    Ntot = huge(1._dp)                     ! first pass: the far side closed
    do ipass = 1, npass
    if (ipass > 1) then
       rewind(10)
       read(10, *) nz, nf, vturb
       read(10, *) fw
    end if
    open(unit=11, file=trim(prefix)//'.zones', status='replace', action='write')
    write(11, '(a)') '# depth[cm] N(H2)in[cm-2] n(H2) Sol_g[s-1] Sol_*[s-1] Sol[s-1] pump[s-1] o/p f* iterations'
    open(unit=12, file=trim(prefix)//'.pops', status='replace', access='stream', action='write')
    Ncol = 0._dp; depth = 0._dp; fo = 0.75_dp; pops = 0._dp
    do iz = 1, nz
       read(10, *) dr, T, nH, nHe, nH2, nHp, wSurf
       read(10, *) fe
       b = sqrt(2._dp*kB*T/(mH2*amu) + vturb*vturb)
       do i = 1, h2NT
          etaC(i) = fe(cell(i))
       end do
       phi = 0._dp
       do k = 1, h2NSurf
          if (wSurf(k) <= 0._dp) cycle
          call h2FormDist(k, phi1)
          phi = phi + wSurf(k)*phi1
       end do
       phi = phi/sum(phi)

       if (lgFed) then
          ! Cloudy's: tau at the inner face, Federman's fit, damping from the line's own A
          do i = 1, h2NT
             u = h2tU(i); l = h2tL(i)
             lam = 1._dp/h2tWN(i)
             sig = h2uG(u)/h2G(l)*h2tA(i)*lam**3/(8._dp*pi**1.5_dp*b)
             a = h2tA(i)*lam/(4._dp*pi*b)
             shield(i) = h2ShieldFederman(Ncol(l)*sig, a)
          end do
       end if
       ! the ortho and para H2 that collide are the model's own: iterate
       do it = 1, 30
          dens = (/ nH, nHe, fo*nH2, (1._dp - fo)*nH2, nHp /)
          if (.not.lgFed) then
             dN = pops*nH2*dr
             ! the other lines' shading once per zone, at mid-zone, with the
             ! zone's own column guessed from the zone before
             if (it == 1) call h2LineOverlap(Ncol + 0.5_dp*dN, b, ovl)
             if (it == 1 .and. iz == 1) then
                call h2LineShield(Ncol, b, shield, overlap=ovl)
             else
                call h2LineShield(Ncol, b, shield, dN, overlap=ovl)
             end if
          end if
          eta = etaC*shield
          ! escape of each line toward the source and away from it
          if (lgFed) then
             ! Cloudy's columns: the zone taken at its inner face, damping from the line's own A
             do i = 1, h2NT
                u = h2tU(i); l = h2tL(i)
                lam = 1._dp/h2tWN(i)
                sig = h2uG(u)/h2G(l)*h2tA(i)*lam**3/(8._dp*pi**1.5_dp*b)
                a = h2tA(i)*lam/(4._dp*pi*b)
                beta(i) = 0.5_dp*(h2Shield(Ncol(l)*sig, a) + &
                     & h2Shield(min(max(Ntot(l) - Ncol(l), 0._dp), 1.e40_dp)*sig, a))
             end do
          else
             dN = pops*nH2*dr
             N2(:, 1) = Ncol + 0.5_dp*dN
             N2(:, 2) = min(max(Ntot - Ncol - 0.5_dp*dN, 0._dp), 1.e40_dp)
             call h2LineEscape(N2, b, beta)
          end if
          call h2Solve(T, dens, eta, phi, pops, kdiss, pump, beta=beta)
          foNew = sum(pops, mask=h2Ortho)
          if (abs(foNew - fo) < 1.e-5_dp .and. (lgFed .or. it > 2)) then
             fo = foNew; exit
          end if
          fo = foNew
       end do
       popG = sum(pops, mask=(h2E <= eStar))
       solG = sum(pops*kdiss, mask=(h2E <= eStar))/popG
       solS = sum(pops*kdiss, mask=(h2E > eStar))/max(1._dp - popG, tiny(1._dp))
       write(11, '(es14.6,es13.5,es12.4,4es13.5,f9.5,es12.4,i4)') depth + 0.5_dp*dr, sum(Ncol), nH2, solG, solS, &
            & sum(pops*kdiss), sum(pops*pump), fo/(1._dp - fo), 1._dp - popG, min(it, 30)
       write(12) pops
       Ncol = Ncol + pops*nH2*dr
       depth = depth + dr
    end do
    close(11); close(12)
    Ntot = Ncol
    end do
    close(10)

    open(unit=13, file=trim(prefix)//'.cols', status='replace', action='write')
    write(13, '(a)') '# v J E[cm-1] N[cm-2]'
    do i = 1, h2NX
       write(13, '(2i4,f12.4,es15.6e3)') h2V(i), h2J(i), h2E(i), Ncol(i)
    end do
    close(13)
    ! the lines at the far face: wavenumber, lower level, tau0, damping (model's), shield
    call h2LineShield(Ncol, b, shield, tau0=tau0)
    open(unit=14, file=trim(prefix)//'.tau', status='replace', action='write')
    write(14, '(a)') '# state vu Ju vl Jl wavenumber[cm-1] A[s-1] tau0 a(Gamma_u) a(A_ul) S'
    do i = 1, h2NT
       if (tau0(i) < 1.e-4_dp) cycle
       u = h2tU(i); l = h2tL(i); lam = 1._dp/h2tWN(i)
       write(14, '(5i4,f13.3,5es15.5e3)') h2uS(u), h2uV(u), h2uJ(u), h2V(l), h2J(l), h2tWN(i), h2tA(i), tau0(i), &
            & (h2uAtot(u) + h2uDiss(u))*lam/(4._dp*pi*b), h2tA(i)*lam/(4._dp*pi*b), shield(i)
    end do
    close(14)
    print '(a,i5,a,es11.4,a)', ' h2Slab: ', nz, ' zones, N(H2) = ', sum(Ncol), ' cm^-2'
end program h2Slab
