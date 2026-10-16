#!/usr/bin/env python3
"""Add the sixth column, Im(m), to a Q file that has only five (D-415).

MOCASSIN's photoelectric yield is Weingartner & Draine's (2001, ApJS 134, 263; WD01). Its size effect needs the
photon attenuation length l_a = lambda / (4 pi Im(m)) (WD01 eq. 14), so a Q species needs Im(m) per wavelength,
which a standard Q file does not carry (doc/dust.md). Without it MOCASSIN refuses the species when photoelectric
heating is on (D-313).

For carbonaceous grains WD01 take graphite's two axes (their eq. 15),

    1/l_a = (4 pi / lambda) [ 2/3 Im(m_perp) + 1/3 Im(m_par) ],

with the dielectric functions of Draine & Lee (1984) and Laor & Draine (1993), and: "Since PAH dielectric
functions are not available, we use graphite dielectric functions for all carbonaceous grains" (WD01, p. 8). So a
PAH Q file (Li & Draine 2001) takes graphite's axis-weighted Im(m), the column tools/mkqfile.py writes for
dustData/grph-avg.cat. The efficiencies are not touched: each data record keeps its five columns as written and
gains the sixth.

    python tools/qfile_addk.py dustData/PAHneu_30.cat dustData/grph2-dl.nk:0.6667 dustData/grph1-dl.nk:0.3333

grph2-dl.nk is E perpendicular to the c-axis (metallic in the basal plane), grph1-dl.nk E parallel. Without --out
the file is rewritten in place; a header comment line says where its sixth column came from.
"""
import argparse
import os
import sys

import numpy as np


def read_nk(path):
    head = open(path).read().splitlines()
    a = np.loadtxt(path, skiprows=2)
    o = np.argsort(a[:, 0])
    return {'label': head[1].split()[0], 'lam': a[o, 0], 'k': a[o, 2]}


def main():
    p = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    p.add_argument('qfile', help='the five-column Q file')
    p.add_argument('axes', nargs='+', help='file.nk:weight, one per axis')
    p.add_argument('--out', help='write here instead of rewriting qfile')
    args = p.parse_args()

    ax, w = [], []
    for s in args.axes:
        f, wt = s.rsplit(':', 1)
        ax.append(read_nk(f))
        w.append(float(wt))
    w = np.array(w) / sum(w)

    L = open(args.qfile).read().split('\n')
    if L[-1] == '':
        L = L[:-1]
    if L[0].split()[0] != 'Q':
        raise SystemExit('%s: not a Q file (first line %r)' % (args.qfile, L[0]))
    # the header as MOCASSIN reads it: type, label line, comments until NRAD parses, NWAV, one title line
    i = 2
    while True:
        try:
            nrad = int(L[i].split()[0])
            if nrad > 0:
                break
        except (ValueError, IndexError):
            pass
        i += 1
    inrad = i
    nwav = int(L[inrad + 1].split()[0])
    ititle = inrad + 2
    data = L[ititle + 1:]
    if len(data) < nrad * nwav:
        raise SystemExit('%s: %d data records, NRAD x NWAV = %d' % (args.qfile, len(data), nrad * nwav))
    ncol = len(data[0].split())
    if ncol != 5:
        raise SystemExit('%s: the first data record has %d columns, not 5 - nothing to add' % (args.qfile, ncol))

    lam = np.array([float(d.split()[1]) for d in data[:nrad * nwav]])
    lo, hi = max(a['lam'][0] for a in ax), min(a['lam'][-1] for a in ax)
    if lam.min() < lo * (1 - 1e-9) or lam.max() > hi * (1 + 1e-9):
        raise SystemExit('the Q file runs %.4g-%.4g um, the n,k files only %.4g-%.4g um' % (lam.min(), lam.max(), lo, hi))
    k = np.zeros(len(lam))
    for a, wi in zip(ax, w):
        k += wi * np.interp(lam, a['lam'], a['k'])

    axl = ', '.join('%s:%.4f' % (os.path.basename(s.rsplit(':', 1)[0]), wi) for s, wi in zip(args.axes, w))
    note = '# column 6 = Im(m), k of %s (WD01 eq. 15), by tools/qfile_addk.py (D-415)' % axl
    if len(note) > 250:
        raise SystemExit('header note longer than the reader takes (256): %s' % note)
    t = L[ititle]
    title = t[:t.index('!')].rstrip() + '  Im(m)  ' + t[t.index('!'):] if '!' in t else t.rstrip() + '  Im(m)'
    out = L[:inrad] + [note] + L[inrad:ititle] + [title]
    out += ['%s %13.6e' % (d.rstrip(), kk) for d, kk in zip(data[:nrad * nwav], k)]
    out += data[nrad * nwav:]
    dest = args.out or args.qfile
    open(dest, 'w').write('\n'.join(out) + '\n')
    print('%s: %d radii x %d wavelengths, Im(m) from %s -> %s' % (args.qfile, nrad, nwav, axl, dest))
    print('  Im(m) at 0.1, 0.2, 1, 100 um: %s' % ', '.join('%.3f' % np.interp(x, np.sort(lam[:nwav]), k[:nwav][np.argsort(lam[:nwav])])
                                                       for x in (0.1, 0.2, 1.0, 100.)))


if __name__ == '__main__':
    main()
