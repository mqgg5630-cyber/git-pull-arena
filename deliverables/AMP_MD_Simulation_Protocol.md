# 分子动力学模拟方案（单一主靶点）

> 配套文件：`AMP_Pipeline_Reproduction_Method.md`、`AMP_Pipeline_Flowchart_20261012.svg`
> 适用对象：pep_018 / pep_029 / pep_037（鳄鱼肠道宏基因组来源新型抗菌肽）

---

## 1. 为什么只保留一个靶点，并且为什么必须补做 MD

前期对接覆盖了 4 个靶点（EcFtsZ 6UNX、EcGyrB 4DUH、SaFtsZ 5MN4、SaSrtA 1T2W）共 12 个复合物。存在两个方法学问题：

1. **多靶点平行对接缺乏文献主线**。抗菌肽的胞内蛋白靶点必须有明确的机制文献支撑，否则属于"广撒网"。
2. **肽链过长，刚性对接不可靠**。本研究 3 条候选肽长度为 16–24 残基，自由度远超 AutoDock Vina 的适用范围（经验上 > 10 个可旋转键即显著降低打分可靠性）。对接给出的结合能只能作为**初筛排序**，不能作为结合模式的结论。打分数据本身也印证了这一点：pep_037 对 6UNX 的平均打分为 **+2.433 kcal/mol**（正值，说明刚性对接根本没能放下这条 24 肽）。

**结论**：保留 **大肠杆菌细胞分裂蛋白 FtsZ（PDB: 6UNX）** 作为唯一主靶点，对接仅作初筛呈现，结合模式与稳定性结论全部由分子动力学给出。

### 1.1 主靶点选择依据

| 维度 | 说明 |
|---|---|
| 必需性 | FtsZ 是细菌胞质分裂环（Z-ring）的核心骨架蛋白，在大肠杆菌中为必需基因，抑制后直接导致细胞丝状化与分裂失败 |
| **抗菌肽直接文献证据** | Temporin L 已被证实通过与 FtsZ 及分裂体复合物相互作用而阻断大肠杆菌细胞分裂——这是"AMP 以 FtsZ 为胞内靶点"最直接的实验先例 |
| 结构质量 | 6UNX 为 *E. coli* FtsZ(L178E)–GTP 复合物晶体结构（Schumacher 等, 2020, *Acta Crystallogr F* 76:94-102, doi:10.1107/S2053230X20001132），含完整 GTP 结合位点与 T7 loop |
| 本研究对接支持 | pep_018 对 6UNX 平均 −7.242 kcal/mol、pep_029 −8.793 kcal/mol，二者均落在合理区间 |
| 物种一致性 | bin.1 鉴定为 *Aeromonas dhakensis*（γ-变形菌纲），与大肠杆菌同属革兰氏阴性菌，靶点同源性与生态学相关性均成立 |

### 1.2 靶点保留策略（对接 vs 动力学）

| 层级 | 保留靶点 | 说明 |
|---|---|---|
| **分子对接（虚拟筛选）** | **EcFtsZ 6UNX + EcGyrB 4DUH 两个大肠杆菌靶点均保留** | 作为交叉验证，说明候选肽并非只对单一口袋有打分偏好；金黄色葡萄球菌的 SaFtsZ 5MN4 与 SaSrtA 1T2W 移入补充材料 |
| **分子动力学** | **只做 EcFtsZ 6UNX 一个靶点** | MD 成本高，结论要深不要广；FtsZ 有 Temporin L 的 AMP 直接实验先例，而 GyrB 仅有小分子抑制剂文献，缺乏"抗菌肽作用于 ATP 酶口袋"的机制支撑——pep_018 对 GyrB 的 −10.753 kcal/mol 更可能是长肽落入大口袋造成的打分虚高 |

因此正文主线为：**对接给出两靶点初筛排序 → 动力学只对 FtsZ 给出结合模式与稳定性结论**。

---

## 2. 模拟体系设计

共三类体系，每类 **3 次独立重复**（不同初始速度种子），合计 9 条轨迹，每条 100 ns。

| 体系 | 组成 | 目的 | 时长 |
|---|---|---|---|
| **S1 肽–FtsZ 复合物** | FtsZ (6UNX) + 肽，显式水 + 0.15 M NaCl | 验证对接姿势能否稳定维持，给出真实结合界面 | 3 × 100 ns |
| **S2 自由肽** | 单肽 + 水 + 0.15 M NaCl | 二级结构倾向（螺旋度）基线 | 3 × 100 ns |
| **S3 肽–膜** | 肽 + POPE:POPG = 3:1 双层膜（模拟大肠杆菌内膜） | 膜作用机制（吸附 / 插入 / 变薄） | 3 × 100 ns |

> S3 是抗菌肽研究的标准配置：革兰氏阴性菌内膜以 PE/PG 为主，阴离子 PG 组分是阳离子 AMP 选择性的来源。

---

## 3. 力场与参数

| 项目 | 设置 |
|---|---|
| 软件 | GROMACS 2023 及以上 |
| 力场 | CHARMM36m（蛋白与肽）+ CHARMM36 脂质 |
| 水模型 | TIP3P |
| 离子 | 0.15 M NaCl，并中和体系净电荷 |
| 盒子 | 立方盒（S1/S2，边界距溶质 ≥ 1.2 nm）；膜体系用 CHARMM-GUI Membrane Builder 构建 |
| 积分步长 | 2 fs，LINCS 约束所有含氢键 |
| 非键截断 | 1.2 nm，范德华力 force-switch 自 1.0 nm |
| 静电 | PME，傅里叶间距 0.12 nm |
| 控温 | Nosé-Hoover，310 K，τ = 1.0 ps；蛋白/脂质、溶剂分别耦合 |
| 控压 | Parrinello-Rahman，1 bar；S1/S2 各向同性，S3 半各向同性 |
| 周期性 | 三维周期性边界 |

---

## 4. 执行流程（GROMACS 命令）

```bash
# ---------- 0. 输入准备 ----------
# 受体：6UNX 去水、去配体冗余链，保留 GTP 与 Mg2+；用 pdb2gmx 加氢
# 配体肽：取对接最优构象（pep_018 对 6UNX）

gmx pdb2gmx -f complex.pdb -o complex.gro -water tip3p -ff charmm36m -ignh

# ---------- 1. 盒子与溶剂 ----------
gmx editconf -f complex.gro -o box.gro -c -d 1.2 -bt cubic
gmx solvate  -cp box.gro -cs spc216.gro -o solv.gro -p topol.top
gmx grompp   -f ions.mdp -c solv.gro -p topol.top -o ions.tpr -maxwarn 2
gmx genion   -s ions.tpr -o ions.gro -p topol.top -pname NA -nname CL -neutral -conc 0.15

# ---------- 2. 能量最小化 ----------
gmx grompp -f em.mdp -c ions.gro -p topol.top -o em.tpr
gmx mdrun  -v -deffnm em           # 收敛标准：Fmax < 1000 kJ/mol/nm

# ---------- 3. 两步平衡 ----------
gmx grompp -f nvt.mdp -c em.gro  -r em.gro  -p topol.top -o nvt.tpr
gmx mdrun  -deffnm nvt             # NVT 100 ps，位置限制 1000 kJ/mol/nm^2
gmx grompp -f npt.mdp -c nvt.gro -r nvt.gro -t nvt.cpt -p topol.top -o npt.tpr
gmx mdrun  -deffnm npt             # NPT 1 ns，逐步释放限制

# ---------- 4. 成产轨迹（3 次重复，改 gen_seed） ----------
for r in 1 2 3 ; do
  gmx grompp -f md.mdp -c npt.gro -t npt.cpt -p topol.top -o md_r${r}.tpr
  gmx mdrun  -deffnm md_r${r} -nb gpu -bonded gpu -pme gpu
done
```

`md.mdp` 关键项：`integrator = md`，`nsteps = 50000000`（100 ns），`dt = 0.002`，`nstxout-compressed = 5000`（每 10 ps 存一帧）。

---

## 5. 分析指标

| 指标 | 命令 | 判读 |
|---|---|---|
| 复合物 RMSD | `gmx rms -s md.tpr -f md.xtc -n index.ndx` | 后 50 ns 平台且波动 < 0.3 nm 视为稳定 |
| 残基 RMSF | `gmx rmsf -res` | 定位柔性界面残基 |
| 回转半径 | `gmx gyrate` | 肽的紧致度变化 |
| 氢键 | `gmx hbond -num -dist` | 统计肽–FtsZ 平均氢键数及寿命 |
| 接触面积 | `gmx sasa` 计算 ΔSASA | 埋藏面积反映界面规模 |
| 二级结构 | `gmx dssp`（或 DSSP） | 螺旋度随时间演化，对照 S2 自由肽基线 |
| 结合自由能 | `gmx_MMPBSA`（MM-PBSA / MM-GBSA）取后 30 ns，每 100 ps 取一帧 | 给出 ΔG_bind 及按残基能量分解 |
| 主成分分析 | `gmx covar` + `gmx anaeig` | 前两个主成分的自由能景观（FEL） |
| 膜体系专用 | `gmx density`（质量密度沿 z）、`gmx order`（脂质尾链序参数 S_CD）、每脂面积 APL、膜厚 | 判断插入深度与膜扰动程度 |

**结果呈现**：每个指标给出 3 次重复的均值 ± 标准差；关键构象用 PyMOL 出图并标注相互作用残基，风格沿用既有 SCI 组图套件。

---

## 6. 计算量与可行性

| 体系 | 原子数（估） | 单条 100 ns 用时（RTX 级单卡） |
|---|---|---|
| S1 肽–FtsZ | ~60,000 | 约 1–1.5 天 |
| S2 自由肽 | ~15,000 | 约 5 小时 |
| S3 肽–膜 | ~90,000 | 约 2–2.5 天 |

若算力受限，建议的最小可发表方案：**只做 S1 与 S3，各 3 × 100 ns**，并以 MM-PBSA 结合能 + 氢键占据率 + DSSP 螺旋度三项作为核心证据。

---

## 7. 方法学文献支撑

1. Di Somma A, et al. The antimicrobial peptide Temporin L impairs *E. coli* cell division by interacting with FtsZ and the divisome complex. *Biochim Biophys Acta Gen Subj*. 2020;1864:129606.
2. Schumacher MA, et al. Structures of *Escherichia coli* FtsZ. *Acta Crystallogr F Struct Biol Commun*. 2020;76:94-102. doi:10.1107/S2053230X20001132
3. Huang J, et al. CHARMM36m: an improved force field for folded and intrinsically disordered proteins. *Nat Methods*. 2017;14:71-73.
4. Abraham MJ, et al. GROMACS: High performance molecular simulations through multi-level parallelism from laptops to supercomputers. *SoftwareX*. 2015;1-2:19-25.
5. Jo S, Kim T, Iyer VG, Im W. CHARMM-GUI: a web-based graphical user interface for CHARMM. *J Comput Chem*. 2008;29:1859-1865.
6. Kumari R, Kumar R, Lynn A. g_mmpbsa — A GROMACS tool for high-throughput MM-PBSA calculations. *J Chem Inf Model*. 2014;54:1951-1962.
7. Wang Y, et al. Molecular dynamics simulations of human antimicrobial peptide LL-37 in model POPC and POPG lipid bilayers. *Int J Mol Sci*. 2018;19:1186.
8. Vesicle protrusion induced by antimicrobial peptides suggests common carpet mechanism for short antimicrobial peptides. *Sci Rep*. 2024;14:9668.
9. Trott O, Olson AJ. AutoDock Vina. *J Comput Chem*. 2010;31:455-461.（对接仅用于初筛排序）
