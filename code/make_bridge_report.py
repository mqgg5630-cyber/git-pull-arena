#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""make_bridge_report.py - build the real Office deliverables for this session.

Pure standard library on purpose:
  * no python-docx / python-pptx (pip is PEP-668 blocked in the Arena sandbox),
  * no .venv (the git-sync rules forbid a venv standing in for the local machine),
  * deterministic output (fixed ZIP timestamps) so the SHA-256 recorded in
    deliverable/OFFICE_HASHES.json is reproducible and code/local_check.ps1 can
    prove on the REAL machine that what arrived through git is byte-identical
    to what was generated here, and that both packages are well-formed OOXML.

Usage:
    python3 code/make_bridge_report.py            # writes deliverable/*
    python3 code/make_bridge_report.py --selftest # also re-open and validate

Everything travels to the user's machine through the git working branch only.
This script has no network access and never pretends to be the local side.
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
import zipfile
from xml.sax.saxutils import escape

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(REPO_ROOT, "deliverable")

DOCX_NAME = "BRIDGE_REPORT_v2.7.4.docx"
PPTX_NAME = "BRIDGE_REPORT_v2.7.4.pptx"
HASH_NAME = "OFFICE_HASHES.json"

# deterministic ZIP timestamps -> reproducible sha256
ZIP_TIME = (2026, 9, 16, 10, 30, 0)

NS_W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
NS_A = "http://schemas.openxmlformats.org/drawingml/2006/main"
NS_P = "http://schemas.openxmlformats.org/presentationml/2006/main"
NS_R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
NS_REL = "http://schemas.openxmlformats.org/package/2006/relationships"
NS_CT = "http://schemas.openxmlformats.org/package/2006/content-types"
NS_CP = "http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
NS_DC = "http://purl.org/dc/elements/1.1/"
NS_DCT = "http://purl.org/dc/terms/"
NS_XSI = "http://www.w3.org/2001/XMLSchema-instance"
NS_EP = "http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"
NS_VT = "http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"

RT_OFFDOC = NS_R + "/officeDocument"
RT_CORE = "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"
RT_EXT = NS_R + "/extendedProperties"
RT_STYLES = NS_R + "/styles"
RT_THEME = NS_R + "/theme"
RT_SLIDE = NS_R + "/slide"
RT_SLIDE_MASTER = NS_R + "/slideMaster"
RT_SLIDE_LAYOUT = NS_R + "/slideLayout"

CT_DOC_MAIN = "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"
CT_DOC_STYLES = "application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"
CT_PML_PRES = "application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"
CT_PML_MASTER = "application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"
CT_PML_LAYOUT = "application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"
CT_PML_SLIDE = "application/vnd.openxmlformats-officedocument.presentationml.slide+xml"
CT_THEME = "application/vnd.openxmlformats-officedocument.theme+xml"
CT_CORE = "application/vnd.openxmlformats-package.core-properties+xml"
CT_EXT = "application/vnd.openxmlformats-officedocument.extended-properties+xml"

CREATED = "2026-09-16T10:30:00Z"

# --------------------------------------------------------------------------
# the facts of this session (all of them were produced by real commands)
# --------------------------------------------------------------------------

FACTS = [
    ("技能版本", "v2.7.4（skills/git-sync/VERSION）"),
    ("技能来源", "https://github.com/mqgg5630-cyber/git-pull-arena.git 分支 arena/01a0a821-git-pull-arena，tip 6c25969"),
    ("本会话分支", "arena/01a0a9ba-git-pull-arena"),
    ("树比对", "diff -rq 对源分支逐字节一致，唯一差异是 sync.config.json 的 branch"),
    ("gate", "bash code/check_all.sh 退出 0：.ps1 全 ASCII / 分支守卫 / 根目录与 skill 镜像一致 / $var: 陷阱扫描"),
    ("成功标准", "agent-criteria.sh PASSED，17 ok / 0 fail"),
    ("提交", "0a2dcf9 安装技能；f9efc0a 请求第 20 轮检查"),
    ("本机回传", "round 20 arena=awaiting_check / local=passed，host LAPTOP-R77M5D6M"),
    ("时间戳", "arena_updated 2026-09-16 10:24:17 UTC；local_updated 2026-09-16 18:27:00（本机 UTC+8）"),
]

HARDWARE = [
    ("主机 / 用户", "LAPTOP-R77M5D6M / 文少"),
    ("操作系统", "Microsoft Windows 11 专业版（build 26200）"),
    ("CPU", "Intel Core i5-10200H @ 2.40GHz，4 核 / 8 线程"),
    ("内存", "15.9 GB 总量，5.6 GB 空闲"),
    ("GPU", "NVIDIA GeForce GTX 1650，4 GB 显存，驱动 576.02，compute cap 7.5，CUDA driver 12.9"),
    ("磁盘", "C: 100 GB（剩 49.1）；D: 137.2 GB（剩 29.7）；E: 715.4 GB（剩 181.3）"),
    ("Python / conda", "global python 3.11.9（E:\\spider\\python.exe）；conda 25.3.1；mamba 2.0.5"),
    ("报告生成", "2026-09-15 09:33:51 本机时间，由 hardware.ps1 采集"),
]

DEFECT = [
    "agent-install.sh 的 DEFAULT_SOURCE_BRANCHES=(\"main\" \"arena/01a0a821-git-pull-arena\")，main 排在前面。",
    "照文档那条 one-liner 直接跑，安装器从 main 取到 v2.6.7，并先 rm -rf skills/git-sync 再覆盖。",
    "后果：静默降级，11 个 v2.7.4 独有文件被删除（agent-handsfree.sh、agent-criteria.sh、"
    "templates/one-sentence.md、task-loop.md、connect-local.ps1、USER_PROMPT.md 等）。",
    "处置：改用 --source /tmp/git-sync-src 指回 arena 分支重装，拿到 v2.7.4；"
    "sync.config.json 因安装器先读 OLD_CFG_B64 而完整保留，只有 branch 被改写到本会话分支。",
    "建议修复：把 arena 分支排到 main 之前，或让安装器比对 VERSION 拒绝降级。",
]

LOOP = [
    "agent-handsfree.sh --sync \"...\" --request \"verify: ...\" --timeout auto",
    "第 1 步 agent-sync.sh：分支守卫 → fetch → 发散自愈 → gate → 写回执 → commit + push",
    "第 2/3 步 agent-check.sh --request（round+1）→ agent-wait.sh 轮询，本机值守一回传就返回",
    "第 4 步 agent-criteria.sh 读 results/status/success_criteria.json",
    "第 5 步 全过则 agent-check.sh --accept，循环收尾；退出 0",
    "退出 2 = 本机判失败或标准未达：读 results/status/check_rN_*.txt，修完 round+1 再来",
    "退出 3 = 本机值守不在：重贴 clone + bootstrap 的 PowerShell，禁止改口说沙箱 local/ 已打通",
    "上限：最多认真修 5 轮，第 5 轮仍失败就把日志与缺项交给用户，不空转",
]

DELIVERABLES = [
    ("deliverable/" + DOCX_NAME, "本验收报告（Word）"),
    ("deliverable/" + PPTX_NAME, "同内容的汇报幻灯片（PowerPoint）"),
    ("deliverable/" + HASH_NAME, "两份 Office 文件的 SHA-256 / 字节数 / 必需部件 / 必含字符串"),
    ("code/make_bridge_report.py", "生成器：纯标准库，确定性输出，无网络"),
    ("code/local_check.ps1", "本机侧检查：OOXML 结构 + SHA-256 完整性 + 可选 Office COM 开档"),
    ("results/status/success_criteria.json", "机读的成功标准，本机与助手侧跑同一份"),
]

SLIDES = [
    ("title", "git-sync v2.7.4 本机打通验收",
     ["Arena 会话分支 arena/01a0a9ba-git-pull-arena",
      "技能来源分支 arena/01a0a821-git-pull-arena（tip 6c25969）",
      "生成时间 2026-09-16 10:30 UTC · 纯标准库生成，确定性输出"]),
    ("bullets", "结论：本机已真打通",
     ["round 20 本机回传 local_state = passed，host = LAPTOP-R77M5D6M",
      "证据链：git clone → bootstrap -Auto → watch.ps1 -Register → 值守自动检查 → 静默 push 回分支",
      "不是沙箱 local/inbox，不是 python 复刻，不是 .venv 冒充本机",
      "本机时间 2026-09-16 18:27:00（UTC+8）= arena 请求后约 3 分钟"]),
    ("bullets", "安装记录",
     ["技能版本 v2.7.4，源分支 arena/01a0a821-git-pull-arena",
      "diff -rq 与源分支逐字节一致，唯一差异是 sync.config.json 的 branch",
      "根目录 12 个 .ps1 齐备，含 watch.ps1（83666 B）与 auth.ps1",
      "配置保留：hands_free / auto_pull / auto_push = true，gate = bash code/check_all.sh",
      "提交 0a2dcf9（安装）、f9efc0a（请求第 20 轮检查）"]),
    ("bullets", "发现的缺陷：安装器会静默降级",
     ["DEFAULT_SOURCE_BRANCHES 把 main 排在 arena 分支之前",
      "照文档 one-liner 跑 → 从 main 取到 v2.6.7 → rm -rf 后覆盖",
      "11 个 v2.7.4 独有文件被删（agent-handsfree.sh、one-sentence.md 等）",
      "处置：--source 指回 arena 分支重装；配置因 OLD_CFG_B64 未丢",
      "建议：调换默认顺序，或安装器比对 VERSION 拒绝降级"]),
    ("bullets", "校验结果",
     ["gate bash code/check_all.sh 退出 0",
      ".ps1 全 ASCII / 分支守卫 / 根目录与 skill 脚本镜像一致 / $var: 盘符陷阱扫描通过",
      "agent-criteria.sh PASSED：17 ok / 0 fail",
      "PowerShell 不在沙箱 PATH，.ps1 语法解析项按设计 SKIP，由本机侧补做"]),
    ("table", "本机环境（hardware.ps1 上报）",
     ["主机 LAPTOP-R77M5D6M · Windows 11 专业版 build 26200",
      "CPU i5-10200H 4 核 8 线程 · 内存 15.9 GB（空闲 5.6 GB）",
      "GPU GTX 1650 4 GB 显存 · 驱动 576.02 · CUDA driver 12.9",
      "磁盘 E: 715.4 GB 剩 181.3 GB · python 3.11.9 · conda 25.3.1"]),
    ("bullets", "自循环协议（本机即验证机）",
     ["一条命令：agent-handsfree.sh --sync --request --timeout auto",
      "流程：sync → request（round+1）→ wait 值守 → criteria → 全过则 accept",
      "退出 0 收尾 / 2 修复再来一轮 / 3 值守不在则重贴 PowerShell",
      "--timeout auto：结论一到就返回，上限 check_timeout_min×60+180 秒",
      "hands_free 下值守每轮自动 sync + 自动静默 push，用户不必手动同步"]),
    ("bullets", "本轮交付物",
     ["deliverable/BRIDGE_REPORT_v2.7.4.docx（本报告）",
      "deliverable/BRIDGE_REPORT_v2.7.4.pptx（本幻灯片）",
      "deliverable/OFFICE_HASHES.json（SHA-256 / 字节数 / 必需部件）",
      "code/make_bridge_report.py（纯标准库生成器，可复现）",
      "code/local_check.ps1 第 3 节（本机真校验）+ success_criteria.json"]),
    ("bullets", "下一步",
     ["本机侧：.\\download.ps1 -Set final 取回 deliverable（或直接看克隆目录）",
      "值守会自动跑第 21 轮检查：OOXML 结构 + SHA-256 + 可选 Office 开档",
      "助手侧读 results/status/check_r21_*.txt，全过则 accept 收尾",
      "若要刷新本机硬件报告：.\\hardware.ps1 -Deep"]),
]

DOC_TITLE = "git-sync v2.7.4 本机打通验收报告"
DOC_SUB = ("Arena 会话分支 arena/01a0a9ba-git-pull-arena · 技能源分支 arena/01a0a821-git-pull-arena · "
           "生成于 2026-09-16 10:30 UTC")

MARKERS = ["git-sync", "2.7.4", "LAPTOP-R77M5D6M", "arena/01a0a9ba-git-pull-arena"]


# --------------------------------------------------------------------------
# packaging helpers
# --------------------------------------------------------------------------

def content_types(defaults, overrides):
    parts = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>']
    parts.append('<Types xmlns="%s">' % NS_CT)
    for ext, ct in defaults:
        parts.append('<Default Extension="%s" ContentType="%s"/>' % (ext, ct))
    for name, ct in overrides:
        parts.append('<Override PartName="%s" ContentType="%s"/>' % (name, ct))
    parts.append("</Types>")
    return "".join(parts)


def rels(entries):
    parts = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>']
    parts.append('<Relationships xmlns="%s">' % NS_REL)
    for rid, typ, target in entries:
        parts.append('<Relationship Id="%s" Type="%s" Target="%s"/>' % (rid, typ, target))
    parts.append("</Relationships>")
    return "".join(parts)


def core_props(title, subject):
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="%s" xmlns:dc="%s" xmlns:dcterms="%s" '
        'xmlns:xsi="%s">'
        "<dc:title>%s</dc:title>"
        "<dc:subject>%s</dc:subject>"
        "<dc:creator>Arena Agent</dc:creator>"
        "<cp:lastModifiedBy>Arena Agent</cp:lastModifiedBy>"
        '<cp:revision>1</cp:revision>'
        '<dcterms:created xsi:type="dcterms:W3CDTF">%s</dcterms:created>'
        '<dcterms:modified xsi:type="dcterms:W3CDTF">%s</dcterms:modified>'
        "</cp:coreProperties>" % (NS_CP, NS_DC, NS_DCT, NS_XSI,
                                  escape(title), escape(subject), CREATED, CREATED)
    )


def write_zip(path, entries):
    """entries: list of (arcname, text|bytes)."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for name, payload in entries:
            info = zipfile.ZipInfo(name, date_time=ZIP_TIME)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o600 << 16
            if isinstance(payload, str):
                payload = payload.encode("utf-8")
            z.writestr(info, payload)


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


# --------------------------------------------------------------------------
# DOCX
# --------------------------------------------------------------------------

def w_run(text, bold=False, size=None, color=None):
    rpr = ["<w:rPr>"]
    rpr.append('<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Microsoft YaHei"/>')
    if bold:
        rpr.append("<w:b/>")
    if color:
        rpr.append('<w:color w:val="%s"/>' % color)
    if size:
        rpr.append('<w:sz w:val="%d"/><w:szCs w:val="%d"/>' % (size, size))
    rpr.append("</w:rPr>")
    return "<w:r>%s<w:t xml:space=\"preserve\">%s</w:t></w:r>" % ("".join(rpr), escape(text))


def w_para(text="", style=None, bold=False, size=None, color=None, space_after=120):
    ppr = ["<w:pPr>"]
    if style:
        ppr.append('<w:pStyle w:val="%s"/>' % style)
    ppr.append('<w:spacing w:after="%d" w:line="276" w:lineRule="auto"/>' % space_after)
    ppr.append("</w:pPr>")
    body = w_run(text, bold=bold, size=size, color=color) if text else ""
    return "<w:p>%s%s</w:p>" % ("".join(ppr), body)


def w_bullet(text, level=0):
    ppr = (
        "<w:pPr>"
        '<w:spacing w:after="60" w:line="276" w:lineRule="auto"/>'
        '<w:ind w:left="%d" w:hanging="220"/>' % (360 + level * 360) +
        "</w:pPr>"
    )
    return "<w:p>%s%s%s</w:p>" % (ppr, w_run("\u2022  "), w_run(text))


def w_table(rows, widths):
    out = ["<w:tbl><w:tblPr>"]
    out.append('<w:tblW w:w="%d" w:type="dxa"/>' % sum(widths))
    out.append(
        "<w:tblBorders>"
        '<w:top w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/>'
        '<w:left w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/>'
        '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/>'
        '<w:right w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/>'
        '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/>'
        '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="BFBFBF"/>'
        "</w:tblBorders>"
    )
    out.append('<w:tblCellMar><w:top w:w="60" w:type="dxa"/><w:left w:w="108" w:type="dxa"/>'
               '<w:bottom w:w="60" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tblCellMar>')
    out.append("</w:tblPr><w:tblGrid>")
    for w in widths:
        out.append('<w:gridCol w:w="%d"/>' % w)
    out.append("</w:tblGrid>")
    for ri, row in enumerate(rows):
        out.append("<w:tr>")
        if ri == 0:
            out.append("<w:trPr><w:tblHeader/></w:trPr>")
        for ci, cell in enumerate(row):
            shd = '<w:shd w:val="clear" w:color="auto" w:fill="DEEAF6"/>' if ri == 0 else ""
            out.append("<w:tc><w:tcPr><w:tcW w:w=\"%d\" w:type=\"dxa\"/>%s"
                       '<w:vAlign w:val="center"/></w:tcPr>' % (widths[ci], shd))
            out.append(w_para(cell, bold=(ri == 0), size=20, space_after=0))
            out.append("</w:tc>")
        out.append("</w:tr>")
    out.append("</w:tbl>")
    # a table must be followed by a paragraph or Word complains
    out.append(w_para("", space_after=120))
    return "".join(out)


def docx_styles():
    def style(sid, name, based, size, bold, color, before, after, keepnext=False):
        kn = "<w:keepNext/>" if keepnext else ""
        return (
            '<w:style w:type="paragraph" w:styleId="%s"><w:name w:val="%s"/>'
            '<w:basedOn w:val="%s"/><w:qFormat/><w:pPr>%s'
            '<w:spacing w:before="%d" w:after="%d"/><w:outlineLvl w:val="%d"/></w:pPr>'
            '<w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Microsoft YaHei"/>'
            '%s%s<w:sz w:val="%d"/><w:szCs w:val="%d"/></w:rPr></w:style>'
            % (sid, name, based, kn, before, after,
               {"Title": 0, "Heading1": 0, "Heading2": 1}.get(sid, 9),
               "<w:b/>" if bold else "",
               '<w:color w:val="%s"/>' % color if color else "",
               size, size)
        )

    body = (
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
        '<w:name w:val="Normal"/><w:qFormat/>'
        '<w:pPr><w:spacing w:after="120" w:line="276" w:lineRule="auto"/></w:pPr>'
        '<w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Microsoft YaHei"/>'
        '<w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr></w:style>'
    )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:styles xmlns:w="%s">'
        '<w:docDefaults><w:rPrDefault><w:rPr>'
        '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Microsoft YaHei" w:cs="Times New Roman"/>'
        '<w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="en-US" w:eastAsia="zh-CN"/>'
        "</w:rPr></w:rPrDefault></w:docDefaults>"
        "%s%s%s%s"
        "</w:styles>"
        % (NS_W, body,
           style("Title", "Title", "Normal", 52, True, "1F3864", 0, 240),
           style("Heading1", "heading 1", "Normal", 32, True, "1F4E79", 360, 120, True),
           style("Heading2", "heading 2", "Normal", 26, True, "2E74B5", 240, 80, True))
    )


def docx_document():
    b = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>']
    b.append('<w:document xmlns:w="%s" xmlns:r="%s"><w:body>' % (NS_W, NS_R))

    b.append(w_para(DOC_TITLE, style="Title"))
    b.append(w_para(DOC_SUB, size=20, color="595959", space_after=240))

    b.append(w_para("一、结论", style="Heading1"))
    b.append(w_para("git-sync 技能 v2.7.4 已装进本会话分支，本机打通已由真实回传证明：第 20 轮握手 "
                    "local_state = passed，host = LAPTOP-R77M5D6M。交付物只经 git 工作分支到达本机，"
                    "没有使用沙箱 local/inbox、python 复刻或 .venv 冒充本机。"))

    b.append(w_para("二、安装与校验事实", style="Heading1"))
    b.append(w_table([["项目", "实测结果"]] + [[k, v] for k, v in FACTS], [2200, 7000]))

    b.append(w_para("三、发现的缺陷", style="Heading1"))
    for line in DEFECT:
        b.append(w_bullet(line))

    b.append(w_para("四、本机环境", style="Heading1"))
    b.append(w_table([["项目", "上报值"]] + [[k, v] for k, v in HARDWARE], [2200, 7000]))

    b.append(w_para("五、自循环协议", style="Heading1"))
    for line in LOOP:
        b.append(w_bullet(line))

    b.append(w_para("六、交付物清单", style="Heading1"))
    b.append(w_table([["路径", "说明"]] + [[k, v] for k, v in DELIVERABLES], [4200, 5000]))

    b.append(w_para("七、本机侧如何验真", style="Heading1"))
    b.append(w_para("code/local_check.ps1 第 3 节在本机执行：先比对 OFFICE_HASHES.json 里的 SHA-256 与字节数，"
                    "证明经 git 到达本机的文件与生成时逐字节相同；再以 System.IO.Compression 打开包，"
                    "校验必需部件存在、每个 XML 部件可解析、正文含约定标记字符串；"
                    "PowerPoint 文件另计幻灯片张数。若本机装有 Office，则再用 COM 只读开档一次，"
                    "未安装则记 SKIP 而不是失败。"))

    b.append("<w:sectPr>"
             '<w:pgSz w:w="11906" w:h="16838"/>'
             '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" '
             'w:header="720" w:footer="720" w:gutter="0"/>'
             "</w:sectPr>")
    b.append("</w:body></w:document>")
    return "".join(b)


def build_docx(path):
    doc = docx_document()
    entries = [
        ("[Content_Types].xml", content_types(
            [("rels", "application/vnd.openxmlformats-package.relationships+xml"), ("xml", "application/xml")],
            [("/word/document.xml", CT_DOC_MAIN),
             ("/word/styles.xml", CT_DOC_STYLES),
             ("/docProps/core.xml", CT_CORE),
             ("/docProps/app.xml", CT_EXT)])),
        ("_rels/.rels", rels([
            ("rId1", RT_OFFDOC, "word/document.xml"),
            ("rId2", RT_CORE, "docProps/core.xml"),
            ("rId3", RT_EXT, "docProps/app.xml")])),
        ("word/document.xml", doc),
        ("word/styles.xml", docx_styles()),
        ("word/_rels/document.xml.rels", rels([("rId1", RT_STYLES, "styles.xml")])),
        ("docProps/core.xml", core_props(DOC_TITLE, "git-sync v2.7.4 local bridge acceptance")),
        ("docProps/app.xml",
         '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
         '<Properties xmlns="%s" xmlns:vt="%s">'
         "<Application>Microsoft Office Word</Application><DocSecurity>0</DocSecurity>"
         "<ScaleCrop>false</ScaleCrop><LinksUpToDate>false</LinksUpToDate>"
         "<SharedDoc>false</SharedDoc><HyperlinksChanged>false</HyperlinksChanged>"
         "<AppVersion>16.0000</AppVersion></Properties>" % (NS_EP, NS_VT)),
    ]
    write_zip(path, entries)


# --------------------------------------------------------------------------
# PPTX
# --------------------------------------------------------------------------

SLIDE_W = 12192000   # 16:9
SLIDE_H = 6858000


def a_text_frame(paras, anchor="t", sizes=None, bullet=True):
    """Build a p:txBody. paras: list of paragraphs, each a list of (text, bold).

    Child order follows the PresentationML schema (CT_TextParagraphProperties:
    lnSpc, spcBef, spcAft, buFont, buChar, ..., defRPr) - getting it wrong makes
    PowerPoint report "unreadable content".
    """
    out = ['<p:txBody><a:bodyPr anchor="%s"><a:normAutofit/></a:bodyPr><a:lstStyle/>' % anchor]
    sz = sizes or 1800
    for i, runs in enumerate(paras):
        want_bullet = bullet and not (i == 0 and len(paras) == 1)
        bu = ('<a:buFont typeface="Arial" pitchFamily="34" charset="0"/>'
              '<a:buChar char="\u2022"/>') if want_bullet else "<a:buNone/>"
        indent = ' marL="228600" indent="-228600"' if want_bullet else ' marL="0" indent="0"'
        out.append('<a:p><a:pPr%s><a:spcBef><a:spcPts val="600"/></a:spcBef>%s</a:pPr>'
                   % (indent, bu))
        for text, bold in runs:
            if not text:
                continue
            out.append('<a:r><a:rPr lang="zh-CN" altLang="en-US" sz="%d" b="%d" dirty="0">'
                       '<a:solidFill><a:schemeClr val="tx1"/></a:solidFill>'
                       '<a:latin typeface="Calibri"/><a:ea typeface="Microsoft YaHei"/>'
                       "</a:rPr><a:t>%s</a:t></a:r>" % (sz, 1 if bold else 0, escape(text)))
        out.append('<a:endParaRPr lang="zh-CN" altLang="en-US" sz="%d"/></a:p>' % sz)
    return "".join(out) + "</p:txBody>"


def sp_shape(shape_id, name, ph, x, y, cx, cy, txbody):
    ph_xml = '<p:ph type="%s"%s/>' % (ph["type"], ' idx="%s"' % ph["idx"] if ph.get("idx") else "")
    return (
        "<p:sp><p:nvSpPr>"
        '<p:cNvPr id="%d" name="%s"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>'
        "<p:nvPr>%s</p:nvPr></p:nvSpPr>"
        "<p:spPr><a:xfrm><a:off x=\"%d\" y=\"%d\"/><a:ext cx=\"%d\" cy=\"%d\"/></a:xfrm>"
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>'
        "%s</p:sp>" % (shape_id, escape(name), ph_xml, x, y, cx, cy, txbody)
    )


def sp_tree(inner):
    return (
        "<p:spTree><p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>"
        "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/>"
        "<a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>"
        + inner + "</p:spTree>"
    )


def slide_xml(kind, title, lines):
    if kind == "title":
        body = sp_shape(2, "Title 1", {"type": "ctrTitle"}, 838200, 2171700, 10515600, 1500000,
                        a_text_frame([[(title, True)]], anchor="ctr", sizes=4000, bullet=False))
        body += sp_shape(3, "Subtitle 2", {"type": "subTitle", "idx": "1"},
                         838200, 3800000, 10515600, 1600000,
                         a_text_frame([[(t, False)] for t in lines],
                                      anchor="t", sizes=1800, bullet=False))
    else:
        body = sp_shape(2, "Title 1", {"type": "title"}, 838200, 365125, 10515600, 1143000,
                        a_text_frame([[(title, True)]], anchor="b", sizes=3000, bullet=False))
        body += sp_shape(3, "Content 2", {"type": "body", "idx": "1"},
                         838200, 1600200, 10515600, 4525963,
                         a_text_frame([[(t, False)] for t in lines], anchor="t", sizes=1800))
    return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<p:sld xmlns:a="%s" xmlns:r="%s" xmlns:p="%s"><p:cSld>%s</p:cSld>'
            "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>"
            % (NS_A, NS_R, NS_P, sp_tree(body)))


def theme_xml():
    fills = (
        '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
        '<a:gradFill rotWithShape="1"><a:gsLst>'
        '<a:gs pos="0"><a:schemeClr val="phClr"><a:lumMod val="110000"/><a:satMod val="105000"/>'
        '<a:tint val="67000"/></a:schemeClr></a:gs>'
        '<a:gs pos="50000"><a:schemeClr val="phClr"><a:lumMod val="105000"/><a:satMod val="103000"/>'
        '<a:tint val="73000"/></a:schemeClr></a:gs>'
        '<a:gs pos="100000"><a:schemeClr val="phClr"><a:lumMod val="105000"/><a:satMod val="109000"/>'
        '<a:tint val="81000"/></a:schemeClr></a:gs></a:gsLst>'
        '<a:lin ang="5400000" scaled="0"/></a:gradFill>'
        '<a:gradFill rotWithShape="1"><a:gsLst>'
        '<a:gs pos="0"><a:schemeClr val="phClr"><a:satMod val="103000"/><a:lumMod val="102000"/>'
        '<a:tint val="94000"/></a:schemeClr></a:gs>'
        '<a:gs pos="50000"><a:schemeClr val="phClr"><a:satMod val="110000"/><a:lumMod val="100000"/>'
        '<a:shade val="100000"/></a:schemeClr></a:gs>'
        '<a:gs pos="100000"><a:schemeClr val="phClr"><a:lumMod val="99000"/><a:satMod val="120000"/>'
        '<a:shade val="78000"/></a:schemeClr></a:gs></a:gsLst>'
        '<a:lin ang="5400000" scaled="0"/></a:gradFill>'
    )
    lines = "".join(
        '<a:ln w="%d" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
        "<a:prstDash val=\"solid\"/><a:miter lim=\"800000\"/></a:ln>" % w
        for w in (6350, 12700, 19050)
    )
    effects = "<a:effectStyle><a:effectLst/></a:effectStyle>" * 3
    bgfills = (
        '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
        '<a:gradFill rotWithShape="1"><a:gsLst>'
        '<a:gs pos="0"><a:schemeClr val="phClr"><a:tint val="40000"/><a:satMod val="350000"/></a:schemeClr></a:gs>'
        '<a:gs pos="40000"><a:schemeClr val="phClr"><a:tint val="45000"/><a:shade val="99000"/>'
        '<a:satMod val="350000"/></a:schemeClr></a:gs>'
        '<a:gs pos="100000"><a:schemeClr val="phClr"><a:shade val="20000"/><a:satMod val="255000"/></a:schemeClr>'
        "</a:gs></a:gsLst><a:path path=\"circle\"><a:fillToRect l=\"50000\" t=\"-80000\" r=\"50000\" b=\"180000\"/>"
        "</a:path></a:gradFill>"
        '<a:gradFill rotWithShape="1"><a:gsLst>'
        '<a:gs pos="0"><a:schemeClr val="phClr"><a:tint val="100000"/><a:shade val="100000"/><a:satMod val="130000"/></a:schemeClr></a:gs>'
        '<a:gs pos="50000"><a:schemeClr val="phClr"><a:tint val="50000"/><a:shade val="100000"/><a:satMod val="130000"/></a:schemeClr></a:gs>'
        '<a:gs pos="100000"><a:schemeClr val="phClr"><a:shade val="50000"/><a:satMod val="130000"/></a:schemeClr></a:gs>'
        "</a:gsLst><a:path path=\"circle\"><a:fillToRect l=\"50000\" t=\"50000\" r=\"50000\" b=\"50000\"/></a:path>"
        "</a:gradFill>"
    )
    accents = ["4472C4", "ED7D31", "A5A5A5", "FFC000", "5B9BD5", "70AD47"]
    clr = "".join('<a:accent%d><a:srgbClr val="%s"/></a:accent%d>' % (i + 1, c, i + 1)
                  for i, c in enumerate(accents))
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<a:theme xmlns:a="%s" name="Office Theme"><a:themeElements>'
        '<a:clrScheme name="Office">'
        '<a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>'
        '<a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>'
        '<a:dk2><a:srgbClr val="44546A"/></a:dk2>'
        '<a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>'
        "%s"
        '<a:hlink><a:srgbClr val="0563C1"/></a:hlink>'
        '<a:folHlink><a:srgbClr val="954F72"/></a:folHlink>'
        "</a:clrScheme>"
        '<a:fontScheme name="Office">'
        '<a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface="Microsoft YaHei"/>'
        '<a:cs typeface=""/></a:majorFont>'
        '<a:minorFont><a:latin typeface="Calibri"/><a:ea typeface="Microsoft YaHei"/>'
        '<a:cs typeface=""/></a:minorFont>'
        "</a:fontScheme>"
        '<a:fmtScheme name="Office">'
        "<a:fillStyleLst>%s</a:fillStyleLst>"
        "<a:lnStyleLst>%s</a:lnStyleLst>"
        "<a:effectStyleLst>%s</a:effectStyleLst>"
        "<a:bgFillStyleLst>%s</a:bgFillStyleLst>"
        "</a:fmtScheme>"
        "</a:themeElements><a:objectDefaults/><a:extraClrSchemeLst/></a:theme>"
        % (NS_A, clr, fills, lines, effects, bgfills)
    )


def master_xml(layout_count):
    title_ph = sp_shape(2, "Title Placeholder 1", {"type": "title"},
                        838200, 365125, 10515600, 1143000,
                        a_text_frame([[("", False)]], sizes=4400))
    body_ph = sp_shape(3, "Text Placeholder 2", {"type": "body", "idx": "1"},
                       838200, 1600200, 10515600, 4525963,
                       a_text_frame([[("", False)]], sizes=2800))
    layout_ids = "".join(
        '<p:sldLayoutId id="%d" r:id="rId%d"/>' % (2147483649 + i, i + 1)
        for i in range(layout_count)
    )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:sldMaster xmlns:a="%s" xmlns:r="%s" xmlns:p="%s"><p:cSld>'
        '<p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef></p:bg>'
        "%s</p:cSld>"
        '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" '
        'accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" '
        'hlink="hlink" folHlink="folHlink"/>'
        "<p:sldLayoutIdLst>%s</p:sldLayoutIdLst>"
        "<p:txStyles>"
        '<p:titleStyle><a:lvl1pPr algn="l"><a:defRPr sz="4400" b="1">'
        '<a:solidFill><a:schemeClr val="tx1"/></a:solidFill>'
        '<a:latin typeface="Calibri Light"/><a:ea typeface="Microsoft YaHei"/></a:defRPr></a:lvl1pPr></p:titleStyle>'
        '<p:bodyStyle><a:lvl1pPr marL="228600" indent="-228600"><a:spcBef><a:spcPts val="600"/></a:spcBef>'
        '<a:buFont typeface="Arial" pitchFamily="34" charset="0"/><a:buChar char="\u2022"/>'
        '<a:defRPr sz="1800"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill>'
        '<a:latin typeface="Calibri"/><a:ea typeface="Microsoft YaHei"/></a:defRPr></a:lvl1pPr></p:bodyStyle>'
        '<p:otherStyle><a:lvl1pPr><a:defRPr sz="1800"/></a:lvl1pPr></p:otherStyle>'
        "</p:txStyles></p:sldMaster>"
        % (NS_A, NS_R, NS_P, sp_tree(title_ph + body_ph), layout_ids)
    )


def layout_xml(kind):
    if kind == "title":
        shapes = (
            sp_shape(2, "Title 1", {"type": "ctrTitle"}, 838200, 2171700, 10515600, 1500000,
                     a_text_frame([[("", False)]], anchor="ctr", sizes=4000))
            + sp_shape(3, "Subtitle 2", {"type": "subTitle", "idx": "1"}, 838200, 3800000,
                       10515600, 1600000, a_text_frame([[("", False)]], sizes=1800))
        )
        name, typ = "Title Slide", "title"
    else:
        shapes = (
            sp_shape(2, "Title 1", {"type": "title"}, 838200, 365125, 10515600, 1143000,
                     a_text_frame([[("", False)]], anchor="b", sizes=3000))
            + sp_shape(3, "Content Placeholder 2", {"type": "body", "idx": "1"}, 838200, 1600200,
                       10515600, 4525963, a_text_frame([[("", False)]], sizes=1800))
        )
        name, typ = "Title and Content", "obj"
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:sldLayout xmlns:a="%s" xmlns:r="%s" xmlns:p="%s" type="%s" preserve="1">'
        '<p:cSld name="%s">%s</p:cSld>'
        "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>"
        % (NS_A, NS_R, NS_P, typ, escape(name), sp_tree(shapes))
    )


def build_pptx(path):
    n = len(SLIDES)
    entries = []

    overrides = [("/ppt/presentation.xml", CT_PML_PRES),
                 ("/ppt/slideMasters/slideMaster1.xml", CT_PML_MASTER),
                 ("/ppt/slideLayouts/slideLayout1.xml", CT_PML_LAYOUT),
                 ("/ppt/slideLayouts/slideLayout2.xml", CT_PML_LAYOUT),
                 ("/ppt/theme/theme1.xml", CT_THEME),
                 ("/docProps/core.xml", CT_CORE),
                 ("/docProps/app.xml", CT_EXT)]
    for i in range(1, n + 1):
        overrides.append(("/ppt/slides/slide%d.xml" % i, CT_PML_SLIDE))
    entries.append(("[Content_Types].xml", content_types(
        [("rels", "application/vnd.openxmlformats-package.relationships+xml"), ("xml", "application/xml")],
        overrides)))

    pres_rels = [("rId1", RT_SLIDE_MASTER, "slideMasters/slideMaster1.xml")]
    for i in range(1, n + 1):
        pres_rels.append(("rId%d" % (i + 1), RT_SLIDE, "slides/slide%d.xml" % i))
    entries.append(("_rels/.rels", rels([
        ("rId1", RT_OFFDOC, "ppt/presentation.xml"),
        ("rId2", RT_CORE, "docProps/core.xml"),
        ("rId3", RT_EXT, "docProps/app.xml")])))
    entries.append(("ppt/_rels/presentation.xml.rels", rels(pres_rels)))

    sld_ids = "".join('<p:sldId id="%d" r:id="rId%d"/>' % (255 + i, i + 1) for i in range(1, n + 1))
    entries.append(("ppt/presentation.xml",
                    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                    '<p:presentation xmlns:a="%s" xmlns:r="%s" xmlns:p="%s">'
                    '<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>'
                    '<p:sldIdLst>%s</p:sldIdLst>'
                    '<p:sldSz cx="%d" cy="%d" type="screen16x9"/>'
                    '<p:notesSz cx="6858000" cy="9144000"/>'
                    "</p:presentation>" % (NS_A, NS_R, NS_P, sld_ids, SLIDE_W, SLIDE_H)))

    entries.append(("ppt/slideMasters/slideMaster1.xml", master_xml(2)))
    entries.append(("ppt/slideMasters/_rels/slideMaster1.xml.rels", rels([
        ("rId1", RT_SLIDE_LAYOUT, "../slideLayouts/slideLayout1.xml"),
        ("rId2", RT_SLIDE_LAYOUT, "../slideLayouts/slideLayout2.xml"),
        ("rId3", RT_THEME, "../theme/theme1.xml")])))
    entries.append(("ppt/slideLayouts/slideLayout1.xml", layout_xml("title")))
    entries.append(("ppt/slideLayouts/slideLayout2.xml", layout_xml("obj")))
    for i in (1, 2):
        entries.append(("ppt/slideLayouts/_rels/slideLayout%d.xml.rels" % i,
                        rels([("rId1", RT_SLIDE_MASTER, "../slideMasters/slideMaster1.xml")])))
    entries.append(("ppt/theme/theme1.xml", theme_xml()))

    for i, (kind, title, lines) in enumerate(SLIDES, start=1):
        layout = 1 if kind == "title" else 2
        entries.append(("ppt/slides/slide%d.xml" % i, slide_xml(kind, title, lines)))
        entries.append(("ppt/slides/_rels/slide%d.xml.rels" % i,
                        rels([("rId1", RT_SLIDE_LAYOUT, "../slideLayouts/slideLayout%d.xml" % layout)])))

    titles = "".join("<vt:lpstr>%s</vt:lpstr>" % escape(t) for _, t, _ in SLIDES)
    entries.append(("docProps/core.xml",
                    core_props("git-sync v2.7.4 \u672c\u673a\u6253\u901a\u9a8c\u6536",
                               "local bridge acceptance deck")))
    entries.append(("docProps/app.xml",
                    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                    '<Properties xmlns="%s" xmlns:vt="%s">'
                    "<Application>Microsoft Office PowerPoint</Application><DocSecurity>0</DocSecurity>"
                    "<ScaleCrop>false</ScaleCrop><LinksUpToDate>false</LinksUpToDate>"
                    "<SharedDoc>false</SharedDoc><HyperlinksChanged>false</HyperlinksChanged>"
                    "<AppVersion>16.0000</AppVersion>"
                    "<Slides>%d</Slides>"
                    "<TitlesOfParts><vt:vector size=\"%d\" baseType=\"lpstr\">%s</vt:vector></TitlesOfParts>"
                    "</Properties>" % (NS_EP, NS_VT, n, n, titles)))

    write_zip(path, entries)


# --------------------------------------------------------------------------
# validation (sandbox side; the real proof happens on the local machine)
# --------------------------------------------------------------------------

def selftest(path, kind):
    import xml.etree.ElementTree as ET

    required = ["[Content_Types].xml", "_rels/.rels"]
    required += ["word/document.xml", "word/styles.xml"] if kind == "docx" else [
        "ppt/presentation.xml", "ppt/slideMasters/slideMaster1.xml", "ppt/theme/theme1.xml"]
    with zipfile.ZipFile(path) as z:
        names = set(z.namelist())
        missing = [r for r in required if r not in names]
        assert not missing, "missing parts: %s" % missing
        slides = sorted(x for x in names if x.startswith("ppt/slides/slide") and x.endswith(".xml"))
        for name in sorted(names):
            ET.fromstring(z.read(name))          # every part must be well-formed XML
        main = z.read("word/document.xml" if kind == "docx" else "ppt/presentation.xml").decode("utf-8")
        blob = "".join(z.read(x).decode("utf-8", "ignore") for x in sorted(names))
        for marker in MARKERS if kind == "docx" else ["git-sync", "2.7.4"]:
            assert marker in blob, "marker missing in %s: %s" % (kind, marker)
    return {"parts": len(names), "slides": len(slides), "main_bytes": len(main.encode("utf-8"))}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    docx_path = os.path.join(OUT_DIR, DOCX_NAME)
    pptx_path = os.path.join(OUT_DIR, PPTX_NAME)
    build_docx(docx_path)
    build_pptx(pptx_path)

    files = []
    for path, kind, required, main_part, markers, min_slides in (
        (docx_path, "docx",
         ["[Content_Types].xml", "_rels/.rels", "word/document.xml", "word/styles.xml",
          "word/_rels/document.xml.rels", "docProps/core.xml", "docProps/app.xml"],
         "word/document.xml", MARKERS, None),
        (pptx_path, "pptx",
         ["[Content_Types].xml", "_rels/.rels", "ppt/presentation.xml",
          "ppt/_rels/presentation.xml.rels", "ppt/slideMasters/slideMaster1.xml",
          "ppt/slideLayouts/slideLayout1.xml", "ppt/slideLayouts/slideLayout2.xml",
          "ppt/theme/theme1.xml", "ppt/slides/slide1.xml", "docProps/core.xml", "docProps/app.xml"],
         "ppt/presentation.xml", ["git-sync", "2.7.4", "arena/01a0a9ba-git-pull-arena"], len(SLIDES)),
    ):
        info = selftest(path, kind)
        files.append({
            "path": os.path.relpath(path, REPO_ROOT).replace(os.sep, "/"),
            "kind": kind,
            "bytes": os.path.getsize(path),
            "sha256": sha256_of(path),
            "required_parts": required,
            "main_part": main_part,
            "must_contain": markers,
            "min_slides": min_slides,
            "sandbox_selftest": info,
        })
        print("OK %s  %d bytes  sha256=%s  parts=%d slides=%s"
              % (files[-1]["path"], files[-1]["bytes"], files[-1]["sha256"][:16],
                 info["parts"], info["slides"] or "-"))

    manifest = {
        "generated_utc": CREATED,
        "generator": "code/make_bridge_report.py",
        "generator_note": "pure stdlib OOXML writer; deterministic ZIP timestamps; no network access",
        "how_local_verifies": ("code/local_check.ps1 section 3 compares sha256/bytes, opens the package, "
                               "checks required_parts exist, parses every .xml/.rels part, proves every "
                               "relationship target resolves and content types cover every part, then "
                               "searches must_contain across ALL xml parts (main_part is the structural "
                               "anchor, not the text scope) and counts slides against min_slides; "
                               "the Office COM open test is opt-in because the watcher is non-interactive"),
        "files": files,
    }
    with open(os.path.join(OUT_DIR, HASH_NAME), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("OK deliverable/%s" % HASH_NAME)
    return 0


if __name__ == "__main__":
    sys.exit(main())
