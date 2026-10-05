# Antimicrobial peptide docking report (AutoDock Vina baseline)

Run time: 2026-10-05 15:52:40

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

- Ligands: RDKit `MolFromFASTA`, explicit hydrogens, ETKDG conformers, UFF energy minimization; best conformer exported as a rigid heavy-atom peptide PDBQT (archived minimized PDB keeps hydrogens).
- Receptors: RCSB PDB first model; protein ATOM records retained; crystallographic waters, ions and hetero ligands removed; simple rigid receptor PDBQT generated.
- Search box: centered on crystallographic hetero/cofactor pocket when present; otherwise receptor center; 30 A cubic grid; Vina exhaustiveness 1 with one CPU to avoid Windows-memory failures for long peptide ligands.
- Replicates: 3 independent AutoDock Vina CLI seeds per peptide-target pair; the reported score is the mean of each replicate's best pose.
- Contacts/figures: residues within 4.0 A of the best selected pose are listed and labelled in figures/PyMOL scripts.

## Results: mean of three best Vina scores

| Organism | Target | PDB | Peptide | Mean best kcal/mol | SD | Best single |
|---|---|---:|---|---:|---:|---:|
| Escherichia coli | DNA gyrase B ATPase domain | 4DUH | FVNKLNRIIPVKGFSMR | -10.753 | 0.006 | -10.76 |
| Escherichia coli | FtsZ cell-division protein | 6UNX | FVNKLNRIIPVKGFSMR | -7.242 | 0.02 | -7.261 |
| Escherichia coli | DNA gyrase B ATPase domain | 4DUH | LISNTKKFGTAIASHR | -9.75 | 0.083 | -9.811 |
| Escherichia coli | FtsZ cell-division protein | 6UNX | LISNTKKFGTAIASHR | -8.793 | 0.022 | -8.819 |
| Escherichia coli | DNA gyrase B ATPase domain | 4DUH | ISLAIPLASKISGFTLALVKNAST | -8.172 | 0.413 | -8.642 |
| Escherichia coli | FtsZ cell-division protein | 6UNX | ISLAIPLASKISGFTLALVKNAST | 2.433 | 0.021 | 2.41 |
| Staphylococcus aureus | FtsZ cell-division protein | 5MN4 | FVNKLNRIIPVKGFSMR | 1.02 | 5.436 | -3.766 |
| Staphylococcus aureus | Sortase A transpeptidase | 1T2W | FVNKLNRIIPVKGFSMR | 197.733 | 13.378 | 186.2 |
| Staphylococcus aureus | FtsZ cell-division protein | 5MN4 | LISNTKKFGTAIASHR | -6.741 | 0.187 | -6.957 |
| Staphylococcus aureus | Sortase A transpeptidase | 1T2W | LISNTKKFGTAIASHR | 49.73 | 26.132 | 32.43 |
| Staphylococcus aureus | FtsZ cell-division protein | 5MN4 | ISLAIPLASKISGFTLALVKNAST | 0.548 | 0.055 | 0.495 |
| Staphylococcus aureus | Sortase A transpeptidase | 1T2W | ISLAIPLASKISGFTLALVKNAST | 605.833 | 443.85 | 288.3 |

## Selected complexes for result figures

| Organism | Peptide | Chosen target | Mean kcal/mol | Figure | Labelled residues |
|---|---|---|---:|---|---|
| Escherichia coli | FVNKLNRIIPVKGFSMR | ecoli_GyrB_4DUH | -10.753 | `E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\figures\ecoli_GyrB_4DUH__P1_FVNKLNRIIPVKGFSMR_best_complex.png` | A:GLU92(2.687A); B:LYS57(2.701A); B:THR163(2.738A); B:LYS162(3.124A); A:ASP17(3.127A); B:GLY54(3.139A); A:ARG20(3.161A); A:GLU86(3.174A); A:GLY15(3.201A); A:LEU16(3.247A) |
| Staphylococcus aureus | FVNKLNRIIPVKGFSMR | saureus_FtsZ_5MN4 | 1.02 | `E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\figures\saureus_FtsZ_5MN4__P1_FVNKLNRIIPVKGFSMR_best_complex.png` | A:MET179(1.911A); A:GLU139(2.932A); A:LEU170(3.044A); A:ALA138(3.083A); A:ARG143(3.138A); A:ALA73(3.257A); A:PHE136(3.411A); A:ALA182(3.876A); A:GLY72(3.897A); A:GLY21(3.997A) |
| Escherichia coli | LISNTKKFGTAIASHR | ecoli_GyrB_4DUH | -9.75 | `E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\figures\ecoli_GyrB_4DUH__P2_LISNTKKFGTAIASHR_best_complex.png` | B:ASP74(2.974A); B:THR163(3.001A); A:THR96(3.091A); A:GLY15(3.15A); B:GLU161(3.181A); A:ARG20(3.324A); B:LYS162(3.378A); A:LEU16(3.5A); A:ASP17(3.523A); A:GLU86(3.561A) |
| Staphylococcus aureus | LISNTKKFGTAIASHR | saureus_FtsZ_5MN4 | -6.741 | `E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\figures\saureus_FtsZ_5MN4__P2_LISNTKKFGTAIASHR_best_complex.png` | A:GLU139(2.47A); A:GLY21(2.71A); A:GLN48(2.833A); A:GLY70(2.969A); A:ASP46(2.981A); A:ARG143(2.992A); A:MET179(3.059A); A:PHE183(3.144A); A:MET180(3.232A); A:ALA138(3.282A) |
| Escherichia coli | ISLAIPLASKISGFTLALVKNAST | ecoli_GyrB_4DUH | -8.172 | `E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\figures\ecoli_GyrB_4DUH__P3_ISLAIPLASKISGFTLALVKNAST_best_complex.png` | A:ASP17(2.322A); A:VAL149(2.367A); B:ASP74(2.764A); B:GLU161(2.972A); B:HIS55(2.998A); A:GLU86(3.112A); A:GLU85(3.168A); A:VAL97(3.209A); B:LYS162(3.26A); B:GLY54(3.296A) |
| Staphylococcus aureus | ISLAIPLASKISGFTLALVKNAST | saureus_FtsZ_5MN4 | 0.548 | `E:\0github\git-sync\git-pull-arena-01a0ff69\results\docking\AMP_Docking_Vina_R255\figures\saureus_FtsZ_5MN4__P3_ISLAIPLASKISGFTLALVKNAST_best_complex.png` | A:ASN25(1.728A); A:MET179(2.373A); A:MET180(2.467A); A:ALA138(2.536A); A:GLY72(2.777A); A:ASP46(2.782A); A:GLY21(2.921A); A:GLY70(2.961A); A:GLY104(3.041A); A:GLU139(3.064A) |

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
RECEPTOR_STANDARDIZATION_DONE=True
