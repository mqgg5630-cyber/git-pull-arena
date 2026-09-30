# t27_pagefile_registry.ps1 - round 42 task: the WMI pagefile setting keeps
# vanishing from Win32_PageFileSetting (rounds 38/41 both created it, then
# queries show 0). The GROUND TRUTH is the registry value PagingFiles under
# HKLM\...\Session Manager\Memory Management (REG_MULTI_SZ). This task:
#   1. reads that registry value (no admin needed to READ)
#   2. reads the active pagefiles (Win32_PageFileUsage)
#   3. if PagingFiles is not exactly "E:\pagefile.sys 8192 16384", pops ONE
#      UAC and writes the registry value directly (the classic method)
#   4. re-reads and prints the final truth
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t27: pagefile ground truth (registry) ---'
$mmKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
$want = 'E:\pagefile.sys 8192 16384'

function Get-PagingFiles {
    try {
        $v = (Get-ItemProperty -Path $mmKey -Name PagingFiles -ErrorAction Stop).PagingFiles
        return @($v)
    } catch { return @() }
}

$pf0 = Get-PagingFiles
Write-Output ('   PagingFiles now: ' + $pf0.Count + ' entr(ies)')
foreach ($e in $pf0) { Write-Output ('      "' + (San ([string]$e)) + '"') }
try {
    foreach ($u in @(Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue)) {
        Write-Output ('   ACTIVE pagefile: ' + (San ([string]$u.Name)) + ' ' + $u.AllocatedBaseSize + ' MB (until reboot)')
    }
} catch { }

$good = $false
if ($pf0.Count -eq 1 -and ([string]$pf0[0]) -eq $want) { $good = $true }

if ($good) {
    Write-Output '   == CORRECT already: E:\pagefile.sys fixed at 8192-16384 MB. Just REBOOT to apply (~26 GB back on E:, none on C:).'
    exit 0
}

Write-Output ('   NOT correct yet - popping the UAC dialog to write "' + $want + '" directly ...')
$resultFile = 'E:\pagefile_reg_result.txt'
if (Test-Path -LiteralPath $resultFile) { Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue }
$helper = 'E:\pagefile_reg_admin.ps1'
$body = @'
# elevated: write PagingFiles directly (the reliable way)
$lines = @()
try {
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name PagingFiles -Value @('E:\pagefile.sys 8192 16384') -Type MultiString -ErrorAction Stop
    $lines += 'PagingFiles written: E:\pagefile.sys 8192 16384'
} catch { $lines += ('write failed: ' + $_.Exception.Message) }
Start-Sleep -Seconds 1
$v = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name PagingFiles).PagingFiles
foreach ($e in @($v)) { $lines += ('verify: "' + $e + '"') }
[System.IO.File]::WriteAllText('E:\pagefile_reg_result.txt', ($lines -join "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
'@
try {
    [System.IO.File]::WriteAllText($helper, $body, (New-Object System.Text.UTF8Encoding($true)))
} catch { Write-Output ('   [FAIL] ' + (San $_.Exception.Message)); exit 2 }

$ok = $false
try {
    $p = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Window', 'Hidden', '-File', $helper) -PassThru
    $ok = $true
    Write-Output ('   elevated process started (pid ' + $p.Id + ') - CLICK YES on the screen')
} catch { Write-Output ('   [WARN] elevation declined: ' + (San $_.Exception.Message)) }

if ($ok) {
    $found = $false
    for ($i = 0; $i -lt 15; $i++) {
        Start-Sleep -Seconds 2
        if (Test-Path -LiteralPath $resultFile) { $found = $true; break }
    }
    if ($found) {
        foreach ($ln in @(Get-Content -LiteralPath $resultFile -ErrorAction SilentlyContinue)) { Write-Output ('   ' + (San ([string]$ln))) }
        Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue
    } else { Write-Output '   [WARN] no result file' }
    Remove-Item -LiteralPath $helper -Force -ErrorAction SilentlyContinue
}

$pf2 = Get-PagingFiles
Write-Output ('   final PagingFiles: ' + $pf2.Count + ' entr(ies)')
foreach ($e in $pf2) { Write-Output ('      "' + (San ([string]$e)) + '"') }
if ($pf2.Count -eq 1 -and ([string]$pf2[0]) -eq $want) {
    Write-Output '   == FIXED: E:\pagefile.sys 8192-16384 MB. REBOOT to apply (~26 GB back on E:, nothing on C:).'
} else {
    Write-Output '   [WARN] still not right - will need the System Properties GUI route next'
}
exit 0
