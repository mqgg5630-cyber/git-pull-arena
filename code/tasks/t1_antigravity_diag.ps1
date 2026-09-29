# t1_antigravity_diag.ps1 - round 22 task 1: diagnose the Antigravity login
# failure for account j***z@gmail.com. READ-ONLY: nothing is modified.
#
# The output lands in the check receipt and is pushed to GitHub, so every line
# is sanitized: the account is masked, non-ASCII becomes '?', and anything
# that looks like a token (40+ char base64/JWT run) becomes [REDACTED].
#
# Windows PowerShell 5.1, ASCII-only, Write-Output only (receipt captures
# stdout).

$ErrorActionPreference = 'Continue'

$acct = 'jzthjyz@gmail.com'
$acctMask = 'j***z@gmail.com'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace [regex]::Escape($acct), $acctMask } catch { }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    try { $s = $s -replace '[A-Za-z0-9+/=_-]{40,}', '[REDACTED]' } catch { }
    return $s
}

Write-Output '--- task t1: Antigravity login diagnosis (read-only) ---'
Write-Output ('account (masked): ' + $acctMask)

# ---------------------------------------------------------------- install
Write-Output '--- install locations ---'
$installDirs = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Antigravity'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Antigravity IDE'),
    'C:\Program Files\Antigravity',
    'C:\Program Files\Google\Antigravity',
    'C:\Program Files\Antigravity IDE'
)
foreach ($d in $installDirs) {
    if (Test-Path -LiteralPath $d) {
        $ver = ''
        $pkg = Join-Path $d 'resources\app\package.json'
        if (Test-Path -LiteralPath $pkg) {
            try { $ver = [string]((Get-Content -LiteralPath $pkg -Raw -Encoding UTF8 | ConvertFrom-Json).version) } catch { $ver = '(unreadable)' }
        }
        $exeVer = ''
        $exe = Get-ChildItem -LiteralPath $d -Filter '*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($exe) { try { $exeVer = [string]$exe.VersionInfo.ProductVersion } catch { } }
        Write-Output ('   install: PRESENT ' + $d + ' (package.json=' + $ver + ', exe=' + $exeVer + ')')
    } else {
        Write-Output ('   install: absent  ' + $d)
    }
}

# ------------------------------------------------------------------ data
Write-Output '--- data locations (top-level entries, newest 25 each) ---'
$dataDirs = @(
    (Join-Path $env:APPDATA 'Antigravity'),
    (Join-Path $env:APPDATA 'Antigravity IDE'),
    (Join-Path $env:USERPROFILE '.antigravity'),
    (Join-Path $env:USERPROFILE '.gemini\antigravity'),
    (Join-Path $env:USERPROFILE '.gemini\antigravity-ide')
)
foreach ($d in $dataDirs) {
    if (-not (Test-Path -LiteralPath $d)) {
        Write-Output ('   data dir absent: ' + $d)
        continue
    }
    Write-Output ('   data dir PRESENT: ' + $d)
    $subs = Get-ChildItem -LiteralPath $d -Force -ErrorAction SilentlyContinue | Select-Object -First 25
    foreach ($s in @($subs)) {
        $t = ''
        try { $t = $s.LastWriteTime.ToString('yyyy-MM-dd HH:mm') } catch { }
        if ($s.PSIsContainer) { $k = 'dir' } else { $k = ('file ' + $s.Length + 'B') }
        Write-Output ('      ' + $k.PadRight(14) + ' ' + $t + '  ' + (San ([string]$s.Name)))
    }
}

# ------------------------------------------------------------ processes
$procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)antigravity' }
if ($procs) {
    $pl = @($procs | Select-Object -First 8 | ForEach-Object { $_.Name + '(' + $_.Id + ')' })
    Write-Output ('processes: RUNNING - ' + ($pl -join ' '))
} else {
    Write-Output 'processes: none running'
}

# -------------------------------------------------- browsers / url handler
try {
    $uc = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice' -ErrorAction Stop
    Write-Output ('default browser (https ProgId): ' + (San ([string]$uc.ProgId)))
} catch {
    Write-Output 'default browser: (UserChoice not readable)'
}
foreach ($b in @('C:\Program Files\Google\Chrome\Application\chrome.exe', 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe')) {
    if (Test-Path -LiteralPath $b) {
        $cv = ''
        try { $cv = [string](Get-Item -LiteralPath $b).VersionInfo.ProductVersion } catch { }
        Write-Output ('chrome: PRESENT ' + $b + ' version=' + $cv)
    } else {
        Write-Output ('chrome: absent  ' + $b)
    }
}
Write-Output ('edge: ' + $(if (Test-Path 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe') { 'PRESENT' } else { 'absent' }))
foreach ($k in @('HKCU:\Software\Classes\antigravity', 'HKLM:\SOFTWARE\Classes\antigravity')) {
    if (Test-Path $k) {
        $cmd = ''
        try { $cmd = [string](Get-ItemProperty (Join-Path $k 'shell\open\command') -ErrorAction Stop).'(default)' } catch { }
        Write-Output ('url handler antigravity:// : REGISTERED at ' + $k + ' -> ' + (San $cmd))
    } else {
        Write-Output ('url handler antigravity:// : missing at ' + $k)
    }
}

# --------------------------------------------------------- WSA / WSL
try {
    $wsa = Get-AppxPackage -Name '*WindowsSubsystemForAndroid*' -ErrorAction SilentlyContinue
    if ($wsa) { Write-Output ('WSA: INSTALLED ' + [string]$wsa.Version + ' (a crashing WSA has blocked the login popup for other users)') }
    else { Write-Output 'WSA: not installed' }
} catch { Write-Output 'WSA: query failed' }
$wslExe = Get-Command wsl.exe -ErrorAction SilentlyContinue
Write-Output ('wsl.exe: ' + $(if ($wslExe) { 'present' } else { 'absent' }))
$wslcfg = Join-Path $env:USERPROFILE '.wslconfig'
if (Test-Path -LiteralPath $wslcfg) {
    Write-Output '.wslconfig:'
    foreach ($ln in @(Get-Content -LiteralPath $wslcfg -ErrorAction SilentlyContinue | Select-Object -First 12)) { Write-Output ('   ' + (San ([string]$ln))) }
} else {
    Write-Output '.wslconfig: not present (WSL default NAT networking)'
}

# ------------------------------------------------------------- proxy
Write-Output '--- proxy state ---'
foreach ($n in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY', 'http_proxy', 'https_proxy')) {
    $mv = [Environment]::GetEnvironmentVariable($n)
    if ($mv) { Write-Output ('   env ' + $n + '=' + (San ([string]$mv))) }
}
try {
    $winhttp = (& netsh winhttp show proxy 2>&1 | Out-String)
    $winhttp = ($winhttp -replace "`r?`n", ' | ').Trim()
    if ($winhttp) { Write-Output ('   winhttp: ' + (San $winhttp)) }
} catch { Write-Output '   winhttp: netsh failed' }
try {
    $is = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction Stop
    Write-Output ('   WinINET: ProxyEnable=' + [string]$is.ProxyEnable + ' ProxyServer=' + (San ([string]$is.ProxyServer)) + ' AutoConfigURL=' + (San ([string]$is.AutoConfigURL)))
} catch { Write-Output '   WinINET: unreadable' }
try {
    $gp = & git config --global --get http.proxy 2>$null
    if ($gp) { Write-Output ('   git http.proxy: ' + (San ([string]$gp))) } else { Write-Output '   git http.proxy: (none)' }
} catch { Write-Output '   git http.proxy: (git not found)' }

# ---------------------------------------------------------- network
Write-Output '--- network: DNS + direct TCP 443 (4s timeout each) ---'
function Test-Tcp443 {
    param([string]$h)
    $c = New-Object System.Net.Sockets.TcpClient
    try {
        $ar = $c.BeginConnect($h, 443, $null, $null)
        $ok = $ar.AsyncWaitHandle.WaitOne(4000)
        if (-not $ok) { return $false }
        try { $c.EndConnect($ar) } catch { return $false }
        return $c.Connected
    } catch {
        return $false
    } finally {
        try { $c.Close() } catch { }
    }
}
foreach ($h in @('github.com', 'www.google.com', 'accounts.google.com', 'oauth2.googleapis.com', 'antigravity.google', 'www.baidu.com')) {
    $ips = ''
    try {
        $ia = [System.Net.Dns]::GetHostAddresses($h)
        $ips = (@($ia | Select-Object -First 2 | ForEach-Object { $_.IPAddressToString }) -join ',')
    } catch { $ips = 'DNS-FAIL' }
    $tcp = Test-Tcp443 $h
    Write-Output ('   ' + $h.PadRight(24) + ' dns=' + $ips.PadRight(34) + ' tcp443=' + $(if ($tcp) { 'OK' } else { 'FAIL' }))
}

Write-Output '--- HTTPS probe (direct vs system proxy) ---'
foreach ($u in @('https://www.google.com/generate_204', 'https://accounts.google.com/')) {
    foreach ($mode in @('direct', 'systemproxy')) {
        $req = $null
        try { $req = [System.Net.HttpWebRequest]::Create($u) } catch { continue }
        $req.Method = 'HEAD'
        $req.Timeout = 8000
        $req.ReadWriteTimeout = 8000
        $req.AllowAutoRedirect = $false
        if ($mode -eq 'direct') { $req.Proxy = $null } else { $req.Proxy = [System.Net.WebRequest]::GetSystemWebProxy() }
        try {
            $resp = $req.GetResponse()
            $code = [int]$resp.StatusCode
            $dt = [string]$resp.Headers['Date']
            $resp.Close()
            Write-Output ('   ' + $mode.PadRight(12) + ' ' + $u + ' -> HTTP ' + $code + ' Date=' + $dt)
        } catch {
            $msg = [string]$_.Exception.Message
            if ($_.Exception.InnerException) { $msg = [string]$_.Exception.InnerException.Message }
            Write-Output ('   ' + $mode.PadRight(12) + ' ' + $u + ' -> FAIL ' + (San $msg))
        }
    }
}

# -------------------------------------------------------- clock skew
$skewNote = 'could not measure (no reachable server Date header)'
foreach ($u in @('https://www.google.com/generate_204', 'https://www.baidu.com/')) {
    try {
        $req2 = [System.Net.HttpWebRequest]::Create($u)
        $req2.Method = 'HEAD'
        $req2.Timeout = 6000
        $req2.Proxy = $null
        $r2 = $req2.GetResponse()
        $d2 = [string]$r2.Headers['Date']
        $r2.Close()
        if ($d2) {
            $srv = [DateTime]::Parse($d2, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
            $skewNote = ([math]::Round(([DateTime]::UtcNow - $srv).TotalMinutes, 1)).ToString() + ' min (local minus server; Google OAuth rejects more than about 5 min)'
            break
        }
    } catch { }
}
Write-Output ('clock skew: ' + $skewNote)

try { Write-Output ('system locale: ' + (Get-WinSystemLocale).Name + ' / culture: ' + (Get-Culture).Name + ' / timezone: ' + ([System.TimeZoneInfo]::Local.Id)) } catch { }

# ---------------------------------------------------------------- logs
Write-Output '--- Antigravity logs (newest 3 sessions, recursive) ---'
$logRoots = @((Join-Path $env:APPDATA 'Antigravity\logs'), (Join-Path $env:APPDATA 'Antigravity IDE\logs'))
$rxHi = '(?i)(location is not supported|not eligible|access_denied|invalid_grant|blocked|unusual traffic|quota|429|403|ETIMEDOUT|ENOTFOUND|ECONNREFUSED|ECONNRESET|certificate|tls|proxy|sign.?in|authenticat|oauth|callback|redirect|token|verify|account|error|fail)'
foreach ($lr in $logRoots) {
    if (-not (Test-Path -LiteralPath $lr)) { continue }
    Write-Output ('log root: ' + $lr)
    $sess = @(Get-ChildItem -LiteralPath $lr -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3)
    if ($sess.Count -eq 0) { Write-Output '   (no session folders)' ; continue }
    foreach ($s in $sess) {
        try { $lw = $s.LastWriteTime.ToString('yyyy-MM-dd HH:mm') } catch { $lw = '?' }
        Write-Output ('   session ' + (San $s.Name) + ' (last write ' + $lw + ')')
        $lfs = @(Get-ChildItem -LiteralPath $s.FullName -Filter '*.log' -Recurse -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 8)
        foreach ($lf in $lfs) { Write-Output ('      log ' + (San $lf.Name) + ' (' + $lf.Length + ' B)') }
    }
    Write-Output '   matching lines (masked, deduped, newest 2 sessions):'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    $shown = 0
    $acctHits = 0
    foreach ($s in @($sess | Select-Object -First 2)) {
        $lfs = @(Get-ChildItem -LiteralPath $s.FullName -Filter '*.log' -Recurse -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 8)
        foreach ($lf in $lfs) {
            try { $txt = Get-Content -LiteralPath $lf.FullName -Raw -Encoding UTF8 -ErrorAction Stop } catch { continue }
            foreach ($ln in ($txt -split "`r?`n")) {
                if ($shown -ge 60) { break }
                $hasAcct = $false
                if ($ln -and $ln.Contains($acct)) { $acctHits++ ; $hasAcct = $true }
                if ($hasAcct -or ($ln -match $rxHi)) {
                    $m = (San $ln).Trim()
                    if ($m.Length -gt 220) { $m = $m.Substring(0, 220) + ' ...' }
                    if ($seen.Add($m)) {
                        $tag = ''
                        if ($hasAcct) { $tag = '[ACCT] ' }
                        Write-Output ('      [' + (San $lf.Name) + '] ' + $tag + $m)
                        $shown++
                    }
                }
            }
            if ($shown -ge 60) { break }
        }
        if ($shown -ge 60) { break }
    }
    Write-Output ('   account lines found: ' + $acctHits + ' (lines above already masked)')
    if ($shown -eq 0) { Write-Output '      (no matching lines)' }
    $newBig = $null
    if ($sess.Count -gt 0) {
        $newBig = Get-ChildItem -LiteralPath $sess[0].FullName -Filter '*.log' -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }
    if ($newBig) {
        Write-Output ('   tail of newest log ' + (San $newBig.Name) + ' (last 25 lines, masked):')
        try {
            $tl = @(Get-Content -LiteralPath $newBig.FullName -Tail 25 -Encoding UTF8 -ErrorAction Stop)
            foreach ($ln in $tl) { Write-Output ('      ' + (San ([string]$ln))) }
        } catch { Write-Output '      (unreadable)' }
    }
}

Write-Output '--- known Antigravity login blockers (for reference when reading this receipt) ---'
Write-Output '   1. region: Google blocks sign-in / API from unsupported locations (log: User location is not supported)'
Write-Output '   2. the OAuth callback uses Chrome (CDP); Chrome absent = silent fail for some users'
Write-Output '   3. stale auth state: clear %APPDATA%\Antigravity Session Storage + Local Storage after signing out'
Write-Output '   4. proxy/VPN: some VPN exit IPs are blocked; a crashing WSA has blocked the popup; clock drift > 5 min breaks OAuth'
Write-Output '--- task t1 done (read-only, nothing modified) ---'
exit 0
