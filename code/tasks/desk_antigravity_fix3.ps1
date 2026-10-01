# desk_antigravity_fix3.ps1 - runs ON THE DESKTOP. v3: make the proxy env
# REACH the Antigravity processes by launching through an explicit cmd
# wrapper (Task Scheduler relaunch did not inherit the setx user env, so
# the Go language server kept direct-dialing -> TLS garbage). Also dumps
# ProxyOverride for reference. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{40,}', '[REDACTED]' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop Antigravity proxy fix v3 (wrapper launch) ---'

$proxy = 'http://127.0.0.1:10808'
$agExe = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
if (-not (Test-Path -LiteralPath $agExe)) { L '   [FAIL] Antigravity.exe missing'; exit 2 }

# ------------------------------------------------ 1. write the launch wrapper
$wrapper = 'F:\fig1_rebuild\agy_proxy.cmd'
$wLines = @(
    '@echo off',
    ('set HTTP_PROXY=' + $proxy),
    ('set HTTPS_PROXY=' + $proxy),
    ('set ALL_PROXY=' + $proxy),
    'set NO_PROXY=localhost,127.0.0.1',
    'set http_proxy=' + $proxy,
    'set https_proxy=' + $proxy,
    'set no_proxy=localhost,127.0.0.1',
    ('start "" "' + $agExe + '"')
)
[IO.File]::WriteAllLines($wrapper, $wLines, (New-Object System.Text.ASCIIEncoding))
L ('   wrapper written: ' + $wrapper)

# ------------------------------------------------ 2. repoint the relaunch task
try { & taskkill /f /im Antigravity.exe 2>&1 | Out-Null } catch { }
Start-Sleep -Seconds 3
try {
    $action = New-ScheduledTaskAction -Execute $wrapper
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 8)
    Register-ScheduledTask -TaskName 'agyrelaunch' -Action $action -Principal $principal -Settings $settings -Force | Out-Null
    Start-ScheduledTask -TaskName 'agyrelaunch'
    L '   Antigravity relaunched through the proxy wrapper'
} catch { L ('   [FAIL] relaunch: ' + (San $_.Exception.Message)); exit 2 }

# ------------------------------------------------ 3. reference: WinINET bypass
try {
    $w = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    L ('   WinINET ProxyOverride=' + (San ([string]$w.ProxyOverride)))
} catch { }

# ------------------------------------------------ 4. wait + check new TLS-garbage errors
Start-Sleep -Seconds 75
$procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'Antigravity' })
L ('   antigravity processes: ' + $procs.Count)
foreach ($app in @('Antigravity')) {
    $ld = Join-Path $env:APPDATA ($app + '\logs')
    foreach ($lf in @(Get-ChildItem -LiteralPath $ld -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 2)) {
        $lines = @(Get-Content -LiteralPath $lf.FullName -ErrorAction SilentlyContinue)
        # only lines from the last 3 minutes
        $cut = (Get-Date).AddMinutes(-3)
        $recent = @()
        foreach ($ln in $lines) {
            if ($ln -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})') {
                try { $t = [DateTime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null) } catch { $t = $null }
                if ($t -and $t -ge $cut) { $recent += $ln }
            }
        }
        $garbage = @($recent | Select-String -Pattern 'record with version 15')
        $dial = @($recent | Select-String -Pattern 'dial tcp')
        L ('   ' + (San $lf.Name) + ': recent3min lines=' + $recent.Count + ' tls-garbage=' + $garbage.Count + ' dial-tcp=' + $dial.Count)
        foreach ($g in ($garbage | Select-Object -First 3)) { L ('      ' + (San ([string]$g.Line).Trim())) }
    }
}
# language_server.log has a different timestamp format - count signatures in its tail
$lsLog = Join-Path $env:APPDATA 'Antigravity\logs\language_server.log'
if (Test-Path -LiteralPath $lsLog) {
    $tail = @(Get-Content -LiteralPath $lsLog -Tail 25 -ErrorAction SilentlyContinue)
    $g2 = @($tail | Select-String -Pattern 'record with version 15')
    $d2 = @($tail | Select-String -Pattern 'dial tcp')
    L ('   language_server tail25: tls-garbage=' + $g2.Count + ' dial-tcp=' + $d2.Count)
    foreach ($g in ($g2 | Select-Object -First 2)) { L ('      ' + (San ([string]$g.Line).Trim())) }
}
L '--- desktop fix v3 done ---'
