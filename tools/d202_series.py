#!/usr/bin/env python3
"""Extract the D-202/D-203 census time series from a MOCASSIN run log.

The D-200 census reported three labels and the count of cells that changed the
HOT one; D-202 replaced that with the molecular fraction's distribution because
the swing never crossed the hot threshold (see DEVLOG D-202).  This script
turns the per-iteration blocks back into two tables:

  distribution   the f_mol histogram, one row per iteration
  drivers        f_mol / Te / chi_FUV / A_V quantiles and the movement counts

Usage:  tools/d202_series.py runs/d202-census/run.log [more.log ...]
"""
import re
import sys

# The census prints inside the iteration, BEFORE the [Summary] block that
# closes it, so the summary line is the delimiter and the census lines that
# precede it belong to the iteration it names.
ITER = re.compile(r"\[Summary\] Iteration\s+(\d+)\s+; Total:\s+([-\d.eE+]+)\s+%")
HIST = re.compile(r"\[D202\]\s+((?:\s*[-\d.]+){8})\s*$")
FMOL = re.compile(r"\[D202\]\s+f_mol\s+p10\s+([-\d.eE+]+)\s+median\s+([-\d.eE+]+)"
                  r"\s+p90\s+([-\d.eE+]+)\s+mean\s+([-\d.eE+]+)")
DMOL = re.compile(r"\[D202\]\s+\|df_mol\| since iter start\s+median\s+([-\d.eE+]+)"
                  r"\s+p90\s+([-\d.eE+]+)\s+max\s+([-\d.eE+]+)")
MOVE = re.compile(r"\[D202\]\s+moved >0.10:\s*(\d+)\s+\(\s*([-\d.]+)%\)\s+"
                  r">0.50:\s*(\d+)\s+\(\s*([-\d.]+)%\)")
TEQ = re.compile(r"\[D202\]\s+Te\s+p10\s+([-\d.eE+]+)\s+median\s+([-\d.eE+]+)"
                 r"\s+p90\s+([-\d.eE+]+)")
CHI = re.compile(r"\[D203\]\s+chiFUV\s+p10\s+([-\d.eE+]+)\s+median\s+([-\d.eE+]+)"
                 r"\s+p90\s+([-\d.eE+]+)")
AVE = re.compile(r"\[D203\]\s+AVeff\s+p10\s+([-\d.eE+]+)\s+median\s+([-\d.eE+]+)"
                 r"\s+p90\s+([-\d.eE+]+)")
UPD1 = re.compile(r"\[D204\]\s+pass-1 updateCell done.*?mean Te\s+([-\d.eE+]+)"
                  r"\s+Te>3000 K in\s*(\d+)\s+\(\s*([-\d.]+)%\)")
STRT = re.compile(r"\[D204\]\s+iteration start, for comparison.*?mean Te\s+([-\d.eE+]+)"
                  r"\s+Te>3000 K in\s*(\d+)\s+\(\s*([-\d.]+)%\)")
MSTR = re.compile(r"\[D204\]\s+mean f_mol at iteration start\s+([-\d.eE+]+)"
                  r"\s+now\s+([-\d.eE+]+)")
RATIO = re.compile(r"\[D196\]\s+x\(H\+\)_ion / x\(H\+\)_chem\s+median\s+([-\d.eE+]+)"
                   r"\s+p90\s+([-\d.eE+]+)\s+max\s+([-\d.eE+]+)")


def parse(path):
    """Return {iteration: {field: value}} for one log."""
    out, d = {}, {}
    for line in open(path, errors="replace"):
        m = ITER.search(line)
        if m:
            d["conv"] = float(m.group(2))
            out[int(m.group(1))] = d
            d = {}
            continue
        m = HIST.search(line)
        if m and "f_mol" not in line and "<.01" not in line:
            d["hist"] = [float(x) for x in m.group(1).split()]
        for key, rx, n in (("fmol", FMOL, 4), ("dmol", DMOL, 3), ("te", TEQ, 3),
                           ("chi", CHI, 3), ("av", AVE, 3), ("ratio", RATIO, 3),
                           ("upd1", UPD1, 3), ("strt", STRT, 3), ("mstr", MSTR, 2)):
            m = rx.search(line)
            if m:
                d[key] = [float(m.group(i + 1)) for i in range(n)]
        m = MOVE.search(line)
        if m:
            d["move"] = [int(m.group(1)), float(m.group(2)),
                         int(m.group(3)), float(m.group(4))]
    return out


BINS = ["<.01", ".01-.1", ".1-.3", ".3-.5", ".5-.7", ".7-.9", ".9-.99", ">=.99"]


def report(path, data):
    print("=" * 78)
    print(path)
    print("=" * 78)
    its = sorted(k for k in data if "fmol" in data[k])
    if not its:
        print("  no D-202 blocks in this log")
        return

    print("\n  f_mol = 2x(H2) distribution, % of PDR cells")
    print("   it  " + "".join("%8s" % b for b in BINS))
    for i in its:
        h = data[i].get("hist")
        if h:
            print("  %3d  " % i + "".join("%8.2f" % v for v in h))

    print("\n  drivers and movement")
    print("   it   f_mol_med  f_mol_mean   |df|_med   |df|_p90   mv>0.1%   "
          "Te_med     chi_med      AV_med    conv%")
    for i in its:
        d = data[i]
        f = d.get("fmol", [float("nan")] * 4)
        dm = d.get("dmol", [float("nan")] * 3)
        mv = d.get("move", [0, float("nan"), 0, float("nan")])
        te = d.get("te", [float("nan")] * 3)
        ch = d.get("chi", [float("nan")] * 3)
        av = d.get("av", [float("nan")] * 3)
        print("  %3d   %9.4f  %10.4f  %9.4f  %9.4f  %8.2f  %9.1f  %10.3e  "
              "%10.3e  %7.4f"
              % (i, f[1], f[3], dm[0], dm[1], mv[1], te[1], ch[1], av[1],
                 d.get("conv", float("nan"))))
    if any("upd1" in data[i] for i in its):
        print("  ordering: Te across one iteration, and where f_mol sits")
        print("   it   Te_start   Te_afterUpd1   Te_end    hot%_start  "
              "hot%_upd1  hot%_end   f_mol_start   f_mol_end")
        for i in its:
            d = data[i]
            st = d.get("strt")
            u1 = d.get("upd1")
            ms = d.get("mstr")
            if not (st and u1 and ms):
                continue
            te = d.get("te", [float("nan")] * 3)
            print("  %3d  %9.1f  %13.1f  %8.1f  %10.2f  %9.2f  %8s  %11.4f  %10.4f"
                  % (i, st[0], u1[0], te[1], st[2], u1[2], "-", ms[0], ms[1]))
        print()


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    for path in sys.argv[1:]:
        report(path, parse(path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
