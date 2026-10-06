# t270_winfr_tally_r319.py - round 319. DATA RECOVERY phase 14 (tally).
# helper v8 is running independently (VARIANT v1 started, winfr alive).
# This task polls vss_out.txt for up to 20 minutes for WINFR_DONE /
# WINFR_FAILED_ALL / 'helper v8 done', printing the latest MONITOR lines,
# then reports the final tally: file count, MB, Recovery_* subdirs, and a
# per-category census if the nine-category structure was restored.
import os, sys, time, subprocess, json, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R319_WINFR_TALLY.md'; J=OUT/'r319-winfr-tally.json'
DBOX=Path(r'E:\0mcp-agv-arena-optimized\deskbox-v2')
VSSOUT=DBOX/'vss_out.txt'
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
NEED=['01-Apps-Shortcuts','02-Job-Tools','03-Video-Creation','04-Images-ID-Photos','05-Documents','06-Archives-Installers','07-Old-Folders','08-Misc','09-Anime-Wallpapers']

L('# R319 winfr tally - waiting for the helper v8 verdict')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
final=None
try:
    t0=time.time(); lastmon=''
    while time.time()-t0<1200:
        time.sleep(60)
        vtxt=''
        if VSSOUT.exists():
            try: vtxt=VSSOUT.read_text(encoding='utf-8',errors='replace')
            except Exception: pass
        mons=[ln for ln in vtxt.splitlines() if ln.startswith('MONITOR')]
        if mons and mons[-1]!=lastmon:
            lastmon=mons[-1]; L('  %s'%lastmon[:170])
        if 'WINFR_DONE' in vtxt:
            final=[ln for ln in vtxt.splitlines() if 'WINFR_DONE' in ln][0]; L('VERDICT: '+final[:170]); break
        if 'WINFR_FAILED_ALL' in vtxt:
            final='WINFR_FAILED_ALL'; L('VERDICT: WINFR_FAILED_ALL'); break
        if 'WINFR_NOT_FOUND' in vtxt:
            final='WINFR_NOT_FOUND'; L('VERDICT: WINFR_NOT_FOUND'); break
    if final is None:
        L('no final verdict within 1200s - scan still running (helper deadline is 40min); reporting current progress')
    # full monitor summary
    if VSSOUT.exists():
        try:
            vtxt=VSSOUT.read_text(encoding='utf-8',errors='replace')
            vls=vtxt.splitlines()
            L('== vss_out.txt key lines (%d total) =='%len(vls))
            for ln in vls:
                if ln.startswith('VARIANT') or 'WINFR_' in ln or 'start_error' in ln or ln.startswith('  out:') or 'helper v8 done' in ln:
                    L('  vss| '+ln[:170])
        except Exception as ex: L('vss read error %r'%ex)
    # recovery dir census
    rdir=Path(r'C:\recovery_winfr_E')
    if rdir.exists():
        try:
            recs=[d for d in rdir.iterdir() if d.is_dir()]
            L('recovery_winfr_E: %d Recovery_* dirs'%len(recs))
            allfiles=0; allmb=0
            for d in recs:
                try:
                    fs=[e for e in d.rglob('*') if e.is_file()]
                    mb=sum(e.stat().st_size for e in fs)//1048576
                    L('  %s: %d files, %dMB'%(d.name,len(fs),mb))
                    allfiles+=len(fs); allmb+=mb
                except Exception: pass
            L('TOTAL recovered: %d files, %dMB'%(allfiles,allmb))
            # per-category census (any depth matching the nine names)
            for d in recs:
                for cat in NEED:
                    hits=[p for p in d.rglob(cat) if p.is_dir()]
                    for h in hits[:1]:
                        try:
                            items=list(h.iterdir())
                            L('  CAT %s -> %d entries (%s)'%(cat,len(items),str(h)[:150]))
                        except Exception: pass
            # extension stats for the biggest recovered set
            exts={}
            for d in recs:
                for e in d.rglob('*'):
                    if e.is_file():
                        k=e.suffix.lower() or '(none)'
                        exts[k]=exts.get(k,0)+1
            top=sorted(exts.items(),key=lambda x:-x[1])[:12]
            L('top extensions: %s'%(', '.join('%s:%d'%kv for kv in top)))
        except Exception as ex: L('census error %r'%ex)
    else:
        L('recovery_winfr_E absent')
except Exception:
    L('FATAL: '+traceback.format_exc())
L('R319_TALLY_COMPLETE=True')
WT(REPORT,'\n'.join(lines)+'\n')
WT(J,json.dumps({'final':str(final)},indent=2)+'\n')
sys.exit(0)
