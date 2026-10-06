# t250_screenshot_verify2_r299.py - round 299.
# r297 spawned mpv --wid=67222 successfully but the EnumChildWindows check
# could not see it: in --wid mode mpv renders DIRECTLY onto the target hwnd
# and creates no child window of its own. The desktop may already be alive.
# This round verifies with actual SCREEN CAPTURES and re-embeds with the
# canonical WorkerW (the GW_HWNDNEXT sibling of SHELLDLL_DefView) if needed.
# Boxes untouched; nothing deleted.
import ctypes, sys, time, subprocess, json, threading
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R299_SCREENSHOT_VERIFY2.md'; J=OUT/'r299-screenshot-verify2.json'
DBOX=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
L12=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\lively-12')
MPV=r'C:\Program Files\Lively Wallpaper\plugins\mpv\mpv.exe'
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
    if t.is_alive(): L('guard_timeout %s (%ds)'%(tag,timeout_s)); return None
    if 'err' in box: L('guard_error %s: %s'%(tag,box['err']))
    return box.get('r')

gdi=ctypes.windll.g32 if hasattr(ctypes.windll,'g32') else ctypes.windll.gdi32
u=ctypes.windll.user32
import ctypes.wintypes as wt
class BMIH(ctypes.Structure):
    _fields_=[('biSize',ctypes.c_uint32),('biWidth',ctypes.c_long),('biHeight',ctypes.c_long),
              ('biPlanes',ctypes.c_uint16),('biBitCount',ctypes.c_uint16),('biCompression',ctypes.c_uint32),
              ('biSizeImage',ctypes.c_uint32),('biXPelsPerMeter',ctypes.c_long),('biYPelsPerMeter',ctypes.c_long),
              ('biClrUsed',ctypes.c_uint32),('biClrImportant',ctypes.c_uint32)]
class BMI(ctypes.Structure):
    _fields_=[('bmiHeader',BMIH),('bmiColors',ctypes.c_uint32*3)]
def capture_band(y0,y1):
    # capture full width band [y0,y1) of the primary screen; return stats + save BMP
    SW=u.GetSystemMetrics(0); SH=u.GetSystemMetrics(1)
    y0=max(0,y0); y1=min(SH,y1); H=y1-y0; W=SW
    sdc=u.GetDC(0)
    mdc=gdi.CreateCompatibleDC(sdc)
    mbm=gdi.CreateCompatibleBitmap(sdc,W,H)
    gdi.SelectObject(mdc,mbm)
    gdi.BitBlt(mdc,0,0,W,H,sdc,0,y0,0x00CC0020)
    bmi=BMI()
    bmi.bmiHeader.biSize=ctypes.sizeof(BMIH); bmi.bmiHeader.biWidth=W; bmi.bmiHeader.biHeight=-H
    bmi.bmiHeader.biPlanes=1; bmi.bmiHeader.biBitCount=24; bmi.bmiHeader.biCompression=0
    buf=ctypes.create_string_buffer(W*H*3)
    gdi.GetDIBits(mdc,mbm,0,H,buf,ctypes.byref(bmi),0)
    u.ReleaseDC(0,sdc); gdi.DeleteObject(mbm); gdi.DeleteDC(mdc)
    data=buf.raw[:W*H*3]
    # stats: mean brightness + colorfulness (mean abs channel spread) + nonblack ratio
    n=len(data)//3; tot=0; colorful=0; nb=0; step=max(1,n//4000)
    for i in range(0,n,step):
        b=data[i*3]; gr=data[i*3+1]; r=data[i*3+2]
        tot+=(r+gr+b)//3
        if max(r,gr,b)-min(r,gr,b)>18: colorful+=1
        if r+gr+b>45: nb+=1
    cnt=len(range(0,n,step))
    stats={'mean':tot//max(1,cnt),'colorful_pct':100*colorful//max(1,cnt),'nonblack_pct':100*nb//max(1,cnt)}
    return stats
def bmp_save(y0,y1,path):
    SW=u.GetSystemMetrics(0); SH=u.GetSystemMetrics(1)
    y0=max(0,y0); y1=min(SH,y1); H=y1-y0; W=SW
    sdc=u.GetDC(0); mdc=gdi.CreateCompatibleDC(sdc); mbm=gdi.CreateCompatibleBitmap(sdc,W,H)
    gdi.SelectObject(mdc,mbm); gdi.BitBlt(mdc,0,0,W,H,sdc,0,y0,0x00CC0020)
    bmi=BMI(); bmi.bmiHeader.biSize=ctypes.sizeof(BMIH); bmi.bmiHeader.biWidth=W; bmi.bmiHeader.biHeight=-H
    bmi.bmiHeader.biPlanes=1; bmi.bmiHeader.biBitCount=24; bmi.bmiHeader.biCompression=0
    buf=ctypes.create_string_buffer(W*H*3)
    gdi.GetDIBits(mdc,mbm,0,H,buf,ctypes.byref(bmi),0)
    u.ReleaseDC(0,sdc); gdi.DeleteObject(mbm); gdi.DeleteDC(mdc)
    row=W*3; pad=(4-row%4)%4; stride=row+pad
    hdr=b'BM'+ctypes.pack('<IHHI',54+stride*H,0,0,54)+ctypes.pack('<IiiHHIIiiII',40,W,H,1,24,0,stride*H,0,0,0,0)
    raw=b''.join(buf.raw[i*row:(i+1)*row]+b'\x00'*pad for i in range(H))
    WT(path,hdr+raw)

def find_workerw_canonical():
    dv=u.FindWindowW('SHELLDLL_DefView',None)
    L('defview_hwnd=%s'%dv)
    if not dv: return 0
    ww=u.GetWindow(dv,2)  # GW_HWNDNEXT
    cls=ctypes.create_unicode_buffer(64)
    if ww: u.GetClassNameW(ww,cls,64)
    L('next_sibling_hwnd=%s class=%s'%(ww,cls.value if ww else '?'))
    return ww if ww and cls.value=='WorkerW' else 0
def proc_alive(name):
    c,o=run(['tasklist','/FI','IMAGENAME eq '+name],timeout=20)
    return name in (o or '')

L('# R299 screenshot verification of wallpaper layer (fixed capture + candidate hunt)')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
SH=u.GetSystemMetrics(1); L('screen=%dx%d'%(u.GetSystemMetrics(0),SH))

# boxes are parked at y=14 (top); analyze a clear band near the bottom
def band_stats():
    return capture_band(SH-200,SH-40)
st0=guarded(band_stats,25,'band_stats(before)')
L('band_before=%s'%st0)
alive_before=proc_alive('mpv.exe'); L('mpv_alive_before=%s'%alive_before)

layer_visual=False
if st0 and st0.get('colorful_pct',0)>=8 and st0.get('nonblack_pct',0)>=30:
    layer_visual=True
    L('VERDICT: wallpaper already rendering (band is colorful)')
else:
    L('band not colorful - hunting WorkerW candidates')
    prog=u.FindWindowW('Progman',None); res=wt.DWORD()
    u.SendMessageTimeoutW(prog,0x052C,0,0,0x2,1500,ctypes.byref(res)); time.sleep(2)
    cands=[]
    CB=ctypes.WINFUNCTYPE(ctypes.c_bool,wt.HWND,wt.LPARAM)
    def ecb(h,l):
        cls=ctypes.create_unicode_buffer(64); u.GetClassNameW(h,cls,64)
        if cls.value=='WorkerW': cands.append(h)
        return True
    u.EnumWindows(CB(ecb),0)
    L('workerw_candidates=%s'%cands)
    st=json.loads((L12/'state.json').read_text()) if (L12/'state.json').exists() else {}
    cur=st.get('current') or 17
    if isinstance(cur,int):
        hits=sorted(L12.glob('%02d-*.mp4'%cur)) or sorted(L12.glob('%d-*.mp4'%cur))
        cur=hits[0].name if hits else '17-pure-soul.mp4'
    vid=L12/str(cur); L('video=%s exists=%s'%(str(vid),vid.exists()))
    run(['taskkill','/F','/IM','Lively.exe'],timeout=20)
    for ci,ww in enumerate(cands[:4]):
        L('try embed #%d wid=%d'%(ci,ww))
        run(['taskkill','/F','/IM','mpv.exe'],timeout=20); time.sleep(3)
        ok=run_bg([MPV,'--wid=%d'%ww,'--no-audio','--loop-file=inf','--no-border','--osc=no',str(vid)])
        L('mpv_spawn=%s'%ok)
        t0=time.time()
        while time.time()-t0<36:
            time.sleep(12)
            stx=guarded(band_stats,25,'band_stats(poll)')
            L('  poll+%ds %s'%(int(time.time()-t0),stx))
            if stx and stx.get('colorful_pct',0)>=8 and stx.get('nonblack_pct',0)>=30:
                layer_visual=True; break
        if layer_visual: break
if layer_visual:
    bmp_save(SH-220,SH-20,OUT/'r299_wallpaper_band.bmp')
    L('evidence saved: r299_wallpaper_band.bmp')
L('layer_visual=%s'%layer_visual)
L('mpv_alive_after=%s'%proc_alive('mpv.exe'))

box_pids=[]
for f in DBOX.glob('deskbox-*.pid'):
    try:
        pid=int(f.read_text().strip())
        c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
        if str(pid) in (o or ''): box_pids.append(pid)
    except Exception: pass
L('boxes_alive_now=%d %s'%(len(box_pids),box_pids))
ready=bool(layer_visual and len(box_pids)>=2 and not locked)
L('R299_ROUND_READY='+str(ready))
WT(J,json.dumps({'ready':ready,'layerVisual':layer_visual,'boxesAlive':len(box_pids),'bandBefore':st0},indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
