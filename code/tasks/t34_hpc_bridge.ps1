# t34_hpc_bridge.ps1 - round 46 task: make this laptop a Tailscale subnet
# router for the HPC host only (10.10.5.210/32). Uses `tailscale set` so no
# other preference is touched. Nothing actually flows until the user approves
# the route in the admin console. Reversible: tailscale set --advertise-routes=
# (empty). If the CLI needs elevation -> ONE UAC popup.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t34: advertise HPC route 10.10.5.210/32 via Tailscale ---'
$tsExe = 'E:\Tailscale\tailscale.exe'
if (-not (Test-Path -LiteralPath $tsExe)) { Write-Output '   [FAIL] tailscale.exe not found'; exit 2 }

# sanity: VPN still up?
try {
    $rt = route print -4 | Select-String '^\s*10\.10\.5\.210'
    Write-Output ('   VPN route check: ' + $(if ($rt) { '10.10.5.210/32 route present (VPN connected)' } else { 'no 10.10.5.210 route - VPN disconnected (route can still be advertised)' }))
} catch { }

# try without elevation first
$done = $false
$err = ''
try {
    $out = (& $tsExe set --advertise-routes=10.10.5.210/32 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -eq 0) { $done = $true; Write-Output '   tailscale set: OK (no elevation needed)' }
    else { $err = $out }
} catch { $err = (San $_.Exception.Message) }

if (-not $done) {
    Write-Output ('   non-elevated attempt: ' + $err + ' -> retrying elevated (UAC) ...')
    $helper = 'E:\tsroute_admin.ps1'
    $resultFile = 'E:\tsroute_result.txt'
    if (Test-Path -LiteralPath $resultFile) { Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue }
    $body = @'
$ErrorActionPreference = 'Continue'
$r = (& 'E:\Tailscale\tailscale.exe' set --advertise-routes=10.10.5.210/32 2>&1 | Out-String).Trim()
[System.IO.File]::WriteAllText('E:\tsroute_result.txt', ('exit=' + $LASTEXITCODE + ' out=' + $r), (New-Object System.Text.UTF8Encoding($false)))
'@
    [System.IO.File]::WriteAllText($helper, $body, (New-Object System.Text.UTF8Encoding($true)))
    try {
        $p = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Window', 'Hidden', '-File', $helper) -PassThru
        Write-Output ('   UAC popped (pid ' + $p.Id + ') - CLICK YES ...')
        for ($i = 0; $i -lt 40; $i++) {
            Start-Sleep -Seconds 2
            if (Test-Path -LiteralPath $resultFile) { $done = $true; break }
        }
        if ($done) {
            $txt = (Get-Content -LiteralPath $resultFile -Raw -ErrorAction SilentlyContinue)
            Write-Output ('   elevated result: ' + (San ([string]$txt)))
            Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue
        } else { Write-Output '   [WARN] no elevated result within 80s' }
        Remove-Item -LiteralPath $helper -Force -ErrorAction SilentlyContinue
    } catch { Write-Output ('   [WARN] elevation declined: ' + (San $_.Exception.Message)) }
}

# verify prefs + status regardless
try {
    $pref = (& $tsExe debug prefs 2>$null | Out-String)
    foreach ($ln in @($pref -split "`r?`n")) { if ($ln -match 'AdvertiseRoutes') { Write-Output ('   ' + (San ($ln.Trim()))) } }
} catch { }
try {
    $st = (& $tsExe status 2>&1 | Out-String)
    foreach ($ln in @($st -split "`r?`n" | Select-Object -First 8)) { if ($ln -match '\S') { Write-Output ('   ' + (San ([string]$ln))) } }
} catch { }

Write-Output '--- NEXT (user steps) ---'
Write-Output '   1. phone/any browser: https://login.tailscale.com/admin/machines'
Write-Output '      -> LAPTOP-R77M5D6M -> ... menu -> Edit route settings'
Write-Output '      -> tick 10.10.5.210/32 -> Save   (route approval is what turns it on)'
Write-Output '   2. from the home desktop test:  ssh 25wenshaohua@10.10.5.210'
Write-Output '   (undo anytime: tailscale set --advertise-routes=  with empty value, or untick in console)'
exit 0
