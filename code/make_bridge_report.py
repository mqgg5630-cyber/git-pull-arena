#!/usr/bin/env python3
# make_bridge_report.py - this session's bridge proof: one .docx + one .pptx
# plus deliverable/OFFICE_HASHES.json, the manifest the REAL machine verifies.
#
# Why it exists (session 01a0aa00, 2026-09-16):
#   the user asked to install the skills of arena.ai/agent/01a0a9f0 (that is
#   git-sync v2.8.1, branch arena/01a0a9f0-git-pull-arena) and to connect that
#   to their own Windows box (conda base / spyder, E:\0github\git-sync).
#   A link that is only claimed is worth nothing: the deliverables must travel
#   through git and be judged by the scheduled watcher on that machine. This
#   script builds them, then re-implements code/local_check.ps1 section 3
#   (3a-3g) in Python so the package is proven INSIDE the sandbox before push.
#
# Sandbox policy (v2.8.0+): python-docx / python-pptx / .venv are allowed here -
# they are just generators. The one hard rule left: "local" means the user's
# machine (never local/inbox, never a hand-made stand-in skill).
#
# Usage:
#   python3 code/make_bridge_report.py            # build + self-verify + manifest
#   python3 code/make_bridge_report.py --verify   # only re-run the 3a-3g mirror
#
# Exit codes: 0 ok, 1 a check failed (never write a manifest you cannot prove).

import datetime
import hashlib
import json
import os
import re
import sys
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
OUT = os.path.join(ROOT, 'deliverable')
MANIFEST = os.path.join(OUT, 'OFFICE_HASHES.json')
DOCX = os.path.join(OUT, 'BRIDGE_01a0aa00_v2.8.1.docx')
PPTX = os.path.join(OUT, 'BRIDGE_01a0aa00_v2.8.1.pptx')

SESSION = '01a0aa00'
SOURCE_SESSION = '01a0a9f0'
SOURCE_BRANCH = 'arena/01a0a9f0-git-pull-arena'
SKILL_DEV_BRANCH = 'arena/01a0a98d-git-pull-arena'
BRANCH_FALLBACK = 'arena/01a0aa00-git-pull-arena'
FOLDER = 'git-pull-arena-01a0aa00'
MARKERS = ['2.8.1', 'git-sync', 'local_check.ps1']

HANDOFF = """cd E:\\0github\\git-sync
git clone -b %s https://github.com/mqgg5630-cyber/git-pull-arena.git %s
cd %s
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\\bootstrap.ps1 -Auto      # 身份 + 分支 + 免点击推送凭据 + 注册值守
.\\doctor.ps1               # branch=%s, ahead/behind 0/0, watcher/heartbeat/auth
.\\watch.ps1 -Status        # 应看到 hands-free: master=True""" % (
    BRANCH_FALLBACK, FOLDER, FOLDER, BRANCH_FALLBACK)


# --------------------------------------------------------------------- facts
def repo_facts():
    # the round number is the handshake's own counter (the branch inherits the
    # numbering of the commit it was forked from, so do not assume it starts at 1)
    facts = {'branch': BRANCH_FALLBACK, 'version': '2.8.1', 'host': '', 'lines': [], 'round': 1}
    hs = os.path.join(ROOT, 'results', 'status', 'handshake.json')
    try:
        with open(hs, encoding='utf-8-sig') as fh:
            facts['round'] = int(json.load(fh).get('round') or 1)
    except Exception:
        pass
    cfg = os.path.join(ROOT, 'skills', 'git-sync', 'sync.config.json')
    try:
        with open(cfg, encoding='utf-8-sig') as fh:
            facts['branch'] = json.load(fh).get('branch') or BRANCH_FALLBACK
    except Exception:
        pass
    ver = os.path.join(ROOT, 'skills', 'git-sync', 'VERSION')
    try:
        with open(ver, encoding='utf-8') as fh:
            facts['version'] = fh.read().strip() or facts['version']
    except Exception:
        pass
    hw = os.path.join(ROOT, 'results', 'hardware', 'latest.md')
    if os.path.isfile(hw):
        with open(hw, encoding='utf-8', errors='replace') as fh:
            text = fh.read()
        for line in text.splitlines():
            line = line.strip()
            if line.startswith('- generated:'):
                m = re.search(r'host:\s*([^\s]+)', line)
                if m:
                    facts['host'] = m.group(1)
            if line.startswith('- '):
                facts['lines'].append(line[2:])
    return facts


def hw_line(facts, needle):
    for line in facts['lines']:
        if line.lower().startswith(needle):
            return line
    return ''


def docx_body(facts):
    """[(kind, text)] - kept in one place so the docx and the markers agree."""
    host = facts['host'] or 'LAPTOP-R77M5D6M'
    body = [
        ('h1', '1. 这一轮装了什么（session %s）' % SESSION),
        ('b', '安装来源：用户给的 arena.ai/agent/%s —— 也就是 GitHub 分支 %s 上的 '
              'skills/git-sync v%s（那个会话的技能又取自开发分支 %s）。'
              % (SOURCE_SESSION, SOURCE_BRANCH, facts['version'], SKILL_DEV_BRANCH)),
        ('b', '技能本体：skills/git-sync v%d.%d.%d，由 skills/git-sync/scripts/agent-install.sh '
              '安装（v2.7.4 -> v%s）；安装器不再静默降级，也不再把 main 上的旧版盖上来。'
              % (2, 8, 1, facts['version'])),
        ('b', '本会话分支：%s（所有脚本只拉/推这个分支；配置分支与 HEAD 不一致时闸门直接失败）'
              % facts['branch']),
        ('b', '仓库闸门：code/check_all.sh（.ps1 全 ASCII、配置分支 == HEAD、根目录脚本与技能脚本一致、'
              '$var: 笔误扫描、值守收尾行、.ps1 逐个解析）'),
        ('b', '真机检查：code/local_check.ps1 —— 值守收到助手请求时执行的那个脚本（下面第 4 节）'),
        ('b', '本机侧：一个新文件夹 clone + .\\bootstrap.ps1 -Auto（注册值守 + 免点击推送），一共只做一次'),

        ('h1', '2. 本机怎么打通（粘一次，Windows PowerShell）'),
        ('p', '这段由 bash skills/git-sync/scripts/agent-handoff.sh 生成，真值来自 git remote get-url '
              '+ sync.config.json，不要手打（手打会写错仓库/分支/路径，请求就永远停在 pending）。'),
        ('code', HANDOFF),
        ('b', '不要覆盖已有目录：git-pull-arena / git-pull-arena-v268 / git-pull-arena-s2 / '
              'git-pull-arena-01a0a9f0。这是新文件夹 %s。' % FOLDER),
        ('b', 'bootstrap -Auto 会把本机其它 git-sync-watch-* 值守暂停（任务保留）：'
              '.\\watch.ps1 -RestoreParked 一次全恢复；切回某个会话用 .\\watch.ps1 -Focus。'),

        ('h1', '3. 循环里谁做什么'),
        ('tbl', ['步骤', '命令', '在哪跑']),
        ('trow', ['干活 + 推送', 'bash skills/git-sync/scripts/agent-sync.sh "feat: ..."', 'Arena 沙箱']),
        ('trow', ['请求本机检查', 'bash skills/git-sync/scripts/agent-check.sh --request "verify ..."', 'Arena 沙箱']),
        ('trow', ['拉取 + 跑检查 + 推回结论', 'sync.ps1 -> code/local_check.ps1 -> push', '本机值守（计划任务）']),
        ('trow', ['读结论', 'bash skills/git-sync/scripts/agent-check.sh --read  (0 过 / 2 败 / 3 等待)', 'Arena 沙箱']),
        ('trow', ['收尾', 'bash skills/git-sync/scripts/agent-check.sh --accept', 'Arena 沙箱']),

        ('h1', '4. 本机到底检查什么（code/local_check.ps1）'),
        ('tbl', ['项', '证明的事情']),
        ('trow', ['gate', '仓库闸门在这台机器上真的跑起来了（本机 git 自带 bash），含 python 扫描']),
        ('trow', ['3a', '每个产物的 sha256 + 字节数与沙箱生成的一致']),
        ('trow', ['3b', 'OOXML 必需部件齐全（缺部件 = Office 报文件损坏）']),
        ('trow', ['3c', '每个 .xml / .rels 部件都能解析']),
        ('trow', ['3d', '每个关系目标都在包内存在（没有断链的 r:id）']),
        ('trow', ['3e', '[Content_Types].xml 覆盖每一个部件']),
        ('trow', ['3f', '标记词真的在文件里（markers，见文末）']),
        ('trow', ['3g', '幻灯片数不少于承诺值（min_slides）']),
        ('trow', ['3h', '真 Word / 真 PowerPoint（或 WPS）只读打开该文件，带硬超时']),
        ('trow', ['2a-2d', '免点击推送实证、值守窗口等级、每出口收尾行、hands-free 自动 pull/push']),

        ('h1', '5. 链路的另一端（这台机器）'),
        ('b', 'host %s（来自 results/hardware/latest.md，由 hardware.ps1 采集）' % host),
    ]
    for line in [hw_line(facts, 'os:'), hw_line(facts, 'cpu:'), hw_line(facts, 'ram:'),
                 hw_line(facts, 'nvidia'), hw_line(facts, 'global python:'),
                 hw_line(facts, 'conda:'), hw_line(facts, 'git:')]:
        if line:
            body.append(('b', line))
    body += [
        ('p', 'v2.8.1 里与这台机器直接相关的两条：① 闸门改成「逐个验证 python 候选」'
              '（python3 / python / py -3），Microsoft Store 那个假 python3 挡不住真检查了，'
              '本机以前那几项 SKIP 应该消失；② 3h 开档测试改成读 deliverable/OFFICE_HASHES.json，'
              '所以这轮的产物会被真 Word / 真 PowerPoint 打开验证。'),

        ('h1', '6. 怎么读一轮的结论'),
        ('b', 'results/status/handshake.json —— round、arena_state（awaiting_check / accepted）、'
              'local_state（pending / passed / failed）、host、时间戳'),
        ('b', 'results/status/check_rN_<时间戳>.txt —— 本机推回的第 N 轮完整日志'),
        ('b', ('本轮（round %d）状态：awaiting_check / pending —— 等这台机器的值守回传。'
               '在本机粘完第 2 节并跑完 bootstrap 之后，最多一个轮询间隔（默认 2 分钟）就会自动判定。')
              % facts['round']),

        ('h1', '7. 不糊弄的边界'),
        ('b', '「本机」= 你 Windows 上那个计划任务值守（git-sync-watch-%s）；'
              '不是沙箱里的 local/inbox，也不是自制脚本冒充的本地。' % FOLDER),
        ('b', '沙箱可以 pip install / .venv 生成产物（v2.8.0 起）：生成器只是工具，证据必须先经 git 到本机。'),
        ('b', '沙箱不会自己宣布成功：结论必须由本机值守写回 handshake 并从远端读回来。'),

        ('h1', '8. 中文速查（在克隆目录里）'),
        ('b', '.\\sync.ps1 取最新；.\\push.ps1 "说明" 提交并推送（默认静默免点击）'),
        ('b', '.\\doctor.ps1 体检（技能版本 + 值守/心跳/凭据 + hands-free master=True）'),
        ('b', '.\\watch.ps1 -Status 值守活着吗；.\\watch.ps1 -Test 立刻跑一轮；.\\watch.ps1 -Unregister 摘除'),
        ('b', '.\\download.ps1 -Set final 把 deliverable\\ 镜像到 ..\\%s_out\\（本报告的 docx/pptx 就在里面）'
              % 'git-pull-arena'),
        ('b', '.\\auth.ps1 -Setup -Verify 一次性配好免点击推送并当场证明（每台机器一次）'),

        ('h1', '9. 产物清单（本报告自己）'),
        ('b', 'deliverable/BRIDGE_01a0aa00_v2.8.1.docx —— 本文档'),
        ('b', 'deliverable/BRIDGE_01a0aa00_v2.8.1.pptx —— 同一内容的 8 页幻灯片'),
        ('b', 'deliverable/OFFICE_HASHES.json —— sha256/字节/必需部件/标记词的清单，3h 开档测试按它找文件'),
        ('b', '生成器：code/make_bridge_report.py（跑之前先在本机跑同一套 3a-3g 的 Python 镜像自检）'),
    ]
    return body


# ---------------------------------------------------------------------- docx
def build_docx(facts):
    from docx import Document

    host = facts['host'] or 'LAPTOP-R77M5D6M'
    doc = Document()
    doc.core_properties.title = 'Arena <-> local bridge report (session %s)' % SESSION
    doc.core_properties.comments = 'git-sync v%s branch %s' % (facts['version'], facts['branch'])

    doc.add_heading('Arena <-> 本机 打通报告', 0)
    doc.add_paragraph('session %s  |  git-sync v%s  |  branch %s  |  '
                      'generated by code/make_bridge_report.py'
                      % (SESSION, facts['version'], facts['branch']))

    for kind, text in docx_body(facts):
        if kind == 'h1':
            doc.add_heading(text, level=1)
        elif kind == 'p':
            doc.add_paragraph(text)
        elif kind == 'b':
            doc.add_paragraph(text, style='List Bullet')
        elif kind == 'code':
            para = doc.add_paragraph()
            run = para.add_run(text)
            run.font.name = 'Consolas'
        elif kind == 'tbl':
            table = doc.add_table(rows=1, cols=len(text))
            table.style = 'Table Grid'
            for i, name in enumerate(text):
                table.rows[0].cells[i].text = name
        elif kind == 'trow':
            row = doc.tables[-1].add_row().cells
            for i, value in enumerate(text):
                row[i].text = value

    doc.add_paragraph()
    doc.add_paragraph(('round %d = 这一轮（awaiting_check / pending）  |  markers: '
                       % facts['round']) + ' , '.join(MARKERS + ['round %d' % facts['round'], host, facts['branch']]))
    doc.save(DOCX)


# ---------------------------------------------------------------------- pptx
def build_pptx(facts):
    from pptx import Presentation
    from pptx.util import Pt

    host = facts['host'] or 'LAPTOP-R77M5D6M'
    prs = Presentation()

    def bullets(slide, items):
        frame = slide.placeholders[1].text_frame
        frame.clear()
        for i, item in enumerate(items):
            para = frame.paragraphs[0] if i == 0 else frame.add_paragraph()
            para.text = item
            para.font.size = Pt(15)

    def content(title, items):
        slide = prs.slides.add_slide(prs.slide_layouts[1])
        slide.shapes.title.text = title
        bullets(slide, items)

    slide = prs.slides.add_slide(prs.slide_layouts[0])
    slide.shapes.title.text = 'Arena <-> 本机 打通报告'
    slide.placeholders[1].text = ('session %s  |  git-sync v%s\n%s'
                                  % (SESSION, facts['version'], facts['branch']))

    content('装了什么', [
        '技能来源：arena.ai/agent/%s = 分支 %s 上的 skills/git-sync v%s'
        % (SOURCE_SESSION, SOURCE_BRANCH, facts['version']),
        '开发分支：%s（v2.8.1 的出处）' % SKILL_DEV_BRANCH,
        '安装：agent-install.sh，v2.7.4 -> v%s，拒绝降级' % facts['version'],
        '仓库闸门 code/check_all.sh + 真机检查 code/local_check.ps1（3a-3h）',
    ])

    content('本机怎么打通（只做一次）', [
        'cd E:\\0github\\git-sync',
        'git clone -b %s <repo> %s' % (facts['branch'], FOLDER),
        'cd %s ; .\\bootstrap.ps1 -Auto' % FOLDER,
        '.\\doctor.ps1 ; .\\watch.ps1 -Status（hands-free master=True）',
        '不要覆盖 git-pull-arena / -v268 / -s2 / -01a0a9f0',
    ])

    content('循环：谁做什么', [
        'Arena：agent-sync.sh 提交并推送到本会话分支',
        'Arena：agent-check.sh --request 请求一轮检查（round + 1）',
        '本机：值守 pull -> 跑 local_check.ps1 -> 把结论和日志推回分支',
        'Arena：--read 读结论（0 过 / 2 败 / 3 等待），满意就 --accept 收尾',
    ])

    content('本机证明什么', [
        'gate：闸门在本机（git 自带 bash）真的跑起来',
        '3a sha256+字节 | 3b OOXML 必需部件 | 3c 每个 XML 可解析',
        '3d 关系不断链 | 3e 内容类型齐全 | 3f 标记词在文件里 | 3g 页数达标',
        '3h 真 Word / 真 PowerPoint 只读打开，带 120s 硬超时',
        '2a-2d 免点击推送、值守窗口等级、收尾行、hands-free 拉推',
    ])

    content('另一端这台机器', [
        'host ' + host + '（results/hardware/latest.md）',
        'conda base python 3.11.9（E:\\spider\\python.exe）—— 本机检查用的就是它',
        'v2.8.1 闸门逐个验证 python3 / python / py -3，假 Store 存根不再造成 SKIP',
        '3h 开档测试读 OFFICE_HASHES.json，本报告的 docx/pptx 会被真 Office 打开',
    ])

    content('怎么读结论', [
        'results/status/handshake.json：round / arena_state / local_state / host',
        'results/status/check_rN_<时间戳>.txt：本机推回的第 N 轮完整日志',
        '本轮 round %d：awaiting_check / pending —— 等值守回传（默认 2 分钟一轮询）' % facts['round'],
        'passed -> agent-check.sh --accept 关闭这一轮',
    ])

    content('边界（不糊弄）', [
        '「本机」= Windows 计划任务值守 git-sync-watch-%s' % FOLDER,
        '不是沙箱里的 local/inbox，也不是自制脚本冒充的本地',
        '沙箱可以 pip/.venv 生成产物（v2.8.0 起）：生成器只是工具',
        '结论必须由本机值守写回 handshake 并从远端读回来',
    ])

    content('中文速查（克隆目录里）', [
        '.\\sync.ps1 取最新 | .\\push.ps1 "说明" 提交推送（静默免点击）',
        '.\\doctor.ps1 体检 | .\\watch.ps1 -Status / -Test / -Unregister',
        '.\\download.ps1 -Set final 把 deliverable\\ 镜像到 ..\\git-pull-arena_out\\',
        '.\\auth.ps1 -Setup -Verify 配好免点击推送并当场证明（每台机器一次）',
    ])

    prs.save(PPTX)


# --------------------------------------------------- mirror of local_check 3a-3g
def rels_base(name):
    segs = name.split('/')
    return '/'.join(segs[:-2]) if len(segs) > 2 else ''


def resolve(base, target):
    segs = [s for s in base.split('/') if s] if base else []
    for part in target.split('/'):
        if part in ('', '.'):
            continue
        if part == '..':
            segs = segs[:-1] if len(segs) > 1 else []
            continue
        segs.append(part)
    return '/'.join(segs)


def verify(manifest):
    problems = []
    import xml.etree.ElementTree as ET
    for entry in manifest['files']:
        rel = entry['path']
        path = os.path.join(ROOT, rel.replace('/', os.sep))
        if not os.path.isfile(path):
            problems.append('MISSING ' + rel)
            continue
        raw = open(path, 'rb').read()
        if len(raw) != int(entry['bytes']):
            problems.append('SIZE %s expected %s got %d' % (rel, entry['bytes'], len(raw)))
        if hashlib.sha256(raw).hexdigest() != entry['sha256']:
            problems.append('SHA256 ' + rel)

        with zipfile.ZipFile(path) as zf:
            names = zf.namelist()
            if len(set(names)) != len(names):
                problems.append('3b duplicate zip entries in ' + rel)
            name_set = set(names)

            missing = [p for p in entry['required_parts'] if p not in name_set]
            if missing:
                problems.append('3b missing parts in %s: %s' % (rel, ', '.join(missing)))

            xml_text = {}
            for name in names:
                if not name.endswith(('.xml', '.rels')):
                    continue
                try:
                    xml_text[name] = zf.read(name).decode('utf-8')
                except Exception as exc:
                    problems.append('3c unreadable %s in %s (%s)' % (name, rel, exc))
            for name, text in xml_text.items():
                try:
                    ET.fromstring(text)
                except Exception:
                    problems.append('3c unparseable XML %s in %s' % (name, rel))

            for name, text in xml_text.items():
                if not name.endswith('.rels'):
                    continue
                try:
                    root = ET.fromstring(text)
                except Exception:
                    continue
                base = rels_base(name)
                for node in root:
                    target = node.get('Target') or ''
                    if not target or target.startswith('http'):
                        continue
                    if resolve(base, target) not in name_set:
                        problems.append('3d dangling %s -> %s in %s' % (name, target, rel))

            ct = xml_text.get('[Content_Types].xml')
            if ct is None:
                problems.append('3e no [Content_Types].xml in ' + rel)
            else:
                root = ET.fromstring(ct)
                defs, ovrs = set(), set()
                for node in root:
                    tag = node.tag.split('}')[-1]
                    if tag == 'Default':
                        defs.add((node.get('Extension') or '').lower())
                    elif tag == 'Override':
                        ovrs.add(node.get('PartName') or '')
                for name in names:
                    if name == '[Content_Types].xml':
                        continue
                    ext = name.rsplit('.', 1)[-1].lower() if '.' in name else ''
                    if ('/' + name) not in ovrs and ext not in defs:
                        problems.append('3e no content type for %s in %s' % (name, rel))

            body = ''.join(xml_text.values())
            for marker in entry['must_contain']:
                if marker not in body:
                    problems.append('3f marker %r not found in %s' % (marker, rel))

            if entry.get('min_slides'):
                slides = len([n for n in names if re.match(r'^ppt/slides/slide[0-9]+\.xml$', n)])
                if slides < int(entry['min_slides']):
                    problems.append('3g slides %d < %d in %s' % (slides, entry['min_slides'], rel))
            if entry.get('main_part') and entry['main_part'] not in name_set:
                problems.append('main_part %s not in %s' % (entry['main_part'], rel))
    return problems


def main():
    verify_only = '--verify' in sys.argv[1:]
    facts = repo_facts()
    os.makedirs(OUT, exist_ok=True)

    if not verify_only:
        build_docx(facts)
        build_pptx(facts)
        print('built: %s' % os.path.relpath(DOCX, ROOT))
        print('built: %s' % os.path.relpath(PPTX, ROOT))
    elif not (os.path.isfile(DOCX) and os.path.isfile(PPTX)):
        print('[ERROR] nothing to verify - run without --verify first', file=sys.stderr)
        return 1

    entries = []
    for path, kind, required, main_part, markers, min_slides in [
        (DOCX, 'docx', ['[Content_Types].xml', '_rels/.rels', 'word/document.xml', 'word/styles.xml',
                        'word/_rels/document.xml.rels', 'docProps/core.xml'], 'word/document.xml',
         MARKERS + ['round %d' % facts['round'], facts['host'], facts['branch']], None),
        (PPTX, 'pptx', ['[Content_Types].xml', '_rels/.rels', 'ppt/presentation.xml',
                        'ppt/_rels/presentation.xml.rels', 'ppt/slides/slide1.xml',
                        'ppt/slideMasters/slideMaster1.xml', 'ppt/slideLayouts/slideLayout1.xml',
                        'ppt/theme/theme1.xml', 'docProps/core.xml'], 'ppt/presentation.xml',
         MARKERS + ['round %d' % facts['round'], facts['host'], facts['branch']], 8),
    ]:
        rel = os.path.relpath(path, ROOT).replace(os.sep, '/')
        if verify_only and os.path.isfile(MANIFEST):
            with open(MANIFEST, encoding='utf-8') as fh:
                cached = json.load(fh)
            for item in cached.get('files', []):
                if item['path'] == rel:
                    entries.append(item)
                    break
        if any(e['path'] == rel for e in entries):
            continue
        raw = open(path, 'rb').read()
        with zipfile.ZipFile(path) as zf:
            present = set(zf.namelist())
            slides = len([n for n in present if re.match(r'^ppt/slides/slide[0-9]+\.xml$', n)])
        entries.append({
            'path': rel,
            'kind': kind,
            'bytes': len(raw),
            'sha256': hashlib.sha256(raw).hexdigest(),
            'required_parts': required,
            'main_part': main_part,
            'must_contain': [m for m in markers if m],
            'min_slides': min_slides,
            'sandbox_selftest': {'parts': len(present), 'slides': slides},
        })

    manifest = {
        'generated_utc': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
        'generator': 'code/make_bridge_report.py',
        'generator_note': ('python-docx + python-pptx (allowed in the sandbox since v2.8.0); this manifest is '
                           'the contract the REAL machine verifies in code/local_check.ps1 section 3, and the '
                           'same 3a-3g rules are mirrored in Python here so a package that cannot pass is '
                           'never pushed'),
        'branch': facts['branch'],
        'session': SESSION,
        'skill_source': SOURCE_BRANCH,
        'skill_version': facts['version'],
        'how_local_verifies': ('code/local_check.ps1 compares sha256/bytes, opens the package, requires every '
                               'required_parts entry, parses every .xml/.rels part, resolves every relationship '
                               'target and content type, searches must_contain across all xml parts and counts '
                               'slides against min_slides; the Office COM open test (3h) runs on the real machine'),
        'handoff': HANDOFF,
        'files': entries,
    }

    problems = verify(manifest)
    if problems:
        print('[FAIL] the 3a-3g mirror found %d problem(s) - manifest NOT written:' % len(problems),
              file=sys.stderr)
        for item in problems:
            print('       ' + item, file=sys.stderr)
        return 1

    if not verify_only:
        with open(MANIFEST, 'w', encoding='utf-8') as fh:
            json.dump(manifest, fh, ensure_ascii=False, indent=2)
            fh.write('\n')
        print('wrote: %s' % os.path.relpath(MANIFEST, ROOT))

    print('== 3a-3g mirror PASSED for %d file(s)' % len(entries))
    for entry in entries:
        print('   OK %s (%d B, %s, slides=%s)'
              % (entry['path'], entry['bytes'], entry['kind'], entry['sandbox_selftest']['slides']))
    return 0


if __name__ == '__main__':
    sys.exit(main())
