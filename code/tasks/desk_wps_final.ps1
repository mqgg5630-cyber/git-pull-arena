# desk_wps_final.ps1 - runs ON THE DESKTOP via ssh (elevated). COM is now
# healthy (r153: ksolaunch /prometheus /X /Automation). The only remaining
# break was WPS 12 lacking SaveAs2 - patched with a SaveAs fallback in the
# staged harness tree. This script: force-reinstall the harness from the
# patched tree, run writer + impress smoke tests, build the 12-slide deck,
# verify everything, and report. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop WPS harness FINAL round ---'

$haDir = 'F:\fig1_rebuild\harness-anything'
$results = 'F:\fig1_rebuild\harness_results'
Set-Location -LiteralPath $results

$pyexe = ''
try { $null = & py -3.12 --version 2>&1; if ($LASTEXITCODE -eq 0) { $pyexe = 'py -3.12' } } catch { }
if (-not $pyexe) { $pyexe = 'python' }
$vendor = $haDir + '\vendor_wheels'

# ---------------- 1. force-reinstall patched harness ----------------
$o = Invoke-Expression ($pyexe + ' -m pip install --force-reinstall --no-deps --no-index --no-build-isolation --find-links ' + $vendor + ' ' + $haDir + ' 2>&1')
foreach ($ln in @($o | Select-Object -Last 2)) { L ('   ' + (San ([string]$ln))) }
$chk = Invoke-Expression ($pyexe + ' -c "import cli_anything.wps.utils.wps_backend as b; print(b.__file__)" 2>&1')
$bfile = ([string](@($chk) -join ' ')).Trim()
$patched = $false
if ($bfile -and (Test-Path -LiteralPath $bfile)) {
    $bsrc = [IO.File]::ReadAllText($bfile)
    if ($bsrc -match 'doc\.SaveAs\(abs_path') { $patched = $true }
}
L ('   installed save_as patch: ' + $(if ($patched) { 'PRESENT' } else { 'MISSING (' + $bfile + ')' }))

# ---------------- 2. writer smoke ----------------
$w = @()
$w += ('new: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps document new --type writer --name harnesssmoke -o proj_writer.json 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
$w += ('head: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps --project proj_writer.json writer add-heading -t HarnessSmokeTest -l 1 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
$w += ('para: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps --project proj_writer.json writer add-paragraph -t EditableParagraphViaWpsComOnDesktop. 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
$w += ('export: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps --project proj_writer.json export render test_writer.docx -p docx 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
foreach ($ln in $w) { if ($ln) { L ('   W ' + $ln.Substring(0, [Math]::Min(220, $ln.Length))) } }
if (Test-Path -LiteralPath 'test_writer.docx') { L ('   writer OK: test_writer.docx ' + [math]::Round((Get-Item 'test_writer.docx').Length/1KB) + 'KB') }
else { L '   [FAIL] writer docx missing' }

# ---------------- 3. impress smoke ----------------
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

# ---------------- 4. the 12-slide deck ----------------
L '   building 12-slide deck...'
$deckOut = Invoke-Expression ($pyexe + ' F:\fig1_rebuild\harness_results\desk_harness_deck.py 2>&1')
foreach ($ln in @($deckOut)) { if ($ln) { L ('   deck| ' + (San ($ln.ToString().Substring(0, [Math]::Min(240, $ln.ToString().Length))))) } }

# ---------------- 5. summary + cleanup ----------------
foreach ($n in @('wps', 'et', 'wpp', 'wpsoffice', 'wpscloudlaunch', 'ksolaunch')) {
    try { & taskkill /f /im ($n + '.exe') 2>&1 | Out-Null } catch { }
}
$deck = Test-Path -LiteralPath 'arena_report.pptx'
if ($deck) { L ('   DECK OK: arena_report.pptx ' + [math]::Round((Get-Item 'arena_report.pptx').Length/1KB) + 'KB') }
else { L '   DECK MISSING' }
L ('   FINAL: ' + $(if ($deck -and (Test-Path 'test_writer.docx') -and (Test-Path 'test_impress.pptx')) { 'PASS - all artifacts produced' } else { 'PARTIAL' }))
L '--- desktop WPS harness FINAL done ---'
