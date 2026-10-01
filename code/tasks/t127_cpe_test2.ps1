# t127_cpe_test2.ps1 - round 169 task: (cell_ppt_edited skill, desktop only)
# retry the LIVE integration acceptance. r168 already proved self-test and
# doctor (rc=0) and 7/27 checks, but the run died at step 8 with a
# transient COM RPC_E_CALL_REJECTED busy error. This round re-runs the
# full integration.py acceptance up to 3 times (fresh out dir + POWERPNT
# kill each attempt) and collects the best attempt's artifacts.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t127: cell_ppt_edited live acceptance retry ---'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'

$fp = Join-Path $repoRoot 'code\tasks\desk_cpe_test2.ps1'
$tok = $null; $perrs = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($fp, [ref]$tok, [ref]$perrs)
if ($perrs -and $perrs.Count -gt 0) {
    L ('   [FAIL] parse errors in desk_cpe_test2.ps1: ' + $perrs.Count)
    foreach ($e in ($perrs | Select-Object -First 3)) { L ('      line ' + $e.Extent.StartLineNumber + ': ' + (San $e.Message)) }
    exit 2
}
L '   parse check: OK'

$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
try {
    Copy-Item -LiteralPath $fp -Destination ($fshare + '\fig1_rebuild\desk_cpe_test2.ps1') -Force
    L '   staged desk_cpe_test2.ps1'
}
finally { & net use $fshare /delete 2>&1 | Out-Null }

$job = Start-Job -ScriptBlock {
    param($o, $t, $h)
    & ssh @o ($t + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\desk_cpe_test2.ps1' 2>&1 | Out-String
} -ArgumentList $sshBase, $duser, $desktop
if (-not (Wait-Job $job -Timeout 980)) {
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
$dest = Join-Path $repoRoot 'results\cell_ppt_edited'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$netOut2 = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -eq 0) {
    try {
        foreach ($f in @('integration_log.txt', 'integ_a1.txt', 'integ_a2.txt', 'integ_a3.txt')) {
            $src = $fshare + '\fig1_rebuild\cpe\' + $f
            if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $dest $f) -Force; L ('   collected: ' + $f) }
        }
        $oDir = $fshare + '\fig1_rebuild\cpe\integration_out'
        if (Test-Path -LiteralPath $oDir) {
            foreach ($f in @(Get-ChildItem -LiteralPath $oDir -File)) {
                Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $dest $f.Name) -Force
                L ('   collected: ' + $f.Name + ' (' + [math]::Round($f.Length/1KB) + 'KB)')
            }
        }
    }
    finally { & net use $fshare /delete 2>&1 | Out-Null }
}
$acc = Join-Path $dest 'acceptance.pptx'
if (Test-Path -LiteralPath $acc) {
    L ('   RESULT repo: ' + $acc)
    L '   RESULT desktop: F:\fig1_rebuild\cpe\integration_out\acceptance.pptx'
}
else { L '   [FAIL] acceptance artifacts not collected' }
$ajs = Join-Path $dest 'acceptance.json'
if (Test-Path -LiteralPath $ajs) { L '   RESULT acceptance.json present: run reached full completion' }
L '--- task t127 done ---'
exit 0
