# t86_deskinstall.ps1 - round 116 task: run install_desktop.ps1 ON THE
# DESKTOP via ssh: unzip both skills, ensure Python 3.12 + fontTools/
# shapely, patch exe search to F:\, register the interactive scheduled
# task 'fig1desk'. Report the full install output. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t86: desktop install (via ssh) ---'

$desktop = '100.84.137.117'
$duser = 'BNI'
$opts = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')

$remote = 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\stage\install_desktop.ps1'
$o = (& ssh @opts ($duser + '@' + $desktop) $remote 2>&1 | Out-String).Trim()
foreach ($ln in ($o -split "`r?`n")) { $x = San $ln; if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ ') { L ('   ' + $x) } }

# verification probes
foreach ($probe in @(
    @{ t = 'py';   c = 'py -3 --version' },
    @{ t = 'deps'; c = 'py -3 -c "import fontTools,shapely;print(''DEPS_OK'')"' },
    @{ t = 'task'; c = 'schtasks /query /tn fig1desk /fo list' },
    @{ t = 'skills'; c = 'dir /b C:\Users\BNI\.codex\skills' }
)) {
    $o = (& ssh @opts ($duser + '@' + $desktop) $probe.c 2>&1 | Out-String).Trim()
    foreach ($ln in ($o -split "`r?`n")) { $x = San $ln; if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ ') { L ('   ' + $probe.t + '| ' + $x) } }
}
L '--- task t86 done ---'
exit 0
