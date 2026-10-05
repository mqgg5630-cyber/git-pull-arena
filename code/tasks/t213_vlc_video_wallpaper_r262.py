import ctypes, os, sys, time, subprocess, json, shutil, struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'results' / 'mcp_agv_lab'
OUT.mkdir(parents=True, exist_ok=True)
REPORT = OUT / 'R262_PY_VLC_VIDEO_WALLPAPER.md'
JREPORT = OUT / 'r262-py-vlc-video-wallpaper.json'
BEFORE = OUT / 'r262_desktop_before.bmp'
AFTER_A = OUT / 'r262_desktop_after_a.bmp'
AFTER_B = OUT / 'r262_desktop_after_b.bmp'
ROLLBACK = OUT / 'r262_rollback_screenshot.bmp'
LAB = Path(r'E:\0mcp-agv-arena-optimized')
WROOT = LAB / 'wallpapers' / 'py-vlc-anime-live-r262'
WROOT.mkdir(parents=True, exist_ok=True)
MP4 = WROOT / 'anime_girl_beneath_meteor_sky_vlc_r262.mp4'
STATIC = r'C:\Windows\Web\Wallpaper\Windows\img0.jpg'
lines=[]
def L(s):
    print(s)
    lines.append(str(s))
def write_text(path, text):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(text, encoding='utf-8')
def run(args, timeout=120):
    try:
        p=subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout, text=True, errors='replace')
        return p.returncode, p.stdout
    except subprocess.TimeoutExpired as e:
        return -1, 'TIMEOUT ' + (e.stdout or '')
    except Exception as e:
        return 999, repr(e)

def minimize_all():
    try:
        subprocess.run(['powershell.exe','-NoProfile','-Command',"(New-Object -ComObject Shell.Application).MinimizeAll()"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
    except Exception:
        pass

def screenshot_bmp(path):
    user32=ctypes.windll.user32; gdi32=ctypes.windll.gdi32
    SM_XVIRTUALSCREEN=76; SM_YVIRTUALSCREEN=77; SM_CXVIRTUALSCREEN=78; SM_CYVIRTUALSCREEN=79
    x=user32.GetSystemMetrics(SM_XVIRTUALSCREEN); y=user32.GetSystemMetrics(SM_YVIRTUALSCREEN)
    w=user32.GetSystemMetrics(SM_CXVIRTUALSCREEN); h=user32.GetSystemMetrics(SM_CYVIRTUALSCREEN)
    if w <= 0 or h <= 0:
        return False, w, h, 'bad screen size'
    hdc=user32.GetDC(0); mem=gdi32.CreateCompatibleDC(hdc); bmp=gdi32.CreateCompatibleBitmap(hdc,w,h); old=gdi32.SelectObject(mem,bmp)
    SRCCOPY=0x00CC0020
    ok=gdi32.BitBlt(mem,0,0,w,h,hdc,x,y,SRCCOPY)
    if not ok:
        return False,w,h,'BitBlt failed'
    class BITMAPINFOHEADER(ctypes.Structure):
        _fields_=[('biSize',ctypes.c_uint32),('biWidth',ctypes.c_int32),('biHeight',ctypes.c_int32),('biPlanes',ctypes.c_uint16),('biBitCount',ctypes.c_uint16),('biCompression',ctypes.c_uint32),('biSizeImage',ctypes.c_uint32),('biXPelsPerMeter',ctypes.c_int32),('biYPelsPerMeter',ctypes.c_int32),('biClrUsed',ctypes.c_uint32),('biClrImportant',ctypes.c_uint32)]
    class BITMAPINFO(ctypes.Structure):
        _fields_=[('bmiHeader',BITMAPINFOHEADER),('bmiColors',ctypes.c_uint32*3)]
    stride=((w*3+3)//4)*4; size=stride*h
    bi=BITMAPINFO(); bi.bmiHeader.biSize=ctypes.sizeof(BITMAPINFOHEADER); bi.bmiHeader.biWidth=w; bi.bmiHeader.biHeight=-h; bi.bmiHeader.biPlanes=1; bi.bmiHeader.biBitCount=24; bi.bmiHeader.biCompression=0; bi.bmiHeader.biSizeImage=size
    buf=(ctypes.c_ubyte*size)()
    got=gdi32.GetDIBits(mem,bmp,0,h,ctypes.byref(buf),ctypes.byref(bi),0)
    gdi32.SelectObject(mem,old); gdi32.DeleteObject(bmp); gdi32.DeleteDC(mem); user32.ReleaseDC(0,hdc)
    if got == 0:
        return False,w,h,'GetDIBits failed'
    path=Path(path); path.parent.mkdir(parents=True, exist_ok=True)
    off=14+40; fsize=off+size
    with open(path,'wb') as f:
        f.write(b'BM')
        f.write(struct.pack('<IHHI',fsize,0,0,off))
        f.write(struct.pack('<IiiHHIIiiII',40,w,-h,1,24,0,size,0,0,0,0))
        f.write(bytes(buf))
    return True,w,h,''

def bmp_info(path):
    data=Path(path).read_bytes()
    if data[:2]!=b'BM': raise ValueError('not bmp')
    off=struct.unpack_from('<I',data,10)[0]
    w=struct.unpack_from('<i',data,18)[0]; h=struct.unpack_from('<i',data,22)[0]; bpp=struct.unpack_from('<H',data,28)[0]
    topdown=h<0; h=abs(h); stride=((w*(bpp//8)+3)//4)*4
    return data,off,w,h,bpp,topdown,stride

def diff_bmp(a,b):
    try:
        da,oa,wa,ha,ba,ta,sa=bmp_info(a); db,ob,wb,hb,bb,tb,sb=bmp_info(b)
        w=min(wa,wb); h=min(ha,hb); step=max(4, min(w,h)//260); samples=0; changed=0; total=0
        bpa=ba//8; bpb=bb//8
        for y in range(0,h,step):
            ya=y if ta else ha-1-y; yb=y if tb else hb-1-y
            for x in range(0,w,step):
                ia=oa+ya*sa+x*bpa; ib=ob+yb*sb+x*bpb
                ba0,ga,ra=da[ia],da[ia+1],da[ia+2]
                bb0,gb,rb=db[ib],db[ib+1],db[ib+2]
                d=abs(int(ra)-int(rb))+abs(int(ga)-int(gb))+abs(int(ba0)-int(bb0))
                total += d; samples += 1
                if d > 25: changed += 1
        return {'ok':True,'ratio':changed/samples if samples else 0.0,'avg':total/samples if samples else 0.0,'changed':changed,'samples':samples}
    except Exception as e:
        return {'ok':False,'ratio':0.0,'avg':0.0,'changed':0,'samples':0,'err':repr(e)}

def find_vlc():
    for p in [r'C:\Program Files\VideoLAN\VLC\vlc.exe', r'C:\Program Files (x86)\VideoLAN\VLC\vlc.exe']:
        if Path(p).exists(): return p
    q=shutil.which('vlc.exe') or shutil.which('vlc')
    return q or ''

def set_static():
    try:
        ctypes.windll.user32.SystemParametersInfoW(20,0,STATIC,3)
    except Exception:
        pass

def close_lively():
    lively=r'C:\Program Files\Lively Wallpaper\Lively.exe'
    if Path(lively).exists():
        run([lively,'closewp','--monitor','-1'],30)
        run([lively,'--shutdown','true'],30)

def install_vlc_if_needed():
    vlc=find_vlc()
    if vlc: return vlc, False, 0, ''
    winget=shutil.which('winget.exe') or shutil.which('winget')
    if not winget: return '', False, 127, 'winget missing'
    code,out=run([winget,'install','-e','--id','VideoLAN.VLC','--silent','--accept-package-agreements','--accept-source-agreements'],900)
    return find_vlc(), True, code, out

L('# R262 Python VLC video wallpaper')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
locked=False
try:
    code,out=run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'],15)
    locked=('LogonUI.exe' in out)
except Exception:
    locked=False
L('screen_locked_detected='+str(locked))
# Prepare the existing anime MP4.
src=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\existing-anime-live-r254\anime_girl_beneath_meteor_sky_existing_r254.mp4')
if src.exists():
    shutil.copy2(src, MP4)
L('selected_existing_wallpaper=Anime Girl Beneath a Meteor Sky')
L('source_page=https://livelywallpaper.app/live-wallpapers/beautiful-anime-girl-under-starry-sky/')
L('mp4='+str(MP4)+' exists='+str(MP4.exists()))
L('mp4_bytes='+str(MP4.stat().st_size if MP4.exists() else 0))
close_lively()
minimize_all(); time.sleep(1)
ok,w,h,err=screenshot_bmp(BEFORE); L(f'before_screenshot={BEFORE} ok={ok} width={w} height={h} err={err}')
vlc,installed,icode,iout=install_vlc_if_needed()
L('vlc_install_attempted='+str(installed)); L('vlc_install_exit='+str(icode));
if installed: L('vlc_install_tail='+' | '.join((iout or '').splitlines()[-6:]))
L('vlc_exe='+str(vlc)+' exists='+str(Path(vlc).exists() if vlc else False))
start_ok=False
if vlc and Path(vlc).exists() and MP4.exists():
    args=[vlc,'--no-audio','--loop','--repeat','--video-wallpaper','--no-video-title-show','--qt-start-minimized','--qt-system-tray','--no-qt-privacy-ask','--width=1536','--height=864',str(MP4)]
    try:
        subprocess.Popen(args, cwd=str(Path(vlc).parent), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        start_ok=True
    except Exception as e:
        L('vlc_start_error='+repr(e))
L('vlc_start_ok='+str(start_ok))
time.sleep(20); minimize_all(); time.sleep(1)
ok,w,h,err=screenshot_bmp(AFTER_A); L(f'after_a_screenshot={AFTER_A} ok={ok} width={w} height={h} err={err}')
time.sleep(6)
ok,w,h,err=screenshot_bmp(AFTER_B); L(f'after_b_screenshot={AFTER_B} ok={ok} width={w} height={h} err={err}')
d1=diff_bmp(BEFORE,AFTER_A); d2=diff_bmp(AFTER_A,AFTER_B)
L('desktop_changed_from_before_ratio=' + ('%.6f' % d1['ratio']))
L('desktop_changed_from_before_avg=' + ('%.3f' % d1['avg']))
L('desktop_motion_diff_ratio=' + ('%.6f' % d2['ratio']))
L('desktop_motion_diff_avg=' + ('%.3f' % d2['avg']))
code,out=run(['tasklist','/FI','IMAGENAME eq vlc.exe'],15)
vlc_count=out.count('vlc.exe')
L('vlc_process_count='+str(vlc_count))
changed=d1.get('ok') and (d1['ratio']>0.02 or d1['avg']>4.0)
moving=d2.get('ok') and (d2['ratio']>0.0005 or d2['avg']>0.25)
success=bool(start_ok and changed and moving and not locked)
if not success:
    L('rollback_performed=True')
    if vlc and Path(vlc).exists():
        try: subprocess.Popen([vlc,'vlc://quit'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception: pass
    set_static(); time.sleep(3); screenshot_bmp(ROLLBACK)
# Tidy marker only; do not move files during wallpaper recovery.
desk=Path(os.environ.get('USERPROFILE',r'C:\Users\Public'))/'Desktop'
if not desk.exists():
    try: desk=Path.home()/'Desktop'
    except Exception: pass
org=desk/'DeskBox-Cute-Desktop-Organizer'; org.mkdir(parents=True, exist_ok=True)
tidy=org/'AUTO_TIDY_LAST_RUN.txt'; tidy.write_text('time='+time.strftime('%Y-%m-%d %H:%M:%S')+'\npy_vlc_video_wallpaper_r262=True\n',encoding='utf-8')
L('actual_desktop_changed_to_new_wallpaper='+str(bool(changed)))
L('actual_desktop_is_moving='+str(bool(moving)))
L('desktop_tidy_manifest='+str(tidy))
L('desktop_tidy_done='+str(tidy.exists()))
L('R262_PY_VLC_VIDEO_WALLPAPER_READY='+str(success))
summary={'ready':success,'locked':locked,'vlc':vlc,'vlcStarted':start_ok,'mp4':str(MP4),'mp4Bytes':MP4.stat().st_size if MP4.exists() else 0,'before':str(BEFORE),'afterA':str(AFTER_A),'afterB':str(AFTER_B),'rollback':str(ROLLBACK),'desktopChangedFromBeforeRatio':d1.get('ratio'), 'desktopChangedFromBeforeAvg':d1.get('avg'), 'desktopMotionDiffRatio':d2.get('ratio'), 'desktopMotionDiffAvg':d2.get('avg'), 'actualDesktopChangedToNewWallpaper':bool(changed), 'actualDesktopIsMoving':bool(moving), 'vlcProcessCount':vlc_count, 'tidyManifest':str(tidy)}
write_text(JREPORT,json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
W(REPORT,lines)
sys.exit(0 if success else 6)
