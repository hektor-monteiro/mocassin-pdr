# Reading the outputs in Python

`tools/mocread.py` reads a finished model's main output files into numpy arrays. It needs
numpy and nothing else, and it is what the {doc}`quickstart <../getting-started/quickstart>`
plot scripts and the {doc}`Lexington benchmark <../benchmarks/lexington>` use. The file layouts
it reads are described on the {doc}`outputs` page.

To use it from your own script, put the repository's `tools/` directory on the path:

```python
import sys
sys.path.insert(0, '/path/to/mocassin-pdr/tools')
import mocread

g = mocread.read_grid('my_model')       # the directory holding input/ and output/
print(g.nx, g.ny, g.nz, g.mask.sum(), 'cells in the line tables')
```

Run as a script, it prints a summary of a model:

```console
$ python3 tools/mocread.py my_model
```

## What it reads

| Function | File(s) | Returns |
| :--- | :--- | :--- |
| `composition(run)` | `input/input.in` and its `nebComposition` (or `multiChemistry`) file(s) | the elements switched on, symbol → abundance by number relative to H; with `multiChemistry`, only when every component is the same |
| `compositions(run)` | the same | one such dict per abundance file, in file order |
| `read_grid(run)` | `output/grid0.out`, `grid1.out`, `grid2.out` | a `Grid`: axes, flags, $T_e$, $n_e$, $n_{\mathrm H}$, ionic fractions |
| `read_lines(run)` | `output/lineFlux.out`, the totals block | a `Lines`: H$\beta$ and the H I, He I, He II and heavy-ion forbidden lines relative to H$\beta$ (not the heavy-element recombination tables that `recombinationLines` adds) |
| `mean_te(run)` | `output/temperature.out`, totals block | the mean temperature of each ion, weighted by $n_e\,n_\mathrm{ion}\,dV$ |
| `ion_fractions(run)` | `output/ionratio.out`, totals block | the mean fraction of each element in each stage, weighted by $n_e\,n_{\mathrm H}\,dV$ |
| `read_sed(run)` | `output/SED.out` | frequency (Ryd), wavelength (µm) and the SED summed over all directions, as $F_\nu D^2$ (Jy pc²) |
| `read_pdr(run, grid)` | `output/pdrGrid.out` (PDR runs) | a `PDR`: the FUV field, $A_V$, the chemistry's heating and cooling, and the abundances of its 33 species |
| `read_convergence(run)` | `output/convergence.out` | the names of the model-integrated quantities and their values per iteration |

## Conventions

- **Ion stages are named by charge.** `g.frac('O', 2)` is the fraction of oxygen in O²⁺; 0 is
  the neutral atom. MOCASSIN's own files count stages from 1, and every function converts them.
  `mocread.ion_label('O', 2)` gives `'O2+'`.
- **Arrays have the grid's shape**, `(nx, ny, nz)`, with `g.x`, `g.y` and `g.z` the grid's axis
  points in cm (`grid0.out`). Cell walls lie midway between them, so the first and last cells along an
  axis are half cells. Every grid point is written, inactive ones as zeros.
- **`g.mask`** selects the cells `lineFlux.out` and `lineFluxMol.out` count (`lineFluxH2.out` counts the
  flagged ones too): active, and not flagged by the code
  (`lgBlack`: a cell whose thermal balance was not reached or reached 30,000 K, or whose ionisation
  balance failed). Select cells with it, as in `g.Te[g.mask]`; note that a plain mean over cells is
  not weighted by volume, and mocread does not provide the cell volumes.
- **`g.r`** is the distance from the grid origin in cm, which is the star's position in a
  symmetric model.
- **Lines** are summed over a wavelength window: `l.sum('O', 2, 4957, 5010)` is
  [O III] 4959+5007 relative to H$\beta$, and `l.matches(...)` lists the transitions it summed.
  Heavy-ion wavelengths in `lineFlux.out` are in vacuum, He I wavelengths in air. `l.hbeta` is
  H$\beta$ in erg s⁻¹.
- **`ion_fractions`** follows `ionratio.out`, whose header reads `<ion>/<H+>` but whose values are
  each element's fractions (Harrington's definition). With `f = mocread.ion_fractions(run)`, the
  ratio `f[('He', 1)] / f[('H', 1)]` is the Lexington benchmarks' $\langle\mathrm{He^+}\rangle/\langle\mathrm{H^+}\rangle$.
- **Several compositions** (`multiChemistry`): `g.abindex` holds each grid point's abundance file
  (1 to N, from `grid1.out`), `g.components` the abundances of each file, and `g.abundance('C')` the
  per-point abundance of carbon. The elements in `grid2.out` are those switched on in any file.
- **PDR abundances** are per H nucleus, as the chemistry computes them:
  `p.abundance('CO')`. The species and their order are `mocread.REDUCED_SPECIES`.

## Scope

It reads models with **one grid** in **three dimensions**, written by a **gfortran** build without
`lgDebug`, with one nebular composition or several (`multiChemistry`). A model outside these limits
(sub-grids, a 2D model, files wrapped at 80 columns by ifort) is refused with a message saying which
limit it hit, rather than read wrongly.
