# desk_amp_deck.ps1 - runs ON THE DESKTOP via ssh (elevated). Build the
# "machine learning prediction of antimicrobial peptides" deck (14 slides)
# using the proven r160 pattern: kill all WPS, warm a wpp.exe via the
# interactive wpplaunch task, then run amp_deck_v2_build.py as the FIRST AND
# ONLY COM client (single process: harness authoring + render + SaveAs +
# verify). Interactive-session fallback if phase 1 fails. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop AMP deck v2 pipeline (single-process, warm wpp, designed edition) ---'

$results = 'F:\fig1_rebuild\harness_results'
Set-Location -LiteralPath $results

$pyexe = ''
try { $null = & py -3.12 --version 2>&1; if ($LASTEXITCODE -eq 0) { $pyexe = 'py -3.12' } } catch { }
if (-not $pyexe) { $pyexe = 'python' }

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

# ---------------- 0. clean slate ----------------
Kill-Wps

# ---------------- 1. warm wpp (interactive) ----------------
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

# ---------------- Phase 1: single-process build (first client) ----------------
L '   phase 1: AMP deck build (single process, first client)...'
$deckOut = Invoke-Expression ($pyexe + ' F:\fig1_rebuild\harness_results\amp_deck_v2_build.py 2>&1')
foreach ($ln in @($deckOut)) { if ($ln) { L ('   p1| ' + (San ($ln.ToString().Substring(0, [Math]::Min(240, $ln.ToString().Length))))) } }
$deckOk = Test-Path -LiteralPath 'amp_ml_prediction_v2.pptx'
if ($deckOk) { L ('   PHASE1 DECK OK: ' + [math]::Round((Get-Item 'amp_ml_prediction_v2.pptx').Length/1KB) + 'KB') }

# ---------------- Phase 2: interactive fallback ----------------
if (-not $deckOk) {
    L '   phase 2: interactive-session build via wpstest4...'
    Kill-Wps
    $wcmd = 'F:\fig1_rebuild\amprun2.cmd'
    $lines = @(
        '@echo off',
        ('cd /d ' + $results),
        ($pyexe + ' F:\fig1_rebuild\harness_results\amp_deck_v2_build.py > F:\fig1_rebuild\harness_results\amp_deck_v2_log.txt 2>&1')
    )
    [IO.File]::WriteAllLines($wcmd, $lines, (New-Object System.Text.ASCIIEncoding))
    try { Remove-Item -LiteralPath ($results + '\amp_deck_v2_log.txt') -Force -ErrorAction Stop } catch { }
    $null = & schtasks /delete /tn wpstest4 /f 2>$null
    $null = & schtasks /create /tn wpstest4 /tr $wcmd /sc once /st 23:59 /f 2>&1
    $null = & schtasks /run /tn wpstest4 2>&1
    $deadline = (Get-Date).AddMinutes(8)
    $log = @()
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 30
        $log = @(Get-Content -LiteralPath ($results + '\amp_deck_v2_log.txt') -ErrorAction SilentlyContinue)
        if (($log -join ' ') -match 'AMP-DECK-DONE') { break }
    }
    foreach ($ln in @($log | Select-Object -Last 20)) { L ('   p2| ' + (San ([string]$ln))) }
    $deckOk = Test-Path -LiteralPath 'amp_ml_prediction_v2.pptx'
    if ($deckOk) { L ('   PHASE2 DECK OK: ' + [math]::Round((Get-Item 'amp_ml_prediction_v2.pptx').Length/1KB) + 'KB') }
}

# ---------------- summary + cleanup ----------------
Kill-Wps
L ('   FINAL: ' + $(if ($deckOk) { 'PASS - amp_ml_prediction_v2.pptx produced' } else { 'FAIL - no deck' }))
L '--- desktop AMP deck v2 pipeline done ---'
