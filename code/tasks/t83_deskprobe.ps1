# t83_deskprobe.ps1 - round 113 task: READ-ONLY probe before syncing
# Illustrator 2020 to the desktop F: drive:
#  1. laptop AI 2020 folder: exact path, size, file count
#  2. desktop (BNI@100.84.137.117): F: exists? free space? admin share F$
#     reachable from the laptop? user logged in interactively?
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t83: pre-sync probe (laptop AI 2020 -> desktop F:) ---'

$desktop = '100.84.137.117'
$duser = 'BNI'
$opts = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')

# ------------------------------------------------ 1. laptop AI folder
Write-Output '--- 1. laptop Illustrator 2020 folder ---'
$aiDir = $null
foreach ($d in @(Get-ChildItem -Path 'E:\' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Illustrator' })) {
    $cand = Join-Path $d.FullName 'Support Files\Contents\Windows\Illustrator.exe'
    if (Test-Path -LiteralPath $cand) { $aiDir = $d.FullName; L ('   AI dir : ' + (San $aiDir)); L ('   AI exe : ' + (San $cand)); break }
}
if (-not $aiDir) { L '   [FAIL] no Illustrator dir on E:\ (laptop)'; exit 2 }
$measure = Get-ChildItem -LiteralPath $aiDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
L ('   files  : ' + $measure.Count)
L ('   size GB: ' + [math]::Round($measure.Sum / 1GB, 2))

# ------------------------------------------------ 2. desktop state via ssh
Write-Output '--- 2. desktop state (via ssh) ---'
$probeCmd = 'powershell -NoProfile -Command "Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Name + ''='' + [math]::Round($_.Free/1GB,1) + ''GB free'' }"'
$o = (& ssh @opts ($duser + '@' + $desktop) $probeCmd 2>&1 | Out-String).Trim()
foreach ($ln in ($o -split "`r?`n")) { $x = San $ln; if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualified|~~|\+ ') { L ('   drive| ' + $x) } }

$o = (& ssh @opts ($duser + '@' + $desktop) 'quser' 2>&1 | Out-String).Trim()
foreach ($ln in ($o -split "`r?`n")) { $x = San $ln; if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualified|~~|\+ ') { L ('   quser| ' + $x) } }

# ------------------------------------------------ 3. F$ admin share from laptop
Write-Output '--- 3. desktop F$ admin share (from laptop) ---'
$fshare = '\\' + $desktop + '\F$'
$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -eq 0) {
    L '   F$ share: CONNECTED'
    $dirs = @(Get-ChildItem -LiteralPath $fshare -Directory -ErrorAction SilentlyContinue | Select-Object -First 8)
    if (@($dirs).Count -eq 0) { L '   F:\ appears empty (or no top-level dirs)' }
    foreach ($d in $dirs) { L ('   F:\ -> ' + (San $d.Name)) }
    $free = (Get-PSDrive -Name ($fshare.Substring(0, 1)) -ErrorAction SilentlyContinue)
    & net use $fshare /delete 2>&1 | Out-Null
    L '   F$ released'
} else {
    L '   F$ share: FAILED with current credentials'
    foreach ($ln in ($netOut -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('   net| ' + $x) } }
    L '   (will fall back to C$ + ssh-tar transport)'
}

L '--- task t83 done (read-only probe) ---'
exit 0
