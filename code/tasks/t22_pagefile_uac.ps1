# t22_pagefile_uac.ps1 - round 38 task: apply the pagefile shrink WITHOUT
# needing a right-click menu: pop the standard UAC consent dialog on the
# user's screen (they click Yes), which runs E:\pagefile_shrink_admin.ps1
# elevated. Then this task re-reads the pagefile settings to verify.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t22: pagefile shrink via UAC prompt ---'

$helper = 'E:\pagefile_shrink_admin.ps1'
if (-not (Test-Path -LiteralPath $helper)) {
    Write-Output ('   [FAIL] helper missing: ' + $helper)
    exit 2
}

# current state
$before = ''
try { $before = [string](Get-CimInstance Win32_ComputerSystem).AutomaticManagedPagefile } catch { }
Write-Output ('   automatic managed now: ' + $before)

Write-Output '   popping the UAC dialog - CLICK YES on the screen (waits up to 120s) ...'
$ok = $false
try {
    $p = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $helper) -PassThru
    $ok = $true
    Write-Output ('   elevated process started (pid ' + $p.Id + ')')
} catch {
    Write-Output ('   [WARN] elevation declined or failed: ' + (San $_.Exception.Message))
}

if ($ok) {
    # give the elevated script a moment, then verify the settings changed
    Start-Sleep -Seconds 8
    try {
        $am = [string](Get-CimInstance Win32_ComputerSystem).AutomaticManagedPagefile
        Write-Output ('   automatic managed now: ' + $am)
        $pf = @(Get-CimInstance Win32_PageFileSetting | Where-Object { ([string]$_.Name) -like 'E:*' })
        if ($pf.Count -gt 0) {
            Write-Output ('   E:\pagefile.sys setting: initial ' + $pf[0].InitialSize + ' MB / max ' + $pf[0].MaximumSize + ' MB')
            if ($am -eq 'False' -and $pf[0].MaximumSize -le 16384) {
                Write-Output '== APPLIED: reboot now and E: gains ~25 GB (file shrinks from 42 GB to <=16 GB)'
                exit 0
            }
        } else {
            Write-Output '   E: pagefile setting not visible yet (the elevated window may still be open - press Enter in it)'
        }
    } catch { Write-Output ('   [WARN] verify: ' + (San $_.Exception.Message)) }
} else {
    Write-Output '   manual way instead: open PowerShell as admin (Win+X -> Terminal(Admin)) and run:'
    Write-Output ('     powershell -ExecutionPolicy Bypass -File ' + $helper)
}
exit 0
