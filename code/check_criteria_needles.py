#!/usr/bin/env python3
# check_criteria_needles.py - every require_contains / require_regex assertion in
# results/status/success_criteria.json must actually be satisfiable in THIS
# worktree. Round 33 on the machine failed on exactly this: the criteria asked
# for the literal "round 28" in skills/office-loop/CASE_STUDY.md, the file said
# "round-28", and the whole round was verdict=failed after a green 4a/4b/4c.
# A one-line gate here catches that in the sandbox instead of on the user's PC.
#
# Files that do not exist yet are reported as SKIP: they may legitimately be
# produced later by the machine (receipts, evidence, generated decks). Missing
# files are still covered by require_files / min_bytes.
#
# Usage: python3 code/check_criteria_needles.py [repo_root]
# Exit 0 = every needle that can be checked here is present, 1 = a needle is
# missing (that round would fail on the machine).
import json
import os
import re
import sys

CRITERIA = 'results/status/success_criteria.json'


def main():
    repo = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.getcwd()
    path = os.path.join(repo, CRITERIA)
    if not os.path.isfile(path):
        print('SKIP: %s not present' % CRITERIA)
        return 0
    with open(path, encoding='utf-8') as fh:
        crit = json.load(fh)

    problems, checked, skipped = [], 0, 0
    for rel, needle in (crit.get('require_contains') or {}).items():
        full = os.path.join(repo, rel.replace('/', os.sep))
        if not os.path.isfile(full):
            skipped += 1
            continue
        try:
            with open(full, encoding='utf-8', errors='replace') as fh:
                body = fh.read()
        except Exception as exc:
            problems.append('%s: cannot read (%s)' % (rel, exc))
            continue
        checked += 1
        if str(needle) not in body:
            problems.append('require_contains %s <- %r : NOT in the file '
                            '(the machine round would fail on this)' % (rel, needle))
    for rel, pattern in (crit.get('require_regex') or {}).items():
        full = os.path.join(repo, rel.replace('/', os.sep))
        if not os.path.isfile(full):
            skipped += 1
            continue
        try:
            with open(full, encoding='utf-8', errors='replace') as fh:
                body = fh.read()
        except Exception as exc:
            problems.append('%s: cannot read (%s)' % (rel, exc))
            continue
        checked += 1
        try:
            if not re.search(pattern, body):
                problems.append('require_regex %s <- %r : no match '
                                '(the machine round would fail on this)' % (rel, pattern))
        except re.error as exc:
            problems.append('require_regex %s <- %r : bad pattern (%s)' % (rel, pattern, exc))

    for item in problems:
        print('[FAIL] ' + item)
    if problems:
        print('[FAIL] %d unsatisfiable assertion(s)' % len(problems))
        return 1
    print('OK: criteria needles all satisfiable here (%d checked, %d not present yet)'
          % (checked, skipped))
    return 0


if __name__ == '__main__':
    sys.exit(main())
