# t148_restart_verify_bridge.ps1 - round 191: restart xray bridge without killing v2rayN.
# ASCII-only. Uses private config; prints no node secrets.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function Write-Utf8([string]$Path, [string[]]$Lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null; [IO.File]::WriteAllText($Path, ($Lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function Wait-Port([int]$port, [int]$sec) { $deadline=(Get-Date).AddSeconds($sec); while((Get-Date)-lt $deadline){ try{$c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$port,$null,$null); if($iar.AsyncWaitHandle.WaitOne(400)){ $c.EndConnect($iar); $c.Close(); return $true}; $c.Close()}catch{}; Start-Sleep -Milliseconds 300}; return $false }
function Invoke-Curl([string[]]$CurlArgs) { try { $ce = Join-Path $env:SystemRoot 'System32\curl.exe'; return (& $ce @CurlArgs 2>&1 | Out-String).Trim() } catch { return $_.Exception.Message } }
function Find-XrayPath {
    $cmdPath = Join-Path $env:USERPROFILE '.arena-private\start-antigravity-xray-bridge.cmd'
    if(Test-Path $cmdPath){ try{ $txt=Get-Content -LiteralPath $cmdPath -Raw; if($txt -match '"([A-Z]:\\[^\"]*xray\.exe)"'){ return $Matches[1] } }catch{} }
    foreach($p in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^xray\.exe$|^v2ray\.exe$' -and $_.ExecutablePath } | Select-Object -First 3)){ if($p.ExecutablePath){ return [string]$p.ExecutablePath } }
    foreach($root in @($env:USERPROFILE,$env:LOCALAPPDATA,$env:APPDATA,'E:\','F:\')){ if(Test-Path $root){ $f=@(Get-ChildItem -LiteralPath $root -Recurse -Depth 6 -Filter xray.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1); if($f.Count -gt 0){ return $f[0].FullName } } }
    return ''
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\antigravity'; New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report=Join-Path $outDir 'antigravity_bridge_restart_verify_r191.md'
L '# Antigravity bridge restart verify'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
$priv=Join-Path $env:USERPROFILE '.arena-private'
$cfgPath=Join-Path $priv 'antigravity-xray-bridge.json'
$xray=Find-XrayPath
L ('cfg_exists=' + (Test-Path -LiteralPath $cfgPath))
L ('xray_path=' + (San $xray))
if(-not (Test-Path -LiteralPath $cfgPath)){ L 'FINAL_RESTART: MISSING_PRIVATE_BRIDGE_CONFIG'; Write-Utf8 $report $script:Lines; Get-Content $report; exit 0 }
if(-not $xray -or -not (Test-Path -LiteralPath $xray)){ L 'FINAL_RESTART: XRAY_NOT_FOUND'; Write-Utf8 $report $script:Lines; Get-Content $report; exit 0 }
$testOut = (& $xray run -test -config $cfgPath 2>&1 | Out-String)
L ('xray_config_test=' + (San (($testOut -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 1))))
# Stop only prior bridge processes that used this private config. Leave v2rayN's core alone.
try {
    $old = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { ($_.Name -match '^xray\.exe$|^v2ray\.exe$') -and ($_.CommandLine -like ('*' + $cfgPath + '*')) })
    foreach($p in $old){ try{ Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue; L ('stopped_old_bridge_pid=' + $p.ProcessId) }catch{} }
} catch { L ('stop_old_WARN=' + (San $_.Exception.Message)) }
$stdout=Join-Path $priv 'antigravity-xray-bridge.stdout.log'
$stderr=Join-Path $priv 'antigravity-xray-bridge.stderr.log'
Remove-Item -LiteralPath $stdout,$stderr -Force -ErrorAction SilentlyContinue
try {
    $p = Start-Process -FilePath $xray -ArgumentList @('run','-config',$cfgPath) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    L ('started_direct_pid=' + $p.Id)
} catch { L ('start_direct_WARN=' + (San $_.Exception.Message)) }
Start-Sleep -Seconds 2
$listen = Wait-Port 18088 10
L ('bridge_port_18088_listen_after_direct=' + $listen)
if(-not $listen){
    foreach($lf in @($stderr,$stdout)){ if(Test-Path $lf){ foreach($ln in (Get-Content -LiteralPath $lf -Tail 20 -ErrorAction SilentlyContinue)){ L ('xray_log| ' + (San $ln)) } } }
}
# Install a private no-kill launcher for future logons.
$ensure=Join-Path $priv 'ensure-antigravity-xray-bridge.ps1'
$ensureLines=@(
    '$ErrorActionPreference = ''Continue''',
    '$cfg = ''' + ($cfgPath -replace '''','''''') + '''',
    '$xray = ''' + ($xray -replace '''','''''') + '''',
    'try { $old = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { ($_.Name -match ''^xray\.exe$|^v2ray\.exe$'') -and ($_.CommandLine -like (''*'' + $cfg + ''*'')) }); foreach($p in $old){ Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } } catch {}',
    'Start-Process -FilePath $xray -ArgumentList @(''run'',''-config'',$cfg) -WindowStyle Hidden'
)
[IO.File]::WriteAllLines($ensure, $ensureLines, (New-Object Text.UTF8Encoding($false)))
try { $tn='antigravity-xray-bridge'; $ps=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'; $la=New-ScheduledTaskAction -Execute $ps -Argument ('-NoProfile -ExecutionPolicy Bypass -File "' + $ensure + '"'); $tr=New-ScheduledTaskTrigger -AtLogOn; $pr=New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited; $st=New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries; Register-ScheduledTask -TaskName $tn -Action $la -Trigger $tr -Principal $pr -Settings $st -Force | Out-Null; Start-ScheduledTask -TaskName $tn; L ('scheduled_task_reinstalled_started=' + $tn) } catch { L ('scheduled_task_WARN=' + (San $_.Exception.Message)) }
if(-not $listen){ Start-Sleep -Seconds 4; $listen = Wait-Port 18088 8; L ('bridge_port_18088_listen_after_task=' + $listen) }
if($listen){
    foreach($scope in @('User')){ foreach($k in @('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy')){ [Environment]::SetEnvironmentVariable($k,'http://127.0.0.1:18088',$scope) } }
    foreach($root in @((Join-Path $env:APPDATA 'Antigravity\User'),(Join-Path $env:APPDATA 'Antigravity IDE\User'))){ try{ New-Item -ItemType Directory -Force -Path $root | Out-Null; $sp=Join-Path $root 'settings.json'; $obj=[pscustomobject]@{}; if(Test-Path $sp){ try{$obj=Get-Content $sp -Raw -Encoding UTF8 | ConvertFrom-Json}catch{$obj=[pscustomobject]@{}} }; $obj|Add-Member -NotePropertyName 'http.proxy' -NotePropertyValue 'http://127.0.0.1:18088' -Force; $obj|Add-Member -NotePropertyName 'http.proxySupport' -NotePropertyValue 'on' -Force; $obj|Add-Member -NotePropertyName 'http.noProxy' -NotePropertyValue @('localhost','127.0.0.1','::1') -Force; [IO.File]::WriteAllText($sp,(($obj|ConvertTo-Json -Depth 8)+"`r`n"),(New-Object Text.UTF8Encoding($false))); L ('settings_OK=' + $sp) }catch{L('settings_WARN=' + (San $_.Exception.Message))} }
    $geo = Invoke-Curl -CurlArgs @('-L','--max-time','15','-sS','--proxy','http://127.0.0.1:18088','https://ipinfo.io/json')
    try{ $go=$geo|ConvertFrom-Json; L ('bridge_geo_country=' + [string]$go.country + ' ip=' + (San ([string]$go.ip)) + ' org=' + (San ([string]$go.org))) }catch{ L ('bridge_geo_raw=' + (San $geo)) }
    try{ foreach($n in @('language_server','Antigravity')){ taskkill /f /im ($n + '.exe') 2>&1 | Out-Null }; Start-Sleep -Seconds 2; $exe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'; if(Test-Path $exe){ Start-Process $exe; L 'antigravity_relaunch=OK' } }catch{ L ('antigravity_relaunch_WARN=' + (San $_.Exception.Message)) }
    L 'FINAL_RESTART: ANTIGRAVITY_BRIDGE_LISTENING'
} else {
    L 'FINAL_RESTART: ANTIGRAVITY_BRIDGE_STILL_NOT_LISTENING'
}
Write-Utf8 $report $script:Lines
Get-Content -LiteralPath $report -ErrorAction SilentlyContinue
exit 0
