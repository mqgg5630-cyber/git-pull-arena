reinitialize
load E:/0github/git-sync/git-pull-arena-01a0ff69/results/docking/AMP_Docking_Vina_R255/complexes/saureus_FtsZ_5MN4__P1_FVNKLNRIIPVKGFSMR_best_complex.pdb, complex
hide everything
select peptide, chain L
select receptor, not chain L
show cartoon, receptor
color gray70, receptor
show sticks, peptide
color cyan, peptide
select contact_residues, (chain A and resi 179) or (chain A and resi 139) or (chain A and resi 170) or (chain A and resi 138) or (chain A and resi 143) or (chain A and resi 73) or (chain A and resi 136) or (chain A and resi 182) or (chain A and resi 72) or (chain A and resi 21) or (chain A and resi 46)
show sticks, contact_residues
color orange, contact_residues
set label_size, 18
set label_color, black
label contact_residues and name CA, resn+resi
bg_color white
orient peptide
zoom peptide or contact_residues, 8
set ray_opaque_background, off
png E:/0github/git-sync/git-pull-arena-01a0ff69/results/docking/AMP_Docking_Vina_R255/figures/saureus_FtsZ_5MN4__P1_FVNKLNRIIPVKGFSMR_best_complex.png, width=2200, height=1600, dpi=300, ray=1
save E:/0github/git-sync/git-pull-arena-01a0ff69/results/docking/AMP_Docking_Vina_R255/figures/saureus_FtsZ_5MN4__P1_FVNKLNRIIPVKGFSMR_best_complex.pse
quit
