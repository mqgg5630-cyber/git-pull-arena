# t21_optimize_review.ps1 - round 38 task: overall optimization review,
# READ-ONLY. Collects: startup programs, non-Microsoft services and tasks,
# active power plan, Storage Sense, physical disk health, C:/E: space,
# top memory processes, .wslconfig (WSL RAM cap!), and the full Tailscale
# state (service + version + status + IP) so the next round can fix it.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t21: optimization review (READ-ONLY) ---'

# ------------------------------------------------------------ startup
Write-Output '--- startup programs ---'
try {
    $su = @(Get-CimInstance Win32_StartupCommand -ErrorAction Stop)
    Write-Output ('   entries: ' + $su.Count)
    foreach ($s in @($su | Select-Object -First 30)) {
        $loc = ''
        try { $loc = $s.Location } catch { }
        Write-Output ('   ' + (San ([string]$s.Name)).PadRight(28).Substring(0, [Math]::Min(28, (San ([string]$s.Name)).Length)) + ' | ' + (San ([string]$s.Command)))
    }
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }

# ----------------------------------------------------------- services
Write-Output '--- non-Microsoft services (running or auto) ---'
try {
    $svcs = @(Get-CimInstance Win32_Service -ErrorAction Stop | Where-Object { $_.PathName -and ($_.PathName -notlike 'C:\Windows\*') -and ($_.State -eq 'Running' -or $_.StartMode -ne 'Manual') })
    Write-Output ('   entries: ' + $svcs.Count)
    foreach ($v in @($svcs | Sort-Object State, Name | Select-Object -First 40)) {
        $pn = (San ([string]$v.PathName))
        if ($pn.Length -gt 70) { $pn = $pn.Substring(0, 70) + '...' }
        Write-Output ('   ' + $v.State.PadRight(9) + $v.StartMode.PadRight(11) + (San $v.Name).PadRight(26) + ' ' + $pn)
    }
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }

# ----------------------------------------------------- scheduled tasks
Write-Output '--- non-Microsoft scheduled tasks ---'
try {
    $tks = @(Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskPath -notlike '\Microsoft\*' })
    Write-Output ('   entries: ' + $tks.Count)
    foreach ($t in @($tks | Select-Object -First 25)) {
        $exe = ''
        try { $exe = [string]$t.Actions[0].Execute } catch { }
        Write-Output ('   ' + ([string]$t.State).PadRight(9) + '\' + (San ([string]$t.TaskPath)).Trim('\') + '\' + (San ([string]$t.TaskName)) + '  ->  ' + (San $exe))
    }
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }

# -------------------------------------------------------- power plan
try {
    $ap = (& powercfg /getactivescheme 2>&1 | Out-String).Trim()
    Write-Output ('--- power plan ---')
    Write-Output ('   ' + (San ($ap -replace '\s+', ' ')))
} catch { }

# ---------------------------------------------------- storage sense
Write-Output '--- Storage Sense ---'
try {
    $ssk = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy'
    if (Test-Path $ssk) {
        $sp = Get-ItemProperty $ssk
        Write-Output ('   01(enabled)=' + $sp.'01' + '  2048(cadence)=' + $sp.'2048' + '  04(temp)=' + $sp.'04' + '  08(recyclebin)=' + $sp.'08')
    } else { Write-Output '   not configured (default)' }
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }

# ------------------------------------------------------ disks + space
Write-Output '--- physical disks ---'
try {
    foreach ($d in @(Get-PhysicalDisk -ErrorAction Stop)) {
        Write-Output ('   ' + (San ([string]$d.FriendlyName)).PadRight(36) + ' ' + (San ([string]$d.MediaType)).PadRight(10) + ' ' + ([math]::Round($d.Size / 1GB, 1)) + ' GB  health=' + $d.HealthStatus)
    }
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }
foreach ($dl in @('C:', 'E:')) {
    try {
        $dk = Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='" + $dl + "'")
        Write-Output ('   ' + $dl + ' free ' + ([math]::Round($dk.FreeSpace / 1GB, 1)) + ' of ' + ([math]::Round($dk.Size / 1GB, 1)) + ' GB')
    } catch { }
}

# ----------------------------------------------------------- memory
try {
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Output ('--- memory ---')
    Write-Output ('   total ' + ([math]::Round($os.TotalVisibleMemorySize / 1MB, 1)) + ' GB, free ' + ([math]::Round($os.FreePhysicalMemory / 1MB, 1)) + ' GB')
    $top = @(Get-Process -ErrorAction SilentlyContinue | Sort-Object WorkingSet -Descending | Select-Object -First 12)
    foreach ($p in $top) {
        Write-Output ('   ' + ([math]::Round($p.WorkingSet / 1MB)).ToString().PadLeft(6) + ' MB  ' + (San $p.Name) + '(' + $p.Id + ')')
    }
} catch { }

# ------------------------------------------------------------- WSL
Write-Output '--- WSL config + distros ---'
$wslcfg = Join-Path $env:USERPROFILE '.wslconfig'
if (Test-Path -LiteralPath $wslcfg) {
    foreach ($ln in @(Get-Content -LiteralPath $wslcfg -ErrorAction SilentlyContinue | Select-Object -First 12)) { Write-Output ('   cfg: ' + (San ([string]$ln))) }
    Write-Output '   NOTE: memory=16GB on a 15.9 GB RAM machine caps WSL at ALL physical RAM -'
    Write-Output '         if Windows feels slow while WSL/Docker runs, cap it at 8 GB instead.'
} else { Write-Output '   no .wslconfig (defaults: WSL may take up to 50% RAM)' }
try {
    $wl = (& wsl.exe -l -v 2>&1 | Out-String)
    foreach ($l in @($wl -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 8)) { Write-Output ('   ' + (San ([string]$l))) }
} catch { }

# --------------------------------------------------------- Tailscale
Write-Output '--- Tailscale ---'
$tsSvc = Get-Service -Name Tailscale -ErrorAction SilentlyContinue
if ($tsSvc) { Write-Output ('   service: ' + $tsSvc.Status + ' / start type ' + $tsSvc.StartType) }
else { Write-Output '   service: NOT FOUND (is Tailscale installed as an app or only a folder?)' }
$tsExe = $null
foreach ($c in @('C:\Program Files\Tailscale\tailscale.exe', 'C:\Program Files (x86)\Tailscale\tailscale.exe', "$env:LOCALAPPDATA\Programs\Tailscale\tailscale.exe")) {
    if (Test-Path -LiteralPath $c) { $tsExe = $c; break }
}
if (-not $tsExe) {
    $c2 = Get-Command tailscale -ErrorAction SilentlyContinue
    if ($c2) { $tsExe = [string]$c2.Source }
}
if (-not $tsExe) {
    try {
        $hits = @(Get-ChildItem -LiteralPath 'E:\tailscale' -Recurse -Depth 3 -Filter 'tailscale.exe' -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($hits.Count -gt 0) { $tsExe = $hits[0].FullName }
    } catch { }
}
Write-Output ('   CLI: ' + $(if ($tsExe) { (San $tsExe) } else { 'not found' }))
if ($tsExe) {
    $v = ''
    try { $v = ((& $tsExe version 2>&1 | Out-String).Trim() -replace '\s+', ' ') } catch { $v = 'ERR ' + (San $_.Exception.Message) }
    Write-Output ('   version: ' + (San $v))
    $st = ''
    try { $st = (& $tsExe status 2>&1 | Out-String) } catch { $st = 'ERR ' + (San $_.Exception.Message) }
    $stLines = @($st -split "`r?`n" | Where-Object { $_ -match '\S' })
    Write-Output ('   status lines: ' + $stLines.Count)
    foreach ($l in @($stLines | Select-Object -First 15)) { Write-Output ('      ' + (San ([string]$l))) }
    $ip = ''
    try { $ip = ((& $tsExe ip -4 2>&1 | Out-String).Trim() -replace '\s+', ' ') } catch { $ip = 'ERR' }
    Write-Output ('   this node IPv4: ' + (San $ip))
    $ng = ''
    try { $ng = ((& $tsExe netcheck 2>&1 | Out-String)) } catch { $ng = 'ERR' }
    foreach ($l in @(($ng -split "`r?`n") | Where-Object { $_ -match '(?i)udp|ipv4|ipv6|derp|hairpin|portmap' } | Select-Object -First 10)) { Write-Output ('      net: ' + (San ([string]$l))) }
}
Write-Output '--- task t21 done (READ-ONLY) ---'
exit 0
