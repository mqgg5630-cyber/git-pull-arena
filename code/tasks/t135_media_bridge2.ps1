# t135_media_bridge2.ps1 - round 177 task: runs ON THE LAPTOP. Retry of the
# media-bridge base (r176 installed fine but wechatpy failed instantly with
# 'from versions: none' - pip most likely routed through a dead/proxied
# path to the mirror). This version:
#   - scrubs HTTP(S)_PROXY/ALL_PROXY from the PROCESS env for pip (a proxy
#     env var pointing anywhere would break domestic mirrors),
#   - logs pip config + which env vars were scrubbed (diagnostics),
#   - tries mirrors in order: aliyun -> tuna -> pypi direct -> pypi via
#     the local v2ray proxy,
#   - then finishes the rest of the base: social-auto-upload clone,
#     media-bridge-tg scheduled task, self-checks.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }
function Cut([string]$s, [int]$n) { if ($s.Length -gt $n) { return $s.Substring(0, $n) }; return $s }

$base = 'E:\0github\git-sync\media-bridge'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

L '--- task t135: media-bridge green base v2 (resilient pip) ---'

# ---------------- 1. stage scripts + dirs (idempotent) ----------------
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
L '   staged: 4 scripts + dirs'

# ---------------- 2. venv + wechatpy with resilient pip ----------------
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

# scrub proxy env for THIS process so domestic mirrors are reached direct
$scrubbed = @()
foreach ($k in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy')) {
    if ([Environment]::GetEnvironmentVariable($k)) { $scrubbed += $k; [Environment]::SetEnvironmentVariable($k, $null) }
}
if ($scrubbed.Count -gt 0) { L ('   scrubbed proxy env for pip: ' + ($scrubbed -join ', ')) }
else { L '   no proxy env vars set' }
$pc = & $venvPy -m pip config list 2>&1
foreach ($ln in @($pc)) { $t = ((San ([string]$ln)).Trim()); if ($t) { L ('   pipcfg| ' + (Cut $t 130)) } }

$imp = & $venvPy -c "import wechatpy; print(wechatpy.__version__)" 2>&1
if ($LASTEXITCODE -eq 0) { L ('   wechatpy already installed: ' + (San (($imp | Out-String).Trim()))) }
else {
    $mirrors = @(
        'https://mirrors.aliyun.com/pypi/simple/',
        'https://pypi.tuna.tsinghua.edu.cn/simple',
        'https://pypi.org/simple'
    )
    $installed = $false
    foreach ($mi in $mirrors) {
        L ('   pip attempt: ' + $mi)
        $pi = & $venvPy -m pip install --timeout 40 -i $mi wechatpy 2>&1
        $imp = & $venvPy -c "import wechatpy; print(wechatpy.__version__)" 2>&1
        if ($LASTEXITCODE -eq 0) {
            L ('   wechatpy installed from ' + $mi + ' -> ' + (San (($imp | Out-String).Trim())))
            $installed = $true
            break
        }
        foreach ($ln in @($pi | Where-Object { $_ -match 'ERROR|error' } | Select-Object -Last 3)) { L ('      ' + (Cut (San ([string]$ln)) 170)) }
    }
    if (-not $installed) {
        L '   pip attempt: pypi.org via local proxy 127.0.0.1:10808'
        $pi = & $venvPy -m pip install --timeout 40 --proxy http://127.0.0.1:10808 -i https://pypi.org/simple wechatpy 2>&1
        $imp = & $venvPy -c "import wechatpy; print(wechatpy.__version__)" 2>&1
        if ($LASTEXITCODE -eq 0) {
            L ('   wechatpy installed via proxy -> ' + (San (($imp | Out-String).Trim())))
            $installed = $true
        }
        else {
            L '   [FAIL] all pip routes failed:'
            foreach ($ln in @($pi | Select-Object -Last 6)) { L ('      ' + (Cut (San ([string]$ln)) 170)) }
            exit 2
        }
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
L '--- task t135 done ---'
exit 0
