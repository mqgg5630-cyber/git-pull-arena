# t140_direct_node_payload_bridge.ps1 - round 183: write selected node
# payload directly to local private file and run Antigravity bridge. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir = Join-Path $repo 'results\antigravity'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
L '--- task t140: direct selected-node Antigravity bridge ---'
$privDir = Join-Path $env:USERPROFILE '.arena-private'
$subsFile = Join-Path $privDir 'v2ray_subs.txt'
New-Item -ItemType Directory -Force -Path $privDir | Out-Null
$payload = @'
vless://f56f179b-cc8d-41c8-8fea-e52adcccd456@217.116.170.32:443?security=tls&type=ws&host=sdldyh.us.ci&fp=chrome&sni=sdldyh.us.ci&path=%2Fproxyip%3DProxyIP.US.CMLiussss.Net&encryption=none#SG-01
vless://f56f179b-cc8d-41c8-8fea-e52adcccd456@109.176.19.174:443?security=tls&type=ws&host=sdldyh.us.ci&fp=chrome&sni=sdldyh.us.ci&path=%2Fproxyip%3DProxyIP.US.CMLiussss.Net&encryption=none#SG-02
vless://f56f179b-cc8d-41c8-8fea-e52adcccd456@161.118.210.121:443?security=tls&type=ws&host=sdldyh.us.ci&fp=chrome&sni=sdldyh.us.ci&path=%2Fproxyip%3DProxyIP.US.CMLiussss.Net&encryption=none#SG-03
vless://f56f179b-cc8d-41c8-8fea-e52adcccd456@139.180.143.248:8443?security=tls&type=ws&host=sdldyh.us.ci&fp=chrome&sni=sdldyh.us.ci&path=%2Fproxyip%3DProxyIP.US.CMLiussss.Net&encryption=none#SG-04
vless://f56f179b-cc8d-41c8-8fea-e52adcccd456@132.243.238.192:8443?security=tls&type=ws&host=sdldyh.us.ci&fp=chrome&sni=sdldyh.us.ci&path=%2Fproxyip%3DProxyIP.US.CMLiussss.Net&encryption=none#SG-05
vless://f56f179b-cc8d-41c8-8fea-e52adcccd456@8.219.116.94:443?security=tls&type=ws&host=sdldyh.us.ci&fp=chrome&sni=sdldyh.us.ci&path=%2Fproxyip%3DProxyIP.US.CMLiussss.Net&encryption=none#SG-06
vless://f56f179b-cc8d-41c8-8fea-e52adcccd456@50.7.21.174:443?security=tls&type=ws&host=sdldyh.us.ci&fp=chrome&sni=sdldyh.us.ci&path=%2Fproxyip%3DProxyIP.US.CMLiussss.Net&encryption=none#SG-07
vless://f56f179b-cc8d-41c8-8fea-e52adcccd456@45.127.34.59:8443?security=tls&type=ws&host=sdldyh.us.ci&fp=chrome&sni=sdldyh.us.ci&path=%2Fproxyip%3DProxyIP.US.CMLiussss.Net&encryption=none#SG-08
vless://f56f179b-cc8d-41c8-8fea-e52adcccd456@134.185.85.155:443?security=tls&type=ws&host=sdldyh.us.ci&fp=chrome&sni=sdldyh.us.ci&path=%2Fproxyip%3DProxyIP.US.CMLiussss.Net&encryption=none#SG-09
vless://f56f179b-cc8d-41c8-8fea-e52adcccd456@207.148.120.87:443?security=tls&type=ws&host=sdldyh.us.ci&fp=chrome&sni=sdldyh.us.ci&path=%2Fproxyip%3DProxyIP.US.CMLiussss.Net&encryption=none#SG-10
vless://f56f179b-cc8d-41c8-8fea-e52adcccd456@47.79.35.185:443?security=tls&type=ws&host=sdldyh.us.ci&fp=chrome&sni=sdldyh.us.ci&path=%2Fproxyip%3DProxyIP.US.CMLiussss.Net&encryption=none#JP-01
vless://f56f179b-cc8d-41c8-8fea-e52adcccd456@216.23.123.64:30718?security=tls&type=ws&host=sdldyh.us.ci&fp=chrome&sni=sdldyh.us.ci&path=%2Fproxyip%3DProxyIP.US.CMLiussss.Net&encryption=none#JP-02
vless://f56f179b-cc8d-41c8-8fea-e52adcccd456@103.53.80.239:443?security=tls&type=ws&host=sdldyh.us.ci&fp=chrome&sni=sdldyh.us.ci&path=%2Fproxyip%3DProxyIP.US.CMLiussss.Net&encryption=none#JP-03
vless://f56f179b-cc8d-41c8-8fea-e52adcccd456@142.91.109.150:443?security=tls&type=ws&host=sdldyh.us.ci&fp=chrome&sni=sdldyh.us.ci&path=%2Fproxyip%3DProxyIP.US.CMLiussss.Net&encryption=none#JP-04
vless://f56f179b-cc8d-41c8-8fea-e52adcccd456@139.180.196.14:443?security=tls&type=ws&host=sdldyh.us.ci&fp=chrome&sni=sdldyh.us.ci&path=%2Fproxyip%3DProxyIP.US.CMLiussss.Net&encryption=none#JP-05
'@
[IO.File]::WriteAllText($subsFile, $payload, (New-Object System.Text.UTF8Encoding($false)))
$cnt = @($payload -split "`r?`n" | Where-Object { $_ -match '^(vmess|vless|trojan|ss)://' }).Count
L ('private_payload_written=' + $cnt + ' node-lines')
$helper = Join-Path $repo 'code\tasks\v2rayn_antigravity_auto_bridge.ps1'
$report = Join-Path $outDir 'v2rayn_node_bridge_local_r183.md'
if (Test-Path -LiteralPath $helper) {
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $helper -OutPath $report -MaxNodes 30 -Apply -Relaunch
        L ('bridge_exit=' + $LASTEXITCODE)
    } catch { L ('bridge_THROW=' + (San $_.Exception.Message)) }
    if (Test-Path -LiteralPath $report) { foreach ($ln in @(Get-Content -LiteralPath $report -Tail 180 -ErrorAction SilentlyContinue)) { L ('bridge| ' + (San $ln)) } }
} else { L 'bridge_skipped=missing helper' }
L '--- task t140 done ---'
exit 0
