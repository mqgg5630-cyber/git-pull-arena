# 把 PPT Master 装进本机（并且由本机自己证明装好了）

这一轮（round 25）做的事：**不只在沙箱里用 ppt-master，而是把它装到你的 Windows 机器上**，
然后让机器**自己生成一份 deck 并自己验证**，验证结论推回本分支——整件事都在自循环里完成。

沙箱永远够不到你的电脑，所以"装进本地"只能这么做：把安装器 + 验证器写进仓库，
值守（计划任务 `git-sync-watch-git-pull-arena-01a0aa00`）在下一轮拉到它、按它执行、
把回执推回来。下面的数字和路径都是脚本里确定的，机器执行时会写进
`results/status/pptmaster_local.json`（回执）与 `results/status/check_r25_*.txt`（日志）。

## 1. 装到哪里

| 项 | 位置 / 内容 |
|---|---|
| 工具本体 | `E:\0github\git-sync\ppt-master`（`git clone --depth 1`，v6.4.0，MIT） |
| Python 环境 | `<工具目录>\.venv`（用本机 python 3.10+ 建，依赖装在 venv 里，不动 conda base） |
| 依赖（核心） | PyYAML · python-pptx · XlsxWriter · skia-pathops · uharfbuzz · Pillow · numpy |
| 依赖（可选） | `pip install -r requirements.txt` 的其余部分（PDF/网页/配音等工具用），装了更好，失败不影响出稿 |
| 一键入口 | `E:\0github\git-sync\ppt-master\make-deck.cmd`（双击＝在本机重跑一遍出稿并打开成品） |
| 安装状态 | `<工具目录>\.git-sync-install.json`（记录 commit + 依赖状态，后续轮次不会重复装） |

不动的东西：`git-pull-arena*` 那些克隆目录、conda base、系统 Python。
安装目录不存在才创建；克隆中途失败时只删自己刚建的那半个目录。

## 2. 谁在什么时候装

`code/pptmaster_local.ps1`（安装器 + 验证器）被写进了本机检查脚本
`code/local_check.ps1` 的第 4 节，所以**每一轮验证都会跑它**：

```
值守 pull 最新提交
  └─ code/local_check.ps1
       ├─ 1.  仓库闸门（.ps1 全 ASCII、分支一致…）
       ├─ 2.  静默推送 / 值守窗口 / 收尾行 / hands-free 2a–2d
       ├─ 3.  7 份交付物 3a–3h（含真 Word / PowerPoint 只读开档）
       ├─ 4.  ppt-master：本机安装 + 本机出稿 + 本机验证   ← 本轮新增
       └─ 成功标准 results/status/success_criteria.json 逐条验
```

第 4 节又分两层：

```
code/pptmaster_local.ps1   找 git / 找 python / 建 venv / pip 装依赖 / 开 PowerPoint
      └─ code/pptmaster_pipeline.py   归因闸门 → 出 12 页 SVG → 质检 → 导出 → 验包
```

`pptmaster_pipeline.py` 是纯 Python、只用标准库，沙箱和本机跑的是**同一份代码**，
所以"沙箱里通过"和"本机通过"不是两套标准。

## 3. 本机到底验证了什么

| 断言 | 怎么做 |
|---|---|
| 装好了 | 克隆 + venv + pip 真的跑完；`attribution_guard.py`（ppt-master 自带的强制闸门）exit 0 |
| 依赖齐了 | 在 venv 里 import `yaml / pptx / xlsxwriter / pathops / uharfbuzz / PIL / numpy` 并记录版本 |
| 能出稿 | 用**本仓库的生成器**写 12 页 canonical SVG → `compact_svg_styles` → `svg_quality_checker`（要求 0 blocking / 0 error）→ `svg_to_pptx` 导出原生 DrawingML |
| 稿子是好的 | 自己再拆包验一遍：zip 完整、40 个部件、12 页、XML 全部可解析、关系目标都能解析、内容类型齐全、7 个标记词都在；再跑 ppt-master 自带的 `pptx_delivery_check.py`（要求 errors=0） |
| 打开没问题 | **真 PowerPoint**（COM，只读）打开本机刚生成的那份 pptx，读回页数＝12 |
| 证据留存 | 回执 `results/status/pptmaster_local.json` + 一行式 `pptmaster_local.txt`（`deck_slides=12 checker_blocking=0 markers=ok powerpoint=yes`），值守自动 push 回本分支 |

`local_check.ps1` 再读这两个回执做 4a/4b/4c 判定：缺任何一个断言 → 这一轮 verdict = failed，
日志里会指名道姓说是哪一条（比如 `4b receipt is missing deck_slides=12`）。

## 3b. 换主题：这份回执现在描述的是哪一套 deck

出稿的主题不写死在这份文档里，而是写在 **`code/pptmaster_deck.json`**（`generator` / `project` /
`deck_name` / `evidence_dir` / `markers`）。`pptmaster_pipeline.py`、`pptmaster_local.ps1`
和 `make-deck.cmd` 都读它，所以换主题＝改这一个文件，别的都不动：

| 字段 | 现在的值 | 含义 |
|---|---|---|
| `generator` | `code/make_deck_umami.py` | 12 页 SVG 的生成器（机器学习筛选鲜味肽） |
| `project` | `umami-01a0aa00` | ppt-master 项目名（实际目录会带日期后缀）；**和上一套 deck 的项目目录不同** |
| `deck_name` | `DECK_umami_01a0aa00_v1.pptx` | 本机 `out\` 里的成品名；不会覆盖旧的 `DECK_local_*.pptx` |
| `evidence_dir` | `results/umami` | 质检报告、页源、成品 pptx 回传到仓库的位置 |
| `markers` | `鲜味肽` / `umami` / `T1R1` / `make-deck.cmd` | 拆包校验时必须出现的字符串 |

页面的公共框架在 `code/deck_kit.py`（画布、token、转义、`data-pptx-bounds` 规则、
XML/重叠自检 + runner），两套 deck 共用；`code/deck_layout_selftest.py` 会把**每一套**
deck 在包括 round-28 机器状态在内的极端输入下全部跑一遍，作为每次 push 前的门禁。
鲜味肽那套页面上所有数字都标了 **示例** —— 仓库里没有肽数据集，所以页面明说是占位，
而不是编造实验数据。

## 4. 手工怎么用（装好之后，你自己随时可以用）

```powershell
# 双击就行（重跑一遍出稿并打开成品）
E:\0github\git-sync\ppt-master\make-deck.cmd

# 或者命令行：按 code\pptmaster_deck.json 重建整套（这一步就是自循环每轮跑的东西）
$pm = 'E:\0github\git-sync\ppt-master'
$py = "$pm\.venv\Scripts\python.exe"
$repo = 'E:\0github\git-sync\git-pull-arena-01a0aa00'
& $py "$repo\code\pptmaster_pipeline.py" --ppt-master $pm --python $py --repo $repo --environment windows --host $env:COMPUTERNAME --python-mode venv

# 想只想手工走一遍底层四步（换主题时改的是 --out 里的页源生成器）：
& $py "$pm\skills\ppt-master\scripts\project_manager.py" init my-deck --quick-generate
& $py "$repo\code\make_deck_umami.py" --out "$pm\projects\my-deck\svg_output"
& $py "$pm\skills\ppt-master\scripts\svg_quality_checker.py" "$pm\projects\my-deck" --quick-generate --canonical-authoring --stage final --json
& $py "$pm\skills\ppt-master\scripts\svg_to_pptx.py" "$pm\projects\my-deck" --quick-generate --no-notes -o "$pm\out\my-deck.pptx"

# 重新验证安装（不装新的东西）
powershell -NoProfile -ExecutionPolicy Bypass -File 'E:\0github\git-sync\git-pull-arena-01a0aa00\code\pptmaster_local.ps1' -SkipInstall

# 升级工具本体（浅克隆的 fetch + reset）
powershell -NoProfile -ExecutionPolicy Bypass -File '...\code\pptmaster_local.ps1' -Update
```

## 5. 失败会怎样

第 4 节任何一条不过 → 这一轮 `verdict = failed`，`results/status/check_r25_*.txt` 里带着
`PPTMASTER:` 开头的完整输出（pip 报错、质检 blocking、PowerPoint 拒绝打开…），
状态文件同时推回本分支；我读到之后就是修脚本、再跑一轮，直到它通过为止 —— 这就是"自循环验证装成功没有"。

安装是幂等的：装好之后，后续每一轮只花出稿 + 验证的时间（沙箱里实测约 3–8 秒，
本机多一个 PowerPoint 开档）。
