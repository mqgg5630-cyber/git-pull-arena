# v2.6.0 —— 现在到底卡在哪，怎么一次弄好

> 你这一轮的输出把问题定位清楚了。**结论先说**：
> 1. **真正的拦路石只有一个：这台机器的 GCM 里没有存过任何 GitHub 凭据**（所以它每次都弹登录，
>    现在 prompts 被关掉就直接失败）。**没有任何脚本能凭空变出一个凭据——必须登录一次**；
>    登录一次之后，推送、值守永远不再问。
> 2. 值守方面：零窗口启动器在这台机器上**没跑起来**（脚本自动回退到 flash 模式），
>    v2.6.0 改成 **"一次登录一个常驻进程"**：即使退回到 flash 模式，也只在**登录时闪一次**，
>    而不是每 2 分钟闪一次（原来 720 次/天）。启动器还会**先做冒烟测试**再决定用不用它。

---

## 一、照做（4 条，5 分钟）

```powershell
cd E:\0github\git-sync\git-pull-arena

# 1) 一次性登录（唯一需要你动一下的地方；gh 用的是设备码/浏览器，不是脚本弹窗）
.\auth.ps1 -GhLogin -Verify
#    它会：跑 gh 的登录流程 -> 把 gh 设成 git 的凭据助手 -> 关闭一切提示做验证

# 2) 如果第 1 步不方便用浏览器，二选一（都只做一次）：
#    .\auth.ps1 -Setup -PromptToken        # 粘贴一个 PAT，输入隐藏
#    .\auth.ps1 -Setup -TokenFile C:\pat.txt
#    实在不想弄 token：.\push.ps1 -Prompt "login once"   # 让登录窗出现一次，之后不再问

# 3) 取最新脚本（v2.6.0：常驻循环 + 启动器冒烟测试）
.\sync.ps1

# 4) 重注册值守（会先冒烟测试启动器，再自检真的跑起来）
.\watch.ps1 -Unregister
.\watch.ps1 -Register
.\doctor.ps1
```

第 1 步成功的样子：`[ok] gh is logged in` → `[ok] gh is now git's credential helper ...` →
`push --dry-run : PASSED`，退出码 0。

---

## 二、为什么必须登录一次（不是脚本不行）

你这次的输出里有三行是关键证据：

```
helper  : credential.helper = !"E:/hermes/git/mingw64/bin/git-credential-manager.exe"
          credential.credentialStore = dpapi
silent credential probe : NOT AVAILABLE
push --dry-run : FAILED     fatal: Cannot prompt because user interactivity has been disabled.
```

* `git ls-remote : PASSED` **是假象**：这个仓库是公开的，匿名也能读——所以它证明不了鉴权
  （v2.6.0 起 `auth.ps1` 会明确标注这一点，只有 `push --dry-run` 才算数）。
* 写入类操作（push）必须带凭据，而 GCM 在 dpapi 和 wincredman **两个库里都没有**可用的东西，
  它只能"问用户"→ prompts 关掉后就变成 `Cannot prompt ...` 失败。
* 也就是说：你之前每次 push 都要点一下，正是因为**凭据从来没存住过**。
  现在改一次配置就能存住：`gh auth setup-git` 把令牌放进 gh 自己的配置文件（`~/.config/gh/hosts.yml`），
  任何会话（包括计划任务/session 0）都能直接读，不需要 Credential Manager，也不会过期弹窗。

> 另外注意：你的 `credential.interactive = false` 是机器级设置（不是我的脚本写的）。
> 它会让**手动** push 也不再弹窗，所以 `.\push.ps1 -Prompt` 现在会显式覆盖它
> （v2.6.0 已修）；`.\auth.ps1 -Unset` 可以把这类键清掉。

---

## 三、值守：从"每 2 分钟闪一次"到"每次登录闪一次 / 或零闪"

失败信息是 `== self-test FAILED: no heartbeat - this launcher does not work here.`，
脚本按设计自动回退到 `-Flash`（旧模式）并**如实报告**。v2.6.0 针对这件事做了三处改动：

| 改动 | 作用 |
|---|---|
| **常驻循环**（`watch.ps1 -Loop`，注册的任务就是它） | 一个进程每 2 分钟自己轮询到底：flash 模式下**只在登录时闪一次**，而不是每轮一次；零窗口模式下依然是 0 |
| **启动器冒烟测试**（用一个临时小脚本试跑） | 把"启动器本身能不能跑"和"计划任务会不会启动它"分开验证；失败时**直接打印任务结果 + host 日志尾部**，不再让人猜 |
| **keeper 心跳触发器**（每 30 分钟一次，IgnoreNew） | 常驻进程万一死了，下一次 keeper 跳动会重新拉起来；存活时它什么都不做（不多开窗口） |

**想要真正零窗口**（两条路）：

```powershell
# A) 让启动器工作：把这张日志发我，我来定位
Get-Content "$env:LOCALAPPDATA\git-sync\watch-git-pull-arena.log" -Tail 30

# B) 用 session 0（S4U）：需要"以管理员身份运行"的 PowerShell 注册一次
.\watch.ps1 -Unregister ; .\watch.ps1 -Register -Headless
#    注意：S4U 下 GCM 的 dpapi/wincredman 都可能读不到，所以必须先做第一节的
#    gh 登录（gh 把令牌放在自己的配置文件里，session 0 可读）——顺序别反
```

**升级技能后请重注册**：常驻循环用的是启动时的代码，`.\watch.ps1 -Unregister ; .\watch.ps1 -Register`
才会用上新版本（v2.6.0 起 `-Register` 会先停掉旧实例，不会再留一个旧代码的循环在跑）。

---

## 四、验收

* 免点击：`.\auth.ps1 -Verify` → 退出码 0（`ls-remote` + `push --dry-run` 都 PASSED）。
* 零/少弹窗：`.\watch.ps1 -Status` → `mode:` 显示 `zero-window loop (launcher exe)`（零闪）
  或 `loop (one flash per logon)`（每次登录一次）；`loop alive: yes (pid ...)`、
  heartbeat 时间每 2 分钟推进。`-Test` 在循环活着时立刻返回 OK。

**round 9 已排好**：你做完第一节后，值守第一次轮询就会跑这一轮（检查项 2a=免点击推送实跑、
2b=零窗口启动器），并**免点击**把结论推回。我这边读结果即可继续。

---

## 五、回退（如果这条链你不想再折腾）

你说了"实在不行就退回之前的"——两条干净的回退都保留着：

```powershell
# A) 回到"每次轮询闪一下"的旧模式（v2.4.6 行为；功能完整，只是有窗口）
.\watch.ps1 -Unregister ; .\watch.ps1 -Register -Flash
$env:GIT_SYNC_PROMPT='1'; .\push.ps1 "msg"      # 需要交互时的一次性开关

# B) 彻底不用值守：不注册计划任务，需要时手动跑一轮
.\watch.ps1              # 手动处理当前请求（前台执行，看得见输出）
.\auth.ps1 -Unset        # 把 -Setup 改过的 git 配置清掉（凭据本身不动）
```

技能总部（本仓库）与三条 AgentArena 分支都不受影响；v2.4.7 的旧分支
`arena/01a09fc1-git-pull-arena` 也还在远端，随时可以切回去。
