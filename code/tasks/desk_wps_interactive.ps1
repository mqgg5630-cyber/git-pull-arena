# desk_wps_interactive.ps1 - runs ON THE DESKTOP inside the INTERACTIVE
# session (via scheduled task wpstest). r151 proved COM works up to class
# lookup but the server launch fails with 0x80080005 in the headless sshd
# session - WPS 12 needs an interactive session. This script: COM verify
# (cold, then warm wpp.exe), pip harness install, writer/impress smoke,
# the 12-slide deck build + verify. Everything is logged to
# F:\fig1_rebuild\harness_results\interactive_log.txt and ends with the
# INTERACTIVE-DONE marker. ASCII-only.

$ErrorActionPreference = 'Continue'

$logFile = 'F:\fig1_rebuild\harness_results\interactive_log.txt'
$results = 'F:\fig1_rebuild\harness_results'

function Log([string]$m) {
    $line = ('{0} {1}' -f (Get-Date -Format 'HH:mm:ss'), $m)
    try { Add-Content -LiteralPath $logFile -Value $line -Encoding ASCII } catch { }
}

try { Remove-Item -LiteralPath $logFile -Force -ErrorAction Stop } catch { }
Log '=== interactive WPS harness session start ==='
Set-Location -LiteralPath $results

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

# ---------------- 1. COM verify (interactive session) ----------------
$kwpp = TryCom 'KWPP.Application'
Log ('COM KWPP cold: ' + $kwpp)
if ($kwpp -notmatch '^OK') {
    $office6 = $null
    foreach ($vd in @(Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Kingsoft\WPS Office') -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d' } | Sort-Object Name -Descending)) {
        $o6 = Join-Path $vd.FullName 'office6'
        if (Test-Path -LiteralPath $o6) { $office6 = $o6; break }
    }
    if ($office6) {
        Log 'warm-starting wpp.exe + wps.exe...'
        try { Start-Process -FilePath (Join-Path $office6 'wpp.exe') -ErrorAction Stop | Out-Null } catch { Log ('wpp start fail: ' + $_.Exception.Message) }
        try { Start-Process -FilePath (Join-Path $office6 'wps.exe') -ErrorAction Stop | Out-Null } catch { }
        Start-Sleep -Seconds 15
        $alive = @(Get-Process -Name wpp -ErrorAction SilentlyContinue).Count
        Log ('wpp.exe processes: ' + $alive)
        $kwpp = TryCom 'KWPP.Application'
        Log ('COM KWPP warm: ' + $kwpp)
    }
}
$kwps = TryCom 'KWPS.Application'
$ket = TryCom 'KET.Application'
Log ('COM KWPS: ' + $kwps)
Log ('COM KET: ' + $ket)
if (($kwpp -notmatch '^OK') -and ($kwps -notmatch '^OK') -and ($ket -notmatch '^OK')) {
    Log 'INTERACTIVE-RESULT: COM-FAIL'
    Log 'INTERACTIVE-DONE'
    exit 2
}

# ---------------- 2. python + harness install ----------------
$pyexe = ''
try { $null = & py -3.12 --version 2>&1; if ($LASTEXITCODE -eq 0) { $pyexe = 'py -3.12' } } catch { }
if (-not $pyexe) { $pyexe = 'python' }
Log ('python: ' + $pyexe)
$haDir = 'F:\fig1_rebuild\harness-anything'
$vendor = $haDir + '\vendor_wheels'
$o1 = Invoke-Expression ($pyexe + ' -m pip install --no-index --find-links ' + $vendor + ' setuptools wheel packaging 2>&1')
Log ('pip base: ' + ((@($o1 | Select-Object -Last 1) -join ' ')))
$o2 = Invoke-Expression ($pyexe + ' -m pip install --no-index --no-build-isolation --find-links ' + $vendor + ' ' + $haDir + ' 2>&1')
Log ('pip harness: ' + ((@($o2 | Select-Object -Last 2) -join ' | ')))
$hc = Invoke-Expression ($pyexe + ' -c "import win32com.client" 2>&1')
Log ('pywin32: ' + $(if ($LASTEXITCODE -eq 0) { 'OK' } else { 'FAIL' }))

# ---------------- 3. smoke tests ----------------
$o = @()
$o += ('w-new: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps document new --type writer --name harnesssmoke -o proj_writer.json 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
$o += ('w-head: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps --project proj_writer.json writer add-heading -t HarnessSmokeTest -l 1 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
$o += ('w-para: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps --project proj_writer.json writer add-paragraph -t EditableParagraphViaWpsComOnDesktop. 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
$o += ('w-exp: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps --project proj_writer.json export render test_writer.docx -p docx 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
$o += ('i-new: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps document new --type impress --name harnesspptx -o proj_impress.json 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
$o += ('i-slide: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps --project proj_impress.json impress add-slide -t HarnessPPTXTest -c EditableBodyViaWpsCom 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
$o += ('i-elem: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps --project proj_impress.json impress add-element 0 --type text_box --text HelloEditablePptx 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
$o += ('i-exp: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps --project proj_impress.json export render test_impress.pptx -p pptx 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
foreach ($ln in $o) { if ($ln) { Log ($ln.Substring(0, [Math]::Min(300, $ln.Length))) } }
foreach ($f in @('test_writer.docx', 'test_impress.pptx')) {
    if (Test-Path -LiteralPath ($results + '\' + $f)) { Log ('produced: ' + $f + ' ' + [math]::Round((Get-Item ($results + '\' + $f)).Length/1KB) + 'KB') }
    else { Log ('MISSING: ' + $f) }
}

# ---------------- 4. the 12-slide deck ----------------
Log 'building 12-slide deck...'
$deckOut = Invoke-Expression ($pyexe + ' F:\fig1_rebuild\harness_results\desk_harness_deck.py 2>&1')
foreach ($ln in @($deckOut)) { if ($ln) { Log ($ln.ToString().Substring(0, [Math]::Min(300, $ln.ToString().Length))) } }
if (Test-Path -LiteralPath ($results + '\arena_report.pptx')) {
    Log ('DECK: arena_report.pptx ' + [math]::Round((Get-Item ($results + '\arena_report.pptx')).Length/1KB) + 'KB')
}
else { Log 'DECK: MISSING' }

# ---------------- 5. verify + cleanup ----------------
if (Test-Path -LiteralPath ($results + '\test_impress.pptx')) {
    $rv = Invoke-Expression ($pyexe + ' F:\fig1_rebuild\verify_pptx.py F:\fig1_rebuild\harness_results\test_impress.pptx 2>&1')
    foreach ($ln in @($rv | Select-Object -Last 3)) { Log ('verify: ' + $ln) }
}
foreach ($n in @('wps', 'et', 'wpp', 'wpsoffice', 'wpscloudlaunch')) {
    try { & taskkill /f /im ($n + '.exe') 2>&1 | Out-Null } catch { }
}
$deckOk = Test-Path -LiteralPath ($results + '\arena_report.pptx')
Log ('INTERACTIVE-RESULT: ' + $(if ($deckOk) { 'PASS' } else { 'PARTIAL' }))
Log 'INTERACTIVE-DONE'
