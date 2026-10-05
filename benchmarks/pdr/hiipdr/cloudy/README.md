# Cloudy c25.00 equivalent of the hiipdr fixture (DEVLOG D-264)

    cloudy.exe -r compile   # compile grains -> sdraine03_hiipdr_10.opc (~40 s, 4 MB, not committed)
    cloudy.exe -r hiipdr    # 697 zones, 3 iterations, ~14 min single thread (D-396: 700 and ~5 min with the
                            # small H2 model of D-277; 741 with the 3e17 inner radius of D-264)

Matched to MOCASSIN's hiipdr: star, geometry, abundances (every other element
off), cosmic-ray H0 ionization rate 2.30e-17 s^-1, Draine (2003) silicate with
the same MRN power law. Dust amount is matched on A_V/N_H = 5.177e-22 (MOCASSIN's
measured value), not on the dust-to-gas mass ratio, because the two codes'
silicate material densities differ (1.57x in grain cross-section).

D-396: the same 1 km/s microturbulence as MOCASSIN (`pdrVturb`, 3D-PDR's
`v_turb`), which every line width, H2's shielding included, depends on; and
Cloudy's large H2 model (`Database H2`), whose line-by-line shielding is the
one to set against MOCASSIN's level model - the small model's shielding is the
Elwert et al. (2005) fit, 1.4-3.3x stronger than the large model's at
N(H2) = 1e15-1e17 (H-005's slab, h2-model branch). The pn150k
reference has used the large model since D-302. Line ratios are read from the
last iteration's block of the listing (the first is unconverged).

Figures: `tools/d260_roellig.py --cloudy <mocassin-run> <dir>/hiipdr <out-dir>`.
