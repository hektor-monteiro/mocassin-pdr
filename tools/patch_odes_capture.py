#!/usr/bin/env python3
"""
DEVLOG D-113. Export per-species form/loss from the generated ODE files.

The odes_*.c files are GENERATED, so this is written as a re-runnable patch
rather than a hand edit: regenerate the network, run this again. It is
idempotent - a file that already carries the capture is left alone.

Every ODE line in those files has the identical shape

    ode[N] = form+x[N]*loss;

where form is an additive production rate and loss a specific destruction
rate. Both are computed and then overwritten on the next species. This
appends a store of each into the C-visible arrays declared in
chemistry_module (modules.F90).

Usage:  python3 tools/patch_odes_capture.py source/pdr/odes_reduced.c [...]
"""
import re
import sys

MARK = "/* D-113 capture */"
EXTERN = """
/* D-113: per-species formation and destruction rates, exported to Fortran.
 * Declared in chemistry_module (modules.F90) with bind(c), the same
 * convention calculate_abundances.c already uses for the tolerances. */
extern double chemistry_module_mp_species_form_[];
extern double chemistry_module_mp_species_loss_[];
"""

ODE = re.compile(r"^(\s*)ode\[(\d+)\]\s*=\s*form\+x\[(\d+)\]\*loss;\s*$")


def patch(path):
    src = open(path).read()
    if MARK in src:
        print(f"  {path}: already patched, left alone")
        return 0
    lines = src.split("\n")
    out, n = [], 0
    for line in lines:
        out.append(line)
        m = ODE.match(line)
        if m:
            indent, i, j = m.group(1), m.group(2), m.group(3)
            if i != j:
                raise SystemExit(f"{path}: unexpected ode/x index mismatch: {line}")
            out.append(f"{indent}chemistry_module_mp_species_form_[{i}] = form; "
                       f"chemistry_module_mp_species_loss_[{i}] = loss; {MARK}")
            n += 1
    if n == 0:
        raise SystemExit(f"{path}: no 'ode[N] = form+x[N]*loss;' lines found - "
                         "the generator's output shape has changed, check before forcing")
    body = "\n".join(out)
    # insert the externs after the last #include so they precede any use
    inc = [k for k, l in enumerate(body.split("\n")) if l.startswith("#include")]
    bl = body.split("\n")
    bl.insert(inc[-1] + 1, EXTERN)
    open(path, "w").write("\n".join(bl))
    print(f"  {path}: {n} species captured")
    return n


if __name__ == "__main__":
    targets = sys.argv[1:] or ["source/pdr/odes_reduced.c"]
    total = sum(patch(t) for t in targets)
    print(f"total: {total} capture points")
