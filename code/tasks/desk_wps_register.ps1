# desk_wps_register.ps1 - runs ON THE DESKTOP via ssh. WPS 12.1.0.22525 is
# fully installed (all office6 exes present) but the COM ProgIDs were never
# registered. Plan: kill stray WPS processes, search the registry for any
# Kingsoft COM keys the installer DID write, try the classic /regserver
# self-registration on each exe, and if that fails write the HKCU COM
# entries manually (ProgID + CLSID + LocalServer32). Then COM-verify and,
# if healthy, run the harness smoke tests. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop WPS COM registration repair ---'

$root = Join-Path $env:LOCALAPPDATA 'Kingsoft\WPS Office'
$office6 = $null
foreach ($vd in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d' } | Sort-Object Name -Descending)) {
    $o6 = Join-Path $vd.FullName 'office6'
    if (Test-Path -LiteralPath $o6) { $office6 = $o6; break }
}
if (-not $office6) { L '   [FAIL] office6 not found'; exit 2 }
L ('   office6: ' + (San $office6))

# ---------------- 0. kill stray WPS ----------------
foreach ($n in @('wps', 'et', 'wpp', 'wpsoffice', 'wpscloudlaunch')) {
    try { & taskkill /f /im ($n + '.exe') 2>&1 | Out-Null } catch { }
}
Start-Sleep -Seconds 3

function Have-ProgId([string]$pg) {
    (Test-Path ('HKLM:\SOFTWARE\Classes\' + $pg)) -or (Test-Path ('HKCU:\SOFTWARE\Classes\' + $pg))
}
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

# ---------------- 1. what did the installer write? ----------------
L '   --- registry search (Kingsoft COM keys) ---'
$hits = 0
foreach ($base in @('HKLM:\SOFTWARE\Classes', 'HKCU:\SOFTWARE\Classes')) {
    foreach ($pat in @('KWPP*', 'KWPS*', 'KET*')) {
        foreach ($k in @(Get-ChildItem -Path ($base + '\' + $pat) -ErrorAction SilentlyContinue | Select-Object -First 6)) {
            $clsid = ''
            try { $clsid = [string](Get-ItemProperty -LiteralPath ($k.PSPath + '\CLSID') -ErrorAction Stop).'(default)' } catch { }
            L ('      ' + $base.Replace(':SOFTWARE\Classes', '') + '\' + (San $k.PSChildName) + ' -> CLSID=' + (San $clsid))
            $hits++
        }
    }
}
if ($hits -eq 0) { L '      (no ProgID keys found)' }

# LocalServer32 entries pointing into the Kingsoft dir
$ls32 = 0
foreach ($base in @('HKLM:\SOFTWARE\Classes\CLSID', 'HKCU:\SOFTWARE\Classes\CLSID')) {
    foreach ($k in @(Get-ChildItem -Path $base -ErrorAction SilentlyContinue)) {
        $ls = $null
        try { $ls = [string](Get-ItemProperty -LiteralPath ($k.PSPath + '\LocalServer32') -ErrorAction Stop).'(default)' } catch { }
        if ($ls -and $ls -match 'Kingsoft') {
            L ('      CLSID ' + (San $k.PSChildName) + ' LocalServer32: ' + (San $ls))
            $ls32++
            if ($ls32 -ge 8) { break }
        }
    }
    if ($ls32 -ge 8) { break }
}
if ($ls32 -eq 0) { L '      (no Kingsoft LocalServer32 entries)' }

# ---------------- 2. /regserver attempts ----------------
if (-not (Have-ProgId 'KWPP.Application')) {
    foreach ($exe in @('wps.exe', 'et.exe', 'wpp.exe')) {
        $f = Join-Path $office6 $exe
        if (-not (Test-Path -LiteralPath $f)) { continue }
        try {
            $p = Start-Process -FilePath $f -ArgumentList '/regserver' -PassThru -ErrorAction Stop
            $null = $p.WaitForExit(60000)
            L ('   ' + $exe + ' /regserver exit=' + $(try { $p.ExitCode } catch { '?' }))
        } catch { L ('   ' + $exe + ' /regserver failed: ' + (San $_.Exception.Message)) }
        Start-Sleep -Seconds 2
    }
    L ('   after /regserver: KWPP=' + (Have-ProgId 'KWPP.Application') + ' KWPS=' + (Have-ProgId 'KWPS.Application') + ' KET=' + (Have-ProgId 'KET.Application'))
}

# ---------------- 3. manual HKCU registration fallback ----------------
if (-not (Have-ProgId 'KWPP.Application')) {
    L '   writing manual HKCU COM registration...'
    $map = @(
        @{ progid = 'KWPS.Application'; clsid = '{000209FF-0000-4b30-A977-D214852036FF}'; exe = 'wps.exe' },
        @{ progid = 'KET.Application';  clsid = '{45540001-5750-5300-4B49-4E47534F4655}'; exe = 'et.exe' },
        @{ progid = 'KWPP.Application'; clsid = '{44720441-94BF-4940-926D-4F38FECF2A48}'; exe = 'wpp.exe' }
    )
    foreach ($m in $map) {
        $exePath = Join-Path $office6 $m.exe
        if (-not (Test-Path -LiteralPath $exePath)) { L ('   [WARN] missing ' + $m.exe); continue }
        foreach ($view in @('HKCU:\SOFTWARE\Classes\CLSID', 'HKCU:\SOFTWARE\Classes\WOW6432Node\CLSID')) {
            $ck = $view + '\' + $m.clsid
            New-Item -Path ($ck + '\LocalServer32') -Force | Out-Null
            Set-ItemProperty -Path ($ck + '\LocalServer32') -Name '(default)' -Value ('"' + $exePath + '"')
            Set-ItemProperty -Path $ck -Name '(default)' -Value ('Kingsoft ' + $m.exe + ' Application')
            New-Item -Path ($ck + '\ProgID') -Force | Out-Null
            Set-ItemProperty -Path ($ck + '\ProgID') -Name '(default)' -Value $m.progid
        }
        $pk = 'HKCU:\SOFTWARE\Classes\' + $m.progid
        New-Item -Path ($pk + '\CLSID') -Force | Out-Null
        Set-ItemProperty -Path ($pk + '\CLSID') -Name '(default)' -Value $m.clsid
        Set-ItemProperty -Path $pk -Name '(default)' -Value ($m.progid + ' (Kingsoft)')
        L ('   registered ' + $m.progid + ' -> ' + $m.exe)
    }
}

# ---------------- 4. COM verify ----------------
$comOk = $false
foreach ($pg in @('KWPS.Application', 'KET.Application', 'KWPP.Application')) {
    $r = TryCom $pg
    L ('   COM ' + $pg + ': ' + $r)
    if ($r -match '^OK') { $comOk = $true }
}

if (-not $comOk) {
    L '   [FAIL] COM still not working after registration attempts'
    exit 2
}

# ---------------- 5. harness smoke ----------------
$pyexe = ''
try { $null = & py -3.12 --version 2>&1; if ($LASTEXITCODE -eq 0) { $pyexe = 'py -3.12' } } catch { }
if (-not $pyexe) { $pyexe = 'python' }
$haDir = 'F:\fig1_rebuild\harness-anything'
$vendor = $haDir + '\vendor_wheels'
$results = 'F:\fig1_rebuild\harness_results'
$o1 = Invoke-Expression ($pyexe + ' -m pip install --no-index --find-links ' + $vendor + ' setuptools wheel packaging 2>&1')
foreach ($ln in @($o1 | Select-Object -Last 2)) { L ('   ' + (San ([string]$ln))) }
$o2 = Invoke-Expression ($pyexe + ' -m pip install --no-index --no-build-isolation --find-links ' + $vendor + ' ' + $haDir + ' 2>&1')
foreach ($ln in @($o2 | Select-Object -Last 4)) { L ('   ' + (San ([string]$ln))) }
$hc = Invoke-Expression ($pyexe + ' -c "import win32com.client" 2>&1')
L ('   pywin32 import: ' + $(if ($LASTEXITCODE -eq 0) { 'OK' } else { (San ([string](@($hc) -join ' '))) }))

New-Item -ItemType Directory -Force -Path $results | Out-Null
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

foreach ($n in @('wps', 'et', 'wpp', 'wpsoffice', 'wpscloudlaunch')) {
    try { & taskkill /f /im ($n + '.exe') 2>&1 | Out-Null } catch { }
}
L '--- desktop WPS registration repair done ---'
