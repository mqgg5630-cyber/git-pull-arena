# t16_uvcache_final2.ps1 - round 33 task: actually delete E:\mcp\uv-cache.
# Round 32 got everything done except this: the rd /s /q argument built with
# embedded quotes was mangled by Start-Process ("filename syntax incorrect").
# Fix: no quotes needed (no spaces in the path) and a plain synchronous call
# inside a job with a timeout. Windows PowerShell 5.1, ASCII-only.

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

Write-Output '--- task t16: uv cache final removal (fixed quoting) ---'
$dir = 'E:\mcp\uv-cache'
$free0 = Get-FreeE
Write-Output ('   E: free now: ' + $free0 + ' GB')

if (-not (Test-Path -LiteralPath $dir)) {
    Write-Output '   OK: uv cache already gone'
    Write-Output ('=== FINAL: E: free ' + $free0 + ' GB (cleanup series started at 233.98 GB)')
    exit 0
}

# measure what is left (30s cap)
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
Write-Output ('   remaining: ' + (FmtB $sz) + ' / ' + $cnt + ' files')

# kill any uv process still running FROM the cache (none in round 32, re-check)
$uvProcs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(?i)uv|uvx' })
foreach ($p in $uvProcs) {
    $path = ''
    try { $path = [string]$p.Path } catch { }
    if ($path -and $path.StartsWith('E:\mcp\uv-cache', [System.StringComparison]::OrdinalIgnoreCase)) {
        try { Stop-Process -Id $p.Id -Force -ErrorAction Stop; Write-Output ('   killed ' + $p.Name + '(' + $p.Id + ') - it ran from the cache') } catch { Write-Output ('   [WARN] kill ' + $p.Id + ': ' + (San $_.Exception.Message)) }
    } else {
        Write-Output ('   leave alone: ' + $p.Name + '(' + $p.Id + ')')
    }
}
if ($uvProcs.Count -gt 0) { Start-Sleep -Seconds 3 }

# plain synchronous rd, no embedded quotes (path has no spaces)
$job = Start-Job -ScriptBlock {
    cmd /c rd /s /q E:\mcp\uv-cache
    return $LASTEXITCODE
}
if (Wait-Job $job -Timeout 780) {
    $rc = (Receive-Job $job | Select-Object -Last 1)
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    Write-Output ('   rd exit code: ' + $rc)
} else {
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    Write-Output '   [WARN] rd TIMEOUT (780s)'
}

if (-not (Test-Path -LiteralPath $dir)) {
    Write-Output '   OK: E:\mcp\uv-cache fully removed'
} else {
    $left = [double]0
    try {
        foreach ($f in [System.IO.Directory]::EnumerateFiles($dir, '*', [System.IO.SearchOption]::AllDirectories)) {
            try { $left += [double]([System.IO.FileInfo]::new($f)).Length } catch { }
        }
    } catch { }
    Write-Output ('   [WARN] folder still present with ' + (FmtB $left) + ' (locked)')
}

$free1 = Get-FreeE
Write-Output ('   E: free after: ' + $free1 + ' GB (this step freed ' + [math]::Round($free1 - $free0, 2) + ' GB)')
Write-Output ('=== FINAL: E: free ' + $free1 + ' GB (the cleanup series started at 233.98 GB on 2026-09-29)')
exit 0
