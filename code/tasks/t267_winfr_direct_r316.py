# t267_winfr_direct_r316.py - round 316. DATA RECOVERY phase 12.
# r315: winfr lived ~40s then exited; the cmd-wrapped > redirect never
# updated winfr_E.log (still r314 content) so we never saw WHY it died.
# helper v7: launch winfr DIRECTLY via Start-Process -FilePath with an
# ArgumentList array and NATIVE -RedirectStandardOutput/-RedirectStandardError
# (no cmd parsing at all). Two attempts (wildcard filter, dir filter),
# 60s liveness, read the redirected output on death. UAC via full path.
import os, sys, time, subprocess, json, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R316_WINFR_DIRECT.md'; J=OUT/'r316-winfr-direct.json'
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
Set-Content -Path $out -Value ('== recovery helper v7 started ' + (Get-Date)) -Encoding UTF8
New-Item -ItemType Directory -Force -Path 'C:\recovery_winfr_E' | Out-Null
$wf=Get-Command winfr -ErrorAction SilentlyContinue
if(-not $wf){ $alias=Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winfr.exe'; if(Test-Path $alias){ $wf=$alias } }
if(-not $wf){ Log 'WINFR_NOT_FOUND'; Log ('== recovery helper v7 done ' + (Get-Date)); exit }
$exe=$wf.Source
if(-not $exe){ $exe=$wf.ToString() }
Log ('winfr_exe=' + $exe)
function WinfrAlive{ $p=Get-Process winfr -ErrorAction SilentlyContinue; return ($p -ne $null) }
function DumpTxt($f){
  if(Test-Path $f){
    $t=Get-Content $f -ErrorAction SilentlyContinue | Select-Object -Last 14
    foreach($l in $t){ if($l){ Log ('  out: ' + ($l -replace '\x00','')) } }
  } else { Log ('  (no file ' + $f + ')') }
}
Log 'attempt1: direct start, wildcard filter, /a, native redirect'
$o1='E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_o1.txt'
$e1='E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_err1.txt'
try{
  Start-Process -FilePath $exe -ArgumentList 'E:','C:\recovery_winfr_E','/n','\0mcp-agv-arena-optimized\deskbox-v2\library\*','/a' -WindowStyle Hidden -RedirectStandardOutput $o1 -RedirectStandardError $e1
  Log 'started ok'
}catch{
  Log ('start_error: ' + $_.Exception.Message)
  try{
    Start-Process -FilePath $exe -ArgumentList 'E:','C:\recovery_winfr_E','/n','\0mcp-agv-arena-optimized\deskbox-v2\library\*','/a' -NoNewWindow -RedirectStandardOutput $o1 -RedirectStandardError $e1
    Log 'started ok (NoNewWindow)'
  }catch{ Log ('start_error2: ' + $_.Exception.Message) }
}
Start-Sleep 60
if(WinfrAlive){ Log 'WINFR_SCAN_RUNNING (direct, wildcard, /a)'; Log ('== recovery helper v7 done ' + (Get-Date)); exit }
Log 'attempt1 exited. stdout tail:'
DumpTxt $o1
Log 'attempt1 stderr tail:'
DumpTxt $e1
Log 'attempt2: direct start, dir filter, /a'
$o2='E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_o2.txt'
$e2='E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_err2.txt'
try{
  Start-Process -FilePath $exe -ArgumentList 'E:','C:\recovery_winfr_E','/n','\0mcp-agv-arena-optimized\deskbox-v2\library\','/a' -WindowStyle Hidden -RedirectStandardOutput $o2 -RedirectStandardError $e2
  Log 'started ok'
}catch{ Log ('start_error: ' + $_.Exception.Message) }
Start-Sleep 60
if(WinfrAlive){ Log 'WINFR_SCAN_RUNNING (direct, dir filter, /a)'; Log ('== recovery helper v7 done ' + (Get-Date)); exit }
Log 'attempt2 exited. stdout tail:'
DumpTxt $o2
Log 'attempt2 stderr tail:'
DumpTxt $e2
Log 'WINFR_FAILED_ALL_ATTEMPTS'
Log ('== recovery helper v7 done ' + (Get-Date))
'''
WT(HELPER,helper,'utf-8-sig')
launcher=("$ErrorActionPreference='Stop'; "
          "try{ Start-Process -FilePath '" + PSFULL + "' -Verb RunAs -Wait -WindowStyle Hidden "
          "-ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','" + str(HELPER) + "'; "
          "'ELEVATED_RUN_OK' | Out-File '" + str(UACERR) + "' -Encoding ascii }"
          "catch{ ('ELEVATION_FAILED: ' + $_.Exception.Message) | Out-File '" + str(UACERR) + "' -Encoding utf8 }")
LF=DBOX/'vss_launch_v7.ps1'; WT(LF,launcher)

L('# R316 winfr direct launch with native redirect')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
state='unknown'
try:
    locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
    # diagnostics from r315 leftovers
    for nm in ('winfr_E.log',):
        lf=DBOX/nm
        if lf.exists():
            L('%s mtime=%s'%(nm,time.strftime('%H:%M:%S',time.localtime(lf.stat().st_mtime))))
    rdir=Path(r'C:\recovery_winfr_E')
    if rdir.exists():
        for d in sorted(rdir.iterdir()):
            try: L('recovery subdir %s mtime=%s'%(d.name,time.strftime('%H:%M:%S',time.localtime(d.stat().st_mtime))))
            except Exception: pass
    try: UACERR.unlink()
    except Exception: pass
    L('heads-up popup then UAC')
    msg=("RECOVERY SCAN START: a Windows admin dialog appears in a few "
         "seconds - PLEASE CLICK YES. This run captures the scan output "
         "properly. Nothing is deleted; recovered files go to C:\\recovery_winfr_E.")
    run([PSFULL,'-NoProfile','-Command',
         "(New-Object -ComObject WScript.Shell).Popup('{0}',20,'DeskBox data recovery',64)"\
         .format(msg.replace("'","''"))],timeout=30)
    rc,out=run([PSFULL,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(LF)],timeout=300)
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
            for ln in vls[:150]:
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
    for nm in ('winfr_o1.txt','winfr_err1.txt','winfr_o2.txt','winfr_err2.txt'):
        lf=DBOX/nm
        if lf.exists():
            try:
                raw=lf.read_bytes(); txt=None
                for encd in ('utf-16','utf-16-le','utf-8'):
                    try:
                        txt=raw.decode(encd)
                        if txt.count('\x00')<len(txt)//4: break
                    except Exception: txt=None
                if txt is None: txt=raw.decode('utf-8',errors='replace')
                wl=[x.replace('\x00','').strip() for x in txt.splitlines() if x.replace('\x00','').strip()]
                L('== %s (%d lines) =='%(nm,len(wl)))
                for ln in wl[-14:]: L('  wfx| '+ln[:160])
            except Exception as ex: L('%s read error %r'%(nm,ex))
    if rdir.exists():
        try:
            files=[e for e in rdir.rglob('*') if e.is_file()]
            L('recovery_winfr_E now: %d files, %dMB'%(len(files),sum(e.stat().st_size for e in files)//1048576))
        except Exception: pass
except Exception:
    L('FATAL: '+traceback.format_exc()); state='crashed'
L('R316_FINAL=%s'%state)
WT(REPORT,'\n'.join(lines)+'\n')
WT(J,json.dumps({'state':state},indent=2)+'\n')
sys.exit(0 if state in ('winfr_scan_running','winfr_failed_all','winfr_missing','uac_declined','unclear','elevation_failed_or_timeout') else 6)
