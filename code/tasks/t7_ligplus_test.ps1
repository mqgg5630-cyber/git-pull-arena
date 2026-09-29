# t7_ligplus_test.ps1 - round 27 task: try to OPEN LigPlus.jar from the
# desktop with the JDK installed in round 23 (E:\java\jdk-21.0.12.1+1).
# Locates the jar on every desktop (local / OneDrive / E:\Users\*\Desktop),
# launches it, watches the process for 25s (window title + liveness),
# captures stdout/stderr, then closes it and reports.
# Nothing is installed or modified.
#
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t7: LigPlus.jar launch test ---'

# ------------------------------------------------------------ find the jar
$candRoots = @()
try { $candRoots += [Environment]::GetFolderPath('Desktop') } catch { }
foreach ($extra in @((Join-Path $env:USERPROFILE 'Desktop'), (Join-Path $env:USERPROFILE 'OneDrive\Desktop'))) {
    if ($extra -and (Test-Path -LiteralPath $extra)) { $candRoots += $extra }
}
try {
    foreach ($u in [System.IO.Directory]::EnumerateDirectories('E:\Users')) {
        $d = Join-Path $u 'Desktop'
        if (Test-Path -LiteralPath $d) { $candRoots += $d }
    }
} catch { }
$jar = $null
foreach ($root in ($candRoots | Select-Object -Unique)) {
    if (-not $root -or -not (Test-Path -LiteralPath $root)) { continue }
    try {
        $hits = @(Get-ChildItem -LiteralPath $root -Recurse -Depth 3 -Filter '*.jar' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)ligplus|ligplot|lig.?plus' })
        if ($hits.Count -gt 0) { $jar = $hits[0]; break }
    } catch { }
}
if (-not $jar) {
    Write-Output '   jar: NOT found on any desktop (searched *.jar matching ligplus/ligplot, depth 3)'
    Write-Output '   desktop roots searched:'
    foreach ($root in ($candRoots | Select-Object -Unique)) { Write-Output ('      ' + (San $root)) }
    # shallow fallback on E: (depth 2) just in case it moved
    try {
        $hits2 = @(Get-ChildItem -Path 'E:\' -Recurse -Depth 2 -Filter 'LigPlus*.jar' -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($hits2.Count -gt 0) { $jar = $hits2[0] }
    } catch { }
}
if (-not $jar) {
    Write-Output '   [FAIL] LigPlus.jar not found anywhere obvious - tell the agent the exact path'
    exit 2
}
$jarPath = $jar.FullName
$jarDir = Split-Path -Parent $jarPath
try { $mt = $jar.LastWriteTime.ToString('yyyy-MM-dd HH:mm') } catch { $mt = '?' }
Write-Output ('   jar: ' + (San $jarPath) + ' (' + $jar.Length + ' B, ' + $mt + ')')

# ----------------------------------------------------------- find java
$javaExe = $null
$jh = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
if (-not $jh) { $jh = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine') }
if ($jh -and (Test-Path -LiteralPath (Join-Path $jh 'bin\java.exe'))) { $javaExe = Join-Path $jh 'bin\java.exe' }
if (-not $javaExe -and (Test-Path -LiteralPath 'E:\java\jdk-21.0.12.1+1\bin\java.exe')) { $javaExe = 'E:\java\jdk-21.0.12.1+1\bin\java.exe' }
if (-not $javaExe) {
    $c = Get-Command java -ErrorAction SilentlyContinue
    if ($c) { $javaExe = [string]$c.Source }
}
if (-not $javaExe) { Write-Output '   [FAIL] no java found (JAVA_HOME unset and E:\java missing)'; exit 2 }
Write-Output ('   java: ' + (San $javaExe))

# ------------------------------------------------------------- launch
$outF = [System.IO.Path]::GetTempFileName()
$errF = [System.IO.Path]::GetTempFileName()
Write-Output ('   launching: java -jar "' + (San $jarPath) + '" (cwd = jar folder) ...')
$p = $null
try {
    $p = Start-Process -FilePath $javaExe -ArgumentList @('-jar', ('"' + $jarPath + '"')) -WorkingDirectory $jarDir -RedirectStandardOutput $outF -RedirectStandardError $errF -PassThru
} catch {
    Write-Output ('   [FAIL] launch threw: ' + (San $_.Exception.Message))
    exit 2
}
$aliveSec = 0
$title = ''
for ($i = 0; $i -lt 13; $i++) {
    Start-Sleep -Seconds 2
    if ($p.HasExited) { break }
    $aliveSec = ($i + 1) * 2
    try {
        $p2 = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
        if ($p2 -and $p2.MainWindowTitle) { $title = [string]$p2.MainWindowTitle }
    } catch { }
    if ($title) { break }
}
$stdoutT = ''
$stderrT = ''
try { $stdoutT = (Get-Content -LiteralPath $outF -Raw -ErrorAction SilentlyContinue) } catch { }
try { $stderrT = (Get-Content -LiteralPath $errF -Raw -ErrorAction SilentlyContinue) } catch { }

if ($p.HasExited) {
    Write-Output ('   [FAIL] process EXITED after ~' + $aliveSec + 's (exit code ' + $p.ExitCode + ')')
} else {
    Write-Output ('   process ALIVE for ' + $aliveSec + 's' + $(if ($title) { (', window title: ' + (San $title)) } else { ' (no window title captured)' }))
}

# child java processes (some jars spawn a second JVM)
$javaProcs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(?i)java(w)?(c)?$' } | Select-Object -First 6 | ForEach-Object { $_.Name + '(' + $_.Id + ')' + $(if ($_.MainWindowTitle) { ('[' + (San ([string]$_.MainWindowTitle)) + ']') } else { '' }) })
Write-Output ('   java processes now: ' + $(if ($javaProcs.Count) { $javaProcs -join ' ' } else { '(none)' }))

if ($stdoutT -and $stdoutT.Trim()) {
    foreach ($l in @(($stdoutT -split "`r?`n") | Where-Object { $_ -match '\S' } | Select-Object -First 10)) { Write-Output ('   out: ' + (San ([string]$l))) }
}
if ($stderrT -and $stderrT.Trim()) {
    foreach ($l in @(($stderrT -split "`r?`n") | Where-Object { $_ -match '\S' } | Select-Object -First 15)) { Write-Output ('   err: ' + (San ([string]$l))) }
}

# ------------------------------------------------------------ close it
if (-not $p.HasExited) {
    try { Stop-Process -Id $p.Id -Force -ErrorAction Stop; Write-Output '   closed the test instance (open it yourself from the desktop when needed)' }
    catch { Write-Output ('   [WARN] could not close: ' + (San $_.Exception.Message)) }
}
Remove-Item -LiteralPath $outF, $errF -Force -ErrorAction SilentlyContinue

if (-not $p.HasExited -or $aliveSec -ge 6) {
    Write-Output ('== LigPlus.jar OPENS OK with ' + (San $javaExe))
    exit 0
}
Write-Output '== LigPlus.jar did NOT stay open - see err lines above'
exit 2
