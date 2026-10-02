# -*- coding: utf-8 -*-
"""Generate privacy-safe resume and vector demo artifacts for round 219.

This script intentionally uses fictional resume data only. It writes Markdown,
HTML, DOCX, and SVG artifacts using only Python's standard library.
"""
from __future__ import annotations

import argparse
import html
import json
import os
import zipfile
from pathlib import Path
from textwrap import dedent


FAKE_PROFILE = {
    "name": "林澈",
    "title": "科研数据分析 / AI 产品实习生",
    "phone": "+86 000-0000-0000",
    "email": "demo.resume@example.com",
    "location": "上海 / 可远程",
    "github": "github.com/example-linche",
    "summary": "具备科研数据清洗、机器学习建模、可视化制图与自动化文档生成经验。熟悉 Python、R、SQL、WPS/Office 自动化和矢量图编辑流程，能够把实验数据转化为可复现的报告、图表和演示材料。",
    "skills": [
        "Python / pandas / scikit-learn / matplotlib",
        "R / 统计建模 / 文献数据整理",
        "SQL / Excel / WPS 表格自动化",
        "科研绘图：SVG、Illustrator、可编辑矢量流程图",
        "AI 协作：提示词设计、结果校验、自动化工作流",
    ],
    "experience": [
        {
            "role": "科研数据分析助理",
            "org": "某高校交叉学科实验室（示例）",
            "time": "2024.09 - 2026.06",
            "bullets": [
                "整理 12 批实验数据，建立字段字典和缺失值处理流程，使分析脚本可复用。",
                "使用机器学习模型完成样本分类基线实验，并输出可解释性图表。",
                "将图表、引用和结论自动汇总为 WPS/PowerPoint 演示文稿。",
            ],
        },
        {
            "role": "AI 产品与自动化实习生",
            "org": "某技术公司（示例）",
            "time": "2023.07 - 2024.02",
            "bullets": [
                "设计面向研究人员的资料整理流程，减少重复复制粘贴操作。",
                "把需求拆分为文件处理、网页检索、图表生成和结果校验四类工具。",
            ],
        },
    ],
    "projects": [
        {
            "name": "可复现实验报告模板",
            "bullets": [
                "构建 Markdown -> HTML -> DOCX 的报告生成链路，保留图表、表格和引用。",
                "支持把 SVG 矢量图嵌入论文初稿或演示材料，便于后期编辑。",
            ],
        },
        {
            "name": "科研文献与数据一致性检查",
            "bullets": [
                "用脚本检查引用编号、图表编号和数据口径，输出人工复核清单。",
            ],
        },
    ],
    "education": "某大学 数据科学与生物信息方向 硕士（示例） | 2023 - 2026",
}


def md_resume(profile: dict) -> str:
    lines = [
        f"# {profile['name']}",
        f"**{profile['title']}**",
        "",
        f"电话：{profile['phone']}  |  邮箱：{profile['email']}  |  地点：{profile['location']}",
        f"GitHub：{profile['github']}",
        "",
        "## 个人简介",
        profile["summary"],
        "",
        "## 核心技能",
    ]
    lines += [f"- {x}" for x in profile["skills"]]
    lines += ["", "## 工作 / 科研经历"]
    for item in profile["experience"]:
        lines += [f"### {item['role']}｜{item['org']}｜{item['time']}"]
        lines += [f"- {b}" for b in item["bullets"]]
    lines += ["", "## 项目经历"]
    for item in profile["projects"]:
        lines += [f"### {item['name']}"]
        lines += [f"- {b}" for b in item["bullets"]]
    lines += ["", "## 教育背景", profile["education"], ""]
    lines += ["---", "注：本简历为隐私安全的虚构示例，不包含用户真实个人信息。"]
    return "\n".join(lines) + "\n"


def html_resume(profile: dict, md_text: str) -> str:
    # Minimal semantic HTML; the visible content mirrors the Markdown resume.
    def esc(x: str) -> str:
        return html.escape(x, quote=True)

    exp_html = []
    for item in profile["experience"]:
        exp_html.append(
            f"<section><h3>{esc(item['role'])}<span>{esc(item['org'])} · {esc(item['time'])}</span></h3>"
            + "<ul>"
            + "".join(f"<li>{esc(b)}</li>" for b in item["bullets"])
            + "</ul></section>"
        )
    proj_html = []
    for item in profile["projects"]:
        proj_html.append(
            f"<section><h3>{esc(item['name'])}</h3><ul>"
            + "".join(f"<li>{esc(b)}</li>" for b in item["bullets"])
            + "</ul></section>"
        )
    return f"""<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>{esc(profile['name'])} - 示例简历</title>
<style>
:root {{ --ink:#172033; --muted:#667085; --blue:#2f6fed; --bg:#f5f7fb; }}
* {{ box-sizing:border-box; }}
body {{ margin:0; background:var(--bg); color:var(--ink); font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","Microsoft YaHei",Arial,sans-serif; }}
.page {{ width:900px; margin:32px auto; background:#fff; padding:44px 54px; border-radius:18px; box-shadow:0 18px 60px rgba(20,35,70,.12); }}
header {{ border-bottom:3px solid #eef2ff; padding-bottom:20px; margin-bottom:24px; }}
h1 {{ margin:0; font-size:42px; letter-spacing:.08em; }}
.subtitle {{ margin-top:8px; color:var(--blue); font-weight:700; font-size:18px; }}
.contact {{ margin-top:14px; color:var(--muted); line-height:1.8; }}
h2 {{ margin:28px 0 12px; font-size:21px; border-left:5px solid var(--blue); padding-left:10px; }}
h3 {{ margin:16px 0 8px; font-size:17px; }}
h3 span {{ display:block; margin-top:4px; color:var(--muted); font-size:14px; font-weight:500; }}
ul {{ margin-top:8px; padding-left:22px; }}
li {{ margin:6px 0; line-height:1.6; }}
.skills {{ display:grid; grid-template-columns:1fr 1fr; gap:8px 18px; padding:0; list-style:none; }}
.skills li {{ background:#f3f6ff; padding:8px 10px; border-radius:9px; margin:0; }}
.note {{ margin-top:30px; color:#98a2b3; font-size:13px; }}
@media print {{ body {{ background:#fff; }} .page {{ box-shadow:none; margin:0; width:auto; border-radius:0; }} }}
</style>
</head>
<body>
<main class="page">
<header>
<h1>{esc(profile['name'])}</h1>
<div class="subtitle">{esc(profile['title'])}</div>
<div class="contact">电话：{esc(profile['phone'])} ｜ 邮箱：{esc(profile['email'])} ｜ 地点：{esc(profile['location'])}<br>GitHub：{esc(profile['github'])}</div>
</header>
<h2>个人简介</h2><p>{esc(profile['summary'])}</p>
<h2>核心技能</h2><ul class="skills">{''.join(f'<li>{esc(s)}</li>' for s in profile['skills'])}</ul>
<h2>工作 / 科研经历</h2>{''.join(exp_html)}
<h2>项目经历</h2>{''.join(proj_html)}
<h2>教育背景</h2><p>{esc(profile['education'])}</p>
<p class="note">本简历为隐私安全的虚构示例，不包含用户真实个人信息。</p>
</main>
</body>
</html>
"""


def para(text: str, style: str | None = None) -> str:
    style_xml = f'<w:pPr><w:pStyle w:val="{style}"/></w:pPr>' if style else ""
    parts = []
    for line in text.split("\n"):
        if parts:
            parts.append('<w:br/>')
        parts.append(f'<w:t xml:space="preserve">{html.escape(line)}</w:t>')
    return f"<w:p>{style_xml}<w:r>{''.join(parts)}</w:r></w:p>"


def make_docx(profile: dict, out_path: Path) -> None:
    body = []
    body.append(para(profile["name"], "Title"))
    body.append(para(profile["title"], "Subtitle"))
    body.append(para(f"电话：{profile['phone']} ｜ 邮箱：{profile['email']} ｜ 地点：{profile['location']} ｜ {profile['github']}"))
    body.append(para("个人简介", "Heading1"))
    body.append(para(profile["summary"]))
    body.append(para("核心技能", "Heading1"))
    for s in profile["skills"]:
        body.append(para("• " + s))
    body.append(para("工作 / 科研经历", "Heading1"))
    for item in profile["experience"]:
        body.append(para(f"{item['role']}｜{item['org']}｜{item['time']}", "Heading2"))
        for b in item["bullets"]:
            body.append(para("• " + b))
    body.append(para("项目经历", "Heading1"))
    for item in profile["projects"]:
        body.append(para(item["name"], "Heading2"))
        for b in item["bullets"]:
            body.append(para("• " + b))
    body.append(para("教育背景", "Heading1"))
    body.append(para(profile["education"]))
    body.append(para("注：本简历为隐私安全的虚构示例，不包含用户真实个人信息。"))

    document = f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
{''.join(body)}
<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1000" w:right="1000" w:bottom="1000" w:left="1000"/></w:sectPr>
</w:body></w:document>'''
    styles = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:rPr><w:b/><w:sz w:val="48"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Subtitle"><w:name w:val="Subtitle"/><w:rPr><w:color w:val="2F6FED"/><w:b/><w:sz w:val="28"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:rPr><w:b/><w:color w:val="2F6FED"/><w:sz w:val="28"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:rPr><w:b/><w:sz w:val="24"/></w:rPr></w:style>
</w:styles>'''
    content_types = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>'''
    rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>'''
    doc_rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>'''
    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", content_types)
        zf.writestr("_rels/.rels", rels)
        zf.writestr("word/_rels/document.xml.rels", doc_rels)
        zf.writestr("word/document.xml", document)
        zf.writestr("word/styles.xml", styles)


def svg_resume(profile: dict) -> str:
    skills = ["数据清洗", "机器学习", "科研绘图", "文献管理", "自动化报告"]
    chips = "".join(
        f'<rect x="60" y="{210+i*42}" width="220" height="28" rx="14" fill="#eef4ff"/><text x="78" y="{230+i*42}" font-size="15">{html.escape(s)}</text>'
        for i, s in enumerate(skills)
    )
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="900" height="520" viewBox="0 0 900 520">
<rect width="900" height="520" fill="#f8fafc"/>
<rect x="36" y="36" width="828" height="448" rx="24" fill="white" stroke="#dbe4f0"/>
<rect x="36" y="36" width="290" height="448" rx="24" fill="#1d4ed8"/>
<text x="60" y="95" fill="white" font-size="36" font-family="Microsoft YaHei, Arial" font-weight="700">{html.escape(profile['name'])}</text>
<text x="60" y="132" fill="#dbeafe" font-size="18" font-family="Microsoft YaHei, Arial">{html.escape(profile['title'])}</text>
<text x="60" y="178" fill="white" font-size="16" font-family="Microsoft YaHei, Arial">核心能力</text>
{chips}
<text x="360" y="90" fill="#111827" font-size="24" font-family="Microsoft YaHei, Arial" font-weight="700">科研与 AI 协作型简历示例</text>
<text x="360" y="130" fill="#475569" font-size="16" font-family="Microsoft YaHei, Arial">本文件是可编辑 SVG：文本、色块、流程线均可在 Illustrator/Inkscape 中修改。</text>
<circle cx="420" cy="230" r="54" fill="#dbeafe" stroke="#2f6fed" stroke-width="3"/>
<text x="390" y="236" font-size="16" font-family="Microsoft YaHei, Arial">数据</text>
<circle cx="590" cy="230" r="54" fill="#dcfce7" stroke="#16a34a" stroke-width="3"/>
<text x="560" y="236" font-size="16" font-family="Microsoft YaHei, Arial">模型</text>
<circle cx="760" cy="230" r="54" fill="#fef3c7" stroke="#f59e0b" stroke-width="3"/>
<text x="730" y="236" font-size="16" font-family="Microsoft YaHei, Arial">报告</text>
<path d="M474 230 L536 230" stroke="#94a3b8" stroke-width="3" marker-end="url(#arrow)"/>
<path d="M644 230 L706 230" stroke="#94a3b8" stroke-width="3" marker-end="url(#arrow)"/>
<defs><marker id="arrow" markerWidth="12" markerHeight="12" refX="10" refY="6" orient="auto"><path d="M2,2 L10,6 L2,10" fill="none" stroke="#94a3b8" stroke-width="2"/></marker></defs>
<text x="360" y="330" fill="#111827" font-size="18" font-family="Microsoft YaHei, Arial" font-weight="700">项目亮点</text>
<text x="360" y="365" fill="#334155" font-size="15" font-family="Microsoft YaHei, Arial">• 可复现实验报告模板：Markdown / HTML / DOCX / SVG</text>
<text x="360" y="395" fill="#334155" font-size="15" font-family="Microsoft YaHei, Arial">• 科研文献与数据一致性检查：引用、图表、数据口径</text>
<text x="360" y="425" fill="#334155" font-size="15" font-family="Microsoft YaHei, Arial">• 自动化演示材料：WPS COM 与可编辑矢量图协同</text>
</svg>'''


def research_vector_svg() -> str:
    return '''<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="620" viewBox="0 0 1000 620">
<rect width="1000" height="620" fill="#ffffff"/>
<text x="50" y="60" font-size="30" font-family="Microsoft YaHei, Arial" font-weight="700">科研工作流矢量图示例</text>
<text x="50" y="95" font-size="16" fill="#64748b" font-family="Microsoft YaHei, Arial">可编辑 SVG：节点、连线、颜色、文本均可修改。</text>
<g font-family="Microsoft YaHei, Arial" font-size="18">
<rect x="70" y="170" width="170" height="90" rx="18" fill="#e0f2fe" stroke="#0284c7" stroke-width="2"/><text x="112" y="222">文献检索</text>
<rect x="300" y="170" width="170" height="90" rx="18" fill="#ecfccb" stroke="#65a30d" stroke-width="2"/><text x="342" y="222">数据清洗</text>
<rect x="530" y="170" width="170" height="90" rx="18" fill="#fef3c7" stroke="#d97706" stroke-width="2"/><text x="572" y="222">模型分析</text>
<rect x="760" y="170" width="170" height="90" rx="18" fill="#fce7f3" stroke="#db2777" stroke-width="2"/><text x="802" y="222">论文图表</text>
<path d="M240 215 H300" stroke="#94a3b8" stroke-width="4" marker-end="url(#a)"/>
<path d="M470 215 H530" stroke="#94a3b8" stroke-width="4" marker-end="url(#a)"/>
<path d="M700 215 H760" stroke="#94a3b8" stroke-width="4" marker-end="url(#a)"/>
<rect x="180" y="360" width="220" height="90" rx="18" fill="#eef2ff" stroke="#4f46e5" stroke-width="2"/><text x="232" y="412">引用一致性</text>
<rect x="600" y="360" width="220" height="90" rx="18" fill="#f0fdf4" stroke="#16a34a" stroke-width="2"/><text x="643" y="412">可复现报告</text>
<path d="M615 260 C610 320 370 320 290 360" fill="none" stroke="#94a3b8" stroke-width="3" marker-end="url(#a)"/>
<path d="M845 260 C850 330 755 340 710 360" fill="none" stroke="#94a3b8" stroke-width="3" marker-end="url(#a)"/>
</g>
<defs><marker id="a" markerWidth="12" markerHeight="12" refX="10" refY="6" orient="auto"><path d="M2,2 L10,6 L2,10" fill="none" stroke="#94a3b8" stroke-width="2"/></marker></defs>
</svg>'''


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    md = md_resume(FAKE_PROFILE)
    html_text = html_resume(FAKE_PROFILE, md)
    (out / "sample_resume_privacy_safe_r219.md").write_text(md, encoding="utf-8")
    (out / "sample_resume_privacy_safe_r219.html").write_text(html_text, encoding="utf-8")
    make_docx(FAKE_PROFILE, out / "sample_resume_privacy_safe_r219.docx")
    (out / "sample_resume_vector_editable_r219.svg").write_text(svg_resume(FAKE_PROFILE), encoding="utf-8")
    (out / "research_vector_editable_figure_r219.svg").write_text(research_vector_svg(), encoding="utf-8")
    manifest = {
        "privacy": "fictional sample only; no user personal data",
        "files": [str(p) for p in sorted(out.glob("*r219*"))],
    }
    (out / "resume_artifacts_manifest_r219.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(manifest, ensure_ascii=False))


if __name__ == "__main__":
    main()
