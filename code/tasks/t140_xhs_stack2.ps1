# t140_xhs_stack2.ps1 - round 182 task: runs ON THE LAPTOP. Correct XHS
# stack install. r181 failed because requirements.txt is a bloated legacy
# list (biliup, yt-dlp, ... no py3.12 wheels for some pins) - but the
# project's pyproject.toml declares the REAL runtime deps: loguru,
# opencv-python, patchright (the anti-detect playwright fork, NOT
# playwright), qrcode, requests, segno. So:
#   1. pip install <social-auto-upload dir>  (installs exactly the 6 deps
#      and creates venv\Scripts\sau.exe from the sau = sau_cli:main entry)
#   2. python -m patchright install chromium  (PLAYWRIGHT_DOWNLOAD_HOST
#      pointed at npmmirror)
#   3. verify sau --help + chromium exe + xhs status
# Raw error tails are printed (no filtering - r181 swallowed the reason).
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }
function Cut([string]$s, [int]$n) { if ($s.Length -gt $n) { return $s.Substring(0, $n) }; return $s }

$base = 'E:\0github\git-sync\media-bridge'
$sau = Join-Path $base 'social-auto-upload'
$venvPy = Join-Path $base 'venv\Scripts\python.exe'
$venvPip = Join-Path $base 'venv\Scripts\pip.exe'
$sauExe = Join-Path $base 'venv\Scripts\sau.exe'

L '--- task t140: xhs stack v2 (pyproject deps + patchright chromium) ---'

if (-not (Test-Path -LiteralPath (Join-Path $sau 'pyproject.toml'))) { L '   [FAIL] social-auto-upload/pyproject.toml missing'; exit 2 }
if (-not (Test-Path -LiteralPath $venvPy)) { L '   [FAIL] media-bridge venv missing'; exit 2 }

foreach ($k in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy')) {
    if ([Environment]::GetEnvironmentVariable($k)) { [Environment]::SetEnvironmentVariable($k, $null) }
}
L ('   python: ' + (San ((& $venvPy --version 2>&1 | Out-String).Trim())))

# ---------------- 1. install sau per pyproject ----------------
if (Test-Path -LiteralPath $sauExe) {
    L '   sau CLI already present'
}
else {
    L '   pip install social-auto-upload (aliyun mirror, 6 real deps) ...'
    $t0 = Get-Date
    $pi = & $venvPip install --timeout 90 -i https://mirrors.aliyun.com/pypi/simple/ $sau 2>&1
    $el1 = [int]((Get-Date) - $t0).TotalSeconds
    if (Test-Path -LiteralPath $sauExe) {
        L ('   sau installed in ' + $el1 + 's')
    }
    else {
        L ('   sau install FAILED after ' + $el1 + 's, raw tail:')
        foreach ($ln in @($pi | Select-Object -Last 10)) { $t = ((San ([string]$ln)).Trim()); if ($t) { L ('      ' + (Cut $t 170)) } }
        exit 2
    }
}

# ---------------- 2. patchright chromium ----------------
$msPw = Join-Path $env:LOCALAPPDATA 'ms-playwright'
$chrome = ''
foreach ($d in @(Get-ChildItem -LiteralPath $msPw -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^chromium' })) {
    foreach ($sub in @('chrome-win\chrome.exe', 'chrome-win64\chrome.exe', 'chrome-win64\chrome-win64\chrome.exe')) {
        $c = Join-Path $d.FullName $sub
        if (Test-Path -LiteralPath $c) { $chrome = $c; break }
    }
    if ($chrome) { break }
}
if ($chrome) { L ('   chromium already present: ' + (San $chrome)) }
else {
    [Environment]::SetEnvironmentVariable('PLAYWRIGHT_DOWNLOAD_HOST', 'https://cdn.npmmirror.com/binaries/playwright')
    L '   patchright install chromium (npmmirror) ...'
    $t1 = Get-Date
    $pw = & $venvPy -m patchright install chromium 2>&1
    $el2 = [int]((Get-Date) - $t1).TotalSeconds
    foreach ($d in @(Get-ChildItem -LiteralPath $msPw -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^chromium' })) {
        foreach ($sub in @('chrome-win\chrome.exe', 'chrome-win64\chrome.exe', 'chrome-win64\chrome-win64\chrome.exe')) {
            $c = Join-Path $d.FullName $sub
            if (Test-Path -LiteralPath $c) { $chrome = $c; break }
        }
        if ($chrome) { break }
    }
    if ($chrome) { L ('   chromium installed in ' + $el2 + 's') }
    else {
        L ('   chromium did not land after ' + $el2 + 's, raw tail:')
        foreach ($ln in @($pw | Select-Object -Last 10)) { $t = ((San ([string]$ln)).Trim()); if ($t) { L ('      ' + (Cut $t 170)) } }
        L '   retry via playwright CDN without mirror ...'
        [Environment]::SetEnvironmentVariable('PLAYWRIGHT_DOWNLOAD_HOST', $null)
        $pw2 = & $venvPy -m patchright install chromium 2>&1
        foreach ($d in @(Get-ChildItem -LiteralPath $msPw -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^chromium' })) {
            foreach ($sub in @('chrome-win\chrome.exe', 'chrome-win64\chrome.exe', 'chrome-win64\chrome-win64\chrome.exe')) {
                $c = Join-Path $d.FullName $sub
                if (Test-Path -LiteralPath $c) { $chrome = $c; break }
            }
            if ($chrome) { break }
        }
        if ($chrome) { L '   chromium installed (playwright CDN)' }
        else {
            foreach ($ln in @($pw2 | Select-Object -Last 8)) { $t = ((San ([string]$ln)).Trim()); if ($t) { L ('      ' + (Cut $t 170)) } }
        }
    }
}

# ---------------- 3. verify sau CLI ----------------
$sauHelpOk = $false
if (Test-Path -LiteralPath $sauExe) {
    $h = & $sauExe --help 2>&1
    $hTxt = ($h | Out-String)
    if ($LASTEXITCODE -eq 0 -and $hTxt.Trim()) {
        $sauHelpOk = $true
        foreach ($ln in @($h | Select-Object -First 8)) { $t = ((San ([string]$ln)).Trim()); if ($t) { L ('   sau| ' + (Cut $t 130)) } }
    }
    else {
        L '   sau --help failed, raw tail:'
        foreach ($ln in @($h | Select-Object -Last 8)) { $t = ((San ([string]$ln)).Trim()); if ($t) { L ('      ' + (Cut $t 170)) } }
    }
}
else { L '   [WARN] sau.exe not present' }

# ---------------- 4. xhs status ----------------
$xh = & $venvPy -X utf8 (Join-Path $base 'xhs_publish.py') 2>&1
foreach ($ln in @($xh | Select-Object -First 8)) { $t = ((San ([string]$ln)).Trim()); if ($t) { L ('   xh| ' + (Cut $t 160)) } }

# ---------------- verdict ----------------
if ($sauHelpOk -and $chrome) {
    L '   FINAL: PASS - sau CLI answers and patchright chromium is installed; XHS channel ready for cookie login'
    L '   next (user): E:\0github\git-sync\media-bridge\venv\Scripts\sau.exe xhs login --account <name>'
}
elseif ($chrome -or $sauHelpOk) { L '   FINAL: PARTIAL - one component missing, see above'; exit 2 }
else { L '   FINAL: FAIL - both components missing'; exit 2 }
L '--- task t140 done ---'
exit 0
