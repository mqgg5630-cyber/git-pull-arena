# 架构：任务无关的两平面自循环（v2）

v1 把「生成 docx/pptx + 本机 PPT Master 出稿」写死在技能里 —— 那只是这个仓库的**默认测试任务**。
v2 把任务抽成**配方（recipe）**，把「谁在哪里执行」抽成**平面（plane）**，于是同一个技能可以驱动任何仓库的任何任务。

```
                      ┌────────────────────────── 一次循环 ──────────────────────────┐
    配方 recipe       │  agent（沙箱）                    machine（用户机器）        │
 code/recipes/*.json  │  ─────────────                    ──────────────────        │
 ┌──────────────────┐ │  ① 读配方 → plan：谁在哪里跑     ⑤ 值守拉取请求              │
 │ sandbox.steps[]  │─┼─►② 沙箱平面：出页/编译/单测     ⑥ 跑 code/local_check.*     │
 │ local.steps{os}  │ │  ③ gates.json 门禁全过           ⑦ 四段判定（下面那个表）    │
 │ local.receipt    │─┼─►④ commit + push  ────────────► ⑧ 写回执 + 证据 + 日志       │
 │ evidence[]       │ │                                   ⑨ push 回  ──────────────►│
 └──────────────────┘ │  ⑩ 读 check_r<N>_*.txt + 回执：过了就收尾，没过就改并回到 ②   │
                      └──────────────────────────────────────────────────────────────┘
```

## 1. 五个概念（都在仓库里，可被别的会话接手）

| 概念 | 文件 | 作用 |
|---|---|---|
| **配方 recipe** | `code/recipes/<id>.json` | 这个仓库的任务是什么：沙箱跑什么、本机跑什么、成品的回执里必须有哪几个键、证据放哪 |
| **默认配方** | `code/loop.json` | 本仓库现在的任务（换任务＝改这一行，不动脚本） |
| **门禁 gates** | `code/gates.json` | push 前必须回答 YES 的便宜问题（pre-commit hook 的思路，无依赖实现） |
| **平面 plane** | 配方里的 `sandbox` / `local` | 「能在这里回答」和「只能在那台机器回答」分开，runner 从不猜 |
| **统一回执** | `results/status/local_loop_receipt.{json,txt}` | 任何任务、任何系统，机器判定结果的同一格式（供 `success_criteria.json` 直接引用） |

```jsonc
// code/recipes/office-deck.json（真实文件，节选）
{ "sandbox": { "steps": [ { "id": "pages", "run": ["{python}", "code/make_deck_umami.py", "--out", "build/pages"],
                            "produces": ["build/pages/*.svg"], "why": "排版错误在这里就该被抓住" } ] },
  "local":   { "steps": { "windows": [ { "run_powershell": "code/pptmaster_local.ps1" } ],
                          "linux":   [ { "run": ["{bash}", "code/pptmaster_local.sh", "--repo", "{repo}"] } ] },
               "receipt": { "file": "results/status/pptmaster_local.txt",
                            "keys": { "deck_slides": "12", "checker_blocking": "0", "markers": "ok" } } },
  "evidence": ["results/umami/DECK_*.pptx", "results/umami/pptmaster_local_quality.json"] }
```

## 2. 谁在哪里跑：判定矩阵（写进配方，不靠人记）

| 事情 | 平面 | 理由 |
|---|---|---|
| 排版 / XML / 静态检查 / 单元测试 / 编译 | **sandbox** | 快、可重复、失败一轮成本≈0 |
| 需要真 Office / COM / 需要装到用户机器 / 需要 GUI / 需要许可证 / 需要那台机器的 GPU 或数据 | **local** | 沙箱里"通过"不等于用户那儿能用 |
| 生成代码、页面、文档内容 | **sandbox** | 产物推到分支即可，机器只需验证 |
| 安装工具链（venv / npm / apt / conda / 克隆仓库） | **local** | 装的是那台机器的环境 |
| 拆包校验、哈希比对、清单核对 | 两边都行，通常 **local**（用真实文件） | 本机拿到的就是用户手里的文件 |

配方 `needs` 字段**明说为什么要本机**（例如 `office-com-or-libreoffice`），`plan` 会打印出来 ——
把一个纯沙箱任务误标成"必须本机"时，人一眼就看得出来。

## 3. 三个可替换的适配器（这就是"换系统 / 换身份"的全部代价）

| 适配器 | Windows（已验证） | Linux / macOS（新，已在沙箱端到端跑通） |
|---|---|---|
| **本机检查** `code/local_check.*` | `local_check.ps1` 四段（3a–3h、4a–4c） | `local_check.sh` 同编号：gates → 交付物 3a–3g → **3h LibreOffice headless** → 配方本机平面 4a → 统一回执 4b/4c |
| **本机执行** | `pptmaster_local.ps1`（真实 powershell.exe、注册表/PATH/conda 找 python、venv、COM 开档） | `pptmaster_local.sh`（候选 python + `--version` 探测、clone、venv、`soffice --headless` 开档、`make-deck.sh`） |
| **值守（定时触发）** | 计划任务 `git-sync-watch-<folder>`（git-sync 桥） | `watch-linux.sh` + **systemd --user timer** 或 **cron**（模板在 `templates/`） |

三者接口相同：**拉请求 → 跑 `code/local_check.*` → 把 verdict 与证据 push 回分支**。
所以"本地是 Linux"要改的只是这三件，仓库里的配方、门禁、验收标准、循环命令都不变（见 `PORTING.md`）。

## 4. 从高 star 仓库借来的做法（这里怎么落地）

| 做法出处 | 借来的点 | 本技能的落地 |
|---|---|---|
| **pre-commit**（多语言、极广） | hook 列表是数据，不是脚本；severity 决定是否阻断 | `code/gates.json` + `code/gates.py`：新增门禁＝加一条 JSON，`severity: block/warn`、`plane: sandbox/local` |
| **Taskfile / Just** | 一个稳定入口（`task` / `just`）跑任意子任务 | `bash code/check_all.sh` 是唯一记忆入口；`python3 code/local_loop.py {plan,sandbox,local,gates}` 是任务无关的 runner |
| **GitHub Actions** | job/step 声明式、artifact 显式、matrix 化 | 配方 = job，step = step，`evidence[]` = artifact，`{os}` 分支 = matrix；日志与 `results/status/loop_plan.json` 就是 run log 与 plan |
| **devcontainer / Nix / conda env spec** | 环境是可复现声明，带 idempotent setup | `install_dir` + venv + `deps` 步骤幂等；`make-deck.sh` / `make-deck.cmd` 是人用入口 |
| **Dagger / Earthly**（容器化流水线） | 同一流水线在多执行器上跑，接口一致 | 同一配方在 sandbox / windows / linux 三个执行器上跑；不同系统只换适配器 |
| **12-factor / keep receipts** | 配置与代码分离、状态可观测 | 配方/门禁是配置；回执（`pptmaster_local.txt`、`local_loop_receipt.*`、`gates.json`、`loop_plan.json`）是状态 |

**刻意不借的**：不改用 YAML（要额外依赖，机器上可能装不上；JSON 零依赖）、不引入容器（用户机器上要真的用 Office/GPU）、不引入编排服务（必须离线可跑、git 就是消息总线）。

## 5. 判定的权威链（谁说了算）

```
success_criteria.json            ← 复述"用户要什么"，任何文件都能断言
        ↑ 由 agent 写
results/status/local_loop_receipt.txt   ← 统一回执：recipe=… os=… ok=true deck_slides=12(/12) opened=yes
        ↑ 由 local_loop.py 在机器上写
results/status/pptmaster_local.txt / check_r<N>_*.txt   ← 任务自己的回执 + 该轮完整日志
        ↑ 由 local_check.* 在机器上写
```
三层都不在沙箱里产生。agent 能做的只是**让沙箱里的门禁先过**，以及读回执修问题。

## 6. 失败怎么定位（每一层都有归属）

| 现象 | 层 | 归属 |
|---|---|---|
| `gates: N blocking failure(s)` | 沙箱门禁 | 改代码，push 前就该消失 |
| `check_r<N> … failed` 且日志里 `FAIL 3a–3h` | 交付物 | 重新生成/推送产物，或清单与实际不一致 |
| `FAIL 4a` | 本机平面 | 装/依赖/脚本；日志里 `PPTMASTER:` 行给出原因 |
| `4b` 键不匹配 | 配方回执契约 | 产物没到预期（12 页？0 blocking？），或配方写错 |
| `4c` | 真应用 | Windows：PowerPoint COM；Linux：LibreOffice headless；两边的三态都写进日志 |
| verdict 一直 `pending` | 桥 | 值守没在跑 / 分支不对 / push 失败（`watch-linux.sh` 会打印 `PUSH FAILED`） |
