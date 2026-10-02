# desk_antigravity_agent_error.ps1 - runs ON THE DESKTOP via ssh.
# Diagnose and refresh Antigravity agent/proxy state after the UI shows
# "Agent execution terminated due to error". ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{40,}', '[REDACTED]' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m; $script:Report += $m }
function TailLines([string]$path, [int]$n) {
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    return @(Get-Content -LiteralPath $path -Tail $n -ErrorAction SilentlyContinue)
}
function AddRecentMatches([string]$label, [string]$path, [string]$pattern) {
    if (-not (Test-Path -LiteralPath $path)) { return }
    $hits = @(Select-String -Path $path -Pattern $pattern -SimpleMatch:$false -ErrorAction SilentlyContinue | Select-Object -Last 20)
    L ('   ' + $label + ': hits=' + $hits.Count + ' file=' + $path)
    foreach ($h in ($hits | Select-Object -Last 8)) { L ('      L' + $h.LineNumber + ' ' + (San $h.Line.Trim())) }
}

$script:Report = @()
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = 'F:\fig1_rebuild\agy_agent_diag_r172.md'
$proxy = 'http://127.0.0.1:10808'

L '# Antigravity agent-error desktop diagnostic r172'
L ('time: ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer: ' + $env:COMPUTERNAME + ' user: ' + $env:USERNAME)

# 1. Persist proxy variables again. This is the safe fix for the known failure
# mode where Go helpers do not inherit Electron/system proxy settings.
L '## proxy persistence refresh'
try {
    [Environment]::SetEnvironmentVariable('HTTP_PROXY', $proxy, 'User')
    [Environment]::SetEnvironmentVariable('HTTPS_PROXY', $proxy, 'User')
    [Environment]::SetEnvironmentVariable('ALL_PROXY', $proxy, 'User')
    [Environment]::SetEnvironmentVariable('NO_PROXY', 'localhost,127.0.0.1,::1', 'User')
    $env:HTTP_PROXY = $proxy; $env:HTTPS_PROXY = $proxy; $env:ALL_PROXY = $proxy; $env:NO_PROXY = 'localhost,127.0.0.1,::1'
    L '   HKCU/env proxy set: OK'
} catch { L ('   HKCU/env proxy set: FAIL ' + (San $_.Exception.Message)) }
try {
    [Environment]::SetEnvironmentVariable('HTTP_PROXY', $proxy, 'Machine')
    [Environment]::SetEnvironmentVariable('HTTPS_PROXY', $proxy, 'Machine')
    [Environment]::SetEnvironmentVariable('ALL_PROXY', $proxy, 'Machine')
    [Environment]::SetEnvironmentVariable('NO_PROXY', 'localhost,127.0.0.1,::1', 'Machine')
    L '   HKLM proxy set: OK'
} catch { L ('   HKLM proxy set: WARN ' + (San $_.Exception.Message)) }

# 2. Settings files for Electron/network stack.
L '## Antigravity settings refresh'
$settingsRoots = @(
    (Join-Path $env:APPDATA 'Antigravity\User'),
    (Join-Path $env:APPDATA 'Antigravity IDE\User')
)
foreach ($root in $settingsRoots) {
    try {
        New-Item -ItemType Directory -Force -Path $root | Out-Null
        $sp = Join-Path $root 'settings.json'
        $obj = @{}
        if (Test-Path -LiteralPath $sp) {
            try { $obj = Get-Content -LiteralPath $sp -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $obj = @{} }
        }
        if (-not ($obj -is [pscustomobject])) { $obj = [pscustomobject]@{} }
        $obj | Add-Member -NotePropertyName 'http.proxy' -NotePropertyValue $proxy -Force
        $obj | Add-Member -NotePropertyName 'http.proxySupport' -NotePropertyValue 'on' -Force
        $obj | Add-Member -NotePropertyName 'http.noProxy' -NotePropertyValue @('localhost','127.0.0.1','::1') -Force
        $json = $obj | ConvertTo-Json -Depth 8
        [IO.File]::WriteAllText($sp, $json + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
        L ('   settings OK: ' + $sp)
    } catch { L ('   settings FAIL: ' + $root + ' ' + (San $_.Exception.Message)) }
}

# 3. Wrapper. Existing start-menu links may bypass it, but it gives one clean
# launch path and proves the helper env is present.
L '## wrapper refresh'
$agyExe = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
$wrap = 'F:\fig1_rebuild\agy_proxy.cmd'
if (Test-Path -LiteralPath $agyExe) {
    $cmd = @(
        '@echo off',
        'set HTTP_PROXY=http://127.0.0.1:10808',
        'set HTTPS_PROXY=http://127.0.0.1:10808',
        'set ALL_PROXY=http://127.0.0.1:10808',
        'set NO_PROXY=localhost,127.0.0.1,::1',
        'set http_proxy=http://127.0.0.1:10808',
        'set https_proxy=http://127.0.0.1:10808',
        'echo %DATE% %TIME% agy_proxy launch>>F:\fig1_rebuild\agy_launch.log',
        'set > F:\fig1_rebuild\agy_env_snapshot.txt',
        'start "" "' + $agyExe + '"'
    )
    [IO.File]::WriteAllLines($wrap, $cmd, (New-Object System.Text.ASCIIEncoding))
    L ('   wrapper OK: ' + $wrap)
} else { L ('   wrapper skipped, missing exe: ' + $agyExe) }

# 4. Network probes.
L '## network probes'
try {
    $tnc = Test-NetConnection 127.0.0.1 -Port 10808 -WarningAction SilentlyContinue
    L ('   local proxy port 10808: ' + $tnc.TcpTestSucceeded)
} catch { L ('   local proxy probe failed: ' + (San $_.Exception.Message)) }
$curl = Get-Command curl.exe -ErrorAction SilentlyContinue
if ($curl) {
    foreach ($url in @('https://daily-cloudcode-pa.googleapis.com/', 'https://oauth2.googleapis.com/', 'https://jetski-webchannel.googleapis.com/')) {
        try {
            $o = & curl.exe -I -L --max-time 20 --proxy $proxy $url 2>&1 | Out-String
            $head = (($o -split "`r?`n") | Where-Object { $_ -match 'HTTP/' } | Select-Object -Last 1)
            if (-not $head) { $head = (($o -split "`r?`n") | Select-Object -Last 1) }
            L ('   curl proxy ' + $url + ' -> ' + (San $head.Trim()))
        } catch { L ('   curl proxy ' + $url + ' -> FAIL ' + (San $_.Exception.Message)) }
    }
} else { L '   curl.exe missing' }

# 5. Processes and logs before/after a controlled refresh.
function DumpState([string]$tag) {
    L ('## state ' + $tag)
    $procs = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        (($_.ExecutablePath) -and ($_.ExecutablePath -match 'Antigravity')) -or
        ($_.Name -eq 'Antigravity.exe') -or ($_.Name -eq 'language_server.exe')
    } | Sort-Object Name, ProcessId)
    L ('   processes: ' + $procs.Count)
    foreach ($p in ($procs | Select-Object -First 12)) {
        L ('      pid=' + $p.ProcessId + ' name=' + $p.Name + ' path=' + (San $p.ExecutablePath))
    }
    $pc = 0; $d4 = 0
    foreach ($p in $procs) {
        foreach ($c in @(Get-NetTCPConnection -OwningProcess $p.ProcessId -ErrorAction SilentlyContinue)) {
            $ra = [string]$c.RemoteAddress
            if ($ra -eq '127.0.0.1' -and $c.RemotePort -eq 10808) { $pc++ }
            elseif ($c.RemotePort -eq 443 -and $ra -notmatch '^127\.') { $d4++ }
        }
    }
    L ('   tcp: to_proxy=' + $pc + ' direct_443=' + $d4)

    $logRoots = @((Join-Path $env:APPDATA 'Antigravity\logs'), (Join-Path $env:APPDATA 'Antigravity IDE\logs'))
    foreach ($lr in $logRoots) {
        if (-not (Test-Path -LiteralPath $lr)) { L ('   logs missing: ' + $lr); continue }
        L ('   logs: ' + $lr)
        foreach ($lf in @(Get-ChildItem -LiteralPath $lr -File -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 10)) {
            L ('      file ' + $lf.Name + ' ' + $lf.LastWriteTime.ToString('HH:mm:ss') + ' ' + [math]::Round($lf.Length/1KB) + 'KB')
        }
        $pat = 'Agent execution terminated|terminated due to error|\[error\]|Error:|panic|exception|quota|429|401|403|Unauthenticated|Failed to get OAuth|dial tcp|record with version 15|ECONN|ETIMEDOUT|ENOTFOUND|language_server|mcp|tool'
        foreach ($lf in @(Get-ChildItem -LiteralPath $lr -File -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 8)) {
            AddRecentMatches ($tag + ' ' + $lf.Name) $lf.FullName $pat
        }
    }
}

DumpState 'before'

L '## controlled relaunch'
try {
    foreach ($n in @('language_server','Antigravity')) { & taskkill /f /im ($n + '.exe') 2>&1 | Out-Null }
    Start-Sleep -Seconds 4
    if (Test-Path -LiteralPath $wrap) {
        Start-Process -FilePath $wrap -WindowStyle Hidden
        L '   relaunched through wrapper'
    } elseif (Test-Path -LiteralPath $agyExe) {
        Start-Process -FilePath $agyExe
        L '   relaunched direct exe (wrapper missing)'
    } else { L '   relaunch skipped, exe missing' }
} catch { L ('   relaunch WARN ' + (San $_.Exception.Message)) }
Start-Sleep -Seconds 25
DumpState 'after'

# 6. Verdict. The browser working but IDE agent failing most often means the
# IDE helper process is not using the browser/system proxy. If the after-state
# has proxy TCP connections and no fresh dial/tls errors, the network layer is
# repaired; remaining terminations are likely account/quota/model/extension log
# errors shown above.
$txt = ($script:Report -join "`n")
$hasTerm = ($txt -match 'Agent execution terminated|terminated due to error')
$hasProxy = ($txt -match 'tcp: to_proxy=[1-9]')
$hasDial = ($txt -match 'dial tcp|record with version 15')
if ($hasProxy -and -not $hasDial) { L 'FINAL: AGY_NETWORK_LAYER_OK proxy path active; inspect termination/error lines above if UI still fails.' }
elseif ($hasDial) { L 'FINAL: AGY_NETWORK_LAYER_STILL_BAD direct dial/tls errors remain.' }
else { L 'FINAL: AGY_DIAG_DONE no proxy connection yet; open a new chat and rerun if needed.' }
if ($hasTerm) { L 'FINAL_DETAIL: termination marker found in logs.' } else { L 'FINAL_DETAIL: no exact termination marker found in scanned logs.' }

try { [IO.File]::WriteAllText($reportPath, ($script:Report -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) } catch { }
L ('report: ' + $reportPath)
exit 0
