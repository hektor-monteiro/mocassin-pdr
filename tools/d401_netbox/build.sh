#!/bin/bash
# D-401. Build the one-cell box against the reduced and the full network in
# scratch copies of the source; the repository is not touched.
# Usage: tools/d401_netbox/build.sh <scratch dir> <cells.txt>
set -e
R=$(cd "$(dirname "$0")/../.." && pwd)
S=$1; C=$2
for n in reduced full; do
  mkdir -p "$S/b_$n"
  rsync -a --exclude '*.o' --exclude '*.mod' "$R/source" "$S/b_$n/"
  cp "$R/Makefile" "$S/b_$n/"
  ln -sfn "$R/dataPDR" "$S/b_$n/chemfiles"
  cp "$R/tools/d401_netbox/boxTest.f90" "$S/b_$n/source/pdrSmokeTest.f90"
  cp "$C" "$S/b_$n/cells.txt"
done
( cd "$S/b_full"
  LC_ALL=C sed -i 's/-DTHERMALBALANCE -DREDUCED/-DTHERMALBALANCE -DFULL/; s#source/pdr/odes_reduced.o#source/pdr/odes_full.o#' Makefile
  python3 "$R/tools/patch_odes_capture.py" source/pdr/odes_full.c )
for n in reduced full; do ( cd "$S/b_$n" && make PDR=1 pdrSmokeTest > build.log 2>&1 && echo "$n built" ); done
echo "run: (cd $S/b_reduced && ./pdrSmokeTest); (cd $S/b_full && ./pdrSmokeTest 1 0)"
