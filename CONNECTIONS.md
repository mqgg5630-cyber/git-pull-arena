# 连接台账 —— Arena 仓库 × 分支 × 本机路径（防忘专用）

> 更新：2026-09-15 ｜ 技能版本：v2.4.2 ｜ 本文件在 `E:\0github\git-sync\git-pull-arena\CONNECTIONS.md`
> 忘了的时候：`cd E:\0github\git-sync\git-pull-arena` 然后 `notepad CONNECTIONS.md`

## 一、当前所有连接

| 用途 | GitHub 仓库 | 工作分支 | 本机路径 | 值守任务名 | 状态 |
|---|---|---|---|---|---|
| **git-sync 技能总部**（版本发布、升级源） | [mqgg5630-cyber/git-pull-arena](https://github.com/mqgg5630-cyber/git-pull-arena) | `arena/01a09fc1-git-pull-arena` | `E:\0github\git-sync\git-pull-arena` | `git-sync-watch-git-pull-arena` | ✅ 在线（本会话，值守 2 分钟） |
| **图片→可编辑PPT 项目**（fig3 交付物在那边） | [mqgg5630-cyber/image-to-editable-pptx](https://github.com/mqgg5630-cyber/image-to-editable-pptx) | `arena/01a04caf-image-to-editable-pptx` | `E:\0github\git-sync\image-to-editable-pptx` | `git-sync-watch-image-to-editable-pptx` | ✅ 在线（[该会话](https://arena.ai/agent/01a04caf-77d4-7672-92a2-59223763a988)；v2.3.4 @ `14c1f5f`，5/5 验收通过，值守 2 分钟） |
| **中期报告/PPT**（git-sync 技能发源地） | [mqgg5630-cyber/zhongqi](https://github.com/mqgg5630-cyber/zhongqi) | `arena/01a09d79-zhongqi` | `E:\0zhongqi\zhongqi`（你原有的克隆） | 未注册 | ✅ 可拉取（会话已结束；本会话对它只读） |
| **AgentArena**（基准测试工具 + 本机 runner 整合） | [mqgg5630-cyber/AgentArena](https://github.com/mqgg5630-cyber/AgentArena)（fork） | `arena/01a0a356-agentarena` | `E:\0github\git-sync\agentarena` | `git-sync-watch-agentarena` | ✅ 在线（round 1 accepted `2bcc53b`；设计文档 `docs/local-runner-brief.md`；**根目录精简安装**——无 skills/git-sync 目录，升级用 agent-install 即可，v2.4.0 起根目录配置也会被保留） |

## 二、日常命令速查（在任何已连接仓库的本机路径里）

```powershell
.\sync.ps1                # 取：拉最新
.\push.ps1 "说明"          # 传：提交并推送
.\doctor.ps1              # 体检（含技能版本）
.\download.ps1 -Set final # 交付物镜像到 ..\<仓库名>_out\
```

值守（自动验证循环，本机侧）：

```powershell
.\watch.ps1 -Register -Interval 2   # 注册值守（每 2 分钟轮询；v2.3.4 起默认就是 2）
.\watch.ps1                         # 手动跑一轮（立即处理 pending 的请求）
.\watch.ps1 -Unregister             # 摘除值守
Get-ScheduledTask git-sync-watch-*  # 看本机注册了哪些值守
```

## 三、技能升级命令（任何仓库同一条，已有配置不丢）

给那个仓库的 Arena 会话说"升级 git-sync"，或手动：

```bash
git clone --quiet --depth 1 -b arena/01a09fc1-git-pull-arena \
     https://github.com/mqgg5630-cyber/git-pull-arena.git /tmp/src \
  && bash /tmp/src/skills/git-sync/scripts/agent-install.sh
```

当前版本看 `skills\git-sync\VERSION` 或 `.\doctor.ps1` 的 skill 行。

## 四、故障速查（本台账相关的）

| 现象 | 处理 |
|---|---|
| 在 main 上提交时把未跟踪文件误扫进去（main 没有 .gitignore） | 修正：`git checkout <工作分支> -- .gitignore` 随下一次 main 提交带上；skills/ 模板只在工作分支上，跨分支取文件用 `git checkout <工作分支> -- <路径>`，不要 copy |
| 值守 12 分钟没响应（那边第 5 轮遇到过） | 本机手动 `.\watch.ps1` 跑一轮；`del $env:TEMP\git-sync-watch-*.lock`；`Get-ScheduledTaskInfo <任务名>` 看上次运行 |
| 值守推送卡住等同意 | 通常是凭据管理器在计划任务里要交互确认：手动 `.\watch.ps1` 一轮即可完成推送 |
| agent 说读不到你的检查结果 | 大概率是 BOM/编码，v2.3.2 已修——确认那边技能 ≥ v2.3.2 |
| 本地改动"消失" | 在 stash 里：`git stash list` → `git stash pop` |

## 五、历史里程碑

- 2026-09-14：git-sync v1（zhongqi 沉淀）→ 本仓库安装 → 双向打通（`1d4d62f`）
- 2026-09-14：v2（agent-install / 回执 / doctor -Fix / 增量下载 / PR / profile）
- 2026-09-14：v2.1（新会话提示词模板）→ 首次跨会话复用成功（image-to-editable-pptx）
- 2026-09-15：v2.2（回执归档 + 硬件上报：GTX 1650 / 22 conda 环境）
- 2026-09-15：v2.3（自动验证循环）→ 真机 4 轮闭环（BOM / .gitignore .log 两个真 bug 修复）
- 2026-09-15：image-to-editable-pptx 项目级验收 5 轮全过（fig3 PPTX：227 形状 / 0 贴图 / 1139 可编辑字符）
- 2026-09-15：v2.3.4（移植 add -A 假删除守卫 / 值守默认 2 分钟 / 模板日志可捕获）；CONNECTIONS.md 台账建立
- 2026-09-15：AgentArena fork 建立（mqgg5630-cyber/AgentArena，只含 main，与上游同步——权限障碍解除）
- 2026-09-15：v2.3.5（值守锁 30 分钟过期自愈——进程硬崩后锁残留会让值守永久停摆）
- 2026-09-15：AgentArena 会话开工即验收通过（round 1 accepted `2bcc53b`：文档在位 + npm 冒烟；local-runner 设计文档落仓）
- 2026-09-15：v2.4.0（`agent-wait --auto-accept` / 本机即 Runner 配方 / health.yml 每日体检 / 安装器保留根目录配置）
