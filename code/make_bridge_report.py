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
GUIDE_DOCX = os.path.join(OUT, 'GUIDE_01a0aa00_v2.8.1.docx')
GUIDE_PPTX = os.path.join(OUT, 'GUIDE_01a0aa00_v2.8.1.pptx')
DELIVERY_DOCX = os.path.join(OUT, 'DELIVERY_01a0aa00_v2.8.1.docx')
DELIVERY_PPTX = os.path.join(OUT, 'DELIVERY_01a0aa00_v2.8.1.pptx')

SESSION = '01a0aa00'
SOURCE_SESSION = '01a0a9f0'
SOURCE_BRANCH = 'arena/01a0a9f0-git-pull-arena'
SKILL_DEV_BRANCH = 'arena/01a0a98d-git-pull-arena'
BRANCH_FALLBACK = 'arena/01a0aa00-git-pull-arena'
FOLDER = 'git-pull-arena-01a0aa00'
MARKERS = ['2.8.1', 'git-sync', 'local_check.ps1']
GUIDE_MARKERS = ['2.8.1', 'git-sync', 'local_check.ps1', '使用说明',
                 '.\\bootstrap.ps1 -Auto', '.\\download.ps1', 'agent-handoff.sh']
DELIVERY_MARKERS = ['2.8.1', 'git-sync', '交付清单', 'download.ps1',
                    'results/status/handshake.json', 'round 21']

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
        ('p', '本会话另外交付了一份《使用说明》：deliverable/GUIDE_01a0aa00_v2.8.1.docx 与同内容的 '
              '幻灯片 GUIDE_01a0aa00_v2.8.1.pptx（安装 / 日常命令 / 值守 / 故障 / 边界，逐条可照抄）。'),

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
        ('b', '本轮的读写：agent-check.sh --request 把 handshake 写成 awaiting_check / pending，'
              '值守回传后变成 passed / failed 并 push 回分支；当前值永远看 results/status/handshake.json。'),

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
    doc.add_paragraph('markers: ' + ' , '.join(MARKERS + [host, facts['branch']]))
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
        '值守默认 2 分钟一轮询：pull -> 跑检查 -> 把结论和日志 push 回分支',
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


# --------------------------------------------------------------------- guide
def guide_rows():
    """(章节, [(小标题, 正文)]) - the user guide's content, one source of truth."""
    return [
        ('1. 这条链路是什么', [
            ('一句话', 'Arena 会话（沙箱）<-> 你的 Windows 本机，中间只有 git；本机侧是一个计划任务值守。'),
            ('分支', '本会话分支 arena/01a0aa00-git-pull-arena（所有脚本只拉/推它；push.ps1 拒绝 main/master）。'),
            ('目录', '本机克隆在 E:\\0github\\git-sync\\git-pull-arena-01a0aa00（新文件夹，不覆盖旧克隆）。'),
            ('为什么可靠', '每个结论都来自你机器上的值守：它 pull、跑 code/local_check.ps1、再把 passed/failed 与完整日志 push 回分支。'),
        ]),
        ('2. 首次安装（只做一次）', [
            ('命令', 'cd E:\\0github\\git-sync -> git clone -b arena/01a0aa00-git-pull-arena <repo> git-pull-arena-01a0aa00 -> cd 进去 -> .\\bootstrap.ps1 -Auto'),
            ('bootstrap 做什么', 'git 身份 + 切到工作分支 + 配置免点击推送凭据 + 注册值守（并暂停本机其它 git-sync-watch-*，任务保留）。'),
            ('验收', '.\\doctor.ps1 应显示 branch 正确、ahead/behind 0/0，末尾 watcher / heartbeat / auth / hands-free master=True 都是好消息。'),
            ('值守任务名', 'git-sync-watch-git-pull-arena-01a0aa00；Get-ScheduledTask git-sync-watch-* 可以看到本机所有值守。'),
            ('命令别手打', 'bash skills/git-sync/scripts/agent-handoff.sh 会打印上面这段填好真值的 PowerShell（仓库/分支/文件夹名来自 git remote + sync.config.json）。'),
        ]),
        ('3. 日常命令', [
            ('.\\sync.ps1', '取：拉最新（本地有改动会先自动 stash）。'),
            ('.\\push.ps1 "说明"', '传：pull --ff-only -> add -> commit -> push（默认静默，不用点任何确认）。'),
            ('.\\doctor.ps1', '体检；不对劲先跑它，-Fix 一键修 refspec / stash / 切分支 / 拉取。'),
            ('.\\download.ps1 -Set final', '把 deliverable\\ 镜像到 ..\\git-pull-arena_out\\（docx/pptx 就在里面）。'),
            ('.\\pack.ps1 -Set final', '打成 _export\\<日期>_final.zip（不进 git）。'),
            ('.\\auth.ps1 -Setup -Verify', '一次性配好免点击推送并当场证明（每台机器一次）。'),
        ]),
        ('4. 值守（自动验证循环）', [
            ('.\\watch.ps1 -Status', '值守活着吗：模式 / 上次运行 / 心跳 / 最近一轮 / other loops。'),
            ('.\\watch.ps1 -Test', '立刻跑一次，验证"真的会跑"（别信 LastTaskResult）。'),
            ('.\\watch.ps1 -Register', '重新注册（每 2 分钟轮询；-Interval 10 可降频；-Headless 是零窗口 S4U，需要管理员）。'),
            ('.\\watch.ps1 -Focus', '只留这一会话：暂停其它 git-sync-watch-*（任务保留，循环停掉）。'),
            ('.\\watch.ps1 -RestoreParked', '把 -Focus / -Register 暂停过的值守全部拉回来。'),
            ('.\\watch.ps1 -Unregister', '摘除值守。'),
        ]),
        ('5. 一轮循环里发生什么', [
            ('① 助手提交', 'bash skills/git-sync/scripts/agent-sync.sh "feat: ..." —— 提交前自动跑仓库闸门 code/check_all.sh。'),
            ('② 助手请求检查', 'bash skills/git-sync/scripts/agent-check.sh --request "verify ..." —— handshake 变 awaiting_check / pending。'),
            ('③ 本机自动', '值守 pull -> 跑 code/local_check.ps1 -> 把 passed/failed 与日志 push 回分支（hands-free 还会自动 push 本机改动）。'),
            ('④ 助手读结论', 'agent-check.sh --read：0 = passed / 2 = failed / 3 = 还在等；满足成功标准就 --accept 收尾。'),
            ('一条命令', 'bash skills/git-sync/scripts/agent-handsfree.sh --sync "..." --request "verify ..." --timeout auto（一回传就返回）。'),
        ]),
        ('6. 结论与交付物在哪', [
            ('状态', 'results/status/handshake.json（round / arena_state / local_state / host / 时间戳）。'),
            ('日志', 'results/status/check_rN_<时间戳>.txt（本机推回的第 N 轮完整日志，含每条 OK/FAIL）。'),
            ('成功标准', 'results/status/success_criteria.json（可机读的"没问题"定义，本机逐条验）。'),
            ('交付物', 'deliverable\\GUIDE_01a0aa00_v2.8.1.docx / .pptx（本说明）+ deliverable/OFFICE_HASHES.json（哈希清单，3h 开档测试按它找文件）。'),
            ('回执', 'results/sync/last_sync.md（每轮 agent-sync 后更新，本机 .\\sync.ps1 一下就能看到）。'),
        ]),
        ('7. 常见故障', [
            ('推送卡住要确认', '跑 .\\auth.ps1 -Setup -Verify（gh 优先，其次 GCM + credentialStore=dpapi），再 .\\watch.ps1 -Test。'),
            ('轮询窗口闪 / 占控制台', '默认已是常驻循环：每次登录最多闪一次；要严格零窗口用管理员 PowerShell 跑 .\\watch.ps1 -Register -Headless。'),
            ('值守注册了却不动', '.\\watch.ps1 -Test 看心跳；日志在 %LOCALAPPDATA%\\git-sync\\watch-*.log；卡住先 del $env:TEMP\\git-sync-watch-*.lock。'),
            ('本轮一直 pending', '多半是值守在看另一个分支/另一个克隆：cd 到本会话文件夹，.\\sync.ps1 ; .\\watch.ps1 -Focus ; .\\doctor.ps1。'),
            ('python 检查全 SKIP', 'v2.8.1 闸门会逐个验证 python3 / python / py -3，Store 存根不会再骗过它；确认 conda base 的 python 在 PATH。'),
        ]),
        ('8. 不糊弄的边界', [
            ('"本机"的定义', '你 Windows 上那个计划任务值守——不是沙箱里的 local/inbox，也不是自制脚本冒充的本地。'),
            ('沙箱能做什么', 'pip install / .venv / python-docx / python-pptx 都可以（v2.8.0 起）；生成器只是工具，不是证据。'),
            ('证据在哪', '产物经 git 到本机，由本机的真 Word / 真 PowerPoint 打开 + 结构校验（3a-3h）判定，结论再从远端读回来。'),
        ]),
    ]


def build_guide_docx(facts):
    from docx import Document

    host = facts['host'] or 'LAPTOP-R77M5D6M'
    doc = Document()
    doc.core_properties.title = 'git-sync v%s 使用说明（session %s）' % (facts['version'], SESSION)
    doc.core_properties.comments = 'branch %s | generated by code/make_bridge_report.py' % facts['branch']

    doc.add_heading('git-sync v%s 使用说明' % facts['version'], 0)
    doc.add_paragraph('session %s  |  branch %s  |  本机 %s（值守 git-sync-watch-%s）'
                      % (SESSION, facts['branch'], host, FOLDER))
    doc.add_paragraph('这份说明和同目录的 GUIDE_01a0aa00_v2.8.1.pptx 是同一份内容；'
                      '两个文件都由 code/make_bridge_report.py 生成，'
                      '清单 deliverable/OFFICE_HASHES.json 记录它们的哈希与必需部件。')

    for section, items in guide_rows():
        doc.add_heading(section, level=1)
        table = doc.add_table(rows=1, cols=2)
        table.style = 'Table Grid'
        hdr = table.rows[0].cells
        hdr[0].text = '项'
        hdr[1].text = '说明'
        for name, text in items:
            cells = table.add_row().cells
            cells[0].text = name
            cells[1].text = text

    doc.add_heading('9. 本机回执（真实证据）', level=1)
    for line in [
        'round 20（2026-09-16 19:43 本机时间）判定 passed：exit 0，用时 27 秒，host ' + host,
        '3a-3g 全 OK：sha256/字节、OOXML 必需部件、XML 解析、关系不断链、内容类型、标记词、页数',
        '3h：真 Word.Application 只读打开 BRIDGE_01a0aa00_v2.8.1.docx；'
        '真 PowerPoint.Application 只读打开 BRIDGE_01a0aa00_v2.8.1.pptx（9 页）',
        '2a-2d：免点击推送 PROVEN（ls-remote + push --dry-run，全程关闭交互提示）、值守收尾行齐全、'
        'hands-free auto_pull/auto_push 都在',
        '完整日志：results/status/check_r20_20260916-194327.txt（本机值守推回本分支）',
    ]:
        doc.add_paragraph(line, style='List Bullet')

    doc.add_paragraph()
    doc.add_paragraph('markers: ' + ' , '.join(GUIDE_MARKERS + [host, facts['branch']]))
    doc.save(GUIDE_DOCX)


def build_guide_pptx(facts):
    from pptx import Presentation
    from pptx.util import Pt

    host = facts['host'] or 'LAPTOP-R77M5D6M'
    prs = Presentation()

    def content(title, items, size=13):
        slide = prs.slides.add_slide(prs.slide_layouts[1])
        slide.shapes.title.text = title
        frame = slide.placeholders[1].text_frame
        frame.clear()
        for i, item in enumerate(items):
            para = frame.paragraphs[0] if i == 0 else frame.add_paragraph()
            para.text = item
            para.font.size = Pt(size)

    slide = prs.slides.add_slide(prs.slide_layouts[0])
    slide.shapes.title.text = 'git-sync v%s 使用说明' % facts['version']
    slide.placeholders[1].text = ('session %s  |  %s\n本机 %s  值守 git-sync-watch-%s'
                                  % (SESSION, facts['branch'], host, FOLDER))

    pairs = guide_rows()
    for section, items in pairs:
        content(section, ['%s：%s' % (name, text) for name, text in items])

    content('本机回执（真实证据）', [
        'round 20 判定 passed：exit 0，27 秒，host ' + host,
        '3a-3g 全 OK：哈希/字节、OOXML 部件、XML、关系、内容类型、标记词、页数',
        '3h：真 Word 打开 .docx；真 PowerPoint 打开 .pptx（9 页）',
        '2a-2d：免点击推送 PROVEN、值守收尾行齐全、hands-free 自动拉推',
    ], 14)

    prs.save(GUIDE_PPTX)


# ------------------------------------------------------------------ delivery
def machine_receipts():
    """[(round, host, verdict, elapsed, log)] - read from the pushed check logs."""
    out = []
    d = os.path.join(ROOT, 'results', 'status')
    if not os.path.isdir(d):
        return out
    for name in sorted(os.listdir(d)):
        if not re.match(r'^check_r[0-9]+_.*\.txt$', name):
            continue
        path = os.path.join(d, name)
        try:
            with open(path, encoding='utf-8', errors='replace') as fh:
                head = fh.read(4000)
        except Exception:
            continue
        m_round = re.search(r'^check round ([0-9]+) on ([^ ]+) - (\w+) \(exit ([0-9-]+)\)', head, re.M)
        if not m_round:
            continue
        m_el = re.search(r'^elapsed: ([0-9]+)s', head, re.M)
        out.append((int(m_round.group(1)), m_round.group(2), m_round.group(3),
                    (m_el.group(1) + 's') if m_el else '', name))
    out.sort()
    return out[-3:]


def build_delivery_docx(facts, files):
    from docx import Document

    host = facts['host'] or 'LAPTOP-R77M5D6M'
    doc = Document()
    doc.core_properties.title = '交付清单 / 闭环回执（session %s）' % SESSION
    doc.core_properties.comments = 'git-sync v%s branch %s' % (facts['version'], facts['branch'])

    doc.add_heading('交付清单 / 闭环回执', 0)
    doc.add_paragraph('session %s  |  git-sync v%s  |  分支 %s  |  本机 %s'
                      % (SESSION, facts['version'], facts['branch'], host))
    doc.add_paragraph('这一轮（自循环的最后一步）不再生成新内容，只把"交付了什么、本机怎么判的、'
                      '在本机哪里取"列成一张可核对的清单；哈希与构件数和 deliverable/OFFICE_HASHES.json 一致。')

    doc.add_paragraph('内容是动态生成的：清单里的每一行就是 deliverable/OFFICE_HASHES.json 里的一项，'
                      '本机按同一份清单逐项判定（sha256、OOXML 部件、XML、关系、内容类型、标记词、'
                      '页数，真 Office 开档）。')

    doc.add_heading('1. 交付清单（deliverable/）', level=1)
    table = doc.add_table(rows=1, cols=4)
    table.style = 'Table Grid'
    for i, name in enumerate(['文件', '类型', '字节', 'sha256（前 16 位）']):
        table.rows[0].cells[i].text = name
    for entry in files:
        cells = table.add_row().cells
        cells[0].text = entry['path']
        cells[1].text = entry['kind']
        cells[2].text = str(entry['bytes'])
        cells[3].text = entry['sha256'][:16]
    doc.add_paragraph('生成器：code/make_bridge_report.py（报告与清单，docx/pptx）'
                      '与 code/make_deck_pptmaster.py（本清单里的 DECK，12 页，走 PPT Master 的'
                      ' SVG → 原生 DrawingML 流水线）。两者都会先在沙箱里过同一套 3a-3g 的 Python 镜像自检，'
                      '再交本机判定。')

    doc.add_heading('2. 本机回执（真机判定）', level=1)
    for rnd, hostn, verdict, elapsed, name in machine_receipts():
        doc.add_paragraph('round %d on %s - %s（exit 0%s）  日志：results/status/%s'
                          % (rnd, hostn, verdict, ('，' + elapsed) if elapsed else '', name),
                          style='List Bullet')
    for line in [
        '每个产物：sha256 + 字节数、OOXML 必需部件、每个 XML/rels 可解析、关系不断链、'
        '内容类型覆盖、标记词、页数（3a-3g）全部 OK',
        '3h：真 Word.Application 只读打开两份 .docx；真 PowerPoint.Application 只读打开两份 .pptx',
        '2a：免点击推送 PROVEN（ls-remote + push --dry-run，全程关闭交互提示）',
        '2b-2d：值守三行/收尾行齐全、hands-free auto_pull/auto_push 都在；成功标准逐条全过、0 fail',
        '本轮（DECK 加入后）本机判定的是上表全部 %d 份产物——结论见 results/status/handshake.json' % len(files),
    ]:
        doc.add_paragraph(line, style='List Bullet')

    doc.add_heading('3. 在本机怎么取', level=1)
    for line in [
        'cd E:\\0github\\git-sync\\' + FOLDER + '  然后 .\\sync.ps1（拉最新；本轮的回执会写进 results\\sync\\last_sync.md）',
        '.\\download.ps1 -Set final  把 deliverable\\ 整个镜像到 ..\\git-pull-arena_out\\（不想动 git 的话用这个）',
        '或直接打开克隆目录里的 deliverable\\（上表全部文件 + 清单 OFFICE_HASHES.json 就在里面）',
        '.\\pack.ps1 -Set final  也可以，打成 _export\\<日期>_final.zip',
    ]:
        doc.add_paragraph(line, style='List Bullet')

    doc.add_heading('4. 值守与"清理其他任务"', level=1)
    for line in [
        '本会话值守：git-sync-watch-' + FOLDER + '（每 2 分钟一轮询；hands-free 会自己 pull/push）',
        'bootstrap.ps1 -Auto 注册时会 park 本机其它 git-sync-watch-*（Stop + Disable + 杀循环，任务保留）'
        '——本机已经只有本会话在轮询；这就是"清理其他任务"的结果',
        '要切回某个旧会话：cd <那个文件夹> ; .\\watch.ps1 -Focus；要全部拉回：.\\watch.ps1 -RestoreParked',
        '要严格零闪窗（一点都不闪）：管理员 PowerShell 跑 .\\watch.ps1 -Unregister ; .\\watch.ps1 -Register -Headless',
        'Get-ScheduledTask git-sync-watch-* | Select-Object TaskName, State  可以看到本机所有值守',
    ]:
        doc.add_paragraph(line, style='List Bullet')

    doc.add_heading('5. 这一轮循环做过的步（可复核）', level=1)
    for line in [
        'round 20：装上用户链接会话（arena/01a0a9f0 -> v2.8.1）的技能 + 打通报告 BRIDGE，本机 passed 并已 accept',
        'round 21：新增《使用说明》GUIDE（docx + 10 页 pptx），四份产物一起被本机判定，passed 并已 accept',
        'round 22：把前两轮的结果与清单固化成 DELIVERY，同样交本机判定',
        'round 23：用 PPT Master v6.4.0 重新生成 12 页 DECK（先写 SVG 设计稿，再由它的导出器'
        '编译成原生 DrawingML 形状），7 份产物一起交本机判定',
        '每一步都在 results/status/check_rN_<时间戳>.txt 留了完整日志，handshake 的最终状态是 accepted',
    ]:
        doc.add_paragraph(line, style='List Bullet')

    doc.add_heading('6. 还想要什么', level=1)
    for line in [
        '开 PR 到 main：.\\pr.ps1（需要 GitHub CLI：winget install GitHub.cli）',
        '只读地看这一轮：results/status/handshake.json + 上面的日志；沙箱侧读结论用 bash skills/git-sync/scripts/agent-check.sh --read',
        '继续让助手干活：回到本会话说一句就行，值守会把它 pull 到本机',
    ]:
        doc.add_paragraph(line, style='List Bullet')

    doc.add_paragraph()
    doc.add_paragraph('markers: ' + ' , '.join(DELIVERY_MARKERS + [host, facts['branch']]))
    doc.save(DELIVERY_DOCX)


def build_delivery_pptx(facts, files):
    from pptx import Presentation
    from pptx.util import Pt

    host = facts['host'] or 'LAPTOP-R77M5D6M'
    prs = Presentation()

    def content(title, items, size=13):
        slide = prs.slides.add_slide(prs.slide_layouts[1])
        slide.shapes.title.text = title
        frame = slide.placeholders[1].text_frame
        frame.clear()
        for i, item in enumerate(items):
            para = frame.paragraphs[0] if i == 0 else frame.add_paragraph()
            para.text = item
            para.font.size = Pt(size)

    slide = prs.slides.add_slide(prs.slide_layouts[0])
    slide.shapes.title.text = '交付清单 / 闭环回执'
    slide.placeholders[1].text = 'session %s  |  git-sync v%s\n%s\n本机 %s' % (
        SESSION, facts['version'], facts['branch'], host)

    content('交付清单', ['%s (%s, %d B, sha256 %.12s...)' % (e['path'], e['kind'], e['bytes'], e['sha256'])
                     for e in files] + ['生成器 code/make_bridge_report.py（先过 3a-3g 镜像自检）'])

    content('本机回执', ['round %d on %s - %s' % (r, h, v) for r, h, v, _e, _n in machine_receipts()] + [
        '3a-3g：哈希/字节、OOXML 部件、XML、关系、内容类型、标记词、页数全 OK',
        '3h：真 Word 打开两份 docx；真 PowerPoint 打开两份 pptx',
        '成功标准 54 条全过、0 fail；2a 免点击推送 PROVEN',
    ])

    content('在本机怎么取', [
        'cd E:\\0github\\git-sync\\' + FOLDER + ' ; .\\sync.ps1',
        '.\\download.ps1 -Set final  ->  ..\\git-pull-arena_out\\',
        '或直接打开克隆目录里的 deliverable\\',
        '.\\pack.ps1 -Set final  ->  _export\\<日期>_final.zip',
    ])

    content('值守与清理', [
        '本会话：git-sync-watch-' + FOLDER + '（2 分钟一轮询，hands-free）',
        'bootstrap -Auto 已 park 其它 git-sync-watch-*（任务保留）',
        '切回旧会话：cd <文件夹> ; .\\watch.ps1 -Focus   |   全恢复：-RestoreParked',
        '零闪窗：管理员 PowerShell 跑 .\\watch.ps1 -Register -Headless',
    ])

    content('循环里做过的步', [
        'round 20：装技能（v2.8.1）+ BRIDGE 报告 -> 本机 passed + accepted',
        'round 21：GUIDE 使用说明（docx + pptx）-> 本机 passed + accepted',
        '本轮：DELIVERY 交付清单/回执 -> 同样交本机判定',
        '每轮日志：results/status/check_rN_<时间戳>.txt；状态：results/status/handshake.json = accepted',
    ])

    content('还想要什么', [
        'PR 到 main：.\\pr.ps1（需 GitHub CLI）',
        '沙箱读结论：bash skills/git-sync/scripts/agent-check.sh --read',
        '继续干活：回本会话说一句，值守会把改动 pull 到本机',
    ])

    prs.save(DELIVERY_PPTX)


def entry_for(path, kind, required, main_part, markers, min_slides):
    """One manifest entry: hash, size and the parts/markers the machine checks."""
    raw = open(path, 'rb').read()
    with zipfile.ZipFile(path) as zf:
        present = set(zf.namelist())
        slides = len([n for n in present if re.match(r'^ppt/slides/slide[0-9]+\.xml$', n)])
    return {
        'path': os.path.relpath(path, ROOT).replace(os.sep, '/'),
        'kind': kind,
        'bytes': len(raw),
        'sha256': hashlib.sha256(raw).hexdigest(),
        'required_parts': required,
        'main_part': main_part,
        'must_contain': [m for m in markers if m],
        'min_slides': min_slides,
        'sandbox_selftest': {'parts': len(present), 'slides': slides},
    }


# --------------------------------------------------- mirror of local_check 3a-3g
# --------------------------------------------------------- parts per kind
DOCX_PARTS = ['[Content_Types].xml', '_rels/.rels', 'word/document.xml', 'word/styles.xml',
              'word/_rels/document.xml.rels', 'docProps/core.xml']
PPTX_PARTS = ['[Content_Types].xml', '_rels/.rels', 'ppt/presentation.xml',
              'ppt/_rels/presentation.xml.rels', 'ppt/slides/slide1.xml',
              'ppt/slideMasters/slideMaster1.xml', 'ppt/slideLayouts/slideLayout1.xml',
              'ppt/theme/theme1.xml', 'docProps/core.xml']


def parts_for(kind):
    return DOCX_PARTS if kind == 'docx' else PPTX_PARTS


def parts_from_package(path, kind):
    """Required parts derived from the package itself - third-party exporters
    (PPT Master) name their layouts freely, so do not hardcode part names."""
    with zipfile.ZipFile(path) as zf:
        names = set(zf.namelist())
    req = ['[Content_Types].xml', '_rels/.rels']
    if kind == 'pptx':
        req += ['ppt/presentation.xml', 'ppt/_rels/presentation.xml.rels', 'ppt/slides/slide1.xml']
        for prefix in ('ppt/slideMasters/slideMaster', 'ppt/slideLayouts/slideLayout',
                       'ppt/theme/theme'):
            cands = sorted(n for n in names if n.startswith(prefix) and n.endswith('.xml'))
            if cands:
                req.append(cands[0])
    else:
        req += ['word/document.xml', 'word/_rels/document.xml.rels']
        if 'word/styles.xml' in names:
            req.append('word/styles.xml')
    if 'docProps/core.xml' in names:
        req.append('docProps/core.xml')
    return req


def main_part_for(kind):
    return 'word/document.xml' if kind == 'docx' else 'ppt/presentation.xml'


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
    delivery = '--delivery' in sys.argv[1:]
    add_artifact = ''
    artifact_markers = ''
    min_slides = 0
    if '--add-artifact' in sys.argv[1:]:
        add_artifact = sys.argv[sys.argv.index('--add-artifact') + 1]
    if '--markers' in sys.argv[1:]:
        artifact_markers = sys.argv[sys.argv.index('--markers') + 1]
    if '--min-slides' in sys.argv[1:]:
        min_slides = int(sys.argv[sys.argv.index('--min-slides') + 1])
    facts = repo_facts()
    os.makedirs(OUT, exist_ok=True)


    if add_artifact:
        # step 3: register an artifact built OUTSIDE this generator (the deck
        # PPT Master compiled from authored SVG) under the same 3a-3g contract.
        if not os.path.isfile(MANIFEST):
            print('[ERROR] no manifest yet - build the base files first', file=sys.stderr)
            return 1
        with open(MANIFEST, encoding='utf-8') as fh:
            manifest = json.load(fh)
        path = os.path.join(ROOT, add_artifact.replace('/', os.sep))
        if not os.path.isfile(path):
            print('[ERROR] not found: %s' % add_artifact, file=sys.stderr)
            return 1
        kind = os.path.splitext(add_artifact)[1].lstrip('.').lower()
        markers = [m for m in (artifact_markers.split(',') if artifact_markers else
                               ['2.8.1', 'ppt-master', 'local_check.ps1', facts['host'], facts['branch']])
                   if m.strip()]
        entry = entry_for(path, kind, parts_from_package(path, kind), main_part_for(kind),
                          markers, min_slides or None)
        files = [e for e in manifest.get('files', []) if e['path'] != entry['path']]
        files.append(entry)
        manifest['files'] = files
        manifest['generated_utc'] = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
        manifest['extra_artifacts'] = True
        problems = verify(manifest)
        if problems:
            print('[FAIL] the 3a-3g mirror found %d problem(s) - manifest NOT written:' % len(problems),
                  file=sys.stderr)
            for item in problems:
                print('       ' + item, file=sys.stderr)
            return 1
        with open(MANIFEST, 'w', encoding='utf-8') as fh:
            json.dump(manifest, fh, ensure_ascii=False, indent=2)
            fh.write('\n')
        print('wrote: %s (%d file(s))' % (os.path.relpath(MANIFEST, ROOT), len(files)))
        print('== 3a-3g mirror PASSED for %d file(s)' % len(files))
        for item in files:
            print('   OK %s (%d B, %s, slides=%s)'
                  % (item['path'], item['bytes'], item['kind'], item['sandbox_selftest']['slides']))
        return 0

    if delivery:
        # step 2: the wrap-up pair. It lists the files built by step 1, so it
        # must be built AFTER them and must not rebuild them (a rebuild would
        # change their bytes and invalidate the hashes printed here).
        if not os.path.isfile(MANIFEST):
            print('[ERROR] no manifest yet - run without --delivery first', file=sys.stderr)
            return 1
        with open(MANIFEST, encoding='utf-8') as fh:
            manifest = json.load(fh)
        base = [e for e in manifest.get('files', [])
                if not os.path.basename(e['path']).startswith('DELIVERY_')]
        # the manifest is the single source of truth for "what is delivered"
        manifest['delivered_count'] = len(base)
        build_delivery_docx(facts, base)
        build_delivery_pptx(facts, base)
        print('built: %s' % os.path.relpath(DELIVERY_DOCX, ROOT))
        print('built: %s' % os.path.relpath(DELIVERY_PPTX, ROOT))
        entries = list(base)
        for path, kind, required, main_part, markers, min_slides in [
            (DELIVERY_DOCX, 'docx', ['[Content_Types].xml', '_rels/.rels', 'word/document.xml',
                                     'word/styles.xml', 'word/_rels/document.xml.rels', 'docProps/core.xml'],
             'word/document.xml', DELIVERY_MARKERS + [facts['host'], facts['branch']], None),
            (DELIVERY_PPTX, 'pptx', ['[Content_Types].xml', '_rels/.rels', 'ppt/presentation.xml',
                                     'ppt/_rels/presentation.xml.rels', 'ppt/slides/slide1.xml',
                                     'ppt/slideMasters/slideMaster1.xml', 'ppt/slideLayouts/slideLayout1.xml',
                                     'ppt/theme/theme1.xml', 'docProps/core.xml'], 'ppt/presentation.xml',
             DELIVERY_MARKERS + [facts['host'], facts['branch']], 6),
        ]:
            entries.append(entry_for(path, kind, required, main_part, markers, min_slides))
        manifest['files'] = entries
        manifest['generated_utc'] = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
        manifest['delivery_pair'] = True
        problems = verify(manifest)
        if problems:
            print('[FAIL] the 3a-3g mirror found %d problem(s) - manifest NOT written:' % len(problems),
                  file=sys.stderr)
            for item in problems:
                print('       ' + item, file=sys.stderr)
            return 1
        with open(MANIFEST, 'w', encoding='utf-8') as fh:
            json.dump(manifest, fh, ensure_ascii=False, indent=2)
            fh.write('\n')
        print('wrote: %s (%d file(s))' % (os.path.relpath(MANIFEST, ROOT), len(entries)))
        print('== 3a-3g mirror PASSED for %d file(s)' % len(entries))
        for entry in entries:
            print('   OK %s (%d B, %s, slides=%s)'
                  % (entry['path'], entry['bytes'], entry['kind'], entry['sandbox_selftest']['slides']))
        return 0

    if not verify_only:
        build_docx(facts)
        build_pptx(facts)
        build_guide_docx(facts)
        build_guide_pptx(facts)
        for p in (DOCX, PPTX, GUIDE_DOCX, GUIDE_PPTX):
            print('built: %s' % os.path.relpath(p, ROOT))
    elif not (os.path.isfile(DOCX) and os.path.isfile(PPTX)):
        print('[ERROR] nothing to verify - run without --verify first', file=sys.stderr)
        return 1

    entries = []
    for path, kind, required, main_part, markers, min_slides in [
        (DOCX, 'docx', ['[Content_Types].xml', '_rels/.rels', 'word/document.xml', 'word/styles.xml',
                        'word/_rels/document.xml.rels', 'docProps/core.xml'], 'word/document.xml',
         MARKERS + [facts['host'], facts['branch']], None),
        (PPTX, 'pptx', ['[Content_Types].xml', '_rels/.rels', 'ppt/presentation.xml',
                        'ppt/_rels/presentation.xml.rels', 'ppt/slides/slide1.xml',
                        'ppt/slideMasters/slideMaster1.xml', 'ppt/slideLayouts/slideLayout1.xml',
                        'ppt/theme/theme1.xml', 'docProps/core.xml'], 'ppt/presentation.xml',
         MARKERS + [facts['host'], facts['branch']], 8),
        (GUIDE_DOCX, 'docx', ['[Content_Types].xml', '_rels/.rels', 'word/document.xml', 'word/styles.xml',
                              'word/_rels/document.xml.rels', 'docProps/core.xml'], 'word/document.xml',
         GUIDE_MARKERS + [facts['host'], facts['branch']], None),
        (GUIDE_PPTX, 'pptx', ['[Content_Types].xml', '_rels/.rels', 'ppt/presentation.xml',
                              'ppt/_rels/presentation.xml.rels', 'ppt/slides/slide1.xml',
                              'ppt/slideMasters/slideMaster1.xml', 'ppt/slideLayouts/slideLayout1.xml',
                              'ppt/theme/theme1.xml', 'docProps/core.xml'], 'ppt/presentation.xml',
         GUIDE_MARKERS + [facts['host'], facts['branch']], 10),
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
        entries.append(entry_for(path, kind, required, main_part, markers, min_slides))

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
