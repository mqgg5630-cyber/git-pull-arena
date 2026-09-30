# t30_tailscale_prep.ps1 - round 43 task: collect everything needed to plan
# the HPC bridge over Tailscale + check what this laptop can serve
# (SSH jump host / RDP host). READ-ONLY.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t30: Tailscape prep / HPC bridge info (READ-ONLY) ---'

# ------------------------------------------------------- this node's role
Write-Output '--- inbound access INTO this laptop (what the desktop / other devices can use) ---'
try {
    $rdp = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -ErrorAction SilentlyContinue).fDenyTSConnections
    Write-Output ('   RDP host: ' + $(if ($rdp -eq 0) { 'ENABLED - mstsc /v:100.71.123.19 works from any tailnet device' } else { 'disabled (enable: Settings > System > Remote Desktop)' }))
} catch { Write-Output '   RDP host: unknown' }
try {
    $sshd = Get-Service sshd -ErrorAction SilentlyContinue
    if ($sshd) { Write-Output ('   OpenSSH server (sshd): ' + $sshd.Status + ' / ' + $sshd.StartType + '  (ssh user@100.71.123.19 from tailnet devices)') }
    else {
        $cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*' -ErrorAction SilentlyContinue
        $st = 'not installed'
        if ($cap) { $st = [string]$cap.State }
        Write-Output ('   OpenSSH server: ' + $st + ' (Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0)')
    }
} catch { Write-Output '   OpenSSH server: check failed' }
try {
    $f = Get-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq 'True' -and $_.Direction -eq 'Inbound' } | Select-Object -First 1
    Write-Output ('   file sharing (SMB): ' + $(if ($f) { 'firewall rules ON - \\\\100.71.123.19 from tailnet devices' } else { 'no inbound SMB rule (shared folders still reachable if you share one)' }))
} catch { }

# ------------------------------------------------------------ tailscale
Write-Output '--- tailscale state ---'
$tsExe = 'E:\Tailscale\tailscale.exe'
if (Test-Path -LiteralPath $tsExe) {
    try {
        $j = (& $tsExe status --json 2>$null | Out-String) | ConvertFrom-Json
        $me = $j.Self
        Write-Output ('   this node: ' + (San ([string]$me.HostName)) + ' ' + (San ([string]$me.TailscaleIPs[0])) + ' online=' + $me.Online)
        if ($j.CurrentTailnet) {
            Write-Output ('   tailnet: ' + (San ([string]$j.CurrentTailnet.Name)) + ' magic-suffix: ' + (San ([string]$j.CurrentTailnet.MagicDNSSuffix)))
        }
        Write-Output '   peers:'
        foreach ($p in @($j.Peer | Select-Object -First 8)) {
            Write-Output ('      ' + (San ([string]$p.TailscaleIPs[0])).PadRight(16) + (San ([string]$p.HostName)).PadRight(24) + 'online=' + $p.Online + '  ' + (San ([string]$p.OS)))
        }
    } catch { Write-Output ('   [WARN] status json: ' + (San $_.Exception.Message)) }
    # subnet routes already advertised?
    try {
        $pref = & $tsExe debug prefs 2>$null | Out-String
        $ar = ''
        foreach ($ln in @($pref -split "`r?`n")) { if ($ln -match 'AdvertiseRoutes') { $ar = $ln.Trim() } }
        Write-Output ('   advertise-routes: ' + $(if ($ar) { (San $ar) } else { '(none - this node is not a subnet router)' }))
    } catch { }
    try {
        $sv = (& $tsExe serve status 2>&1 | Out-String).Trim()
        if ($sv) { Write-Output ('   serve status: ' + (San ($sv -replace '\s+', ' '))) }
    } catch { }
}

# ------------------------------------------------- campus / network info
Write-Output '--- network (for the HPC bridge plan) ---'
try {
    foreach ($a in @(Get-NetIPConfiguration -ErrorAction Stop | Where-Object { $_.IPv4DefaultGateway })) {
        $ipa = [string]$a.IPv4Address.IPAddress
        Write-Output ('   adapter: ' + (San ([string]$a.InterfaceAlias)) + '  ip=' + $ipa + '  gw=' + (San ([string]$a.IPv4DefaultGateway.NextHop)) + '  dns=' + ((@($a.DNSServer | ForEach-Object { $_.ServerAddresses }) | Select-Object -First 2) -join ','))
    }
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }
$pub = ''
try { $pub = ((& curl.exe -s --max-time 6 https://api.ipify.org 2>$null | Out-String).Trim()) } catch { }
Write-Output ('   public IPv4 (egress): ' + $(if ($pub) { $pub } else { '(curl failed)' }))

Write-Output '--- HPC bridge - what to tell the agent next ---'
Write-Output '   1. the HPC login address (e.g. hpc.xxx.edu.cn or 10.x.y.z) and whether it needs the campus network or a VPN'
Write-Output '   2. ssh port if not 22'
Write-Output '   with that, the options are:'
Write-Output '     a. if the HPC is reachable from THIS laptop: keep an ssh session / use ssh -J via this laptop from anywhere in the tailnet'
Write-Output '     b. make a campus machine a subnet router (tailscale up --advertise-routes=<HPC subnet>) so every tailnet device reaches the HPC directly'
Write-Output '     c. if the HPC allows only web/https portals: tailscale serve/funnel can publish them'
exit 0
