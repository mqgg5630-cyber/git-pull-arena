# DECK 构建记录 —— PPT Master v6.4.0（session 01a0aa00）

这一轮用户要求「用 ppt master 重新生成好看的 pptx」，并作为自循环任务的测试。
本文件记录实际跑过的流水线、每一步的真实输出、以及本机判定结果。

## 1. 用了什么

| 项 | 值 |
|---|---|
| 工具 | [hugohe3/ppt-master](https://github.com/hugohe3/ppt-master) v6.4.0（MIT），路由：Generate PPTX → ordinary **explicit Quick** |
| 画布 | 1280 × 720（PPT 16:9），12 页 |
| 视觉 | dark-tech 风格：深底 + 冷色发光强调 + 等宽小标签（Windows PowerPoint 目标字体：Microsoft YaHei / Consolas） |
| 产物 | `deliverable/DECK_01a0aa00_v2.8.1.pptx`（原生 DrawingML 形状，非图片版） |
| 源 | `code/make_deck_pptmaster.py` → 12 个 canonical SVG 页 |

## 2. 实际执行的命令（沙箱内）

```bash
git clone --depth 1 https://github.com/hugohe3/ppt-master.git /tmp/ppt-master
python3 -m venv /tmp/venv-ppt
/tmp/venv-ppt/bin/pip install PyYAML "python-pptx>=0.6.21" XlsxWriter \
    "skia-pathops>=0.9.2" "uharfbuzz>=0.50.0" "Pillow>=9.0.0" "numpy>=1.20.0"

# 完整性闸门（技能自带）
/tmp/venv-ppt/bin/python /tmp/ppt-master/skills/ppt-master/scripts/attribution_guard.py     # exit 0

# 1) 建项目
/tmp/venv-ppt/bin/python /tmp/ppt-master/skills/ppt-master/scripts/project_manager.py \
    init arena-loop-01a0aa00 --quick-generate
# -> projects/arena-loop-01a0aa00_20260916（svg_output/ + validation/workflow.log）

# 2) 写 SVG（本仓库的生成器，12 页）
/tmp/venv-ppt/bin/python code/make_deck_pptmaster.py \
    --out /tmp/ppt-master/projects/arena-loop-01a0aa00_20260916/svg_output

# 3) 规范化 + 质检（Quick 的强制闸门）
/tmp/venv-ppt/bin/python /tmp/ppt-master/skills/ppt-master/scripts/compact_svg_styles.py \
    <project>/svg_output --inplace
/tmp/venv-ppt/bin/python /tmp/ppt-master/skills/ppt-master/scripts/svg_quality_checker.py \
    <project> --quick-generate --canonical-authoring --stage final --json

# 4) 导出（原生形状，无讲稿）
/tmp/venv-ppt/bin/python /tmp/ppt-master/skills/ppt-master/scripts/svg_to_pptx.py \
    <project> --quick-generate --no-notes -o deliverable/DECK_01a0aa00_v2.8.1.pptx
```

## 3. 真实输出（不是概括）

```
compact_svg_styles : {"file_count": 12, "changed_files": 2, ...}
svg_quality_checker: Total files: 12 | [OK] Fully passed: 9 | [WARN] With warnings: 3 | [ERROR] 0
                     blocking: 0 hard findings
svg_to_pptx        : 12 slides, "Flat structure: project-owned Master + Blank Layout"
                     [POSTFLIGHT] status=passed-with-warnings quality_gate=passed slides=12
                     0 pictures · 0 skipped elements · every page Native
```

包内自检（沙箱，同一套 3a–3g 的 Python 镜像）：

```
OK deliverable/DECK_01a0aa00_v2.8.1.pptx (46582 B, pptx, slides=12)
   40 parts · 12 slides · 首页 20 个形状 / 11 个文本框 / 0 张图片
```

## 4. 迭代过的两处（闸门真抓到了东西）

| 轮次 | 闸门发现 | 修法 |
|---|---|---|
| 第 1 次质检 | 4 个文件 **blocking**：可见的根级 `<g>` 没有 `data-pptx-bounds` | 按语义分组契约重写生成器：每个逻辑单元一个 `<g id data-pptx-bounds>`，静态装饰改成带 `data-pptx-role` 的根原语 |
| 第 2 次质检 | 3 个文件 **blocking**：文本超出所属分组的 bounds（竖排 11.3% / 横排 8.5%） | 按实测文本盒调整分组的 y/高度，并把「真机数据」页的柱状图与 host 模块错开，保证分组互不重叠 |
| 第 3 次质检 | 0 blocking，3 条 advisory | 先跑 `compact_svg_styles.py --inplace`，再重跑质检 → 9/12 完全通过 |

## 5. 本机侧

`deliverable/OFFICE_HASHES.json` 现在声明 **7 份产物**（其中 DECK 由 `--add-artifact` 注册，
必需部件按包内实际名字推导，不写死）。本机值守会在这一轮里对 7 份文件跑
3a–3h：哈希/字节、OOXML 部件、XML 解析、关系、内容类型、标记词、页数，
以及**真 PowerPoint 只读开档**（DECK 要求 ≥12 页）。结论与完整日志推回本分支。
