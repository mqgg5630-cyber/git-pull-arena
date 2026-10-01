# t84_deskstage_sync.ps1 - round 114 task: stage everything the desktop
# needs onto F$ (skill zips, desktop worker + installer, fig1/test inputs)
# and START the detached robocopy of Illustrator 2020 (1.92 GB) from the
# laptop E:\ to the desktop F:\. Log + DONE marker under
# E:\fig1_rebuild\desk\. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t84: stage desktop kit + start AI 2020 robocopy ---'

$desktop = '100.84.137.117'
$fshare = '\\' + $desktop + '\F$'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$work = 'E:\fig1_rebuild\desk'
New-Item -ItemType Directory -Force -Path $work | Out-Null

# ------------------------------------------------ 0. connect F$
$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; foreach ($ln in ($netOut -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('   net| ' + $x) } }; exit 2 }
L '   F$ connected'

# free space on F:
try {
    & net use X: $fshare /persistent:no 2>&1 | Out-Null
    $free = (Get-PSDrive -Name X -ErrorAction Stop).Free
    L ('   F: free space: ' + [math]::Round($free / 1GB, 1) + ' GB')
    & net use X: /delete 2>&1 | Out-Null
    if ($free -lt 5GB) { L '   [FAIL] not enough free space on F:'; & net use $fshare /delete 2>&1 | Out-Null; exit 2 }
} catch { L ('   [WARN] free-space probe failed: ' + (San $_.Exception.Message)) }

# ------------------------------------------------ 1. skill zips
$home_ = [Environment]::GetFolderPath('UserProfile')
foreach ($pair in @(@('cell-lct', 'cell-lct.zip'), @('cell_su7', 'cell_su7.zip'))) {
    $src = Join-Path $home_ ('.codex\skills\' + $pair[0])
    $zip = Join-Path $work $pair[1]
    if (-not (Test-Path -LiteralPath (Join-Path $src 'scripts\run_cell_lct.ps1'))) { L ('   [FAIL] skill dir incomplete: ' + $pair[0]); exit 2 }
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    Compress-Archive -Path (Join-Path $src '*') -DestinationPath $zip -Force
    L ('   zipped: ' + $pair[0] + ' -> ' + [int]((Get-Item -LiteralPath $zip).Length / 1KB) + ' KB')
}

# ------------------------------------------------ 2. stage to F:\fig1_rebuild
$stage = $fshare + '\fig1_rebuild'
$stageIn = Join-Path $stage 'stage'
New-Item -ItemType Directory -Force -Path $stageIn | Out-Null
foreach ($z in @('cell-lct.zip', 'cell_su7.zip')) { Copy-Item -LiteralPath (Join-Path $work $z) -Destination (Join-Path $stageIn $z) -Force }
Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\desktop_worker.ps1') -Destination (Join-Path $stage 'desktop_worker.ps1') -Force
Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\install_desktop.ps1') -Destination (Join-Path $stageIn 'install_desktop.ps1') -Force
Copy-Item -LiteralPath (Join-Path $repoRoot 'results\fig1_rebuild\fig1_merged.svg') -Destination (Join-Path $stage 'fig1_merged.svg') -Force
Copy-Item -LiteralPath (Join-Path $repoRoot 'results\reference\fig1_text_manifest.json') -Destination (Join-Path $stage 'fig1_text_manifest.json') -Force
Copy-Item -LiteralPath (Join-Path $repoRoot 'results\fig1_rebuild\test_fixture.svg') -Destination (Join-Path $stage 'test_fixture.svg') -Force
L '   staged: zips + worker + installer + inputs -> F:\fig1_rebuild'

# ------------------------------------------------ 3. detached robocopy of AI 2020
$aiDir = $null
foreach ($d in @(Get-ChildItem -Path 'E:\' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Illustrator' })) {
    if (Test-Path -LiteralPath (Join-Path $d.FullName 'Support Files\Contents\Windows\Illustrator.exe')) { $aiDir = $d.FullName; break }
}
if (-not $aiDir) { L '   [FAIL] no AI dir on laptop E:\'; exit 2 }
$dst = $fshare + '\' + (Split-Path $aiDir -Leaf)
L ('   robocopy source: ' + (San $aiDir))
L ('   robocopy dest  : ' + (San $dst))

$rcLog = Join-Path $work 'robocopy.log'
$doneMarker = Join-Path $work 'sync_done.marker'
Remove-Item -LiteralPath $doneMarker -Force -ErrorAction SilentlyContinue
$inner = "robocopy `"$aiDir`" `"$dst`" /MIR /MT:16 /R:1 /W:1 /NP /NFL /NDL /LOG:`"$rcLog`"; `$rc = `$LASTEXITCODE; ('SYNC_DONE rc=' + `$rc) | Out-File '$doneMarker' -Encoding ascii"
Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $inner) -WindowStyle Hidden
L '   robocopy launched detached (1.92 GB, /MIR /MT:16)'

& net use $fshare /delete 2>&1 | Out-Null
L '   F$ released (robocopy keeps its own handle)'

# ------------------------------------------------ 4. peek
Start-Sleep -Seconds 50
if (Test-Path -LiteralPath $doneMarker) { L ('   sync finished already: ' + (San ([string]([IO.File]::ReadAllText($doneMarker))))) }
elseif (Test-Path -LiteralPath $rcLog) {
    $lines = @(Get-Content -LiteralPath $rcLog -Tail 4 -ErrorAction SilentlyContinue)
    foreach ($t in $lines) { $x = San ([string]$t); if ($x.Trim()) { L ('   rc| ' + $x) } }
    L '   (still copying - poll next round)'
}
else { L '   robocopy log not created yet' }
L '--- task t84 ok ---'
exit 0
