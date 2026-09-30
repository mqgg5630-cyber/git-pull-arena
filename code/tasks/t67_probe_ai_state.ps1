# t67_probe_ai_state.ps1 - round 81 task: probe the stuck Illustrator after
# the fig1 draw (48/48 batches done). Enumerate its top-level windows (modal
# script-alert dialogs?), check Responding, run a 60s bridge probe, and if a
# dialog is found try to dismiss it with WM_CLOSE, then re-probe.
# Does NOT kill Illustrator; resumable state preserved. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }

Write-Output '--- task t67: probe stuck Illustrator state ---'

$aiProcs = @(Get-Process -Name Illustrator -ErrorAction SilentlyContinue)
if ($aiProcs.Count -lt 1) { Write-Output '   [FAIL] Illustrator not running'; exit 2 }
foreach ($p in $aiProcs) {
    Write-Output ('   pid=' + $p.Id + ' responding=' + $p.Responding + ' cpu=' + [int]$p.CPU + 's threads=' + $p.Threads.Count + ' title=[' + (San $p.MainWindowTitle) + ']')
}

# ------------------------------------------------ enumerate AI windows
$src = @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class CsWinEnum {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern int GetWindowTextW(IntPtr hWnd, [MarshalAs(UnmanagedType.LPWStr)] StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern int GetClassNameW(IntPtr hWnd, [MarshalAs(UnmanagedType.LPWStr)] StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr PostMessageW(IntPtr hWnd, uint msg, IntPtr wp, IntPtr lp);
    public static List<string> WindowsOf(uint targetPid) {
        List<string> lines = new List<string>();
        EnumWindows(delegate(IntPtr h, IntPtr l) {
            uint pid; GetWindowThreadProcessId(h, out pid);
            if (pid == targetPid && IsWindowVisible(h)) {
                StringBuilder t = new StringBuilder(256); GetWindowTextW(h, t, 256);
                StringBuilder c = new StringBuilder(256); GetClassNameW(h, c, 256);
                if (t.Length > 0 || c.Length > 0) lines.Add(h.ToInt64() + "|" + c.ToString() + "|" + t.ToString());
            }
            return true;
        }, IntPtr.Zero);
        return lines;
    }
    public static bool CloseWindowByHandle(long handle) {
        return PostMessageW(new IntPtr(handle), 0x0010, IntPtr.Zero, IntPtr.Zero);
    }
}
'@
try { Add-Type -TypeDefinition $src } catch { Write-Output ('   [WARN] Add-Type: ' + (San $_.Exception.Message)) }

$aiExe = $null
foreach ($d in @(Get-ChildItem -Path 'E:\' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Illustrator' })) {
    $cand = Join-Path $d.FullName 'Support Files\Contents\Windows\Illustrator.exe'
    if (Test-Path -LiteralPath $cand) { $aiExe = $cand; break }
}
if (-not $aiExe) { Write-Output '   [FAIL] no Illustrator.exe'; exit 2 }

function Probe-Bridge([string]$expr, [int]$seconds) {
    $dir = 'E:\fig1_rebuild\probe'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $id = [guid]::NewGuid().ToString('N')
    $sf = Join-Path $dir ("p_$id.jsx")
    $rf = Join-Path $dir ("p_$id.result")
    $rfJs = ($rf -replace '\\', '/')
    $jsx = 'var CELL_LCT_RET = String(' + $expr + ');' + "`r`n" + "(function(){try{var w=new File('$rfJs');w.encoding='UTF-8';w.open('w');w.write(String(CELL_LCT_RET));w.close();}catch(e){}})();"
    [IO.File]::WriteAllText($sf, $jsx, (New-Object System.Text.UTF8Encoding($false)))
    Start-Process -FilePath $aiExe -ArgumentList @(('"' + $sf + '"'))
    $deadline = [DateTime]::UtcNow.AddSeconds($seconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 400
        if (Test-Path -LiteralPath $rf) {
            Start-Sleep -Milliseconds 200
            $txt = [string]([IO.File]::ReadAllText($rf))
            Remove-Item -LiteralPath $rf, $sf -Force -ErrorAction SilentlyContinue
            return $txt
        }
    }
    return 'PROBE_TIMEOUT'
}

$targetPid = [uint32]$aiProcs[0].Id
try {
    $wins = [CsWinEnum]::WindowsOf($targetPid)
    Write-Output ('   visible top-level windows: ' + $wins.Count)
    $dialogHandles = @()
    foreach ($w in $wins) {
        Write-Output ('   win| ' + (San $w))
        $parts = $w -split '\|', 3
        if ($parts.Count -eq 3 -and $parts[1] -match '^(#32770|UXWindow|Illustrator)' ) { $dialogHandles += [long]$parts[0] }
    }
    # dismiss classic modal dialogs (#32770 = standard dialog class)
    $closed = 0
    foreach ($h in $dialogHandles) {
        try { [void][CsWinEnum]::CloseWindowByHandle($h); $closed++ } catch { }
    }
    if ($closed -gt 0) {
        Write-Output ('   sent WM_CLOSE to ' + $closed + ' dialog(s); waiting 3s')
        Start-Sleep -Seconds 3
    } else { Write-Output '   no classic modal dialog found to close' }
} catch { Write-Output ('   [WARN] window enum: ' + (San $_.Exception.Message)) }

# ------------------------------------------------ probe 1
$r = Probe-Bridge 'app.documents.length' 60
Write-Output ('   probe docs.length: ' + (San $r))

# if timed out, re-list windows (maybe dialog appeared during probe) and retry once
if ($r -eq 'PROBE_TIMEOUT') {
    try {
        $wins2 = [CsWinEnum]::WindowsOf($targetPid)
        foreach ($w in $wins2) { Write-Output ('   win2| ' + (San $w)) }
    } catch { }
    $r2 = Probe-Bridge 'app.documents.length' 60
    Write-Output ('   probe retry docs.length: ' + (San $r2))
}

# leftover bridge scripts in temp (evidence of lost/queued calls)
$bridgeTemp = Join-Path ([IO.Path]::GetTempPath()) 'cs_ai_bridge'
if (Test-Path -LiteralPath $bridgeTemp) {
    $jsx = @(Get-ChildItem -LiteralPath $bridgeTemp -Filter '*.jsx' -ErrorAction SilentlyContinue)
    $res = @(Get-ChildItem -LiteralPath $bridgeTemp -Filter '*.result' -ErrorAction SilentlyContinue)
    Write-Output ('   temp bridge leftovers: ' + $jsx.Count + ' jsx, ' + $res.Count + ' result')
}

# document state via probe (only if bridge alive)
if ($r -ne 'PROBE_TIMEOUT') {
    Write-Output ('   probe activeDoc: ' + (San (Probe-Bridge 'app.activeDocument.name' 45)))
    Write-Output ('   probe rootGroup: ' + (San (Probe-Bridge '(function(){var n=0;try{for(var d=0;d<app.documents.length;d++){var doc=app.documents[d];for(var i=0;i<doc.groupItems.length;i++){if(doc.groupItems[i].name.indexOf("CELL_LCT_CACHE")===0){n++;}}}return "rootgroups="+n;}catch(e){return "ERR:"+e.message;}})()' 60)))
}
Write-Output '--- task t67 ok (probe only, nothing killed) ---'
exit 0
