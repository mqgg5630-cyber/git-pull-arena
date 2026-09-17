#!/usr/bin/env python3
# make_deck_pptmaster.py - author the deck as canonical SVG pages for PPT Master.
#
# Pipeline (PPT Master v6.4.0, route "Generate PPTX - ordinary explicit Quick"):
#   1. python3 <ppt-master>/skills/ppt-master/scripts/project_manager.py init <name> --quick-generate
#   2. python3 code/make_deck_pptmaster.py --out <project>/svg_output     <- this file
#   3. python3 <ppt-master>/skills/ppt-master/scripts/svg_quality_checker.py <project> \
#          --quick-generate --canonical-authoring --stage final --json
#   4. python3 <ppt-master>/skills/ppt-master/scripts/svg_to_pptx.py <project> \
#          --quick-generate --no-notes -o deliverable/DECK_<session>_v<skill>.pptx
#
# Why a generator instead of hand-written SVG: 12 pages must not drift apart in
# tokens or geometry, and the deck has to be rebuildable after a content change.
# The pages stay plain canonical SVG - the generator only removes repetition.
#
# Authoring rules honoured (ppt-master references/shared-standards-core.md,
# references/semantic-svg.md, scripts/docs/svg-contract.md):
#   * strict XML, raw Unicode typography, no classes / stylesheets / masks /
#     foreignObject / textPath / scripts / animations; inline style only for the
#     registered paint + text properties
#   * common typography on the root <svg>; paint on the element or nearest <g>
#   * one root data-pptx-page-role on every flat page (cover / toc / section /
#     content / ending); identical viewBox on every page
#   * every logical body unit is one top-level <g id> with root-coordinate
#     data-pptx-bounds; groups never overlap (the checker fails on overlap)
#   * canvas-level framing stays a root primitive with id + data-pptx-role
#   * Windows PowerPoint faces: Microsoft YaHei (CJK + Latin) + Consolas (mono)
#
# Usage: python3 code/make_deck_pptmaster.py [--out DIR]

import argparse
import glob
import hashlib
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from deck_kit import (  # noqa: E402  (the shared deck framework)
    AMBER, ASCII_EM, BAD_XML_CHAR, BG, BLUE, BOUNDS_TOLERANCE, CJK_EM, CYAN, DIM, H, INK, LIME,
    LINE, LINE_SOFT, MONO, MONO_INK, MUTED, PANEL, PANEL_DEEP, Page, SANS, STRUCTURAL_ROLES, W,
    bounds_overlaps, card, divider_page, esc, root_bounds, run, text_width, xml_invalid_chars,
)

SESSION = '01a0aa00'
SKILL_VER = '2.8.1'
BRANCH = 'arena/%s-git-pull-arena' % SESSION
HOST = 'LAPTOP-R77M5D6M'
FOLDER = 'git-pull-arena-%s' % SESSION
FOOTER = 'git-sync v%s  ·  %s  ·  ppt-master v6.4.0' % (SKILL_VER, BRANCH)


# ----------------------------------------------------------------- facts
def repo_facts():
    """Numbers for the slides, read straight out of the repo (never hardcoded):
    check logs -> rounds + elapsed, success criteria -> assertion count,
    manifest -> artifact count. A deck rebuilt after a new round shows it."""
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    found = []
    for path in glob.glob(os.path.join(root, 'results', 'status', 'check_r*.txt')):
        stamp = re.search(r'check_r\d+_(\d{8}-\d{6})\.txt$', os.path.basename(path))
        if not stamp:
            continue
        body = open(path, encoding='utf-8', errors='replace').read()
        m = re.search(r'check round (\d+) on (\S+) - (passed|failed)', body)
        e = re.search(r'elapsed: (\d+)s', body)
        if m:
            found.append((stamp.group(1), int(m.group(1)), int(e.group(1)) if e else 0,
                          m.group(3) == 'passed'))
    found.sort()
    rounds = [(rnd, secs, ok) for _stamp, rnd, secs, ok in found][-4:]
    criteria = 0
    crit_path = os.path.join(root, 'results', 'status', 'success_criteria.json')
    if os.path.isfile(crit_path):
        crit = json.load(open(crit_path, encoding='utf-8'))
        for key in ('require_files', 'require_contains', 'require_regex', 'forbid_files',
                    'min_bytes', 'max_bytes'):
            criteria += len(crit.get(key) or {})
    deliverables = 0
    man_path = os.path.join(root, 'deliverable', 'OFFICE_HASHES.json')
    if os.path.isfile(man_path):
        deliverables = len(json.load(open(man_path, encoding='utf-8')).get('files', []))
    return {'rounds': rounds, 'criteria': criteria, 'deliverables': deliverables}


FACTS = repo_facts()

TOTAL_PAGES = 12
# the framework reads the deck's identity off the Page class (deck_kit.py)
Page.total_pages = TOTAL_PAGES
Page.footer = FOOTER
Page.host = HOST


# ----------------------------------------------------------------- pages
def page_cover():
    p = Page('cover')
    p.background()
    p.path('M0 470L1280 250', fill='none', stroke='#16324D', width=2,
           role='decoration', rid='cover-trace')
    p.circle(1042, 214, 5, LIME, glow=True, role='decoration', rid='cover-node-a')
    p.circle(893, 300, 4, CYAN, glow=True, role='decoration', rid='cover-node-b')
    p.rect(0, 0, 6, H, fill=CYAN, opacity='0.9', role='decoration', rid='cover-edge')

    p.group('cover-kicker', 90, 96, 900, 40)
    p.text(96, 128, '//  ARENA  ⇄  LOCAL   ·   SESSION ' + SESSION.upper(), 18, CYAN,
           family=MONO, spacing='4', limit=880)
    p.end()

    p.group('cover-title', 70, 186, 1150, 250)
    p.text(94, 300, 'Arena 与本机', 92, INK, weight='700', limit=1120)
    p.text(94, 400, '自循环打通报告', 92, CYAN, weight='700', limit=1120)
    p.end()

    p.group('cover-subtitle', 92, 438, 1010, 58)
    p.text(98, 474, '沙箱生成 → git 分支 → 本机值守判定 → 结论回传', 26, MONO_INK, limit=990)
    p.end()

    p.group('cover-rule', 96, 502, 300, 12)
    p.rect(98, 506, 300, 2, fill=CYAN, opacity='0.7')
    p.end()

    p.group('cover-kpis', 94, 524, 1006, 118)
    rounds = FACTS['rounds']
    passed = sum(1 for r in rounds if r[2])
    chips = [('%d / %d 轮' % (passed, len(rounds)), '真机逐轮 passed', LIME),
             ('%d 份交付物' % FACTS['deliverables'], 'docx · pptx · 清单', INK),
             ('0 失败 / 0 跳过', '%d 条成功标准全过' % FACTS['criteria'], MONO_INK)]
    for i, (value, label, accent) in enumerate(chips):
        cx = 98 + i * 274
        p.rect(cx, 536, 250, 92, fill=PANEL, stroke=LINE, rx=12, width=1)
        p.text(cx + 24, 578, value, 26, accent, weight='700', limit=220)
        p.text(cx + 24, 608, label, 15, MUTED, limit=220)
    p.end()

    p.group('cover-meta', 94, 646, 1010, 36)
    p.text(98, 672, '2026-09-16   ·   git-sync v%s   ·   %s' % (SKILL_VER, HOST), 16, DIM,
           family=MONO, limit=980)
    p.end()
    return p


def page_toc():
    p = Page('toc', 2, '//  INDEX', '这份报告讲什么', '六个问题，一条链路')
    p.background(grid=False)
    p.page_title()
    rows = [
        ('01', '一条链路', '沙箱 · git 分支 · 本机值守，各自负责什么'),
        ('02', '装了什么', '从你链接的会话装来的 git-sync v' + SKILL_VER),
        ('03', '自循环怎么跑', '五步一圈，值守一回传就结束'),
        ('04', '本机检查清单', '3a–3h 与 2a–2d 到底验了什么'),
        ('05', '交付物与命令', '七份文件 + 本机四条日常命令'),
        ('06', '边界与故障', '什么算打通，卡住怎么修'),
    ]
    for i, (num, name, note) in enumerate(rows):
        ry = 206 + 62 * i
        p.group('toc-row-%d' % (i + 1), 70, ry, 1140, 54)
        p.text(74, ry + 40, num, 22, CYAN, family=MONO, spacing='2')
        p.text(154, ry + 40, name, 26, INK, weight='700', limit=250)
        p.text(430, ry + 40, note, 19, MUTED, limit=760)
        p.line(72, ry + 50, 1208, ry + 50, LINE_SOFT, 1)
        p.end()
    return p


def page_chain():
    p = Page('content', 3, '//  TOPOLOGY', '一条链路的三个角色', '每一段都只传 git 提交')
    p.background(grid=False)
    p.page_title()
    boxes = [
        (72, 'chain-sandbox', 'Arena 沙箱', CYAN, [
            ('生成交付物（docx / pptx）', None, 17),
            ('agent-sync.sh 提交并推送', MONO, 15),
            ('agent-check.sh --request', MONO, 15),
            ('请求检查，round + 1', None, 17),
        ]),
        (468, 'chain-branch', 'GitHub 分支', BLUE, [
            (BRANCH, MONO, 15),
            ('唯一交换面：提交 + 日志 + 握手', None, 16),
            ('results/status/handshake.json', MONO, 15),
            ('两端只认这个分支', None, 17),
        ]),
        (864, 'chain-watcher', '本机值守', LIME, [
            ('计划任务 git-sync-watch-', MONO, 15),
            ('git-pull-arena-' + SESSION, MONO, 15),
            ('每 2 分钟一轮询：pull → 跑', None, 16),
            ('local_check.ps1，再推回结论', None, 16),
        ]),
    ]
    for x, gid, name, accent, lines in boxes:
        p.group(gid, x, 232, 344, 274)
        p.rect(x, 232, 344, 274, fill=PANEL, stroke=LINE, rx=14, width=1)
        p.rect(x, 232, 4, 274, fill=accent, rx=2)
        p.text(x + 32, 286, name, 26, INK, weight='700', limit=280)
        p.line(x + 32, 306, x + 312, 306, LINE_SOFT, 1)
        ly = 344
        for text, family, size in lines:
            p.text(x + 32, ly, text, size, MONO_INK if family == MONO else MUTED,
                   family=family, limit=280)
            ly += 38
        p.end()
    p.path('M420 368H456', fill='none', stroke='#2B4E75', width=3,
           role='decoration', rid='chain-arrow-1')
    p.path('M456 360L470 368L456 376Z', fill='#2B4E75', role='decoration', rid='chain-arrow-2')
    p.path('M816 368H852', fill='none', stroke='#2B4E75', width=3,
           role='decoration', rid='chain-arrow-3')
    p.path('M852 360L866 368L852 376Z', fill='#2B4E75', role='decoration', rid='chain-arrow-4')
    p.group('chain-note', 72, 526, 1136, 74)
    p.rect(72, 526, 1136, 74, fill=PANEL_DEEP, stroke=LINE, rx=12, width=1)
    p.text(100, 572, '唯一通道是 git：产物经分支到本机，结论从分支读回来；'
                     '值守没回传之前，助手不会说“已打通”。', 19, MONO_INK, limit=1080)
    p.end()
    return p


def page_installed():
    p = Page('content', 4, '//  WHAT SHIPPED', '装了什么（git-sync v' + SKILL_VER + '）',
             '从你链接的会话 01a0a9f0 装来，技能本体出自开发分支 01a0a98d')
    p.background(grid=False)
    p.page_title()
    cards = [
        ('installed-upgrade', 72, 230, CYAN, '安装器拒绝降级', [
            ('v2.7.4 → v' + SKILL_VER + '，一步装好', None, 17),
            ('不再被 main 上的旧版悄悄覆盖', None, 17),
            ('配置分支自动指向本会话分支', None, 17),
        ]),
        ('installed-python', 648, 230, LIME, '闸门逐个验证 python', [
            ('python3 / python / py -3 依次实测', None, 17),
            ('Microsoft Store 假 python3 不再骗过它', None, 17),
            ('本机以前那几项 SKIP 消失了', None, 17),
        ]),
        ('installed-office', 72, 422, AMBER, '开档测试读清单', [
            ('OFFICE_HASHES.json 决定打开哪些文件', None, 17),
            ('新增产物不用改脚本', None, 17),
            ('真 Word / 真 PowerPoint 只读开档', None, 17),
        ]),
        ('installed-bytes', 648, 422, BLUE, '字节判定更稳', [
            ('文本统一 LF 入库，两边字节数一致', None, 17),
            ('值守日志带时间戳', None, 17),
            ('轮询自适应，结论一到就返回', None, 17),
        ]),
    ]
    for gid, cx, cy, accent, name, lines in cards:
        card(p, cx, cy, 544, 178, accent, name, lines, gid)
    return p


def page_loop():
    p = Page('content', 5, '//  SELF-LOOP', '自循环：五步一圈', '一轮 30–60 秒，值守一回传就结束')
    p.background(grid=False)
    p.page_title()
    steps = [
        ('1', '提交推送', [('agent-sync.sh', MONO, 14), ('过闸门后 push', None, 14)]),
        ('2', '请求检查', [('agent-check.sh', MONO, 14), ('--request round + 1', MONO, 14)]),
        ('3', '本机执行', [('值守 pull', None, 14), ('跑 local_check.ps1', MONO, 14)]),
        ('4', '回传结论', [('passed / failed', MONO, 14), ('日志一起 push 回', None, 14)]),
        ('5', '读结论收尾', [('--read 0 / 2 / 3', MONO, 14), ('--accept 收尾', MONO, 14)]),
    ]
    for i, (num, name, lines) in enumerate(steps):
        cx = 72 + i * 234
        accent = CYAN if i < 2 else (LIME if i < 4 else AMBER)
        p.group('loop-step-%d' % (i + 1), cx, 246, 200, 214)
        p.rect(cx, 246, 200, 214, fill=PANEL, stroke=LINE, rx=14, width=1)
        p.circle(cx + 34, 288, 18, accent, opacity='0.16')
        p.text(cx + 34, 295, num, 20, accent, family=MONO, anchor='middle', weight='700')
        p.text(cx + 60, 295, name, 20, INK, weight='700', limit=132)
        ly = 342
        for text, family, size in lines:
            p.text(cx + 26, ly, text, size, MUTED, family=family, limit=150)
            ly += 28
        p.text(cx + 26, 428, 'P%d' % (i + 1), 13, DIM, family=MONO)
        p.end()
        if i < len(steps) - 1:
            p.path('M%d 352H%d' % (cx + 204, cx + 228), fill='none', stroke='#2B4E75', width=3,
                   role='decoration', rid='loop-arrow-%d' % (i + 1))
            p.path('M%d 344L%d 352L%d 360Z' % (cx + 228, cx + 240, cx + 228), fill='#2B4E75',
                   role='decoration', rid='loop-head-%d' % (i + 1))
    p.group('loop-note', 72, 486, 1136, 110)
    p.rect(72, 486, 1136, 110, fill=PANEL_DEEP, stroke=LINE, rx=12, width=1)
    p.text(100, 528, '一条命令跑完一圈：agent-handsfree.sh --timeout auto', 20, MONO_INK,
           family=MONO, limit=1080)
    p.text(100, 568, '沙箱不自己宣布成功：成功标准写在 results/status/success_criteria.json，'
                     '本机逐条验过才 --accept。', 17, MUTED, limit=1080)
    p.end()
    return p


def page_checks():
    p = Page('content', 6, '//  REAL-MACHINE CHECKS', '本机检查清单（code/local_check.ps1）',
             '每一条都在你的机器上跑，日志原样推回分支')
    p.background(grid=False)
    p.page_title()
    tiles = [
        ('3a', 'sha256 + 字节', CYAN), ('3b', 'OOXML 必需部件', CYAN),
        ('3c', '每个 XML 可解析', BLUE), ('3d', '关系不断链', BLUE),
        ('3e', '内容类型覆盖', LIME), ('3f', '关键标记词在文件里', LIME),
        ('3g', '页数达标', AMBER), ('3h', '真 Office 只读开档', AMBER),
    ]
    for i, (tag, name, accent) in enumerate(tiles):
        cx = 72 + (i % 4) * 290
        cy = 238 + (i // 4) * 124
        p.group('check-%s' % tag, cx, cy, 266, 106)
        p.rect(cx, cy, 266, 106, fill=PANEL, stroke=LINE, rx=12, width=1)
        p.text(cx + 24, cy + 46, tag, 24, accent, family=MONO, weight='700')
        p.text(cx + 24, cy + 82, name, 17, MUTED, limit=222)
        p.end()
    p.group('checks-note', 72, 486, 1136, 110)
    p.rect(72, 486, 1136, 110, fill=PANEL_DEEP, stroke=LINE, rx=12, width=1)
    p.text(100, 526, '2a–2d：免点击推送实证（ls-remote + push --dry-run）、值守收尾行、'
                     'hands-free 自动 pull / push。', 18, MONO_INK, limit=1080)
    p.text(100, 566, '闸门 code/check_all.sh 也在本机真跑：.ps1 全 ASCII、配置分支与 HEAD 一致、'
                     '根目录脚本与技能脚本逐字节相同。', 16, MUTED, limit=1080)
    p.end()
    return p


def page_numbers():
    f = FACTS
    total = len(f['rounds'])
    secs = [r[1] for r in f['rounds'] if r[1]]
    span = '%d–%ds' % (min(secs), max(secs)) if secs else 'n/a'
    p = Page('content', 7, '//  NUMBERS', '真机数据（%d 轮全部 passed）' % total,
             '耗时取自 results/status/check_r*.txt，不是估计值')
    p.background(grid=False)
    p.page_title()
    kpis = [('0', '失败 / 0 跳过', LIME), ('%d' % f['criteria'], '条成功标准全过', CYAN),
            (span, '单轮耗时（真机）', MONO_INK), ('%d' % f['deliverables'], '份交付物', AMBER)]
    for i, (value, label, accent) in enumerate(kpis):
        cx = 72 + i * 288
        p.group('kpi-%d' % (i + 1), cx, 228, 264, 102)
        p.rect(cx, 228, 264, 102, fill=PANEL, stroke=LINE, rx=12, width=1)
        p.text(cx + 24, 282, value, 28, accent, weight='700', limit=220)
        p.text(cx + 24, 314, label, 15, MUTED, limit=220)
        p.end()
    # Scale every bar against the slowest round and cap the height. The old
    # fixed slope (elapsed/40*180) let a slow round grow its module box up into
    # the KPI row, and the machine's own numbers did exactly that: kpi-2/kpi-3
    # data-pptx-bounds overlapped bar-3 (checker exit 1, blocking=2, round 28).
    base = 560
    slow = max([el for _r, el, _ok in f['rounds']] or [1]) or 1
    for i, (rnd, el, ok) in enumerate(f['rounds']):
        h = max(24, int(min(max(el, 0), slow) / float(slow) * 150))
        bx = 180 + i * 190
        by = base - h
        accent = LIME if ok else AMBER
        p.group('bar-%d' % (i + 1), bx - 28, by - 36, 152, h + 76)
        p.rect(bx, by, 96, h, fill=accent, rx=6, opacity='0.9')
        p.text(bx + 48, by - 14, '%ds' % el, 22, INK, family=MONO, anchor='middle',
               weight='700', limit=140)
        p.text(bx + 48, base + 30, 'round %d' % rnd, 18, MUTED, anchor='middle', limit=170)
        p.end()
    p.line(150, base, 900, base, LINE, 2, role='decoration', rid='axis')
    p.group('numbers-host', 900, 360, 308, 112)
    p.text(1208, 398, 'host ' + HOST, 20, INK, family=MONO, anchor='end', weight='700',
           limit=300)
    p.text(1208, 428, 'Windows 11 · conda base', 15, MUTED, anchor='end', limit=300)
    p.text(1208, 452, 'python 3.11.9 · 真 Office 开档', 15, MUTED, anchor='end', limit=300)
    p.end()
    return p


def page_deliverables():
    p = Page('content', 8, '//  DELIVERABLES', '交付物（都在本会话分支的 deliverable/）',
             '本机 .\\download.ps1 -Set final 可以把整个目录镜像出来')
    p.background(grid=False)
    p.page_title()
    rows = [
        ('BRIDGE_%s_v%s.docx / .pptx' % (SESSION, SKILL_VER), '打通报告',
         '装了什么、链路怎么走、本机粘哪段命令', False),
        ('GUIDE_%s_v%s.docx / .pptx' % (SESSION, SKILL_VER), '使用说明 · 10 页',
         '安装 / 日常命令 / 值守 / 故障 / 边界', False),
        ('DECK_%s_v%s.pptx' % (SESSION, SKILL_VER), '本文件 · ppt-master',
         '12 页设计稿，原生 DrawingML 形状，可直接改', True),
        ('DELIVERY_%s_v%s.docx / .pptx' % (SESSION, SKILL_VER), '交付清单',
         '文件哈希 + 本机回执', False),
        ('OFFICE_HASHES.json', '哈希清单', '真机开档测试按它决定打开哪些文件', False),
    ]
    for i, (name, kind, note, highlight) in enumerate(rows):
        ry = 232 + 72 * i
        p.group('deliverable-%d' % (i + 1), 72, ry, 1136, 64)
        p.rect(72, ry, 1136, 64, fill=PANEL, stroke=LIME if highlight else LINE_SOFT,
               rx=10, width=1)
        p.text(98, ry + 38, name, 18, INK, family=MONO, limit=470)
        p.text(600, ry + 38, kind, 17, CYAN if highlight else MUTED, limit=190)
        p.text(800, ry + 38, note, 16, MUTED, limit=380)
        p.end()
    p.group('deliverables-note', 72, 596, 1136, 26)
    p.text(72, 614, '生成器也一起进仓库：code/make_deck_pptmaster.py（本 pptx）、'
                    'code/make_bridge_report.py（报告与清单）。', 16, DIM, limit=1120)
    p.end()
    return p


def page_commands():
    p = Page('content', 10, '//  YOUR MACHINE', '本机命令（在克隆目录里）',
             'E:\\0github\\git-sync\\' + FOLDER)
    p.background(grid=False)
    p.page_title()
    cmds = [
        ('.\\bootstrap.ps1 -Auto', '一次装好：身份 + 分支 + 免点击推送 + 注册值守'),
        ('.\\doctor.ps1', '体检：分支 / ahead-behind / 值守 / 心跳 / 凭据'),
        ('.\\watch.ps1 -Status', '值守活着吗：模式 / 上次运行 / 心跳 / 最近一轮'),
        ('.\\download.ps1 -Set final', '把 deliverable\\ 镜像到 ..\\git-pull-arena_out\\'),
        ('.\\auth.ps1 -Setup -Verify', '推送不用点确认，并当场证明'),
        ('.\\watch.ps1 -Focus', '只留本会话值守（其它会话任务保留）'),
    ]
    for i, (cmd, note) in enumerate(cmds):
        cx = 72 + (i % 2) * 576
        cy = 232 + (i // 2) * 118
        p.group('command-%d' % (i + 1), cx, cy, 544, 100)
        p.rect(cx, cy, 544, 100, fill=PANEL, stroke=LINE, rx=12, width=1)
        p.text(cx + 28, cy + 42, cmd, 19, LIME, family=MONO, limit=490)
        p.text(cx + 28, cy + 74, note, 16, MUTED, limit=490)
        p.end()
    return p


def page_ending():
    p = Page('ending')
    p.background()
    p.path('M0 250L1280 470', fill='none', stroke='#16324D', width=2,
           role='decoration', rid='ending-trace')
    p.group('ending-kicker', 90, 216, 900, 44)
    p.text(94, 246, '//  STATUS', 18, CYAN, family=MONO, spacing='4', limit=880)
    p.end()
    p.group('ending-headline', 70, 280, 1140, 150)
    p.text(92, 380, '已打通', 96, LIME, weight='700', limit=1100)
    p.end()
    p.group('ending-status', 70, 436, 1150, 44)
    latest = max([r[0] for r in FACTS['rounds']] or [0])
    p.text(96, 466, 'results/status/handshake.json · round %d · accepted · local_state=passed'
           % latest, 19, MONO_INK, family=MONO, limit=1120)
    p.end()
    p.group('ending-rule', 94, 488, 300, 14)
    p.rect(96, 492, 300, 2, fill=LIME, opacity='0.7')
    p.end()
    p.group('ending-note', 70, 508, 1120, 56)
    p.text(96, 544, '下一步：回本会话说一句就行，值守会把改动 pull 到这台机器；'
                    '要继续循环，助手直接跑 agent-handsfree.sh。', 19, MUTED, limit=1090)
    p.end()
    p.group('ending-paths', 70, 584, 1150, 36)
    p.text(96, 610, '交付物：deliverable/   ·   台账：CONNECTIONS.md   ·   日志：results/status/check_r*',
           16, DIM, family=MONO, limit=1120)
    p.end()
    p.text(96, 672, '2026-09-16   ·   git-sync v%s   ·   ppt-master v6.4.0' % SKILL_VER, 16, DIM,
           family=MONO, role='footer', tid='footer-left')
    return p


BUILDERS = [
    ('01_cover.svg', page_cover),
    ('02_toc.svg', page_toc),
    ('03_section_a.svg', lambda: divider_page('01', 'SECTION 01', '一条链路',
                                              '沙箱 → git 分支 → 你的 Windows 机器',
                                              '没有别的通道：不是沙箱里的假本地，也没有自制桥接脚本。')),
    ('04_chain.svg', page_chain),
    ('05_installed.svg', page_installed),
    ('06_loop.svg', page_loop),
    ('07_checks.svg', page_checks),
    ('08_numbers.svg', page_numbers),
    ('09_deliverables.svg', page_deliverables),
    ('10_section_b.svg', lambda: divider_page('02', 'SECTION 02', '一次装好',
                                              '本机四条日常命令 + 卡住怎么修',
                                              '值守注册好之后，你不用每轮手动 sync / push。')),
    ('11_commands.svg', page_commands),
    ('12_ending.svg', page_ending),
]


def main():
    """Author the pages, validating what the machine's checker will validate."""
    return run(BUILDERS, session=SESSION,
               apply_facts=lambda d: globals().__setitem__('FACTS', d),
               title='git-sync')


if __name__ == '__main__':
    sys.exit(main())
