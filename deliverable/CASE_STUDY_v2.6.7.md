# CASE_STUDY —— v2.6.7 值守闭环的**已核实**证据，与 v2.6.8 的待复验清单

> **这份文件的诚实边界**
> - 第 1、2 节的每一条都能在 `git` 里复核（给了 sha，`git show <sha>` 即可）。
> - 第 3 节是**用户本机**（`LAPTOP-R77M5D6M`）真机检查文件的原文，逐字复制，未加工。
> - 第 4 节起全部是 **v2.6.8 新增内容**，在写这份文件时**尚未在真机上跑过**，逐条标
>   **待真机复验**。这里不写任何"已通过"的记录。
> - 本文档由 Arena 沙箱侧撰写；沙箱是 Linux，**没有 PowerShell**，因此 v2.6.8 的 `.ps1`
>   改动只经过静态闸门（见第 5 节），语法与真机行为都还没被 PowerShell 验证过。

---

## 1. 闭环提交链（`git log` 可核实）

值守闭环的完整一轮半，全部由**本机**（author 是本机用户，不是 agent）推上来：

| # | sha | 时间（+0800） | subject | 改动文件 |
|---|---|---|---|---|
| 1 | `7c5521f` | 2026-09-16 09:23:15 | `check: request round 16 (self-test)` | `results/status/handshake.json` |
| 2 | `abffd1c` | 2026-09-16 09:23:45 | `check: round 16 passed` | `results/status/check_r16_20260916-092327.txt`、`handshake.json` |
| 3 | `f0d5d1c` | 2026-09-16 09:34:12 | `check: request round 17 (few-step check)` | `code/accept_test.ps1`（0 字节）、`handshake.json` |
| 4 | `bec74fa` | 2026-09-16 09:36:16 | `check: round 17 passed` | `results/status/check_r17_20260916-093600.txt`、`handshake.json` |

四个提交的 author 都是 `shaohuawen03-cyber <shaohuawen03@gmail.com>`，即本机 git 身份 —— 也就是说
**"agent 请求 → 本机自动跑检查 → 结论免点击推回"这条链是机器自己走完的**，中间没有人手动
commit/push 结论（`check: round N passed` 这两个提交是 `push.ps1 -NoPrompt` 推的）。

时间差也对得上闭环语义：

- round 16：请求 `09:23:15` → 结论 `09:23:45`，**30 秒**（轮询间隔内被立刻捡起）。
- round 17：请求 `09:34:12` → 结论 `09:36:16`，**约 2 分 4 秒**（跨了一个轮询 tick）。

`handshake.json` 最终状态（`bec74fa`）：

```json
{
    "round":  17,
    "arena_state":  "awaiting_check",
    "local_state":  "passed",
    "host":  "LAPTOP-R77M5D6M",
    "note":  "few-step check round 17",
    "arena_updated":  "2026-09-16 00:48:09",
    "local_updated":  "2026-09-16 09:36:13"
}
```

## 2. 这条链**证明**了什么，**没有**证明什么

**证明**（有 sha + 检查文件为凭）：

1. 值守任务在无人值守的情况下自己跑完了 `code/local_check.ps1` 并写出检查文件；
2. 结论提交是**免点击**推回远端的（否则远端不会出现 `check: round N passed`）；
3. 检查项 2a（免点击推送）与 2b（零弹窗值守）在该机上为**通过**，原文见第 3 节。

**没有**证明：

- 没有证明"零窗口"是**严格零闪**：round 16/17 的 2b 走的是 `session 0 (S4U)` 分支，这条分支
  本身就是零闪的，但它不覆盖"可见控制台里的常驻循环"那条路径；
- 没有证明 `watch.ps1` 在**可见窗口**里的收尾行表现 —— 那正是 v2.6.8 要补的（第 4 节）；
- round 16 的 note 是 `self-test`、round 17 是 `few-step check`，都是**握手自检**轮次，
  不是承载新功能代码的验收轮次。

## 3. 真机检查文件原文（逐字，未加工）

`results/status/check_r16_20260916-092327.txt` 与 `check_r17_20260916-093600.txt` 内容一致，
只有 round 号与 elapsed 不同：

```text
check round 17 on LAPTOP-R77M5D6M - passed (exit 0)
cmd: powershell -NoProfile -ExecutionPolicy Bypass -File code/local_check.ps1
elapsed: 13s

OK: all .ps1 files are ASCII-only
NOTE: python3 is not a working python - trying plain text
OK: sync.config.json branch=arena/01a0a4f5-git-pull-arena remote=origin (checked without python)
OK: root scripts identical to skills/git-sync/scripts
SKIP: python3 is not a working python - $var: typo scan skipped here
      (it still runs in the agent sandbox before every push)
OK: every .ps1 parses
   (gate ran via E:\hermes\git\bin\bash.exe [git])
== accept 2a: silent push PROVEN (ls-remote + push --dry-run, prompts disabled)
== accept 2b: ZERO window - session 0 (S4U), logon type S4U
== local checks passed
```

**从这份原文里读出的两个环境事实**（很重要，决定了 v2.6.8 的检查怎么落位）：

- `python3 is not a working python` —— 该机的 `python3` 是 Windows Store 占位符。
  ⇒ `code/check_all.sh` 的 **§3c 在这台机器上会 SKIP**（它先自检解释器）。
  ⇒ 真正在本机把关的是 **PowerShell 版的 `code/check_loop_summary.ps1`（accept 2c）**。
  这就是 v2.6.8 坚持"py + ps1 两份"的原因，不是冗余。
- `OK: every .ps1 parses` —— 该机有 PowerShell，`check_all.sh` §4 会真跑。
  ⇒ v2.6.8 的 `.ps1` 语法会在**第一轮真机检查**时被 PowerShell 自己的解析器验证；
  沙箱侧（无 PowerShell）只能 SKIP 这一节。

## 3b. v2.6.7 基线在真机上**复现**了 v2.6.8 要修的问题（2026-09-16 实测）

用户在 `E:\0github\git-sync\git-pull-arena-v268` 克隆了 `arena/01a0a4f5`（当时 PR 未合，拿到的是
**v2.6.7**），于是顺手得到了 v2.6.8 两个目标 bug 的真机复现。以下都是终端原文。

**① 手动单轮静默退出**（v2.6.8 第 1 项要修的）：

```text
PS E:\0github\git-sync\git-pull-arena-v268> .\watch.ps1
PS E:\0github\git-sync\git-pull-arena-v268>
```

一条输出都没有就退回提示符 —— 看不出它跑了没跑、结论是什么。v2.6.8 起这里必须打印
`== <summary>` 再跟一行 `== finished at HH:MM:SS (manual poll; the scheduled loop keeps running)`。

**② host log 中文乱码**（v2.6.8 第 4 项要修的）。`-Status` 与 `-Register` 的 host log tail：

```text
[2026-09-16 10:18:48] launcher smoke test could not start: 鐢变簬鍑虹幇浠ヤ笅閿欒锛屾棤娉曡繍琛屾鍛戒护: %1 涓嶆槸鏈夋晥鐨?Win32 搴旂敤绋嬪簭銆傘€?
```

原文应是「由于出现以下错误，无法运行此命令: %1 不是有效的 Win32 应用程序。」。
已核实这是 **UTF-8 字节被按 GBK 读回**：把原文按 UTF-8 编码再按 GBK 解码，得到的前 8 个字
`鐢变簬鍑虹幇浠ヤ笅閿欒` 与真机输出**逐字一致**（后面几字的差异是终端复制时的二次有损转码）。

同一个 `-Status` 输出里，`state dir : C:\Users\文少\AppData\Local\git-sync` 的中文是**正常**的 ——
那一行是 PowerShell 直接写的字符串，没经过读文件。所以问题在**读**的一侧
（v2.6.7 的 `Get-LogTail` 用默认编码读），不在控制台字体，这正是 v2.6.8 改成
`Get-Content ... -Encoding UTF8` 的依据。

**③ 计划任务结果码没有解释**（v2.6.8 第 4 项）：

```text
   last run    : 2026-09-16 10:19:30 | schedule result: 267009
```

`267009` = `0x41301`「任务正在运行」，对常驻循环是**正常**的，但裸一个数字看不出好坏。
v2.6.8 起这一行会带 `= still RUNNING (0x41301) - normal, the loop never exits`。

**④ 同一份输出里的旁证**：`loop process: pid 83888 (running)`、`heartbeat age: 0 min (fresh)`、
`poll took 1s` 后紧跟 `== idle - next poll at 10:19:34 (Ctrl+C stops this loop)` —— 说明 v2.6.7 的
轮询闭环本身是健康的，坏的是**收尾行的可见性**，不是轮询逻辑。这也界定了 v2.6.8 的改动范围。

> 附带发现（与 v2.6.8 无关，属于既有问题）：零窗口启动器冒烟测试失败
> `exe: C:\ProgramData\git-sync\watchhost-git-pull-arena-v268.exe (True)  size: 6144` +
> `%1 is not a valid Win32 application`，于是自动回退 `-Flash` 模式。6144 字节的 exe 说明编译产物
> 被杀软拦掉或没写全。这条 v2.6.8 没有动，单独立账。

## 4. v2.6.8 新增项 —— 全部 **待真机复验**

| # | 改动 | 静态闸门已验证 | 真机行为 |
|---|---|---|---|
| 1 | `watch.ps1`：`Invoke-PollRound` 6 个出口 + `Invoke-PollOnce` 2 个出口各自设置 `$script:PollSummary`，循环与手动单轮都打印 | ✅ `check_loop_summary.py`（6 exit paths） | **待真机复验** |
| 2 | 新增 `code/check_loop_summary.py`（闸门 §3c）+ `code/check_loop_summary.ps1`（accept 2c） | ✅ 正/负向都跑过（见第 5 节） | **待真机复验**（`.ps1` 那份还没被 PowerShell 执行过） |
| 3 | `Get-PowerShellExe` 优先 64 位：pwsh 原样 → 32 位进程走 `SysNative` → `System32` → 当前进程 | ⚠️ 仅静态（无 PowerShell 可跑） | **待真机复验** |
| 4 | `-Status`：host log 尾部按 UTF-8 读；任务结果码加人话注释（0 / 267009 / 267011 / 267014 / 2147946720）；代理提示改成可照抄的 `setx HTTPS_PROXY "..."` | ⚠️ 仅静态 | **待真机复验** |
| 5 | `doctor.ps1`：上述结果码一律视为正常，只有别的码才提示 | ⚠️ 仅静态 | **待真机复验** |
| 6 | 文档：`skills/git-sync/templates/install-one-liner.md`（新）、README「零」节、本文件 | n/a | n/a |
| 7 | 删掉分支上那个 0 字节的 `code/accept_test.ps1`（`f0d5d1c` 引入的垃圾） | ✅ | n/a |
| 8 | `install.ps1`：`$src` 自适应（根目录/`scripts\` 两种位置都能跑）、`code\check_loop_summary.*` create-only 安装、根目录镜像加 `install.ps1` | ⚠️ 仅静态 | **待真机复验** |

### 收尾行文案（逐字，用户已熟悉，不要改写）

```text
== round {N} checked ({verdict}) - verdict pushed back to {remote}/{branch}
== round {N} checked ({verdict}) but the verdict was NOT pushed ({reason})
== idle - no check requested (arena={arena_state} local={local_state})
== another poll is still running (lock held) - skipped this tick
== poll CRASHED: {msg} - the next tick retries
== idle - no handshake file yet on {remote}/{branch}
== round {N}: sync FAILED - will retry next poll
== round {N} was already answered elsewhere - nothing to do
== next poll at HH:MM:SS (Ctrl+C stops this loop)
== finished at HH:MM:SS (manual poll; the scheduled loop keeps running)
```

前 8 条一一对应 8 个出口（6 个在 `Invoke-PollRound`、2 个在 `Invoke-PollOnce`）；后 2 条由循环体
与手动单轮各自固定追加。

## 5. 沙箱侧**已经**跑过的验证（这些是真跑过的，不是声明）

```text
$ bash code/check_all.sh
OK: all .ps1 files are ASCII-only
OK: sync.config.json branch=arena/01a0a7de-git-pull-arena
OK: root scripts identical to skills/git-sync/scripts
OK: no drive-style variable typos ($var:)
== exits in Invoke-PollRound: 6
OK: every exit path sets its closing summary
== exits in Invoke-PollOnce: 2 (lock held / crashed / normal)
OK: loop closing lines covered (6 exit paths, all with their own summary)
SKIP: no PowerShell on PATH - .ps1 syntax not parse-checked here
$ echo $?
0
```

负向自测（必须失败，实测都失败）：

| 破坏方式 | 结果 |
|---|---|
| 删掉 `Invoke-PollRound` 里任意一条 `$script:PollSummary = ...` | `check_all.sh` **exit 1**，并指出具体行号：`[FAIL] watch.ps1:1037: exit does not set $script:PollSummary first: return 0` |
| 把 `verdict pushed back to` 改成别的措辞 | `check_loop_summary.py` **exit 1**：`required closing-line wording is gone` |
| 换成只有 1 个出口的桩文件 | **exit 1**：`only 1 exit path(s) found, expected at least 5` |
| 传一个不存在的路径 | **exit 1**：`cannot read ...` |

**沙箱跑不了的**：`.ps1` 语法解析（无 PowerShell）、`Get-PowerShellExe` 的 64 位分支、
`-Status` / `doctor.ps1` 的结果码注释、`install.ps1` 的实际拷贝行为。

## 6. 真机复验清单（用户执行）

```powershell
cd E:\0github\git-sync\git-pull-arena-v268          # v2.6.8 的独立克隆（任务名/心跳/日志都独立）
.\sync.ps1
.\watch.ps1 -Unregister ; .\watch.ps1 -Register
.\watch.ps1 -Status                                 # skill 那行必须是 v2.6.8，否则你在测 v2.6.7
.\watch.ps1 -Test
.\code\check_loop_summary.ps1 -WatchPath .\watch.ps1
```

> **先确认版本再往下走**（2026-09-16 就栽在这一步：克隆的是 `arena/01a0a4f5` = v2.6.7，
> 于是 `check_loop_summary.ps1` 根本不存在、`-Status` 显示 `skill : v2.6.7`）：
>
> ```powershell
> Get-Content skills\git-sync\VERSION              # 必须是 2.6.8
> Test-Path code\check_loop_summary.ps1            # 必须是 True
> git log --oneline -1                             # 必须能看到 5882cc8 或其后代
> ```

然后造一个新轮次（`handshake.json` 的 `round` +1，`arena_state=awaiting_check`、
`local_state=pending`，用 `.\push.ps1` 推请求），等 2~3 分钟，逐条核对：

| 期望 | 在哪看 |
|---|---|
| `last_round` = 新轮次、`last_push` = `ok` | `.\watch.ps1 -Status` |
| `git log` 出现 `check: round N passed` | `git log --oneline -3` |
| host log 出现 `== round N checked (passed) - verdict pushed back to ...` | `-Status` 的 host log tail |
| 紧接着出现 `== next poll at HH:MM:SS (Ctrl+C stops this loop)` | 同上 |
| `last run / schedule result` 带人话注释，且 267009 / 2147946720 不再被当异常 | `-Status` 与 `.\doctor.ps1` |
| host log 里的中文不再乱码（v2.6.7 实测是乱码，见第 3b 节） | `-Status` 的 host log tail |
| 手动单轮 `.\watch.ps1`（不带 `-Loop`）以 `== <summary>` + `== finished at ...` 结束，不静默退回提示符 | 手动跑一次 |
| `code\check_loop_summary.ps1` 单独跑输出 `== check_loop_summary PASSED`，exit 0 | `.\code\check_loop_summary.ps1 -WatchPath .\watch.ps1` |
| `local_check.ps1` 输出 `== accept 2c: watcher closing lines verified (every exit path has its summary)` | 下一轮检查文件 |

任何一条对不上，把 `-Status` 与对应 `results\status\check_rN_*.txt` 的原文贴回来。

---

*本文档随 v2.6.8 一起提交到工作分支 `arena/01a0a7de-git-pull-arena`。真机复验通过后，第 4 节的
「待真机复验」应逐条改写成实测结果（连同当时的 `-Status` 原文与检查文件）。2026-09-16 决定：
**暂不开 PR 到 `main`**，v2.6.8 就停在工作分支上；`main` 仍是 v2.6.7。*
