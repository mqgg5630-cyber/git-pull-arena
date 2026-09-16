# 成功案例 v2.8.0 —— 一句话 → 装技能 → 打通本机 → 自循环到真机 accept

> 这条链路**已经在你本机跑通并留证**，不是沙箱自说自话。证据全部是分支上的提交与本机回执。
> 本版同时**取消了「不装第三方、不碰 venv」的限制**：那是把「别拿沙箱冒充本机」错写成了
> 「别装库」。现在沙箱想 `pip install python-docx` 就装，唯一硬要求不变：**产物经 git 到本机、
> 由本机值守回传判定**。

## 一、两步协议（用户只做第一步）

**第一步：安装 skills 并与本地打通**（本机粘一次，之后不用再管）

```bash
# 助手侧（沙箱）：装技能 + 推送
git clone --quiet --depth 1 -b arena/01a0a821-git-pull-arena \
  https://github.com/mqgg5630-cyber/git-pull-arena.git /tmp/git-sync-src \
  && bash /tmp/git-sync-src/skills/git-sync/scripts/agent-install.sh
bash skills/git-sync/scripts/agent-sync.sh "feat: install git-sync skill"
bash skills/git-sync/scripts/agent-handoff.sh          # 生成本机那段 PowerShell
```

```powershell
# 用户侧（Windows，一次）：把 agent-handoff.sh 打印的那段原样粘进去
cd E:\0github\git-sync
git clone -b <BRANCH> <ORIGIN_URL> <NEW_FOLDER>
cd <NEW_FOLDER>
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\bootstrap.ps1 -Auto ; .\doctor.ps1 ; .\watch.ps1 -Status
```

**第二步：按具体任务自循环**（助手侧，用户不用动手）

```bash
bash skills/git-sync/scripts/agent-handsfree.sh \
     --sync "feat: <本轮改动>" --request "verify: <任务一句话>" --timeout auto
```

`sync → request(round+1) → 等值守回传 → agent-criteria → accept`，退出码 0 = 闭环，
2 = 本机判失败（读 `results/status/check_rN_*.txt` 修），3 = 本机没通（重发交接块）。

## 二、真机证据（本机 `LAPTOP-R77M5D6M` 自己推上来的提交）

| 轮次 | 请求内容 | 本机裁决 | 提交 | 本机时间 |
|---|---|---|---|---|
| 20 | 验证技能安装 | `passed` → accept | `edf5e56` | 2026-09-16 18:27:03 +0800 |
| 21 | docx+pptx 逐字节到达 + OOXML 合法 | `passed` → accept（**47 秒**回传） | `2a9e7e7` | 2026-09-16 18:46:02 +0800 |
| 22 | 3h 修复后回归 + 脚本再解析 | `passed` → accept | `1d739a8` | 2026-09-16 18:50:39 +0800 |

第 22 轮回执 `results/status/check_r22_20260916-185014.txt` 里最硬的三行：

```text
OK 3h Word.Application opened read-only, name=BRIDGE_REPORT_v2.7.4.docx
OK 3h PowerPoint.Application opened read-only, slides=9
OK: every .ps1 parses        <- 真 PowerShell 解析器（沙箱只能 SKIP）
```

即：**真 Word / 真 PowerPoint 打开了手写 OOXML，没有修复提示**；本机用真解析器验了助手改的脚本。

更早一轮（zhongqi 仓库 `arena/01a0a95e-zhongqi`）round 1 也是本机判的：`c88dafe check: round 1 passed`，
17 个产物 sha256/体积/OOXML 全对，`== deliverables on this machine: 17 intact, 0 failed`。

## 三、本机 `local_check.ps1` 到底查什么（第 3 节，v2.8.0 随包）

| 项 | 查什么 | 为什么 |
|---|---|---|
| 3a | sha256 + 字节数 == 生成时的值 | 经 git 到达的文件没被改写 |
| 3b | 必需部件齐全（docx 7 / pptx 11） | 缺部件 = Office 报损坏 |
| 3c | 每个 XML 部件可解析 | 手写 OOXML 最容易破的就是这里 |
| 3d | **每个关系目标可解析**（`r:id` 不断链） | 断链是「内容有问题」的头号原因 |
| 3e | `[Content_Types].xml` 覆盖每个部件 | 漏声明 = 打不开 |
| 3f | 正文标记词在位 | 内容真的写进去了 |
| 3g | 幻灯片数 ≥ 期望 | 页数没缩水 |
| 3h | 真 Word/WPS、真 PowerPoint COM 只读开档（120s 硬超时，无 Office 则 SKIP） | 应用级最终裁判 |

外加：闸门（.ps1 全 ASCII / 配置分支 / 根目录与 skill 脚本一致 / 值守收尾行）、
`accept 2a` 免点击推送证明、`accept 2b` 值守窗口等级、`success_criteria.json`（含 `forbid_files`）。

## 四、v2.8.0 改了什么（每条都有对应的真实事故）

| # | 改动 | 之前的真实事故 | 怎么验的 |
|---|---|---|---|
| 1 | **取消「不装第三方 / 不碰 venv」** | 上一轮因 PEP 668 装不了库，被迫手写 OOXML，自己背 schema 责任、修了 3 个会让 PowerPoint 报错的错 | 文档/铁律/SKILL description 全部改写；`success_criteria.json` 的 `forbid_files` 去掉 `.venv`/`venv`，只留 `local/inbox` 等「假本机」项。**并且实测：PEP 668 只挡系统 python 的 `pip install --user`，`python3 -m venv /tmp/oa` + `pip install python-docx python-pptx` 在沙箱里 5 秒装好、`python-pptx 1.0.2` 可 import——那条限制从一开始就是多余的，手写 OOXML 属于自找的** |
| 2 | **安装器取最新分支 + 拒绝降级** | `DEFAULT_SOURCE_BRANCHES` 里 `main` 排在前面 → 照文档 one-liner 会静默装成 v2.6.7，并 `rm -rf skills/git-sync` 删掉 v2.7.x 的 11 个文件 | 实测：干净仓库跑安装器 → 选中开发分支装 v2.7.5（0.64s）；把本地 VERSION 改成 9.9.9 再装 → `[REFUSED] refusing to downgrade … installed v9.9.9, source has v2.7.5`，exit 2；`--force` 才覆盖 |
| 3 | **`.gitattributes` 统一 LF** | 本机日志显示文本文件到 Windows 都变大（`VERSION` 6→7 B、`watch.ps1` 83666→85361），CRLF 让按字节的验收假失败 | 新增 `* text=auto eol=lf` + `*.sh/*.py/*.json/*.md/*.tsv/*.yml/VERSION text eol=lf`；docx/pptx 仍 `binary`（所以它们字节数一直没变） |
| 4 | **值守每行带时间戳** | 用户问「我才知道具体跑没跑」 | `Show-PollSummary` 给每条收尾行加 `[yyyy-MM-dd HH:mm:ss]`；`auto_pull` / `auto_push` 日志行也带时间；`-Status` 的心跳块本来就打印 `last_auto_pull_at` / `last_auto_push_at` |
| 5 | **轮询自适应提速** | round 21 的 47 秒里大部分是轮询延迟（固定 15s + 每轮全量 `git fetch`） | `agent-wait.sh`：前 120 秒每 5 秒轮询，之后回落到 `--interval`；并用 `git ls-remote` 比对分支尖端，**只有尖端变了才 fetch** |
| 6 | **交接块生成化（v2.7.5 起）** | 手打命令写错仓库/分支/路径 → 请求在 `pending` 挂 2 小时 | `agent-handoff.sh` 从 `git remote get-url` + 配置 branch 生成；配置分支 ≠ HEAD 直接 exit 3 |
| 7 | **闸门校验「配置分支 == HEAD」** | 新会话继承上个会话的 `sync.config.json`，本机永远收不到请求 | `code/check_all.sh` 2b 段；负向实测：改错分支 → `[FAIL] … but HEAD is …`，exit 1 |

## 五、还剩的坑（照实说）

- **值守是 fallback 模式**：`accept 2b (fallback)` = 常驻循环进程，每次登录闪一下窗口。彻底零闪窗要管理员：`.\watch.ps1 -Unregister ; .\watch.ps1 -Register -Headless`。
- **本机没有可用的 `python3`**（Windows Store 存根），所以本机侧的 `$var:` 扫描、值守收尾行静态检查、文档 QA 都是 `SKIP`，靠沙箱侧兜。
- **3h 会真的启动 Word/PowerPoint**：不想每轮启动就 `setx GIT_SYNC_OFFICE_COM 0`（新窗口生效）。
- **沙箱每轮重造**：`.git` 的创建时间就是本轮开始时间，`/tmp` 每轮清空 → 任何跨轮状态只能放分支上。
