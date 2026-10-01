# t112_desk_deck_collect.ps1 - round 148 task: (task 2 finale, desktop)
# Run the 12-slide deck builder through WPS COM on the desktop, then copy
# all artifacts (arena_report.pptx + smoke test outputs) from F$ into the
# repo results tree. No laptop testing (user cancelled). ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t112: desktop 12-slide deck + artifact collection ---'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'

# ---------------- A. run the deck builder on the desktop ----------------
$job = Start-Job -ScriptBlock {
    param($o, $t, $h)
    & ssh @o ($t + '@' + $h) 'py -3.12 F:\fig1_rebuild\harness_results\desk_harness_deck.py' 2>&1 | Out-String
} -ArgumentList $sshBase, $duser, $desktop
if (-not (Wait-Job $job -Timeout 600)) {
    Stop-Job $job -Force -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    L '   [FAIL] deck build timed out'
    exit 2
}
$out = (Receive-Job $job | Out-String).Trim()
Remove-Job $job -Force -ErrorAction SilentlyContinue
foreach ($ln in ($out -split "`r?`n")) {
    $x = San $ln
    if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ +') { L ('   ' + $x) }
}

# ---------------- B. collect artifacts into the repo ----------------
$dest = Join-Path $repoRoot 'results\harness_wps\desktop'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [WARN] F$ unreachable - artifacts stay on F:' }
else {
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
    L ('   REPO COPY: ' + $pptx + ' (' + [math]::Round((Get-Item -LiteralPath $pptx).Length/1KB) + 'KB)')
    L ('   DESKTOP COPY: F:\fig1_rebuild\harness_results\arena_report.pptx')
}
else { L '   [FAIL] arena_report.pptx not collected' }
L '--- task t112 done ---'
exit 0
