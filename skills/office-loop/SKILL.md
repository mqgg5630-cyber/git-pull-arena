# office-loop — 任务无关的「沙箱生成 + 本机判定」自循环

**版本 2.0.0** · 成功案例：`mqgg5630-cyber/git-pull-arena` 分支 `arena/01a0aa00-git-pull-arena`
（round 20–35 全部由用户真机判定）· 架构见 [`ARCHITECTURE.md`](ARCHITECTURE.md) · 移植见 [`PORTING.md`](PORTING.md)

> **这个技能不是"生成 docx/pptx"**。生成 docx/pptx 只是本案的**默认测试任务**。
> 技能本体是：**任务写成配方（recipe）→ 沙箱平面做能做的 → 用户机器做只能在那里做的 → 机器写回执判定 → 不通过就继续改**。

## 1. 它解决什么

| 现实 | 技能里的对应 |
|---|---|
| 任务因仓库而异 | `code/recipes/<id>.json`：沙箱跑什么、本机跑什么、成品回执里必须有哪几个键、证据放哪 |
| 有些必须装到用户机器上，有些在沙箱里做完推上去就行 | 配方把步骤分到 `sandbox` / `local` 两个平面；`plan` 会把"谁在哪里跑"列出来给人和 agent 看 |
| "装好了吗 / 跑得好吗"不能靠沙箱自称 | 只有机器写的回执（`results/status/local_loop_receipt.txt`、`pptmaster_local.txt`、`check_r<N>_*.txt`）算数 |
| 用户机器可能是 Windows，也可能是 Linux | 三个适配器（本机检查 / 本机执行 / 定时触发）各有两套实现，配方与标准不变 |
| 别的会话要复用 | 技能自带 payload；`agent-install.sh` 幂等安装；`--check` 自检；`--refresh-sections` 升级 |

## 2. 装（3 条命令）

```bash
git fetch https://github.com/mqgg5630-cyber/git-pull-arena.git arena/01a0aa00-git-pull-arena
git checkout FETCH_HEAD -- skills/office-loop
bash skills/office-loop/agent-install.sh            # 自动识别 windows/linux；幂等
bash skills/office-loop/agent-install.sh --check     # 装完自检
```

前置：git-sync 桥已通（第 1 轮那个技能）。机器上 python 3.10+；Windows 版另有 Office COM 可选、
Linux 版 LibreOffice 可选（没有就如实 WARN，不假装验过）。

装完 `git push`，机器下一轮就会按配方干活。

## 3. 一轮循环（两个平面）

```bash
python3 code/local_loop.py plan               # ① 先看拓扑：这条任务谁在哪跑、为什么
python3 code/local_loop.py sandbox --apply    # ② 沙箱平面：出成品原件、跑门禁
bash code/check_all.sh                        # ③ 门禁全过（= code/gates.py 的列表）
# ④ commit + push —— 机器值守：pull → code/local_check.* → 回执 + 证据 → push、判定
python3 code/local_loop.py plan               # ⑤ 读 results/status/check_r<N>_*.txt 与回执，不过就回到 ②
```

* **沙箱平面**：快、可重复、失败成本≈0（生成页面/代码/文档、编译、单测、静态检查）
* **本机平面**：装工具链、真 Office/LibreOffice 开档、GUI、许可证、那台机器上的数据/GPU
* 配方 `needs[]` 与每步 `why` 明说为什么要本机 —— 把纯沙箱任务误标成本机需求，`plan` 一眼能看出来

## 4. 换任务 / 换系统 / 换身份（都只动一处）

| 想做的事 | 改什么 | 不动什么 |
|---|---|---|
| 换任务 | 复制 `code/recipes/office-deck.json` 改成自己的；`code/loop.json` 指向它 | runner、门禁、检查脚本、验收标准格式 |
| 纯沙箱任务 | 配方里 `"local": {"skip": "原因"}` | —— runner 照样写 `ok=true` 的统一回执并打印理由 |
| 换成本机安装类任务 | 配方 `local.steps.{windows,linux}` + `local.receipt.keys` | —— ③ 的判定链不变 |
| 换系统 | 三个适配器：`local_check.*` / `<tool>_local.*` / 定时器模板 | 配方、门禁、验收标准、循环命令 |
| 换身份（别的助理 / CI / 人） | 只要四件事：可 push 的分支、能被触发的机器、`handshake.json` 请求、`check_r<N>_*.txt` 判定 | 其余全部 |

细节与首次在新系统上的检查清单：**[`PORTING.md`](PORTING.md)**。

## 5. 每轮推送前后的三件事

```bash
bash code/pull_machine_evidence.sh     # 提交前：把机器推回来的 results/ 换回工作区（白名单，不动标准）
bash code/check_all.sh                 # 推送前：门禁列表（数据驱动，见 code/gates.json）
bash skills/git-sync/scripts/agent-handsfree.sh --sync "…" --request "…"   # 一轮到底 + 自动收尾
```

`results/` 归机器所有：它写回执、证据与日志。沙箱里可能留着旧副本，所以提交前用白名单还原
（round 30 真实踩过：把机器的 `environment=windows` 回执覆盖成了 `sandbox`）。

## 6. 出问题看哪儿

| 症状 | 先看 |
|---|---|
| 门禁失败 | `bash code/check_all.sh` 的输出；每条 gate 的 `why` 说明它防的是什么事故 |
| 轮次 `failed` | `results/status/check_r<N>_*.txt`：`FAIL 3a–3h`（交付物）/ `FAIL 4a–4c`（本机平面） |
| 本机安装失败 | 日志里 `PPTMASTER:`（Windows）/ `PPTMASTER:`（Linux 同前缀）开头的行；`pptmaster_local.json` 的 `problems` |
| 回执键不匹配 | `results/status/local_loop_receipt.json` 的 `checks`：哪个键 want/got 不同 |
| 脚本拒绝跑 | 每次都是**指名**失败（缺 python、目录不是 clone、锚点找不到、结果不平衡）——不会半装 |
| verdict 一直 pending | 桥：值守没跑 / 分支不对 / push 失败（`watch-linux.sh` 会打印 `PUSH FAILED`） |

## 7. 目录

```
skills/office-loop/
  SKILL.md ARCHITECTURE.md PORTING.md CASE_STUDY.md CHANGELOG.md prompts.md VERSION
  agent-install.sh           幂等安装入口
  tools/install.py           安装逻辑（--os / --check / --force / --refresh-sections）
  tools/check_payload.py     payload 与仓库 code/ 的逐字节漂移门禁
  payload/code/              循环本体（runner、门禁、配方、两套适配器、默认任务实现）
  templates/                 deck 配置、Windows 两段 PowerShell、Linux systemd/cron
```

## 8. 这个技能不做的事

* 不替你做决策：**"必须本机"还是"沙箱就够"**永远写在配方里并打印出来，不藏在脚本里。
* 不假装验证：没有 Office/LibreOffice 时 3h/4c 如实 WARN 或 SKIP，结构性检查照跑。
* 不编数据：案例里的鲜味肽 deck 每个数字都标了「示例」；换数据前先换统计口径。
* 不覆盖别人的产物：新任务用自己的 `deck_name` / 项目目录，日志打印 `out before/after` 作证。
