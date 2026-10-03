# Probe Muse on the user's Tailscale network from the real Windows laptop.
# This is read-only: it does not change routes, shares, credentials, or files.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')

$outDir = Join-Path (Get-Location) 'results\status'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report = Join-Path $outDir 'muse_tailscale_probe_r238.md'
$lines = New-Object System.Collections.Generic.List[string]

function Add-Line {
    param([string]$Text)
    $script:lines.Add($Text) | Out-Null
    Write-Output $Text
}

function Write-Report {
    $script:lines | Set-Content -LiteralPath $script:report -Encoding UTF8
}

function Find-TailscaleExe {
    $cmd = Get-Command tailscale -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd -and $cmd.Source) { return [string]$cmd.Source }
    $cands = @()
    if ($env:ProgramFiles) { $cands += (Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe') }
    $pf86 = ${env:ProgramFiles(x86)}
    if ($pf86) { $cands += (Join-Path $pf86 'Tailscale\tailscale.exe') }
    $cands += 'C:\Program Files\Tailscale\tailscale.exe'
    foreach ($c in $cands) { if (Test-Path -LiteralPath $c) { return $c } }
    return $null
}

function Node-Label {
    param($Node)
    $names = @()
    foreach ($k in @('HostName','DNSName','Name')) {
        try {
            $v = [string]$Node.$k
            if ($v) { $names += $v }
        } catch { }
    }
    if ($names.Count -eq 0) { return '(unnamed)' }
    return ($names -join ' / ')
}

function Node-IPs {
    param($Node)
    $ips = @()
    try { $ips += @($Node.TailscaleIPs) } catch { }
    if ($ips.Count -eq 0) {
        try { $ips += @($Node.AllowedIPs | Where-Object { $_ -match '^100\.' }) } catch { }
    }
    return @($ips | Where-Object { $_ } | Select-Object -Unique)
}

function First-IPv4 {
    param([string[]]$IPs)
    foreach ($ip in @($IPs)) { if ($ip -match '^\d+\.\d+\.\d+\.\d+$') { return $ip } }
    if ($IPs.Count -gt 0) { return [string]$IPs[0] }
    return $null
}

function Test-TcpPort {
    param([string]$HostName, [int]$Port, [int]$TimeoutMs = 3000)
    $client = $null
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect($HostName, $Port, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if (-not $ok) { return $false }
        $client.EndConnect($iar)
        return $client.Connected
    } catch {
        return $false
    } finally {
        if ($client) { $client.Close() }
    }
}

function Run-NetView {
    param([string]$HostName)
    $job = $null
    try {
        $job = Start-Job -ScriptBlock {
            param($h)
            cmd /c "net view \\$h" 2>&1
        } -ArgumentList $HostName
        $done = Wait-Job $job -Timeout 12
        if ($done) {
            return ((Receive-Job $job 2>&1) | Out-String).TrimEnd()
        }
        Stop-Job $job -Force -ErrorAction SilentlyContinue
        return 'net view timed out after 12 seconds'
    } catch {
        return ('net view failed: ' + $_.Exception.Message)
    } finally {
        if ($job) { Remove-Job $job -Force -ErrorAction SilentlyContinue }
    }
}

Add-Line '# Muse Tailscale probe - round 238'
Add-Line ''
Add-Line ('- Time: ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
Add-Line ('- Host: ' + $env:COMPUTERNAME)
Add-Line ('- User: ' + $env:USERNAME)
Add-Line ''

$ts = Find-TailscaleExe
if (-not $ts) {
    Add-Line '[FAIL] tailscale.exe was not found on this laptop.'
    Add-Line 'MUSE_TAILSCALE_PROBE_DONE'
    Write-Report
    exit 1
}
Add-Line ('- tailscale.exe: ' + $ts)

$statusText = (& $ts status --json 2>&1 | Out-String)
$statusCode = $LASTEXITCODE
if ($statusCode -ne 0 -or -not $statusText.Trim()) {
    Add-Line ('[FAIL] tailscale status --json failed, exit=' + $statusCode)
    Add-Line '```'
    Add-Line ($statusText.TrimEnd())
    Add-Line '```'
    Add-Line 'MUSE_TAILSCALE_PROBE_DONE'
    Write-Report
    exit 1
}

try {
    $status = $statusText | ConvertFrom-Json
} catch {
    Add-Line ('[FAIL] could not parse tailscale status JSON: ' + $_.Exception.Message)
    Add-Line 'MUSE_TAILSCALE_PROBE_DONE'
    Write-Report
    exit 1
}

try { Add-Line ('- BackendState: ' + [string]$status.BackendState) } catch { }
if ($status.Self) {
    Add-Line ('- This node: ' + (Node-Label $status.Self) + ' | ips=' + ((Node-IPs $status.Self) -join ', '))
}
Add-Line ''

$nodes = @()
if ($status.Self) { $nodes += $status.Self }
if ($status.Peer) {
    foreach ($prop in @($status.Peer.PSObject.Properties)) {
        if ($prop.Value) { $nodes += $prop.Value }
    }
}

Add-Line '## Tailnet nodes seen by this laptop'
if ($nodes.Count -eq 0) {
    Add-Line '- (none)'
} else {
    foreach ($n in $nodes) {
        $ips = Node-IPs $n
        $online = ''
        try { $online = [string]$n.Online } catch { }
        $os = ''
        try { $os = [string]$n.OS } catch { }
        Add-Line ('- ' + (Node-Label $n) + ' | ips=' + ($ips -join ', ') + ' | online=' + $online + ' | os=' + $os)
    }
}
Add-Line ''

$muse = @()
foreach ($n in $nodes) {
    $text = (Node-Label $n)
    if ($text -match '(?i)muse') { $muse += $n }
}

if ($muse.Count -eq 0) {
    Add-Line '[FAIL] No Tailscale node whose name contains "muse" was found.'
    Add-Line 'Ask Muse for its Tailscale IP or MagicDNS name, then test it from this laptop.'
    Add-Line 'MUSE_TAILSCALE_PROBE_DONE'
    Write-Report
    exit 2
}

Add-Line '## Muse candidates'
$ports = @(445,22,139,3389,80,443,8000,8080,5000)
$anySmb = $false
$anySsh = $false
foreach ($n in $muse) {
    $label = Node-Label $n
    $ips = Node-IPs $n
    $ip = First-IPv4 $ips
    Add-Line ('### ' + $label)
    Add-Line ('- IPs: ' + ($ips -join ', '))
    if (-not $ip) {
        Add-Line '- [FAIL] no usable Tailscale IP for this node'
        continue
    }
    Add-Line ('- Probe target: ' + $ip)
    foreach ($p in $ports) {
        $open = Test-TcpPort -HostName $ip -Port $p -TimeoutMs 3000
        if ($open) {
            Add-Line ('  - tcp/' + $p + ': OPEN')
            if ($p -eq 445) { $anySmb = $true }
            if ($p -eq 22) { $anySsh = $true }
        } else {
            Add-Line ('  - tcp/' + $p + ': closed/filtered')
        }
    }
    if (Test-TcpPort -HostName $ip -Port 445 -TimeoutMs 1000) {
        Add-Line ''
        Add-Line ('#### SMB share listing for ' + $ip)
        Add-Line '```'
        Add-Line (Run-NetView -HostName $ip)
        Add-Line '```'
    }
    Add-Line ''
}

Add-Line '## Access guidance'
if ($anySmb) {
    Add-Line 'MUSE_FILE_PATH_READY_SMB'
    Add-Line '- SMB port 445 is open. In File Explorer, try the UNC path shown by net view, or start with:'
    foreach ($n in $muse) {
        $ip = First-IPv4 (Node-IPs $n)
        if ($ip) { Add-Line ('  - \\' + $ip + '\\') }
        try {
            if ($n.DNSName) { Add-Line ('  - \\' + ([string]$n.DNSName).TrimEnd('.') + '\\') }
        } catch { }
    }
    Add-Line '- If a share name is listed, map it for example with: net use M: \\<muse-ip>\<share> /persistent:yes'
} elseif ($anySsh) {
    Add-Line 'MUSE_REACHABLE_SSH_ONLY'
    Add-Line '- SSH/SFTP port 22 is open, but SMB port 445 is not open. Use SFTP/WinSCP/VS Code Remote, or enable an SMB share on Muse for a Windows UNC path.'
} else {
    Add-Line 'MUSE_REACHABLE_NO_FILE_SERVICE'
    Add-Line '- Muse is visible in Tailscale, but common file-service ports were not open. Ask Muse to expose SMB tcp/445 or SSH/SFTP tcp/22 on its Tailscale IP.'
}

Add-Line 'MUSE_TAILSCALE_PROBE_DONE'
Write-Report

if (-not $anySmb -and -not $anySsh) { exit 3 }
exit 0
