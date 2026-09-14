# git-pull-arena —— 本机 ↔ Arena 会话分支 双向同步测试

这个仓库用来验证一条完整链路：**Arena 会话分支（GitHub 远端）⇄ 你的 Windows 本机**。
同步工具就是 [zhongqi 仓库 arena 分支](https://github.com/mqgg5630-cyber/zhongqi/tree/arena%2F01a09d79-zhongqi) 的 `skills/git-sync` 技能，
已原样安装到本仓库：**日常脚本在仓库根目录**，完整技能（说明书 + 助手侧脚本 + 安装器）在 `skills\git-sync\`。

- **工作分支**：`arena/01a09fc1-git-pull-arena`（所有脚本只拉/推这个分支；`push.ps1` 直接拒绝 main/master）
- **助手侧**：每轮用 `skills/git-sync/scripts/agent-sync.sh` 提交推送，提交前自动跑 `code/check_all.sh` 自检（.ps1 全 ASCII + 配置分支守卫）

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

## 二、日常就两条命令（在仓库目录里）

```powershell
.\sync.ps1                      # 取：拉取助手推上来的最新提交（本地有改动会先自动 stash）
.\push.ps1 "test: 本机改动"       # 传：pull --ff-only 对齐 → add → commit → push
```

交付物落地（可选）：

```powershell
.\download.ps1 -Set final       # 把 deliverable\ 镜像到 ..\git-pull-arena_out\
.\download.ps1 -List            # 看有哪些集合（final / skill / all）
.\pack.ps1   -Set final         # 或打成 _export\<日期>_final.zip（不进 git）
```

任何"不对劲"先跑 `.\doctor.ps1`，把完整输出贴给助手；故障对照表见 `skills\git-sync\README.md` 第五节。

## 三、本次打通测试清单

| # | 方向 | 谁做 | 怎么算通过 |
|---|------|------|------------|
| 1 | 助手 → 本机 | 你 | `.\sync.ps1` 后本地出现 `deliverable\SYNC_TEST.md` |
| 2 | 本机 → 助手 | 你 | 在 `SYNC_TEST.md` 末尾加一句话 → `.\push.ps1 "test: local -> arena branch"`；助手在远端拉到并确认 |
| 3 | 交付物落地 | 你 | `.\download.ps1 -Set final` 后 `..\git-pull-arena_out\deliverable\` 里有文件 |

## 四、装到别的项目

这套技能是通用的，`skills\git-sync\scripts\install.ps1` 可以把它装进任何仓库：

```powershell
.\skills\git-sync\scripts\install.ps1 -Target C:\MyProject -Branch main
```

装完只需编辑目标仓库的 `sync.config.json`（分支 / 下载集合 / 归位规则），脚本一行都不用动。
