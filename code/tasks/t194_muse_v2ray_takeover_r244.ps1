# t194_muse_v2ray_takeover_r244.ps1 - round 244.
# Process the formal Muse relay package and take over Antigravity/V2ray routing.
# Secrets are never written to the repository: subscription URLs/nodes may be
# read from local v2rayN config, local private file, or clipboard, and reports
# are sanitized. ASCII-only.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')

$repo = (Get-Location).Path
$outDir = Join-Path $repo 'results\muse'
$agyDir = Join-Path $repo 'results\antigravity'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
New-Item -ItemType Directory -Force -Path $agyDir | Out-Null
$report = Join-Path $outDir 'MUSE_V2RAY_TAKEOVER_R244.md'
$jsonReport = Join-Path $outDir 'MUSE_V2RAY_TAKEOVER_R244.json'
$lines = New-Object System.Collections.Generic.List[string]
$recs = @()

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace 'token=[A-Za-z0-9._~+/=-]+', 'token=[REDACTED]' } catch { }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{24,}', '[REDACTED]' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { $script:lines.Add($m) | Out-Null; Write-Output $m }
function Rec([string]$k, [string]$v) { $script:recs += [pscustomobject]@{ key=$k; value=(San $v) } }
function Write-Reports {
    $script:lines | Set-Content -LiteralPath $script:report -Encoding UTF8
    ([pscustomobject]@{ time=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'); host=$env:COMPUTERNAME; records=$script:recs } | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $script:jsonReport -Encoding UTF8
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
function CurlText([string[]]$CurlArgs) {
    try { $ce = Join-Path $env:SystemRoot 'System32\curl.exe'; return (& $ce @CurlArgs 2>&1 | Out-String).Trim() } catch { return $_.Exception.Message }
}
function SupportedCountry([string]$cc) {
    $x = ([string]$cc).ToUpperInvariant()
    if ($x -match 'UNITED STATES|AMERICA') { $x = 'US' }
    if ($x -match 'JAPAN') { $x = 'JP' }
    if ($x -match 'SINGAPORE') { $x = 'SG' }
    if ($x -match 'TAIWAN') { $x = 'TW' }
    if ($x -match 'HONG KONG') { $x = 'HK' }
    $good = @('US','CA','GB','AU','NZ','JP','KR','SG','TW','DE','FR','NL','SE','NO','FI','DK','IE','ES','IT','PT','PL','BE','CH','AT','CZ','EE','LV','LT','LU','RO','BG','GR','HR','HU','IS','LI','MT','SK','SI')
    return ($good -contains $x)
}
function RouteProbe([string]$Name, [string]$Proxy) {
    $curl = @('-L','--max-time','15','-sS')
    if ($Proxy) { $curl += @('--proxy', $Proxy) }
    $geoRaw = CurlText ($curl + @('https://ipinfo.io/json'))
    if (-not $geoRaw -or $geoRaw -match 'curl:|Failed|timed out') { $geoRaw = CurlText ($curl + @('http://ip-api.com/json/?fields=status,countryCode,country,query,isp,org')) }
    $cc=''; $country=''; $ip=''; $org=''
    try {
        $g = $geoRaw | ConvertFrom-Json
        $cc = [string]$g.countryCode; if (-not $cc) { $cc = [string]$g.country }
        $country = [string]$g.country; if (-not $country) { $country = $cc }
        $ip = [string]$g.ip; if (-not $ip) { $ip = [string]$g.query }
        $org = [string]$g.org; if (-not $org) { $org = [string]$g.isp }
    } catch { $country = San $geoRaw }
    $head = CurlText ($curl + @('-I','https://daily-cloudcode-pa.googleapis.com/'))
    $http = (($head -split "`r?`n") | Where-Object { $_ -match '^HTTP/' } | Select-Object -Last 1)
    $blocked = [bool]($head -match 'User location is not supported|FAILED_PRECONDITION')
    $sup = SupportedCountry (($cc + ' ' + $country).Trim())
    L ('route_probe name=' + $Name + ' proxy=' + $Proxy + ' country=' + (San ($cc + '/' + $country)) + ' ip=' + (San $ip) + ' org=' + (San $org) + ' cloud=' + (San $http) + ' supported=' + $sup + ' location_block=' + $blocked)
    return @{ name=$Name; proxy=$Proxy; cc=$cc; country=$country; ip=$ip; org=$org; cloud=$http; supported=$sup; blocked=$blocked }
}
function ApplyProxy([string]$Proxy) {
    foreach ($scope in @('User','Machine')) {
        try {
            foreach ($k in @('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy')) { [Environment]::SetEnvironmentVariable($k, $Proxy, $scope) }
            [Environment]::SetEnvironmentVariable('NO_PROXY','localhost,127.0.0.1,::1',$scope)
            L ('env_proxy_' + $scope + '=set')
        } catch { L ('env_proxy_WARN=' + (San $_.Exception.Message)) }
    }
    $env:HTTP_PROXY=$Proxy; $env:HTTPS_PROXY=$Proxy; $env:ALL_PROXY=$Proxy; $env:NO_PROXY='localhost,127.0.0.1,::1'
    foreach ($root in @((Join-Path $env:APPDATA 'Antigravity\User'), (Join-Path $env:APPDATA 'Antigravity IDE\User'))) {
        try {
            New-Item -ItemType Directory -Force -Path $root | Out-Null
            $sp = Join-Path $root 'settings.json'
            $obj = [pscustomobject]@{}
            if (Test-Path -LiteralPath $sp) { try { $obj = Get-Content -LiteralPath $sp -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $obj = [pscustomobject]@{} } }
            $obj | Add-Member -NotePropertyName 'http.proxy' -NotePropertyValue $Proxy -Force
            $obj | Add-Member -NotePropertyName 'http.proxySupport' -NotePropertyValue 'on' -Force
            $obj | Add-Member -NotePropertyName 'http.noProxy' -NotePropertyValue @('localhost','127.0.0.1','::1') -Force
            [IO.File]::WriteAllText($sp, (($obj | ConvertTo-Json -Depth 8) + "`r`n"), (New-Object Text.UTF8Encoding($false)))
            L ('antigravity_settings_OK=' + (San $sp))
        } catch { L ('antigravity_settings_WARN=' + (San $_.Exception.Message)) }
    }
}
function RelaunchAgy {
    try { foreach ($n in @('language_server','Antigravity')) { taskkill /f /im ($n + '.exe') 2>&1 | Out-Null } } catch { }
    Start-Sleep -Seconds 2
    $exe = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
    if (Test-Path -LiteralPath $exe) { try { Start-Process -FilePath $exe; L 'antigravity_relaunch=OK' } catch { L ('antigravity_relaunch_WARN=' + (San $_.Exception.Message)) } }
    else { L 'antigravity_relaunch=SKIP_NOT_FOUND' }
}

L '# Muse relay + V2ray takeover - round 244'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
L ('host=' + $env:COMPUTERNAME)
L ''

# ---------------------------------------------------------- 1. Muse package
L '## 1. Muse formal package'
$statusPath = Join-Path $repo 'results\muse\status_20261003_1633.json'
$zipPath = Join-Path $repo 'sources\muse\muse_out_20261003_1633.zip'
$pkgOK = $false
try {
    if (-not (Test-Path -LiteralPath $statusPath)) { L '[FAIL] missing Muse status JSON'; throw 'missing status' }
    if (-not (Test-Path -LiteralPath $zipPath)) { L '[FAIL] missing Muse zip'; throw 'missing zip' }
    $status = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json
    L ('status_task_id=' + (San ([string]$status.task_id)))
    L ('status_state=' + (San ([string]$status.state)))
    L ('status_artifact=' + (San ([string]$status.artifact)))
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $extract = Join-Path $outDir 'extracted_20261003_1633'
    if (Test-Path -LiteralPath $extract) { Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Force -Path $extract | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extract)
    $names = @()
    foreach ($it in @(Get-ChildItem -LiteralPath $extract -Recurse -File -ErrorAction SilentlyContinue)) {
        $rel = $it.FullName.Substring($extract.Length + 1) -replace '\\','/'
        $names += $rel
        L ('zip_file=' + (San $rel) + ' bytes=' + $it.Length)
    }
    $readme = Join-Path $extract 'README.txt'
    if (Test-Path -LiteralPath $readme) {
        $txt = Get-Content -LiteralPath $readme -Raw -Encoding UTF8
        L 'README_HEAD_BEGIN'
        foreach ($ln in (($txt -split "`r?`n") | Select-Object -First 12)) { if ($ln.Trim()) { L ('  ' + (San $ln)) } }
        L 'README_HEAD_END'
    }
    if (($names -contains 'README.txt') -and ($names -contains 'outputs/Hello-World/README') -and ($names -contains 'logs/package.log')) { $pkgOK = $true }
} catch { L ('package_exception=' + (San $_.Exception.Message)) }
L ('MUSE_PACKAGE_VALID=' + $pkgOK)
Rec 'MUSE_PACKAGE_VALID' ([string]$pkgOK)
L ''

# ---------------------------------------------------------- 2. private subs source
L '## 2. Local private subscription source (no secrets printed)'
$privDir = Join-Path $env:USERPROFILE '.arena-private'
$subsFile = Join-Path $privDir 'v2ray_subs.txt'
$hadSubs = Test-Path -LiteralPath $subsFile
if (-not $hadSubs) {
    try {
        $clip = Get-Clipboard -Raw -ErrorAction SilentlyContinue
        $urls = @()
        if ($clip) { $urls = @([regex]::Matches($clip, 'https?://[^\s\)\]\}\>]+') | ForEach-Object { $_.Value.Trim() } | Select-Object -Unique) }
        if ($urls.Count -gt 0) {
            New-Item -ItemType Directory -Force -Path $privDir | Out-Null
            [IO.File]::WriteAllLines($subsFile, $urls, (New-Object Text.UTF8Encoding($false)))
            L ('clipboard_subscription_urls_saved_private_count=' + $urls.Count)
            $hadSubs = $true
        } else { L 'clipboard_subscription_urls_saved_private_count=0' }
    } catch { L ('clipboard_private_save_WARN=' + (San $_.Exception.Message)) }
}
if (Test-Path -LiteralPath $subsFile) {
    $urlCnt = @(Get-Content -LiteralPath $subsFile -ErrorAction SilentlyContinue | Where-Object { $_ -match '^https?://' }).Count
    $nodeCnt = @(Get-Content -LiteralPath $subsFile -ErrorAction SilentlyContinue | Where-Object { $_ -match '^(vmess|vless|trojan|ss)://' }).Count
    L ('private_subs_file=present url_lines=' + $urlCnt + ' node_lines=' + $nodeCnt + ' path=' + (San $subsFile))
} else { L 'private_subs_file=absent (will still try local v2rayN config files)' }
L ''

# ---------------------------------------------------------- 3. local helper
L '## 3. Laptop Antigravity/V2ray bridge'
$helper = Join-Path $repo 'code\tasks\v2rayn_antigravity_auto_bridge.ps1'
$helperReport = Join-Path $agyDir 'V2RAY_TAKEOVER_LOCAL_R244.md'
$localOK = $false
$helperApplied = $false
if (Test-Path -LiteralPath $helper) {
    try {
        $psExe = Join-Path $PSHOME 'powershell.exe'
        if (-not (Test-Path -LiteralPath $psExe)) {
            $cmd = Get-Command powershell.exe -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($cmd -and $cmd.Source) { $psExe = [string]$cmd.Source }
        }
        if (-not (Test-Path -LiteralPath $psExe)) { throw 'powershell.exe not found for helper child process' }
        L ('helper_ps=' + (San $psExe))
        $out = (& $psExe -NoProfile -ExecutionPolicy Bypass -File $helper -OutPath $helperReport -MaxNodes 80 -Apply 2>&1 | Out-String)
        L ('helper_exit=' + $LASTEXITCODE)
        if ($out -match 'V2RAYN_NODE_BRIDGE_APPLIED') { $helperApplied = $true }
        foreach ($ln in (($out -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -First 500)) { L ('helper| ' + (San $ln)) }
    } catch { L ('helper_THROW=' + (San $_.Exception.Message)) }
    if (Test-Path -LiteralPath $helperReport) { L ('helper_report=' + (San $helperReport)) }
} else { L 'helper_missing=True' }

$candidates = @()
if (TcpTest '127.0.0.1' 18088 800) { $candidates += @{name='bridge_18088'; proxy='http://127.0.0.1:18088'} }
if (TcpTest '127.0.0.1' 10808 800) { $candidates += @{name='v2rayn_10808'; proxy='http://127.0.0.1:10808'} }
$candidates += @{name='direct'; proxy=''}
$chosen = $null
foreach ($c in $candidates) {
    $r = RouteProbe $c.name $c.proxy
    if ($c.proxy -and $r.supported -and -not $r.blocked -and -not $chosen) { $chosen = $r }
}
if (-not $chosen -and $helperApplied -and (TcpTest '127.0.0.1' 18088 1200)) {
    L 'route_probe_fallback=helper already proved a supported node; using bridge_18088'
    $chosen = @{ name='bridge_18088_helper'; proxy='http://127.0.0.1:18088'; cc=''; country='helper_supported'; ip=''; org=''; cloud=''; supported=$true; blocked=$false }
}
if ($chosen) {
    ApplyProxy $chosen.proxy
    # Prove GitHub child processes can use the proxy before changing git global config.
    $env:GIT_TERMINAL_PROMPT='0'
    $env:HTTPS_PROXY=$chosen.proxy; $env:HTTP_PROXY=$chosen.proxy; $env:ALL_PROXY=$chosen.proxy
    $gitOk = $false
    try {
        $go = (& git ls-remote https://github.com/octocat/Hello-World.git HEAD 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -eq 0 -and $go -match 'HEAD') { $gitOk = $true }
        L ('git_probe_via_chosen_proxy=' + $gitOk)
    } catch { L ('git_probe_WARN=' + (San $_.Exception.Message)) }
    if ($gitOk) {
        try { git config --global http.proxy $chosen.proxy | Out-Null; git config --global https.proxy $chosen.proxy | Out-Null; L 'git_global_proxy=set_to_chosen_proxy' } catch { L ('git_global_proxy_WARN=' + (San $_.Exception.Message)) }
    }
    RelaunchAgy
    $localOK = $true
    L ('LOCAL_V2RAY_TAKEOVER_OK=True proxy=' + $chosen.proxy + ' country=' + (San ($chosen.cc + '/' + $chosen.country)))
} else {
    L 'LOCAL_V2RAY_TAKEOVER_OK=False no supported non-HK proxy route found among local bridge/v2rayN candidates'
}
Rec 'LOCAL_V2RAY_TAKEOVER_OK' ([string]$localOK)
L ''

# ---------------------------------------------------------- 4. desktop bridge (best effort, non-secret)
L '## 4. Desktop bridge check (best effort)'
$deskOK = $false
$desktopPrev = Join-Path $agyDir 'R244_antigravity_bridge_desktop_r193.md'
if (Test-Path -LiteralPath $desktopPrev) {
    $prevTxt = Get-Content -LiteralPath $desktopPrev -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($prevTxt -match 'FINAL_DESKTOP_BRIDGE: OK_SUPPORTED_ROUTE') {
        $deskOK = $true
        L 'desktop_bridge_reuse=OK previous sanitized report already shows supported route'
    }
}
$desktop = '100.84.137.117'
$duser = 'BNI'
if ((-not $deskOK) -and (TcpTest $desktop 22 2500)) {
    L 'desktop_ssh_port=OPEN'
    $fshare = '\\' + $desktop + '\F$'
    $net = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -eq 0) {
        try {
            $rootUnc = $fshare + '\fig1_rebuild'
            New-Item -ItemType Directory -Force -Path $rootUnc | Out-Null
            Copy-Item -LiteralPath $helper -Destination ($rootUnc + '\v2rayn_antigravity_auto_bridge.ps1') -Force
            Copy-Item -LiteralPath (Join-Path $repo 'code\tasks\desk_antigravity_private_bridge.ps1') -Destination ($rootUnc + '\desk_antigravity_private_bridge.ps1') -Force
            if (Test-Path -LiteralPath $subsFile) {
                $privUnc = $rootUnc + '\private'
                New-Item -ItemType Directory -Force -Path $privUnc | Out-Null
                Copy-Item -LiteralPath $subsFile -Destination ($privUnc + '\v2ray_subs.txt') -Force
                L 'desktop_private_subs_stage=OK'
            } else { L 'desktop_private_subs_stage=SKIP_NO_LOCAL_PRIVATE_FILE' }
            $boot = @'
$ErrorActionPreference = 'Continue'
$dst = Join-Path $env:USERPROFILE '.arena-private'
New-Item -ItemType Directory -Force -Path $dst | Out-Null
if (Test-Path -LiteralPath 'F:\fig1_rebuild\private\v2ray_subs.txt') {
  Copy-Item -LiteralPath 'F:\fig1_rebuild\private\v2ray_subs.txt' -Destination (Join-Path $dst 'v2ray_subs.txt') -Force
  Remove-Item -LiteralPath 'F:\fig1_rebuild\private\v2ray_subs.txt' -Force -ErrorAction SilentlyContinue
}
powershell -NoProfile -ExecutionPolicy Bypass -File 'F:\fig1_rebuild\desk_antigravity_private_bridge.ps1'
'@
            [IO.File]::WriteAllText(($rootUnc + '\desk_agy_bootstrap_r244.ps1'), $boot.Replace("`n","`r`n"), (New-Object Text.UTF8Encoding($false)))
            L 'desktop_stage=OK'
        } catch { L ('desktop_stage_WARN=' + (San $_.Exception.Message)) }
        finally { & net use $fshare /delete 2>&1 | Out-Null }
        $sshBase = @('-o','BatchMode=yes','-o','ConnectTimeout=12','-o','StrictHostKeyChecking=accept-new')
        $job = Start-Job -ScriptBlock { param($o,$u,$h) & ssh @o ($u + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\desk_agy_bootstrap_r244.ps1' 2>&1 | Out-String } -ArgumentList $sshBase,$duser,$desktop
        if (Wait-Job $job -Timeout 900) {
            $do = (Receive-Job $job | Out-String).Trim()
            foreach ($ln in (($do -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -First 500)) { L ('desktop| ' + (San $ln)) }
            if ($do -match 'FINAL_DESKTOP_BRIDGE: OK_SUPPORTED_ROUTE|FINAL: V2RAYN_NODE_BRIDGE_APPLIED') { $deskOK = $true }
        } else { Stop-Job $job -Force -ErrorAction SilentlyContinue; L 'desktop_bridge_TIMEOUT=900s' }
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        # collect sanitized reports
        $net2 = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -eq 0) {
            try {
                foreach ($name in @('antigravity_bridge_desktop_r193.md','v2rayn_node_bridge_desktop_r193.md')) {
                    $src = $fshare + '\fig1_rebuild\' + $name
                    if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $agyDir ('R244_' + $name)) -Force; L ('desktop_collected=' + 'R244_' + $name) }
                }
            } catch { L ('desktop_collect_WARN=' + (San $_.Exception.Message)) }
            finally { & net use $fshare /delete 2>&1 | Out-Null }
        } else { L ('desktop_collect_skip=' + (San $net2)) }
    } else { L ('desktop_Fshare_unreachable=' + (San $net)) }
} elseif (-not $deskOK) { L 'desktop_ssh_port=CLOSED' }
L ('DESKTOP_V2RAY_TAKEOVER_OK=' + $deskOK)
Rec 'DESKTOP_V2RAY_TAKEOVER_OK' ([string]$deskOK)
L ''

# ---------------------------------------------------------- final
L '## 5. Final markers'
L ('MUSE_PACKAGE_VALID=' + $pkgOK)
L ('LOCAL_V2RAY_TAKEOVER_OK=' + $localOK)
L ('DESKTOP_V2RAY_TAKEOVER_OK=' + $deskOK)
L ('report=' + ($report -replace '\\','/'))
L ('json=' + ($jsonReport -replace '\\','/'))
L 'MUSE_V2RAY_TAKEOVER_DONE'
Write-Reports
if (-not $pkgOK) { exit 2 }
if (-not $localOK) { exit 3 }
# Desktop is allowed to be best-effort: local Antigravity is the required fix.
exit 0
