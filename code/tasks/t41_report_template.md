任务场景与工具能力 + 大文件清单 2026-09-30
===

> r50 生成：科研/办公任务场景、MCP 资源、n8n、R 环境、大文档清单。供取舍参考。

## 一、科研场景（用现有工具怎么干）

| 场景 | 方案 | 工具 |
|---|---|---|
| HPC 作业 | 提交/查状态/拉结果全流程可自动化：ssh 批量 sbatch，结果 scp 回本地 | ssh/scp + tailscale 链路（已打通） |
| 数据处理 | 数据清洗、统计、批处理脚本；Linux 环境跑生信/化学工具链 | Python(E:\spider)、WSL Ubuntu-24.04/26.04、R |
| 结构生物学 | 画图手动，但批量预处理（PDB 批量下载/解析/格式转换）可自动化 | LigPlot+（快捷方式已配）、VMD（可启动） |
| 分子对接 | AutoDock/Vina 命令行批量对接、结果批量分析（D 盘有旧版，建议 winget 装新版） | WSL/Vina |
| 文献管理 | 库在 Zotero/EndNote；我能做 PDF 批量重命名/查重、BibTeX 合并去重 | Python + rg |
| 论文写作 | 数据→图表→Word/Excel 自动生成；LaTeX 编译需装 TeX Live（可装） | python-docx/openpyxl（按需 pip 安装） |
| 机器学习 | conda/uv 环境管理、数据集处理、训练脚本轮询值守 | conda、uv、Go/Rust/Node |

## 二、办公场景

| 场景 | 方案 | 工具 |
|---|---|---|
| Excel 报表 | 合并/拆分/汇总/格式化全自动 | Python openpyxl（按需装） |
| Word 批量 | 按模板批量生成文档（通知单、报告） | python-docx（按需装） |
| PDF 处理 | 合并/拆分/转文字需装 poppler/ffmpeg（一条命令的事） | winget 现装 |
| 文件整理 | 重复文件/大文件/按类型归档，全盘秒搜 | rg、robocopy |
| 定时任务 | 文件备份、定时提醒、断线重连 | schtasks（我）+ zTasker（你，GUI） |
| 自动化流水线 | 事件触发的工作流（如"收到邮件→存附件→回消息"） | n8n（见下） |
| 远程协作 | 双向 RDP、跨网访问 HPC、内网穿透 | Tailscale（已配好） |

## 三、MCP 资源（E:\0mcp-agv）
{{MCP_SECTION}}

## 四、n8n 工作流
{{N8N_SECTION}}

## 五、R 语言环境
{{R_SECTION}}

## 六、大文档清单（供取舍）
{{DOCS_TABLE}}

## 七、其他软件使用方式 / 按需安装（winget 一条命令）

| 缺的工具 | 用途 | 安装命令（我可以直接执行） |
|---|---|---|
| ffmpeg | 音视频转换/剪辑/录屏 | winget install Gyan.FFmpeg |
| 7-Zip | 压缩解压（含 rar 需另行装） | winget install 7zip.7zip |
| poppler | PDF 转文本/拆页 | winget install poppler |
| LibreOffice | docx/pdf 批量互转（无 GUI 依赖） | winget install TheDocumentFoundation.LibreOffice |
| TeX Live | LaTeX 编译 | winget install TeXLive.TeXLive |
| RStudio | R 的 IDE（如需 GUI） | winget install Posit.RStudio |

> GUI 软件（WPS、Zotero、EndNote、VMD、Discovery Studio、zTasker、NSFOCUS）我只能启动或配合你人工操作；
> 命令行/脚本类的我都能无人值守驱动。要装哪个说一声即可。
