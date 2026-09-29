# t17b_uv_finish.ps1 - round 35 task: verify E:\mcp\uv-cache is gone; if
# anything remains, finish it with robocopy /MT:16 - with ALL robocopy/rd
# output REDIRECTED to temp files (round 34 let robocopy print 200k+ lines
# straight into the receipt and the survey never got its time budget).
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

Write-Output '--- task t17b: uv cache finish (quiet) ---'
$dir = 'E:\mcp\uv-cache'
$free0 = Get-FreeE
if (-not (Test-Path -LiteralPath $dir)) {
    Write-Output ('   OK: E:\mcp\uv-cache is GONE (rounds 33-34 deleted it)')
    Write-Output ('   E: free: ' + $free0 + ' GB')
    exit 0
}

# what is left (20s measure cap)
$sz = [double]0
$cnt = [long]0
try {
    $stack = New-Object System.Collections.Stack
    $stack.Push($dir)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stack.Count -gt 0 -and $sw.Elapsed.TotalSeconds -lt 20) {
        $d = [string]$stack.Pop()
        try { foreach ($sd in [System.IO.Directory]::EnumerateDirectories($d)) { $stack.Push($sd) } } catch { }
        try { foreach ($f in [System.IO.Directory]::EnumerateFiles($d)) { try { $sz += [double]([System.IO.FileInfo]::new($f)).Length; $cnt++ } catch { } } } catch { }
    }
} catch { }
Write-Output ('   remaining: ' + (FmtB $sz) + ' / ' + $cnt + ' files')

$empty = Join-Path $env:TEMP ('uv_empty2_' + $PID)
try { New-Item -ItemType Directory -Force -Path $empty | Out-Null } catch { }
$outF = [System.IO.Path]::GetTempFileName()
$errF = [System.IO.Path]::GetTempFileName()
Write-Output '   robocopy /MIR /MT:16 (output redirected to a temp file) ...'
$rc = Start-Process -FilePath 'robocopy.exe' -ArgumentList @($empty, $dir, '/MIR', '/MT:16', '/R:0', '/W:0', '/NFL', '/NDL', '/NJH', '/NJS', '/NP') -NoNewWindow -PassThru -RedirectStandardOutput $outF -RedirectStandardError $errF
$null = $rc.WaitForExit(300000)
$rcCode = ''
try { $rcCode = [string]$rc.ExitCode } catch { }
if ($rc.HasExited) { Write-Output ('   robocopy exit: ' + $rcCode + ' (0-7 = success)') }
else {
    try { $null = cmd /c ("taskkill /F /T /PID " + $rc.Id + " 2>&1") } catch { }
    Write-Output '   [WARN] robocopy TIMEOUT (300s) - detaching a quiet rd'
    $null = Start-Process -FilePath "$env:ComSpec" -ArgumentList @('/c', 'rd /s /q E:\mcp\uv-cache > nul 2>&1') -WindowStyle Hidden
}

foreach ($d in @($dir, $empty)) {
    if (Test-Path -LiteralPath $d) {
        $p2 = Start-Process -FilePath "$env:ComSpec" -ArgumentList @('/c', ('rd /s /q "' + $d + '" > nul 2>&1')) -NoNewWindow -PassThru
        $null = $p2.WaitForExit(120000)
    }
}
Remove-Item -LiteralPath $outF, $errF -Force -ErrorAction SilentlyContinue

$free1 = Get-FreeE
if (-not (Test-Path -LiteralPath $dir)) {
    Write-Output ('   OK: E:\mcp\uv-cache GONE. E: free: ' + $free0 + ' -> ' + $free1 + ' GB')
    exit 0
}
$left = [double]0
try { foreach ($f in [System.IO.Directory]::EnumerateFiles($dir, '*', [System.IO.SearchOption]::AllDirectories)) { try { $left += [double]([System.IO.FileInfo]::new($f)).Length } catch { } } } catch { }
Write-Output ('   [WARN] still present: ' + (FmtB $left) + ' (locked files - a reboot-time clean would finish it)')
exit 0
