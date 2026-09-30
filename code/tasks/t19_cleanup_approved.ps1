# t19_cleanup_approved.ps1 - round 37 task: execute the user-approved
# cleanup (2026-09-30): old installers (~5.5 GB), old research data
# (~1.6 GB), long-unused folders (~1.5 GB), every OLD LigPlus.jar copy
# (hash-identified, including the WeChat one), and replace the desktop
# LigPlus shortcut with one that opens the NEW v2.3.2 install via the
# E:\java JDK. Everything removable goes to the RECYCLE BIN first.
# The uv cache is NOT touched (user still needs the MCP tools).
# Windows PowerShell 5.1, ASCII-only (Chinese folder names are built from
# [char] codes so this file stays ASCII).

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

Add-Type -AssemblyName Microsoft.VisualBasic
$ui = [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs
$rb = [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin

$binTotal = [double]0
function Bin-File {
    param([string]$p)
    if (Test-Path -LiteralPath $p) {
        try {
            $sz = [double](Get-Item -LiteralPath $p).Length
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($p, $ui, $rb)
            $script:binTotal += $sz
            Write-Output ('   BIN  ' + (FmtB $sz).PadLeft(11) + '  ' + (San $p))
            return $sz
        } catch { Write-Output ('   [WARN] ' + (San $p) + ' : ' + (San $_.Exception.Message)) }
    }
    return [double]0
}
function Bin-Dir {
    param([string]$p)
    if (Test-Path -LiteralPath $p) {
        try {
            $sz = [double]0
            foreach ($f in [System.IO.Directory]::EnumerateFiles($p, '*', [System.IO.SearchOption]::AllDirectories)) {
                try { $sz += [double]([System.IO.FileInfo]::new($f)).Length } catch { }
            }
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($p, $ui, $rb)
            $script:binTotal += $sz
            Write-Output ('   BIN  ' + (FmtB $sz).PadLeft(11) + '  ' + (San $p) + ' (folder)')
            return $sz
        } catch { Write-Output ('   [WARN] ' + (San $p) + ' : ' + (San $_.Exception.Message)) }
    }
    return [double]0
}

Write-Output '--- task t19: approved cleanup (recycle bin first) ---'

# ---------------------------------------------------- download dirs
$dl = @()
try {
    foreach ($u in [System.IO.Directory]::EnumerateDirectories('E:\Users')) {
        $d = Join-Path $u 'Downloads'
        if (Test-Path -LiteralPath $d) { $dl += $d }
    }
} catch { }

# --------------------------------------------- 1. old installers
Write-Output '--- 1. old installers ---'
foreach ($d in $dl) {
    Bin-File (Join-Path $d 'BIOVIA_DS2025Client.exe')
    Bin-File (Join-Path $d 'AmberTools24.tar.bz2')
    Bin-File (Join-Path $d 'Positron-2025.03.0-116-UserSetup.exe')
    Bin-File (Join-Path $d 'Cytoscape_3_10_3_windows_64bit.exe')
    Bin-File (Join-Path $d 'TencentMeeting_0300000000_3.33.3.413_x86_64.publish.officialwebsite.exe')
    Bin-File (Join-Path $d 'jdk-24_windows-x64_bin.exe')
    Bin-File (Join-Path $d 'jdk-23_windows-x64_bin.exe')
    Bin-File (Join-Path $d 'Sheas-Cealer-Scd-X64-Zip-1.1.4.zip')
    Bin-Dir  (Join-Path $d 'Sheas-Cealer-Scd-X64-Zip-1.1.4')
    Bin-Dir  (Join-Path $d 'DiscoveryS_206427')
    # the extracted-folder-named-like-a-zip cases (found in the survey)
    Bin-Dir  (Join-Path $d 'fuhewu.zip')
    Bin-Dir  (Join-Path $d 'sh.zip')
    Bin-File (Join-Path $d 'Sham-BWM_ileum_3_1.msf')
    # teaching mp4 inside the YoutubeDownloader folder
    $yd = Join-Path $d 'YoutubeDownloader.win-x64'
    if (Test-Path -LiteralPath $yd) {
        try {
            foreach ($f in [System.IO.Directory]::EnumerateFiles($yd, '*.mp4')) {
                try {
                    if (([System.IO.FileInfo]::new($f)).Length -ge 200MB) { Bin-File $f }
                } catch { }
            }
        } catch { }
    }
}
# VMware installer in E:\xunlei (name has a Chinese suffix - match by prefix)
try {
    foreach ($f in [System.IO.Directory]::EnumerateFiles('E:\xunlei')) {
        $fn = [System.IO.Path]::GetFileName($f)
        if ($fn -like 'VMware-Workstation-Lite*' -and $fn -like '*.exe') { Bin-File $f }
    }
} catch { }
# Adobe Illustrator 2020 zip at E: root (Chinese suffix - prefix match)
try {
    foreach ($f in [System.IO.Directory]::EnumerateFiles('E:\')) {
        $fn = [System.IO.Path]::GetFileName($f)
        if ($fn -like 'Adobe Illustrator 2020*' -and $fn -like '*.zip') { Bin-File $f }
    }
} catch { }

# --------------------------------------------- 2. old research data
Write-Output '--- 2. old research data ---'
Bin-File 'E:\bert.bin'

# --------------------------------------------- 3. long-unused folders
Write-Output '--- 3. long-unused folders ---'
# Chinese names built from char codes to keep this file ASCII:
#   xue xi (study) / xun lei xia zai (thunder downloads) / gong ju xiang (toolbox)
$cStudy = [string][char]0x5B66 + [string][char]0x4E60
$cThunder = [string][char]0x8FC5 + [string][char]0x96F7 + [string][char]0x4E0B + [string][char]0x8F7D
$cToolbox = [string][char]0x5DE5 + [string][char]0x5177 + [string][char]0x7BB1
foreach ($t in @('vit-pytorch-main', 'Vivaldi')) { Bin-Dir ('E:\' + $t) }
Bin-Dir ('E:\' + $cStudy)
Bin-Dir ('E:\' + $cThunder)
Bin-Dir ('E:\wsa' + $cToolbox)

# --------------------------------------------- 4. old LigPlus jars
Write-Output '--- 4. old LigPlus copies (hash check) ---'
$oldHash = '8E97C34D'
$kept = 'E:\LigPlus\LigPlus'
try {
    $jars = @(Get-ChildItem -LiteralPath 'E:\' -Recurse -Depth 6 -File -Filter 'LigPlus.jar' -ErrorAction SilentlyContinue)
    foreach ($j in $jars) {
        $inside = $j.FullName.StartsWith($kept, [System.StringComparison]::OrdinalIgnoreCase)
        $h = ''
        try { $h = (Get-FileHash -LiteralPath $j.FullName -Algorithm SHA256).Hash.Substring(0, 8) } catch { }
        if ($inside) {
            Write-Output ('   keep (new install): ' + (San $j.FullName) + ' hash ' + $h)
            continue
        }
        if ($h -eq $oldHash) { Bin-File $j.FullName }
        else { Write-Output ('   keep (different build, hash ' + $h + '): ' + (San $j.FullName)) }
    }
} catch { Write-Output ('   [WARN] jar scan: ' + (San $_.Exception.Message)) }

# --------------------------------------------- 5. desktop shortcut
Write-Output '--- 5. desktop shortcut for the NEW LigPlot+ ---'
$desktop = [Environment]::GetFolderPath('Desktop')
$sh = New-Object -ComObject WScript.Shell
# remove old shortcuts that point at the old LigPlus locations
try {
    foreach ($lnk in @(Get-ChildItem -LiteralPath $desktop -Filter '*.lnk' -ErrorAction SilentlyContinue)) {
        $s = $sh.CreateShortcut($lnk.FullName)
        $tp = [string]$s.TargetPath
        $ar = [string]$s.Arguments
        if (($tp + ' ' + $ar) -match '(?i)ligplus|ligplot|1result') {
            Write-Output ('   old shortcut found: ' + (San $lnk.Name) + ' -> ' + (San $tp) + ' ' + (San $ar))
            Bin-File $lnk.FullName
        }
    }
} catch { Write-Output ('   [WARN] shortcut scan: ' + (San $_.Exception.Message)) }
# create the new one
$newLnk = Join-Path $desktop 'LigPlot+.lnk'
try {
    $s2 = $sh.CreateShortcut($newLnk)
    $s2.TargetPath = 'E:\java\jdk-21.0.12.1+1\bin\javaw.exe'
    $s2.Arguments = '-jar "E:\LigPlus\LigPlus\LigPlus.jar"'
    $s2.WorkingDirectory = 'E:\LigPlus\LigPlus'
    $s2.IconLocation = 'E:\java\jdk-21.0.12.1+1\bin\javaw.exe,0'
    $s2.Description = 'LigPlot+ v2.3.2 (JDK 21 on E:)'
    $s2.Save()
    Write-Output ('   CREATED: ' + (San $newLnk))
    # verify it back
    $chk = $sh.CreateShortcut($newLnk)
    Write-Output ('   verify: target=' + (San ([string]$chk.TargetPath)) + ' args=' + (San ([string]$chk.Arguments)))
} catch {
    Write-Output ('   [WARN] could not create shortcut: ' + (San $_.Exception.Message))
    # fallback: a double-click cmd on the desktop
    try {
        $cmd = Join-Path $desktop 'LigPlot+.cmd'
        [System.IO.File]::WriteAllText($cmd, "@`"E:\java\jdk-21.0.12.1+1\bin\javaw.exe`" -jar `"`"%~dp0..\LigPlus\LigPlus\LigPlus.jar`"`"`r`n", (New-Object System.Text.UTF8Encoding($false)))
        Write-Output ('   fallback CREATED: ' + (San $cmd))
    } catch { }
}

# ------------------------------------------------------------- total
try {
    $rbSize = [double]0
    $stack = New-Object System.Collections.Stack
    $stack.Push('E:\$RECYCLE.BIN')
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stack.Count -gt 0 -and $sw.Elapsed.TotalSeconds -lt 30) {
        $d2 = [string]$stack.Pop()
        try { foreach ($sd in [System.IO.Directory]::EnumerateDirectories($d2)) { $stack.Push($sd) } } catch { }
        try { foreach ($f in [System.IO.Directory]::EnumerateFiles($d2)) { try { $rbSize += [double]([System.IO.FileInfo]::new($f)).Length } catch { } } } catch { }
    }
    Write-Output ('=== moved ' + (FmtB $binTotal) + ' to the recycle bin this round; the bin now holds ' + (FmtB $rbSize) + ' total')
    Write-Output '=== empty the bin in Explorer when you are happy (that is the final +GB)'
} catch { }
exit 0
