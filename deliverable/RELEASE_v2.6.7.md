# git-sync v2.6.7 发布说明（`main`）

> 本版已发布到 **`main`**（PR #1，合并提交 `009fb6a`）。开发分支：`arena/01a0a4f5-git-pull-arena`。
> 真机（Windows 11 + PowerShell 5.1 + git 2.54.0 + GCM 2.7.3 + gh 2.97.0）验收通过。

---

## 一、这一版解决了什么（用户的两条硬要求）

| 要求 | 状态 | 真机证据 |
|---|---|---|
| **推送免点击**（`push` 不再要人点确认） | ✅ | `auth.ps1 -Verify` exit 0；`== accept 2a: silent push PROVEN (ls-remote + push --dry-run, prompts disabled)` |
| **值守零弹窗**（不再每 2 分钟闪黑窗） | ✅ | 值守改为**常驻循环**：窗口最多"每次登录一次"（原先 720 次/天）；启动器模式与 `-Register -Headless`（S4U/session 0）为**严格零闪**；循环还会**自我脱离**，不再占用用户控制台 |

**闭环证据**：值守自动跑完 round 15，并**免点击**把结论推回（`a884f73 check: round 15 passed`），
`.\watch.ps1 -Status` 显示 `last_push: ok`、`last_verdict: passed`、`loop process: pid … (running)`。

---

## 二、组件与能力

| 组件 | 说明 |
|---|---|
| `auth.ps1` | 凭据：**先探测再改动**；`-GhLogin`（唯一一次交互登录，自动 `gh auth setup-git`）、`-PromptToken`/`-TokenFile`（**离线入库**，不需要 API）、`-MigrateStore`（复制到 dpapi 供 session 0）、`-HttpProxy`/自动套用 `git config http.proxy`、`-Json`（给 `doctor`/`local_check` 读）、`-Unset` |
| `watch.ps1` | 值守：常驻循环（`-Loop`）+ keeper 保活（10 分钟）+ 旧循环清理 + 单实例 pid + 自我脱离；零窗口启动器（编译→`MZ` 校验→冒烟测试→失败自动回退 `-Flash`）；`-Status`（模式/pid/心跳年龄/push 结果与原因/other loops）、`-Test`、`-Pause`/`-Resume`/`-Unregister` |
| `sync.ps1` / `push.ps1` | 双机同步：所有 git 调用经 `cmd /c`（PS 5.1 把子进程 stderr 当致命错误是多次崩溃的根因）；产物提交 amend 化 + 自动对齐远端；`push -Prompt` 显式开交互；错误提示给可执行命令 |
| `doctor.ps1` | 体检：环境 / 分支 / LFS / 值守 / 心跳 / 凭据（含代理不一致提醒、`auto-stash` 堆积提示） |
| `code/local_check.ps1` | 验收 2a（免点击推送：`ls-remote` + `push --dry-run`，prompts 全关）与 2b（值守可见性**分级**：零闪 / 每次登录一次 / 每轮一次=FAIL） |
| `code/scan_ps_var_colon.py` | 闸门扫描 `"$var:"`（盘符变量陷阱，曾让整个 `watch.ps1` 解析失败） |
| `agent-*.sh` | **agent 侧**：`agent-sync.sh`（提交前比对握手，避免覆盖本地已推回的结论）、`agent-check.sh --request/--read`、`agent-install.sh`、`agent-pr.sh`、`agent-wait.sh`、`agent-recover.sh`、`agent-hardware.sh` |

---

## 三、本机升级（一条命令）

```powershell
cd E:\0github\git-sync\git-pull-arena
.\sync.ps1                                     # 取到 v2.6.7
.\watch.ps1 -Unregister ; .\watch.ps1 -Register # 新循环（会顺手清掉旧循环）
.\watch.ps1 -Status                            # 期望：other loops 为空、last_push: ok
```

（凭据已在 round 12 配好：`gh` 已登录并把 gh 设为 github.com 的凭据助手。）

---

## 四、回退

| 方式 | 命令/分支 |
|---|---|
| 退回"每次登录闪一次"的保守模式 | `.\watch.ps1 -Unregister ; .\watch.ps1 -Register -Flash` |
| 完全不值守（需要时手动跑一轮） | `.\watch.ps1 -Unregister`；之后 `. \watch.ps1` 手动处理 |
| 退回 v2.4.7（旧分支，冻结未动） | `git checkout arena/01a09fc1-git-pull-arena` |

---

## 五、问题账（v2.5.0 → v2.6.7，真机踩坑 14 项）

逐轮记录见 `deliverable/FIX_v2.5.1.md`、`FIX_v2.6.0.md`、`FIX_v2.6.1.md`、`FIX_v2.6.2.md`、`FIX_v2.6.3.md`、`FIX_v2.6.4.md`、`FIX_v2.6.5.md`。摘要：

1. VBScript 启动器在 Win11 静默死亡 → 编译式零窗口启动器
2. `"$round:"` 被当盘符变量 → 整份 `watch.ps1` 解析失败 → `${round}:` + 闸门扫描器
3. `auth.ps1 -Setup` 乱改 `credentialStore`，把 wincredman 里的凭据"藏掉"
4. 机器从未存过 GitHub 凭据（每次 push 都要手点）→ `gh` 登录后彻底解决
5. `gh` 不走 git 的代理 → 登录超时 → 自动套用 `http.proxy` / `-HttpProxy`
6. 我的 dry-run 探针把"非快进被拒"误判成认证失败
7. 值守结论提交导致分支分叉 → `pull --ff-only` 永远失败
8. `sync.ps1`/`push.ps1` 把 git 的 stderr 当终止性错误 → 轮询中途崩溃
9. `check_cmd` 用裸名字启动失败（`%1 不是有效的 Win32 应用程序`）→ 绝对路径 + `cmd /d /c`
10. 退出码读不出来（`failed (exit )`、过期的 0）→ `cmd /v:on` + `!ERRORLEVEL!`
11. 闸门因"PATH 上的 python3 不可用"假失败 → 解释器自检 + `sed` 回退
12. 值守常驻进程占住用户控制台（"一直卡住"）→ 自我脱离 + 单实例 + 旧循环清理
13. 过期握手覆盖已推回的 `passed`（害值守重跑同一轮）→ `agent-sync.sh` 提交前比对
14. 循环结束静默 sleep（看起来像卡在最后一行）→ 打印 `== idle - next poll at HH:MM:SS`
