# t280_wdr_validate_r329.py - round 329. E:\WDR-20261006230705 holds 561
# recovered .docx files (1GB, appeared 23:07 - user apparently ran a recovery
# tool). Validate them: zip/OOXML structural check per file, zero-byte junk
# detection, duplicate groups, mtime histogram; write a FULL human-readable
# index to results/mcp_agv_lab/WDR_INDEX.md so the user can browse names.
# Read-only on E:, NO elevation, NO UAC.
import os, sys, time, zipfile, traceback, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R329_WDR_VALIDATE.md'; INDEX=OUT/'WDR_INDEX.md'
WDR=Path(r'E:\WDR-20261006230705')
lines=[]
def L(s):
    s=str(s).encode('ascii','replace').decode('ascii'); print(s,flush=True); lines.append(s)
def LX(s):
    s=str(s).encode('unicode_escape').decode('ascii'); print(s,flush=True); lines.append(s)
def WT(p,t):
    Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(t,encoding='utf-8')
def iso(m):
    try: return time.strftime('%Y-%m-%d %H:%M',time.localtime(m))
    except Exception: return '?'
def check_docx(p):
    # 2 = valid OOXML, 1 = valid zip but missing OOXML parts, 0 = not a zip, -1 = unreadable
    try:
        if not zipfile.is_zipfile(str(p)): return 0
        with zipfile.ZipFile(str(p)) as z:
            names=z.namelist()
            if '[Content_Types].xml' in names and any(n.startswith('word/') for n in names): return 2
            return 1
    except Exception: return -1
L('# R329 WDR recovered-docx validation')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
try:
    if not WDR.is_dir():
        L('WDR folder missing'); L('R329_WDR_VALIDATE_COMPLETE=True'); sys.exit(0)
    rows=[]
    for e in os.scandir(str(WDR)):
        try:
            if not e.is_file(follow_symlinks=False): continue
            st=e.stat(follow_symlinks=False)
            rows.append((e.name,st.st_size,st.st_mtime))
        except Exception: pass
    rows.sort(key=lambda x:-x[2])
    L('files now in WDR folder: '+str(len(rows))+' ('+str(sum(r[1] for r in rows)//1048576)+'MB)')
    stats={2:0,1:0,0:0,-1:0}; zero=0; idx=[]
    for name,size,mtime in rows:
        if size==0:
            zero+=1; idx.append((name,size,mtime,'ZERO')); continue
        v=check_docx(WDR/name)
        stats[v]+=1
        tag={2:'OK',1:'ZIP-ONLY',0:'NOTZIP',-1:'ERR'}[v]
        idx.append((name,size,mtime,tag))
    L('valid OOXML docx: '+str(stats[2]))
    L('zip-but-not-docx: '+str(stats[1]))
    L('not-a-zip (likely corrupt/carved junk): '+str(stats[0]))
    L('unreadable/error: '+str(stats[-1]))
    L('zero-byte files (Word lock junk etc): '+str(zero))
    good=[r for r in idx if r[3]=='OK']
    L('recoverable-good total: '+str(len(good))+' files, '+str(sum(r[1] for r in good)//1048576)+'MB')
    # duplicate groups (same size+mtime)
    seen={}; dups=0
    for r in good:
        k=(r[1],int(r[2]))
        if k in seen: dups+=1
        else: seen[k]=r
    L('likely duplicate copies among good: '+str(dups))
    # mtime histogram by year
    yrs={}
    for name,size,mtime,tag in idx:
        try:
            y=time.strftime('%Y',time.localtime(mtime)); yrs[y]=yrs.get(y,0)+1
        except Exception: pass
    L('mtime histogram: '+', '.join(k+':'+str(v) for k,v in sorted(yrs.items())))
    L('-- 40 newest files --')
    for name,size,mtime,tag in idx[:40]:
        LX('   '+iso(mtime)+' | '+str(size//1024)+'KB | '+tag+' | '+name)
    bad=[r for r in idx if r[3] in ('NOTZIP','ERR','ZIP-ONLY')]
    L('-- non-valid files ('+str(len(bad))+', up to 40) --')
    for name,size,mtime,tag in bad[:40]:
        LX('   '+iso(mtime)+' | '+str(size//1024)+'KB | '+tag+' | '+name)
    # full index for the user to browse
    out=['# WDR-20261006230705 full index ('+str(len(idx))+' files)','',
         '| date | size | status | filename |','|---|---|---|---|']
    for name,size,mtime,tag in idx:
        out.append('| '+iso(mtime)+' | '+str(size//1024)+'KB | '+tag+' | '+name.encode('unicode_escape').decode('ascii')+' |')
    WT(INDEX,'\n'.join(out)+'\n')
    L('full index written to results/mcp_agv_lab/WDR_INDEX.md')
    L('R329_WDR_VALIDATE_COMPLETE=True')
    WT(REPORT,'\n'.join(lines)+'\n')
except Exception:
    L('FATAL: '+traceback.format_exc())
    try: WT(REPORT,'\n'.join(lines)+'\n')
    except Exception: pass
sys.exit(0)
