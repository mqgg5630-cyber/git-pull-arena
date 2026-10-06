# t253_recovery_vss_r302.py - round 302. DATA RECOVERY (user-ordered).
# Facts: r292 renamed organizer->D:\DeskBoxLibrary (verified complete) then
# rmdir'd the 20GB E: copy. The nine categories vanished from
# D:\DeskBoxLibrary between 17:33 and 17:41 (no task was running). All
# deletions were fast (rmdir/rename), so disk blocks are likely intact.
# Plan:
#  A. no-elevation forensics: library dir mtimes, full $RECYCLE.BIN scan of
#     D:+E: with $I index parsing (original paths + deletion times!),
#     wallpapers pack census, free space.
#  B. elevated via UAC (user must click Yes): enumerate VSS shadow copies,
#     link them, look for the nine-category library inside, and if found
#     start a BACKGROUND robocopy (COPY only, never /MOVE) to a recovery dir.
#  C. honest data_found verdict. Nothing is deleted by this task.
import ctypes, os, sys, time, subprocess, json, threading, datetime
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R302_RECOVERY_VSS.md'; J=OUT/'r302-recovery-vss.json'
DBOX=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
WALL=Path(r'E:\0mcp-agv-arena-optimized\wallpapers')
LIB_D=Path(r'D:\DeskBoxLibrary')
HELPER=DBOX/'vss_helper.ps1'; LAUNCHER=DBOX/'vss_launch.ps1'; VSSOUT=DBOX/'vss_out.txt'
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
def guarded(fn,timeout_s,tag):
    box={}
    def work():
        try: box['r']=fn()
        except Exception as ex: box['r']=None; box['err']=repr(ex)
    t=threading.Thread(target=work,daemon=True); t.start(); t.join(timeout_s)
    if t.is_alive(): L('guard_timeout %s (%ds)'%(tag,timeout_s)); return None
    if 'err' in box: L('guard_error %s: %s'%(tag,box['err']))
    return box.get('r')
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
def ft_to_str(ft):
    try:
        dt=datetime.datetime(1601,1,1)+datetime.timedelta(microseconds=ft/10)
        return dt.strftime('%Y-%m-%d %H:%M:%S')
    except Exception: return '?'

L('# R302 DATA RECOVERY - recycle forensics + VSS shadow search')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
DESK=real_desktop(); L('real_desktop='+str(DESK))
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))

# ---- A1. library + old-folders mtimes (when did the nine categories vanish?)
def stat_line(p):
    try:
        st=p.stat(); L('  %s  mtime=%s'%(p.name,time.strftime('%Y-%m-%d %H:%M:%S',time.localtime(st.st_mtime))))
    except Exception as ex: L('  %s stat_error'%p.name)
L('== A1: D:\\DeskBoxLibrary mtimes ==')
stat_line(LIB_D)
if LIB_D.exists():
    for c in sorted(LIB_D.iterdir()):
        stat_line(c)
        try:
            for cc in sorted(c.iterdir())[:20]: stat_line(cc)
        except Exception: pass
NEED=['01-Apps-Shortcuts','02-Job-Tools','03-Video-Creation','04-Images-ID-Photos','05-Documents','06-Archives-Installers','07-Old-Folders','08-Misc','09-Anime-Wallpapers']
have=[n for n in NEED if (LIB_D/n).is_dir()]
L('nine_cat_present=%s'%have)

# ---- A2. $RECYCLE.BIN full scan (D: + E:) with $I parsing
def scan_bin(letter):
    rb=Path(letter+':\\$RECYCLE.BIN')
    L('== A2: %s\\$RECYCLE.BIN =='%letter)
    if not rb.exists(): L('  absent'); return
    try: sids=list(rb.iterdir())
    except Exception as ex: L('  access_error %r'%ex); return
    for sd in sids:
        try:
            items=list(sd.iterdir())
        except Exception as ex:
            L('  %s access_error'%sd.name); continue
        rfiles=[f for f in items if f.name.startswith('$R')]
        ifiles=[f for f in items if f.name.startswith('$I')]
        tot=0
        for f in rfiles[:4000]:
            try: tot+=f.stat().st_size
            except Exception: pass
        L('  sid=%s R=%d I=%d Rsize=%dMB'%(sd.name,len(rfiles),len(ifiles),tot//1048576))
        for f in ifiles[:200]:
            try:
                d=f.read_bytes()
                if len(d)>=28:
                    ver=int.from_bytes(d[0:8],'little'); sz=int.from_bytes(d[8:16],'little')
                    ft=int.from_bytes(d[16:24],'little'); plen=int.from_bytes(d[24:28],'little')
                    path=d[28:28+plen*2].decode('utf-16-le',errors='replace')
                    L('    $I %s | del=%s size=%dMB orig=%s'%(f.name,ft_to_str(ft),sz//1048576,path))
            except Exception as ex: L('    $I parse_error %s'%f.name)
scan_bin('D'); scan_bin('E')

# ---- A3. wallpapers pack census (is the 20GB actually here?)
L('== A3: wallpapers census ==')
if WALL.exists():
    for c in sorted(WALL.iterdir()):
        try:
            if c.is_dir():
                n=0; sz=0
                for f in c.iterdir():
                    n+=1
                    try: sz+=f.stat().st_size
                    except Exception: pass
                L('  %-42s dir  first-level=%d size=%dMB'%(c.name,n,sz//1048576))
            else:
                L('  %-42s file %dB'%(c.name,c.stat().st_size))
        except Exception as ex: L('  %s error'%c.name)
else: L('  wallpapers missing')

# ---- A4. free space
for d in ('C:\\','D:\\','E:\\'):
    try:
        t,u,f=os.statvfs(d); L('free %s = %.1fGB'%(d,f*t/1073741824))
    except Exception as ex:
        try:
            import shutil as _sh; t2,u2,f2=_sh.disk_usage(d); L('free %s = %.1fGB'%(d,f2/1073741824))
        except Exception: L('free %s = ?'%d)

# ---- B. elevated VSS helper (UAC prompt will appear on screen - user clicks Yes)
helper=r'''
$ErrorActionPreference='Continue'
$out='E:\0mcp-agv-arena-optimized\deskbox-v2\vss_out.txt'
function Log($s){ Add-Content -Path $out -Value $s -Encoding UTF8 }
Set-Content -Path $out -Value ('== VSS helper started ' + (Get-Date)) -Encoding UTF8
foreach($d in @('C:\','D:\','E:\')){
  try{ $x=Get-PSDrive ($d.Substring(0,1)) -ErrorAction Stop; Log ('free ' + $d + ' ' + [math]::Round($x.Free/1GB,2) + 'GB') }catch{}
}
$shadows=@()
try{ $shadows=@(Get-CimInstance Win32_ShadowCopy -ErrorAction Stop) }catch{ Log ('cim_error ' + $_.Exception.Message) }
Log ('shadow_count=' + $shadows.Count)
$linkRoot='C:\vss_links'
New-Item -ItemType Directory -Force -Path $linkRoot | Out-Null
$idx=0
$best=$null
foreach($s in $shadows){
  $idx++
  $dev=$s.DeviceObject
  Log ('shadow ' + $idx + ' created=' + $s.InstallDate + ' dev=' + $dev)
  $link=Join-Path $linkRoot ('s' + $idx)
  if(Test-Path $link){ cmd /c rmdir $link | Out-Null }
  cmd /c mklink /d $link ($dev + '\') | Out-Null
  if(-not (Test-Path $link)){ Log ('  link_fail'); continue }
  $cands=@('DeskBoxLibrary','0mcp-agv-arena-optimized\deskbox-v2\library')
  foreach($t in $cands){
    $p=Join-Path $link $t
    if(Test-Path $p){
      $subs=@(Get-ChildItem $p -Directory -ErrorAction SilentlyContinue)
      $names=@($subs | ForEach-Object { $_.Name })
      Log ('  HIT ' + $t + ' subdirs=' + $subs.Count + ' [' + ($names -join ',') + ']')
      $n9=0
      foreach($n in @('01-Apps-Shortcuts','02-Job-Tools','03-Video-Creation','04-Images-ID-Photos','05-Documents','06-Archives-Installers','07-Old-Folders','08-Misc','09-Anime-Wallpapers')){
        if(Test-Path (Join-Path $p $n)){ $n9++ }
      }
      Log ('  nine_cat_count=' + $n9)
      if($n9 -gt 0){
        if($best -eq $null -or $n9 -gt $best.n9){ $best=@{path=$p; n9=$n9; shadow=$idx} }
      }
    }
  }
}
if($best -ne $null){
  $dest='E:\recovery\DeskBoxLibrary_vss'
  try{ $e=Get-PSDrive E -ErrorAction Stop; if($e.Free -lt 25GB){ $dest='D:\recovery_vss\DeskBoxLibrary' } }catch{}
  $logf='E:\0mcp-agv-arena-optimized\deskbox-v2\recovery_robocopy.log'
  Log ('RECOVERY_START shadow=' + $best.shadow + ' nine=' + $best.n9 + ' src=' + $best.path + ' dest=' + $dest)
  New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
  Start-Process robocopy -ArgumentList ('"{0}" "{1}" /E /COPY:DAT /DCOPY:T /R:1 /W:1 /LOG:"{2}"' -f $best.path,$dest,$logf) -WindowStyle Hidden
  Log ('robocopy launched (background, COPY mode only)')
}else{
  Log ('NO_NINE_CAT_IN_SHADOWS')
}
Log ('== VSS helper done ' + (Get-Date))
'''
WT(HELPER,helper,'utf-8-sig')
launcher=("Start-Process powershell -Verb RunAs -Wait -WindowStyle Hidden "
          "-ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','{0}'"
          ).format(str(HELPER).replace("'","''"))
WT(LAUNCHER,launcher)
L('== B: launching elevated VSS helper (UAC prompt on screen) ==')
if VSSOUT.exists():
    try: VSSOUT.unlink()
    except Exception: pass
rc=guarded(lambda: run(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(LAUNCHER)],timeout=380),400,'uac_helper')
L('launcher_rc=%s'%(rc[0] if rc else 'timeout'))
time.sleep(2)
data_found='uac_declined'
if VSSOUT.exists():
    try: vtxt=VSSOUT.read_text(encoding='utf-8',errors='replace')
    except Exception: vtxt=VSSOUT.read_text(errors='replace')
    vls=vtxt.splitlines()
    L('== vss_out.txt (%d lines) =='%len(vls))
    keep=[ln for ln in vls if ('shadow' in ln.lower() or 'HIT' in ln or 'nine_cat' in ln or 'RECOVERY' in ln or 'NO_NINE' in ln or 'free ' in ln or 'link_fail' in ln or 'cim_error' in ln)][:60]
    for ln in keep: L('  vss| '+ln[:170])
    if 'RECOVERY_START' in vtxt: data_found='recovering'
    elif 'NO_NINE_CAT_IN_SHADOWS' in vtxt: data_found='none'
    elif 'shadow_count=0' in vtxt: data_found='no_shadows'
    elif 'cim_error' in vtxt: data_found='vss_enum_failed'
    else: data_found='vss_seen_no_hit'
else:
    L('vss_out.txt absent - UAC was likely declined or timed out')
L('data_found=%s'%data_found)
rcv=Path(r'E:\recovery\DeskBoxLibrary_vss'); rcv2=Path(r'D:\recovery_vss\DeskBoxLibrary')
for r in (rcv,rcv2):
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
complete = data_found in ('recovering','none','no_shadows')
L('R302_RECOVERY_PHASE1_COMPLETE=%s'%complete)
WT(J,json.dumps({'dataFound':data_found,'phase1Complete':complete,'boxesAlive':len(box_pids)},indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if complete else 6)
