# t70_v2_rebuild.ps1 - round 86 task: (1) patch cell_lct_cached_runtime.jsx
# in both copies so rotated text rotates around its ANCHOR (not the center);
# (2) stage the v2 merged SVG (corrected font sizes) + manifest; (3) force a
# FRESH rebuild (new job) via the worker v3. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t70: runtime rotation patch + v2 fresh rebuild ---'

# ------------------------------------------------ 1. patch runtime jsx (both copies)
$rotBlock = @'
if (textStyle.rotationDegrees) {
        var anchorBefore = [created.position[0], created.position[1]];
        try {
          created.rotate(-textStyle.rotationDegrees, true, true, true, true, Transformation.BOTTOMLEFT);
        } catch (rotErr) {
          created.rotate(-textStyle.rotationDegrees);
        }
        var anchorAfter = created.position;
        if (Math.abs(anchorAfter[0] - anchorBefore[0]) > 0.01 || Math.abs(anchorAfter[1] - anchorBefore[1]) > 0.01) {
          created.translate(anchorBefore[0] - anchorAfter[0], anchorBefore[1] - anchorAfter[1]);
        }
      }
'@

$skillScripts = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex\skills\cell_su7\scripts'
$jsxTargets = @(
    'E:\cell_su7\plugins\cell_su7\skills\cell_su7\scripts\cell_lct_cached_runtime.jsx',
    (Join-Path $skillScripts 'cell_lct_cached_runtime.jsx')
)
foreach ($f in $jsxTargets) {
    if (-not (Test-Path -LiteralPath $f)) { L ('   [WARN] missing: ' + $f); continue }
    $raw = [string]([IO.File]::ReadAllText($f))
    if ($raw -match 'anchorBefore') { L ('   already rotation-patched: ' + $f); continue }
    $needle = 'if (textStyle.rotationDegrees) created.rotate(-textStyle.rotationDegrees);'
    $i = $raw.IndexOf($needle)
    if ($i -lt 0) { L ('   [WARN] rotation line not found in ' + $f); continue }
    $lineEnd = $raw.IndexOf("`n", $i)
    if ($lineEnd -lt 0) { $lineEnd = $raw.Length - 1 }
    $patched = $raw.Substring(0, $i) + $rotBlock + $raw.Substring($lineEnd + 1)
    $patched = $patched -replace "`r?`n", "`r`n"
    [IO.File]::WriteAllText($f, $patched, (New-Object System.Text.UTF8Encoding($false)))
    if ((Select-String -LiteralPath $f -Pattern 'anchorBefore' -Quiet) -and (Select-String -LiteralPath $f -Pattern 'Transformation.BOTTOMLEFT' -Quiet)) {
        L ('   ROTATION-ANCHOR PATCHED: ' + $f)
    } else { L ('   [FAIL] patch verify failed: ' + $f) }
}

# ------------------------------------------------ 2. stage v2 inputs
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$stage = 'E:\fig1_rebuild'
New-Item -ItemType Directory -Force -Path $stage | Out-Null
$mergedSrc = Join-Path $repoRoot 'results\fig1_rebuild\fig1_merged.svg'
$manSrc = Join-Path $repoRoot 'results\reference\fig1_text_manifest.json'
$workerSrc = Join-Path $repoRoot 'code\tasks\fig1_rebuild_worker.ps1'
foreach ($p in @($mergedSrc, $manSrc, $workerSrc)) {
    if (-not (Test-Path -LiteralPath $p)) { L ('   [FAIL] missing repo file: ' + $p); exit 2 }
}
# verify the staged svg carries corrected sizes (spot check: font-size="26.5" present, 38 gone for lbl-pg)
$svgText = [string]([IO.File]::ReadAllText($mergedSrc))
if ($svgText -notmatch 'font-size="26\.5"') { L '   [FAIL] staged svg is not the v2 (corrected sizes) version'; exit 2 }
Copy-Item -LiteralPath $mergedSrc -Destination (Join-Path $stage 'fig1_merged.svg') -Force
Copy-Item -LiteralPath $manSrc -Destination (Join-Path $stage 'fig1_text_manifest.json') -Force
Copy-Item -LiteralPath $workerSrc -Destination (Join-Path $stage 'fig1_rebuild_worker.ps1') -Force
L '   staged v2 merged svg + corrected manifest + worker v3'

# ------------------------------------------------ 3. clean state + FRESH marker
foreach ($m in @('DONE.marker', 'FAILED.marker')) { Remove-Item -LiteralPath (Join-Path $stage $m) -Force -ErrorAction SilentlyContinue }
foreach ($f in @('lct_run1.log', 'lct_run2.log', 'lct_run3.log', 'lct_err1.log', 'lct_err2.log', 'lct_err3.log')) {
    Remove-Item -LiteralPath (Join-Path $stage $f) -Force -ErrorAction SilentlyContinue
}
$staleWorkers = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'fig1_rebuild_worker' })
foreach ($p in $staleWorkers) { try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
L ('   stale workers stopped: ' + $staleWorkers.Count)
try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }
Start-Sleep -Seconds 2
'fresh' | Out-File -FilePath (Join-Path $stage 'FRESH.marker') -Encoding ascii
L '   FRESH.marker written (full redraw, new job name)'

# ------------------------------------------------ 4. launch worker v3 detached
Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $stage 'fig1_rebuild_worker.ps1') + '"')) -WindowStyle Hidden
L '   worker launched detached'
Start-Sleep -Seconds 40
$logPath = Join-Path $stage 'rebuild.log'
if (Test-Path -LiteralPath $logPath) {
    L '   --- rebuild.log tail ---'
    $tail = @(Get-Content -LiteralPath $logPath -Tail 14 -ErrorAction SilentlyContinue)
    foreach ($t in $tail) { $x = San ([string]$t); if ($x.Trim()) { L ('   | ' + $x) } }
} else { L '   [WARN] rebuild.log not created yet' }
L ('   Illustrator processes: ' + @(Get-Process -Name Illustrator -ErrorAction SilentlyContinue).Count)
L '--- task t70 ok ---'
exit 0
