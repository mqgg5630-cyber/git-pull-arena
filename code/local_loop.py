#!/usr/bin/env python3
# local_loop.py - run a repo's build/verify task as a RECIPE, on two planes.
#
# The task is not part of this program. A recipe (code/recipes/<id>.json) says
# what the task is, which steps belong to which plane, what the finished work
# must look like, and what the machine has to prove afterwards:
#
#   plan      what would run where, and why (writes results/status/loop_plan.json)
#   sandbox   run the sandbox-plane steps here (authoring, builds, gates)
#   local     run the local-plane steps ON THE MACHINE (install + verify)
#   gates     run the repo's gate list (code/gates.json)
#
# Two planes, because the honest answer to "does it work" differs per task:
#   * sandbox  - fast, no GUI/licence/COM, runs in the agent's container. Good
#                for authoring files, compiling, unit tests, static checks.
#   * local    - the user's real machine (Windows or Linux): the only place that
#                can judge installs, COM/Office, GUI tools, licence-gated apps
#                and anything the repo is supposed to reach from there.
# A recipe declares a step's plane; this runner never guesses. `plan` prints the
# decision so a human can see it before a round is spent.
#
# Receipts: `local` writes ONE normalized receipt for any task and any OS -
#   results/status/local_loop_receipt.json   (machine, os, recipe, per-check ok)
#   results/status/local_loop_receipt.txt    (one line, for success_criteria)
# so a repo's acceptance criteria do not have to learn each task's private format.
#
# No third-party imports on purpose: this runs on a fresh machine with only the
# python the machine already has.
#
# Usage:
#   python3 code/local_loop.py plan [--recipe office-deck]
#   python3 code/local_loop.py sandbox [--recipe office-deck] [--apply]
#   python3 code/local_loop.py local   [--recipe office-deck] [--os linux|windows]
#   python3 code/local_loop.py gates
import argparse
import datetime
import glob
import json
import os
import platform
import re
import shlex
import subprocess
import sys

RECIPE_DIR = os.path.join('code', 'recipes')
PLAN = os.path.join('results', 'status', 'loop_plan.json')
RECEIPT_JSON = os.path.join('results', 'status', 'local_loop_receipt.json')
RECEIPT_TXT = os.path.join('results', 'status', 'local_loop_receipt.txt')
SCHEMA = 'local-loop.recipe.v1'


def log(msg):
    print('LOOP: %s' % msg)
    sys.stdout.flush()


def read_json(path, default=None):
    try:
        with open(path, encoding='utf-8') as fh:
            return json.load(fh)
    except Exception:
        return default


def write_json(path, data):
    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write('\n')


def write_text(path, text):
    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='') as fh:
        fh.write(text)


def repo_root():
    return os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))


def this_os():
    if os.name == 'nt' or sys.platform.startswith('win'):
        return 'windows'
    if sys.platform == 'darwin':
        return 'macos'
    return 'linux'


def venv_python(install_dir, os_name):
    if not install_dir:
        return sys.executable
    if os_name == 'windows':
        return os.path.join(install_dir, '.venv', 'Scripts', 'python.exe')
    return os.path.join(install_dir, '.venv', 'bin', 'python')


def placeholders(repo, recipe, os_name):
    install = (recipe.get('install_dir') or '').replace('{repo_parent}',
                                                        os.path.dirname(repo))
    bash = ''
    for d in os.environ.get('PATH', '').split(os.pathsep):
        cand = os.path.join(d, 'bash')
        if os.path.isfile(cand) and os.access(cand, os.X_OK):
            bash = cand
            break
    return {
        'host': platform.node().split('.')[0] or 'localhost',
        'bash': bash or 'bash',
        'python': sys.executable,
        'repo': repo,
        'repo_parent': os.path.dirname(repo),
        'venv_python': venv_python(install, os_name),
        'install': install,
        'os': os_name,
    }


def expand(token, table):
    for key, value in table.items():
        token = token.replace('{%s}' % key, value)
    return token


def load_recipe(repo, name):
    path = os.path.join(repo, RECIPE_DIR, (name or '') + '.json')
    if not os.path.isfile(path):
        choices = sorted(os.path.splitext(os.path.basename(p))[0]
                         for p in glob.glob(os.path.join(repo, RECIPE_DIR, '*.json')))
        return None, ('no recipe %r in %s (available: %s)'
                      % (name, RECIPE_DIR, ', '.join(choices) or 'none'))
    recipe = read_json(path)
    if not recipe:
        return None, 'recipe %s is not valid JSON' % path
    problems = validate(recipe, path)
    return recipe, problems


def validate(recipe, path):
    """Structural checks - a broken recipe must fail here, not mid-round."""
    problems = []
    if recipe.get('schema') != SCHEMA:
        problems.append('%s: schema must be %r' % (path, SCHEMA))
    if not recipe.get('id'):
        problems.append('%s: id is required' % path)
    sandbox = recipe.get('sandbox') or {}
    for i, step in enumerate(sandbox.get('steps') or []):
        if not step.get('id'):
            problems.append('%s: sandbox.steps[%d] needs an id' % (path, i))
        if not step.get('run'):
            problems.append('%s: sandbox.steps[%d] needs run' % (path, i))
    local = recipe.get('local') or {}
    if not local:
        problems.append('%s: local is required (even a sandbox-only task needs '
                        'an explicit local: {"skip": "reason"})' % path)
    receipt = (local.get('receipt') or {}) if isinstance(local, dict) else {}
    if local and not receipt.get('file') and not local.get('skip'):
        problems.append('%s: local.receipt.file is required (or local.skip with a reason)' % path)
    return problems


def which_recipe(repo, name):
    """--recipe wins, then code/loop.json (the repo's default), then a single recipe."""
    if name:
        return name
    cfg = read_json(os.path.join(repo, 'code', 'loop.json')) or {}
    if cfg.get('recipe'):
        return cfg['recipe']
    found = sorted(os.path.splitext(os.path.basename(p))[0]
                   for p in glob.glob(os.path.join(repo, RECIPE_DIR, '*.json')))
    return found[0] if len(found) == 1 else None


# ---------------------------------------------------------------- plan
def cmd_plan(args):
    repo = repo_root()
    name = which_recipe(repo, args.recipe)
    recipe, problems = load_recipe(repo, name) if name else (None, ['no recipe selected'])
    if problems:
        for p in problems:
            log('[FAIL] ' + str(p))
        return 1
    os_name = args.os or this_os()
    table = placeholders(repo, recipe, os_name)
    rows = []
    for step in (recipe.get('sandbox') or {}).get('steps') or []:
        rows.append({'plane': 'sandbox', 'id': step['id'],
                     'run': ' '.join(expand(str(t), table) for t in step['run']),
                     'produces': step.get('produces') or [],
                     'why': step.get('why') or ''})
    local = recipe.get('local') or {}
    os_steps = ((local.get('steps') or {}).get(os_name) or []) if isinstance(local, dict) else []
    for step in os_steps:
        rows.append({'plane': 'local', 'id': step['id'],
                     'run': step.get('run_powershell') or
                            ' '.join(expand(str(t), table) for t in (step.get('run') or [])),
                     'produces': step.get('produces') or [],
                     'why': step.get('why') or ''})
    receipt = local.get('receipt') or {}
    plan = {
        'schema': 'local-loop.plan.v1',
        'at': datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'repo': repo,
        'recipe': recipe.get('id'),
        'title': recipe.get('title'),
        'target_os': os_name,
        'needs': recipe.get('needs') or [],
        'steps': rows,
        'receipt': {'file': receipt.get('file'), 'keys': receipt.get('keys') or {},
                    'evidence': recipe.get('evidence') or []},
        'skip': local.get('skip') or '',
        'note': recipe.get('note') or '',
    }
    write_json(os.path.join(repo, PLAN), plan)
    log('recipe  : %s - %s' % (plan['recipe'], plan['title']))
    log('target  : %s' % os_name)
    log('needs   : %s' % (', '.join(plan['needs']) or '(nothing local)'))
    for row in rows:
        log('  %-7s %-18s %s' % (row['plane'], row['id'], row['run']))
        for produced in row['produces']:
            log('          -> %s' % produced)
    if plan['skip']:
        log('local skipped: %s' % plan['skip'])
    if plan['receipt']['file']:
        log('receipt : %s' % plan['receipt']['file'])
        for key, want in (plan['receipt']['keys'] or {}).items():
            log('          %s = %s' % (key, want))
    log('plan    : %s' % PLAN)
    return 0


# ---------------------------------------------------------------- sandbox
def run_step(repo, step, table, timeout_default=1800):
    cmd = [expand(str(t), table) for t in step['run']]
    timeout = int(step.get('timeout') or timeout_default)
    log('run %s: %s' % (step['id'], ' '.join(shlex.quote(c) for c in cmd)))
    try:
        proc = subprocess.run(cmd, cwd=repo, capture_output=True, timeout=timeout)
    except FileNotFoundError as exc:
        return 127, '[missing executable] %s' % exc, step
    except subprocess.TimeoutExpired:
        return 124, 'timeout after %ds' % timeout, step
    out = (proc.stdout or b'').decode('utf-8', 'replace')
    err = (proc.stderr or b'').decode('utf-8', 'replace')
    for line in (out.strip().split('\n') if out.strip() else []):
        log('  | ' + line[:220])
    for line in (err.strip().split('\n') if err.strip() else []):
        log('  ! ' + line[:220])
    return proc.returncode, out + err, step


def cmd_sandbox(args):
    repo = repo_root()
    name = which_recipe(repo, args.recipe)
    recipe, problems = load_recipe(repo, name) if name else (None, ['no recipe selected'])
    if problems:
        for p in problems:
            log('[FAIL] ' + str(p))
        return 1
    table = placeholders(repo, recipe, args.os or this_os())
    steps = (recipe.get('sandbox') or {}).get('steps') or []
    if not steps:
        log('recipe %s declares no sandbox step - nothing to do here' % recipe.get('id'))
        return 0
    failures = []
    for step in steps:
        if not args.apply:
            log('dry-run %s: %s' % (step['id'], ' '.join(str(t) for t in step['run'])))
            continue
        code, out, _ = run_step(repo, step, table)
        if code != 0:
            failures.append('%s (exit %d)' % (step['id'], code))
            continue
        for pattern in step.get('produces') or []:
            if not glob.glob(os.path.join(repo, expand(str(pattern), table))):
                failures.append('%s produced nothing matching %s' % (step['id'], pattern))
            else:
                log('produced %s' % pattern)
    if failures:
        log('[FAIL] sandbox plane: %s' % '; '.join(failures))
        return 1
    log('%s sandbox plane ok' % ('executed' if args.apply else 'planned (add --apply)'))
    return 0


# ---------------------------------------------------------------- local
def local_commands(step, table):
    """A local step is either a native command list or a PowerShell script."""
    if step.get('run_powershell'):
        script = expand(step['run_powershell'], table)
        args = [expand(str(a), table) for a in (step.get('args') or [])]
        return ['powershell', '-NoProfile', '-NonInteractive',
                '-ExecutionPolicy', 'Bypass', '-File', script] + args
    return [expand(str(t), table) for t in (step.get('run') or [])]


def read_receipt(repo, receipt):
    """Parse the task's own receipt into {key: value} (text `key=value` lines or JSON)."""
    path = os.path.join(repo, receipt.get('file') or '')
    if not receipt.get('file') or not os.path.isfile(path):
        return None, 'receipt %s not found' % (receipt.get('file') or '(none)')
    values = {}
    text = open(path, encoding='utf-8', errors='replace').read()
    try:
        data = json.loads(text)
        if isinstance(data, dict):
            for key, value in data.items():
                values[str(key)] = value
    except Exception:
        for line in text.splitlines():
            for match in re.finditer(r'([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)', line):
                values[match.group(1)] = match.group(2)
    return values, ''


def cmd_local(args):
    repo = repo_root()
    name = which_recipe(repo, args.recipe)
    recipe, problems = load_recipe(repo, name) if name else (None, ['no recipe selected'])
    if problems:
        for p in problems:
            log('[FAIL] ' + str(p))
        return 1
    os_name = args.os or this_os()
    table = placeholders(repo, recipe, os_name)
    local = recipe.get('local') or {}
    receipt = dict(local.get('receipt') or {})
    receipt['file'] = expand(str(receipt.get('file') or ''), table)

    if local.get('skip'):
        values = {'skip': local['skip']}
        ok = True
    else:
        values, ok = {}, True
        steps = (local.get('steps') or {}).get(os_name) or []
        if not steps:
            log('[WARN] recipe %s declares no local step for %s' % (recipe.get('id'), os_name))
        for step in steps:
            cmd = local_commands(step, table)
            if step.get('skip_if_missing') and not os.path.exists(
                    expand(str(step['skip_if_missing']), table)):
                log('skip %s: %s is not there' % (step['id'], step['skip_if_missing']))
                continue
            if args.dry_run:
                log('would run %s: %s' % (step['id'], ' '.join(cmd)))
                continue
            log('run %s: %s' % (step['id'], ' '.join(shlex.quote(c) for c in cmd)))
            try:
                proc = subprocess.run(cmd, cwd=repo, timeout=int(step.get('timeout') or 1800))
                code = proc.returncode
            except FileNotFoundError as exc:
                code = 127
                log('  ! %s' % exc)
            if code != 0:
                ok = False
                log('  -> exit %d' % code)
        got, err = read_receipt(repo, receipt)
        if got is None:
            ok = False
            values = {'receipt': err}
        else:
            values = got

    checks = {}
    for key, want in (receipt.get('keys') or {}).items():
        have = values.get(key, values.get(key.replace('_', '-'), None))
        good = str(have) == str(want)
        checks[key] = {'want': want, 'got': have, 'ok': good}
        if not good:
            ok = False
    # the task's own receipt says whether a real application opened the artifact
    # (PowerPoint on Windows, LibreOffice on Linux) - carry it into the unified
    # receipt so 4c can judge it without knowing the task's format
    opened = str(values.get('powerpoint') or values.get('opened') or '')
    summary = {
        'schema': 'local-loop.receipt.v1',
        'at': datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'recipe': recipe.get('id'),
        'os': os_name,
        'host': platform.node(),
        'ok': bool(ok),
        'checks': checks,
        'values': {k: v for k, v in values.items() if isinstance(v, (str, int, float, bool))},
        'materials': {},
    }
    for rel in recipe.get('evidence') or []:
        hits = sorted(glob.glob(os.path.join(repo, expand(str(rel), table))))
        summary['materials'][str(rel)] = [os.path.relpath(h, repo) for h in hits[:20]]
    summary['opened'] = opened
    write_json(os.path.join(repo, RECEIPT_JSON), summary)
    line = '%s recipe=%s os=%s host=%s ok=%s %s opened=%s' % (
        'loop-ok' if ok else 'loop-FAIL', recipe.get('id'), os_name, summary['host'],
        'true' if ok else 'false',
        ' '.join('%s=%s(/%s)' % (k, v['got'], v['want']) for k, v in checks.items()),
        opened or 'unknown')
    write_text(os.path.join(repo, RECEIPT_TXT), line + '\n')
    log('receipt : %s' % RECEIPT_TXT)
    log(line)
    return 0 if ok else 1


# ---------------------------------------------------------------- gates
def cmd_gates(args):
    here = os.path.dirname(os.path.abspath(__file__))
    gates = os.path.join(here, 'gates.py')
    if not os.path.isfile(gates):
        log('no code/gates.py in this repo - nothing to run')
        return 0
    proc = subprocess.run([sys.executable, gates] + list(args.rest), cwd=repo_root())
    return proc.returncode


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd')
    for name in ('plan', 'sandbox', 'local'):
        p = sub.add_parser(name)
        p.add_argument('--recipe', default=None)
        p.add_argument('--os', default=None, choices=['windows', 'linux', 'macos'])
    sub.choices['sandbox'].add_argument('--apply', action='store_true',
                                        help='actually run the steps (default: dry run)')
    sub.choices['local'].add_argument('--dry-run', action='store_true')
    g = sub.add_parser('gates')
    g.add_argument('rest', nargs='*')
    args = ap.parse_args()
    if args.cmd == 'plan':
        return cmd_plan(args)
    if args.cmd == 'sandbox':
        return cmd_sandbox(args)
    if args.cmd == 'local':
        return cmd_local(args)
    if args.cmd == 'gates':
        return cmd_gates(args)
    ap.print_help()
    return 1


if __name__ == '__main__':
    sys.exit(main())
