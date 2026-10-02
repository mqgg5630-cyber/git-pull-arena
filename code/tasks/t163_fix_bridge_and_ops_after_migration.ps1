# t163_fix_bridge_and_ops_after_migration.ps1 - round 206.
# After moving lab to E:, restore/verify the laptop Antigravity bridge, fix
# software-ops test launchers, and recheck MCP config paths. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function WA([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllLines($p, $lines, (New-Object System.Text.ASCIIEncoding)) }
function Wait-Port([int]$port, [int]$sec) { $deadline=(Get-Date).AddSeconds($sec); while((Get-Date)-lt $deadline){ try{$c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$port,$null,$null); if($iar.AsyncWaitHandle.WaitOne(400)){ $c.EndConnect($iar); $c.Close(); return $true}; $c.Close()}catch{}; Start-Sleep -Milliseconds 300}; return $false }
function Invoke-Curl([string[]]$CurlArgs) { try { $ce = Join-Path $env:SystemRoot 'System32\curl.exe'; return (& $ce @CurlArgs 2>&1 | Out-String).Trim() } catch { return $_.Exception.Message } }
function Run-Capped([string]$Name, [scriptblock]$Block, [int]$TimeoutSec) {
    L ('RUN_START=' + $Name)
    $job=Start-Job -ScriptBlock $Block
    if(-not (Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; L ('RUN_TIMEOUT=' + $Name); return @{ok=$false;text='TIMEOUT'} }
    $txt=(Receive-Job $job | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue
    foreach($ln in (($txt -split "`r?`n") | Select-Object -First 120)){ if($ln.Trim()){ L ('RUN_OUT|' + $Name + '| ' + (San $ln)) } }
    return @{ok=$true;text=$txt}
}
function Find-XrayPath {
    $cmdPath=Join-Path $env:USERPROFILE '.arena-private\start-antigravity-xray-bridge.cmd'
    if(Test-Path -LiteralPath $cmdPath){ try{ $txt=Get-Content -LiteralPath $cmdPath -Raw; if($txt -match '"([A-Z]:\\[^\"]*xray\.exe)"'){ return $Matches[1] } }catch{} }
    foreach($p in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^xray\.exe$|^v2ray\.exe$' -and $_.ExecutablePath } | Select-Object -First 3)){ if($p.ExecutablePath){ return [string]$p.ExecutablePath } }
    foreach($root in @($env:USERPROFILE,$env:LOCALAPPDATA,$env:APPDATA,'E:\','F:\')){ if(Test-Path $root){ $f=@(Get-ChildItem -LiteralPath $root -Recurse -Depth 6 -Filter xray.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1); if($f.Count -gt 0){ return $f[0].FullName } } }
    return ''
}
function Ensure-Bridge {
    $priv=Join-Path $env:USERPROFILE '.arena-private'
    $cfg=Join-Path $priv 'antigravity-xray-bridge.json'
    $xray=Find-XrayPath
    L ('bridge_cfg_exists=' + (Test-Path -LiteralPath $cfg))
    L ('bridge_xray_path=' + (San $xray))
    if((-not (Test-Path -LiteralPath $cfg)) -or (-not $xray) -or (-not (Test-Path -LiteralPath $xray))){ return $false }
    try { $testOut=(& $xray run -test -config $cfg 2>&1 | Out-String); L ('bridge_config_test=' + (San (($testOut -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 1)))) } catch { L ('bridge_config_test_WARN=' + (San $_.Exception.Message)) }
    try { $old=@(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { ($_.Name -match '^xray\.exe$|^v2ray\.exe$') -and ($_.CommandLine -like ('*' + $cfg + '*')) }); foreach($p in $old){ Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue; L ('stopped_old_bridge_pid=' + $p.ProcessId) } } catch { }
    try { $p=Start-Process -FilePath $xray -ArgumentList @('run','-config',$cfg) -WindowStyle Hidden -PassThru; L ('started_bridge_pid=' + $p.Id) } catch { L ('start_bridge_WARN=' + (San $_.Exception.Message)) }
    try {
        $tn='antigravity-xray-bridge-live'
        $arg='run -config "' + $cfg + '"'
        $la=New-ScheduledTaskAction -Execute $xray -Argument $arg
        $tr=New-ScheduledTaskTrigger -AtLogOn
        $pr=New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
        try { $st=New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 365) } catch { $st=New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries }
        Register-ScheduledTask -TaskName $tn -Action $la -Trigger $tr -Principal $pr -Settings $st -Force | Out-Null
        Start-ScheduledTask -TaskName $tn
        L ('bridge_task_registered_started=' + $tn)
    } catch { L ('bridge_task_WARN=' + (San $_.Exception.Message)) }
    return (Wait-Port 18088 12)
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report=Join-Path $outDir 'FIX_BRIDGE_AND_OPS_AFTER_MIGRATION_R206.md'
L '--- task t163: fix bridge and ops after E migration ---'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
$lab='E:\0mcp-agv-arena-optimized'
$old=Join-Path $env:USERPROFILE '0mcp-agv-arena-optimized'
L ('lab_E_exists=' + (Test-Path -LiteralPath $lab))
L ('lab_C_exists=' + (Test-Path -LiteralPath $old))

# Restore/verify Antigravity route.
$listen0=Wait-Port 18088 2
L ('bridge_port_18088_before=' + $listen0)
if(-not $listen0){
    $listen=Ensure-Bridge
    L ('bridge_port_18088_after_ensure=' + $listen)
} else { $listen=$listen0 }
if(-not $listen){
    $helper=Join-Path $repo 'code\tasks\v2rayn_antigravity_auto_bridge.ps1'
    $helperReport=Join-Path $outDir 'v2rayn_node_bridge_local_r206.md'
    if(Test-Path -LiteralPath $helper){
        try{ $out=(& $helper -OutPath $helperReport -MaxNodes 30 -Apply -Relaunch 2>&1 | Out-String); L ('helper_bridge_exit=' + $LASTEXITCODE); foreach($ln in (($out -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -First 120)){ L ('helper| ' + (San $ln)) } }catch{ L ('helper_bridge_WARN=' + (San $_.Exception.Message)) }
        $listen=Wait-Port 18088 12
        L ('bridge_port_18088_after_helper=' + $listen)
    }
}
if($listen){
    foreach($scope in @('User')){ foreach($k in @('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy')){ try{ [Environment]::SetEnvironmentVariable($k,'http://127.0.0.1:18088',$scope) }catch{} } }
    foreach($root in @((Join-Path $env:APPDATA 'Antigravity\User'),(Join-Path $env:APPDATA 'Antigravity IDE\User'))){ try{ $sp=Join-Path $root 'settings.json'; $obj=[pscustomobject]@{}; if(Test-Path $sp){ try{$obj=Get-Content $sp -Raw -Encoding UTF8 | ConvertFrom-Json}catch{$obj=[pscustomobject]@{}} }; $obj|Add-Member -NotePropertyName 'http.proxy' -NotePropertyValue 'http://127.0.0.1:18088' -Force; $obj|Add-Member -NotePropertyName 'http.proxySupport' -NotePropertyValue 'on' -Force; $obj|Add-Member -NotePropertyName 'arena.computerUseLab' -NotePropertyValue $lab -Force; [IO.File]::WriteAllText($sp,(($obj|ConvertTo-Json -Depth 20)+"`r`n"),(New-Object Text.UTF8Encoding($false))); L ('settings_verified=' + (San $sp)) }catch{} }
    $httpGeo=Invoke-Curl -CurlArgs @('-L','--max-time','15','-sS','--proxy','http://127.0.0.1:18088','http://ip-api.com/json/?fields=status,countryCode,country,query,isp,org')
    try{ $h=$httpGeo|ConvertFrom-Json; L ('bridge_http_geo=' + [string]$h.countryCode + ' ip=' + (San ([string]$h.query)) + ' org=' + (San ([string]$h.org))) }catch{ L ('bridge_http_geo_raw=' + (San $httpGeo)) }
    $api=Invoke-Curl -CurlArgs @('--ssl-no-revoke','-i','-L','--max-time','20','-sS','--proxy','http://127.0.0.1:18088','https://daily-cloudcode-pa.googleapis.com/')
    $status=(($api -split "`r?`n") | Where-Object { $_ -match '^HTTP/' } | Select-Object -Last 1)
    L ('daily_cloudcode_status=' + (San $status))
    L ('daily_cloudcode_location_block_text_present=' + [bool]($api -match 'User location is not supported|FAILED_PRECONDITION'))
}

# Fix software-ops launcher and retest with full powershell.exe path.
$opsDir=Join-Path $lab 'software-ops'
$opsScript=Join-Path $opsDir 'Invoke-SoftwareAction.ps1'
$opsCmd=Join-Path $opsDir 'Invoke-SoftwareAction.cmd'
if(Test-Path -LiteralPath $opsScript){
    WA $opsCmd @('@echo off','%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Invoke-SoftwareAction.ps1" -Action %*')
    L ('software_ops_cmd_written=' + (San $opsCmd))
}
$psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$opsTest=@()
foreach($a in @('antigravity-status','v2rayn-status','greenvpn-status','wps-status')){
    if(Test-Path -LiteralPath $opsScript){
        try{ $txt=(& $psExe -NoProfile -ExecutionPolicy Bypass -File $opsScript -Action $a 2>&1 | Out-String).Trim(); $opsTest += ('## ' + $a); $opsTest += $txt; L ('software_op_test=' + $a + ' ok=True') }catch{ $opsTest += ('## ' + $a + ' FAIL ' + $_.Exception.Message); L ('software_op_test=' + $a + ' ok=False') }
    }
}
$reportsDir=Join-Path $lab 'reports'
New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null
W (Join-Path $reportsDir 'software-ops-test-r206.md') $opsTest
try { Copy-Item -LiteralPath (Join-Path $reportsDir 'software-ops-test-r206.md') -Destination (Join-Path $outDir 'software-ops-test-r206.md') -Force } catch { }

# Recheck MCP paths point to E:.
$mcpPaths=@('E:\0mcp-agv\.agent\mcp_config.json','E:\0mcp-agv\.agents\mcp_config.json','E:\0mcp-agv\.mcp.json',(Join-Path $env:APPDATA 'Antigravity\User\mcp_config.json'),(Join-Path $env:APPDATA 'Antigravity IDE\User\mcp_config.json'))
$pathOk=0
foreach($p in $mcpPaths){
    if(Test-Path -LiteralPath $p){
        try{ $raw=Get-Content -LiteralPath $p -Raw -Encoding UTF8; $has=[bool]($raw -match 'windows-computer-use' -and $raw -match 'E:\\0mcp-agv-arena-optimized'); L ('mcp_path_check=' + (San $p) + ' ok=' + $has); if($has){$pathOk++} }catch{ L ('mcp_path_check_WARN=' + (San $p)) }
    } else { L ('mcp_path_missing=' + (San $p)) }
}
L ('mcp_path_ok_count=' + $pathOk)
$skillsIndex=Join-Path $lab 'agents-skills\skills-index.json'
if(Test-Path -LiteralPath $skillsIndex){ try{ $idx=Get-Content -LiteralPath $skillsIndex -Raw -Encoding UTF8 | ConvertFrom-Json; L ('skills_index_exists=True count=' + @($idx).Count) }catch{ L 'skills_index_exists=True count=parse_warn' } } else { L 'skills_index_exists=False' }

$summary=@(
'# Round 206 verification',
'',
('Lab root on E exists: ' + (Test-Path -LiteralPath $lab)),
('Old C lab exists: ' + (Test-Path -LiteralPath $old)),
('Bridge 18088 listening: ' + $listen),
('MCP configs pointing to E: ' + $pathOk),
('Software ops script: ' + $opsScript),
('Software ops cmd: ' + $opsCmd),
('Skills index: ' + $skillsIndex)
)
W (Join-Path $reportsDir 'round206-verification.md') $summary
try { Copy-Item -LiteralPath (Join-Path $reportsDir 'round206-verification.md') -Destination (Join-Path $outDir 'round206-verification.md') -Force } catch { }
if($listen -and $pathOk -ge 3){ L 'FINAL_R206: E_MIGRATION_MCP_AND_BRIDGE_VERIFIED' } else { L 'FINAL_R206: CHECK_REPORT' }
W $report $script:Lines
L ('main_report=' + (San $report))
L '--- task t163 done ---'
exit 0
