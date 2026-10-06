# t259_recovery_retry_r308.py - round 308. DATA RECOVERY retry.
# r307 restored the desktop (explorer + icons back). Crucially the earlier
# recovery attempts happened while the mpv fullscreen window HID the desktop,
# so the user could not even see RECOVERY-recover-data.bat to double-click.
# Now the desktop is visible. This round:
#  1. If vss_out.txt already exists (user ran the bat after r307): read,
#     classify, report progress. Done - no popups.
#  2. Else: make sure the bat and the elevated helper exist (rewrite if
#     missing), show one instruction popup, poll vss_out.txt for 600s
#     (one reminder popup at 300s).
#  3. Progress evidence: robocopy / winfr log tails, recovery dir counts.
import os, sys, time, subprocess, json, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R308_RECOVERY_RETRY.md'; J=OUT/'r308-recovery-retry.json'
DBOX=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
HELPER=DBOX/'vss_helper.ps1'; VSSOUT=DBOX/'vss_out.txt'
RCLOG=DBOX/'recovery_robocopy.log'; WFLOG=DBOX/'winfr_E.log'
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
def tail(p,n=6):
    if not Path(p).exists(): return '(absent)'
    try: return ' | '.join(Path(p).read_text(encoding='utf-8',errors='replace').splitlines()[-n:])
    except Exception as ex: return repr(ex)
def report_progress(kind):
    if kind=='recovering_vss':
        L('robocopy_log_tail=%s'%tail(RCLOG)[:500])
    if kind=='winfr_running':
        L('winfr_log_tail=%s'%tail(WFLOG)[:500])
    for r in (Path(r'C:\recovery_vss\DeskBoxLibrary'),Path(r'C:\recovery_winfr_E')):
        if r.exists():
            try:
                ents=list(r.iterdir())
                L('recovery_dest %s -> %d top entries'%(str(r),len(ents)))
                for e in ents[:12]: L('   %s'%e.name)
            except Exception as ex: L('recovery_dest read error %r'%ex)

def read_vss():
    if not VSSOUT.exists(): return None
    try: return VSSOUT.read_text(encoding='utf-8',errors='replace')
    except Exception: return '<unreadable>'

L('# R308 DATA RECOVERY retry - desktop is visible again')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
data_found='unknown'
try:
    locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
    DESK=real_desktop(); L('real_desktop='+str(DESK))

    # ---- 1. did the user already run the bat?
    vtxt=read_vss()
    if vtxt:
        vls=vtxt.splitlines(); L('vss_out.txt ALREADY exists (%d lines) - user ran the bat'%len(vls))
        for ln in vls[:80]:
            if any(k in ln for k in ('shadow','HIT','nine_cat','RECOVERY','NO_NINE','free','fs ','WINFR','winget','cim_error','link_fail','started','done')):
                L('  vss| '+ln[:170])
        data_found=classify(vtxt)
        L('data_found=%s'%data_found); report_progress(data_found)
    else:
        # ---- 2. ensure bat + helper exist (rewrite if missing)
        BAT=DESK/'RECOVERY-recover-data.bat'
        if not BAT.exists():
            bat=("@echo off\r\n"
                 "net session >nul 2>&1\r\n"
                 "if %errorlevel% neq 0 (\r\n"
                 "    echo Requesting administrator privileges...\r\n"
                 "    powershell -NoProfile -Command \"Start-Process -FilePath '%~f0' -Verb RunAs\"\r\n"
                 "    exit /b\r\n"
                 ")\r\n"
                 "echo Running the recovery helper (shadow-copy search, then winfr if needed)...\r\n"
                 "powershell -NoProfile -ExecutionPolicy Bypass -File \"E:\\0mcp-agv-arena-optimized\\deskbox-v2\\vss_helper.ps1\"\r\n"
                 "echo.\r\n"
                 "echo ===== DONE. Result file: E:\\0mcp-agv-arena-optimized\\deskbox-v2\\vss_out.txt =====\r\n"
                 "echo This window closes in 25 seconds.\r\n"
                 "timeout /t 25 >nul\r\n")
            WT(BAT,bat); L('bat_rewritten=%s'%str(BAT))
        else:
            L('bat_present=%s (%dB)'%(str(BAT),BAT.stat().st_size))
        if not HELPER.exists():
            L('FATAL: vss_helper.ps1 missing - cannot proceed'); sys.exit(6)
        L('helper_present=True (%dB)'%HELPER.stat().st_size)

        # ---- 3. instruction popup + long poll
        L('showing instruction popup (45s auto-close)')
        msg=("DATA RECOVERY - ACTION NEEDED: please DOUBLE-CLICK "
             "'RECOVERY-recover-data.bat' on your desktop NOW, then click YES on "
             "the permission prompt. It searches volume shadow copies and "
             "recovers the lost 20GB library to C:\\. Nothing will be deleted.")
        run(['powershell','-NoProfile','-Command',
             "(New-Object -ComObject WScript.Shell).Popup('{0}',45,'DeskBox data recovery',64)"\
             .format(msg.replace("'","''"))],timeout=55)
        L('polling vss_out.txt for up to 600s...')
        t0=time.time()
        while time.time()-t0<600:
            time.sleep(15)
            vtxt=read_vss()
            if vtxt:
                started=('RECOVERY_START' in vtxt) or ('WINFR_START' in vtxt)
                done=('== recovery helper done' in vtxt) or ('WINFR_UNAVAILABLE' in vtxt) or ('shadow_count=' in vtxt and 'NO_NINE_CAT' in vtxt)
                if started or done:
                    L('helper output ready after %ds'%(int(time.time()-t0))); break
            el=int(time.time()-t0)
            if el==300:
                run(['powershell','-NoProfile','-Command',
                     "(New-Object -ComObject WScript.Shell).Popup('{0}',60,'DeskBox data recovery',64)"\
                     .format("REMINDER: double-click RECOVERY-recover-data.bat on the desktop and click YES to recover the lost 20GB library.".replace("'","''"))],timeout=70)
                L('reminder popup shown at 300s')
        if vtxt:
            vls=vtxt.splitlines()
            L('== vss_out.txt (%d lines) =='%len(vls))
            for ln in vls[:80]:
                if any(k in ln for k in ('shadow','HIT','nine_cat','RECOVERY','NO_NINE','free','fs ','WINFR','winget','cim_error','link_fail','started','done')):
                    L('  vss| '+ln[:170])
            data_found=classify(vtxt)
            report_progress(data_found)
        else:
            L('no helper output within 600s')
            data_found='awaiting_user_doubleclick'
        L('data_found=%s'%data_found)
except Exception:
    L('FATAL: '+traceback.format_exc()); data_found='crashed'

L('boxes: (rolled back in r307 - expected none)')
WT(REPORT,'\n'.join(lines)+'\n')
WT(J,json.dumps({'dataFound':data_found},indent=2)+'\n')
sys.exit(0 if data_found in ('recovering_vss','winfr_running','no_shadows','vss_empty_winfr_unavailable','vss_seen_no_hit','vss_enum_failed') else 6)
