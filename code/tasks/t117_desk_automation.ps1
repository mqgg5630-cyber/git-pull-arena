# t117_desk_automation.ps1 - round 153 task: (task 2) fix the desktop WPS
# COM registration the classic way (LocalServer32 WITH /Automation, HKLM),
# verify COM, run the harness pipeline if healthy, else start the 32-bit
# build download as fallback. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t117: desktop WPS /Automation registration + pipeline ---'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'

$fp = Join-Path $repoRoot 'code\tasks\desk_wps_automation.ps1'
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
    Copy-Item -LiteralPath $fp -Destination ($fshare + '\fig1_rebuild\desk_wps_automation.ps1') -Force
    L '   staged desk_wps_automation.ps1'
}
finally { & net use $fshare /delete 2>&1 | Out-Null }

$job = Start-Job -ScriptBlock {
    param($o, $t, $h)
    & ssh @o ($t + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\desk_wps_automation.ps1' 2>&1 | Out-String
} -ArgumentList $sshBase, $duser, $desktop
if (-not (Wait-Job $job -Timeout 1500)) {
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

# collect artifacts if the deck got produced
$dest = Join-Path $repoRoot 'results\harness_wps\desktop'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$netOut2 = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -eq 0) {
    try {
        foreach ($f in @('arena_report.pptx', 'proj_deck.json', 'test_writer.docx', 'test_impress.pptx', 'interactive_log.txt')) {
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
L '--- task t117 done ---'
exit 0
