# v2.5.0 升级与验收（零弹窗值守 + 免点击推送）

> 针对你的三条要求：**① 单个测试成功 ② 无弹窗 ③ push 不用手动点**，
> 外加第 4 条"多会话协作暂时不弄"。
> 本文件是本机侧的**照做清单**；技能细节见 `skills\git-sync\README.md` 与 `SKILL.md`。

---

## 一、这次到底改了什么

### 1. 无弹窗：值守不再闪黑窗（也不用管理员、不用 VBScript）

**为什么以前会闪**：Task Scheduler 启动 `powershell.exe`（控制台程序）时，Windows
**必然先创建一个 console 窗口**，`-WindowStyle Hidden` 只能事后再把它藏起来——所以每次轮询都闪一下。
v2.4.4 想用 `wscript + invisible.vbs` 绕开，结果 Windows 11 正在淘汰 VBScript，
值守全线静默死亡而任务状态还显示正常（`LastTaskResult 0`）。

**v2.5.0 的做法**：`watch.ps1 -Register` 现场编译一个**GUI 子系统**启动器
（`%LOCALAPPDATA%\git-sync\watchhost-<仓库>.exe`，约 5 KB，用 .NET Framework 自带的 csc，不需要装任何东西），
由它用 `CreateNoWindow` 拉起 powershell——**根本不创建窗口**，0 帧闪动，不需要管理员权限。
编译失败会自动回退到旧模式并**明说**，不会假装成功。

**防"看着成了其实没成"（v2.4.4 的教训）**：注册后立刻做**自检**——
真的跑一次计划任务并等心跳文件出现；自检失败自动改用 `-Flash` 重注册，再失败就报错退出。

### 2. 免点击：push 不再等你点确认（新增 `auth.ps1`）

**为什么会卡**：GitHub 早就只认令牌；默认的 Windows 凭据管理器（wincredman）在
计划任务/后台会话里要么弹窗、要么（session 0 / SSH 下）根本读不到——于是值守推送
挂在那里等人点，或者干脆失败。`auth.ps1` 把这件事一次性解决并**证明**给你看：

| 优先级 | 方式 | 为什么 |
|---|---|---|
| 1 | `gh auth setup-git` | 令牌存在 gh 自己的配置文件里，任何会话都能读到，永不提示 |
| 2 | GCM + `credential.credentialStore=dpapi` | 没装 gh 时用；DPAPI 文件不依赖交互式桌面（wincredman 依赖），session 0 也能读 |
| 3 | `-Token` / `-TokenFile` / `-PromptToken` | 完全不想走浏览器时，直接播种令牌（**永不回显**，也不写进仓库） |

配套：`push.ps1` **默认静默模式**——所有 git 调用的 `GIT_TERMINAL_PROMPT=0`、
`GCM_INTERACTIVE=never`、`credential.interactive=false`，拿不到凭据就**立刻失败**（exit 4）
并告诉你跑 `auth.ps1 -Setup`，**绝不弹窗等待**（要交互才用 `push.ps1 -Prompt`）。

### 3. 单会话闭环：多会话协作搁置

模式 B（同仓库多分支）/ 模式 C（汇总会话）暂停使用；今后默认"一会话一仓库"。
单会话闭环的验收标准就一条：agent 一条 `agent-wait.sh --request "..." --auto-accept`
在**一轮对话内**拿到 exit 0（本机值守零窗口跑完 + 免点击推回）。说明与重启方法留在
`skills\git-sync\README.md` 第七节。

### 4. 顺手修的问题（"还有什么要改进的"）

| 改动 | 解决什么 |
|---|---|
| `watch.ps1 -Status` / `-Test` | 值守"到底活着吗"以前只能看任务状态（会骗人）；现在看心跳（`%LOCALAPPDATA%\git-sync\watch-<仓库>.json` + `.log`，含每次 git 调用的结果） |
| 检查硬超时 `check_timeout_min`（默认 30 分钟） | 检查卡死会让轮询永久占锁；现在超时判 `failed` 并在日志头写 `TIMEOUT`；`lock_stale_min` 自动跟随（≥ 超时 + 15） |
| 检查日志带 `elapsed:` 与空输出显式标记（v2.4.7 起）+ 真实退出码 | 防"检查链空转、轮轮假通过" |
| 每次轮询最多重试 3 次推送（间隔 20s） | 网络抖动不再让一轮结论白做 |
| 同一 round 被别的克隆答过就跳过 | 多克隆/多机器同时值守时不再重复跑同一轮 |
| `push.ps1` 的失败分类 | 认证失败（exit 4）与网络/分支问题分开，提示对应修法 |
| `doctor.ps1` 增加 watcher / heartbeat / auth 三行 + 顺序提示 | "不对劲先跑 doctor"现在能看到值守与凭据 |
| gate 增加"每个 `.ps1` 都要能解析"（PowerShell 自带解析器；没有就显式 SKIP）+ 缺根目录副本算失败 | 括号/引号写错能在提交前抓到，而不是值守每轮静默失败 |
| `bootstrap.ps1 -Auto` | 新机器一条命令把"凭据 + 值守 + 首次同步"都做掉 |

---

## 二、本机升级（每台机器一次，复制粘贴）

v2.5.0 在新分支 `arena/01a0a4f5-git-pull-arena` 上，所以本机克隆要切一次分支
（旧分支 `arena/01a09fc1-git-pull-arena` 冻结在 v2.4.7，只读保留）：

```powershell
cd E:\0github\git-sync\git-pull-arena
git fetch origin
git checkout arena/01a0a4f5-git-pull-arena     # 本地有改动就先 git stash
.\sync.ps1                                      # 对齐（此时配置里的分支已经是新分支）

.\auth.ps1 -Setup -Verify                       # 免点击推送：配好 + 关闭提示实跑证明
.\watch.ps1 -Unregister                         # 摘掉旧值守
.\watch.ps1 -Register                           # 新值守：零窗口 + 注册后自检
.\doctor.ps1                                    # 看最后四行
```

`.\bootstrap.ps1 -Auto` 是同一套动作的合并版（新机器上用）。

---

## 三、验收（两条硬要求，各一条命令）

| 要求 | 命令 | 通过标准 |
|---|---|---|
| **无弹窗** | `.\watch.ps1 -Status` | `mode` = `zero-window (launcher exe)`；heartbeat 的 `last_run` 每 2 分钟推进；**屏幕上没有任何窗口出现**（观察 4~6 分钟） |
| **免点击** | `.\auth.ps1 -Verify` | 退出码 0（输出里 `git ls-remote` 与 `push --dry-run` 都是 PASSED），全程没有人点过任何东西 |
| 闭环（可选） | 让这个会话跑 `agent-wait.sh --request "..." --auto-accept` | 一轮内 exit 0；`results/status/check_rN_*.txt` 出现且 `local_state=passed` |

任何一项不通过：`.\watch.ps1 -Status` + `.\doctor.ps1` + `%LOCALAPPDATA%\git-sync\watch-*.log`
三处日志贴给会话即可定位（`-Flash` 是保底可用的旧模式）。

---

## 四、诚实说明：沙箱里验证到什么程度

我在 Arena 沙箱（Linux，没有 Windows、没有 PowerShell）里能做的与不能做的：

| 项 | 状态 |
|---|---|
| 全部 `.ps1` 语法/括号配平、ASCII 合规 | ✅ 已检查（gate 现在也会在提交前用 PowerShell 解析器再查一遍） |
| 根目录脚本与 `skills\git-sync\scripts\` 一致性 | ✅ gate 检查通过 |
| `auth.ps1` / `watch.ps1` / `push.ps1` 的逻辑与分支守卫 | ✅ 代码走查 + 文档/命令自检 |
| 启动器编译、`CreateNoWindow` 真实无窗、GCM dpapi 实跑 | ⚠️ **必须在本机验证**——所以设计成"注册后自动自检 + 失败自动回退 + 如实报告"，`-Status` 的 `mode` 与 heartbeat 就是结论 |
| GitHub CLI 分支/权限、远端推送 | ✅ 沙箱内实测（本会话即用该链路提交） |

也就是说：**不需要你相信我**，`-Register` 的自检与 `auth.ps1 -Verify` 的实跑会自己给结论；
任何一处不成立，脚本会明确报错并给出回退命令。

---

## 五、验收轮已经排好（round 7，升级完自动跑）

我在新分支上已经**提前发起了一轮验收请求**（`results/status/handshake.json`：round 7、
`arena_state=awaiting_check`、`local_state=pending`）。你本机升级完成后：

1. 新的值守第一次轮询（≤2 分钟）看到 pending → 自动 `sync` → 跑 `code/local_check.ps1`；
2. 这一轮的检查**本身就断言两条硬要求**：
   * 2a：`auth.ps1 -Verify` 必须实跑通过（prompts 全关下的 `ls-remote` + `push --dry-run`）；
   * 2b：计划任务的动作必须指向 `watchhost` 启动器（而不是 `powershell.exe`）；
3. 结论（passed/failed）由值守**免点击**推回分支，我这边 `agent-check.sh --read` 就能看到。

也就是说：**这一轮就是"单个测试成功 + 无弹窗 + 不用手点"的验收**——
它需要满足"零窗口启动器真的在跑"和"推送真的不需要人"，否则会明确报 2a/2b 哪一项没过。

> 如果你还没升级就看到这轮 waiting：不要紧，请求会一直挂着，升级后第一次轮询就会处理；
> 我这边读到"超时未响应"只说明"本机还没升级"，不是失败。

## 六、回退

```powershell
.\watch.ps1 -Unregister ; .\watch.ps1 -Register -Flash   # 回到"隐藏窗口"模式（每轮闪一下）
git checkout arena/01a09fc1-git-pull-arena               # 回到 v2.4.7 的脚本（旧分支仍在远端）
.\auth.ps1 -Unset                                        # 撤销 -Setup 改过的 git 配置（凭据本身不删）
```
