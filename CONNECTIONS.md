# 连接台账 —— Arena 仓库 × 分支 × 本机路径（防忘专用）

> 更新：2026-09-15（v2.6.0：值守=常驻循环（每次登录最多闪一次）+ 启动器冒烟测试 + keeper 保活；auth 新增 -GhLogin：auth 改为"先探测再动手" + watch 的 `$var:` 解析陷阱修复 + gate 新增扫描器：零弹窗值守 + 免点击推送；多会话协作搁置）｜ 技能版本：v2.6.0 ｜ 本文件在 `E:\0github\git-sync\git-pull-arena\CONNECTIONS.md`
> 忘了的时候：`cd E:\0github\git-sync\git-pull-arena` 然后 `notepad CONNECTIONS.md`

## 一、当前所有连接

| 用途 | GitHub 仓库 | 工作分支 | 本机路径 | 值守任务名 | 状态 |
|---|---|---|---|---|---|
| **git-sync 技能总部**（版本发布、升级源） | [mqgg5630-cyber/git-pull-arena](https://github.com/mqgg5630-cyber/git-pull-arena) | **`arena/01a0a4f5-git-pull-arena`**（2026-09-15 起，v2.5.0） | `E:\0github\git-sync\git-pull-arena` | `git-sync-watch-git-pull-arena` | ✅ 本会话 HQ；本机需切到新分支并重注册值守（见下"本机升级步骤"） |
| **图片→可编辑PPT 项目**（fig3 交付物在那边） | [mqgg5630-cyber/image-to-editable-pptx](https://github.com/mqgg5630-cyber/image-to-editable-pptx) | `arena/01a04caf-image-to-editable-pptx` | `E:\0github\git-sync\image-to-editable-pptx` | `git-sync-watch-image-to-editable-pptx` | ✅ 在线（[该会话](https://arena.ai/agent/01a04caf-77d4-7672-92a2-59223763a988)；v2.3.4 @ `14c1f5f`，5/5 验收通过，值守 2 分钟） |
| **中期报告/PPT**（git-sync 技能发源地） | [mqgg5630-cyber/zhongqi](https://github.com/mqgg5630-cyber/zhongqi) | `arena/01a09d79-zhongqi` | `E:\0zhongqi\zhongqi`（你原有的克隆） | 未注册 | ✅ 可拉取（会话已结束；本会话对它只读） |
| **AgentArena**（基准测试工具 + 本机 runner 整合） | [mqgg5630-cyber/AgentArena](https://github.com/mqgg5630-cyber/AgentArena)（fork） | 多会话并行（见下表） | 见下表 | 按文件夹注册 | ✅ 模式 C 试点中 |

**（已搁置）AgentArena 多会话布局** —— 2026-09-15 用户决定：**多会话协作成本高于收益，暂时不弄**。
下表作为历史与"随时重启"的说明书保留；今后默认"一会话一仓库"（模式 A）。
重启方法、命名规则与合并纪律见 `skills\git-sync\README.md` 第七节。

**先做一件事：把搁置会话的本机值守摘掉**（3~4 个任务每 2 分钟各闪一次窗，就是"老是弹窗"的主因）：

```powershell
cd E:\0github\git-sync\agentarena-w1  ; .\watch.ps1 -Unregister
cd E:\0github\git-sync\agentarena-w2  ; .\watch.ps1 -Unregister
cd E:\0github\git-sync\agentarena-int ; .\watch.ps1 -Unregister
Get-ScheduledTask git-sync-watch-* | Select-Object TaskName, State   # 应只剩 git-sync-watch-git-pull-arena
```

| 角色 | 分支（均已在远端，技能 v2.4.6；总部 v2.4.7 已发，非紧急） | 本机路径 | 值守任务名 |
|---|---|---|---|
| 工作会话 1 | `arena/01a0a3ee-agentarena` | `E:\0github\git-sync\agentarena-w1` | `git-sync-watch-agentarena-w1` |
| 工作会话 2（已自发写工作报告） | `arena/01a0a3d6-agentarena` | `E:\0github\git-sync\agentarena-w2` | `git-sync-watch-agentarena-w2` |
| 汇总会话（release manager） | `arena/01a0a3f1-agentarena` | `E:\0github\git-sync\agentarena-int` | `git-sync-watch-agentarena-int` |
| 汇总状态文件 | 工作方 `results/status/work-report.md`；汇中方 `results/status/integration.md` | — | — |
| （旧，已清理 2026-09-15） | `arena/01a0a356-agentarena`（由 3f1 并入零丢失后删）、`arena/01a0a3d5-agentarena`（无独有交付物，删） | `E:\0github\git-sync\agentarena`（旧克隆，可删可留） | 已 Unregister |

## 二、日常命令速查（在任何已连接仓库的本机路径里）

> 多个 Arena 会话分任务 / 同仓库多分支 / 汇总会话的协作模式：见 `skills\git-sync\README.md` 第七节。

```powershell
.\sync.ps1                # 取：拉最新
.\push.ps1 "说明"          # 传：提交并推送（默认静默：不弹窗、不等确认）
.\doctor.ps1              # 体检（技能版本 + 值守/心跳/凭据三行）
.\download.ps1 -Set final # 交付物镜像到 ..\<仓库名>_out\
.\auth.ps1                # 凭据体检：现在推送能不能不点确认
.\auth.ps1 -Setup -Verify # 一次性修好并当场证明（gh > GCM+dpapi）
.\watch.ps1 -Status        # 值守活着吗：模式 / 上次运行 / 心跳 / 最近一轮
.\watch.ps1 -Test          # 立刻跑一次值守，验证"真的会跑"
```

值守（自动验证循环，本机侧）：

```powershell
.\watch.ps1 -Register -Interval 2   # 注册值守（每 2 分钟轮询；v2.3.4 起默认就是 2）
.\watch.ps1 -Register -Interval 10  # 降频：闪窗减 5 倍（代价：请求最多等 10 分钟才被消化）
.\watch.ps1 -Register -Headless     # 零窗口（S4U）——必须"以管理员身份运行"的 PowerShell；push 停摆就回退重注册
.\watch.ps1                         # 手动跑一轮（立即处理 pending 的请求）
.\watch.ps1 -Unregister             # 摘除值守
Get-ScheduledTask git-sync-watch-*  # 看本机注册了哪些值守
```

## 二·五、本机升级步骤（v2.4.7 → v2.5.0，每台机器一次）

v2.5.0 的脚本在新分支上，所以本机克隆要**切一次分支**（旧分支 `arena/01a09fc1-git-pull-arena`
冻结在 v2.4.7，仍然可读）：

```powershell
cd E:\0github\git-sync\git-pull-arena
git fetch origin
git checkout arena/01a0a4f5-git-pull-arena     # 带上 v2.5.0 脚本与新配置（本地有改动就先 git stash）
.\auth.ps1 -Setup -Verify                      # 免点击推送：配好 + 实跑证明（不弹窗）
.\watch.ps1 -Unregister                        # 换掉旧值守
.\watch.ps1 -Register                          # 新值守：零窗口 + 注册后自检
.\doctor.ps1                                   # 四行都要好看：sync / watcher / heartbeat / auth
```

> **round 7 已排好**（2026-09-15）：新分支上的 handshake 是 `awaiting_check/pending`，
> 本机升级 + 重注册值守后，第一次轮询就会自动跑这轮验收并推回结论；检查项 2a/2b
> 分别断言"免点击推送"与"零窗口启动器"，所以这一轮就是两条硬要求的机器证明。

验收（两条硬要求）：

* **无弹窗**：`.\watch.ps1 -Status` 的 `mode` 是 `zero-window (launcher exe)`，
  且每 2 分钟轮询时屏幕上**没有任何窗口**（heartbeat 里的 `last_run` 在推进）。
* **免点击**：`auth.ps1 -Verify` 退出码 0；值守轮询 `last_push=ok`，全程没有人点过任何东西。

其它仓库（image-to-editable-pptx / zhongqi 等）升级：让该仓库的 Arena 会话重新跑一次
`agent-install.sh`（配置不丢），本机再跑 `auth.ps1 -Setup -Verify`（凭据是**每台机器**级别，不用每仓库重配）。

## 三、技能升级命令（任何仓库同一条，已有配置不丢）

给那个仓库的 Arena 会话说"升级 git-sync"，或手动：

```bash
git clone --quiet --depth 1 -b arena/01a0a4f5-git-pull-arena \
     https://github.com/mqgg5630-cyber/git-pull-arena.git /tmp/src \
  && bash /tmp/src/skills/git-sync/scripts/agent-install.sh
```

当前版本看 `skills\git-sync\VERSION` 或 `.\doctor.ps1` 的 skill 行。

## 四、故障速查（本台账相关的）

| 现象 | 处理 |
|---|---|
| 在 main 上提交时把未跟踪文件误扫进去（main 没有 .gitignore） | 修正：`git checkout <工作分支> -- .gitignore` 随下一次 main 提交带上；skills/ 模板只在工作分支上，跨分支取文件用 `git checkout <工作分支> -- <路径>`，不要 copy；清残留目录用 `git rm -r -f`（暂存改动会挡住不带 -f 的 rm，然后被 add -A 又提交回去） |
| 值守 12 分钟没响应（那边第 5 轮遇到过） | 本机手动 `.\watch.ps1` 跑一轮；`del $env:TEMP\git-sync-watch-*.lock`；`Get-ScheduledTaskInfo <任务名>` 看上次运行 |
| `-Setup` 之后反而开始要登录（v2.5.0 的坑） | v2.5.1 已修：`-Setup` 先探测再动手；若已受影响，跑 `.\auth.ps1 -MigrateStore` 或 `.\auth.ps1 -Unset`，原凭据立刻可见 |
| 值守注册/运行时报 ParserError（`InvalidVariableReferenceWithDrive`） | `"$var:"` 写法会让**整份 .ps1 解析失败**（一行都不跑）：改成 `"${var}:"`；gate 已内置 `code/scan_ps_var_colon.py` |
| 值守推送卡住等同意 / 要手动点确认 | v2.5.0 起推送默认静默：`.\auth.ps1 -Setup -Verify` 一次配好免点击凭据（gh helper 或 GCM+`credentialStore=dpapi`）；心跳里出现 `auth: no silent credential` 就是这个没配 |
| 值守每 2 分钟闪一下黑窗（无弹窗要求） | v2.5.0 默认零窗口（编译 GUI 子系统启动器）：`.\watch.ps1 -Unregister` → `.\watch.ps1 -Register`；`-Status` 的 mode 应显示 `zero-window`（`-Flash` 才是旧的闪窗模式） |
| 值守"注册了但没在跑" | `.\watch.ps1 -Test`（立刻跑一次并等心跳）；别信 `LastTaskResult`（v2.4.4 的 VBScript 启动器就是 0 但没跑），要看 `%LOCALAPPDATA%\git-sync\watch-*.log` 与心跳 json |
| S4U/-Headless 报"拒绝访问 0x80070005" | 改任务 Principal 必须管理员权限：用"以管理员身份运行"的 PowerShell 重跑同一条命令；回退 Interactive 同样要在管理员窗口做 |
| 检查日志只有头部几行、exit 0 疑似空转 | v2.4.7 起日志带 `elapsed:` 行 + 空输出显式标记；elapsed≈0 且本该有产出 → check_cmd 链没真跑（w1 实战：powershell -File 链空转，改 `bash code/local_check.sh` 原生链修复） |
| agent 说读不到你的检查结果 | 大概率是 BOM/编码，v2.3.2 已修——确认那边技能 ≥ v2.3.2 |
| 本地改动"消失" | 在 stash 里：`git stash list` → `git stash pop` |

## 五、历史里程碑

- 2026-09-14：git-sync v1（zhongqi 沉淀）→ 本仓库安装 → 双向打通（`1d4d62f`）
- 2026-09-14：v2（agent-install / 回执 / doctor -Fix / 增量下载 / PR / profile）
- 2026-09-14：v2.1（新会话提示词模板）→ 首次跨会话复用成功（image-to-editable-pptx）
- 2026-09-15：v2.2（回执归档 + 硬件上报：GTX 1650 / 22 conda 环境）
- 2026-09-15：v2.3（自动验证循环）→ 真机 4 轮闭环（BOM / .gitignore .log 两个真 bug 修复）
- 2026-09-15：image-to-editable-pptx 项目级验收 5 轮全过（fig3 PPTX：227 形状 / 0 贴图 / 1139 可编辑字符）
- 2026-09-15：v2.3.4（移植 add -A 假删除守卫 / 值守默认 2 分钟 / 模板日志可捕获）；CONNECTIONS.md 台账建立
- 2026-09-15：AgentArena fork 建立（mqgg5630-cyber/AgentArena，只含 main，与上游同步——权限障碍解除）
- 2026-09-15：v2.3.5（值守锁 30 分钟过期自愈——进程硬崩后锁残留会让值守永久停摆）
- 2026-09-15：AgentArena 会话开工即验收通过（round 1 accepted `2bcc53b`：文档在位 + npm 冒烟；local-runner 设计文档落仓）
- 2026-09-15：v2.4.0（`agent-wait --auto-accept` / 本机即 Runner 配方 / health.yml 每日体检 / 安装器保留根目录配置）
- 2026-09-15：v2.4.4→v2.4.6（wscript+vbs 隐形启动器实战判死：Win11 弃用 VBScript，值守全线静默停摆、LastTaskResult 0 假象 → 回退 `powershell -WindowStyle Hidden` + `-Headless` S4U 实验项）；恢复命令执行后**值守首次全自动闭环**——w2 round 3 请求 30 秒自动判定回推（`f6c74bf`）、w1 round 2 39 秒、3f1 回归 92 秒，全程无人碰机器
- 2026-09-15：**v2.6.0**（实测定位：本机 GCM 从未存过凭据=推送必然要人点，必须登录一次（`auth.ps1 -GhLogin` 一条命令，gh 令牌放自己配置里，session 0 也能读）；值守改为**常驻循环**——flash 模式也只每次登录闪一次，替代每 2 分钟闪一次；注册前对启动器做冒烟测试并在失败时打印任务结果+host 日志；keeper 触发器每 30 分钟保活；`-Status` 报告循环存活/心跳年龄；`push.ps1 -Prompt` 显式开交互；`auth.ps1` 说明"公开仓库 ls-remote 不代表鉴权"）
- 2026-09-15：**v2.5.1**（实测修复：`auth.ps1` 改为"先探测、只在必要时改"，并会 unset 误设的 `credentialStore`；新增 `-MigrateStore`；`watch.ps1` 的 `$var:` 盘符陷阱根治 + 注册环境预检（git/bash/powershell 路径入心跳）；`local_check.ps1` 禁止 gate 空转通过；gate 新增 `code/scan_ps_var_colon.py`）
- 2026-09-15：**v2.5.0**（零弹窗值守 + 免点击推送：`auth.ps1`（gh/GCM-dpapi + 关闭提示的实跑验证）；`watch.ps1` 默认 GUI 子系统启动器（CreateNoWindow，无管理员、不碰 VBScript）+ 注册自检 + `-Status`/`-Test` + 心跳/日志落 `%LOCALAPPDATA%\git-sync\`+ 检查硬超时；`push.ps1` 默认静默、认证失败 exit 4；gate 增加"每个 .ps1 可解析"；多会话协作搁置）
- 2026-09-15：v2.4.7（实测吸收：S4U 注册/切换需管理员控制台 0x80070005；检查日志加 `elapsed:` 行 + 空输出显式标记——w1 的 check_cmd 链空转、轮轮假通过的教训）；356/3d5 旧分支已由 3f1 清理
