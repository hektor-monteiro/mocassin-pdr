! Copyright (C) 2005 Barbara Ercolano
!
! Version 2.02
module ionization_mod
    use common_mod             ! common variables
    use constants_mod          ! physical constants
    use xSec_mod               ! x sections module

    ! common variables
    real, allocatable :: contBoltz(:)       ! Boltzman factors for the continuum array
    real, allocatable :: FFOpacity(:)       ! FF opacity
    real, allocatable :: log10nuArray(:)    ! log10(nu) at this cell

    real, allocatable &
         &:: density(:,:)               ! abundance*ionDensity*HDen [cm^-3]

    real, save :: log10Ne               ! log10(Ne) at this cell
    real, save :: log10Te               ! log10(Te) at this cell
    real, save :: sqrTeUsed             ! sqr(Te) at this cell
    real, save :: eDenFFSum=0.          ! sum of heavy elements free electrons


    contains

    ! main routine to drive ionization solution for all species
    subroutine ionizationDriver(grid, ix, iy, iz)
        implicit none

        integer, intent(in) :: ix, iy, iz    ! pointers to cell in the x,y,z grid

        logical, save :: firstLg=.true.      ! first time?

        type(grid_type), intent(inout) :: grid

        ! local variables

        integer :: err                       ! allocation error status
        integer :: i, n                      ! counter


        ! check whether this cell is outside the nebula
        if (grid%active(ix,iy,iz) <= 0) return

        if (firstLg) then
           allocate(density(nElements, nStages), stat=err)
           if (err /= 0) then
              print*, "! ionizationDriver: can't allocate grid memory"
              stop
           end if
        end if

        density=0.

        ! find the physical properties of this cell
        ionDenUsed = grid%ionDen(grid%active(ix, iy, iz), :,:)
        log10Ne = log10(grid%Ne(grid%active(ix, iy, iz)))
        log10Te = log10(grid%Te(grid%active(ix, iy, iz)))
        NeUsed = grid%Ne(grid%active(ix, iy, iz))
        TeUsed = grid%Te(grid%active(ix, iy, iz))
        sqrTeUsed = sqrt(TeUsed)

        density = 0.

        ! find the ion number density [cm^-3] at this cell
        do n = 1, nElements
            do i= 1, min(n, nstages)

                ! check this element is present
                if (.not.lgElementOn(n)) exit
                if (grid%abFileIndex(ix,iy,iz)<=0) then
                   print*, '! ionizationDriver: abundance file index has value: ', grid%abFileIndex(ix,iy,iz)
                   print*, 'Cell: ', ix,iy,iz, grid%active(ix,iy,iz)
                   print*, 'Abundance file index array: ', grid%abFileIndex
                   stop
                end if

                density(n, i) = ionDenUsed(elementXref(n), i)*grid%elemAbun(grid%abFileIndex(ix,iy,iz),n)*&
                     & grid%Hden(grid%active(ix, iy, iz))
           end do
        end do

        ! initialize arrays if this is the first time the procedure is called
        if (firstLg) then
            allocate(log10nuArray(nbins), stat = err)
            if (err /= 0) then
                print*, "! ionizationDriver: can't allocate grid memory"
                stop
            end if
            allocate(contBoltz(nbins), stat = err)
            if (err /= 0) then
                print*, "! ionizationDriver: can't allocate grid memory"
                stop
            end if
            allocate(gauntFF(nbins), stat = err)
            if (err /= 0) then
                print*, "! ionizationDriver: can't allocate grid memory"
                stop
            end if
            allocate(gauntFFHeII(nbins), stat = err)
            if (err /= 0) then
                print*, "! ionizationDriver: can't allocate grid memory"
                stop
            end if
            allocate(FFOpacity(nbins), stat = err)
            if (err /= 0) then
                print*, "! ionizationDriver: can't allocate grid memory"
                stop
            end if

            contBoltz = 0.
            FFOpacity = 0.
            gauntFF = 0.
            gauntFFHeII = 0.
            log10nuArray = log10(nuArray)

            firstLg = .false.

       end if

        ! re-evaluate gaunt factors and boltzmann factors
        call BoltGaunt()

        ! (re)evauate the sum of heavy elements free electrons density
         call eDenSum()

        ! reevaluate all opacities if new ionization
        ! D-109: lgPDR and grid%H2den only exist in the PDR build - guard the
        ! whole block, not just the runtime test (this is the same slip D-096
        ! caught in iteration_mod, and it had broken the plain build again).
#ifdef PDR
        if (lgPDR) then
           if (allocated(grid%opaRep)) then                          ! D-222
              call addOpacity(grid%opacity(grid%active(ix, iy, iz), :), &
                   & grid%H2den(grid%active(ix, iy, iz)), &
                   & grid%opaRep(grid%active(ix, iy, iz), :, :))
           else
              call addOpacity(grid%opacity(grid%active(ix, iy, iz), :), &
                   & grid%H2den(grid%active(ix, iy, iz)))
           end if
        else
           call addOpacity(grid%opacity(grid%active(ix, iy, iz), :))
        end if
#else
        call addOpacity(grid%opacity(grid%active(ix, iy, iz), :))
#endif

    end subroutine ionizationDriver


    ! this subroutine evaluates boltzmann  factors for the continuum
    ! and related variables
    subroutine BoltGaunt()
        implicit none

        ! local variables
        integer :: i                            ! counter
        integer :: iflag                        ! status flag returned by getGauntFF
        integer :: max                          ! upper nu limit given by 0 exp

        real :: exponent                        ! exponenent
        real, save :: TeOld1=-1., TeOld2=-1.    ! te on last run of sub

        ! correction factors for induced recombination
        ! are also used as Boltzmann factors.

        ! check for temperature changes or for first evaluation
        if ( (TeOld1 /= TeUsed) .or. (contBoltz(1) <= 0.) ) then
            TeOld1 = TeUsed
            do i = 1, nbins
                exponent = (Te1Ryd / TeUsed) + nuArray(i)
                if( exponent > 84.) exit
                contBoltz(i) = exp(-exponent)
            end do

            ! set max
            max = i

            ! zero out the remainder
            do i = max, nbins
                contBoltz(i) = 0.
            end do
        end if

        ! find the Gaunt factors
        ! check if temperature has changed by much
        if ( abs(1. - TeOld2/TeUsed) > 0.10 ) then
            call getGauntFF(0., log10Te, log10nuArray, gauntFF, iflag)
            ! following is for ionized helium
            call getGauntFF(0.30103, log10Te, log10nuArray, gauntFFHeII, iflag)
            TeOld2 = TeUsed
        end if
    end subroutine BoltGaunt

    ! this subroutine computes the gaunt factors for any charge
    ! it generates thermally averaged free-free non-relativistic gaunt
    ! factor for a hydrogenic ion of charge z, with a maximum relative
    ! error of 0.007, (rms fitting error = 0.001) for tmps and freqs in
    ! intervals:
    !          10^-4 <= U <= 10^1.5
    !          10^-3 <= Gams <= 10^3~
    ! where U = h*nu/k*T and gams = Z^2 * Ryd / k*T. To obtain the stated
    ! accuracy the full number of significant figures must be retained.
    !
    ! this subroutine uses a two-dimensional chebyshev epansion computed
    ! from expressions given bu Karzas and Latter (ApJSuppl., V.6, P.167,
    ! 1961) augmented by various limiting forms of energy-specific gaunt-
    ! factors.
    ! D.G.Hummer, Jila, May 1987. ApJ 327, 477
    ! modified with correct limits, J Ferguson, July 94
    ! modified for MOCASSIN by B Ercolano (Ercolano et al 2003, MNRAS 340, 1136)
    subroutine getGauntFF(z, log10Te, xlf, g, iflag)
        implicit none

        integer, intent(out) :: iflag                ! explanation given in each area

        real, intent(in) :: log10Te                  ! log10(Te)
        real, intent(in) ::  z                       ! log10 of nuclear charge
        real, dimension(:), intent(in) :: xlf        ! array of log10(h*nu/Ryd)
        real, dimension(size(xlf)), intent(out) :: g ! array of values of g

        ! local variables
        integer ::  i, ir, j

        real, dimension(11) :: b
        real, dimension(8) :: c
        real :: con
        real(kind=8), dimension(88) :: dd
        real(kind=8), dimension(8, 11) :: d
        real :: gamma2                               ! gamma^2 (gams = Z^2 * Ryd / k*T)
        real :: slope                                ! slope
        real :: txg                                  ! hummer variable related to gamma^2
        real :: txu                                  ! hummer variable related to U
        real :: u                                    ! U = h*nu/k*T
        real :: xlrkt                                ! log(ryd/kt)

        dd = (/8.986940175e+00, -4.009515855e+00,  8.808871266e-01,&
&          2.640245111e-02, -4.580645915e-02, -3.568055702e-03,&
&          2.827798067e-03,  3.365860195e-04, -8.006936989e-01,&
&          9.466021705e-01,  9.043402532e-02, -9.608451450e-02,&
&         -1.885629865e-02,  1.050313890e-02,  2.800889961e-03,&
&         -1.078209202e-03, -3.781305103e-01,  1.102726332e-01,&
&         -1.543619180e-02,  8.310561114e-03,  2.179620525e-02,&
&          4.259726289e-03, -4.181588794e-03, -1.770208330e-03,&
&          1.877213132e-02, -1.004885705e-01, -5.483366378e-02,&
&         -4.520154409e-03,  8.366530426e-03,  3.700273930e-03,&
&          6.889320423e-04,  9.460313195e-05,  7.300158392e-02,&
&          3.576785497e-03, -4.545307025e-03, -1.017965604e-02,&
&         -9.530211924e-03, -3.450186162e-03,  1.040482914e-03,&
&          1.407073544e-03, -1.744671550e-03,  2.864013856e-02,&
&          1.903394837e-02,  7.091074494e-03, -9.668371391e-04,&
&         -2.999107465e-03, -1.820642230e-03, -3.874082085e-04,&
&         -1.707268366e-02, -4.694254776e-03,  1.311691517e-03,&
&          5.316703136e-03,  5.178193095e-03,  2.451228935e-03,&
&         -2.277321615e-05, -8.182359057e-04,  2.567331664e-04,&
&         -9.155339970e-03, -6.997479192e-03, -3.571518641e-03,&
&         -2.096101038e-04,  1.553822487e-03,  1.509584686e-03,&
&          6.212627837e-04,  4.098322531e-03,  1.635218463e-03,&
&         -5.918883504e-04, -2.333091048e-03, -2.484138313e-03,&
&         -1.359996060e-03, -5.371426147e-05,  5.553549563e-04,&
&          3.837562402e-05,  2.938325230e-03,  2.393747064e-03,&
&          1.328839809e-03,  9.135013312e-05, -7.137252303e-04,&
&         -7.656848158e-04, -3.504683798e-04, -8.491991820e-04,&
&         -3.615327726e-04,  3.148015257e-04,  8.909207650e-04,&
&          9.869737522e-04,  6.134671184e-04,  1.068883394e-04,&
&         -2.046080100e-04/)

        d = reshape( dd, (/8, 11/) )

        ! compute temperature dependent coeffcients for U expansion

        ! xlrxt is log(ryd/kt), code note valid for Te > 10^8
        ! xlrxt is log(ryd/kt), code note valid for Te < 10^2.5
        if ( log10Te < 2.5 ) then
            xlrkt = 5.1983649 - 2.5
        else if ( log10Te > 8. ) then
            xlrkt = 5.1983649 - 8.
        else
            xlrkt = 5.1983649 - log10Te
        end if

        ! set txg
        txg = 0.66666667*(2.0*z+xlrkt)
        gamma2 = 10**(txg*1.5)

        con = 0.72727273*xlrkt+0.90909091
        do j=1,8
            ir = 9
            b(11) = real(d(j,11))
            b(10) = real(txg*b(11)+d(j,10))
            do i=1,9
                b(ir) = real(txg*b(ir+1)-b(ir+2)+d(j,ir))
                ir = ir-1
            end do
            c(j) = 0.25*(b(1)-b(3))
        end do

        ! sum U expansion
        ! loop through energy at fixed temperature
        do i = 1, size(xlf)
            txu = 0.72727273*xlf(i)+con
            u = 10**((txu - .90909091)/.72727273)
            ! criteria set by hummer limits. it is a wedge from
            ! log(hnu),log(T)) =
            ! (-5,2.5) to (-5,4) to (-1,8) to (4,8) to (-1.5,2.5).
            ! these limits correspond to the gamma^2 and U limits
            ! given above
            if(abs(txu)<=2.0) then
                ir = 6
                b(8) = c(8)
                b(7) = txu*b(8)+c(7)
                do j=1,6
                    b(ir) = txu*b(ir+1)-b(ir+2)+c(ir)
                    ir = ir-1
                end do
                g(i) = b(1)-b(3)
                if( (log10Te>=2.5) .and. (log10Te<=8.0)) iflag = 0
                ! On the bottom side of the hummer box,u<-4 and gamma2>.33
            else if( (log10(u)<-4.0) .and. (gamma2<0.3) ) then
               g(i) = 0.551329 * log(2.24593/u)
              if( (log10Te>=2.5) .and. (log10Te<=8.0) ) iflag = 2
            ! On the bottom side of the box,u<-4 and gamma2<.33
            else if( (log10(u)<-4.0) .and. (gamma2>=0.3) ) then
                g(i) = 0.551329 * alog( 0.944931/u/sqrt(gamma2) )
                if( (log10Te>=2.5) .and.( log10Te<=8.0) ) iflag = 3
                ! Now on the bottom side of the box
                else if (txu>2.0) then
                ! Top of the box high T first
                if (log10(gamma2)<-3.) then
                    g(i) =  sqrt(0.9549297/u)
                    if(log10Te>=2.5.and.log10Te<=8.0) iflag = 4
                    ! Must interpolate between two asymptotes
                else if(log10(gamma2)<0.0) then
                    slope = ( sqrt(12*gamma2/u) - sqrt(0.9549297/u) ) / 3.0
                    g(i) =  sqrt(12*gamma2/u) + slope * log10(gamma2)
                    if((log10Te>=2.5) .and. (log10Te<=8.0)) iflag = 7
                else
                ! The top side with wedge of 1.05 where region 6 fails
                    g(i) = sqrt(12. * gamma2 / u)
                    g(i) = min(1.05,g(i))
                    if( (g(i)==1.05) .and. (log10Te>=2.5) .and. (log10Te<=8.0)) &
                         & iflag = 5
                    if( (g(i)<1.05) .and. (log10Te>=2.5) .and. (log10Te<=8.0)) &
                         & iflag = 6
                end if
            end if
            u = 0.0
        end do
    end subroutine getGauntFF


    ! this subroutine sums up the free electron density over all species
    subroutine eDenSum()
        implicit none

        ! local variables
        integer :: n, i                                           ! counters

        ! sum the heavy metal free electron density
        eDenFFSum = 0.
        do n = 3, nElements
            do i = 1, min(n, nstages-1)
                eDenFFSum = eDenFFSum + float(i*i)*density(n, i+1)
            end do
        end do
    end subroutine eDenSum

    ! D-141. H2 photoionization cross section, Yan, Sadeghpour & Dalgarno
    ! 1998 ApJ 496, 1044, with the revisions of the 2001 erratum (ApJ 559,
    ! 1194). Ported from Cloudy c25's Yan_H2_CS (source/mole_h2_etc.cpp), which
    ! is the same published fit; the branch boundaries, coefficients and the
    ! E^-7/2 scaling are Cloudy's exactly.
    !
    ! This replaces the single power law of D-107, whose own comment asked for
    ! the tabulated cross section once an approximation stopped being adequate.
    ! It was not merely imprecise but the wrong shape: the true cross section
    ! RISES from threshold to 9.8e-18 cm^2 at 18 eV before falling, while the
    ! power law fell monotonically from 6.2e-18 - a factor 2.5 too low right
    ! across the peak, and a factor 2 too high just above threshold.
    !
    ! Returns cm^2. Zero below the 15.4 eV threshold: H2 absorption in the
    ! 13.6-15.4 eV window is line opacity in the higher electronic bands, not a
    ! continuum, and Cloudy treats it that way too (D-139).
    function yanH2xSec(nu) result(xsec)
      implicit none
      real, intent(in) :: nu      ! photon energy [Ryd]
      real             :: xsec    ! [cm^2]
      real             :: e, ekev, x, xsq, x15, x2
      e = nu*13.605693
      xsec = 0.
      if (e < 15.4) return
      x    = e/15.4
      ekev = e/1000.
      xsq  = sqrt(x)
      x15  = x*xsq
      x2   = x*x
      if (e < 18.) then
         xsec = 1.e7*(1. - 197.448/xsq + 438.823/x - 260.481/x15 + 17.915/x2)
         ! the fit is negative at threshold; Cloudy clamps it the same way
         xsec = max(0., xsec)
      else if (e <= 30.) then
         xsec = (-145.528 + 351.394*xsq - 274.294*x + 74.320*x15)/ekev**3.5
      else if (e <= 85.) then
         xsec = (65.304 - 91.762*xsq + 51.778*x - 9.364*x15)/ekev**3.5
      else
         xsec = 45.57*(1. - 2.003/xsq - 4.806/x + 50.577/x15 - 171.044/x2 &
              & + 231.608/(xsq*x2) - 81.885/(x*x2))/ekev**3.5
      end if
      xsec = xsec*1.e-24            ! barns -> cm^2
    end function yanH2xSec

    subroutine addOpacity(opacity, H2density, comp)
        implicit none

        real, dimension(:), intent(out) :: opacity                !  opacity
        real, intent(in), optional      :: H2density               ! n(H2) [cm^-3] (D-107)
        ! D-222: each gas absorber's share at the four hard representative bins
        real, dimension(:,:), intent(out), optional :: comp   ! (band 2-5 -> 1-4, absorber 1-6)
        real    :: snapP(0:6, 2:5)
        logical :: lgComp

       ! local variables

        integer :: i                                           ! counters
        real    :: fac1, fac2, fac3       ! factors to be used in calculations

        ! (re) initialize opacity arrays
        opacity = 0.
        lgComp = present(comp)
        if (lgComp) call setHardBands()
        if (lgComp) lgComp = (bandRepP(5) > 0)
        snapP = 0.

        ! D-107: H2 photoionization continuum, threshold 15.43 eV = 1.1345 Ryd.
        ! MOCASSIN otherwise has no absorber below the Lyman edge but atomic
        ! hydrogen - no H-minus, no Rayleigh - so once the coupling makes the
        ! neutral fraction physically small (D-099), photons between 13.6 and
        ! whatever this covers pass through the whole cloud unabsorbed and heat
        ! dust far from the surface (D-103/D-104). This restores that missing
        ! absorber; it does not touch the 912-2400 A band the PDR already owns,
        ! so it cannot double-count against 3D-PDR's shielding.
        !
        ! sigma(nu): threshold ~6e-18 cm^2 rising to a broad peak of order
        ! 1e-17 cm^2 near 18-20 eV then falling off - Backx, Wight & Van der
        ! Wiel (1976); Chung, Lee & Gallagher (1993); Yan, Sadeghpour & Dalgarno
        ! (1998) for the tabulated cross section this approximates. The fit
        ! below is a single power law anchored at threshold, NOT a reproduction
        ! of the resonance structure near 15-18 eV - it is restoring an
        ! absorber that is otherwise entirely absent, not a spectroscopic
        ! result. Revisit with the tabulated cross section if the ionization
        ! structure of molecular gas ever needs to be more than a guard against
        ! this failure mode.
        if (present(H2density)) then
           if (H2density > 0.) then
              do i = 1, nbins
                 if (nuArray(i) >= 1.1345) then
                    ! D-139 (reverted): an H2 continuum was briefly added between
                    ! 1.0 and 1.1345 Ryd on the theory that the Lyman continuum
                    ! was leaking to A_V ~ 1.5. Two things killed it. Cloudy's
                    ! own H2 cross section (Yan, Sadeghpour & Dalgarno, in
                    ! mole_h2_etc.cpp:Yan_H2_CS) is explicitly ZERO below
                    ! 15.4 eV - it covers that window with H2 line absorption in
                    ! the higher electronic bands, not a continuum. And the
                    ! premise was false anyway: measured x(H) in deep PDR cells
                    ! is 0.189, not the 0.002 of D-099, so atomic hydrogen alone
                    ! gives tau = 230 PER CELL at the Lyman edge and tau ~ 5000
                    ! to that depth. Nothing is leaking; the H I photoionization
                    ! heating measured there has another cause.
                    opacity(i) = opacity(i) + H2density*yanH2xSec(nuArray(i))
                 end if
              end do
           end if
        end if

        if (lgComp) snapP(1, 2:5) = opacity(bandRepP(2:5))      ! D-222: after H2
        ! hydrogen helium and heavy element brems (free-free) opacity,
        ! assuming hydrogen ff gaunt factors
        ! xSecArray is missing factor of 1.e-20 to avoid underflow.
        fac1 = (NeUsed/1.e10) * ( (density(1,2) + density(2, 2) + &
             & 4.*density(2, 3) + eDenFFSum)/1.e10 ) / sqrTeUsed
        fac2 = fac1 * Te1Ryd / TeUsed

        do i = 1, nbins

           if (i>1) then
              if (FFOpacity(i-1)<1.e-35) then
                 FFOpacity(i) = 0.
              end if
           else
              if (contBoltz(i) < 0.995 ) then
                 ! 1-exp(hn/kT) is used only is exp is small
                 ! the last term is scaled h minus free-free absorption

                 fac3 = xSecArray(i-1+bremsXSecP)*(1.-contBoltz(i))*gauntFF(i)

                 FFOpacity(i) = fac3 * fac1

              else

                 fac3 = xSecArray(i-1+bremsXSecP)*nuArray(i)*gauntFF(i)
                 FFOpacity(i) = fac3 * fac2

              end if
           end if

           opacity(i) = opacity(i) + FFOpacity(i)
        end do

       ! hydrogen lyman continuum photoelectric opacity
       if (lgComp) snapP(2, 2:5) = opacity(bandRepP(2:5))       ! D-222: after free-free
       call inOpacity(HlevXSecP(1), HlevNuP(1), nbins, density(1,1), 0.)
       if (lgComp) snapP(3, 2:5) = opacity(bandRepP(2:5))       ! D-222: after H0

       ! NOTE: the opacity due to the excited levels of HI, HeI and HeII is
       ! neglected for now as it requires calculations of the densities of
       ! the excited levels populations -> 4th argument in inOpacity is density
       ! of the lower level [cm^-3]

       ! helium singlets HeI (ground special because it extends to the high energy limit)
       call inOpacity(HeISingXSecP(1), HeIlevNuP(1), nbins, density(2, 1), 0.)
       if (lgComp) snapP(4, 2:5) = opacity(bandRepP(2:5))       ! D-222: after He0

       ! ionized helium HeII (ground special because it extends to the high energy limit)
       call inOpacity(HeIIXSecP(1), HeIIlevNuP(1), nbins, density(2, 2), 0.)
       if (lgComp) snapP(5, 2:5) = opacity(bandRepP(2:5))       ! D-222: after He+

       do i = 3, nElements
          if ( lgElementOn(i) ) call putOpacity(i)
       end do
       ! D-222: each absorber's share, as the difference between successive
       ! snapshots of the running total at the representative bins
       if (lgComp) then
          snapP(6, 2:5) = opacity(bandRepP(2:5))
          comp = 0.
          do i = 2, 5
             comp(i-1, 1) = snapP(1, i)                    ! H2
             comp(i-1, 2) = snapP(2, i) - snapP(1, i)      ! free-free
             comp(i-1, 3) = snapP(3, i) - snapP(2, i)      ! H0
             comp(i-1, 4) = snapP(4, i) - snapP(3, i)      ! He0
             comp(i-1, 5) = snapP(5, i) - snapP(4, i)      ! He+
             comp(i-1, 6) = snapP(6, i) - snapP(5, i)      ! heavier elements
          end do
       end if

       contains

         ! this subroutine enters the total phoo cross section
         ! for all subshells into opacity array. it drives inOpacity
         ! to put in total opacities
         subroutine putOpacity(nElem)
             implicit none

             integer, intent(in)               :: nElem

             ! local variables
             integer :: nIon                  ! counter
             integer :: nuLowP, nuHighP       ! pointers to lower and highert limit of energy range
             integer :: nShell                ! counter
             integer :: xSecP                 ! pointer to x scetion in xSecArray


             do nIon = 1, min(nElem, nstages)
                 if ( density(nElem, nIon) > 0. ) then

                     ! number of bound electrons
                     do nShell = 1, nShells(nElem, nIon)
                         nuLowP = elementP(nElem, nIon, nShell, 1)
                         nuHighP = elementP(nElem, nIon, nShell, 2)
                         xSecP = elementP(nElem, nIon, nShell, 3)
                         call inOpacity(xSecP, nuLowP, nuHighP, density(nElem, nIon), 0.)
                     end do

                 end if
             end do
          end subroutine putOpacity

         ! this subroutine adds the opacity of individual species,
         ! it can include stimulated emission. the departure coefficient b
         ! can be set to zero.
         subroutine inOpacity(xSecP, nuLowP, nuHighP, den, b)
             implicit none

             integer, intent(in)               :: nuLowP, nuHighP  ! pointers to lower and higher limits in nuArray
             integer, intent(in)               :: xSecP            ! x section pointer

             real, intent(in)                  :: b                ! departure coefficient
             real, intent(in)                  :: den              ! density of the lower level [cm^-3]

             ! local variables
             integer             :: i                              ! counter
             integer             :: iup                            ! upper limit
             integer             :: k                              ! offset

             real                :: bInv                           ! 1./b

             k = xSecP - nuLowP
             iup = min(nuHighP, nbins)
             iup = max(nuLowP, iup)
             if (b > 1e-35) then
                 bInv = 1./b
                 do i = nuLowP, iup
                     opacity(i) = opacity(i) + xSecArray(i+k)*den*&
&                                  max(0., 1.-contBoltz(i)*bInv)
                 end do
             else
                 do i = nuLowP, iup

                     opacity(i) = opacity(i) + xSecArray(i+k)*den

                end do
             end if


        end subroutine inOpacity

    end subroutine addOpacity

end module ionization_mod


