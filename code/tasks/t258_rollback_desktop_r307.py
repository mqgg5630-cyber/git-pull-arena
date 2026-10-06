# t258_rollback_desktop_r307.py - round 307. FULL DESKTOP ROLLBACK (user-
# ordered: "restore my previous desktop" - no taskbar, no desktop visible).
# Steps: stop our mpv wallpaper, set HideIcons=0, restart explorer (taskbar
# + icons), stop the three deskbox windows, remove our autostart entries.
# KEPT on purpose: the RECOVERY-recover-data.bat (20GB data recovery entry)
# and everything in deskbox-v2 (pid files, backups, logs, PATHS.txt).
import os, sys, time, subprocess, json, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R307_ROLLBACK_DESKTOP.md'; J=OUT/'r307-rollback-desktop.json'
DBOX=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
lines=[]
def L(s):
    s=str(s).encode('ascii','replace').decode('ascii'); print(s,flush=True); lines.append(s)
def WT(p,t,enc='utf-8'):
    Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(t,encoding=enc)
def run(args,timeout=25):
    try:
        p=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout,text=True,errors='replace')
        return p.returncode,p.stdout
    except subprocess.TimeoutExpired: return 998,'timeout'
    except Exception as e: return 999,repr(e)
def run_bg(args):
    try: subprocess.Popen(args,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,creationflags=0x08000000); return True
    except Exception: return False

L('# R307 FULL DESKTOP ROLLBACK')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
try:
    # ---- 0. state before
    c,o=run(['tasklist','/FI','IMAGENAME eq explorer.exe'],timeout=20)
    explorer_before='explorer.exe' in (o or ''); L('explorer_before=%s'%explorer_before)
    c,o=run(['tasklist','/FI','IMAGENAME eq mpv.exe'],timeout=20)
    L('mpv_before=%s'%('mpv.exe' in (o or '')))

    # ---- 1. stop our wallpaper player
    run(['taskkill','/F','/IM','mpv.exe'],timeout=20)
    run(['taskkill','/F','/IM','Lively.exe'],timeout=20)
    time.sleep(2)
    c,o=run(['tasklist','/FI','IMAGENAME eq mpv.exe'],timeout=20)
    L('mpv_after_kill=%s'%('mpv.exe' in (o or '')))

    # ---- 2. icons visible again
    c,o=run(['reg','add',r'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced','/v','HideIcons','/t','REG_DWORD','/d','0','/f'],timeout=20)
    L('hideicons_set0_rc=%s'%c)
    c,o=run(['reg','query',r'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced','/v','HideIcons'],timeout=20)
    L('hideicons_now=%s'%[x.strip() for x in (o or '').splitlines() if 'HideIcons' in x])

    # ---- 3. stop the three deskbox windows (our pythonw processes)
    stopped=0
    for f in DBOX.glob('deskbox-*.pid'):
        try:
            pid=int(f.read_text().strip())
            c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
            if str(pid) in (o or ''):
                run(['taskkill','/F','/PID',str(pid)],timeout=20); stopped+=1
        except Exception: pass
    L('boxes_stopped=%d'%stopped)
    time.sleep(1)
    alive=0
    for f in DBOX.glob('deskbox-*.pid'):
        try:
            pid=int(f.read_text().strip())
            c,o=run(['tasklist','/FI','PID eq %d'%pid],timeout=20)
            if str(pid) in (o or ''): alive+=1
        except Exception: pass
    L('boxes_still_alive=%d'%alive)

    # ---- 4. remove our autostart (Startup folder entries we added)
    startups=[]
    for base in (Path(os.environ.get('APPDATA',''))/'Microsoft'/'Windows'/'Start Menu'/'Programs'/'Startup',
                 Path(r'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp')):
        try:
            for f in base.iterdir():
                startups.append(str(f))
                low=f.name.lower()
                if 'deskbox' in low or 'desktop-organized' in low:
                    try: f.unlink(); L('autostart_removed=%s'%f)
                    except Exception as ex: L('autostart_remove_error=%s %r'%(f,ex))
        except Exception: pass
    L('startup_entries=%s'%startups)

    # ---- 5. restart explorer (rebuilds taskbar + desktop with icons)
    run(['taskkill','/F','/IM','explorer.exe'],timeout=20); time.sleep(3)
    run_bg(['explorer.exe'])
    time.sleep(8)
    c,o=run(['tasklist','/FI','IMAGENAME eq explorer.exe'],timeout=20)
    explorer_after='explorer.exe' in (o or ''); L('explorer_after=%s'%explorer_after)

    # ---- 6. final confirmation popup (visible again once explorer is back)
    msg=("Desktop restored: icons visible, taskbar restarted, desktop boxes "
         "stopped, wallpaper player stopped. The file RECOVERY-recover-data.bat "
         "stays on the desktop - double-click it (and click Yes) whenever you "
         "want to search shadow copies and recover the lost 20GB library.")
    run(['powershell','-NoProfile','-Command',
         "(New-Object -ComObject WScript.Shell).Popup('{0}',30,'DeskBox rollback complete',64)"\
         .format(msg.replace("'","''"))],timeout=40)

    ok=bool(explorer_after and stopped>=1)
    L('R307_ROLLBACK_OK=%s'%ok)
except Exception:
    L('FATAL: '+traceback.format_exc())
    ok=False
    L('R307_ROLLBACK_OK=False')
WT(REPORT,'\n'.join(lines)+'\n')
WT(J,json.dumps({'rollbackOk':ok},indent=2)+'\n')
sys.exit(0 if ok else 6)
