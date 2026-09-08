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
           integer(kind=8)        :: cvS5(3)                             ! D-179
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

              if (lgDust .and. .not.lgGas) then
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

              if (lgDust .and. .not.lgGas) then
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

                 if (lgDebug) then
                    size =  (grid(iG)%nCells+1)*nLines

                    call mpi_allreduce(grid(iG)%linePDF, linePDFTemp, size,&
                         & mpi_real, mpi_sum, mpi_comm_world, ierr)
                 end if
              end if

              if (lgDust .and. .not.lgGas) then

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
                             if (lgDebug) then
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
                 if ( allocated(JDifTemp) )           deallocate(JDifTemp)
              end if
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
              call mocassinToPDR(grid(1:nGrids))
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


              ! D-119: close the ionization <-> chemistry loop inside one MC
              ! iteration. Until now they ran once each in sequence, so the
              ! loop closed only across MC iterations - the chemistry saw last
              ! iteration's ionization and vice versa. Cloudy iterates them to
              ! a joint solution within a zone (conv_base) with damping and
              ! oscillation detection.
              !
              ! The count is FIXED, not convergence-tested, on purpose: every
              ! rank must execute the same number of passes or the MPI
              ! collectives inside deadlock. Convergence is measured and
              ! reported instead, and the operator chooses the count.
              do iCouple = 1, max(pdrCoupleIter, 1)
#ifdef PDR
              if (lgPDR .and. nIterateMC >= pdrStartIter .and. iCouple > 1) then
                 ! remember the ionization this pass starts from, so the change
                 ! across the pass can be measured and damped
                 if (allocated(ionDenPrev)) ionDenPrev = grid(iG)%ionDen
              end if
#endif

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
              end if
#endif

#ifdef PDR
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
              ! AFTER the Te exchange, not before: that allreduce overwrites
              ! grid%Te wholesale from TeTemp, so a handover written earlier
              ! would be silently discarded.
              if (lgPDR .and. nIterateMC >= pdrStartIter) &
                   & call pdrToMocassin(grid(1:nGrids))
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
                    if (cvS5(1)+cvS5(2)+cvS5(3) > 0) then
                       print*, "! CVPROBE   which test failed: x(H0) only", cvS5(1), &
                            & "  x(H2) only", cvS5(2), "  both", cvS5(3)
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
              cvFailH0 = 0; cvFailH2 = 0; cvFailBoth = 0
              teBrkHist = 0
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

       end subroutine MCIterationDriver

 end module iteration_mod
