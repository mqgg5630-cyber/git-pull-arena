# t120_desk_warm.ps1 - round 158 task: (task 2 closure) keep a wpp.exe
# warm instance alive via an interactive task so COM attaches to it (the
# r153 success state), then deck + impress smoke + collection.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t120: desktop WPP warm-instance pipeline ---'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
$haDir = Join-Path $repoRoot 'skills\harness-anything'

$fp = Join-Path $repoRoot 'code\tasks\desk_wpp_warm.ps1'
$tok = $null; $perrs = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($fp, [ref]$tok, [ref]$perrs)
if ($perrs -and $perrs.Count -gt 0) {
    L ('   [FAIL] parse errors: ' + $perrs.Count)
    foreach ($e in ($perrs | Select-Object -First 3)) { L ('      line ' + $e.Extent.StartLineNumber + ': ' + (San $e.Message)) }
    exit 2
}
L '   parse check: OK'

$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
try {
    & robocopy $haDir ($fshare + '\fig1_rebuild\harness-anything') /E /MT:16 /NFL /NDL /NJH /NP 2>&1 | Out-Null
    Copy-Item -LiteralPath $fp -Destination ($fshare + '\fig1_rebuild\desk_wpp_warm.ps1') -Force
    L '   staged harness + warm pipeline script'
}
finally { & net use $fshare /delete 2>&1 | Out-Null }

$job = Start-Job -ScriptBlock {
    param($o, $t, $h)
    & ssh @o ($t + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\desk_wpp_warm.ps1' 2>&1 | Out-String
} -ArgumentList $sshBase, $duser, $desktop
if (-not (Wait-Job $job -Timeout 900)) {
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
        foreach ($f in @('arena_report.pptx', 'proj_deck.json', 'test_writer.docx', 'test_impress.pptx', 'proj_writer.json', 'proj_impress.json')) {
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
L '--- task t120 done ---'
exit 0
