# 移植：换系统、换身份、换任务

三件事彼此独立 —— 换任务只动**配方**，换系统只动**三个适配器**，换身份只动**桥**。
下面按"要改的文件 / 不要改的文件 / 怎么验证"写。

## 1. 换任务（最常见）

```bash
cp code/recipes/office-deck.json code/recipes/my-task.json   # 照抄一份
# 改 sandbox.steps / local.steps / receipt.keys / evidence
python3 code/local_loop.py plan        # 先看"谁在哪里跑"符不符合直觉
python3 code/local_loop.py sandbox --apply
```

`code/loop.json` 的 `recipe` 指向新的那份即可。**不要**改 `local_loop.py`、`gates.py`、
`local_check.*` —— 它们是任务无关的。

配方里必须回答的三个问题：

1. 成品是什么？→ `evidence[]`（回传到仓库的路径）
2. 怎么证明成品在**这台机器**上是好的？→ `local.receipt.keys`（键=值，机器自己写）
3. 为什么非本机不可？→ `needs[]` + 每个 step 的 `why`（写清楚，评审时会看）

**纯沙箱任务**（不需要本机）：`"local": {"skip": "artifact is a source tree; CI proves it"}` ——
runner 会照常写一份 `ok=true` 的统一回执，`plan` 会打印这个理由，不会假装本机验过。

## 2. 换系统

| 部件 | Windows | Linux | macOS |
|---|---|---|---|
| 本机检查 | `code/local_check.ps1`（3a–3h / 4a–4c） | `code/local_check.sh`（同编号） | 同 Linux（`--os macos`） |
| 本机执行 | `code/pptmaster_local.ps1` | `code/pptmaster_local.sh` | 同 Linux |
| 定时触发 | 计划任务（git-sync 桥的 `watch.ps1`） | `code/watch-linux.sh` + `templates/local-loop.timer`（systemd --user）或 `templates/local-loop.cron` | 同 Linux（launchd 或 cron） |
| "真应用打开" | PowerPoint COM（只读） | LibreOffice headless 转 PDF | 同 Linux |
| 换行/编码 | `.ps1` 必须 ASCII，CRLF 安全 | `.sh` 必须 `bash -n` 通过，LF | 同 Linux |

新增一个系统时只需要三样：一个 `local_check.<ext>`、一个 `pptmaster_local.<ext>`、一个定时器模板。
**仓库里的配方、门禁、验收标准、循环命令都不用动**（配方用 `steps.{windows,linux,macos}` 分派）。

### Linux 上已经端到端验证过什么（在沙箱里模拟"另一台 Linux 机器"）

* `local_loop.py local --os linux` → `loop-ok recipe=office-deck os=linux host=… ok=true deck_slides=12(/12) checker_blocking=0(/0) markers=ok(/ok) opened=na`
* `local_check.sh` → gates 全过 → 交付物 3a–3g 全 OK → 4a 用本机 venv 出稿 → 4b 键匹配 → 4c 无 LibreOffice 时如实 WARN
* `watch-linux.sh --once`（对着一个本地 bare 仓库）→ 看到待办轮次 → pull → 跑检查 → 写 `check_r1_*.txt` → 改 handshake → push；第二次运行**什么都不做**

**还没在真 Linux 上验证的**：systemd/cron 模板、LibreOffice 真实开档（沙箱无 LibreOffice）、
非 ASCII 主机名、代理环境。第一次在真 Linux 上跑时按第 4 节逐项确认。

## 3. 换身份（谁在驱动这个循环）

技能不假设"你是一个 Arena 会话"。契约只有四条：

1. 有一个能被 push 的**分支**（git 就是消息总线）；
2. 有一台**机器**，它愿意被定时触发（计划任务 / systemd / cron / 手动双击都行）；
3. 双方约定：请求放 `results/status/handshake.json`，判定放 `results/status/check_r<N>_*.txt`；
4. 谁都不覆盖对方写的文件（机器拥有 `results/` 里的回执/证据/日志，agent 拥有标准与文档）。

| 身份 | 怎么用 |
|---|---|
| Arena 会话（本案例） | `skills/git-sync/` 的粘贴块装值守；`agent-handsfree.sh` 跑一轮；`arena.ai/agent/<id>` 链接 → 映射到 GitHub 分支（**不要打开链接**） |
| 其他助理 / 另一个仓库的 agent | 同上面四条；把"请求/判定"两个文件名写进它的提示词即可，不需要任何 Arena 专有环境变量 |
| 人类开发者 | `bash code/check_all.sh`（本地门禁）+ `python3 code/local_loop.py plan`（看任务拓扑）+ 机器上 `make-deck.cmd` / `make-deck.sh` |
| CI（GitHub Actions / GitLab CI 等） | 只跑**沙箱平面**：`python3 code/local_loop.py sandbox --apply` + `python3 code/gates.py`；把 `local` 平面留给真机器（`machine-task` 那条 gate 的 `plane: local` 会自然地 SKIP）。产物用 CI 的 artifact 上传，判定用同一套回执格式 |
| 多台机器 | 每台机器一份 `results/status/local_loop_receipt.json` 会互相覆盖 —— 需要并存时给配方加 `receipt.file` 带主机名（`{host}` 占位符已支持） |

## 4. 在一台新机器上第一次跑，按这个顺序确认

```bash
python3 code/local_loop.py plan                 # 1. 任务拓扑对不对（谁在哪跑）
bash code/check_all.sh                          # 2. 沙箱门禁（新系统上注意 bash 版本）
python3 code/local_loop.py local --os linux     # 3. 本机平面：装 + 出稿 + 回执
bash code/local_check.sh                        # 4. 完整本机判定（含 3a–3h）
bash code/watch-linux.sh --once                 # 5. 值守单次跑（对着真远端；没有待办就退出 0）
systemctl --user enable --now local-loop.timer  # 6. 接管定时（或 cron）
```

每一步失败都有明确归属（见 `ARCHITECTURE.md` 第 6 节），不需要猜。

## 5. 已知限制（真 Linux 测试时优先看这些）

* `pptmaster_local.sh` 的 python 候选表比 Windows 版短（PATH、conda 常见路径、`/usr/bin`）；
  机器用 pyenv/asdf/nix 时请设 `GIT_SYNC_PPTMASTER_PYTHON=/path/to/python3`。
* LibreOffice 首次运行会弹用户配置（本脚本用 `--headless --norestore`，一般无碍）；
  无 GUI 的容器里若失败，`4c` 会如实 WARN，不会假装通过。
* systemd `--user` 需要 linger 才能在未登录时运行：`loginctl enable-linger $USER`。
* macOS 没有 `systemd`，用 `launchd` 或 cron；`soffice` 在 `/Applications/LibreOffice.app/Contents/MacOS/soffice`。
* `watch-linux.sh` 用 `git pull --ff-only`：工作区脏或有本地提交时它会**拒绝并写明原因**，绝不覆盖。
