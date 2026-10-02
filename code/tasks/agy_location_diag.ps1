# agy_location_diag.ps1 - diagnose Antigravity "User location is not supported"
# and switch to a likely-supported proxy if one is discovered. ASCII-only.

param(
    [string]$OutPath = '',
    [switch]$Apply
)

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{40,}', '[REDACTED]' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function Write-Utf8([string]$Path, [string[]]$Lines) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    [IO.File]::WriteAllText($Path, ($Lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
}
function Add-ProxyCandidate([string]$p) {
    if (-not $p) { return }
    $x = $p.Trim()
    if (-not $x) { return }
    if ($x -notmatch '^[a-zA-Z]+://') { $x = 'http://' + $x }
    if ($script:ProxyMap.ContainsKey($x)) { return }
    $script:ProxyMap[$x] = $true
    $script:Proxies += $x
}
function CurlText([string]$url, [string]$proxy) {
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if (-not $curl) { return @{ ok = $false; text = 'curl.exe missing' } }
    $args = @('-L', '--max-time', '16', '-sS')
    if ($proxy) { $args += @('--proxy', $proxy) }
    $args += $url
    try {
        $txt = (& curl.exe @args 2>&1 | Out-String).Trim()
        $code = $LASTEXITCODE
        return @{ ok = ($code -eq 0); text = $txt; code = $code }
    } catch { return @{ ok = $false; text = $_.Exception.Message; code = -1 } }
}
function CurlHead([string]$url, [string]$proxy) {
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if (-not $curl) { return @{ ok = $false; text = 'curl.exe missing' } }
    $args = @('-I', '-L', '--max-time', '16', '-sS')
    if ($proxy) { $args += @('--proxy', $proxy) }
    $args += $url
    try {
        $txt = (& curl.exe @args 2>&1 | Out-String).Trim()
        $code = $LASTEXITCODE
        $h = (($txt -split "`r?`n") | Where-Object { $_ -match '^HTTP/' } | Select-Object -Last 1)
        if (-not $h) { $h = (($txt -split "`r?`n") | Select-Object -Last 1) }
        return @{ ok = ($code -eq 0); text = $h; code = $code; raw = $txt }
    } catch { return @{ ok = $false; text = $_.Exception.Message; code = -1 } }
}
function Parse-Country([string]$json) {
    try {
        $o = $json | ConvertFrom-Json
        $cc = ''
        foreach ($k in @('country','countryCode','country_code','country_code_iso3')) { if ($o.$k) { $cc = [string]$o.$k; break } }
        $city = ''; foreach ($k in @('city','region','regionName')) { if ($o.$k) { $city = [string]$o.$k; break } }
        $ip = ''; foreach ($k in @('ip','query')) { if ($o.$k) { $ip = [string]$o.$k; break } }
        $org = ''; foreach ($k in @('org','isp','asn_org')) { if ($o.$k) { $org = [string]$o.$k; break } }
        return @{ country = $cc.ToUpperInvariant(); city = $city; ip = $ip; org = $org }
    } catch { return @{ country = ''; city = ''; ip = ''; org = '' } }
}
function Is-LikelySupported([string]$cc) {
    if (-not $cc) { return $false }
    $good = @('US','CA','GB','AU','NZ','JP','KR','SG','TW','DE','FR','NL','SE','NO','FI','DK','IE','ES','IT','PT','PL','BE','CH','AT','CZ','EE','LV','LT','LU','RO','BG','GR','HR','HU','IS','LI','MT','SK','SI')
    return ($good -contains $cc.ToUpperInvariant())
}
function Get-LogHits {
    $roots = @((Join-Path $env:APPDATA 'Antigravity\logs'), (Join-Path $env:APPDATA 'Antigravity IDE\logs'))
    foreach ($r in $roots) {
        if (-not (Test-Path -LiteralPath $r)) { L ('logs_missing=' + $r); continue }
        L ('logs_root=' + $r)
        foreach ($f in @(Get-ChildItem -LiteralPath $r -File -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 8)) {
            $hits = @(Select-String -Path $f.FullName -Pattern 'User location is not supported|FAILED_PRECONDITION|HTTP 400|Cloudaicompanion|TraceID|location|unsupported|Agent execution terminated' -ErrorAction SilentlyContinue | Select-Object -Last 12)
            if ($hits.Count -gt 0) {
                L ('log_hits ' + $f.Name + ' count=' + $hits.Count)
                foreach ($h in $hits) { L ('   L' + $h.LineNumber + ' ' + (San $h.Line.Trim())) }
            }
        }
    }
}
function Apply-Proxy([string]$proxy) {
    L ('apply_proxy=' + $proxy)
    try {
        foreach ($scope in @('User','Machine')) {
            try {
                [Environment]::SetEnvironmentVariable('HTTP_PROXY', $proxy, $scope)
                [Environment]::SetEnvironmentVariable('HTTPS_PROXY', $proxy, $scope)
                [Environment]::SetEnvironmentVariable('ALL_PROXY', $proxy, $scope)
                [Environment]::SetEnvironmentVariable('NO_PROXY', 'localhost,127.0.0.1,::1', $scope)
                L ('env_' + $scope + '=OK')
            } catch { L ('env_' + $scope + '=WARN ' + (San $_.Exception.Message)) }
        }
        $env:HTTP_PROXY = $proxy; $env:HTTPS_PROXY = $proxy; $env:ALL_PROXY = $proxy; $env:NO_PROXY = 'localhost,127.0.0.1,::1'
        foreach ($root in @((Join-Path $env:APPDATA 'Antigravity\User'), (Join-Path $env:APPDATA 'Antigravity IDE\User'))) {
            try {
                New-Item -ItemType Directory -Force -Path $root | Out-Null
                $sp = Join-Path $root 'settings.json'
                $obj = [pscustomobject]@{}
                if (Test-Path -LiteralPath $sp) { try { $obj = Get-Content -LiteralPath $sp -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $obj = [pscustomobject]@{} } }
                $obj | Add-Member -NotePropertyName 'http.proxy' -NotePropertyValue $proxy -Force
                $obj | Add-Member -NotePropertyName 'http.proxySupport' -NotePropertyValue 'on' -Force
                $obj | Add-Member -NotePropertyName 'http.noProxy' -NotePropertyValue @('localhost','127.0.0.1','::1') -Force
                [IO.File]::WriteAllText($sp, (($obj | ConvertTo-Json -Depth 8) + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
                L ('settings_OK=' + $sp)
            } catch { L ('settings_WARN=' + $root + ' ' + (San $_.Exception.Message)) }
        }
        return $true
    } catch { L ('apply_proxy_FAIL=' + (San $_.Exception.Message)); return $false }
}

$script:Lines = @()
if (-not $OutPath) {
    $base = if (Test-Path 'F:\fig1_rebuild') { 'F:\fig1_rebuild' } else { (Join-Path $env:TEMP 'git-sync-agy') }
    $OutPath = Join-Path $base 'agy_location_diag.md'
}
L '# Antigravity API location diagnostic'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
L ('apply=' + [bool]$Apply)

Get-LogHits

$script:Proxies = @()
$script:ProxyMap = @{}
foreach ($v in @($env:HTTPS_PROXY, $env:HTTP_PROXY, $env:ALL_PROXY, $env:https_proxy, $env:http_proxy)) { Add-ProxyCandidate $v }
try {
    $ru = Get-ItemProperty -Path 'HKCU:\Environment' -ErrorAction SilentlyContinue
    foreach ($v in @($ru.HTTPS_PROXY, $ru.HTTP_PROXY, $ru.ALL_PROXY)) { Add-ProxyCandidate ([string]$v) }
} catch { }
try {
    $rm = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -ErrorAction SilentlyContinue
    foreach ($v in @($rm.HTTPS_PROXY, $rm.HTTP_PROXY, $rm.ALL_PROXY)) { Add-ProxyCandidate ([string]$v) }
} catch { }
try {
    $inet = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
    if ($inet.ProxyServer) {
        foreach ($part in ([string]$inet.ProxyServer -split ';')) {
            $p = $part.Trim()
            if ($p -match '=') { $p = ($p -split '=',2)[1] }
            Add-ProxyCandidate $p
        }
    }
} catch { }
foreach ($p in @('127.0.0.1:10808','127.0.0.1:7890','127.0.0.1:7897','127.0.0.1:7899','127.0.0.1:1080','127.0.0.1:8080','127.0.0.1:8118','100.71.123.19:10808','100.71.123.19:7890')) { Add-ProxyCandidate $p }

L '## exit IP tests'
$candidates = @()
$tests = @(@{ name='DIRECT'; proxy='' })
foreach ($p in $script:Proxies) { $tests += @{ name=$p; proxy=$p } }
foreach ($t in $tests) {
    $geo = CurlText 'https://ipinfo.io/json' $t.proxy
    if (-not $geo.ok -or -not $geo.text) { $geo = CurlText 'http://ip-api.com/json/?fields=status,countryCode,country,regionName,city,query,isp,org' $t.proxy }
    $g = Parse-Country $geo.text
    $g204 = CurlHead 'https://www.google.com/generate_204' $t.proxy
    $dcp = CurlHead 'https://daily-cloudcode-pa.googleapis.com/' $t.proxy
    $supported = Is-LikelySupported $g.country
    L ('route=' + $t.name + ' country=' + $g.country + ' city=' + (San $g.city) + ' ip=' + (San $g.ip) + ' org=' + (San $g.org) + ' google=' + (San $g204.text) + ' cloudcode=' + (San $dcp.text) + ' likely_supported=' + $supported)
    if ($t.proxy -and $supported -and $g204.ok) { $candidates += $t.proxy }
}

if ($candidates.Count -gt 0) {
    $chosen = [string]$candidates[0]
    L ('chosen_supported_proxy=' + $chosen)
    if ($Apply) {
        $ok = Apply-Proxy $chosen
        if ($ok) { L 'FINAL: AGY_LOCATION_PROXY_APPLIED restart Antigravity fully, then open a new agent chat.' }
        else { L 'FINAL: AGY_LOCATION_PROXY_APPLY_FAILED' }
    } else { L 'FINAL: AGY_LOCATION_SUPPORTED_PROXY_FOUND run with -Apply to switch.' }
} else {
    L 'FINAL: AGY_LOCATION_NO_SUPPORTED_PROXY_FOUND current error is a Google API geo restriction; browser availability is not enough. Use a US/JP/SG/TW/EU proxy/VPN exit, then rerun.'
}

Write-Utf8 $OutPath $script:Lines
L ('report=' + $OutPath)
exit 0
