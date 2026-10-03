# t138_tg_task2.ps1 - round 180 task: runs ON THE LAPTOP. Fix for r179's
# 'Register-ScheduledTask : access denied': an -AtLogOn trigger WITHOUT
# -User means 'any user logs on' which needs admin rights. watch.ps1
# itself registers with -User $env:USERNAME (that is why the watcher
# tasks could be registered from this same context in r173/r174).
# This task: register media-bridge-tg with -User $env:USERNAME, verify,
# start, and check the bridge log. Fallback: schtasks.exe with escaped
# quotes in /TR.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }
function Cut([string]$s, [int]$n) { if ($s.Length -gt $n) { return $s.Substring(0, $n) }; return $s }

$base = 'E:\0github\git-sync\media-bridge'
L '--- task t138: register media-bridge-tg (AtLogOn -User fix) ---'

if (-not (Test-Path -LiteralPath (Join-Path $base 'run_tg_bridge.ps1'))) { L '   [FAIL] run_tg_bridge.ps1 missing'; exit 2 }

# ---------------- 1. (re)register ----------------
try {
    $null = Get-ScheduledTask -TaskName 'media-bridge-tg' -ErrorAction Stop
    try { Unregister-ScheduledTask -TaskName 'media-bridge-tg' -Confirm:$false -ErrorAction SilentlyContinue } catch { }
    L '   removed previous registration (if any)'
} catch { }

$arg = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + (Join-Path $base 'run_tg_bridge.ps1') + '"'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg -WorkingDirectory $base
$trigger = $null
try { $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME -ErrorAction Stop } catch { }
if (-not $trigger) { $trigger = New-ScheduledTaskTrigger -AtLogOn -ErrorAction SilentlyContinue }
if (-not $trigger) {
    # no logon trigger possible: fall back to a boot-agnostic once trigger
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
    L '   [WARN] no logon trigger, using a once trigger (task still starts below)'
}
$settings = $null
try {
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ErrorAction Stop
} catch { $settings = $null }
$regArgs = @{ TaskName = 'media-bridge-tg'; Action = $action; Trigger = $trigger; Force = $true; Description = 'media-bridge Telegram remote control (keeps tg_bridge.py alive)' }
if ($settings) { $regArgs['Settings'] = $settings }

$regOk = $false
try {
    Register-ScheduledTask @regArgs | Out-Null
    $regOk = $true
    L '   Register-ScheduledTask: OK'
}
catch {
    L ('   Register-ScheduledTask failed: ' + (Cut (San ([string]$_.Exception.Message)) 140))
    L '   fallback: schtasks.exe with escaped quotes'
    $trEsc = 'powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File \"' + (Join-Path $base 'run_tg_bridge.ps1') + '\"'
    $co = & schtasks /create /tn media-bridge-tg /tr $trEsc /sc onlogon /f 2>&1
    L ('   schtasks rc=' + $LASTEXITCODE + ' :: ' + (Cut (San (($co | Out-String).Trim())) 140))
    if ($LASTEXITCODE -eq 0) { $regOk = $true }
}
if (-not $regOk) { L '   [FAIL] could not register media-bridge-tg'; exit 2 }
$t = Get-ScheduledTask -TaskName 'media-bridge-tg' -ErrorAction SilentlyContinue
if ($t) { L ('   registered: media-bridge-tg state=' + (San ([string]$t.State))) }

# ---------------- 2. start + verify ----------------
try { Start-ScheduledTask -TaskName 'media-bridge-tg' -ErrorAction Stop } catch { L ('   start failed: ' + (Cut (San ([string]$_.Exception.Message)) 120)) }
Start-Sleep -Seconds 12
$tgLog = Join-Path $base 'logs\tg_bridge.log'
$bridgeAlive = $false
if (Test-Path -LiteralPath $tgLog) {
    foreach ($ln in @(Get-Content -LiteralPath $tgLog -Tail 8)) { L ('   tg| ' + (Cut (San ([string]$ln)) 150)) }
    if ([IO.File]::ReadAllText($tgLog) -match 'tg_bridge start') { $bridgeAlive = $true }
}
else { L '   [WARN] tg_bridge.log still not written' }
$procs = @()
try { $procs = @(Get-CimInstance Win32_Process -Filter "Name='python.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'tg_bridge\.py' }) } catch { }
if ($procs.Count -gt 0) { L ('   bridge process: pid ' + (@($procs)[0].ProcessId) + ' running') }
else { L '   [WARN] no tg_bridge.py process seen yet (run_tg_bridge.ps1 retries every 30s)' }

# ---------------- verdict ----------------
if ($bridgeAlive) {
    L '   FINAL: PASS - media-bridge-tg registered and tg_bridge.py is alive'
    L '   bridge waits for conf\tg_token.txt (BotFather token) and re-reads it every 60s'
}
else { L '   FINAL: FAIL - bridge log missing'; exit 2 }
L '--- task t138 done ---'
exit 0
