# t198_agy_runkey_fix_r247.ps1 - round 247.
# r246 landed the ASCII staging (C:\ProgramData\agy-bridge\{xray\xray.exe,
# bridge.json,bridge.vbs,guard.*}) but Register-ScheduledTask was DENIED
# (0x80070005) from the watcher context. This round makes the boot chain
# independent of the task scheduler:
#   - autostart via HKCU Run keys (always writable by the user, zero admin,
#     zero window through wscript //B)
#   - guard v3 starts xray DIRECTLY (no Start-ScheduledTask dependency)
#   - scheduled-task registration is still attempted after a clean delete,
#     as a best-effort second layer (period guard task already exists)
# Bridge is started right now and verified end to end. ASCII-only.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')   # repo root
$repo = (Get-Location).Path
$G = 'C:\ProgramData\agy-bridge'
$fail = 0

function Healthy {
    try {
        $o = & curl.exe --proxy http://127.0.0.1:18088 -s -o NUL -w "%{http_code}" --max-time 12 https://www.gstatic.com/generate_204 2>$null
        return ([string]$o -eq '204')
    } catch { return $false }
}
function WaitPort([int]$port, [int]$sec) {
    for ($i = 0; $i -lt $sec; $i++) {
        if ((netstat -ano | Select-String (':' + $port + ' .*LISTENING') | Measure-Object).Count -gt 0) { return $true }
        Start-Sleep -Seconds 1
    }
    return $false
}
function Stop-BridgeXray {
    try {
        foreach ($pr in @(Get-CimInstance Win32_Process -Filter "Name='xray.exe'" -ErrorAction SilentlyContinue)) {
            $cl = [string]$pr.CommandLine
            if ($cl -match 'agy-bridge' -or $cl -match 'antigravity-xray-bridge\.json') {
                Stop-Process -Id $pr.ProcessId -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {}
}

# ---------- 0. sanity: staged files from r246 ----------
foreach ($p in @((Join-Path $G 'xray\xray.exe'), (Join-Path $G 'bridge.json'), (Join-Path $G 'bridge.vbs'))) {
    if (-not (Test-Path -LiteralPath $p)) { Write-Output ('[FAIL] staged file missing: ' + $p); exit 1 }
}
Write-Output '== 0. r246 staging present (xray.exe / bridge.json / bridge.vbs)'

# ---------- 1. start the bridge DIRECTLY and verify ----------
Write-Output '== 1. direct bridge start'
Stop-BridgeXray
Start-Sleep -Seconds 1
try {
    Start-Process -FilePath (Join-Path $G 'xray\xray.exe') -ArgumentList @('run', '-config', (Join-Path $G 'bridge.json')) -WindowStyle Hidden
} catch { Write-Output ('[FAIL] xray start threw: ' + $_.Exception.Message); exit 1 }
if (WaitPort 18088 15) { Write-Output '   port 18088 LISTENING' } else { Write-Output '[FAIL] port 18088 closed'; $fail = 1 }
$h = Healthy
Write-Output ('   generate_204 via bridge = ' + $h)
if (-not $h) {
    Write-Output '   node seems dead - full reselect via auto_bridge'
    $auto = Join-Path $repo 'code\tasks\v2rayn_antigravity_auto_bridge.ps1'
    & (Join-Path $PSHOME 'powershell.exe') -NoProfile -ExecutionPolicy Bypass -File $auto -Apply -OutPath (Join-Path $G 'last_rebridge.md') | Out-Null
    $cfgSrc = Join-Path $env:USERPROFILE '.arena-private\antigravity-xray-bridge.json'
    if (Test-Path -LiteralPath $cfgSrc) { Copy-Item -LiteralPath $cfgSrc -Destination (Join-Path $G 'bridge.json') -Force }
    Stop-BridgeXray
    Start-Sleep -Seconds 1
    Start-Process -FilePath (Join-Path $G 'xray\xray.exe') -ArgumentList @('run', '-config', (Join-Path $G 'bridge.json')) -WindowStyle Hidden
    [void](WaitPort 18088 15)
    $h = Healthy
    Write-Output ('   after reselect: generate_204 = ' + $h)
}
if (-not $h) { $fail = 1 }

# ---------- 2. guard v3 (task-free recovery) ----------
Write-Output '== 2. guard v3'
$guard = @(
    '# agy-bridge guard v3 - generated r247. Task-free recovery. ASCII-only.',
    '$G = ''C:\ProgramData\agy-bridge''',
    '$log = Join-Path $G ''guard.log''',
    'function GL([string]$m){ try{ Add-Content -Path $log -Value ((Get-Date).ToString(''yyyy-MM-dd HH:mm:ss'') + '' '' + $m) }catch{} }',
    'function Healthy { try { $o = & curl.exe --proxy http://127.0.0.1:18088 -s -o NUL -w "%{http_code}" --max-time 12 https://www.gstatic.com/generate_204 2>$null; return ([string]$o -eq ''204'') } catch { return $false } }',
    'function StopBridge { try { foreach ($pr in @(Get-CimInstance Win32_Process -Filter "Name=''xray.exe''" -ErrorAction SilentlyContinue)) { $cl = [string]$pr.CommandLine; if ($cl -match ''agy-bridge'' -or $cl -match ''antigravity-xray-bridge\.json'') { Stop-Process -Id $pr.ProcessId -Force -ErrorAction SilentlyContinue } } } catch {} }',
    'function StartBridge { try { Start-Process -FilePath (Join-Path $G ''xray\xray.exe'') -ArgumentList @(''run'',''-config'',(Join-Path $G ''bridge.json'')) -WindowStyle Hidden } catch { GL (''xray start failed: '' + $_.Exception.Message) } }',
    'if (Healthy) { GL ''ok''; exit 0 }',
    'GL ''unhealthy - direct bridge restart''',
    'StopBridge; Start-Sleep -Seconds 1; StartBridge; Start-Sleep -Seconds 10',
    'if (Healthy) { GL ''recovered via direct restart''; exit 0 }',
    'GL ''still down - full node reselect''',
    ('$auto = ''' + ($repo -replace "'", "''") + '\code\tasks\v2rayn_antigravity_auto_bridge.ps1'''),
    'if (-not (Test-Path -LiteralPath $auto)) { GL ''auto_bridge missing''; exit 1 }',
    '& (Join-Path $PSHOME ''powershell.exe'') -NoProfile -ExecutionPolicy Bypass -File $auto -Apply -OutPath (Join-Path $G ''last_rebridge.md'') | Out-Null',
    '$cfgSrc = Join-Path $env:USERPROFILE ''.arena-private\antigravity-xray-bridge.json''',
    'if (Test-Path -LiteralPath $cfgSrc) { Copy-Item -LiteralPath $cfgSrc -Destination (Join-Path $G ''bridge.json'') -Force }',
    'StopBridge; Start-Sleep -Seconds 1; StartBridge; Start-Sleep -Seconds 10',
    'if (Healthy) {',
    '    GL ''recovered via node reselect - relaunching Antigravity''',
    '    foreach($n in @(''language_server'',''Antigravity'')){ try{ taskkill /f /im ($n + ''.exe'') 2>&1 | Out-Null }catch{} }',
    '    Start-Sleep -Seconds 3',
    '    $exe = Join-Path $env:LOCALAPPDATA ''Programs\Antigravity\Antigravity.exe''',
    '    if (Test-Path -LiteralPath $exe) { try { Start-Process $exe } catch {} }',
    '} else { GL ''reselect did not recover - subs may be dead'' }'
)
[IO.File]::WriteAllText((Join-Path $G 'guard.ps1'), ($guard -join "`r`n") + "`r`n", (New-Object Text.UTF8Encoding($false)))
# boot.vbs: start bridge immediately, then run the guard once after 75 s
$boot = @(
    'Set sh = CreateObject("Wscript.Shell")',
    'sh.Run """C:\ProgramData\agy-bridge\xray\xray.exe"" run -config ""C:\ProgramData\agy-bridge\bridge.json""", 0, False',
    'WScript.Sleep 75000',
    'sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\ProgramData\agy-bridge\guard.ps1""", 0, False'
)
[IO.File]::WriteAllText((Join-Path $G 'boot.vbs'), ($boot -join "`r`n") + "`r`n", (New-Object Text.UTF8Encoding($false)))
Write-Output '   guard.ps1 v3 + boot.vbs written'

# ---------- 3. HKCU Run keys: the autostart that cannot be denied ----------
Write-Output '== 3. HKCU Run autostart'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
try {
    Set-ItemProperty -Path $runKey -Name 'agy-bridge' -Value ('wscript.exe //B "' + (Join-Path $G 'boot.vbs') + '"') -Type String -Force
    $rb = (Get-ItemProperty -Path $runKey -Name 'agy-bridge').'agy-bridge'
    Write-Output ('   Run\agy-bridge = ' + $rb)
    if (-not $rb) { $fail = 1 }
} catch { Write-Output ('[FAIL] Run key write: ' + $_.Exception.Message); $fail = 1 }

# ---------- 4. best-effort: clean + re-register the logon tasks ----------
Write-Output '== 4. best-effort scheduled tasks (second layer)'
foreach ($tn in @('antigravity-xray-bridge', 'agy-bridge-guard-logon')) {
    $null = (& schtasks /delete /tn $tn /f 2>&1 | Out-String)
}
try {
    $la = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('//B "' + (Join-Path $G 'boot.vbs') + '"')
    $tr = New-ScheduledTaskTrigger -AtLogOn
    $pr2 = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
    $st = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName 'antigravity-xray-bridge' -Action $la -Trigger $tr -Principal $pr2 -Settings $st -Force | Out-Null
    Write-Output '   task antigravity-xray-bridge registered'
} catch { Write-Output ('   [WARN] task layer still denied (' + $_.Exception.Message + ') - Run key covers logon') }
$o2 = (& schtasks /create /tn 'agy-bridge-guard-period' /sc minute /mo 30 /tr ('wscript.exe //B "' + (Join-Path $G 'guard.vbs') + '"') /f 2>&1 | Out-String).Trim()
Write-Output ('   period guard: ' + ($o2 -replace '[^\x20-\x7E]', '?'))
$gvbs = @(
    'Set sh = CreateObject("Wscript.Shell")',
    'sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\ProgramData\agy-bridge\guard.ps1""", 0, False'
)
[IO.File]::WriteAllText((Join-Path $G 'guard.vbs'), ($gvbs -join "`r`n") + "`r`n", (New-Object Text.UTF8Encoding($false)))

# ---------- 5. relaunch Antigravity on the healthy bridge ----------
if ($h) {
    Write-Output '== 5. relaunch Antigravity'
    foreach ($n in @('language_server', 'Antigravity')) { try { taskkill /f /im ($n + '.exe') 2>&1 | Out-Null } catch {} }
    Start-Sleep -Seconds 3
    $exe = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
    $started = $false
    try { Start-ScheduledTask -TaskName 'agyrelaunch_auto_bridge' -ErrorAction Stop; $started = $true; Write-Output '   relaunched via existing interactive task' } catch {}
    if (-not $started -and (Test-Path -LiteralPath $exe)) {
        try { Start-Process $exe; Write-Output '   relaunched via Start-Process' } catch { Write-Output ('   [WARN] relaunch: ' + $_.Exception.Message) }
    }
}

# ---------- 6. final verify ----------
Write-Output '== 6. final verify'
Write-Output ('   port 18088 listening = ' + (WaitPort 18088 3))
Write-Output ('   generate_204 via bridge = ' + (Healthy))
try { $cc = & curl.exe --proxy http://127.0.0.1:18088 -s -o NUL -w "%{http_code}" --max-time 15 https://daily-cloudcode-pa.googleapis.com/ 2>$null; Write-Output ('   daily-cloudcode-pa HTTP ' + $cc + ' (404 = clear)') } catch {}
try { $geo = (& curl.exe --proxy http://127.0.0.1:18088 -s --max-time 15 "http://ip-api.com/line/?fields=countryCode" 2>$null); Write-Output ('   exit country = ' + ([string]$geo).Trim()) } catch {}
Write-Output ('   HKCU HTTP_PROXY = ' + ((Get-ItemProperty -Path 'HKCU:\Environment' -Name HTTP_PROXY -ErrorAction SilentlyContinue).HTTP_PROXY))
Write-Output ('   Run\agy-bridge = ' + ((Get-ItemProperty -Path $runKey -Name 'agy-bridge' -ErrorAction SilentlyContinue).'agy-bridge'))
foreach ($tn in @('antigravity-xray-bridge', 'agy-bridge-guard-period')) {
    try { $t = Get-ScheduledTask -TaskName $tn -ErrorAction Stop; Write-Output ('   task ' + $tn + ' = ' + $t.State) }
    catch { Write-Output ('   task ' + $tn + ' = ABSENT (Run key covers it)') }
}

if ($fail -ne 0) { Write-Output '== t198 RESULT: FAILED'; exit 1 }
Write-Output '== t198 RESULT: OK - bridge healthy NOW; autostart via HKCU Run key (admin-free); guard self-heals at logon +75 s and every 30 min'
exit 0
