# t4_cleanup_dryrun.ps1 - round 24 task: measure EXACTLY what the safe
# cleanup commands would free, without deleting anything.
#   - conda:  E:\spider\Scripts\conda.exe clean --all --dry-run
#   - npm:    cache location + size (no verify, no clean)
#   - uv:     cache dir + size
#   - recycle bin on E: size
#   - WSL distro state (for the 145 GB ext4.vhdx decision)
# READ-ONLY.
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

function Get-DirSize {
    param([string]$root, [int]$budgetSec)
    if (-not (Test-Path -LiteralPath $root)) { return $null }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $bytes = [double]0
    $files = [long]0
    $partial = $false
    $stack = New-Object System.Collections.Stack
    $stack.Push($root)
    while ($stack.Count -gt 0) {
        if ($sw.Elapsed.TotalSeconds -gt $budgetSec) { $partial = $true; break }
        $dir = [string]$stack.Pop()
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
                try { $bytes += [double]([System.IO.FileInfo]::new($f)).Length; $files++ } catch { }
            }
        } catch { }
    }
    return @{ bytes = $bytes; files = $files; partial = $partial }
}

Write-Output '--- task t4: cleanup dry-run (READ-ONLY, nothing is deleted) ---'

try {
    $dk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='E:'" -ErrorAction Stop
    Write-Output ('E: free BEFORE any cleanup: ' + ('{0:N1}' -f ([double]$dk.FreeSpace / 1GB)) + ' GB')
} catch { }

# ------------------------------------------------------------ conda
Write-Output '--- conda clean --all --dry-run ---'
$condaExe = 'E:\spider\Scripts\conda.exe'
if (-not (Test-Path -LiteralPath $condaExe)) { $condaExe = 'E:\spider\conda.exe' }
if (Test-Path -LiteralPath $condaExe) {
    $job = Start-Job -ScriptBlock { param($p) & $p clean --all --dry-run 2>&1 | Out-String } -ArgumentList $condaExe
    if (Wait-Job $job -Timeout 240) {
        $out = (Receive-Job $job | Out-String)
        $lines = @($out -split "`r?`n" | Where-Object { $_ -match '\S' })
        Write-Output ('   conda dry-run lines: ' + $lines.Count)
        foreach ($l in @($lines | Select-Object -Last 25)) { Write-Output ('   ' + (San ([string]$l))) }
    } else {
        Write-Output '   conda dry-run TIMEOUT (240s)'
    }
    Remove-Job $job -Force -ErrorAction SilentlyContinue
} else {
    Write-Output '   conda.exe not found under E:\spider'
}
$pkgs = Get-DirSize -root 'E:\spider\pkgs' -budgetSec 60
if ($pkgs) { Write-Output ('   E:\spider\pkgs on disk: ' + (FmtB ([double]$pkgs.bytes)) + ' / ' + $pkgs.files + ' files' + $(if ($pkgs.partial) { ' (partial)' } else { '' })) }

# ------------------------------------------------------------ npm
Write-Output '--- npm cache ---'
$npmCmd = Get-Command npm -ErrorAction SilentlyContinue
if ($npmCmd) {
    Write-Output ('   npm at: ' + (San ([string]$npmCmd.Source)))
    try {
        $cacheDir = (& npm config get cache 2>$null | Out-String).Trim()
        if ($cacheDir) { Write-Output ('   npm cache dir: ' + (San $cacheDir)) }
    } catch { }
} else {
    Write-Output '   npm not on PATH'
}
$npmCache = Get-DirSize -root 'E:\npm-cache' -budgetSec 60
if ($npmCache) { Write-Output ('   E:\npm-cache on disk: ' + (FmtB ([double]$npmCache.bytes)) + ' / ' + $npmCache.files + ' files' + $(if ($npmCache.partial) { ' (partial)' } else { '' })) }

# ------------------------------------------------------------ uv
Write-Output '--- uv cache ---'
$uvCmd = Get-Command uv -ErrorAction SilentlyContinue
if ($uvCmd) {
    Write-Output ('   uv at: ' + (San ([string]$uvCmd.Source)))
    try {
        $uvDir = (& uv cache dir 2>$null | Out-String).Trim()
        if ($uvDir) { Write-Output ('   uv cache dir: ' + (San $uvDir)) }
    } catch { }
} else {
    Write-Output '   uv not on PATH (E:\mcp\uv-cache measured directly)'
}
$uvSize = Get-DirSize -root 'E:\mcp\uv-cache' -budgetSec 60
if ($uvSize) { Write-Output ('   E:\mcp\uv-cache on disk: ' + (FmtB ([double]$uvSize.bytes)) + ' / ' + $uvSize.files + ' files' + $(if ($uvSize.partial) { ' (partial)' } else { '' })) }

# ------------------------------------------------------------ recycle bin
Write-Output '--- E: recycle bin ---'
$rb = Get-DirSize -root 'E:\$RECYCLE.BIN' -budgetSec 60
if ($rb) { Write-Output ('   E:\$RECYCLE.BIN: ' + (FmtB ([double]$rb.bytes)) + ' / ' + $rb.files + ' files' + $(if ($rb.partial) { ' (partial)' } else { '' })) }

# ------------------------------------------------------------ WSL
Write-Output '--- WSL state (for the 145 GB ext4.vhdx decision) ---'
try {
    $wl = (& wsl.exe --list --verbose 2>&1 | Out-String)
    foreach ($l in @($wl -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 8)) { Write-Output ('   ' + (San ([string]$l))) }
} catch { Write-Output '   wsl.exe failed' }
$vhdx = Get-Item -LiteralPath 'E:\WSL\Ubuntu-24.04\ext4.vhdx' -ErrorAction SilentlyContinue
if ($vhdx) { Write-Output ('   ext4.vhdx: ' + (FmtB ([double]$vhdx.Length)) + ' (sparse compaction: wsl --manage Ubuntu-24.04 --set-sparse true)') }

Write-Output 'NOTE: dry-run only. Nothing was deleted.'
exit 0
