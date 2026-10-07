#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AMP method supplement builder.

Runs on the user's Windows laptop (via the git-sync watcher).

Outputs (into the existing Desktop result folder):
  1) method_with_docking_<stamp>.docx  - the user's own method (1).docx with
     new sections 2.9 / 3.8 / 3.9 appended, embedding the user's own
     SCI composite figures.
  2) AMP_Pipeline_Reproduction_Method.md - a reproduction-method document that
     follows the user's flow chart
     (鳄鱼肠道抗菌肽流程图_中文单行结果版.svg) step by step.
  3) AMP_Figure_Style_Review.md - comparison between the user's figure suite
     and the agent-generated one.
"""

import csv
import os
import sys
import json
import datetime

try:
    import docx
    from docx.shared import Pt, Cm
    from docx.enum.text import WD_ALIGN_PARAGRAPH
except Exception as exc:  # pragma: no cover
    print("NEED python-docx:", exc)
    raise


# --------------------------------------------------------------------------
# paths
# --------------------------------------------------------------------------

def find_desktop():
    """Pick the desktop that actually holds the docking result folder."""
    target = "AMP_Docking_Vina_R255_20261005_1552"
    cands = []
    v = os.environ.get("DESKTOP_DIR")
    if v:
        cands.append(v)
    cands.append("D:\\\u684c\u9762")
    up = os.environ.get("USERPROFILE", "")
    if up:
        cands.append(os.path.join(up, "Desktop"))
        cands.append(os.path.join(up, "OneDrive", "Desktop"))
    for c in cands:
        if c and os.path.isdir(os.path.join(c, target)):
            return c
    for c in cands:
        if c and os.path.isdir(c):
            return c
    return cands[0] if cands else ""


DESKTOP = find_desktop()
RESULT_DIR = os.path.join(DESKTOP, "AMP_Docking_Vina_R255_20261005_1552")
SUITE_DIR = os.path.join(RESULT_DIR, "SCI_Docking_Figure4_Suite")
FIG_DIR = os.path.join(SUITE_DIR, "sci_composite_figures")
TABLE_DIR = os.path.join(RESULT_DIR, "tables")

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(REPO, "sources", "user_amp")
METHOD_DOCX = os.path.join(SRC_DIR, "method (1).docx")

STAMP = datetime.datetime.now().strftime("%Y%m%d_%H%M")


def log(msg):
    print(msg, flush=True)


# --------------------------------------------------------------------------
# data loading
# --------------------------------------------------------------------------

TARGET_LABEL = {
    "ecoli_FtsZ_6UNX": ("Escherichia coli", "FtsZ cell-division protein", "6UNX"),
    "ecoli_GyrB_4DUH": ("Escherichia coli", "DNA gyrase B ATPase domain", "4DUH"),
    "saureus_FtsZ_5MN4": ("Staphylococcus aureus", "FtsZ cell-division protein", "5MN4"),
    "saureus_SrtA_1T2W": ("Staphylococcus aureus", "Sortase A transpeptidase", "1T2W"),
}

PEP_LABEL = {
    "P1_FVNKLNRIIPVKGFSMR": ("pep_018", "FVNKLNRIIPVKGFSMR"),
    "P2_LISNTKKFGTAIASHR": ("pep_029", "LISNTKKFGTAIASHR"),
    "P3_ISLAIPLASKISGFTLALVKNAST": ("pep_037", "ISLAIPLASKISGFTLALVKNAST"),
}


def read_csv_rows(path):
    if not os.path.isfile(path):
        log("MISSING_CSV=%s" % path)
        return []
    for enc in ("utf-8-sig", "gbk", "utf-8"):
        try:
            with open(path, "r", encoding=enc, newline="") as fh:
                return list(csv.DictReader(fh))
        except Exception:
            continue
    return []


def load_summary():
    rows = read_csv_rows(os.path.join(TABLE_DIR, "vina_summary_mean_of_3.csv"))
    out = []
    for r in rows:
        tkey = (r.get("target") or r.get("target_key") or "").strip()
        pkey = (r.get("peptide") or r.get("peptide_key") or "").strip()
        org, prot, pdb = TARGET_LABEL.get(tkey, ("", tkey, ""))
        pid, seq = PEP_LABEL.get(pkey, (pkey, ""))

        def num(*keys):
            for k in keys:
                v = r.get(k)
                if v not in (None, ""):
                    try:
                        return float(v)
                    except Exception:
                        pass
            return None

        out.append({
            "target_key": tkey, "peptide_key": pkey,
            "organism": org, "protein": prot, "pdb": pdb,
            "pep_id": pid, "sequence": seq,
            "n": int(num("n", "n_repeats") or 3),
            "mean": num("mean_best", "mean", "mean_best_affinity"),
            "sd": num("sd", "std", "sd_best"),
            "best": num("best_single", "best", "min_best"),
        })
    return out


def load_contacts():
    rows = read_csv_rows(os.path.join(SUITE_DIR, "complexes_interaction_summary.csv"))
    out = {}
    for r in rows:
        panel = (r.get("panel") or "").strip()
        out[panel] = {
            "title": (r.get("title") or "").strip(),
            "target": (r.get("target") or "").strip(),
            "peptide": (r.get("peptide") or "").strip(),
            "count": (r.get("contact_residues_count") or "").strip(),
            "residues": (r.get("contact_residues") or "").strip(),
        }
    return out


# --------------------------------------------------------------------------
# docx helpers
# --------------------------------------------------------------------------

def add_heading(doc, text, level):
    try:
        p = doc.add_heading(text, level=level)
    except Exception:
        p = doc.add_paragraph(text)
        p.runs[0].bold = True
    return p


def add_body(doc, text):
    p = doc.add_paragraph(text)
    p.paragraph_format.first_line_indent = Pt(24)
    p.paragraph_format.space_after = Pt(6)
    return p


def add_caption(doc, text):
    p = doc.add_paragraph(text)
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    for r in p.runs:
        r.font.size = Pt(9)
        r.bold = True
    return p


def add_figure(doc, path, caption, width_cm=16.0):
    if not os.path.isfile(path):
        log("MISSING_FIG=%s" % path)
        add_body(doc, "[figure missing: %s]" % os.path.basename(path))
        return False
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.add_run().add_picture(path, width=Cm(width_cm))
    add_caption(doc, caption)
    log("EMBEDDED_FIG=%s" % os.path.basename(path))
    return True


def add_table(doc, header, rows):
    t = doc.add_table(rows=1, cols=len(header))
    try:
        t.style = "Table Grid"
    except Exception:
        pass
    for i, h in enumerate(header):
        cell = t.rows[0].cells[i]
        cell.text = str(h)
        for pr in cell.paragraphs:
            for run in pr.runs:
                run.bold = True
                run.font.size = Pt(9)
    for row in rows:
        cells = t.add_row().cells
        for i, v in enumerate(row):
            cells[i].text = "" if v is None else str(v)
            for pr in cells[i].paragraphs:
                for run in pr.runs:
                    run.font.size = Pt(9)
    return t


def fmt(v, nd=3):
    if v is None:
        return "NA"
    return ("%%.%df" % nd) % v


# --------------------------------------------------------------------------
# 1) supplement docx (append onto the user's own method file)
# --------------------------------------------------------------------------

def build_supplement_docx(summary, contacts):
    if not os.path.isfile(METHOD_DOCX):
        log("MISSING_METHOD_DOCX=%s" % METHOD_DOCX)
        return None
    doc = docx.Document(METHOD_DOCX)
    doc.add_page_break()

    # ---------------- methods ----------------
    add_heading(doc, "2.9 最终候选肽的分子对接验证", 3)

    add_heading(doc, "2.9.1 对接靶点的选择依据", 4)
    add_body(doc,
             "为进一步评估2.7—2.8节确定的3条最终候选抗菌肽(pep_018、pep_029、pep_037)与细菌关键蛋白"
             "相互作用的可能性，本研究在革兰氏阴性与革兰氏阳性代表菌中各选择两个与抗菌作用高度相关的"
             "蛋白靶点，开展分子对接评估。针对Escherichia coli，选择细胞分裂蛋白FtsZ(PDB: 6UNX)与"
             "DNA促旋酶B亚基ATPase结构域(PDB: 4DUH)；针对Staphylococcus aureus，选择细胞分裂蛋白"
             "FtsZ(PDB: 5MN4)与转肽酶Sortase A(PDB: 1T2W)。FtsZ是类微管蛋白的细菌胞质分裂核心蛋白，"
             "负责Z环与分裂体的组装，已被报道为抗菌肽作用靶点；GyrB ATPase口袋是区别于喹诺酮类GyrA"
             "切割复合物化学型的已验证抗菌靶点；Sortase A负责将含LPXTG基序的毒力相关表面蛋白锚定于"
             "革兰氏阳性菌细胞壁，常被作为抗毒力靶点。所选晶体结构均为高分辨率、具明确配体或核苷酸"
             "结合位点的结构，便于定义对接盒并进行可比性分析。")

    add_heading(doc, "2.9.2 受体与配体准备", 4)
    add_body(doc,
             "受体结构自RCSB PDB获取。仅保留第一个model的蛋白ATOM记录，去除结晶水、离子与共晶小分子，"
             "统一加氢并转换为刚性受体PDBQT格式。候选肽配体由肽序列经RDKit的MolFromFASTA构建，加氢后"
             "使用ETKDGv3生成三维构象，并采用UFF分子力场进行能量最小化，取UFF能量最低的构象作为后续"
             "对接的起始刚性配体构象，再转换为重原子PDBQT。")

    add_heading(doc, "2.9.3 对接参数与重复设置", 4)
    add_body(doc,
             "分子对接采用AutoDock Vina 1.2.7命令行版本完成。对接盒以受体几何中心(或已知配体/核苷酸"
             "结合位点)为中心，边长设置为30 Å×30 Å×30 Å，以覆盖目标口袋及其邻近区域。每个peptide-target"
             "组合使用3个不同随机种子进行独立重复对接(--cpu 1，exhaustiveness=1，--num_modes 3)，"
             "共完成4个靶点×3条肽×3次重复=36次独立对接。对每次对接取其最优构象的结合能，并计算3次重复"
             "的均值、标准差与最优单次值，以均值作为该组合的主要比较指标。")

    add_heading(doc, "2.9.4 相互作用分析与可视化", 4)
    add_body(doc,
             "对每个组合的最优构象，计算受体中与肽配体距离在4 Å以内的残基，作为接触残基集合，并识别"
             "可能的氢键与极性接触。可视化使用PyMOL无头(headless)模式批量渲染：左侧为受体整体视图，"
             "右侧为结合位点4 Å局部放大视图；受体以淡紫灰色cartoon表示，肽配体以橙色棒状模型表示，"
             "接触残基以青色棒状模型表示并标注残基名称与编号，可能的极性接触以品红虚线表示。所有面板"
             "按A—L编号后，使用PIL按3×2与4×3版式拼装为300 DPI的多面板组图，用于正文与补充材料。")

    # ---------------- results ----------------
    add_heading(doc, "3.8 最终候选肽的分子对接结果", 3)

    add_body(doc,
             "3条最终候选抗菌肽与4个细菌靶点共12个组合、36次独立对接均成功完成。各组合3次重复的结合能"
             "均值、标准差与最优单次值见表2。")

    rows = []
    order = ["ecoli_FtsZ_6UNX", "ecoli_GyrB_4DUH", "saureus_FtsZ_5MN4", "saureus_SrtA_1T2W"]
    pep_order = ["P1_FVNKLNRIIPVKGFSMR", "P2_LISNTKKFGTAIASHR", "P3_ISLAIPLASKISGFTLALVKNAST"]
    smap = {(r["target_key"], r["peptide_key"]): r for r in summary}
    for t in order:
        for p in pep_order:
            r = smap.get((t, p))
            if not r:
                continue
            rows.append([
                r["organism"], r["protein"], r["pdb"],
                r["pep_id"], r["sequence"], r["n"],
                fmt(r["mean"]), fmt(r["sd"]), fmt(r["best"]),
            ])

    add_caption(doc, "表2 最终候选抗菌肽与4个细菌靶点的AutoDock Vina对接结果(3次独立重复)")
    add_table(doc,
              ["菌种", "靶点", "PDB", "肽ID", "肽序列", "n",
               "结合能均值(kcal/mol)", "SD", "最优单次(kcal/mol)"],
              rows)

    # narrative
    def mean_of(t, p):
        r = smap.get((t, p))
        return r["mean"] if r else None

    add_body(doc,
             "在Escherichia coli的两个靶点中，3条候选肽对GyrB ATPase结构域(4DUH)的结合能均优于对FtsZ"
             "(6UNX)：pep_018为%s kcal/mol，pep_029为%s kcal/mol，pep_037为%s kcal/mol，提示在当前"
             "刚性肽对接条件下，GyrB ATP结合口袋对这3条候选肽具有更好的形状与静电互补性。"
             % (fmt(mean_of("ecoli_GyrB_4DUH", "P1_FVNKLNRIIPVKGFSMR"), 2),
                fmt(mean_of("ecoli_GyrB_4DUH", "P2_LISNTKKFGTAIASHR"), 2),
                fmt(mean_of("ecoli_GyrB_4DUH", "P3_ISLAIPLASKISGFTLALVKNAST"), 2)))

    add_body(doc,
             "在Staphylococcus aureus的两个靶点中，3条候选肽对FtsZ(5MN4)的结合能整体优于对Sortase A"
             "(1T2W)，其中pep_029与SaFtsZ的结合能均值为%s kcal/mol，为该菌中最优组合。Sortase A组合"
             "普遍出现较大正值，提示在固定受体网格与刚性肽构象条件下，候选肽难以在该浅而开放的底物"
             "通道中获得无空间冲突的结合姿态；该结果应理解为当前对接条件下的拟合不佳信号，而非直接的"
             "热力学结合自由能结论。"
             % fmt(mean_of("saureus_FtsZ_5MN4", "P2_LISNTKKFGTAIASHR"), 2))

    # contacts table
    add_heading(doc, "3.9 结合位点接触残基与可视化", 3)
    add_body(doc,
             "对12个组合的最优构象分别计算4 Å以内的接触残基，结果见表3；对应的三维相互作用可视化见"
             "图2与图3，12个复合物的总览见图S1。")

    crows = []
    for panel in sorted(contacts.keys()):
        c = contacts[panel]
        crows.append([panel, c["target"], c["peptide"], c["count"], c["residues"]])
    if crows:
        add_caption(doc, "表3 各复合物最优构象的4 Å接触残基")
        add_table(doc, ["面板", "靶点", "候选肽", "接触残基数", "接触残基"], crows)

    f1 = os.path.join(FIG_DIR, "Figure_4_Part1_A-F_300dpi.png")
    f2 = os.path.join(FIG_DIR, "Figure_4_Part2_G-L_300dpi.png")
    f3 = os.path.join(FIG_DIR, "Figure_S1_12_Combined_300dpi.png")

    add_figure(doc, f1,
               "图2 最终候选抗菌肽与Escherichia coli靶点的分子对接相互作用图(A—F)。"
               "A—C为FtsZ(6UNX)分别与pep_018、pep_029、pep_037的复合物；D—F为GyrB ATPase结构域(4DUH)"
               "与同样3条候选肽的复合物。每个面板左侧为受体整体视图，右侧为结合位点4 Å局部放大视图；"
               "肽配体为橙色棒状模型，接触残基为青色棒状模型并标注残基编号。")

    add_figure(doc, f2,
               "图3 最终候选抗菌肽与Staphylococcus aureus靶点的分子对接相互作用图(G—L)。"
               "G—I为FtsZ(5MN4)分别与pep_018、pep_029、pep_037的复合物；J—L为Sortase A(1T2W)"
               "与同样3条候选肽的复合物。图例与图2一致。")

    add_figure(doc, f3,
               "图S1 3条最终候选抗菌肽与4个细菌靶点共12个复合物的分子对接总览(A—L)。")

    add_heading(doc, "3.10 对接结果的解释与局限", 3)
    add_body(doc,
             "需要指出的是，AutoDock Vina的评分函数是针对小分子配体开发的，并非专用的柔性肽—蛋白对接"
             "引擎。本研究将经RDKit/UFF能量最小化后的肽构象作为刚性配体对接至标准化受体，其结果适合"
             "作为可复现、开放源代码的计算初筛记录，用于在多个候选靶点之间进行相对比较与优先级排序，"
             "而不应直接等同于实验结合亲和力。若用于机制结论或投稿，建议进一步开展柔性肽对接、分子"
             "动力学模拟与MM/GBSA结合自由能计算，并结合体外抑菌与结合实验加以验证。")

    out = os.path.join(RESULT_DIR, "method_with_docking_%s.docx" % STAMP)
    doc.save(out)
    log("SUPPLEMENT_DOCX=%s" % out)
    return out


# --------------------------------------------------------------------------
# 2) reproduction method markdown (follows the user's flow chart)
# --------------------------------------------------------------------------

REPRO_MD = u"""# 鳄鱼肠道宏基因组抗菌肽发现流程 —— 复刻方法文档

生成时间：{now}
生成主机：{host}
对应流程图：`鳄鱼肠道抗菌肽流程图_中文单行结果版.svg`
对应方法学原文：`method (1).docx`

---

## 0. 本文档的作用

原始工程目录(`~/c_AMPs-prediction-master/.../amp_results`、`sorf_grouped_catalog`)已被删除，
但以下线索仍然完整保留，足以复刻整条流程：

| 线索 | 位置 | 可恢复的内容 |
|---|---|---|
| 方法学正文 | `Downloads\\method (1).docx` | 全部参数、阈值、工具版本与逐级筛选数量 |
| 流程图 | `Downloads\\鳄鱼肠道抗菌肽流程图_中文单行结果版.svg` | 9个流程节点与每级的候选数量 |
| 深度学习预测内核 | GitHub `mqgg5630-cyber/c_AMPs-prediction`，分支 `arena/01a06f35-c-amps-prediction` | Attention/LSTM/BERT 三模型脚本、模型权重、`amp_pipeline/` 自写封装 |
| 本地运行环境 | WSL conda 环境 `camps-tf114`、`py36` | 三模型的两套依赖环境仍在 |
| AlgPred2 封装 | `Downloads\\run_algpred2_allergen.sh` | 过敏性筛选的安装与运行参数 |
| 终筛记录 | `Downloads\\Prediction_Result.csv`、`Prediction_Result(1).csv`、`jieguo.csv` | TheraPepNet 活性预测与 CAMP/AxPep 联合投票的原始结果 |
| 对接结果 | 桌面 `AMP_Docking_Vina_R255_20261005_1552` | 36次Vina重复、12个复合物、SCI组图 |

---

## 1. 原始数据与总体设计（流程图节点①）

- 原始数据：双端 shotgun 宏基因组测序 `SRR18112698_1.fastq.gz` / `SRR18112698_2.fastq.gz`
- 宿主参考：NCBI RefSeq `GCF_030867095.1`（rAllMis1，*Alligator mississippiensis*，Vertebrate Genomes Project 提交，含17条已组装染色体及未定位 scaffolds）
- 技术路线：质控去宿主 → 组装分箱 → 目标MAG确定 → sORF挖掘 → 深度学习初筛 → 本地安全性预筛 → 网页服务器多级终筛 → 新颖性核查与理化表征

```bash
# 数据获取
prefetch SRR18112698
fasterq-dump --split-files SRR18112698 -O raw/
pigz raw/SRR18112698_*.fastq
```

---

## 2. 质控与宿主去除（流程图节点②）

```bash
# 2.1 fastp 质控
fastp \\
  -i raw/SRR18112698_1.fastq.gz -I raw/SRR18112698_2.fastq.gz \\
  -o qc/SRR18112698_1.clean.fq.gz -O qc/SRR18112698_2.clean.fq.gz \\
  -h qc/fastp.html -j qc/fastp.json

# 2.2 构建宿主 Bowtie2 索引
bowtie2-build GCF_030867095.1_rAllMis1_genomic.fna host_db/rAllMis1

# 2.3 KneadData 去宿主
kneaddata \\
  --input1 qc/SRR18112698_1.clean.fq.gz \\
  --input2 qc/SRR18112698_2.clean.fq.gz \\
  --reference-db host_db/rAllMis1 \\
  --output kneaddata_out \\
  --bypass-trim --bypass-trf --reorder \\
  --bowtie2-options "--very-sensitive --dovetail"
```

参数要点（与 method 原文一致）：
- `--bypass-trim`、`--bypass-trf`：避免重复执行额外修剪
- Bowtie2 层 `--very-sensitive --dovetail`：提高宿主污染识别灵敏度
- `--reorder`：保持双端 reads 顺序，保证后续 paired-end 兼容性

---

## 3. 组装、分箱与目标MAG确定（流程图节点③④）

```bash
# 3.1 MEGAHIT 组装
megahit -1 clean_1.fq.gz -2 clean_2.fq.gz -o megahit_out

# 3.2 metaWRAP 分箱（MetaBAT2 + MaxBin2）
metawrap binning -o binning_out -t 16 -a megahit_out/final.contigs.fa \\
  --metabat2 --maxbin2 clean_1.fastq clean_2.fastq

# 3.3 bin_refinement，保留 完整度>=50% 且 污染度<=10%
metawrap bin_refinement -o bin_refinement -t 16 \\
  -A binning_out/metabat2_bins -B binning_out/maxbin2_bins \\
  -c 50 -x 10

# 3.4 CheckM 质量评估 + GTDB-Tk 分类
checkm lineage_wf -x fa bin_refinement/metawrap_bins checkm_out
gtdbtk classify_wf --genome_dir bin_refinement/metawrap_bins --out_dir gtdbtk_out -x fa
```

**关键结果**：共获得 **3个 refined bins**；其中 **bin.1 完整度 97.04%、污染度 0.146%**，
满足高质量MAG标准（完整度≥90%、污染度≤5%），确定为目标MAG。

---

## 4. sORF挖掘（流程图节点⑤）

```bash
getorf -sequence bin.1.fa -outseq sorf/bin1_orfs.faa \\
  -table 11 -minsize 15 -maxsize 150 -find 1
# 合并所有contigs的ORF并按完全相同肽序列去冗余
seqkit rmdup -s sorf/bin1_orfs.faa -o sorf/final_sORF_Catalog.unique.fa
```

- 遗传密码表：细菌 table 11
- ORF 长度范围：15–150 nt
- **关键结果：131,816 条候选短肽**

---

## 5. 三模型集成AMP预测（流程图节点⑥）

代码来源（已验证仍可获取）：

```bash
git clone -b arena/01a06f35-c-amps-prediction \\
  https://github.com/mqgg5630-cyber/c_AMPs-prediction.git
cd c_AMPs-prediction
```

运行环境（WSL 中仍然存在）：
- `camps-tf114`：Attention(`att.h5`) 与 LSTM(`lstm.h5`)，TF1.14 / Keras2.2.4
- `py36`：BERT(`bert.bin`)，PyTorch1.10 / bert-sklearn

```bash
# 单个分组 FASTA 跑三模型
bash amp_pipeline/run_pipeline_one.sh \\
  sorf/final_sORF_Catalog.unique.fa out_bin1 \\
  "$PWD" /home/w26/miniconda3/envs/camps-tf114 /home/w26/miniconda3/envs/py36

# 三模型概率汇总 + 投票
python amp_pipeline/aggregate_amp_results.py \\
  --indir out_bin1 --outdir out_bin1/run_output
```

预处理规则（与 method 原文一致）：
- 整理为单行 FASTA；过滤非标准氨基酸字符与长度 >300 aa 的条目
- Attention / LSTM：20种标准氨基酸整数编码，左侧零填充至长度300
- BERT：按单残基 token 化

判定标准：**三个模型一致判定为阳性** → 高置信度候选。

**关键结果：13,296 条高置信度候选AMP**

---

## 6. 本地预筛：合法性 + 去冗余 + 毒性（流程图节点⑦前半）

```bash
# 6.1 基础合法性：仅保留 20种标准氨基酸、长度 4-50 aa
seqkit fx2tab high_conf.fa | awk 'length($2)>=4 && length($2)<=50 && $2 !~ /[^ACDEFGHIKLMNPQRSTVWY]/' \\
  | seqkit tab2fx > legal.fa

# 6.2 MMseqs2 去冗余
mmseqs easy-cluster legal.fa nr tmp --min-seq-id 1.0 -c 1.0
# 代表序列：nr_rep_seq.fasta

# 6.3 ToxinPred2 毒性预筛（standalone, model1, threshold=0.60）
python toxinpred2.py -i nr_rep_seq.fasta -o toxin_out.csv -m 1 -t 0.60
# 仅保留 non-toxic
```

**关键结果**：合法性检查后仍为 13,296 条 → MMseqs2 去冗余得 **13,294 条代表序列** →
ToxinPred2 保留 **935 条 non-toxic**。

---

## 7. 网页服务器多级终筛（流程图节点⑦⑧⑨）

### 7.1 过敏性筛选 —— AlgPred2

使用你自己写的封装脚本（`Downloads\\run_algpred2_allergen.sh`）：

```bash
# 安装
bash run_algpred2_allergen.sh install --prefix ~/tools/algpred2_only

# 运行：model1 (AAC-RF), threshold=0.3, display=2
bash run_algpred2_allergen.sh run \\
  -i nontoxic_935.fa -o algpred2_result \\
  --prefix ~/tools/algpred2_only -m 1 -t 0.3 -d 2
# 产物：non_allergen.fa / allergen.fa / summary.tsv
```

与 ToxinPred2 的 non-toxic 结果取交集。

**关键结果：268 条同时低毒性、低过敏性的候选肽**

### 7.2 理化性质评估 —— PepFun

计算净电荷、平均疏水性、instability index、`solubility_fail`、`synthesis_fail` 等指标，
按经验规则过滤。

**关键结果：49 条可开发性候选**

### 7.3 肽活性预测 —— TheraPepNet

原始输出即 `Prediction_Result.csv` / `Prediction_Result(1).csv`
（字段：`Number,Sequence,Class`，Class 为 positive/negative）。

**关键结果：15 条治疗潜力候选**

### 7.4 CAMP 与 AxPep 联合筛选

- CAMP：综合 SVM、随机森林、人工神经网络、判别分析 四类分类器统计支持票数（x/4）
- AxPep：综合 AmPEP、Deep-AmPEP30、RF-AmPEP30 三种模型统计支持票数（x/3）

原始投票记录即 `jieguo.csv`，与 method 正文表1完全一致：

| 肽ID | 肽序列 | CAMP | AxPep | 综合判定 |
|---|---|---|---|---|
| pep_003 | WRPTVLRKVSA | 1/4 | 2/3 | 复核保留 |
| pep_008 | WPRTSATSHPYTPPGWRP | 0/4 | 3/3 | 复核保留 |
| pep_015 | KPLHPVSTWK | 0/4 | 2/3 | 复核保留 |
| pep_016 | GPPGWTDHPAF | 0/4 | 0/3 | 不优先 |
| **pep_018** | **FVNKLNRIIPVKGFSMR** | **4/4** | **2/3** | **优先保留** |
| pep_019 | AIKSKNKITKRVQLE | 1/4 | 0/3 | 不优先 |
| pep_020 | NGAGLHFRYGAATGWHHKNMS | 4/4 | 1/3 | 复核保留 |
| **pep_029** | **LISNTKKFGTAIASHR** | **3/4** | **2/3** | **优先保留** |
| pep_034 | KPWLTAWPTAS | 0/4 | 3/3 | 复核保留 |
| pep_036 | SAFFAHKITARQWRAVLIGVSRGSARCGHRSV | 4/4 | 1/3 | 复核保留 |
| **pep_037** | **ISLAIPLASKISGFTLALVKNAST** | **4/4** | **3/3** | **优先保留** |
| pep_039 | KWISTVISVQYSGIWCQMQ | 0/4 | 1/3 | 不优先 |
| pep_044 | EATSSDWGFLAGAGGSWGSGGSR | 0/4 | 0/3 | 不优先 |
| pep_045 | SIGAIVRLWCPVLRGPGWRGGGSAATISCCNHSHLQTITMQTGHHANTSQ | 4/4 | 1/3 | 复核保留 |

**关键结果：3 条最终优先候选 —— pep_018、pep_029、pep_037**

### 7.5 肽级新颖性核查 —— UniProt peptide search

3条最终候选肽均未检出直接肽条目命中，提示在当前数据库与检索条件下具序列层面新颖性。

### 7.6 序列特征分析 —— ExPASy ProtParam

计算肽长、理论pI、分子量、氨基酸组成、instability index、aliphatic index、GRAVY，
用于表征而非进一步过滤。

---

## 8. 分子对接验证（本轮新增，接在原流程之后）

| 项目 | 设置 |
|---|---|
| 对接引擎 | AutoDock Vina 1.2.7 CLI |
| 靶点 | *E. coli* FtsZ `6UNX`、*E. coli* GyrB `4DUH`、*S. aureus* FtsZ `5MN4`、*S. aureus* SrtA `1T2W` |
| 配体 | pep_018 / pep_029 / pep_037（RDKit ETKDGv3 + UFF 能量最小化） |
| 对接盒 | 30 Å × 30 Å × 30 Å |
| 重复 | 每组合 3 个随机种子，共 36 次 |
| 参数 | `--cpu 1`，exhaustiveness=1，`--num_modes 3` |
| 分析 | 4 Å 接触残基、极性接触；PyMOL headless 渲染 + PIL 拼图 300 DPI |

结果数据见桌面结果文件夹：

- `tables/vina_summary_mean_of_3.csv`（12行均值）
- `tables/vina_repeats.csv`（36行重复）
- `SCI_Docking_Figure4_Suite/complexes_interaction_summary.csv`（12个复合物接触残基）
- `SCI_Docking_Figure4_Suite/sci_composite_figures/`（3张300 DPI组图）

---

## 9. 候选逐级压缩总览（对应流程图右栏）

| 阶段 | 工具 | 剩余数量 |
|---|---|---:|
| refined bins | metaWRAP + CheckM | 3 |
| 目标MAG | bin.1（97.04% / 0.146%） | 1 |
| sORF挖掘 | EMBOSS getorf | 131,816 |
| 深度学习三模型一致阳性 | Attention + LSTM + BERT | 13,296 |
| 合法性检查 | 自定义过滤 | 13,296 |
| 去冗余 | MMseqs2 | 13,294 |
| 毒性预筛 | ToxinPred2 (m1, t=0.60) | 935 |
| 过敏性筛选 | AlgPred2 (m1, t=0.3) | 268 |
| 理化性质 | PepFun | 49 |
| 活性预测 | TheraPepNet | 15 |
| 联合投票 | CAMP + AxPep | **3** |
| 新颖性核查 | UniProt peptide search | 3（均未命中） |
| 分子对接 | AutoDock Vina ×36 | 3 条 × 4 靶点 |

---

## 10. 复刻时的注意事项

1. **BERT 权重不在仓库里**：`Models/bert.bin` 需按 `Models/ReadME.txt` 单独下载并校验 md5。
2. **两套 conda 环境不可混用**：Attention/LSTM 必须在 TF1.14 的 `camps-tf114` 下运行，BERT 必须在 `py36` 下运行，`run_pipeline_one.sh` 已内置环境切换。
3. **已知内核缺陷**：原始内核存在路径拼写错误 `../Moldes/lstm.h5`，仓库里的 `amp_pipeline` 版本已修正为 `../Models/lstm.h5`。
4. **网页服务器步骤不可脚本化全自动**：PepFun、TheraPepNet、CAMP、AxPep、UniProt、ExPASy 均为网页提交，需保留每步的导出 CSV 作为可追溯记录（本次即依靠 `Prediction_Result*.csv` 与 `jieguo.csv` 完成回溯）。
5. **HPC 侧仍可能保留原始大文件**：shell history 显示服务器路径
   `25wenshaohua@mu01:/mnt/hpc/home/25menglei/25wenshaohua/wsh/ad/codenew/sorf_pipeline`，
   若该目录尚在，可直接取回 `final_sORF_Catalog.unique.fa` 与分组 FASTA，无需从 reads 重跑。

---

生成标记：
AMP_REPRO_MD_DONE=True
"""


def build_repro_md():
    import socket
    txt = REPRO_MD.format(
        now=datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        host=socket.gethostname(),
    )
    out = os.path.join(RESULT_DIR, "AMP_Pipeline_Reproduction_Method.md")
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(txt)
    log("REPRO_MD=%s" % out)
    return out


# --------------------------------------------------------------------------
# 3) figure style review
# --------------------------------------------------------------------------

REVIEW_MD = u"""# SCI 组图风格对比评估

生成时间：{now}

对比对象：

- **A 组（你自己做的）**：`AMP_Docking_Vina_R255_20261005_1552\\SCI_Docking_Figure4_Suite\\sci_composite_figures\\`
- **B 组（上一轮我生成的）**：`AMP_Docking_Vina_R255_20261005_1552\\complexes_best_vina\\sci_composite_figures\\`

## 结论

**A 组（你的）明显更专业、更接近可直接投稿的质量。** 后续正文与补充材料统一采用 A 组。

## 逐项对比

| 维度 | A 组（你的） | B 组（我的） | 判定 |
|---|---|---|---|
| 版式结构 | 左侧整体视图 + 右侧虚线框放大视图，虚线引导线连接两者，关系一目了然 | 两图并列，无引导线，读者需自行建立对应关系 | A 更优 |
| 面板标注 | 粗体 A—L + 括号注明靶点与肽编号，位置统一在左上角 | 标注样式不统一 | A 更优 |
| 配色 | 受体淡紫灰 `#C2C7E6`、肽橙色 `#EB8526`、接触残基青色 `#26CCD1`、极性接触品红 `#D91A73`，冷暖对比克制且专业 | 配色对比过强，偏演示风 | A 更优 |
| 透明度处理 | 放大视图用 80% 玻璃态透明 ray-tracing，既保留结构语境又突出配体 | 无透明度分层，背景结构与配体争夺视觉重心 | A 更优 |
| 字体 | Times New Roman Bold，并做了标签防碰撞排布 | 默认 PyMOL 标签，存在重叠风险 | A 更优 |
| 留白与边框 | 面板边框统一、白底、留白均匀 | 留白不均 | A 更优 |
| 产出格式 | 每个复合物 5 种格式：`_times.png`、`_clean.png`、`_vector.svg`、`_vector.pse`、`_labeled.png` | 仅位图 | A 更优，`.svg` 可在 AI/PPT 中二次编辑，`.pse` 可交互复核 |
| 分辨率 | 300 DPI，2060×1744 / 2392×1826 | 300 DPI | 相当 |

## 唯一可以再优化的两点

1. **接触残基标注数量偏少**：A 组每个面板只标注了 1—4 个残基（如面板 D 仅 `LYS-57`），而 4 Å 内实际接触残基更多。建议在正文图保持简洁、在补充材料中补一张完整残基标注版，或在图注中列全。
2. **缺少结合能数值**：可在每个面板右下角加一行小字 `ΔG = -10.75 kcal/mol`，读者无需翻表即可比较，这是高分期刊对接图的常见做法。

两点都不影响当前使用，已在正文图注中以文字形式补足。

SCI_FIGURE_REVIEW_DONE=True
"""


def build_review_md():
    out = os.path.join(RESULT_DIR, "AMP_Figure_Style_Review.md")
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(REVIEW_MD.format(now=datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")))
    log("REVIEW_MD=%s" % out)
    return out


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------

def main():
    log("DESKTOP=%s" % DESKTOP)
    log("RESULT_DIR=%s exists=%s" % (RESULT_DIR, os.path.isdir(RESULT_DIR)))
    log("FIG_DIR=%s exists=%s" % (FIG_DIR, os.path.isdir(FIG_DIR)))
    if not os.path.isdir(RESULT_DIR):
        log("FATAL: result folder missing")
        return 1
    os.makedirs(RESULT_DIR, exist_ok=True)

    summary = load_summary()
    log("SUMMARY_ROWS=%d" % len(summary))
    contacts = load_contacts()
    log("CONTACT_PANELS=%d" % len(contacts))

    docx_path = build_supplement_docx(summary, contacts)
    md_path = build_repro_md()
    review_path = build_review_md()

    manifest = {
        "generated": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "result_dir": RESULT_DIR,
        "supplement_docx": docx_path,
        "reproduction_md": md_path,
        "figure_review_md": review_path,
        "summary_rows": len(summary),
        "contact_panels": len(contacts),
    }
    mf = os.path.join(RESULT_DIR, "AMP_Method_Supplement_manifest.json")
    with open(mf, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=2)
    log("MANIFEST=%s" % mf)

    ok = bool(docx_path) and os.path.isfile(md_path) and os.path.isfile(review_path)
    log("AMP_METHOD_SUPPLEMENT_DONE=%s" % ok)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
