# 3D-PDR 3D benchmark reference

3D-PDR's own three-dimensional example, run to completion and kept here so the
coupled code can be compared without a 20-minute regeneration.

    IC        ics/diffuse_32.dat   32^3 = 32768 points, turbulent density field
              0.06 - 3.94 pc, n_H = 22.8 .. 3.56e4 cm^-3 (median 188)
    build     templates/3D/config.mk : DIMENSIONS=3, RAYTHEIA=1, CHEMANALYSIS=0
              RAYTHEIA=1 maps to -DRAYTHEIA -DRAYTHEIA_MO (both; see DEVLOG D-084)
    params    G0 = 10 Draine, zeta = 1e-16, A_V factor 6.289e-22, UV factor 3.02,
              HEALPix level 0, dust-to-gas 1.0

Result: T_gas 6.9 - 305.4 K (median 90.3), T_dust 10.0 - 20.0 K (median 16.3),
chi 7.2e-6 - 7.88, x(H2) up to 0.5.

## Output format (42 columns, against 41 in 1D)

| column | quantity |
|---|---|
| 1 | index |
| 2,3,4 | x, y, z [pc] |
| 5 | T_gas [K] |
| 6 | T_dust [K] |
| 8 | n_H [cm^-3] |
| 9 | chi [Draine] |
| 10-42 | abundances, in v1.species order |

There is **no A_V column**: in 3D the extinction is per-ray (12 values at
HEALPix level 0), so no single value exists.

## The comparison problem

**This reference cannot currently be matched by the coupled code.** 3D-PDR
illuminates a 3D model isotropically - `UVfield.F90`:

```fortran
#ifdef ONEDIMENSIONAL
   pdr(p)%rad_surface(6) = Gext(1)                    ! 1D: all flux on one ray
#else
   pdr(p)%rad_surface = Gext(1)/real(nrays,kind=dp)   ! 3D: isotropic bath
#endif
```

MOCASSIN has no equivalent source. Its options are point sources, a
plane-parallel beam (`planeIonization`), or `diffuseSource` - and the last is a
*volumetric* emitter distributed over active cells by volume and density
(`continuum_mod.f90:setLdiffuse`), not an external bath. `emittingGrid` selects
which grid emits in a multi-grid run, not a spatial shell.

Closing that gap needs an isotropic external illumination mode in MOCASSIN:
packets launched inward from the grid boundary, cosine-weighted, with the
luminosity set from chi and the bounding surface area. That is the same shape of
change as `planeIonization` (launch position + direction in `photon_mod`, an
`Lstar` normalisation in `grid_mod`, one input keyword), and it is worth having
independently of benchmarking, since the interstellar radiation field that
illuminates real PDRs is isotropic.
