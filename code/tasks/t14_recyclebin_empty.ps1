# t14_recyclebin_empty.ps1 - round 32 task: empty the E: recycle bin
# (user approved - it holds ~6.1 GB of removed installers and old LigPlus
# jars). Tries Clear-RecycleBin first; if anything survives, falls back to
# rd /s /q on E:\$RECYCLE.BIN (Windows recreates the folder automatically).
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

function Get-BinSize {
    $bytes = [double]0
    $files = [long]0
    try {
        $stack = New-Object System.Collections.Stack
        $stack.Push('E:\$RECYCLE.BIN')
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($stack.Count -gt 0 -and $sw.Elapsed.TotalSeconds -lt 30) {
            $dir = [string]$stack.Pop()
            try { foreach ($sd in [System.IO.Directory]::EnumerateDirectories($dir)) { $stack.Push($sd) } } catch { }
            try { foreach ($f in [System.IO.Directory]::EnumerateFiles($dir)) { try { $bytes += [double]([System.IO.FileInfo]::new($f)).Length; $files++ } catch { } } } catch { }
        }
    } catch { }
    return @{ b = $bytes; f = $files }
}

Write-Output '--- task t14: empty the E: recycle bin ---'

$before = Get-BinSize
Write-Output ('   bin before: ' + (FmtB $before.b) + ' / ' + $before.f + ' files')

try {
    Clear-RecycleBin -DriveLetter E -Force -ErrorAction Stop
    Write-Output '   Clear-RecycleBin ran'
} catch {
    Write-Output ('   [WARN] Clear-RecycleBin: ' + (San $_.Exception.Message))
}

$mid = Get-BinSize
if ($mid.b -gt 10MB) {
    Write-Output ('   bin still holds ' + (FmtB $mid.b) + ' - falling back to rd /s /q (Windows recreates the folder)')
    $p = Start-Process -FilePath "$env:ComSpec" -ArgumentList @('/c', 'rd /s /q "E:\$RECYCLE.BIN"') -NoNewWindow -PassThru
    if (-not $p.WaitForExit(300000)) {
        try { $null = cmd /c ("taskkill /F /T /PID " + $p.Id + " 2>&1") } catch { }
        Write-Output '   [WARN] rd TIMEOUT'
    }
}

$after = Get-BinSize
if ($after.b -le 10MB) {
    Write-Output ('   bin after: ' + (FmtB $after.b) + ' - EMPTY OK')
    Write-Output ('== recycle bin emptied (freed ' + (FmtB ([double]($before.b - $after.b))) + ' on E:)')
    exit 0
}
Write-Output ('   [WARN] bin still holds ' + (FmtB $after.b) + ' / ' + $after.f + ' files - something may be open in Explorer')
exit 0
