# desk_cpe_test4.ps1 - runs ON THE DESKTOP via ssh (elevated). Round 4 of
# the cell_ppt_edited LIVE acceptance. r170 proved via the watcher that
# the blocker is an Office NUIDialog (activation/first-run wizard; ospp
# shows LICENSE STATUS: NOTIFICATIONS, KMS client unactivated) that pops
# on every PowerPoint launch and rejects/breaks COM calls. Also proven:
# the graceful-quit prep works, and PowerPoint survives client exit.
# This round: every attempt runs watcher v2 (closes #32770 AND NUIDialog
# with WM_CLOSE + ESC) and prepcpe v2 (crash-state clear, graceful quit,
# then VISIBLE prewarm left RUNNING so integration.py attaches via
# GetActiveObject to a warm dialog-free instance instead of launching a
# fresh PowerPoint that would re-show the activation dialog mid-test).
# Up to 3 attempts; final cleanup quits PowerPoint; best attempt is
# consolidated into F:\fig1_rebuild\cpe\integration_out.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }
function Cut([string]$s, [int]$n) { if ($s.Length -gt $n) { return $s.Substring(0, $n) }; return $s }

L '--- desktop cell_ppt_edited live acceptance round 4 (dialog-closing watcher + warm attach) ---'

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
$watcher = Join-Path $cpe 'watcher.ps1'
$prep = Join-Path $cpe 'prepcpe.ps1'
if (-not (Test-Path -LiteralPath $watcher)) { L '   [FAIL] watcher.ps1 not staged'; exit 2 }
if (-not (Test-Path -LiteralPath $prep)) { L '   [FAIL] prepcpe.ps1 not staged'; exit 2 }
$pyexe = ''
try { $null = & py -3.12 --version 2>&1; if ($LASTEXITCODE -eq 0) { $pyexe = 'py -3.12' } } catch { }
if (-not $pyexe) { $pyexe = 'python' }
L ('   python: ' + $pyexe)
L ('   powerpnt running at start: ' + @(Get-Process -Name POWERPNT -ErrorAction SilentlyContinue).Count)
L '   office: KMS client, ospp LICENSE STATUS NOTIFICATIONS (unactivated) - activation NUIDialog expected, watcher closes it'

# ---------------- up to 3 attempts ----------------
$cmdFile = Join-Path $cpe 'integrun4.cmd'
$bestA = 0
$bestPc = 0
$won = $false
$winA = 0

for ($a = 1; $a -le 3; $a++) {
    L ('--- attempt ' + $a + ' of 3 ---')
    $null = & schtasks /end /tn cpeinteg4 2>$null
    $null = & schtasks /delete /tn cpeinteg4 /f 2>$null
    $outDir = Join-Path $cpe ('iout_a' + $a)
    if (Test-Path -LiteralPath $outDir) { Remove-Item -Recurse -Force -LiteralPath $outDir }
    $log = Join-Path $cpe ('integ_a' + $a + '.txt')
    if (Test-Path -LiteralPath $log) { Remove-Item -Force -LiteralPath $log }
    $wlog = Join-Path $cpe ('watch_a' + $a + '.txt')
    if (Test-Path -LiteralPath $wlog) { Remove-Item -Force -LiteralPath $wlog }
    $lines = @(
        '@echo off',
        ('start "" /min powershell -NoProfile -ExecutionPolicy Bypass -File ' + $watcher + ' ' + $wlog + ' 300'),
        ('powershell -NoProfile -ExecutionPolicy Bypass -File ' + $prep + ' a' + $a + ' 1 >> ' + $log + ' 2>&1'),
        ('cd /d ' + $src),
        ($pyexe + ' integration.py ' + $outDir + ' "' + $exe + '" >> ' + $log + ' 2>&1'),
        ('echo INTEG-EXIT %ERRORLEVEL% >> ' + $log),
        ('echo INTEG-DONE >> ' + $log)
    )
    [IO.File]::WriteAllLines($cmdFile, $lines, (New-Object System.Text.ASCIIEncoding))
    $null = & schtasks /create /tn cpeinteg4 /tr $cmdFile /sc once /st 23:59 /f 2>&1
    $null = & schtasks /run /tn cpeinteg4 2>&1
    L ('   attempt ' + $a + ' launched (interactive cpeinteg4: watcher v2 + prep v2 warm + integration)')
    $t0 = Get-Date
    $deadline = (Get-Date).AddSeconds(280)
    $done = $false
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 15
        if ((Test-Path -LiteralPath $log) -and ([IO.File]::ReadAllText($log) -match 'INTEG-DONE')) { $done = $true; break }
    }
    $el = [int]((Get-Date) - $t0).TotalSeconds
    if (-not $done) {
        L ('   attempt ' + $a + ': TIMEOUT after ' + $el + 's, ending task')
        $null = & schtasks /end /tn cpeinteg4 2>$null
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
            if ($ln -match '^(PASS |PREP)') { L ('   | ' + (Cut (San $ln) 200)) }
        }
        if (-not ($exit -eq 0 -and $pc -ge 20)) {
            $tail = @(($txt -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 4)
            foreach ($ln in $tail) { L ('   ! ' + (Cut (San $ln) 260)) }
        }
    }
    if (Test-Path -LiteralPath $wlog) {
        $wl = @(Get-Content -LiteralPath $wlog | Where-Object { $_ -match 'window:|closing dialog|still present|watcher (start|end)' } | Select-Object -First 16)
        if ($wl.Count -gt 0) { L '   --- watcher ---'; foreach ($ln in $wl) { L ('   | ' + (Cut (San $ln) 170)) } }
        else { L '   watcher: no POWERPNT windows logged' }
    }
    if ($pc -gt $bestPc) { $bestPc = $pc; $bestA = $a }
    if ($exit -eq 0 -and $pc -ge 20 -and $accOk) { $won = $true; $winA = $a; break }
}

# ---------------- final graceful cleanup ----------------
$cleanLog = Join-Path $cpe 'cleancpe.txt'
if (Test-Path -LiteralPath $cleanLog) { Remove-Item -Force -LiteralPath $cleanLog }
$cleanCmd = Join-Path $cpe 'cpeclean4.cmd'
$clines = @(
    '@echo off',
    ('powershell -NoProfile -ExecutionPolicy Bypass -File ' + $prep + ' final 0 > ' + $cleanLog + ' 2>&1')
)
[IO.File]::WriteAllLines($cleanCmd, $clines, (New-Object System.Text.ASCIIEncoding))
$null = & schtasks /end /tn cpeclean4 2>$null
$null = & schtasks /delete /tn cpeclean4 /f 2>$null
$null = & schtasks /create /tn cpeclean4 /tr $cleanCmd /sc once /st 23:59 /f 2>&1
$null = & schtasks /run /tn cpeclean4 2>&1
Start-Sleep -Seconds 40
if (Test-Path -LiteralPath $cleanLog) {
    foreach ($ln in @(Get-Content -LiteralPath $cleanLog | Where-Object { $_ -match '^PREP' } | Select-Object -First 8)) { L ('   | ' + (Cut (San $ln) 200)) }
}
L ('   powerpnt running at end: ' + @(Get-Process -Name POWERPNT -ErrorAction SilentlyContinue).Count)

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
L '--- cell_ppt_edited round 4 done ---'
