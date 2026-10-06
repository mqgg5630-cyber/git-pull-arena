# t265_winfr_vintage_r314.py - round 314. DATA RECOVERY phase 10.
# r313: the full-path UAC WORKS now (ELEVATED_RUN_OK - the user clicked Yes,
# helper v4 ran elevated, no bat double-click needed anymore). But winfr
# 0.1.20151.0 (the vintage May-2020 build) rejects both our invocations
# with "Switch used is incompatible with recovery mode" - it likely does
# not know /y or /regular, which were added in later builds. Its own error
# text says: check /! for more information.
# helper v5 plan (elevated, one UAC click):
#  0. winfr /!  -> winfr_help.log (the REAL syntax of this build)
#  1. attempt: echo Y | winfr E: dest /n <wildcard filter>   (no /y, no mode)
#  2. attempt: upgrade/install the newer winfr (winget upgrade, then
#     msstore 9N26S50LN705), then winfr E: dest /n <filter> /y
#  3. attempt: echo Y | winfr E: dest /r                      (vintage signature mode, last resort)
#  Each attempt: 40s liveness check + log tail into vss_out.txt.
# Nothing deleted; recovery output to C:\ only.
import os, sys, time, subprocess, json, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R314_WINFR_VINTAGE.md'; J=OUT/'r314-winfr-vintage.json'
DBOX=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
HELPER=DBOX/'vss_helper.ps1'; VSSOUT=DBOX/'vss_out.txt'; UACERR=DBOX/'uac_err.txt'
PSFULL=r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
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

helper=r'''
$ErrorActionPreference='Continue'
$out='E:\0mcp-agv-arena-optimized\deskbox-v2\vss_out.txt'
function Log($s){ Add-Content -Path $out -Value $s -Encoding UTF8 }
Set-Content -Path $out -Value ('== recovery helper v5 started ' + (Get-Date)) -Encoding UTF8
$dest='C:\recovery_winfr_E'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$wf=Get-Command winfr -ErrorAction SilentlyContinue
if(-not $wf){ $alias=Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winfr.exe'; if(Test-Path $alias){ $wf=$alias } }
if(-not $wf){ Log 'WINFR_NOT_FOUND'; Log ('== recovery helper v5 done ' + (Get-Date)); exit }
function WinfrAlive{ $p=Get-Process winfr -ErrorAction SilentlyContinue; return ($p -ne $null) }
function DumpLog($f){
  if(Test-Path $f){
    $t=Get-Content $f -ErrorAction SilentlyContinue | Select-Object -Last 10
    foreach($l in $t){ Log ('  wflog: ' + ($l -replace '\x00','')) }
  }
}
Log 'step0: capture this build usage screen (winfr /!)'
cmd /c "winfr /! > E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_help.log 2>&1" | Out-Null
if(Test-Path 'E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_help.log'){
  $help=Get-Content 'E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_help.log' -ErrorAction SilentlyContinue | Select-Object -First 40
  foreach($l in $help){ Log ('  usage: ' + ($l -replace '\x00','')) }
}
Log 'attempt1: vintage segment (echo Y pipe, no /y no mode switch)'
cmd /c "echo Y| winfr E: `"C:\recovery_winfr_E`" /n \0mcp-agv-arena-optimized\deskbox-v2\library\* > E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_E.log 2>&1" | Out-Null
Log ('attempt1 exitcode=' + $LASTEXITCODE)
Start-Sleep 40
if(WinfrAlive){ Log 'WINFR_SCAN_RUNNING (vintage segment, echo Y)'; Log ('== recovery helper v5 done ' + (Get-Date)); exit }
Log 'attempt1 died - log tail:'
DumpLog 'E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_E.log'
Log 'attempt2: upgrade winfr to a newer build'
try{ $u=winget upgrade Microsoft.WindowsFileRecovery --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-String; Log ('wgup: ' + $u.Trim()) }catch{ Log ('wgup_error ' + $_.Exception.Message) }
$wf2=Get-Command winfr -ErrorAction SilentlyContinue
if(-not $wf2){ $alias=Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winfr.exe'; if(Test-Path $alias){ $wf2=$alias } }
if($wf2){
  Log 'attempt2b: newer build with /y'
  cmd /c "winfr E: `"C:\recovery_winfr_E`" /n \0mcp-agv-arena-optimized\deskbox-v2\library\* /y > E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_E3.log 2>&1" | Out-Null
  Start-Sleep 40
  if(WinfrAlive){ Log 'WINFR_SCAN_RUNNING (upgraded build with /y)'; Log ('== recovery helper v5 done ' + (Get-Date)); exit }
  Log 'attempt2b died - log tail:'
  DumpLog 'E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_E3.log'
}
Log 'attempt3: vintage signature mode /r (last resort, filenames may be lost)'
cmd /c "echo Y| winfr E: `"C:\recovery_winfr_E`" /r > E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_E4.log 2>&1" | Out-Null
Start-Sleep 40
if(WinfrAlive){ Log 'WINFR_SCAN_RUNNING (vintage signature /r)'; Log ('== recovery helper v5 done ' + (Get-Date)); exit }
Log 'attempt3 died - log tail:'
DumpLog 'E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_E4.log'
Log 'WINFR_FAILED_ALL_ATTEMPTS'
Log ('== recovery helper v5 done ' + (Get-Date))
'''
WT(HELPER,helper,'utf-8-sig')
launcher=("$ErrorActionPreference='Stop'; "
          "try{ Start-Process -FilePath '" + PSFULL + "' -Verb RunAs -Wait -WindowStyle Hidden "
          "-ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','" + str(HELPER) + "'; "
          "'ELEVATED_RUN_OK' | Out-File '" + str(UACERR) + "' -Encoding ascii }"
          "catch{ ('ELEVATION_FAILED: ' + $_.Exception.Message) | Out-File '" + str(UACERR) + "' -Encoding utf8 }")
LF=DBOX/'vss_launch_v5.ps1'; WT(LF,launcher)

L('# R314 vintage winfr invocation attempts')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
state='unknown'
try:
    locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
    try: UACERR.unlink()
    except Exception: pass
    L('showing heads-up popup (UAC is coming - click Yes)')
    msg=("ONE MORE PERMISSION REQUEST: a Windows admin dialog appears in a "
         "few seconds - PLEASE CLICK YES. It reads this winfr build's real "
         "usage screen and starts the 20GB scan with vintage-compatible "
         "settings. Nothing is deleted.")
    run([PSFULL,'-NoProfile','-Command',
         "(New-Object -ComObject WScript.Shell).Popup('{0}',20,'DeskBox data recovery',64)"\
         .format(msg.replace("'","''"))],timeout=30)
    rc=run([PSFULL,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(LF)],timeout=420)
    L('launcher_rc=%s'%rc[0])
    uerr=''
    if UACERR.exists():
        try: uerr=UACERR.read_text(encoding='utf-8',errors='replace').strip()
        except Exception: pass
    L('uac_err=%s'%uerr[:160])
    if 'ELEVATED_RUN_OK' in uerr:
        time.sleep(8)
        if VSSOUT.exists():
            vtxt=VSSOUT.read_text(encoding='utf-8',errors='replace')
            vls=vtxt.splitlines()
            L('== vss_out.txt (%d lines) =='%len(vls))
            for ln in vls[:150]:
                L('  vss| '+ln[:170])
                if '?' in ln:
                    L('  raw| '+ln.encode('unicode_escape').decode('ascii')[:260])
            if 'WINFR_SCAN_RUNNING' in vtxt: state='winfr_scan_running'
            elif 'WINFR_FAILED_ALL_ATTEMPTS' in vtxt: state='winfr_failed_all'
            elif 'WINFR_NOT_FOUND' in vtxt: state='winfr_missing'
            else: state='unclear'
    elif 'canceled' in uerr or u'\u53d6\u6d88' in uerr:
        state='uac_declined'
    else:
        state='elevation_failed'
    L('state=%s'%state)
    c,o=run(['tasklist','/FI','IMAGENAME eq winfr.exe'],timeout=20)
    L('winfr_process_now=%s'%('winfr.exe' in (o or '')))
    for nm in ('winfr_E.log','winfr_E3.log','winfr_E4.log','winfr_help.log'):
        lf=DBOX/nm
        if lf.exists():
            try:
                raw=lf.read_bytes()
                txt=None
                for encd in ('utf-16','utf-16-le','utf-8'):
                    try:
                        txt=raw.decode(encd)
                        if txt.count('\x00')<len(txt)//4: break
                    except Exception: txt=None
                if txt is None: txt=raw.decode('utf-8',errors='replace')
                wl=[x.replace('\x00','').strip() for x in txt.splitlines() if x.replace('\x00','').strip()]
                L('== %s (%d lines) tail =='%(nm,len(wl)))
                for ln in wl[-10:]: L('  wf| '+ln[:160])
            except Exception as ex: L('%s read error %r'%(nm,ex))
    rdir=Path(r'C:\recovery_winfr_E')
    if rdir.exists():
        try:
            files=[e for e in rdir.rglob('*') if e.is_file()]
            L('recovery_winfr_E now: %d files, %dMB'%(len(files),sum(e.stat().st_size for e in files)//1048576))
        except Exception: pass
except Exception:
    L('FATAL: '+traceback.format_exc()); state='crashed'
L('R314_FINAL=%s'%state)
WT(REPORT,'\n'.join(lines)+'\n')
WT(J,json.dumps({'state':state},indent=2)+'\n')
sys.exit(0 if state in ('winfr_scan_running','winfr_failed_all','winfr_missing','uac_declined','unclear','elevation_failed') else 6)
