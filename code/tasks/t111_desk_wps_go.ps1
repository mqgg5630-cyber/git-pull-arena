# t111_desk_wps_go.ps1 - round 147 task: (task 2, desktop execution)
# Wait for the desktop background download to finish (wps_setup.exe >=
# 200MB), then run the staged desk_wps_install.ps1 over ssh: silent WPS
# install + COM verify + offline harness install + writer/impress smoke
# tests with reopen verification. No laptop testing (user cancelled).
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t111: desktop WPS install + harness smoke ---'

$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')

function Get-SetupSize {
    $r = & ssh @sshBase ($duser + '@' + $desktop) 'dir F:\fig1_rebuild\wps_setup.exe 2>nul | findstr wps_setup' 2>&1
    $line = ($r | Select-Object -Last 1)
    if ($line -match '([\d\s,\.]+)\s+wps_setup\.exe') {
        $num = ($Matches[1] -replace '[^\d]', '')
        if ($num) { return [long]$num }
    }
    return 0
}

# ---------------- A. wait for the download (up to 15 min) ----------------
$size = Get-SetupSize
$waited = 0
while ($size -lt 200MB -and $waited -lt 900) {
    Start-Sleep -Seconds 60
    $waited += 60
    $size = Get-SetupSize
    if (($waited % 180) -eq 0) { L ('   waiting for download: ' + [math]::Round($size/1MB) + 'MB after ' + $waited + 's') }
}
L ('   setup size: ' + [math]::Round($size/1MB) + 'MB (waited ' + $waited + 's)')
if ($size -lt 200MB) {
    L '   [FAIL] download still incomplete - install deferred to next round'
    $dl = & ssh @sshBase ($duser + '@' + $desktop) 'type F:\fig1_rebuild\wps_download.log 2>nul' 2>&1
    foreach ($ln in @($dl | Select-Object -Last 4)) { if ($ln) { L ('   wpsdl log: ' + (San ([string]$ln))) } }
    exit 2
}

# ---------------- B. run the install + smoke tests ----------------
$job = Start-Job -ScriptBlock {
    param($o, $t, $h)
    & ssh @o ($t + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\desk_wps_install.ps1' 2>&1 | Out-String
} -ArgumentList $sshBase, $duser, $desktop
if (-not (Wait-Job $job -Timeout 1500)) {
    Stop-Job $job -Force -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    L '   [FAIL] remote install timed out (installer may still be running - recheck next round)'
    exit 2
}
$out = (Receive-Job $job | Out-String).Trim()
Remove-Job $job -Force -ErrorAction SilentlyContinue
foreach ($ln in ($out -split "`r?`n")) {
    $x = San $ln
    if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ +') { L ('   ' + $x) }
}
L '--- task t111 done ---'
exit 0
