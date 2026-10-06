# 连接台账 —— Arena 仓库 × 分支 × 本机路径（防忘专用）

> 更新：2026-10-05（**本会话（`arena/01a10bf3`）HQ = 新克隆 `git-pull-arena-01a10bf3` / `arena/01a10bf3-git-pull-arena`，技能 **v2.8.1**；**不要覆盖旧目录**。不要覆盖的目录：`git-pull-arena`（旧 v2.6.7）、`git-pull-arena-v268`、`git-pull-arena-s2`、`git-pull-arena-01a0a9f0` 及其他更早会话目录。上一个会话 `arena/01a10bde`（动态壁纸重试，其 round 268 未在本分支闭环）值守已被本会话 park，可在其目录 `.\\watch.ps1 -Focus` 切回）｜ 技能版本：v2.8.1（开发分支）/ v2.6.7（`main`）｜ 开发分支 `arena/01a10bf3-git-pull-arena`（本会话）｜ 退路 `arena/01a0a4f5-git-pull-arena`（v2.6.7）/ `arena/01a09fc1-git-pull-arena`（v2.4.7）｜ 本文件在 `E:\0github\git-sync\git-pull-arena-01a10bf3\CONNECTIONS.md`
> 忘了的时候：`cd E:\0github\git-sync\git-pull-arena-01a10bf3` 然后 `notepad CONNECTIONS.md`

## 一、当前所有连接

| 用途 | GitHub 仓库 | 工作分支 | 本机路径 | 值守任务名 | 状态 |
|---|---|---|---|---|---|
| **git-sync 技能总部（本会话）** | [mqgg5630-cyber/git-pull-arena](https://github.com/mqgg5630-cyber/git-pull-arena) | **`arena/01a10bf3-git-pull-arena`**（技能 v2.8.1） | `E:\0github\git-sync\git-pull-arena-01a10bf3` | `git-sync-watch-git-pull-arena-01a10bf3` | ⏳ 本机粘一次交接块（`bootstrap.ps1 -Auto`）后收 round 回执；**不要覆盖旧目录** |
| git-sync 上一会话克隆（v2.8.1，值守已被本会话 park） | 同上 | `arena/01a0a9f0-git-pull-arena`（v2.8.1） | `E:\0github\git-sync\git-pull-arena-01a0a9f0` | `git-sync-watch-git-pull-arena-01a0a9f0` | ⏸ 切回：`cd git-pull-arena-01a0a9f0 ; .\watch.ps1 -Focus`（不要覆盖这个目录） |
| git-sync 上一会话克隆（v2.7.4，值守已被本会话 park） | 同上 | `arena/01a0a821-git-pull-arena`（v2.7.4） | `E:\0github\git-sync\git-pull-arena-s2` | `git-sync-watch-git-pull-arena-s2` | ⏸ 切回：`cd git-pull-arena-s2 ; .\watch.ps1 -Focus`（不要覆盖这个目录） |
| git-sync 上一会话克隆（v2.6.8 静态/收尾行已验，冻结） | 同上 | `arena/01a0a7de-git-pull-arena`（v2.6.8；PR #3 已关） | `E:\0github\git-sync\git-pull-arena-v268` | `git-sync-watch-git-pull-arena-v268` | ⏸ **不要覆盖、不要在这里跑本会话的 `.\sync.ps1`** |
| git-sync 旧安装（v2.6.7，冻结当退路） | 同上 | `arena/01a0a4f5-git-pull-arena`（v2.6.7） | `E:\0github\git-sync\git-pull-arena` | `git-sync-watch-git-pull-arena`（2026-09-16 已 `-Pause`） | ⏸ 不要在这里跑 `.\sync.ps1`，会停在 v2.6.7 |
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
.\watch.ps1 -Status        # 值守活着吗：模式 / 上次运行 / 心跳 / 最近一轮 / other tasks
.\watch.ps1 -Focus         # 只留这一会话（暂停其他 git-sync-watch-*，不删任务）
.\watch.ps1 -RestoreParked # 恢复被暂停的其他会话值守
.\watch.ps1 -Test          # 立刻跑一次值守，验证"真的会跑"
```

值守（自动验证循环，本机侧）：

```powershell
.\watch.ps1 -Register -Interval 2   # 注册值守（每 2 分钟轮询；v2.3.4 起默认就是 2）
.\watch.ps1 -Register -Interval 10  # 降频：闪窗减 5 倍（代价：请求最多等 10 分钟才被消化）
.\watch.ps1 -Register -Headless     # 零窗口（S4U）——必须"以管理员身份运行"的 PowerShell；push 停摆就回退重注册
.\watch.ps1                         # 手动跑一轮（立即处理 pending 的请求）
.\watch.ps1 -Unregister             # 摘除值守
.\watch.ps1 -Focus                  # 本克隆为当前会话：暂停其他值守（任务保留）
.\watch.ps1 -RestoreParked          # 恢复 parked.json 里的值守
Get-ScheduledTask git-sync-watch-*  # 看本机注册了哪些值守
```

## 二·五、本机升级步骤（v2.4.7 → v2.5.0，每台机器一次）

v2.5.0 的脚本在新分支上，所以本机克隆要**切一次分支**（旧分支 `arena/01a09fc1-git-pull-arena`
冻结在 v2.4.7，仍然可读）：

```powershell
# 本会话：新文件夹克隆，不要 checkout 进旧目录
cd E:\0github\git-sync
git clone -b arena/01a0a821-git-pull-arena https://github.com/mqgg5630-cyber/git-pull-arena.git git-pull-arena-s2
cd git-pull-arena-s2
.\auth.ps1 -Setup -Verify                      # 免点击推送：配好 + 实跑证明（不弹窗）
.\watch.ps1 -Register                          # 新值守：零窗口 + 注册后自检（任务名带 -s2，不碰旧任务）
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
git clone --quiet --depth 1 -b arena/01a0a821-git-pull-arena \
     https://github.com/mqgg5630-cyber/git-pull-arena.git /tmp/src \
  && bash /tmp/src/skills/git-sync/scripts/agent-install.sh
```

当前版本看 `skills\git-sync\VERSION` 或 `.\doctor.ps1` 的 skill 行。

## 四、故障速查（本台账相关的）

| 现象 | 处理 |
|---|---|
| 在 main 上提交时把未跟踪文件误扫进去（main 没有 .gitignore） | 修正：`git checkout <工作分支> -- .gitignore` 随下一次 main 提交带上；skills/ 模板只在工作分支上，跨分支取文件用 `git checkout <工作分支> -- <路径>`，不要 copy；清残留目录用 `git rm -r -f`（暂存改动会挡住不带 -f 的 rm，然后被 add -A 又提交回去） |
| 新会话装完旧会话值守停了 | 默认行为：`-Register` 暂停其他任务。回原会话 `cd <原克隆> ; .\watch.ps1 -Focus`；全恢复 `.\watch.ps1 -RestoreParked` |
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

- 2026-09-16：**本会话（`arena/01a0a9f0`）装 v2.8.1 + 与本地打通**：用户短句＝「安装 `arena.ai/agent/01a0a98d` 的 skills，与本机（spyder/conda base，`E:\0github\git-sync`）打通」。动作：`agent-install.sh`（`--source` = 分支 `arena/01a0a98d`）把 `skills/git-sync` 从 v2.7.4 升到 **v2.8.1** 并把配置分支改成本会话分支；仓库级 `code/check_all.sh`、`code/local_check.ps1`（3a–3h）、`.gitattributes`（LF 统一）、`.gitignore` 一并对齐；新增 `code/make_link_proof.py` + `deliverable/LINK_PROOF_v2.8.1.docx/.pptx` + `OFFICE_HASHES.json`（沙箱内先用 Python 跑同一套 3a–3g 镜像自检，再交本机真 Word/PowerPoint 判定）。本机侧只需粘一次 `agent-handoff.sh` 生成的交接块。

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
- 2026-09-16：**v2.7.4**（用户坚持短句 `安装 arena.ai/agent/01a0a821 的skills，与本地打通`：助手必须自己映射到 GitHub clone，禁止打开 arena.ai、禁止向用户要长提示词。入口 `01a0a821.md` + SKILL description TRIGGER。zhongqi `01a0a954` 再次没先打通本机）
- 2026-09-16：**v2.7.3**（根因：新会话只贴 arena.ai 链接 → 沙箱打不开 → 对方自制 python/.venv 冒充本机。用户应粘 `templates/USER_PROMPT.md` 整段，内含 GitHub clone。test-auto-arena `01a0a948` 再次踩坑）
- 2026-09-16：**v2.7.2**（铁律：与本地打通 = Windows `watch.ps1`，禁止沙箱 `local/inbox` / 自制 python skills；第一条回复必须是填好的 PowerShell；`agent-install.sh` 补拷 `install.ps1`。test-auto-arena 那次就是踩了假本机）
- 2026-09-16：**v2.7.1**（新会话一句话触发装技能+自循环；`agent-wait`/`agent-handsfree` 默认 `--timeout auto`：值守一回传就停，上限=check_timeout_min*60+180，不再死等 600s。协议 `templates/one-sentence.md` / `task-loop.md`。Arena 链接 `arena.ai/agent/01a0a821-...` 等同本技能总部）
- 2026-09-16：**v2.7.0**（解放双手：值守 auto_pull/auto_push + Agent `agent-handsfree.sh`/`agent-criteria.sh`；先例 `new`/`arena/01a0a90b-new` round 1 `6fe3dc7` accepted。HQ 必须重注册。说明 `deliverable/HANDS_FREE_v2.7.0.md`）
- 2026-09-16：**v2.6.9**（新会话自动暂停其他 `git-sync-watch-*`：Stop+Disable+杀循环，不删任务；台账 `%LOCALAPPDATA%\git-sync\parked.json`。继续原对话：HQ `cd git-pull-arena-s2 ; .\watch.ps1 -Focus`。一次全恢复：`.\watch.ps1 -RestoreParked`。`-Register -KeepOthers` 跳过。`-Status` last-check 与日志轮转均 UTF-8。说明 `deliverable/FIX_v2.6.9.md`）
- 2026-09-16：**v2.6.8**（收尾行闸门已在上一会话真机 PS 跑过；本会话 `arena/01a0a821` + 新克隆 `git-pull-arena-s2` 做推送闭环。① 值守每个出口都必须留收尾行：`Invoke-PollRound` 6 个出口 + `Invoke-PollOnce` 2 个出口各自设置 `$script:PollSummary`，循环与手动单轮都打印它，手动单轮再以 `== finished at ...` 收尾（不再静默退回提示符）；新增 `code/check_loop_summary.py`（闸门 §3c）+ `code/check_loop_summary.ps1`（accept 2c）**静态**盯住这条规则，删掉任意一条赋值闸门就 exit 1 ② `Get-PowerShellExe` 优先 64 位（32 位进程走 `SysNative`）③ `-Status` 的 host log 尾部按 UTF-8 读（修中文乱码）+ 任务结果码人话注释（0/267009/267011/267014/2147946720=0x800710E0 都是正常码）+ 代理提示改成可照抄的 `setx HTTPS_PROXY "..."` ④ `doctor.ps1` 同步把这些码当正常 ⑤ 新增 `templates/install-one-liner.md` 与 README「零」节的四行安装块/三命令升级块 ⑥ 删掉 `f0d5d1c` 带进来的 0 字节 `code/accept_test.ps1`）
- 2026-09-16：**v2.6.7**（值守循环拿到可见控制台时打印"这个窗口就是值守"的说明 + 每轮打印 `== idle - next poll at HH:MM:SS`，消除"卡在 verdict pushed back"的误解；round 15 已验证：单轮不再重跑）
- 2026-09-16：**v2.6.6**（修我自己的两个真 bug：① agent-sync.sh 用过期握手覆盖本地已推回的 passed→pending，害值守重跑同一轮；改为提交前比对、本地侧已答则取远端 ② 旧版本循环无 pid 文件、-Unregister 停不掉 → 循环启动时清理同仓库旧循环，-Status 列出 other loops，-Pause/-Unregister 一并清理（"窗口卡住/刷屏"的根因））
- 2026-09-16：**v2.6.5**（round 13 **通过**：2a 免点击推送 PROVEN、2b 分级通过，结论自动推回=闭环；"卡住"=值守常驻循环被挂到用户控制台 → 循环自我脱离（隐藏重启）+ 单实例 pid 闸 + -Pause/-Unregister 真停循环；退出码改用 `/v:on` + `!ERRORLEVEL!`（修"闸门失败却报 passed"）；防坑扫描器在 python 不可用时 SKIP）
- 2026-09-16：**v2.6.4**（round 12 结果：**2a 免点击推送 PROVEN、2b 分级通过**；唯一失败是我 gate 的 python 假失败 → 改为自检解释器 + sed 回退；push.ps1 全走 cmd/c（最后的 poll crash）；退出码写入标记文件（修 `failed (exit )`）；每轮自愈补推未推送的结论提交；启动器改 ASCII 目录 + MZ 校验）
- 2026-09-16：**v2.6.3**（2a 已成立：push --dry-run PASSED；修值守跑不完的三坑：① sync.ps1 的 git stderr 在 EAP=Stop 下变成终止性错误（poll crashed: Already on ...）→ 全部走 cmd /c；② check_cmd 用裸 `powershell` 启动失败（%1 不是有效的 Win32 应用程序/exit 193）→ 解析绝对路径 + cmd /d /c + 杀进程树 + ANSI 读回；③ 产物提交 amend 化（313 个堆积）；keeper 10 分钟；bash 优先 git 自带）
- 2026-09-15：**v2.6.2**（gh 已登录、凭据探针 OK；修掉我自己的误报：dry-run 推本地 HEAD，非快进被拒被当认证失败 → 改推远端跟踪引用到一次性探针分支，拒绝也计入 READY；push.ps1 遇"只领先结论提交"自动对齐远端后重试（修值守 exit 3 死循环）；local_check 2b 改分级；-Headless 提示管理员窗口；启动器失败打印 host 日志）
- 2026-09-15：**v2.6.1**（实测定位真因：`gh auth login` 超时=网络路径，git 经代理可通而 gh 只认 HTTPS_PROXY → auth.ps1 自动套用 git 的 http.proxy + `-HttpProxy`；PAT 改为离线优先入库（无需 API）；sync.ps1 不再把 results/status 产物堆成 stash（本地提交 + 分叉自动对齐）；值守记录 push 失败原因 last_push_detail；-Status/-Register 提醒代理不一致）
- 2026-09-15：**v2.6.0**（实测定位：本机 GCM 从未存过凭据=推送必然要人点，必须登录一次（`auth.ps1 -GhLogin` 一条命令，gh 令牌放自己配置里，session 0 也能读）；值守改为**常驻循环**——flash 模式也只每次登录闪一次，替代每 2 分钟闪一次；注册前对启动器做冒烟测试并在失败时打印任务结果+host 日志；keeper 触发器每 30 分钟保活；`-Status` 报告循环存活/心跳年龄；`push.ps1 -Prompt` 显式开交互；`auth.ps1` 说明"公开仓库 ls-remote 不代表鉴权"）
- 2026-09-15：**v2.5.1**（实测修复：`auth.ps1` 改为"先探测、只在必要时改"，并会 unset 误设的 `credentialStore`；新增 `-MigrateStore`；`watch.ps1` 的 `$var:` 盘符陷阱根治 + 注册环境预检（git/bash/powershell 路径入心跳）；`local_check.ps1` 禁止 gate 空转通过；gate 新增 `code/scan_ps_var_colon.py`）
- 2026-09-15：**v2.5.0**（零弹窗值守 + 免点击推送：`auth.ps1`（gh/GCM-dpapi + 关闭提示的实跑验证）；`watch.ps1` 默认 GUI 子系统启动器（CreateNoWindow，无管理员、不碰 VBScript）+ 注册自检 + `-Status`/`-Test` + 心跳/日志落 `%LOCALAPPDATA%\git-sync\`+ 检查硬超时；`push.ps1` 默认静默、认证失败 exit 4；gate 增加"每个 .ps1 可解析"；多会话协作搁置）
- 2026-09-15：v2.4.7（实测吸收：S4U 注册/切换需管理员控制台 0x80070005；检查日志加 `elapsed:` 行 + 空输出显式标记——w1 的 check_cmd 链空转、轮轮假通过的教训）；356/3d5 旧分支已由 3f1 清理

## Round 22+ - repo tasks (code/tasks, run by the local machine)

- `code/tasks/manifest.json` maps a handshake round number to task scripts in `code/tasks/`.
- `code/local_check.ps1` section 4 runs the CURRENT round's tasks on the local machine (child `powershell.exe`, stdout goes to the round receipt, non-zero exit fails the round).
- Round 22 = three READ-ONLY diagnostics: `t1_antigravity_diag.ps1` (Antigravity login failure, account masked), `t2_java_diag.ps1` (why Java will not install), `t3_edrive_scan.ps1` (E: cleanup candidates, 600s capped walk, nothing deleted).
- Cleanup / install actions only happen in later rounds, after the receipts are read and the user approves deletions.

## Round 23 - fixes based on the round-22 receipts

- `t1_fix_antigravity.ps1`: patched `%APPDATA%\Antigravity IDE\User\settings.json` (+ legacy dir) with `http.proxy` / `http.proxySupport` / `http.noProxy` (backup written next to it). Root cause from r22: the IDE's language server dials Google APIs directly, bypassing the working system proxy (127.0.0.1:10808) - all direct TCP 443 to Google fail. User must reopen Antigravity; if the LS still dials direct, enable TUN mode in the proxy client.
- `t3_edrive_scan2.ps1`: finishes the E: scan (r22 covered 289.7 of 481.1 GB; this pass covers the remaining top-level folders + recycle bin).
- `t2_install_java.ps1`: portable Temurin JDK 21 zip -> `E:\java\<jdk>` (TUNA mirror first, then Huawei, Microsoft, Adoptium API; direct/proxy fallbacks; zip validated; JAVA_HOME + User PATH set with backup; `java -version` verified). No admin, no installer, no UAC.

## Rounds 28-31 - LigPlus upgrade + wrap-up

- All rounds ran through the watcher on LAPTOP-R77M5D6M; receipts in results/status/check_r2[2-9]_*.txt, check_r3[01]_*.txt.
- LigPlot+ v2.3.2 now at E:\LigPlus\LigPlus (window title verified); old expired v2.2.9 copies removed to the recycle bin (WeChat copy left: chat history).
- Java env proven end-to-end (javac + jar + Swing GUI window "JavaOK-E-drive").
- Antigravity login fixed (settings.json http.proxy + user-level proxy env vars; user confirmed working).
- E: freed ~10 GB on disk + ~6.1 GB in the recycle bin; uv cache 1.78 GB remains (locked by running MCP tools).

## Round 37 - approved cleanup executed

- 7.49 GB to the recycle bin: old installers (BIOVIA/AmberTools/Positron/Cytoscape/TencentMeeting/jdk23+24/Sheas-Cealer/DiscoveryS/fuhewu+sh data/VMware/AI-mp4/AI-zip), bert.bin, study folder, vit-pytorch-main, Vivaldi, thunder-download folder, wsa toolbox, the WeChat LigPlus.jar (old build, hash-checked).
- Desktop: old LigPlus.jar.lnk replaced by LigPlot+.lnk -> E:\java JDK javaw + E:\LigPlus\LigPlus\LigPlus.jar (verified).
- Docker builder prune: engine was OFF - retry when Docker Desktop runs.
- Pagefile: 42 GB auto-managed, peak 8.8 GB -> E:\pagefile_shrink_admin.ps1 written (run as admin + reboot -> 8-16 GB fixed).
- uv cache: left alone (actively used by MCP tools; it regrows while they run).

## rounds 43-46 (2026-09-30, post-reboot + HPC bridge)
- r43: post-reboot verified — watcher auto-resumed, pagefile E:\ 8192MB ACTIVE (was 42272MB), E: free 287.7GB (+33GB). D: survey: 137.2GB total, 106.5 used; D:\WSL (Ubuntu-26.04 vhdx) = 70.54GB, desktop 2.96GB, stale tools ~0.9GB, no dupes/big installers. Report: results/status/ddrive_survey_r43.md
- r44: laptop RDP ENABLED + OpenSSH server installed & running (0.0.0.0:22, auto). WSL-26.04 inside survey: 50G used inside (miniconda3 28G incl py36+torch, CUDA 12.9 7.3G, Proteomics_Projects 6.1G, /var/log 816M). USER RETRACTED cleanup: "上一个点错了，不要随意清理" — do NOT clean WSL-26.04 without explicit new approval.
- r45: HPC probe — 10.10.5.210 ping+tcp22 OPEN (NSFOCUS VPN connected: 5 procs, tunnel 10.0.0.15, /32 route present); 2 active user ssh sessions to HPC spotted. Tailscale: no exit node, no routes.
- r46: `tailscale set --advertise-routes=10.10.5.210/32` DONE on laptop (no elevation needed). PENDING: user must approve route at login.tailscale.com/admin/machines, then desktop tests `ssh 25wenshaohua@10.10.5.210`. Undo: tailscale set --advertise-routes= (empty).

## round 47 (2026-09-30, desktop access + HPC chain verified)
- Probe from laptop: desktop 100.84.137.117 = 4ms direct; ports 3389 RDP OPEN, 445 SMB OPEN, 22 SSH OPEN (desktop has sshd!).
- RDP "cert error" = benign self-signed warning; user clicks Yes.
- SMB fails because no shares/credentials on desktop, not a network issue (net view exit 0, empty list).
- HPC chain: netmap shows 10.10.5.210/32 APPROVED+active (user approved in console); laptop VPN up (ping+tcp22 to HPC OK). Desktop test command: ssh 25wenshaohua@10.10.5.210 (Windows accepts subnet routes by default; laptop SNATs).
- Laptop net profiles: Tailscale=Private, WLAN=Public.

## round 47 confirmation (user-tested, 2026-09-30)
- USER CONFIRMED: from home desktop `ssh 25wenshaohua@10.10.5.210` SUCCESS (full HPC bridge works) + RDP to desktop SUCCESS (cert warning clicked through).
- \\100.84.137.117 shows "folder is empty" (no shares configured, expected).
- Next: use built-in admin shares \\ip\C$ D$ E$ with desktop credentials; if denied, set LocalAccountTokenFilterPolicy=1 on desktop (UAC remote restriction). Optional later: ssh key laptop->desktop for agent-managed desktop control.

## round 48 (2026-09-30, autostart + software inventory)
- t36: Tailscale service already Automatic; tray GUI (E:\Tailscale\tailscale-ipn.exe) added to HKCU Run. NSFOCUS VPN (E:\NsfocusVPN\NsfocusVPN.exe) added to HKCU Run. Undo: Remove-ItemProperty HKCU:\...\Run -Name NsfocusVPN / Tailscale. Auto-CONNECT not guaranteed (depends on client saved creds) - check after next reboot.
- t37: 47 desktop apps + 74 appx inventoried -> results/status/software_inventory_r48.md. zTasker 2.3.12 (portable, E:\zTasker_2.3.12_绿色版_不要放C盘\zTasker.exe) found RUNNING; GUI-first automation tool, task storage not yet inspected.
- Notable: Antigravity installed TWICE (IDE (User) 2.5.5 @ E:\Antigravity + "Antigravity 2.15.1" no location, 534MB) - verify which is active before any removal. FlyingMouse Format 2.08GB + KeyMouse Studio 341MB biggest non-essential candidates. AweSun kept per r38 binding decision.

## round 49 (2026-09-30, QwenPaw uninstalled + toolbox)
- t38: QwenPaw Desktop 2.1.0 uninstalled silently (uninstall.exe /S); uninstaller removed dir+registry+shortcuts itself; E: free 295.20 -> 297.05 GB (+1.85). Note: user emptied recycle bin between r43 and r49 (287.7+7.5=295.2 matches).
- t39: agent toolbox = 31/39 PATH tools (git 2.54@E:\hermes, gh 2.97, docker 29.6.1, wsl x2 distros, python 3.11.9@E:\spider, node 22@E:\hermes, go 1.26.5, rust, java 21, tailscale, ssh/scp, code, rg, winget, tar, robocopy, schtasks, reg, msiexec, conda, uv). Missing: py, pipx, ffmpeg, 7z, pwsh, choco, scoop, adb. winget available = hands-free install/uninstall possible.
- Reports: D:\桌面\软件工具清单_2026-09-30.md (user's desktop, UTF-8 BOM) + results/status/software_paths_r49.md (46 apps with resolved local paths).

## rounds 52-56 (2026-09-30, R hunt concluded + report fixes)
- r52: desktop report n8n section corrected; WSL R probe via PS capture = mojibake (dead end).
- r53: clean probe via code/tasks/r_probe.sh run INSIDE WSL (writes results/status/r_detail_wsl24.txt itself - no PS decoding). Ubuntu-24.04: NO R (no R/Rscript, no dirs, conda envs = camps-tf114/docking/py36 only). Ubuntu-26.04: 0.
- r54: Windows conda E:\spider = base + 13 envs (1, blast, DIP, docking, gmx_copilot, gmx_mmpbsa, HeroMDanalysis, lark-f, mcp_pymol, meta-analysis, MMPBSA, ncbi_datasets, spyder-runtime) + D:\Pymol + NTxPred2/cnki-review/lark/lmab/orange3 + e:\kubernetes-master\.conda. NO r envs. FOUND: E:\R and E:\RStudio dirs (t40 regex missed bare 'R' name).
- r55 FAILED (parse: semicolon inside cast parens) -> r56 PASSED after fix (+ quote-nesting fix in desktop patch).
- r56: E:\R = R-4.6.0 ONLY (189.1 MB, single version - NOTHING to delete) + data files (GSE11121/GSE42872 .Rdata, TCGA gdc_download folder+tar.gz, R_libs, R_Temp, rna_seq tsv). E:\RStudio = single Electron install. Desktop report R section updated. E: free 292.8 GB.
- User questions answered: task scenarios (report sec 1-2), MCP usable via stdio JSON-RPC, n8n needs Docker engine on, alternatives via winget (report sec 7).

## rounds 57-65 (2026-09-30, DELIVERABLE: English.docx Zotero-linked version)
- Task: make E:\0writing\Light-skills\projects\English.docx Zotero-linked, same format, SAME output path. Success case = E:\0writing\cnki-skills\periodontitis-ad-pg-review (zotero_word_fields.py pipeline, verified docx ZOTERO_ITEM=34+BIBL=1).
- Recon: 653 paras; 62 citation runs ALL PLAIN (not superscript), numbers 1-36 incl ranges [8-9]/combos [23,31]; refs = 36 AMA entries ("N. Authors. Title. Journal. Year;V(I):P. doi:...") at paras 632-667, style Reference; Zotero data E:\ozotero\zotero.sqlite (409 items, the 36 refs NOT in it); AMA style installed; python-docx 1.2.0.
- Mechanism (from success case): ADDIN ZOTERO_ITEM CSL_CITATION complex fields w/ embedded itemData + uris [] + storeReferences, ZOTERO_BIBL wrap, docProps/custom.xml ZOTERO_PREF_n (255-char slices), storeReferences=true. No .tex needed - keys derived from bracket numbers (ref1..ref36), CSL items parsed from the AMA ref text (all 36 have DOIs).
- r61 first build: bib selection bug (40 paras incl textbox-regex fragments -> ZOTERO_BIBL wrapped 0 paras, would corrupt on Refresh). r62 verify caught it, restored backup; r62 verifier itself had 2 false-negative bugs (display-run unlinked check off-by-string; bib extent counted via truncated fragments).
- r63: solved 63rd bracket = "[0, 1]" AnOxPePred probability array (NOT a citation) -> 62/62 real citations linked. r64 FINAL BUILD PASSED (enclosing-paragraph bib verification: begin=ref1 Scheltens, end=ref36 Kryger; 0 unlinked; displays preserved; AMA en-US prefs).
- r65 REAL-WORD COM TEST: opened read-only hidden, 63 fields (62 ZOTERO_ITEM + 1 ZOTERO_BIBL), field1 result "[1]", clean close, no repair prompt.
- Deliverables on machine: English.docx (SAME path, zotero-linked, 7200.2 KB), English_backup_pre-zotero.docx (original), English_Zotero_library.json (36 items importable CSL-JSON). Tools in repo: code/tasks/t46-t53 + results/reference/pgreview/ (pipeline sources).
- Usage: open in Word -> Zotero tab -> Refresh. Optional: import English_Zotero_library.json into Zotero for library binding. Undo: copy backup over.

## rounds 66-70 (2026-09-30 evening, English.docx zotero-link v2 - FULLY BOUND)
- User reported failure: citations "not linked", library import failed, asked to verify refs are real. Root causes found+fixed:
  1. refs were NOT in the Zotero library (0/36 matched) -> imported all 36 via Connector saveItems API (127.0.0.1:23119, same mechanism as push_to_zotero.py; Zotero internal item format, NOT CSL - that is why the manual .json import failed). 3 batches x 201 SAVED, landed in selected collection Collagen_Stability_MD_Docking_Hybrid_Review (libraryID 1).
  2. prefs said zoteroVersion 7.0.0 but machine runs Zotero 9.0.6 -> rebuilt with 9.0.0 (r67).
  3. citation uris were empty [] (orphan fields) -> r69/r70: matched 36/36 refs to Zotero items by DOI (sqlite snapshot copy +wal), rewrote all 91 citation items' uris to http://zotero.org/users/0/items/<KEY>. Doc is now natively bound: Add/EditCitation opens the library item, Refresh re-renders from library.
- Crossref verification: ALL 36 DOIs resolve; 34/36 title-similarity >= 0.75 (ref8 0.46 / ref12 0.51 are Crossref HTML-tag artifacts); NONE fake. Report: results/status/ref_verify_r66.md.
- A/B test (r68): Zotero.Refresh via COM throws E_FAIL on the SUCCESS-CASE docx too -> E_FAIL is an automation-context artifact, NOT a document defect.
- FINAL STATE: English.docx (same path) = 62 ZOTERO_ITEM fields (91 citation items, all uris bound + full itemData embedded) + ZOTERO_BIBL (refs 1-36) + AMA en-US prefs v9 + storeReferences; format unchanged; English_backup_pre-zotero.docx = original; English_Zotero_library.json = CSL export (for reference only - import already done via API).
- Word plugin Zotero.dotm present in %APPDATA%\Microsoft\Word\STARTUP. Usage: open English.docx in Word -> Zotero tab -> Refresh (citations keep [n] look in AMA; switch styles via Document Preferences).

## round 269 (2026-10-05, session arena/01a10bf3 - real dynamic video wallpaper)
- 用户改派任务：「轮询任务是给我本机壁纸变为动态的……直接去找一个本身是动态壁纸的换上」。
- `code/tasks/t221_run_dynamic_video_wallpaper_r269.ps1`（薄壳，避开本机 AMSI）+ `t221_dynamic_video_wallpaper_r269.py`（复刻 **r266 已验证** 的 VLC `--video-wallpaper` 配方）：
  1. **找**：从 livelywallpaper.app CDN 下载真·动态壁纸 mp4（候选：Hotori 落日城市 → 蓝档案 Kisaki 金鱼 → 夕阳窗边猫；本地兜底 r254/r255 两个 mp4）；
  2. **换**：VLC video-wallpaper 模式设为桌面壁纸（本机 17:25 实证过该配方）；
  3. **证**：截图像素差——换上前 vs 后 ≥2% 变化 + 两帧间隔持续运动（r266 同款阈值）；
  4. **留**：Start/Stop bat + 开机自启（Startup 文件夹）+ PATHS.txt；失败自动回滚 r267 静态壁纸。
- 判据维护：修掉上一会话遗留的 5 条坏判据（R264 幻影回执 + 3 条 min_bytes 虚高），新增 R268 回执判据。
- 回执：`results/mcp_agv_lab/R269_DYNAMIC_VIDEO_WALLPAPER.md` + `r269-dynamic-video-wallpaper.json` + 四帧截图。
- 状态：⏳ 已排队（round 268 accept 后自动发起，值守 2 分钟内消化）。

## round 270 (2026-10-05, retry: r269 编码修复)
- r269 诊断：Hotori mp4 已下载（2.66MB）+ VLC 已启动，但写 PATHS.txt 用了 `encoding='ascii'`，路径里的中文用户名（`C:\Users\文少\...`）直接 UnicodeEncodeError 崩溃，像素验证没跑成（check_r269 日志）。
- r270 = `t222_run_dynamic_video_wallpaper_r270.ps1` + `.py`：PATHS.txt 改 utf-8、bat 走 ascii-replace 守卫、优先复用 r269 已下载的 mp4、清理 r269 的 Startup/bat 残留（防重启双开），其余复刻 r266 已验证配方。
- 状态：⏳ 已排队。

## round 271 (2026-10-05, pixel-only verdict)
- r270 诊断：像素证据显示视频壁纸**在播**（换上前→后 99.7% 变化；100s/106s 两帧 7.8% 持续运动——与 r266 成功时同量级），但 `tasklist` 数到 0 个 vlc.exe，触发保守回滚（现已是 r267 静态）。教训重申（r251 就写过）：**信像素，别信进程计数**。
- r271 = `t223_*`：判定改为纯像素（A→B 变化 + 两处晚期探针 ~101s/107s 和 ~195s/201s 都在动才 READY）；复用已下载的 hotori mp4；清理 r270 残留；PATHS.txt utf-8 / bat ascii 守卫保留。
- 状态：❌ NameError 崩溃（助手侧拼装错误，无副作用）。

## round 272 (2026-10-05)
- r271 败因：助手侧拼接脚本的低级错误——`R270_MP4` 未定义（NameError，任务 20 秒即崩，没碰任何壁纸状态；r270 的残留 bat 已被清掉）。
- r272 = `t224_*`：补上定义 + 全量未定义名字扫描通过；其余与 r271 设计一致（纯像素判定 + 双晚期探针）。
- 状态：⏳ 已排队。

## round 272 结果（2026-10-05 20:54-20:59，✅ 动态壁纸上墙，闭环）
- **Hotori Above a Sunset City**（livelywallpaper.app 现成动态壁纸 mp4，1080p/2.66MB/15.5s 循环）已设为桌面壁纸，VLC `--video-wallpaper` 播放。
- 像素证明：换上前→后 99.5% 变化；~105s 两帧 8.4% 运动、~200s 两帧 13.3% 运动 → `persistent_motion_proven=True`；`DYNAMIC_VIDEO_WALLPAPER_READY=True`；round 272 自动 accept（判据 485+ 全过）。
- 持久化：`E:\0mcp-agv-arena-optimized\wallpapers\dynamic-video-r272\`（mp4 + Start/Stop bat + PATHS.txt）；开机自启 = Startup 文件夹 `R272 Dynamic Video Wallpaper Start.bat`（开机延迟 20 秒启动；不想开机自动恢复就删它；停止用 Stop bat；换回静态 = 右键个性化或重设 r267 png）。
- 本会话总账：round 268 通道冒烟 ✅ → 269 编码崩溃 ❌ → 270 进程计数误判回滚 ❌（但像素证明在播）→ 271 助手侧 NameError ❌ → 272 ✅ 闭环。「自动 pull → 执行代码 → push 本地结果 → 反复轮询」全链路在 5 轮里自动运转，两轮完全 hands-free accept（268、272）。

## round 273 (2026-10-05, 用户否决 VLC，Lively 上场)
- 用户判定：**VLC 那不是壁纸**（`--video-wallpaper` 在 Win11 上是无边框覆盖窗口，像素测试无法区分"壁纸层"和"盖桌面的窗口"——结构证明缺失是我的验收漏洞）。
- r273 = `t225_*`：① 彻底退役 VLC（杀进程 + 删 R272 自启/bat，保留 mp4）② 清 Lively 僵尸（r258 的死因）③ Settings.json 备份后关掉 pause 规则（电池暂停默认开！）④ 干净启动 Lively 主程序（维基要求先运行）⑤ setwp hotori mp4 ⑥ **结构性证明**：枚举窗口树，Lively 播放窗口必须是 WorkerW/Progman 的子窗口（真正图标层之下的壁纸层）+ 双晚期像素探针。全量诊断（Settings schema/电源状态/窗口树）入回执。
- 状态：⏳ 已排队。

## round 274 (2026-10-06, 判据修正)
- r273 复盘：壁纸其实**装好了**——Lively v2.2.1 用 mpv.exe 当播放器，`class=mpv owner=mpv.exe` 的窗口就嵌在 WorkerW 壁纸层（图标层之下，无覆盖窗口），像素 88% 变化 + 双探针持续运动。但判据写死找"Lively 名字的进程"→ 误判 → 回滚拆掉了装好的壁纸。
- r274 = `t226_*`：结构判据改为「WorkerW/Progman 层内任何**非 explorer** 的全屏播放窗口」都算壁纸层（mpv/webview/gif 播放器通吃）；BatteryPause/PowerSaveModePause 按 0/1 整数正确关闭（r273 翻转 0 条的教训）；其余流程不变（杀僵尸→改设置→起 Lively→setwp→play→结构+像素双证→不回滚）。
- 状态：⏳ 已排队。

## round 274 结果（2026-10-06 10:31，✅ 真·动态壁纸成立，闭环）
- **Lively Wallpaper v2.2.1** 正在播放 **Hotori Above a Sunset City**（hotori mp4）：`class=mpv owner=mpv.exe rect=(0,0,1536,864)` 的播放窗口嵌在 **WorkerW 壁纸层**（`wallpaper_layer_proven=True`，桌面图标层之下，无覆盖窗口）。
- 像素：换上 88.4% 变化；~105s 20.4% / ~200s 19.3% 持续运动 → `persistent_motion_proven=True`。
- `BatteryPause`/`PowerSaveModePause` 已按 0/1 整数正确关闭（电池供电也继续动）；开机自启走 Lively 自带 `Startup=true`。
- round 274 自动 accept。轮询循环总账：268 ✅ 269-271 ❌ 272 ✅(VLC假壁纸,用户否决) 273 ❌(壁纸装好了但判据误杀回滚) **274 ✅ 真壁纸**。
