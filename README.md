# git-pull-arena —— 本机 ↔ Arena 会话分支 双向同步

这个仓库验证一条完整链路：**Arena 会话分支（GitHub 远端）⇄ 你的 Windows 本机**。
同步工具就是 [zhongqi 仓库 arena 分支](https://github.com/mqgg5630-cyber/zhongqi/tree/arena%2F01a09d79-zhongqi) 沉淀的 `skills/git-sync` 技能
（本仓库已升级到 **v2.5.0**：零弹窗值守 + 免点击推送；安装器 `agent-install.sh` 可以把它一条命令装进任何新仓库）。

- **工作分支**：`arena/01a0a4f5-git-pull-arena`（所有脚本只拉/推这个分支；`push.ps1` 直接拒绝 main/master）
- **两条硬要求（v2.5.0 起是默认行为）**：① 值守**零弹窗**（默认编译 GUI 子系统启动器，Task Scheduler 不再闪黑窗）；② 推送**免点击**（`auth.ps1` 一次配好，`push.ps1` 默认静默模式，拿不到凭据快速失败并告诉你怎么修）
- **只用单会话闭环**：多会话并行/汇总会话（模式 B/C）**暂时搁置**（2026-09-15 决定）；本仓库就是"一会话一仓库"的样板
- **连接台账**：所有已连接仓库 × 分支 × 本机路径 × 值守任务，见 [`CONNECTIONS.md`](CONNECTIONS.md)（防忘专用，忘了一条命令就能翻到）
- **助手侧**：每轮用 `skills/git-sync/scripts/agent-sync.sh` 提交推送——提交前自动跑 `code/check_all.sh` 自检（.ps1 全 ASCII + 配置分支守卫 + 根目录/skill 脚本一致性），提交后把**同步回执**写进 `results/sync/last_sync.md`
- **双向测试**：已于 2026-09-14 通过（见 `deliverable/SYNC_TEST.md`）；v2.5.0 的升级与验收清单见 [`deliverable/UPGRADE_v2.5.0.md`](deliverable/UPGRADE_v2.5.0.md)
- **本机要做的（一次）**：切到新分支 + 重配凭据 + 重注册值守 —— 5 条命令，见 `CONNECTIONS.md` 第"二·五"节

## 一、本机首次安装（Windows PowerShell，只做一次）

前置：本机装好 Git —— `git --version` 能出版本号；没有就到 <https://git-scm.com/download/win> 下载安装（一路默认即可）。

```powershell
# 1) 允许运行本地脚本（只做一次）
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# 2) 克隆工作分支（子文件夹布局：E:\0github\git-sync\git-pull-arena）
cd E:\0github\git-sync
git clone -b arena/01a0a4f5-git-pull-arena https://github.com/mqgg5630-cyber/git-pull-arena.git
cd git-pull-arena

# 3) 首次准备：git 身份 / 切分支 / 首次拉取（之后就不用再跑）
#    -Auto = 顺带把"免点击推送 + 值守"也配好，等价于下面 4、5 两步
.\bootstrap.ps1 -Auto

# 4) 凭据：让推送不再需要点确认（配好当场实跑证明；不弹任何窗口）
.\auth.ps1 -Setup -Verify

# 5) 值守：注册自动验证（零窗口；注册后会自检"真的跑了一次"）
.\watch.ps1 -Register

# 6) 体检：branch 应显示 arena/01a0a4f5-git-pull-arena，ahead/behind = 0/0，
#    末尾应看到 watcher / heartbeat / auth 三行都是好消息
.\doctor.ps1
```

> 为什么推荐 `auth.ps1`：GitHub 早就只认令牌不认密码，默认的凭据管理器（Windows 凭据管理器）
> 每次都要弹窗或点确认，值守任务在后台根本点不了。`auth.ps1 -Setup` 会优先用 GitHub CLI
> （`gh auth setup-git`，令牌存在 gh 自己的配置里），没有 gh 就配 GCM + `credentialStore=dpapi`
> （Windows 凭据管理器在 session 0/SSH 下读不到，dpapi 文件可以）；`-Verify` 会在**关闭一切交互提示**
> 的前提下实跑 `git ls-remote` 和 `git push --dry-run`，退出码 0 才算配好。

## 二、日常命令（在仓库目录里）

```powershell
.\sync.ps1                                 # 取：拉最新（本地有改动会先自动 stash）
.\push.ps1 "test: 本机改动"                  # 传：pull --ff-only 对齐 → add → commit → push

.\download.ps1 -Set final                  # 把 deliverable\ 镜像到 ..\git-pull-arena_out\
.\download.ps1 -Set final -Since 2026-09-14    # 只复制该日期后变过的文件
.\download.ps1 -Folders examples\x         # 临时指定目录下载（不用改配置）
.\download.ps1 -List                       # 看有哪些集合（final / skill / all）
.\auth.ps1                                 # 凭据体检：现在推送能不能不弹窗、不点确认
.\auth.ps1 -Setup -Verify                  # 配 + 证明（每台机器/换令牌后各一次）
.\watch.ps1 -Status                        # 值守活着吗：模式 / 上次运行 / 心跳 / 最近一轮结论
.\watch.ps1 -Test                          # 立刻跑一次值守任务，验证"真的会跑"
.\pack.ps1   -Set final                    # 或打成 _export\<日期>_final.zip（不进 git）

.\doctor.ps1                               # 体检；不对劲先跑它
.\doctor.ps1 -Fix                          # 一键修复：refspec + stash + 切回分支 + 拉取
.\hardware.ps1 -Deep                       # 采集本机硬件/conda环境报告并推送（每台机器一次；GPU/环境变了重跑）
.\watch.ps1 -Register                      # 自动验证循环：注册本机值守（每2分钟轮询；-Unregister 摘除）
.\pr.ps1                                   # 开 PR 到 main（需 GitHub CLI：winget install GitHub.cli）
```

每轮助手提交后，`.\sync.ps1` 再打开 `results\sync\last_sync.md` 就能看到这轮的**同步回执**。

值守的三种启动方式（v2.5.0）：

```powershell
.\watch.ps1 -Register               # 默认：零窗口（编译启动器）+ 注册后自检
.\watch.ps1 -Register -Flash        # 回退：隐藏窗口的 powershell（每轮闪一下）
.\watch.ps1 -Register -Headless     # 零窗口的另一种：S4U/session 0（需管理员控制台）
.\watch.ps1 -Register -Interval 10  # 降频到 10 分钟
```

可选——启用远端 CI（沙箱 agent 令牌没有 workflows 权限，从你本机启用一次即可）：

```powershell
New-Item -ItemType Directory -Force .github\workflows | Out-Null
Copy-Item skills\git-sync\templates\gate.yml .github\workflows\gate.yml
.\push.ps1 "ci: enable gate workflow"
```

## 三、验收清单（单会话闭环；多会话模式已搁置）

| # | 方向 | 怎么算通过 | 状态 |
|---|------|------------|------|
| 1 | 助手 → 本机 | `.\sync.ps1` 后本地出现 `deliverable\SYNC_TEST.md` | ✅ 2026-09-14 |
| 2 | 本机 → 助手 | 在 `SYNC_TEST.md` 加一句话 → `.\push.ps1`，助手在远端拉到并确认 | ✅ 2026-09-14 |
| 3 | 交付物落地 | `.\download.ps1 -Set final`（在 zhongqi 仓库验证） | ✅ 2026-09-14 |
| 4 | 自动验证循环（单会话） | `agent-wait.sh --request "..." --auto-accept` 一轮内 exit 0；handshake `local_state=passed`、`arena_state=accepted` | ✅ 2026-09-15（round 6） |
| 5 | **零弹窗值守**（v2.5.0） | `.\watch.ps1 -Register` 自检通过后，值守每 2 分钟轮询**看不到任何窗口**；`.\watch.ps1 -Status` 的 heartbeat 时间在推进 | ⏳ 已排入 round 7（检查项 2b），本机升级后自动判定 |
| 6 | **免点击推送**（v2.5.0） | `auth.ps1 -Verify` exit 0；值守轮询里 `last_push=ok`，全程没有人点过任何东西 | ⏳ 已排入 round 7（检查项 2a），本机升级后自动判定 |

> 多会话协作（同仓库多分支 / 汇总会话）实测成本高于收益，**暂时不做**；
> 需要时按 `skills\git-sync\README.md` 第七节重启。

## 四、装到别的项目（技能复用）

**新的 Arena 会话**里说一句话即可：

> 参考 https://github.com/mqgg5630-cyber/git-pull-arena 的 skills/git-sync，用 agent-install.sh 装到本仓库当前分支。

（完整的复制粘贴版提示词在 `skills\git-sync\templates\new-session-prompt.md`，含本机步骤与双向验收清单。）

Agent 执行的命令（raw.githubusercontent.com 在沙箱可能被墙，git clone 稳定可用）：

```bash
git clone --quiet --depth 1 -b arena/01a0a4f5-git-pull-arena \
     https://github.com/mqgg5630-cyber/git-pull-arena.git /tmp/git-sync-src \
  && bash /tmp/git-sync-src/skills/git-sync/scripts/agent-install.sh --branch <工作分支>
```

（本技能合并进 main 后，把 `-b` 换成 `main`，链接就是永久稳定的。）

**本机侧**装/升级（保留目标仓库已有配置，只动分支）：

```powershell
.\skills\git-sync\scripts\install.ps1 -Target C:\MyProject -Branch arena/xxx
```

详细说明：`skills\git-sync\README.md`（使用手册）、`skills\git-sync\SKILL.md`（技能规范）。
