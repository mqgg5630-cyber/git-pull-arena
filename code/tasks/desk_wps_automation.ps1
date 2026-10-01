# desk_wps_automation.ps1 - runs ON THE DESKTOP via ssh (elevated). r151's
# manual registration pointed LocalServer32 at the bare exe - WPS then
# starts as a normal GUI app and never serves the COM class (0x80080005).
# Classic registry layouts and the Aliyun RPA docs show LocalServer32 must
# carry the /Automation flag. Fix: drop the stale HKCU entries, register
# under HKLM WITH /Automation, verify COM, and if healthy run the whole
# harness pipeline (smoke + 12-slide deck) inline; else fall back to the
# interactive wpstest task; else start a background download of the 32-bit
# build (25225) whose COM line still works. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop WPS COM /Automation registration + pipeline ---'

$haDir = 'F:\fig1_rebuild\harness-anything'
$results = 'F:\fig1_rebuild\harness_results'

$root = Join-Path $env:LOCALAPPDATA 'Kingsoft\WPS Office'
$office6 = $null
foreach ($vd in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d' } | Sort-Object Name -Descending)) {
    $o6 = Join-Path $vd.FullName 'office6'
    if (Test-Path -LiteralPath $o6) { $office6 = $o6; break }
}
if (-not $office6) { L '   [FAIL] office6 not found'; exit 2 }
L ('   office6: ' + (San $office6))
foreach ($n in @('wps', 'et', 'wpp', 'wpsoffice', 'wpscloudlaunch', 'ksolaunch')) {
    try { & taskkill /f /im ($n + '.exe') 2>&1 | Out-Null } catch { }
}
Start-Sleep -Seconds 2

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

# ---------------- A. drop stale HKCU registration from r151 ----------------
foreach ($k in @('HKCU:\SOFTWARE\Classes\KWPS.Application', 'HKCU:\SOFTWARE\Classes\KET.Application', 'HKCU:\SOFTWARE\Classes\KWPP.Application')) {
    if (Test-Path -LiteralPath $k) { Remove-Item -Recurse -Force -LiteralPath $k -ErrorAction SilentlyContinue; L ('   removed ' + $k) }
}
foreach ($c in @('{000209FF-0000-4b30-A977-D214852036FF}', '{45540001-5750-5300-4B49-4E47534F4655}', '{44720441-94BF-4940-926D-4F38FECF2A48}')) {
    foreach ($v2 in @(('HKCU:\SOFTWARE\Classes\CLSID\' + $c), ('HKCU:\SOFTWARE\Classes\WOW6432Node\CLSID\' + $c))) {
        if (Test-Path -LiteralPath $v2) { Remove-Item -Recurse -Force -LiteralPath $v2 -ErrorAction SilentlyContinue; L ('   removed ' + $v2) }
    }
}

# ---------------- B. register under HKLM WITH /Automation ----------------
$ksolaunch = Join-Path $office6 'ksolaunch.exe'
L ('   ksolaunch.exe present: ' + (Test-Path -LiteralPath $ksolaunch))
$map = @(
    @{ progid = 'KWPS.Application'; verpid = 'KWPS.Application'; clsid = '{000209FF-0000-4b30-A977-D214852036FF}'; flag = '/wps' },
    @{ progid = 'KET.Application';  verpid = 'KET.Application';  clsid = '{45540001-5750-5300-4B49-4E47534F4655}'; flag = '/et' },
    @{ progid = 'KWPP.Application'; verpid = 'KWPP.Application'; clsid = '{44720441-94BF-4940-926D-4F38FECF2A48}'; flag = '/wpp' }
)
foreach ($m in $map) {
    $exe = Join-Path $office6 ($m.flag.TrimStart('/') + '.exe')
    $cmd = ''
    if (Test-Path -LiteralPath $ksolaunch) { $cmd = '"' + $ksolaunch + '" /prometheus ' + $m.flag + ' /Automation' }
    else { $cmd = '"' + $exe + '" /Automation' }
    foreach ($view in @('HKLM:\SOFTWARE\Classes\CLSID', 'HKLM:\SOFTWARE\Classes\WOW6432Node\CLSID')) {
        $ck = $view + '\' + $m.clsid
        New-Item -Path ($ck + '\LocalServer32') -Force | Out-Null
        Set-ItemProperty -Path ($ck + '\LocalServer32') -Name '(default)' -Value $cmd
        New-Item -Path ($ck + '\ProgID') -Force | Out-Null
        Set-ItemProperty -Path ($ck + '\ProgID') -Name '(default)' -Value $m.progid
        New-Item -Path ($ck + '\VersionIndependentProgID') -Force | Out-Null
        Set-ItemProperty -Path ($ck + '\VersionIndependentProgID') -Name '(default)' -Value $m.verpid
    }
    $pk = 'HKLM:\SOFTWARE\Classes\' + $m.progid
    New-Item -Path ($pk + '\CLSID') -Force | Out-Null
    Set-ItemProperty -Path ($pk + '\CLSID') -Name '(default)' -Value $m.clsid
    L ('   registered ' + $m.progid + ' -> ' + $cmd)
}

# ---------------- C. COM verify (headless) ----------------
$comOk = $false
foreach ($pg in @('KWPS.Application', 'KET.Application', 'KWPP.Application')) {
    $r = TryCom $pg
    L ('   COM ' + $pg + ': ' + $r)
    if ($r -match '^OK') { $comOk = $true }
}

if (-not $comOk) {
    L '   headless COM failed - trying interactive wpstest rerun (fixed registration)...'
    try {
        Start-ScheduledTask -TaskName 'wpstest' -ErrorAction Stop
        L '   wpstest restarted'
    } catch { L ('   wpstest start failed: ' + (San $_.Exception.Message)) }
    $deadline = (Get-Date).AddMinutes(9)
    $verdict = ''
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 30
        $log = @(Get-Content -LiteralPath ($results + '\interactive_log.txt') -ErrorAction SilentlyContinue)
        $txt = $log -join ' '
        if ($txt -match 'INTERACTIVE-DONE') { $verdict = $txt; break }
    }
    if ($verdict) {
        foreach ($ln in @($log | Select-Object -Last 25)) { L ('   | ' + (San ([string]$ln))) }
        if ($verdict -match 'INTERACTIVE-RESULT: PASS') { $comOk = $true }
    }
    else { L '   wpstest did not finish within 9 min' }
}

# ---------------- D. inline pipeline if COM healthy ----------------
if ($comOk -and (Test-Path -LiteralPath ($results + '\arena_report.pptx')) -and -not ($verdict)) {
    L '   headless COM OK - running pipeline inline'
}
if ($comOk -and -not (Test-Path -LiteralPath ($results + '\arena_report.pptx'))) {
    L '   running harness pipeline inline (headless)...'
    $pyexe = ''
    try { $null = & py -3.12 --version 2>&1; if ($LASTEXITCODE -eq 0) { $pyexe = 'py -3.12' } } catch { }
    if (-not $pyexe) { $pyexe = 'python' }
    $vendor = $haDir + '\vendor_wheels'
    $o1 = Invoke-Expression ($pyexe + ' -m pip install --no-index --find-links ' + $vendor + ' setuptools wheel packaging 2>&1')
    L ('   pip base: ' + ((@($o1 | Select-Object -Last 1) -join ' ')))
    $o2 = Invoke-Expression ($pyexe + ' -m pip install --no-index --no-build-isolation --find-links ' + $vendor + ' ' + $haDir + ' 2>&1')
    L ('   pip harness: ' + ((@($o2 | Select-Object -Last 2) -join ' | ')))
    Set-Location -LiteralPath $results
    $deckOut = Invoke-Expression ($pyexe + ' F:\fig1_rebuild\harness_results\desk_harness_deck.py 2>&1')
    foreach ($ln in @($deckOut)) { if ($ln) { L ('   deck| ' + (San ($ln.ToString().Substring(0, [Math]::Min(240, $ln.ToString().Length))))) } }
}

# ---------------- E. fallback: 32-bit build download ----------------
if (-not $comOk) {
    L '   COM dead on this build (known 22525 regression) - starting 32-bit build download...'
    $wcmd = 'F:\fig1_rebuild\wpsdl32.cmd'
    $lines = @(
        '@echo off',
        'set HTTP_PROXY=',
        'set HTTPS_PROXY=',
        'set ALL_PROXY=',
        'set NO_PROXY=*',
        'set http_proxy=',
        'set https_proxy=',
        'set all_proxy=',
        'set no_proxy=*',
        'set URL=https://official-package.wpscdn.cn/wps/download/WPS_Setup_25225.exe',
        'set PART=F:\fig1_rebuild\wps_setup32.partial',
        'set OUT=F:\fig1_rebuild\wps_setup32.exe',
        'del /f /q %PART% 2>nul',
        'echo start32 %DATE% %TIME% >> F:\fig1_rebuild\wps_download.log',
        'set TRIES=0',
        ':loop',
        'set /a TRIES+=1',
        'curl.exe --noproxy "*" -L -C - -o %PART% --max-time 1500 --connect-timeout 20 -sS %URL% >> F:\fig1_rebuild\wps_download.log 2>&1',
        'for %%A in (%PART%) do set SZ=%%~zA',
        'echo try32 %TRIES% size=%SZ% %DATE% %TIME% >> F:\fig1_rebuild\wps_download.log',
        'if %SZ% GEQ 280000000 goto done',
        'if %TRIES% GEQ 60 goto giveup',
        'timeout /t 10 /nobreak >nul',
        'goto loop',
        ':done',
        'move /y %PART% %OUT%',
        'echo done32 size=%SZ% %DATE% %TIME% >> F:\fig1_rebuild\wps_download.log',
        'exit /b 0',
        ':giveup',
        'echo gaveup32 size=%SZ% %DATE% %TIME% >> F:\fig1_rebuild\wps_download.log',
        'exit /b 1'
    )
    [IO.File]::WriteAllLines($wcmd, $lines, (New-Object System.Text.ASCIIEncoding))
    $null = & schtasks /end /tn wpsdl32 2>$null
    $null = & schtasks /delete /tn wpsdl32 /f 2>$null
    $null = & schtasks /create /tn wpsdl32 /tr $wcmd /sc once /st 23:59 /f 2>&1
    $null = & schtasks /run /tn wpsdl32 2>&1
    L '   wpsdl32 background task started (WPS_Setup_25225.exe, 273MB)'
    L '   NEXT ROUND: silent-install the 32-bit build over this one and retest COM'
    exit 2
}

if (Test-Path -LiteralPath ($results + '\arena_report.pptx')) {
    L ('   DECK OK: ' + $results + '\arena_report.pptx ' + [math]::Round((Get-Item -LiteralPath ($results + '\arena_report.pptx')).Length/1KB) + 'KB')
}
else { L '   deck still missing (see pipeline output above)' }
L '--- desktop /Automation round done ---'
