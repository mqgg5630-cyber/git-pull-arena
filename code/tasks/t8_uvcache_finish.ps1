# t8_uvcache_finish.ps1 - round 27 task: finish deleting E:\mcp\uv-cache
# (round 26's rd /s /q hit its 600s cap with 1.28 GB freed; some is left).
# SAFETY: if a uv/uvx process is running right now (MCP tools), the delete
# is SKIPPED so nothing active breaks - it reports what is left instead.
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

Write-Output '--- task t8: uv cache finish ---'
$dir = 'E:\mcp\uv-cache'
if (-not (Test-Path -LiteralPath $dir)) {
    Write-Output '   OK: uv cache already fully removed'
    exit 0
}

$uvRunning = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(?i)uv|uvx' })
if ($uvRunning.Count -gt 0) {
    $pl = @($uvRunning | Select-Object -First 6 | ForEach-Object { $_.Name + '(' + $_.Id + ')' })
    Write-Output ('   SKIP: uv processes are running (' + ($pl -join ' ') + ') - not deleting an in-use cache.')
    Write-Output '   close your MCP tools and the agent will retry in a later round'
    exit 0
}

# measure what is left (60s budget)
$sz = [double]0
$cnt = [long]0
$stack = New-Object System.Collections.Stack
$stack.Push($dir)
$swm = [System.Diagnostics.Stopwatch]::StartNew()
while ($stack.Count -gt 0 -and $swm.Elapsed.TotalSeconds -lt 60) {
    $d = [string]$stack.Pop()
    try { foreach ($sd in [System.IO.Directory]::EnumerateDirectories($d)) { $stack.Push($sd) } } catch { }
    try { foreach ($f in [System.IO.Directory]::EnumerateFiles($d)) { try { $sz += [double]([System.IO.FileInfo]::new($f)).Length; $cnt++ } catch { } } } catch { }
}
Write-Output ('   remaining in uv cache: ' + (FmtB $sz) + ' / ' + $cnt + ' files' + $(if ($swm.Elapsed.TotalSeconds -ge 60) { ' (measure capped)' } else { '' }))

$p = Start-Process -FilePath "$env:ComSpec" -ArgumentList @('/c', 'rd /s /q "' + $dir + '"') -NoNewWindow -PassThru
if ($p.WaitForExit(780000)) {
    if (-not (Test-Path -LiteralPath $dir)) { Write-Output ('   OK: uv cache fully removed (rd exit ' + $p.ExitCode + ')') }
    else { Write-Output ('   [WARN] rd exit ' + $p.ExitCode + ' but the folder is still there - files may be locked') }
} else {
    try { $null = cmd /c ("taskkill /F /T /PID " + $p.Id + " 2>&1") } catch { }
    Write-Output '   [WARN] rd TIMEOUT again - something is holding the cache; report and stop'
}
exit 0
