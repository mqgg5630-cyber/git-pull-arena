# install_desktop.ps1 - runs ON THE DESKTOP via ssh (BNI). Installs the
# two bridge-patched skills from the staged zips, ensures Python 3.12 +
# fontTools/shapely, patches Get-CsIllustratorExe to search F:\ too, and
# registers the interactive scheduled task 'fig1desk' that runs
# desktop_worker.ps1. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

$root = 'F:\fig1_rebuild'
$stage = Join-Path $root 'stage'

Write-Output '--- desktop install start ---'

# ------------------------------------------ 1. unzip skills
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

# ------------------------------------------ 2. patch exe search to include F:\
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
    else { L ('   [WARN] search pattern not found in ' + $skill + ' (bridge layout differs?)') }
}

# ------------------------------------------ 3. python 3.12 (py launcher)
$pyGood = $false
try {
    $v = (& py -3 -c "import sys; print(sys.version_info[:2] >= (3,11))" 2>$null | Out-String).Trim()
    if ($v -match 'True') { $pyGood = $true }
} catch { }
if (-not $pyGood) {
    L 'installing Python 3.12 (user scope, winget) ...'
    & winget install --id Python.Python.3.12 --scope user --silent --accept-package-agreements --accept-source-agreements 2>&1 | ForEach-Object { L ('   winget| ' + (San ([string]$_))) }
    Start-Sleep -Seconds 5
    try { $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') } catch { }
}
$depOk = $false
try { & py -3 -c "import fontTools" 2>$null; if ($LASTEXITCODE -eq 0) { $depOk = $true } } catch { }
if (-not $depOk) {
    L 'installing fonttools + shapely into py -3 ...'
    & py -3 -m pip install --quiet --disable-pip-version-check fonttools shapely 2>&1 | ForEach-Object { L ('   pip| ' + (San ([string]$_))) }
    try { & py -3 -c "import fontTools" 2>$null; if ($LASTEXITCODE -eq 0) { $depOk = $true } } catch { }
}
L ('py -3 + deps: ' + $(if ($depOk) { 'OK' } else { 'MISSING (worker will retry install)' }))
try { $pv = (& py -3 --version 2>$null | Out-String).Trim(); L ('   py -3 version: ' + (San $pv)) } catch { }

# ------------------------------------------ 4. verify Illustrator on F:\
$aiExe = $null
foreach ($drive in @('F:\', 'E:\')) {
    foreach ($d in @(Get-ChildItem -Path $drive -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Illustrator' })) {
        $cand = Join-Path $d.FullName 'Support Files\Contents\Windows\Illustrator.exe'
        if (Test-Path -LiteralPath $cand) { $aiExe = $cand; break }
    }
    if ($aiExe) { break }
}
if ($aiExe) { L ('Illustrator.exe on desktop: ' + (San $aiExe)) }
else { L '   [WARN] Illustrator.exe not found yet (robocopy still running?)' }

# ------------------------------------------ 5. register the scheduled task
$worker = Join-Path $root 'desktop_worker.ps1'
if (-not (Test-Path -LiteralPath $worker)) { L ('   [FAIL] worker missing: ' + $worker); exit 2 }
try {
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File "' + $worker + '"')
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
    Register-ScheduledTask -TaskName 'fig1desk' -Action $action -Principal $principal -Settings $settings -Force | Out-Null
    L '   scheduled task registered: fig1desk (interactive, run on demand)'
} catch { L ('   [WARN] task register: ' + (San $_.Exception.Message)) }

# ------------------------------------------ 6. inputs present?
foreach ($f in @('test_fixture.svg', 'fig1_merged.svg', 'fig1_text_manifest.json')) {
    L ('   input ' + $f + ': ' + (Test-Path -LiteralPath (Join-Path $root $f)))
}
Write-Output '--- desktop install done ---'
exit 0
