# t3_edrive_scan.ps1 - round 22 task 3: READ-ONLY scan of E: for caches and
# content that are safe to clean. NOTHING IS DELETED OR MODIFIED.
#
# One depth-first walk collects: per top-level folder sizes, largest files,
# big installers/archives, vm disks / crash dumps, and well-known cache
# folders (node_modules, conda pkgs, pip, npm, gradle, temp, ...). The walk is
# time-capped at 600s so the round can never hang (watcher hard cap 30 min).
# Reparse points (junctions/symlinks) are skipped so nothing is double counted.
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

Write-Output '--- task t3: E: cleanup analysis (READ-ONLY, nothing is deleted) ---'

$drive = $null
try { $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='E:'" -ErrorAction Stop } catch { }
if (-not $drive) {
    Write-Output 'E: not found - nothing to scan'
    exit 0
}
$tot = [double]$drive.Size
$free = [double]$drive.FreeSpace
Write-Output ('drive E: total ' + ('{0:N1}' -f ($tot / 1GB)) + ' GB, used ' + ('{0:N1}' -f (($tot - $free) / 1GB)) + ' GB, free ' + ('{0:N1}' -f ($free / 1GB)) + ' GB, FS=' + (San ([string]$drive.FileSystem)))

# cache folder leaf names tracked during the walk (lower case)
$cacheSet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($n in @('node_modules', '.gradle', '.m2', '.cache', '__pycache__', 'npm-cache', 'pip', 'pkgs', '.npm', '.nuget', 'temp', 'tmp', '.conda', 'conda-bld', 'yarn-cache', '.pytest_cache', '.mypy_cache', 'v8-compile-cache')) { $null = $cacheSet.Add($n.ToLower()) }
# whole subtrees that matter beyond leaf names
$watchPrefixes = @('E:\$RECYCLE.BIN', 'E:\0github\git-sync\git-pull-arena')

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$capSec = 600
$BIG = 100MB

$topBytes = @{}
$topCount = @{}
$bigFiles = New-Object System.Collections.Generic.List[object]
$specials = New-Object System.Collections.Generic.List[object]
$accDone = New-Object System.Collections.Generic.List[object]
$accStack = New-Object System.Collections.Stack
$dirStack = New-Object System.Collections.Stack
$dirStack.Push('E:\')
$totalFiles = [long]0
$totalDirs = [long]0
$totalBytes = [double]0
$partial = $false

while ($dirStack.Count -gt 0) {
    if ($sw.Elapsed.TotalSeconds -gt $capSec) { $partial = $true; break }
    $item = $dirStack.Pop()
    if ($item -isnot [string]) {
        # marker: leaving this directory - close its accumulator if it had one
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

            $seg = '(root files)'
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
if ($partial) { $statusLine = 'TIME CAP HIT - PARTIAL RESULTS (remaining folders not scanned)' }
Write-Output ('walk: ' + $totalFiles + ' files, ' + $totalDirs + ' dirs, ' + (FmtB $totalBytes) + ' scanned in ' + $walkSec + 's - ' + $statusLine)

Write-Output '--- top-level folders on E: (by size, top 40) ---'
$tbSorted = @($topBytes.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 40)
foreach ($e in $tbSorted) {
    $cnt = [long]0
    if ($topCount.ContainsKey($e.Key)) { $cnt = [long]$topCount[$e.Key] }
    Write-Output ('   ' + (FmtB ([double]$e.Value)).PadLeft(12) + '  ' + ($cnt).ToString().PadLeft(8) + ' files  E:\' + (San ([string]$e.Key)))
}

function Tag-For {
    param([string]$p)
    $l = $p.ToLower()
    if ($l -like '*\pkgs') { return 'conda package cache - clean with: conda clean --all (keeps every env)' }
    if ($l -like '*\node_modules') { return 'node deps - delete only if you can re-run the package install for that project' }
    if ($l -like '*\$recycle.bin*') { return 'recycle bin - safe: Clear-RecycleBin -DriveLetter E' }
    if ($l -like '*\__pycache__' -or $l -like '*\.pytest_cache' -or $l -like '*\.mypy_cache') { return 'python caches - safe to delete' }
    if ($l -like '*\pip') { return 'pip cache - safe: pip cache purge' }
    if ($l -like '*\npm-cache' -or $l -like '*\.npm') { return 'npm cache - safe: npm cache clean --force' }
    if ($l -like '*\.gradle' -or $l -like '*\.m2') { return 'build cache - re-downloaded on demand' }
    if ($l -like '*\.nuget') { return 'nuget package cache - safe unless you build .NET offline' }
    if ($l -match '\\temp$' -or $l -match '\\tmp$') { return 'temp folder - usually safe, verify no app is using it' }
    if ($l -like '*\.cache' -or $l -like '*\cache') { return 'generic cache folder - usually safe to empty' }
    if ($l -like '*git-pull-arena*') { return 'old session clone - ASK USER: delete only if that session is over' }
    return 'inspect before deleting'
}

Write-Output '--- cache / reclaim candidates (tracked during the walk, top 30) ---'
$accSorted = @($accDone | Sort-Object { [double]$_.bytes } -Descending | Select-Object -First 30)
if ($accSorted.Count -eq 0) { Write-Output '   (none found)' }
foreach ($a in $accSorted) {
    $ap = [string]$a.path
    $ab = [double]$a.bytes
    $af = [long]$a.files
    Write-Output ('   ' + (FmtB $ab).PadLeft(12) + '  ' + $af.ToString().PadLeft(8) + ' files  ' + (San $ap))
    Write-Output ('        -> ' + (Tag-For $ap))
}

Write-Output '--- largest files on E: (top 25) ---'
$bfSorted = @($bigFiles | Sort-Object b -Descending | Select-Object -First 25)
foreach ($bf in $bfSorted) {
    Write-Output ('   ' + (FmtB ([double]$bf.b)).PadLeft(12) + '  ' + (San ([string]$bf.p)))
}

Write-Output '--- installers / archives >= 200 MB (top 20) ---'
$arch = @($bigFiles | Where-Object { ($_.e -in @('.exe', '.msi', '.zip', '.7z', '.rar', '.iso', '.cab')) -and $_.b -ge 200MB } | Sort-Object b -Descending | Select-Object -First 20)
if ($arch.Count -eq 0) { Write-Output '   (none)' }
foreach ($bf in $arch) {
    Write-Output ('   ' + (FmtB ([double]$bf.b)).PadLeft(12) + '  ' + (San ([string]$bf.p)))
}

Write-Output '--- vm disks / crash dumps (any size, top 20) ---'
$spSorted = @($specials | Sort-Object b -Descending | Select-Object -First 20)
if ($spSorted.Count -eq 0) { Write-Output '   (none)' }
foreach ($sp in $spSorted) {
    Write-Output ('   ' + (FmtB ([double]$sp.b)).PadLeft(12) + '  ' + (San ([string]$sp.p)))
}

Write-Output 'NOTE: this scan is READ-ONLY. Nothing was deleted or modified.'
Write-Output '      Cleanup happens only in a later round, after you approve the list.'
exit 0
