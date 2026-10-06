# t235_translucent_panel_r283.py - round 283.
# User request: a PRETTIER UI than the old DeskBox - translucent, does not
# block the dynamic wallpaper, wallpaper launch/switch stays on the desktop,
# and it must work after reboot.
# Deliverables:
#   E:\...\lively-12\panel.py : tkinter borderless translucent panel
#       (alpha 0.85, dark cards, docked right edge, drag to move, single
#        instance, 24 wallpaper cards + next/auto on-off/interval cycle/
#        repair buttons; imports switcher.py directly - no subprocess)
#   desktop  壁纸面板.bat      : launches the panel via pythonw (no console)
#   Startup  Wallpaper Panel Startup.bat : auto-start at logon (reboot-safe)
# Live tests: tkinter availability, panel launch -> pid alive + Tk window
#   found by class/rect via EnumWindows, screenshot with the panel open
#   (receipt artifact), kill, wallpaper layer + motion still fine.
import ctypes, os, sys, time, subprocess, json, struct, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R283_WALLPAPER_PANEL.md'; J=OUT/'r283-wallpaper-panel.json'
SHOT_PANEL=OUT/'r283_panel_visible.bmp'
M1=OUT/'r283_m1.bmp'; M2=OUT/'r283_m2.bmp'
WALLROOT=Path(r'E:\0mcp-agv-arena-optimized\wallpapers'); PACK=WALLROOT/'lively-12'
PANEL=PACK/'panel.py'
LIVELY_CANDIDATES=[r'C:\Program Files\Lively Wallpaper\Lively.exe',r'C:\Program Files (x86)\Lively Wallpaper\Lively.exe']
DESK_FALLBACK=Path(os.environ.get('USERPROFILE',r'C:\Users\Public'))/'Desktop'
STARTUP_DIR=Path(os.environ.get('APPDATA',r'C:\Users\Public'))/'Microsoft'/'Windows'/'Start Menu'/'Programs'/'Startup'
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

L('# R283 translucent wallpaper panel (prettier UI, reboot-proof)')
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
PANEL_BAT=DESK_DIR/'壁纸面板.bat'
STARTER_BAT=STARTUP_DIR/'Wallpaper Panel Startup.bat'

# ---- 1. tkinter availability
c,o=run([sys.executable,'-c','import tkinter;print("tk-ok")'],timeout=60)
tkinter_ok=(c==0 and 'tk-ok' in (o or ''))
L('tkinter_available='+str(tkinter_ok)+' out='+(' '.join((o or '').split())[:120]))

# ---- 2. write panel.py (imports switcher, no path literals, no prints)
panel_src=(
"# panel.py - translucent wallpaper switcher panel (r283)\n"
"# Borderless tkinter window, alpha 0.85, docked to the right screen edge,\n"
"# drag the header to move. Imports switcher.py for all actions.\n"
"import colorsys, json, sys, threading\n"
"from pathlib import Path\n"
"BASE = Path(__file__).resolve().parent\n"
"sys.path.insert(0, str(BASE))\n"
"import tkinter as tk\n"
"import switcher\n"
"PID_FILE = BASE / 'panel.pid'\n"
"import os\n"
"def pid_alive(pid):\n"
"    try:\n"
"        out = switcher.run(['tasklist', '/FI', 'PID eq %d' % pid], timeout=20)[1] or ''\n"
"        return str(pid) in out\n"
"    except Exception:\n"
"        return False\n"
"try:\n"
"    old = int(PID_FILE.read_text().strip())\n"
"    if old != os.getpid() and pid_alive(old):\n"
"        sys.exit(0)\n"
"except Exception:\n"
"    pass\n"
"PID_FILE.write_text(str(os.getpid()), encoding='ascii')\n"
"BG = '#10141d'\n"
"CARD = '#1a2130'\n"
"CARD_HOT = '#232e44'\n"
"CARD_CUR = '#27354f'\n"
"FG = '#dfe6f2'\n"
"FG_DIM = '#8b97ad'\n"
"ACCENT = '#7fd4ff'\n"
"root = tk.Tk()\n"
"root.title('wallpaper-panel')\n"
"root.overrideredirect(True)\n"
"root.attributes('-alpha', 0.85)\n"
"root.configure(bg=BG)\n"
"W, H = 372, 668\n"
"SW, SH = root.winfo_screenwidth(), root.winfo_screenheight()\n"
"root.geometry('%dx%d+%d+%d' % (W, H, SW - W - 14, max(10, (SH - H) // 2)))\n"
"def badge_color(i, n):\n"
"    r, g, b = colorsys.hls_to_rgb((i - 1) / max(1, n), 0.62, 0.60)\n"
"    return '#%02x%02x%02x' % (int(r * 255), int(g * 255), int(b * 255))\n"
"def do_thread(fn):\n"
"    threading.Thread(target=fn, daemon=True).start()\n"
"header = tk.Frame(root, bg=BG)\n"
"header.pack(fill='x', padx=14, pady=(12, 4))\n"
"title_lbl = tk.Label(header, text='动态壁纸', bg=BG, fg=FG, font=('Microsoft YaHei UI', 14, 'bold'))\n"
"title_lbl.pack(side='left')\n"
"status_lbl = tk.Label(header, text='', bg=BG, fg=FG_DIM, font=('Microsoft YaHei UI', 9))\n"
"status_lbl.pack(side='right')\n"
"close_lbl = tk.Label(header, text='✕', bg=BG, fg=FG_DIM, font=('Microsoft YaHei UI', 11, 'bold'), width=3)\n"
"close_lbl.pack(side='right')\n"
"close_lbl.bind('<Button-1>', lambda e: root.destroy())\n"
"close_lbl.bind('<Enter>', lambda e: close_lbl.configure(fg='#ff8080'))\n"
"close_lbl.bind('<Leave>', lambda e: close_lbl.configure(fg=FG_DIM))\n"
"drag = {'x': 0, 'y': 0}\n"
"def drag_start(e):\n"
"    drag['x'], drag['y'] = e.x, e.y\n"
"def drag_move(e):\n"
"    root.geometry('+%d+%d' % (root.winfo_x() + e.x - drag['x'], root.winfo_y() + e.y - drag['y']))\n"
"for wgt in (header, title_lbl, status_lbl):\n"
"    wgt.bind('<Button-1>', drag_start)\n"
"    wgt.bind('<B1-Motion>', drag_move)\n"
"canvas = tk.Canvas(root, bg=BG, bd=0, highlightthickness=0)\n"
"canvas.pack(fill='both', expand=True, padx=10, pady=4)\n"
"cards_frame = tk.Frame(canvas, bg=BG)\n"
"cards_win = canvas.create_window((0, 0), window=cards_frame, anchor='nw')\n"
"def fit_width(e):\n"
"    canvas.itemconfigure(cards_win, width=canvas.winfo_width())\n"
"canvas.bind('<Configure>', fit_width)\n"
"def on_wheel(e):\n"
"    canvas.yview_scroll(int(-1 * (e.delta / 120)), 'units')\n"
"root.bind_all('<MouseWheel>', on_wheel)\n"
"cat = switcher.load_cat()\n"
"card_widgets = []\n"
"def make_card(item):\n"
"    idx = item['idx']\n"
"    row = tk.Frame(cards_frame, bg=CARD)\n"
"    row.pack(fill='x', pady=2)\n"
"    num = tk.Label(row, text='%02d' % idx, bg=CARD, fg=badge_color(idx, len(cat)), font=('Microsoft YaHei UI', 10, 'bold'), width=3)\n"
"    num.pack(side='left', padx=(8, 2), pady=5)\n"
"    name = tk.Label(row, text=item['cn'], bg=CARD, fg=FG, font=('Microsoft YaHei UI', 10), anchor='w')\n"
"    name.pack(side='left', fill='x', expand=True, pady=5)\n"
"    mark = tk.Label(row, text='', bg=CARD, fg=ACCENT, font=('Microsoft YaHei UI', 9, 'bold'), width=2)\n"
"    mark.pack(side='right', padx=6)\n"
"    def hot(e):\n"
"        if switcher.load_state()['current'] != idx:\n"
"            for w2 in (row, num, name, mark): w2.configure(bg=CARD_HOT)\n"
"    def cold(e):\n"
"        cur = switcher.load_state()['current'] == idx\n"
"        for w2 in (row, num, name, mark): w2.configure(bg=CARD_CUR if cur else CARD)\n"
"    def click(e):\n"
"        do_thread(lambda: switcher.apply(idx))\n"
"    for w2 in (row, num, name, mark):\n"
"        w2.bind('<Enter>', hot)\n"
"        w2.bind('<Leave>', cold)\n"
"        w2.bind('<Button-1>', click)\n"
"        w2.configure(cursor='hand2')\n"
"    card_widgets.append((idx, row, num, name, mark))\n"
"for item in cat:\n"
"    make_card(item)\n"
"bottom = tk.Frame(root, bg=BG)\n"
"bottom.pack(fill='x', padx=10, pady=(4, 12))\n"
"def flat_btn(parent, text, cmd, fg=FG):\n"
"    b = tk.Label(parent, text=text, bg=CARD, fg=fg, font=('Microsoft YaHei UI', 10), padx=8, pady=5, cursor='hand2')\n"
"    b.bind('<Button-1>', lambda e: cmd())\n"
"    b.bind('<Enter>', lambda e: b.configure(bg=CARD_HOT))\n"
"    b.bind('<Leave>', lambda e: b.configure(bg=CARD))\n"
"    return b\n"
"interval_lbl = tk.Label(bottom, text='', bg=CARD, fg=ACCENT, font=('Microsoft YaHei UI', 10), padx=8, pady=5, cursor='hand2')\n"
"def cycle_interval():\n"
"    st = switcher.load_state()\n"
"    vals = [v for v, lab in switcher.INTERVALS]\n"
"    cur = int(st.get('interval', 1800))\n"
"    nxt = vals[(vals.index(cur) + 1) % len(vals)] if cur in vals else vals[0]\n"
"    st['interval'] = nxt\n"
"    switcher.save_state(st)\n"
"    switcher.log('panel: interval -> %ds' % nxt)\n"
"    refresh()\n"
"interval_lbl.bind('<Button-1>', lambda e: cycle_interval())\n"
"def refresh():\n"
"    try:\n"
"        st = switcher.load_state()\n"
"        cur = st['current']\n"
"        for idx, row, num, name, mark in card_widgets:\n"
"            bgc = CARD_CUR if idx == cur else CARD\n"
"            for w2 in (row, num, name, mark): w2.configure(bg=bgc)\n"
"            mark.configure(text='✓' if idx == cur else '')\n"
"        if st.get('auto_on'):\n"
"            pool = st.get('pool') or []\n"
"            status_lbl.configure(text='自动 ' + switcher.interval_label(st.get('interval', 1800)) + (' | 轮换%d款' % len(pool) if pool else ''), fg='#7fe0a0')\n"
"        else:\n"
"            status_lbl.configure(text='手动', fg=FG_DIM)\n"
"        iv = switcher.interval_label(st.get('interval', 1800))\n"
"        interval_lbl.configure(text='间隔 ' + iv)\n"
"    except Exception:\n"
"        pass\n"
"    root.after(2000, refresh)\n"
"flat_btn(bottom, '下一张', lambda: do_thread(switcher.next_one)).pack(side='left', padx=(0, 4))\n"
"flat_btn(bottom, '自动 开', lambda: do_thread(switcher.auto_start), fg='#7fe0a0').pack(side='left', padx=4)\n"
"flat_btn(bottom, '自动 关', lambda: do_thread(switcher.auto_stop), fg='#ffb37f').pack(side='left', padx=4)\n"
"interval_lbl.pack(side='left', padx=4)\n"
"flat_btn(bottom, '修复', lambda: do_thread(switcher.repair_current)).pack(side='right')\n"
"refresh()\n"
"root.mainloop()\n"
"try:\n"
"    PID_FILE.unlink()\n"
"except Exception:\n"
"    pass\n")
try:
    WT(PANEL,panel_src)
    L('panel_py='+str(PANEL)+' exists='+str(PANEL.exists())+' bytes='+str(PANEL.stat().st_size))
except Exception as ex: L('panel_py_error='+repr(ex))
panel_installed=bool(PANEL.exists() and PANEL.stat().st_size>6000)

# ---- 3. desktop launcher + Startup bat (reboot-proof)
try:
    bat=('@echo off\r\n'
         'rem translucent wallpaper panel launcher\r\n'
         'set "PANEL='+str(PANEL)+'"\r\n'
         'where pythonw.exe >nul 2>&1 && (start "" pythonw.exe "%PANEL%") || (start "" /min python.exe "%PANEL%")\r\n')
    WA(PANEL_BAT,bat)
    L('panel_bat='+str(PANEL_BAT)+' exists='+str(PANEL_BAT.exists()))
except Exception as ex: L('panel_bat_error='+repr(ex))
try:
    sbat=('@echo off\r\n'
          'rem wallpaper panel - start at logon (after a short settle delay)\r\n'
          'ping -n 11 127.0.0.1 >nul\r\n'
          'set "PANEL='+str(PANEL)+'"\r\n'
          'where pythonw.exe >nul 2>&1 && (start "" pythonw.exe "%PANEL%") || (start "" /min python.exe "%PANEL%")\r\n')
    WA(STARTER_BAT,sbat)
    L('startup_bat='+str(STARTER_BAT)+' exists='+str(STARTER_BAT.exists()))
except Exception as ex: L('startup_bat_error='+repr(ex))
bats_installed=bool(PANEL_BAT.exists() and STARTER_BAT.exists())

# ---- 4. live test: launch panel, verify pid + Tk window, screenshot, kill
panel_pid=None; panel_alive=False; panel_window_found=False
if panel_installed and tkinter_ok:
    try:
        subprocess.Popen([sys.executable,str(PANEL)],creationflags=0x08000000,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        time.sleep(8)
        for _ in range(6):
            try:
                panel_pid=int((PACK/'panel.pid').read_text().strip()); break
            except Exception: time.sleep(2)
        L('panel_pid='+str(panel_pid))
        if panel_pid:
            c,o=run(['tasklist','/FI','PID eq %d'%panel_pid],timeout=20)
            panel_alive=str(panel_pid) in (o or '')
            L('panel_process_alive='+str(panel_alive))
        top,children=windows_report()
        for w in top:
            if w[3] and panel_pid and w[2]==panel_pid and 300<=(w[6]-w[4])<=430 and 450<=(w[7]-w[5])<=780:
                panel_window_found=True
                L('panel_window| class='+w[1]+' pid='+str(w[2])+' rect='+str((w[4],w[5],w[6],w[7])))
                break
        L('panel_window_found='+str(panel_window_found))
        mini(); time.sleep(2)
        ok,w,h,e=shot(SHOT_PANEL); L(f'panel_screenshot ok={ok} ({SHOT_PANEL.name})')
    except Exception as ex: L('panel_test_error='+repr(ex))
    finally:
        if panel_pid:
            run(['taskkill','/F','/PID',str(panel_pid)],timeout=20); time.sleep(2)
            c,o=run(['tasklist','/FI','PID eq %d'%panel_pid],timeout=20)
            L('panel_killed='+str(str(panel_pid) not in (o or '')))

# ---- 5. wallpaper still fine
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
    WT(PACK/'PATHS.txt',open(PACK/'PATHS.txt',encoding='utf-8').read()+'panel       : '+str(PANEL)+' (translucent UI; desktop bat: panel; Startup bat autostarts it)\r\n')
    L('paths_txt_updated=True')
except Exception: pass

ready=bool(panel_installed and tkinter_ok and bats_installed and panel_alive and panel_window_found and layer_final and motion_final and not locked)
L('TRANSLUCENT_PANEL_READY='+str(ready))
summary={'ready':ready,'locked':locked,'panelPy':str(PANEL),'panelBat':str(PANEL_BAT),'startupBat':str(STARTER_BAT),'tkinterOk':tkinter_ok,'panelAlive':panel_alive,'panelWindowFound':panel_window_found,'layerFinal':layer_final,'motionFinalRatio':d_m.get('ratio')}
WT(J,json.dumps(summary,ensure_ascii=False,indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
