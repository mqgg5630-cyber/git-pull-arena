# t245_data_audit_wallpaper_r294.py - round 294.
# r293 exposed a DATA INTEGRITY EMERGENCY: D:\DeskBoxLibrary contains only
# 07-Old-Folders (2 items) while the old organizer held nine category folders
# (~98903 files, 20.1 GB, mostly 09-Anime-Wallpapers). The E: copy from r291
# is also gone (r292's rmdir). Before ANY further changes: a read-only,
# thread-guarded DATA AUDIT to locate every remaining copy, plus a wallpaper
# layer repair attempt. The running boxes are left untouched.
#  1. scene forensics: timestamps in deskbox-v2 (did r292 spawn? which files)
#  2. full listing: D:\, D:\<desktop>, D:\DeskBoxLibrary (2 levels), E: app dirs
#  3. guarded keyword search for the category folder names on D:\ and E:\
#  4. VSS shadow copies + recycle bin check (recovery options)
#  5. Lively wallpaper source intactness (current wallpaper file exists)
#  6. wallpaper layer repair: restart Lively directly, guarded poll 150s
#  7. boxes: leave running (respawn only if fewer than 2 alive)
import ctypes, os, sys, time, subprocess, json, threading
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R294_DATA_AUDIT.md'; J=OUT/'r294-data-audit.json'
DBOX_DIR=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
LIB_D=Path(r'D:\DeskBoxLibrary')
WALL_DIR=Path(r'E:\0mcp-agv-arena-optimized\wallpapers')
LIVELY_CANDIDATES=[r'C:\Program Files\Lively Wallpaper\Lively.exe',r'C:\Program Files (x86)\Lively Wallpaper\Lively.exe']
lines=[]
def L(s):
    s=str(s).encode('ascii','replace').decode('ascii'); print(s,flush=True); lines.append(s)
def WT(p,t): Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(t,encoding='utf-8')
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
    if t.is_alive():
        L('guard_timeout %s (%ds)'%(tag,timeout_s)); return None
    if 'err' in box: L('guard_error %s: %s'%(tag,box['err']))
    return box.get('r')
def windows_report():
    u=ctypes.windll.user32
    import ctypes.wintypes as wt
    top=[]; children=[]
    CBT=ctypes.WINFUNCTYPE(ctypes.c_bool,wt.HWND,wt.LPARAM)
    def probe(h):
        cls=ctypes.create_unicode_buffer(256); u.GetClassNameW(h,cls,256)
        pid=wt.DWORD(); u.GetWindowThreadProcessId(h,ctypes.byref(pid))
        r=wt.RECT(); u.GetWindowRect(h,ctypes.byref(r))
        return (h,cls.value,int(pid.value),int(u.IsWindowVisible(h)),int(r.left),int(r.top),int(r.right),int(r.bottom),int(u.GetParent(h)))
    def tcb(h,l):
        top.append(probe(h)); return True
    u.EnumWindows(CBT(tcb),0)
    roots=[w[0] for w in top if w[1] in ('WorkerW','Progman')]
    def ccb(h,l):
        children.append(probe(h)); return True
    for rh in roots:
        u.EnumChildWindows(rh,CBT(ccb),0)
    return top,children
def tasklist_map():
    m={}
    c,o=run(['tasklist','/FO','CSV','/NH'],timeout=30)
    for ln in (o or '').splitlines():
        parts=ln.split('","')
        if len(parts)>=2:
            try: m[int(parts[1].strip('"'))]=parts[0].strip('"')
            except Exception: pass
    return m
def wallpaper_players_in_layer(tmap=None):
    tmap=tmap or tasklist_map()
    rep=guarded(windows_report,20,'windows_report(layer)')
    if rep is None: return None
    top,children=rep
    EXPLORER_CLASSES={'SHELLDLL_DefView','SysListView32','SysHeader32','WorkerW','Progman'}
    _u=ctypes.windll.user32
    SW=_u.GetSystemMetrics(78); SH=_u.GetSystemMetrics(79)
    out=[]
    for c in children:
        if c[1] in EXPLORER_CLASSES: continue
        if 'explorer' in tmap.get(c[2],'?').lower(): continue
        if not c[3]: continue
        if (c[6]-c[4])>=SW*0.95 and (c[7]-c[5])>=SH*0.95: out.append(c)
    return out
def ls_dir(p,depth=1,maxdepth=1):
    out=[]
    try:
        for x in sorted(p.iterdir(),key=lambda z:z.name.lower()):
            try: out.append(('  '*depth)+x.name+('/' if x.is_dir() else ''))
            except Exception: pass
        if depth<maxdepth:
            for x in sorted(p.iterdir(),key=lambda z:z.name.lower()):
                if x.is_dir(): out+=ls_dir(x,depth+1,maxdepth)
    except Exception as ex:
        out.append(('  '*depth)+'<error %r>'%ex)
    return out
def dirsearch(drive,keywords,timeout_s):
    def work():
        rc,o=run(['cmd','/c','dir',drive,'/s','/b','/ad'],timeout=timeout_s)
        hits=[ln for ln in (o or '').splitlines() if any(k in ln.lower() for k in keywords)]
        return hits[:40], rc
    return guarded(work,timeout_s+15,'dirsearch '+drive)

L('# R294 DATA AUDIT + wallpaper repair (read-only on data)')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
DESK_DIR=Path(os.environ.get('USERPROFILE',r'C:\Users\Public'))/'Desktop'
try:
    c,o=run(['reg','query',r'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders','/v','Desktop'],timeout=15)
    for ln in (o or '').splitlines():
        if 'REG_SZ' in ln and 'Desktop' in ln:
            cand=ln.split('REG_SZ',1)[1].strip()
            if cand and Path(cand).exists(): DESK_DIR=Path(cand); break
except Exception as ex: L('reg_desktop_error='+repr(ex))
L('real_desktop='+str(DESK_DIR))

# ---- 1. scene forensics in deskbox-v2 (what did r292/r293 leave)
L('== deskbox-v2 dir (with mtimes) ==')
try:
    for f in sorted(DBOX_DIR.iterdir(),key=lambda z:z.name.lower()):
        try: L('  %-34s %8dB  %s'%(f.name,f.stat().st_size,time.strftime('%m-%d %H:%M',time.localtime(f.stat().st_mtime))))
        except Exception: L('  '+f.name)
except Exception as ex: L('dbox_list_error=%r'%ex)
L('== launch.log ==')
try: L('  '+' '.join((DBOX_DIR/'deskbox-launch.log').read_text(encoding='utf-8',errors='replace').split()))
except Exception as ex: L('  read_error=%r'%ex)

# ---- 2. full listings
L('== D:\\ top-level dirs ==')
for ln in ls_dir(Path('D:/'),1,1)[:80]: L(ln)
L('== D: junction/reparse check ==')
c,o=run(['cmd','/c','dir','D:\\','/AL'],timeout=15)
for ln in (o or '').splitlines()[:12]: L('  '+ln)
L('== real desktop top-level (%s) =='%str(DESK_DIR))
for ln in ls_dir(DESK_DIR,1,1)[:120]: L(ln)
L('== D:\\DeskBoxLibrary tree (2 levels) ==')
if LIB_D.exists():
    for ln in ls_dir(LIB_D,1,2)[:200]: L(ln)
    try: L('total_children=%d'%len(list(LIB_D.iterdir())))
    except Exception: pass
else:
    L('  MISSING')
L('== E:\\0mcp-agv-arena-optimized top ==')
for ln in ls_dir(Path(r'E:\0mcp-agv-arena-optimized'),1,1)[:60]: L(ln)
L('== E:\\...\\deskbox-v2 top ==')
for ln in ls_dir(DBOX_DIR,1,1)[:40]: L(ln)

# ---- 3. keyword search (guarded)
KEYS=['anime-wallpapers','apps-shortcuts','deskbox-cute','job-tools','archives-installers']
L('== keyword search D:\\ (guarded 300s) ==')
res=dirsearch('D:\\',KEYS,300)
if res:
    hits,rc=res
    L('dir rc=%s hits=%d'%(str(rc),len(hits)))
    for h in hits: L('  HIT '+h)
else:
    L('search D unavailable/timeout')
L('== keyword search E:\\ (guarded 240s) ==')
res2=dirsearch('E:\\',KEYS,240)
if res2:
    hits2,rc2=res2
    L('dir rc=%s hits=%d'%(str(rc2),len(hits2)))
    for h in hits2: L('  HIT '+h)
else:
    L('search E unavailable/timeout')

# ---- 4. recovery options: VSS shadows + recycle bin
L('== VSS shadow copies ==')
c,o=run(['vssadmin','list','shadows'],timeout=30)
L('vssadmin rc=%d'%c)
for ln in (o or '').splitlines()[:15]: L('  '+ln)
c,o=run(['powershell','-NoProfile','-Command','Get-CimInstance Win32_ShadowCopy | Select-Object -First 5 InstallDate,VolumeName | Format-List'],timeout=40)
for ln in (o or '').splitlines()[:12]: L('  ps '+ln)
L('== recycle bin (COM) ==')
c,o=run(['powershell','-NoProfile','-Command','$s=(New-Object -ComObject Shell.Application).Namespace(0xA); $i=$s.Items(); $i.Count; $i | Select-Object -First 12 -Expand Name'],timeout=40)
for ln in (o or '').splitlines()[:16]: L('  rb '+ln)

# ---- 5. Lively wallpaper source intactness
L('== wallpaper sources ==')
for w in ('lively-12','anime-girl-meteor-r254','mahiru-golden-r255'):
    d=WALL_DIR/w
    try:
        n=len(list(d.iterdir())); L('  %s exists, %d entries'%(w,n))
    except Exception: L('  %s missing'%w)
try:
    st=json.loads((WALL_DIR/'lively-12'/'state.json').read_text(encoding='utf-8'))
    cur=st.get('current') if isinstance(st,dict) else None
    L('  state.json current=%s'%str(cur))
    if cur:
        cands=list((WALL_DIR/'lively-12').glob('*%s*'%str(cur)))[:5]
        for cc in cands: L('   current-source %s (%dB)'%(cc.name,cc.stat().st_size))
except Exception as ex: L('  state_error=%r'%ex)
L('== lively processes ==')
for nm in ('Lively.exe','mpv.exe'):
    c,o=run(['tasklist','/FI','IMAGENAME eq '+nm],timeout=20)
    found=nm in (o or '')
    L('  %s running=%s'%(nm,found))

# ---- 6. wallpaper layer repair
layer_before=wallpaper_players_in_layer()
L('layer_before=%s'%('UP' if layer_before else ('ENUM_HUNG' if layer_before is None else 'DOWN')))
if not layer_before:
    lively=''
    for cnd in LIVELY_CANDIDATES:
        if Path(cnd).exists(): lively=cnd; break
    L('repair: kill mpv+lively, start %s'%lively)
    run(['taskkill','/F','/IM','mpv.exe'],timeout=20)
    run(['taskkill','/F','/IM','Lively.exe'],timeout=20); time.sleep(5)
    if lively:
        run_bg([lively]); time.sleep(20)
        ok=False
        t0=time.time()
        while time.time()-t0<150:
            pl=wallpaper_players_in_layer()
            if pl:
                L('layer_recovered after %ds'%(int(time.time()-t0))); ok=True; break
            if pl is None: L('enum_hung_during_repair_poll')
            time.sleep(10)
        layer_after=bool(pl) if (pl is not None) else False
    else:
        layer_after=False
else:
    layer_after=True
L('layer_final=%s'%layer_after)

# ---- 7. boxes left running (respawn only if <2)
box_pids=[]
for f in DBOX_DIR.glob('deskbox-*.pid'):
    try:
        pid=int(f.read_text().strip())
        c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
        if str(pid) in (o or ''): box_pids.append(pid)
    except Exception: pass
L('boxes_alive_now=%d %s'%(len(box_pids),box_pids))
if len(box_pids)<2:
    L('respawning via supervisor')
    run_bg([sys.executable,str(DBOX_DIR/'deskbox.py')]); time.sleep(12)
    box_pids=[]
    for f in sorted(DBOX_DIR.glob('deskbox-*.pid')):
        try:
            pid=int(f.read_text().strip())
            c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
            if str(pid) in (o or ''): box_pids.append(pid)
        except Exception: pass
    L('boxes_after_respawn=%d %s'%(len(box_pids),box_pids))

ready=bool(len(box_pids)>=2 and (layer_after) and not locked)
L('DATA_AUDIT_COMPLETE=True')
L('AUDIT_ROUND_READY='+str(ready))
summary={'ready':ready,'locked':locked,'boxesAlive':len(box_pids),'layerFinal':layer_after}
WT(J,json.dumps(summary,ensure_ascii=False,indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
