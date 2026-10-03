# t136_media_bridge3.ps1 - round 178 task: runs ON THE LAPTOP. Final fix of
# the media-bridge base. Root cause chain found in r176/r177 + sandbox
# reproduction:
#   - wechatpy's wheel needs an OPTIONAL crypto backend at import time
#     (pycryptodome/cryptography) -> 'import wechatpy' failed although pip
#     succeeded,
#   - and the published wheel (1.8.18) does not even register the
#     draft/freepublish components we need.
# So wxmp_cli.py v2 now talks to the MP REST API directly with requests
# (no wechatpy at all). This task: pip install requests (single pure
# wheel), social-auto-upload clone, media-bridge-tg task, self-checks.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }
function Cut([string]$s, [int]$n) { if ($s.Length -gt $n) { return $s.Substring(0, $n) }; return $s }

$base = 'E:\0github\git-sync\media-bridge'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

L '--- task t136: media-bridge green base v3 (requests-only wxmp cli) ---'

# ---------------- 1. stage scripts (idempotent) ----------------
$src = Join-Path $repoRoot 'code\media-bridge'
foreach ($f in @('tg_bridge.py', 'wxmp_cli.py', 'xhs_publish.py', 'run_tg_bridge.ps1')) {
    if (-not (Test-Path -LiteralPath (Join-Path $src $f))) { L ('   [FAIL] missing repo file: ' + $f); exit 2 }
}
New-Item -ItemType Directory -Force -Path $base | Out-Null
foreach ($d in @('conf', 'logs', 'cookies', 'content')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $base $d) | Out-Null
}
foreach ($f in @('tg_bridge.py', 'wxmp_cli.py', 'xhs_publish.py', 'run_tg_bridge.ps1')) {
    Copy-Item -LiteralPath (Join-Path $src $f) -Destination (Join-Path $base $f) -Force
}
L '   staged: 4 scripts (wxmp_cli.py v2 = pure requests) + dirs'

# ---------------- 2. venv + requests ----------------
$pyExe = ''
foreach ($cand in @('py -3', 'python')) {
    try {
        $v = & cmd /c ($cand + ' --version') 2>&1
        if ($LASTEXITCODE -eq 0 -and ($v -match 'Python')) { $pyExe = $cand; L ('   python: ' + (San (($v | Out-String).Trim()))); break }
    } catch { }
}
if (-not $pyExe) { L '   [FAIL] no python on PATH'; exit 2 }
$venvPy = Join-Path $base 'venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $venvPy)) {
    $null = & cmd /c ($pyExe + ' -m venv "' + (Join-Path $base 'venv') + '"') 2>&1
    if (-not (Test-Path -LiteralPath $venvPy)) { L '   [FAIL] venv creation failed'; exit 2 }
    L '   venv created'
}
else { L '   venv already present' }

$scrubbed = @()
foreach ($k in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy')) {
    if ([Environment]::GetEnvironmentVariable($k)) { $scrubbed += $k; [Environment]::SetEnvironmentVariable($k, $null) }
}
if ($scrubbed.Count -gt 0) { L ('   scrubbed proxy env for pip: ' + ($scrubbed -join ', ')) }

$imp = & $venvPy -c "import requests; print(requests.__version__)" 2>&1
if ($LASTEXITCODE -eq 0) { L ('   requests already installed: ' + (San (($imp | Out-String).Trim()))) }
else {
    $installed = $false
    foreach ($mi in @('https://mirrors.aliyun.com/pypi/simple/', 'https://pypi.tuna.tsinghua.edu.cn/simple', 'https://pypi.org/simple')) {
        L ('   pip attempt: ' + $mi)
        $pi = & $venvPy -m pip install --timeout 40 -i $mi requests 2>&1
        $imp = & $venvPy -c "import requests; print(requests.__version__)" 2>&1
        if ($LASTEXITCODE -eq 0) {
            L ('   requests installed from ' + $mi + ' -> ' + (San (($imp | Out-String).Trim())))
            $installed = $true
            break
        }
        foreach ($ln in @($pi | Select-Object -Last 3)) { L ('      ' + (Cut (San ([string]$ln)) 170)) }
    }
    if (-not $installed) {
        L '   pip attempt: pypi.org via local proxy'
        $pi = & $venvPy -m pip install --timeout 40 --proxy http://127.0.0.1:10808 -i https://pypi.org/simple requests 2>&1
        $imp = & $venvPy -c "import requests; print(requests.__version__)" 2>&1
        if ($LASTEXITCODE -ne 0) {
            L '   [FAIL] requests install failed on all routes:'
            foreach ($ln in @($pi | Select-Object -Last 5)) { L ('      ' + (Cut (San ([string]$ln)) 170)) }
            exit 2
        }
        L ('   requests installed via proxy -> ' + (San (($imp | Out-String).Trim())))
    }
}

# ---------------- 3. clone social-auto-upload ----------------
$sau = Join-Path $base 'social-auto-upload'
if (Test-Path -LiteralPath (Join-Path $sau '.git')) {
    L '   social-auto-upload already cloned'
}
else {
    $co = & git clone -q --depth 1 https://github.com/dreammis/social-auto-upload.git $sau 2>&1
    if ($LASTEXITCODE -ne 0) {
        L ('   [FAIL] social-auto-upload clone failed rc=' + $LASTEXITCODE)
        foreach ($ln in @($co | Select-Object -Last 3)) { L ('      ' + (Cut (San ([string]$ln)) 170)) }
        exit 2
    }
    L '   social-auto-upload cloned (shallow)'
}

# ---------------- 4. register + start the tg bridge task ----------------
$null = & schtasks /end /tn media-bridge-tg 2>$null
$null = & schtasks /delete /tn media-bridge-tg /f 2>$null
$tr = 'powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + (Join-Path $base 'run_tg_bridge.ps1') + '"'
$null = & schtasks /create /tn media-bridge-tg /tr $tr /sc onlogon /f 2>&1
L ('   schtasks create media-bridge-tg rc=' + $LASTEXITCODE)
$null = & schtasks /run /tn media-bridge-tg 2>&1
Start-Sleep -Seconds 10
$tgLog = Join-Path $base 'logs\tg_bridge.log'
$bridgeAlive = $false
if (Test-Path -LiteralPath $tgLog) {
    foreach ($ln in @(Get-Content -LiteralPath $tgLog -Tail 6)) { L ('   tg| ' + (Cut (San ([string]$ln)) 150)) }
    if ([IO.File]::ReadAllText($tgLog) -match 'tg_bridge start') { $bridgeAlive = $true }
}
else { L '   [WARN] tg_bridge.log not written yet' }

# ---------------- 5. self-checks ----------------
$wx = & $venvPy -X utf8 (Join-Path $base 'wxmp_cli.py') check 2>&1
L '   --- wxmp check (config missing = expected) ---'
foreach ($ln in @($wx | Select-Object -First 4)) { $t = ((San ([string]$ln)).Trim()); if ($t) { L ('   wx| ' + (Cut $t 160)) } }
$xh = & $venvPy -X utf8 (Join-Path $base 'xhs_publish.py') 2>&1
L '   --- xhs status ---'
foreach ($ln in @($xh | Select-Object -First 8)) { $t = ((San ([string]$ln)).Trim()); if ($t) { L ('   xh| ' + (Cut $t 160)) } }

# ---------------- verdict ----------------
$ok = $bridgeAlive -and (Test-Path -LiteralPath (Join-Path $sau '.git'))
if ($ok) {
    L '   FINAL: PASS - media-bridge base installed; tg bridge alive and waiting for conf\tg_token.txt'
    L ('   layout: ' + $base)
    L '   next (user): BotFather token -> conf\tg_token.txt ; AppID/secret -> conf\wxmp.txt ; xhs stack installs next round'
}
else { L '   FINAL: FAIL - see lines above'; exit 2 }
L '--- task t136 done ---'
exit 0
