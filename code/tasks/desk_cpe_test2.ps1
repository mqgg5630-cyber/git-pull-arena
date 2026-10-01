# desk_cpe_test2.ps1 - runs ON THE DESKTOP via ssh (elevated). Retry round
# for the cell_ppt_edited LIVE acceptance test. r168 proved self-test and
# doctor (both rc=0) and 7/27 checks, then died at step 8 ('ungroup') with
# COM RPC_E_CALL_REJECTED (-2147418111, busy callee) on the readback right
# after the ungroup completed. That is a transient cross-process COM race
# (no IMessageFilter in the packaged runtime), so this script retries the
# FULL integration.py run up to 3 times: POWERPNT killed and task ended
# before each attempt so the engine cannot attach to a stale busy
# instance, a FRESH out dir each attempt (integration.py requires a
# non-existing dir), 280s cap per attempt. The best attempt is
# consolidated into F:\fig1_rebuild\cpe\integration_out plus
# integration_log.txt for collection. 27 checks total; full success =
# py exit 0 (integration.py asserts every check).
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }
function Cut([string]$s, [int]$n) { if ($s.Length -gt $n) { return $s.Substring(0, $n) }; return $s }

L '--- desktop cell_ppt_edited live acceptance RETRY (r168 died at 8/27 with COM busy rejection) ---'

$cpe = 'F:\fig1_rebuild\cpe'
$pkg = Join-Path $cpe 'pkg'
$root = $null
foreach ($d in @(Get-ChildItem -LiteralPath $pkg -Directory -ErrorAction SilentlyContinue | Select-Object -First 1)) { $root = $d.FullName }
if (-not $root) { L '   [FAIL] release root not found'; exit 2 }
L ('   release root: ' + (San $root))
$exe = Join-Path $root 'plugins\cell-ppt-edited\bin\cell-ppt-edited.exe'
if (-not (Test-Path -LiteralPath $exe)) { L '   [FAIL] packaged exe missing'; exit 2 }
$src = Join-Path $cpe 'src'
if (-not (Test-Path -LiteralPath (Join-Path $src 'integration.py'))) { L '   [FAIL] integration.py not staged'; exit 2 }
$pyexe = ''
try { $null = & py -3.12 --version 2>&1; if ($LASTEXITCODE -eq 0) { $pyexe = 'py -3.12' } } catch { }
if (-not $pyexe) { $pyexe = 'python' }
L ('   python: ' + $pyexe)

$cmdFile = Join-Path $cpe 'integrun_retry.cmd'
$bestA = 0
$bestPc = 0
$won = $false
$winA = 0

for ($a = 1; $a -le 3; $a++) {
    L ('--- attempt ' + $a + ' of 3 ---')
    $null = & schtasks /end /tn cpeinteg 2>$null
    try { & taskkill /f /im POWERPNT.EXE 2>&1 | Out-Null } catch { }
    Start-Sleep -Seconds 4
    $outDir = Join-Path $cpe ('iout_a' + $a)
    if (Test-Path -LiteralPath $outDir) { Remove-Item -Recurse -Force -LiteralPath $outDir }
    $log = Join-Path $cpe ('integ_a' + $a + '.txt')
    if (Test-Path -LiteralPath $log) { Remove-Item -Force -LiteralPath $log }
    $lines = @(
        '@echo off',
        ('cd /d ' + $src),
        ($pyexe + ' integration.py ' + $outDir + ' "' + $exe + '" > ' + $log + ' 2>&1'),
        ('echo INTEG-EXIT %ERRORLEVEL% >> ' + $log),
        ('echo INTEG-DONE >> ' + $log)
    )
    [IO.File]::WriteAllLines($cmdFile, $lines, (New-Object System.Text.ASCIIEncoding))
    $null = & schtasks /delete /tn cpeinteg /f 2>$null
    $null = & schtasks /create /tn cpeinteg /tr $cmdFile /sc once /st 23:59 /f 2>&1
    $null = & schtasks /run /tn cpeinteg 2>&1
    L ('   attempt ' + $a + ' launched (interactive cpeinteg task)')
    $t0 = Get-Date
    $deadline = (Get-Date).AddSeconds(280)
    $done = $false
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 10
        if ((Test-Path -LiteralPath $log) -and ([IO.File]::ReadAllText($log) -match 'INTEG-DONE')) { $done = $true; break }
    }
    $el = [int]((Get-Date) - $t0).TotalSeconds
    if (-not $done) {
        L ('   attempt ' + $a + ': TIMEOUT after ' + $el + 's, ending task and killing POWERPNT')
        $null = & schtasks /end /tn cpeinteg 2>$null
        try { & taskkill /f /im POWERPNT.EXE 2>&1 | Out-Null } catch { }
        Start-Sleep -Seconds 3
    }
    $exit = -1
    $pc = 0
    $txt = ''
    if (Test-Path -LiteralPath $log) {
        $txt = [IO.File]::ReadAllText($log)
        if ($txt -match 'INTEG-EXIT (\d+)') { $exit = [int]$Matches[1] }
        $pc = @(($txt -split "`r?`n") | Where-Object { $_ -match '^PASS ' }).Count
    }
    $accPath = Join-Path $outDir 'acceptance.pptx'
    $accOk = Test-Path -LiteralPath $accPath
    L ('   attempt ' + $a + ': exit=' + $exit + ' PASS=' + $pc + '/27 acc=' + $(if ($accOk) { 'yes' } else { 'no' }) + ' elapsed=' + $el + 's')
    if ($txt) {
        foreach ($ln in ($txt -split "`r?`n")) {
            if ($ln -match '^PASS ') { L ('   | ' + (Cut (San $ln) 200)) }
        }
        if (-not ($exit -eq 0 -and $pc -ge 20)) {
            $tail = @(($txt -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 4)
            foreach ($ln in $tail) { L ('   ! ' + (Cut (San $ln) 260)) }
        }
    }
    if ($pc -gt $bestPc) { $bestPc = $pc; $bestA = $a }
    if ($exit -eq 0 -and $pc -ge 20 -and $accOk) { $won = $true; $winA = $a; break }
}

$null = & schtasks /end /tn cpeinteg 2>$null
try { & taskkill /f /im POWERPNT.EXE 2>&1 | Out-Null } catch { }

# ---------------- consolidate the best attempt ----------------
$finalOut = Join-Path $cpe 'integration_out'
if (Test-Path -LiteralPath $finalOut) { Remove-Item -Recurse -Force -LiteralPath $finalOut }
$srcDir = $null
if ($winA -ge 1) { $srcDir = Join-Path $cpe ('iout_a' + $winA) }
elseif ($bestA -ge 1) { $srcDir = Join-Path $cpe ('iout_a' + $bestA) }
if ($srcDir -and (Test-Path -LiteralPath $srcDir)) {
    New-Item -ItemType Directory -Path $finalOut | Out-Null
    foreach ($f in @(Get-ChildItem -LiteralPath $srcDir -File)) { Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $finalOut $f.Name) -Force }
    L ('   consolidated attempt ' + $(if ($winA -ge 1) { $winA } else { $bestA }) + ' into integration_out')
}
$useA = $winA
if ($useA -lt 1) { $useA = $bestA }
if ($useA -ge 1) {
    $bestLog = Join-Path $cpe ('integ_a' + $useA + '.txt')
    if (Test-Path -LiteralPath $bestLog) { Copy-Item -LiteralPath $bestLog -Destination (Join-Path $cpe 'integration_log.txt') -Force }
}
$acc = Join-Path $finalOut 'acceptance.pptx'
if (Test-Path -LiteralPath $acc) { L ('   acceptance.pptx: ' + [math]::Round((Get-Item -LiteralPath $acc).Length/1KB) + 'KB') }
else { L '   [WARN] acceptance.pptx missing' }
$ajs = Join-Path $finalOut 'acceptance.json'
if (Test-Path -LiteralPath $ajs) { L '   acceptance.json present (run reached full completion)' }
else { L '   [WARN] acceptance.json missing (run did not reach full completion)' }
if ($won) { L ('   FINAL: PASS - ' + $bestPc + '/27 live checks passed (attempt ' + $winA + ')') }
elseif ($bestPc -gt 0) { L ('   FINAL: PARTIAL - best ' + $bestPc + '/27 checks (attempt ' + $bestA + ')') }
else { L '   FINAL: FAIL' }
L '--- cell_ppt_edited retry done ---'
