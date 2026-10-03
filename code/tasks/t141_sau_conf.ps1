# t141_sau_conf.ps1 - round 183 task: runs ON THE LAPTOP. Last mile of the
# XHS stack. r182: sau installed (6 deps) + patchright chromium OK (via
# playwright CDN fallback), but 'sau --help' fails with
# 'ModuleNotFoundError: No module named conf' - the repo ships only
# conf.example.py, so pip never installed a 'conf' module. Fix:
# copy conf.example.py -> conf.py in the clone, force-reinstall sau
# (py-modules now picks up conf.py), verify sau --help.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }
function Cut([string]$s, [int]$n) { if ($s.Length -gt $n) { return $s.Substring(0, $n) }; return $s }

$base = 'E:\0github\git-sync\media-bridge'
$sau = Join-Path $base 'social-auto-upload'
$venvPip = Join-Path $base 'venv\Scripts\pip.exe'
$sauExe = Join-Path $base 'venv\Scripts\sau.exe'

L '--- task t141: sau conf module fix ---'

if (-not (Test-Path -LiteralPath (Join-Path $sau 'conf.example.py'))) { L '   [FAIL] conf.example.py missing'; exit 2 }

# ---------------- 1. conf.py from template ----------------
$confPy = Join-Path $sau 'conf.py'
if (-not (Test-Path -LiteralPath $confPy)) {
    Copy-Item -LiteralPath (Join-Path $sau 'conf.example.py') -Destination $confPy -Force
    L '   created conf.py from conf.example.py'
}
else { L '   conf.py already present' }

# ---------------- 2. force reinstall (picks up conf.py) ----------------
foreach ($k in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy')) {
    if ([Environment]::GetEnvironmentVariable($k)) { [Environment]::SetEnvironmentVariable($k, $null) }
}
L '   force-reinstalling sau (no deps) ...'
$pi = & $venvPip install --force-reinstall --no-deps -i https://mirrors.aliyun.com/pypi/simple/ $sau 2>&1
if ($LASTEXITCODE -ne 0) {
    L '   reinstall failed, raw tail:'
    foreach ($ln in @($pi | Select-Object -Last 8)) { $t = ((San ([string]$ln)).Trim()); if ($t) { L ('      ' + (Cut $t 170)) } }
    exit 2
}
L '   reinstalled'

# conf.py landed in site-packages?
$sp = & $venvPip show -f social-auto-upload 2>&1 | Out-String
if ($sp -match 'conf\.py') { L '   conf.py packaged into site-packages' }
else { L '   [WARN] conf.py not listed in package files' }

# ---------------- 3. verify sau CLI ----------------
$sauHelpOk = $false
$h = & $sauExe --help 2>&1
$hTxt = ($h | Out-String)
if ($LASTEXITCODE -eq 0 -and $hTxt.Trim()) {
    $sauHelpOk = $true
    foreach ($ln in @($h | Select-Object -First 10)) { $t = ((San ([string]$ln)).Trim()); if ($t) { L ('   sau| ' + (Cut $t 130)) } }
}
else {
    L '   sau --help still failing, raw tail:'
    foreach ($ln in @($h | Select-Object -Last 8)) { $t = ((San ([string]$ln)).Trim()); if ($t) { L ('      ' + (Cut $t 170)) } }
}

# ---------------- 4. chromium still there? ----------------
$msPw = Join-Path $env:LOCALAPPDATA 'ms-playwright'
$chrome = ''
foreach ($d in @(Get-ChildItem -LiteralPath $msPw -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^chromium' })) {
    foreach ($sub in @('chrome-win\chrome.exe', 'chrome-win64\chrome.exe', 'chrome-win64\chrome-win64\chrome.exe')) {
        $c = Join-Path $d.FullName $sub
        if (Test-Path -LiteralPath $c) { $chrome = $c; break }
    }
    if ($chrome) { break }
}
if ($chrome) { L ('   chromium: present (' + (San $chrome) + ')') }
else { L '   [WARN] chromium not found anymore' }

# ---------------- verdict ----------------
if ($sauHelpOk -and $chrome) {
    L '   FINAL: PASS - sau CLI answers and chromium is installed; XHS channel ready for cookie login'
    L '   next (user): E:\0github\git-sync\media-bridge\venv\Scripts\sau.exe xhs login --account <name>  (QR scan)'
}
elseif ($sauHelpOk) { L '   FINAL: PARTIAL - sau OK but chromium missing'; exit 2 }
else { L '   FINAL: FAIL - sau still broken'; exit 2 }
L '--- task t141 done ---'
exit 0
