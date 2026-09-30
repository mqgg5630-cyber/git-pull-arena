# t68_bridge_v2_resume.ps1 - round 82 task: (1) patch Invoke-CsAiScript to
# v2 in both run_cell_lct.ps1 copies (400ms spacing, 3x redelivery with
# 240s windows, dup-guard lock, try/catch fast error pass-through);
# (2) clean stale temp bridge files; (3) restage worker v3 + relaunch
# detached (resume mode: final phase only for shibielujing1). ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }

Write-Output '--- task t68: bridge v2 patch + resume worker v3 ---'

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
'@

$targets = @(
    'E:\cell_su7\plugins\cell_su7\skills\cell_su7\scripts\run_cell_lct.ps1',
    (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex\skills\cell_su7\scripts\run_cell_lct.ps1')
)
foreach ($f in $targets) {
    if (-not (Test-Path -LiteralPath $f)) { Write-Output ('   [WARN] missing: ' + $f); continue }
    $raw = [string]([IO.File]::ReadAllText($f))
    if ($raw -match 'BRIDGE_DUP_GUARD') { Write-Output ('   already v2: ' + $f); continue }
    $s = $raw.IndexOf('function Invoke-CsAiScript')
    if ($s -lt 0) { Write-Output ('   [WARN] no Invoke-CsAiScript in ' + $f); continue }
    $e = $raw.IndexOf('AI_BRIDGE_TIMEOUT', $s)
    if ($e -lt 0) { Write-Output ('   [WARN] no timeout marker in ' + $f); continue }
    $close = $raw.IndexOf('}', $e)
    if ($close -lt 0) { Write-Output ('   [WARN] no closing brace in ' + $f); continue }
    $patched = $raw.Substring(0, $s) + $bridgeV2 + $raw.Substring($close + 1)
    $patched = $patched -replace "`r?`n", "`r`n"
    [IO.File]::WriteAllText($f, $patched, (New-Object System.Text.UTF8Encoding($false)))
    $errs = $null
    $null = [System.Management.Automation.PSParser]::Tokenize($patched, [ref]$errs)
    if (@($errs).Count -eq 0) { Write-Output ('   BRIDGE-V2 PATCHED + PARSE OK: ' + $f) }
    else { Write-Output ('   [FAIL] parse errors after patch: ' + @($errs).Count + ' - ' + (San $errs[0].Message)) }
}

# ------------------------------------------------ 2. clean stale temp bridge files
$bridgeTemp = Join-Path ([IO.Path]::GetTempPath()) 'cs_ai_bridge'
if (Test-Path -LiteralPath $bridgeTemp) {
    $stale = @(Get-ChildItem -LiteralPath $bridgeTemp -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt [DateTime]::Now.AddMinutes(-5) })
    foreach ($sf in $stale) { Remove-Item -LiteralPath $sf.FullName -Force -ErrorAction SilentlyContinue }
    Write-Output ('   stale bridge temp files removed: ' + $stale.Count)
}

# ------------------------------------------------ 3. restage + relaunch worker v3
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$stage = 'E:\fig1_rebuild'
$workerSrc = Join-Path $repoRoot 'code\tasks\fig1_rebuild_worker.ps1'
if (-not (Test-Path -LiteralPath $workerSrc)) { Write-Output '   [FAIL] worker source missing'; exit 2 }
if (-not (Select-String -LiteralPath $workerSrc -Pattern 'WORKER v3' -Quiet)) { Write-Output '   [FAIL] worker source is not v3'; exit 2 }

# stop stale workers (none expected)
$staleWorkers = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'fig1_rebuild_worker' })
foreach ($p in $staleWorkers) { try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
Write-Output ('   stale workers stopped: ' + $staleWorkers.Count)

foreach ($m in @('DONE.marker', 'FAILED.marker')) { Remove-Item -LiteralPath (Join-Path $stage $m) -Force -ErrorAction SilentlyContinue }
foreach ($f in @('lct_run1.log', 'lct_run2.log', 'lct_run3.log', 'lct_err1.log', 'lct_err2.log', 'lct_err3.log')) {
    Remove-Item -LiteralPath (Join-Path $stage $f) -Force -ErrorAction SilentlyContinue
}
Copy-Item -LiteralPath $workerSrc -Destination (Join-Path $stage 'fig1_rebuild_worker.ps1') -Force
Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $stage 'fig1_rebuild_worker.ps1') + '"')) -WindowStyle Hidden
Write-Output '   worker v3 launched detached'
Start-Sleep -Seconds 40

$logPath = Join-Path $stage 'rebuild.log'
if (Test-Path -LiteralPath $logPath) {
    Write-Output '   --- rebuild.log tail ---'
    $tail = @(Get-Content -LiteralPath $logPath -Tail 16 -ErrorAction SilentlyContinue)
    foreach ($t in $tail) { $x = San ([string]$t); if ($x.Trim()) { Write-Output ('   | ' + $x) } }
} else { Write-Output '   [WARN] rebuild.log not created yet' }
Write-Output ('   Illustrator processes: ' + @(Get-Process -Name Illustrator -ErrorAction SilentlyContinue).Count)
Write-Output '--- task t68 ok ---'
exit 0
