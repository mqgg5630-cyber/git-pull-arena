# SCI Molecular Docking Publication Figures (Figure 4-4 FRPYL Paradigm)

Generated from: `all_12_complexes/`

## 1. 300 DPI Multi-Panel Composite Figures (`sci_composite_figures/`)

- **`Figure_4_Part1_A-F_300dpi.png`**: Panels A to F (E. coli FtsZ & GyrB against P1, P2, P3; 3x2 Grid, 300 DPI)
- **`Figure_4_Part2_G-L_300dpi.png`**: Panels G to L (S. aureus FtsZ & SrtA against P1, P2, P3; 3x2 Grid, 300 DPI)
- **`Figure_S1_12_Combined_300dpi.png`**: Complete 12-Complex Global Landscape (Panels A to L; 4x3 Grid, 300 DPI)

## 2. 5-Format Individual Complex Suites (`visualizations/`)

For each of the 12 complexes, 5 formats are generated:
1. `*_times.png`: High-resolution bitmap with Times New Roman Bold typography & anti-collision repulsive layout.
2. `*_clean.png`: 0-Text Clean 3D Rendering (Left 0% solid lavender, Right 80% ray-traced glass transparency).
3. `*_vector.svg`: 100% Vector Editable SVG for Adobe Illustrator / Microsoft PowerPoint.
4. `*_vector.pse`: Interactive 3D PyMOL session file for interactive rotation and inspection.
5. `*_labeled.png`: PyMOL default labeled comparison reference.

## 3. Physical PDB Separations (`split_pdbs/`)

- `*_pro.pdb`: Receptor protein structure (clean ATOM records, chain formatting preserved)
- `*_lig.pdb`: Peptide ligand structure (Chain L)

## 4. Visual Color Palette & Design Architecture

- **Receptor Overview (Left)**: Soft Silvery Lavender (`#C2C7E6`), 0% solid cartoon.
- **Receptor Zoomed (Right)**: Ray-traced 80% glass transparency (`transparency=0.80`, `transparency_mode=1`).
- **Peptide Ligand**: 100% pure warm solid orange sticks (`#EB8526`, radius 0.28).
- **Interacting Residues**: Pure bright cyan sticks (`#26CCD1`, radius 0.22).
- **Polar Contacts / H-bonds**: High-contrast vibrant rose-magenta dashed lines (`#D91A73`, native PyMOL mode=2).
