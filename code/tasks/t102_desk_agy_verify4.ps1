# t102_desk_agy_verify4.ps1 - round 138 task: final acceptance check of
# the desktop Antigravity proxy fix (read-only, no soak - the session has
# been up since the v4 relaunch). ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t102: desktop Antigravity final acceptance ---'

$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$verifySrc = Join-Path $repoRoot 'code\tasks\desk_antigravity_verify4.ps1'
if (-not (Test-Path -LiteralPath $verifySrc)) { L '   [FAIL] verify script missing'; exit 2 }

# parse-validate with the real PowerShell parser BEFORE touching the desktop
$tok = $null; $perrs = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($verifySrc, [ref]$tok, [ref]$perrs)
if ($perrs -and $perrs.Count -gt 0) {
    L ('   [FAIL] verify script has ' + $perrs.Count + ' parse errors:')
    foreach ($e in ($perrs | Select-Object -First 3)) { L ('      line ' + $e.Extent.StartLineNumber + ': ' + (San $e.Message)) }
    exit 2
}
L '   verify4 parse check: OK'

$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
try {
    [IO.File]::WriteAllText(($fshare + '\fig1_rebuild\deskverify4.ps1'), ([IO.File]::ReadAllText($verifySrc)), (New-Object System.Text.UTF8Encoding($false)))
    L '   deskverify4.ps1 staged'
}
finally { & net use $fshare /delete 2>&1 | Out-Null }

$job = Start-Job -ScriptBlock {
    param($o, $t, $h)
    & ssh @o ($t + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\deskverify4.ps1' 2>&1 | Out-String
} -ArgumentList $sshBase, $duser, $desktop
if (-not (Wait-Job $job -Timeout 300)) {
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
L '--- task t102 done ---'
exit 0
