# 用户一句话 —— 助手必须自动跑完全套（装技能 + 打通本机 + 可选自循环）

用户在**任何新 Arena 会话**里发下面这类话（有无 markdown 链接、有无后半段任务，都算同一套入口）。
助手**不要再向用户要长提示词**。

## 触发句（等价，命中任一条就开跑）

```text
安装 arena/01a0a821-git-pull-arena skills, 与本地打通
```

```text
安装https://arena.ai/agent/01a0a821-3f3c-7bbe-bf99-6e6793c45d81的skills。与本地打通
并实现自循环任务，将这个生成docx和pptx返回到本机，本机并把结果状态push到分支，一直自动循环知道你觉得结果没问题
```

也算（关键词：`安装` + `skills` + `打通`；后半段任务可换）：

- `安装 https://github.com/mqgg5630-cyber/git-pull-arena/tree/arena/01a0a821-git-pull-arena 的 skills，与本地打通`
- `安装 [arena/01a0a821-git-pull-arena](...) skills, 与本地打通`
- 任务不一定是 docx/pptx：改成「生成报告 / 跑脚本 / 改代码 / 画图」等，只要带 **自循环 / 一直循环直到没问题 / 自动验收**，就走第 3 节任务环

`https://arena.ai/agent/01a0a821-...` = 本技能总部，来源分支永远是
`arena/01a0a821-git-pull-arena`（仓库 `mqgg5630-cyber/git-pull-arena`）。

---

## 0. 先回答「要不要先本地同步？」

**不用等上一个会话。** 新会话这句话本身就会：装技能 → 开始做任务 → 推到**本会话工作分支** → 等本机值守回传 → 标准过了就 accept。

但 Windows 计划任务沙箱**按不了**，所以每个**新仓库 / 新会话克隆**本机要粘贴**一次**第 2 节的 PowerShell（`clone` 新文件夹 + `bootstrap -Auto`）。

| 时机 | 你要不要动手 |
|---|---|
| 这句话发出去之后 | 助手立刻装技能、写标准、做任务、push。**不用**先去 HQ 目录 `.\sync.ps1` |
| 这个新会话的本机克隆**还没有**值守 | 粘贴一次第 2 节。跑完**不用回「好了」**，也不用再 `sync`/`push` |
| 值守已经在跑（同一文件夹重开对话） | 什么都不用粘，助手直接自循环 |
| 任务简单，值守 1～2 分钟推回结论 | `agent-handsfree` **立刻结束**，不会空等到 600 秒 |
| 任务难，检查要跑十几分钟 | 上限跟 `check_timeout_min`（默认 30 分钟 + 3 分钟余量），等到结束 |

禁止覆盖：`git-pull-arena` / `git-pull-arena-v268` / `git-pull-arena-s2`。

---

## 1. 助手必须执行（不要问、不要改命令）

```bash
git clone --quiet --depth 1 -b arena/01a0a821-git-pull-arena \
  https://github.com/mqgg5630-cyber/git-pull-arena.git /tmp/git-sync-src \
  && bash /tmp/git-sync-src/skills/git-sync/scripts/agent-install.sh

bash skills/git-sync/scripts/agent-sync.sh "feat: install git-sync skill"
```

然后读：

```bash
git remote get-url origin
git rev-parse --abbrev-ref HEAD
```

HEAD 若是 `main` / `master`：**停**，先切到本会话工作分支再装。

---

## 2. 助手必须回复的本机代码（填好，可直接粘）

新文件夹建议：`<仓库名>-<工作分支短号>`，例如 `image-to-editable-pptx-01a04caf`。

```powershell
cd E:\0github\git-sync
git clone -b <BRANCH> <ORIGIN_URL> <NEW_FOLDER>
cd <NEW_FOLDER>
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\bootstrap.ps1 -Auto
.\doctor.ps1
.\watch.ps1 -Status
```

把 `<BRANCH>` / `<ORIGIN_URL>` / `<NEW_FOLDER>` 换成刚才读到的真值。不要留占位符。

成功标志：`doctor.ps1` 的 branch 是工作分支、ahead/behind = 0/0、末尾 watcher / heartbeat / auth / **hands-free master=True**。

`bootstrap -Auto` 会暂停其他会话的 `git-sync-watch-*`（任务保留）。回 HQ：

```powershell
cd E:\0github\git-sync\git-pull-arena-s2
.\watch.ps1 -Focus
```

---

## 3. 若用户还说了具体任务 / 自循环 —— 助手接着做（不要等用户再发一句）

任务从提示词里抽（docx/pptx 只是例子）。然后：

1. 把交付物做到 `deliverable/`（或任务指定的路径），`agent-sync.sh` 推上**本会话分支**。
2. 写 `results/status/success_criteria.json`（存在哪些文件、关键子串、最小字节）。本机 `local_check.ps1` 和助手 `agent-criteria.sh` 都读它。
3. 自循环（失败就改、再请求，直到 accept；**不要**固定睡 600 秒）：

```bash
bash skills/git-sync/scripts/agent-handsfree.sh \
     --sync "feat: <本轮改动>" \
     --request "verify: <用户的任务一句话>" \
     --timeout auto \
     --interval 15
```

- exit 0：本机检查过 + 标准过 + 已 accept → **停**，告诉用户交付物在 `deliverable/`，本机值守会自动拉。
- exit 2：看 `results/status/check_r*_*.txt` 和 `agent-criteria.sh` 输出 → 修 → 再跑同一条（round+1）。
- exit 3：本机值守还没起来。再把第 2 节 PowerShell 贴一次（不要改命令），**不要**假装成功。

`--timeout auto` = `check_timeout_min * 60 + 180`（最短 240 秒，最长 7200 秒）。
值守一推回 passed/failed，wait **马上返回**。

细节清单：`templates/task-loop.md`。
