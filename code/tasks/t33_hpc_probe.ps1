# t33_hpc_probe.ps1 - round 45 task: READ-ONLY probe for the HPC bridge plan.
#   1. finish the sshd verification from round 44
#   2. can we reach the HPC 10.10.5.210 right now (ping + ssh port)?
#   3. is the NSFOCUS VPN client installed? adapters? routes? running?
#   4. is a Tailscale exit node active (explains the odd public IP)?
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t33: HPC bridge probe (READ-ONLY) ---'

# ---------------------------------------------------------- 1. sshd
Write-Output '--- 1. OpenSSH server (round 44 follow-up) ---'
try {
    $sv = Get-Service sshd -ErrorAction Stop
    Write-Output ('   sshd: ' + $sv.Status + ' / ' + $sv.StartType)
    if ($sv.Status -eq 'Running') {
        $l = netstat -an | Select-String ':22\s'
        foreach ($x in @($l | Select-Object -First 3)) { Write-Output ('   listen: ' + (San ([string]$x).Trim())) }
        Write-Output '   -> laptop is now ssh-able over Tailscale: ssh <user>@100.71.123.19'
    }
} catch { Write-Output '   sshd: still not installed (Add-WindowsCapability must have failed - try again with a working FoD source)' }
try {
    $r = Get-NetFirewallRule -DisplayGroup 'OpenSSH Server' -ErrorAction Stop | Where-Object Enabled -eq 'True' | Select-Object -First 1
    if ($r) { Write-Output ('   firewall: OpenSSH Server rule ON (' + $r.DisplayName + ')') }
} catch { Write-Output '   firewall: no OpenSSH Server rule' }

# ------------------------------------------------- 2. HPC reachability
Write-Output '--- 2. HPC 10.10.5.210 reachability (no VPN change) ---'
$pong = $false
try { $pong = Test-Connection -ComputerName '10.10.5.210' -Count 2 -Quiet -ErrorAction SilentlyContinue } catch { }
Write-Output ('   ping 10.10.5.210: ' + $(if ($pong) { 'REPLY (already routable!)' } else { 'no reply (expected without the campus/VPN network)' }))
try {
    $t = New-Object System.Net.Sockets.TcpClient
    $ok = $t.ConnectAsync('10.10.5.210', 22).Wait(4000)
    Write-Output ('   tcp 10.10.5.210:22: ' + $(if ($ok -and $t.Connected) { 'OPEN - ssh 25wenshaohua@10.10.5.210 would work from here' } else { 'closed/timeout' }))
    $t.Close()
} catch { Write-Output '   tcp 10.10.5.210:22: timeout' }

# ------------------------------------------------------- 3. NSFOCUS VPN
Write-Output '--- 3. NSFOCUS / VPN client detection ---'
$found = @()
foreach ($up in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
    foreach ($it in @(Get-ItemProperty -Path $up -ErrorAction SilentlyContinue)) {
        $dn = [string]$it.DisplayName
        if ($dn -match 'nsfocus|leaguer|VPN|SecSpace|EasyConnect|aTrust|Sangfor|SecEdge') {
            $found += ('   INSTALLED: ' + (San $dn) + ' ' + (San ([string]$it.DisplayVersion)) + '  @ ' + (San ([string]$it.InstallLocation)))
        }
    }
}
if ($found.Count -eq 0) { Write-Output '   no VPN client found in installed programs' }
foreach ($f in ($found | Select-Object -First 6)) { Write-Output $f }
try {
    foreach ($a in @(Get-NetAdapter -ErrorAction Stop | Where-Object { $_.InterfaceDescription -match 'VPN|TAP|TUN|WAN Minport|NSFOCUS|Leaguer|Sangfor' })) {
        Write-Output ('   adapter: ' + (San ([string]$a.InterfaceDescription)).PadRight(40) + ' status=' + $a.Status + '  name=' + (San ([string]$a.Name)))
    }
} catch { }
try {
    $rt = route print -4 | Select-String '^\s*10\.10\.'
    if ($rt) { foreach ($x in @($rt | Select-Object -First 6)) { Write-Output ('   route: ' + (San ([string]$x).Trim())) } }
    else { Write-Output '   route table: no 10.10.x entries (VPN not connected)' }
} catch { }
try {
    foreach ($p in @(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -match 'nsfocus|leaguer|vpn|easyconnect|atrust|SecSpace' } | Select-Object -First 5)) {
        Write-Output ('   process: ' + (San ([string]$p.ProcessName)) + ' (pid ' + $p.Id + ')')
    }
} catch { }

# ------------------------------------------------- 4. tailscale extras
Write-Output '--- 4. tailscale exit node / route readiness ---'
$tsExe = 'E:\Tailscale\tailscale.exe'
if (Test-Path -LiteralPath $tsExe) {
    try {
        $pref = (& $tsExe debug prefs 2>$null | Out-String)
        foreach ($ln in @($pref -split "`r?`n")) {
            if ($ln -match 'ExitNode|AdvertiseRoutes|RouteAll') { Write-Output ('   ' + (San ($ln.Trim()))) }
        }
    } catch { }
    try {
        Write-Output '   (plan: once 10.10.5.210 is reachable from this laptop, run on it:)'
        Write-Output '     tailscale up --advertise-routes=10.10.5.0/24   <- then approve at login.tailscale.com'
        Write-Output '   (the home desktop then reaches the HPC through this laptop over Tailscale)'
    } catch { }
}
exit 0
