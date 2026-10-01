# desk_antigravity_verify2.ps1 - runs ON THE DESKTOP. Timestamp-accurate
# verification of the v3 wrapper fix: parse language_server.log's
# envelope (E1001 18:55:02 = month/day + time) and count failure
# signatures ONLY in lines newer than the given cutoff (v3 relaunch).
# READ-ONLY. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{40,}', '[REDACTED]' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop Antigravity verify2 (timestamp-accurate) ---'

# newest Antigravity process start time = v3 relaunch moment
$procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'Antigravity' } | Sort-Object StartTime)
$since = $null
if ($procs.Count -gt 0) { $since = $procs[0].StartTime }
L ('   antigravity processes: ' + $procs.Count + ' (earliest start: ' + $(if ($since) { $since.ToString('HH:mm:ss') } else { '?' }) + ')')
if (-not $since) { $since = (Get-Date).AddMinutes(-5) }

$lsLog = Join-Path $env:APPDATA 'Antigravity\logs\language_server.log'
if (Test-Path -LiteralPath $lsLog) {
    $all = @(Get-Content -LiteralPath $lsLog -ErrorAction SilentlyContinue)
    $fresh = @()
    $old = 0
    foreach ($ln in $all) {
        if ($ln -match '([EWIF]\d{4}) (\d{2}):(\d{2}):(\d{2})') {
            $md = $Matches[1].Substring(1)
            $month = [int]$md.Substring(0, 2)
            $day = [int]$md.Substring(2, 2)
            $hh = [int]$Matches[2]; $mm = [int]$Matches[3]; $ss = [int]$Matches[4]
            try {
                $t = Get-Date -Month $month -Day $day -Hour $hh -Minute $mm -Second $ss
                if ($t -ge $since) { $fresh += $ln } else { $old++ }
            } catch { $old++ }
        } else { $old++ }
    }
    $dial = @($fresh | Select-String -Pattern 'dial tcp')
    $garbage = @($fresh | Select-String -Pattern 'record with version 15')
    $ok = @($fresh | Select-String -Pattern 'oauth|token|userInfo|availableModels|loadCodeAssist|signed' -CaseSensitive:$false)
    L ('   language_server.log: total=' + $all.Count + ' pre-relaunch=' + $old + ' post-relaunch=' + $fresh.Count)
    L ('   POST-RELAUNCH dial-tcp=' + $dial.Count + '  tls-garbage=' + $garbage.Count)
    if ($fresh.Count -gt 0) {
        L '   --- post-relaunch sample (last 6) ---'
        foreach ($f in (@($fresh) | Select-Object -Last 6)) { L ('      ' + (San ([string]$f).Trim())) }
    } else { L '   (no post-relaunch lines yet - language server idle until used)' }
}
else { L '   language_server.log not found' }

# auth/backend status from the electron main (recent 3 min)
$mainLog = Join-Path $env:APPDATA 'Antigravity\logs\main.log'
if (Test-Path -LiteralPath $mainLog) {
    $cut = (Get-Date).AddMinutes(-3)
    $recent = @()
    foreach ($ln in @(Get-Content -LiteralPath $mainLog -Tail 80 -ErrorAction SilentlyContinue)) {
        if ($ln -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})') {
            try { $t = [DateTime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null); if ($t -ge $cut) { $recent += $ln } } catch { }
        }
    }
    $err = @($recent | Select-String -Pattern '\[error\]')
    L ('   main.log last-3min: lines=' + $recent.Count + ' errors=' + $err.Count)
    foreach ($e in ($err | Select-Object -First 3)) { L ('      ' + (San ([string]$e.Line).Trim())) }
}
L '--- verify2 done ---'
