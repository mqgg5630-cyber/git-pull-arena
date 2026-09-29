# t2_cleanup_exec.ps1 - round 25 task: EXECUTE the user-approved E: cleanup.
# User approval (2026-09-29): all safe caches + WSL vhdx compaction +
# leftover installer files. Order matters:
#   1. record E: free space
#   2. EMPTY the E: recycle bin first (approved)
#   3. move leftover installer files/folders to the RECYCLE BIN (recoverable)
#   4. conda clean --all -y   (official command, keeps every env)
#   5. npm cache clean / uv cache clean (official commands, fallback: delete)
#   6. wsl --shutdown + wsl --manage Ubuntu-24.04 --set-sparse true (lossless)
#   7. report E: free space after + what each step freed
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

function Get-FreeE {
    try {
        $dk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='E:'" -ErrorAction Stop
        return [math]::Round([double]$dk.FreeSpace / 1GB, 2)
    } catch { return -1 }
}

Write-Output '--- task t2 (cleanup): executing the approved cleanup ---'

$free0 = Get-FreeE
Write-Output ('E: free BEFORE: ' + $free0 + ' GB')

# ---------------------------------------------------- 1. empty recycle bin
Write-Output '--- step 1: empty the E: recycle bin ---'
try {
    Clear-RecycleBin -DriveLetter E -Force -ErrorAction Stop
    Write-Output '   OK: recycle bin on E: emptied'
} catch {
    Write-Output ('   [WARN] Clear-RecycleBin: ' + (San $_.Exception.Message))
}
$free1 = Get-FreeE
Write-Output ('   E: free now: ' + $free1 + ' GB (freed ' + [math]::Round($free1 - $free0, 2) + ' GB)')

# --------------------------------------- 2. leftover installers -> bin
Write-Output '--- step 2: leftover installers -> RECYCLE BIN (recoverable) ---'
Add-Type -AssemblyName Microsoft.VisualBasic
$ui = [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs
$rb = [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin

function Send-FileToBin {
    param([string]$p)
    if (Test-Path -LiteralPath $p) {
        try {
            $sz = [double](Get-Item -LiteralPath $p).Length
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($p, $ui, $rb)
            [Console]::WriteLine('   BIN  ' + (FmtB $sz) + '  ' + (San $p))
            return $sz
        } catch { [Console]::WriteLine('   [WARN] file: ' + (San $_.Exception.Message)) }
    } else { [Console]::WriteLine('   skip (absent): ' + (San $p)) }
    return [double]0
}

function Send-DirToBin {
    param([string]$p)
    if (Test-Path -LiteralPath $p) {
        try {
            $sz = [double]0
            foreach ($f in [System.IO.Directory]::EnumerateFiles($p, '*', [System.IO.SearchOption]::AllDirectories)) {
                try { $sz += [double]([System.IO.FileInfo]::new($f)).Length } catch { }
            }
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($p, $ui, $rb)
            [Console]::WriteLine('   BIN  ' + (FmtB $sz) + '  ' + (San $p) + ' (folder)')
            return $sz
        } catch { [Console]::WriteLine('   [WARN] dir: ' + (San $_.Exception.Message)) }
    } else { [Console]::WriteLine('   skip (absent): ' + (San $p)) }
    return [double]0
}

$binBytes = [double]0

# Downloads folders live under E:\Users\<name>\Downloads
$dlDirs = @()
try {
    foreach ($u in [System.IO.Directory]::EnumerateDirectories('E:\Users')) {
        $d = Join-Path $u 'Downloads'
        if (Test-Path -LiteralPath $d) { $dlDirs += $d }
    }
} catch { }
foreach ($d in $dlDirs) {
    $binBytes += Send-FileToBin (Join-Path $d 'BIOVIA_DS2025Client (1).exe')
    $binBytes += Send-FileToBin (Join-Path $d 'RStudio-2025.09.2-418.exe')
    $binBytes += Send-DirToBin (Join-Path $d 'WSA_2407.40000.4.0_x64_Release-Nightly-GApps-13.0')
}
$binBytes += Send-FileToBin 'E:\Program Files\Docker Desktop Installer.exe'
$binBytes += Send-FileToBin 'E:\QQ\versions\9.9.26-44725-9.9.35-52892.zip'
$binBytes += Send-FileToBin 'E:\xunlei\Origin2024\Setup\data2.cab'
$binBytes += Send-DirToBin 'E:\Program Files (x86)\WeGameInstaller'

# Office2024 setup (top-level dir name contains non-ASCII -> discover it)
try {
    foreach ($t in [System.IO.Directory]::EnumerateDirectories('E:\')) {
        $leaf = [System.IO.Path]::GetFileName($t.TrimEnd('\'))
        if ($leaf -like 'Office2024*') {
            foreach ($f in [System.IO.Directory]::EnumerateFiles($t)) {
                if ($f -like '*Setup.exe') {
                    try {
                        $sz = [double]([System.IO.FileInfo]::new($f)).Length
                        if ($sz -ge 200MB) { $binBytes += Send-FileToBin $f }
                    } catch { }
                }
            }
        }
    }
} catch { }

# WPS 2019 zip (~489 MB) somewhere in a top-level folder (name masked in receipts)
try {
    foreach ($t in [System.IO.Directory]::EnumerateDirectories('E:\')) {
        foreach ($f in [System.IO.Directory]::EnumerateFiles($t)) {
            $fn = [System.IO.Path]::GetFileName($f)
            if ($fn -like 'WPSOffice_*2019*.zip') {
                try {
                    $sz = [double]([System.IO.FileInfo]::new($f)).Length
                    if ($sz -ge 400MB) { $binBytes += Send-FileToBin $f }
                } catch { }
            }
        }
    }
} catch { }

Write-Output ('   total moved to recycle bin: ' + (FmtB $binBytes) + ' (still on disk until you empty the bin)')
$free2 = Get-FreeE
Write-Output ('   E: free now: ' + $free2 + ' GB')

# ------------------------------------------------------- 3. conda clean
Write-Output '--- step 3: conda clean --all -y ---'
$condaExe = 'E:\spider\Scripts\conda.exe'
if (-not (Test-Path -LiteralPath $condaExe)) { $condaExe = 'E:\spider\conda.exe' }
if (Test-Path -LiteralPath $condaExe) {
    $job = Start-Job -ScriptBlock { param($p) & $p clean --all -y 2>&1 | Out-String } -ArgumentList $condaExe
    if (Wait-Job $job -Timeout 900) {
        $out = (Receive-Job $job | Out-String)
        $tail = @($out -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -Last 12)
        foreach ($l in $tail) { Write-Output ('   ' + (San ([string]$l))) }
        Write-Output '   OK: conda clean finished'
    } else {
        Write-Output '   [WARN] conda clean TIMEOUT (900s) - killed'
    }
    Remove-Job $job -Force -ErrorAction SilentlyContinue
} else { Write-Output '   [WARN] conda.exe not found' }
$free3 = Get-FreeE
Write-Output ('   E: free now: ' + $free3 + ' GB (this step freed ' + [math]::Round($free3 - $free2, 2) + ' GB)')

# -------------------------------------------------------- 4. npm caches
Write-Output '--- step 4: npm caches (configured one + the old E:\npm-cache) ---'
$npmCmd = Get-Command npm -ErrorAction SilentlyContinue
if ($npmCmd) {
    $job = Start-Job -ScriptBlock { & npm cache clean --force 2>&1 | Out-String }
    if (Wait-Job $job -Timeout 300) {
        $o = (Receive-Job $job | Out-String)
        foreach ($l in @($o -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 5)) { Write-Output ('   ' + (San ([string]$l))) }
        Write-Output '   OK: npm cache clean finished (configured cache dir)'
    } else { Write-Output '   [WARN] npm cache clean TIMEOUT' }
    Remove-Job $job -Force -ErrorAction SilentlyContinue
}
if (Test-Path -LiteralPath 'E:\npm-cache') {
    try { Remove-Item -LiteralPath 'E:\npm-cache' -Recurse -Force -ErrorAction Stop; Write-Output '   OK: old cache E:\npm-cache deleted (1.47 GB, cache only)' }
    catch { Write-Output ('   [WARN] E:\npm-cache: ' + (San $_.Exception.Message)) }
}

# --------------------------------------------- 4b. E:\.cache (root cache)
Write-Output '--- step 4b: E:\.cache contents (generic cache dir) ---'
if (Test-Path -LiteralPath 'E:\.cache') {
    try {
        Get-ChildItem -LiteralPath 'E:\.cache' -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop } catch { Write-Output ('   [WARN] ' + (San ([string]$_.Name)) + ': ' + (San $_.Exception.Message)) }
        }
        Write-Output '   OK: E:\.cache emptied'
    } catch { Write-Output ('   [WARN] E:\.cache: ' + (San $_.Exception.Message)) }
} else { Write-Output '   (absent)' }

# --------------------------------- 4c. installers in top-level E:\Downloads
Write-Output '--- step 4c: big installers in E:\Downloads -> recycle bin ---'
$dlSwept = [double]0
if (Test-Path -LiteralPath 'E:\Downloads') {
    try {
        foreach ($f in [System.IO.Directory]::EnumerateFiles('E:\Downloads')) {
            $ext = [System.IO.Path]::GetExtension($f).ToLower()
            if ($ext -in @('.exe', '.msi', '.zip', '.7z', '.rar', '.iso')) {
                try {
                    $sz = [double]([System.IO.FileInfo]::new($f)).Length
                    if ($sz -ge 200MB) { $r = Send-FileToBin $f; $dlSwept += $r; $binBytes += $r }
                } catch { }
            }
        }
    } catch { }
    Write-Output ('   E:\Downloads installers >=200MB moved to bin: ' + (FmtB $dlSwept))
} else { Write-Output '   (absent)' }

$free4 = Get-FreeE
Write-Output ('   E: free now: ' + $free4 + ' GB')

# --------------------------------------------------------- 5. uv cache
Write-Output '--- step 5: uv cache ---'
$uvCmd = Get-Command uv -ErrorAction SilentlyContinue
$uvDone = $false
if ($uvCmd) {
    $job = Start-Job -ScriptBlock { & uv cache clean 2>&1 | Out-String }
    if (Wait-Job $job -Timeout 300) {
        $o = (Receive-Job $job | Out-String)
        foreach ($l in @($o -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 5)) { Write-Output ('   ' + (San ([string]$l))) }
        $uvDone = $true
    } else { Write-Output '   [WARN] uv cache clean TIMEOUT' }
    Remove-Job $job -Force -ErrorAction SilentlyContinue
}
if (-not $uvDone) {
    if (Test-Path -LiteralPath 'E:\mcp\uv-cache') {
        try { Remove-Item -LiteralPath 'E:\mcp\uv-cache' -Recurse -Force -ErrorAction Stop; Write-Output '   OK: E:\mcp\uv-cache deleted directly (cache only)' }
        catch { Write-Output ('   [WARN] direct delete: ' + (San $_.Exception.Message)) }
    }
}
$free5 = Get-FreeE
Write-Output ('   E: free now: ' + $free5 + ' GB')

# --------------------------------------------------- 6. WSL compaction
Write-Output '--- step 6: WSL vhdx sparse compaction (lossless) ---'
$vhdxPath = 'E:\WSL\Ubuntu-24.04\ext4.vhdx'
$before = [double]0
if (Test-Path -LiteralPath $vhdxPath) {
    try { $before = [double](Get-Item -LiteralPath $vhdxPath).Length } catch { }
    Write-Output ('   ext4.vhdx before: ' + (FmtB $before))
} else {
    Write-Output '   [WARN] ext4.vhdx not found at the known path'
}
try {
    $null = & wsl.exe --shutdown 2>&1
    Start-Sleep -Seconds 3
    Write-Output '   wsl --shutdown done'
} catch { Write-Output ('   [WARN] wsl --shutdown: ' + (San $_.Exception.Message)) }
$job = Start-Job -ScriptBlock { & wsl.exe --manage Ubuntu-24.04 --set-sparse true 2>&1 | Out-String }
if (Wait-Job $job -Timeout 900) {
    $o = (Receive-Job $job | Out-String)
    foreach ($l in @($o -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 8)) { Write-Output ('   ' + (San ([string]$l))) }
    Write-Output '   OK: set-sparse finished'
} else {
    Write-Output '   [WARN] set-sparse TIMEOUT (900s) - killed (vhdx left as-is)'
}
Remove-Job $job -Force -ErrorAction SilentlyContinue
if (Test-Path -LiteralPath $vhdxPath) {
    try {
        $after = [double](Get-Item -LiteralPath $vhdxPath).Length
        Write-Output ('   ext4.vhdx after: ' + (FmtB $after) + '  (saved ' + (FmtB ([double]($before - $after))) + ' if positive)')
    } catch { }
}

$freeEnd = Get-FreeE
Write-Output ('=== cleanup done. E: free ' + $free0 + ' GB -> ' + $freeEnd + ' GB (total freed on disk: ' + [math]::Round($freeEnd - $free0, 2) + ' GB; installers in the bin still count until emptied)')
Write-Output '=== NOT touched (for the user to decide later) ==='
Write-Output '   E:\Docker 27.4 GB - docker images/volumes; "docker system prune -a" frees most of it if you do not need the images'
Write-Output '   E:\WSL\Ubuntu-24.04 - if you already moved to Ubuntu-26.04, "wsl --unregister Ubuntu-24.04" frees all 145 GB (DELETES that distro!)'
Write-Output '   E:\Tencent Games\VALORANT 32.6 GB - uninstall via the game launcher if not played'
exit 0
