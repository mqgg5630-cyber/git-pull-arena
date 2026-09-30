# t36_autostart_vpn_tailscale.ps1 - round 48 task: make Tailscale + the
# NSFOCUS VPN client start at boot/login. Tailscale: service StartType
# (likely already Automatic) + tray GUI in HKCU Run. NSFOCUS: locate the
# client exe (process path -> Win32_Service -> dir scan) and add it to
# HKCU Run (no elevation needed). Prints undo commands.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t36: autostart Tailscale + NSFOCUS VPN ---'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

# ------------------------------------------------------ Tailscale service
Write-Output '--- Tailscale ---'
$tsSvc = $null
try { $tsSvc = Get-Service -Name Tailscale -ErrorAction Stop } catch { }
if ($tsSvc) {
    Write-Output ('   service: ' + $tsSvc.Status + ' / ' + $tsSvc.StartType)
    if ([string]$tsSvc.StartType -ne 'Automatic') {
        try {
            Set-Service -Name Tailscale -StartupType Automatic -ErrorAction Stop
            Write-Output '   -> StartType set to Automatic (no elevation needed)'
        } catch {
            Write-Output '   -> needs elevation, popping UAC - CLICK YES ...'
            $helper = 'E:\tsauto_admin.ps1'
            $rf = 'E:\tsauto_result.txt'
            if (Test-Path -LiteralPath $rf) { Remove-Item -LiteralPath $rf -Force -ErrorAction SilentlyContinue }
            $body = @'
try { Set-Service -Name Tailscale -StartupType Automatic -ErrorAction Stop; $r = 'OK' } catch { $r = $_.Exception.Message }
[System.IO.File]::WriteAllText('E:\tsauto_result.txt', $r, (New-Object System.Text.UTF8Encoding($false)))
'@
            [System.IO.File]::WriteAllText($helper, $body, (New-Object System.Text.UTF8Encoding($true)))
            try {
                $null = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Window', 'Hidden', '-File', $helper)
                $done = $false
                for ($i = 0; $i -lt 30; $i++) { Start-Sleep -Seconds 2; if (Test-Path -LiteralPath $rf) { $done = $true; break } }
                if ($done) { Write-Output ('   elevated result: ' + (San ([string](Get-Content -LiteralPath $rf -Raw)))); Remove-Item -LiteralPath $rf -Force -ErrorAction SilentlyContinue }
                else { Write-Output '   [WARN] no result within 60s' }
                Remove-Item -LiteralPath $helper -Force -ErrorAction SilentlyContinue
            } catch { Write-Output ('   [WARN] elevation declined: ' + (San $_.Exception.Message)) }
        }
    } else { Write-Output '   -> already Automatic, nothing to do' }
} else { Write-Output '   [WARN] Tailscale service not found' }

# ------------------------------------------------- Tailscale tray GUI
$ipn = 'E:\Tailscale\tailscale-ipn.exe'
try {
    $cur = (Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue).'Tailscale'
    if (-not $cur) {
        if (Test-Path -LiteralPath $ipn) {
            New-ItemProperty -Path $runKey -Name 'Tailscale' -Value ('"' + $ipn + '"') -PropertyType String -Force | Out-Null
            Write-Output '   tray GUI: added to HKCU Run (tailscale-ipn.exe)'
        } else { Write-Output '   tray GUI: tailscale-ipn.exe not found, skipped' }
    } else { Write-Output ('   tray GUI already in Run: ' + (San ([string]$cur))) }
} catch { Write-Output ('   [WARN] run key: ' + (San $_.Exception.Message)) }

# ------------------------------------------------------- NSFOCUS VPN
Write-Output '--- NSFOCUS VPN ---'
$exe = ''
try { $p = Get-Process -Name NsfocusVPN -ErrorAction Stop | Select-Object -First 1; if ($p) { $exe = [string]$p.Path } } catch { }
if (-not $exe) { try { $p = Get-Process -Name nsvpn -ErrorAction Stop | Select-Object -First 1; if ($p) { $exe = [string]$p.Path } } catch { } }
if (-not $exe) {
    try {
        $svc = Get-CimInstance Win32_Service -ErrorAction Stop | Where-Object { $_.PathName -match 'nsfo|nsvpn' } | Select-Object -First 1
        if ($svc) { $exe = ([string]$svc.PathName).Trim('"') }
    } catch { }
}
if (-not $exe) {
    foreach ($root in @('C:\Program Files', 'C:\Program Files (x86)', 'D:\', 'E:\')) {
        try {
            $hit = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'nsfo' } | Select-Object -First 1
            if ($hit) {
                $cand = Get-ChildItem -Path $hit.FullName -Recurse -Filter '*.exe' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'nsfo' } | Select-Object -First 1
                if ($cand) { $exe = $cand.FullName; break }
            }
        } catch { }
    }
}
if ($exe) {
    Write-Output ('   client exe: ' + $exe)
    $cur2 = $null
    try { $cur2 = (Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue).'NsfocusVPN' } catch { }
    if ($cur2) {
        Write-Output ('   already in HKCU Run: ' + (San ([string]$cur2)))
    } else {
        try {
            New-ItemProperty -Path $runKey -Name 'NsfocusVPN' -Value ('"' + $exe + '"') -PropertyType String -Force | Out-Null
            Write-Output '   HKCU Run added: NsfocusVPN (starts at login)'
            Write-Output '   note: auto-START is guaranteed; auto-CONNECT depends on the client remembering credentials'
            Write-Output '   undo: Remove-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Run -Name NsfocusVPN'
        } catch { Write-Output ('   [FAIL] ' + (San $_.Exception.Message)) }
    }
} else { Write-Output '   [WARN] NSFOCUS exe not located (is the VPN running?) - retry when connected' }

# ------------------------------------------- record current autostart
Write-Output '--- current autostart (for the record) ---'
try {
    foreach ($n in @('Tailscale', 'NsfocusVPN')) {
        $v = (Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue).$n
        Write-Output ('   Run[' + $n + '] = ' + (San ([string]$v)))
    }
} catch { }
try {
    $sf = [Environment]::GetFolderPath('Startup')
    foreach ($f in @(Get-ChildItem -Path $sf -ErrorAction SilentlyContinue)) { Write-Output ('   startup-folder: ' + (San ([string]$f.Name))) }
} catch { }
exit 0
