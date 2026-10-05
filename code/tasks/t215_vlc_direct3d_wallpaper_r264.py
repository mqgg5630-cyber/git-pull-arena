import ctypes, os, sys, time, subprocess, json, shutil, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True, exist_ok=True)
REPORT=OUT/'R264_VLC_DIRECT3D_WALLPAPER.md'; JREPORT=OUT/'r264-vlc-direct3d-wallpaper.json'
BEFORE=OUT/'r264_desktop_before.bmp'; A=OUT/'r264_desktop_after_a.bmp'; B=OUT/'r264_desktop_after_b.bmp'; ROLLBACK=OUT/'r264_rollback_screenshot.bmp'
WROOT=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\vlc-direct3d-anime-r264'); WROOT.mkdir(parents=True, exist_ok=True)
MP4=WROOT/'cute_mahiru_or_meteor_vlc_r264.mp4'; STATIC=r'C:\Windows\Web\Wallpaper\Windows\img0.jpg'
lines=[]
def L(s):
    safe=str(s).encode('ascii','replace').decode('ascii'); print(safe); lines.append(safe)
def WT(p,t): Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(t,encoding='utf-8')
def run(args,timeout=120):
    try:
        p=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout,text=True,errors='replace')
        return p.returncode,p.stdout
    except subprocess.TimeoutExpired as e:
        return -1,'TIMEOUT '+str(e.stdout or '')
    except Exception as e:
        return 999,repr(e)
def mini():
    try: subprocess.run(['powershell.exe','-NoProfile','-Command','(New-Object -ComObject Shell.Application).MinimizeAll()'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10)
    except Exception: pass
def shot(path):
    try:
        u=ctypes.windll.user32; g=ctypes.windll.gdi32; x=u.GetSystemMetrics(76); y=u.GetSystemMetrics(77); w=u.GetSystemMetrics(78); h=u.GetSystemMetrics(79)
        hdc=u.GetDC(0); mem=g.CreateCompatibleDC(hdc); bmp=g.CreateCompatibleBitmap(hdc,w,h); old=g.SelectObject(mem,bmp)
        if not g.BitBlt(mem,0,0,w,h,hdc,x,y,0x00CC0020): return False,w,h,'BitBlt'
        stride=((w*3+3)//4)*4; size=stride*h
        class BIH(ctypes.Structure): _fields_=[('biSize',ctypes.c_uint32),('biWidth',ctypes.c_int32),('biHeight',ctypes.c_int32),('biPlanes',ctypes.c_uint16),('biBitCount',ctypes.c_uint16),('biCompression',ctypes.c_uint32),('biSizeImage',ctypes.c_uint32),('biXPelsPerMeter',ctypes.c_int32),('biYPelsPerMeter',ctypes.c_int32),('biClrUsed',ctypes.c_uint32),('biClrImportant',ctypes.c_uint32)]
        class BI(ctypes.Structure): _fields_=[('bmiHeader',BIH),('bmiColors',ctypes.c_uint32*3)]
        bi=BI(); bi.bmiHeader.biSize=ctypes.sizeof(BIH); bi.bmiHeader.biWidth=w; bi.bmiHeader.biHeight=-h; bi.bmiHeader.biPlanes=1; bi.bmiHeader.biBitCount=24; bi.bmiHeader.biCompression=0; bi.bmiHeader.biSizeImage=size
        buf=(ctypes.c_ubyte*size)(); got=g.GetDIBits(mem,bmp,0,h,ctypes.byref(buf),ctypes.byref(bi),0)
        g.SelectObject(mem,old); g.DeleteObject(bmp); g.DeleteDC(mem); u.ReleaseDC(0,hdc)
        if got==0: return False,w,h,'GetDIBits'
        path=Path(path); path.parent.mkdir(parents=True,exist_ok=True); off=54; fsize=off+size
        with open(path,'wb') as f:
            f.write(b'BM'); f.write(struct.pack('<IHHI',fsize,0,0,off)); f.write(struct.pack('<IiiHHIIiiII',40,w,-h,1,24,0,size,0,0,0,0)); f.write(bytes(buf))
        return True,w,h,''
    except Exception as e: return False,0,0,repr(e)
def info(p):
    d=Path(p).read_bytes(); off=struct.unpack_from('<I',d,10)[0]; w=struct.unpack_from('<i',d,18)[0]; hh=struct.unpack_from('<i',d,22)[0]; bpp=struct.unpack_from('<H',d,28)[0]; td=hh<0; h=abs(hh); st=((w*(bpp//8)+3)//4)*4; return d,off,w,h,bpp,td,st
def diff(a,b):
    try:
        da,oa,wa,ha,ba,ta,sa=info(a); db,ob,wb,hb,bb,tb,sb=info(b); w=min(wa,wb); h=min(ha,hb); step=max(4,min(w,h)//260); sm=0; ch=0; tot=0; bpa=ba//8; bpb=bb//8
        for y in range(0,h,step):
            ya=y if ta else ha-1-y; yb=y if tb else hb-1-y
            for x in range(0,w,step):
                ia=oa+ya*sa+x*bpa; ib=ob+yb*sb+x*bpb; d=abs(da[ia+2]-db[ib+2])+abs(da[ia+1]-db[ib+1])+abs(da[ia]-db[ib]); tot+=d; sm+=1; ch+=1 if d>25 else 0
        return {'ok':True,'ratio':ch/sm if sm else 0,'avg':tot/sm if sm else 0,'changed':ch,'samples':sm}
    except Exception as e: return {'ok':False,'ratio':0,'avg':0,'err':repr(e)}
def vlc_path():
    for p in [r'C:\Program Files\VideoLAN\VLC\vlc.exe',r'C:\Program Files (x86)\VideoLAN\VLC\vlc.exe']:
        if Path(p).exists(): return p
    return shutil.which('vlc.exe') or ''
def install_vlc():
    v=vlc_path()
    if v: return v,False,0,''
    w=shutil.which('winget.exe') or shutil.which('winget')
    if not w: return '',False,127,'winget missing'
    c,o=run([w,'install','-e','--id','VideoLAN.VLC','--silent','--accept-package-agreements','--accept-source-agreements'],900)
    return vlc_path(),True,c,o
def set_static():
    try: ctypes.windll.user32.SystemParametersInfoW(20,0,STATIC,3)
    except Exception: pass
L('# R264 VLC Direct3D video wallpaper')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
c,o=run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'],15); locked='LogonUI.exe' in o; L('screen_locked_detected='+str(locked))
for s in [Path(r'E:\0mcp-agv-arena-optimized\wallpapers\existing-anime-live-r255\golden_afternoon_mahiru_shiina_existing_r255.mp4'),Path(r'E:\0mcp-agv-arena-optimized\wallpapers\existing-anime-live-r254\anime_girl_beneath_meteor_sky_existing_r254.mp4')]:
    if s.exists(): shutil.copy2(s,MP4); break
L('selected_existing_wallpaper=Golden Afternoon With Mahiru Shiina if available, otherwise Anime Girl Beneath a Meteor Sky')
L('mp4='+str(MP4)+' exists='+str(MP4.exists())); L('mp4_bytes='+str(MP4.stat().st_size if MP4.exists() else 0))
# Ask Lively to close politely; no custom host used.
lively=r'C:\Program Files\Lively Wallpaper\Lively.exe'
if Path(lively).exists(): run([lively,'closewp','--monitor','-1'],20); run([lively,'--shutdown','true'],20)
mini(); time.sleep(1); ok,w,h,e=shot(BEFORE); L(f'before_screenshot={BEFORE} ok={ok} width={w} height={h} err={e}')
vlc,inst,ic,io=install_vlc(); L('vlc_install_attempted='+str(inst)); L('vlc_install_exit='+str(ic)); L('vlc_exe='+str(vlc)+' exists='+str(Path(vlc).exists() if vlc else False))
start=False
if vlc and Path(vlc).exists() and MP4.exists():
    url='file:///'+str(MP4).replace('\\','/')
    argsets=[['--direct3d11-hw-blending','--video-wallpaper','--loop','--no-audio','--no-video-title-show','--qt-start-minimized','--no-qt-privacy-ask',url],['--directx-hw-yuv','--video-wallpaper','--loop','--no-audio','--no-video-title-show','--qt-start-minimized','--no-qt-privacy-ask',url]]
    for args in argsets:
        try:
            subprocess.Popen([vlc]+args,cwd=str(Path(vlc).parent),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); start=True; L('vlc_started_args='+' '.join(args[:4])); time.sleep(12); break
        except Exception as ex: L('vlc_start_error='+repr(ex))
L('vlc_start_ok='+str(start))
time.sleep(12); mini(); time.sleep(1); ok,w,h,e=shot(A); L(f'after_a_screenshot={A} ok={ok} width={w} height={h} err={e}')
time.sleep(6); ok,w,h,e=shot(B); L(f'after_b_screenshot={B} ok={ok} width={w} height={h} err={e}')
d1=diff(BEFORE,A); d2=diff(A,B); L('desktop_changed_from_before_ratio=%.6f'%d1['ratio']); L('desktop_changed_from_before_avg=%.3f'%d1['avg']); L('desktop_motion_diff_ratio=%.6f'%d2['ratio']); L('desktop_motion_diff_avg=%.3f'%d2['avg'])
c,o=run(['tasklist','/FI','IMAGENAME eq vlc.exe'],15); vc=o.count('vlc.exe'); L('vlc_process_count='+str(vc))
changed=d1.get('ok') and (d1['ratio']>0.02 or d1['avg']>4); moving=d2.get('ok') and (d2['ratio']>0.0005 or d2['avg']>0.25); success=bool(start and changed and moving and not locked)
if not success:
    L('rollback_performed=True')
    if vlc and Path(vlc).exists():
        try: subprocess.Popen([vlc,'vlc://quit'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        except Exception: pass
    set_static(); time.sleep(3); shot(ROLLBACK)
desk=Path(os.environ.get('USERPROFILE',r'C:\Users\Public'))/'Desktop'; org=desk/'DeskBox-Cute-Desktop-Organizer'; org.mkdir(parents=True,exist_ok=True); tidy=org/'AUTO_TIDY_LAST_RUN.txt'; tidy.write_text('time='+time.strftime('%Y-%m-%d %H:%M:%S')+'\nvlc_direct3d_wallpaper_r264=True\n',encoding='utf-8')
L('actual_desktop_changed_to_new_wallpaper='+str(bool(changed))); L('actual_desktop_is_moving='+str(bool(moving))); L('desktop_tidy_manifest='+str(tidy)); L('desktop_tidy_done='+str(tidy.exists())); L('R264_VLC_DIRECT3D_WALLPAPER_READY='+str(success))
summary={'ready':success,'locked':locked,'vlc':vlc,'vlcStarted':start,'mp4':str(MP4),'mp4Bytes':MP4.stat().st_size if MP4.exists() else 0,'before':str(BEFORE),'afterA':str(A),'afterB':str(B),'rollback':str(ROLLBACK),'desktopChangedFromBeforeRatio':d1.get('ratio'),'desktopChangedFromBeforeAvg':d1.get('avg'),'desktopMotionDiffRatio':d2.get('ratio'),'desktopMotionDiffAvg':d2.get('avg'),'actualDesktopChangedToNewWallpaper':bool(changed),'actualDesktopIsMoving':bool(moving),'vlcProcessCount':vc,'tidyManifest':str(tidy)}
WT(JREPORT,json.dumps(summary,ensure_ascii=False,indent=2)+'\n'); W(REPORT,lines); sys.exit(0 if success else 6)
