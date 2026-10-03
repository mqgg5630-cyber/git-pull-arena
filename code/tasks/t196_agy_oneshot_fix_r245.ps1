# t196_agy_oneshot_fix_r245.ps1 - round 245.
# One-shot, reboot-proof Antigravity login fix for the laptop.
# Root causes targeted:
#   (1) r189 evidence: writing the user-level HTTP(S)_PROXY env vars FAILED
#       (env_WARN SetEnvironmentVariable) - after a reboot the Go language
#       server has no proxy env and dials googleapis directly = blocked.
#       Fix: write HKCU\Environment via the registry (reg add semantics),
#       verify by reading back, broadcast WM_SETTINGCHANGE; try HKLM too.
#   (2) The pinned xray node can die between boots (ephemeral subs).
#       Fix: install a zero-window self-healing guard (wscript+hidden
#       powershell) that runs 1 min after every logon and every 30 min:
#       health-check the 127.0.0.1:18088 bridge, restart the bridge task,
#       and if still dead do a full node reselect via the existing
#       v2rayn_antigravity_auto_bridge.ps1 (-Apply -Relaunch).
# ASCII-only. Secrets are never printed (auto_bridge sanitizes).

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')   # repo root
$repo = (Get-Location).Path
$PROXY = 'http://127.0.0.1:18088'
$NOPROXY = 'localhost,127.0.0.1,::1'
$fail = 0

function Healthy {
    try {
        $o = & curl.exe --proxy http://127.0.0.1:18088 -s -o NUL -w "%{http_code}" --max-time 12 https://www.gstatic.com/generate_204 2>$null
        return ([string]$o -eq '204')
    } catch { return $false }
}

# ---------- A. diagnose current state ----------
Write-Output '== A. diagnosis (before fix)'
foreach ($tn in @('antigravity-xray-bridge', 'agy-bridge-guard-logon', 'agy-bridge-guard-period')) {
    try {
        $t = Get-ScheduledTask -TaskName $tn -ErrorAction Stop
        Write-Output ('   task ' + $tn + ' = ' + $t.State)
    } catch { Write-Output ('   task ' + $tn + ' = ABSENT') }
}
$xp = @(Get-Process -Name xray -ErrorAction SilentlyContinue)
Write-Output ('   xray processes = ' + $xp.Count)
$lis = (netstat -ano | Select-String ':18088 .*LISTENING' | Measure-Object).Count
Write-Output ('   port 18088 listening = ' + ($lis -gt 0))
foreach ($hive in @('HKCU:\Environment', 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment')) {
    try {
        $v = (Get-ItemProperty -Path $hive -Name HTTP_PROXY -ErrorAction SilentlyContinue).HTTP_PROXY
        Write-Output ('   ' + $hive + ' HTTP_PROXY = ' + ($(if ($v) { $v } else { '(not set)' })))
    } catch { Write-Output ('   ' + $hive + ' unreadable') }
}
$healthy0 = Healthy
Write-Output ('   bridge health (generate_204 via proxy) = ' + $healthy0)

# ---------- B. (re)bridge when unhealthy ----------
if (-not $healthy0) {
    Write-Output '== B. bridge unhealthy - full node reselect via auto_bridge'
    $auto = Join-Path $repo 'code\tasks\v2rayn_antigravity_auto_bridge.ps1'
    if (-not (Test-Path -LiteralPath $auto)) {
        Write-Output '[FAIL] v2rayn_antigravity_auto_bridge.ps1 missing in repo'
        exit 1
    }
    $rep = Join-Path $repo 'results\antigravity\auto_bridge_r245.md'
    $psExe = Join-Path $PSHOME 'powershell.exe'
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $auto -Apply -Relaunch -InteractiveTask -OutPath $rep 2>&1 | Out-String
    foreach ($ln in ($out -split "`r?`n")) {
        if ($ln -match 'chosen_node|FINAL|bridge_task|env_|settings_OK|agy_relaunch|nodes_found') { Write-Output ('   ' + $ln) }
    }
    Start-Sleep -Seconds 5
    if (-not (Healthy)) {
        Write-Output '[FAIL] bridge still unhealthy after reselect - no live supported node right now'
        $fail = 1
    } else {
        Write-Output '   bridge recovered'
    }
} else {
    Write-Output '== B. bridge already healthy - node reselect skipped'
}

# ---------- C. persistent proxy env (the reboot killer) ----------
Write-Output '== C. persist proxy env via registry'
$pairs = @(
    @{ n = 'HTTP_PROXY';  v = $PROXY },
    @{ n = 'HTTPS_PROXY'; v = $PROXY },
    @{ n = 'ALL_PROXY';   v = $PROXY },
    @{ n = 'NO_PROXY';    v = $NOPROXY }
)
foreach ($p in $pairs) {
    try {
        Set-ItemProperty -Path 'HKCU:\Environment' -Name $p.n -Value $p.v -Type String -Force
        $rb = (Get-ItemProperty -Path 'HKCU:\Environment' -Name $p.n).($p.n)
        if ($rb -eq $p.v) { Write-Output ('   HKCU ' + $p.n + ' = ' + $rb + ' (verified)') }
        else { Write-Output ('[FAIL] HKCU ' + $p.n + ' readback mismatch'); $fail = 1 }
    } catch {
        Write-Output ('[FAIL] HKCU ' + $p.n + ' write threw: ' + $_.Exception.Message); $fail = 1
    }
    try { [Environment]::SetEnvironmentVariable($p.n, $p.v, 'Process') } catch {}
}
# machine level too when we have the rights (scheduled tasks inherit it on any logon type)
$hklmOk = $true
foreach ($p in $pairs) {
    try {
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -Name $p.n -Value $p.v -Type String -Force -ErrorAction Stop
    } catch { $hklmOk = $false }
}
Write-Output ('   HKLM machine env ' + $(if ($hklmOk) { 'written (admin rights present)' } else { 'skipped (no admin) - HKCU is sufficient for logon-launched apps' }))
# broadcast WM_SETTINGCHANGE so new Explorer children see the vars without relogon
try {
    Add-Type -Namespace W -Name M -MemberDefinition '[DllImport("user32.dll",SetLastError=true,CharSet=CharSet.Auto)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd,uint Msg,UIntPtr wParam,string lParam,uint fuFlags,uint uTimeout,out UIntPtr lpdwResult);'
    $r = [UIntPtr]::Zero
    [void][W.M]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$r)
    Write-Output '   WM_SETTINGCHANGE broadcast sent'
} catch { Write-Output '   [WARN] env broadcast failed (takes effect at next logon anyway)' }

# ---------- D. install the zero-window self-healing guard ----------
Write-Output '== D. install self-healing guard'
$gdir = 'C:\ProgramData\agy-bridge'
New-Item -ItemType Directory -Force -Path $gdir | Out-Null
$guardPs = @(
    '# agy-bridge guard - auto-generated by git-pull-arena r245. ASCII-only.',
    '$log = ''C:\ProgramData\agy-bridge\guard.log''',
    'function GL([string]$m){ try{ Add-Content -Path $log -Value ((Get-Date).ToString(''yyyy-MM-dd HH:mm:ss'') + '' '' + $m) }catch{} }',
    'function Healthy { try { $o = & curl.exe --proxy http://127.0.0.1:18088 -s -o NUL -w "%{http_code}" --max-time 12 https://www.gstatic.com/generate_204 2>$null; return ([string]$o -eq ''204'') } catch { return $false } }',
    'if (Healthy) { GL ''ok''; exit 0 }',
    'GL ''unhealthy - (re)starting bridge task''',
    'try { Start-ScheduledTask -TaskName ''antigravity-xray-bridge'' } catch { GL (''bridge task start failed: '' + $_.Exception.Message) }',
    'Start-Sleep -Seconds 12',
    'if (Healthy) { GL ''recovered via bridge task restart''; exit 0 }',
    'GL ''still down - full node reselect''',
    ('$auto = ''' + ($repo -replace "'", "''") + '\code\tasks\v2rayn_antigravity_auto_bridge.ps1'''),
    'if (Test-Path -LiteralPath $auto) {',
    '    & (Join-Path $PSHOME ''powershell.exe'') -NoProfile -ExecutionPolicy Bypass -File $auto -Apply -Relaunch -InteractiveTask -OutPath ''C:\ProgramData\agy-bridge\last_rebridge.md'' | Out-Null',
    '    Start-Sleep -Seconds 6',
    '    if (Healthy) { GL ''recovered via full node reselect'' } else { GL ''reselect did not recover - check subs file'' }',
    '} else { GL ''auto_bridge script missing - repo moved?'' }'
)
[IO.File]::WriteAllText((Join-Path $gdir 'guard.ps1'), ($guardPs -join "`r`n") + "`r`n", (New-Object Text.UTF8Encoding($false)))
$vbs = @(
    'Set sh = CreateObject("Wscript.Shell")',
    'sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\ProgramData\agy-bridge\guard.ps1""", 0, False'
)
[IO.File]::WriteAllText((Join-Path $gdir 'guard.vbs'), ($vbs -join "`r`n") + "`r`n", (New-Object Text.UTF8Encoding($false)))
Write-Output '   guard.ps1 + guard.vbs written to C:\ProgramData\agy-bridge'

$act = 'wscript.exe //B "C:\ProgramData\agy-bridge\guard.vbs"'
$o1 = (& schtasks /create /tn 'agy-bridge-guard-logon'  /sc onlogon /delay 0001:00 /tr $act /f 2>&1 | Out-String).Trim()
Write-Output ('   logon guard : ' + ($o1 -replace '[^\x20-\x7E]', '?'))
$o2 = (& schtasks /create /tn 'agy-bridge-guard-period' /sc minute /mo 30 /tr $act /f 2>&1 | Out-String).Trim()
Write-Output ('   period guard: ' + ($o2 -replace '[^\x20-\x7E]', '?'))
foreach ($tn in @('agy-bridge-guard-logon', 'agy-bridge-guard-period')) {
    try {
        $t = Get-ScheduledTask -TaskName $tn -ErrorAction Stop
        Write-Output ('   task ' + $tn + ' registered, state=' + $t.State)
    } catch { Write-Output ('[FAIL] task ' + $tn + ' not registered'); $fail = 1 }
}
# run the guard once right now through the scheduler (proves the whole chain)
try {
    Start-ScheduledTask -TaskName 'agy-bridge-guard-period'
    Start-Sleep -Seconds 20
    $gl = Get-Content -LiteralPath (Join-Path $gdir 'guard.log') -Tail 3 -ErrorAction SilentlyContinue
    foreach ($ln in @($gl)) { Write-Output ('   guard.log: ' + $ln) }
} catch { Write-Output ('   [WARN] guard smoke run: ' + $_.Exception.Message) }

# ---------- E. final end-to-end verify ----------
Write-Output '== E. final verify'
$lis2 = (netstat -ano | Select-String ':18088 .*LISTENING' | Measure-Object).Count
Write-Output ('   port 18088 listening = ' + ($lis2 -gt 0))
$h = Healthy
Write-Output ('   generate_204 via bridge = ' + $h)
try {
    $cc = & curl.exe --proxy http://127.0.0.1:18088 -s -o NUL -w "%{http_code}" --max-time 15 https://daily-cloudcode-pa.googleapis.com/ 2>$null
    Write-Output ('   daily-cloudcode-pa via bridge HTTP ' + $cc + ' (404 = TLS path clear, not blocked)')
} catch { Write-Output '   [WARN] cloudcode probe failed' }
try {
    $geo = & curl.exe --proxy http://127.0.0.1:18088 -s --max-time 15 http://ip-api.com/line/?fields=countryCode 2>$null
    Write-Output ('   exit country via bridge = ' + ([string]$geo).Trim())
} catch {}
if (-not $h) { $fail = 1 }

if ($fail -ne 0) { Write-Output '== t196 RESULT: FAILED (see lines above)'; exit 1 }
Write-Output '== t196 RESULT: OK - bridge healthy, env persisted in registry, guard active at logon + every 30 min'
exit 0
