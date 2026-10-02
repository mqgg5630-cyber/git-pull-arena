# t144_parse_diag_bridge.ps1 - round 187: parser diagnostics plus bridge.
# ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir = Join-Path $repo 'results\antigravity'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
L '--- task t144: parse diagnostics Antigravity bridge ---'
$subsFile = Join-Path $env:USERPROFILE '.arena-private\v2ray_subs.txt'
if (Test-Path -LiteralPath $subsFile) {
    $lines = @(Get-Content -LiteralPath $subsFile -ErrorAction SilentlyContinue | Where-Object { $_ -match '^(vmess|vless|trojan|ss)://' })
    L ('private_payload_exists=True node_lines=' + $lines.Count)
    $i=0
    foreach($line in ($lines | Select-Object -First 8)){
        $i++
        $scheme = (($line -split '://',2)[0])
        $hasAt = [bool]($line -match '@')
        $hasQ = [bool]($line -match '\?')
        $hasHash = [bool]($line -match '#')
        $simple = [regex]::IsMatch($line, '^(vless|trojan)://[^@]+@[^:/?#]+:\d+')
        L ('line_diag_' + $i + ' scheme=' + $scheme + ' len=' + $line.Length + ' at=' + $hasAt + ' q=' + $hasQ + ' hash=' + $hasHash + ' simpleAuthority=' + $simple)
    }
} else { L 'private_payload_exists=False' }
$helper = Join-Path $repo 'code\tasks\v2rayn_antigravity_auto_bridge.ps1'
$report = Join-Path $outDir 'v2rayn_node_bridge_local_r187.md'
try {
    $out = (& $helper -OutPath $report -MaxNodes 30 -Apply -Relaunch 2>&1 | Out-String)
    L ('helper_exit=' + $LASTEXITCODE)
    foreach ($ln in (($out -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -First 700)) { L ('helper| ' + (San $ln)) }
} catch { L ('helper_THROW=' + (San $_.Exception.Message)) }
if (Test-Path -LiteralPath $report) {
    foreach ($ln in @(Get-Content -LiteralPath $report -Tail 420 -ErrorAction SilentlyContinue)) { L ('report| ' + (San $ln)) }
} else { L 'report_missing' }
L '--- task t144 done ---'
exit 0
