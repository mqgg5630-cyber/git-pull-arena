# t111b_desk_wps_go2.ps1 - round 148 task: (task 2, desktop execution)
# The desktop download IS complete (wps_setup.exe staged, wpsdl v1 ground
# through). t110's staging never ran (skipped round) and the first
# desk_wps_install.ps1 had a parse error (fixed now). This task:
#   A. stage everything on F$ (fixed desk_wps_install.ps1, verify_pptx.py,
#      deck builder, patched harness-anything tree)
#   B. size-check the setup (exact file match, not the partial)
#   C. run install + COM verify + harness install + writer/impress smoke
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t111b: staging + desktop WPS install + harness smoke ---'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
$haDir = Join-Path $repoRoot 'skills\harness-anything'

# ---------------- A. stage ----------------
$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
try {
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\desk_wps_install.ps1') -Destination ($fshare + '\fig1_rebuild\desk_wps_install.ps1') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\verify_pptx.py') -Destination ($fshare + '\fig1_rebuild\verify_pptx.py') -Force
    New-Item -ItemType Directory -Force -Path ($fshare + '\fig1_rebuild\harness_results') | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\desk_harness_deck.py') -Destination ($fshare + '\fig1_rebuild\harness_results\desk_harness_deck.py') -Force
    L '   scripts staged (fixed install + verify + deck builder)'
    & robocopy $haDir ($fshare + '\fig1_rebuild\harness-anything') /E /MT:16 /NFL /NDL /NJH /NP 2>&1 | Select-Object -Last 2 | ForEach-Object { L ('      robocopy harness: ' + (San ([string]$_))) }
}
finally { & net use $fshare /delete 2>&1 | Out-Null }

# ---------------- B. setup size (exact exe, ignore partial) ----------------
$szLine = & ssh @sshBase ($duser + '@' + $desktop) 'dir F:\fig1_rebuild\wps_setup.exe 2>nul | findstr /c:"wps_setup.exe"' 2>&1
foreach ($ln in @($szLine)) { L ('   setup: ' + (San ([string]$ln))) }
$size = 0
foreach ($ln in @($szLine)) {
    if ($ln -match '([\d\s,\.]+)\s+wps_setup\.exe') {
        $num = ($Matches[1] -replace '[^\d]', '')
        if ($num) { $size = [long]$num }
    }
}
L ('   setup bytes: ' + $size + ' (' + [math]::Round($size/1MB) + 'MB)')
if ($size -lt 200MB) {
    L '   [FAIL] setup incomplete - download not finished'
    $dl = & ssh @sshBase ($duser + '@' + $desktop) 'type F:\fig1_rebuild\wps_download.log 2>nul' 2>&1
    foreach ($ln in @($dl | Select-Object -Last 4)) { if ($ln) { L ('   wpsdl log: ' + (San ([string]$ln))) } }
    exit 2
}

# ---------------- C. install + smoke ----------------
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
L '--- task t111b done ---'
exit 0
