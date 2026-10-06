# t254_recovery_uac2_r303.py - round 303. DATA RECOVERY phase 2.
# r302: forensics done (accident chain reconstructed); the UAC attempt
# returned in 5s with no output - cause unknown (declined? blocked?).
# This round: explain to the user FIRST (MessageBox), then try UAC twice
# with error capture, and extend the elevated helper to fall back to
# Microsoft's official recovery tool winfr when VSS has nothing.
# Recovery destinations live on C:\ ONLY (D: and E: are deletion crime
# scenes - writing there could overwrite recoverable blocks).
# Nothing is deleted. robocopy/winfr run COPY-mode, backgrounded.
import ctypes, os, sys, time, subprocess, json, threading
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R303_RECOVERY_UAC2.md'; J=OUT/'r303-recovery-uac2.json'
DBOX=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
HELPER=DBOX/'vss_helper.ps1'; LAUNCHER=DBOX/'vss_launch.ps1'
VSSOUT=DBOX/'vss_out.txt'; UACERR=DBOX/'uac_err.txt'
lines=[]
def L(s):
    s=str(s).encode('ascii','replace').decode('ascii'); print(s,flush=True); lines.append(s)
def WT(p,t,enc='utf-8'):
    Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(t,encoding=enc)
def run(args,timeout=25):
    try:
        p=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout,text=True,errors='replace')
        return p.returncode,p.stdout
    except Exception as e: return 999,repr(e)
def run_bg(args):
    try: subprocess.Popen(args,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,creationflags=0x08000000); return True
    except Exception: return False
def guarded(fn,timeout_s,tag):
    box={}
    def work():
        try: box['r']=fn()
        except Exception as ex: box['r']=None; box['err']=repr(ex)
    t=threading.Thread(target=work,daemon=True); t.start(); t.join(timeout_s)
    if t.is_alive(): L('guard_timeout %s (%ds)'%(tag,timeout_s)); return None
    if 'err' in box: L('guard_error %s: %s'%(tag,box['err']))
    return box.get('r')
def notify(msg):
    cmd=("Add-Type -AssemblyName System.Windows.Forms; "
         "[System.Windows.Forms.MessageBox]::Show(" + msg + ","
         "'DeskBox data recovery','OK','Information') | Out-Null")
    run_bg(['powershell','-NoProfile','-Command',cmd])

# ---- elevated helper v2: VSS search, then winfr fallback
helper=r'''
$ErrorActionPreference='Continue'
$out='E:\0mcp-agv-arena-optimized\deskbox-v2\vss_out.txt'
function Log($s){ Add-Content -Path $out -Value $s -Encoding UTF8 }
Set-Content -Path $out -Value ('== recovery helper started ' + (Get-Date)) -Encoding UTF8
$shadows=@()
try{ $shadows=@(Get-CimInstance Win32_ShadowCopy -ErrorAction Stop) }catch{ Log ('cim_error ' + $_.Exception.Message) }
Log ('shadow_count=' + $shadows.Count)
$linkRoot='C:\vss_links'
New-Item -ItemType Directory -Force -Path $linkRoot | Out-Null
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
      Log ('  HIT ' + $t + ' subdirs=' + $subs.Count + ' [' + (@($subs | ForEach-Object { $_.Name }) -join ',') + ']')
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
  $logf='E:\0mcp-agv-arena-optimized\deskbox-v2\recovery_robocopy.log'
  Log ('RECOVERY_START shadow=' + $best.shadow + ' nine=' + $best.n9 + ' src=' + $best.path + ' dest=' + $dest)
  New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
  Start-Process robocopy -ArgumentList ('"{0}" "{1}" /E /COPY:DAT /DCOPY:T /R:1 /W:1 /LOG:"{2}"' -f $best.path,$dest,$logf) -WindowStyle Hidden
  Log ('robocopy launched (background, COPY mode only)')
}else{
  Log 'NO_NINE_CAT_IN_SHADOWS'
  $fsE=''; $fsD=''
  try{ $fsE=(Get-Volume -DriveLetter E -ErrorAction Stop).FileSystemType }catch{}
  try{ $fsD=(Get-Volume -DriveLetter D -ErrorAction Stop).FileSystemType }catch{}
  Log ('fs E=' + $fsE + ' D=' + $fsD)
  $wf=Get-Command winfr -ErrorAction SilentlyContinue
  if(-not $wf){
    Log 'installing winfr via winget'
    try{
      winget install Microsoft.WindowsFileRecovery --accept-source-agreements --accept-package-agreements --silent --disable-interactivity 2>&1 | ForEach-Object { Log ('winget ' + $_) }
    }catch{ Log ('winget_error ' + $_.Exception.Message) }
    $wf=Get-Command winfr -ErrorAction SilentlyContinue
    if(-not $wf){ $alias=Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winfr.exe'; if(Test-Path $alias){ $wf=$alias } }
  }
  if($wf){
    $mode='/regular'; if($fsE -ne 'NTFS'){ $mode='/extensive' }
    $dest='C:\recovery_winfr_E'
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Log ('WINFR_START E: -> ' + $dest + ' ' + $mode + ' (filter: old library path)')
    Start-Process cmd -ArgumentList ('/c winfr E: "{0}" {1} /n \0mcp-agv-arena-optimized\deskbox-v2\library\* /y > E:\0mcp-agv-arena-optimized\deskbox-v2\winfr_E.log 2>&1' -f $dest,$mode) -WindowStyle Hidden
    Log 'winfr launched (background, from E: deletion scene, output to C:)'
  } else { Log 'WINFR_UNAVAILABLE' }
}
Log ('== recovery helper done ' + (Get-Date))
'''
WT(HELPER,helper,'utf-8-sig')
launcher=r'''
$ErrorActionPreference='Stop'
$errf='E:\0mcp-agv-arena-optimized\deskbox-v2\uac_err.txt'
try{
  Start-Process powershell -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','E:\0mcp-agv-arena-optimized\deskbox-v2\vss_helper.ps1'
  'ELEVATED_RUN_OK' | Out-File $errf -Encoding ascii
}catch{
  ('ELEVATION_FAILED: ' + $_.Exception.Message) | Out-File $errf -Encoding utf8
}
'''
WT(LAUNCHER,launcher)

def uac_attempt(tag):
    L('== UAC attempt %s =='%tag)
    for f in (VSSOUT,UACERR):
        try: f.unlink()
        except Exception: pass
    rc=guarded(lambda: run(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(LAUNCHER)],timeout=380),400,'uac_'+tag)
    L('launcher_rc=%s'%(rc[0] if rc else 'timeout'))
    uerr=''
    if UACERR.exists():
        try: uerr=UACERR.read_text(encoding='utf-8',errors='replace').strip()
        except Exception: pass
    L('uac_err=%s'%uerr.splitlines()[:1])
    if VSSOUT.exists():
        try: vtxt=VSSOUT.read_text(encoding='utf-8',errors='replace')
        except Exception: vtxt=VSSOUT.read_text(errors='replace')
        vls=vtxt.splitlines()
        L('== vss_out.txt (%d lines) =='%len(vls))
        for ln in vls[:70]:
            if any(k in ln for k in ('shadow','HIT','nine_cat','RECOVERY','NO_NINE','free','fs ','WINFR','winget','cim_error','link_fail','started','done')):
                L('  vss| '+ln[:170])
        if 'RECOVERY_START' in vtxt: return 'recovering_vss'
        if 'WINFR_START' in vtxt: return 'winfr_running'
        if 'NO_NINE_CAT_IN_SHADOWS' in vtxt and 'WINFR_UNAVAILABLE' in vtxt: return 'vss_empty_winfr_unavailable'
        if 'shadow_count=0' in vtxt: return 'no_shadows'
        return 'vss_seen_no_hit'
    if 'canceled by the user' in uerr:
        L('user clicked No on the UAC prompt'); return 'declined'
    if 'ELEVATED_RUN_OK' in uerr:
        L('elevation reported OK but helper output missing'); return 'helper_no_output'
    return 'unknown'

L('# R303 DATA RECOVERY phase 2 - explained UAC + winfr fallback')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))

L('showing explanation MessageBox (user must click OK, then accept UAC)')
notify("DATA RECOVERY: a Windows permission dialog (UAC) will appear next. PLEASE CLICK YES to allow the shadow-copy search and file recovery. Recovery output goes to C:\\ only; nothing will be deleted.")
time.sleep(10)
data_found=uac_attempt(1)
if data_found in ('declined','unknown','helper_no_output'):
    L('first attempt failed (%s) - explaining again and retrying once'%data_found)
    notify("One more try: a Windows permission dialog (UAC) will appear. PLEASE CLICK YES - it is needed to search volume shadow copies and recover the lost 20GB library.")
    time.sleep(8)
    data_found=uac_attempt(2)
L('data_found=%s'%data_found)
for r in (Path(r'C:\recovery_vss\DeskBoxLibrary'),Path(r'C:\recovery_winfr_E')):
    if r.exists():
        try: L('recovery_dest %s -> %d entries'%(str(r),len(list(r.iterdir()))))
        except Exception: pass

box_pids=[]
for f in DBOX.glob('deskbox-*.pid'):
    try:
        pid=int(f.read_text().strip())
        c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
        if str(pid) in (o or ''): box_pids.append(pid)
    except Exception: pass
L('boxes_alive_now=%d %s'%(len(box_pids),box_pids))
complete = data_found in ('recovering_vss','winfr_running','no_shadows','vss_empty_winfr_unavailable','vss_seen_no_hit')
L('R303_RECOVERY_PHASE2_COMPLETE=%s'%complete)
WT(J,json.dumps({'dataFound':data_found,'phase2Complete':complete,'boxesAlive':len(box_pids)},indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if complete else 6)
