# 抗菌肽分子对接：靶点选择依据、方法学文献支持与结果记录

生成时间：2026-10-05 17:49:52

## 1. 研究对象与输出概览

本轮对三条抗菌肽进行开放源代码 AutoDock Vina 基线分子对接，并围绕 *Escherichia coli* 与 *Staphylococcus aureus* 各选择两个与抗菌作用高度相关的蛋白靶点。每个 peptide-target pair 进行 3 次独立 Vina seed 重复，报告每次最佳构象分数的均值。

肽序列：
- `FVNKLNRIIPVKGFSMR`
- `LISNTKKFGTAIASHR`
- `ISLAIPLASKISGFTLALVKNAST`

主要输出：
- `tables/vina_summary_mean_of_3.csv`：12 个 peptide-target pair 的 3 次重复均值。
- `tables/vina_repeats.csv`：36 条重复对接记录。
- `complexes_best_vina/sci_composite_figures/`：按 SCI 图件风格排版的 PyMOL 复合图。
- `AMP_Docking_Targets_Methods_Results.docx`：与本 Markdown 同内容的 Word 报告。

## 2. 靶点选择原因与文献支持

| 病原体 | 靶点/PDB | 选择原因 | 结构选择依据 | 文献支持 |
|---|---|---|---|---|
| *Escherichia coli* | FtsZ cell-division protein / `6UNX` | FtsZ is an essential tubulin-like bacterial cytokinesis protein. It organizes the Z-ring/divisome; perturbing this process is a recognized antimicrobial strategy and peptide-FtsZ interactions have been experimentally implicated for antimicrobial peptides. | 6UNX is a high-resolution E. coli FtsZ(L178E)-GTP crystal structure, suitable for a nucleotide-pocket/assembly-core baseline docking model. | Schumacher et al., 2020; de Boer et al., 1992; RayChaudhuri and Park, 1992; Di Somma et al., 2020. |
| *Escherichia coli* | DNA gyrase B ATPase domain / `4DUH` | DNA gyrase is essential for bacterial DNA topology, replication and transcription. The GyrB N-terminal ATPase pocket is a validated antibacterial target distinct from quinolone GyrA cleavage-complex chemistry, making it attractive for orthogonal antimicrobial screening. | 4DUH is the 24 kDa E. coli GyrB ATPase domain co-crystallized with a small-molecule inhibitor, providing a defined inhibitor/ATP pocket for grid placement. | Brvar et al., 2012; Maxwell and Lawson, 2011. |
| *Staphylococcus aureus* | FtsZ cell-division protein / `5MN4` | S. aureus FtsZ is an essential cell-division target with extensive anti-staphylococcal inhibitor precedent, including benzamide/TXA-series compounds and synergy with beta-lactams in MRSA models. | 5MN4 is a 1.5 A S. aureus FtsZ 12-316 GDP open-form crystal structure from the polymerization-associated conformational-switch study, making it appropriate for a SaFtsZ structural baseline. | Wagstaff et al., 2017; Haydon et al., 2008; Ferrer-Gonzalez et al., 2021. |
| *Staphylococcus aureus* | Sortase A transpeptidase / `1T2W` | Sortase A anchors LPXTG-containing surface proteins to the Gram-positive cell wall. Because these surface proteins mediate adhesion, biofilm and virulence, SrtA is commonly treated as an antivirulence/anti-infective target for S. aureus. | 1T2W is a crystal structure of S. aureus Sortase A in complex with an LPETG sorting peptide. The co-bound substrate peptide provides a biologically interpretable active-site reference. | Zong et al., 2004; Bentley et al., 2008; Shulga and Kudryavtsev, 2022. |

## 3. 方法学与文献支持

1. **受体标准化**：从 RCSB PDB 获取晶体结构；保留 first model 的 protein ATOM 记录，移除结晶水、离子及共晶小分子，输出 rigid receptor PDBQT。该处理对应常规 docking 前处理流程，目的是使不同靶点处于一致、可复现的输入状态。
2. **肽配体构建与能量最小化**：使用 RDKit `MolFromFASTA` 从序列构建肽分子，加氢，使用 ETKDGv3 生成 3D conformers，并用 UFF 分子力场优化，取最低 UFF energy 构象作为 rigid peptide baseline。ETKDG 和 UFF 的方法学文献分别为 Riniker & Landrum 2015 以及 Rappe et al. 1992。
3. **对接引擎**：采用 AutoDock Vina 1.2.7 CLI。Vina 是常用开源 docking 引擎，原始算法与评分函数见 Trott & Olson 2010，Vina 1.2 系列更新见 Eberhardt et al. 2021。
4. **重复设置**：每个 peptide-target pair 进行 3 个独立 seed 的 docking，汇总每次 docking 的最佳 pose score，计算 mean、SD 与 best single score。
5. **结合位点与可视化**：对最终 best pose 计算 4 Å 以内受体残基，并使用 PyMOL headless 渲染。每个 SCI panel 包含 receptor overview 与 4 Å contact zoom，肽以红色棒状表示，接触残基以青色棒状表示，可能氢键以品红虚线表示，残基标签直接标注在局部图中。

## 4. 对接结果记录

重复记录数：36；汇总行数：12。

| 病原体 | 靶点 | PDB | 肽序列 | n | Mean best (kcal/mol) | SD | Best single |
|---|---|---:|---|---:|---:|---:|---:|
| *Escherichia coli* | FtsZ cell-division protein | `6UNX` | `FVNKLNRIIPVKGFSMR` | 3 | -7.242 | 0.02 | -7.261 |
| *Escherichia coli* | FtsZ cell-division protein | `6UNX` | `LISNTKKFGTAIASHR` | 3 | -8.793 | 0.022 | -8.819 |
| *Escherichia coli* | FtsZ cell-division protein | `6UNX` | `ISLAIPLASKISGFTLALVKNAST` | 3 | 2.433 | 0.021 | 2.41 |
| *Escherichia coli* | DNA gyrase B ATPase domain | `4DUH` | `FVNKLNRIIPVKGFSMR` | 3 | -10.753 | 0.006 | -10.76 |
| *Escherichia coli* | DNA gyrase B ATPase domain | `4DUH` | `LISNTKKFGTAIASHR` | 3 | -9.75 | 0.083 | -9.811 |
| *Escherichia coli* | DNA gyrase B ATPase domain | `4DUH` | `ISLAIPLASKISGFTLALVKNAST` | 3 | -8.172 | 0.413 | -8.642 |
| *Staphylococcus aureus* | FtsZ cell-division protein | `5MN4` | `FVNKLNRIIPVKGFSMR` | 3 | 1.02 | 5.436 | -3.766 |
| *Staphylococcus aureus* | FtsZ cell-division protein | `5MN4` | `LISNTKKFGTAIASHR` | 3 | -6.741 | 0.187 | -6.957 |
| *Staphylococcus aureus* | FtsZ cell-division protein | `5MN4` | `ISLAIPLASKISGFTLALVKNAST` | 3 | 0.548 | 0.055 | 0.495 |
| *Staphylococcus aureus* | Sortase A transpeptidase | `1T2W` | `FVNKLNRIIPVKGFSMR` | 3 | 197.733 | 13.378 | 186.2 |
| *Staphylococcus aureus* | Sortase A transpeptidase | `1T2W` | `LISNTKKFGTAIASHR` | 3 | 49.73 | 26.132 | 32.43 |
| *Staphylococcus aureus* | Sortase A transpeptidase | `1T2W` | `ISLAIPLASKISGFTLALVKNAST` | 3 | 605.833 | 443.85 | 288.3 |

### 4.1 每条肽在每个病原体内的较优靶点

| 病原体 | 肽序列 | 较优靶点 | Mean best (kcal/mol) | 主要 4 Å 接触残基 |
|---|---|---|---:|---|
| *Escherichia coli* | `FVNKLNRIIPVKGFSMR` | `ecoli_GyrB_4DUH` | -10.753 | B:LYS57(2.924A); A:GLY15(3.201A); B:GLU161(3.256A); A:GLU92(3.312A); B:ASP74(3.415A); A:ASP17(3.465A); A:VAL149(3.526A); A:LEU16(3.567A); B:GLY138(3.606A); B:LYS162(3.711A) |
| *Staphylococcus aureus* | `FVNKLNRIIPVKGFSMR` | `saureus_FtsZ_5MN4` | 1.02 | A:MET179(1.911A); A:GLU139(3.059A); A:LEU170(3.065A); A:ALA138(3.106A); A:ARG143(3.256A); A:ALA73(3.257A); A:PHE136(3.411A); A:ALA182(3.876A); A:GLY72(3.904A); A:GLY21(3.997A) |
| *Escherichia coli* | `LISNTKKFGTAIASHR` | `ecoli_GyrB_4DUH` | -9.75 | B:ASP74(2.974A); B:THR163(3.001A); B:GLU161(3.181A); A:GLY15(3.185A); A:ARG20(3.324A); B:LYS162(3.378A); A:LEU16(3.5A); A:ASP17(3.523A); A:GLU86(3.561A); A:VAL149(3.589A) |
| *Staphylococcus aureus* | `LISNTKKFGTAIASHR` | `saureus_FtsZ_5MN4` | -6.741 | A:GLY21(2.71A); A:GLY70(2.969A); A:ARG143(3.2A); A:MET179(3.346A); A:ALA49(3.35A); A:ALA73(3.353A); A:GLY72(3.402A); A:ASN24(3.421A); A:GLU139(3.454A); A:ASN44(3.495A) |
| *Escherichia coli* | `ISLAIPLASKISGFTLALVKNAST` | `ecoli_GyrB_4DUH` | -8.172 | A:VAL149(2.367A); A:GLU86(3.112A); B:GLU161(3.149A); A:GLU85(3.168A); B:ASP74(3.248A); B:LYS162(3.26A); B:GLY54(3.296A); B:HIS55(3.369A); B:LYS57(3.429A); A:VAL97(3.551A) |
| *Staphylococcus aureus* | `ISLAIPLASKISGFTLALVKNAST` | `saureus_FtsZ_5MN4` | 0.548 | A:ASN25(1.728A); A:MET179(2.373A); A:MET180(2.467A); A:ALA138(2.536A); A:GLY72(2.777A); A:ASP46(2.782A); A:GLY21(2.921A); A:GLY70(2.961A); A:GLY104(3.041A); A:GLU139(3.064A) |

结果解释：在本 rigid-peptide Vina baseline 中，三条肽对 *E. coli* 的较优目标均为 GyrB ATPase domain（4DUH）。对 *S. aureus*，三条肽均更倾向 FtsZ（5MN4），而 Sortase A（1T2W）出现正值或极高 Vina score，提示在当前刚性肽构象和固定受体网格下拟合较差；该现象应作为筛选提示而非物理结合自由能。

## 5. SCI 图件输出

- `complexes_best_vina/sci_composite_figures/Figure_4_Part1_A-F_300dpi.png`：A-F 六个复合物面板。
- `complexes_best_vina/sci_composite_figures/Figure_4_Part2_G-L_300dpi.png`：G-L 六个复合物面板。
- `complexes_best_vina/sci_composite_figures/Figure_S1_12_Combined_300dpi.png`：12 个复合物总览补充图。

## 6. 局限性

AutoDock Vina 不是专用的 flexible peptide-protein docking 引擎。本结果适合作为可复现、开放源代码的初筛记录：肽构象经 RDKit/UFF 最小化后作为 rigid ligand dock 到标准化 receptor。若用于投稿或机制结论，建议增加 flexible peptide docking、分子动力学、MM/GBSA 或实验结合/抑菌验证。

## 7. 参考文献

1. de Boer, P. A. J.; Crossley, R. E.; Rothfield, L. I. The essential bacterial cell-division protein FtsZ is a GTPase. Nature 1992, 359, 254-256.
2. RayChaudhuri, D.; Park, J. T. Escherichia coli cell-division gene ftsZ encodes a novel GTP-binding protein. Nature 1992, 359, 251-254.
3. Schumacher, M. A.; Ohashi, T.; Corbin, L.; Erickson, H. P. High-resolution crystal structures of Escherichia coli FtsZ bound to GDP and GTP. Acta Crystallogr. F 2020, 76, 94-102. DOI: 10.1107/S2053230X20001132. PDB: 6UNX.
4. Di Somma, A.; Moretta, A.; Canè, C.; Cirillo, A.; Duilio, A. The antimicrobial peptide Temporin L impairs E. coli cell division by interacting with FtsZ and the divisome complex. Biochim. Biophys. Acta Biomembr. 2020, 1862, 183310.
5. Brvar, M.; Perdih, A.; Renko, M.; Anderluh, G.; Turk, D.; Solmajer, T. Structure-based discovery of substituted 4,5'-bithiazoles as novel DNA gyrase inhibitors. J. Med. Chem. 2012, 55, 6413-6426. DOI: 10.1021/jm300395d. PDB: 4DUH.
6. Maxwell, A.; Lawson, D. M. The ATP-binding site of type II topoisomerases as a target for antibacterial drugs. Curr. Top. Med. Chem. 2003, 3, 283-303; see also DNA gyrase drug-target reviews.
7. Haydon, D. J.; Stokes, N. R.; Ure, R.; Galbraith, G.; Bennett, J. M.; Brown, D. R.; et al. An inhibitor of FtsZ with potent and selective anti-staphylococcal activity. Science 2008, 321, 1673-1675.
8. Wagstaff, J. M.; Tsim, M.; Oliva, M. A.; Garcia-Sanchez, A.; Kureisaite-Ciziene, D.; Andreu, J. M.; Lowe, J. A polymerization-associated structural switch in FtsZ that enables treadmilling of model filaments. mBio 2017, 8, e00254-17. DOI: 10.1128/mBio.00254-17. PDB: 5MN4.
9. Ferrer-Gonzalez, E.; Huh, H.; Al-Tameemi, H. M.; Boyd, J. M.; Lee, S. H.; Pilch, D. S. Impact of FtsZ inhibition on the localization of the penicillin binding proteins in methicillin-resistant Staphylococcus aureus. J. Bacteriol. 2021, 203, e00204-21.
10. Zong, Y.; Bice, T. W.; Ton-That, H.; Schneewind, O.; Narayana, S. V. L. Crystal structures of Staphylococcus aureus sortase A and its substrate complex. J. Biol. Chem. 2004, 279, 31383-31389. DOI: 10.1074/jbc.M401374200. PDB: 1T2W.
11. Bentley, M. L.; Lamb, E. C.; McCafferty, D. G. Mutagenesis studies of substrate recognition and catalysis in the Sortase A transpeptidase from Staphylococcus aureus. J. Biol. Chem. 2008, 283, 14762-14771.
12. Shulga, D. A.; Kudryavtsev, K. V. Theoretical studies of Leu-Pro-Arg-Asp-Ala pentapeptide (LPRDA) binding to Sortase A of Staphylococcus aureus. Molecules 2022, 27, 8182.
13. Trott, O.; Olson, A. J. AutoDock Vina: improving the speed and accuracy of docking with a new scoring function, efficient optimization, and multithreading. J. Comput. Chem. 2010, 31, 455-461. DOI: 10.1002/jcc.21334.
14. Eberhardt, J.; Santos-Martins, D.; Tillack, A. F.; Forli, S. AutoDock Vina 1.2.0: new docking methods, expanded force field, and Python bindings. J. Chem. Inf. Model. 2021, 61, 3891-3898. DOI: 10.1021/acs.jcim.1c00203.
15. Riniker, S.; Landrum, G. A. Better informed distance geometry: using what we know to improve conformation generation. J. Chem. Inf. Model. 2015, 55, 2562-2574. DOI: 10.1021/acs.jcim.5b00654.
16. Rappe, A. K.; Casewit, C. J.; Colwell, K. S.; Goddard, W. A. III; Skiff, W. M. UFF, a full periodic table force field for molecular mechanics and molecular dynamics simulations. J. Am. Chem. Soc. 1992, 114, 10024-10035.

---
AMP_DOC_REPORT_DONE=True
VINA_REPEATS_PER_PAIR=3
SCI_COMPOSITE_FIGURES_DONE=True
