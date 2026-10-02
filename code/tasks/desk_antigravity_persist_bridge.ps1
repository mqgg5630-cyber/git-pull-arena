# desk_antigravity_persist_bridge.ps1 - runs ON THE DESKTOP via ssh.
# Fix persistence by making Task Scheduler run xray.exe itself (not a short
# wrapper that starts a child process and exits). ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function Write-Utf8([string]$Path, [string[]]$Lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null; [IO.File]::WriteAllText($Path, ($Lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function Invoke-Curl([string[]]$CurlArgs) { try { $ce = Join-Path $env:SystemRoot 'System32\curl.exe'; return (& $ce @CurlArgs 2>&1 | Out-String).Trim() } catch { return $_.Exception.Message } }
function Wait-Port([int]$port, [int]$sec) { $deadline=(Get-Date).AddSeconds($sec); while((Get-Date)-lt $deadline){ try{$c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$port,$null,$null); if($iar.AsyncWaitHandle.WaitOne(400)){ $c.EndConnect($iar); $c.Close(); return $true}; $c.Close()}catch{}; Start-Sleep -Milliseconds 300}; return $false }
function Find-XrayPath {
    $cmdPath = Join-Path $env:USERPROFILE '.arena-private\start-antigravity-xray-bridge.cmd'
    if(Test-Path -LiteralPath $cmdPath){ try{ $txt=Get-Content -LiteralPath $cmdPath -Raw; if($txt -match '"([A-Z]:\\[^\"]*xray\.exe)"'){ return $Matches[1] } }catch{} }
    foreach($p in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^xray\.exe$|^v2ray\.exe$' -and $_.ExecutablePath } | Select-Object -First 3)){ if($p.ExecutablePath){ return [string]$p.ExecutablePath } }
    foreach($root in @('F:\v2rayN-new','F:\','E:\',$env:USERPROFILE,$env:LOCALAPPDATA,$env:APPDATA)){ if(Test-Path $root){ $f=@(Get-ChildItem -LiteralPath $root -Recurse -Depth 7 -Filter xray.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1); if($f.Count -gt 0){ return $f[0].FullName } } }
    return ''
}
function Ensure-Settings {
    foreach($scope in @('User','Machine')){ try{ foreach($k in @('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy')){ [Environment]::SetEnvironmentVariable($k,'http://127.0.0.1:18088',$scope) }; [Environment]::SetEnvironmentVariable('NO_PROXY','localhost,127.0.0.1,::1',$scope) }catch{} }
    foreach($root in @((Join-Path $env:APPDATA 'Antigravity\User'),(Join-Path $env:APPDATA 'Antigravity IDE\User'))){
        try{ New-Item -ItemType Directory -Force -Path $root | Out-Null; $sp=Join-Path $root 'settings.json'; $obj=[pscustomobject]@{}; if(Test-Path $sp){ try{$obj=Get-Content $sp -Raw -Encoding UTF8 | ConvertFrom-Json}catch{$obj=[pscustomobject]@{}} }; $obj|Add-Member -NotePropertyName 'http.proxy' -NotePropertyValue 'http://127.0.0.1:18088' -Force; $obj|Add-Member -NotePropertyName 'http.proxySupport' -NotePropertyValue 'on' -Force; $obj|Add-Member -NotePropertyName 'http.noProxy' -NotePropertyValue @('localhost','127.0.0.1','::1') -Force; [IO.File]::WriteAllText($sp,(($obj|ConvertTo-Json -Depth 8)+"`r`n"),(New-Object Text.UTF8Encoding($false))); L ('settings_OK=' + $sp) }catch{ L ('settings_WARN=' + (San $_.Exception.Message)) }
    }
}

$script:Lines=@()
$root='F:\fig1_rebuild'
New-Item -ItemType Directory -Force -Path $root | Out-Null
$report=Join-Path $root 'antigravity_bridge_desktop_persist_r195.md'
L '# Desktop Antigravity bridge persistence fix'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
$agExe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
L ('antigravity_installed=' + (Test-Path -LiteralPath $agExe))
if(Test-Path -LiteralPath $agExe){ L ('antigravity_version=' + (San ([string](Get-Item -LiteralPath $agExe).VersionInfo.ProductVersion))) }
$priv=Join-Path $env:USERPROFILE '.arena-private'
$cfg=Join-Path $priv 'antigravity-xray-bridge.json'
$xray=Find-XrayPath
L ('cfg_exists=' + (Test-Path -LiteralPath $cfg))
L ('xray_path=' + (San $xray))
if(-not (Test-Path -LiteralPath $cfg)){ L 'FINAL_DESKTOP_PERSIST: MISSING_CONFIG'; Write-Utf8 $report $script:Lines; Get-Content $report; exit 0 }
if(-not $xray -or -not (Test-Path -LiteralPath $xray)){ L 'FINAL_DESKTOP_PERSIST: XRAY_NOT_FOUND'; Write-Utf8 $report $script:Lines; Get-Content $report; exit 0 }
try{ $testOut=(& $xray run -test -config $cfg 2>&1 | Out-String); L ('xray_config_test=' + (San (($testOut -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 1)))) }catch{ L ('xray_config_test_WARN=' + (San $_.Exception.Message)) }
# Stop prior bridge processes and old wrapper task. Do not kill v2rayN's core.
try{ foreach($tn in @('antigravity-xray-bridge-live','antigravity-xray-bridge')){ try{ Stop-ScheduledTask -TaskName $tn -ErrorAction SilentlyContinue }catch{} } }catch{}
try{ $old=@(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { ($_.Name -match '^xray\.exe$|^v2ray\.exe$') -and ($_.CommandLine -like ('*' + $cfg + '*')) }); foreach($p in $old){ try{ Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue; L ('stopped_old_bridge_pid=' + $p.ProcessId) }catch{} } }catch{ L ('stop_old_WARN=' + (San $_.Exception.Message)) }
Ensure-Settings
$tn='antigravity-xray-bridge-live'
try{
    $arg='run -config "' + $cfg + '"'
    $la=New-ScheduledTaskAction -Execute $xray -Argument $arg
    $tr=New-ScheduledTaskTrigger -AtLogOn
    $pr=New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
    try { $st=New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 365) } catch { $st=New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries }
    Register-ScheduledTask -TaskName $tn -Action $la -Trigger $tr -Principal $pr -Settings $st -Force | Out-Null
    L ('direct_task_registered=' + $tn)
    Start-ScheduledTask -TaskName $tn
    L ('direct_task_started=' + $tn)
}catch{ L ('direct_task_WARN=' + (San $_.Exception.Message)) }
Start-Sleep -Seconds 4
$listen1=Wait-Port 18088 12
L ('bridge_port_18088_listen_1=' + $listen1)
Start-Sleep -Seconds 20
$listen2=Wait-Port 18088 5
L ('bridge_port_18088_listen_2=' + $listen2)
$bridgeProcs=@(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { ($_.Name -match '^xray\.exe$|^v2ray\.exe$') -and ($_.CommandLine -like '*antigravity-xray-bridge.json*') })
L ('bridge_xray_processes=' + $bridgeProcs.Count)
foreach($p in ($bridgeProcs | Select-Object -First 4)){ L ('bridge_proc_pid=' + $p.ProcessId + ' exe=' + (San ([string]$p.ExecutablePath))) }
try{ $ti=Get-ScheduledTaskInfo -TaskName $tn -ErrorAction SilentlyContinue; if($ti){ L ('task_state=' + (Get-ScheduledTask -TaskName $tn).State + ' last=' + $ti.LastTaskResult) } }catch{}
if($listen2){
    $proxy='http://127.0.0.1:18088'
    $httpGeo=Invoke-Curl -CurlArgs @('-L','--max-time','15','-sS','--proxy',$proxy,'http://ip-api.com/json/?fields=status,countryCode,country,query,isp,org')
    $cc=''
    try{ $h=$httpGeo|ConvertFrom-Json; $cc=[string]$h.countryCode; L ('http_geo_status=' + [string]$h.status + ' country=' + $cc + ' ip=' + (San ([string]$h.query)) + ' org=' + (San ([string]$h.org))) }catch{ L ('http_geo_raw=' + (San $httpGeo)) }
    $httpsGeo=Invoke-Curl -CurlArgs @('--ssl-no-revoke','-L','--max-time','20','-sS','--proxy',$proxy,'https://ipinfo.io/json')
    try{ $g=$httpsGeo|ConvertFrom-Json; L ('https_geo_country=' + [string]$g.country + ' ip=' + (San ([string]$g.ip)) + ' org=' + (San ([string]$g.org))) }catch{ L ('https_geo_raw=' + (San $httpsGeo)) }
    $api=Invoke-Curl -CurlArgs @('--ssl-no-revoke','-i','-L','--max-time','20','-sS','--proxy',$proxy,'https://daily-cloudcode-pa.googleapis.com/')
    $status=(($api -split "`r?`n") | Where-Object { $_ -match '^HTTP/' } | Select-Object -Last 1)
    $unsupported=[bool]($api -match 'User location is not supported|FAILED_PRECONDITION')
    L ('daily_cloudcode_status=' + (San $status))
    L ('daily_cloudcode_location_block_text_present=' + $unsupported)
    try{ foreach($n in @('language_server','Antigravity')){ taskkill /f /im ($n + '.exe') 2>&1 | Out-Null }; Start-Sleep -Seconds 2; if(Test-Path $agExe){ $rt='agyrelaunch_auto_bridge_desktop'; $a=New-ScheduledTaskAction -Execute $agExe; $p=New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited; Register-ScheduledTask -TaskName $rt -Action $a -Principal $p -Force | Out-Null; Start-ScheduledTask -TaskName $rt; L ('antigravity_relaunch_task=' + $rt) } }catch{ L ('antigravity_relaunch_WARN=' + (San $_.Exception.Message)) }
    if(-not $unsupported -and $cc -match 'US|CA|GB|AU|NZ|JP|KR|SG|TW|DE|FR|NL|SE|NO|FI|DK|IE|ES|IT|PT|PL|BE|CH|AT|CZ|EE|LV|LT|LU|RO|BG|GR|HR|HU|IS|LI|MT|SK|SI'){ L 'FINAL_DESKTOP_PERSIST: OK_PERSISTENT_SUPPORTED_ROUTE' }
    elseif(-not $unsupported){ L 'FINAL_DESKTOP_PERSIST: OK_PERSISTENT_ROUTE_CHECK' }
    else{ L 'FINAL_DESKTOP_PERSIST: LOCATION_BLOCK_STILL_PRESENT' }
}else{ L 'FINAL_DESKTOP_PERSIST: NOT_LISTENING' }
Write-Utf8 $report $script:Lines
Get-Content -LiteralPath $report -ErrorAction SilentlyContinue
exit 0
