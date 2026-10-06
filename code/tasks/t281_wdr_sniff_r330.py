# t281_wdr_sniff_r330.py - round 330. r329 found all 547 non-zero files in
# E:\WDR-20261006230705 are NOT valid docx. Magic-sniff every file to see
# what the content actually is (old OLE2 .doc? corrupt zip? zero-filled?
# junk?), check whether the WDR folder is still growing, and look for a
# running recovery-tool process. Read-only on E:, NO elevation, NO UAC.
import os, sys, time, subprocess, traceback, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R330_WDR_SNIFF.md'
WDR=Path(r'E:\WDR-20261006230705')
lines=[]
def L(s):
    s=str(s).encode('ascii','replace').decode('ascii'); print(s,flush=True); lines.append(s)
def LX(s):
    s=str(s).encode('unicode_escape').decode('ascii'); print(s,flush=True); lines.append(s)
def WT(p,t):
    Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(t,encoding='utf-8')
def classify(b):
    if b.startswith(b'PK'): return 'PK-zip'
    if b.startswith(b'\xd0\xcf\x11\xe0'): return 'OLE2-doc'
    if b.startswith(b'%PDF'): return 'PDF'
    if b.startswith(b'{\\rtf'): return 'RTF'
    if b.startswith(b'\xff\xd8\xff'): return 'JPEG'
    if b.startswith(b'\x89PNG'): return 'PNG'
    if b.startswith(b'\x00\x00\x00'): return 'zeros'
    if b.startswith(b'\xff\xff\xff\xff'): return 'ff-fill'
    return 'unknown'
L('# R330 WDR content magic-sniff')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
try:
    files=sorted((e for e in os.scandir(str(WDR)) if e.is_file(follow_symlinks=False)),key=lambda e:e.name)
    L('files now: '+str(len(files))+' (was 561 at 23:32 - growth means the tool is still writing)')
    stats={}; samples={}; mb={}
    allzero=0
    for e in files:
        try:
            sz=e.stat(follow_symlinks=False).st_size
            with open(e.path,'rb') as f:
                head=f.read(32)
                if sz>0:
                    f.seek(max(0,sz//2)); mid=f.read(4096)
                    f.seek(max(0,sz-4096)); tail=f.read(4096)
                else:
                    mid=tail=b''
            c=classify(head)
            if sz>0 and (not any(mid)) and (not any(tail)) and (not any(head)):
                c='ALL-ZERO'; allzero+=1
            stats[c]=stats.get(c,0)+1
            mb[c]=mb.get(c,0)+sz
            samples.setdefault(c,[]).append((e.name,sz))
        except Exception as ex:
            stats['ERR']=stats.get('ERR',0)+1
    L('-- content classes --')
    for c in sorted(stats,key=lambda x:-stats[x]):
        L('  '+c+': '+str(stats[c])+' files, '+str(mb.get(c,0)//1048576)+'MB')
        for name,sz in samples.get(c,[])[:12]:
            LX('     '+str(sz//1024)+'KB | '+name)
    L('entirely-zero-sampled files: '+str(allzero))
    # sample hex of a few unknown files
    L('-- first-bytes hex of 5 largest non-PK/OLE2 files --')
    cand=[e for e in files if e.stat(follow_symlinks=False).st_size>0]
    cand.sort(key=lambda e:-e.stat(follow_symlinks=False).st_size)
    shown=0
    for e in cand:
        if shown>=5: break
        try:
            with open(e.path,'rb') as f: h=f.read(24)
            LX('   '+e.name[:50]+' | '+h.hex())
            shown+=1
        except Exception: pass
    # is a recovery tool running? (look for common names / window titles)
    c,o=subprocess.run(['powershell','-NoProfile','-Command','Get-Process | Where-Object {$_.MainWindowTitle} | Select-Object ProcessName,MainWindowTitle | Format-Table -HideTableHeaders | Out-String -Width 200'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=40,text=True)
    L('-- windowed processes --')
    for ln in (o or '').splitlines():
        ln=ln.strip()
        if ln: L('  win| '+ln.encode('ascii','replace').decode('ascii')[:120])
    L('R330_WDR_SNIFF_COMPLETE=True')
    WT(REPORT,'\n'.join(lines)+'\n')
except Exception:
    L('FATAL: '+traceback.format_exc())
    try: WT(REPORT,'\n'.join(lines)+'\n')
    except Exception: pass
sys.exit(0)
