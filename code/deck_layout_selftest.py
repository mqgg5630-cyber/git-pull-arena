#!/usr/bin/env python3
# deck_layout_selftest.py - prove the generated deck pages survive ANY numbers.
#
# The pages read their numbers out of the repo (results/status/check_r*.txt,
# success_criteria.json, deliverable/OFFICE_HASHES.json), and those numbers feed
# both the text and the geometry (KPI widths, bar heights). That makes the deck
# input-dependent: the same generator can produce a clean page here and a page
# the machine's checker rejects. It happened - round 28 on LAPTOP-R77M5D6M:
#
#   svg_quality_checker exit=1: total=12 passed=10 warnings=1 errors=1 blocking=2
#   <g id="kpi-2"> data-pptx-bounds overlaps <g id="bar-3"> ... by 92.0px x 49.0px
#
# (the local repo had check_r28_*.txt, the machine's did not, so its "last four
# rounds" were R24-R27 and one bar grew into the KPI row).
#
# So this test builds every page over a matrix of inputs - including the exact
# failing machine state and absurd extremes - and asserts what the machine's
# checker asserts: well-formed XML, no two ordinary direct-root module zones
# overlapping, and no text run that breaks its own declared width.
#
# Exit 0 = the layout is safe for any numbers, 1 = a page is fragile.
import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GENERATOR = os.path.join(HERE, 'make_deck_pptmaster.py')
EXPECT_PAGES = 12


def load_generator():
    spec = importlib.util.spec_from_file_location('deckgen', GENERATOR)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# The machine state that failed round 28 (logs up to R27 in E:\0github\git-sync\
# git-pull-arena-01a0aa00) - kept as a named regression case, not as a number
# anybody should trust for today's deck.
MACHINE_R28 = {'rounds': [[24, 34, True], [25, 33, False], [26, 54, False], [27, 42, False]],
               'criteria': 81, 'deliverables': 7}


def variants(base):
    """[name, facts] - base is the repo's own numbers."""
    return [
        ('repo-today', base),
        ('machine-r28', MACHINE_R28),
        ('slow-single-round', {'rounds': [[28, 1799, True]], 'criteria': 81,
                               'deliverables': 7}),
        ('extreme', {'rounds': [[9999, 3600, False], [1, 0, True], [77, 9999, True],
                                [3, 1, False]],
                     'criteria': 9999, 'deliverables': 9999}),
        ('tiny', {'rounds': [[1, 1, True], [2, 2, True], [3, 3, False], [4, 4, True]],
                  'criteria': 0, 'deliverables': 0}),
    ]


def check_page(name, svg, mod):
    problems = []
    try:
        mod.ET.fromstring(svg)
    except mod.ET.ParseError as exc:
        problems.append('%s: not well-formed XML (%s)' % (name, exc))
        return problems
    for msg in mod.bounds_overlaps(svg):
        problems.append('%s: %s' % (name, msg))
    bad = mod.xml_invalid_chars(svg)
    if bad:
        problems.append('%s: XML-illegal code point(s) %s' % (name, [hex(c) for c in bad]))
    return problems


def main():
    mod = load_generator()
    if len(mod.BUILDERS) != EXPECT_PAGES:
        print('[FAIL] generator builds %d page(s), expected %d'
              % (len(mod.BUILDERS), EXPECT_PAGES))
        return 1
    base = json.loads(json.dumps(mod.FACTS))
    failures = 0
    for label, facts in variants(base):
        mod.FACTS = facts
        problems = []
        for name, builder in mod.BUILDERS:
            page = builder()
            svg = page.svg()
            problems.extend(check_page(name, svg, mod))
            for w in page.warn:
                problems.append('%s: text does not fit its box: %s' % (name, w))
        if problems:
            failures += len(problems)
            print('[FAIL] %s: %d layout problem(s)' % (label, len(problems)))
            for item in problems[:6]:
                print('       ' + item)
        else:
            print('OK: %s - %d page(s), xml ok, no overlapping module zones'
                  % (label, len(mod.BUILDERS)))
    mod.FACTS = base
    if failures:
        print('[FAIL] %d layout problem(s) - the machine checker would reject this deck'
              % failures)
        return 1
    print('OK: every page survives every tested input (including the round-28 machine state)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
