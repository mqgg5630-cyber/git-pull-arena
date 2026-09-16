# 本会话交接说明 · git-sync v2.8.1（分支 `arena/01a0a9f0-git-pull-arena`）

> 2026-09-16 · 会话 `arena.ai/agent/01a0a9f0` · 技能来源：`arena.ai/agent/01a0a98d` → GitHub 分支 `arena/01a0a98d-git-pull-arena`
> 一句话：**技能装好了、产物在分支上、请求已发出（round 20）——只差你本机粘一次下面这段。**

## 1. 你本机要做的（一次，Windows PowerShell）

```powershell
cd E:\0github\git-sync
git clone -b arena/01a0a9f0-git-pull-arena https://github.com/mqgg5630-cyber/git-pull-arena.git git-pull-arena-01a0a9f0
cd git-pull-arena-01a0a9f0
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\bootstrap.ps1 -Auto      # 身份 + 分支 + 免点击推送凭据 + 注册值守
.\doctor.ps1               # branch=arena/01a0a9f0-git-pull-arena、ahead/behind 0/0、watcher/heartbeat/auth
.\watch.ps1 -Status        # 应看到 hands-free: master=True
```

* 这是**新文件夹** `git-pull-arena-01a0a9f0`；不要覆盖 `git-pull-arena` / `git-pull-arena-v268` / `git-pull-arena-s2`。
* `bootstrap -Auto` 会把本机其他 `git-sync-watch-*` 值守**暂停**（任务保留）；要全部拉回：`.\watch.ps1 -RestoreParked`。
* `-Status` 里若看到 `scheduled: NOT REGISTERED`，就再跑一次 `.\watch.ps1 -Register`（注册才会轮询）。

## 2. 这一轮助手做了什么

| 项 | 内容 |
|---|---|
| 技能升级 | `skills/git-sync` **v2.7.4 → v2.8.1**（安装器 `--source` 指向最新分支；`agent-install.sh` 自带**拒绝降级**） |
| 配置 | `sync.config.json` 的 `branch` = `arena/01a0a9f0-git-pull-arena`（本会话分支），其余键保留 |
| 仓库级校验 | `code/check_all.sh`、`code/local_check.ps1`（3a–3h）、`.gitattributes`（文本统一 LF）、`.gitignore` 对齐 v2.8.1 |
| 产物 | `deliverable/LINK_PROOF_v2.8.1.docx`、`LINK_PROOF_v2.8.1.pptx`、清单 `deliverable/OFFICE_HASHES.json`、生成器 `code/make_link_proof.py` |
| 请求 | `results/status/handshake.json` = **round 20 / awaiting_check / pending**（等你本机值守应答） |

### v2.8.1 里与你这台机器直接相关的两条

1. **本机 python 探测改成「逐个验证」**（`python3` → `python` → `py -3`）。你机器上 `python3` 是 Microsoft Store 存根（`command -v` 能命中但一跑就非零退出），所以以前本机的 `$var:` 扫描 / 收尾行检查 / 文档 QA **全是 SKIP**；现在会用 conda base 的真 python（`E:\spider\python.exe`，3.11.9）真跑。
2. **3h 开档测试改为读 `OFFICE_HASHES.json`**（不再写死文件名），所以本会话的 `LINK_PROOF_v2.8.1.*` 会被真 Word / 真 PowerPoint 打开验证。

## 3. 本机值守这一轮会做什么（`code/local_check.ps1`）

```
gate            : bash code/check_all.sh（.ps1 全 ASCII / 配置分支 == HEAD / 根目录脚本与 skill 一致 / $var: 扫描 / 收尾行 / .ps1 解析）
accept 2a–2d    : 免点击推送实证、值守窗口等级、每出口收尾行、hands-free auto_pull/auto_push
3a–3g           : 产物 sha256+字节、OOXML 必需部件、XML 可解析、关系不断链、内容类型覆盖、标记词、页数 ≥ 6
3h              : 真 Word / PowerPoint 只读开档（120s 硬超时；可用 setx GIT_SYNC_OFFICE_COM 0 关闭）
success criteria: results/status/success_criteria.json（本会话版）
```

判定与日志都会推回本分支：`handshake.json` 的 `local_state=passed|failed`，完整日志 `results/status/check_r20_<时间>.txt`。

## 4. 之后怎么闭环

* 助手侧读结论：`bash skills/git-sync/scripts/agent-check.sh --read`（0=过 / 2=败 / 3=还在等）
* 过了 → `--accept`（循环收尾，值守回到静默待命）
* 败了 → 看日志修，`--request` 再来一轮（round + 1）

## 5. 边界（不糊弄的部分）

* 「本机」= 你 Windows 上那个计划任务值守；**不是**沙箱里的 `local/inbox`，也不是自制脚本。
* 沙箱可以 `pip install` / 用 `.venv` 生成产物（v2.8.0 起），但那只是生成工具：**产物必须经 git 到本机、由本机值守判定**。
* 在本机回传 `passed` 之前，助手不会说「已打通」。
