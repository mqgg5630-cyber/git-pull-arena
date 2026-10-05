import ctypes, os, sys, time, subprocess, json, shutil, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R266_PERSISTENT_VLC_DYNAMIC_WALLPAPER.md'; J=OUT/'r266-persistent-vlc-dynamic-wallpaper.json'
A=OUT/'r266_frame_a.bmp'; B=OUT/'r266_frame_b.bmp'; C=OUT/'r266_frame_c_late.bmp'; D=OUT/'r266_frame_d_late.bmp'; ROLLBACK=OUT/'r266_rollback.bmp'
WROOT=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\persistent-vlc-anime-r266'); WROOT.mkdir(parents=True,exist_ok=True)
MP4=WROOT/'cute_anime_persistent_vlc_r266.mp4'; STATIC=r'C:\Windows\Web\Wallpaper\Windows\img0.jpg'
lines=[]
def L(s):
    s=str(s).encode('ascii','replace').decode('ascii'); print(s); lines.append(s)
def WT(p,t): Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(t,encoding='utf-8')
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
def set_static():
    try: ctypes.windll.user32.SystemParametersInfoW(20,0,STATIC,3)
    except Exception: pass
def vlc_path():
    for p in [r'C:\Program Files\VideoLAN\VLC\vlc.exe',r'C:\Program Files (x86)\VideoLAN\VLC\vlc.exe']:
        if Path(p).exists(): return p
    return shutil.which('vlc.exe') or ''
def task_count(name):
    c,o=run(['tasklist','/FI',f'IMAGENAME eq {name}']); return o.count(name)
L('# R266 persistent VLC dynamic wallpaper')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
# choose cute Mahiru first
for src in [Path(r'E:\0mcp-agv-arena-optimized\wallpapers\existing-anime-live-r255\golden_afternoon_mahiru_shiina_existing_r255.mp4'),Path(r'E:\0mcp-agv-arena-optimized\wallpapers\existing-anime-live-r254\anime_girl_beneath_meteor_sky_existing_r254.mp4')]:
    if src.exists(): shutil.copy2(src,MP4); break
L('selected_existing_wallpaper=Golden Afternoon With Mahiru Shiina if available')
L('mp4='+str(MP4)+' exists='+str(MP4.exists())); L('mp4_bytes='+str(MP4.stat().st_size if MP4.exists() else 0))
# close stale apps politely
vlc=vlc_path();
if vlc: subprocess.Popen([vlc,'vlc://quit'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); time.sleep(2)
lively=r'C:\Program Files\Lively Wallpaper\Lively.exe'
if Path(lively).exists(): run([lively,'closewp','--monitor','-1']); run([lively,'--shutdown','true'])
mini(); time.sleep(1); ok,w,h,e=shot(A); L(f'frame_a_before_start={A} ok={ok} width={w} height={h} err={e}')
L('vlc_exe='+str(vlc)+' exists='+str(Path(vlc).exists() if vlc else False))
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
time.sleep(25); mini(); time.sleep(1); ok,w,h,e=shot(B); L(f'frame_b_after_start={B} ok={ok} width={w} height={h} err={e}')
time.sleep(75); ok,w,h,e=shot(C); L(f'frame_c_late={C} ok={ok} width={w} height={h} err={e}')
time.sleep(6); ok,w,h,e=shot(D); L(f'frame_d_late={D} ok={ok} width={w} height={h} err={e}')
d_start=diff(A,B); d_late=diff(C,D)
L('desktop_changed_from_before_ratio=%.6f'%d_start['ratio']); L('desktop_changed_from_before_avg=%.3f'%d_start['avg']); L('desktop_late_motion_ratio=%.6f'%d_late['ratio']); L('desktop_late_motion_avg=%.3f'%d_late['avg'])
vc=task_count('vlc.exe'); L('vlc_process_count_late='+str(vc))
changed=d_start.get('ok') and (d_start['ratio']>0.02 or d_start['avg']>4); moving=d_late.get('ok') and (d_late['ratio']>0.0005 or d_late['avg']>0.25); ready=bool(start and changed and moving and vc>0 and not locked)
if not ready:
    L('rollback_performed=True')
    if vlc: subprocess.Popen([vlc,'vlc://quit'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    set_static(); time.sleep(3); shot(ROLLBACK)
desk=Path(os.environ.get('USERPROFILE',r'C:\Users\Public'))/'Desktop'; org=desk/'DeskBox-Cute-Desktop-Organizer'; org.mkdir(parents=True,exist_ok=True); tidy=org/'AUTO_TIDY_LAST_RUN.txt'; tidy.write_text('time='+time.strftime('%Y-%m-%d %H:%M:%S')+'\npersistent_vlc_dynamic_r266=True\n',encoding='utf-8')
L('actual_desktop_changed_to_new_wallpaper='+str(bool(changed))); L('actual_desktop_is_moving_late='+str(bool(moving))); L('desktop_tidy_manifest='+str(tidy)); L('desktop_tidy_done='+str(tidy.exists())); L('R266_PERSISTENT_VLC_DYNAMIC_WALLPAPER_READY='+str(ready))
summary={'ready':ready,'locked':locked,'vlcStarted':start,'vlcProcessCountLate':vc,'mp4':str(MP4),'mp4Bytes':MP4.stat().st_size if MP4.exists() else 0,'frameA':str(A),'frameB':str(B),'frameC':str(C),'frameD':str(D),'desktopChangedFromBeforeRatio':d_start.get('ratio'),'desktopChangedFromBeforeAvg':d_start.get('avg'),'desktopLateMotionRatio':d_late.get('ratio'),'desktopLateMotionAvg':d_late.get('avg'),'actualDesktopChangedToNewWallpaper':bool(changed),'actualDesktopIsMovingLate':bool(moving),'tidyManifest':str(tidy)}
WT(J,json.dumps(summary,ensure_ascii=False,indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
