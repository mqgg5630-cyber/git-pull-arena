# t74_hpc_watch.ps1 - round 99 task: ssh into the HPC (10.10.5.210) from
# the laptop and run the requested watch.sh sequence in 0amp-src:
#   status -> focus -> register -> status
# Non-interactive only (BatchMode): if key auth is missing, generate a key
# (if none) and print the pubkey for the user to authorize on the HPC side.
# ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t74: HPC ssh + watch.sh status/focus/register/status ---'

$hpc = '25wenshaohua@10.10.5.210'
$workdir = '/mnt/hpc/home/25menglei/25wenshaohua/0amp-src'

# ---------------------------------------------------------- 1. reachability
try {
    $t = New-Object System.Net.Sockets.TcpClient
    $ok = $t.ConnectAsync('10.10.5.210', 22).Wait(5000)
    if ($ok -and $t.Connected) { L '   tcp 10.10.5.210:22: OPEN' } else { L '   [FAIL] tcp 10.10.5.210:22: unreachable (VPN/campus network down?)'; $t.Close(); exit 2 }
    $t.Close()
} catch { L ('   [FAIL] reachability: ' + (San $_.Exception.Message)); exit 2 }

# ---------------------------------------------------------- 2. ssh client + key
$sshExe = (Get-Command ssh -ErrorAction SilentlyContinue).Source
if (-not $sshExe) { L '   [FAIL] no ssh client on the laptop'; exit 2 }
L ('   ssh client: ' + $sshExe)

$sshDir = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.ssh'
$pubKey = $null
foreach ($k in @('id_ed25519.pub', 'id_rsa.pub')) {
    $p = Join-Path $sshDir $k
    if (Test-Path -LiteralPath $p) { $pubKey = $p; break }
}
if (-not $pubKey) {
    L '   no ssh key on the laptop - generating ed25519 (no passphrase) ...'
    $keyPath = Join-Path $sshDir 'id_ed25519'
    & ssh-keygen -t ed25519 -N '""' -f $keyPath -C 'laptop-git-sync' 2>&1 | ForEach-Object { L ('   keygen| ' + (San ([string]$_))) }
    if (Test-Path -LiteralPath ($keyPath + '.pub')) { $pubKey = $keyPath + '.pub' }
}
if ($pubKey) { L ('   pubkey: ' + $pubKey) } else { L '   [WARN] no pubkey available' }

# ---------------------------------------------------------- 3. BatchMode ssh test
$opts = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$probe = (& ssh @opts $hpc 'echo SSH_OK; hostname' 2>&1 | Out-String).Trim()
if ($probe -notmatch 'SSH_OK') {
    L '   [AUTH-NEEDED] key auth not set up on the HPC. ssh said:'
    foreach ($ln in ($probe -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('   ssh| ' + $x) } }
    if ($pubKey) {
        L '   --- laptop public key (add ONE line on the HPC) ---'
        $pk = [string]([IO.File]::ReadAllText($pubKey)).Trim()
        L ('   ' + $pk)
        L ('   on the HPC run:  mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo "' + $pk + '" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys')
        L '   (use your own HPC password for that one step, then this task can run hands-free)'
    }
    exit 3
}
foreach ($ln in ($probe -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('   ssh| ' + $x) } }

# ---------------------------------------------------------- 4. run the sequence
$cmds = @(
    @{ tag = 'status-1';  arg = '--status' },
    @{ tag = 'focus';     arg = '--focus' },
    @{ tag = 'register';  arg = '--register' },
    @{ tag = 'status-2';  arg = '--status' }
)
$rcOverall = 0
foreach ($c in $cmds) {
    L ('   --- watch.sh ' + $c.tag + ' (' + $c.arg + ') ---')
    $remote = 'cd ' + $workdir + ' && bash skills/git-sync/scripts/local/watch.sh ' + $c.arg
    $out = (& ssh @opts $hpc $remote 2>&1 | Out-String).Trim()
    $code = $LASTEXITCODE
    foreach ($ln in ($out -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('   ' + $c.tag + '| ' + $x) } }
    L ('   ' + $c.tag + ' exit code: ' + $code)
    if ($code -ne 0) { $rcOverall = $code }
}

# ---------------------------------------------------------- 5. confirm job state on the HPC clone
$listing = (& ssh @opts $hpc ('cd ' + $workdir + ' && ls -la skills/git-sync/scripts/local/ && git log --oneline -1 2>/dev/null') 2>&1 | Out-String).Trim()
foreach ($ln in ($listing -split "`r?`n")) { $x = San $ln; if ($x.Trim()) { L ('   ls| ' + $x) } }

L ('--- task t74 done (overall rc=' + $rcOverall + ') ---')
exit 0
