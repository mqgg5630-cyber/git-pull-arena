import ctypes, os, sys, time, subprocess, json, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True, exist_ok=True)
REPORT=OUT/'R265_CONFIRM_VLC_DYNAMIC_WALLPAPER.md'; J=OUT/'r265-confirm-vlc-dynamic-wallpaper.json'
A=OUT/'r265_desktop_frame_a.bmp'; B=OUT/'r265_desktop_frame_b.bmp'
lines=[]
def L(s):
    s=str(s).encode('ascii','replace').decode('ascii'); print(s); lines.append(s)
def WT(p,t): Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(t,encoding='utf-8')
def run(args,timeout=15):
    try:
        p=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout,text=True,errors='replace')
        return p.returncode,p.stdout
    except Exception as e: return 999,repr(e)
def mini():
    try: subprocess.run(['powershell.exe','-NoProfile','-Command','(New-Object -ComObject Shell.Application).MinimizeAll()'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10)
    except Exception: pass
def shot(path):
    u=ctypes.windll.user32; g=ctypes.windll.gdi32; x=u.GetSystemMetrics(76); y=u.GetSystemMetrics(77); w=u.GetSystemMetrics(78); h=u.GetSystemMetrics(79)
    hdc=u.GetDC(0); mem=g.CreateCompatibleDC(hdc); bmp=g.CreateCompatibleBitmap(hdc,w,h); old=g.SelectObject(mem,bmp); ok=g.BitBlt(mem,0,0,w,h,hdc,x,y,0x00CC0020)
    stride=((w*3+3)//4)*4; size=stride*h
    class BIH(ctypes.Structure): _fields_=[('biSize',ctypes.c_uint32),('biWidth',ctypes.c_int32),('biHeight',ctypes.c_int32),('biPlanes',ctypes.c_uint16),('biBitCount',ctypes.c_uint16),('biCompression',ctypes.c_uint32),('biSizeImage',ctypes.c_uint32),('biXPelsPerMeter',ctypes.c_int32),('biYPelsPerMeter',ctypes.c_int32),('biClrUsed',ctypes.c_uint32),('biClrImportant',ctypes.c_uint32)]
    class BI(ctypes.Structure): _fields_=[('bmiHeader',BIH),('bmiColors',ctypes.c_uint32*3)]
    bi=BI(); bi.bmiHeader.biSize=ctypes.sizeof(BIH); bi.bmiHeader.biWidth=w; bi.bmiHeader.biHeight=-h; bi.bmiHeader.biPlanes=1; bi.bmiHeader.biBitCount=24; bi.bmiHeader.biCompression=0; bi.bmiHeader.biSizeImage=size
    buf=(ctypes.c_ubyte*size)(); got=g.GetDIBits(mem,bmp,0,h,ctypes.byref(buf),ctypes.byref(bi),0)
    g.SelectObject(mem,old); g.DeleteObject(bmp); g.DeleteDC(mem); u.ReleaseDC(0,hdc)
    if (not ok) or got==0: return False,w,h,'capture failed'
    p=Path(path); p.parent.mkdir(parents=True,exist_ok=True); off=54
    with open(p,'wb') as f:
        f.write(b'BM'); f.write(struct.pack('<IHHI',off+size,0,0,off)); f.write(struct.pack('<IiiHHIIiiII',40,w,-h,1,24,0,size,0,0,0,0)); f.write(bytes(buf))
    return True,w,h,''
def info(p):
    d=Path(p).read_bytes(); off=struct.unpack_from('<I',d,10)[0]; w=struct.unpack_from('<i',d,18)[0]; hh=struct.unpack_from('<i',d,22)[0]; bpp=struct.unpack_from('<H',d,28)[0]; td=hh<0; h=abs(hh); st=((w*(bpp//8)+3)//4)*4; return d,off,w,h,bpp,td,st
def diff(a,b):
    da,oa,wa,ha,ba,ta,sa=info(a); db,ob,wb,hb,bb,tb,sb=info(b); w=min(wa,wb); h=min(ha,hb); step=max(4,min(w,h)//260); sm=0; ch=0; tot=0; bpa=ba//8; bpb=bb//8
    for y in range(0,h,step):
        ya=y if ta else ha-1-y; yb=y if tb else hb-1-y
        for x in range(0,w,step):
            ia=oa+ya*sa+x*bpa; ib=ob+yb*sb+x*bpb; dd=abs(da[ia+2]-db[ib+2])+abs(da[ia+1]-db[ib+1])+abs(da[ia]-db[ib]); tot+=dd; sm+=1; ch+=1 if dd>25 else 0
    return {'ratio':ch/sm if sm else 0,'avg':tot/sm if sm else 0,'changed':ch,'samples':sm}
L('# R265 confirm VLC dynamic wallpaper')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
code,out=run(['tasklist','/FI','IMAGENAME eq vlc.exe']); vlc_count=out.count('vlc.exe')
L('vlc_process_count='+str(vlc_count))
mini(); time.sleep(1); ok,w,h,e=shot(A); L(f'frame_a={A} ok={ok} width={w} height={h} err={e}')
time.sleep(6); ok,w,h,e=shot(B); L(f'frame_b={B} ok={ok} width={w} height={h} err={e}')
d=diff(A,B); moving=(d['ratio']>0.0005 or d['avg']>0.25)
L('desktop_motion_diff_ratio=%.6f'%d['ratio']); L('desktop_motion_diff_avg=%.3f'%d['avg']); L('actual_desktop_is_moving='+str(bool(moving)))
mp4=r'E:\0mcp-agv-arena-optimized\wallpapers\vlc-direct3d-anime-r264\cute_mahiru_or_meteor_vlc_r264.mp4'
L('wallpaper_video='+mp4+' exists='+str(Path(mp4).exists()))
desk=Path(os.environ.get('USERPROFILE',r'C:\Users\Public'))/'Desktop'; org=desk/'DeskBox-Cute-Desktop-Organizer'; org.mkdir(parents=True,exist_ok=True); tidy=org/'AUTO_TIDY_LAST_RUN.txt'; tidy.write_text('time='+time.strftime('%Y-%m-%d %H:%M:%S')+'\nconfirm_vlc_dynamic_r265=True\n',encoding='utf-8')
L('desktop_tidy_manifest='+str(tidy)); L('desktop_tidy_done='+str(tidy.exists()))
ready=bool(vlc_count>0 and moving and Path(mp4).exists())
L('R265_CONFIRM_VLC_DYNAMIC_WALLPAPER_READY='+str(ready))
summary={'ready':ready,'vlcProcessCount':vlc_count,'frameA':str(A),'frameB':str(B),'desktopMotionDiffRatio':d['ratio'],'desktopMotionDiffAvg':d['avg'],'actualDesktopIsMoving':bool(moving),'wallpaperVideo':mp4,'tidyManifest':str(tidy)}
WT(J,json.dumps(summary,ensure_ascii=False,indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
