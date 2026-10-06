# t260_recovery_winfr_r309.py - round 309. DATA RECOVERY phase 6.
# r308: the user ran the desktop bat successfully! Verdict: shadow_count=0
# (no VSS on this machine, that path is closed), D+E are NTFS (good -
# filename-preserving recovery possible), but the winget install of winfr
# failed (error text was Chinese and got mangled; likely the old winget
# does not know --disable-interactivity).
# This round: rewrite the elevated helper with a fixed installer
# (winget version log + attempt via winget source + attempt via msstore
# source, no --disable-interactivity, full UTF-8 output into vss_out.txt),
# ask the user to double-click the SAME bat again, poll, and report the
# real winget errors via unicode_escape. Recovery still goes to C:\ only.
import os, sys, time, subprocess, json, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R309_RECOVERY_WINFR.md'; J=OUT/'r309-recovery-winfr.json'
DBOX=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
HELPER=DBOX/'vss_helper.ps1'; VSSOUT=DBOX/'vss_out.txt'; WFLOG=DBOX/'winfr_E.log'
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

# ---- helper v3: fixed winfr installer, keeps a quick VSS re-check first
helper=r'''
$ErrorActionPreference='Continue'
$out='E:\0mcp-agv-arena-optimized\deskbox-v2\vss_out.txt'
function Log($s){ Add-Content -Path $out -Value $s -Encoding UTF8 }
Set-Content -Path $out -Value ('== recovery helper v3 started ' + (Get-Date)) -Encoding UTF8
$shadows=@()
try{ $shadows=@(Get-CimInstance Win32_ShadowCopy -ErrorAction Stop) }catch{ Log ('cim_error ' + $_.Exception.Message) }
Log ('shadow_count=' + $shadows.Count)
if($shadows.Count -gt 0){
  $linkRoot='C:\vss_links'; New-Item -ItemType Directory -Force -Path $linkRoot | Out-Null
  $idx=0; $best=$null
  foreach($s in $shadows){
    $idx++
    $dev=$s.DeviceObject
    Log ('shadow ' + $idx + ' created=' + $s.InstallDate + ' dev=' + $dev)
    $link=Join-Path $linkRoot ('s' + $idx)
    if(Test-Path $link){ cmd /c rmdir $link | Out-Null }
    cmd /c mklink /d $link ($dev + '\') | Out-Null
    if(-not (Test-Path $link)){ Log ('  link_fail'); continue }
    foreach($t in @('DeskBoxLibrary','0mcp-agv-arena-optimized\deskbox-v2\library')){
      $p=Join-Path $link $t
      if(Test-Path $p){
        $subs=@(Get-ChildItem $p -Directory -ErrorAction SilentlyContinue)
        Log ('  HIT ' + $t + ' subdirs=' + $subs.Count)
        $n9=0
        foreach($n in @('01-Apps-Shortcuts','02-Job-Tools','03-Video-Creation','04-Images-ID-Photos','05-Documents','06-Archives-Installers','07-Old-Folders','08-Misc','09-Anime-Wallpapers')){
          if(Test-Path (Join-Path $p $n)){ $n9++ }
        }
        Log ('  nine_cat_count=' + $n9)
        if($n9 -gt 0 -and ($best -eq $null -or $n9 -gt $best.n9)){ $best=@{path=$p; n9=$n9; shadow=$idx} }
      }
    }
  }
  if($best -ne $null){
    $dest='C:\recovery_vss\DeskBoxLibrary'
    Log ('RECOVERY_START shadow=' + $best.shadow + ' nine=' + $best.n9 + ' dest=' + $dest)
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
    Start-Process robocopy -ArgumentList ('"{0}" "{1}" /E /COPY:DAT /DCOPY:T /R:1 /W:1 /LOG:"E:\0mcp-agv-arena-optimized\deskbox-v2\recovery_robocopy.log"' -f $best.path,$dest) -WindowStyle Hidden
    Log ('robocopy launched (background, COPY mode only)')
    Log ('== recovery helper v3 done ' + (Get-Date))
    exit
  }
  Log 'NO_NINE_CAT_IN_SHADOWS'
}else{
  Log 'NO_SHADOWS_AT_ALL'
}
$fsE=''; try{ $fsE=(Get-Volume -DriveLetter E -ErrorAction Stop).FileSystemType }catch{}
$fsD=''; try{ $fsD=(Get-Volume -DriveLetter D -ErrorAction Stop).FileSystemType }catch{}
Log ('fs E=' + $fsE + ' D=' + $fsD)
$wf=Get-Command winfr -ErrorAction SilentlyContinue
if(-not $wf){ $alias=Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winfr.exe'; if(Test-Path $alias){ $wf=$alias } }
if(-not $wf){ $pf='C:\Program Files\Windows File Recovery\winfr.exe'; if(Test-Path $pf){ $wf=$pf } }
if(-not $wf){
  Log 'winget_version:'
  try{ $v=winget --version 2>&1 | Out-String; Log ('wgver: ' + $v.Trim()) }catch{ Log ('wgver_error ' + $_.Exception.Message) }
  Log 'winfr_install_attempt1 (winget source):'
  try{ $o1=winget install --id Microsoft.WindowsFileRecovery --source winget --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-String; Log ('wg1: ' + $o1.Trim()) }catch{ Log ('wg1_error ' + $_.Exception.Message) }
  $wf=Get-Command winfr -ErrorAction SilentlyContinue
  if(-not $wf){ $alias=Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winfr.exe'; if(Test-Path $alias){ $wf=$alias } }
}
if(-not $wf){
  Log 'winfr_install_attempt2 (msstore source):'
  try{ $o2=winget install --id 9N26S50LN705 --source msstore --accept-package-agreements --accept-source-agreements 2>&1 | Out-String; Log ('wg2: ' + $o2.Trim()) }catch{ Log ('wg2_error ' + $_.Exception.Message) }
  $wf=Get-Command winfr -ErrorAction SilentlyContinue
  if(-not $wf){ $alias=Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winfr.exe'; if(Test-Path $alias){ $wf=$alias } }
  if(-not $wf){ $pf='C:\Program Files\Windows File Recovery\winfr.exe'; if(Test-Path $pf){ $wf=$pf } }
}
if($wf){
  $mode='/regular'; if($fsE -ne 'NTFS'){ $mode='/extensive' }
  $dest='C:\recovery_winfr_E'
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  Log ('WINFR_START E: -> ' + $dest + ' ' + $mode + ' (filter: old library path)')
  Start-Process cmd -ArgumentList ('/c winfr E: "{0}" {1} /n \0mcp-agv-arena-optimized\deskbox-v2\library\* /y > E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_E.log 2>&1' -f $dest,$mode) -WindowStyle Hidden
  Log 'winfr launched (background, from E: deletion scene, output to C:)'
}else{
  Log 'WINFR_INSTALL_FAILED (see wg1/wg2 output above)'
}
Log ('== recovery helper v3 done ' + (Get-Date))
'''
WT(HELPER,helper,'utf-8-sig')

L('# R309 DATA RECOVERY phase 6 - fixed winfr installer')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
data_found='unknown'
try:
    locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
    DESK=real_desktop(); L('real_desktop='+str(DESK))
    BAT=DESK/'RECOVERY-recover-data.bat'
    L('bat_present=%s helper_v3_written=%s (%dB)'%(BAT.exists(),HELPER.exists(),HELPER.stat().st_size))
    mtime0=VSSOUT.stat().st_mtime if VSSOUT.exists() else 0
    L('old_vss_out_mtime=%s'%time.strftime('%H:%M:%S',time.localtime(mtime0)))

    L('showing instruction popup (please double-click the bat AGAIN)')
    msg=("FIX INSTALLED: please DOUBLE-CLICK 'RECOVERY-recover-data.bat' on the "
         "desktop ONE MORE TIME and click YES. This run installs Microsoft's "
         "recovery tool properly and starts the 20GB scan of the E: drive. "
         "Nothing is deleted; recovered files go to C:\\recovery_winfr_E.")
    run(['powershell','-NoProfile','-Command',
         "(New-Object -ComObject WScript.Shell).Popup('{0}',45,'DeskBox data recovery',64)"\
         .format(msg.replace("'","''"))],timeout=55)
    L('polling vss_out.txt (fresh mtime) for up to 600s...')
    t0=time.time(); vtxt=None; fresh=False
    while time.time()-t0<600:
        time.sleep(15)
        if VSSOUT.exists() and VSSOUT.stat().st_mtime>t0:
            try: vtxt=VSSOUT.read_text(encoding='utf-8',errors='replace'); fresh=True
            except Exception: pass
        if fresh and (('WINFR_START' in vtxt) or ('WINFR_INSTALL_FAILED' in vtxt) or ('RECOVERY_START' in vtxt) or ('== recovery helper v3 done' in vtxt)):
            L('fresh helper output after %ds'%(int(time.time()-t0))); break
        el=int(time.time()-t0)
        if el==300:
            run(['powershell','-NoProfile','-Command',
                 "(New-Object -ComObject WScript.Shell).Popup('{0}',60,'DeskBox data recovery',64)"\
                 .format("REMINDER: double-click RECOVERY-recover-data.bat once more and click YES - it now installs the recovery tool and scans E:.".replace("'","''"))],timeout=70)
            L('reminder popup at 300s')
    if vtxt and fresh:
        vls=vtxt.splitlines()
        L('== fresh vss_out.txt (%d lines) =='%len(vls))
        for ln in vls[:90]:
            L('  vss| '+ln[:170])
            if '?' in ln:
                L('  raw| '+ln.encode('unicode_escape').decode('ascii')[:220])
        if 'RECOVERY_START' in vtxt: data_found='recovering_vss'
        elif 'WINFR_START' in vtxt: data_found='winfr_running'
        elif 'WINFR_INSTALL_FAILED' in vtxt: data_found='winfr_install_failed'
        elif 'shadow_count=0' in vtxt or 'NO_SHADOWS_AT_ALL' in vtxt: data_found='no_shadows'
        else: data_found='helper_ran_unclear'
    else:
        L('no fresh helper output within 600s')
        data_found='awaiting_user_doubleclick'
    L('data_found=%s'%data_found)
    if data_found=='winfr_running':
        if WFLOG.exists():
            try: L('winfr_log_tail=%s'%' | '.join(WFLOG.read_text(encoding='utf-8',errors='replace').splitlines()[-6:])[:500])
            except Exception as ex: L('winfr log read error %r'%ex)
        else: L('winfr_log not yet created (just started)')
    rdir=Path(r'C:\recovery_winfr_E')
    if rdir.exists():
        try: L('recovery_winfr_E entries=%d'%len(list(rdir.iterdir())))
        except Exception: pass
except Exception:
    L('FATAL: '+traceback.format_exc()); data_found='crashed'
WT(REPORT,'\n'.join(lines)+'\n')
WT(J,json.dumps({'dataFound':data_found},indent=2)+'\n')
sys.exit(0 if data_found in ('recovering_vss','winfr_running','winfr_install_failed','no_shadows','helper_ran_unclear') else 6)
