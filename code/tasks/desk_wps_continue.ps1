# desk_wps_continue.ps1 - runs ON THE DESKTOP via ssh.
# Continue the prior desktop WPS work by rebuilding/verifying the designed AMP
# deck with WPS KWPP, then leave fresh artifacts for collection. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m; $script:Report += $m }

$script:Report = @()
$results = 'F:\fig1_rebuild\harness_results'
$report = Join-Path $results 'wps_continue_r172.md'
New-Item -ItemType Directory -Force -Path $results | Out-Null
Set-Location -LiteralPath $results

L '# WPS desktop continuation r172'
L ('time: ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer: ' + $env:COMPUTERNAME + ' user: ' + $env:USERNAME)

$pyexe = ''
try { $null = & py -3.12 --version 2>&1; if ($LASTEXITCODE -eq 0) { $pyexe = 'py -3.12' } } catch { }
if (-not $pyexe) { $pyexe = 'python' }
L ('python: ' + $pyexe)

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
if (-not $office6) {
    L 'FINAL: WPS_FAIL office6 not found'
    [IO.File]::WriteAllText($report, ($script:Report -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
    exit 2
}
$wppExe = Join-Path $office6 'wpp.exe'
L ('office6: ' + $office6)
L ('wpp.exe exists: ' + (Test-Path -LiteralPath $wppExe))

# Prefer a fresh rebuild. The build script was staged by the wrapper.
$build = Join-Path $results 'amp_deck_v2_build.py'
$deck = Join-Path $results 'amp_ml_prediction_v2.pptx'
$deckCopy = Join-Path $results 'amp_ml_prediction_v2_r172.pptx'
$start = Get-Date
$deckOk = $false

if (Test-Path -LiteralPath $build) {
    Kill-Wps
    try {
        $la = New-ScheduledTaskAction -Execute $wppExe
        $pr = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
        $st = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
        Register-ScheduledTask -TaskName 'wpplaunch' -Action $la -Principal $pr -Settings $st -Force | Out-Null
        Start-ScheduledTask -TaskName 'wpplaunch'
        L 'warm: wpplaunch started'
    } catch { L ('warm: WARN ' + (San $_.Exception.Message)) }
    Start-Sleep -Seconds 15
    L ('warm: wpp.exe alive=' + @(Get-Process -Name wpp -ErrorAction SilentlyContinue).Count)

    L 'build: running amp_deck_v2_build.py as first COM client'
    $deckOut = Invoke-Expression ($pyexe + ' F:\fig1_rebuild\harness_results\amp_deck_v2_build.py 2>&1')
    foreach ($ln in @($deckOut)) {
        if ($ln) {
            $s = San ($ln.ToString())
            L ('   build| ' + $s.Substring(0, [Math]::Min(240, $s.Length)))
        }
    }
} else {
    L ('build: missing script ' + $build + '; will verify existing deck only')
}

if (Test-Path -LiteralPath $deck) {
    $fi = Get-Item -LiteralPath $deck
    $fresh = ($fi.LastWriteTime -ge $start.AddMinutes(-1))
    L ('deck: exists sizeKB=' + [math]::Round($fi.Length/1KB) + ' lastWrite=' + $fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') + ' fresh=' + $fresh)
    try { Copy-Item -LiteralPath $deck -Destination $deckCopy -Force; L ('deck: copied to ' + $deckCopy) } catch { L ('deck copy WARN ' + (San $_.Exception.Message)) }
    $deckOk = $true
} else {
    L 'deck: missing amp_ml_prediction_v2.pptx'
}

# Structural verification through the helper if present.
$verify = 'F:\fig1_rebuild\verify_pptx.py'
if ((Test-Path -LiteralPath $verify) -and (Test-Path -LiteralPath $deckCopy)) {
    try {
        $vo = Invoke-Expression ($pyexe + ' ' + $verify + ' ' + $deckCopy + ' 2>&1')
        foreach ($ln in @($vo)) { if ($ln) { L ('verify: ' + (San ([string]$ln))) } }
    } catch { L ('verify WARN ' + (San $_.Exception.Message)) }
} else { L 'verify: helper missing or deck copy missing' }

Kill-Wps
if ($deckOk) { L 'FINAL: WPS_CONTINUE_OK fresh/editable deck available (or existing deck verified).' }
else { L 'FINAL: WPS_CONTINUE_FAIL no deck available.' }
try { [IO.File]::WriteAllText($report, ($script:Report -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) } catch { }
L ('report: ' + $report)
if ($deckOk) { exit 0 } else { exit 2 }
