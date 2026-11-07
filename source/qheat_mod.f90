! Copyright (C) 2026 Hektor Monteiro
! Part of MOCASSIN-PDR.
!
! This program is free software: you can redistribute it and/or modify it
! under the terms of the GNU General Public License as published by the Free
! Software Foundation, either version 3 of the License, or (at your option)
! any later version. It is distributed WITHOUT ANY WARRANTY; see the GNU
! General Public License (LICENSE) for details.
!
! D-462: stochastic heating of small grains - the steady-state probability
! P(T) of a grain's temperature, and the emission it gives.
!
! The thermal-continuous approximation of Draine & Li (2001, ApJ 551, 807;
! DL01). Absorption takes the grain from level l up to u at the rate of DL01
! eqs 15-24 (the overlap of the two levels' widths), eq 28 for the next level
! (with its intrabin term) and eq 16 for the top one, which takes every photon
! beyond it. Emission takes it down one level at a time, at the power it
! radiates at the level's temperature in photons below the level's energy
! (eqs 40-41). The steady state is the recursion of Guhathakurta & Draine
! (1989; GD89), DL01 eqs 53-54. The heat capacities are GD89's, as Cloudy's
! default graphite and silicate (grains_qheat.cpp, ENTH_CAR and ENTH_SIL).
!
! The levels sit on one temperature grid for every grain, geometric from Tlo
! to Tmax, so that the Planck function is tabulated once (qhInit). The field
! is a histogram over MOCASSIN's frequency bins: bin i holds field(i) [erg
! s^-1 cm^-2, Jste's units] spread evenly between the midpoints to its
! neighbours, an interval of width widFlx(i). The integrals F0(E), F1(E) of
! the absorbed power below a photon energy E are then exact, and so are the
! rates.
!
! Standalone (constants_mod only), so that qhTest can drive it.
module qheat_mod
    use constants_mod
    implicit none
    private
    public :: qhInit, qhSolve, qhEnthalpy, qhNT, qhT

    integer, save :: qhNT = 0                           ! levels; 0 until qhInit
    integer, save :: qhNB = 0                           ! frequency bins
    double precision, allocatable, save :: qhT(:)       ! (qhNT) level temperatures [K]
    double precision, allocatable, save :: qhB(:,:)     ! (qhNB, qhNT) B_nu(T_j)/h * widFlx: getFlux's units, times the width
    double precision, allocatable, save :: qhEph(:)     ! (qhNB) photon energy at the bin points [erg]
    double precision, allocatable, save :: qhEdge(:)    ! (0:qhNB) bin edges [erg]
    double precision, save :: pconv                     ! qhB times a cross section -> power: 4 pi h fr1Ryd
    ! qhSolve's work arrays
    double precision, allocatable, save :: Tm(:,:)      ! (qhNT, qhNT) rates T(u,l), then their sums over u
    double precision, allocatable, save :: E(:), Emin(:), Emax(:), dE(:), X(:), pw(:), cool(:)
    double precision, allocatable, save :: dens(:), F0e(:), F1e(:)
    integer, allocatable, save          :: nI(:)

contains

    subroutine qhInit(nb, nu, wid, nT, Tlo, Tmax)
      implicit none
      integer, intent(in)          :: nb, nT
      real, intent(in)             :: nu(nb), wid(nb)   ! frequency points and widths [Ryd]
      double precision, intent(in) :: Tlo, Tmax         ! the grid's ends [K]
      integer          :: i, j
      double precision :: eRyd, nuHz, xh

      if (nT < 3 .or. nb < 2 .or. Tlo <= 0.d0 .or. Tmax <= Tlo) then
         print*, "! qhInit: need nTbins >= 3, nbins >= 2 and 0 < Tlo < Tmax:", nT, nb, Tlo, Tmax
         stop
      end if
      qhNT = nT
      qhNB = nb
      allocate(qhT(nT), qhB(nb,nT), qhEph(nb), qhEdge(0:nb))
      allocate(Tm(nT,nT), E(nT), Emin(nT), Emax(nT), dE(nT), X(nT), pw(nT), cool(nT), nI(nT))
      allocate(dens(nb), F0e(0:nb), F1e(0:nb))

      eRyd  = dble(hPlanck)*dble(fr1Ryd)                ! erg per Ryd
      pconv = 4.d0*dble(pi)*eRyd
      do j = 1, nT
         qhT(j) = Tlo*(Tmax/Tlo)**(dble(j-1)/dble(nT-1))
      end do
      do i = 1, nb
         qhEph(i) = eRyd*dble(nu(i))
      end do
      qhEdge(0) = max(eRyd*(1.5d0*dble(nu(1)) - 0.5d0*dble(nu(2))), 0.d0)
      do i = 1, nb-1
         qhEdge(i) = eRyd*0.5d0*(dble(nu(i)) + dble(nu(i+1)))
      end do
      qhEdge(nb) = eRyd*(1.5d0*dble(nu(nb)) - 0.5d0*dble(nu(nb-1)))
      do j = 1, nT
         do i = 1, nb
            nuHz = dble(nu(i))*dble(fr1Ryd)
            xh = dble(hPlanck)*nuHz/(dble(kBoltzmann)*qhT(j))
            if (xh > 700.d0) then
               qhB(i,j) = 0.d0
            else
               qhB(i,j) = 2.d0*nuHz**3/dble(c)**2/(exp(xh) - 1.d0)*dble(wid(i))
            end if
         end do
      end do
    end subroutine qhInit

    ! GD89's enthalpy [erg] times (N - 2), their formula 3.1 (Cloudy's
    ! MAX2(N-2,1)): graphite per atom; silicate per volume (the coefficients
    ! made continuous at 50, 150 and 500 K, as MOCASSIN has had them since
    ! Ercolano et al. 2005) times the grain volume vg [cm^3] over N.
    pure double precision function qhEnthalpy(T, lgCarb, Nat, vg)
      implicit none
      double precision, intent(in) :: T, Nat, vg
      logical, intent(in)          :: lgCarb
      double precision :: fN, u, u50, u150, u500

      fN = max(Nat - 2.d0, 1.d0)
      if (lgCarb) then
         qhEnthalpy = fN*4.15d-22*T**3.3d0/(1.d0 + 6.51d-3*T + 1.5d-6*T*T + 8.3d-7*T**2.3d0)
      else
         u50  = (1.4d3/3.d0)*50.d0**3
         u150 = u50 + (2.1647d4/2.3d0)*(150.d0**2.3d0 - 50.d0**2.3d0)
         u500 = u150 + (4.8375d5/1.68d0)*(500.d0**1.68d0 - 150.d0**1.68d0)
         if (T <= 50.d0) then
            u = (1.4d3/3.d0)*T**3
         else if (T <= 150.d0) then
            u = u50 + (2.1647d4/2.3d0)*(T**2.3d0 - 50.d0**2.3d0)
         else if (T <= 500.d0) then
            u = u150 + (4.8375d5/1.68d0)*(T**1.68d0 - 150.d0**1.68d0)
         else
            u = u500 + 3.3107d7*(T - 500.d0)
         end if
         qhEnthalpy = fN/Nat*vg*u
      end if
    end function qhEnthalpy

    ! F0(e) = int_0^e dens dE' and F1(e) = int_0^e E' dens dE' over the
    ! histogram. k is the bin holding e on return (qhEdge(k-1) <= e <
    ! qhEdge(k)), searched from its value on entry, so that a monotone
    ! sequence of e costs O(1) each.
    subroutine qhCum(ee, k, f0, f1)
      implicit none
      double precision, intent(in)  :: ee
      integer, intent(inout)        :: k
      double precision, intent(out) :: f0, f1

      if (ee <= qhEdge(0)) then
         f0 = 0.d0
         f1 = 0.d0
         k = 1
         return
      end if
      if (ee >= qhEdge(qhNB)) then
         f0 = F0e(qhNB)
         f1 = F1e(qhNB)
         k = qhNB
         return
      end if
      k = max(1, min(k, qhNB))
      do while (ee >= qhEdge(k))
         k = k + 1
      end do
      do while (ee < qhEdge(k-1))
         k = k - 1
      end do
      f0 = F0e(k-1) + dens(k)*(ee - qhEdge(k-1))
      f1 = F1e(k-1) + dens(k)*0.5d0*(ee*ee - qhEdge(k-1)**2)
    end subroutine qhCum

    ! One grain: field(i) the field in bin i [erg s^-1 cm^-2], cab(i) its
    ! absorption cross section, cont its heating that is not radiation (the
    ! units of sum(cab*field)). A net gain is continuous heating; a net loss
    ! scales every photon rate by (gamma + cont)/gamma, gamma = sum(cab*field).
    ! Returns P on qhT, the emission spec(i) = cab(i) sum_u P_u B_nu(T_u)/h
    ! widFlx(i) over the levels whose energy exceeds the photon's (the
    ! equilibrium branch's xSec*getFlux*widFlx, summed over P), the mean T,
    ! emitted/absorbed power and P of the top level. ok = .false. when the
    ! grain has no net heating or no distribution.
    subroutine qhSolve(field, cab, cont, lgCarb, Nat, vg, P, spec, Tmean, ratio, ptop, ok)
      implicit none
      double precision, intent(in)  :: field(:), cab(:)   ! (qhNB)
      double precision, intent(in)  :: cont, Nat, vg     ! heating; atoms; volume [cm^3]
      logical, intent(in)           :: lgCarb
      double precision, intent(out) :: P(:), spec(:)      ! (qhNT), (qhNB)
      double precision, intent(out) :: Tmean, ratio, ptop
      logical, intent(out)          :: ok
      integer          :: i, j, l, u, k1, k2, k3, k4, kc
      double precision :: gam, f, contH, W1, W2, W3, W4, Wc, s, absP, emP
      double precision :: a0, a1, b0, b1, c0, c1, d0, d1

      ok = .false.
      P = 0.d0
      spec = 0.d0
      Tmean = 0.d0
      ratio = 0.d0
      ptop = 0.d0

      gam = 0.d0
      do i = 1, qhNB
         gam = gam + cab(i)*field(i)
      end do
      if (gam <= 0.d0) return
      f = 1.d0
      contH = 0.d0
      if (cont >= 0.d0) then
         contH = cont
      else
         if (gam + cont <= 0.d0) return
         f = (gam + cont)/gam
      end if

      ! the levels: bin j is [Emin(j), Emax(j)], the ground bin from 0
      do j = 1, qhNT
         E(j) = qhEnthalpy(qhT(j), lgCarb, Nat, vg)
      end do
      Emin(1) = 0.d0
      do j = 2, qhNT
         Emin(j) = 0.5d0*(E(j-1) + E(j))
         Emax(j-1) = Emin(j)
      end do
      Emax(qhNT) = E(qhNT) + (E(qhNT) - Emin(qhNT))
      do j = 1, qhNT
         dE(j) = Emax(j) - Emin(j)
      end do

      ! the absorbed power per unit photon energy, and its integrals at the edges
      F0e(0) = 0.d0
      F1e(0) = 0.d0
      do i = 1, qhNB
         if (qhEdge(i) > qhEdge(i-1)) then
            dens(i) = f*cab(i)*field(i)/(qhEdge(i) - qhEdge(i-1))
         else
            dens(i) = 0.d0
         end if
         F0e(i) = F0e(i-1) + dens(i)*(qhEdge(i) - qhEdge(i-1))
         F1e(i) = F1e(i-1) + dens(i)*0.5d0*(qhEdge(i)**2 - qhEdge(i-1)**2)
      end do

      ! upward rates T(u,l)
      Tm = 0.d0
      do l = 1, qhNT-1
         k1 = 1
         k2 = 1
         k3 = 1
         k4 = 1
         do u = l+1, qhNT-1
            W1 = max(Emin(u) - Emax(l), 0.d0)
            if (W1 >= qhEdge(qhNB)) exit              ! no photon reaches u or above
            W2 = min(Emin(u) - Emin(l), Emax(u) - Emax(l))
            W3 = max(Emin(u) - Emin(l), Emax(u) - Emax(l))
            W4 = Emax(u) - Emin(l)
            call qhCum(W1, k1, a0, a1)
            call qhCum(W2, k2, b0, b1)
            call qhCum(W3, k3, c0, c1)
            call qhCum(W4, k4, d0, d1)
            s = ((b1 - a1) - W1*(b0 - a0)) + min(dE(l), dE(u))*(c0 - b0) &
                 & + (W4*(d0 - c0) - (d1 - c1))
            Tm(u,l) = s/(dE(l)*(E(u) - E(l)))        ! DL01 eq 15
         end do
         ! intrabin absorptions into the next level (eq 28, second term)
         kc = 1
         call qhCum(dE(l), kc, a0, a1)
         Tm(l+1,l) = Tm(l+1,l) + (a0 - a1/dE(l))/(E(l+1) - E(l))
         ! the top level takes every photon beyond it, energy-weighted (eq 16)
         W1 = max(Emin(qhNT) - Emax(l), 0.d0)
         Wc = Emin(qhNT) - Emin(l)
         call qhCum(W1, kc, a0, a1)
         call qhCum(Wc, kc, b0, b1)
         s = F0e(qhNB) - b0
         if (Wc > W1) s = s + ((b1 - a1) - W1*(b0 - a0))/(Wc - W1)
         Tm(qhNT,l) = Tm(qhNT,l) + s/(E(qhNT) - E(l))
         ! continuous heating
         if (contH > 0.d0) Tm(l+1,l) = Tm(l+1,l) + contH/(E(l+1) - E(l))
      end do

      ! cooling from u to u-1, at the power radiated at T_u in photons below
      ! E_u (eq 41)
      j = 0
      nI(1) = 0
      pw(1) = 0.d0
      cool(1) = 0.d0
      do u = 2, qhNT
         do while (j < qhNB)
            if (qhEph(j+1) >= E(u)) exit
            j = j + 1
         end do
         nI(u) = j
         s = 0.d0
         do i = 1, j
            s = s + cab(i)*qhB(i,u)
         end do
         pw(u) = pconv*s
         cool(u) = pw(u)/(E(u) - E(u-1))
      end do

      ! the steady state (GD89; DL01 eqs 53-54): Tm(j,l) becomes
      ! B(j,l) = sum_{u >= j} T(u,l)
      do l = 1, qhNT-1
         do u = qhNT-1, l+1, -1
            Tm(u,l) = Tm(u,l) + Tm(u+1,l)
         end do
      end do
      X(1) = 1.d0
      do j = 2, qhNT
         s = 0.d0
         do l = 1, j-1
            s = s + Tm(j,l)*X(l)
         end do
         if (cool(j) > 0.d0) then
            X(j) = s/cool(j)
         else
            X(j) = 0.d0                             ! below the lowest photon energy
         end if
         if (X(j) > 1.d250) then
            do l = 1, j
               X(l) = X(l)*1.d-250
            end do
         end if
      end do
      s = 0.d0
      do j = 1, qhNT
         s = s + X(j)
      end do
      if (.not.(s > 0.d0) .or. s > huge(s)) return

      absP = f*gam + contH
      emP = 0.d0
      do j = 1, qhNT
         P(j) = X(j)/s
         Tmean = Tmean + P(j)*qhT(j)
         emP = emP + P(j)*pw(j)
      end do
      ptop = P(qhNT)
      ratio = emP/absP

      ! the emission: each level's Planck function below its energy
      do u = 2, qhNT
         if (P(u) > 0.d0) then
            do i = 1, nI(u)
               spec(i) = spec(i) + P(u)*qhB(i,u)
            end do
         end if
      end do
      do i = 1, qhNB
         spec(i) = spec(i)*cab(i)
      end do
      ok = .true.
    end subroutine qhSolve

end module qheat_mod
