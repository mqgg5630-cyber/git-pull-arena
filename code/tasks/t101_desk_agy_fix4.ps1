# t101_desk_agy_fix4.ps1 - round 136 task: run fix v4 on the desktop
# (deterministic proxy env delivery + proven relaunch chain), then dump
# the laptop reference config (login works there) for comparison.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t101: desktop fix v4 (retry) + laptop reference ---'

$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$fixSrc = Join-Path $repoRoot 'code\tasks\desk_antigravity_fix4.ps1'
if (-not (Test-Path -LiteralPath $fixSrc)) { L '   [FAIL] fix script missing'; exit 2 }

# parse-validate with the real PowerShell parser BEFORE touching the desktop
$tok = $null; $perrs = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($fixSrc, [ref]$tok, [ref]$perrs)
if ($perrs -and $perrs.Count -gt 0) {
    L ('   [FAIL] fix script has ' + $perrs.Count + ' parse errors:')
    foreach ($e in ($perrs | Select-Object -First 3)) { L ('      line ' + $e.Extent.StartLineNumber + ': ' + (San $e.Message)) }
    exit 2
}
L '   fix4 parse check: OK'

$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
try {
    [IO.File]::WriteAllText(($fshare + '\fig1_rebuild\deskfix4.ps1'), ([IO.File]::ReadAllText($fixSrc)), (New-Object System.Text.UTF8Encoding($false)))
    L '   deskfix4.ps1 staged'
}
finally { & net use $fshare /delete 2>&1 | Out-Null }

$job = Start-Job -ScriptBlock {
    param($o, $t, $h)
    & ssh @o ($t + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\deskfix4.ps1' 2>&1 | Out-String
} -ArgumentList $sshBase, $duser, $desktop
if (-not (Wait-Job $job -Timeout 480)) {
    Stop-Job $job -Force -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    L '   [FAIL] remote fix timed out'
    exit 2
}
$out = (Receive-Job $job | Out-String).Trim()
Remove-Job $job -Force -ErrorAction SilentlyContinue
foreach ($ln in ($out -split "`r?`n")) {
    $x = San $ln
    if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ +') { L ('   ' + $x) }
}

# ---- laptop reference: login WORKS on this machine ----
$lsf = Join-Path $env:APPDATA 'Antigravity\User\settings.json'
if (Test-Path -LiteralPath $lsf) {
    L '--- laptop reference settings.json (login works here) ---'
    foreach ($s in @(Get-Content -LiteralPath $lsf)) { $t = San $s; if ($t.Trim()) { L ('   ' + $t) } }
} else { L '--- laptop reference: settings.json not found ---' }
try {
    $rk = Get-ItemProperty -Path 'HKCU:\Environment'
    L ('   laptop HKCU env: HTTP_PROXY=' + (San ([string]$rk.HTTP_PROXY)) + ' HTTPS_PROXY=' + (San ([string]$rk.HTTPS_PROXY)) + ' NO_PROXY=' + (San ([string]$rk.NO_PROXY)))
} catch { L '   laptop HKCU env read failed' }
L '--- task t101 done ---'
exit 0
