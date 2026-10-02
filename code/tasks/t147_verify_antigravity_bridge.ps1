# t147_verify_antigravity_bridge.ps1 - round 190: verify applied Antigravity bridge.
# ASCII-only. Prints no node secrets.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function Write-Utf8([string]$Path, [string[]]$Lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null; [IO.File]::WriteAllText($Path, ($Lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function Invoke-Curl([string[]]$CurlArgs) { try { $ce = Join-Path $env:SystemRoot 'System32\curl.exe'; return (& $ce @CurlArgs 2>&1 | Out-String).Trim() } catch { return $_.Exception.Message } }
function Wait-Port([int]$port, [int]$sec) {
    $deadline = (Get-Date).AddSeconds($sec)
    while ((Get-Date) -lt $deadline) {
        try { $c = New-Object Net.Sockets.TcpClient; $iar = $c.BeginConnect('127.0.0.1', $port, $null, $null); if ($iar.AsyncWaitHandle.WaitOne(400)) { $c.EndConnect($iar); $c.Close(); return $true }; $c.Close() } catch { }
        Start-Sleep -Milliseconds 300
    }
    return $false
}

$script:Lines=@()
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir = Join-Path $repo 'results\antigravity'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report = Join-Path $outDir 'antigravity_bridge_verify_r190.md'
L '# Antigravity bridge verify'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
$listen = Wait-Port 18088 8
L ('bridge_port_18088_listen=' + $listen)
$xps = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^xray\.exe$|^v2ray\.exe$' })
L ('xray_processes=' + $xps.Count)
foreach($p in ($xps | Select-Object -First 6)) { L ('xray_proc=' + (San ([string]$p.ExecutablePath)) + ' pid=' + $p.ProcessId) }
$proxy = 'http://127.0.0.1:18088'
if ($listen) {
    $geoTxt = Invoke-Curl -CurlArgs @('-L','--max-time','15','-sS','--proxy',$proxy,'https://ipinfo.io/json')
    $cc=''; $country=''; $ip=''; $org=''
    try { $o=$geoTxt|ConvertFrom-Json; $cc=[string]$o.country; $country=[string]$o.country; $ip=[string]$o.ip; $org=[string]$o.org } catch { L ('geo_parse_WARN=' + (San $_.Exception.Message)) }
    L ('bridge_geo_country=' + $country + ' ip=' + (San $ip) + ' org=' + (San $org))
    $api = Invoke-Curl -CurlArgs @('-i','-L','--max-time','20','-sS','--proxy',$proxy,'https://daily-cloudcode-pa.googleapis.com/')
    $status = (($api -split "`r?`n") | Where-Object { $_ -match '^HTTP/' } | Select-Object -Last 1)
    $unsupported = [bool]($api -match 'User location is not supported|FAILED_PRECONDITION')
    L ('daily_cloudcode_status=' + (San $status))
    L ('daily_cloudcode_location_block_text_present=' + $unsupported)
} else {
    L 'bridge_probe_skipped=port_not_listening'
}
foreach($scope in @('Process','User','Machine')){
    foreach($k in @('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY')){
        try { L ('env_' + $scope + '_' + $k + '=' + (San ([Environment]::GetEnvironmentVariable($k,$scope)))) } catch { }
    }
}
foreach($root in @((Join-Path $env:APPDATA 'Antigravity\User'),(Join-Path $env:APPDATA 'Antigravity IDE\User'))){
    $sp=Join-Path $root 'settings.json'
    if(Test-Path $sp){ $txt=Get-Content -LiteralPath $sp -Raw -ErrorAction SilentlyContinue; L ('settings_proxy_present=' + $sp + ' -> ' + [bool]($txt -match '127\.0\.0\.1:18088')) } else { L ('settings_missing=' + $sp) }
}
$agy = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^Antigravity\.exe$|^language_server\.exe$' })
L ('antigravity_processes=' + $agy.Count)
foreach($p in ($agy | Select-Object -First 8)){ L ('antigravity_proc=' + $p.Name + ' pid=' + $p.ProcessId) }
if($listen -and $country -match 'SG|Singapore|JP|Japan|US|United States|CA|GB|DE|FR|NL|TW|KR'){
    L 'FINAL_VERIFY: ANTIGRAVITY_BRIDGE_ACTIVE_SUPPORTED_ROUTE'
} elseif($listen) {
    L 'FINAL_VERIFY: ANTIGRAVITY_BRIDGE_ACTIVE_CHECK_ROUTE_MANUALLY'
} else {
    L 'FINAL_VERIFY: ANTIGRAVITY_BRIDGE_NOT_LISTENING'
}
Write-Utf8 $report $script:Lines
Get-Content -LiteralPath $report -ErrorAction SilentlyContinue
exit 0
