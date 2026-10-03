# t137_tg_task.ps1 - round 179 task: runs ON THE LAPTOP. Last mile of the
# media-bridge: r178 installed everything (requests, sau clone, wxmp/xhs
# checks OK) but 'schtasks /create' failed on the nested quotes in /TR
# (rc=1), so media-bridge-tg never registered and the bridge never ran.
# Fix: register with the PowerShell-native Register-ScheduledTask (same
# mechanism watch.ps1 uses), start it, verify the bridge log.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }
function Cut([string]$s, [int]$n) { if ($s.Length -gt $n) { return $s.Substring(0, $n) }; return $s }

$base = 'E:\0github\git-sync\media-bridge'
L '--- task t137: register media-bridge-tg via Register-ScheduledTask ---'

if (-not (Test-Path -LiteralPath (Join-Path $base 'tg_bridge.py'))) { L '   [FAIL] media-bridge not staged'; exit 2 }
if (-not (Test-Path -LiteralPath (Join-Path $base 'run_tg_bridge.ps1'))) { L '   [FAIL] run_tg_bridge.ps1 missing'; exit 2 }

# ---------------- 1. (re)register the task ----------------
try {
    $null = Get-ScheduledTask -TaskName 'media-bridge-tg' -ErrorAction Stop
    try { Unregister-ScheduledTask -TaskName 'media-bridge-tg' -Confirm:$false -ErrorAction SilentlyContinue } catch { }
    L '   removed previous registration (if any)'
} catch { }

$arg = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + (Join-Path $base 'run_tg_bridge.ps1') + '"'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg -WorkingDirectory $base
$trigger = New-ScheduledTaskTrigger -AtLogOn -ErrorAction SilentlyContinue
if (-not $trigger) { $trigger = New-ScheduledTaskTrigger -AtLogOn }
$settings = $null
try {
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ErrorAction Stop
} catch { $settings = $null }
$regArgs = @{ TaskName = 'media-bridge-tg'; Action = $action; Trigger = $trigger; Force = $true; Description = 'media-bridge Telegram remote control (keeps tg_bridge.py alive)' }
if ($settings) { $regArgs['Settings'] = $settings }
Register-ScheduledTask @regArgs | Out-Null
$t = Get-ScheduledTask -TaskName 'media-bridge-tg' -ErrorAction SilentlyContinue
if (-not $t) { L '   [FAIL] Register-ScheduledTask did not create the task'; exit 2 }
L ('   registered: media-bridge-tg state=' + (San ([string]$t.State)))

# ---------------- 2. start + verify bridge log ----------------
Start-ScheduledTask -TaskName 'media-bridge-tg' -ErrorAction SilentlyContinue
Start-Sleep -Seconds 12
$tgLog = Join-Path $base 'logs\tg_bridge.log'
$bridgeAlive = $false
if (Test-Path -LiteralPath $tgLog) {
    foreach ($ln in @(Get-Content -LiteralPath $tgLog -Tail 8)) { L ('   tg| ' + (Cut (San ([string]$ln)) 150)) }
    if ([IO.File]::ReadAllText($tgLog) -match 'tg_bridge start') { $bridgeAlive = $true }
}
else { L '   [WARN] tg_bridge.log still not written' }

# bridge process?
$procs = @()
try { $procs = @(Get-CimInstance Win32_Process -Filter "Name='python.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'tg_bridge\.py' }) } catch { }
if ($procs.Count -gt 0) { L ('   bridge process: pid ' + (@($procs)[0].ProcessId) + ' running') }
else { L '   [WARN] no tg_bridge.py process seen (run_tg_bridge.ps1 restarts it every 30s)' }

# ---------------- verdict ----------------
if ($bridgeAlive) {
    L '   FINAL: PASS - media-bridge-tg registered and tg_bridge.py is alive'
    L '   bridge waits for conf\tg_token.txt (user: BotFather token) - re-reads it every 60s'
}
else { L '   FINAL: FAIL - bridge log missing'; exit 2 }
L '--- task t137 done ---'
exit 0
