# PDR coupling benchmark

A 1D slab run through the coupled code and through **standalone 3D-PDR**, with
every parameter matched, so the two can be compared directly.

    n_H = 1e3 cm^-3   chi = 10 Draine   zeta = 5e-17 s^-1
    C/H = 1.4e-4      O/H = 3e-4        He/H = 0.1
    A_V = 0 .. 8.491  reduced network (33 species)

## Running the coupled model

    cd v1slab && python3 make_density.py
    mpirun -np 14 ../../../mocassin

The grain setup matters and was got wrong once (DEVLOG D-073). Silicates from
0.07 to 50 um - as this benchmark originally inherited - are large enough to
give *grey* extinction, R_FUV = tau_FUV/tau_V = 1.12, where interstellar dust
gives ~3. The transported FUV field then decays far too slowly and reaches
chi ~ 1e-2 at A_V = 8.5, eight orders above 3D-PDR. The committed
`dust_species.dat` uses 0.010-0.30 um, giving R_FUV = 3.59 against 3D-PDR's
stated UV factor of 3.02, and `MdMg = 0.01059` then holds A_V/N_H at 3D-PDR's
value. Confirm both from the lines the run prints:

    ! calibratePDRdust: A_V per N_H = 5.33838558E-22 (N_H per mag = 1.87322554E+21)
    ! [D073] kFUV/kV = R_FUV = 3.59476638

## Parameters audited against 3D-PDR's params.dat (D-074)

| parameter | 3D-PDR | here |
|---|---|---|
| G0 | 10 Draine | 10.1 |
| cosmic-ray rate | 5e-17 | 5e-17 |
| turbulent velocity | 1 km/s | 1.0 |
| grain radius | 1e-5 cm | 1e-5 |
| A_V conversion | 5.33997e-22 | 5.33839e-22 |
| T_min / T_max | 1 / 2e4 | 1 / 2e4 |
| HEALPix level | 0 | 0 |
| Fcrit | 0.005 | 0.005 |
| UV factor (R_FUV) | 3.02 | 3.59 |
| dust-to-gas x1e-2 | 1 | 1.06 |

## Regenerating the standalone baseline

`baseline3dpdr/v1.pdr.fin` is 3D-PDR run on `ics/1Dn30.dat` (n_H = 1e3 over
5.15 pc) with `params.dat` as committed here. To rebuild it:

1. Clone upstream 3D-PDR at `fabcdc6` (the commit `source/pdr/` vendors).
2. Copy `config.mk` and `params.dat` into place, and `1Dn30.dat` into `ics/`.
3. Our SUNDIALS is MPI-enabled and 3D-PDR never calls `MPI_INIT`, so CVODE
   aborts with `MPI_Comm_dup() called before MPI_INIT`. Compile `mpishim.c`
   and link it in:

        mpicc -O2 -c mpishim.c
        mpif90 -fopenmp -O3 -L$SUNDIALS_DIR/lib -Wl,-rpath,$SUNDIALS_DIR/lib \
          -o 3DPDR *.o -lsundials_cvode -lsundials_nvecserial \
          -lsundials_sunmatrixdense -lsundials_sunlinsoldense \
          -lsundials_sunnonlinsolnewton -lsundials_core -lm

4. Run it as `mpirun -np 1 ./3DPDR < /dev/null`. As an MPI singleton it
   initialises and then blocks at zero CPU.

## Output format

`v1.pdr.fin`, one row per point, 41 columns:

| column | quantity |
|---|---|
| 1 | point index |
| 2 | x [pc] |
| 3 | A_V [mag] |
| 4 | T_gas [K] |
| 5 | T_dust [K] |
| 7 | n_H [cm^-3] |
| 8 | chi [Draine] |
| 9-41 | abundances, in `v1.species` order |

Species indices used by the comparison: C+ = 11, C = 25, CO = 28, H2 = 31,
H = 32, e- = 33 — the same order `source/pdr/` uses.

## Where it stands

Matched against the standalone run, all three chemical fronts land within a
tight band: H->2H2 0.76, C+->C 0.76, C->CO 0.82, with heating and cooling
balanced to 0.999 in every cell.

The open defect is a **uniform ~1.96x gas temperature offset** (deep 3.8x),
tracked as DEVLOG D-064. It traces to a cooling function that is weak at fixed
temperature - [C II] at 0.24x and [O I] at 0.06x of standalone when compared at
the same T - with the atomic data, collision-partner mapping, detailed balance
and escape-probability branch all verified identical.
