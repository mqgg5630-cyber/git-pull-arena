# t65_relaunch_worker.ps1 - round 78 task: restage the fixed worker
# (PATH refresh + python deps preflight) and relaunch it detached.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }

Write-Output '--- task t65: relaunch fixed fig1 rebuild worker ---'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$stage = 'E:\fig1_rebuild'
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$workerSrc = Join-Path $repoRoot 'code\tasks\fig1_rebuild_worker.ps1'
if (-not (Test-Path -LiteralPath $workerSrc)) { Write-Output '   [FAIL] worker source missing'; exit 2 }
# sanity: the fixed worker must contain the deps preflight
if (-not (Select-String -LiteralPath $workerSrc -Pattern 'requirements.lock' -Quiet)) { Write-Output '   [FAIL] worker source is not the fixed version'; exit 2 }

# stop any stale worker + Illustrator from the failed attempt
$stale = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'fig1_rebuild_worker' })
foreach ($p in $stale) { try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
Write-Output ('   stale workers stopped: ' + $stale.Count)
try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }
Start-Sleep -Seconds 2

# clean previous markers/logs (keep job dirs if any)
foreach ($f in @('DONE.marker', 'FAILED.marker', 'rebuild.log', 'mkdoc.result', 'closed.result')) {
    Remove-Item -LiteralPath (Join-Path $stage $f) -Force -ErrorAction SilentlyContinue
}
Remove-Item -LiteralPath (Join-Path $stage 'lct_run*.log') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $stage 'lct_err*.log') -Force -ErrorAction SilentlyContinue

# verify inputs still staged (worker checks too, but fail fast here)
foreach ($f in @('fig1_merged.svg', 'fig1_text_manifest.json')) {
    if (-not (Test-Path -LiteralPath (Join-Path $stage $f))) { Write-Output ('   [FAIL] missing staged input: ' + $f); exit 2 }
}

Copy-Item -LiteralPath $workerSrc -Destination (Join-Path $stage 'fig1_rebuild_worker.ps1') -Force
Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $stage 'fig1_rebuild_worker.ps1') + '"')) -WindowStyle Hidden
Write-Output '   worker relaunched detached'
Start-Sleep -Seconds 40

$logPath = Join-Path $stage 'rebuild.log'
if (Test-Path -LiteralPath $logPath) {
    Write-Output '   --- rebuild.log tail ---'
    $tail = @(Get-Content -LiteralPath $logPath -Tail 14 -ErrorAction SilentlyContinue)
    foreach ($t in $tail) { $x = San ([string]$t); if ($x.Trim()) { Write-Output ('   | ' + $x) } }
} else { Write-Output '   [WARN] rebuild.log not created yet' }
$aiProc = @(Get-Process -Name Illustrator -ErrorAction SilentlyContinue).Count
Write-Output ('   Illustrator processes: ' + $aiProc)
Write-Output '--- task t65 ok ---'
exit 0
