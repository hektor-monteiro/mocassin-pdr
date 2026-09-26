#!/bin/bash
# Regression: a new binary against a baseline binary on one fixture, at a
# fixed randomSeed (D-334), so the comparison is exact rather than against a
# measured noise floor. Physics-neutral changes must come back byte-identical;
# anything else is a physics change and is compared with regress_cmp.py.
#
# D-352: the MOCASSIN_LINES on/off A/B this script used to run (D-314) is
# gone with the switch - the thin diffuse lines are always transported, and a
# binary built after D-352 refuses to run with any MOCASSIN_* physics variable
# set. Both runs are started with those variables removed from the
# environment, so an old baseline binary runs at its own defaults too.
#
#   tools/regress.sh <fixture-dir> <new-binary> <baseline-binary> <outdir> [np] [seed]
set -u
FIX=$1; NEW=$2; BASE=$3; OUT=$4; NP=${5:-14}; SEED=${6:-1001}

run () {   # run <binary> <tag>
    local bin=$1 tag=$2
    rm -rf "$OUT/$tag"; mkdir -p "$OUT/$tag/output"
    cp -r "$FIX/input" "$OUT/$tag/"
    grep -q '^ *randomSeed' "$OUT/$tag/input/input.in" || \
        echo "randomSeed $SEED" >> "$OUT/$tag/input/input.in"
    cp "$bin" "$OUT/$tag/mocassin"
    ( cd "$OUT/$tag" && env -u MOCASSIN_LINES -u MOCASSIN_RECCOOL -u MOCASSIN_YIELD \
          -u MOCASSIN_GRAINQ mpirun -np "$NP" ./mocassin > run.log 2>&1 )
    echo "  $tag exit=$? $(grep -c 'Summary. Iteration' "$OUT/$tag/run.log" 2>/dev/null) iteration lines"
}

echo "== $(basename "$FIX") (seed $SEED, $NP ranks) =="
run "$BASE" base
run "$NEW"  new
for f in "$OUT"/base/output/*; do
    g="$OUT/new/output/$(basename "$f")"
    if cmp -s "$f" "$g"; then echo "  identical  $(basename "$f")"
    else echo "  DIFFERENT  $(basename "$f")"; fi
done
