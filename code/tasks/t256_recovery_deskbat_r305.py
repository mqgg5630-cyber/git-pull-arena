# t256_recovery_deskbat_r305.py - round 305. DATA RECOVERY phase 4.
# r304 proved Start-Process -Verb RunAs fails IMMEDIATELY from the watcher
# (ELEVATION_FAILED twice, no user-interaction wait) - the UAC prompt never
# reaches the user's desktop. New approach: STOP trying to auto-elevate.
#  1. Diagnose: dump the real uac_err.txt message (unicode_escape), check
#     the watcher's session id.
#  2. Drop a self-elevating RECOVERY bat on the real desktop.
#  3. Show a synchronous WScript Popup (auto-closes in 45s) instructing the
#     user to double-click the bat and click Yes on ITS UAC prompt.
#  4. Poll vss_out.txt for up to 5 minutes; classify and report.
import os, sys, time, subprocess, json, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R305_RECOVERY_DESKBAT.md'; J=OUT/'r305-recovery-deskbat.json'
DBOX=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
HELPER=DBOX/'vss_helper.ps1'; VSSOUT=DBOX/'vss_out.txt'; UACERR=DBOX/'uac_err.txt'
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
def real_desktop():
    d=Path(os.environ.get('USERPROFILE',r'C:\Users\Public'))/'Desktop'
    try:
        c,o=run(['reg','query',r'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders','/v','Desktop'],timeout=15)
        for ln in (o or '').splitlines():
            if 'REG_SZ' in ln and 'Desktop' in ln:
                cand=ln.split('REG_SZ',1)[1].strip()
                if cand and Path(cand).exists(): return Path(cand)
    except Exception: pass
    return d

def classify(vtxt):
    if vtxt is None: return 'no_file'
    if 'RECOVERY_START' in vtxt: return 'recovering_vss'
    if 'WINFR_START' in vtxt: return 'winfr_running'
    if 'WINFR_UNAVAILABLE' in vtxt and 'NO_NINE_CAT_IN_SHADOWS' in vtxt: return 'vss_empty_winfr_unavailable'
    if 'shadow_count=0' in vtxt: return 'no_shadows'
    if 'cim_error' in vtxt: return 'vss_enum_failed'
    if 'NO_NINE_CAT_IN_SHADOWS' in vtxt: return 'vss_seen_no_hit'
    return 'helper_ran_unclear'

L('# R305 DATA RECOVERY phase 4 - desktop self-elevating bat')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
data_found='unknown'
DESK=real_desktop(); L('real_desktop='+str(DESK))
try:
    locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))

    # ---- 1. diagnostics: real elevation error + session id
    if UACERR.exists():
        try:
            uerr=UACERR.read_text(encoding='utf-8',errors='replace').strip()
            L('uac_err_raw=%s'%uerr.encode('unicode_escape').decode('ascii')[:400])
        except Exception as ex: L('uac_err read error %r'%ex)
    c,o=run(['powershell','-NoProfile','-Command','(Get-Process -Id %d).SessionId'%os.getpid()],timeout=20)
    L('watcher_session_id=%s'%(o or '').strip().splitlines()[-1:] )
    L('helper_exists=%s'%HELPER.exists())
    if not HELPER.exists(): L('FATAL helper missing - cannot proceed'); sys.exit(6)

    # ---- 2. self-elevating bat on the real desktop
    BAT=DESK/'RECOVERY-recover-data.bat'
    bat=r'''@echo off
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
echo Running the recovery helper (shadow-copy search, then winfr if needed)...
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\0mcp-agv-arena-optimized\deskbox-v2\vss_helper.ps1"
echo.
echo ===== DONE. Result file: E:\0mcp-agv-arena-optimized\deskbox-v2\vss_out.txt =====
echo This window closes in 25 seconds.
timeout /t 25 >nul
'''
    WT(BAT,bat)
    L('bat_written=%s (%dB)'%(str(BAT),BAT.stat().st_size))

    # ---- 3. synchronous instruction popup (auto-closes in 45s)
    L('showing instruction popup (45s auto-close)')
    msg=("DATA RECOVERY - ACTION NEEDED: please DOUBLE-CLICK the file "
         "'RECOVERY-recover-data.bat' on your desktop, then click YES on its "
         "permission prompt. It searches volume shadow copies and recovers the "
         "lost 20GB library to C:\\. Nothing will be deleted.")
    c,o=run(['powershell','-NoProfile','-Command',
             "(New-Object -ComObject WScript.Shell).Popup('{0}',45,'DeskBox data recovery',64)"\
             .format(msg.replace("'","''"))],timeout=55)
    L('popup_rc=%s (1=OK clicked, -1/timeout=auto-closed)'%c)

    # ---- 4. poll for the helper output (user needs time to double-click)
    L('polling vss_out.txt for up to 300s...')
    t0=time.time()
    vtxt=None
    while time.time()-t0<300:
        time.sleep(10)
        if VSSOUT.exists():
            try: vtxt=VSSOUT.read_text(encoding='utf-8',errors='replace')
            except Exception: pass
            if vtxt and ('== recovery helper done' in vtxt or 'RECOVERY_START' in vtxt or 'WINFR_START' in vtxt or 'WINFR_UNAVAILABLE' in vtxt or 'shadow_count=' in vtxt):
                L('vss_out.txt appeared after %ds'%(int(time.time()-t0)))
                break
        if int(time.time()-t0)%60==0: L('  still waiting (%ds)...'%(int(time.time()-t0)))
    if vtxt:
        vls=vtxt.splitlines()
        L('== vss_out.txt (%d lines) =='%len(vls))
        for ln in vls[:70]:
            if any(k in ln for k in ('shadow','HIT','nine_cat','RECOVERY','NO_NINE','free','fs ','WINFR','winget','cim_error','link_fail','started','done')):
                L('  vss| '+ln[:170])
        data_found=classify(vtxt)
    else:
        L('user did not run the bat within 300s')
        data_found='awaiting_user_doubleclick'
    L('data_found=%s'%data_found)
    for r in (Path(r'C:\recovery_vss\DeskBoxLibrary'),Path(r'C:\recovery_winfr_E')):
        if r.exists():
            try: L('recovery_dest %s -> %d entries'%(str(r),len(list(r.iterdir()))))
            except Exception: pass
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
L('R305_RECOVERY_PHASE4_COMPLETE=%s'%complete)
L('BAT_STAYS_ON_DESKTOP=%s'%('RECOVERY-recover-data.bat' if data_found=='awaiting_user_doubleclick' else 'remove-after-verify'))
WT(REPORT,'\n'.join(lines)+'\n')
WT(J,json.dumps({'dataFound':data_found,'phase4Complete':complete,'boxesAlive':len(box_pids)},indent=2)+'\n')
sys.exit(0 if complete else 6)
