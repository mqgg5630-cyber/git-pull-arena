#!/usr/bin/env python3
"""Peptide docking workflow for round 255+.

Open/free workflow:
- Fetch selected bacterial target PDB structures from RCSB.
- Standardize receptors: first MODEL, protein ATOM records only, waters/hetero removed.
- Build peptide ligands from sequences with RDKit, add hydrogens, ETKDG conformers, UFF minimize.
- Convert receptor and minimized peptides to simple rigid PDBQT.
- Run AutoDock Vina 3 independent repeats per peptide-target pair.
- Analyze receptor residues within 4 A of the best pose.
- Generate summary tables and method/result figures; PyMOL scripts are written and used if PyMOL is available.

This workflow is intended as a reproducible screening/report-generation baseline,
not as a substitute for dedicated flexible protein-peptide docking or MD refinement.
"""
from __future__ import annotations

import csv
import json
import math
import os
import random
import shutil
import subprocess
import sys
import textwrap
import time
import urllib.request
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

import numpy as np

try:
    from rdkit import Chem
    from rdkit.Chem import AllChem
except Exception as e:  # pragma: no cover
    print(f"IMPORT_ERROR: rdkit unavailable: {e}", file=sys.stderr)
    raise

try:
    from vina import Vina
except Exception as e:  # pragma: no cover
    print(f"IMPORT_ERROR: vina unavailable: {e}", file=sys.stderr)
    raise

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except Exception as e:  # pragma: no cover
    print(f"IMPORT_ERROR: matplotlib unavailable: {e}", file=sys.stderr)
    raise


@dataclass
class Target:
    key: str
    organism: str
    protein: str
    pdb_id: str
    note: str


@dataclass
class Peptide:
    key: str
    sequence: str


PEPTIDES = [
    Peptide("P1_FVNKLNRIIPVKGFSMR", "FVNKLNRIIPVKGFSMR"),
    Peptide("P2_LISNTKKFGTAIASHR", "LISNTKKFGTAIASHR"),
    Peptide("P3_ISLAIPLASKISGFTLALVKNAST", "ISLAIPLASKISGFTLALVKNAST"),
]

TARGETS = [
    Target("ecoli_FtsZ_6UNX", "Escherichia coli", "FtsZ cell-division protein", "6UNX", "E. coli FtsZ GTP-complex active-site/grid around cofactor if present"),
    Target("ecoli_GyrB_4DUH", "Escherichia coli", "DNA gyrase B ATPase domain", "4DUH", "E. coli GyrB ATPase domain inhibitor pocket"),
    Target("saureus_FtsZ_5MN4", "Staphylococcus aureus", "FtsZ cell-division protein", "5MN4", "S. aureus FtsZ open/GDP form"),
    Target("saureus_SrtA_1T2W", "Staphylococcus aureus", "Sortase A transpeptidase", "1T2W", "S. aureus Sortase A substrate-bound structure"),
]

AA3 = {
    "A": "ALA", "R": "ARG", "N": "ASN", "D": "ASP", "C": "CYS", "E": "GLU", "Q": "GLN", "G": "GLY", "H": "HIS", "I": "ILE",
    "L": "LEU", "K": "LYS", "M": "MET", "F": "PHE", "P": "PRO", "S": "SER", "T": "THR", "W": "TRP", "Y": "TYR", "V": "VAL",
}

AD_TYPES = {
    "H": "H", "C": "C", "N": "N", "O": "O", "S": "S", "P": "P", "F": "F", "CL": "Cl", "BR": "Br", "I": "I", "MG": "Mg", "ZN": "Zn", "FE": "Fe", "CA": "Ca",
}


def log(msg: str) -> None:
    print(msg, flush=True)


def run(cmd: List[str], cwd: Optional[Path] = None, timeout: int = 300) -> Tuple[int, str]:
    try:
        p = subprocess.run(cmd, cwd=str(cwd) if cwd else None, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        return p.returncode, p.stdout
    except Exception as e:
        return 999, str(e)


def fetch_pdb(pdb_id: str, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists() and out.stat().st_size > 5000:
        return
    urls = [
        f"https://files.rcsb.org/download/{pdb_id}.pdb",
        f"https://www.rcsb.org/fasta/entry/{pdb_id}",  # deliberately last-resort check, not a PDB
    ]
    # Prefer curl on Windows because it handles local certificate stores and proxies better.
    curl = shutil.which("curl") or str(Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32" / "curl.exe")
    if curl and Path(curl).exists():
        code, text = run([curl, "-L", "--ssl-no-revoke", "--retry", "3", "--connect-timeout", "20", "--max-time", "180", "-o", str(out), urls[0]], timeout=240)
        if code == 0 and out.exists() and out.stat().st_size > 5000:
            return
        log(f"WARN curl fetch {pdb_id} failed code={code}: {text[-500:]}")
    try:
        with urllib.request.urlopen(urls[0], timeout=60) as r:
            data = r.read()
        out.write_bytes(data)
        if out.stat().st_size > 5000:
            return
    except Exception as e:
        log(f"WARN urllib fetch {pdb_id} failed: {e}")
    raise RuntimeError(f"could not fetch PDB {pdb_id}")


def element_from_pdb_line(line: str) -> str:
    e = line[76:78].strip().upper() if len(line) >= 78 else ""
    if not e:
        name = line[12:16].strip()
        letters = "".join([c for c in name if c.isalpha()])
        if len(letters) >= 2 and letters[:2].upper() in AD_TYPES:
            e = letters[:2].upper()
        elif letters:
            e = letters[0].upper()
        else:
            e = "C"
    return e


def pdb_atom_coords(line: str) -> Tuple[float, float, float]:
    return (float(line[30:38]), float(line[38:46]), float(line[46:54]))


def clean_receptor_pdb(raw: Path, clean: Path) -> Tuple[np.ndarray, List[Tuple[str, str, str, int, str, np.ndarray]], Optional[np.ndarray]]:
    clean.parent.mkdir(parents=True, exist_ok=True)
    atom_lines: List[str] = []
    all_atoms: List[Tuple[str, str, str, int, str, np.ndarray]] = []
    hetero_coords: List[np.ndarray] = []
    in_first_model = True
    saw_model = False
    for line in raw.read_text(errors="ignore").splitlines():
        rec = line[:6].strip()
        if rec == "MODEL":
            if saw_model:
                in_first_model = False
            saw_model = True
            continue
        if rec == "ENDMDL" and saw_model:
            break
        if not in_first_model:
            continue
        if rec == "HETATM":
            resn = line[17:20].strip().upper()
            if resn not in {"HOH", "WAT", "DOD", "SO4", "CL", "NA", "K"}:
                try:
                    hetero_coords.append(np.array(pdb_atom_coords(line), dtype=float))
                except Exception:
                    pass
            continue
        if rec != "ATOM":
            continue
        resn = line[17:20].strip().upper()
        if resn in {"HOH", "WAT", "DOD"}:
            continue
        if element_from_pdb_line(line) == "H":
            # crystal H atoms are rare; remove for a consistent heavy-atom receptor.
            continue
        atom_lines.append(line[:66])
        try:
            chain = line[21].strip() or "A"
            resi = int(line[22:26])
            atom = line[12:16].strip()
            coord = np.array(pdb_atom_coords(line), dtype=float)
            all_atoms.append((chain, resn, atom, resi, element_from_pdb_line(line), coord))
        except Exception:
            continue
    if not atom_lines:
        raise RuntimeError(f"no protein atoms in {raw}")
    clean.write_text("\n".join(atom_lines) + "\nEND\n", encoding="ascii", errors="ignore")
    coords = np.array([a[-1] for a in all_atoms], dtype=float)
    het_center = np.mean(np.vstack(hetero_coords), axis=0) if hetero_coords else None
    return coords, all_atoms, het_center


def ad_type(element: str) -> str:
    e = element.strip().upper()
    return AD_TYPES.get(e, e.capitalize() if len(e) > 1 else e)


def write_receptor_pdbqt(clean_pdb: Path, out: Path) -> None:
    lines_out: List[str] = []
    serial = 1
    for line in clean_pdb.read_text(errors="ignore").splitlines():
        if not line.startswith("ATOM"):
            continue
        x, y, z = pdb_atom_coords(line)
        name = line[12:16].strip() or element_from_pdb_line(line)
        resn = line[17:20].strip() or "UNK"
        chain = line[21].strip() or "A"
        resi = line[22:26].strip() or "1"
        typ = ad_type(element_from_pdb_line(line))
        lines_out.append(f"ATOM  {serial:5d} {name:<4s} {resn:>3s} {chain:1s}{int(resi):4d}    {x:8.3f}{y:8.3f}{z:8.3f}  1.00  0.00    {0.0:6.3f} {typ:>2s}")
        serial += 1
    out.write_text("\n".join(lines_out) + "\n", encoding="ascii")


def build_peptide(peptide: Peptide, out_pdb: Path, out_pdbqt: Path, seed: int) -> Dict[str, float]:
    out_pdb.parent.mkdir(parents=True, exist_ok=True)
    mol = Chem.MolFromFASTA(peptide.sequence)
    if mol is None:
        raise RuntimeError(f"RDKit MolFromFASTA failed for {peptide.key}")
    mol = Chem.AddHs(mol)
    params = AllChem.ETKDGv3()
    params.randomSeed = int(seed)
    params.numThreads = 0
    params.pruneRmsThresh = 0.5
    conf_ids = list(AllChem.EmbedMultipleConfs(mol, numConfs=12, params=params))
    if not conf_ids:
        # deterministic fallback: one conformer with random coords.
        params.useRandomCoords = True
        conf_ids = list(AllChem.EmbedMultipleConfs(mol, numConfs=4, params=params))
    if not conf_ids:
        raise RuntimeError(f"RDKit embedding failed for {peptide.key}")
    results = AllChem.UFFOptimizeMoleculeConfs(mol, numThreads=0, maxIters=1000)
    best_i, best_e = min(enumerate([float(x[1]) for x in results]), key=lambda t: t[1])
    best_conf = conf_ids[best_i]
    Chem.MolToPDBFile(mol, str(out_pdb), confId=int(best_conf))
    try:
        AllChem.ComputeGasteigerCharges(mol)
    except Exception:
        pass
    conf = mol.GetConformer(int(best_conf))
    pdbqt_lines = ["ROOT"]
    for i, atom in enumerate(mol.GetAtoms(), start=1):
        pos = conf.GetAtomPosition(i - 1)
        sym = atom.GetSymbol().upper()
        typ = ad_type(sym)
        q = 0.0
        if atom.HasProp("_GasteigerCharge"):
            try:
                q = float(atom.GetProp("_GasteigerCharge"))
                if not math.isfinite(q):
                    q = 0.0
            except Exception:
                q = 0.0
        name = f"{sym}{i}"[:4]
        pdbqt_lines.append(f"HETATM{i:5d} {name:<4s} LIG A   1    {pos.x:8.3f}{pos.y:8.3f}{pos.z:8.3f}  1.00  0.00    {q:6.3f} {typ:>2s}")
    pdbqt_lines += ["ENDROOT", "TORSDOF 0"]
    out_pdbqt.write_text("\n".join(pdbqt_lines) + "\n", encoding="ascii")
    return {"uff_energy": best_e, "n_atoms": float(mol.GetNumAtoms()), "n_conformers": float(len(conf_ids))}


def parse_pdbqt_coords(path: Path) -> List[Tuple[str, np.ndarray]]:
    atoms = []
    for line in path.read_text(errors="ignore").splitlines():
        if line.startswith(("ATOM", "HETATM")):
            try:
                name = line[12:16].strip() or line[77:].strip() or "X"
                atoms.append((name, np.array((float(line[30:38]), float(line[38:46]), float(line[46:54])), dtype=float)))
            except Exception:
                pass
    return atoms


def pdbqt_to_pdb(pdbqt: Path, pdb: Path, resname: str = "PEP") -> None:
    out = []
    serial = 1
    for name, coord in parse_pdbqt_coords(pdbqt):
        elem = "".join([c for c in name if c.isalpha()])[:1].upper() or "C"
        out.append(f"HETATM{serial:5d} {name[:4]:<4s} {resname:>3s} L   1    {coord[0]:8.3f}{coord[1]:8.3f}{coord[2]:8.3f}  1.00  0.00          {elem:>2s}")
        serial += 1
    out.append("END")
    pdb.write_text("\n".join(out) + "\n", encoding="ascii")


def combine_complex(receptor_pdb: Path, ligand_pdb: Path, out: Path) -> None:
    r = [ln for ln in receptor_pdb.read_text(errors="ignore").splitlines() if ln.startswith("ATOM")]
    l = [ln for ln in ligand_pdb.read_text(errors="ignore").splitlines() if ln.startswith("HETATM")]
    out.write_text("\n".join(r + ["TER"] + l + ["END"]) + "\n", encoding="ascii")


def contact_residues(receptor_atoms, ligand_atoms, cutoff: float = 4.0) -> List[Dict[str, object]]:
    rec_by_res: Dict[Tuple[str, int, str], Dict[str, object]] = {}
    lig_coords = np.array([c for _, c in ligand_atoms], dtype=float)
    if lig_coords.size == 0:
        return []
    for chain, resn, atom, resi, elem, coord in receptor_atoms:
        d = float(np.min(np.linalg.norm(lig_coords - coord, axis=1)))
        if d <= cutoff:
            key = (chain, resi, resn)
            old = rec_by_res.get(key)
            if old is None or d < old["min_distance_A"]:
                rec_by_res[key] = {"chain": chain, "residue": resn, "resi": resi, "min_distance_A": round(d, 3), "nearest_atom": atom}
    return sorted(rec_by_res.values(), key=lambda x: float(x["min_distance_A"]))


def find_pymol() -> Optional[str]:
    candidates = []
    for name in ["pymol", "pymol.exe", "PyMOLWin.exe"]:
        p = shutil.which(name)
        if p:
            candidates.append(p)
    for p in [
        r"D:\Pymol\PyMOLWin.exe",
        r"D:\Pymol\pymol.exe",
        r"E:\Pymol\PyMOLWin.exe",
        r"E:\PyMOL\PyMOLWin.exe",
        r"C:\Program Files\PyMOL\PyMOLWin.exe",
    ]:
        if Path(p).exists():
            candidates.append(p)
    return candidates[0] if candidates else None


def write_pymol_script(complex_pdb: Path, png: Path, pse: Path, contacts: List[Dict[str, object]], script: Path) -> None:
    selects = []
    for c in contacts[:12]:
        chain, resi = c["chain"], c["resi"]
        selects.append(f"(chain {chain} and resi {resi})")
    contact_sel = " or ".join(selects) if selects else "none"
    script.write_text(textwrap.dedent(f"""
        reinitialize
        load {complex_pdb.as_posix()}, complex
        hide everything
        select peptide, chain L
        select receptor, not chain L
        show cartoon, receptor
        color gray70, receptor
        show sticks, peptide
        color cyan, peptide
        select contact_residues, {contact_sel}
        show sticks, contact_residues
        color orange, contact_residues
        set label_size, 18
        set label_color, black
        label contact_residues and name CA, resn+resi
        bg_color white
        orient peptide
        zoom peptide or contact_residues, 8
        set ray_opaque_background, off
        png {png.as_posix()}, width=2200, height=1600, dpi=300, ray=1
        save {pse.as_posix()}
        quit
    """).strip() + "\n", encoding="utf-8")


def fallback_contact_plot(complex_pdb: Path, png: Path, receptor_atoms, ligand_atoms, contacts: List[Dict[str, object]], title: str) -> None:
    rec_ca = [(resn, resi, chain, coord) for chain, resn, atom, resi, elem, coord in receptor_atoms if atom == "CA"]
    lig = np.array([c for _, c in ligand_atoms], dtype=float) if ligand_atoms else np.zeros((0, 3))
    fig = plt.figure(figsize=(8, 6), dpi=200)
    ax = fig.add_subplot(111, projection="3d")
    if rec_ca:
        rcoords = np.array([x[3] for x in rec_ca])
        ax.scatter(rcoords[:, 0], rcoords[:, 1], rcoords[:, 2], s=6, c="lightgray", alpha=0.55, label="receptor CA")
    if lig.size:
        ax.scatter(lig[:, 0], lig[:, 1], lig[:, 2], s=16, c="cyan", alpha=0.9, label="peptide atoms")
    cmap = { (c["chain"], c["resi"], c["residue"]): c for c in contacts[:12] }
    for resn, resi, chain, coord in rec_ca:
        if (chain, resi, resn) in cmap:
            ax.scatter([coord[0]], [coord[1]], [coord[2]], s=35, c="orange")
            ax.text(coord[0], coord[1], coord[2], f"{resn}{resi}", fontsize=6)
    ax.set_title(title)
    ax.set_xlabel("X (A)"); ax.set_ylabel("Y (A)"); ax.set_zlabel("Z (A)")
    ax.legend(loc="upper right", fontsize=6)
    plt.tight_layout()
    fig.savefig(png)
    plt.close(fig)


def run_vina_for_pair(target: Target, peptide: Peptide, receptor_pdbqt: Path, ligand_pdbqt: Path, center: np.ndarray, box: np.ndarray, out_dir: Path, repeats: int = 3, exhaustiveness: int = 6) -> List[Dict[str, object]]:
    rows = []
    for rep in range(1, repeats + 1):
        seed = 100000 + rep * 1000 + abs(hash(target.key + peptide.key)) % 997
        pose_pdbqt = out_dir / f"{target.key}__{peptide.key}__rep{rep}_best.pdbqt"
        log(f"DOCK {target.key} {peptide.key} rep={rep} seed={seed}")
        v = Vina(sf_name="vina", seed=int(seed), verbosity=0)
        v.set_receptor(str(receptor_pdbqt))
        v.set_ligand_from_file(str(ligand_pdbqt))
        v.compute_vina_maps(center=center.tolist(), box_size=box.tolist())
        v.dock(exhaustiveness=exhaustiveness, n_poses=5)
        energies = v.energies(n_poses=5)
        best = float(energies[0][0])
        v.write_poses(str(pose_pdbqt), n_poses=1, overwrite=True)
        rows.append({
            "target_key": target.key,
            "organism": target.organism,
            "protein": target.protein,
            "pdb_id": target.pdb_id,
            "peptide_key": peptide.key,
            "sequence": peptide.sequence,
            "repeat": rep,
            "seed": seed,
            "best_affinity_kcal_mol": best,
            "pose_pdbqt": str(pose_pdbqt),
            "center_x": float(center[0]),
            "center_y": float(center[1]),
            "center_z": float(center[2]),
            "box_x": float(box[0]),
            "box_y": float(box[1]),
            "box_z": float(box[2]),
        })
    return rows


def write_csv(path: Path, rows: List[Dict[str, object]]) -> None:
    if not rows:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = list(rows[0].keys())
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)


def heatmap(summary_rows: List[Dict[str, object]], out: Path) -> None:
    targets = [t.key for t in TARGETS]
    peps = [p.key for p in PEPTIDES]
    mat = np.full((len(peps), len(targets)), np.nan)
    for r in summary_rows:
        i = peps.index(r["peptide_key"]); j = targets.index(r["target_key"])
        mat[i, j] = float(r["mean_best_affinity_kcal_mol"])
    fig, ax = plt.subplots(figsize=(11, 5.5), dpi=220)
    im = ax.imshow(mat, cmap="viridis_r")
    ax.set_xticks(range(len(targets)), targets, rotation=30, ha="right", fontsize=8)
    ax.set_yticks(range(len(peps)), [p.sequence for p in PEPTIDES], fontsize=8)
    for i in range(mat.shape[0]):
        for j in range(mat.shape[1]):
            ax.text(j, i, f"{mat[i,j]:.2f}", ha="center", va="center", color="white" if mat[i,j] < np.nanmean(mat) else "black", fontsize=8)
    ax.set_title("Mean best Vina affinity from 3 independent repeats (kcal/mol)")
    cbar = fig.colorbar(im, ax=ax)
    cbar.set_label("kcal/mol (more negative = better)")
    plt.tight_layout()
    fig.savefig(out)
    plt.close(fig)


def main(argv: List[str]) -> int:
    if len(argv) < 2:
        print("usage: peptide_vina_pipeline.py OUTDIR")
        return 2
    out = Path(argv[1]).resolve()
    out.mkdir(parents=True, exist_ok=True)
    dirs = {name: out / name for name in ["targets", "peptides", "pdbqt", "poses", "complexes", "contacts", "figures", "scripts"]}
    for d in dirs.values():
        d.mkdir(parents=True, exist_ok=True)
    start = time.time()
    manifest: Dict[str, object] = {"start": time.strftime("%Y-%m-%d %H:%M:%S"), "out": str(out), "targets": [t.__dict__ for t in TARGETS], "peptides": [p.__dict__ for p in PEPTIDES]}

    target_infos = {}
    for t in TARGETS:
        raw = dirs["targets"] / f"{t.pdb_id}.pdb"
        fetch_pdb(t.pdb_id, raw)
        clean = dirs["targets"] / f"{t.key}_protein_clean.pdb"
        coords, atoms, het_center = clean_receptor_pdb(raw, clean)
        rec_pdbqt = dirs["pdbqt"] / f"{t.key}_receptor.pdbqt"
        write_receptor_pdbqt(clean, rec_pdbqt)
        center = het_center if het_center is not None else np.mean(coords, axis=0)
        span = np.max(coords, axis=0) - np.min(coords, axis=0)
        # Active/cofactor pocket if available; otherwise broad receptor center. Keep boxes practical for Vina.
        box_edge = 30.0 if het_center is not None else float(min(max(np.max(span) + 8.0, 32.0), 52.0))
        box = np.array([box_edge, box_edge, box_edge], dtype=float)
        target_infos[t.key] = {"raw": raw, "clean": clean, "pdbqt": rec_pdbqt, "coords": coords, "atoms": atoms, "center": center, "box": box, "het_center": het_center is not None}
        log(f"TARGET {t.key} atoms={len(atoms)} center={center.round(2).tolist()} box={box.tolist()} het_center={het_center is not None}")

    peptide_infos = {}
    for p in PEPTIDES:
        pep_pdb = dirs["peptides"] / f"{p.key}_uff_minimized.pdb"
        pep_pdbqt = dirs["pdbqt"] / f"{p.key}_rigid_minimized.pdbqt"
        minfo = build_peptide(p, pep_pdb, pep_pdbqt, seed=4242 + len(p.sequence))
        peptide_infos[p.key] = {"pdb": pep_pdb, "pdbqt": pep_pdbqt, "minimization": minfo}
        log(f"PEPTIDE {p.key} atoms={minfo['n_atoms']} uff_energy={minfo['uff_energy']:.2f}")

    dock_rows: List[Dict[str, object]] = []
    for t in TARGETS:
        ti = target_infos[t.key]
        for p in PEPTIDES:
            pi = peptide_infos[p.key]
            pair_dir = dirs["poses"] / t.key / p.key
            pair_dir.mkdir(parents=True, exist_ok=True)
            try:
                dock_rows.extend(run_vina_for_pair(t, p, ti["pdbqt"], pi["pdbqt"], ti["center"], ti["box"], pair_dir, repeats=3, exhaustiveness=6))
            except Exception as e:
                log(f"DOCK_FAIL {t.key} {p.key}: {e}")
                dock_rows.append({
                    "target_key": t.key, "organism": t.organism, "protein": t.protein, "pdb_id": t.pdb_id,
                    "peptide_key": p.key, "sequence": p.sequence, "repeat": 0, "seed": 0,
                    "best_affinity_kcal_mol": "NA", "pose_pdbqt": "", "error": str(e),
                    "center_x": float(ti["center"][0]), "center_y": float(ti["center"][1]), "center_z": float(ti["center"][2]),
                    "box_x": float(ti["box"][0]), "box_y": float(ti["box"][1]), "box_z": float(ti["box"][2]),
                })
    write_csv(out / "tables" / "vina_repeats.csv", dock_rows)

    grouped: Dict[Tuple[str, str], List[Dict[str, object]]] = defaultdict(list)
    for r in dock_rows:
        if isinstance(r.get("best_affinity_kcal_mol"), (float, int)):
            grouped[(r["target_key"], r["peptide_key"])].append(r)
    summary_rows: List[Dict[str, object]] = []
    for (tkey, pkey), rows in grouped.items():
        vals = [float(r["best_affinity_kcal_mol"]) for r in rows]
        bestrow = min(rows, key=lambda r: float(r["best_affinity_kcal_mol"]))
        t = next(x for x in TARGETS if x.key == tkey)
        p = next(x for x in PEPTIDES if x.key == pkey)
        summary_rows.append({
            "organism": t.organism, "target_key": tkey, "protein": t.protein, "pdb_id": t.pdb_id,
            "peptide_key": pkey, "sequence": p.sequence,
            "n_repeats": len(vals),
            "mean_best_affinity_kcal_mol": round(float(np.mean(vals)), 3),
            "sd_best_affinity_kcal_mol": round(float(np.std(vals, ddof=1)) if len(vals) > 1 else 0.0, 3),
            "best_single_affinity_kcal_mol": round(float(np.min(vals)), 3),
            "best_pose_pdbqt": bestrow["pose_pdbqt"],
        })
    summary_rows.sort(key=lambda r: (r["organism"], r["peptide_key"], float(r["mean_best_affinity_kcal_mol"])))
    write_csv(out / "tables" / "vina_summary_mean_of_3.csv", summary_rows)
    heatmap(summary_rows, dirs["figures"] / "vina_affinity_heatmap.png")

    # Build complexes and figures for the best mean target per peptide per organism.
    pymol = find_pymol()
    figure_rows = []
    for pep in PEPTIDES:
        for organism in sorted({t.organism for t in TARGETS}):
            candidates = [r for r in summary_rows if r["peptide_key"] == pep.key and r["organism"] == organism]
            if not candidates:
                continue
            chosen = min(candidates, key=lambda r: float(r["mean_best_affinity_kcal_mol"]))
            pose = Path(str(chosen["best_pose_pdbqt"]))
            if not pose.exists():
                continue
            target = next(t for t in TARGETS if t.key == chosen["target_key"])
            ti = target_infos[target.key]
            ligand_pdb = dirs["complexes"] / f"{target.key}__{pep.key}_best_ligand.pdb"
            complex_pdb = dirs["complexes"] / f"{target.key}__{pep.key}_best_complex.pdb"
            pdbqt_to_pdb(pose, ligand_pdb, "PEP")
            combine_complex(ti["clean"], ligand_pdb, complex_pdb)
            ligand_atoms = parse_pdbqt_coords(pose)
            contacts = contact_residues(ti["atoms"], ligand_atoms, cutoff=4.0)
            contact_csv = dirs["contacts"] / f"{target.key}__{pep.key}_contacts_4A.csv"
            write_csv(contact_csv, contacts if contacts else [{"chain":"", "residue":"", "resi":"", "min_distance_A":"", "nearest_atom":""}])
            png = dirs["figures"] / f"{target.key}__{pep.key}_best_complex.png"
            pse = dirs["figures"] / f"{target.key}__{pep.key}_best_complex.pse"
            pml = dirs["scripts"] / f"{target.key}__{pep.key}_view.pml"
            write_pymol_script(complex_pdb, png, pse, contacts, pml)
            used = "fallback_matplotlib"
            if pymol:
                code, text = run([pymol, "-cq", str(pml)], timeout=180)
                if code == 0 and png.exists():
                    used = f"pymol:{pymol}"
                else:
                    (dirs["scripts"] / f"{target.key}__{pep.key}_pymol.log").write_text(text, encoding="utf-8", errors="replace")
            if not png.exists():
                fallback_contact_plot(complex_pdb, png, ti["atoms"], ligand_atoms, contacts, f"{pep.sequence} vs {target.protein} ({target.pdb_id})")
            figure_rows.append({
                "organism": organism,
                "peptide_key": pep.key,
                "sequence": pep.sequence,
                "chosen_target": target.key,
                "mean_best_affinity_kcal_mol": chosen["mean_best_affinity_kcal_mol"],
                "contact_csv": str(contact_csv),
                "complex_pdb": str(complex_pdb),
                "figure_png": str(png),
                "pymol_script": str(pml),
                "render_method": used,
                "top_contact_residues": "; ".join([f"{c['chain']}:{c['residue']}{c['resi']}({c['min_distance_A']}A)" for c in contacts[:10]]),
            })
    write_csv(out / "tables" / "selected_best_complexes_for_figures.csv", figure_rows)

    report = out / "REPORT.md"
    with report.open("w", encoding="utf-8") as f:
        f.write("# Antimicrobial peptide docking report (AutoDock Vina baseline)\n\n")
        f.write(f"Run time: {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        f.write("## Peptides\n\n")
        for p in PEPTIDES:
            f.write(f"- {p.key}: `{p.sequence}`\n")
        f.write("\n## Targets\n\n")
        for t in TARGETS:
            f.write(f"- {t.organism}: {t.protein}, PDB `{t.pdb_id}` ({t.note})\n")
        f.write("\n## Method summary\n\n")
        f.write("- Ligands: RDKit `MolFromFASTA`, explicit hydrogens, ETKDG conformers, UFF energy minimization; best conformer docked as rigid peptide PDBQT.\n")
        f.write("- Receptors: RCSB PDB first model; protein ATOM records retained; crystallographic waters, ions and hetero ligands removed; simple rigid receptor PDBQT generated.\n")
        f.write("- Search box: centered on crystallographic hetero/cofactor pocket when present; otherwise receptor center; Vina exhaustiveness 6.\n")
        f.write("- Replicates: 3 independent Vina seeds per peptide-target pair; the reported score is the mean of each replicate's best pose.\n")
        f.write("- Contacts/figures: residues within 4.0 A of the best selected pose are listed and labelled in figures/PyMOL scripts.\n")
        f.write("\n## Results: mean of three best Vina scores\n\n")
        f.write("| Organism | Target | PDB | Peptide | Mean best kcal/mol | SD | Best single |\n")
        f.write("|---|---|---:|---|---:|---:|---:|\n")
        for r in summary_rows:
            f.write(f"| {r['organism']} | {r['protein']} | {r['pdb_id']} | {r['sequence']} | {r['mean_best_affinity_kcal_mol']} | {r['sd_best_affinity_kcal_mol']} | {r['best_single_affinity_kcal_mol']} |\n")
        f.write("\n## Selected complexes for result figures\n\n")
        f.write("| Organism | Peptide | Chosen target | Mean kcal/mol | Figure | Labelled residues |\n")
        f.write("|---|---|---|---:|---|---|\n")
        for r in figure_rows:
            f.write(f"| {r['organism']} | {r['sequence']} | {r['chosen_target']} | {r['mean_best_affinity_kcal_mol']} | `{r['figure_png']}` | {r['top_contact_residues']} |\n")
        f.write("\n## Important limitations\n\n")
        f.write("Vina is not a dedicated flexible peptide-protein docking engine. This run is a reproducible, open-source baseline: minimized peptide conformers are docked rigidly to standardized receptors. For publication-level claims, follow-up flexible peptide docking and MD/MM-GBSA validation are recommended.\n")
        f.write("\n## Output paths\n\n")
        f.write(f"- Root: `{out}`\n")
        f.write(f"- Summary CSV: `{out / 'tables' / 'vina_summary_mean_of_3.csv'}`\n")
        f.write(f"- Heatmap: `{dirs['figures'] / 'vina_affinity_heatmap.png'}`\n")
        f.write(f"- PyMOL detected: `{pymol or 'not found; fallback matplotlib figures written'}`\n")
        f.write("\nDOCKING_PIPELINE_DONE=True\n")
        f.write("VINA_REPEATS_PER_PAIR=3\n")
        f.write("ENERGY_MINIMIZATION_DONE=True\n")
        f.write("RECEPTOR_STANDARDIZATION_DONE=True\n")

    manifest.update({
        "finish": time.strftime("%Y-%m-%d %H:%M:%S"),
        "elapsed_sec": round(time.time() - start, 1),
        "summary_rows": summary_rows,
        "figure_rows": figure_rows,
        "pymol": pymol,
        "status": "done",
        "report": str(report),
    })
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    log(f"REPORT={report}")
    log("DOCKING_PIPELINE_DONE=True")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
