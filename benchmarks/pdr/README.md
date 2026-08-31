# PDR coupling benchmark

A 1D slab run through the coupled code and through **standalone 3D-PDR**, with
every parameter matched, so the two can be compared directly.

    n_H = 1e3 cm^-3   chi = 10 Draine   zeta = 5e-17 s^-1
    C/H = 1.4e-4      O/H = 3e-4        He/H = 0.1
    A_V = 0 .. 8.491  reduced network (33 species)

## Running the coupled model

    cd v1slab && python3 make_density.py
    mpirun -np 14 ../../../mocassin

`MdMg = 0.0281` is deliberate: MOCASSIN's grains at the usual 0.01 give
5.26e21 N_H per magnitude, 2.8x less extinguishing per hydrogen than the
canonical 1.87e21. Matching the *dust*, not just the A_V, is what brings the
self-shielding columns onto the same footing (DEVLOG D-058). Confirm with the
line the run prints:

    ! calibratePDRdust: A_V per N_H = 5.33996734E-22 (N_H per mag = 1.87267061E+21)

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

Matched against the standalone run: deep x(CO) 0.99, H->2H2 1.17, deep T 1.20,
C+->C 0.77, C->CO 0.63. **Surface temperature is 12.4x too hot** — the open
defect, tracked as DEVLOG D-060.
