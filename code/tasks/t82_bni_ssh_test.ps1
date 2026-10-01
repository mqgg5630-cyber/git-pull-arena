# t82_bni_ssh_test.ps1 - round 112 task: test ssh to the desktop as the
# REAL desktop user BNI (key was installed in r111 via SMB): 3 spaced
# probes + identity + toolchain (git/python). ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t82: desktop ssh as BNI (real desktop user) ---'

$desktop = '100.84.137.117'
$user = 'BNI'
$opts = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')

$okCount = 0
for ($i = 1; $i -le 3; $i++) {
    if ($i -gt 1) { Start-Sleep -Seconds 5 }
    $o = (& ssh @opts ($user + '@' + $desktop) ('echo BNI_SSH_OK_' + $i) 2>&1 | Out-String).Trim()
    $good = ($o -match ('BNI_SSH_OK_' + $i))
    if ($good) { $okCount++ }
    L ('   probe ' + $i + ': ' + $(if ($good) { 'OK' } else { 'FAIL' }))
    if (-not $good) { foreach ($ln in ($o -split "`r?`n")) { $x = San $ln; if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|At line') { L ('     err| ' + $x) } } }
}
L ('   stability: ' + $okCount + '/3')

if ($okCount -lt 2) {
    L '   BNI auth not working yet - dumping ssh -v (first 25 lines) for diagnosis'
    $v = (& ssh -v @opts ($user + '@' + $desktop) 'echo X' 2>&1 | Out-String).Trim()
    $lines = @($v -split "`r?`n" | Where-Object { $_ -match 'auth|publickey|denied|Offering|Server accepts|identity' } | Select-Object -First 12)
    foreach ($ln in $lines) { $x = San $ln; if ($x.Trim()) { L ('   v| ' + $x) } }
    exit 0
}

# identity + toolchain
foreach ($e in @(
    @{ tag = 'id';  c = 'whoami & hostname' },
    @{ tag = 'os';  c = 'ver' },
    @{ tag = 'git'; c = 'git --version' },
    @{ tag = 'py';  c = 'python --version' },
    @{ tag = 'py3'; c = 'py -3 --version' }
)) {
    $o = (& ssh @opts ($user + '@' + $desktop) $e.c 2>&1 | Out-String).Trim()
    foreach ($ln in ($o -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('   ' + $e.tag + '| ' + $x) } }
}
L ('   >>> DESKTOP SSH STABLE: ssh ' + $user + '@' + $desktop)
L '--- task t82 done ---'
exit 0
