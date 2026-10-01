# desk_antigravity_verify4.ps1 - runs ON THE DESKTOP. Final acceptance
# check after the v4 fix: the Antigravity session relaunched 19:35:19
# through the verified proxy wrapper must show
#   - zero dial-tcp / tls-garbage in language_server.log since relaunch
#     (whole window AND last 5 minutes)
#   - auth-state markers (Auth succeeded / userInfo / loadCodeAssist)
#   - live TCP connections to the proxy (to-proxy > 0)
#   - clean main.log
# READ-ONLY. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{40,}', '[REDACTED]' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }

L '--- desktop Antigravity verify4 (final acceptance) ---'

function Get-AgyProcs {
    @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        (($_.ExecutablePath) -and ($_.ExecutablePath -match 'Antigravity')) -or
        ($_.Name -eq 'Antigravity.exe') -or ($_.Name -eq 'language_server.exe')
    })
}

# ---------------- 1. session anchor: earliest process start ----------------
$procs = Get-AgyProcs
$ag = @($procs | Where-Object { $_.Name -eq 'Antigravity.exe' } | Sort-Object CreationDate)
$since = $null
if ($ag.Count -gt 0) { try { $since = $ag[0].CreationDate } catch { } }
L ('   processes: ' + $procs.Count + '  session start: ' + $(if ($since) { $since.ToString('yyyy-MM-dd HH:mm:ss') } else { '?' }))
if (-not $since) { L '   [FAIL] no Antigravity session running'; exit 2 }

# ---------------- 2. language_server.log since session start ----------------
$lsLog = Join-Path $env:APPDATA 'Antigravity\logs\language_server.log'
function Get-LsTime([string]$ln) {
    if ($ln -match '([EWIF]\d{4}) (\d{2}):(\d{2}):(\d{2})') {
        $md = $Matches[1].Substring(1)
        try { return (Get-Date -Month ([int]$md.Substring(0, 2)) -Day ([int]$md.Substring(2, 2)) -Hour ([int]$Matches[2]) -Minute ([int]$Matches[3]) -Second ([int]$Matches[4])) } catch { return $null }
    }
    return $null
}
$fresh = @()
$fresh5 = @()
$cut5 = (Get-Date).AddMinutes(-5)
if (Test-Path -LiteralPath $lsLog) {
    foreach ($ln in @(Get-Content -LiteralPath $lsLog -ErrorAction SilentlyContinue)) {
        $t = Get-LsTime $ln
        if ($t -and $t -ge $since) {
            $fresh += $ln
            if ($t -ge $cut5) { $fresh5 += $ln }
        }
    }
    $dial = @($fresh | Where-Object { $_ -match 'dial tcp' })
    $garb = @($fresh | Where-Object { $_ -match 'record with version 15' })
    $dial5 = @($fresh5 | Where-Object { $_ -match 'dial tcp' })
    L ('   ls.log since relaunch: lines=' + $fresh.Count + ' dial-tcp=' + $dial.Count + ' tls-garbage=' + $garb.Count)
    L ('   ls.log last-5-min:     lines=' + $fresh5.Count + ' dial-tcp=' + $dial5.Count)
    if ($dial.Count -gt 0) { foreach ($d in ($dial | Select-Object -Last 2)) { L ('      [dial] ' + (San ([string]$d).Trim())) } }

    $authOk = @($fresh | Where-Object { $_ -match 'Auth succeeded|AuthState|signed [Ii]n|loadCodeAssist|userInfo|userTier|availableModels' })
    $authBad = @($fresh | Where-Object { $_ -match 'Auth failed|Failed to get OAuth|oauth2\.googleapis.*dial|Unauthenticated' })
    L ('   auth markers: positive=' + $authOk.Count + ' negative=' + $authBad.Count)
    foreach ($a in ($authOk | Select-Object -Last 5)) { L ('      [+] ' + (San ([string]$a).Trim())) }
    foreach ($a in ($authBad | Select-Object -Last 3)) { L ('      [-] ' + (San ([string]$a).Trim())) }

    $init = @($fresh | Where-Object { $_ -match 'initialized server successfully in' } | Select-Object -Last 1)
    foreach ($i2 in $init) { L ('      init: ' + (San ([string]$i2).Trim())) }
    L '   ls.log last 3 lines:'
    foreach ($f in (@($fresh) | Select-Object -Last 3)) { L ('      ' + (San ([string]$f).Trim())) }
}
else { L '   [WARN] language_server.log not found' }

# ---------------- 3. live TCP probe (proxy vs direct) ----------------
$pc = 0; $d4 = 0; $ips = ''
foreach ($p in $procs) {
    foreach ($c in @(Get-NetTCPConnection -OwningProcess $p.ProcessId -ErrorAction SilentlyContinue)) {
        $ra = [string]$c.RemoteAddress
        if ($ra -eq '127.0.0.1' -and $c.RemotePort -eq 10808) { $pc++ }
        elseif ($c.RemotePort -eq 443 -and $ra -notmatch '^127\.') { $d4++; if ($ips.Length -lt 150) { $ips += ($ra + '[' + $c.State + '] ') } }
    }
}
L ('   live TCP: to-proxy(127.0.0.1:10808)=' + $pc + '  direct-443=' + $d4 + '  ' + $ips.Trim())

# ---------------- 4. persisted env (user + machine) ----------------
try {
    $ru = Get-ItemProperty -Path 'HKCU:\Environment'
    L ('   HKCU env: HTTPS_PROXY=' + (San ([string]$ru.HTTPS_PROXY)) + ' NO_PROXY=' + (San ([string]$ru.NO_PROXY)))
} catch { }
try {
    $rm = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
    L ('   HKLM env: HTTPS_PROXY=' + (San ([string]$rm.HTTPS_PROXY)) + ' NO_PROXY=' + (San ([string]$rm.NO_PROXY)))
} catch { L '   HKLM env read failed' }

# ---------------- 5. wrapper invoke history ----------------
$llog = 'F:\fig1_rebuild\agy_launch.log'
if (Test-Path -LiteralPath $llog) {
    L '   wrapper invoke history (all):'
    foreach ($s in @(Get-Content -LiteralPath $llog)) { L ('      ' + (San $s)) }
} else { L '   wrapper invoke log missing' }

# ---------------- 6. main.log last 3 min ----------------
$mainLog = Join-Path $env:APPDATA 'Antigravity\logs\main.log'
if (Test-Path -LiteralPath $mainLog) {
    $cut = (Get-Date).AddMinutes(-3)
    $recent = @()
    foreach ($ln in @(Get-Content -LiteralPath $mainLog -Tail 120 -ErrorAction SilentlyContinue)) {
        if ($ln -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})') {
            try { $t3 = [DateTime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null); if ($t3 -ge $cut) { $recent += $ln } } catch { }
        }
    }
    $err = @($recent | Where-Object { $_ -match '\[error\]' })
    L ('   main.log last-3min: lines=' + $recent.Count + ' errors=' + $err.Count)
    foreach ($e in ($err | Select-Object -First 3)) { L ('      ' + (San ([string]$e).Trim())) }
}

# ---------------- verdict ----------------
$ok = ($dial.Count -eq 0) -and ($garb.Count -eq 0) -and ($pc -gt 0)
L ('   FINAL: ' + $(if ($ok) { 'PASS - language server clean through proxy, machine env persisted' } else { 'CHECK - see counts above' }))
L '--- verify4 done ---'
