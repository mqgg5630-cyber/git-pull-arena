# t109_laptop_impress_retry.ps1 - round 145 task: (task 2, laptop)
# A. run the FIXED patch_harness.py (direct sys.path scan, no subprocess)
#    -> patches the installed site-packages copy
# B. rerun the impress flow -> editable test_impress.pptx + python reopen
# C. locate the laptop's real WPS 12 install root via the WORKING KET COM
#    object (app.Path) + report desktop wpsdl download progress
# ASCII-only. Runs on the LAPTOP.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t109: laptop impress retry (installed-copy patch) ---'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$workDir = Join-Path $repoRoot 'results\harness_wps\laptop'

# ================= A. patch installed copy =================
L '--- A: patch_harness.py (fixed locator) ---'
$po = & python (Join-Path $repoRoot 'code\tasks\patch_harness.py') 2>&1
foreach ($ln in @($po)) { L ('   ' + (San ([string]$ln))) }

# ================= B. impress flow =================
L '--- B: impress flow ---'
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

# ================= C. WPS install root + download progress =================
L '--- C: WPS root + desktop download progress ---'
try {
    $et = New-Object -ComObject KET.Application
    $p = [string]$et.Path
    $b = ''
    try { $b = [string]$et.Build } catch { }
    $et.Quit()
    L ('   KET install root: ' + (San $p) + ' build=' + (San $b))
    if ($p -and (Test-Path -LiteralPath $p)) {
        foreach ($e in @('wps.exe', 'et.exe', 'wpp.exe')) {
            $f = Join-Path $p $e
            if (Test-Path -LiteralPath $f) { L ('      ' + $e + ' OK v' + (San ([string](Get-Item -LiteralPath $f).VersionInfo.ProductVersion))) }
            else { L ('      ' + $e + ' MISSING') }
        }
    }
} catch { L ('   KET probe failed: ' + (San $_.Exception.Message)) }

$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$dl = & ssh @sshBase ($duser + '@' + $desktop) 'type F:\fig1_rebuild\wps_download.log 2>nul' 2>&1
foreach ($ln in @($dl | Select-Object -Last 4)) { L ('   wpsdl: ' + (San ([string]$ln))) }
$st = & ssh @sshBase ($duser + '@' + $desktop) 'dir F:\fig1_rebuild\wps_setup.* 2>nul | findstr wps_setup' 2>&1
foreach ($ln in @($st)) { L ('   files: ' + (San ([string]$ln))) }
L '--- task t109 done ---'
exit 0
