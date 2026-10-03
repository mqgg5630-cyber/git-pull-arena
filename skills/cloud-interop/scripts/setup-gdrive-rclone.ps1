# setup-gdrive-rclone.ps1
# Installs rclone from the official GitHub release, verifies SHA256SUMS,
# and starts Google Drive OAuth for a named remote. ASCII-only by design.

[CmdletBinding()]
param(
    [string]$RemoteName = 'gdrive_main',
    [string]$AccountEmail = '',
    [ValidateSet('drive','drive.readonly','drive.file')]
    [string]$Scope = 'drive',
    [string]$InstallDir = "$env:LOCALAPPDATA\Programs\rclone",
    [switch]$InstallOnly,
    [switch]$NoInstall
)

$ErrorActionPreference = 'Stop'

function Say($m) { Write-Output $m }
function Fail($m) { Write-Error $m; exit 1 }
function Get-RcloneExe {
    param([string]$Dir)
    $local = Join-Path $Dir 'rclone.exe'
    if (Test-Path -LiteralPath $local) { return $local }
    $cmd = Get-Command rclone -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd -and $cmd.Source) { return [string]$cmd.Source }
    return ''
}
function Download($Url, $Out) {
    $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
    if (Test-Path -LiteralPath $curl) {
        & $curl -L --ssl-no-revoke --retry 3 --connect-timeout 20 --max-time 900 -o $Out $Url
        if ($LASTEXITCODE -ne 0) { Fail "download failed: $Url" }
    } else {
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Out
    }
}
function Ensure-Rclone {
    param([string]$Dir)
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    $existing = Get-RcloneExe $Dir
    if ($existing) {
        Say "rclone_existing=$existing"
        return $existing
    }

    $api = 'https://api.github.com/repos/rclone/rclone/releases/latest'
    Say "release_api=$api"
    $release = Invoke-RestMethod -Uri $api -UseBasicParsing
    $tag = [string]$release.tag_name
    if (-not $tag) { Fail 'could not resolve latest rclone tag' }
    $assetName = 'rclone-' + $tag + '-windows-amd64.zip'
    $asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
    $sumAsset = $release.assets | Where-Object { $_.name -eq 'SHA256SUMS' } | Select-Object -First 1
    if (-not $asset) { Fail "missing release asset $assetName" }
    if (-not $sumAsset) { Fail 'missing SHA256SUMS asset' }

    $dlDir = Join-Path $env:LOCALAPPDATA 'ArenaTools\downloads'
    New-Item -ItemType Directory -Force -Path $dlDir | Out-Null
    $zip = Join-Path $dlDir $assetName
    $sums = Join-Path $dlDir ('rclone-' + $tag + '-SHA256SUMS')
    Say "download_zip=$($asset.browser_download_url)"
    Download ([string]$asset.browser_download_url) $zip
    Say "download_sums=$($sumAsset.browser_download_url)"
    Download ([string]$sumAsset.browser_download_url) $sums

    $sumText = Get-Content -LiteralPath $sums -Raw -Encoding UTF8
    $expected = ''
    foreach ($line in ($sumText -split "`r?`n")) {
        if ($line -match [regex]::Escape($assetName)) {
            $expected = (($line.Trim() -split '\s+')[0]).ToLowerInvariant()
            break
        }
    }
    if (-not $expected) { Fail "no checksum line for $assetName" }
    $actual = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    Say "rclone_zip_sha256=$actual"
    if ($actual -ne $expected) { Fail 'rclone checksum mismatch' }

    $extract = Join-Path $dlDir ('extract-' + $tag)
    if (Test-Path -LiteralPath $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $extract | Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
    $exe = Get-ChildItem -LiteralPath $extract -Recurse -Filter rclone.exe | Select-Object -First 1
    if (-not $exe) { Fail 'rclone.exe missing after extraction' }
    Copy-Item -LiteralPath $exe.FullName -Destination (Join-Path $Dir 'rclone.exe') -Force

    $userPath = [Environment]::GetEnvironmentVariable('Path','User')
    if (($userPath -split ';') -notcontains $Dir) {
        [Environment]::SetEnvironmentVariable('Path', (($userPath.TrimEnd(';') + ';' + $Dir).Trim(';')), 'User')
        Say "user_path_added=$Dir"
    }
    return (Join-Path $Dir 'rclone.exe')
}

if ($RemoteName -match ':') { Fail 'RemoteName should not contain colon' }

$rclone = ''
if ($NoInstall) {
    $rclone = Get-RcloneExe $InstallDir
    if (-not $rclone) { Fail 'rclone not found; remove -NoInstall to install it' }
} else {
    $rclone = Ensure-Rclone $InstallDir
}

Say "rclone=$rclone"
& $rclone version | Select-Object -First 4 | ForEach-Object { Say ('rclone_version| ' + $_) }

if ($InstallOnly) {
    Say 'install_only=True'
    exit 0
}

$remotes = @(& $rclone listremotes 2>$null)
$remoteWithColon = $RemoteName + ':'
$hasRemote = $false
foreach ($r in $remotes) { if ($r.Trim() -eq $remoteWithColon) { $hasRemote = $true } }

if (-not $hasRemote) {
    Say "remote_create=$RemoteName"
    if ($AccountEmail) { Say "account_hint=$AccountEmail" }
    Say 'oauth_action=browser_will_open_choose_the_requested_google_account'
    & $rclone config create $RemoteName drive scope $Scope
    if ($LASTEXITCODE -ne 0) { Fail 'rclone config create failed' }
}

Say 'oauth_reconnect_start=True'
Say 'If a browser opens, sign in locally and approve. Do not paste tokens into chat.'
& $rclone config reconnect $remoteWithColon
if ($LASTEXITCODE -ne 0) {
    Say 'oauth_reconnect_warn=nonzero_exit; remote may already be connected or user cancelled'
}

Say 'verify_about_start=True'
& $rclone about $remoteWithColon
if ($LASTEXITCODE -ne 0) { Fail 'rclone about failed; Google Drive remote is not ready yet' }
Say 'GDRIVE_RCLONE_READY=True'
Say "remote=$remoteWithColon"
exit 0
