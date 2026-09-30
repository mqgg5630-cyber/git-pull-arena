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
MCP location: E:\0mcp-agv (48 subfolders)

- .agent : ? 
- .agents : ? 
- .playwright-mcp : ? 
- academic_hub_gui : binary Start_Academic_Hub.bat
- agents : ? 
- ARTA_Agent_Output : ? 
- banana-slides : node banana-slides [start: docker compose up -d]
- cep-extension : node illustrator-mcp-panel [node_modules]
- complexes_best_vina : ? 
- CyberPPT : ? 
- cyber_svg_icons : ? 
- cyber_svg_icons_png : ? 
- dashi-ppt-skill : ? 
- docs : ? 
- extracted_icons_15slides : ? 
- fig1_assets : ? 
- gas-sheet-project : ? 
- guizang-ppt-skill : ? 
- icon_cache : ? 
- icon_cache_flagship : ? 
- illustrator-scripts : ? 
- illustrator_mcp : python antigravity.py
- illustrator_mcp.egg-info : ? 
- living test : ? 
- mcp_servers : python lark_thesis_mcp_server.py
- nature-skills : ? 
- output_dashi_umami : ? 
- ppt-master : ? 
- PPTist : node pptist (bin: pptist-mcp) [node_modules]
- renders_ad_exact_15slides : ? 
- renders_ad_flagship_15slides : ? 
- renders_ad_stage_amp : ? 
- renders_amp_15slides : ? 
- renders_dashi_final : ? 
- renders_dashi_theme07 : ? 
- renders_original_15slides : ? 
- renders_original_dashi_umami : ? 
- renders_zonghe : ? 
- renders_zonghe_opt : ? 
- scipilot-figure-skill : python scipilot-figure-skill
- sci_docking_studio : binary run_cli.bat
- scratch : python inspect_zotero.py
- scripts : binary hybrid-academic.bat
- smart-illustrator : ? 
- tests : python conftest.py
- tests_jsx : ? 
- uxp-plugin : ? 
- 机器学习筛选鲜味肽_综述成果 : ? 

Usability: node/python type MCP servers can be invoked by the watcher loop via stdio JSON-RPC (npx/node/python all on PATH). Pilot candidates: fetch / filesystem / pandas style servers.

## 四、n8n 工作流

- Docker engine RUNNING. Containers:
  - docker : failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine; check if the path is correct
  -  and if the daemon is running: open //./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified.
  -     + CategoryInfo          : NotSpecified: (failed to conne...file specified.:String) [], RemoteException
  -     + FullyQualifiedErrorId : NativeCommandError
- No n8n container currently running.

## 五、R 语言环境

- Windows R version dirs: 0
  - WSL Ubuntu-24.04: 8 hits
  - WSL Ubuntu-26.04: 0 hits
- Action: no Windows R installation dirs found (registry entries: 0)
- R inside WSL is reported only, never deleted (WSL stays untouched by agreement).

## 六、大文档清单（供取舍）
### 文档类 >= 10 MB, 共 428 个, 前 80

| 大小 | 修改日期 | 文件 |
|---|---|---|
| 179.0 MB | 2025-11-03 | E:\Users\文少\Downloads\AMP.tsv |
| 92.8 MB | 2026-06-25 | D:\桌面\AI\wangluoyaolixue\网络药理学.pptx |
| 92.8 MB | 2026-06-25 | D:\桌面\AI\wangluoyaolixue\网络药理学.pptx |
| 68.6 MB | 2025-03-03 | E:\Users\文少\Downloads\MS-R.docx |
| 68.6 MB | 2025-02-08 | D:\桌面\1\2月\Interaction study of Components of Black Pepper wi.docx |
| 68.6 MB | 2025-02-08 | D:\桌面\1\2月\Interaction study of Components of Black Pepper wi.docx |
| 63.8 MB | 2026-07-27 | E:\微信\xwechat_files\wxid_n7lel2eo7ouj22_8412\msg\file\2026-07\02 政治理论与常识判断（解析）.pdf.pdf |
| 63.5 MB | 2026-04-14 | D:\桌面\AD\figures\Clustering_scatterplots.pdf |
| 63.5 MB | 2026-04-14 | D:\桌面\AD\figures\Clustering_scatterplots.pdf |
| 63.5 MB | 2026-06-08 | E:\1yzy\Sequence_Feature_Analysis_20260608_112057\CTDC\CTDC_All.csv |
| 63.2 MB | 2026-07-24 | E:\.codex\skills\practical-ml\Ch07-Analyzing-Movie-Reviews-Sentiment\movie_reviews.csv |
| 55.3 MB | 2025-01-16 | D:\桌面\1\2月\1月\AI\1pdf.pdf |
| 55.3 MB | 2025-01-16 | D:\桌面\1\2月\1月\AI\1pdf.pdf |
| 54.9 MB | 2025-01-16 | D:\桌面\1\2月\1月\AI\3.pdf |
| 54.9 MB | 2025-01-16 | D:\桌面\1\2月\1月\AI\3.pdf |
| 54.9 MB | 2025-01-17 | D:\桌面\1\2月\1月\JIUDONG.pdf |
| 54.9 MB | 2025-01-17 | D:\桌面\1\2月\1月\JIUDONG.pdf |
| 52.7 MB | 2026-06-11 | D:\桌面\AI\gong\考公学习资料-江西省考\江西公务员考试真题pdf版\江西公务员考试真题——行测06-22PDF版\答案及解析\2022年江西省公务员录用考试《行测》题（网友回忆版）答案与解析.pdf |
| 52.7 MB | 2026-06-11 | D:\桌面\AI\gong\考公学习资料-江西省考\江西公务员考试真题pdf版\江西公务员考试真题——行测06-22PDF版\答案及解析\2022年江西省公务员录用考试《行测》题（网友回忆版）答案与解析.pdf |
| 52.7 MB | 2026-06-11 | D:\桌面\AI\gong\考公学习资料-江西省考\江西公务员考试真题pdf版(1)\江西公务员考试真题——行测06-22PDF版\答案及解析\2022年江西省公务员录用考试《行测》题（网友回忆版）答案与解析.pdf |
| 52.7 MB | 2026-06-11 | D:\桌面\AI\gong\考公学习资料-江西省考\江西公务员考试真题pdf版(1)\江西公务员考试真题——行测06-22PDF版\答案及解析\2022年江西省公务员录用考试《行测》题（网友回忆版）答案与解析.pdf |
| 51.8 MB | 2025-01-16 | D:\桌面\1\2月\1月\AI\2.pdf |
| 51.8 MB | 2025-01-16 | D:\桌面\1\2月\1月\AI\2.pdf |
| 51.4 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Periodontitis_Specific\perio_batch_8_Predictions.csv |
| 50.3 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Healthy_Specific\healthy_batch_4_Predictions.csv |
| 50.3 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Periodontitis_Specific\perio_batch_21_Predictions.csv |
| 50.2 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Periodontitis_Specific\perio_batch_19_Predictions.csv |
| 49.7 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Healthy_Specific\healthy_batch_12_Predictions.csv |
| 48.2 MB | 2025-06-23 | E:\xwechat_files\wxid_n7lel2eo7ouj22_8412\msg\file\2025-06\世界鸟类分类与分布名录(第2版) (郑光美) (Z-Library).pdf |
| 48.2 MB | 2025-06-23 | E:\微信\WeChat Files\wxid_n7lel2eo7ouj22\FileStorage\File\2025-06\世界鸟类分类与分布名录(第2版) (郑光美) (Z-Library).pdf |
| 45.9 MB | 2026-03-20 | E:\xwechat_files\wxid_n7lel2eo7ouj22_8412\msg\file\2026-03\多肽提取、鉴定及虚拟筛选.pptx |
| 45.2 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Periodontitis_Specific\perio_batch_20_Predictions.csv |
| 44.9 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Periodontitis_Specific\perio_batch_2_Predictions.csv |
| 44.7 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Healthy_Specific\healthy_batch_22_Predictions.csv |
| 44.1 MB | 2026-07-24 | E:\.codex\skills\practical-ml\Ch10-Analyzing-Music-Trends-and-Recommendations\user_playcount_df.csv |
| 43.4 MB | 2025-11-03 | D:\桌面\学位论文开题用表\抗菌肽\1\2\AMP_filtered.tsv |
| 43.4 MB | 2025-11-03 | D:\桌面\学位论文开题用表\抗菌肽\1\2\AMP_filtered.tsv |
| 41.9 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Healthy_Specific\healthy_batch_10_Predictions.csv |
| 41.7 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Healthy_Specific\healthy_batch_24_Predictions.csv |
| 41.4 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Healthy_Specific\healthy_batch_6_Predictions.csv |
| 41.4 MB | 2026-09-10 | E:\ozotero\storage\XW8NX7B5\Jyler_Menard_2025_Towards_best_practices_in_low-dimensiona.pdf |
| 41.0 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Periodontitis_Specific\perio_batch_13_Predictions.csv |
| 38.9 MB | 2026-06-11 | D:\桌面\AI\gong\考公学习资料-江西省考\江西公务员考试真题pdf版\江西公务员考试真题——行测06-22PDF版\题目\2022年江西省公务员录用考试《行测》题（网友回忆版）.pdf |
| 38.9 MB | 2026-06-11 | D:\桌面\AI\gong\考公学习资料-江西省考\江西公务员考试真题pdf版(1)\江西公务员考试真题——行测06-22PDF版\题目\2022年江西省公务员录用考试《行测》题（网友回忆版）.pdf |
| 38.9 MB | 2026-06-11 | D:\桌面\AI\gong\考公学习资料-江西省考\江西公务员考试真题pdf版(1)\江西公务员考试真题——行测06-22PDF版\题目\2022年江西省公务员录用考试《行测》题（网友回忆版）.pdf |
| 38.9 MB | 2026-06-11 | D:\桌面\AI\gong\考公学习资料-江西省考\江西公务员考试真题pdf版\江西公务员考试真题——行测06-22PDF版\题目\2022年江西省公务员录用考试《行测》题（网友回忆版）.pdf |
| 38.9 MB | 2017-10-09 | E:\Users\文少\Downloads\ailearning-2.0\ailearning-2.0\books\机器学习实战-中文版-带目录版.pdf |
| 38.4 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Healthy_Specific\healthy_batch_5_Predictions.csv |
| 38.2 MB | 2026-01-24 | E:\Users\文少\Downloads\20210604142009_134.pdf |
| 37.8 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Periodontitis_Specific\perio_batch_23_Predictions.csv |
| 37.8 MB | 2026-08-24 | E:\Users\文少\Downloads\东华大学-卢婷婷-答辩通用PPT模板.pptx |
| 37.0 MB | 2026-09-23 | E:\Users\文少\Downloads\宿舍用电常见情况处理(6).doc |
| 37.0 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Periodontitis_Specific\perio_batch_16_Predictions.csv |
| 36.8 MB | 2023-02-06 | D:\MobileFile\pdf-1.pdf |
| 36.1 MB | 2010-06-29 | E:\G09W\gvref\gv5ref.pdf |
| 35.4 MB | 2024-11-03 | D:\桌面\1\2月\1月\天然产物与多糖对接\阿魏酸.pdf |
| 35.4 MB | 2024-11-03 | D:\桌面\1\2月\1月\天然产物与多糖对接\阿魏酸.pdf |
| 35.2 MB | 2022-11-12 | D:\MobileFile\科二四组遗传学第五章.pptx |
| 35.0 MB | 2026-01-08 | D:\桌面\学位论文开题用表\肠道抗菌肽区域异质性及其调控机制研究.pdf |
| 35.0 MB | 2026-01-08 | D:\桌面\学位论文开题用表\肠道抗菌肽区域异质性及其调控机制研究.pdf |
| 35.0 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Periodontitis_Specific\perio_batch_15_Predictions.csv |
| 34.9 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Periodontitis_Specific\perio_batch_14_Predictions.csv |
| 34.5 MB | 2025-03-11 | D:\桌面\论文\Interaction study of Components of Black Pepper wi.docx |
| 34.5 MB | 2025-03-11 | D:\桌面\论文\Interaction study of Components of Black Pepper wi.docx |
| 33.9 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Healthy_Specific\healthy_batch_18_Predictions.csv |
| 33.4 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Healthy_Specific\healthy_batch_3_Predictions.csv |
| 32.4 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Healthy_Specific\healthy_batch_7_Predictions.csv |
| 31.4 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Periodontitis_Specific\perio_batch_9_Predictions.csv |
| 31.4 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Periodontitis_Specific\perio_batch_18_Predictions.csv |
| 31.2 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Periodontitis_Specific\perio_batch_11_Predictions.csv |
| 31.2 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Periodontitis_Specific\perio_batch_17_Predictions.csv |
| 31.1 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Healthy_Specific\healthy_batch_17_Predictions.csv |
| 30.9 MB | 2026-06-08 | E:\1yzy\Sequence_Feature_Analysis_20260608_112057\PAAC\PAAC_All.csv |
| 30.6 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Healthy_Specific\healthy_batch_9_Predictions.csv |
| 30.1 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Healthy_Specific\healthy_batch_1_Predictions.csv |
| 30.0 MB | 2020-08-21 | E:\Multiwfn-mirror-3.7\Multiwfn-mirror-3.7\Multiwfn_3.7.pdf |
| 29.6 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Healthy_Specific\healthy_batch_14_Predictions.csv |
| 29.4 MB | 2025-01-14 | D:\桌面\1\2月\1月\ZONG.pptx |
| 29.4 MB | 2025-01-14 | D:\桌面\1\2月\1月\ZONG.pptx |
| 28.6 MB | 2026-06-03 | E:\1yzy\Predictions_Results\Predictions_Results\Healthy_Specific\healthy_batch_11_Predictions.csv |

### 压缩包/数据集 >= 50 MB, 共 105 个, 前 40

| 大小 | 修改日期 | 文件 |
|---|---|---|
| 488.7 MB | 2026-08-11 | E:\迅雷云盘\WPSOffice_雨糖科技特别版_2019_11.8.2.12344_x86_20260806.zip |
| 362.5 MB | 2026-06-04 | E:\1yzy\Predictions_Results.zip |
| 254.6 MB | 2026-06-04 | E:\1yzy\csv_batches.zip |
| 247.4 MB | 2025-10-01 | E:\Users\文少\Downloads\ai_102060\products\ILST\AdobeIllustrator29-maskingAi.zip |
| 235.5 MB | 2026-06-02 | E:\Users\文少\Downloads\GROMACS-2026.2_May17_GPU_Windows-AMD64-AVX2_CUDA1320_msvc.zip |
| 234.9 MB | 2026-07-21 | E:\Users\文少\Downloads\Gromacs.2026.2.Prebuild.Windows.X64.CUDA13.0.AVX512.zip |
| 234.5 MB | 2026-07-21 | E:\gromacs.zip |
| 225.3 MB | 2026-08-15 | E:\Users\文少\Downloads\eSearch-15.3.4-win32-x64.zip |
| 217.0 MB | 2026-08-15 | E:\vscode-cache\vscode-remote-wsl\stable\c2d1b13fdc4a77628e5f3bb70173351c8f2fbad1\vscode-server-stable-linux-x64.tar.gz |
| 213.6 MB | 2026-08-17 | E:\vscode-cache\vscode-remote-wsl\stable\a5b500951314efd502d07465bd138dfbd714a960\vscode-server-stable-linux-x64.tar.gz |
| 213.1 MB | 2026-09-02 | E:\vscode-cache\vscode-remote-wsl\stable\08d4889f9ec4a1685d257b9b95de036c8e1ce1e5\vscode-server-stable-linux-x64.tar.gz |
| 207.1 MB | 2026-05-11 | E:\Users\文少\Downloads\pretrain_model-20260511T121533Z-3-001.zip |
| 199.5 MB | 2026-08-14 | E:\Users\文少\Downloads\Orca-1.4.182-mac.zip |
| 190.0 MB | 2025-04-29 | E:\xwechat_files\wxid_n7lel2eo7ouj22_8412\msg\file\2025-04\SVID_20241021_143643_1.zip |
| 190.0 MB | 2025-04-29 | E:\微信\WeChat Files\wxid_n7lel2eo7ouj22\FileStorage\File\2025-04\SVID_20241021_143643_1.zip |
| 178.1 MB | 2026-01-26 | E:\Users\文少\Downloads\EasyAmplicon-2.00.zip |
| 171.8 MB | 2026-05-14 | E:\Users\文少\Downloads\UniDL4BioPep-new.zip |
| 161.2 MB | 2025-08-17 | E:\Users\文少\Downloads\v2rayN-windows-64-SelfContained-With-Core.zip |
| 157.5 MB | 2026-03-26 | D:\桌面\AI\fanqiang\FirefoxFQ.7z |
| 157.5 MB | 2026-03-26 | D:\桌面\AI\fanqiang\FirefoxFQ.7z |
| 146.2 MB | 2025-10-27 | E:\BaiduNetdiskDownload\永久会员6.0.1激活.zip |
| 137.5 MB | 2026-07-05 | E:\0docking\SailVina\SailVina_exe.zip |
| 137.5 MB | 2026-07-05 | E:\BaiduNetdiskDownload\SailVina_exe.zip |
| 130.9 MB | 2025-08-26 | E:\v2rayN-windows-64-SelfContained.zip |
| 128.3 MB | 2026-07-03 | E:\Users\文少\Downloads\ACDLabs202525_ChemSketch_FInstall.zip |
| 127.1 MB | 2020-09-03 | E:\0wangyao\wangyao\raw\1\GSE157827\RAW\GSM4775576_NC12_matrix.mtx.gz |
| 127.1 MB | 2026-07-04 | E:\0wangyao\wangyao\raw\1\GSE157827\GSM4775576_NC12\matrix.mtx.gz |
| 126.3 MB | 2026-08-20 | E:\Users\文少\Downloads\v2rayN-windows-64-desktop.zip |
| 125.2 MB | 2026-08-15 | E:\Users\文少\Downloads\ZTools-3.1.0-win-x64.zip |
| 124.8 MB | 2025-07-10 | E:\Users\文少\Downloads\mgltools_x86_64Linux2_1.5.7p1.tar.gz |
| 124.8 MB | 2025-11-03 | D:\桌面\学位论文开题用表\宏基因组\EasyMetagenome-1.21.zip |
| 124.8 MB | 2025-11-03 | D:\桌面\学位论文开题用表\宏基因组\EasyMetagenome-1.21.zip |
| 123.8 MB | 2025-05-31 | E:\Users\文少\Downloads\Python-100-Days-master.zip |
| 118.9 MB | 2025-02-25 | E:\xunlei\EndNote21.5(64bit).zip |
| 118.0 MB | 2025-07-05 | E:\Users\文少\Downloads\14eeb709-b9ce-4637-8bed-d14fea0067d3-B.rar |
| 117.7 MB | 2025-03-29 | E:\Users\文少\Downloads\DirectX_Repair增强版_v4.3.7z |
| 115.4 MB | 2020-09-03 | E:\0wangyao\wangyao\raw\1\GSE157827\RAW\GSM4775568_AD10_matrix.mtx.gz |
| 115.4 MB | 2026-07-04 | E:\0wangyao\wangyao\raw\1\GSE157827\GSM4775568_AD10\matrix.mtx.gz |
| 115.3 MB | 2020-09-03 | E:\0wangyao\wangyao\raw\1\GSE157827\RAW\GSM4775562_AD2_matrix.mtx.gz |
| 115.3 MB | 2026-07-04 | E:\0wangyao\wangyao\raw\1\GSE157827\GSM4775562_AD2\matrix.mtx.gz |

### 其他大文件 >= 200 MB, 共 69 个, 前 20

| 大小 | 修改日期 | 文件 |
|---|---|---|
| 18.27 GB | 2026-09-19 | E:\Tencent Games\VALORANT\live\ShooterGame\Content\Paks\pakchunk10-WindowsClient.ucas |
| 6.19 GB | 2026-09-19 | E:\Tencent Games\VALORANT\live\ShooterGame\Content\Paks\pakchunk1-WindowsClient.ucas |
| 2.50 GB | 2026-09-19 | E:\Tencent Games\VALORANT\live\ShooterGame\Content\Paks\pakchunk0-WindowsClient.ucas |
| 2.00 GB | 2026-09-19 | E:\Tencent Games\VALORANT\live\ShooterGame\Content\Paks\pakchunk0-WindowsClient.pak |
| 863.4 MB | 2025-08-10 | E:\BaiduNetdiskDownload\MolAICal\current\MolAICal-win64-v1.3.zip.baiduyun.p.downloading |
| 718.1 MB | 2026-07-04 | E:\0wangyao\wangyao\processed\seurat_list_clean.rds |
| 649.8 MB | 2022-03-08 | D:\桌面\Win版 PDF 2023【必须win10、11】\Data1.CAB |
| 649.8 MB | 2022-03-08 | D:\桌面\Win版 PDF 2023【必须win10、11】\Data1.CAB |
| 625.7 MB | 2024-05-21 | D:\桌面\origin\Setup\data2.cab |
| 625.7 MB | 2024-05-21 | D:\桌面\origin\Setup\data2.cab |
| 573.4 MB | 2026-09-30 | E:\Tencent Files\2845346805\nt_qq\nt_db\nt_msg.db |
| 537.8 MB | 2026-09-19 | E:\Tencent Games\VALORANT\live\ShooterGame\Content\Paks\pakchunk2-WindowsClient.ucas |
| 521.5 MB | 2026-09-19 | E:\Tencent Games\VALORANT\live\ShooterGame\Content\Paks\pakchunk3-WindowsClient.ucas |
| 494.3 MB | 2026-09-29 | E:\google\GoogleUpdater\crx_cache\11b1217f1a4cddf2df3e88a560eeae873c98e8611c038bc02b000725116ae45b |
| 490.5 MB | 2025-04-24 | E:\gmx2020.6_GPU\bin\-7.8_jiodng\trj_10-20ns.xtc |
| 490.5 MB | 2025-04-24 | E:\gmx2020.6_GPU\a\肌动蛋白处理\Chavicine_1HLU1-7.6\trj_10-20ns.xtc |
| 490.4 MB | 2025-04-24 | E:\gmx2020.6_GPU\a\肌动蛋白处理\piperettine_1HLU2-7.7\trj_10-20ns.xtc |
| 449.5 MB | 2024-12-10 | E:\Compressed\WSA_2407.40000.4.0_x64_Release-Nightly-GApps-13.0-NoAmazon\WSA_2407.40000.4.0_x64\Tools\initrd.img |
| 440.5 MB | 2026-06-20 | E:\0md\1\test1c\md_fit.xtc |
| 424.2 MB | 2025-08-07 | E:\ST\ST\90-100.xtc |


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
