# t271_diagnose_winfr_r320.py - round 320. DIAGNOSIS (read-only, no UAC).
# Three WinFR processes have produced 0 files for 27+ minutes. Hypothesis:
# the console app is blocked under hidden-window + redirected pipes.
# This round: snapshot WinFR CPU times, wait 90s, snapshot again (frozen =
# no CPU growth), read the newest MONITOR lines, wait for helper v8 to hit
# its 40-min deadline (up to 15 min), report the final state. No kills, no
# elevation - the cleanup + single visible-window retry goes to r321.
import os, sys, time, subprocess, json, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R320_DIAGNOSE_WINFR.md'; J=OUT/'r320-diagnose-winfr.json'
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
def winfr_snapshot():
    rows={}
    for name in ('WinFR.exe','winfr.exe','Winfr.exe'):
        c,o=run(['tasklist','/FI','IMAGENAME eq '+name,'/FO','CSV','/V'],timeout=20)
        for ln in (o or '').splitlines():
            parts=[p.strip('"') for p in ln.split('","')]
            if len(parts)>=5 and parts[0].lower().startswith('winfr'):
                try: rows[int(parts[1])]=(name,parts[4] if len(parts)>4 else '?')
                except Exception: pass
        if rows: break
    return rows
L('# R320 diagnose the frozen WinFR processes')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
try:
    snap1=winfr_snapshot()
    L('snapshot1: %s'%snap1)
    c,o=run(['tasklist','/FI','IMAGENAME eq WinFR.exe','/FO','CSV'],timeout=20)
    if not (o or '').lower().count('winfr'):
        c,o=run(['tasklist','/FO','CSV'],timeout=30)
        alt=[ln for ln in (o or '').splitlines() if 'winfr' in ln.lower()]
        L('alt listing: %s'%alt[:6])
        snap1={ln.split('","')[1].strip('"'):(ln.split('","')[0].strip('"'),'?') for ln in alt}
        L('snapshot1b: %s'%snap1)
    if VSSOUT.exists():
        try:
            vls=VSSOUT.read_text(encoding='utf-8',errors='replace').splitlines()
            mons=[ln for ln in vls if ln.startswith('MONITOR')]
            L('latest MONITOR lines:')
            for ln in mons[-4:]: L('  '+ln[:170])
            key=[ln for ln in vls if ln.startswith('VARIANT') or 'WINFR_' in ln or 'helper v8 done' in ln or 'deadline' in ln]
            for ln in key[-8:]: L('  key| '+ln[:170])
        except Exception as ex: L('vss read error %r'%ex)
    L('waiting 90s for a CPU-time comparison...')
    time.sleep(90)
    snap2=winfr_snapshot()
    L('snapshot2: %s'%snap2)
    frozen=(snap1==snap2 and bool(snap1))
    L('cpu_frozen=%s (equal snapshots => no progress)'%frozen)
    L('waiting up to 15 min for helper v8 deadline / done marker...')
    t0=time.time(); done=False
    while time.time()-t0<900:
        time.sleep(60)
        vtxt=''
        if VSSOUT.exists():
            try: vtxt=VSSOUT.read_text(encoding='utf-8',errors='replace')
            except Exception: pass
        mons=[ln for ln in vtxt.splitlines() if ln.startswith('MONITOR')]
        if mons:
            last=mons[-1]
            if not lines or lines[-1]!=('  '+last[:170]): L('  '+last[:170])
        if 'helper v8 done' in vtxt:
            L('helper v8 done marker present'); done=True; break
    snap3=winfr_snapshot()
    L('snapshot3 (after wait): %s'%snap3)
    rdir=Path(r'C:\recovery_winfr_E')
    if rdir.exists():
        try:
            fs=[e for e in rdir.rglob('*') if e.is_file()]
            L('recovery_winfr_E: %d files, %dMB'%(len(fs),sum(e.stat().st_size for e in fs)//1048576))
        except Exception: pass
    L('DIAGNOSIS: frozen=%s helper_done=%s winfr_left=%d'%(frozen,done,len(snap3)))
    L('PLAN: r321 = elevated cleanup (kill all WinFR) + single visible-window unredirected retry.')
except Exception:
    L('FATAL: '+traceback.format_exc())
L('R320_DIAG_COMPLETE=True')
WT(REPORT,'\n'.join(lines)+'\n')
WT(J,json.dumps({'diagComplete':True},indent=2)+'\n')
sys.exit(0)
