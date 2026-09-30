#!/usr/bin/env python3
# t49_dump_refs.py - dump English.docx paragraphs around the References
# heading, detect ref-entry format, and reverse-match entries against the
# local Zotero library (normalized zotero title inside ref text).
# Writes results/status/english_refs_list.json + stdout summary.
import json
import re
import sqlite3
import sys
import zipfile
from pathlib import Path

docx = r"E:\0writing\Light-skills\projects\English.docx"

with zipfile.ZipFile(docx) as z:
    xml = z.read("word/document.xml").decode("utf-8")

paras = re.findall(r'(?s)<w:p\b.*?</w:p>', xml)
pdata = []
for i, p in enumerate(paras):
    sm = re.search(r'<w:pStyle w:val="([^"]+)"', p)
    text = ''.join(m.group(1) for m in re.finditer(r'<w:t(?: [^>]*)?>([^<]*)</w:t>', p))
    pdata.append({'i': i, 'style': sm.group(1) if sm else '', 'text': text})

# ---- dump paragraphs 620..end
lines = ["# r60: paragraphs 620..end of English.docx", ""]
print("--- paragraphs 620..end (idx | style | text) ---")
for d in pdata[620:]:
    if d['text'].strip():
        line = f"{d['i']} | {d['style']} | {d['text'][:200]}"
        print(('P ' + line).encode('ascii', 'replace').decode())
        lines.append(f"- {line}")
Path("results/status/english_paras_tail.md").write_text("\n".join(lines), encoding="utf-8")

# ---- detect reference entries after the References heading
start = None
for d in pdata:
    if d['text'].strip().lower() in ('references', 'reference'):
        start = d['i']
        break
entries = []
if start is not None:
    for d in pdata[start + 1:]:
        t = d['text'].strip()
        if not t:
            continue
        m = re.match(r'^\[(\d+)\]\s*(.+)', t) or re.match(r'^(\d+)[\.\)]\s+(.+)', t) or re.match(r'^(\d+)\s{2,}(.+)', t)
        if m:
            entries.append({'n': int(m.group(1)), 'text': t, 'body': m.group(2)})
        elif entries:
            break  # first non-entry after entries started ends the list
print('refs heading at para', start, '; detected entries:', len(entries))
for e in entries[:6]:
    print('E', e['n'], e['body'][:90].encode('ascii', 'replace').decode())

# ---- reverse match against zotero
def norm(s):
    s = s.lower()
    s = re.sub(r'[^a-z0-9]+', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()

zot = []
if entries:
    try:
        con = sqlite3.connect("file:E:/ozotero/zotero.sqlite?mode=ro", uri=True)
        cur = con.cursor()
        q = """
        select idv.value from itemData ida
        join fields f on f.fieldID = ida.fieldID and f.fieldName='title'
        join itemDataValues idv on idv.valueID = ida.valueID
        """
        zot = [r[0] for r in cur.execute(q).fetchall()]
        con.close()
    except Exception as ex:
        print('zotero open failed:', str(ex).encode('ascii', 'replace').decode())

matched = 0
for e in entries:
    nb = norm(e['text'])
    hit = None
    for t in zot:
        nt = norm(t)
        if len(nt) >= 10 and nt in nb:
            hit = t
            break
    e['zotero_title'] = hit
    e['match'] = bool(hit)
    if hit:
        matched += 1

out = {'refs_heading_para': start, 'entries': entries, 'zotero_titles': len(zot)}
Path("results/status/english_refs_list.json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
print('zotero titles:', len(zot), '; matched:', matched, '/', len(entries))
for e in entries[:10]:
    tag = 'HIT ' if e['match'] else 'MISS'
    print(tag, e['n'], (e['zotero_title'] or e['body'])[:80].encode('ascii', 'replace').decode())
