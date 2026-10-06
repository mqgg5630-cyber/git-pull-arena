# t269_trigger_oneshot_r318.py - round 318. USER IS PRESENT AND ASKED FOR
# THE TRIGGER. Re-arm helper v8 (identical content, defensive rewrite),
# heads-up popup, full-path UAC trigger (launcher WITHOUT -Wait so helper
# v8 runs independently), verify ELEVATED_RUN_OK, read the first monitor
# lines, confirm the winfr process, report monitor_started.
import os, sys, time, subprocess, json, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R318_TRIGGER_ONESHOT.md'; J=OUT/'r318-trigger-oneshot.json'
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
Set-Content -Path $out -Value ('== recovery helper v8 (one-shot monitor) started ' + (Get-Date)) -Encoding UTF8
New-Item -ItemType Directory -Force -Path 'C:\recovery_winfr_E' | Out-Null
$wf=Get-Command winfr -ErrorAction SilentlyContinue
if(-not $wf){ $alias=Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winfr.exe'; if(Test-Path $alias){ $wf=$alias } }
if(-not $wf){ Log 'WINFR_NOT_FOUND'; Log ('== helper v8 done ' + (Get-Date)); exit }
$exe=$wf.Source; if(-not $exe){ $exe=$wf.ToString() }
Log ('winfr_exe=' + $exe)
$deadline=(Get-Date).AddMinutes(40)
function WinfrAlive{ $p=Get-Process winfr -ErrorAction SilentlyContinue; return ($p -ne $null) }
function CountFiles{ try{ return @(Get-ChildItem 'C:\recovery_winfr_E' -Recurse -File -ErrorAction SilentlyContinue).Count }catch{ return -1 } }
function DumpTxt($f){
  if(Test-Path $f){
    $t=Get-Content $f -ErrorAction SilentlyContinue | Select-Object -Last 14
    foreach($l in $t){ if($l){ Log ('  out: ' + ($l -replace '\x00','')) } }
  } else { Log ('  (no file ' + $f + ')') }
}
function RunVariant($tag,$filter){
  $o='E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_' + $tag + '_o.txt'
  $e='E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_' + $tag + '_e.txt'
  Log ('VARIANT ' + $tag + ' filter=' + $filter)
  try{
    Start-Process -FilePath $exe -ArgumentList 'E:','C:\recovery_winfr_E','/n',$filter,'/a' -WindowStyle Hidden -RedirectStandardOutput $o -RedirectStandardError $e
    Log ('started ' + $tag)
  }catch{
    Log ('start_error ' + $tag + ': ' + $_.Exception.Message)
    try{
      Start-Process -FilePath $exe -ArgumentList 'E:','C:\recovery_winfr_E','/n',$filter,'/a' -NoNewWindow -RedirectStandardOutput $o -RedirectStandardError $e
      Log ('started ' + $tag + ' (NoNewWindow)')
    }catch{ Log ('start_error2 ' + $tag + ': ' + $_.Exception.Message); return $false }
  }
  $t0=Get-Date
  while((Get-Date) -lt $deadline){
    Start-Sleep 30
    $el=[int]((Get-Date)-$t0).TotalSeconds
    $n=CountFiles
    Log ('MONITOR ' + $tag + ' elapsed=' + $el + 's alive=' + (WinfrAlive) + ' files=' + $n)
    if(-not (WinfrAlive)){
      Log ('VARIANT ' + $tag + ' exited after ' + $el + 's; stdout tail:')
      DumpTxt $o
      Log ('VARIANT ' + $tag + ' stderr tail:')
      DumpTxt $e
      return ($n -gt 0)
    }
    if($n -gt 200000){ Log 'recovered over 200k files - stopping monitor early to avoid runaway'; return $true }
  }
  Log ('deadline reached with winfr still alive - leaving it running, monitor ends')
  return $true
}
$r1=RunVariant 'v1' '\0mcp-agv-arena-optimized\deskbox-v2\library\*'
if(-not $r1 -and (Get-Date) -lt $deadline){ $r2=RunVariant 'v2' '\0mcp-agv-arena-optimized\deskbox-v2\library\' } else { $r2=$true }
if(-not $r2 -and (Get-Date) -lt $deadline){ $r3=RunVariant 'v3' '\0mcp-agv-arena-optimized\' } else { $r3=$true }
$n=CountFiles
$mb=0
try{ $mb=[int]((Get-ChildItem 'C:\recovery_winfr_E' -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum/1MB) }catch{}
if($n -gt 0){
  Log ('WINFR_DONE files=' + $n + ' MB=' + $mb)
}else{
  Log 'WINFR_FAILED_ALL'
}
Log ('== helper v8 done ' + (Get-Date))
'''
WT(HELPER,helper,'utf-8-sig')
launcher=("$ErrorActionPreference='Stop'; "
          "try{ Start-Process -FilePath '" + PSFULL + "' -Verb RunAs -WindowStyle Hidden "
          "-ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','" + str(HELPER) + "'; "
          "'ELEVATED_RUN_OK' | Out-File '" + str(UACERR) + "' -Encoding ascii }"
          "catch{ ('ELEVATION_FAILED: ' + $_.Exception.Message) | Out-File '" + str(UACERR) + "' -Encoding utf8 }")
LF=DBOX/'vss_launch_v8.ps1'; WT(LF,launcher)

L('# R318 user-present trigger of the one-shot recovery')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
state='unknown'
try:
    locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
    try: UACERR.unlink()
    except Exception: pass
    L('heads-up popup: click YES when the admin dialog appears')
    msg=("CLICK YES NOW: the Windows admin dialog appears in a few seconds. "
         "One click and everything runs automatically - scan, monitoring, "
         "retries, and the final report. Recovered files go to "
         "C:\\recovery_winfr_E. Nothing is deleted.")
    run([PSFULL,'-NoProfile','-Command',
         "(New-Object -ComObject WScript.Shell).Popup('{0}',15,'DeskBox data recovery',64)"\
         .format(msg.replace("'","''"))],timeout=25)
    rc,out=run([PSFULL,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(LF)],timeout=150)
    L('launcher_rc=%s'%rc)
    uerr=''
    if UACERR.exists():
        try: uerr=UACERR.read_text(encoding='utf-8',errors='replace').strip()
        except Exception: pass
    L('uac_err=%s'%uerr[:160])
    if '?' in uerr:
        L('uac_raw=%s'%uerr.encode('unicode_escape').decode('ascii')[:300])
    if 'ELEVATED_RUN_OK' in uerr:
        L('ELEVATION OK - helper v8 running independently; reading first monitor lines')
        t0=time.time(); state='monitor_started'
        while time.time()-t0<150:
            time.sleep(20)
            if VSSOUT.exists():
                try: vtxt=VSSOUT.read_text(encoding='utf-8',errors='replace')
                except Exception: vtxt=''
                mon=[ln for ln in vtxt.splitlines() if ln.startswith('MONITOR') or ln.startswith('VARIANT') or 'WINFR_' in ln or 'start_error' in ln or 'helper v8 done' in ln]
                if mon:
                    for ln in mon[-12:]: L('  vss| '+ln[:170])
                    if 'WINFR_DONE' in vtxt or 'WINFR_FAILED_ALL' in vtxt or 'helper v8 done' in vtxt:
                        state='helper_already_done'; break
                    if any(ln.startswith('MONITOR') for ln in mon): break
        c,o=run(['tasklist','/FI','IMAGENAME eq winfr.exe'],timeout=20)
        L('winfr_process=%s'%('winfr.exe' in (o or '')))
        rdir=Path(r'C:\recovery_winfr_E')
        if rdir.exists():
            try:
                files=[e for e in rdir.rglob('*') if e.is_file()]
                L('recovery_winfr_E now: %d files, %dMB'%(len(files),sum(e.stat().st_size for e in files)//1048576))
            except Exception: pass
    elif 'canceled' in uerr or u'\u53d6\u6d88' in uerr:
        state='uac_declined'
    else:
        state='elevation_failed'
    L('state=%s'%state)
except Exception:
    L('FATAL: '+traceback.format_exc()); state='crashed'
L('R318_FINAL=%s'%state)
L('NEXT: r319 waits for WINFR_DONE / WINFR_FAILED_ALL and reports the tally.')
WT(REPORT,'\n'.join(lines)+'\n')
WT(J,json.dumps({'state':state},indent=2)+'\n')
sys.exit(0 if state in ('monitor_started','helper_already_done','uac_declined','elevation_failed') else 6)
