# desk_antigravity_verify.ps1 - runs ON THE DESKTOP. Soak verification of
# the v2 proxy fix: count failure signatures in the CURRENT (post-restart)
# logs, and look for positive auth/backend signals. READ-ONLY.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{40,}', '[REDACTED]' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    try { $s = $s -replace '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+', '[EMAIL]' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop Antigravity soak verification ---'

foreach ($app in @('Antigravity', 'Antigravity IDE')) {
    $ld = Join-Path $env:APPDATA ($app + '\logs')
    if (-not (Test-Path -LiteralPath $ld)) { continue }
    foreach ($lf in @(Get-ChildItem -LiteralPath $ld -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 2)) {
        $lines = @(Get-Content -LiteralPath $lf.FullName -ErrorAction SilentlyContinue)
        $dial = @($lines | Select-String -Pattern 'dial tcp' )
        $loop = @($lines | Select-String -Pattern 'ERR_TIMED_OUT')
        $loopLocal = @($lines | Select-String -Pattern 'https://127\.0\.0\.1:\d+.*ERR_TIMED_OUT')
        L ('   ' + (San $lf.Name) + ' (' + $lf.LastWriteTime.ToString('HH:mm:ss') + ', ' + $lines.Count + ' lines):')
        L ('      dial-tcp-direct-errors = ' + $dial.Count)
        L ('      err-timed-out total    = ' + $loop.Count + ' (loopback callback: ' + $loopLocal.Count + ')')
        $pos = @($lines | Select-String -Pattern 'signed in|Signed in|oauth.*success|token.*obtain|userInfo|availableModels|loadCodeAssist' | Select-Object -Last 4)
        if (@($pos).Count -gt 0) {
            L '      positive signals:'
            foreach ($p in $pos) { L ('        ' + (San ([string]$p.Line).Trim())) }
        } else { L '      positive signals: none yet (login button not clicked?)' }
    }
}

# backend connectivity through the proxy, straight from this box
$r = & curl.exe -sS -m 10 -x http://127.0.0.1:10808 -o NUL -w "%{http_code}" https://oauth2.googleapis.com 2>&1
L ('   oauth2.googleapis.com via local proxy: HTTP ' + (San ([string]$r)))
$r2 = & curl.exe -sS -m 10 -x http://127.0.0.1:10808 -o NUL -w "%{http_code}" https://daily-cloudcode-pa.googleapis.com 2>&1
L ('   daily-cloudcode-pa via local proxy:   HTTP ' + (San ([string]$r2)))

$procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'Antigravity' })
L ('   antigravity processes: ' + $procs.Count)
L '--- soak verification done ---'
