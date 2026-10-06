# t272_watch_winfr_r321.py - round 321. OBSERVATION (read-only, no UAC).
# Two WinFR processes are actively working (memory growing), one is idle.
# Helper monitors have expired but the scans continue. Before any cleanup:
# watch for 15 minutes - if recovered files start appearing, the scans are
# productive and we simply keep waiting; if files stay at 0 and memory
# stops growing, the deadlock is confirmed and r322 does the elevated
# cleanup + single-instance retry.
import os, sys, time, subprocess, json, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R321_WATCH_WINFR.md'; J=OUT/'r321-watch-winfr.json'
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
def snap():
    c,o=run(['tasklist','/FI','IMAGENAME eq WinFR.exe','/FO','CSV'],timeout=20)
    d={}
    for ln in (o or '').splitlines():
        parts=[p.strip('"') for p in ln.split('","')]
        if len(parts)>=5 and parts[0].lower().startswith('winfr'):
            try: d[int(parts[1])]=int(parts[4].replace(',','').replace(' K','').replace('K','').strip() or 0)
            except Exception:
                try: d[int(parts[1])]=parts[4]
                except Exception: pass
    return d
def count_rec():
    rdir=Path(r'C:\recovery_winfr_E')
    try:
        fs=[e for e in rdir.rglob('*') if e.is_file()]
        return len(fs),sum(e.stat().st_size for e in fs)//1048576
    except Exception: return -1,-1
L('# R321 watch the working WinFR scans')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
try:
    s0=snap(); n0,mb0=count_rec()
    L('start: procs=%s files=%sMB=%s'%(s0,n0,mb0))
    productive=False
    t0=time.time()
    while time.time()-t0<900:
        time.sleep(60)
        s=snap(); n,mb=count_rec()
        L('  +%dmin procs=%s files=%d MB=%d'%((time.time()-t0)//60,s,n,mb))
        if n and n>0:
            productive=True; L('PRODUCTIVE - files are appearing!')
            break
    if productive:
        L('continue watching until they finish (another 10 min max here)')
        t1=time.time()
        while time.time()-t1<600:
            time.sleep(60)
            s=snap(); n,mb=count_rec()
            L('  +%dmin files=%d MB=%d procs=%d'%((time.time()-t1)//60,n,mb,len(s)))
            if not s:
                L('all WinFR exited'); break
    s9=snap(); n9,mb9=count_rec()
    L('end: procs=%s files=%d MB=%d'%(s9,n9,mb9))
    verdict='productive' if (n9 or 0)>0 else ('still_zero_but_alive' if s9 else 'all_exited_zero')
    L('VERDICT=%s'%verdict)
    L('NEXT: productive/still_zero -> keep waiting (r322 observe) ; all_exited_zero -> r322 elevated single-instance visible-window retry.')
except Exception:
    L('FATAL: '+traceback.format_exc())
L('R321_WATCH_COMPLETE=True')
WT(REPORT,'\n'.join(lines)+'\n')
WT(J,json.dumps({'watchComplete':True},indent=2)+'\n')
sys.exit(0)
