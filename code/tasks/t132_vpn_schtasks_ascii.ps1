# t132_vpn_schtasks_ascii.ps1 - round 175: force Green VPN autostart
# through an ASCII helper cmd plus schtasks verification. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function Write-Utf8([string]$Path, [string[]]$Lines) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    [IO.File]::WriteAllText($Path, ($Lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
}

$script:Lines = @()
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outRoot = Join-Path $repo 'results\ops_r175'
$reportPath = Join-Path $outRoot 'VPN_AUTOSTART_SCHTASKS.md'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

L '--- task t132: Green VPN schtasks ASCII autostart ---'
$target = 'E:\NsfocusVPN\NsfocusVPN.exe'
if (-not (Test-Path -LiteralPath $target)) {
    L ('target_missing=' + $target)
    L 'FINAL: VPN_SCHTASKS_FAIL target exe missing'
    Write-Utf8 $reportPath $script:Lines
    exit 2
}
L ('target=' + $target)
$helper = 'E:\NsfocusVPN\git-sync-start-green-vpn.cmd'
$cmdLines = @('@echo off', 'start "" "E:\NsfocusVPN\NsfocusVPN.exe"')
try {
    [IO.File]::WriteAllLines($helper, $cmdLines, (New-Object System.Text.ASCIIEncoding))
    L ('helper_written=' + $helper)
} catch {
    L ('helper_write_FAIL=' + (San $_.Exception.Message))
    Write-Utf8 $reportPath $script:Lines
    exit 2
}

# Startup-folder fallback using ASCII helper cmd. Path may contain a non-ASCII
# username, but Explorer handles it; schtasks uses the ASCII helper path below.
try {
    $startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
    New-Item -ItemType Directory -Force -Path $startup | Out-Null
    $startupCmd = Join-Path $startup 'GreenVPN-Autostart.cmd'
    Copy-Item -LiteralPath $helper -Destination $startupCmd -Force
    L ('startup_cmd=' + (San $startupCmd) + ' exists=' + (Test-Path -LiteralPath $startupCmd))
} catch { L ('startup_cmd_WARN=' + (San $_.Exception.Message)) }

$taskName = 'git-sync-autostart-green-vpn'
$createOk = $false
try {
    $null = & schtasks /Delete /TN $taskName /F 2>$null
    $out = (& schtasks /Create /TN $taskName /SC ONLOGON /TR $helper /F 2>&1 | Out-String).Trim()
    $code = $LASTEXITCODE
    L ('schtasks_create_exit=' + $code + ' out=' + (San $out))
    if ($code -eq 0) { $createOk = $true }
} catch { L ('schtasks_create_THROW=' + (San $_.Exception.Message)) }

$queryOk = $false
try {
    $q = (& schtasks /Query /TN $taskName /FO LIST /V 2>&1 | Out-String).Trim()
    $qCode = $LASTEXITCODE
    L ('schtasks_query_exit=' + $qCode)
    foreach ($ln in (($q -split "`r?`n") | Where-Object { $_ -match 'TaskName|Task To Run|Status|Logon Mode|Author' } | Select-Object -First 12)) {
        L ('   query| ' + (San $ln))
    }
    if ($qCode -eq 0 -and $q -match [regex]::Escape($helper)) { $queryOk = $true }
} catch { L ('schtasks_query_THROW=' + (San $_.Exception.Message)) }

# Also try the ScheduledTasks API query, but do not require it because the
# schtasks.exe query is the source of truth for Task Scheduler registration.
try {
    $t = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
    L ('GetScheduledTask_state=' + $t.State)
} catch { L ('GetScheduledTask_WARN=' + (San $_.Exception.Message)) }

if ($createOk -and $queryOk) {
    L 'FINAL: VPN_SCHTASKS_OK at-logon task points to ASCII helper cmd; startup fallback also installed.'
    Write-Utf8 $reportPath $script:Lines
    exit 0
}
L ('FINAL: VPN_SCHTASKS_PARTIAL createOk=' + $createOk + ' queryOk=' + $queryOk)
Write-Utf8 $reportPath $script:Lines
if ($createOk) { exit 0 } else { exit 2 }
