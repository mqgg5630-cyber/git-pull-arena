# t135_tun_route_and_vpn_delay.ps1 - round 178.
# 1) Re-check Antigravity with the user's TUN mode; use direct route if the
#    TUN egress is supported, otherwise use 10808 if supported.
# 2) Replace Green VPN startup helper with delayed launch to avoid post-UAC
#    first-launch hang. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir = Join-Path $repo 'results\antigravity'
$opsDir = Join-Path $repo 'results\ops_r178'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
New-Item -ItemType Directory -Force -Path $opsDir | Out-Null
L '--- task t135: TUN route fix + delayed VPN startup ---'

# ---------------- local Antigravity route check ----------------
$helper = Join-Path $repo 'code\tasks\agy_tun_mode_fix.ps1'
if (Test-Path -LiteralPath $helper) {
    $localOut = Join-Path $outDir 'agy_tun_mode_local_r178.md'
    L '--- local TUN/proxy check ---'
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $helper -OutPath $localOut -Relaunch
        L ('local_tun_exit=' + $LASTEXITCODE)
    } catch { L ('local_tun_THROW=' + (San $_.Exception.Message)) }
    if (Test-Path -LiteralPath $localOut) { foreach ($ln in @(Get-Content -LiteralPath $localOut -Tail 80 -ErrorAction SilentlyContinue)) { L ('local| ' + (San $ln)) } }
} else { L ('missing_helper=' + $helper) }

# ---------------- desktop Antigravity route check ----------------
L '--- desktop TUN/proxy check ---'
$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o','BatchMode=yes','-o','ConnectTimeout=15','-o','StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
try {
    $net = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
    L ('net_use=' + (San $net))
    if ($LASTEXITCODE -eq 0 -or $net -match 'success') {
        Copy-Item -LiteralPath $helper -Destination ($fshare + '\fig1_rebuild\agy_tun_mode_fix.ps1') -Force
        & net use $fshare /delete 2>&1 | Out-Null
        $remoteOut = 'F:\fig1_rebuild\agy_tun_mode_desktop_r178.md'
        $job = Start-Job -ScriptBlock {
            param($o,$u,$h,$outp)
            & ssh @o ($u + '@' + $h) ('powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\agy_tun_mode_fix.ps1 -OutPath ' + $outp + ' -Relaunch -InteractiveTask') 2>&1 | Out-String
        } -ArgumentList $sshBase,$duser,$desktop,$remoteOut
        if (Wait-Job $job -Timeout 420) {
            $rout = (Receive-Job $job | Out-String)
            foreach ($ln in ($rout -split "`r?`n")) { if ($ln.Trim()) { L ('desk| ' + (San $ln)) } }
        } else { Stop-Job $job -Force -ErrorAction SilentlyContinue; L 'desk_tun_TIMEOUT' }
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        $null = & net use $fshare /persistent:no 2>&1
        $src = $fshare + '\fig1_rebuild\agy_tun_mode_desktop_r178.md'
        $dst = Join-Path $outDir 'agy_tun_mode_desktop_r178.md'
        if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination $dst -Force; foreach ($ln in @(Get-Content -LiteralPath $dst -Tail 80 -ErrorAction SilentlyContinue)) { L ('desk_report| ' + (San $ln)) } }
        else { L 'desktop_tun_report_missing' }
        & net use $fshare /delete 2>&1 | Out-Null
    }
} catch { L ('desktop_tun_THROW=' + (San $_.Exception.Message)); try { & net use $fshare /delete 2>&1 | Out-Null } catch { } }

# ---------------- Green VPN delayed startup ----------------
L '--- Green VPN delayed startup helper ---'
$vpnLines = @()
function VL([string]$m) { $script:vpnLines += $m; L ('vpn| ' + $m) }
$target = 'E:\NsfocusVPN\NsfocusVPN.exe'
$helperCmd = 'E:\NsfocusVPN\git-sync-start-green-vpn-delayed.cmd'
$startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
$startupCmd = Join-Path $startup 'GreenVPN-Autostart.cmd'
if (Test-Path -LiteralPath $target) {
    $cmdLines = @(
        '@echo off',
        'timeout /t 45 /nobreak >nul',
        'taskkill /f /im NsfocusVPN.exe >nul 2>nul',
        'timeout /t 5 /nobreak >nul',
        'start "" "E:\NsfocusVPN\NsfocusVPN.exe"'
    )
    try {
        [IO.File]::WriteAllLines($helperCmd, $cmdLines, (New-Object System.Text.ASCIIEncoding))
        New-Item -ItemType Directory -Force -Path $startup | Out-Null
        Copy-Item -LiteralPath $helperCmd -Destination $startupCmd -Force
        VL ('target_exists=True ' + $target)
        VL ('delayed_helper=' + $helperCmd)
        VL ('startup_cmd=' + (San $startupCmd))
        VL 'FINAL: VPN_DELAYED_STARTUP_OK helper waits 45s, kills stale first launch, then starts VPN normally.'
    } catch { VL ('FINAL: VPN_DELAYED_STARTUP_FAIL ' + (San $_.Exception.Message)) }
} else { VL ('FINAL: VPN_DELAYED_STARTUP_FAIL target missing ' + $target) }
W (Join-Path $opsDir 'VPN_DELAYED_STARTUP.md') $vpnLines

L '--- task t135 done ---'
exit 0
