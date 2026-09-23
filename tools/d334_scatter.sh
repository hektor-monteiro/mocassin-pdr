#!/usr/bin/env bash
# D-334: build an ensemble of repeats of one fixture, differing only in the
# Monte Carlo seed, so the run-to-run scatter on the PRODUCTION grid can be
# measured. D-314 measured it on a 5^3 fixture (37% in median T_gas) and every
# published comparison has rested on one draw since.
#
#   tools/d334_scatter.sh <source-run> <outdir> <nreps> <seed0>
#
# <source-run> is an existing run directory whose input/ is copied verbatim;
# only `randomSeed` is appended, so the ensemble is the published physics.
set -euo pipefail

SRC=${1:?source run directory}
OUT=${2:?output directory}
N=${3:-4}
SEED0=${4:-1000}
BIN=${BIN:-$(cd "$(dirname "$0")/.." && pwd)/mocassin}
NP=${NP:-14}

[ -d "$SRC/input" ] || { echo "no $SRC/input"; exit 1; }
[ -x "$BIN" ]       || { echo "no binary at $BIN"; exit 1; }

mkdir -p "$OUT"
for i in $(seq 1 "$N"); do
    seed=$((SEED0 + i))
    d="$OUT/s$seed"
    if [ -f "$d/output/grid1.out" ]; then echo "skip $d (done)"; continue; fi
    rm -rf "$d"; mkdir -p "$d/output"
    cp -r "$SRC/input" "$d/"
    # strip any seed the source carried, then set ours - one reality per value
    grep -v '^randomSeed' "$d/input/input.in" > "$d/input/input.tmp"
    mv "$d/input/input.tmp" "$d/input/input.in"
    echo "randomSeed $seed" >> "$d/input/input.in"
    echo "=== $d  seed $seed  $(date +%H:%M:%S) ==="
    ( cd "$d" && mpirun -np "$NP" "$BIN" > run.log 2>&1 ) || echo "FAILED $d"
    grep -E "random seed|Total:.*converged|total run time" "$d/run.log" | tail -3
done
echo "=== ensemble complete $(date +%H:%M:%S) ==="
