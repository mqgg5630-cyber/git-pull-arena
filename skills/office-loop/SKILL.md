# office-loop — 本机生成 + 本机判定的 docx / pptx 自循环技能

**版本 1.0.0** · 成功案例来源：`mqgg5630-cyber/git-pull-arena` 分支
`arena/01a0aa00-git-pull-arena`（round 20–32 全部由用户真机判定，见 `CASE_STUDY.md`）

一句话：把「生成 Office 文件 → 推到会话分支 → **用户的 Windows 机器自己打开检查** →
状态推回来 → 不合格就继续改」这套循环，装进任何一个 Arena 会话仓库。

技能只做两件事，两件都在**用户真机**上执行，沙箱里看到的任何"通过"都不算数：

| 半 | 装什么 | 在机器上跑什么 | 判什么 |
|---|---|---|---|
| Office 交付物 | `deliverable/OFFICE_HASHES.json` 驱动 | `code/local_check.ps1` 第 3 段 | 3a–3h：sha256/大小一致、OOXML 部件齐全、XML 可解析、关系目标能解析、内容类型覆盖、标记词、`min_slides`，最后用**真 Word / 真 PowerPoint**（COM，只读）开档 |
| PPT Master 本机出稿 | `code/pptmaster_*.{py,ps1}` + `code/deck_kit.py` + 页源生成器 | `code/local_check.ps1` 第 4 段 → `code/pptmaster_local.ps1` | 4a 出稿管线（克隆 ppt-master、建 venv、装依赖、写 12 页、`svg_quality_checker`、`svg_to_pptx`、拆包复检、`pptx_delivery_check`、真 PowerPoint 开档）＋ 4b 回执断言 ＋ 4c 开档判定 |

## 1. 前置条件

1. **git-sync 桥已装好**（第 1 轮对话装的那个 skill）：本机有定时值守任务、仓库能被 pull/push。
   本技能靠它把 `results/status/*` 从机器推回来 —— 没有桥，4a/4b/4c 的结果就回不来。
2. 机器是 Windows + PowerShell 5.1（模板就是按它写的，全部 ASCII）。
3. Word / PowerPoint 可选：装了才有 3h / 4c 的"真开档"，没装会降级成 `WARN … SKIP`，结构性检查照跑。
4. python 3.10+（机器上的 conda base 即可；`pptmaster_local.ps1` 会自己从 PATH / conda /
   硬件报告 / 注册表里找到并验证它，找不到就 FAIL 并列出试过的候选）。

## 2. 安装（3 条命令）

```bash
# 1) 把技能目录拿进你的会话仓库（示例：直接从这个成功案例的分支取）
git fetch https://github.com/mqgg5630-cyber/git-pull-arena.git \
    arena/01a0aa00-git-pull-arena
git checkout FETCH_HEAD -- skills/office-loop

# 2) 安装进当前仓库（会复制代码、插入 local_check 两段、合并验收标准、跑版面自检）
bash skills/office-loop/agent-install.sh

# 3) 自检 + 提交
bash skills/office-loop/agent-install.sh --check
bash code/check_all.sh && git add -A && git commit -m "install: office-loop v1.0.0"
```

安装器是**幂等**的（重复跑安全），并且它**从不猜**：找不到插入点、找不到 python、源文件缺失，
都会指名报错退出，不会留下半装状态。它会写 `results/status/office_loop_install.{json,txt}`
作为安装回执。

### 换主题（换 deck 的内容）

只改 `code/pptmaster_deck.json`：

```json
{
  "generator": "code/make_deck_umami.py",     // 你自己的 12 页页源生成器
  "project": "umami-01a0aa00",                // ppt-master 项目名（独立目录）
  "deck_name": "DECK_umami_01a0aa00_v1.pptx", // 本机 out\ 里的成品名（不要用别人的名字）
  "evidence_dir": "results/umami",            // 成品/质检报告/页源回传到哪
  "markers": ["鲜味肽", "umami"],              // 拆包校验必须出现的词
  "expect_slides": 12
}
```

`pptmaster_pipeline.py`、`pptmaster_local.ps1`、`make-deck.cmd` 全读这个文件。
页面的公共框架在 `code/deck_kit.py`（画布 / token / 转义 / `data-pptx-bounds` 规则 / XML 与模块框重叠自检），
换主题时**照抄一份 `make_deck_umami.py` 改内容**即可，不要动 kit。

## 3. 一轮循环发生了什么

```
你（对话里）改页源 → 提交 + 推送
        ↓ 值守任务 pull
用户机器：code/local_check.ps1
        3a–3h 拆包验一遍 deliverable/*.docx|pptx + 真 Word/PowerPoint 开档
        4a  pptmaster_local.ps1：没有就装 ppt-master（venv + pip），然后
            写页 → svg_quality_checker（要求 0 blocking）→ svg_to_pptx
            → 拆包复检 → pptx_delivery_check → 真 PowerPoint 只读开档
        4b  回执断言 environment=windows / deck_slides=N / checker_blocking=0 / markers=ok
        4c  powerpoint=yes|na|no 三态判定
        ↓ 自动 push
你（对话里）：读 results/status/check_r<round>_*.txt，不合格就改，合格就收尾
```

**判定权在机器**：`check_r<round>_*.txt` 里 4a/4b/4c 全 OK 才算过；
回执是 `results/status/pptmaster_local.txt`，一行一个断言，方便直接 grep。

## 4. 每一次改动的门禁（沙箱里就该拦住的问题）

`code/check_all.sh` 在每次 push 前跑，技能装进去后它会多两件：

* `code/deck_layout_selftest.py`：把仓库里**每一套** deck 的 12 页，在包括
  "round-28 机器状态"（日志只到 R27 导致柱子长进 KPI 行、checker blocking=2）和
  极端/空值输入下全部重算，断言"XML 良构 + 两个根模块框不重叠"——
  这正是唯一一次真机翻车的原因，现在在沙箱里就报错。
* 生成器自己也会在写页之后立刻做同样的断言（`deck_kit.run`），写坏页直接 exit 2。

## 4b. 每次 push 的三道门禁（都在沙箱里跑，别让机器替你发现）

```
bash code/check_all.sh                       # ASCII / 分支 / 脚本一致 / 循环收尾 / 版面自检 /
                                             # payload 漂移 / 验收标准里的字符串是否真的存在
python3 code/deck_layout_selftest.py         # 单独跑：每套 deck × 机器 round-28 状态 + 极端输入
python3 code/check_criteria_needles.py       # 单独跑：criteria 里的 needle 能不能在仓库里找到
```

`check_criteria_needles.py` 是 round 33 用一次真机失败换来的：那一轮 4a/4b/4c 全绿，
却因为验收标准里写了 `'round 28'`、而文件里是 `round-28`，整轮被判 failed。

## 4c. 每轮推送前后的两条命令（round 30 的教训）

```bash
bash code/pull_machine_evidence.sh    # 提交前：把 results/ 换回机器推回来的那份
bash skills/git-sync/scripts/agent-handsfree.sh --sync "…" --request "…"
```

`results/` 归机器所有：它写日志、回执、质检报告、成品并 push 回来，而沙箱工作区里可能还留着
**自己那次的旧副本**。round 30 就是这样把机器写的 `environment=windows` 回执覆盖掉的
（`agent-check.sh --accept` 现在也会先还原 `results/`）。升级已装好的技能用：

```bash
bash skills/office-loop/agent-install.sh --refresh-sections   # 只替换两段，先自动备份
```

## 5. 出问题时看哪儿

| 症状 | 先看 |
|---|---|
| 轮次 verdict=failed | `results/status/check_r<round>_*.txt` 里 `FAIL 4a/4b/4c` 那几行 |
| 4a 报 python 找不到 | 同一份日志里 `PPTMASTER: [FAIL] no python 3.10+ found; tried N candidate(s)` 列表；`probe <exe> -> exit N : <detail>` 会指名失败原因 |
| checker 拒绝某页 | `results/<evidence_dir>/pptmaster_local_quality.json`（完整报告）+ `svg/`（机器上那 12 页原文）+ `pptmaster_local_checker.log` |
| 机器上的回执被沙箱覆盖 | 收尾提交用 `agent-check.sh --accept`；它现在会先 `git checkout <origin> -- results`（机器拥有 `results/`） |
| 想人工重跑 | 机器上双击 `<repo parent>\ppt-master\make-deck.cmd` |

## 6. 这个技能**不**做什么

* 不代替 git-sync 桥（第 1 轮那个）：没有值守任务就没有真机判定。
* 不保证内容正确：页面上的数字要靠你自己的数据源；成功案例里的鲜味肽 deck 每个数字都标注了
  **示例**，因为那个仓库里没有肽数据集 —— **宁可标占位，也不要编数据**。
* 不碰别人已生成的成品：deck 名与项目目录独立（`out before/after` 会写进日志，证明旧文件没被改）。
