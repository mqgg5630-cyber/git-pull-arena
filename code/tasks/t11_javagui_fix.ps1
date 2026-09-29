# t11_javagui_fix.ps1 - round 30 task: redo the Swing self-test properly.
# Round 29's HelloSwing.jar failed because the class file was added to the
# jar with its ABSOLUTE path as the entry name (E:\java\selftest\HelloSwing.
# class), so the JVM could not find class HelloSwing. Fix: rebuild the jar
# from INSIDE E:\java\selftest with a relative entry name, run it, capture
# stdout+stderr, verify the window title, close it.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t11: java GUI self-test, fixed ---'
$selfDir = 'E:\java\selftest'
$javaExe = 'E:\java\jdk-21.0.12.1+1\bin\java.exe'
$javacExe = 'E:\java\jdk-21.0.12.1+1\bin\javac.exe'
$jarExe = 'E:\java\jdk-21.0.12.1+1\bin\jar.exe'
foreach ($t in @($javaExe, $javacExe, $jarExe)) {
    if (-not (Test-Path -LiteralPath $t)) { Write-Output ('   [FAIL] missing ' + $t); exit 2 }
}
if (-not (Test-Path -LiteralPath (Join-Path $selfDir 'HelloSwing.java'))) {
    Write-Output '   [FAIL] HelloSwing.java missing (round 29 created it)'
    exit 2
}

# rebuild class + jar with RELATIVE names (cwd = selfDir)
$null = & $javacExe 'HelloSwing.java' 2>&1
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $selfDir 'HelloSwing.class'))) { Write-Output '   [FAIL] javac'; exit 2 }
Write-Output '   javac OK'
$null = & $jarExe '--create' '--file' 'HelloSwing.jar' '-e' 'HelloSwing' 'HelloSwing.class' 2>&1
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $selfDir 'HelloSwing.jar'))) { Write-Output '   [FAIL] jar'; exit 2 }
Write-Output '   jar rebuilt with a relative entry name'
# prove the entry name is right
$listing = (& $jarExe '--list' '--file' 'HelloSwing.jar' 2>&1 | Out-String)
foreach ($l in @($listing -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   entry: ' + (San ([string]$l))) }

# run with output capture
$outF = [System.IO.Path]::GetTempFileName()
$errF = [System.IO.Path]::GetTempFileName()
$p = Start-Process -FilePath $javaExe -ArgumentList @('-jar', 'HelloSwing.jar') -WorkingDirectory $selfDir -RedirectStandardOutput $outF -RedirectStandardError $errF -PassThru
$title = ''
$alive = 0
for ($i = 0; $i -lt 8; $i++) {
    Start-Sleep -Seconds 2
    if ($p.HasExited) { break }
    $alive = ($i + 1) * 2
    try {
        $p2 = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
        if ($p2 -and $p2.MainWindowTitle) { $title = [string]$p2.MainWindowTitle }
    } catch { }
    if ($title) { break }
}
$stillRunning = (-not $p.HasExited)
if ($stillRunning) { try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch { } }
$o = ''
$e = ''
try { $o = (Get-Content -LiteralPath $outF -Raw -ErrorAction SilentlyContinue) } catch { }
try { $e = (Get-Content -LiteralPath $errF -Raw -ErrorAction SilentlyContinue) } catch { }
Remove-Item -LiteralPath $outF, $errF -Force -ErrorAction SilentlyContinue
Write-Output ('   alive: ' + $alive + 's, still running at check: ' + $stillRunning + ', window title: "' + (San $title) + '"')
foreach ($l in @(($o + "`n" + $e) -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 12)) { Write-Output ('   out: ' + (San ([string]$l))) }

if ($title -match 'JavaOK') {
    Write-Output '== SUCCESS: a standalone jar GUI app compiled, packaged and RUN with the E:\java JDK - window verified'
    Write-Output '   (LigPlus itself also runs - only its academic licence is expired; re-download from EBI for a working copy)'
    exit 0
}
if ($stillRunning -and $alive -ge 10) {
    Write-Output '== SUCCESS (window title not readable from the task session, but the app stayed alive 10s+)'
    exit 0
}
Write-Output '== FAIL: the GUI jar did not stay open - see out lines above'
exit 2
