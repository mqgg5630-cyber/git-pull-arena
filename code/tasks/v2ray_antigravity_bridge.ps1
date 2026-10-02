# v2ray_antigravity_bridge.ps1 - find a supported V2Ray/TUN route and point
# Antigravity at it without exposing proxy secrets. ASCII-only.

param(
    [string]$OutPath = '',
    [switch]$Apply,
    [switch]$Relaunch,
    [switch]$InteractiveTask
)

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{40,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function Write-Utf8([string]$Path, [string[]]$Lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null; [IO.File]::WriteAllText($Path, ($Lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function NormCountry([string]$s) {
    $x = ([string]$s).ToUpperInvariant()
    if ($x -eq 'US' -or $x -match 'UNITED STATES|AMERICA') { return 'US' }
    if ($x -eq 'JP' -or $x -match 'JAPAN') { return 'JP' }
    if ($x -eq 'SG' -or $x -match 'SINGAPORE') { return 'SG' }
    if ($x -eq 'TW' -or $x -match 'TAIWAN') { return 'TW' }
    if ($x -eq 'HK' -or $x -match 'HONG KONG') { return 'HK' }
    if ($x -eq 'GB' -or $x -match 'UNITED KINGDOM|BRITAIN') { return 'GB' }
    if ($x -match 'GERMANY') { return 'DE' }
    if ($x -match 'FRANCE') { return 'FR' }
    if ($x -match 'NETHERLAND') { return 'NL' }
    if ($x.Length -eq 2) { return $x }
    return $x
}
function Supported([string]$s) {
    $cc = NormCountry $s
    $good = @('US','CA','GB','AU','NZ','JP','KR','SG','TW','DE','FR','NL','SE','NO','FI','DK','IE','ES','IT','PT','PL','BE','CH','AT','CZ','EE','LV','LT','LU','RO','BG','GR','HR','HU','IS','LI','MT','SK','SI')
    return ($good -contains $cc)
}
function CurlText([string]$url, [string]$curlProxy) {
    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) { return @{ ok=$false; text='curl.exe missing'; code=-1 } }
    $args = @('-L','--max-time','15','-sS')
    if ($curlProxy) { $args += @('--proxy', $curlProxy) }
    $args += $url
    try { $txt = (& curl.exe @args 2>&1 | Out-String).Trim(); return @{ ok=($LASTEXITCODE -eq 0); text=$txt; code=$LASTEXITCODE } }
    catch { return @{ ok=$false; text=$_.Exception.Message; code=-1 } }
}
function CurlHead([string]$url, [string]$curlProxy) {
    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) { return 'curl.exe missing' }
    $args = @('-I','-L','--max-time','15','-sS')
    if ($curlProxy) { $args += @('--proxy', $curlProxy) }
    $args += $url
    try {
        $txt = (& curl.exe @args 2>&1 | Out-String).Trim()
        $h = (($txt -split "`r?`n") | Where-Object { $_ -match '^HTTP/' } | Select-Object -Last 1)
        if ($h) { return $h }
        return (($txt -split "`r?`n") | Select-Object -Last 1)
    } catch { return $_.Exception.Message }
}
function Geo([string]$curlProxy) {
    $txt = (CurlText 'https://ipinfo.io/json' $curlProxy).text
    if (-not $txt -or $txt -match 'Failed to connect|timed out|Could not resolve|curl:') { $txt = (CurlText 'http://ip-api.com/json/?fields=status,countryCode,country,regionName,city,query,isp,org' $curlProxy).text }
    $cc=''; $country=''; $city=''; $ip=''; $org=''
    try {
        $o = $txt | ConvertFrom-Json
        $cc = [string]$o.countryCode; if (-not $cc) { $cc = [string]$o.country }
        $country = [string]$o.country; if (-not $country) { $country = $cc }
        $city = [string]$o.city
        $ip = [string]$o.ip; if (-not $ip) { $ip = [string]$o.query }
        $org = [string]$o.org; if (-not $org) { $org = [string]$o.isp }
    } catch { $country = San $txt }
    return @{ cc=NormCountry ($cc + ' ' + $country); raw=($cc + '/' + $country); city=$city; ip=$ip; org=$org }
}
function AddRoute([string]$name, [string]$curlProxy, [string]$appProxy, [string]$mode, [int]$score) {
    $script:Routes += [pscustomobject]@{ name=$name; curl=$curlProxy; app=$appProxy; mode=$mode; score=$score }
}
function Set-Settings([string]$mode, [string]$appProxy) {
    foreach ($root in @((Join-Path $env:APPDATA 'Antigravity\User'), (Join-Path $env:APPDATA 'Antigravity IDE\User'))) {
        try {
            New-Item -ItemType Directory -Force -Path $root | Out-Null
            $sp = Join-Path $root 'settings.json'
            $obj = [pscustomobject]@{}
            if (Test-Path -LiteralPath $sp) { try { $obj = Get-Content -LiteralPath $sp -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $obj = [pscustomobject]@{} } }
            if ($mode -eq 'direct') { $obj | Add-Member -NotePropertyName 'http.proxy' -NotePropertyValue '' -Force; $obj | Add-Member -NotePropertyName 'http.proxySupport' -NotePropertyValue 'off' -Force }
            else { $obj | Add-Member -NotePropertyName 'http.proxy' -NotePropertyValue $appProxy -Force; $obj | Add-Member -NotePropertyName 'http.proxySupport' -NotePropertyValue 'on' -Force }
            $obj | Add-Member -NotePropertyName 'http.noProxy' -NotePropertyValue @('localhost','127.0.0.1','::1') -Force
            [IO.File]::WriteAllText($sp, (($obj | ConvertTo-Json -Depth 8) + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
            L ('settings_OK=' + $sp + ' mode=' + $mode)
        } catch { L ('settings_WARN=' + (San $_.Exception.Message)) }
    }
}
function Set-EnvProxy([string]$mode, [string]$appProxy) {
    foreach ($scope in @('User','Machine')) {
        try {
            if ($mode -eq 'direct') {
                foreach ($k in @('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy')) { [Environment]::SetEnvironmentVariable($k, $null, $scope) }
                [Environment]::SetEnvironmentVariable('NO_PROXY','localhost,127.0.0.1,::1',$scope)
            } else {
                foreach ($k in @('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy')) { [Environment]::SetEnvironmentVariable($k, $appProxy, $scope) }
                [Environment]::SetEnvironmentVariable('NO_PROXY','localhost,127.0.0.1,::1',$scope)
            }
            L ('env_' + $scope + '=' + $mode)
        } catch { L ('env_' + $scope + '_WARN=' + (San $_.Exception.Message)) }
    }
}
function Relaunch-Agy([bool]$interactive) {
    foreach ($n in @('language_server','Antigravity')) { try { & taskkill /f /im ($n + '.exe') 2>&1 | Out-Null } catch { } }
    Start-Sleep -Seconds 3
    $exe = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
    if (-not (Test-Path -LiteralPath $exe)) { L ('relaunch_SKIP missing=' + $exe); return }
    if ($interactive) {
        try { $tn='agyrelaunch_v2ray_bridge'; $la=New-ScheduledTaskAction -Execute $exe; $pr=New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited; $st=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10); Register-ScheduledTask -TaskName $tn -Action $la -Principal $pr -Settings $st -Force | Out-Null; Start-ScheduledTask -TaskName $tn; L ('relaunch_interactive_task=' + $tn) } catch { L ('relaunch_interactive_WARN=' + (San $_.Exception.Message)) }
    } else { try { Start-Process -FilePath $exe; L 'relaunch_startprocess=OK' } catch { L ('relaunch_WARN=' + (San $_.Exception.Message)) } }
}

$script:Lines = @()
$script:Routes = @()
if (-not $OutPath) { $OutPath = Join-Path $env:TEMP 'v2ray_antigravity_bridge.md' }
L '# V2Ray to Antigravity bridge diagnostic'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME + ' apply=' + [bool]$Apply)

$procs = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'v2ray|xray|v2rayN|sing-box|clash|mihomo|nekoray|hiddify|hysteria|tuic|warp|tailscale' -or $_.CommandLine -match 'v2ray|xray|v2rayN|sing-box|clash|mihomo|nekoray|hiddify|hysteria|tuic|warp|tailscale' })
L ('process_count=' + $procs.Count)
foreach ($p in ($procs | Select-Object -First 18)) { L ('process=' + $p.ProcessId + ' ' + (San $p.Name) + ' ' + (San $p.ExecutablePath)) }
$listen = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalAddress -match '^(127\.|0\.0\.0\.0|::1|::)$' })
$ports = @()
foreach ($p in @(10808,10809,1080,7890,7891,7897,7899,8080,8118,20170,2080,6152)) { $ports += $p }
foreach ($c in $listen) { if ($c.LocalPort -ge 1000 -and $c.LocalPort -le 30000) { $ports += [int]$c.LocalPort } }
$ports = @($ports | Sort-Object -Unique)
L ('candidate_ports=' + (($ports | Select-Object -First 80) -join ','))

AddRoute 'DIRECT_TUN' '' '' 'direct' 100
foreach ($p in $ports) {
    AddRoute ('HTTP_' + $p) ('http://127.0.0.1:' + $p) ('http://127.0.0.1:' + $p) 'proxy' (200 + $p)
    AddRoute ('SOCKS5_' + $p) ('socks5h://127.0.0.1:' + $p) ('socks5://127.0.0.1:' + $p) 'proxy' (300 + $p)
}

$results = @()
foreach ($r in $script:Routes) {
    $g = Geo $r.curl
    $sup = Supported $g.cc
    $google = CurlHead 'https://www.google.com/generate_204' $r.curl
    $api = CurlHead 'https://daily-cloudcode-pa.googleapis.com/' $r.curl
    $googleOk = ($google -match '204|200|301|302')
    $apiOk = ($api -match 'HTTP/')
    L ('route=' + $r.name + ' appProxy=' + $r.app + ' country=' + $g.cc + ' raw=' + (San $g.raw) + ' ip=' + (San $g.ip) + ' org=' + (San $g.org) + ' google=' + (San $google) + ' cloudcode=' + (San $api) + ' supported=' + $sup)
    $results += [pscustomobject]@{ route=$r; supported=$sup; googleOk=$googleOk; apiOk=$apiOk; cc=$g.cc }
}
$choice = @($results | Where-Object { $_.supported -and $_.googleOk -and $_.apiOk } | Sort-Object @{Expression={$_.route.score}} | Select-Object -First 1)
if ($choice.Count -gt 0) {
    $ch = $choice[0].route
    L ('chosen=' + $ch.name + ' mode=' + $ch.mode + ' appProxy=' + $ch.app)
    if ($Apply) {
        Set-EnvProxy $ch.mode $ch.app
        Set-Settings $ch.mode $ch.app
        if ($Relaunch) { Relaunch-Agy ([bool]$InteractiveTask) }
        L 'FINAL: V2RAY_BRIDGE_APPLIED supported route applied to Antigravity.'
    } else { L 'FINAL: V2RAY_BRIDGE_FOUND supported route found; rerun with -Apply.' }
} else {
    L 'FINAL: V2RAY_BRIDGE_NO_SUPPORTED_ROUTE no local V2Ray/TUN route exits a supported region. Switch v2rayN to a US/JP/SG/TW/EU node, then rerun.'
}
Write-Utf8 $OutPath $script:Lines
L ('report=' + $OutPath)
exit 0
