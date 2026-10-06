# t233_wallpaper_rebuild_safe_r281.py - round 281.
# r279 crashed mid-rename (KeyError) leaving files renamed but json stale;
# r280 then unlinked the renamed files while trying to rename from the stale
# names -> the six r278 CDN wallpapers were accidentally deleted.
# Current disk (expected): 01-hotori + 08..12 (zoro/goku/luffy/autumn/
# butterfly). This round rebuilds SAFELY, trusting the DISK not the json:
#   1. scan PACK/*.mp4, match each file to a known slug by filename
#   2. download the 6 missing slugs (proven chain: page-extract + IWR,
#      curl/certutil fallbacks)
#   3. TWO-PHASE rebuild: first move every source to a unique _tmp name,
#      then _tmp -> final NN-slug names (collisions impossible)
#   4. rewrite wallpapers.json + state.json, delete junk
#   5. live test: switch 1 -> 2 pixel diff, back to 1, motion probe
import ctypes, os, sys, time, subprocess, json, struct, re, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R281_WALLPAPER_SAFE_REBUILD.md'; J=OUT/'r281-wallpaper-safe-rebuild.json'
PA=OUT/'r281_pa_wallpaper1.bmp'; PB=OUT/'r281_pb_wallpaper2.bmp'
M1=OUT/'r281_m1_final.bmp'; M2=OUT/'r281_m2_final.bmp'
WALLROOT=Path(r'E:\0mcp-agv-arena-optimized\wallpapers'); PACK=WALLROOT/'lively-12'
LIVELY_CANDIDATES=[r'C:\Program Files\Lively Wallpaper\Lively.exe',r'C:\Program Files (x86)\Lively Wallpaper\Lively.exe',str(Path(os.environ.get('LOCALAPPDATA',r'C:\Users\Public'))/'Programs'/'Lively Wallpaper'/'Lively.exe')]
UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'
PAGE='https://livelywallpaper.app/live-wallpapers/%s/'
CDN_PATTERNS=['https://cdn.livelywallpaper.app/wallpapers/%s/hd.mp4','https://cdn.livelywallpaper.app/wallpapers/%s/preview.mp4']
PLAN=[('hotori','Hotori（原壁纸）'),
('evening-window-view','夕阳窗边的黑猫'),
('midnight-sakura-train-station','午夜樱花车站'),
('peaceful-anime-tree-swing-live-wallpaper','云端树秋千'),
('gojo-satoru-train','五条悟·霓虹列车'),
('tanjiro-kamado-crimson-moon','炭治郎·红月'),
('itachi-uchiha-crimson-shadows','鼬·绯红暗影'),
('zoro-king-of-hell','索隆·阎魔之王'),
('ultra-instinct-goku','悟空·自在极意功'),
('luffy-before-the-storm','路飞·风暴前夕'),
('autumn-spirit-dance','枫叶精灵起舞'),
('butterfly-bloom-sword-spirit-forest','蝶舞剑灵之森')]
HOTORI_SOURCES=[WALLROOT/'lively-dynamic-r274'/'hotori_dynamic_wallpaper_r274.mp4',WALLROOT/'lively-dynamic-r273'/'hotori_dynamic_wallpaper_r273.mp4']
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

L('# R281 safe rebuild of the 12-pack (disk-trusting, two-phase rename)')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
lively=''
for c in LIVELY_CANDIDATES:
    if Path(c).exists(): lively=c; break
L('lively_exe='+str(lively))

# ---- 1. scan the disk, match files to planned slugs by filename
found={}
for f in sorted(PACK.glob('*.mp4')):
    if not is_mp4(f,300000): continue
    for slug,cn in PLAN:
        if slug in f.name.lower() and slug not in found:
            found[slug]=f; break
L('disk_scan_found=%d/%d'%(len(found),len(PLAN)))
for slug,cn in PLAN:
    L('   %s| %s'%(('found  '+slug) if slug in found else ('missing '+slug),found[slug].name if slug in found else ''))
if 'hotori' not in found:
    for src in HOTORI_SOURCES:
        if is_mp4(src,300000):
            shutil_target=PACK/'_fresh-hotori.mp4'
            import shutil; shutil.copy2(src,shutil_target); found['hotori']=shutil_target
            L('hotori_restored_from='+str(src)); break

# ---- 2. download the missing slugs
def page_mp4_urls(slug):
    c,o=run(['powershell','-NoProfile','-Command',"try{(Invoke-WebRequest -Uri '"+(PAGE%slug)+"' -UserAgent '"+UA+"' -UseBasicParsing -TimeoutSec 60).Content}catch{''}"],timeout=90)
    urls=re.findall(r'https://cdn\.livelywallpaper\.app[^\"\'\s<>]+\.mp4',(o or ''))
    out=[]
    for u in urls:
        if u not in out: out.append(u)
    return out
def try_url(url,dest):
    c,o=run(['powershell','-NoProfile','-Command',"try{Invoke-WebRequest -Uri '"+url+"' -OutFile '"+str(dest)+"' -UserAgent '"+UA+"' -TimeoutSec 240 -UseBasicParsing;$?}catch{''}"],timeout=260)
    if is_mp4(dest): return 'iwr'
    c,o=run(['curl.exe','-sS','-L','--max-time','180','-A',UA,'-o',str(dest),url],timeout=200)
    if c==0 and is_mp4(dest): return 'curl'
    c,o=run(['certutil','-urlcache','-split','-f',url,str(dest)],timeout=200)
    if is_mp4(dest): return 'certutil'
    try: dest.unlink()
    except Exception: pass
    return ''
downloads=0
for slug,cn in PLAN:
    if slug in found: continue
    dest=PACK/('_fresh-%s.mp4'%slug)
    got=''
    for u in page_mp4_urls(slug):
        if 'preview' in u: continue
        got=try_url(u,dest)
        if got: break
    if not got:
        for pat in CDN_PATTERNS:
            got=try_url(pat%slug,dest)
            if got: break
    if got:
        found[slug]=dest; downloads+=1
        L('download %-44s OK via %s (%d KB)'%(slug,got,dest.stat().st_size//1024))
    else:
        L('download %-44s FAIL'%slug)
L('redownloaded=%d now_have=%d/%d'%(downloads,len(found),len(PLAN)))

# ---- 3. two-phase rebuild (sources -> _tmp -> final; no collisions possible)
tmp_moves=[]
for i,(slug,cn) in enumerate(PLAN,1):
    src=found.get(slug)
    if src is None: continue
    tmp=PACK/('_tmp-%02d.mp4'%i)
    try:
        if tmp.exists(): tmp.unlink()
        src.rename(tmp); tmp_moves.append((i,slug,cn,tmp))
    except Exception as ex: L('tmp_move_error %s %r'%(slug,ex))
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
for f in list(PACK.glob('_tmp-*.mp4'))+list(PACK.glob('_fresh-*.mp4'))+list(PACK.glob('*.mp4')):
    if f.name not in {e['file'] for e in catalog}:
        try: f.unlink()
        except Exception: pass
distinct=len({sha(PACK/e['file']) for e in catalog if e['valid']})
WT(PACK/'wallpapers.json',json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
WT(PACK/'state.json',json.dumps({'current':1,'auto_on':False,'interval':1800},ensure_ascii=False,indent=2)+'\n')
L('catalog_size=%d valid=%d distinct=%d'%(len(catalog),valid,distinct))

# ---- 4. live test
def sw(n):
    c,o=run([sys.executable,str(PACK/'switcher.py'),'set',str(n)],timeout=180)
    return c
mini(); time.sleep(1)
ca=sw(1); L('switch_1_exit='+str(ca)); time.sleep(6); ok,w,h,e=shot(PA); L(f'pa ok={ok}')
cb=sw(2); L('switch_2_exit='+str(cb)); time.sleep(6); ok,w,h,e=shot(PB); L(f'pb ok={ok}')
pl=wallpaper_players_in_layer(); tmap=tasklist_map()
for c in pl[:4]: L('   wallpaper_player| class='+c[1]+' owner='+tmap.get(c[2],'?'))
d_sw=diff(PA,PB)
L('switch_diff_ratio=%.6f'%d_sw['ratio'])
switch_proven=bool(ca==0 and cb==0 and len(pl)>0 and d_sw.get('ok') and d_sw['ratio']>0.05)
L('switch_proven='+str(switch_proven))
cf=sw(1); L('final_switch_1_exit='+str(cf)); time.sleep(5)
mini(); time.sleep(1); ok,w,h,e=shot(M1); L(f'm1 ok={ok}')
time.sleep(40); ok,w,h,e=shot(M2); L(f'm2 ok={ok}')
d_m=diff(M1,M2)
L('final_motion_ratio=%.6f'%d_m['ratio']); L('final_motion_avg=%.3f'%d_m['avg'])
motion_final=bool(d_m.get('ok') and (d_m['ratio']>0.0005 or d_m['avg']>0.25))
L('motion_final_proven='+str(motion_final))
layer_final=len(wallpaper_players_in_layer())>0
L('layer_final='+str(layer_final))

ready=bool(valid==12 and distinct==12 and len(catalog)==12 and switch_proven and motion_final and layer_final and not locked)
L('WALLPAPER_SAFE_REBUILD_READY='+str(ready))
summary={'ready':ready,'locked':locked,'valid':valid,'distinct':distinct,'redownloaded':downloads,'catalog':[{'idx':e['idx'],'slug':e['slug'],'cn':e['cn'],'file':e['file']} for e in catalog],'switchProven':switch_proven,'switchDiffRatio':d_sw.get('ratio'),'motionFinalRatio':d_m.get('ratio'),'layerFinal':layer_final}
WT(J,json.dumps(summary,ensure_ascii=False,indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
