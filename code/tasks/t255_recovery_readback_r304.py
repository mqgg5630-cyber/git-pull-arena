# t255_recovery_readback_r304.py - round 304. DATA RECOVERY phase 3.
# r303 crashed (exit 1, 12s) right after starting the UAC attempt - no
# traceback in the receipt. BUT the UAC may have been shown AND accepted in
# those 12 seconds: the elevated helper may have already run and written
# vss_out.txt. This round:
#  A. FIRST just read the leftover vss_out.txt / uac_err.txt from r303.
#     If they contain RECOVERY_START or WINFR_START we are done - no UAC.
#  B. Otherwise retry the UAC flow, fully wrapped in try/except with the
#     traceback written to the receipt, no thread wrapping (plain
#     subprocess.run with its own timeout), flushing the report to disk
#     after every step.
import os, sys, time, subprocess, json, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R304_RECOVERY_READBACK.md'; J=OUT/'r304-recovery-readback.json'
DBOX=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
HELPER=DBOX/'vss_helper.ps1'; LAUNCHER=DBOX/'vss_launch.ps1'
VSSOUT=DBOX/'vss_out.txt'; UACERR=DBOX/'uac_err.txt'
lines=[]
def L(s):
    s=str(s).encode('ascii','replace').decode('ascii'); print(s,flush=True); lines.append(s)
def WT(p,t,enc='utf-8'):
    Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(t,encoding=enc)
def flush_report():
    try: WT(REPORT,'\n'.join(lines)+'\n')
    except Exception: pass
def run(args,timeout=25):
    try:
        p=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout,text=True,errors='replace')
        return p.returncode,p.stdout
    except subprocess.TimeoutExpired as e:
        return 998,'timeout'
    except Exception as e: return 999,repr(e)
def run_bg(args):
    try: subprocess.Popen(args,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,creationflags=0x08000000); return True
    except Exception: return False
def notify(msg):
    cmd=("Add-Type -AssemblyName System.Windows.Forms; "
         "[System.Windows.Forms.MessageBox]::Show(" + msg + ","
         "'DeskBox data recovery','OK','Information') | Out-Null")
    return run_bg(['powershell','-NoProfile','-Command',cmd])

def read_vss():
    if not VSSOUT.exists(): return None
    try: return VSSOUT.read_text(encoding='utf-8',errors='replace')
    except Exception:
        try: return VSSOUT.read_text(errors='replace')
        except Exception: return '<unreadable>'

def classify(vtxt):
    if vtxt is None: return 'no_file'
    if 'RECOVERY_START' in vtxt: return 'recovering_vss'
    if 'WINFR_START' in vtxt: return 'winfr_running'
    if 'WINFR_UNAVAILABLE' in vtxt and 'NO_NINE_CAT_IN_SHADOWS' in vtxt: return 'vss_empty_winfr_unavailable'
    if 'shadow_count=0' in vtxt: return 'no_shadows'
    if 'cim_error' in vtxt: return 'vss_enum_failed'
    if 'NO_NINE_CAT_IN_SHADOWS' in vtxt: return 'vss_seen_no_hit'
    return 'helper_ran_unclear'

L('# R304 DATA RECOVERY phase 3 - readback + hardened retry')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
data_found='unknown'
try:
    locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked)); flush_report()

    # ---- A. read back whatever r303's helper left behind
    L('== A: leftover helper output from r303 ==')
    vtxt=read_vss()
    uerr=''
    if UACERR.exists():
        try: uerr=UACERR.read_text(encoding='utf-8',errors='replace').strip()
        except Exception: pass
    L('vss_out.txt exists=%s uac_err=%s'%(VSSOUT.exists(),(uerr.splitlines()[:1] or [''])[0][:120]))
    if vtxt:
        vls=vtxt.splitlines()
        L('vss_out.txt has %d lines:'%len(vls))
        for ln in vls[:70]:
            if any(k in ln for k in ('shadow','HIT','nine_cat','RECOVERY','NO_NINE','free','fs ','WINFR','winget','cim_error','link_fail','started','done')):
                L('  vss| '+ln[:170])
    data_found=classify(vtxt)
    L('classify_leftover=%s'%data_found)
    flush_report()

    # ---- B. retry only if the leftovers are inconclusive
    if data_found in ('no_file','helper_ran_unclear'):
        for attempt in (1,2):
            L('== B: UAC retry %d =='%attempt); flush_report()
            L('showing explanation MessageBox'); flush_report()
            notify("DATA RECOVERY: a Windows permission dialog (UAC) will appear next. PLEASE CLICK YES to allow the shadow-copy search and file recovery. Nothing will be deleted; recovery output goes to C:\\ only.")
            time.sleep(9); flush_report()
            for f in (VSSOUT,UACERR):
                try: f.unlink()
                except Exception: pass
            L('launching elevated helper (subprocess timeout 380s)')
            rc,out=run(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(LAUNCHER)],timeout=380)
            L('launcher_rc=%s out=%s'%(rc,(out or '').strip().splitlines()[:1]))
            flush_report()
            vtxt=read_vss()
            data_found=classify(vtxt)
            L('classify_after=%s'%data_found); flush_report()
            if data_found not in ('no_file','helper_ran_unclear'):
                break
            uerr=''
            if UACERR.exists():
                try: uerr=UACERR.read_text(encoding='utf-8',errors='replace').strip()
                except Exception: pass
            L('uac_err=%s'%uerr[:200])
            if 'canceled by the user' in uerr:
                L('user clicked No - will explain and retry once more'); continue
            if data_found!='no_file':
                break
    L('data_found=%s'%data_found)
    for r in (Path(r'C:\recovery_vss\DeskBoxLibrary'),Path(r'C:\recovery_winfr_E')):
        if r.exists():
            try: L('recovery_dest %s -> %d entries'%(str(r),len(list(r.iterdir()))))
            except Exception: pass
    flush_report()
except Exception:
    L('FATAL: '+traceback.format_exc()); flush_report()
    data_found='crashed'

box_pids=[]
for f in DBOX.glob('deskbox-*.pid'):
    try:
        pid=int(f.read_text().strip())
        c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
        if str(pid) in (o or ''): box_pids.append(pid)
    except Exception: pass
L('boxes_alive_now=%d %s'%(len(box_pids),box_pids))
complete = data_found in ('recovering_vss','winfr_running','no_shadows','vss_empty_winfr_unavailable','vss_seen_no_hit','vss_enum_failed')
L('R304_RECOVERY_PHASE3_COMPLETE=%s'%complete)
flush_report()
WT(J,json.dumps({'dataFound':data_found,'phase3Complete':complete,'boxesAlive':len(box_pids)},indent=2)+'\n')
sys.exit(0 if complete else 6)
