# t109_cancel_desktop_status.ps1 - round 145 REPLACEMENT task: the user
# cancelled ALL laptop-side testing (user request 2026-10-01). The original
# t109 laptop impress retry must NOT run. This replacement does exactly one
# read-only thing: report the desktop's background WPS download progress.
# No laptop-local probes, no WPS automation anywhere. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t109 (replacement): laptop testing CANCELLED - desktop download status only ---'

$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')

$dl = & ssh @sshBase ($duser + '@' $desktop) 'type F:\fig1_rebuild\wps_download.log 2>nul' 2>&1
foreach ($ln in @($dl | Select-Object -Last 5)) { if ($ln) { L ('   wpsdl: ' + (San ([string]$ln))) } }
$st = & ssh @sshBase ($duser + '@' $desktop) 'dir F:\fig1_rebuild\wps_setup.* 2>nul | findstr wps_setup' 2>&1
foreach ($ln in @($st)) { if ($ln) { L ('   files: ' + (San ([string]$ln))) } }
$tk = & ssh @sshBase ($duser + '@' $desktop) 'schtasks /query /tn wpsdl /fo list 2>nul | findstr /i "status"' 2>&1
foreach ($ln in @($tk)) { if ($ln) { L ('   task:  ' + (San ([string]$ln))) } }
L '--- task t109 replacement done (no laptop testing, per user) ---'
exit 0
