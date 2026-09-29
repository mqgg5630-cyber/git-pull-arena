# t17_uv_delete_bg.ps1 - round 34 task: kill E:\mcp\uv-cache for good.
# Root cause of the "stuck" deletes: rd removes 30k+ tiny files one by one
# while Defender scans each - it takes many minutes and LOOKS hung (the
# user's manual run and round 33 both deleted ~half before being stopped).
# Fix: robocopy /MIR from an EMPTY dir with /MT:16 (16 threads) - the
# classic fast-delete trick. If that is still slow, a detached rd keeps
# running in the background after this check ends.
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

Write-Output '--- task t17: uv cache fast delete (robocopy /MT:16) ---'
$dir = 'E:\mcp\uv-cache'
$free0 = Get-FreeE
if (-not (Test-Path -LiteralPath $dir)) {
    Write-Output '   OK: uv cache already gone'
    Write-Output ('   E: free: ' + $free0 + ' GB')
    exit 0
}

# what is left
$sz = [double]0
$cnt = [long]0
try {
    $stack = New-Object System.Collections.Stack
    $stack.Push($dir)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stack.Count -gt 0 -and $sw.Elapsed.TotalSeconds -lt 30) {
        $d = [string]$stack.Pop()
        try { foreach ($sd in [System.IO.Directory]::EnumerateDirectories($d)) { $stack.Push($sd) } } catch { }
        try { foreach ($f in [System.IO.Directory]::EnumerateFiles($d)) { try { $sz += [double]([System.IO.FileInfo]::new($f)).Length; $cnt++ } catch { } } } catch { }
    }
} catch { }
Write-Output ('   remaining: ' + (FmtB $sz) + ' / ' + $cnt + ' files (round 33 stopped at 760 MB - every run deletes more)')

# who keeps uv alive (parent process), report only
try {
    $uvs = @(Get-CimInstance Win32_Process -Filter "Name LIKE 'uv%' OR Name LIKE 'uvx%'" -ErrorAction SilentlyContinue)
    foreach ($u in $uvs) {
        $par = ''
        try { $par = [string](Get-CimInstance Win32_Process -Filter ("ProcessId=" + $u.ParentProcessId) -ErrorAction SilentlyContinue).Name } catch { }
        Write-Output ('   uv process: ' + (San ([string]$u.Name)) + ' pid=' + $u.ProcessId + ' parent=' + $(if ($par) { (San $par) } else { '(gone)' }))
    }
    if ($uvs.Count -eq 0) { Write-Output '   uv processes: none running' }
} catch { }

# robocopy mirror-empty delete
$empty = Join-Path $env:TEMP ('uv_empty_' + $PID)
try { New-Item -ItemType Directory -Force -Path $empty | Out-Null } catch { }
Write-Output '   robocopy /MIR /MT:16 from an empty dir (multi-threaded delete) ...'
$rc = Start-Process -FilePath 'robocopy.exe' -ArgumentList @($empty, $dir, '/MIR', '/MT:16', '/R:0', '/W:0', '/NFL', '/NDL', '/NJH', '/NJS', '/NP') -NoNewWindow -PassThru
$done = $rc.WaitForExit(420000)
if (-not $done) {
    try { $null = cmd /c ("taskkill /F /T /PID " + $rc.Id + " 2>&1") } catch { }
    Write-Output '   [WARN] robocopy TIMEOUT (420s) - detaching an rd to finish in the background'
    $null = Start-Process -FilePath "$env:ComSpec" -ArgumentList @('/c', 'rd /s /q E:\mcp\uv-cache') -WindowStyle Hidden
    Write-Output '   background rd launched - it keeps deleting after this check ends'
} else {
    Write-Output ('   robocopy finished (exit ' + $rc.ExitCode + ' - 0-7 are success codes for robocopy)')
}

# remove the emptied shell + temp dir
foreach ($d in @($dir, $empty)) {
    if (Test-Path -LiteralPath $d) {
        $p2 = Start-Process -FilePath "$env:ComSpec" -ArgumentList @('/c', ('rd /s /q ' + $d)) -NoNewWindow -PassThru
        $null = $p2.WaitForExit(120000)
    }
}

if (-not (Test-Path -LiteralPath $dir)) {
    $free1 = Get-FreeE
    Write-Output ('   OK: E:\mcp\uv-cache GONE')
    Write-Output ('   E: free: ' + $free0 + ' -> ' + $free1 + ' GB')
    exit 0
}
$left = [double]0
try { foreach ($f in [System.IO.Directory]::EnumerateFiles($dir, '*', [System.IO.SearchOption]::AllDirectories)) { try { $left += [double]([System.IO.FileInfo]::new($f)).Length } catch { } } } catch { }
Write-Output ('   [WARN] still present: ' + (FmtB $left) + ' - the background rd or the next round finishes it')
exit 0
