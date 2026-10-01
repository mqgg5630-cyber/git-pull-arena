# desk_cpe_test.ps1 - runs ON THE DESKTOP via ssh (elevated). Phase 1b+2
# for the cell_ppt_edited skill: bundled exe --self-test + --doctor +
# Install.ps1 -CheckOnly (root path now known: pkg\<topdir>), then the
# LIVE acceptance test - integration.py (28 PowerPoint COM checks) run in
# the INTERACTIVE session via a scheduled task, driving the PACKAGED exe
# as the MCP server. Logs to F:\fig1_rebuild\cpe\integration_log.txt.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop cell_ppt_edited phase 1b + 2 (engine checks + live acceptance) ---'

$cpe = 'F:\fig1_rebuild\cpe'
$pkg = Join-Path $cpe 'pkg'
$root = $null
foreach ($d in @(Get-ChildItem -LiteralPath $pkg -Directory -ErrorAction SilentlyContinue | Select-Object -First 1)) { $root = $d.FullName }
if (-not $root) { L '   [FAIL] release root not found'; exit 2 }
L ('   release root: ' + (San $root))
$exe = Join-Path $root 'plugins\cell-ppt-edited\bin\cell-ppt-edited.exe'

# ---------------- 1. engine checks ----------------
if (Test-Path -LiteralPath $exe) {
    $st = & $exe --self-test 2>&1
    $stTxt = (San ((($st | Out-String).Trim()) -replace "`r?`n", ' | '))
    if ($stTxt.Length -gt 220) { $stTxt = $stTxt.Substring(0, 220) }
    L ('   self-test rc=' + $LASTEXITCODE + ' :: ' + $stTxt)
    $dr = & $exe --doctor 2>&1
    $drTxt = (San ((($dr | Out-String).Trim()) -replace "`r?`n", ' | '))
    if ($drTxt.Length -gt 220) { $drTxt = $drTxt.Substring(0, 220) }
    L ('   doctor rc=' + $LASTEXITCODE + ' :: ' + $drTxt)
}
else { L '   [FAIL] packaged exe missing'; exit 2 }

# ---------------- 2. Install.ps1 -CheckOnly ----------------
$ips = Join-Path $root 'Install.ps1'
if (Test-Path -LiteralPath $ips) {
    $co = & powershell -NoProfile -ExecutionPolicy Bypass -File $ips -CheckOnly 2>&1
    L ('   CheckOnly rc=' + $LASTEXITCODE)
    foreach ($ln in @($co | Select-Object -Last 5)) { $t = (San ([string]$ln)); if ($t.Trim()) { L ('      ' + $t) } }
}

# ---------------- 3. live acceptance (interactive session) ----------------
$src = Join-Path $cpe 'src'
if (-not (Test-Path -LiteralPath (Join-Path $src 'integration.py'))) { L '   [FAIL] integration.py not staged'; exit 2 }
$pyexe = ''
try { $null = & py -3.12 --version 2>&1; if ($LASTEXITCODE -eq 0) { $pyexe = 'py -3.12' } } catch { }
if (-not $pyexe) { $pyexe = 'python' }
L ('   python: ' + $pyexe)

try { & taskkill /f /im POWERPNT.EXE 2>&1 | Out-Null } catch { }
Start-Sleep -Seconds 3
$outDir = Join-Path $cpe 'integration_out'
if (Test-Path -LiteralPath $outDir) { Remove-Item -Recurse -Force -LiteralPath $outDir }
$log = Join-Path $cpe 'integration_log.txt'
if (Test-Path -LiteralPath $log) { Remove-Item -Force -LiteralPath $log }

$cmd = Join-Path $cpe 'integrun.cmd'
$lines = @(
    '@echo off',
    ('cd /d ' + $src),
    ($pyexe + ' integration.py ' + $outDir + ' "' + $exe + '" > ' + $log + ' 2>&1'),
    ('echo INTEG-EXIT %ERRORLEVEL% >> ' + $log),
    ('echo INTEG-DONE >> ' + $log)
)
[IO.File]::WriteAllLines($cmd, $lines, (New-Object System.Text.ASCIIEncoding))

$null = & schtasks /delete /tn cpeinteg /f 2>$null
$null = & schtasks /create /tn cpeinteg /tr $cmd /sc once /st 23:59 /f 2>&1
$null = & schtasks /run /tn cpeinteg 2>&1
L '   cpeinteg interactive task started'

$deadline = (Get-Date).AddMinutes(11)
$done = $false
$lastLen = -1
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 30
    if (Test-Path -LiteralPath $log) {
        $txt = [IO.File]::ReadAllText($log)
        if ($txt.Length -ne $lastLen) { $lastLen = $txt.Length }
        if ($txt -match 'INTEG-DONE') { $done = $true; break }
    }
}
if ($done) { L '   integration finished' } else { L '   [WARN] integration did not signal done within 11 min' }
if (Test-Path -LiteralPath $log) {
    foreach ($ln in @(Get-Content -LiteralPath $log)) { $t = (San ([string]$ln)); if ($t.Trim()) { L ('   | ' + $t) } }
}
else { L '   [FAIL] no integration log produced'; exit 2 }

# ---------------- 4. results ----------------
$passCount = 0
if (Test-Path -LiteralPath $log) { $passCount = @((Get-Content -LiteralPath $log) | Where-Object { $_ -match '^PASS ' }).Count }
$acc = Join-Path $outDir 'acceptance.pptx'
if (Test-Path -LiteralPath $acc) { L ('   acceptance.pptx: ' + [math]::Round((Get-Item -LiteralPath $acc).Length/1KB) + 'KB') }
else { L '   [WARN] acceptance.pptx missing' }
if (Test-Path -LiteralPath $outDir) {
    foreach ($f in @(Get-ChildItem -LiteralPath $outDir -File | Select-Object -First 10)) { L ('   out: ' + (San $f.Name) + ' (' + [math]::Round($f.Length/1KB) + 'KB)') }
}
try { & taskkill /f /im POWERPNT.EXE 2>&1 | Out-Null } catch { }
L ('   FINAL: ' + $(if (($passCount -ge 20) -and (Test-Path -LiteralPath $acc)) { 'PASS - ' + $passCount + ' live checks passed' } elseif ($passCount -gt 0) { 'PARTIAL - ' + $passCount + ' checks passed' } else { 'FAIL' }))
L '--- cell_ppt_edited phase 2 done ---'
