# t282_disk_media_r331.py - round 331. Decide whether raw-sector carving is
# viable: if E: is an SSD with TRIM, freed blocks were wiped at deletion time
# and signature carving is hopeless; if HDD, most freed clusters survive and
# PhotoRec/DMDE has a real chance. Also: windowed-process list (find the WDR
# tool) and E: free-space re-check. Read-only, NO elevation, NO UAC.
import os, sys, time, subprocess, shutil, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R331_DISK_MEDIA.md'
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
def ps(cmd,timeout=40):
    return run(['powershell','-NoProfile','-Command',cmd],timeout=timeout)
def clean(o):
    return (o or '').replace('\r','')
L('# R331 disk media type + process check')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
try:
    c,o=ps('Get-PhysicalDisk | Select-Object DeviceId,Model,MediaType,BusType,@{n=\"SizeGB\";e={[math]::Round($_.Size/1GB)}} | Format-Table -AutoSize | Out-String -Width 200')
    L('-- Get-PhysicalDisk rc='+str(c))
    for ln in clean(o).splitlines():
        if ln.strip(): L('  pd| '+ln.encode('ascii','replace').decode('ascii')[:130])
    c,o=ps('Get-CimInstance Win32_DiskDrive | Select-Object Model,Index,@{n=\"SizeGB\";e={[math]::Round($_.Size/1GB)}},InterfaceType | Format-Table -AutoSize | Out-String -Width 200')
    L('-- Win32_DiskDrive rc='+str(c))
    for ln in clean(o).splitlines():
        if ln.strip(): L('  dd| '+ln.encode('ascii','replace').decode('ascii')[:130])
    c,o=ps('Get-CimInstance Win32_LogicalDiskToPartition | Select-Object Antecedent,Dependent | Format-List | Out-String -Width 250')
    L('-- letter->partition map rc='+str(c))
    for ln in clean(o).splitlines():
        if ln.strip(): L('  map| '+ln.encode('ascii','replace').decode('ascii')[:150])
    c,o=ps('Get-Process | Where-Object {$_.MainWindowTitle} | Select-Object ProcessName,MainWindowTitle | Format-Table -HideTableHeaders | Out-String -Width 200')
    L('-- windowed processes rc='+str(c))
    for ln in clean(o).splitlines():
        if ln.strip(): L('  win| '+ln.encode('ascii','replace').decode('ascii')[:120])
    du=shutil.disk_usage('E:\\')
    L('E: free now: '+str(du.free//1048576)+'MB / '+str(du.total//1048576)+'MB')
    wdr=Path(r'E:\WDR-20261006230705')
    if wdr.is_dir():
        n=sum(1 for e in os.scandir(str(wdr)) if e.is_file())
        L('WDR folder files now: '+str(n)+' (561 at 23:32)')
    L('R331_DISK_MEDIA_COMPLETE=True')
    WT(REPORT,'\n'.join(lines)+'\n')
except Exception:
    L('FATAL: '+traceback.format_exc())
    try: WT(REPORT,'\n'.join(lines)+'\n')
    except Exception: pass
sys.exit(0)
