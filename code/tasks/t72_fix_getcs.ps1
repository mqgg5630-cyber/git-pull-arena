# t72_fix_getcs.ps1 - round 93 task: insert the missing Get-CsIllustratorExe
# helper into both cell-lct run_cell_lct.ps1 copies (the t71 bridge port
# referenced it but did not carry its definition), rewrite FRESH.marker and
# relaunch the worker (fresh redraw via cell-lct skill). ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t72: add Get-CsIllustratorExe to cell-lct runners + relaunch ---'

$getCls = @'
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

'@

$home_ = [Environment]::GetFolderPath('UserProfile')
$targets = @(
    'E:\cell-lct-free\plugins\cell-lct\skills\cell-lct\scripts\run_cell_lct.ps1',
    (Join-Path $home_ '.codex\skills\cell-lct\scripts\run_cell_lct.ps1')
)
foreach ($f in $targets) {
    if (-not (Test-Path -LiteralPath $f)) { L ('   [WARN] missing: ' + $f); continue }
    $raw = [string]([IO.File]::ReadAllText($f))
    if ($raw -match 'function Get-CsIllustratorExe') { L ('   already has Get-CsIllustratorExe: ' + $f); continue }
    $anchor = 'function Invoke-CsAiScript'
    $i = $raw.IndexOf($anchor)
    if ($i -lt 0) { L ('   [WARN] no Invoke-CsAiScript anchor in ' + $f); continue }
    $patched = $raw.Substring(0, $i) + $getCls + $raw.Substring($i)
    $patched = $patched -replace "`r?`n", "`r`n"
    [IO.File]::WriteAllText($f, $patched, (New-Object System.Text.UTF8Encoding($false)))
    $errs = $null
    $null = [System.Management.Automation.PSParser]::Tokenize($patched, [ref]$errs)
    if (@($errs).Count -eq 0 -and $patched -match 'function Get-CsIllustratorExe') {
        L ('   Get-CsIllustratorExe INSERTED + PARSE OK: ' + $f)
    } else { L ('   [FAIL] insert/parse problem: ' + $f) }
}

# ------------------------------------------------ relaunch worker (FRESH)
$stage = 'E:\fig1_rebuild'
$staleWorkers = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'fig1_rebuild_worker' })
foreach ($p in $staleWorkers) { try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
L ('   stale workers stopped: ' + $staleWorkers.Count)

foreach ($m in @('DONE.marker', 'FAILED.marker')) { Remove-Item -LiteralPath (Join-Path $stage $m) -Force -ErrorAction SilentlyContinue }
foreach ($f in @('lct_run1.log', 'lct_run2.log', 'lct_run3.log', 'lct_err1.log', 'lct_err2.log', 'lct_err3.log')) {
    Remove-Item -LiteralPath (Join-Path $stage $f) -Force -ErrorAction SilentlyContinue
}
'fresh' | Out-File -FilePath (Join-Path $stage 'FRESH.marker') -Encoding ascii
L '   FRESH.marker rewritten'

Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $stage 'fig1_rebuild_worker.ps1') + '"')) -WindowStyle Hidden
L '   worker relaunched detached'
Start-Sleep -Seconds 45

$logPath = Join-Path $stage 'rebuild.log'
if (Test-Path -LiteralPath $logPath) {
    L '   --- rebuild.log tail ---'
    $tail = @(Get-Content -LiteralPath $logPath -Tail 16 -ErrorAction SilentlyContinue)
    foreach ($t in $tail) { $x = San ([string]$t); if ($x.Trim()) { L ('   | ' + $x) } }
}
L ('   Illustrator processes: ' + @(Get-Process -Name Illustrator -ErrorAction SilentlyContinue).Count)
L '--- task t72 ok ---'
exit 0
