# Computer-use 多后端互补能力清单（R218）

生成时间：2026-10-02

## 结论

1. Antigravity 的终端 CLI 确实可用，但它更适合从终端打开文件/文件夹/工作区；真正要自动完成 Antigravity 对话任务，目前更稳定的是 CDP/Electron DOM 路线。
2. 已证明 Antigravity 对话可自动输入并提交：R212 使用 CDP 找到 `Message input`，通过 `Input.insertText` 写入并提交，提交后 marker 出现在 DOM 中。
3. 多个 computer-use 项目/后端互补是必要的：一个项目不全能，组合后覆盖更稳。
4. 笔记本已按要求放在 `E:\0mcp-agv-arena-optimized`。
5. 台式机实测没有可用的 `E:` 盘：`e_drive_available=False`，`F:` 可用，所以台式机只能落到 `F:\0mcp-agv-arena-optimized` 作为兜底；如果必须严格 E 盘，需要先在台式机创建/挂载 E 盘。

## 关键报告路径

### 笔记本

- 主清单：`E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-laptop-r213.md`
- JSON：`E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-laptop-r213.json`
- Antigravity 对话成功记录：`E:\0mcp-agv-arena-optimized\reports\antigravity-cdp-targeted-message-input-r212.json`

### 台式机

- 实测结果：台式机无 `E:`，使用 `F:` 兜底。
- 主清单：`F:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-desktop-r218.md`
- JSON：`F:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-desktop-r218.json`
- 仓库副本：`results/mcp_agv_lab/computer-use-capability-audit-desktop-r218.md`

## 多后端互补成功案例

| 步骤 | 后端/项目 | 完成的任务 | 结果 |
|---|---|---|---|
| 1 | Antigravity CLI | 从终端打开 E/F 盘 probe 文件或工作区 | 成功发起 |
| 2 | CDP / Electron DOM | 操作 Antigravity 对话输入框并提交消息 | R212 成功 |
| 3 | windows-computer-use MCP/UIA | 在 E 盘 WinForms 测试程序中查找按钮并 Invoke | R213 成功写入 marker |
| 4 | software-ops wrappers | 检查 Antigravity、v2rayN、GreenVPN、WPS、Illustrator | 成功 |
| 5 | WPS COM | Writer/Sheet/Presentation COM 实例化 | 笔记本、台式机均 OK |

## 笔记本可操作软件清单

| 软件/对象 | 后端 | 本轮测试任务 | 结果 | 能完成的任务 |
|---|---|---|---|---|
| Antigravity | CLI | 打开 E 盘 probe 文件/工作区 | OK_ISSUED | 启动、打开文件/文件夹/工作区 |
| Antigravity chat | CDP/Electron DOM | 输入并提交对话 marker | OK_PROVEN_R212 | 自动完成对话类任务、提交 prompt |
| windows-computer-use | MCP/UIA | 安装/存在检查 | OK | Windows UIA 查找、Invoke、截图/控件操作 |
| Windows-MCP | MCP 项目 | 安装/存在检查 | OK | 作为 Windows 操作 MCP 后端候选 |
| pywinauto-mcp | pywinauto MCP 项目 | 安装/存在检查 | OK | 作为 UIA/pywinauto 兜底后端候选 |
| WinForms 测试程序 | windows-computer-use MCP/UIA | find 按钮 + invoke | OK | 普通 Windows GUI 按钮可靠操作 |
| v2rayN/xray | software-ops | 状态检查，18088 bridge | OK | 代理/bridge 状态检查、后续可重启/切换 |
| GreenVPN | software-ops | 进程/启动项检查 | OK | 状态检查、启动 |
| WPS Office | COM | KWPS/KET/KWPP COM 实例化 | OK | PPT/文档/表格自动化，已有 WPS PPT 成果 |
| Adobe Illustrator | path/process probe | 检测 Illustrator.exe | OK | 可做启动/检测，后续可加专用 COM/UIA 动作 |
| File Explorer | shell CLI | 打开 E 盘 lab 文件夹 | OK_CAPABLE | 文件夹打开、文件定位 |
| Notepad | process/file CLI | 检测 notepad.exe | OK_CAPABLE | 打开/编辑文本文件 |

## 台式机可操作软件清单

> 注意：台式机本轮明确检测到 `e_drive_available=False`，因此无法严格安装到 E 盘；已用 `F:\0mcp-agv-arena-optimized` 兜底。

| 软件/对象 | 后端 | 本轮测试任务 | 结果 | 能完成的任务 |
|---|---|---|---|---|
| windows-computer-use | F 盘兜底安装 | 项目源码展开，backend 存在 | OK | Windows GUI UIA 后端可用 |
| Windows-MCP | F 盘兜底安装 | 项目源码展开 | OK | Windows MCP 后端候选 |
| pywinauto-mcp | F 盘兜底安装 | 项目源码展开 | OK | pywinauto/UIA 后端候选 |
| Antigravity | CLI | 打开 probe 文件/工作区 | OK_ISSUED | 启动、打开文件/文件夹/工作区 |
| Antigravity | app-specific status + bridge | 安装/进程/proxy 检查 | OK，版本 2.15.1.0，18088=True | 状态检查、bridge 验证、后续可配合 CDP |
| v2rayN/xray | process + port status | 检查进程和 18088 | OK | 代理/bridge 状态检查 |
| GreenVPN | app-specific status | 检查安装和进程 | OK，路径 `F:\NsfocusVPN\NsfocusVPN.exe` | 状态检查、启动 |
| WPS Office | COM | KWPS/KET/KWPP COM 实例化 | OK | 文档/表格/PPT 自动化 |
| Adobe Illustrator | path/process probe | 检测 Illustrator.exe | OK，位于 F 盘 | 可做启动/检测，后续可加专用动作 |
| File Explorer | shell CLI | 打开 lab 文件夹 | OK_CAPABLE | 文件夹打开、文件定位 |
| Notepad | process/file CLI | 检测 notepad.exe | OK_CAPABLE | 打开/编辑文本文件 |

## 限制

- Antigravity CLI 不是完整的 chat/agent 自动化接口；它适合 launch/open，实际对话操作仍建议用 CDP。
- UIA 对 Antigravity 不可靠；R208/R209 已证明 UIA 只能看到标题栏/CaptionButton，CDP 才能操作真实输入框。
- 不是所有软件都能保证自动化；管理员权限、UAC、安全桌面、反自动化、无 UIA 节点、全屏/游戏类界面都会降低成功率。
- 台式机没有可用 E 盘，因此没有办法真正把文件写到 E 盘；若需要严格 E 盘，需要先在台式机提供 E 盘或挂载点。
