# t1_antigravity_verify.ps1 - round 25 task: after the user retried the
# login (and the settings.json proxy patch did NOT fix it), verify what the
# new logs say and whether direct connections are now proxied (Tun mode).
# READ-ONLY.
#
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

$acct = 'jzthjyz@gmail.com'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace [regex]::Escape($acct), 'j***z@gmail.com' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    try { $s = $s -replace '[A-Za-z0-9+/=_-]{40,}', '[REDACTED]' } catch { }
    return $s
}

Write-Output '--- task t1 (verify): Antigravity state after the retry ---'

# ------------------------------------------------ settings still patched?
foreach ($sf in @((Join-Path $env:APPDATA 'Antigravity IDE\User\settings.json'), (Join-Path $env:APPDATA 'Antigravity\User\settings.json'))) {
    if (Test-Path -LiteralPath $sf) {
        $raw = ''
        try { $raw = Get-Content -LiteralPath $sf -Raw -Encoding UTF8 } catch { }
        $hasProxy = $raw -match '"http\.proxy"'
        Write-Output ('   ' + $sf + ' : http.proxy present = ' + $hasProxy)
    }
}

# ------------------------------------------------------ direct connectivity
Write-Output '--- connectivity now (direct vs proxy, 4s each) ---'
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
foreach ($h in @('accounts.google.com', 'oauth2.googleapis.com', 'www.google.com')) {
    $t = Test-Tcp443 $h
    Write-Output ('   direct tcp443 ' + $h.PadRight(24) + ' = ' + $(if ($t) { 'OK (proxied at network level / Tun ON?)' } else { 'FAIL (still blocked - Tun mode not on)' }))
}

# -------------------------------------------------------------- v2rayN
$vp = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)v2ray|xray|clash|sing' }
if ($vp) {
    $pl = @($vp | Select-Object -First 6 | ForEach-Object { $_.Name + '(' + $_.Id + ')' })
    Write-Output ('   proxy client running: ' + ($pl -join ' '))
} else {
    Write-Output '   proxy client: NO v2ray/xray/clash process seen'
}

# ------------------------------------------------------ newest auth.log
Write-Output '--- auth.log, newest 3 sessions of Antigravity IDE ---'
$lr = Join-Path $env:APPDATA 'Antigravity IDE\logs'
if (Test-Path -LiteralPath $lr) {
    $sess = @(Get-ChildItem -LiteralPath $lr -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3)
    foreach ($s in $sess) {
        Write-Output ('   session ' + (San $s.Name) + ' (last write ' + $s.LastWriteTime.ToString('yyyy-MM-dd HH:mm') + ')')
        $al = Join-Path $s.FullName 'auth.log'
        if (Test-Path -LiteralPath $al) {
            try {
                $lines = @(Get-Content -LiteralPath $al -Encoding UTF8 -ErrorAction Stop | Select-Object -Last 30)
                foreach ($ln in $lines) { Write-Output ('      ' + (San ([string]$ln))) }
            } catch { Write-Output '      (unreadable)' }
        } else {
            Write-Output '      no auth.log in this session'
        }
    }
} else {
    Write-Output '   no logs dir'
}

Write-Output '--- decision rule ---'
Write-Output '   if direct tcp443 to google = OK now: reopen Antigravity and sign in - it should work'
Write-Output '   if still FAIL: enable Tun mode in v2rayN (needs admin once), then reopen Antigravity'
exit 0
