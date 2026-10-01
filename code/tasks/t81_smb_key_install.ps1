# t81_smb_key_install.ps1 - round 111 task: authorize the laptop ssh key
# on the desktop (100.84.137.117) via SMB C$ with current credentials:
# connect admin share -> read sshd_config (which AuthorizedKeysFile) ->
# list real desktop users -> append pubkey to administrators_authorized_
# keys (+ user authorized_keys) -> fix ACLs with well-known SIDs ->
# retest ssh 3x. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t81: desktop key install via SMB C$ ---'

$desktop = '100.84.137.117'
$share = '\\' + $desktop + '\C$'
$opts = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')

# laptop pubkey
$sshDir = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.ssh'
$pubKey = $null
foreach ($k in @('id_ed25519.pub', 'id_rsa.pub')) {
    $p = Join-Path $sshDir $k
    if (Test-Path -LiteralPath $p) { $pubKey = ([string]([IO.File]::ReadAllText($p))).Trim(); break }
}
if (-not $pubKey) { L '   [FAIL] no laptop pubkey'; exit 2 }
L ('   laptop pubkey: ' + $pubKey.Substring(0, 30) + '...')

# 1. SMB C$ with current credentials
$netOut = (& net use $share /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) {
    L '   SMB C$ FAILED with current credentials (desktop account differs)'
    foreach ($ln in ($netOut -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('   net| ' + $x) } }
    L '   --- manual finish (run on the desktop, via RDP, ~30s) ---'
    L ('   powershell -NoProfile -Command "Add-Content $env:USERPROFILE\.ssh\authorized_keys -Value ''' + $pubKey + ''' -Encoding ascii; Add-Content C:\ProgramData\ssh\administrators_authorized_keys -Value ''' + $pubKey + ''' -Encoding ascii; icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r /grant *S-1-5-32-544:F /grant *S-1-5-18:F"'
    )
    exit 3
}
L '   SMB C$: CONNECTED with current credentials'

try {
    # 2. read sshd_config for AuthorizedKeysFile / Match blocks
    $sshdCfg = $share + '\ProgramData\ssh\sshd_config'
    if (Test-Path -LiteralPath $sshdCfg) {
        $cfgHits = @(Select-String -LiteralPath $sshdCfg -Pattern 'AuthorizedKeysFile|Match Group|PubkeyAuthentication|PasswordAuthentication' -ErrorAction SilentlyContinue | Select-Object -First 8)
        if (@($cfgHits).Count -eq 0) { L '   sshd_config: all defaults (user .ssh/authorized_keys; admins -> ProgramData file)' }
        foreach ($h in $cfgHits) { L ('   cfg| ' + (San ([string]$h.Line).Trim())) }
    } else { L '   [WARN] sshd_config not found at ProgramData\ssh' }

    # 3. real desktop users
    $usersDir = $share + '\Users'
    $dirs = @(Get-ChildItem -LiteralPath $usersDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '^(Public|Default|Default User|defaultuser0|All Users)$' } | Select-Object -First 5)
    foreach ($d in $dirs) { L ('   desktop user dir: ' + (San $d.Name)) }

    # 4. append pubkey: administrators_authorized_keys (covers admin accounts)
    $adminAk = $share + '\ProgramData\ssh\administrators_authorized_keys'
    $existing = ''
    if (Test-Path -LiteralPath $adminAk) { $existing = [string]([IO.File]::ReadAllText($adminAk)) }
    if ($existing -notmatch [regex]::Escape($pubKey)) { Add-Content -LiteralPath $adminAk -Value $pubKey -Encoding ascii }
    L '   admins key file updated'
    # ACL fix with well-known SIDs (Administrators/SYSTEM), inheritance off
    $aclOut = (& icacls $adminAk /inheritance:r /grant '*S-1-5-32-544:F' /grant '*S-1-5-18:F' 2>&1 | Out-String).Trim()
    foreach ($ln in ($aclOut -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('   icacls-admin| ' + $x) } }

    # 5. append pubkey: each real user's authorized_keys
    foreach ($d in $dirs) {
        $akDir = $usersDir + '\' + $d.Name + '\.ssh'
        $ak = $akDir + '\authorized_keys'
        try {
            if (-not (Test-Path -LiteralPath $akDir)) { New-Item -ItemType Directory -Path $akDir -Force | Out-Null }
            $ex = ''
            if (Test-Path -LiteralPath $ak) { $ex = [string]([IO.File]::ReadAllText($ak)) }
            if ($ex -notmatch [regex]::Escape($pubKey)) { Add-Content -LiteralPath $ak -Value $pubKey -Encoding ascii }
            L ('   user key file updated: \Users\' + (San $d.Name))
        } catch { L ('   [WARN] user ak (' + (San $d.Name) + '): ' + (San $_.Exception.Message)) }
    }
}
finally {
    & net use $share /delete 2>&1 | Out-Null
    L '   SMB share released'
}

# 6. retest ssh for all candidate users (3x for the best candidate)
$candidates = @()
$lu = [string]$env:USERNAME
if ($lu) { $candidates += $lu }
foreach ($d in $dirs) { $candidates += $d.Name }
$candidates += @('Administrator')
$candidates = @($candidates | Select-Object -Unique)
L ('   retesting ssh for: ' + (($candidates | ForEach-Object { San $_ }) -join ', '))

$workingUser = $null
foreach ($u in $candidates) {
    $o = (& ssh @opts ($u + '@' + $desktop) 'echo SSHTEST_OK' 2>&1 | Out-String).Trim()
    if ($o -match 'SSHTEST_OK') { $workingUser = $u; break }
}
if ($workingUser) {
    L ('   SSH NOW WORKS: ' + (San $workingUser) + '@' + $desktop)
    $okCount = 1
    for ($i = 2; $i -le 3; $i++) {
        Start-Sleep -Seconds 3
        $o = (& ssh @opts ($workingUser + '@' + $desktop) 'echo SSHTEST_OK' 2>&1 | Out-String).Trim()
        if ($o -match 'SSHTEST_OK') { $okCount++ }
    }
    L ('   stability: ' + $okCount + '/3')
    if ($okCount -ge 2) {
        $id = (& ssh @opts ($workingUser + '@' + $desktop) 'whoami & hostname' 2>&1 | Out-String).Trim()
        foreach ($ln in ($id -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('   id| ' + $x) } }
        L ('   >>> DESKTOP SSH READY: ssh ' + (San $workingUser) + '@' + $desktop)
    }
} else {
    L '   ssh STILL denied after key install - ACL or sshd_config nuance on the desktop'
    L '   --- manual finish (run on the desktop, ~30s) ---'
    L ('   icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r /grant *S-1-5-32-544:F /grant *S-1-5-18:F')
    L ('   (then from the laptop:  ssh <desktop-user>@' + $desktop + ')')
}
L '--- task t81 done ---'
exit 0
