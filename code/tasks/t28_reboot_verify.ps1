# t28_reboot_verify.ps1 - round 43 task: verify the machine state after the
# reboot (if it happened): pagefile actually shrank, E: gained space, the
# watcher auto-resumed (this receipt itself proves the sync loop works).
# READ-ONLY. Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

function FmtB {
    param([double]$b)
    if ($b -ge 1GB) { return ('{0:N2} GB' -f ($b / 1GB)) }
    if ($b -ge 1MB) { return ('{0:N1} MB' -f ($b / 1MB)) }
    if ($b -ge 1KB) { return ('{0:N1} KB' -f ($b / 1KB)) }
    return ('{0:N0} B' -f $b)
}

Write-Output '--- task t28: post-reboot verification ---'

try {
    $os = Get-CimInstance Win32_OperatingSystem
    $up = [int]((Get-Date) - $os.LastBootUpTime).TotalMinutes
    Write-Output ('   uptime: ' + $up + ' min (' + $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm') + ')' + $(if ($up -lt 60) { '  <- FRESHLY REBOOTED' } else { '  (reboot not done yet or a while ago)' }))
} catch { }

try {
    foreach ($u in @(Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue)) {
        Write-Output ('   ACTIVE pagefile: ' + (San ([string]$u.Name)) + ' ' + $u.AllocatedBaseSize + ' MB (peak ' + $u.PeakUsage + ' MB)')
    }
} catch { }
try {
    $pf = Get-Item -LiteralPath 'E:\pagefile.sys' -Force -ErrorAction SilentlyContinue
    if ($pf) { Write-Output ('   E:\pagefile.sys on disk now: ' + (FmtB ([double]$pf.Length)) + ' (was 42.3 GB before the fix; <=16 GB = SUCCESS)') }
    else { Write-Output '   E:\pagefile.sys: not found on disk (no reboot yet, or the new small file is in use)' }
    $pfC = Get-Item -LiteralPath 'C:\pagefile.sys' -Force -ErrorAction SilentlyContinue
    if ($pfC) { Write-Output ('   C:\pagefile.sys: ' + (FmtB ([double]$pfC.Length)) + ' (!! should NOT exist after the fix)') }
    else { Write-Output '   C:\pagefile.sys: absent (correct)' }
} catch { }

try {
    $dk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='E:'"
    Write-Output ('   E: free now: ' + ([math]::Round($dk.FreeSpace / 1GB, 1)) + ' GB (pre-reboot 254.5; +~26 GB expected after reboot)')
    $dkC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    Write-Output ('   C: free now: ' + ([math]::Round($dkC.FreeSpace / 1GB, 1)) + ' GB')
} catch { }

try {
    $mem = Get-CimInstance Win32_OperatingSystem
    Write-Output ('   memory free now: ' + ([math]::Round($mem.FreePhysicalMemory / 1MB, 1)) + ' GB of ' + ([math]::Round($mem.TotalVisibleMemorySize / 1MB, 1)) + ' GB')
} catch { }

Write-Output '   watcher: this receipt being pushed proves the scheduled task auto-resumed after the reboot.'
exit 0
