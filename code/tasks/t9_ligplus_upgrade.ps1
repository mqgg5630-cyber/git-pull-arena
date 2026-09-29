# t9_ligplus_upgrade.ps1 - round 28 task: the desktop LigPlus.jar (found at
# E:\1result\LigPlus.jar, v2.2.9 from Sep 2024) is EXPIRED. User wants:
# find a NEWER LigPlus on the machine, test it, and if the new one works,
# remove the expired one; otherwise prove the java env with another jar app.
#
# Steps:
#   1. search E:\ (depth 5), D:\ (depth 2) and the real desktops for
#      LigPlus*.jar and folders named *LigPlus* / *Ligplot*
#   2. test-launch the NEWEST candidate (25s watch, full output, expiry grep)
#   3. if the new one works AND is a different file -> move the OLD expired
#      jar to the recycle bin (recoverable); its lib folder is left alone
#   4. if no new version exists or it also fails -> keep everything, then
#      test one other desktop/E: jar app to prove java works
# Nothing is deleted except the old jar to the recycle bin, and only on
# success. Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t9: LigPlus upgrade (find newer, test, swap) ---'

$javaExe = 'E:\java\jdk-21.0.12.1+1\bin\java.exe'
if (-not (Test-Path -LiteralPath $javaExe)) {
    $c = Get-Command java -ErrorAction SilentlyContinue
    if ($c) { $javaExe = [string]$c.Source } else { Write-Output '   [FAIL] no java'; exit 2 }
}
Write-Output ('   java: ' + (San $javaExe))
$oldJar = 'E:\1result\LigPlus.jar'

# ------------------------------------------------------------- 1. search
Write-Output '--- search for LigPlus copies (E:\ depth 5, D:\ depth 2, desktops) ---'
$jars = New-Object System.Collections.Generic.List[object]
$dirs = New-Object System.Collections.Generic.List[object]
$roots = @(
    @{ p = 'E:\'; d = 5 },
    @{ p = 'D:\'; d = 2 }
)
try { $roots += @{ p = [Environment]::GetFolderPath('Desktop'); d = 3 } } catch { }
foreach ($r in $roots) {
    if (-not $r.p -or -not (Test-Path -LiteralPath $r.p)) { continue }
    Write-Output ('   scanning ' + (San $r.p) + ' (depth ' + $r.d + ') ...')
    try {
        foreach ($f in @(Get-ChildItem -LiteralPath $r.p -Recurse -Depth $r.d -File -Filter 'LigPlus*.jar' -ErrorAction SilentlyContinue)) { $jars.Add($f) }
        foreach ($f in @(Get-ChildItem -LiteralPath $r.p -Recurse -Depth $r.d -File -Filter 'LigPlot*.jar' -ErrorAction SilentlyContinue)) { $jars.Add($f) }
        foreach ($d in @(Get-ChildItem -LiteralPath $r.p -Recurse -Depth $r.d -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)ligplus|ligplot' })) { $dirs.Add($d) }
    } catch { }
}
Write-Output ('   jars found: ' + $jars.Count + ' ; folders found: ' + $dirs.Count)
foreach ($d in @($dirs | Select-Object -First 10)) { Write-Output ('   folder: ' + (San $d.FullName)) }
foreach ($j in @($jars | Sort-Object LastWriteTime -Descending)) {
    Write-Output ('   jar: ' + (San $j.FullName) + '  (' + $j.Length + ' B, ' + $j.LastWriteTime.ToString('yyyy-MM-dd HH:mm') + ')')
}

# ------------------------------------------------- 2. pick the newest jar
$newest = $null
foreach ($j in @($jars | Sort-Object LastWriteTime -Descending)) {
    if ($j.FullName -ne $oldJar) { $newest = $j; break }
}
if ($newest) {
    Write-Output ('   candidate NEW version: ' + (San $newest.FullName) + ' (' + $newest.LastWriteTime.ToString('yyyy-MM-dd') + ')')
    if ($newest.LastWriteTime -le (Get-Item -LiteralPath $oldJar -ErrorAction SilentlyContinue).LastWriteTime) {
        Write-Output '   [WARN] the "new" jar is not newer than the old one - still testing it'
    }
} else {
    Write-Output '   no second LigPlus jar found on the machine'
}

# ------------------------------------------------------ 3. test launcher
function Test-Jar {
    param([string]$path, [int]$watchSec)
    $jarDir = Split-Path -Parent $path
    $outF = [System.IO.Path]::GetTempFileName()
    $errF = [System.IO.Path]::GetTempFileName()
    $p = $null
    try {
        $p = Start-Process -FilePath $javaExe -ArgumentList @('-jar', ('"' + $path + '"')) -WorkingDirectory $jarDir -RedirectStandardOutput $outF -RedirectStandardError $errF -PassThru
    } catch {
        Write-Output ('   [FAIL] launch threw: ' + (San $_.Exception.Message))
        return @{ ok = $false; title = ''; out = '' }
    }
    $alive = 0
    $title = ''
    $loops = [int]($watchSec / 2)
    for ($i = 0; $i -lt $loops; $i++) {
        Start-Sleep -Seconds 2
        if ($p.HasExited) { break }
        $alive = ($i + 1) * 2
        try {
            $p2 = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
            if ($p2 -and $p2.MainWindowTitle) { $title = [string]$p2.MainWindowTitle }
        } catch { }
    }
    Start-Sleep -Seconds 2
    $o = ''
    $e = ''
    try { $o = (Get-Content -LiteralPath $outF -Raw -ErrorAction SilentlyContinue) } catch { }
    try { $e = (Get-Content -LiteralPath $errF -Raw -ErrorAction SilentlyContinue) } catch { }
    Remove-Item -LiteralPath $outF, $errF -Force -ErrorAction SilentlyContinue
    if (-not $p.HasExited) {
        try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch { }
        $exitCode = 'still-running(killed-by-test)'
    } else {
        $exitCode = [string]$p.ExitCode
    }
    Write-Output ('      alive: ' + $alive + 's, exit: ' + $exitCode + ', window title: ' + (San $title))
    $all = ($o + "`n" + $e)
    $shown = 0
    foreach ($l in @(($all -split "`r?`n") | Where-Object { $_ -match '\S' })) {
        if ($shown -ge 40) { Write-Output '      ... (more lines cut)'; break }
        Write-Output ('      out: ' + (San ([string]$l)))
        $shown++
    }
    $expired = ($all -match '(?i)expir|licen[cs]e')
    $ok = ((-not $p.HasExited) -and ($alive -ge 16) -and (-not $expired))
    return @{ ok = $ok; title = $title; out = $all }
}

# -------------------------------------------- 4. test new, then old swap
$swapped = $false
if ($newest) {
    Write-Output ('--- test NEW jar: ' + (San $newest.FullName) + ' ---')
    $r = Test-Jar -path $newest.FullName -watchSec 25
    if ($r.ok) {
        Write-Output '   OK: the new jar runs (stayed open, no license/expiry message)'
        if ($newest.FullName -ne $oldJar -and (Test-Path -LiteralPath $oldJar)) {
            Add-Type -AssemblyName Microsoft.VisualBasic
            try {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($oldJar, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs, [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
                Write-Output ('   REMOVED (to recycle bin): ' + (San $oldJar) + '  - the expired copy')
                Write-Output '   its E:\1result\lib folder was LEFT ALONE (harmless, and other tools may use it)'
                $swapped = $true
            } catch {
                Write-Output ('   [WARN] could not remove the old jar: ' + (San $_.Exception.Message))
            }
        }
    } else {
        Write-Output '   [FAIL] the new jar did not stay open (see output above - maybe also expired)'
        Write-Output '   the old jar is KEPT (nothing removed)'
    }
}

if (-not $swapped) {
    # no new version, or new one failed: prove java works with another jar
    Write-Output '--- no successful swap - testing the OLD jar fully to record its expiry, then looking for other jars ---'
    if (-not $newest -and (Test-Path -LiteralPath $oldJar)) {
        $ro = Test-Jar -path $oldJar -watchSec 20
        Write-Output ('   old jar result: ok=' + $ro.ok + ' (expected false if expired)')
    }
    Write-Output '--- other jar apps on E:\ (depth 4, > 500 KB, not inside node_modules) ---'
    $others = @()
    try {
        $others = @(Get-ChildItem -LiteralPath 'E:\' -Recurse -Depth 4 -File -Filter '*.jar' -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 500KB -and $_.FullName -notmatch '(?i)node_modules|\\lib\\|jre' } | Sort-Object Length -Descending | Select-Object -First 10)
    } catch { }
    if ($others.Count -eq 0) { Write-Output '   (none found)' }
    foreach ($o in @($others)) {
        Write-Output ('   other: ' + (San $o.FullName) + '  (' + [math]::Round($o.Length / 1KB) + ' KB, ' + $o.LastWriteTime.ToString('yyyy-MM-dd') + ')')
    }
    if ($others.Count -gt 0) {
        Write-Output ('--- test the largest other jar: ' + (San $others[0].FullName) + ' ---')
        $r2 = Test-Jar -path $others[0].FullName -watchSec 20
        if ($r2.ok) { Write-Output '   OK: java environment PROVEN with this jar app' }
        else { Write-Output '   [WARN] this jar also did not stay open (may be a CLI jar - not necessarily a java problem)' }
    }
}

Write-Output ('--- t9 done (swapped=' + $swapped + ') ---')
exit 0
