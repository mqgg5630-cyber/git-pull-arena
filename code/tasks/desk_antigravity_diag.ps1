# desk_antigravity_diag.ps1 - runs ON THE DESKTOP (staged via F$, executed
# by ssh). READ-ONLY diagnosis of the Antigravity login failure:
# install/data dirs, processes, proxy state (WinINET/env/listening ports),
# direct TCP probes to Google, probe of the LAPTOP proxy over Tailscale,
# and masked auth-log tails. ASCII-only, tokens redacted.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{40,}', '[REDACTED]' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    try { $s = $s -replace '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+', '[EMAIL]' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop Antigravity login diagnosis (read-only) ---'
$u = [string]$env:USERNAME
L ('user: ' + (San $u))

# ------------------------------------------------ install locations
L '--- 1. install locations ---'
foreach ($d in @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Antigravity'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Antigravity IDE'),
    'C:\Program Files\Antigravity',
    'C:\Program Files\Google\Antigravity'
)) {
    if (Test-Path -LiteralPath $d) {
        $exe = Get-ChildItem -LiteralPath $d -Filter '*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        $v = ''
        if ($exe) { try { $v = [string]$exe.VersionInfo.ProductVersion } catch { } }
        L ('   install PRESENT: ' + $d + ' exe=' + $v)
    } else { L ('   install absent : ' + $d) }
}

# ------------------------------------------------ data locations
L '--- 2. data locations ---'
foreach ($d in @(
    (Join-Path $env:APPDATA 'Antigravity'),
    (Join-Path $env:APPDATA 'Antigravity IDE'),
    (Join-Path $env:USERPROFILE '.gemini\antigravity'),
    (Join-Path $env:USERPROFILE '.gemini\antigravity-ide'),
    (Join-Path $env:USERPROFILE '.antigravity')
)) {
    if (Test-Path -LiteralPath $d) {
        $newest = Get-ChildItem -LiteralPath $d -Recurse -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3
        L ('   data PRESENT: ' + $d)
        foreach ($f in $newest) { L ('      ' + (San $f.Name) + '  ' + $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm') + '  ' + [int]($f.Length / 1KB) + 'KB') }
    } else { L ('   data absent : ' + $d) }
}

# ------------------------------------------------ processes
L '--- 3. processes ---'
$procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'Antigravity' })
L ('   antigravity processes: ' + $procs.Count)
foreach ($p in ($procs | Select-Object -First 5)) { L ('   pid=' + $p.Id + ' ' + (San $p.ProcessName)) }

# ------------------------------------------------ default browser + url handler
L '--- 4. browser + url handler ---'
try {
    $prog = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice' -ErrorAction Stop).ProgId
    L ('   default https browser ProgId: ' + (San $prog))
} catch { L '   default browser: unknown' }
foreach ($k in @('HKCU:\Software\Classes\antigravity', 'HKLM:\SOFTWARE\Classes\antigravity')) {
    if (Test-Path -LiteralPath $k) { L ('   url handler antigravity:// REGISTERED at ' + $k) }
    else { L ('   url handler missing at ' + $k) }
}

# ------------------------------------------------ proxy state
L '--- 5. proxy state ---'
foreach ($n in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy')) {
    $v = [Environment]::GetEnvironmentVariable($n)
    if ($v) { L ('   env ' + $n + '=' + (San $v)) }
}
try {
    $w = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction Stop
    L ('   WinINET: ProxyEnable=' + $w.ProxyEnable + ' ProxyServer=' + (San ([string]$w.ProxyServer)) + ' AutoConfigURL=' + (San ([string]$w.AutoConfigURL)))
} catch { L '   WinINET: unreadable' }
# listening proxy ports
foreach ($port in @(10808, 10809, 7890, 7897, 1080, 8888, 2080, 8080)) {
    $hit = netstat -an | Select-String (':' + $port + '\s')
    if ($hit) { foreach ($h in @($hit | Select-Object -First 2)) { L ('   listening : ' + (San ([string]$h).Trim())) } }
}

# ------------------------------------------------ direct network probes
L '--- 6. direct TCP 443 probes (4s) ---'
foreach ($host_ in @('github.com', 'accounts.google.com', 'oauth2.googleapis.com', 'antigravity.google', 'www.baidu.com')) {
    $ip = '(dns fail)'
    try { $ip = ([System.Net.Dns]::GetHostAddresses($host_)[0].IPAddressToString) } catch { }
    $ok = $false
    try { $t = New-Object System.Net.Sockets.TcpClient; $ok = $t.ConnectAsync($host_, 443).Wait(4000); $t.Close() } catch { }
    L ('   ' + $host_.PadRight(22) + ' dns=' + $ip.PadRight(16) + ' tcp443=' + $(if ($ok) { 'OK' } else { 'FAIL' }))
}

# ------------------------------------------------ laptop proxy over Tailscale
L '--- 7. laptop proxy probe (100.71.123.19:10808 over Tailscale) ---'
$lp = $false
try { $t = New-Object System.Net.Sockets.TcpClient; $lp = $t.ConnectAsync('100.71.123.19', 10808).Wait(4000); $t.Close() } catch { }
L ('   tcp 100.71.123.19:10808: ' + $(if ($lp) { 'OPEN (laptop proxy reachable!)' } else { 'FAIL (proxy not LAN-exposed or laptop offline)' }))
if ($lp) {
    $r = & curl.exe -sS -m 10 -x http://100.71.123.19:10808 -o NUL -w "%{http_code}" https://accounts.google.com 2>&1
    L ('   via laptop proxy -> accounts.google.com HTTP: ' + (San ([string]$r)))
    $r2 = & curl.exe -sS -m 10 -x http://100.71.123.19:10808 -o NUL -w "%{http_code}" https://antigravity.google 2>&1
    L ('   via laptop proxy -> antigravity.google  HTTP: ' + (San ([string]$r2)))
}

# ------------------------------------------------ auth logs
L '--- 8. newest auth/error log lines (masked) ---'
$logDirs = @()
foreach ($d in @((Join-Path $env:APPDATA 'Antigravity IDE\logs'), (Join-Path $env:APPDATA 'Antigravity\logs'))) {
    if (Test-Path -LiteralPath $d) { $logDirs += $d }
}
foreach ($ld in $logDirs) {
    $logs = @(Get-ChildItem -LiteralPath $ld -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3)
    foreach ($lf in $logs) {
        L ('   --- ' + (San $lf.Name) + ' (' + $lf.LastWriteTime.ToString('MM-dd HH:mm') + ') ---')
        $hits = @(Select-String -LiteralPath $lf.FullName -Pattern 'auth|login|oauth|token|error|fail|denied|expired|offline|network' -ErrorAction SilentlyContinue | Select-Object -Last 8)
        if (@($hits).Count -eq 0) { L '      (no matching lines)' }
        foreach ($h in $hits) { L ('      ' + (San ([string]$h.Line).Trim())) }
    }
}
L '--- desktop diagnosis done ---'
