# desk_cpe_setup.ps1 - runs ON THE DESKTOP via ssh. Task: install+test the
# cell_ppt_edited skill (yrui-cmd/cell_ppt_edited v1.1.0) - PHASE 1:
# environment check (desktop MS PowerPoint? Codex CLI?), release download
# through the local proxy, SHA256 verify, extract, bundled-runtime
# self-test + PowerPoint doctor, Install.ps1 -CheckOnly. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop cell_ppt_edited phase 1 (env + download + engine checks) ---'

# ---------------- 1. PowerPoint detection ----------------
$ppReg = (Test-Path 'HKLM:\SOFTWARE\Classes\PowerPoint.Application') -or (Test-Path 'HKCU:\SOFTWARE\Classes\PowerPoint.Application')
L ('   PowerPoint ProgID registered: ' + $ppReg)
foreach ($root in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths')) {
    $ap = Join-Path $root 'POWERPNT.EXE'
    if (Test-Path -LiteralPath $ap) {
        $p = (Get-ItemProperty -LiteralPath $ap -ErrorAction SilentlyContinue).'(default)'
        L ('   App Paths POWERPNT.EXE: ' + (San ([string]$p)))
    }
}
$keys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
          'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
          'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')
$apps = @(Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Microsoft Office|PowerPoint|Microsoft 365' })
L ('   Office-family uninstall entries: ' + $apps.Count)
foreach ($a in ($apps | Select-Object -First 6)) { L ('      ' + (San ([string]$a.DisplayName)) + ' v' + (San ([string]$a.DisplayVersion))) }
foreach ($p in @((Join-Path $env:ProgramFiles 'Microsoft Office\root\Office16\POWERPNT.EXE'),
                 (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Office\root\Office16\POWERPNT.EXE'),
                 (Join-Path $env:ProgramFiles 'Microsoft Office\Office16\POWERPNT.EXE'))) {
    if (Test-Path -LiteralPath $p) { L ('   POWERPNT.EXE: ' + $p + ' v' + (San ([string](Get-Item -LiteralPath $p).VersionInfo.ProductVersion))) }
}

# ---------------- 2. Codex detection ----------------
$codex = Get-Command codex -ErrorAction SilentlyContinue
$cbin = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin'
L ('   codex CLI: ' + $(if ($codex) { (San $codex.Source) } else { 'not on PATH' }) + ' | Codex bin dir: ' + (Test-Path -LiteralPath $cbin))

# ---------------- 3. release download via proxy ----------------
$dir = 'F:\fig1_rebuild\cpe'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$zip = Join-Path $dir 'cell_ppt_edited-1.1.0-windows-x64.zip'
if (-not (Test-Path -LiteralPath $zip) -or ((Get-Item -LiteralPath $zip -ErrorAction SilentlyContinue).Length -lt 1MB)) {
    $u = 'https://github.com/yrui-cmd/cell_ppt_edited/releases/download/v1.1.0/cell_ppt_edited-1.1.0-windows-x64.zip'
    & curl.exe -x http://127.0.0.1:10808 --ssl-no-revoke -L -sS -o $zip --max-time 300 --connect-timeout 20 $u 2>&1 | ForEach-Object { L ('   curl: ' + (San ([string]$_))) }
}
if (-not (Test-Path -LiteralPath $zip)) { L '   [FAIL] download produced nothing'; exit 2 }
L ('   zip: ' + [math]::Round((Get-Item -LiteralPath $zip).Length/1MB) + 'MB')
if ((Get-Item -LiteralPath $zip).Length -lt 10MB) { L '   [FAIL] zip too small'; exit 2 }

$sums = Join-Path $dir 'SHA256SUMS.txt'
if (-not (Test-Path -LiteralPath $sums)) {
    & curl.exe -x http://127.0.0.1:10808 --ssl-no-revoke -L -sS -o $sums --max-time 60 'https://github.com/yrui-cmd/cell_ppt_edited/releases/download/v1.1.0/SHA256SUMS.txt' 2>&1 | Out-Null
}
$expected = ''
if (Test-Path -LiteralPath $sums) {
    foreach ($ln in @(Get-Content -LiteralPath $sums)) {
        if ($ln -match '^([0-9A-Fa-f]{64})\s.*windows-x64\.zip') { $expected = $Matches[1] }
    }
}
$actual = ''
try { $actual = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash } catch { }
L ('   sha256 expected: ' + $expected)
L ('   sha256 actual:   ' + $actual)
if ($expected -and $actual -and $expected.ToUpper() -eq $actual.ToUpper()) { L '   sha256 MATCH' }
else { L '   [FAIL] sha256 mismatch (or sums file missing)'; exit 2 }

# ---------------- 4. extract ----------------
$pkg = Join-Path $dir 'pkg'
if (Test-Path -LiteralPath $pkg) { Remove-Item -Recurse -Force -LiteralPath $pkg }
try { Expand-Archive -LiteralPath $zip -DestinationPath $pkg -Force } catch { L ('   [FAIL] extract: ' + (San $_.Exception.Message)); exit 2 }
L ('   extracted top entries: ' + @(Get-ChildItem -LiteralPath $pkg).Count)
foreach ($e in @(Get-ChildItem -LiteralPath $pkg | Select-Object -First 12)) { L ('      ' + (San $e.Name)) }

# ---------------- 5. bundled engine checks ----------------
$exe = Join-Path $pkg 'plugins\cell-ppt-edited\bin\cell-ppt-edited.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    L '   [WARN] exe not at expected path - searching:'
    foreach ($f in @(Get-ChildItem -LiteralPath $pkg -Recurse -Filter '*.exe' -ErrorAction SilentlyContinue | Select-Object -First 5)) { L ('      ' + (San $f.FullName)) }
}
else {
    $st = & $exe --self-test 2>&1
    $stTxt = (San ((($st | Out-String).Trim()) -replace "`r?`n", ' | '))
    if ($stTxt.Length -gt 200) { $stTxt = $stTxt.Substring(0, 200) }
    L ('   self-test rc=' + $LASTEXITCODE + ' :: ' + $stTxt)
    $dr = & $exe --doctor 2>&1
    $drTxt = (San ((($dr | Out-String).Trim()) -replace "`r?`n", ' | '))
    if ($drTxt.Length -gt 200) { $drTxt = $drTxt.Substring(0, 200) }
    L ('   doctor rc=' + $LASTEXITCODE + ' :: ' + $drTxt)
}

# ---------------- 6. Install.ps1 -CheckOnly ----------------
$ips = Join-Path $pkg 'Install.ps1'
if (Test-Path -LiteralPath $ips) {
    $co = & powershell -NoProfile -ExecutionPolicy Bypass -File $ips -CheckOnly 2>&1
    L ('   CheckOnly rc=' + $LASTEXITCODE)
    foreach ($ln in @($co | Select-Object -Last 6)) { $t = (San ([string]$ln)); if ($t.Trim()) { L ('      ' + $t) } }
}
else { L '   [WARN] Install.ps1 not found in package' }

L '--- cell_ppt_edited phase 1 done ---'
