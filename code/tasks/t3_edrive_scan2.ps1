# t3_edrive_scan2.ps1 - round 23 task: FINISH the E: cleanup scan. Round 22
# (t3_edrive_scan.ps1) hit its 600s cap after 289.7 of 481.1 GB; this task
# scans ONLY the top-level folders that were NOT measured then (the known ones
# are skipped by name), plus the recycle bin. READ-ONLY: nothing is deleted.
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

Write-Output '--- task t3 (scan 2): E: remaining top-level folders (READ-ONLY) ---'

$drive = $null
try { $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='E:'" -ErrorAction Stop } catch { }
if (-not $drive) { Write-Output 'E: not found'; exit 0 }
$tot = [double]$drive.Size
$free = [double]$drive.FreeSpace
Write-Output ('drive E: used ' + ('{0:N1}' -f (($tot - $free) / 1GB)) + ' GB, free ' + ('{0:N1}' -f ($free / 1GB)) + ' GB (round 22 measured 289.7 GB of used space; this pass covers the rest)')

# top-level folders already measured in round 22 (skip them)
$skipExact = @('WSL', 'Tencent Games', 'Users', 'spider', 'xwechat_files', 'Tencent Files', 'xunlei', 'VSCodeData', 'WPSOffice', 'Weka-3-8-7', 'ST', 'Steam', 'Tencent', 'VM', 'vscode-cache', 'v2rayN-windows-64-desktop', 'ZTools-3.1.0-win-x64', 'ToDesk', 'Zotero', 'vit-pytorch-main', 'VMD2', 'Wise Care 365', 'UniGetUI.x64', 'tailscale', 'steam co', 'Tabby', 'v2rayN-windows-64-SelfContained', 'vscode', 'WpSystem', 'trae-chajian', 'Thunder')
$skipPrefix = @('zTasker_2.3.12_')
$skipSuffix = @('OfficeBox')

function Test-SkipTop {
    param([string]$name)
    foreach ($s in $skipExact) { if ($name.Equals($s, [System.StringComparison]::OrdinalIgnoreCase)) { return $true } }
    foreach ($p in $skipPrefix) { if ($name.Length -ge $p.Length -and $name.Substring(0, $p.Length).Equals($p, [System.StringComparison]::OrdinalIgnoreCase)) { return $true } }
    foreach ($q in $skipSuffix) { if ($name.Length -ge $q.Length -and $name.Substring($name.Length - $q.Length).Equals($q, [System.StringComparison]::OrdinalIgnoreCase)) { return $true } }
    return $false
}

$tops = @()
$skipped = @()
try {
    foreach ($d in [System.IO.Directory]::EnumerateDirectories('E:\')) {
        $leaf = $d.Substring(3).TrimEnd('\')
        if (Test-SkipTop $leaf) { $skipped += $leaf }
        else { $tops += $d }
    }
} catch { }
Write-Output ('top-level folders to scan now: ' + $tops.Count + ' ; skipped (already measured): ' + $skipped.Count)
foreach ($s in @($skipped | Select-Object -First 40)) { Write-Output ('   skip: ' + (San $s)) }

$cacheSet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($n in @('node_modules', '.gradle', '.m2', '.cache', '__pycache__', 'npm-cache', 'pip', 'pkgs', '.npm', '.nuget', 'temp', 'tmp', '.conda', 'conda-bld', 'yarn-cache', '.pytest_cache', '.mypy_cache')) { $null = $cacheSet.Add($n.ToLower()) }
$watchPrefixes = @('E:\$RECYCLE.BIN', 'E:\0github\git-sync\git-pull-arena')

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$capSec = 300
$BIG = 100MB

$topBytes = @{}
$topCount = @{}
$bigFiles = New-Object System.Collections.Generic.List[object]
$specials = New-Object System.Collections.Generic.List[object]
$accDone = New-Object System.Collections.Generic.List[object]
$accStack = New-Object System.Collections.Stack
$dirStack = New-Object System.Collections.Stack
$doneSet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($t in $tops) {
    $leaf = $t.Substring(3).TrimEnd('\')
    $null = $doneSet.Add($leaf.ToLower())
    $dirStack.Push($t)
}
$totalFiles = [long]0
$totalDirs = [long]0
$totalBytes = [double]0
$partial = $false

while ($dirStack.Count -gt 0) {
    if ($sw.Elapsed.TotalSeconds -gt $capSec) { $partial = $true; break }
    $item = $dirStack.Pop()
    if ($item -isnot [string]) {
        if ($null -ne $item.acc) {
            $null = $accStack.Pop()
            if ([double]$item.acc.bytes -ge 10MB) { $accDone.Add($item.acc) }
        }
        continue
    }
    $dir = [string]$item
    $totalDirs++
    $leaf = ''
    $li = $dir.LastIndexOf('\')
    if ($li -ge 0 -and ($li + 1) -lt $dir.Length) { $leaf = $dir.Substring($li + 1) }

    # only descend into non-skipped top-level trees (all pushed here are wanted)
    $acc = $null
    $isWatch = $false
    if ($leaf.Length -gt 0 -and $cacheSet.Contains($leaf.ToLower())) { $isWatch = $true }
    if (-not $isWatch) {
        foreach ($wp in $watchPrefixes) {
            if ($dir.Length -ge $wp.Length -and $dir.Substring(0, $wp.Length).Equals($wp, [System.StringComparison]::OrdinalIgnoreCase)) { $isWatch = $true; break }
        }
    }
    if ($isWatch) {
        $acc = @{ path = $dir; bytes = [double]0; files = [long]0 }
        $accStack.Push($acc)
    }
    $dirStack.Push([pscustomobject]@{ acc = $acc })

    try {
        foreach ($sd in [System.IO.Directory]::EnumerateDirectories($dir)) {
            $push = $true
            try {
                $attr = [System.IO.File]::GetAttributes($sd)
                if (($attr -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { $push = $false }
            } catch { }
            if ($push) { $dirStack.Push($sd) }
        }
    } catch { }
    try {
        foreach ($f in [System.IO.Directory]::EnumerateFiles($dir)) {
            $len = [double]0
            try { $len = [double]([System.IO.FileInfo]::new($f)).Length } catch { $len = [double]0 }
            $totalFiles++
            $totalBytes += $len

            $seg = '(top)'
            if ($f.Length -gt 3) {
                $i = $f.IndexOf('\', 3)
                if ($i -gt 0) { $seg = $f.Substring(3, $i - 3) }
            }
            if ($topBytes.ContainsKey($seg)) { $topBytes[$seg] = [double]$topBytes[$seg] + $len }
            else { $topBytes[$seg] = $len }
            if ($topCount.ContainsKey($seg)) { $topCount[$seg] = [long]$topCount[$seg] + 1 }
            else { $topCount[$seg] = [long]1 }

            if ($accStack.Count -gt 0) {
                foreach ($a in $accStack) {
                    $a.bytes = [double]$a.bytes + $len
                    $a.files = [long]$a.files + 1
                }
            }

            $ext = ''
            $dot = $f.LastIndexOf('.')
            $bs = $f.LastIndexOf('\')
            if ($dot -gt $bs -and $dot -ge 0) { $ext = $f.Substring($dot).ToLower() }
            if ($len -ge $BIG) {
                $bigFiles.Add([pscustomobject]@{ p = $f; b = $len; e = $ext })
            } elseif ($ext -eq '.vhdx' -or $ext -eq '.avhdx' -or $ext -eq '.vhd' -or $ext -eq '.dmp' -or $ext -eq '.mdmp') {
                $specials.Add([pscustomobject]@{ p = $f; b = $len; e = $ext })
            }
        }
    } catch { }
}

$walkSec = [int]$sw.Elapsed.TotalSeconds
$statusLine = 'complete'
if ($partial) { $statusLine = 'TIME CAP HIT - PARTIAL RESULTS' }
Write-Output ('walk 2: ' + $totalFiles + ' files, ' + $totalDirs + ' dirs, ' + (FmtB $totalBytes) + ' scanned in ' + $walkSec + 's - ' + $statusLine)

Write-Output '--- remaining top-level folders on E: (by size) ---'
$tbSorted = @($topBytes.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 40)
if ($tbSorted.Count -eq 0) { Write-Output '   (nothing to scan - all measured in round 22)' }
foreach ($e in $tbSorted) {
    $cnt = [long]0
    if ($topCount.ContainsKey($e.Key)) { $cnt = [long]$topCount[$e.Key] }
    Write-Output ('   ' + (FmtB ([double]$e.Value)).PadLeft(12) + '  ' + ($cnt).ToString().PadLeft(8) + ' files  E:\' + (San ([string]$e.Key)))
}

Write-Output '--- cache / reclaim candidates in this pass (top 15) ---'
$accSorted = @($accDone | Sort-Object { [double]$_.bytes } -Descending | Select-Object -First 15)
if ($accSorted.Count -eq 0) { Write-Output '   (none found)' }
foreach ($a in $accSorted) {
    Write-Output ('   ' + (FmtB ([double]$a.bytes)).PadLeft(12) + '  ' + ([long]$a.files).ToString().PadLeft(8) + ' files  ' + (San ([string]$a.path)))
}

Write-Output '--- largest files in this pass (top 15) ---'
$bfSorted = @($bigFiles | Sort-Object b -Descending | Select-Object -First 15)
if ($bfSorted.Count -eq 0) { Write-Output '   (none)' }
foreach ($bf in $bfSorted) {
    Write-Output ('   ' + (FmtB ([double]$bf.b)).PadLeft(12) + '  ' + (San ([string]$bf.p)))
}

Write-Output '--- vm disks / crash dumps in this pass (top 10) ---'
$spSorted = @($specials | Sort-Object b -Descending | Select-Object -First 10)
if ($spSorted.Count -eq 0) { Write-Output '   (none)' }
foreach ($sp in $spSorted) {
    Write-Output ('   ' + (FmtB ([double]$sp.b)).PadLeft(12) + '  ' + (San ([string]$sp.p)))
}

Write-Output 'NOTE: read-only again. Nothing was deleted. Cleanup happens only after user approval.'
exit 0
