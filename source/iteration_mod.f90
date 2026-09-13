! Copyright (C) 2005 Barbara Ercolano
!
! Version 2.02
module iteration_mod
    use common_mod
    use continuum_mod
    use emission_mod
    use ionization_mod
    use output_mod
#ifdef PDR
    use pdr_mod
#endif
    use photon_mod
    use update_mod

    implicit none

    contains

    subroutine MCIterationDriver(grid)
       implicit none

       type(grid_type), intent(inout) :: grid(*) ! the 3D cartesian grid

       ! local variables

       integer :: i, j, k                     ! counters
        ! D-119: the coupling loop wraps updateCell, which compiles in EVERY
        ! flavour, so these cannot sit behind #ifdef PDR. Third time this trap
        ! has been sprung in this file - see D-096 and D-109.
        real, allocatable :: ionDenPrev(:,:,:)
        integer           :: iCouple, iDum, jDum, kDum
        integer           :: nCv1                      ! D-175
        double precision  :: wNew, fWt

       ! To perform message spliting in mpi
       integer :: chunk_start, chunk_end, chunk_size, chunk, nCells
       integer :: num_chunks, chunk_elements
       real, allocatable :: temp_chunk(:,:,:)

       call iterateMC()

       contains

       recursive subroutine iterateMC()
           implicit none
           include 'mpif.h'

           ! local variables
           real, allocatable :: budgetTemp(:,:)      ! temporary dust heating budget array
           real, allocatable :: dustPDFTemp(:,:)     ! temporary dust emission PDF array
           real, allocatable :: escapedPacketsTemp(:,:,:)!temporary escaped packets array
           real, allocatable :: fEscapeResPhotonsTemp(:,:) ! temporary escape res line phot
#ifdef PDR
           integer :: i1PdrStuck                             ! cells whose chemistry stalled
           real, allocatable :: pdrHeatTmp(:), pdrHeatSum(:)
           real, allocatable :: pdrCoolTmp(:), pdrCoolSum(:)
           double precision, allocatable :: pdrLevTmp(:,:), pdrLevSum(:,:)
           real, allocatable :: pdrTgTmp(:), pdrTgSum(:), pdrTlTmp(:), pdrTlSum(:)
           real, allocatable :: pdrThTmp(:), pdrThSum(:)
           real, allocatable :: pdrHeatPETmp(:), pdrHeatPESum(:)
           real, allocatable :: pdrHeatGGTmp(:), pdrHeatGGSum(:)      ! D-096
           real, allocatable :: pdrCoolSlTmp(:), pdrCoolSlSum(:)      ! D-166
           real, allocatable :: pdrCoolTrTmp(:), pdrCoolTrSum(:)      ! D-166
           real, allocatable :: NePDRTmp(:), NePDRSum(:)              ! D-105
           real, allocatable :: H2denTmp(:), H2denSum(:)              ! D-107
           real, allocatable :: pdrCoolSpTmp(:,:), pdrCoolSpSum(:,:)  ! D-096
           real, allocatable :: pdrIonRateTmp(:,:), pdrIonRateSum(:,:) ! D-118
           integer, allocatable :: pdrZoneSum(:)
           double precision, allocatable :: pdrAbunTemp(:,:) ! this rank's owned cells
           double precision, allocatable :: pdrAbunSum(:,:)  ! reassembled grid
           ! D-200: iteration-start snapshots for the damping below. Local
           ! rather than grid arrays: they are needed only between the top and
           ! the bottom of one iterateMC call, and keeping them off the grid
           ! keeps them out of the checkpoint and out of resetGrid.
           double precision, allocatable :: pdrAbunIter(:,:)
           real,             allocatable :: ionDenIter(:,:,:)
           ! D-196: is the convergence test measuring anything?
           real(kind=8), allocatable :: cvBud(:), cvXH0(:), cvDlt(:), cvRat(:)
           integer                   :: nBud, nPin, nBad, nRat, nZero
           real(kind=8)              :: avSum, bMin, bMax, bMed, xMed, dMed
           real(kind=8)              :: h2Sum, xHp, xHpChem
           ! D-202: the molecular fraction's own distribution and movement,
           ! which is what the D-200 three-way branch label was standing in for.
           real(kind=8), allocatable :: cvMol(:), cvDMl(:), cvTe(:)
           ! D-203: the field the chemistry was handed, alongside the answer
           ! it gave, so a swing in f_mol can be attributed to the radiative
           ! transfer or ruled out of it.
           real(kind=8), allocatable :: cvChi(:), cvAv(:)
           integer                   :: molHist(8), iBin, nMv10, nMv50
           integer                   :: nWarm, nHotBr
           real(kind=8)              :: fMol, fMolWas, molSum
           ! D-204: Te sampled after the first updateCell of the iteration -
           ! thermal balance done, chemistry not yet run - so the ordering of
           ! Te against f_mol can be measured instead of inferred.
           integer                   :: nUpd1, nUpd1Hot, nStHot
           real(kind=8)              :: teUpd1Sum, teStSum, molStSum
           ! D-205: the same snapshot on EVERY coupling pass, with the cooling
           ! terms, because the runaway happens inside the loop and the loop's
           ! own residual cannot see it.
           real(kind=8)              :: molUpdSum, pcSum, phSum, ppeSum
           real(kind=8)              :: pcSubSum, pcNulSum   ! D-210
           real(kind=8)              :: tfacSum, trefSum, slopSum   ! D-213
           real(kind=8)              :: budSum(3,21)                ! D-217
           integer                   :: iBudG, iBudT                ! D-217
           character(len=11)         :: budLab(3)                   ! D-217
           real(kind=8)              :: budSum2(3,9)                ! D-218
           integer                   :: iLastG                      ! D-218
           real(kind=8)              :: dxCell                      ! D-218
           real(kind=8)              :: budSum3(3,4)                ! D-221
           integer, save             :: iH2thrC = 0                 ! D-221
           integer                   :: iNuD                        ! D-221
           real(kind=8)              :: budSum4(3,42)               ! D-222
           integer                   :: kBd, mBd, nOpaRep           ! D-222
           real(kind=8)              :: budSum5(3,8)                ! D-223
           integer                   :: iOffD, niD, njD, nkD, nbD   ! D-223
           integer                   :: nHotD, nUpD, nDnD           ! D-223
           real(kind=8)              :: budSum6(3,15)               ! D-224
           real(kind=8)              :: tNbD, tMinD, tUpMinD        ! D-224
           integer                   :: nbMinD, iHD                 ! D-224
           real(kind=8)              :: budSum7(3,7)                ! D-225
           real(kind=8)              :: jbD, jdD, tj1D, tj4D, sclD  ! D-225
           real(kind=8)              :: sJ225, sT225                ! D-225
           integer                   :: nC225, nMis225, iC225       ! D-225
           real(kind=8)              :: budSum8(3,70), budSum9(3,64) ! D-226
           real(kind=8)              :: pLinD, dP226                ! D-226
           integer                   :: nB226, kB226, kTopP, kTopJ  ! D-226
           real(kind=8)              :: spSum(4)                    ! D-213
           integer                   :: iCoolD                      ! D-213
#endif
           real, allocatable :: JDifTemp(:,:)        ! temporary diffuse field array
           real, allocatable :: JSteTemp(:,:)        ! temporary stellar field array
           real, allocatable :: linePacketsTemp(:,:) ! temporary line packets array
           real, allocatable :: opacityTemp(:,:)     ! temporary opacities array
           real, allocatable :: recPDFTemp(:,:)      ! temporary rec prob distribution function
           real, allocatable :: linePDFTemp(:,:)     ! temporary line prob distribution function
           real, allocatable :: totalLinesTemp(:)    ! temporary fraction of non-ionizing line phots

           real, allocatable          :: noHitPercent(:)    ! percentage of no Hit cells
           real, allocatable          :: noIonBalPercent(:) ! percentage of cell where ion bal not conv
           real, allocatable          :: noTeBalPercent(:)  ! percentage of cell where Te bal not conv
           real,save              :: totPercentOld   ! percentage of converged cells from prev iteration
           real                   :: totCells        ! total # of active cells
           real                   :: totheatdust     ! total dust heating

           integer, allocatable       :: planeIonDistributionTemp(:,:)
           integer, allocatable       :: resLinePacketsTemp(:) ! temporary array for extra packets
           integer                :: err             ! allocation error status
           integer                :: freq,nS         ! counters
           integer                :: ifreq, ian      ! counters
           integer                :: ios,iG          ! I/O error status
           integer(kind=8)        :: load,rest       !
           integer(kind=8)        :: teNsum(8), teBrkSum(teNbin)  ! D-165
           integer(kind=8)        :: teNsum2(4)                 ! D-166/D-167/D-168
           integer(kind=8)        :: cvS(4), cvHS(12), cvXS(9), cvAS(7)  ! D-170
           integer(kind=8)        :: cvS2(4)                             ! D-172
           integer(kind=8)        :: cvS3(4)                             ! D-173
           integer(kind=8)        :: cvS4                                ! D-176
           real(kind=8)           :: wDum                                ! D-178
           integer(kind=8)        :: cvS5(4)                             ! D-179, (4) D-229
           integer(kind=8)        :: cvTS(12), cvTAS(7), cvS6(3)         ! D-248
           character(len=80)      :: chNotConv                           ! D-172
           integer(kind=int64)    :: size            ! size for mpi
           integer                :: iCell           ! cell index including non-active
           integer                :: iStar           ! star index
           integer                :: ai              ! grain size counter
           integer                :: icontrib,icomp ! counters
           integer                :: imu             ! direction cosine
           integer                :: cellLoc(3)      ! local cell counters
           integer                :: gpLoc           ! local grid counter
           integer                :: ii,jj,kk        ! counters
           integer                :: ngridloc
           integer                :: yTop

           integer                :: dcp, nsp

           character(len=10)      :: time            ! to display time when each iteration finishes

           allocate(noHitPercent(nGrids))
           allocate(noIonBalPercent(nGrids))
           allocate(noTeBalPercent(nGrids))

           ! re-initialize MC estimators
           do iG = 1, nGrids
              grid(iG)%lgConverged(0:grid(iG)%nCells)    = 0
              grid(iG)%lgBlack(0:grid(iG)%nCells)        = 0
              if (lgGas) then
                 ! zero out PDF arrays
                 grid(iG)%recPDF(0:grid(iG)%nCells, 1:nbins) = 0.
                 ! D-232: zeroed with the PDF it describes. emissionDriver only
                 ! clears the cells a rank owns, so without this the sum across
                 ! ranks would accumulate from one iteration to the next.
                 if (allocated(grid(iG)%pdfSrc)) grid(iG)%pdfSrc = 0.
                 ! D-157: linePDF is allocated only under `if (nLines > 0)`
                 ! (grid_mod:1571), but this zeroing was guarded on lgDebug
                 ! alone - so enabling `debug` on a model with no line list
                 ! wrote to an unallocated array and segfaulted. That is why
                 ! debug mode has been unusable, and with it the only way to
                 ! separate Jste from Jdif.
                 ! ...and `nLines > 0` is not the right guard either: nLines is
                 ! still 0 when the grid is built and is set later in hydro_mod,
                 ! so the allocation guard and any use guard read different
                 ! values. Test the allocation itself.
                 if (lgDebug .and. allocated(grid(iG)%linePDF)) &
                      & grid(iG)%linePDF(0:grid(iG)%nCells, 1:nLines) = 0.
                 grid(iG)%totalLines(0:grid(iG)%nCells) = 0.

                 ! zero out Balmer jump
                 BjumpTemp = 0.
                 Bjump     = 0.
              end if

              if (lgDust) then   ! D-233: with gas too, now that dust re-emits
                 ! zero out dust PDF arrays
                 grid(iG)%dustPDF(0:grid(iG)%nCells, 1:nbins)     = 0.
              end if
           end do

!*****************************************************************************

           iCell = 0

           do iG = 1, nGrids

              if (ig>1 .or. (.not.lg2D)) then
                 yTop = grid(iG)%ny
              else if (iG ==1 .and. lg2D) then
                 yTop = 1
              end if


              grid(iG)%opacity(0:grid(iG)%nCells, 1:nbins) = 0.
#ifdef PDR
              ! D-222: zeroed with the opacity, so the sum across ranks below
              ! carries only this iteration's capture
              if (allocated(grid(iG)%opaRep)) grid(iG)%opaRep = 0.
#endif

              if (lgGas) then
                 if (taskid==0) print*, '! iterateMC: ionizationDriver in', iG
                 ! calculate the opacities at every grid cell
                 do i = 1, grid(iG)%nx
                    do j = 1, yTop
                       do k = 1, grid(iG)%nz
                          iCell = iCell+1
                          if (mod(iCell-(taskid+1),numtasks)==0) &
                               & call ionizationDriver(grid(iG),i,j,k)
                       end do
                    end do
                 end do
                 if (taskid==0) print*, '! iterateMC: ionizationDriver out', iG

                 allocate(opacityTemp(0:grid(iG)%nCells, 1:nbins), stat = err)
                 if (err /= 0) then
                    print*, "! iterateMC: can't allocate array memory: opacityTemp ", iG
                    stop
                 end if

                 opacityTemp = 0.

                 size = (grid(iG)%nCells+1)*nbins

                 call mpi_allreduce(grid(iG)%opacity, opacityTemp, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)


                 do i = 1, grid(iG)%nx
                    do j = 1, yTop
                       do k = 1, grid(iG)%nz
                          do freq = 1, nbins

                             if (grid(iG)%active(i,j,k)>0) then
                                grid(iG)%opacity(grid(iG)%active(i,j,k),freq) = opacityTemp(grid(iG)%active(i,j,k),freq)
                             end if

                          end do
                       end do
                    end do
                 end do
                 if ( allocated(opacityTemp) ) deallocate(opacityTemp)
#ifdef PDR
                 ! D-222: the absorber split is captured where ionizationDriver
                 ! runs, which is not necessarily the rank the census counts a
                 ! cell on (the iCell counters differ across grids), so it is
                 ! summed across ranks exactly as the opacity is
                 if (lgPDR .and. allocated(grid(iG)%opaRep)) then
                    nOpaRep = (grid(iG)%nCells + 1)*4*6
                    call mpi_allreduce(MPI_IN_PLACE, grid(iG)%opaRep, nOpaRep, &
                         & mpi_real, mpi_sum, mpi_comm_world, ierr)
                 end if
#endif

              end if

              ! add dust contribution to total opacity
              if (taskid==0) print*, '! iterateMC: adding dust contribution to total opacity ',iG
              if (lgDust) then
                 grid(iG)%scaOpac(0:grid(iG)%nCells, 1:nbins) = 0.
                 grid(iG)%absOpac(0:grid(iG)%nCells, 1:nbins) = 0.

                 if((nIterateMC==1 .and. lgEquivalentTau)) then
                    grid(iG)%scaOpac(0:grid(iG)%nCells, 1:nbins) = 0.
                    grid(iG)%absOpac(0:grid(iG)%nCells, 1:nbins) = 0.
                 else


                    if (ig>1 .or. (.not. lg2D)) then
                       yTop = grid(iG)%ny
                    else if (iG ==1 .and. lg2D) then
                       yTop = 1
                    end if

                    do i = 1, grid(iG)%nx
                       do j = 1, yTop
                          do k = 1, grid(iG)%nz
                             if (grid(iG)%active(i,j,k)>0) then
                                if (lgMultiDustChemistry) then
                                   dcp = dustComPoint(grid(iG)%dustAbunIndex(grid(iG)%active(i,j,k)))
                                   nsp = grid(iG)%dustAbunIndex(grid(iG)%active(i,j,k))
                                else
                                   dcp = dustComPoint(1)
                                   nsp = 1
                                end if

                                do nS = 1, nSpeciesPart(nsp)

                                   do ai = 1, nSizes
                                      if (grid(iG)%Tdust(nS,ai,grid(iG)%active(i,j,k))<TdustSublime(dcp-1+nS)) then
                                         do freq = 1, nbins
                                            grid(iG)%scaOpac(grid(iG)%active(i,j,k),freq) = &
                                                 & grid(iG)%scaOpac(grid(iG)%active(i,j,k),freq) + &
                                                 & grainAbun(nsp,nS)*&
                                                 & grainWeight(ai)*grid(iG)%Ndust(grid(iG)%active(i,j,k))*&
                                                 & xSecArray(dustScaXsecP(nS+dcp-1,ai)+freq-1)
                                            grid(iG)%absOpac(grid(iG)%active(i,j,k),freq) = &
                                                 & grid(iG)%absOpac(grid(iG)%active(i,j,k),freq) + &
                                                 & grainAbun(nsp,nS)&
                                                 & *grainWeight(ai)*grid(iG)%Ndust(grid(iG)%active(i,j,k))*&
                                                 & xSecArray(dustAbsXsecP(nS+dcp-1,ai)+freq-1)
                                         end do
                                      end if
                                   end do
                                end do

                                do freq = 1, nbins
                                   grid(iG)%opacity(grid(iG)%active(i,j,k),freq) = &
                                        &grid(iG)%opacity(grid(iG)%active(i,j,k),freq) + &
                                        & (grid(iG)%scaOpac(grid(iG)%active(i,j,k),freq) + &
                                        &grid(iG)%absOpac(grid(iG)%active(i,j,k),freq))
                                end do
                             end if

                          end do
                       end do
                    end do
                 end if

              end if
              if (taskid==0) print*, '! iterateMC: dust contribution to total opacity added ',iG

           end do ! ngrids

           call mpi_barrier(mpi_comm_world, ierr)


!*****************************************************************************




           if (taskid==0 .and. lgWritePss) then
              open(unit=89, file='output/qHeatPss.out',  action="write",status='unknown', position='rewind', iostat=ios)
              if (ios /= 0) then
                 print*, "! iterationMC: can't open file for writing, output/qHeatPss.out"
                 stop
              end if
           end if

           ! check if min convergence was reached to carry out resonant line transfer
           if (lgDust .and. lgGas .and. convPercent>=resLinesTransfer .and. lgResLinesFirst &
                &.and. (.not.nIterateMC==1)) then

              call initResLines(grid(1:nGrids))

              do iG = 1, nGrids
                 if (allocated(fEscapeResPhotonsTemp)) deallocate(fEscapeResPhotonsTemp)
                 allocate(fEscapeResPhotonsTemp(0:grid(iG)%nCells, 1:nResLines), stat &
                      &= err)
                 if (err /= 0) then
                    print*, "! iterateMC: can't allocate array&
                         & memory:fEscapeResPhotonsTemp"
                    stop
                 end if
                 fEscapeResPhotonsTemp = 0.

                 if (allocated(resLinePacketsTemp)) deallocate(resLinePacketsTemp)
                 allocate(resLinePacketsTemp(0:grid(iG)%nCells), stat &
                      &= err)
                 if (err /= 0) then
                    print*, "! iterateMC: can't allocate array&
                         & memory:resLinePacketsTemp"
                    stop
                 end if
                 resLinePacketsTemp = 0

              end do
           end if

           ! set the diffuse PDFs at every grid cell
           do iG = 1, nGrids

              if (ig>1 .or. (.not.lg2D) ) then
                 yTop = grid(iG)%ny
              else if (iG ==1 .and. lg2D) then
                 yTop = 1
              end if


              if (taskid==0) print*, '! iterateMC: emissionDriver in',iG
              iCell = 0
              do i = 1, grid(iG)%nz
                 do j = 1, yTop
                    do k = 1, grid(iG)%nx
                       iCell = iCell+1
                       if (mod(iCell-(taskid+1),numtasks)==0) &
                            & call emissionDriver(grid,k,j,i,iG)
                    end do
                 end do
              end do

              if (taskid==0) print*, '! iterateMC: emissionDriver out', iG
              if (taskid==0 .and. lgWritePss) close(89)

              if (lgDust) then   ! D-233
                 allocate(dustPDFTemp(0:grid(iG)%nCells, 1:nbins),&
                      & stat = err)
                 if (err /= 0) then
                    print*, "! iterateMC: can't allocate array memory:&
                         & dustPDFTemp ", iG
                    stop
                 end if
                 dustPDFTemp = 0.
              end if

              if (lgGas) then
                 call mpi_allreduce(BjumpTemp, Bjump, 1, mpi_real&
                      &, mpi_sum, mpi_comm_world, ierr)

                 ! Balmer jump is in [erg/s/A] since factor of e-40 from gas emissivity
                 ! and factor of e45 from volume calculations, so multiply by e5
                 if (lgSymmetricXYZ) Bjump = Bjump*8.
                 Bjump = Bjump*1.e5

                 if (taskid==0) print*, "Balmer Jump: [erg/s/A] ", Bjump

                 allocate(recPDFTemp(0:grid(iG)%nCells, 1:nbins),&
                      & stat = err)
                 if (err /= 0) then
                    print*, "! iterateMC: can't allocate array memory:&
                         & recPDFTemp "
                    stop
                 end if

                 allocate(totalLinesTemp(0:grid(iG)%nCells), stat =&
                      & err)
                 if (err /= 0) then
                    print*, "! iterateMC: can't allocate array memory:&
                         & opacityTemp "
                    stop
                 end if

                 recPDFTemp = 0.
                 totalLinesTemp = 0.

              end if

              if (lgDebug) then
                 allocate(linePDFTemp(0:grid(iG)%nCells, nLines),&
                      & stat = err)
                 if (err /= 0) then
                    print*, "! iterateMC: can't allocate array memory:&
                         & opacityTemp "
                    stop
                 end if
                 linePDFTemp = 0.
              end if

              size =  (grid(iG)%nCells+1)*nbins


              if (lgGas) then
                 call mpi_allreduce(grid(iG)%recPDF, recPDFTemp, size, mpi_real&
                      &, mpi_sum, mpi_comm_world, ierr)

                 ! D-232: the source split travels with the PDF it describes.
                 ! Only the owning rank writes a cell in emissionDriver, so a
                 ! plain sum reassembles it, exactly as for recPDF above.
                 if (allocated(grid(iG)%pdfSrc)) &
                      & call mpi_allreduce(MPI_IN_PLACE, grid(iG)%pdfSrc, &
                      & (grid(iG)%nCells+1)*6, mpi_real, mpi_sum, mpi_comm_world, ierr)

                 if (lgDebug) then
                    size =  (grid(iG)%nCells+1)*nLines

                    call mpi_allreduce(grid(iG)%linePDF, linePDFTemp, size,&
                         & mpi_real, mpi_sum, mpi_comm_world, ierr)
                 end if
              end if

              if (lgDust) then   ! D-233

                 ! D-233: set `size` here rather than inherit it. It is
                 ! (nCells+1)*nbins above, but the lgGas branch just before
                 ! reassigns it to (nCells+1)*nLines for linePDF under lgDebug -
                 ! harmless while this block only ran without gas, wrong the
                 ! moment dust and gas coexist.
                 size = (grid(iG)%nCells+1)*nbins

                 call mpi_allreduce(grid(iG)%dustPDF, dustPDFTemp, size, mpi_real&
                      &, mpi_sum, mpi_comm_world, ierr)

                 do i = 0, grid(iG)%nCells
                    do freq = 1, nbins
                       grid(iG)%dustPDF(i,freq) = dustPDFTemp(i,freq)
!if (nIterateMC>1 .and. ig == 181 .and. i==9) then
!print*,i, grid(iG)%dustPDF(i,freq)
!end if
                    end do
                 end do

                 if (allocated(dustPDFTemp)) deallocate(dustPDFTemp)
              end if

              call mpi_barrier(mpi_comm_world, ierr)

              size = (grid(iG)%nCells+1)

              if (lgGas) then
                 call mpi_allreduce(grid(iG)%totalLines, totalLinesTemp, size,&
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)

                 do i = 1, grid(iG)%nx
                    do j = 1, yTop
                       do k = 1, grid(iG)%nz
                          if (grid(iG)%active(i,j,k)>0) then
                             grid(iG)%totalLines(grid(iG)%active(i,j,k)) = totalLinesTemp(grid(iG)%active(i,j,k))
                             do freq = 1, nbins
                                grid(iG)%recPDF(grid(iG)%active(i,j,k),freq) = recPDFTemp(grid(iG)%active(i,j,k) ,freq)
                             end do
                             if (lgDebug) then
                                do freq = 1, nLines
                                   grid(iG)%linePDF(grid(iG)%active(i,j,k),freq) = linePDFTemp(grid(iG)%active(i,j,k),freq)
                                end do
                             end if
                          end if
                       end do
                    end do
                 end do

                 call mpi_barrier(mpi_comm_world, ierr)

                 if ( allocated(totalLinesTemp) )&
                      & deallocate(totalLinesTemp)
                 if (lgDebug) then
                    if ( allocated(linePDFTemp) ) deallocate(linePDFTemp)
                 end if
                 if ( allocated(recPDFTemp) ) deallocate(recPDFTemp)
              end if

              ! check if min convergence was reached to carry out resonant line transfer
              if (lgDust .and. lgGas .and. convPercent>=resLinesTransfer .and. lgResLinesFirst &
                   &.and. (.not.nIterateMC==1)) then

                 if (iG==nGrids) lgResLinesFirst = .false.

                 size = (grid(iG)%nCells+1)*nResLines

                 call mpi_allreduce(grid(iG)%fEscapeResPhotons, fEscapeResPhotonsTemp, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)

                 grid(iG)%fEscapeResPhotons(0:grid(iG)%nCells, 1:nResLines) = fEscapeResPhotonsTemp

                 size = grid(iG)%nCells+1

                 if (allocated(fEscapeResPhotonsTemp)) deallocate(fEscapeResPhotonsTemp)
                 call mpi_allreduce(grid(iG)%resLinePackets, resLinePacketsTemp, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)

                 grid(iG)%resLinePackets(0:grid(iG)%nCells) = resLinePacketsTemp

                 if (allocated(resLinePacketsTemp)) deallocate(resLinePacketsTemp)

                 call mpi_barrier(mpi_comm_world, ierr)

              end if


           end do ! nGrids loop

!**********************************************************************************************

           do iG = 1, nGrids

              grid(iG)%Jste(0:grid(iG)%nCells, 1:nbins)    = 0.
              ! D-224: the transport trace restarts with the field
              if (pdrSplitField /= 0) then
                 trc224 = 0.d0
                 if (allocated(grid(iG)%trcJ)) grid(iG)%trcJ = 0.
              end if
              ! D-158: Jdif is only reset under lgDebug, so mirroring the
              ! diffuse packets into it without this let it accumulate across
              ! every iteration - it read 8.8e7 against Jste's 0.038. Reset it
              ! whenever it is being written.
              if (lgDebug .or. pdrSplitField /= 0) &
                   & grid(iG)%Jdif(0:grid(iG)%nCells, 1:nbins) = 0.
              if (lgDebug) then
                 grid(iG)%linePackets(0:grid(iG)%nCells, 1:nLines) = 0.
              end if
           end do


           totalEscaped = 0

           do iG = 1, nGrids
              grid(iG)%escapedPackets(0:grid(iG)%nCells, 0:nbins,0:nAngleBins) = 0.
           end do

           do iStar = 1, nStars
              if(taskid==0) print*, 'iterateMC: Starting transfer for ionising source ', iStar

              load = nPhotons(iStar)/numtasks
              rest = mod(nPhotons(iStar), numtasks)

              if (lgPlaneIonization) then
                 planeIonDistribution = 0
              end if


              ! send the photons through and evaluate the MC
              ! estimators of Jste and Jdif at every grid cell
              if (taskid < rest) then
                 load = load+1
                 call energyPacketDriver(iStar,load, grid(1:nGrids))
              else
                 call energyPacketDriver(iStar,load, grid(1:nGrids))
              end if

              call mpi_barrier(mpi_comm_world, ierr)
           end do

           if (Ldiffuse>0.) then

              if (emittingGrid>0) then
                 ngridloc = emittingGrid
              else
                 ngridloc = ngrids
              end if

              do gpLoc = 1, nGridloc

                 if (gploc>1 .or. (.not. lg2D)) then
                    yTop = grid(gploc)%ny
                 else if (gploc ==1 .and. lg2D) then
                    yTop = 1
                 end if


                 if(taskid==0) print*, 'iterateMC: Starting transfer for diffuse source grid: ', gpLoc
                 do ii = 1,grid(gpLoc)%nx
                    do jj = 1,yTop
                       do kk = 1,grid(gpLoc)%nz

                          if (grid(gpLoc)%active(ii,jj,kk)>0) then

                             cellLoc(1)  = ii
                             cellLoc(2)  = jj
                             cellLoc(3)  = kk

                             load = nPhotonsDiffuseLoc/numtasks
                             rest = mod(nPhotonsDiffuseLoc, numtasks)


                             ! send the photons through and evaluate the MC
                             ! estimators of Jste and Jdif at every grid cell
                             if (taskid < rest) then
                                load = load+1
                                call energyPacketDriver(iStar=0,n=load, grid=grid(1:nGrids), &
                                     & gpLoc=gpLoc, cellLoc=cellLoc)
                             else
                                call energyPacketDriver(iStar=0,n=load, grid=grid(1:nGrids), &
                                     & gpLoc=gpLoc, cellLoc=cellLoc)
                             end if

                             call mpi_barrier(mpi_comm_world, ierr)

                          end if

                       end do
                    end do
                 end do
              end do

           end if


           if (lgPlaneIonization) then

              allocate(planeIonDistributionTemp(grid(1)%nx, grid(1)%nz), stat = err)
              if (err /= 0) then
                 print*, "! iterateMC: can't allocate grid memory, planeIonDistributionTemp"
                 stop
              end if
              planeIonDistributionTemp = 0

              size = grid(1)%nx*grid(1)%nz

              call mpi_allreduce(planeIonDistribution, planeIonDistributionTemp, size, &
                   & mpi_integer, mpi_sum, mpi_comm_world, ierr)

              planeIonDistribution = planeIonDistributionTemp

              if (taskid ==0) then
                 open(file="output/planeIonDistribution.out",  action="write",unit=18, status="unknown")
                 do i = 1, grid(1)%nx
                    do k = 1, grid(1)%nz
                       write(18,*) i,k,planeIonDistribution(i,k)
                    end do
                 end do
                 close(18)
              end if

              if (allocated(planeIonDistributionTemp)) deallocate(planeIonDistributionTemp)

           end if

           do iG = 1, nGrids

              if (ig>1 .or. (.not. lg2D)) then
                 yTop = grid(iG)%ny
              else if (iG ==1 .and. lg2D) then
                 yTop = 1
              end if



!              allocate(escapedPacketsTemp(0:grid(iG)%nCells, 0:nbins, 0:nAngleBins), stat = err)
!              if (err /= 0) then
!                 print*, "! iterateMC: can't allocate grid memory: escapedPacketsTemp", iG
!                 stop
!              end if

!              escapedPacketsTemp  = 0.

              allocate(JSteTemp(0:grid(iG)%nCells, nbins), stat = err)
              if (err /= 0) then
                 print*, "! iterateMC: can't allocate array memory: JsteTemp ", iG
                 stop
              end if
              JSteTemp           = 0.

              if (lgDebug .or. pdrSplitField /= 0) then   ! D-158
                 allocate(JDifTemp(0:grid(iG)%nCells, nbins), stat = err)
                 if (err /= 0) then
                    print*, "! iterateMC: can't allocate array memory: JdifTemp "
                    stop
                 end if
                 if (lgDebug) allocate(linePacketsTemp(0:grid(iG)%nCells, nLines), stat = err)
                 if (err /= 0) then
                    print*, "! iterateMC: can't allocate array memory: linePacketsTemp "
                    stop
                 end if

                 JDifTemp           = 0.
                 if (lgDebug) linePacketsTemp    = 0.
              end if

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Original
!              size =  (grid(iG)%nCells+1)*(1+nbins)*(nAngleBins+1)
              
!              call mpi_allreduce(grid(iG)%escapedPackets, escapedPacketsTemp, size, &
!                   & mpi_real, mpi_sum, mpi_comm_world, ierr)
!              do i = 0, grid(iG)%nCells
!                 do freq = 0, nbins
!                    do imu = 0, nAngleBins
!                       grid(iG)%escapedPackets(i, freq,imu) = escapedPacketsTemp(i, freq, imu)
!
!                    end do
!                 end do
!              end do


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Using message spliting

              ! Dimensions of the array
              nCells = grid(iG)%nCells + 1  ! First dimension size
              chunk_size = MIN(grid(iG)%nx*grid(iG)%ny*grid(iG)%nz,1000000)  ! Maximum size for 32-bit count
              num_chunks = ceiling(real(nCells) / real(chunk_size))

              if (taskid==0) print*, '! iterateMC: chunk size = ',chunk_size
              do chunk = 1, num_chunks
                                
                  chunk_start = (chunk - 1) * chunk_size  ! Start from 0, not 1
                  chunk_end = min(chunk * chunk_size - 1, nCells - 1) ! End index, not count, and adjust for 0-indexing
                                                    ! nCells is total count, so last index is nCells - 1
                  chunk_elements = chunk_end - chunk_start + 1                   
                  
                  if (taskid==0) print*, '! iterateMC: Doing chunk ',chunk

                  ! Slice the 3D array along the first dimension for MPI_Allreduce

                  call mpi_allreduce(MPI_IN_PLACE, grid(iG)%escapedPackets(chunk_start:chunk_end, :, :), &
                       chunk_elements * (nbins + 1) * (nAngleBins + 1), &
                       & mpi_real, mpi_sum, mpi_comm_world, ierr)              

                  if (ierr /= 0) then
                      print *, "Error in MPI_Allreduce during chunk", chunk, "MPI Error Code:", ierr
                      stop
                  endif

              end do


              size =  (grid(iG)%nCells+1)*nbins

              if (lgDebug .or. pdrSplitField /= 0) then   ! D-158
                 call mpi_allreduce(grid(iG)%JDif, JDifTemp, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)
              end if

              call mpi_allreduce(grid(iG)%JSte, JSteTemp, size, &
                   & mpi_real, mpi_sum, mpi_comm_world, ierr)

#ifdef PDR
              ! D-224: the transport trace, summed over ranks. pdrSplitField
              ! and trcJ's allocation are the same on every rank, so no rank
              ! skips a collective the others run. PDR build only: trcJ is
              ! only allocated there, and the print borrows the census's
              ! loop counter, which is declared there.
              if (pdrSplitField /= 0) then
                 if (allocated(grid(iG)%trcJ)) &
                      & call mpi_allreduce(MPI_IN_PLACE, grid(iG)%trcJ, (grid(iG)%nCells+1)*6, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)
                 if (iG == 1) then
                    call mpi_allreduce(MPI_IN_PLACE, trc224, 20, &
                         & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
                    if (taskid == 0) then
                       print '(a,es10.3,a,f9.5,a,f9.5,a,es10.3,a,es10.3)', &
                            & " ! [D224T] steps", trc224(1), &
                            & "   start outside their cell (%)", 100.d0*trc224(2)/max(trc224(1), 1.d0), &
                            & "   longer than the chord (%)", 100.d0*trc224(3)/max(trc224(1), 1.d0), &
                            & "   excess/total path", trc224(5)/max(trc224(4), 1.d-99), &
                            & "   wall snaps", trc224(6)
                       print '(a,es10.3,a,f9.5,a,f9.5)', &
                            & " ! [D224T] 15.4-24.6 eV stellar steps", trc224(7), &
                            & "   start outside (%)", 100.d0*trc224(8)/max(trc224(7), 1.d0), &
                            & "   longer than the chord (%)", 100.d0*trc224(9)/max(trc224(7), 1.d0)
                       print '(a,es10.3,a,6f7.2,a,f7.2,a,f7.2,a,f7.2,a,f7.2)', &
                            & " ! [D224T] 15.4-24.6 eV stellar interactions in cells with tau/cell>20:", &
                            & trc224(10), &
                            & "   previous cell tau/cell none/<0.1/0.1-1/1-10/10-100/>=100 (%)", &
                            & (100.d0*trc224(10+kBd)/max(trc224(10), 1.d0), kBd = 1, 6), &
                            & "   previous step not in its cell (%)", 100.d0*trc224(17)/max(trc224(10), 1.d0), &
                            & "   this step not in its cell (%)", 100.d0*trc224(18)/max(trc224(10), 1.d0), &
                            & "   point outside cell (%)", 100.d0*trc224(19)/max(trc224(10), 1.d0), &
                            & "   previous cell PDR zone (%)", 100.d0*trc224(20)/max(trc224(10), 1.d0)
                    end if
                 end if
              end if
#endif

              size =  (grid(iG)%nCells+1)*nLines

              if (lgDebug) then
                 if (lgDebug) call mpi_allreduce(grid(iG)%linePackets, linePacketsTemp, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)
              end if


              do i = 1, grid(iG)%nx
                 do j = 1, yTop
                    do k = 1, grid(iG)%nz
                       if (grid(iG)%active(i,j,k)>0) then
                          do freq = 1, nbins
                             ! D-225: pdrSplitField reduces Jdif into JDifTemp
                             ! (D-158) but the copy back was only under lgDebug,
                             ! so every rank kept its own packets' deposits and
                             ! the census read ~1/14 of the diffuse field. That
                             ! made D-223's "diffuse fraction" ~0.07 whatever the
                             ! truth. Diagnostic only: nothing reads Jdif for
                             ! physics unless lgDebug (D-218).
                             if (lgDebug .or. pdrSplitField /= 0) then
                                grid(iG)%JDif(grid(iG)%active(i,j,k),freq) = &
                                     & JDifTemp(grid(iG)%active(i,j,k),freq)
                             end if
                             grid(iG)%JSte(grid(iG)%active(i,j,k),freq) = &
                                  & JSteTemp(grid(iG)%active(i,j,k),freq)
                             if (lg2D) grid(iG)%JSte(grid(iG)%active(i,j,k),freq) = &
                                  & grid(iG)%JSte(grid(iG)%active(i,j,k),freq)/&
                                  & TwoDscaleJ(grid(iG)%active(i,j,k))

                          end do
                          if (lgDebug) then
                             do freq = 1, nLines
                                if (lgDebug) then
                                grid(iG)%linePackets(grid(iG)%active(i,j,k),freq) &
                                     & = linePacketsTemp(grid(iG)%active(i,j,k),freq)
                                end if
                                if (lg2D) grid(iG)%JDif(grid(iG)%active(i,j,k),freq) = &
                                     & grid(iG)%JDif(grid(iG)%active(i,j,k),freq)/&
                                     & TwoDscaleJ(grid(iG)%active(i,j,k))

                             end do
                          end if
                       end if
                    end do
                 end do
              end do

              call mpi_barrier(mpi_comm_world, ierr)


              if (lgDebug) then
                 if ( allocated(linePacketsTemp) )    deallocate(linePacketsTemp)
              end if
              ! D-245: JDifTemp is allocated under (lgDebug .or. pdrSplitField /= 0)
              ! at line ~760 but was freed here only under lgDebug, so with
              ! pdrSplitField set and lgDebug off it was never freed. iterateMC is
              ! RECURSIVE - it advances nIterateMC and calls itself rather than
              ! looping - so a local allocatable still allocated at the recursive
              ! call stays live in that frame and in every frame beneath it.
              ! Measured cost: one (nCells+1, nbins) array = 34.8 MiB per rank per
              ! iteration, taking 720 MB/rank at iteration 1 to 1050 MB/rank by
              ! iteration 10 and making a 22-iteration run exhaust memory.
              ! The guard must match the allocation, so it is freed unconditionally.
              if ( allocated(JDifTemp) )           deallocate(JDifTemp)
              if ( allocated(JSteTemp) )           deallocate(JSteTemp)



              do i = 0, grid(iG)%nCells
                 grid(iG)%Jste(i,:) = grid(iG)%Jste(i,:) * 1.e-9

                 ! D-158: Jdif needs the same unit conversion and octant
                 ! division as Jste, or the diagnostic compares a scaled array
                 ! against an unscaled one - a factor ~1e10.
                 if (lgDebug .or. pdrSplitField /= 0) &
                      & grid(iG)%Jdif(i,:) = grid(iG)%Jdif(i,:) * 1.e-9
                 do ifreq = 1, nbins
                    totalEscaped = totalEscaped+&
                         & nint(grid(iG)%escapedPackets(i,ifreq, 0))
                    do ian = 0, nAngleBins
                       grid(iG)%escapedPackets(i,ifreq,ian) = grid(iG)%escapedPackets(i,ifreq,ian)
                    end do
                 end do

                 if (lgSymmetricXYZ) then
                    grid(iG)%Jste(i,:) = grid(iG)%Jste(i,:)/8.
                    grid(iG)%escapedPackets(i,:,:) = grid(iG)%escapedPackets(i,:,:)/8.
                    totalEscaped = nint(real(totalEscaped)/8.)
                    if (lgDebug .or. pdrSplitField /= 0) &
                         & grid(iG)%Jdif(i,:) = grid(iG)%Jdif(i,:)/8.
                 end if

              end do

           end do

#ifdef PDR
           ! ------------------------------------------------------- D-225
           ! Closure, checkpoint 1: straight after the transfer, reduction and
           ! scaling, does Jste summed over 15.4-24.6 eV equal the traced
           ! deposits of every packet in that band, cell by cell? trcJ(:,4)
           ! adds exactly what pathSegment adds to Jste, so it can only differ
           ! if something else writes Jste. Scaled as Jste is just above.
           ! Both arrays are reduced, so every rank holds the same values; no
           ! collective here.
           if (pdrSplitField /= 0 .and. allocated(grid(1)%trcJ) .and. bandP(2) > 0) then
              sclD = 1.d-9
              if (lgSymmetricXYZ) sclD = sclD/8.d0
              nC225 = 0; nMis225 = 0; sJ225 = 0.d0; sT225 = 0.d0
              do iC225 = 1, grid(1)%nCells
                 jbD  = dble(sum(grid(1)%Jste(iC225, bandP(2):bandP(3)-1)))
                 tj4D = dble(grid(1)%trcJ(iC225,4))*sclD
                 if (jbD <= 0.d0 .and. tj4D <= 0.d0) cycle
                 nC225 = nC225 + 1
                 sJ225 = sJ225 + jbD
                 sT225 = sT225 + tj4D
                 if (abs(jbD - tj4D) > 1.d-3*max(jbD, tj4D)) nMis225 = nMis225 + 1
              end do
              if (taskid == 0) print '(a,es12.5,a,es12.5,a,f9.6,a,i8,a,i8)', &
                   & " ! [D225T] after transfer, 15.4-24.6 eV: sum Jste", sJ225, &
                   & "   sum traced", sT225, "   traced/Jste", sT225/max(sJ225, 1.d-99), &
                   & "   cells with field", nC225, "   not closing to 1e-3", nMis225
           end if

           ! Placed AFTER the loop above, not before it. That loop applies the
           ! 1.e-9 unit conversion to Jste (and the lgSymmetricXYZ division by
           ! 8); reducing the field any earlier reads the raw estimator and
           ! overstates chi by exactly 1e9. Caught because writeFUVField, which
           ! runs later and was validated in Phase 0, disagreed by that factor.
           if (lgPDR .and. nIterateMC >= pdrStartIter) then
              if (pdrRfuv <= 0.) then
                 call calibratePDRdust(grid(1:nGrids))
              else
                 ! D-109: refresh every iteration. The dust opacity is rebuilt
                 ! above each pass (sublimation, and Tdust feedback through it),
                 ! so per-cell values measured once at pdrStartIter would go
                 ! stale - which is how a one-shot calibration froze a transient
                 ! into the A_V scale for a whole run.
                 call dustPerCell(grid(1:nGrids))
              end if
              call computeAVdust(grid(1:nGrids))
              ! --------------------------------------------------- D-209
              ! Place the H/H2 balance from MOCASSIN's photoionization
              ! solution, ONCE, at the first PDR iteration.
              !
              ! It has to sit here and not in seedPDR: seedPDR runs at
              ! startup, before MOCASSIN knows anything, so D-208 correctly
              ! leaves it writing zeros. By pdrStartIter there is a converged
              ! ionization structure, a Te, a Tdust and a dust opacity, and
              ! computeAVdust above has just turned the last of those into
              ! chi_FUV and A_V. Those are dust and radiation quantities and
              ! do not depend on the molecular abundances, so calling it
              ! before the seed costs nothing and gives the seed its field.
              !
              ! The whole pair is then run AGAIN, because both of them
              ! integrate shielding columns and those DO depend on the
              ! abundances - they have to see the seeded grid, not the zeroed
              ! one (D-208: both column routines run before the coupling loop
              ! opens, which is why the old hardcoded x(H2)=0.300 was reaching
              ! the first chemistry call at all). One extra pass, once per run.
              !
              ! The seed must sit AFTER mocassinToPDR, not between the two:
              ! chiFUV is written by mocassinToPDR, so calling seedMolecules
              ! before it hands the seed a zero FUV field. The closed form
              ! then returns N/2 - every cell fully molecular, the H II region
              ! included - and it is not obviously wrong on the face of it,
              ! because a zero field IS the fully-shielded limit. Measured on
              ! the first attempt: mean f_mol 1.0000 in 100.00% of cells.
              call mocassinToPDR(grid(1:nGrids))
              if (lgPDR .and. nIterateMC == pdrStartIter) then
                 call seedMolecules(grid(1:nGrids))
                 call computeAVdust(grid(1:nGrids))
                 call mocassinToPDR(grid(1:nGrids))
                 ! D-220: the seed moved the molecular content, so republish
                 ! elemAvail before updateCell normalises the ion stages to it.
                 ! Without this the first PDR iteration ran with the stages
                 ! summing to 1 beside a seed that had made half the hydrogen
                 ! molecular - a hydrogen budget of 1.85 (D-219).
                 call pdrToMocassin(grid(1:nGrids))
              end if
           end if
#endif

           if (lgDust .and. (nIterateMC>1 .or. .not.lgEquivalentTau)) then
              print*, "! iterateMC: [Interactions] : total -- abs -- sca: "
              print*, "! iterateMC: [Interactions] ", absInt+scaInt, " -- ", &
                   &  absInt*100./(absInt+scaInt),"% -- ", &
                   &  scaInt*100./(scaInt+absInt),"%"
           end if

           if (taskid==0 .and. lgIonMatrix) then
              print*, "! [D114] matrix vs chain, worst relative difference:", &
                   & real(ionMatMaxDiff), " elem", ionMatWorstEl, " ion", ionMatWorstIon
              print*, "! [D114]   chain =", real(ionMatWorstA), " matrix =", real(ionMatWorstB), &
                   & "  (stages above 1e-15 only)"
              print*, "! [D114]   chain returned a NEGATIVE fraction in", ionMatNegChain, &
                   & "stage-cells; the matrix clamps those to zero"
              ionMatMaxDiff = 0.; ionMatNegChain = 0
           end if

           if (taskid==0 .and. nInsaneEta > 0) then
              print*, "! [warning] getGrainRecombination hit a NaN eta", nInsaneEta, &
                   & "times this iteration - the ionization solution has NaNs in it"
              nInsaneEta = 0
           end if

           if (taskid==0) print*, " total Escaped Packets :",  totalEscaped

           if (taskid==0) call writeSED(grid)
           if (taskid==0 .and. contCube(1)>0. .and. contCube(2)>0. ) &
                & call writeContCube(grid, contCube(1),contCube(2))

!*******************************************************************

           do iG = 1, nGrids

              if (ig>1 .or. (.not.lg2D)) then
                 yTop = grid(iG)%ny
              else if (iG ==1 .and. lg2D) then
                 yTop = 1
              end if


              allocate(lgConvergedTemp(0:grid(iG)%nCells), stat &
                   &= err)
              if (err /= 0) then
                 print*, "! iterateMC: can't allocate array&
                      & memory:lgConvergedTemp"
                 stop
              end if

              allocate(lgBlackTemp(0:grid(iG)%nCells), stat &
                   &= err)
              if (err /= 0) then
                 print*, "! iterateMC: can't allocate array&
                      & memory:lgBlackTemp  "
                 stop
              end if

              if (lgGas) then

                 allocate(NeTemp(0:grid(iG)%nCells), stat = err)
                 if (err /= 0) then
                    print*, "! iterateMC: can't allocate array memory:&
                         & NeTemp ", iG
                    stop
                 end if
                 NeTemp           = 0.
                 allocate(TeTemp(0:grid(iG)%nCells), stat = err)
                 if (err /= 0) then
                    print*, "! iterateMC: can't allocate array memory:&
                         & TeTemp ", iG
                    stop
                 end if
                 TeTemp           = 0.
                 allocate(ionDenTemp(0:grid(iG)%nCells, &
                      & nElementsUsed, nStages), stat = err)
                 if (err /= 0) then
                    print*, "! iterateMC: can't allocate array memory: &
                         &ionDenTemp ", iG
                    stop
                 end if
                 ionDenTemp       = 0.

              end if

              if (lgDust) then
                 allocate(TdustTemp(0:nSpeciesMax,0:nSizes,0:grid(iG)%nCells), stat = err)
                 if (err /= 0) then
                    print*, "! iterateMC: can't allocate array memory:&
                         &TdustTemp ", iG
                    stop
                 end if
                 TdustTemp = 0.
              end if


              grid(iG)%lgConverged(0:grid(iG)%nCells) = 0
              ! D-155: the state this MC iteration starts from. The convergence
              ! test must compare against THIS, not against the previous
              ! coupling pass - see the note on xHIiterStart in common_mod.
              if (allocated(grid(iG)%xHIiterStart)) &
                   & grid(iG)%xHIiterStart(0:grid(iG)%nCells) = &
                   & grid(iG)%ionDen(0:grid(iG)%nCells, elementXref(1), 1)
              ! D-173: same snapshot for the temperature.
              if (allocated(grid(iG)%TeIterStart)) &
                   & grid(iG)%TeIterStart(0:grid(iG)%nCells) = &
                   & grid(iG)%Te(0:grid(iG)%nCells)
#ifdef PDR
              ! D-200: and for the two state vectors the bistability actually
              ! lives in - the molecular abundances and the ion fractions.
              ! D-174 damped Te across the MC iteration and said so explicitly:
              ! "Te only, for now: it is the bistable variable". Measured at
              ! D-198, it is not the only one. A cell on the hot branch is
              ! atomic AND ionized AND hot; the three move together, and
              ! damping one of them while the other two are free lets the pair
              ! that is free carry the flip.
              if (lgPDR .and. nIterateMC >= pdrStartIter .and. iterDamp > 0.) then
                 if (allocated(grid(iG)%pdrAbun)) then
                    if (.not.allocated(pdrAbunIter)) &
                         & allocate(pdrAbunIter(0:grid(iG)%nCells, 1:pdrNspec), stat=err)
                    if (err == 0) pdrAbunIter = grid(iG)%pdrAbun(0:grid(iG)%nCells, 1:pdrNspec)
                 end if
                 if (.not.allocated(ionDenIter)) &
                      & allocate(ionDenIter(0:grid(iG)%nCells, 1:nElementsUsed, 1:nstages), stat=err)
                 if (err == 0) ionDenIter = grid(iG)%ionDen(0:grid(iG)%nCells, :, :)
              end if
#endif
#ifdef PDR
              ! D-179: and x(H2), the quantity that is actually moving when the
              ! PDR first engages.
              if (allocated(grid(iG)%xH2iterStart) .and. allocated(grid(iG)%H2den)) then
                 do iDum = 0, grid(iG)%nCells
                    if (grid(iG)%Hden(iDum) > 0.) then
                       grid(iG)%xH2iterStart(iDum) = &
                            & grid(iG)%H2den(iDum)/grid(iG)%Hden(iDum)
                    else
                       grid(iG)%xH2iterStart(iDum) = 0.
                    end if
                 end do
              end if
#endif
              grid(iG)%lgBlack(0:grid(iG)%nCells)     = 0
              grid(iG)%noHit       = 0.
              grid(iG)%noIonBal    = 0.
              grid(iG)%noTeBal     = 0.
              noHitPercent(iG)     = 0.
              noIonBalPercent(iG)  = 0.
              noTeBalPercent(iG)   = 0.
              lgConvergedTemp      = 0
              lgBlackTemp          = 0

               if (lgTraceHeating.and.taskid==0) then
                 open(file="output/thermalBalance.out",  action="write",unit=57, status="unknown", iostat=ios)
                 if (ios /= 0) then
                    print*, "! iterationMC: can't open file for writing, output/thermalBalance.out"
                    stop
                 end if
              end if


              ! ---------------------------------------------------- D-216
              ! MOCASSIN solves the thermal equilibrium and the ionization
              ! ONCE per MC iteration; the chemistry then converges the
              ! molecular content against that temperature.
              !
              ! This is the contract as stated: MOCASSIN hands 3D-PDR the ion
              ! densities, Ne, Te, the dust temperature and the dust opacity;
              ! 3D-PDR returns the molecular content and the heating and
              ! cooling that follow from it. A pass is one exchange. Nothing
              ! in that says MOCASSIN should re-solve its half five times
              ! while the radiation field stands still.
              !
              ! D-119 put updateCell INSIDE this loop to close the
              ! ionization/chemistry handshake within an MC iteration, and
              ! that reasoning was sound. What it did not anticipate is that
              ! updateCell calls iterateT, a full bracketed temperature search
              ! - so the loop was re-solving the thermal equilibrium once per
              ! pass at frozen radiation field, with nothing damping Te across
              ! passes (iterDamp acts across MC iterations, pdrCoupleDamp acts
              ! on ionDen). D-213/D-214 measured the consequence: each pass
              ! re-anchored pdrCoolTref, flattened the measured slope, removed
              ! part of the extrapolation holding the cell cold and let the
              ! temperature step up - 530 -> 4129 -> 8054 -> 8245 -> 8283 K
              ! inside one iteration.
              !
              ! The Te lag this reintroduces - the chemistry answering at a
              ! temperature computed from the previous iteration's molecules -
              ! now lives in the MC iteration loop, which is the right place
              ! for it because that loop contains the radiation field: the leg
              ! that pushes back when the gas ionizes and the opacity changes.
              ! A lag closed by an unstable inner loop is worse than a lag.
              !
              ! pdrCoupleIter is now the number of CHEMISTRY passes. It is a
              ! numerical convergence parameter, not an ownership switch: it
              ! cannot move a quantity from one code to the other, only decide
              ! how far the chemistry is iterated against a fixed MOCASSIN
              ! state. The count stays FIXED rather than convergence-tested
              ! because every rank must execute the same number of passes or
              ! the MPI collectives inside deadlock.
              if(taskid==0) print*, 'iterateMC: updateCell in', iG
              iCell = 0
              do i = 1, grid(iG)%nx
                 do j = 1, yTop
                    do k = 1, grid(iG)%nz
                       iCell = iCell+1
                       if (mod(iCell-(taskid+1),numtasks)==0) &
                            & call updateCell(grid(iG),i,j,k)

                    end do
                 end do
              end do
              if(taskid==0) print*, 'iterateMC: updateCell out', iG

              do iCouple = 1, max(pdrCoupleIter, 1)
#ifdef PDR
              ! ---------------------------------------------------- D-204
              ! Te at this point has been solved by updateCell against the
              ! abundances the iteration STARTED with: pdrStep has not run yet
              ! in this iteration. So this snapshot answers the ordering
              ! question the per-iteration medians cannot. If the temperature
              ! has already flipped here, at unchanged f_mol, the thermal
              ! balance leads and the chemistry is following it; if it has not,
              ! the collapse in f_mol comes first and the heating follows the
              ! coolants it destroyed.
              !
              ! D-203 reasoned from the pass order that Te probably leads. That
              ! is inference from code order, and inference of exactly this
              ! kind has been wrong three times here (D-135, D-137, D-191), so
              ! it gets measured.
              !
              ! grid%Te is NOT reduced inside the coupling loop - each rank
              ! holds its own cells' new values and stale ones elsewhere - so
              ! the counts are formed per rank over owned cells and reduced.
              ! Every rank runs all three collectives unconditionally: a
              ! collective a subset of ranks skips is a deadlock.
              if (lgPDR .and. nIterateMC >= pdrStartIter) then
                 nUpd1 = 0; nUpd1Hot = 0; teUpd1Sum = 0.d0
                 molUpdSum = 0.d0; pcSum = 0.d0; phSum = 0.d0; ppeSum = 0.d0
                 pcSubSum = 0.d0; pcNulSum = 0.d0
                 tfacSum = 0.d0; trefSum = 0.d0; slopSum = 0.d0; spSum = 0.d0
                 budSum = 0.d0
                 budSum2 = 0.d0
                 budSum3 = 0.d0
                 budSum4 = 0.d0
                 budSum5 = 0.d0
                 budSum6 = 0.d0
                 budSum7 = 0.d0
                 budSum8 = 0.d0
                 budSum9 = 0.d0
                 iCell = 0
                 do i = 1, grid(iG)%nx
                    do j = 1, yTop
                       do k = 1, grid(iG)%nz
                          iCell = iCell + 1
                          if (mod(iCell-(taskid+1),numtasks) /= 0) cycle
                          if (grid(iG)%active(i,j,k) <= 0) cycle
                          iDum = grid(iG)%active(i,j,k)
                          if (.not. allocated(grid(iG)%pdrZone)) cycle
                          if (grid(iG)%pdrZone(iDum) /= 1) cycle
                          if (grid(iG)%Hden(iDum) <= 0.) cycle
                          nUpd1 = nUpd1 + 1
                          teUpd1Sum = teUpd1Sum + dble(grid(iG)%Te(iDum))
                          if (grid(iG)%Te(iDum) > 3000.) nUpd1Hot = nUpd1Hot + 1
                          ! f_mol as the thermal balance just saw it, and the
                          ! PDR terms it was handed. All four per H nucleus so
                          ! the heating and cooling are directly comparable.
                          if (allocated(grid(iG)%H2den)) molUpdSum = molUpdSum &
                               & + 2.d0*dble(grid(iG)%H2den(iDum)) &
                               &   /dble(grid(iG)%Hden(iDum))
                          ! D-207. These are what the substitution actually
                          ! did to MOCASSIN's budget, not 3D-PDR's own totals.
                          ! The first version of this line reported pdrCool,
                          ! pdrHeat and pdrHeatPE, and pdrHeatPE does not enter
                          ! the balance at all unless pdrPEfromPDR is set - it
                          ! is 0 by default and no fixture sets it - so the
                          ! heating column was ~1.9e-25 per H where the true
                          ! contribution is ~1.4e-26. An instrument reporting a
                          ! quantity adjacent to the one that matters is the
                          ! fourth of these in this audit, and the first I
                          ! built myself (D-196, D-202, D-205, here).
                          if (allocated(grid(iG)%pdrCoolUsed)) pcSum = pcSum &
                               & + dble(grid(iG)%pdrCoolUsed(iDum))
                          if (allocated(grid(iG)%pdrHeatUsed)) phSum = phSum &
                               & + dble(grid(iG)%pdrHeatUsed(iDum))
                          if (allocated(grid(iG)%pdrCoolSub)) pcSubSum = pcSubSum &
                               & + dble(grid(iG)%pdrCoolSub(iDum))
                          if (allocated(grid(iG)%pdrCoolNul)) pcNulSum = pcNulSum &
                               & + dble(grid(iG)%pdrCoolNul(iDum))
                          ! D-213: the two factors whose product is `added`
                          if (allocated(grid(iG)%pdrTfacUsed)) tfacSum = tfacSum &
                               & + dble(grid(iG)%pdrTfacUsed(iDum))
                          if (allocated(grid(iG)%pdrCoolTref)) trefSum = trefSum &
                               & + dble(grid(iG)%pdrCoolTref(iDum))
                          if (allocated(grid(iG)%pdrCoolSlope)) slopSum = slopSum &
                               & + dble(grid(iG)%pdrCoolSlope(iDum))
                          if (allocated(grid(iG)%pdrCoolSp)) then
                             do iCoolD = 1, min(4, pdrNcool)
                                spSum(iCoolD) = spSum(iCoolD) &
                                     & + dble(grid(iG)%pdrCoolSp(iDum,iCoolD)) &
                                     &   /dble(grid(iG)%Hden(iDum))
                             end do
                          end if
                          ! ------------------------------------------ D-217
                          ! MOCASSIN's own budget, grouped by what the thermal
                          ! solve did to the cell: cold at the start of the
                          ! iteration and hot after it, cold throughout, or
                          ! hot from the start. Grouping by OUTCOME is what
                          ! keeps each mean describing one population - the
                          ! D-209 input line averaged a hot and a cold
                          ! population together and described neither. 3000 K
                          ! is the census's existing hot threshold and bins
                          ! the report only; it decides nothing.
                          ! updateCell runs once per MC iteration (D-216), so
                          ! the budget is the same on every chemistry pass and
                          ! is taken on pass 1.
                          if (iCouple == 1 .and. allocated(grid(iG)%mocBud) &
                               & .and. allocated(grid(iG)%TeIterStart)) then
                             if (grid(iG)%TeIterStart(iDum) > 3000.) then
                                iBudG = 3
                             else if (grid(iG)%Te(iDum) > 3000.) then
                                iBudG = 1
                             else
                                iBudG = 2
                             end if
                             do iBudT = 1, 10
                                budSum(iBudG, iBudT) = budSum(iBudG, iBudT) &
                                     & + dble(grid(iG)%mocBud(iDum, 1, iBudT))
                                budSum(iBudG, 10+iBudT) = budSum(iBudG, 10+iBudT) &
                                     & + dble(grid(iG)%mocBud(iDum, 2, iBudT))
                             end do
                             budSum(iBudG, 21) = budSum(iBudG, 21) + 1.d0
                             ! ---------------------------------------- D-218
                             ! What sets the photoionization heating D-217
                             ! found: heating per H ~ x(H0) * J, and J at
                             ! depth is what the opacity in front lets through.
                             ! So per group: depth (A_V), the absorbers
                             ! (x(H0), f_mol), the field above hydrogen's
                             ! threshold, and tau per cell AT that threshold -
                             ! HlevNuP(1) is the bin the H0 cross section
                             ! itself starts from (ph_mod). The opacity is
                             ! rebuilt at the top of the MC iteration and not
                             ! rewritten by updateCell, and Jste is reduced
                             ! after the transfer, so both are global here.
                             budSum2(iBudG,1) = budSum2(iBudG,1) &
                                  & + dble(grid(iG)%AVeff(iDum))
                             budSum2(iBudG,2) = budSum2(iBudG,2) &
                                  & + dble(grid(iG)%ionDen(iDum,elementXref(1),1))
                             if (allocated(grid(iG)%H2den)) &
                                  & budSum2(iBudG,3) = budSum2(iBudG,3) &
                                  & + 2.d0*dble(grid(iG)%H2den(iDum)) &
                                  &   /dble(grid(iG)%Hden(iDum))
                             budSum2(iBudG,4) = budSum2(iBudG,4) &
                                  & + dble(sum(grid(iG)%Jste(iDum,HlevNuP(1):nbins)))
                             if (i < grid(iG)%nx) then
                                dxCell = dble(grid(iG)%xAxis(i+1) - grid(iG)%xAxis(i))
                             else
                                dxCell = dble(grid(iG)%xAxis(i) - grid(iG)%xAxis(i-1))
                             end if
                             budSum2(iBudG,5) = budSum2(iBudG,5) &
                                  & + dble(grid(iG)%opacity(iDum,HlevNuP(1)))*dxCell
                             ! D-221: the field and H0's heating on each side
                             ! of 15.43 eV, where H2's continuum begins
                             if (iH2thrC == 0) then
                                iH2thrC = nbins + 1
                                do iNuD = 1, nbins
                                   if (nuArray(iNuD) >= 1.1345) then
                                      iH2thrC = iNuD
                                      exit
                                   end if
                                end do
                             end if
                             if (iH2thrC > HlevNuP(1)) budSum3(iBudG,1) = budSum3(iBudG,1) &
                                  & + dble(sum(grid(iG)%Jste(iDum,HlevNuP(1):iH2thrC-1)))
                             if (iH2thrC <= nbins) budSum3(iBudG,2) = budSum3(iBudG,2) &
                                  & + dble(sum(grid(iG)%Jste(iDum,iH2thrC:nbins)))
                             if (allocated(grid(iG)%mocBand)) then
                                budSum3(iBudG,3) = budSum3(iBudG,3) &
                                     & + dble(grid(iG)%mocBand(iDum,1))
                                budSum3(iBudG,4) = budSum3(iBudG,4) &
                                     & + dble(grid(iG)%mocBand(iDum,2))
                             end if
                             ! ---------------------------------------- D-222
                             ! per band: the field and H0's entry heating; per
                             ! representative bin of bands 2-5: tau per cell of
                             ! each gas absorber, of dust, and of the total
                             ! opacity the transport used, so the split can be
                             ! checked against the total it should sum to
                             call setHardBands()
                             if (bandRepP(5) > 0) then
                                do kBd = 1, 5
                                   budSum4(iBudG,kBd) = budSum4(iBudG,kBd) &
                                        & + dble(sum(grid(iG)%Jste(iDum,bandP(kBd):bandP(kBd+1)-1)))
                                   if (allocated(grid(iG)%mocBand)) &
                                        & budSum4(iBudG,5+kBd) = budSum4(iBudG,5+kBd) &
                                        & + dble(grid(iG)%mocBand(iDum,2+kBd))
                                end do
                                do mBd = 2, 5
                                   if (allocated(grid(iG)%opaRep)) then
                                      do kBd = 1, 6
                                         budSum4(iBudG,10+(mBd-2)*8+kBd) = &
                                              & budSum4(iBudG,10+(mBd-2)*8+kBd) &
                                              & + dble(grid(iG)%opaRep(iDum,mBd-1,kBd))*dxCell
                                      end do
                                   end if
                                   if (lgDust) budSum4(iBudG,10+(mBd-2)*8+7) = &
                                        & budSum4(iBudG,10+(mBd-2)*8+7) &
                                        & + dble(grid(iG)%absOpac(iDum,bandRepP(mBd)) &
                                        &      + grid(iG)%scaOpac(iDum,bandRepP(mBd)))*dxCell
                                   budSum4(iBudG,10+(mBd-2)*8+8) = &
                                        & budSum4(iBudG,10+(mBd-2)*8+8) &
                                        & + dble(grid(iG)%opacity(iDum,bandRepP(mBd)))*dxCell
                                end do
                             end if
                             ! ---------------------------------------- D-223
                             ! Is each flipping cell next to a cell that was
                             ! already hot? D-222 found no energy present in the
                             ! field lets photons cross these cells (tau >= ~89
                             ! per cell), so the field inside them must enter a
                             ! skin from a neighbour or be emitted locally. A
                             ! front advancing a cell per iteration predicts the
                             ! flippers border hot cells, upstream in A_V;
                             ! scattered heating predicts they do not. The
                             ! stayed-cold group is the control.
                             ! "Hot" is the NEIGHBOUR's iteration-start Te, which
                             ! every rank holds for every cell (copied from the
                             ! reduced grid) - budGrpLast is only valid on the
                             ! rank that owns a cell, so it cannot be read for a
                             ! neighbour. Upstream is decided by A_V, which needs
                             ! no assumption about where the star sits.
                             if (allocated(grid(iG)%TeIterStart)) then
                                nHotD = 0; nUpD = 0; nDnD = 0
                                tMinD = huge(1.d0); tUpMinD = huge(1.d0); nbMinD = 0   ! D-224
                                do iOffD = 1, 6
                                   niD = i; njD = j; nkD = k
                                   select case (iOffD)
                                   case (1); niD = i - 1
                                   case (2); niD = i + 1
                                   case (3); njD = j - 1
                                   case (4); njD = j + 1
                                   case (5); nkD = k - 1
                                   case (6); nkD = k + 1
                                   end select
                                   if (niD < 1 .or. niD > grid(iG)%nx) cycle
                                   if (njD < 1 .or. njD > yTop)        cycle
                                   if (nkD < 1 .or. nkD > grid(iG)%nz) cycle
                                   nbD = grid(iG)%active(niD,njD,nkD)
                                   if (nbD <= 0) cycle
                                   budSum5(iBudG,5) = budSum5(iBudG,5) + 1.d0
                                   ! D-224: what the photons care about - the
                                   ! neighbour's tau per cell at band 2's
                                   ! representative bin, from the opacity the
                                   ! transport used (reduced, so every rank
                                   ! holds it for every cell)
                                   if (bandRepP(2) > 0) then
                                      tNbD = dble(grid(iG)%opacity(nbD,bandRepP(2)))*dxCell
                                      if (tNbD < tMinD) then
                                         tMinD = tNbD
                                         nbMinD = nbD
                                      end if
                                      if (grid(iG)%AVeff(nbD) < grid(iG)%AVeff(iDum)) &
                                           & tUpMinD = min(tUpMinD, tNbD)
                                   end if
                                   if (grid(iG)%TeIterStart(nbD) > 3000.) then
                                      nHotD = nHotD + 1
                                      if (grid(iG)%AVeff(nbD) < grid(iG)%AVeff(iDum)) then
                                         nUpD = nUpD + 1
                                      else
                                         nDnD = nDnD + 1
                                      end if
                                   end if
                                end do
                                if (nHotD > 0) budSum5(iBudG,1) = budSum5(iBudG,1) + 1.d0
                                budSum5(iBudG,2) = budSum5(iBudG,2) + dble(nHotD)
                                if (nUpD > 0)  budSum5(iBudG,3) = budSum5(iBudG,3) + 1.d0
                                if (nDnD > 0)  budSum5(iBudG,4) = budSum5(iBudG,4) + 1.d0
                                ! D-224: the most transparent face-neighbour,
                                ! and where this cell's band-2 stellar field
                                ! came from (trcJ, summed after the transfer)
                                if (nbMinD > 0) then
                                   if (tMinD < 0.1d0) then
                                      iHD = 1
                                   else if (tMinD < 1.d0) then
                                      iHD = 2
                                   else if (tMinD < 10.d0) then
                                      iHD = 3
                                   else if (tMinD < 100.d0) then
                                      iHD = 4
                                   else
                                      iHD = 5
                                   end if
                                   budSum6(iBudG,iHD) = budSum6(iBudG,iHD) + 1.d0
                                   budSum6(iBudG,6) = budSum6(iBudG,6) + log10(max(tMinD, 1.d-10))
                                   if (allocated(grid(iG)%pdrZone)) then
                                      if (grid(iG)%pdrZone(nbMinD) == 1) &
                                           & budSum6(iBudG,7) = budSum6(iBudG,7) + 1.d0
                                   end if
                                   budSum6(iBudG,8) = budSum6(iBudG,8) + dble(grid(iG)%TeIterStart(nbMinD))
                                   if (allocated(grid(iG)%xHIiterStart)) budSum6(iBudG,9) = &
                                        & budSum6(iBudG,9) + dble(grid(iG)%xHIiterStart(nbMinD))
                                   if (grid(iG)%AVeff(nbMinD) < grid(iG)%AVeff(iDum)) &
                                        & budSum6(iBudG,10) = budSum6(iBudG,10) + 1.d0
                                   budSum6(iBudG,15) = budSum6(iBudG,15) + 1.d0
                                end if
                                if (tUpMinD < 1.d0) budSum6(iBudG,14) = budSum6(iBudG,14) + 1.d0
                                if (allocated(grid(iG)%trcJ)) then
                                   do kBd = 1, 3
                                      budSum6(iBudG,10+kBd) = budSum6(iBudG,10+kBd) &
                                           & + dble(grid(iG)%trcJ(iDum,kBd))
                                   end do
                                end if
                                ! D-225: closure, checkpoint 2 - at the census,
                                ! per group, in absolute terms. Jste and trcJ
                                ! are both reduced, so any cell can be read here.
                                if (allocated(grid(iG)%trcJ) .and. bandP(2) > 0 &
                                     & .and. pdrSplitField /= 0) then
                                   sclD = 1.d-9
                                   if (lgSymmetricXYZ) sclD = sclD/8.d0
                                   jbD  = dble(sum(grid(iG)%Jste(iDum, bandP(2):bandP(3)-1)))
                                   jdD  = dble(sum(grid(iG)%Jdif(iDum, bandP(2):bandP(3)-1)))
                                   tj1D = dble(grid(iG)%trcJ(iDum,1))*sclD
                                   tj4D = dble(grid(iG)%trcJ(iDum,4))*sclD
                                   budSum7(iBudG,1) = budSum7(iBudG,1) + jbD
                                   budSum7(iBudG,2) = budSum7(iBudG,2) + jdD
                                   budSum7(iBudG,3) = budSum7(iBudG,3) + tj1D
                                   budSum7(iBudG,4) = budSum7(iBudG,4) + tj4D
                                   budSum7(iBudG,5) = budSum7(iBudG,5) + dble(grid(iG)%trcJ(iDum,5))
                                   budSum7(iBudG,6) = budSum7(iBudG,6) + dble(grid(iG)%trcJ(iDum,6))
                                   if (abs(jbD - tj4D) > 1.d-3*max(jbD, tj4D)) &
                                        & budSum7(iBudG,7) = budSum7(iBudG,7) + 1.d0
                                end if
                                ! D-226: what this cell's re-emission spectrum
                                ! puts into the band - the probability that a
                                ! diffuse packet born here is a 15.4-24.6 eV
                                ! continuum photon, bin by bin (recPDF is the
                                ! cumulative continuum PDF, totalLines the line
                                ! share; both reduced after emissionDriver) -
                                ! with the field in the same bins beside it
                                if (bandP(2) > 1 .and. bandP(3) > bandP(2)) then
                                   nB226 = min(bandP(3) - bandP(2), 64)
                                   pLinD = dble(grid(iG)%totalLines(iDum))
                                   do kB226 = 0, nB226 - 1
                                      dP226 = (1.d0 - pLinD) &
                                           & *dble(grid(iG)%recPDF(iDum, bandP(2)+kB226) &
                                           &     - grid(iG)%recPDF(iDum, bandP(2)+kB226-1))
                                      budSum8(iBudG,6+kB226) = budSum8(iBudG,6+kB226) + dP226
                                      budSum8(iBudG,1) = budSum8(iBudG,1) + dP226
                                      budSum9(iBudG,1+kB226) = budSum9(iBudG,1+kB226) &
                                           & + dble(grid(iG)%Jste(iDum, bandP(2)+kB226))
                                   end do
                                   if (grid(iG)%TeIterStart(iDum) < 100.) &
                                        & budSum8(iBudG,2) = budSum8(iBudG,2) + 1.d0
                                   budSum8(iBudG,3) = budSum8(iBudG,3) &
                                        & + dble(grid(iG)%ionDen(iDum,elementXref(2),2))
                                   budSum8(iBudG,4) = budSum8(iBudG,4) &
                                        & + dble(grid(iG)%ionDen(iDum,elementXref(1),2))
                                   budSum8(iBudG,5) = budSum8(iBudG,5) + pLinD
                                end if
                                ! D-232: what the cell's re-emission spectrum is
                                ! made of, before normalisation - gas terms and
                                ! dust term, whole band and above 13.6/24.6 eV.
                                ! A dust absorption samples the pooled PDF, so a
                                ! nonzero gas ionizing part is dust-absorbed
                                ! energy able to come back out ionizing.
                                if (allocated(grid(iG)%pdfSrc)) then
                                   do kBd = 1, 6
                                      budSum8(iBudG,15+kBd) = budSum8(iBudG,15+kBd) &
                                           & + dble(grid(iG)%pdfSrc(iDum,kBd))
                                   end do
                                end if
                             end if
                             ! the diffuse part of the field in the three bands
                             ! that carry any: Jdif holds the diffuse packets
                             ! alone when pdrSplitField is set, Jste both
                             if (pdrSplitField /= 0 .and. bandRepP(5) > 0) then
                                do kBd = 1, 3
                                   budSum5(iBudG,5+kBd) = budSum5(iBudG,5+kBd) &
                                        & + dble(sum(grid(iG)%Jdif(iDum,bandP(kBd):bandP(kBd+1)-1)))
                                end do
                             end if
                             ! the same cell's group one MC iteration ago;
                             ! ownership is fixed per rank, so each rank
                             ! carries its own cells' history without a
                             ! reduction
                             iLastG = 0
                             if (allocated(grid(iG)%budGrpLast)) then
                                iLastG = grid(iG)%budGrpLast(iDum)
                                grid(iG)%budGrpLast(iDum) = iBudG
                             end if
                             budSum2(iBudG,6+iLastG) = budSum2(iBudG,6+iLastG) + 1.d0
                          end if
                          if (allocated(grid(iG)%pdrHeatXtra)) ppeSum = ppeSum &
                               & + dble(grid(iG)%pdrHeatXtra(iDum)) &
                               &   /dble(grid(iG)%Hden(iDum))
                       end do
                    end do
                 end do
                 call mpi_allreduce(MPI_IN_PLACE, nUpd1, 1, mpi_integer, &
                      & mpi_sum, mpi_comm_world, ierr)
                 call mpi_allreduce(MPI_IN_PLACE, nUpd1Hot, 1, mpi_integer, &
                      & mpi_sum, mpi_comm_world, ierr)
                 call mpi_allreduce(MPI_IN_PLACE, teUpd1Sum, 1, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
                 call mpi_allreduce(MPI_IN_PLACE, molUpdSum, 1, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
                 call mpi_allreduce(MPI_IN_PLACE, pcSum, 1, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
                 call mpi_allreduce(MPI_IN_PLACE, phSum, 1, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
                 call mpi_allreduce(MPI_IN_PLACE, ppeSum, 1, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
                 call mpi_allreduce(MPI_IN_PLACE, pcSubSum, 1, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
                 call mpi_allreduce(MPI_IN_PLACE, pcNulSum, 1, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
                 call mpi_allreduce(MPI_IN_PLACE, tfacSum, 1, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
                 call mpi_allreduce(MPI_IN_PLACE, trefSum, 1, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
                 call mpi_allreduce(MPI_IN_PLACE, slopSum, 1, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
                 call mpi_allreduce(MPI_IN_PLACE, spSum, 4, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
                 ! D-217: iCouple is the same on every rank, so this
                 ! collective cannot be skipped by a subset of them.
                 if (iCouple == 1) call mpi_allreduce(MPI_IN_PLACE, budSum, 63, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
                 if (iCouple == 1) call mpi_allreduce(MPI_IN_PLACE, budSum2, 27, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)   ! D-218
                 if (iCouple == 1) call mpi_allreduce(MPI_IN_PLACE, budSum3, 12, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)   ! D-221
                 if (iCouple == 1) call mpi_allreduce(MPI_IN_PLACE, budSum4, 126, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)   ! D-222
                 if (iCouple == 1) call mpi_allreduce(MPI_IN_PLACE, budSum5, 24, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)   ! D-223
                 if (iCouple == 1) call mpi_allreduce(MPI_IN_PLACE, budSum6, 45, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)   ! D-224
                 if (iCouple == 1) call mpi_allreduce(MPI_IN_PLACE, budSum7, 21, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)   ! D-225
                 if (iCouple == 1) call mpi_allreduce(MPI_IN_PLACE, budSum8, 210, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)   ! D-226
                 if (iCouple == 1) call mpi_allreduce(MPI_IN_PLACE, budSum9, 192, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)   ! D-226
                 ! D-205. The pass-1 line is the D-204 ordering probe and keeps
                 ! its label; passes 2..n are the same numbers inside the loop,
                 ! where the runaway actually happens. The [D119] residual
                 ! beside these decays monotonically through an excursion that
                 ! takes the hot fraction from 5% to 77% - it measures ion
                 ! fractions and cannot see this, which is why the loop looked
                 ! like it was settling.
                 if (taskid == 0 .and. nUpd1 > 0) then
                    if (iCouple == 1) then
                       print '(a,es11.4,a,i7,a,f6.2,a)', &
                            & " ! [D204]   pass-1 updateCell done, chemistry not&
                            & yet run:  mean Te ", teUpd1Sum/dble(nUpd1), &
                            & "  Te>3000 K in", nUpd1Hot, " (", &
                            & 100.d0*dble(nUpd1Hot)/dble(nUpd1), "%)"
                    end if
                    print '(a,i2,a,es11.4,a,f6.2,a,f7.4)', &
                         & " ! [D205]   pass", iCouple, " after updateCell:  mean Te ", &
                         & teUpd1Sum/dble(nUpd1), "  hot ", &
                         & 100.d0*dble(nUpd1Hot)/dble(nUpd1), " %   f_mol ", &
                         & molUpdSum/dble(nUpd1)
                    print '(a,3(es11.4,a))', &
                         & " ! [D205]      per H, as USED by the balance:  cool ", &
                         & pcSum/dble(nUpd1), "  heat ", phSum/dble(nUpd1), &
                         & "  (heatXtra ", ppeSum/dble(nUpd1), ")"
                    ! D-210. The net above goes NEGATIVE, meaning the
                    ! substitution removes more of MOCASSIN's cooling than it
                    ! puts back. These two say why: `removed` is MOCASSIN's own
                    ! coolant taken out, `added` is 3D-PDR's put in (net +
                    ! removed, by construction), and `guard kept` counts the
                    ! coolants where 3D-PDR had nothing and MOCASSIN's was
                    ! left alone (D-167). If added is well below removed while
                    ! the guard is quiet, the loss is 3D-PDR's coolants being
                    ! SMALLER, which nothing guards against.
                    print '(a,2(es11.4,a),f8.3)', &
                         & " ! [D210]      cooling: removed ", &
                         & pcSubSum/dble(nUpd1), "  added ", &
                         & (pcSum + pcSubSum)/dble(nUpd1), &
                         & "   guard kept, per cell ", pcNulSum/dble(nUpd1)
                    ! D-213. `added` is the product of these two. The raw
                    ! coolants come straight from pdrCoolSp; the factor is
                    ! D-166's (TeUsed/Tref)^slope, clamped to 1e-8..1e8,
                    ! which extrapolates a cold-gas coolant to whatever
                    ! temperature the solver is trying. If the coolants hold
                    ! steady while the factor collapses, the loss is the
                    ! extrapolation and not the chemistry.
                    print '(a,4(es11.4,a))', &
                         & " ! [D213]      coolants per H:  CO ", spSum(1)/dble(nUpd1), &
                         & "  C+ ", spSum(2)/dble(nUpd1), "  C ", spSum(3)/dble(nUpd1), &
                         & "  O ", spSum(4)/dble(nUpd1)
                    print '(a,3(es11.4,a))', &
                         & " ! [D213]      D-166 factor: mean (Te/Tref)^slope ", &
                         & tfacSum/dble(nUpd1), "   Tref ", trefSum/dble(nUpd1), &
                         & "   slope ", slopSum/dble(nUpd1)
                    ! D-217. Per group, per H nucleus: at ENTRY (the cell's
                    ! iteration-start Te under the new field - what changed)
                    ! and at EXIT (where the solve left it). Heating is
                    ! phot + PE + PDR, cooling is coll + rec + ff + gd + PDR,
                    ! and H-C is their difference; the terms are additive, so
                    ! the means are too.
                    if (iCouple == 1) then
                       budLab = (/ 'cold -> hot', 'stayed cold', 'started hot' /)
                       do iBudG = 1, 3
                          if (budSum(iBudG,21) <= 0.d0) cycle
                          print '(a,a,a,i8)', " ! [D217] ", budLab(iBudG), &
                               & "   cells", nint(budSum(iBudG,21))
                          print '(a,f9.1,a,3es10.2,a,5es10.2,a,es10.2)', &
                               & " ! [D217]   entry  Te", &
                               & budSum(iBudG,10)/budSum(iBudG,21), &
                               & "  heat phot/PE/PDR", &
                               & (budSum(iBudG,iBudT)/budSum(iBudG,21), iBudT = 1, 3), &
                               & "  cool coll/rec/ff/gd/PDR", &
                               & (budSum(iBudG,iBudT)/budSum(iBudG,21), iBudT = 4, 8), &
                               & "  H-C", budSum(iBudG,9)/budSum(iBudG,21)
                          print '(a,f9.1,a,3es10.2,a,5es10.2,a,es10.2)', &
                               & " ! [D217]   exit   Te", &
                               & budSum(iBudG,20)/budSum(iBudG,21), &
                               & "  heat phot/PE/PDR", &
                               & (budSum(iBudG,10+iBudT)/budSum(iBudG,21), iBudT = 1, 3), &
                               & "  cool coll/rec/ff/gd/PDR", &
                               & (budSum(iBudG,10+iBudT)/budSum(iBudG,21), iBudT = 4, 8), &
                               & "  H-C", budSum(iBudG,19)/budSum(iBudG,21)
                          ! D-218: depth, absorbers, field, tau at threshold,
                          ! and where these cells were one iteration ago
                          print '(a,f7.3,a,es10.3,a,f7.4,a,es10.3,a,es10.3,a,4i7)', &
                               & " ! [D218]   A_V", budSum2(iBudG,1)/budSum(iBudG,21), &
                               & "  x(H0)", budSum2(iBudG,2)/budSum(iBudG,21), &
                               & "  f_mol", budSum2(iBudG,3)/budSum(iBudG,21), &
                               & "  J>H0thr", budSum2(iBudG,4)/budSum(iBudG,21), &
                               & "  tau/cell@thr", budSum2(iBudG,5)/budSum(iBudG,21), &
                               & "   last it none/c->h/cold/hot", &
                               & (nint(budSum2(iBudG,5+iLastG)), iLastG = 1, 4)
                          ! D-221: which band. H0 share is H0's heating over the
                          ! group's entry photoionization heating (D-217 term 1).
                          print '(a,2es10.3,a,2es10.3,a,f8.4)', &
                               & " ! [D221]   J 13.6-15.4 / >15.4 eV", &
                               & budSum3(iBudG,1)/budSum(iBudG,21), &
                               & budSum3(iBudG,2)/budSum(iBudG,21), &
                               & "  H0 phot heat 13.6-15.4 / >15.4", &
                               & budSum3(iBudG,3)/budSum(iBudG,21), &
                               & budSum3(iBudG,4)/budSum(iBudG,21), &
                               & "  H0 share", &
                               & (budSum3(iBudG,3)+budSum3(iBudG,4)) &
                               & /max(budSum(iBudG,1), 1.d-99)
                          ! D-222: by band, then the absorber split at each hard
                          ! band's representative energy, with (gas+dust)/total
                          if (bandRepP(5) > 0) then
                             print '(a,5es10.2,a,5es10.2)', &
                                  & " ! [D222]   J by band win/H2-He0/He0-He+/He+-mid/mid-top", &
                                  & (budSum4(iBudG,kBd)/budSum(iBudG,21), kBd = 1, 5), &
                                  & "   H0 heat by band", &
                                  & (budSum4(iBudG,5+kBd)/budSum(iBudG,21), kBd = 1, 5)
                             do mBd = 2, 5
                                print '(a,f7.1,a,7es10.2,a,f8.4)', &
                                     & " ! [D222]   tau/cell @", nuArray(bandRepP(mBd))*13.605693, &
                                     & " eV  H2/ff/H0/He0/He+/Z/dust", &
                                     & (budSum4(iBudG,10+(mBd-2)*8+kBd)/budSum(iBudG,21), kBd = 1, 7), &
                                     & "  (gas+dust)/total", &
                                     & sum(budSum4(iBudG,10+(mBd-2)*8+1:10+(mBd-2)*8+7)) &
                                     & /max(budSum4(iBudG,10+(mBd-2)*8+8), 1.d-99)
                             end do
                          end if
                          ! D-223: neighbours, and the diffuse share of the field
                          print '(a,f7.2,a,f5.2,a,f7.2,a,f7.2,a)', &
                               & " ! [D223]   hot face-neighbour (Te_start>3000 K): >=1 in", &
                               & 100.d0*budSum5(iBudG,1)/budSum(iBudG,21), &
                               & "%   mean", budSum5(iBudG,2)/budSum(iBudG,21), &
                               & "   upstream (lower A_V) >=1 in", &
                               & 100.d0*budSum5(iBudG,3)/budSum(iBudG,21), &
                               & "%   downstream >=1 in", &
                               & 100.d0*budSum5(iBudG,4)/budSum(iBudG,21), "%"
                          if (pdrSplitField /= 0 .and. bandRepP(5) > 0) &
                               & print '(a,3f9.4)', &
                               & " ! [D223]   diffuse fraction of J  win / 15.4-24.6 / 24.6-54.4", &
                               & (budSum5(iBudG,5+kBd)/max(budSum4(iBudG,kBd), 1.d-99), kBd = 1, 3)
                          ! D-224: neighbours by optical depth, and where the
                          ! 15.4-24.6 eV stellar field came from
                          if (bandRepP(2) > 0) then
                             print '(a,f6.1,a,5f7.2,a,f7.2)', &
                                  & " ! [D224]   most transparent face-neighbour, tau/cell @", &
                                  & nuArray(bandRepP(2))*13.605693, &
                                  & " eV  <0.1 / 0.1-1 / 1-10 / 10-100 / >=100 (%)", &
                                  & (100.d0*budSum6(iBudG,kBd)/max(budSum6(iBudG,15), 1.d0), kBd = 1, 5), &
                                  & "   <log10>", budSum6(iBudG,6)/max(budSum6(iBudG,15), 1.d0)
                             print '(a,f7.2,a,f8.1,a,es10.3,a,f7.2,a,f7.2,a)', &
                                  & " ! [D224]   that neighbour: PDR zone", &
                                  & 100.d0*budSum6(iBudG,7)/max(budSum6(iBudG,15), 1.d0), &
                                  & "%   Te_start", budSum6(iBudG,8)/max(budSum6(iBudG,15), 1.d0), &
                                  & "   x(H0)_start", budSum6(iBudG,9)/max(budSum6(iBudG,15), 1.d0), &
                                  & "   upstream", 100.d0*budSum6(iBudG,10)/max(budSum6(iBudG,15), 1.d0), &
                                  & "%   any upstream neighbour tau/cell<1 in", &
                                  & 100.d0*budSum6(iBudG,14)/max(budSum(iBudG,21), 1.d0), "%"
                             ! D-232: the re-emission spectrum by source term
                             if (budSum8(iBudG,16)+budSum8(iBudG,17) > 0.d0) then
                                print '(a,f8.5,a,es10.3,a,es10.3,a,es10.3,a,es10.3)', &
                                     & " ! [D232]   re-emission spectrum: dust share", &
                                     & budSum8(iBudG,17) &
                                     & /max(budSum8(iBudG,16)+budSum8(iBudG,17), 1.d-99), &
                                     & "   gas >13.6 eV / gas", &
                                     & budSum8(iBudG,18)/max(budSum8(iBudG,16), 1.d-99), &
                                     & "   dust >13.6 eV / dust", &
                                     & budSum8(iBudG,19)/max(budSum8(iBudG,17), 1.d-99), &
                                     & "   gas >24.6 eV / gas", &
                                     & budSum8(iBudG,20)/max(budSum8(iBudG,16), 1.d-99), &
                                     & "   dust >24.6 eV / dust", &
                                     & budSum8(iBudG,21)/max(budSum8(iBudG,17), 1.d-99)
                             end if
                             print '(a,2f9.5)', &
                                  & " ! [D224]   15.4-24.6 eV stellar J share: steps not in their cell / entering from tau/cell<1", &
                                  & budSum6(iBudG,12)/max(budSum6(iBudG,11), 1.d-99), &
                                  & budSum6(iBudG,13)/max(budSum6(iBudG,11), 1.d-99)
                             ! D-225: the closure, and the transport events
                             ! that actually happened in these cells
                             if (pdrSplitField /= 0) then
                                print '(a,es10.3,a,es10.3,a,f9.6,a,f7.2,a)', &
                                     & " ! [D225]   15.4-24.6 eV per cell: Jste", &
                                     & budSum7(iBudG,1)/max(budSum(iBudG,21), 1.d0), &
                                     & "   traced, all packets", budSum7(iBudG,4)/max(budSum(iBudG,21), 1.d0), &
                                     & "   traced/Jste", budSum7(iBudG,4)/max(budSum7(iBudG,1), 1.d-99), &
                                     & "   cells not closing to 1e-3", &
                                     & 100.d0*budSum7(iBudG,7)/max(budSum(iBudG,21), 1.d0), "%"
                                print '(a,es10.3,a,es10.3,a,f9.6,a,es10.3,a,es10.3)', &
                                     & " ! [D225]   stellar per cell: Jste-Jdif", &
                                     & (budSum7(iBudG,1)-budSum7(iBudG,2))/max(budSum(iBudG,21), 1.d0), &
                                     & "   traced stellar", budSum7(iBudG,3)/max(budSum(iBudG,21), 1.d0), &
                                     & "   ratio", budSum7(iBudG,3)/max(budSum7(iBudG,1)-budSum7(iBudG,2), 1.d-99), &
                                     & "   stellar interactions/cell", budSum7(iBudG,5)/max(budSum(iBudG,21), 1.d0), &
                                     & "   stellar steps/cell", budSum7(iBudG,6)/max(budSum(iBudG,21), 1.d0)
                             end if
                             ! D-226: the re-emission spectrum in the band,
                             ! and where in the band the field sits
                             if (bandP(3) > bandP(2) .and. bandP(2) > 1) then
                                nB226 = min(bandP(3) - bandP(2), 64)
                                kTopP = maxloc(budSum8(iBudG,6:5+nB226), 1) - 1
                                kTopJ = maxloc(budSum9(iBudG,1:nB226), 1) - 1
                                print '(a,es10.3,a,f7.2,a,es10.3,a,f7.2,a,es10.3,a,es10.3,a,f6.3)', &
                                     & " ! [D226]   P(re-emitted packet born in 15.4-24.6 eV)", &
                                     & budSum8(iBudG,1)/max(budSum(iBudG,21), 1.d0), &
                                     & "   top bin", nuArray(bandP(2)+kTopP)*13.605693, &
                                     & " eV carries", budSum8(iBudG,6+kTopP)/max(budSum8(iBudG,1), 1.d-99), &
                                     & "   Te_start<100 K (%)", 100.d0*budSum8(iBudG,2)/max(budSum(iBudG,21), 1.d0), &
                                     & "   x(He+)", budSum8(iBudG,3)/max(budSum(iBudG,21), 1.d0), &
                                     & "   x(H+)", budSum8(iBudG,4)/max(budSum(iBudG,21), 1.d0), &
                                     & "   line fraction", budSum8(iBudG,5)/max(budSum(iBudG,21), 1.d0)
                                print '(a,f7.2,a,f6.3,a,f7.2,a,f6.3)', &
                                     & " ! [D226]   Jste 15.4-24.6 eV: top bin", nuArray(bandP(2)+kTopJ)*13.605693, &
                                     & " eV holds", budSum9(iBudG,1+kTopJ)/max(sum(budSum9(iBudG,1:nB226)), 1.d-99), &
                                     & " of the band;  the top-P bin", nuArray(bandP(2)+kTopP)*13.605693, &
                                     & " eV holds", budSum9(iBudG,1+kTopP)/max(sum(budSum9(iBudG,1:nB226)), 1.d-99)
                             end if
                          end if
                       end do
                    end if
                 end if
              end if
#endif

#ifdef PDR
              ! PDR chemistry, distributed exactly as updateCell is: per-cell
              ! chemistry is embarrassingly parallel and needs no new MPI
              ! design (DEVLOG D-027). Runs in addition to updateCell for now -
              ! handing thermal balance over to 3D-PDR in the neutral zone
              ! (D-007) needs the cooling functions and is the next step.
              !
              ! The reduction differs from Te/Ne/ionDen above. Those are built
              ! into a zeroed temporary that only owned cells write, so SUM
              ! reassembles them. pdrAbun instead holds a full seeded copy on
              ! EVERY rank, so a plain SUM would multiply it by numtasks. Each
              ! rank therefore contributes only the cells it owns, and the
              ! owner contributes them whether or not pdrStep changed anything -
              ! otherwise skipped cells (inactive, or outside the PDR zone)
              ! would come back zero and lose their seeded abundances.
              if (lgPDR .and. nIterateMC >= pdrStartIter) then
                 if (taskid==0) print*, '! iterateMC: pdrStep in', iG
                 allocate(pdrAbunTemp(0:grid(iG)%nCells,1:pdrNspec), stat=err)
                 if (err /= 0) then
                    print*, "! iterateMC: can't allocate pdrAbunTemp"; stop
                 end if
                 allocate(pdrAbunSum(0:grid(iG)%nCells,1:pdrNspec), stat=err)
                 if (err /= 0) then
                    print*, "! iterateMC: can't allocate pdrAbunSum"; stop
                 end if
                 allocate(pdrHeatTmp(0:grid(iG)%nCells),   stat=err)
                 allocate(pdrHeatSum(0:grid(iG)%nCells),   stat=err)
                 allocate(pdrHeatPETmp(0:grid(iG)%nCells), stat=err)
                 allocate(pdrHeatPESum(0:grid(iG)%nCells), stat=err)
                 allocate(pdrHeatGGTmp(0:grid(iG)%nCells), stat=err)
                 allocate(pdrHeatGGSum(0:grid(iG)%nCells), stat=err)
                 allocate(pdrCoolSlTmp(0:grid(iG)%nCells), stat=err)
                 allocate(pdrCoolSlSum(0:grid(iG)%nCells), stat=err)
                 allocate(pdrCoolTrTmp(0:grid(iG)%nCells), stat=err)
                 allocate(pdrCoolTrSum(0:grid(iG)%nCells), stat=err)
                 allocate(NePDRTmp(0:grid(iG)%nCells), stat=err)
                 allocate(NePDRSum(0:grid(iG)%nCells), stat=err)
                 allocate(H2denTmp(0:grid(iG)%nCells), stat=err)
                 allocate(H2denSum(0:grid(iG)%nCells), stat=err)
                 allocate(pdrCoolSpTmp(0:grid(iG)%nCells, 1:max(pdrNcool,1)), stat=err)
                 allocate(pdrCoolSpSum(0:grid(iG)%nCells, 1:max(pdrNcool,1)), stat=err)
                 if (pdrCoupleIter > 1 .and. .not.allocated(ionDenPrev)) then
                    allocate(ionDenPrev(0:grid(iG)%nCells, 1:nElementsUsed, 1:nstages), stat=err)
                    if (err /= 0) then
                       print*, "! iterateMC: can't allocate ionDenPrev"; stop
                    end if
                 end if
                 allocate(pdrIonRateTmp(0:grid(iG)%nCells, 1:2*pdrNlink), stat=err)
                 allocate(pdrIonRateSum(0:grid(iG)%nCells, 1:2*pdrNlink), stat=err)
                 allocate(pdrZoneSum(0:grid(iG)%nCells),   stat=err)
                 allocate(pdrCoolTmp(0:grid(iG)%nCells),   stat=err)
                 allocate(pdrCoolSum(0:grid(iG)%nCells),   stat=err)
                 allocate(pdrLevTmp(0:grid(iG)%nCells,1:max(pdrNlevTot,1)), stat=err)
                 allocate(pdrLevSum(0:grid(iG)%nCells,1:max(pdrNlevTot,1)), stat=err)
                 allocate(pdrTgTmp(0:grid(iG)%nCells), pdrTgSum(0:grid(iG)%nCells), stat=err)
                 allocate(pdrTlTmp(0:grid(iG)%nCells), pdrTlSum(0:grid(iG)%nCells), stat=err)
                 allocate(pdrThTmp(0:grid(iG)%nCells), pdrThSum(0:grid(iG)%nCells), stat=err)
                 if (err /= 0) then
                    print*, "! iterateMC: can't allocate PDR reduction buffers"; stop
                 end if
                 pdrAbunTemp  = 0.d0
                 pdrAbunSum   = 0.d0
                 pdrHeatTmp   = 0.
                 pdrHeatSum   = 0.
                 pdrHeatPETmp = 0.
                 pdrHeatGGTmp = 0.
                 pdrCoolSlTmp = 0.
                 pdrCoolTrTmp = 0.
                 NePDRTmp = 0.
                 H2denTmp = 0.
                 pdrCoolSpTmp = 0.
                 pdrIonRateTmp = 0.; pdrIonRateSum = 0.
                 pdrHeatPESum = 0.
                 pdrZoneSum   = 0
                 pdrCoolTmp   = 0.
                 pdrCoolSum   = 0.
                 pdrLevTmp    = 0.d0
                 pdrLevSum    = 0.d0
                 pdrTgTmp = 0.; pdrTgSum = 0.
                 pdrTlTmp = 0.; pdrTlSum = 0.
                 pdrThTmp = 0.; pdrThSum = 0.
                 pdrNstuck   = 0
                 pdrNbadPop  = 0

                 iCell = 0
                 do i = 1, grid(iG)%nx
                    do j = 1, yTop
                       do k = 1, grid(iG)%nz
                          iCell = iCell+1
                          if (mod(iCell-(taskid+1),numtasks)==0) then
                             call pdrStep(grid(iG),i,j,k)
                             if (grid(iG)%active(i,j,k) > 0) then
                                pdrAbunTemp(grid(iG)%active(i,j,k),:) = &
                                     & grid(iG)%pdrAbun(grid(iG)%active(i,j,k),:)
                                pdrHeatTmp(grid(iG)%active(i,j,k))   = &
                                     & grid(iG)%pdrHeat(grid(iG)%active(i,j,k))
                                pdrHeatPETmp(grid(iG)%active(i,j,k)) = &
                                     & grid(iG)%pdrHeatPE(grid(iG)%active(i,j,k))
                                pdrCoolTmp(grid(iG)%active(i,j,k))   = &
                                     & grid(iG)%pdrCool(grid(iG)%active(i,j,k))
                                pdrHeatGGTmp(grid(iG)%active(i,j,k)) = &
                                     & grid(iG)%pdrHeatGG(grid(iG)%active(i,j,k))
                                pdrCoolSlTmp(grid(iG)%active(i,j,k)) = &
                                     & grid(iG)%pdrCoolSlope(grid(iG)%active(i,j,k))
                                pdrCoolTrTmp(grid(iG)%active(i,j,k)) = &
                                     & grid(iG)%pdrCoolTref(grid(iG)%active(i,j,k))
                                NePDRTmp(grid(iG)%active(i,j,k)) = &
                                     & grid(iG)%NePDR(grid(iG)%active(i,j,k))
                                H2denTmp(grid(iG)%active(i,j,k)) = &
                                     & grid(iG)%H2den(grid(iG)%active(i,j,k))
                                pdrCoolSpTmp(grid(iG)%active(i,j,k),:) = &
                                     & grid(iG)%pdrCoolSp(grid(iG)%active(i,j,k),:)
                                pdrIonRateTmp(grid(iG)%active(i,j,k),:) = &
                                     & grid(iG)%pdrIonRate(grid(iG)%active(i,j,k),:)
                                pdrLevTmp(grid(iG)%active(i,j,k),:)  = &
                                     & grid(iG)%pdrLevPop(grid(iG)%active(i,j,k),:)
                                pdrTgTmp(grid(iG)%active(i,j,k))  = grid(iG)%pdrTgas(grid(iG)%active(i,j,k))
                                pdrTlTmp(grid(iG)%active(i,j,k))  = grid(iG)%pdrTlow(grid(iG)%active(i,j,k))
                                pdrThTmp(grid(iG)%active(i,j,k))  = grid(iG)%pdrThigh(grid(iG)%active(i,j,k))
                             end if
                          end if
                       end do
                    end do
                 end do

                 size = (grid(iG)%nCells+1)*pdrNspec
                 call mpi_allreduce(pdrAbunTemp, pdrAbunSum, size, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)

                 ! The heating budget needs the same treatment. Without it only
                 ! the cells owned by rank 0 survive into the output, so the
                 ! array looks ~1/numtasks populated - which reads like a
                 ! physics problem rather than a missing exchange.
                 size = grid(iG)%nCells+1
                 call mpi_allreduce(pdrHeatTmp, pdrHeatSum, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)
                 call mpi_allreduce(pdrHeatPETmp, pdrHeatPESum, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)
                 call mpi_allreduce(pdrCoolTmp, pdrCoolSum, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)
                 grid(iG)%pdrCool(1:grid(iG)%nCells) = pdrCoolSum(1:grid(iG)%nCells)
                 call mpi_allreduce(pdrCoolSlTmp, pdrCoolSlSum, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)
                 grid(iG)%pdrCoolSlope(1:grid(iG)%nCells) = pdrCoolSlSum(1:grid(iG)%nCells)
                 call mpi_allreduce(pdrCoolTrTmp, pdrCoolTrSum, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)
                 grid(iG)%pdrCoolTref(1:grid(iG)%nCells) = pdrCoolTrSum(1:grid(iG)%nCells)
                 call mpi_allreduce(pdrHeatGGTmp, pdrHeatGGSum, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)
                 grid(iG)%pdrHeatGG(1:grid(iG)%nCells) = pdrHeatGGSum(1:grid(iG)%nCells)
                 call mpi_allreduce(NePDRTmp, NePDRSum, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)
                 grid(iG)%NePDR(1:grid(iG)%nCells) = NePDRSum(1:grid(iG)%nCells)
                 call mpi_allreduce(H2denTmp, H2denSum, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)
                 grid(iG)%H2den(1:grid(iG)%nCells) = H2denSum(1:grid(iG)%nCells)
                 size = (grid(iG)%nCells+1)*max(pdrNcool,1)
                 call mpi_allreduce(pdrCoolSpTmp, pdrCoolSpSum, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)
                 grid(iG)%pdrCoolSp(1:grid(iG)%nCells,:) = pdrCoolSpSum(1:grid(iG)%nCells,:)
                 size = (grid(iG)%nCells+1)*2*pdrNlink
                 call mpi_allreduce(pdrIonRateTmp, pdrIonRateSum, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)
                 grid(iG)%pdrIonRate(1:grid(iG)%nCells,:) = pdrIonRateSum(1:grid(iG)%nCells,:)
                 size = grid(iG)%nCells+1
                 size = (grid(iG)%nCells+1)*max(pdrNlevTot,1)
                 call mpi_allreduce(pdrLevTmp, pdrLevSum, size, &
                      & mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
                 grid(iG)%pdrLevPop(1:grid(iG)%nCells,:) = pdrLevSum(1:grid(iG)%nCells,:)
                 size = grid(iG)%nCells+1
                 call mpi_allreduce(pdrTgTmp, pdrTgSum, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)
                 call mpi_allreduce(pdrTlTmp, pdrTlSum, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)
                 call mpi_allreduce(pdrThTmp, pdrThSum, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)
                 grid(iG)%pdrTgas(1:grid(iG)%nCells)  = pdrTgSum(1:grid(iG)%nCells)
                 grid(iG)%pdrTlow(1:grid(iG)%nCells)  = pdrTlSum(1:grid(iG)%nCells)
                 grid(iG)%pdrThigh(1:grid(iG)%nCells) = pdrThSum(1:grid(iG)%nCells)
                 grid(iG)%pdrHeat(1:grid(iG)%nCells)   = pdrHeatSum(1:grid(iG)%nCells)
                 grid(iG)%pdrHeatPE(1:grid(iG)%nCells) = pdrHeatPESum(1:grid(iG)%nCells)

                 ! pdrZone is identical on every rank except where pdrStep
                 ! raised it to 2 for a stalled cell, so MAX propagates that.
                 call mpi_allreduce(grid(iG)%pdrZone, pdrZoneSum, size, &
                      & mpi_integer, mpi_max, mpi_comm_world, ierr)
                 grid(iG)%pdrZone = pdrZoneSum
                 ! cell 0 is the inactive dump cell: several (i,j,k) map to it,
                 ! so it is deliberately left out of the exchange
                 grid(iG)%pdrAbun(1:grid(iG)%nCells,:) = &
                      & pdrAbunSum(1:grid(iG)%nCells,:)

                 deallocate(pdrAbunTemp)
                 deallocate(pdrAbunSum)
                 deallocate(pdrHeatTmp)
                 deallocate(pdrHeatSum)
                 deallocate(pdrHeatPETmp)
                 deallocate(pdrHeatPESum)
                 deallocate(pdrZoneSum)
                 deallocate(pdrCoolTmp)
                 deallocate(pdrCoolSum)
                 deallocate(pdrLevTmp)
                 deallocate(pdrLevSum)
                 deallocate(pdrTgTmp, pdrTgSum, pdrTlTmp, pdrTlSum, pdrThTmp, pdrThSum)
                 deallocate(pdrCoolSlTmp, pdrCoolSlSum, pdrCoolTrTmp, pdrCoolTrSum)  ! D-166
                 ! ------------------------------------------------------ D-253
                 ! These ten are allocated in the same guarded block at
                 ! :1942-1961 and were omitted from this list, so every MC
                 ! iteration left them behind. That matters because iterateMC
                 ! is RECURSIVE - it advances nIterateMC and calls itself at
                 ! :3258 rather than looping - so an allocatable still
                 ! allocated at that call stays live in that frame and in
                 ! every frame beneath it. D-245 exactly, in the same routine.
                 !
                 ! ~3.1 MB per iteration per rank at 15205 cells, dominated by
                 ! pdrIonRate{Tmp,Sum} at 1.16 MB each; measured drift was
                 ! ~4.5 MB/rank/iteration, so this is most of it. Last use of
                 ! all ten is :2060-2076, so freeing here is safe.
                 !
                 ! ionDenPrev is deliberately NOT freed: it is guarded by
                 ! .not.allocated at :1954 and persists across coupling passes
                 ! by design.
                 deallocate(pdrHeatGGTmp, pdrHeatGGSum)
                 deallocate(NePDRTmp, NePDRSum)
                 deallocate(H2denTmp, H2denSum)
                 deallocate(pdrCoolSpTmp, pdrCoolSpSum)
                 deallocate(pdrIonRateTmp, pdrIonRateSum)

                 call mpi_allreduce(pdrNstuck, i1PdrStuck, 1, mpi_integer, &
                      & mpi_sum, mpi_comm_world, ierr)
                 if (taskid==0) then
                    print*, '! iterateMC: pdrStep out', iG
                    if (pdrNbadPop > 0) print*, &
                         & "! iterateMC: [warning] ", pdrNbadPop, &
                         & " level-population solves rejected as non-finite (D-041)"
                    if (i1PdrStuck > 0) then
                       print*, "! iterateMC: chemistry unchanged in ", i1PdrStuck, &
                            & " cells (converged or stalled) - thermal balance still runs"
                    end if
                 end if

                 ! ------------------------------------------------- D-199
                 ! Publish elemAvail HERE, inside the coupling loop, not once
                 ! per MC iteration after it.
                 !
                 ! pdrToMocassin is the only writer of elemAvail, and until now
                 ! it ran after this loop closed. updateCell reads elemAvail and
                 ! runs pdrCoupleIter times per iteration, so every one of those
                 ! passes was normalising the ion stages to a molecular fraction
                 ! a full MC iteration out of date.
                 !
                 ! That was survivable while pdrToMocassin also wrote ionDen
                 ! directly - the handback corrected its own lag. D-193 removed
                 ! that write: ionDen is now ionBalance's answer normalised to
                 ! elemAvail and nothing else, so a stale elemAvail goes
                 ! straight into x(H0), which is the quantity the convergence
                 ! test measures. Measured at D-198: the ion/chemistry x(H+)
                 ! ratio rang 1.05 -> 19.5 -> 0.166 across iterations 4-6 while
                 ! the converged fraction sat at 0.00% for three passes.
                 !
                 ! The old call site carried a note that it had to follow the Te
                 ! allreduce, which overwrites grid%Te wholesale. That no longer
                 ! binds: under D-193 pdrToMocassin writes elemAvail and nothing
                 ! else. It does need the pdrAbun reduction above, which is why
                 ! it sits here rather than higher up.
                 if (lgPDR .and. nIterateMC >= pdrStartIter) &
                      & call pdrToMocassin(grid(1:nGrids))
              end if
#endif

#ifdef PDR
              ! D-216: inert under the restructure and kept only so the
              ! residual is still reported. ionDen is written by updateCell,
              ! which now runs once per MC iteration, and pdrToMocassin writes
              ! elemAvail and nothing else (D-193) - so ionDen does not change
              ! across chemistry passes and this measures zero. It is left in
              ! place rather than deleted because the [D119] line is how the
              ! ionization/chemistry handshake was watched, and a line that
              ! reads zero for a stated reason is better than a line that
              ! disappears.
              if (lgPDR .and. nIterateMC >= pdrStartIter .and. iCouple > 1 &
                  & .and. allocated(ionDenPrev)) then
                 ! Cloudy damps by averaging old and new rather than taking the
                 ! new value outright; two solvers passing rates can otherwise
                 ! chase each other instead of settling.
                 ! D-119: measure the change ABUNDANCE-WEIGHTED.
                 !
                 ! The first version of this was a bare relative difference
                 ! over every stage above 1e-10, and it reported changes of
                 ! 1e5 - not a diverging loop, but a stage sitting on the guard
                 ! where a negligible absolute change is an enormous relative
                 ! one. That is the third time in this work a comparison built
                 ! that way has measured its own floor rather than the physics
                 ! (see the chain-vs-matrix diff and the MC "noise floor").
                 !
                 ! The general form of the mistake: a relative-difference
                 ! metric with a bare floor guard measures the floor. Weight by
                 ! how much of the element the stage actually holds, so a
                 ! stage carrying 1e-12 of it cannot dominate the answer.
                 pdrCoupleResid = 0.d0
                 fWt = 0.d0
                 do iDum = 1, grid(iG)%nCells
                    do jDum = 1, nElementsUsed
                       do kDum = 1, nstages
                          wNew = dble(grid(iG)%ionDen(iDum,jDum,kDum))
                          if (wNew <= 0.d0) cycle
                          pdrCoupleResid = pdrCoupleResid + wNew * &
                             & abs(wNew - dble(ionDenPrev(iDum,jDum,kDum)))
                          fWt = fWt + wNew
                       end do
                    end do
                 end do
                 if (fWt > 0.d0) pdrCoupleResid = pdrCoupleResid/fWt
                 ! D-174: pdrCoupleDamp is now the weight on the PREVIOUS
                 ! pass, matching iterDamp. The arithmetic is flipped with it.
                 grid(iG)%ionDen = real((1.d0-pdrCoupleDamp)*dble(grid(iG)%ionDen) &
                      &          + pdrCoupleDamp*dble(ionDenPrev))
                 if (taskid == 0) print*, "! [D119] coupling pass", iCouple, &
                      & " abundance-weighted mean ion-fraction change:", &
                      & real(pdrCoupleResid)
              end if
#endif
              end do


              if (lgTraceHeating.and.taskid==0) then
                 close (57)
              end if



              size = 1

              call mpi_allreduce(grid(iG)%noHit, noHitPercent(iG), size, &
                   & mpi_real, mpi_sum,mpi_comm_world, ierr)

              if (lgGas) then
                 call mpi_allreduce(grid(iG)%noIonBal, noIonBalPercent(iG), size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)

                 call mpi_allreduce(grid(iG)%noTeBal, noTeBalPercent(iG), size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)
              end if

              size =  (grid(iG)%nCells+1)

              ! D-175 probe: lgConverged is MPI_SUM'd here and the GLOBAL
              ! result is copied back into grid%lgConverged a few lines below -
              ! inside the coupling loop. After the first pass every rank holds
              ! the full global array, so the next pass's sum adds each cell's
              ! value once per rank. If that is what happens, the flag stops
              ! being 0/1 and the headline convergence percentage stops meaning
              ! what it says. Measure it rather than argue about it.
              if (teProbe /= 0 .and. taskid == 0) then
                 nCv1 = 0
                 do iDum = 1, grid(iG)%nCells
                    if (grid(iG)%lgConverged(iDum) == 1) nCv1 = nCv1 + 1
                 end do
                 print*, "! [D175] pass", iCouple, " rank0 pre-reduce: ==1", nCv1, &
                      & " max", maxval(grid(iG)%lgConverged(1:grid(iG)%nCells)), &
                      & " sum", sum(grid(iG)%lgConverged(1:grid(iG)%nCells))
              end if
              call mpi_allreduce(grid(iG)%lgConverged, lgConvergedTemp, size, &
                   & mpi_integer, mpi_sum, mpi_comm_world, ierr)
              if (teProbe /= 0 .and. taskid == 0) then
                 nCv1 = 0
                 do iDum = 1, grid(iG)%nCells
                    if (lgConvergedTemp(iDum) == 1) nCv1 = nCv1 + 1
                 end do
                 print*, "! [D175] pass", iCouple, " post-reduce:     ==1", nCv1, &
                      & " max", maxval(lgConvergedTemp(1:grid(iG)%nCells)), &
                      & " sum", sum(lgConvergedTemp(1:grid(iG)%nCells))
              end if
              call mpi_allreduce(grid(iG)%lgBlack, lgBlackTemp, size, &
                   & mpi_integer, mpi_sum, mpi_comm_world, ierr)


              if (lgGas) then
                 call mpi_allreduce(NeTemp, grid(iG)%Ne, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)
                 call mpi_allreduce(TeTemp, grid(iG)%Te, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)


                 size = (grid(iG)%nCells+1)*nElementsUsed*nStages

                 call mpi_allreduce(ionDenTemp, grid(iG)%ionDen, size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)

              end if

#ifdef PDR
              ! D-199: pdrToMocassin now runs INSIDE the coupling loop, so that
              ! elemAvail is current for each updateCell pass rather than one MC
              ! iteration stale. See the note at that call site. The old comment
              ! here - that the handover had to follow the Te allreduce, which
              ! overwrites grid%Te wholesale - applied when pdrToMocassin still
              ! wrote Te; D-193 removed that write.
#endif


              if (lgDust) then
                 size =  (grid(iG)%nCells+1)*(nspeciesMax+1)*(nsizes+1)

                 call mpi_allreduce(TdustTemp,grid(iG)%Tdust,size, &
                      & mpi_real, mpi_sum, mpi_comm_world, ierr)

                 if (lgGas .and. convPercent>=resLinesTransfer .and. (.not.lgResLinesFirst) &
                      & .and. .not.(nIterateMC==1)) then

                    allocate(budgetTemp(0:nAbComponents,0:nResLines), stat=err)
                    if (err /= 0) then
                       print*, "! iterateMC: can't allocate array memory:&
                            &budgetTemp "
                       stop
                    end if
                    budgetTemp=0.

                    size = (nAbcomponents+1)*(nResLines+1)

                    call mpi_allreduce(dustHeatingBudget,budgetTemp,size, &
                         & mpi_real, mpi_sum, mpi_comm_world, ierr)

                    dustHeatingBudget = budgetTemp


                    deallocate(budgetTemp)

                 end if

              end if

              do i = 1, grid(iG)%nx
                 do j = 1, yTop
                    do k = 1, grid(iG)%nz
                       if (grid(iG)%active(i,j,k)>0) then
                          grid(iG)%lgConverged(grid(iG)%active(i,j,k)) = &
                               & lgConvergedTemp(grid(iG)%active(i,j,k))
                          grid(iG)%lgBlack(grid(iG)%active(i,j,k)) = &
                               & lgBlackTemp(grid(iG)%active(i,j,k))
                       end if
                    end do
                 end do
              end do


              call mpi_barrier(mpi_comm_world, ierr)

              if ( allocated(lgConvergedTemp) )  deallocate(lgConvergedTemp)
              if ( allocated(lgBlackTemp) )  deallocate(lgBlackTemp)
              if (lgGas) then
                 if ( allocated(NeTemp) )           deallocate(NeTemp)
                 if ( allocated(TeTemp) )           deallocate(TeTemp)
                 if ( allocated(ionDenTemp) )       deallocate(ionDenTemp)
              end if
              if (lgDust) then
                 if ( allocated(TdustTemp)) deallocate(TdustTemp)
              end if

           end do

           ! ------------------------------------------------------- D-174
           ! Damp the temperature across the MC iteration. The coupling loop
           ! above is damped pass to pass (pdrCoupleDamp); this interval - the
           ! one the convergence criterion is defined on - was not damped at
           ! all, and D-173 measured 44-76% of cells crossing the branch
           ! boundary on every one of them, in both directions at once.
           !
           ! Applied after the coupling loop and after Te has been reduced
           ! across ranks, so every rank damps the same complete array against
           ! the same iteration-start snapshot. Te only, for now: it is the
           ! bistable variable, and one change at a time is the point.
           if (iterDamp > 0.) then
              do iG = 1, nGrids
                 if (.not.allocated(grid(iG)%TeIterStart)) cycle
                 do iDum = 1, grid(iG)%nCells
                    if (grid(iG)%TeIterStart(iDum) > 0.) &
                         & grid(iG)%Te(iDum) = &
                         &   (1.-iterDamp)*grid(iG)%Te(iDum) &
                         & + iterDamp*grid(iG)%TeIterStart(iDum)
                 end do
              end do
           end if

           ! ------------------------------------------------------- D-200
           ! Damp the MOLECULAR and IONIC state across the MC iteration too.
           !
           ! D-174 damped Te here and recorded the restriction: "Te only, for
           ! now: it is the bistable variable, and one change at a time is the
           ! point." D-198 measured the state the contract settles into and Te
           ! is not the only bistable variable. The two branches differ in all
           ! three quantities at once - hot cells are atomic, ionized and hot;
           ! cold cells are molecular, neutral and cold - and damping one of
           ! the three while the other two are free lets the free pair carry
           ! the flip and drag the damped one after it.
           !
           ! The molecular abundances matter for a reason specific to this
           ! chemistry: under CHEMSTEADY the network integrates to a steady
           ! state, so its starting point does not set the answer EXCEPT where
           ! more than one steady state exists - which is precisely the
           ! bistable regime (D-112 measured that a seed can select between
           ! them and that the two do not relax into each other). pdrAbun
           ! carries over from the previous iteration as that starting point,
           ! undamped until now.
           !
           ! WHAT THIS CAN AND CANNOT DO. Damping is a relaxation on the path,
           ! not a change to the fixed point: if the coupled system has one
           ! root and was oscillating around it, this finds it; if the thermal
           ! balance genuinely has two roots, this does NOT remove the second
           ! one - it freezes each cell on whichever branch it is nearest and
           ! the profile stays bimodal but stops moving. Those two outcomes
           ! look different and the difference is the measurement: a single
           ! smooth profile means the oscillation was a coupling artifact; a
           ! static bimodal one means the roots are real and damping has hidden
           ! the symptom rather than fixed the cause. Reported either way.
           !
           ! Applied after the coupling loop and after the reductions, so every
           ! rank damps the same complete arrays against the same snapshot.
#ifdef PDR
           if (lgPDR .and. iterDamp > 0. .and. nIterateMC >= pdrStartIter) then
              do iG = 1, nGrids
                 if (allocated(pdrAbunIter) .and. allocated(grid(iG)%pdrAbun)) then
                    grid(iG)%pdrAbun(0:grid(iG)%nCells, 1:pdrNspec) = &
                         &   (1.d0-dble(iterDamp)) &
                         &   *grid(iG)%pdrAbun(0:grid(iG)%nCells, 1:pdrNspec) &
                         & + dble(iterDamp)*pdrAbunIter
                 end if
                 if (allocated(ionDenIter)) then
                    grid(iG)%ionDen(0:grid(iG)%nCells, :, :) = &
                         &   (1.-iterDamp)*grid(iG)%ionDen(0:grid(iG)%nCells, :, :) &
                         & + iterDamp*ionDenIter
                 end if
              end do
              ! H2den is DERIVED from pdrAbun too - pdrStep writes it as
              ! abun(NH2)*nH - so it has to follow the damped abundances or the
              ! model carries two x(H2). It is not a diagnostic: MOCASSIN's H2
              ! opacity reads it (D-107, addOpacity), the convergence test
              ! reads it against xH2iterStart (D-179), and the D-200 branch
              ! census reads it. Leaving it undamped is exactly the "one
              ! reality per quantity" failure this project keeps finding, and
              ! the damping introduced it: measured on the first D-200 run, the
              ! in-code census (H2den, undamped) put 27.6% of cells on the hot
              ! branch at iteration 12 while the same census recomputed from
              ! pdrAbun (damped) put 1.6% there. Same cells, same threshold,
              ! two different molecular fractions.
              do iG = 1, nGrids
                 if (.not.allocated(grid(iG)%H2den)) cycle
                 if (pdrIdxH2 <= 0) cycle
                 do iDum = 0, grid(iG)%nCells
                    grid(iG)%H2den(iDum) = &
                         & real(grid(iG)%pdrAbun(iDum,pdrIdxH2))*grid(iG)%Hden(iDum)
                 end do
              end do
              ! elemAvail is DERIVED from pdrAbun, so republish it from the
              ! damped abundances. Without this the next iteration's first
              ! coupling pass normalises the ion stages to a molecular fraction
              ! that no longer matches the abundances it sits beside - the
              ! D-199 lag, reintroduced by the damping itself.
              if (nIterateMC >= pdrStartIter) call pdrToMocassin(grid(1:nGrids))
           end if
           ! D-220: after the last change to the molecular content and the last
           ! republish - whether or not the damping above ran - bring the ion
           ! stages to the same hydrogen before the next iteration builds its
           ! opacity from them (D-219).
           if (lgPDR .and. nIterateMC >= pdrStartIter) &
                & call rescaleIonToAvail(grid(1:nGrids))
           if (allocated(pdrAbunIter)) deallocate(pdrAbunIter)
           if (allocated(ionDenIter))  deallocate(ionDenIter)
#endif

!******************************************************************************

           if (nGrids>1) then
!              print*, " ! iterateMC: integratePathTau stuff still not implemented for multiple grids.... skipping"
           else
              call writeTauNu(grid)
           end if


           ! ------------------------------------------------------- D-183
           ! Are the chemistry's per-stage rates actually being delivered?
           ! D-118 stands elemAvail down wherever they are supplied, so if they
           ! are zero the molecular locking is represented by NEITHER mechanism.
           ! D-169 measured zero for hydrogen - but that probe fired inside
           ! updateCell, which runs BEFORE pdrStep in every coupling pass, so on
           ! the first PDR pass pdrIonRate has never been written. Report the
           ! populated fraction and magnitude here, after the pass, where the
           ! question is answerable.
#ifdef PDR
           if (lgPDR .and. teProbe /= 0 .and. taskid == 0 .and. &
                & nIterateMC >= pdrStartIter) then
              do iG = 1, nGrids
                 if (.not.allocated(grid(iG)%pdrIonRate)) cycle
                 do iDum = 1, min(2*pdrNlink, 10)
                    wDum = 0.d0; nCv1 = 0
                    do jDum = 1, grid(iG)%nCells
                       if (grid(iG)%pdrIonRate(jDum,iDum) /= 0.) then
                          nCv1 = nCv1 + 1
                          wDum = wDum + abs(dble(grid(iG)%pdrIonRate(jDum,iDum)))
                       end if
                    end do
                    print '(a,i3,a,i8,a,i8,a,es11.4)', "! [D183] pdrIonRate slot", &
                         & iDum, ": nonzero in", nCv1, " of", grid(iG)%nCells, &
                         & " cells, mean |rate| ", wDum/max(nCv1,1)
                 end do
              end do
           end if
#endif

           ! ------------------------------------------------------- D-178
           ! Total content per species, the geometry-free analogue of Cloudy's
           ! column-density test. Every rank has the full reduced grid here, so
           ! this is a plain sum, no communication needed.
#ifdef PDR
           if (lgPDR .and. teProbe /= 0 .and. taskid == 0) then
              cvSpNow = 0.d0
              do iG = 1, nGrids
                 do iDum = 1, grid(iG)%nCells
                    wDum = dble(grid(iG)%Hden(iDum))
                    if (wDum <= 0.d0) cycle
                    cvSpNow(1) = cvSpNow(1) + wDum*dble(grid(iG)%ionDen(iDum,elementXref(1),1))
                    cvSpNow(2) = cvSpNow(2) + wDum*dble(grid(iG)%ionDen(iDum,elementXref(1),2))
                    if (allocated(grid(iG)%pdrAbun) .and. pdrIdxH2 > 0) then
                       cvSpNow(3) = cvSpNow(3) + wDum*grid(iG)%pdrAbun(iDum,pdrIdxH2)
                       cvSpNow(4) = cvSpNow(4) + wDum*grid(iG)%pdrAbun(iDum,pdrIdxCO)
                       cvSpNow(5) = cvSpNow(5) + wDum*grid(iG)%pdrAbun(iDum,pdrIdxCp)
                       cvSpNow(6) = cvSpNow(6) + wDum*grid(iG)%pdrAbun(iDum,pdrIdxC)
                    end if
                    cvSpNow(7) = cvSpNow(7) + dble(grid(iG)%Ne(iDum))
                    cvSpNow(8) = cvSpNow(8) + dble(grid(iG)%Te(iDum))
                 end do
              end do
              if (any(cvSpOld > 0.d0)) then
                 print*, "! CVSPEC  iteration-to-iteration change in total content:"
                 do iDum = 1, nCvSp
                    if (cvSpOld(iDum) > 0.d0) then
                       print '(a,a6,a,es11.4,a,f9.3,a)', "! CVSPEC   ", cvSpName(iDum), &
                            & "  total ", cvSpNow(iDum), "   change ", &
                            & 100.d0*(cvSpNow(iDum)-cvSpOld(iDum))/cvSpOld(iDum), " %"
                    end if
                 end do
              end if
              cvSpOld = cvSpNow
           end if
#endif

           ! ------------------------------------------------------- D-196
           ! CAN THE TESTED QUANTITY MOVE?
           !
           ! The model's convergence percentage is dominated by a test on
           ! x(H0) (D-155, D-179). ionBalance closes its matrix on a
           ! conservation row that reads sum(stages) = availFrac(elem), and
           ! D-118 sets availFrac to 1.0 wherever the chemistry supplied
           ! per-stage rates - which, after the first coupling pass, is every
           ! cell it touched. In those cells the row asserts
           !
           !     x(H0) + x(H+) = 1
           !
           ! in gas that may be 98% molecular, so x(H0) is pinned just below
           ! unity no matter what the chemistry does and |dx(H0)|/x(H0) has
           ! almost nothing to move it. A test on a quantity that cannot move
           ! passes for free (CLAUDE.md; D-176..D-181, and again at D-191).
           !
           ! Three numbers settle it, reported every iteration rather than
           ! behind a probe flag, because this is the measurement that says
           ! whether any other convergence number in the run means anything:
           !
           !   x(H0) spread      - pinned at ~1 in the molecular gas, or not
           !   |dx(H0)| spread   - what the test actually sees
           !   x(H+) ratio       - the ion solver's answer over the chemistry's
           !
           ! That last one is the non-tautological test, and it needs saying
           ! why the obvious one is not. pdrToMocassin runs AFTER updateCell in
           ! every coupling pass and writes
           !     ionDen(H0) = max(1 - ionDen(H+) - 2x(H2), 0)
           ! so x(H0) + 2x(H2) + x(H+) is 1 BY CONSTRUCTION here and departs
           ! from it only where that max() clamps. Reported, but as what it is
           ! - a clamp counter, which is the D-192 symptom (budget 1.28-1.64
           ! with ionDen(H0) pinned at exactly zero) and not an independent
           ! check of the budget.
           !
           ! ionDen(H+) is untouched by the handback under pdrIonFromMocassin
           ! (w = 0), so it is the ion solver's own answer, while pdrAbun(H+)
           ! is the chemistry's - both fractions per hydrogen NUCLEUS. Under
           ! pdrIonFromMocassin the chemistry is handed MOCASSIN's ratio and
           ! re-imposes it on its non-molecular total, so
           !
           !   x(H+)_chem = (1 - 2x(H2)) * ionDen(H+)/(ionDen(H0)+ionDen(H+))
           !
           ! If the conservation row normalises to the available fraction the
           ! denominator is 1 - 2x(H2) and the ratio is exactly 1. If it
           ! normalises to unity - the D-118 stand-down - the denominator is 1
           ! and the ratio is 1/(1 - 2x(H2)). So the ratio IS the defect: 1
           ! when the bookkeeping is right, rising without bound as the gas
           ! turns molecular when it is not.
           !
           ! Rank 0 only, on the fully reduced grid, so no communication.
#ifdef PDR
           if (lgPDR .and. taskid == 0 .and. nIterateMC >= pdrStartIter) then
              do iG = 1, nGrids
                 if (.not.allocated(grid(iG)%pdrZone)) cycle
                 allocate(cvBud(grid(iG)%nCells), cvXH0(grid(iG)%nCells), &
                      &   cvDlt(grid(iG)%nCells), cvRat(grid(iG)%nCells), &
                      &   cvMol(grid(iG)%nCells), cvDMl(grid(iG)%nCells), &
                      &   cvTe(grid(iG)%nCells), cvChi(grid(iG)%nCells), &
                      &   cvAv(grid(iG)%nCells), stat=err)
                 if (err /= 0) then
                    print*, "! iterateMC: can't allocate D-196 work arrays"; stop
                 end if
                 nBud = 0; nPin = 0; nBad = 0; nRat = 0; nZero = 0
                 avSum = 0.d0; h2Sum = 0.d0
                 molHist = 0; nMv10 = 0; nMv50 = 0; nWarm = 0; nHotBr = 0
                 molSum = 0.d0; teStSum = 0.d0; molStSum = 0.d0; nStHot = 0
                 do iDum = 1, grid(iG)%nCells
                    if (grid(iG)%pdrZone(iDum) /= 1) cycle
                    if (grid(iG)%Hden(iDum) <= 0.) cycle
                    nBud = nBud + 1
                    cvXH0(nBud) = dble(grid(iG)%ionDen(iDum,elementXref(1),1))
                    xHp         = dble(grid(iG)%ionDen(iDum,elementXref(1),2))
                    cvBud(nBud) = cvXH0(nBud) + xHp
                    if (allocated(grid(iG)%pdrAbun) .and. pdrIdxH2 > 0) then
                       cvBud(nBud) = cvBud(nBud) &
                            & + 2.d0*grid(iG)%pdrAbun(iDum,pdrIdxH2)
                       h2Sum = h2Sum + 2.d0*grid(iG)%pdrAbun(iDum,pdrIdxH2)
                    end if
                    cvDlt(nBud) = 0.d0
                    if (allocated(grid(iG)%xHIiterStart)) then
                       if (grid(iG)%xHIiterStart(iDum) > 0.) &
                            & cvDlt(nBud) = abs(cvXH0(nBud) &
                            & - dble(grid(iG)%xHIiterStart(iDum))) &
                            & / dble(grid(iG)%xHIiterStart(iDum))
                    end if
                    ! the ion solver's x(H+) over the chemistry's, both per
                    ! hydrogen nucleus - 1 if the conservation row normalised
                    ! to the available fraction, 1/(1-2x(H2)) if it did not
                    if (allocated(grid(iG)%pdrAbun) .and. pdrIdxHp > 0) then
                       xHpChem = grid(iG)%pdrAbun(iDum,pdrIdxHp)
                       if (xHpChem > 1.d-30 .and. xHp > 1.d-30) then
                          nRat = nRat + 1
                          cvRat(nRat) = xHp/xHpChem
                       end if
                    end if
                    if (cvXH0(nBud) > 0.99d0) nPin = nPin + 1
                    if (abs(cvBud(nBud)-1.d0) > 0.01d0) nBad = nBad + 1
                    if (cvXH0(nBud) <= 0.d0) nZero = nZero + 1
                    if (allocated(grid(iG)%elemAvail)) &
                         & avSum = avSum + dble(grid(iG)%elemAvail(iDum,1))
                    if (allocated(grid(iG)%TeIterStart)) then
                       teStSum = teStSum + dble(grid(iG)%TeIterStart(iDum))
                       if (grid(iG)%TeIterStart(iDum) > 3000.) nStHot = nStHot + 1
                    end if
                    ! ------------------------------------------- D-202
                    ! The D-200 census labelled each cell hot / cold / between
                    ! and counted changes of the HOT label. That instrument
                    ! read 0-1.8% straight through an iteration in which three
                    ! quarters of the grid moved, because the swing ran
                    ! between the cold and middle labels and never crossed the
                    ! hot threshold. A label whose transitions the motion
                    ! avoids reports a settled model on a moving one - the
                    ! same failure as a convergence test on a quantity that
                    ! cannot move (CLAUDE.md; D-176..D-181, D-191, D-196).
                    !
                    ! So report the molecular fraction itself: its whole
                    ! distribution over the PDR cells, and how far each cell
                    ! moved since the iteration started. No threshold decides
                    ! what counts as a change of state; the one count that
                    ! remains labelled (nHotBr) is kept only so the D-200 and
                    ! D-201 tables stay comparable.
                    !
                    ! f_mol = 2 x(H2) comes from H2den, which D-201 ties to
                    ! pdrAbun. If those two ever separate again, this line and
                    ! the mean 2x(H2) above are computed from opposite sides
                    ! of the split and will disagree - which is how D-201 was
                    ! caught in the first place.
                    fMol = 0.d0
                    if (allocated(grid(iG)%H2den)) &
                         & fMol = 2.d0*dble(grid(iG)%H2den(iDum)) &
                         &        /dble(grid(iG)%Hden(iDum))
                    cvMol(nBud) = fMol
                    cvTe(nBud)  = dble(grid(iG)%Te(iDum))
                    molSum      = molSum + fMol
                    cvChi(nBud) = 0.d0
                    if (allocated(grid(iG)%chiFUV)) &
                         & cvChi(nBud) = dble(grid(iG)%chiFUV(iDum))
                    cvAv(nBud) = 0.d0
                    if (allocated(grid(iG)%AVeff)) &
                         & cvAv(nBud) = dble(grid(iG)%AVeff(iDum))
                    if (grid(iG)%Te(iDum) > 3000.) nWarm = nWarm + 1
                    if (fMol < 0.01d0 .and. grid(iG)%Te(iDum) > 3000.) &
                         & nHotBr = nHotBr + 1
                    iBin = 1
                    if (fMol >= 0.01d0) iBin = 2
                    if (fMol >= 0.10d0) iBin = 3
                    if (fMol >= 0.30d0) iBin = 4
                    if (fMol >= 0.50d0) iBin = 5
                    if (fMol >= 0.70d0) iBin = 6
                    if (fMol >= 0.90d0) iBin = 7
                    if (fMol >= 0.99d0) iBin = 8
                    molHist(iBin) = molHist(iBin) + 1
                    cvDMl(nBud) = 0.d0
                    if (allocated(grid(iG)%xH2iterStart)) then
                       fMolWas     = 2.d0*dble(grid(iG)%xH2iterStart(iDum))
                       cvDMl(nBud) = abs(fMol - fMolWas)
                       molStSum    = molStSum + fMolWas
                       if (cvDMl(nBud) > 0.10d0) nMv10 = nMv10 + 1
                       if (cvDMl(nBud) > 0.50d0) nMv50 = nMv50 + 1
                    end if
                 end do
                 if (nBud > 0) then
                    call cvSortD(cvXH0, nBud)
                    call cvSortD(cvBud, nBud)
                    call cvSortD(cvDlt, nBud)
                    xMed = cvXH0((nBud+1)/2)
                    bMed = cvBud((nBud+1)/2)
                    dMed = cvDlt((nBud+1)/2)
                    bMin = cvBud(1); bMax = cvBud(nBud)
                    print*, "! [D196] can the convergence test move? grid", iG
                    print '(a,i8,a,i8,a,f6.2,a)', "! [D196]   PDR-zone cells", &
                         & nBud, ",  x(H0) > 0.99 in", nPin, "  (", &
                         & 100.d0*dble(nPin)/dble(nBud), " %)"
                    print '(a,3(es11.4,a))', "! [D196]   x(H0)      min ", &
                         & cvXH0(1), "  median ", xMed, "  max ", cvXH0(nBud)
                    print '(a,3(es11.4,a))', "! [D196]   |dx(H0)|/x median ", &
                         & dMed, "  p90 ", cvDlt(min(nBud,max(1,(9*nBud)/10))), &
                         & "  max ", cvDlt(nBud)
                    print '(a,3(es11.4,a))', "! [D196]   x(H0)+2x(H2)+x(H+)  min ", &
                         & bMin, "  median ", bMed, "  max ", bMax
                    ! D-199: this line used to be labelled a clamp counter,
                    ! and that was right only while pdrToMocassin wrote
                    ! ionDen(H0) = max(1 - x(H+) - 2x(H2), 0) - the budget was
                    ! then 1 by construction and could only depart from it
                    ! where that max() fired. D-193 removed the write, so the
                    ! budget is now an INDEPENDENT test, and what it reports
                    ! is hydrogen the sum does not account for: the network's
                    ! other carriers (H2O, OH, the CH_n chain, H3+) plus any
                    ! lag between elemAvail and the abundances it was built
                    ! from. D-199 measured the split - fixing the lag took the
                    ! count from 9670 cells to 29 - so it is mostly lag, and
                    ! the other carriers are well under 1%. A non-zero nZero IS
                    ! still the D-192 clamp.
                    print '(a,i8,a,i8,a)', &
                         & "! [D196]   off by >1% (H in other carriers, ~1.25%):", &
                         & nBad, " cells;", nZero, " with x(H0) exactly 0 (D-192 clamp)"
                    print '(a,f8.4,a,f8.4)', "! [D196]   mean 2x(H2) ", &
                         & h2Sum/dble(nBud), "   mean elemAvail(H) ", avSum/dble(nBud)
                    call cvSortD(cvMol, nBud)
                    call cvSortD(cvDMl, nBud)
                    call cvSortD(cvTe,  nBud)
                    print '(a)', " ! [D202]   f_mol = 2x(H2) distribution, % of PDR cells"
                    print '(a)', " ! [D202]      <.01  .01-.1   .1-.3   .3-.5&
                         &   .5-.7   .7-.9  .9-.99   >=.99"
                    print '(a,8f8.2)', " ! [D202]   ", &
                         & (100.d0*dble(molHist(iBin))/dble(nBud), iBin = 1, 8)
                    print '(a,4(f8.4,a))', " ! [D202]   f_mol      p10 ", &
                         & cvMol(max(1,nBud/10)), "  median ", cvMol((nBud+1)/2), &
                         & "  p90 ", cvMol(min(nBud,max(1,(9*nBud)/10))), &
                         & "  mean ", molSum/dble(nBud)
                    print '(a,3(f8.4,a))', &
                         & " ! [D202]   |df_mol| since iter start  median ", &
                         & cvDMl((nBud+1)/2), "  p90 ", &
                         & cvDMl(min(nBud,max(1,(9*nBud)/10))), "  max ", cvDMl(nBud)
                    print '(a,i7,a,f6.2,a,i7,a,f6.2,a)', &
                         & " ! [D202]   moved >0.10:", nMv10, " (", &
                         & 100.d0*dble(nMv10)/dble(nBud), "%)    >0.50:", nMv50, &
                         & " (", 100.d0*dble(nMv50)/dble(nBud), "%)"
                    print '(a,3(es11.4,a))', " ! [D202]   Te         p10 ", &
                         & cvTe(max(1,nBud/10)), "  median ", cvTe((nBud+1)/2), &
                         & "  p90 ", cvTe(min(nBud,max(1,(9*nBud)/10)))
                    print '(a,i7,a,f6.2,a,i7,a,f6.2,a)', &
                         & " ! [D202]   Te > 3000 K:", nWarm, " (", &
                         & 100.d0*dble(nWarm)/dble(nBud), &
                         & "%)    and f_mol<.01 (the D-200 'hot' label):", nHotBr, &
                         & " (", 100.d0*dble(nHotBr)/dble(nBud), "%)"
                    ! D-204. The same two numbers at the START of the
                    ! iteration, over the same cells, so the pass-1 line above
                    ! and the end-of-iteration line below make a three-point
                    ! series: start -> thermal balance only -> chemistry too.
                    print '(a,es11.4,a,i7,a,f6.2,a)', &
                         & " ! [D204]   iteration start, for comparison:      &
                         &  mean Te ", teStSum/dble(nBud), &
                         & "  Te>3000 K in", nStHot, " (", &
                         & 100.d0*dble(nStHot)/dble(nBud), "%)"
                    print '(a,f8.4,a,f8.4)', &
                         & " ! [D204]   mean f_mol at iteration start ", &
                         & molStSum/dble(nBud), "   now ", molSum/dble(nBud)
                    ! D-203. f_mol is the chemistry's ANSWER; chi and A_V are
                    ! most of its input. Printed on the same line every
                    ! iteration so the two time series can be read against
                    ! each other: a collapse in f_mol with chi and A_V steady
                    ! is internal to the chemistry-thermal loop, and one that
                    ! follows a jump in chi is the radiative transfer's.
                    call cvSortD(cvChi, nBud)
                    call cvSortD(cvAv,  nBud)
                    print '(a,3(es11.4,a))', " ! [D203]   chiFUV     p10 ", &
                         & cvChi(max(1,nBud/10)), "  median ", cvChi((nBud+1)/2), &
                         & "  p90 ", cvChi(min(nBud,max(1,(9*nBud)/10)))
                    print '(a,3(es11.4,a))', " ! [D203]   AVeff      p10 ", &
                         & cvAv(max(1,nBud/10)), "  median ", cvAv((nBud+1)/2), &
                         & "  p90 ", cvAv(min(nBud,max(1,(9*nBud)/10)))
                    if (nRat > 0) then
                       call cvSortD(cvRat, nRat)
                       print '(a,3(es11.4,a),i8)', &
                            & "! [D196]   x(H+)_ion / x(H+)_chem  median ", &
                            & cvRat((nRat+1)/2), "  p90 ", &
                            & cvRat(min(nRat,max(1,(9*nRat)/10))), "  max ", &
                            & cvRat(nRat), "   over cells ", nRat
                       print*, "! [D196]   1.0 = row used the available fraction;", &
                            & " 1/(1-2x(H2)) = it normalised to unity"
                    end if
                 end if
                 deallocate(cvBud, cvXH0, cvDlt, cvRat, cvMol, cvDMl, cvTe, &
                      &      cvChi, cvAv)
              end do
           end if
#endif

           ! decide over final convergence of the model

           ! reinitialize convPercent and totCells
           totPercent  = 0.

           ! calculate the percentage of converged cells
           do iG = 1, nGrids

              totCells    = 0.
              convPercent = 0.

              if (ig>1 .or. (.not.lg2D)) then
                 yTop = grid(iG)%ny
              else if (iG ==1 .and. lg2D) then
                 yTop = 1
              end if

              do i = 1, grid(iG)%nx
                 do j = 1, yTop
                    do k = 1, grid(iG)%nz
                       if (grid(iG)%active(i,j,k)>0)  then
                          if (.not.lgEcho) then
                             convPercent = convPercent + grid(iG)%lgConverged(grid(iG)%active(i,j,k))
                             totCells    = totCells + 1.
                          else ! if light echo then only count echo cells!
                             if (grid(iG)%echoVol(i,j,k).gt.0.0) then
                                convPercent = convPercent + grid(iG)%lgConverged(grid(iG)%active(i,j,k))
                                totCells    = totCells + 1.
                             end if
                          endif
                       end if
                    end do
                 end do
              end do

              if (totCells .gt. 0) then
                convPercent               = 100.*convPercent / totCells
                noHitPercent              = 100.*noHitPercent(iG) / totCells
                grid(iG)%noIonBal         = 100.*noIonBalPercent(iG) / totCells
                grid(iG)%noTeBal          = 100.*noTeBalPercent(iG) / totCells
              else
                print *,"! iterationMC: no active cells in grid ",iG
                convPercent               = 0
                noHitPercent              = 0
                grid(iG)%noIonBal         = 0
                grid(iG)%noTeBal          = 0
              endif

              totPercent = totPercent + convPercent*grid(iG)%nCells/100.

              if (taskid == 0) then
                 if (nIterateMC == 1) then
                    close(21)
                    open(unit=21, status='unknown', position='rewind', file='output/summary.out', iostat=ios)
                    if (ios /= 0) then
                       print*, "! iterationMC: can't open file for writing, output/summary.out -1"
                       stop
                    end if
                 else
                    close(21)
                    open(unit=21, status='unknown', position='append', file='output/summary.out', iostat=ios)
                    if (ios /= 0) then
                       print*, "! iterationMC: can't open file for writing, output/summary.out -2"
                       stop
                    end if
                 end if

                 print*, "! iterateMC: [Summary] Iteration ",nIterateMC,'; ', &
                      &int(convPercent),"% converged cells in grid ", iG
                 print*, "! iterateMC: [Summary] Iteration ",nIterateMC,'; ', &
                      &int(noHitPercent(iG)),"% no hit cells in grid ", iG
                 print*, "! iterateMC: [Summary] Iteration ",nIterateMC,'; ', &
                      &int(grid(iG)%noIonBal),"% Ion balance not reached in grid ", iG
                 print*, "! iterateMC: [Summary] Iteration ",nIterateMC,'; ', &
                      &int(grid(iG)%noTeBal),"% Te balance not reached in grid", iG
#ifdef PDR
                 ! D-093: a non-zero count means the PDR's grain heating terms
                 ! exceeded what MOCASSIN's grains absorbed in those cells, and
                 ! the loss was capped to keep the dust balance solvable.
                 if (lgPDR .and. nDustCapped > 0) &
                      & print*, "! iterateMC: [Summary] Iteration ",nIterateMC,'; ', &
                      & nDustCapped," grain energy-budget caps hit"
                 nDustCapped = 0
#endif
                 write(21,*) "! iterateMC: [Summary] Iteration ",nIterateMC,'; ', &
                      &int(convPercent),"% converged cells in grid ", iG
                 write(21,*) "! iterateMC: [Summary] Iteration ",nIterateMC,'; ', &
                      &int(noHitPercent(iG)),"% no hit cells in grid ", iG
                 write(21,*) "! iterateMC: [Summary] Iteration ",nIterateMC,'; ', &
                      &int(grid(iG)%noIonBal),"% Ion balance not reached in grid ", iG
                 write(21,*) "! iterateMC: [Summary] Iteration ",nIterateMC,'; ', &
                      &int(grid(iG)%noTeBal),"% Te balance not reached in grid", iG
                 if (lgGas .and. convPercent>=resLinesTransfer .and. .not.lgResLinesFirst .and. &
                      & (.not. nIterateMC==1) ) then
                    write(21,*) "! iterateMC: [Summary] Iteration ",nIterateMC,'; '
                    write(21,*) "Dust Budgets: "
                    do icomp = 0, nAbComponents
                       write(21,*) " Component ", icomp
                       totheatdust = 0.
                       do icontrib =0, nResLines
                          totheatdust = totheatdust+dustHeatingBudget(icomp,icontrib)
                       end do
                       do icontrib =0, nResLines
                          write(21,*) " Contribution", icontrib, dustHeatingBudget(icomp,icontrib)/&
                               & totheatdust
                       end do
                    end do
                 end if
              end if

           end do

           if (lgDust .and. convPercent>=resLinesTransfer .and. lgGas .and. &
                & (.not. nIterateMC==1) .and. (.not.lgResLinesFirst)) dustHeatingBudget = 0.

           totCells = 0
           do iG =1,nGrids
              totCells = totCells+grid(iG)%nCells
           end do

           totPercent      = 100.*totPercent / totCells

           ! -------------------------------------------------------- D-165
           ! Report what the temperature solver did this iteration, summed over
           ! ranks. The bracket-width histogram is the point: Cloudy declares Te
           ! converged only when the bracket is narrow relative to Te as well as
           ! |H-C|/H being small, because a shallow thermostat lets the residual
           ! test pass at a temperature that is not determined.
           if (teProbe /= 0) then
              call mpi_reduce(teN, teNsum(1), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(teNconv, teNsum(2), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(teNstall, teNsum(3), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(teNloclamp, teNsum(4), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(teNhiclamp, teNsum(5), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(teNsteps, teNsum(6), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(teNwide, teNsum(7), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(teNnobrack, teNsum(8), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(teBrkHist, teBrkSum, teNbin, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(teNflat, teNsum2(1), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(teNflatClamp, teNsum2(2), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(nCoolNull, teNsum2(3), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(teNhiNoPdr, teNsum2(4), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvN,          cvS(1), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvFail,       cvS(2), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvFailSmallX, cvS(3), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvPassGated,  cvS(4), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvHist,     cvHS, 12, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvFailByX,  cvXS,  9, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvFailByAV, cvAS,  7, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvNear,     cvS2(1), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvFar,      cvS2(2), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvUnstable, cvS2(3), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvDeriv,    cvS2(4), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvStayHot,  cvS3(1), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvStayCold, cvS3(2), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvHot2Cold, cvS3(3), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvCold2Hot, cvS3(4), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvPdrCleared, cvS4, 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvFailH0,   cvS5(1), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvFailH2,   cvS5(2), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvFailBoth, cvS5(3), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              ! D-229/D-230: the temperature test was added to lgConverged but
              ! not to this report, so at D-230's iteration 6 the line named 313
              ! failures out of ~14900 unconverged cells. cvFailTe counts every
              ! cell that failed on Te, exclusively or not.
              call mpi_reduce(cvFailTe,   cvS5(4), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              ! D-248: the Te test statistic's distribution, and the cells the
              ! floor is holding still.
              call mpi_reduce(cvTeHist,     cvTS, 12, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvFailTeByAV, cvTAS, 7, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvTeNear,      cvS6(1), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvTeFloorPass, cvS6(2), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              call mpi_reduce(cvTeFloorN,    cvS6(3), 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
              if (taskid == 0 .and. teNsum(1) > 0) then
                 print*, "! TEPROBE iter", nIterateMC, " calls", teNsum(1), &
                      & " conv", teNsum(2), " (", 100.*real(teNsum(2))/real(teNsum(1)), "%)"
                 print*, "! TEPROBE   mean steps", real(teNsum(6))/real(teNsum(1)), &
                      & " stalled", teNsum(3), " loclamp", teNsum(4), " hiclamp", teNsum(5)
                 print*, "! TEPROBE   no bracket", teNsum(8), &
                      & " bracket wider than thLimit/3", teNsum(7), &
                      & " (", 100.*real(teNsum(7))/real(teNsum(1)), "%)"
                 print*, "! TEPROBE   log10(bracket/Te) histogram -6..+5:", teBrkSum
                 print*, "! TEPROBE   flat residual (<1% over the scan)", teNsum2(1), &
                      & " of which clamped", teNsum2(2)
                 print*, "! TEPROBE   D-167 atomic coolant with no PDR replacement", teNsum2(3)
                 print*, "! TEPROBE   D-168 of the ceiling clamps, no PDR coolant yet:", teNsum2(4)
                 if (cvS(1) > 0) then
                    print*, "! CVPROBE  cells", cvS(1), " failing", cvS(2), &
                         & " (", 100.*real(cvS(2))/real(cvS(1)), "%)"
                    print*, "! CVPROBE   log10|dx/x| histogram -8..+3:", cvHS
                    print*, "! CVPROBE   failures by log10 x(H0) -8..0:", cvXS
                    print*, "! CVPROBE   failures by A_V <.1 <.5 <1 <2 <4 >4:", cvAS(1:6)
                    print*, "! CVPROBE   failures with x(H0)<1e-3:", cvS(3), &
                         & "  would pass Cloudy-shaped gate (20% or x<1e-3):", &
                         & 100.*real(cvS(4))/real(cvS(1)), "%"
                    print*, "! CVPROBE   of the failures:", cvS2(1), &
                         & "within 2x tolerance,", cvS2(2), "moving >100%"
                    if (cvS2(4) > 0) print*, "! CVPROBE   thermally unstable ", &
                         & "d(H-C)/dT > 0 at solution:", cvS2(3), " of", cvS2(4), &
                         & " (", 100.*real(cvS2(3))/real(cvS2(4)), "%)"
                    ! ------------------------------------------------ D-172
                    ! Name the dominant reason, as Cloudy's chNotConverged
                    ! does. A bare percentage has been the whole of this
                    ! code's convergence reporting, and every argument about
                    ! convergence in the log has been an argument about a
                    ! scalar with no attribution.
                    if (cvS5(1)+cvS5(2)+cvS5(3)+cvS5(4) > 0) then
                       print*, "! CVPROBE   which test failed: x(H0) only", cvS5(1), &
                            & "  x(H2) only", cvS5(2), "  both", cvS5(3), &
                            & "  Te (any)", cvS5(4)
                    end if
                    ! -------------------------------------------------- D-248
                    ! The Te statistic's own distribution. The verdict line
                    ! above says how many cells fail; this says whether they
                    ! are moving or merely noisy, and how many pass only
                    ! because the floor is holding them still.
                    if (sum(cvTS) > 0) then
                       print*, "! CVPROBE   log10|dTe/Te| histogram -8..+3:", cvTS
                       print*, "! CVPROBE   Te failures by A_V <.1 <.5 <1 <2 <4 >4:", cvTAS(1:6)
                       print*, "! CVPROBE   Te failures within 2x tolerance:", cvS6(1), &
                            & "  at teFloor:", cvS6(3), " of which PASSING for free:", cvS6(2)
                    end if
                    if (cvS3(1)+cvS3(2)+cvS3(3)+cvS3(4) > 0) then
                       print*, "! CVPROBE   branch vs last iteration (split", &
                            & cvTsplit, "K): stayed hot", cvS3(1), " stayed cold", cvS3(2), &
                            & "  HOT->COLD", cvS3(3), "  COLD->HOT", cvS3(4), &
                            & "  flipped", 100.*real(cvS3(3)+cvS3(4))/ &
                            & real(cvS3(1)+cvS3(2)+cvS3(3)+cvS3(4)), "%"
                    end if
                    if (cvS(2) > 0) then
                       if (cvS2(3)*2 > cvS2(4) .and. cvS2(4) > 0) then
                          chNotConv = "thermally unstable solution (d(H-C)/dT > 0)"
                       else if (cvS(3)*2 > cvS(2)) then
                          chNotConv = "x(H0) too small to matter (< 1e-3); relative test is MC noise"
                       else if (cvS2(2)*2 > cvS(2)) then
                          chNotConv = "x(H0) moving >100% per iteration; model genuinely not settling"
                       else if (cvS2(1)*2 > cvS(2)) then
                          chNotConv = "just outside XHILimit; tolerance may be below the MC noise floor"
                       else if (maxval(cvAS(1:6)) == cvAS(4) .or. maxval(cvAS(1:6)) == cvAS(5)) then
                          chNotConv = "concentrated at A_V 1-4, the H/H2 transition"
                       else
                          chNotConv = "spread across depth, no single dominant band"
                       end if
                       print*, "! CVPROBE   NOT CONVERGED: ", trim(chNotConv)
                    end if
                    ! D-176: the OTHER test. pdrStep clears lgConverged after
                    ! updateCell has set it, so this is what actually decides
                    ! the headline number whenever it is large.
                    if (cvS4 > 0) then
                       print*, "! CVPROBE   PDR heat/cool test cleared", cvS4, &
                            & " cells that had passed the x(H0) test", &
                            & " (pdrFcritConv", pdrFcritConv, ")"
                    end if
                 end if
              end if
              teN = 0; teNconv = 0; teNstall = 0; teNloclamp = 0
              teNhiclamp = 0; teNsteps = 0; teNwide = 0; teNnobrack = 0
              teNflat = 0; teNflatClamp = 0; nCoolNull = 0; teNhiNoPdr = 0
              cvN = 0; cvFail = 0; cvFailSmallX = 0; cvPassGated = 0
              cvHist = 0; cvFailByX = 0; cvFailByAV = 0
              cvNear = 0; cvFar = 0; cvUnstable = 0; cvDeriv = 0
              cvStayHot = 0; cvStayCold = 0; cvHot2Cold = 0; cvCold2Hot = 0
              cvPdrCleared = 0
              cvFailH0 = 0; cvFailH2 = 0; cvFailBoth = 0; cvFailTe = 0   ! D-229
              cvTeHist = 0; cvFailTeByAV = 0                             ! D-248
              cvTeNear = 0; cvTeFloorPass = 0; cvTeFloorN = 0            ! D-248
              teBrkHist = 0
           end if

           ! ------------------------------------------------------- D-239
           ! What the packet weights did this iteration. Reduced here, once per
           ! iteration, rather than beside the budSum census - that sits inside
           ! the coupling and grid loops and would zero these mid-transport.
           if (lgPathStretch) then
              call mpi_allreduce(MPI_IN_PLACE, wgtN239,   1, mpi_double_precision, &
                   & mpi_sum, mpi_comm_world, ierr)
              call mpi_allreduce(MPI_IN_PLACE, wgtSum239, 1, mpi_double_precision, &
                   & mpi_sum, mpi_comm_world, ierr)
              call mpi_allreduce(MPI_IN_PLACE, wgtLogS239,1, mpi_double_precision, &
                   & mpi_sum, mpi_comm_world, ierr)
              call mpi_allreduce(MPI_IN_PLACE, wgtKill239,1, mpi_double_precision, &
                   & mpi_sum, mpi_comm_world, ierr)
              call mpi_allreduce(MPI_IN_PLACE, wgtSurv239,1, mpi_double_precision, &
                   & mpi_sum, mpi_comm_world, ierr)
              call mpi_allreduce(MPI_IN_PLACE, wgtMin239, 1, mpi_double_precision, &
                   & mpi_min, mpi_comm_world, ierr)
              call mpi_allreduce(MPI_IN_PLACE, wgtMax239, 1, mpi_double_precision, &
                   & mpi_max, mpi_comm_world, ierr)
              if (taskid == 0 .and. wgtN239 > 0.d0) &
                   & print '(a,es10.3,a,es10.3,a,f7.2,a,es10.3,a,es11.4,a,es10.3)', &
                   & " ! [D239]   weight min", wgtMin239, "  max", wgtMax239, &
                   & "  mean log10", wgtLogS239/wgtN239, &
                   & "  mean", wgtSum239/wgtN239, &
                   & "  draws", wgtN239, "  roulette killed", wgtKill239
              wgtMin239 = 1.d99; wgtMax239 = 0.d0; wgtSum239 = 0.d0
              wgtLogS239 = 0.d0; wgtN239 = 0.d0
              wgtKill239 = 0.d0; wgtSurv239 = 0.d0
           end if

           if (taskid==0) then
              print*, "! iterateMC: [Summary] Iteration ",nIterateMC,'; Total:  ', &
                   &totPercent,"% converged cells over all grids"
              print*, "! iterateMC: [Summary] Iteration ",nIterateMC,'; ', &
                   &nPhotons, " energy packets used"
              write(21, *) "! iterateMC: [Summary] Iteration ",nIterateMC,'; Total:  ', &
                   &totPercent,"% converged cells over all grids"
              write(21,*) "! iterateMC: [Summary] Iteration ",nIterateMC,'; ', &
                   &nPhotons, " energy packets used"
              call date_and_time(TIME=time)
              write(21,*) "! iterateMC: [Summary] Iteration ",nIterateMC,"; finished at ",time(1:2),":",time(3:4),":",time(5:6)
              write(21,*) ""
              close(21)

              ! write grid to files for warm start

              if ( totPercent >= convWriteGrid) then

                 ! write old grid to disk
                 call writeGrid(grid(1:nGrids))

              end if

           end if

           nPhotonsTot = nPhotons(1)
           do iStar=1, nStars
              nPhotonsTot = nPhotonsTot+nPhotons(iStar)
           end do

           if (nIterateMC > 1 .and. totPercent < 95. .and. lgAutoPackets &
                & .and. nPhotonsTot < maxPhotons .and. totPercentOld > 0.) then

              if ( (totPercent-totPercentOld)/totPercentOld <= convIncPercent ) then
                 nPhotons = nint(nPhotons*nPhotIncrease,kind=int64)
                 deltaE   = deltaE/nPhotIncrease

                 if (taskid==0) &
                      & print*, "! iterateMC: [talk] Total number of energy packets &
                      &increased to ", nPhotons

                 if (Ldiffuse>0.) then
                    nPhotonsDiffuseLoc = nint(nPhotonsDiffuseLoc*nPhotIncrease)
                    if (taskid==0) &
                         & print*, "! iterateMC: [talk] number of diffuse energy packets &
                         &per cell increased to ", nPhotonsDiffuseLoc
                 end if

              end if
           end if


!           if (Ldiffuse>0. .and. nIterateMC > 1 .and. totPercent < 95. .and. lgAutoPackets &
!                &  .and. totPercentOld > 0.) then
!
!              if ( (totPercent-totPercentOld)/totPercentOld <= convIncPercent ) then
!                 nPhotonsDiffuseLoc = nPhotonsDiffuseLoc*nPhotIncrease
!
!                 if (taskid==0) &
!                      & print*, "! iterateMC: [talk] number of diffuse energy packets &
!                      &per cell increased to ", nPhotonsDiffuseLoc
!              end if
!
!           end if


           totPercentOld = totPercent

           if (taskid==0) then
              print *,"! iterateMC: [Summary] Iteration ",nIterateMC,"; finished at ",time(1:2),":",time(3:4),":",time(5:6)
           endif

           ! D-062: a warm-up must not let the pre-PDR solution END the run.
           ! Without this, `pdrStartIter 4` on a slab that converges in 3 stops
           ! before the chemistry has run once - measured: 100% converged at
           ! iteration 3, zero pdrStep calls, every cell still zone 0. Hold the
           ! run open until the PDR has been enabled and has had one pass.
#ifdef PDR
           if ( totPercent >= minConvergence .and. &
              & (.not.lgPDR .or. nIterateMC > pdrStartIter) ) then
#else
           if ( totPercent >= minConvergence ) then
#endif

              if (taskid==0) then
                 print*, "! iterateMC: [talk] convergence reached after ", &
                      &                           nIterateMC, " iterations. & Finishing up ... "

                 ! output results at this itearation stage (every 3 iterations)

#ifdef PDR
                 ! NOT re-running mocassinToPDR here. It already ran this
                 ! iteration, before the cell loops, on the same radiation
                 ! field - nothing has changed since. Running it again would
                 ! recompute pdrZone AFTER the last pdrStep, so any cell that
                 ! had just crossed the x(H+) threshold would be written to the
                 ! checkpoint labelled "PDR zone" while still holding its seed
                 ! abundances, indistinguishable from a converged result.
#endif
                 call writeGrid(grid(1:nGrids))
#ifdef PDR
                 call writeFUVField(grid(1:nGrids))
#endif
                 if (lgGas) call outputGas(grid(1:nGrids))
              end if

              call mpi_barrier(mpi_comm_world, ierr)

           else if (nIterateMC >= maxIterateMC) then

              if (taskid==0) then

                 print*, " ! iterateMC: maximum number of iterations reached. Finishing up ... ",&
                      & maxIterateMC

#ifdef PDR
                 ! NOT re-running mocassinToPDR here. It already ran this
                 ! iteration, before the cell loops, on the same radiation
                 ! field - nothing has changed since. Running it again would
                 ! recompute pdrZone AFTER the last pdrStep, so any cell that
                 ! had just crossed the x(H+) threshold would be written to the
                 ! checkpoint labelled "PDR zone" while still holding its seed
                 ! abundances, indistinguishable from a converged result.
#endif
                 call writeGrid(grid(1:nGrids))
#ifdef PDR
                 call writeFUVField(grid(1:nGrids))
#endif
                 if (lgGas) call outputGas(grid(1:nGrids))
              end if

              call mpi_barrier(mpi_comm_world, ierr)

           else

              if (lgOutput .and. taskid == 0 ) then
                 ! output results at this itearation stage (every ? iterations)
                 if ( mod(nIterateMC, 1) == 0 ) then
                    if (lgGas) call outputGas(grid(1:nGrids))
                 end if
              end if

              call mpi_barrier(mpi_comm_world, ierr)

              ! step up MC iterations counter
              nIterateMC = nIterateMC + 1

              if (lgTalk) print*, "! iterateMC: [talk] now starting iteration #",&
                   &                            nIterateMC

              ! start the next iteration

              call iterateMC()
              return

           end if

         end subroutine iterateMC

         ! ------------------------------------------------------- D-196
         ! In-place ascending sort, used only to take medians and percentiles
         ! of a per-cell distribution on rank 0. Heapsort: the array is in cell
         ! order, not value order, so this is n log n on ~30k elements rather
         ! than the n^2 an insertion sort would pay here. Non-recursive and
         ! allocation-free, so it costs nothing to call every iteration.
         subroutine cvSortD(a, n)
           implicit none
           real(kind=8), intent(inout) :: a(:)
           integer, intent(in)         :: n
           integer                     :: i, ir, j, l
           real(kind=8)                :: v

           if (n < 2) return
           l  = n/2 + 1
           ir = n
           do
              if (l > 1) then
                 l = l - 1
                 v = a(l)
              else
                 v     = a(ir)
                 a(ir) = a(1)
                 ir    = ir - 1
                 if (ir == 1) then
                    a(1) = v
                    return
                 end if
              end if
              i = l
              j = l + l
              do while (j <= ir)
                 if (j < ir) then
                    if (a(j) < a(j+1)) j = j + 1
                 end if
                 if (v >= a(j)) exit
                 a(i) = a(j)
                 i    = j
                 j    = j + j
              end do
              a(i) = v
           end do
         end subroutine cvSortD

       end subroutine MCIterationDriver

 end module iteration_mod
