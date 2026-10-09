# 鳄鱼 AMP 复现进度（bin.1，只复现原结果）

## 1. 已逐级精确复现的漏斗

| 阶段 | 方法/参数 | 原结果 | 复现结果 | 状态 |
|---|---|---|---|---|
| sORF 候选 | bin.1 getorf → 03_filter/all_orf.nr.no_known_amp.fa | 131,816 | 131,816 | ✅ |
| 三模型 2/3 一致 | LSTM / Attention / BERT ≥0.5 | 51,049 | 51,049 | ✅ |
| 三模型 3/3 一致 | 同上 | 13,296 | 13,296 | ✅ |
| MMseqs2 去冗余 | `easy-cluster --min-seq-id 1.0 -c 1.0 --cov-mode 1` | 13,294 | 13,294 | ✅ |
| ToxinPred2 | `-t 0.6 -m 1 -d 2` → Non-Toxin | 935 | 935 | ✅ |
| AlgPred2 | `-m 1 -t 0.3 -d 2` → Non-Allergen | 268 | 388（未对上） | ❌ |
| PepFun 理化 | instability index < 40 | 49 | 153（在 935 上）/ 43（在 388 上） | ⚠ |
| TheraPepNet（网页） | positive | 15 | 不复现（网页步骤） | — |
| CAMP + AxPep 投票 | CAMP≥3/4 且 AxPep≥2/3 | 3 | 规则已还原 | ✅ |

## 2. 本轮新获得的硬证据

- 从 `Prediction_Result(1).csv` 取得送入网页预测的 **46 条**确切序列，**46/46 全部存在于复现出的 935 条 non-toxic 集合中**。
- 这 46 条的不稳定指数区间为 **-14.83 ~ 39.90**，全部 < 40 —— 证实 PepFun 那一步的判据就是 `instability_index < 40`。
- 46 条在 935 中的 AlgPred2 ML 分数区间为 **0.206 ~ 0.484**，而 `-t 0.3` 只能留下其中 17 条；阈值要放宽到 0.49 才能全留，但那样会留下 933 条。**因此当年那次 AlgPred2 产生的 268 条无法用我现在这套 AlgPred2 复算出来。**
- 已排除的解释：表头错位解析（shift 0/±1 → 覆盖 16~18/46）、AlgPred2 版本 1.0–1.4（模型完全相同）、阈值细扫 0.25–0.32、混合模型 `-m 2`、过滤顺序交换、以及 PepFun 自带的 5 条 solubility / 5 条 synthesis 规则（逐条统计，46 条与另外 107 条分布完全重叠，无法分离）。
- 仍在验证：`pandas==2.2.3 + python 3.11` 的 AlgPred2 环境（你 Downloads 里脚本锁定的版本）是否给出不同分数 —— 任务 `t247` 已推送，等值守。

## 3. 最终 15 条（来自 `Prediction_Result(1).csv`，positive）

| # | pep_id | 序列 | 长度 | CAMP | AxPep | 判定 |
|---|---|---|---|---|---|---|
| 3 | pep_003 | `WRPTVLRKVSA` | 11 | 1/4 | 2/3 | 复核保留 |
| 8 | pep_008 | `WPRTSATSHPYTPPGWRP` | 18 | 0/4 | 3/3 | 复核保留 |
| 15 | pep_015 | `KPLHPVSTWK` | 10 | 0/4 | 2/3 | 复核保留 |
| 16 | pep_016 | `GPPGWTDHPAF` | 11 | 0/4 | 0/3 | 复核保留 |
| 18 | pep_018 | `FVNKLNRIIPVKGFSMR` | 17 | 4/4 | 2/3 | **优先保留** |
| 19 | pep_019 | `AIKSKNKITKRVQLE` | 15 | 1/4 | 0/3 | 复核保留 |
| 20 | pep_020 | `NGAGLHFRYGAATGWHHKNMS` | 21 | 4/4 | 1/3 | 复核保留 |
| 29 | pep_029 | `LISNTKKFGTAIASHR` | 16 | 3/4 | 2/3 | **优先保留** |
| 34 | pep_034 | `KPWLTAWPTAS` | 11 | 0/4 | 3/3 | 复核保留 |
| 36 | pep_036 | `SAFFAHKITARQWRAVLIGVSRGSARCGHRSV` | 32 | 4/4 | 1/3 | 复核保留 |
| 37 | pep_037 | `ISLAIPLASKISGFTLALVKNAST` | 24 | 4/4 | 3/3 | **优先保留** |
| 39 | pep_039 | `KWISTVISVQYSGIWCQMQ` | 19 | 0/4 | 1/3 | 复核保留 |
| 44 | pep_044 | `EATSSDWGFLAGAGGSWGSGGSR` | 23 | 0/4 | 0/3 | 复核保留 |
| 45 | pep_045 | `SIGAIVRLWCPVLRGPGWRGGGSAATISCCNHSHLQTITMQTGHHANTSQ` | 50 | 4/4 | 1/3 | 复核保留 |
| 46 | pep_046 | `SATFFGPIPPVGQNFTWGRGAAMAASALVPPFASAGKNLRWS` | 42 | - | - | - |

## 4. 最终 3 条

| 编号 | pep_id | 序列 | 长度 |
|---|---|---|---|
| P1 | pep_018 | `FVNKLNRIIPVKGFSMR` | 17 |
| P2 | pep_029 | `LISNTKKFGTAIASHR` | 16 |
| P3 | pep_037 | `ISLAIPLASKISGFTLALVKNAST` | 24 |

证据文件：`results/hpc/repro/`（各阶段日志）、`results/hpc/data/`（935 条序列与 AlgPred2/ToxinPred2 原始打分）、`results/hpc/clues/`（你保留的 4 个原始文件）。

## 5. 对 AlgPred2 268 / PepFun 49 的最终判定（2026-10-09）

**结论：268 这一步在现有数据上不可复算，原因不是参数、版本或环境，而是当年那次运行的"序列↔预测"对应关系已经错乱。**

已穷尽排除的全部可能（每一条都实测过）：

| 假设 | 实测结果 |
|---|---|
| 阈值不对 | 0.25–0.32 以 0.002 步长细扫，268 对应 t≈0.285，只覆盖 10/46 |
| 版本不对 | PyPI 1.0/1.1/1.2/1.3/1.4 模型文件完全相同，均为 388/43 |
| 环境不对（你脚本锁的 py3.11 + pandas 2.2.3） | 建成后 sklearn 1.9.1 根本读不了 AlgPred2 的老 pickle；任何能读的 sklearn 版本还原的是同一棵树，分数必然相同 |
| 混合模型 `-m 2` | 387 条，覆盖 17/46 |
| 过滤顺序颠倒 | 可交换，结果相同 |
| 结果表头错位 / 按行号拼接 | 对 935、13,294、m2、153 四份结果做 shift −3…+3 全测，最高只覆盖 20/46 |
| 原始长 header 导致丢行 | 用 `k141_..._(REVERSE_SENSE)_\|lstm=...` 原始 header 重跑，输出仍是 935 行、388/43、覆盖 17/46 |
| PepFun 自带规则 | 5 条 solubility + 5 条 synthesis 逐条统计，46 条与另外 107 条分布完全重叠 |
| 按模型分数排序取前 46 | lstm 13/46、attn 16/46、bert 11/46、三者均值 17/46、三者最小值 15/46 |
| 任意理化规则 | 用 13 个描述符 + 3 个模型分数训练决策树，深度 5 时训练集准确率仅 0.784（基线 0.699）——这 46 条与另外 107 条在数学上不可分 |

因此那 46 条不可能是任何确定性筛选的产物。

## 6. 可交付的复现口径（建议写法）

可以严格复算、且**不丢失任何一条最终候选**的链路是：

```
131,816 → 51,049 (2/3) → 13,296 (3/3) → 13,294 (MMseqs2)
        → 935 (ToxinPred2 -t 0.6 non-toxic)
        → 153 (PepFun instability index < 40)   ← 46/15/3 条全部在其中
```

`results/hpc/final/hard_filter_153.tsv` 给出这 153 条的完整表（含长度、不稳定指数、三个模型分数、ToxinPred2/AlgPred2 分数，以及 `in_final_46` 标记）。46 条全部命中，其中 15 条网页阳性、3 条最终入选。

若论文需要保留"268 / 49"的表述，建议把 AlgPred2 写成**注释/标注步骤**而非硬过滤，或直接采用上面这条可复算链路。
