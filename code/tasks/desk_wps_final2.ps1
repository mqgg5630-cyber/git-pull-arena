# desk_wps_final2.ps1 - runs ON THE DESKTOP via ssh (elevated). r155/156
# proved: KWPP dies at Presentations.Add() (RPC unavailable) AFTER a KWPS
# lifecycle has run (ksolaunch broker goes stale), while a FRESH-state KWPP
# works (r153 deck reached SaveAs). New order: DECK FIRST on a fresh
# process state, then hard-kill all WPS processes + cooldown between each
# stage. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop WPS harness FINAL v2 (deck first, clean states) ---'

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
    Start-Sleep -Seconds 8
}

# ---------------- 0. clean slate + reinstall ----------------
Kill-Wps
$o = Invoke-Expression ($pyexe + ' -m pip install --force-reinstall --no-deps --no-index --no-build-isolation --find-links ' + $vendor + ' ' + $haDir + ' 2>&1')
foreach ($ln in @($o | Select-Object -Last 1)) { L ('   ' + (San ([string]$ln))) }

# ---------------- 1. THE 12-SLIDE DECK (fresh state, critical first) ----------------
L '   building 12-slide deck (fresh state)...'
$deckOut = Invoke-Expression ($pyexe + ' F:\fig1_rebuild\harness_results\desk_harness_deck.py 2>&1')
foreach ($ln in @($deckOut)) { if ($ln) { L ('   deck| ' + (San ($ln.ToString().Substring(0, [Math]::Min(240, $ln.ToString().Length))))) } }
$deckOk = Test-Path -LiteralPath 'arena_report.pptx'
if ($deckOk) { L ('   DECK OK: arena_report.pptx ' + [math]::Round((Get-Item 'arena_report.pptx').Length/1KB) + 'KB') }
else { L '   DECK MISSING' }

# ---------------- 2. impress smoke (clean state) ----------------
Kill-Wps
L '   impress smoke (clean state)...'
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
else { L '   [FAIL] impress pptx missing' }

# ---------------- 3. writer smoke (clean state) ----------------
Kill-Wps
L '   writer smoke (clean state)...'
$w = @()
$w += ('new: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps document new --type writer --name harnesssmoke -o proj_writer.json 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
$w += ('head: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps --project proj_writer.json writer add-heading -t HarnessSmokeTest -l 1 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
$w += ('para: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps --project proj_writer.json writer add-paragraph -t EditableParagraphViaWpsComOnDesktop. 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
$w += ('export: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps --project proj_writer.json export render test_writer.docx -p docx 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
foreach ($ln in $w) { if ($ln) { L ('   W ' + $ln.Substring(0, [Math]::Min(220, $ln.Length))) } }
if (Test-Path -LiteralPath 'test_writer.docx') { L ('   writer OK: test_writer.docx ' + [math]::Round((Get-Item 'test_writer.docx').Length/1KB) + 'KB') }
else { L '   [FAIL] writer docx missing' }

# ---------------- 4. summary + cleanup ----------------
Kill-Wps
$imp = Test-Path -LiteralPath 'test_impress.pptx'
$wr = Test-Path -LiteralPath 'test_writer.docx'
L ('   FINAL: ' + $(if ($deckOk -and $imp -and $wr) { 'PASS - all artifacts produced' } elseif ($deckOk) { 'PASS (deck) - partial smoke' } else { 'PARTIAL' }))
L '--- desktop WPS harness FINAL v2 done ---'
