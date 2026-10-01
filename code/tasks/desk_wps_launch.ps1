# desk_wps_launch.ps1 - runs ON THE DESKTOP via ssh. The silent installer
# laid down files (LOCALAPPDATA Kingsoft WPS Office exists) but never
# registered COM ProgIDs - modern WPS likely completes registration on
# first app launch. Plan: inventory the install dir, launch wps.exe via an
# INTERACTIVE scheduled task (headless ssh launches may be blocked from
# first-run UI), poll ProgIDs, verify COM, then (if healthy) harness
# install + writer/impress smoke tests. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop WPS first-launch registration + harness smoke ---'

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

# ---------------- A. inventory the install dir ----------------
$root = Join-Path $env:LOCALAPPDATA 'Kingsoft\WPS Office'
$office6 = $null
$mainExe = $null
if (Test-Path -LiteralPath $root) {
    L ('   --- ' + $root + ' ---')
    foreach ($d in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)) { L ('      dir: ' + (San $d.Name)) }
    foreach ($vd in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d' } | Sort-Object Name -Descending)) {
        $o6 = Join-Path $vd.FullName 'office6'
        if (Test-Path -LiteralPath $o6) {
            $office6 = $o6
            L ('      version dir: ' + (San $vd.Name) + ' (office6 found)')
            break
        }
    }
    if (-not $office6) {
        foreach ($f in @(Get-ChildItem -LiteralPath $root -Recurse -Depth 2 -Filter 'wps.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 3)) {
            L ('      wps.exe at: ' + (San $f.FullName) + ' v' + (San ([string]$f.VersionInfo.ProductVersion)))
            $office6 = Split-Path $f.FullName
        }
    }
    if ($office6) {
        foreach ($e in @('wps.exe', 'et.exe', 'wpp.exe', 'wpspdf.exe', 'ksomisc.exe', 'wpsoffice.exe', 'kwpsagent.exe')) {
            $f = Join-Path $office6 $e
            if (Test-Path -LiteralPath $f) { L ('      ' + $e + ' OK v' + (San ([string](Get-Item -LiteralPath $f).VersionInfo.ProductVersion))) }
        }
        $mainExe = Join-Path $office6 'wps.exe'
        if (-not (Test-Path -LiteralPath $mainExe)) {
            foreach ($alt in @('wpsoffice.exe', 'wpscloudlaunch.exe')) {
                $f = Join-Path $office6 $alt
                if (Test-Path -LiteralPath $f) { $mainExe = $f; break }
            }
        }
    }
}
else { L '   [FAIL] install dir still missing' }

# ---------------- B. interactive launch ----------------
if (-not (Have-Wps)) {
    if ($mainExe -and (Test-Path -LiteralPath $mainExe)) {
        L ('   launching (interactive task): ' + $mainExe)
        $la = New-ScheduledTaskAction -Execute $mainExe
        $pr = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
        $st = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
        try {
            Register-ScheduledTask -TaskName 'wpslaunch' -Action $la -Principal $pr -Settings $st -Force | Out-Null
            Start-ScheduledTask -TaskName 'wpslaunch'
            L '   wpslaunch task started'
        } catch { L ('   [FAIL] launch task: ' + (San $_.Exception.Message)) }
        $poll = 0
        while ($poll -lt 180) {
            Start-Sleep -Seconds 15; $poll += 15
            if (Have-Wps) { break }
        }
        L ('   ProgID poll ' + $poll + 's: registered=' + (Have-Wps))
    }
    else { L '   [FAIL] no main exe found to launch' }
}
else { L '   WPS ProgIDs already present' }

# ---------------- C. COM verify ----------------
$comOk = $false
foreach ($pg in @('KWPS.Application', 'KET.Application', 'KWPP.Application')) {
    $r = TryCom $pg
    L ('   COM ' + $pg + ': ' + $r)
    if ($r -match '^OK') { $comOk = $true }
}

if (-not $comOk) {
    L '   first-run diagnostics:'
    foreach ($lg in @(Get-ChildItem (Join-Path $env:APPDATA 'Kingsoft') -Recurse -Depth 2 -Filter '*.log' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3)) {
        L ('      ' + (San $lg.FullName) + ' (' + $lg.Length + 'B)')
    }
    foreach ($p in @(Get-Process -Name wps, et, wpp, wpsoffice -ErrorAction SilentlyContinue)) { L ('      proc: ' + (San $p.ProcessName) + ' pid=' + $p.Id) }
    exit 2
}

# ---------------- D. harness install + smoke ----------------
$pyexe = ''
try { $null = & py -3.12 --version 2>&1; if ($LASTEXITCODE -eq 0) { $pyexe = 'py -3.12' } } catch { }
if (-not $pyexe) { $pyexe = 'python' }
$vendor = $haDir + '\vendor_wheels'
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

# ---------------- E. cleanup ----------------
foreach ($n in @('wps', 'et', 'wpp', 'wpsoffice', 'wpscloudlaunch')) {
    try { & taskkill /f /im ($n + '.exe') 2>&1 | Out-Null } catch { }
}
L '--- desktop WPS launch round done ---'
