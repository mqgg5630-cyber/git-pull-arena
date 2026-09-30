# t35_desktop_access_probe.ps1 - round 47 task: diagnose the two
# desktop-access failures (RDP cert error is expected to be benign;
# SMB \\100.84.137.117 failed) + verify the HPC chain state
# (route approval? VPN still up?). READ-ONLY.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

$ts = 'E:\Tailscale\tailscale.exe'
$desktop = '100.84.137.117'

function Invoke-Cap {
    param([scriptblock]$sb, [int]$cap)
    $job = Start-Job -ScriptBlock $sb
    if (Wait-Job $job -Timeout $cap) {
        $o = (Receive-Job $job | Out-String)
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        return $o
    }
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    return '__TIMEOUT__'
}

Write-Output '--- task t35: desktop access + HPC chain probe (READ-ONLY) ---'

Write-Output ('--- A. tailscale link to desktop ' + $desktop + ' ---')
$r = Invoke-Cap { & 'E:\Tailscale\tailscale.exe' ping 100.84.137.117 2>&1 | Out-String } 30
foreach ($l in @($r -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 4)) { Write-Output ('   ' + (San ([string]$l))) }

Write-Output '--- B. desktop TCP ports ---'
foreach ($port in @(3389, 445, 22)) {
    $verdict = 'closed/timeout'
    try {
        $t = New-Object System.Net.Sockets.TcpClient
        if ($t.ConnectAsync($desktop, $port).Wait(3000) -and $t.Connected) { $verdict = 'OPEN' }
        $t.Close()
    } catch { }
    $svc = 'RDP (mstsc)'
    if ($port -eq 445) { $svc = 'SMB (file share)' }
    if ($port -eq 22) { $svc = 'SSH' }
    Write-Output ('   port ' + $port.ToString().PadRight(6) + $svc.PadRight(20) + $verdict)
}

Write-Output '--- C. share enumeration (net view) ---'
$r = Invoke-Cap {
    $o = (& cmd /c net view \\100.84.137.117 2>&1 | Out-String)
    ('NETVIEW_EXIT=' + $LASTEXITCODE)
    $o
} 20
foreach ($l in @($r -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 8)) { Write-Output ('   ' + (San ([string]$l))) }

Write-Output '--- D. HPC route approval state ---'
try {
    $p = (& $ts debug prefs 2>$null | Out-String)
    foreach ($ln in @($p -split "`r?`n")) { if ($ln -match 'AdvertiseRoutes') { Write-Output ('   advertises: ' + (San ($ln.Trim()))) } }
} catch { }
$nm = Invoke-Cap { & 'E:\Tailscale\tailscale.exe' debug netmap 2>&1 | Out-String } 30
if ($nm -eq '__TIMEOUT__' -or -not $nm) {
    Write-Output '   netmap: unavailable'
} else {
    $m = [regex]::Matches($nm, '.{0,60}10\.10\.5\.210.{0,60}')
    if ($m.Count -eq 0) {
        Write-Output '   netmap has NO 10.10.5.210 -> route NOT approved yet (admin console step pending)'
        Write-Output ('   netmap head: ' + (San ($nm.Substring(0, [Math]::Min(120, $nm.Length)).Trim())))
    } else {
        Write-Output ('   netmap contains 10.10.5.210 x' + $m.Count + ' -> route APPROVED and active:')
        foreach ($x in @($m | Select-Object -First 6)) { Write-Output ('      ' + (San ([string]$x.Value))) }
    }
}
try {
    $j = ((& $ts status --json 2>$null | Out-String) | ConvertFrom-Json)
    $self = ($j.Self | ConvertTo-Json -Depth 4 -Compress)
    if ($self -match '10\.10\.5\.210') { Write-Output '   status self shows 10.10.5.210 (approved)' }
    else { Write-Output '   status self: no 10.10.5.210 field (normal if unapproved)' }
} catch { }

Write-Output '--- E. HPC via VPN (laptop side) ---'
$pong = $false
try { $pong = Test-Connection -ComputerName '10.10.5.210' -Count 2 -Quiet -ErrorAction SilentlyContinue } catch { }
Write-Output ('   ping 10.10.5.210: ' + $(if ($pong) { 'reply' } else { 'no reply' }))
$ok = $false
try {
    $t = New-Object System.Net.Sockets.TcpClient
    $ok = ($t.ConnectAsync('10.10.5.210', 22).Wait(4000) -and $t.Connected)
    $t.Close()
} catch { }
Write-Output ('   tcp 10.10.5.210:22: ' + $(if ($ok) { 'OPEN (VPN fine, HPC reachable from laptop)' } else { 'closed/timeout (VPN down?)' }))

Write-Output '--- F. laptop network profiles (reference) ---'
try {
    foreach ($np in @(Get-NetConnectionProfile -ErrorAction Stop)) {
        Write-Output ('   ' + (San ([string]$np.InterfaceAlias)).PadRight(24) + ' category=' + (San ([string]$np.NetworkCategory)))
    }
} catch { Write-Output '   (profiles unavailable)' }
exit 0
