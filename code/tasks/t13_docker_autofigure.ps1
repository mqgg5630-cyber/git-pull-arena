# t13_docker_autofigure.ps1 - round 32 task: remove the autofigure-edit
# container (stopped 5 weeks ago) and its 9.34 GB image, as the user approved.
# NOTHING else is pruned (n8n and the other images stay).
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t13: remove autofigure-edit (container + image) ---'

$dockerExe = 'E:\Docker\DockerDesktop\resources\bin\docker.exe'
if (-not (Test-Path -LiteralPath $dockerExe)) {
    $c = Get-Command docker -ErrorAction SilentlyContinue
    if ($c) { $dockerExe = [string]$c.Source } else { Write-Output '   [FAIL] docker CLI not found'; exit 2 }
}

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

# engine up?
$ver = Invoke-Docker @('version', '--format', '{{.Server.Version}}') 30
if ($ver -eq '__TIMEOUT__' -or $ver -notmatch '\S' -or $ver -match '(?i)error|failed') {
    Write-Output ('   [FAIL] docker engine not reachable: ' + (San ($ver -replace '\s+', ' ')))
    exit 2
}
Write-Output ('   engine up, server version ' + (San ($ver.Trim())))

Write-Output '--- before ---'
$df0 = Invoke-Docker @('system', 'df') 60
foreach ($l in @($df0 -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 6)) { Write-Output ('   ' + (San ([string]$l))) }

# remove the stopped container
Write-Output '--- docker rm autofigure-edit ---'
$rm = Invoke-Docker @('rm', 'autofigure-edit') 60
Write-Output ('   ' + (San (($rm -replace '\s+', ' ').Trim())))

# remove the image
Write-Output '--- docker rmi autofigure-edit:latest ---'
$rmi = Invoke-Docker @('rmi', 'autofigure-edit:latest') 180
foreach ($l in @($rmi -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 8)) { Write-Output ('   ' + (San ([string]$l))) }

Write-Output '--- after ---'
$df1 = Invoke-Docker @('system', 'df') 60
foreach ($l in @($df1 -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 6)) { Write-Output ('   ' + (San ([string]$l))) }

# confirm gone
$imgs = Invoke-Docker @('images', '--format', '{{.Repository}}:{{.Tag}}') 60
$left = @($imgs -split "`r?`n" | Where-Object { $_ -match '(?i)autofigure' })
if ($left.Count -eq 0) { Write-Output '== autofigure-edit container + image REMOVED (n8n and everything else untouched)' }
else { Write-Output ('   [WARN] autofigure images still present: ' + ($left -join ', ')); exit 2 }
exit 0
