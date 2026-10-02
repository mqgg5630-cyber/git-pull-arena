# t139_ephemeral_sub_bridge.ps1 - round 182: fetch a one-time subscription
# payload from the sandbox secret bridge into the local private file, then run
# the Antigravity xray bridge. ASCII-only; payload is not printed.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir = Join-Path $repo 'results\antigravity'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
L '--- task t139: ephemeral subscription payload bridge ---'
$payloadUrl = 'https://8765-i487sgcvn8gcs2yvc478w.e2b.app/payload/9WFq6PfmWGsO88FRLpf69heeIOjXt8Wu'
$privDir = Join-Path $env:USERPROFILE '.arena-private'
$subsFile = Join-Path $privDir 'v2ray_subs.txt'
New-Item -ItemType Directory -Force -Path $privDir | Out-Null
try {
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if (-not $curl) { throw 'curl.exe missing' }
    $tmp = Join-Path $privDir 'v2ray_subs.tmp'
    $o = (& curl.exe -fL --max-time 60 -sS $payloadUrl -o $tmp 2>&1 | Out-String).Trim()
    $code = $LASTEXITCODE
    L ('payload_fetch_exit=' + $code + ' out=' + (San $o))
    if ($code -eq 0 -and (Test-Path -LiteralPath $tmp)) {
        Move-Item -LiteralPath $tmp -Destination $subsFile -Force
        $lines = @(Get-Content -LiteralPath $subsFile -ErrorAction SilentlyContinue | Where-Object { $_ -match '^(vmess|vless|trojan|ss)://' }).Count
        L ('private_payload_written=' + $lines + ' node-lines')
    }
} catch { L ('payload_fetch_FAIL=' + (San $_.Exception.Message)) }

$helper = Join-Path $repo 'code\tasks\v2rayn_antigravity_auto_bridge.ps1'
$report = Join-Path $outDir 'v2rayn_node_bridge_local_r182.md'
if ((Test-Path -LiteralPath $helper) -and (Test-Path -LiteralPath $subsFile)) {
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $helper -OutPath $report -MaxNodes 60 -Apply -Relaunch
        L ('bridge_exit=' + $LASTEXITCODE)
    } catch { L ('bridge_THROW=' + (San $_.Exception.Message)) }
    if (Test-Path -LiteralPath $report) { foreach ($ln in @(Get-Content -LiteralPath $report -Tail 160 -ErrorAction SilentlyContinue)) { L ('bridge| ' + (San $ln)) } }
} else { L 'bridge_skipped=missing helper or private payload' }
L '--- task t139 done ---'
exit 0
