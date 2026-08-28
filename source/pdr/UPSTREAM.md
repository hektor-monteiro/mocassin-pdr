# Vendored 3D-PDR sources

Imported per DEVLOG **D-005**. Do not edit casually: every local change widens the
gap with upstream and has to be re-applied by hand at the next merge. Record any
edit here and in the DEV log.

| | |
|---|---|
| Upstream | https://github.com/itamos-ism/3D-PDR |
| Commit | `fabcdc646d7a54ae2ea3ba30bdd1a9f25a92e959` |
| Date | 2026-08-26 |
| Imported | 2026-08-28 |
| Licence | GPL-3.0 (same as MOCASSIN) |

Data files (`chemfiles/`) are vendored separately into `dataPDR/` at the repository
root, following the `data/` and `dustData/` convention.

## Local modifications

None yet. The sources are byte-identical to upstream except that `3DPDR.F90`,
the standalone driver, is not imported.

## Compiled subset

The build compiles the object list in the `Makefile` (`PDR_MODULES`, `PDR_CODE`,
`PDR_C`), which follows upstream's `src/makefile`. The following vendored files
are deliberately **not compiled**, because MOCASSIN supplies the functionality:

| File | Replaced by |
|------|-------------|
| `input_parameters.F90` (`readparams`) | MOCASSIN input keywords (Phase 2) |
| `readdensity.F90` | MOCASSIN's grid |
| `UVfield.F90` (`calc_uvfield`) | the Monte Carlo radiation field (**D-001**) |
| `writeoutputs.F90` | MOCASSIN's output routines |
| `restart_io.F90` | MOCASSIN's `grid*.out` checkpoints (**D-006**) |
| `read_command_line.F90`, `logo.F90`, `writeparams.F90` | MOCASSIN's driver |
| `m_IOAndVisu.F90`, `analyse_chem.F90`, `dust_t.F90` | not in the frozen build matrix (**D-009**) |
| `odes_medium.c`, `odes_full.c`, `odes_mynetwork.c` | only the REDUCED network is built (**D-003**) |

They are kept in the tree so the vendored copy stays a faithful mirror of upstream
and future merges stay clean.

> **`read_input.F90` is NOT the parameter reader.** It is the LAMDA/RADEX coolant
> datafile reader, and it *is* required — `read_coolants.F90` calls it. The
> parameter reader is `input_parameters.F90`. D-005's original exclusion list was
> inferred from filenames and got this wrong; see the 2026-08-28f DEV log entry.

## Namespace hazard

3D-PDR's modules export very generic names — `maincode_module` exports `i`, `j`,
`k`, `p`; `global_module` exports `NH`, `NC`, `NO`. A blanket `use` of either
collides with ordinary local variables. **Always import with an explicit `only:`
list** (DEVLOG D-021).

Three procedure names exist in both codebases: `readinput`, `spline`, `splint`.
There is no link clash — MOCASSIN's are module procedures (name-mangled), 3D-PDR's
are bare externals — but a source file that `use`s `interpolation_mod` and also
calls 3D-PDR's `spline` will silently get MOCASSIN's.

## Hardcoded paths

`read_species.F90`, `read_rates.F90` and `input_parameters.F90` open their data
files through a hardcoded relative path, `chemfiles/...`. Until Phase 2 makes this
configurable, anything driving the chemistry must run from a directory containing a
`chemfiles` link to `dataPDR/`.
