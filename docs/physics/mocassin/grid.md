(sec:moc-grid)=
# The grid: frequencies, cells and geometry

MOCASSIN describes a model on a Cartesian grid of homogeneous cells: each cell has one gas density, one dust density and one composition and, once the iteration has run, one radiation field, one ionisation state and one temperature {cite:p}`Ercolano2003,Ercolano2005`. This page describes how the grid is built: the frequency grid that every cell shares, the axes and walls of the cells, which cells are active, how densities and abundances are assigned, and the geometries the code offers on top of a plain cube (the octant of `symmetricXYZ`, nested sub-grids, the 2D mode and plane-parallel illumination). All of it is done once, at start-up, by {src}`grid_mod.f90::initCartesianGrid` and {src}`grid_mod.f90::fillGrid`; {numref}`tab:moc-startup` places them in the start-up chain. Each section opens with the feature's status in this project ({doc}`index` gives the legend). Lengths are in cm, frequencies in Ryd, densities in cm$^{-3}$.

(sec:moc-freq)=
## The frequency grid
{bdg-success}`used`

The frequency grid `nuArray` is built on the first call of `initCartesianGrid` and serves every grid, cell and iteration. It has `nbins` points (default 600, {src}`set_input_mod.f90::readInput@"nbins = 600"`) between `nuMin` and `nuMax` (defaults $1.001\times10^{-5}$ and 15 Ryd). What goes into it depends on the model's content.

**Gas only** (the Lexington models): a point at 4.9 GHz if `nuMin` lies below it; the 17 fixed edges of `seriesEdge`, all below 0.3 Ryd (the H I series limits of $n=2$ to 12 and six further thresholds); and the threshold of every ion stage present, from H I at 0.999434 Ryd, He I at 1.80804 and He II at 4 Ryd, and for the heavy elements the threshold of the outer shell in the shell data `ph1` (`getOuterShell`, {src}`grid_mod.f90::initCartesianGrid@"! find the ionization edges included in our frequency range"`; {doc}`ionisation`), as long as it lies below `nuMax`. Every edge gets two companion points 0.0003 Ryd below and above it. The remaining $n_{\log}$ points are spaced logarithmically from `nuMin` (lowered to 0.0006 Ryd below any edge that lies under it) to `nuMax`, and the whole set is sorted ({src}`code <grid_mod.f90::initCartesianGrid@"else if (lgGas .and. (.not.lgDust)) then">`):

$$
\nu_{i+1}=\nu_i\,10^{\delta},\qquad \delta=\frac{\log_{10}\nu_{\max}-\log_{10}\nu_{\min}}{n_{\log}-1}.
$$ (eq:moc-logmesh)

**Dust only** (the 1D dust shells): the points of `dustData/nuDustRyd.dat`, read up to the first above `nuMax`, and `nbins` is reset to their number; the run stops if the file has more points than `nbins`+1 ({src}`code <grid_mod.f90::initCartesianGrid@"if ( (lgDust) .and. (.not.lgGas) ) then"+38>`). `nuMin` is ignored: the grid starts at the file's first point, $1.3\times10^{-6}$ Ryd ({lim}`L-70`).

**Dust and gas** (the PDR fixtures, `test_Problem`): the gas edges, then the points of `nuDustRyd.dat` up to the gas grid's lowest series edge, then the logarithmic fill ({src}`code <grid_mod.f90::initCartesianGrid@"else if (lgDust .and. lgGas) then"..@"call sortUp(nuArray)">`). The loop that reads the file tests an earlier gas point, `nuArray(i)`, instead of the point just read, so with the default `nuMin` it stops after the first value, an orphan point at $1.3\times10^{-6}$ Ryd ({src}`the exit test <grid_mod.f90::initCartesianGrid@"if (nuArray(i)>= seriesEdge(1)) exit">`, {lim}`L-70`), and with `nuMin` below the 4.9 GHz point, as in `test_Problem` and the tutorial ($1.001\times10^{-6}$ Ryd), after the second; the logarithmic fill still samples the infrared more finely than the file would.

The grid is a set of points. Each gets a width by central differences ({src}`grid_mod.f90::initCartesianGrid@"widFlx(1) = nuArray(2)-nuArray(1)"`),

$$
\Delta\nu_1=\nu_2-\nu_1,\qquad \Delta\nu_k=\tfrac12(\nu_{k+1}-\nu_{k-1}),\qquad \Delta\nu_{N}=\nu_N-\nu_{N-1},
$$ (eq:moc-widflx)

so that a sum $\sum_k f_k\,\Delta\nu_k$ stands for an integral over frequency, and a bin $k$ is the interval between the midpoints that surround $\nu_k$. The Lyman limit, the 4.9 GHz point and, in a PDR build, the FUV band are located on this grid once ({src}`continuum_mod.f90::setContinuum@"call locate(nuArray, 1., lymanP)"`, {ref}`sec:bands`).

(sec:moc-cells)=
## Axes, cells and walls
{bdg-success}`used`

A grid has $n_x\times n_y\times n_z$ points (`nx`, `ny`, `nz`, default 30 each). Without a density file the axes come from `edges` $R_x\,R_y\,R_z$: with `symmetricXYZ` they run from 0 to $R$, $x_i=R\,(i-1)/(n-1)$; otherwise from $-R$ to $R$, $x_i=R\,[2(i-1)/(n-1)-1]$, and $n$ must be odd so that a point lies at the centre ({src}`code <grid_mod.f90::fillGrid@"if (mod(grid(1)%nx,2) == 0.) then">`). With a `densityFile` or an `Ndust` file the axes are read from the file's first three columns, one line per point with $x$ outermost and $z$ innermost, and `edges` is ignored with a warning; a first line starting with `#` gives $n_x\,n_y\,n_z$ ({src}`set_input_mod.f90::readInput@"case (\"densityFile\")"`). An `MdMg` or `MdMh` file can give the counts the same way but its coordinate columns are skipped.

A cell is centred on its axis point, and the wall between two cells lies midway between their axis points; the transport measures every step to these walls ({ref}`sec:moc-path`). The grid ends at the outermost axis points: a packet in an edge cell moving outwards has that cell's own axis point as its far wall, and crossing it leaves the grid ({src}`code <photon_mod.f90::energyPacketDriver/pathSegment@"dSx = ( grid(gP)%xAxis(grid(gP)%nx)-rVec%x)/vHat%x">`). The volume of a cell is ({src}`grid_mod.f90::getVolume`)

$$
V_{ijk}=\Delta x_i\,\Delta y_j\,\Delta z_k,\qquad
\Delta x_i=\tfrac12(x_{i+1}-x_{i-1}),\qquad
\Delta x_1=\frac{x_2-x_1}{f},\quad \Delta x_n=\frac{x_n-x_{n-1}}{f},
$$ (eq:moc-volume)

in units of $10^{45}$ cm$^3$, with $f=2$ under `symmetricXYZ` and $f=1$ otherwise. With `symmetricXYZ` the edge cells are therefore half-cells on both sides, as the transport sees them. Without it `getVolume` gives each edge cell a full spacing, of which packets cross only the inner half, so the estimator there is low by a factor of 2 ({lim}`L-84`). The transport takes the volumes from a table filled once ({src}`photon_mod.f90::initCellVolumes`). `fillGrid` also stores half the outermost spacing of each axis as `geoCorrX`, `geoCorrY`, `geoCorrZ` ({src}`code <grid_mod.f90::fillGrid@"grid(iG)%geoCorrX = (grid(iG)%xAxis(grid(iG)%nx) - grid(iG)%xAxis(grid(iG)%nx-1))/2.">`), which the boundary tests of the transport add to the outermost axis points; in practice those tests fire when the cell index leaves the grid. A point is assigned to a cell by locating it on each axis and rounding to the nearer axis point, as for a star ({src}`grid_mod.f90::setStarPosition`).

(sec:moc-active)=
## Active cells, `Rin` and `Rout`
{bdg-success}`used`

`setMotherGrid` decides which cells exist ({src}`code <grid_mod.f90::setMotherGrid@"! set active cells pointers"..@"print*, '! setMotherGrid: no gas and no dust? The grid is empty.'">`). A cell whose axis point lies at $r<R_{\mathrm{in}}$, or at $r>R_{\mathrm{out}}$ when $R_{\mathrm{out}}>0$, is inactive, except under plane-parallel illumination, where no radius is tested. Of the rest, a cell is active if it holds gas ($n_{\mathrm H}>0$) or dust ($N_{\mathrm{dust}}>0$), whichever the model contains. The active cells are numbered $1\dots N_{\mathrm{cells}}$ in loop order ($x$ outermost) and the number is stored in `active(i,j,k)`; an inactive cell has 0, and a mother-grid cell covered by a sub-grid has minus the sub-grid's index. Every per-cell array is allocated from 0 to $N_{\mathrm{cells}}$, and slot 0 stands for every inactive cell; a packet created in an inactive cell (by a source in a cavity) is booked on escape in slot 0 of `escapedPackets`, which the SED counts since {devlog}`D-441` ({ref}`sec:moc-sed`).

`Rin` is required: its default of $-1$ fails the input check ({src}`code <set_input_mod.f90::readInput@"else if (R_in < 0.) then">`). It may be 0, as in the 1D dust shells and `test_Problem`. `Rout` defaults to 0, which means no outer radius; $R_{\mathrm{in}}\ge R_{\mathrm{out}}>0$ is refused. Besides the active test, $R_{\mathrm{out}}$ ends a packet whose interaction point lies beyond it ({ref}`sec:moc-path`) and sets the depth scale of the path biasing ({ref}`sec:moc-pathstretch`).

(sec:moc-density)=
## Gas density, abundances and the starting state
{bdg-success}`used`

The hydrogen density of each point is set in `setMotherGrid` ({src}`code <grid_mod.f90::setMotherGrid@"! set density"+56>`) by the first of three inputs present, in this order:

- {bdg-warning}`not exercised` `densityLaw` $r_1\,n\,N_0$: $n_{\mathrm H}=N_0\,(r/r_1)^n\exp[-\tfrac12(r/r_1)^2]$, the law of {cite:t}`Clegg1987` named in the code;
- `Hdensity`: a uniform density (the Lexington models, `hiipdr`, `pn150k`);
- `densityFile`: one line per point with $x\,y\,z\,n_{\mathrm H}$ and, with `multiChemistry`, a fifth column selecting the abundance set of that point (`abFileIndex`); `test_Problem` uses both. `multiChemistry` $n$ followed by $n$ abundance files requires a density file ({src}`code <set_input_mod.f90::readInput@"else if (lgMultiChemistry .and. .not.lgDfile) then">`); a single abundance set is given by `nebComposition`, which also declares a model without gas (`noGas`).

The dust density comes from `Ndust` (a constant or a file, which sets the axes like a density file) or from the dust-to-gas mass ratio `MdMg` or `MdMh`, converted to grains per cm$^3$ in each cell; {doc}`dust` describes them and the per-cell dust composition of `multiDustChemistry`.

{bdg-warning}`not exercised` `gasMass` and `dustMass` (in M$_\odot$) rescale the densities after the grid is built ({src}`code <grid_mod.f90::fillGrid@"!BEKS 2011: scale the gas mass here to gasMass keyword"..@"totalGasMass = inputGasMass">`): every $n_{\mathrm H}$ (and $N_{\mathrm{dust}}$, when it follows the gas through `MdMg` or `MdMh`) is multiplied by the ratio of the requested to the computed mass $\sum_{\mathrm{cells}} n_{\mathrm H}V\sum_{\mathrm{el}}A_{\mathrm{el}}m_{\mathrm{el}}$, and `dustMass` does the same for $N_{\mathrm{dust}}$ alone; under `symmetricXYZ` the requested masses are divided by 8 ({src}`code <set_input_mod.f90::readInput@"if (lginputGasMass) then"#1>`). `dustMass` together with a gas-to-dust ratio is refused.

{bdg-warning}`not exercised` `fillingFactor` $\epsilon<1$ sets $n_{\mathrm H}=0$ at each point where a uniform random number exceeds $\epsilon$ ({src}`code <grid_mod.f90::setMotherGrid@"if (fillingFactor<1.) then">`). It is a mask on whole cells, applied to the gas only: with `Ndust` a masked cell keeps its dust and stays active if it has any, but with `MdMg` or `MdMh`, whose dust follows the gas, it has none and becomes inactive ({src}`code <grid_mod.f90::setMotherGrid@"if (HdenTemp(i,j,k) > 0. .or. NdustTemp(i,j,k)>0.) then">`); the volume of the remaining cells is not changed. The random numbers are drawn before any seeding, so the mask is outside `randomSeed` and, with gfortran's fixed default state, every rank builds the same grid ({lim}`L-74`).

Every active cell starts with $T_e$ = `TeStart` (default $10^4$ K), $n_e=n_{\mathrm H}$, $x(\mathrm H^0)$ = `initH0` (default $10^{-5}$, {devlog}`D-160`; the keyword exists in PDR builds only), $x(\mathrm{He}^0)=x(\mathrm H^0)$ and $x(\mathrm{He}^+)=1-x(\mathrm H^0)$; every heavy element starts with its neutral stage at $x(\mathrm H^0)$ and the others empty ({src}`code <grid_mod.f90::setMotherGrid@"H0in  = initH0   ! D-160"+45>`). The grains start at 50 K ({src}`code <dust_mod.f90::dustDriver@"grid%Tdust   = 50.">`).

(sec:moc-symmetric)=
## The octant: `symmetricXYZ`
{bdg-success}`used`

With `symmetricXYZ` the grid holds the octant $x,y,z\ge0$ of a model symmetric under reflection in the three coordinate planes, which act as mirrors. Every benchmark and fixture of this project uses it (the Lexington models, the 1D dust shells, the 2D dust disc inputs, `hiipdr`, `pn150k`, `test_Problem`) except the plane-parallel slabs `benchmarks/pdr/v1slab`, `v2slab` and `ifront` ({ref}`sec:moc-plane`). The packets of a single source are launched into the octant by taking the absolute value of each direction cosine; with `multiPhotoSources` they are not folded ({src}`code <photon_mod.f90::energyPacketDriver/initPhotonPacket@"if ((lgSymmetricXYZ) .and. initPhotonPacket%lgStellar &">`). A packet that reaches a mirror plane has the negative component of its direction reversed and is put back on the plane, at three places in `pathSegment`: before each step ({src}`code <photon_mod.f90::energyPacketDriver/pathSegment@"! find distances from all walls"..@"enPacket%direction = vHat">`), at an interaction point ({src}`code <photon_mod.f90::energyPacketDriver/pathSegment@"if (lgSymmetricXYZ .and. gP==1) then">`) and after a wall crossing ({src}`code <photon_mod.f90::energyPacketDriver/pathSegment@"if (lgSymmetricXYZ ) then"..@"enPacket%direction = vHat">`). Each site also copies the reflected step direction into the packet's stored direction since {devlog}`D-366`, which made the same fix at a fourth site, the mirror walls of plane-parallel illumination ({src}`code <photon_mod.f90::energyPacketDriver/pathSegment@"! D-366: the mirror walls above flip vHat; the stored">`). Before, the next Henyey–Greenstein scattering started from the pre-bounce direction and printed a grid-direction pattern on the scattered field: in `hiipdr` at $A_V$ 2.5–3.5, +0.44 in $\ln\chi$ on the planes and −0.15 on the diagonals, about +55% and −14%.

Since the whole luminosity of a source is sent into one octant, the field estimators and the escaped energy are divided by 8 after the transport ({src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"grid(iG)%Jste(i,:) = grid(iG)%Jste(i,:)/8.">`), the printed masses and the Balmer jump are multiplied by 8, and the SED is multiplied by 8 when integrated over angle and by 4 in each viewpoint ({src}`code <output_mod.f90::writeSED@"SED(freq,0) = SED(freq,0)*8.">`). A viewpoint with $\theta>\pi/2$ is refused ({src}`code <grid_mod.f90::initCartesianGrid@"if (viewPointTheta(i) > Pi/2. .and. lgSymmetricXYZ) then">`), and the angles of escaping packets are binned folded into the octant ({ref}`sec:moc-sed`). Plane-parallel illumination switches `symmetricXYZ` off with a warning.

(sec:moc-subgrids)=
## Nested sub-grids
{bdg-warning}`not exercised`

`multiGrids` $n$ *file* adds $n-1$ sub-grids to the mother grid. No model of this project uses them; the upstream examples `examples/multigridgas` and `examples/multigridgasdust` have not been run. For each sub-grid the file gives the index of its mother grid, its $n_x\,n_y\,n_z$, its density file and a density factor, then its six edges ({src}`code <grid_mod.f90::setSubGrids@"read(71, *) grid(iG)%motherP , grid(iG)%nx, grid(iG)%ny, grid(iG)%nz, dFileRead, denfac">`). The block that would move the edges onto the mother grid's walls is switched off (`if (.false.)`, {src}`grid_mod.f90::setSubGrids@"! realign boundaries with mother grid cell half-way boundaries"+1`); the sub-grid's axes are those of its density file, and its densities are multiplied by the factor. `fillGrid` marks every mother cell whose axis point lies inside a sub-grid with minus that sub-grid's index ({src}`code <grid_mod.f90::fillGrid@"grid(iG)%active(i,j,k) = -jG"#1>`). In `pathSegment` a packet that steps into such a cell is located in the sub-grid and continues there ({src}`code <photon_mod.f90::energyPacketDriver/pathSegment@"! packet is entering a subgrid">`), while keeping track of the mother cell it is in; when it leaves the sub-grid's box it returns to that mother cell. The mother-cell tracking and the location of a star in a sub-grid each contain a slip ({lim}`L-74`), and the H$_2$ level model skips any model with sub-grids ({lim}`L-58`). A diffuse source can be restricted to the first grids with `emittingGrid` ({ref}`sec:moc-sources`).

(sec:moc-2d)=
## The 2D mode
{bdg-warning}`not exercised`

With `2D` the model is symmetric about the $z$ axis and only the plane $y=y_1$ holds independent cells: densities are read or computed for $j=1$ only, `yAxis` is set equal to `xAxis`, and every point $(x_i,y_j,z_k)$ with $j>1$ takes the cell number of the point on the $x$ axis nearest to its cylindrical radius $\sqrt{x_i^2+y_j^2}$ at the same $z$ ({src}`code <grid_mod.f90::setMotherGrid@"if (lg2D) then"#2>`). Until {devlog}`D-450` a radius equal to the last axis point, which the point $(x_1, y_{n_y})$ and some others have, was mapped onto cell 2 ({lim}`L-91`). Packets are transported through the full cube, so several points add path length to one cell's estimator; `iterateMC` divides $J^{\mathrm{ste}}$ by the number of points mapped onto each cell (`TwoDscaleJ`, {src}`code <iteration_mod.f90::MCIterationDriver/iterateMC@"if (lg2D) grid(iG)%JSte(grid(iG)%active(i,j,k),freq) = &">`), and the cell loops of the iteration run over $j=1$ only. The mode is refused with plane-parallel illumination and in a PDR run ({src}`code <set_input_mod.f90::readInput@"if (lgPDR .and. lg2D) then">`). The same division applied to $J^{\mathrm{dif}}$ (debug mode only) indexes the frequency axis with the line counter ({lim}`L-77`). The project's 2D dust disc inputs (`benchmarks/dust/2D`) do not use this mode: they are octants of a 3D grid.

(sec:moc-plane)=
## Plane-parallel illumination
{bdg-warning}`not exercised`

`planeIonization` $F\,\nu_0$ replaces the point sources by a uniform beam entering through the face $y=0$. The 1D slabs `v1slab`, `v2slab` and `ifront` use it, and were measured at {devlog}`D-045`–{devlog}`D-052`, but they have not been rerun since ({lim}`L-11`). Until {devlog}`D-450` a packet launched past the last $x$ or $z$ axis point, clamped onto it, started in column 2 instead of the last: 10% of the packets per axis on the slabs' five columns, so their archived runs misplace that part of the beam in the first layer ({lim}`L-91`). The mode requires a density file and is refused with `2D`. With $\nu_0=0$, $F$ is the bolometric energy flux (erg cm$^{-2}$ s$^{-1}$); with $\nu_0>0$ it is the photon flux above $\nu_0$ (cm$^{-2}$ s$^{-1}$), converted into the bolometric energy flux with the spectral shape of the source. The source luminosity is that flux times the face $x_{\max}z_{\max}$, for $\nu_0>0$ ({src}`code <grid_mod.f90::setMotherGrid@"if (lgPlaneIonization) then">`):

$$
L_\star=\frac{x_{\max}\,z_{\max}}{10^{36}}\;F\,\frac{\int F^{E}_\nu\,\mathrm d\nu}{\int_{\nu_0}F^{N}_\nu\,\mathrm d\nu}\quad[10^{36}\ \mathrm{erg\,s^{-1}}],
$$ (eq:moc-plane)

with $F^E_\nu$ and $F^N_\nu$ the energy and photon spectra of the source. A packet starts at $y=0$ travelling along $+y$, at a uniform random $x$ between $-\Delta x_1/2$ and $x_n+\Delta x_n/2$, with $\Delta x_1$ and $\Delta x_n$ the first and the last spacing of the axis (likewise in $z$), and is put back onto the outermost axis point when it falls outside the axis ({src}`code <photon_mod.f90::energyPacketDriver/initPhotonPacket@"if (initPhotonPacket%lgStellar .and. lgPlaneIonization) then"..@"planeIonDistribution(initPhotonPacket%xP(igpi),&">`); the launch cells are counted in `output/planeIonDistribution.out`. With axes from $-R$ to $R$ the face $y=0$ is the mid-plane and only the half $y>0$ is lit ({devlog}`D-045`); the lower bound of the launch range is then near the centre of the face, not its edge, so only the quadrant $x,z\ge0$ of the face is lit ({lim}`L-74`). With axes from 0 the face is the grid's edge and the luminosity is exactly the flux through it ({devlog}`D-047`).

The $x$ and $z$ faces are specular mirrors, making the slab infinite ({devlog}`D-048`); only the $y$ faces let packets out ({src}`code <photon_mod.f90::energyPacketDriver/pathSegment@"if ( (rVec%x <= grid(1)%xAxis(1) .or. xP<1) ) then">`). The mirrors sit at the outermost axis points, without the half-cell `geoCorr` the escape tests use; this is kept, since it makes the enclosed area the $x_{\max}z_{\max}$ that Eq. ({eq}`eq:moc-plane`) assumes ({devlog}`D-052`). The $z$-minimum mirror puts the packet at `yAxis(1)` instead of `zAxis(1)`, harmless only when the two axes start at the same value ({devlog}`D-049`). `fillGrid` sets $R_{\mathrm{out}}$ to $x_{\max}y_{\max}z_{\max}/10^{20}$, which is not a length ({src}`code <grid_mod.f90::fillGrid@"R_out = 1.e10*( (grid(1)%xAxis(grid(1)%nx)/1.e10)*&">`, {lim}`L-74`): the escape-by-radius test never fires, which leaves escape to the walls, and the path biasing would lose its depth scale.
