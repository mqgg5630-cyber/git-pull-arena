# t77_demo_celllct.ps1 - round 105 task: FULL DEMONSTRATION via the
# cell-lct skill: set SKILLPREF.marker=cell-lct, FRESH.marker, relaunch the
# detached worker -> complete fig1 rebuild (vector draw + live text + .ai +
# .png) as a new shibielujingN job. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

$pref = 'cell-lct'
$taskName = 't77'

Write-Output ('--- task ' + $taskName + ': full demo via ' + $pref + ' ---')

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$stage = 'E:\fig1_rebuild'
$workerSrc = Join-Path $repoRoot 'code\tasks\fig1_rebuild_worker.ps1'
if (-not (Test-Path -LiteralPath $workerSrc)) { L '   [FAIL] worker source missing'; exit 2 }
if (-not (Select-String -LiteralPath $workerSrc -Pattern 'SKILLPREF.marker' -Quiet)) { L '   [FAIL] worker lacks SKILLPREF logic'; exit 2 }

# inputs must be staged
foreach ($f in @('fig1_merged.svg', 'fig1_text_manifest.json')) {
    if (-not (Test-Path -LiteralPath (Join-Path $stage $f))) { L ('   [FAIL] missing staged input: ' + $f); exit 2 }
}

# stop stale worker + Illustrator
$staleWorkers = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'fig1_rebuild_worker' })
foreach ($p in $staleWorkers) { try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
L ('   stale workers stopped: ' + $staleWorkers.Count)
try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }
Start-Sleep -Seconds 3

# markers
$pref | Out-File -FilePath (Join-Path $stage 'SKILLPREF.marker') -Encoding ascii
'fresh' | Out-File -FilePath (Join-Path $stage 'FRESH.marker') -Encoding ascii
foreach ($m in @('DONE.marker', 'FAILED.marker')) { Remove-Item -LiteralPath (Join-Path $stage $m) -Force -ErrorAction SilentlyContinue }
foreach ($f in @('lct_run1.log', 'lct_run2.log', 'lct_run3.log', 'lct_err1.log', 'lct_err2.log', 'lct_err3.log')) {
    Remove-Item -LiteralPath (Join-Path $stage $f) -Force -ErrorAction SilentlyContinue
}
Copy-Item -LiteralPath $workerSrc -Destination (Join-Path $stage 'fig1_rebuild_worker.ps1') -Force
L ('   markers set: SKILLPREF=' + $pref + ' + FRESH')

Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $stage 'fig1_rebuild_worker.ps1') + '"')) -WindowStyle Hidden
L '   worker launched detached'
Start-Sleep -Seconds 50

$logPath = Join-Path $stage 'rebuild.log'
if (Test-Path -LiteralPath $logPath) {
    L '   --- rebuild.log tail ---'
    foreach ($t in @(Get-Content -LiteralPath $logPath -Tail 16 -ErrorAction SilentlyContinue)) { $x = San ([string]$t); if ($x.Trim()) { L ('   | ' + $x) } }
}
L ('   Illustrator processes: ' + @(Get-Process -Name Illustrator -ErrorAction SilentlyContinue).Count)
L ('--- task ' + $taskName + ' ok ---')
exit 0
