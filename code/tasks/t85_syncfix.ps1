# t85_syncfix.ps1 - round 115 task: diagnose the rc=16 robocopy failure
# (dump the log), then retry the AI 2020 sync with a held SMB session and a
# pre-created destination directory. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t85: robocopy diagnosis + retry ---'

$desktop = '100.84.137.117'
$fshare = '\\' + $desktop + '\F$'
$work = 'E:\fig1_rebuild\desk'
$rcLog = Join-Path $work 'robocopy.log'

# ------------------------------------------------ 1. dump previous log
if (Test-Path -LiteralPath $rcLog) {
    L '   --- previous robocopy.log (first 25 lines) ---'
    foreach ($t in @(Get-Content -LiteralPath $rcLog -TotalCount 25 -ErrorAction SilentlyContinue)) { $x = San ([string]$t); if ($x.Trim()) { L ('   rc| ' + $x) } }
    L '   --- previous robocopy.log (last 10 lines) ---'
    foreach ($t in @(Get-Content -LiteralPath $rcLog -Tail 10 -ErrorAction SilentlyContinue)) { $x = San ([string]$t); if ($x.Trim()) { L ('   rc| ' + $x) } }
} else { L '   [WARN] no previous robocopy log' }

# ------------------------------------------------ 2. retry with held session + pre-created dest
$aiDir = $null
foreach ($d in @(Get-ChildItem -Path 'E:\' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Illustrator' })) {
    if (Test-Path -LiteralPath (Join-Path $d.FullName 'Support Files\Contents\Windows\Illustrator.exe')) { $aiDir = $d.FullName; break }
}
if (-not $aiDir) { L '   [FAIL] no AI dir'; exit 2 }

$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
$dst = $fshare + '\' + (Split-Path $aiDir -Leaf)
try { New-Item -ItemType Directory -Path $dst -Force | Out-Null; L ('   destination pre-created: ' + (San $dst)) }
catch { L ('   [FAIL] cannot create destination: ' + (San $_.Exception.Message)); & net use $fshare /delete 2>&1 | Out-Null; exit 2 }

$rcLog2 = Join-Path $work 'robocopy2.log'
$doneMarker = Join-Path $work 'sync_done2.marker'
Remove-Item -LiteralPath $doneMarker -Force -ErrorAction SilentlyContinue
L '   running robocopy INLINE this time (waiting, up to ~7 min)...'
& robocopy $aiDir $dst /MIR /MT:16 /R:1 /W:1 /NP /NFL /NDL /LOG:$rcLog2
$rc = $LASTEXITCODE
L ('   robocopy exit code: ' + $rc + '  (0-7 = success)')
if (Test-Path -LiteralPath $rcLog2) {
    foreach ($t in @(Get-Content -LiteralPath $rcLog2 -Tail 8 -ErrorAction SilentlyContinue)) { $x = San ([string]$t); if ($x.Trim()) { L ('   rc2| ' + $x) } }
}
('SYNC2_DONE rc=' + $rc) | Out-File -FilePath $doneMarker -Encoding ascii

if ($rc -le 7) {
    # verify remote exe exists
    $exe = Join-Path $dst 'Support Files\Contents\Windows\Illustrator.exe'
    L ('   remote Illustrator.exe present: ' + (Test-Path -LiteralPath $exe))
}
& net use $fshare /delete 2>&1 | Out-Null
L '--- task t85 done ---'
exit 0
