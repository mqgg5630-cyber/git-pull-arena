# t229_wallpaper_switcher_12pack_r277.py - round 277.
# User request: 12 anime dynamic wallpapers (hotori + 11 new from the Lively
# CDN), a switcher with MANUAL pick + AUTO rotation, the entry bat on the
# REAL desktop (user's desktop is on D:), and the OLD C:-desktop artifacts
# cleaned up.
# Deliverables:
#   E:\...\wallpapers\lively-12\ : 12 mp4s + wallpapers.json + state.json
#                                  + switcher.py + auto_rotate.py + keeper12.py
#   <real desktop>\动态壁纸切换器.bat : interactive menu (CN), set/next/auto
#   Startup\Lively Wallpaper Keeper.bat : now runs keeper12.py (restores the
#                                  CURRENT selection at logon, restarts auto)
# Cleanup: C:\Users\<u>\Desktop\一键启动动态壁纸.bat + DeskBox marker, old
#          lively-hotori folder (best effort, after the pack is live).
# Live tests: manual switch w1->w2 pixel-diff, auto rotation 25s x2 ticks,
#          keeper12 --now, final motion probe.
import ctypes, os, sys, time, subprocess, json, shutil, struct, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R277_WALLPAPER_SWITCHER_12PACK.md'; J=OUT/'r277-wallpaper-switcher-12pack.json'
P1=OUT/'r277_p1_wallpaper1.bmp'; P2=OUT/'r277_p2_wallpaper2.bmp'; P3=OUT/'r277_p3_after_auto.bmp'
M1=OUT/'r277_m1_final.bmp'; M2=OUT/'r277_m2_final.bmp'
WALLROOT=Path(r'E:\0mcp-agv-arena-optimized\wallpapers')
PACK=WALLROOT/'lively-12'; PACK.mkdir(parents=True,exist_ok=True)
OLD_PERM=WALLROOT/'lively-hotori'
HOTORI_SOURCES=[OLD_PERM/'hotori_dynamic_wallpaper.mp4',WALLROOT/'lively-dynamic-r274'/'hotori_dynamic_wallpaper_r274.mp4',WALLROOT/'lively-dynamic-r273'/'hotori_dynamic_wallpaper_r273.mp4']
LIVELY_CANDIDATES=[r'C:\Program Files\Lively Wallpaper\Lively.exe',r'C:\Program Files (x86)\Lively Wallpaper\Lively.exe',str(Path(os.environ.get('LOCALAPPDATA',r'C:\Users\Public'))/'Programs'/'Lively Wallpaper'/'Lively.exe')]
CDN='https://cdn.livelywallpaper.app/wallpapers/%s/%s'
PRIMARIES=[('evening-window-view','Cat at Sunset Window','夕阳窗边的黑猫'),
('beautiful-anime-girl-under-starry-sky','Girl Beneath Meteor Sky','流星夜空下的蓝发少女'),
('golden-afternoon-with-mahiru-shiina','Golden Afternoon Mahiru','金色午后的椎名真昼'),
('midnight-sakura-train-station','Midnight Sakura Station','午夜樱花车站'),
('peaceful-anime-tree-swing-live-wallpaper','Tree Swing Above Clouds','云端树秋千'),
('gojo-satoru-train','Gojo Satoru Train','五条悟·霓虹列车'),
('tanjiro-kamado-crimson-moon','Tanjiro Crimson Moon','炭治郎·红月'),
('itachi-uchiha-crimson-shadows','Itachi Crimson Shadows','鼬·绯红暗影'),
('zoro-king-of-hell','Zoro King of Hell','索隆·阎魔之王'),
('ultra-instinct-goku','Ultra Instinct Goku','悟空·自在极意功'),
('luffy-before-the-storm','Luffy Before the Storm','路飞·风暴前夕')]
FALLBACKS=[('a-cozy-cafe-rendezvous-under-the-trees','Cozy Cafe Rendezvous','树影咖啡座'),
('autumn-spirit-dance','Autumn Spirit Dance','枫叶精灵起舞'),
('butterfly-bloom-sword-spirit-forest','Butterfly Bloom Sword Forest','蝶舞剑灵之森'),
('violet-evergarden-chinese','Violet Evergarden Ink-Wash','薇尔莉特·水墨'),
('cozy-lofi-relaxing-rainy-day-aesthetic','Cozy Lofi Rainy Day','雨天lofi咖啡馆'),
('crimson-anime-eyes','Crimson Anime Eyes','绯红眼瞳'),
('anime-girl-sword-reflection','Sword Reflection Girl','剑刃倒影少女'),
('gojo-and-sukuna','Gojo and Sukuna','五条悟vs宿傩'),
('neverness-to-everness-seaside-train-station','Seaside Train Station','海边列车车站'),
('dreamy-anime-style-cottage','Dreamy Anime Cottage','梦幻动漫小屋'),
('shinchan-and-shiro-relaxing-on-water-lily','Shinchan on Water Lily','小新与小白'),
('silent-katana-in-the-forest','Silent Katana Forest','林中静刀')]
STARTUP_DIR=Path(os.environ.get('APPDATA',r'C:\Users\Public'))/'Microsoft'/'Windows'/'Start Menu'/'Programs'/'Startup'
KEEPER_BAT=STARTUP_DIR/'Lively Wallpaper Keeper.bat'
C_DESKTOP=Path(os.environ.get('USERPROFILE',r'C:\Users\Public'))/'Desktop'
C_OLD_BAT=C_DESKTOP/'一键启动动态壁纸.bat'
DESKBOX=C_DESKTOP/'DeskBox-Cute-Desktop-Organizer'
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
        return {'ok':True,'ratio':ch/sm if sm else 0,'avg':tot/sm if sm else 0,'changed':ch,'samples':sm}
    except Exception as e: return {'ok':False,'ratio':0,'avg':0,'err':repr(e)}
def mini():
    try: subprocess.run(['powershell.exe','-NoProfile','-Command','(New-Object -ComObject Shell.Application).MinimizeAll()'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10)
    except Exception: pass
def is_mp4(p,min_size=400000):
    try:
        q=Path(p); return q.is_file() and q.stat().st_size>=min_size and b'ftyp' in q.read_bytes()[:16]
    except Exception: return False
def task_count(name):
    c,o=run(['tasklist','/FI',f'IMAGENAME eq {name}']); return o.count(name)
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

L('# R277 12-pack anime wallpaper switcher (manual + auto)')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
lively=''
for c in LIVELY_CANDIDATES:
    if Path(c).exists(): lively=c; break
L('lively_exe='+str(lively))

# ---- 0. real desktop (user says it is on D:) - read from registry
DESK_DIR=C_DESKTOP
try:
    c,o=run(['reg','query',r'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders','/v','Desktop'],timeout=15)
    for ln in (o or '').splitlines():
        if 'REG_SZ' in ln and 'Desktop' in ln:
            cand=ln.split('REG_SZ',1)[1].strip()
            if cand and Path(cand).exists(): DESK_DIR=Path(cand); break
except Exception as ex: L('reg_desktop_error='+repr(ex))
L('real_desktop='+str(DESK_DIR)+' (user_profile_desktop='+str(C_DESKTOP)+')')
MENU_BAT=DESK_DIR/'动态壁纸切换器.bat'

# ---- 1. build the 12-pack
catalog=[]
hotori_src=None
for s in HOTORI_SOURCES:
    if is_mp4(s): hotori_src=s; break
if hotori_src:
    shutil.copy2(hotori_src,PACK/'01-hotori.mp4')
    catalog.append({'idx':1,'slug':'hotori','name':'Hotori (original)','cn':'Hotori（原壁纸）','file':'01-hotori.mp4'})
L('hotori_packed='+str(bool(hotori_src))+' src='+str(hotori_src))
def download(slug,dest):
    for tail in ('hd.mp4','preview.mp4'):
        c,o=run(['curl.exe','-sS','-L','--max-time','90','-o',str(dest),CDN%(slug,tail)],timeout=110)
        if c==0 and is_mp4(dest): return True
        try: dest.unlink()
        except Exception: pass
    return False
idx=1
for slug,name,cn in PRIMARIES:
    if len(catalog)>=12: break
    idx=len(catalog)+1
    dest=PACK/('%02d-%s.mp4'%(idx,slug))
    ok=download(slug,dest)
    L('download %02d %-44s %s'%(idx,slug,'OK' if ok else 'FAIL'))
    if ok: catalog.append({'idx':idx,'slug':slug,'name':name,'cn':cn,'file':dest.name})
for slug,name,cn in FALLBACKS:
    if len(catalog)>=12: break
    idx=len(catalog)+1
    dest=PACK/('%02d-%s.mp4'%(idx,slug))
    ok=download(slug,dest)
    L('download %02d %-44s %s'%(idx,slug,'OK' if ok else 'FAIL'))
    if ok: catalog.append({'idx':idx,'slug':slug,'name':name,'cn':cn,'file':dest.name})
if len(catalog)<12:
    L('cdn_short_fallback_local_scan')
    seen={e['slug'] for e in catalog}
    for f in sorted(WALLROOT.rglob('*.mp4')):
        if len(catalog)>=12: break
        if PACK in f.parents or not is_mp4(f): continue
        idx=len(catalog)+1; slug='local-%d'%idx
        dest=PACK/('%02d-local%d.mp4'%(idx,idx))
        shutil.copy2(f,dest)
        catalog.append({'idx':idx,'slug':slug,'name':f.stem[:40],'cn':'本机动漫壁纸 %d'%idx,'file':dest.name})
        L('local_fallback %02d from %s'%(idx,f.name))
pack_count=len(catalog)
valid=sum(1 for e in catalog if is_mp4(PACK/e['file']))
L('pack_count='+str(pack_count)+' valid_files='+str(valid))
WT(PACK/'wallpapers.json',json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
WT(PACK/'state.json',json.dumps({'current':1,'auto_on':False,'interval':1800},ensure_ascii=False,indent=2)+'\n')

# ---- 2. switcher.py (core + menu), auto_rotate.py, keeper12.py
switcher_src=(
"# switcher.py - 12 anime wallpapers: manual pick + auto rotation (r277)\n"
"import ctypes, json, os, re, subprocess, sys, time\n"
"from pathlib import Path\n"
"BASE = Path(__file__).resolve().parent\n"
"CATALOG = BASE / 'wallpapers.json'\n"
"STATE = BASE / 'state.json'\n"
"LOG = BASE / 'switcher.log'\n"
"LIVELY = r'C:\\Program Files\\Lively Wallpaper\\Lively.exe'\n"
"def log(m):\n"
"    try:\n"
"        entry = time.strftime('%Y-%m-%d %H:%M:%S') + ' ' + str(m) + chr(10)\n"
"        old = LOG.read_text(encoding='utf-8', errors='replace') if LOG.exists() else ''\n"
"        LOG.write_text((old + entry)[-6000:], encoding='utf-8')\n"
"    except Exception:\n"
"        pass\n"
"def run(args, timeout=30):\n"
"    try:\n"
"        p = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout, text=True, errors='replace')\n"
"        return p.returncode, p.stdout\n"
"    except Exception as e:\n"
"        return 999, repr(e)\n"
"def running(name):\n"
"    c, o = run(['tasklist', '/FI', 'IMAGENAME eq ' + name], timeout=20)\n"
"    return name in (o or '')\n"
"def layer_players():\n"
"    try:\n"
"        import ctypes.wintypes as wt\n"
"        u = ctypes.windll.user32\n"
"        top = []; children = []\n"
"        CBT = ctypes.WINFUNCTYPE(ctypes.c_bool, wt.HWND, wt.LPARAM)\n"
"        def probe(h):\n"
"            cls = ctypes.create_unicode_buffer(256); u.GetClassNameW(h, cls, 256)\n"
"            pid = wt.DWORD(); u.GetWindowThreadProcessId(h, ctypes.byref(pid))\n"
"            r = wt.RECT(); u.GetWindowRect(h, ctypes.byref(r))\n"
"            return (h, cls.value, int(pid.value), int(u.IsWindowVisible(h)), int(r.left), int(r.top), int(r.right), int(r.bottom))\n"
"        def tcb(h, l):\n"
"            top.append(probe(h)); return True\n"
"        u.EnumWindows(CBT(tcb), 0)\n"
"        roots = [w[0] for w in top if w[1] in ('WorkerW', 'Progman')]\n"
"        def ccb(h, l):\n"
"            children.append(probe(h)); return True\n"
"        for rh in roots:\n"
"            u.EnumChildWindows(rh, CBT(ccb), 0)\n"
"        names = {}\n"
"        c, o = run(['tasklist', '/FO', 'CSV', '/NH'], timeout=30)\n"
"        for ln in (o or '').splitlines():\n"
"            p = ln.split('\",\"')\n"
"            if len(p) >= 2:\n"
"                try: names[int(p[1].strip('\"'))] = p[0].strip('\"').lower()\n"
"                except Exception: pass\n"
"        SW = u.GetSystemMetrics(78); SH = u.GetSystemMetrics(79)\n"
"        out = []\n"
"        for c in children:\n"
"            if c[1] in ('SHELLDLL_DefView', 'SysListView32', 'SysHeader32', 'WorkerW', 'Progman'): continue\n"
"            if 'explorer' in names.get(c[2], '?'): continue\n"
"            if not c[3]: continue\n"
"            if (c[6] - c[4]) >= SW * 0.95 and (c[7] - c[5]) >= SH * 0.95: out.append(c)\n"
"        return out\n"
"    except Exception as ex:\n"
"        log('layer probe error ' + repr(ex))\n"
"        return []\n"
"def load_cat():\n"
"    return json.loads(CATALOG.read_text(encoding='utf-8'))\n"
"def load_state():\n"
"    try: return json.loads(STATE.read_text(encoding='utf-8'))\n"
"    except Exception: return {'current': 1, 'auto_on': False, 'interval': 1800}\n"
"def save_state(st):\n"
"    STATE.write_text(json.dumps(st, ensure_ascii=False, indent=2), encoding='utf-8')\n"
"def ensure_lively():\n"
"    if running('Lively.exe'): return True\n"
"    run(['taskkill', '/F', '/IM', 'Livelycu.exe'], timeout=20)\n"
"    try: subprocess.Popen([LIVELY], cwd=str(Path(LIVELY).parent), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n"
"    except Exception as ex:\n"
"        log('start lively error ' + repr(ex)); return False\n"
"    time.sleep(25)\n"
"    return running('Lively.exe')\n"
"def apply(idx, verify=True):\n"
"    cat = load_cat()\n"
"    n = (int(idx) - 1) % len(cat) + 1\n"
"    item = cat[n - 1]\n"
"    f = BASE / item['file']\n"
"    if not f.exists():\n"
"        log('wallpaper file missing: ' + item['file']); return False\n"
"    if not ensure_lively(): return False\n"
"    c, o = run([LIVELY, 'setwp', '--file', str(f), '--monitor', '1'], timeout=30)\n"
"    log('setwp %d (%s) exit %d' % (n, item['slug'], c))\n"
"    time.sleep(10)\n"
"    run([LIVELY, '--play', 'true'], timeout=15)\n"
"    ok = (c == 0) and (not verify or bool(layer_players()))\n"
"    if ok:\n"
"        st = load_state(); st['current'] = n; save_state(st)\n"
"    return ok\n"
"def next_one():\n"
"    st = load_state()\n"
"    return apply(st['current'] % len(load_cat()) + 1)\n"
"def repair_current():\n"
"    return apply(load_state()['current'])\n"
"def auto_running():\n"
"    p = BASE / 'auto.pid'\n"
"    if not p.exists(): return False\n"
"    try: pid = int(p.read_text().strip())\n"
"    except Exception: return False\n"
"    c, o = run(['tasklist', '/FI', 'PID eq %d' % pid], timeout=20)\n"
"    return bool(re.search(r'\\b%d\\b' % pid, o or ''))\n"
"def auto_start():\n"
"    if auto_running(): return True\n"
"    st = load_state(); st['auto_on'] = True; save_state(st)\n"
"    try:\n"
"        subprocess.Popen([sys.executable, str(BASE / 'auto_rotate.py'), '--interval-sec', str(int(st.get('interval', 1800)))], creationflags=0x08000000, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n"
"        log('auto rotation started'); return True\n"
"    except Exception as ex:\n"
"        log('auto start error ' + repr(ex)); return False\n"
"def auto_stop():\n"
"    st = load_state(); st['auto_on'] = False; save_state(st)\n"
"    p = BASE / 'auto.pid'\n"
"    if p.exists():\n"
"        try:\n"
"            pid = int(p.read_text().strip())\n"
"            run(['taskkill', '/F', '/PID', str(pid)], timeout=20)\n"
"        except Exception: pass\n"
"    log('auto rotation stopped')\n"
"def menu():\n"
"    cat = load_cat()\n"
"    while True:\n"
"        st = load_state()\n"
"        print()\n"
"        print('========== 动态壁纸切换器（12款动漫） ==========')\n"
"        for it in cat:\n"
"            mark = '  <-- 当前' if it['idx'] == st['current'] else ''\n"
"            print('  [%2d] %s%s' % (it['idx'], it['cn'], mark))\n"
"        print('------------------------------------------------')\n"
"        print('  [N] 下一张    [A] 开启自动切换（每30分钟）')\n"
"        print('  [S] 停止自动  [R] 修复当前壁纸   [Q] 退出')\n"
"        if st.get('auto_on'): print('  * 自动切换运行中')\n"
"        try: choice = input('请输入选择: ').strip().lower()\n"
"        except Exception: break\n"
"        if choice == 'q': break\n"
"        elif choice == 'n': print('切换中...'); print('结果: ' + ('成功' if next_one() else '失败'))\n"
"        elif choice == 'a': print('已开启' if auto_start() else '开启失败')\n"
"        elif choice == 's': auto_stop(); print('自动切换已停止')\n"
"        elif choice == 'r': print('修复中...'); print('结果: ' + ('成功' if repair_current() else '失败'))\n"
"        elif choice.isdigit() and 1 <= int(choice) <= len(cat):\n"
"            print('切换中...'); print('结果: ' + ('成功' if apply(int(choice)) else '失败'))\n"
"        else: print('无效输入')\n"
"if __name__ == '__main__':\n"
"    args = sys.argv[1:]\n"
"    if not args or args[0] == 'menu': menu()\n"
"    elif args[0] == 'set' and len(args) > 1: sys.exit(0 if apply(int(args[1])) else 1)\n"
"    elif args[0] == 'next': sys.exit(0 if next_one() else 1)\n"
"    elif args[0] == 'repair': sys.exit(0 if repair_current() else 1)\n"
"    elif args[0] == 'status':\n"
"        st = load_state(); print('current=%d auto_on=%s' % (st['current'], st.get('auto_on')))\n"
"    else: print('usage: switcher.py [menu|set N|next|repair|status]')\n")
auto_src=(
"# auto_rotate.py - background rotation loop (started by switcher/keeper)\n"
"import os, sys, time\n"
"from pathlib import Path\n"
"BASE = Path(__file__).resolve().parent\n"
"sys.path.insert(0, str(BASE))\n"
"import switcher\n"
"interval = 1800\n"
"max_sw = 0\n"
"i = 1\n"
"while i < len(sys.argv):\n"
"    a = sys.argv[i]\n"
"    if a == '--interval-sec' and i + 1 < len(sys.argv): interval = int(sys.argv[i + 1]); i += 2\n"
"    elif a == '--max-switches' and i + 1 < len(sys.argv): max_sw = int(sys.argv[i + 1]); i += 2\n"
"    else: i += 1\n"
"pid_file = BASE / 'auto.pid'\n"
"pid_file.write_text(str(os.getpid()), encoding='ascii')\n"
"switcher.log('auto rotate start pid=%d interval=%ds max=%d' % (os.getpid(), interval, max_sw))\n"
"n = 0\n"
"try:\n"
"    while True:\n"
"        time.sleep(interval)\n"
"        ok = switcher.next_one()\n"
"        n += 1\n"
"        switcher.log('auto switch #%d ok=%s' % (n, ok))\n"
"        if max_sw and n >= max_sw: break\n"
"finally:\n"
"    try: pid_file.unlink()\n"
"    except Exception: pass\n"
"    switcher.log('auto rotate exit after %d switches' % n)\n")
keeper_src=(
"# keeper12.py - logon keeper for the 12-pack: restore the current selection,\n"
"# restart auto rotation if it was on. Run hidden from the Startup bat.\n"
"import sys, time\n"
"from pathlib import Path\n"
"BASE = Path(__file__).resolve().parent\n"
"sys.path.insert(0, str(BASE))\n"
"import switcher\n"
"if '--now' not in sys.argv:\n"
"    time.sleep(45)\n"
"switcher.log('keeper12 start')\n"
"ok = switcher.repair_current()\n"
"switcher.log('keeper12 restore ok=%s' % ok)\n"
"st = switcher.load_state()\n"
"if st.get('auto_on') and not switcher.auto_running():\n"
"    switcher.auto_start()\n"
"    switcher.log('keeper12 restarted auto rotation')\n"
"sys.exit(0 if ok else 1)\n")
try:
    WT(PACK/'switcher.py',switcher_src)
    WT(PACK/'auto_rotate.py',auto_src)
    WT(PACK/'keeper12.py',keeper_src)
    L('scripts_installed switcher=%d auto=%d keeper=%d bytes'%(PACK.joinpath('switcher.py').stat().st_size,PACK.joinpath('auto_rotate.py').stat().st_size,PACK.joinpath('keeper12.py').stat().st_size))
except Exception as ex: L('scripts_install_error='+repr(ex))

# ---- 3. menu bat on the REAL desktop + keeper bat update
try:
    bat=('@echo off\r\n'
         'title Dynamic Wallpaper Switcher - 12 Anime\r\n'
         'cd /d "'+str(PACK)+'"\r\n'
         'set "PY="\r\n'
         'where python.exe >nul 2>&1 && set "PY=python"\r\n'
         'if not defined PY where py.exe >nul 2>&1 && set "PY=py -3"\r\n'
         'if not defined PY (\r\n'
         '  echo [ERROR] Python not found - tell the agent.\r\n'
         '  pause\r\n'
         '  exit /b 1\r\n'
         ')\r\n'
         '%PY% switcher.py menu\r\n'
         'echo.\r\n'
         'pause\r\n')
    WA(MENU_BAT,bat)
    L('menu_bat='+str(MENU_BAT)+' exists='+str(MENU_BAT.exists()))
except Exception as ex: L('menu_bat_error='+repr(ex))
try:
    kbat=('@echo off\r\n'
          'rem 12-pack logon keeper - restores the selected wallpaper after reboot\r\n'
          'where pythonw.exe >nul 2>&1 && (start "" pythonw.exe "'+str(PACK/'keeper12.py')+'") || (start "" /min python.exe "'+str(PACK/'keeper12.py')+'")\r\n')
    WA(KEEPER_BAT,kbat)
    L('keeper_bat_updated='+str(KEEPER_BAT.exists()))
except Exception as ex: L('keeper_bat_error='+repr(ex))
try:
    WT(PACK/'PATHS.txt','12 anime dynamic wallpapers switcher (r277)\r\n=============================================\r\npack folder : '+str(PACK)+'\r\ncatalog     : wallpapers.json (12 entries)   state: state.json (current/auto)\r\ndesktop bat : '+str(MENU_BAT)+' (double-click: menu 1-12 / N next / A auto / S stop / R repair)\r\nauto rotate : auto_rotate.py (pythonw hidden, pid in auto.pid, log auto log in switcher.log)\r\nlogon keeper: '+str(KEEPER_BAT)+' -> keeper12.py (restores selection, restarts auto)\r\nlively exe  : '+str(lively)+'\r\n')
    L('paths_txt_ok=True')
except Exception: pass

# ---- 4. TEST: manual switch 1 -> 2 with pixel proof
mini(); time.sleep(1)
def sw(n):
    c,o=run([sys.executable,str(PACK/'switcher.py'),'set',str(n)],timeout=180)
    return c,(o or '').strip()
c1,o1=sw(1); L('switcher_set_1_exit='+str(c1)); time.sleep(6); ok,w,h,e=shot(P1); L(f'p1={P1.name} ok={ok}')
c2,o2=sw(2); L('switcher_set_2_exit='+str(c2)); time.sleep(6); ok,w,h,e=shot(P2); L(f'p2={P2.name} ok={ok}')
pl=wallpaper_players_in_layer(); tmap=tasklist_map()
for c in pl[:4]: L('   wallpaper_player| class='+c[1]+' owner='+tmap.get(c[2],'?'))
d_man=diff(P1,P2)
L('manual_switch_diff_ratio=%.6f'%d_man['ratio'])
manual_switch_proven=bool(c1==0 and c2==0 and len(pl)>0 and d_man.get('ok') and d_man['ratio']>0.05)
L('manual_switch_proven='+str(manual_switch_proven))

# ---- 5. TEST: auto rotation (25s x 2 ticks), then stop
auto_switches=0; auto_test_ok=False
try:
    subprocess.Popen([sys.executable,str(PACK/'auto_rotate.py'),'--interval-sec','25','--max-switches','2'],creationflags=0x08000000,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    start=time.time()
    def read_current():
        try: return json.loads((PACK/'state.json').read_text(encoding='utf-8'))['current']
        except Exception: return -1
    seen=read_current()
    if seen<0: seen=2
    while time.time()-start<110:
        time.sleep(5)
        cur=read_current()
        if cur>0: auto_switches=max(auto_switches,(cur-seen)%12)
        if auto_switches>=2: break
    auto_test_ok=auto_switches>=2
    L('auto_rotation_switches='+str(auto_switches)+' proven='+str(auto_test_ok))
    time.sleep(3); ok,w,h,e=shot(P3); L(f'p3={P3.name} ok={ok}')
except Exception as ex: L('auto_test_error='+repr(ex))
run([sys.executable,str(PACK/'switcher.py'),'status'],timeout=60)
cstop,ostop=run([sys.executable,'-c','import sys;sys.path.insert(0,r"'+str(PACK)+'");import switcher;switcher.auto_stop()'],timeout=60)
L('auto_stop_done')
auto_pid_alive=False
try:
    pf=PACK/'auto.pid'
    if pf.exists():
        pid=int(pf.read_text().strip())
        auto_pid_alive=str(pid) in (run(['tasklist','/FI','PID eq %d'%pid],timeout=20)[1] or '')
    else: auto_pid_alive=False
except Exception: auto_pid_alive=True
L('auto_pid_alive_after_stop='+str(auto_pid_alive))
auto_stopped=auto_test_ok and not auto_pid_alive
L('auto_stopped='+str(auto_stopped))

# ---- 6. TEST: keeper12 --now (restore current), then final wallpaper = 1
ck,ok2=run([sys.executable,str(PACK/'keeper12.py'),'--now'],timeout=180)
L('keeper12_now_exit='+str(ck))
keeper12_tested=(ck==0)
c1b,_=sw(1); L('final_set_1_exit='+str(c1b)); time.sleep(5)
mini(); time.sleep(1); ok,w,h,e=shot(M1); L(f'm1={M1.name} ok={ok}')
time.sleep(40); ok,w,h,e=shot(M2); L(f'm2={M2.name} ok={ok}')
d_fin=diff(M1,M2)
L('final_motion_ratio=%.6f'%d_fin['ratio']); L('final_motion_avg=%.3f'%d_fin['avg'])
motion_final=bool(d_fin.get('ok') and (d_fin['ratio']>0.0005 or d_fin['avg']>0.25))
L('motion_final_proven='+str(motion_final))
pl=wallpaper_players_in_layer(); layer_final=len(pl)>0
L('layer_final='+str(layer_final))

# ---- 7. cleanup: old C:-desktop artifacts + superseded lively-hotori
c_cleanup_done=False
try:
    if C_OLD_BAT.exists(): C_OLD_BAT.unlink(); L('c_old_bat_deleted=True')
    else: L('c_old_bat_not_present=True')
    if DESKBOX.exists():
        others=[f for f in DESKBOX.rglob('*') if f.is_file() and not f.name.startswith('AUTO_TIDY')]
        for f in DESKBOX.glob('AUTO_TIDY*'):
            try: f.unlink()
            except Exception: pass
        if not others:
            try: DESKBOX.rmdir(); L('deskbox_folder_removed=True')
            except Exception: L('deskbox_folder_busy=True')
        else: L('deskbox_other_files_kept=%d'%len(others))
    else: L('deskbox_not_present=True')
    c_cleanup_done=not C_OLD_BAT.exists()
except Exception as ex: L('cleanup_error='+repr(ex))
L('c_cleanup_done='+str(c_cleanup_done))
old_folder_left=True
try:
    if OLD_PERM.exists():
        shutil.rmtree(OLD_PERM,ignore_errors=True)
        old_folder_left=OLD_PERM.exists()
        L('old_lively_hotori_folder_removed='+str(not old_folder_left))
except Exception as ex: L('old_folder_cleanup_error='+repr(ex))

ready=bool(pack_count==12 and valid==12 and MENU_BAT.exists() and KEEPER_BAT.exists() and manual_switch_proven and auto_test_ok and auto_stopped and keeper12_tested and layer_final and motion_final and c_cleanup_done and not locked)
L('switcher_12pack_ready='+str(ready))
L('LIVELY_SWITCHER_12PACK_READY='+str(ready))

# ---- 8. receipts
summary={'ready':ready,'locked':locked,'packDir':str(PACK),'packCount':pack_count,'validFiles':valid,'catalog':[{'idx':e['idx'],'slug':e['slug'],'cn':e['cn'],'file':e['file'],'bytes':(PACK/e['file']).stat().st_size if (PACK/e['file']).exists() else 0} for e in catalog],'desktopDir':str(DESK_DIR),'menuBat':str(MENU_BAT),'keeperBat':str(KEEPER_BAT),'manualSwitchProven':manual_switch_proven,'manualDiffRatio':d_man.get('ratio'),'autoSwitches':auto_switches,'autoStopped':auto_stopped,'keeper12Tested':keeper12_tested,'motionFinalRatio':d_fin.get('ratio'),'layerFinal':layer_final,'cCleanupDone':c_cleanup_done,'oldFolderLeft':old_folder_left,'livelyExe':lively}
WT(J,json.dumps(summary,ensure_ascii=False,indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
