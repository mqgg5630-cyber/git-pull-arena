# t1_antigravity_tun2.ps1 - round 27 task: the user says Tun is ALWAYS ON but
# direct connections still fail (r25: direct tcp443 to google = FAIL), so the
# Antigravity login keeps dying at the oauth2.googleapis.com token POST.
# This task:
#   1. checks whether a wintun/tun adapter actually exists and is routing
#   2. sets the USER-level proxy env vars (HTTP_PROXY/HTTPS_PROXY/ALL_PROXY/
#      NO_PROXY) so every app launched after this inherits them - Node-based
#      auth services (Antigravity's) DO honour these
#   3. if Antigravity is NOT running: relaunches it from here (it inherits
#      the proxy env) and watches its fresh auth.log for 90s - if it has a
#      stored refresh token it may log in silently
#   4. dumps the fresh auth.log either way
# The env change is reversible:
#   [Environment]::SetEnvironmentVariable('HTTP_PROXY',$null,'User')  (x4)
#
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t1 (tun2): Antigravity proxy env fix + Tun diagnosis ---'

# ------------------------------------------------------- 1. Tun diagnosis
Write-Output '--- Tun diagnosis ---'
$tunAdapters = @()
try {
    $tunAdapters = @(Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue | Where-Object { ($_.InterfaceDescription -match '(?i)wintun|wireguard|tun2|tap') -or ($_.Name -match '(?i)tun|v2ray') })
} catch { }
if ($tunAdapters.Count -eq 0) {
    Write-Output '   adapters: NO tun/wintun adapter found -> Tun mode is NOT actually active'
    Write-Output '             (v2rayN must run its service as admin for Tun - in v2rayN: menu "automatic run as admin")'
} else {
    foreach ($a in $tunAdapters) {
        Write-Output ('   adapter: ' + (San ([string]$a.Name)) + ' | ' + (San ([string]$a.InterfaceDescription)) + ' | status=' + (San ([string]$a.Status)) + ' | ifIndex=' + $a.ifIndex)
    }
    try {
        foreach ($r in @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Select-Object -First 6)) {
            Write-Output ('   route 0.0.0.0/0 -> ifIndex ' + $r.ifIndex + ' metric ' + $r.RouteMetric + ' (' + (San ([string]$r.InterfaceAlias)) + ')')
        }
    } catch { }
}
$svcHits = @(Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)wintun|v2ray|singbox|sing-box' -or $_.DisplayName -match '(?i)wintun|v2ray|sing' } | Select-Object -First 5)
if ($svcHits.Count -gt 0) {
    foreach ($s in $svcHits) { Write-Output ('   service: ' + (San ([string]$s.Name)) + ' = ' + $s.Status) }
} else {
    Write-Output '   services: no v2ray/wintun service registered (Tun needs the service mode)'
}

# direct connectivity again, now
function Test-Tcp443 {
    param([string]$h)
    $c = New-Object System.Net.Sockets.TcpClient
    try {
        $ar = $c.BeginConnect($h, 443, $null, $null)
        $ok = $ar.AsyncWaitHandle.WaitOne(4000)
        if (-not $ok) { return $false }
        try { $c.EndConnect($ar) } catch { return $false }
        return $c.Connected
    } catch { return $false } finally { try { $c.Close() } catch { } }
}
$directNow = Test-Tcp443 'oauth2.googleapis.com'
Write-Output ('   direct tcp443 oauth2.googleapis.com NOW = ' + $(if ($directNow) { 'OK (something is intercepting - good)' } else { 'FAIL (Tun is NOT routing, as suspected)' }))

# --------------------------------------------- 2. user-level proxy env
Write-Output '--- set user-level proxy env vars (Node/auth services honour these) ---'
$proxyUrl = ''
try {
    $is = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction Stop
    $psv = [string]$is.ProxyServer
    if (([int]$is.ProxyEnable -eq 1) -and $psv) {
        if ($psv -notmatch '^[a-z]+://') { $proxyUrl = 'http://' + $psv }
        else { $proxyUrl = $psv }
    }
} catch { }
if (-not $proxyUrl) { $proxyUrl = 'http://127.0.0.1:10808' }
Write-Output ('   proxy: ' + $proxyUrl)
foreach ($n in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy')) {
    [Environment]::SetEnvironmentVariable($n, $proxyUrl, 'User')
}
[Environment]::SetEnvironmentVariable('NO_PROXY', 'localhost,127.0.0.1,::1', 'User')
[Environment]::SetEnvironmentVariable('no_proxy', 'localhost,127.0.0.1,::1', 'User')
foreach ($n in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY')) {
    Write-Output ('   ' + $n + ' (User) = ' + (San ([string][Environment]::GetEnvironmentVariable($n, 'User'))))
}
Write-Output '   NOTE: applies to apps started AFTER now (new processes). Undo with:'
Write-Output '     [Environment]::SetEnvironmentVariable("HTTP_PROXY",$null,"User")   (repeat for the others)'

# --------------------------------- 3. relaunch Antigravity with the env
Write-Output '--- Antigravity relaunch with proxy env ---'
$agProcs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)antigravity' })
$exe = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
if (-not (Test-Path -LiteralPath $exe)) { $exe = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity IDE\Antigravity IDE.exe' }
if ($agProcs.Count -gt 0) {
    $pl = @($agProcs | Select-Object -First 5 | ForEach-Object { $_.Name + '(' + $_.Id + ')' })
    $runMsg = '   Antigravity is RUNNING (' + ($pl -join ' ') + ') - close it (File -> Exit) and the NEXT launch picks up the env vars'
    Write-Output $runMsg
    Write-Output '   no relaunch done here (will not kill your open windows)'
} elseif (-not (Test-Path -LiteralPath $exe)) {
    Write-Output ('   [WARN] Antigravity exe not found at expected paths')
} else {
    Write-Output ('   launching: ' + (San $exe))
    $env:HTTP_PROXY = $proxyUrl
    $env:HTTPS_PROXY = $proxyUrl
    $env:ALL_PROXY = $proxyUrl
    $env:NO_PROXY = 'localhost,127.0.0.1,::1'
    try {
        Start-Process -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe)
        Write-Output '   launched - waiting 90s for the auth flow to settle ...'
        Start-Sleep -Seconds 90
        $np = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)antigravity' } | Select-Object -First 3 | ForEach-Object { $_.Name + '(' + $_.Id + ')' })
        Write-Output ('   processes now: ' + $(if ($np.Count) { $np -join ' ' } else { '(not running?)' }))
    } catch {
        Write-Output ('   [WARN] launch failed: ' + (San $_.Exception.Message))
    }
}

# ------------------------------------------------ 4. fresh auth.log
Write-Output '--- newest auth.log (after this round) ---'
$lr = Join-Path $env:APPDATA 'Antigravity IDE\logs'
if (Test-Path -LiteralPath $lr) {
    $sess = @(Get-ChildItem -LiteralPath $lr -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 2)
    foreach ($s in $sess) {
        Write-Output ('   session ' + (San $s.Name) + ' (last write ' + $s.LastWriteTime.ToString('yyyy-MM-dd HH:mm') + ')')
        $al = Join-Path $s.FullName 'auth.log'
        if (Test-Path -LiteralPath $al) {
            $lines = @(Get-Content -LiteralPath $al -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -Last 20)
            foreach ($ln in $lines) { Write-Output ('      ' + (San ([string]$ln))) }
        } else { Write-Output '      no auth.log yet' }
    }
} else {
    Write-Output '   no logs dir'
}
Write-Output '--- verdict rule ---'
Write-Output '   SUCCESS = auth.log shows no ETIMEDOUT and state reaches signedIn/validatingLogin->ok'
Write-Output '   if ETIMEDOUT is still there, the machine must route via Tun properly (v2rayN service mode)'
exit 0
