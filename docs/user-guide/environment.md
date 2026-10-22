# Environment variables

The programs read one environment variable, a diagnostic that prints and
changes nothing, and refuse to run when one of four retired ones is set.

## `MOCASSIN_DUSTPROBE`

`MOCASSIN_DUSTPROBE=on` prints the two halves of the grain temperature
balance, so they can be checked against an independent integral
({devlog}`D-308`). Only the exact value `on` turns it on. It prints on rank 0
only, in lines tagged `! [D308]`, and changes no result.

- **The emission side**, once, when
  {src}`dustEmissionInt <dust_mod.f90::dustEmissionInt@"call get_environment_variable(\"MOCASSIN_DUSTPROBE\""..@"end if">`
  has built the table of emitted power per grain against temperature: the
  table's sizes (nSpecies, nSizes, nbins, nTemps); then, for the first two
  grain species and every `nSizes/4`-th size from the second, the emission
  integral at 20, 40 and 60 K and the absorption cross section at 0.44 and
  2.0 Ryd.
- **The absorption side**, in the grain temperature solve
  {src}`getDustT <update_mod.f90::getDustT@"if (nProbe < 12 .and. taskid == 0) then">`,
  for the middle grain size (`1 + nSizes/2`), at the first 12 such solves
  rank 0 makes (the counter is kept for the whole run): the cell, species and
  size; the summed field `sum(Jste)` and `sum(radField)` and the grain number
  density; the absorbed power, the temperature-table index it falls at, the
  emission integral there, and the grain temperature found.

## Retired: `MOCASSIN_LINES`, `MOCASSIN_RECCOOL`, `MOCASSIN_YIELD`, `MOCASSIN_GRAINQ`

These four used to select between alternative physics:

| Variable | Selected |
|---|---|
| `MOCASSIN_LINES` | whether the optically thin diffuse lines were discarded ({devlog}`D-306`, {devlog}`D-307`) |
| `MOCASSIN_RECCOOL` | Case B recombination cooling ({devlog}`D-286`) |
| `MOCASSIN_YIELD` | the Baldwin et al. (1991) photoelectric yield ({devlog}`D-289`) |
| `MOCASSIN_GRAINQ` | the 4π² units of the grain charge balance ({devlog}`D-290`) |

They changed the physics without leaving a trace in the input file. The
adopted forms are now the only ones ({devlog}`D-352`), and a run in an
environment that still sets one to a non-empty value stops at once:
{src}`readInput <set_input_mod.f90::readInput@"do i = 1, 4">` prints (on
rank 0) which variable is set and that it is retired, then stops.
`mocassin`, `mocassinWarm`, `mocassinOutput` and `mocassinPlot` all call
`readInput`, so none of them runs with one set. Unset them; the old modes
are built by the tag `d352-zone-and-switches`.
