! H-003: standalone test driver for h2_mod. Reads cases from a file, one per
! line: label T n(H) n(He) n(oH2) n(pH2) n(H+)  [cm^-3], and writes for each
! the X-level populations (fractions of H2) to <label>.h2pops: v J E[cm-1]
! pop rateOut[s-1].
!
!    h2Test <data dir> <cases file>
program h2Test
    use h2_mod
    implicit none
    integer, parameter :: dp = kind(1.d0)
    character(len=512) :: dir, cases, line
    character(len=64) :: label
    real(dp) :: T, dens(h2NColl)
    real(dp), allocatable :: pops(:), rout(:)
    integer :: ios, i

    call get_command_argument(1, dir)
    call get_command_argument(2, cases)
    call h2ReadX(trim(dir))
    print '(a,i5,a)', ' h2Test: ', h2NX, ' X levels'
    allocate(pops(h2NX), rout(h2NX))
    open(unit=10, file=trim(cases), status='old', action='read')
    do
       read(10, '(a)', iostat=ios) line
       if (ios /= 0) exit
       if (len_trim(line) == 0 .or. line(1:1) == '#') cycle
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
    end do
    close(10)
end program h2Test
