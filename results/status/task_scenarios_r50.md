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


## 四、n8n 工作流


## 五、R 语言环境


## 六、大文档清单（供取舍）
### 文档类 >= 10 MB, 共 219 个, 前 80

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
| 55.3 MB | 2025-01-16 | D:\桌面\1\2月\1月\AI\1pdf.pdf |
| 55.3 MB | 2025-01-16 | D:\桌面\1\2月\1月\AI\1pdf.pdf |
| 54.9 MB | 2025-01-16 | D:\桌面\1\2月\1月\AI\3.pdf |
| 54.9 MB | 2025-01-16 | D:\桌面\1\2月\1月\AI\3.pdf |
| 54.9 MB | 2025-01-17 | D:\桌面\1\2月\1月\JIUDONG.pdf |
| 54.9 MB | 2025-01-17 | D:\桌面\1\2月\1月\JIUDONG.pdf |
| 52.7 MB | 2026-06-11 | D:\桌面\AI\gong\考公学习资料-江西省考\江西公务员考试真题pdf版\江西公务员考试真题——行测06-22PDF版\答案及解析\2022年江西省公务员录用考试《行测》题（网友回忆版）答案与解析.pdf |
| 52.7 MB | 2026-06-11 | D:\桌面\AI\gong\考公学习资料-江西省考\江西公务员考试真题pdf版(1)\江西公务员考试真题——行测06-22PDF版\答案及解析\2022年江西省公务员录用考试《行测》题（网友回忆版）答案与解析.pdf |
| 52.7 MB | 2026-06-11 | D:\桌面\AI\gong\考公学习资料-江西省考\江西公务员考试真题pdf版\江西公务员考试真题——行测06-22PDF版\答案及解析\2022年江西省公务员录用考试《行测》题（网友回忆版）答案与解析.pdf |
| 52.7 MB | 2026-06-11 | D:\桌面\AI\gong\考公学习资料-江西省考\江西公务员考试真题pdf版(1)\江西公务员考试真题——行测06-22PDF版\答案及解析\2022年江西省公务员录用考试《行测》题（网友回忆版）答案与解析.pdf |
| 51.8 MB | 2025-01-16 | D:\桌面\1\2月\1月\AI\2.pdf |
| 51.8 MB | 2025-01-16 | D:\桌面\1\2月\1月\AI\2.pdf |
| 48.2 MB | 2025-06-23 | E:\xwechat_files\wxid_n7lel2eo7ouj22_8412\msg\file\2025-06\世界鸟类分类与分布名录(第2版) (郑光美) (Z-Library).pdf |
| 48.2 MB | 2025-06-23 | E:\微信\WeChat Files\wxid_n7lel2eo7ouj22\FileStorage\File\2025-06\世界鸟类分类与分布名录(第2版) (郑光美) (Z-Library).pdf |
| 45.9 MB | 2026-03-20 | E:\xwechat_files\wxid_n7lel2eo7ouj22_8412\msg\file\2026-03\多肽提取、鉴定及虚拟筛选.pptx |
| 43.4 MB | 2025-11-03 | D:\桌面\学位论文开题用表\抗菌肽\1\2\AMP_filtered.tsv |
| 43.4 MB | 2025-11-03 | D:\桌面\学位论文开题用表\抗菌肽\1\2\AMP_filtered.tsv |
| 38.9 MB | 2026-06-11 | D:\桌面\AI\gong\考公学习资料-江西省考\江西公务员考试真题pdf版(1)\江西公务员考试真题——行测06-22PDF版\题目\2022年江西省公务员录用考试《行测》题（网友回忆版）.pdf |
| 38.9 MB | 2026-06-11 | D:\桌面\AI\gong\考公学习资料-江西省考\江西公务员考试真题pdf版\江西公务员考试真题——行测06-22PDF版\题目\2022年江西省公务员录用考试《行测》题（网友回忆版）.pdf |
| 38.9 MB | 2026-06-11 | D:\桌面\AI\gong\考公学习资料-江西省考\江西公务员考试真题pdf版\江西公务员考试真题——行测06-22PDF版\题目\2022年江西省公务员录用考试《行测》题（网友回忆版）.pdf |
| 38.9 MB | 2026-06-11 | D:\桌面\AI\gong\考公学习资料-江西省考\江西公务员考试真题pdf版(1)\江西公务员考试真题——行测06-22PDF版\题目\2022年江西省公务员录用考试《行测》题（网友回忆版）.pdf |
| 38.2 MB | 2026-01-24 | E:\Users\文少\Downloads\20210604142009_134.pdf |
| 37.8 MB | 2026-08-24 | E:\Users\文少\Downloads\东华大学-卢婷婷-答辩通用PPT模板.pptx |
| 37.0 MB | 2026-09-23 | E:\Users\文少\Downloads\宿舍用电常见情况处理(6).doc |
| 36.8 MB | 2023-02-06 | D:\MobileFile\pdf-1.pdf |
| 35.4 MB | 2024-11-03 | D:\桌面\1\2月\1月\天然产物与多糖对接\阿魏酸.pdf |
| 35.4 MB | 2024-11-03 | D:\桌面\1\2月\1月\天然产物与多糖对接\阿魏酸.pdf |
| 35.2 MB | 2022-11-12 | D:\MobileFile\科二四组遗传学第五章.pptx |
| 35.0 MB | 2026-01-08 | D:\桌面\学位论文开题用表\肠道抗菌肽区域异质性及其调控机制研究.pdf |
| 35.0 MB | 2026-01-08 | D:\桌面\学位论文开题用表\肠道抗菌肽区域异质性及其调控机制研究.pdf |
| 34.5 MB | 2025-03-11 | D:\桌面\论文\Interaction study of Components of Black Pepper wi.docx |
| 34.5 MB | 2025-03-11 | D:\桌面\论文\Interaction study of Components of Black Pepper wi.docx |
| 29.4 MB | 2025-01-14 | D:\桌面\1\2月\1月\ZONG.pptx |
| 29.4 MB | 2025-01-14 | D:\桌面\1\2月\1月\ZONG.pptx |
| 27.4 MB | 2025-01-16 | D:\桌面\1\2月\1月\演示文稿4.pptx |
| 27.4 MB | 2025-01-16 | D:\桌面\1\2月\1月\演示文稿4.pptx |
| 25.4 MB | 2025-01-14 | D:\桌面\1\2月\1月\文字文稿2.docx |
| 25.4 MB | 2025-01-14 | D:\桌面\1\2月\1月\文字文稿2.docx |
| 22.8 MB | 2026-06-16 | E:\Users\文少\Downloads\007cb874-6efa-4bb4-a541-965092b7831d(1).pdf |
| 22.8 MB | 2024-03-06 | D:\桌面\machine_learning-main\machine_learning-main\机器学习实战14-超导体的实战应用\train.csv |
| 22.8 MB | 2024-03-06 | D:\桌面\machine_learning-main\machine_learning-main\机器学习实战14-超导体的实战应用\train.csv |
| 22.6 MB | 2026-01-11 | E:\Users\文少\Downloads\2. 降脂肽方法.docx |
| 22.5 MB | 2026-01-14 | D:\桌面\降脂肽\1\2. 材料与方法 (Materials and Methods).docx |
| 22.5 MB | 2026-01-14 | D:\桌面\降脂肽\1\2. 材料与方法 (Materials and Methods).docx |
| 22.5 MB | 2026-01-14 | D:\桌面\降脂肽\1\2.7 体外生物活性实验验证 (In Vitro Bioactivity Validation).docx |
| 22.5 MB | 2026-01-14 | D:\桌面\降脂肽\1\2.7 体外生物活性实验验证 (In Vitro Bioactivity Validation).docx |
| 20.7 MB | 2026-02-24 | D:\桌面\Latex\hujiaojian\MYOSIN-讨论结果分.docx |
| 20.7 MB | 2026-02-24 | D:\桌面\Latex\hujiaojian\MYOSIN-讨论结果分.docx |
| 20.4 MB | 2026-02-22 | D:\桌面\Latex\hujiaojian\Myosin 蛋白SCI论文撰写指导.docx |
| 20.4 MB | 2026-02-22 | D:\桌面\Latex\hujiaojian\Myosin 蛋白SCI论文撰写指导.docx |
| 19.8 MB | 2026-02-27 | D:\桌面\Latex\hujiaojian\ACTIN-讨论结果分.docx |
| 19.8 MB | 2026-02-27 | D:\桌面\Latex\hujiaojian\ACTIN-讨论结果分.docx |
| 19.1 MB | 2026-08-16 | E:\微信\xwechat_files\wxid_n7lel2eo7ouj22_8412\msg\file\2026-08\Deep Learning with Python-Francois_Chollet-中文-Python深度学习-2018.pdf |
| 18.5 MB | 2026-03-30 | E:\xwechat_files\wxid_n7lel2eo7ouj22_8412\msg\file\2026-03\ph-0025-0020.pdf |
| 18.5 MB | 2025-11-10 | D:\桌面\学位论文开题用表\Explainable-deep-learning-and-virtual-evolution-identifies-antimicrobial-peptides-with-activity.pdf |
| 18.5 MB | 2025-11-10 | D:\桌面\学位论文开题用表\Explainable-deep-learning-and-virtual-evolution-identifies-antimicrobial-peptides-with-activity.pdf |
| 18.3 MB | 2026-04-20 | D:\桌面\AI\yzy\Oral_Metatranscriptome_MetaAnalysis-main\Oral_Metatranscriptome_MetaAnalysis-main\Data_handling.ipynb |
| 18.3 MB | 2026-04-20 | D:\桌面\AI\yzy\Oral_Metatranscriptome_MetaAnalysis-main\Oral_Metatranscriptome_MetaAnalysis-main\Data_handling.ipynb |
| 18.0 MB | 2026-02-22 | D:\桌面\Latex\hujiaojian\Actin蛋白SCI论文撰写指导.docx |
| 18.0 MB | 2026-02-22 | D:\桌面\Latex\hujiaojian\Actin蛋白SCI论文撰写指导.docx |
| 17.6 MB | 2026-01-09 | E:\Users\文少\Downloads\AI_Mapping_Gut_Peptides_in_Alzheimer_s.pdf |
| 17.5 MB | 2026-06-05 | E:\xwechat_files\wxid_n7lel2eo7ouj22_8412\msg\file\2026-06\ChemistrySelect - 2022 - Heravi - Construction and Aromatization of Hantzsch 1 4‐Dihydropyridines under Microwave.pdf |
| 17.4 MB | 2022-03-10 | D:\桌面\machine_learning-main\Coursera-ML-AndrewNg-Notes-master\Coursera-ML-AndrewNg-Notes-master\docx\机器学习个人笔记完整版v5.52.docx |
| 17.4 MB | 2022-03-10 | D:\桌面\machine_learning-main\Coursera-ML-AndrewNg-Notes-master\Coursera-ML-AndrewNg-Notes-master\docx\机器学习个人笔记完整版v5.52.docx |
| 17.2 MB | 2025-10-27 | E:\xwechat_files\wxid_n7lel2eo7ouj22_8412\msg\file\2025-10\PIIS0092867425011262.pdf |
| 16.8 MB | 2024-09-11 | D:\桌面\回收站\功能糖\之前文档\功能糖的总结.docx |
| 16.8 MB | 2024-09-11 | D:\桌面\回收站\功能糖\之前文档\功能糖的总结.docx |
| 16.6 MB | 2025-03-27 | D:\桌面\研一下学期\1\微生物及应用\文献.pdf |
| 16.6 MB | 2025-03-27 | D:\桌面\研一下学期\1\微生物及应用\文献.pdf |
| 16.4 MB | 2025-12-24 | D:\桌面\学位论文开题用表\抗菌肽\Explainable deep learning and virtual evolution identifies antimicrobial peptides with activity against multidrug-resistant human pathogens.pdf |
| 16.4 MB | 2025-12-24 | D:\桌面\学位论文开题用表\抗菌肽\Explainable deep learning and virtual evolution identifies antimicrobial peptides with activity against multidrug-resistant human pathogens.pdf |

### 压缩包/数据集 >= 50 MB, 共 62 个, 前 40

| 大小 | 修改日期 | 文件 |
|---|---|---|
| 488.7 MB | 2026-08-11 | E:\迅雷云盘\WPSOffice_雨糖科技特别版_2019_11.8.2.12344_x86_20260806.zip |
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
| 130.9 MB | 2025-08-26 | E:\v2rayN-windows-64-SelfContained.zip |
| 128.3 MB | 2026-07-03 | E:\Users\文少\Downloads\ACDLabs202525_ChemSketch_FInstall.zip |
| 126.3 MB | 2026-08-20 | E:\Users\文少\Downloads\v2rayN-windows-64-desktop.zip |
| 125.2 MB | 2026-08-15 | E:\Users\文少\Downloads\ZTools-3.1.0-win-x64.zip |
| 124.8 MB | 2025-07-10 | E:\Users\文少\Downloads\mgltools_x86_64Linux2_1.5.7p1.tar.gz |
| 124.8 MB | 2025-11-03 | D:\桌面\学位论文开题用表\宏基因组\EasyMetagenome-1.21.zip |
| 124.8 MB | 2025-11-03 | D:\桌面\学位论文开题用表\宏基因组\EasyMetagenome-1.21.zip |
| 123.8 MB | 2025-05-31 | E:\Users\文少\Downloads\Python-100-Days-master.zip |
| 118.9 MB | 2025-02-25 | E:\xunlei\EndNote21.5(64bit).zip |
| 118.0 MB | 2025-07-05 | E:\Users\文少\Downloads\14eeb709-b9ce-4637-8bed-d14fea0067d3-B.rar |
| 117.7 MB | 2025-03-29 | E:\Users\文少\Downloads\DirectX_Repair增强版_v4.3.7z |
| 110.8 MB | 2026-04-04 | D:\桌面\AI\复刻论文图\AutoFigure-Edit-main.zip |
| 110.8 MB | 2026-04-04 | D:\桌面\AI\复刻论文图\AutoFigure-Edit-main.zip |
| 110.5 MB | 2025-11-11 | E:\Users\文少\Downloads\Xndaiuwtd.zip |
| 109.4 MB | 2025-03-27 | E:\Users\文少\Downloads\smartgit_24.1.1_portable.7z |
| 105.4 MB | 2025-07-02 | E:\Users\文少\Downloads\ailearning-2.0.zip |
| 104.1 MB | 2025-02-20 | E:\VM\windows.iso |
| 104.0 MB | 2025-07-19 | E:\Users\文少\Downloads\fpocket-4.2.2.zip |
| 94.5 MB | 2026-04-14 | E:\Users\文少\Downloads\sratoolkit.2.11.0-centos_linux64.tar.gz |
| 90.5 MB | 2026-07-21 | E:\Users\文少\Downloads\AMDock-win-master.zip |
| 87.9 MB | 2025-01-03 | E:\Users\文少\Downloads\gmx2020.6_AVX2_CUDA_win64.rar |
| 86.2 MB | 2026-08-14 | E:\Users\文少\Downloads\copytranslator-12.1.0-win.zip |
| 81.0 MB | 2026-06-23 | E:\xwechat_files\wxid_n7lel2eo7ouj22_8412\msg\file\2026-06\win版绿盟vpn客户端使用说明.rar |

### 其他大文件 >= 200 MB, 共 22 个, 前 20

| 大小 | 修改日期 | 文件 |
|---|---|---|
| 649.8 MB | 2022-03-08 | D:\桌面\Win版 PDF 2023【必须win10、11】\Data1.CAB |
| 649.8 MB | 2022-03-08 | D:\桌面\Win版 PDF 2023【必须win10、11】\Data1.CAB |
| 625.7 MB | 2024-05-21 | D:\桌面\origin\Setup\data2.cab |
| 625.7 MB | 2024-05-21 | D:\桌面\origin\Setup\data2.cab |
| 417.7 MB | 2025-12-19 | E:\Users\文少\Downloads\c_AMPs-prediction-master\c_AMPs-prediction-master\Models\bert.bin |
| 416.4 MB | 2025-01-22 | D:\桌面\DataEase-win32-x64\resources\app.asar |
| 416.4 MB | 2025-01-22 | D:\桌面\DataEase-win32-x64\resources\app.asar |
| 416.1 MB | 2026-05-08 | D:\桌面\AI\ai\healthy_specific.fasta |
| 416.1 MB | 2026-05-08 | D:\桌面\AI\ai\healthy_specific.fasta |
| 411.7 MB | 2026-09-16 | E:\新建文件夹\Weixin\4.1.13.65\RadiumWMPF.bin |
| 410.1 MB | 2026-07-20 | E:\视频md\pymol.mp4 |
| 399.0 MB | 2026-05-08 | D:\桌面\AI\ai\periodontitis_specific.fasta |
| 399.0 MB | 2026-05-08 | D:\桌面\AI\ai\periodontitis_specific.fasta |
| 341.4 MB | 2023-06-02 | D:\LenovoQMDownload\SoftMgr\XYAZ-Setup-lenovo-8.1.5-hab629b4fe.exe.part |
| 313.7 MB | 2017-05-11 | D:\new\MEGA11\cef_sandbox.lib |
| 265.1 MB | 2026-04-04 | E:\Users\文少\Downloads\bybit.apk |
| 261.4 MB | 2026-05-18 | D:\桌面\AI\yijian\duijie.tif |
| 261.4 MB | 2026-05-18 | D:\桌面\AI\yijian\duijie.tif |
| 241.8 MB | 2026-08-20 | E:\VSCodeData\Extensions\openai.chatgpt-26.818.21641-win32-x64\bin\linux-x86_64\codex |
| 224.3 MB | 2026-09-08 | E:\WpSystem\S-1-5-21-2081821339-301707966-4042885555-1003\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Roaming\Codex\web\Codex\windows-msix-updater\OpenAI.Codex_2p2nqsd0c76g0\ChatGPT-x64.msix.download |


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
