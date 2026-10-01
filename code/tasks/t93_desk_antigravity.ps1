# t93_desk_antigravity.ps1 - round 129 task: diagnose the DESKTOP
# Antigravity login failure: stage desk_antigravity_diag.ps1 via F$ and run
# it over ssh (quote-free -File invocation, 420s cap). Output is already
# sanitized on the desktop side. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t93: desktop Antigravity login diagnosis ---'

$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$diagSrc = Join-Path $repoRoot 'code\tasks\desk_antigravity_diag.ps1'
if (-not (Test-Path -LiteralPath $diagSrc)) { L '   [FAIL] diag script missing in repo'; exit 2 }

# ------------------------------------------------ 1. stage via F$
$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
try {
    [IO.File]::WriteAllText(($fshare + '\fig1_rebuild\deskdiag.ps1'), ([IO.File]::ReadAllText($diagSrc)), (New-Object System.Text.UTF8Encoding($false)))
    L '   deskdiag.ps1 staged on F:\fig1_rebuild'
}
finally { & net use $fshare /delete 2>&1 | Out-Null }

# ------------------------------------------------ 2. run it (capped)
$job = Start-Job -ScriptBlock {
    param($o, $t, $h)
    & ssh @o ($t + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\deskdiag.ps1' 2>&1 | Out-String
} -ArgumentList $sshBase, $duser, $desktop
if (-not (Wait-Job $job -Timeout 420)) {
    Stop-Job $job -Force -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    L '   [FAIL] remote diagnosis timed out (420s)'
    exit 2
}
$out = (Receive-Job $job | Out-String).Trim()
Remove-Job $job -Force -ErrorAction SilentlyContinue

# ------------------------------------------------ 3. print (filter PS noise)
foreach ($ln in ($out -split "`r?`n")) {
    $x = San $ln
    if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ +') { L ('   ' + $x) }
}
L '--- task t93 done ---'
exit 0
