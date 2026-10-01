# t92_desk_collect.ps1 - round 127 task: collect ALL desktop results via
# F$ into the repo: fixture tests (test-cell-lct / test-cell_su7), fig1
# demos (jobs\shibielujing1 = cell_su7, jobs\shibielujing2 = cell-lct),
# plus rebuild.log and probe.result. Report sizes. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t92: collect desktop results into repo ---'

$desktop = '100.84.137.117'
$fshare = '\\' + $desktop + '\F$'
$deskRoot = $fshare + '\fig1_rebuild'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$dest = Join-Path $repoRoot 'results\fig1_rebuild\desktop'
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; foreach ($ln in ($netOut -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('   net| ' + $x) } }; exit 2 }
L '   F$ connected'

try {
    $copied = 0
    # fixture tests
    foreach ($t in @('test-cell-lct', 'test-cell_su7')) {
        $srcDir = Join-Path $deskRoot $t
        $dstDir = Join-Path $dest $t
        New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
        foreach ($n in @(('test_' + ($t -replace 'test-', '') + '.ai'), ('test_' + ($t -replace 'test-', '') + '.png'))) {
            $p = Join-Path $srcDir $n
            if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination (Join-Path $dstDir $n) -Force; $copied++; L ('   copied: ' + $t + '\' + $n + ' (' + [int]((Get-Item -LiteralPath $p).Length / 1024) + ' KB)') }
            else { L ('   [WARN] missing: ' + $t + '\' + $n) }
        }
    }
    # fig1 demo jobs
    $jobsDir = Join-Path $deskRoot 'jobs'
    foreach ($jd in @(Get-ChildItem -LiteralPath $jobsDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^shibielujing\d+$' })) {
        $dstDir = Join-Path $dest $jd.Name
        New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
        foreach ($n in @(($jd.Name + '.ai'), ($jd.Name + '.png'), ($jd.Name + '.svg'), 'text-manifest.json')) {
            $p = Join-Path $jd.FullName $n
            if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination (Join-Path $dstDir $n) -Force; $copied++; L ('   copied: jobs\' + $jd.Name + '\' + $n + ' (' + [int]((Get-Item -LiteralPath $p).Length / 1024) + ' KB)') }
            else { L ('   [WARN] missing: jobs\' + $jd.Name + '\' + $n) }
        }
    }
    # logs + probes
    foreach ($n in @('rebuild.log', 'probe.result', 'depcheck.py')) {
        $p = Join-Path $deskRoot $n
        if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination (Join-Path $dest $n) -Force; $copied++ }
    }
    L ('   total files copied: ' + $copied)
    # job order note: shibielujing1 = cell_su7 (r124), shibielujing2 = cell-lct (r125)
    L '   note: jobs\shibielujing1 = cell_su7 demo, jobs\shibielujing2 = cell-lct demo'
}
finally {
    & net use $fshare /delete 2>&1 | Out-Null
    L '   F$ released'
}
L '--- task t92 done ---'
exit 0
