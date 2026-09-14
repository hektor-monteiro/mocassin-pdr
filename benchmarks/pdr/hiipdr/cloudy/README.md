# Cloudy c25.00 equivalent of the hiipdr fixture (DEVLOG D-264)

    cloudy.exe -r compile   # compile grains -> sdraine03_hiipdr_10.opc (~40 s, 4 MB, not committed)
    cloudy.exe -r hiipdr    # 700 zones, 3 iterations, ~5 min single thread (D-277; 741 with the 3e17 inner radius of D-264)

Matched to MOCASSIN's hiipdr: star, geometry, abundances (every other element
off), cosmic-ray H0 ionization rate 2.30e-17 s^-1, Draine (2003) silicate with
the same MRN power law. Dust amount is matched on A_V/N_H = 5.177e-22 (MOCASSIN's
measured value), not on the dust-to-gas mass ratio, because the two codes'
silicate material densities differ (1.57x in grain cross-section).

Figures: `tools/d260_roellig.py --cloudy <mocassin-run> <dir>/hiipdr <out-dir>`.
