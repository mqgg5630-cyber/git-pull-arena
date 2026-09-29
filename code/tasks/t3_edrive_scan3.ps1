# t3_edrive_scan3.ps1 - round 24 task: FINAL pass of the E: inventory.
# Round 22 measured 289.7 GB, round 23 another 54.0 GB; ~137 GB of top-level
# folders (plus the recycle bin) are still unknown. This pass:
#   - reads the r22/r23 receipts from results/status/ and skips every
#     top-level folder already measured (exact ASCII names; names containing
#     '?' in the receipts are Chinese names -> matched as one-char patterns)
#   - walks each REMAINING top-level folder with a 25s per-folder budget and a
#     570s global cap, so one huge tree can never starve the rest
# READ-ONLY: nothing is deleted.
#
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

function FmtB {
    param([double]$b)
    if ($b -ge 1GB) { return ('{0:N2} GB' -f ($b / 1GB)) }
    if ($b -ge 1MB) { return ('{0:N1} MB' -f ($b / 1MB)) }
    if ($b -ge 1KB) { return ('{0:N1} KB' -f ($b / 1KB)) }
    return ('{0:N0} B' -f $b)
}

Write-Output '--- task t3 (scan 3): E: final remaining folders (READ-ONLY) ---'

# ---------------------------------------------- skip list from receipts
$known = New-Object 'System.Collections.Generic.List[string]'
foreach ($rf in @(Get-ChildItem -Path '.\results\status' -Filter 'check_r2[23]_*.txt' -ErrorAction SilentlyContinue)) {
    try {
        foreach ($ln in (Get-Content -LiteralPath $rf.FullName -Encoding UTF8 -ErrorAction Stop)) {
            if ($ln -match 'files\s+E:\\(.+?)\s*$') {
                $nm = $Matches[1].Trim()
                if ($nm -and $nm -ne '(root files)') { $known.Add($nm) }
            }
        }
    } catch { }
}
Write-Output ('known top-level names parsed from r22/r23 receipts: ' + $known.Count)

$exact = New-Object 'System.Collections.Generic.HashSet[string]'
$patterns = New-Object 'System.Collections.Generic.List[string]'
foreach ($k in $known) {
    if ($k -match '^[\x20-\x7E]+$' -and $k -notmatch '\?') {
        $null = $exact.Add($k.ToLower())
    } elseif ($k -match '\?') {
        # receipt masked non-ASCII as '?' - each '?' stood for ONE character
        $rx = '^'
        foreach ($ch in $k.ToCharArray()) {
            if ($ch -eq '?') { $rx += '.' }
            else { $rx += [regex]::Escape([string]$ch) }
        }
        $rx += '$'
        $patterns.Add($rx)
    }
}
$prefixSkips = @('zTasker_2.3.12_')
$rootSkip = 'E:\Users\'

function Test-KnownTop {
    param([string]$name)
    if ($exact.Contains($name.ToLower())) { return $true }
    foreach ($p in $patterns) { if ($name -match $p) { return $true } }
    foreach ($p in $prefixSkips) { if ($name.Length -ge $p.Length -and $name.Substring(0, $p.Length).Equals($p, [System.StringComparison]::OrdinalIgnoreCase)) { return $true } }
    return $false
}

# --------------------------------------------------------- folder queue
$queue = @()
try {
    foreach ($d in [System.IO.Directory]::EnumerateDirectories('E:\')) {
        $leaf = $d.Substring(3).TrimEnd('\')
        if ($d.StartsWith($rootSkip, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        if (Test-KnownTop $leaf) { continue }
        $queue += $d
    }
} catch { }
Write-Output ('remaining top-level folders to measure: ' + $queue.Count)

$BIG = 100MB
$dirBudget = 25
$globalCap = 570
$gsw = [System.Diagnostics.Stopwatch]::StartNew()

$results = New-Object System.Collections.Generic.List[object]
$bigFiles = New-Object System.Collections.Generic.List[object]
$cacheNames = @('node_modules', '.gradle', '.m2', '.cache', '__pycache__', 'npm-cache', 'pip', 'pkgs', '.npm', '.nuget', 'temp', 'tmp', '.conda', 'uv-cache', '.pytest_cache', '.mypy_cache')

function Measure-Tree {
    param([string]$root, [int]$budgetSec)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $bytes = [double]0
    $files = [long]0
    $dirs = [long]0
    $partial = $false
    $localBig = New-Object System.Collections.Generic.List[object]
    $stack = New-Object System.Collections.Stack
    $stack.Push($root)
    while ($stack.Count -gt 0) {
        if ($sw.Elapsed.TotalSeconds -gt $budgetSec) { $partial = $true; break }
        $dir = [string]$stack.Pop()
        $dirs++
        try {
            foreach ($sd in [System.IO.Directory]::EnumerateDirectories($dir)) {
                $push = $true
                try {
                    $attr = [System.IO.File]::GetAttributes($sd)
                    if (($attr -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { $push = $false }
                } catch { }
                if ($push) { $stack.Push($sd) }
            }
        } catch { }
        try {
            foreach ($f in [System.IO.Directory]::EnumerateFiles($dir)) {
                $len = [double]0
                try { $len = [double]([System.IO.FileInfo]::new($f)).Length } catch { $len = [double]0 }
                $files++
                $bytes += $len
                if ($len -ge $BIG) {
                    $ext = ''
                    $dot = $f.LastIndexOf('.')
                    $bs = $f.LastIndexOf('\')
                    if ($dot -gt $bs -and $dot -ge 0) { $ext = $f.Substring($dot).ToLower() }
                    $localBig.Add([pscustomobject]@{ p = $f; b = $len; e = $ext })
                }
            }
        } catch { }
    }
    return @{ bytes = $bytes; files = $files; dirs = $dirs; partial = $partial; big = $localBig }
}

$notReached = New-Object System.Collections.Generic.List[string]
foreach ($top in $queue) {
    if ($gsw.Elapsed.TotalSeconds -gt $globalCap) { $notReached.Add($top); continue }
    $r = Measure-Tree -root $top -budgetSec $dirBudget
    $tag = ''
    if ($r.partial) { $tag = ' (PARTIAL - 25s budget hit)' }
    $results.Add([pscustomobject]@{ name = $top; bytes = [double]$r.bytes; files = [long]$r.files; tag = $tag })
    foreach ($b in @($r.big)) { $bigFiles.Add($b) }
}

$gSec = [int]$gsw.Elapsed.TotalSeconds
Write-Output ('pass 3: measured ' + $results.Count + ' folders in ' + $gSec + 's' + $(if ($notReached.Count -gt 0) { (' ; ' + $notReached.Count + ' NOT REACHED (cap)') } else { '' }))
if ($notReached.Count -gt 0) {
    foreach ($n in @($notReached | Select-Object -First 25)) { Write-Output ('   not reached: ' + (San $n)) }
}

Write-Output '--- pass-3 top-level folders on E: (by size, top 40) ---'
$rs = @($results | Sort-Object bytes -Descending | Select-Object -First 40)
if ($rs.Count -eq 0) { Write-Output '   (nothing left to measure)' }
foreach ($r in $rs) {
    Write-Output ('   ' + (FmtB ([double]$r.bytes)).PadLeft(12) + '  ' + ([long]$r.files).ToString().PadLeft(8) + ' files  ' + (San ([string]$r.name)) + $r.tag)
}

Write-Output '--- largest files in pass 3 (top 20) ---'
$bs2 = @($bigFiles | Sort-Object b -Descending | Select-Object -First 20)
if ($bs2.Count -eq 0) { Write-Output '   (none)' }
foreach ($bf in $bs2) {
    Write-Output ('   ' + (FmtB ([double]$bf.b)).PadLeft(12) + '  ' + (San ([string]$bf.p)))
}

Write-Output 'NOTE: read-only. Nothing was deleted.'
exit 0
