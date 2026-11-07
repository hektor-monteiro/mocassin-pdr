! Copyright (C) 2026 Hektor Monteiro
! Part of MOCASSIN-PDR.
!
! This program is free software: you can redistribute it and/or modify it
! under the terms of the GNU General Public License as published by the Free
! Software Foundation, either version 3 of the License, or (at your option)
! any later version. It is distributed WITHOUT ANY WARRANTY; see the GNU
! General Public License (LICENSE) for details.
!
! D-462: standalone test driver for qheat_mod.
!
!    qhTest <case file> <output file>
!
! Case file: line 1 "nb nT Tlo Tmax carbon(1|0) Nat vg cont", then nb lines
! "nu[Ryd] widFlx[Ryd] field[erg s-1 cm-2] cab". Output: line 1 "ok Tmean
! ratio ptop", then nT lines "T P", then nb lines "spec".
! tools/d462_qheat_check.py writes the cases and reads the results.
program qhTest
    use qheat_mod
    implicit none
    character(len=512) :: caseFile, outFile
    integer :: nb, nT, iCarb, i, j, ios
    real, allocatable :: nu(:), wid(:)
    double precision, allocatable :: field(:), cab(:), P(:), spec(:)
    double precision :: Tlo, Tmax, Nat, vg, cont, Tmean, ratio, ptop
    logical :: ok

    if (command_argument_count() /= 2) then
       print*, "usage: qhTest <case file> <output file>"
       stop 1
    end if
    call get_command_argument(1, caseFile)
    call get_command_argument(2, outFile)
    open(10, file=trim(caseFile), status='old', action='read', iostat=ios)
    if (ios /= 0) then
       print*, "! qhTest: cannot open ", trim(caseFile)
       stop 1
    end if
    read(10, *) nb, nT, Tlo, Tmax, iCarb, Nat, vg, cont
    allocate(nu(nb), wid(nb), field(nb), cab(nb), P(nT), spec(nb))
    do i = 1, nb
       read(10, *) nu(i), wid(i), field(i), cab(i)
    end do
    close(10)
    call qhInit(nb, nu, wid, nT, Tlo, Tmax)
    call qhSolve(field, cab, cont, iCarb == 1, Nat, vg, P, spec, Tmean, ratio, ptop, ok)
    open(11, file=trim(outFile), status='replace', action='write')
    write(11, '(L2, 3ES25.15E3)') ok, Tmean, ratio, ptop
    do j = 1, nT
       write(11, '(2ES25.15E3)') qhT(j), P(j)
    end do
    do i = 1, nb
       write(11, '(ES25.15E3)') spec(i)
    end do
    close(11)
end program qhTest
