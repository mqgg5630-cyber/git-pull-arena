# desk_antigravity_private_bridge.ps1 - runs ON THE DESKTOP via ssh.
# Apply the same private node bridge used on the laptop to Antigravity.
# Prints no node secrets. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function Write-Utf8([string]$Path, [string[]]$Lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null; [IO.File]::WriteAllText($Path, ($Lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function Invoke-Curl([string[]]$CurlArgs) { try { $ce = Join-Path $env:SystemRoot 'System32\curl.exe'; return (& $ce @CurlArgs 2>&1 | Out-String).Trim() } catch { return $_.Exception.Message } }
function Wait-Port([int]$port, [int]$sec) {
    $deadline = (Get-Date).AddSeconds($sec)
    while ((Get-Date) -lt $deadline) {
        try { $c = New-Object Net.Sockets.TcpClient; $iar = $c.BeginConnect('127.0.0.1', $port, $null, $null); if ($iar.AsyncWaitHandle.WaitOne(400)) { $c.EndConnect($iar); $c.Close(); return $true }; $c.Close() } catch { }
        Start-Sleep -Milliseconds 300
    }
    return $false
}
function Find-XrayPath {
    $cmdPath = Join-Path $env:USERPROFILE '.arena-private\start-antigravity-xray-bridge.cmd'
    if (Test-Path -LiteralPath $cmdPath) {
        try { $txt = Get-Content -LiteralPath $cmdPath -Raw; if ($txt -match '"([A-Z]:\\[^\"]*xray\.exe)"') { return $Matches[1] } } catch { }
    }
    foreach ($p in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^xray\.exe$|^v2ray\.exe$' -and $_.ExecutablePath } | Select-Object -First 3)) { if ($p.ExecutablePath) { return [string]$p.ExecutablePath } }
    foreach ($root in @('F:\v2rayN-new', 'F:\', 'E:\', $env:USERPROFILE, $env:LOCALAPPDATA, $env:APPDATA)) {
        if (Test-Path -LiteralPath $root) {
            $f = @(Get-ChildItem -LiteralPath $root -Recurse -Depth 7 -Filter xray.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1)
            if ($f.Count -gt 0) { return $f[0].FullName }
        }
    }
    return ''
}
function Ensure-Bridge-From-Config {
    $priv = Join-Path $env:USERPROFILE '.arena-private'
    $cfgPath = Join-Path $priv 'antigravity-xray-bridge.json'
    $xray = Find-XrayPath
    L ('ensure_cfg_exists=' + (Test-Path -LiteralPath $cfgPath))
    L ('ensure_xray=' + (San $xray))
    if (-not (Test-Path -LiteralPath $cfgPath)) { return $false }
    if (-not $xray -or -not (Test-Path -LiteralPath $xray)) { return $false }
    try {
        $testOut = (& $xray run -test -config $cfgPath 2>&1 | Out-String)
        L ('xray_config_test=' + (San (($testOut -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 1))))
    } catch { L ('xray_config_test_WARN=' + (San $_.Exception.Message)) }
    try {
        $old = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { ($_.Name -match '^xray\.exe$|^v2ray\.exe$') -and ($_.CommandLine -like ('*' + $cfgPath + '*')) })
        foreach ($p in $old) { try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue; L ('stopped_old_bridge_pid=' + $p.ProcessId) } catch { } }
    } catch { L ('stop_old_WARN=' + (San $_.Exception.Message)) }
    try {
        $p = Start-Process -FilePath $xray -ArgumentList @('run','-config',$cfgPath) -WindowStyle Hidden -PassThru
        L ('started_bridge_pid=' + $p.Id)
    } catch { L ('start_bridge_WARN=' + (San $_.Exception.Message)) }
    $ensure = Join-Path $priv 'ensure-antigravity-xray-bridge.ps1'
    $ensureLines = @(
        '$ErrorActionPreference = ''Continue''',
        '$cfg = ''' + ($cfgPath -replace '''','''''') + '''',
        '$xray = ''' + ($xray -replace '''','''''') + '''',
        'try { $old = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { ($_.Name -match ''^xray\.exe$|^v2ray\.exe$'') -and ($_.CommandLine -like (''*'' + $cfg + ''*'')) }); foreach($p in $old){ Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } } catch {}',
        'Start-Process -FilePath $xray -ArgumentList @(''run'',''-config'',$cfg) -WindowStyle Hidden'
    )
    [IO.File]::WriteAllLines($ensure, $ensureLines, (New-Object Text.UTF8Encoding($false)))
    try {
        $tn='antigravity-xray-bridge'
        $ps=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $la=New-ScheduledTaskAction -Execute $ps -Argument ('-NoProfile -ExecutionPolicy Bypass -File "' + $ensure + '"')
        $tr=New-ScheduledTaskTrigger -AtLogOn
        $pr=New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
        $st=New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        Register-ScheduledTask -TaskName $tn -Action $la -Trigger $tr -Principal $pr -Settings $st -Force | Out-Null
        Start-ScheduledTask -TaskName $tn
        L ('scheduled_task_reinstalled_started=' + $tn)
    } catch { L ('scheduled_task_WARN=' + (San $_.Exception.Message)) }
    return (Wait-Port 18088 12)
}
function Ensure-Antigravity-Proxy-Settings {
    foreach($scope in @('User')){
        foreach($k in @('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy')){ try{ [Environment]::SetEnvironmentVariable($k,'http://127.0.0.1:18088',$scope) }catch{} }
        try{ [Environment]::SetEnvironmentVariable('NO_PROXY','localhost,127.0.0.1,::1',$scope) }catch{}
    }
    foreach($root in @((Join-Path $env:APPDATA 'Antigravity\User'),(Join-Path $env:APPDATA 'Antigravity IDE\User'))){
        try{
            New-Item -ItemType Directory -Force -Path $root | Out-Null
            $sp=Join-Path $root 'settings.json'
            $obj=[pscustomobject]@{}
            if(Test-Path $sp){ try{$obj=Get-Content $sp -Raw -Encoding UTF8 | ConvertFrom-Json}catch{$obj=[pscustomobject]@{}} }
            $obj|Add-Member -NotePropertyName 'http.proxy' -NotePropertyValue 'http://127.0.0.1:18088' -Force
            $obj|Add-Member -NotePropertyName 'http.proxySupport' -NotePropertyValue 'on' -Force
            $obj|Add-Member -NotePropertyName 'http.noProxy' -NotePropertyValue @('localhost','127.0.0.1','::1') -Force
            [IO.File]::WriteAllText($sp,(($obj|ConvertTo-Json -Depth 8)+"`r`n"),(New-Object Text.UTF8Encoding($false)))
            L ('settings_OK=' + $sp)
        } catch { L ('settings_WARN=' + (San $_.Exception.Message)) }
    }
}
function Relaunch-Antigravity {
    try { foreach($n in @('language_server','Antigravity')){ taskkill /f /im ($n + '.exe') 2>&1 | Out-Null } } catch { }
    Start-Sleep -Seconds 2
    $exe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
    if(Test-Path $exe){
        try{
            $tn='agyrelaunch_auto_bridge_desktop'
            $la=New-ScheduledTaskAction -Execute $exe
            $pr=New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
            Register-ScheduledTask -TaskName $tn -Action $la -Principal $pr -Force | Out-Null
            Start-ScheduledTask -TaskName $tn
            L ('antigravity_relaunch_task=' + $tn)
        }catch{
            try{ Start-Process $exe; L 'antigravity_relaunch=OK' }catch{ L ('antigravity_relaunch_WARN=' + (San $_.Exception.Message)) }
        }
    }
}

$script:Lines=@()
$root='F:\fig1_rebuild'
New-Item -ItemType Directory -Force -Path $root | Out-Null
$report=Join-Path $root 'antigravity_bridge_desktop_r193.md'
L '# Desktop Antigravity private bridge'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
$agExe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
L ('antigravity_installed=' + (Test-Path -LiteralPath $agExe))
if(Test-Path -LiteralPath $agExe){ L ('antigravity_version=' + (San ([string](Get-Item -LiteralPath $agExe).VersionInfo.ProductVersion))) }
$subs=Join-Path $env:USERPROFILE '.arena-private\v2ray_subs.txt'
if(Test-Path -LiteralPath $subs){ $cnt=@(Get-Content -LiteralPath $subs -ErrorAction SilentlyContinue | Where-Object { $_ -match '^(vmess|vless|trojan|ss)://' }).Count; L ('private_subs_present=True node_lines=' + $cnt) } else { L 'private_subs_present=False' }
$helper=Join-Path $root 'v2rayn_antigravity_auto_bridge.ps1'
$nodeReport=Join-Path $root 'v2rayn_node_bridge_desktop_r193.md'
if(Test-Path -LiteralPath $helper){
    try{
        $out=(& $helper -OutPath $nodeReport -MaxNodes 30 -Apply -Relaunch -InteractiveTask 2>&1 | Out-String)
        L ('helper_exit=' + $LASTEXITCODE)
        foreach($ln in (($out -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -First 900)){ L ('helper| ' + (San $ln)) }
    } catch { L ('helper_THROW=' + (San $_.Exception.Message)) }
} else { L 'helper_missing=True' }
$listen=Wait-Port 18088 8
L ('bridge_port_18088_listen_after_helper=' + $listen)
if(-not $listen){ $listen=Ensure-Bridge-From-Config; L ('bridge_port_18088_listen_after_ensure=' + $listen) }
Ensure-Antigravity-Proxy-Settings
if($listen){
    $proxy='http://127.0.0.1:18088'
    $httpGeo=Invoke-Curl -CurlArgs @('-L','--max-time','15','-sS','--proxy',$proxy,'http://ip-api.com/json/?fields=status,countryCode,country,query,isp,org')
    $cc=''; $org=''; $ip=''
    try{ $h=$httpGeo|ConvertFrom-Json; $cc=[string]$h.countryCode; $ip=[string]$h.query; $org=[string]$h.org; L ('http_geo_status=' + [string]$h.status + ' country=' + $cc + ' ip=' + (San $ip) + ' org=' + (San $org)) }catch{ L ('http_geo_raw=' + (San $httpGeo)) }
    $httpsGeo=Invoke-Curl -CurlArgs @('--ssl-no-revoke','-L','--max-time','20','-sS','--proxy',$proxy,'https://ipinfo.io/json')
    try{ $g=$httpsGeo|ConvertFrom-Json; L ('https_geo_country=' + [string]$g.country + ' ip=' + (San ([string]$g.ip)) + ' org=' + (San ([string]$g.org))) }catch{ L ('https_geo_raw=' + (San $httpsGeo)) }
    $api=Invoke-Curl -CurlArgs @('--ssl-no-revoke','-i','-L','--max-time','20','-sS','--proxy',$proxy,'https://daily-cloudcode-pa.googleapis.com/')
    $status=(($api -split "`r?`n") | Where-Object { $_ -match '^HTTP/' } | Select-Object -Last 1)
    $unsupported=[bool]($api -match 'User location is not supported|FAILED_PRECONDITION')
    L ('daily_cloudcode_status=' + (San $status))
    L ('daily_cloudcode_location_block_text_present=' + $unsupported)
    Relaunch-Antigravity
    if($unsupported){ L 'FINAL_DESKTOP_BRIDGE: LOCATION_BLOCK_STILL_PRESENT' }
    elseif($cc -match 'US|CA|GB|AU|NZ|JP|KR|SG|TW|DE|FR|NL|SE|NO|FI|DK|IE|ES|IT|PT|PL|BE|CH|AT|CZ|EE|LV|LT|LU|RO|BG|GR|HR|HU|IS|LI|MT|SK|SI'){ L 'FINAL_DESKTOP_BRIDGE: OK_SUPPORTED_ROUTE' }
    else { L 'FINAL_DESKTOP_BRIDGE: LISTENING_ROUTE_CHECK_NEEDED' }
} else { L 'FINAL_DESKTOP_BRIDGE: NOT_LISTENING' }
$bridgeProcs=@(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { ($_.Name -match '^xray\.exe$|^v2ray\.exe$') -and ($_.CommandLine -like '*antigravity-xray-bridge.json*') })
L ('bridge_xray_processes=' + $bridgeProcs.Count)
$agy=@(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^Antigravity\.exe$|^language_server\.exe$' })
L ('antigravity_processes=' + $agy.Count)
Write-Utf8 $report $script:Lines
Get-Content -LiteralPath $report -ErrorAction SilentlyContinue
exit 0
