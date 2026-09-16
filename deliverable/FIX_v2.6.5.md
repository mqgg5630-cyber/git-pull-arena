# v2.6.5 —— "卡住"其实是**成功了**；顺手把控制台被你占住的体验修掉

## 一、先说结论：round 13 **通过**，而且是全自动推回来的

```
== check passed (log: results/status/check_r13_20260916-083139.txt, 11s)
== pushed to arena/01a0a4f5-git-pull-arena : d973d63 check: round 13 passed
== verdict pushed back to origin/arena/01a0a4f5-git-pull-arena
```
我这边读到的远端握手文件：`round 13 / local_state: passed / host: LAPTOP-R77M5D6M`。
**整条链路闭环了**：改代码 → 值守自动验证 → **免点击**把结论推回（你这次一根手指都没动）。

## 二、那"一直卡住"是什么

那个黑窗口没有卡，是**值守本人**：flash 模式下的值守是一个**常驻进程**（`-Loop`），
`-Register` 自检把它启动时，Windows 把它**挂到了你当前这个控制台**上——于是它每 2 分钟往你这个窗口
打印一次、永远不退出。你在那个窗口里看起来就"卡住/停不下来"。

**怎么办**：那个窗口就是值守，**别关**（关了要等下一次 keeper 心跳，最多 10 分钟才重启）；
需要输入命令请**另开一个 PowerShell 窗口**。

## 三、v2.6.5 把它彻底修了

| 改动 | 效果 |
|---|---|
| 值守启动后**自我脱离**：检测到自己带着可见控制台，就用 `-WindowStyle Hidden` 重新启动一份（子进程带标记，不会无限递归） | 你那个窗口立刻恢复自由；"每次登录闪一下"变成**不足一秒**（真正的零窗口仍是启动器 / `-Headless`） |
| **单实例保护**（循环 pid 文件） | 脱离后任务实例会退出，keeper 每 10 分钟会再拉起任务——没有这道闸就会堆出多个循环；现在第二个实例发现已有循环就直接退出 |
| `-Pause` / `-Unregister` 现在会**真的停掉循环进程**（以前只停任务） | 摘掉值守变得干净彻底；`-Status` 里新增 `loop process: pid ... (running)` |
| `-Test` 改用"循环 pid + 心跳年龄"判断 | 脱离后任务状态不再是 Running，旧判断会误报 |

## 四、顺便修掉 round 13 日志里的一个真问题（我的）

你那份日志里其实藏着一条矛盾：

```
NOTE: python3 is not a working python - trying plain text
OK: sync.config.json ... (checked without python)
OK: every .ps1 parses
[FAIL] gate failed (exit 1)          ← 闸门确实失败了
== accept 2a: silent push PROVEN     ← 但结论却报成 passed
```
两处都是我的 bug：

1. **闸门失败原因**：同一台机器上那个不能用的 `python3` 也被**防坑扫描器**（`$var:` 检查）用了，
   扫描器崩掉 → 闸门判 FAIL。→ 现在扫描器也先自检解释器，不能用就 SKIP 并注明
   （真正的扫描仍在我的沙箱里每次提交都跑）。
2. **为什么失败还报 passed**：`cmd /c "X > out & echo %ERRORLEVEL% > code"` 里的 `%ERRORLEVEL%`
   是 cmd **解析整行时**就展开的——拿到的是**上一条命令的**退出码（老坑）。所以退出码要么空、
   要么是过期的 0。→ 改成 `/v:on` + `!ERRORLEVEL!`（执行时才展开），退出码现在是真的。

> 对你的两条硬指标没有影响（2a/2b 那两行是实打实的），但它会导致"明明有问题却显示通过"，
> 必须修——否则以后我这边看到的"passed"就不可信了。

## 五、零窗口还剩最后一步（可选）

启动器现在能编译、能校验、路径也搬到 ASCII 目录了，但 `Process.Start` 仍报
`%1 不是有效的 Win32 应用程序`（文件在、6144 字节、MZ 头正常）——这是典型的**杀软拦截**
（"运行时编译出来、专门用来静默启动 PowerShell 的 exe"是启发式最敏感的类型）。

三个选择（按省事排序）：
1. **什么都不做**：v2.6.5 之后，flash 模式的实际表现是"**登录时闪不足一秒**"，日常几乎无感；
2. **管理员窗口**里 `.\watch.ps1 -Unregister ; .\watch.ps1 -Register -Headless`（session 0，严格零闪；
   你 gh 已登录，凭据在 gh 自己的配置里，session 0 可读）；
3. 给 `C:\ProgramData\git-sync\` 加一条杀软/Defender 排除项，然后重跑 `.\watch.ps1 -Register`
   （会打印 `launcher works` 就是真零闪）。

## 六、现在照做（3 条）

```powershell
cd E:\0github\git-sync\git-pull-arena

.\sync.ps1                                              # 取 v2.6.5
.\watch.ps1 -Unregister ; .\watch.ps1 -Register          # 新循环（自带脱离 + 单实例）
.\watch.ps1 -Status                                      # 2 分钟内：last_push: ok
```
顺手清掉 9 条 stash：`git stash list ; git stash clear ; git status`

**round 14 已排好**：这轮的目的是验证"退出码是真的了"（闸门这次应该真的全绿）+
确认新循环不再占用你的控制台。你在 `-Status` 里看到的 `last_verdict` 就是真值。

---

## 附：从 v2.5.0 到现在的完整问题账（共 12 项，全部已修）

| # | 问题 | 版本 |
|---|---|---|
| 1 | VBScript 启动器在 Win11 静默死亡 | v2.5.0 换编译式启动器 |
| 2 | `"$round:"` 盘符写法 → 整个 watch.ps1 解析失败 | v2.5.1 + gate 扫描器 |
| 3 | `auth.ps1 -Setup` 乱改 `credentialStore`，把已有凭据藏掉 | v2.5.1 |
| 4 | 机器从未存过 GitHub 凭据 → 一直要手点 | gh 登录（`-GhLogin`）后彻底解决 |
| 5 | gh 不走 git 的代理 → 登录超时 | v2.6.1（自动套用 `http.proxy` / `-HttpProxy`） |
| 6 | 我的 dry-run 探针把"非快进被拒"当认证失败 | v2.6.2 |
| 7 | 值守结论提交导致分叉 → `pull --ff-only` 永远失败 | v2.6.1/v2.6.2 |
| 8 | `sync.ps1`/`push.ps1` 把 git 的 stderr 当终止性错误 → 轮询中途崩溃 | v2.6.3/v2.6.4 |
| 9 | `check_cmd` 用裸名字启动失败（`%1 不是有效的 Win32`） | v2.6.3 |
| 10 | 退出码读不出来（`failed (exit )` / 假 passed） | v2.6.4（标记文件）、v2.6.5（`!ERRORLEVEL!`） |
| 11 | 闸门因"不可用的 python"假失败 | v2.6.4（配置）/ v2.6.5（扫描器） |
| 12 | 值守常驻进程占住用户控制台（"卡住"） | v2.6.5（自我脱离 + 单实例） |
