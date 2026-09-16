# v2.6.1 —— 原因是"网络路径"，不是脚本

> 你这次把最后一块拼图给出来了：
> ```
> gh auth login
> failed to authenticate via web browser: Post "https://github.com/login/device/code":
>   dial tcp 140.82.112.4:443: connectex: ... did not properly respond after a period of time
> ```
> 这是**连不上 github.com:443**（超时），不是 gh 坏了、也不是脚本的问题。
> 而同一台机器上 `git fetch / ls-remote` 又能成功 —— 说明 **git 走的是代理，gh 没走**。
> 这是最常见的"半通"状态：git 的代理写在 `git config http.proxy`，而 gh（和其它工具）
> 只认环境变量 `HTTPS_PROXY` / `HTTP_PROXY`。

---

## 一、先确认这一点（3 条命令）

```powershell
git config --global --get http.proxy        # git 用的代理（可能来自系统/软件设置）
git config --global --get https.proxy
echo $env:HTTPS_PROXY                        # gh 需要的代理（多半是空的）
```

* **第一条有值、第三条为空** → 结论就是"git 能通、gh 不通"。按下面第二节做，一次就通。
* 两条都为空、且 `gh auth login` 一直超时 → 这台机器到 GitHub 的直连被阻断/极不稳定，
  需要先解决网络（代理/VPN/换网络），再回到这里。

顺便：`git ls-remote` 能过**不代表鉴权没问题**——这仓库是公开的，匿名也能读；
真正需要凭据的是 push。

---

## 二、让 gh 也走 git 的代理（v2.6.1 已内置自动检测）

```powershell
cd E:\0github\git-sync\git-pull-arena
.\sync.ps1                                     # 取 v2.6.1

# A) 自动：auth.ps1 会读取 git config 的 http.proxy 并套用给 gh
.\auth.ps1 -GhLogin -Verify

# B) 手动指定（不知道 git 用了哪个代理时，填你本机代理端口，常见 7890/1080/10809）
.\auth.ps1 -GhLogin -HttpProxy http://127.0.0.1:7890 -Verify

# C) 让这台机器长期生效（所有工具都能用；开了新窗口后再跑 A）
setx HTTPS_PROXY  http://127.0.0.1:7890
setx HTTP_PROXY   http://127.0.0.1:7890
```

## 三、不想折腾 gh：PAT 离线入库（**设置时不联网**，v2.6.1 已改为离线优先）

```powershell
.\auth.ps1 -Setup -PromptToken -Verify      # 粘贴 PAT，输入隐藏
#    或：.\auth.ps1 -Setup -TokenFile C:\pat.txt
```
v2.6.1 起这条路**先写入凭据助手（不需要任何 GitHub API 调用）**，所以即使 github.com
连不上也能把凭据存好；等你网络通畅时 push 就直接用它。
PAT 需要 `repo` 权限（fine-grained 的话：Contents 读写）。

---

## 四、顺手修掉你日志里的两个"次生灾害"

### 1. 6 条 stash 是怎么来的（已修）

v2.5.x 的 `sync.ps1` 只要看到工作区有改动就**无条件 stash**。值守写的
`results/status/handshake.json` 和 `check_rN_*.txt` 在推送失败时会留在工作区，
于是**每 sync 一次就多一条 stash**，越积越多（你那里 6 条）。

v2.6.1 起：如果脏文件**只**在 `results/status/`（值守产物，每轮都会重写），就
**本地提交**而不是 stash；并且当分支因为"推送失败留下的 verdict 提交"而与远端分叉时，
`sync.ps1` 会自动对齐远端（文件保留，verdict 本来就是可再生的）。

清理历史包袱（确认里面没有你要的东西再删）：

```powershell
git stash list                       # 看一眼
git stash show --stat stash@{0}      # 检查内容（多半是 results/status/*）
# 确认是值守产物后，全部丢弃：
git stash list | ForEach-Object { git stash drop }     # 或 git stash clear
```

### 2. "push failed (exit 3)" 看不出原因（已修）

v2.6.1 起值守会把 push 的**输出尾部**记进心跳：`last_push_detail`，
`.\watch.ps1 -Status` 和 `.\doctor.ps1` 都能直接看到是认证问题、网络问题还是分支问题。
`-Register` 时还会把 git 的代理设置一并记录，并且当"git 有代理但 `HTTPS_PROXY` 没设"时**主动提醒**。

---

## 五、做完这些，再按顺序验证

```powershell
.\sync.ps1                                  # 取 v2.6.1
.\auth.ps1 -Setup -Verify                   # 应 exit 0：ls-remote + push --dry-run 全过
.\watch.ps1 -Unregister ; .\watch.ps1 -Register
.\doctor.ps1                                # watcher / heartbeat / auth / proxy
```

* `auth.ps1 -Verify` 通过 = **推送不再需要人点**（这是 2a）。
* `watch.ps1 -Register` 会先对零窗口启动器做冒烟测试：通过就是 `zero-window loop (launcher exe)`（零闪）；
  不通过会回退 `loop (one flash per logon)`（每次登录闪一次）——两种情况都比原来的"每 2 分钟闪一次"好得多（2b）。
  想要零闪且启动器就是不工作：管理员窗口里 `.\watch.ps1 -Register -Headless`（前提是已登录，见第二节）。

**round 10 已排好**，你做完上面命令后值守第一次轮询就会跑这一轮并推回结论。

> 如果网络这条路暂时走不通（GitHub 直连被阻断、也没有代理），最现实的做法是：
> **先按第四节清理 stash，然后把值守摘掉**（`.\watch.ps1 -Unregister`），
> 需要时手动 `.\watch.ps1` 跑一轮，等工作在你自己控制下完成——
> 双机同步（`.\sync.ps1` / `.\push.ps1`）不受影响，只是"自动验证"那一步要手动触发。
