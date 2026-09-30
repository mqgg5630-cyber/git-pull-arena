#!/usr/bin/env python3
# t56_import_zotero.py - import the 36 references into the RUNNING Zotero
# via the Connector saveItems API (same mechanism as push_to_zotero.py),
# converting CSL -> Zotero internal item format. Idempotent via
# deterministic sessionIDs. Prints per-batch status.
import hashlib
import json
import urllib.request
from pathlib import Path

API = 'http://127.0.0.1:23119/connector'
SRC = Path(r"E:\0writing\Light-skills\projects\English_Zotero_library.json")


def req(endpoint, data, timeout=45):
    body = json.dumps(data, ensure_ascii=False).encode('utf-8')
    r = urllib.request.Request(API + '/' + endpoint, data=body, headers={
        'Content-Type': 'application/json',
        'X-Zotero-Connector-API-Version': '3'})
    try:
        resp = urllib.request.urlopen(r, timeout=timeout)
        txt = resp.read().decode('utf-8')
        return resp.status, (json.loads(txt) if txt else None)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8', errors='replace')[:300]
    except Exception as e:
        return 0, str(e)[:200]


s, _ = req('ping', {})
print('ping:', s)
if s != 200:
    print('Zotero not reachable')
    raise SystemExit(1)
s, col = req('getSelectedCollection', {})
print('selected collection:', str(col)[:200])

items = json.loads(SRC.read_text(encoding='utf-8'))
zitems = []
for it in items:
    creators = []
    for a in it.get('author', []):
        if 'literal' in a:
            creators.append({'name': a['literal'], 'creatorType': 'author'})
        else:
            creators.append({'creatorType': 'author', 'lastName': a.get('family', ''), 'firstName': a.get('given', '')})
    year = str((it.get('issued', {}).get('date-parts') or [[None]])[0][0] or '')
    zi = {
        'itemType': 'journalArticle',
        'title': it.get('title', ''),
        'creators': creators,
        'publicationTitle': it.get('container-title', ''),
        'date': year,
        'volume': it.get('volume', ''),
        'issue': it.get('issue', ''),
        'pages': (it.get('page', '') or '').replace('-', '\u2013'),
        'DOI': it.get('DOI', ''),
        'language': 'en',
        'libraryCatalog': 'Crossref',
        'attachments': [],
        'tags': [],
    }
    if it.get('DOI'):
        zi['url'] = 'https://doi.org/' + it['DOI']
    zitems.append(zi)

print('converted items:', len(zitems))
ok = 0
for i in range(0, len(zitems), 12):
    chunk = zitems[i:i + 12]
    for n, zi in enumerate(chunk):
        zi['id'] = 'engref_%03d' % (i + n)
    key = '|'.join(sorted(z['title'] for z in chunk))
    sid = hashlib.md5(key.encode('utf-8')).hexdigest()[:12]
    s, resp = req('saveItems', {'sessionID': sid, 'uri': '', 'items': chunk}, timeout=60)
    tag = {201: 'SAVED', 409: 'ALREADY SAVED'}.get(s, 'ERROR')
    print('batch %d-%d: %s %s %s' % (i + 1, i + len(chunk), s, tag, str(resp)[:120]))
    if s in (201, 409):
        ok += len(chunk)
print('imported (or already present):', ok, '/', len(zitems))
