# t198_docking_path_probe_r259.ps1 - record exact Desktop result path for AMP docking.
# Runs on the real Windows machine. ASCII-only source; output may contain Unicode paths.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')
$repo = (Get-Location).Path
$outRoot = Join-Path $repo 'results\docking'
$probeReport = Join-Path $outRoot 'DESKTOP_RESULT_PATH_R259.md'
$mainReport = Join-Path $outRoot 'AMP_DOCKING_R255.md'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

function Escape-Unicode([string]$s) {
    if ($null -eq $s) { return '' }
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        $code = [int][char]$ch
        if ($code -ge 32 -and $code -le 126) {
            [void]$sb.Append($ch)
        } else {
            [void]$sb.Append(('\u{0:X4}' -f $code))
        }
    }
    return $sb.ToString()
}

$desktop = [Environment]::GetFolderPath('Desktop')
$latest = $null
try {
    $latest = Get-ChildItem -LiteralPath $desktop -Directory -Filter 'AMP_Docking_Vina_R255_*' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
} catch { }
$exists = $false
$path = ''
if ($latest) {
    $path = [string]$latest.FullName
    $exists = Test-Path -LiteralPath $path
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# AMP docking Desktop result path probe') | Out-Null
$lines.Add('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')) | Out-Null
$lines.Add('host=' + $env:COMPUTERNAME) | Out-Null
$lines.Add('desktop_root_raw=' + $desktop) | Out-Null
$lines.Add('desktop_root_escaped=' + (Escape-Unicode $desktop)) | Out-Null
$lines.Add('desktop_result_folder_raw=' + $path) | Out-Null
$lines.Add('desktop_result_folder_escaped=' + (Escape-Unicode $path)) | Out-Null
$lines.Add('DESKTOP_DOCKING_EXISTS=' + $exists) | Out-Null
$lines.Add('AMP_DOCKING_PATH_PROBE_DONE=True') | Out-Null
$lines | Set-Content -LiteralPath $probeReport -Encoding UTF8

try {
    Add-Content -LiteralPath $mainReport -Encoding UTF8 -Value ''
    Add-Content -LiteralPath $mainReport -Encoding UTF8 -Value '## Desktop result folder (unredacted probe)'
    Add-Content -LiteralPath $mainReport -Encoding UTF8 -Value ('desktop_result_folder_raw=' + $path)
    Add-Content -LiteralPath $mainReport -Encoding UTF8 -Value ('desktop_result_folder_escaped=' + (Escape-Unicode $path))
    Add-Content -LiteralPath $mainReport -Encoding UTF8 -Value ('DESKTOP_DOCKING_EXISTS=' + $exists)
} catch { }

Get-Content -LiteralPath $probeReport -Encoding UTF8
if ($exists) { exit 0 }
exit 7
