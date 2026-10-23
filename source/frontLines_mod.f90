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
! D-382: the [O I] optical lines of the cells an ionization front crosses,
! from a sub-cell profile - a post-processing estimate, written to
! output/lineFluxFront.out when the input has the keyword frontLines.
!
! A cell holds one ionization state for its whole volume. Where the front is
! thinner than the cell, that state mixes ionized and neutral gas, and a line
! that needs both - [O I] 6300 needs electrons and neutral O - comes out too
! bright, in proportion to the cell size (D-362, D-365, L-37). Each cell in
! output/frontField.out (x(H+) > 1e-4, with the transport's field and
! opacity, D-381) is integrated along the direction from the star:
!   - the field entering the cell, J_in = J tau/(1 - e^-tau) per bin, with
!     tau the transport's own opacity over the cell's chord;
!   - H and He ionization at each depth, with the recombination rates the
!     cell's own balance implies (alpha = Gamma n_i / (n_i+1 n_e), at its
!     T). Where a He stage is empty the balance cannot give its rate, and
!     MOCASSIN's radiative fits (radrec.dat, as radRecFit reads it) give the
!     He/H ratio applied to the cell's own H rate;
!   - O0/O+ locked to H0/H+ at the cell's own ratio (charge exchange,
!     D-263), O++/O+ scaled with the photoionization rate above O+'s edge;
!   - MOCASSIN's own O I atom (equilibrium, with the chemistry's neutral
!     colliders and the cell's escape probabilities in a PDR build) at each
!     depth, at the cell's T.
! Nothing is fitted. Only [O I] 6300, 6363 and 5577 are reported, the lines
! this was tested for (D-381: hiipdr's 6300 within +-9% at 21^3, 31^3 and
! 41^3, where the uncorrected value falls 1.72x). [O I] 63/145 are not: the
! neutral part of a cell keeps the cell's warm T here, and they stay wrong.
!
! An estimate, not the model's state: the cells' T was set by the
! uncorrected cooling, and lineFlux.out keeps the lines the thermal balance
! used (D-362). One ionizing source is required (it sets the chord
! direction); planeIonization, 1D and 2D grids and sub-grids are not handled.
!===============================================================================
module frontLines_mod
    use common_mod
    use constants_mod
    use emission_mod, only: equilibrium
    use grid_mod, only: getVolume
    use elements_mod, only: getOuterShell
    implicit none
    private
    public :: writeFrontLines

    integer, parameter :: nRep = 3
    ! the reported transitions, identified by the atom's own wavelengths
    double precision, parameter :: wavRep(nRep) = (/6300.3d0, 6363.8d0, 5577.3d0/)
    character(len=12), parameter :: labRep(nRep) = (/'[O I] 6300  ', '[O I] 6363  ', &
         & '[O I] 5577  '/)
    integer, parameter :: maxZ = 20000       ! depth steps per cell

    ! MOCASSIN's radiative recombination fits for H I, He I, He II
    double precision :: vfHI(4), vfHeI(4), vfHeII(4)

contains

  subroutine writeFrontLines(grid, HbVol)
    implicit none
    type(grid_type), dimension(:), intent(in) :: grid
    real, intent(in) :: HbVol                  ! Hbeta [E36 erg/s], as lineFlux.out has it

    integer :: ios, nLo, nb, nn, iGf, nOut, i, j, k, cP, iE, u, lw, ir, nz, iz
    integer :: nProf, nFallb, nCap, nThick, outShell, nuO2P
    integer :: repU(nRep), repL(nRep)
    integer, allocatable :: entOf(:)
    double precision, allocatable :: nuF(:), sH(:), sHe0(:), sHe1(:)
    double precision, allocatable :: Jf(:,:), kf(:,:), kdf(:,:)
    double precision, allocatable :: fl(:,:), wv(:,:)
    double precision, allocatable :: wz(:), xHpz(:), xH0z(:), y0z(:), y1z(:), nez(:), g35z(:)
    double precision, allocatable :: budg(:)
    double precision :: sumU(nRep), sumC(nRep), sumUf(nRep), sumCf(nRep)
    double precision :: emU(nRep), emC(nRep), dV, nH, T, ne0, xHp, xH0, AHe, y0, y1, y2
    double precision :: AO, fO0c, RO, q2, OpO0, q2z, fO0, G35c, chordL, rv(3), rr, dxyz(3)
    double precision :: best, scl, bRatio, nuO2
    integer :: g0, g1
    logical :: lgFb, lgCap
    character(len=300) :: line

    print*, '! frontLines: sub-cell front estimate of the [O I] optical lines (D-382)'
    if (size(grid) /= 1 .or. lg1D .or. lg2D .or. lgPlaneIonization .or. nStars /= 1) then
       print*, '! frontLines: needs one grid, one ionizing source, 3D, no planeIonization - skipped'
       return
    end if
    if (.not.lgElementOn(8)) then
       print*, '! frontLines: oxygen is not in the model - skipped'
       return
    end if
    if (.not.lgDataAvailable(8,1)) then
       print*, '! frontLines: no O I atomic data - skipped'
       return
    end if

    ! the transport's field and opacity, as writeGrid saved them
    close(44)
    open(unit=44, file='output/frontField.out', status='old', action='read', iostat=ios)
    if (ios /= 0) then
       print*, '! frontLines: output/frontField.out not found - it is written by runs that ', &
            & 'have frontLines in their input - skipped'
       return
    end if
    read(44, '(a)') line
    read(44, *) nLo, nb
    if (nb /= nbins .or. nLo /= HlevNuP(1)) then
       print*, '! frontLines: frontField.out has bins ', nLo, nb, ' against this model''s ', &
            & HlevNuP(1), nbins, ' - skipped'
       close(44)
       return
    end if
    nn = nb - nLo + 1
    allocate(nuF(nn), sH(nn), sHe0(nn), sHe1(nn))
    read(44, *) nuF
    read(44, *) sH
    read(44, *) sHe0
    read(44, *) sHe1
    read(44, *) iGf, nOut
    allocate(Jf(nn, nOut), kf(nn, nOut), kdf(nn, nOut), entOf(0:grid(1)%nCells))
    entOf = 0
    do iE = 1, nOut
       read(44, *) iGf, i, j, k, cP
       read(44, *) Jf(:, iE)
       read(44, *) kf(:, iE)
       read(44, *) kdf(:, iE)
       if (cP >= 1 .and. cP <= grid(1)%nCells) entOf(cP) = iE
    end do
    close(44)

    call readRadRec()

    ! O+'s photoionization edge, from the same tables updateCell uses
    call getOuterShell(8, 7, outShell, g0, g1)
    nuO2P = elementP(8, 2, outShell, 1)
    nuO2 = dble(nuArray(nuO2P))

    ! the reported transitions, from the atom's own wavelengths
    allocate(fl(nForLevels, nForLevels), wv(nForLevels, nForLevels))
    fl = 0.d0; wv = 0.d0
    call equilibrium(dataFile(8,1), 0., 1.e4, 100., fl, wv)
    do ir = 1, nRep
       best = huge(1.d0); repU(ir) = 0; repL(ir) = 0
       do u = 1, nForLevels
          do lw = 1, nForLevels
             if (wv(u,lw) <= 0.d0) cycle
             if (abs(wv(u,lw) - wavRep(ir)) < best) then
                best = abs(wv(u,lw) - wavRep(ir)); repU(ir) = u; repL(ir) = lw
             end if
          end do
       end do
       if (best > 5.d0) then
          print*, '! frontLines: no O I transition within 5 A of ', wavRep(ir), ' - skipped'
          return
       end if
    end do

    allocate(wz(maxZ), xHpz(maxZ), xH0z(maxZ), y0z(maxZ), y1z(maxZ), nez(maxZ), g35z(maxZ))
    allocate(budg(nOut))
    sumU = 0.d0; sumC = 0.d0; sumUf = 0.d0; sumCf = 0.d0
    nProf = 0; nFallb = 0; nCap = 0; nThick = 0

    do i = 1, grid(1)%nx
       do j = 1, grid(1)%ny
          do k = 1, grid(1)%nz
             cP = grid(1)%active(i,j,k)
             if (cP <= 0) cycle
             if (grid(1)%lgBlack(cP) >= 1) cycle
             dV = dble(getVolume(grid(1), i, j, k))
             nH = dble(grid(1)%Hden(cP))
             T = dble(grid(1)%Te(cP))
             ne0 = dble(grid(1)%Ne(cP))
             AO = dble(grid(1)%elemAbun(grid(1)%abFileIndex(i,j,k), 8))
             fO0c = dble(grid(1)%ionDen(cP, elementXref(8), 1))
             if (fO0c <= 0.d0) cycle

             ! the cell as it is: the emission lineFlux.out has
#ifdef PDR
             if (lgPDR) call setLineColliders(grid(1), cP, grid(1)%ionDen(cP,:,:), &
                  & grid(1)%elemAbun(grid(1)%abFileIndex(i,j,k), 2))
#endif
             fl = 0.d0
             call equilibrium(dataFile(8,1), grid(1)%ionDen(cP,elementXref(8),2)/ &
                  & grid(1)%ionDen(cP,elementXref(8),1), grid(1)%Te(cP), grid(1)%Ne(cP), fl)
             do ir = 1, nRep
                emU(ir) = fl(repU(ir), repL(ir))*1.9865d9*AO*fO0c
             end do
             emC = emU

             iE = entOf(cP)
             if (iE > 0) then
                xHp = dble(grid(1)%ionDen(cP, elementXref(1), 2))
                xH0 = dble(grid(1)%ionDen(cP, elementXref(1), 1))
                AHe = 0.d0; y0 = 0.d0; y1 = 0.d0; y2 = 0.d0
                if (lgElementOn(2)) then
                   AHe = dble(grid(1)%elemAbun(grid(1)%abFileIndex(i,j,k), 2))
                   y0 = dble(grid(1)%ionDen(cP, elementXref(2), 1))
                   y1 = dble(grid(1)%ionDen(cP, elementXref(2), 2))
                   if (nstages > 2) y2 = dble(grid(1)%ionDen(cP, elementXref(2), 3))
                end if
                rv(1) = dble(grid(1)%xAxis(i)) - dble(starPosition(1)%x)
                rv(2) = dble(grid(1)%yAxis(j)) - dble(starPosition(1)%y)
                rv(3) = dble(grid(1)%zAxis(k)) - dble(starPosition(1)%z)
                rr = sqrt(sum(rv**2))
                if (xH0 > 0.d0 .and. xHp > 0.d0 .and. rr > 0.d0 .and. sum(Jf(:,iE)) > 0.d0) then
                   ! the cell's widths and its chord along the direction from the star
                   dxyz(1) = cellWidth(grid(1)%xAxis, i)
                   dxyz(2) = cellWidth(grid(1)%yAxis, j)
                   dxyz(3) = cellWidth(grid(1)%zAxis, k)
                   rv = rv/rr
                   chordL = dxyz(1)*dxyz(2)*dxyz(3)/(dxyz(2)*dxyz(3)*abs(rv(1)) + &
                        & dxyz(1)*dxyz(3)*abs(rv(2)) + dxyz(1)*dxyz(2)*abs(rv(3)))
                   call subcellProfile(nn, nuF, sH, sHe0, sHe1, Jf(:,iE), kf(:,iE), kdf(:,iE), &
                        & nuO2, chordL, nH, AHe, T, ne0, xHp, xH0, y0, y1, y2, nz, wz, xHpz, xH0z, &
                        & y0z, y1z, nez, g35z, G35c, bRatio, lgFb, lgCap)
                   nProf = nProf + 1
                   if (lgFb) nFallb = nFallb + 1
                   if (lgCap) nCap = nCap + 1
                   if (kf(1,iE)*chordL > 100.d0) then
                      nThick = nThick + 1
                      budg(nThick) = bRatio
                   end if

                   ! oxygen through the profile, and MOCASSIN's atom at each depth
                   RO = (fO0c/max(dble(grid(1)%ionDen(cP, elementXref(8), 2)), 1.d-30))/(xH0/xHp)
                   q2 = 0.d0
                   if (nstages > 2) q2 = dble(grid(1)%ionDen(cP, elementXref(8), 3))/ &
                        & max(dble(grid(1)%ionDen(cP, elementXref(8), 2)), 1.d-30)
                   emC = 0.d0
                   do iz = 1, nz
                      OpO0 = xHpz(iz)/(max(xH0z(iz), 1.d-300)*RO)
                      q2z = 0.d0
                      if (G35c > 0.d0) q2z = q2*(g35z(iz)/G35c)*(ne0/nez(iz))
                      fO0 = 1.d0/(1.d0 + OpO0*(1.d0 + q2z))
#ifdef PDR
                      if (lgPDR .and. collCellP > 0) then
                         collDen(5) = nH*xH0z(iz)
                         collDen(7) = nH*xHpz(iz)
                         collDen(6) = nH*AHe*y0z(iz)
                      end if
#endif
                      fl = 0.d0
                      call equilibrium(dataFile(8,1), real(min(OpO0, 1.d30)), real(T), &
                           & real(nez(iz)), fl)
                      do ir = 1, nRep
                         emC(ir) = emC(ir) + wz(iz)*fl(repU(ir), repL(ir))*1.9865d9*AO*fO0
                      end do
                   end do
                end if
                sumUf = sumUf + emU*nH*dV
                sumCf = sumCf + emC*nH*dV
             end if
#ifdef PDR
             collCellP = 0
#endif
             sumU = sumU + emU*nH*dV
             sumC = sumC + emC*nH*dV
          end do
       end do
    end do

    ! to [E36 erg/s], as outputGas scales Hbeta
    scl = 1.d-16
    if (lgSymmetricXYZ) scl = 8.d0*scl
    sumU = sumU*scl; sumC = sumC*scl; sumUf = sumUf*scl; sumCf = sumCf*scl

    close(45)
    open(unit=45, file='output/lineFluxFront.out', status='unknown', position='rewind', &
         & action='write', iostat=ios)
    if (ios /= 0) then
       print*, "! frontLines: can't open output/lineFluxFront.out for writing"
       return
    end if
    write(45, '(a)') '# lineFluxFront v1 (D-382): the [O I] optical lines with the cells an '// &
         & 'ionization front crosses integrated through a sub-cell profile'
    write(45, '(a)') '# A post-processing ESTIMATE, not the model''s state: the cells'' T was set '// &
         & 'by the uncorrected cooling, and lineFlux.out keeps the lines the thermal balance used.'
    write(45, '(a)') '# Method and tests: DEVLOG D-379..D-382. Tested for [O I] 6300 only; '// &
         & '[O I] 63/145 are not corrected (the neutral part keeps the cell''s T).'
    write(45, '(a,es13.5)') '# Hbeta [E36 erg/s]: ', HbVol
    write(45, '(a,i8,a,i8,a,i8,a)') '# cells integrated: ', nProf, ' of ', nOut, &
         & ' in frontField.out (', nThick, ' with tau(912 A) > 100 across the chord)'
    write(45, '(a,i8)') '# cells using the radrec.dat He/H recombination ratio: ', nFallb
    if (nCap > 0) write(45, '(a,i8)') '# cells stopped at the depth-step limit: ', nCap
    if (nThick > 0) write(45, '(a,f8.3,a)') '# H photoabsorption, profile / cell, median over '// &
         & 'the tau > 100 cells: ', median(budg(1:nThick)), &
         & '  (1 when the front is stationary; below 1 while it still moves in, D-381)'
    write(45, '(a)') '# line          wav[A]     uncorr/Hb      corr/Hb   corr/uncorr'// &
         & '   uncorr[E36]     corr[E36]  front cells: uncorr[E36]   corr[E36]'
    do ir = 1, nRep
       write(45, '(a12,f10.2,2es13.5,f13.4,2es14.5,2es14.5)') labRep(ir), &
            & wv(repU(ir), repL(ir)), sumU(ir)/dble(HbVol), sumC(ir)/dble(HbVol), &
            & sumC(ir)/max(sumU(ir), 1.d-300), sumU(ir), sumC(ir), sumUf(ir), sumCf(ir)
    end do
    close(45)
    print*, '! frontLines: [O I] 6300/Hbeta ', real(sumU(1)/dble(HbVol)), ' -> ', &
         & real(sumC(1)/dble(HbVol)), ' (lineFluxFront.out)'

  end subroutine writeFrontLines

  ! a cell's full width along one axis: the spacing around it (the mirror
  ! planes of a symmetric grid cut their cells in half; this is the whole one)
  double precision function cellWidth(ax, i)
    real, intent(in) :: ax(:)
    integer, intent(in) :: i
    integer :: i1, i2
    i1 = max(i-1, 1); i2 = min(i+1, size(ax))
    cellWidth = dble(ax(i2) - ax(i1))/dble(i2 - i1)
  end function cellWidth

  double precision function median(a)
    double precision, intent(in) :: a(:)
    double precision :: b(size(a)), t
    integer :: i, j, n
    n = size(a); b = a
    do i = 2, n
       t = b(i); j = i - 1
       do while (j >= 1)
          if (b(j) <= t) exit
          b(j+1) = b(j); j = j - 1
       end do
       b(j+1) = t
    end do
    median = b((n+1)/2)
  end function median

  ! MOCASSIN's radiative recombination fits (Verner & Ferland 1996), read
  ! in radRecFit's own order, for H I, He II and He I
  subroutine readRadRec()
    integer :: ion, elem, ios
    real :: r2(2), r4(4)
    close(17)
    open(unit=17, file=PREFIX//'/share/mocassin/data/radrec.dat', status='old', &
         & position='rewind', iostat=ios, action='read')
    if (ios /= 0) then
       print*, '! frontLines: cannot open radrec.dat'
       stop
    end if
    do ion = 4, 30
       if (ion == 11) cycle
       do elem = ion, 30
          if ((elem /= 26) .or. (ion >= 14)) read(17, *) r2
       end do
    end do
    do ion = 1, 3
       do elem = ion, 30
          read(17, *) r4
          if (ion == 1 .and. elem == 1) vfHI = dble(r4)
          if (ion == 1 .and. elem == 2) vfHeII = dble(r4)
          if (ion == 2 .and. elem == 2) vfHeI = dble(r4)
       end do
    end do
    close(17)
  end subroutine readRadRec

  double precision function vf96(c, T)
    double precision, intent(in) :: c(4), T
    double precision :: tt
    tt = sqrt(T/c(3))
    vf96 = c(1)/(tt*(1.d0+tt)**(1.d0-c(2))*(1.d0+sqrt(T/c(4)))**(1.d0+c(2)))
  end function vf96

  !-----------------------------------------------------------------------------
  ! One cell's ionization profile along its chord (D-381's stage 1). Rates
  ! are photons per bin in the units of Jste/nu; only ratios enter, so the
  ! field's normalization cancels. Returns per depth step its weight dz/L and
  ! the state at the step's midpoint.
  !-----------------------------------------------------------------------------
  subroutine subcellProfile(nn, nu, sH, sHe0, sHe1, Jb, kap, kd, nuO2, L, nH, AHe, T, &
       & ne0, xHp0, xH00, y0c, y1c, y2c, nz, wz, xHpz, xH0z, y0z, y1z, nez, g35z, G35c, &
       & bRatio, lgFb, lgCap)
    integer, intent(in) :: nn
    double precision, intent(in) :: nu(nn), sH(nn), sHe0(nn), sHe1(nn), Jb(nn), kap(nn), kd(nn)
    double precision, intent(in) :: nuO2, L, nH, AHe, T, ne0, xHp0, xH00, y0c, y1c, y2c
    integer, intent(out) :: nz
    double precision, intent(out) :: wz(:), xHpz(:), xH0z(:), y0z(:), y1z(:), nez(:), g35z(:)
    double precision, intent(out) :: G35c, bRatio
    logical, intent(out) :: lgFb, lgCap

    double precision :: ph(nn), phin(nn), tau(nn), kabs(nn), k2(nn), w(nn), tb
    logical :: hi(nn)
    double precision :: GH, G0, G1, aH, aHe0, aHe1, neo, rin, z, dz, keff, ne
    double precision :: sxHp, sxH0, sy0, sy1, sy2, sne, sg35, srate, sgH
    double precision :: absP, absH
    integer :: b

    ph = Jb/nu
    do b = 1, nn
       tb = kap(b)*L
       if (tb > 1.d-6) then
          phin(b) = ph(b)*tb/(1.d0 - exp(-tb))
       else
          phin(b) = ph(b)
       end if
    end do
    hi = nu >= nuO2
    GH = sum(ph*sH); G0 = sum(ph*sHe0); G1 = sum(ph*sHe1)
    G35c = sum(ph*sHe0, mask=hi)
    aH = GH*xH00/(xHp0*ne0)
    lgFb = .false.
    if (y0c > 1.d-6 .and. y1c > 1.d-6 .and. G0 > 0.d0) then
       aHe0 = G0*y0c/(y1c*ne0)
    else
       aHe0 = aH*vf96(vfHeI, T)/vf96(vfHI, T); lgFb = .true.
    end if
    if (y1c > 1.d-6 .and. y2c > 1.d-6 .and. G1 > 0.d0) then
       aHe1 = G1*y1c/(y2c*ne0)
    else
       aHe1 = aH*vf96(vfHeII, T)/vf96(vfHI, T); lgFb = .true.
    end if
    neo = max(ne0 - nH*(xHp0 + AHe*(y1c + 2.d0*y2c)), 1.d-6*nH)
    rin = sum(phin)

    tau = 0.d0; z = 0.d0; ne = ne0; nz = 0; lgCap = .false.; absP = 0.d0
    do while (z < L)
       call localState(tau, ne, sxHp, sxH0, sy0, sy1, sy2, sne, sg35, srate, sgH)
       ne = sne
       kabs = nH*(sxH0*sH + AHe*(sy0*sHe0 + sy1*sHe1)) + kd
       w = phin*exp(-tau)
       keff = sum(w*kabs)/max(sum(w), tiny(1.d0))
       dz = min(L/400.d0, 0.05d0/max(keff, tiny(1.d0)), L - z)
       if (srate < 1.d-8*rin) dz = L - z          ! dark: the rest of the cell is this state
       if (nz == size(wz) - 1) then
          dz = L - z; lgCap = .true.
       end if
       call localState(tau + 0.5d0*dz*kabs, ne, sxHp, sxH0, sy0, sy1, sy2, sne, sg35, srate, sgH)
       k2 = nH*(sxH0*sH + AHe*(sy0*sHe0 + sy1*sHe1)) + kd
       nz = nz + 1
       wz(nz) = dz/L; xHpz(nz) = sxHp; xH0z(nz) = sxH0; y0z(nz) = sy0; y1z(nz) = sy1
       nez(nz) = sne; g35z(nz) = sg35
       absP = absP + nH*sxH0*sgH*dz
       tau = tau + dz*k2
       z = z + dz
    end do
    absH = nH*xH00*GH*L
    bRatio = absP/max(absH, tiny(1.d0))

  contains

    ! the local balance at optical depth tauL: H, He and n_e together
    subroutine localState(tauL, neIn, xHp, xH0, y0, y1, y2, neOut, g35, rate, gH)
      double precision, intent(in) :: tauL(nn), neIn
      double precision, intent(out) :: xHp, xH0, y0, y1, y2, neOut, g35, rate, gH
      double precision :: Jz(nn), g0, g1, r1, r2, neo2, bq, cq, disc, neNew
      integer :: it
      Jz = phin*exp(-tauL)
      gH = sum(Jz*sH); g0 = sum(Jz*sHe0); g1 = sum(Jz*sHe1)
      g35 = sum(Jz*sHe0, mask=hi)
      rate = sum(Jz)
      neOut = neIn
      y0 = 1.d0; y1 = 0.d0; y2 = 0.d0
      do it = 1, 30
         r1 = g0/(aHe0*neOut); r2 = g1/(aHe1*neOut)
         y0 = 1.d0/(1.d0 + r1 + r1*r2); y1 = r1*y0; y2 = r1*r2*y0
         neo2 = neo + nH*AHe*(y1 + 2.d0*y2)
         ! H: aH ne^2 + (gH - aH neo2) ne - (nH + neo2) gH = 0, solved without cancellation
         bq = gH - aH*neo2
         cq = (nH + neo2)*gH
         disc = sqrt(bq*bq + 4.d0*aH*cq)
         if (bq <= 0.d0) then
            neNew = (-bq + disc)/(2.d0*aH)
         else
            neNew = 2.d0*cq/(bq + disc)
         end if
         neNew = max(neNew, neo2)
         if (abs(neNew - neOut) < 1.d-7*neOut) then
            neOut = neNew
            exit
         end if
         neOut = neNew
      end do
      if (gH > 0.d0) then
         xHp = gH/(gH + aH*neOut)
      else
         xHp = 0.d0
      end if
      xH0 = 1.d0 - xHp
    end subroutine localState

  end subroutine subcellProfile

end module frontLines_mod
