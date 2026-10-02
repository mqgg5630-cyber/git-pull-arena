# 简历 Skills / 科研绘图 / Colab-Kaggle 计算资源 / Antigravity 测试清单（R219）

生成时间：2026-10-02

## 隐私边界

本轮按你的要求只在**笔记本**做简历相关测试，没有到台式机测试简历。生成的简历是**虚构示例**，没有使用你的真实个人信息。

## 1. 简历制作 skills

我检查了现有 skills，科研和图形类 skills 很多，但没有发现明确的专用简历 skill，因此已在笔记本 E 盘安装新的简历 wrapper skill：

```text
E:\0mcp-agv-arena-optimized\agents-skills\skills\resume-cv-builder\SKILL.md
```

同时安装了配套能力：

```text
E:\0mcp-agv-arena-optimized\agents-skills\skills\research-skill-router\SKILL.md
E:\0mcp-agv-arena-optimized\agents-skills\skills\vector-editable-figure\SKILL.md
E:\0mcp-agv-arena-optimized\agents-skills\skills\cloud-compute-bridge\SKILL.md
```

## 2. 已生成的示例简历文件（笔记本 E 盘）

输出目录：

```text
E:\0mcp-agv-arena-optimized\resume-samples
```

已生成：

```text
E:\0mcp-agv-arena-optimized\resume-samples\sample_resume_privacy_safe_r219.md
E:\0mcp-agv-arena-optimized\resume-samples\sample_resume_privacy_safe_r219.html
E:\0mcp-agv-arena-optimized\resume-samples\sample_resume_privacy_safe_r219.docx
E:\0mcp-agv-arena-optimized\resume-samples\sample_resume_vector_editable_r219.svg
E:\0mcp-agv-arena-optimized\resume-samples\research_vector_editable_figure_r219.svg
E:\0mcp-agv-arena-optimized\resume-samples\resume_artifacts_manifest_r219.json
```

用途：

- `.md`：方便继续让 AI/Antigravity 修改文本。
- `.html`：适合浏览器预览和打印 PDF。
- `.docx`：可用 WPS/Word 编辑。
- `.svg`：矢量可编辑，可用 Illustrator/Inkscape/浏览器查看和修改。

## 3. 科研 skills 检索结果

检出 28 个相关 skills，其中科研类 20 个、矢量/图形类 8 个。

科研类代表：

```text
academic-experimental-paper-writer
cnki-academic-agent
english-academic-agent
hybrid-academic-agent
lark-thesis-formatter
light-citation
light-consistency
light-data-engineering
light-paper-writing
light-research-ethics
light-research-plan
nature-academic-search
nature-citation
nature-data
nature-paper-card
nature-paper-to-patent
nature-paper2ppt
```

矢量可编辑绘图类代表：

```text
light-figure
nature-figure
pure-vector-svg-illustrator
scientific-figure-shapes
scipilot-figure-skill
smart-illustrator
```

完整 JSON：

```text
E:\0mcp-agv-arena-optimized\reports\resume-research-vector-skill-hits-r219.json
```

仓库副本：

```text
results/mcp_agv_lab/resume-research-vector-skill-hits-r219.json
```

## 4. Antigravity 能力测试

我让 Antigravity 使用**虚构数据**做了一次简历/科研/矢量 skills 能力测试，结果：

```text
Inserted: True
Submitted: True
Marker found in DOM: True
FINAL: ANTIGRAVITY_FAKE_RESUME_SKILL_RESPONSE_MARKER_FOUND
```

也就是说，Antigravity 这次不仅能打开/启动，还能通过 CDP 完成对话输入和提交，并检测到生成结果 marker。

结果路径：

```text
E:\0mcp-agv-arena-optimized\reports\antigravity-resume-skill-test-r219.json
E:\0mcp-agv-arena-optimized\reports\antigravity-resume-skill-test-summary-r219.md
```

仓库副本：

```text
results/mcp_agv_lab/antigravity-resume-skill-test-summary-r219.md
```

## 5. Colab / Kaggle 免费计算资源打通可行性

已生成本地打通目录：

```text
E:\0mcp-agv-arena-optimized\compute-bridge
```

包含：

```text
E:\0mcp-agv-arena-optimized\compute-bridge\README.md
E:\0mcp-agv-arena-optimized\compute-bridge\kaggle_cli_setup.md
E:\0mcp-agv-arena-optimized\compute-bridge\colab_bridge_template.ipynb
```

本轮只做了**无凭据网络探测**，没有索要或保存任何 Kaggle/Google token。

探测结果概要：

```text
Colab: HTTP 200, 可达，time≈0.84s
Kaggle API: HTTP 200, 可达，time≈1.02s
Google Storage: 可达，返回 HTTP 400 属于根路径无对象的正常响应
Kaggle 首页: TLS close_notify 报错，但 Kaggle API 可达
```

完整探测 JSON：

```text
E:\0mcp-agv-arena-optimized\reports\colab-kaggle-connectivity-r219.json
```

结论：

- 可以打通 Colab/Kaggle，但需要你授权登录或提供本机私有 token 文件。
- Kaggle 推荐把 `kaggle.json` 放在 `%USERPROFILE%\.kaggle\kaggle.json`，不能进 Git，也不能发到聊天里。
- Colab 适合 notebook/GPU 实验；Kaggle 适合 dataset、notebook、GPU/TPU quota 内任务。
- 免费资源有配额、断连、限时、GPU 不保证的问题。
- 本地原生网络适合下载/上传/整理文件；云 GPU 适合算力瓶颈任务。数据很大时，传输时间可能抵消免费 GPU 的收益。

## 6. 对比结论

| 能力 | 最适合的后端 |
|---|---|
| 简历文本生成/改写 | resume-cv-builder + Markdown/HTML/DOCX |
| 简历排版可编辑 | DOCX + HTML |
| 简历图形化/科研图 | SVG + vector-editable-figure |
| WPS 文档/PPT | WPS COM |
| Antigravity 对话 | CDP/Electron DOM |
| Antigravity 打开项目/文件 | Antigravity CLI |
| 普通 Windows 软件按钮 | windows-computer-use MCP/UIA |
| 科研文献/引用/数据检查 | research-skill-router + light/nature 系列 skills |
| Colab/Kaggle | cloud-compute-bridge，需要本机私有授权 |

## 7. 本轮主报告

```text
results/mcp_agv_lab/RESUME_SKILLS_COMPUTE_AGV_R219.md
results/mcp_agv_lab/resume-skills-compute-antigravity-summary-r219.md
```
