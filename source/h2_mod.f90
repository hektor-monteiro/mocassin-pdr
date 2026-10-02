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
! It is a re-implementation from those equations and data, not a translation
! of Cloudy's source.
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
! Not yet in: destruction other than the Solomon process, formation by H- and
! H2+, cosmic rays, self-shielding, and electrons as colliders, which Aleman &
! Gruenwald 2011 include and Cloudy does not.
!===============================================================================
module h2_mod
    implicit none
    private

    integer, parameter :: dp = kind(1.d0)
    integer, parameter, public :: h2NColl = 5          ! H, He, o-H2, p-H2, H+
    character(len=4), parameter, public :: h2CollName(h2NColl) = &
         & (/'H   ', 'He  ', 'oH2 ', 'pH2 ', 'H+  '/)
    real(dp), parameter :: hcK = 1.4387769_dp           ! hc/k [cm K]

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

    public :: h2ReadX, h2ReadElec, h2SolveX, h2Solve, h2Level, h2PumpRates, h2FormDist, h2CollRad

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
    !---------------------------------------------------------------------------
    subroutine h2PumpRates(eta, W, kdiss, pump)
      real(dp), intent(in) :: eta(:)
      real(dp), intent(out) :: W(:,:), kdiss(:)
      real(dp), intent(out), optional :: pump(:)
      real(dp) :: gam, P
      integer :: u, t, t2

      W = 0._dp; kdiss = 0._dp
      if (present(pump)) pump = 0._dp
      do u = 1, h2NU
         if (uLast(u) < uFirst(u)) cycle
         gam = h2uDiss(u)
         do t = uFirst(u), uLast(u)
            gam = gam + h2tA(t)*(1._dp + eta(t))
         end do
         if (gam <= 0._dp) cycle
         do t = uFirst(u), uLast(u)
            if (eta(t) <= 0._dp) cycle
            P = h2tA(t)*h2uG(u)/h2G(h2tL(t))*eta(t)
            if (present(pump)) pump(h2tL(t)) = pump(h2tL(t)) + P
            kdiss(h2tL(t)) = kdiss(h2tL(t)) + P*h2uDiss(u)/gam
            do t2 = uFirst(u), uLast(u)
               W(h2tL(t), h2tL(t2)) = W(h2tL(t), h2tL(t2)) + P*h2tA(t2)*(1._dp + eta(t2))/gam
            end do
         end do
      end do
    end subroutine h2PumpRates

    !---------------------------------------------------------------------------
    ! The (v, J) distribution of H2 newly formed on a grain surface, summing to
    ! 1: Takahashi & Uehara 2001 (ApJ 561, 843), surf = 1 ice, 2 silicate,
    ! 3 carbonaceous, as Cloudy applies it (mole_h2_create.cpp): the vibrational
    ! distribution of their eqs 4-5 about E_vm = X_vib D, the rotational one the
    ! mean of their eqs 6 and 7 about E_rot (eq. 3), and no molecules in a v
    ! whose E_rot is not positive (J. Takahashi, quoted there).
    !---------------------------------------------------------------------------
    subroutine h2FormDist(surf, phi)
      integer, intent(in) :: surf
      real(dp), intent(out) :: phi(:)
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

    ! Collisions among the X levels and their radiative decay at temperature T
    ! with collider densities dens(1:5) [cm^-3] (H, He, o-H2, p-H2, H+):
    ! R(i,j), the rate from level i to level j [s^-1].
    subroutine h2CollRad(T, dens, R)
      real(dp), intent(in) :: T, dens(h2NColl)
      real(dp), intent(out) :: R(:,:)
      real(dp), allocatable :: kd(:,:)
      real(dp) :: dE, kgb
      integer :: n, ic, it, iu, il

      n = h2NX
      allocate(kd(n, n))
      R = 0._dp
      do ic = 1, h2NColl
         if (dens(ic) <= 0._dp) cycle
         kd = 0._dp
         do it = 1, tab(ic)%nTr
            kd(tab(ic)%up(it), tab(ic)%lo(it)) = tabRate(ic, it, T)
         end do
         do iu = 2, n
            do il = 1, iu - 1
               if (kd(iu, il) == 0._dp .and. (h2Ortho(iu) .eqv. h2Ortho(il))) then
                  dE = max(100._dp, h2E(iu) - h2E(il))
                  kgb = 10._dp**(gbar(1,ic) + gbar(2,ic)*dE**gbar(3,ic))
                  kd(iu, il) = kgb
               end if
               if (kd(iu, il) <= 0._dp) cycle
               R(iu, il) = R(iu, il) + dens(ic)*kd(iu, il)
               R(il, iu) = R(il, iu) + dens(ic)*kd(iu, il)*h2G(iu)/h2G(il)* &
                    & exp(-hcK*(h2E(iu) - h2E(il))/T)
            end do
         end do
      end do
      R = R + h2A                                  ! radiative decay, upper -> lower
      deallocate(kd)
    end subroutine h2CollRad

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
    !---------------------------------------------------------------------------
    subroutine h2Solve(T, dens, eta, phi, pops, kdiss, pump, sink, src)
      real(dp), intent(in) :: T, dens(h2NColl), eta(:), phi(:)
      real(dp), intent(out) :: pops(:)
      real(dp), intent(out), optional :: kdiss(:), pump(:)
      real(dp), intent(in), optional :: sink(:), src(:)
      real(dp), allocatable :: R(:,:), W(:,:), k(:), pm(:)

      allocate(R(h2NX, h2NX), W(h2NX, h2NX), k(h2NX), pm(h2NX))
      call h2CollRad(T, dens, R)
      call h2PumpRates(eta, W, k, pm)
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
      integer :: i, k, p
      real(dp) :: f, t
      real(dp) :: rowt(n)
      do k = 1, n - 1
         p = k - 1 + maxloc(abs(a(k:n, k)), 1)
         if (p /= k) then
            rowt = a(k, :); a(k, :) = a(p, :); a(p, :) = rowt
            t = b(k); b(k) = b(p); b(p) = t
         end if
         if (a(k, k) == 0._dp) cycle
         do i = k + 1, n
            f = a(i, k)/a(k, k)
            if (f == 0._dp) cycle
            a(i, k:n) = a(i, k:n) - f*a(k, k:n)
            b(i) = b(i) - f*b(k)
         end do
      end do
      do i = n, 1, -1
         b(i) = (b(i) - sum(a(i, i+1:n)*b(i+1:n)))/a(i, i)
      end do
    end subroutine gaussSolve

end module h2_mod
