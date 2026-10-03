# t197_agy_bridge_fix2_r246.ps1 - round 246.
# ROOT CAUSE found in r245: Apply-Bridge writes the logon .cmd with
# ASCIIEncoding, and this laptop's profile path is non-ASCII - the cmd ends
# up pointing at E:\Users\??\... so the logon task NEVER started the bridge.
# Fix: move everything the boot chain needs onto pure-ASCII paths:
#   C:\ProgramData\agy-bridge\xray\xray.exe   (copied binary + *.dat)
#   C:\ProgramData\agy-bridge\bridge.json     (config r245 selected, SG node)
#   C:\ProgramData\agy-bridge\bridge.vbs      (zero-window xray launcher)
# and re-register:
#   task antigravity-xray-bridge      = at logon -> wscript //B bridge.vbs
#   task agy-bridge-guard-logon       = at logon +1 min  (PS registration,
#                                       schtasks onlogon needs admin)
#   task agy-bridge-guard-period      = every 30 min (already OK, repointed)
# Guard v2 also repairs after a node reselect by copying the fresh config to
# the ASCII path and restarting via the vbs. ASCII-only, zero windows.

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
        $n = (netstat -ano | Select-String (':' + $port + ' .*LISTENING') | Measure-Object).Count
        if ($n -gt 0) { return $true }
        Start-Sleep -Seconds 1
    }
    return $false
}

# ---------- 1. copy xray onto an ASCII path ----------
Write-Output '== 1. stage xray at C:\ProgramData\agy-bridge\xray'
$xraySrc = ''
try { $gp = Get-Process -Name xray -ErrorAction SilentlyContinue | Select-Object -First 1; if ($gp -and $gp.Path) { $xraySrc = $gp.Path } } catch {}
if (-not $xraySrc) {
    foreach ($pat in @('E:\Users\*\Downloads\xray-core\xray.exe', 'C:\Users\*\Downloads\xray-core\xray.exe', 'E:\*\v2rayN*\*\bin\xray\xray.exe', 'F:\v2rayN*\*\bin\xray\xray.exe')) {
        try { $hit = Get-ChildItem -Path $pat -File -ErrorAction SilentlyContinue | Select-Object -First 1; if ($hit) { $xraySrc = $hit.FullName; break } } catch {}
    }
}
if (-not $xraySrc) { Write-Output '[FAIL] xray.exe not found anywhere'; exit 1 }
Write-Output ('   source: ' + ($xraySrc -replace '[^\x20-\x7E]', '?'))
New-Item -ItemType Directory -Force -Path (Join-Path $G 'xray') | Out-Null
Copy-Item -LiteralPath $xraySrc -Destination (Join-Path $G 'xray\xray.exe') -Force
foreach ($dat in @(Get-ChildItem -Path (Join-Path (Split-Path -Parent $xraySrc) '*.dat') -File -ErrorAction SilentlyContinue)) {
    Copy-Item -LiteralPath $dat.FullName -Destination (Join-Path $G 'xray') -Force
}
$xrayDst = Join-Path $G 'xray\xray.exe'
Write-Output ('   staged: ' + $xrayDst + ' (' + (Get-Item -LiteralPath $xrayDst).Length + ' B)')

# ---------- 2. copy the r245-selected config onto the ASCII path ----------
Write-Output '== 2. stage bridge config'
$cfgSrc = Join-Path $env:USERPROFILE '.arena-private\antigravity-xray-bridge.json'
if (-not (Test-Path -LiteralPath $cfgSrc)) { Write-Output '[FAIL] no selected-node config (run auto_bridge first)'; exit 1 }
$cfgDst = Join-Path $G 'bridge.json'
Copy-Item -LiteralPath $cfgSrc -Destination $cfgDst -Force
Write-Output ('   staged: ' + $cfgDst + ' (' + (Get-Item -LiteralPath $cfgDst).Length + ' B)')

# ---------- 3. zero-window launcher + bridge task ----------
Write-Output '== 3. bridge launcher + logon task'
$vbs = @(
    'Set sh = CreateObject("Wscript.Shell")',
    'sh.Run """C:\ProgramData\agy-bridge\xray\xray.exe"" run -config ""C:\ProgramData\agy-bridge\bridge.json""", 0, False'
)
[IO.File]::WriteAllText((Join-Path $G 'bridge.vbs'), ($vbs -join "`r`n") + "`r`n", (New-Object Text.UTF8Encoding($false)))
# stop any previous bridge xray (match by command line; never touch v2rayN's own)
try {
    foreach ($pr in @(Get-CimInstance Win32_Process -Filter "Name='xray.exe'" -ErrorAction SilentlyContinue)) {
        $cl = [string]$pr.CommandLine
        if ($cl -match 'antigravity-xray-bridge\.json' -or $cl -match 'agy-bridge') {
            Stop-Process -Id $pr.ProcessId -Force -ErrorAction SilentlyContinue
            Write-Output ('   stopped old bridge xray pid=' + $pr.ProcessId)
        }
    }
} catch {}
try {
    $la = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('//B "' + (Join-Path $G 'bridge.vbs') + '"')
    $tr = New-ScheduledTaskTrigger -AtLogOn
    $pr2 = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
    $st = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
    Register-ScheduledTask -TaskName 'antigravity-xray-bridge' -Action $la -Trigger $tr -Principal $pr2 -Settings $st -Force | Out-Null
    Write-Output '   task antigravity-xray-bridge re-registered (wscript, ASCII paths)'
} catch { Write-Output ('[FAIL] bridge task registration: ' + $_.Exception.Message); $fail = 1 }
try { Start-ScheduledTask -TaskName 'antigravity-xray-bridge' } catch { Write-Output ('[FAIL] bridge task start: ' + $_.Exception.Message); $fail = 1 }
if (WaitPort 18088 20) { Write-Output '   port 18088 LISTENING' } else { Write-Output '[FAIL] port 18088 did not open'; $fail = 1 }
$h1 = Healthy
Write-Output ('   generate_204 via bridge = ' + $h1)
if (-not $h1) { $fail = 1 }

# ---------- 4. guard v2 (knows how to refresh the ASCII config) ----------
Write-Output '== 4. guard v2 + logon/period triggers'
$guard = @(
    '# agy-bridge guard v2 - generated r246. ASCII-only.',
    '$G = ''C:\ProgramData\agy-bridge''',
    '$log = Join-Path $G ''guard.log''',
    'function GL([string]$m){ try{ Add-Content -Path $log -Value ((Get-Date).ToString(''yyyy-MM-dd HH:mm:ss'') + '' '' + $m) }catch{} }',
    'function Healthy { try { $o = & curl.exe --proxy http://127.0.0.1:18088 -s -o NUL -w "%{http_code}" --max-time 12 https://www.gstatic.com/generate_204 2>$null; return ([string]$o -eq ''204'') } catch { return $false } }',
    'if (Healthy) { GL ''ok''; exit 0 }',
    'GL ''unhealthy - restart bridge task''',
    'try { Start-ScheduledTask -TaskName ''antigravity-xray-bridge'' } catch { GL (''task start failed: '' + $_.Exception.Message) }',
    'Start-Sleep -Seconds 12',
    'if (Healthy) { GL ''recovered via bridge restart''; exit 0 }',
    'GL ''still down - full node reselect''',
    ('$auto = ''' + ($repo -replace "'", "''") + '\code\tasks\v2rayn_antigravity_auto_bridge.ps1'''),
    'if (-not (Test-Path -LiteralPath $auto)) { GL ''auto_bridge missing''; exit 1 }',
    '& (Join-Path $PSHOME ''powershell.exe'') -NoProfile -ExecutionPolicy Bypass -File $auto -Apply -OutPath (Join-Path $G ''last_rebridge.md'') | Out-Null',
    '$cfgSrc = Join-Path $env:USERPROFILE ''.arena-private\antigravity-xray-bridge.json''',
    'if (Test-Path -LiteralPath $cfgSrc) { Copy-Item -LiteralPath $cfgSrc -Destination (Join-Path $G ''bridge.json'') -Force }',
    'foreach ($pr in @(Get-CimInstance Win32_Process -Filter "Name=''xray.exe''" -ErrorAction SilentlyContinue)) {',
    '    $cl = [string]$pr.CommandLine',
    '    if ($cl -match ''agy-bridge'' -or $cl -match ''antigravity-xray-bridge\.json'') { Stop-Process -Id $pr.ProcessId -Force -ErrorAction SilentlyContinue }',
    '}',
    'Start-ScheduledTask -TaskName ''antigravity-xray-bridge''',
    'Start-Sleep -Seconds 12',
    'if (Healthy) {',
    '    GL ''recovered via node reselect - relaunching Antigravity''',
    '    foreach($n in @(''language_server'',''Antigravity'')){ try{ taskkill /f /im ($n + ''.exe'') 2>&1 | Out-Null }catch{} }',
    '    Start-Sleep -Seconds 3',
    '    $exe = Join-Path $env:LOCALAPPDATA ''Programs\Antigravity\Antigravity.exe''',
    '    if (Test-Path -LiteralPath $exe) { try { Start-Process $exe } catch {} }',
    '} else { GL ''reselect did not recover - subs may be dead'' }'
)
[IO.File]::WriteAllText((Join-Path $G 'guard.ps1'), ($guard -join "`r`n") + "`r`n", (New-Object Text.UTF8Encoding($false)))
$gvbs = @(
    'Set sh = CreateObject("Wscript.Shell")',
    'sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\ProgramData\agy-bridge\guard.ps1""", 0, False'
)
[IO.File]::WriteAllText((Join-Path $G 'guard.vbs'), ($gvbs -join "`r`n") + "`r`n", (New-Object Text.UTF8Encoding($false)))
Write-Output '   guard.ps1 v2 + guard.vbs written'
try {
    $la = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('//B "' + (Join-Path $G 'guard.vbs') + '"')
    $tr = New-ScheduledTaskTrigger -AtLogOn
    $tr.Delay = 'PT1M'
    $pr3 = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
    $st = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName 'agy-bridge-guard-logon' -Action $la -Trigger $tr -Principal $pr3 -Settings $st -Force | Out-Null
    Write-Output '   task agy-bridge-guard-logon registered (PS, delay 1 min)'
} catch { Write-Output ('[FAIL] guard logon task: ' + $_.Exception.Message); $fail = 1 }
$o2 = (& schtasks /create /tn 'agy-bridge-guard-period' /sc minute /mo 30 /tr ('wscript.exe //B "' + (Join-Path $G 'guard.vbs') + '"') /f 2>&1 | Out-String).Trim()
Write-Output ('   period guard refresh: ' + ($o2 -replace '[^\x20-\x7E]', '?'))

# ---------- 5. relaunch Antigravity on the healthy bridge ----------
if ($h1) {
    Write-Output '== 5. relaunch Antigravity'
    foreach ($n in @('language_server', 'Antigravity')) { try { taskkill /f /im ($n + '.exe') 2>&1 | Out-Null } catch {} }
    Start-Sleep -Seconds 3
    $exe = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
    if (Test-Path -LiteralPath $exe) {
        try {
            $la = New-ScheduledTaskAction -Execute $exe
            $pr4 = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
            Register-ScheduledTask -TaskName 'agyrelaunch_auto_bridge' -Action $la -Principal $pr4 -Force | Out-Null
            Start-ScheduledTask -TaskName 'agyrelaunch_auto_bridge'
            Write-Output '   Antigravity relaunched (interactive task)'
        } catch { Write-Output ('   [WARN] relaunch: ' + $_.Exception.Message) }
    } else { Write-Output '   [WARN] Antigravity.exe not found at the usual path' }
}

# ---------- 6. final verify ----------
Write-Output '== 6. final verify'
Write-Output ('   port 18088 listening = ' + (WaitPort 18088 3))
Write-Output ('   generate_204 via bridge = ' + (Healthy))
try {
    $cc = & curl.exe --proxy http://127.0.0.1:18088 -s -o NUL -w "%{http_code}" --max-time 15 https://daily-cloudcode-pa.googleapis.com/ 2>$null
    Write-Output ('   daily-cloudcode-pa HTTP ' + $cc + ' (404 = clear)')
} catch {}
try {
    $geo = (& curl.exe --proxy http://127.0.0.1:18088 -s --max-time 15 "http://ip-api.com/line/?fields=countryCode" 2>$null)
    Write-Output ('   exit country = ' + ([string]$geo).Trim())
} catch {}
$hk = (Get-ItemProperty -Path 'HKCU:\Environment' -Name HTTP_PROXY -ErrorAction SilentlyContinue).HTTP_PROXY
Write-Output ('   HKCU HTTP_PROXY = ' + $hk)
foreach ($tn in @('antigravity-xray-bridge', 'agy-bridge-guard-logon', 'agy-bridge-guard-period')) {
    try { $t = Get-ScheduledTask -TaskName $tn -ErrorAction Stop; Write-Output ('   task ' + $tn + ' = ' + $t.State) }
    catch { Write-Output ('[FAIL] task ' + $tn + ' ABSENT'); $fail = 1 }
}

if ($fail -ne 0) { Write-Output '== t197 RESULT: FAILED'; exit 1 }
Write-Output '== t197 RESULT: OK - boot chain is now fully ASCII-path, zero-window, self-healing'
exit 0
