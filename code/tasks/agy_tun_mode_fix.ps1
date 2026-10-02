# agy_tun_mode_fix.ps1 - configure Antigravity for current TUN/proxy route.
# If direct egress is in a supported region, clear explicit HTTP proxy so TUN
# captures traffic. Else if 127.0.0.1:10808 is supported, use it. ASCII-only.

param(
    [string]$OutPath = '',
    [switch]$Relaunch,
    [switch]$InteractiveTask
)

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{40,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function Write-Utf8([string]$Path, [string[]]$Lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null; [IO.File]::WriteAllText($Path, ($Lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function CurlText([string]$url, [string]$proxy) {
    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) { return '' }
    $args = @('-L','--max-time','15','-sS')
    if ($proxy) { $args += @('--proxy', $proxy) }
    $args += $url
    try { return (& curl.exe @args 2>&1 | Out-String).Trim() } catch { return $_.Exception.Message }
}
function CurlHead([string]$url, [string]$proxy) {
    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) { return '' }
    $args = @('-I','-L','--max-time','15','-sS')
    if ($proxy) { $args += @('--proxy', $proxy) }
    $args += $url
    try {
        $txt = (& curl.exe @args 2>&1 | Out-String).Trim()
        $h = (($txt -split "`r?`n") | Where-Object { $_ -match '^HTTP/' } | Select-Object -Last 1)
        if ($h) { return $h }
        return (($txt -split "`r?`n") | Select-Object -Last 1)
    } catch { return $_.Exception.Message }
}
function Geo([string]$proxy) {
    $txt = CurlText 'https://ipinfo.io/json' $proxy
    if (-not $txt -or $txt -match 'error|Could not|Failed to connect|timed out') { $txt = CurlText 'http://ip-api.com/json/?fields=status,countryCode,country,regionName,city,query,isp,org' $proxy }
    $cc=''; $country=''; $city=''; $ip=''; $org=''
    try {
        $o = $txt | ConvertFrom-Json
        $cc = [string]$o.countryCode; if (-not $cc) { $cc = [string]$o.country }
        $country = [string]$o.country; if (-not $country) { $country = $cc }
        $city = [string]$o.city
        $ip = [string]$o.ip; if (-not $ip) { $ip = [string]$o.query }
        $org = [string]$o.org; if (-not $org) { $org = [string]$o.isp }
    } catch { $country = San $txt }
    return @{ cc=$cc.ToUpperInvariant(); country=$country; city=$city; ip=$ip; org=$org; raw=$txt }
}
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
function Set-Settings([string]$mode, [string]$proxy) {
    foreach ($root in @((Join-Path $env:APPDATA 'Antigravity\User'), (Join-Path $env:APPDATA 'Antigravity IDE\User'))) {
        try {
            New-Item -ItemType Directory -Force -Path $root | Out-Null
            $sp = Join-Path $root 'settings.json'
            $obj = [pscustomobject]@{}
            if (Test-Path -LiteralPath $sp) { try { $obj = Get-Content -LiteralPath $sp -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $obj = [pscustomobject]@{} } }
            if ($mode -eq 'direct') {
                $obj | Add-Member -NotePropertyName 'http.proxy' -NotePropertyValue '' -Force
                $obj | Add-Member -NotePropertyName 'http.proxySupport' -NotePropertyValue 'off' -Force
            } else {
                $obj | Add-Member -NotePropertyName 'http.proxy' -NotePropertyValue $proxy -Force
                $obj | Add-Member -NotePropertyName 'http.proxySupport' -NotePropertyValue 'on' -Force
            }
            $obj | Add-Member -NotePropertyName 'http.noProxy' -NotePropertyValue @('localhost','127.0.0.1','::1') -Force
            [IO.File]::WriteAllText($sp, (($obj | ConvertTo-Json -Depth 8) + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
            L ('settings=' + $mode + ' ' + $sp)
        } catch { L ('settings_WARN=' + (San $_.Exception.Message)) }
    }
}
function Set-EnvProxy([string]$mode, [string]$proxy) {
    foreach ($scope in @('User','Machine')) {
        try {
            if ($mode -eq 'direct') {
                foreach ($k in @('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy')) { [Environment]::SetEnvironmentVariable($k, $null, $scope) }
                [Environment]::SetEnvironmentVariable('NO_PROXY', 'localhost,127.0.0.1,::1', $scope)
            } else {
                foreach ($k in @('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy')) { [Environment]::SetEnvironmentVariable($k, $proxy, $scope) }
                [Environment]::SetEnvironmentVariable('NO_PROXY', 'localhost,127.0.0.1,::1', $scope)
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
        try {
            $tn = 'agyrelaunch_tunfix'
            $la = New-ScheduledTaskAction -Execute $exe
            $pr = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
            $st = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
            Register-ScheduledTask -TaskName $tn -Action $la -Principal $pr -Settings $st -Force | Out-Null
            Start-ScheduledTask -TaskName $tn
            L ('relaunch_interactive_task=' + $tn)
        } catch { L ('relaunch_interactive_WARN=' + (San $_.Exception.Message)) }
    } else {
        try { Start-Process -FilePath $exe; L 'relaunch_startprocess=OK' } catch { L ('relaunch_WARN=' + (San $_.Exception.Message)) }
    }
}

$script:Lines = @()
if (-not $OutPath) { $OutPath = Join-Path $env:TEMP 'agy_tun_mode_fix.md' }
L '# Antigravity TUN/proxy route fix'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)

$routes = @(
    @{ name='DIRECT_TUN'; proxy='' },
    @{ name='HTTP_10808'; proxy='http://127.0.0.1:10808' },
    @{ name='TS_10808'; proxy='http://100.71.123.19:10808' }
)
$chosenMode = ''
$chosenProxy = ''
foreach ($r in $routes) {
    $g = Geo $r.proxy
    $cc = NormCountry ($g.cc + ' ' + $g.country)
    $sup = Supported ($g.cc + ' ' + $g.country)
    $g204 = CurlHead 'https://www.google.com/generate_204' $r.proxy
    $api = CurlHead 'https://daily-cloudcode-pa.googleapis.com/' $r.proxy
    L ('route=' + $r.name + ' proxy=' + $r.proxy + ' country=' + $cc + ' rawCountry=' + (San ($g.cc + '/' + $g.country)) + ' ip=' + (San $g.ip) + ' org=' + (San $g.org) + ' google=' + (San $g204) + ' cloudcode=' + (San $api) + ' supported=' + $sup)
    if (-not $chosenMode -and $sup) {
        if ($r.name -eq 'DIRECT_TUN') { $chosenMode = 'direct' } else { $chosenMode = 'proxy'; $chosenProxy = $r.proxy }
    }
}

if ($chosenMode) {
    L ('chosen_mode=' + $chosenMode + ' proxy=' + $chosenProxy)
    Set-EnvProxy $chosenMode $chosenProxy
    Set-Settings $chosenMode $chosenProxy
    if ($Relaunch) { Relaunch-Agy ([bool]$InteractiveTask) }
    L 'FINAL: AGY_TUN_ROUTE_APPLIED supported route configured; open a new Antigravity chat.'
} else {
    L 'FINAL: AGY_TUN_ROUTE_UNSUPPORTED no tested route exits a supported region; current TUN/proxy still cannot satisfy Google API geo policy.'
}
Write-Utf8 $OutPath $script:Lines
L ('report=' + $OutPath)
exit 0
