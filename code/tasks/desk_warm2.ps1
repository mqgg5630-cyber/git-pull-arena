# desk_warm2.ps1 - runs ON THE DESKTOP via ssh (elevated). Two-shot closure:
#   Phase 1: warm wpp (interactive wpplaunch task) + deck_warm_build.py from
#            ssh as the FIRST AND ONLY COM client (single process does
#            author+render+save+verify)
#   Phase 2 (only if phase 1 fails): run deck_warm_build.py INSIDE the
#            interactive session via the wpstest2 task (cold Dispatch with
#            the new /Automation registration has never been tried there)
# Then writer smoke + FINAL verdict. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop WARM2 pipeline (single-process deck) ---'

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
$wppExe = Join-Path $office6 'wpp.exe'

# ---------------- 0. clean + reinstall ----------------
Kill-Wps
$o = Invoke-Expression ($pyexe + ' -m pip install --force-reinstall --no-deps --no-index --no-build-isolation --find-links ' + $vendor + ' ' + $haDir + ' 2>&1')
foreach ($ln in @($o | Select-Object -Last 1)) { L ('   ' + (San ([string]$ln))) }

# ---------------- Phase 1: warm wpp + single-process build ----------------
try {
    $la = New-ScheduledTaskAction -Execute $wppExe
    $pr = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
    $st = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
    Register-ScheduledTask -TaskName 'wpplaunch' -Action $la -Principal $pr -Settings $st -Force | Out-Null
    Start-ScheduledTask -TaskName 'wpplaunch'
    L '   wpplaunch started'
} catch { L ('   [FAIL] wpplaunch: ' + (San $_.Exception.Message)) }
Start-Sleep -Seconds 15
L ('   wpp.exe alive: ' + @(Get-Process -Name wpp -ErrorAction SilentlyContinue).Count)

L '   phase 1: single-process deck build (first client)...'
$deckOut = Invoke-Expression ($pyexe + ' F:\fig1_rebuild\harness_results\deck_warm_build.py 2>&1')
foreach ($ln in @($deckOut)) { if ($ln) { L ('   p1| ' + (San ($ln.ToString().Substring(0, [Math]::Min(240, $ln.ToString().Length))))) } }
$deckOk = Test-Path -LiteralPath 'arena_report.pptx'
if ($deckOk) { L ('   PHASE1 DECK OK: ' + [math]::Round((Get-Item 'arena_report.pptx').Length/1KB) + 'KB') }

# ---------------- Phase 2: interactive cold attempt ----------------
if (-not $deckOk) {
    L '   phase 2: interactive-session build via wpstest2...'
    Kill-Wps
    $wcmd = 'F:\fig1_rebuild\warm2run.cmd'
    $lines = @(
        '@echo off',
        ('cd /d ' + $results),
        ($pyexe + ' F:\fig1_rebuild\harness_results\deck_warm_build.py > F:\fig1_rebuild\harness_results\warm2_log.txt 2>&1')
    )
    [IO.File]::WriteAllLines($wcmd, $lines, (New-Object System.Text.ASCIIEncoding))
    try { Remove-Item -LiteralPath ($results + '\warm2_log.txt') -Force -ErrorAction Stop } catch { }
    $null = & schtasks /delete /tn wpstest2 /f 2>$null
    $null = & schtasks /create /tn wpstest2 /tr $wcmd /sc once /st 23:59 /f 2>&1
    $null = & schtasks /run /tn wpstest2 2>&1
    $deadline = (Get-Date).AddMinutes(8)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 30
        $log = @(Get-Content -LiteralPath ($results + '\warm2_log.txt') -ErrorAction SilentlyContinue)
        if (($log -join ' ') -match 'WARM2-DONE') { break }
    }
    foreach ($ln in @($log | Select-Object -Last 20)) { L ('   p2| ' + (San ([string]$ln))) }
    $deckOk = Test-Path -LiteralPath 'arena_report.pptx'
    if ($deckOk) { L ('   PHASE2 DECK OK: ' + [math]::Round((Get-Item 'arena_report.pptx').Length/1KB) + 'KB') }
}

# ---------------- writer smoke (harness CLI, proven path) ----------------
if (-not (Test-Path -LiteralPath 'test_writer.docx')) {
    Kill-Wps
    $w = @()
    $w += ('new: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps document new --type writer --name harnesssmoke -o proj_writer.json 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
    $w += ('head: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps --project proj_writer.json writer add-heading -t HarnessSmokeTest -l 1 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
    $w += ('para: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps --project proj_writer.json writer add-paragraph -t EditableParagraphViaWpsComOnDesktop. 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
    $w += ('export: ' + ((Invoke-Expression ($pyexe + ' -m cli_anything.wps --project proj_writer.json export render test_writer.docx -p docx 2>&1') | Out-String).Trim() -replace "`r?`n", ' | '))
    foreach ($ln in $w) { if ($ln) { L ('   W ' + $ln.Substring(0, [Math]::Min(200, $ln.Length))) } }
}

# ---------------- summary + cleanup ----------------
Kill-Wps
$imp = Test-Path -LiteralPath 'test_impress.pptx'
$wr = Test-Path -LiteralPath 'test_writer.docx'
L ('   FINAL: ' + $(if ($deckOk -and $imp -and $wr) { 'PASS - deck + impress smoke + writer smoke' } elseif ($deckOk) { 'PASS (deck' + $(if ($wr) { ' + writer' } else { '' }) + ')' } else { 'FAIL - no deck' }))
L '--- desktop WARM2 pipeline done ---'
