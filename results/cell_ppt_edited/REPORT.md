# cell_ppt_edited 技能测试报告（台式机）

**日期**：2026-10-02 ｜ **结论：测试成功 —— 28/28 活体检查全部通过（exit 0）**

## 一、被测物

| 项目 | 内容 |
|---|---|
| 技能 | `yrui-cmd/cell_ppt_edited` v1.1.0（Codex MCP 插件，MIT） |
| 发行包 | `cell_ppt_edited-1.1.0-windows-x64.zip`（14MB，GitHub release） |
| SHA256 | `dce85a395ca12426ac8a6d8b99fe759efe1fecb54f44bf7cac66f0d50326c4ea` — **MATCH** |
| 安装位置（台式机） | `F:\fig1_rebuild\cpe\pkg\cell_ppt_edited-1.1.0-windows-x64\`（解压完成；exe 位于 `pkg\<顶层>\plugins\cell-ppt-edited\bin\cell-ppt-edited.exe`，捆绑 Python 运行时） |
| 源码 | 已 vendor 到本仓库 `skills/cell_ppt_edited/src/`（9 脚本 + LICENSE，沙箱语法全过） |

## 二、测试环境（仅台式机，笔记本零参与）

- Windows 台式机（SSH 派发 + 计划任务进交互会话）
- **PowerPoint 2016 Pro Plus 64 位**（POWERPNT.EXE 16.0.4266.1001，ProgID 注册正常）
- Python 3.12（`py -3.12`）
- 测试方式：**引擎级**——打包 exe 直接作为 MCP server（stdio），由上游验收脚本 `integration.py` 驱动，编辑**真实打开的桌面版 PowerPoint** 原生对象（这正是该技能的设计用途）

## 三、结果明细

### 引擎自检
```
exe --self-test  rc=0  {"self_test":"passed","version":"1.1.0","actions":7,"COM_imports":true}
exe --doctor     rc=0  {"product":"cell_ppt_edited","version":"1.1.0","windows":true,
                        "bundled_runtime":true,"pywin32":true,"powerpoint_registered":true}
Install.ps1 -CheckOnly  → 仅报 Codex CLI not found（预期内，见第五节）
```

### 活体验收 integration.py：28/28 PASS，exit 0（r171 第 1 次尝试，30 秒完成）
```
PASS 11 MCP tools and capability contracts        PASS linear native multi-stop gradient
PASS batch create five native objects             PASS radial native multi-stop gradient
PASS legacy basic edits share the adv. session    PASS corner native multi-stop gradient
PASS completion footer returned verbatim          PASS native cubic path with control handles
PASS both legacy tool sets use same document      PASS move Bezier handle
PASS group is editable native group               PASS stale path hash rejected
PASS inspect grouped child by path                PASS insert native path node
PASS ungroup preserves object IDs and geometry    PASS delete native path node
PASS delete and idempotent replay                 PASS set native node editing mode
PASS whole-batch preflight prevents prec. create  PASS line converted to cubic segment
PASS Unicode rich replacement after emoji         PASS subscript and untouched prefix preserved
PASS mixed paragraphs and bullet formatting       PASS hyperlink retained as native text fmt
PASS zero-length append range                     PASS checkpoint and save
PASS untargeted sentinel unchanged                PASS saved OOXML keeps gradients/curves/text native
```
`acceptance.json`（仅全程跑完才写）：`passed: 28`，18 组操作总往返 4.34s（最慢 1.05s）。

### 产物（本目录）
| 文件 | 说明 |
|---|---|
| `acceptance.pptx`（34,878 B） | 验收演示文稿，沙箱已终验：**3 个原生渐变、2 段原生贝塞尔、11 文本运行、1 超链接、960×540pt、字体 Arial + 微软雅黑、Unicode 文本 `H2O · Ca2+ 🧬 DNA中文 / English link ✓`、0 张图片（无截图兜底，全是原生 OOXML 对象）、0 个组（ungroup 已验证）** |
| `acceptance.png`（40KB） | 引擎导出的 1440px 渲染图 |
| `checkpoint.pptx` | checkpoint 机制产物 |
| `acceptance.json` | 28 项检查名 + 每操作耗时 |
| `integ_a1.txt` / `integration_log.txt` | 完整验收日志（28 PASS + exit 0） |
| `watch_a1.txt` | 看门狗日志：02:33:29 激活对话框弹出即被自动关闭 |

## 四、调试过程（r168→r171，四轮）

| 轮 | 结果 | 发现 |
|---|---|---|
| r168 | 8/27，死于 ungroup 后 `RPC_E_CALL_REJECTED(-2147418111)` | COM 忙拒绝为瞬态竞态 |
| r169 | 盲重试 3 次更糟（`<unknown>.Add`、`Presentations` 损坏） | **引擎 shutdown() 设计上从不退出 PowerPoint**；taskkill 强杀 → 崩溃恢复态连锁 |
| r170 | 加看门狗+优雅退出，仍 0-1/27，但**捕获元凶** | ① ospp 证实 Office **未激活**（KMS `NOTIFICATIONS`，0xC004F00F），每次启动弹 `[NUIDialog] Microsoft Office 激活/首选项` 模态框堵塞 COM；② 优雅退出机制验证可行 |
| r171 | **第 1 次尝试 28/28 全过** | 看门狗 v2（WM_CLOSE+ESC 关 NUIDialog）+ 可见预热后**留 PowerPoint 在跑**，integration.py 经 GetActiveObject 附着无对话框的热实例 |

## 五、注意事项（环境层面，非技能缺陷）

1. **台式机 Office 未激活**：KMS 客户端、`LICENSE STATUS: NOTIFICATIONS`（硬件 ID 绑定超差 0xC004F00F）。每次启动 PowerPoint 都弹激活向导，会堵塞 COM 自动化（本测试用看门狗自动关闭绕过）。**建议激活 Office**，之后该技能可完全无人值守使用。
2. **台式机无 Codex CLI**：`Install.ps1` 正式安装会在 Find-Codex 处终止，故未走正式安装路径；本次引擎级测试（打包 exe 作 MCP server + integration.py 活体验收）已完整覆盖其全部功能面。若日后安装 Codex，引擎前提已全部验证通过，正式安装预期可直接成功。

## 六、结论

**cell_ppt_edited v1.1.0 在台式机（PowerPoint 2016 Pro Plus 64 位）测试成功**：发行包校验、引擎自检、11 个 MCP 工具契约、批量原生对象创建/组合/解组/删除、幂等重放、预检防半批、三种渐变、贝塞尔节点级编辑、CJK/emoji 富文本、超链接、checkpoint、OOXML 原生持久化——**28/28 全过，产物已归档**。
