# t239_deskbox_capture_probe_r288.py - round 288.
# r287 postmortem: all four screenshots were FROZEN frames (pairwise diff
# 0.0002 across 60s) while every process was alive - the classic signature of
# a locked session / display-off desktop where DWM stopped composing and
# BitBlt returns a stale surface. New windows (the boxes) never appear in a
# stale capture, so the r287 pixel gates were judging a dead frame.
# r288 adds a LIVE-CAPTURE PROBE before any pixel judgment:
#   * the task itself shows a small magenta topmost window, screenshots, and
#     checks the magenta actually appears in the captured pixels
#   * if not (stale frame), it waits and retries for up to ~3 minutes so a
#     sleeping display can wake up (user moves the mouse)
#   * only a LIVE capture triggers the per-box visibility gates
# Also logs session state (quser), mpv CPU time samples, and coarse ASCII
# dumps of each box region straight into the receipt, so box structure can
# be read from the receipt text itself. Boxes are again LEFT RUNNING.
import ctypes, os, sys, time, subprocess, json, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R288_DESKBOX_CAPTURE_PROBE.md'; J=OUT/'r288-deskbox-capture-probe.json'
PROBE_BMP=OUT/'r288_probe.bmp'; LIVE_BMP=OUT/'r288_deskbox_live.bmp'
M1=OUT/'r288_m1.bmp'; M2=OUT/'r288_m2.bmp'
DBOX_DIR=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
BOX_PY=DBOX_DIR/'box.py'; SUP_PY=DBOX_DIR/'deskbox.py'
lines=[]
def L(s):
    s=str(s).encode('ascii','replace').decode('ascii'); print(s); lines.append(s)
def WT(p,t): Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(t,encoding='utf-8')
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
        return {'ok':True,'ratio':ch/sm if sm else 0,'avg':tot/sm if sm else 0}
    except Exception as e: return {'ok':False,'ratio':0,'avg':0,'err':repr(e)}
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
def probe_capture_live():
    """show a magenta topmost probe window; return True only if the capture
    actually contains it (i.e. the capture is live, not a stale frame)"""
    try:
        import tkinter as tk
        r=tk.Tk(); r.overrideredirect(True); r.geometry('70x70+700+300'); r.configure(bg='#ff00ff'); r.attributes('-topmost',True)
        r.update(); time.sleep(1.5); r.update()
        ok,w,h,e=shot(PROBE_BMP)
        try: r.destroy()
        except Exception: pass
        if not ok: return False
        data,off,W,H,bpp,td,st=info(PROBE_BMP)
        cnt=0
        for y in range(300,370,2):
            for x in range(700,770,2):
                i=off+y*st+x*3
                if data[i]>190 and data[i+2]>190 and data[i+1]<95: cnt+=1
        return cnt>=150
    except Exception as ex:
        L('probe_error='+repr(ex)); return False
def box_stats(bmp, rect):
    """per-box: bright pixels in title band (any color), bright list pixels,
    cyan-ish title pixels (bonus), for gate + logging"""
    try:
        data,off,w,h,bpp,td,st=info(bmp)
        l,t,r,b=rect
        title_bright=0; cyan=0
        for y in range(max(0,t+4),min(h,t+40)):
            for x in range(max(0,l+8),min(w,l+240),2):
                i=off+y*st+x*3
                bb,gg,rr=data[i],data[i+1],data[i+2]
                if (bb+gg+rr)//3>140: title_bright+=1
                if bb>170 and gg>120 and rr>60 and bb>rr and gg>rr: cyan+=1
        list_bright=0
        for y in range(max(0,t+46),min(h,b-6),2):
            for x in range(max(0,l+8),min(w,r-8),2):
                i=off+y*st+x*3
                if (data[i]+data[i+1]+data[i+2])//3>150: list_bright+=1
        return title_bright,cyan,list_bright
    except Exception:
        return -1,-1,-1
def ascii_dump(bmp, rect, label, cols=44):
    try:
        data,off,w,h,bpp,td,st=info(bmp)
        l,t,r,b=rect
        rw=r-l; rh=b-t
        stepx=max(1,rw//cols); stepy=max(1,stepx*2)
        RAMP=' .:-=+*#%@'
        L('   ascii %s (step %dx%d):'%(label,stepx,stepy))
        for y in range(max(0,t),min(h,b),stepy):
            line=''
            for x in range(max(0,l),min(w,r),stepx):
                i=off+y*st+x*3
                line+=RAMP[min(9,((data[i]+data[i+1]+data[i+2])//3)*10//256)]
            L('   |'+line)
    except Exception as ex:
        L('   ascii_error='+repr(ex))

L('# R288 DeskBox - live-capture probe before any pixel judgment')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
c,q=run(['quser'],timeout=15)
for ln in (q or '').strip().splitlines()[:6]: L('quser| '+ln)
c,mpv1=run(['tasklist','/V','/FI','IMAGENAME eq mpv.exe','/FO','LIST'],timeout=20)
for ln in (mpv1 or '').strip().splitlines()[:8]: L('mpv_t0| '+ln)

# ---- ensure boxes running (idempotent: single-instance per key exits)
box_pids=[]; boxes_alive=0; box_windows=[]; visible_boxes=0; live_capture=False
try:
    for f in DBOX_DIR.glob('deskbox-*.pid'):
        try:
            pid=int(f.read_text().strip())
            c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
            if str(pid) in (o or ''): box_pids.append(pid)
        except Exception: pass
    if len(box_pids)<2:
        L('respawning via supervisor (found %d live)'%len(box_pids))
        subprocess.Popen([sys.executable,str(SUP_PY)],creationflags=0x08000000,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        time.sleep(12)
        box_pids=[]
        for f in sorted(DBOX_DIR.glob('deskbox-*.pid')):
            try:
                pid=int(f.read_text().strip())
                c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
                if str(pid) in (o or ''): box_pids.append(pid)
            except Exception: pass
    L('box_pids=%s'%box_pids)
    boxes_alive=len(box_pids); L('boxes_alive=%d'%boxes_alive)
    top,children=windows_report(); pidset=set(box_pids)
    for w in top:
        if w[3] and w[2] in pidset and 250<=(w[6]-w[4])<=340 and 40<=(w[7]-w[5])<=450:
            box_windows.append((w[2],(w[4],w[5],w[6],w[7])))
            L('   box_window| pid=%d rect=%s'%(w[2],str((w[4],w[5],w[6],w[7]))))
    L('box_windows_found=%d'%len(box_windows))
except Exception as ex: L('spawn_check_error='+repr(ex))

# ---- live-capture probe with retry (a sleeping display needs a mouse move)
for attempt in range(1,10):
    live_capture=probe_capture_live()
    L('capture_live attempt %d -> %s'%(attempt,live_capture))
    if live_capture: break
    time.sleep(18)

if live_capture:
    ok,w,h,e=shot(LIVE_BMP); L('live_shot ok=%s'%ok)
    for pid,rect in box_windows:
        tb,cy,lb=box_stats(LIVE_BMP,rect)
        vis=(tb>=10 and lb>=25) or (rect[3]-rect[1])<=52
        if vis: visible_boxes+=1
        L('   box_visible| pid=%d title_bright=%d cyan=%d list_bright=%d -> %s'%(pid,tb,cy,lb,'YES' if vis else 'NO'))
        ascii_dump(LIVE_BMP,rect,'box pid=%d'%pid)
    try:
        for f in DBOX_DIR.glob('deskbox-*-crash.log'):
            L('   crashlog %s| %s'%(f.name,' '.join(f.read_text(encoding='utf-8',errors='replace').split())[:200]))
    except Exception: pass
    pl=wallpaper_players_in_layer(); tmap=tasklist_map()
    for c2 in pl[:3]: L('   wallpaper_player| class='+c2[1]+' owner='+tmap.get(c2[2],'?'))
    layer_final=len(pl)>0; L('layer_final='+str(layer_final))
    ok,w,h,e=shot(M1); L(f'm1 ok={ok}')
    time.sleep(30); ok,w,h,e=shot(M2); L(f'm2 ok={ok}')
    d_m=diff(M1,M2)
    L('motion_ratio=%.6f'%d_m['ratio']); L('motion_final_proven='+str(bool(d_m.get('ok') and (d_m['ratio']>0.0005 or d_m['avg']>0.25))))
    c,mpv2=run(['tasklist','/V','/FI','IMAGENAME eq mpv.exe','/FO','LIST'],timeout=20)
    for ln in (mpv2 or '').strip().splitlines()[:8]: L('mpv_t1| '+ln)
else:
    L('CAPTURE_STALE_AFTER_RETRIES=True - display off / session not composing; pixel gates skipped')
    layer_final=False; d_m={'ok':False,'ratio':0,'avg':0}

# ---- boxes still alive at end (left running for the user)
final_alive=0
for pid in box_pids:
    c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
    if str(pid) in (o or ''): final_alive+=1
L('boxes_left_running=%d/%d'%(final_alive,len(box_pids)))

alpha72=False
try: alpha72="root.attributes('-alpha', 0.72)" in BOX_PY.read_text(encoding='utf-8')
except Exception: pass
L('box_alpha_0.72='+str(alpha72))

ready=bool(live_capture and len(box_pids)>=2 and boxes_alive>=2 and len(box_windows)>=2 and visible_boxes>=2 and layer_final and bool(d_m.get('ok') and (d_m['ratio']>0.0005 or d_m['avg']>0.25)) and final_alive>=2 and alpha72 and not locked)
L('DESKBOX_PROBE_READY='+str(ready))
summary={'ready':ready,'locked':locked,'liveCapture':live_capture,'alpha72':alpha72,'boxPids':box_pids,'boxesAlive':boxes_alive,'boxWindows':len(box_windows),'visibleBoxes':visible_boxes,'layerFinal':layer_final,'motionFinalRatio':d_m.get('ratio'),'boxesLeftRunning':final_alive}
WT(J,json.dumps(summary,ensure_ascii=False,indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
