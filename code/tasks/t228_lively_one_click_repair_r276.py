# t228_lively_one_click_repair_r276.py - round 276.
# User request: "容易被其他杀掉" - provide a DESKTOP ONE-CLICK launcher so a
# killed wallpaper can be restored manually with a double-click.
# This round:
#   1. Writes repair_lively_hotori.py into the permanent wallpaper folder
#      (same logic as the logon keeper, but immediate + console progress in
#      Chinese + repair.log). --auto flag = machine mode (no input pause).
#   2. Writes desktop shortcut "一键启动动态壁纸.bat" (ASCII content) that
#      runs the repair script and pauses so the user sees the result.
#   3. LIVE KILL TEST: taskkill Lively.exe + mpv.exe + Livelycu.exe, prove
#      the wallpaper layer is EMPTY, then run the repair script exactly the
#      way it is meant to work (--auto) and prove the wallpaper comes back:
#      WorkerW layer structure + motion probe (two frames 45s apart).
#   4. If anything fails, direct recovery (start Lively + setwp + play) so
#      the machine never ends this round without a wallpaper.
import ctypes, os, sys, time, subprocess, json, shutil, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R276_LIVELY_ONE_CLICK_REPAIR.md'; J=OUT/'r276-one-click-repair.json'
C=OUT/'r276_frame_c_after_repair.bmp'; D=OUT/'r276_frame_d_after_repair.bmp'
PERM=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\lively-hotori')
MP4=PERM/'hotori_dynamic_wallpaper.mp4'
REPAIR_PY=PERM/'repair_lively_hotori.py'; REPAIR_LOG=PERM/'repair.log'
LIVELY_CANDIDATES=[r'C:\Program Files\Lively Wallpaper\Lively.exe',r'C:\Program Files (x86)\Lively Wallpaper\Lively.exe',str(Path(os.environ.get('LOCALAPPDATA',r'C:\Users\Public'))/'Programs'/'Lively Wallpaper'/'Lively.exe')]
STATIC_R267=Path(r'E:\0mcp-agv-arena-optimized\wallpapers\static-anime-r267\cute_static_anime_wallpaper_r267.png')
STATIC_DEFAULT=r'C:\Windows\Web\Wallpaper\Windows\img0.jpg'
DESK=Path(os.environ.get('USERPROFILE',r'C:\Users\Public'))/'Desktop'
DESK_BAT=DESK/'一键启动动态壁纸.bat'
KEEPER_PY=PERM/'keeper_lively_hotori.py'; KEEPER_BAT=Path(os.environ.get('APPDATA',r'C:\Users\Public'))/'Microsoft'/'Windows'/'Start Menu'/'Programs'/'Startup'/'Lively Wallpaper Keeper.bat'
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
def set_static(path):
    try: ctypes.windll.user32.SystemParametersInfoW(20,0,str(path),3)
    except Exception: pass
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

L('# R276 Lively dynamic wallpaper - desktop one-click repair')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
L('user_request=desktop one-click launcher so a killed wallpaper can be restored manually')
locked='LogonUI.exe' in run(['tasklist','/FI','IMAGENAME eq LogonUI.exe'])[1]; L('screen_locked_detected='+str(locked))
lively=''
for c in LIVELY_CANDIDATES:
    if Path(c).exists(): lively=c; break
L('lively_exe='+str(lively))
L('mp4_exists='+str(MP4.exists())+' bytes='+str(MP4.stat().st_size if MP4.exists() else 0))

# ---- 1. write the repair script (user-facing, Chinese console output)
repair_src=(
"# repair_lively_hotori.py - desktop one-click repair for the Lively dynamic wallpaper.\n"
"# Double-click the desktop bat to run me. Log: repair.log next to this file.\n"
"# --auto : machine mode, no input() pause, exit code 0 ok / 1 failed.\n"
"import ctypes, os, subprocess, sys, time\n"
"from pathlib import Path\n"
"AUTO = '--auto' in sys.argv\n"
"BASE = Path(__file__).resolve().parent\n"
"MP4 = BASE / 'hotori_dynamic_wallpaper.mp4'\n"
"LOG = BASE / 'repair.log'\n"
"LIVELY = r'C:\\Program Files\\Lively Wallpaper\\Lively.exe'\n"
"def say(m):\n"
"    print(m, flush=True)\n"
"    try:\n"
"        entry = time.strftime('%Y-%m-%d %H:%M:%S') + ' ' + m + '\\n'\n"
"        old = LOG.read_text(encoding='utf-8', errors='replace') if LOG.exists() else ''\n"
"        LOG.write_text((old + entry)[-4000:], encoding='utf-8')\n"
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
"        say('     layer probe error ' + repr(ex))\n"
"        return []\n"
"say('========================================')\n"
"say('     动态壁纸 一键修复 (r276)')\n"
"say('========================================')\n"
"run(['taskkill', '/F', '/IM', 'Livelycu.exe'], timeout=20)\n"
"ok = False\n"
"for attempt in range(1, 4):\n"
"    say('[' + str(attempt) + '/3] checking wallpaper state...')\n"
"    if not running('Lively.exe'):\n"
"        say('     Lively 没在运行，正在启动...')\n"
"        try: subprocess.Popen([LIVELY], cwd=str(Path(LIVELY).parent), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n"
"        except Exception as ex: say('     start failed: ' + repr(ex))\n"
"        time.sleep(25)\n"
"    players = layer_players()\n"
"    if players:\n"
"        say('     壁纸正常运行中，无需修复')\n"
"        ok = True\n"
"        break\n"
"    if not MP4.exists():\n"
"        say('     wallpaper file missing: ' + str(MP4))\n"
"        break\n"
"    say('     壁纸不在桌面层，正在重新设置...')\n"
"    c, o = run([LIVELY, 'setwp', '--file', str(MP4), '--monitor', '1'])\n"
"    say('     setwp exit ' + str(c))\n"
"    time.sleep(25)\n"
"    run([LIVELY, '--play', 'true'])\n"
"    time.sleep(8)\n"
"    players = layer_players()\n"
"    if players:\n"
"        say('     修复成功，动态壁纸已恢复')\n"
"        ok = True\n"
"        break\n"
"if not ok:\n"
"    say('修复失败。请把本窗口内容截图发回给助手')\n"
"if not AUTO:\n"
"    try: input('按回车键关闭...')\n"
"    except Exception: pass\n"
"sys.exit(0 if ok else 1)\n")
try:
    WT(REPAIR_PY,repair_src)
    L('repair_py='+str(REPAIR_PY)+' exists='+str(REPAIR_PY.exists())+' bytes='+str(REPAIR_PY.stat().st_size if REPAIR_PY.exists() else 0))
except Exception as ex: L('repair_py_error='+repr(ex))
repair_py_installed=bool(REPAIR_PY.exists() and REPAIR_PY.stat().st_size>3000)

# ---- 2. desktop one-click bat (ASCII content, Chinese filename)
try:
    bat=('@echo off\r\n'
         'title Lively Wallpaper One-Click Repair\r\n'
         'echo ==================================================\r\n'
         'echo   Dynamic Wallpaper One-Click Repair (r276)\r\n'
         'echo ==================================================\r\n'
         'echo.\r\n'
         'set "SCRIPT='+str(REPAIR_PY)+'"\r\n'
         'set "PY="\r\n'
         'where python.exe >nul 2>&1 && set "PY=python"\r\n'
         'if not defined PY where py.exe >nul 2>&1 && set "PY=py -3"\r\n'
         'if not defined PY (\r\n'
         '  echo [ERROR] Python not found - tell the agent.\r\n'
         '  pause\r\n'
         '  exit /b 1\r\n'
         ')\r\n'
         '%PY% "%SCRIPT%"\r\n'
         'echo.\r\n'
         'pause\r\n')
    WA(DESK_BAT,bat)
    L('desktop_bat_exists='+str(DESK_BAT.exists())+' bytes='+str(DESK_BAT.stat().st_size if DESK_BAT.exists() else 0))
    for ln in bat.splitlines(): L('   bat| '+ln[:110])
except Exception as ex: L('desktop_bat_error='+repr(ex))
desktop_bat_installed=bool(DESK_BAT.exists() and DESK_BAT.stat().st_size>300)

# ---- 3. PATHS.txt refresh (documents everything)
try:
    WT(PERM/'PATHS.txt','Lively dynamic wallpaper (permanent home)\r\n=========================================\r\nwallpaper    : '+str(MP4)+'\r\none-click fix: double-click the desktop file \r\n              '+str(DESK_BAT)+'\r\nrepair script: '+str(REPAIR_PY)+' (--auto = no pause)\r\nrepair log   : '+str(REPAIR_LOG)+'\r\nlogon keeper : '+str(KEEPER_PY)+'\r\nkeeper bat   : '+str(KEEPER_BAT)+' (Startup folder)\r\nkeeper log   : '+str(PERM/'keeper.log')+'\r\nlively exe   : '+str(lively)+'\r\n')
    L('paths_txt_refreshed=True')
except Exception: pass

# ---- 4. LIVE KILL TEST: kill everything, prove the layer is empty
L('kill_test_start (simulating: something killed the wallpaper)')
k1,_=run(['taskkill','/F','/IM','Lively.exe','/IM','mpv.exe','/IM','Livelycu.exe'],timeout=30)
L('taskkill_exit='+str(k1))
time.sleep(8)
lively_after_kill=task_count('Lively.exe'); mpv_after_kill=task_count('mpv.exe')
L('lively_processes_after_kill='+str(lively_after_kill)); L('mpv_processes_after_kill='+str(mpv_after_kill))
try:
    pk=wallpaper_players_in_layer()
    layer_empty_after_kill=len(pk)==0
    L('layer_empty_after_kill='+str(layer_empty_after_kill)+' players='+str(len(pk)))
except Exception as ex:
    layer_empty_after_kill=False; L('kill_test_probe_error='+repr(ex))

# ---- 5. run the repair script exactly like a user double-click would (--auto)
repair_exit=-1; repair_tail=''
if repair_py_installed:
    try:
        p=subprocess.run([sys.executable,str(REPAIR_PY),'--auto'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=300,text=True,errors='replace')
        repair_exit=p.returncode; repair_tail=(p.stdout or '')
    except Exception as ex:
        repair_exit=999; repair_tail=repr(ex)
    for ln in (repair_tail or '').strip().splitlines()[-14:]: L('   repair| '+ln[:120])
L('repair_auto_exit='+str(repair_exit))

# ---- 6. verify the wallpaper is back (structure)
tmap=tasklist_map()
pl=wallpaper_players_in_layer()
for c in pl[:6]: L('   wallpaper_player| class='+c[1]+' owner='+tmap.get(c[2],'?')+' rect='+str((c[4],c[5],c[6],c[7])))
layer_present_after_repair=len(pl)>0
L('layer_present_after_repair='+str(layer_present_after_repair))

# ---- 7. motion probe (two frames 45s apart)
time.sleep(5); mini(); time.sleep(1)
ok,w,h,e=shot(C); L(f'frame_c_after_repair={C} ok={ok} width={w} height={h} err={e}')
time.sleep(45)
ok,w,h,e=shot(D); L(f'frame_d_after_repair={D} ok={ok} width={w} height={h} err={e}')
d_m=diff(C,D)
L('motion_after_repair_ratio=%.6f'%d_m['ratio']); L('motion_after_repair_avg=%.3f'%d_m['avg'])
motion_after_repair_proven=bool(d_m.get('ok') and (d_m['ratio']>0.0005 or d_m['avg']>0.25))
L('motion_after_repair_proven='+str(motion_after_repair_proven))

# ---- 8. safety net: never end the round without a wallpaper
if not layer_present_after_repair and lively and MP4.exists():
    L('direct_recovery_start')
    if task_count('Lively.exe')==0:
        try: subprocess.Popen([lively],cwd=str(Path(lively).parent),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        except Exception: pass
        time.sleep(25)
    e1,_=run([lively,'setwp','--file',str(MP4),'--monitor','1'],timeout=30); L('recovery_setwp_exit='+str(e1))
    time.sleep(20)
    run([lively,'--play','true'],timeout=15); time.sleep(5)
    pl=wallpaper_players_in_layer(); layer_present_after_repair=len(pl)>0
    L('layer_present_after_recovery='+str(layer_present_after_repair))
if not layer_present_after_repair:
    set_static(str(STATIC_R267) if STATIC_R267.exists() else STATIC_DEFAULT)
    L('rollback_static_done=True')

ready=bool(repair_py_installed and desktop_bat_installed and layer_empty_after_kill and repair_exit==0 and layer_present_after_repair and motion_after_repair_proven and not locked)
L('one_click_repair_ready='+str(ready))

# ---- 9. receipts
deskbox=DESK/'DeskBox-Cute-Desktop-Organizer'; deskbox.mkdir(parents=True,exist_ok=True)
tidy=deskbox/'AUTO_TIDY_LAST_RUN.txt'; tidy.write_text('time='+time.strftime('%Y-%m-%d %H:%M:%S')+'\nlively_one_click_repair_r276='+str(ready)+'\n',encoding='utf-8')
L('desktop_tidy_done='+str(tidy.exists()))
L('LIVELY_ONE_CLICK_REPAIR_READY='+str(ready))
summary={'ready':ready,'locked':locked,'repairPy':str(REPAIR_PY),'desktopBat':str(DESK_BAT),'repairAutoExit':repair_exit,'killTestLayerEmpty':layer_empty_after_kill,'layerPresentAfterRepair':layer_present_after_repair,'motionAfterRepairRatio':d_m.get('ratio'),'motionAfterRepairProven':motion_after_repair_proven,'keeperStillInstalled':bool(KEEPER_PY.exists() and KEEPER_BAT.exists()),'mp4':str(MP4)}
WT(J,json.dumps(summary,ensure_ascii=False,indent=2)+'\n'); WT(REPORT,'\n'.join(lines)+'\n')
sys.exit(0 if ready else 6)
