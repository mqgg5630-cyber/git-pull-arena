reinitialize
load E:/0github/git-sync/git-pull-arena-01a0ff69/results/docking/AMP_Docking_Vina_R255/complexes_best_vina/all_12_complexes/K_saureus_SrtA_1T2W__P2_LISNTKKFGTAIASHR_complex_best.pdb, complex
remove solvent
hide everything
set retain_order, 1
set ray_opaque_background, off
set antialias, 2
set orthoscopic, on
set ambient, 0.55
set specular, 0.18
set shininess, 20
set cartoon_fancy_helices, 1
set stick_radius, 0.16
bg_color white
select peptide, chain L
select receptor, not chain L
select pocket, byres (receptor within 4.0 of peptide)
select contact_labels, (chain C and resi 77) or (chain C and resi 127) or (chain B and resi 82) or (chain C and resi 84) or (chain C and resi 82) or (chain A and resi 150) or (chain A and resi 206) or (chain A and resi 152) or (chain B and resi 127) or (chain A and resi 149) or (chain C and resi 79) or (chain C and resi 81)
show cartoon, receptor
color gray80, receptor
show sticks, peptide
color tv_red, peptide
show sticks, pocket
color cyan, pocket
set transparency, 0.10, receptor
orient receptor
zoom receptor, 6
png E:/0github/git-sync/git-pull-arena-01a0ff69/results/docking/AMP_Docking_Vina_R255/complexes_best_vina/visualizations/K_saureus_SrtA_1T2W__P2_LISNTKKFGTAIASHR_overview_clean.png, width=1200, height=900, dpi=300, ray=1
hide labels
show cartoon, receptor
color gray85, receptor
show surface, receptor
set transparency, 0.78, receptor
show sticks, peptide
color tv_red, peptide
show sticks, pocket
color cyan, pocket
distance hbonds, peptide, pocket, 3.6, 2
set dash_color, magenta
set dash_width, 2.5
set dash_gap, 0.35
set label_size, 18
set label_font_id, 7
set label_color, black
label contact_labels and name CA, resn+resi
orient peptide
zoom peptide or pocket, 5
png E:/0github/git-sync/git-pull-arena-01a0ff69/results/docking/AMP_Docking_Vina_R255/complexes_best_vina/visualizations/K_saureus_SrtA_1T2W__P2_LISNTKKFGTAIASHR_zoom_labelled.png, width=1400, height=900, dpi=300, ray=1
save E:/0github/git-sync/git-pull-arena-01a0ff69/results/docking/AMP_Docking_Vina_R255/complexes_best_vina/visualizations/K_saureus_SrtA_1T2W__P2_LISNTKKFGTAIASHR_vector.pse
quit
