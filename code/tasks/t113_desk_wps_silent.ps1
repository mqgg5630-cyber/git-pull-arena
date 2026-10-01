# t113_desk_wps_silent.ps1 - round 149 task: (task 2, desktop) retry the
# WPS install with the CORRECT silent switches (/s -agreelicense, verified
# by the community - bare /S does nothing on the personal edition), then
# harness install (setuptools first) + writer/impress smoke tests.
# Stages desk_wps_install2.ps1 + verify_pptx.py + deck builder on F$.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t113: desktop WPS silent install v2 + harness smoke ---'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'

foreach ($f in @('desk_wps_install2.ps1')) {
    $tok = $null; $perrs = $null
    $fp = Join-Path $repoRoot ('code\tasks\' + $f)
    $null = [System.Management.Automation.Language.Parser]::ParseFile($fp, [ref]$tok, [ref]$perrs)
    if ($perrs -and $perrs.Count -gt 0) {
        L ('   [FAIL] parse errors in ' + $f + ': ' + $perrs.Count)
        foreach ($e in ($perrs | Select-Object -First 3)) { L ('      line ' + $e.Extent.StartLineNumber + ': ' + (San $e.Message)) }
        exit 2
    }
}
L '   parse checks: OK'

$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
try {
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\desk_wps_install2.ps1') -Destination ($fshare + '\fig1_rebuild\desk_wps_install2.ps1') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\verify_pptx.py') -Destination ($fshare + '\fig1_rebuild\verify_pptx.py') -Force
    New-Item -ItemType Directory -Force -Path ($fshare + '\fig1_rebuild\harness_results') | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\desk_harness_deck.py') -Destination ($fshare + '\fig1_rebuild\harness_results\desk_harness_deck.py') -Force
    L '   staged desk_wps_install2.ps1 + verify + deck builder'
}
finally { & net use $fshare /delete 2>&1 | Out-Null }

$job = Start-Job -ScriptBlock {
    param($o, $t, $h)
    & ssh @o ($t + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\desk_wps_install2.ps1' 2>&1 | Out-String
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
L '--- task t113 done ---'
exit 0
