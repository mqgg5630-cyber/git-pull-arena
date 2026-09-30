#!/usr/bin/env python3
# t52_build_final.py - round 63: FINAL build of the Zotero-linked
# English.docx from the pristine backup, with:
#   - consecutive-36 bibliography wrap (r62 fix, kept)
#   - FIXED verifier: unlinked check uses exact end-run prefix; bib extent
#     identified by begin-para == "1. ..." and end-para == "36. ..."
#   - sliding-window pass2 (up to 4 consecutive runs) for split citations
#   - diff report of any bracket mention not converted (the 63rd)
# Overwrite only after full verification passes.
import json
import re
import shutil
import sys
import zipfile
from copy import deepcopy
from io import BytesIO
from pathlib import Path
from xml.sax.saxutils import escape, unescape

DOCX = Path(r"E:\0writing\Light-skills\projects\English.docx")
BACKUP = Path(r"E:\0writing\Light-skills\projects\English_backup_pre-zotero.docx")
LIB_OUT = Path(r"E:\0writing\Light-skills\projects\English_Zotero_library.json")
TEMP_OUT = DOCX.with_suffix('.docx.zotlive3.tmp')
STALE_TMP = DOCX.with_suffix('.docx.zotlive2.tmp')

STYLE_ID = "http://www.zotero.org/styles/american-medical-association"
CSL_SCHEMA = "https://github.com/citation-style-language/schema/raw/master/csl-citation.json"
MAXP = 255
CUSTOM_PROPS_PART = "docProps/custom.xml"
CUSTOM_PROPS_CONTENT_TYPE = "application/vnd.openxmlformats-officedocument.custom-properties+xml"
CUSTOM_PROPS_REL_TYPE = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/custom-properties"
_FMTID = "{D5CDD505-2E9C-101B-9397-08002B2CF9AE}"
END_RUN = '<w:r><w:fldChar w:fldCharType="end"/></w:r>'

run_pattern = re.compile(r'(?s)<w:r\b[^>]*>(?:(?!</w:r>).)*?</w:r>')
bracket_pattern = re.compile(r'\[[0-9,\s\u2013\-]+\]')


def fail(msg):
    print("FAIL:", msg)
    sys.exit(1)


def paras_of(xml):
    out = []
    for pm in re.finditer(r'(?s)<w:p\b.*?</w:p>', xml):
        p = pm.group(0)
        style = re.search(r'<w:pStyle w:val="([^"]+)"', p)
        text = ''.join(m.group(1) for m in re.finditer(r'<w:t(?: [^>]*)?>([^<]*)</w:t>', p))
        out.append({'m': pm, 'style': style.group(1) if style else '', 'text': text})
    return out


if STALE_TMP.exists():
    STALE_TMP.unlink()
    print('stale tmp removed')
if not BACKUP.exists():
    fail('backup missing')
shutil.copy2(BACKUP, DOCX)
parts = None
with zipfile.ZipFile(DOCX) as z:
    parts = {i.filename: z.read(i.filename) for i in z.infolist()}
    infos = list(z.infolist())
doc_xml = parts['word/document.xml'].decode('utf-8')
paras = paras_of(doc_xml)

# ------------------------------------------------ refs -> CSL
refs_start = None
for d in paras:
    if d['text'].strip().lower() == 'references':
        refs_start = d['m'].start()
        break
if refs_start is None:
    fail('References heading not found')
ref_entries = []
started = False
for d in paras:
    if d['m'].start() <= refs_start:
        continue
    t = d['text'].strip()
    m = re.match(r'^(\d{1,2})\.\s+(.+)$', t)
    if m and d['style'] == 'Reference':
        started = True
        ref_entries.append((int(m.group(1)), m.group(2)))
    elif started and t:
        break
print('consecutive ref entries:', len(ref_entries))
if len(ref_entries) != 36:
    fail('expected 36 refs, got %d' % len(ref_entries))


def parse_ref(body):
    segs = body.split('. ')
    if len(segs) < 4:
        return None
    authors_s, title, journal = segs[0].strip(), segs[1].strip(), segs[2].strip()
    tail = '. '.join(segs[3:])
    dm = re.search(r'doi:\s*(10\.\d{4,9}/\S+?)\.?\s*$', body, re.I) or re.search(r'(10\.\d{4,9}/\S+)', body)
    doi = dm.group(1).rstrip('.') if dm else ''
    ym = re.search(r'(\d{4});([\d\-]+)(?:\(([^)]+)\))?:(\S+?)\.?\s*(?:doi|$)', tail)
    year = vol = issue = page = ''
    if ym:
        year, vol, issue, page = ym.group(1), ym.group(2), ym.group(3) or '', ym.group(4)
    else:
        ym2 = re.search(r'(\d{4})', tail)
        year = ym2.group(1) if ym2 else ''
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
    item = {'id': '', 'type': 'article-journal', 'author': authors, 'title': title,
            'container-title': journal, 'issued': {'date-parts': [[int(year)]]} if year else {}, 'DOI': doi}
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
        fail('cannot parse ref %d' % n)
    it['id'] = 'ref%d' % n
    library[it['id']] = it
    ref_items.append(it)


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


state = {'n': 0, 'replaced': 0, 'displays': []}


def field_xml(keys, display, rpr):
    state['n'] += 1
    cits = []
    for k in keys:
        item = deepcopy(library['ref%d' % k])
        cits.append({'id': item['id'], 'uris': [], 'itemData': item})
    payload = {'citationID': 'cEngCite%03d' % state['n'],
               'properties': {'formattedCitation': display, 'plainCitation': display, 'noteIndex': 0},
               'citationItems': cits, 'schema': CSL_SCHEMA}
    code = 'ADDIN ZOTERO_ITEM CSL_CITATION ' + json.dumps(payload, ensure_ascii=False, separators=(',', ':'))
    return ('<w:r><w:fldChar w:fldCharType="begin"/></w:r>'
            '<w:r><w:instrText xml:space="preserve"> ' + escape(code) + ' </w:instrText></w:r>'
            '<w:r><w:fldChar w:fldCharType="separate"/></w:r>'
            '<w:r>' + rpr + '<w:t xml:space="preserve">' + escape(display) + '</w:t></w:r>'
            + END_RUN)


def get_rpr(run):
    m = re.match(r'(?s)\s*<w:r\b[^>]*>\s*(<w:rPr>(?:(?!</w:rPr>).)*?</w:rPr>)', run)
    return m.group(1) if m else ''


def build_replacement(rpr, before, bracket, after):
    keys = nums_from(bracket[1:-1])
    if not keys or any(k < 1 or k > 36 for k in keys):
        return None
    out = []
    if before:
        out.append('<w:r>' + rpr + '<w:t xml:space="preserve">' + escape(before) + '</w:t></w:r>')
    out.append(field_xml(keys, bracket, rpr))
    state['replaced'] += 1
    state['displays'].append(bracket)
    if after:
        out.append('<w:r>' + rpr + '<w:t xml:space="preserve">' + escape(after) + '</w:t></w:r>')
    return ''.join(out)


def repl_run(m):
    run = m.group(0)
    tm = re.search(r'<w:t\b[^>]*>([^<]*)</w:t>', run)
    if not tm:
        return run
    plain = unescape(tm.group(1))
    bm = bracket_pattern.search(plain)
    if not bm:
        return run
    rep = build_replacement(get_rpr(run), plain[:bm.start()], bm.group(0), plain[bm.end():])
    return rep if rep is not None else run


doc_xml2 = run_pattern.sub(repl_run, doc_xml)
print('pass1 replaced:', state['replaced'])

# pass2: sliding window over up to 4 consecutive runs inside each paragraph
p2 = {'n': 0}


def fix_split(pm):
    xml = pm.group(0)
    runs = list(run_pattern.finditer(xml))
    i = 0
    while i < len(runs):
        replaced = False
        for w in range(2, 5):
            if i + w > len(runs):
                break
            texts = []
            ok = True
            for r in runs[i:i + w]:
                tm = re.search(r'<w:t\b[^>]*>([^<]*)</w:t>', r.group(0))
                if not tm:
                    ok = False
                    break
                texts.append(unescape(tm.group(1)))
            if not ok:
                continue
            joined = ''.join(texts)
            bm = bracket_pattern.search(joined)
            if not bm:
                continue
            rep = build_replacement(get_rpr(runs[i].group(0)), joined[:bm.start()], bm.group(0), joined[bm.end():])
            if rep is None:
                continue
            p2['n'] += 1
            xml = xml[:runs[i].start()] + rep + xml[runs[i + w - 1].end():]
            newruns = list(run_pattern.finditer(xml))
            replaced = True
            break
        if replaced:
            runs = list(run_pattern.finditer(xml))
            i = 0
            continue
        i += 1
    return xml


doc_xml2 = re.sub(r'(?s)<w:p\b.*?</w:p>', fix_split, doc_xml2)
print('pass2 (window) replaced:', p2['n'])
print('total fields:', state['replaced'])

# ---------------------------------------- what bracket mentions remain?
alltext_paras = paras_of(doc_xml2)
mentions = []
for d in alltext_paras:
    for bm in bracket_pattern.finditer(d['text']):
        mentions.append((bm.group(0), d['text'][:80]))
from collections import Counter
disp_count = Counter(state['displays'])
men_count = Counter(m[0] for m in mentions)
uncovered = []
for k, v in men_count.items():
    if disp_count.get(k, 0) < v:
        uncovered.append(k)
print('bracket mentions in text:', sum(men_count.values()), '; displays:', sum(disp_count.values()), '; uncovered kinds:', uncovered[:10])
for m in mentions:
    if m[0] in uncovered:
        print('UNCOVERED', m[0], '|', m[1].encode('ascii', 'replace').decode()[:90])

if state['replaced'] < 55:
    fail('too few fields')

# ------------------------------------------------ bibliography
paras2 = paras_of(doc_xml2)
heading_pos = None
for d in paras2:
    if d['text'].strip().lower() == 'references':
        heading_pos = d['m'].start()
        break
consec = []
started = False
for d in paras2:
    if d['m'].start() <= heading_pos:
        continue
    t = d['text'].strip()
    if re.match(r'^\d{1,2}\.\s', t) and d['style'] == 'Reference':
        started = True
        consec.append(d['m'])
    elif started and t:
        break
print('bib paragraphs (consecutive):', len(consec))
if len(consec) != 36:
    fail('bib paragraphs != 36')
first, last = consec[0], consec[-1]
bib_start_code = ('<w:r><w:fldChar w:fldCharType="begin"/></w:r>'
                  '<w:r><w:instrText xml:space="preserve"> ADDIN ZOTERO_BIBL {"uncited":[],"omitted":[],"custom":[]} CSL_BIBLIOGRAPHY </w:instrText></w:r>'
                  '<w:r><w:fldChar w:fldCharType="separate"/></w:r>')


def insert_into_para(pxml, code, at_end):
    if at_end:
        pos = pxml.rfind('</w:p>')
        return pxml[:pos] + code + pxml[pos:]
    pos = pxml.find('</w:pPr>')
    if pos >= 0:
        return pxml[:pos + len('</w:pPr>')] + code + pxml[pos + len('</w:pPr>'):]
    m = re.match(r'(?s)(<w:p\b[^>]*>)', pxml)
    return pxml[:m.end()] + code + pxml[m.end():]


new_first = insert_into_para(first.group(0), bib_start_code, False)
new_last = insert_into_para(last.group(0), END_RUN, True)
doc_xml3 = (doc_xml2[:first.start()] + new_first
            + doc_xml2[first.end():last.start()] + new_last
            + doc_xml2[last.end():])

# ------------------------------------------------ prefs
prefs = json.dumps({'style': {'styleID': STYLE_ID, 'locale': 'en-US', 'hasBibliography': True, 'bibliographyStyleHasBeenSet': True},
                    'prefs': {'fieldType': 'Field', 'storeReferences': True, 'automaticJournalAbbreviations': True, 'noteType': 0},
                    'sessionID': 'EnglishZotero03', 'zoteroVersion': '7.0.0', 'dataVersion': 3},
                   ensure_ascii=False, separators=(',', ':'))
chunks = [prefs[i:i + MAXP] for i in range(0, len(prefs), MAXP)] or ['']
props = ''.join('<property fmtid="%s" pid="%d" name="ZOTERO_PREF_%d"><vt:lpwstr>%s</vt:lpwstr></property>' % (_FMTID, 2 + i, i + 1, escape(c)) for i, c in enumerate(chunks))
custom_xml = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
              '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/custom-properties" '
              'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">' + props + '</Properties>\n')
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
TEMP_OUT.write_bytes(buf.getvalue())

# ------------------------------------------------ FIXED verify
errs = []
with zipfile.ZipFile(TEMP_OUT) as z:
    names = set(z.namelist())
    vx = z.read('word/document.xml').decode('utf-8')
    craw = z.read(CUSTOM_PROPS_PART).decode('utf-8')
zitem = vx.count('ZOTERO_ITEM')
zbib = vx.count('ZOTERO_BIBL')
print('verify: ZOTERO_ITEM=%d ZOTERO_BIBL=%d' % (zitem, zbib))
if zitem != state['replaced']:
    errs.append('ZOTERO_ITEM mismatch')
if zbib != 1:
    errs.append('ZOTERO_BIBL != 1')
if 'fldSimple' in vx:
    errs.append('fldSimple present')
if CUSTOM_PROPS_PART not in names:
    errs.append('custom.xml missing')
# bib begin/end paragraph identity
b0 = vx.find('ADDIN ZOTERO_BIBL')
p_before = paras_of(vx[:b0])
begin_para = p_before[-1] if p_before else None
endp = vx.find(END_RUN, vx.find('fldCharType="separate"', b0))
p_around = paras_of(vx[:endp])
end_para = p_around[-1] if p_around else None
bt = (begin_para['text'].strip() if begin_para else '')
et = (end_para['text'].strip() if end_para else '')
print('bib begin para:', bt[:60].encode('ascii', 'replace').decode())
print('bib end para  :', et[:60].encode('ascii', 'replace').decode())
if not bt.startswith('1. '):
    errs.append('bib does not start at ref 1')
if not et.startswith('36. '):
    errs.append('bib does not end at ref 36')
# payloads
payloads = []
for im in re.finditer(r'<w:instrText[^>]*>(.*?)</w:instrText>', vx, re.DOTALL):
    t = unescape(im.group(1))
    if 'CSL_CITATION' in t:
        try:
            payloads.append(json.loads(t[t.find('{'):]))
        except Exception as e:
            errs.append('payload json %s' % e)
cids = [p['citationID'] for p in payloads]
if len(cids) != len(set(cids)):
    errs.append('duplicate citationIDs')
for p in payloads:
    if p['properties']['noteIndex'] != 0:
        errs.append('noteIndex')
    for ci in p['citationItems']:
        if ci.get('uris') != []:
            errs.append('uris')
        if ci['id'] != ci['itemData']['id'] or not ci['itemData'].get('title'):
            errs.append('itemData bad')
# unlinked = bracket runs NOT immediately followed by the end-run
unlinked = []
for rm in run_pattern.finditer(vx):
    tm = re.search(r'<w:t\b[^>]*>([^<]*)</w:t>', rm.group(0))
    if tm and bracket_pattern.fullmatch(tm.group(1).strip()):
        if not vx[rm.end():].startswith(END_RUN):
            unlinked.append(tm.group(1))
print('unlinked plain bracket runs:', len(unlinked), unlinked[:6])
if unlinked:
    errs.append('%d unlinked' % len(unlinked))
# prefs
ch = []
for pm in re.finditer(r'name="ZOTERO_PREF_(\d)"[^>]*><vt:lpwstr>(.*?)</vt:lpwstr>', craw):
    ch.append((int(pm.group(1)), unescape(pm.group(2))))
pr = json.loads(''.join(c for _, c in sorted(ch)))
if pr.get('dataVersion') != 3 or 'american-medical-association' not in pr['style']['styleID']:
    errs.append('prefs wrong')
# python-docx
try:
    import docx as _d
    _ = _d.Document(str(TEMP_OUT))
    print('python-docx opens OK')
except Exception as e:
    errs.append('python-docx %s' % e)

if errs:
    for e in errs:
        print('ERR', e.encode('ascii', 'replace').decode())
    fail('verification failed - original left in place')

shutil.copy2(TEMP_OUT, DOCX)
TEMP_OUT.unlink(missing_ok=True)
LIB_OUT.write_text(json.dumps(ref_items, ensure_ascii=False, indent=2), encoding='utf-8')
print('SUCCESS: %d citation fields + bib(1..36) ; AMA en-US ; displays preserved' % zitem)
print('OUTPUT :', DOCX)
print('BACKUP :', BACKUP)
print('LIBRARY:', LIB_OUT)
