# t262_winfr_segment_r311.py - round 311. DATA RECOVERY phase 8.
# r310: winfr IS installed (v3 installer worked!) but it quit instantly:
# "Switch used is incompatible with recovery mode" - /regular does not
# accept the \path\* wildcard filter. Fix: segment mode (the default)
# accepts wildcards and still restores filenames from NTFS MFT.
# helper v4: try segment mode, wait 35s, verify the winfr process is still
# alive; if it died, fall back to /regular with a trailing-backslash
# directory filter; verify again; log the final verdict. One user
# double-click should now be the LAST one needed to start the scan.
import os, sys, time, subprocess, json, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R311_WINFR_SEGMENT.md'; J=OUT/'r311-winfr-segment.json'
DBOX=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
HELPER=DBOX/'vss_helper.ps1'; VSSOUT=DBOX/'vss_out.txt'; WFLOG=DBOX/'winfr_E.log'; WFLOG2=DBOX/'winfr_E2.log'
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

helper=r'''
$ErrorActionPreference='Continue'
$out='E:\0mcp-agv-arena-optimized\deskbox-v2\vss_out.txt'
function Log($s){ Add-Content -Path $out -Value $s -Encoding UTF8 }
Set-Content -Path $out -Value ('== recovery helper v4 started ' + (Get-Date)) -Encoding UTF8
$dest='C:\recovery_winfr_E'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Log 'NO_SHADOWS_AT_ALL (established r308/r310)'
Log 'fs E=NTFS D=NTFS'
$wf=Get-Command winfr -ErrorAction SilentlyContinue
if(-not $wf){ $alias=Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winfr.exe'; if(Test-Path $alias){ $wf=$alias } }
if(-not $wf){ $pf='C:\Program Files\Windows File Recovery\winfr.exe'; if(Test-Path $pf){ $wf=$pf } }
if(-not $wf){
  Log 'WINFR_NOT_FOUND - reinstalling'
  try{ $o1=winget install --id Microsoft.WindowsFileRecovery --source winget --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-String; Log ('wg1: ' + $o1.Trim()) }catch{ Log ('wg1_error ' + $_.Exception.Message) }
  $wf=Get-Command winfr -ErrorAction SilentlyContinue
  if(-not $wf){ $alias=Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winfr.exe'; if(Test-Path $alias){ $wf=$alias } }
}
if(-not $wf){ Log 'WINFR_STILL_MISSING'; Log ('== recovery helper v4 done ' + (Get-Date)); exit }
function WinfrAlive{ $p=Get-Process winfr -ErrorAction SilentlyContinue; return ($p -ne $null) }
function DumpLog($f){
  if(Test-Path $f){
    $t=Get-Content $f -ErrorAction SilentlyContinue | Select-Object -Last 12
    foreach($l in $t){ Log ('  wflog: ' + $l) }
  }
}
Log 'attempt segment mode (wildcard filter, default mode)'
Start-Process cmd -ArgumentList '/c winfr E: "C:\recovery_winfr_E" /n \0mcp-agv-arena-optimized\deskbox-v2\library\* /y > E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_E.log 2>&1' -WindowStyle Hidden
Start-Sleep 35
if(WinfrAlive){ Log 'WINFR_SCAN_RUNNING (segment mode, wildcard filter)'; Log ('== recovery helper v4 done ' + (Get-Date)); exit }
Log 'segment mode died - log tail:'
DumpLog 'E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_E.log'
Log 'attempt regular mode with trailing-backslash directory filter'
Start-Process cmd -ArgumentList '/c winfr E: "C:\recovery_winfr_E" /regular /n \0mcp-agv-arena-optimized\deskbox-v2\library\ /y > E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_E2.log 2>&1' -WindowStyle Hidden
Start-Sleep 35
if(WinfrAlive){ Log 'WINFR_SCAN_RUNNING (regular mode, dir filter)'; Log ('== recovery helper v4 done ' + (Get-Date)); exit }
Log 'regular mode died too - log tail:'
DumpLog 'E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_E2.log'
Log 'WINFR_FAILED_BOTH'
Log ('== recovery helper v4 done ' + (Get-Date))
'''
WT(HELPER,helper,'utf-8-sig')

L('# R311 winfr segment-mode retry')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
state='unknown'
try:
    locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
    DESK=real_desktop(); BAT=DESK/'RECOVERY-recover-data.bat'
    L('bat_present=%s helper_v4_written=%dB'%(BAT.exists(),HELPER.stat().st_size))
    c,o=run(['tasklist','/FI','IMAGENAME eq winfr.exe'],timeout=20)
    L('winfr_process_before=%s'%('winfr.exe' in (o or '')))
    mtime0=VSSOUT.stat().st_mtime if VSSOUT.exists() else 0
    L('old_vss_out_mtime=%s'%time.strftime('%H:%M:%S',time.localtime(mtime0)))

    L('showing popup: LAST double-click needed')
    msg=("ALMOST THERE: winfr is installed. Please DOUBLE-CLICK "
         "'RECOVERY-recover-data.bat' ONE LAST TIME and click YES - this run "
         "starts the actual 20GB scan with the corrected settings. The scan "
         "runs in the background for 10-30 minutes; you can keep using the "
         "PC. Nothing is deleted.")
    run(['powershell','-NoProfile','-Command',
         "(New-Object -ComObject WScript.Shell).Popup('{0}',45,'DeskBox data recovery',64)"\
         .format(msg.replace("'","''"))],timeout=55)
    L('polling for fresh vss_out.txt (up to 600s)...')
    t0=time.time(); vtxt=None; fresh=False
    while time.time()-t0<600:
        time.sleep(15)
        if VSSOUT.exists() and VSSOUT.stat().st_mtime>t0:
            try: vtxt=VSSOUT.read_text(encoding='utf-8',errors='replace'); fresh=True
            except Exception: pass
        if fresh and ('WINFR_SCAN_RUNNING' in vtxt or 'WINFR_FAILED_BOTH' in vtxt or 'WINFR_STILL_MISSING' in vtxt or ('v4 done' in vtxt)):
            L('helper v4 finished after %ds'%(int(time.time()-t0))); break
        el=int(time.time()-t0)
        if el==300:
            run(['powershell','-NoProfile','-Command',
                 "(New-Object -ComObject WScript.Shell).Popup('{0}',60,'DeskBox data recovery',64)"\
                 .format("REMINDER: double-click RECOVERY-recover-data.bat one last time and click YES - it starts the 20GB scan now.".replace("'","''"))],timeout=70)
            L('reminder popup at 300s')
    if vtxt and fresh:
        vls=vtxt.splitlines()
        L('== fresh vss_out.txt (%d lines) =='%len(vls))
        for ln in vls[:120]:
            L('  vss| '+ln[:170])
            if '?' in ln:
                L('  raw| '+ln.encode('unicode_escape').decode('ascii')[:260])
        if 'WINFR_SCAN_RUNNING' in vtxt: state='winfr_scan_running'
        elif 'WINFR_FAILED_BOTH' in vtxt: state='winfr_failed_both'
        elif 'WINFR_STILL_MISSING' in vtxt: state='winfr_missing'
        else: state='unclear'
    else:
        L('no fresh helper output within 600s'); state='awaiting_user_doubleclick'
    L('state=%s'%state)
    # independent process check
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
L('R311_FINAL=%s'%state)
WT(REPORT,'\n'.join(lines)+'\n')
WT(J,json.dumps({'state':state},indent=2)+'\n')
sys.exit(0 if state in ('winfr_scan_running','winfr_failed_both','winfr_missing','unclear') else 6)
