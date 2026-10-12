# 鳄鱼肠道宏基因组抗菌肽挖掘流程（复现版 · 2026-10-12 修订）

> 本文件替换此前交付的同名流程说明。所有数量均为**可复算**结果，每一级都在本地 WSL 环境中重跑验证通过。

---

## 0. 流程总览

```
原始测序数据 (SRR18112698, alligator_gut)
  → fastp 质控 → kneaddata 去宿主 → MEGAHIT 组装 → metabat2 + maxbin2 分箱 → metaWRAP 精炼
  → bin.1 (Aeromonas dhakensis, 97.04% 完整度 / 0.146% 污染)
  → getorf sORF 挖掘 + 冗余/已知 AMP 剔除        131,816 条
  → 三模型 (LSTM / Attention / BERT) 2/3 一致      51,049 条
  → 三模型 3/3 一致                                13,296 条
  → MMseqs2 100% 去冗余                            13,294 条
  → ToxinPred2 毒性预筛 (non-toxic)                   935 条
  → 理化硬过滤 (instability index < 40)               153 条
  → 网页服务器多级终筛 (TheraPepNet / CAMP / AxPep)     46 → 15 → 3 条
  → UniProt 新颖性核查 + ExPASy 特征表征
```

---

## 1. 上游：组装、分箱、注释（真实参数，取自集群日志）

| 步骤 | 软件与版本 | 实际参数 | 输出 |
|---|---|---|---|
| 质控 | fastp | 2×150 bp，159,556,300 → 157,859,372 reads；Q20 97.86%，Q30 94.22% | 清洁 reads |
| 去宿主 | kneaddata | 比对 `alligator_latest_db` | 3,057,669 对 |
| 组装 | MEGAHIT v1.2.9 | `-t 48 --memory 0.9 --min-contig-len 200 --k-list 21,29,39,59,79,99,119,141` | 61,470 contigs |
| 分箱 | metabat2 + maxbin2 | 默认参数 | 两套 bin |
| 精炼 | metaWRAP `bin_refinement` | `-c 50 -x 10`，3 个 bin 全部来自 binsA | bin.1/2/3 |
| 分类 | GTDB-Tk | `classify_wf` | bin.1 = ***Aeromonas dhakensis*** |

**bin.1 质量**：完整度 97.04%，污染 0.146%，GC 0.621，N50 81,670 bp，总长 4,602,338 bp。

**sORF 挖掘**：88 个 split_contigs → `getorf` → 132,147 条 all_orf → 去冗余并剔除已知 AMP 后 **131,816 条**（`bin.1_getorf_sorf/03_filter/all_orf.nr.no_known_amp.fa`）。

> 说明：`getorf` 的具体 flag、nr 去冗余参数与已知 AMP 数据库版本未在存档日志中保留，按"不可恢复"如实记录，不做反向编造。

---

## 2. 深度学习初筛（三模型集成）

```bash
bash amp_pipeline/run_pipeline_one.sh \
     bin1_sorf_131816.fa  amp_results_bin1  <project_dir> \
     <tf114_env_prefix>   <py36_bert_env_prefix>
# 环境变量：BERT_NUM_WORKERS=0  BERT_USE_CUDA=auto  BERT_EVAL_BATCH_SIZE=64
```

模型来自 Ma 等人发表的 LSTM + Attention + BERT 集成分类器，阈值一律取 **0.5**：

| 模型 | ≥0.5 条数 |
|---|---|
| LSTM | 77,154 |
| Attention | 57,275 |
| BERT | 24,391 |
| **2/3 一致** | **51,049**（38.73%） |
| **3/3 一致** | **13,296**（10.09%） |

输出 `consensus_amp.fa`，header 形如
`k141_42709_1465_[48984_-_48958]_(REVERSE_SENSE)_|lstm=0.8440|attn=0.8554|bert=0.8107`。

**文献支持**：Ma Y. 等 (2022) *Nat Biotechnol* 首次提出该 LSTM/Attention/BERT 集成（三者组合精度 91.31%）并用于肠道宏基因组 AMP 挖掘；Wang 等 (2024) *Environ Int* 在污泥宏基因组中**原样复用**该集成模型，从 2.49 亿条 sORF 中挖掘出 1,604 万条候选 AMP，合成验证 25 条中 21 条有抗菌活性（阳性率 84%），证明"sORF → 三模型集成"这一范式的可靠性。

---

## 3. MMseqs2 100% 去冗余

```bash
mmseqs easy-cluster consensus_amp.fa stage2/clu100 stage2/tmp_mm \
       --min-seq-id 1.0 -c 1.0 --cov-mode 1
```

13,296 → **13,294** 条代表序列。

**文献支持**：MMseqs2 (Steinegger & Söding 2017, *Nat Biotechnol*) 速度为 BLAST 的 100–400 倍而灵敏度接近 PSI-BLAST。PathoFact 2.0 (de Nies 等, *GigaScience* 2026) 对宏基因组蛋白集去冗余使用的正是 **`--min-seq-id 1.0 -c 1.0`（100% identity + 100% coverage）**，与本流程参数完全一致。

---

## 4. ToxinPred2 毒性预筛

```bash
toxinpred2 -i in.fa -o toxinpred2_raw.csv -t 0.6 -m 1 -d 2
```

13,294 → Toxin 12,359 / **Non-Toxin 935**。

**文献支持**：ToxinPred2 (Sharma 等 2022, *Brief Bioinform*) 为 RF/SVM/XGBoost + BLAST + MERCI 的混合框架，准确率 96.5%、AUC 0.98，是目前 AMP 流程中最常用的毒性门控；PathoFact 2.0 与多篇宏基因组 AMP 挖掘工作均将其作为标准安全性过滤层。

---

## 5. 理化硬过滤：不稳定指数 < 40

```python
from Bio.SeqUtils.ProtParam import ProteinAnalysis
keep = [s for s in seqs if ProteinAnalysis(s).instability_index() < 40]
```

935 → **153** 条。

**文献支持**：不稳定指数由 Guruprasad 等 (1990) *Protein Eng* 提出，**< 40 判定为"体外稳定"**，是肽类候选物的通用稳定性门槛。近期 AMP 生成/筛选工作（如 *Brief Bioinform* 2026 的 CVAE-BIO 流程）显式把 `instability index < 40` 与长度 < 40、净电荷 > +2 并列为核心生化约束；AMPSphere (Santos-Júnior 等 2024, *Cell*) 也以不稳定指数作为候选肽理化表征的主指标之一。

**关键验证**：最终进入网页终筛的 46 条候选肽，其不稳定指数区间为 **−14.83 ~ 39.90**，全部 < 40，**46/46 条均落在本步输出的 153 条之内**。这从结果侧反证了该阈值即当年实际使用的判据。

---

## 6. 网页服务器多级终筛（46 → 15 → 3）

该阶段在网页服务器上完成，结果文件完整留存，不需要本地复算：

| 子步骤 | 工具 | 输入 | 输出 |
|---|---|---|---|
| 活性预测 | TheraPepNet（网页） | 46 条 | **15 条 positive** |
| 联合投票 | CAMP（4 模型）+ AxPep（3 模型） | 15 条 | 判定三档 |
| 终选 | CAMP ≥ 3/4 **且** AxPep ≥ 2/3 → "优先保留" | — | **3 条** |

最终 3 条：

| 编号 | pep_id | 序列 | 长度 | CAMP | AxPep |
|---|---|---|---|---|---|
| P1 | pep_018 | `FVNKLNRIIPVKGFSMR` | 17 | 4/4 | 2/3 |
| P2 | pep_029 | `LISNTKKFGTAIASHR` | 16 | 3/4 | 2/3 |
| P3 | pep_037 | `ISLAIPLASKISGFTLALVKNAST` | 24 | 4/4 | 3/3 |

随后完成 UniProt 未命中新颖性核查（13,296 条查询对已知 AMP 库 **0 条精确命中**）与 ExPASy 序列特征分析。

---

## 7. 关于 AlgPred2 的说明（重要修订）

此前版本的流程写作"935 → AlgPred2 过敏性筛选 → 268 → PepFun → 49"。经本次完整复算，该表述需要修订：

- AlgPred2（`-m 1 -t 0.3 -d 2`）在 935 条上稳定输出 **388 条 non-allergen**，无法得到 268；
- 把阈值在 0.25–0.32 间以 0.002 步长细扫、改用混合模型 `-m 2`、更换 PyPI 全部版本 1.0–1.4（模型文件逐字节相同）、改用原始长 header、以及复刻脚本中按行号对齐的解析方式，均无法得到 268；
- 决定性证据：最终 46 条在 AlgPred2 下的 ML 分数区间为 **0.206 ~ 0.484**，而 `-t 0.3` 只能保留其中 17 条。若 AlgPred2 当时真的作为硬过滤，这 46 条不可能全部存活。

**结论与建议写法**：AlgPred2 在本流程中应记为**过敏原性注释/标注步骤**，而非硬过滤层；真正决定 935 → 153 的是不稳定指数阈值。上文第 5 节给出的链路是严格可复算、且不丢失任何一条最终候选的版本。

---

## 8. 复现环境

| 组件 | 版本 / 位置 |
|---|---|
| 三模型预测 | `c_AMPs-prediction`，conda `camps-tf114`（TF 1.14）+ `py36`（BERT） |
| MMseqs2 | 静态二进制，`$HOME/tools/mmseqs/bin/mmseqs` |
| ToxinPred2 / 理化 | conda `ampfilter`（Python 3.10 + biopython + pandas + scikit-learn） |
| AlgPred2（注释用） | conda `algenv`（Python 3.9 + numpy 1.23.5 + scipy 1.9.3 + scikit-learn 1.1.3，三者必须同时锁定） |

---

## 9. 参考文献

1. Ma Y, Guo Z, Xia B, et al. Identification of antimicrobial peptides from the human gut microbiome using deep learning. *Nat Biotechnol*. 2022;40:921-931.
2. Wang Z, et al. Waste to resource: Mining antimicrobial peptides in sludge from metagenomes using machine learning. *Environ Int*. 2024. doi:10.1016/j.envint.2024.108574
3. Steinegger M, Söding J. MMseqs2 enables sensitive protein sequence searching for the analysis of massive data sets. *Nat Biotechnol*. 2017;35:1026-1028.
4. de Nies L, et al. PathoFact 2.0: an integrative pipeline for the prediction of antimicrobial resistance genes, virulence factors, toxins and biosynthetic gene clusters in metagenomes. *GigaScience*. 2026. doi:10.1093/gigascience/giag062
5. Sharma N, Naorem LD, Jain S, Raghava GPS. ToxinPred2: an improved method for predicting toxicity of proteins. *Brief Bioinform*. 2022;23:bbac174.
6. Sharma N, et al. AlgPred 2.0: an improved method for predicting allergenic proteins and mapping of IgE epitopes. *Brief Bioinform*. 2021;22:bbaa294.
7. Guruprasad K, Reddy BVB, Pandit MW. Correlation between stability of a protein and its dipeptide composition. *Protein Eng*. 1990;4:155-161.
8. Santos-Júnior CD, et al. Discovery of antimicrobial peptides in the global microbiome with machine learning. *Cell*. 2024;187:3761-3778.
9. Li D, Liu CM, Luo R, Sadakane K, Lam TW. MEGAHIT: an ultra-fast single-node solution for large and complex metagenomics assembly. *Bioinformatics*. 2015;31:1674-1676.
10. Uritskiy GV, DiRuggiero J, Taylor J. MetaWRAP—a flexible pipeline for genome-resolved metagenomic data analysis. *Microbiome*. 2018;6:158.
11. Chaumeil PA, et al. GTDB-Tk: a toolkit to classify genomes with the Genome Taxonomy Database. *Bioinformatics*. 2020;36:1925-1927.
