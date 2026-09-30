#!/usr/bin/env python3
# t48_zotero_match.py - match English.docx references against the local
# Zotero library (E:\ozotero\zotero.sqlite, read-only).
# Writes results/status/zotero_match_r59.md + ASCII summary stdout.
import json
import re
import sqlite3
from pathlib import Path

refs = json.loads(Path("results/status/english_citations.json").read_text(encoding="utf-8"))["refs"]

con = sqlite3.connect("file:E:/ozotero/zotero.sqlite?mode=ro", uri=True)
cur = con.cursor()

total_items = cur.execute("select count(*) from items").fetchone()[0]
q = """
select it.itemID, idv.value
from items it
join itemData ida on ida.itemID = it.itemID
join fields f on f.fieldID = ida.fieldID and f.fieldName = 'title'
join itemDataValues idv on idv.valueID = ida.valueID
"""
rows = cur.execute(q).fetchall()
con.close()

def norm(s):
    s = s.lower()
    s = re.sub(r'[^a-z0-9]+', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()

zot = {iid: norm(t) for iid, t in rows}
zot_by_norm = {}
for iid, t in rows:
    zot_by_norm.setdefault(norm(t), []).append((iid, t))

lines = ["# r59: English.docx refs vs local Zotero library", ""]
matched = 0
mapping = []
for r in refs:
    body = r["body"]
    # try progressively shorter prefixes of the reference title
    cands = [body[:80], body[:60], body[:40]]
    hit = None
    for c in cands:
        nc = norm(c)
        if len(nc) < 12:
            continue
        for iid, t in zot_by_norm.items():
            if nc in iid or iid in nc or iid.startswith(nc[:30]):
                hit = (iid, t)
                break
        if hit:
            break
    if hit:
        matched += 1
        mapping.append((r["n"], "HIT", hit[1][:110]))
        lines.append(f"- [{r['n']}] HIT  zotero: {hit[1][:160]}")
    else:
        mapping.append((r["n"], "MISS", body[:110]))
        lines.append(f"- [{r['n']}] MISS docx: {body[:160]}")

Path("results/status/zotero_match_r59.md").write_text("\n".join(lines), encoding="utf-8")
print("zotero items with titles:", len(rows), "of", total_items, "total items")
print("docx refs:", len(refs), " matched:", matched, " missed:", len(refs) - matched)
for n, st, t in mapping[:15]:
    print(f"{n:3d} {st} {t.encode('ascii', 'replace').decode()[:80]}")
