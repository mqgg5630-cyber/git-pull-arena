# watcher.ps1 - runs ON THE DESKTOP in the INTERACTIVE session (started by
# the integrun cmd file). Polls every 1.5s for visible top-level windows
# owned by POWERPNT processes; logs every new window class/title (so we can
# SEE which dialog PowerPoint shows) and closes any standard Win32 modal
# dialog (class #32770, e.g. safe-mode prompt / first-run prompts) that
# would block COM automation with RPC_E_CALL_REJECTED.
# Usage: powershell -File watcher.ps1 <logfile> <maxSeconds>
# ASCII-only.

param([string]$LogFile = 'F:\fig1_rebuild\cpe\watcher.txt', [int]$MaxSec = 300)

$ErrorActionPreference = 'Continue'

$cs = '
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class PW {
    public delegate bool CB(IntPtr h, IntPtr lp);
    [DllImport("user32.dll")] public static extern bool EnumWindows(CB cb, IntPtr lp);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    public static List<string> Scan(uint[] pids) {
        List<string> r = new List<string>();
        EnumWindows(delegate(IntPtr h, IntPtr lp) {
            uint pid;
            GetWindowThreadProcessId(h, out pid);
            for (int i = 0; i < pids.Length; i++) {
                if (pids[i] == pid && IsWindowVisible(h)) {
                    StringBuilder c = new StringBuilder(256);
                    StringBuilder t = new StringBuilder(256);
                    GetClassName(h, c, 256);
                    GetWindowText(h, t, 256);
                    if (c.Length == 0 && t.Length == 0) { return true; }
                    r.Add(h.ToInt64().ToString() + "|" + c.ToString() + "|" + t.ToString());
                    break;
                }
            }
            return true;
        }, IntPtr.Zero);
        return r;
    }
    public static bool CloseDialog(long h) {
        return PostMessage(new IntPtr(h), 0x0010U, IntPtr.Zero, IntPtr.Zero);
    }
}
'
try { Add-Type -TypeDefinition $cs -ErrorAction Stop } catch { }

function WL([string]$m) {
    try { Add-Content -LiteralPath $LogFile -Value ((Get-Date -Format 'HH:mm:ss') + ' ' + $m) } catch { }
}

WL ('watcher start pid=' + $PID + ' max=' + $MaxSec + 's')
$deadline = (Get-Date).AddSeconds($MaxSec)
$known = @{}
$scanOk = $true
if (-not ('PW' -as [type])) { WL 'watcher: Add-Type failed, cannot scan'; $scanOk = $false }

while ($scanOk -and ((Get-Date) -lt $deadline)) {
    Start-Sleep -Milliseconds 1500
    $procs = @(Get-Process -Name POWERPNT -ErrorAction SilentlyContinue)
    if ($procs.Count -eq 0) { continue }
    $ids = [uint32[]]@($procs | ForEach-Object { [uint32]$_.Id })
    $wins = @()
    try { $wins = @([PW]::Scan($ids)) } catch { WL ('watcher: scan error: ' + (($_.Exception.Message) -replace '[^\x20-\x7E]', '?')); break }
    foreach ($w in $wins) {
        $parts = @($w -split '\|', 3)
        if ($parts.Count -lt 3) { continue }
        $hwndS = [string]$parts[0]
        $cls = [string]$parts[1]
        $title = [string]$parts[2]
        $key = $cls + ' :: ' + $title
        if (-not $known.ContainsKey($key)) {
            $known[$key] = $true
            WL ('window: [' + $cls + '] ' + $title)
        }
        if ($cls -eq '#32770') {
            WL ('closing dialog: [' + $cls + '] ' + $title)
            $null = [PW]::CloseDialog([long]$hwndS)
        }
    }
}
WL 'watcher end'
