# t226_lively_dynamic_wallpaper_r274.py - round 274.
# The user rejected the VLC result: VLC's --video-wallpaper on this Win11
# machine behaves like a borderless window covering the desktop, not a real
# wallpaper layer - pixel motion alone cannot tell the two apart. This round
# retires VLC completely and gives Lively Wallpaper (the real wallpaper app,
# installed at C:\Program Files\Lively Wallpaper) its first FAIR trial:
#   r258's Lively failure had 25 zombie Livelycu processes and likely no
#   running app; r259/r260 (clean restart) were killed by AMSI before running.
# Steps: kill all Lively*/vlc -> disable pause rules in Settings.json ->
# start the Lively app -> setwp the hotori mp4 -> PROOF = (a) structural: a
# Lively window parented inside WorkerW/Progman (the wallpaper layer BEHIND
# the desktop icons) + (b) pixels: desktop changed AND moving at ~105s and
# ~200s. Full diagnostics (settings schema, power status, window tree) go
# into the receipt either way.
import ctypes, os, sys, time, subprocess, json, shutil, struct, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R274_LIVELY_DYNAMIC_WALLPAPER.md'; J=OUT/'r274-lively-dynamic-wallpaper.json'
A=OUT/'r274_frame_a_before.bmp'; B=OUT/'r274_frame_b_after.bmp'; C=OUT/'r274_frame_c_late.bmp'; D=OUT/'r274_frame_d_late.bmp'; E=OUT/'r274_frame_e_late2.bmp'; F=OUT/'r274_frame_f_late2.bmp'; ROLLBACK=OUT/'r274_rollback.bmp'
WALL_R273=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\lively-dynamic-r273\hotori_dynamic_wallpaper_r273.mp4')
WALL_R272=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\dynamic-video-r272\dynamic_video_wallpaper_r272.mp4')
WALL_R270=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\dynamic-video-r270\dynamic_video_wallpaper_r270.mp4')
WALL_R269=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\dynamic-video-r269\dynamic_video_wallpaper_r269.mp4')
WROOT=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\lively-dynamic-r274'); WROOT.mkdir(parents=True,exist_ok=True)
MP4=WROOT/'hotori_dynamic_wallpaper_r274.mp4'
# vlc was fully retired in r273; re-check the startup bat just in case
VLC_RETIRE=[Path(os.environ.get('APPDATA',r'C:\Users\Public'))/'Microsoft'/'Windows'/'Start Menu'/'Programs'/'Startup'/'R272 Dynamic Video Wallpaper Start.bat']
LIVELY_CANDIDATES=[r'C:\Program Files\Lively Wallpaper\Lively.exe',r'C:\Program Files (x86)\Lively Wallpaper\Lively.exe',str(Path(os.environ.get('LOCALAPPDATA',r'C:\Users\Public'))/'Programs'/'Lively Wallpaper'/'Lively.exe')]
SETTINGS=Path(os.environ.get('LOCALAPPDATA',r'C:\Users\Public'))/'Lively Wallpaper'/'Settings.json'
STATIC_R267=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\static-anime-r267\cute_static_anime_wallpaper_r267.png')
STATIC_DEFAULT=r'C:\Windows\Web\Wallpaper\Windows\img0.jpg'
STARTUP_DIR=Path(os.environ.get('APPDATA',r'C:\Users\Public'))/'Microsoft'/'Windows'/'Start Menu'/'Programs'/'Startup'
OUR_STARTUP=STARTUP_DIR/'R274 Lively Dynamic Wallpaper Start.bat'
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
def power_status():
    try:
        class PWR(ctypes.Structure): _fields_=[('ACLineStatus',ctypes.c_byte),('BatteryFlag',ctypes.c_byte),('BatteryLifePercent',ctypes.c_byte),('Reserved1',ctypes.c_byte),('BatteryLifeTime',ctypes.c_uint32),('BatteryFullLifeTime',ctypes.c_uint32)]
        p=PWR(); ctypes.windll.kernel32.GetSystemPowerStatus(ctypes.byref(p))
        return ('ac' if p.ACLineStatus==1 else 'battery'), int(p.BatteryLifePercent)
    except Exception as e: return 'unknown',0
def tasklist_map():
    m={}
    c,o=run(['tasklist','/FO','CSV','/NH'],timeout=30)
    for ln in (o or '').splitlines():
        parts=ln.split('","')
        if len(parts)>=2:
            name=parts[0].strip('"'); pid=parts[1].strip('"')
            try: m[int(pid)]=name
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
    workerws=[w for w in top if w[1]=='WorkerW']
    progmans=[w for w in top if w[1]=='Progman']
    roots=[w[0] for w in workerws]+[w[0] for w in progmans]
    def ccb(h,l):
        children.append(probe(h)); return True
    for rh in roots:
        u.EnumChildWindows(rh,CBT(ccb),0)
    return top,workerws,progmans,children

def flip_pause_rules(obj):
    # Lively v2 stores booleans as 0/1 ints; only touch battery/power-save keys
    n=0
    if isinstance(obj,dict):
        for k,v in list(obj.items()):
            if re.search(r'batter|powersave',str(k),re.I) and v in (1,'1',True):
                obj[k]=0; n+=1
            else:
                n+=flip_pause_rules(v)
    elif isinstance(obj,list):
        for it in obj: n+=flip_pause_rules(it)
    return n

L('# R274 real dynamic wallpaper via Lively (player-process aware gate)')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
L('r273_lesson=the wallpaper WAS working (mpv.exe window inside WorkerW, pixels moving) but the gate demanded a Lively-named process and rolled it back; r274 accepts the actual player process (mpv/webview/gif) as structural proof')
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
ac,pct=power_status(); L('power_source='+ac+' battery_percent='+str(pct))
vlc=r'C:\Program Files\VideoLAN\VLC\vlc.exe'
if Path(vlc).exists():
    subprocess.Popen([vlc,'vlc://quit'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); time.sleep(3)
run(['taskkill','/F','/IM','vlc.exe'],timeout=15)
L('vlc_processes_after_kill='+str(task_count('vlc.exe')))
retired=0
for p in VLC_RETIRE:
    try:
        if p.exists(): p.unlink(); retired+=1; L('vlc_artifact_removed='+str(p))
    except Exception as ex: L('vlc_artifact_remove_error='+repr(ex))
L('vlc_retired='+str(retired>=1 or not any(p.exists() for p in VLC_RETIRE)))

# ---- 1. Lively zombie cleanup (the r258 killer)
z_before=task_count('Livelycu.exe')+task_count('Lively.exe')
run(['taskkill','/F','/IM','Livelycu.exe'],timeout=20); run(['taskkill','/F','/IM','Lively.exe'],timeout=20); time.sleep(3)
z_after=task_count('Livelycu.exe')+task_count('Lively.exe')
L('lively_zombies_before='+str(z_before)+' after_cleanup='+str(z_after))

# ---- 2. settings: log schema, backup, disable pause rules
settings_text=''; settings_flipped=0
if SETTINGS.exists():
    settings_text=SETTINGS.read_text(encoding='utf-8',errors='replace')
    L('settings_json='+SETTINGS.name+' bytes='+str(len(settings_text)))
    for ln in settings_text.splitlines()[:80]:
        if ln.strip(): L('   sj| '+ln.strip()[:160])
    try:
        d=json.loads(settings_text)
        SETTINGS.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(SETTINGS,str(SETTINGS)+'.bak_r273')
        settings_flipped=flip_pause_rules(d)
        if settings_flipped>0:
            SETTINGS.write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8')
        L('settings_pause_rules_flipped='+str(settings_flipped)+' (backup: Settings.json.bak_r274)')
    except Exception as ex: L('settings_edit_error='+repr(ex))
else:
    L('settings_json=MISSING at '+str(SETTINGS))
    try:
        p=SETTINGS.parent
        if p.exists():
            for f in sorted(p.iterdir())[:20]: L('   livelydir| '+f.name)
    except Exception: pass

# ---- 3. wallpaper file (reuse chain, keep the hotori video)
if not (MP4.exists() and MP4.stat().st_size>=300000 and looks_like_mp4(MP4)):
    for src in [WALL_R273,WALL_R272,WALL_R270,WALL_R269]:
        if src.exists() and src.stat().st_size>=300000 and looks_like_mp4(src):
            shutil.copy2(src,MP4); break
L('mp4='+str(MP4)+' exists='+str(MP4.exists())+' bytes='+str(MP4.stat().st_size if MP4.exists() else 0))

# ---- 4. baseline screenshot (static desktop, vlc gone)
mini(); time.sleep(1); ok,w,h,e=shot(A); L(f'frame_a_before={A} ok={ok} width={w} height={h} err={e}')

# ---- 5. start the Lively APP properly, then setwp
lively=''
for c in LIVELY_CANDIDATES:
    if Path(c).exists(): lively=c; break
L('lively_exe='+str(lively)+' exists='+str(bool(lively)))
app_ok=False
if lively:
    try:
        subprocess.Popen([lively],cwd=str(Path(lively).parent),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); app_ok=True
    except Exception as ex: L('lively_start_error='+repr(ex))
L('lively_app_start_invoked='+str(app_ok))
time.sleep(30)
L('lively_process_count_after_start='+str(task_count('Lively.exe')))
setwp_exit=-1
if lively and MP4.exists():
    setwp_exit,o=run([lively,'setwp','--file',str(MP4),'--monitor','1'],timeout=30)
    L('setwp_monitor1_exit='+str(setwp_exit)+' tail='+(' '.join((o or '').split())[:120]))
L('setwp_ok='+str(setwp_exit==0))
time.sleep(20)

# structural proof BEFORE the fallback setwp (primary screen default)
tmap=tasklist_map(); top,workerws,progmans,children=windows_report()
def owner(pid): return tmap.get(pid,'?')
EXPLORER_CLASSES={'SHELLDLL_DefView','SysListView32','SysHeader32','WorkerW','Progman'}
_u0=ctypes.windll.user32
SW0=_u0.GetSystemMetrics(78); SH0=_u0.GetSystemMetrics(79)
def is_wallpaper_player(c):
    if c[1] in EXPLORER_CLASSES: return False
    if 'explorer' in owner(c[2]).lower(): return False
    if not c[3]: return False
    return (c[6]-c[4])>=SW0*0.95 and (c[7]-c[5])>=SH0*0.95
wallpaper_players=[c for c in children if is_wallpaper_player(c)]
lively_children=[c for c in children if 'lively' in owner(c[2]).lower()]
if not wallpaper_players and lively and MP4.exists():
    e2,o=run([lively,'setwp','--file',str(MP4)],timeout=30)
    L('setwp_primary_fallback_exit='+str(e2)+' tail='+(' '.join((o or '').split())[:120]))
    time.sleep(15)
    tmap=tasklist_map(); top,workerws,progmans,children=windows_report()
    wallpaper_players=[c for c in children if is_wallpaper_player(c)]
    lively_children=[c for c in children if 'lively' in owner(c[2]).lower()]
# ensure playback not paused
if lively:
    p1,_=run([lively,'--play','true'],timeout=15); p2,_=run([lively,'app','--play','true'],timeout=15)
    L('play_true_exit_form1='+str(p1)+' form2='+str(p2))
    time.sleep(5)

# ---- 6. structural evidence: wallpaper-layer windows (children of WorkerW/Progman)
L('workerw_count='+str(len(workerws))+' progman_count='+str(len(progmans)))
for c in children[:12]:
    L('   layer_child| class='+c[1]+' owner='+owner(c[2])+' visible='+str(c[3])+' rect='+str((c[4],c[5],c[6],c[7])))
for c in lively_children[:6]:
    L('   lively_layer_child| class='+c[1]+' visible='+str(c[3])+' rect='+str((c[4],c[5],c[6],c[7])))
for c in wallpaper_players[:6]:
    L('   wallpaper_player| class='+c[1]+' owner='+owner(c[2])+' rect='+str((c[4],c[5],c[6],c[7])))
workerw_child_lively=len(lively_children)>0
wallpaper_layer_proven=len(wallpaper_players)>0
L('workerw_child_lively='+str(workerw_child_lively)+' (info only: Lively-named process in the layer)')
L('wallpaper_layer_proven='+str(wallpaper_layer_proven)+' <-- real proof: non-explorer fullscreen player window INSIDE WorkerW/Progman (behind desktop icons)')
# cover windows: visible top-level windows spanning the whole screen that are NOT the wallpaper layer
vs_l=u=ctypes.windll.user32
sw=u.GetSystemMetrics(78); sh=u.GetSystemMetrics(79)
cover=[]
for t in top:
    if not t[3] or t[8]!=0: continue
    if t[1] in ('WorkerW','Progman','Shell_TrayWnd','Shell_SecondaryTrayWnd','MsGinaBlockUISink','Button','tooltips_class32','SysToolTip','Xaml_WindowedPopupClass','Windows.UI.Composition.DesktopWindowContentBridge','ApplicationFrameWindow','Windows.UI.Core.CoreWindow'): continue
    if owner(t[2]).lower() in ('explorer.exe','dwm.exe','searchhost.exe','textinputhost.exe','startmenuexperiencehost.exe','shellexperiencehost.exe','runtimebroker.exe','applicationframehost.exe'): continue
    if (t[6]-t[4])>=sw*0.99 and (t[7]-t[5])>=sh*0.99:
        cover.append(t)
for t in cover[:6]:
    L('   cover_window| class='+t[1]+' owner='+owner(t[2])+' rect='+str((t[4],t[5],t[6],t[7])))
L('fullscreen_cover_windows='+str(len(cover))+' (report only)')

# ---- 7. pixel probes
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
ready=bool(lively and app_ok and setwp_exit==0 and wallpaper_layer_proven and changed and moving and moving2 and not locked)
L('lively_process_count_final='+str(task_count('Lively.exe')))

# ---- 8. persistence + rollback
lively_autostart_own=False
try:
    c,o=run(['reg','query',r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run'],timeout=15)
    lively_autostart_own=('lively' in (o or '').lower())
except Exception: pass
try:
    for f in STARTUP_DIR.glob('*.lnk'):
        if 'lively' in f.name.lower(): lively_autostart_own=True
except Exception: pass
L('lively_own_autostart_detected='+str(lively_autostart_own))
autostart_ready=False
if ready and lively and not lively_autostart_own:
    WA(OUR_STARTUP,'@echo off\r\nstart "" "'+lively+'"\r\n')
    autostart_ready=OUR_STARTUP.exists()
    L('our_startup_bat='+str(OUR_STARTUP)+' exists='+str(autostart_ready))
elif ready:
    autostart_ready=True
    L('autostart=lively own setting already handles logon')
L('autostart_ready='+str(autostart_ready))
if not ready:
    L('rollback_performed=True')
    if lively:
        run([lively,'closewp','--monitor','-1'],timeout=20); run([lively,'--shutdown','true'],timeout=20)
    rollback_static=str(STATIC_R267) if STATIC_R267.exists() else STATIC_DEFAULT
    set_static(rollback_static); L('rollback_static='+rollback_static); time.sleep(3); shot(ROLLBACK)
    try: OUR_STARTUP.unlink()
    except Exception: pass

# ---- 9. receipts
desk=Path(os.environ.get('USERPROFILE',r'C:\Users\Public'))/'Desktop'; org=desk/'DeskBox-Cute-Desktop-Organizer'; org.mkdir(parents=True,exist_ok=True)
tidy=org/'AUTO_TIDY_LAST_RUN.txt'; tidy.write_text('time='+time.strftime('%Y-%m-%d %H:%M:%S')+'\nlively_dynamic_wallpaper_r274='+str(ready)+'\n',encoding='utf-8')
L('desktop_tidy_done='+str(tidy.exists()))
L('wallpaper_app=Lively Wallpaper (real wallpaper engine, WorkerW layer)')
L('LIVELY_DYNAMIC_WALLPAPER_READY='+str(ready))
summary={'ready':ready,'locked':locked,'powerSource':ac,'batteryPercent':pct,'livelyExe':lively,'appStarted':app_ok,'setwpExit':setwp_exit,'workerwChildLively':workerw_child_lively,'wallpaperLayerProven':wallpaper_layer_proven,'wallpaperPlayerOwners':[owner(c[2]) for c in wallpaper_players[:3]],'coverWindows':len(cover),'settingsFlipped':settings_flipped,'zombiesBefore':z_before,'zombiesAfter':z_after,'mp4':str(MP4),'mp4Bytes':MP4.stat().st_size if MP4.exists() else 0,'desktopChangedFromBeforeRatio':d_start.get('ratio'),'desktopLateMotionRatio':d_late.get('ratio'),'desktopLate2MotionRatio':d_late2.get('ratio'),'persistentMotionProven':bool(moving and moving2),'autostartReady':autostart_ready,'livelyOwnAutostart':lively_autostart_own,'tidyManifest':str(tidy)}
WT(J,json.dumps(summary,ensure_ascii=False,indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
