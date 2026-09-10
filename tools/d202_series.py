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
WARM = re.compile(r"\[D202\]\s+Te > 3000 K:\s*(\d+)\s+\(\s*([-\d.]+)%\)")
UPD1 = re.compile(r"\[D204\]\s+pass-1 updateCell done.*?mean Te\s+([-\d.eE+]+)"
                  r"\s+Te>3000 K in\s*(\d+)\s+\(\s*([-\d.]+)%\)")
STRT = re.compile(r"\[D204\]\s+iteration start, for comparison.*?mean Te\s+([-\d.eE+]+)"
                  r"\s+Te>3000 K in\s*(\d+)\s+\(\s*([-\d.]+)%\)")
MSTR = re.compile(r"\[D204\]\s+mean f_mol at iteration start\s+([-\d.eE+]+)"
                  r"\s+now\s+([-\d.eE+]+)")
# D-217: MOCASSIN's own budget, per outcome group. A label line opens a group;
# the entry and exit lines that follow carry Te then the 9 budget terms.
BUDLAB = re.compile(r"\[D217\]\s+(cold -> hot|stayed cold|started hot)\s+cells\s+(\d+)")
BUDROW = re.compile(r"\[D217\]\s+(entry|exit)\s+Te\s*([-\d.eE+]+)\s+heat phot/PE/PDR"
                    r"((?:\s*[-\d.eE+]+){3})\s+cool coll/rec/ff/gd/PDR"
                    r"((?:\s*[-\d.eE+]+){5})\s+H-C\s*([-\d.eE+]+)")
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
        m = BUDLAB.search(line)
        if m:
            d.setdefault("bud", {})[m.group(1)] = {"n": int(m.group(2))}
            d["_budgrp"] = m.group(1)
            continue
        m = BUDROW.search(line)
        if m and d.get("_budgrp"):
            heat = [float(x) for x in m.group(3).split()]
            cool = [float(x) for x in m.group(4).split()]
            d["bud"][d["_budgrp"]][m.group(1)] = {
                "Te": float(m.group(2)), "heat": heat, "cool": cool,
                "net": float(m.group(5))}
            continue
        m = WARM.search(line)
        if m:
            d["warm"] = [int(m.group(1)), float(m.group(2))]
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
        print("  ordering (D-204): three points in one MC iteration")
        print("    start   = iteration start")
        print("    upd1    = after pass-1 updateCell; thermal balance done, "
              "chemistry NOT yet run")
        print("    end     = end of iteration; chemistry has run")
        print("  A jump already present at upd1, with f_mol still at its start")
        print("  value, means Te leads and the chemistry follows a hot cell.")
        print()
        print("   it   | cells with Te > 3000 K, %  |  mean Te, K        "
              "|   mean f_mol")
        print("        |  start    upd1     end    |  start     upd1    "
              "|  start     end")
        for i in its:
            d = data[i]
            st, u1, ms = d.get("strt"), d.get("upd1"), d.get("mstr")
            if not (st and u1 and ms):
                continue
            wm = d.get("warm", [0, float("nan")])
            print("  %3d   | %6.2f  %6.2f  %6.2f   | %8.1f %8.1f   | %7.4f  %7.4f"
                  % (i, st[2], u1[2], wm[1], st[0], u1[0], ms[0], ms[1]))
        print()


def report_budget(data):
    """D-217 table: MOCASSIN's own budget per outcome group, entry and exit."""
    its = sorted(k for k in data if "bud" in data[k])
    if not its:
        return
    print("  MOCASSIN's own thermal budget (D-217), per H nucleus, group means")
    print("    entry = first thermBalance call: iteration-start Te, NEW field")
    print("    exit  = last call: where the solve left the cell")
    hdr = ("   it  group        slot    cells       Te    h:phot      h:PE     h:PDR"
           "    c:coll     c:rec      c:ff      c:gd     c:PDR       H-C")
    print(hdr)
    for i in its:
        for grp in ("cold -> hot", "stayed cold", "started hot"):
            g = data[i]["bud"].get(grp)
            if not g:
                continue
            for slot in ("entry", "exit"):
                r = g.get(slot)
                if not r:
                    continue
                vals = r["heat"] + r["cool"] + [r["net"]]
                print("  %3d  %-11s  %-5s  %7d  %7.1f " % (i, grp, slot, g["n"], r["Te"])
                      + "".join("%10.2e" % v for v in vals))
        print()


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    for path in sys.argv[1:]:
        data = parse(path)
        report(path, data)
        report_budget(data)
    return 0


if __name__ == "__main__":
    sys.exit(main())
