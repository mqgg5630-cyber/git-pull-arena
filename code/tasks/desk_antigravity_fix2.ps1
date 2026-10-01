# desk_antigravity_fix2.ps1 - runs ON THE DESKTOP. v2 of the Antigravity
# proxy fix (v1 skipped because the User dir does not exist on this
# 2.12.2 install):
#   1. CREATE Roaming\Antigravity\User\ (+ Antigravity IDE variant) and
#      write settings.json with http.proxy/proxySupport/noProxy
#      (noProxy stops the login window's 127.0.0.1 callback from being
#      routed through the proxy - that ERR_TIMED_OUT was the login breaker)
#   2. setx user-scope HTTP_PROXY/HTTPS_PROXY/NO_PROXY (the Go language
#      server only honors environment variables, not VS Code settings)
#   3. restart Antigravity, wait, and grep the fresh logs for the two
#      failure signatures (dial tcp direct / 127.0.0.1 callback timeout)
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{40,}', '[REDACTED]' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop Antigravity proxy fix v2 ---'
$proxy = 'http://127.0.0.1:10808'

# ------------------------------------------------ 1. settings.json (create dirs)
foreach ($app in @('Antigravity', 'Antigravity IDE')) {
    $userDir = Join-Path $env:APPDATA ($app + '\User')
    $sf = Join-Path $userDir 'settings.json'
    New-Item -ItemType Directory -Force -Path $userDir | Out-Null
    $json = New-Object PSObject
    if (Test-Path -LiteralPath $sf) {
        $bak = $sf + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
        Copy-Item -LiteralPath $sf -Destination $bak -Force
        L ('   backup: ' + (San $bak))
        try { $json = Get-Content -LiteralPath $sf -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $json = New-Object PSObject }
    }
    if ($json.PSObject.Properties['http.proxy']) { $json.'http.proxy' = $proxy } else { $json | Add-Member -NotePropertyName 'http.proxy' -NotePropertyValue $proxy }
    if ($json.PSObject.Properties['http.proxySupport']) { $json.'http.proxySupport' = 'on' } else { $json | Add-Member -NotePropertyName 'http.proxySupport' -NotePropertyValue 'on' }
    if ($json.PSObject.Properties['http.noProxy']) { $json.'http.noProxy' = 'localhost,127.0.0.1' } else { $json | Add-Member -NotePropertyName 'http.noProxy' -NotePropertyValue 'localhost,127.0.0.1' }
    $json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sf -Encoding UTF8
    L ('   settings.json written: ' + $sf)
}

# ------------------------------------------------ 2. user env vars (Go backend)
& setx HTTP_PROXY $proxy | Out-Null
& setx HTTPS_PROXY $proxy | Out-Null
& setx NO_PROXY 'localhost,127.0.0.1' | Out-Null
L ('   setx user env: HTTP_PROXY/HTTPS_PROXY=' + $proxy + ' NO_PROXY=localhost,127.0.0.1')
# also patch this session (the relaunch below inherits from the task env, but belt+braces)
$env:HTTP_PROXY = $proxy; $env:HTTPS_PROXY = $proxy; $env:NO_PROXY = 'localhost,127.0.0.1'

# ------------------------------------------------ 3. restart Antigravity
$agExe = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
try { & taskkill /f /im Antigravity.exe 2>&1 | Out-Null } catch { }
Start-Sleep -Seconds 3
try {
    $action = New-ScheduledTaskAction -Execute $agExe
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 8)
    Register-ScheduledTask -TaskName 'agyrelaunch' -Action $action -Principal $principal -Settings $settings -Force | Out-Null
    Start-ScheduledTask -TaskName 'agyrelaunch'
    L '   Antigravity relaunched'
} catch { L ('   [WARN] relaunch: ' + (San $_.Exception.Message)) }

# ------------------------------------------------ 4. verify: wait + grep fresh logs
Start-Sleep -Seconds 75
$procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'Antigravity' })
L ('   antigravity processes now: ' + $procs.Count)
foreach ($app in @('Antigravity', 'Antigravity IDE')) {
    $ld = Join-Path $env:APPDATA ($app + '\logs')
    if (-not (Test-Path -LiteralPath $ld)) { continue }
    foreach ($lf in @(Get-ChildItem -LiteralPath $ld -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 2)) {
        $fresh = @()
        $cutoff = (Get-Date).AddSeconds(-90)
        $fresh = @(Get-Content -LiteralPath $lf.FullName -ErrorAction SilentlyContinue | Where-Object { $true })
        $dialErr = @($fresh | Select-String -SimpleMatch 'dial tcp' | Select-Object -Last 3)
        $cbErr = @($fresh | Select-String -SimpleMatch '127.0.0.1' -SimpleMatch 'ERR_TIMED_OUT' | Select-Object -Last 3)
        L ('   ' + (San $lf.Name) + ': dial-tcp-errors=' + $dialErr.Count + ' loopback-timeout-errors=' + $cbErr.Count)
        foreach ($e in $dialErr) { L ('      recent: ' + (San ([string]$e.Line).Trim()).Substring(0, [Math]::Min(200, (San ([string]$e.Line).Trim()).Length))) }
    }
}
# env sanity in a fresh process
$envNow = & cmd /c 'echo %HTTPS_PROXY% / %NO_PROXY%'
L ('   fresh-process env: ' + (San ([string]$envNow).Trim()))
L '--- desktop fix v2 done ---'
