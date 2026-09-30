# t26_pagefile_fix_uac.ps1 - round 41 task: fix the pagefile setting.
# Round 40 verification showed: automatic management OFF (good), but the
# only pagefile setting is now "C:\pagefile.sys 0/0" (system-managed on C:)
# - Windows created that when auto-manage was disabled, and the E: 8-16 GB
# setting from round 38 did not stick. If left like this, the reboot would
# put a RAM-sized pagefile on C: (only 47.9 GB free) instead of E:.
# This task pops ONE more UAC to run an elevated fix that:
#   1. removes the C: pagefile setting
#   2. sets E:\pagefile.sys to initial 8192 MB / max 16384 MB
#   3. writes the before/after state to E:\pagefile_fix_result.txt
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t26: pagefile fix (UAC) ---'

$resultFile = 'E:\pagefile_fix_result.txt'
if (Test-Path -LiteralPath $resultFile) { Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue }

$helper = 'E:\pagefile_fix_admin.ps1'
$body = @'
# elevated: pagefile = E: only, fixed 8-16 GB
$ErrorActionPreference = 'Continue'
$lines = @()
$lines += ('BEFORE auto-managed: ' + (Get-CimInstance Win32_ComputerSystem).AutomaticManagedPagefile)
foreach ($p in @(Get-CimInstance Win32_PageFileSetting)) { $lines += ('BEFORE setting: ' + $p.Name + ' ' + $p.InitialSize + '/' + $p.MaximumSize + ' MB') }
# 1. disable auto management (keep it off)
$cs = Get-CimInstance Win32_ComputerSystem
if ($cs.AutomaticManagedPagefile) { $cs | Set-CimInstance -Property @{ AutomaticManagedPagefile = $false } }
# 2. remove the C: setting
foreach ($p in @(Get-CimInstance Win32_PageFileSetting | Where-Object { ([string]$_.Name) -like 'C:*' })) {
    try { $p | Remove-CimInstance -ErrorAction Stop; $lines += ('removed C: setting: ' + $p.Name) } catch { $lines += ('C: remove failed: ' + $_.Exception.Message) }
}
# 3. set E: 8192/16384 (update or create)
$pf = @(Get-CimInstance Win32_PageFileSetting | Where-Object { ([string]$_.Name) -like 'E:*' })
if ($pf.Count -gt 0) {
    $pf[0] | Set-CimInstance -Property @{ InitialSize = 8192; MaximumSize = 16384 }
    $lines += 'updated E: setting to 8192/16384 MB'
} else {
    try {
        New-CimInstance -ClassName Win32_PageFileSetting -Property @{ Name = 'E:\pagefile.sys'; InitialSize = 8192; MaximumSize = 16384 } | Out-Null
        $lines += 'created E: setting 8192/16384 MB'
    } catch { $lines += ('E: create failed: ' + $_.Exception.Message) }
}
Start-Sleep -Seconds 2
$lines += ('AFTER auto-managed: ' + (Get-CimInstance Win32_ComputerSystem).AutomaticManagedPagefile)
foreach ($p in @(Get-CimInstance Win32_PageFileSetting)) { $lines += ('AFTER setting: ' + $p.Name + ' ' + $p.InitialSize + '/' + $p.MaximumSize + ' MB') }
$lines += 'REBOOT to apply. E: keeps a 16 GB pagefile; C: gets none.'
[System.IO.File]::WriteAllText('E:\pagefile_fix_result.txt', ($lines -join "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
'@
try {
    [System.IO.File]::WriteAllText($helper, $body, (New-Object System.Text.UTF8Encoding($true)))
    Write-Output ('   helper written: ' + $helper)
} catch {
    Write-Output ('   [FAIL] ' + (San $_.Exception.Message))
    exit 2
}

Write-Output '   popping the UAC dialog - CLICK YES ...'
$ok = $false
try {
    $p = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Window', 'Hidden', '-File', $helper) -PassThru
    $ok = $true
    Write-Output ('   elevated process started (pid ' + $p.Id + ')')
} catch {
    Write-Output ('   [WARN] elevation declined/failed: ' + (San $_.Exception.Message))
}

if ($ok) {
    $found = $false
    for ($i = 0; $i -lt 15; $i++) {
        Start-Sleep -Seconds 2
        if (Test-Path -LiteralPath $resultFile) { $found = $true; break }
    }
    if ($found) {
        Write-Output '   --- elevated result ---'
        foreach ($ln in @(Get-Content -LiteralPath $resultFile -ErrorAction SilentlyContinue)) { Write-Output ('   ' + (San ([string]$ln))) }
        Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue
    } else {
        Write-Output '   [WARN] no result file - the fix may have failed; check manually'
    }
    Remove-Item -LiteralPath $helper -Force -ErrorAction SilentlyContinue
}

# non-elevated verify
try {
    $am = [string](Get-CimInstance Win32_ComputerSystem).AutomaticManagedPagefile
    $pfv = @(Get-CimInstance Win32_PageFileSetting)
    Write-Output ('   verify: auto-managed=' + $am + ' ; settings: ' + $pfv.Count)
    foreach ($p in $pfv) { Write-Output ('      ' + (San ([string]$p.Name)) + ' ' + $p.InitialSize + '/' + $p.MaximumSize + ' MB') }
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }
exit 0
