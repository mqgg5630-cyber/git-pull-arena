# t131_watcher_diag.ps1 - round 173 task: runs ON THE LAPTOP. Round 172
# cloned the new session branch (E:\0github\git-sync\git-pull-arena-01a0fa39)
# and ran watch.ps1 -Register -KeepOthers with rc=0, BUT the follow-up
# Get-ScheduledTask lookup found no task and no state file - and ALL child
# powershell output was swallowed (Write-Host from a child of the zero-
# window watcher context is not captured by & ... 2>&1).
# This round redoes the register with HANDLE-LEVEL redirection via a .cmd
# wrapper (the proven integrun pattern), dumps the FULL register output,
# and enumerates the raw task database (schtasks /query + Get-ScheduledTask
# full scan) before and after, plus watcher state files, so the receipt
# shows exactly what name/path/state the new watcher task has.
# The old watcher (git-sync-watch-git-pull-arena-01a0a9f0) must stay
# Running throughout (-KeepOthers again).
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }
function Cut([string]$s, [int]$n) { if ($s.Length -gt $n) { return $s.Substring(0, $n) }; return $s }

$base = 'E:\0github\git-sync'
$dir = Join-Path $base 'git-pull-arena-01a0fa39'
$oldTask = 'git-sync-watch-git-pull-arena-01a0a9f0'
$newTask = 'git-sync-watch-git-pull-arena-01a0fa39'

L '--- task t131: new watcher diagnose + register with visible output ---'

# ---------------- 0. context ----------------
$isAdmin = $false
try {
    $wp = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $wp.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch { }
L ('   user: ' + $env:USERNAME + ' | elevated: ' + $(if ($isAdmin) { 'yes' } else { 'no' }))
L ('   localappdata: ' + $env:LOCALAPPDATA)
if (-not (Test-Path -LiteralPath (Join-Path $dir 'watch.ps1'))) { L '   [FAIL] new clone or watch.ps1 missing'; exit 2 }
$head = (& git -C $dir log -1 --oneline 2>&1 | Out-String).Trim()
L ('   new clone HEAD: ' + (San $head))

function Show-Tasks([string]$tag) {
    L ('   --- task enumeration (' + $tag + ') ---')
    $csv = & schtasks /query /fo csv 2>&1
    $n = 0
    foreach ($ln in @($csv)) {
        $t = (San ([string]$ln)).Trim()
        if ($t -match 'git-sync-watch') { L ('   schtasks: ' + (Cut $t 150)); $n++ }
    }
    if ($n -eq 0) { L '   schtasks: no git-sync-watch tasks listed' }
    $all = @()
    try { $all = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like 'git-sync-watch-*' }) } catch { }
    if ($all.Count -eq 0) { L '   get-scheduledtask: none matched' }
    foreach ($t in $all) {
        try { L ('   task: ' + (San $t.TaskPath) + (San $t.TaskName) + ' state=' + (San ([string]$t.State))) } catch { }
    }
}

Show-Tasks 'before'

# ---------------- 1. register with handle-level output capture ----------------
$regOut = Join-Path $base 'reg172.txt'
$cmf = Join-Path $base 'regdiag.cmd'
if (Test-Path -LiteralPath $regOut) { Remove-Item -Force -LiteralPath $regOut }
$lines = @(
    '@echo off',
    ('powershell -NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $dir 'watch.ps1') + '" -Register -KeepOthers > "' + $regOut + '" 2>&1'),
    ('echo REG-EXIT %ERRORLEVEL% >> "' + $regOut + '"')
)
[IO.File]::WriteAllLines($cmf, $lines, (New-Object System.Text.ASCIIEncoding))
$t0 = Get-Date
$null = & cmd /c $cmf
$el = [int]((Get-Date) - $t0).TotalSeconds
L ('   register cmd-file finished, elapsed=' + $el + 's')
if (Test-Path -LiteralPath $regOut) {
    $n = 0
    foreach ($ln in @(Get-Content -LiteralPath $regOut)) {
        $t = ((San ([string]$ln)).Trim())
        if ($t -and $n -lt 55) { L ('   reg| ' + (Cut $t 160)); $n++ }
    }
}
else { L '   [FAIL] no register output file produced' }

# ---------------- 2. status with handle-level capture ----------------
$stOut = Join-Path $base 'status172.txt'
$cmf2 = Join-Path $base 'statdiag.cmd'
if (Test-Path -LiteralPath $stOut) { Remove-Item -Force -LiteralPath $stOut }
$lines2 = @(
    '@echo off',
    ('powershell -NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $dir 'watch.ps1') + '" -Status > "' + $stOut + '" 2>&1')
)
[IO.File]::WriteAllLines($cmf2, $lines2, (New-Object System.Text.ASCIIEncoding))
$null = & cmd /c $cmf2
if (Test-Path -LiteralPath $stOut) {
    $n = 0
    foreach ($ln in @(Get-Content -LiteralPath $stOut)) {
        $t = ((San ([string]$ln)).Trim())
        if ($t -and $n -lt 30) { L ('   st| ' + (Cut $t 160)); $n++ }
    }
}

# ---------------- 3. task enumeration after ----------------
Show-Tasks 'after'

# ---------------- 4. watcher state files ----------------
$sd = Join-Path $env:LOCALAPPDATA 'git-sync'
if (Test-Path -LiteralPath $sd) {
    $n = 0
    foreach ($f in @(Get-ChildItem -LiteralPath $sd -File | Where-Object { $_.Name -match '01a0fa39|parked' })) {
        L ('   state file: ' + (San $f.Name) + ' (' + $f.Length + 'B)'); $n++
    }
    if ($n -eq 0) { L '   state files: none matching 01a0fa39 / parked in git-sync dir' }
    $hbFile = Join-Path $sd 'watch-git-pull-arena-01a0fa39.json'
    if (Test-Path -LiteralPath $hbFile) {
        foreach ($ln in @(Get-Content -LiteralPath $hbFile -Raw | ConvertFrom-Json | Select-Object -Property * -ExcludeProperty PSObject* | Out-String) -split "`r?`n") { $t = ((San ([string]$ln)).Trim()); if ($t) { L ('   hb| ' + (Cut $t 150)) } }
    }
    else { L '   [WARN] new watcher heartbeat file still missing' }
    $pf = Join-Path $sd 'watchloop-git-pull-arena-01a0fa39.pid'
    if (Test-Path -LiteralPath $pf) {
        $lpid = 0
        try { $lpid = [int](((Get-Content -LiteralPath $pf -Raw) -replace '[^0-9]', '')) } catch { }
        if ($lpid -gt 0) {
            $lp = Get-Process -Id $lpid -ErrorAction SilentlyContinue
            if ($lp) { L ('   new watcher loop: alive (pid ' + $lpid + ')') }
            else { L ('   new watcher loop: pid ' + $lpid + ' NOT running') }
        }
    }
    else { L '   new watcher loop pid file: not present yet' }
}
else { L '   [WARN] git-sync state dir not found: ' + $sd }
$pd = Join-Path $env:ProgramData 'git-sync'
if (Test-Path -LiteralPath $pd) {
    foreach ($f in @(Get-ChildItem -LiteralPath $pd -File | Where-Object { $_.Name -match '01a0fa39' })) { L ('   host exe: ' + (San $f.Name) + ' (' + [math]::Round($f.Length/1KB) + 'KB)') }
}

# ---------------- 5. old watcher health + heal if needed ----------------
$oldAfter = $null
try { $oldAfter = Get-ScheduledTask -TaskName $oldTask -ErrorAction Stop } catch { }
if ($oldAfter) {
    L ('   old watcher: ' + $oldTask + ' state=' + (San ([string]$oldAfter.State)))
    if ($oldAfter.State -eq 'Disabled') {
        L '   [WARN] old watcher disabled - healing now'
        try { Enable-ScheduledTask -TaskName $oldTask -ErrorAction Stop | Out-Null } catch { }
        try { Start-ScheduledTask -TaskName $oldTask -ErrorAction Stop } catch { }
        Start-Sleep -Seconds 5
        try { $oldAfter = Get-ScheduledTask -TaskName $oldTask -ErrorAction Stop } catch { }
        if ($oldAfter) { L ('   old watcher after heal: state=' + (San ([string]$oldAfter.State))) }
    }
}
else { L '   [WARN] old watcher task not found' }

# ---------------- 6. verdict ----------------
$newFound = $false
$newState = ''
try {
    $nt = Get-ScheduledTask -TaskName $newTask -ErrorAction Stop
    $newFound = $true; $newState = [string]$nt.State
} catch { }
if (-not $newFound) {
    try {
        $any = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like '*01a0fa39*' })
        if ($any.Count -gt 0) { $newFound = $true; $newState = [string]$any[0].State; L ('   new watcher found under name: ' + (San $any[0].TaskName)) }
    } catch { }
}
$hbOk = Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'git-sync\watch-git-pull-arena-01a0fa39.json')
$oldOk = (-not $oldAfter) -or ($oldAfter.State -ne 'Disabled')
if ($newFound -and ($newState -ne 'Disabled') -and $oldOk) {
    L ('   FINAL: PASS - new watcher task exists (state=' + $newState + '), old watcher intact')
    if ($hbOk) { L '   heartbeat file present' } else { L '   [NOTE] heartbeat file not yet present - first poll will write it' }
}
elseif ($newFound -and ($newState -ne 'Disabled')) { L '   FINAL: PARTIAL - new watcher OK but old watcher state unhealthy' }
else { L '   FINAL: FAIL - new watcher task still not found (read the reg| lines above)'; exit 2 }
L '--- task t131 done ---'
exit 0
