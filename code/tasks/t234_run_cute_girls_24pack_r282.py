# t234_cute_girls_24pack_r282.py - round 282.
# User request: replace the male-character wallpapers with CUTE GIRL ones,
# grow the pack to 24, auto-switch with multiple interval choices (15s!)
# and let the user pick WHICH wallpapers join the auto rotation (pool).
# Plan:
#   keep 6: hotori, evening-window-view, midnight-sakura-train-station,
#           peaceful-anime-tree-swing, autumn-spirit-dance,
#           butterfly-bloom-sword-spirit-forest
#   delete 6 males: gojo-satoru-train, tanjiro-kamado-crimson-moon,
#           itachi-uchiha-crimson-shadows, zoro-king-of-hell,
#           ultra-instinct-goku, luffy-before-the-storm
#   download 18 cute-girl wallpapers (IWR fast path first, page-extract and
#           curl/certutil fallbacks, 20-minute self budget, resumable via
#           _fresh-*.mp4 reuse)
#   switcher.py v2: 24 entries, [T] interval menu (15s..1h+custom),
#           [P] rotation pool picker (e.g. "1,3,5-8", empty = all)
#   auto_rotate.py v2: live-reads state (interval/pool/auto_on) each tick,
#           exits itself when auto is off
#   live tests: switch 1->7 pixel diff, pool rotation [1,7] at 15s,
#           motion probe. keeper12.py stays as-is (API compatible).
import ctypes, os, sys, time, subprocess, json, struct, re, hashlib, shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R282_CUTE_GIRLS_24PACK.md'; J=OUT/'r282-cute-girls-24pack.json'
PA=OUT/'r282_pa_wallpaper1.bmp'; PB=OUT/'r282_pb_wallpaper7.bmp'
M1=OUT/'r282_m1_final.bmp'; M2=OUT/'r282_m2_final.bmp'
WALLROOT=Path(r'E:\0mcp-agv-arena-optimized\wallpapers'); PACK=WALLROOT/'lively-12'
LIVELY_CANDIDATES=[r'C:\Program Files\Lively Wallpaper\Lively.exe',r'C:\Program Files (x86)\Lively Wallpaper\Lively.exe',str(Path(os.environ.get('LOCALAPPDATA',r'C:\Users\Public'))/'Programs'/'Lively Wallpaper'/'Lively.exe')]
UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'
PAGE='https://livelywallpaper.app/live-wallpapers/%s/'
CDN_PATTERNS=['https://cdn.livelywallpaper.app/wallpapers/%s/hd.mp4','https://cdn.livelywallpaper.app/wallpapers/%s/preview.mp4']
KEEP=[('hotori','Hotori（原壁纸）'),
('evening-window-view','夕阳窗边的黑猫'),
('midnight-sakura-train-station','午夜樱花车站'),
('peaceful-anime-tree-swing-live-wallpaper','云端树秋千'),
('autumn-spirit-dance','枫叶精灵起舞'),
('butterfly-bloom-sword-spirit-forest','蝶舞剑灵之森')]
MALES={'gojo-satoru-train','tanjiro-kamado-crimson-moon','itachi-uchiha-crimson-shadows','zoro-king-of-hell','ultra-instinct-goku','luffy-before-the-storm'}
NEW=[('ryuuge-kisaki-blue-archive','戒戒·金鱼梦中'),
('mahiru-shiina-in-a-flower-field','真昼·金色花田'),
('mahiru-shiina-summer-sky','真昼·夏日晴空'),
('furina-on-the-throne-genshin-impact','芙宁娜·水中神座'),
('elaina-witch-of-the-roads','伊蕾娜·雪中森林'),
('elaina-reading-magic-book-wandering-witch','伊蕾娜·魔导书'),
('nier-automata-2b-forest-ruins','2B·废墟森林'),
('at-girl-on-a-mountain-lake','猫耳少女·山间湖畔'),
('pink-blossom','樱花与相机少女'),
('cozy-reading-girl','窗边读书的少女'),
('pure-soul','水中白银少女'),
('neon-gaze-mysterious-anime-girl','霓虹凝视·少女'),
('phoebe-cozy-bedroom','菲比·温馨卧室'),
('phoebe-wuthering-waves','菲比·鸣潮旷野'),
('winter-wanderer-xayah','雪之行者·霞'),
('anime-girl-sword-reflection','剑刃倒影少女'),
('crimson-anime-eyes','绯红眼瞳少女'),
('violet-evergarden-chinese','薇尔莉特·水墨')]
FALLBACK=[('cyber-slayer-schoolgirl-pink-anime-power','粉刃JK少女'),
('monochrome-anime-eyes-reflection','黑白镜像少女'),
('koyomi-shirato-anemoi','风之白羽少女'),
('houshou-marine-the-pirate-captain-s-secret-chamber','船长的密室'),
('zero-two-x-toyota-gr-86','零二·GR86'),
('the-midnight-duo-evo-vi','午夜车手少女'),
('honda-civic-ek-anime-drift','车头少女·Civic'),
('blood-bride','白裙新娘·余烬'),
('exusiai-the-new-covenant-arknights-lute','能天使·琴声'),
('beautiful-anime-girl-under-starry-sky','流星夜空下的少女')]
LOCAL_FILL=[(WALLROOT/'anime-girl-meteor-r254'/'anime_girl_beneath_meteor_sky_existing_r254.mp4','meteor-girl','流星夜空下的少女（本机）'),
(WALLROOT/'mahiru-golden-r255'/'golden_afternoon_mahiru_shiina_existing_r255.mp4','mahiru-local','真昼·午后（本机）')]
DESK_FALLBACK=Path(os.environ.get('USERPROFILE',r'C:\Users\Public'))/'Desktop'
BUDGET_SEC=1080
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
def is_mp4(p,min_size=400000):
    try:
        q=Path(p); return q.is_file() and q.stat().st_size>=min_size and b'ftyp' in q.read_bytes()[:16]
    except Exception: return False
def sha(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for blk in iter(lambda:f.read(1<<20),b''): h.update(blk)
    return h.hexdigest()
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

L('# R282 cute-girls 24-pack + interval/pool auto switching')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
t0=time.time()
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
lively=''
for c in LIVELY_CANDIDATES:
    if Path(c).exists(): lively=c; break
L('lively_exe='+str(lively))

# ---- 1. scan disk: keep files + reusable _fresh files
found={}
for f in sorted(PACK.glob('*.mp4')):
    if not is_mp4(f,300000): continue
    for slug,cn in KEEP:
        if slug in f.name.lower() and slug not in found: found[slug]=f; break
males_present=[s for s in MALES if any(s in f.name.lower() for f in PACK.glob('*.mp4'))]
L('keep_found=%d/6 males_on_disk=%s'%(len(found),males_present))
for f in sorted(PACK.glob('_fresh-*.mp4')):
    if is_mp4(f,300000):
        slug=f.stem[len('_fresh-'):]
        if slug not in found: found[slug]=f; L('reuse_fresh %s'%slug)

# ---- 2. download the cute girls (budgeted, resumable)
def iwr(url,dest,timeout_sec=240):
    c,o=run(['powershell','-NoProfile','-Command',"try{Invoke-WebRequest -Uri '"+url+"' -OutFile '"+str(dest)+"' -UserAgent '"+UA+"' -TimeoutSec "+str(timeout_sec)+" -UseBasicParsing;$?}catch{''}"],timeout=timeout_sec+30)
    return is_mp4(dest)
def page_mp4_urls(slug):
    c,o=run(['powershell','-NoProfile','-Command',"try{(Invoke-WebRequest -Uri '"+(PAGE%slug)+"' -UserAgent '"+UA+"' -UseBasicParsing -TimeoutSec 60).Content}catch{''}"],timeout=90)
    urls=re.findall(r'https://cdn\.livelywallpaper\.app[^\"\'\s<>]+\.mp4',(o or ''))
    out=[]
    for u in urls:
        if u not in out: out.append(u)
    return out
def grab(slug):
    dest=PACK/('_fresh-%s.mp4'%slug)
    if is_mp4(dest): return 'reused'
    for pat in CDN_PATTERNS:
        if iwr(pat%slug,dest): return 'iwr'
    for u in page_mp4_urls(slug):
        if 'preview' in u: continue
        if iwr(u,dest): return 'iwr(page)'
    c,o=run(['curl.exe','-sS','-L','--max-time','120','-A',UA,'-o',str(dest),CDN_PATTERNS[0]%slug],timeout=140)
    if c==0 and is_mp4(dest): return 'curl'
    c,o=run(['certutil','-urlcache','-split','-f',CDN_PATTERNS[0]%slug,str(dest)],timeout=140)
    if is_mp4(dest): return 'certutil'
    try: dest.unlink()
    except Exception: pass
    return ''
new_entries=[]; seen_hashes={sha(v) for v in found.values()}
for slug,cn in NEW+FALLBACK:
    if len(new_entries)>=18: break
    if slug in found: continue
    if time.time()-t0>BUDGET_SEC:
        L('budget_reached stop downloading'); break
    m=grab(slug)
    if m and sha(PACK/('_fresh-%s.mp4'%slug)) not in seen_hashes:
        new_entries.append({'slug':slug,'cn':cn,'path':PACK/('_fresh-%s.mp4'%slug)})
        seen_hashes.add(sha(new_entries[-1]['path']))
        L('download %-44s OK via %s (%d KB)'%(slug,m,new_entries[-1]['path'].stat().st_size//1024))
    elif m:
        L('download %-44s DUPLICATE skip'%slug)
        try: (PACK/('_fresh-%s.mp4'%slug)).unlink()
        except Exception: pass
    else:
        L('download %-44s FAIL'%slug)
L('new_cute_downloads=%d'%len(new_entries))
if len(new_entries)<18:
    for src,slug,cn in LOCAL_FILL:
        if len(new_entries)>=18: break
        if slug in found or not is_mp4(src,300000): continue
        tgt=PACK/('_fresh-%s.mp4'%slug)
        if not tgt.exists(): shutil.copy2(src,tgt)
        if sha(tgt) not in seen_hashes:
            new_entries.append({'slug':slug,'cn':cn,'path':tgt}); seen_hashes.add(sha(tgt))
            L('local_fill %s'%slug)

# ---- 3. rebuild: 6 keep + 18 new = 24, two-phase rename
final=[]
for slug,cn in KEEP:
    if slug in found: final.append({'slug':slug,'cn':cn,'path':found[slug]})
for e in new_entries: final.append(e)
L('final_entries=%d (target 24)'%len(final))
tmp_moves=[]
for i,e in enumerate(final,1):
    tmp=PACK/('_tmp-%02d.mp4'%i)
    try:
        if tmp.exists(): tmp.unlink()
        e['path'].rename(tmp); tmp_moves.append((i,e['slug'],e['cn'],tmp))
    except Exception as ex: L('tmp_move_error %s %r'%(e['slug'],ex))
catalog=[]; valid=0
for i,slug,cn,tmp in tmp_moves:
    target=PACK/('%02d-%s.mp4'%(i,slug))
    try:
        if target.exists(): target.unlink()
        tmp.rename(target)
        okf=is_mp4(target,300000)
        catalog.append({'idx':i,'slug':slug,'name':slug,'cn':cn,'file':target.name,'valid':bool(okf)})
        if okf: valid+=1
        L('   cat %02d %-44s %s %dKB'%(i,slug,'OK' if okf else 'INVALID',target.stat().st_size//1024))
    except Exception as ex: L('final_move_error %s %r'%(slug,ex))
keep={e['file'] for e in catalog}
for f in list(PACK.glob('_tmp-*.mp4'))+list(PACK.glob('_fresh-*.mp4'))+list(PACK.glob('*.mp4')):
    if f.name not in keep:
        try: f.unlink()
        except Exception: pass
distinct=len({sha(PACK/e['file']) for e in catalog if e['valid']})
males_left=[f.name for f in PACK.glob('*.mp4') if any(m in f.name.lower() for m in MALES)]
L('catalog=%d valid=%d distinct=%d males_left=%s'%(len(catalog),valid,distinct,males_left))

# ---- 4. switcher v2 + auto_rotate v2
switcher_src=(
"# switcher.py v2 - 24 cute anime wallpapers: manual + auto (interval + pool)\n"
"import ctypes, json, os, re, subprocess, sys, time\n"
"from pathlib import Path\n"
"BASE = Path(__file__).resolve().parent\n"
"CATALOG = BASE / 'wallpapers.json'\n"
"STATE = BASE / 'state.json'\n"
"LOG = BASE / 'switcher.log'\n"
"LIVELY = r'C:\\Program Files\\Lively Wallpaper\\Lively.exe'\n"
"INTERVALS = [(15,'15 秒'),(30,'30 秒'),(60,'1 分钟'),(300,'5 分钟'),(1800,'30 分钟'),(3600,'1 小时')]\n"
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
"    except Exception: return {'current': 1, 'auto_on': False, 'interval': 1800, 'pool': []}\n"
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
"def pool_list():\n"
"    st = load_state()\n"
"    pool = st.get('pool') or []\n"
"    if pool: return [p for p in pool if 1 <= p <= len(load_cat())]\n"
"    return list(range(1, len(load_cat()) + 1))\n"
"def next_one():\n"
"    pool = pool_list()\n"
"    cur = load_state()['current']\n"
"    if cur in pool:\n"
"        nxt = pool[(pool.index(cur) + 1) % len(pool)]\n"
"    else:\n"
"        nxt = pool[0]\n"
"    return apply(nxt)\n"
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
"        subprocess.Popen([sys.executable, str(BASE / 'auto_rotate.py')], creationflags=0x08000000, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n"
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
"def parse_pool(text, n):\n"
"    nums = set()\n"
"    for part in re.split(r'[,\\s]+', text.strip()):\n"
"        if not part: continue\n"
"        m = re.match(r'^(\\d+)-(\\d+)$', part)\n"
"        if m:\n"
"            a, b = int(m.group(1)), int(m.group(2))\n"
"            for k in range(min(a, b), max(a, b) + 1):\n"
"                if 1 <= k <= n: nums.add(k)\n"
"        elif part.isdigit() and 1 <= int(part) <= n:\n"
"            nums.add(int(part))\n"
"    return sorted(nums)\n"
"def interval_label(v):\n"
"    return dict(INTERVALS).get(int(v), str(v) + ' 秒')\n"
"def menu():\n"
"    while True:\n"
"        cat = load_cat(); st = load_state()\n"
"        pool = st.get('pool') or []\n"
"        print()\n"
"        print('======== 动态壁纸切换器（%d 款动漫少女） ========' % len(cat))\n"
"        for it in cat:\n"
"            mark = '  <-- 当前' if it['idx'] == st['current'] else ''\n"
"            pool_mark = ' *' if pool and it['idx'] in pool else ''\n"
"            print('  [%2d] %s%s%s' % (it['idx'], it['cn'], pool_mark, mark))\n"
"        print('--------------------------------------------------')\n"
"        print('  [N] 下一张  [A] 开启自动  [S] 停止自动  [R] 修复')\n"
"        print('  [P] 选择轮换款  [T] 切换间隔  [Q] 退出')\n"
"        if st.get('auto_on'):\n"
"            print('  * 自动运行中 | 间隔 %s | 轮换 %s' % (interval_label(st.get('interval', 1800)), ('全部' if not pool else ','.join(str(x) for x in pool))))\n"
"        try: choice = input('请输入选择: ').strip().lower()\n"
"        except Exception: break\n"
"        if choice == 'q': break\n"
"        elif choice == 'n': print('切换中...'); print('结果: ' + ('成功' if next_one() else '失败'))\n"
"        elif choice == 'a': print('已开启' if auto_start() else '开启失败')\n"
"        elif choice == 's': auto_stop(); print('自动切换已停止')\n"
"        elif choice == 'r': print('修复中...'); print('结果: ' + ('成功' if repair_current() else '失败'))\n"
"        elif choice == 'p':\n"
"            try: text = input('输入轮换编号（如 1,3,5-8，直接回车=全部）: ').strip()\n"
"            except Exception: text = ''\n"
"            st2 = load_state(); st2['pool'] = parse_pool(text, len(cat)) if text else []; save_state(st2)\n"
"            print('轮换款已设为: ' + ('全部' if not st2['pool'] else ','.join(str(x) for x in st2['pool'])))\n"
"        elif choice == 't':\n"
"            print('  间隔选择: ' + '  '.join('%d) %s' % (i + 1, lab) for i, (v, lab) in enumerate(INTERVALS)) + '  7) 自定义秒数')\n"
"            try: tch = input('选择 1-7: ').strip()\n"
"            except Exception: tch = ''\n"
"            st2 = load_state()\n"
"            if tch.isdigit() and 1 <= int(tch) <= 6:\n"
"                st2['interval'] = INTERVALS[int(tch) - 1][0]; save_state(st2)\n"
"                print('间隔已设为 ' + interval_label(st2['interval']))\n"
"            elif tch == '7':\n"
"                try: v = int(input('输入秒数 (>=5): ').strip())\n"
"                except Exception: v = 0\n"
"                if v >= 5:\n"
"                    st2['interval'] = v; save_state(st2)\n"
"                    print('间隔已设为 %d 秒' % v)\n"
"                else: print('无效秒数')\n"
"            else: print('无效输入')\n"
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
"        st = load_state()\n"
"        print('current=%d auto_on=%s interval=%s pool=%s' % (st['current'], st.get('auto_on'), st.get('interval', 1800), ','.join(str(x) for x in (st.get('pool') or [])) or 'all'))\n"
"    else: print('usage: switcher.py [menu|set N|next|repair|status]')\n")
auto_src=(
"# auto_rotate.py v2 - live-config rotation loop (interval/pool/auto_on from state.json)\n"
"import os, sys, time\n"
"from pathlib import Path\n"
"BASE = Path(__file__).resolve().parent\n"
"sys.path.insert(0, str(BASE))\n"
"import switcher\n"
"pid_file = BASE / 'auto.pid'\n"
"pid_file.write_text(str(os.getpid()), encoding='ascii')\n"
"switcher.log('auto start pid=%d' % os.getpid())\n"
"try:\n"
"    while True:\n"
"        st = switcher.load_state()\n"
"        if not st.get('auto_on'):\n"
"            switcher.log('auto off, exiting'); break\n"
"        time.sleep(max(5, int(st.get('interval', 1800))))\n"
"        st = switcher.load_state()\n"
"        if not st.get('auto_on'):\n"
"            switcher.log('auto off while waiting, exiting'); break\n"
"        ok = switcher.next_one()\n"
"        switcher.log('auto switch -> %d ok=%s' % (switcher.load_state()['current'], ok))\n"
"finally:\n"
"    try: pid_file.unlink()\n"
"    except Exception: pass\n"
"    switcher.log('auto rotate exit')\n")
try:
    WT(PACK/'switcher.py',switcher_src)
    WT(PACK/'auto_rotate.py',auto_src)
    L('scripts_v2_installed switcher=%d auto=%d bytes'%(PACK.joinpath('switcher.py').stat().st_size,PACK.joinpath('auto_rotate.py').stat().st_size))
except Exception as ex: L('scripts_v2_error='+repr(ex))
scripts_ok=bool(PACK.joinpath('switcher.py').exists() and PACK.joinpath('switcher.py').stat().st_size>6000 and PACK.joinpath('auto_rotate.py').exists() and PACK.joinpath('keeper12.py').exists())
WT(PACK/'wallpapers.json',json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
WT(PACK/'state.json',json.dumps({'current':1,'auto_on':False,'interval':1800,'pool':[]},ensure_ascii=False,indent=2)+'\n')
try:
    WT(PACK/'PATHS.txt','24 cute anime wallpapers switcher v2 (r282)\r\n==========================================\r\npack folder : '+str(PACK)+'\r\nmenu        : desktop bat -> [1-24] pick, N next, A auto on, S auto off,\r\n              P pick rotation pool (e.g. 1,3,5-8; empty = all),\r\n              T interval (15s/30s/1m/5m/30m/1h/custom), R repair\r\nstate file  : state.json (current/auto_on/interval/pool)\r\nlogon keeper: Startup keeper bat -> keeper12.py (restores selection, restarts auto)\r\n')
    L('paths_txt_ok=True')
except Exception: pass

# ---- 5. tests
def sw(n):
    c,o=run([sys.executable,str(PACK/'switcher.py'),'set',str(n)],timeout=180)
    return c
mini(); time.sleep(1)
ca=sw(1); L('switch_1_exit='+str(ca)); time.sleep(6); ok,w,h,e=shot(PA); L(f'pa ok={ok}')
cb=sw(7); L('switch_7_exit='+str(cb)); time.sleep(6); ok,w,h,e=shot(PB); L(f'pb ok={ok}')
pl=wallpaper_players_in_layer(); tmap=tasklist_map()
for c in pl[:4]: L('   wallpaper_player| class='+c[1]+' owner='+tmap.get(c[2],'?'))
d_sw=diff(PA,PB)
L('switch_diff_ratio=%.6f'%d_sw['ratio'])
switch_proven=bool(ca==0 and cb==0 and len(pl)>0 and d_sw.get('ok') and d_sw['ratio']>0.05)
L('switch_proven='+str(switch_proven))
pool_ok=False; interval_ok=False; seen_values=set(); switches=0
try:
    WT(PACK/'state.json',json.dumps({'current':1,'auto_on':True,'interval':15,'pool':[1,7]},ensure_ascii=False,indent=2)+'\n')
    subprocess.Popen([sys.executable,str(PACK/'auto_rotate.py')],creationflags=0x08000000,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    start=time.time(); prev=1
    while time.time()-start<80:
        time.sleep(4)
        try: cur=json.loads((PACK/'state.json').read_text(encoding='utf-8'))['current']
        except Exception: continue
        seen_values.add(cur)
        if cur!=prev: switches+=1; prev=cur
        if switches>=3: break
    pool_ok=bool(seen_values) and seen_values.issubset({1,7}) and 1 in seen_values and 7 in seen_values
    interval_ok=switches>=3
    L('pool_test switches=%d seen=%s subset_ok=%s'%(switches,sorted(seen_values),pool_ok))
    L('interval_15s_proven=%s'%interval_ok)
    st=json.loads((PACK/'state.json').read_text(encoding='utf-8')); st['auto_on']=False
    WT(PACK/'state.json',json.dumps(st,ensure_ascii=False,indent=2)+'\n')
    time.sleep(6)
    auto_pid_gone=not (PACK/'auto.pid').exists()
    L('auto_self_exit_pid_gone='+str(auto_pid_gone))
except Exception as ex: L('pool_test_error='+repr(ex))
cf=sw(1); L('final_switch_1_exit='+str(cf)); time.sleep(5)
mini(); time.sleep(1); ok,w,h,e=shot(M1); L(f'm1 ok={ok}')
time.sleep(40); ok,w,h,e=shot(M2); L(f'm2 ok={ok}')
d_m=diff(M1,M2)
L('final_motion_ratio=%.6f'%d_m['ratio']); L('final_motion_avg=%.3f'%d_m['avg'])
motion_final=bool(d_m.get('ok') and (d_m['ratio']>0.0005 or d_m['avg']>0.25))
L('motion_final_proven='+str(motion_final))
layer_final=len(wallpaper_players_in_layer())>0
L('layer_final='+str(layer_final))

ready=bool(valid==24 and distinct==24 and len(catalog)==24 and not males_left and len(new_entries)>=16 and scripts_ok and switch_proven and pool_ok and interval_ok and motion_final and layer_final and not locked)
L('CUTE_GIRLS_24PACK_READY='+str(ready))
summary={'ready':ready,'locked':locked,'valid':valid,'distinct':distinct,'catalogSize':len(catalog),'newCuteDownloads':len(new_entries),'malesLeft':males_left,'scriptsOk':scripts_ok,'switchProven':switch_proven,'switchDiffRatio':d_sw.get('ratio'),'poolTestOk':pool_ok,'interval15Proven':interval_ok,'motionFinalRatio':d_m.get('ratio'),'layerFinal':layer_final,'catalog':[{'idx':e['idx'],'slug':e['slug'],'cn':e['cn'],'file':e['file']} for e in catalog]}
WT(J,json.dumps(summary,ensure_ascii=False,indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
