# t273_clean_restart_r322.py - round 322. CLEAN RESTART (one final UAC).
# One hour, three WinFR instances, zero files - mutual interference and/or
# pipe-blocking under hidden windows. helper v10 (elevated, independent):
#  1. kill ALL WinFR processes (clean slate; recovery dir is empty, no
#     half-written results to lose)
#  2. start ONE instance: -WindowStyle Minimized, NO redirects (real
#     console, only minimized - eliminates every blocking suspect)
#  3. monitor for 60 minutes: file count every 60s into vss_out.txt
#  4. verdict: WINFR_DONE files=N MB=M / WINFR_ZERO (exited, nothing) /
#     WINFR_STILL_RUNNING (leave it, next round reads the tally)
# The task: heads-up popup -> full-path UAC -> confirm -> first monitor
# lines -> exit (helper keeps running independently).
import os, sys, time, subprocess, json, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R322_CLEAN_RESTART.md'; J=OUT/'r322-clean-restart.json'
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
Set-Content -Path $out -Value ('== recovery helper v10 (clean restart) started ' + (Get-Date)) -Encoding UTF8
New-Item -ItemType Directory -Force -Path 'C:\recovery_winfr_E' | Out-Null
$wf=Get-Command winfr -ErrorAction SilentlyContinue
if(-not $wf){ $alias=Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winfr.exe'; if(Test-Path $alias){ $wf=$alias } }
if(-not $wf){ Log 'WINFR_NOT_FOUND'; Log ('== helper v10 done ' + (Get-Date)); exit }
$exe=$wf.Source; if(-not $exe){ $exe=$wf.ToString() }
Log ('winfr_exe=' + $exe)
Log 'step1: killing all WinFR instances (clean slate)'
$killed=@(Get-Process WinFR -ErrorAction SilentlyContinue)
foreach($p in $killed){ try{ Stop-Process -Id $p.Id -Force -ErrorAction Stop }catch{} }
Start-Sleep 5
$left=@(Get-Process WinFR -ErrorAction SilentlyContinue)
Log ('killed=' + $killed.Count + ' remaining=' + $left.Count)
function WinfrAlive{ $p=Get-Process WinFR -ErrorAction SilentlyContinue; return ($p -ne $null) }
function CountFiles{ try{ return @(Get-ChildItem 'C:\recovery_winfr_E' -Recurse -File -ErrorAction SilentlyContinue).Count }catch{ return -1 } }
Log 'step2: single instance, minimized visible window, NO redirects'
try{
  Start-Process -FilePath $exe -ArgumentList 'E:','C:\recovery_winfr_E','/n','\0mcp-agv-arena-optimized\deskbox-v2\library\*','/a' -WindowStyle Minimized
  Log 'single instance started (Minimized, no redirect)'
}catch{
  Log ('start_error: ' + $_.Exception.Message)
  Log ('== helper v10 done ' + (Get-Date)); exit
}
Start-Sleep 20
Log ('startup check: alive=' + (WinfrAlive) + ' files=' + (CountFiles))
Log 'step3: monitoring for 60 minutes'
$deadline=(Get-Date).AddMinutes(60)
$t0=Get-Date
while((Get-Date) -lt $deadline){
  Start-Sleep 60
  $el=[int]((Get-Date)-$t0).TotalSeconds
  $n=CountFiles
  Log ('MON2 elapsed=' + $el + 's alive=' + (WinfrAlive) + ' files=' + $n)
  if(-not (WinfrAlive)){
    $n2=CountFiles
    if($n2 -gt 0){
      $mb=0
      try{ $mb=[int]((Get-ChildItem 'C:\recovery_winfr_E' -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum/1MB) }catch{}
      Log ('WINFR_DONE files=' + $n2 + ' MB=' + $mb)
    }else{
      Log 'WINFR_ZERO (winfr exited with no files recovered)'
    }
    Log ('== helper v10 done ' + (Get-Date))
    exit
  }
}
Log ('WINFR_STILL_RUNNING after 60min, files=' + (CountFiles) + ' - leaving it running; next round reads the tally')
Log ('== helper v10 done ' + (Get-Date))
'''
WT(HELPER,helper,'utf-8-sig')
launcher=("$ErrorActionPreference='Stop'; "
          "try{ Start-Process -FilePath '" + PSFULL + "' -Verb RunAs -WindowStyle Hidden "
          "-ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','" + str(HELPER) + "'; "
          "'ELEVATED_RUN_OK' | Out-File '" + str(UACERR) + "' -Encoding ascii }"
          "catch{ ('ELEVATION_FAILED: ' + $_.Exception.Message) | Out-File '" + str(UACERR) + "' -Encoding utf8 }")
LF=DBOX/'vss_launch_v10.ps1'; WT(LF,launcher)

L('# R322 clean restart - single instance, no interference')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
state='unknown'
try:
    locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
    try: UACERR.unlink()
    except Exception: pass
    L('heads-up popup: clean restart, one click')
    msg=("CLEAN RESTART: the three parallel scans interfered with each "
         "other for an hour with zero results. Please CLICK YES on the "
         "admin dialog - this stops them and starts ONE clean scan in a "
         "minimized window. It runs up to 60 minutes fully automatically; "
         "you can keep using the PC. Recovered files go to C:\\recovery_winfr_E.")
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
        L('elevation ok; reading helper v10 startup lines')
        t0=time.time(); state='v10_started'
        while time.time()-t0<120:
            time.sleep(20)
            vtxt=''
            if VSSOUT.exists():
                try: vtxt=VSSOUT.read_text(encoding='utf-8',errors='replace')
                except Exception: pass
            key=[ln for ln in vtxt.splitlines() if ('v10' in ln) or ln.startswith('MON2') or 'killed=' in ln or 'WINFR_' in ln or 'startup check' in ln or 'single instance' in ln or 'start_error' in ln]
            if key:
                for ln in key[-10:]: L('  vss| '+ln[:170])
                if any(ln.startswith('MON2') for ln in key): break
                if any('WINFR_DONE' in ln or 'WINFR_ZERO' in ln or 'WINFR_NOT_FOUND' in ln or 'start_error' in ln for ln in key):
                    state='v10_finished_early'; break
        c,o=run(['tasklist','/FI','IMAGENAME eq WinFR.exe','/FO','CSV'],timeout=20)
        L('winfr_procs_now=%d'%(o or '').lower().count('winfr'))
        rdir=Path(r'C:\recovery_winfr_E')
        if rdir.exists():
            try:
                fs=[e for e in rdir.rglob('*') if e.is_file()]
                L('recovery_winfr_E now: %d files, %dMB'%(len(fs),sum(e.stat().st_size for e in fs)//1048576))
            except Exception: pass
    elif 'canceled' in uerr or u'\u53d6\u6d88' in uerr:
        state='uac_declined'
    else:
        state='elevation_failed'
    L('state=%s'%state)
except Exception:
    L('FATAL: '+traceback.format_exc()); state='crashed'
L('R322_FINAL=%s'%state)
L('NEXT: r323 reads MON2 lines / WINFR_DONE / WINFR_ZERO after the 60-minute window.')
WT(REPORT,'\n'.join(lines)+'\n')
WT(J,json.dumps({'state':state},indent=2)+'\n')
sys.exit(0 if state in ('v10_started','v10_finished_early','uac_declined','elevation_failed') else 6)
