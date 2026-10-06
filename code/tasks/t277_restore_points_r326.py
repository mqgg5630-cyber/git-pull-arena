# t277_restore_points_r326.py - round 326. Read-only, NON-ELEVATED census of
# restore/backup mechanisms: system restore points, shadow copies, File
# History, Windows Backup. Question: does anything exist that could bring the
# deleted E: library back? No changes, NO elevation, NO UAC.
import os, sys, time, subprocess, traceback, winreg
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'results'/'mcp_agv_lab'; OUT.mkdir(parents=True,exist_ok=True)
REPORT=OUT/'R326_RESTORE_POINTS.md'
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
def clean(o,cap=320):
    return (o or '').strip().replace('\r','').replace('\n',' | ')[:cap]
L('# R326 restore-point / backup census (read-only, non-elevated)')
L('time='+time.strftime('%Y-%m-%d %H:%M:%S'))
try:
    # 1) restore points via cmdlet
    c,o=ps('Get-ComputerRestorePoint -ErrorAction Continue | Select-Object SequenceNumber,CreationTime,Description | Format-List')
    L('get_computerrestorepoint rc='+str(c)+' out='+clean(o))
    # 2) WMI SystemRestore
    c,o=ps('Get-CimInstance -Namespace root/default -ClassName SystemRestore -ErrorAction Continue | Select-Object SequenceNumber,CreationTime,Description | Format-List')
    L('wmi_systemrestore rc='+str(c)+' out='+clean(o))
    # 3) SystemRestoreConfig (enabled scopes)
    c,o=ps('Get-CimInstance -Namespace root/default -ClassName SystemRestoreConfig -ErrorAction Continue | Format-List')
    L('wmi_systemrestoreconfig rc='+str(c)+' out='+clean(o))
    # 4) vssadmin attempt (expected: needs elevation)
    c,o=run(['vssadmin','list','shadows'],timeout=30)
    L('vssadmin rc='+str(c)+' out='+clean(o))
    # 5) registry state
    for keyname in (r'SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore', r'SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore'):
        try:
            k=winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE,keyname)
            i=0; vals=[]
            while True:
                try:
                    n,v,t=winreg.EnumValue(k,i); vals.append(n+'='+str(v)); i+=1
                except OSError: break
            winreg.CloseKey(k)
            L('reg '+keyname+': '+(('; '.join(vals))[:300] if vals else '(no values)'))
        except Exception as ex:
            L('reg '+keyname+': '+repr(ex)[:90])
    # 6) File History
    c,o=ps('Get-Service FhSvc -ErrorAction SilentlyContinue | Select-Object Status,StartType | Format-List')
    L('fhsvc rc='+str(c)+' out='+clean(o,200))
    fhcfg=Path(os.environ.get('LOCALAPPDATA',''))/'Microsoft'/'Windows'/'FileHistory'/'Configuration'
    L('filehistory_config_exists='+str(fhcfg.exists()))
    # 7) Windows Backup engine
    c,o=ps('Get-Service wbengine -ErrorAction SilentlyContinue | Select-Object Status,StartType | Format-List')
    L('wbengine rc='+str(c)+' out='+clean(o,200))
    # 8) disks for context
    c,o=ps('Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID,DriveType,Size,FreeSpace | Format-Table -HideTableHeaders')
    L('disks: '+clean(o,400))
    L('R326_RESTORE_CENSUS_COMPLETE=True')
    WT(REPORT,'\n'.join(lines)+'\n')
except Exception:
    L('FATAL: '+traceback.format_exc())
    try: WT(REPORT,'\n'.join(lines)+'\n')
    except Exception: pass
sys.exit(0)
