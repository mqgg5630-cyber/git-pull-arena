# t73_v5_relaunch.ps1 - round 95 task: stage worker v5 (mkdoc dialog
# self-heal: kill + clean relaunch + dismiss #32770 modals + retry), kill
# any stuck Illustrator, rewrite FRESH.marker, relaunch detached.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t73: worker v5 (mkdoc self-heal) relaunch ---'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$stage = 'E:\fig1_rebuild'
$workerSrc = Join-Path $repoRoot 'code\tasks\fig1_rebuild_worker.ps1'
if (-not (Test-Path -LiteralPath $workerSrc)) { L '   [FAIL] worker source missing'; exit 2 }
if (-not (Select-String -LiteralPath $workerSrc -Pattern 'CsWinEnum2' -Quiet) -or -not (Select-String -LiteralPath $workerSrc -Pattern 'Invoke-Mkdoc' -Quiet)) {
    L '   [FAIL] worker source is not v5'; exit 2
}

$staleWorkers = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'fig1_rebuild_worker' })
foreach ($p in $staleWorkers) { try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
L ('   stale workers stopped: ' + $staleWorkers.Count)

# kill stuck Illustrator (may be showing a modal recovery dialog right now)
try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue; L '   Illustrator killed for a clean start' } catch { }
Start-Sleep -Seconds 3

foreach ($m in @('DONE.marker', 'FAILED.marker')) { Remove-Item -LiteralPath (Join-Path $stage $m) -Force -ErrorAction SilentlyContinue }
foreach ($f in @('lct_run1.log', 'lct_run2.log', 'lct_run3.log', 'lct_err1.log', 'lct_err2.log', 'lct_err3.log')) {
    Remove-Item -LiteralPath (Join-Path $stage $f) -Force -ErrorAction SilentlyContinue
}
Copy-Item -LiteralPath $workerSrc -Destination (Join-Path $stage 'fig1_rebuild_worker.ps1') -Force
'fresh' | Out-File -FilePath (Join-Path $stage 'FRESH.marker') -Encoding ascii
L '   worker v5 staged + FRESH.marker'

Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $stage 'fig1_rebuild_worker.ps1') + '"')) -WindowStyle Hidden
L '   worker v5 launched detached'
Start-Sleep -Seconds 50

$logPath = Join-Path $stage 'rebuild.log'
if (Test-Path -LiteralPath $logPath) {
    L '   --- rebuild.log tail ---'
    $tail = @(Get-Content -LiteralPath $logPath -Tail 18 -ErrorAction SilentlyContinue)
    foreach ($t in $tail) { $x = San ([string]$t); if ($x.Trim()) { L ('   | ' + $x) } }
}
L ('   Illustrator processes: ' + @(Get-Process -Name Illustrator -ErrorAction SilentlyContinue).Count)
L '--- task t73 ok ---'
exit 0
