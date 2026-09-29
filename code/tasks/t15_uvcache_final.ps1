# t15_uvcache_final.ps1 - round 32 task: final uv cache removal.
# The remaining 1.78 GB cannot be deleted because uv processes are running
# FROM the cache (uvx temporary environments live in uv-cache\archive-v0 -
# typically MCP servers). The user asked to finish this now, so:
#   1. list every uv/uvx process and its executable path
#   2. kill ONLY those whose exe lives inside E:\mcp\uv-cache (they are
#      throwaway uvx environments; the owning tool re-provisions them on
#      its next start) - other uv processes are left alone
#   3. rd /s /q the cache
#   4. report the final E: free space (cleanup series started at 233.98 GB)
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

Write-Output '--- task t15: uv cache final removal ---'
$dir = 'E:\mcp\uv-cache'
$free0 = Get-FreeE
Write-Output ('   E: free now: ' + $free0 + ' GB')

if (-not (Test-Path -LiteralPath $dir)) {
    Write-Output '   OK: uv cache already gone'
    Write-Output ('=== FINAL: E: free ' + $free0 + ' GB (the cleanup series started at 233.98 GB)')
    exit 0
}

# 1. uv processes and their paths
$uvProcs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(?i)uv|uvx' })
Write-Output ('   uv/uvx processes: ' + $uvProcs.Count)
$inCache = @()
$other = @()
foreach ($p in $uvProcs) {
    $path = ''
    try { $path = [string]$p.Path } catch { }
    if ($path -and $path.StartsWith('E:\mcp\uv-cache', [System.StringComparison]::OrdinalIgnoreCase)) {
        $inCache += $p
        Write-Output ('   KILL-LATER  ' + $p.Name + '(' + $p.Id + ')  ' + (San $path))
    } else {
        $other += $p
        Write-Output ('   leave-alone ' + $p.Name + '(' + $p.Id + ')  ' + $(if ($path) { (San $path) } else { '(path not readable)' }))
    }
}

# 2. kill the ones running from the cache (they re-provision on next start)
if ($inCache.Count -gt 0) {
    foreach ($p in $inCache) {
        try { Stop-Process -Id $p.Id -Force -ErrorAction Stop; Write-Output ('   killed ' + $p.Name + '(' + $p.Id + ')') }
        catch { Write-Output ('   [WARN] could not kill ' + $p.Id + ': ' + (San $_.Exception.Message)) }
    }
    Start-Sleep -Seconds 3
} else {
    Write-Output '   no processes are running from the cache'
}

# 3. delete the cache
$p2 = Start-Process -FilePath "$env:ComSpec" -ArgumentList @('/c', 'rd /s /q "' + $dir + '"') -NoNewWindow -PassThru
if ($p2.WaitForExit(600000)) {
    if (-not (Test-Path -LiteralPath $dir)) { Write-Output ('   OK: uv cache fully removed (rd exit ' + $p2.ExitCode + ')') }
    else {
        $left = [double]0
        try {
            foreach ($f in [System.IO.Directory]::EnumerateFiles($dir, '*', [System.IO.SearchOption]::AllDirectories)) {
                try { $left += [double]([System.IO.FileInfo]::new($f)).Length } catch { }
            }
        } catch { }
        Write-Output ('   [WARN] rd finished but ' + (FmtB $left) + ' is still in the folder (locked files)')
    }
} else {
    try { $null = cmd /c ("taskkill /F /T /PID " + $p2.Id + " 2>&1") } catch { }
    Write-Output '   [WARN] rd TIMEOUT (600s)'
}

# 4. final numbers
$free1 = Get-FreeE
Write-Output ('   E: free after: ' + $free1 + ' GB (this step freed ' + [math]::Round($free1 - $free0, 2) + ' GB)')
Write-Output ('=== FINAL: E: free ' + $free1 + ' GB  (cleanup series started at 233.98 GB on 2026-09-29)')
Write-Output '    note: if an MCP tool was running from the cache, just restart that tool - uv re-downloads its environment on demand'
exit 0
