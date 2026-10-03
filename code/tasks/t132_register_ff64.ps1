# t132_register_ff64.ps1 - round 174 task: runs ON THE LAPTOP. Two jobs:
#   A) register the watcher for the NEWEST session branch
#      arena/01a0ff64-git-pull-arena (clone into
#      E:\0github\git-sync\git-pull-arena-01a0ff64, bootstrap, auth -Setup,
#      watch.ps1 -Register -KeepOthers),
#   B) STOP the watcher of the RETIRED session branch
#      arena/01a0fa39-git-pull-arena: run its own watch.ps1 -Pause (stops
#      the task, kills its loop process, disables the task; reversible
#      later with .\watch.ps1 -Resume in that clone).
# THIS old watcher (git-sync-watch-git-pull-arena-01a0a9f0) must stay
# Running throughout: -KeepOthers at registration, and -Pause is run only
# in the 01a0fa39 clone so it can only touch its own task.
# All child scripts run via cmd files with handle-level output capture
# (the proven r173 pattern - & powershell from the watcher context swallows
# Write-Host and can silently no-op).
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }
function Cut([string]$s, [int]$n) { if ($s.Length -gt $n) { return $s.Substring(0, $n) }; return $s }

$base = 'E:\0github\git-sync'
$url = 'https://github.com/mqgg5630-cyber/git-pull-arena.git'
$branch = 'arena/01a0ff64-git-pull-arena'
$dir = Join-Path $base 'git-pull-arena-01a0ff64'
$dir39 = Join-Path $base 'git-pull-arena-01a0fa39'
$myTask = 'git-sync-watch-git-pull-arena-01a0a9f0'
$prevTask = 'git-sync-watch-git-pull-arena-01a0fa39'
$newTask = 'git-sync-watch-git-pull-arena-01a0ff64'

L '--- task t132: register 01a0ff64 watcher + pause 01a0fa39 watcher ---'

$isAdmin = $false
try {
    $wp = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $wp.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch { }
L ('   user: ' + $env:USERNAME + ' | elevated: ' + $(if ($isAdmin) { 'yes' } else { 'no' }))

function Show-Tasks([string]$tag) {
    L ('   --- git-sync-watch tasks (' + $tag + ') ---')
    $all = @()
    try { $all = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like 'git-sync-watch-*' }) } catch { }
    if ($all.Count -eq 0) { L '   none found' }
    foreach ($t in $all) {
        try { L ('   task: ' + (San $t.TaskName) + ' state=' + (San ([string]$t.State))) } catch { }
    }
}

Show-Tasks 'before'

# ---------------- A1. clone or update the new branch ----------------
if (Test-Path -LiteralPath (Join-Path $dir '.git')) {
    L ('   dir exists, fast-forwarding: ' + $dir)
    $null = & git -C $dir fetch origin 2>&1
    if ($LASTEXITCODE -ne 0) { L '   [FAIL] git fetch failed'; exit 2 }
    $null = & git -C $dir checkout $branch 2>&1
    if ($LASTEXITCODE -ne 0) { L ('   [FAIL] cannot check out ' + $branch); exit 2 }
    $null = & git -C $dir pull --ff-only origin $branch 2>&1
    if ($LASTEXITCODE -ne 0) { L '   [FAIL] pull --ff-only failed'; exit 2 }
    L '   update OK'
}
else {
    if (Test-Path -LiteralPath $dir) {
        L '   dir exists without .git - removing and recloning'
        Remove-Item -Recurse -Force -LiteralPath $dir
    }
    if (-not (Test-Path -LiteralPath $base)) { New-Item -ItemType Directory -Force -Path $base | Out-Null }
    L ('   cloning ' + $branch)
    $co = & git clone -b $branch $url $dir 2>&1
    if ($LASTEXITCODE -ne 0) {
        L ('   [FAIL] clone failed rc=' + $LASTEXITCODE)
        foreach ($ln in @($co | Select-Object -Last 5)) { L ('      ' + (Cut (San ([string]$ln)) 180)) }
        exit 2
    }
    L '   clone OK'
}
$head = (& git -C $dir log -1 --oneline 2>&1 | Out-String).Trim()
L ('   HEAD: ' + (San $head))
$un = (& git -C $dir config user.name 2>&1 | Out-String).Trim()
if (-not $un) {
    $null = & git -C $dir config user.name 'mqgg5630-cyber'
    $null = & git -C $dir config user.email 'mqgg5630-cyber@users.noreply.github.com'
    L '   set repo-local git identity (mqgg5630-cyber)'
}
else { L ('   git identity: ' + (San $un)) }
$curBr = (& git -C $dir rev-parse --abbrev-ref HEAD 2>&1 | Out-String).Trim()
L ('   checked out branch: ' + (San $curBr))
if ($curBr -ne $branch) { L '   [FAIL] wrong branch checked out'; exit 2 }

# ---------------- A2. bootstrap / auth / register via cmd files ----------------
function Run-Capture([string]$tag, [string]$psFile, [string]$args_) {
    $out = Join-Path $base ($tag + '.txt')
    $cmf = Join-Path $base ($tag + '.cmd')
    if (Test-Path -LiteralPath $out) { Remove-Item -Force -LiteralPath $out }
    $lines = @(
        '@echo off',
        ('powershell -NoProfile -ExecutionPolicy Bypass -File "' + $psFile + '" ' + $args_ + ' > "' + $out + '" 2>&1'),
        ('echo ' + $tag.ToUpper() + '-EXIT %ERRORLEVEL% >> "' + $out + '"')
    )
    [IO.File]::WriteAllLines($cmf, $lines, (New-Object System.Text.ASCIIEncoding))
    $null = & cmd /c $cmf
    return $out
}

$bootOut = Run-Capture 'boot174' (Join-Path $dir 'bootstrap.ps1') ''
L ('   --- bootstrap ---')
$exitLine = ''
foreach ($ln in @(Get-Content -LiteralPath $bootOut -ErrorAction SilentlyContinue)) {
    $t = ((San ([string]$ln)).Trim())
    if ($t -match 'BOOT174-EXIT') { $exitLine = $t }
    if ($t -and $t -notmatch 'BOOT174-EXIT' -and $t -match 'ready|latest commit|branch|ERROR|identity|policy') { L ('   boot| ' + (Cut $t 160)) }
}
L ('   boot| ' + $exitLine)

$authOut = Run-Capture 'auth174' (Join-Path $dir 'auth.ps1') '-Setup'
L ('   --- auth -Setup ---')
$exitLine = ''
$authTail = @()
foreach ($ln in @(Get-Content -LiteralPath $authOut -ErrorAction SilentlyContinue)) {
    $t = ((San ([string]$ln)).Trim())
    if ($t -match 'AUTH174-EXIT') { $exitLine = $t }
    elseif ($t) { $authTail += $t }
}
foreach ($t in (@($authTail | Select-Object -Last 5))) { L ('   auth| ' + (Cut $t 160)) }
L ('   auth| ' + $exitLine)

$regOut = Run-Capture 'reg174' (Join-Path $dir 'watch.ps1') '-Register -KeepOthers'
L ('   --- watch -Register -KeepOthers ---')
foreach ($ln in @(Get-Content -LiteralPath $regOut -ErrorAction SilentlyContinue)) {
    $t = ((San ([string]$ln)).Trim())
    if ($t -and $t -match 'registered|self-test|heartbeat|mode|KeepOthers|parked|ERROR|FAILED|watcher will now|poll |this check') { L ('   reg| ' + (Cut $t 170)) }
}

# ---------------- A3. verify the new watcher ----------------
$newT = $null
try { $newT = Get-ScheduledTask -TaskName $newTask -ErrorAction Stop } catch { }
if ($newT) { L ('   new watcher task: ' + $newTask + ' state=' + (San ([string]$newT.State))) }
else { L '   [FAIL] new watcher task not found after register' }
$hbFile = Join-Path $env:LOCALAPPDATA 'git-sync\watch-git-pull-arena-01a0ff64.json'
$hbOk = $false
if (Test-Path -LiteralPath $hbFile) {
    try {
        $hb = Get-Content -LiteralPath $hbFile -Raw -Encoding UTF8 | ConvertFrom-Json
        L ('   new watcher heartbeat: last_run=' + (San ([string]$hb.last_run)) + ' pid=' + (San ([string]$hb.pid)) + ' branch=' + (San ([string]$hb.branch)))
        if ($hb.last_run) { $hbOk = $true }
    } catch { L '   [WARN] cannot parse new heartbeat file' }
}
else { L '   [WARN] new heartbeat file not present yet' }
$pf = Join-Path $env:LOCALAPPDATA 'git-sync\watchloop-git-pull-arena-01a0ff64.pid'
if (Test-Path -LiteralPath $pf) {
    $lpid = 0
    try { $lpid = [int](((Get-Content -LiteralPath $pf -Raw) -replace '[^0-9]', '')) } catch { }
    if ($lpid -gt 0) {
        $lp = Get-Process -Id $lpid -ErrorAction SilentlyContinue
        if ($lp) { L ('   new watcher loop: alive (pid ' + $lpid + ')') }
        else { L ('   new watcher loop: pid ' + $lpid + ' NOT running (keeper tick will restart it)') }
    }
}

Show-Tasks 'after register'

# ---------------- B. pause the 01a0fa39 watcher ----------------
if (Test-Path -LiteralPath (Join-Path $dir39 'watch.ps1')) {
    $pauseOut = Run-Capture 'pause174' (Join-Path $dir39 'watch.ps1') '-Pause'
    L ('   --- watch -Pause (01a0fa39 clone) ---')
    foreach ($ln in @(Get-Content -LiteralPath $pauseOut -ErrorAction SilentlyContinue)) {
        $t = ((San ([string]$ln)).Trim())
        if ($t) { L ('   pause| ' + (Cut $t 160)) }
    }
}
else {
    L '   [WARN] 01a0fa39 clone missing - pausing its task directly'
    try { Stop-ScheduledTask -TaskName $prevTask -ErrorAction SilentlyContinue } catch { }
    try { Disable-ScheduledTask -TaskName $prevTask -ErrorAction SilentlyContinue } catch { }
    $pf39 = Join-Path $env:LOCALAPPDATA 'git-sync\watchloop-git-pull-arena-01a0fa39.pid'
    if (Test-Path -LiteralPath $pf39) {
        try {
            $lpid39 = [int](((Get-Content -LiteralPath $pf39 -Raw) -replace '[^0-9]', ''))
            if ($lpid39 -gt 0) { Stop-Process -Id $lpid39 -Force -ErrorAction SilentlyContinue }
        } catch { }
        Remove-Item -LiteralPath $pf39 -Force -ErrorAction SilentlyContinue
    }
}

# verify paused state
$prevT = $null
try { $prevT = Get-ScheduledTask -TaskName $prevTask -ErrorAction Stop } catch { }
if ($prevT) { L ('   prev watcher (01a0fa39) task state: ' + (San ([string]$prevT.State))) }
else { L '   prev watcher (01a0fa39) task: not found (was never registered or already removed)' }
$pf39b = Join-Path $env:LOCALAPPDATA 'git-sync\watchloop-git-pull-arena-01a0fa39.pid'
if (Test-Path -LiteralPath $pf39b) {
    $lpid39b = 0
    try { $lpid39b = [int](((Get-Content -LiteralPath $pf39b -Raw) -replace '[^0-9]', '')) } catch { }
    if ($lpid39b -gt 0) {
        $lp39 = Get-Process -Id $lpid39b -ErrorAction SilentlyContinue
        if ($lp39) { L ('   [WARN] 01a0fa39 loop still alive (pid ' + $lpid39b + ') - killing') ; Stop-Process -Id $lpid39b -Force -ErrorAction SilentlyContinue }
        else { L '   01a0fa39 loop process: dead' }
    }
}
else { L '   01a0fa39 loop pid file: gone (loop stopped)' }

# ---------------- C. my old watcher must still be Running ----------------
$myT = $null
try { $myT = Get-ScheduledTask -TaskName $myTask -ErrorAction Stop } catch { }
if ($myT) {
    L ('   this session watcher (01a0a9f0): state=' + (San ([string]$myT.State)))
    if ($myT.State -eq 'Disabled') {
        L '   [WARN] my watcher got disabled - healing now'
        try { Enable-ScheduledTask -TaskName $myTask -ErrorAction Stop | Out-Null } catch { }
        try { Start-ScheduledTask -TaskName $myTask -ErrorAction Stop } catch { }
        Start-Sleep -Seconds 5
        try { $myT = Get-ScheduledTask -TaskName $myTask -ErrorAction Stop } catch { }
        if ($myT) { L ('   this session watcher after heal: state=' + (San ([string]$myT.State))) }
    }
}
else { L '   [WARN] this session watcher (01a0a9f0) task not found' }

Show-Tasks 'final'

# ---------------- verdict ----------------
$newOk = ($newT -and ($newT.State -ne 'Disabled') -and $hbOk)
$prevStopped = ($prevT -and ($prevT.State -eq 'Disabled')) -or (-not $prevT)
$myOk = ($myT -and ($myT.State -ne 'Disabled'))
if ($newOk -and $prevStopped -and $myOk) {
    L '   FINAL: PASS - 01a0ff64 watcher registered and running; 01a0fa39 watcher paused; 01a0a9f0 watcher intact'
    L ('   new watcher serves: ' + $branch + ' at ' + $dir)
    L '   resume 01a0fa39 later with: cd ' + $dir39 + ' ; .\watch.ps1 -Resume'
}
elseif ($newOk -and $prevStopped) { L '   FINAL: PARTIAL - new OK and old paused, but THIS session watcher state unhealthy' }
else { L '   FINAL: FAIL - see lines above'; exit 2 }
L '--- task t132 done ---'
exit 0
