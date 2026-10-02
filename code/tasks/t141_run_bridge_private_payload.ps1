# t141_run_bridge_private_payload.ps1 - round 184: rerun Antigravity bridge
# against existing private payload, with captured output. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir = Join-Path $repo 'results\antigravity'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
L '--- task t141: rerun private payload bridge ---'
$subsFile = Join-Path $env:USERPROFILE '.arena-private\v2ray_subs.txt'
if (Test-Path -LiteralPath $subsFile) {
    $cnt = @(Get-Content -LiteralPath $subsFile -ErrorAction SilentlyContinue | Where-Object { $_ -match '^(vmess|vless|trojan|ss)://' }).Count
    L ('private_payload_exists=True node_lines=' + $cnt)
} else {
    L 'private_payload_exists=False'
}
$helper = Join-Path $repo 'code\tasks\v2rayn_antigravity_auto_bridge.ps1'
$report = Join-Path $outDir 'v2rayn_node_bridge_local_r184.md'
if (-not (Test-Path -LiteralPath $helper)) { L 'helper_missing'; exit 2 }
try {
    $out = (& $helper -OutPath $report -MaxNodes 30 -Apply -Relaunch 2>&1 | Out-String)
    $code = $LASTEXITCODE
    L ('helper_exit=' + $code)
    foreach ($ln in (($out -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -First 260)) { L ('helper| ' + (San $ln)) }
} catch { L ('helper_THROW=' + (San $_.Exception.Message)) }
if (Test-Path -LiteralPath $report) {
    foreach ($ln in @(Get-Content -LiteralPath $report -Tail 200 -ErrorAction SilentlyContinue)) { L ('report| ' + (San $ln)) }
} else { L 'report_missing' }
L '--- task t141 done ---'
exit 0
