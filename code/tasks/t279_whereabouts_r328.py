# t279_whereabouts_r328.py - round 328. r327 found leads; inspect them.
# 1) D:\DeskBoxLibrary census - may hold the original deskbox content;
# 2) quick census of E:\0docx, 0word, 0writing, 0md, 0github;
# 3) E:\WDR-20261006230705 full listing (appeared 23:07, unknown tool);
# 4) what survives of E:\0mcp-agv-arena-optimized\deskbox-v2 besides library;
# 5) D:\ root documents; 6) exact (unicode-escaped) desktop path and the
# D: recycle-bin $I original paths. Read-only, NO elevation, NO UAC.
import os, sys, time, struct, traceback, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R328_WHEREABOUTS.md'
lines=[]
def L(s):
    s=str(s).encode('ascii','replace').decode('ascii'); print(s,flush=True); lines.append(s)
def LX(s):
    # keep non-ascii as \uXXXX escapes so Chinese paths survive the receipt
    s=str(s).encode('unicode_escape').decode('ascii'); print(s,flush=True); lines.append(s)
def WT(p,t):
    Path(p).parent.mkdir(parents=True,exist_ok=True); Path(p).write_text(t,encoding='utf-8')
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
                        st=e.stat(follow_symlinks=False)
                        out.append((e.path,st.st_size,st.st_mtime))
                except Exception: pass
        except Exception: pass
    return out,tmo
def iso(m):
    try: return time.strftime('%Y-%m-%d %H:%M',time.localtime(m))
    except Exception: return '?'
def census(name,root,deadline=None,sample_exts=('.doc','.docx','.pdf','.xls','.xlsx','.ppt','.pptx'),nsamp=12,deep=True):
    if not os.path.isdir(root):
        L('## '+name+': (missing) '+root); return
    files,tmo=list_files(root,deadline=deadline)
    tot=sum(s for _,s,_ in files)
    exts={}
    for p,s,m in files:
        e=os.path.splitext(p)[1].lower(); exts[e]=exts.get(e,0)+1
    top=sorted(exts.items(),key=lambda x:-x[1])[:14]
    L('## '+name+': '+str(len(files))+' files, '+str(tot//1048576)+'MB'+(' (partial)' if tmo else ''))
    L('  ext: '+', '.join((e or '(none)')+':'+str(c) for e,c in top))
    try:
        ent=sorted(os.scandir(root),key=lambda x:x.name.lower())
        for e2 in ent[:25]:
            try:
                if e2.is_dir(follow_symlinks=False):
                    sub,st2,_=list_files(e2.path,deadline=deadline,cap=300000)
                    L('  DIR  '+e2.name[:60]+' -> '+str(len(sub))+' files '+str(sum(s for _,s,_ in sub)//1048576)+'MB')
                else:
                    L('  FILE '+e2.name[:60]+' '+str(e2.stat().st_size//1024)+'KB '+iso(e2.stat().st_mtime))
            except Exception: pass
    except Exception: pass
    docs=[f for f in files if os.path.splitext(f[0])[1].lower() in sample_exts]
    docs.sort(key=lambda x:-x[2])
    L('  -- '+str(len(docs))+' doc-type files, newest first (up to '+str(nsamp)+') --')
    for p,s,m in docs[:nsamp]:
        LX('   '+iso(m)+' | '+str(s//1024)+'KB | '+p)
    return files
L('# R328 document whereabouts - targeted inspection')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
try:
    deadline=time.time()+700
    # 1) DeskBoxLibrary
    census('D:\\DeskBoxLibrary',r'D:\DeskBoxLibrary',deadline=deadline)
    # 2) E: doc-ish dirs
    for d in ('0docx','0word','0writing','0md','0github'):
        census('E:\\'+d,os.path.join('E:\\',d),deadline=deadline,nsamp=8)
    # 3) WDR folder
    census('E:\\WDR-20261006230705',r'E:\WDR-20261006230705',deadline=deadline,nsamp=25)
    # 4) deskbox-v2 remains
    census('E:\\0mcp-agv-arena-optimized\\deskbox-v2',r'E:\0mcp-agv-arena-optimized\deskbox-v2',deadline=deadline,nsamp=8)
    # 5) D: root docs (depth 0 only)
    L('## D:\\ root documents')
    try:
        for e2 in sorted(os.scandir('D:\\'),key=lambda x:x.name.lower()):
            if os.path.splitext(e2.name)[1].lower() in ('.doc','.docx','.pdf','.xls','.xlsx','.ppt','.pptx'):
                try: LX('   '+iso(e2.stat().st_mtime)+' | '+str(e2.stat().st_size//1024)+'KB | '+e2.path)
                except Exception: pass
    except Exception: pass
    # 6) exact desktop path + D: bin $I original paths (unicode-escaped)
    L('## exact paths')
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
    LX('desktop='+str(desktop))
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
    binroot=r'D:\$Recycle.Bin'
    for p,s,m in (list_files(binroot,cap=100000)[0] if os.path.isdir(binroot) else []):
        if os.path.basename(p).upper().startswith('$I'):
            try:
                r=parse_i(open(p,'rb').read())
                if r: LX('  D-bin $I | ver='+str(r[0])+' | '+str(r[1]//1024)+'KB | deleted-unix='+str(int(r[2]))+' | orig='+r[3])
            except Exception: pass
    L('R328_WHEREABOUTS_COMPLETE=True')
    WT(REPORT,'\n'.join(lines)+'\n')
except Exception:
    L('FATAL: '+traceback.format_exc())
    try: WT(REPORT,'\n'.join(lines)+'\n')
    except Exception: pass
sys.exit(0)
