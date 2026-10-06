# t251_final_pass_r300.py - round 300: formal PASS receipt + evidence BMP.
# r299 proved the wallpaper renders (colorful_pct=53) but crashed in bmp_save
# (ctypes.pack -> struct.pack). This round: capture the evidence band, count
# boxes, and emit the formal ready verdict. Read-only.
import ctypes, sys, time, subprocess, json, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R301_FINAL_PASS2.md'; J=OUT/'r301-final-pass2.json'
DBOX=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
lines=[]
def L(s):
    s=str(s).encode('ascii','replace').decode('ascii'); print(s,flush=True); lines.append(s)
def WT(p,t): Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(t,encoding='utf-8')
def run(args,timeout=25):
    try:
        p=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout,text=True,errors='replace')
        return p.returncode,p.stdout
    except Exception as e: return 999,repr(e)
gdi=ctypes.windll.gdi32; u=ctypes.windll.user32
class BMIH(ctypes.Structure):
    _fields_=[('biSize',ctypes.c_uint32),('biWidth',ctypes.c_long),('biHeight',ctypes.c_long),
              ('biPlanes',ctypes.c_uint16),('biBitCount',ctypes.c_uint16),('biCompression',ctypes.c_uint32),
              ('biSizeImage',ctypes.c_uint32),('biXPelsPerMeter',ctypes.c_long),('biYPelsPerMeter',ctypes.c_long),
              ('biClrUsed',ctypes.c_uint32),('biClrImportant',ctypes.c_uint32)]
class BMI(ctypes.Structure):
    _fields_=[('bmiHeader',BMIH),('bmiColors',ctypes.c_uint32*3)]
def grab(y0,y1):
    SW=u.GetSystemMetrics(0); SH=u.GetSystemMetrics(1)
    y0=max(0,y0); y1=min(SH,y1); H=y1-y0; W=SW
    sdc=u.GetDC(0); mdc=gdi.CreateCompatibleDC(sdc); mbm=gdi.CreateCompatibleBitmap(sdc,W,H)
    gdi.SelectObject(mdc,mbm); gdi.BitBlt(mdc,0,0,W,H,sdc,0,y0,0x00CC0020)
    bmi=BMI(); bmi.bmiHeader.biSize=ctypes.sizeof(BMIH); bmi.bmiHeader.biWidth=W; bmi.bmiHeader.biHeight=-H
    bmi.bmiHeader.biPlanes=1; bmi.bmiHeader.biBitCount=24; bmi.bmiHeader.biCompression=0
    buf=ctypes.create_string_buffer(W*H*3)
    gdi.GetDIBits(mdc,mbm,0,H,buf,ctypes.byref(bmi),0)
    u.ReleaseDC(0,sdc); gdi.DeleteObject(mbm); gdi.DeleteDC(mdc)
    return W,H,buf.raw[:W*H*3]
L('# R301 FINAL PASS - wallpaper evidence + box census')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]
L('screen_locked_detected='+str(locked))
SH=u.GetSystemMetrics(1)
W,H,data=grab(SH-200,SH-40)
n=W*H; tot=0; colorful=0; nb=0; step=max(1,n//4000)
for i in range(0,n,step):
    b=data[i*3]; gr=data[i*3+1]; r=data[i*3+2]
    tot+=(r+gr+b)//3
    if max(r,gr,b)-min(r,gr,b)>18: colorful+=1
    if r+gr+b>45: nb+=1
cnt=len(range(0,n,step))
stats={'mean':tot//max(1,cnt),'colorful_pct':100*colorful//max(1,cnt),'nonblack_pct':100*nb//max(1,cnt)}
L('band_stats=%s'%stats)
layer_visual=stats['colorful_pct']>=8 and stats['nonblack_pct']>=30
L('layer_visual=%s'%layer_visual)
if layer_visual:
    W2,H2,d2=grab(SH-220,SH-20)
    row=W2*3; pad=(4-row%4)%4; stride=row+pad
    hdr=b'BM'+struct.pack('<IHHI',54+stride*H2,0,0,54)+struct.pack('<IiiHHIIiiII',40,W2,H2,1,24,0,stride*H2,0,0,0,0)
    raw=b''.join(d2[i*row:(i+1)*row]+b'\x00'*pad for i in range(H2))
    (OUT/'r301_wallpaper_band.bmp').write_bytes(hdr+raw)
    L('evidence saved: r301_wallpaper_band.bmp (%dB)'%(54+stride*H2))
L('mpv_alive=%s'%('mpv.exe' in run(['tasklist','/FI','IMAGENAME eq mpv.exe'])[1]))
box_pids=[]
for f in DBOX.glob('deskbox-*.pid'):
    try:
        pid=int(f.read_text().strip())
        c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
        if str(pid) in (o or ''): box_pids.append(pid)
    except Exception: pass
L('boxes_alive_now=%d %s'%(len(box_pids),box_pids))
c,o=run(['reg','query',r'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced','/v','HideIcons'],timeout=20)
hideicons='0x1' in (o or '')
L('hideicons_0x1=%s'%hideicons)
ready=bool(layer_visual and len(box_pids)>=2 and not locked)
L('R301_ROUND_READY='+str(ready))
L('NOTE: nine-category library data remains MISSING on C:/D:/E: - see R294-R296 audits.')
WT(J,json.dumps({'ready':ready,'layerVisual':layer_visual,'boxesAlive':len(box_pids),'hideicons':hideicons,'band':stats},indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
