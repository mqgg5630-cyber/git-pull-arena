# t133_watcher_health.ps1 - round 175 task: runs ON THE LAPTOP. Health
# check of ALL git-sync watchers:
#   - 01a0a9f0 (THIS session) - must be Running, fresh heartbeat
#   - 01a0ff64 (newest session) - must be Running, fresh heartbeat
#   - 01a0fa39 (retired) - must stay Disabled, loop dead
# For each: watch.ps1 -Status via cmd-file capture (read-only), heartbeat
# age vs the 2-minute interval, loop pid liveness, host log tail, git
# ahead/behind vs origin. Plus a machine-wide scan for leftover watcher
# loop processes and the park ledger.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }
function Cut([string]$s, [int]$n) { if ($s.Length -gt $n) { return $s.Substring(0, $n) }; return $s }

$base = 'E:\0github\git-sync'
$sd = Join-Path $env:LOCALAPPDATA 'git-sync'
$clones = @(
    @{ tag = '01a0a9f0 (this session)'; dir = Join-Path $base 'git-pull-arena-01a0a9f0'; repo = 'git-pull-arena-01a0a9f0'; expect = 'running' },
    @{ tag = '01a0ff64 (newest)';       dir = Join-Path $base 'git-pull-arena-01a0ff64'; repo = 'git-pull-arena-01a0ff64'; expect = 'running' },
    @{ tag = '01a0fa39 (retired)';      dir = Join-Path $base 'git-pull-arena-01a0fa39'; repo = 'git-pull-arena-01a0fa39'; expect = 'disabled' }
)

L '--- task t133: watcher health check (all watchers) ---'
L ('   now: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' on ' + $env:COMPUTERNAME)

# ---------------- 0. task states ----------------
L '   --- scheduled tasks ---'
$tasks = @()
try { $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like 'git-sync-watch-*' }) } catch { }
foreach ($t in $tasks) { L ('   task: ' + (San $t.TaskName) + ' state=' + (San ([string]$t.State))) }
if ($tasks.Count -eq 0) { L '   no git-sync-watch tasks found' }

# ---------------- 1. per-clone status ----------------
foreach ($c in $clones) {
    L ('   === ' + $c.tag + ' ===')
    $dir = $c.dir
    if (-not (Test-Path -LiteralPath (Join-Path $dir 'watch.ps1'))) { L '   [WARN] clone/watch.ps1 missing: ' + $dir; continue }

    # watch.ps1 -Status via cmd-file capture
    $out = Join-Path $base ('stat_' + $c.repo + '.txt')
    $cmf = Join-Path $base ('stat_' + $c.repo + '.cmd')
    if (Test-Path -LiteralPath $out) { Remove-Item -Force -LiteralPath $out }
    $lines = @(
        '@echo off',
        ('powershell -NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $dir 'watch.ps1') + '" -Status > "' + $out + '" 2>&1')
    )
    [IO.File]::WriteAllLines($cmf, $lines, (New-Object System.Text.ASCIIEncoding))
    $null = & cmd /c $cmf
    if (Test-Path -LiteralPath $out) {
        foreach ($ln in @(Get-Content -LiteralPath $out)) {
            $t = ((San ([string]$ln)).Trim())
            if ($t -match 'repo |branch |task |skill |hands-free|scheduled|last run|next keeper|loop process|loop alive|heartbeat age|paused|other loops|other tasks|parked') { L ('   st| ' + (Cut $t 160)) }
        }
    }
    else { L '   [WARN] status capture failed' }

    # heartbeat age straight from the state file
    $hbFile = Join-Path $sd ('watch-' + $c.repo + '.json')
    if (Test-Path -LiteralPath $hbFile) {
        try {
            $hb = Get-Content -LiteralPath $hbFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $lr = [string]$hb.last_run
            $age = -1
            try {
                $dt = [datetime]::ParseExact($lr, 'yyyy-MM-dd HH:mm:ss', $null)
                $age = [int]((Get-Date) - $dt).TotalMinutes
            } catch { }
            $lpid = [int]($hb.pid)
            $lpAlive = $false
            if ($lpid -gt 0) { $lpAlive = [bool](Get-Process -Id $lpid -ErrorAction SilentlyContinue) }
            L ('   hb| last_action=' + (San ([string]$hb.last_action)) + ' last_run=' + (San $lr) + ' age=' + $age + 'min pid=' + $lpid + ' alive=' + $(if ($lpAlive) { 'yes' } else { 'no' }))
        } catch { L '   [WARN] heartbeat parse failed' }
    }
    else { L '   hb| no state file' }

    # host log tail
    $log = Join-Path $sd ('watch-' + $c.repo + '.log')
    if (Test-Path -LiteralPath $log) {
        $tl = @(Get-Content -LiteralPath $log -Tail 6)
        foreach ($ln in $tl) { $t = ((San ([string]$ln)).Trim()); if ($t) { L ('   log| ' + (Cut $t 150)) } }
    }

    # git currency (skip fetch for the retired clone)
    if ($c.expect -eq 'running') {
        $null = & git -C $dir fetch -q origin 2>&1
        $br = (& git -C $dir rev-parse --abbrev-ref HEAD 2>&1 | Out-String).Trim()
        $loc = (& git -C $dir rev-parse HEAD 2>&1 | Out-String).Trim()
        $rem = (& git -C $dir rev-parse ('origin/' + $br) 2>&1 | Out-String).Trim()
        $ahead = (& git -C $dir rev-list --count ('origin/' + $br + '..HEAD') 2>&1 | Out-String).Trim()
        $behind = (& git -C $dir rev-list --count ('HEAD..origin/' + $br) 2>&1 | Out-String).Trim()
        $dirty = @(& git -C $dir status --short 2>$null).Count
        L ('   git| branch=' + (San $br) + ' ahead=' + (San $ahead) + ' behind=' + (San $behind) + ' dirty=' + $dirty + ' head=' + (San ((& git -C $dir log -1 --oneline 2>&1 | Out-String).Trim())))
    }
}

# ---------------- 2. machine-wide leftover loop processes ----------------
L '   --- watcher processes (machine-wide) ---'
$procs = @()
try { $procs = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'watch\.ps1' -and $_.CommandLine -match '-Loop' }) } catch { }
if ($procs.Count -eq 0) { L '   no powershell -Loop processes' }
foreach ($p in $procs) { L ('   loop: pid=' + $p.ProcessId + ' ' + (Cut (San ([string]$p.CommandLine)) 130)) }
$hosts = @()
try { $hosts = @(Get-Process | Where-Object { $_.Name -like 'watchhost-*' }) } catch { }
foreach ($h in $hosts) { L ('   host: ' + (San $h.Name) + ' pid=' + $h.Id) }
if ($hosts.Count -eq 0) { L '   no watchhost processes (flash mode uses powershell loop instead)' }

# ---------------- 3. park ledger ----------------
$parkFile = Join-Path $sd 'parked.json'
if (Test-Path -LiteralPath $parkFile) {
    try {
        $pl = Get-Content -LiteralPath $parkFile -Raw -Encoding UTF8 | ConvertFrom-Json
        L ('   park ledger: ' + @($pl.items).Count + ' item(s), last_focus=' + (San ([string]$pl.last_focus)) + ' at ' + (San ([string]$pl.updated)))
    } catch { L '   park ledger: unreadable' }
}
else { L '   park ledger: none' }

# ---------------- verdict ----------------
$mine = $null;  $ff64 = $null; $fa39 = $null
foreach ($t in $tasks) {
    $n = [string]$t.TaskName
    if ($n -match '01a0a9f0') { $mine = $t }
    elseif ($n -match '01a0ff64') { $ff64 = $t }
    elseif ($n -match '01a0fa39') { $fa39 = $t }
}
$okMine = ($mine -and ([string]$mine.State -eq 'Running'))
$okFf64 = ($ff64 -and ([string]$ff64.State -eq 'Running'))
$okFa39 = ($fa39 -and ([string]$fa39.State -eq 'Disabled'))
if (-not $fa39) { $okFa39 = $true; L '   [note] 01a0fa39 task not present (treated as retired)' }
if ($okMine -and $okFf64 -and $okFa39) { L '   FINAL: PASS - this session Running, newest Running, retired Disabled' }
else {
    L ('   FINAL: FAIL - mine=' + $(if ($mine) { [string]$mine.State } else { 'missing' }) + ' ff64=' + $(if ($ff64) { [string]$ff64.State } else { 'missing' }) + ' fa39=' + $(if ($fa39) { [string]$fa39.State } else { 'missing' }))
    exit 2
}
L '--- task t133 done ---'
exit 0
