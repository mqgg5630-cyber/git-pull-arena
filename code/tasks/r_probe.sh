#!/bin/bash
# r_probe.sh - run INSIDE WSL via: bash r_probe.sh <output-file>
# Collects every R-related installation fact (versions, paths, sizes).
out="$1"
{
echo "==WHICH=="
which R Rscript 2>/dev/null
echo "==VER=="
R --version 2>/dev/null | head -2
echo "==DIRS=="
for d in /opt/R* /usr/lib/R /usr/local/lib/R "$HOME/R" "$HOME/rbase" /usr/local/bin/R; do
  [ -e "$d" ] && ls -d "$d"
done
echo "==CONDA=="
ls "$HOME/miniconda3/envs" "$HOME/anaconda3/envs" 2>/dev/null
for ce in "$HOME/miniconda3/bin/conda" "$HOME/anaconda3/bin/conda"; do
  [ -x "$ce" ] && "$ce" env list 2>/dev/null
done
echo "==DPKG=="
dpkg -l 2>/dev/null | grep -E "r-base-core|r-cran-" | head -8
echo "==SIZES=="
for d in /opt/R* /usr/lib/R "$HOME/R" "$HOME/miniconda3/envs/r-base" "$HOME/miniconda3/envs/r4" "$HOME/anaconda3/envs/r-base"; do
  [ -e "$d" ] && du -sh "$d" 2>/dev/null
done
echo "==R_LIBS_USER=="
ls -d "$HOME/R/x86_64"* 2>/dev/null
echo "==DONE=="
} > "$out" 2>&1
