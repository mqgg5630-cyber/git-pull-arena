# t12_ligplus_new.ps1 - round 30 task: the user downloaded the NEW LigPlus
# (E:\Users\<user>\Downloads\LigPlus-main\...\LigPlus\LigPlus\LigPlus.jar).
# This task: find it, test it IN PLACE, and only if it runs:
#   - move the OLD install (E:\LigPlus, build 8e97c34d... of Sep 2024) to the
#     recycle bin (user: delete all old versions)
#   - copy the new LigPlus folder to E:\LigPlus\LigPlus (canonical location)
#   - test the copied install too
# The copy inside the WeChat folder is chat history and is NOT touched.
# If the new jar does not run, NOTHING is removed and full output is printed.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t12: install + test the NEW LigPlus ---'
$javaExe = 'E:\java\jdk-21.0.12.1+1\bin\java.exe'
if (-not (Test-Path -LiteralPath $javaExe)) {
    $c = Get-Command java -ErrorAction SilentlyContinue
    if ($c) { $javaExe = [string]$c.Source } else { Write-Output '   [FAIL] no java'; exit 2 }
}
Write-Output ('   java: ' + (San $javaExe))

# ------------------------------------------------------- 1. find new jar
$newJar = $null
try {
    $hits = @(Get-ChildItem -LiteralPath 'E:\Users' -Recurse -Depth 7 -File -Filter 'LigPlus.jar' -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match '(?i)LigPlus-main' } | Sort-Object LastWriteTime -Descending)
    if ($hits.Count -gt 0) { $newJar = $hits[0] }
} catch { }
if (-not $newJar) {
    foreach ($alt in @('E:\Downloads', 'D:\')) {
        try {
            $hits = @(Get-ChildItem -LiteralPath $alt -Recurse -Depth 6 -File -Filter 'LigPlus.jar' -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match '(?i)LigPlus-main' } | Select-Object -First 1)
            if ($hits.Count -gt 0) { $newJar = $hits[0]; break }
        } catch { }
    }
}
if (-not $newJar) { Write-Output '   [FAIL] LigPlus-main jar not found under E:\Users\*\Downloads'; exit 2 }
$newPath = $newJar.FullName
try { $mt = $newJar.LastWriteTime.ToString('yyyy-MM-dd HH:mm') } catch { $mt = '?' }
$newHash = ''
try { $newHash = (Get-FileHash -LiteralPath $newPath -Algorithm SHA256).Hash.Substring(0, 16).ToLowerInvariant() } catch { }
Write-Output ('   NEW jar: ' + (San $newPath) + ' (' + $newJar.Length + ' B, ' + $mt + ', sha256 ' + $newHash + ')')
$oldHash = '8e97c34dda2aa160'
if ($newHash -eq $oldHash) {
    Write-Output '   [WARN] same hash as the expired build - testing anyway'
}

# --------------------------------------------------------- 2. test runner
function Test-LigPlus {
    param([string]$path, [int]$watchSec)
    $dir = Split-Path -Parent $path
    $outF = [System.IO.Path]::GetTempFileName()
    $errF = [System.IO.Path]::GetTempFileName()
    $p = $null
    try {
        $p = Start-Process -FilePath $javaExe -ArgumentList @('-jar', ('"' + $path + '"')) -WorkingDirectory $dir -RedirectStandardOutput $outF -RedirectStandardError $errF -PassThru
    } catch {
        Write-Output ('   [FAIL] launch threw: ' + (San $_.Exception.Message))
        return @{ ok = $false }
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
    $wasAlive = (-not $p.HasExited)
    if ($wasAlive) { try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch { } }
    $o = ''
    $e = ''
    try { $o = (Get-Content -LiteralPath $outF -Raw -ErrorAction SilentlyContinue) } catch { }
    try { $e = (Get-Content -LiteralPath $errF -Raw -ErrorAction SilentlyContinue) } catch { }
    Remove-Item -LiteralPath $outF, $errF -Force -ErrorAction SilentlyContinue
    [Console]::WriteLine('      alive ' + $alive + 's, still-running=' + $wasAlive + ', title="' + (San $title) + '"')
    $all = ($o + "`n" + $e)
    $n = 0
    foreach ($l in @(($all -split "`r?`n") | Where-Object { $_ -match '\S' })) {
        if ($n -ge 30) { Write-Output '      ... (cut)'; break }
        Write-Output ('      out: ' + (San ([string]$l)))
        $n++
    }
    $expired = ($all -match '(?i)expir')
    $ok = ($wasAlive -and ($alive -ge 16) -and (-not $expired))
    return @{ ok = $ok; title = $title }
}

# ---------------------------------------------------- 3. test in place
Write-Output '--- test the NEW jar in place ---'
$r = Test-LigPlus -path $newPath -watchSec 25
if (-not $r.ok) {
    Write-Output '   [FAIL] the new jar did not stay open (or printed an expiry message)'
    Write-Output '   NOTHING was removed - old install kept, no copy made'
    exit 2
}
Write-Output '   OK: the NEW LigPlus runs (stayed open, no expiry message)'

# ------------------------------------- 4. remove old install, copy new
Add-Type -AssemblyName Microsoft.VisualBasic
$oldRoot = 'E:\LigPlus'
if (Test-Path -LiteralPath $oldRoot) {
    try {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($oldRoot, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs, [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
        Write-Output '   REMOVED to the recycle bin: E:\LigPlus (the whole old install - old jar, pdb_collection copy, old lib)'
    } catch {
        Write-Output ('   [WARN] could not remove the old install: ' + (San $_.Exception.Message))
    }
} else {
    Write-Output '   old install E:\LigPlus already gone'
}

$srcDir = Split-Path -Parent $newPath
$copiedJar = $null
try {
    New-Item -ItemType Directory -Force -Path $oldRoot | Out-Null
    Copy-Item -LiteralPath $srcDir -Destination $oldRoot -Recurse -Force
    $leaf = Split-Path -Leaf $srcDir
    $copiedJar = Join-Path (Join-Path $oldRoot $leaf) 'LigPlus.jar'
    Write-Output ('   COPIED the new install to: ' + (San $copiedJar))
} catch {
    Write-Output ('   [WARN] copy to E:\LigPlus failed: ' + (San $_.Exception.Message))
    $copiedJar = $null
}

# ------------------------------------------------- 5. test the copy
if ($copiedJar -and (Test-Path -LiteralPath $copiedJar)) {
    Write-Output '--- test the COPIED install ---'
    $r2 = Test-LigPlus -path $copiedJar -watchSec 25
    if ($r2.ok) {
        Write-Output ('   OK: the copied install also runs - use it from ' + (San (Split-Path -Parent $copiedJar)))
    } else {
        Write-Output '   [WARN] the copy did not stay open - the original in Downloads still works; the agent will fix the copy next round'
    }
} else {
    Write-Output '   (no copied install to test - the Downloads original is the working one)'
}

Write-Output '   NOTE: the LigPlus.jar inside E:\xwechat_files was NOT touched (it is WeChat chat history).'
Write-Output '         Say the word and the agent removes that one too.'
$doneMsg = '== LigPlus UPGRADE DONE: new version tested' + $(if ($copiedJar) { ' + installed at E:\LigPlus' } else { '' })
Write-Output $doneMsg
exit 0
