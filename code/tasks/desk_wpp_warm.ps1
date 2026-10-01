# desk_wpp_warm.ps1 - runs ON THE DESKTOP via ssh (elevated). Root cause of
# the Add() RPC failures: fresh KWPP launches (via ksolaunch) die on first
# COM call in the headless sshd session. r153 worked because a wpp.exe
# launched by the INTERACTIVE wpslaunch task was still running - COM
# Dispatch attached to that live instance across sessions. Replicate that:
# launch wpp.exe via an interactive task, keep it running, attach for the
# probe + deck + impress smoke, quit at the end. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop WPP warm-instance pipeline ---'

$haDir = 'F:\fig1_rebuild\harness-anything'
$results = 'F:\fig1_rebuild\harness_results'
Set-Location -LiteralPath $results

$pyexe = ''
try { $null = & py -3.12 --version 2>&1; if ($LASTEXITCODE -eq 0) { $pyexe = 'py -3.12' } } catch { }
if (-not $pyexe) { $pyexe = 'python' }
$vendor = $haDir + '\vendor_wheels'

function Kill-Wps {
    foreach ($n in @('wps', 'et', 'wpp', 'wpsoffice', 'wpscloudlaunch', 'ksolaunch', 'wpspdf')) {
        try { & taskkill /f /im ($n + '.exe') 2>&1 | Out-Null } catch { }
    }
    Start-Sleep -Seconds 6
}

$office6 = $null
foreach ($vd in @(Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Kingsoft\WPS Office') -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d' } | Sort-Object Name -Descending)) {
    $o6 = Join-Path $vd.FullName 'office6'
    if (Test-Path -LiteralPath $o6) { $office6 = $o6; break }
}
if (-not $office6) { L '   [FAIL] office6 not found'; exit 2 }
$wppExe = Join-Path $office6 'wpp.exe'

# ---------------- 0. clean + reinstall ----------------
Kill-Wps
$o = Invoke-Expression ($pyexe + ' -m pip install --force-reinstall --no-deps --no-index --no-build-isolation --find-links ' + $vendor + ' ' + $haDir + ' 2>&1')
foreach ($ln in @($o | Select-Object -Last 1)) { L ('   ' + (San ([string]$ln))) }

# ---------------- 1. warm wpp via interactive task ----------------
try {
    $la = New-ScheduledTaskAction -Execute $wppExe
    $pr = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
    $st = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
    Register-ScheduledTask -TaskName 'wpplaunch' -Action $la -Principal $pr -Settings $st -Force | Out-Null
    Start-ScheduledTask -TaskName 'wpplaunch'
    L '   wpplaunch started (interactive)'
} catch { L ('   [FAIL] wpplaunch: ' + (San $_.Exception.Message)); exit 2 }
Start-Sleep -Seconds 15
$alive = @(Get-Process -Name wpp -ErrorAction SilentlyContinue).Count
L ('   wpp.exe processes alive: ' + $alive)
if ($alive -eq 0) { L '   [FAIL] warm wpp did not stay alive'; exit 2 }

# ---------------- 2. attach probe (NO Quit - keep the instance) ----------------
$probe = @'
import win32com.client
app = win32com.client.Dispatch("KWPP.Application")
p = app.Presentations.Add()
n = p.Slides.Count
if n == 0:
    p.Slides.Add(1, 2)
    n = p.Slides.Count
v = str(app.Version)
p.Close()
print("ATTACH-OK version=%s slides=%d" % (v, n))
'@
[IO.File]::WriteAllText('F:\fig1_rebuild\harness_results\probe_warm.py', $probe.Replace("`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
$pv = Invoke-Expression ($pyexe + ' F:\fig1_rebuild\harness_results\probe_warm.py 2>&1')
foreach ($ln in @($pv | Select-Object -Last 3)) { L ('   probe: ' + (San ([string]$ln))) }
if ((@($pv) -join ' ') -notmatch 'ATTACH-OK') { L '   [FAIL] attach probe failed'; exit 2 }

# ---------------- 3. the 12-slide deck (attaches to warm wpp) ----------------
L '   building 12-slide deck (warm attach)...'
$deckOut = Invoke-Expression ($pyexe + ' F:\fig1_rebuild\harness_results\desk_harness_deck.py 2>&1')
foreach ($ln in @($deckOut)) { if ($ln) { L ('   deck| ' + (San ($ln.ToString().Substring(0, [Math]::Min(240, $ln.ToString().Length))))) } }
$deckOk = Test-Path -LiteralPath 'arena_report.pptx'
if ($deckOk) { L ('   DECK OK: arena_report.pptx ' + [math]::Round((Get-Item 'arena_report.pptx').Length/1KB) + 'KB') }
else { L '   DECK MISSING' }

# ---------------- 4. impress smoke (fresh warm instance if needed) ----------------
$alive2 = @(Get-Process -Name wpp -ErrorAction SilentlyContinue).Count
if ($alive2 -eq 0) {
    L '   wpp died after deck - relaunching warm instance...'
    try { Start-ScheduledTask -TaskName 'wpplaunch' } catch { }
    Start-Sleep -Seconds 12
    L ('   wpp.exe alive: ' + @(Get-Process -Name wpp -ErrorAction SilentlyContinue).Count)
}
$i = @()
$i += ('new: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps document new --type impress --name harnesspptx -o proj_impress.json 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
$i += ('slide: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps --project proj_impress.json impress add-slide -t HarnessPPTXTest -c EditableBodyViaWpsCom 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
$i += ('elem: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps --project proj_impress.json impress add-element 0 --type text_box --text HelloEditablePptx 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
$i += ('export: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps --project proj_impress.json export render test_impress.pptx -p pptx 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
foreach ($ln in $i) { if ($ln) { L ('   I ' + $ln.Substring(0, [Math]::Min(220, $ln.Length))) } }
if (Test-Path -LiteralPath 'test_impress.pptx') {
    L ('   impress OK: test_impress.pptx ' + [math]::Round((Get-Item 'test_impress.pptx').Length/1KB) + 'KB')
    $rv = Invoke-Expression ($pyexe + ' F:\fig1_rebuild\verify_pptx.py F:\fig1_rebuild\harness_results\test_impress.pptx 2>&1')
    foreach ($ln in @($rv | Select-Object -Last 2)) { L ('   verify: ' + (San ([string]$ln))) }
}
else { L '   [WARN] impress smoke pptx missing (deck is the deliverable)' }

# ---------------- 5. summary + cleanup ----------------
Kill-Wps
$imp = Test-Path -LiteralPath 'test_impress.pptx'
$wr = Test-Path -LiteralPath 'test_writer.docx'
if (-not $wr) {
    $wexp = Invoke-Expression ($pyexe + ' -m cli_anything.wps --project proj_writer.json export render test_writer.docx -p docx 2>&1')
    $wr = Test-Path -LiteralPath 'test_writer.docx'
    if ($wr) { L ('   writer OK (post): test_writer.docx ' + [math]::Round((Get-Item 'test_writer.docx').Length/1KB) + 'KB') }
}
L ('   FINAL: ' + $(if ($deckOk) { 'PASS - deck produced' + $(if ($imp) { ' + impress smoke' } else { '' }) } else { 'FAIL - no deck' }))
L '--- desktop WPP warm pipeline done ---'
