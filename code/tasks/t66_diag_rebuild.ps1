# t66_diag_rebuild.ps1 - round 80 task: dump full diagnostics of the fig1
# rebuild failure (worker attempt logs + stderr + state + keep resumable
# artifacts intact). Read-only except nothing modified. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }

function Dump-File([string]$path, [int]$n, [string]$label) {
    if (Test-Path -LiteralPath $path) {
        Write-Output ('   --- ' + $label + ' (tail ' + $n + ') ---')
        $tail = @(Get-Content -LiteralPath $path -Tail $n -ErrorAction SilentlyContinue)
        foreach ($t in $tail) { $x = San ([string]$t); if ($x.Trim()) { Write-Output ('   | ' + $x) } }
    } else { Write-Output ('   --- ' + $label + ': MISSING ---') }
}

Write-Output '--- task t66: fig1 rebuild diagnostics ---'

$root = 'E:\fig1_rebuild'

# worker status
foreach ($m in @('DONE.marker', 'FAILED.marker')) {
    $p = Join-Path $root $m
    if (Test-Path -LiteralPath $p) { Write-Output ('   ' + $m + ': ' + (San ([IO.File]::ReadAllText($p)))) }
}
$workers = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'fig1_rebuild_worker' })
Write-Output ('   workers alive: ' + $workers.Count)
Write-Output ('   Illustrator processes: ' + @(Get-Process -Name Illustrator -ErrorAction SilentlyContinue).Count)

Dump-File (Join-Path $root 'rebuild.log') 30 'rebuild.log'

# per-attempt logs (stdout + stderr interleaved view)
for ($i = 1; $i -le 3; $i++) {
    Dump-File (Join-Path $root ('lct_run' + $i + '.log')) 25 ('lct_run' + $i + '.log stdout')
    Dump-File (Join-Path $root ('lct_err' + $i + '.log')) 25 ('lct_err' + $i + '.log stderr')
}

# job state
$jobDirs = @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^shibielujing\d+$' })
if ($jobDirs.Count -gt 0) {
    $jobRoot = $jobDirs[-1].FullName
    Write-Output ('   job dir: ' + $jobDirs[-1].Name)
    $cache = Join-Path $jobRoot '.cell-lct-internal\live-cache\geometry-cache.json'
    $state = Join-Path $jobRoot '.cell-lct-internal\live-cache\playback.json'
    if (Test-Path -LiteralPath $state) {
        try {
            $st = Get-Content -LiteralPath $state -Raw -Encoding UTF8 | ConvertFrom-Json
            $comp = @($st.batches | Where-Object { $_.completed }).Count
            Write-Output ('   batches: ' + $comp + '/' + @($st.batches).Count + ' completed')
            $bad = @($st.batches | Where-Object { -not $_.completed })
            foreach ($b in $bad) { Write-Output ('   incomplete batch: ' + $b.index + ' | last_error: ' + (San ([string]$b.last_error))) }
        } catch { Write-Output ('   [WARN] state parse: ' + (San $_.Exception.Message)) }
    }
    foreach ($f in @(($jobDirs[-1].Name + '.ai'), ($jobDirs[-1].Name + '.png'))) {
        $p = Join-Path $jobRoot $f
        if (Test-Path -LiteralPath $p) {
            $it = Get-Item -LiteralPath $p
            Write-Output ('   artifact: ' + $f + ' ' + [int]($it.Length / 1024) + ' KB mtime ' + $it.LastWriteTime.ToString('HH:mm:ss'))
        } else { Write-Output ('   artifact MISSING: ' + $f) }
    }
}
Write-Output '--- task t66 ok (diagnostics only) ---'
exit 0
