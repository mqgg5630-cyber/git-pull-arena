# t257_recovery_wait_r306.py - round 306. DATA RECOVERY phase 5.
# The desktop bat RECOVERY-recover-data.bat is in place (549B). The user has
# been told (chat + popup) to double-click it and accept the UAC. This round:
#  1. poll vss_out.txt for up to 600s (the elevated helper writes it);
#  2. if nothing after 300s, show ONE more instruction popup, keep polling;
#  3. when output appears: classify, and also report recovery progress
#     (robocopy log tail, recovery dir entry counts, winfr log tail);
#  4. honest verdict. Read-only except nothing - this round deletes nothing.
import os, sys, time, subprocess, json, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R306_RECOVERY_WAIT.md'; J=OUT/'r306-recovery-wait.json'
DBOX=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
VSSOUT=DBOX/'vss_out.txt'; RCLOG=DBOX/'recovery_robocopy.log'; WFLOG=DBOX/'winfr_E.log'
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
def classify(vtxt):
    if vtxt is None: return 'no_file'
    if 'RECOVERY_START' in vtxt: return 'recovering_vss'
    if 'WINFR_START' in vtxt: return 'winfr_running'
    if 'WINFR_UNAVAILABLE' in vtxt and 'NO_NINE_CAT_IN_SHADOWS' in vtxt: return 'vss_empty_winfr_unavailable'
    if 'shadow_count=0' in vtxt: return 'no_shadows'
    if 'cim_error' in vtxt: return 'vss_enum_failed'
    if 'NO_NINE_CAT_IN_SHADOWS' in vtxt: return 'vss_seen_no_hit'
    return 'helper_ran_unclear'
def tail(p,n=8):
    if not Path(p).exists(): return '(absent)'
    try: return ' | '.join(Path(p).read_text(encoding='utf-8',errors='replace').splitlines()[-n:])
    except Exception as ex: return repr(ex)

L('# R306 DATA RECOVERY phase 5 - wait for the user-run bat')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
data_found='unknown'
try:
    locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
    L('bat on desktop: %s'%Path(r'D:\桌面\RECOVERY-recover-data.bat').exists())
    L('polling vss_out.txt for up to 600s (reminder popup at 300s if silent)...')
    t0=time.time(); vtxt=None
    while time.time()-t0<600:
        time.sleep(15)
        if VSSOUT.exists():
            try: vtxt=VSSOUT.read_text(encoding='utf-8',errors='replace')
            except Exception: pass
        if vtxt:
            done=('== recovery helper done' in vtxt) or ('WINFR_UNAVAILABLE' in vtxt) or ('shadow_count=' in vtxt and 'NO_NINE_CAT' in vtxt)
            started=('RECOVERY_START' in vtxt) or ('WINFR_START' in vtxt)
            if started or done:
                L('helper output ready after %ds'%(int(time.time()-t0))); break
        el=int(time.time()-t0)
        if el in (300,):
            msg=("REMINDER: to recover the lost 20GB library, DOUBLE-CLICK "
                 "'RECOVERY-recover-data.bat' on the desktop and click YES on the "
                 "permission prompt. Recovery goes to C:\\; nothing is deleted.")
            run(['powershell','-NoProfile','-Command',
                 "(New-Object -ComObject WScript.Shell).Popup('{0}',60,'DeskBox data recovery',64)"\
                 .format(msg.replace("'","''"))],timeout=70)
            L('reminder popup shown at 300s')
    if vtxt:
        vls=vtxt.splitlines()
        L('== vss_out.txt (%d lines) =='%len(vls))
        for ln in vls[:80]:
            if any(k in ln for k in ('shadow','HIT','nine_cat','RECOVERY','NO_NINE','free','fs ','WINFR','winget','cim_error','link_fail','started','done')):
                L('  vss| '+ln[:170])
        data_found=classify(vtxt)
    else:
        L('no helper output within 600s')
        data_found='awaiting_user_doubleclick'
    L('data_found=%s'%data_found)
    # progress evidence
    if data_found=='recovering_vss':
        L('robocopy log tail: %s'%tail(RCLOG)[:400])
    if data_found=='winfr_running':
        L('winfr log tail: %s'%tail(WFLOG)[:400])
    for r in (Path(r'C:\recovery_vss\DeskBoxLibrary'),Path(r'C:\recovery_winfr_E')):
        if r.exists():
            try:
                ents=list(r.iterdir())
                L('recovery_dest %s -> %d top entries'%(str(r),len(ents)))
                for e in ents[:12]: L('   %s'%e.name)
            except Exception as ex: L('recovery_dest read error %r'%ex)
except Exception:
    L('FATAL: '+traceback.format_exc()); data_found='crashed'

box_pids=[]
for f in DBOX.glob('deskbox-*.pid'):
    try:
        pid=int(f.read_text().strip())
        c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
        if str(pid) in (o or ''): box_pids.append(pid)
    except Exception: pass
L('boxes_alive_now=%d %s'%(len(box_pids),box_pids))
complete = data_found in ('recovering_vss','winfr_running','no_shadows','vss_empty_winfr_unavailable','vss_seen_no_hit','vss_enum_failed')
L('R306_RECOVERY_PHASE5_COMPLETE=%s'%complete)
WT(REPORT,'\n'.join(lines)+'\n')
WT(J,json.dumps({'dataFound':data_found,'phase5Complete':complete,'boxesAlive':len(box_pids)},indent=2)+'\n')
sys.exit(0 if complete else 6)
