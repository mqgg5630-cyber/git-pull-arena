#!/usr/bin/env python3
# t54_crossref_verify.py - verify all 36 references of English.docx against
# Crossref by DOI: is each reference REAL, and does the parsed metadata
# (title/year/journal) match? Writes results/status/ref_verify_r66.md.
import difflib
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

LIB = Path(r"E:\0writing\Light-skills\projects\English_Zotero_library.json")
OUT = Path("results/status/ref_verify_r66.md")

items = json.loads(LIB.read_text(encoding="utf-8"))
print("items to verify:", len(items))

results = []
for it in items:
    doi = it.get("DOI", "")
    rec = {"n": int(it["id"][3:]), "doi": doi, "ok": False, "ratio": 0.0,
           "cr_title": "", "cr_year": "", "cr_journal": "", "err": "",
           "title": it.get("title", ""), "year": str((it.get("issued", {}).get("date-parts") or [[None]])[0][0] or ""),
           "journal": it.get("container-title", "")}
    try:
        url = "https://api.crossref.org/works/" + urllib.parse.quote(doi, safe="")
        req = urllib.request.Request(url, headers={"User-Agent": "ref-verify/1.0 (mailto:check@localhost)"})
        with urllib.request.urlopen(req, timeout=25) as r:
            m = json.load(r)["message"]
        rec["cr_title"] = (m.get("title") or [""])[0]
        rec["cr_year"] = str((m.get("issued", {}).get("date-parts") or [[None]])[0][0] or "")
        rec["cr_journal"] = (m.get("container-title") or [""])[0]
        rec["ok"] = True
        rec["ratio"] = round(difflib.SequenceMatcher(None, rec["title"].lower(), rec["cr_title"].lower()).ratio(), 3)
    except Exception as e:
        rec["err"] = str(e)[:120]
    results.append(rec)
    print("ref%-2d %s ratio=%.2f %s" % (rec["n"], "OK " if rec["ok"] else "ERR", rec["ratio"], (rec["cr_title"] or rec["err"])[:60].encode("ascii", "replace").decode()))
    time.sleep(0.35)

verdict = lambda r: "REAL" if (r["ok"] and r["ratio"] >= 0.75) else ("CHECK" if r["ok"] else "NOT-FOUND")
lines = ["# r66: reference verification (Crossref by DOI)", "",
         "| # | verdict | title-similarity | year | yearCR | journal match | DOI |", "|---|---|---|---|---|---|---|"]
for r in results:
    jmatch = "yes" if r["ok"] and (r["cr_journal"].lower()[:25] in r["journal"].lower() or r["journal"].lower()[:25] in r["cr_journal"].lower()) else ("?" if r["ok"] else "-")
    ymatch = r["year"] if r["ok"] else "-"
    ycr = r["cr_year"] if r["ok"] else "-"
    lines.append("| %d | %s | %.2f | %s | %s | %s | %s |" % (r["n"], verdict(r), r["ratio"], ymatch, ycr, jmatch, r["doi"]))
lines += ["", "## mismatches / problems", ""]
probs = [r for r in results if not (r["ok"] and r["ratio"] >= 0.75 and (r["cr_year"] == r["year"]))]
if not probs:
    lines.append("- none: all references verified REAL with matching metadata")
for r in probs:
    lines.append("- ref%d (%s): title sim %.2f; docx year %s vs crossref %s; %s" % (r["n"], verdict(r), r["ratio"], r["year"], r["cr_year"], r["err"] or ""))
    lines.append("  - docx:   %s" % r["title"][:130])
    lines.append("  - crossref: %s" % (r["cr_title"][:130] or r["err"]))
OUT.write_text("\n".join(lines), encoding="utf-8")
nreal = sum(1 for r in results if r["ok"] and r["ratio"] >= 0.75)
print("VERIFIED REAL:", nreal, "/", len(results))
print("problems:", len(probs))
