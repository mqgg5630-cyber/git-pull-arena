#!/usr/bin/env bash
# pptmaster_local.sh - the LOCAL plane on Linux/macOS: install PPT Master here and
# build the deck with THIS machine's own venv.
#
# Linux/macOS twin of code/pptmaster_local.ps1 (Windows). Same job, same order,
# same receipts - only the tools differ:
#   powershell -File pptmaster_local.ps1   ->  bash pptmaster_local.sh
#   Find-Py over registry/PATH             ->  a candidate list + `--version` probe
#   PowerPoint COM read-only open          ->  LibreOffice headless (soffice)
#   Scheduled Task (watcher)               ->  systemd --user timer / cron
#
# What it does, in order (idempotent - re-running is safe):
#   1. find a working python 3.10+ (PATH, conda base, common install dirs)
#   2. clone hugohe3/ppt-master into <install dir> unless it is already there
#   3. create <install>/.venv, install the core deps (best effort, in order:
#      wheel-only -> plain -> a mirror)
#   4. run code/pptmaster_pipeline.py with that venv: author the pages, checker,
#      export the native pptx, structural re-check, pptx_delivery_check
#   5. prove a real application can open the file: LibreOffice headless converts
#      it (soffice --headless --convert-to pdf) and the slide count is re-read
#      from the pptx; that result is folded into the receipt as powerpoint=...
#   6. write <install>/make-deck.sh so the user can rebuild without the agent
#
# Exit 0 = the local plane verified (or was skipped with a printed reason),
# 1 = it failed - the round must fail.
#
# Usage: bash code/pptmaster_local.sh [--repo DIR] [--root DIR] [--skip-install]
#                                     [--skip-open] [--update]
set -u -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
ROOT=""
SKIP_INSTALL=0
SKIP_OPEN=0
UPDATE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --repo) REPO="$(cd "$2" && pwd)"; shift 2 ;;
        --root) ROOT="$2"; shift 2 ;;
        --skip-install) SKIP_INSTALL=1; shift ;;
        --skip-open) SKIP_OPEN=1; shift ;;
        --update) UPDATE=1; shift ;;
        *) echo "unknown flag: $1" >&2; exit 1 ;;
    esac
done

say() { echo "PPTMASTER: $*"; }
[ -z "$ROOT" ] && ROOT="$(dirname "$REPO")"
INSTALL="$ROOT/ppt-master"
HOST="$(hostname 2>/dev/null | cut -d. -f1)"; [ -z "$HOST" ] && HOST="localhost"
CORE_PKGS=(PyYAML python-pptx XlsxWriter skia-pathops uharfbuzz Pillow numpy)
CORE_IMPORTS=(yaml pptx xlsxwriter pathops uharfbuzz PIL numpy)

say "repo    : $REPO"
say "install : $INSTALL"
say "host    : $HOST"

# ------------------------------------------------------------------ 1. python
PY=""
try_python() {
    local cand="$1"
    [ -z "$cand" ] && return 1
    case "$cand" in
        */*) [ -x "$cand" ] || return 1 ;;
        *) command -v "$cand" >/dev/null 2>&1 || return 1 ;;
    esac
    # "Python 3.11.9" - split it without bash-only expansions so this runs on
    # any /bin/sh-derived bash, old or new
    set -- $("$cand" --version 2>&1 | head -1)
    [ "$1" = "Python" ] || return 1
    case "$2" in 3.*) ;; *) return 1 ;; esac
    major="${2%%.*}"
    minor="${2#*.}"
    minor="${minor%%.*}"
    [ "$major" -ge 3 ] 2>/dev/null || return 1
    [ "$major" -gt 3 ] && { PY="$cand"; return 0; }
    [ "$minor" -ge 10 ] 2>/dev/null || return 1
    PY="$cand"
    return 0
}
for cand in "${GIT_SYNC_PPTMASTER_PYTHON:-}" python3 python "$HOME/miniconda3/bin/python" \
            "$HOME/anaconda3/bin/python" /usr/local/bin/python3 /usr/bin/python3; do
    if try_python "$cand"; then
        pyver="$("$PY" --version 2>&1)"
        say "python  : $PY ($pyver)"
        break
    fi
done
if [ -z "$PY" ]; then
    say "[FAIL] no python 3.10+ found (tried PATH, conda base dirs, /usr/bin)"
    exit 1
fi

# ------------------------------------------------------------------ 2. clone
GIT="$(command -v git || true)"
[ -z "$GIT" ] && { say "[FAIL] git is not on PATH"; exit 1; }
if [ -d "$INSTALL/.git" ]; then
    say "clone   : present"
    if [ "$UPDATE" = "1" ]; then
        say "update  : git fetch + reset"
        git -C "$INSTALL" fetch --depth 1 origin main >/dev/null 2>&1 && \
            git -C "$INSTALL" reset --hard FETCH_HEAD >/dev/null 2>&1 || \
            say "[WARN] update failed - keeping the current checkout"
    fi
elif [ -e "$INSTALL" ]; then
    say "[FAIL] $INSTALL exists but is not a git clone - refusing to touch it"
    exit 1
else
    say "clone   : git clone --depth 1"
    mkdir -p "$ROOT" 2>/dev/null || true
    if ! git clone --depth 1 --quiet https://github.com/hugohe3/ppt-master.git "$INSTALL"; then
        say "[FAIL] git clone failed (network/proxy?)"
        exit 1
    fi
    say "clone   : done"
fi
[ -d "$INSTALL/skills/ppt-master/scripts" ] || {
    say "[FAIL] $INSTALL/skills/ppt-master/scripts is missing - not a usable clone"; exit 1; }

# ------------------------------------------------------------------ 3. venv
VENV="$INSTALL/.venv"
VPY="$VENV/bin/python"
MODE="venv"
if [ "$SKIP_INSTALL" = "1" ] && [ -x "$VPY" ]; then
    say "install : skipped (--skip-install)"
else
    if [ ! -x "$VPY" ]; then
        say "venv    : creating"
        if ! "$PY" -m venv "$VENV" >/dev/null 2>&1; then
            say "[WARN] venv creation failed - falling back to the base interpreter"
            MODE="direct"; VPY="$PY"
        else
            say "venv    : created"
        fi
    else
        say "venv    : present"
    fi
    if [ "$MODE" = "venv" ]; then
        "$VPY" -m pip --version >/dev/null 2>&1 || "$VPY" -m ensurepip --upgrade >/dev/null 2>&1
        pip_install() {
            "$VPY" -m pip install -q --disable-pip-version-check "$@" >/dev/null 2>&1
        }
        say "deps    : pip install (core, wheel-only)"
        if ! pip_install --only-binary :all: "${CORE_PKGS[@]}"; then
            say "deps    : pip install (core)"
            if ! pip_install "${CORE_PKGS[@]}"; then
                say "deps    : pip install (core, mirror)"
                if ! pip_install -i https://pypi.tuna.tsinghua.edu.cn/simple "${CORE_PKGS[@]}"; then
                    say "[FAIL] the core dependencies did not install - the pipeline cannot run"
                    exit 1
                fi
            fi
        fi
        say "deps    : core ok"
        if [ -f "$INSTALL/requirements.txt" ]; then
            say "deps    : pip install -r requirements.txt (optional extras, best effort)"
            pip_install -r "$INSTALL/requirements.txt" || \
                say "[WARN] optional extras did not all install - the deck pipeline only needs the core set"
        fi
    fi
fi

# ------------------------------------------------------------------ 4. pipeline
DEPS_FULL="-1"
[ "$MODE" = "venv" ] && DEPS_FULL="0"
say "pipeline: $VPY code/pptmaster_pipeline.py --environment linux"
"$VPY" "$REPO/code/pptmaster_pipeline.py" --ppt-master "$INSTALL" --python "$VPY" \
    --repo "$REPO" --environment linux --host "$HOST" --python-mode "$MODE" \
    --deps-full-ok "$DEPS_FULL"
PIPE_CODE=$?
if [ "$PIPE_CODE" -ne 0 ]; then
    say "[FAIL] the deck pipeline failed (exit $PIPE_CODE) - see the lines above"
fi

# ------------------------------------------------------------------ 5. real app
# the Linux answer to "PowerPoint opened it": LibreOffice headless converts the
# ended pptx. No LibreOffice = a printed skip, exactly like a machine without
# Office on Windows.
DECK=""
while IFS= read -r line; do
    case "$line" in *"deck_path"*) ;;
    esac
done < /dev/null
if [ -f "$REPO/results/status/pptmaster_local.json" ]; then
    DECK="$(python3 - "$REPO/results/status/pptmaster_local.json" <<'PY' 2>/dev/null || true
import json, sys
try:
    print(json.load(open(sys.argv[1], encoding='utf-8')).get('deck_path', ''))
except Exception:
    pass
PY
)"
fi
OPEN_RESULT="skip no deck to open"
if [ -n "$DECK" ] && [ -f "$DECK" ] && [ "$SKIP_OPEN" = "0" ]; then
    SOFFICE="$(command -v soffice || command -v libreoffice || true)"
    if [ -z "$SOFFICE" ]; then
        OPEN_RESULT="skip no LibreOffice on this machine"
    else
        TMPD="$(mktemp -d)"
        if "$SOFFICE" --headless --norestore --convert-to pdf --outdir "$TMPD" "$DECK" >/dev/null 2>&1 \
           && ls "$TMPD"/*.pdf >/dev/null 2>&1; then
            SLIDES="$(python3 - "$DECK" <<'PY' 2>/dev/null || echo 0
import sys, zipfile
try:
    z = zipfile.ZipFile(sys.argv[1])
    print(len([n for n in z.namelist() if n.startswith('ppt/slides/slide') and n.endswith('.xml')]))
except Exception:
    print(0)
PY
)"
            OPEN_RESULT="ok slides=$SLIDES"
        else
            OPEN_RESULT="fail LibreOffice could not convert the deck"
        fi
        rm -rf "$TMPD"
    fi
fi
say "open    : $OPEN_RESULT"
"$VPY" "$REPO/code/pptmaster_pipeline.py" --ppt-master "$INSTALL" --python "$VPY" \
    --repo "$REPO" --patch-com "$OPEN_RESULT" >/dev/null 2>&1 || true

# ------------------------------------------------------------------ 6. launcher
LAUNCHER="$INSTALL/make-deck.sh"
cat > "$LAUNCHER" <<EOF
#!/usr/bin/env bash
# rebuild the deck on this machine (written by code/pptmaster_local.sh)
set -e
"$REPO/code/pptmaster_local.sh" --repo "$REPO" --root "$ROOT" --skip-install
EOF
chmod +x "$LAUNCHER"
say "launcher: $LAUNCHER (bash it to rebuild the deck here)"

# ------------------------------------------------------------------ verdict
REC="$REPO/results/status/pptmaster_local.txt"
if [ -f "$REC" ]; then
    say "receipt : results/status/pptmaster_local.txt"
    sed 's/^/  /' "$REC"
fi
case "$OPEN_RESULT" in
    fail*) say "[FAIL] the deck could not be opened by a real application"; exit 1 ;;
esac
[ "$PIPE_CODE" -eq 0 ] || exit 1
say "local plane ok: deck built and verified with this machine's own venv"
exit 0
