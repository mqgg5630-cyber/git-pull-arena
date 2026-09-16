# 用户一句话 —— 助手必须自动跑完全套（先打通本机，再自循环）

用户在**任何新 Arena 会话**里发下面这类话（有无 markdown 链接、有无后半段任务，都算同一套入口）。
助手**不要再向用户要长提示词**。

## 铁律（违反 = 没打通，不许说完成）

1. **「与本地打通」= 用户 Windows 上的 git 克隆 + `.\watch.ps1` 计划任务。**
   不是沙箱里建 `local/inbox/`，不是 python `local_bridge`，不是 `copy_to_local()`，
   不是自己写一套 `skills/docx_skill.py`。那些都是假本机。
2. **必须安装的 skills** 只有这一份：
   `https://github.com/mqgg5630-cyber/git-pull-arena` 分支 `arena/01a0a821-git-pull-arena`
   里的 `skills/git-sync`（第 1 节那条 clone 命令）。
   `arena.ai/agent/01a0a821-...` **不要去打开**（要登录）。技能只在 GitHub。**禁止**用 python 复刻，禁止 `.venv` 冒充本机。
3. **给用户的第一条可见回复必须是第 2 节填好的 PowerShell**（clone 新文件夹 + `bootstrap -Auto`）。
   在用户还没拿到这段命令之前：不许生成 docx/pptx、不许自循环、不许写 LOOP_COMPLETED、
   不许说「已返回本机」。
4. 自循环只准走 `agent-handsfree.sh --timeout auto`（git 握手 + 本机值守回传）。
   exit 3 = 本机值守没起来 → **停**，再贴一次 PowerShell，**不要**假装成功。
5. 禁止覆盖文件夹：`git-pull-arena` / `git-pull-arena-v268` / `git-pull-arena-s2`。

## 触发句

**推荐用户粘贴 `templates/USER_PROMPT.md` 里的整段**（自带 GitHub clone 命令）。
只说「安装 arena.ai/agent/01a0a821 的 skills」会失败：沙箱打不开 arena.ai，对方就会自己写 python。

短句仍算同一套（助手必须去 GitHub 装，禁止打开 arena.ai）：

```text
安装 arena/01a0a821-git-pull-arena skills, 与本地打通
```

```text
从 github.com/mqgg5630-cyber/git-pull-arena 分支 arena/01a0a821-git-pull-arena 安装 skills/git-sync，与本地打通。不要自己写 python。
```

后半段任务可换。带自循环就走第 3 节——必须先做完第 1、2 节。

---

## 0. 要不要先去旧克隆 sync？

**不用。** 新会话装技能、做任务、都推到**本会话工作分支**。

本机要对**这个新仓库**粘贴一次第 2 节（沙箱不能注册 Windows 计划任务）。
跑完不用回「好了」，也不用再 `sync`/`push`。假的 `local/inbox` 不算。

| 时机 | 你要不要动手 |
|---|---|
| 这句话发出去 | 助手先装 git-sync，**先把 PowerShell 发给你** |
| 这个新会话还没有值守 | 粘贴一次第 2 节 |
| 值守已在跑（同一文件夹重开） | 不用再粘，助手可以直接 `agent-handsfree` |
| 简单任务 | 值守一回传，`agent-handsfree` 立刻停（不是死等 600 秒） |

---

## 1. 助手必须先做（不要问、不要改命令）

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
test -f watch.ps1 && test -f skills/git-sync/VERSION && echo "git-sync OK"
```

HEAD 若是 `main` / `master`：**停**，先切到本会话工作分支再装。
若 `watch.ps1` 不存在：**没装上，不许进入第 3 节。**

---

## 2. 助手必须立刻回复的本机代码（填好，可直接粘）——第一条回复就是这个

新文件夹建议：`<仓库名>-<工作分支短号>`。

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

## 3. 本机命令已经发出去之后，若用户还说了具体任务 / 自循环

任务从提示词里抽（docx/pptx 只是例子）。交付物放 `deliverable/`，用 git 到用户机器，
**禁止** `local/inbox`。

1. 写 `results/status/success_criteria.json`。
2. `agent-sync.sh` 推上**本会话分支**。
3. 自循环：

```bash
bash skills/git-sync/scripts/agent-handsfree.sh \
     --sync "feat: <本轮改动>" \
     --request "verify: <用户的任务一句话>" \
     --timeout auto \
     --interval 15
```

- exit 0：本机检查过 + 标准过 + 已 accept → 停。
- exit 2：看 `results/status/check_r*_*.txt` → 修 → 再跑（round+1）。
- exit 3：本机没通。再贴第 2 节。**禁止**改口说「沙箱 local/ 已打通」。

`--timeout auto`：结论一到就返回。细节：`templates/task-loop.md`。
