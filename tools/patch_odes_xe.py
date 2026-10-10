#!/usr/bin/env python3
"""
DEVLOG D-402. Let the host add electrons the network does not carry.

The generated right-hand side builds x_e as the sum of the network's own
cations. In MOCASSIN-PDR the gas also holds ions the network has no species
for - every stage above the first ion, and the elements it does not carry -
and their electrons were missing from the solve. This adds one term to that
sum, chemistry_module's xe_extra (modules.F90), which is zero unless the host
sets it: upstream behaviour by default.

Written as a re-runnable patch because the odes_*.c files are generated:
regenerate the network, run this again. Idempotent.

Usage:  python3 tools/patch_odes_xe.py source/pdr/odes_reduced.c [...]
"""
import re
import sys

MARK = "/* D-402 xe_extra */"
EXTERN = """
/* D-402: electrons per H nucleus from ions the network does not carry,
 * supplied by the host (chemistry_module, modules.F90). Zero by default. */
extern double chemistry_module_mp_xe_extra_;
"""
XE = re.compile(r"^(\s*)x_e\s*=\s*(?!chemistry_module_mp_xe_extra_)(.*)$")


def patch(path):
    src = open(path).read()
    if MARK in src:
        print(f"  {path}: already patched, left alone")
        return 0
    lines = src.split("\n")
    out, n = [], 0
    for line in lines:
        m = XE.match(line)
        if m and n == 0:
            out.append(f"{m.group(1)}x_e = chemistry_module_mp_xe_extra_+{m.group(2)} {MARK}")
            n += 1
        else:
            out.append(line)
    if n != 1:
        raise SystemExit(f"{path}: no 'x_e = ...' line found - the generator's "
                         "output shape has changed, check before forcing")
    inc = [k for k, l in enumerate(out) if l.startswith("#include")]
    out.insert(inc[-1] + 1, EXTERN)
    open(path, "w").write("\n".join(out))
    print(f"  {path}: x_e takes the host's extra electrons")
    return 1


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    for p in sys.argv[1:]:
        patch(p)
