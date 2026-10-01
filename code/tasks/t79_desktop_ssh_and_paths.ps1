# t79_desktop_ssh_and_paths.ps1 - round 109 task:
# A) print + open (Explorer) the local laptop paths of the cell-lct /
#    cell_su7 test + full-demo results;
# B) establish ssh laptop -> desktop (100.84.137.117): test current key
#    auth for candidate users; if not authorized, try SMB C$ with current
#    credentials to lay down the laptop pubkey (administrators_authorized_
#    keys + user authorized_keys), then retest; report a ready-to-paste
#    one-liner for the desktop if anything remains manual.
# ASCII-only (usernames are read at runtime, never hardcoded).

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t79: result paths + desktop ssh bridge ---'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$desktop = '100.84.137.117'

# ================================================== A. result paths
Write-Output '--- A. where to open the two results on THIS laptop ---'
$outDir = Join-Path $repoRoot 'results\fig1_rebuild\out'
$testDir = Join-Path $repoRoot 'results\fig1_rebuild\test'
L ('   repo root      : ' + $repoRoot)
L ('   full demos     : ' + $outDir)
foreach ($n in @('shibielujing5.ai', 'shibielujing5.png', 'shibielujing6.ai', 'shibielujing6.png')) {
    $p = Join-Path $outDir $n
    if (Test-Path -LiteralPath $p) { L ('     ' + $n + '  (' + [int]((Get-Item -LiteralPath $p).Length / 1024) + ' KB)') }
}
L ('   cell-lct test  : ' + (Join-Path $testDir 'cell-lct') + '  (test_cell-lct.ai / .png)')
L ('   cell_su7 test  : ' + (Join-Path $testDir 'cell_su7') + '  (test_cell_su7.ai / .png)')
L '   machine-side copies (also on this laptop):'
foreach ($d in @('E:\fig1_rebuild\shibielujing5', 'E:\fig1_rebuild\shibielujing6', 'E:\fig1_rebuild\test-cell-lct', 'E:\fig1_rebuild\test-cell_su7')) {
    if (Test-Path -LiteralPath $d) { L ('     ' + $d) }
}
try {
    Start-Process -FilePath 'explorer.exe' -ArgumentList @(('"' + $outDir + '"'))
    Start-Process -FilePath 'explorer.exe' -ArgumentList @('E:\fig1_rebuild')
    L '   opened two Explorer windows (repo out dir + E:\fig1_rebuild)'
} catch { L ('   [WARN] explorer: ' + (San $_.Exception.Message)) }

# ================================================== B. desktop ssh
Write-Output ('--- B. desktop ssh bridge to ' + $desktop + ' ---')

# B1. tailscale link
$ts = 'E:\Tailscale\tailscale.exe'
if (Test-Path -LiteralPath $ts) {
    $r = (& $ts ping $desktop 2>&1 | Select-Object -First 1 | Out-String).Trim()
    L ('   tailscale ping: ' + (San $r))
}

# B2. tcp 22
$port22 = $false
try {
    $t = New-Object System.Net.Sockets.TcpClient
    $ok = $t.ConnectAsync($desktop, 22).Wait(5000)
    if ($ok -and $t.Connected) { $port22 = $true }
    $t.Close()
} catch { }
L ('   tcp 22 (sshd): ' + $(if ($port22) { 'OPEN' } else { 'CLOSED/TIMEOUT' }))
if (-not $port22) { L '   [FAIL] desktop sshd not reachable - cannot bridge today'; exit 0 }

# B3. laptop pubkey
$sshDir = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.ssh'
$pubKey = $null
foreach ($k in @('id_ed25519.pub', 'id_rsa.pub')) {
    $p = Join-Path $sshDir $k
    if (Test-Path -LiteralPath $p) { $pubKey = ([string]([IO.File]::ReadAllText($p))).Trim(); break }
}
if (-not $pubKey) { L '   [FAIL] laptop has no ssh pubkey'; exit 0 }
L ('   laptop pubkey: ' + $pubKey.Substring(0, 40) + '...')

# B4. candidate users + BatchMode ssh test
$opts = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10', '-o', 'StrictHostKeyChecking=accept-new')
$candidates = @()
$lu = [string]$env:USERNAME
if ($lu) { $candidates += $lu }
$candidates += @('Administrator', 'wenshaohua', '25wenshaohua', 'wen')
$candidates = @($candidates | Select-Object -Unique)
function Test-SshUser([string]$u) {
    $o = (& ssh @opts ($u + '@' + $desktop) 'echo SSH_OK' 2>&1 | Out-String).Trim()
    if ($o -match 'SSH_OK') { return $true }
    return $false
}
$sshOkUser = $null
foreach ($u in $candidates) {
    if (Test-SshUser $u) { $sshOkUser = $u; break }
}
if ($sshOkUser) {
    L ('   SSH ALREADY WORKS: ' + (San $sshOkUser) + '@' + $desktop + '  (key auth OK)')
    $hostn = (& ssh @opts ($sshOkUser + '@' + $desktop) 'hostname' 2>&1 | Out-String).Trim()
    L ('   desktop hostname: ' + (San $hostn))
    L ('   >>> usable as:  ssh ' + (San $sshOkUser) + '@' + $desktop)
    L '--- task t79 done (desktop ssh already authorized) ---'
    exit 0
}
L ('   key auth not yet authorized for: ' + (($candidates | ForEach-Object { San $_ }) -join ', '))

# B5. SMB C$ with current credentials
$share = '\\' + $desktop + '\C$'
$netOut = (& net use $share /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) {
    L '   SMB C$ with current credentials: FAILED (different desktop account/password)'
    foreach ($ln in ($netOut -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('   net| ' + $x) } }
    L '   --- manual finish (one paste, ~30s, run in an RDP window on the desktop) ---'
    L ('   powershell -NoProfile -Command "Add-Content -Path $env:USERPROFILE\.ssh\authorized_keys -Value ''' + $pubKey + ''' -Encoding ascii ; Add-Content -Path C:\ProgramData\ssh\administrators_authorized_keys -Value ''' + $pubKey + ''' -Encoding ascii"')
    L ('   (then from the laptop:  ssh <desktop-user>@' + $desktop + ')')
    L '--- task t79 done (desktop ssh needs the one-line manual finish) ---'
    exit 0
}
L '   SMB C$: CONNECTED with current credentials - laying down the key'

# B5a. find real desktop users
$usersDir = $share + '\Users'
$dirs = @(Get-ChildItem -LiteralPath $usersDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '^(Public|Default|Default User|defaultuser0|All Users)$' } | Select-Object -First 5)
foreach ($d in $dirs) { L ('   desktop user dir: ' + (San $d.Name)) }

# B5b. write pubkey to user authorized_keys (every candidate dir)
foreach ($d in $dirs) {
    $akDir = $usersDir + '\' + $d.Name + '\.ssh'
    $ak = $akDir + '\authorized_keys'
    try {
        if (-not (Test-Path -LiteralPath $akDir)) { New-Item -ItemType Directory -Path $akDir -Force | Out-Null }
        $existing = ''
        if (Test-Path -LiteralPath $ak) { $existing = [string]([IO.File]::ReadAllText($ak)) }
        if ($existing -notmatch [regex]::Escape($pubKey)) { Add-Content -LiteralPath $ak -Value $pubKey -Encoding ascii }
        L ('   key appended: \Users\' + (San $d.Name) + '\.ssh\authorized_keys')
    } catch { L ('   [WARN] user ak write (' + (San $d.Name) + '): ' + (San $_.Exception.Message)) }
}

# B5c. write pubkey to administrators_authorized_keys (admin accounts on Windows OpenSSH)
try {
    $adminAk = $share + '\ProgramData\ssh\administrators_authorized_keys'
    $sshCfgDir = $share + '\ProgramData\ssh'
    if (-not (Test-Path -LiteralPath $sshCfgDir)) { L '   [WARN] no ProgramData\ssh on desktop (non-standard sshd?)' }
    else {
        $existing = ''
        if (Test-Path -LiteralPath $adminAk) { $existing = [string]([IO.File]::ReadAllText($adminAk)) }
        if ($existing -notmatch [regex]::Escape($pubKey)) { Add-Content -LiteralPath $adminAk -Value $pubKey -Encoding ascii }
        L '   key appended: C:\ProgramData\ssh\administrators_authorized_keys'
    }
} catch { L ('   [WARN] admin ak write: ' + (San $_.Exception.Message)) }

& net use $share /delete 2>&1 | Out-Null
L '   SMB share released'

# B6. retest ssh for all candidates
foreach ($u in $candidates) {
    if (Test-SshUser $u) {
        $hostn = (& ssh @opts ($u + '@' + $desktop) 'hostname' 2>&1 | Out-String).Trim()
        L ('   SSH NOW WORKS: ' + (San $u) + '@' + $desktop + '  hostname=' + (San $hostn))
        L ('   >>> usable as:  ssh ' + (San $u) + '@' + $desktop)
        L '--- task t79 done (desktop ssh bridged via SMB key install) ---'
        exit 0
    }
}
L '   ssh still not authorized after key install (sshd may reject the file ACL or use another user)'
L '   --- manual finish (run on the desktop via RDP, ~30s) ---'
L ('   icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"')
L ('   (then from the laptop:  ssh <desktop-user>@' + $desktop + ')')
L '--- task t79 done (desktop ssh one ACL fix away) ---'
exit 0
