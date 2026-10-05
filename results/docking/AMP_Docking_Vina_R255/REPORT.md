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
RECEPTOR_STANDARDIZATION_DONE=True
