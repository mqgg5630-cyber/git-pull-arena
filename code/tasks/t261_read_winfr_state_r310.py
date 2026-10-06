# t261_read_winfr_state_r310.py - round 310. DATA RECOVERY phase 7.
# The user just double-clicked the bat again (v3 helper). Read vss_out.txt
# NOW and report exactly what happened: did winget install winfr, did the
# scan start, or did it fail again (real winget errors via unicode_escape).
# If winfr is running: process check + log tail + recovery dir census.
import os, sys, time, subprocess, json, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R310_WINFR_STATE.md'; J=OUT/'r310-winfr-state.json'
DBOX=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
VSSOUT=DBOX/'vss_out.txt'; WFLOG=DBOX/'winfr_E.log'
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

L('# R310 read the winfr state after the user double-click')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
state='unknown'
try:
    if VSSOUT.exists():
        mt=time.strftime('%Y-%m-%d %H:%M:%S',time.localtime(VSSOUT.stat().st_mtime))
        L('vss_out.txt mtime=%s size=%d'%(mt,VSSOUT.stat().st_size))
        vtxt=VSSOUT.read_text(encoding='utf-8',errors='replace')
        vls=vtxt.splitlines()
        L('== full vss_out.txt (%d lines) =='%len(vls))
        for ln in vls[:120]:
            L('  vss| '+ln[:170])
            if '?' in ln:
                L('  raw| '+ln.encode('unicode_escape').decode('ascii')[:260])
        if 'WINFR_START' in vtxt: state='winfr_running'
        elif 'WINFR_INSTALL_FAILED' in vtxt: state='winfr_install_failed'
        elif 'RECOVERY_START' in vtxt: state='recovering_vss'
        elif 'NO_SHADOWS' in vtxt or 'shadow_count=0' in vtxt: state='no_shadows'
        else: state='unclear'
    else:
        L('vss_out.txt absent'); state='no_file'

    # winfr process / log / output dir
    c,o=run(['tasklist','/FI','IMAGENAME eq winfr.exe'],timeout=20)
    L('winfr_process=%s'%('winfr.exe' in (o or '')))
    c,o=run(['tasklist','/FI','IMAGENAME eq cmd.exe'],timeout=20)
    L('cmd_count=%d'%(o or '').count('cmd.exe'))
    if WFLOG.exists():
        try:
            wl=WFLOG.read_text(encoding='utf-8',errors='replace').splitlines()
            L('== winfr_E.log (%d lines), tail =='%len(wl))
            for ln in wl[-15:]: L('  wf| '+ln[:170])
        except Exception as ex: L('winfr log read error %r'%ex)
    else:
        L('winfr_E.log absent (not started or redirect failed)')
    rdir=Path(r'C:\recovery_winfr_E')
    if rdir.exists():
        try:
            ents=list(rdir.rglob('*'))
            files=[e for e in ents if e.is_file()]
            tot=sum(e.stat().st_size for e in files)
            L('recovery_winfr_E: %d files, %dMB total'%(len(files),tot//1048576))
            subs=set(e.parent.relative_to(rdir) for e in files)
            for s in list(subs)[:15]: L('   subdir %s'%s)
        except Exception as ex: L('recovery dir read error %r'%ex)
    else:
        L('C:\\recovery_winfr_E absent')
except Exception:
    L('FATAL: '+traceback.format_exc()); state='crashed'
L('state=%s'%state)
WT(REPORT,'\n'.join(lines)+'\n')
WT(J,json.dumps({'state':state},indent=2)+'\n')
sys.exit(0 if state!='crashed' and state!='no_file' else 6)
