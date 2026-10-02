# t133_vpn_startup_verify.ps1 - round 176: verify Green VPN Startup
# folder autostart fallback. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function Write-Utf8([string]$Path, [string[]]$Lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null; [IO.File]::WriteAllText($Path, ($Lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }

$script:Lines = @()
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outRoot = Join-Path $repo 'results\ops_r176'
$reportPath = Join-Path $outRoot 'VPN_STARTUP_VERIFY.md'

L '--- task t133: Green VPN Startup-folder verification ---'
$target = 'E:\NsfocusVPN\NsfocusVPN.exe'
$helper = 'E:\NsfocusVPN\git-sync-start-green-vpn.cmd'
$startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
$startupCmd = Join-Path $startup 'GreenVPN-Autostart.cmd'
$startupLnk = Join-Path $startup 'GreenVPN-Autostart.lnk'

# Ensure helper exists even if the previous schtasks step failed.
try {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $helper) | Out-Null
    [IO.File]::WriteAllLines($helper, @('@echo off', 'start "" "E:\NsfocusVPN\NsfocusVPN.exe"'), (New-Object System.Text.ASCIIEncoding))
    New-Item -ItemType Directory -Force -Path $startup | Out-Null
    Copy-Item -LiteralPath $helper -Destination $startupCmd -Force
} catch { L ('write_WARN=' + (San $_.Exception.Message)) }

$targetOk = Test-Path -LiteralPath $target
$helperOk = Test-Path -LiteralPath $helper
$startupCmdOk = Test-Path -LiteralPath $startupCmd
$startupLnkOk = Test-Path -LiteralPath $startupLnk
L ('target_exists=' + $targetOk + ' ' + $target)
L ('helper_exists=' + $helperOk + ' ' + $helper)
L ('startup_cmd_exists=' + $startupCmdOk + ' ' + (San $startupCmd))
L ('startup_lnk_exists=' + $startupLnkOk + ' ' + (San $startupLnk))
if ($helperOk) {
    try { foreach ($ln in @(Get-Content -LiteralPath $helper -ErrorAction SilentlyContinue)) { L ('helper_line=' + (San $ln)) } } catch { }
}
if ($targetOk -and $helperOk -and ($startupCmdOk -or $startupLnkOk)) {
    L 'FINAL: VPN_STARTUP_OK Green VPN will be launched at user logon from Startup folder.'
    Write-Utf8 $reportPath $script:Lines
    exit 0
}
L 'FINAL: VPN_STARTUP_FAIL Startup fallback not fully installed.'
Write-Utf8 $reportPath $script:Lines
exit 2
