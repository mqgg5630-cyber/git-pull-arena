# t1_fix_antigravity.ps1 - round 23 task 1: apply the round-22 fix for the
# Antigravity login failure. The cause: the IDE's backend dials Google APIs
# directly, bypassing the system proxy, and direct connections are blocked.
#
# What this does (with a backup first):
#   1. reads the system proxy from WinINET (ProxyEnable/ProxyServer)
#   2. backs up and patches settings.json of "Antigravity IDE" (and the legacy
#      "Antigravity" dir if present) with:
#         http.proxy        = http://127.0.0.1:10808   (from WinINET)
#         http.proxySupport = on
#         http.noProxy      = localhost,127.0.0.1
#   3. reports proxy env var scopes (User vs Machine)
#   4. dumps auth.log + region-error grep from the newest sessions (masked)
#
# It does NOT kill or relaunch Antigravity - the user reopens it afterwards.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

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

try { [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072 } catch { }

Write-Output '--- task t1 (fix): Antigravity proxy patch ---'

# ------------------------------------------------------------ proxy source
$proxyUrl = ''
try {
    $is = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction Stop
    $ps = [string]$is.ProxyServer
    if (([int]$is.ProxyEnable -eq 1) -and $ps) {
        if ($ps -notmatch '^[a-z]+://') { $proxyUrl = 'http://' + $ps }
        else { $proxyUrl = $ps }
    }
} catch { }
if (-not $proxyUrl) {
    foreach ($n in @('HTTP_PROXY', 'HTTPS_PROXY')) {
        $v = [Environment]::GetEnvironmentVariable($n, 'User')
        if (-not $v) { $v = [Environment]::GetEnvironmentVariable($n, 'Machine') }
        if ($v) { $proxyUrl = $v; break }
    }
}
if (-not $proxyUrl) { $proxyUrl = 'http://127.0.0.1:10808' }
Write-Output ('proxy to use: ' + $proxyUrl + ' (WinINET first, env fallback)')

foreach ($n in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY')) {
    $uv = [Environment]::GetEnvironmentVariable($n, 'User')
    $mv = [Environment]::GetEnvironmentVariable($n, 'Machine')
    Write-Output ('   env ' + $n + ' User=' + $(if ($uv) { $uv } else { '(unset)' }) + ' Machine=' + $(if ($mv) { $mv } else { '(unset)' }))
}

# probe the proxy is actually alive before writing it into settings
$alive = $false
try {
    $req = [System.Net.HttpWebRequest]::Create('https://www.google.com/generate_204')
    $req.Method = 'HEAD'
    $req.Timeout = 8000
    $req.Proxy = New-Object System.Net.WebProxy($proxyUrl)
    $resp = $req.GetResponse()
    $alive = ([int]$resp.StatusCode -eq 204)
    $resp.Close()
} catch { $alive = $false }
Write-Output ('proxy alive check (via ' + $proxyUrl + ' -> google generate_204): ' + $(if ($alive) { 'OK' } else { 'FAIL - patching anyway (proxy client may be off right now)' }))

# ------------------------------------------------------------- patch files
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$targets = @(
    (Join-Path $env:APPDATA 'Antigravity IDE\User\settings.json'),
    (Join-Path $env:APPDATA 'Antigravity\User\settings.json')
)
$patchedAny = $false
foreach ($sf in $targets) {
    if (-not (Test-Path -LiteralPath $sf)) {
        Write-Output ('   settings: absent - creating: ' + $sf)
        try {
            $dir = Split-Path -Parent $sf
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
            $minimal = '{' + "`r`n" + '  "http.proxy": "' + $proxyUrl + '",' + "`r`n" + '  "http.proxySupport": "on",' + "`r`n" + '  "http.noProxy": ["localhost", "127.0.0.1"]' + "`r`n" + '}'
            [System.IO.File]::WriteAllText($sf, $minimal, (New-Object System.Text.UTF8Encoding($false)))
            $patchedAny = $true
            Write-Output '   settings: CREATED with proxy entries'
        } catch {
            Write-Output ('   [FAIL] could not create settings: ' + (San $_.Exception.Message))
        }
        continue
    }
    Write-Output ('   settings: patching ' + $sf)
    $raw = ''
    try { $raw = Get-Content -LiteralPath $sf -Raw -Encoding UTF8 } catch { $raw = '' }
    if ($raw.Trim()) {
        Write-Output '   settings BEFORE (masked):'
        foreach ($ln in (@($raw -split "`r?`n") | Select-Object -First 40)) { Write-Output ('      ' + (San ([string]$ln))) }
    }
    $bak = $sf + '.bak-' + $stamp
    try {
        Copy-Item -LiteralPath $sf -Destination $bak -Force
        Write-Output ('   backup: ' + $bak)
    } catch {
        Write-Output ('   [FAIL] backup failed - NOT touching this file: ' + (San $_.Exception.Message))
        continue
    }
    $okPatched = $false
    try {
        $cfg = $null
        try { $cfg = $raw | ConvertFrom-Json } catch { $cfg = $null }
        if ($null -ne $cfg) {
            # clean JSON - edit as object
            if ($cfg.PSObject.Properties['http.proxy']) { $cfg.'http.proxy' = $proxyUrl }
            else { $cfg | Add-Member -NotePropertyName 'http.proxy' -NotePropertyValue $proxyUrl }
            if ($cfg.PSObject.Properties['http.proxySupport']) { $cfg.'http.proxySupport' = 'on' }
            else { $cfg | Add-Member -NotePropertyName 'http.proxySupport' -NotePropertyValue 'on' }
            $noP = @('localhost', '127.0.0.1')
            if ($cfg.PSObject.Properties['http.noProxy']) { $cfg.'http.noProxy' = $noP }
            else { $cfg | Add-Member -NotePropertyName 'http.noProxy' -NotePropertyValue $noP }
            $out = $cfg | ConvertTo-Json -Depth 30
            [System.IO.File]::WriteAllText($sf, $out + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
            $okPatched = $true
            $method = 'json'
        } else {
            # JSONC (comments) - text-level edit
            $txt = $raw
            $add = '  "http.proxy": "' + $proxyUrl + '",' + "`r`n" + '  "http.proxySupport": "on",' + "`r`n" + '  "http.noProxy": ["localhost", "127.0.0.1"]'
            if ($txt -match '"http\.proxy"\s*:') {
                $txt = [regex]::Replace($txt, '("http\.proxy"\s*:\s*")[^"]*(")', ('${1}' + $proxyUrl + '${2}'), 1)
                if ($txt -notmatch '"http\.proxySupport"') {
                    $txt = [regex]::Replace($txt, '("http\.proxy"\s*:\s*"[^"]*")', ('${1},' + "`r`n" + '  "http.proxySupport": "on"'), 1)
                }
            } else {
                $i = $txt.LastIndexOf('}')
                if ($i -ge 0) {
                    $before = $txt.Substring(0, $i).TrimEnd()
                    if ($before.EndsWith(',')) { $txt = $before + "`r`n" + $add + "`r`n}" + $txt.Substring($i + 1) }
                    else { $txt = $before.TrimEnd() + "`r`n" + $add + "`r`n}" + $txt.Substring($i + 1) }
                } else {
                    $txt = '{' + "`r`n" + $add + "`r`n" + '}'
                }
            }
            [System.IO.File]::WriteAllText($sf, $txt, (New-Object System.Text.UTF8Encoding($false)))
            $okPatched = $true
            $method = 'jsonc-text'
        }
    } catch {
        Write-Output ('   [FAIL] patch threw: ' + (San $_.Exception.Message))
    }
    if ($okPatched) {
        $patchedAny = $true
        Write-Output ('   settings PATCHED (' + $method + ')')
        $after = ''
        try { $after = Get-Content -LiteralPath $sf -Raw -Encoding UTF8 } catch { $after = '' }
        Write-Output '   settings AFTER (masked):'
        foreach ($ln in (@($after -split "`r?`n") | Select-Object -First 40)) { Write-Output ('      ' + (San ([string]$ln))) }
    }
}
Write-Output ('patched at least one settings file: ' + $patchedAny)

# ------------------------------------------------ auth.log + region errors
Write-Output '--- auth.log from newest sessions (masked) ---'
foreach ($lr in @((Join-Path $env:APPDATA 'Antigravity IDE\logs'), (Join-Path $env:APPDATA 'Antigravity\logs'))) {
    if (-not (Test-Path -LiteralPath $lr)) { continue }
    Write-Output ('log root: ' + $lr)
    $sess = @(Get-ChildItem -LiteralPath $lr -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3)
    foreach ($s in $sess) {
        $al = Join-Path $s.FullName 'auth.log'
        if (Test-Path -LiteralPath $al) {
            Write-Output ('   auth.log of session ' + (San $s.Name) + ':')
            try {
                $lines = @(Get-Content -LiteralPath $al -Encoding UTF8 -ErrorAction Stop | Select-Object -Last 50)
                foreach ($ln in $lines) { Write-Output ('      ' + (San ([string]$ln))) }
            } catch { Write-Output '      (unreadable)' }
        } else {
            Write-Output ('   session ' + (San $s.Name) + ': no auth.log')
        }
        # region / eligibility errors anywhere in this session
        $regionHits = 0
        $regionSamples = @()
        $allLogs = @(Get-ChildItem -LiteralPath $s.FullName -Filter '*.log' -Recurse -ErrorAction SilentlyContinue)
        foreach ($lf in $allLogs) {
            try { $t = Get-Content -LiteralPath $lf.FullName -Raw -Encoding UTF8 -ErrorAction Stop } catch { continue }
            foreach ($m in [regex]::Matches($t, '(?i).{0,60}(location is not supported|not eligible|unsupported region|country not supported).{0,60}')) {
                $regionHits++
                if ($regionSamples.Count -lt 5) { $regionSamples += ((San $m.Value).Trim() + ' [' + (San $lf.Name) + ']') }
            }
        }
        Write-Output ('   region/eligibility error lines in this session: ' + $regionHits)
        foreach ($r in $regionSamples) { Write-Output ('      ' + $r) }
    }
}

Write-Output '--- next steps for the user (manual) ---'
Write-Output ('   1. close Antigravity completely (File -> Exit), reopen it, sign in with ' + $acctMask)
Write-Output '   2. if it still fails: the language server ignores the proxy - enable TUN mode in the'
Write-Output '      proxy client (v2rayN: Settings -> Tun mode) so direct connections are proxied too,'
Write-Output '      then reopen Antigravity'
Write-Output '--- task t1 (fix) done - settings patched with backup, nothing else modified ---'
exit 0
