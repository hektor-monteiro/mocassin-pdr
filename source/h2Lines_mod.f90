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
! H-007 (branch h2-model): output of the H2 level model that pdr_mod's
! h2LevelModel runs on the finished model.
!
!   output/lineFluxH2.out   the rovibrational lines of H2 X integrated over the
!                           grid, L = sum n(H2) pop_u A_ul h nu V, optically
!                           thin, no dust extinction applied; every line above
!                           1e-6 of the strongest, by wavelength
!   output/h2Cells.out      per active cell: n(H2), Te, the Solomon rate from
!                           the levels and the chemistry's own on the same
!                           field, the pumping rate, ortho/para, the fraction
!                           above 4100 cm^-1; (H-012) the H2 heating from the
!                           levels beside 3D-PDR's three H2 terms and
!                           MOCASSIN's own heating and cooling, per H
!   output/h2Pop.bin        the level populations of every cell (raw): int32
!                           nCells, nLev; int32 v(nLev), J(nLev); real64
!                           E(nLev) [cm^-1]; then real32 pop(nLev) per cell in
!                           cell order (h2Cells.out gives each cell's i, j, k)
!===============================================================================
module h2Lines_mod
#ifdef PDR
    use common_mod
    use constants_mod
    use h2_mod, only : h2NX, h2V, h2J, h2E, h2A, h2Ortho
    use grid_mod, only : getVolume

    implicit none
    private
    public :: writeH2Lines

contains

    subroutine writeH2Lines(grid, HbVol)
      type(grid_type), dimension(:), intent(in) :: grid
      real, intent(in) :: HbVol                         ! Hbeta [E36 erg/s]

      double precision, parameter :: eStar = 4100.d0
      double precision, parameter :: eVerg = 1.602176634d-12   ! [erg]
      double precision, allocatable :: molLev(:), lineL(:), wl(:)
      integer, allocatable :: lnUp(:), lnLo(:), ord(:)
      double precision :: dV, sym, nH2, Lmax, fo, fs, hb
      double precision :: xH, xH2, hLev(3), hPdr(3), hMoc(2), ePer(3)
      integer :: i, j, k, l, m, n, cellP, ios, nl, dj
      character(len=1) :: br
      character(len=12) :: lab

      if (.not.allocated(grid(1)%h2Pop) .or. h2NX == 0) return
      sym = 1.d0
      if (lgSymmetricXYZ .and. .not.lg2D) sym = 8.d0
      if (lgSymmetricXYZ .and. lg2D) sym = 2.d0

      ! number of H2 molecules in each level, summed over the grid
      allocate(molLev(h2NX)); molLev = 0.d0
      open(unit=64, file='output/h2Cells.out', status='unknown', position='rewind', action='write', iostat=ios)
      if (ios /= 0) then
         print*, "! writeH2Lines: can't open output/h2Cells.out"; stop
      end if
      write(64, '(a)') "# h2Cells.out (H-007): the H2 level model per active cell"
      write(64, '(a)') "#  i  j  k   cell    x[cm]       y[cm]       z[cm]       n(H2)[cm-3] Te[K]    "// &
           & "Sol(levels)[s-1] Sol(chem)[s-1] pump[s-1]  o/p     f(E>4100) | direct part: Sol(levels) Sol(chem) | "// &
           & "N(H2) to cell, through cell [cm-2] | diffuse share of LW field | per H2 formed on grains: "// &
           & "energy left on the grain [erg], formation rate [cm3 s-1] | (H-012) H2 heating per H [erg s-1], "// &
           & "levels: formation, dissociation, collisions within X | 3D-PDR: formation, photodissociation, "// &
           & "FUV pumping | MOCASSIN's heating, cooling (thermBudget) | eV per event: kinetic per H2 formed, "// &
           & "left on the grain per H2 formed, kinetic per dissociation"
      do i = 1, grid(1)%nx
         do j = 1, grid(1)%ny
            do k = 1, grid(1)%nz
               cellP = grid(1)%active(i,j,k)
               if (cellP <= 0) cycle
               dV = dble(getVolume(grid(1), i, j, k))*1.d45*sym
               nH2 = dble(grid(1)%H2den(cellP))
               fo = 0.d0; fs = 0.d0
               do l = 1, h2NX
                  molLev(l) = molLev(l) + nH2*dble(grid(1)%h2Pop(cellP,l))*dV
                  if (h2Ortho(l)) fo = fo + dble(grid(1)%h2Pop(cellP,l))
                  if (h2E(l) > eStar) fs = fs + dble(grid(1)%h2Pop(cellP,l))
               end do
               ! H-012: the H2 heating, per H nucleus as MOCASSIN's budget
               hLev = 0.d0; hPdr = 0.d0; hMoc = 0.d0; ePer = 0.d0
               if (allocated(grid(1)%h2Heat) .and. grid(1)%Hden(cellP) > 0.) then
                  xH  = grid(1)%pdrAbun(cellP, pdrIdxH)
                  xH2 = grid(1)%pdrAbun(cellP, pdrIdxH2)
                  hLev(1) = dble(grid(1)%h2Diag(cellP,7))*xH*dble(grid(1)%Hden(cellP))*dble(grid(1)%h2Heat(cellP,3))
                  hLev(2) = xH2*dble(grid(1)%h2Heat(cellP,1))
                  hLev(3) = xH2*dble(grid(1)%h2Heat(cellP,2))
                  if (allocated(grid(1)%pdrHeatH2)) hPdr = dble(grid(1)%pdrHeatH2(cellP,:))/dble(grid(1)%Hden(cellP))
                  if (allocated(grid(1)%mocBud)) then
                     hMoc(1) = sum(dble(grid(1)%mocBud(cellP,2,1:3)))
                     hMoc(2) = sum(dble(grid(1)%mocBud(cellP,2,4:8)))
                  end if
                  ePer(1) = dble(grid(1)%h2Heat(cellP,3))/eVerg
                  ePer(2) = dble(grid(1)%h2Diag(cellP,6))/eVerg
                  if (grid(1)%h2Sol(cellP) > 0.) ePer(3) = dble(grid(1)%h2Heat(cellP,1))/dble(grid(1)%h2Sol(cellP))/eVerg
               end if
               write(64, '(3i4,i7,3es12.4,es12.4,f9.1,3es13.4,f8.3,es11.3,7es12.4,8es12.4,3f8.4)') i, j, k, cellP, &
                    & grid(1)%xAxis(i), grid(1)%yAxis(j), grid(1)%zAxis(k), nH2, grid(1)%Te(cellP), &
                    & grid(1)%h2Sol(cellP), grid(1)%h2SolChem(cellP), grid(1)%h2Pump(cellP), &
                    & fo/max(1.d0 - fo, 1.d-30), fs, grid(1)%h2Diag(cellP,:), hLev, hPdr, hMoc, ePer
            end do
         end do
      end do
      close(64)

      open(unit=64, file='output/h2Pop.bin', status='replace', access='stream', action='write', iostat=ios)
      if (ios == 0) then
         write(64) int(grid(1)%nCells, 4), int(h2NX, 4)
         write(64) int(h2V, 4), int(h2J, 4)
         write(64) h2E
         do cellP = 1, grid(1)%nCells
            write(64) grid(1)%h2Pop(cellP,:)
         end do
         close(64)
      end if

      ! the lines
      nl = count(h2A > 0.d0)
      allocate(lineL(nl), wl(nl), lnUp(nl), lnLo(nl), ord(nl))
      n = 0
      do i = 2, h2NX
         do j = 1, i - 1
            if (h2A(i,j) <= 0.d0) cycle
            n = n + 1
            lnUp(n) = i; lnLo(n) = j
            wl(n) = 1.d4/(h2E(i) - h2E(j))                              ! [um]
            lineL(n) = molLev(i)*h2A(i,j)*dble(hPlanck)*dble(c)*(h2E(i) - h2E(j))
         end do
      end do
      Lmax = maxval(lineL)
      ! by wavelength (insertion sort on the kept lines)
      m = 0
      do n = 1, nl
         if (lineL(n) < 1.d-6*Lmax .or. lineL(n) <= 0.d0) cycle
         m = m + 1; ord(m) = n
      end do
      do i = 2, m
         k = ord(i); j = i - 1
         do while (j >= 1)
            if (wl(ord(j)) <= wl(k)) exit
            ord(j+1) = ord(j); j = j - 1
         end do
         ord(j+1) = k
      end do
      hb = dble(HbVol)*1.d36
      open(unit=64, file='output/lineFluxH2.out', status='unknown', position='rewind', action='write', iostat=ios)
      if (ios /= 0) then
         print*, "! writeH2Lines: can't open output/lineFluxH2.out"; stop
      end if
      write(64, '(a)') "# lineFluxH2.out (H-007): rovibrational lines of H2 X from the level model run on"
      write(64, '(a)') "# the finished model, integrated over the grid. Optically thin, no dust extinction."
      write(64, '(a)') "# Lines above 1e-6 of the strongest."
      write(64, '(a,es14.6)') "# Hbeta [E36 erg/s]: ", HbVol
      write(64, '(a,es14.6)') "# H2 molecules in the grid: ", sum(molLev)
      write(64, '(a)') "#  line          vu  Ju  vl  Jl    lambda[um]    E_up/k[K]      L[erg/s]       L/Hbeta"
      do i = 1, m
         n = ord(i)
         dj = h2J(lnUp(n)) - h2J(lnLo(n))
         br = 'Q'
         if (dj == 2) br = 'S'
         if (dj == -2) br = 'O'
         write(lab, '(i2,a,i2,1x,a,a,i2,a)') h2V(lnUp(n)), '-', h2V(lnLo(n)), br, '(', h2J(lnLo(n)), ')'
         write(64, '(2x,a12,4i4,f14.5,f13.1,2es14.5)') lab, h2V(lnUp(n)), h2J(lnUp(n)), h2V(lnLo(n)), h2J(lnLo(n)), &
              & wl(n), h2E(lnUp(n))*dble(hPlanck)*dble(c)/dble(kBoltzmann), lineL(n), lineL(n)/max(hb, 1.d-300)
      end do
      close(64)
      deallocate(molLev, lineL, wl, lnUp, lnLo, ord)
    end subroutine writeH2Lines
#endif
end module h2Lines_mod
