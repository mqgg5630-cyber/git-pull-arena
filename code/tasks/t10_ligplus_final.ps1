# t10_ligplus_final.ps1 - round 29 task: close out the LigPlus question.
# Round 28 proved: 4 LigPlus.jar copies exist and ALL are the same size
# (1,030,898 B = v2.2.9, build 13 Sep 2024) - there is NO newer version on
# the machine, and the license is expired (user-confirmed).
#
# This task:
#   1. sha256 all 4 jars (prove they are the same file)
#   2. run ONE of them with FULL output capture (document the exact expiry
#      message, 50 lines) - output via [Console]::WriteLine, no function
#      pipeline pollution this time
#   3. look for a licence file in the LigPlus lib dir (name + mtime only)
#   4. REMOVE the expired copy the user pointed at: E:\1result\LigPlus.jar
#      -> recycle bin (recoverable). The canonical install dir
#      E:\LigPlus\LigPlus\ is KEPT - the new version will go there.
#      The WeChat copy is chat history - untouched.
#   5. prove the java environment end to end: compile a small Swing GUI app
#      with javac, pack it as a jar, run it, verify the window title shows,
#      close it. The jar stays at E:\java\selftest\HelloSwing.jar.
#
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t10: LigPlus final - hashes, expiry proof, remove expired copy, java self-test ---'

$javaExe = 'E:\java\jdk-21.0.12.1+1\bin\java.exe'
$javacExe = 'E:\java\jdk-21.0.12.1+1\bin\javac.exe'
$jarExe = 'E:\java\jdk-21.0.12.1+1\bin\jar.exe'
foreach ($t in @($javaExe, $javacExe, $jarExe)) {
    if (-not (Test-Path -LiteralPath $t)) { Write-Output ('   [FAIL] missing ' + $t); exit 2 }
}
Write-Output '   JDK 21 tools present (java/javac/jar)'

# ------------------------------------------------------------- 1. hashes
Write-Output '--- sha256 of every LigPlus.jar copy ---'
$copies = @('E:\LigPlus\LigPlus\LigPlus.jar', 'E:\1result\LigPlus.jar', 'E:\LigPlus\LigPlus\pdb_collection\LigPlus.jar')
# the WeChat copy path contains a non-ASCII-safe username; discover it
try {
    $wx = @(Get-ChildItem -LiteralPath 'E:\xwechat_files' -Directory -ErrorAction SilentlyContinue | Select-Object -First 3)
    foreach ($w in $wx) {
        $hits = @(Get-ChildItem -LiteralPath $w.FullName -Recurse -Depth 4 -File -Filter 'LigPlus.jar' -ErrorAction SilentlyContinue | Select-Object -First 2)
        foreach ($h in $hits) { $copies += $h.FullName }
    }
} catch { }
$hashes = @{}
foreach ($c in $copies) {
    if (Test-Path -LiteralPath $c) {
        try {
            $h = (Get-FileHash -LiteralPath $c -Algorithm SHA256).Hash.Substring(0, 16).ToLowerInvariant()
            $hashes[$c] = $h
            Write-Output ('   ' + $h + '  ' + (San $c))
        } catch { Write-Output ('   hash fail: ' + (San $c)) }
    } else {
        Write-Output ('   absent: ' + (San $c))
    }
}
$uniq = @($hashes.Values | Select-Object -Unique)
Write-Output ('   unique builds on the machine: ' + $uniq.Count + $(if ($uniq.Count -eq 1) { '  (all copies are the SAME build - no newer version exists here)' } else { '  (different builds exist!)' }))

# ------------------------------------------------- 2. full run output once
Write-Output '--- one full LigPlus run (documenting why it exits) ---'
$probe = 'E:\LigPlus\LigPlus\LigPlus.jar'
if (Test-Path -LiteralPath $probe) {
    $outF = [System.IO.Path]::GetTempFileName()
    $errF = [System.IO.Path]::GetTempFileName()
    $p = Start-Process -FilePath $javaExe -ArgumentList @('-jar', ('"' + $probe + '"')) -WorkingDirectory (Split-Path -Parent $probe) -RedirectStandardOutput $outF -RedirectStandardError $errF -PassThru
    $alive = 0
    for ($i = 0; $i -lt 10; $i++) {
        Start-Sleep -Seconds 2
        if ($p.HasExited) { break }
        $alive = ($i + 1) * 2
    }
    if (-not $p.HasExited) { try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch { } }
    [Console]::WriteLine('   alive ' + $alive + 's, exited=' + (-not $p.HasExited))
    $o = ''
    $e = ''
    try { $o = (Get-Content -LiteralPath $outF -Raw -ErrorAction SilentlyContinue) } catch { }
    try { $e = (Get-Content -LiteralPath $errF -Raw -ErrorAction SilentlyContinue) } catch { }
    Remove-Item -LiteralPath $outF, $errF -Force -ErrorAction SilentlyContinue
    $n = 0
    foreach ($l in @((($o + "`n" + $e) -split "`r?`n") | Where-Object { $_ -match '\S' })) {
        if ($n -ge 50) { Write-Output '      ... (cut)'; break }
        Write-Output ('      ' + (San ([string]$l)))
        $n++
    }
}

# --------------------------------------------------- 3. licence file peek
Write-Output '--- licence-ish files in the LigPlus install ---'
$licRoot = 'E:\LigPlus\LigPlus'
try {
    $lics = @(Get-ChildItem -LiteralPath $licRoot -Recurse -Depth 2 -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)licen[cs]e|\.key$|\.lic$' } | Select-Object -First 6)
    if ($lics.Count -eq 0) { Write-Output '   (no license file found - the expiry is likely compiled into the jar)' }
    foreach ($lf in $lics) { Write-Output ('   ' + (San $lf.FullName) + '  (' + $lf.Length + ' B, ' + $lf.LastWriteTime.ToString('yyyy-MM-dd') + ')') }
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }

# --------------------------------------------- 4. remove the expired copy
Write-Output '--- remove the expired copy (E:\1result\LigPlus.jar -> recycle bin) ---'
$old = 'E:\1result\LigPlus.jar'
if (Test-Path -LiteralPath $old) {
    Add-Type -AssemblyName Microsoft.VisualBasic
    try {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($old, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs, [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
        Write-Output '   REMOVED to the recycle bin: E:\1result\LigPlus.jar (recoverable)'
        Write-Output '   E:\1result\lib was left in place (its folder, harmless)'
    } catch {
        Write-Output ('   [WARN] could not remove: ' + (San $_.Exception.Message))
    }
} else {
    Write-Output '   already gone'
}
Write-Output '   KEPT: E:\LigPlus\LigPlus\ (canonical install - put the NEW version here)'
Write-Output '   KEPT: the WeChat copy (it is part of chat history)'

# ------------------------------- 5. java end-to-end self test (Swing GUI)
Write-Output '--- java self-test: compile + jar + run a Swing GUI app ---'
$selfDir = 'E:\java\selftest'
try { New-Item -ItemType Directory -Force -Path $selfDir | Out-Null } catch { Write-Output ('   [FAIL] mkdir: ' + (San $_.Exception.Message)); exit 2 }
$src = @'
import javax.swing.*;
public class HelloSwing {
    public static void main(String[] a) throws Exception {
        JFrame f = new JFrame("JavaOK-E-drive");
        f.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        f.add(new JLabel("JDK 21 on E: works", SwingConstants.CENTER));
        f.setSize(360, 160);
        f.setLocationRelativeTo(null);
        f.setVisible(true);
    }
}
'@
$srcFile = Join-Path $selfDir 'HelloSwing.java'
[System.IO.File]::WriteAllText($srcFile, $src, (New-Object System.Text.UTF8Encoding($false)))
Write-Output '   wrote HelloSwing.java'
$null = & $javacExe (Join-Path $selfDir 'HelloSwing.java') 2>&1
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $selfDir 'HelloSwing.class'))) {
    Write-Output '   [FAIL] javac did not produce HelloSwing.class'
    exit 2
}
Write-Output '   javac OK'
$jarPath = Join-Path $selfDir 'HelloSwing.jar'
$clsPath = Join-Path $selfDir 'HelloSwing.class'
$null = & $jarExe '--create' "--file=$jarPath" '-e' 'HelloSwing' $clsPath 2>&1
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $jarPath)) {
    Write-Output '   [FAIL] jar packaging failed'
    exit 2
}
Write-Output '   jar packaged: E:\java\selftest\HelloSwing.jar'
$p2 = Start-Process -FilePath $javaExe -ArgumentList @('-jar', ('"' + (Join-Path $selfDir 'HelloSwing.jar') + '"')) -WorkingDirectory $selfDir -PassThru
$title = ''
$alive2 = 0
for ($i = 0; $i -lt 8; $i++) {
    Start-Sleep -Seconds 2
    if ($p2.HasExited) { break }
    $alive2 = ($i + 1) * 2
    try {
        $p3 = Get-Process -Id $p2.Id -ErrorAction SilentlyContinue
        if ($p3 -and $p3.MainWindowTitle) { $title = [string]$p3.MainWindowTitle }
    } catch { }
    if ($title) { break }
}
if (-not $p2.HasExited) {
    try { Stop-Process -Id $p2.Id -Force -ErrorAction SilentlyContinue } catch { }
}
if ($title -match 'JavaOK') {
    Write-Output ('   WINDOW OPENED: title="' + (San $title) + '" (alive ' + $alive2 + 's) - closed by the test')
    Write-Output '== JAVA ENVIRONMENT FULLY PROVEN: javac compile + jar pack + GUI run, all from E:\java'
} else {
    Write-Output ('   [WARN] no window title captured (alive ' + $alive2 + 's, exited=' + (-not $p2.HasExited) + ')')
    Write-Output '   the jar still lives at E:\java\selftest\HelloSwing.jar - run it by hand to see'
}

Write-Output '--- how to get a WORKING LigPlot+ (manual, free academic licence) ---'
Write-Output '   1. open https://www.ebi.ac.uk/thornton-srv/software/LigPlus/'
Write-Output '   2. fill the academic licence form (free) and download the CURRENT zip'
Write-Output '   3. tell the agent where you saved it - the next round installs it to E:\LigPlus and tests it'
exit 0
