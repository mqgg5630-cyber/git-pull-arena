# t71_install_celllct.ps1 - round 87 task: install GitHub cell-lct on the
# machine: (1) official yrui-cmd/cell-lct (SkipApiKey), (2) free edition
# TryLoveMe/cell-lct-free (local vtracer, no API) overwriting the skill;
# (3) port the FULL file-bridge stack (bridge v2 + call sites + connect
# block) and the rotation-anchor patch onto the free edition's
# run_cell_lct.ps1 + cell_lct_cached_runtime.jsx (source + installed).
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t71: install cell-lct (+free) and port the bridge ---'

# ------------------------------------------------ 1. clone + install both
foreach ($d in @('E:\cell-lct', 'E:\cell-lct-free')) {
    if (Test-Path -LiteralPath $d) { L ('   exists, skipping clone: ' + $d) }
}
if (-not (Test-Path -LiteralPath 'E:\cell-lct\.git')) {
    & git clone --depth 1 https://github.com/yrui-cmd/cell-lct.git E:\cell-lct 2>&1 | ForEach-Object { L ('   git| ' + (San ([string]$_))) }
}
if (-not (Test-Path -LiteralPath 'E:\cell-lct-free\.git')) {
    & git clone --depth 1 https://github.com/TryLoveMe/cell-lct-free.git E:\cell-lct-free 2>&1 | ForEach-Object { L ('   git| ' + (San ([string]$_))) }
}
if (-not (Test-Path -LiteralPath 'E:\cell-lct-free\plugins\cell-lct\skills\cell-lct\scripts\run_cell_lct.ps1')) { L '   [FAIL] free edition source missing'; exit 2 }

# official install (skill cell-lct), skip API key prompt
L '   running official setup.ps1 -SkipApiKey ...'
$officialSetupLog = 'E:\celllct_setup1.log'
$p1 = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', 'Set-Location E:\cell-lct; .\setup.ps1 -SkipApiKey *>&1 | Out-File E:\celllct_setup1.log -Encoding utf8') -Wait -PassThru -WindowStyle Hidden
L ('   official setup exit: ' + $p1.ExitCode)
if (Test-Path -LiteralPath $officialSetupLog) {
    $hits = @(Select-String -LiteralPath $officialSetupLog -Pattern 'SETUP_OK|INSTALLED|RUNTIME_CONFIG_OK|DOCTOR_OK|ERROR|FAIL' -ErrorAction SilentlyContinue | Select-Object -First 8)
    foreach ($h in $hits) { L ('   setup1| ' + (San $h.Line)) }
}

# free install (overwrites skill cell-lct with the free edition)
L '   running free setup.ps1 -Force ...'
$p2 = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', 'Set-Location E:\cell-lct-free; .\setup.ps1 -Force *>&1 | Out-File E:\celllct_setup2.log -Encoding utf8') -Wait -PassThru -WindowStyle Hidden
L ('   free setup exit: ' + $p2.ExitCode)
if (Test-Path -LiteralPath 'E:\celllct_setup2.log') {
    $hits = @(Select-String -LiteralPath 'E:\celllct_setup2.log' -Pattern 'SETUP_OK|INSTALLED|RUNTIME_CONFIG_OK|DOCTOR_OK|ERROR|FAIL' -ErrorAction SilentlyContinue | Select-Object -First 8)
    foreach ($h in $hits) { L ('   setup2| ' + (San $h.Line)) }
}

# py -3 must have vtracer + fonttools (free deps)
& py -3 -c "import vtracer, fontTools; print('deps-ok')" 2>$null
if ($LASTEXITCODE -ne 0) {
    L '   installing free deps into py -3 ...'
    & py -3 -m pip install --quiet --disable-pip-version-check -r E:\cell-lct-free\requirements.lock 2>&1 | ForEach-Object { L ('   pip| ' + (San ([string]$_))) }
    & py -3 -c "import vtracer, fontTools; print('deps-ok')" 2>$null
    if ($LASTEXITCODE -ne 0) { L '   [FAIL] py -3 deps still missing'; exit 2 }
}
L '   py -3 deps: vtracer + fontTools OK'

# ------------------------------------------------ 2. port bridge v2 to run_cell_lct.ps1
$bridgeV2 = @'
function Invoke-CsAiScript([string]$script) {
    $bridgeDir = Join-Path ([IO.Path]::GetTempPath()) 'cs_ai_bridge'
    New-Item -ItemType Directory -Force -Path $bridgeDir | Out-Null
    $id = [guid]::NewGuid().ToString('N')
    $scriptFile = Join-Path $bridgeDir ("cs_$id.jsx")
    $resultFile = Join-Path $bridgeDir ("cs_$id.result")
    $rfJs = ($resultFile -replace '\\', '/')
    $guardOpen = "var CELL_LCT_LK=new File('$rfJs.lock');`r`nif(CELL_LCT_LK.exists){var CELL_LCT_D=new File('$rfJs');CELL_LCT_D.encoding='UTF-8';CELL_LCT_D.open('w');CELL_LCT_D.write('ERROR|BRIDGE_DUP_GUARD');CELL_LCT_D.close();}else{CELL_LCT_LK.encoding='UTF-8';CELL_LCT_LK.open('w');CELL_LCT_LK.write('1');CELL_LCT_LK.close();`r`ntry{"
    $guardClose = "`r`n}catch(e){CELL_LCT_RET='ERROR|BRIDGE_JS|'+e.message;}"
    $writer = "(function(){var CELL_LCT_W=null;try{CELL_LCT_W=new File('$rfJs');CELL_LCT_W.encoding='UTF-8';CELL_LCT_W.open('w');CELL_LCT_W.write(String(CELL_LCT_RET));CELL_LCT_W.close();}catch(e){try{CELL_LCT_W=new File('$rfJs');CELL_LCT_W.encoding='UTF-8';CELL_LCT_W.open('w');CELL_LCT_W.write('ERROR|BRIDGE_WRITE|'+e.message);CELL_LCT_W.close();}catch(e2){}}})();"
    [IO.File]::WriteAllText($scriptFile, ($guardOpen + $script + $guardClose + "`r`n" + $writer + "`r`n}"), (New-Object Text.UTF8Encoding($false)))
    $exe = Get-CsIllustratorExe
    for ($delivery = 1; $delivery -le 3; $delivery++) {
        Start-Sleep -Milliseconds 400
        $null = Start-Process -FilePath $exe -ArgumentList @(('"' + $scriptFile + '"'))
        $deadline = [DateTime]::UtcNow.AddSeconds(240)
        while ([DateTime]::UtcNow -lt $deadline) {
            Start-Sleep -Milliseconds 400
            if (Test-Path -LiteralPath $resultFile) {
                Start-Sleep -Milliseconds 200
                $txt = [string]([IO.File]::ReadAllText($resultFile))
                Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath ($resultFile + '.lock') -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $scriptFile -Force -ErrorAction SilentlyContinue
                return $txt
            }
        }
        Write-Output "INFO|bridge_redelivery|$delivery|script=$(Split-Path $scriptFile -Leaf)"
    }
    throw "AI_BRIDGE_TIMEOUT|delivered 3x with no result (240s each)|script=$scriptFile"
}

function Invoke-CachedRuntime([object]$illustrator, [object]$configuration) {
    $configJson = ConvertTo-JsJson $configuration
    $runtimeJson = (($runtimePath -replace '\\', '/') | ConvertTo-Json -Compress)
    $bootstrap = "var CELL_LCT_CACHED_CONFIG = $configJson;`r`n" +
        "var CELL_LCT_RET = String(`$.evalFile(new File($runtimeJson)));"
    return Invoke-CsAiScript $bootstrap
}
'@

$connectNew = @'
$illustrator = $null
$batchPayloadPath = Join-Path $workPath 'current-batch.json'
try {
    # File-bridge mode: the repacked AI 2020 has no COM registration, so
    # scripts execute inside the already-open Illustrator via exe argument.
    $bridgeVersion = Invoke-CsAiScript 'var CELL_LCT_RET = String(app.version);'
    Write-Output "INFO|bridge_illustrator_version=$bridgeVersion"
    if ([version]$bridgeVersion -lt [version]'24.0') {
        throw "Illustrator 2020 (24.0) or newer is required; connected version is $bridgeVersion."
    }
    $bridgeDocs = Invoke-CsAiScript 'var CELL_LCT_RET = String(app.documents.length);'
    if ([int]$bridgeDocs -lt 1) {
        throw 'AI_DOCUMENT_REQUIRED|Open the target Illustrator document yourself before drawing.'
    }

    $targetDocumentName = Invoke-CsAiScript 'var CELL_LCT_RET = String(app.activeDocument.name);'
'@

$home_ = [Environment]::GetFolderPath('UserProfile')
$ps1Targets = @(
    'E:\cell-lct-free\plugins\cell-lct\skills\cell-lct\scripts\run_cell_lct.ps1',
    (Join-Path $home_ '.codex\skills\cell-lct\scripts\run_cell_lct.ps1')
)
foreach ($f in $ps1Targets) {
    if (-not (Test-Path -LiteralPath $f)) { L ('   [WARN] missing: ' + $f); continue }
    $raw = [string]([IO.File]::ReadAllText($f))
    if ($raw -match 'BRIDGE_DUP_GUARD') { L ('   already bridge-v2: ' + $f); continue }
    # 2a. replace Invoke-CachedRuntime function block
    $sF = $raw.IndexOf('function Invoke-CachedRuntime')
    if ($sF -lt 0) { L ('   [ABORT] no Invoke-CachedRuntime in ' + $f); continue }
    $iBoot = $raw.IndexOf('DoJavaScript($bootstrap)', $sF)
    if ($iBoot -lt 0) { L ('   [ABORT] bootstrap line missing in ' + $f); continue }
    $eF = $raw.IndexOf('}', $iBoot)
    $raw = $raw.Substring(0, $sF) + $bridgeV2 + $raw.Substring($eF + 1)
    # 2b. rewrite the three call sites
    $oldCall = '$result = [string]$illustrator.DoJavaScript($script)'
    $cnt = ([regex]::Matches($raw, [regex]::Escape($oldCall))).Count
    $raw = $raw.Replace($oldCall, '$result = Invoke-CsAiScript ("var CELL_LCT_RET = String(" + $script.TrimEnd().TrimEnd('';'') + ");")')
    L ('   call sites rewritten: ' + $cnt + ' (expect 3): ' + $f)
    # 2c. connect block
    $sC = $raw.IndexOf('$illustrator = $null')
    $iDoc = $raw.IndexOf('ActiveDocument.Name', $sC)
    if ($sC -lt 0 -or $iDoc -lt 0) { L ('   [ABORT] connect anchors missing in ' + $f); continue }
    $eC = $iDoc + 'ActiveDocument.Name'.Length
    $nl = $raw.IndexOf("`n", $eC)
    if ($nl -ge 0) { $eC = $nl }
    $raw = $raw.Substring(0, $sC) + $connectNew + $raw.Substring($eC)
    # 2d. normalize + write + parse check
    $raw = $raw -replace "`r?`n", "`r`n"
    [IO.File]::WriteAllText($f, $raw, (New-Object System.Text.UTF8Encoding($false)))
    $errs = $null
    $null = [System.Management.Automation.PSParser]::Tokenize($raw, [ref]$errs)
    if (@($errs).Count -eq 0) { L ('   BRIDGE-V2 PATCHED + PARSE OK: ' + $f) }
    else { L ('   [FAIL] parse errors: ' + @($errs).Count + ' first: ' + (San $errs[0].Message)) }
}

# ------------------------------------------------ 3. rotation-anchor patch (jsx)
$rotBlock = @'
if (textStyle.rotationDegrees) {
        var anchorBefore = [created.position[0], created.position[1]];
        try {
          created.rotate(-textStyle.rotationDegrees, true, true, true, true, Transformation.BOTTOMLEFT);
        } catch (rotErr) {
          created.rotate(-textStyle.rotationDegrees);
        }
        var anchorAfter = created.position;
        if (Math.abs(anchorAfter[0] - anchorBefore[0]) > 0.01 || Math.abs(anchorAfter[1] - anchorBefore[1]) > 0.01) {
          created.translate(anchorBefore[0] - anchorAfter[0], anchorBefore[1] - anchorAfter[1]);
        }
      }
'@
$jsxTargets = @(
    'E:\cell-lct-free\plugins\cell-lct\skills\cell-lct\scripts\cell_lct_cached_runtime.jsx',
    (Join-Path $home_ '.codex\skills\cell-lct\scripts\cell_lct_cached_runtime.jsx')
)
foreach ($f in $jsxTargets) {
    if (-not (Test-Path -LiteralPath $f)) { L ('   [WARN] missing: ' + $f); continue }
    $raw = [string]([IO.File]::ReadAllText($f))
    if ($raw -match 'anchorBefore') { L ('   already rotation-patched: ' + $f); continue }
    $needle = 'if (textStyle.rotationDegrees) created.rotate(-textStyle.rotationDegrees);'
    $i = $raw.IndexOf($needle)
    if ($i -lt 0) { L ('   [WARN] rotation needle missing in ' + $f); continue }
    $lineEnd = $raw.IndexOf("`n", $i)
    if ($lineEnd -lt 0) { $lineEnd = $raw.Length - 1 }
    $patched = $raw.Substring(0, $i) + $rotBlock + $raw.Substring($lineEnd + 1)
    $patched = $patched -replace "`r?`n", "`r`n"
    [IO.File]::WriteAllText($f, $patched, (New-Object System.Text.UTF8Encoding($false)))
    if (Select-String -LiteralPath $f -Pattern 'anchorBefore' -Quiet) { L ('   ROTATION-ANCHOR PATCHED: ' + $f) }
}

# ------------------------------------------------ 4. inventory + verify
$skillDir = Join-Path $home_ '.codex\skills\cell-lct\scripts'
foreach ($n in @('run_cell_lct.ps1', 'cell_lct_cached_runtime.jsx', 'local_vectorize.py', 'merge_live_text.py', 'allocate_shibielujing_name.py', 'validate_vector_svg.py')) {
    $p = Join-Path $skillDir $n
    L ('   installed file ' + $n + ': ' + (Test-Path -LiteralPath $p))
}
$installedRunner = Join-Path $skillDir 'run_cell_lct.ps1'
if (Test-Path -LiteralPath $installedRunner) {
    $chk = [string]([IO.File]::ReadAllText($installedRunner))
    L ('   installed bridge v2: ' + ($chk -match 'BRIDGE_DUP_GUARD') + ' | call sites: ' + ([regex]::Matches($chk, 'Invoke-CsAiScript')).Count)
}
L '--- task t71 ok ---'
exit 0
