reinitialize
load E:/0github/git-sync/git-pull-arena-01a0ff69/results/docking/AMP_Docking_Vina_R255/complexes/ecoli_GyrB_4DUH__P2_LISNTKKFGTAIASHR_best_complex.pdb, complex
hide everything
select peptide, chain L
select receptor, not chain L
show cartoon, receptor
color gray70, receptor
show sticks, peptide
color cyan, peptide
select contact_residues, (chain B and resi 74) or (chain B and resi 163) or (chain A and resi 96) or (chain A and resi 15) or (chain B and resi 161) or (chain A and resi 20) or (chain B and resi 162) or (chain A and resi 16) or (chain A and resi 17) or (chain A and resi 86) or (chain A and resi 149) or (chain A and resi 88)
show sticks, contact_residues
color orange, contact_residues
set label_size, 18
set label_color, black
label contact_residues and name CA, resn+resi
bg_color white
orient peptide
zoom peptide or contact_residues, 8
set ray_opaque_background, off
png E:/0github/git-sync/git-pull-arena-01a0ff69/results/docking/AMP_Docking_Vina_R255/figures/ecoli_GyrB_4DUH__P2_LISNTKKFGTAIASHR_best_complex.png, width=2200, height=1600, dpi=300, ray=1
save E:/0github/git-sync/git-pull-arena-01a0ff69/results/docking/AMP_Docking_Vina_R255/figures/ecoli_GyrB_4DUH__P2_LISNTKKFGTAIASHR_best_complex.pse
quit
