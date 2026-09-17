#!/usr/bin/env python3
# check_payload.py - the skill carries the loop's code inside itself
# (payload/code/...), so another session can install without cloning this repo.
# That copy can drift from the repo's code/ - and a skill that installs an old
# loop is worse than no skill. This gate fails the moment they differ, and runs
# from code/check_all.sh before every push.
#
# Usage: python3 skills/office-loop/tools/check_payload.py [repo_root]
# Exit 0 = payload == repo code, 1 = drift (or a missing file).
import filecmp
import os
import sys

FILES = [
    'code/deck_kit.py',
    'code/deck_layout_selftest.py',
    'code/make_deck_pptmaster.py',
    'code/make_deck_umami.py',
    'code/pptmaster_pipeline.py',
    'code/pptmaster_local.ps1',
    'code/render_deck_preview.py',
]


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    skill = os.path.dirname(here)
    repo = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 \
        else os.path.dirname(os.path.dirname(skill))
    payload = os.path.join(skill, 'payload')
    problems = []
    for rel in FILES:
        src = os.path.join(repo, rel)
        dst = os.path.join(payload, rel)
        if not os.path.isfile(src):
            problems.append('missing in the repo: ' + rel)
            continue
        if not os.path.isfile(dst):
            problems.append('missing from the skill payload: ' + rel)
            continue
        if not filecmp.cmp(src, dst, shallow=False):
            problems.append('payload differs: %s (copy it again: '
                            'cp %s skills/office-loop/payload/%s)' % (rel, rel, rel))
    for item in problems:
        print('[FAIL] ' + item)
    if problems:
        print('[FAIL] %d payload drift(s) - the skill would install an old loop' % len(problems))
        return 1
    print('OK: office-loop payload matches the repo code (%d file(s))' % len(FILES))
    return 0


if __name__ == '__main__':
    sys.exit(main())
