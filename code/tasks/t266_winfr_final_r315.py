# t266_winfr_final_r315.py - round 315. DATA RECOVERY phase 11 (final form).
# r314 captured this vintage winfr's REAL switch table: there is no /y and
# no /regular - it uses /a (accept all prompts), default mode "Regular".
# r314 also hung because cmd /c waited synchronously on winfr's y/n prompt.
# helper v6: start winfr in the BACKGROUND with /a (no prompt, no pipe):
#   attempt1: winfr E: dest /n \0mcp-agv-arena-optimized\deskbox-v2\library\* /a
#   attempt2 (if 1 dies): same with trailing-backslash dir filter
# 40s liveness checks, log tails, verdict. UAC via the proven full-path
# trigger. Recovery output to C:\ only. Nothing deleted.
import os, sys, time, subprocess, json, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R315_WINFR_FINAL.md'; J=OUT/'r315-winfr-final.json'
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
Set-Content -Path $out -Value ('== recovery helper v6 started ' + (Get-Date)) -Encoding UTF8
New-Item -ItemType Directory -Force -Path 'C:\recovery_winfr_E' | Out-Null
$wf=Get-Command winfr -ErrorAction SilentlyContinue
if(-not $wf){ $alias=Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winfr.exe'; if(Test-Path $alias){ $wf=$alias } }
if(-not $wf){ Log 'WINFR_NOT_FOUND'; Log ('== recovery helper v6 done ' + (Get-Date)); exit }
function WinfrAlive{ $p=Get-Process winfr -ErrorAction SilentlyContinue; return ($p -ne $null) }
function DumpLog($f){
  if(Test-Path $f){
    $t=Get-Content $f -ErrorAction SilentlyContinue | Select-Object -Last 10
    foreach($l in $t){ Log ('  wflog: ' + ($l -replace '\x00','')) }
  }
}
Log 'attempt1: winfr E: /n wildcard /a (background)'
Start-Process cmd -ArgumentList '/c winfr E: "C:\recovery_winfr_E" /n \0mcp-agv-arena-optimized\deskbox-v2\library\* /a > E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_E.log 2>&1' -WindowStyle Hidden
Start-Sleep 40
if(WinfrAlive){ Log 'WINFR_SCAN_RUNNING (mode=/n wildcard, /a autoprompts)'; Log ('== recovery helper v6 done ' + (Get-Date)); exit }
Log 'attempt1 exited - log tail:'
DumpLog 'E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_E.log'
Log 'attempt2: dir-filter variant'
Start-Process cmd -ArgumentList '/c winfr E: "C:\recovery_winfr_E" /n \0mcp-agv-arena-optimized\deskbox-v2\library\ /a > E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_E5.log 2>&1' -WindowStyle Hidden
Start-Sleep 40
if(WinfrAlive){ Log 'WINFR_SCAN_RUNNING (dir filter, /a autoprompts)'; Log ('== recovery helper v6 done ' + (Get-Date)); exit }
Log 'attempt2 exited - log tail:'
DumpLog 'E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_E5.log'
Log 'WINFR_FAILED_ALL_ATTEMPTS'
Log ('== recovery helper v6 done ' + (Get-Date))
'''
WT(HELPER,helper,'utf-8-sig')
launcher=("$ErrorActionPreference='Stop'; "
          "try{ Start-Process -FilePath '" + PSFULL + "' -Verb RunAs -Wait -WindowStyle Hidden "
          "-ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','" + str(HELPER) + "'; "
          "'ELEVATED_RUN_OK' | Out-File '" + str(UACERR) + "' -Encoding ascii }"
          "catch{ ('ELEVATION_FAILED: ' + $_.Exception.Message) | Out-File '" + str(UACERR) + "' -Encoding utf8 }")
LF=DBOX/'vss_launch_v6.ps1'; WT(LF,launcher)

L('# R315 winfr final form (/a autoprompts, background)')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
state='unknown'
try:
    locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
    try: UACERR.unlink()
    except Exception: pass
    L('heads-up popup: permission request coming, click Yes')
    msg=("FINAL RUN: a Windows admin dialog appears in a few seconds - "
         "PLEASE CLICK YES. The recovery scan starts immediately in the "
         "background (10-30 min). You can keep using the PC. Nothing is "
         "deleted; recovered files go to C:\\recovery_winfr_E.")
    run([PSFULL,'-NoProfile','-Command',
         "(New-Object -ComObject WScript.Shell).Popup('{0}',20,'DeskBox data recovery',64)"\
         .format(msg.replace("'","''"))],timeout=30)
    rc,out=run([PSFULL,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(LF)],timeout=280)
    L('launcher_rc=%s'%rc)
    uerr=''
    if UACERR.exists():
        try: uerr=UACERR.read_text(encoding='utf-8',errors='replace').strip()
        except Exception: pass
    L('uac_err=%s'%uerr[:160])
    if 'ELEVATED_RUN_OK' in uerr:
        time.sleep(6)
        if VSSOUT.exists():
            vtxt=VSSOUT.read_text(encoding='utf-8',errors='replace')
            vls=vtxt.splitlines()
            L('== vss_out.txt (%d lines) =='%len(vls))
            for ln in vls[:120]:
                L('  vss| '+ln[:170])
                if '?' in ln: L('  raw| '+ln.encode('unicode_escape').decode('ascii')[:260])
            if 'WINFR_SCAN_RUNNING' in vtxt: state='winfr_scan_running'
            elif 'WINFR_FAILED_ALL_ATTEMPTS' in vtxt: state='winfr_failed_all'
            elif 'WINFR_NOT_FOUND' in vtxt: state='winfr_missing'
            else: state='unclear'
    elif 'canceled' in uerr or u'\u53d6\u6d88' in uerr:
        state='uac_declined'
    else:
        state='elevation_failed_or_timeout'
    L('state=%s'%state)
    c,o=run(['tasklist','/FI','IMAGENAME eq winfr.exe'],timeout=20)
    L('winfr_process_now=%s'%('winfr.exe' in (o or '')))
    for nm in ('winfr_E.log','winfr_E5.log'):
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
L('R315_FINAL=%s'%state)
WT(REPORT,'\n'.join(lines)+'\n')
WT(J,json.dumps({'state':state},indent=2)+'\n')
sys.exit(0 if state in ('winfr_scan_running','winfr_failed_all','winfr_missing','uac_declined','unclear','elevation_failed_or_timeout') else 6)
