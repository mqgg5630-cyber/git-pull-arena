# t86_deskinstall.ps1 - round 116 task (v2): run install_desktop.ps1 ON
# THE DESKTOP as a DETACHED process via ssh (no long-lived ssh call that
# could hang the whole check), then poll its output file with short ssh
# calls until the completion sentinel appears (max 15 min). Then verify
# py/deps/task/skills with short probes. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t86 v2: desktop install (detached + short polls) ---'

$desktop = '100.84.137.117'
$duser = 'BNI'
$opts = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')

# ------------------------------------------------ 1. launch install detached
$launch = 'powershell -NoProfile -Command "Start-Process -FilePath powershell.exe -ArgumentList ''-NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\stage\install_desktop.ps1'' -WindowStyle Hidden -RedirectStandardOutput F:\fig1_rebuild\install_out.txt -RedirectStandardError F:\fig1_rebuild\install_err.txt"'
$o = (& ssh @opts ($duser + '@' + $desktop) $launch 2>&1 | Out-String).Trim()
if ($o) { foreach ($ln in ($o -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('   launch| ' + $x) } } }
L '   install launched detached on the desktop'

# ------------------------------------------------ 2. poll for completion sentinel
$sentinel = 'desktop install v2 done'
$found = $false
$deadline = [DateTime]::UtcNow.AddMinutes(15)
while ([DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Seconds 20
    $o = (& ssh @opts ($duser + '@' $desktop) 'type F:\fig1_rebuild\install_out.txt 2>nul' 2>&1 | Out-String).Trim()
    if ($o -match [regex]::Escape($sentinel)) { $found = $true; break }
    if ($o -match 'FATAL|FAIL') { L '   failure detected in install log:'; break }
}
if ($found) { L '   install finished (sentinel seen)' } else { L '   [WARN] install sentinel not seen within 15 min (dumping partial log)' }

# ------------------------------------------------ 3. dump install output
$o = (& ssh @opts ($duser + '@' $desktop) 'type F:\fig1_rebuild\install_out.txt 2>nul' 2>&1 | Out-String).Trim()
foreach ($ln in ($o -split "`r?`n")) { $x = San $ln; if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ ') { L ('   ' + $x) } }
$e = (& ssh @opts ($duser + '@' $desktop) 'type F:\fig1_rebuild\install_err.txt 2>nul' 2>&1 | Out-String).Trim()
if ($e) { foreach ($ln in ($e -split "`r?`n")) { $x = San $ln; if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ ') { L ('   err| ' + $x) } } }

# ------------------------------------------------ 4. verification probes (short)
foreach ($probe in @(
    @{ t = 'py';    c = 'py -3 --version' },
    @{ t = 'deps';  c = 'py -3 -c "import fontTools,shapely;print(''DEPS_OK'')"' },
    @{ t = 'task';  c = 'schtasks /query /tn fig1desk /fo list' },
    @{ t = 'skills'; c = 'dir /b C:\Users\BNI\.codex\skills' },
    @{ t = 'aiexe'; c = 'dir /b /s F:\Adobe*Illustrator*\Illustrator.exe 2>nul' }
)) {
    $o = (& ssh @opts ($duser + '@' $desktop) $probe.c 2>&1 | Out-String).Trim()
    foreach ($ln in ($o -split "`r?`n")) { $x = San $ln; if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ ') { L ('   ' + $probe.t + '| ' + $x) } }
}
L '--- task t86 v2 done ---'
exit 0
