# t276_c_cleanup_r325.py - round 325. User abandoned the winfr recovery.
# 1) record helper v10's final verdict, verify/stop WinFR (non-elevated best
#    effort - user was asked to close its window manually), 2) audit where
#    C:'s missing gigabytes went (read-only), 3) clean user-level safe caches
#    and recovery debris, 4) report freed space + admin-only items.
# NO elevation, NO UAC, NO recycle-bin touches, NO user-data deletion.
import os, sys, time, subprocess, json, traceback, shutil, winreg
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R325_C_CLEANUP.md'; J=OUT/'r325-c-cleanup.json'
DBOX=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
VSSOUT=DBOX/'vss_out.txt'
lines=[]
def L(s):
    s=str(s).encode('ascii','replace').decode('ascii'); print(s,flush=True); lines.append(s)
def WT(p,t):
    Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(t,encoding='utf-8')
def run(args,timeout=40):
    try:
        p=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout,text=True,errors='replace')
        return p.returncode,p.stdout
    except subprocess.TimeoutExpired: return 998,'timeout'
    except Exception as e: return 999,repr(e)
def walk(path):
    # cycle-safe (realpath dedup + depth cap) file walk -> (count, bytes)
    total=0; n=0; stack=[(str(path),0)]; seen=set()
    while stack:
        d,depth=stack.pop()
        try: rp=os.path.realpath(d)
        except Exception: rp=d
        if rp in seen or depth>10: continue
        seen.add(rp)
        try:
            for e in os.scandir(d):
                try:
                    if e.is_dir(follow_symlinks=False): stack.append((e.path,depth+1))
                    elif e.is_file(follow_symlinks=False):
                        total+=e.stat(follow_symlinks=False).st_size; n+=1
                except Exception: pass
        except Exception: pass
    return n,total
def free_c():
    try:
        f=shutil.disk_usage('C:\\'); return f.free//1048576, f.total//1048576
    except Exception: return -1,-1
freed=0
def rmtree_freed(path,label):
    global freed
    p=Path(path)
    if not p.exists(): L('  skip '+label+' (missing)'); return
    n0,b0=walk(p)
    shutil.rmtree(str(p),ignore_errors=True)
    n1,b1=walk(p) if p.exists() else (0,0)
    got=b0-b1; freed+=got
    L('  '+label+': freed '+str(got//1048576)+'MB (leftover '+str(b1//1048576)+'MB)')
def purge_children(path,label):
    global freed
    p=Path(path)
    if not p.exists(): L('  skip '+label+' (missing)'); return
    n0,b0=walk(p)
    try:
        for e in os.scandir(str(p)):
            try:
                if e.is_dir(follow_symlinks=False): shutil.rmtree(e.path,ignore_errors=True)
                else: os.unlink(e.path)
            except Exception: pass
    except Exception: pass
    n1,b1=walk(p)
    got=b0-b1; freed+=got
    L('  '+label+': freed '+str(got//1048576)+'MB (leftover '+str(b1//1048576)+'MB)')
def browser_caches():
    la=os.environ.get('LOCALAPPDATA','')
    out=[]
    for label,rel in (('edge',r'Microsoft\Edge\User Data'),('chrome',r'Google\Chrome\User Data')):
        ud=Path(os.path.join(la,rel))
        try:
            if ud.exists():
                for prof in ud.iterdir():
                    if prof.is_dir():
                        for sub in ('Cache','Code Cache','GPUCache','Media Cache'):
                            c=prof/sub
                            if c.is_dir(): out.append((label+'-'+prof.name+'-'+sub,str(c)))
        except Exception: pass
    return out
L('# R325 recovery abandoned - stop scan, audit C:, clean caches')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
try:
    free0,tot=free_c(); L('C: free before: '+str(free0)+'MB / total '+str(tot)+'MB')
    # 0) record helper v10 final verdict before removing its files
    if VSSOUT.exists():
        try:
            raw=VSSOUT.read_bytes().decode('utf-8',errors='replace')
            for ln in raw.splitlines()[-6:]: L('  vss_final| '+ln[:170])
        except Exception: pass
    # 1) WinFR status + non-elevated stop attempt
    c,o=run(['powershell','-NoProfile','-Command','(Get-Process WinFR -ErrorAction SilentlyContinue | Measure-Object).Count'],timeout=30)
    cl=(o or '').strip().splitlines()
    cnt=cl[-1].strip() if cl else ''
    alive=bool(cnt) and cnt!='0'
    L('winfr_count='+cnt)
    if alive:
        c2,o2=run(['powershell','-NoProfile','-Command','Stop-Process -Name WinFR -Force -ErrorAction SilentlyContinue; Start-Sleep 2; (Get-Process WinFR -ErrorAction SilentlyContinue | Measure-Object).Count'],timeout=40)
        c3=(o2 or '').strip().splitlines()
        after=c3[-1].strip() if c3 else '?'
        L('stop_attempt -> winfr_count='+after)
        alive=bool(after) and after!='0'
    L('winfr_alive_after='+str(alive))
    if alive:
        L('NOTE: winfr is elevated - user must close its minimized window manually (no UAC needed).')
    # 2) audit
    L('## audit (read-only sizes, MB)')
    LA=os.environ.get('LOCALAPPDATA','')
    TEMP=os.environ.get('TEMP','')
    audit=[('recovery_winfr_E',r'C:\recovery_winfr_E'),('user_temp',TEMP),
           ('crashdumps',os.path.join(LA,'CrashDumps')),
           ('c_windows_temp',r'C:\Windows\Temp'),
           ('wu_download',r'C:\Windows\SoftwareDistribution\Download'),
           ('c_recyclebin',r'C:\$Recycle.Bin'),
           ('programdata_wer',r'C:\ProgramData\Microsoft\Windows\WER'),
           ('search_index',r'C:\ProgramData\Microsoft\Windows\Search\Data'),
           ('pip_cache',os.path.join(LA,'pip','cache')),
           ('delivery_opt',r'C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization')]
    for name,p in audit:
        if p and os.path.exists(p):
            n,b=walk(p); L('  '+name+': '+str(n)+' files, '+str(b//1048576)+'MB')
        else: L('  '+name+': (missing/inaccessible)')
    for f in (r'C:\pagefile.sys',r'C:\hiberfil.sys',r'C:\swapfile.sys'):
        try: L('  '+f+': '+str(os.path.getsize(f)//1048576)+'MB')
        except Exception: pass
    L('  -- LOCALAPPDATA top 15 --')
    sz=[]
    if os.path.isdir(LA):
        try:
            for d in os.scandir(LA):
                try:
                    if d.is_dir(follow_symlinks=False):
                        n,b=walk(d.path); sz.append((b,d.name))
                except Exception: pass
        except Exception: pass
    sz.sort(reverse=True)
    for b,name in sz[:15]: L('  LA/'+name+': '+str(b//1048576)+'MB')
    # 3) cleanup
    L('## cleanup (user-level only)')
    purge_children(TEMP,'user_temp')
    purge_children(os.path.join(LA,'CrashDumps'),'crashdumps')
    rmtree_freed(os.path.join(LA,'pip','cache'),'pip_cache')
    for label,path in browser_caches():
        rmtree_freed(path,label)
    if os.path.exists(r'C:\recovery_winfr_E'):
        if not alive:
            rmtree_freed(r'C:\recovery_winfr_E','recovery_winfr_E')
        else:
            L('  recovery_winfr_E: SKIPPED - winfr still alive, close its window (r326 will remove)')
    else:
        L('  recovery_winfr_E: (already gone)')
    for f in ('vss_helper.ps1','vss_launch_v10.ps1','vss_out.txt','uac_err.txt'):
        p=DBOX/f
        try:
            if p.exists(): p.unlink(); L('  dbox/'+f+': removed')
            else: L('  dbox/'+f+': (missing)')
        except Exception as ex: L('  dbox/'+f+': FAILED '+repr(ex)[:80])
    desktop=None
    for keyname in (r'Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders',r'Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders'):
        try:
            k=winreg.OpenKey(winreg.HKEY_CURRENT_USER,keyname)
            v,_=winreg.QueryValueEx(k,'Desktop'); winreg.CloseKey(k)
            desktop=os.path.expandvars(v)
            if not os.path.isabs(desktop): desktop=None
            break
        except Exception: pass
    L('desktop='+str(desktop))
    if desktop and os.path.isdir(desktop):
        hit=set()
        for pat in ('RECOVERY*.bat','Recovery*.bat','recovery*.bat'):
            for bat in Path(desktop).glob(pat):
                if str(bat).lower() in hit: continue
                hit.add(str(bat).lower())
                try: bat.unlink(); L('  desktop/'+bat.name+': removed')
                except Exception as ex: L('  desktop/'+bat.name+': FAILED '+repr(ex)[:80])
    # 4) summary
    free1,_=free_c()
    L('## summary')
    L('freed_estimate='+str(int(freed//1048576))+'MB')
    L('C: free after: '+str(free1)+'MB (delta '+str(free1-free0)+'MB)')
    L('admin_only (user can clean via Settings > System > Storage): wu_download, delivery_opt, search_index, hiberfil, pagefile')
    L('recycle_bin_left_untouched=yes (may hold user files)')
    L('R325_CLEANUP_COMPLETE=True')
    WT(REPORT,'\n'.join(lines)+'\n')
    WT(J,json.dumps({'freed_mb':int(freed//1048576),'winfr_alive_after':bool(alive),'c_free_before_mb':free0,'c_free_after_mb':free1},indent=2)+'\n')
except Exception:
    L('FATAL: '+traceback.format_exc())
    try: WT(REPORT,'\n'.join(lines)+'\n')
    except Exception: pass
sys.exit(0)
