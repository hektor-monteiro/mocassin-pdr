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
! of Cloudy's source. Formation into specific levels, destruction, cosmic
! rays and UV pumping through the electronic states are later steps; so are
! electrons as colliders, which Aleman & Gruenwald 2011 include and Cloudy
! does not.
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

    public :: h2ReadX, h2SolveX, h2Level

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

    !---------------------------------------------------------------------------
    ! Populations of the X levels (fractions, summing to 1) at temperature T
    ! with collider densities dens(1:5) [cm^-3] (H, He, o-H2, p-H2, H+).
    ! rateOut(i), optional: the total rate out of level i [s^-1].
    !---------------------------------------------------------------------------
    subroutine h2SolveX(T, dens, pops, rateOut)
      real(dp), intent(in) :: T, dens(h2NColl)
      real(dp), intent(out) :: pops(:)
      real(dp), intent(out), optional :: rateOut(:)
      real(dp), allocatable :: R(:,:), M(:,:), b(:), kd(:,:)
      real(dp) :: dE, kgb
      integer :: n, ic, it, i, j, iu, il
      logical, allocatable :: has(:,:)

      n = h2NX
      allocate(R(n, n), M(n, n), b(n), kd(n, n), has(n, n))
      R = 0._dp                                    ! R(i,j): rate i -> j [s^-1]
      do ic = 1, h2NColl
         if (dens(ic) <= 0._dp) cycle
         kd = 0._dp; has = .false.
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

      ! balance: sum_j n_j R(j,i) - n_i sum_j R(i,j) = 0; level 1 replaced by sum n = 1
      do i = 1, n
         do j = 1, n
            M(i, j) = R(j, i)
         end do
         M(i, i) = -sum(R(i, :)) + R(i, i)
      end do
      if (present(rateOut)) then
         do i = 1, n
            rateOut(i) = sum(R(i, :)) - R(i, i)
         end do
      end if
      M(1, :) = 1._dp
      b = 0._dp; b(1) = 1._dp
      call gaussSolve(n, M, b)
      pops(1:n) = b
      deallocate(R, M, b, kd, has)
    end subroutine h2SolveX

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
