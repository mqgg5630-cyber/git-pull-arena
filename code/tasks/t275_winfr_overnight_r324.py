# t275_winfr_overnight_r324.py - round 324. Final read of helper v10's
# 60-minute verdict (window ends ~22:59), then report the overnight plan.
# Read-only: MON2 tail, WINFR_DONE/WINFR_ZERO/WINFR_STILL_RUNNING verdict,
# recovery count, process count. If the scan is still running with zero
# files, the recommendation is to LET IT RUN OVERNIGHT and read the tally
# in the morning.
import os, sys, time, subprocess, json, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R324_WINFR_OVERNIGHT.md'; J=OUT/'r324-winfr-overnight.json'
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
L('# R324 helper v10 final verdict + overnight decision')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
try:
    verdict=None
    t0=time.time()
    while time.time()-t0<900:
        vtxt=''
        if VSSOUT.exists():
            try: vtxt=VSSOUT.read_text(encoding='utf-8',errors='replace')
            except Exception: pass
        for k in ('WINFR_DONE','WINFR_ZERO','WINFR_STILL_RUNNING'):
            if k in vtxt: verdict=k; break
        if verdict: break
        time.sleep(60)
    L('verdict=%s'%verdict)
    if VSSOUT.exists():
        try:
            vls=VSSOUT.read_text(encoding='utf-8',errors='replace').splitlines()
            for ln in vls[-12:]: L('  tail| '+ln[:170])
        except Exception: pass
    n,mb=count_rec()
    L('recovery now: %d files, %dMB'%(n,mb))
    c,o=run(['tasklist','/FI','IMAGENAME eq WinFR.exe','/FO','CSV'],timeout=20)
    procs=(o or '').lower().count('winfr')
    L('winfr_procs=%d'%procs)
    if verdict=='WINFR_STILL_RUNNING' or (procs>0 and not verdict):
        L('RECOMMENDATION: let the scan run overnight; read the tally in the morning.')
        L('DO NOT shut down; avoid writing large files to E:')
    elif verdict=='WINFR_DONE':
        L('RECOMMENDATION: tally complete - census follows in the morning round or now.')
        try:
            rdir=Path(r'C:\recovery_winfr_E')
            for d in sorted((x for x in rdir.iterdir() if x.is_dir())):
                fs=[e for e in d.rglob('*') if e.is_file()]
                L('  %s: %d files, %dMB'%(d.name,len(fs),sum(e.stat().st_size for e in fs)//1048576))
        except Exception: pass
    elif verdict=='WINFR_ZERO':
        L('RECOMMENDATION: vintage winfr found nothing - morning round decides plan B (extensive/signature mode or accept loss).')
    else:
        L('no verdict yet - treat as still running.')
except Exception:
    L('FATAL: '+traceback.format_exc())
L('R324_OVERNIGHT_DECISION_COMPLETE=True')
WT(REPORT,'\n'.join(lines)+'\n')
WT(J,json.dumps({'verdict':str(verdict)},indent=2)+'\n')
sys.exit(0)
