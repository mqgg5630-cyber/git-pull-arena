# desk_antigravity_fix4.ps1 - runs ON THE DESKTOP. v4: deterministic proxy
# env delivery to the Go language server. r135 proved: language_server.exe
# holds 10 TCP conns with to-proxy=0, all direct SYN_SENT to Google; the
# wrapper on disk had its lowercase set lines split in two (array concat
# bug in fix3); top failing endpoint = daily-cloudcode-pa.googleapis.com
# (the auth backend). v4:
#   A. dump state: process cmdlines, HKCU env registry, settings.json
#      validity, main.log proxy mentions, curl-via-proxy to the backend
#   B. rewrite wrapper with literal lines + byte-exact read-back (plus a
#      runtime env snapshot + invoke log the wrapper itself writes);
#      re-merge settings.json with round-trip validation; setx user env
#      (registry-verified); setx /M if elevated
#   C. kill all, relaunch through the wrapper task, then PROVE the chain:
#      task LastRunTime vs process starts, LS cmdline, live TCP probes,
#      and fresh ls.log must show 0 dial-tcp (HTTP 401/403 instead means
#      the LS talks THROUGH the proxy and just needs the user login).
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{40,}', '[REDACTED]' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

$proxy = 'http://127.0.0.1:10808'
$agExe = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
$lsLog = Join-Path $env:APPDATA 'Antigravity\logs\language_server.log'

function Get-AgyProcs {
    @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        (($_.ExecutablePath) -and ($_.ExecutablePath -match 'Antigravity')) -or
        ($_.Name -eq 'Antigravity.exe') -or ($_.Name -eq 'language_server.exe')
    })
}

L '--- desktop Antigravity fix v4 (deterministic env delivery) ---'

# ================= A. current state =================
$elev = $false
try { $elev = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch { }
L ('   A: elevated session: ' + $elev)

$procs0 = Get-AgyProcs
L ('   A: current processes: ' + $procs0.Count)
foreach ($p in $procs0) {
    $st = '?'
    try { $st = $p.CreationDate.ToString('HH:mm:ss') } catch { }
    L ('      pid=' + $p.ProcessId + ' ppid=' + $p.ParentProcessId + ' start=' + $st + ' ' + (San ([string]$p.Name)))
    $cl = (San ([string]$p.CommandLine))
    if ($cl.Length -gt 300) { $cl = $cl.Substring(0, 300) + '...' }
    L ('         cmd: ' + $cl)
}
try { L ('   A: exe version: ' + (San ([string](Get-Item -LiteralPath $agExe).VersionInfo.ProductVersion))) } catch { }

try {
    $rk = Get-ItemProperty -Path 'HKCU:\Environment' -ErrorAction Stop
    L ('   A: HKCU env: HTTP_PROXY=' + (San ([string]$rk.HTTP_PROXY)) + ' HTTPS_PROXY=' + (San ([string]$rk.HTTPS_PROXY)) + ' NO_PROXY=' + (San ([string]$rk.NO_PROXY)))
} catch { L '   A: HKCU env read failed' }

foreach ($app in @('Antigravity', 'Antigravity IDE')) {
    $sf = Join-Path $env:APPDATA ($app + '\User\settings.json')
    if (Test-Path -LiteralPath $sf) {
        $raw = ''
        try { $raw = [IO.File]::ReadAllText($sf) } catch { }
        $ok = 'INVALID JSON'
        $keys = ''
        try {
            $j = $raw | ConvertFrom-Json
            $ok = 'valid'
            foreach ($pr in $j.PSObject.Properties) { if ($pr.Name -like 'http.*') { $keys += ($pr.Name + '=' + (San ([string]$pr.Value)) + ' ') } }
        } catch { }
        L ('   A: ' + $app + ' settings.json: ' + $ok + ' ' + $keys.Trim())
    } else { L ('   A: ' + $app + ' settings.json: MISSING') }
}

$mainLog = Join-Path $env:APPDATA 'Antigravity\logs\main.log'
if (Test-Path -LiteralPath $mainLog) {
    $ml = @(Get-Content -LiteralPath $mainLog -Tail 400 -ErrorAction SilentlyContinue | Where-Object { $_ -match 'proxy' } | Select-Object -Last 5)
    L ('   A: main.log proxy mentions (tail400): ' + $ml.Count)
    foreach ($m in $ml) { L ('      ' + (San ([string]$m).Trim())) }
}

try {
    $code = & curl.exe -x $proxy -s -o NUL -w '%{http_code}' --max-time 20 'https://daily-cloudcode-pa.googleapis.com/' 2>$null
    L ('   A: curl via proxy -> daily-cloudcode-pa: HTTP ' + (San ([string]$code)))
} catch { L '   A: curl test failed' }

# ================= B. fixes =================
$wrapper = 'F:\fig1_rebuild\agy_proxy.cmd'
$w = New-Object System.Collections.Generic.List[string]
$w.Add('@echo off')
$w.Add('echo %DATE% %TIME% agy_proxy wrapper invoked >> F:\fig1_rebuild\agy_launch.log')
$w.Add('set HTTP_PROXY=http://127.0.0.1:10808')
$w.Add('set HTTPS_PROXY=http://127.0.0.1:10808')
$w.Add('set ALL_PROXY=http://127.0.0.1:10808')
$w.Add('set NO_PROXY=localhost,127.0.0.1')
$w.Add('set http_proxy=http://127.0.0.1:10808')
$w.Add('set https_proxy=http://127.0.0.1:10808')
$w.Add('set no_proxy=localhost,127.0.0.1')
$w.Add('set | findstr /i "proxy" > F:\fig1_rebuild\agy_env_snapshot.txt')
$w.Add(('start "" "{0}"' -f $agExe))
try {
    [IO.File]::WriteAllLines($wrapper, $w.ToArray(), (New-Object System.Text.ASCIIEncoding))
    $back = @([IO.File]::ReadAllLines($wrapper))
    $bad = 0
    if ($back.Count -ne $w.Count) { $bad = 1 }
    else {
        for ($i = 0; $i -lt $w.Count; $i++) {
            if ([string]$back[$i] -ne [string]$w[$i]) { $bad = 1; L ('   B: wrapper MISMATCH line ' + ($i + 1) + ': [' + (San ([string]$back[$i])) + ']') }
        }
    }
    L ('   B: wrapper written (11 lines) + read-back: ' + $(if ($bad -eq 0) { 'EXACT MATCH' } else { 'MISMATCH' }))
} catch { L ('   B: wrapper write FAILED: ' + (San $_.Exception.Message)) }

foreach ($app in @('Antigravity', 'Antigravity IDE')) {
    $userDir = Join-Path $env:APPDATA ($app + '\User')
    $sf = Join-Path $userDir 'settings.json'
    try {
        New-Item -ItemType Directory -Force -Path $userDir | Out-Null
        $h = @{}
        if (Test-Path -LiteralPath $sf) {
            try { (Get-Content -LiteralPath $sf -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $h[$_.Name] = $_.Value } } catch { }
        }
        $h['http.proxy'] = $proxy
        $h['http.proxySupport'] = 'on'
        $h['http.noProxy'] = 'localhost,127.0.0.1'
        [IO.File]::WriteAllText($sf, ($h | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
        $null = Get-Content -LiteralPath $sf -Raw | ConvertFrom-Json
        L ('   B: ' + $app + ' settings.json written + JSON valid')
    } catch { L ('   B: ' + $app + ' settings.json FAILED: ' + (San $_.Exception.Message)) }
}

try {
    & setx HTTP_PROXY $proxy | Out-Null
    & setx HTTPS_PROXY $proxy | Out-Null
    & setx NO_PROXY 'localhost,127.0.0.1' | Out-Null
    $rk2 = Get-ItemProperty -Path 'HKCU:\Environment'
    L ('   B: setx user env verified (registry): HTTP_PROXY=' + (San ([string]$rk2.HTTP_PROXY)) + ' HTTPS_PROXY=' + (San ([string]$rk2.HTTPS_PROXY)))
} catch { L ('   B: setx user env failed: ' + (San $_.Exception.Message)) }

if ($elev) {
    try {
        & setx HTTP_PROXY $proxy /M | Out-Null
        & setx HTTPS_PROXY $proxy /M | Out-Null
        & setx NO_PROXY 'localhost,127.0.0.1' /M | Out-Null
        L '   B: machine-level env set (setx /M)'
    } catch { L ('   B: setx /M failed: ' + (San $_.Exception.Message)) }
} else { L '   B: not elevated - skipped setx /M' }

# ================= C. relaunch + prove the chain =================
$killRounds = 0
while ($killRounds -lt 3) {
    $killRounds++
    $a = @(Get-Process -Name Antigravity -ErrorAction SilentlyContinue)
    if ($a.Count -gt 0) { try { & taskkill /f /im Antigravity.exe 2>&1 | Out-Null } catch { } }
    $lsp = @(Get-Process -Name language_server -ErrorAction SilentlyContinue)
    if ($lsp.Count -gt 0) { try { & taskkill /f /im language_server.exe 2>&1 | Out-Null } catch { } }
    Start-Sleep -Seconds 5
    $a = @(Get-Process -Name Antigravity -ErrorAction SilentlyContinue)
    $lsp = @(Get-Process -Name language_server -ErrorAction SilentlyContinue)
    if ($a.Count -eq 0 -and $lsp.Count -eq 0) { break }
}
$aL = @(Get-Process -Name Antigravity -ErrorAction SilentlyContinue).Count
$lL = @(Get-Process -Name language_server -ErrorAction SilentlyContinue).Count
L ('   C: kill rounds=' + $killRounds + ' remaining: Antigravity=' + $aL + ' language_server=' + $lL)

try {
    Start-ScheduledTask -TaskName 'agyrelaunch'
    L '   C: agyrelaunch task started'
} catch { L ('   C: [FAIL] start task: ' + (San $_.Exception.Message)); exit 2 }

$bootAt = $null
for ($i = 0; $i -lt 16; $i++) {
    Start-Sleep -Seconds 5
    $a = @(Get-Process -Name Antigravity -ErrorAction SilentlyContinue | Sort-Object StartTime)
    if ($a.Count -gt 0) { $bootAt = $a[0].StartTime; break }
}
$ti = Get-ScheduledTaskInfo -TaskName 'agyrelaunch' -ErrorAction SilentlyContinue
L ('   C: task LastRunTime=' + $(if ($ti -and $ti.LastRunTime) { $ti.LastRunTime.ToString('HH:mm:ss') } else { '?' }) + '  first process start=' + $(if ($bootAt) { $bootAt.ToString('HH:mm:ss') } else { 'NONE within 80s' }))

$snap = 'F:\fig1_rebuild\agy_env_snapshot.txt'
if (Test-Path -LiteralPath $snap) {
    L '   C: wrapper env snapshot (at launch):'
    foreach ($s in @(Get-Content -LiteralPath $snap)) { L ('      ' + (San $s)) }
} else { L '   C: [WARN] wrapper env snapshot missing - wrapper did not run!' }
$llog = 'F:\fig1_rebuild\agy_launch.log'
if (Test-Path -LiteralPath $llog) {
    L ('   C: wrapper invoke log (tail 3):')
    foreach ($s in @(Get-Content -LiteralPath $llog -Tail 3)) { L ('      ' + (San $s)) }
}

$lsProc = $null
for ($i = 0; $i -lt 18; $i++) {
    $lsp = @(Get-Process -Name language_server -ErrorAction SilentlyContinue)
    if ($lsp.Count -gt 0) { $lsProc = @($lsp | Sort-Object StartTime)[0]; break }
    Start-Sleep -Seconds 5
}
if ($lsProc) {
    $cl = ''
    try { $cl = (San ([string](Get-CimInstance Win32_Process -Filter ('ProcessId=' + $lsProc.Id)).CommandLine)) } catch { }
    if ($cl.Length -gt 300) { $cl = $cl.Substring(0, 300) + '...' }
    L ('   C: language_server pid=' + $lsProc.Id + ' start=' + $lsProc.StartTime.ToString('HH:mm:ss'))
    L ('      cmd: ' + $cl)
} else { L '   C: [WARN] language_server not seen within 90s' }

function Probe-Tcp {
    $pc = 0; $d4 = 0; $ips = ''
    foreach ($p in (Get-AgyProcs)) {
        foreach ($c in @(Get-NetTCPConnection -OwningProcess $p.ProcessId -ErrorAction SilentlyContinue)) {
            $ra = [string]$c.RemoteAddress
            if ($ra -eq '127.0.0.1' -and $c.RemotePort -eq 10808) { $pc++ }
            elseif ($c.RemotePort -eq 443 -and $ra -notmatch '^127\.') { $d4++; if ($ips.Length -lt 150) { $ips += ($ra + '[' + $c.State + '] ') } }
        }
    }
    L ('   C: TCP probe: to-proxy=' + $pc + ' direct-443=' + $d4 + ' ' + $ips.Trim())
}

function Fresh-LsLines($since) {
    $out = @()
    if (-not (Test-Path -LiteralPath $lsLog)) { return ,@() }
    foreach ($ln in @(Get-Content -LiteralPath $lsLog -ErrorAction SilentlyContinue)) {
        if ($ln -match '([EWIF]\d{4}) (\d{2}):(\d{2}):(\d{2})') {
            $md = $Matches[1].Substring(1)
            try {
                $t2 = Get-Date -Month ([int]$md.Substring(0, 2)) -Day ([int]$md.Substring(2, 2)) -Hour ([int]$Matches[2]) -Minute ([int]$Matches[3]) -Second ([int]$Matches[4])
                if ($t2 -ge $since) { $out += $ln }
            } catch { }
        }
    }
    return ,@($out)
}

Start-Sleep -Seconds 20
Probe-Tcp | Out-Null
if ($bootAt) {
    $fresh = @(Fresh-LsLines $bootAt)
    $fd = @($fresh | Where-Object { $_ -match 'dial tcp' })
    $fg = @($fresh | Where-Object { $_ -match 'record with version 15' })
    $fh = @($fresh | Where-Object { $_ -match '401|403|Unauthenticated|Permission' })
    $init = @($fresh | Where-Object { $_ -match 'initialized server successfully in' } | Select-Object -Last 1)
    L ('   C: ls.log fresh (1st): lines=' + $fresh.Count + ' dial-tcp=' + $fd.Count + ' tls-garbage=' + $fg.Count + ' http-status/auth=' + $fh.Count)
    if ($init) { L ('      init: ' + (San ([string]$init).Trim())) }
    foreach ($s in (@($fresh) | Select-Object -Last 4)) { L ('      ' + (San ([string]$s).Trim())) }
}

L '   C: waiting 45s for second sample...'
Start-Sleep -Seconds 45
Probe-Tcp | Out-Null
if ($bootAt) {
    $fresh2 = @(Fresh-LsLines $bootAt)
    $fd2 = @($fresh2 | Where-Object { $_ -match 'dial tcp' })
    $fh2 = @($fresh2 | Where-Object { $_ -match '401|403|Unauthenticated|Permission' })
    $init2 = @($fresh2 | Where-Object { $_ -match 'initialized server successfully in' } | Select-Object -Last 1)
    L ('   C: ls.log fresh (2nd): lines=' + $fresh2.Count + ' dial-tcp=' + $fd2.Count + ' http-status/auth=' + $fh2.Count)
    if ($init2) { L ('      init: ' + (San ([string]$init2).Trim())) }
    if ($fresh2.Count -gt 0 -and $fd2.Count -eq 0) { L '   C: VERDICT: dial-tcp=0 after verified-wrapper relaunch - proxy chain OK' }
    elseif ($fd2.Count -gt 0) { L ('   C: VERDICT: still direct-dialing (' + $fd2.Count + ' lines) - env not reaching the language server' }
    else { L '   C: VERDICT: no fresh LS lines yet - inconclusive, recheck later' }
} else { L '   C: VERDICT: relaunch failed - no processes' }
L '--- desktop fix v4 done ---'
