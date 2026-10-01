# t80_desktop_ssh_stability.ps1 - round 110 task: verify ssh to the
# desktop (100.84.137.117, user = laptop username) is STABLE after the
# flaky success-then-deny in r109: three spaced ssh probes + identity and
# toolchain inventory (whoami/hostname/ver/git/python). READ-ONLY.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t80: desktop ssh stability retest ---'

$desktop = '100.84.137.117'
$user = [string]$env:USERNAME
$opts = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')

# 1. tailscale link health
$ts = 'E:\Tailscale\tailscale.exe'
if (Test-Path -LiteralPath $ts) {
    $r = (& $ts ping $desktop 2>&1 | Select-Object -First 2 | Out-String).Trim()
    foreach ($ln in ($r -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('   ts| ' + $x) } }
}

# 2. three spaced ssh probes
$okCount = 0
for ($i = 1; $i -le 3; $i++) {
    $o = (& ssh @opts ($user + '@' + $desktop) ('echo SSHTEST' + $i + '_OK') 2>&1 | Out-String).Trim()
    $good = ($o -match ('SSHTEST' + $i + '_OK'))
    if ($good) { $okCount++ }
    L ('   probe ' + $i + ': ' + $(if ($good) { 'OK' } else { 'FAIL' }))
    if (-not $good) { foreach ($ln in ($o -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('     err| ' + $x) } } }
    Start-Sleep -Seconds 3
}
L ('   stability: ' + $okCount + '/3 OK')

if ($okCount -eq 0) {
    L '   ssh NOT working now (r109 success was transient or key/ACL issue)'
    L '   --- finish manually on the desktop (RDP, ~30s) ---'
    $sshDir = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.ssh'
    $pubKey = ''
    foreach ($k in @('id_ed25519.pub', 'id_rsa.pub')) { $p = Join-Path $sshDir $k; if (Test-Path -LiteralPath $p) { $pubKey = ([string]([IO.File]::ReadAllText($p))).Trim(); break } }
    if ($pubKey) {
        L ('   powershell -NoProfile -Command "Add-Content $env:USERPROFILE\.ssh\authorized_keys -Value ''' + $pubKey + ''' -Encoding ascii; Add-Content C:\ProgramData\ssh\administrators_authorized_keys -Value ''' + $pubKey + ''' -Encoding ascii; icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r /grant Administrators:F /grant SYSTEM:F"'
        )
    }
    exit 0
}

# 3. identity + toolchain (only if ssh alive)
$cmds = @(
    @{ tag = 'identity'; c = 'whoami & hostname' },
    @{ tag = 'osver';    c = 'ver' },
    @{ tag = 'git';      c = 'git --version' },
    @{ tag = 'python';   c = 'python --version' }
)
foreach ($e in $cmds) {
    $o = (& ssh @opts ($user + '@' + $desktop) $e.c 2>&1 | Out-String).Trim()
    foreach ($ln in ($o -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('   ' + $e.tag + '| ' + $x) } }
}

# 4. verdict
if ($okCount -ge 2) {
    L ('   >>> DESKTOP SSH STABLE: ssh ' + (San $user) + '@' + $desktop + '  (usable for hands-free work)')
} else {
    L ('   >>> desktop ssh FLAKY (' + $okCount + '/3) - works sometimes; retest next round before relying on it')
}
L '--- task t80 done ---'
exit 0
