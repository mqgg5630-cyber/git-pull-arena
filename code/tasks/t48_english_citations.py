#!/usr/bin/env python3
# t48_english_citations.py - analyze English.docx citation runs + refs list.
# Writes results/status/english_citations.json (UTF-8) + ASCII summary stdout.
import json
import re
import sys
import zipfile
from pathlib import Path

docx = r"E:\0writing\Light-skills\projects\English.docx"
out = Path("results/status/english_citations.json")

with zipfile.ZipFile(docx) as z:
    xml = z.read("word/document.xml").decode("utf-8")

paras = re.findall(r'(?s)<w:p\b.*?</w:p>', xml)
pdata = []
for i, p in enumerate(paras):
    sm = re.search(r'<w:pStyle w:val="([^"]+)"', p)
    text = ''.join(m.group(1) for m in re.finditer(r'<w:t(?: [^>]*)?>([^<]*)</w:t>', p))
    pdata.append({'i': i, 'style': sm.group(1) if sm else '', 'text': text})

# citation runs (whole-run bracket text, e.g. "[3,4]" or "[5]")
BR = re.compile(r'^\[[0-9,\s\-\u2013]+\]$')
cites = []
for i, p in enumerate(paras):
    for rm in re.finditer(r'(?s)<w:r\b[^>]*>(.*?)</w:r>', p):
        run = rm.group(1)
        tm = re.search(r'<w:t\b[^>]*>([^<]*)</w:t>', run)
        if not tm:
            continue
        t = tm.group(1)
        if BR.match(t.strip()):
            sup = '<w:vertAlign w:val="superscript"' in run
            cites.append({'para': i, 'text': t.strip(), 'sup': sup})

# in-text bracket mentions (anywhere in paragraph text, incl. split runs)
alltext = '\n'.join(d['text'] for d in pdata)
inline = re.findall(r'\[[0-9]{1,3}(?:\s*[,;\-\u2013]\s*[0-9]{1,3})*\]', alltext)

# refs section
refs_start = None
for d in pdata:
    if d['text'].strip().lower() in ('references', 'reference'):
        refs_start = d['i']
        break
refs = []
if refs_start is not None:
    for d in pdata[refs_start + 1:]:
        t = d['text'].strip()
        m = re.match(r'^\[(\d+)\]\s*(.+)', t)
        if m:
            refs.append({'n': int(m.group(1)), 'text': t[:400], 'body': m.group(2)[:400], 'style': d['style'], 'para': d['i']})
        elif len(refs) >= 3 and t and not t.startswith('['):
            break
        elif t and not t.startswith('[') and len(refs) == 0:
            # tolerate a lead-in paragraph
            continue

result = {
    'para_count': len(paras),
    'cite_runs': cites,
    'inline_bracket_mentions': inline,
    'refs_start_para': refs_start,
    'refs': refs,
}
out.write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding='utf-8')

print('paras:', len(paras))
print('whole-run cite runs:', len(cites), ' superscript:', sum(1 for c in cites if c['sup']), ' plain:', sum(1 for c in cites if not c['sup']))
print('inline bracket mentions in text:', len(inline))
print('refs section para:', refs_start, ' entries:', len(refs))
if refs:
    ns = [r['n'] for r in refs]
    print('ref numbers:', 'min', min(ns), 'max', max(ns), 'count', len(ns), 'unique', len(set(ns)))
for r in refs[:10]:
    print('REF', r['n'], r['body'][:88].encode('ascii', 'replace').decode())
nonsup = [c['text'] + '@p' + str(c['para']) for c in cites if not c['sup']]
print('non-superscript cite runs:', len(nonsup), nonsup[:8])
