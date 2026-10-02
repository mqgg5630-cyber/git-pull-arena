# t149_verify_bridge_stable.ps1 - round 192: verify bridge persists and HTTPS works with schannel no-revoke.
# ASCII-only. Prints no node secrets.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function Write-Utf8([string]$Path, [string[]]$Lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null; [IO.File]::WriteAllText($Path, ($Lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function Invoke-Curl([string[]]$CurlArgs) { try { $ce = Join-Path $env:SystemRoot 'System32\curl.exe'; return (& $ce @CurlArgs 2>&1 | Out-String).Trim() } catch { return $_.Exception.Message } }
function Wait-Port([int]$port, [int]$sec) { $deadline=(Get-Date).AddSeconds($sec); while((Get-Date)-lt $deadline){ try{$c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$port,$null,$null); if($iar.AsyncWaitHandle.WaitOne(400)){ $c.EndConnect($iar); $c.Close(); return $true}; $c.Close()}catch{}; Start-Sleep -Milliseconds 300}; return $false }
$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\antigravity'; New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report=Join-Path $outDir 'antigravity_bridge_stable_verify_r192.md'
L '# Antigravity bridge stable verify'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
$listen=Wait-Port 18088 8
L ('bridge_port_18088_listen=' + $listen)
$bridgeProcs=@(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { ($_.Name -match '^xray\.exe$|^v2ray\.exe$') -and ($_.CommandLine -like '*antigravity-xray-bridge.json*') })
L ('bridge_xray_processes=' + $bridgeProcs.Count)
foreach($p in ($bridgeProcs | Select-Object -First 4)){ L ('bridge_proc_pid=' + $p.ProcessId + ' exe=' + (San ([string]$p.ExecutablePath))) }
if($listen){
    $proxy='http://127.0.0.1:18088'
    $httpGeo=Invoke-Curl -CurlArgs @('-L','--max-time','15','-sS','--proxy',$proxy,'http://ip-api.com/json/?fields=status,countryCode,country,query,isp,org')
    try{ $h=$httpGeo|ConvertFrom-Json; L ('http_geo_status=' + [string]$h.status + ' country=' + [string]$h.countryCode + ' ip=' + (San ([string]$h.query)) + ' org=' + (San ([string]$h.org))) }catch{ L ('http_geo_raw=' + (San $httpGeo)) }
    $httpsGeo=Invoke-Curl -CurlArgs @('--ssl-no-revoke','-L','--max-time','20','-sS','--proxy',$proxy,'https://ipinfo.io/json')
    try{ $g=$httpsGeo|ConvertFrom-Json; L ('https_geo_country=' + [string]$g.country + ' ip=' + (San ([string]$g.ip)) + ' org=' + (San ([string]$g.org))) }catch{ L ('https_geo_raw=' + (San $httpsGeo)) }
    $api=Invoke-Curl -CurlArgs @('--ssl-no-revoke','-i','-L','--max-time','20','-sS','--proxy',$proxy,'https://daily-cloudcode-pa.googleapis.com/')
    $status=(($api -split "`r?`n") | Where-Object { $_ -match '^HTTP/' } | Select-Object -Last 1)
    $unsupported=[bool]($api -match 'User location is not supported|FAILED_PRECONDITION')
    L ('daily_cloudcode_status=' + (San $status))
    L ('daily_cloudcode_location_block_text_present=' + $unsupported)
}
foreach($root in @((Join-Path $env:APPDATA 'Antigravity\User'),(Join-Path $env:APPDATA 'Antigravity IDE\User'))){ $sp=Join-Path $root 'settings.json'; if(Test-Path $sp){ $txt=Get-Content -LiteralPath $sp -Raw -ErrorAction SilentlyContinue; L ('settings_proxy_present=' + $sp + ' -> ' + [bool]($txt -match '127\.0\.0\.1:18088')) } }
$agy=@(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^Antigravity\.exe$|^language_server\.exe$' })
L ('antigravity_processes=' + $agy.Count)
if($listen -and $bridgeProcs.Count -gt 0){ L 'FINAL_STABLE_VERIFY: ANTIGRAVITY_BRIDGE_PERSISTENT' } else { L 'FINAL_STABLE_VERIFY: ANTIGRAVITY_BRIDGE_NOT_STABLE' }
Write-Utf8 $report $script:Lines
Get-Content -LiteralPath $report -ErrorAction SilentlyContinue
exit 0
