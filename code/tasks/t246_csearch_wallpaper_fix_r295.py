# t246_csearch_wallpaper_fix_r295.py - round 295.
# Follow-up to the r294 data audit. Three urgent jobs, all read-only except
# the wallpaper repair:
#  1. WALLPAPER LAYER REPAIR (hard): r294's plain Lively restart left mpv
#     running but NOT embedded under WorkerW. This round tries the proven
#     keeper12 guard script from the wallpaper pack, then a direct Lively
#     restart with a longer guarded poll.
#  2. C:\ keyword search for the missing library data (r294 only searched
#     D:\ and E:\; the old DeskBox app may relocate files into user-profile
#     paths on C:).
#  3. Old DeskBox remnants: scheduled tasks mentioning tidy/deskbox, the
#     app folder listing, running processes, and quark-cloud-drive listing.
# Boxes stay untouched. Nothing is deleted anywhere.
import ctypes, os, sys, time, subprocess, json, threading
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R295_CSEARCH_WALLPAPER.md'; J=OUT/'r295-csearch-wallpaper.json'
DBOX_DIR=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
L12=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\lively-12')
APPS_DESKBOX=Path(r'E:\0mcp-agv-arena-optimized\apps\DeskBox')
LIVELY_CANDIDATES=[r'C:\Program Files\Lively Wallpaper\Lively.exe',r'C:\Program Files (x86)\Lively Wallpaper\Lively.exe']
lines=[]
def L(s):
    s=str(s).encode('ascii','replace').decode('ascii'); print(s,flush=True); lines.append(s)
def WT(p,t): Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(t,encoding='utf-8')
def run(args,timeout=25):
    try:
        p=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout,text=True,errors='replace')
        return p.returncode,p.stdout
    except Exception as e: return 999,repr(e)
def run_bg(args):
    try: subprocess.Popen(args,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,creationflags=0x08000000); return True
    except Exception: return False
def guarded(fn,timeout_s,tag):
    box={}
    def work():
        try: box['r']=fn()
        except Exception as ex: box['r']=None; box['err']=repr(ex)
    t=threading.Thread(target=work,daemon=True); t.start(); t.join(timeout_s)
    if t.is_alive():
        L('guard_timeout %s (%ds)'%(tag,timeout_s)); return None
    if 'err' in box: L('guard_error %s: %s'%(tag,box['err']))
    return box.get('r')
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
    rep=guarded(windows_report,20,'windows_report(layer)')
    if rep is None: return None
    top,children=rep
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
def ls_dir(p,maxn=60):
    out=[]
    try:
        for x in sorted(p.iterdir(),key=lambda z:z.name.lower())[:maxn]:
            try: out.append(x.name+('/' if x.is_dir() else ''))
            except Exception: pass
    except Exception as ex:
        out.append('<error %r>'%ex)
    return out

L('# R295 C-drive search + hard wallpaper repair')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))

# ---- 1. wallpaper layer state + repair
pl=wallpaper_players_in_layer()
layer_now='UP' if pl else ('ENUM_HUNG' if pl is None else 'DOWN')
L('layer_now=%s'%layer_now)
if not pl:
    L('== wallpaper pack contents ==')
    for n in ls_dir(L12,40): L('  '+n)
    keepers=[p for p in L12.glob('keeper*')] if L12.exists() else []
    L('keeper_candidates=%s'%[p.name for p in keepers])
    if keepers:
        k=keepers[0]
        L('running keeper: %s (%dB)'%(k.name,k.stat().st_size))
        if k.suffix.lower()=='.ps1':
            run_bg(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(k)])
        else:
            run_bg([str(k)])
        t0=time.time()
        while time.time()-t0<120:
            pl=wallpaper_players_in_layer()
            if pl: L('layer_recovered_via_keeper after %ds'%(int(time.time()-t0))); break
            time.sleep(10)
    if not pl:
        L('keeper insufficient - direct Lively restart with long poll')
        lively=''
        for cnd in LIVELY_CANDIDATES:
            if Path(cnd).exists(): lively=cnd; break
        run(['taskkill','/F','/IM','mpv.exe'],timeout=20)
        run(['taskkill','/F','/IM','Lively.exe'],timeout=20); time.sleep(5)
        if lively:
            run_bg([lively])
            t0=time.time()
            while time.time()-t0<180:
                pl=wallpaper_players_in_layer()
                if pl: L('layer_recovered_via_lively after %ds'%(int(time.time()-t0))); break
                if pl is None: L('enum_hung_poll')
                time.sleep(10)
    if not pl:
        pl=wallpaper_players_in_layer()
layer_final=bool(pl)
tmap=tasklist_map()
for c2 in (pl or [])[:3]: L('   wallpaper_player| class='+c2[1]+' owner='+tmap.get(c2[2],'?'))
L('layer_final=%s'%layer_final)

# ---- 2. C-drive keyword search (guarded)
KEYS=['anime-wallpapers','apps-shortcuts','deskbox-cute','job-tools','deskboxlibrary']
def csearch():
    rc,o=run(['cmd','/c','dir','C:\\Users','/s','/b','/ad'],timeout=300)
    hits=[ln for ln in (o or '').splitlines() if any(k in ln.lower() for k in KEYS)]
    return hits[:40],rc
L('== keyword search C:\\Users (guarded 300s) ==')
res=guarded(csearch,330,'csearch')
if res:
    hits,rc=res
    L('dir rc=%s hits=%d'%(str(rc),len(hits)))
    for h in hits: L('  HIT '+h)
else:
    L('C search unavailable/timeout')

# ---- 3. old DeskBox remnants
L('== scheduled tasks mentioning tidy/deskbox/organizer ==')
c,o=run(['schtasks','/query','/fo','csv'],timeout=40)
for ln in (o or '').splitlines():
    low=ln.lower()
    if 'tidy' in low or 'deskbox' in low or 'organiz' in low or 'cute' in low:
        L('  task '+ln[:160])
L('== apps\\DeskBox top ==')
for n in ls_dir(APPS_DESKBOX,40): L('  '+n)
L('== processes that might be the old deskbox ==')
for nm in ('DeskBox.exe','DeskBoxCute.exe','AutoTidy.exe'):
    c,o=run(['tasklist','/FI','IMAGENAME eq '+nm],timeout=20)
    if nm in (o or ''): L('  RUNNING '+nm)
L('== quark-cloud-drive top ==')
for n in ls_dir(Path(r'D:\quark-cloud-drive'),40): L('  '+n)
L('== D:\\Users? / C:\\Users one-level ==')
for base in (r'C:\Users',):
    try:
        for n in ls_dir(Path(base),30): L('  %s\\%s'%(base,n))
    except Exception as ex: L('  %s error %r'%(base,ex))

# ---- 4. boxes untouched check
box_pids=[]
for f in DBOX_DIR.glob('deskbox-*.pid'):
    try:
        pid=int(f.read_text().strip())
        c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
        if str(pid) in (o or ''): box_pids.append(pid)
    except Exception: pass
L('boxes_alive_now=%d %s'%(len(box_pids),box_pids))

ready=bool(layer_final and len(box_pids)>=2 and not locked)
L('R295_ROUND_READY='+str(ready))
summary={'ready':ready,'locked':locked,'layerFinal':layer_final,'boxesAlive':len(box_pids)}
WT(J,json.dumps(summary,ensure_ascii=False,indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
