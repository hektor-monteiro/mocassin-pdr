#!/usr/bin/env python3
"""The tutorial's checks of a finished run: how it stopped, the cells MOCASSIN flagged, the hydrogen
budget of the chemistry, and the last iteration's convergence.

    python3 check_model.py RUN

RUN is the model's directory (the one holding input/ and output/, and run.log if the run's output was
written there). Needs numpy, and tools/mocread.py of the MOCASSIN-PDR repository. The hydrogen budget
is the largest |sum_s h(s) x(s) - 1| over the active points, where x(s) is the abundance per H of each
species of the reduced network (pdrGrid.out) and h(s) its number of hydrogen atoms: every hydrogen
atom is in exactly one species, so the sum is 1.
"""
import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'tools'))
try:
    import mocread
except ImportError:
    print("run this script from the repository's examples/tutorial/")
    sys.exit(1)

import numpy as np

STOPS = ('convergence reached', 'NOT CONVERGED', 'maximum number of iterations')


def n_hydrogen(name):
    """the number of H atoms in a species name: H3+ 3, CH5+ 5, H2O 2, HCO+ 1, He 0, e- 0"""
    return sum(int(k or 1) for el, k in re.findall(r'(He|Mg|[A-Z])(\d*)', name.strip('+-')) if el == 'H')


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('run')
    run = ap.parse_args().run

    log = os.path.join(run, 'run.log')
    if os.path.exists(log):
        stop = [ln.strip() for ln in open(log, errors='replace') if any(s in ln for s in STOPS)]
        print('stop:', stop[-1] if stop else 'no stop line in run.log')
    else:
        print('stop: no run.log')

    g = mocread.read_grid(run)
    act = g.active > 0
    print(f'cells: {int(act.sum())} active points, {int((act & g.black).sum())} flagged')

    p = mocread.read_pdr(run, g)
    tot = sum(p.abundance(s) for s in mocread.REDUCED_SPECIES)
    hsum = sum(n_hydrogen(s) * p.abundance(s) for s in mocread.REDUCED_SPECIES)
    k = act & (tot > 0)
    print(f'hydrogen budget: max |sum_s h(s) x(s) - 1| = {np.abs(hsum[k] - 1).max():.2g} '
          f'over {int(k.sum())} active points')

    names, a = mocread.read_convergence(run)
    last = a[-1]
    print(f'convergence: iteration {int(last[names.index("it")])}, '
          f'cells {last[names.index("cells%")]:.2f}%, worst {last[names.index("worst%")]:.3f}%')


if __name__ == '__main__':
    main()
