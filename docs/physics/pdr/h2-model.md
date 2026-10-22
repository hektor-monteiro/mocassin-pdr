(sec:h2model)=
# The H$_2$ level model
The level model computes, in every cell, the fractional populations of the 302 rovibrational levels of the electronic ground state $X\,^1\Sigma_g^+$ of H$_2$ under the cell’s own radiation field, gas temperature and colliders, and from them the Solomon photodissociation rate per molecule that the chemistry uses ({ref}`sec:photorates`) and three H$_2$ heating terms ({ref}`sec:thermal`). The physics is in {src}`h2_mod.f90` (1570 lines); the driver that supplies the field, the columns, the colliders and the formation distribution is `h2LevelModel` with its internal routine `solveCell` ({src}`pdr_mod.f90::h2LevelModel`). It is a re-implementation, from the data and conventions of Cloudy’s large H$_2$ model {cite:p}`Shaw2005`, of the line-by-line treatment of ultraviolet pumping and self-shielding that the Meudon PDR code {cite:p}`LePetit2006` and the models of {cite:t}`DraineBertoldi1996` also use, in place of a shielding function fitted to such models. It was validated level by level against Cloudy on one-zone and slab models ({devlog}`H-003`–{devlog}`H-006`). Those comparisons isolate three deliberate departures from Cloudy, each discussed below: the closure of the level balance ({ref}`sec:balance`), the damping width of the lines ({ref}`sec:shield`) and the treatment of line overlap ({ref}`sec:overlap`).

**Physical picture.**
A molecule in level $l$ of $X$ absorbs a far-ultraviolet photon in a Lyman ($B\,^1\Sigma_u^+$–$X$) or Werner ($C\,^1\Pi_u$–$X$) line, or in one of the weaker $B'\,^1\Sigma_u^+$–$X$ and $D\,^1\Pi_u$–$X$ lines; out of $v=0$ the Lyman and Werner lines lie between 912 and 1110 Å (11.2–13.6 eV), and the $B'$ and $D$ systems reach below 912 Å. Within about a nanosecond the excited level $u$ decays, either into the vibrational continuum of $X$, which dissociates the molecule into two H(1s) atoms (the Solomon process), or into a bound level of $X$, mostly vibrationally excited, from which a slow electric-quadrupole cascade ($A=3\times10^{-11}$–$6\times10^{-6}$ s$^{-1}$, median $2\times10^{-8}$ s$^{-1}$ in `transprob_X.dat`) competes with collisions. In an unshielded field of the Draine shape the model dissociates one molecule per 8.1 absorptions, at $6.36\times10^{-11}$ s$^{-1}$ per unit Draine field ({devlog}`H-007`); the mean dissociation probability per absorption is 0.12 in the computations of {cite:t}`Sternberg2014` and about 0.15 when averaged through complete photodissociation fronts {cite:p}`DraineBertoldi1996`. The strong lines out of a level become optically thick at level columns of order $10^{14}$ cm$^{-2}$, saturate, and above $\sim10^{17}$–$10^{18}$ cm$^{-2}$ absorb mainly in their Lorentzian wings, where above $N(\mathrm{H_2})\sim10^{20}$ cm$^{-2}$ the lines of different levels overlap {cite:p}`DraineBertoldi1996`. The dissociation rate in a cell therefore depends on the field at every line, on the column of every level along the paths of the photons, on the line widths, and on the populations of the absorbing levels, which the pumping itself changes. The model treats all of these line by line.

(sec:h2data)=
## Data
All data are Cloudy c25.00’s (`dataPDR/h2/`, copied unmodified; provenance in `dataPDR/h2/README.md`). The reading rules are Cloudy’s: a line starting with `#` is a comment, and the data of the excited-state files end at the first empty line. The sources in {numref}`tab:h2data` are those that the files’ own headers give, completed where the header is not the primary source.

:::{list-table} Data of the H$_2$ level model. Temperature ranges are those of the tables; coverage is given as the upper levels present.
:name: tab:h2data
:header-rows: 1
:widths: 33 28 33

* - Content
  - File(s)
  - Source
* - energies of the $X$ rovibrational levels (302 levels, $v\le14$, $J\le31$; sorted by energy)
  - `energy_X.dat`
  - {cite:t}`Komasa2011`, their Table 1, compiled by K. Kaplan (header)
* - radiative transition probabilities within $X$: electric quadrupole, plus magnetic-dipole components of 30 $v=1\to0$, $\Delta J=0$ transitions listed separately and summed
  - `transprob_X.dat`
  - {cite:t}`Wolniewicz1998`; magnetic dipole {cite:t}`PachuckiKomasa2011`
* - H + H$_2$: 1432 transitions, $v\le3$, $J\le17$, 728 of them ortho$\leftrightarrow$para (reactive); 100–5000 K
  - `coll_rates_H_15.dat`
  - {cite:t}`Lique2015`
* - He + H$_2$: 3251 transitions, $v\le14$, $J\le30$, no spin change; 1–$10^4$ K
  - `coll_rates_He_ORNL.dat`
  - ORNL data set; the header cites “Lee, T. G. et al. 2007, ApJ, in preparation”; no published source for this table was identified
* - ortho- and para-H$_2$ + H$_2$: 240 and 241 transitions, $v=0$, $J\le31$; 1–$10^4$ K
  - `coll_rates_H2ortho_ORNL.dat`, `coll_rates_H2para_ORNL.dat`
  - {cite:t}`Wan2018`
* - H$^+$ + H$_2$: 44 transitions, $v=0$, $J\le9$, 24 of them ortho$\leftrightarrow$para (proton exchange); 3–6000 K
  - `coll_rates_Hp.dat`
  - {cite:t}`Gerlich1990`
* - energies of the rovibrational levels of $B$, $C^+$, $C^-$, $B'$, $D^+$, $D^-$ (1592 levels)
  - `energy_{B,C_plus,…}.dat`
  - derived from {cite:t}`Abgrall2000` (headers)
* - transition probabilities of the 32 453 lines to $X$
  - `transprob_*.dat`
  - {cite:t}`Abgrall2000`, from the band-system calculations of {cite:t}`Abgrall1993` ($B$–$X$, $C$–$X$) and {cite:t}`Abgrall1994` ($B'$–$X$, $D$–$X$)
* - spontaneous radiative dissociation rate $D_u$ \[s$^{-1}$\] and mean kinetic energy of the atoms \[eV\] per excited level
  - `dissprob_*.dat`
  - {cite:t}`Abgrall2000`
* - dissociation energy of $X$, $D=36\,118.11$ cm$^{-1}$ (4.478 eV; the only value of the file the model uses)
  - `energy_dissoc.dat`
  - {cite:t}`Sharp1970` per the header (which dates it 1971), with values revised in Cloudy in 2002
:::

Reading: `h2ReadX` ({src}`h2_mod.f90::h2ReadX`) and `h2ReadElec` ({src}`h2_mod.f90::h2ReadElec`). Statistical weights are $g=(2J+1)(2I+1)$, with nuclear-spin factor $2I+1=3$ for ortho and 1 for para. In $X$ ortho levels have odd $J$; in the excited states $B$, $B'$ and the $\Pi^+$ components $C^+$, $D^+$ ortho levels have even $J$, and in the $\Pi^-$ components $C^-$, $D^-$ odd $J$, following Cloudy {cite:p}`Shaw2005`: this is the assignment under which every allowed transition ($\Delta J=\pm1$ to the $\Sigma_u^+$ states and the $\Pi^+$ components, $\Delta J=0$ to the $\Pi^-$ components) conserves the nuclear spin, and the reader counts the lines that would not (none, {devlog}`H-004`). The $\Pi$ states have no $J=0$ level. The $D^-$ state stops at $v=2$ because Cloudy’s file has an empty line before the levels it marks “above the dissociation limit”; 3138 $D^-$ lines are dropped with them, and 392 lines whose lower level lies beyond the 302 levels of $X$ ({devlog}`H-004`). The dissociation rates $D_u$ are those of spontaneous emission into the vibrational continuum of $X$ {cite:p}`Abgrall2000`. Apart from 45 high-$J$ levels of $D^-$ ($v\le2$), all the excited levels lie below the H(1s) + H($n=2$) limit (118 376 cm$^{-1}$ in `energy_dissoc.dat`), where this radiative channel is the only way they dissociate; predissociation, which acts above that limit, is not in the data. A transition listed twice adds its components, as Cloudy does; reading the $X$ file without adding the magnetic-dipole components had doubled the $v=1$ populations at low density ({devlog}`H-003`). The lines are stored sorted by upper level (counting sort) and indexed by wavenumber (heapsort) for the overlap calculation.

(sec:balance)=
## Statistical equilibrium and the formation closure
Let $n_i$ be the fraction of the cell’s H$_2$ molecules in level $i$ of $X$ ($\sum_i n_i=1$). The populations solve (`balance`, {src}`h2_mod.f90::balance`) 

$$
\sum_{j\neq i} n_j R_{ji} - n_i\Bigl(\sum_{j\neq i} R_{ij} + k_i\Bigr)
  + \phi_i \sum_j n_j k_j + s_i = 0,\qquad i=1,\ldots,302,
$$ (eq:balance)

 where $R_{ij}$ \[s$^{-1}$\] is the total rate per molecule from level $i$ to level $j$ (collisions, spontaneous decay within $X$ and the fluorescent transfer through the excited states; {ref}`sec:coll` and {ref}`sec:pump`), $k_i$ \[s$^{-1}$\] the Solomon dissociation rate out of level $i$, $\phi_i$ the fraction of newly formed molecules that enter level $i$ ($\sum_i\phi_i=1$; {ref}`sec:formdist`) and $s_i$ \[s$^{-1}$\] an optional further source per molecule, not used by `solveCell`. Fluorescent returns to the absorbing level ($R_{ii}$) drop out. Summed over $i$, the transfer terms cancel and so do the dissociation and formation terms, so the system conserves $\sum_in_i$: the term $\phi_i\sum_jn_jk_j$ is the closure *every molecule destroyed by the Solomon process is replaced by one formed*. The level model determines how the molecules are distributed over the levels; how many there are is the chemistry’s ({ref}`sec:chemistry`).

**Numerics.**
The equation of level 1 is replaced by $\sum_in_i=1$ and the $302\times302$ system is solved directly by Gaussian elimination with partial pivoting (`gaussSolve`, {src}`h2_mod.f90::gaussSolve`; about $n^3/3\approx9\times10^6$ operations per solution). `h2Solve` ({src}`h2_mod.f90::h2Solve`) assembles $R=C+A+W$ (collisions, radiative decay, fluorescent transfer) and the $k_i$, and calls it. The populations of the validation runs were never negative and summed to unity to the printed precision ({devlog}`H-003`). Cloudy instead solves its lowest 70 levels by matrix inversion and the others one by one ({devlog}`H-010`).

**Validity of the closure.**
In steady state the chemistry’s formation rate per molecule, $R_{\mathrm f}\,n_{\mathrm H}\,n(\mathrm H)/n(\mathrm{H_2})$, equals the sum of all destruction rates per molecule, of which $k_{\mathrm{Sol}}$ is one; the closure sets the formation flux into the levels equal to $k_{\mathrm{Sol}}$ alone. It is therefore exact where photodissociation dominates the destruction (93–100% of the H$_2$ destruction out to 0.43 pc in `pn150k`, {devlog}`H-009`), and underestimates the formation flux by the factor $k_{\mathrm{Sol}}/(k_{\mathrm{Sol}}+k_{\mathrm{other}})$ elsewhere. The network’s three H$_2$ + CRP channels alone give $k_{\mathrm{other}}=0.99\,\zeta$, $1.0\times10^{-16}$ s$^{-1}$ at the default `pdrZeta`, so the closure fails where the Solomon rate is shielded below a few $10^{-16}$ s$^{-1}$, a reduction by more than $10^5$ from its unshielded value at $\chi\sim1$. There the formation pumping of the $v\ge1$ levels, the infrared emission it produces and the part of the formation energy that reaches the gas by collisional de-excitation are underestimated; the Solomon rate itself is affected only through the populations of the absorbing levels, and the kinetic part of the formation energy follows the chemistry’s own formation rate ({ref}`sec:thermal`; {ref}`sec:limitations`). Cloudy closes its level system differently: it applies its network’s Solomon rate a second time as a uniform sink on the levels below 4100 cm$^{-1}$, solves without a sum rule and rescales all populations by one factor (1.06–1.11 in one-zone models with $n_{\mathrm H}\le10^4$ cm$^{-3}$ and fields up to 100 Habing). Put through that scheme, this model’s rates reproduce Cloudy’s populations to 0.002–0.018 dex in 15 of 16 such models, against a median difference of 0.07 dex with its own closure ({devlog}`H-004`); Cloudy’s closure raises the pumped line intensities by about 1.2 ({devlog}`H-009`).

(sec:coll)=
## Collisional and radiative rates within $X$
`h2CollRad` ({src}`h2_mod.f90::h2CollRad`) adds, for every pair of levels $u>l$ (energies $E$ in cm$^{-1}$), 

$$
R_{ul} \mathrel{+}= \sum_c n_c\,k^c_{ul}(T) + A_{ul},\qquad
  R_{lu} \mathrel{+}= \sum_c n_c\,k^c_{ul}(T)\,\frac{g_u}{g_l}\,e^{-hc(E_u-E_l)/kT},
$$ (eq:collrad)

 with $n_c$ \[cm$^{-3}$\] the density of collider $c\in\{\mathrm H,\,\mathrm{He},\,o\text{-H}_2,\,p\text{-H}_2,\,\mathrm H^+\}$, $k^c_{ul}$ \[cm$^3$ s$^{-1}$\] its de-excitation rate coefficient, $A_{ul}$ \[s$^{-1}$\] the radiative transition probability, and $T=\max(T_e,1\,\mathrm K)$ ({src}`pdr_mod.f90::h2LevelModel/solveCell@"T = max(dble(grid(1)%Te(cellP)), 1.d0)"`):

- downward coefficients from the tables of {numref}`tab:h2data`, interpolated linearly in $T$ and held at the end values outside the tabulated range (`tabRate`, {src}`h2_mod.f90::tabRate`; Cloudy’s `InterpCollRate` convention). Below 100 K the H + H$_2$ rates are therefore those of 100 K, which overestimates the reactive (ortho–para) channels, whose barrier makes them fall steeply with temperature; above 5000 K (H), 6000 K (H$^+$) and $10^4$ K (He, H$_2$) the rates are those of the table’s end;

- for a pair of levels of the same nuclear spin that a collider’s table does not contain, the “g-bar” estimate of {cite:t}`Shaw2005`, their eq. 1 and
  Table 2, 

$$
\log_{10}\bigl(k^c_{ul}/\mathrm{cm^3\,s^{-1}}\bigr) = y_0 + a_g\,\bigl[\max(\Delta E,\,100)\bigr]^{b_g},
      \qquad \Delta E = E_u-E_l\ [\mathrm{cm^{-1}}],
$$ (eq:gbar)

 a fit, per collider, of the rate coefficients then available as a function of the energy gap (coefficients in {numref}`tab:gbar`; Cloudy’s `GbarRateCoeff`), which {cite:t}`Shaw2005` found to lie within 1 dex of 60–70% of the rates it was fitted to. A pair that changes the nuclear spin and is not in a table has no collisional rate;

- upward rates by detailed balance at the gas temperature, so that collisions alone relax the populations to a Boltzmann distribution at $T$;

- spontaneous radiative decay $A_{ul}$ (quadrupole plus magnetic dipole) from `transprob_X.dat`.

:::{list-table} g-bar coefficients of Equation ({eq}`eq:gbar`) ({src}`h2_mod.f90@"real(dp), parameter :: gbar(3, h2NColl) = reshape( (/ &"`), identical to Table 2 of {cite:t}`Shaw2005`.
:name: tab:gbar
:header-rows: 1

* - Collider
  - $y_0$
  - $a_g$
  - $b_g$
* - H
  - $-9.9265$
  - $-0.1048$
  - 0.456
* - He
  - $-8.281$
  - $-0.1303$
  - 0.4931
* - $o$-H$_2$
  - $-10.0357$
  - $-0.0243$
  - 0.67
* - $p$-H$_2$
  - $-8.6213$
  - $-0.1004$
  - 0.5291
* - H$^+$
  - $-9.2719$
  - $-0.0001$
  - 1.0391
:::

**Coverage.**
Of the 22 675 pairs of levels of the same nuclear spin, the tables contain 703 for H, 3250 for He, 240 and 239 for $o$- and $p$-H$_2$ and 20 for H$^+$ (counted from the data files); the remaining 86–99.9% take Equation ({eq}`eq:gbar`). Ortho and para are coupled by collisions only through the 728 reactive H + H$_2$ transitions ($v\le3$) and the 24 proton-exchange H$^+$ + H$_2$ transitions ($v=0$, $J\le9$), the latter being by far the faster {cite:p}`Shaw2005`. The tabulated pairs include the low-$J$ levels of $v=0$ that carry most of the column; the g-bar rates matter where collisions compete with radiative decay in levels without data, i.e. high-$v$ or high-$J$ levels at high density, and {cite:t}`Shaw2005` found the populations of the tabulated low levels nearly insensitive to them.

**Colliders.**
The collider densities ({src}`pdr_mod.f90::h2LevelModel/solveCell@"dens = (/ nH*grid(1)%pdrAbun(cellP,pdrNHsp), nH*grid(1)%pdrAbun(cellP,NHe), &"`) are taken from the chemistry’s abundances of the previous iteration, $n(\mathrm H)=n_{\mathrm H}x(\mathrm H)$, $n(\mathrm{He})$ and $n(\mathrm H^+)$, and from the cell’s own solution for the spin split, $n(o\text{-H}_2)=f_o\,n(\mathrm{H_2})$, $n(p\text{-H}_2)=(1-f_o)\,n(\mathrm{H_2})$, with $f_o=\sum_{i\in\mathrm{ortho}} n_i$ iterated to self-consistency ({ref}`sec:solvecell`). Electrons are not a collider, as in Cloudy; {cite:t}`AlemanGruenwald2011` include them in their models of the H$_2$ emission of the ionised region of planetary nebulae. Where electrons are a large fraction of the colliders, in the ionised gas and at the ionisation front, the collisional excitation of H$_2$ is therefore underestimated, in gas whose H$_2$ abundance is in any case uncertain ({lim}`L-43`). The rate coefficients and Boltzmann factors are cached for the last temperature (`crKd`, `crBf`), so the iterations over the colliders’ densities at fixed $T$ rebuild only $R$.

(sec:pump)=
## Ultraviolet pumping, Solomon dissociation and trapping
A molecule in $X$ level $l$ is excited in the line $l\to u$ at the rate 

$$
P_{lu} = B_{lu}\,\bar J_{lu} = A_{ul}\,\frac{g_u}{g_l}\,\eta_{lu}\quad[\mathrm{s^{-1}}],
  \qquad
  \eta_{lu} = \frac{c^2}{2h\nu_{lu}^3}\,J_\nu(\nu_{lu}),
$$ (eq:pump)

 where $\bar J_{lu}$ is the mean intensity averaged over the line profile and $\eta_{lu}$ the photon occupation number at the line after shielding ({ref}`sec:eta` and {ref}`sec:shield`); the second form follows from the Einstein relations for a field constant across the line. In the unshielded Draine field $\eta\approx2\times10^{-19}$ near 12 eV.

The excited levels have radiative lifetimes of 0.5–9 ns in these data (total decay rates $\Gamma_u=1.1\times10^8$–$1.9\times10^9$ s$^{-1}$, median $\approx10^9$ s$^{-1}$ for $B$ and $C$). Collisions cannot compete with that below $\sim10^{14}$ cm$^{-3}$ {cite:p}`Shaw2005`, and the excited populations, of order $\sum_lP_{lu}/\Gamma_u\sim10^{-18}\chi$ per molecule, are never a reservoir: every absorption is followed at once by a decay, into the continuum of $X$ (dissociation) or into a bound level of $X$. The excited states are therefore not solved for. With the effective decay rates 

$$
A^{\mathrm{eff}}_t = A_t\,(1+\eta_t)\,\beta_t,
  \qquad
  \Gamma^{\mathrm{eff}}_u = D_u + \sum_{t\in u} A^{\mathrm{eff}}_t ,
$$ (eq:aeff)

 where $t$ runs over the lines from $u$ to bound levels of $X$, $1+\eta_t$ accounts for stimulated emission (negligible, kept for completeness), $\beta_t$ is the escape probability of a photon emitted in line $t$ ({ref}`sec:escape`) and $D_u$ the spontaneous radiative dissociation rate of $u$, `h2PumpRates` ({src}`h2_mod.f90::h2PumpRates`) returns 

```{math}
\begin{align}
  k_l &= \sum_u P_{lu}\,\frac{D_u}{\Gamma^{\mathrm{eff}}_u}
       && \text{(Solomon dissociation out of } l\text{)},\\
  W_{ll'} &= \sum_u P_{lu}\,\frac{A^{\mathrm{eff}}_{ul'}}{\Gamma^{\mathrm{eff}}_u}
       && \text{(fluorescent transfer } l\to l'\text{)},\\
  H^{\mathrm{dis}}_l &= \sum_u P_{lu}\,\frac{D_u}{\Gamma^{\mathrm{eff}}_u}\,E^{\mathrm{kin}}_u
       && \text{(kinetic energy given to the atoms [eV\,s}^{-1}\text{])},
\end{align}
```

 and the total absorption rate $p_l=\sum_u P_{lu}$, with $E^{\mathrm{kin}}_u$ the mean kinetic energy released per dissociation of $u$ (`dissprob_*.dat`). The first step of the fluorescent cascade is $W$; the quadrupole cascade that follows is carried by $A$ in Equation ({eq}`eq:balance`). The Solomon rate per molecule handed to the chemistry is 

$$
k_{\mathrm{Sol}} = \sum_l n_l\,k_l
$$ (eq:ksol)

({src}`pdr_mod.f90::h2LevelModel/solveCell@"r1Tmp(cellP,1) = real(sum(pops*kdiss))"`).

**Trapping.**
A photon emitted in a line $t=u\to l'$ that is optically thick is absorbed again close by, by a molecule in $l'$, which it re-excites to the same level $u$. In the escape-probability (“on-the-spot”) approximation the net effect is that the decay rate of the line is reduced to $A_t\beta_t$, and the level’s other decays and its dissociation take its share in $\Gamma^{\mathrm{eff}}_u$. Only lines that end in populated low levels are thick, so trapping closes the decays to $v=0$ and raises the dissociation probability $D_u/\Gamma^{\mathrm{eff}}_u$ in thick gas. It is needed: without it the rate into $v=0$, $J=0$–5 from the excited states was up to 2200 times Cloudy’s in the shielded zones of the slab of {devlog}`H-005` and the Solomon rate 10–20% low; with it the Solomon rate comes within 3–8% of Cloudy’s ({devlog}`H-005`). The total absorption rate $p_l$ counts only the external field. Photons that dust or an overlapping H$_2$ line absorb before they escape are not counted as lost (Cloudy adds such a destruction probability to the escape probability, {cite:t}`Shaw2005`); this slightly overestimates the dissociation probability of levels whose decays are trapped.

(sec:shield)=
## Self-shielding of the pumping lines
**Line parameters.**
For line $lu$ of wavelength $\lambda=1/\tilde\nu_{lu}$ \[cm\] (`h2LineParams`, {src}`h2_mod.f90::h2LineParams`), 

$$
\sigma_{lu} = \frac{g_u}{g_l}\,\frac{A_{ul}\,\lambda^3}{8\pi^{3/2}\,b}\ [\mathrm{cm^2}],\qquad
  \tau_0 = \sigma_{lu}N_l,\qquad
  a = \frac{\Gamma_u\,\lambda}{4\pi\,b},\qquad
  \Gamma_u = D_u + \sum_{t\in u}A_t ,
$$ (eq:lineparams)

 where $\sigma_{lu}$ is the line-centre cross section of a pure Doppler profile of Doppler width $\Delta\nu_D=b/\lambda$, $(\pi e^2/m_ec)f_{lu}/(\sqrt\pi\Delta\nu_D)$ written with $A_{ul}$; $N_l$ \[cm$^{-2}$\] is the column of molecules in level $l$; $b=\sqrt{2kT/m_{\mathrm{H_2}}+v_{\mathrm{turb}}^2}$ \[cm s$^{-1}$\] the Doppler parameter of the target cell ({src}`pdr_mod.f90::h2LevelModel/solveCell@"b = sqrt(2.d0*dble(kBoltzmann)*T/mH2g + (dble(pdrVturb)*1.d5)**2)"`; $v_{\mathrm{turb}}$ is `pdrVturb`, default 1 km s$^{-1}$); and $a$ the Voigt damping parameter, the ratio of the Lorentzian half width $\Gamma_u/4\pi$ to $\Delta\nu_D$. $\Gamma_u$ is the total decay rate of the upper level, bound–bound plus bound–free (spontaneous radiative dissociation), i.e. the inverse radiative lifetime; since the lower level of every line is a metastable level of $X$, $\Gamma_u$ is the natural width of the line. With these data $a\le0.03$ for $b\ge1$ km s$^{-1}$ (median 0.006 at 100 K and the default $v_{\mathrm{turb}}$).

**The damping width.**
$\Gamma_u$ exceeds a line’s own $A_{ul}$ by a factor 20 in the median over the thick lines of the {devlog}`H-005` slab (16–84%: 7.8–157), and the shielding in the damping wings scales as $a^{1/2}$ (Eq. {eq}`eq:Sasym`). Cloudy damps each H$_2$ line with its own $A_{ul}$ (`dampXvel`$\,=A_{ul}\lambda/4\pi$ in `mole_h2_create.cpp` of c25.00, and in its saved damping constants, {devlog}`H-005`), whereas its hydrogenic lines use the lifetime of the upper level (`iso_create.cpp`). The natural width is the physical choice. Cloudy’s lowers the transmission in the damping regime by $\sqrt{20}\approx4.5$ for the median thick line (2.8–12.5 for the 16–84% range) (pumped lines behind more than $10^{16}$ cm$^{-2}$ of H$_2$ fall to 0.18–0.41 of their intensity, {devlog}`H-008`) and moves the H/H$_2$ crossing 0.21 mag shallower on `hiipdr` and 0.10 mag on `pn150k` ({devlog}`H-026`; {ref}`sec:limitations`). The same $b$ (the target cell’s) is used for the whole column in front of the cell and along the escape rays; this matters in the Doppler-saturated regime, where $\tau_0\propto b^{-1}$, and not in the damping regime, where the equivalent width in frequency does not depend on $b$.

**Transmission and curve of growth.**
The rate at which a molecule behind the column $N_l$ absorbs in the line, relative to the unshielded rate for a continuum flat across the line, and its integral over $\tau_0$ are 

```{math}
:label: eq:SW
\begin{align}
  S(\tau_0,a) &= \frac{1}{\sqrt\pi}\int_{-\infty}^{\infty} H(a,x)\,
       \exp\!\left[-\tau_0\frac{H(a,x)}{H(a,0)}\right]\mathrm{d}x,\\
  W(\tau_0,a) &= \int_0^{\tau_0} S\,\mathrm{d}\tau
      = \frac{2H(a,0)}{\sqrt\pi}\int_0^{\infty}\left\{1-\exp\!\left[-\tau_0\frac{H(a,x)}{H(a,0)}\right]\right\}\mathrm{d}x ,
\end{align}
```

 with $x=(\nu-\nu_{lu})/\Delta\nu_D$ and $H(a,x)=(a/\pi)\int e^{-y^2}[(x-y)^2+a^2]^{-1}\mathrm{d}y$ the Voigt function ($\int H\,\mathrm{d}x=\sqrt\pi$), evaluated with the rational approximation of {cite:t}`Humlicek1982` (relative accuracy $10^{-4}$; `h2Voigt`, {src}`h2_mod.f90::h2Voigt`). $S$ is the single-line self-shielding function: the profile-weighted transmission, $S(0,a)=1$. $W$ is the equivalent width in units of $\sqrt\pi\Delta\nu_D/H(a,0)$, normalised so that $W\to\tau_0$ for $\tau_0\ll1$, and $\mathrm{d}W/\mathrm{d}\tau_0=S$. The three regimes are 

$$
S \simeq \begin{cases}
    1-\tau_0/\sqrt2 & (\tau_0\ll1),\\[2pt]
    \bigl[\sqrt\pi\,\tau_0\,(\ln\tau_0)^{1/2}\bigr]^{-1} & \text{(saturated Doppler core)},\\[2pt]
    \pi^{-1/4}\,\bigl[H(a,0)\,a/\tau_0\bigr]^{1/2} & \text{(damping wings)},
  \end{cases}
$$ (eq:Sasym)

 the first two for $a\to0$, the third when the absorption is dominated by the Lorentzian wings $H\simeq a/(\sqrt\pi x^2)$.

**Profile normalisation.**
$\tau_0=\sigma_{lu}N_l$ is the line-centre optical depth of the Doppler core, and $S$ normalises the profile to its own centre, $\tau(x)=\tau_0H(a,x)/H(a,0)$; with this convention $\tau_0$ agrees with Cloudy’s line optical depths to 0.04% ({devlog}`H-005`). The area-normalised Voigt profile gives $\tau(x)=\tau_0H(a,x)$, smaller by the factor $H(a,0)\simeq1-2a/\sqrt\pi$ at every frequency. For these data the difference is at most 3% in $\tau$ (0.8% weighted by the unshielded pumping, and half that in $S$ in the damping regime), negligible against the other uncertainties.

**Numerical strategy.**
`shieldQuad` ({src}`h2_mod.f90::shieldQuad`) integrates one side of the profile with the trapezoidal rule on 1200 uniform points to $x=6$ and logarithmically (60 points per decade) beyond, to $x_{\max}=\max(60,\,300\sqrt{\tau_0 a})$; beyond $x_{\max}$ the Lorentzian wing $H\simeq a/(\sqrt\pi x^2)$ is optically thin ($\tau\le10^{-5}$ at $x_{\max}=300\sqrt{\tau_0a}$) and is added analytically. It also records the offsets $x_q$ at which $1/6$, $1/2$ and $5/6$ of one side’s absorption, $\int H e^{-\tau}\mathrm{d}x$, has accumulated, for the overlap quadrature. Against an independent quadrature (the Faddeeva function of SciPy) $S$ and $W$ agree to 0.04% and 0.03% over $\tau_0=10^{-2}$–$10^{11}$, $a=10^{-6}$–$10^{-1}$ ({devlog}`H-005`). `shieldTable` ({src}`h2_mod.f90::shieldTable`) tabulates $\log S$, $\log W$ and $\log x_q$ once on a $161\times29$ grid, $\log_{10}\tau_0\in[-4,16]$ (step 0.125) and $\log_{10}a\in[-7,0]$ (step 0.25). Look-up (`tabShieldJ`, {src}`h2_mod.f90::tabShieldJ`) is bilinear in $(\log\tau_0,\log a)$ on the logarithms; below the table $S=1$ and $W=\tau_0$; above it the damping-wing asymptote, $S\propto\tau_0^{-1/2}$, $W\propto\tau_0^{1/2}$. The table’s $S$ is within 1.2% of the exact single-line integral ({devlog}`H-006`). The damping parameter’s column and fraction in the table are found once per line (`h2ShieldAIndex`, {src}`h2_mod.f90::h2ShieldAIndex`).

**Comparison with shielding functions.**
A shielding-function treatment writes the Solomon rate as $k_{\mathrm{Sol}}\simeq k_{\mathrm{Sol}}(0)\,
f_{\mathrm{shield}}(N_{\mathrm{H_2}})\,e^{-\tau_{d,1000}}$ ({cite:alp}`DraineBertoldi1996`, their
eq. 40), with $\tau_{d,1000}$ the dust optical depth at 1000 Å and $f_{\mathrm{shield}}$ a fit to multi-line models for given populations, temperature and field shape. The fit of {cite:t}`DraineBertoldi1996`, their
eq. 37, 

$$
\begin{split}
  f_{\mathrm{shield}} &= \frac{0.965}{(1+x/b_5)^2}+\frac{0.035}{(1+x)^{1/2}}\,
     \exp\!\left[-8.5\times10^{-4}(1+x)^{1/2}\right],\\
  x&=\frac{N(\mathrm{H_2})}{5\times10^{14}\,\mathrm{cm^{-2}}},\qquad b_5=\frac{b}{\mathrm{km\,s^{-1}}},
  \end{split}
$$ (eq:db96)

 describes the saturation of the lines in its first two terms and their overlap in the exponential. 3D-PDR’s own rate uses the single-line function of {cite:t}`Federman1979` for one representative line ({ref}`sec:h2rate`). Here the equivalent of $f_{\mathrm{shield}}$ follows from the level columns, the line widths, the populations and the field at each line, and the dust attenuation is in the MC field. On the Cloudy slab of {devlog}`H-005` (100 K, $n_{\mathrm H}=10^4$ cm$^{-3}$, 100 Habing, $b=0.91$ km s$^{-1}$) the model without overlap followed Equation ({eq}`eq:db96`) without its overlap factor to 0.79–1.00 at $N(\mathrm{H_2})=10^{18}$–$10^{21}$ cm$^{-2}$, and with overlap it lies at 0.70–0.95 of the full fit there and 20–50% above it at $10^{14}$–$10^{17}$ cm$^{-2}$ ({devlog}`H-005`, {devlog}`H-006`). The analytic theory of the H I-to-H$_2$ transition of {cite:t}`Sternberg2014`, in which the total atomic column of a slab in a beamed field is $N_{\mathrm{H\,I}}=\sigma_g^{-1}\ln(\alpha G/2+1)$ (their eq. 40), with $\sigma_g$ the far-ultraviolet dust absorption cross section per H nucleus, $\alpha$ the ratio of the free-space dissociation rate to the formation rate $R_{\mathrm f}n$ and $G$ a cloud-averaged self-shielding factor, rests on the same kind of line-by-line computation (an “effective dissociation bandwidth” computed with the Meudon code).

(sec:ownavg)=
## Averaging through the cell’s own column
The pumping rate that the level balance of a cell needs is its mean over the cell, whose populations are uniform. If the cell adds $\Delta\tau=\sigma_{lu}\Delta N_l$ to the column $\tau_0$ in front of it, the mean of $S$ over a uniform layer traversed along one chord is the mean slope of the curve of growth across it (`h2Shield`, `h2ShieldJ`, {src}`h2_mod.f90::h2Shield`, {src}`h2_mod.f90::h2ShieldJ`; `h2LineShieldPrep/Eval`, {src}`h2_mod.f90::h2LineShieldPrep`, {src}`h2_mod.f90::h2LineShieldEval`): 

$$
\langle S\rangle = \frac{W(\tau_0+\Delta\tau,a)-W(\tau_0,a)}{\Delta\tau}
  \quad\text{if }\Delta\tau > 10^{-3}\max(\tau_0,10^{-3}),
  \qquad\text{else } S(\tau_0+\tfrac12\Delta\tau,a),
$$ (eq:cellavg)

 clamped to $[0,1]$; the second form avoids the cancellation in the difference of $W$ for thin layers, with an error of order $\Delta\tau^2 S''/24$. A cell whose own column takes its lines from thin to saturated absorbs the band in its front part, and $\langle S\rangle$ is then much smaller than $S(\tau_0)$. The cell’s own column of level $l$ is $\Delta N_l = n_l\,n(\mathrm{H_2})\,\ell$ with two path lengths ({src}`pdr_mod.f90::h2LevelModel/cWid`, {src}`pdr_mod.f90::h2LevelModel/solveCell@"! the cell: its widths, and its mean chord over all directions, 4 V / A"..@"dN = dble(grid(1)%h2Pop(cellP,:))*dnH2*chordIso"`, {src}`pdr_mod.f90::h2LevelModel/solveCell@"! ---- the direct part: the star-ward column, averaged through the cell"..@"if (fTot > 0.d0) chord = chord/fTot"`): 

```{math}
\begin{align}
  \ell_{\mathrm{dir}} &= \frac{\Delta x\,\Delta y\,\Delta z}{\Delta y\Delta z\,|u_x|+\Delta x\Delta z\,|u_y|+\Delta x\Delta y\,|u_z|},\\
  \ell_{\mathrm{iso}} &= \frac{4V}{A} = \frac{2\,\Delta x\,\Delta y\,\Delta z}{\Delta x\Delta y+\Delta y\Delta z+\Delta x\Delta z},
\end{align}
```

 where $\ell_{\mathrm{dir}}$ is the mean chord of the cell along the unit vector $\hat u$ towards the source (the volume over the area projected on a plane normal to $\hat u$), averaged over sources with weights $r_s^{-2}$ and used for the direct beam, and $\ell_{\mathrm{iso}}$ is Cauchy’s mean chord of a convex body for isotropically distributed lines, used for the diffuse light. The widths $\Delta x,\Delta y,\Delta z$ are centred differences of the axis values (`cWid`), one-sided at the first and last axis value; there the full spacing is used, although the outermost cell of a grid that ends at its last axis value is half as wide. One representative chord stands for the distribution of chord lengths through the cell. The direct-path column uses the populations of the current pass of the cell’s iteration, the diffuse one those of the previous sweep.

This is how the level model includes the self-shielding of the cell’s own H$_2$, which the chemistry’s columns leave out ({ref}`sec:avradial`). Averaging the transmission through the cell is a different operation from adding the cell’s near half to the shielding column, which made the chemistry’s surface cell shield itself completely and settle on a self-shielded branch ({devlog}`D-088`). The size of the effect shows how thin the pumping layer is: when the diffuse part was first computed without the cell’s own column, the Solomon rate where H$_2$ turns on was 4–12 times the chemistry’s, and averaging through the mean chord lowered the 1–0 S(1) luminosity of the test model by a factor 4.6 ({devlog}`H-007`). The average is exact for a uniform cell; cells across the H/H$_2$ transition are not, and on `hiipdr` the 1–0 S(1) luminosity changed by $+35\%$ from $21^3$ to $31^3$ and by $+3\%$ from $31^3$ to $41^3$ cells while the H$_2$ profile of the transition was still moving ({devlog}`H-007`).

(sec:overlap)=
## Line overlap
The H$_2$ lines shade one another. Each line’s transmission is its own $S$ times the mean transmission of all the *other* lines over the frequencies where it absorbs (`lineOverlap`, {src}`h2_mod.f90::lineOverlap`, {devlog}`H-006`): 

$$
\mathcal{O}_i = \frac16\sum_{k=1}^{3}\sum_{s=\pm1}
     \exp\!\Bigl[-\tau_{\mathrm{oth}}\bigl(\tilde\nu_i + s\,x_{q,k}\,\Delta\tilde\nu_{D,i}\bigr)\Bigr],
  \qquad
  \tau_{\mathrm{oth}}(\tilde\nu) = \sum_{j\neq i,\ \tau_{0,j}\ge10^{-2}} \tau_{0,j}\,\frac{H(a_j,x_j)}{H(a_j,0)},
$$ (eq:overlap)

 with $x_j=(\tilde\nu-\tilde\nu_j)/\Delta\tilde\nu_{D,j}$ and $\Delta\tilde\nu_{D,j}=\tilde\nu_j b/c$ \[cm$^{-1}$\]. $\mathcal{O}_i$ approximates $\int\phi_ie^{-\tau_i}e^{-\tau_{\mathrm{oth}}}\mathrm{d}\nu\big/\int\phi_ie^{-\tau_i}\mathrm{d}\nu$, the mean of $e^{-\tau_{\mathrm{oth}}}$ weighted by line $i$’s own absorption, by a midpoint rule in the cumulative absorption: each side of the line is cut into three parts that carry equal shares of its absorption, and each part is represented by the offset $x_{q,k}$ that halves its share ($1/6$, $1/2$ and $5/6$ of the side). A thin line thus samples its core and a damped line its wings, hundreds of Doppler widths out. Three points per side were chosen by test: against an exact reference the factor on the Solomon rate is 0.86–1.03 with one point per side, 0.99–1.02 with two and 0.98–1.04 with three, and the line-by-line rms falls from 0.03–0.45 to 0.03–0.21 ({devlog}`H-006`). Numerically:

- only lines with $\tau_0\ge10^{-2}$ shade; a shading line’s reach is $\Delta\tilde\nu_D\max\bigl(12,\sqrt{\tau_0 a/(\sqrt\pi H(a,0)\,\varepsilon)}\bigr)$ with $\varepsilon=10^{-4}$, the offset where its wing optical depth falls to $10^{-4}$;

- the full Voigt function is used within 12 Doppler widths and the Lorentzian wing $\tau_0 a/(\sqrt\pi H(a,0)x^2)$ beyond;

- lines whose reach exceeds 100 cm$^{-1}$ (“long”) shade every line through their Lorentzian wings, summed as $\sum_j C_j/(\tilde\nu-\tilde\nu_j)^2$ with four interleaved partial sums; other lines (“short”) are added where they reach, within 100 cm$^{-1}$; lines within 40 Doppler widths of line $i$ (“near”) are evaluated term by term;

- the lines are processed in wavenumber order so that the windows only move forward; a thin line ($\tau_0<1$) takes the far contribution once at its centre; lines that no shading line reaches keep $\mathcal{O}=1$.

In `solveCell` the factor is computed once per cell and path, at the columns in front of the cell plus half the cell’s own ({ref}`sec:solvecell`), and multiplies the cell-averaged $\langle S\rangle$ of Equation ({eq}`eq:cellavg`): a product of means stands for the mean of the product, adequate where the other lines’ shading changes little across the cell. The result was checked against the same integral on a 0.05 cm$^{-1}$ grid across 84 000–119 500 cm$^{-1}$ (every line with $\tau_0>10^{-3}$ a Voigt profile). The exact factor on the Solomon rate of the {devlog}`H-005` slab’s ground-state levels is 0.96, 0.93, 0.86, 0.65, 0.49 and 0.32 at $N(\mathrm{H_2})=10^{17}$, $10^{18}$, $10^{19}$, $10^{20}$, $3\times10^{20}$ and $10^{21}$ cm$^{-2}$; the model reproduces it to 0.2–1.6% up to $3\times10^{20}$ cm$^{-2}$ and to 4.5% at $10^{21}$ cm$^{-2}$, and the exact factor is within 5% of the overlap term of Equation ({eq}`eq:db96`) ({devlog}`H-006`). Overlap lowered the total pumping through that slab by 33%.

Not included: a photon absorbed in another line’s wing is counted as lost rather than as a pump of that line (cross-pumping), which underestimates the pumping of the weaker lines where the band is saturated; and the H I Lyman-series lines, which the MC field does not contain either ({ref}`sec:eta`), do not shade the band. Their damping wings remove continuum around Ly$\beta$, Ly$\gamma$ and Ly$\delta$ (1026, 973 and 950 Å) over equivalent widths of about 4, 1.4 and 0.7 Å at $N(\mathrm{H\,I})=10^{21}$ cm$^{-2}$, growing as $N(\mathrm{H\,I})^{1/2}$ (an estimate of this document from the damping-wing curve of growth, i.e. a few per cent of the 912–1110 Å band); pumping and dissociation behind such columns are overestimated ({ref}`sec:limitations`). The Meudon code includes them in its exact transfer {cite:p}`LePetit2006`.

(sec:escape)=
## Escape probabilities
The probability that a photon emitted in line $t$ ($u\to l$) at the cell centre leaves the cloud is (`h2LineEscape`, {src}`h2_mod.f90::h2LineEscape`; {src}`pdr_mod.f90::h2LevelModel/solveCell@"! ---- escape of each line over the twelve line rays"..@"call h2LineEscape(N12, b, beta)"`) 

$$
\beta_t = \frac{1}{12}\sum_{k=1}^{12} S\bigl(\sigma_t N_{l,k},\,a_t\bigr),
$$ (eq:beta)

 with $N_{l,k}$ the column of the line’s lower level from the cell centre to the edge of the model along line ray $k$ ({ref}`sec:lineRays`), the cell’s own half included, from the populations of the previous sweep. With complete redistribution the photon is emitted with the absorption profile, so the probability that it crosses a column in one direction, $\int\phi\,e^{-\tau}\mathrm{d}x/\int\phi\,\mathrm{d}x$, is the function $S$ of Equation ({eq}`eq:SW`); the mean over the twelve HEALPix directions is the mean over the sphere. The medium is static (no velocity field, so no Sobolev-type escape), the escape probability is that of the cell centre rather than a mean over the cell, and each line is treated alone (no overlap in the trapping). The Meudon code makes the same on-the-spot approximation for the ultraviolet photons of the H$_2$ cascades {cite:p}`LePetit2006`.

(sec:formdist)=
## Formation on grains: the nascent distribution
Molecules formed on grains are placed in the $(v,J)$ distribution of {cite:t}`TakahashiUehara2001`, as Cloudy applies it {cite:p}`Shaw2005` (`h2FormDist`, {src}`h2_mod.f90::h2FormDist`). With $D$ the dissociation energy of $X$ from its $(0,0)$ level (36 118.11 cm$^{-1}$, 4.478 eV; their $D_e=4.48$ eV), $E_{\mathrm{off}}=0.273$ eV the energy of $(0,0)$ above the bottom of the potential well (their zero-point energy $E_{v0}=0.27$ eV; 0.273 eV is Cloudy’s value), $E(v,J)$ the level energies above $(0,0)$, and per surface the parameters of {numref}`tab:tu01`: 

```{math}
\begin{gather}
  E_{vm} = X_{\mathrm{vib}}D + E_{\mathrm{off}},\qquad
  E_v = E(v,0)+E_{\mathrm{off}},\\
  E_{\mathrm{dust}}(v) = D\,X_{\mathrm{dust}}\Bigl[1-\frac{E_v-E_{vm}}{D+E_{\mathrm{off}}-E_{vm}}\,\frac{1-X_{\mathrm{dust}}}{2}\Bigr],\qquad
  E_{\mathrm{H_2}}(v) = D+E_{\mathrm{off}}-E_{\mathrm{dust}}(v),\\
  F(v) = e^{-x_v^2},\quad
  x_v = \begin{cases}\dfrac{E_v-E_{vm}}{g_1E_{vm}} & E_v\le E_{vm}\\[6pt]
                     \dfrac{E_v-E_{vm}}{g_2\,(E_{\mathrm{H_2}}(v)-E_{vm})} & E_v>E_{vm}\end{cases},\\
  E_{\mathrm{rot}}(v) = \bigl(E_{\mathrm{H_2}}(v)-E_v\bigr)\frac{X_{\mathrm{rot}}}{X_{\mathrm{rot}}+X_{\mathrm{trans}}},\qquad
  \phi(v,J)\propto g_{\mathrm{ns}}\,\frac{F(v)}{\sum_vF}\,(2J+1)\,\tfrac12\Bigl[e^{-y^2}+e^{-\Delta E/E_{\mathrm{rot}}}\Bigr],
\end{gather}
```

 with $\Delta E=E(v,J)-E(v,0)$, $y=(\Delta E-E_{\mathrm{rot}})/(E_{\mathrm{rot}}/2)$, $g_{\mathrm{ns}}=3$ (ortho) or 1 (para), $\phi=0$ where $E_{\mathrm{rot}}\le0$ (high $v$; J. Takahashi’s prescription as quoted in Cloudy’s source), and $\phi$ normalised to one. These are equations 1–7 of {cite:t}`TakahashiUehara2001`: the energy left on the grain $E_{\mathrm{dust}}(v)$ (their eq. 1), the energy that stays in the molecule (eq. 2) and its share in rotation (eq. 3), and a vibrational distribution peaked at $E_{vm}$ with different widths below and above it (eqs. 5–7). The rotational distribution is the mean of their two models, a Gaussian about $E_{\mathrm{rot}}$ of width $E_{\mathrm{rot}}/2$ (model A, eq. 12) and a thermal distribution at $E_{\mathrm{rot}}$ (model B, eq. 13); the mean is applied before one overall normalisation, as in Cloudy. Carbonaceous, silicate and icy surfaces put the new molecules mainly near $v=2$, 6 and 7 respectively {cite:p}`Shaw2005`. The fraction formed above 4100 cm$^{-1}$ agrees with Cloudy’s network to four digits (0.9771, {devlog}`H-004`).

The energy budget of a formation follows by conservation: $E_{\mathrm{grain}}=\langle
E_{\mathrm{dust}}\rangle_\phi$ is left on the grain, $E_{\mathrm{kin}}=D-E_{\mathrm{grain}}-\langle E(v,J)\rangle_\phi$ is the translational energy of the departing molecule, which heats the gas directly, and the internal energy $\langle E(v,J)\rangle_\phi$ is either radiated in H$_2$ lines or returned to the gas by collisional de-excitation, i.e. through $\mathcal{H}_{\mathrm{coll}}$ ({ref}`sec:solvecell`). $E_{\mathrm{kin}}$ is 0.834 eV for silicate and 1.142 eV for carbonaceous surfaces, against 3D-PDR’s 1.5 eV ({devlog}`H-013`). $E_{\mathrm{grain}}$ is a diagnostic only (`h2Cells.out`); it is not added to MOCASSIN’s grain energy balance.

:::{list-table} {cite:t}`TakahashiUehara2001`, their Table 2 parameters as used ({src}`h2_mod.f90@"integer, parameter, public :: h2NSurf = 3"`); the ice set is not used by `solveCell`.
:name: tab:tu01
:header-rows: 1

* - Surface
  - $X_{\mathrm{vib}}$
  - $X_{\mathrm{dust}}$
  - $X_{\mathrm{rot}}$
  - $X_{\mathrm{trans}}$
  - $g_1$
  - $g_2$
* - ice
  - 0.70
  - 0.04
  - 0.14
  - 0.12
  - 0.3
  - 0.6
* - silicate
  - 0.60
  - 0.10
  - 0.15
  - 0.15
  - 0.4
  - 0.6
* - carbonaceous
  - 0.20
  - 0.40
  - 0.15
  - 0.25
  - 0.9
  - 0.4
:::

In each cell the silicate and carbonaceous distributions are mixed in the proportion of the chemistry's own formation rate on each material: $w_{\mathrm{sil}}$ and $w_{\mathrm{gra}}$ are `H2_FORMATION_RATE` ({ref}`sec:formation`) evaluated with only that material's grain area ({src}`code <pdr_mod.f90::h2LevelModel/solveCell@"! ---- formation: the two surfaces in the proportion of the"..@"phi(l) = h2G(l)*exp(-hcK*h2E(l)/T)">`). A cell with no grain formation (no dust, or $T_d=0$) takes a Boltzmann distribution at $T_e$, i.e. no formation pumping, and is counted. Formation through H$^-$ and H$_2^+$, which populates specific levels, is not distributed over the levels: every molecule the closure forms enters in $\phi$.

(sec:solvecell)=
## The per-cell algorithm

`solveCell` ({src}`pdr_mod.f90::h2LevelModel/solveCell`) does, for one cell:

1.  **Field** ({src}`code <pdr_mod.f90::h2LevelModel/solveCell@"T = max(dble(grid(1)%Te(cellP)), 1.d0)"..@"etaDir(ln) = 0.d0; etaDif(ln) = 0.d0">`): $b$ from $T_e$; $J_\nu^{\mathrm{dir}}$, $J_\nu^{\mathrm{dif}}$ per bin and $\eta^{\mathrm{dir}}$, $\eta^{\mathrm{dif}}$ per line (Eq. {eq}`eq:eta`).

2.  **Cell geometry** ({src}`code <pdr_mod.f90::h2LevelModel/solveCell@"! the cell: its widths, and its mean chord over all directions, 4 V / A"..@"dN = dble(grid(1)%h2Pop(cellP,:))*dnH2*chordIso">`): cell widths, $\ell_{\mathrm{iso}}$, and the cell's own column for the diffuse paths from its populations of the last sweep, $\Delta N^{\mathrm{iso}}_l = n_l n(\mathrm{H_2})\ell_{\mathrm{iso}}$.

3.  **Diffuse shielding** ({src}`code <pdr_mod.f90::h2LevelModel/solveCell@"lgDif = any(etaDif > 0.d0)"..@"shDif = -1.d0">`), if any line has $\eta^{\mathrm{dif}}>0$: `traceDiffuseSites` gives the sites and their weights $w$ ({ref}`sec:sites`); walking the stored rays again, each site gets a column per level,

    $$
    N_{l,\mathrm{site}} = N^\star_l(P) + n_l(P)\,n(\mathrm{H_2},P)\,\ell_{\mathrm{own}}(P)
        + \sum_{\mathrm{between}} n_l\,n(\mathrm{H_2})\,\ell + \tfrac12\,n_l(P)\,n(\mathrm{H_2},P)\,\ell_P
    $$

    (the level-resolved form of Eq. {eq}`eq:twoleg`, with the source-ward level columns $N^\star_l$ of `starColumns`). Evaluating $S$ for every line at every site would cost $32\,453\times N_{\mathrm{site}}$ look-ups, and a cell has hundreds of sites, so the sites are binned:

    - four groups by total column $\sum_l N_{l,\mathrm{site}}$, with edges $10^{17}$, $10^{19}$ and $3\times10^{20}$ cm$^{-2}$;
    - within a group and for each level, a histogram of the weights in $\log_{10}N_{l,\mathrm{site}}$, 0.1 dex bins from $10^9$ cm$^{-2}$ (150 bins, the end bins catching the columns beyond), plus a "thin" weight for sites where $\sigma_{\max,l}N_l<10^{-4}$, $\sigma_{\max,l}$ being the largest cross section of the lines out of $l$;
    - the overlap factor (Eq. {eq}`eq:overlap`) once per group with more than $10^{-4}$ of the total weight, at the group's weight-mean level columns plus $\frac12\Delta N^{\mathrm{iso}}$ (none for the $<10^{17}$ cm$^{-2}$ group);
    - per line, the diffuse shielding factor

      $$
      \langle S\rangle^{\mathrm{dif}}_i = \frac{1}{\sum w}\sum_{g}\mathcal{O}_{i,g}
      \Bigl[w^{\mathrm{thin}}_{l,g}\,\langle S\rangle(0) + \sum_{\mathrm{bins}} w_{l,g,\mathrm{bin}}\,
      \langle S\rangle\bigl(\sigma_i N_{\mathrm{bin}}\bigr)\Bigr],
      $$

      each $\langle S\rangle$ averaged through the cell's own column $\sigma_i\Delta N^{\mathrm{iso}}_l$ by Eq. {eq}`eq:cellavg`.

    The binning replaces each site's column by its bin centre (an error of at most $\pm0.05$ dex in $N_l$) and each group's overlap by that at the group's mean columns. If there is diffuse light but no site (no dust on any of the twelve rays) the diffuse part rides the direct path ({src}`code <pdr_mod.f90::h2LevelModel/solveCell@"! no site to place the diffuse field on: it rides the source-ward"..@"shDif = -1.d0">`).

4.  **Direct path** ({src}`code <pdr_mod.f90::h2LevelModel/solveCell@"! ---- the direct part: the star-ward column, averaged through the cell"..@"if (fTot > 0.d0) chord = chord/fTot">`): source-ward level columns $N^\star_l$ and the chord $\ell_{\mathrm{dir}}$.

5.  **Escape** ({src}`code <pdr_mod.f90::h2LevelModel/solveCell@"! ---- escape of each line over the twelve line rays"..@"call h2LineEscape(N12, b, beta)">`): $\beta_t$ over the twelve line rays (Eq. {eq}`eq:beta`).

6.  **Formation** ({src}`code <pdr_mod.f90::h2LevelModel/solveCell@"! ---- formation: the two surfaces in the proportion of the"..@"phi(l) = h2G(l)*exp(-hcK*h2E(l)/T)">`): mixture weights, $\phi$, $E_{\mathrm{kin}}$, $E_{\mathrm{grain}}$.

7.  **Solve** ({src}`code <pdr_mod.f90::h2LevelModel/solveCell@"! ---- solve; the colliding ortho and para H2 and the cell's own"..@"fo = foNew; exit">`). `h2LineShieldPrep` stores, for the direct column, each line's $\tau_0$, $W(\tau_0)$ and damping index. Then up to 12 passes: colliders from the current ortho fraction; the cell's own direct column $\Delta N^{\mathrm{dir}}_l = n_l n(\mathrm{H_2})\ell_{\mathrm{dir}}$ from the current populations; on the first pass only, the direct overlap factor at $N^\star+\frac12\Delta N^{\mathrm{dir}}$; the direct shielding $\langle S\rangle^{\mathrm{dir}}_i\mathcal{O}^{\mathrm{dir}}_i$ (`h2LineShieldEval`); the shielded occupation numbers

    $$
    \eta_i = \eta^{\mathrm{dir}}_i\,\langle S\rangle^{\mathrm{dir}}_i\mathcal{O}^{\mathrm{dir}}_i
           + \eta^{\mathrm{dif}}_i\,\langle S\rangle^{\mathrm{dif}}_i
    $$

    (or $(\eta^{\mathrm{dir}}_i+\eta^{\mathrm{dif}}_i)$ times the direct factor when there is no site); and the level balance (`h2Solve`). The loop stops when the ortho fraction changes by less than $10^{-4}$; a cell that had settled in the previous sweep needs one pass, and the mean was 1.0–1.6 passes per cell ({devlog}`H-011`).

8.  **Products** ({src}`code <pdr_mod.f90::h2LevelModel/solveCell@"popTmp(cellP,:) = real(pops)"..@"r1Tmp(cellP,13) = real(eKin*dble(hPlanck)*dble(c)) ! kinetic, per H2 formed [erg]">`): $k_{\mathrm{Sol}}=\sum n_lk_l$; the absorption rate $\sum n_l\sum_uP_{lu}$; for comparison the chemistry's own single-line rate on the same field and columns (`h2SolChem`, 3D-PDR's `H2PDRATE`); diagnostics; and three heating terms per molecule: the atoms' kinetic energy from dissociation $\sum_l n_l H^{\mathrm{dis}}_l$, the net heating by collisions within $X$

    $$
    \mathcal{H}_{\mathrm{coll}} = hc\sum_c\sum_{u>l} n_c k^c_{ul}
       \Bigl(n_u - n_l\frac{g_u}{g_l}e^{-hc(E_u-E_l)/kT}\Bigr)(E_u-E_l)
       \quad[\mathrm{erg\,s^{-1}}]
    $$ (eq:hcoll)

    (`h2CollHeat`, {src}`h2_mod.f90::h2CollHeat`; Cloudy's `HeatDexc`), and the kinetic energy per molecule formed, $E_{\mathrm{kin}}$. $\mathcal{H}_{\mathrm{coll}}$ is the energy that collisions take out of the levels populated above their Boltzmann ratio at $T$ by pumping and formation; it is negative, i.e. H$_2$ line cooling, where the gas is hotter than the level populations. A pump deposits in the gas only what $\mathcal{H}_{\mathrm{coll}}$ recovers from the levels it feeds, and a dissociation the kinetic energy of the atoms, so the three terms do not count any energy twice.

(sec:sweeps)=
## Sweeps, parallel strategy and convergence
`h2LevelModel` reads the data once and, on every call:

- takes $n(\mathrm{H_2})=n_{\mathrm H}x(\mathrm{H_2})$ of every cell from the chemistry; on the first call it starts every cell from Boltzmann populations at $T_e$, or, on a warm start, from `output/h2Pop.bin` if that file describes the same grid and level set (`h2PopResume`, {src}`pdr_mod.f90::h2LevelModel/h2PopResume`, {devlog}`H-020`); later calls start from the last call’s populations. A cold start on a converged model overshoots the dissociations of its first sweep by 38% ({devlog}`H-016`); a resumed one is within 0.6% of the checkpointed run ({devlog}`H-020`);

- for each sweep, rebuilds the source-ward level columns of every cell, $N^\star_l=\sum n_l\,n(\mathrm{H_2})\,\ell$ along `rayCells` to each source, weighted over sources by $r_s^{-2}$ and excluding the cell itself (`starColumns`, {src}`pdr_mod.f90::h2LevelModel/starColumns`); the other cells’ populations in all columns are those of the previous sweep, so a sweep is a Jacobi iteration over the cells, whose result does not depend on the order in which the cells are solved;

- distributes the cells dynamically: the ranks take cells one at a time from a shared counter in an MPI-3 one-sided window allocated on rank 0 (`MPI_Win_allocate`, `MPI_Fetch_and_op`, {src}`pdr_mod.f90::h2LevelModel@"call mpi_win_allocate(wsz, 8, mpi_info_null, mpi_comm_world, wbase, winC, ierr)"..@"i = cI(cellP); j = cJ(cellP); k = cK(cellP)"`); the first sweep takes them in a fixed pseudo-random order (a Fisher–Yates shuffle driven by a linear congruential generator), later sweeps in decreasing cost of the previous sweep (`orderCells`, {src}`pdr_mod.f90::h2LevelModel/orderCells`), so that cores of different speed finish together; a cell’s result does not depend on the rank that solves it;

- reduces populations, rates and heating terms with `MPI_Allreduce` (in single precision);

- stops when the luminosities of 1–0 S(1), 2–1 S(1), 0–0 S(0) and 0–0 S(1), summed over the grid in the optically thin limit, all change by less than 1% between sweeps ({src}`pdr_mod.f90::h2LevelModel@"lum = 0.d0; pumpTot = 0.d0; solTot = 0.d0"..@"lumOld = lum"`), at most `nSweepMax` sweeps.

Inside the MC iteration `nSweepMax`$=1$: one sweep per iteration, the level model converging together with the rest of the model. On the finished model `nSweepMax`$=12$ ({ref}`sec:convergence`). On `pn150k` ($41^3$, 35 384 cells, 14 ranks) a call took 3736 s before and 1474 s after the optimisations of {devlog}`H-011`; the overlap calculation was about half of the timed work ({devlog}`H-007`).
