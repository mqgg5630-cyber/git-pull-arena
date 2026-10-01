# t110_desk_wpsdl_fix.ps1 - round 146 task: the desktop wpsdl download
# stalled at 0 bytes (machine-level HTTP_PROXY routes the China CDN through
# the overseas proxy exit). Fix: deploy wpsdl.cmd v2 (proxy env cleared +
# curl --noproxy "*"), restart the task, wait 4 minutes, report growth.
# Also re-stage the patched harness (new _fill_impress renderer) + deck
# builder on F$. No laptop testing (user cancelled that). ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t110: desktop wpsdl v2 restart + harness re-stage ---'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
$haDir = Join-Path $repoRoot 'skills\harness-anything'

# ---------------- A. current state ----------------
$dl = & ssh @sshBase ($duser + '@' + $desktop) 'type F:\fig1_rebuild\wps_download.log 2>nul' 2>&1
foreach ($ln in @($dl | Select-Object -Last 3)) { if ($ln) { L ('   before: ' + (San ([string]$ln))) } }

# ---------------- B. deploy v2 + restart ----------------
$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
try {
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\wpsdl.cmd') -Destination ($fshare + '\fig1_rebuild\wpsdl.cmd') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\desk_wps_install.ps1') -Destination ($fshare + '\fig1_rebuild\desk_wps_install.ps1') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\verify_pptx.py') -Destination ($fshare + '\fig1_rebuild\verify_pptx.py') -Force
    New-Item -ItemType Directory -Force -Path ($fshare + '\fig1_rebuild\harness_results') | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\desk_harness_deck.py') -Destination ($fshare + '\fig1_rebuild\harness_results\desk_harness_deck.py') -Force
    L '   scripts staged (wpsdl v2 + install + verify + deck builder)'
    & robocopy $haDir ($fshare + '\fig1_rebuild\harness-anything') /E /MT:16 /NFL /NDL /NJH /NP 2>&1 | Select-Object -Last 2 | ForEach-Object { L ('      robocopy harness: ' + (San ([string]$_))) }
}
finally { & net use $fshare /delete 2>&1 | Out-Null }

$null = & ssh @sshBase ($duser + '@' $desktop) 'schtasks /end /tn wpsdl 2>nul & taskkill /f /im curl.exe 2>nul & schtasks /delete /tn wpsdl /f 2>nul' 2>&1
Start-Sleep -Seconds 3
$mk = & ssh @sshBase ($duser + '@' $desktop) 'schtasks /create /tn wpsdl /tr F:\fig1_rebuild\wpsdl.cmd /sc once /st 23:59 /f' 2>&1
L ('   schtasks create: ' + (San ((($mk | Out-String).Trim()) -replace "`r?`n", ' | ')))
$rn = & ssh @sshBase ($duser + '@' $desktop) 'schtasks /run /tn wpsdl' 2>&1
L ('   schtasks run: ' + (San ((($rn | Out-String).Trim()) -replace "`r?`n", ' | ')))

# ---------------- C. wait + report growth ----------------
Start-Sleep -Seconds 240
$sz = & ssh @sshBase ($duser + '@' $desktop) 'dir F:\fig1_rebuild\wps_setup.partial 2>nul | findstr partial' 2>&1
foreach ($ln in @($sz)) { L ('   after 240s: ' + (San ([string]$ln))) }
$dl2 = & ssh @sshBase ($duser + '@' $desktop) 'type F:\fig1_rebuild\wps_download.log 2>nul' 2>&1
foreach ($ln in @($dl2 | Select-Object -Last 3)) { if ($ln) { L ('   log: ' + (San ([string]$ln))) } }
L '--- task t110 done ---'
exit 0
