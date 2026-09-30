# t29_ddrive_survey.ps1 - round 43 task: D: cleanup survey (same method as
# the E: survey in round 36): top-level sizes, files >= 50 MB, duplicates
# (>= 50 MB, size -> prefix hash -> full hash), 180-day-unused folders/files,
# software installed on D:. Report to results/status/ddrive_survey_r43.md.
# READ-ONLY. Windows PowerShell 5.1, ASCII-only, Write-Output only.

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

Write-Output '--- task t29: D: survey (READ-ONLY) ---'

$drive = $null
try { $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='D:'" -ErrorAction Stop } catch { }
if (-not $drive) { Write-Output '   D: not found'; exit 0 }
Write-Output ('   D: total ' + ([math]::Round($drive.Size / 1GB, 1)) + ' GB, used ' + ([math]::Round(($drive.Size - $drive.FreeSpace) / 1GB, 1)) + ' GB, free ' + ([math]::Round($drive.FreeSpace / 1GB, 1)) + ' GB')

$stale = (Get-Date).AddDays(-180)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$walkCap = 420
$BIG = 50MB
$topBytes = @{}
$topFiles = @{}
$topLW = @{}
$topLA = @{}
$big = New-Object System.Collections.Generic.List[object]
$partial = $false
$stack = New-Object System.Collections.Stack
$stack.Push('D:\')
while ($stack.Count -gt 0) {
    if ($sw.Elapsed.TotalSeconds -gt $walkCap) { $partial = $true; break }
    $dir = [string]$stack.Pop()
    $seg = '(root files)'
    if ($dir.Length -gt 3) {
        $i = $dir.IndexOf('\', 3)
        if ($i -gt 0) { $seg = $dir.Substring(3, $i - 3) }
    }
    if (-not $topBytes.ContainsKey($seg)) {
        $topBytes[$seg] = [double]0
        $topFiles[$seg] = [long]0
        $topLW[$seg] = [datetime]::MinValue
        $topLA[$seg] = [datetime]::MinValue
    }
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
            $lw = [datetime]::MinValue
            $la = [datetime]::MinValue
            try {
                $fi = [System.IO.FileInfo]::new($f)
                $len = [double]$fi.Length
                $lw = $fi.LastWriteTime
                $la = $fi.LastAccessTime
            } catch { }
            $topBytes[$seg] = [double]$topBytes[$seg] + $len
            $topFiles[$seg] = [long]$topFiles[$seg] + 1
            if ($lw -gt $topLW[$seg]) { $topLW[$seg] = $lw }
            if ($la -gt $topLA[$seg]) { $topLA[$seg] = $la }
            if ($len -ge $BIG) { $big.Add([pscustomobject]@{ p = $f; sz = $len; lw = $lw; la = $la }) }
        }
    } catch { }
}
Write-Output ('   walk: ' + $topBytes.Count + ' top-level entries, ' + $big.Count + ' files >=50MB, ' + [int]$sw.Elapsed.TotalSeconds + 's' + $(if ($partial) { ' (PARTIAL - 420s cap)' } else { '' }))

# duplicates >= 50MB
Write-Output '--- duplicates (>= 50MB) ---'
$hsw = [System.Diagnostics.Stopwatch]::StartNew()
$hashBudget = 180
$bySize = @{}
foreach ($b in $big) {
    $k = [string]$b.sz
    if (-not $bySize.ContainsKey($k)) { $bySize[$k] = New-Object System.Collections.Generic.List[object] }
    $bySize[$k].Add($b)
}
$dupeGroups = @()
foreach ($k in @($bySize.Keys)) {
    if ($bySize[$k].Count -lt 2) { continue }
    if ($hsw.Elapsed.TotalSeconds -gt $hashBudget) { break }
    $full = @{}
    foreach ($b in @($bySize[$k])) {
        if ($hsw.Elapsed.TotalSeconds -gt $hashBudget) { break }
        $fh = ''
        try { $fh = (Get-FileHash -LiteralPath $b.p -Algorithm SHA256).Hash } catch { $fh = ('ERR' + $b.p) }
        if (-not $full.ContainsKey($fh)) { $full[$fh] = New-Object System.Collections.Generic.List[object] }
        $full[$fh].Add($b)
    }
    foreach ($fk in @($full.Keys)) {
        if ($full[$fk].Count -ge 2) { $dupeGroups += , @($full[$fk]) }
    }
}
$dupeReclaim = [double]0
foreach ($g in $dupeGroups) { $dupeReclaim += [double]($g[0].sz) * ($g.Count - 1) }
Write-Output ('   duplicate groups: ' + $dupeGroups.Count + ' ; reclaimable: ' + (FmtB $dupeReclaim))
foreach ($g in @($dupeGroups | Select-Object -First 10)) {
    Write-Output ('   DUPE ' + (FmtB ([double]$g[0].sz)) + ' x' + $g.Count)
    foreach ($b in @($g | Select-Object -First 5)) { Write-Output ('      ' + (San ([string]$b.p))) }
}

# stale folders
$staleFolders = @()
foreach ($k in @($topBytes.Keys)) {
    if ($k -eq '(root files)') { continue }
    if ($topLA[$k] -ne [datetime]::MinValue -and $topLA[$k] -lt $stale -and $topLW[$k] -lt $stale) {
        $staleFolders += [pscustomobject]@{ name = $k; bytes = [double]$topBytes[$k]; files = [long]$topFiles[$k]; la = $topLA[$k] }
    }
}
$staleFolders = @($staleFolders | Sort-Object bytes -Descending)
$staleTotal = [double]0
foreach ($s in $staleFolders) { $staleTotal += $s.bytes }
Write-Output ('--- long-unused folders (180d) ---')
Write-Output ('   stale: ' + $staleFolders.Count + ' totaling ' + (FmtB $staleTotal))
foreach ($s in @($staleFolders | Select-Object -First 15)) {
    Write-Output ('   STALE ' + (FmtB ([double]$s.bytes)).PadLeft(11) + '  ' + $s.la.ToString('yyyy-MM-dd') + '  D:\' + (San ([string]$s.name)))
}
$staleBig = @($big | Where-Object { ($_.lw -lt $stale) -and ($_.la -lt $stale) -and $_.sz -ge 100MB } | Sort-Object sz -Descending)
Write-Output '--- big files (>=100MB) untouched 180d ---'
foreach ($b in @($staleBig | Select-Object -First 15)) {
    Write-Output ('   STALE ' + (FmtB ([double]$b.sz)).PadLeft(11) + '  ' + $b.la.ToString('yyyy-MM-dd') + '  ' + (San ([string]$b.p)))
}

# software on D:
$apps = @()
foreach ($up in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
    foreach ($it in @(Get-ItemProperty -Path $up -ErrorAction SilentlyContinue)) {
        $dn = [string]$it.DisplayName
        $loc = [string]$it.InstallLocation
        if ($dn -and $loc -like 'D:\*') { $apps += [pscustomobject]@{ name = $dn; ver = [string]$it.DisplayVersion; loc = $loc.TrimEnd('\'); date = [string]$it.InstallDate } }
    }
}
Write-Output ('--- software installed on D:: ' + (@($apps | Sort-Object name -Unique).Count) + ' ---')
foreach ($a in @($apps | Sort-Object name -Unique)) {
    Write-Output ('   APP  ' + (San ([string]$a.name)) + ' ' + (San ([string]$a.ver)) + '  @ ' + (San ([string]$a.loc)))
}

# md report
$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine('# D: cleanup survey (round 43, 2026-09-30)')
[void]$md.AppendLine('')
[void]$md.AppendLine('> READ-ONLY scan. Nothing deleted.')
[void]$md.AppendLine('')
[void]$md.AppendLine(('## 1. Top-level folders (D:, ' + $(if ($partial) { 'partial scan - lower bounds' } else { 'complete scan' }) + ')'))
[void]$md.AppendLine('')
[void]$md.AppendLine('| size | files | last access | folder |')
[void]$md.AppendLine('|---|---|---|---|')
foreach ($e in @($topBytes.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 50)) {
    $laS = '-'
    if ($topLA[$e.Key] -ne [datetime]::MinValue) { $laS = $topLA[$e.Key].ToString('yyyy-MM-dd') }
    [void]$md.AppendLine('| ' + (FmtB ([double]$e.Value)) + ' | ' + $topFiles[$e.Key] + ' | ' + $laS + ' | D:\\' + $e.Key + ' |')
}
[void]$md.AppendLine('')
[void]$md.AppendLine('## 2. Largest files (>= 50 MB, top 50)')
[void]$md.AppendLine('')
[void]$md.AppendLine('| size | last write | last access | file |')
[void]$md.AppendLine('|---|---|---|---|')
foreach ($b in @($big | Sort-Object sz -Descending | Select-Object -First 50)) {
    [void]$md.AppendLine('| ' + (FmtB ([double]$b.sz)) + ' | ' + $b.lw.ToString('yyyy-MM-dd') + ' | ' + $b.la.ToString('yyyy-MM-dd') + ' | ' + $b.p + ' |')
}
[void]$md.AppendLine('')
[void]$md.AppendLine(('## 3. Duplicates (>= 50 MB, SHA256-verified): ' + $dupeGroups.Count + ' groups, reclaimable ' + (FmtB $dupeReclaim)))
[void]$md.AppendLine('')
foreach ($g in $dupeGroups) {
    [void]$md.AppendLine(('### ' + (FmtB ([double]$g[0].sz)) + ' x ' + $g.Count))
    foreach ($b in $g) { [void]$md.AppendLine('- ' + $b.p) }
    [void]$md.AppendLine('')
}
[void]$md.AppendLine(('## 4. Long-unused folders (180d): ' + $staleFolders.Count + ', ' + (FmtB $staleTotal)))
[void]$md.AppendLine('')
[void]$md.AppendLine('| size | last access | folder |')
[void]$md.AppendLine('|---|---|---|')
foreach ($s in $staleFolders) {
    [void]$md.AppendLine('| ' + (FmtB ([double]$s.bytes)) + ' | ' + $s.la.ToString('yyyy-MM-dd') + ' | D:\\' + $s.name + ' |')
}
[void]$md.AppendLine('')
[void]$md.AppendLine('## 5. Big long-unused files (>= 100 MB, 180d)')
[void]$md.AppendLine('')
[void]$md.AppendLine('| size | last access | file |')
[void]$md.AppendLine('|---|---|---|')
foreach ($b in $staleBig) {
    [void]$md.AppendLine('| ' + (FmtB ([double]$b.sz)) + ' | ' + $b.la.ToString('yyyy-MM-dd') + ' | ' + $b.p + ' |')
}
[void]$md.AppendLine('')
try {
    [System.IO.File]::WriteAllText((Join-Path (Get-Location) 'results\status\ddrive_survey_r43.md'), $md.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    Write-Output ('   report written: results/status/ddrive_survey_r43.md (' + $md.Length + ' chars)')
} catch { Write-Output ('   [WARN] report: ' + (San $_.Exception.Message)) }
exit 0
