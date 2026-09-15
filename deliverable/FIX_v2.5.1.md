# v2.5.1 —— 修复你实测撞到的两个 bug（照做即可）

> 你这次贴回来的输出暴露了**两个真 bug**，都已修复（技能 v2.5.1，同一分支）。
> 下面第一段是"立刻照做"，第二段是"到底错在哪"，第三段是"验收"。

---

## 一、立刻照做（复制粘贴，5 条）

```powershell
cd E:\0github\git-sync\git-pull-arena

.\sync.ps1                       # 取到 v2.5.1 的脚本

.\auth.ps1 -Setup -Verify        # 1) 凭据：这一次会"先探测、只在必要时才改配置"
                                #    它会先发现你原来的凭据在 Windows 凭据管理器里，
                                #    并把 v2.5.0 误设的 dpapi 覆盖项撤掉

.\watch.ps1 -Unregister          # 2) 值守：旧任务留着但已 Disabled，删掉重来
.\watch.ps1 -Register            #    默认零窗口 + 注册后自检（真的跑一次并等心跳）

.\doctor.ps1                     # 3) 看最后四行：sync / watcher / heartbeat / auth
```

**如果 `auth.ps1 -Verify` 仍显示 `NOT READY`**（有可能：你原来的凭据可能压根没存住，
或者 GCM 拒绝用它），就做**一次**登录，之后永久免点击——三选一：

```powershell
gh auth login                                  # 最优（gh 已装 2.97.0）：设备码/浏览器一次
.\auth.ps1 -Setup -PromptToken                  # 或用 PAT：输入隐藏，不落盘
.\auth.ps1 -Setup -TokenFile C:\pat.txt          # 或从文件读（文件别放进仓库）
.\push.ps1 -Prompt "msg"                        # 让登录窗出现一次（最土但有效）
```

做完任意一条后：

```powershell
.\auth.ps1 -Verify              # 必须 exit 0：prompts 全关下 ls-remote + push --dry-run 都通过
```

---

## 二、两个 bug 到底是什么

### bug 1：`watch.ps1` 整个文件被 PowerShell 拒绝解析（所以值守一直没跑）

错误信息里的关键字是 `InvalidVariableReferenceWithDrive`，位置在
`Add-Log "round $round: ..."` 这类行：`$round:` 被 PowerShell 当成**盘符变量名**
（像 `$env:`、`$script:` 那样），解析阶段就报 ParserError。

**为什么整份脚本都不工作**：PowerShell 是**先解析整个文件、再执行**——文件里只要有一处这种
写法，`watch.ps1` 的任何子命令（包括 `-Register`）都不会执行，只在解析阶段丢出错误。
所以你的 `-Register` 从来没成功过；旧任务显示 `Disabled` + `last run 15:11:50` 是更早的老任务。

**修复**：改成 `${round}:`（5 处），并且**写进 gate**：`code/scan_ps_var_colon.py` 会扫描
所有 `.ps1`，发现 `$变量名:` 直接让提交失败（这次的教训必须变成机制，而不是"下次注意"）。

### bug 2：`auth.ps1 -Setup` 在"本来能用的凭据"上乱改配置（把登录搞失效了）

你的输出里最关键的两行：

```
credential.helper already set: !"E:/hermes/git/mingw64/bin/git-credential-manager.exe" (kept)
[ok] credential.credentialStore = dpapi (...)
...
push --dry-run : FAILED / silent credential probe : NOT AVAILABLE
```

v2.5.0 的 `-Setup` **无条件**把 `credential.credentialStore` 设成 `dpapi`。而
Git Credential Manager 的默认存储是 **Windows 凭据管理器（wincredman）**——你原来的凭据就在那里。
把 store 改成 dpapi 等于**换了一个空仓库**，于是：

* 之前能用的凭据"消失"了 → 推送开始要求登录/点击；
* 我还在自检里跑了 `-Verify`，于是当场就把 `push --dry-run` 判成 FAILED。

**修复（v2.5.1 起改为"先探测，只在必要时动手"）**：

1. 先用**当前配置**探测（prompts 全关）——能拿到凭据就**什么都不改**；
2. 需要改时，先逐个 store 试：**dpapi → wincredman**，哪个里有凭据就用哪个；
3. 若命中的是 wincredman，就把 `credential.credentialStore` **撤掉**（回到 GCM 默认），
   而不是把它指到别处（"unset = 用默认" 比 "写上默认值" 更不容易撞兼容性差异）；
4. 只有在需要 session 0（`watch.ps1 -Register -Headless`）时，才会**拷贝**一份到 dpapi：
   `.\auth.ps1 -MigrateStore`（原凭据保留，不是搬家而是复制）；
5. `doctor.ps1` 不再在你没取到远端分支时报 `NOT ready`（那次只是噪声），且只跑一次探测。

还有一个附带的坑也一起修了：PS 5.1 会把**子进程 stderr** 当成错误对象，即使重定向了
`2>&1` 也会在调用处用红字打出来（你输出里那两行 `+| ... core.askpass= ...use user
interactivity has been disabled` 就是它）。v2.5.1 起所有外部命令都通过
`cmd /c "... 2>&1"` 走，输出干净、退出码可靠。

### 顺手加的几道闸（都是"静默失败"类问题）

* `watch.ps1 -Register` 现在**预检环境**：git / bash / powershell 的真实路径会打印出来，
  并记进心跳（你的 git 是 `E:\hermes\git\...` 这种自定义安装，计划任务的 PATH 不一定有它，
  早发现早好）；缺 git 直接拒绝注册，缺 bash 会警告（gate 需要它）。
* `local_check.ps1` 不再允许 gate "空转通过"：bash 不在 PATH、或 gate 没有任何输出，
  一律判 FAIL（而不是沿用上一次的退出码）。
* `push.ps1` 的认证失败识别补齐了 GCM 的真实措辞（`Cannot prompt because user
  interactivity has been disabled.` 这类），遇到就 exit 4 + 打印一次性登录的三种做法，
  而不是当成"网络/分支问题"重试。
* gate 的解释器按 `python3` → `python` 回退（Windows/conda 常常只有 `python`），
  免得整条自检因为"没有 python3"而失败或空跑。

---

## 三、验收（两条硬要求，各一条命令）

| 要求 | 命令 | 通过标准 |
|---|---|---|
| 免点击推送 | `.\auth.ps1 -Verify` | 退出码 0；`ls-remote` 与 `push --dry-run` 都 PASSED |
| 零弹窗值守 | `.\watch.ps1 -Register` 后的自检 + `.\watch.ps1 -Status` | 自检 `PASSED`；`mode` = `zero-window (launcher exe)`；heartbeat 的 `last_run` 每 2 分钟推进，屏幕上无任何窗口 |

**round 8 已经排好**：我这边发了一轮验收请求（含"2a 免点击推送 / 2b 零窗口启动器"两项断言）。
你按第一节做完后，值守第一次轮询（≤2 分钟）就会**零窗口**跑完这一轮、**免点击**把结论推回来；
我 `--read` 就能拿到 passed/failed，失败项会直接在日志里指出是 2a 还是 2b。

> 如果推进受阻：`.\watch.ps1 -Status` + `.\doctor.ps1` + `%LOCALAPPDATA%\git-sync\watch-*.log`
> 三处一并发我，就能定位；`-Flash` 是保底可用的旧模式（只是每轮闪一下）。

---

## 四、我这边沙箱里能证明什么

| 项 | 状态 |
|---|---|
| 全仓 `.ps1`：ASCII、括号配平、**无 `$var:` 盘符陷阱**、根目录副本一致 | ✅ gate 每次提交自动跑 |
| `watch.ps1` 解析（这次 bug 的类别） | ⚠️ 沙箱没有 PowerShell；但 gate 在有 powershell/pwsh 的机器上会**用 PowerShell 自己的解析器**逐文件解析（你机器上跑 `.\doctor.ps1` 或 `.`+`push.ps1 -Gate` 时就会执行这步） |
| `auth.ps1` 的探测/迁移逻辑 | ✅ 代码走查 + 状态机分支全覆盖（本次按你的实际输出逐行走查） |
| 启动器编译、无窗、dpapi 实跑 | ⚠️ 只能在你机器上验证：所以设计成"注册自检 + 实跑验证 + 失败回退 + 如实报告" |
