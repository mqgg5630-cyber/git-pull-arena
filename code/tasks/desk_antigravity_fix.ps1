# desk_antigravity_fix.ps1 - runs ON THE DESKTOP (staged via F$). Applies
# the r23-style proxy fix for Antigravity: test the local proxy against
# Google, fall back to the laptop proxy over Tailscale if needed, patch
# User\settings.json (http.proxy/proxySupport/noProxy) with a backup,
# restart Antigravity via a one-shot interactive task, then tail the fresh
# logs. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{40,}', '[REDACTED]' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop Antigravity proxy fix ---'

# ------------------------------------------------ 1. pick a working proxy
$proxy = $null
$r = & curl.exe -sS -m 10 -x http://127.0.0.1:10808 -o NUL -w "%{http_code}" https://accounts.google.com 2>&1
$code = [string]$r
L ('   local proxy 127.0.0.1:10808 -> accounts.google.com: HTTP ' + (San $code))
if ($code -match '^[23]\d\d$') { $proxy = 'http://127.0.0.1:10808' }
else {
    $r2 = & curl.exe -sS -m 12 -x http://100.71.123.19:10808 -o NUL -w "%{http_code}" https://accounts.google.com 2>&1
    $code2 = [string]$r2
    L ('   laptop proxy 100.71.123.19:10808 -> accounts.google.com: HTTP ' + (San $code2))
    if ($code2 -match '^[23]\d\d$') { $proxy = 'http://100.71.123.19:10808' }
}
if (-not $proxy) { L '   [FAIL] no working proxy found (neither local nor laptop)'; exit 2 }
L ('   chosen proxy: ' + $proxy)

# ------------------------------------------------ 2. patch settings.json
$targets = @(
    (Join-Path $env:APPDATA 'Antigravity\User\settings.json'),
    (Join-Path $env:APPDATA 'Antigravity IDE\User\settings.json')
)
foreach ($sf in $targets) {
    $dir = Split-Path -Parent $sf
    if (-not (Test-Path -LiteralPath $dir)) { L ('   skip (no dir): ' + $sf); continue }
    $bak = $sf + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    if (Test-Path -LiteralPath $sf) {
        Copy-Item -LiteralPath $sf -Destination $bak -Force
        L ('   backup: ' + (San $bak))
        try { $json = Get-Content -LiteralPath $sf -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $json = New-Object PSObject }
    } else { $json = New-Object PSObject; L ('   (creating new settings.json)' ) }
    # set properties
    if ($json.PSObject.Properties['http.proxy']) { $json.'http.proxy' = $proxy } else { $json | Add-Member -NotePropertyName 'http.proxy' -NotePropertyValue $proxy }
    if ($json.PSObject.Properties['http.proxySupport']) { $json.'http.proxySupport' = 'on' } else { $json | Add-Member -NotePropertyName 'http.proxySupport' -NotePropertyValue 'on' }
    $noProxy = 'localhost,127.0.0.1'
    if ($json.PSObject.Properties['http.noProxy']) { $json.'http.noProxy' = $noProxy } else { $json | Add-Member -NotePropertyName 'http.noProxy' -NotePropertyValue $noProxy }
    $json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sf -Encoding UTF8
    L ('   PATCHED: ' + $sf)
    L ('      http.proxy = ' + $proxy + ' , http.proxySupport = on , http.noProxy = ' + $noProxy)
}

# ------------------------------------------------ 3. restart Antigravity
$agExe = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
if (-not (Test-Path -LiteralPath $agExe)) { L ('   [WARN] Antigravity.exe not found at expected path: ' + $agExe); exit 2 }
try { & taskkill /f /im Antigravity.exe 2>&1 | Out-Null } catch { }
Start-Sleep -Seconds 3
try {
    $action = New-ScheduledTaskAction -Execute $agExe
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 8)
    Register-ScheduledTask -TaskName 'agyrelaunch' -Action $action -Principal $principal -Settings $settings -Force | Out-Null
    Start-ScheduledTask -TaskName 'agyrelaunch'
    L '   Antigravity relaunched (interactive task agyrelaunch)'
} catch { L ('   [WARN] relaunch: ' + (San $_.Exception.Message)) }

# ------------------------------------------------ 4. wait + check fresh logs
Start-Sleep -Seconds 50
$procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'Antigravity' })
L ('   antigravity processes now: ' + $procs.Count)
foreach ($ld in @((Join-Path $env:APPDATA 'Antigravity\logs'), (Join-Path $env:APPDATA 'Antigravity IDE\logs'))) {
    if (-not (Test-Path -LiteralPath $ld)) { continue }
    $logs = @(Get-ChildItem -LiteralPath $ld -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 2)
    foreach ($lf in $logs) {
        L ('   --- fresh tail: ' + (San $lf.Name) + ' (' + $lf.LastWriteTime.ToString('HH:mm:ss') + ') ---')
        $tail = @(Get-Content -LiteralPath $lf.FullName -Tail 12 -ErrorAction SilentlyContinue)
        foreach ($t in $tail) { L ('      ' + (San ([string]$t).Trim())) }
    }
}
L '--- desktop fix done (user completes login in the reopened window if prompted) ---'
