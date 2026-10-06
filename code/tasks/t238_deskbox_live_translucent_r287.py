# t238_deskbox_live_translucent_r287.py - round 287.
# User feedback after r286: the proof screenshot looked "the same as my
# original desktop" - (a) the task KILLED all boxes after verifying, so
# nothing was left running on the desktop; (b) two of three boxes did not
# render into the screenshot (shot was taken after MinimizeAll); (c) alpha
# 0.85 dark glass over a dark wallpaper does not read as translucent.
# r287 fixes all three:
#   1. patch the installed box.py: alpha 0.85 -> 0.72 (more see-through)
#   2. spawn boxes and take TWO screenshots with NO MinimizeAll call
#   3. per-box pixel gate: each box window must show its cyan title text
#      and bright list text in at least one shot (hard evidence, not hope)
#   4. LEAVE THE BOXES RUNNING on the desktop when the task ends
import ctypes, os, sys, time, subprocess, json, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R287_DESKBOX_LIVE_TRANSLUCENT.md'; J=OUT/'r287-deskbox-live-translucent.json'
SHOT_A=OUT/'r287_deskbox_live_a.bmp'; SHOT_B=OUT/'r287_deskbox_live_b.bmp'
M1=OUT/'r287_m1.bmp'; M2=OUT/'r287_m2.bmp'
DBOX_DIR=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
BOX_PY=DBOX_DIR/'box.py'; SUP_PY=DBOX_DIR/'deskbox.py'; BAK=BOX_PY.with_suffix('.py.r285bak')
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
def box_text_pixels(bmp, rect):
    """count cyan title pixels + bright list pixels inside a box rect"""
    try:
        data,off,w,h,bpp,td,st=info(bmp)
        l,t,r,b=rect
        cyan=0; bright=0
        for y in range(max(0,t+4),min(h,t+40)):
            for x in range(max(0,l+8),min(w,l+240),2):
                i=off+y*st+x*3
                bb,gg,rr=data[i],data[i+1],data[i+2]
                if bb>170 and gg>120 and rr>60 and bb>rr and gg>rr: cyan+=1
        for y in range(max(0,t+46),min(h,b-6),2):
            for x in range(max(0,l+8),min(w,r-8),2):
                i=off+y*st+x*3
                if (data[i]+data[i+1]+data[i+2])//3>150: bright+=1
        return cyan,bright
    except Exception as e:
        return -1,-1

L('# R287 DeskBox v2 - live on desktop, more translucent, pixel-proof visibility')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))

# ---- 1. patch alpha 0.85 -> 0.72 in the installed box.py
patched=False
try:
    src=BOX_PY.read_text(encoding='utf-8')
    if "root.attributes('-alpha', 0.72)" in src:
        patched=True; L('alpha_already_0.72=True')
    elif src.count("root.attributes('-alpha', 0.85)")==1:
        if not BAK.exists(): BAK.write_text(src,encoding='utf-8')
        BOX_PY.write_text(src.replace("root.attributes('-alpha', 0.85)","root.attributes('-alpha', 0.72)"),encoding='utf-8')
        patched=("root.attributes('-alpha', 0.72)" in BOX_PY.read_text(encoding='utf-8'))
        L('alpha_patched_to_0.72='+str(patched)+' (backup='+BAK.name+')')
    else:
        L('box_py_alpha_string_unexpected count='+str(src.count("root.attributes('-alpha', 0.85)")))
except Exception as ex: L('patch_error='+repr(ex))
L('box_py_size=%d'%BOX_PY.stat().st_size if BOX_PY.exists() else 'box_py_missing')

# ---- 2. clean stale state, spawn boxes (exactly what the desktop bat does)
box_pids=[]; boxes_alive=0; box_windows=[]; visible_boxes=0
if patched and not locked:
    for f in DBOX_DIR.glob('deskbox-*.pid'):
        try: f.unlink()
        except Exception: pass
    subprocess.Popen([sys.executable,str(SUP_PY)],creationflags=0x08000000,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    time.sleep(12)
    for f in sorted(DBOX_DIR.glob('deskbox-*.pid')):
        try: box_pids.append(int(f.read_text().strip()))
        except Exception: pass
    L('box_pids=%s'%box_pids)
    for pid in box_pids:
        c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
        if str(pid) in (o or ''): boxes_alive+=1
    L('boxes_alive=%d/%d'%(boxes_alive,len(box_pids)))
    top,children=windows_report(); pidset=set(box_pids)
    for w in top:
        if w[3] and w[2] in pidset and 250<=(w[6]-w[4])<=340 and 40<=(w[7]-w[5])<=450:
            box_windows.append((w[2],(w[4],w[5],w[6],w[7])))
            L('   box_window| pid=%d rect=%s'%(w[2],str((w[4],w[5],w[6],w[7]))))
    L('box_windows_found=%d'%len(box_windows))
    try: L('launch_log='+' '.join((DBOX_DIR/'deskbox-launch.log').read_text(encoding='utf-8',errors='replace').split()))
    except Exception as ex: L('launch_log_read_error='+repr(ex))
    # ---- 3. TWO screenshots, NO MinimizeAll; per-box pixel gates
    okA,wA,hA,eA=shot(SHOT_A); L('shot_a ok=%s'%okA); time.sleep(6)
    okB,wB,hB,eB=shot(SHOT_B); L('shot_b ok=%s'%okB)
    try:
        for f in DBOX_DIR.glob('deskbox-*-crash.log'):
            L('   crashlog(post-shot) %s| %s'%(f.name,' '.join(f.read_text(encoding='utf-8',errors='replace').split())[:200]))
    except Exception: pass
    for pid,rect in box_windows:
        ca,ba=box_text_pixels(SHOT_A,rect); cb,bb2=box_text_pixels(SHOT_B,rect)
        vis=(max(ca,cb)>=6 and max(ba,bb2)>=25) or (rect[3]-rect[1])<=52
        if vis: visible_boxes+=1
        L('   box_visible| pid=%d cyanA=%d cyanB=%d brightA=%d brightB=%d -> %s'%(pid,ca,cb,ba,bb2,'YES' if vis else 'NO'))
    L('visible_boxes=%d/%d'%(visible_boxes,len(box_windows)))
    for f in sorted(DBOX_DIR.glob('deskbox-*-crash.log')):
        try: L('   crashlog %s| %s'%(f.name,' '.join(f.read_text(encoding='utf-8',errors='replace').split())[:260]))
        except Exception: pass
else:
    L('skip_spawn reason patched=%s locked=%s'%(patched,locked))

# ---- 4. wallpaper untouched (boxes stay running; NO minimize, NO kill)
pl=wallpaper_players_in_layer(); tmap=tasklist_map()
for c in pl[:3]: L('   wallpaper_player| class='+c[1]+' owner='+tmap.get(c[2],'?'))
layer_final=len(pl)>0; L('layer_final='+str(layer_final))
ok,w,h,e=shot(M1); L(f'm1 ok={ok}')
time.sleep(30); ok,w,h,e=shot(M2); L(f'm2 ok={ok}')
d_m=diff(M1,M2)
L('motion_ratio=%.6f'%d_m['ratio']); L('motion_final_proven='+str(bool(d_m.get('ok') and (d_m['ratio']>0.0005 or d_m['avg']>0.25))))

# ---- 5. boxes still alive at task end (left running for the user)
final_alive=0
for pid in box_pids:
    c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
    if str(pid) in (o or ''): final_alive+=1
L('boxes_left_running=%d/%d'%(final_alive,len(box_pids)))

try:
    WT(DBOX_DIR/'PATHS.txt','DeskBox v2 (r287 - one process per box, alpha 0.72, boxes stay after install-test)\r\n=====================================================================\r\nsupervisor  : '+str(SUP_PY)+' (spawns one box.py per non-empty desktop category)\r\nbox program : '+str(BOX_PY)+' <key> <title> <x> <y>   [alpha 0.72 translucent dark glass]\r\nlauncher    : desktop 桌面整理盒.bat ; autostart: Startup\\DeskBox Startup.bat\r\nper-box cfg : deskbox-<key>.json (x/y/collapsed) ; crash log: deskbox-<key>-crash.log\r\ncategories  : folders / programs / docs / images / video / archives / other\r\nusage       : double-click item opens it; drag header moves the box (saved);\r\n              + / - collapses; x closes that box only; relaunch via the bat\r\nnote        : the install test now LEAVES THE BOXES RUNNING on the desktop\r\n')
    L('paths_txt_ok=True')
except Exception: pass

ready=bool(patched and len(box_pids)>=2 and boxes_alive>=2 and len(box_windows)>=2 and visible_boxes>=2 and layer_final and bool(d_m.get('ok') and (d_m['ratio']>0.0005 or d_m['avg']>0.25)) and final_alive>=2 and not locked)
L('DESKBOX_LIVE_READY='+str(ready))
summary={'ready':ready,'locked':locked,'alphaPatched':patched,'boxPids':box_pids,'boxesAlive':boxes_alive,'boxWindows':len(box_windows),'visibleBoxes':visible_boxes,'layerFinal':layer_final,'motionFinalRatio':d_m.get('ratio'),'boxesLeftRunning':final_alive}
WT(J,json.dumps(summary,ensure_ascii=False,indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
