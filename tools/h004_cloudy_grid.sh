#!/bin/bash
# H-004: writes the 18 one-zone Cloudy inputs of the pumping reference grid and
# a run_all.sh beside them (runs/ is not tracked). T = 100, 1000 K; log n_H =
# 2, 4, 6; FUV = 1, 1e2, 1e4 x 1.6e-3 erg cm^-2 s^-1 over 0.4412-1 Ryd.
#
#    tools/h004_cloudy_grid.sh <dir> [cloudy.exe]
set -e
export LC_ALL=C
D=${1:?directory}
EXE=${2:-$HOME/software/cloudy-c25.00/source/cloudy.exe}
mkdir -p "$D"
for T in 100 1000; do for n in 2 4 6; do for g in 0 2 4; do
  d=$D/T${T}_n${n}_G${g}; mkdir -p "$d"
  I=$(awk -v g=$g 'BEGIN{printf "%.4f", log(1.6e-3)/log(10)+g}')
  cat > "$d/pump.in" <<EOT
title H2 pumping test (H-004): T=$T K, log n_H=$n, FUV = 1e$g Habing
black 30000
intensity $I range 0.4412 to 1 Ryd
extinguish 24 0
cosmic rays, background
abundances ism
hden $n
set dr 0
stop zone 1
database h2
iterate 3
constant temperature ${T}K
save last overview "pump.ovr"
save last continuum units Ryd "pump.con"
save last species densities "pump.dens"
e-
H
H+
H2
H2*
H-
H2+
H3+
He
He+
end
save H2 populations last "pump.pops"
save last H2 rates "pump.rates"
save last H2 solomon "pump.sol"
save last H2 levels "pump.lev"
save last chemistry rates destruction "pump.h2dest" species "H2"
save last chemistry rates creation "pump.h2crea" species "H2"
save last chemistry rates destruction "pump.h2sdest" species "H2*"
save last chemistry rates creation "pump.h2screa" species "H2*"
save last grain H2rates "pump.gh2"
EOT
done; done; done
cat > "$D/run_all.sh" <<EOT
#!/bin/bash
cd "\$(dirname "\$0")"
ls -d T*_n*_G* | xargs -P 9 -I{} bash -c 'cd {} && $EXE -r pump > cloudy.stdout 2>&1'
touch DONE
EOT
chmod +x "$D/run_all.sh"
echo "wrote $(ls -d "$D"/T*_n*_G* | wc -l) inputs in $D; run $D/run_all.sh (~10 s each)"
