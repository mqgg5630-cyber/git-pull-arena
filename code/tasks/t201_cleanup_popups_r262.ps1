$ErrorActionPreference = "Continue"
Write-Output "== cleanup: close popup dialogs and stop stray watchers =="
Write-Output "HOST=$env:COMPUTERNAME"

# repo this watcher belongs to (the task runs inside the repo working dir)
$keepRepo = (Get-Location).Path
Write-Output "KEEP_REPO=$keepRepo"

# ancestors of this process must never be killed (they include the live watcher)
$keepPids = @()
$p = Get-CimInstance Win32_Process -Filter "ProcessId=$PID"
while ($p) {
    $keepPids += [int]$p.ProcessId
    if (-not $p.ParentProcessId) { break }
    $p = Get-CimInstance Win32_Process -Filter ("ProcessId={0}" -f $p.ParentProcessId) -ErrorAction SilentlyContinue
}
Write-Output ("KEEP_PIDS=" + ($keepPids -join ","))

# 1) stray watcher processes (watch.ps1 / sync.ps1) that are not our chain
$killedWatchers = 0
Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" | ForEach-Object {
    $cl = [string]$_.CommandLine
    if ($cl -match 'watch\.ps1|sync\.ps1') {
        if ($keepPids -notcontains [int]$_.ProcessId) {
            Write-Output ("STRAY_WATCHER pid={0} cmd={1}" -f $_.ProcessId, ($cl -replace '\s+',' '))
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            $killedWatchers++
        }
    }
}
Write-Output "STRAY_WATCHERS_KILLED=$killedWatchers"

# 2) close popup / message-box windows (dialog class #32770) and error reporters
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class W {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, IntPtr l, uint f, uint t, out IntPtr r);
}
"@
$closed = 0
$cb = [W+EnumProc]{
    param($h, $l)
    if ([W]::IsWindowVisible($h)) {
        $c = New-Object System.Text.StringBuilder 256
        [void][W]::GetClassName($h, $c, 256)
        $t = New-Object System.Text.StringBuilder 512
        [void][W]::GetWindowText($h, $t, 512)
        $cls = $c.ToString(); $title = $t.ToString()
        if ($cls -eq '#32770') {
            Write-Output ("POPUP_CLOSED class={0} title={1}" -f $cls, $title)
            $r = [IntPtr]::Zero
            [void][W]::SendMessageTimeout($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero, 2, 1500, [ref]$r)
            $script:closed++
        }
    }
    return $true
}
[void][W]::EnumWindows($cb, [IntPtr]::Zero)
Write-Output "POPUPS_CLOSED=$closed"

# 3) kill known nagging dialog hosts
$killedHosts = 0
foreach ($n in @('WerFault','WerFaultSecure','DW20','dwwin','msiexec_dialog')) {
    Get-Process -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output ("DIALOG_HOST_KILLED name={0} pid={1}" -f $_.ProcessName, $_.Id)
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        $killedHosts++
    }
}
Write-Output "DIALOG_HOSTS_KILLED=$killedHosts"

# 4) report remaining watcher scheduled tasks so only ours stays armed
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match 'git|sync|watch|arena' } | ForEach-Object {
    $info = $_ | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue
    Write-Output ("TASK name={0} state={1} lastRun={2}" -f $_.TaskName, $_.State, $info.LastRunTime)
}

Write-Output "CLEANUP_OK=True"
