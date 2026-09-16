# v2.6.3 —— 2a 已经过了，这次修掉"值守跑不完"的最后三个坑

> 好消息先说：**免点击推送成立**。
> ```
> silent credential probe : OK - username=mqgg5630-cyber password=(hidden, 40 chars)
> push --dry-run          : PASSED
> == verdict: READY - a push completes with no window and no click.
> ```
> 这就是你要的 2a。剩下的问题都出在"值守把这一轮跑完"这一步上，日志把三个原因都写清楚了。

---

## 一、坑 1：`poll crashed: Already on 'arena/01a0a4f5-git-pull-arena'`

`git checkout <分支>` 在"已经在该分支"时会把 `Already on '...'` 写到 **stderr**——
这本来是**正常信息**，但 PowerShell 5.1 在 `$ErrorActionPreference = 'Stop'` 下会把子进程的
stderr 当成**终止性错误**，于是 `sync.ps1` 从中间炸掉、整个轮询被中断，结论永远推不出去。
（之前你看到的那两行 `+| ...` 红字也是同一个机制。）

**v2.6.3 修复**：`sync.ps1` 里**所有** git 调用都改走 `cmd /c`（stderr 保持 stderr，退出码取 git 自己的），
并且轮询崩溃时会写进心跳（`last_action=error`），不再留一个"看起来正常"的心跳。

## 二、坑 2：`check_cmd could not be started: ... %1 不是有效的 Win32 应用程序`（exit 193）

这是 `ERROR_BAD_EXE_FORMAT`：我在任务里用**裸名字** `powershell` 去 `Start-Process`，
而计划任务的 PATH 与你的控制台不同，裸名字解析到了一个"不是可执行文件"的东西上，于是检查**根本没跑**
（`elapsed: 0s`）。

**v2.6.3 修复**：
* `check_cmd` 的首个词先解析成**绝对路径**（`powershell` → `C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe`；
  `bash` → 优先用**你用的那个 git 自带的 bash**，而不是 `C:\WINDOWS\system32\bash.exe`(WSL)，WSL bash 读不了 Windows 目录）；
* 整条命令交给 `cmd /d /c` 执行，输出重定向到临时文件（顺便：读回时用 ANSI 编码，
  之前的乱码 `鐢变簬...` 就是按 UTF-8 读 GBK 输出造成的）；
* 超时改为**杀进程树**（`taskkill /F /T`），不再留下还在跑的检查；
* `Start-Process` 万一失败就**退回进程内执行**，宁可没有超时也别整轮失败；
* 解析后的命令行写进 host 日志，下次一眼就能看出到底跑的是什么。

## 三、坑 3：本地"结论提交"堆到 313 个

`sync.ps1` 之前每轮都把值守产物**提交一次**（为了不再堆 stash），而推送失败时这些提交留在本地，
于是 `ahead by 313 commits`，`pull --ff-only` 永远失败。

**v2.6.3 修复**：只要"未推送的提交"里最新一条是值守产物提交，就 **amend**（合并）它，
而不是再开新提交——本地永远只有 1 个产物提交；加上 v2.6.2 的自动对齐，多轮之后也不会再堆。

---

## 四、现在照做（3 条）

```powershell
cd E:\0github\git-sync\git-pull-arena

.\sync.ps1            # 取 v2.6.3；会把 313 个结论提交对齐掉（文件保留）

.\watch.ps1 -Unregister ; .\watch.ps1 -Register    # 新代码 + keeper 改为 10 分钟保活

.\watch.ps1 -Status   # 这次应该看到：loop alive / heartbeat 在推进 / last_push: ok
```

顺手清一下历史 stash（8 条，里面是值守产物）：
```powershell
git stash list ; git stash show --stat stash@{0} ; git stash clear
```

**注意**：flash 模式下登录时会出现一个黑窗口——**别关它**，那就是值守本体；
关了要等下一次 keeper 心跳（10 分钟）才会重新拉起。
要做到一次都不闪，仍是二选一：管理员窗口执行 `.\watch.ps1 -Unregister ; .\watch.ps1 -Register -Headless`，
或者把 `Get-Content "$env:LOCALAPPDATA\git-sync\watch-git-pull-arena.log" -Tail 30` 发我（v2.6.3 起
冒烟测试失败会把它直接打在屏幕上）。

---

## 五、验收怎么算

| 项 | 现在 |
|---|---|
| 2a 免点击推送 | ✅ 已成立（`push --dry-run: PASSED`，prompts 全关） |
| 2b 值守可见性 | 现在是 `loop (one flash per logon)`（每次登录闪一次）→ **按分级算通过**；零闪是可选升级项 |
| 跑完一轮并推回结论 | v2.6.3 修掉上面三个坑后，第一次轮询（≤2 分钟）应该就能把 `passed` 推回来——**round 12 已排好** |

如果这一轮仍然失败，把这三样发我，一定能定位：
```powershell
.\watch.ps1 -Status
Get-Content "$env:LOCALAPPDATA\git-sync\watch-git-pull-arena.log" -Tail 40
Get-Content (Get-ChildItem .\results\status\check_r*.txt | Sort-Object LastWriteTime | Select-Object -Last 1).FullName
```
