# t192_muse_interconnect_probe_r242.ps1 - round 242.
# Read-only interconnect smoke test after Muse deploy key setup:
#   - check whether Muse has pushed anything into sources/muse/results/muse
#   - verify laptop, desktop, Muse Tailscale visibility
#   - verify laptop <-> desktop reachability, desktop -> laptop SSH probe
#   - verify laptop -> HPC and desktop -> HPC tcp/22, plus laptop SSH to HPC
# Writes results/muse/INTERCONNECT_R242.md and .json. ASCII-only.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')

$outDir = '.\results\muse'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$mdPath = Join-Path $outDir 'INTERCONNECT_R242.md'
$jsonPath = Join-Path $outDir 'INTERCONNECT_R242.json'
$lines = New-Object System.Collections.Generic.List[string]
$records = @()

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { $script:lines.Add($m) | Out-Null; Write-Output $m }
function Add-Rec([string]$name, [string]$state, [string]$detail) { $script:records += [pscustomobject]@{name=$name; state=$state; detail=(San $detail)} }
function Write-Reports {
    $script:lines | Set-Content -LiteralPath $script:mdPath -Encoding UTF8
    $payload = [pscustomobject]@{ time=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'); host=$env:COMPUTERNAME; records=$script:records }
    $payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $script:jsonPath -Encoding UTF8
}
function TcpTest([string]$HostName, [int]$Port, [int]$TimeoutMs) {
    $c = $null
    try {
        $c = New-Object System.Net.Sockets.TcpClient
        $iar = $c.BeginConnect($HostName, $Port, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if (-not $ok) { return $false }
        $c.EndConnect($iar)
        return $c.Connected
    } catch { return $false } finally { if ($c) { $c.Close() } }
}
function Run-Cap([scriptblock]$Sb, [int]$Sec) {
    $job = $null
    try {
        $job = Start-Job -ScriptBlock $Sb
        if (Wait-Job $job -Timeout $Sec) { return ((Receive-Job $job 2>&1) | Out-String).TrimEnd() }
        Stop-Job $job -Force -ErrorAction SilentlyContinue
        return '__TIMEOUT__'
    } catch { return ('__ERROR__ ' + $_.Exception.Message) } finally { if ($job) { Remove-Job $job -Force -ErrorAction SilentlyContinue } }
}
function Find-TailscaleExe {
    $cmd = Get-Command tailscale -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd -and $cmd.Source) { return [string]$cmd.Source }
    foreach ($c in @('E:\Tailscale\tailscale.exe', 'C:\Program Files\Tailscale\tailscale.exe')) { if (Test-Path -LiteralPath $c) { return $c } }
    return $null
}
function NodeLabel($Node) {
    $a = @()
    foreach ($k in @('HostName','DNSName','Name')) { try { $v=[string]$Node.$k; if ($v) { $a += $v } } catch {} }
    if ($a.Count -eq 0) { return '(unnamed)' }
    return ($a -join ' / ')
}
function NodeIPs($Node) {
    $ips = @()
    try { $ips += @($Node.TailscaleIPs) } catch {}
    if ($ips.Count -eq 0) { try { $ips += @($Node.AllowedIPs | Where-Object { $_ -match '^100\.' }) } catch {} }
    return @($ips | Where-Object { $_ } | Select-Object -Unique)
}
function FirstIPv4($Ips) { foreach ($x in @($Ips)) { if ($x -match '^\d+\.\d+\.\d+\.\d+$') { return [string]$x } }; return '' }

L '# Interconnect probe - round 242'
L ''
L ('- Time: ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
L ('- Host: ' + $env:COMPUTERNAME)
L ''

# ---------------------------------------------------- Muse branch contents
L '## 1. Muse GitHub bridge contents'
$museFiles = @()
foreach ($root in @('sources\muse','results\muse','deliverable\muse')) {
    if (Test-Path -LiteralPath $root) {
        foreach ($it in @(Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue)) {
            $rel = $it.FullName.Substring((Get-Location).Path.Length + 1) -replace '\\','/'
            $museFiles += $rel
        }
    }
}
foreach ($f in ($museFiles | Sort-Object)) { L ('- ' + $f) }
$realMuse = @($museFiles | Where-Object { $_ -notmatch '\.gitkeep$' -and $_ -ne 'results/muse/HANDOFF.md' -and $_ -notmatch 'INTERCONNECT_R242' })
if ($realMuse.Count -gt 0) {
    L ('MUSE_PUSH_SEEN: yes (' + $realMuse.Count + ' non-placeholder file(s))')
    Add-Rec 'muse_push' 'seen' ($realMuse -join '; ')
} else {
    L 'MUSE_PUSH_SEEN: no (no non-placeholder Muse upload on this branch yet)'
    Add-Rec 'muse_push' 'not_seen' 'No Muse result package/status has landed yet; deploy-key push must be tested from Muse side.'
}
L ''

# ---------------------------------------------------------- Tailscale map
$ts = Find-TailscaleExe
$laptopIp = '100.71.123.19'
$desktopIp = '100.84.137.117'
$museIp = '100.109.207.34'
$hpcIp = '10.10.5.210'
L '## 2. Tailscale nodes'
if (-not $ts) {
    L '- [WARN] tailscale.exe not found'
    Add-Rec 'tailscale' 'warn' 'tailscale.exe not found'
} else {
    L ('- tailscale.exe: ' + $ts)
    $raw = (& $ts status --json 2>&1 | Out-String)
    try {
        $j = $raw | ConvertFrom-Json
        if ($j.Self) { $laptopIp = FirstIPv4 (NodeIPs $j.Self) }
        $nodes = @()
        if ($j.Self) { $nodes += $j.Self }
        if ($j.Peer) { foreach ($p in @($j.Peer.PSObject.Properties)) { if ($p.Value) { $nodes += $p.Value } } }
        foreach ($n in $nodes) {
            $label = NodeLabel $n
            $ips = NodeIPs $n
            $online = ''
            try { $online = [string]$n.Online } catch {}
            L ('- ' + (San $label) + ' | ips=' + (($ips | ForEach-Object { San ([string]$_) }) -join ', ') + ' | online=' + $online)
            if ($label -match '(?i)desktop') { $desktopIp = FirstIPv4 $ips }
            if ($label -match '(?i)muse') { $museIp = FirstIPv4 $ips }
        }
        Add-Rec 'tailscale' 'ok' ('laptop=' + $laptopIp + ' desktop=' + $desktopIp + ' muse=' + $museIp)
    } catch {
        L ('- [WARN] tailscale status parse failed: ' + (San $_.Exception.Message))
        Add-Rec 'tailscale' 'warn' 'status parse failed'
    }
}
L ''

# -------------------------------------------------------- TCP from laptop
L '## 3. Laptop-side TCP reachability'
foreach ($target in @(
    @{name='desktop'; ip=$desktopIp; ports=@(22,3389,445)},
    @{name='muse'; ip=$museIp; ports=@(22,445,80,443)},
    @{name='hpc'; ip=$hpcIp; ports=@(22)}
)) {
    foreach ($p in $target.ports) {
        $ok = TcpTest $target.ip $p 3500
        $state = $(if ($ok) { 'OPEN' } else { 'closed/filtered' })
        L ('- laptop -> ' + $target.name + ' ' + $target.ip + ':' + $p + ' = ' + $state)
        Add-Rec ('laptop_to_' + $target.name + '_' + $p) $state ($target.ip + ':' + $p)
    }
}
L ''

# --------------------------------------------------------- SSH probes
L '## 4. SSH and reverse probes'
$ssh = (Get-Command ssh -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $ssh) {
    L '- [WARN] ssh client not found'
    Add-Rec 'ssh_client' 'warn' 'not found'
} else {
    $opts = @('-o','BatchMode=yes','-o','ConnectTimeout=10','-o','StrictHostKeyChecking=accept-new')
    L ('- ssh client: ' + $ssh)

    # laptop -> desktop, then desktop -> laptop / desktop -> HPC
    $deskUser = 'BNI'
    $deskTarget = $deskUser + '@' + $desktopIp
    $deskCmd = 'echo DESKTOP_SSH_OK & hostname & powershell -NoProfile -Command "Test-NetConnection ' + $laptopIp + ' -Port 22 -InformationLevel Quiet; Test-NetConnection ' + $hpcIp + ' -Port 22 -InformationLevel Quiet"'
    $deskOut = (& ssh @opts $deskTarget $deskCmd 2>&1 | Out-String).Trim()
    if ($deskOut -match 'DESKTOP_SSH_OK') {
        L '- laptop -> desktop SSH: OK'
        Add-Rec 'laptop_to_desktop_ssh' 'OK' $deskOut
        $parts = @($deskOut -split "`r?`n" | Where-Object { $_ -match 'True|False|DESKTOP|^[A-Za-z0-9_-]+$' })
        foreach ($ln in ($parts | Select-Object -First 8)) { L ('  - desktop| ' + (San $ln)) }
    } else {
        L '- laptop -> desktop SSH: WARN/failed'
        foreach ($ln in (($deskOut -split "`r?`n") | Select-Object -First 8)) { if ($ln.Trim()) { L ('  - desktop-ssh| ' + (San $ln)) } }
        Add-Rec 'laptop_to_desktop_ssh' 'warn' $deskOut
    }

    # laptop -> HPC
    $hpcTarget = '25wenshaohua@' + $hpcIp
    $hpcCmd = 'echo HPC_SSH_OK; hostname; whoami; pwd; (timeout 3 bash -lc "cat < /dev/null > /dev/tcp/' + $laptopIp + '/22" && echo HPC_TO_LAPTOP_22_OPEN || echo HPC_TO_LAPTOP_22_NO) 2>/dev/null'
    $hpcOut = (& ssh @opts $hpcTarget $hpcCmd 2>&1 | Out-String).Trim()
    if ($hpcOut -match 'HPC_SSH_OK') {
        L '- laptop -> HPC SSH: OK'
        Add-Rec 'laptop_to_hpc_ssh' 'OK' $hpcOut
        foreach ($ln in (($hpcOut -split "`r?`n") | Select-Object -First 10)) { if ($ln.Trim()) { L ('  - hpc| ' + (San $ln)) } }
    } else {
        L '- laptop -> HPC SSH: WARN/failed (tcp/22 may still be open)'
        foreach ($ln in (($hpcOut -split "`r?`n") | Select-Object -First 8)) { if ($ln.Trim()) { L ('  - hpc-ssh| ' + (San $ln)) } }
        Add-Rec 'laptop_to_hpc_ssh' 'warn' $hpcOut
    }
}
L ''
L '## 5. Summary'
L ('- Laptop IP: ' + $laptopIp)
L ('- Desktop IP: ' + $desktopIp)
L ('- Muse IP: ' + $museIp + ' (outbound-only; inbound closed is expected)')
L ('- HPC IP: ' + $hpcIp)
L '- Report paths:'
L ('  - ' + ($mdPath -replace '\\','/'))
L ('  - ' + ($jsonPath -replace '\\','/'))
L 'INTERCONNECT_PROBE_DONE'
Write-Reports
exit 0
