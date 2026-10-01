# cell_ppt_edited

**在已经打开的 Windows PowerPoint 中，快速编辑原生对象。**

PPT Turbo 与 PPT Turbo Studio 合并后的开源发行版。使用独立常驻 COM 引擎，通过 MCP 供 Codex 调用，不依赖 Scientific Illustrator。所有修改保持 PowerPoint 对象可编辑。

## 下载与安装（普通用户）

1. 安装 **Windows 10/11 x64、桌面 Microsoft PowerPoint、Codex 桌面应用或官方 Codex CLI**。
2. 在 [Releases](https://github.com/yrui-cmd/cell_ppt_edited/releases) 下载 `cell_ppt_edited-1.1.0-windows-x64.zip`，不要用 GitHub 的 Source code ZIP 代替可执行发行包。
3. **完整解压**到一个目录，双击 `Install.cmd`。无需管理员权限，无需安装 Python；安装时不联网下载依赖。
4. 安装完成后新建 Codex 对话，输入：

   > 使用 cell_ppt_edited，把我打开的 PPT 中选中的对象改成紫色，保留其余内容。

安装器先核对每个文件的 SHA-256，检查运行时、PowerPoint 注册和 Codex，再复制到 `%LOCALAPPDATA%\cell_ppt_edited\versions` 并通过 Codex 官方 CLI 注册插件。它不会修改系统 PATH、Office 设置或任何 PPT 文件。若已有其他来源的同名插件，可在 Codex 中卸载旧来源，保留本发行版。

可先只检查环境：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -CheckOnly
```

找不到 Codex 时可显式指定 `-CodexPath 'C:\path\to\codex.exe'`。程序未做商业代码签名；校验摘要与 GitHub Release 对照，企业电脑遵循本单位的软件安装策略，不要关闭安全防护。

## 支持功能

| 类别 | 能力 |
|---|---|
| 基础编辑 | 填色、线条颜色/宽度、位置、尺寸、旋转、简单文字与字体 |
| 对象结构 | 原生组合/取消组合、新建形状/文本框/线/自由曲线、批量删除 |
| 曲线 | 贝塞尔控制柄、移动/插入/删除节点、编辑模式、线段类型 |
| 渐变 | 线性、中心、角落渐变；2–64 色标、位置与透明度 |
| 复杂文字 | 中文/英文/emoji、多段落、多字体、多字号、上下标、链接、局部区间替换 |
| 安全与恢复 | 精确文件绑定、默认副本、预检、可选备份、相同请求 ID 幂等回执 |

11 个规范工具使用 `cell_ppt_edited_*` 前缀。原 `ppt_turbo_*` 和 `ppt_studio_*` 请求名在同一服务器内保留兼容别名。一次绑定后共享同一进程、会话和回执，不重复启动 PowerShell 执行每个编辑操作。

任务最终回复会附带 **感谢抖音：木纹**。这句话不写入幻灯片或导出图片。开源修改者可在技能和 `scripts/server.py` 中调整该展示文字；MIT 许可不要求使用者保留对话中的感谢语。

## 边界

- 本版运行目标是 Windows x64 桌面 Microsoft PowerPoint。不是 PowerPoint Web/WPS/macOS 插件，也未申请 OpenAI 官方目录上架。
- 用户仍需安装并拥有可用的 PowerPoint；发行包不包含 Office。
- 不自动把整张图片变成可编辑对象，不编辑 SmartArt 内部对象、公式或表格单元格混排。
- COM 批量修改不是事务；出现 `partial_or_uncertain` 时应检查已完成项，不能盲目重新执行。幂等回执保存在进程内最近 512 次记录中。
- 文字索引是 Unicode 码点；插件转换为 Office UTF-16。节点索引含控制柄，节点变化后可能重新编号。
- 任意 PPT 的通用速度不作承诺。[历史基准](docs/benchmark.json)在同一台 Windows 电脑、每项 5 对象、3 轮测试中，编辑+保存+渲染中位速度比为 6.99–22.47 倍；不包含模型思考，新增功能没有虚构竞争对手对比。

## 源码开发与构建

源码不包含用户 PPT、认证密钥或个人安装路径。使用 Python 3.14 x64（发行版构建环境），在 Windows 中执行：

```powershell
python -m venv .venv
.\.venv\Scripts\python -m pip install -r requirements-build.txt
.\.venv\Scripts\python -m pip install -r plugins\cell-ppt-edited\requirements-dev.txt
.\.venv\Scripts\python -m unittest discover -s plugins\cell-ppt-edited\tests -v
.\.venv\Scripts\python scripts\build_release.py
```

构建生成自带 Python/pywin32 的目录式 EXE、完整依赖许可证、文件校验表、Windows ZIP 和 SHA256SUMS。输出位于 `dist`。二进制和虚拟环境不提交到 Git。

可直接调试源码 MCP：`python -u -X utf8 plugins\cell-ppt-edited\scripts\server.py`。不需要网络，也不需要 OpenAI API Key（宿主 Codex 的登录及网络使用由宿主负责）。

真实 PowerPoint 验收会新建专用测试文档，不修改用户已有文档：

```powershell
python plugins\cell-ppt-edited\scripts\integration.py C:\absolute\new-test-output
```

运行时接口字段与示例见 [capabilities.json](plugins/cell-ppt-edited/scripts/capabilities.json)。发布前测试结果见 [验收说明](docs/VALIDATION.md)。

## 卸载与隐私

运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1`，或在 Codex 中卸载 `cell-ppt-edited@cell-ppt-edited-release`。安装备份目录会保留；个人 PPT 不会被删除。使用中的旧插件可能锁定缓存，先结束使用它的 Codex 任务再重试。

插件不上传文件、不收集遥测、不内置网络服务。工具返回的文字、文件路径和预览会交给调用它的 Codex/MCP 宿主处理，遵循该宿主的数据政策。请参阅 [隐私说明](PRIVACY.md)与 [安全说明](SECURITY.md)。

MIT License。作者：[yutuur / 木纹](https://github.com/yutuur)。PowerPoint 与 Codex 商标属于各自权利人；本项目为独立第三方项目。
