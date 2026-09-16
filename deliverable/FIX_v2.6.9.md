# v2.6.9 —— 新会话暂停其他值守；切回原会话用 `-Focus`

用户要求两件事：

1. **新对话**要清理其他之前对话的旧进程与旧计划任务；
2. **继续原来的对话**要恢复那些旧进程与旧计划任务。

顺带把 `-Status` 里 last-check 日志的中文乱码修掉（host log 轮转已在 v2.6.8 用 UTF-8；last-check 漏了）。

## 一、行为（不删任务）

**不**对其他会话跑 `-Unregister`。任务还在，只是停掉：

| 动作 | 对其他 `git-sync-watch-*` | 对本克隆 |
|---|---|---|
| 新会话 `.\\watch.ps1 -Register`（`bootstrap -Auto` 会走到这里） | Stop + Disable + 杀掉 `-Loop` 进程 | 照常注册并拉起 |
| `.\\watch.ps1 -Focus` | 同上 | Enable + Start |
| `.\\watch.ps1 -RestoreParked` | Enable + Start 台账里的每一项 | 不动 |
| `.\\watch.ps1 -Register -KeepOthers` | 不动 | 只注册自己 |

台账：`%LOCALAPPDATA%\git-sync\parked.json`（UTF-8，不进 git）。已经是 Disabled 的任务（你自己 `-Pause` 过的、或冻结克隆）不会被二次写入。

循环进程按**文件夹名路径段**匹配（`...\Name\watch.ps1`），所以 `git-pull-arena` 不会误杀 `git-pull-arena-s2`。

## 二、本机：先把 HQ 升到 v2.6.9

不要动冻结目录 `git-pull-arena` / `git-pull-arena-v268`。

```powershell
cd E:\0github\git-sync\git-pull-arena-s2
.\sync.ps1
.\watch.ps1 -Unregister ; .\watch.ps1 -Register
.\watch.ps1 -Status
.\doctor.ps1
```

期望：`skill` 行是 v2.6.9；`other loops` 不出现；`last_push: ok`；last-check 中文不再乱码。

## 三、新 Arena 会话（对方只发那一句之后，你本机跑）

助手会给你填好的 clone 命令。核心是**新文件夹** + `bootstrap -Auto`（内部会 `-Register`，于是自动暂停其他会话的值守）：

```powershell
cd E:\0github\git-sync
git clone -b <BRANCH> <ORIGIN_URL> <NEW_FOLDER>
cd <NEW_FOLDER>
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\bootstrap.ps1 -Auto
.\doctor.ps1
.\watch.ps1 -Status
```

禁止文件夹名：`git-pull-arena`、`git-pull-arena-v268`、`git-pull-arena-s2`。

## 四、继续原来的对话（切回本会话 HQ）

```powershell
cd E:\0github\git-sync\git-pull-arena-s2
.\watch.ps1 -Focus
```

这会：拉起 `git-sync-watch-git-pull-arena-s2`，并把其他 `git-sync-watch-*` 再暂停。

一次把所有被暂停的都拉回来（多会话并行时才需要）：

```powershell
.\watch.ps1 -RestoreParked
```

## 五、改了哪些文件

- `watch.ps1`（根目录 = `skills/git-sync/scripts/watch.ps1`）
  - `-Focus` / `-RestoreParked` / `-KeepOthers`
  - `Invoke-ParkOthers` / `Invoke-RestoreParked` / `Invoke-Focus`
  - `-Register` 默认停车；`-Status` 列出 other tasks + parked
  - last-check `Get-Content -Encoding UTF8`；host log 轮转同样 UTF-8
- `doctor.ps1`：other tasks / parked 两行 + next steps
- `skills/git-sync/templates/one-sentence.md`：一句话协议带上暂停/切回
- `VERSION` = 2.6.9

## 六、验收（本机跑完把输出贴回来即可）

```powershell
Get-ScheduledTask git-sync-watch-* | Select-Object TaskName, State
Get-Content $env:LOCALAPPDATA\git-sync\parked.json -Encoding UTF8
```

新会话 Register 之后：只有新文件夹那个任务是 Ready/Running，HQ 的 `git-sync-watch-git-pull-arena-s2` 是 Disabled。
HQ `-Focus` 之后反过来。
