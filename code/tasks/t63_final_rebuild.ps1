# t63_final_rebuild.ps1 - round 76 task: stage inputs to E:\fig1_rebuild and
# launch the detached fig1 rebuild worker (background, survives this task).
# Fast task: verify staging + worker started, then return. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }

Write-Output '--- task t63: stage + launch detached fig1 rebuild worker ---'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$stage = 'E:\fig1_rebuild'
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$src = @{
    mergedSvg = Join-Path $repoRoot 'results\fig1_rebuild\fig1_merged.svg'
    rawSvg    = Join-Path $repoRoot 'results\fig1_rebuild\fig1_vector_raw.svg'
    manifest  = Join-Path $repoRoot 'results\reference\fig1_text_manifest.json'
    worker    = Join-Path $repoRoot 'code\tasks\fig1_rebuild_worker.ps1'
}
foreach ($k in @($src.Keys)) {
    $p = $src[$k]
    if (-not (Test-Path -LiteralPath $p)) { Write-Output ('   [FAIL] missing repo file: ' + $k + ' -> ' + $p); exit 2 }
}

Copy-Item -LiteralPath $src['mergedSvg'] -Destination (Join-Path $stage 'fig1_merged.svg') -Force
Copy-Item -LiteralPath $src['rawSvg']    -Destination (Join-Path $stage 'fig1_vector_raw.svg') -Force
Copy-Item -LiteralPath $src['manifest']  -Destination (Join-Path $stage 'fig1_text_manifest.json') -Force
Copy-Item -LiteralPath $src['worker']    -Destination (Join-Path $stage 'fig1_rebuild_worker.ps1') -Force
Write-Output '   staged: merged svg + raw svg + text manifest + worker'

# clean previous markers/logs
foreach ($f in @('DONE.marker', 'FAILED.marker', 'rebuild.log', 'mkdoc.result', 'closed.result')) {
    Remove-Item -LiteralPath (Join-Path $stage $f) -Force -ErrorAction SilentlyContinue
}
Remove-Item -LiteralPath (Join-Path $stage 'lct_run*.log') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $stage 'lct_err*.log') -Force -ErrorAction SilentlyContinue

# launch detached worker
$workerPath = Join-Path $stage 'fig1_rebuild_worker.ps1'
Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $workerPath + '"')) -WindowStyle Hidden
Write-Output '   worker launched detached'
Start-Sleep -Seconds 25

$alive = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'fig1_rebuild_worker' }).Count
Write-Output ('   worker process alive after 25s: ' + $alive)
$logPath = Join-Path $stage 'rebuild.log'
if (Test-Path -LiteralPath $logPath) {
    Write-Output '   --- rebuild.log head ---'
    $head = @(Get-Content -LiteralPath $logPath -TotalCount 15 -ErrorAction SilentlyContinue)
    foreach ($h in $head) { $t = San ([string]$h); if ($t.Trim()) { Write-Output ('   | ' + $t) } }
} else {
    Write-Output '   [WARN] rebuild.log not created yet'
}
$aiProc = @(Get-Process -Name Illustrator -ErrorAction SilentlyContinue).Count
Write-Output ('   Illustrator processes: ' + $aiProc)

if ($alive -ge 1) { Write-Output '--- task t63 ok (worker running) ---'; exit 0 }
Write-Output '--- task t63 WARN: worker not detected - check next round ---'
exit 0
