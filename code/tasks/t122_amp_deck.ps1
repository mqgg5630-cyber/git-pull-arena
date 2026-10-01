# t122_amp_deck.ps1 - round 161 task: generate the 14-slide editable PPTX
# "machine learning prediction of antimicrobial peptides" on the desktop
# (warm wpp + single-process first-client build), then collect artifacts
# into results/amp_deck/. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t122: AMP deck generation (14 slides, editable pptx) ---'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'

$fp = Join-Path $repoRoot 'code\tasks\desk_amp_deck.ps1'
$tok = $null; $perrs = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($fp, [ref]$tok, [ref]$perrs)
if ($perrs -and $perrs.Count -gt 0) {
    L ('   [FAIL] parse errors in desk_amp_deck.ps1: ' + $perrs.Count)
    foreach ($e in ($perrs | Select-Object -First 3)) { L ('      line ' + $e.Extent.StartLineNumber + ': ' + (San $e.Message)) }
    exit 2
}
$pyCheck = & python -c "import ast; ast.parse(open(r'$repoRoot\code\tasks\amp_deck_build.py', encoding='utf-8').read()); print('py OK')" 2>&1
if (([string]$pyCheck) -notmatch 'py OK') { L ('   [FAIL] amp_deck_build.py parse: ' + (San ([string]$pyCheck))); exit 2 }
L '   parse checks: OK'

$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
try {
    Copy-Item -LiteralPath $fp -Destination ($fshare + '\fig1_rebuild\desk_amp_deck.ps1') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\amp_deck_build.py') -Destination ($fshare + '\fig1_rebuild\harness_results\amp_deck_build.py') -Force
    L '   staged desk_amp_deck.ps1 + amp_deck_build.py'
}
finally { & net use $fshare /delete 2>&1 | Out-Null }

$job = Start-Job -ScriptBlock {
    param($o, $t, $h)
    & ssh @o ($t + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\desk_amp_deck.ps1' 2>&1 | Out-String
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
$dest = Join-Path $repoRoot 'results\amp_deck'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$netOut2 = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -eq 0) {
    try {
        foreach ($f in @('amp_ml_prediction.pptx', 'proj_amp.json', 'amp_deck_log.txt')) {
            $src = $fshare + '\fig1_rebuild\harness_results\' + $f
            if (Test-Path -LiteralPath $src) {
                Copy-Item -LiteralPath $src -Destination (Join-Path $dest $f) -Force
                L ('   collected: ' + $f + ' (' + [math]::Round((Get-Item -LiteralPath $src).Length/1KB) + 'KB)')
            }
        }
    }
    finally { & net use $fshare /delete 2>&1 | Out-Null }
}
$pptx = Join-Path $dest 'amp_ml_prediction.pptx'
if (Test-Path -LiteralPath $pptx) {
    L ('   RESULT repo: ' + $pptx)
    L '   RESULT desktop: F:\fig1_rebuild\harness_results\amp_ml_prediction.pptx'
}
else { L '   [FAIL] amp_ml_prediction.pptx not collected' }
L '--- task t122 done ---'
exit 0
