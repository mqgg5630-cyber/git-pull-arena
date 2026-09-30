#!/usr/bin/env python3
# t50_zotero_link.py - THE transformation: make English.docx Zotero-linked
# in place (same path, same visible format), following the proven
# periodontitis-ad-pg-review pipeline (zotero_word_fields.py) adapted for:
#   - plain (non-superscript) citation runs  [n] / [n-m] / [n,m]
#   - AMA/Vancouver reference list ("N. Authors. Title. Journal. Year;...")
#   - citation keys derived from the bracket numbers themselves (no .tex)
# Flow: parse 36 refs -> CSL items; inject ZOTERO_ITEM complex fields
# (embedded itemData, uris [], storeReferences) keeping each run's original
# rPr; wrap the References list in ZOTERO_BIBL; write docProps/custom.xml
# prefs (AMA style, en-US, installed in E:\ozotero\styles); write to a TEMP
# file; VERIFY everything; only then backup original and overwrite.
# Also exports English_Zotero_library.json (importable CSL-JSON).
import json
import re
import shutil
import sys
import zipfile
from copy import deepcopy
from io import BytesIO
from pathlib import Path
from xml.sax.saxutils import escape, unescape

DOCX = r"E:\0writing\Light-skills\projects\English.docx"
BACKUP = r"E:\0writing\Light-skills\projects\English_backup_pre-zotero.docx"
LIB_OUT = r"E:\0writing\Light-skills\projects\English_Zotero_library.json"
TEMP_OUT = DOCX + ".zotlive.tmp"

STYLE_ID = "http://www.zotero.org/styles/american-medical-association"
LOCALE = "en-US"
SESSION = "EnglishZotero01"
CSL_SCHEMA = "https://github.com/citation-style-language/schema/raw/master/csl-citation.json"
MAX_PROPERTY_LENGTH = 255
CUSTOM_PROPS_PART = "docProps/custom.xml"
CUSTOM_PROPS_CONTENT_TYPE = "application/vnd.openxmlformats-officedocument.custom-properties+xml"
CUSTOM_PROPS_REL_TYPE = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/custom-properties"
_FMTID = "{D5CDD505-2E9C-101B-9397-08002B2CF9AE}"


def fail(msg):
    print("FAIL:", msg)
    sys.exit(1)


# ---------------------------------------------------------------- read doc
with zipfile.ZipFile(DOCX) as z:
    parts = {i.filename: z.read(i.filename) for i in z.infolist()}
    infos = list(z.infolist())
doc_xml = parts["word/document.xml"].decode("utf-8")


def paras_of(xml):
    out = []
    for pm in re.finditer(r'(?s)<w:p\b.*?</w:p>', xml):
        p = pm.group(0)
        style = re.search(r'<w:pStyle w:val="([^"]+)"', p)
        text = ''.join(m.group(1) for m in re.finditer(r'<w:t(?: [^>]*)?>([^<]*)</w:t>', p))
        out.append({'m': pm, 'style': style.group(1) if style else '', 'text': text})
    return out


paras = paras_of(doc_xml)

# ------------------------------------------------- 1. references -> CSL
refs_start = None
for d in paras:
    if d['text'].strip().lower() == 'references':
        refs_start = d['m'].start()
        break
if refs_start is None:
    fail("References heading not found")

ref_entries = []  # (n, text)
for d in paras:
    if d['m'].start() <= refs_start:
        continue
    t = d['text'].strip()
    m = re.match(r'^(\d{1,2})\.\s+(.+)$', t)
    if m:
        ref_entries.append((int(m.group(1)), m.group(2)))
    elif ref_entries:
        break
print("ref entries:", len(ref_entries))
if len(ref_entries) < 30:
    fail("too few reference entries parsed (%d)" % len(ref_entries))


def parse_ref(body):
    segs = body.split('. ')
    if len(segs) < 4:
        return None
    authors_s, title, journal = segs[0].strip(), segs[1].strip(), segs[2].strip()
    tail = '. '.join(segs[3:])
    doi = ''
    dm = re.search(r'doi:\s*(10\.\d{4,9}/\S+?)\.?\s*$', body, re.I) or re.search(r'(10\.\d{4,9}/\S+)', body)
    if dm:
        doi = dm.group(1).rstrip('.')
    ym = re.search(r'(\d{4});([\d\-]+)(?:\(([^)]+)\))?:(\S+?)\.?\s*(?:doi|$)', tail)
    year = vol = issue = page = ''
    if ym:
        year, vol, issue, page = ym.group(1), ym.group(2), ym.group(3) or '', ym.group(4)
    else:
        ym2 = re.search(r'(\d{4})', tail)
        year = ym2.group(1) if ym2 else ''
    # authors
    authors = []
    for a in authors_s.split(', '):
        a = a.strip()
        if not a or a.lower() in ('et al', 'et al.'):
            continue
        am = re.match(r'^(.+?)\s+([A-Z](?:\s*[A-Z]){0,3})$', a)
        if am:
            authors.append({'family': am.group(1), 'given': am.group(2).replace(' ', '')})
        else:
            authors.append({'literal': a})
    item = {
        'id': '', 'type': 'article-journal',
        'author': authors, 'title': title,
        'container-title': journal,
        'issued': {'date-parts': [[int(year)]]} if year else {},
        'DOI': doi,
    }
    if vol:
        item['volume'] = vol
    if issue:
        item['issue'] = issue
    if page:
        item['page'] = page.replace('\u2013', '-')
    return item


library = {}
ref_items = []
for n, body in ref_entries:
    it = parse_ref(body)
    if it is None:
        fail("cannot parse ref %d: %s" % (n, body[:80]))
    it['id'] = 'ref%d' % n
    library[it['id']] = it
    ref_items.append(it)
    print("REF %2d | %d authors | %-58s | %s" % (n, len(it['author']), it['title'][:58].encode('ascii', 'replace').decode(), it['DOI'][:40]))

bad = [it['id'] for it in ref_items if len(it.get('title', '')) < 8 or not it.get('author') or not it.get('DOI')]
if bad:
    print("WARN refs with weak metadata:", bad)

# ------------------------------------------------- 2. citation fields
def nums_from(inner):
    out = []
    for p in inner.split(','):
        p = p.strip()
        m = re.fullmatch(r'(\d{1,3})(?:[\u2013\-](\d{1,3}))?', p)
        if not m:
            return None
        a = int(m.group(1))
        b = int(m.group(2)) if m.group(2) else a
        out.extend(range(a, b + 1))
    return out


run_pattern = re.compile(r'(?s)<w:r\b[^>]*>(?:(?!</w:r>).)*?</w:r>')
bracket_pattern = re.compile(r'\[[0-9,\s\u2013\-]+\]')
state = {'n': 0, 'replaced': 0, 'displays': []}


def field_xml(keys, display, rpr):
    state['n'] += 1
    citation_items = []
    for k in keys:
        item = deepcopy(library['ref%d' % k])
        citation_items.append({'id': item['id'], 'uris': [], 'itemData': item})
    payload = {
        'citationID': 'cEngCite%03d' % state['n'],
        'properties': {'formattedCitation': display, 'plainCitation': display, 'noteIndex': 0},
        'citationItems': citation_items,
        'schema': CSL_SCHEMA,
    }
    code = 'ADDIN ZOTERO_ITEM CSL_CITATION ' + json.dumps(payload, ensure_ascii=False, separators=(',', ':'))
    return (
        '<w:r><w:fldChar w:fldCharType="begin"/></w:r>'
        '<w:r><w:instrText xml:space="preserve"> ' + escape(code) + ' </w:instrText></w:r>'
        '<w:r><w:fldChar w:fldCharType="separate"/></w:r>'
        '<w:r>' + rpr + '<w:t xml:space="preserve">' + escape(display) + '</w:t></w:r>'
        '<w:r><w:fldChar w:fldCharType="end"/></w:r>'
    )


def repl_run(m):
    run = m.group(0)
    tm = re.search(r'<w:t\b[^>]*>([^<]*)</w:t>', run)
    if not tm:
        return run
    t = tm.group(1)
    bm = bracket_pattern.search(t)
    if not bm:
        return run
    keys = nums_from(bm.group(0)[1:-1])
    if not keys or any(k not in range(1, 37) for k in keys):
        return run
    rpm = re.match(r'(?s)\s*<w:r\b[^>]*>\s*(<w:rPr>(?:(?!</w:rPr>).)*?</w:rPr>)', run)
    rpr = rpm.group(1) if rpm else ''
    fld = field_xml(keys, bm.group(0), rpr)
    plain = unescape(t)
    before, after = plain[:bm.start()], plain[bm.end():]
    out = []
    if before:
        out.append('<w:r>' + rpr + '<w:t xml:space="preserve">' + escape(before) + '</w:t></w:r>')
    out.append(fld)
    if after:
        out.append('<w:r>' + rpr + '<w:t xml:space="preserve">' + escape(after) + '</w:t></w:r>')
    state['replaced'] += 1
    state['displays'].append(bm.group(0))
    return ''.join(out)


doc_xml2 = run_pattern.sub(repl_run, doc_xml)
print("citation fields injected:", state['replaced'])
if state['replaced'] < 55:
    fail("too few citations replaced (%d)" % state['replaced'])

# leftovers?
leftover = []
for rm in run_pattern.finditer(doc_xml2):
    tm = re.search(r'<w:t\b[^>]*>([^<]*)</w:t>', rm.group(0))
    if tm and bracket_pattern.fullmatch(tm.group(1).strip()):
        leftover.append(tm.group(1))
print("plain bracket runs remaining:", len(leftover), leftover[:5])

# ------------------------------------------------- 3. bibliography wrap
paras2 = paras_of(doc_xml2)
ref_paras = [d for d in paras2 if d['m'].start() > refs_start and d['style'] == 'Reference' and re.match(r'^\d{1,2}\.\s', d['text'].strip())]
print("bibliography paragraphs:", len(ref_paras))
if len(ref_paras) < 30:
    fail("bibliography paragraphs not found")

first, last = ref_paras[0], ref_paras[-1]
bib_start_code = (
    '<w:r><w:fldChar w:fldCharType="begin"/></w:r>'
    '<w:r><w:instrText xml:space="preserve"> ADDIN ZOTERO_BIBL {"uncited":[],"omitted":[],"custom":[]} CSL_BIBLIOGRAPHY </w:instrText></w:r>'
    '<w:r><w:fldChar w:fldCharType="separate"/></w:r>'
)
bib_end_code = '<w:r><w:fldChar w:fldCharType="end"/></w:r>'


def insert_into_para(pxml, code, at_end):
    if at_end:
        pos = pxml.rfind('</w:p>')
        return pxml[:pos] + code + pxml[pos:]
    pos = pxml.find('</w:pPr>')
    if pos >= 0:
        pos += len('</w:pPr>')
        return pxml[:pos] + code + pxml[pos:]
    m = re.match(r'(?s)(<w:p\b[^>]*>)', pxml)
    pos = m.end()
    return pxml[:pos] + code + pxml[pos:]


new_first = insert_into_para(first['m'].group(0), bib_start_code, False)
new_last = insert_into_para(last['m'].group(0), bib_end_code, True)
doc_xml3 = (
    doc_xml2[:first['m'].start()] + new_first
    + doc_xml2[first['m'].end():last['m'].start()] + new_last
    + doc_xml2[last['m'].end():]
)

# ------------------------------------------------- 4. doc prefs
prefs = json.dumps({
    'style': {'styleID': STYLE_ID, 'locale': LOCALE, 'hasBibliography': True, 'bibliographyStyleHasBeenSet': True},
    'prefs': {'fieldType': 'Field', 'storeReferences': True, 'automaticJournalAbbreviations': True, 'noteType': 0},
    'sessionID': SESSION,
    'zoteroVersion': '7.0.0',
    'dataVersion': 3,
}, ensure_ascii=False, separators=(',', ':'))
chunks = [prefs[i:i + MAX_PROPERTY_LENGTH] for i in range(0, len(prefs), MAX_PROPERTY_LENGTH)] or ['']
props = ''.join(
    '<property fmtid="%s" pid="%d" name="ZOTERO_PREF_%d"><vt:lpwstr>%s</vt:lpwstr></property>' % (_FMTID, 2 + i, i + 1, escape(c))
    for i, c in enumerate(chunks)
)
custom_xml = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/custom-properties" '
    'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
    + props + '</Properties>\n'
)

parts2 = dict(parts)
parts2['word/document.xml'] = doc_xml3.encode('utf-8')
parts2[CUSTOM_PROPS_PART] = custom_xml.encode('utf-8')
ct = parts2.get('[Content_Types].xml', b'').decode('utf-8')
if 'PartName="/%s"' % CUSTOM_PROPS_PART not in ct:
    ct = ct.replace('</Types>', '<Override PartName="/%s" ContentType="%s"/></Types>' % (CUSTOM_PROPS_PART, CUSTOM_PROPS_CONTENT_TYPE), 1)
parts2['[Content_Types].xml'] = ct.encode('utf-8')
rels = parts2.get('_rels/.rels', b'').decode('utf-8')
if CUSTOM_PROPS_REL_TYPE not in rels:
    rels = rels.replace('</Relationships>', '<Relationship Id="rIdZoteroPref" Type="%s" Target="%s"/></Relationships>' % (CUSTOM_PROPS_REL_TYPE, CUSTOM_PROPS_PART), 1)
parts2['_rels/.rels'] = rels.encode('utf-8')

buf = BytesIO()
with zipfile.ZipFile(buf, 'w', compression=zipfile.ZIP_DEFLATED) as zout:
    written = set()
    for info in infos:
        ni = zipfile.ZipInfo(filename=info.filename, date_time=info.date_time)
        ni.compress_type = zipfile.ZIP_DEFLATED
        zout.writestr(ni, parts2[info.filename])
        written.add(info.filename)
    for name, content in parts2.items():
        if name not in written:
            zout.writestr(name, content)
Path(TEMP_OUT).write_bytes(buf.getvalue())
print("temp written:", TEMP_OUT)

# ------------------------------------------------- 5. verify
errs = []
with zipfile.ZipFile(TEMP_OUT) as z:
    names = set(z.namelist())
    vx = z.read('word/document.xml').decode('utf-8')
zitem = vx.count('ZOTERO_ITEM')
zbib = vx.count('ZOTERO_BIBL')
if zitem != state['replaced']:
    errs.append('ZOTERO_ITEM=%d expected %d' % (zitem, state['replaced']))
if zbib != 1:
    errs.append('ZOTERO_BIBL=%d expected 1' % zbib)
if 'fldSimple' in vx:
    errs.append('fldSimple present')
if CUSTOM_PROPS_PART not in names:
    errs.append('custom.xml missing')
# payloads
payloads = []
for im in re.finditer(r'<w:instrText[^>]*>(.*?)</w:instrText>', vx, re.DOTALL):
    t = unescape(im.group(1))
    if 'CSL_CITATION' in t:
        try:
            payloads.append(json.loads(t[t.find('{'):]))
        except Exception as e:
            errs.append('payload json: %s' % e)
cids = [p['citationID'] for p in payloads]
if len(cids) != len(set(cids)):
    errs.append('citationIDs not unique')
for p in payloads:
    if p['properties']['noteIndex'] != 0:
        errs.append('noteIndex != 0')
    for ci in p['citationItems']:
        if ci.get('uris') != []:
            errs.append('uris not empty')
        if ci['id'] != ci['itemData']['id']:
            errs.append('id mismatch')
        if not ci['itemData'].get('title'):
            errs.append('empty title')
# prefs parse
with zipfile.ZipFile(TEMP_OUT) as z:
    craw = z.read(CUSTOM_PROPS_PART).decode('utf-8')
chunks_read = []
for pm in re.finditer(r'name="ZOTERO_PREF_(\d)"[^>]*><vt:lpwstr>(.*?)</vt:lpwstr>', craw):
    chunks_read.append((int(pm.group(1)), unescape(pm.group(2))))
prefs_read = json.loads(''.join(c for _, c in sorted(chunks_read)))
if prefs_read.get('dataVersion') != 3 or prefs_read.get('prefs', {}).get('fieldType') != 'Field':
    errs.append('prefs wrong')
if 'american-medical-association' not in prefs_read['style']['styleID']:
    errs.append('style id wrong')
# visible text preserved
vis = ''.join(m.group(1) for m in re.finditer(r'<w:t(?: [^>]*)?>([^<]*)</w:t>', vx))
for d in state['displays']:
    if escape(d) not in vx and d not in vis:
        errs.append('display lost: %s' % d)
# python-docx opens
try:
    import docx as _docx
    _doc = _docx.Document(TEMP_OUT)
    print('python-docx opens OK, paragraphs:', len(_doc.paragraphs))
except Exception as e:
    errs.append('python-docx: %s' % e)

if errs:
    for e in errs:
        print('ERR', e.encode('ascii', 'replace').decode())
    fail('verification failed - original left untouched')

# ------------------------------------------------- 6. commit
shutil.copy2(DOCX, BACKUP)
shutil.copy2(TEMP_OUT, DOCX)
Path(TEMP_OUT).unlink(missing_ok=True)
Path(LIB_OUT).write_text(json.dumps(ref_items, ensure_ascii=False, indent=2), encoding='utf-8')
print('BACKUP :', BACKUP)
print('OUTPUT :', DOCX, '(same path, zotero-linked)')
print('LIBRARY:', LIB_OUT, '(%d items, importable CSL-JSON)' % len(ref_items))
print('VERIFIED: %d ZOTERO_ITEM fields + 1 ZOTERO_BIBL ; style=AMA en-US (installed) ; displays preserved' % zitem)
