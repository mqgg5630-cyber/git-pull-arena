# t240_deskbox_wake_proof_r289.py - round 289.
# r288 proved the capture was stale for 3+ minutes (display asleep, mpv CPU
# 0:00:00) while the boxes stayed alive - and the programs box rect moved
# (326,14)->(354,17), i.e. the USER dragged it: the boxes are live on the
# desktop and interactive. The only missing piece is a LIVE screenshot.
# r289:
#   1. wake the display programmatically (SendInput 1px mouse move, invisible)
#   2. magenta live-capture probe (relocated to (760,520), clear of boxes/panel)
#   3. dump every deskbox-<key>.json - persisted user drags are hard evidence
#   4. per-box gates only on a LIVE capture + ASCII dumps into the receipt
#   5. wallpaper layer + 30s motion, boxes left running
import ctypes, os, sys, time, subprocess, json, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R289_DESKBOX_WAKE_PROOF.md'; J=OUT/'r289-deskbox-wake-proof.json'
PROBE_BMP=OUT/'r289_probe.bmp'; LIVE_BMP=OUT/'r289_deskbox_live.bmp'
M1=OUT/'r289_m1.bmp'; M2=OUT/'r289_m2.bmp'
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
def wake_display():
    """synthesize a 1px mouse move to wake a sleeping display (imperceptible)"""
    try:
        ULONG_PTR=ctypes.c_size_t
        class MOUSEINPUT(ctypes.Structure):
            _fields_=[('dx',ctypes.c_long),('dy',ctypes.c_long),('mouseData',ctypes.c_ulong),('dwFlags',ctypes.c_ulong),('time',ctypes.c_ulong),('dwExtraInfo',ULONG_PTR)]
        class _U(ctypes.Union):
            _fields_=[('mi',MOUSEINPUT)]
        class INPUT(ctypes.Structure):
            _fields_=[('type',ctypes.c_ulong),('u',_U)]
        inp=INPUT(); inp.type=0  # INPUT_MOUSE
        inp.u.mi.dx=1; inp.u.mi.dy=0; inp.u.mi.dwFlags=0x0001  # MOUSEEVENTF_MOVE
        n=ctypes.windll.user32.SendInput(1,ctypes.byref(inp),ctypes.sizeof(INPUT))
        return n==1
    except Exception as ex:
        L('wake_error='+repr(ex)); return False
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
    try:
        import tkinter as tk
        r=tk.Tk(); r.overrideredirect(True); r.geometry('70x70+760+520'); r.configure(bg='#ff00ff'); r.attributes('-topmost',True)
        r.update(); time.sleep(1.5); r.update()
        ok,w,h,e=shot(PROBE_BMP)
        try: r.destroy()
        except Exception: pass
        if not ok: return False
        data,off,W,H,bpp,td,st=info(PROBE_BMP)
        cnt=0
        for y in range(520,590,2):
            for x in range(760,830,2):
                i=off+y*st+x*3
                if data[i]>190 and data[i+2]>190 and data[i+1]<95: cnt+=1
        return cnt>=150
    except Exception as ex:
        L('probe_error='+repr(ex)); return False
def box_stats(bmp, rect):
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

L('# R289 DeskBox - wake display, live proof')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))

# ---- user-interaction evidence: persisted per-box configs (drags / collapse)
for f in sorted(DBOX_DIR.glob('deskbox-*.json')):
    try: L('cfg %s| %s'%(f.name,' '.join(f.read_text(encoding='utf-8',errors='replace').split())))
    except Exception as ex: L('cfg %s| read_error=%r'%(f.name,ex))

# ---- ensure boxes running (idempotent)
box_pids=[]; boxes_alive=0; box_windows=[]; visible_boxes=0; live_capture=False
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

# ---- wake the display, then live-capture probe with retry
for attempt in range(1,13):
    woke=wake_display(); time.sleep(2.5)
    live_capture=probe_capture_live()
    L('wake attempt %d sent=%s capture_live=%s'%(attempt,woke,live_capture))
    if live_capture: break
    time.sleep(12)

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
else:
    L('CAPTURE_STALE_AFTER_WAKE_RETRIES=True')
    layer_final=False; d_m={'ok':False,'ratio':0,'avg':0}

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
L('DESKBOX_WAKE_PROOF_READY='+str(ready))
summary={'ready':ready,'locked':locked,'liveCapture':live_capture,'alpha72':alpha72,'boxPids':box_pids,'boxesAlive':boxes_alive,'boxWindows':len(box_windows),'visibleBoxes':visible_boxes,'layerFinal':layer_final,'motionFinalRatio':d_m.get('ratio'),'boxesLeftRunning':final_alive}
WT(J,json.dumps(summary,ensure_ascii=False,indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
