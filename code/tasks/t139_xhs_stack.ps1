# t139_xhs_stack.ps1 - round 181 task: runs ON THE LAPTOP. Heavy half of
# the XHS channel: install social-auto-upload's Python stack into the
# media-bridge venv and the Playwright Chromium browser (via the npmmirror
# CDN mirror), then verify the `sau` CLI answers.
#   - full requirements.txt first (aliyun mirror); if pinned builds fail
#     on this Python, fall back to a core subset,
#   - PLAYWRIGHT_DOWNLOAD_HOST=https://cdn.npmmirror.com/binaries/playwright
#     for the Chromium download (domestic, no proxy),
#   - verify: venv\Scripts\sau.exe --help + chromium exe present.
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

L '--- task t139: xhs stack (sau requirements + playwright chromium) ---'

if (-not (Test-Path -LiteralPath (Join-Path $sau 'requirements.txt'))) { L '   [FAIL] social-auto-upload/requirements.txt missing'; exit 2 }
if (-not (Test-Path -LiteralPath $venvPy)) { L '   [FAIL] media-bridge venv missing'; exit 2 }

# ---------------- 1. scrub proxy env ----------------
$scrubbed = @()
foreach ($k in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy')) {
    if ([Environment]::GetEnvironmentVariable($k)) { $scrubbed += $k; [Environment]::SetEnvironmentVariable($k, $null) }
}
if ($scrubbed.Count -gt 0) { L ('   scrubbed proxy env: ' + ($scrubbed -join ', ')) }
else { L '   no proxy env vars set' }
L ('   python: ' + (San ((& $venvPy --version 2>&1 | Out-String).Trim())))

# ---------------- 2. sau stack ----------------
if (Test-Path -LiteralPath $sauExe) {
    L '   sau CLI already installed'
}
else {
    L '   installing full requirements.txt (aliyun mirror) ...'
    $t0 = Get-Date
    $pi = & $venvPip install --timeout 60 -i https://mirrors.aliyun.com/pypi/simple/ -r (Join-Path $sau 'requirements.txt') 2>&1
    $el1 = [int]((Get-Date) - $t0).TotalSeconds
    if (Test-Path -LiteralPath $sauExe) {
        L ('   full requirements installed in ' + $el1 + 's; sau CLI present')
    }
    else {
        L ('   full requirements incomplete after ' + $el1 + 's, errors:')
        foreach ($ln in @($pi | Where-Object { $_ -match 'ERROR|error:' } | Select-Object -Last 4)) { L ('      ' + (Cut (San ([string]$ln)) 170)) }
        L '   falling back to core subset ...'
        $core = 'playwright==1.52.0 aiohttp requests pillow PyYAML loguru click qrcode pycryptodome Flask flask-cors SQLAlchemy jinja2 schedule tqdm'
        $pi2 = & $venvPip install --timeout 60 -i https://mirrors.aliyun.com/pypi/simple/ $core.Split(' ') 2>&1
        if (-not (Test-Path -LiteralPath $sauExe)) {
            L '   sau entry point still missing - installing the package itself'
            $pi3 = & $venvPip install --timeout 60 -i https://mirrors.aliyun.com/pypi/simple/ --no-deps (Join-Path $sau) 2>&1
            foreach ($ln in @($pi3 | Select-Object -Last 3)) { L ('      ' + (Cut (San ([string]$ln)) 170)) }
        }
    }
}

# ---------------- 3. playwright chromium ----------------
$chrome = ''
$msPw = Join-Path $env:LOCALAPPDATA 'ms-playwright'
if (Test-Path -LiteralPath $msPw) {
    foreach ($d in @(Get-ChildItem -LiteralPath $msPw -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^chromium' })) {
        $c = Join-Path $d.FullName 'chrome-win\chrome.exe'
        if (-not (Test-Path -LiteralPath $c)) { $c = Join-Path $d.FullName 'chrome-win64\chrome.exe' }
        if (Test-Path -LiteralPath $c) { $chrome = $c; break }
    }
}
if ($chrome) {
    L '   chromium already present: ' + (San $chrome)
}
else {
    L '   downloading playwright chromium via npmmirror ...'
    [Environment]::SetEnvironmentVariable('PLAYWRIGHT_DOWNLOAD_HOST', 'https://cdn.npmmirror.com/binaries/playwright')
    $t1 = Get-Date
    $pw = & $venvPy -m playwright install chromium 2>&1
    $el2 = [int]((Get-Date) - $t1).TotalSeconds
    foreach ($d in @(Get-ChildItem -LiteralPath $msPw -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^chromium' })) {
        $c = Join-Path $d.FullName 'chrome-win\chrome.exe'
        if (-not (Test-Path -LiteralPath $c)) { $c = Join-Path $d.FullName 'chrome-win64\chrome.exe' }
        if (Test-Path -LiteralPath $c) { $chrome = $c; break }
    }
    if ($chrome) { L ('   chromium installed in ' + $el2 + 's') }
    else {
        L ('   chromium download did not land after ' + $el2 + 's:')
        foreach ($ln in @($pw | Select-Object -Last 5)) { L ('      ' + (Cut (San ([string]$ln)) 170)) }
    }
}

# ---------------- 4. verify sau CLI ----------------
$sauHelpOk = $false
if (Test-Path -LiteralPath $sauExe) {
    $h = & $sauExe --help 2>&1
    $hTxt = ($h | Out-String)
    if ($LASTEXITCODE -eq 0 -and $hTxt.Trim()) {
        $sauHelpOk = $true
        foreach ($ln in @($h | Select-Object -First 6)) { $t = ((San ([string]$ln)).Trim()); if ($t) { L ('   sau| ' + (Cut $t 130)) } }
    }
    else {
        L '   sau --help failed:'
        foreach ($ln in @($h | Select-Object -Last 6)) { L ('      ' + (Cut (San ([string]$ln)) 170)) }
    }
}
else { L '   [WARN] sau.exe not present' }

# ---------------- 5. xhs status ----------------
$xh = & $venvPy -X utf8 (Join-Path $base 'xhs_publish.py') 2>&1
foreach ($ln in @($xh | Select-Object -First 8)) { $t = ((San ([string]$ln)).Trim()); if ($t) { L ('   xh| ' + (Cut $t 160)) } }

# ---------------- verdict ----------------
if ($sauHelpOk -and $chrome) {
    L '   FINAL: PASS - sau CLI answers and chromium is installed; XHS channel ready for cookie login'
    L '   next (user): venv\Scripts\sau.exe xhs login --account <name>  (scan QR with the XHS app)'
}
elseif ($chrome -or $sauHelpOk) { L '   FINAL: PARTIAL - see lines above (one component missing)'; exit 2 }
else { L '   FINAL: FAIL - both sau CLI and chromium missing'; exit 2 }
L '--- task t139 done ---'
exit 0
