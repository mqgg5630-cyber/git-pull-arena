# install_desktop.ps1 v2 - runs ON THE DESKTOP via ssh (BNI). CRITICAL PATH
# (unzip skills + F:\ search patch + scheduled task) needs NO network.
# Python install / pip are timeout-guarded and DEFERRED to the worker if
# they hang (winget/pip over ssh can stall without a proxy).
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

$root = 'F:\fig1_rebuild'
$stage = Join-Path $root 'stage'

Write-Output '--- desktop install v2 start ---'

# ------------------------------------------ 0. kill orphaned installers (a stuck r116 attempt may linger)
try {
    $orphans = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'install_desktop' -and $_.ProcessId -ne $PID })
    foreach ($p in $orphans) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
    L ('   orphaned installers stopped: ' + $orphans.Count)
} catch { }
try { & taskkill /f /im winget.exe 2>&1 | Out-Null } catch { }

# ------------------------------------------ 1. unzip skills (no network)
$home = [Environment]::GetFolderPath('UserProfile')
$skillsDir = Join-Path $home '.codex\skills'
New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
foreach ($pair in @(@('cell-lct.zip', 'cell-lct'), @('cell_su7.zip', 'cell_su7'))) {
    $zip = Join-Path $stage $pair[0]
    $dest = Join-Path $skillsDir $pair[1]
    if (-not (Test-Path -LiteralPath $zip)) { L ('   [FAIL] missing zip: ' + $zip); exit 2 }
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue }
    Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force
    $runner = Join-Path $dest 'scripts\run_cell_lct.ps1'
    if (-not (Test-Path -LiteralPath $runner)) { L ('   [FAIL] unzip layout wrong for ' + $pair[1]); exit 2 }
    L ('   installed skill: ' + $pair[1])
}

# ------------------------------------------ 2. patch exe search to F:\ (no network)
foreach ($skill in @('cell-lct', 'cell_su7')) {
    $runner = Join-Path $skillsDir ($skill + '\scripts\run_cell_lct.ps1')
    $raw = [string]([IO.File]::ReadAllText($runner))
    $old = "Get-ChildItem -Path 'E:\'"
    $new = "Get-ChildItem -Path 'F:\','E:\'"
    if ($raw.Contains($old)) {
        $raw = $raw.Replace($old, $new)
        [IO.File]::WriteAllText($runner, $raw, (New-Object System.Text.UTF8Encoding($false)))
        L ('   exe-search patched (F: first): ' + $skill)
    }
    elseif ($raw.Contains($new)) { L ('   exe-search already patched: ' + $skill) }
    else { L ('   [WARN] search pattern not found in ' + $skill) }
}

# ------------------------------------------ 3. register the scheduled task (no network)
$worker = Join-Path $root 'desktop_worker.ps1'
if (-not (Test-Path -LiteralPath $worker)) { L ('   [FAIL] worker missing: ' + $worker); exit 2 }
try {
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File "' + $worker + '"')
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
    Register-ScheduledTask -TaskName 'fig1desk' -Action $action -Principal $principal -Settings $settings -Force | Out-Null
    L '   scheduled task registered: fig1desk (interactive, run on demand)'
} catch { L ('   [FAIL] task register: ' + (San $_.Exception.Message)); exit 2 }

# ------------------------------------------ 4. python check (fast, no install here)
try { $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') } catch { }
$pyVer = ''
try { $pyVer = (& py -3 --version 2>$null | Out-String).Trim() } catch { }
L ('   current py -3: ' + $(if ($pyVer) { (San $pyVer) } else { 'NOT FOUND' }))
$pyNew = $false
try { $v = (& py -3 -c "import sys; print(sys.version_info >= (3,11))" 2>$null | Out-String).Trim(); if ($v -match 'True') { $pyNew = $true } } catch { }

if (-not $pyNew) {
    L '   installing Python 3.12 via winget (420s hard cap)...'
    $job = Start-Job -ScriptBlock { & winget install --id Python.Python.3.12 --source winget --scope user --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-String }
    if (Wait-Job $job -Timeout 420) {
        $out = (Receive-Job $job | Out-String).Trim()
        foreach ($ln in ($out -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('   winget| ' + $x) } }
        Remove-Job $job -Force -ErrorAction SilentlyContinue
    } else {
        Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue
        L '   winget TIMEOUT (420s) - python deferred; worker will retry at draw time'
    }
    try { $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') } catch { }
    try { $pyVer = (& py -3 --version 2>$null | Out-String).Trim(); L ('   py -3 after winget: ' + $(if ($pyVer) { (San $pyVer) } else { 'still missing' })) } catch { }
}

# deps: quick timeout-guarded pip (only if py >= 3.11)
try { $v = (& py -3 -c "import sys; print(sys.version_info >= (3,11))" 2>$null | Out-String).Trim(); if ($v -match 'True') { $pyNew = $true } } catch { }
if ($pyNew) {
    $depOk = $false
    try { & py -3 -c "import fontTools" 2>$null; if ($LASTEXITCODE -eq 0) { $depOk = $true } } catch { }
    if (-not $depOk) {
        L '   pip install fonttools+shapely (300s hard cap)...'
        $job = Start-Job -ScriptBlock { & py -3 -m pip install --quiet --disable-pip-version-check --timeout 20 --retries 1 fonttools shapely 2>&1 | Out-String }
        if (Wait-Job $job -Timeout 300) {
            $out = (Receive-Job $job | Out-String).Trim()
            foreach ($ln in ($out -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('   pip| ' + $x) } }
            Remove-Job $job -Force -ErrorAction SilentlyContinue
        } else {
            Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue
            L '   pip TIMEOUT (300s) - deps deferred; worker will retry at draw time'
        }
        try { & py -3 -c "import fontTools" 2>$null; if ($LASTEXITCODE -eq 0) { $depOk = $true } } catch { }
    }
    L ('   py deps: ' + $(if ($depOk) { 'OK' } else { 'PENDING (worker retries)' }))
} else {
    L '   py >= 3.11 not available yet - fully deferred to worker'
}

# ------------------------------------------ 5. verify Illustrator on F:\
$aiExe = $null
foreach ($drive in @('F:\', 'E:\')) {
    foreach ($d in @(Get-ChildItem -Path $drive -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Illustrator' })) {
        $cand = Join-Path $d.FullName 'Support Files\Contents\Windows\Illustrator.exe'
        if (Test-Path -LiteralPath $cand) { $aiExe = $cand; break }
    }
    if ($aiExe) { break }
}
if ($aiExe) { L ('   Illustrator.exe on desktop: ' + (San $aiExe)) }
else { L '   [WARN] Illustrator.exe not found on F:\ or E:\' }

# ------------------------------------------ 6. inputs present?
foreach ($f in @('test_fixture.svg', 'fig1_merged.svg', 'fig1_text_manifest.json', 'desktop_worker.ps1')) {
    L ('   input ' + $f + ': ' + (Test-Path -LiteralPath (Join-Path $root $f)))
}
Write-Output '--- desktop install v2 done ---'
exit 0
