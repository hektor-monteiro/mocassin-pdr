# Quickstart

This page runs two small models and plots them: a photoionised nebula in under a minute,
then the same kind of nebula with dust and its photodissociation region (PDR) in about ten.
Both come with the code, in `examples/quickstart/`.

## 1. Build and install

The 3D build runs both models: it is MOCASSIN with the PDR chemistry and the H₂ level model,
and without the `pdr` keyword it is MOCASSIN alone. It needs SUNDIALS ({doc}`install` covers
it and the other builds). From your checkout:

```bash
make clean
make PDR=1 PDRGEOM=3D install        # PREFIX defaults to $HOME/.local
```

This puts `mocassin` in `$HOME/.local/bin`, the data under `$HOME/.local/share/mocassin/`, and
the examples under `$HOME/.local/share/doc/mocassin/examples/`. The commands below assume that
`$HOME/.local/bin` is on your `PATH`. For the plots you need Python 3 with numpy and matplotlib.

## 2. A photoionised nebula: HII40

HII40 is the standard H II region of the Lexington benchmarks: a 40,000 K star ionising a uniform
sphere of hydrogen at 100 cm⁻³, with no dust. Copy it, make the output directory (MOCASSIN does
not create it), and run it on 4 cores:

```bash
cp -r $HOME/.local/share/doc/mocassin/examples/quickstart/hii40 ~/qs-hii40
cd ~/qs-hii40
mkdir -p output
mpirun -np 4 mocassin > run.log 2>&1
```

It takes 45 seconds on 4 cores (30 seconds on 14). The input is `input/input.in`, one
keyword per line, with the abundances in `input/abunHII40.in`; {doc}`../user-guide/keywords`
explains each keyword. The run stops when the model has converged, and the last lines of
`run.log` say so:

```text
 ! iterateMC: [talk] convergence reached after           17  iterations. & Finishing up ...
 ! iterateMC: [talk] integrated quantities converged: largest change over the last window   1.889% (S+), limit  2.00%
total run time per processor  00:00:45 (HMS)
 ! MoCaSSin: end simulation reached - clean exit -
```

`output/` now holds the model: the grid with each cell's temperature, density and ionisation
(`grid0.out` to `grid3.out`), the line luminosities (`lineFlux.out`), the mean temperatures and
ionisation fractions (`temperature.out`, `ionratio.out`) and the spectrum that leaves the nebula
(`SED.out`). {doc}`../user-guide/outputs` describes every file.

**A first look.** `tools/mocread.py`, in your checkout, reads these files with numpy
({doc}`../user-guide/python`). Run as a script, it summarises a model:

```console
$ python3 /path/to/mocassin-pdr/tools/mocread.py .
grid: 13 x 13 x 13, 1200 active cells, 0 flagged
elements: H He C N O Ne S
Hbeta: 2.01204796e+37 erg/s
T(H+): 8098.97 K
strongest heavy-ion lines:
    ion    lambda vac [A]    I/Hbeta
    O2+              5008      1.591
    O2+         8.834e+05      1.258
    O+               3730      1.253
    O2+         5.181e+05      1.051
    O+               3727     0.9737
    S2+         3.348e+05     0.7611
    S2+              9533       0.69
    S3+         1.051e+05     0.5687
```

**The structure of the nebula.** `examples/quickstart/plot_hii40.py` plots the electron
temperature and the ionisation of oxygen and carbon in every cell against its distance from the
star:

```bash
python3 /path/to/mocassin-pdr/examples/quickstart/plot_hii40.py .
```

```{figure} _figures/qs-hii40.png
:name: fig-qs-hii40
:alt: Electron temperature and the ionisation fractions of oxygen and carbon in each cell of HII40 against the distance from the star.
:width: 90%

HII40, made by `plot_hii40.py` from the run above (4 ranks). Each dot is one cell. Hydrogen is
ionised out to the edge of the model at 4.7 pc, its Strömgren radius; O²⁺ and C²⁺ give way to O⁺
and C⁺ from about 3.8 and 4.1 pc, as the harder photons are used up, and the gas heats outward as
the remaining radiation hardens.
```

The script also prints H$\beta$ and four strong lines relative to it:

```text
Hbeta: 2.012e+37 erg/s
[O III] 4959+5007  I/Hbeta = 2.142
[O II] 3726+3729   I/Hbeta = 2.227
[N II] 6548+6584   I/Hbeta = 0.6967
[S II] 6716+6731   I/Hbeta = 0.1598
```

These are the numbers the {doc}`Lexington benchmark <../benchmarks/lexington>` compares with seven
other photoionisation codes.

## 3. A nebula with dust and its PDR: hiipdr21

`hiipdr21` is the {doc}`hiipdr benchmark <../benchmarks/hiipdr>` made small: the same 40,000 K
star, now in a sphere of gas and silicate grains that reaches past the ionisation front into
neutral and molecular gas. The `pdr` keyword switches on the chemistry and the H₂ level model in
every cell. Against the benchmark it has $21^3$ cells instead of $31^3$, $2\times10^6$ packets per
iteration instead of $6\times10^6$, and at most 7 iterations; the chemistry starts at iteration 4
(`pdrStartIter 4`).

```bash
cp -r $HOME/.local/share/doc/mocassin/examples/quickstart/hiipdr21 ~/qs-hiipdr21
cd ~/qs-hiipdr21
mkdir -p output
mpirun -np 4 mocassin > run.log 2>&1
```

It takes about 9 minutes on 4 cores (5 minutes on 14) and about 0.65 GB of memory per rank
({doc}`running` explains how memory grows with the grid). Then plot the gas temperature, the
hydrogen and the carbon of every cell against the visual extinction $A_V$ from the star:

```bash
python3 /path/to/mocassin-pdr/examples/quickstart/plot_hiipdr21.py .
```

```{figure} _figures/qs-hiipdr21.png
:name: fig-qs-hiipdr21
:alt: Gas temperature, hydrogen fractions and carbon abundances of each cell of hiipdr21 against A_V from the star.
:width: 90%

hiipdr21, made by `plot_hiipdr21.py` from the run above (4 ranks). Each dot is one cell. From the
star outward: the ionised gas at 8,000–9,500 K, the ionisation front at $A_V\approx0.5$, then
neutral atomic gas at 40–50 K, hydrogen turning molecular from $A_V\approx1.2$ as the gas cools,
and carbon turning neutral at $A_V\approx2$, with CO still a trace ($\sim10^{-7}$ per H) at the
edge of this small model. The temperature axis is logarithmic: the neutral gas is at tens of kelvin.
```

**This model is not converged.** It stops at its cap of 7 iterations, and `run.log` says
`NOT CONVERGED`: after only four passes of the chemistry, the molecular gas is still changing from
one iteration to the next. That is the price of a ten-minute run. A model for science runs until
the integrated test passes ({ref}`convergence <running-convergence>`); the
{doc}`hiipdr benchmark <../benchmarks/hiipdr>` shows the same model at $31^3$ and 15 iterations,
against Cloudy.

## Next steps

- {doc}`../user-guide/keywords` and {doc}`../user-guide/outputs`: every input keyword and output
  file.
- {doc}`../user-guide/h2-manual`: a full dust + gas + PDR + H₂ model, the test problem, with maps of
  its H₂ and CO lines.
- {doc}`running`: ranks and memory, warm starts and convergence.
- {doc}`../benchmarks/index`: how the code compares with others.
