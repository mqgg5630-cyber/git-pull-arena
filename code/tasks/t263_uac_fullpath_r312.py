# t263_uac_fullpath_r312.py - round 312. DATA RECOVERY phase 9.
# The user asked for the flow: WE trigger the permission prompt, THEY click
# Yes, the recovery runs. The watcher's Start-Process -Verb RunAs failed
# with "no application is associated with the specified file" - most likely
# because 'powershell' was resolved via a stripped PATH. Fix: use FULL PATHS.
#  1. popup telling the user a UAC will appear NOW - click Yes.
#  2. attempt A: Start-Process -FilePath <full powershell.exe> -Verb RunAs.
#  3. attempt B (if A failed): Start-Process <full cmd.exe> -Verb RunAs with
#     /c powershell -File helper.
#  4. read vss_out.txt for the helper v4 verdict (WINFR_SCAN_RUNNING etc).
#  5. if elevation still impossible: one popup pointing at the desktop bat
#     + a 300s poll as fallback. Nothing is deleted.
import os, sys, time, subprocess, json, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R312_UAC_FULLPATH.md'; J=OUT/'r312-uac-fullpath.json'
DBOX=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
HELPER=DBOX/'vss_helper.ps1'; VSSOUT=DBOX/'vss_out.txt'; UACERR=DBOX/'uac_err.txt'
WFLOG=DBOX/'winfr_E.log'; WFLOG2=DBOX/'winfr_E2.log'
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
PSFULL=r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
CMDFULL=r'C:\Windows\System32\cmd.exe'

def launcher(variant):
    if variant=='A':
        inner=("$ErrorActionPreference='Stop';"
               "try{ Start-Process -FilePath '{ps}' -Verb RunAs -Wait -WindowStyle Hidden "
               "-ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','{h}';"
               "'ELEVATED_RUN_OK' | Out-File '{e}' -Encoding ascii }"
               "catch{{ ('ELEVATION_FAILED: ' + $_.Exception.Message) | Out-File '{e}' -Encoding utf8 }}"\
               ).format(ps=PSFULL,h=str(HELPER),e=str(UACERR))
    else:
        inner=("try{ Start-Process -FilePath '{cm}' -Verb RunAs -Wait -WindowStyle Hidden "
               "-ArgumentList '/c','{ps}','-NoProfile','-ExecutionPolicy','Bypass','-File','{h}';"
               "'ELEVATED_RUN_OK' | Out-File '{e}' -Encoding ascii }"
               "catch{{ ('ELEVATION_FAILED: ' + $_.Exception.Message) | Out-File '{e}' -Encoding utf8 }}"\
               ).format(cm=CMDFULL,ps=PSFULL,h=str(HELPER),e=str(UACERR))
    lf=DBOX/('vss_launch_%s.ps1'%variant)
    WT(lf,inner)
    return lf

def attempt(variant):
    L('== elevation attempt %s (full paths) =='%variant)
    for f in (UACERR,):
        try: f.unlink()
        except Exception: pass
    lf=launcher(variant)
    rc,out=run([PSFULL,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(lf)],timeout=300)
    L('launcher_rc=%s'%rc)
    uerr=''
    if UACERR.exists():
        try: uerr=UACERR.read_text(encoding='utf-8',errors='replace').strip()
        except Exception: pass
    L('uac_err=%s'%uerr[:200])
    if '?' in uerr:
        L('uac_err_raw=%s'%uerr.encode('unicode_escape').decode('ascii')[:400])
    if 'ELEVATED_RUN_OK' in uerr:
        return 'ok'
    if 'canceled by the user' in uerr or u'\u53d6\u6d88' in uerr:
        return 'declined'
    return 'failed'

def read_helper_result():
    if not VSSOUT.exists(): return None
    try: return VSSOUT.read_text(encoding='utf-8',errors='replace')
    except Exception: return '<unreadable>'

L('# R312 full-path UAC trigger + helper v4 run')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
state='unknown'
try:
    locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
    L('ps_full_exists=%s cmd_full_exists=%s helper_exists=%s'%(Path(PSFULL).exists(),Path(CMDFULL).exists(),HELPER.exists()))
    mtime0=VSSOUT.stat().st_mtime if VSSOUT.exists() else 0

    L('showing heads-up popup (UAC is coming NOW)')
    msg=("PERMISSION REQUEST COMING NOW: in a few seconds Windows will ask "
         "for administrator permission (blue/yellow shield dialog). PLEASE "
         "CLICK YES - the 20GB recovery scan starts immediately. You do not "
         "need to double-click anything else.")
    run([PSFULL,'-NoProfile','-Command',
         "(New-Object -ComObject WScript.Shell).Popup('{0}',20,'DeskBox data recovery',64)"\
         .format(msg.replace("'","''"))],timeout=30)
    res=attempt('A')
    if res!='ok':
        L('attempt A %s - trying B (cmd wrapper)'%res)
        time.sleep(3)
        res=attempt('B')
    if res=='ok' or res=='declined':
        time.sleep(5)
    vtxt=read_helper_result()
    if vtxt and VSSOUT.exists() and VSSOUT.stat().st_mtime>time.time()-420:
        vls=vtxt.splitlines()
        L('== vss_out.txt (%d lines) =='%len(vls))
        for ln in vls[:130]:
            L('  vss| '+ln[:170])
            if '?' in ln:
                L('  raw| '+ln.encode('unicode_escape').decode('ascii')[:260])
        if 'WINFR_SCAN_RUNNING' in vtxt: state='winfr_scan_running'
        elif 'WINFR_FAILED_BOTH' in vtxt: state='winfr_failed_both'
        elif 'WINFR_STILL_MISSING' in vtxt: state='winfr_missing'
        elif res=='declined': state='uac_declined'
        else: state='unclear'
    elif res=='declined':
        state='uac_declined'
    else:
        L('elevation from watcher still broken - falling back to the desktop bat')
        run([PSFULL,'-NoProfile','-Command',
             "(New-Object -ComObject WScript.Shell).Popup('{0}',60,'DeskBox data recovery',64)"\
             .format("Could not show the permission dialog automatically. Please DOUBLE-CLICK 'RECOVERY-recover-data.bat' on the desktop and click YES - the 20GB scan starts from there.".replace("'","''"))],timeout=70)
        t0=time.time()
        while time.time()-t0<300:
            time.sleep(15)
            vtxt=read_helper_result()
            if vtxt and VSSOUT.stat().st_mtime>t0 and ('WINFR_SCAN_RUNNING' in vtxt or 'WINFR_FAILED_BOTH' in vtxt):
                L('helper ran via bat after %ds'%(int(time.time()-t0)))
                vls=vtxt.splitlines()
                for ln in vls[:130]:
                    L('  vss| '+ln[:170])
                    if '?' in ln: L('  raw| '+ln.encode('unicode_escape').decode('ascii')[:260])
                state='winfr_scan_running' if 'WINFR_SCAN_RUNNING' in vtxt else 'winfr_failed_both'
                break
        if state=='unknown': state='awaiting_user'
    L('state=%s'%state)
    c,o=run(['tasklist','/FI','IMAGENAME eq winfr.exe'],timeout=20)
    L('winfr_process_now=%s'%('winfr.exe' in (o or '')))
    for lf in (WFLOG,WFLOG2):
        if lf.exists():
            try:
                raw=lf.read_text(encoding='utf-16',errors='replace')
                if not raw.strip('\x00 \r\n'): raw=lf.read_text(encoding='utf-8',errors='replace')
                wl=[x.strip('\x00 ') for x in raw.splitlines() if x.strip('\x00 ')]
                L('== %s (%d lines) tail =='%(lf.name,len(wl)))
                for ln in wl[-8:]: L('  wf| '+ln[:160])
            except Exception as ex: L('%s read error %r'%(lf.name,ex))
    rdir=Path(r'C:\recovery_winfr_E')
    if rdir.exists():
        try:
            files=[e for e in rdir.rglob('*') if e.is_file()]
            L('recovery_winfr_E now: %d files, %dMB'%(len(files),sum(e.stat().st_size for e in files)//1048576))
        except Exception: pass
except Exception:
    L('FATAL: '+traceback.format_exc()); state='crashed'
L('R312_FINAL=%s'%state)
WT(REPORT,'\n'.join(lines)+'\n')
WT(J,json.dumps({'state':state},indent=2)+'\n')
sys.exit(0 if state in ('winfr_scan_running','winfr_failed_both','winfr_missing','uac_declined','unclear') else 6)
