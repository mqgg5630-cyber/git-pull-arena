#!/usr/bin/env python3
# gates.py - run the repo's gate list (code/gates.json) before a push.
#
# A gate is one cheap question with a yes/no answer, asked while the code is
# still in the sandbox: "is every .ps1 ASCII?", "does every deck survive the
# machine's own numbers?", "does every acceptance needle exist?". The list lives
# in code/gates.json so a repo ADDS a gate without editing a script - the same
# shape pre-commit uses for hooks, minus the dependency:
#
#   {"id": "ps1-ascii", "run": ["{bash}", "code/check_ps1_ascii.sh"],
#    "severity": "block", "plane": "sandbox", "why": "..."}
#
# severity: block (exit 1 stops the push) / warn (printed, never blocks).
# plane:    sandbox (default) / local (a gate only the machine can run - listed
#           here so the plan is complete, skipped by this runner).
#
# check_all.sh calls this when it is present, so the gate list keeps working both
# as "bash code/check_all.sh" (the one command a human remembers) and as a
# data-driven list a repo can extend.
#
# Usage: python3 code/gates.py [--list] [--only id,id] [--json]
# Exit 0 = every blocking gate passed, 1 = at least one failed.
import argparse
import datetime
import json
import os
import shlex
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
GATES = os.path.join(HERE, 'gates.json')
REPORT = os.path.join(REPO, 'results', 'status', 'gates.json')


def this_os():
    if os.name == 'nt' or sys.platform.startswith('win'):
        return 'windows'
    if sys.platform == 'darwin':
        return 'macos'
    return 'linux'


def shutil_which(name):
    for d in os.environ.get('PATH', '').split(os.pathsep):
        cand = os.path.join(d, name)
        if os.path.isfile(cand) and os.access(cand, os.X_OK):
            return cand
    return ''


def table():
    bash = shutil_which('bash') or 'bash'
    python = sys.executable
    return {
        'python': python,
        'python3': python,
        'bash': bash,
        'os': this_os(),
        'repo': REPO,
    }


def expand(token, values):
    for key, value in values.items():
        token = token.replace('{%s}' % key, value)
    return token


def load():
    if not os.path.isfile(GATES):
        return None, 'no %s in this repo' % os.path.relpath(GATES, REPO)
    try:
        with open(GATES, encoding='utf-8') as fh:
            data = json.load(fh)
    except Exception as exc:
        return None, 'cannot read %s: %s' % (GATES, exc)
    gates = data.get('gates') if isinstance(data, dict) else data
    if not isinstance(gates, list):
        return None, '%s must hold a list (or {"gates": [...]})' % GATES
    return gates, ''


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--list', action='store_true')
    ap.add_argument('--only', default='')
    ap.add_argument('--json', action='store_true')
    args = ap.parse_args()

    gates, problem = load()
    if gates is None:
        print('SKIP: ' + problem)
        return 0
    only = [g for g in args.only.split(',') if g]
    values = table()
    results, failed = [], 0

    for gate in gates:
        gid = gate.get('id') or '?'
        severity = (gate.get('severity') or 'block').lower()
        plane = (gate.get('plane') or 'sandbox').lower()
        cmd = [expand(str(t), values) for t in (gate.get('run') or [])]
        entry = {'id': gid, 'severity': severity, 'plane': plane,
                 'run': ' '.join(cmd), 'why': gate.get('why') or ''}
        if args.list:
            print('%-22s %-6s %-8s %s' % (gid, severity, plane, entry['run']))
            continue
        if only and gid not in only:
            continue
        if plane != 'sandbox':
            entry.update({'status': 'local-only', 'detail': 'runs on the machine'})
            results.append(entry)
            print('SKIP  %-20s (local-only: %s)' % (gid, entry['why'] or 'machine gate'))
            continue
        if not cmd:
            entry.update({'status': 'skipped', 'detail': 'no run command'})
            results.append(entry)
            print('SKIP  %-20s (no run command)' % gid)
            continue
        proc = subprocess.run(cmd, cwd=REPO, capture_output=True)
        out = (proc.stdout or b'').decode('utf-8', 'replace')
        err = (proc.stderr or b'').decode('utf-8', 'replace')
        ok = proc.returncode == 0
        entry.update({'status': 'ok' if ok else 'failed', 'exit': proc.returncode,
                      'detail': (out + err).strip().split('\n')[-1][:200] if (out + err).strip() else ''})
        results.append(entry)
        print('%s %-20s %s' % ('OK   ' if ok else 'FAIL ', gid, entry['detail']))
        if not ok:
            for line in [ln for ln in (out + err).strip().split('\n') if ln.strip()][-6:]:
                print('      ' + line[:180])
            if severity == 'block':
                failed += 1

    if args.list:
        return 0
    report = {'schema': 'local-loop.gates.v1',
              'at': datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
              'os': values['os'], 'gates': results, 'blocking_failed': failed}
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, 'w', encoding='utf-8') as fh:
        json.dump(report, fh, ensure_ascii=False, indent=2)
        fh.write('\n')
    if args.json:
        print(json.dumps(report, ensure_ascii=False))
    print('== gates: %d gate(s), %d blocking failure(s)' % (len(results), failed))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
