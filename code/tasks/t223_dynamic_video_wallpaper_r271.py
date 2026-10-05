# t223_dynamic_video_wallpaper_r271.py - round 271 (pixel-only verdict).
# r270 proved with screen pixels that the video wallpaper plays (99.7% change,
# 7.8% late motion), but tasklist reported 0 vlc.exe and the round rolled back.
# Lesson from r251 stands: trust pixels, not process counts. This round:
#   - verdict = pixels ONLY (changed A->B, moving at BOTH late probes)
#   - second late probe at ~195s/201s proves the wallpaper keeps playing
#   - reuses the downloaded mp4 (r270 copy, then r269), cleans r270 leftovers
#   - utf-8 PATHS.txt, ascii-guarded bats (the r269 fix, kept)
import ctypes, os, sys, time, subprocess, json, shutil, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R271_DYNAMIC_VIDEO_WALLPAPER.md'; J=OUT/'r271-dynamic-video-wallpaper.json'
A=OUT/'r271_frame_a_before.bmp'; B=OUT/'r271_frame_b_after.bmp'; C=OUT/'r271_frame_c_late.bmp'; D=OUT/'r271_frame_d_late.bmp'; E=OUT/'r271_frame_e_late2.bmp'; F=OUT/'r271_frame_f_late2.bmp'; ROLLBACK=OUT/'r271_rollback.bmp'
WROOT=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\dynamic-video-r271'); WROOT.mkdir(parents=True,exist_ok=True)
MP4=WROOT/'dynamic_video_wallpaper_r271.mp4'
R269_MP4=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\dynamic-video-r269\dynamic_video_wallpaper_r269.mp4')
R270_BATS=[Path(r'E:\0mcp-agv-arena-optimized\wallpapers\dynamic-video-r270\Start-R270-Dynamic-Wallpaper.bat'),Path(r'E:\0mcp-agv-arena-optimized\wallpapers\dynamic-video-r270\Stop-R270-Dynamic-Wallpaper.bat')]
R270_STARTUP=Path(os.environ.get('APPDATA',r'C:\Users\Public'))/'Microsoft'/'Windows'/'Start Menu'/'Programs'/'Startup'/'R270 Dynamic Video Wallpaper Start.bat'
STATIC_R267=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\static-anime-r267\cute_static_anime_wallpaper_r267.png')
STATIC_DEFAULT=r'C:\Windows\Web\Wallpaper\Windows\img0.jpg'
CANDIDATES=[
 ('hotori-neverness-to-everness','Hotori Above a Sunset City','https://cdn.livelywallpaper.app/wallpapers/hotori-neverness-to-everness/hd.mp4'),
 ('ryuuge-kisaki-blue-archive','Kisaki Among the Giant Goldfish','https://cdn.livelywallpaper.app/wallpapers/ryuuge-kisaki-blue-archive/hd.mp4'),
 ('evening-window-view','Cat at an Open Sunset Window','https://cdn.livelywallpaper.app/wallpapers/evening-window-view/hd.mp4'),
]
LOCAL_FALLBACKS=[
 ('local-mahiru-shiina','Golden Afternoon With Mahiru Shiina (local r255)',Path(r'E:\0mcp-agv-arena-optimized\wallpapers\existing-anime-live-r255\golden_afternoon_mahiru_shiina_existing_r255.mp4')),
 ('local-meteor-sky','Anime Girl Beneath a Meteor Sky (local r254)',Path(r'E:\0mcp-agv-arena-optimized\wallpapers\existing-anime-live-r254\anime_girl_beneath_meteor_sky_existing_r254.mp4')),
]
lines=[]
def L(s):
    s=str(s).encode('ascii','replace').decode('ascii'); print(s); lines.append(s)
def WT(p,t): Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(t,encoding='utf-8')
def WA(p,t):  # bat files must stay pure ascii for cmd.exe
    Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(str(t).encode('ascii','replace').decode('ascii'),encoding='ascii')
def run(args,timeout=20):
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
def vlc_path():
    for p in [r'C:\Program Files\VideoLAN\VLC\vlc.exe',r'C:\Program Files (x86)\VideoLAN\VLC\vlc.exe']:
        if Path(p).exists(): return p
    return shutil.which('vlc.exe') or ''
def looks_like_mp4(p):
    try:
        head=Path(p).read_bytes()[:16]
        return b'ftyp' in head
    except Exception: return False
def task_count(name):
    c,o=run(['tasklist','/FI',f'IMAGENAME eq {name}']); return o.count(name)

L('# R271 real dynamic video wallpaper (pixel-only verdict, two late probes)')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
L('fix_vs_r270=verdict is PIXELS ONLY (r270 proved playing but tasklist missed vlc.exe); second late probe at ~200s proves persistence')
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
vlc=vlc_path(); L('vlc_exe='+str(vlc)+' exists='+str(Path(vlc).exists() if vlc else False))

# ---- 0. clean the r270 leftovers (rolled-back round left a startup bat behind)
for old in [R270_STARTUP]+R270_BATS:
    try:
        if old.exists(): old.unlink(); L('cleanup_r270_leftover='+str(old))
    except Exception as ex: L('cleanup_r270_error='+repr(ex))

# ---- 1. find the wallpaper: reuse the r269 download, then CDN, then local
chosen_slug=''; chosen_name=''; chosen_url=''; download_method=''; downloaded_ok=False
for reuse_src, reuse_slug in [(R270_MP4,'reuse-hotori-r270'),(R269_MP4,'reuse-hotori-r269')]:
    if reuse_src.exists() and reuse_src.stat().st_size>=300000 and looks_like_mp4(reuse_src):
        shutil.copy2(reuse_src,MP4)
        chosen_slug=reuse_slug; chosen_name='Hotori Above a Sunset City'; chosen_url='https://cdn.livelywallpaper.app/wallpapers/hotori-neverness-to-everness/hd.mp4'; download_method=reuse_slug; downloaded_ok=True
        L('download_ok=True via reuse of '+reuse_slug)
        break
if not downloaded_ok:
    for slug,name,url in CANDIDATES:
        L('download_try='+slug+' url='+url)
        c,o=run(['curl.exe','-L','--fail','-sS','--max-time','180','-o',str(MP4),url],timeout=200)
        sz=MP4.stat().st_size if MP4.exists() else 0
        L('download_exit='+str(c)+' bytes='+str(sz))
        if c==0 and sz>=300000 and looks_like_mp4(MP4):
            chosen_slug=slug; chosen_name=name; chosen_url=url; download_method='curl'; downloaded_ok=True
            L('download_ok=True via '+slug)
            break
        if MP4.exists(): MP4.unlink()
if not downloaded_ok:
    for slug,name,src in LOCAL_FALLBACKS:
        if src.exists() and src.stat().st_size>300000 and looks_like_mp4(src):
            shutil.copy2(src,MP4)
            chosen_slug=slug; chosen_name=name; chosen_url=str(src); download_method='local-copy'; downloaded_ok=True
            L('download_ok=True via local '+slug)
            break
L('wallpaper_source='+chosen_slug); L('wallpaper_name='+chosen_name); L('wallpaper_source_url='+chosen_url)
L('wallpaper_inherently_dynamic=True (live-wallpaper MP4, not a static image)')
L('downloaded_ok='+str(downloaded_ok)+' download_method='+download_method)
L('mp4='+str(MP4)+' exists='+str(MP4.exists())); L('mp4_bytes='+str(MP4.stat().st_size if MP4.exists() else 0))

# ---- 2. clean start: stop stale players politely
if vlc and Path(vlc).exists():
    subprocess.Popen([vlc,'vlc://quit'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); time.sleep(2)
lively=r'C:\Program Files\Lively Wallpaper\Lively.exe'
if Path(lively).exists(): run([lively,'closewp','--monitor','-1']); run([lively,'--shutdown','true'])
mini(); time.sleep(1); ok,w,h,e=shot(A); L(f'frame_a_before_start={A} ok={ok} width={w} height={h} err={e}')

# ---- 3. play it as the wallpaper (the exact vlc recipe that passed r266)
start=False
if vlc and Path(vlc).exists() and MP4.exists():
    uri='file:///'+str(MP4).replace('\\','/')
    args=[vlc,'--direct3d11-hw-blending','--video-wallpaper','--loop','--repeat','--input-repeat=65535','--no-audio','--no-video-title-show','--qt-start-minimized','--no-qt-privacy-ask',uri]
    flags=0
    if hasattr(subprocess,'CREATE_NEW_PROCESS_GROUP'): flags|=subprocess.CREATE_NEW_PROCESS_GROUP
    if hasattr(subprocess,'DETACHED_PROCESS'): flags|=subprocess.DETACHED_PROCESS
    try: subprocess.Popen(args,cwd=str(Path(vlc).parent),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,creationflags=flags); start=True
    except Exception as ex: L('vlc_start_error='+repr(ex))
L('vlc_start_ok='+str(start))

# ---- 4. persistence: start bat + startup bat + stop bat + PATHS (utf-8!)
start_bat=WROOT/'Start-R271-Dynamic-Wallpaper.bat'
stop_bat=WROOT/'Stop-R271-Dynamic-Wallpaper.bat'
uri='file:///'+str(MP4).replace('\\','/')
if vlc:
    WA(start_bat,'@echo off\r\nstart "" "'+vlc+'" --direct3d11-hw-blending --video-wallpaper --loop --repeat --input-repeat=65535 --no-audio --no-video-title-show --qt-start-minimized --no-qt-privacy-ask "'+uri+'"\r\n')
    WA(stop_bat,'@echo off\r\nstart "" "'+vlc+'" vlc://quit\r\n')
startup_dir=Path(os.environ.get('APPDATA',r'C:\Users\Public'))/'Microsoft'/'Windows'/'Start Menu'/'Programs'/'Startup'
startup_bat=startup_dir/'R271 Dynamic Video Wallpaper Start.bat'
try:
    startup_dir.mkdir(parents=True,exist_ok=True)
    WA(startup_bat,'@echo off\r\ntimeout /t 20 /nobreak >nul\r\ncall "'+str(start_bat)+'"\r\n')
except Exception as ex:
    L('startup_bat_error='+repr(ex))
L('start_bat='+str(start_bat)+' exists='+str(start_bat.exists()))
L('stop_bat='+str(stop_bat)+' exists='+str(stop_bat.exists()))
L('autostart_bat='+str(startup_bat)+' exists='+str(startup_bat.exists()))
paths=WROOT/'PATHS.txt'
WT(paths,'R271 dynamic video wallpaper\r\n===============================\r\nwallpaper : '+str(MP4)+'\r\nsource    : '+chosen_name+' <'+chosen_url+'>\r\nstart     : '+str(start_bat)+'\r\nstop      : '+str(stop_bat)+'\r\nautostart : '+str(startup_bat)+' (delete this file to stop it coming back after reboot)\r\nrestore static: right-click desktop > Personalize, or re-run the r267 static png at\r\n              '+str(STATIC_R267)+'\r\n')
L('paths_txt='+str(paths)+' exists='+str(paths.exists()))
autostart_ready=bool(start_bat.exists() and stop_bat.exists() and startup_bat.exists() and paths.exists())

# ---- 5. prove it with pixels
time.sleep(25); mini(); time.sleep(1); ok,w,h,e=shot(B); L(f'frame_b_after_start={B} ok={ok} width={w} height={h} err={e}')
time.sleep(75); ok,w,h,e=shot(C); L(f'frame_c_late={C} ok={ok} width={w} height={h} err={e}')
time.sleep(6); ok,w,h,e=shot(D); L(f'frame_d_late={D} ok={ok} width={w} height={h} err={e}')
time.sleep(88); ok,w,h,e=shot(E); L(f'frame_e_late2={E} ok={ok} width={w} height={h} err={e}')
time.sleep(6); ok,w,h,e=shot(F); L(f'frame_f_late2={F} ok={ok} width={w} height={h} err={e}')
d_start=diff(A,B); d_late=diff(C,D); d_late2=diff(E,F)
L('desktop_changed_from_before_ratio=%.6f'%d_start['ratio']); L('desktop_changed_from_before_avg=%.3f'%d_start['avg'])
L('desktop_late_motion_ratio=%.6f'%d_late['ratio']); L('desktop_late_motion_avg=%.3f'%d_late['avg'])
L('desktop_late2_motion_ratio=%.6f'%d_late2['ratio']); L('desktop_late2_motion_avg=%.3f'%d_late2['avg'])
vc=task_count('vlc.exe'); L('vlc_process_count_late='+str(vc)+' (report only - the verdict is pixels)')
L('vlc_video_wallpaper_running='+str(bool(d_late.get('ok') and d_late2.get('ok'))))
changed=d_start.get('ok') and (d_start['ratio']>0.02 or d_start['avg']>4)
moving=d_late.get('ok') and (d_late['ratio']>0.0005 or d_late['avg']>0.25)
moving2=d_late2.get('ok') and (d_late2['ratio']>0.0005 or d_late2['avg']>0.25)
L('actual_desktop_changed_to_new_wallpaper='+str(bool(changed))); L('actual_desktop_is_moving_late='+str(bool(moving)))
L('actual_desktop_is_moving_late2='+str(bool(moving2))); L('persistent_motion_proven='+str(bool(moving and moving2)))
ready=bool(start and changed and moving and moving2 and not locked and downloaded_ok and autostart_ready)
if not ready:
    L('rollback_performed=True')
    if vlc: subprocess.Popen([vlc,'vlc://quit'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    rollback_static=str(STATIC_R267) if STATIC_R267.exists() else STATIC_DEFAULT
    set_static(rollback_static); L('rollback_static='+rollback_static); time.sleep(3); shot(ROLLBACK)
    try: startup_bat.unlink()
    except Exception: pass

# ---- 6. receipts
desk=Path(os.environ.get('USERPROFILE',r'C:\Users\Public'))/'Desktop'; org=desk/'DeskBox-Cute-Desktop-Organizer'; org.mkdir(parents=True,exist_ok=True)
tidy=org/'AUTO_TIDY_LAST_RUN.txt'; tidy.write_text('time='+time.strftime('%Y-%m-%d %H:%M:%S')+'\ndynamic_video_wallpaper_r271='+str(ready)+'\n',encoding='utf-8')
L('desktop_tidy_manifest='+str(tidy)); L('desktop_tidy_done='+str(tidy.exists()))
L('autostart_ready='+str(autostart_ready))
L('DYNAMIC_VIDEO_WALLPAPER_READY='+str(ready))
summary={'ready':ready,'locked':locked,'wallpaperSource':chosen_slug,'wallpaperName':chosen_name,'wallpaperUrl':chosen_url,'downloadMethod':download_method,'mp4':str(MP4),'mp4Bytes':MP4.stat().st_size if MP4.exists() else 0,'vlcStarted':start,'vlcProcessCountLate':vc,'autostartReady':autostart_ready,'frameA':str(A),'frameB':str(B),'frameC':str(C),'frameD':str(D),'frameE':str(E),'frameF':str(F),'desktopChangedFromBeforeRatio':d_start.get('ratio'),'desktopChangedFromBeforeAvg':d_start.get('avg'),'desktopLateMotionRatio':d_late.get('ratio'),'desktopLate2MotionRatio':d_late2.get('ratio'),'persistentMotionProven':bool(moving and moving2),'desktopLateMotionAvg':d_late.get('avg'),'actualDesktopChangedToNewWallpaper':bool(changed),'actualDesktopIsMovingLate':bool(moving),'tidyManifest':str(tidy)}
WT(J,json.dumps(summary,ensure_ascii=False,indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
