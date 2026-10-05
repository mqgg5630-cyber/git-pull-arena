#!/usr/bin/env python3
"""Build literature-backed AMP docking report and SCI-style PyMOL figures.

This post-processing script is intentionally self-contained so it can run on the
Windows watcher where PyMOL is installed.  It reads the completed round-255 Vina
outputs and writes:
  - AMP_Docking_Targets_Methods_Results.md
  - AMP_Docking_Targets_Methods_Results.docx
  - complexes_best_vina/sci_composite_figures/*.png

The figures follow the user's PyMOL-MCP example at a practical scale: each panel
contains a receptor overview and a labelled 4 A binding-site close-up, then the
panels are assembled into Part1 A-F, Part2 G-L and a 12-panel supplemental grid.
"""
from __future__ import annotations

import csv
import json
import math
import os
import shutil
import subprocess
import sys
import textwrap
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

try:
    from PIL import Image, ImageDraw, ImageFont
except Exception as exc:  # pragma: no cover
    print(f"IMPORT_ERROR: pillow unavailable: {exc}", file=sys.stderr)
    raise

try:
    from docx import Document
    from docx.shared import Inches, Pt
except Exception as exc:  # pragma: no cover
    print(f"IMPORT_ERROR: python-docx unavailable: {exc}", file=sys.stderr)
    raise


@dataclass
class TargetInfo:
    key: str
    organism: str
    protein: str
    pdb_id: str
    reason: str
    structure_reason: str
    literature: str


TARGET_INFO: Dict[str, TargetInfo] = {
    "ecoli_FtsZ_6UNX": TargetInfo(
        key="ecoli_FtsZ_6UNX",
        organism="Escherichia coli",
        protein="FtsZ cell-division protein",
        pdb_id="6UNX",
        reason=("FtsZ is an essential tubulin-like bacterial cytokinesis protein. "
                "It organizes the Z-ring/divisome; perturbing this process is a "
                "recognized antimicrobial strategy and peptide-FtsZ interactions have "
                "been experimentally implicated for antimicrobial peptides."),
        structure_reason=("6UNX is a high-resolution E. coli FtsZ(L178E)-GTP crystal "
                          "structure, suitable for a nucleotide-pocket/assembly-core "
                          "baseline docking model."),
        literature=("Schumacher et al., 2020; de Boer et al., 1992; RayChaudhuri "
                    "and Park, 1992; Di Somma et al., 2020."),
    ),
    "ecoli_GyrB_4DUH": TargetInfo(
        key="ecoli_GyrB_4DUH",
        organism="Escherichia coli",
        protein="DNA gyrase B ATPase domain",
        pdb_id="4DUH",
        reason=("DNA gyrase is essential for bacterial DNA topology, replication and "
                "transcription. The GyrB N-terminal ATPase pocket is a validated "
                "antibacterial target distinct from quinolone GyrA cleavage-complex "
                "chemistry, making it attractive for orthogonal antimicrobial screening."),
        structure_reason=("4DUH is the 24 kDa E. coli GyrB ATPase domain co-crystallized "
                          "with a small-molecule inhibitor, providing a defined inhibitor/ATP "
                          "pocket for grid placement."),
        literature="Brvar et al., 2012; Maxwell and Lawson, 2011.",
    ),
    "saureus_FtsZ_5MN4": TargetInfo(
        key="saureus_FtsZ_5MN4",
        organism="Staphylococcus aureus",
        protein="FtsZ cell-division protein",
        pdb_id="5MN4",
        reason=("S. aureus FtsZ is an essential cell-division target with extensive "
                "anti-staphylococcal inhibitor precedent, including benzamide/TXA-series "
                "compounds and synergy with beta-lactams in MRSA models."),
        structure_reason=("5MN4 is a 1.5 A S. aureus FtsZ 12-316 GDP open-form crystal "
                          "structure from the polymerization-associated conformational-switch "
                          "study, making it appropriate for a SaFtsZ structural baseline."),
        literature="Wagstaff et al., 2017; Haydon et al., 2008; Ferrer-Gonzalez et al., 2021.",
    ),
    "saureus_SrtA_1T2W": TargetInfo(
        key="saureus_SrtA_1T2W",
        organism="Staphylococcus aureus",
        protein="Sortase A transpeptidase",
        pdb_id="1T2W",
        reason=("Sortase A anchors LPXTG-containing surface proteins to the Gram-positive "
                "cell wall. Because these surface proteins mediate adhesion, biofilm and "
                "virulence, SrtA is commonly treated as an antivirulence/anti-infective "
                "target for S. aureus."),
        structure_reason=("1T2W is a crystal structure of S. aureus Sortase A in complex "
                          "with an LPETG sorting peptide. The co-bound substrate peptide "
                          "provides a biologically interpretable active-site reference."),
        literature="Zong et al., 2004; Bentley et al., 2008; Shulga and Kudryavtsev, 2022.",
    ),
}

PEPTIDE_ORDER = [
    "P1_FVNKLNRIIPVKGFSMR",
    "P2_LISNTKKFGTAIASHR",
    "P3_ISLAIPLASKISGFTLALVKNAST",
]
TARGET_ORDER = ["ecoli_FtsZ_6UNX", "ecoli_GyrB_4DUH", "saureus_FtsZ_5MN4", "saureus_SrtA_1T2W"]
LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

REFERENCE_TEXT = [
    "de Boer, P. A. J.; Crossley, R. E.; Rothfield, L. I. The essential bacterial cell-division protein FtsZ is a GTPase. Nature 1992, 359, 254-256.",
    "RayChaudhuri, D.; Park, J. T. Escherichia coli cell-division gene ftsZ encodes a novel GTP-binding protein. Nature 1992, 359, 251-254.",
    "Schumacher, M. A.; Ohashi, T.; Corbin, L.; Erickson, H. P. High-resolution crystal structures of Escherichia coli FtsZ bound to GDP and GTP. Acta Crystallogr. F 2020, 76, 94-102. DOI: 10.1107/S2053230X20001132. PDB: 6UNX.",
    "Di Somma, A.; Moretta, A.; Canè, C.; Cirillo, A.; Duilio, A. The antimicrobial peptide Temporin L impairs E. coli cell division by interacting with FtsZ and the divisome complex. Biochim. Biophys. Acta Biomembr. 2020, 1862, 183310.",
    "Brvar, M.; Perdih, A.; Renko, M.; Anderluh, G.; Turk, D.; Solmajer, T. Structure-based discovery of substituted 4,5'-bithiazoles as novel DNA gyrase inhibitors. J. Med. Chem. 2012, 55, 6413-6426. DOI: 10.1021/jm300395d. PDB: 4DUH.",
    "Maxwell, A.; Lawson, D. M. The ATP-binding site of type II topoisomerases as a target for antibacterial drugs. Curr. Top. Med. Chem. 2003, 3, 283-303; see also DNA gyrase drug-target reviews.",
    "Haydon, D. J.; Stokes, N. R.; Ure, R.; Galbraith, G.; Bennett, J. M.; Brown, D. R.; et al. An inhibitor of FtsZ with potent and selective anti-staphylococcal activity. Science 2008, 321, 1673-1675.",
    "Wagstaff, J. M.; Tsim, M.; Oliva, M. A.; Garcia-Sanchez, A.; Kureisaite-Ciziene, D.; Andreu, J. M.; Lowe, J. A polymerization-associated structural switch in FtsZ that enables treadmilling of model filaments. mBio 2017, 8, e00254-17. DOI: 10.1128/mBio.00254-17. PDB: 5MN4.",
    "Ferrer-Gonzalez, E.; Huh, H.; Al-Tameemi, H. M.; Boyd, J. M.; Lee, S. H.; Pilch, D. S. Impact of FtsZ inhibition on the localization of the penicillin binding proteins in methicillin-resistant Staphylococcus aureus. J. Bacteriol. 2021, 203, e00204-21.",
    "Zong, Y.; Bice, T. W.; Ton-That, H.; Schneewind, O.; Narayana, S. V. L. Crystal structures of Staphylococcus aureus sortase A and its substrate complex. J. Biol. Chem. 2004, 279, 31383-31389. DOI: 10.1074/jbc.M401374200. PDB: 1T2W.",
    "Bentley, M. L.; Lamb, E. C.; McCafferty, D. G. Mutagenesis studies of substrate recognition and catalysis in the Sortase A transpeptidase from Staphylococcus aureus. J. Biol. Chem. 2008, 283, 14762-14771.",
    "Shulga, D. A.; Kudryavtsev, K. V. Theoretical studies of Leu-Pro-Arg-Asp-Ala pentapeptide (LPRDA) binding to Sortase A of Staphylococcus aureus. Molecules 2022, 27, 8182.",
    "Trott, O.; Olson, A. J. AutoDock Vina: improving the speed and accuracy of docking with a new scoring function, efficient optimization, and multithreading. J. Comput. Chem. 2010, 31, 455-461. DOI: 10.1002/jcc.21334.",
    "Eberhardt, J.; Santos-Martins, D.; Tillack, A. F.; Forli, S. AutoDock Vina 1.2.0: new docking methods, expanded force field, and Python bindings. J. Chem. Inf. Model. 2021, 61, 3891-3898. DOI: 10.1021/acs.jcim.1c00203.",
    "Riniker, S.; Landrum, G. A. Better informed distance geometry: using what we know to improve conformation generation. J. Chem. Inf. Model. 2015, 55, 2562-2574. DOI: 10.1021/acs.jcim.5b00654.",
    "Rappe, A. K.; Casewit, C. J.; Colwell, K. S.; Goddard, W. A. III; Skiff, W. M. UFF, a full periodic table force field for molecular mechanics and molecular dynamics simulations. J. Am. Chem. Soc. 1992, 114, 10024-10035.",
]


def log(msg: str) -> None:
    print(msg, flush=True)


def read_csv(path: Path) -> List[Dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def write_csv(path: Path, rows: Sequence[Dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fields = list(rows[0].keys())
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)


def fnum(x: object, nd: int = 3) -> str:
    try:
        v = float(x)
        if not math.isfinite(v):
            return "NA"
        return f"{v:.{nd}f}".rstrip("0").rstrip(".")
    except Exception:
        return str(x)


def atom_coords_from_pdb_line(line: str) -> Tuple[float, float, float]:
    return float(line[30:38]), float(line[38:46]), float(line[46:54])


def parse_receptor_atoms(clean_pdb: Path) -> List[Tuple[str, str, str, int, Tuple[float, float, float]]]:
    atoms: List[Tuple[str, str, str, int, Tuple[float, float, float]]] = []
    for line in clean_pdb.read_text(errors="ignore").splitlines():
        if not line.startswith("ATOM"):
            continue
        try:
            chain = line[21].strip() or "A"
            resn = line[17:20].strip() or "UNK"
            atom = line[12:16].strip() or "X"
            resi = int(line[22:26])
            atoms.append((chain, resn, atom, resi, atom_coords_from_pdb_line(line)))
        except Exception:
            continue
    return atoms


def iter_first_model_pdbqt(path: Path) -> Iterable[str]:
    seen_model = False
    in_first = True
    for line in path.read_text(errors="ignore").splitlines():
        tag = line[:6].strip().upper()
        if tag == "MODEL":
            if seen_model:
                in_first = False
            seen_model = True
            continue
        if tag == "ENDMDL" and seen_model:
            break
        if not in_first:
            continue
        if line.startswith(("ATOM", "HETATM")):
            yield line


def parse_pdbqt_atoms(path: Path) -> List[Tuple[str, Tuple[float, float, float]]]:
    atoms: List[Tuple[str, Tuple[float, float, float]]] = []
    for line in iter_first_model_pdbqt(path):
        try:
            name = line[12:16].strip() or "X"
            atoms.append((name, atom_coords_from_pdb_line(line)))
        except Exception:
            continue
    return atoms


def pdbqt_to_pdb_first_model(pdbqt: Path, pdb: Path, resname: str = "PEP") -> None:
    atoms = parse_pdbqt_atoms(pdbqt)
    lines: List[str] = []
    for serial, (name, coord) in enumerate(atoms, start=1):
        elem = "".join(c for c in name if c.isalpha())[:1].upper() or "C"
        x, y, z = coord
        lines.append(f"HETATM{serial:5d} {name[:4]:<4s} {resname:>3s} L   1    {x:8.3f}{y:8.3f}{z:8.3f}  1.00  0.00          {elem:>2s}")
    lines.append("END")
    pdb.parent.mkdir(parents=True, exist_ok=True)
    pdb.write_text("\n".join(lines) + "\n", encoding="ascii", errors="ignore")


def combine_complex(receptor_pdb: Path, ligand_pdb: Path, out: Path) -> None:
    rec = [ln for ln in receptor_pdb.read_text(errors="ignore").splitlines() if ln.startswith("ATOM")]
    lig = [ln for ln in ligand_pdb.read_text(errors="ignore").splitlines() if ln.startswith("HETATM")]
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(rec + ["TER"] + lig + ["END"]) + "\n", encoding="ascii", errors="ignore")


def contact_residues(receptor_atoms, ligand_atoms, cutoff: float = 4.0) -> List[Dict[str, object]]:
    if not ligand_atoms:
        return []
    lig = [c for _n, c in ligand_atoms]
    by_res: Dict[Tuple[str, int, str], Dict[str, object]] = {}
    for chain, resn, atom, resi, coord in receptor_atoms:
        cx, cy, cz = coord
        best = min(math.sqrt((cx - lx) ** 2 + (cy - ly) ** 2 + (cz - lz) ** 2) for lx, ly, lz in lig)
        if best <= cutoff:
            key = (chain, resi, resn)
            old = by_res.get(key)
            if old is None or best < float(old["min_distance_A"]):
                by_res[key] = {
                    "chain": chain,
                    "residue": resn,
                    "resi": resi,
                    "min_distance_A": round(best, 3),
                    "nearest_atom": atom,
                }
    return sorted(by_res.values(), key=lambda x: (float(x["min_distance_A"]), str(x["chain"]), int(x["resi"])))


def find_pose_path(out_dir: Path, row: Dict[str, str]) -> Path:
    raw = Path(row.get("best_pose_pdbqt", ""))
    if raw.exists():
        return raw
    alt = out_dir / "poses" / row["target_key"] / row["peptide_key"] / raw.name
    if alt.exists():
        return alt
    matches = list((out_dir / "poses" / row["target_key"] / row["peptide_key"]).glob("*_best.pdbqt"))
    if matches:
        return sorted(matches)[0]
    return alt


def find_pymol() -> Optional[str]:
    for name in ["pymol", "pymol.exe", "PyMOLWin.exe"]:
        p = shutil.which(name)
        if p:
            return p
    for p in [
        r"E:\spider\Scripts\pymol.EXE",
        r"E:\spider\Scripts\pymol.exe",
        r"D:\Pymol\PyMOLWin.exe",
        r"D:\Pymol\pymol.exe",
        r"E:\Pymol\PyMOLWin.exe",
        r"E:\PyMOL\PyMOLWin.exe",
        r"C:\Program Files\PyMOL\PyMOLWin.exe",
        r"C:\Program Files\Schrodinger\PyMOL2\PyMOLWin.exe",
    ]:
        if Path(p).exists():
            return p
    return None


def pml_quote(path: Path) -> str:
    # PyMOL's png command can append a second .png when Windows paths are
    # double-quoted in a .pml file. The watcher repo path has no spaces, so use
    # forward slashes without surrounding quotes, matching the existing
    # PyMOL-MCP scripts in this repository.
    return str(path).replace("\\", "/")


def selection_for_contacts(contacts: Sequence[Dict[str, object]], max_labels: int = 10) -> str:
    terms = []
    for c in contacts[:max_labels]:
        chain = str(c.get("chain", "A") or "A")
        resi = str(c.get("resi", ""))
        if resi:
            terms.append(f"(chain {chain} and resi {resi})")
    return " or ".join(terms) if terms else "none"


def write_pymol_script(complex_pdb: Path, overview: Path, closeup: Path, pse: Path, contacts: Sequence[Dict[str, object]], pml: Path) -> None:
    contact_sel = selection_for_contacts(contacts, max_labels=12)
    pml.parent.mkdir(parents=True, exist_ok=True)
    pml.write_text(textwrap.dedent(f"""
        reinitialize
        load {pml_quote(complex_pdb)}, complex
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
        select contact_labels, {contact_sel}
        show cartoon, receptor
        color gray80, receptor
        show sticks, peptide
        color tv_red, peptide
        show sticks, pocket
        color cyan, pocket
        set transparency, 0.10, receptor
        orient receptor
        zoom receptor, 6
        png {pml_quote(overview)}, width=1200, height=900, dpi=300, ray=1
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
        png {pml_quote(closeup)}, width=1400, height=900, dpi=300, ray=1
        save {pml_quote(pse)}
        quit
    """).strip() + "\n", encoding="utf-8")


def run_pymol(pymol: str, pml: Path, timeout: int = 240) -> Tuple[int, str]:
    try:
        p = subprocess.run([pymol, "-cq", str(pml)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        return p.returncode, p.stdout
    except Exception as exc:
        return 999, str(exc)


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    candidates = []
    if os.name == "nt":
        candidates += [r"C:\Windows\Fonts\timesbd.ttf" if bold else r"C:\Windows\Fonts\times.ttf", r"C:\Windows\Fonts\arialbd.ttf" if bold else r"C:\Windows\Fonts\arial.ttf"]
    candidates += ["/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf"]
    for p in candidates:
        try:
            if Path(p).exists():
                return ImageFont.truetype(p, size=size)
        except Exception:
            pass
    return ImageFont.load_default()


def fit_text(draw: ImageDraw.ImageDraw, text: str, max_width: int, base_size: int, bold: bool = False) -> ImageFont.ImageFont:
    size = base_size
    while size >= 14:
        f = font(size, bold=bold)
        box = draw.textbbox((0, 0), text, font=f)
        if box[2] - box[0] <= max_width:
            return f
        size -= 2
    return font(14, bold=bold)


def make_panel(letter: str, row: Dict[str, str], overview: Path, closeup: Path, contacts: Sequence[Dict[str, object]], panel_out: Path) -> None:
    W, H = 2600, 1120
    top = 118
    gap = 34
    side_margin = 50
    sub_w = (W - 2 * side_margin - gap) // 2
    sub_h = 860
    canvas = Image.new("RGB", (W, H), "white")
    d = ImageDraw.Draw(canvas)
    title = f"{letter}. {row['sequence']} | {TARGET_INFO[row['target_key']].organism} {row['protein']} ({row['pdb_id']}) | mean {fnum(row['mean_best_affinity_kcal_mol'])} kcal/mol"
    title_font = fit_text(d, title, W - 160, 42, bold=True)
    d.text((50, 24), title, fill=(0, 0, 0), font=title_font)
    d.text((side_margin + 8, 84), "Overview", fill=(55, 55, 55), font=font(24, bold=True))
    d.text((side_margin + sub_w + gap + 8, 84), "4 A contact zoom", fill=(55, 55, 55), font=font(24, bold=True))
    for idx, img_path in enumerate([overview, closeup]):
        try:
            img = Image.open(img_path).convert("RGB")
        except Exception:
            img = Image.new("RGB", (sub_w, sub_h), (245, 245, 245))
            dd = ImageDraw.Draw(img)
            dd.text((40, 40), f"Missing render:\n{img_path.name}", fill=(180, 0, 0), font=font(28, bold=True))
        img.thumbnail((sub_w, sub_h), Image.Resampling.LANCZOS)
        x0 = side_margin + idx * (sub_w + gap)
        y0 = top + (sub_h - img.height) // 2
        d.rectangle([x0 - 4, top - 4, x0 + sub_w + 4, top + sub_h + 4], outline=(210, 210, 210), width=3)
        canvas.paste(img, (x0 + (sub_w - img.width) // 2, y0))
    contact_text = "; ".join([f"{c['chain']}:{c['residue']}{c['resi']} {c['min_distance_A']}A" for c in contacts[:8]]) or "No 4 A contacts detected"
    d.text((50, H - 90), "Top contacts: " + contact_text, fill=(20, 20, 20), font=fit_text(d, "Top contacts: " + contact_text, W - 100, 25, bold=False))
    d.text((50, H - 48), "Receptor: gray/cartoon+transparent surface; peptide: red sticks; contact residues: cyan sticks; hydrogen-bond candidates: magenta dashed lines.", fill=(70, 70, 70), font=font(20))
    panel_out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(panel_out, dpi=(300, 300))


def assemble_grid(panel_paths: Sequence[Path], output: Path, title: str, ncols: int) -> None:
    imgs = [Image.open(p).convert("RGB") for p in panel_paths]
    thumb_w, thumb_h = 1300, 560
    thumbs = []
    for img in imgs:
        im = img.copy()
        im.thumbnail((thumb_w, thumb_h), Image.Resampling.LANCZOS)
        tile = Image.new("RGB", (thumb_w, thumb_h), "white")
        tile.paste(im, ((thumb_w - im.width) // 2, (thumb_h - im.height) // 2))
        thumbs.append(tile)
    nrows = math.ceil(len(thumbs) / ncols)
    margin = 70
    title_h = 90
    gap = 34
    W = 2 * margin + ncols * thumb_w + (ncols - 1) * gap
    H = margin + title_h + nrows * thumb_h + (nrows - 1) * gap + 50
    canvas = Image.new("RGB", (W, H), "white")
    d = ImageDraw.Draw(canvas)
    d.text((margin, 28), title, fill=(0, 0, 0), font=fit_text(d, title, W - 2 * margin, 44, bold=True))
    for idx, im in enumerate(thumbs):
        r, c = divmod(idx, ncols)
        x = margin + c * (thumb_w + gap)
        y = margin + title_h + r * (thumb_h + gap)
        d.rectangle([x - 3, y - 3, x + thumb_w + 3, y + thumb_h + 3], outline=(220, 220, 220), width=3)
        canvas.paste(im, (x, y))
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, dpi=(300, 300))


def make_literature_md(summary_rows: List[Dict[str, str]], repeats_rows: List[Dict[str, str]], figure_rows: List[Dict[str, object]], out_dir: Path) -> str:
    generated = time.strftime("%Y-%m-%d %H:%M:%S")
    md: List[str] = []
    md.append("# 抗菌肽分子对接：靶点选择依据、方法学文献支持与结果记录")
    md.append("")
    md.append(f"生成时间：{generated}")
    md.append("")
    md.append("## 1. 研究对象与输出概览")
    md.append("")
    md.append("本轮对三条抗菌肽进行开放源代码 AutoDock Vina 基线分子对接，并围绕 *Escherichia coli* 与 *Staphylococcus aureus* 各选择两个与抗菌作用高度相关的蛋白靶点。每个 peptide-target pair 进行 3 次独立 Vina seed 重复，报告每次最佳构象分数的均值。")
    md.append("")
    md.append("肽序列：")
    for pkey in PEPTIDE_ORDER:
        seq = next((r["sequence"] for r in summary_rows if r["peptide_key"] == pkey), pkey.split("_", 1)[-1])
        md.append(f"- `{seq}`")
    md.append("")
    md.append("主要输出：")
    md.append("- `tables/vina_summary_mean_of_3.csv`：12 个 peptide-target pair 的 3 次重复均值。")
    md.append("- `tables/vina_repeats.csv`：36 条重复对接记录。")
    md.append("- `complexes_best_vina/sci_composite_figures/`：按 SCI 图件风格排版的 PyMOL 复合图。")
    md.append("- `AMP_Docking_Targets_Methods_Results.docx`：与本 Markdown 同内容的 Word 报告。")
    md.append("")
    md.append("## 2. 靶点选择原因与文献支持")
    md.append("")
    md.append("| 病原体 | 靶点/PDB | 选择原因 | 结构选择依据 | 文献支持 |")
    md.append("|---|---|---|---|---|")
    for key in TARGET_ORDER:
        t = TARGET_INFO[key]
        md.append(f"| *{t.organism}* | {t.protein} / `{t.pdb_id}` | {t.reason} | {t.structure_reason} | {t.literature} |")
    md.append("")
    md.append("## 3. 方法学与文献支持")
    md.append("")
    md.append("1. **受体标准化**：从 RCSB PDB 获取晶体结构；保留 first model 的 protein ATOM 记录，移除结晶水、离子及共晶小分子，输出 rigid receptor PDBQT。该处理对应常规 docking 前处理流程，目的是使不同靶点处于一致、可复现的输入状态。")
    md.append("2. **肽配体构建与能量最小化**：使用 RDKit `MolFromFASTA` 从序列构建肽分子，加氢，使用 ETKDGv3 生成 3D conformers，并用 UFF 分子力场优化，取最低 UFF energy 构象作为 rigid peptide baseline。ETKDG 和 UFF 的方法学文献分别为 Riniker & Landrum 2015 以及 Rappe et al. 1992。")
    md.append("3. **对接引擎**：采用 AutoDock Vina 1.2.7 CLI。Vina 是常用开源 docking 引擎，原始算法与评分函数见 Trott & Olson 2010，Vina 1.2 系列更新见 Eberhardt et al. 2021。")
    md.append("4. **重复设置**：每个 peptide-target pair 进行 3 个独立 seed 的 docking，汇总每次 docking 的最佳 pose score，计算 mean、SD 与 best single score。")
    md.append("5. **结合位点与可视化**：对最终 best pose 计算 4 Å 以内受体残基，并使用 PyMOL headless 渲染。每个 SCI panel 包含 receptor overview 与 4 Å contact zoom，肽以红色棒状表示，接触残基以青色棒状表示，可能氢键以品红虚线表示，残基标签直接标注在局部图中。")
    md.append("")
    md.append("## 4. 对接结果记录")
    md.append("")
    md.append(f"重复记录数：{len(repeats_rows)}；汇总行数：{len(summary_rows)}。")
    md.append("")
    md.append("| 病原体 | 靶点 | PDB | 肽序列 | n | Mean best (kcal/mol) | SD | Best single |")
    md.append("|---|---|---:|---|---:|---:|---:|---:|")
    for r in summary_rows:
        md.append(f"| *{r['organism']}* | {r['protein']} | `{r['pdb_id']}` | `{r['sequence']}` | {r['n_repeats']} | {fnum(r['mean_best_affinity_kcal_mol'])} | {fnum(r['sd_best_affinity_kcal_mol'])} | {fnum(r['best_single_affinity_kcal_mol'])} |")
    md.append("")
    md.append("### 4.1 每条肽在每个病原体内的较优靶点")
    md.append("")
    md.append("| 病原体 | 肽序列 | 较优靶点 | Mean best (kcal/mol) | 主要 4 Å 接触残基 |")
    md.append("|---|---|---|---:|---|")
    for fr in figure_rows:
        md.append(f"| *{fr['organism']}* | `{fr['sequence']}` | `{fr['target_key']}` | {fnum(fr['mean_best_affinity_kcal_mol'])} | {fr['top_contacts']} |")
    md.append("")
    md.append("结果解释：在本 rigid-peptide Vina baseline 中，三条肽对 *E. coli* 的较优目标均为 GyrB ATPase domain（4DUH）。对 *S. aureus*，三条肽均更倾向 FtsZ（5MN4），而 Sortase A（1T2W）出现正值或极高 Vina score，提示在当前刚性肽构象和固定受体网格下拟合较差；该现象应作为筛选提示而非物理结合自由能。")
    md.append("")
    md.append("## 5. SCI 图件输出")
    md.append("")
    md.append("- `complexes_best_vina/sci_composite_figures/Figure_4_Part1_A-F_300dpi.png`：A-F 六个复合物面板。")
    md.append("- `complexes_best_vina/sci_composite_figures/Figure_4_Part2_G-L_300dpi.png`：G-L 六个复合物面板。")
    md.append("- `complexes_best_vina/sci_composite_figures/Figure_S1_12_Combined_300dpi.png`：12 个复合物总览补充图。")
    md.append("")
    md.append("## 6. 局限性")
    md.append("")
    md.append("AutoDock Vina 不是专用的 flexible peptide-protein docking 引擎。本结果适合作为可复现、开放源代码的初筛记录：肽构象经 RDKit/UFF 最小化后作为 rigid ligand dock 到标准化 receptor。若用于投稿或机制结论，建议增加 flexible peptide docking、分子动力学、MM/GBSA 或实验结合/抑菌验证。")
    md.append("")
    md.append("## 7. 参考文献")
    md.append("")
    for i, ref in enumerate(REFERENCE_TEXT, start=1):
        md.append(f"{i}. {ref}")
    md.append("")
    md.append("---")
    md.append("AMP_DOC_REPORT_DONE=True")
    md.append("VINA_REPEATS_PER_PAIR=3")
    md.append("SCI_COMPOSITE_FIGURES_DONE=True")
    return "\n".join(md) + "\n"


def add_table_docx(doc: Document, headers: Sequence[str], rows: Sequence[Sequence[str]]) -> None:
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    hdr = table.rows[0].cells
    for i, h in enumerate(headers):
        hdr[i].text = h
    for row in rows:
        cells = table.add_row().cells
        for i, value in enumerate(row):
            cells[i].text = str(value)


def make_docx(md_text: str, docx_path: Path, summary_rows: List[Dict[str, str]], figure_rows: List[Dict[str, object]], composite_paths: Sequence[Path]) -> None:
    doc = Document()
    styles = doc.styles
    styles["Normal"].font.name = "Times New Roman"
    styles["Normal"].font.size = Pt(10.5)
    doc.add_heading("抗菌肽分子对接：靶点选择依据、方法学文献支持与结果记录", 0)
    doc.add_paragraph(f"生成时间：{time.strftime('%Y-%m-%d %H:%M:%S')}")
    doc.add_heading("1. 研究对象与输出概览", level=1)
    doc.add_paragraph("本报告记录三条抗菌肽针对 E. coli 与 S. aureus 相关靶点的 AutoDock Vina 基线对接、靶点选择依据、方法学文献支持和 PyMOL SCI 图件输出。每个 peptide-target pair 进行 3 次独立 seed 重复，报告最佳构象分数均值。")
    doc.add_paragraph("肽序列：" + "；".join(sorted({r["sequence"] for r in summary_rows})))
    doc.add_heading("2. 靶点选择原因与文献支持", level=1)
    target_rows = []
    for key in TARGET_ORDER:
        t = TARGET_INFO[key]
        target_rows.append([t.organism, f"{t.protein} / {t.pdb_id}", t.reason, t.structure_reason, t.literature])
    add_table_docx(doc, ["病原体", "靶点/PDB", "选择原因", "结构选择依据", "文献支持"], target_rows)
    doc.add_heading("3. 方法学与文献支持", level=1)
    methods = [
        "受体标准化：RCSB PDB 结构；保留 first model protein ATOM，移除水、离子及共晶小分子，输出 rigid receptor PDBQT。",
        "肽配体构建：RDKit MolFromFASTA，加氢，ETKDGv3 conformer 生成，UFF 能量最小化，取最低能构象作为 rigid peptide baseline。",
        "对接引擎：AutoDock Vina 1.2.7 CLI；每个 peptide-target pair 使用 3 个独立 seed，汇总最佳 pose score 的 mean、SD 与 best single。",
        "可视化：PyMOL headless 渲染 receptor overview 与 4 Å contact zoom，标注接触残基，绘制可能氢键虚线。",
    ]
    for m in methods:
        doc.add_paragraph(m, style=None)
    doc.add_heading("4. 对接结果记录", level=1)
    result_rows = [[r["organism"], r["protein"], r["pdb_id"], r["sequence"], r["n_repeats"], fnum(r["mean_best_affinity_kcal_mol"]), fnum(r["sd_best_affinity_kcal_mol"]), fnum(r["best_single_affinity_kcal_mol"])] for r in summary_rows]
    add_table_docx(doc, ["病原体", "靶点", "PDB", "肽序列", "n", "Mean best", "SD", "Best single"], result_rows)
    doc.add_heading("4.1 每条肽在每个病原体内的较优靶点", level=2)
    best_rows = [[r["organism"], r["sequence"], r["target_key"], fnum(r["mean_best_affinity_kcal_mol"]), r["top_contacts"]] for r in figure_rows]
    add_table_docx(doc, ["病原体", "肽序列", "较优靶点", "Mean best", "主要 4 Å 接触残基"], best_rows)
    doc.add_paragraph("结果解释：在本 rigid-peptide Vina baseline 中，三条肽对 E. coli 的较优目标均为 GyrB ATPase domain（4DUH）；对 S. aureus 的较优目标均为 FtsZ（5MN4）。Sortase A（1T2W）的正值/极高分数提示当前刚性肽构象与该口袋拟合较差，应作为筛选提示而非物理结合自由能。")
    doc.add_heading("5. SCI 图件", level=1)
    for p in composite_paths:
        if p.exists():
            doc.add_paragraph(p.name)
            try:
                doc.add_picture(str(p), width=Inches(6.5))
            except Exception as exc:
                doc.add_paragraph(f"[图片插入失败：{exc}] {p}")
    doc.add_heading("6. 局限性", level=1)
    doc.add_paragraph("Vina 不是专用 flexible peptide-protein docking 引擎。本结果适合作为可复现的开放源代码初筛；投稿级机制结论建议进一步进行 flexible peptide docking、MD、MM/GBSA 或实验验证。")
    doc.add_heading("7. 参考文献", level=1)
    for ref in REFERENCE_TEXT:
        doc.add_paragraph(ref, style=None)
    doc.add_paragraph("AMP_DOC_REPORT_DONE=True; SCI_COMPOSITE_FIGURES_DONE=True")
    docx_path.parent.mkdir(parents=True, exist_ok=True)
    doc.save(docx_path)


def build_all(out_dir: Path) -> Dict[str, object]:
    summary_csv = out_dir / "tables" / "vina_summary_mean_of_3.csv"
    repeats_csv = out_dir / "tables" / "vina_repeats.csv"
    if not summary_csv.exists():
        raise FileNotFoundError(summary_csv)
    summary_rows = read_csv(summary_csv)
    repeats_rows = read_csv(repeats_csv) if repeats_csv.exists() else []
    summary_rows.sort(key=lambda r: (TARGET_ORDER.index(r["target_key"]) if r["target_key"] in TARGET_ORDER else 99,
                                     PEPTIDE_ORDER.index(r["peptide_key"]) if r["peptide_key"] in PEPTIDE_ORDER else 99))

    pymol = find_pymol()
    if not pymol:
        raise RuntimeError("PyMOL executable not found; cannot generate requested PyMOL SCI figures")
    log(f"PYMOL={pymol}")

    base = out_dir / "complexes_best_vina"
    complex_dir = base / "all_12_complexes"
    lig_dir = base / "best_ligands"
    contacts_dir = base / "contacts_4A"
    viz_dir = base / "visualizations"
    panel_dir = viz_dir / "panels_times"
    composite_dir = base / "sci_composite_figures"
    scripts_dir = base / "pymol_scripts"
    for d in [complex_dir, lig_dir, contacts_dir, viz_dir, panel_dir, composite_dir, scripts_dir]:
        d.mkdir(parents=True, exist_ok=True)

    all_panel_paths: List[Path] = []
    all_contact_rows: List[Dict[str, object]] = []
    row_contact_map: Dict[Tuple[str, str], List[Dict[str, object]]] = {}
    render_records: List[Dict[str, object]] = []

    for idx, row in enumerate(summary_rows):
        letter = LETTERS[idx]
        tkey = row["target_key"]
        pkey = row["peptide_key"]
        label = f"{letter}_{tkey}__{pkey}"
        receptor = out_dir / "targets" / f"{tkey}_protein_clean.pdb"
        pose = find_pose_path(out_dir, row)
        if not receptor.exists():
            raise FileNotFoundError(receptor)
        if not pose.exists():
            raise FileNotFoundError(pose)
        ligand_pdb = lig_dir / f"{label}_best_ligand.pdb"
        complex_pdb = complex_dir / f"{label}_complex_best.pdb"
        pdbqt_to_pdb_first_model(pose, ligand_pdb)
        combine_complex(receptor, ligand_pdb, complex_pdb)
        contacts = contact_residues(parse_receptor_atoms(receptor), parse_pdbqt_atoms(pose), cutoff=4.0)
        row_contact_map[(tkey, pkey)] = contacts
        contact_csv = contacts_dir / f"{label}_contacts_4A.csv"
        contact_rows = [{"panel": letter, "target_key": tkey, "peptide_key": pkey, **c} for c in contacts]
        write_csv(contact_csv, contact_rows if contact_rows else [{"panel": letter, "target_key": tkey, "peptide_key": pkey, "chain": "", "residue": "", "resi": "", "min_distance_A": "", "nearest_atom": ""}])
        all_contact_rows.extend(contact_rows)

        overview = viz_dir / f"{label}_overview_clean.png"
        closeup = viz_dir / f"{label}_zoom_labelled.png"
        panel = panel_dir / f"{label}_times.png"
        pse = viz_dir / f"{label}_vector.pse"
        pml = scripts_dir / f"{label}_render.pml"
        write_pymol_script(complex_pdb, overview, closeup, pse, contacts, pml)
        if not (overview.exists() and closeup.exists()):
            code, text = run_pymol(pymol, pml, timeout=300)
            (scripts_dir / f"{label}_pymol.log").write_text(text, encoding="utf-8", errors="replace")
            if code != 0 or not overview.exists() or not closeup.exists():
                raise RuntimeError(f"PyMOL render failed for {label}; code={code}; tail={text[-800:]}")
        make_panel(letter, row, overview, closeup, contacts, panel)
        all_panel_paths.append(panel)
        render_records.append({
            "panel": letter,
            "target_key": tkey,
            "peptide_key": pkey,
            "sequence": row["sequence"],
            "mean_best_affinity_kcal_mol": row["mean_best_affinity_kcal_mol"],
            "complex_pdb": str(complex_pdb),
            "panel_png": str(panel),
            "pse": str(pse),
            "contacts_csv": str(contact_csv),
            "top_contacts": "; ".join([f"{c['chain']}:{c['residue']}{c['resi']}({c['min_distance_A']}A)" for c in contacts[:10]]),
        })
        log(f"PANEL {letter} {tkey} {pkey} contacts={len(contacts)}")

    write_csv(base / "all_panel_render_records.csv", render_records)
    write_csv(base / "all_contacts_4A.csv", all_contact_rows)

    part1 = composite_dir / "Figure_4_Part1_A-F_300dpi.png"
    part2 = composite_dir / "Figure_4_Part2_G-L_300dpi.png"
    supp = composite_dir / "Figure_S1_12_Combined_300dpi.png"
    assemble_grid(all_panel_paths[:6], part1, "Figure 4 Part 1 (A-F). AMP docking complexes: overview and labelled 4 A contact zoom", ncols=2)
    assemble_grid(all_panel_paths[6:12], part2, "Figure 4 Part 2 (G-L). AMP docking complexes: overview and labelled 4 A contact zoom", ncols=2)
    assemble_grid(all_panel_paths, supp, "Figure S1. Twelve AMP-target Vina complexes rendered by PyMOL", ncols=3)

    # Best target per peptide per organism for the report summary.
    best_rows: List[Dict[str, object]] = []
    organisms = sorted({r["organism"] for r in summary_rows})
    for pkey in PEPTIDE_ORDER:
        for org in organisms:
            cands = [r for r in summary_rows if r["peptide_key"] == pkey and r["organism"] == org]
            if not cands:
                continue
            best = min(cands, key=lambda r: float(r["mean_best_affinity_kcal_mol"]))
            contacts = row_contact_map.get((best["target_key"], best["peptide_key"]), [])
            best_rows.append({
                "organism": best["organism"],
                "sequence": best["sequence"],
                "target_key": best["target_key"],
                "mean_best_affinity_kcal_mol": best["mean_best_affinity_kcal_mol"],
                "top_contacts": "; ".join([f"{c['chain']}:{c['residue']}{c['resi']}({c['min_distance_A']}A)" for c in contacts[:10]]) or "NA",
            })

    md_text = make_literature_md(summary_rows, repeats_rows, best_rows, out_dir)
    md_path = out_dir / "AMP_Docking_Targets_Methods_Results.md"
    md_path.write_text(md_text, encoding="utf-8")
    docx_path = out_dir / "AMP_Docking_Targets_Methods_Results.docx"
    make_docx(md_text, docx_path, summary_rows, best_rows, [part1, part2, supp])

    status = {
        "time": time.strftime("%Y-%m-%d %H:%M:%S"),
        "pymol": pymol,
        "markdown": str(md_path),
        "docx": str(docx_path),
        "composite_figures": [str(part1), str(part2), str(supp)],
        "panels": len(all_panel_paths),
        "summary_rows": len(summary_rows),
        "repeat_rows": len(repeats_rows),
        "status": "done",
    }
    (out_dir / "AMP_Docking_Report_SciFigures_manifest.json").write_text(json.dumps(status, ensure_ascii=False, indent=2), encoding="utf-8")
    log(f"MD={md_path}")
    log(f"DOCX={docx_path}")
    log(f"SCI_FIGURES={composite_dir}")
    log("AMP_DOC_REPORT_DONE=True")
    log("AMP_DOCX_DONE=True")
    log("AMP_MD_DONE=True")
    log("SCI_COMPOSITE_FIGURES_DONE=True")
    return status


def main(argv: Sequence[str]) -> int:
    if len(argv) < 2:
        print("usage: amp_docking_report_and_sci_figures.py OUTDIR", file=sys.stderr)
        return 2
    out_dir = Path(argv[1]).resolve()
    try:
        build_all(out_dir)
        return 0
    except Exception as exc:
        log(f"ERROR: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
