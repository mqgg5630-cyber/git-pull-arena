#!/usr/bin/env bash
set -Eeuo pipefail
source "/home/w20/algpred2_only/venv/bin/activate"
cd "/home/w20/algpred2_only/algpred2_repo" 2>/dev/null || true
algpred2 -i "/mnt/d/桌面/AI/e-yu/pepfun.fa" -o "/mnt/d/桌面/AI/e-yu/algpred2_result/raw/algpred2_raw.csv" -t "0.3" -m "1" -d "2"
