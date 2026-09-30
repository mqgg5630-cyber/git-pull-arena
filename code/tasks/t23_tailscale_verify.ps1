# t23_tailscale_verify.ps1 - round 39 task: prove the existing Tailscale
# tailnet actually carries traffic: fresh status + real pings to the ONLINE
# peers (desktop-ieudgs5 100.84.137.117, muse 100.109.207.34).
# READ-ONLY. Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

$tsExe = 'E:\Tailscale\tailscale.exe'
if (-not (Test-Path -LiteralPath $tsExe)) { Write-Output '   [FAIL] tailscale.exe not found'; exit 2 }

Write-Output '--- task t23: Tailscale connectivity proof ---'

$st = ''
try { $st = (& $tsExe status 2>&1 | Out-String) } catch { $st = 'ERR ' + (San $_.Exception.Message) }
foreach ($l in @($st -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 10)) { Write-Output ('   ' + (San ([string]$l))) }

Write-Output '--- ping desktop-ieudgs5 (100.84.137.117) ---'
$job = Start-Job -ScriptBlock { param($p) & $p ping 100.84.137.117 2>&1 | Out-String } -ArgumentList $tsExe
if (Wait-Job $job -Timeout 45) {
    $o = (Receive-Job $job | Out-String)
    foreach ($l in @($o -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 12)) { Write-Output ('   ' + (San ([string]$l))) }
} else { Write-Output '   TIMEOUT (45s) - desktop may be firewalled or offline' }
Remove-Job $job -Force -ErrorAction SilentlyContinue

Write-Output '--- ping muse (100.109.207.34) ---'
$job2 = Start-Job -ScriptBlock { param($p) & $p ping 100.109.207.34 2>&1 | Out-String } -ArgumentList $tsExe
if (Wait-Job $job2 -Timeout 45) {
    $o2 = (Receive-Job $job2 | Out-String)
    foreach ($l in @($o2 -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 12)) { Write-Output ('   ' + (San ([string]$l))) }
} else { Write-Output '   TIMEOUT (45s)' }
Remove-Job $job2 -Force -ErrorAction SilentlyContinue

Write-Output '--- notes for the user ---'
Write-Output '   this laptop   = 100.71.123.19 (laptop-r77m5d6m-1, online)'
Write-Output '   your desktop  = 100.84.137.117 (desktop-ieudgs5, online)'
Write-Output '   muse          = 100.109.207.34'
Write-Output '   old duplicate = 100.99.113.111 (laptop-r77m5d6m, offline 107d - remove it at'
Write-Output '                    https://login.tailscale.com admin console -> Machines)'
Write-Output '   from the desktop you can reach this laptop as \\100.71.123.19 or ssh user@100.71.123.19'
exit 0
