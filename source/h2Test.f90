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
