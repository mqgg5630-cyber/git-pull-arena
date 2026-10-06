# t237_deskbox_one_process_per_box_r285.py - round 285.
# r284 postmortem: deskbox.py (withdraw + multiple Toplevels) died silently
# right after writing its pid - stderr went to DEVNULL so the traceback is
# lost. The r283 panel proved this machine runs: root window + overrideredirect
# + alpha + canvas scroll + bind_all. r285 rebuilds DeskBox v2 using ONLY that
# proven pattern:
#   box.py <key> <title>  - ONE process = ONE box (root window, r283 pattern),
#                           per-key pid lock + per-key config + crash log
#   deskbox.py            - supervisor: scans the desktop once, spawns one
#                           box.py per non-empty category, exits
# The existing desktop bat + Startup bat (from r284) already point at
# deskbox.py and stay valid. If anything still crashes, deskbox-<key>-crash.log
# captures the traceback for the receipt.
import ctypes, os, sys, time, subprocess, json, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R285_DESKBOX_V2_PROVEN.md'; J=OUT/'r285-deskbox-v2-proven.json'
SHOT_BOX=OUT/'r285_deskbox_visible.bmp'
M1=OUT/'r285_m1.bmp'; M2=OUT/'r285_m2.bmp'
DBOX_DIR=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2'); DBOX_DIR.mkdir(parents=True,exist_ok=True)
BOX_PY=DBOX_DIR/'box.py'; SUP_PY=DBOX_DIR/'deskbox.py'
LIVELY_CANDIDATES=[r'C:\Program Files\Lively Wallpaper\Lively.exe',r'C:\Program Files (x86)\Lively Wallpaper\Lively.exe']
STARTUP_DIR=Path(os.environ.get('APPDATA',r'C:\Users\Public'))/'Microsoft'/'Windows'/'Start Menu'/'Programs'/'Startup'
DESK_FALLBACK=Path(os.environ.get('USERPROFILE',r'C:\Users\Public'))/'Desktop'
lines=[]
def L(s):
    s=str(s).encode('ascii','replace').decode('ascii'); print(s); lines.append(s)
def WT(p,t): Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(t,encoding='utf-8')
def WA(p,t): Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(str(t).encode('ascii','replace').decode('ascii'),encoding='ascii')
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
def mini():
    try: subprocess.run(['powershell.exe','-NoProfile','-Command','(New-Object -ComObject Shell.Application).MinimizeAll()'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10)
    except Exception: pass
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

L('# R285 DeskBox v2 rebuilt on the proven r283 pattern (one process per box)')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
lively=''
for c in LIVELY_CANDIDATES:
    if Path(c).exists(): lively=c; break
L('lively_exe='+str(lively))
DESK_DIR=DESK_FALLBACK
try:
    c,o=run(['reg','query',r'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders','/v','Desktop'],timeout=15)
    for ln in (o or '').splitlines():
        if 'REG_SZ' in ln and 'Desktop' in ln:
            cand=ln.split('REG_SZ',1)[1].strip()
            if cand and Path(cand).exists(): DESK_DIR=Path(cand); break
except Exception as ex: L('reg_desktop_error='+repr(ex))
L('real_desktop='+str(DESK_DIR))

# ---- shared helpers embedded identically in both scripts (self-contained)
HELPERS=(
"def real_desktop():\n"
"    import subprocess\n"
"    try:\n"
"        o = subprocess.run(['reg','query',r'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Shell Folders','/v','Desktop'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=15, text=True, errors='replace').stdout or ''\n"
"        for ln in o.splitlines():\n"
"            if 'REG_SZ' in ln and 'Desktop' in ln:\n"
"                cand = ln.split('REG_SZ',1)[1].strip()\n"
"                if cand and Path(cand).is_dir(): return Path(cand)\n"
"    except Exception: pass\n"
"    return Path.home() / 'Desktop'\n"
"def desktop_items():\n"
"    out = {}\n"
"    for d in (real_desktop(), Path(os.environ.get('PUBLIC', r'C:\\Users\\Public')) / 'Desktop'):\n"
"        try:\n"
"            for p in sorted(d.iterdir(), key=lambda x: x.name.lower()):\n"
"                if p.name.lower() in ('desktop.ini','thumbs.db') or p.name.startswith('.'): continue\n"
"                out[p.name.lower()] = p\n"
"        except Exception: pass\n"
"    return list(out.values())\n"
"EXT = {'docs':{'.txt','.md','.doc','.docx','.pdf','.xls','.xlsx','.ppt','.pptx','.csv'},'images':{'.png','.jpg','.jpeg','.webp','.gif','.bmp','.ico'},'video':{'.mp4','.mkv','.webm','.avi','.mov','.flv'},'archives':{'.zip','.rar','.7z','.tar','.gz'}}\n"
"def categorize(items):\n"
"    boxes = {'folders':[],'programs':[],'docs':[],'images':[],'video':[],'archives':[],'other':[]}\n"
"    for p in items:\n"
"        if p.is_dir(): boxes['folders'].append(p)\n"
"        elif p.suffix.lower() in ('.lnk','.url','.exe','.bat'): boxes['programs'].append(p)\n"
"        else:\n"
"            for cat, exts in EXT.items():\n"
"                if p.suffix.lower() in exts: boxes[cat].append(p); break\n"
"            else: boxes['other'].append(p)\n"
"    return boxes\n")

# ---- box.py: ONE process = ONE box, exact r283-proven window pattern
# argv: <key> <title> [default_x default_y]  (supervisor passes slot coords)
box_src=(
"# box.py <key> <title> [x y] - one translucent desktop-folder box (DeskBox v2, r285)\n"
"# Same window pattern as the proven r283 wallpaper panel: a root window with\n"
"# overrideredirect + alpha. One process per box; crash log next to this file.\n"
"import json, os, subprocess, sys, time, traceback\n"
"from pathlib import Path\n"
"BASE = Path(__file__).resolve().parent\n"
"KEY = sys.argv[1] if len(sys.argv) > 1 else 'other'\n"
"TITLE = sys.argv[2] if len(sys.argv) > 2 else KEY\n"
"DEF_X, DEF_Y = 14, 14\n"
"try: DEF_X, DEF_Y = int(sys.argv[3]), int(sys.argv[4])\n"
"except Exception: pass\n"
"PID_FILE = BASE / ('deskbox-%s.pid' % KEY)\n"
"CFG_FILE = BASE / ('deskbox-%s.json' % KEY)\n"
"CRASH = BASE / ('deskbox-%s-crash.log' % KEY)\n"
"def write_crash():\n"
"    try: CRASH.write_text(time.strftime('%Y-%m-%d %H:%M:%S') + chr(10) + traceback.format_exc(), encoding='utf-8')\n"
"    except Exception: pass\n"
"def pid_alive(pid):\n"
"    try:\n"
"        o = subprocess.run(['tasklist','/FI','PID eq %d' % pid], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20, text=True, errors='replace').stdout or ''\n"
"        return str(pid) in o\n"
"    except Exception: return False\n"
+ HELPERS +
"try:\n"
"    old = int(PID_FILE.read_text().strip())\n"
"    if old != os.getpid() and pid_alive(old): sys.exit(0)\n"
"except Exception: pass\n"
"PID_FILE.write_text(str(os.getpid()), encoding='ascii')\n"
"import tkinter as tk\n"
"BG='#10141d'; CARD='#1a2130'; CARD_HOT='#232e44'; FG='#dfe6f2'; FG_DIM='#8b97ad'; ACCENT='#7fd4ff'\n"
"try:\n"
"    root = tk.Tk()\n"
"    root.title('deskbox-' + KEY)\n"
"    root.overrideredirect(True)\n"
"    root.attributes('-alpha', 0.85)\n"
"    root.configure(bg=BG)\n"
"    SW, SH = root.winfo_screenwidth(), root.winfo_screenheight()\n"
"    BOX_W = 300\n"
"    def load_cfg():\n"
"        try: return json.loads(CFG_FILE.read_text(encoding='utf-8'))\n"
"        except Exception: return {}\n"
"    def save_cfg(c):\n"
"        try: CFG_FILE.write_text(json.dumps(c, ensure_ascii=False, indent=2), encoding='utf-8')\n"
"        except Exception: pass\n"
"    cfg = load_cfg()\n"
"    pos = {'x': cfg.get('x', DEF_X), 'y': cfg.get('y', DEF_Y)}\n"
"    state = {'collapsed': bool(cfg.get('collapsed', False)), 'items': []}\n"
"    head = tk.Frame(root, bg=BG)\n"
"    head.pack(fill='x', padx=10, pady=(8, 2))\n"
"    ttl = tk.Label(head, text='', bg=BG, fg=ACCENT, font=('Microsoft YaHei UI', 10, 'bold'))\n"
"    ttl.pack(side='left')\n"
"    btn = tk.Label(head, text='+', bg=BG, fg=FG_DIM, font=('Microsoft YaHei UI', 10), width=3, cursor='hand2')\n"
"    btn.pack(side='right')\n"
"    x2 = tk.Label(head, text=('%c' % 0x2715), bg=BG, fg=FG_DIM, font=('Microsoft YaHei UI', 10), width=3, cursor='hand2')\n"
"    x2.pack(side='right')\n"
"    def close_box():\n"
"        try: PID_FILE.unlink()\n"
"        except Exception: pass\n"
"        root.destroy()\n"
"    x2.bind('<Button-1>', lambda e: close_box())\n"
"    drag = {'x': 0, 'y': 0}\n"
"    def ds(e): drag['x'], drag['y'] = e.x_root - root.winfo_x(), e.y_root - root.winfo_y()\n"
"    def dm(e):\n"
"        pos['x'], pos['y'] = e.x_root - drag['x'], e.y_root - drag['y']\n"
"        root.geometry('+%d+%d' % (pos['x'], pos['y']))\n"
"    def drel(e):\n"
"        c2 = load_cfg(); c2['x'], c2['y'] = pos['x'], pos['y']; save_cfg(c2)\n"
"    for w in (head, ttl, btn, x2):\n"
"        w.bind('<ButtonPress-1>', ds); w.bind('<B1-Motion>', dm); w.bind('<ButtonRelease-1>', drel)\n"
"    body = tk.Frame(root, bg=BG)\n"
"    body.pack(fill='both', expand=True, padx=8, pady=4)\n"
"    cv = tk.Canvas(body, bg=BG, bd=0, highlightthickness=0)\n"
"    cv.pack(fill='both', expand=True)\n"
"    inner = tk.Frame(cv, bg=BG)\n"
"    cw = cv.create_window((0, 0), window=inner, anchor='nw')\n"
"    def fw(e): cv.itemconfigure(cw, width=cv.winfo_width())\n"
"    cv.bind('<Configure>', fw)\n"
"    def on_wheel(e): cv.yview_scroll(int(-1 * (e.delta / 120)), 'units')\n"
"    root.bind_all('<MouseWheel>', on_wheel)\n"
"    def fit(e=None):\n"
"        inner.update_idletasks()\n"
"        cv.configure(scrollregion=cv.bbox('all'))\n"
"    inner.bind('<Configure>', fit)\n"
"    def toggle():\n"
"        state['collapsed'] = not state['collapsed']\n"
"        c2 = load_cfg(); c2['collapsed'] = state['collapsed']; save_cfg(c2)\n"
"        relayout()\n"
"    btn.bind('<Button-1>', lambda e: toggle())\n"
"    def relayout():\n"
"        for w in inner.winfo_children(): w.destroy()\n"
"        n = len(state['items'])\n"
"        ttl.configure(text=TITLE + '  (' + str(n) + ')')\n"
"        btn.configure(text=('+' if state['collapsed'] else ('%c' % 0x2212)))\n"
"        if state['collapsed']:\n"
"            h = 44\n"
"        else:\n"
"            h = min(70 + 30 * min(n, 40), 430)\n"
"            for p in state['items'][:40]:\n"
"                row = tk.Frame(inner, bg=CARD)\n"
"                row.pack(fill='x', pady=1)\n"
"                nm = p.name\n"
"                if len(nm) > 26: nm = nm[:25] + '..'\n"
"                lab = tk.Label(row, text=nm, bg=CARD, fg=FG, font=('Microsoft YaHei UI', 9), anchor='w', cursor='hand2')\n"
"                lab.pack(fill='x', expand=True, padx=8, pady=3)\n"
"                def hot(e, r=row, l=lab): r.configure(bg=CARD_HOT); l.configure(bg=CARD_HOT)\n"
"                def cold(e, r=row, l=lab): r.configure(bg=CARD); l.configure(bg=CARD)\n"
"                def op(e, path=p):\n"
"                    try: os.startfile(str(path))\n"
"                    except Exception: pass\n"
"                for w in (row, lab):\n"
"                    w.bind('<Enter>', hot); w.bind('<Leave>', cold); w.bind('<Double-Button-1>', op)\n"
"        x0 = max(8, min(pos['x'], max(8, SW - BOX_W - 8)))\n"
"        y0 = max(8, min(pos['y'], max(8, SH - 80)))\n"
"        root.geometry('%dx%d+%d+%d' % (BOX_W, h, x0, y0))\n"
"    def rescan():\n"
"        try: state['items'] = categorize(desktop_items()).get(KEY, [])\n"
"        except Exception: state['items'] = []\n"
"        relayout()\n"
"        root.after(5000, rescan)\n"
"    rescan()\n"
"    root.mainloop()\n"
"except Exception:\n"
"    write_crash()\n"
"    raise\n"
"finally:\n"
"    try: PID_FILE.unlink()\n"
"    except Exception: pass\n")

# ---- deskbox.py supervisor
sup_src=(
"# deskbox.py - DeskBox v2 supervisor: spawn one box.py per non-empty category\n"
"import os, subprocess, sys, time, traceback\n"
"from pathlib import Path\n"
"BASE = Path(__file__).resolve().parent\n"
+ HELPERS +
"def slot_xy(slot):\n"
"    col, row = slot % 2, slot // 2\n"
"    return 14 + col * 312, 14 + row * 442\n"
"TITLE = {'folders':'文件夹','programs':'程序','docs':'文档','images':'图片','video':'视频','archives':'压缩包','other':'其他'}\n"
"SLOT = {'folders':0,'programs':1,'docs':2,'images':3,'video':4,'archives':5,'other':6}\n"
"try:\n"
"    groups = categorize(desktop_items())\n"
"    log = []\n"
"    for key, lst in groups.items():\n"
"        if not lst: continue\n"
"        slot = SLOT.get(key, 9)\n"
"        x, y = slot_xy(slot)\n"
"        subprocess.Popen([sys.executable, str(BASE / 'box.py'), key, TITLE.get(key, key), str(x), str(y)], creationflags=0x08000000, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n"
"        log.append('%s=%d@%d,%d' % (key, len(lst), x, y))\n"
"    try:\n"
"        (BASE / 'deskbox-launch.log').write_text(time.strftime('%Y-%m-%d %H:%M:%S') + ' spawned: ' + ', '.join(log) + chr(10), encoding='utf-8')\n"
"    except Exception: pass\n"
"except Exception:\n"
"    try:\n"
"        (BASE / 'deskbox-supervisor-crash.log').write_text(time.strftime('%Y-%m-%d %H:%M:%S') + chr(10) + traceback.format_exc(), encoding='utf-8')\n"
"    except Exception: pass\n")

try:
    WT(BOX_PY,box_src)
    WT(SUP_PY,sup_src)
    L('box_py=%d bytes, sup_py=%d bytes'%(BOX_PY.stat().st_size,SUP_PY.stat().st_size))
except Exception as ex: L('write_error='+repr(ex))
installed=bool(BOX_PY.exists() and BOX_PY.stat().st_size>5000 and SUP_PY.exists() and SUP_PY.stat().st_size>1500)

# ---- ensure bats still point at deskbox.py (supervisor)
BAT_DESK=DESK_DIR/'桌面整理盒.bat'; BAT_START=STARTUP_DIR/'DeskBox Startup.bat'
try:
    if not BAT_DESK.exists():
        WA(BAT_DESK,('@echo off\r\nrem DeskBox v2 launcher\r\nset "BOX='+str(SUP_PY)+'"\r\nwhere pythonw.exe >nul 2>&1 && (start "" pythonw.exe "%BOX%") || (start "" /min python.exe "%BOX%")\r\n'))
    if not BAT_START.exists():
        WA(BAT_START,('@echo off\r\nrem DeskBox v2 - start at logon\r\nping -n 16 127.0.0.1 >nul\r\nset "BOX='+str(SUP_PY)+'"\r\nwhere pythonw.exe >nul 2>&1 && (start "" pythonw.exe "%BOX%") || (start "" /min python.exe "%BOX%")\r\n'))
    L('bats_present desk=%s startup=%s'%(BAT_DESK.exists(),BAT_START.exists()))
except Exception as ex: L('bat_error='+repr(ex))

# ---- live test
box_pids=[]; boxes_alive=0; box_windows=0
if installed:
    try:
        for oldname in ('deskbox.pid','deskbox-config.json','deskbox-launch.log'):
            try: (DBOX_DIR/oldname).unlink()
            except Exception: pass
        for f in DBOX_DIR.glob('deskbox-*-crash.log'):
            try: f.unlink()
            except Exception: pass
        for f in DBOX_DIR.glob('deskbox-*.pid'): 
            try: f.unlink()
            except Exception: pass
        subprocess.Popen([sys.executable,str(SUP_PY)],creationflags=0x08000000,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        time.sleep(10)
        for f in sorted(DBOX_DIR.glob('deskbox-*.pid')):
            try: box_pids.append(int(f.read_text().strip()))
            except Exception: pass
        L('box_pids=%s'%box_pids)
        try: L('launch_log='+' '.join((DBOX_DIR/'deskbox-launch.log').read_text(encoding='utf-8',errors='replace').split()))
        except Exception as ex: L('launch_log_read_error='+repr(ex))
        for pid in box_pids:
            c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
            if str(pid) in (o or ''): boxes_alive+=1
        L('boxes_alive=%d/%d'%(boxes_alive,len(box_pids)))
        top,children=windows_report()
        pidset=set(box_pids)
        for w in top:
            if w[3] and w[2] in pidset and 250<=(w[6]-w[4])<=340 and 40<=(w[7]-w[5])<=450:
                box_windows+=1
                L('   box_window| class=%s pid=%d rect=%s'%(w[1],w[2],str((w[4],w[5],w[6],w[7]))))
        L('box_windows_found=%d'%box_windows)
        for f in sorted(DBOX_DIR.glob('deskbox-*-crash.log')):
            try: L('   crashlog %s| %s'%(f.name,' '.join(f.read_text(encoding='utf-8',errors='replace').split())[:260]))
            except Exception: pass
        mini(); time.sleep(2)
        ok,w,h,e=shot(SHOT_BOX); L(f'deskbox_screenshot ok={ok} ({SHOT_BOX.name})')
    except Exception as ex: L('test_error='+repr(ex))
    finally:
        for pid in box_pids:
            run(['taskkill','/F','/PID',str(pid)],timeout=20)
        time.sleep(2)
        for f in DBOX_DIR.glob('deskbox-*.pid'):
            try: f.unlink()
            except Exception: pass
        L('boxes_killed=True')

# ---- wallpaper unaffected
pl=wallpaper_players_in_layer(); tmap=tasklist_map()
for c in pl[:3]: L('   wallpaper_player| class='+c[1]+' owner='+tmap.get(c[2],'?'))
layer_final=len(pl)>0; L('layer_final='+str(layer_final))
mini(); time.sleep(1); ok,w,h,e=shot(M1); L(f'm1 ok={ok}')
time.sleep(30); ok,w,h,e=shot(M2); L(f'm2 ok={ok}')
d_m=diff(M1,M2)
L('motion_ratio=%.6f'%d_m['ratio']); L('motion_final_proven='+str(bool(d_m.get('ok') and (d_m['ratio']>0.0005 or d_m['avg']>0.25))))
try:
    WT(DBOX_DIR/'PATHS.txt','DeskBox v2 (r285, one process per box - proven pattern)\r\n=========================================================\r\nsupervisor  : '+str(SUP_PY)+' (spawns one box.py per non-empty desktop category)\r\nbox program : '+str(BOX_PY)+' <key> <title>\r\nlauncher    : desktop 桌面整理盒.bat ; autostart: Startup\\DeskBox Startup.bat\r\nper-box cfg : deskbox-<key>.json (x/y/collapsed) ; crash log: deskbox-<key>-crash.log\r\ncategories  : folders / programs / docs / images / video / archives / other\r\nusage       : double-click item opens it; drag header moves the box (saved);\r\n              + / - collapses; box-close closes that box only\r\n')
    L('paths_txt_ok=True')
except Exception: pass

ready=bool(installed and len(box_pids)>=2 and boxes_alive>=2 and box_windows>=2 and layer_final and bool(d_m.get('ok') and (d_m['ratio']>0.0005 or d_m['avg']>0.25)) and not locked)
L('DESKBOX_V2_PROVEN_READY='+str(ready))
summary={'ready':ready,'locked':locked,'boxPy':str(BOX_PY),'supPy':str(SUP_PY),'boxPids':box_pids,'boxesAlive':boxes_alive,'boxWindows':box_windows,'layerFinal':layer_final,'motionFinalRatio':d_m.get('ratio')}
WT(J,json.dumps(summary,ensure_ascii=False,indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
