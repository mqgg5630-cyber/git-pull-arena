# t278_doc_recon_r327.py - round 327. User wants SOME DOCUMENTS back from
# the deleted E: library. Recon before choosing a method:
# 1) census ALL recycle bins (E:, D:, C:) + parse $I metadata (original path,
#    deletion time, size) - if the library was Explorer-deleted it may still
#    sit in a recycle bin;
# 2) disk-wide search for existing document-type files (a copy may survive
#    outside the deleted set);
# 3) desktop .lnk targets (where did the 44 shortcuts point);
# 4) capture winfr /? to check whether this vintage has a signature mode.
# Read-only, NO elevation, NO UAC, NO downloads.
import os, sys, time, subprocess, traceback, struct, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R327_DOC_RECON.md'; J=OUT/'r327-doc-recon.json'
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
def list_files(root,deadline=None,cap=2000000):
    out=[]; stack=[(str(root),0)]; seen=set(); tmo=False
    while stack:
        if deadline and time.time()>deadline: tmo=True; break
        if len(out)>=cap: tmo=True; break
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
                        out.append((e.path,e.stat(follow_symlinks=False).st_size,e.stat(follow_symlinks=False).st_mtime))
                except Exception: pass
        except Exception: pass
    return out,tmo
def parse_i(b):
    try:
        if len(b)<28: return None
        ver=struct.unpack('<Q',b[0:8])[0]
        size=struct.unpack('<Q',b[8:16])[0]
        ft=struct.unpack('<Q',b[16:24])[0]
        ln=struct.unpack('<I',b[24:28])[0]
        if ln>20000: ln=20000
        p=b[28:28+ln*2].decode('utf-16-le',errors='replace').split('\x00')[0]
        unix=(ft-116444736000000000)/10.0
        return ver,size,unix,p
    except Exception: return None
def iso(unix):
    try: return time.strftime('%Y-%m-%d %H:%M',time.localtime(unix))
    except Exception: return '?'
res={}
L('# R327 document recovery recon (read-only, non-elevated)')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
try:
    # 1) recycle bins
    L('## recycle bins')
    for drive in ('E:','D:','C:'):
        rb=drive+'\\$Recycle.Bin'
        if not os.path.isdir(rb): L('  '+drive+': no bin dir'); continue
        files,tmo=list_files(rb,cap=500000)
        tot=sum(s for _,s,_ in files)
        L('  '+drive+' bin: '+str(len(files))+' files, '+str(tot//1048576)+'MB'+(' (partial)' if tmo else ''))
        rs=[]
        try:
            for sid in os.scandir(rb):
                try:
                    if sid.is_dir(follow_symlinks=False):
                        for e2 in os.scandir(sid.path):
                            if e2.name.upper().startswith('$R'):
                                try: rs.append((e2.path,e2.is_dir(follow_symlinks=False)))
                                except Exception: rs.append((e2.path,False))
                except Exception: pass
        except Exception: pass
        L('    $R top-level items: '+str(len(rs))+' ('+str(sum(1 for _,d in rs if d))+' are folders)')
        for p,d in rs[:8]: L('      R| '+('DIR  ' if d else 'FILE ')+' '+p[:120])
        iparsed=[]
        for p,s,m in files:
            if os.path.basename(p).upper().startswith('$I'):
                try:
                    r=parse_i(open(p,'rb').read())
                    if r: iparsed.append(r)
                except Exception: pass
        L('    $I entries parsed: '+str(len(iparsed)))
        iparsed.sort(key=lambda x:-x[1])
        for ver,size,unix,p in iparsed[:12]:
            L('    I| '+iso(unix)+' | '+str(size//1024)+'KB | '+p[:120])
        libh=[(ver,size,unix,p) for ver,size,unix,p in iparsed if ('library' in p.lower()) or ('deskbox' in p.lower())]
        L('    deskbox/library-related $I: '+str(len(libh)))
        for ver,size,unix,p in libh[:12]:
            L('    LIB| '+iso(unix)+' | '+str(size//1024)+'KB | '+p[:120])
        exts={}
        for p,s,m in files:
            bn=os.path.basename(p)
            if bn.upper().startswith('$R'):
                e=os.path.splitext(bn)[1].lower(); exts[e]=exts.get(e,0)+1
        top=sorted(exts.items(),key=lambda x:-x[1])[:12]
        L('    $R ext histogram: '+', '.join((e or '(none)')+':'+str(c) for e,c in top))
        res[drive+'_bin']={'files':len(files),'mb':tot//1048576}
    # 2) existing document files
    L('## existing document-type files on disk')
    DOC_EXTS={'.doc','.docx','.xls','.xlsx','.ppt','.pptx','.pdf','.txt','.md','.csv','.rtf','.odt'}
    SKIP=('.git\\','node_modules','ms-playwright','$recycle.bin','\\appdata\\local\\temp','\\windows\\','program files','windowsapps','system volume information','\\temp\\','$windows.~')
    deadline=time.time()+840
    hits=[]
    roots=['E:\\','D:\\',os.environ.get('USERPROFILE','')]
    for root in roots:
        if not root or not os.path.isdir(root): continue
        files,tmo=list_files(root,deadline=deadline,cap=2000000)
        cnt=0; totmb=0
        for p,s,m in files:
            pl=p.lower()
            if any(k in pl for k in SKIP): continue
            if os.path.splitext(p)[1].lower() in DOC_EXTS:
                cnt+=1; totmb+=s; hits.append((p,s,m))
        L('  '+root[:3]+' scanned '+str(len(files))+' files'+(' (partial-timeout)' if tmo else '')+' -> doc hits: '+str(cnt)+' / '+str(totmb//1048576)+'MB')
    hits.sort(key=lambda x:-x[2])
    L('  -- 30 most recently modified doc files --')
    for p,s,m in hits[:30]:
        L('   '+time.strftime('%m-%d %H:%M',time.localtime(m))+' | '+str(s//1024)+'KB | '+p[:130])
    dl=[h for h in hits if ('deskbox' in h[0].lower()) or ('library' in h[0].lower()) or ('0mcp' in h[0].lower())]
    L('  doc hits under deskbox/library/0mcp paths: '+str(len(dl)))
    for p,s,m in dl[:20]:
        L('   DL| '+time.strftime('%m-%d %H:%M',time.localtime(m))+' | '+str(s//1024)+'KB | '+p[:130])
    res['doc_hits_total']=len(hits)
    # 3) desktop shortcuts
    L('## desktop shortcuts')
    import winreg
    desktop=None
    for keyname in (r'Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders',r'Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders'):
        try:
            k=winreg.OpenKey(winreg.HKEY_CURRENT_USER,keyname)
            v,_=winreg.QueryValueEx(k,'Desktop'); winreg.CloseKey(k)
            desktop=os.path.expandvars(v)
            if not os.path.isabs(desktop): desktop=None
            break
        except Exception: pass
    L('  desktop='+str(desktop))
    if desktop and os.path.isdir(desktop):
        c,o=run(['powershell','-NoProfile','-Command',"Get-ChildItem -LiteralPath '"+desktop+"' -Filter *.lnk | ForEach-Object { $s=(New-Object -ComObject WScript.Shell).CreateShortcut($_.FullName); '{0} => {1}' -f $_.BaseName, $s.TargetPath }"],timeout=90)
        for ln in (o or '').splitlines():
            if ln.strip(): L('  lnk| '+ln.encode('ascii','replace').decode('ascii')[:150])
    # 4) winfr capabilities
    L('## winfr capabilities')
    exe=None
    c,o=run(['where','winfr'],timeout=15)
    for ln in (o or '').splitlines():
        ln=ln.strip()
        if ln.lower().endswith('winfr.exe') and os.path.isfile(ln): exe=ln; break
    if not exe:
        c,o=run(['powershell','-NoProfile','-Command','(Get-AppxPackage Microsoft.WindowsFileRecovery -ErrorAction SilentlyContinue).InstallLocation'],timeout=30)
        loc=(o or '').strip().splitlines()[-1].strip() if (o or '').strip() else ''
        if loc and os.path.isfile(os.path.join(loc,'winfr.exe')): exe=os.path.join(loc,'winfr.exe')
    L('  winfr_exe='+str(exe))
    if exe:
        c,o=run([exe,'/?'],timeout=30)
        L('  winfr /? rc='+str(c))
        for ln in (o or '').splitlines()[:70]:
            if ln.strip(): L('  help| '+ln.encode('ascii','replace').decode('ascii')[:150])
    # 5) misc
    L('## misc')
    for d in ('E:\\','D:\\'):
        try:
            L('  '+d+' top-level: '+', '.join(sorted(e.name for e in os.scandir(d))[:22]))
        except Exception: pass
    for env in ('OneDrive','OneDriveConsumer'):
        v=os.environ.get(env)
        if v: L('  '+env+'='+v)
    L('R327_DOC_RECON_COMPLETE=True')
    WT(REPORT,'\n'.join(lines)+'\n')
    WT(J,json.dumps(res,indent=2)+'\n')
except Exception:
    L('FATAL: '+traceback.format_exc())
    try: WT(REPORT,'\n'.join(lines)+'\n')
    except Exception: pass
sys.exit(0)
