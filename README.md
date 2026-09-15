# git-pull-arena —— 本机 ↔ Arena 会话分支 双向同步

这个仓库验证一条完整链路：**Arena 会话分支（GitHub 远端）⇄ 你的 Windows 本机**。
同步工具就是 [zhongqi 仓库 arena 分支](https://github.com/mqgg5630-cyber/zhongqi/tree/arena%2F01a09d79-zhongqi) 沉淀的 `skills/git-sync` 技能
（本仓库已升级到 v2，安装器 `agent-install.sh` 可以把它一条命令装进任何新仓库）。

- **工作分支**：`arena/01a09fc1-git-pull-arena`（所有脚本只拉/推这个分支；`push.ps1` 直接拒绝 main/master）
- **助手侧**：每轮用 `skills/git-sync/scripts/agent-sync.sh` 提交推送——提交前自动跑 `code/check_all.sh` 自检（.ps1 全 ASCII + 配置分支守卫 + 根目录/skill 脚本一致性），提交后把**同步回执**写进 `results/sync/last_sync.md`
- **双向测试**：已于 2026-09-14 通过（见 `deliverable/SYNC_TEST.md`）

## 一、本机首次安装（Windows PowerShell，只做一次）

前置：本机装好 Git —— `git --version` 能出版本号；没有就到 <https://git-scm.com/download/win> 下载安装（一路默认即可）。

```powershell
# 1) 允许运行本地脚本（只做一次）
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# 2) 克隆工作分支（子文件夹布局：E:\0github\git-sync\git-pull-arena）
cd E:\0github\git-sync
git clone -b arena/01a09fc1-git-pull-arena https://github.com/mqgg5630-cyber/git-pull-arena.git
cd git-pull-arena

# 3) 首次准备：git 身份 / 切分支 / 首次拉取（之后就不用再跑）
.\bootstrap.ps1

# 4) 体检：branch 应显示 arena/01a09fc1-git-pull-arena，ahead/behind = 0/0
.\doctor.ps1
```

> 第一次 `git push` 时 GitHub 不收账号密码：Git for Windows 自带的凭据管理器会弹浏览器让你登录授权一次，之后自动记住。

## 二、日常命令（在仓库目录里）

```powershell
.\sync.ps1                                 # 取：拉最新（本地有改动会先自动 stash）
.\push.ps1 "test: 本机改动"                  # 传：pull --ff-only 对齐 → add → commit → push

.\download.ps1 -Set final                  # 把 deliverable\ 镜像到 ..\git-pull-arena_out\
.\download.ps1 -Set final -Since 2026-09-14    # 只复制该日期后变过的文件
.\download.ps1 -Folders examples\x         # 临时指定目录下载（不用改配置）
.\download.ps1 -List                       # 看有哪些集合（final / skill / all）
.\pack.ps1   -Set final                    # 或打成 _export\<日期>_final.zip（不进 git）

.\doctor.ps1                               # 体检；不对劲先跑它
.\doctor.ps1 -Fix                          # 一键修复：refspec + stash + 切回分支 + 拉取
.\hardware.ps1 -Deep                       # 采集本机硬件/conda环境报告并推送（每台机器一次；GPU/环境变了重跑）
.\pr.ps1                                   # 开 PR 到 main（需 GitHub CLI：winget install GitHub.cli）
```

每轮助手提交后，`.\sync.ps1` 再打开 `results\sync\last_sync.md` 就能看到这轮的**同步回执**。

可选——启用远端 CI（沙箱 agent 令牌没有 workflows 权限，从你本机启用一次即可）：

```powershell
New-Item -ItemType Directory -Force .github\workflows | Out-Null
Copy-Item skills\git-sync\templates\gate.yml .github\workflows\gate.yml
.\push.ps1 "ci: enable gate workflow"
```

## 三、本次打通测试清单（已全部通过）

| # | 方向 | 怎么算通过 |
|---|------|------------|
| 1 | 助手 → 本机 | `.\sync.ps1` 后本地出现 `deliverable\SYNC_TEST.md` ✅ |
| 2 | 本机 → 助手 | 在 `SYNC_TEST.md` 加一句话 → `.\push.ps1`；助手在远端拉到并确认 ✅ |
| 3 | 交付物落地 | `.\download.ps1 -Set final`（在 zhongqi 仓库验证）✅ |

## 四、装到别的项目（技能复用）

**新的 Arena 会话**里说一句话即可：

> 参考 https://github.com/mqgg5630-cyber/git-pull-arena 的 skills/git-sync，用 agent-install.sh 装到本仓库当前分支。

（完整的复制粘贴版提示词在 `skills\git-sync\templates\new-session-prompt.md`，含本机步骤与双向验收清单。）

Agent 执行的命令（raw.githubusercontent.com 在沙箱可能被墙，git clone 稳定可用）：

```bash
git clone --quiet --depth 1 -b arena/01a09fc1-git-pull-arena \
     https://github.com/mqgg5630-cyber/git-pull-arena.git /tmp/git-sync-src \
  && bash /tmp/git-sync-src/skills/git-sync/scripts/agent-install.sh --branch <工作分支>
```

（本技能合并进 main 后，把 `-b` 换成 `main`，链接就是永久稳定的。）

**本机侧**装/升级（保留目标仓库已有配置，只动分支）：

```powershell
.\skills\git-sync\scripts\install.ps1 -Target C:\MyProject -Branch arena/xxx
```

详细说明：`skills\git-sync\README.md`（使用手册）、`skills\git-sync\SKILL.md`（技能规范）。
