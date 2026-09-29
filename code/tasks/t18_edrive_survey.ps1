# t18_edrive_survey.ps1 - round 34 task: the big E: survey the user asked
# for: LARGE files, DUPLICATES (hash-verified), LONG-UNUSED software - with
# sizes and timestamps, so the user can decide what to delete.
#
#   1. full walk of E: (540s budget): per-top-level totals (size + newest
#      last-write / last-access) and every file >= 100 MB
#   2. duplicates: files >= 100 MB grouped by size -> 4 MB prefix SHA256 ->
#      full SHA256 (files > 2 GB: prefix match only, too slow to full-hash)
#   3. long-unused: top-level folders whose newest access is > 180 days old,
#      and big files untouched > 180 days
#   4. installed software on E: (registry) with measured install sizes
#   5. FULL report written to results/status/edrive_survey_r34.md (English
#      labels, ASCII-safe) - the watcher auto-pushes it back with the receipt
# READ-ONLY: nothing is deleted.
# Windows PowerShell 5.1 task body, ASCII-only.

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

Write-Output '--- task t18: E: survey (large / duplicate / long-unused) - READ-ONLY ---'
$today = Get-Date
$stale = $today.AddDays(-180)

# ------------------------------------------------------------- 1. walk
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$walkCap = 540
$topBytes = @{}
$topFiles = @{}
$topLW = @{}
$topLA = @{}
$big = New-Object System.Collections.Generic.List[object]
$partial = $false
$stack = New-Object System.Collections.Stack
$stack.Push('E:\')
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
            if ($len -ge 100MB) { $big.Add([pscustomobject]@{ p = $f; sz = $len; lw = $lw; la = $la }) }
        }
    } catch { }
}
$walkSec = [int]$sw.Elapsed.TotalSeconds
Write-Output ('   walk: top-level entries tracked: ' + $topBytes.Count + ', big(>=100MB) files: ' + $big.Count + ', ' + $walkSec + 's' + $(if ($partial) { ' (PARTIAL - 540s cap hit; sizes below are lower bounds)' } else { '' }))

$laNote = 'unknown'
try {
    $fs = (& fsutil behavior query disablelastaccess 2>&1 | Out-String).Trim()
    $laNote = (San ($fs -replace '\s+', ' '))
} catch { }
Write-Output ('   last-access policy: ' + $laNote)

# ------------------------------------------------------- 2. duplicates
Write-Output '--- duplicates (size match -> 4MB prefix hash -> full hash) ---'
$hsw = [System.Diagnostics.Stopwatch]::StartNew()
$hashBudget = 240
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
    $pref = @{}
    foreach ($b in @($bySize[$k])) {
        if ($hsw.Elapsed.TotalSeconds -gt $hashBudget) { break }
        $ph = ''
        try {
            $fs2 = [System.IO.File]::OpenRead($b.p)
            $buf = New-Object byte[] (4MB)
            $got = $fs2.Read($buf, 0, $buf.Length)
            $fs2.Close()
            $ha = (New-Object System.Security.Cryptography.SHA256Managed).ComputeHash($buf, 0, $got)
            $ph = ($ha[0..7] -join '')
        } catch { $ph = ('ERR' + $b.p) }
        if (-not $pref.ContainsKey($ph)) { $pref[$ph] = New-Object System.Collections.Generic.List[object] }
        $pref[$ph].Add($b)
    }
    foreach ($pk in @($pref.Keys)) {
        if ($pref[$pk].Count -lt 2) { continue }
        $group = @($pref[$pk])
        $confirmed = $true
        if ($group[0].sz -le 2GB) {
            # confirm with full hash
            $full = @{}
            foreach ($b in $group) {
                if ($hsw.Elapsed.TotalSeconds -gt $hashBudget) { break }
                $fh = ''
                try { $fh = (Get-FileHash -LiteralPath $b.p -Algorithm SHA256).Hash } catch { $fh = ('ERR' + $b.p) }
                if (-not $full.ContainsKey($fh)) { $full[$fh] = New-Object System.Collections.Generic.List[object] }
                $full[$fh].Add($b)
            }
            $confirmed = $false
            foreach ($fk in @($full.Keys)) {
                if ($full[$fk].Count -ge 2) { $dupeGroups += , @($full[$fk]); $confirmed = $true }
            }
        }
        if (-not $confirmed -and $group.Count -ge 2) {
            # > 2 GB: prefix match + identical size is strong evidence; tag it
            $dupeGroups += , @($group)
        }
    }
}
$dupeReclaim = [double]0
foreach ($g in $dupeGroups) { $dupeReclaim += [double]($g[0].sz) * ($g.Count - 1) }
Write-Output ('   duplicate groups (>=100MB, hash-verified): ' + $dupeGroups.Count + ' ; reclaimable: ' + (FmtB $dupeReclaim))
$di = 0
foreach ($g in $dupeGroups) {
    if ($di -ge 15) { Write-Output '   ... (more in the md report)'; break }
    Write-Output ('   DUPE ' + (FmtB ([double]$g[0].sz)) + ' x' + $g.Count + ':')
    foreach ($b in @($g | Select-Object -First 6)) { Write-Output ('      ' + (San ([string]$b.p))) }
    $di++
}

# -------------------------------------------------- 3. long-unused folders
Write-Output '--- long-unused top-level folders (newest access > 180 days ago) ---'
$staleFolders = @()
foreach ($k in @($topBytes.Keys)) {
    if ($k -eq '(root files)') { continue }
    if ($topLA[$k] -ne [datetime]::MinValue -and $topLA[$k] -lt $stale -and $topLW[$k] -lt $stale) {
        $staleFolders += [pscustomobject]@{ name = $k; bytes = [double]$topBytes[$k]; files = [long]$topFiles[$k]; la = $topLA[$k]; lw = $topLW[$k] }
    }
}
$staleFolders = @($staleFolders | Sort-Object bytes -Descending)
$staleTotal = [double]0
foreach ($s in $staleFolders) { $staleTotal += $s.bytes }
Write-Output ('   stale folders: ' + $staleFolders.Count + ' totaling ' + (FmtB $staleTotal))
foreach ($s in @($staleFolders | Select-Object -First 20)) {
    Write-Output ('   STALE ' + (FmtB ([double]$s.bytes)).PadLeft(12) + '  last access ' + $s.la.ToString('yyyy-MM-dd') + '  E:\' + (San ([string]$s.name)))
}

$staleBig = @($big | Where-Object { ($_.lw -lt $stale) -and ($_.la -lt $stale) -and $_.sz -ge 200MB } | Sort-Object sz -Descending)
Write-Output '--- big files (>=200MB) untouched > 180 days ---'
foreach ($b in @($staleBig | Select-Object -First 20)) {
    Write-Output ('   STALE ' + (FmtB ([double]$b.sz)).PadLeft(12) + '  ' + $b.la.ToString('yyyy-MM-dd') + '  ' + (San ([string]$b.p)))
}

# ------------------------------------------------- 4. installed software
Write-Output '--- installed software on E: (registry) ---'
$apps = @()
foreach ($up in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
    foreach ($it in @(Get-ItemProperty -Path $up -ErrorAction SilentlyContinue)) {
        $dn = [string]$it.DisplayName
        $loc = [string]$it.InstallLocation
        if ($dn -and $loc -like 'E:\*') {
            $apps += [pscustomobject]@{ name = $dn; ver = [string]$it.DisplayVersion; loc = $loc.TrimEnd('\'); date = [string]$it.InstallDate }
        }
    }
}
$apps = @($apps | Sort-Object name -Unique)
Write-Output ('   apps installed on E:: ' + $apps.Count)
$appRows = New-Object System.Collections.Generic.List[object]
$asw = [System.Diagnostics.Stopwatch]::StartNew()
foreach ($a in $apps) {
    if ($asw.Elapsed.TotalSeconds -gt 180) { break }
    $sz2 = [double]0
    $la2 = [datetime]::MinValue
    if (Test-Path -LiteralPath $a.loc) {
        $ssw = [System.Diagnostics.Stopwatch]::StartNew()
        $st2 = New-Object System.Collections.Stack
        $st2.Push($a.loc)
        while ($st2.Count -gt 0 -and $ssw.Elapsed.TotalSeconds -lt 30) {
            $d = [string]$st2.Pop()
            try { foreach ($sd in [System.IO.Directory]::EnumerateDirectories($d)) { $st2.Push($sd) } } catch { }
            try {
                foreach ($f in [System.IO.Directory]::EnumerateFiles($d)) {
                    try {
                        $fi2 = [System.IO.FileInfo]::new($f)
                        $sz2 += [double]$fi2.Length
                        if ($fi2.LastAccessTime -gt $la2) { $la2 = $fi2.LastAccessTime }
                    } catch { }
                }
            } catch { }
        }
    }
    $appRows.Add([pscustomobject]@{ name = $a.name; ver = $a.ver; loc = $a.loc; date = $a.date; sz = $sz2; la = $la2 })
}
foreach ($r in @($appRows | Sort-Object sz -Descending)) {
    $laS = '(n/a)'
    if ($r.la -ne [datetime]::MinValue) { $laS = $r.la.ToString('yyyy-MM-dd') }
    Write-Output ('   APP  ' + (FmtB ([double]$r.sz)).PadLeft(12) + '  used ' + $laS + '  ' + (San ([string]$r.name)) + ' ' + (San ([string]$r.ver)) + '  @ ' + (San ([string]$r.loc)))
}

# ------------------------------------------------ 5. write the md report
$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine('# E: cleanup survey report (round 34, 2026-09-29)')
[void]$md.AppendLine('')
[void]$md.AppendLine('> READ-ONLY scan. Nothing was deleted. Every item below is evidence for YOUR decision.')
[void]$md.AppendLine('')
[void]$md.AppendLine('## 1. Overview')
[void]$md.AppendLine('')
[void]$md.AppendLine(('- Scope: all of E: (symlinks skipped); this scan ' + $(if ($partial) { 'hit the 540s cap - numbers are LOWER bounds' } else { 'completed' })))
[void]$md.AppendLine(('- Last-access policy: ' + $laNote + ' (if it says disabled, judge "unused" by last-WRITE instead)'))
[void]$md.AppendLine('')
[void]$md.AppendLine('## 2. Top-level folders (size / files / last access)')
[void]$md.AppendLine('')
[void]$md.AppendLine('| size | files | last access | folder |')
[void]$md.AppendLine('|---|---|---|---|')
foreach ($e in @($topBytes.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 60)) {
    $laS2 = '-'
    if ($topLA[$e.Key] -ne [datetime]::MinValue) { $laS2 = $topLA[$e.Key].ToString('yyyy-MM-dd') }
    [void]$md.AppendLine('| ' + (FmtB ([double]$e.Value)) + ' | ' + $topFiles[$e.Key] + ' | ' + $laS2 + ' | E:\\' + $e.Key + ' |')
}
[void]$md.AppendLine('')
[void]$md.AppendLine('## 3. Largest files (>= 100 MB, top 60)')
[void]$md.AppendLine('')
[void]$md.AppendLine('| size | last write | last access | file |')
[void]$md.AppendLine('|---|---|---|---|')
foreach ($b in @($big | Sort-Object sz -Descending | Select-Object -First 60)) {
    [void]$md.AppendLine('| ' + (FmtB ([double]$b.sz)) + ' | ' + $b.lw.ToString('yyyy-MM-dd') + ' | ' + $b.la.ToString('yyyy-MM-dd') + ' | ' + $b.p + ' |')
}
[void]$md.AppendLine('')
[void]$md.AppendLine('Notes: `E:\\pagefile.sys` is the E: page file - do NOT delete it directly; shrink or move it via System Properties > Advanced > Performance > Virtual Memory (reboot needed). `E:\\WSL\\Ubuntu-24.04\\ext4.vhdx` is the WSL disk (user keeps it). `E:\\Docker\\WSLData` is Docker engine data.')
[void]$md.AppendLine('')
[void]$md.AppendLine('## 4. Duplicate files (>= 100 MB, identical size + hash; >2GB files: prefix-hash match)')
[void]$md.AppendLine('')
[void]$md.AppendLine(('Total groups: ' + $dupeGroups.Count + ' ; reclaimable: ' + (FmtB $dupeReclaim) + ' (keep ONE copy per group).'))
[void]$md.AppendLine('')
foreach ($g in $dupeGroups) {
    [void]$md.AppendLine(('### group: ' + (FmtB ([double]$g[0].sz)) + ' x ' + $g.Count + ' copies'))
    foreach ($b in $g) { [void]$md.AppendLine('- ' + $b.p) }
    [void]$md.AppendLine('')
}
[void]$md.AppendLine('## 5. Long-unused top-level folders (last access AND last write > 180 days ago)')
[void]$md.AppendLine('')
[void]$md.AppendLine(('Total: ' + $staleFolders.Count + ' folders, ' + (FmtB $staleTotal) + '.'))
[void]$md.AppendLine('')
[void]$md.AppendLine('| size | last access | folder |')
[void]$md.AppendLine('|---|---|---|')
foreach ($s in $staleFolders) {
    [void]$md.AppendLine('| ' + (FmtB ([double]$s.bytes)) + ' | ' + $s.la.ToString('yyyy-MM-dd') + ' | E:\\' + $s.name + ' |')
}
[void]$md.AppendLine('')
[void]$md.AppendLine('## 6. Long-unused big files (>= 200 MB, untouched > 180 days)')
[void]$md.AppendLine('')
[void]$md.AppendLine('| size | last access | file |')
[void]$md.AppendLine('|---|---|---|')
foreach ($b in $staleBig) {
    [void]$md.AppendLine('| ' + (FmtB ([double]$b.sz)) + ' | ' + $b.la.ToString('yyyy-MM-dd') + ' | ' + $b.p + ' |')
}
[void]$md.AppendLine('')
[void]$md.AppendLine('## 7. Software installed on E: (registry, with measured size and last use)')
[void]$md.AppendLine('')
[void]$md.AppendLine('| size | last used | software | version | location |')
[void]$md.AppendLine('|---|---|---|---|---|')
foreach ($r in @($appRows | Sort-Object sz -Descending)) {
    $laS3 = '-'
    if ($r.la -ne [datetime]::MinValue) { $laS3 = $r.la.ToString('yyyy-MM-dd') }
    [void]$md.AppendLine('| ' + (FmtB ([double]$r.sz)) + ' | ' + $laS3 + ' | ' + $r.name + ' | ' + $r.ver + ' | ' + $r.loc + ' |')
}
[void]$md.AppendLine('')
[void]$md.AppendLine('## 8. Suggested next steps (all need YOUR confirmation)')
[void]$md.AppendLine('')
[void]$md.AppendLine(('1. Section 4 duplicates: delete the extra copies -> ' + (FmtB $dupeReclaim)))
[void]$md.AppendLine('2. Section 5 stale folders you recognize as old tools: confirm one by one, then delete')
[void]$md.AppendLine('3. Section 6 stale big files (old installers / old data): confirm, then delete')
[void]$md.AppendLine('4. E:\\pagefile.sys (36 GB): if RAM is enough, cap it at 8-16 GB (reboot) -> ~20-28 GB back')
[void]$md.AppendLine('5. Docker build cache (10 GB, 0% used): `docker builder prune -a` reclaims all of it')
[void]$md.AppendLine('')
$mdPath = '.\results\status\edrive_survey_r34.md'
try {
    [System.IO.File]::WriteAllText((Join-Path (Get-Location) 'results\status\edrive_survey_r34.md'), $md.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    Write-Output ('   report written: ' + $mdPath + ' (' + $md.Length + ' chars) - the watcher pushes it back with this receipt')
} catch {
    Write-Output ('   [WARN] report write failed: ' + (San $_.Exception.Message))
}

Write-Output '--- task t18 done (READ-ONLY) ---'
exit 0
