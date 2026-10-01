# t108_laptop_harness_patch2.ps1 - round 144 task: (task 2)
# A. apply the engine-probe patch to the INSTALLED harness copy (repo copy
#    already patched via git): healthy-WPP-engine candidate chain +
#    Slides(1)->Add fallback
# B. rerun the impress flow -> editable test_impress.pptx + python reopen
# C. laptop CDN speed probe (both WPS setup URLs, 5MB range sample)
# D. re-stage patched harness + scripts on F$, drop the stale 67MB partial
#    setup, and launch a detached resume-loop download task on the desktop
# ASCII-only. Runs on the LAPTOP.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t108: harness engine patch + impress + desktop download task ---'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$haDir = Join-Path $repoRoot 'skills\harness-anything'
$workDir = Join-Path $repoRoot 'results\harness_wps\laptop'

# ================= A. patch installed harness copy =================
L '--- A: patch_harness.py ---'
$po = & python (Join-Path $repoRoot 'code\tasks\patch_harness.py') 2>&1
foreach ($ln in @($po)) { L ('   ' + (San ([string]$ln))) }

# ================= B. impress flow =================
L '--- B: impress flow (engine probe + editable pptx) ---'
$dj = Start-Job -ScriptBlock {
    param($wd)
    Set-Location -LiteralPath $wd
    $o = @()
    $o += ('new: ' + ((& python -m cli_anything.wps document new --type impress --name 'harness pptx' -o proj_impress.json 2>&1 | Out-String).Trim() -replace "`r?`n", ' | '))
    $o += ('slide: ' + ((& python -m cli_anything.wps --project proj_impress.json impress add-slide -t 'Harness PPTX Test' -c 'Editable body via WPS COM' 2>&1 | Out-String).Trim() -replace "`r?`n", ' | '))
    $o += ('elem: ' + ((& python -m cli_anything.wps --project proj_impress.json impress add-element 0 --type text_box --text 'Hello editable pptx' 2>&1 | Out-String).Trim() -replace "`r?`n", ' | '))
    $o += ('export: ' + ((& python -m cli_anything.wps --project proj_impress.json export render test_impress.pptx -p pptx 2>&1 | Out-String).Trim() -replace "`r?`n", ' | '))
    $o
} -ArgumentList $workDir
if (-not (Wait-Job $dj -Timeout 420)) { Stop-Job $dj -Force; L '   [FAIL] impress flow timed out' }
else { foreach ($ln in @(Receive-Job $dj)) { if ($ln) { L ('   ' + (San ([string]$ln))) } } }
Remove-Job $dj -Force -ErrorAction SilentlyContinue

$pptx = Join-Path $workDir 'test_impress.pptx'
if (Test-Path -LiteralPath $pptx) {
    L ('   pptx: ' + [math]::Round((Get-Item -LiteralPath $pptx).Length/1KB) + 'KB')
    $rv = & python (Join-Path $repoRoot 'code\tasks\verify_pptx.py') $pptx 2>&1
    foreach ($ln in @($rv | Select-Object -Last 4)) { L ('   ' + (San ([string]$ln))) }
}
else { L '   [FAIL] test_impress.pptx still not produced' }

# ================= C. laptop CDN speed probe =================
L '--- C: CDN speed probe (laptop, 5MB sample) ---'
foreach ($u in @('https://official-package.wpscdn.cn/wps/download/WPS_Setup_X64_22525.exe', 'https://official-package.wpscdn.cn/wps/download/WPS_Setup_25225.exe')) {
    $sp = (& curl.exe -L -s -o NUL --max-time 60 -r 0-5242879 -w '%{speed_download}' $u 2>$null | Out-String).Trim()
    if ($sp) { L ('   ' + (San ($u -replace '.*/', '')) + ': ' + [math]::Round([double]$sp/1KB) + ' KB/s') }
    else { L ('   ' + (San ($u -replace '.*/', '')) + ': probe failed') }
}

# ================= D. stage + desktop download task =================
L '--- D: staging + desktop wpsdl task ---'
$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
try {
    if (Test-Path ($fshare + '\fig1_rebuild\wps_setup.exe')) { Remove-Item ($fshare + '\fig1_rebuild\wps_setup.exe') -Force; L '   stale partial wps_setup.exe removed' }
    & robocopy $haDir ($fshare + '\fig1_rebuild\harness-anything') /E /MT:16 /NFL /NDL /NJH /NP 2>&1 | Select-Object -Last 2 | ForEach-Object { L ('      robocopy: ' + (San ([string]$_))) }
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\verify_pptx.py') -Destination ($fshare + '\fig1_rebuild\verify_pptx.py') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\desk_wps_install.ps1') -Destination ($fshare + '\fig1_rebuild\desk_wps_install.ps1') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\wpsdl.cmd') -Destination ($fshare + '\fig1_rebuild\wpsdl.cmd') -Force
    L '   staged harness + scripts (incl. wpsdl.cmd)'
}
finally { & net use $fshare /delete 2>&1 | Out-Null }

$mk = & ssh @sshBase ($duser + '@' + $desktop) 'schtasks /create /tn wpsdl /tr F:\fig1_rebuild\wpsdl.cmd /sc once /st 23:59 /f' 2>&1
L ('   schtasks create: ' + (San ((($mk | Out-String).Trim()) -replace "`r?`n", ' | ')))
$rn = & ssh @sshBase ($duser + '@' + $desktop) 'schtasks /run /tn wpsdl' 2>&1
L ('   schtasks run: ' + (San ((($rn | Out-String).Trim()) -replace "`r?`n", ' | ')))
Start-Sleep -Seconds 20
$sz = (& ssh @sshBase ($duser + '@' + $desktop) 'dir F:\fig1_rebuild\wps_setup.partial 2>nul | findstr partial' 2>&1 | Out-String).Trim()
L ('   after 20s: ' + (San ($sz -replace "`r?`n", ' | ')))
L '--- task t108 done ---'
exit 0
