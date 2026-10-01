# desk_wps_install2.ps1 - runs ON THE DESKTOP via ssh. v2: the WPS personal
# installer ignores bare /S (r148 proved it: exit 0, nothing installed).
# Community-verified silent switches: /s -agreelicense (lowercase s).
# Also: pip --no-build-isolation needs setuptools/wheel in the TARGET env
# FIRST (r148 failed with BackendUnavailable). ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop WPS install v2 (correct silent switches) ---'

$setup = 'F:\fig1_rebuild\wps_setup.exe'
$haDir = 'F:\fig1_rebuild\harness-anything'
$results = 'F:\fig1_rebuild\harness_results'

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
function Have-Wps {
    (Test-Path 'HKLM:\SOFTWARE\Classes\KWPP.Application') -or (Test-Path 'HKCU:\SOFTWARE\Classes\KWPP.Application') -or (Test-Path 'HKLM:\SOFTWARE\Classes\KWPS.Application') -or (Test-Path 'HKCU:\SOFTWARE\Classes\KWPS.Application')
}

# ---------------- 0. python ----------------
$pyexe = ''
try { $null = & py -3.12 --version 2>&1; if ($LASTEXITCODE -eq 0) { $pyexe = 'py -3.12' } } catch { }
if (-not $pyexe) { try { $null = & python --version 2>&1; if ($LASTEXITCODE -eq 0) { $pyexe = 'python' } } catch { } }
if (-not $pyexe) { L '   [FAIL] no python found'; exit 2 }
L ('   python: ' + $pyexe)

# ---------------- 1. install WPS (correct switches) ----------------
if (Have-Wps) {
    L '   WPS already registered - skipping install'
}
else {
    L ('   setup: ' + [math]::Round((Get-Item -LiteralPath $setup).Length/1MB) + 'MB')
    $attempts = @(
        @{ flag = '/s -agreelicense'; note = 'community-verified lowercase' },
        @{ flag = '/S -agreelicense'; note = 'capital variant' }
    )
    $installed = $false
    foreach ($a in $attempts) {
        L ('   trying: wps_setup.exe ' + $a.flag + ' (' + $a.note + ')')
        try {
            $p = Start-Process -FilePath $setup -ArgumentList $a.flag -PassThru -ErrorAction Stop
            $w = 0
            while (-not $p.HasExited -and $w -lt 480) { Start-Sleep -Seconds 5; $w += 5; $p.Refresh() }
            L ('   installer: exited=' + $p.HasExited + ' code=' + $(try { $p.ExitCode } catch { '?' }) + ' waited=' + $w + 's')
        } catch { L ('   installer launch failed: ' + (San $_.Exception.Message)) }
        $poll = 0
        while ($poll -lt 300) {
            Start-Sleep -Seconds 15; $poll += 15
            if (Have-Wps) { break }
        }
        L ('   ProgID poll ' + $poll + 's: registered=' + (Have-Wps))
        if (Have-Wps) { $installed = $true; break }
    }
    if (-not $installed) {
        L '   [FAIL] silent install did not register WPS - diagnostics:'
        foreach ($lg in @((Join-Path $env:TEMP 'wps_install.log'), (Join-Path $env:TEMP 'wpsoffice_pinstall.log'))) {
            if (Test-Path -LiteralPath $lg) {
                L ('   --- ' + $lg + ' (tail 12) ---')
                foreach ($ln in @(Get-Content -LiteralPath $lg -Tail 12 -ErrorAction SilentlyContinue)) { L ('      ' + (San $ln)) }
            }
        }
        L '   --- temp WPS-ish logs ---'
        foreach ($f in @(Get-ChildItem $env:TEMP -Filter '*wps*' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 5)) { L ('      ' + (San $f.Name) + ' ' + $f.Length + 'B ' + $f.LastWriteTime.ToString('HH:mm:ss')) }
        $keys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')
        $apps = @(Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'WPS|Kingsoft' })
        L ('   uninstall entries matching WPS/Kingsoft: ' + $apps.Count)
        foreach ($a2 in $apps) { L ('      ' + (San ([string]$a2.DisplayName)) + ' v' + (San ([string]$a2.DisplayVersion))) }
        foreach ($d in @((Join-Path $env:LOCALAPPDATA 'Kingsoft\WPS Office'), 'C:\Program Files\Kingsoft\WPS Office', 'C:\Program Files (x86)\Kingsoft\WPS Office', (Join-Path $env:APPDATA 'Kingsoft'))) {
            if (Test-Path -LiteralPath $d) { L ('   dir exists: ' + $d) }
        }
        exit 2
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

# ---------------- 3. harness install (setuptools FIRST) ----------------
if (-not (Test-Path -LiteralPath ($haDir + '\setup.py'))) { L '   [FAIL] harness dir not staged'; exit 2 }
$vendor = $haDir + '\vendor_wheels'
$o1 = Invoke-Expression ($pyexe + ' -m pip install --no-index --find-links ' + $vendor + ' setuptools wheel packaging 2>&1')
foreach ($ln in @($o1 | Select-Object -Last 2)) { L ('   ' + (San ([string]$ln))) }
$o2 = Invoke-Expression ($pyexe + ' -m pip install --no-index --no-build-isolation --find-links ' + $vendor + ' ' + $haDir + ' 2>&1')
foreach ($ln in @($o2 | Select-Object -Last 4)) { L ('   ' + (San ([string]$ln))) }
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
if (Test-Path -LiteralPath ($results + '\test_impress.pptx')) {
    $rv = Invoke-Expression ($pyexe + ' F:\fig1_rebuild\verify_pptx.py F:\fig1_rebuild\harness_results\test_impress.pptx 2>&1')
    foreach ($ln in @($rv | Select-Object -Last 4)) { L ('   ' + (San ([string]$ln))) }
}
L '--- desktop WPS install v2 done ---'
