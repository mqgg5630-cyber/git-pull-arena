# t130_register_watcher.ps1 - round 172 task: runs ON THE LAPTOP (the
# machine where THIS old watcher, git-sync-watch-git-pull-arena-01a0a9f0,
# runs). Registers the watcher for the NEW Arena session branch
# arena/01a0fa39-git-pull-arena:
#   1. clone (or fast-forward update) the branch into
#      E:\0github\git-sync\git-pull-arena-01a0fa39,
#   2. bootstrap.ps1 (execution policy + repo-local git identity +
#      checkout/ff, NO -Auto),
#   3. auth.ps1 -Setup (non-interactive verify/fix of push auth),
#   4. watch.ps1 -Register -KeepOthers  <-- KeepOthers is essential: the
#      default -Register parks (stops + disables) every OTHER
#      git-sync-watch-* task, which would stop THIS old watcher mid-round
#      and kill the round-172 receipt. With -KeepOthers both watchers run:
#      the old one keeps serving arena/01a0a9f0, the new one serves
#      arena/01a0fa39.
#   5. doctor.ps1 + watch.ps1 -Status for the new clone,
#   6. verify BOTH tasks are alive at the end (self-heal: if the old task
#      somehow got disabled, re-enable + restart it).
# All sub-scripts run as CHILD powershell.exe processes because they call
# exit - an in-process invocation would terminate this task.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }
function Cut([string]$s, [int]$n) { if ($s.Length -gt $n) { return $s.Substring(0, $n) }; return $s }

$base = 'E:\0github\git-sync'
$url = 'https://github.com/mqgg5630-cyber/git-pull-arena.git'
$branch = 'arena/01a0fa39-git-pull-arena'
$dir = Join-Path $base 'git-pull-arena-01a0fa39'
$oldTask = 'git-sync-watch-git-pull-arena-01a0a9f0'
$newTask = 'git-sync-watch-git-pull-arena-01a0fa39'

L '--- task t130: register watcher for new session branch ---'

# ---------------- 0. old watcher sanity ----------------
$oldBefore = $null
try { $oldBefore = Get-ScheduledTask -TaskName $oldTask -ErrorAction Stop } catch { }
if ($oldBefore) { L ('   old watcher before: ' + $oldTask + ' state=' + $oldBefore.State) }
else { L '   [WARN] old watcher task not found on this machine' }
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
L ('   this repo: ' + $repoRoot)

# ---------------- 1. clone or update ----------------
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
    L ('   from ' + $url)
    $co = & git clone -b $branch $url $dir 2>&1
    if ($LASTEXITCODE -ne 0) {
        L ('   [FAIL] clone failed rc=' + $LASTEXITCODE)
        foreach ($ln in @($co | Select-Object -Last 5)) { L ('      ' + (Cut (San ([string]$ln)) 180)) }
        exit 2
    }
    L '   clone OK'
}

# ---------------- 2. head + git identity ----------------
$head = (& git -C $dir log -1 --oneline 2>&1 | Out-String).Trim()
L ('   HEAD: ' + (San $head))
$un = (& git -C $dir config user.name 2>&1 | Out-String).Trim()
if (-not $un) {
    $null = & git -C $dir config user.name 'mqgg5630-cyber'
    $null = & git -C $dir config user.email 'mqgg5630-cyber@users.noreply.github.com'
    L '   set repo-local git identity (mqgg5630-cyber)'
}
else { L ('   git identity: ' + (San $un)) }
$cfgBranch = (& git -C $dir rev-parse --abbrev-ref HEAD 2>&1 | Out-String).Trim()
L ('   checked out branch: ' + (San $cfgBranch))
if ($cfgBranch -ne $branch) { L ('   [FAIL] wrong branch checked out'); exit 2 }

# ---------------- 3. bootstrap (policy + identity + ff; no -Auto) ----------------
$bs = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir 'bootstrap.ps1') 2>&1
$bsRc = $LASTEXITCODE
$bsTxt = ((($bs | Out-String).Trim()) -split "`r?`n")
L ('   bootstrap rc=' + $bsRc)
foreach ($ln in (@($bsTxt | Where-Object { $_.Trim() } | Select-Object -First 10))) { L ('      ' + (Cut (San $ln) 170)) }
if ($bsRc -ne 0) { L '   [FAIL] bootstrap failed'; exit 2 }

# ---------------- 4. auth setup (non-interactive) ----------------
$au = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir 'auth.ps1') -Setup 2>&1
$auRc = $LASTEXITCODE
$auTxt = ((($au | Out-String).Trim()) -split "`r?`n")
L ('   auth -Setup rc=' + $auRc)
foreach ($ln in (@($auTxt | Where-Object { $_.Trim() } | Select-Object -Last 8))) { L ('      ' + (Cut (San $ln) 170)) }
if ($auRc -ne 0) { L '   [WARN] auth setup returned nonzero - pushes from the new clone may prompt' }

# ---------------- 5. register the new watcher (KEEP the old one) ----------------
$rg = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir 'watch.ps1') -Register -KeepOthers 2>&1
$rgRc = $LASTEXITCODE
$rgTxt = ((($rg | Out-String).Trim()) -split "`r?`n")
L ('   watch -Register -KeepOthers rc=' + $rgRc)
foreach ($ln in (@($rgTxt | Where-Object { $_ -match 'registered|self-test|heartbeat|KeepOthers|parked|mode:|ERROR|FAILED|watcher' } | Select-Object -First 14))) { L ('      ' + (Cut (San $ln) 170)) }
if ($rgRc -ne 0) { L '   [FAIL] register failed'; exit 2 }

# ---------------- 6. doctor + status of the new clone ----------------
$dc = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir 'doctor.ps1') 2>&1
$dcRc = $LASTEXITCODE
$dcTxt = ((($dc | Out-String).Trim()) -split "`r?`n")
L ('   doctor rc=' + $dcRc)
foreach ($ln in (@($dcTxt | Where-Object { $_ -match 'OK|FAIL|WARN|ERROR|ready|task|heartbeat' } | Select-Object -First 12))) { L ('      ' + (Cut (San $ln) 170)) }

$st = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir 'watch.ps1') -Status 2>&1
$stRc = $LASTEXITCODE
$stTxt = ((($st | Out-String).Trim()) -split "`r?`n")
L ('   watch -Status rc=' + $stRc)
foreach ($ln in (@($stTxt | Where-Object { $_ -match 'scheduled|heartbeat|loop|branch|repo|task|parked|other' } | Select-Object -First 14))) { L ('      ' + (Cut (San $ln) 170)) }

# ---------------- 7. verify BOTH watchers ----------------
$newT = $null
try { $newT = Get-ScheduledTask -TaskName $newTask -ErrorAction Stop } catch { }
$oldAfter = $null
try { $oldAfter = Get-ScheduledTask -TaskName $oldTask -ErrorAction Stop } catch { }
if ($newT) { L ('   new watcher task: ' + $newTask + ' state=' + $newT.State) }
else { L '   [FAIL] new watcher task not registered' }
if ($oldAfter) { L ('   old watcher task: ' + $oldTask + ' state=' + $oldAfter.State) }
else { L '   [WARN] old watcher task not found after register' }

# self-heal: if the old watcher got disabled despite -KeepOthers, restore it
if ($oldAfter -and ($oldAfter.State -eq 'Disabled')) {
    L '   [WARN] old watcher was disabled - re-enabling and starting it now'
    try { Enable-ScheduledTask -TaskName $oldTask -ErrorAction Stop | Out-Null } catch { }
    try { Start-ScheduledTask -TaskName $oldTask -ErrorAction Stop } catch { }
    Start-Sleep -Seconds 5
    try { $oldAfter = Get-ScheduledTask -TaskName $oldTask -ErrorAction Stop } catch { }
    if ($oldAfter) { L ('   old watcher after heal: state=' + $oldAfter.State) }
}

# new watcher heartbeat + loop process
$hbOk = $false
$stateFile = Join-Path $env:LOCALAPPDATA ('git-sync\watch-git-pull-arena-01a0fa39.json')
if (Test-Path -LiteralPath $stateFile) {
    try {
        $hb = Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
        L ('   new watcher heartbeat: last_run=' + (San ([string]$hb.last_run)) + ' registered=' + (San ([string]$hb.registered)))
        if ($hb.last_run) { $hbOk = $true }
    } catch { L '   [WARN] cannot parse new watcher state file' }
}
else { L '   [WARN] new watcher state file not found yet' }
$pidFile = Join-Path $env:LOCALAPPDATA ('git-sync\watchloop-git-pull-arena-01a0fa39.pid')
if (Test-Path -LiteralPath $pidFile) {
    $lpid = 0
    try { $lpid = [int](((Get-Content -LiteralPath $pidFile -Raw) -replace '[^0-9]', '')) } catch { }
    if ($lpid -gt 0) {
        $lp = Get-Process -Id $lpid -ErrorAction SilentlyContinue
        if ($lp) { L ('   new watcher loop: alive (pid ' + $lpid + ')') }
        else { L ('   new watcher loop: pid ' + $lpid + ' not running (will start on next task tick)') }
    }
}
# park ledger should not list the old task
$parkFile = Join-Path $env:LOCALAPPDATA 'git-sync\parked.json'
if (Test-Path -LiteralPath $parkFile) {
    try {
        $pl = Get-Content -LiteralPath $parkFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($pl.items -and @($pl.items).Count -gt 0) {
            L ('   [WARN] park ledger has ' + @($pl.items).Count + ' item(s) (last_focus=' + (San ([string]$pl.last_focus)) + ')')
        }
        else { L '   park ledger: empty (nothing parked)' }
    } catch { }
}

# ---------------- 8. verdict ----------------
$ok = ($newT -and ($newT.State -ne 'Disabled') -and $hbOk)
$oldOk = (-not $oldBefore) -or ($oldAfter -and ($oldAfter.State -ne 'Disabled'))
if ($ok -and $oldOk) {
    L '   FINAL: PASS - new watcher registered and alive; old watcher untouched'
    L ('   new watcher serves: ' + $branch + ' at ' + $dir)
    L '   it idles until that session posts its next round request'
}
elseif ($ok -and -not $oldOk) { L '   FINAL: PARTIAL - new watcher OK but old watcher state is not healthy' }
else { L '   FINAL: FAIL - new watcher not verified'; exit 2 }
L '--- task t130 done ---'
exit 0
