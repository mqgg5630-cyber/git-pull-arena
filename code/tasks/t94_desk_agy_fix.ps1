# t94_desk_agy_fix.ps1 - round 130 task: apply the desktop Antigravity
# proxy fix: stage desk_antigravity_fix.ps1 via F$, run it over ssh
# (capped 300s), print the sanitized output. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t94: desktop Antigravity proxy fix ---'

$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$fixSrc = Join-Path $repoRoot 'code\tasks\desk_antigravity_fix.ps1'
if (-not (Test-Path -LiteralPath $fixSrc)) { L '   [FAIL] fix script missing in repo'; exit 2 }

# ------------------------------------------------ 1. stage via F$
$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
try {
    [IO.File]::WriteAllText(($fshare + '\fig1_rebuild\deskfix.ps1'), ([IO.File]::ReadAllText($fixSrc)), (New-Object System.Text.UTF8Encoding($false)))
    L '   deskfix.ps1 staged'
}
finally { & net use $fshare /delete 2>&1 | Out-Null }

# ------------------------------------------------ 2. run (capped 300s)
$job = Start-Job -ScriptBlock {
    param($o, $t, $h)
    & ssh @o ($t + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\deskfix.ps1' 2>&1 | Out-String
} -ArgumentList $sshBase, $duser, $desktop
if (-not (Wait-Job $job -Timeout 300)) {
    Stop-Job $job -Force -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    L '   [FAIL] remote fix timed out (300s)'
    exit 2
}
$out = (Receive-Job $job | Out-String).Trim()
Remove-Job $job -Force -ErrorAction SilentlyContinue
foreach ($ln in ($out -split "`r?`n")) {
    $x = San $ln
    if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ +') { L ('   ' + $x) }
}
L '--- task t94 done ---'
exit 0
