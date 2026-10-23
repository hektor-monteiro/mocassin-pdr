! Copyright (C) 2026 Hektor Monteiro
! Part of MOCASSIN-PDR.
!
! This program is free software: you can redistribute it and/or modify it
! under the terms of the GNU General Public License as published by the Free
! Software Foundation, either version 3 of the License, or (at your option)
! any later version. It is distributed WITHOUT ANY WARRANTY; see the GNU
! General Public License (LICENSE) for details.
!
!===============================================================================
! H-003: the H2 level model, stage A step 1 - the rovibrational levels of the
! electronic ground state X, in statistical equilibrium under collisions and
! radiative decay.
!
! Levels, A values and collision data are Cloudy c25.00's (dataPDR/h2/, see
! its README), and so are the conventions this follows, so that the solver can
! be checked level by level against Cloudy's large H2 model:
!   - the five colliders and their default data sets (h2.cpp): H (Lique 2015),
!     He (ORNL), ortho-H2 and para-H2 (Wan et al. 2018), H+ (Gerlich 1990);
!   - rate coefficients interpolated linearly in T and held at the table ends
!     (atmdat.cpp InterpCollRate);
!   - every pair of levels takes a collision rate for every collider: the
!     table's where it has one, otherwise the g-bar fit
!     log10 k = y0 + a (max(dE, 100 cm^-1))^b, and only if the pair does not
!     change the nuclear spin (mole_h2_coll.cpp GbarRateCoeff);
!   - statistical weights (2J+1) x 3 for ortho (odd J) and x 1 for para, and
!     excitation by detailed balance on the levels' own energies.
! It is a re-implementation from those equations and data. Two routines are
! translated or adapted from Cloudy's source and marked below (h2ShieldFederman,
! h2FormDist); Cloudy's zlib licence is reproduced in THIRD_PARTY_NOTICES.md.
!
! H-004: ultraviolet pumping. The electronic states B, C+, C-, B', D+, D-
! (Abgrall, Roueff & Drira 2000) are read with their lines to X and their
! dissociation rates. A molecule in X level l absorbs in line l -> u at the
! rate A_ul (g_u/g_l) eta, eta the photon occupation number of the local
! field at the line (shielding included by the caller). The excited level u
! lives ~1e-8 s, so it is never a reservoir: it returns to X level l' with
! probability A_ul'/Gamma_u or dissociates with probability D_u/Gamma_u,
! Gamma_u = sum A + D. That gives a rate matrix within X (the fluorescent
! cascade's first step) and a dissociation rate per level (the Solomon
! process); the quadrupole cascade that follows is the X solver's.
!   - ortho/para of the excited levels and the weights follow Cloudy
!     (mole_h2_create.cpp): B, C+, B', D+ are ortho for even J; C-, D- for odd;
!   - Cloudy's files end at the first empty line, so D- stops at v = 2 (the
!     levels after it are above the dissociation limit); the same rule here.
! Each molecule destroyed is replaced by one newly formed (steady state), in
! the distribution over (v, J) of Takahashi & Uehara 2001 for formation on a
! grain surface, as Cloudy applies it by default.
!
! H-005: self-shielding of the pumping lines. Between the source and the
! point, the H2 in lower level l has column N_l; line l -> u then has optical
! depth tau_0 = N_l (g_u/g_l) A_ul lambda^3 / (8 pi^1.5 b) at its centre and
! the continuum reaching the point in that line is cut by
!     S(tau_0, a) = (1/sqrt(pi)) int H(a,x) exp(-tau_0 H(a,x)/H(a,0)) dx,
! the absorption of a beam by a Voigt line, integrated numerically and
! tabulated once (h2Shield). The damping parameter is a = Gamma_u lambda /
! (4 pi b) with Gamma_u the upper level's total decay rate, sum A + D_u.
! Through a cell that itself holds a column dN_l the mean over the cell is
! (W(tau_0 + dtau) - W(tau_0))/dtau, W the integral of S (the curve of
! growth), tabulated with it.
! The same S is the chance that a photon emitted in a line crosses the column
! in one direction, so its mean over directions is the line's escape
! probability (h2LineEscape); a decay through a thick line is undone on the
! spot and counts only by that probability (beta in h2PumpRates).
! Cloudy's own choices differ and are kept only as h2ShieldFederman for the
! like-for-like check: the fit of Federman, Glassgold & Kwan 1979, the
! damping from the line's own A alone, and no averaging over the zone.
!
! H-006: line overlap. The H2 lines shade one another: each line's shielding
! is its own S times the mean transmission of all the other lines over the
! frequencies where it absorbs (lineOverlap), checked against the integral on
! a fine frequency grid.
!
! Not yet in: destruction other than the Solomon process, formation by H- and
! H2+, cosmic rays, shading by the H I Lyman lines, and electrons as
! colliders, which Aleman & Gruenwald 2011 include and Cloudy does not.
!===============================================================================
module h2_mod
    implicit none
    private

    integer, parameter :: dp = kind(1.d0)
    integer, parameter, public :: h2NColl = 5          ! H, He, o-H2, p-H2, H+
    character(len=4), parameter, public :: h2CollName(h2NColl) = &
         & (/'H   ', 'He  ', 'oH2 ', 'pH2 ', 'H+  '/)
    real(dp), parameter :: hcK = 1.4387769_dp           ! hc/k [cm K]
    real(dp), parameter :: hPl = 6.62607015e-27_dp      ! Planck's constant [erg s]

    integer, public :: h2NX = 0                         ! X levels, in energy order
    integer, allocatable, public :: h2V(:), h2J(:)
    real(dp), allocatable, public :: h2E(:)             ! [cm^-1]
    real(dp), allocatable, public :: h2G(:)             ! (2J+1)(2I+1)
    logical, allocatable, public :: h2Ortho(:)
    real(dp), allocatable, public :: h2A(:,:)           ! (upper, lower) [s^-1]
    integer, allocatable :: idx(:,:)                    ! (v, J) -> level

    type tab_t
       integer :: nT = 0, nTr = 0
       real(dp), allocatable :: T(:)
       integer, allocatable :: up(:), lo(:)
       real(dp), allocatable :: k(:,:)                  ! (transition, T)
    end type tab_t
    type(tab_t) :: tab(h2NColl)

    ! Cloudy's g-bar fits, per collider: y0, a, b
    real(dp), parameter :: gbar(3, h2NColl) = reshape( (/ &
         & -9.9265_dp, -0.1048_dp, 0.456_dp, &
         & -8.281_dp,  -0.1303_dp, 0.4931_dp, &
         & -10.0357_dp,-0.0243_dp, 0.67_dp, &
         & -8.6213_dp, -0.1004_dp, 0.5291_dp, &
         & -9.2719_dp, -0.0001_dp, 1.0391_dp /), (/3, h2NColl/))

    character(len=40), parameter :: collFile(h2NColl) = (/ &
         & 'coll_rates_H_15.dat        ', 'coll_rates_He_ORNL.dat     ', &
         & 'coll_rates_H2ortho_ORNL.dat', 'coll_rates_H2para_ORNL.dat ', &
         & 'coll_rates_Hp.dat          ' /)

    ! --- electronic excited states, all in one list (H-004)
    integer, parameter, public :: h2NElec = 6
    character(len=8), parameter, public :: h2ElecName(h2NElec) = (/ &
         & 'B       ', 'C_plus  ', 'C_minus ', 'B_primed', 'D_plus  ', 'D_minus ' /)
    integer, parameter :: orthoAdd(h2NElec) = (/1, 1, 0, 1, 1, 0/)   ! ortho if J + this is odd
    integer, public :: h2NU = 0
    integer, allocatable, public :: h2uS(:), h2uV(:), h2uJ(:)   ! state, v, J
    real(dp), allocatable, public :: h2uE(:)            ! [cm^-1] above X(0,0)
    real(dp), allocatable, public :: h2uG(:)
    real(dp), allocatable, public :: h2uDiss(:)         ! dissociation rate [s^-1]
    real(dp), allocatable, public :: h2uKE(:)           ! kinetic energy of the atoms [eV]
    real(dp), allocatable, public :: h2uAtot(:)         ! sum of A to X [s^-1]
    integer, public :: h2NT = 0                         ! lines u -> X, sorted by u
    integer, allocatable, public :: h2tU(:), h2tL(:)
    real(dp), allocatable, public :: h2tA(:), h2tWN(:)  ! [s^-1], [cm^-1]
    integer, allocatable :: uFirst(:), uLast(:)         ! a level's lines in the list
    real(dp), allocatable :: crKd(:,:,:), crBf(:,:)     ! h2CollRad's rate coefficients and Boltzmann factors at crT
    real(dp) :: crT = -1._dp
    real(dp), allocatable :: psSig(:), psT(:), psW0(:), psFa(:)   ! h2LineShieldPrep's path
    integer, allocatable :: psJ(:)
    real(dp), public :: h2DissX = 0._dp                 ! dissociation energy of X [cm^-1]
    integer, public :: h2NSkipped = 0                 ! lines read whose levels are not in the model

    ! Takahashi & Uehara 2001 surfaces: ice, silicate, carbonaceous
    integer, parameter, public :: h2NSurf = 3
    real(dp), parameter :: tuXvib(h2NSurf)   = (/0.70_dp, 0.60_dp, 0.20_dp/)
    real(dp), parameter :: tuXdust(h2NSurf)  = (/0.04_dp, 0.10_dp, 0.40_dp/)
    real(dp), parameter :: tuXrot(h2NSurf)   = (/0.14_dp, 0.15_dp, 0.15_dp/)
    real(dp), parameter :: tuXtrans(h2NSurf) = (/0.12_dp, 0.15_dp, 0.25_dp/)
    real(dp), parameter :: tuG1(h2NSurf)     = (/0.3_dp, 0.4_dp, 0.9_dp/)
    real(dp), parameter :: tuG2(h2NSurf)     = (/0.6_dp, 0.6_dp, 0.4_dp/)
    real(dp), parameter :: tuEoff = 0.273_dp*8065.544_dp   ! well bottom to (0,0) [cm^-1]

    ! --- self-shielding (H-005): S and the curve of growth W on a grid of
    ! log10 tau_0 and log10 a
    real(dp), parameter :: pi = 3.14159265358979324_dp
    real(dp), parameter :: cLight = 2.99792458e10_dp
    integer, parameter :: nShT = 161, nShA = 29
    real(dp), parameter :: shT0 = -4._dp, shT1 = 16._dp      ! log10 tau_0
    real(dp), parameter :: shA0 = -7._dp, shA1 = 0._dp       ! log10 a
    real(dp) :: shS(nShT, nShA), shW(nShT, nShA)             ! log10 S, log10 W
    ! where in a line its absorption happens: the offsets x (Doppler widths)
    ! at which the cumulative of phi exp(-tau) on one side reaches 1/6, 1/2, 5/6
    integer, parameter :: nShQ = 3
    real(dp), parameter :: shQ(nShQ) = (/1._dp/6._dp, 0.5_dp, 5._dp/6._dp/)
    real(dp) :: shX(nShT, nShA, nShQ)                        ! log10 x_q
    logical :: lgShTab = .false.
    integer, allocatable :: ordWN(:)                         ! the lines in wavenumber order
    real(dp), allocatable :: wnSort(:)                       ! and their wavenumbers in that order
    ! line overlap (H-006)
    real(dp), parameter :: ovTauB = 1.e-2_dp      ! a line shades others from this tau0
    real(dp), parameter :: ovEps = 1.e-4_dp       ! wing optical depth below which it is dropped
    real(dp), parameter :: ovNear = 40._dp        ! Doppler widths treated sample by sample
    real(dp), parameter :: ovLong = 100._dp       ! reach [cm^-1] above which a line shades every line

    public :: h2ReadX, h2ReadElec, h2SolveX, h2Solve, h2Level, h2PumpRates, h2FormDist, h2CollRad
    public :: h2Shield, h2ShieldFederman, h2LineShield, h2LineOverlap, h2LineEscape, h2LineParams, h2Voigt
    public :: h2ShieldAIndex, h2ShieldJ, h2LineShieldPrep, h2LineShieldEval, h2CollHeat

contains

    ! the level of (v, J), 0 if it does not exist
    integer function h2Level(v, J)
      integer, intent(in) :: v, J
      h2Level = 0
      if (v < lbound(idx,1) .or. v > ubound(idx,1)) return
      if (J < lbound(idx,2) .or. J > ubound(idx,2)) return
      h2Level = idx(v, J)
    end function h2Level

    ! the data part of a line: '#' and '//' comments cut, blank if nothing left
    function dataPart(line) result(s)
      character(len=*), intent(in) :: line
      character(len=len(line)) :: s
      integer :: p
      s = line
      p = index(s, '#');  if (p > 0) s(p:) = ' '
      p = index(s, '//'); if (p > 0) s(p:) = ' '
      do p = 1, len(s)
         if (s(p:p) == char(9)) s(p:p) = ' '
      end do
    end function dataPart

    integer function nTokens(s)
      character(len=*), intent(in) :: s
      integer :: p
      logical :: inTok
      nTokens = 0; inTok = .false.
      do p = 1, len_trim(s)
         if (s(p:p) /= ' ') then
            if (.not.inTok) nTokens = nTokens + 1
            inTok = .true.
         else
            inTok = .false.
         end if
      end do
    end function nTokens

    subroutine h2ReadX(dir)
      character(len=*), intent(in) :: dir
      character(len=1024) :: line, s
      integer :: ios, n, v, J, i, k, vu, Ju, vl, Jl, iu, il, ic, nt, ntr, eh, el, pass
      integer :: vmax, jmax
      real(dp) :: e, a
      integer, allocatable :: vt(:), jt(:), ord(:)
      real(dp), allocatable :: et(:), row(:)
      logical :: gotMagic

      ! --- energies
      open(unit=91, file=trim(dir)//'/energy_X.dat', status='old', action='read', iostat=ios)
      if (ios /= 0) stop '! h2ReadX: cannot open energy_X.dat'
      allocate(vt(1000), jt(1000), et(1000))
      n = 0; gotMagic = .false.
      do
         read(91, '(a)', iostat=ios) line
         if (ios /= 0) exit
         s = dataPart(line)
         if (len_trim(s) == 0) cycle
         if (.not.gotMagic) then
            gotMagic = .true.; cycle
         end if
         read(s, *, iostat=ios) v, J, e
         if (ios /= 0) cycle
         n = n + 1; vt(n) = v; jt(n) = J; et(n) = e
      end do
      close(91)
      ! energy order
      allocate(ord(n))
      ord = (/ (i, i = 1, n) /)
      do i = 2, n
         k = ord(i); J = i - 1
         do while (J >= 1)
            if (et(ord(J)) <= et(k)) exit
            ord(J+1) = ord(J); J = J - 1
         end do
         ord(J+1) = k
      end do
      h2NX = n
      allocate(h2V(n), h2J(n), h2E(n), h2G(n), h2Ortho(n))
      h2V = vt(ord(1:n)); h2J = jt(ord(1:n)); h2E = et(ord(1:n))
      vmax = maxval(h2V); jmax = maxval(h2J)
      allocate(idx(0:vmax, 0:jmax)); idx = 0
      do i = 1, n
         idx(h2V(i), h2J(i)) = i
         h2Ortho(i) = (mod(h2J(i), 2) == 1)
         h2G(i) = dble(2*h2J(i) + 1)*merge(3._dp, 1._dp, h2Ortho(i))
      end do
      deallocate(vt, jt, et, ord)

      ! --- A values within X
      allocate(h2A(n, n)); h2A = 0._dp
      open(unit=91, file=trim(dir)//'/transprob_X.dat', status='old', action='read', iostat=ios)
      if (ios /= 0) stop '! h2ReadX: cannot open transprob_X.dat'
      gotMagic = .false.
      do
         read(91, '(a)', iostat=ios) line
         if (ios /= 0) exit
         s = dataPart(line)
         if (len_trim(s) == 0) cycle
         if (.not.gotMagic) then
            gotMagic = .true.; cycle
         end if
         read(s, *, iostat=ios) eh, vu, Ju, el, vl, Jl, a
         if (ios /= 0) cycle
         if (eh /= 0 .or. el /= 0) cycle
         iu = h2Level(vu, Ju); il = h2Level(vl, Jl)
         if (iu == 0 .or. il == 0) cycle
         if (h2E(iu) < h2E(il)) then
            k = iu; iu = il; il = k
         end if
         ! a transition can be listed twice (E2 and M1 components,
         ! Pachucki & Komasa 2011): the components add, as in Cloudy
         h2A(iu, il) = h2A(iu, il) + a
      end do
      close(91)

      ! --- collision tables: magic, temperatures, then v' J' v J k(T...)
      do ic = 1, h2NColl
         do pass = 1, 2
            open(unit=91, file=trim(dir)//'/'//trim(collFile(ic)), status='old', action='read', iostat=ios)
            if (ios /= 0) then
               print*, '! h2ReadX: cannot open ', trim(collFile(ic)); stop
            end if
            gotMagic = .false.; nt = 0; ntr = 0
            do
               read(91, '(a)', iostat=ios) line
               if (ios /= 0) exit
               s = dataPart(line)
               if (len_trim(s) == 0) cycle
               if (.not.gotMagic) then
                  gotMagic = .true.; cycle
               end if
               if (nt == 0) then
                  nt = nTokens(s)
                  if (pass == 2) then
                     tab(ic)%nT = nt
                     allocate(tab(ic)%T(nt))
                     read(s, *) tab(ic)%T
                     allocate(row(nt))
                  end if
                  cycle
               end if
               if (nTokens(s) < 4 + nt) cycle
               read(s, *, iostat=ios) vu, Ju, vl, Jl
               if (ios /= 0) cycle
               iu = h2Level(vu, Ju); il = h2Level(vl, Jl)
               if (iu == 0 .or. il == 0 .or. iu == il) cycle
               ntr = ntr + 1
               if (pass == 2) then
                  read(s, *) vu, Ju, vl, Jl, row
                  if (h2E(iu) < h2E(il)) then
                     k = iu; iu = il; il = k
                  end if
                  tab(ic)%up(ntr) = iu; tab(ic)%lo(ntr) = il
                  tab(ic)%k(ntr, :) = row
               end if
            end do
            close(91)
            if (pass == 1) then
               tab(ic)%nTr = ntr
               allocate(tab(ic)%up(ntr), tab(ic)%lo(ntr), tab(ic)%k(ntr, nt))
            else
               deallocate(row)
            end if
         end do
      end do
    end subroutine h2ReadX

    ! Cloudy's rule for its level, line and dissociation files: '#' starts a
    ! comment line, and the data end at the first empty line or line starting
    ! with a blank. 0 comment, 1 data, 2 end of data.
    integer function lineKind(line)
      character(len=*), intent(in) :: line
      if (len_trim(line) == 0 .or. line(1:1) == ' ' .or. line(1:1) == char(13)) then
         lineKind = 2
      else if (line(1:1) == '#') then
         lineKind = 0
      else
         lineKind = 1
      end if
    end function lineKind

    ! open one of the files and skip its first line (the magic number)
    subroutine openData(dir, name)
      character(len=*), intent(in) :: dir, name
      integer :: ios
      character(len=8) :: skip
      open(unit=91, file=trim(dir)//'/'//trim(name), status='old', action='read', iostat=ios)
      if (ios /= 0) then
         print*, '! h2_mod: cannot open ', trim(dir)//'/'//trim(name); stop
      end if
      read(91, '(a)') skip
    end subroutine openData

    !---------------------------------------------------------------------------
    ! H-004: the excited electronic states - levels, dissociation rates and the
    ! lines to X. h2ReadX first.
    !---------------------------------------------------------------------------
    subroutine h2ReadElec(dir)
      character(len=*), intent(in) :: dir
      character(len=1024) :: line, s
      integer :: ios, is, n, v, J, i, k, eh, el, vu, Ju, vl, Jl, iu, il, pass, nt, vmax, jmax
      integer :: nSkip, nSpin
      real(dp) :: e, a, b
      integer, allocatable :: st(:), vt(:), jt(:), idxU(:,:,:), map(:,:), cnt(:), ord(:)
      integer, allocatable :: tU(:), tL(:)
      real(dp), allocatable :: et(:), tA(:)

      if (h2NX == 0) stop '! h2ReadElec: h2ReadX first'

      ! --- dissociation energy of X
      call openData(dir, 'energy_dissoc.dat')
      do
         read(91, '(a)', iostat=ios) line
         if (ios /= 0) exit
         k = lineKind(line)
         if (k == 2) exit
         if (k == 0) cycle
         s = dataPart(line)
         read(s, *, iostat=ios) is, e
         if (ios == 0 .and. is == 0) h2DissX = e
      end do
      close(91)

      ! --- levels, two passes: count, then fill
      do pass = 1, 2
         n = 0
         do is = 1, h2NElec
            call openData(dir, 'energy_'//trim(h2ElecName(is))//'.dat')
            do
               read(91, '(a)', iostat=ios) line
               if (ios /= 0) exit
               k = lineKind(line)
               if (k == 2) exit
               if (k == 0) cycle
               s = dataPart(line)
               read(s, *, iostat=ios) v, J, e
               if (ios /= 0) cycle
               n = n + 1
               if (pass == 2) then
                  st(n) = is; vt(n) = v; jt(n) = J; et(n) = e
               end if
            end do
            close(91)
         end do
         if (pass == 1) allocate(st(n), vt(n), jt(n), et(n))
      end do
      h2NU = n
      allocate(h2uS(n), h2uV(n), h2uJ(n), h2uE(n), h2uG(n), h2uDiss(n), h2uKE(n), h2uAtot(n))
      h2uS = st; h2uV = vt; h2uJ = jt; h2uE = et
      h2uDiss = 0._dp; h2uKE = 0._dp; h2uAtot = 0._dp
      vmax = maxval(vt); jmax = maxval(jt)
      allocate(idxU(h2NElec, 0:vmax, 0:jmax)); idxU = 0
      do i = 1, n
         idxU(st(i), vt(i), jt(i)) = i
         h2uG(i) = dble(2*jt(i) + 1)*merge(3._dp, 1._dp, mod(jt(i) + orthoAdd(st(i)), 2) == 1)
      end do
      deallocate(st, vt, jt, et)

      ! --- dissociation rate and the kinetic energy it releases
      do is = 1, h2NElec
         call openData(dir, 'dissprob_'//trim(h2ElecName(is))//'.dat')
         do
            read(91, '(a)', iostat=ios) line
            if (ios /= 0) exit
            k = lineKind(line)
            if (k == 2) exit
            if (k == 0) cycle
            s = dataPart(line)
            b = 0._dp
            read(s, *, iostat=ios) v, J, a, b
            if (ios /= 0) then
               read(s, *, iostat=ios) v, J, a
               if (ios /= 0) cycle
            end if
            if (v < 0 .or. v > vmax .or. J < 0 .or. J > jmax) cycle
            i = idxU(is, v, J)
            if (i == 0) cycle
            h2uDiss(i) = a; h2uKE(i) = b
         end do
         close(91)
      end do

      ! --- lines to X; a line listed twice adds, as within X
      allocate(map(h2NU, h2NX))
      do pass = 1, 2
         map = 0; nt = 0; nSkip = 0; nSpin = 0
         do is = 1, h2NElec
            call openData(dir, 'transprob_'//trim(h2ElecName(is))//'.dat')
            do
               read(91, '(a)', iostat=ios) line
               if (ios /= 0) exit
               k = lineKind(line)
               if (k == 2) exit
               if (k == 0) cycle
               s = dataPart(line)
               read(s, *, iostat=ios) eh, vu, Ju, el, vl, Jl, a
               if (ios /= 0) cycle
               iu = 0
               if (eh == is .and. vu >= 0 .and. vu <= vmax .and. Ju >= 0 .and. Ju <= jmax) &
                    & iu = idxU(is, vu, Ju)
               il = 0
               if (el == 0) il = h2Level(vl, Jl)
               if (iu == 0 .or. il == 0) then
                  nSkip = nSkip + 1; cycle
               end if
               if ((h2uG(iu) > dble(2*Ju + 1)) .neqv. h2Ortho(il)) nSpin = nSpin + 1
               if (map(iu, il) == 0) then
                  nt = nt + 1; map(iu, il) = nt
                  if (pass == 2) then
                     tU(nt) = iu; tL(nt) = il; tA(nt) = a
                  end if
               else if (pass == 2) then
                  tA(map(iu, il)) = tA(map(iu, il)) + a
               end if
            end do
            close(91)
         end do
         if (pass == 1) allocate(tU(nt), tL(nt), tA(nt))
      end do
      if (nSpin > 0) print*, '! h2ReadElec: lines that change the nuclear spin: ', nSpin
      h2NT = nt
      ! sorted by upper level (counting sort)
      allocate(cnt(h2NU), uFirst(h2NU), uLast(h2NU), ord(nt))
      cnt = 0
      do i = 1, nt
         cnt(tU(i)) = cnt(tU(i)) + 1
      end do
      k = 1
      do i = 1, h2NU
         uFirst(i) = k; uLast(i) = k - 1; k = k + cnt(i)
      end do
      do i = 1, nt
         uLast(tU(i)) = uLast(tU(i)) + 1
         ord(uLast(tU(i))) = i
      end do
      allocate(h2tU(nt), h2tL(nt), h2tA(nt), h2tWN(nt))
      h2tU = tU(ord); h2tL = tL(ord); h2tA = tA(ord)
      do i = 1, nt
         h2tWN(i) = h2uE(h2tU(i)) - h2E(h2tL(i))
         h2uAtot(h2tU(i)) = h2uAtot(h2tU(i)) + h2tA(i)
      end do
      if (any(h2tWN <= 0._dp)) stop '! h2ReadElec: a line with no energy'
      allocate(ordWN(nt), wnSort(nt))
      call indexSort(nt, h2tWN, ordWN)
      wnSort = h2tWN(ordWN)
      deallocate(idxU, map, cnt, ord, tU, tL, tA)
      h2NSkipped = nSkip
    end subroutine h2ReadElec

    !---------------------------------------------------------------------------
    ! Pumping through the excited states for a given field. eta(1:h2NT) is the
    ! photon occupation number at each line, J_nu c^2/(2 h nu^3), with whatever
    ! shielding applies already in it.
    !   W(l, l')  rate [s^-1] at which a molecule in X level l is moved to X
    !             level l' by one absorption and the decay that follows
    !   kdiss(l)  rate [s^-1] at which it is dissociated instead (Solomon)
    !   pump(l)   total absorption rate out of l = sum_l' W(l,l') + kdiss(l)
    ! Stimulated emission (A eta) is kept in the decay for completeness.
    !
    ! beta(1:h2NT), optional (H-005): the probability that a photon emitted in
    ! each line leaves the cloud rather than being absorbed again in the same
    ! line by the H2 around it. A decay through a thick line is undone on the
    ! spot - the photon re-excites the same upper level - so the line's A
    ! counts only by its escape probability, and the excited level's other
    ! decays and its dissociation take the share. pump(l) is still the
    ! absorption of the external field alone.
    !
    ! heatDis(l), optional (H-012): the kinetic energy the dissociations out
    ! of l leave in the gas, per molecule in l [eV s^-1] - each excited
    ! level's dissociation rate times the energy of its atoms (h2uKE).
    !---------------------------------------------------------------------------
    subroutine h2PumpRates(eta, W, kdiss, pump, beta, heatDis)
      real(dp), intent(in) :: eta(:)
      real(dp), intent(out) :: W(:,:), kdiss(:)
      real(dp), intent(out), optional :: pump(:), heatDis(:)
      real(dp), intent(in), optional :: beta(:)
      real(dp) :: gam, P
      real(dp), allocatable :: Aeff(:)
      integer :: u, t, t2

      ! decay through each line: A (1 + eta), times its escape probability
      allocate(Aeff(h2NT))
      Aeff = h2tA*(1._dp + eta(1:h2NT))
      if (present(beta)) Aeff = Aeff*beta(1:h2NT)
      W = 0._dp; kdiss = 0._dp
      if (present(pump)) pump = 0._dp
      if (present(heatDis)) heatDis = 0._dp
      do u = 1, h2NU
         if (uLast(u) < uFirst(u)) cycle
         gam = h2uDiss(u) + sum(Aeff(uFirst(u):uLast(u)))
         if (gam <= 0._dp) cycle
         do t = uFirst(u), uLast(u)
            if (eta(t) <= 0._dp) cycle
            P = h2tA(t)*h2uG(u)/h2G(h2tL(t))*eta(t)
            if (present(pump)) pump(h2tL(t)) = pump(h2tL(t)) + P
            kdiss(h2tL(t)) = kdiss(h2tL(t)) + P*h2uDiss(u)/gam
            if (present(heatDis)) heatDis(h2tL(t)) = heatDis(h2tL(t)) + P*h2uDiss(u)/gam*h2uKE(u)
            do t2 = uFirst(u), uLast(u)
               W(h2tL(t), h2tL(t2)) = W(h2tL(t), h2tL(t2)) + P*Aeff(t2)/gam
            end do
         end do
      end do
      deallocate(Aeff)
    end subroutine h2PumpRates

    !---------------------------------------------------------------------------
    ! The (v, J) distribution of H2 newly formed on a grain surface, summing to
    ! 1: Takahashi & Uehara 2001 (ApJ 561, 843), surf = 1 ice, 2 silicate,
    ! 3 carbonaceous, as Cloudy applies it (mole_h2_create.cpp): the vibrational
    ! distribution of their eqs 4-5 about E_vm = X_vib D, the rotational one the
    ! mean of their eqs 6 and 7 about E_rot (eq. 3), and no molecules in a v
    ! whose E_rot is not positive (J. Takahashi, quoted there).
    !
    ! H-012, optional: where the binding energy D goes, per molecule formed
    ! [cm^-1]. eGrain is their energy left on the grain, E_dust(v) (their
    ! eq. 1-2 as Cloudy evaluates it), averaged over phi; eKin the kinetic
    ! energy the molecule leaves with, by energy conservation:
    ! D - E_dust(v) - E(v,J) averaged over phi. The internal energy E(v,J)
    ! is the populations' own business (formation pumping).
    !
    ! Adapted from Cloudy c25.00, source/mole_h2_create.cpp. Copyright (C)
    ! 1978-2025 Gary J. Ferland and others; zlib licence, reproduced in
    ! THIRD_PARTY_NOTICES.md. Altered for MOCASSIN-PDR by H. Monteiro, 2026: this
    ! is not Cloudy's original code.
    !---------------------------------------------------------------------------
    subroutine h2FormDist(surf, phi, eKin, eGrain)
      integer, intent(in) :: surf
      real(dp), intent(out) :: phi(:)
      real(dp), intent(out), optional :: eKin, eGrain
      real(dp) :: Evm, Ev, Edust, EH2, Erot, dE, sumvib, x
      real(dp), allocatable :: Fv(:), EH2v(:)
      integer :: v, vmax, i, i0

      vmax = maxval(h2V)
      allocate(Fv(0:vmax), EH2v(0:vmax))
      Evm = h2DissX*tuXvib(surf) + tuEoff
      do v = 0, vmax
         i0 = h2Level(v, 0)
         if (i0 == 0) stop '! h2FormDist: a vibrational state without J = 0'
         Ev = h2E(i0) + tuEoff
         Edust = h2DissX*tuXdust(surf)*(1._dp - (Ev - Evm)/(h2DissX + tuEoff - Evm)* &
              & (1._dp - tuXdust(surf))/2._dp)
         EH2v(v) = h2DissX + tuEoff - Edust
         if (Ev <= Evm) then
            x = (Ev - Evm)/(tuG1(surf)*Evm)
         else
            x = (Ev - Evm)/(tuG2(surf)*(EH2v(v) - Evm))
         end if
         Fv(v) = exp(-x*x)
      end do
      sumvib = sum(Fv)
      phi = 0._dp
      do i = 1, h2NX
         v = h2V(i); i0 = h2Level(v, 0)
         Ev = h2E(i0) + tuEoff
         Erot = (EH2v(v) - Ev)*tuXrot(surf)/(tuXrot(surf) + tuXtrans(surf))
         if (Erot <= 0._dp) cycle
         dE = h2E(i) - h2E(i0)
         x = (dE - Erot)/(0.5_dp*Erot)
         phi(i) = merge(3._dp, 1._dp, h2Ortho(i))*Fv(v)/sumvib*dble(2*h2J(i) + 1)* &
              & 0.5_dp*(exp(-x*x) + exp(-dE/Erot))
      end do
      phi = phi/sum(phi)
      ! E_dust(v) = D + E_off - EH2v(v)
      if (present(eGrain) .or. present(eKin)) then
         x = 0._dp; dE = 0._dp
         do i = 1, h2NX
            if (phi(i) <= 0._dp) cycle
            x  = x  + phi(i)*(h2DissX + tuEoff - EH2v(h2V(i)))
            dE = dE + phi(i)*h2E(i)
         end do
         if (present(eGrain)) eGrain = x
         if (present(eKin)) eKin = h2DissX - x - dE
      end if
      deallocate(Fv, EH2v)
    end subroutine h2FormDist

    ! a table's rate at T: linear in T, held at the ends (Cloudy's InterpCollRate)
    real(dp) function tabRate(ic, it, T)
      integer, intent(in) :: ic, it
      real(dp), intent(in) :: T
      integer :: i
      real(dp) :: f
      associate (tt => tab(ic)%T, kk => tab(ic)%k)
        if (T <= tt(1)) then
           tabRate = kk(it, 1)
        else if (T >= tt(tab(ic)%nT)) then
           tabRate = kk(it, tab(ic)%nT)
        else
           do i = 1, tab(ic)%nT - 1
              if (T < tt(i+1)) exit
           end do
           f = (T - tt(i))/(tt(i+1) - tt(i))
           tabRate = kk(it, i) + f*(kk(it, i+1) - kk(it, i))
        end if
      end associate
    end function tabRate

    ! The Voigt function H(a, x), Humlicek 1982 (JQSRT 27, 437), relative
    ! accuracy 1e-4
    real(dp) function h2Voigt(a, x)
      real(dp), intent(in) :: a, x
      complex(dp) :: t, u, w
      real(dp) :: sx
      t = cmplx(a, -x, dp)
      sx = abs(x) + a
      if (sx >= 15._dp) then
         w = t*0.5641896_dp/(0.5_dp + t*t)
      else if (sx >= 5.5_dp) then
         u = t*t
         w = t*(1.410474_dp + u*0.5641896_dp)/(0.75_dp + u*(3._dp + u))
      else if (a >= 0.195_dp*abs(x) - 0.176_dp) then
         w = (16.4955_dp + t*(20.20933_dp + t*(11.96482_dp + t*(3.778987_dp + t*0.5642236_dp))))/ &
              & (16.4955_dp + t*(38.82363_dp + t*(39.27121_dp + t*(21.69274_dp + t*(6.699398_dp + t)))))
      else
         u = t*t
         w = exp(u) - t*(36183.31_dp - u*(3321.9905_dp - u*(1540.787_dp - u*(219.0313_dp - &
              & u*(35.76683_dp - u*(1.320522_dp - u*0.56419_dp))))))/ &
              & (32066.6_dp - u*(24322.84_dp - u*(9022.228_dp - u*(2186.181_dp - u*(364.2191_dp - &
              & u*(61.57037_dp - u*(1.841439_dp - u)))))))
      end if
      h2Voigt = real(w, dp)
    end function h2Voigt

    ! S(tau0, a) and W(tau0, a) = int_0^tau0 S dt by quadrature over the
    ! profile: x linear to 6 Doppler widths, then logarithmic far past the
    ! point where the wing turns thin, with the rest of the wing added
    ! analytically.
    subroutine shieldQuad(tau0, a, S, W, xq)
      real(dp), intent(in) :: tau0, a
      real(dp), intent(out) :: S, W, xq(nShQ)
      integer, parameter :: nlin = 1200, nlog = 60     ! points to x = 6; per decade beyond
      real(dp) :: h0, x, xp, f, fp, g, gp, h, t, xmax, r, tot, target
      real(dp), allocatable :: xs(:), cs(:)
      integer :: i, n, k
      h0 = h2Voigt(a, 0._dp)
      xmax = max(60._dp, 300._dp*sqrt(tau0*a))
      S = 0._dp; W = 0._dp
      xp = 0._dp; fp = h0*exp(-tau0); gp = -expm1(-tau0)
      n = nlin + int(nlog*log10(xmax/6._dp)) + 1
      allocate(xs(0:n), cs(0:n))
      xs(0) = 0._dp; cs(0) = 0._dp
      r = (xmax/6._dp)**(1._dp/dble(n - nlin))
      do i = 1, n
         if (i <= nlin) then
            x = 6._dp*dble(i)/dble(nlin)
         else
            x = xp*r
         end if
         h = h2Voigt(a, x)
         t = tau0*h/h0
         f = h*exp(-t); g = -expm1(-t)
         S = S + 0.5_dp*(f + fp)*(x - xp)
         W = W + 0.5_dp*(g + gp)*(x - xp)
         xs(i) = x; cs(i) = S
         xp = x; fp = f; gp = g
      end do
      ! the quantiles of the absorption on one side, the far wing as a/(sqrt(pi) x^2)
      tot = S + a/(sqrt(pi)*xmax)
      do k = 1, nShQ
         target = shQ(k)*tot
         if (target >= S) then
            xq(k) = 1._dp/max(1._dp/xmax - (target - S)*sqrt(pi)/a, 1.e-30_dp)
         else
            do i = 1, n
               if (cs(i) >= target) exit
            end do
            xq(k) = xs(i-1) + (xs(i) - xs(i-1))*(target - cs(i-1))/max(cs(i) - cs(i-1), tiny(1._dp))
         end if
      end do
      deallocate(xs, cs)
      S = 2._dp/sqrt(pi)*(S + a/(sqrt(pi)*xmax))
      W = 2._dp*h0/sqrt(pi)*(W + tau0*a/(sqrt(pi)*h0*xmax))
    contains
      real(dp) function expm1(y)
        real(dp), intent(in) :: y
        if (abs(y) < 1.e-5_dp) then
           expm1 = y*(1._dp + 0.5_dp*y)
        else
           expm1 = exp(y) - 1._dp
        end if
      end function expm1
    end subroutine shieldQuad

    subroutine shieldTable()
      integer :: i, j
      real(dp) :: S, W, xq(nShQ)
      do j = 1, nShA
         do i = 1, nShT
            call shieldQuad(10._dp**(shT0 + (shT1 - shT0)*dble(i - 1)/dble(nShT - 1)), &
                 & 10._dp**(shA0 + (shA1 - shA0)*dble(j - 1)/dble(nShA - 1)), S, W, xq)
            shS(i, j) = log10(S); shW(i, j) = log10(W)
            shX(i, j, :) = log10(max(xq, 1.e-6_dp))
         end do
      end do
      lgShTab = .true.
    end subroutine shieldTable

    !---------------------------------------------------------------------------
    ! The fraction of a beam left in a Voigt line of central optical depth
    ! tau0 and damping parameter a, S; with dtau given, its mean through a
    ! layer that adds dtau to tau0. Bilinear in the logs of the table; below
    ! the table S = 1, beyond it the square-root wing.
    !---------------------------------------------------------------------------
    real(dp) function h2Shield(tau0, a, dtau)
      real(dp), intent(in) :: tau0, a
      real(dp), intent(in), optional :: dtau
      real(dp) :: w1, w2
      if (.not.lgShTab) call shieldTable()
      if (present(dtau)) then
         if (dtau > 1.e-3_dp*max(tau0, 1.e-3_dp)) then
            w1 = tabShield(shW, tau0, a, .true.)
            w2 = tabShield(shW, tau0 + dtau, a, .true.)
            h2Shield = min(1._dp, max(0._dp, (w2 - w1)/dtau))
            return
         end if
         h2Shield = tabShield(shS, tau0 + 0.5_dp*dtau, a, .false.)
         return
      end if
      h2Shield = tabShield(shS, tau0, a, .false.)
    end function h2Shield

    ! the offsets [Doppler widths] of a line's absorption (see shX)
    subroutine shieldOffsets(tau0, a, xq)
      real(dp), intent(in) :: tau0, a
      real(dp), intent(out) :: xq(nShQ)
      real(dp) :: lt, la, ft, fa, dlt, dla
      integer :: i, j, k
      if (.not.lgShTab) call shieldTable()
      dlt = (shT1 - shT0)/dble(nShT - 1); dla = (shA1 - shA0)/dble(nShA - 1)
      lt = min(max(log10(max(tau0, tiny(1._dp))), shT0), shT1)
      la = min(max(log10(max(a, tiny(1._dp))), shA0), shA1)
      i = min(int((lt - shT0)/dlt) + 1, nShT - 1)
      j = min(int((la - shA0)/dla) + 1, nShA - 1)
      ft = (lt - (shT0 + dlt*dble(i - 1)))/dlt
      fa = (la - (shA0 + dla*dble(j - 1)))/dla
      do k = 1, nShQ
         xq(k) = 10._dp**((1._dp - ft)*(1._dp - fa)*shX(i, j, k) + ft*(1._dp - fa)*shX(i + 1, j, k) + &
              & (1._dp - ft)*fa*shX(i, j + 1, k) + ft*fa*shX(i + 1, j + 1, k))
      end do
      ! past the table the wing: the offsets grow as tau0^1/2
      if (tau0 > 10._dp**shT1) xq = xq*sqrt(tau0/10._dp**shT1)
    end subroutine shieldOffsets

    real(dp) function tabShield(tab, tau0, a, lgW)
      real(dp), intent(in) :: tab(nShT, nShA), tau0, a
      logical, intent(in) :: lgW
      real(dp) :: fa
      integer :: j
      if (tau0 <= 10._dp**shT0) then
         tabShield = merge(tau0, 1._dp, lgW); return     ! thin: S = 1, W = tau0
      end if
      call h2ShieldAIndex(a, j, fa)
      tabShield = tabShieldJ(tab, tau0, j, fa, lgW)
    end function tabShield

    ! the damping parameter's place in the shielding table (column j and
    ! fraction fa), for callers that look up many tau0 at one a
    subroutine h2ShieldAIndex(a, j, fa)
      real(dp), intent(in) :: a
      integer, intent(out) :: j
      real(dp), intent(out) :: fa
      real(dp) :: la
      la = min(max(log10(max(a, tiny(1._dp))), shA0), shA1)
      j = min(int((la - shA0)/((shA1 - shA0)/dble(nShA - 1))) + 1, nShA - 1)
      fa = (la - (shA0 + (shA1 - shA0)*dble(j - 1)/dble(nShA - 1)))/((shA1 - shA0)/dble(nShA - 1))
    end subroutine h2ShieldAIndex

    ! tabShield with the damping's place given
    real(dp) function tabShieldJ(tab, tau0, j, fa, lgW)
      real(dp), intent(in) :: tab(nShT, nShA), tau0, fa
      integer, intent(in) :: j
      logical, intent(in) :: lgW
      real(dp) :: lt, ft, v, dlt
      integer :: i
      dlt = (shT1 - shT0)/dble(nShT - 1)
      if (tau0 <= 10._dp**shT0) then
         tabShieldJ = merge(tau0, 1._dp, lgW); return    ! thin: S = 1, W = tau0
      end if
      lt = min(log10(tau0), shT1)
      i = min(int((lt - shT0)/dlt) + 1, nShT - 1)
      ft = (lt - (shT0 + dlt*dble(i - 1)))/dlt
      v = (1._dp - ft)*(1._dp - fa)*tab(i, j) + ft*(1._dp - fa)*tab(i + 1, j) + &
           & (1._dp - ft)*fa*tab(i, j + 1) + ft*fa*tab(i + 1, j + 1)
      tabShieldJ = 10._dp**v
      ! past the table the wing: S ~ tau0^-1/2, W ~ tau0^1/2
      if (log10(tau0) > shT1) tabShieldJ = tabShieldJ*(tau0/10._dp**shT1)**merge(0.5_dp, -0.5_dp, lgW)
    end function tabShieldJ

    ! h2Shield with the damping's place in the table given (h2ShieldAIndex)
    real(dp) function h2ShieldJ(tau0, j, fa, dtau)
      real(dp), intent(in) :: tau0, fa, dtau
      integer, intent(in) :: j
      real(dp) :: w1, w2
      if (.not.lgShTab) call shieldTable()
      if (dtau > 1.e-3_dp*max(tau0, 1.e-3_dp)) then
         w1 = tabShieldJ(shW, tau0, j, fa, .true.)
         w2 = tabShieldJ(shW, tau0 + dtau, j, fa, .true.)
         h2ShieldJ = min(1._dp, max(0._dp, (w2 - w1)/dtau))
         return
      end if
      h2ShieldJ = tabShieldJ(shS, tau0 + 0.5_dp*dtau, j, fa, .false.)
    end function h2ShieldJ

    !---------------------------------------------------------------------------
    ! H-011: h2LineShield for a caller that iterates on the column of its own
    ! cell. h2LineShieldPrep takes the path's column Ncol and the Doppler
    ! parameter b and keeps what depends on them alone (each line's tau0,
    ! W(tau0) and the damping's place in the table); h2LineShieldEval then
    ! gives, for the cell's own column dNcol, what h2LineShield(Ncol, b,
    ! shield, dNcol, overlap=overlap) would.
    !---------------------------------------------------------------------------
    subroutine h2LineShieldPrep(Ncol, b)
      real(dp), intent(in) :: Ncol(:), b
      real(dp) :: sig, a
      integer :: i
      if (.not.lgShTab) call shieldTable()
      if (.not.allocated(psSig)) allocate(psSig(h2NT), psT(h2NT), psW0(h2NT), psFa(h2NT), psJ(h2NT))
      do i = 1, h2NT
         call h2LineParams(i, b, sig, a)
         psSig(i) = sig
         psT(i) = Ncol(h2tL(i))*sig
         call h2ShieldAIndex(a, psJ(i), psFa(i))
         psW0(i) = tabShieldJ(shW, psT(i), psJ(i), psFa(i), .true.)
      end do
    end subroutine h2LineShieldPrep

    subroutine h2LineShieldEval(dNcol, shield, overlap)
      real(dp), intent(in) :: dNcol(:), overlap(:)
      real(dp), intent(out) :: shield(:)
      real(dp) :: t, dt, w2
      integer :: i
      do i = 1, h2NT
         t = psT(i)
         dt = dNcol(h2tL(i))*psSig(i)
         if (dt > 1.e-3_dp*max(t, 1.e-3_dp)) then
            w2 = tabShieldJ(shW, t + dt, psJ(i), psFa(i), .true.)
            shield(i) = min(1._dp, max(0._dp, (w2 - psW0(i))/dt))
         else
            shield(i) = tabShieldJ(shS, t + 0.5_dp*dt, psJ(i), psFa(i), .false.)
         end if
         shield(i) = shield(i)*overlap(i)
      end do
    end subroutine h2LineShieldEval

    !---------------------------------------------------------------------------
    ! Cloudy's default line shielding, for the like-for-like check only: the
    ! fit of Federman, Glassgold & Kwan 1979 (ApJ 227, 466, appendix) as
    ! rt_continuum_shield_fcn.cpp applies it - Doppler core by their eq. A8,
    ! wings by A6 at sqrt(pi) tau, the sum held at 1.
    !
    ! Translated from Cloudy c25.00, source/rt_continuum_shield_fcn.cpp,
    ! shieldFederman. Copyright (C) 1978-2025 Gary J. Ferland and others; zlib
    ! licence, reproduced in THIRD_PARTY_NOTICES.md. Altered for MOCASSIN-PDR by
    ! H. Monteiro, 2026: this is not Cloudy's original code.
    !---------------------------------------------------------------------------
    real(dp) function h2ShieldFederman(tau, a)
      real(dp), intent(in) :: tau, a
      real(dp) :: core, wings, t1, u1
      if (tau < 2._dp) then
         core = exp(-tau*0.66666_dp)
      else if (tau < 10._dp) then
         core = 0.638_dp*tau**(-1.25_dp)
      else if (tau < 100._dp) then
         core = 0.505_dp*tau**(-1.15_dp)
      else
         core = 0.344_dp*tau**(-1.0667_dp)
      end if
      wings = 0._dp
      if (a > 0._dp) then
         t1 = 3.02_dp*(a*1.e3_dp)**(-0.064_dp)
         u1 = sqrt(max(tau*sqrt(pi), 0._dp)*a)/t1
         wings = a/t1/sqrt(0.78540_dp + u1*u1)
      end if
      h2ShieldFederman = min(1._dp, core + wings)
    end function h2ShieldFederman

    !---------------------------------------------------------------------------
    ! Shielding of every pumping line by the H2 between the source and the
    ! point: its own (h2Shield) times the other lines' (lineOverlap).
    ! Ncol(1:h2NX): column of each X level [cm^-2]; b: Doppler parameter
    ! [cm s^-1]. Optional:
    !   dNcol    the column of the cell itself; the line's own shielding is
    !            then averaged over it and the others' taken at mid-cell
    !   tau0     the central optical depths at Ncol
    !   own      the line's own shielding, without overlap
    !   overlap  overlap factors already in hand (h2LineOverlap), used instead
    !            of computing them
    !---------------------------------------------------------------------------
    subroutine h2LineShield(Ncol, b, shield, dNcol, tau0, own, overlap)
      real(dp), intent(in) :: Ncol(:), b
      real(dp), intent(out) :: shield(:)
      real(dp), intent(in), optional :: dNcol(:)
      real(dp), intent(out), optional :: tau0(:), own(:)
      real(dp), intent(in), optional :: overlap(:)
      real(dp) :: sig, a, t, dt
      real(dp), allocatable :: tm(:), aa(:), ov(:)
      integer :: i
      allocate(tm(h2NT), aa(h2NT), ov(h2NT))
      do i = 1, h2NT
         call h2LineParams(i, b, sig, a)
         t = Ncol(h2tL(i))*sig
         if (present(tau0)) tau0(i) = t
         aa(i) = a
         if (present(dNcol)) then
            dt = dNcol(h2tL(i))*sig
            shield(i) = h2Shield(t, a, dt)
            tm(i) = t + 0.5_dp*dt
         else
            shield(i) = h2Shield(t, a)
            tm(i) = t
         end if
      end do
      if (present(own)) own(1:h2NT) = shield(1:h2NT)
      if (present(overlap)) then
         ! the caller's overlap factors, from h2LineOverlap on nearly the same columns
         shield(1:h2NT) = shield(1:h2NT)*overlap(1:h2NT)
      else
         call lineOverlap(tm, aa, b, ov)
         shield(1:h2NT) = shield(1:h2NT)*ov
      end if
      deallocate(tm, aa, ov)
    end subroutine h2LineShield

    ! The overlap factor of every line for the columns Ncol (lineOverlap), for
    ! a caller that iterates on a cell and need not redo it each time: the
    ! factor moves little while the cell's own populations settle.
    subroutine h2LineOverlap(Ncol, b, ov)
      real(dp), intent(in) :: Ncol(:), b
      real(dp), intent(out) :: ov(:)
      real(dp) :: sig
      real(dp), allocatable :: tm(:), aa(:)
      integer :: i
      allocate(tm(h2NT), aa(h2NT))
      do i = 1, h2NT
         call h2LineParams(i, b, sig, aa(i))
         tm(i) = Ncol(h2tL(i))*sig
      end do
      call lineOverlap(tm, aa, b, ov)
      deallocate(tm, aa)
    end subroutine h2LineOverlap

    !---------------------------------------------------------------------------
    ! H-006: line overlap. The other lines' optical depth where line i does its
    ! absorbing cuts its pumping further:
    !     S_i = int phi_i exp(-tau_i) exp(-tau_others) dnu
    !         ~ S(tau_i, a_i) x mean of exp(-tau_others) over line i's absorption.
    ! The mean is a quadrature on six points, three on each side of the line at
    ! the offsets where a sixth, a half and five sixths of that side's
    ! absorption has happened (tabulated with S), so that a thin line samples
    ! its core and a damped line its wings. tau_others at a point is the sum
    ! of the other lines' Voigt profiles there: the full function within 12 of
    ! the other line's Doppler widths, its Lorentzian wing beyond, dropped
    ! below ovEps. tau0(i), a(i): each line's own; ov(i): the factor.
    !
    ! Checked against the same integral done on a fine frequency grid
    ! (tools/h006_exact.py). Not in it: a photon absorbed in another line's
    ! wing is counted as lost, not as a pump of that line.
    !---------------------------------------------------------------------------
    subroutine lineOverlap(tau0, a, b, ov)
      real(dp), intent(in) :: tau0(:), a(:), b
      real(dp), intent(out) :: ov(:)
      real(dp), allocatable :: bWn(:), bDop(:), bT(:), bA(:), bReach(:)
      real(dp), allocatable :: lWn(:), lC(:), sWn(:), sDop(:), sT(:), sA(:), sReach(:)
      integer, allocatable :: bLine(:), sLine(:), lPos(:)
      real(dp) :: xq(nShQ), dop, nu, tc, rNear, rr, wc
      integer :: nB, nL, nS, i, j, k, m, is, lo, hi, m1, li, kord, pL1, pL2, pS1, pS2, pS3, pS4
      integer, allocatable :: cnt(:)
      logical, allocatable :: mark(:)

      nB = count(tau0(1:h2NT) >= ovTauB)
      ov(1:h2NT) = 1._dp
      if (nB == 0) return
      allocate(bWn(nB), bDop(nB), bT(nB), bA(nB), bReach(nB), bLine(nB))
      allocate(lWn(nB), lC(nB), sWn(nB), sDop(nB), sT(nB), sA(nB), sReach(nB), sLine(nB), lPos(h2NT))
      ! the lines that shade, in wavenumber order; then those of them that
      ! reach beyond ovLong (long: only their Lorentzian wing is used far
      ! out, as a coefficient over the distance squared) and the rest
      ! (short), each in a list of its own, also in wavenumber order
      m = 0; nL = 0; nS = 0
      lPos = 0
      do k = 1, h2NT
         j = ordWN(k)
         if (tau0(j) < ovTauB) cycle
         m = m + 1
         bLine(m) = j; bWn(m) = h2tWN(j); bDop(m) = h2tWN(j)*b/cLight; bA(m) = a(j)
         bT(m) = tau0(j)/h2Voigt(a(j), 0._dp)
         bReach(m) = bDop(m)*max(12._dp, sqrt(bT(m)*a(j)/(sqrt(pi)*ovEps)))
         if (bReach(m) > ovLong) then
            nL = nL + 1
            lWn(nL) = bWn(m); lC(nL) = bT(m)*bA(m)*bDop(m)**2/sqrt(pi); lPos(j) = nL
         else
            nS = nS + 1
            sWn(nS) = bWn(m); sDop(nS) = bDop(m); sT(nS) = bT(m); sA(nS) = bA(m)
            sReach(nS) = bReach(m); sLine(nS) = j
         end if
      end do

      ! which lines any shading line reaches (the rest keep ov = 1): the thick
      ! lines, whose own absorption lies far out, and every line within a
      ! shading line's reach plus a thin line's own few Doppler widths
      allocate(cnt(h2NT + 1), mark(h2NT))
      cnt = 0
      do m = 1, nB
         rr = bReach(m) + 3._dp*bDop(m)
         lo = lowerL(bWn(m) - rr); hi = lowerL(bWn(m) + rr) - 1
         if (hi >= lo) then
            cnt(lo) = cnt(lo) + 1; cnt(hi + 1) = cnt(hi + 1) - 1
         end if
      end do
      k = 0
      do j = 1, h2NT
         k = k + cnt(j)
         mark(ordWN(j)) = (k > 0)
      end do
      deallocate(cnt)

      ! the lines in wavenumber order: a thin line's windows (all centred on
      ! it, all widening with it) then only move forward, and are followed
      ! by pointers instead of searched for
      pL1 = 1; pL2 = 1; pS1 = 1; pS2 = 1; pS3 = 1; pS4 = 1; m1 = 1
      do kord = 1, h2NT
         i = ordWN(kord)
         if (.not.mark(i) .and. tau0(i) < 1._dp) cycle
         dop = h2tWN(i)*b/cLight
         rNear = ovNear*dop
         li = lPos(i)
         call shieldOffsets(tau0(i), a(i), xq)
         ov(i) = 0._dp
         if (tau0(i) < 1._dp) then
            ! a thin line absorbs within its core: what lies far from it is the
            ! same at all six points, and so is the near window
            wc = h2tWN(i)
            do while (pL1 <= nL)
               if (lWn(pL1) >= wc - rNear) exit
               pL1 = pL1 + 1
            end do
            do while (pL2 <= nL)
               if (lWn(pL2) > wc + rNear) exit
               pL2 = pL2 + 1
            end do
            do while (pS1 <= nS)
               if (sWn(pS1) >= wc - ovLong) exit
               pS1 = pS1 + 1
            end do
            do while (pS2 <= nS)
               if (sWn(pS2) >= wc - rNear) exit
               pS2 = pS2 + 1
            end do
            do while (pS3 <= nS)
               if (sWn(pS3) > wc + rNear) exit
               pS3 = pS3 + 1
            end do
            do while (pS4 <= nS)
               if (sWn(pS4) > wc + ovLong) exit
               pS4 = pS4 + 1
            end do
            do while (m1 <= nB)
               if (bWn(m1) >= wc - rNear) exit
               m1 = m1 + 1
            end do
            tc = farSumAt(wc, pL1, pL2, pS1, pS2, pS3, pS4)
            do k = 1, nShQ
               do is = -1, 1, 2
                  nu = h2tWN(i) + dble(is)*xq(k)*dop
                  ov(i) = ov(i) + exp(-(tc + nearSum(m1, nu, wc)))
               end do
            end do
         else
            do k = 1, nShQ
               do is = -1, 1, 2
                  nu = h2tWN(i) + dble(is)*xq(k)*dop
                  ov(i) = ov(i) + exp(-(farSum(nu, nu) + nearSum(firstGE(bWn, nB, nu - rNear), nu, nu)))
               end do
            end do
         end if
         ov(i) = ov(i)/dble(2*nShQ)
      end do
      deallocate(bWn, bDop, bT, bA, bReach, bLine, lWn, lC, sWn, sDop, sT, sA, sReach, sLine, lPos, mark)

    contains

      ! first line, in wavenumber order, at or above wavenumber w
      integer function lowerL(w)
        real(dp), intent(in) :: w
        integer :: l1, l2, lm
        l1 = 1; l2 = h2NT + 1
        do while (l1 < l2)
           lm = (l1 + l2)/2
           if (wnSort(lm) < w) then
              l1 = lm + 1
           else
              l2 = lm
           end if
        end do
        lowerL = l1
      end function lowerL

      ! first entry of the ascending list v(1:n) at or above w (n + 1 if none)
      integer function firstGE(v, n, w)
        real(dp), intent(in) :: v(:), w
        integer, intent(in) :: n
        integer :: l1, l2, lm
        l1 = 1; l2 = n + 1
        do while (l1 < l2)
           lm = (l1 + l2)/2
           if (v(lm) < w) then
              l1 = lm + 1
           else
              l2 = lm
           end if
        end do
        firstGE = l1
      end function firstGE

      ! first entry of the ascending list v(1:n) above w (n + 1 if none)
      integer function firstGT(v, n, w)
        real(dp), intent(in) :: v(:), w
        integer, intent(in) :: n
        integer :: l1, l2, lm
        l1 = 1; l2 = n + 1
        do while (l1 < l2)
           lm = (l1 + l2)/2
           if (v(lm) <= w) then
              l1 = lm + 1
           else
              l2 = lm
           end if
        end do
        firstGT = l1
      end function firstGT

      ! a shading line's optical depth at w: blocker mm of the full list
      real(dp) function tauAt(mm, w)
        integer, intent(in) :: mm
        real(dp), intent(in) :: w
        real(dp) :: x
        x = (w - bWn(mm))/bDop(mm)
        if (abs(x) > 12._dp) then
           tauAt = bT(mm)*bA(mm)/(sqrt(pi)*x*x)
        else
           tauAt = bT(mm)*h2Voigt(bA(mm), x)
        end if
      end function tauAt

      ! the shading lines within rNear of wc, from the first of them, m1, evaluated at w
      real(dp) function nearSum(m1, w, wc)
        integer, intent(in) :: m1
        real(dp), intent(in) :: w, wc
        integer :: mm
        nearSum = 0._dp
        mm = m1
        do while (mm <= nB)
           if (bWn(mm) > wc + rNear) exit
           if (bLine(mm) /= i) nearSum = nearSum + tauAt(mm, w)
           mm = mm + 1
        end do
      end function nearSum

      ! the long lines' wings over lC(lo:hi), at w; four partial sums
      real(dp) function longWing(lo, hi, w)
        integer, intent(in) :: lo, hi
        real(dp), intent(in) :: w
        real(dp) :: s1, s2, s3, s4, d1, d2, d3, d4
        integer :: kk
        s1 = 0._dp; s2 = 0._dp; s3 = 0._dp; s4 = 0._dp
        kk = lo
        do while (kk + 3 <= hi)
           d1 = w - lWn(kk); d2 = w - lWn(kk+1); d3 = w - lWn(kk+2); d4 = w - lWn(kk+3)
           s1 = s1 + lC(kk)/(d1*d1); s2 = s2 + lC(kk+1)/(d2*d2)
           s3 = s3 + lC(kk+2)/(d3*d3); s4 = s4 + lC(kk+3)/(d4*d4)
           kk = kk + 4
        end do
        do while (kk <= hi)
           d1 = w - lWn(kk)
           s1 = s1 + lC(kk)/(d1*d1)
           kk = kk + 1
        end do
        longWing = (s1 + s2) + (s3 + s4)
      end function longWing

      ! the shading lines farther than rNear from wc, evaluated at w: every
      ! long line (its Lorentzian wing), and the short ones within ovLong of
      ! wc that reach w; line i itself left out
      real(dp) function farSum(w, wc)
        real(dp), intent(in) :: w, wc
        farSum = farSumAt(w, firstGE(lWn, nL, wc - rNear), firstGT(lWn, nL, wc + rNear), &
             & firstGE(sWn, nS, wc - ovLong), firstGE(sWn, nS, wc - rNear), &
             & firstGT(sWn, nS, wc + rNear), firstGT(sWn, nS, wc + ovLong))
      end function farSum

      ! farSum with its windows given: long lines k1..k2-1 within rNear of
      ! wc; short lines s1..s2-1 below it and s3..s4-1 above it within ovLong
      real(dp) function farSumAt(w, k1, k2, s1, s2, s3, s4)
        real(dp), intent(in) :: w
        integer, intent(in) :: k1, k2, s1, s2, s3, s4
        integer :: mm
        ! long lines outside the window, two ranges, line i cut out
        if (li > 0 .and. li < k1) then
           farSumAt = longWing(1, li - 1, w) + longWing(li + 1, k1 - 1, w)
        else
           farSumAt = longWing(1, k1 - 1, w)
        end if
        if (li >= k2) then
           farSumAt = farSumAt + longWing(k2, li - 1, w) + longWing(li + 1, nL, w)
        else
           farSumAt = farSumAt + longWing(k2, nL, w)
        end if
        ! short lines with rNear < |nu - wc| <= ovLong that reach w
        do mm = s1, s2 - 1
           if (sLine(mm) /= i .and. abs(w - sWn(mm)) < sReach(mm)) farSumAt = farSumAt + tauS(mm, w)
        end do
        do mm = s3, s4 - 1
           if (sLine(mm) /= i .and. abs(w - sWn(mm)) < sReach(mm)) farSumAt = farSumAt + tauS(mm, w)
        end do
      end function farSumAt

      ! a short shading line's optical depth at w
      real(dp) function tauS(mm, w)
        integer, intent(in) :: mm
        real(dp), intent(in) :: w
        real(dp) :: x
        x = (w - sWn(mm))/sDop(mm)
        if (abs(x) > 12._dp) then
           tauS = sT(mm)*sA(mm)/(sqrt(pi)*x*x)
        else
           tauS = sT(mm)*h2Voigt(sA(mm), x)
        end if
      end function tauS

    end subroutine lineOverlap

    ! index sort (heapsort): ord such that key(ord) ascends
    subroutine indexSort(n, key, ord)
      integer, intent(in) :: n
      real(dp), intent(in) :: key(n)
      integer, intent(out) :: ord(n)
      integer :: i, ir, j, l, it
      do i = 1, n
         ord(i) = i
      end do
      if (n < 2) return
      l = n/2 + 1; ir = n
      do
         if (l > 1) then
            l = l - 1; it = ord(l)
         else
            it = ord(ir); ord(ir) = ord(1); ir = ir - 1
            if (ir == 1) then
               ord(1) = it; exit
            end if
         end if
         i = l; j = l + l
         do while (j <= ir)
            if (j < ir) then
               if (key(ord(j)) < key(ord(j+1))) j = j + 1
            end if
            if (key(it) < key(ord(j))) then
               ord(i) = ord(j); i = j; j = j + j
            else
               j = ir + 1
            end if
         end do
         ord(i) = it
      end do
    end subroutine indexSort

    ! line i at Doppler parameter b [cm s^-1]: cross-section at line centre
    ! [cm^2] and damping parameter
    subroutine h2LineParams(i, b, sig, a)
      integer, intent(in) :: i
      real(dp), intent(in) :: b
      real(dp), intent(out) :: sig, a
      real(dp) :: lam
      lam = 1._dp/h2tWN(i)
      sig = h2uG(h2tU(i))/h2G(h2tL(i))*h2tA(i)*lam**3/(8._dp*pi**1.5_dp*b)
      a = (h2uAtot(h2tU(i)) + h2uDiss(h2tU(i)))*lam/(4._dp*pi*b)
    end subroutine h2LineParams

    !---------------------------------------------------------------------------
    ! Escape probability of every line: the mean over the directions given of
    ! the chance that a photon emitted in the line (with the line's own
    ! profile) crosses the H2 column of the line's lower level in that
    ! direction, which is the same function S. Ncol(1:h2NX, 1:ndir) [cm^-2].
    !---------------------------------------------------------------------------
    subroutine h2LineEscape(Ncol, b, beta)
      real(dp), intent(in) :: Ncol(:,:), b
      real(dp), intent(out) :: beta(:)
      real(dp) :: sig, a, fa
      integer :: i, k, nd, j
      if (.not.lgShTab) call shieldTable()
      nd = size(Ncol, 2)
      do i = 1, h2NT
         call h2LineParams(i, b, sig, a)
         ! the damping's place in the table, once for the line's directions
         call h2ShieldAIndex(a, j, fa)
         beta(i) = 0._dp
         do k = 1, nd
            beta(i) = beta(i) + tabShieldJ(shS, Ncol(h2tL(i), k)*sig, j, fa, .false.)
         end do
         beta(i) = beta(i)/dble(nd)
      end do
    end subroutine h2LineEscape

    ! Collisions among the X levels and their radiative decay at temperature T
    ! with collider densities dens(1:5) [cm^-3] (H, He, o-H2, p-H2, H+):
    ! R(i,j), the rate from level i to level j [s^-1].
    ! The rate coefficients and Boltzmann factors depend on T alone and are
    ! kept from the last call (crKd, crBf at crT): a caller that iterates on
    ! the colliders' densities at one temperature builds them once.
    subroutine h2CollRad(T, dens, R)
      real(dp), intent(in) :: T, dens(h2NColl)
      real(dp), intent(out) :: R(:,:)
      real(dp) :: dE, kgb
      integer :: n, ic, it, iu, il

      n = h2NX
      if (.not.allocated(crKd)) then
         allocate(crKd(n, n, h2NColl), crBf(n, n))
         crT = -1._dp
      end if
      if (T /= crT) then
         do ic = 1, h2NColl
            crKd(:, :, ic) = 0._dp
            do it = 1, tab(ic)%nTr
               crKd(tab(ic)%up(it), tab(ic)%lo(it), ic) = tabRate(ic, it, T)
            end do
            do iu = 2, n
               do il = 1, iu - 1
                  if (crKd(iu, il, ic) == 0._dp .and. (h2Ortho(iu) .eqv. h2Ortho(il))) then
                     dE = max(100._dp, h2E(iu) - h2E(il))
                     kgb = 10._dp**(gbar(1,ic) + gbar(2,ic)*dE**gbar(3,ic))
                     crKd(iu, il, ic) = kgb
                  end if
               end do
            end do
         end do
         do iu = 2, n
            do il = 1, iu - 1
               crBf(iu, il) = exp(-hcK*(h2E(iu) - h2E(il))/T)
            end do
         end do
         crT = T
      end if
      R = 0._dp
      do ic = 1, h2NColl
         if (dens(ic) <= 0._dp) cycle
         do iu = 2, n
            do il = 1, iu - 1
               if (crKd(iu, il, ic) <= 0._dp) cycle
               R(iu, il) = R(iu, il) + dens(ic)*crKd(iu, il, ic)
               R(il, iu) = R(il, iu) + dens(ic)*crKd(iu, il, ic)*h2G(iu)/h2G(il)*crBf(iu, il)
            end do
         end do
      end do
      R = R + h2A                                  ! radiative decay, upper -> lower
    end subroutine h2CollRad

    !---------------------------------------------------------------------------
    ! H-012: the net heating of the gas by collisions within X, per molecule
    ! [erg s^-1], for populations pops (fractions) at temperature T with
    ! collider densities dens: every downward collision gives its level
    ! difference to the gas, every upward one takes it (detailed balance), as
    ! Cloudy's HeatDexc. Positive where pumping keeps the levels above their
    ! Boltzmann ratio, negative (cooling) where the gas is hotter than they are.
    !---------------------------------------------------------------------------
    real(dp) function h2CollHeat(T, dens, pops)
      real(dp), intent(in) :: T, dens(h2NColl), pops(:)
      real(dp), allocatable :: R(:,:)
      real(dp) :: s, kdn
      integer :: ic, iu, il
      ! the coefficients and Boltzmann factors of h2CollRad at T
      if (.not.allocated(crKd) .or. T /= crT) then
         allocate(R(h2NX, h2NX))
         call h2CollRad(T, dens, R)
         deallocate(R)
      end if
      s = 0._dp
      do ic = 1, h2NColl
         if (dens(ic) <= 0._dp) cycle
         do iu = 2, h2NX
            do il = 1, iu - 1
               if (crKd(iu, il, ic) <= 0._dp) cycle
               kdn = dens(ic)*crKd(iu, il, ic)
               s = s + kdn*(pops(iu) - pops(il)*h2G(iu)/h2G(il)*crBf(iu, il))*(h2E(iu) - h2E(il))
            end do
         end do
      end do
      h2CollHeat = s*hPl*cLight
    end function h2CollHeat

    ! Statistical equilibrium for rates R(i,j) [s^-1] between the levels, a
    ! destruction rate k(i) [s^-1] out of each, and formation: each molecule
    ! destroyed is replaced by one formed in the distribution phi (sum 1), plus
    ! src(i) [s^-1 per H2] if given.
    !   sum_j n_j R(j,i) - n_i (sum_j R(i,j) + k_i) + phi_i sum_j n_j k_j + src_i = 0
    ! Level 1's equation is replaced by sum n = 1.
    subroutine balance(R, k, phi, pops, src)
      real(dp), intent(in) :: R(:,:), k(:), phi(:)
      real(dp), intent(out) :: pops(:)
      real(dp), intent(in), optional :: src(:)
      real(dp), allocatable :: M(:,:), b(:)
      integer :: n, i, j

      n = h2NX
      allocate(M(n, n), b(n))
      do i = 1, n
         do j = 1, n
            M(i, j) = R(j, i) + phi(i)*k(j)
         end do
         M(i, i) = -(sum(R(i, :)) - R(i, i)) - k(i) + phi(i)*k(i)
      end do
      b = 0._dp
      if (present(src)) b = -src(1:n)
      M(1, :) = 1._dp; b(1) = 1._dp
      call gaussSolve(n, M, b)
      pops(1:n) = b
      deallocate(M, b)
    end subroutine balance

    !---------------------------------------------------------------------------
    ! H-003: populations of the X levels (fractions, summing to 1) under
    ! collisions and radiative decay alone. rateOut(i), optional: the total
    ! rate out of level i [s^-1].
    !---------------------------------------------------------------------------
    subroutine h2SolveX(T, dens, pops, rateOut)
      real(dp), intent(in) :: T, dens(h2NColl)
      real(dp), intent(out) :: pops(:)
      real(dp), intent(out), optional :: rateOut(:)
      real(dp), allocatable :: R(:,:), zero(:)
      integer :: i

      allocate(R(h2NX, h2NX), zero(h2NX))
      zero = 0._dp
      call h2CollRad(T, dens, R)
      if (present(rateOut)) then
         do i = 1, h2NX
            rateOut(i) = sum(R(i, :)) - R(i, i)
         end do
      end if
      call balance(R, zero, zero, pops)
      deallocate(R, zero)
    end subroutine h2SolveX

    !---------------------------------------------------------------------------
    ! H-004: populations of the X levels (fractions, summing to 1) under
    ! collisions, radiative decay, and pumping by a field of occupation number
    ! eta(1:h2NT) at the lines to the excited states (see h2PumpRates). The
    ! molecules the pumping dissociates, and those that sink(i) [s^-1] removes
    ! if given, are replaced by newly formed ones in the distribution phi.
    !   kdiss(i)  Solomon dissociation rate out of level i [s^-1]
    !   pump(i)   absorption rate out of level i [s^-1]
    !   src(i)    further formation into level i, per H2 [s^-1]
    !   beta(t)   escape probability of each line (see h2PumpRates)
    !   heatDis(i) kinetic energy the dissociations out of level i leave in
    !             the gas, per molecule in i [eV s^-1] (see h2PumpRates)
    !---------------------------------------------------------------------------
    subroutine h2Solve(T, dens, eta, phi, pops, kdiss, pump, sink, src, beta, heatDis)
      real(dp), intent(in) :: T, dens(h2NColl), eta(:), phi(:)
      real(dp), intent(out) :: pops(:)
      real(dp), intent(out), optional :: kdiss(:), pump(:), heatDis(:)
      real(dp), intent(in), optional :: sink(:), src(:), beta(:)
      real(dp), allocatable :: R(:,:), W(:,:), k(:), pm(:)

      allocate(R(h2NX, h2NX), W(h2NX, h2NX), k(h2NX), pm(h2NX))
      call h2CollRad(T, dens, R)
      ! an absent optional passes on as absent
      call h2PumpRates(eta, W, k, pm, beta, heatDis)
      R = R + W
      if (present(kdiss)) kdiss(1:h2NX) = k
      if (present(pump)) pump(1:h2NX) = pm
      if (present(sink)) k = k + sink(1:h2NX)
      call balance(R, k, phi, pops, src)
      deallocate(R, W, k, pm)
    end subroutine h2Solve

    ! Gaussian elimination with partial pivoting, solution returned in b
    subroutine gaussSolve(n, a, b)
      integer, intent(in) :: n
      real(dp), intent(inout) :: a(n, n), b(n)
      integer :: i, j, k, p
      real(dp) :: f, t
      real(dp) :: rowt(n), fm(n)
      do k = 1, n - 1
         p = k - 1 + maxloc(abs(a(k:n, k)), 1)
         if (p /= k) then
            rowt = a(k, :); a(k, :) = a(p, :); a(p, :) = rowt
            t = b(k); b(k) = b(p); b(p) = t
         end if
         if (a(k, k) == 0._dp) cycle
         ! the multipliers, then the rows below updated a column at a time
         ! (memory order); each element gets the same operations as row by
         ! row, a zero multiplier changing nothing
         do i = k + 1, n
            fm(i) = a(i, k)/a(k, k)
         end do
         do j = k, n
            f = a(k, j)
            do i = k + 1, n
               a(i, j) = a(i, j) - fm(i)*f
            end do
         end do
         do i = k + 1, n
            if (fm(i) /= 0._dp) b(i) = b(i) - fm(i)*b(k)
         end do
      end do
      do i = n, 1, -1
         b(i) = (b(i) - sum(a(i, i+1:n)*b(i+1:n)))/a(i, i)
      end do
    end subroutine gaussSolve

end module h2_mod
