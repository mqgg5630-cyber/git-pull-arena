#!/usr/bin/env bash
set -Eeuo pipefail

# =========================================================
# run_algpred2_allergen.sh
# One-file installer + allergenicity screening wrapper for peptides/proteins
# based on AlgPred2.
#
# Modes:
#   install : create Python venv and install algpred2 (and optional repo assets)
#   run     : run allergenicity prediction and split outputs into
#             non_allergen.fa / allergen.fa / summary.tsv
#   all     : install then run
#
# Default model: 1 (AAC-RF)
# Optional model: 2 (Hybrid; requires BLAST and local repo assets)
# =========================================================

MODE=""
INPUT=""
OUTDIR=""
PREFIX="${HOME}/algpred2_allergen"
PYTHON_BIN="python3"
MODEL="1"
THRESHOLD="0.3"
DISPLAY="2"
THREADS="4"
FORCE_REINSTALL="0"
REPO_URL="https://github.com/raghavagps/algpred2.git"

usage() {
  cat <<USAGE
Usage:
  bash run_algpred2_allergen.sh install [options]
  bash run_algpred2_allergen.sh run     -i input.fa -o outdir [options]
  bash run_algpred2_allergen.sh all     -i input.fa -o outdir [options]

Modes:
  install   Install AlgPred2 into a Python virtual environment.
  run       Run allergenicity prediction.
  all       Install first, then run prediction.

Required for run/all:
  -i, --input FILE         Input FASTA or one-sequence-per-line file.
  -o, --outdir DIR         Output directory.

Optional:
      --prefix DIR         Install prefix. Default: ~/algpred2_allergen
      --python EXE         Python executable. Default: python3
  -m, --model {1,2}        1 = AAC-RF; 2 = Hybrid. Default: 1
  -t, --threshold FLOAT    AlgPred2 threshold. Default: 0.3
  -d, --display {1,2}      1 = allergens only; 2 = all peptides. Default: 2
      --threads INT        Reserved for future use. Default: 4
      --force-reinstall    Recreate env / reinstall package
  -h, --help               Show help

Examples:
  bash run_algpred2_allergen.sh install --prefix ~/tools/algpred2_only

  bash run_algpred2_allergen.sh run \
    -i candidates.fa \
    -o algpred2_result \
    --prefix ~/tools/algpred2_only \
    -m 1 -t 0.3 -d 2

  bash run_algpred2_allergen.sh all \
    -i candidates.fa \
    -o algpred2_result \
    --prefix ~/tools/algpred2_only \
    -m 1
USAGE
}

log() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }
die() { echo "[ERROR] $*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    install|run|all)
      MODE="$1"; shift ;;
    -i|--input)
      INPUT="$2"; shift 2 ;;
    -o|--outdir)
      OUTDIR="$2"; shift 2 ;;
    --prefix)
      PREFIX="$2"; shift 2 ;;
    --python)
      PYTHON_BIN="$2"; shift 2 ;;
    -m|--model)
      MODEL="$2"; shift 2 ;;
    -t|--threshold)
      THRESHOLD="$2"; shift 2 ;;
    -d|--display)
      DISPLAY="$2"; shift 2 ;;
    --threads)
      THREADS="$2"; shift 2 ;;
    --force-reinstall)
      FORCE_REINSTALL="1"; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$MODE" ]] || { usage; exit 1; }
[[ "$MODEL" == "1" || "$MODEL" == "2" ]] || die "--model must be 1 or 2"
[[ "$DISPLAY" == "1" || "$DISPLAY" == "2" ]] || die "--display must be 1 or 2"

VENV_DIR="${PREFIX}/venv"
REPO_DIR="${PREFIX}/algpred2_repo"
TOOLS_ENV_SH="${PREFIX}/env_algpred2.sh"

install_algpred2() {
  need_cmd "$PYTHON_BIN"
  mkdir -p "$PREFIX"

  if [[ -d "$VENV_DIR" && "$FORCE_REINSTALL" == "1" ]]; then
    log "Removing existing virtual environment: $VENV_DIR"
    rm -rf "$VENV_DIR"
  fi

  if [[ ! -d "$VENV_DIR" ]]; then
    log "Creating Python virtual environment: $VENV_DIR"
    "$PYTHON_BIN" -m venv "$VENV_DIR"
  fi

  # shellcheck disable=SC1090
  source "$VENV_DIR/bin/activate"

  log "Upgrading pip/setuptools/wheel"
  python -m pip install --upgrade pip setuptools wheel

  log "Installing algpred2 from PyPI"
  python -m pip install --upgrade algpred2 pandas

  if command -v git >/dev/null 2>&1; then
    if [[ -d "$REPO_DIR/.git" ]]; then
      log "Updating AlgPred2 repository clone"
      git -C "$REPO_DIR" pull --ff-only || warn "git pull failed; keeping existing repo clone"
    else
      log "Cloning AlgPred2 repository"
      git clone "$REPO_URL" "$REPO_DIR" || warn "git clone failed; Model 2 local assets may be unavailable"
    fi
  else
    warn "git not found; skipping repository clone"
  fi

  if [[ "$MODEL" == "2" ]]; then
    if ! command -v blastp >/dev/null 2>&1; then
      if command -v conda >/dev/null 2>&1; then
        warn "Model 2 needs blastp; trying to install ncbi-blast+ via conda base"
        conda install -y -n base -c bioconda blast || warn "conda install blast failed"
      elif command -v apt-get >/dev/null 2>&1; then
        warn "Model 2 needs blastp; trying apt-get install ncbi-blast+"
        sudo apt-get update && sudo apt-get install -y ncbi-blast+ || warn "apt-get install ncbi-blast+ failed"
      else
        warn "blastp not found. Model 2 may fail until BLAST+ is installed manually."
      fi
    fi
  fi

  cat > "$TOOLS_ENV_SH" <<EOS
# shellcheck shell=bash
export ALGPRED2_PREFIX="$PREFIX"
export ALGPRED2_VENV="$VENV_DIR"
export ALGPRED2_REPO="$REPO_DIR"
EOS

  log "Install finished"
  log "Activate later with: source '$VENV_DIR/bin/activate'"
}

patch_envfile_for_model2() {
  local envfile="$REPO_DIR/envfile"
  [[ -f "$envfile" ]] || die "Model 2 requested but envfile not found: $envfile"
  command -v blastp >/dev/null 2>&1 || die "Model 2 requested but blastp not found in PATH"
  [[ -d "$REPO_DIR/Database" ]] || die "Model 2 requested but Database directory not found in $REPO_DIR"
  [[ -d "$REPO_DIR/progs" ]] || die "Model 2 requested but progs directory not found in $REPO_DIR"

  local blast_path merci_path db_path motif_path
  blast_path="$(command -v blastp)"
  merci_path="$REPO_DIR/progs/MERCI_motif_locator.pl"
  db_path="$REPO_DIR/Database/data"
  motif_path="$REPO_DIR/Database/pos_ige_motifs.txt"

  [[ -f "$merci_path" ]] || die "MERCI script not found: $merci_path"
  [[ -e "$db_path" ]] || die "BLAST database path not found: $db_path"
  [[ -f "$motif_path" ]] || die "Motif file not found: $motif_path"

  python <<PY
from pathlib import Path
p = Path(r'''$envfile''')
text = p.read_text()
new_lines = [
    '#Path information for BLAST and MERCI commands',
    '',
    '#Path information of the data required to run the BLAST and MERCI',
    '',
    '#User can change the paths according to their machines',
    '',
    f'BLAST:{r"$blast_path"}',
    '',
    f'BLAST database:{r"$db_path"}',
    '',
    f'MERCI:{r"$merci_path"}',
    '',
    f'MERCI motif file:{r"$motif_path"}',
]
p.write_text("\n".join(new_lines) + "\n")
print(f'Patched envfile: {p}')
PY
}

run_algpred2() {
  [[ -n "$INPUT" ]] || die "--input is required for run/all"
  [[ -n "$OUTDIR" ]] || die "--outdir is required for run/all"
  [[ -f "$INPUT" ]] || die "Input file not found: $INPUT"
  [[ -d "$VENV_DIR" ]] || die "Virtual environment not found: $VENV_DIR. Run install first."

  mkdir -p "$OUTDIR"
  local RAW_DIR="$OUTDIR/raw"
  mkdir -p "$RAW_DIR"

  # shellcheck disable=SC1090
  source "$VENV_DIR/bin/activate"

  local algpred_cmd=""
  if command -v algpred2 >/dev/null 2>&1; then
    algpred_cmd="algpred2"
  elif command -v algpred2.py >/dev/null 2>&1; then
    algpred_cmd="algpred2.py"
  else
    algpred_cmd="python -m algpred2"
  fi

  if [[ "$MODEL" == "2" ]]; then
    patch_envfile_for_model2
    log "Model 2 selected (Hybrid)"
  else
    log "Model 1 selected (AAC-RF)"
  fi

  local RAW_CSV="$RAW_DIR/algpred2_raw.csv"
  local CMD_SCRIPT="$RAW_DIR/run_algpred2_command.sh"
  cat > "$CMD_SCRIPT" <<EOS
#!/usr/bin/env bash
set -Eeuo pipefail
source "$VENV_DIR/bin/activate"
cd "$REPO_DIR" 2>/dev/null || true
$algpred_cmd -i "$INPUT" -o "$RAW_CSV" -t "$THRESHOLD" -m "$MODEL" -d "$DISPLAY"
EOS
  chmod +x "$CMD_SCRIPT"

  log "Running AlgPred2"
  bash "$CMD_SCRIPT"

  [[ -f "$RAW_CSV" ]] || die "AlgPred2 did not produce expected output: $RAW_CSV"

  local SUMMARY_TSV="$OUTDIR/allergen_summary.tsv"
  local PASS_FA="$OUTDIR/non_allergen.fa"
  local FAIL_FA="$OUTDIR/allergen.fa"
  local PASS_TXT="$OUTDIR/non_allergen_ids.txt"
  local FAIL_TXT="$OUTDIR/allergen_ids.txt"

  export INPUT_FASTA="$INPUT"
  export RAW_CSV_FILE="$RAW_CSV"
  export SUMMARY_TSV_FILE="$SUMMARY_TSV"
  export PASS_FA_FILE="$PASS_FA"
  export FAIL_FA_FILE="$FAIL_FA"
  export PASS_TXT_FILE="$PASS_TXT"
  export FAIL_TXT_FILE="$FAIL_TXT"

  python <<'PY'
import csv
import os
import re
from pathlib import Path

input_fa = Path(os.environ['INPUT_FASTA'])
raw_csv = Path(os.environ['RAW_CSV_FILE'])
summary_tsv = Path(os.environ['SUMMARY_TSV_FILE'])
pass_fa = Path(os.environ['PASS_FA_FILE'])
fail_fa = Path(os.environ['FAIL_FA_FILE'])
pass_txt = Path(os.environ['PASS_TXT_FILE'])
fail_txt = Path(os.environ['FAIL_TXT_FILE'])

# ---------- read FASTA ----------
def read_fasta(path: Path):
    records = []
    name = None
    seq_lines = []
    with path.open() as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            if line.startswith('>'):
                if name is not None:
                    records.append((name, ''.join(seq_lines)))
                name = line[1:].strip().split()[0]
                seq_lines = []
            else:
                seq_lines.append(re.sub(r'\s+', '', line))
        if name is not None:
            records.append((name, ''.join(seq_lines)))
    return records

records = read_fasta(input_fa)
seq_by_id = {rid: seq for rid, seq in records}
order = [rid for rid, _ in records]

# ---------- read AlgPred2 CSV robustly ----------
with raw_csv.open(newline='') as fh:
    sample = fh.read(4096)
    fh.seek(0)
    try:
        dialect = csv.Sniffer().sniff(sample)
    except Exception:
        dialect = csv.excel
    reader = csv.DictReader(fh, dialect=dialect)
    rows = list(reader)
    fieldnames = reader.fieldnames or []

norm = {fn.lower().strip(): fn for fn in fieldnames}

# likely columns based on AlgPred2 docs/web output:
# header/id, ml score / hybrid score, prediction
pred_col = None
score_col = None
id_col = None
sequence_col = None
for fn in fieldnames:
    fl = fn.lower().strip()
    if pred_col is None and ('prediction' in fl or fl == 'pred'):
        pred_col = fn
    if score_col is None and ('hybrid score' in fl or 'ml score' in fl or fl.endswith('score') or fl == 'score'):
        score_col = fn
    if id_col is None and (fl in {'seqid', 'sequence id', 'seq id', 'id', 'name', 'header', 'protein', 'peptide'} or 'header' in fl):
        id_col = fn
    if sequence_col is None and (fl == 'sequence' or 'seq' == fl):
        sequence_col = fn

# fallback: first column as ID-like if explicit id field missing
if id_col is None and fieldnames:
    id_col = fieldnames[0]

# match raw rows back to fasta ids in a tolerant way
result_map = {}
used_input_ids = set()
for row in rows:
    raw_id = (row.get(id_col, '') if id_col else '').strip()
    pred = (row.get(pred_col, '') if pred_col else '').strip()
    score = (row.get(score_col, '') if score_col else '').strip()
    seqv = (row.get(sequence_col, '') if sequence_col else '').strip()

    candidate_ids = []
    if raw_id:
        candidate_ids.append(raw_id)
        candidate_ids.append(raw_id.split()[0])
        candidate_ids.append(raw_id.lstrip('>'))
        candidate_ids.append(raw_id.lstrip('>').split()[0])
    matched = None
    for cid in candidate_ids:
        if cid in seq_by_id and cid not in used_input_ids:
            matched = cid
            break
    if matched is None and seqv:
        seqv_clean = re.sub(r'\s+', '', seqv)
        for rid, seq in seq_by_id.items():
            if rid not in used_input_ids and seq == seqv_clean:
                matched = rid
                break
    if matched is None:
        # last fallback: append row order later
        continue
    used_input_ids.add(matched)
    result_map[matched] = {
        'prediction_raw': pred,
        'score_raw': score,
    }

# fallback by order if row count matches fasta count and mapping incomplete
if len(result_map) < len(records) and len(rows) == len(records):
    for (rid, _), row in zip(records, rows):
        result_map.setdefault(rid, {
            'prediction_raw': (row.get(pred_col, '') if pred_col else '').strip(),
            'score_raw': (row.get(score_col, '') if score_col else '').strip(),
        })

# ---------- classify ----------
def normalize_pred(s: str):
    sl = s.strip().lower()
    if 'non' in sl and 'allergen' in sl:
        return 'non_allergen'
    if 'allergen' in sl:
        return 'allergen'
    return 'unknown'

summary_rows = []
pass_ids = []
fail_ids = []
for rid in order:
    seq = seq_by_id[rid]
    meta = result_map.get(rid, {'prediction_raw': 'NA', 'score_raw': 'NA'})
    pred_norm = normalize_pred(meta['prediction_raw'])
    pass_flag = 'True' if pred_norm == 'non_allergen' else 'False'
    if pred_norm == 'non_allergen':
        pass_ids.append(rid)
    else:
        fail_ids.append(rid)
    summary_rows.append({
        'peptide_id': rid,
        'sequence': seq,
        'algpred2_prediction_raw': meta['prediction_raw'],
        'algpred2_prediction_norm': pred_norm,
        'algpred2_score': meta['score_raw'],
        'allergen_pass': pass_flag,
    })

with summary_tsv.open('w', newline='') as out:
    writer = csv.DictWriter(out, fieldnames=list(summary_rows[0].keys()) if summary_rows else [
        'peptide_id','sequence','algpred2_prediction_raw','algpred2_prediction_norm','algpred2_score','allergen_pass'
    ], delimiter='\t')
    writer.writeheader()
    writer.writerows(summary_rows)

with pass_fa.open('w') as out:
    for rid in pass_ids:
        out.write(f'>{rid}\n{seq_by_id[rid]}\n')
with fail_fa.open('w') as out:
    for rid in fail_ids:
        out.write(f'>{rid}\n{seq_by_id[rid]}\n')

pass_txt.write_text('\n'.join(pass_ids) + ('\n' if pass_ids else ''))
fail_txt.write_text('\n'.join(fail_ids) + ('\n' if fail_ids else ''))

print(f'Total input sequences: {len(records)}')
print(f'Non-allergen passed:  {len(pass_ids)}')
print(f'Allergen/unknown:     {len(fail_ids)}')
print(f'Summary TSV:          {summary_tsv}')
print(f'Pass FASTA:           {pass_fa}')
print(f'Fail FASTA:           {fail_fa}')
PY

  log "Finished"
  log "Summary: $SUMMARY_TSV"
  log "Pass FASTA: $PASS_FA"
  log "Fail FASTA: $FAIL_FA"
}

case "$MODE" in
  install)
    install_algpred2
    ;;
  run)
    run_algpred2
    ;;
  all)
    install_algpred2
    run_algpred2
    ;;
  *)
    die "Unsupported mode: $MODE"
    ;;
esac
