# harness-anything 接管 WPS 制作可编辑 PPTX — 最终报告

日期：2026-10-02　状态：**双机测试成功**（台式机全流程 / 笔记本文字流程；笔记本演示流程按用户要求取消）

## 交付物（结果路径）

| 机器 | 文件 | 路径 | 说明 |
|---|---|---|---|
| 台式机 | **arena_report.pptx** | `F:\fig1_rebuild\harness_results\arena_report.pptx` | **12 页可编辑中文汇报 PPT**（75KB） |
| 台式机 | test_writer.docx | `F:\fig1_rebuild\harness_results\test_writer.docx` | 文字流程冒烟（10KB） |
| 仓库 | **arena_report.pptx** | `results/harness_wps/desktop/arena_report.pptx` | 同一文件的 git 副本 |
| 仓库 | 其余产物 | `results/harness_wps/desktop/`（proj_deck.json 等 6 件）、`results/harness_wps/laptop/`（test_writer.docx 等 3 件） | 项目 JSON + 冒烟产物 |

台式机 repo 根：`E:\0github\git-sync\git-pull-arena-01a0a9f0`（同仓库路径结构）。

## 12 页 deck 内容（全部由 WPS COM 写入，可继续编辑）

封面 → 三大任务 → git-sync 观察者环 → 登录修复（根因/五层修复栈/成果）→
IDE 双机同步 → harness-anything 接管 WPS → 引擎健康探测补丁 → 测试矩阵 →
本演示文稿即证明 → 下一步

**终验（沙箱结构级）**：12/12 页、OOXML 齐全（[Content_Types] + presentation.xml + 26 布局 + 4 母版）、
0 个 XML 解析错误、212 个文本段、全部内容标记命中。WPS COM 引擎版本 12.0（KWPP）。

## 安装与修复全记录（台式机）

1. **WPS 安装**：官方离线包 `WPS_Setup_X64_22525.exe`（296MB，wpscdn 断点续传后台任务磨完）
   → 静默参数 `/s -agreelicense`（裸 `/S` 是无效的）→ WPS 12.1.0.22525 全组件就位。
2. **COM 注册**（22525 版已知缺陷：安装器不注册 COM，修复工具也无效）：
   `HKLM\SOFTWARE\Classes` 手工注册 KWPS/KET/KWPP → CLSID → LocalServer32 =
   `ksolaunch.exe /prometheus /wps|et|wpp /Automation`（**/Automation 参数是关键**，裸 exe 会 0x80080005）。
3. **harness 适配补丁**（全部在 vendored 副本 `skills/harness-anything/`）：
   - WPP 引擎健康探测（候选链 + 重试）
   - `Slides(1)` → `Slides.Add` 兜底；`SaveAs2` → `SaveAs` 回退（WPS 12 未实现 SaveAs2）
   - `_fill_impress` v2 渲染器：title/content 正确落位 + **text_box 元素真渲染**（分数坐标/cm/pt）
4. **WPS 12 KWPP 单客户端怪癖的解法**：冷启动的 KWPP 在首个 COM 调用即死；热实例只认第一个客户端。
   解法 = 交互计划任务保温 wpp.exe + **单进程一体化构建**（`code/tasks/deck_warm_build.py`：
   同一 python 进程内 harness impress 模块授权构建 → 附着渲染 → SaveAs → 收尾）。

## 测试矩阵

| 测试 | 笔记本 | 台式机 |
|---|---|---|
| harness 离线安装（vendor wheels） | ✅ | ✅ |
| writer → 可编辑 docx（COM 重开验证） | ✅（r141，paragraphs=3） | ✅（r155/160，10KB） |
| impress → 可编辑 pptx | 用户取消 | ✅（**12 页 deck + PK/OOXML/文本终验**） |

## 遗留（无害）

- WPS 12 KWPP 同一 App 会话内第二张 Presentations.Add 会失败（单客户端怪癖）——deck 构建已规避，后续批量生成采用"每 App 会话一份演示文稿"模式。
- 笔记本 KWPP（WPS 11 演示组件）COM 为存量缺陷（r139 起始即存在，与本次操作无关），修复待排期。
- 台式机残留计划任务 wpplaunch/wpstest2/wpsdl（一次性，惰性，无害）。
