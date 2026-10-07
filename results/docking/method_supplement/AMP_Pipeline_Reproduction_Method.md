# 鳄鱼肠道宏基因组抗菌肽发现流程 —— 复刻方法文档

生成时间：2026-10-07 16:00:19
生成主机：LAPTOP-R77M5D6M
对应流程图：`鳄鱼肠道抗菌肽流程图_中文单行结果版.svg`
对应方法学原文：`method (1).docx`

---

## 0. 本文档的作用

原始工程目录(`~/c_AMPs-prediction-master/.../amp_results`、`sorf_grouped_catalog`)已被删除，
但以下线索仍然完整保留，足以复刻整条流程：

| 线索 | 位置 | 可恢复的内容 |
|---|---|---|
| 方法学正文 | `Downloads\method (1).docx` | 全部参数、阈值、工具版本与逐级筛选数量 |
| 流程图 | `Downloads\鳄鱼肠道抗菌肽流程图_中文单行结果版.svg` | 9个流程节点与每级的候选数量 |
| 深度学习预测内核 | GitHub `mqgg5630-cyber/c_AMPs-prediction`，分支 `arena/01a06f35-c-amps-prediction` | Attention/LSTM/BERT 三模型脚本、模型权重、`amp_pipeline/` 自写封装 |
| 本地运行环境 | WSL conda 环境 `camps-tf114`、`py36` | 三模型的两套依赖环境仍在 |
| AlgPred2 封装 | `Downloads\run_algpred2_allergen.sh` | 过敏性筛选的安装与运行参数 |
| 终筛记录 | `Downloads\Prediction_Result.csv`、`Prediction_Result(1).csv`、`jieguo.csv` | TheraPepNet 活性预测与 CAMP/AxPep 联合投票的原始结果 |
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
fastp \
  -i raw/SRR18112698_1.fastq.gz -I raw/SRR18112698_2.fastq.gz \
  -o qc/SRR18112698_1.clean.fq.gz -O qc/SRR18112698_2.clean.fq.gz \
  -h qc/fastp.html -j qc/fastp.json

# 2.2 构建宿主 Bowtie2 索引
bowtie2-build GCF_030867095.1_rAllMis1_genomic.fna host_db/rAllMis1

# 2.3 KneadData 去宿主
kneaddata \
  --input1 qc/SRR18112698_1.clean.fq.gz \
  --input2 qc/SRR18112698_2.clean.fq.gz \
  --reference-db host_db/rAllMis1 \
  --output kneaddata_out \
  --bypass-trim --bypass-trf --reorder \
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
metawrap binning -o binning_out -t 16 -a megahit_out/final.contigs.fa \
  --metabat2 --maxbin2 clean_1.fastq clean_2.fastq

# 3.3 bin_refinement，保留 完整度>=50% 且 污染度<=10%
metawrap bin_refinement -o bin_refinement -t 16 \
  -A binning_out/metabat2_bins -B binning_out/maxbin2_bins \
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
getorf -sequence bin.1.fa -outseq sorf/bin1_orfs.faa \
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
git clone -b arena/01a06f35-c-amps-prediction \
  https://github.com/mqgg5630-cyber/c_AMPs-prediction.git
cd c_AMPs-prediction
```

运行环境（WSL 中仍然存在）：
- `camps-tf114`：Attention(`att.h5`) 与 LSTM(`lstm.h5`)，TF1.14 / Keras2.2.4
- `py36`：BERT(`bert.bin`)，PyTorch1.10 / bert-sklearn

```bash
# 单个分组 FASTA 跑三模型
bash amp_pipeline/run_pipeline_one.sh \
  sorf/final_sORF_Catalog.unique.fa out_bin1 \
  "$PWD" /home/w26/miniconda3/envs/camps-tf114 /home/w26/miniconda3/envs/py36

# 三模型概率汇总 + 投票
python amp_pipeline/aggregate_amp_results.py \
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
seqkit fx2tab high_conf.fa | awk 'length($2)>=4 && length($2)<=50 && $2 !~ /[^ACDEFGHIKLMNPQRSTVWY]/' \
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

使用你自己写的封装脚本（`Downloads\run_algpred2_allergen.sh`）：

```bash
# 安装
bash run_algpred2_allergen.sh install --prefix ~/tools/algpred2_only

# 运行：model1 (AAC-RF), threshold=0.3, display=2
bash run_algpred2_allergen.sh run \
  -i nontoxic_935.fa -o algpred2_result \
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
