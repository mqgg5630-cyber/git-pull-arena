# desk_sync_ide.ps1 - runs ON THE DESKTOP via ssh. Task 1: bring the
# desktop Antigravity IDE up to the laptop's 2.15.1 (installer or copied
# install tree staged by the laptop on F$), keep the proxy chain intact,
# then relaunch and verify. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{40,}', '[REDACTED]' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop IDE sync (target: laptop 2.15.1) ---'

$agExe = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
$inst = 'F:\fig1_rebuild\agy_installer_2151.exe'
$srcDir = 'F:\fig1_rebuild\agy_install_src'
$dst = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity'

function Get-AgyVer {
    try { return [string](Get-Item -LiteralPath $agExe -ErrorAction Stop).VersionInfo.ProductVersion } catch { return '' }
}

L ('   current version: ' + (San (Get-AgyVer)))
$v0 = Get-AgyVer

# ---------------- 1. stop running instances ----------------
$round = 0
while ($round -lt 3) {
    $round++
    $a = @(Get-Process -Name Antigravity -ErrorAction SilentlyContinue)
    $l = @(Get-Process -Name language_server -ErrorAction SilentlyContinue)
    if ($a.Count -eq 0 -and $l.Count -eq 0) { break }
    if ($a.Count -gt 0) { try { & taskkill /f /im Antigravity.exe 2>&1 | Out-Null } catch { } }
    if ($l.Count -gt 0) { try { & taskkill /f /im language_server.exe 2>&1 | Out-Null } catch { } }
    Start-Sleep -Seconds 5
}
L ('   stopped: rounds=' + $round + ' remaining A=' + @(Get-Process -Name Antigravity -ErrorAction SilentlyContinue).Count + ' LS=' + @(Get-Process -Name language_server -ErrorAction SilentlyContinue).Count)

# ---------------- 2. install ----------------
$done = $false
if (Test-Path -LiteralPath $inst) {
    L ('   installer found: ' + [math]::Round((Get-Item -LiteralPath $inst).Length/1MB) + 'MB')
    try {
        $p = Start-Process -FilePath $inst -ArgumentList '--silent' -PassThru -ErrorAction Stop
        $waited = 0
        while (-not $p.HasExited -and $waited -lt 420) { Start-Sleep -Seconds 5; $waited += 5; $p.Refresh() }
        L ('   installer --silent: exited=' + $p.HasExited + ' code=' + $(try { $p.ExitCode } catch { '?' }) + ' (waited ' + $waited + 's)')
    } catch { L ('   installer launch failed: ' + (San $_.Exception.Message)) }
    $poll = 0
    while ($poll -lt 300) {
        Start-Sleep -Seconds 10; $poll += 10
        $v = Get-AgyVer
        if ($v -and $v -ne $v0) { $done = $true; break }
    }
    L ('   after --silent poll ' + $poll + 's: version=' + (San (Get-AgyVer)))
    if (-not $done) {
        L '   retrying installer WITHOUT silent flag (detached)...'
        try { Start-Process -FilePath $inst -ErrorAction Stop | Out-Null } catch { L ('   retry launch failed: ' + (San $_.Exception.Message)) }
        $poll = 0
        while ($poll -lt 600) {
            Start-Sleep -Seconds 15; $poll += 15
            $v = Get-AgyVer
            if ($v -and $v -ne $v0) { $done = $true; break }
        }
        L ('   after no-arg poll ' + $poll + 's: version=' + (San (Get-AgyVer)))
    }
}
elseif (Test-Path -LiteralPath ($srcDir + '\Antigravity.exe')) {
    L '   copied install tree found - robocopy into place'
    & robocopy $srcDir $dst /E /MT:16 /NFL /NDL /NJH /NP 2>&1 | Select-Object -Last 6 | ForEach-Object { L ('      robocopy: ' + (San ([string]$_))) }
    $v = Get-AgyVer
    if ($v -and $v -ne $v0) { $done = $true }
    L ('   after robocopy: version=' + (San $v))
}
else { L '   [FAIL] neither installer nor install tree staged on F:' }

# desktop's own updater cache (reference only)
$upd = Join-Path $env:LOCALAPPDATA 'antigravity-updater\installer.exe'
if (Test-Path -LiteralPath $upd) { L ('   desktop updater cache: v' + (San ([string](Get-Item -LiteralPath $upd).VersionInfo.ProductVersion)) + ' (' + [math]::Round((Get-Item -LiteralPath $upd).Length/1MB) + 'MB)') }
L ('   INSTALL RESULT: ' + $(if ($done) { 'UPDATED ' + (San $v0) + ' -> ' + (San (Get-AgyVer)) } else { 'NOT UPDATED (still ' + (San (Get-AgyVer)) + ')' }))

# ---------------- 3. sync laptop User settings.json ----------------
$setSrc = 'F:\fig1_rebuild\agy_settings_laptop.json'
if (Test-Path -LiteralPath $setSrc) {
    foreach ($app in @('Antigravity', 'Antigravity IDE')) {
        $sf = Join-Path $env:APPDATA ($app + '\User\settings.json')
        try {
            New-Item -ItemType Directory -Force -Path (Split-Path $sf) | Out-Null
            if (Test-Path -LiteralPath $sf) { Copy-Item -LiteralPath $sf -Destination ($sf + '.bak-' + (Get-Date -Format 'HHmmss')) -Force }
            Copy-Item -LiteralPath $setSrc -Destination $sf -Force
            $null = Get-Content -LiteralPath $sf -Raw | ConvertFrom-Json
            L ('   settings.json synced + JSON valid: ' + $app)
        } catch { L ('   settings sync FAILED (' + $app + '): ' + (San $_.Exception.Message)) }
    }
}
else { L '   laptop settings.json not staged - keeping current' }

# ---------------- 4. relaunch + verify chain ----------------
try { Start-ScheduledTask -TaskName 'agyrelaunch'; L '   relaunched via agyrelaunch' } catch { L ('   [FAIL] relaunch: ' + (San $_.Exception.Message)) }
Start-Sleep -Seconds 45
$a = @(Get-Process -Name Antigravity -ErrorAction SilentlyContinue | Sort-Object StartTime)
L ('   processes: ' + $a.Count + $(if ($a.Count -gt 0) { ' first start ' + $a[0].StartTime.ToString('HH:mm:ss') } else { '' }))
if ($a.Count -gt 0) {
    $since = $a[0].StartTime
    $lsLog = Join-Path $env:APPDATA 'Antigravity\logs\language_server.log'
    $dial = 0; $tot = 0
    foreach ($ln in @(Get-Content -LiteralPath $lsLog -ErrorAction SilentlyContinue)) {
        if ($ln -match '([EWIF]\d{4}) (\d{2}):(\d{2}):(\d{2})') {
            $md = $Matches[1].Substring(1)
            try {
                $t = Get-Date -Month ([int]$md.Substring(0,2)) -Day ([int]$md.Substring(2,2)) -Hour ([int]$Matches[2]) -Minute ([int]$Matches[3]) -Second ([int]$Matches[4])
                if ($t -ge $since) { $tot++; if ($ln -match 'dial tcp') { $dial++ } }
            } catch { }
        }
    }
    $pc = 0
    foreach ($pr in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { (($_.ExecutablePath) -and ($_.ExecutablePath -match 'Antigravity')) -or $_.Name -eq 'language_server.exe' })) {
        foreach ($c in @(Get-NetTCPConnection -OwningProcess $pr.ProcessId -ErrorAction SilentlyContinue)) {
            if ([string]$c.RemoteAddress -eq '127.0.0.1' -and $c.RemotePort -eq 10808) { $pc++ }
        }
    }
    L ('   fresh session: ls.log lines=' + $tot + ' dial-tcp=' + $dial + '  live to-proxy=' + $pc)
    L ('   VERDICT: ' + $(if ($dial -eq 0 -and $pc -gt 0) { 'IDE synced AND proxy chain intact' } elseif ($dial -eq 0) { 'IDE synced, proxy idle (recheck later)' } else { 'IDE synced but dial-tcp errors present' }))
}
L '--- desktop IDE sync done ---'
