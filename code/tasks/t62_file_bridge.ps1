# t62_file_bridge.ps1 - round 75 task: (1) prove Illustrator.exe runs a JSX
# passed as argument (cold start) AND delegates to the already-running
# instance (warm) - the two prerequisites for a file-based bridge; (2) if
# proven, patch run_cell_lct.ps1 (E:\cell_su7 + installed skill copy) to use
# the file bridge instead of COM. ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t62: file-bridge proof + run_cell_lct.ps1 bridge patch ---'

# ------------------------------------------------ 0. locate Illustrator.exe
$aiExe = $null
foreach ($d in @(Get-ChildItem -Path 'E:\' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Illustrator' })) {
    $cand = Join-Path $d.FullName 'Support Files\Contents\Windows\Illustrator.exe'
    if (Test-Path -LiteralPath $cand) { $aiExe = $cand; break }
}
if (-not $aiExe) { Write-Output '   [FAIL] Illustrator.exe not found'; exit 2 }
Write-Output ('   Illustrator.exe: ' + $aiExe)
$bridgeDir = 'E:\cs_bridge'
New-Item -ItemType Directory -Force -Path $bridgeDir | Out-Null
Remove-Item -Path (Join-Path $bridgeDir '*.txt') -Force -ErrorAction SilentlyContinue

function Wait-Marker([string]$file, [int]$sec) {
    $deadline = [DateTime]::UtcNow.AddSeconds($sec)
    while ([DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 500
        if (Test-Path -LiteralPath $file) { return (Get-Content -LiteralPath $file -Raw) }
    }
    return $null
}

# ------------------------------------------------ 1. cold start test
Write-Output '--- 1. cold start: Illustrator.exe m1.jsx ---'
try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }
Start-Sleep -Seconds 2
$m1 = Join-Path $bridgeDir 'm1.jsx'
$js1 = '(function(){var f=new File("E:/cs_bridge/m1.txt");f.encoding="UTF-8";f.open("w");f.write("version="+app.version+"|docs="+app.documents.length+"|marker=cold");f.close();app.documents.add();var g=new File("E:/cs_bridge/m1b.txt");g.encoding="UTF-8";g.open("w");g.write("docs_after_add="+app.documents.length);g.close();})();'
[System.IO.File]::WriteAllText($m1, $js1, (New-Object System.Text.UTF8Encoding($false)))
$t0 = [DateTime]::UtcNow
Start-Process -FilePath $aiExe -ArgumentList @(('"' + $m1 + '"'))
$r1 = Wait-Marker (Join-Path $bridgeDir 'm1.txt') 120
$t1 = [DateTime]::UtcNow
if ($r1) {
    Write-Output ('   COLD MARKER (' + [int]($t1 - $t0).TotalSeconds + 's): ' + (San $r1))
    $r1b = Wait-Marker (Join-Path $bridgeDir 'm1b.txt') 30
    if ($r1b) { Write-Output ('   COLD after-add: ' + (San $r1b)) } else { Write-Output '   [WARN] m1b missing (documents.add failed?)' }
} else {
    Write-Output '   [FAIL] cold marker never appeared (120s) - exe-arg scripting NOT working'
    try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }
    exit 3
}

# ------------------------------------------------ 2. warm delegate test
Write-Output '--- 2. warm delegate: Illustrator.exe m2.jsx with AI running ---'
$m2 = Join-Path $bridgeDir 'm2.jsx'
$js2 = '(function(){var f=new File("E:/cs_bridge/m2.txt");f.encoding="UTF-8";f.open("w");f.write("version="+app.version+"|docs="+app.documents.length+"|active="+(app.documents.length>0?app.activeDocument.name:"NONE"));f.close();})();'
[System.IO.File]::WriteAllText($m2, $js2, (New-Object System.Text.UTF8Encoding($false)))
$t2 = [DateTime]::UtcNow
Start-Process -FilePath $aiExe -ArgumentList @(('"' + $m2 + '"'))
$r2 = Wait-Marker (Join-Path $bridgeDir 'm2.txt') 90
$t3 = [DateTime]::UtcNow
$procCount = @(Get-Process -Name Illustrator -ErrorAction SilentlyContinue).Count
if ($r2) {
    Write-Output ('   WARM MARKER (' + [int]($t3 - $t2).TotalSeconds + 's): ' + (San $r2))
    Write-Output ('   Illustrator processes now: ' + $procCount)
} else {
    Write-Output '   [FAIL] warm marker never appeared (90s)'
    try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }
    exit 3
}

$delegateOk = ($r2 -match 'docs=1') -and ($procCount -eq 1)
if (-not $delegateOk) {
    Write-Output '   [FAIL] delegate not confirmed (second instance or doc not visible) - bridge not viable this way'
    try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }
    exit 3
}
Write-Output '   DELEGATE CONFIRMED: warm script ran in the SAME instance (docs=1, one process)'

# ------------------------------------------------ 3. patch run_cell_lct.ps1
Write-Output '--- 3. file-bridge patch on run_cell_lct.ps1 ---'

$bridgeFuncs = @'
function Get-CsIllustratorExe {
    if ($script:CsAiExePath -and (Test-Path -LiteralPath $script:CsAiExePath)) { return $script:CsAiExePath }
    $found = $null
    foreach ($d in @(Get-ChildItem -Path 'E:\' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Illustrator' })) {
        $cand = Join-Path $d.FullName 'Support Files\Contents\Windows\Illustrator.exe'
        if (Test-Path -LiteralPath $cand) { $found = $cand; break }
    }
    if (-not $found) { throw 'AI_BRIDGE|Illustrator.exe not found under E:\' }
    $script:CsAiExePath = $found
    return $found
}

function Invoke-CsAiScript([string]$script) {
    $bridgeDir = Join-Path ([IO.Path]::GetTempPath()) 'cs_ai_bridge'
    New-Item -ItemType Directory -Force -Path $bridgeDir | Out-Null
    $id = [guid]::NewGuid().ToString('N')
    $scriptFile = Join-Path $bridgeDir ("cs_$id.jsx")
    $resultFile = Join-Path $bridgeDir ("cs_$id.result")
    $rfJs = ($resultFile -replace '\\', '/')
    $writer = "(function(){var CELL_LCT_W=null;try{CELL_LCT_W=new File('$rfJs');CELL_LCT_W.encoding='UTF-8';CELL_LCT_W.open('w');CELL_LCT_W.write(String(CELL_LCT_RET));CELL_LCT_W.close();}catch(e){try{CELL_LCT_W=new File('$rfJs');CELL_LCT_W.encoding='UTF-8';CELL_LCT_W.open('w');CELL_LCT_W.write('ERROR|BRIDGE_WRITE|'+e.message);CELL_LCT_W.close();}catch(e2){}}})();"
    [IO.File]::WriteAllText($scriptFile, ($script + "`r`n" + $writer), (New-Object Text.UTF8Encoding($false)))
    $exe = Get-CsIllustratorExe
    $null = Start-Process -FilePath $exe -ArgumentList @(('"' + $scriptFile + '"'))
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    while ([DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 350
        if (Test-Path -LiteralPath $resultFile) {
            Start-Sleep -Milliseconds 150
            $txt = [string]([IO.File]::ReadAllText($resultFile))
            Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $scriptFile -Force -ErrorAction SilentlyContinue
            return $txt
        }
    }
    throw "AI_BRIDGE_TIMEOUT|no result within 120s|script=$scriptFile"
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

$targets = @(
    'E:\cell_su7\plugins\cell_su7\skills\cell_su7\scripts\run_cell_lct.ps1',
    (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex\skills\cell_su7\scripts\run_cell_lct.ps1')
)
foreach ($f in $targets) {
    if (-not (Test-Path -LiteralPath $f)) { Write-Output ('   [WARN] missing: ' + $f); continue }
    $raw = [string]([IO.File]::ReadAllText($f))
    if ($raw -match 'Invoke-CsAiScript') { Write-Output ('   already bridge-patched: ' + $f); continue }

    # 3a. replace Invoke-CachedRuntime function with bridge functions + new runtime invoker
    $sF = $raw.IndexOf('function Invoke-CachedRuntime')
    if ($sF -lt 0) { Write-Output ('   [ABORT] no Invoke-CachedRuntime in ' + $f); continue }
    $iBoot = $raw.IndexOf('DoJavaScript($bootstrap)', $sF)
    if ($iBoot -lt 0) { Write-Output ('   [ABORT] bootstrap line not found in ' + $f); continue }
    $eF = $raw.IndexOf('}', $iBoot)
    $raw = $raw.Substring(0, $sF) + $bridgeFuncs + $raw.Substring($eF + 1)
    Write-Output ('   bridge functions inserted: ' + $f)

    # 3b. rewrite the three $result = [string]$illustrator.DoJavaScript($script) sites
    $oldCall = '$result = [string]$illustrator.DoJavaScript($script)'
    $callCount = ([regex]::Matches($raw, [regex]::Escape($oldCall))).Count
    $raw = $raw.Replace($oldCall, '$result = Invoke-CsAiScript ("var CELL_LCT_RET = String(" + $script.TrimEnd().TrimEnd('';'') + ");")')
    Write-Output ('   call sites rewritten: ' + $callCount + ' (expect 3): ' + $f)

    # 3c. replace the connect block (from "$illustrator = $null" to end of the ActiveDocument.Name line)
    $sC = $raw.IndexOf('$illustrator = $null')
    $iDoc = $raw.IndexOf('ActiveDocument.Name', $sC)
    if ($sC -lt 0 -or $iDoc -lt 0) { Write-Output ('   [ABORT] connect anchors missing in ' + $f); continue }
    $eC = $iDoc + 'ActiveDocument.Name'.Length
    # extend to end of that line (next newline of either kind)
    $nl = $raw.IndexOf("`n", $eC)
    if ($nl -ge 0) { $eC = $nl }
    $raw = $raw.Substring(0, $sC) + $connectNew + $raw.Substring($eC)
    Write-Output ('   connect block bridged: ' + $f)

    # 3d. normalize line endings + write back UTF-8 no BOM
    $raw = $raw -replace "`r?`n", "`r`n"
    [IO.File]::WriteAllText($f, $raw, (New-Object System.Text.UTF8Encoding($false)))

    # 3e. syntax check
    $errs = $null
    $null = [System.Management.Automation.PSParser]::Tokenize($raw, [ref]$errs)
    if (@($errs).Count -eq 0) { Write-Output ('   PARSE OK: ' + $f) } else { Write-Output ('   [FAIL] parse errors: ' + @($errs).Count + ' first: ' + (San $errs[0].Message)) }
    Write-Output ('   Invoke-CsAiScript occurrences: ' + ([regex]::Matches($raw, 'Invoke-CsAiScript')).Count)
}

# ------------------------------------------------ 4. bridge smoke test
Write-Output '--- 4. bridge smoke (version / docs / activeDocument) ---'
function Invoke-Bridge([string]$script) {
    $id = [guid]::NewGuid().ToString('N')
    $sf = Join-Path $bridgeDir ("s_$id.jsx")
    $rf = Join-Path $bridgeDir ("r_$id.txt")
    $rfJs = ($rf -replace '\\', '/')
    $writer = "(function(){var w=new File('$rfJs');w.encoding='UTF-8';w.open('w');w.write(String(CELL_LCT_RET));w.close();})();"
    [System.IO.File]::WriteAllText($sf, ($script + "`r`n" + $writer), (New-Object System.Text.UTF8Encoding($false)))
    Start-Process -FilePath $aiExe -ArgumentList @(('"' + $sf + '"'))
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    while ([DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 350
        if (Test-Path -LiteralPath $rf) {
            Start-Sleep -Milliseconds 150
            $txt = [string]([IO.File]::ReadAllText($rf))
            Remove-Item -LiteralPath $rf, $sf -Force -ErrorAction SilentlyContinue
            return $txt
        }
    }
    return 'TIMEOUT'
}
Write-Output ('   bridge app.version  = ' + (San (Invoke-Bridge 'var CELL_LCT_RET = String(app.version);')))
Write-Output ('   bridge docs.length  = ' + (San (Invoke-Bridge 'var CELL_LCT_RET = String(app.documents.length);')))
Write-Output ('   bridge activeDoc    = ' + (San (Invoke-Bridge 'var CELL_LCT_RET = String(app.activeDocument.name);')))
Write-Output ('   bridge 1+1          = ' + (San (Invoke-Bridge 'var CELL_LCT_RET = String(1+1);')))

# cleanup: close the test document and stop Illustrator
$null = Invoke-Bridge 'var CELL_LCT_RET = String((function(){try{app.activeDocument.close(SaveOptions.DONOTSAVECHANGES);return "closed";}catch(e){return "err:"+e.message;}})());'
Start-Sleep -Seconds 2
try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue; Write-Output '   (Illustrator stopped)' } catch { }
Write-Output '--- task t62 done ---'
exit 0
