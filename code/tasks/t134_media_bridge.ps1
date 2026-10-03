# t134_media_bridge.ps1 - round 176 task: runs ON THE LAPTOP. Green-channel
# media bridge base install at E:\0github\git-sync\media-bridge\:
#   1. stage tg_bridge.py / wxmp_cli.py / xhs_publish.py / run_tg_bridge.ps1
#      from the repo + create conf/logs/cookies/content dirs,
#   2. python venv + wechatpy (tuna mirror, no proxy needed),
#   3. shallow-clone social-auto-upload (git proxy already configured),
#   4. register + start the media-bridge-tg scheduled task (keeps the
#      Telegram bridge alive at logon),
#   5. self-checks: bridge log alive, wechatpy import, wxmp check (expect
#      'config missing' until the user adds credentials), xhs status.
# Credentials are NEVER part of this task: the user drops token/AppID/
# secret into conf\ files afterwards (see code\media-bridge\SETUP.md).
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }
function Cut([string]$s, [int]$n) { if ($s.Length -gt $n) { return $s.Substring(0, $n) }; return $s }

$base = 'E:\0github\git-sync\media-bridge'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

L '--- task t134: media-bridge green base (tg + wxmp + xhs skeleton) ---'

# ---------------- 1. stage scripts + dirs ----------------
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
L '   staged: 4 scripts + conf/logs/cookies/content dirs'

# config templates (only if absent - never overwrite user secrets)
$wxmpCfg = Join-Path $base 'conf\wxmp.txt'
if (-not (Test-Path -LiteralPath $wxmpCfg)) {
    $lines = @('# put your WeChat Official Account credentials here (two lines):', '# appid=wx1234567890abcdef', '# secret=your_app_secret_here')
    [IO.File]::WriteAllLines($wxmpCfg, $lines, (New-Object System.Text.ASCIIEncoding))
    L '   wrote conf\wxmp.txt template (commented out)'
}
if (-not (Test-Path -LiteralPath (Join-Path $base 'conf\tg_token.txt'))) {
    L '   note: conf\tg_token.txt absent (expected - user adds the BotFather token)'
}

# ---------------- 2. python + venv + wechatpy ----------------
$pyExe = ''
foreach ($cand in @('py -3', 'python')) {
    try {
        $v = & cmd /c ($cand + ' --version') 2>&1
        if ($LASTEXITCODE -eq 0 -and ($v -match 'Python')) { $pyExe = $cand; L ('   python launcher: ' + $cand + ' -> ' + (San (($v | Out-String).Trim()))); break }
    } catch { }
}
if (-not $pyExe) { L '   [FAIL] no python on PATH (py -3 / python)'; exit 2 }
$venvPy = Join-Path $base 'venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $venvPy)) {
    $null = & cmd /c ($pyExe + ' -m venv "' + (Join-Path $base 'venv') + '"') 2>&1
    if (-not (Test-Path -LiteralPath $venvPy)) { L '   [FAIL] venv creation failed'; exit 2 }
    L '   venv created'
}
else { L '   venv already present' }
$imp = & $venvPy -c "import wechatpy; print(wechatpy.__version__)" 2>&1
if ($LASTEXITCODE -eq 0) { L ('   wechatpy already installed: ' + (San (($imp | Out-String).Trim()))) }
else {
    L '   installing wechatpy via tuna mirror ...'
    $pi = & $venvPy -m pip install -q -i https://pypi.tuna.tsinghua.edu.cn/simple wechatpy 2>&1
    $imp = & $venvPy -c "import wechatpy; print(wechatpy.__version__)" 2>&1
    if ($LASTEXITCODE -ne 0) {
        L ('   [FAIL] wechatpy install failed:')
        foreach ($ln in @($pi | Select-Object -Last 4)) { L ('      ' + (Cut (San ([string]$ln)) 170)) }
        exit 2
    }
    L ('   wechatpy installed: ' + (San (($imp | Out-String).Trim())))
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
    $tgTxt = [IO.File]::ReadAllText($tgLog)
    if ($tgTxt -match 'tg_bridge start') { $bridgeAlive = $true }
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
else {
    L '   FINAL: FAIL - see lines above'
    exit 2
}
L '--- task t134 done ---'
exit 0
