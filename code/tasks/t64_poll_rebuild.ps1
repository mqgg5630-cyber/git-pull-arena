# t64_poll_rebuild.ps1 - round 77 task: poll the detached fig1 rebuild worker.
# If DONE -> copy artifacts into the repo (results/fig1_rebuild/out/).
# If FAILED -> dump log tail, exit 2. If still running -> report progress.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }

Write-Output '--- task t64: poll fig1 rebuild worker ---'

$root = 'E:\fig1_rebuild'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

$doneMarker = Join-Path $root 'DONE.marker'
$failMarker = Join-Path $root 'FAILED.marker'
$logPath = Join-Path $root 'rebuild.log'

function Show-LogTail([int]$n) {
    if (Test-Path -LiteralPath $logPath) {
        Write-Output ('   --- rebuild.log tail ' + $n + ' ---')
        $tail = @(Get-Content -LiteralPath $logPath -Tail $n -ErrorAction SilentlyContinue)
        foreach ($t in $tail) { $x = San ([string]$t); if ($x.Trim()) { Write-Output ('   | ' + $x) } }
    } else { Write-Output '   [WARN] no rebuild.log' }
}

if (Test-Path -LiteralPath $doneMarker) {
    Write-Output ('   DONE: ' + (San ([IO.File]::ReadAllText($doneMarker))))
    Show-LogTail 12
    # locate job dir
    $jobDirs = @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^shibielujing\d+$' } | Sort-Object Name)
    if ($jobDirs.Count -lt 1) { Write-Output '   [FAIL] no job dir found'; exit 2 }
    $job = $jobDirs[-1]
    $jobRoot = $job.FullName
    Write-Output ('   job dir: ' + $job.Name)
    $outDir = Join-Path $repoRoot 'results\fig1_rebuild\out'
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $copied = @()
    foreach ($n in @($job.Name + '.ai', $job.Name + '.png', $job.Name + '.svg', 'text-manifest.json')) {
        $p = Join-Path $jobRoot $n
        if (Test-Path -LiteralPath $p) {
            Copy-Item -LiteralPath $p -Destination (Join-Path $outDir $n) -Force
            $copied += ($n + ' (' + [int]((Get-Item -LiteralPath $p).Length / 1024) + ' KB)')
        } else { Write-Output ('   [WARN] missing artifact: ' + $n) }
    }
    if (Test-Path -LiteralPath $logPath) { Copy-Item -LiteralPath $logPath -Destination (Join-Path $outDir 'rebuild.log') -Force }
    Write-Output ('   copied to repo: ' + ($copied -join ', '))
    # live text sanity via bridge-independent check: count text frames in the .ai? (not possible without AI) - rely on sandbox OCR of the exported png.
    $png = Join-Path $outDir ($job.Name + '.png')
    if (Test-Path -LiteralPath $png) {
        Add-Type -AssemblyName System.Drawing
        $img = [System.Drawing.Image]::FromFile($png)
        Write-Output ('   exported png: ' + $img.Width + 'x' + $img.Height)
        $img.Dispose()
    }
    Write-Output '--- task t64 ok (rebuild complete, artifacts copied) ---'
    exit 0
}

if (Test-Path -LiteralPath $failMarker) {
    Write-Output ('   FAILED: ' + (San ([IO.File]::ReadAllText($failMarker))))
    Show-LogTail 30
    foreach ($f in @('lct_run1.log', 'lct_run2.log', 'lct_run3.log')) {
        $p = Join-Path $root $f
        if (Test-Path -LiteralPath $p) {
            Write-Output ('   --- ' + $f + ' tail ---')
            $tail = @(Get-Content -LiteralPath $p -Tail 10 -ErrorAction SilentlyContinue)
            foreach ($t in $tail) { $x = San ([string]$t); if ($x.Trim()) { Write-Output ('   | ' + $x) } }
        }
    }
    Write-Output '--- task t64 FAIL ---'
    exit 2
}

# still running: report progress
Write-Output '   still running...'
Show-LogTail 14
$aiProc = @(Get-Process -Name Illustrator -ErrorAction SilentlyContinue).Count
Write-Output ('   Illustrator processes: ' + $aiProc)
$jobDirs = @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^shibielujing\d+$' })
if ($jobDirs.Count -gt 0) {
    $jobRoot = $jobDirs[-1].FullName
    $statePath = Join-Path $jobRoot '.cell-lct-internal\live-cache\playback.json'
    if (Test-Path -LiteralPath $statePath) {
        try {
            $st = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
            $comp = @($st.batches | Where-Object { $_.completed }).Count
            Write-Output ('   progress: batches ' + $comp + '/' + @($st.batches).Count + ' completed')
        } catch { Write-Output ('   [WARN] state parse: ' + (San $_.Exception.Message)) }
    } else { Write-Output '   playback.json not yet created' }
    $aiFile = Get-ChildItem -LiteralPath $jobRoot -Filter '*.ai' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($aiFile) { Write-Output ('   checkpoint .ai present: ' + [int]($aiFile.Length / 1024) + ' KB, mtime ' + $aiFile.LastWriteTime.ToString('HH:mm:ss')) }
}
Write-Output '--- task t64 ok (still running, poll again next round) ---'
exit 0
