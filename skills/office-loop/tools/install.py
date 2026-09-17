#!/usr/bin/env python3
# install.py - install the office-loop skill into a repo (the loop that this
# success case ran): the Office deliverable checks + the PPT Master local deck
# loop, taken byte-for-byte from the code the user's Windows machine validated.
#
#   python3 skills/office-loop/tools/install.py --target <repo> [--profile umami]
#   python3 skills/office-loop/tools/install.py --target <repo> --check
#
# What it does (all idempotent - re-running is safe):
#   1. copies the loop's code/ files from the source repo (the success case) into
#      the target repo, backing up anything it would replace as <file>.bak-<ts>
#   2. inserts the two proven local_check.ps1 sections (office deliverables,
#      ppt-master install + local deck generation) before the success-criteria
#      block, unless they are already there (sentinel / content detection)
#   3. merges this session's success_criteria fragment into
#      results/status/success_criteria.json (existing keys win)
#   4. runs code/deck_layout_selftest.py so the copy is proven before the machine
#      ever sees it, and writes results/status/office_loop_install.{json,txt}
#   5. prints what the machine will do next, and the paste block command for the
#      git-sync bridge when that skill is present
#
# Exit 0 = installed/verified, 1 = a problem the caller must fix (it never
# silently half-installs: every problem is named).
import argparse
import datetime
import json
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.dirname(HERE)
# the loop's code travels INSIDE the skill (payload/code/...) so another session
# only needs this folder - it does not have to clone the success-case repo.
# --source <repo> takes the files from a live repo instead (useful in the repo the
# payload came from, where code/ is the real thing).
PAYLOAD = os.path.join(SKILL, 'payload')
DEFAULT_SOURCE = PAYLOAD

# the loop's files, relative to a repo root. code/local_check.ps1 is NOT copied:
# the target keeps its own and gets the two sections inserted into it.
LOOP_FILES = [
    'code/deck_kit.py',
    'code/deck_layout_selftest.py',
    'code/make_deck_pptmaster.py',
    'code/make_deck_umami.py',
    'code/pptmaster_pipeline.py',
    'code/pptmaster_local.ps1',
    'code/render_deck_preview.py',
]

OFFICE_SENTINEL = 'office-loop: office deliverables section'
PPT_SENTINEL = 'office-loop: ppt-master section'
OFFICE_TEMPLATE = os.path.join(SKILL, 'templates', 'local_check_office.ps1')
PPT_TEMPLATE = os.path.join(SKILL, 'templates', 'local_check_pptmaster.ps1')

# the criteria block of a git-sync local_check.ps1 - the sections go right above
# it. Nothing is inserted when this anchor is missing: a wrong guess would break
# the machine's watcher, and a named failure is cheaper than a broken round.
ANCHOR = re.compile(r'^if \(Test-Path -LiteralPath \$critAbs\)')


def read(path, encoding='utf-8'):
    with open(path, encoding=encoding) as fh:
        return fh.read()


def write(path, text):
    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='') as fh:
        fh.write(text)


def stamp():
    return datetime.datetime.now().strftime('%Y%m%d-%H%M%S')


def copy_loop_files(source, target, force):
    """Copy the loop's code into the target; back up what would be replaced."""
    copied, kept, backed = [], [], []
    for rel in LOOP_FILES:
        src = os.path.join(source, rel)
        dst = os.path.join(target, rel)
        if not os.path.isfile(src):
            continue
        if os.path.isfile(dst) and read(src) == read(dst):
            kept.append(rel)
            continue
        if os.path.isfile(dst) and not force:
            # a repo that already ran the loop: keep its copy unless it asks,
            # but never leave the user wondering which one is active
            backed.append(rel + ' (kept - use --force to replace)')
            continue
        if os.path.isfile(dst):
            shutil.copyfile(dst, dst + '.bak-' + stamp())
        write(dst, read(src))
        copied.append(rel)
    return copied, kept, backed


def sections_installed(text):
    return OFFICE_SENTINEL in text or '$manRel = ' in text


def insert_sections(target):
    """Insert the two proven sections above the criteria block (idempotent)."""
    path = os.path.join(target, 'code', 'local_check.ps1')
    if not os.path.isfile(path):
        return None, ['code/local_check.ps1 is missing - install the git-sync skill first']
    text = read(path, encoding='utf-8')
    lines = text.split('\n')
    if OFFICE_SENTINEL in text and PPT_SENTINEL in text:
        return 'already installed (both sentinels present)', []
    if sections_installed(text) and '$pptScript = Join-Path' in text:
        return 'already installed (the sections are present without sentinels)', []
    at = None
    for i, line in enumerate(lines):
        if ANCHOR.match(line):
            at = i
            break
    if at is None:
        return None, ['code/local_check.ps1 has no "$critAbs" criteria block to insert before - '
                      'install this skill on top of the git-sync template, do not hand-edit it']
    while at > 0 and (lines[at - 1].startswith('#') or lines[at - 1].strip() == ''):
        at -= 1
    add = []
    if OFFICE_SENTINEL not in text:
        add.append(read(OFFICE_TEMPLATE).rstrip('\n'))
    if PPT_SENTINEL not in text:
        add.append(read(PPT_TEMPLATE).rstrip('\n'))
    block = '\n\n'.join(add) + '\n\n'
    out = '\n'.join(lines[:at]) + '\n' + block + '\n'.join(lines[at:])
    # a cheap structural sanity check: the sections are balanced on their own, so
    # the inserted file must be balanced too. PowerShell parses the whole file
    # before running anything, so an imbalance would kill every later round
    # instead of failing loudly - and the machine's own parse is the final gate.
    problems = []
    for open_ch, close_ch in (('{', '}'), ('(', ')')):
        if out.count(open_ch) != out.count(close_ch):
            problems.append('after inserting, %s has %d %r vs %d %r - restoring the backup'
                            % (path, out.count(open_ch), open_ch, out.count(close_ch), close_ch))
    if problems:
        shutil.copyfile(path, path + '.bak-' + stamp())
        write(path, text)
        return None, problems
    write(path, out)
    return 'inserted (%s section(s))' % len(add), []


def merge_criteria(target, profile):
    """Merge this session's acceptance assertions for the installed deck."""
    cfg_rel = 'code/pptmaster_deck.json'
    cfg_path = os.path.join(target, cfg_rel)
    deck_name, generator = '', ''
    if os.path.isfile(cfg_path):
        try:
            cfg = json.loads(read(cfg_path))
            deck_name = cfg.get('deck_name') or ''
            generator = cfg.get('generator') or ''
        except Exception as exc:
            return None, ['cannot read %s: %s' % (cfg_rel, exc)]
    crit_rel = 'results/status/success_criteria.json'
    crit_path = os.path.join(target, crit_rel)
    data = {}
    if os.path.isfile(crit_path):
        try:
            data = json.loads(read(crit_path))
        except Exception as exc:
            return None, ['cannot read %s: %s' % (crit_rel, exc)]
    for key in ('require_files', 'require_contains', 'require_regex', 'min_bytes', 'max_bytes'):
        data.setdefault(key, [] if key == 'require_files' else {})
    if isinstance(data['require_files'], dict):
        data['require_files'] = list(data['require_files'])
    added = []

    def add_file(rel):
        if rel not in data['require_files']:
            data['require_files'].append(rel)
            added.append('files: ' + rel)

    def add_contains(rel, needle):
        if data['require_contains'].get(rel) != needle:
            data['require_contains'][rel] = needle
            added.append('contains: %s <- %s' % (rel, needle))

    def add_min(rel, n):
        if data['min_bytes'].get(rel, 0) < n:
            data['min_bytes'][rel] = n
            added.append('min_bytes: %s >= %d' % (rel, n))

    for rel in LOOP_FILES + [cfg_rel, 'code/local_check.ps1']:
        add_file(rel)
    add_contains('code/local_check.ps1', 'pptmaster_local.ps1')
    add_contains('code/local_check.ps1', 'OFFICE_HASHES.json')
    add_contains(cfg_rel, 'make_deck' if not generator else os.path.basename(generator))
    if deck_name:
        data['require_regex'] = data['require_regex'] if isinstance(data['require_regex'], dict) else {}
        data['require_regex'][cfg_rel] = re.escape(deck_name)
        added.append('regex: %s matches %s' % (cfg_rel, deck_name))
        add_file('results/%s' % os.path.join('', deck_name)) if False else None
    add_contains('results/status/pptmaster_local.txt', 'deck_slides=')
    add_file('results/status/pptmaster_local.txt')
    for rel in ('code/pptmaster_local.ps1', 'code/pptmaster_pipeline.py', 'code/deck_kit.py',
                generator or 'code/make_deck_umami.py'):
        add_min(rel, 8000)
    write(crit_path, json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    return '%d assertion(s)' % len(added), []


def selftest(target):
    script = os.path.join(target, 'code', 'deck_layout_selftest.py')
    if not os.path.isfile(script):
        return None, 'not installed'
    for py in ('python3', 'python'):
        if shutil.which(py):
            r = subprocess.run([py, script], cwd=target, capture_output=True, text=True)
            tail = [ln for ln in (r.stdout or '').strip().split('\n') if ln.strip()]
            return r.returncode, (tail[-1] if tail else r.stderr.strip()[-120:])
    return None, 'no python on PATH'


def check_install(target):
    """Report whether a target already has a working loop installed."""
    problems = []
    for rel in LOOP_FILES + ['code/pptmaster_deck.json', 'code/local_check.ps1']:
        if not os.path.isfile(os.path.join(target, rel)):
            problems.append('missing: ' + rel)
    lc = os.path.join(target, 'code', 'local_check.ps1')
    if os.path.isfile(lc):
        text = read(lc)
        if 'pptmaster_local.ps1' not in text:
            problems.append('code/local_check.ps1 has no ppt-master section (run the installer)')
        if '$manRel = ' not in text and OFFICE_SENTINEL not in text:
            problems.append('code/local_check.ps1 has no office-deliverables section')
    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--target', default=os.getcwd(), help='repo to install into')
    ap.add_argument('--source', default=DEFAULT_SOURCE,
                    help='repo the loop files come from (default: the skill\'s own repo)')
    ap.add_argument('--profile', default='umami',
                    help='which deck config to install when the target has none')
    ap.add_argument('--force', action='store_true',
                    help='replace loop files the target already has (they are backed up)')
    ap.add_argument('--check', action='store_true', help='verify only, change nothing')
    args = ap.parse_args()
    target = os.path.abspath(args.target)
    source = os.path.abspath(args.source)

    print('== office-loop install')
    print('   skill  : %s' % SKILL)
    print('   source : %s' % source)
    print('   target : %s' % target)
    if not os.path.isdir(os.path.join(target, '.git')):
        print('[WARN] %s is not a git checkout - the loop expects a repo the watcher polls' % target)

    if args.check:
        problems = check_install(target)
        for p in problems:
            print('   FAIL ' + p)
        if not problems:
            print('   OK   the loop is installed here')
            return 0
        return 1

    missing_src = [rel for rel in LOOP_FILES if not os.path.isfile(os.path.join(source, rel))]
    if len(missing_src) == len(LOOP_FILES):
        print('[FAIL] source %s has none of the loop files - pass --source <repo that has them>'
              % source)
        return 1
    if missing_src:
        print('   WARN  source is missing %d file(s): %s' % (len(missing_src), missing_src))

    copied, kept, backed = copy_loop_files(source, target, args.force)

    # the deck config: installed only when the target has none - it is the file a
    # session edits to switch the deck's subject, so never overwrite somebody's
    cfg_src = os.path.join(SKILL, 'templates', 'pptmaster_deck.json')
    cfg_rel = 'code/pptmaster_deck.json'
    if not os.path.isfile(os.path.join(target, cfg_rel)):
        if os.path.isfile(cfg_src):
            write(os.path.join(target, cfg_rel), read(cfg_src))
            copied.append(cfg_rel)
    else:
        kept.append(cfg_rel + ' (already present - the target owns its deck subject)')
    for rel in copied:
        print('   copy  ' + rel)
    for rel in kept:
        print('   same  ' + rel)
    for rel in backed:
        print('   WARN  ' + rel)

    note, problems = insert_sections(target)
    if note:
        print('   local_check.ps1 sections: ' + note)
    for p in problems:
        print('   FAIL ' + p)

    note, problems2 = merge_criteria(target, args.profile)
    if note:
        print('   criteria: ' + note)
    problems += problems2

    code, note = selftest(target)
    if code is None:
        print('   WARN  deck layout self-test: ' + note)
    elif code == 0:
        print('   OK    deck layout self-test: ' + note)
    else:
        print('   FAIL  deck layout self-test: ' + note)
        problems.append('deck layout self-test failed')

    receipt = {
        'schema': 'office-loop.install.v1',
        'at': datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'target': target,
        'source': source,
        'copied': copied,
        'unchanged': kept,
        'kept_because_present': backed,
        'local_check': note,
        'selftest_exit': code,
        'problems': problems,
        'next': [
            'commit + push; the watcher pulls and runs code/local_check.ps1 on the machine',
            'the machine clones/creates <repo parent>\\ppt-master, its venv and deps by itself',
            'each round writes results/status/pptmaster_local.{json,txt} and pushes it back',
        ],
    }
    rel_dir = os.path.join(target, 'results', 'status')
    write(os.path.join(rel_dir, 'office_loop_install.json'),
          json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
    write(os.path.join(rel_dir, 'office_loop_install.txt'),
          'office-loop-%s files=%d problems=%d selftest=%s\n'
          % ('ok' if not problems else 'FAIL', len(copied), len(problems), code))
    print('   receipt: results/status/office_loop_install.txt')

    bridge = os.path.join(target, 'skills', 'git-sync', 'scripts', 'agent-handoff.sh')
    if os.path.isfile(bridge):
        print('   machine bridge: bash skills/git-sync/scripts/agent-handoff.sh   '
              '(prints the paste block for the Windows machine)')
    else:
        print('   WARN  the git-sync skill is not installed here - install it first, then re-run')
    if problems:
        print('[FAIL] %d problem(s): the machine round would fail' % len(problems))
        return 1
    print('[OK] installed: push, then the machine produces and verifies the deck by itself')
    return 0


if __name__ == '__main__':
    sys.exit(main())
