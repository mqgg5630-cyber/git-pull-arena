# desk_wps_install.ps1 - runs ON THE DESKTOP via ssh. Task 2 desktop half:
# silent-install WPS (setup staged on F: by the laptop), verify COM ProgIDs,
# offline-install the harness, run writer + impress editable tests, drop
# results into F:\fig1_rebuild\harness_results\. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop WPS install + harness test ---'

$setup = 'F:\fig1_rebuild\wps_setup.exe'
$haDir = 'F:\fig1_rebuild\harness-anything'
$results = 'F:\fig1_rebuild\harness_results'

# ---------------- 0. python ----------------
$pyexe = ''
try { $null = & py -3.12 --version 2>&1; if ($LASTEXITCODE -eq 0) { $pyexe = 'py -3.12' } } catch { }
if (-not $pyexe) {
    try { $null = & python --version 2>&1; if ($LASTEXITCODE -eq 0) { $pyexe = 'python' } } catch { }
}
if (-not $pyexe) { L '   [FAIL] no python 3.12 found'; exit 2 }
L ('   python: ' + $pyexe)
$pv = Invoke-Expression ($pyexe + ' -m pip --version 2>&1') | Select-Object -First 1
if (-not $pv) {
    L '   pip missing - ensurepip...'
    Invoke-Expression ($pyexe + ' -m ensurepip --default-pip 2>&1') | Select-Object -Last 2 | ForEach-Object { L ('      ' + (San ([string]$_))) }
}
else { L ('   ' + (San ([string]$pv))) }

function TryCom([string]$pg) {
    try {
        $k = New-Object -ComObject $pg
        try { $k.Visible = $false } catch { }
        $v = ''
        try { $v = [string]$k.Version } catch { }
        try { $k.Quit() } catch { }
        return 'OK v' + $v
    } catch {
        $hr = ''
        try { $hr = ('0x{0:X8}' -f $_.Exception.HResult) } catch { }
        return 'FAIL ' + $hr
    }
}

# ---------------- 1. install WPS ----------------
$haveWps = (Test-Path 'HKLM:\SOFTWARE\Classes\KWPP.Application') -or (Test-Path 'HKCU:\SOFTWARE\Classes\KWPP.Application')
if ($haveWps) {
    L '   WPS already registered - skipping install'
}
elseif (-not (Test-Path -LiteralPath $setup)) {
    L '   [FAIL] setup exe not staged'; exit 2
}
else {
    L ('   setup: ' + [math]::Round((Get-Item -LiteralPath $setup).Length/1MB) + 'MB')
    if ((Get-Item -LiteralPath $setup).Length -lt 200MB) { L '   [FAIL] setup too small - download incomplete, rerun wpsdl task'; exit 2 }
    foreach ($n in @('wps', 'et', 'wpp', 'wpscloudlaunch', 'wpscenter')) { try { & taskkill /f /im ($n + '.exe') 2>&1 | Out-Null } catch { } }
    try {
        $p = Start-Process -FilePath $setup -ArgumentList '/S' -PassThru -ErrorAction Stop
        $w = 0
        while (-not $p.HasExited -and $w -lt 600) { Start-Sleep -Seconds 5; $w += 5; $p.Refresh() }
        L ('   installer /S: exited=' + $p.HasExited + ' code=' + $(try { $p.ExitCode } catch { '?' }) + ' waited=' + $w + 's')
    } catch { L ('   installer launch failed: ' + (San $_.Exception.Message)) }
    $poll = 0
    while ($poll -lt 420) {
        Start-Sleep -Seconds 15; $poll += 15
        if ((Test-Path 'HKLM:\SOFTWARE\Classes\KWPP.Application') -or (Test-Path 'HKCU:\SOFTWARE\Classes\KWPP.Application')) { break }
    }
    L ('   ProgID poll ' + $poll + 's: KWPP=' + (Test-Path 'HKLM:\SOFTWARE\Classes\KWPP.Application') + '/' + (Test-Path 'HKCU:\SOFTWARE\Classes\KWPP.Application'))
    if (-not ((Test-Path 'HKLM:\SOFTWARE\Classes\KWPP.Application') -or (Test-Path 'HKCU:\SOFTWARE\Classes\KWPP.Application'))) {
        L '   /S failed - retrying detached without args...'
        try { Start-Process -FilePath $setup | Out-Null } catch { L ('   retry failed: ' + (San $_.Exception.Message)) }
        $poll = 0
        while ($poll -lt 480) {
            Start-Sleep -Seconds 20; $poll += 20
            if ((Test-Path 'HKLM:\SOFTWARE\Classes\KWPP.Application') -or (Test-Path 'HKCU:\SOFTWARE\Classes\KWPP.Application')) { break }
        }
        L ('   retry poll ' + $poll + 's done')
    }
}

# ---------------- 2. COM verify ----------------
foreach ($pg in @('KWPS.Application', 'KET.Application', 'KWPP.Application')) { L ('   COM ' + $pg + ': ' + (TryCom $pg)) }
if ((TryCom 'KWPP.Application') -notmatch '^OK') {
    foreach ($pg in @('wpp.Application', 'Kwpp.Application')) {
        $r = TryCom $pg
        L ('   COM alt ' + $pg + ': ' + $r)
        if ($r -match '^OK') { break }
    }
}

# ---------------- 3. harness install ----------------
if (-not (Test-Path -LiteralPath ($haDir + '\setup.py'))) { L '   [FAIL] harness dir not staged'; exit 2 }
$cmd = $pyexe + ' -m pip install --no-index --no-build-isolation --find-links ' + $haDir + '\vendor_wheels ' + $haDir + ' 2>&1'
$out = Invoke-Expression $cmd
foreach ($ln in @($out | Select-Object -Last 4)) { L ('   ' + (San ([string]$ln))) }
$hc = Invoke-Expression ($pyexe + ' -c "import win32com.client" 2>&1')
L ('   pywin32 import: ' + $(if ($LASTEXITCODE -eq 0) { 'OK' } else { (San ([string](@($hc) -join ' '))) }))

New-Item -ItemType Directory -Force -Path $results | Out-Null

# ---------------- 4. tests ----------------
$testCmd = {
    param($py, $res)
    Set-Location -LiteralPath $res
    $o = @()
    $o += ('w-new: ' + ((Invoke-Expression ($py + ' -m cli_anything.wps document new --type writer --name harnesssmoke -o proj_writer.json 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
    $o += ('w-head: ' + ((Invoke-Expression ($py + ' -m cli_anything.wps --project proj_writer.json writer add-heading -t HarnessSmokeTest -l 1 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
    $o += ('w-para: ' + ((Invoke-Expression ($py + ' -m cli_anything.wps --project proj_writer.json writer add-paragraph -t EditableParagraphViaWpsComOnDesktop. 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
    $o += ('w-exp: ' + ((Invoke-Expression ($py + ' -m cli_anything.wps --project proj_writer.json export render test_writer.docx -p docx 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
    $o += ('i-new: ' + ((Invoke-Expression ($py + ' -m cli_anything.wps document new --type impress --name harnesspptx -o proj_impress.json 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
    $o += ('i-slide: ' + ((Invoke-Expression ($py + ' -m cli_anything.wps --project proj_impress.json impress add-slide -t HarnessPPTXTest -c EditableBodyViaWpsCom 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
    $o += ('i-elem: ' + ((Invoke-Expression ($py + ' -m cli_anything.wps --project proj_impress.json impress add-element 0 --type text_box --text HelloEditablePptx 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
    $o += ('i-exp: ' + ((Invoke-Expression ($py + ' -m cli_anything.wps --project proj_impress.json export render test_impress.pptx -p pptx 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
    $o
}
$tj = Start-Job -ScriptBlock $testCmd -ArgumentList $pyexe, $results
if (-not (Wait-Job $tj -Timeout 600)) { Stop-Job $tj -Force; L '   [FAIL] tests timed out' }
else { foreach ($ln in @(Receive-Job $tj)) { if ($ln) { L ('   ' + (San ([string]$ln))) } } }
Remove-Job $tj -Force -ErrorAction SilentlyContinue

foreach ($f in @('test_writer.docx', 'test_impress.pptx')) {
    $p = Join-Path $results $f
    if (Test-Path -LiteralPath $p) { L ('   produced: ' + $f + ' ' + [math]::Round((Get-Item -LiteralPath $p).Length/1KB) + 'KB') }
    else { L ('   MISSING: ' + $f) }
}

# reopen verify via python (pywin32)
if (Test-Path -LiteralPath ($results + '\test_impress.pptx')) {
    $rv = Invoke-Expression ($pyexe + ' F:\fig1_rebuild\verify_pptx.py F:\fig1_rebuild\harness_results\test_impress.pptx 2>&1')
    foreach ($ln in @($rv | Select-Object -Last 6)) { L ('   ' + (San ([string]$ln))) }
}

L '--- desktop WPS install + harness test done ---'
