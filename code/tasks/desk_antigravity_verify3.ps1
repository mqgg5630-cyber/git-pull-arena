# desk_antigravity_verify3.ps1 - runs ON THE DESKTOP. Read-only deep-dive:
# WHY do post-relaunch dial-tcp errors persist despite the wrapper? Break
# them down by endpoint - telemetry (play.googleapis.com/log) vs OAuth
# (bare "Failed to get OAuth token" / oauth2 / accounts.google /
# cloudcode). Also probe live TCP connections of the Antigravity +
# language server processes to see whether ANY traffic goes through
# 127.0.0.1:10808. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{40,}', '[REDACTED]' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop Antigravity verify3 (endpoint breakdown) ---'

# ---------------- 1. process inventory (Antigravity + language server)
$procs = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    (($_.ExecutablePath) -and ($_.ExecutablePath -match 'Antigravity')) -or
    (($_.Name) -and ($_.Name -match 'language|agentic|gemini')) -or
    (($_.CommandLine) -and ($_.CommandLine -match 'language_server'))
})
$antig = @($procs | Where-Object { $_.Name -match 'Antigravity' } | Sort-Object CreationDate)
$since = $null
if ($antig.Count -gt 0) {
    try { $since = $antig[0].CreationDate } catch { }
}
L ('   matching processes: ' + $procs.Count + ' (earliest Antigravity start: ' + $(if ($since) { $since.ToString('HH:mm:ss') } else { '?' }) + ')')
foreach ($p in $procs) {
    $st = '?'
    try { $st = $p.CreationDate.ToString('HH:mm:ss') } catch { }
    L ('      pid=' + $p.ProcessId + ' start=' + $st + ' name=' + (San ([string]$p.Name)))
}
if (-not $since) { $since = (Get-Date).AddMinutes(-10) }

# ---------------- 2. proxy alive?
$listen = @(Get-NetTCPConnection -LocalPort 10808 -State Listen -ErrorAction SilentlyContinue)
L ('   proxy 127.0.0.1:10808 listening: ' + $(if ($listen.Count -gt 0) { 'yes' } else { 'NO' }))

# ---------------- 3. scheduled task + wrapper on disk
try {
    $t = Get-ScheduledTask -TaskName 'agyrelaunch' -ErrorAction Stop
    L ('   agyrelaunch action: ' + (San ([string]$t.Actions[0].Execute)))
    $i = Get-ScheduledTaskInfo -TaskName 'agyrelaunch' -ErrorAction SilentlyContinue
    if ($i) { L ('   agyrelaunch last run: ' + $(if ($i.LastRunTime) { $i.LastRunTime.ToString('yyyy-MM-dd HH:mm:ss') } else { 'never' })) }
} catch { L ('   agyrelaunch task lookup: ' + (San $_.Exception.Message)) }
$wrapper = 'F:\fig1_rebuild\agy_proxy.cmd'
if (Test-Path -LiteralPath $wrapper) {
    L '   --- wrapper on disk ---'
    foreach ($w in @(Get-Content -LiteralPath $wrapper -ErrorAction SilentlyContinue)) { L ('      ' + (San $w)) }
} else { L '   [WARN] wrapper missing on disk' }

# ---------------- 4. language_server.log breakdown (post-relaunch only)
$lsLog = Join-Path $env:APPDATA 'Antigravity\logs\language_server.log'
if (Test-Path -LiteralPath $lsLog) {
    $all = @(Get-Content -LiteralPath $lsLog -ErrorAction SilentlyContinue)
    $fresh = @()
    foreach ($ln in $all) {
        if ($ln -match '([EWIF]\d{4}) (\d{2}):(\d{2}):(\d{2})') {
            $md = $Matches[1].Substring(1)
            try {
                $t2 = Get-Date -Month ([int]$md.Substring(0,2)) -Day ([int]$md.Substring(2,2)) -Hour ([int]$Matches[2]) -Minute ([int]$Matches[3]) -Second ([int]$Matches[4])
                if ($t2 -ge $since) { $fresh += $ln }
            } catch { }
        }
    }
    $dial = @($fresh | Where-Object { $_ -match 'dial tcp' })
    L ('   post-relaunch lines=' + $fresh.Count + ' dial-tcp=' + $dial.Count)
    $hosts = @{}
    $bare = @()
    foreach ($d in $dial) {
        $h = $null
        if ($d -match '"https?://([^"/:]+)') { $h = $Matches[1] }
        if ($h) { $hosts[$h] = [int]$hosts[$h] + 1 } else { $bare += $d }
    }
    L '   --- dial-tcp by endpoint ---'
    if ($hosts.Count -eq 0 -and $bare.Count -eq 0) { L '      (none)' }
    foreach ($k in @($hosts.Keys)) { L ('      ' + $k + ' : ' + $hosts[$k]) }
    L ('      (no-URL bare lines: ' + $bare.Count + ')')
    foreach ($b in ($bare | Select-Object -First 5)) { L ('         ' + (San ([string]$b).Trim())) }
    $auth = @($fresh | Where-Object { $_ -match 'Failed to get OAuth|oauth2\.googleapis|accounts\.google|cloudcode|userInfo|availableModels|signed [Ii]n' })
    L ('   post-relaunch auth-signature lines: ' + $auth.Count)
    foreach ($a2 in ($auth | Select-Object -First 6)) { L ('      ' + (San ([string]$a2).Trim())) }
    L ('   ls.log lastWrite: ' + ((Get-Item -LiteralPath $lsLog).LastWriteTime.ToString('HH:mm:ss')) + '  last 3 lines:')
    foreach ($f in (@($all) | Select-Object -Last 3)) { L ('      ' + (San ([string]$f).Trim())) }
}
else { L '   [WARN] language_server.log not found' }

# ---------------- 5. live TCP connections of those processes
$proxyConns = 0; $direct443 = 0; $other = 0; $dirIps = ''
foreach ($p in $procs) {
    $cs = @(Get-NetTCPConnection -OwningProcess $p.ProcessId -ErrorAction SilentlyContinue)
    if ($cs.Count -gt 0) { L ('      pid=' + $p.ProcessId + ' (' + (San ([string]$p.Name)) + ') tcp=' + $cs.Count) }
    foreach ($c in $cs) {
        $ra = [string]$c.RemoteAddress
        if ($ra -eq '127.0.0.1' -and $c.RemotePort -eq 10808) { $proxyConns++ }
        elseif ($c.RemotePort -eq 443 -and $ra -notmatch '^127\.') {
            $direct443++
            if ($dirIps.Length -lt 200) { $dirIps += ($ra + '[' + $c.State + '] ') }
        }
        else { $other++ }
    }
}
L ('   live TCP: to-proxy=' + $proxyConns + ' direct-443=' + $direct443 + ' other=' + $other)
if ($dirIps) { L ('      direct-443 targets: ' + $dirIps.Trim()) }

# ---------------- 6. main.log recent errors (electron main)
$mainLog = Join-Path $env:APPDATA 'Antigravity\logs\main.log'
if (Test-Path -LiteralPath $mainLog) {
    $cut = (Get-Date).AddMinutes(-3)
    $recent = @()
    foreach ($ln in @(Get-Content -LiteralPath $mainLog -Tail 80 -ErrorAction SilentlyContinue)) {
        if ($ln -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})') {
            try { $t3 = [DateTime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null); if ($t3 -ge $cut) { $recent += $ln } } catch { }
        }
    }
    $err = @($recent | Where-Object { $_ -match '\[error\]' })
    L ('   main.log last-3min: lines=' + $recent.Count + ' errors=' + $err.Count)
    foreach ($e in ($err | Select-Object -First 3)) { L ('      ' + (San ([string]$e).Trim())) }
}
L '--- verify3 done ---'
