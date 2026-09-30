# t20_docker_pagefile.ps1 - round 37 task: the two system-level items the
# user approved:
#   1. docker builder prune -a  (10 GB build cache, 0% in use)
#   2. shrink the E: page file from 36 GB to a 8-16 GB fixed size
#      (needs admin; if this check is not elevated it writes
#      E:\pagefile_shrink_admin.ps1 for a right-click admin run + reboot)
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t20: docker builder prune + pagefile shrink ---'

# ---------------------------------------------------- 1. docker builder
$dockerExe = 'E:\Docker\DockerDesktop\resources\bin\docker.exe'
if (-not (Test-Path -LiteralPath $dockerExe)) {
    $c = Get-Command docker -ErrorAction SilentlyContinue
    if ($c) { $dockerExe = [string]$c.Source }
}
if (Test-Path -LiteralPath $dockerExe) {
    Write-Output '--- docker builder prune -a -f ---'
    $job = Start-Job -ScriptBlock { param($p) & $p builder prune -a -f 2>&1 | Out-String } -ArgumentList $dockerExe
    if (Wait-Job $job -Timeout 600) {
        $o = (Receive-Job $job | Out-String)
        foreach ($l in @($o -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -Last 6)) { Write-Output ('   ' + (San ([string]$l))) }
        Write-Output '   OK: builder prune finished'
    } else {
        Write-Output '   [WARN] builder prune TIMEOUT (600s) - is the engine up?'
    }
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    # report the after state
    $job2 = Start-Job -ScriptBlock { param($p) & $p system df 2>&1 | Out-String } -ArgumentList $dockerExe
    if (Wait-Job $job2 -Timeout 60) {
        $o2 = (Receive-Job $job2 | Out-String)
        foreach ($l in @($o2 -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 6)) { Write-Output ('   ' + (San ([string]$l))) }
    }
    Remove-Job $job2 -Force -ErrorAction SilentlyContinue
} else {
    Write-Output '   [WARN] docker CLI not found - skipped'
}

# ---------------------------------------------------- 2. pagefile shrink
Write-Output '--- pagefile: current state ---'
try {
    foreach ($pf in @(Get-CimInstance Win32_PageFileUsage -ErrorAction Stop)) {
        Write-Output ('   pagefile: ' + (San ([string]$pf.Name)) + '  size ' + $pf.AllocatedBaseSize + ' MB (peak usage ' + $pf.PeakUsage + ' MB)')
    }
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    Write-Output ('   automatic managed pagefile: ' + $cs.AutomaticManagedPagefile)
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }

$isAdmin = $false
try { $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch { }
Write-Output ('   this check runs elevated: ' + $isAdmin)

$sizeInit = 8192
$sizeMax = 16384
if ($isAdmin) {
    Write-Output '--- applying the shrink (admin available) ---'
    try {
        $cs2 = Get-CimInstance Win32_ComputerSystem
        if ($cs2.AutomaticManagedPagefile) {
            $cs2 | Set-CimInstance -Property @{ AutomaticManagedPagefile = $false }
            Write-Output '   automatic management disabled'
        }
        $pf2 = @(Get-CimInstance Win32_PageFileSetting | Where-Object { ([string]$_.Name) -like 'E:*' })
        if ($pf2.Count -gt 0) {
            $pf2[0] | Set-CimInstance -Property @{ InitialSize = $sizeInit; MaximumSize = $sizeMax }
            Write-Output ('   SET: E:\pagefile.sys -> initial ' + $sizeInit + ' MB / max ' + $sizeMax + ' MB (reboot applies it, ~20 GB back)')
        } else {
            New-CimInstance -ClassName Win32_PageFileSetting -Property @{ Name = 'E:\pagefile.sys'; InitialSize = $sizeInit; MaximumSize = $sizeMax }
            Write-Output ('   CREATED setting: E:\pagefile.sys -> initial ' + $sizeInit + ' MB / max ' + $sizeMax + ' MB (reboot applies it)')
        }
        Write-Output '   NOTE: a REBOOT is required for the new size to take effect.'
    } catch {
        Write-Output ('   [FAIL] ' + (San $_.Exception.Message))
    }
} else {
    Write-Output '--- not elevated: writing the one-click admin script ---'
    $helper = 'E:\pagefile_shrink_admin.ps1'
    $body = @'
# Run this as Administrator, then REBOOT. It shrinks E:\pagefile.sys to 8-16 GB.
# Undo: System Properties > Advanced > Performance > Virtual Memory > automatic.
$ErrorActionPreference = 'Stop'
$cs = Get-CimInstance Win32_ComputerSystem
if ($cs.AutomaticManagedPagefile) {
    $cs | Set-CimInstance -Property @{ AutomaticManagedPagefile = $false }
    Write-Host 'automatic pagefile management disabled'
}
$pf = @(Get-CimInstance Win32_PageFileSetting | Where-Object { ([string]$_.Name) -like 'E:*' })
if ($pf.Count -gt 0) {
    $pf[0] | Set-CimInstance -Property @{ InitialSize = 8192; MaximumSize = 16384 }
} else {
    New-CimInstance -ClassName Win32_PageFileSetting -Property @{ Name = 'E:\pagefile.sys'; InitialSize = 8192; MaximumSize = 16384 }
}
Write-Host 'E:\pagefile.sys set to 8192-16384 MB. REBOOT to apply (about 20 GB back on E:).'
Read-Host 'press Enter to close'
'@
    try {
        [System.IO.File]::WriteAllText($helper, $body, (New-Object System.Text.UTF8Encoding($true)))
        Write-Output ('   WROTE: ' + $helper)
        Write-Output '   HOW: right-click it -> Run with PowerShell (as Administrator) -> reboot.'
        Write-Output '         (or in an admin PowerShell: powershell -ExecutionPolicy Bypass -File E:\pagefile_shrink_admin.ps1)'
    } catch {
        Write-Output ('   [WARN] could not write the helper: ' + (San $_.Exception.Message))
    }
}
exit 0
