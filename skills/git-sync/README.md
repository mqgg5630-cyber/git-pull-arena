# 本地 ↔ Agent 同步 skill —— 使用说明

> 目标是：**取、传、下载、打包、排障各一个命令**，不需要 git 知识；
> 一份配置（`sync.config.json`）驱动全部脚本，`agent-install.sh` 一条命令装进任何新仓库。
> 仓库根目录放着同款脚本（`sync.ps1 / push.ps1 / upload.ps1 / download.ps1 / doctor.ps1 / pack.ps1 / bootstrap.ps1 / pr.ps1`），
> 这份 skill 是**通用版 + 说明书**。

## 一、最短用法（在仓库目录里）

```powershell
.\sync.ps1                                # 取：拉最新（本地有改动会自动 stash）
.\upload.ps1                              # 传：附件归位到 sources\ code\ results\ 后 commit + push
.\push.ps1 "说明"                          # 传：直接提交推送（拒绝推 main）
.\download.ps1 -Set final                 # 下载：把 deliverable\ 等目录镜像到本机
.\download.ps1 -Set final -Since 2026-09-14   # 只复制该日期之后变过的文件（先 .\sync.ps1）
.\download.ps1 -List                      # 看有哪些集合
.\pack.ps1 -Set final                     # 打包：生成 _export\20260914_2030_final.zip
.\doctor.ps1                              # 体检：环境 / 分支 / 远端 / 未提交 / stash / 大文件
.\doctor.ps1 -Fix                         # 一键修复：重建 refspec + stash + 切回分支 + 拉取
.\pr.ps1                                  # 开 PR：工作分支 -> main（需 GitHub CLI）
```

助手那一侧（本仓库的 `skills/git-sync/scripts/`）：

```bash
bash skills/git-sync/scripts/agent-sync.sh "feat: xxx"     # 守卫 + fetch + 自检 + 回执 + commit + push
bash skills/git-sync/scripts/agent-sync.sh --status        # 只看状态，不动文件
bash skills/git-sync/scripts/agent-recover.sh              # 沙箱 .git 被重置后的恢复
bash skills/git-sync/scripts/agent-pr.sh --dry-run         # 开 PR（--dry-run 只打印）
bash skills/git-sync/scripts/agent-pr.sh --checks          # 看 PR 的 CI 状态
```

## 二、脚本与配置

| 文件 | 说明 |
|---|---|
| `sync.config.json` | **唯一的配置**：`branch` / `remote` / `download_dir` / `download_sets` / `upload_map` / `gate` / `receipt` |
| `scripts/sync.ps1` | 拉取；配置查找：`-Config` 参数 > `sync.config.<GIT_SYNC_PROFILE>.json` > 仓库内 `skills\git-sync\` > 脚本旁边 |
| `scripts/push.ps1` | 提交推送；**拒绝推 `main` / `master`** |
| `scripts/upload.ps1` | 附件归位：扩展名 → 目录映射取自 `upload_map`，也可 `-Ext`/`-Dest` 临时指定 |
| `scripts/download.ps1` | robocopy 镜像下载；`-Set` 选集合，`-Mirror` 完全镜像，`-Since <日期>` 增量 |
| `scripts/pack.ps1` | 压缩包交付；输出到 `_export\`（已在 `.gitignore` 里，不会被推送） |
| `scripts/doctor.ps1` | 体检报告 + LFS/大文件检查；`-Fix` 一键修复；ahead/behind 对比的是 `origin/<分支>`（修复了老版本永远显示 0 的 bug） |
| `scripts/bootstrap.ps1` | 首次准备：执行策略、git 身份、fetch、切分支、首拉 |
| `scripts/pr.ps1` | GitHub CLI 开 PR / 查 CI；`-Base` 换目标分支，`-Checks` 看检查状态 |
| `scripts/install.ps1` | 装到另一个仓库：`.\install.ps1 -Target C:\MyProject -Branch main`（目标已有配置时只动 branch，其余保留） |
| `scripts/agent-sync.sh` | 助手侧一键：分支守卫 → fetch → 发散自愈 → gate → **写同步回执** → commit + push |
| `scripts/agent-pr.sh` | 助手侧开 PR / 看 CI |
| `scripts/agent-recover.sh` | 助手侧修复：`.git` 被重置回基线提交时，保住工作区把 HEAD 挪回分支 |
| `scripts/agent-install.sh` | **一条命令装进任何仓库**（见第六节） |
| `templates/check_all.sh` | 通用 gate 模板（ASCII + 分支守卫 + 根目录/skill 脚本一致性） |
| `templates/gate.yml` | GitHub Actions 模板：push 后自动跑 gate |

同步回执：助手每轮 `agent-sync.sh` 会把"纳入了你哪些提交、这轮改了哪些文件"写进配置里
`receipt` 指定的文件（默认 `results/sync/last_sync.md`），你 `.\sync.ps1` 之后打开就能看到。

## 三、为什么 `.ps1` 里绝对不能写中文

Windows PowerShell 5.1 读**没有 BOM** 的 `.ps1` 时按 **ANSI/GBK** 解码；UTF-8 的中文注释会变成乱码，
乱码里一旦出现引号就会把后面的字符串吞掉，报 `字符串缺少终止符` / `InvalidArgument`。
约定：**`.ps1` 只用 ASCII，中文只出现在 `.md` / `.json`**；
gate（`code/check_all.sh`）提交前自动扫描全部 `.ps1`，非 ASCII 直接 FAIL。

中文目录名（如 `中间版`）因此**只写在 `sync.config.json` 里**，脚本用 `Get-Content -Encoding UTF8` 读取，
再拼路径——这样既有中文目录，又不会有 GBK 问题。

所有 `.ps1` 从脚本位置**自动上溯找仓库根**（有 `.git` 的目录），所以放在根目录或
`skills\git-sync\scripts\` 里都能直接运行。

## 四、三道安全阀

1. **分支守卫**
   * `push.ps1` / `pr.ps1` / `agent-pr.sh`：分支是 `main` / `master` 直接拒绝；
   * `agent-sync.sh`：HEAD 与配置里的分支不一致就退出（不会误推到别处），并且只 `git push origin <配置分支>`。
2. **提交前自检（gate）**
   `sync.config.json` 的 `gate`（默认 `bash code/check_all.sh`）失败时 `agent-sync.sh` **不提交**，
   因此远端历史里的每个提交都是自检通过的。
3. **远端 CI（可选）**
   `templates/gate.yml` 装到 `.github\workflows\` 后，每次 push 在 GitHub 上自动跑同一套 gate。
   注意：GitHub App 类的 agent 令牌往往**没有 workflows 权限**，推不动这个目录——
   这时由本机侧启用（你的凭据可以）：

   ```powershell
   New-Item -ItemType Directory -Force .github\workflows | Out-Null
   Copy-Item skills\git-sync\templates\gate.yml .github\workflows\gate.yml
   .\push.ps1 "ci: enable gate workflow"
   ```

## 五、故障对照表

| 现象 | 处理 |
|---|---|
| `running scripts is disabled` | 跑一次 `.\bootstrap.ps1` |
| 要密码 / 认证失败 | GitHub 不接受密码：`gh auth login` 或 GitHub Desktop |
| `Updates were rejected`（远端有新提交） | 先 `.\sync.ps1`，再 `.\push.ps1` |
| `pull --ff-only` 失败（本地有分叉提交） | `.\doctor.ps1` 看状态；或 `.\doctor.ps1 -Fix` |
| 本地改动"消失"了 | 多半在 stash：`git stash list` → `git stash pop` |
| 下载后文件是旧的 | 先 `.\sync.ps1` 再 `.\download.ps1`；只要增量加 `-Since <日期>` |
| robocopy 返回 1—7 | 正常（有文件被复制 / 无变化 / 有额外文件），只有 ≥8 才算失败 |
| 想看这轮助手到底改了什么 | `.\sync.ps1` 后打开 `results\sync\last_sync.md`（同步回执） |
| **助手侧**工作区正常但历史回到基线提交 | `bash skills/git-sync/scripts/agent-recover.sh` → `agent-sync.sh` |

## 六、装到别的项目

**助手侧 / 新 Arena 会话（推荐，一条命令）**：

```bash
git clone --quiet --depth 1 -b arena/01a09fc1-git-pull-arena \
     https://github.com/mqgg5630-cyber/git-pull-arena.git /tmp/git-sync-src \
  && bash /tmp/git-sync-src/skills/git-sync/scripts/agent-install.sh --branch <工作分支>
```

（技能合并进 main 后把 `-b` 换成 `main`；也可以 `--gha` 顺带装 CI。）

**本机侧**（比如升级 zhongqi 这种已有配置的仓库）：

```powershell
.\skills\git-sync\scripts\install.ps1 -Target E:\0github\git-sync\zhongqi -Branch arena/01a09d79-zhongqi
cd E:\0github\git-sync\zhongqi
.\push.ps1 "chore: upgrade git-sync skill"
```

两种方式**都保留目标仓库已有的 `sync.config.json`**（只更新分支、补缺失的键），装完只需要按需编辑配置。

## 七、扩展清单

已实现：

- [x] 取 / 传 / 下载 / 打包 / 体检 / 首次准备 / 复用安装 / 开 PR 八类命令
- [x] 配置化：分支、远端、下载集合、扩展名归位、gate、回执路径
- [x] 分支守卫 + 提交前自检（gate）+ 可选 GitHub Actions 远端 CI
- [x] 助手侧 `agent-sync.sh`（含发散自愈、**同步回执**）与 `agent-recover.sh`（沙箱重置恢复）
- [x] `doctor.ps1 -Fix` 一键修复；ahead/behind 改为对比 `origin/<分支>`
- [x] `download.ps1 -Since <日期>` 增量下载
- [x] 多环境 profile（`GIT_SYNC_PROFILE` / `-Config`）
- [x] `agent-install.sh`：任何仓库一条命令安装/升级（保留配置）
- [x] LFS / 大文件体检（>50 MB 提醒）

还想加的（按需）：

- [ ] `agent-sync.sh` 自动 `git lfs install` + push 前 `lfs status` 检查（真有大文件时）
- [ ] 增量清单落到回执里（`-Since` 语义进 `last_sync.md`）
- [ ] 同步报告归档：每轮回执按日期留档，不只覆盖最近一轮
