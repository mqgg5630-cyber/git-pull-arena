# t5_cleanup_fix.ps1 - round 26 task: finish what round 25 could not.
# Round 25 freed 6.4 GB (conda, npm caches, E:\.cache) but hit the 30-min
# watcher cap inside the uv-cache delete (PowerShell Remove-Item is far too
# slow for 62k files), so the WSL compaction never ran, and a function bug
# (Write-Output leaking into return values) swallowed the installer-to-bin
# logging. This task:
#   1. reports which installer targets are gone (in the bin) vs still present
#   2. reports how much the E: recycle bin holds now
#   3. finishes the uv cache delete with native rd /s /q (fast)
#   4. runs the WSL vhdx sparse compaction (lossless) LAST with a big budget
# The recycle bin is NOT emptied here - the installers stay recoverable.
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

function Get-FreeE {
    try {
        $dk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='E:'" -ErrorAction Stop
        return [math]::Round([double]$dk.FreeSpace / 1GB, 2)
    } catch { return -1 }
}

Write-Output '--- task t5: finish the cleanup (round 25 leftovers) ---'

$free0 = Get-FreeE
Write-Output ('E: free now: ' + $free0 + ' GB (round 25 started at 233.98 GB)')

# ------------------------- 1. what happened to the installer targets?
Write-Output '--- installer targets: gone (in recycle bin) vs present ---'
$targets = @()
try {
    foreach ($u in [System.IO.Directory]::EnumerateDirectories('E:\Users')) {
        $d = Join-Path $u 'Downloads'
        if (Test-Path -LiteralPath $d) {
            $targets += (Join-Path $d 'BIOVIA_DS2025Client (1).exe')
            $targets += (Join-Path $d 'RStudio-2025.09.2-418.exe')
            $targets += (Join-Path $d 'WSA_2407.40000.4.0_x64_Release-Nightly-GApps-13.0')
        }
    }
} catch { }
$targets += 'E:\Program Files\Docker Desktop Installer.exe'
$targets += 'E:\QQ\versions\9.9.26-44725-9.9.35-52892.zip'
$targets += 'E:\xunlei\Origin2024\Setup\data2.cab'
$targets += 'E:\Program Files (x86)\WeGameInstaller'
$gone = 0
$present = 0
foreach ($t in $targets) {
    if (Test-Path -LiteralPath $t) { Write-Output ('   PRESENT ' + (San $t)); $present++ }
    else { Write-Output ('   gone    ' + (San $t)); $gone++ }
}
Write-Output ('   summary: ' + $gone + ' gone (moved to the recycle bin by round 25), ' + $present + ' still present')

# E:\Downloads big installers
if (Test-Path -LiteralPath 'E:\Downloads') {
    $bigLeft = 0
    try {
        foreach ($f in [System.IO.Directory]::EnumerateFiles('E:\Downloads')) {
            $ext = [System.IO.Path]::GetExtension($f).ToLower()
            if ($ext -in @('.exe', '.msi', '.zip', '.7z', '.rar', '.iso')) {
                try {
                    $sz = [double]([System.IO.FileInfo]::new($f)).Length
                    if ($sz -ge 200MB) { $bigLeft++; Write-Output ('   DL still present: ' + (FmtB $sz) + '  ' + (San $f)) }
                } catch { }
            }
        }
    } catch { }
    Write-Output ('   E:\Downloads installers >=200MB still present: ' + $bigLeft)
}

# ------------------------------------------- 2. recycle bin size on E:
Write-Output '--- E: recycle bin content (recoverable) ---'
$binBytes = [double]0
$binFiles = [long]0
try {
    $stack = New-Object System.Collections.Stack
    $stack.Push('E:\$RECYCLE.BIN')
    while ($stack.Count -gt 0) {
        $dir = [string]$stack.Pop()
        try { foreach ($sd in [System.IO.Directory]::EnumerateDirectories($dir)) { $stack.Push($sd) } } catch { }
        try {
            foreach ($f in [System.IO.Directory]::EnumerateFiles($dir)) {
                try { $binBytes += [double]([System.IO.FileInfo]::new($f)).Length; $binFiles++ } catch { }
            }
        } catch { }
    }
    Write-Output ('   E:\$RECYCLE.BIN now holds: ' + (FmtB $binBytes) + ' / ' + $binFiles + ' files (empty the bin in Explorer to free it)')
} catch { Write-Output ('   [WARN] bin measure: ' + (San $_.Exception.Message)) }

# --------------------------------------------- 3. finish uv cache delete
Write-Output '--- uv cache: finish with native rd /s /q ---'
if (Test-Path -LiteralPath 'E:\mcp\uv-cache') {
    $p = Start-Process -FilePath "$env:ComSpec" -ArgumentList @('/c', 'rd /s /q "E:\mcp\uv-cache"') -NoNewWindow -PassThru
    if ($p.WaitForExit(600000)) {
        if ($p.ExitCode -eq 0 -or -not (Test-Path -LiteralPath 'E:\mcp\uv-cache')) { Write-Output ('   OK: uv cache removed (exit ' + $p.ExitCode + ')') }
        else { Write-Output ('   [WARN] rd exit ' + $p.ExitCode + ' - dir still present') }
    } else {
        try { $null = cmd /c ("taskkill /F /T /PID " + $p.Id + " 2>&1") } catch { }
        Write-Output '   [WARN] rd /s /q TIMEOUT (600s) - uv cache partially deleted'
    }
} else {
    Write-Output '   OK: E:\mcp\uv-cache already gone'
}
$free1 = Get-FreeE
Write-Output ('   E: free now: ' + $free1 + ' GB (this step freed ' + [math]::Round($free1 - $free0, 2) + ' GB)')

# ------------------------------------------- 4. WSL sparse compaction
Write-Output '--- WSL vhdx sparse compaction (lossless, runs LAST) ---'
$vhdxPath = 'E:\WSL\Ubuntu-24.04\ext4.vhdx'
$before = [double]0
if (Test-Path -LiteralPath $vhdxPath) {
    try { $before = [double](Get-Item -LiteralPath $vhdxPath).Length } catch { }
    Write-Output ('   ext4.vhdx before: ' + (FmtB $before))
} else {
    Write-Output '   [WARN] ext4.vhdx not found'
}
try {
    $null = & wsl.exe --shutdown 2>&1
    Start-Sleep -Seconds 3
    Write-Output '   wsl --shutdown done'
} catch { Write-Output ('   [WARN] wsl --shutdown: ' + (San $_.Exception.Message)) }
$p2 = Start-Process -FilePath 'wsl.exe' -ArgumentList @('--manage', 'Ubuntu-24.04', '--set-sparse', 'true') -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\wsl_sparse_out.txt" -RedirectStandardError "$env:TEMP\wsl_sparse_err.txt"
if ($p2.WaitForExit(900000)) {
    foreach ($lf in @("$env:TEMP\wsl_sparse_out.txt", "$env:TEMP\wsl_sparse_err.txt")) {
        if (Test-Path -LiteralPath $lf) {
            foreach ($l in @(Get-Content -LiteralPath $lf -ErrorAction SilentlyContinue | Where-Object { $_ -match '\S' } | Select-Object -First 5)) { Write-Output ('   ' + (San ([string]$l))) }
            Remove-Item -LiteralPath $lf -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Output ('   OK: set-sparse finished (exit ' + $p2.ExitCode + ')')
} else {
    try { $null = cmd /c ("taskkill /F /T /PID " + $p2.Id + " 2>&1") } catch { }
    Write-Output '   [WARN] set-sparse TIMEOUT (900s) - killed'
}
if (Test-Path -LiteralPath $vhdxPath) {
    try {
        $after = [double](Get-Item -LiteralPath $vhdxPath).Length
        Write-Output ('   ext4.vhdx after: ' + (FmtB $after) + '  (delta ' + (FmtB ([double]($after - $before))) + '; negative = space given back)')
    } catch { }
}

$freeEnd = Get-FreeE
Write-Output ('=== round 26 cleanup finish: E: free ' + $free0 + ' GB -> ' + $freeEnd + ' GB now')
Write-Output ('=== since round 25 started (233.98 GB): total freed on disk ' + [math]::Round($freeEnd - 233.98, 2) + ' GB, plus ' + (FmtB $binBytes) + ' in the recycle bin')
exit 0
