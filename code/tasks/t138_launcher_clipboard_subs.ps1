# t138_launcher_clipboard_subs.ps1 - round 181.
# Install a small Green VPN launcher/guardian and, if the user copied v2ray
# subscription URLs to clipboard, save them to a private local file and try the
# Antigravity bridge again. ASCII-only; secrets are never printed.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function WA([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllLines($p, $lines, (New-Object System.Text.ASCIIEncoding)) }

$script:Lines = @()
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir = Join-Path $repo 'results\ops_r181'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
L '--- task t138: Green VPN launcher + private v2ray subs bridge ---'

# ---------------- Green VPN launcher ----------------
$vpnDir = 'E:\NsfocusVPN'
$vpnExe = Join-Path $vpnDir 'NsfocusVPN.exe'
$launcherPs1 = Join-Path $vpnDir 'green-vpn-launcher.ps1'
$launcherCmd = Join-Path $vpnDir 'green-vpn-launcher.cmd'
$startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
$startupCmd = Join-Path $startup 'GreenVPN-Autostart.cmd'
$desktopLauncher = Join-Path ([Environment]::GetFolderPath('Desktop')) 'GreenVPN-Launcher.cmd'
$publicDesktopLauncher = 'C:\Users\Public\Desktop\GreenVPN-Launcher.cmd'

if (Test-Path -LiteralPath $vpnExe) {
    $ps = @'
param(
    [int]$DelaySec = 45,
    [switch]$KillBefore,
    [switch]$SecondKick,
    [int]$SecondKickSec = 120
)
$ErrorActionPreference = 'Continue'
$dir = Split-Path -Parent $PSCommandPath
$exe = Join-Path $dir 'NsfocusVPN.exe'
$log = Join-Path $dir 'green-vpn-launcher.log'
function Log([string]$m) {
    try { Add-Content -LiteralPath $log -Encoding UTF8 -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $m) } catch { }
}
Log 'launcher start'
if ($DelaySec -gt 0) { Log ('delay ' + $DelaySec + 's'); Start-Sleep -Seconds $DelaySec }
if ($KillBefore) {
    Log 'kill-before enabled'
    try { taskkill /f /im NsfocusVPN.exe 2>&1 | Out-Null } catch { }
    Start-Sleep -Seconds 5
}
if (-not (Test-Path -LiteralPath $exe)) { Log ('missing exe ' + $exe); exit 2 }
try {
    Log ('start ' + $exe)
    Start-Process -FilePath $exe -WorkingDirectory $dir
} catch {
    Log ('normal start failed: ' + $_.Exception.Message)
    try { Start-Process -FilePath $exe -WorkingDirectory $dir -Verb RunAs; Log 'runas issued' } catch { Log ('runas failed: ' + $_.Exception.Message) }
}
if ($SecondKick) {
    Log ('second-kick wait ' + $SecondKickSec + 's')
    Start-Sleep -Seconds $SecondKickSec
    $p = @(Get-Process -Name NsfocusVPN -ErrorAction SilentlyContinue)
    if ($p.Count -gt 0) {
        Log 'second-kick: process exists; leave it running (no blind kill)'
    } else {
        Log 'second-kick: not running, start again'
        try { Start-Process -FilePath $exe -WorkingDirectory $dir } catch { Log ('second start failed: ' + $_.Exception.Message) }
    }
}
Log 'launcher done'
'@ -split "`r?`n"
    try {
        W $launcherPs1 $ps
        WA $launcherCmd @('@echo off', 'powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "E:\NsfocusVPN\green-vpn-launcher.ps1" -DelaySec 0 -KillBefore -SecondKick')
        New-Item -ItemType Directory -Force -Path $startup | Out-Null
        WA $startupCmd @('@echo off', 'powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "E:\NsfocusVPN\green-vpn-launcher.ps1" -DelaySec 45 -KillBefore -SecondKick')
        WA $desktopLauncher @('@echo off', 'powershell -NoProfile -ExecutionPolicy Bypass -File "E:\NsfocusVPN\green-vpn-launcher.ps1" -DelaySec 0 -KillBefore -SecondKick')
        try { WA $publicDesktopLauncher @('@echo off', 'powershell -NoProfile -ExecutionPolicy Bypass -File "E:\NsfocusVPN\green-vpn-launcher.ps1" -DelaySec 0 -KillBefore -SecondKick') } catch { }
        L ('launcher_ps1=' + $launcherPs1)
        L ('launcher_cmd=' + $launcherCmd)
        L ('startup_cmd=' + (San $startupCmd))
        L ('desktop_launcher=' + (San $desktopLauncher))
        L 'FINAL_VPN_LAUNCHER: OK installed delayed Startup launcher and manual launcher.'
    } catch { L ('FINAL_VPN_LAUNCHER: FAIL ' + (San $_.Exception.Message)) }
} else { L ('FINAL_VPN_LAUNCHER: FAIL missing ' + $vpnExe) }

# ---------------- private v2ray subscription from clipboard ----------------
L '--- clipboard/private v2ray subscriptions ---'
$privDir = Join-Path $env:USERPROFILE '.arena-private'
$subsFile = Join-Path $privDir 'v2ray_subs.txt'
$urls = @()
try {
    if (Test-Path -LiteralPath $subsFile) {
        $urls += @(Get-Content -LiteralPath $subsFile -ErrorAction SilentlyContinue | Where-Object { $_ -match '^https?://' })
        L ('private_subs_existing=' + $urls.Count)
    }
} catch { }
if ($urls.Count -eq 0) {
    try {
        $clip = Get-Clipboard -Raw -ErrorAction SilentlyContinue
        if ($clip) { $urls += @([regex]::Matches($clip, 'https?://[^\s\)\]\}\>]+') | ForEach-Object { $_.Value.Trim() }) }
        $urls = @($urls | Where-Object { $_ -match '^https?://' } | Select-Object -Unique)
        if ($urls.Count -gt 0) {
            New-Item -ItemType Directory -Force -Path $privDir | Out-Null
            [IO.File]::WriteAllLines($subsFile, $urls, (New-Object System.Text.UTF8Encoding($false)))
            L ('clipboard_urls_saved=' + $urls.Count + ' file=' + (San $subsFile))
        } else { L 'clipboard_urls_saved=0' }
    } catch { L ('clipboard_read_WARN=' + (San $_.Exception.Message)) }
}

# Run bridge helper only when the private file exists. It prints no URLs.
$bridge = Join-Path $repo 'code\tasks\v2rayn_antigravity_auto_bridge.ps1'
$bridgeReport = Join-Path $repo 'results\antigravity\v2rayn_node_bridge_local_r181.md'
if ((Test-Path -LiteralPath $bridge) -and (Test-Path -LiteralPath $subsFile)) {
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $bridge -OutPath $bridgeReport -MaxNodes 80 -Apply -Relaunch
        L ('bridge_exit=' + $LASTEXITCODE)
    } catch { L ('bridge_THROW=' + (San $_.Exception.Message)) }
    if (Test-Path -LiteralPath $bridgeReport) {
        foreach ($ln in @(Get-Content -LiteralPath $bridgeReport -Tail 120 -ErrorAction SilentlyContinue)) { L ('bridge| ' + (San $ln)) }
    }
} else {
    L 'bridge_skipped=no private subscription file yet'
}

W (Join-Path $outDir 'GREEN_VPN_LAUNCHER_AND_SUBS.md') $script:Lines
L '--- task t138 done ---'
exit 0
