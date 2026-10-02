# desk_antigravity_agent_error.ps1 - runs ON THE DESKTOP via ssh.
# Diagnose and refresh Antigravity agent/proxy state after the UI shows
# "Agent execution terminated due to error". ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{40,}', '[REDACTED]' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m; $script:Report += $m }
function TailLines([string]$path, [int]$n) {
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    return @(Get-Content -LiteralPath $path -Tail $n -ErrorAction SilentlyContinue)
}
function AddRecentMatches([string]$label, [string]$path, [string]$pattern) {
    if (-not (Test-Path -LiteralPath $path)) { return }
    $hits = @(Select-String -Path $path -Pattern $pattern -SimpleMatch:$false -ErrorAction SilentlyContinue | Select-Object -Last 20)
    L ('   ' + $label + ': hits=' + $hits.Count + ' file=' + $path)
    foreach ($h in ($hits | Select-Object -Last 8)) { L ('      L' + $h.LineNumber + ' ' + (San $h.Line.Trim())) }
}

$script:Report = @()
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = 'F:\fig1_rebuild\agy_agent_diag_r173.md'
$proxy = 'http://127.0.0.1:10808'

L '# Antigravity agent-error desktop diagnostic r173'
L ('time: ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer: ' + $env:COMPUTERNAME + ' user: ' + $env:USERNAME)

# 1. Persist proxy variables again. This is the safe fix for the known failure
# mode where Go helpers do not inherit Electron/system proxy settings.
L '## proxy persistence refresh'
try {
    [Environment]::SetEnvironmentVariable('HTTP_PROXY', $proxy, 'User')
    [Environment]::SetEnvironmentVariable('HTTPS_PROXY', $proxy, 'User')
    [Environment]::SetEnvironmentVariable('ALL_PROXY', $proxy, 'User')
    [Environment]::SetEnvironmentVariable('NO_PROXY', 'localhost,127.0.0.1,::1', 'User')
    $env:HTTP_PROXY = $proxy; $env:HTTPS_PROXY = $proxy; $env:ALL_PROXY = $proxy; $env:NO_PROXY = 'localhost,127.0.0.1,::1'
    L '   HKCU/env proxy set: OK'
} catch { L ('   HKCU/env proxy set: FAIL ' + (San $_.Exception.Message)) }
try {
    [Environment]::SetEnvironmentVariable('HTTP_PROXY', $proxy, 'Machine')
    [Environment]::SetEnvironmentVariable('HTTPS_PROXY', $proxy, 'Machine')
    [Environment]::SetEnvironmentVariable('ALL_PROXY', $proxy, 'Machine')
    [Environment]::SetEnvironmentVariable('NO_PROXY', 'localhost,127.0.0.1,::1', 'Machine')
    L '   HKLM proxy set: OK'
} catch { L ('   HKLM proxy set: WARN ' + (San $_.Exception.Message)) }

# 2. Settings files for Electron/network stack.
L '## Antigravity settings refresh'
$settingsRoots = @(
    (Join-Path $env:APPDATA 'Antigravity\User'),
    (Join-Path $env:APPDATA 'Antigravity IDE\User')
)
foreach ($root in $settingsRoots) {
    try {
        New-Item -ItemType Directory -Force -Path $root | Out-Null
        $sp = Join-Path $root 'settings.json'
        $obj = @{}
        if (Test-Path -LiteralPath $sp) {
            try { $obj = Get-Content -LiteralPath $sp -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $obj = @{} }
        }
        if (-not ($obj -is [pscustomobject])) { $obj = [pscustomobject]@{} }
        $obj | Add-Member -NotePropertyName 'http.proxy' -NotePropertyValue $proxy -Force
        $obj | Add-Member -NotePropertyName 'http.proxySupport' -NotePropertyValue 'on' -Force
        $obj | Add-Member -NotePropertyName 'http.noProxy' -NotePropertyValue @('localhost','127.0.0.1','::1') -Force
        $json = $obj | ConvertTo-Json -Depth 8
        [IO.File]::WriteAllText($sp, $json + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
        L ('   settings OK: ' + $sp)
    } catch { L ('   settings FAIL: ' + $root + ' ' + (San $_.Exception.Message)) }
}

# 3. Wrapper. Existing start-menu links may bypass it, but it gives one clean
# launch path and proves the helper env is present.
L '## wrapper refresh'
$agyExe = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
$wrap = 'F:\fig1_rebuild\agy_proxy.cmd'
if (Test-Path -LiteralPath $agyExe) {
    $cmd = @(
        '@echo off',
        'set HTTP_PROXY=http://127.0.0.1:10808',
        'set HTTPS_PROXY=http://127.0.0.1:10808',
        'set ALL_PROXY=http://127.0.0.1:10808',
        'set NO_PROXY=localhost,127.0.0.1,::1',
        'set http_proxy=http://127.0.0.1:10808',
        'set https_proxy=http://127.0.0.1:10808',
        'echo %DATE% %TIME% agy_proxy launch>>F:\fig1_rebuild\agy_launch.log',
        'set > F:\fig1_rebuild\agy_env_snapshot.txt',
        'start "" "' + $agyExe + '"'
    )
    [IO.File]::WriteAllLines($wrap, $cmd, (New-Object System.Text.ASCIIEncoding))
    L ('   wrapper OK: ' + $wrap)
} else { L ('   wrapper skipped, missing exe: ' + $agyExe) }

# 4. Network probes.
L '## network probes'
try {
    $tnc = Test-NetConnection 127.0.0.1 -Port 10808 -WarningAction SilentlyContinue
    L ('   local proxy port 10808: ' + $tnc.TcpTestSucceeded)
} catch { L ('   local proxy probe failed: ' + (San $_.Exception.Message)) }
$curl = Get-Command curl.exe -ErrorAction SilentlyContinue
if ($curl) {
    foreach ($url in @('https://daily-cloudcode-pa.googleapis.com/', 'https://oauth2.googleapis.com/', 'https://jetski-webchannel.googleapis.com/')) {
        try {
            $o = & curl.exe -I -L --max-time 20 --proxy $proxy $url 2>&1 | Out-String
            $head = (($o -split "`r?`n") | Where-Object { $_ -match 'HTTP/' } | Select-Object -Last 1)
            if (-not $head) { $head = (($o -split "`r?`n") | Select-Object -Last 1) }
            L ('   curl proxy ' + $url + ' -> ' + (San $head.Trim()))
        } catch { L ('   curl proxy ' + $url + ' -> FAIL ' + (San $_.Exception.Message)) }
    }
} else { L '   curl.exe missing' }

# 5. Processes and logs before/after a controlled refresh.
function DumpState([string]$tag) {
    L ('## state ' + $tag)
    $procs = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        (($_.ExecutablePath) -and ($_.ExecutablePath -match 'Antigravity')) -or
        ($_.Name -eq 'Antigravity.exe') -or ($_.Name -eq 'language_server.exe')
    } | Sort-Object Name, ProcessId)
    L ('   processes: ' + $procs.Count)
    foreach ($p in ($procs | Select-Object -First 12)) {
        L ('      pid=' + $p.ProcessId + ' name=' + $p.Name + ' path=' + (San $p.ExecutablePath))
    }
    $pc = 0; $d4 = 0
    foreach ($p in $procs) {
        foreach ($c in @(Get-NetTCPConnection -OwningProcess $p.ProcessId -ErrorAction SilentlyContinue)) {
            $ra = [string]$c.RemoteAddress
            if ($ra -eq '127.0.0.1' -and $c.RemotePort -eq 10808) { $pc++ }
            elseif ($c.RemotePort -eq 443 -and $ra -notmatch '^127\.') { $d4++ }
        }
    }
    L ('   tcp: to_proxy=' + $pc + ' direct_443=' + $d4)

    $logRoots = @((Join-Path $env:APPDATA 'Antigravity\logs'), (Join-Path $env:APPDATA 'Antigravity IDE\logs'))
    foreach ($lr in $logRoots) {
        if (-not (Test-Path -LiteralPath $lr)) { L ('   logs missing: ' + $lr); continue }
        L ('   logs: ' + $lr)
        foreach ($lf in @(Get-ChildItem -LiteralPath $lr -File -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 10)) {
            L ('      file ' + $lf.Name + ' ' + $lf.LastWriteTime.ToString('HH:mm:ss') + ' ' + [math]::Round($lf.Length/1KB) + 'KB')
        }
        $pat = 'Agent execution terminated|terminated due to error|\[error\]|Error:|panic|exception|quota|429|401|403|Unauthenticated|Failed to get OAuth|dial tcp|record with version 15|ECONN|ETIMEDOUT|ENOTFOUND|language_server|mcp|tool'
        foreach ($lf in @(Get-ChildItem -LiteralPath $lr -File -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 8)) {
            AddRecentMatches ($tag + ' ' + $lf.Name) $lf.FullName $pat
        }
    }
}

DumpState 'before'

L '## controlled relaunch'
$relaunchAt = Get-Date
try {
    foreach ($n in @('language_server','Antigravity')) { & taskkill /f /im ($n + '.exe') 2>&1 | Out-Null }
    Start-Sleep -Seconds 5
    if (Test-Path -LiteralPath $wrap) {
        try {
            $tn = 'agyrelaunch_git'
            $la = New-ScheduledTaskAction -Execute $wrap
            $pr = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
            $st = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
            Register-ScheduledTask -TaskName $tn -Action $la -Principal $pr -Settings $st -Force | Out-Null
            Start-ScheduledTask -TaskName $tn
            L ('   relaunched through interactive scheduled task: ' + $tn)
        } catch {
            L ('   scheduled relaunch WARN ' + (San $_.Exception.Message))
            try {
                $null = & schtasks /delete /tn agyrelaunch_git /f 2>$null
                $so = (& schtasks /create /tn agyrelaunch_git /tr $wrap /sc once /st 23:59 /it /f 2>&1 | Out-String).Trim()
                L ('   schtasks create: ' + (San $so))
                $ro = (& schtasks /run /tn agyrelaunch_git 2>&1 | Out-String).Trim()
                L ('   schtasks run: ' + (San $ro))
            } catch { L ('   schtasks relaunch FAIL ' + (San $_.Exception.Message)) }
        }
    } elseif (Test-Path -LiteralPath $agyExe) {
        Start-Process -FilePath $agyExe
        L '   relaunched direct exe (wrapper missing)'
    } else { L '   relaunch skipped, exe missing' }
} catch { L ('   relaunch WARN ' + (San $_.Exception.Message)) }
Start-Sleep -Seconds 75
DumpState 'after'

# 6. Fresh post-relaunch analysis. Do not let old log lines from before this
# run make the verdict look bad; the UI must be judged from relaunchAt onward.
function LsTime([string]$ln) {
    if ($ln -match '([EWIF])(\d{2})(\d{2}) (\d{2}):(\d{2}):(\d{2})') {
        try { return (Get-Date -Year (Get-Date).Year -Month ([int]$Matches[2]) -Day ([int]$Matches[3]) -Hour ([int]$Matches[4]) -Minute ([int]$Matches[5]) -Second ([int]$Matches[6]) ) } catch { return $null }
    }
    return $null
}
function MainTime([string]$ln) {
    if ($ln -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})') {
        try { return [DateTime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null) } catch { return $null }
    }
    return $null
}
$freshLines = 0; $freshBad = 0; $freshTerm = 0; $freshGood = 0
$lsLog2 = Join-Path $env:APPDATA 'Antigravity\logs\language_server.log'
if (Test-Path -LiteralPath $lsLog2) {
    foreach ($ln in @(Get-Content -LiteralPath $lsLog2 -Tail 260 -ErrorAction SilentlyContinue)) {
        $t = LsTime $ln
        if ($t -and $t -ge $relaunchAt) {
            $freshLines++
            if ($ln -match 'dial tcp|record with version 15|Failed to get OAuth|Unauthenticated') { $freshBad++; L ('   fresh_bad_ls: ' + (San $ln.Trim())) }
            if ($ln -match 'Auth succeeded|loadCodeAssist|fetchAvailableModels|availableModels|userTier') { $freshGood++ }
        }
    }
}
$mainLog2 = Join-Path $env:APPDATA 'Antigravity\logs\main.log'
if (Test-Path -LiteralPath $mainLog2) {
    foreach ($ln in @(Get-Content -LiteralPath $mainLog2 -Tail 260 -ErrorAction SilentlyContinue)) {
        $t = MainTime $ln
        if ($t -and $t -ge $relaunchAt) {
            if ($ln -match 'Agent execution terminated|terminated due to error') { $freshTerm++; L ('   fresh_term_main: ' + (San $ln.Trim())) }
            elseif ($ln -match 'net::ERR_CONNECTION_CLOSED|\[error\]') { L ('   fresh_main_note: ' + (San $ln.Trim())) }
        }
    }
}
$procsAfter = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    (($_.ExecutablePath) -and ($_.ExecutablePath -match 'Antigravity')) -or
    ($_.Name -eq 'Antigravity.exe') -or ($_.Name -eq 'language_server.exe')
})
$pcAfter = 0; $d4After = 0
foreach ($p2 in $procsAfter) {
    foreach ($c2 in @(Get-NetTCPConnection -OwningProcess $p2.ProcessId -ErrorAction SilentlyContinue)) {
        $ra2 = [string]$c2.RemoteAddress
        if ($ra2 -eq '127.0.0.1' -and $c2.RemotePort -eq 10808) { $pcAfter++ }
        elseif ($c2.RemotePort -eq 443 -and $ra2 -notmatch '^127\.') { $d4After++ }
    }
}
L ('fresh summary: ls_lines=' + $freshLines + ' good=' + $freshGood + ' bad=' + $freshBad + ' term=' + $freshTerm + ' procs=' + $procsAfter.Count + ' to_proxy=' + $pcAfter + ' direct443=' + $d4After)

if ($procsAfter.Count -gt 0 -and $freshBad -eq 0 -and $freshTerm -eq 0) { L 'FINAL: AGY_RELAUNCH_OK fresh session has no new network/termination errors.' }
elseif ($freshBad -gt 0) { L 'FINAL: AGY_NETWORK_LAYER_STILL_BAD fresh language_server network errors remain.' }
elseif ($freshTerm -gt 0) { L 'FINAL: AGY_AGENT_TERMINATION_STILL_PRESENT fresh termination marker remains.' }
else { L 'FINAL: AGY_RELAUNCH_CHECK no fresh bad lines, but Antigravity process/proxy activity is not fully proven yet.' }

try { [IO.File]::WriteAllText($reportPath, ($script:Report -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) } catch { }
L ('report: ' + $reportPath)
exit 0
