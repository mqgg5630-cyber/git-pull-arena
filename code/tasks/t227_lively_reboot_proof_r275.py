# t227_lively_reboot_proof_r275.py - round 275.
# User report: the dynamic wallpaper is GONE after a reboot. Lively's
# "Startup: true" setting did not bring it back. This round:
#   1. DIAGNOSE the post-reboot state: Lively/mpv processes, wallpaper layer,
#      autostart registrations (HKCU/HKLM Run, Startup folder, scheduled
#      tasks), WallpaperLayout.json before/after setwp, Lively folder logs.
#   2. RE-APPLY the wallpaper (clean zombies -> start Lively -> setwp ->
#      play) and prove it (WorkerW layer structure + pixel probes).
#   3. INSTALL A KEEPER so a reboot can never lose the wallpaper again:
#      Startup\\Lively Wallpaper Keeper.bat -> pythonw keeper_lively_hotori.py
#      waits 45s after logon, starts Lively if needed, re-runs setwp if the
#      wallpaper layer is empty (3 attempts), logging to keeper.log.
# Permanent wallpaper home: E:\\...\\lively-hotori (stable path, no round no).
import ctypes, os, sys, time, subprocess, json, shutil, struct, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R275_LIVELY_WALLPAPER_REBOOT_PROOF.md'; J=OUT/'r275-lively-wallpaper-reboot-proof.json'
A=OUT/'r275_frame_a_before.bmp'; B=OUT/'r275_frame_b_after.bmp'; C=OUT/'r275_frame_c_late.bmp'; D=OUT/'r275_frame_d_late.bmp'; E=OUT/'r275_frame_e_late2.bmp'; F=OUT/'r275_frame_f_late2.bmp'
PERM=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\lively-hotori'); PERM.mkdir(parents=True,exist_ok=True)
MP4=PERM/'hotori_dynamic_wallpaper.mp4'
WALL_R274=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\lively-dynamic-r274\hotori_dynamic_wallpaper_r274.mp4')
WALL_R273=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\lively-dynamic-r273\hotori_dynamic_wallpaper_r273.mp4')
WALL_R272=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\dynamic-video-r272\dynamic_video_wallpaper_r272.mp4')
LIVELY_CANDIDATES=[r'C:\Program Files\Lively Wallpaper\Lively.exe',r'C:\Program Files (x86)\Lively Wallpaper\Lively.exe',str(Path(os.environ.get('LOCALAPPDATA',r'C:\Users\Public'))/'Programs'/'Lively Wallpaper'/'Lively.exe')]
LIVELY_DIR=Path(os.environ.get('LOCALAPPDATA',r'C:\Users\Public'))/'Lively Wallpaper'
LAYOUT=LIVELY_DIR/'WallpaperLayout.json'
STATIC_R267=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\static-anime-r267\cute_static_anime_wallpaper_r267.png')
STATIC_DEFAULT=r'C:\Windows\Web\Wallpaper\Windows\img0.jpg'
STARTUP_DIR=Path(os.environ.get('APPDATA',r'C:\Users\Public'))/'Microsoft'/'Windows'/'Start Menu'/'Programs'/'Startup'
KEEPER_BAT=STARTUP_DIR/'Lively Wallpaper Keeper.bat'
KEEPER_PY=PERM/'keeper_lively_hotori.py'
KEEPER_LOG=PERM/'keeper.log'
lines=[]
def L(s):
    s=str(s).encode('ascii','replace').decode('ascii'); print(s); lines.append(s)
def WT(p,t): Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(t,encoding='utf-8')
def WA(p,t):
    Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(str(t).encode('ascii','replace').decode('ascii'),encoding='ascii')
def run(args,timeout=25):
    try:
        p=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout,text=True,errors='replace')
        return p.returncode,p.stdout
    except Exception as e: return 999,repr(e)
def shot(path):
    u=ctypes.windll.user32; g=ctypes.windll.gdi32; x=u.GetSystemMetrics(76); y=u.GetSystemMetrics(77); w=u.GetSystemMetrics(78); h=u.GetSystemMetrics(79)
    hdc=u.GetDC(0); mem=g.CreateCompatibleDC(hdc); bmp=g.CreateCompatibleBitmap(hdc,w,h); old=g.SelectObject(mem,bmp); ok=g.BitBlt(mem,0,0,w,h,hdc,x,y,0x00CC0020)
    stride=((w*3+3)//4)*4; size=stride*h
    class BIH(ctypes.Structure): _fields_=[('biSize',ctypes.c_uint32),('biWidth',ctypes.c_int32),('biHeight',ctypes.c_int32),('biPlanes',ctypes.c_uint16),('biBitCount',ctypes.c_uint16),('biCompression',ctypes.c_uint32),('biSizeImage',ctypes.c_uint32),('biXPelsPerMeter',ctypes.c_int32),('biYPelsPerMeter',ctypes.c_int32),('biClrUsed',ctypes.c_uint32),('biClrImportant',ctypes.c_uint32)]
    class BI(ctypes.Structure): _fields_=[('bmiHeader',BIH),('bmiColors',ctypes.c_uint32*3)]
    bi=BI(); bi.bmiHeader.biSize=ctypes.sizeof(BIH); bi.bmiHeader.biWidth=w; bi.bmiHeader.biHeight=-h; bi.bmiHeader.biPlanes=1; bi.bmiHeader.biBitCount=24; bi.bmiHeader.biCompression=0; bi.bmiHeader.biSizeImage=size
    buf=(ctypes.c_ubyte*size)(); got=g.GetDIBits(mem,bmp,0,h,ctypes.byref(buf),ctypes.byref(bi),0); g.SelectObject(mem,old); g.DeleteObject(bmp); g.DeleteDC(mem); u.ReleaseDC(0,hdc)
    if (not ok) or got==0: return False,w,h,'capture failed'
    p=Path(path); p.parent.mkdir(parents=True,exist_ok=True)
    with open(p,'wb') as f: f.write(b'BM'); f.write(struct.pack('<IHHI',54+size,0,0,54)); f.write(struct.pack('<IiiHHIIiiII',40,w,-h,1,24,0,size,0,0,0,0)); f.write(bytes(buf))
    return True,w,h,''
def info(p):
    data=Path(p).read_bytes(); off=struct.unpack_from('<I',data,10)[0]; w=struct.unpack_from('<i',data,18)[0]; hh=struct.unpack_from('<i',data,22)[0]; bpp=struct.unpack_from('<H',data,28)[0]; td=hh<0; h=abs(hh); st=((w*(bpp//8)+3)//4)*4; return data,off,w,h,bpp,td,st
def diff(a,b):
    try:
        da,oa,wa,ha,ba,ta,sa=info(a); db,ob,wb,hb,bb,tb,sb=info(b); w=min(wa,wb); h=min(ha,hb); step=max(4,min(w,h)//260); sm=0; ch=0; tot=0; bpa=ba//8; bpb=bb//8
        for y in range(0,h,step):
            ya=y if ta else ha-1-y; yb=y if tb else hb-1-y
            for x in range(0,w,step):
                ia=oa+ya*sa+x*bpa; ib=ob+yb*sb+x*bpb; dd=abs(da[ia+2]-db[ib+2])+abs(da[ia+1]-db[ib+1])+abs(da[ia]-db[ib]); tot+=dd; sm+=1; ch+=1 if dd>25 else 0
        return {'ok':True,'ratio':ch/sm if sm else 0,'avg':tot/sm if sm else 0,'changed':ch,'samples':sm}
    except Exception as e: return {'ok':False,'ratio':0,'avg':0,'err':repr(e)}
def mini():
    try: subprocess.run(['powershell.exe','-NoProfile','-Command','(New-Object -ComObject Shell.Application).MinimizeAll()'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10)
    except Exception: pass
def set_static(path):
    try: ctypes.windll.user32.SystemParametersInfoW(20,0,str(path),3)
    except Exception: pass
def looks_like_mp4(p):
    try: return b'ftyp' in Path(p).read_bytes()[:16]
    except Exception: return False
def task_count(name):
    c,o=run(['tasklist','/FI',f'IMAGENAME eq {name}']); return o.count(name)
def tasklist_map():
    m={}
    c,o=run(['tasklist','/FO','CSV','/NH'],timeout=30)
    for ln in (o or '').splitlines():
        parts=ln.split('","')
        if len(parts)>=2:
            try: m[int(parts[1].strip('"'))]=parts[0].strip('"')
            except Exception: pass
    return m
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
def wallpaper_players_in_layer(tmap=None):
    tmap=tmap or tasklist_map()
    top,children=windows_report()
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

L('# R275 Lively dynamic wallpaper reboot proof + keeper')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
L('user_report=wallpaper gone after reboot; lively Startup=true did not restore it')
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))

# ---- 1. POST-REBOOT DIAGNOSIS (before touching anything)
L('post_reboot_lively_process='+str(task_count('Lively.exe')))
L('post_reboot_mpv_process='+str(task_count('mpv.exe')))
try:
    pl=wallpaper_players_in_layer()
    L('post_reboot_wallpaper_layer_present='+str(len(pl)>0))
    for c in pl[:4]: L('   post_reboot_player| class='+c[1]+' owner='+tasklist_map().get(c[2],'?'))
except Exception as ex: L('post_reboot_layer_probe_error='+repr(ex))
for hive in ['HKCU','HKLM']:
    try:
        c,o=run(['reg','query',hive+r'\Software\Microsoft\Windows\CurrentVersion\Run'],timeout=15)
        for ln in (o or '').splitlines():
            if 'lively' in ln.lower(): L('autostart_'+hive+'| '+ln.strip()[:200])
    except Exception: pass
try:
    for f in sorted(STARTUP_DIR.iterdir()):
        if 'lively' in f.name.lower() or 'wallpaper' in f.name.lower(): L('startup_folder| '+f.name)
except Exception: pass
try:
    c,o=run(['schtasks','/query','/fo','csv'],timeout=30)
    for ln in (o or '').splitlines():
        if 'lively' in ln.lower(): L('scheduled_task| '+ln.strip()[:160])
except Exception: pass
def layout_state(tag):
    try:
        if LAYOUT.exists():
            txt=LAYOUT.read_text(encoding='utf-8',errors='replace')
            has='hotori' in txt.lower()
            L('wallpaper_layout_'+tag+'=exists bytes='+str(len(txt))+' has_hotori='+str(has))
            for ln in txt.splitlines()[:14]:
                if ln.strip(): L('   wl'+tag+'| '+ln.strip()[:150])
            return has
        L('wallpaper_layout_'+tag+'=MISSING')
        return False
    except Exception as ex:
        L('wallpaper_layout_'+tag+'_error='+repr(ex)); return False
layout_before=layout_state('before')
try:
    if LIVELY_DIR.exists():
        for f in sorted(LIVELY_DIR.iterdir()):
            if f.suffix.lower() in ('.log','.txt'): L('   livelydir_file| '+f.name+' '+str(f.stat().st_size)+'B')
except Exception: pass

# ---- 2. ensure the permanent mp4 exists
if not (MP4.exists() and MP4.stat().st_size>=300000 and looks_like_mp4(MP4)):
    for src in [WALL_R274,WALL_R273,WALL_R272]:
        if src.exists() and src.stat().st_size>=300000 and looks_like_mp4(src):
            shutil.copy2(src,MP4); break
L('mp4='+str(MP4)+' exists='+str(MP4.exists())+' bytes='+str(MP4.stat().st_size if MP4.exists() else 0))

# ---- 3. clean zombies, start Lively, setwp, play
run(['taskkill','/F','/IM','Livelycu.exe'],timeout=20)
z=task_count('Lively.exe')
if z>1: run(['taskkill','/F','/IM','Lively.exe'],timeout=20); time.sleep(3)
L('lively_cleanup_done pre_count='+str(z))
mini(); time.sleep(1); ok,w,h,e=shot(A); L(f'frame_a_before={A} ok={ok} width={w} height={h} err={e}')
lively=''
for c in LIVELY_CANDIDATES:
    if Path(c).exists(): lively=c; break
L('lively_exe='+str(lively))
app_ok=False
if lively:
    if task_count('Lively.exe')==0:
        try:
            subprocess.Popen([lively],cwd=str(Path(lively).parent),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        except Exception as ex: L('lively_start_error='+repr(ex))
    app_ok=task_count('Lively.exe')>0 or True
    time.sleep(25)
L('lively_app_running='+str(task_count('Lively.exe')>0))
setwp_exit=-1
if lively and MP4.exists():
    setwp_exit,o=run([lively,'setwp','--file',str(MP4),'--monitor','1'],timeout=30)
    L('setwp_monitor1_exit='+str(setwp_exit)+' tail='+(' '.join((o or '').split())[:120]))
L('setwp_ok='+str(setwp_exit==0))
time.sleep(20)
pl=wallpaper_players_in_layer()
if not pl and lively and MP4.exists():
    e2,o=run([lively,'setwp','--file',str(MP4)],timeout=30)
    L('setwp_primary_fallback_exit='+str(e2))
    time.sleep(15)
    pl=wallpaper_players_in_layer()
if lively:
    p1,_=run([lively,'--play','true'],timeout=15); L('play_true_exit='+str(p1)); time.sleep(5)
tmap=tasklist_map()
for c in pl[:6]:
    L('   wallpaper_player| class='+c[1]+' owner='+tmap.get(c[2],'?')+' rect='+str((c[4],c[5],c[6],c[7])))
wallpaper_layer_proven=len(pl)>0
L('wallpaper_layer_proven='+str(wallpaper_layer_proven))
layout_after=layout_state('after')

# ---- 4. pixel probes
time.sleep(10); mini(); time.sleep(1); ok,w,h,e=shot(B); L(f'frame_b_after={B} ok={ok} width={w} height={h} err={e}')
time.sleep(75); ok,w,h,e=shot(C); L(f'frame_c_late={C} ok={ok} width={w} height={h} err={e}')
time.sleep(6); ok,w,h,e=shot(D); L(f'frame_d_late={D} ok={ok} width={w} height={h} err={e}')
time.sleep(88); ok,w,h,e=shot(E); L(f'frame_e_late2={E} ok={ok} width={w} height={h} err={e}')
time.sleep(6); ok,w,h,e=shot(F); L(f'frame_f_late2={F} ok={ok} width={w} height={h} err={e}')
d_start=diff(A,B); d_late=diff(C,D); d_late2=diff(E,F)
L('desktop_changed_from_before_ratio=%.6f'%d_start['ratio']); L('desktop_changed_from_before_avg=%.3f'%d_start['avg'])
L('desktop_late_motion_ratio=%.6f'%d_late['ratio']); L('desktop_late_motion_avg=%.3f'%d_late['avg'])
L('desktop_late2_motion_ratio=%.6f'%d_late2['ratio']); L('desktop_late2_motion_avg=%.3f'%d_late2['avg'])
changed=d_start.get('ok') and (d_start['ratio']>0.02 or d_start['avg']>4)
moving=d_late.get('ok') and (d_late['ratio']>0.0005 or d_late['avg']>0.25)
moving2=d_late2.get('ok') and (d_late2['ratio']>0.0005 or d_late2['avg']>0.25)
L('actual_desktop_changed_to_new_wallpaper='+str(bool(changed)))
L('actual_desktop_is_moving_late='+str(bool(moving)))
L('actual_desktop_is_moving_late2='+str(bool(moving2)))
L('persistent_motion_proven='+str(bool(moving and moving2)))

# ---- 5. install the keeper (reboot self-heal)
keeper_py_src='''# keeper_lively_hotori.py - started from Startup at logon by
# "Lively Wallpaper Keeper.bat". Makes sure the Lively dynamic wallpaper is
# alive after a reboot: start Lively if needed, re-run setwp if the wallpaper
# layer is empty. Log: keeper.log next to this file.
import ctypes, os, subprocess, sys, time
from pathlib import Path
LOG=Path(r'E:\\0mcp-agv-arena-optimized\\wallpapers\\lively-hotori\\keeper.log')
MP4=Path(r'E:\\0mcp-agv-arena-optimized\\wallpapers\\lively-hotori\\hotori_dynamic_wallpaper.mp4')
LIVELY=r'C:\\Program Files\\Lively Wallpaper\\Lively.exe'
def log(m):
    try:
        LOG.parent.mkdir(parents=True,exist_ok=True)
        entry=time.strftime('%Y-%m-%d %H:%M:%S')+' '+m+'\\n'
        old=LOG.read_text(encoding='utf-8',errors='replace') if LOG.exists() else ''
        LOG.write_text((old+entry)[-4000:],encoding='utf-8')
    except Exception: pass
def run(args,timeout=30):
    try:
        p=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout,text=True,errors='replace')
        return p.returncode,p.stdout
    except Exception as e: return 999,repr(e)
def running(name):
    c,o=run(['tasklist','/FI','IMAGENAME eq '+name],timeout=20)
    return name in (o or '')
def layer_players():
    try:
        import ctypes.wintypes as wt
        u=ctypes.windll.user32
        top=[]; children=[]
        CBT=ctypes.WINFUNCTYPE(ctypes.c_bool,wt.HWND,wt.LPARAM)
        def probe(h):
            cls=ctypes.create_unicode_buffer(256); u.GetClassNameW(h,cls,256)
            pid=wt.DWORD(); u.GetWindowThreadProcessId(h,ctypes.byref(pid))
            r=wt.RECT(); u.GetWindowRect(h,ctypes.byref(r))
            return (h,cls.value,int(pid.value),int(u.IsWindowVisible(h)),int(r.left),int(r.top),int(r.right),int(r.bottom))
        def tcb(h,l):
            top.append(probe(h)); return True
        u.EnumWindows(CBT(tcb),0)
        roots=[w[0] for w in top if w[1] in ('WorkerW','Progman')]
        def ccb(h,l):
            children.append(probe(h)); return True
        for rh in roots:
            u.EnumChildWindows(rh,CBT(ccb),0)
        names={}
        c,o=run(['tasklist','/FO','CSV','/NH'],timeout=30)
        for ln in (o or '').splitlines():
            p=ln.split('","')
            if len(p)>=2:
                try: names[int(p[1].strip('"'))]=p[0].strip('"').lower()
                except Exception: pass
        SW=u.GetSystemMetrics(78); SH=u.GetSystemMetrics(79)
        out=[]
        for c in children:
            if c[1] in ('SHELLDLL_DefView','SysListView32','SysHeader32','WorkerW','Progman'): continue
            if 'explorer' in names.get(c[2],'?'): continue
            if not c[3]: continue
            if (c[6]-c[4])>=SW*0.95 and (c[7]-c[5])>=SH*0.95: out.append(c)
        return out
    except Exception as ex:
        log('layer probe error '+repr(ex)); return []
log('keeper start (pid '+str(os.getpid())+')')
time.sleep(45)
ok=False
for attempt in range(1,4):
    if not running('Lively.exe'):
        try: subprocess.Popen([LIVELY],cwd=LIVELY[:LIVELY.rfind('\\\\')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        except Exception as ex: log('start lively error '+repr(ex))
        time.sleep(30)
    players=layer_players()
    if players:
        log('attempt '+str(attempt)+': wallpaper layer OK ('+str(len(players))+' player window)')
        ok=True; break
    if not MP4.exists():
        log('attempt '+str(attempt)+': mp4 missing'); break
    c,o=run([LIVELY,'setwp','--file',str(MP4),'--monitor','1'])
    log('attempt '+str(attempt)+': setwp exit '+str(c))
    time.sleep(25)
    run([LIVELY,'--play','true']); time.sleep(10)
    players=layer_players()
    if players:
        log('attempt '+str(attempt)+': setwp healed the wallpaper'); ok=True; break
log('keeper done ok='+str(ok))
sys.exit(0 if ok else 1)
'''
try:
    WA(KEEPER_PY,keeper_py_src)
    L('keeper_py='+str(KEEPER_PY)+' exists='+str(KEEPER_PY.exists()))
except Exception as ex: L('keeper_py_error='+repr(ex))
try:
    bat=('@echo off\r\n'
         'rem Lively dynamic wallpaper keeper - re-applies the wallpaper after logon if Lively did not\r\n'
         'where pythonw.exe >nul 2>&1 && (start "" pythonw.exe "'+str(KEEPER_PY)+'") || (start "" /min python.exe "'+str(KEEPER_PY)+'")\r\n')
    WA(KEEPER_BAT,bat)
    L('keeper_bat='+str(KEEPER_BAT)+' exists='+str(KEEPER_BAT.exists()))
except Exception as ex: L('keeper_bat_error='+repr(ex))
keeper_installed=bool(KEEPER_PY.exists() and KEEPER_BAT.exists())
L('keeper_installed='+str(keeper_installed)+' (logon: wait 45s -> start Lively -> setwp if layer empty, 3 attempts, keeper.log)')
try:
    WT(PERM/'PATHS.txt','Lively dynamic wallpaper (permanent home)\r\n=========================================\r\nwallpaper : '+str(MP4)+'\r\nkeeper py : '+str(KEEPER_PY)+'\r\nkeeper bat: '+str(KEEPER_BAT)+' (delete to stop self-heal at logon)\r\nkeeper log: '+str(KEEPER_LOG)+'\r\nlively exe: '+str(lively)+'\r\n')
    L('paths_txt_ok=True')
except Exception: pass

ready=bool(lively and setwp_exit==0 and wallpaper_layer_proven and changed and moving and moving2 and not locked and keeper_installed)
if not ready:
    L('rollback_performed=True')
    if lively:
        run([lively,'closewp','--monitor','-1'],timeout=20); run([lively,'--shutdown','true'],timeout=20)
    set_static(str(STATIC_R267) if STATIC_R267.exists() else STATIC_DEFAULT)
    L('rollback_static_done=True')

# ---- 6. receipts
desk=Path(os.environ.get('USERPROFILE',r'C:\Users\Public'))/'Desktop'; org=desk/'DeskBox-Cute-Desktop-Organizer'; org.mkdir(parents=True,exist_ok=True)
tidy=org/'AUTO_TIDY_LAST_RUN.txt'; tidy.write_text('time='+time.strftime('%Y-%m-%d %H:%M:%S')+'\nlively_wallpaper_reboot_proof_r275='+str(ready)+'\n',encoding='utf-8')
L('desktop_tidy_done='+str(tidy.exists()))
L('LIVELY_WALLPAPER_REBOOT_PROOF_READY='+str(ready))
summary={'ready':ready,'locked':locked,'livelyExe':lively,'setwpExit':setwp_exit,'wallpaperLayerProven':wallpaper_layer_proven,'layoutBeforeHasHotori':layout_before,'layoutAfterHasHotori':layout_after,'keeperInstalled':keeper_installed,'keeperBat':str(KEEPER_BAT),'mp4':str(MP4),'desktopChangedFromBeforeRatio':d_start.get('ratio'),'desktopLateMotionRatio':d_late.get('ratio'),'desktopLate2MotionRatio':d_late2.get('ratio'),'persistentMotionProven':bool(moving and moving2),'tidyManifest':str(tidy)}
WT(J,json.dumps(summary,ensure_ascii=False,indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
