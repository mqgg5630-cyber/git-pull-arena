# AMP Vina docking task - round 255
time=2026-10-05 15:06:32 +08:00
host=LAPTOP-R77M5D6M

## Task scope
Peptides: FVNKLNRIIPVKGFSMR; LISNTKKFGTAIASHR; ISLAIPLASKISGFTLALVKNAST
Targets: E. coli FtsZ + GyrB, S. aureus FtsZ + Sortase A
Replicates: 3 Vina repeats per peptide-target pair; report mean of best scores.

desktop_probe=DESKTOP-IEUDGS5
pymol_mcp_path=E:\0mcp-agv\.agents\skills\pymol-mcp exists=True
execution_machine=laptop_or_current_watcher_machine

python=E:\spider\python.exe
python_version=3.11.9 | packaged by conda-forge | (main, Apr 19 2024, 18:27:10) [MSC v.1938 64 bit (AMD64)]
## Dependency setup
pip_core| python.exe :   WARNING: The script f2py.exe is installed in 'C:\Users\??\AppData\Roaming\Python\Python311\Scripts' whic
pip_core| h is not on PATH.
pip_core| ???? ?:1 ??: 2
pip_core| +  & $using:py -m pip install --user --upgrade --quiet "numpy==1.26.4"  ...
pip_core| +  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
pip_core|     + CategoryInfo          : NotSpecified: (  WARNING: The ...is not on PATH.:String) [], RemoteException
pip_core|     + FullyQualifiedErrorId : NativeCommandError
pip_core|   Consider adding this directory to PATH or, if you prefer to suppress this warning, use --no-warn-script-location.
pip_core| [notice] A new release of pip is available: 25.2 -> 26.2.1
pip_core| [notice] To update, run: E:\spider\python.exe -m pip install --upgrade pip
pip_rdkit| python.exe : 
pip_rdkit| ???? ?:1 ??: 2
pip_rdkit| +  & $using:py -m pip install --user --upgrade --quiet rdkit 2>&1 | Out ...
pip_rdkit| +  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
pip_rdkit|     + CategoryInfo          : NotSpecified: (:String) [], RemoteException
pip_rdkit|     + FullyQualifiedErrorId : NativeCommandError
pip_rdkit| [notice] A new release of pip is available: 25.2 -> 26.2.1
pip_rdkit| [notice] To update, run: E:\spider\python.exe -m pip install --upgrade pip
import| IMPORT_OK=True
DEPENDENCIES_OK=True
## AutoDock Vina CLI setup
vina_download|                                  Dload  Upload  Total   Spent   Left   Speed
vina_download|   0      0   0      0   0      0      0      0                              0
vina_download|   0      0   0      0   0      0      0      0                              0
vina_download|   0      0   0      0   0      0      0      0           00:01              0
vina_download|   0      0   0      0   0      0      0      0           00:01              0
vina_download|   0      0   0      0   0      0      0      0           00:01              0
vina_download|   0      0   0      0   0      0      0      0           00:01              0
vina_download| 100  1.17M 100  1.17M   0      0 472.0k      0   00:02   00:02              0
vina_download| 100  1.17M 100  1.17M   0      0 472.0k      0   00:02   00:02              0
vina_download| 100  1.17M 100  1.17M   0      0 472.0k      0   00:02   00:02              0
vina_sha256=e0c4b2715e0c1a74f6e92d0f3be0328ac97542eafbc111e6b1efad897a73cce5
vina| AutoDock Vina v1.2.7
VINA_EXE=C:\Users\??\AppData\Local\ArenaTools\vina\vina_1.2.7_win.exe
VINA_CLI_READY=True
## Docking run
dock| Error: insufficient memory!
dock| DOCK ecoli_GyrB_4DUH P1_FVNKLNRIIPVKGFSMR rep=1 seed=101298
dock| DOCK_FAIL ecoli_GyrB_4DUH P1_FVNKLNRIIPVKGFSMR: vina CLI failed code=1; see E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\poses\ecoli_GyrB_4DUH\P1_FVNKLNRIIPVKGFSMR\[REDACTED].log; tail=#############################################
dock| Scoring function : vina
dock| Rigid receptor: E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\pdbqt\ecoli_GyrB_4DUH_receptor.pdbqt
dock| Ligand: E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\pdbqt\[REDACTED].pdbqt
dock| Grid center: X 16.328 Y 3.494 Z 21.088
dock| Grid size  : X 30 Y 30 Z 30
dock| Grid space : 0.375
dock| Exhaustiveness: 6
dock| CPU: 0
dock| Verbosity: 1
dock| Error: insufficient memory!
dock| DOCK ecoli_GyrB_4DUH P2_LISNTKKFGTAIASHR rep=1 seed=101901
dock| DOCK_FAIL ecoli_GyrB_4DUH P2_LISNTKKFGTAIASHR: vina CLI failed code=1; see E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\poses\ecoli_GyrB_4DUH\P2_LISNTKKFGTAIASHR\[REDACTED].log; tail=##############################################
dock| Scoring function : vina
dock| Rigid receptor: E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\pdbqt\ecoli_GyrB_4DUH_receptor.pdbqt
dock| Ligand: E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\pdbqt\[REDACTED].pdbqt
dock| Grid center: X 16.328 Y 3.494 Z 21.088
dock| Grid size  : X 30 Y 30 Z 30
dock| Grid space : 0.375
dock| Exhaustiveness: 6
dock| CPU: 0
dock| Verbosity: 1
dock| Error: insufficient memory!
dock| DOCK ecoli_GyrB_4DUH P3_ISLAIPLASKISGFTLALVKNAST rep=1 seed=101440
dock| DOCK_FAIL ecoli_GyrB_4DUH P3_ISLAIPLASKISGFTLALVKNAST: vina CLI failed code=1; see E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\poses\ecoli_GyrB_4DUH\P3_ISLAIPLASKISGFTLALVKNAST\[REDACTED].log; tail=######################################
dock| Scoring function : vina
dock| Rigid receptor: E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\pdbqt\ecoli_GyrB_4DUH_receptor.pdbqt
dock| Ligand: E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\pdbqt\[REDACTED].pdbqt
dock| Grid center: X 16.328 Y 3.494 Z 21.088
dock| Grid size  : X 30 Y 30 Z 30
dock| Grid space : 0.375
dock| Exhaustiveness: 6
dock| CPU: 0
dock| Verbosity: 1
dock| Error: insufficient memory!
dock| DOCK saureus_FtsZ_5MN4 P1_FVNKLNRIIPVKGFSMR rep=1 seed=101832
dock| DOCK_FAIL saureus_FtsZ_5MN4 P1_FVNKLNRIIPVKGFSMR: vina CLI failed code=1; see E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\poses\saureus_FtsZ_5MN4\P1_FVNKLNRIIPVKGFSMR\[REDACTED].log; tail=#########################################
dock| Scoring function : vina
dock| Rigid receptor: E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\pdbqt\saureus_FtsZ_5MN4_receptor.pdbqt
dock| Ligand: E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\pdbqt\[REDACTED].pdbqt
dock| Grid center: X -18.685 Y -8.098 Z 20.172
dock| Grid size  : X 30 Y 30 Z 30
dock| Grid space : 0.375
dock| Exhaustiveness: 6
dock| CPU: 0
dock| Verbosity: 1
dock| Error: insufficient memory!
dock| DOCK saureus_FtsZ_5MN4 P2_LISNTKKFGTAIASHR rep=1 seed=101488
dock| DOCK_FAIL saureus_FtsZ_5MN4 P2_LISNTKKFGTAIASHR: vina CLI failed code=1; see E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\poses\saureus_FtsZ_5MN4\P2_LISNTKKFGTAIASHR\[REDACTED].log; tail=##########################################
dock| Scoring function : vina
dock| Rigid receptor: E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\pdbqt\saureus_FtsZ_5MN4_receptor.pdbqt
dock| Ligand: E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\pdbqt\[REDACTED].pdbqt
dock| Grid center: X -18.685 Y -8.098 Z 20.172
dock| Grid size  : X 30 Y 30 Z 30
dock| Grid space : 0.375
dock| Exhaustiveness: 6
dock| CPU: 0
dock| Verbosity: 1
dock| Error: insufficient memory!
dock| DOCK saureus_FtsZ_5MN4 P3_ISLAIPLASKISGFTLALVKNAST rep=1 seed=101737
dock| DOCK_FAIL saureus_FtsZ_5MN4 P3_ISLAIPLASKISGFTLALVKNAST: vina CLI failed code=1; see E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\poses\saureus_FtsZ_5MN4\P3_ISLAIPLASKISGFTLALVKNAST\[REDACTED].log; tail=##################################
dock| Scoring function : vina
dock| Rigid receptor: E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\pdbqt\saureus_FtsZ_5MN4_receptor.pdbqt
dock| Ligand: E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\pdbqt\[REDACTED].pdbqt
dock| Grid center: X -18.685 Y -8.098 Z 20.172
dock| Grid size  : X 30 Y 30 Z 30
dock| Grid space : 0.375
dock| Exhaustiveness: 6
dock| CPU: 0
dock| Verbosity: 1
dock| Error: insufficient memory!
dock| DOCK saureus_SrtA_1T2W P1_FVNKLNRIIPVKGFSMR rep=1 seed=101412
dock| DOCK_FAIL saureus_SrtA_1T2W P1_FVNKLNRIIPVKGFSMR: vina CLI failed code=1; see E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\poses\saureus_SrtA_1T2W\P1_FVNKLNRIIPVKGFSMR\[REDACTED].log; tail=########################################
dock| Scoring function : vina
dock| Rigid receptor: E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\pdbqt\saureus_SrtA_1T2W_receptor.pdbqt
dock| Ligand: E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\pdbqt\[REDACTED].pdbqt
dock| Grid center: X -14.35 Y -20.951 Z -11.198
dock| Grid size  : X 52 Y 52 Z 52
dock| Grid space : 0.375
dock| Exhaustiveness: 6
dock| CPU: 0
dock| Verbosity: 1
dock| Error: insufficient memory!
dock| DOCK saureus_SrtA_1T2W P2_LISNTKKFGTAIASHR rep=1 seed=101701
dock| DOCK_FAIL saureus_SrtA_1T2W P2_LISNTKKFGTAIASHR: vina CLI failed code=1; see E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\poses\saureus_SrtA_1T2W\P2_LISNTKKFGTAIASHR\[REDACTED].log; tail=#########################################
dock| Scoring function : vina
dock| Rigid receptor: E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\pdbqt\saureus_SrtA_1T2W_receptor.pdbqt
dock| Ligand: E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\pdbqt\[REDACTED].pdbqt
dock| Grid center: X -14.35 Y -20.951 Z -11.198
dock| Grid size  : X 52 Y 52 Z 52
dock| Grid space : 0.375
dock| Exhaustiveness: 6
dock| CPU: 0
dock| Verbosity: 1
dock| Error: insufficient memory!
dock| DOCK saureus_SrtA_1T2W P3_ISLAIPLASKISGFTLALVKNAST rep=1 seed=101089
dock| DOCK_FAIL saureus_SrtA_1T2W P3_ISLAIPLASKISGFTLALVKNAST: vina CLI failed code=1; see E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\poses\saureus_SrtA_1T2W\P3_ISLAIPLASKISGFTLALVKNAST\[REDACTED].log; tail=#################################
dock| Scoring function : vina
dock| Rigid receptor: E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\pdbqt\saureus_SrtA_1T2W_receptor.pdbqt
dock| Ligand: E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\pdbqt\[REDACTED].pdbqt
dock| Grid center: X -14.35 Y -20.951 Z -11.198
dock| Grid size  : X 52 Y 52 Z 52
dock| Grid space : 0.375
dock| Exhaustiveness: 6
dock| CPU: 0
dock| Verbosity: 1
dock| Error: insufficient memory!
dock| python.exe : E:\0github\git-sync\git-pull-arena-01a0ff69\code\tasks\peptide_vina_pipeline.py:473: RuntimeWarning: Mean 
dock| of empty slice
dock| ???? ?:1 ??: 34
dock| + ... using:vinaExe; & $using:py $using:pipeline $using:outDir 2>&1 | Out-S ...
dock| +                    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
dock|     + CategoryInfo          : NotSpecified: (E:\0github\git-... of empty slice:String) [], RemoteException
dock|     + FullyQualifiedErrorId : NativeCommandError
dock|   ax.text(j, i, f"{mat[i,j]:.2f}", ha="center", va="center", color="white" if mat[i,j] < np.nanmean(mat) else "black", 
dock| fontsize=8)
dock| REPORT=E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\REPORT.md
dock| DOCKING_PIPELINE_DONE=True
pipeline_ok=True
desktop_result_folder=D:\??\[REDACTED]

## Pipeline report excerpt
# Antimicrobial peptide docking report (AutoDock Vina baseline)

Run time: 2026-10-05 15:22:57

## Peptides

- P1_FVNKLNRIIPVKGFSMR: `FVNKLNRIIPVKGFSMR`
- P2_LISNTKKFGTAIASHR: `LISNTKKFGTAIASHR`
- P3_ISLAIPLASKISGFTLALVKNAST: `ISLAIPLASKISGFTLALVKNAST`

## Targets

- Escherichia coli: FtsZ cell-division protein, PDB `6UNX` (E. coli FtsZ GTP-complex active-site/grid around cofactor if present)
- Escherichia coli: DNA gyrase B ATPase domain, PDB `4DUH` (E. coli GyrB ATPase domain inhibitor pocket)
- Staphylococcus aureus: FtsZ cell-division protein, PDB `5MN4` (S. aureus FtsZ open/GDP form)
- Staphylococcus aureus: Sortase A transpeptidase, PDB `1T2W` (S. aureus Sortase A substrate-bound structure)

## Method summary

- Ligands: RDKit `MolFromFASTA`, explicit hydrogens, ETKDG conformers, UFF energy minimization; best conformer docked as rigid peptide PDBQT.
- Receptors: RCSB PDB first model; protein ATOM records retained; crystallographic waters, ions and hetero ligands removed; simple rigid receptor PDBQT generated.
- Search box: centered on crystallographic hetero/cofactor pocket when present; otherwise receptor center; Vina exhaustiveness 6.
- Replicates: 3 independent AutoDock Vina CLI seeds per peptide-target pair; the reported score is the mean of each replicate's best pose.
- Contacts/figures: residues within 4.0 A of the best selected pose are listed and labelled in figures/PyMOL scripts.

## Results: mean of three best Vina scores

| Organism | Target | PDB | Peptide | Mean best kcal/mol | SD | Best single |
|---|---|---:|---|---:|---:|---:|

## Selected complexes for result figures

| Organism | Peptide | Chosen target | Mean kcal/mol | Figure | Labelled residues |
|---|---|---|---:|---|---|

## Important limitations

Vina is not a dedicated flexible peptide-protein docking engine. This run is a reproducible, open-source baseline: minimized peptide conformers are docked rigidly to standardized receptors. For publication-level claims, follow-up flexible peptide docking and MD/MM-GBSA validation are recommended.

## Output paths

- Root: `E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255`
- Summary CSV: `E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\tables\vina_summary_mean_of_3.csv`
- Heatmap: `E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\figures\vina_affinity_heatmap.png`
- PyMOL detected: `E:\spider\Scripts\pymol.EXE`

DOCKING_PIPELINE_DONE=True
VINA_REPEATS_PER_PAIR=3
ENERGY_MINIMIZATION_DONE=True
[REDACTED]

repo_result_folder=E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255
repo_report=E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\REPORT.md
DOCKING_PIPELINE_DONE=True
VINA_REPEATS_PER_PAIR=3
ENERGY_MINIMIZATION_DONE=True
RECEPTOR_STANDARDIZATION_DONE=True
AMP_DOCKING_DONE=True
