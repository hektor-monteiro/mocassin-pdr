#!/usr/bin/env python3
"""D-196: pull the on-axis radial profile out of a run's writeGrid dump.

Every output file is written from the same i/j/k loop (grid_mod.f90:2911), so
record N is the same cell in all of them. The axis is j = k = 1, so the record
for cell i is (i-1)*ny*nz + 1.

    grid1.out    Te, Ne, Hden                      1 line per cell
    grid2.out    ionDen(elem, stages)              nElem lines per cell,
                 H first (2 stages), He (3), C (7) ...
    pdrGrid.out  pdrZone, chiFUV, AVeff, ...       2 lines per cell, the
                 33 network abundances on the 2nd
    pdrRad.out   A_V, totalLines, J bands, Tdust   1 line per cell, after a
                 one-line header (grid_mod.f90:3048)

Emits JSON on stdout, in the shape the section 5.4 artifact's data block uses.
"""
import json
import os
import sys

NX = NY = NZ = 31
DR = 2.0e18                    # Rout 6e19 over 30 intervals
NELEM = 7                      # H He C N O Ne S
HYD_LINE, CAR_LINE = 0, 2      # offsets within a cell's element block
IH2, IH, IHP, IC, ICP, ICO = 31, 32, 19, 25, 11, 28   # 1-based, species_reduced.d
IHEP, IOH = 2, 29
TD_COL = 6                     # Tdust, 0-based, in pdrRad.out


def load(path):
    with open(path) as fh:
        return [ln.split() for ln in fh]


def main():
    run = sys.argv[1]
    out = os.path.join(run, 'output')
    g1 = load(os.path.join(out, 'grid1.out'))
    g2 = load(os.path.join(out, 'grid2.out'))
    pg = load(os.path.join(out, 'pdrGrid.out'))
    pr = load(os.path.join(out, 'pdrRad.out'))[1:]     # drop the header line

    res = {k: [] for k in ('r', 'T', 'HI', 'HII', 'HImoc', 'HIImoc',
                           'H2', 'Cp', 'C', 'CO', 'AV', 'zone',
                           'Hep', 'OH', 'Td')}

    for i in range(3, NX + 1):                 # i=3..31, as the published series
        rec = (i - 1) * NY * NZ                # 0-based record index
        if rec >= len(g1):
            break
        hyd = g2[rec * NELEM + HYD_LINE]
        car = g2[rec * NELEM + CAR_LINE]
        head = pg[rec * 2]
        abun = pg[rec * 2 + 1]

        res['r'].append((i - 1) * DR)
        res['T'].append(float(g1[rec][0]))
        res['HImoc'].append(float(hyd[0]))
        res['HIImoc'].append(float(hyd[1]))
        res['zone'].append(int(float(head[0])))
        res['AV'].append(float(head[2]))
        res['HI'].append(float(abun[IH - 1]))
        res['HII'].append(float(abun[IHP - 1]))
        res['H2'].append(float(abun[IH2 - 1]))
        # carbon: the chemistry's inside the PDR, MOCASSIN's outside, which is
        # the convention the published panel already uses
        if int(float(head[0])) == 1:
            res['Cp'].append(float(abun[ICP - 1]))
            res['C'].append(float(abun[IC - 1]))
        else:
            res['Cp'].append(float(car[1]) * 2.2e-4)
            res['C'].append(float(car[0]) * 2.2e-4)
        res['CO'].append(float(abun[ICO - 1]))
        res['Hep'].append(float(abun[IHEP - 1]))
        res['OH'].append(float(abun[IOH - 1]))
        res['Td'].append(float(pr[rec][TD_COL]) if rec < len(pr) else 0.)

    json.dump({k: [float(f'{v:.4g}') if isinstance(v, float) else v for v in vals]
               for k, vals in res.items()}, sys.stdout)


if __name__ == '__main__':
    main()
