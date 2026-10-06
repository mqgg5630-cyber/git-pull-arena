# t236_deskbox_translucent_r284.py - round 284.
# User: "DeskBox is installed on my machine - find the local project first,
# then design a semi-transparent desktop-folder UI for it."
# Phase 1 DISCOVERY: locate every deskbox-related file/folder/process/
#   registry entry on the machine (real desktop, D:, E:\0mcp..., AppData,
#   Program Files, Start Menu, Startup, uninstall keys, running processes)
#   and log what the project actually is.
# Phase 2 REDESIGN: deliver DeskBox v2 = translucent desktop-folder boxes
#   (Fences style, tkinter, same dark-glass look as the r283 wallpaper
#   panel): desktop items auto-grouped into floating boxes (folders /
#   programs / docs / images / video / archives / other), double-click to
#   open, per-box collapse, drag to move with position persistence,
#   auto-refresh every 5s, single instance, left-edge default column.
# Phase 3: desktop launcher bat + Startup autostart bat (reboot-proof) +
#   live tests (pid alive, >=2 box windows found by pid, desktop item
#   counts per category, screenshot, wallpaper unaffected).
import ctypes, os, sys, time, subprocess, json, struct, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R284_DESKBOX_TRANSLUCENT.md'; J=OUT/'r284-deskbox-translucent.json'
SHOT_BOX=OUT/'r284_deskbox_visible.bmp'
M1=OUT/'r284_m1.bmp'; M2=OUT/'r284_m2.bmp'
WALLROOT=Path(r'E:\0mcp-agv-arena-optimized\wallpapers'); PACK=WALLROOT/'lively-12'
DBOX_DIR=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2'); DBOX_DIR.mkdir(parents=True,exist_ok=True)
DESKBOX_PY=DBOX_DIR/'deskbox.py'; DBOX_CFG=DBOX_DIR/'deskbox-config.json'
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

L('# R284 DeskBox discovery + translucent desktop-folder v2')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
lively=''
for c in LIVELY_CANDIDATES:
    if Path(c).exists(): lively=c; break
L('lively_exe='+str(lively))

# ---- 0. real desktop
DESK_DIR=DESK_FALLBACK
try:
    c,o=run(['reg','query',r'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders','/v','Desktop'],timeout=15)
    for ln in (o or '').splitlines():
        if 'REG_SZ' in ln and 'Desktop' in ln:
            cand=ln.split('REG_SZ',1)[1].strip()
            if cand and Path(cand).exists(): DESK_DIR=Path(cand); break
except Exception as ex: L('reg_desktop_error='+repr(ex))
L('real_desktop='+str(DESK_DIR))
DBOX_BAT=DESK_DIR/'桌面整理盒.bat'
STARTER_BAT=STARTUP_DIR/'DeskBox Startup.bat'

# ---- 1. DISCOVERY: find every deskbox trace on the machine
L('--- deskbox discovery ---')
def scan_dir_for_deskbox(base,depth=2):
    hits=[]
    base=Path(base)
    if not base.is_dir(): return hits
    try:
        for e in os.scandir(base):
            if 'deskbox' in e.name.lower(): hits.append((base, e.name, 'dir' if e.is_dir() else 'file'))
            if e.is_dir() and not e.name.startswith('.') and depth>1 and 'windows' not in e.name.lower():
                hits+=scan_dir_for_deskbox(e.path,depth-1)
    except Exception: pass
    return hits
disc_roots=[DESK_DIR,DESK_FALLBACK,DESK_DIR.parent if DESK_DIR.parent.exists() else Path('D:/'),Path(r'C:\Users\Public\Desktop'),Path(os.environ.get('LOCALAPPDATA','')),Path(os.environ.get('APPDATA','')),Path(r'C:\Program Files'),Path(r'C:\Program Files (x86)'),Path(r'E:\0mcp-agv-arena-optimized'),Path(r'C:\Users\文少' if Path(r'C:\Users\文少').exists() else os.environ.get('USERPROFILE',''))]
seen=set(); discovery=[]
for r in disc_roots:
    for base,name,kind in scan_dir_for_deskbox(r,depth=2):
        p=Path(base)/name
        if str(p).lower() in seen: continue
        seen.add(str(p).lower()); discovery.append(str(p))
        L('deskbox_hit| %s %s'%(kind,p))
        if kind=='dir':
            try:
                inner=sorted(Path(p).iterdir())[:15]
                for f in inner: L('   in| '+f.name[:90]+' '+('DIR' if f.is_dir() else str(f.stat().st_size)))
            except Exception: pass
c,o=run(['tasklist'],timeout=30)
for ln in (o or '').splitlines():
    if 'deskbox' in ln.lower(): L('deskbox_process| '+ln.strip()[:120])
for hive in ['HKCU','HKLM']:
    c,o=run(['reg','query',hive+r'\Software\Microsoft\Windows\CurrentVersion\Uninstall'],timeout=20)
    for ln in (o or '').splitlines():
        if 'deskbox' in ln.lower(): L('deskbox_uninstall_%s| %s'%(hive,ln.strip()[:120]))
for f in sorted(STARTUP_DIR.iterdir()) if STARTUP_DIR.exists() else []:
    if 'deskbox' in f.name.lower(): L('deskbox_startup| '+f.name)
L('discovery_total_hits=%d'%len(discovery))
if not discovery: L('deskbox_not_found_anywhere=True (will install fresh v2)')

# ---- 2. write deskbox.py (translucent desktop-folder boxes)
deskbox_src=(
"# deskbox.py - translucent desktop-folder boxes (DeskBox v2, r284)\n"
"# Fences-style: desktop items auto-grouped into floating translucent boxes.\n"
"import json, os, sys\n"
"from pathlib import Path\n"
"import tkinter as tk\n"
"BASE = Path(__file__).resolve().parent\n"
"CFG = BASE / 'deskbox-config.json'\n"
"PID_FILE = BASE / 'deskbox.pid'\n"
"REG_DESKTOP = None\n"
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
"def pid_alive(pid):\n"
"    try:\n"
"        import subprocess\n"
"        o = subprocess.run(['tasklist','/FI','PID eq %d' % pid], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20, text=True, errors='replace').stdout or ''\n"
"        return str(pid) in o\n"
"    except Exception: return False\n"
"try:\n"
"    old = int(PID_FILE.read_text().strip())\n"
"    if old != os.getpid() and pid_alive(old): sys.exit(0)\n"
"except Exception: pass\n"
"PID_FILE.write_text(str(os.getpid()), encoding='ascii')\n"
"BG='#10141d'; CARD='#1a2130'; CARD_HOT='#232e44'; FG='#dfe6f2'; FG_DIM='#8b97ad'; ACCENT='#7fd4ff'; HOT='#7fe0a0'\n"
"CATEGORIES=[('folders','文件夹'),( 'programs','程序'),('docs','文档'),('images','图片'),('video','视频'),('archives','压缩包'),('other','其他')]\n"
"EXT={'docs':{'.txt','.md','.doc','.docx','.pdf','.xls','.xlsx','.ppt','.pptx','.csv'},'images':{'.png','.jpg','.jpeg','.webp','.gif','.bmp','.ico'},\n"
"     'video':{'.mp4','.mkv','.webm','.avi','.mov','.flv'},'archives':{'.zip','.rar','.7z','.tar','.gz'}}\n"
"def categorize(items):\n"
"    boxes={'folders':[],'programs':[],'docs':[],'images':[],'video':[],'archives':[],'other':[]}\n"
"    for p in items:\n"
"        if p.is_dir(): boxes['folders'].append(p)\n"
"        elif p.suffix.lower() in ('.lnk','.url','.exe','.bat'): boxes['programs'].append(p)\n"
"        else:\n"
"            for cat,exts in EXT.items():\n"
"                if p.suffix.lower() in exts: boxes[cat].append(p); break\n"
"            else: boxes['other'].append(p)\n"
"    return boxes\n"
"def desktop_items():\n"
"    out={}\n"
"    for d in (real_desktop(), Path(os.environ.get('PUBLIC', r'C:\\Users\\Public'))/'Desktop'):\n"
"        try:\n"
"            for p in sorted(d.iterdir(), key=lambda x: x.name.lower()):\n"
"                if p.name.lower() in ('desktop.ini','thumbs.db') or p.name.startswith('.'): continue\n"
"                out[p.name.lower()]=p\n"
"        except Exception: pass\n"
"    return list(out.values())\n"
"def load_cfg():\n"
"    try: return json.loads(CFG.read_text(encoding='utf-8'))\n"
"    except Exception: return {'boxes':{}}\n"
"def save_cfg(cfg):\n"
"    try: CFG.write_text(json.dumps(cfg,ensure_ascii=False,indent=2),encoding='utf-8')\n"
"    except Exception: pass\n"
"root=tk.Tk()\n"
"root.withdraw()\n"
"root.title('deskbox-v2')\n"
"SW,SH=root.winfo_screenwidth(),root.winfo_screenheight()\n"
"cfg=load_cfg()\n"
"BOX_W=300; state={'cfg':cfg}\n"
"class Box:\n"
"    def __init__(self,key,title,items,x,y):\n"
"        self.key=key; self.items=items; self.collapsed=bool(cfg['boxes'].get(key,{}).get('collapsed',False))\n"
"        self.win=tk.Toplevel(root)\n"
"        self.win.overrideredirect(True)\n"
"        self.win.attributes('-alpha',0.85)\n"
"        self.win.configure(bg=BG)\n"
"        self.x=cfg['boxes'].get(key,{}).get('x',x); self.y=cfg['boxes'].get(key,{}).get('y',y)\n"
"        self.build()\n"
"        self.place()\n"
"    def build(self):\n"
"        for w in self.win.winfo_children(): w.destroy()\n"
"        head=tk.Frame(self.win,bg=BG)\n" 
"        head.pack(fill='x',padx=10,pady=(8,2))\n"
"        t=tk.Label(head,text=self.title+'  ('+str(len(self.items))+')',bg=BG,fg=ACCENT,font=('Microsoft YaHei UI',10,'bold'))\n"
"        t.pack(side='left')\n"
"        self.btn=tk.Label(head,text=('%c'%0x2014) if not self.collapsed else '+',bg=BG,fg=FG_DIM,font=('Microsoft YaHei UI',10),width=3,cursor='hand2')\n"
"        self.btn.pack(side='right')\n"
"        x2=tk.Label(head,text=('%c'%0x2715),bg=BG,fg=FG_DIM,font=('Microsoft YaHei UI',10),width=3,cursor='hand2')\n"
"        x2.pack(side='right')\n"
"        x2.bind('<Button-1>',lambda e: quit_all())\n"
"        self.btn.bind('<Button-1>',lambda e: self.toggle())\n"
"        drag={'x':0,'y':0}\n"
"        def ds(e): drag['x'],drag['y']=e.x_root-self.win.winfo_x(),e.y_root-self.win.winfo_y()\n"
"        def dm(e): self.win.geometry('+%d+%d'%(e.x_root-drag['x'],e.y_root-drag['y']))\n"
"        def drel(e): self.x=self.win.winfo_x(); self.y=self.win.winfo_y(); persist()\n"
"        for w in (head,t,self.btn,x2):\n"
"            w.bind('<ButtonPress-1>',ds); w.bind('<B1-Motion>',dm); w.bind('<ButtonRelease-1>',drel)\n"
"        if not self.collapsed and self.items:\n"
"            cv=tk.Canvas(self.win,bg=BG,bd=0,highlightthickness=0)\n"
"            cv.pack(fill='both',expand=True,padx=8,pady=4)\n"
"            inner=tk.Frame(cv,bg=BG)\n"
"            cw=cv.create_window((0,0),window=inner,anchor='nw')\n"
"            def fw(e): cv.itemconfigure(cw,width=cv.winfo_width())\n"
"            cv.bind('<Configure>',fw)\n"
"            def wheel(e): cv.yview_scroll(int(-1*(e.delta/120)),'units')\n"
"            cv.bind_all('<MouseWheel>',wheel)\n"
"            for p in self.items[:40]:\n"
"                row=tk.Frame(inner,bg=CARD)\n"
"                row.pack(fill='x',pady=1)\n"
"                nm=p.name\n"
"                if len(nm)>26: nm=nm[:25]+'..'\n"
"                lab=tk.Label(row,text=nm,bg=CARD,fg=FG,font=('Microsoft YaHei UI',9),anchor='w',cursor='hand2')\n"
"                lab.pack(fill='x',expand=True,padx=8,pady=3)\n"
"                def hot(e,r=row,l=lab): r.configure(bg=CARD_HOT); l.configure(bg=CARD_HOT)\n"
"                def cold(e,r=row,l=lab): r.configure(bg=CARD); l.configure(bg=CARD)\n"
"                def op(e,path=p):\n"
"                    try: os.startfile(str(path))\n"
"                    except Exception: pass\n"
"                for w in (row,lab):\n"
"                    w.bind('<Enter>',hot); w.bind('<Leave>',cold); w.bind('<Double-Button-1>',op)\n"
"            def fit(e=None):\n"
"                inner.update_idletasks()\n"
"                cv.configure(scrollregion=cv.bbox('all'))\n"
"            inner.bind('<Configure>',fit)\n"
"    def toggle(self):\n"
"        self.collapsed=not self.collapsed\n"
"        cfg['boxes'].setdefault(self.key,{})['collapsed']=self.collapsed\n"
"        save_cfg(cfg)\n"
"        self.build(); self.place()\n"
"    def place(self):\n"
"        if self.collapsed: h=44\n"
"        else: h=min(60+30*min(len(self.items),40),430)\n"
"        self.win.geometry('%dx%d+%d+%d'%(BOX_W,h,max(8,self.x),max(8,self.y)))\n"
"boxes=[]\n"
"def persist():\n"
"    for b in boxes:\n"
"        cfg['boxes'].setdefault(b.key,{})['x']=b.win.winfo_x()\n"
"        cfg['boxes'].setdefault(b.key,{})['y']=b.win.winfo_y()\n"
"    save_cfg(cfg)\n"
"def quit_all():\n"
"    persist()\n"
"    try: PID_FILE.unlink()\n"
"    except Exception: pass\n"
"    root.destroy()\n"
"def rebuild():\n"
"    global boxes\n"
"    items=desktop_items()\n"
"    boxes_map=categorize(items)\n"
"    y=14; col=0\n"
"    old={b.key:b for b in boxes}\n"
"    newboxes=[]\n"
"    for key,title in CATEGORIES:\n"
"        if not boxes_map[key]: continue\n"
"        if key in old:\n"
"            b=old[key]; b.items=boxes_map[key]; b.build(); b.place()\n"
"        else:\n"
"            b=Box(key,title,boxes_map[key],14+col*(BOX_W+12),y)\n"
"        if key not in old: y+=min(60+30*min(len(boxes_map[key]),40),430)+10\n"
"        if y>SH-480: y=14; col+=1\n"
"        newboxes.append(b)\n"
"    for b in boxes:\n"
"        if b.key not in {nb.key for nb in newboxes}: b.win.destroy()\n"
"    boxes=newboxes\n"
"    root.after(5000,rebuild)\n"
"rebuild()\n"
"root.mainloop()\n"
"try: PID_FILE.unlink()\n"
"except Exception: pass\n")
try:
    WT(DESKBOX_PY,deskbox_src)
    L('deskbox_py='+str(DESKBOX_PY)+' exists='+str(DESKBOX_PY.exists())+' bytes='+str(DESKBOX_PY.stat().st_size))
except Exception as ex: L('deskbox_py_error='+repr(ex))
deskbox_installed=bool(DESKBOX_PY.exists() and DESKBOX_PY.stat().st_size>5000)

# ---- 3. launcher bats
try:
    bat=('@echo off\r\n'
         'rem DeskBox v2 - translucent desktop folder boxes\r\n'
         'set "BOX='+str(DESKBOX_PY)+'"\r\n'
         'where pythonw.exe >nul 2>&1 && (start "" pythonw.exe "%BOX%") || (start "" /min python.exe "%BOX%")\r\n')
    WA(DBOX_BAT,bat)
    L('deskbox_bat='+str(DBOX_BAT)+' exists='+str(DBOX_BAT.exists()))
except Exception as ex: L('deskbox_bat_error='+repr(ex))
try:
    sbat=('@echo off\r\n'
          'rem DeskBox v2 - start at logon\r\n'
          'ping -n 16 127.0.0.1 >nul\r\n'
          'set "BOX='+str(DESKBOX_PY)+'"\r\n'
          'where pythonw.exe >nul 2>&1 && (start "" pythonw.exe "%BOX%") || (start "" /min python.exe "%BOX%")\r\n')
    WA(STARTER_BAT,sbat)
    L('startup_bat='+str(STARTER_BAT)+' exists='+str(STARTER_BAT.exists()))
except Exception as ex: L('startup_bat_error='+repr(ex))
bats_installed=bool(DBOX_BAT.exists() and STARTER_BAT.exists())

# ---- 4. live test: launch, pid + windows, category counts, screenshot
box_pid=None; box_alive=False; box_windows=0; cat_counts={}
if deskbox_installed:
    try:
        c,o=run([sys.executable,'-c','import tkinter;print("tk-ok")'],timeout=60)
        L('tkinter_ok='+str(c==0 and 'tk-ok' in (o or '')))
        subprocess.Popen([sys.executable,str(DESKBOX_PY)],creationflags=0x08000000,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        time.sleep(8)
        for _ in range(6):
            try:
                box_pid=int((DBOX_DIR/'deskbox.pid').read_text().strip()); break
            except Exception: time.sleep(2)
        L('deskbox_pid='+str(box_pid))
        if box_pid:
            c,o=run(['tasklist','/FI','PID eq %d'%box_pid],timeout=20)
            box_alive=str(box_pid) in (o or '')
            L('deskbox_process_alive='+str(box_alive))
        top,children=windows_report()
        for w in top:
            if w[3] and box_pid and w[2]==box_pid:
                box_windows+=1
                L('   box_window| class='+w[1]+' rect='+str((w[4],w[5],w[6],w[7])))
        L('box_windows_found='+str(box_windows))
        items=sorted([p for p in DESK_DIR.iterdir() if p.name.lower() not in ('desktop.ini','thumbs.db')],key=lambda x:x.name.lower()) if DESK_DIR.exists() else []
        pub=Path(os.environ.get('PUBLIC',r'C:\Users\Public'))/'Desktop'
        if pub.exists(): items+= [p for p in sorted(pub.iterdir(),key=lambda x:x.name.lower()) if p.name.lower() not in ('desktop.ini','thumbs.db')]
        EXTS={'docs':{'.txt','.md','.doc','.docx','.pdf','.xls','.xlsx','.ppt','.pptx','.csv'},'images':{'.png','.jpg','.jpeg','.webp','.gif','.bmp','.ico'},'video':{'.mp4','.mkv','.webm','.avi','.mov','.flv'},'archives':{'.zip','.rar','.7z','.tar','.gz'}}
        for p in items:
            if p.is_dir(): cat_counts['folders']=cat_counts.get('folders',0)+1
            elif p.suffix.lower() in ('.lnk','.url','.exe','.bat'): cat_counts['programs']=cat_counts.get('programs',0)+1
            else:
                for cat,ex in EXTS.items():
                    if p.suffix.lower() in ex: cat_counts[cat]=cat_counts.get(cat,0)+1; break
                else: cat_counts['other']=cat_counts.get('other',0)+1
        L('desktop_items_categorized='+json.dumps(cat_counts))
        mini(); time.sleep(2)
        ok,w,h,e=shot(SHOT_BOX); L(f'deskbox_screenshot ok={ok} ({SHOT_BOX.name})')
    except Exception as ex: L('deskbox_test_error='+repr(ex))
    finally:
        if box_pid:
            run(['taskkill','/F','/PID',str(box_pid)],timeout=20); time.sleep(2)
            c,o=run(['tasklist','/FI','PID eq %d'%box_pid],timeout=20)
            L('deskbox_killed='+str(str(box_pid) not in (o or '')))

# ---- 5. wallpaper unaffected
pl=wallpaper_players_in_layer(); tmap=tasklist_map()
for c in pl[:3]: L('   wallpaper_player| class='+c[1]+' owner='+tmap.get(c[2],'?'))
layer_final=len(pl)>0; L('layer_final='+str(layer_final))
mini(); time.sleep(1); ok,w,h,e=shot(M1); L(f'm1 ok={ok}')
time.sleep(30); ok,w,h,e=shot(M2); L(f'm2 ok={ok}')
d_m=diff(M1,M2)
L('motion_ratio=%.6f'%d_m['ratio']); L('motion_avg=%.3f'%d_m['avg'])
motion_final=bool(d_m.get('ok') and (d_m['ratio']>0.0005 or d_m['avg']>0.25))
L('motion_final_proven='+str(motion_final))
try:
    WT(DBOX_DIR/'PATHS.txt','DeskBox v2 - translucent desktop folder boxes (r284)\r\n====================================================\r\nentry      : '+str(DESKBOX_PY)+'\r\nlauncher   : desktop '+str(DBOX_BAT)+'\r\nautostart  : '+str(STARTER_BAT)+'\r\nconfig     : '+str(DBOX_CFG)+' (box positions + collapsed state, saved on drag)\r\ncategories : folders / programs / docs / images / video / archives / other\r\nusage      : double-click an item to open it; drag a box header to move;\r\n             - collapses a box; x exits DeskBox; auto-refresh every 5s\r\n')
    L('paths_txt_ok=True')
except Exception: pass

ready=bool(deskbox_installed and bats_installed and box_alive and box_windows>=2 and cat_counts and layer_final and motion_final and not locked)
L('DESKBOX_TRANSLUCENT_READY='+str(ready))
summary={'ready':ready,'locked':locked,'discoveryHits':discovery,'deskboxPy':str(DESKBOX_PY),'deskboxBat':str(DBOX_BAT),'startupBat':str(STARTER_BAT),'boxPid':box_pid,'boxAlive':box_alive,'boxWindows':box_windows,'categoryCounts':cat_counts,'layerFinal':layer_final,'motionFinalRatio':d_m.get('ratio')}
WT(J,json.dumps(summary,ensure_ascii=False,indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
