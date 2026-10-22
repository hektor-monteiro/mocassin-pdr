(sec:geometry)=
# Geometry: rays, extinction and shielding columns
The MC field already contains the attenuation by dust (absorption and scattering) and by the gas continua. What it does not contain is the absorption in the H$_2$ and CO lines, which the MC does not transport. That absorption is applied through column densities integrated along the paths the photons took: the straight line from each source for the direct beam, and the path source $\to$ scattering point $\to$ cell for the scattered light. This section describes how those paths and columns are built; {ref}`sec:h2model` and {ref}`sec:photorates` apply them.

(sec:raycells)=
## Exact ray–cell traversal
Every ray in the bridge is traced by `rayCells` ({src}`pdr_mod.f90::rayCells`, {devlog}`D-397`). MOCASSIN’s cells are centred on the axis values, so a cell’s faces are the midpoints between neighbouring axis values and the grid ends at the first and last values (the boundary cells are half-cells). From a start point inside the grid and a unit vector $\hat u$, the routine computes for each axis the distance along $\hat u$ to the next face and repeatedly steps through the nearest one (a three-dimensional digital differential analyser in the manner of {cite:t}`AmanatidesWoo1987`), returning the list of cells crossed and the exact length $\ell$ of the ray in each, at a cost proportional to the number of cells crossed. The first entry is the cell the ray starts in; inactive cells (outside the nebula or in a cavity) are returned with index zero and contribute nothing. The ray ends after a given length or at the edge of the grid. For a `symmetricXYZ` octant the lower faces are planes of symmetry: when `lgMirror` is set the ray is reflected there ($u_q\to-u_q$) and continues, a segment that re-enters the cell it just left being merged with it; otherwise the ray ends at the edge. This replaced fixed-step marches that sampled each cell an integer number of times and missed the part of the neighbouring cell nearest the target, which had made the source-ward $N(\mathrm{H_2})$ through `hiipdr`’s transition 0.46–0.75 of its exact value; with the exact paths that transition moved 0.25 pc towards the star ({devlog}`D-397`, {devlog}`H-025`, {lim}`L-45`).

(sec:avradial)=
## Source-ward extinction and molecular columns
`computeAVradial` ({src}`pdr_mod.f90::computeAVradial`), called from `computeAVdust` ({src}`pdr_mod.f90::computeAVdust`) for point sources, traces for every active cell and every source $s$ a ray from the cell centre towards the source (no mirror) and accumulates 

```{math}
\tau_{V,s} = \sum_{\mathrm{cells}} (\kappa^{\mathrm{abs}}_V+\kappa^{\mathrm{sca}}_V)\,\ell,
  \qquad
  N_{X,s} = \sum_{\mathrm{cells}\neq\mathrm{target}} n_{\mathrm H}\, x_X\,\ell,
  \quad X\in\{\mathrm{H_2},\,\mathrm C,\,\mathrm{CO}\},
```

 with the abundances left by the previous chemistry. $\tau_{V,s}$ runs to the cell centre, the target’s half-chord included. The target cell is excluded from $N_{X,s}$ ({devlog}`D-088`): including its near half made its H$_2$ shield itself, a positive feedback (more H$_2$, less dissociation, more H$_2$) that, with MOCASSIN’s large cells, drove the surface cell to complete self-shielding. The column is therefore the one to the cell’s near face. It misses the cell’s own contribution, an error that shrinks with the cell size instead of feeding back: on `hiipdr`’s $31^3$ grid a cell is 0.648 pc, 0.104 mag of $A_{V}$ ({devlog}`H-026`) and $2\times10^{20}$ H nuclei cm$^{-2}$, so half a cell can hold $5\times10^{19}$ cm$^{-2}$ of H$_2$ and, at a CO abundance of $10^{-4}$, $10^{16}$ cm$^{-2}$ of CO, columns at which both self-shield strongly (the CO factor of {cite:t}`vanDishoeckBlack1988` is $\approx0.05$ at $N(\mathrm{CO})=10^{16}$ cm$^{-2}$). The level model averages the transmission through the cell’s own column instead ({ref}`sec:ownavg`); the CO photorate and the chemistry’s own H$_2$ diagnostic do not: their column lags the column to the cell centre by half a cell ({devlog}`D-088`), so they are under-shielded in the cells of their own transitions on coarse grids, which places those transitions deeper by up to about half a cell. The length of the source-ward ray inside the target cell, from its near face to its centre, is kept separately as $\ell_{\mathrm{own}}$ for the scattering sites ({devlog}`D-398`).

The sources are combined with the geometric weights $f_s = r_s^{-2}$ (dilution only, {src}`pdr_mod.f90::computeAVradial@"fS = 1.d0/(seg*seg) ! geometric dilution only"`): 

```{math}
:label: eq:avradial
\begin{align}
  A_{V}&= -\frac{1.0857}{R_{\mathrm{FUV}}}\,\ln\!\left[\frac{\sum_s f_s\, e^{-R_{\mathrm{FUV}}\tau_{V,s}}}{\sum_s f_s}\right],
  &
  N_X &= \frac{\sum_s f_s N_{X,s}}{\sum_s f_s},
  &
  \ell_{\mathrm{own}} &= \frac{\sum_s f_s\,\ell_{\mathrm{own},s}}{\sum_s f_s}
\end{align}
```

 ({src}`pdr_mod.f90::computeAVradial@"if (fTot > 0.d0 .and. fSum > 0.d0) then"..@"& grid(iG)%difSrc(cellP,6) = wOwn/fTot"`), stored as `AVeff`, `pdrColH2`, `pdrColC`, `pdrColCO` and `difSrc(:,6)`. For one source these are the plain column and $A_{V}$, and all the fixtures have one source. For several, the $A_{V}$ is the one that reproduces the summed transmitted FUV of sources of *equal* luminosity, and the columns are means weighted by geometry alone (neither the luminosities nor the attenuation of the sources enter $f_s$), applied to the summed direct field through shielding functions that are not linear in the column; the error of this is not measured. An outward ray along the same direction (with mirrors) gives the dust column to the edge, `AVback`.

$A_{V}$ is a coordinate and a diagnostic in the 3D build: the photorates do not use it ({ref}`sec:rays`). It is a geometric dust column, not an inversion of the MC field, which would under-read it by a factor 1.8 because the field carries scattered light ({devlog}`D-086`, {devlog}`D-087`); TORUS-3DPDR also derives $A_{V}$ from the column density along rays ({cite:alp}`Bisbas2015`, their Eq. 2). It is measured from the source and so includes the dust of the ionised gas: `hiipdr`’s ionisation front sits at $A_{V}=0.48$ ({devlog}`D-260`). A 1D PDR model, whose $A_{V}$ starts at its illuminated face, has to be compared at $A_{V}$ measured from the front.

Under plane-parallel illumination `computeAVdust` integrates $A_{V}$ and the columns along the beam direction itself ({src}`pdr_mod.f90::computeAVdust@"do iG = 1, nGrids"..@"& max(real(dble(magPerTau)*tau) - grid(iG)%AVeff(cellP), 0.)"`); there the columns run to the cell centre, the cell’s near half included ({src}`pdr_mod.f90::computeAVdust@"if (cellP > 0) then"..@"grid(iG)%pdrColCO(cellP) = real(cCO)"`), unlike the point-source branch. The level model does not run in that geometry.

## Snapshot for the diffuse walk

`snapDiffuseSources` ({src}`pdr_mod.f90::snapDiffuseSources`) is called by `computeAVdust` before any cell is solved and stores per cell (`difSrc`): 

```{math}
n(\mathrm{H_2}),\ n(\mathrm C),\ n(\mathrm{CO})\ [\mathrm{cm^{-3}}];\qquad
  \kappa_{\mathrm{ext}} = R_{\mathrm{FUV}}\,\kappa_V\ [\mathrm{cm^{-1}}];\qquad
  \epsilon = \sum_{k\in\mathrm{FUV}} \kappa^{\mathrm{sca}}_k\,J^{\mathrm{ste}}_k\ [\mathrm{erg\,s^{-1}\,cm^{-3}}],
```

 the number densities that shield, a grey FUV extinction coefficient, and the FUV power scattered per unit volume in the band ({src}`pdr_mod.f90::snapDiffuseSources@"if (grid(iG)%Hden(cP) <= 0.) cycle"..@"grid(iG)%difSrc(cP,5) = emis"`). For isotropic scattering $\epsilon/4\pi$ is the band-integrated scattering emissivity. It is computed from the full local MC field, direct and diffuse, so it contains every order of scattering.

(sec:sites)=
## Scattering sites of the diffuse field
The diffuse FUV field is produced by scattering inside the cloud. A photon scattered at a point $P$ and arriving at the cell $C$ has crossed the column $N(\star\to P)+N(P\to C)$, not the column from the star to $C$ ({devlog}`D-347`, {devlog}`D-348`). `traceDiffuseSites` ({src}`pdr_mod.f90::traceDiffuseSites`) represents the diffuse field arriving at the target cell by a set of *scattering sites*, built as the discretised formal solution of the transfer equation for the intensity arriving at $C$ from each of a set of directions $\hat k$, 

$$
4\pi I_{\hat k} = \int_0^\infty \epsilon(s)\, e^{-\tau(s)}\,\mathrm{d}s ,
  \qquad \tau(s)=\int_0^s \kappa_{\mathrm{ext}}\,\mathrm{d}s',
$$ (eq:formal)

 with $s$ the distance from $C$ along $\hat k$ (the direction the photons come from):

1.  **Directions.** The twelve HEALPix $N_{\mathrm{side}}=1$ pixel centres {cite:p}`Gorski2005`, which divide the sphere into twelve equal solid angles of $\pi/3$ sr, built directly in RING order: rays 0–3 at $\mu=+2/3$, $\phi=(k+\frac12)\pi/2$; rays 4–7 at $\mu=0$, $\phi=k\pi/2$; rays 8–11 at $\mu=-2/3$, $\phi=(k+\frac12)\pi/2$ ({src}`pdr_mod.f90::traceDiffuseSites@"if (.not.lgDirs) then"..@"lgDirs = .true."`), with $\mu$ measured along the grid’s $z$ axis. The directions are fixed in the grid frame.

2.  **Walk.** Each ray is traced with `rayCells` from the target’s centre, with mirror reflection at the octant’s lower faces, to the edge of the model. Every cell crossed that scatters ($\epsilon>0$, $\kappa_{\mathrm{ext}}>0$) is a site, the target cell itself included (with the half-chord the ray crosses); the walk is stored (`wkCell`, `wkLen`, `siteRay`, `siteIst`) for the level model.

3.  **Weight.** With $\tau$ the grey FUV optical depth between the target’s centre and the entry of the site cell and $\Delta\tau=\kappa_{\mathrm{ext}}\ell$ across it, 

$$
w_{\mathrm{site}} = \epsilon\;\frac{1-e^{-\Delta\tau}}{\kappa_{\mathrm{ext}}}\;e^{-\tau}
        \qquad\bigl(\tfrac{1-e^{-\Delta\tau}}{\kappa_{\mathrm{ext}}}\to\ell(1-\tfrac12\Delta\tau)\ \text{for}\ \Delta\tau\le10^{-4}\bigr)
$$ (eq:siteweight)

 ({src}`pdr_mod.f90::traceDiffuseSites@"emis = grid%difSrc(cP,5)"..@"w = emis*esc*exp(-tau)"`): Equation ({eq}`eq:formal`) integrated over the site’s segment with $\epsilon$ and $\kappa_{\mathrm{ext}}$ constant in the cell. Since the directions subtend equal solid angles, $4\pi J_{\mathrm{formal}}=\frac1{12}\sum_{\mathrm{sites}}w_{\mathrm{site}}$.

4.  **Two-leg column.** For each species $X$ ({src}`pdr_mod.f90::traceDiffuseSites@"col1(1) = dble(grid%pdrColH2(cP))"..@"siteN(:,nSite) = col1 + cN + 0.5d0*dN"`), 

$$
N_{X,\mathrm{site}} = N_X^{\star}(P) + n_X(P)\,\ell_{\mathrm{own}}(P)
           + \sum_{\mathrm{cells\ between}} n_X\,\ell + \tfrac12\,n_X(P)\,\ell_P ,
$$ (eq:twoleg)

 the source-ward column of the site’s cell to its near face, plus the site cell’s own gas from its near face to its centre ({devlog}`D-398`), plus the cells crossed between the target and the site, plus half of the site cell along the walk. The target cell is excluded from both legs, so a site in the target cell carries the direct beam’s column.

Only the *relative* weights are used: the magnitude of the diffuse field is the MC’s $\chi_{\mathrm{dif}}$ (Eq. {eq}`eq:chisplit`), which the sites distribute over directions and columns, each site becoming a ray of the chemistry with field $\chi_{\mathrm{dif}}\,w_{\mathrm{site}}/\sum w$ ({ref}`sec:rays`). The distribution is the formal solution only under the assumptions built into Equation ({eq}`eq:siteweight`): isotropic scattering, whereas the grains of the fixtures have $g=0.61$ and 0.29 ({numref}`tab:dustfix`), so the real diffuse field arrives preferentially from the source side; a grey extinction equal to the source-weighted band mean, whereas the window in which H$_2$ and CO dissociate has a larger extinction and the local field at depth a smaller one ({ref}`sec:dust`); an emissivity made by dust scattering alone, whereas $\chi_{\mathrm{dif}}$ also holds gas emission; uniform emissivity across a cell; and the twelve-direction quadrature. As a check of these assumptions, the formal solution’s own magnitude, $4\pi J_{\mathrm{formal}}/(c\,u_{\mathrm{D}})$, recovers 52–130% of the MC’s $\chi_{\mathrm{dif}}$, falling with depth, for reasons not yet identified (gas two-photon emission, the phase function and the quadrature were named as candidates; the source-weighted grey extinction, which overstates the extinction at depth, is another; {lim}`L-4`). The field arrives markedly anisotropically: the brightest of the twelve directions carries 1.9–3.1 times the mean ({devlog}`D-348`). What the assumptions affect is the distribution of the diffuse field over the sites’ columns, not its magnitude, and that distribution acts on the photorates only through the line shielding: at fixed abundances the two-leg columns took back 5–32% of the increase of the H$_2$ photodissociation rate that the diffuse field’s magnitude produced ({devlog}`D-348`).

(sec:healpix)=
## Angular quadrature
The twelve directions of the sites and of the line rays are the coarsest HEALPix tessellation. Their moments are not isotropic: the mean fourth power of a direction’s component is 0.132 along the ring axis ($z$) against 0.218 across it, where an isotropic set gives 0.2 ({devlog}`D-410`). The result is a pattern fixed in the grid frame: of the cells that the octant’s symmetry makes equivalent, the one nearest the plane $z=0$ holds about 11% more H$_2$ before and across the H/H$_2$ transition, on both fixtures, independently of the packet count ({lim}`L-53`). Rotating the set moves the excess to the new ring axis, and 48 directions ($N_{\mathrm{side}}=2$, fourth moments 0.188 and 0.201) remove it at 1.48 times the run time, moving every integrated quantity by less than 1%; the twelve were kept because no line map carries the pattern ({devlog}`D-410`). 3D-PDR and TORUS-3DPDR also use HEALPix rays, twelve ($\ell=0$) in TORUS-3DPDR’s production runs {cite:p}`Bisbas2012,Bisbas2015`.

(sec:lineRays)=
## Line-escape rays
`traceLineRays` ({src}`pdr_mod.f90::traceLineRays`, {devlog}`D-377`) traces the same twelve directions from the target cell to the edge of the model, with mirrors at the lower faces, skipping inactive cells, and returns for each ray the cells crossed and the path length in each; the first entry is the cell itself with the half of it the ray crosses. These rays give the escape probabilities of the coolant lines ({ref}`sec:thermal`) and of the H$_2$ lines ({ref}`sec:escape`), each crossed cell contributing with its own level populations. Before {devlog}`D-377` the 3D flavour’s line escape was a slab with four of the twelve rays shut, which capped the escape probability of an optically thin line at 2/3 ({lim}`L-27`).

## Comparison with 3D-PDR and TORUS-3DPDR

In 3D-PDR {cite:p}`Bisbas2012` the FUV field is a boundary condition: at every point the field incident on the cloud surface is attenuated along HEALPix rays traced to the boundary, $\chi(p)=N_\ell^{-1}\sum_{q}\chi_0(q)\,e^{-\tau_{\mathrm{UV}}A_{V}(q)}$ with $\tau_{\mathrm{UV}}=3.02$ in the benchmark comparisons ({cite:alp}`Bisbas2015`, their Eq. 1), and the shielding columns are integrated along the same rays. For a source inside the cloud these rays are the wrong paths: a ray pointing away from the source would deliver unshielded radiation from outside a nebula that has no outside source ({devlog}`D-342`). TORUS-3DPDR {cite:p}`Bisbas2015` takes the FUV field of every cell from its MC path-length estimator (912–2400 Å, stored as two vectors for the positive and negative directions), derives $A_{V}$ and the column densities along HEALPix rays from the density field, and leaves the dust’s contribution to the diffuse field to later work (their Sect. 3.1). The present coupling differs from both in that the dust attenuation and scattering are the MC’s, the field is split into its direct and scattered parts, and the line-shielding columns follow the photons’ paths: source-ward for the direct beam and through the scattering sites for the diffuse field.
