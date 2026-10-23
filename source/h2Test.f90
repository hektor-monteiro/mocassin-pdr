! Copyright (C) 2026 Hektor Monteiro
! Part of MOCASSIN-PDR.
!
! This program is free software: you can redistribute it and/or modify it
! under the terms of the GNU General Public License as published by the Free
! Software Foundation, either version 3 of the License, or (at your option)
! any later version. It is distributed WITHOUT ANY WARRANTY; see the GNU
! General Public License (LICENSE) for details.
!
! H-003, H-004: standalone test driver for h2_mod.
!
!    h2Test <data dir> <cases file> [dump]
!
! One case per line of the cases file, densities in cm^-3:
!    label T n(H) n(He) n(oH2) n(pH2) n(H+)
!       collisions and radiative decay only (H-003); writes <label>.h2pops:
!       v J E[cm-1] pop rateOut[s-1]
!    label T n(H) n(He) n(oH2) n(pH2) n(H+) <field file> w_ice w_sil w_car
!       with pumping by the field and formation on the three surfaces in the
!       proportions w (H-004); writes <label>.h2pops:
!       v J E[cm-1] pop pump[s-1] kdiss[s-1] phi
!       The field file has two columns, wavenumber [cm-1] ascending and the
!       photon occupation number there; a line takes the nearest entry's.
!    h2Test <data dir> lines
!       prints the pumping line list
!    h2Test <data dir> overlap <columns file> <b [cm/s]>
!       the shielding of every line, alone and with line overlap, for the
!       level columns of the file (rows "v J N[cm-2]") (H-006)
!    h2Test <data dir> shield
!       prints the line shielding function on a grid: tau0, a, S, W, and
!       Cloudy's Federman fit (H-005)
!
! With 'dump' the pumping matrix W(l,l') [s-1] and then the matrix of
! collisions and radiative decay R(l,l') [s-1] are also written, to
! <label>.h2W (raw float64, column-major).
program h2Test
    use h2_mod
    implicit none
    integer, parameter :: dp = kind(1.d0)
    character(len=512) :: dir, cases, line, fieldFile, arg3
    character(len=64) :: label
    real(dp) :: T, dens(h2NColl), wSurf(h2NSurf)
    real(dp), allocatable :: pops(:), rout(:), kdiss(:), pump(:), phi(:), phi1(:), eta(:)
    real(dp), allocatable :: W(:,:), kd2(:), fw(:), fe(:)
    integer :: ios, i, k, nf, lo, hi, mid
    logical :: lgDump

    call get_command_argument(1, dir)
    call get_command_argument(2, cases)
    call get_command_argument(3, arg3)
    if (trim(cases) == 'lines') then
       ! the pumping lines: state vu Ju vl Jl wavenumber A g_u g_l Gamma_u(= sum A + D) D_u
       call h2ReadX(trim(dir))
       call h2ReadElec(trim(dir))
       do i = 1, h2NT
          print '(5i4,f13.3,es13.5,2f6.0,2es13.5)', h2uS(h2tU(i)), h2uV(h2tU(i)), h2uJ(h2tU(i)), &
               & h2V(h2tL(i)), h2J(h2tL(i)), h2tWN(i), h2tA(i), h2uG(h2tU(i)), h2G(h2tL(i)), &
               & h2uAtot(h2tU(i)) + h2uDiss(h2tU(i)), h2uDiss(h2tU(i))
       end do
       stop
    end if
    if (trim(cases) == 'overlap') then
       ! the shielding of every line for given level columns: arg 3 is a file of
       ! "v J N[cm-2]" rows, arg 4 the Doppler parameter [cm/s]; prints
       ! line index, wavenumber, tau0, own shielding, shielding with overlap
       call h2ReadX(trim(dir))
       call h2ReadElec(trim(dir))
       allocate(pops(h2NX), eta(h2NT), phi(h2NT), phi1(h2NT))
       pops = 0._dp
       open(unit=12, file=trim(arg3), status='old', action='read')
       do
          read(12, *, iostat=ios) i, k, T
          if (ios /= 0) exit
          if (h2Level(i, k) > 0) pops(h2Level(i, k)) = T
       end do
       close(12)
       call get_command_argument(4, line)
       read(line, *) T
       call h2LineShield(pops, T, eta, tau0=phi, own=phi1)
       do i = 1, h2NT
          print '(i7,f13.3,3es16.6e3)', i, h2tWN(i), phi(i), phi1(i), eta(i)
       end do
       stop
    end if
    if (trim(cases) == 'shield') then
       ! the shielding function on a grid, for checking: tau0 a S W Federman
       do k = -6, -1
          do i = -8, 44
             T = 10._dp**(0.25_dp*dble(i)); wSurf(1) = 10._dp**dble(k)
             print '(5es14.6)', T, wSurf(1), h2Shield(T, wSurf(1)), &
                  & T*h2Shield(0._dp, wSurf(1), T), h2ShieldFederman(T, wSurf(1))
          end do
       end do
       stop
    end if
    lgDump = (trim(arg3) == 'dump')
    call h2ReadX(trim(dir))
    call h2ReadElec(trim(dir))
    print '(a,i5,a,i6,a,i7,a,i5,a)', ' h2Test: ', h2NX, ' X levels, ', h2NU, ' excited levels, ', &
         & h2NT, ' lines (', h2NSkipped, ' skipped)'
    allocate(pops(h2NX), rout(h2NX), kdiss(h2NX), pump(h2NX), phi(h2NX), phi1(h2NX), eta(h2NT))
    open(unit=10, file=trim(cases), status='old', action='read')
    do
       read(10, '(a)', iostat=ios) line
       if (ios /= 0) exit
       if (len_trim(line) == 0 .or. line(1:1) == '#') cycle
       if (nTok(line) < 11) then
          read(line, *) label, T, dens
          call h2SolveX(T, dens, pops, rout)
          open(unit=11, file=trim(label)//'.h2pops', status='replace', action='write')
          write(11, '(a)') '# v J E[cm-1] pop/H2 rateOut[s-1]'
          do i = 1, h2NX
             write(11, '(2i4,f12.4,2es15.5e3)') h2V(i), h2J(i), h2E(i), pops(i), rout(i)
          end do
          close(11)
          print '(a,a,a,f8.1,a,es10.3,a,f8.4)', ' h2Test: ', trim(label), '  T', T, &
               & '  sum', sum(pops), '  min', minval(pops)
          cycle
       end if

       read(line, *) label, T, dens, fieldFile, wSurf
       ! the field
       open(unit=12, file=trim(fieldFile), status='old', action='read')
       nf = 0
       do
          read(12, *, iostat=ios)
          if (ios /= 0) exit
          nf = nf + 1
       end do
       rewind(12)
       allocate(fw(nf), fe(nf))
       do i = 1, nf
          read(12, *) fw(i), fe(i)
       end do
       close(12)
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
          k = merge(lo, hi, h2tWN(i) - fw(lo) <= fw(hi) - h2tWN(i))
          eta(i) = fe(k)
       end do
       deallocate(fw, fe)
       ! formation on the surfaces in the proportions given
       phi = 0._dp
       do k = 1, h2NSurf
          if (wSurf(k) <= 0._dp) cycle
          call h2FormDist(k, phi1)
          phi = phi + wSurf(k)*phi1
       end do
       phi = phi/sum(phi)

       call h2Solve(T, dens, eta, phi, pops, kdiss, pump)
       open(unit=11, file=trim(label)//'.h2pops', status='replace', action='write')
       write(11, '(a)') '# v J E[cm-1] pop/H2 pump[s-1] kdiss[s-1] phi'
       do i = 1, h2NX
          write(11, '(2i4,f12.4,4es15.5e3)') h2V(i), h2J(i), h2E(i), pops(i), pump(i), kdiss(i), phi(i)
       end do
       close(11)
       if (lgDump) then
          allocate(W(h2NX, h2NX), kd2(h2NX))
          call h2PumpRates(eta, W, kd2)
          open(unit=13, file=trim(label)//'.h2W', status='replace', access='stream', action='write')
          write(13) W
          call h2CollRad(T, dens, W)
          write(13) W
          close(13)
          deallocate(W, kd2)
       end if
       print '(a,a,a,f8.1,a,es10.3,a,es10.3,a,es10.3,a,f7.3)', ' h2Test: ', trim(label), '  T', T, &
            & '  sum', sum(pops), '  min', minval(pops), '  Solomon', sum(pops*kdiss), &
            & '  pump/diss', sum(pops*pump)/max(sum(pops*kdiss), tiny(1._dp))
    end do
    close(10)

contains

    integer function nTok(s)
      character(len=*), intent(in) :: s
      integer :: p
      logical :: inTok
      nTok = 0; inTok = .false.
      do p = 1, len_trim(s)
         if (s(p:p) /= ' ' .and. s(p:p) /= char(9)) then
            if (.not.inTok) nTok = nTok + 1
            inTok = .true.
         else
            inTok = .false.
         end if
      end do
    end function nTok

end program h2Test
