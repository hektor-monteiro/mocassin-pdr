# Dust optical data (`dustData/`)

Optical constants (`.nk`: wavelength, n, k) and tabulated efficiencies (`.cat`, Q files)
that MOCASSIN reads from `PREFIX/share/mocassin/dustData/` when a species file names
them. They are third-party scientific data, redistributed under their providers' terms;
the GNU GPL of MOCASSIN-PDR covers the code, not these files (see
`../THIRD_PARTY_NOTICES.md`). Please cite the original papers of the data you use; most
files name them in a footer.

## From DUSTY (BSD 3-clause)

`OssOdef.nk`, `OssOrich.nk`, `SiC-peg.nk`, `amC-hann.nk`, `amC-zb1.nk`, `amC-zb2.nk`,
`amC-zb3.nk`, `crMgFeSil.nk`, `crSil.nk`, `glSil.nk`, `glpyrMg50.nk`, `grph1-dl.nk`,
`grph2-dl.nk`, `opyr-pwd.nk`, `opyr-slb.nk`, `sil-dlee.nk`, `sil-oss1.nk`, `sil-oss2.nk`
(and their copies in `dustData_POwen/`) come, reformatted, from the optical-constant
library (`Lib_nk`) of DUSTY (Ivezić & Elitzur 1997; https://github.com/ivezic/dusty).
Their footers name the original measurements (Ossenkopf et al. 1992, Pégourié 1988,
Hanner 1988, Zubko et al. 1996, Jäger et al. 1994, Dorschner et al. 1995, Draine & Lee
1984, and others); `sil-dlee.nk`, `grph1-dl.nk` and `grph2-dl.nk` are Draine & Lee
(1984). DUSTY's licence:

```text
Copyright (c) 2016, Zeljko Ivezic
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of dusty nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

## From B. T. Draine

From https://www.astro.princeton.edu/~draine/dust/dust.diel.html, whose author asks
users to cite the appropriate references:

| Files | Data | Cite |
| :--- | :--- | :--- |
| `Sil_21`, `Sil_21.gz`, `Sil_21.cat`, `suvSil_21`, `suvSil_21.gz`, `suvSil_81`, `suvSil_81.gz`, `suvSil_81.cat`, `callindex.out_silD03` | astronomical silicate | Draine & Lee 1984; Laor & Draine 1993; Weingartner & Draine 2001; Draine 2003 |
| `Car_90.cat` | graphite | Draine & Lee 1984; Laor & Draine 1993; Draine 2003 |
| `PAHneu_30.cat` | neutral PAHs | Li & Draine 2001, ApJ 554, 778. **Modified here** (DEVLOG D-415): an Im(m) column was added by `tools/qfile_addk.py` for the photoelectric yield; the efficiencies are unchanged. `PAHneu_30/PAHneu_30.cat` is the unmodified table without its original header. |
| `astroSilD2003.nk`, `astroSilD2003_base.nk` (and copies in `new_dust_files/`) | astronomical silicate, converted to n, k | Draine 2003 |
| `sil-dlaor.nk`, `gr1-dl-hgk.nk`, `gr2-dl-hgk.nk` | silicate and graphite | Laor & Draine 1993; Draine & Lee 1984 (from the files' labels; the files carry no footer) |

## Compilations by N. Wright and P. Owen

`dust_nk_Nwright/` (N. Wright, UCL, 2006–2010) and `dustData_POwen/` (P. Owen,
2012–2014) were provided by
M. J. Barlow and are included with permission. Their files' footers name the original
data:
- `enst-cryst-*-jena-uvx.nk`: crystalline enstatite, Jena laboratory (Jäger et al. 1998);
- `forst-cryst-*-kyoto-uvx.nk`: crystalline forsterite, Kyoto (Sogawa et al. 2006);
- `feo.nk`: FeO (Henning & Mutschke 1997);
- `graph_dr_par.nk`, `graph_dr_perp.nk`: graphite (Draine 2003);
- `h20_crystalline.nk`: crystalline water ice (Warren 1984);
- `amCarbon.nk`: amorphous carbon (Rouleau & Martin 1991, and others named in its footer).

`rouleau91_ac.nk` and `amC-rmmod.nk` are amorphous carbon after Rouleau & Martin
(1991), per their labels; `zb2mod.nk` is a modified Zubko et al. (1996) amorphous carbon; the source of
`alumina.nk` is not recorded. The top-level copies of the Wright files are the ones
species files name.

## Other files

| Files | Data | Source |
| :--- | :--- | :--- |
| `Enstatite100K_Epx.nk`, `Enstatite100K_Epy.nk`, `Enstatite100K_Epz.nk` | orthoenstatite at 100 K, 6.7–60 μm | probably the Jena database (Zeidler et al. 2015), **not verified**; the footer inside these files ("Jaeger et al. 1994 ... 203 entries") was copied from `crSil.nk` by mistake and does not describe them |
| `Quartz300K_Epab.nk`, `Quartz300K_Epc.nk`, `oliv_nk_x.nk`, `oliv_nk_y.nk`, `oliv_nk_z.nk` | quartz at 300 K, olivine | source not recorded (probably the Jena database), **not verified** |
| `h20_Warren08.nk` | water ice | Warren & Brandt 2008, J. Geophys. Res. 113, D14220 |
| `dirty-ice.nk` | dirty ice | Preibisch et al. 1993 |
| `H2O_ice.nk`, `H2O_dirtyice.nk`, `new_dust_files/*` | ice and silicate mixtures | made here from the files above by `update_H2Odata.py` and `match_dust_files.py`; each footer names its sources |
| `grph-avg.cat` | graphite Q file, orientation-averaged | made here from `grph1-dl.nk`, `grph2-dl.nk` by `tools/mkqfile.py` (DEVLOG D-313) |
| `H2Oice-15-200um-Curtisetal2005.txt` | water-ice optical constants, 15–200 μm | Table 4 of Curtis et al. 2005, Appl. Opt. 44, 4102 (© 2005 Optical Society of America); kept for reference, no code reads it |
| `nuDustRyd*`, `nuRyd.dat`, `makenk.f90`, `makeNuRyd.f90`, `*.py` | frequency grids and helper programs | MOCASSIN and this project (GPL) |
