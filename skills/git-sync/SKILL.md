---
name: git-local-arena-sync
description: 本机（Windows PowerShell）与远端 Agent 之间的双向文件同步技能：拉取、上传、下载交付物（含按日期增量与临时指定目录）、打包提交、体检与自动修复（doctor -Fix）、开 PR、本机硬件与 conda/mamba 环境自动上报（hardware.ps1 / agent-hardware.sh），以及助手侧的"提交+推送+同步回执（按日期归档）"与沙箱 .git 被重置后的历史恢复；自带新会话引导提示词模板，一条命令装进任何新仓库。Use when a user needs repeatable pull / upload / download / pack / fix helpers for a repo shared with an AI agent, when the agent must know the local hardware (GPU/CPU/RAM/conda envs) before compute-heavy work, when .ps1 files must stay ASCII-only (Windows PowerShell 5.1 GBK decoding), when a stray push to main must be blocked, when the skill must be installed into a brand-new repo or agent session with one command (agent-install.sh + templates/new-session-prompt.md), or when the sandbox repository silently resets to its baseline commit and the worktree must be kept.
---

# 本地 ↔ Agent 双向同步（skill）

一个仓库、两条链路：**你在本机按一个命令，Agent 在远端按一个命令**，中间只有 git。
所有脚本都是幂等的、配置驱动的，`agent-install.sh` 一条命令就能装进任何新仓库。

## 0. 一句话流程

```
本机                                          远端（Agent 沙箱 / Arena）
  .\sync.ps1            <---- push ----       agent-sync.sh "feat: ..."   （守卫→自检→回执→提交推送）
  .\upload.ps1          ---- pull ---->       （附件按扩展名归位 -> sources/ code/ results/）
  .\download.ps1        <---- pull ----       （把 deliverable/ 等镜像到本机；-Since 只取增量）
  .\push.ps1 "msg"      ---- push ---->       （你侧提交；两轮 agent-sync 都会把"纳入了哪些提交"写进回执）
  .\hardware.ps1        ---- push ---->       （本机硬件/环境报告；agent 开工前用 agent-hardware.sh 读）
  .\pr.ps1              ---- PR ----->        main（agent-pr.sh 同款；GitHub Actions 会跑 gate）
  .\doctor.ps1 (-Fix)   体检 / 一键修复
```

## 1. 脚本清单

### 本机侧（仓库根目录，PowerShell）

| 脚本 | 作用 | 典型用法 |
|---|---|---|
| `sync.ps1` | fetch + 切分支 + `pull --ff-only`；本地有改动先自动 stash | `.\sync.ps1` |
| `upload.ps1` | 附件按 `upload_map` 归位到 `sources/ code/ results/`，再调用 `push.ps1` | `.\upload.ps1 -Src "E:\附件"` |
| `push.ps1` | `pull --ff-only` → `add -A` → commit → push；**拒绝推 main/master**；`-Gate` 提交前本机也跑一遍自检 | `.\push.ps1 -Gate "add files"` |
| `download.ps1` | 按 `download_sets` 用 robocopy 镜像到本机；**`-Since` 只复制某日期后变过的文件**；**`-Folders a,b` 临时指定目录** | `.\download.ps1 -Folders deliverable,examples\x` |
| `pack.ps1` | 把某个集合压成一个 zip（默认 `_export\<日期>_<集合>.zip`，不进 git） | `.\pack.ps1 -Set final` |
| `doctor.ps1` | 体检：环境/分支/远端/落后领先/未提交/stash/LFS/大文件/**技能版本**；**`-Fix` 一键修复** | `.\doctor.ps1 -Fix` |
| `bootstrap.ps1` | 首次准备：执行策略、git 身份、fetch、切分支、首拉 | `.\bootstrap.ps1` |
| `hardware.ps1` | **采集本机硬件与环境**（OS/CPU/内存/GPU 显存/磁盘/conda/mamba 环境列表，`-Deep` 探测每个环境的 torch+CUDA）写入 `hardware_dir` 并推送 | `.\hardware.ps1 -Deep` |
| `pr.ps1` | 用 GitHub CLI 开 PR（工作分支 → main），`-Checks` 看 CI | `.\pr.ps1` |
| `install.ps1` | 把整套技能装到另一个仓库（升级时**保留**对方已有配置） | `.\install.ps1 -Target C:\MyProject -Branch arena/xxx` |

### 助手侧（`skills/git-sync/scripts/`，bash）

| 脚本 | 作用 | 典型用法 |
|---|---|---|
| `agent-sync.sh` | 分支守卫 → fetch → 发散自愈 → gate → **写同步回执并按日期归档** → commit + push | `bash skills/git-sync/scripts/agent-sync.sh "feat: ..."` |
| `agent-hardware.sh` | **读取本机硬件报告**（缺失或过期会提醒让用户跑 `hardware.ps1`） | `bash skills/git-sync/scripts/agent-hardware.sh` |
| `agent-recover.sh` | 沙箱 `.git` 被重置回基线提交后，保住工作区恢复历史 | `bash skills/git-sync/scripts/agent-recover.sh` |
| `agent-pr.sh` | 助手侧开 PR / 看 CI（`--dry-run` 只打印） | `bash skills/git-sync/scripts/agent-pr.sh --checks` |
| `agent-install.sh` | **把这套技能一条命令装进任何仓库**（新会话复用的入口） | 见第 7 节 |

### 模板与标识（`skills/git-sync/templates/` 等）

| 文件 | 作用 |
|---|---|
| `check_all.sh` | 通用 gate：.ps1 全 ASCII + 配置分支守卫 + 根目录与 skill 脚本一致性（含 hardware.ps1）；`agent-install.sh` 会装到 `code/check_all.sh` |
| `gate.yml` | GitHub Actions：push 后自动跑 gate（`agent-install.sh --gha` 安装；agent 令牌若没有 workflows 权限，就由本机侧复制后 push） |
| `new-session-prompt.md` | **新会话引导提示词模板**：整段复制到任何新 Arena 对话，一条命令装好本技能，并附本机步骤与双向验收清单 |
| `../VERSION` | 技能版本号；`doctor.ps1` 与安装器会显示，升级对账用 |

## 2. 配置：`sync.config.json`

脚本里**不写中文、不写死分支**；一切可变的都在这个 UTF-8 JSON 里：

```json
{
  "branch": "arena/01a09fc1-git-pull-arena",
  "remote": "origin",
  "download_dir": "",
  "download_sets": { "final": ["deliverable"], "all": ["deliverable", "code", "skills"] },
  "upload_map":    { ".docx": "sources", ".py": "code", ".xlsx": "results" },
  "gate": "bash code/check_all.sh",
  "receipt": "results/sync/last_sync.md",
  "receipt_history": "results/sync/history",
  "hardware_dir": "results/hardware"
}
```

* `download_dir` 留空 → 下载到仓库上一级的 `<仓库名>_out`；
* `receipt` 是助手侧每轮 `agent-sync.sh` 落盘的**同步回执**（留空关闭）；`receipt_history` 是**按日期归档**目录（留空不归档；自动只保留最近 50 份，文件名 `YYYYMMDD-HHMMSS.md`）；
* `hardware_dir` 是**本机硬件报告**目录：`hardware.ps1` 写入 `latest.md`/`latest.json` + `history/<时间戳>.md`（保留 30 份），`agent-hardware.sh` 读取；
* **多环境 profile**：每台机器 `setx GIT_SYNC_PROFILE lab` 一次，脚本就会优先找 `sync.config.lab.json`；单次也可 `-Config <路径>` 指定。查找顺序：`-Config` > profile > `sync.config.json`；
* `gate` 是助手侧提交前运行的检查命令，失败就**不提交**；本机侧想跑同一套检查用 `.\push.ps1 -Gate`。

## 3. 铁律（踩过的坑）

1. **`.ps1` 只用 ASCII**。Windows PowerShell 5.1 读无 BOM 的 `.ps1` 时按 GBK 解码，中文注释会把引号吃掉。中文放在 `.md` 与 `.json` 里（`hardware.ps1` 生成的报告里出现中文系统名是运行时数据，不受影响）。gate 提交前自动扫全部 `.ps1`。
2. **只在自己的工作分支上动**。脚本默认从配置读分支；`push.ps1`/`pr.ps1`/`agent-pr.sh` 直接拒绝 `main`/`master`；`agent-sync.sh` 发现 HEAD 不是配置里的分支就退出。
3. **不要 `git init` 再推同一分支**（历史不一致会被拒），也不要在冲突时 `--force`。
4. **推送前先 `pull --ff-only`**（两个方向的脚本都内建），避免 non-fast-forward。
5. **大文件不进 git**。放 `build/` 之类被 ignore 的目录，或本地 `pack.ps1` 外发；`doctor.ps1` 会列出超过 50 MB 的被跟踪文件提醒上 Git LFS。

## 4. 故障对照表

| 现象 | 处理 |
|---|---|
| `cannot be loaded because running scripts is disabled` | `.\bootstrap.ps1`（内部设 CurrentUser RemoteSigned） |
| 提示输入密码 | GitHub 不接受密码 → `gh auth login` / GitHub Desktop |
| `rejected - non-fast-forward` | 先 `.\sync.ps1` 再推；助手侧 `agent-sync.sh` 会自动对齐远端 |
| `pull --ff-only` 失败 | 本机有分叉提交：`.\doctor.ps1` 看清状态，或直接 `.\doctor.ps1 -Fix` |
| 你的改动进了 stash | `git stash list` → `git stash pop`（`doctor -Fix` 的 stash 也在里面） |
| robocopy 报 8 以上错误码 | 目标目录被占用/权限不足；`download.ps1` 只在 ≥8 时报失败，0—7 都正常 |
| 下载后文件是旧的 | 先 `.\sync.ps1` 再 `.\download.ps1`；只要最近变过的文件加 `-Since <日期>` |
| 想下的目录不在任何集合里 | `.\download.ps1 -Folders <目录1>,<目录2>`，或加进 `download_sets` |
| Agent 不知道本机算力/该用哪个环境 | 本机跑 `.\hardware.ps1 -Deep`（GPU/conda/torch+CUDA 全量上报）；agent 侧 `agent-hardware.sh` 读取，超 30 天会提醒重跑 |
| **助手侧**：`git log` 只剩 `Initial commit`，`git status` 全是新文件 | `.git` 被静默重置：`agent-recover.sh`（工作区不动），然后 `agent-sync.sh` 提交（它内部也会自动自愈） |
| 助手侧 fetch 拉不到远端分支 | `agent-sync.sh` / `agent-recover.sh` 现已自动补全 refspec（`+refs/heads/*:...`）再 fetch |
| 分支对不上 / 一团乱 | `.\doctor.ps1 -Fix`：重建 refspec + stash + 切回配置分支 + 拉取 |

## 5. 首次使用

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned      # 只做一次
.\bootstrap.ps1                                          # 身份 / 分支 / 首拉
.\doctor.ps1                                             # 确认状态（含技能版本）
.\hardware.ps1 -Deep                                     # 上报本机硬件与环境（每台机器一次）
```

## 6. 与 Agent 协作的约定

1. Agent 每轮 `agent-sync.sh` 提交推送（**只推约定分支**），回执落在 `receipt` 路径并按日期归档，你 `.\sync.ps1` 后可读；
2. 你这边只记两条：`.\sync.ps1`（取）和 `.\upload.ps1`（传）；要交材料用 `.\pack.ps1`；
3. 交付物落地 `.\download.ps1 -Set final`；增量加 `-Since <日期>`，目录不在集合里用 `-Folders`；
4. **计算/训练类工作**：agent 开工前先 `agent-hardware.sh` 看本机报告（GPU 型号显存、哪个 conda 环境有可用 CUDA 的 torch），据此选环境、选设备、定 batch size；硬件或环境变化后重跑 `.\hardware.ps1 -Deep`；
5. 任何"不对劲"先 `.\doctor.ps1`（或 `-Fix`），把输出贴给 Agent。

## 7. 装进新仓库（未来 Arena 会话一句话）

**完整的复制粘贴版提示词在 `templates/new-session-prompt.md`**（含安装命令、成功标志、
本机步骤、双向验收清单，装好技能的仓库都随身带着它）。最短一句话版：

> 参考 https://github.com/mqgg5630-cyber/git-pull-arena 的 skills/git-sync，
> 用 agent-install.sh 把它装到本仓库的当前分支。

Agent 实际执行的命令（沙箱里 git clone 可用、raw.githubusercontent.com 可能被墙）：

```bash
git clone --quiet --depth 1 -b arena/01a09fc1-git-pull-arena \
     https://github.com/mqgg5630-cyber/git-pull-arena.git /tmp/git-sync-src \
  && bash /tmp/git-sync-src/skills/git-sync/scripts/agent-install.sh \
         --branch <本会话工作分支>
```

（技能合并进 main 之后把 `-b` 换成 `main`。）

安装器行为：装 `skills/git-sync/` 全套 + 根目录 9 个 `.ps1`（含 `hardware.ps1`）+ gate（已存在则不动）；
**目标仓库已有 `sync.config.json` 时只更新 branch/补缺失键，其余配置全部保留**
（所以给已装过的仓库升级也是同一条命令）。`--gha` 额外装 CI；`--source` 可指定别的来源。
升级后用 `.\doctor.ps1` 看技能版本对账。
