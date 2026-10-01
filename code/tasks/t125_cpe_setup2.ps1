# t125_cpe_setup2.ps1 - round 164 task: (cell_ppt_edited skill, desktop
# only) phase 1 - stage the vendored skill source on F$, run the desktop
# environment check + release download + engine self-test/doctor +
# Install.ps1 -CheckOnly over ssh. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t125: cell_ppt_edited phase 1 (retry) (env + download + engine checks) ---'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
$srcDir = Join-Path $repoRoot 'skills\cell_ppt_edited\src'

$fp = Join-Path $repoRoot 'code\tasks\desk_cpe_setup.ps1'
$tok = $null; $perrs = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($fp, [ref]$tok, [ref]$perrs)
if ($perrs -and $perrs.Count -gt 0) {
    L ('   [FAIL] parse errors in desk_cpe_setup.ps1: ' + $perrs.Count)
    foreach ($e in ($perrs | Select-Object -First 3)) { L ('      line ' + $e.Extent.StartLineNumber + ': ' + (San $e.Message)) }
    exit 2
}
L '   parse check: OK'

$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
try {
    Copy-Item -LiteralPath $fp -Destination ($fshare + '\fig1_rebuild\desk_cpe_setup.ps1') -Force
    & robocopy $srcDir ($fshare + '\fig1_rebuild\cpe\src') /E /MT:16 /NFL /NDL /NJH /NP 2>&1 | Select-Object -Last 1 | ForEach-Object { L ('      robocopy skill src: ' + (San ([string]$_))) }
    L '   staged desk_cpe_setup.ps1 + skill source'
}
finally { & net use $fshare /delete 2>&1 | Out-Null }

$job = Start-Job -ScriptBlock {
    param($o, $t, $h)
    & ssh @o ($t + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\desk_cpe_setup.ps1' 2>&1 | Out-String
} -ArgumentList $sshBase, $duser, $desktop
if (-not (Wait-Job $job -Timeout 600)) {
    Stop-Job $job -Force -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    L '   [FAIL] remote phase timed out'
    exit 2
}
$out = (Receive-Job $job | Out-String).Trim()
Remove-Job $job -Force -ErrorAction SilentlyContinue
foreach ($ln in ($out -split "`r?`n")) {
    $x = San $ln
    if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ +') { L ('   ' + $x) }
}
L '--- task t125 done ---'
exit 0
