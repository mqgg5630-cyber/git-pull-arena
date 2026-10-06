# t248_mpv_embed_r297.py - round 297.
# r296 proved the boxes NEVER move files (zero shutil/move/copy/rename in
# both sources) and crashed in 1s on state.json current=17 being an INT.
# This round: fix the int handling and drive the wallpaper embed ourselves.
#  C. Wallpaper layer: manual mpv --wid embed under WorkerW (Lively restarts
#     keep failing to re-embed; drive the player ourselves).
#  D. Boxes untouched; nothing deleted anywhere.
import ctypes, os, sys, time, subprocess, json, threading
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R297_MPV_EMBED.md'; J=OUT/'r297-mpv-embed.json'
DBOX=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
L12=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\lively-12')
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
    if t.is_alive(): L('guard_timeout %s (%ds)'%(tag,timeout_s)); return None
    if 'err' in box: L('guard_error %s: %s'%(tag,box['err']))
    return box.get('r')

# ---- C. wallpaper: manual mpv --wid embed
u=ctypes.windll.user32
import ctypes.wintypes as wt
u.EnumWindows.argtypes=[ctypes.c_void_p,wt.LPARAM]
def find_workerw():
    prog=u.FindWindowW('Progman',None)
    res=wt.DWORD()
    u.SendMessageTimeoutW(prog,0x052C,0,0,0x2,1500,ctypes.byref(res))
    found=[]
    CB=ctypes.WINFUNCTYPE(ctypes.c_bool,wt.HWND,wt.LPARAM)
    def cb(h,l):
        cls=ctypes.create_unicode_buffer(64); u.GetClassNameW(h,cls,64)
        if cls.value=='WorkerW':
            p=u.GetParent(h); pcls=ctypes.create_unicode_buffer(64)
            if p: u.GetClassNameW(p,pcls,64)
            if not p or pcls.value in ('Progman','WorkerW'): found.append(h)
        return True
    u.EnumWindows(CB(cb),0)
    return found[-1] if found else 0
def layer_children():
    top=[]; children=[]
    CB=ctypes.WINFUNCTYPE(ctypes.c_bool,wt.HWND,wt.LPARAM)
    def probe(h):
        cls=ctypes.create_unicode_buffer(256); u.GetClassNameW(h,cls,256)
        pid=wt.DWORD(); u.GetWindowThreadProcessId(h,ctypes.byref(pid))
        r=wt.RECT(); u.GetWindowRect(h,ctypes.byref(r))
        return (h,cls.value,int(pid.value),int(u.IsWindowVisible(h)),int(r.left),int(r.top),int(r.right),int(r.bottom))
    def tcb(h,l): top.append(probe(h)); return True
    u.EnumWindows(CB(tcb),0)
    roots=[w[0] for w in top if w[1] in ('WorkerW','Progman')]
    def ccb(h,l): children.append(probe(h)); return True
    for rh in roots: u.EnumChildWindows(rh,CB(ccb),0)
    return top,children
def wallpaper_up():
    rep=guarded(layer_children,20,'layer_children')
    if rep is None: return None
    top,children=rep
    tmap={}
    c,o=run(['tasklist','/FO','CSV','/NH'],timeout=30)
    for ln in (o or '').splitlines():
        parts=ln.split('","')
        if len(parts)>=2:
            try: tmap[int(parts[1].strip('"'))]=parts[0].strip('"')
            except Exception: pass
    SW=u.GetSystemMetrics(78); SH=u.GetSystemMetrics(79)
    EXPL={'SHELLDLL_DefView','SysListView32','SysHeader32','WorkerW','Progman'}
    hits=[]
    for c2 in children:
        if c2[1] in EXPL: continue
        if 'explorer' in tmap.get(c2[3] if False else c2[2],'?').lower(): continue
        if not c2[3]: continue
        if (c2[6]-c2[4])>=SW*0.95 and (c2[7]-c2[5])>=SH*0.95: hits.append((c2,tmap.get(c2[2],'?')))
    return hits
st=json.loads((L12/'state.json').read_text()) if (L12/'state.json').exists() else {}
cur=st.get('current') or 17
if isinstance(cur,int):
    hits=sorted(L12.glob('%02d-*.mp4'%cur)) or sorted(L12.glob('%d-*.mp4'%cur))
    cur=hits[0].name if hits else '17-pure-soul.mp4'
cur=str(cur)
vid=L12/cur
L('target_wallpaper=%s exists=%s size=%s'%(str(vid),vid.exists(),vid.stat().st_size if vid.exists() else -1))
mpv=''
for cnd in (r'C:\Program Files\Lively Wallpaper\mpv\mpv.exe',r'C:\Program Files\Lively Wallpaper\mpv.exe',str(Path.home()/'.lively'/ 'mpv'/'mpv.exe')):
    if Path(cnd).exists(): mpv=cnd; break
if not mpv:
    c,o=run(['powershell','-NoProfile','-Command','(Get-Process mpv -ErrorAction SilentlyContinue | Select-Object -First 1).Path'],timeout=30)
    mpv=(o or '').strip().splitlines()[-1].strip() if o and o.strip() else ''
L('mpv=%s'%mpv)
pl=wallpaper_up()
L('layer_before=%s'%('UP' if pl else 'DOWN'))
if not pl:
    run(['taskkill','/F','/IM','mpv.exe'],timeout=20); run(['taskkill','/F','/IM','Lively.exe'],timeout=20); time.sleep(4)
    hwnd=guarded(find_workerw,25,'find_workerw')
    L('workerw_hwnd=%s'%hwnd)
    if hwnd and mpv and vid.exists():
        ok=run_bg([mpv,'--wid=%d'%hwnd,'--no-audio','--loop-file=inf','--no-border','--osc=no',str(vid)])
        L('mpv_spawn=%s'%ok)
        t0=time.time()
        while time.time()-t0<90:
            pl=wallpaper_up()
            if pl: L('layer_up after %ds'%(int(time.time()-t0))); break
            time.sleep(8)
pl=wallpaper_up() if not pl else pl
layer_final=bool(pl)
for c2,owner in (pl or [])[:3]: L('   wallpaper_player| class=%s owner=%s rect=%d,%d-%d,%d'%(c2[1],owner,c2[4],c2[5],c2[6],c2[7]))
L('layer_final=%s'%layer_final)

# ---- D. boxes untouched
box_pids=[]
for f in DBOX.glob('deskbox-*.pid'):
    try:
        pid=int(f.read_text().strip())
        c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
        if str(pid) in (o or ''): box_pids.append(pid)
    except Exception: pass
L('boxes_alive_now=%d %s'%(len(box_pids),box_pids))
ready=bool(layer_final and len(box_pids)>=2)
L('R297_ROUND_READY='+str(ready))
WT(J,json.dumps({'ready':ready,'layerFinal':layer_final,'boxesAlive':len(box_pids)},indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
