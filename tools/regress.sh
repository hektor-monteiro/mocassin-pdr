#!/bin/bash
# D-314: regression suite.
#
# The only functional change in this cycle is that lgLineTransfer now defaults
# ON (D-307), plus the previously-unrunnable Q path (D-313). So the suite has
# two jobs:
#
#   off/  - MOCASSIN_LINES=off on the new binary, against the same fixture on
#           the pre-change binary. This must agree within the run-to-run
#           scatter; if it does, every historical result stays valid and only
#           the default needs re-measuring.
#   on/   - the new default, which is the physics we now ship.
#
# MOCASSIN is not bitwise reproducible, so "agree" means within the noise
# floor, which run_pair measures by running the reference twice.
#
#   tools/regress.sh <fixture-dir> <new-binary> <baseline-binary> <outdir> [np]
set -u
FIX=$1; NEW=$2; BASE=$3; OUT=$4; NP=${5:-2}

run () {   # run <binary> <env> <tag>
    local bin=$1 envv=$2 tag=$3
    rm -rf "$OUT/$tag"; mkdir -p "$OUT/$tag/output"
    cp -r "$FIX/input" "$OUT/$tag/"
    cp "$bin" "$OUT/$tag/mocassin"
    ( cd "$OUT/$tag" && env $envv mpirun -np "$NP" ./mocassin > run.log 2>&1 )
    echo "  $tag exit=$? $(grep -c 'Summary. Iteration' "$OUT/$tag/run.log" 2>/dev/null) iteration lines"
}

echo "== $(basename "$FIX") =="
run "$BASE" "MOCASSIN_LINES=unset" base_a      # pre-change binary, its own default (off)
run "$BASE" "MOCASSIN_LINES=unset" base_b      # again, to measure the noise floor
run "$NEW"  "MOCASSIN_LINES=off"   new_off     # new binary, same physics as base
run "$NEW"  "MOCASSIN_LINES=on"    new_on      # the new default
