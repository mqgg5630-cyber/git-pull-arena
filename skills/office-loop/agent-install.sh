#!/usr/bin/env bash
# agent-install.sh - install the office-loop skill into a repo.
#
#   bash skills/office-loop/agent-install.sh                 # install into this repo
#   bash skills/office-loop/agent-install.sh --target /path  # install into another repo
#   bash skills/office-loop/agent-install.sh --check         # verify an existing install
#
# The heavy lifting is tools/install.py (idempotent: copying files, inserting the
# two proven local_check.ps1 sections, merging the acceptance criteria, running
# the deck layout self-test and writing an install receipt). This wrapper only
# finds a working python and hands over.
#
# Exit 0 = installed/verified, 1 = problem (each one is named in the output).
set -u -o pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

PY=""
for cand in python3 python "py -3"; do
    if $cand -c 'import sys; sys.exit(0)' >/dev/null 2>&1; then PY="$cand"; break; fi
done
if [ -z "$PY" ]; then
    echo "[FAIL] no working python found (python3 / python / py -3)"
    echo "       the loop's files are python + PowerShell; install python 3.10+ first"
    exit 1
fi

exec $PY "$HERE/tools/install.py" "$@"
