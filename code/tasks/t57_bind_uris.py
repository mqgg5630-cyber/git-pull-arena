#!/usr/bin/env python3
# t57_bind_uris.py - round 69: bind the citation fields of English.docx to
# the REAL Zotero items just imported: for each citation item, fill
# uris = ["http://zotero.org/users/0/items/<KEY>"] by matching DOI against
# the Zotero sqlite (snapshot copy, since the live db is locked).
# Keeps embedded itemData + everything else. Verify then overwrite in place.
import json
import re
import shutil
import sqlite3
import sys
import tempfile
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape, unescape

DOCX = Path(r"E:\0writing\Light-skills\projects\English.docx")
TEMP_OUT = DOCX.with_suffix('.docx.zotlive5.tmp')
SQLITE = Path(r"E:\ozotero\zotero.sqlite")
LIB = Path(r"E:\0writing\Light-skills\projects\English_Zotero_library.json")


def fail(msg):
    print("FAIL:", msg)
    sys.exit(1)


# ---------------- 1. snapshot sqlite (+wal) and build DOI -> key map
tmpdir = Path(tempfile.mkdtemp(prefix="zsq_"))
try:
    sq_copy = tmpdir / "zotero.sqlite"
    shutil.copy2(SQLITE, sq_copy)
    for ext in ("-wal", "-shm"):
        p = SQLITE.with_name("zotero.sqlite" + ext)
        if p.exists():
            shutil.copy2(p, tmpdir / ("zotero.sqlite" + ext))
    con = sqlite3.connect(str(sq_copy))
    cur = con.cursor()
    rows = cur.execute("""
        select i.itemID, i.key, i.libraryID, lower(v.value)
        from items i
        join itemData d on d.itemID = i.itemID
        join fields f on f.fieldID = d.fieldID and f.fieldName = 'DOI'
        join itemDataValues v on v.valueID = d.valueID
    """).fetchall()
    n_items = cur.execute("select count(*) from items").fetchone()[0]
    con.close()
finally:
    shutil.rmtree(tmpdir, ignore_errors=True)

doi2key = {}
for itemID, key, lib, ldoi in rows:
    if ldoi and ldoi not in doi2key:
        doi2key[ldoi] = (key, lib)
print("zotero snapshot: %d items, %d with DOI" % (n_items, len(rows)))

my_items = json.loads(LIB.read_text(encoding="utf-8"))
missing = []
for it in my_items:
    ldoi = (it.get("DOI") or "").lower()
    if ldoi and ldoi in doi2key:
        it["_key"] = doi2key[ldoi][0]
        it["_lib"] = doi2key[ldoi][1]
    else:
        missing.append(it["id"])
print("matched %d/%d by DOI; missing: %s" % (len(my_items) - len(missing), len(my_items), missing))
if missing:
    fail("some refs not found in zotero db")

# ---------------- 2. rewrite uris in the docx fields
with zipfile.ZipFile(DOCX) as z:
    parts = {i.filename: z.read(i.filename) for i in z.infolist()}
    infos = list(z.infolist())
xml = parts["word/document.xml"].decode("utf-8")


def fix_instr(m):
    inner = m.group(1)
    if 'CSL_CITATION' not in inner:
        return m.group(0)
    plain = unescape(inner)
    b = plain.find('{')
    try:
        payload = json.loads(plain[b:])
    except Exception as e:
        print("payload parse fail:", e)
        return m.group(0)
    changed = False
    for ci in payload.get('citationItems', []):
        doi = (ci.get('itemData', {}).get('DOI') or '').lower()
        if doi and doi in doi2key:
            key, lib = doi2key[doi]
            uri = 'http://zotero.org/users/0/items/' + key
            if ci.get('uris') != [uri]:
                ci['uris'] = [uri]
                changed = True
    if not changed:
        return m.group(0)
    new_plain = plain[:b] + json.dumps(payload, ensure_ascii=False, separators=(',', ':'))
    return m.group(0).replace(inner, escape(new_plain))


new_xml, n_subs = re.subn(r'<w:instrText[^>]*>(.*?)</w:instrText>', fix_instr, xml, flags=re.DOTALL)
print("instrText blocks scanned; citation payloads with bound uris rewritten")
bound = 0
total = 0
for im in re.finditer(r'<w:instrText[^>]*>(.*?)</w:instrText>', new_xml, re.DOTALL):
    t = unescape(im.group(1))
    if 'CSL_CITATION' not in t:
        continue
    p = json.loads(t[t.find('{'):])
    for ci in p.get('citationItems', []):
        total += 1
        if ci.get('uris'):
            bound += 1
print("citation items total=%d bound=%d" % (total, bound))
if bound < total:
    fail("not all citation items bound (%d/%d)" % (bound, total))

parts2 = dict(parts)
parts2['word/document.xml'] = new_xml.encode('utf-8')
import io
bio = io.BytesIO()
with zipfile.ZipFile(bio, 'w', compression=zipfile.ZIP_DEFLATED) as zout:
    written = set()
    for info in infos:
        ni = zipfile.ZipInfo(filename=info.filename, date_time=info.date_time)
        ni.compress_type = zipfile.ZIP_DEFLATED
        zout.writestr(ni, parts2[info.filename])
        written.add(info.filename)
    for name, content in parts2.items():
        if name not in written:
            zout.writestr(name, content)
TEMP_OUT.write_bytes(bio.getvalue())

# ---------------- 3. verify temp then commit
errs = []
with zipfile.ZipFile(TEMP_OUT) as z:
    vx = z.read('word/document.xml').decode('utf-8')
    import docx as _d
    _ = _d.Document(str(TEMP_OUT))
if vx.count('ZOTERO_ITEM') != 62 or vx.count('ZOTERO_BIBL') != 1:
    errs.append('field counts changed!')
if 'fldSimple' in vx:
    errs.append('fldSimple')
if errs:
    for e in errs:
        print('ERR', e)
    fail('verify failed; original untouched')

shutil.copy2(TEMP_OUT, DOCX)
TEMP_OUT.unlink(missing_ok=True)
print('SUCCESS: all %d citation items now bound to real Zotero items (uris filled)' % bound)
print('OUTPUT :', DOCX)
