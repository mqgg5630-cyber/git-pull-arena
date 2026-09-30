#!/usr/bin/env python3
# t51_verify_fix.py - round 62: verify the Zotero-linked English.docx, and
# if the ZOTERO_BIBL extent or citation coverage is wrong, restore from the
# backup and rebuild with FIXED selection logic:
#   - bibliography = CONSECUTIVE numbered Reference paragraphs right after
#     the heading (stop at first non-match) -> exactly 36
#   - citations: whole-run + substring-in-run + SPLIT-ACROSS-RUNS handling
# Then verify again before overwriting. Report everything.
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
TEMP_OUT = DOCX.with_suffix('.docx.zotlive2.tmp')

STYLE_ID = "http://www.zotero.org/styles/american-medical-association"
CSL_SCHEMA = "https://github.com/citation-style-language/schema/raw/master/csl-citation.json"
MAXP = 255
CUSTOM_PROPS_PART = "docProps/custom.xml"
CUSTOM_PROPS_CONTENT_TYPE = "application/vnd.openxmlformats-officedocument.custom-properties+xml"
CUSTOM_PROPS_REL_TYPE = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/custom-properties"
_FMTID = "{D5CDD505-2E9C-101B-9397-08002B2CF9AE}"

run_pattern = re.compile(r'(?s)<w:r\b[^>]*>(?:(?!</w:r>).)*?</w:r>')
bracket_pattern = re.compile(r'\[[0-9,\s\u2013\-]+\]')
DISPLAY_END = '</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r>'


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


def read_docx(path):
    with zipfile.ZipFile(path) as z:
        return {i.filename: z.read(i.filename) for i in z.infolist()}, list(z.infolist())


def verify(path):
    """Return (ok, report_lines)."""
    errs = []
    with zipfile.ZipFile(path) as z:
        names = set(z.namelist())
        vx = z.read('word/document.xml').decode('utf-8')
    zitem = vx.count('ZOTERO_ITEM')
    zbib = vx.count('ZOTERO_BIBL')
    lines = ['ZOTERO_ITEM=%d ZOTERO_BIBL=%d fldSimple=%s' % (zitem, zbib, 'present!' if 'fldSimple' in vx else 'none')]
    if zbib != 1:
        errs.append('ZOTERO_BIBL != 1')
    # bib extent
    b0 = vx.find('ADDIN ZOTERO_BIBL')
    if b0 < 0:
        errs.append('no ZOTERO_BIBL')
    else:
        sep = vx.find('fldCharType="separate"', b0)
        endp = vx.find('<w:r><w:fldChar w:fldCharType="end"/></w:r>', sep)
        inner = vx[sep:endp]
        iparas = paras_of(inner)
        nonref = [d['text'][:70] for d in iparas if not re.match(r'^\d{1,2}\.\s', d['text'].strip()) and d['text'].strip()]
        lines.append('bib inner paragraphs: %d ; non-ref inside: %d' % (len(iparas), len(nonref)))
        for t in nonref[:5]:
            lines.append('  NONREF: ' + t.encode('ascii', 'replace').decode())
        if len(iparas) != 36 or nonref:
            errs.append('bib extent wrong (%d paras, %d non-ref)' % (len(iparas), len(nonref)))
        firstp = paras_of(vx[max(0, b0 - 3000):b0])
        lines.append('bib starts near: ' + (firstp[-1]['text'][:60] if firstp else '?').encode('ascii', 'replace').decode())
    # citations
    payloads = []
    for im in re.finditer(r'<w:instrText[^>]*>(.*?)</w:instrText>', vx, re.DOTALL):
        t = unescape(im.group(1))
        if 'CSL_CITATION' in t:
            try:
                payloads.append(json.loads(t[t.find('{'):]))
            except Exception as e:
                errs.append('payload: %s' % e)
    lines.append('citation payloads: %d' % len(payloads))
    cids = [p['citationID'] for p in payloads]
    if len(cids) != len(set(cids)):
        errs.append('duplicate citationIDs')
    # unlinked bracket runs (not display runs of fields)
    unlinked = []
    for rm in run_pattern.finditer(vx):
        tm = re.search(r'<w:t\b[^>]*>([^<]*)</w:t>', rm.group(0))
        if tm and bracket_pattern.fullmatch(tm.group(1).strip()):
            after = vx[rm.end():rm.end() + len(DISPLAY_END) + 40]
            if DISPLAY_END not in after[:len(DISPLAY_END) + 5]:
                unlinked.append((tm.group(1), rm.start()))
    lines.append('unlinked plain bracket runs: %d %s' % (len(unlinked), [u[0] for u in unlinked[:6]]))
    if unlinked:
        errs.append('%d unlinked citations' % len(unlinked))
    # display preserved
    for p in payloads:
        d = p['properties']['formattedCitation']
        if escape(d) not in vx:
            errs.append('display lost %s' % d)
    # prefs
    try:
        with zipfile.ZipFile(path) as z:
            craw = z.read(CUSTOM_PROPS_PART).decode('utf-8')
        ch = []
        for pm in re.finditer(r'name="ZOTERO_PREF_(\d)"[^>]*><vt:lpwstr>(.*?)</vt:lpwstr>', craw):
            ch.append((int(pm.group(1)), unescape(pm.group(2))))
        pr = json.loads(''.join(c for _, c in sorted(ch)))
        if pr.get('dataVersion') != 3:
            errs.append('prefs dataVersion')
        lines.append('prefs OK style=%s' % pr['style']['styleID'].rsplit('/', 1)[-1])
    except Exception as e:
        errs.append('prefs: %s' % e)
    return (len(errs) == 0), lines, errs


# ================================================ verification first
ok, lines, errs = verify(DOCX)
print('--- verify current output ---')
for l in lines:
    print('  ', l.encode('ascii', 'replace').decode())
for e in errs:
    print('ERR', e.encode('ascii', 'replace').decode())

if ok:
    print('ALL OK - no repair needed')
    sys.exit(0)

# ================================================ repair from backup
print('--- repairing from backup ---')
if not BACKUP.exists():
    fail('backup missing')
shutil.copy2(BACKUP, DOCX)
parts, infos = read_docx(DOCX)
doc_xml = parts['word/document.xml'].decode('utf-8')
paras = paras_of(doc_xml)

refs_start = None
for d in paras:
    if d['text'].strip().lower() == 'references':
        refs_start = d['m'].start()
        break
if refs_start is None:
    fail('References heading not found')

# FIXED: consecutive numbered Reference paragraphs right after the heading
ref_entries = []
ref_para_matches = []
started = False
for d in paras:
    if d['m'].start() <= refs_start:
        continue
    t = d['text'].strip()
    m = re.match(r'^(\d{1,2})\.\s+(.+)$', t)
    if m and d['style'] == 'Reference':
        started = True
        ref_entries.append((int(m.group(1)), m.group(2)))
        ref_para_matches.append(d['m'])
    elif started and t:
        break
print('consecutive ref entries:', len(ref_entries))
if len(ref_entries) != 36:
    fail('expected 36 consecutive refs, got %d' % len(ref_entries))


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


state = {'n': 0, 'replaced': 0}


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
            '<w:r><w:fldChar w:fldCharType="end"/></w:r>')


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
    if after:
        out.append('<w:r>' + rpr + '<w:t xml:space="preserve">' + escape(after) + '</w:t></w:r>')
    return ''.join(out)


# pass 1: whole-run + substring-in-run
def repl_run(m):
    run = m.group(0)
    tm = re.search(r'<w:t\b[^>]*>([^<]*)</w:t>', run)
    if not tm:
        return run
    t = tm.group(1)
    bm = bracket_pattern.search(t)
    if not bm:
        return run
    plain = unescape(t)
    bm2 = bracket_pattern.search(plain)
    if not bm2:
        return run
    rep = build_replacement(get_rpr(run), plain[:bm2.start()], bm2.group(0), plain[bm2.end():])
    if rep is None:
        return run
    state['replaced'] += 1
    return rep


doc_xml2 = run_pattern.sub(repl_run, doc_xml)
print('pass1 (whole/substring runs) replaced:', state['replaced'])

# pass 2: split across two adjacent runs (e.g. "[3" + "1]")
p2 = {'n': 0}
paras_x = list(re.finditer(r'(?s)<w:p\b.*?</w:p>', doc_xml2))


def fix_split_in_para(pm):
    xml = pm.group(0)
    runs = list(run_pattern.finditer(xml))
    for i in range(len(runs) - 1):
        t1m = re.search(r'<w:t\b[^>]*>([^<]*)</w:t>', runs[i].group(0))
        t2m = re.search(r'<w:t\b[^>]*>([^<]*)</w:t>', runs[i + 1].group(0))
        if not t1m or not t2m:
            continue
        joined = unescape(t1m.group(1)) + unescape(t2m.group(1))
        bm = bracket_pattern.search(joined)
        if not bm:
            continue
        rep = build_replacement(get_rpr(runs[i].group(0)), joined[:bm.start()], bm.group(0), joined[bm.end():])
        if rep is None:
            continue
        p2['n'] += 1
        return xml[:runs[i].start()] + rep + xml[runs[i + 1].end():]
    return xml


doc_xml2b = re.sub(r'(?s)<w:p\b.*?</w:p>', lambda m: fix_split_in_para(m), doc_xml2, count=0)
print('pass2 (split runs) replaced:', p2['n'])

total_fields = state['replaced'] + p2['n']
if total_fields < 55:
    fail('too few total citations (%d)' % total_fields)

# bibliography: use the CONSECUTIVE set (re-locate in the new xml)
paras2 = paras_of(doc_xml2b)
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
bib_end_code = '<w:r><w:fldChar w:fldCharType="end"/></w:r>'


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
new_last = insert_into_para(last.group(0), bib_end_code, True)
doc_xml3 = (doc_xml2b[:first.start()] + new_first
            + doc_xml2b[first.end():last.start()] + new_last
            + doc_xml2b[last.end():])

prefs = json.dumps({'style': {'styleID': STYLE_ID, 'locale': 'en-US', 'hasBibliography': True, 'bibliographyStyleHasBeenSet': True},
                    'prefs': {'fieldType': 'Field', 'storeReferences': True, 'automaticJournalAbbreviations': True, 'noteType': 0},
                    'sessionID': 'EnglishZotero02', 'zoteroVersion': '7.0.0', 'dataVersion': 3},
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

ok2, lines2, errs2 = verify(TEMP_OUT)
print('--- verify repaired output ---')
for l in lines2:
    print('  ', l.encode('ascii', 'replace').decode())
if not ok2:
    for e in errs2:
        print('ERR', e.encode('ascii', 'replace').decode())
    fail('repaired output still failing - original (restored backup) left in place')

shutil.copy2(TEMP_OUT, DOCX)
TEMP_OUT.unlink(missing_ok=True)
LIB_OUT.write_text(json.dumps(ref_items, ensure_ascii=False, indent=2), encoding='utf-8')
print('REPAIRED AND VERIFIED ->', DOCX)
print('total citation fields:', total_fields, '; bib = exactly 36 refs')
