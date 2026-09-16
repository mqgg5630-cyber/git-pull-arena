#!/usr/bin/env python3
# pptmaster_pipeline.py - run PPT Master end to end *in the environment this
# script is started in*, then verify the deck it produced and write a receipt.
#
# Why a dedicated script: the same verification has to run on the user's real
# Windows machine (called by code/local_check.ps1 from the scheduled watcher)
# and in the agent sandbox. Keeping the logic here - stdlib only, no imports
# beyond what the pipeline itself needs - means both sides execute the same
# code, and only the few genuinely platform-specific bits (git clone, venv,
# PowerPoint COM open) stay in PowerShell.
#
# What it proves for one round:
#   * the ppt-master toolchain in <install-dir> is complete (guard + deps)
#   * a 12-page deck can be authored and compiled HERE, from this repo's
#     generator, into a native DrawingML pptx
#   * the produced pptx is structurally sound (zip, parts, XML, rels,
#     content types, markers, slide count) and passes ppt-master's own
#     delivery check
#
# Modes:
#   (default)                    run the pipeline, write the receipt
#   --verify-deck PATH           only verify an existing pptx (JSON to stdout)
#   --patch-com "ok slides=12"   fold a PowerPoint COM result into the receipt
#
# Usage (sandbox):
#   python3 code/pptmaster_pipeline.py \
#       --ppt-master /tmp/ppt-master --python /tmp/venv-ppt/bin/python \
#       --environment sandbox --host sandbox --repo .
# Usage (Windows, called by pptmaster_local.ps1):
#   <venv>\python.exe code\pptmaster_pipeline.py --ppt-master <dir> --python <exe> ^
#       --environment windows --host LAPTOP-R77M5D6M --patch-com "ok slides=12"

import argparse
import datetime
import json
import os
import glob
import re
import shutil
import subprocess
import sys
import zipfile

EXPECT_SLIDES = 12
DECK_MARKERS = ['2.8.1', 'ppt-master', 'local_check.ps1', '自循环']
CORE_DEPS = ['yaml', 'pptx', 'xlsxwriter', 'pathops', 'uharfbuzz', 'PIL', 'numpy']
SCHEMA = 'git-pull-arena.pptmaster-local.v1'


def log(msg):
    print('PPTMASTER: %s' % msg)
    sys.stdout.flush()


def run(cmd, cwd=None, timeout=1800, env=None):
    """Run a command, return (exit code, combined output)."""
    e = dict(os.environ)
    e['PYTHONIOENCODING'] = 'utf-8'
    e['PYTHONUTF8'] = '1'
    if env:
        e.update(env)
    try:
        p = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           timeout=timeout, env=e)
        return p.returncode, p.stdout.decode('utf-8', 'replace')
    except subprocess.TimeoutExpired:
        return 124, 'TIMEOUT after %ss: %s' % (timeout, ' '.join(cmd))
    except OSError as exc:
        return 127, 'cannot run %s: %s' % (cmd[0], exc)


def tail(text, lines=6):
    parts = [ln for ln in text.strip().splitlines() if ln.strip()]
    return ' | '.join(parts[-lines:])[:900]


# ------------------------------------------------------------------ probing
def pm_version(pm_dir):
    skill = os.path.join(pm_dir, 'skills', 'ppt-master', 'SKILL.md')
    if os.path.isfile(skill):
        with open(skill, encoding='utf-8', errors='replace') as fh:
            m = re.search(r'^\s*version:\s*"?([0-9][^"\s]*)"?', fh.read(4000), re.M)
            if m:
                return m.group(1)
    mk = os.path.join(pm_dir, '.claude-plugin', 'marketplace.json')
    if os.path.isfile(mk):
        try:
            with open(mk, encoding='utf-8') as fh:
                return str(json.load(fh).get('metadata', {}).get('version', 'unknown'))
        except Exception:
            pass
    return 'unknown'


def probe_deps(python):
    code = ('import importlib, json\n'
            'mods = ["yaml", "pptx", "xlsxwriter", "pathops", "uharfbuzz", "PIL", "numpy"]\n'
            'out = {}\n'
            'for m in mods:\n'
            '    try:\n'
            '        mod = importlib.import_module(m)\n'
            '        out[m] = str(getattr(mod, "__version__", "?"))\n'
            '    except Exception:\n'
            '        out[m] = None\n'
            'print(json.dumps(out))\n')
    done = subprocess.run([python, '-c', code], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        return json.loads(done.stdout.decode('utf-8', 'replace').strip().splitlines()[-1])
    except Exception:
        return {name: None for name in CORE_DEPS}


def python_version(python):
    code, out = run([python, '-c', 'import sys; print("%d.%d.%d" % sys.version_info[:3])'],
                    timeout=120)
    return out.strip() if code == 0 else 'unknown'


# ------------------------------------------------------------ deck checking
def verify_deck(path, expect_slides, markers):
    """Structural verification of a produced pptx. Stdlib only, so the exact
    same code runs on Windows PowerShell's python and in the sandbox."""
    res = {'ok': False, 'slides': 0, 'parts': 0, 'xml_parts': 0, 'markers_ok': False,
           'zip_ok': False, 'xml_ok': False, 'rels_ok': False, 'content_types_ok': False,
           'bytes': 0, 'problems': [], 'missing_markers': []}
    if not os.path.isfile(path):
        res['problems'].append('missing: %s' % path)
        return res
    res['bytes'] = os.path.getsize(path)
    try:
        zf = zipfile.ZipFile(path)
    except Exception as exc:
        res['problems'].append('not a readable zip: %s' % exc)
        return res
    with zf:
        names = zf.namelist()
        res['parts'] = len(names)
        res['zip_ok'] = len(names) == len(set(names))
        if not res['zip_ok']:
            res['problems'].append('duplicate zip entries')
        slides = [n for n in names if re.match(r'^ppt/slides/slide\d+\.xml$', n)]
        res['slides'] = len(slides)
        if res['slides'] != expect_slides:
            res['problems'].append('slides=%d, expected %d' % (res['slides'], expect_slides))
        for need in ('[Content_Types].xml', '_rels/.rels', 'ppt/presentation.xml',
                     'ppt/_rels/presentation.xml.rels', 'ppt/slideMasters/slideMaster1.xml',
                     'ppt/theme/theme1.xml'):
            if need not in names:
                res['problems'].append('missing part: %s' % need)
        # every xml/rels part parses
        bad = []
        text = []
        for n in names:
            if not n.endswith(('.xml', '.rels')):
                continue
            try:
                body = zf.read(n).decode('utf-8', 'replace')
                if n.endswith('.xml'):
                    import xml.etree.ElementTree as ET
                    ET.fromstring(body)
                else:
                    import xml.etree.ElementTree as ET
                    ET.fromstring(body)
                res['xml_parts'] += 1
                text.append(body)
            except Exception as exc:
                bad.append('%s (%s)' % (n, exc))
        res['xml_ok'] = not bad
        if bad:
            res['problems'].append('unparseable XML: %s' % ', '.join(bad[:3]))
        # relationship targets resolve inside the package
        import xml.etree.ElementTree as ET
        dangling = []
        for n in names:
            if not n.endswith('.rels'):
                continue
            base = '/'.join(n.split('/')[:-2])
            try:
                root = ET.fromstring(zf.read(n).decode('utf-8', 'replace'))
            except Exception:
                continue
            for rel in root:
                tgt = rel.get('Target') or ''
                if not tgt or tgt.startswith('http') or rel.get('TargetMode') == 'External':
                    continue
                segs = [s for s in ((base + '/' + tgt).split('/')) if s not in ('', '.')]
                stack = []
                for seg in segs:
                    if seg == '..':
                        if stack:
                            stack.pop()
                    else:
                        stack.append(seg)
                if '/'.join(stack) not in names:
                    dangling.append('%s -> %s' % (n, tgt))
        res['rels_ok'] = not dangling
        if dangling:
            res['problems'].append('dangling relationships: %s' % '; '.join(dangling[:3]))
        # content types cover every part
        try:
            ctx = ET.fromstring(zf.read('[Content_Types].xml').decode('utf-8', 'replace'))
            defs = set()
            overrides = set()
            for el in ctx:
                tag = el.tag.split('}')[-1]
                if tag == 'Default':
                    defs.add((el.get('Extension') or '').lower())
                elif tag == 'Override':
                    overrides.add(el.get('PartName') or '')
            uncovered = []
            for n in names:
                if n == '[Content_Types].xml' or n.endswith('/'):
                    continue
                ext = n.rsplit('.', 1)[-1].lower() if '.' in n else ''
                if ext == 'rels' and 'rels' in defs:
                    continue
                if ext in defs or ('/' + n) in overrides:
                    continue
                uncovered.append(n)
            res['content_types_ok'] = not uncovered
            if uncovered:
                res['problems'].append('parts without a content type: %s' % ', '.join(uncovered[:3]))
        except Exception as exc:
            res['problems'].append('content types unreadable: %s' % exc)
        blob = ''.join(text)
        missing = [m for m in markers if m not in blob]
        res['missing_markers'] = missing
        res['markers_ok'] = not missing
        if missing:
            res['problems'].append('markers missing: %s' % ', '.join(missing))
    res['ok'] = not res['problems']
    return res


# ------------------------------------------------------------------ receipt
def write_receipt(json_path, txt_path, data):
    os.makedirs(os.path.dirname(json_path), exist_ok=True)
    with open(json_path, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write('\n')
    combo = [
        'pptmaster-%s environment=%s host=%s' % ('ok' if data.get('installed') else 'FAIL',
                                                 data.get('environment'), data.get('host')),
        'deck_slides=%s checker_blocking=%s markers=%s powerpoint=%s'
        % (data.get('deck_slides'), data.get('checker_blocking'),
           'ok' if data.get('deck_markers_ok') else 'FAIL',
           data.get('powerpoint') or 'na'),
        'python=%s deps_core=%s deps_full=%s slides_svg=%s export=%s'
        % (data.get('python_mode'), 'ok' if data.get('deps_core_ok') else 'FAIL',
           ('ok' if data.get('deps_full_ok') else
            ('partial' if data.get('deps_full_ok') is False else 'n/a')),
           data.get('svg_pages'), data.get('export_status')),
        'install_dir=%s' % data.get('install_dir'),
    ]
    with open(txt_path, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(combo) + '\n')
    return txt_path


def patch_com(json_path, txt_path, com_result):
    """Fold the PowerPoint COM open result into an existing receipt.

    'ok slides=N'   the real application opened the deck -> pass
    'skip <reason>' no COM server / disabled / no answer  -> neutral, the
                    structural checks above still stand (same policy as 3h)
    anything else   the application refused the file         -> fail
    """
    with open(json_path, encoding='utf-8') as fh:
        data = json.load(fh)
    text = (com_result or '').strip()
    m = re.search(r'slides=(\d+)', text)
    slides = int(m.group(1)) if m else None
    ok = text.startswith('ok')
    skip = text.startswith('skip')
    data['powerpoint_ok'] = ok
    data['powerpoint_slides'] = slides
    data['powerpoint'] = 'yes' if ok else ('na' if skip else 'no')
    data['powerpoint_detail'] = text
    if ok and slides is not None and slides != EXPECT_SLIDES:
        data['powerpoint'] = 'no'
        data['installed'] = False
        data.setdefault('problems', []).append('PowerPoint opened %s slides, expected %d'
                                               % (slides, EXPECT_SLIDES))
    if not ok and not skip:
        data['installed'] = False
        data.setdefault('problems', []).append('PowerPoint could not open the generated deck')
    write_receipt(json_path, txt_path, data)
    log('powerpoint %s (%s)' % (data['powerpoint'], text))
    return 0 if (ok or skip) else 1


# ----------------------------------------------------------------- pipeline
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ppt-master', required=True, help='install dir of the ppt-master clone')
    ap.add_argument('--python', required=True, help='python that has the ppt-master deps')
    ap.add_argument('--repo', default=None, help='repo root (defaults to this script\'s repo)')
    ap.add_argument('--project', default='arena-local-01a0aa00')
    ap.add_argument('--environment', default='sandbox', choices=['sandbox', 'windows'])
    ap.add_argument('--host', default='sandbox')
    ap.add_argument('--expect-slides', type=int, default=EXPECT_SLIDES)
    ap.add_argument('--python-mode', default='direct',
                    help='venv | user | base | direct (how --python was obtained)')
    ap.add_argument('--deps-full-ok', type=int, default=-1,
                    help='1/0: did the full requirements.txt install succeed (-1 = not attempted)')
    ap.add_argument('--verify-deck')
    ap.add_argument('--patch-com')
    args = ap.parse_args()

    repo = os.path.abspath(args.repo or os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    receipt_json = os.path.join(repo, 'results', 'status', 'pptmaster_local.json')
    receipt_txt = os.path.join(repo, 'results', 'status', 'pptmaster_local.txt')

    if args.verify_deck:
        res = verify_deck(args.verify_deck, args.expect_slides, DECK_MARKERS)
        print(json.dumps(res, ensure_ascii=False, indent=2))
        return 0 if res['ok'] else 1

    if args.patch_com:
        return patch_com(receipt_json, receipt_txt, args.patch_com)

    pm = os.path.abspath(args.ppt_master)
    py = args.python
    scripts = os.path.join(pm, 'skills', 'ppt-master', 'scripts')
    data = {
        'schema': SCHEMA,
        'environment': args.environment,
        'host': args.host,
        'generated_utc': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
        'install_dir': pm,
        'installed': False,
        'python': py,
        'problems': [],
    }
    problems = data['problems']

    log('environment=%s host=%s' % (args.environment, args.host))
    log('install dir: %s' % pm)
    if not os.path.isdir(scripts):
        problems.append('ppt-master scripts not found in %s' % scripts)
        write_receipt(receipt_json, receipt_txt, data)
        log('FAIL: ppt-master is not installed at %s' % pm)
        return 2
    data['pptmaster_version'] = pm_version(pm)
    data['pptmaster_commit'] = (run(['git', '-C', pm, 'rev-parse', '--short', 'HEAD'])[1] or '').strip()
    data['skill_md'] = os.path.isfile(os.path.join(pm, 'skills', 'ppt-master', 'SKILL.md'))
    log('ppt-master v%s (%s), skill=%s'
        % (data['pptmaster_version'], data['pptmaster_commit'], data['skill_md']))

    data['python_mode'] = args.python_mode
    if args.deps_full_ok >= 0:
        data['deps_full_ok'] = bool(args.deps_full_ok)
    data['python_version'] = python_version(py)
    log('python: %s (%s, mode=%s)' % (py, data['python_version'], args.python_mode))

    # 1. the mandatory attribution guard
    code, out = run([py, os.path.join(scripts, 'attribution_guard.py')], timeout=300)
    data['guard_exit'] = code
    log('attribution_guard exit=%d' % code)
    if code != 0:
        problems.append('attribution_guard exit %d: %s' % (code, tail(out)))

    # 2. dependencies
    deps = probe_deps(py)
    data['deps'] = deps
    missing = [m for m in CORE_DEPS if not deps.get(m)]
    data['deps_core_ok'] = not missing
    log('deps core %s%s' % ('OK' if not missing else 'MISSING',
                            '' if not missing else ': ' + ', '.join(missing)))
    if missing:
        problems.append('missing python deps: %s' % ', '.join(missing))

    # 3. project + pages authored from THIS repo's generator
    project = os.path.join(pm, 'projects', args.project)
    if not os.path.isdir(os.path.join(project, 'svg_output')):
        code, out = run([py, os.path.join(scripts, 'project_manager.py'), 'init', args.project,
                         '--quick-generate'], cwd=pm, timeout=600)
        log('project_manager init exit=%d' % code)
        if code != 0:
            problems.append('project_manager init failed: %s' % tail(out))
    data['project'] = project

    gen = os.path.join(repo, 'code', 'make_deck_pptmaster.py')
    code, out = run([py, gen, '--out', os.path.join(project, 'svg_output')], cwd=repo, timeout=600)
    pages = sorted(glob.glob(os.path.join(project, 'svg_output', '*.svg')))
    data['svg_pages'] = len(pages)
    log('authored %d SVG page(s) with code/make_deck_pptmaster.py (exit %d)'
        % (len(pages), code))
    if code != 0 or not pages:
        problems.append('deck generator failed (exit %d): %s' % (code, tail(out)))

    code, out = run([py, os.path.join(scripts, 'compact_svg_styles.py'),
                     os.path.join(project, 'svg_output'), '--inplace'], cwd=pm, timeout=600)
    log('compact_svg_styles exit=%d' % code)
    if code != 0:
        problems.append('compact_svg_styles failed: %s' % tail(out))

    # 4. the page checker - the gate before any export
    code, out = run([py, os.path.join(scripts, 'svg_quality_checker.py'), project,
                     '--quick-generate', '--canonical-authoring', '--stage', 'final', '--json'],
                    cwd=pm, timeout=900)
    report_path = os.path.join(project, 'validation', 'svg_quality_report.json')
    summary = {}
    if os.path.isfile(report_path):
        try:
            with open(report_path, encoding='utf-8') as fh:
                rep = json.load(fh)
            summary = rep.get('summary') or {}
            blocking = ((rep.get('categories') or {}).get('blocking') or {}).get('count', -1)
            data['checker_blocking'] = int(blocking)
        except Exception as exc:
            problems.append('quality report unreadable: %s' % exc)
    data['checker_total'] = summary.get('total')
    data['checker_passed'] = summary.get('passed')
    data['checker_warnings'] = summary.get('warnings')
    data['checker_errors'] = summary.get('errors')
    log('svg_quality_checker exit=%d: total=%s passed=%s warnings=%s errors=%s blocking=%s'
        % (code, data['checker_total'], data['checker_passed'], data['checker_warnings'],
           data['checker_errors'], data.get('checker_blocking')))
    if code != 0:
        problems.append('svg_quality_checker exit %d: %s' % (code, tail(out)))
    if data.get('checker_errors'):
        problems.append('checker reported %s error(s)' % data['checker_errors'])
    if data.get('checker_blocking'):
        problems.append('checker reported %s blocking finding(s)' % data['checker_blocking'])

    # 5. export the native pptx
    deck_name = 'DECK_local_%s.pptx' % (datetime.datetime.utcnow().strftime('%Y%m%d'))
    out_dir = os.path.join(pm, 'out')
    os.makedirs(out_dir, exist_ok=True)
    deck = os.path.join(out_dir, deck_name)
    code, out = run([py, os.path.join(scripts, 'svg_to_pptx.py'), project,
                     '--quick-generate', '--no-notes', '-o', deck], cwd=pm, timeout=1800)
    log('svg_to_pptx exit=%d -> %s' % (code, deck))
    if code != 0:
        problems.append('svg_to_pptx failed: %s' % tail(out))
    reports = sorted(glob.glob(os.path.join(project, 'validation', '*.report.json')),
                     key=os.path.getmtime)
    if reports:
        try:
            with open(reports[-1], encoding='utf-8') as fh:
                exp = json.load(fh)
            data['export_status'] = exp.get('status')
            data['export_quality_gate'] = (exp.get('checks') or {}).get('quality_gate')
            data['export_slides'] = (exp.get('package') or {}).get('slides')
        except Exception as exc:
            problems.append('export report unreadable: %s' % exc)
    log('export status=%s quality_gate=%s slides=%s'
        % (data.get('export_status'), data.get('export_quality_gate'), data.get('export_slides')))
    if data.get('export_status') and not str(data['export_status']).startswith('passed'):
        problems.append('export postflight status=%s' % data['export_status'])

    # 6. verify the file that actually landed on disk
    data['deck_path'] = deck
    ver = verify_deck(deck, args.expect_slides, DECK_MARKERS)
    data.update({'deck_bytes': ver['bytes'], 'deck_slides': ver['slides'],
                 'deck_parts': ver['parts'], 'deck_xml_ok': ver['xml_ok'],
                 'deck_rels_ok': ver['rels_ok'], 'deck_content_types_ok': ver['content_types_ok'],
                 'deck_markers_ok': ver['markers_ok']})
    log('deck: %d B, %d slides, %d parts, xml=%s rels=%s markers=%s'
        % (ver['bytes'], ver['slides'], ver['parts'], ver['xml_ok'], ver['rels_ok'],
           ver['markers_ok']))
    if not ver['ok']:
        problems.append('deck verification: %s' % '; '.join(ver['problems'][:4]))

    # 7. ppt-master's own delivery check
    code, out = run([py, os.path.join(scripts, 'pptx_delivery_check.py'), deck], cwd=pm,
                    timeout=600)
    dc = {}
    try:
        dc = json.loads(out[out.index('{'):])
        data['delivery_check_errors'] = len(dc.get('errors') or [])
        data['delivery_check_advisories'] = len(dc.get('advisories') or [])
    except Exception:
        data['delivery_check_errors'] = None
        problems.append('pptx_delivery_check produced no parseable JSON: %s' % tail(out))
    log('pptx_delivery_check exit=%d errors=%s advisories=%s'
        % (code, data.get('delivery_check_errors'), data.get('delivery_check_advisories')))
    if data.get('delivery_check_errors'):
        problems.append('delivery check reported %s error(s)' % data['delivery_check_errors'])

    data['powerpoint'] = 'na'
    data['installed'] = not problems
    write_receipt(receipt_json, receipt_txt, data)
    log('receipt: %s' % os.path.relpath(receipt_txt, repo))
    if problems:
        log('FAIL: %d problem(s)' % len(problems))
        for item in problems:
            log('  - %s' % item)
        return 1
    log('OK: toolchain verified and deck regenerated + verified in this environment')
    return 0


if __name__ == '__main__':
    sys.exit(main())
