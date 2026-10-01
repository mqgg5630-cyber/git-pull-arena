# t121_desk_warm2.ps1 - round 159 task: (task 2 closure) single-process
# deck build (first-and-only COM client on a warm wpp), interactive-session
# fallback, writer smoke, artifact collection. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t121: desktop WARM2 single-process pipeline ---'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
$haDir = Join-Path $repoRoot 'skills\harness-anything'

foreach ($f in @('desk_warm2.ps1')) {
    $tok = $null; $perrs = $null
    $fp = Join-Path $repoRoot ('code\tasks\' + $f)
    $null = [System.Management.Automation.Language.Parser]::ParseFile($fp, [ref]$tok, [ref]$perrs)
    if ($perrs -and $perrs.Count -gt 0) {
        L ('   [FAIL] parse errors in ' + $f + ': ' + $perrs.Count)
        foreach ($e in ($perrs | Select-Object -First 3)) { L ('      line ' + $e.Extent.StartLineNumber + ': ' + (San $e.Message)) }
        exit 2
    }
}
$pyCheck = & python -c "import ast; ast.parse(open(r'$repoRoot\code\tasks\deck_warm_build.py', encoding='utf-8').read()); print('py OK')" 2>&1
L ('   parse checks: ' + (San ([string]$pyCheck)))

$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
try {
    & robocopy $haDir ($fshare + '\fig1_rebuild\harness-anything') /E /MT:16 /NFL /NDL /NJH /NP 2>&1 | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\desk_warm2.ps1') -Destination ($fshare + '\fig1_rebuild\desk_warm2.ps1') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\deck_warm_build.py') -Destination ($fshare + '\fig1_rebuild\harness_results\deck_warm_build.py') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\desk_harness_deck.py') -Destination ($fshare + '\fig1_rebuild\harness_results\desk_harness_deck.py') -Force
    L '   staged harness + warm2 scripts'
}
finally { & net use $fshare /delete 2>&1 | Out-Null }

$job = Start-Job -ScriptBlock {
    param($o, $t, $h)
    & ssh @o ($t + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\desk_warm2.ps1' 2>&1 | Out-String
} -ArgumentList $sshBase, $duser, $desktop
if (-not (Wait-Job $job -Timeout 1200)) {
    Stop-Job $job -Force -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    L '   [FAIL] remote round timed out'
    exit 2
}
$out = (Receive-Job $job | Out-String).Trim()
Remove-Job $job -Force -ErrorAction SilentlyContinue
foreach ($ln in ($out -split "`r?`n")) {
    $x = San $ln
    if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ +') { L ('   ' + $x) }
}

# ---------------- collect artifacts ----------------
$dest = Join-Path $repoRoot 'results\harness_wps\desktop'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$netOut2 = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -eq 0) {
    try {
        foreach ($f in @('arena_report.pptx', 'proj_deck.json', 'test_writer.docx', 'test_impress.pptx', 'proj_writer.json', 'warm2_log.txt')) {
            $src = $fshare + '\fig1_rebuild\harness_results\' + $f
            if (Test-Path -LiteralPath $src) {
                Copy-Item -LiteralPath $src -Destination (Join-Path $dest $f) -Force
                L ('   collected: ' + $f + ' (' + [math]::Round((Get-Item -LiteralPath $src).Length/1KB) + 'KB)')
            }
        }
    }
    finally { & net use $fshare /delete 2>&1 | Out-Null }
}
$pptx = Join-Path $dest 'arena_report.pptx'
if (Test-Path -LiteralPath $pptx) {
    L ('   RESULT repo: ' + $pptx)
    L '   RESULT desktop: F:\fig1_rebuild\harness_results\arena_report.pptx'
}
else { L '   [FAIL] arena_report.pptx not collected' }
L '--- task t121 done ---'
exit 0
