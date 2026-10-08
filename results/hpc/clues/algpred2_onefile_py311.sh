#!/usr/bin/env bash
set -Eeuo pipefail

# Robust AlgPred2 installer + runner for WSL/Linux
# Uses a dedicated conda env with Python 3.11, installs AlgPred2 and patches
# a pandas-related compatibility bug in the package source.

usage() {
  cat <<'EOF'
Usage:
  bash algpred2_onefile_py311.sh install [--env-name algpred2_py311]
  bash algpred2_onefile_py311.sh run -i input.fa -o outdir [--env-name algpred2_py311] [-m 1] [-t 0.3] [-d 2]
  bash algpred2_onefile_py311.sh all -i input.fa -o outdir [--env-name algpred2_py311] [-m 1] [-t 0.3] [-d 2]

Notes:
  - Requires conda/mamba to be available in PATH.
  - Default model 1 = AAC-RF
  - Default threshold 0.3
  - Default display 2
EOF
}

log(){ echo "[INFO] $*"; }
die(){ echo "[ERROR] $*" >&2; exit 1; }

ENV_NAME="algpred2_py311"
MODEL="1"
THRESH="0.3"
DISPLAY="2"
INPUT=""
OUTDIR=""

need_conda() {
  command -v conda >/dev/null 2>&1 || die "conda not found in PATH"
}

abspath() {
  python - "$1" <<'PY'
import os, sys
print(os.path.abspath(os.path.expanduser(sys.argv[1])))
PY
}

patch_algpred2() {
  log "Patching installed algpred2 source for pandas compatibility"
  python - <<'PY'
import inspect
from pathlib import Path
import algpred2.python_scripts.algpred2 as m

p = Path(inspect.getsourcefile(m))
text = p.read_text(encoding="utf-8")

old = 'CM.to_csv("Sequence_1",header=False,index=None,sep="\\n")'
new = 'Path("Sequence_1").write_text("\\n".join(map(str, CM.iloc[:,0].tolist())) + "\\n", encoding="utf-8")'

if old not in text:
    print(f"[INFO] patch target not found, maybe already patched: {p}")
else:
    if 'from pathlib import Path\n' not in text:
        text = text.replace('import warnings\n', 'import warnings\nfrom pathlib import Path\n', 1)
    text = text.replace(old, new)
    p.write_text(text, encoding="utf-8")
    print(f"[INFO] patched: {p}")
PY
}

install_env() {
  need_conda
  log "Creating conda env: ${ENV_NAME}"
  conda create -y -n "${ENV_NAME}" python=3.11 pip
  eval "$(conda shell.bash hook)"
  conda activate "${ENV_NAME}"

  log "Installing AlgPred2 and dependencies"
  python -m pip install -U pip setuptools wheel
  python -m pip install "pandas==2.2.3" numpy scikit-learn joblib
  python -m pip install algpred2

  patch_algpred2

  log "Verifying imports"
  python - <<'PY'
import algpred2, joblib, pandas, sklearn, numpy
print("[INFO] algpred2 ok")
print("[INFO] pandas", pandas.__version__)
print("[INFO] sklearn", sklearn.__version__)
PY

  log "Install complete. Activate with: conda activate ${ENV_NAME}"
}

run_algpred2() {
  [[ -n "${INPUT}" ]] || die "-i input.fa is required"
  [[ -n "${OUTDIR}" ]] || die "-o outdir is required"

  INPUT="$(abspath "${INPUT}")"
  OUTDIR="$(abspath "${OUTDIR}")"
  mkdir -p "${OUTDIR}/raw"

  [[ -f "${INPUT}" ]] || die "Input FASTA not found: ${INPUT}"

  need_conda
  eval "$(conda shell.bash hook)"
  conda activate "${ENV_NAME}" || die "Failed to activate conda env ${ENV_NAME}. Run install first."

  command -v algpred2 >/dev/null 2>&1 || die "algpred2 command not found in env ${ENV_NAME}. Run install first."

  log "Running AlgPred2"
  algpred2 -i "${INPUT}" -o "${OUTDIR}/raw/algpred2_raw.csv" -m "${MODEL}" -t "${THRESH}" -d "${DISPLAY}"

  log "Post-processing outputs"
  python - "${INPUT}" "${OUTDIR}/raw/algpred2_raw.csv" "${OUTDIR}" <<'PY'
import csv, os, sys
from pathlib import Path

fasta = Path(sys.argv[1])
raw_csv = Path(sys.argv[2])
outdir = Path(sys.argv[3])

def read_fasta(path):
    recs = []
    header = None
    seq = []
    with open(path, 'r', encoding='utf-8', errors='ignore') as fh:
        for line in fh:
            line=line.strip()
            if not line:
                continue
            if line.startswith('>'):
                if header is not None:
                    recs.append((header, ''.join(seq)))
                header = line[1:].strip()
                seq = []
            else:
                seq.append(line)
        if header is not None:
            recs.append((header, ''.join(seq)))
    return recs

records = read_fasta(fasta)

# Try to parse the output flexibly.
rows = []
with open(raw_csv, 'r', encoding='utf-8', errors='ignore') as fh:
    sample = fh.read()
if not sample.strip():
    raise SystemExit("AlgPred2 output is empty")

# split lines robustly
lines = [x.strip() for x in sample.splitlines() if x.strip()]
for line in lines:
    # most outputs are comma-separated or tab-separated
    if '\t' in line:
        parts = [p.strip() for p in line.split('\t')]
    else:
        parts = [p.strip() for p in line.split(',')]
    rows.append(parts)

# build summary heuristically
summary = []
for i, (h, s) in enumerate(records):
    pred = ""
    score = ""
    raw = rows[i] if i < len(rows) else []
    joined = " | ".join(raw)
    low = joined.lower()
    if "non-allergen" in low or "non allergen" in low:
        pred = "non_allergen"
    elif "allergen" in low:
        pred = "allergen"
    else:
        pred = "unknown"
    # pick last float-like token as score if present
    for tok in reversed(raw):
        try:
            float(tok)
            score = tok
            break
        except Exception:
            pass
    summary.append((h, s, pred, score, joined))

(outdir / "allergen_summary.tsv").write_text(
    "peptide_id\tsequence\tprediction\tscore\traw_result\n" +
    "\n".join("\t".join(x) for x in summary) + "\n",
    encoding="utf-8"
)

def write_fa(path, items):
    with open(path, "w", encoding="utf-8") as w:
        for h, s, *_ in items:
            w.write(f">{h}\n{s}\n")

write_fa(outdir / "non_allergen.fa", [x for x in summary if x[2] == "non_allergen"])
write_fa(outdir / "allergen.fa", [x for x in summary if x[2] == "allergen"])
print("[INFO] wrote", outdir / "allergen_summary.tsv")
print("[INFO] wrote", outdir / "non_allergen.fa")
print("[INFO] wrote", outdir / "allergen.fa")
PY
}

cmd="${1:-}"
[[ -n "${cmd}" ]] || { usage; exit 1; }
shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-name) ENV_NAME="$2"; shift 2;;
    -i|--input) INPUT="$2"; shift 2;;
    -o|--outdir) OUTDIR="$2"; shift 2;;
    -m) MODEL="$2"; shift 2;;
    -t) THRESH="$2"; shift 2;;
    -d) DISPLAY="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) die "Unknown argument: $1";;
  esac
done

case "${cmd}" in
  install) install_env ;;
  run) run_algpred2 ;;
  all) install_env; run_algpred2 ;;
  *) usage; exit 1 ;;
esac
