# t99_desk_agy_verify3.ps1 - round 135 task: endpoint breakdown of the
# desktop's post-relaunch dial-tcp errors (telemetry vs OAuth) + live
# TCP probe, PLUS a laptop-local comparison (laptop login WORKS - does
# its language_server.log show the same telemetry errors?). ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t99: desktop endpoint breakdown + laptop comparison ---'

$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$verifySrc = Join-Path $repoRoot 'code\tasks\desk_antigravity_verify3.ps1'
if (-not (Test-Path -LiteralPath $verifySrc)) { L '   [FAIL] verify script missing'; exit 2 }

$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
try {
    [IO.File]::WriteAllText(($fshare + '\fig1_rebuild\deskverify3.ps1'), ([IO.File]::ReadAllText($verifySrc)), (New-Object System.Text.UTF8Encoding($false)))
    L '   deskverify3.ps1 staged'
}
finally { & net use $fshare /delete 2>&1 | Out-Null }

$job = Start-Job -ScriptBlock {
    param($o, $t, $h)
    & ssh @o ($t + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\deskverify3.ps1' 2>&1 | Out-String
} -ArgumentList $sshBase, $duser, $desktop
if (-not (Wait-Job $job -Timeout 240)) {
    Stop-Job $job -Force -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    L '   [FAIL] remote verify timed out'
    exit 2
}
$out = (Receive-Job $job | Out-String).Trim()
Remove-Job $job -Force -ErrorAction SilentlyContinue
foreach ($ln in ($out -split "`r?`n")) {
    $x = San $ln
    if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ +') { L ('   ' + $x) }
}

# ---- laptop comparison: login WORKS on this machine ----
$lls = Join-Path $env:APPDATA 'Antigravity\logs\language_server.log'
if (Test-Path -LiteralPath $lls) {
    L '--- laptop comparison (login works here) ---'
    $fi = Get-Item -LiteralPath $lls
    L ('   laptop ls.log size=' + [math]::Round($fi.Length/1KB) + 'KB lastWrite=' + $fi.LastWriteTime.ToString('MM-dd HH:mm'))
    if ($fi.Length -gt 20MB) { $llines = @(Get-Content -LiteralPath $lls -Tail 5000); $lnote = ' (tail 5000)' }
    else { $llines = @(Get-Content -LiteralPath $lls); $lnote = '' }
    $ld = @($llines | Where-Object { $_ -match 'dial tcp' })
    $lp = @($llines | Where-Object { $_ -match 'play\.googleapis\.com' })
    $lf = @($llines | Where-Object { $_ -match 'Failed to get OAuth' })
    $lg = @($llines | Where-Object { $_ -match 'record with version 15' })
    L ('   laptop counts' + $lnote + ': lines=' + $llines.Count + ' dial-tcp=' + $ld.Count + ' play.googleapis=' + $lp.Count + ' FailedToGetOAuth=' + $lf.Count + ' tls-garbage=' + $lg.Count)
    foreach ($s in (@($ld | Select-Object -Last 3))) { L ('      ' + (San ([string]$s).Trim())) }
} else { L '--- laptop comparison: language_server.log not found ---' }
L '--- task t99 done ---'
exit 0
