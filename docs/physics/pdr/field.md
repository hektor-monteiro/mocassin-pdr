(sec:field)=
# The Monte Carlo radiation field
## Transport and the path-length estimator

MOCASSIN transports the radiation of each source $s$ of luminosity $L_s$ as $N_s$ energy packets of equal luminosity $\dot\varepsilon_s=L_s/N_s$ (`deltaE`; {cite:t}`Ercolano2003`). A packet’s frequency bin is drawn from the source’s cumulative emitted-energy distribution (`inSpectrumProbDen`; an energy, not a photon-number, cumulative, as packets of equal energy require). The packet travels in a straight line until it interacts, the optical depth to the interaction, $-\ln(1-\mathcal R)$ with $\mathcal R$ uniform in $[0,1)$, being accumulated with the total opacity of the cells it crosses: the gas continua (bound–free absorption by every ion present, including C I and the other neutral metals in the FUV, the H$_2$ photoionisation continuum above 15.4 eV, free–free) plus dust absorption and scattering. At an interaction the packet is

- scattered by dust with probability $\kappa^{\mathrm{sca}}_\nu/\kappa_\nu$, with $\kappa_\nu$ the total opacity ({src}`photon_mod.f90::energyPacketDriver/pathSegment@"probSca = grid(gP)%scaOpac(grid(gP)%active(xP,yP,zP),enPacket%nuP)/&"..@"lgScattered = .true."`): coherently, keeping its frequency, into a new direction drawn from the {cite:t}`HenyeyGreenstein1941` phase function with the bin’s asymmetry parameter $g_\nu$ (`hg`, {src}`photon_mod.f90::energyPacketDriver/pathSegment@"enPacket = initPhotonPacket(enPacket%nuP, rVec, enPacket%direction, .false., .false., enPacket%xP(1:2), &"..@"print*, '! pathSegment [warning]: hg called ten times [enPacket]', enPacket"`), or isotropically if isotropic scattering is selected;

- otherwise absorbed, by the dust with probability $\kappa^{\mathrm{abs}}_\nu/(\kappa_\nu-\kappa^{\mathrm{sca}}_\nu)$ and by the gas otherwise ({devlog}`D-233`; {src}`photon_mod.f90::energyPacketDriver/pathSegment@"! Split by the absorption opacities themselves, which is"..@"! packet is absorbed by the gas"`), and re-emitted on the spot as a new packet of the same energy at a frequency drawn from the local dust (thermal) or gas (hydrogen and helium diffuse continua and lines; {lim}`L-51`) emissivity.

Packets carry a weight $w$ (`enPacket%weight`) that is unity unless the optional composite path-length biasing of {cite:t}`Baes2016` is switched on (`pathStretch`, off by default, {src}`common_mod.f90@"! D-238: composite biasing of the interaction depth (Baes et al. 2016,"`).

The mean intensity is measured with the path-length estimator of {cite:t}`Lucy1999`, eq. 12. A packet of luminosity $\dot\varepsilon_s$ that travels a length $\ell$ inside a cell of volume $V$ adds $\dot\varepsilon_s\ell/c$ to the time-averaged radiant energy in the cell, and $u=4\pi J/c$, so the integral of the mean intensity over bin $k$ is 

$$
J^{\mathrm{ste}}_k \equiv 4\pi\int_{\mathrm{bin}\,k} J_\nu\,\mathrm{d}\nu
          = \frac{1}{V}\sum_{\mathrm{segments}\in k} \dot\varepsilon_s\, w\,\ell
  \qquad [\mathrm{erg\,s^{-1}\,cm^{-2}}],
$$ (eq:estimator)

 the sum running over every path segment of every packet (stellar or not, of every source) in the cell and in the bin, whether the segment ends at the cell’s face ({src}`photon_mod.f90::energyPacketDriver/pathSegment@"& grid(gP)%Jste(grid(gP)%active(xP,yP,zP),enPacket%nuP) + dS*deltaE(iStar) *(enPacket%weight) / dV"..@"! D-158: same split on the cell-crossing branch."`) or at an interaction inside it ({src}`photon_mod.f90::energyPacketDriver/pathSegment@"& grid(gP)%Jste(grid(gP)%active(xP,yP,zP),enPacket%nuP) + dlLoc*deltaE(iStar) *(enPacket%weight) / dV"..@"! every PDR run (lgJdifLive), not only under pdrSplitField."`). $J^{\mathrm{ste}}_k$ is a sum over the bin, *not* a quantity per unit frequency; the band energy density is $u_{\mathrm{band}}=\sum_k J^{\mathrm{ste}}_k/c$. The accumulation is in MOCASSIN’s internal units (packet luminosity in $10^{36}$ erg s$^{-1}$, cell volume in $10^{45}$ cm$^3$, lengths in cm); the factor $10^{-9}$ that converts to cgs, and the division by 8 for a `symmetricXYZ` octant (into which every packet of a single central source is launched), are applied after the transport ({src}`iteration_mod.f90::MCIterationDriver/iterateMC@"grid(iG)%Jste(i,:) = grid(iG)%Jste(i,:) * 1.e-9"`, {src}`iteration_mod.f90::MCIterationDriver/iterateMC@"grid(iG)%Jste(i,:) = grid(iG)%Jste(i,:)/8."`). The default frequency grid has `nbins` $=600$ bins ({src}`set_input_mod.f90::readInput@"nbins = 600"`). The estimator is unbiased and its relative variance in a cell and bin falls as the inverse of the number of segments recorded there, so it degrades with depth as the packets thin out ({ref}`sec:mcnoise`).

(sec:split)=
## Direct and diffuse parts
A packet leaves a source with `lgStellar` $=$ `.true.`; it is re-initialised as non-stellar whenever it is scattered ({src}`photon_mod.f90::energyPacketDriver/pathSegment@"enPacket = initPhotonPacket(enPacket%nuP, rVec, enPacket%direction, .false., .false., enPacket%xP(1:2), &"`) or re-emitted. In a PDR run every packet adds to $J^{\mathrm{ste}}$, and the non-stellar ones are mirrored into $J^{\mathrm{dif}}$ (`lgJdifLive` is forced true for any PDR run, {src}`set_input_mod.f90::readInput@"lgJdifLive = (pdrSplitField /= 0)"..@"if (lgPDR) lgJdifLive = .true."`; accumulation at {src}`photon_mod.f90::energyPacketDriver/pathSegment@"! every PDR run (lgJdifLive), not only under pdrSplitField."+3` and {src}`photon_mod.f90::energyPacketDriver/pathSegment@"! D-158: same split on the cell-crossing branch."+3`). Hence 

```{math}
\begin{align}
  J^{\mathrm{ste}}_k &= \text{total field},\nonumber\\
  J^{\mathrm{dif}}_k &= \text{scattered} + \text{re-emitted},\\
  J^{\mathrm{ste}}_k - J^{\mathrm{dif}}_k &= \text{the never-scattered source photons}.\nonumber
\end{align}
```

 The last is the direct beam of the sources, averaged over the cell and attenuated along its path by dust absorption *and* scattering and by the gas continua; it arrives at the cell along the straight line from each source. In the 6–13.6 eV band the diffuse part is dust-scattered starlight of any order of scattering plus the gas emission that falls in the band (the two-photon continuum of hydrogen and the line packets not destroyed by dust, {devlog}`D-376`); thermal dust emission contributes nothing there. Two properties of the split matter for what follows. First, the diffuse part dominates the PDR: on `hiipdr` the diffuse fraction $\chi_{\mathrm{dif}}/\chi$ rises from 0.35 at $A_{V}<0.2$ to 0.75 at $A_{V}=0.5$–0.8, 0.93 at 1.2–1.6 and above 0.99 beyond $A_{V}=2.1$ ({devlog}`D-344`), so the deep PDR sees almost no direct starlight. Second, because scattering keeps photons in the cloud, the total field decays with depth much more slowly than pure extinction: on the `V1` slab the transported FUV field fell by $e^{-1.86}$ per magnitude of $A_{V}$, against $e^{-3.02}$ for absorption and scattering removing the photons alike ({src}`pdr_mod.f90@"! D-087: geometric A_V for a NON plane-parallel geometry."`, {devlog}`D-086`, {devlog}`D-087`). (With the debug switch `lgDebug` the diffuse packets go into $J^{\mathrm{dif}}$ alone; every consumer adds them back in that case.)

(sec:bands)=
## Bands and the Draine normalisation
- **FUV band**: $\nu\in[0.44066,\,1.0]$ Ryd, i.e. 6.0–13.6 eV ({src}`constants_mod.f90@"real, parameter :: nuFUVlo = 0.44066 ! 2400 A [Ryd]"`). The bins inside it, `FUVlowP`…`FUVhighP`, run from the first bin with $\nu_k>0.44066$ Ryd to the last with $\nu_k\le1$ Ryd, located once at start-up ({src}`continuum_mod.f90::setContinuum@"call locate(nuArray, nuFUVlo, FUVlowP)"`). On the fixtures the band is 37 (`hiipdr`) and 39 (`pn150k`) of the 600 bins, starting at $\nu_k=6.17$ and 6.02 eV; the bins are $\Delta\nu/\nu\approx2$% wide. (The comment at {src}`constants_mod.f90@"! The far-UV band conventionally used for PDR photorates, 912-2400 Angstrom,"` calls the band 912–2400 Å; the value 0.44066 Ryd is 2068 Å, i.e. 6.0 eV, which is the band the code uses.)

- **Lyman–Werner (LW) window**: $\nu_k\in[0.8232,\,1.0)$ Ryd, 11.2–13.6 eV ({src}`constants_mod.f90@"real, parameter :: nuLWlo = 0.8232 ! 11.2 eV [Ryd]"`), about 9 bins: the range in which H$_2$ absorbs in its Lyman and Werner bands and is photodissociated, in which CO is photodissociated, and above whose lower edge (11.26 eV) C I is photoionised.

- **$V$ band**: the bin containing 5500 Å (`VbandP`, {src}`constants_mod.f90@"real, parameter :: nuVband = 0.165738 ! 5500 A [Ryd]"`), used to define $A_{V}$.

- **Draine unit**: $u_{\mathrm{D}}= 8.94\times10^{-14}$ erg cm$^{-3}$ ({src}`constants_mod.f90@"real, parameter :: uDraine = 8.94e-14 ! [erg/cm^3]"`), the 6–13.6 eV energy density $(4\pi/c)\int E\,F_{\mathrm D}(E)\,\mathrm{d}E$ (with $E$ converted to erg in the integrand) of the interstellar field of {cite:t}`Draine1978`, whose photon intensity $F_{\mathrm D}$ is Equation ({eq}`eq:draine`); integrating the polynomial gives $8.940\times10^{-14}$, and the code’s own quadrature on its bins $8.938\times10^{-14}$ ({src}`pdr_mod.f90@"! D-350: the share of the Draine (1978) field's 6-13.6 eV energy that"`). In photon units the same field carries $4\pi\int F_{\mathrm D}\,\mathrm{d}E=1.94\times10^{8}$ photons cm$^{-2}$ s$^{-1}$ over 6–13.6 eV and $2.06\times10^{7}$ in the LW window.

- **Relation to Habing units.** The {cite:t}`Habing1968` field is usually normalised by its 6–13.6 eV flux, $H_0=1.6\times10^{-3}$ erg s$^{-1}$ cm$^{-2}$ (as in {cite:alp}`Bisbas2015`), an energy density $H_0/c=5.3\times10^{-14}$ erg cm$^{-3}$. In that band $\chi=1$ is $G_0=c\,u_{\mathrm{D}}/H_0=1.68$ (1.69 with the value $5.29\times10^{-14}$ erg cm$^{-3}$ quoted at {src}`constants_mod.f90@"! Integrated FUV energy density of the Draine (1978) field, chi = 1."`); 3D-PDR’s heating routine converts with 1.68 ({src}`pdr/heatingfunctions.F90::CALC_HEATING@"HABING_FIELD=1.68D0*UV_FIELD"`), in terms this coupling does not use ({ref}`sec:thermal`). The factor 1.71 compares the two fields at 1000 Å instead: {cite:t}`Habing1968` gives $\lambda u_\lambda=4\times10^{-14}$ erg cm$^{-3}$ there, Equation ({eq}`eq:draine`) gives $6.84\times10^{-14}$. {cite:t}`DraineBertoldi1996` normalise their field parameter (also written $\chi$) to Habing’s at 1000 Å, so that the Draine field has $\chi_{\mathrm{DB}}=1.71$; the PDR code comparison adopts $\chi=1.71\,G_0$ ({cite:alp}`Rollig2007`, their Table 5), and TORUS-3DPDR divides its MC field by $1.71H_0$ ({cite:alp}`Bisbas2015`, their Eq. 12), a Draine unit 2.1% larger than $c\,u_{\mathrm{D}}$. A band of 912–2400 Å, as in TORUS-3DPDR, holds 13% more of a Draine-shaped field than 6–13.6 eV. As in the code comparison, $\chi$ here is a $4\pi$ average (an energy density), whatever the angular distribution of the field.

## Band-integrated field strengths

In `mocassinToPDR` ({src}`pdr_mod.f90::mocassinToPDR`): 

```{math}
:label: eq:chi
\begin{align}
  \chi &= \frac{1}{c\,u_{\mathrm{D}}}\sum_{k=\mathrm{FUVlowP}}^{\mathrm{FUVhighP}} J^{\mathrm{ste}}_k
  &&\text{(local, attenuated)}\\
  \chi_0 &= \sum_s \frac{L_{\mathrm{FUV},s}}{4\pi r_s^2\, c\,u_{\mathrm{D}}}
  &&\text{(geometric, unattenuated)}
\end{align}
```

where $L_{\mathrm{FUV},s}$ is the luminosity of source $s$ in the FUV bins, taken from the same cumulative distribution the packets are drawn from ({src}`code <pdr_mod.f90::mocassinToPDR@"fFUV = inSpectrumProbDen(iS, FUVhighP)"..@"Lfuv(iS) = dble(Lstar(iS))*1.d36*dble(fFUV)">`), and $r_s$ the distance of the cell centre from the source. The first is stored as `chiFUV` ({src}`code <pdr_mod.f90::mocassinToPDR@"uFUV = 0.d0"..@"grid(iG)%chiFUV(cellP) = real(chi)">`), the second as `chiFUV0` ({src}`code <pdr_mod.f90::mocassinToPDR@"chi0 = 0.d0"..@"grid(iG)%chiFUV0(cellP) = real(chi0)">`). $\chi_0$ is the energy density of the undimmed beams, $u=F/c$ for a beam of flux $F$; it is used only by the 1D build and by diagnostics. $\chi$ is passed to 3D-PDR’s heating routine, where only the photoelectric terms read it, and those are not used ({ref}`sec:thermal`); it also enters the seed ({ref}`sec:seed`). The photorates use the split of {ref}`sec:split`, evaluated per cell in `pdrStep` ({src}`pdr_mod.f90::pdrStep@"sumT = 0.d0; sumD = 0.d0; lwT = 0.d0; lwD = 0.d0"..@"chiDif = sumD/(dble(c)*dble(uDraine))"`): 

$$
\chi_{\mathrm{dir}}= \frac{1}{c\,u_{\mathrm{D}}}\sum_{k\in\mathrm{FUV}} \bigl(J^{\mathrm{ste}}_k-J^{\mathrm{dif}}_k\bigr),
  \qquad
  \chi_{\mathrm{dif}}= \frac{1}{c\,u_{\mathrm{D}}}\sum_{k\in\mathrm{FUV}} J^{\mathrm{dif}}_k ,
$$ (eq:chisplit)

 so that $\chi_{\mathrm{dir}}+\chi_{\mathrm{dif}}=\chi$; $\chi_{\mathrm{dir}}$ is clipped at zero against the rounding of the two single-precision sums.

(sec:window)=
## Lyman–Werner window factors
3D-PDR’s photorate coefficients $\alpha$ are rates per unit Draine field, computed for the Draine spectral shape, and are applied to the 6–13.6 eV band strength. For the four reactions driven only in the LW window (H$_2$, HD and CO photodissociation, C I photoionisation) a field whose shape differs from Draine’s in the band drives them at a different rate for the same $\chi$. The bridge therefore multiplies each such rate by the ratio of the window’s share of the band energy in the MC field to the same share in the Draine field, separately for the direct and the diffuse part ({devlog}`D-349`, {devlog}`D-350`): 

$$
f_{\mathrm{dir}} = \frac{1}{s_{\mathrm D}}
     \frac{\sum_{k\in\mathrm{LW}}(J^{\mathrm{ste}}_k-J^{\mathrm{dif}}_k)}{\sum_{k\in\mathrm{FUV}}(J^{\mathrm{ste}}_k-J^{\mathrm{dif}}_k)},
  \qquad
  f_{\mathrm{dif}} = \frac{1}{s_{\mathrm D}}
     \frac{\sum_{k\in\mathrm{LW}}J^{\mathrm{dif}}_k}{\sum_{k\in\mathrm{FUV}}J^{\mathrm{dif}}_k}
$$ (eq:window)

 ({src}`pdr_mod.f90::pdrStep@"fLWd = draineWindowShare()"`). Here $s_{\mathrm D}$ is the LW share of the Draine field’s 6–13.6 eV energy, computed once by `draineWindowShare` ({src}`pdr_mod.f90::draineWindowShare`) from the photon intensity of {cite:t}`Draine1978`, eq. 11, given there as valid over 5–13.6 eV 

$$
F_{\mathrm D}(E) = 1.658\times10^{6}E - 2.152\times10^{5}E^2 + 6.919\times10^{3}E^3
  \quad [\mathrm{photons\,cm^{-2}\,s^{-1}\,sr^{-1}\,eV^{-1}}],\quad E\ \text{in eV},
$$ (eq:draine)

 weighted by $E\,\Delta E_k$ on MOCASSIN’s own bins, with the same bin membership as the MC sums. The continuous band gives $s_{\mathrm D}=0.148$; on the bins it is 0.155 (`hiipdr`) and 0.164 (`pn150k`), printed as `[D350]` in the run logs. Using the binned value makes $f=1$ exactly for an MC field of Draine shape, whatever the bins. The correction rests on three approximations. (i) It rescales the energy in the window but not the spectral shape inside it, which matters because the window is emptied from its blue end first (dust extinction rises towards 912 Å and C I absorbs above 11.26 eV). (ii) It is a ratio of energy shares, whereas the rates count photons; the two differ by the ratio of the mean photon energies in the window, which lie between 11.2 and 13.6 eV, so by at most $\sim$<!-- -->20%, and much less where the shape in the window is close to Draine’s. (iii) One factor serves all the sites of the diffuse field ({ref}`sec:sites`). The size of what it corrects is large: the MC field’s window share falls from 0.299 at $A_{V}=0.07$ to 0.152, 0.094, 0.041 and 0.008 at $A_{V}=0.74$, 1.13, 1.70 and 2.50 on `hiipdr` ({devlog}`D-349`), so $f$ runs from 1.9 near the star to 0.05 deep in the PDR. The factors are handed to the vendored code as the per-ray array `ray_lw_factor` ({src}`pdr/calc_reac_rates.F90::CALCULATE_REACTION_RATES@"! D-350: the Lyman-Werner-window factor per ray, when the host supplies"..@"LWF(0:NRAYS-1)=ray_lw_factor(0:NRAYS-1)"`; a local modification listed in `pdr/UPSTREAM.md`). In the 3D build only the CO rate actually uses them: the H$_2$ rate is replaced by the level model, C photoionisation by MOCASSIN’s own rate, and the network has no HD ({ref}`sec:photorates`). The other photoreactions keep the Draine shape ({ref}`sec:generic`).

(sec:eta)=
## Specific intensity and occupation number at each H$_2$ line
The level model needs the field at each of the 32 453 pumping lines rather than a band integral. In `solveCell` ({src}`pdr_mod.f90::h2LevelModel/solveCell@"! ---- the field: J_nu of the direct and the diffuse part per bin, and"..@"etaDir(ln) = 0.d0; etaDif(ln) = 0.d0"`) each bin’s direct and diffuse mean intensities are 

```{math}
J_{\nu,k}^{\mathrm{dir}} = \frac{J^{\mathrm{ste}}_k-J^{\mathrm{dif}}_k}{4\pi\,\Delta\nu_k},\qquad
  J_{\nu,k}^{\mathrm{dif}} = \frac{J^{\mathrm{dif}}_k}{4\pi\,\Delta\nu_k},\qquad
  \Delta\nu_k = \mathrm{widFlx}_k \times 3.28984\times10^{15}\,\mathrm{Hz},
```

 in erg s$^{-1}$ cm$^{-2}$ Hz$^{-1}$ sr$^{-1}$, and every line $lu$ of wavenumber $\tilde\nu_{lu}$ takes the bin that contains it, $\nu_k \le \nu_{lu} < \nu_{k+1}$ (`tBin`, {src}`pdr_mod.f90::h2LevelModel@"! each line's frequency bin, by the rule MOCASSIN places its own line"..@"tBin(ln) = ib; exit"`, the rule MOCASSIN uses to place its own line packets). The photon occupation numbers are 

$$
\eta^{\mathrm{dir}}_{lu} = J^{\mathrm{dir}}_{\nu,k(lu)}\,\frac{c^2}{2h\nu_{lu}^3},\qquad
  \eta^{\mathrm{dif}}_{lu} = J^{\mathrm{dif}}_{\nu,k(lu)}\,\frac{c^2}{2h\nu_{lu}^3},
  \qquad \nu_{lu} = c\,\tilde\nu_{lu}.
$$ (eq:eta)

 Lines outside the frequency grid get $\eta=0$. Lines from vibrationally excited levels that lie below 11.2 eV read their own bins as well, inside or outside the 6–13.6 eV band. The field at a line is the bin average of the continuum, 2% wide: the MC field contains no H$_2$ (or H I Lyman-series) line opacity, and the line shielding is applied afterwards through column densities ({ref}`sec:h2model`). This separation of continuum and line attenuation is exact for a line whose absorption does not change the continuum it sits on. It is not exact for the continuum itself: photons that H$_2$ lines absorb remain in the MC field, where they go on heating the dust, ejecting photoelectrons, photoionising C I and being scattered. The fraction of the band so affected is at most the window’s share and falls to the line cores once the lines saturate; its effect has not been measured.
