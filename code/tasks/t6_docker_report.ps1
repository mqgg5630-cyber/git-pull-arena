# t6_docker_report.ps1 - round 27 task: READ-ONLY Docker report so the user
# can decide what to clean (they still USE docker). Nothing is pruned.
#   - E:\Docker folder contents + sizes
#   - docker system df (images / containers / volumes / build cache reclaim)
#   - docker images (top 15), docker ps -a (top 10), volume list count
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

Write-Output '--- task t6: Docker report (READ-ONLY, nothing pruned) ---'

# ---------------------------------------------------- E:\Docker contents
Write-Output '--- E:\Docker folder ---'
if (Test-Path -LiteralPath 'E:\Docker') {
    try {
        foreach ($d in @(Get-ChildItem -LiteralPath 'E:\Docker' -Force -ErrorAction SilentlyContinue | Select-Object -First 15)) {
            $kind = 'file'
            $sz = [double]0
            if ($d.PSIsContainer) {
                $kind = 'dir '
                $stack = New-Object System.Collections.Stack
                $stack.Push($d.FullName)
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                while ($stack.Count -gt 0 -and $sw.Elapsed.TotalSeconds -lt 20) {
                    $dir = [string]$stack.Pop()
                    try { foreach ($sd in [System.IO.Directory]::EnumerateDirectories($dir)) { $stack.Push($sd) } } catch { }
                    try { foreach ($f in [System.IO.Directory]::EnumerateFiles($dir)) { try { $sz += [double]([System.IO.FileInfo]::new($f)).Length } catch { } } } catch { }
                }
            } else {
                $sz = [double]$d.Length
            }
            Write-Output ('   ' + $kind + ' ' + (FmtB $sz).PadLeft(12) + '  ' + (San ([string]$d.Name)))
        }
    } catch { Write-Output ('   [WARN] listing: ' + (San $_.Exception.Message)) }
} else {
    Write-Output '   E:\Docker not found'
}

# ------------------------------------------------------------ docker CLI
$dockerExe = $null
$c = Get-Command docker -ErrorAction SilentlyContinue
if ($c) { $dockerExe = [string]$c.Source }
if (-not $dockerExe) {
    foreach ($p in @('C:\Program Files\Docker\Docker\resources\bin\docker.exe', 'E:\Program Files\Docker\Docker\resources\bin\docker.exe')) {
        if (Test-Path -LiteralPath $p) { $dockerExe = $p; break }
    }
}
if (-not $dockerExe) {
    Write-Output '   docker CLI not found - cannot report engine state'
    Write-Output '   (E:\Docker may only hold the WSL data of Docker Desktop)'
    exit 0
}
Write-Output ('   docker CLI: ' + (San $dockerExe))

function Invoke-Docker {
    param([string[]]$dargs, [int]$timeoutSec)
    $job = Start-Job -ScriptBlock { param($p, $a) & $p @a 2>&1 | Out-String } -ArgumentList $dockerExe, $dargs
    if (Wait-Job $job -Timeout $timeoutSec) {
        $o = (Receive-Job $job | Out-String)
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        return $o
    }
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    return '__TIMEOUT__'
}

Write-Output '--- docker system df ---'
$df = Invoke-Docker @('system', 'df') 60
if ($df -eq '__TIMEOUT__') { Write-Output '   TIMEOUT (engine down or slow - start Docker Desktop first)' }
else {
    foreach ($l in @($df -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 12)) { Write-Output ('   ' + (San ([string]$l))) }
}

Write-Output '--- docker images (top 15) ---'
$imgs = Invoke-Docker @('images', '--format', '{{.Repository}}:{{.Tag}}  {{.Size}}  {{.CreatedSince}}') 60
if ($imgs -eq '__TIMEOUT__') { Write-Output '   TIMEOUT' }
else {
    $il = @($imgs -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 15)
    if ($il.Count -eq 0) { Write-Output '   (no images)' }
    foreach ($l in $il) { Write-Output ('   ' + (San ([string]$l))) }
}

Write-Output '--- docker ps -a (top 10) ---'
$ps = Invoke-Docker @('ps', '-a', '--format', '{{.Names}}  {{.Status}}  {{.Image}}') 60
if ($ps -eq '__TIMEOUT__') { Write-Output '   TIMEOUT' }
else {
    $pl = @($ps -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 10)
    if ($pl.Count -eq 0) { Write-Output '   (no containers)' }
    foreach ($l in $pl) { Write-Output ('   ' + (San ([string]$l))) }
}

Write-Output '--- docker volumes ---'
$vols = Invoke-Docker @('volume', 'ls', '-q') 60
if ($vols -eq '__TIMEOUT__') { Write-Output '   TIMEOUT' }
else {
    $vl = @($vols -split "`r?`n" | Where-Object { $_ -match '\S' })
    Write-Output ('   volumes: ' + $vl.Count)
    foreach ($l in @($vl | Select-Object -First 10)) { Write-Output ('   ' + (San ([string]$l))) }
}

Write-Output '--- what cleaning would do (for your decision) ---'
Write-Output '   docker system prune            : removes STOPPED containers + UNUSED images + build cache'
Write-Output '                                     (RUNNING containers and their images are kept; volumes are KEPT)'
Write-Output '   docker system prune -a         : ALSO removes every image not used by a RUNNING container'
Write-Output '                                     (your data in volumes survives, but images re-download on next use)'
Write-Output '   docker system prune --volumes  : ALSO removes UNUSED volumes = DATA LOSS - do not run blindly'
Write-Output '   nothing was pruned by this task'
exit 0
