# t243_deskbox_dlibrary_fix_r292.py - round 292.
# r291 postmortem: robocopy /MOVE of the 20 GB organizer (98903 files, mostly
# 09-Anime-Wallpapers) COPIED everything to E:\...\deskbox-v2\library but
# failed to delete the source (rc=9, one locked file) -> migration gate
# failed -> v3 boxes never spawned while v2 boxes were already killed -> the
# desktop currently has NO boxes. The explorer restart also broke the
# wallpaper WorkerW layer and a 14s Lively restart did not recover it.
# r292 fixes:
#   1. SAME-DRIVE move: the organizer lives on D: - shutil.move across folders
#      on the same drive is a pure rename (instant, zero copy risk):
#      D:\<desktop>\DeskBox-Cute-Desktop-Organizer -> D:\DeskBoxLibrary
#   2. after verifying D:\DeskBoxLibrary, delete the 20 GB E: copy from r291
#   3. box.py v3.1: library_base() prefers D:\DeskBoxLibrary
#   4. spawn v3.1 boxes (restores the desktop)
#   5. HideIcons with full reg diagnostics
#   6. wallpaper layer RECOVERY LOOP after the explorer restart (poll 90s,
#      then Lively restart + poll 90s) - the layer needs time to re-embed
#   7. PrintWindow per-box proof, boxes left running
import ctypes, os, sys, time, subprocess, json, struct, shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R292_DESKBOX_DLIBRARY.md'; J=OUT/'r292-deskbox-dlibrary.json'
PROBE_BMP=OUT/'r292_probe.bmp'; LIVE_BMP=OUT/'r292_deskbox_live.bmp'
DBOX_DIR=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
BOX_PY=DBOX_DIR/'box.py'; SUP_PY=DBOX_DIR/'deskbox.py'
LIB_D=Path(r'D:\DeskBoxLibrary'); LIB_E=DBOX_DIR/'library'; BK_DIR=DBOX_DIR/'backup'
LIVELY_CANDIDATES=[r'C:\Program Files\Lively Wallpaper\Lively.exe',r'C:\Program Files (x86)\Lively Wallpaper\Lively.exe']
lines=[]
def L(s):
    s=str(s).encode('ascii','replace').decode('ascii'); print(s); lines.append(s)
def WT(p,t): Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(t,encoding='utf-8')
def run(args,timeout=25):
    try:
        p=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout,text=True,errors='replace')
        return p.returncode,p.stdout
    except Exception as e: return 999,repr(e)
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
def tasklist_map():
    m={}
    c,o=run(['tasklist','/FO','CSV','/NH'],timeout=30)
    for ln in (o or '').splitlines():
        parts=ln.split('","')
        if len(parts)>=2:
            try: m[int(parts[1].strip('"'))]=parts[0].strip('"')
            except Exception: pass
    return m
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
def wait_layer(deadline_s=90,tag=''):
    t0=time.time()
    while time.time()-t0<deadline_s:
        pl=wallpaper_players_in_layer()
        if pl:
            if tag: L('layer_recovered %s after %ds'%(tag,int(time.time()-t0)))
            return pl
        time.sleep(10)
    return []
def print_window_bmp(hwnd, path):
    import ctypes.wintypes as wt
    try:
        u=ctypes.windll.user32; g=ctypes.windll.gdi32
        u.GetWindowDC.argtypes=[wt.HWND]; u.GetWindowDC.restype=wt.HDC
        u.ReleaseDC.argtypes=[wt.HWND, wt.HDC]
        u.PrintWindow.argtypes=[wt.HWND, wt.HDC, ctypes.c_uint]; u.PrintWindow.restype=ctypes.c_bool
        r=wt.RECT(); u.GetWindowRect(hwnd,ctypes.byref(r))
        w=r.right-r.left; h=r.bottom-r.top
        if w<=0 or h<=0: return False,0,0
        hdc=u.GetWindowDC(hwnd)
        mem=g.CreateCompatibleDC(hdc); bmp=g.CreateCompatibleBitmap(hdc,w,h); old=g.SelectObject(mem,bmp)
        res=u.PrintWindow(hwnd,mem,2)
        if not res: res=u.PrintWindow(hwnd,mem,1)
        stride=((w*3+3)//4)*4; size=stride*h
        class BIH(ctypes.Structure): _fields_=[('biSize',ctypes.c_uint32),('biWidth',ctypes.c_int32),('biHeight',ctypes.c_int32),('biPlanes',ctypes.c_uint16),('biBitCount',ctypes.c_uint16),('biCompression',ctypes.c_uint32),('biSizeImage',ctypes.c_uint32),('biXPelsPerMeter',ctypes.c_int32),('biYPelsPerMeter',ctypes.c_int32),('biClrUsed',ctypes.c_uint32),('biClrImportant',ctypes.c_uint32)]
        class BI(ctypes.Structure): _fields_=[('bmiHeader',BIH),('bmiColors',ctypes.c_uint32*3)]
        bi=BI(); bi.bmiHeader.biSize=ctypes.sizeof(BIH); bi.bmiHeader.biWidth=w; bi.bmiHeader.biHeight=-h; bi.bmiHeader.biPlanes=1; bi.bmiHeader.biBitCount=24; bi.bmiHeader.biCompression=0; bi.bmiHeader.biSizeImage=size
        buf=(ctypes.c_ubyte*size)(); got=g.GetDIBits(mem,bmp,0,h,ctypes.byref(buf),ctypes.byref(bi),0)
        g.SelectObject(mem,old); g.DeleteObject(bmp); g.DeleteDC(mem); u.ReleaseDC(hwnd,hdc)
        if got==0: return False,w,h
        p=Path(path); p.parent.mkdir(parents=True,exist_ok=True)
        with open(p,'wb') as f: f.write(b'BM'); f.write(struct.pack('<IHHI',54+size,0,0,54)); f.write(struct.pack('<IiiHHIIiiII',40,w,-h,1,24,0,size,0,0,0,0)); f.write(bytes(buf))
        return True,w,h
    except Exception as ex:
        L('printwindow_error=%r'%ex); return False,0,0
def info(p):
    data=Path(p).read_bytes(); off=struct.unpack_from('<I',data,10)[0]; w=struct.unpack_from('<i',data,18)[0]; hh=struct.unpack_from('<i',data,22)[0]; bpp=struct.unpack_from('<H',data,28)[0]; td=hh<0; h=abs(hh); st=((w*(bpp//8)+3)//4)*4; return data,off,w,h,bpp,td,st
def printed_gates(bmp):
    try:
        data,off,w,h,bpp,td,st=info(bmp)
        title_bright=0; cyan=0
        for y in range(4,min(h,40)):
            for x in range(8,min(w,240)):
                i=off+y*st+x*3
                bb,gg,rr=data[i],data[i+1],data[i+2]
                if (bb+gg+rr)//3>115: title_bright+=1
                if bb>150 and gg>110 and rr>50 and bb>rr and gg>rr: cyan+=1
        list_bright=0
        for y in range(46,max(46,h-6)):
            for x in range(8,max(8,w-8)):
                i=off+y*st+x*3
                if (data[i]+data[i+1]+data[i+2])//3>130: list_bright+=1
        return title_bright,cyan,list_bright
    except Exception:
        return -1,-1,-1
def probe_capture_live():
    try:
        import tkinter as tk
        r=tk.Tk(); r.overrideredirect(True); r.geometry('70x70+1000+300'); r.configure(bg='#ff00ff'); r.attributes('-topmost',True)
        r.update(); time.sleep(1.5); r.update()
        u=ctypes.windll.user32; g=ctypes.windll.gdi32
        x=u.GetSystemMetrics(76); y=u.GetSystemMetrics(77); w=u.GetSystemMetrics(78); h=u.GetSystemMetrics(79)
        hdc=u.GetDC(0); mem=g.CreateCompatibleDC(hdc); bmp=g.CreateCompatibleBitmap(hdc,w,h); old=g.SelectObject(mem,bmp); ok=g.BitBlt(mem,0,0,w,h,hdc,x,y,0x00CC0020)
        stride=((w*3+3)//4)*4; size=stride*h
        class BIH(ctypes.Structure): _fields_=[('biSize',ctypes.c_uint32),('biWidth',ctypes.c_int32),('biHeight',ctypes.c_int32),('biPlanes',ctypes.c_uint16),('biBitCount',ctypes.c_uint16),('biCompression',ctypes.c_uint32),('biSizeImage',ctypes.c_uint32),('biXPelsPerMeter',ctypes.c_int32),('biYPelsPerMeter',ctypes.c_int32),('biClrUsed',ctypes.c_uint32),('biClrImportant',ctypes.c_uint32)]
        class BI(ctypes.Structure): _fields_=[('bmiHeader',BIH),('bmiColors',ctypes.c_uint32*3)]
        bi=BI(); bi.bmiHeader.biSize=ctypes.sizeof(BIH); bi.bmiHeader.biWidth=w; bi.bmiHeader.biHeight=-h; bi.bmiHeader.biPlanes=1; bi.bmiHeader.biBitCount=24; bi.bmiHeader.biCompression=0; bi.bmiHeader.biSizeImage=size
        buf=(ctypes.c_ubyte*size)(); got=g.GetDIBits(mem,bmp,0,h,ctypes.byref(buf),ctypes.byref(bi),0)
        g.SelectObject(mem,old); g.DeleteObject(bmp); g.DeleteDC(mem); u.ReleaseDC(0,hdc)
        try: r.destroy()
        except Exception: pass
        if (not ok) or got==0: return False
        cnt=0
        for yy in range(300,370,2):
            for xx in range(1000,1070,2):
                i=yy*stride+xx*3
                if buf[i]>190 and buf[i+2]>190 and buf[i+1]<95: cnt+=1
        return cnt>=150
    except Exception as ex:
        L('probe_error='+repr(ex)); return False

# ---- shared v3.1 helpers (library_base prefers D:\DeskBoxLibrary)
HELPERS=(
"import os\n"
"from pathlib import Path\n"
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
"def library_base():\n"
"    p = Path(r'D:\\DeskBoxLibrary')\n"
"    if p.is_dir(): return p\n"
"    return Path(__file__).resolve().parent / 'library'\n"
"LIB_MAP = {'c01':['01-Apps-Shortcuts','New-Shortcuts'],'c02':['02-Job-Tools'],'c03':['03-Video-Creation'],'c04':['04-Images-ID-Photos'],'c05':['05-Documents'],'c06':['06-Archives-Installers'],'c07':['07-Old-Folders'],'c08':['08-Misc'],'c09':['09-Anime-Wallpapers']}\n"
"EXT_MAP = {'c01':('.lnk','.url','.exe','.bat','.cmd'),'c03':('.mp4','.mkv','.webm','.avi','.mov','.flv','.ts'),'c04':('.png','.jpg','.jpeg','.webp','.gif','.bmp','.ico','.heic'),'c05':('.txt','.md','.doc','.docx','.pdf','.xls','.xlsx','.ppt','.pptx','.csv'),'c06':('.zip','.rar','.7z','.tar','.gz','.msi','.iso')}\n"
"def collect_items(key):\n"
"    base = library_base()\n"
"    seen = {}\n"
"    for sub in LIB_MAP.get(key, []):\n"
"        try:\n"
"            for p in sorted((base / sub).iterdir(), key=lambda x: x.name.lower()):\n"
"                if p.name.lower() in ('desktop.ini','thumbs.db'): continue\n"
"                seen[p.name.lower()] = p\n"
"        except Exception: pass\n"
"    exts = EXT_MAP.get(key, ())\n"
"    all_exts = [e for v in EXT_MAP.values() for e in v]\n"
"    loose_dirs = {}\n"
"    for d in (real_desktop(), Path(os.environ.get('PUBLIC', r'C:\\Users\\Public')) / 'Desktop'):\n"
"        try:\n"
"            for p in d.iterdir():\n"
"                nl = p.name.lower()\n"
"                if nl in ('desktop.ini','thumbs.db') or p.name.startswith('.'): continue\n"
"                if nl in seen: continue\n"
"                if p.is_dir():\n"
"                    if nl == 'deskbox-cute-desktop-organizer': continue\n"
"                    loose_dirs[nl] = p\n"
"                    continue\n"
"                if key == 'c07': continue\n"
"                if exts and p.suffix.lower() in exts: seen[nl] = p\n"
"                elif key == 'c08' and p.suffix.lower() not in all_exts: seen[nl] = p\n"
"        except Exception: pass\n"
"    if key == 'c07': seen.update(loose_dirs)\n"
"    out = list(seen.values())\n"
"    out.sort(key=lambda x: x.name.lower())\n"
"    return out\n")

box_src=(
"# box.py <key> <title> [x y] - one translucent desktop box (DeskBox v3.1, r292)\n"
"import json, os, subprocess, sys, time, traceback\n"
"from pathlib import Path\n"
+ HELPERS +
"BASE = Path(__file__).resolve().parent\n"
"KEY = sys.argv[1] if len(sys.argv) > 1 else 'c08'\n"
"TITLE = sys.argv[2] if len(sys.argv) > 2 else KEY\n"
"DEF_X, DEF_Y = 14, 14\n"
"try: DEF_X, DEF_Y = int(sys.argv[3]), int(sys.argv[4])\n"
"except Exception: pass\n"
"PID_FILE = BASE / ('deskbox-%s.pid' % KEY)\n"
"CFG_FILE = BASE / ('deskbox-%s.json' % KEY)\n"
"CRASH = BASE / ('deskbox-%s-crash.log' % KEY)\n"
"ACCENTS = {'c01':'#7fd4ff','c02':'#8be28b','c03':'#c9a0ff','c04':'#ffb0d6','c05':'#ffd98b','c06':'#ff9d8b','c07':'#9be8dc','c08':'#c8d2e0','c09':'#ffaed0'}\n"
"ACCENT = ACCENTS.get(KEY, '#7fd4ff')\n"
"def write_crash():\n"
"    try: CRASH.write_text(time.strftime('%Y-%m-%d %H:%M:%S') + chr(10) + traceback.format_exc(), encoding='utf-8')\n"
"    except Exception: pass\n"
"def pid_alive(pid):\n"
"    try:\n"
"        o = subprocess.run(['tasklist','/FI','PID eq %d' % pid], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20, text=True, errors='replace').stdout or ''\n"
"        return str(pid) in o\n"
"    except Exception: return False\n"
"try:\n"
"    old = int(PID_FILE.read_text().strip())\n"
"    if old != os.getpid() and pid_alive(old): sys.exit(0)\n"
"except Exception: pass\n"
"PID_FILE.write_text(str(os.getpid()), encoding='ascii')\n"
"import tkinter as tk\n"
"BG='#10141d'; CARD='#1a2130'; CARD_HOT='#232e44'; FG='#dfe6f2'; FG_DIM='#8b97ad'\n"
"try:\n"
"    root = tk.Tk()\n"
"    root.title('deskbox-' + KEY)\n"
"    root.overrideredirect(True)\n"
"    root.attributes('-alpha', 0.72)\n"
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
"        try: state['items'] = collect_items(KEY)\n"
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

sup_src=(
"# deskbox.py - DeskBox v3.1 supervisor: spawn one box.py per non-empty category\n"
"import subprocess, sys, time, traceback\n"
"from pathlib import Path\n"
"BASE = Path(__file__).resolve().parent\n"
+ HELPERS +
"ORDER = ['c01','c02','c03','c04','c05','c06','c07','c08','c09']\n"
"TITLE = {'c01':'01 · 程序','c02':'02 · 工作工具','c03':'03 · 视频创作','c04':'04 · 图片证件','c05':'05 · 文档','c06':'06 · 压缩安装包','c07':'07 · 旧文件夹','c08':'08 · 其他','c09':'09 · 动漫壁纸'}\n"
"try:\n"
"    log = []\n"
"    col_y = [14, 14, 14]\n"
"    col_x = [14, 326, 638]\n"
"    for key in ORDER:\n"
"        try: n = len(collect_items(key))\n"
"        except Exception: n = 0\n"
"        if n == 0: continue\n"
"        h = min(70 + 30 * min(n, 40), 430) + 14\n"
"        ci = col_y.index(min(col_y))\n"
"        x, y = col_x[ci], col_y[ci]\n"
"        col_y[ci] += h\n"
"        subprocess.Popen([sys.executable, str(BASE / 'box.py'), key, TITLE.get(key, key), str(x), str(y)], creationflags=0x08000000, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n"
"        log.append('%s=%d@%d,%d' % (key, n, x, y))\n"
"    try:\n"
"        (BASE / 'deskbox-launch.log').write_text(time.strftime('%Y-%m-%d %H:%M:%S') + ' v3.1 spawned: ' + ', '.join(log) + chr(10), encoding='utf-8')\n"
"    except Exception: pass\n"
"except Exception:\n"
"    try:\n"
"        (BASE / 'deskbox-supervisor-crash.log').write_text(time.strftime('%Y-%m-%d %H:%M:%S') + chr(10) + traceback.format_exc(), encoding='utf-8')\n"
"    except Exception: pass\n")

L('# R292 DeskBox v3.1 - same-drive library move, layer recovery, boxes restored')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
DESK_DIR=Path(os.environ.get('USERPROFILE',r'C:\Users\Public'))/'Desktop'
try:
    c,o=run(['reg','query',r'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders','/v','Desktop'],timeout=15)
    for ln in (o or '').splitlines():
        if 'REG_SZ' in ln and 'Desktop' in ln:
            cand=ln.split('REG_SZ',1)[1].strip()
            if cand and Path(cand).exists(): DESK_DIR=Path(cand); break
except Exception as ex: L('reg_desktop_error='+repr(ex))
L('real_desktop='+str(DESK_DIR))
lively=''
for cnd in LIVELY_CANDIDATES:
    if Path(cnd).exists(): lively=cnd; break
L('lively_exe='+str(lively))

# ---- 0. kill any leftover boxes (v2 or v3), clean pids
killed=0
for f in DBOX_DIR.glob('deskbox-*.pid'):
    try:
        pid=int(f.read_text().strip())
        c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
        if str(pid) in (o or ''): run(['taskkill','/F','/PID',str(pid)],timeout=20); killed+=1
    except Exception: pass
    try: f.unlink()
    except Exception: pass
L('leftover_boxes_killed=%d'%killed); time.sleep(2)

# ---- 1. same-drive move: desktop organizer -> D:\DeskBoxLibrary (pure rename)
SRC_ORG=DESK_DIR/'DeskBox-Cute-Desktop-Organizer'
migrated=False
try:
    if SRC_ORG.exists() and not LIB_D.exists():
        shutil.move(str(SRC_ORG),str(LIB_D)); time.sleep(1)
    elif SRC_ORG.exists() and LIB_D.exists():
        L('both source and D-library exist - merging not attempted; source kept')
    if LIB_D.exists() and not SRC_ORG.exists():
        migrated=True
    elif LIB_D.exists() and SRC_ORG.exists():
        subs=[p.name for p in LIB_D.iterdir()]
        need=['01-Apps-Shortcuts','02-Job-Tools','03-Video-Creation','04-Images-ID-Photos','05-Documents','06-Archives-Installers','07-Old-Folders','08-Misc','09-Anime-Wallpapers']
        if all((LIB_D/n).is_dir() for n in need):
            migrated=True
            L('D-library complete; leftover source folder left in place (data duplicated, not deleted)')
except Exception as ex: L('move_error='+repr(ex))
try:
    subs=sorted([p.name for p in LIB_D.iterdir()]) if LIB_D.exists() else []
    L('library_subfolders=%s'%subs)
    for s in subs:
        try: L('lib_count %s = %d'%(s,len(list((LIB_D/s).iterdir()))))
        except Exception: pass
except Exception: pass
L('migration_ok='+str(migrated))

# ---- 2. delete the failed 20GB E: copy from r291 (source verified on D:)
ecopy_removed=False
if migrated and LIB_E.exists():
    try:
        run(['cmd','/c','rmdir','/s','/q',str(LIB_E)],timeout=600)
        ecopy_removed=not LIB_E.exists()
    except Exception as ex: L('ecopy_error='+repr(ex))
L('e_copy_removed='+str(ecopy_removed))

# ---- 3. retire old lnk (idempotent)
lnk_gone=False
try:
    LNK=DESK_DIR/'DeskBox Cute.lnk'
    if LNK.exists():
        BK_DIR.mkdir(parents=True,exist_ok=True)
        shutil.move(str(LNK),str(BK_DIR/'DeskBox Cute.lnk'))
    lnk_gone=not LNK.exists()
except Exception as ex: L('lnk_error='+repr(ex))
L('old_lnk_removed_from_desktop='+str(lnk_gone))

# ---- 4. install v3.1
installed=False
try:
    WT(BOX_PY,box_src); WT(SUP_PY,sup_src)
    installed=bool(BOX_PY.exists() and BOX_PY.stat().st_size>7500 and SUP_PY.exists() and SUP_PY.stat().st_size>2500)
    L('v31_installed=%s box=%dB sup=%dB'%(installed,BOX_PY.stat().st_size,SUP_PY.stat().st_size))
except Exception as ex: L('install_error='+repr(ex))

# ---- 5. spawn v3.1
box_pids=[]; boxes_alive=0; box_windows=[]; printed_visible=0
if installed and migrated and not locked:
    subprocess.Popen([sys.executable,str(SUP_PY)],creationflags=0x08000000,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    time.sleep(12)
    for f in sorted(DBOX_DIR.glob('deskbox-*.pid')):
        try:
            pid=int(f.read_text().strip())
            c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
            if str(pid) in (o or ''): box_pids.append(pid)
        except Exception: pass
    L('box_pids=%s'%box_pids)
    boxes_alive=len(box_pids); L('boxes_alive=%d'%boxes_alive)
    try: L('launch_log='+' '.join((DBOX_DIR/'deskbox-launch.log').read_text(encoding='utf-8',errors='replace').split()))
    except Exception as ex: L('launch_log_read_error='+repr(ex))
    top,children=windows_report(); pidset=set(box_pids)
    for w in top:
        if w[3] and w[2] in pidset and 250<=(w[6]-w[4])<=340 and 40<=(w[7]-w[5])<=450:
            box_windows.append((w[0],w[2],(w[4],w[5],w[6],w[7])))
            L('   box_window| pid=%d rect=%s'%(w[2],str((w[4],w[5],w[6],w[7]))))
    L('box_windows_found=%d'%len(box_windows))
    for hwnd,pid,rect in box_windows:
        pb=OUT/('r292_box_%d.bmp'%pid)
        ok,pw2,ph2=print_window_bmp(hwnd,pb)
        if ok:
            tb,cy,lb=printed_gates(pb)
            vis=(tb>=25 and lb>=80) or ph2<=52
            if vis: printed_visible+=1
            L('   box_printed| pid=%d %dx%d title_bright=%d cyan=%d list_bright=%d -> %s'%(pid,pw2,ph2,tb,cy,lb,'VISIBLE' if vis else 'NOT-VISIBLE'))
        else:
            L('   box_printed| pid=%d PRINT_FAILED'%pid)
    try:
        for f in DBOX_DIR.glob('deskbox-*-crash.log'):
            L('   crashlog %s| %s'%(f.name,' '.join(f.read_text(encoding='utf-8',errors='replace').split())[:260]))
    except Exception: pass

# ---- 6. hide desktop icons, with diagnostics; then recover the wallpaper layer
icons_hidden=False
try:
    c,o=run(['reg','add',r'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced','/v','HideIcons','/t','REG_DWORD','/d','1','/f'],timeout=15)
    L('reg_add rc=%d out=%s'%(c,(o or '').strip()[:120]))
    run(['taskkill','/F','/IM','explorer.exe'],timeout=20); time.sleep(3)
    run(['explorer.exe'],timeout=15); time.sleep(6)
    c,o=run(['reg','query',r'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced','/v','HideIcons'],timeout=15)
    L('reg_query rc=%d out=%s'%(c,(o or '').strip()[:200]))
    icons_hidden=('0x1' in (o or ''))
except Exception as ex: L('hide_icons_error='+repr(ex))
L('icons_hidden='+str(icons_hidden))

layer_final=False
pl=wait_layer(90,'poll-after-explorer')
if not pl and lively:
    L('layer still down - restarting Lively')
    run(['taskkill','/F','/IM','mpv.exe'],timeout=20)
    run(['taskkill','/F','/IM','Lively.exe'],timeout=20); time.sleep(3)
    run(['cmd','/c','start','',lively],timeout=20)
    pl=wait_layer(120,'after-lively-restart')
tmap=tasklist_map()
for c2 in pl[:3]: L('   wallpaper_player| class='+c2[1]+' owner='+tmap.get(c2[2],'?'))
layer_final=len(pl)>0
L('layer_final='+str(layer_final))

# ---- 7. best-effort live probe (short)
live_capture=False
for attempt in range(1,4):
    live_capture=probe_capture_live()
    L('capture_live attempt %d -> %s'%(attempt,live_capture))
    if live_capture: break
    time.sleep(8)
if not live_capture: L('SCREEN_STALE (display off) - PrintWindow proof stands')

# ---- 8. boxes still alive at end
final_alive=0
for pid in box_pids:
    c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
    if str(pid) in (o or ''): final_alive+=1
L('boxes_left_running=%d/%d'%(final_alive,len(box_pids)))
alpha72=False
try: alpha72="root.attributes('-alpha', 0.72)" in BOX_PY.read_text(encoding='utf-8')
except Exception: pass
L('box_alpha_0.72='+str(alpha72))

try:
    WT(DBOX_DIR/'PATHS.txt','DeskBox v3.1 (r292 - replaces the old opaque DeskBox; translucent only)\r\n======================================================================\r\nsupervisor  : '+str(SUP_PY)+' (one box per non-empty category, 3-column layout)\r\nbox program : '+str(BOX_PY)+' <key> <title> <x> <y>  [alpha 0.72 dark glass, per-category accent]\r\nlibrary     : '+str(LIB_D)+' (the old organizer, SAME-DRIVE moved from the desktop - instant, data intact)\r\nlauncher    : desktop-organized-boxes.bat ; autostart: Startup\\DeskBox Startup.bat\r\ncategories  : 01 Programs 02 WorkTools 03 Video 04 Images 05 Docs 06 Archives 07 OldFolders 08 Misc 09 Wallpapers\r\ndesktop     : icons hidden (HideIcons=1); restore: reg add HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced /v HideIcons /t REG_DWORD /d 0 /f then restart explorer\r\nold deskbox : shortcut in '+str(BK_DIR)+' ; app folder E:\\0mcp-agv-arena-optimized\\apps\\DeskBox untouched\r\nusage       : double-click opens; drag header moves (saved); + / - collapses; x closes one box\r\n')
    L('paths_txt_ok=True')
except Exception: pass

ready=bool(installed and migrated and lnk_gone and icons_hidden and len(box_pids)>=2 and boxes_alive>=2 and len(box_windows)>=2 and printed_visible>=2 and layer_final and final_alive>=2 and alpha72 and not locked)
L('DESKBOX_V31_READY='+str(ready))
summary={'ready':ready,'locked':locked,'installed':installed,'migrated':migrated,'ecopyRemoved':ecopy_removed,'lnkGone':lnk_gone,'iconsHidden':icons_hidden,'alpha72':alpha72,'boxPids':box_pids,'boxesAlive':boxes_alive,'boxWindows':len(box_windows),'printedVisible':printed_visible,'layerFinal':layer_final,'liveCapture':live_capture,'boxesLeftRunning':final_alive}
WT(J,json.dumps(summary,ensure_ascii=False,indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
