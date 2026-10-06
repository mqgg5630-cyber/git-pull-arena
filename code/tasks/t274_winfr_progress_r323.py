# t274_winfr_progress_r323.py - round 323. Progress check (read-only).
# helper v10 runs a single unredirected minimized winfr since 21:59 with a
# 60-minute monitor window. This task waits 20 minutes reading MON2 lines,
# then reports: latest file count, whether WINFR_DONE/WINFR_ZERO appeared,
# and (if files exist) a quick census of C:\recovery_winfr_E.
import os, sys, time, subprocess, json, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R323_WINFR_PROGRESS.md'; J=OUT/'r323-winfr-progress.json'
DBOX=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
VSSOUT=DBOX/'vss_out.txt'
lines=[]
def L(s):
    s=str(s).encode('ascii','replace').decode('ascii'); print(s,flush=True); lines.append(s)
def WT(p,t,enc='utf-8'):
    Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(t,encoding=enc)
def run(args,timeout=25):
    try:
        p=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout,text=True,errors='replace')
        return p.returncode,p.stdout
    except subprocess.TimeoutExpired: return 998,'timeout'
    except Exception as e: return 999,repr(e)
def count_rec():
    rdir=Path(r'C:\recovery_winfr_E')
    try:
        fs=[e for e in rdir.rglob('*') if e.is_file()]
        return len(fs),sum(e.stat().st_size for e in fs)//1048576
    except Exception: return -1,-1
L('# R323 single-instance progress check')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
try:
    t0=time.time(); last=''
    while time.time()-t0<1200:
        time.sleep(60)
        vtxt=''
        if VSSOUT.exists():
            try: vtxt=VSSOUT.read_text(encoding='utf-8',errors='replace')
            except Exception: pass
        mons=[ln for ln in vtxt.splitlines() if ln.startswith('MON2')]
        if mons and mons[-1]!=last:
            last=mons[-1]; L('  '+last[:170])
        if 'WINFR_DONE' in vtxt or 'WINFR_ZERO' in vtxt or 'WINFR_STILL_RUNNING' in vtxt:
            L('VERDICT LINE PRESENT'); break
    n,mb=count_rec()
    L('recovery now: %d files, %dMB'%(n,mb))
    if VSSOUT.exists():
        try:
            vls=VSSOUT.read_text(encoding='utf-8',errors='replace').splitlines()
            for ln in vls[-14:]: L('  tail| '+ln[:170])
        except Exception: pass
    c,o=run(['tasklist','/FI','IMAGENAME eq WinFR.exe','/FO','CSV'],timeout=20)
    L('winfr_procs=%d'%(o or '').lower().count('winfr'))
    if n and n>0:
        rdir=Path(r'C:\recovery_winfr_E')
        try:
            recs=[d for d in rdir.iterdir() if d.is_dir()]
            for d in recs[-3:]:
                fs=[e for e in d.rglob('*') if e.is_file()]
                L('  %s: %d files, %dMB'%(d.name,len(fs),sum(e.stat().st_size for e in fs)//1048576))
        except Exception: pass
except Exception:
    L('FATAL: '+traceback.format_exc())
L('R323_PROGRESS_COMPLETE=True')
WT(REPORT,'\n'.join(lines)+'\n')
WT(J,json.dumps({'progressComplete':True},indent=2)+'\n')
sys.exit(0)
