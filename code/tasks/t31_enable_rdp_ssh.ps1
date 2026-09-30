# t31_enable_rdp_ssh.ps1 - round 44 task: make this laptop reachable from
# the tailnet (user approved BOTH): enable Remote Desktop + install and
# start the OpenSSH server. Both need admin -> ONE UAC popup; the elevated
# helper writes its result to E:\rdpssh_result.txt.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t31: enable RDP + OpenSSH server (UAC) ---'
$resultFile = 'E:\rdpssh_result.txt'
if (Test-Path -LiteralPath $resultFile) { Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue }

$helper = 'E:\rdpssh_admin.ps1'
$body = @'
# elevated: RDP on + OpenSSH server on
$ErrorActionPreference = 'Continue'
$lines = @()
try {
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0 -ErrorAction Stop
    $lines += 'RDP: enabled (fDenyTSConnections=0)'
} catch { $lines += ('RDP enable failed: ' + $_.Exception.Message) }
try {
    Enable-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction Stop
    $lines += 'RDP: firewall group enabled'
} catch { $lines += ('RDP firewall: ' + $_.Exception.Message) }
try {
    $cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' -ErrorAction Stop
    if ([string]$cap.State -ne 'Installed') {
        $r = Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' -ErrorAction Stop
        $lines += ('OpenSSH: installed (restart needed? ' + $r.RestartNeeded + ')')
    } else { $lines += 'OpenSSH: already installed' }
    Start-Service sshd -ErrorAction SilentlyContinue
    Set-Service sshd -StartupType Automatic -ErrorAction SilentlyContinue
    $sv = Get-Service sshd -ErrorAction SilentlyContinue
    $lines += ('sshd service: ' + $(if ($sv) { $sv.Status + ' / ' + $sv.StartType } else { 'not found' }))
} catch { $lines += ('OpenSSH: ' + $_.Exception.Message) }
[System.IO.File]::WriteAllText('E:\rdpssh_result.txt', ($lines -join "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
'@
try {
    [System.IO.File]::WriteAllText($helper, $body, (New-Object System.Text.UTF8Encoding($true)))
    Write-Output ('   helper written: ' + $helper)
} catch { Write-Output ('   [FAIL] ' + (San $_.Exception.Message)); exit 2 }

Write-Output '   popping the UAC dialog - CLICK YES on the screen ...'
$ok = $false
try {
    $p = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Window', 'Hidden', '-File', $helper) -PassThru
    $ok = $true
    Write-Output ('   elevated process started (pid ' + $p.Id + ')')
} catch { Write-Output ('   [WARN] elevation declined: ' + (San $_.Exception.Message)) }

if ($ok) {
    $found = $false
    for ($i = 0; $i -lt 90; $i++) {
        Start-Sleep -Seconds 3
        if (Test-Path -LiteralPath $resultFile) { $found = $true; break }
    }
    if ($found) {
        Write-Output '   --- elevated result ---'
        foreach ($ln in @(Get-Content -LiteralPath $resultFile -ErrorAction SilentlyContinue)) { Write-Output ('   ' + (San ([string]$ln))) }
        Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue
    } else { Write-Output '   [WARN] no result file after 270s (OpenSSH download can be slow - check Get-Service sshd later)' }
    Remove-Item -LiteralPath $helper -Force -ErrorAction SilentlyContinue
}

# non-elevated verify
Write-Output '   --- verify ---'
try {
    $rdp = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -ErrorAction Stop).fDenyTSConnections
    Write-Output ('   RDP host: ' + $(if ($rdp -eq 0) { 'ENABLED - from the desktop run: mstsc /v:100.71.123.19' } else { 'still disabled' }))
} catch { }
try {
    $sv = Get-Service sshd -ErrorAction Stop
    Write-Output ('   sshd: ' + $sv.Status + ' / ' + $sv.StartType + ' - from the desktop run: ssh <windowsuser>@100.71.123.19')
} catch { Write-Output '   sshd: not visible yet' }
exit 0
